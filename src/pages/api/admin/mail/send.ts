import type { APIRoute } from 'astro';
import { dbQuery } from '@/lib/server/supabaseDb';
import { json } from '@/lib/server/appDb';
import { isEmail, parseEmailList, readJsonBody, requireMailAccess } from '@/lib/server/mail/api';
import { sendMailWithAccount, spamScore } from '@/lib/server/mail/providers';

export const prerender = false;

function plainTextFromHtml(html: string) {
  return String(html || '')
    .replace(/<style[\s\S]*?<\/style>/gi, ' ')
    .replace(/<script[\s\S]*?<\/script>/gi, ' ')
    .replace(/<[^>]+>/g, ' ')
    .replace(/\s+/g, ' ')
    .trim();
}

async function findAccount(accountId?: string) {
  const result = accountId
    ? await dbQuery(
      `SELECT *,
        hesap_adi AS account_name,
        gonderen_adi AS sender_name,
        gonderen_eposta AS sender_email,
        servis_tipi AS service_type,
        gonderim_modu AS sending_mode,
        smtp_sunucu AS smtp_host,
        smtp_kullanici AS smtp_username,
        smtp_sifre AS smtp_password_encrypted,
        smtp_guvenlik AS smtp_secure,
        varsayilan_reply_to AS default_reply_to
       FROM public.mail_accounts WHERE id = $1::bigint LIMIT 1`,
      [accountId]
    )
    : await dbQuery(
      `SELECT *,
        hesap_adi AS account_name,
        gonderen_adi AS sender_name,
        gonderen_eposta AS sender_email,
        servis_tipi AS service_type,
        gonderim_modu AS sending_mode,
        smtp_sunucu AS smtp_host,
        smtp_kullanici AS smtp_username,
        smtp_sifre AS smtp_password_encrypted,
        smtp_guvenlik AS smtp_secure,
        varsayilan_reply_to AS default_reply_to
       FROM public.mail_accounts WHERE aktif_mi IS TRUE ORDER BY olusturma_tarihi DESC LIMIT 1`
    );
  return result.rows[0] || null;
}

export const POST: APIRoute = async ({ request }) => {
  const body = await readJsonBody(request);
  try {
    const access = await requireMailAccess(request, body);
    if (access.response) return access.response;

    const account = await findAccount(String(body.account_id || '').trim() || undefined);
    if (!account) return json({ error: { message: 'No active mail account found' } }, 400);

    const subject = String(body.subject || '').trim();
    const contentHtml = String(body.content_html || body.html || '').trim();
    const contentText = String(body.content_text || body.text || plainTextFromHtml(contentHtml)).trim();
    const recipients = parseEmailList(body.recipients || body.to);
    const attachments = Array.isArray(body.attachments) ? body.attachments : [];
    const templateId = String(body.template_id || '').trim() || null;
    const campaignId = String(body.campaign_id || '').trim() || null;
    const scheduledAt = String(body.scheduled_at || '').trim() || null;
    const saveAsDraft = body.draft === true;

    if (!subject) return json({ error: { message: 'Subject is required' } }, 400);
    if (!contentHtml && !contentText) return json({ error: { message: 'Content is required' } }, 400);
    if (!recipients.length) return json({ error: { message: 'At least one valid recipient is required' } }, 400);

    const blocked = await dbQuery<{ email: string }>(
      `SELECT eposta AS email
       FROM public.mail_contacts
       WHERE lower(eposta) = ANY($1::text[])
         AND (aktif_mi IS NOT TRUE OR unsubscribe_tarihi IS NOT NULL OR bounce_durumu = 'hard' OR dogrulama_durumu = 'invalid')`,
      [recipients]
    );
    const blockedSet = new Set(blocked.rows.map((row: { email: string }) => String(row.email || '').toLowerCase()));
    const sendableRecipients = recipients.filter((recipient) => isEmail(recipient) && !blockedSet.has(recipient));
    if (!sendableRecipients.length) return json({ error: { message: 'All recipients are blocked, unsubscribed, or invalid' } }, 400);

    const spam = spamScore({ subject, html: contentHtml, text: contentText });
    if (spam.score >= 70 && !body.ignore_spam_warning) {
      return json({ error: { message: 'Spam score is too high', spam } }, 400);
    }

    const sent: any[] = [];
    const failed: any[] = [];

    for (const recipient of sendableRecipients) {
      const outbox = await dbQuery(
        `INSERT INTO public.mail_outbox (
          hesap_id, kampanya_id, alici_eposta, alici_adi, konu, icerik_html, icerik_text,
          ek_dosyalar_json, sablon_id, durum, zamanlanmis_tarih, kullanici
        )
        VALUES ($1, $2, $3, '', $4, $5, $6, $7, $8, $9, $10, $11)
        RETURNING id`,
        [
          account.id,
          campaignId || null,
          recipient,
          subject,
          contentHtml,
          contentText,
          JSON.stringify(attachments),
          templateId || null,
	          saveAsDraft ? 'draft' : 'queued',
	          scheduledAt,
          access.session!.user.id,
        ]
      );

	      if (saveAsDraft || scheduledAt) {
	        sent.push({ recipient, id: outbox.rows[0]?.id, draft: saveAsDraft, scheduled: Boolean(scheduledAt) });
	        continue;
	      }

      try {
        const result = await sendMailWithAccount(account, {
          to: recipient,
          subject,
          html: contentHtml,
          text: contentText,
          attachments,
        });

        await dbQuery(
          `UPDATE public.mail_outbox
           SET durum = 'sent', servis_message_id = $1, gonderim_tarihi = now(), hata_mesaji = null
           WHERE id = $2`,
          [result.messageId, outbox.rows[0]?.id]
        );
        sent.push({ recipient, id: outbox.rows[0]?.id, messageId: result.messageId, mocked: result.mocked || false });
      } catch (error: any) {
        await dbQuery(
          `UPDATE public.mail_outbox
           SET durum = 'failed', hata_mesaji = $1
           WHERE id = $2`,
          [error.message || 'Send failed', outbox.rows[0]?.id]
        );
        failed.push({ recipient, error: error.message || 'Send failed' });
      }
    }

    await dbQuery(
      `UPDATE public.mail_accounts
       SET bu_gun_gonderilen = bu_gun_gonderilen + $1,
           bu_ay_gonderilen = bu_ay_gonderilen + $1,
           baglanti_durumu = $2,
           son_hata_mesaji = $3,
           guncelleme_tarihi = now()
       WHERE id = $4::bigint`,
	      [sent.filter((item) => !item.scheduled && !item.draft).length, failed.length ? 'partial_error' : 'ok', failed[0]?.error || null, account.id]
	    );

    if (campaignId) {
      await dbQuery(
        `UPDATE public.mail_campaigns
         SET gonderilen_sayisi = gonderilen_sayisi + $1,
             durum = CASE WHEN durum = 'draft' THEN 'sending' ELSE durum END
         WHERE id = $2::bigint`,
        [sent.length, campaignId]
      );
    }

    return json({ ok: failed.length === 0, sent, failed, spam });
  } catch (error: any) {
    return json({ error: { message: error.message || 'Mail could not be sent' } }, 500);
  }
};
