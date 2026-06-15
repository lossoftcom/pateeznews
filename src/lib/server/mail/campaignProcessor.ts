import { connectDbClient, dbQuery } from '@/lib/server/supabaseDb';
import { sendMailWithAccount } from './providers';

type CampaignContact = {
  id: string;
  email: string;
  first_name: string;
  last_name: string;
  phone: string;
};

function plainTextFromHtml(html: string) {
  return String(html || '')
    .replace(/<style[\s\S]*?<\/style>/gi, ' ')
    .replace(/<script[\s\S]*?<\/script>/gi, ' ')
    .replace(/<[^>]+>/g, ' ')
    .replace(/\s+/g, ' ')
    .trim();
}

function escapeHtml(value: string) {
  return value
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;')
    .replaceAll("'", '&#39;');
}

function renderContactVariables(
  value: string,
  contact: CampaignContact,
  html = false
) {
  const fullName = [contact.first_name, contact.last_name].filter(Boolean).join(' ').trim();
  const rawValues: Record<string, string> = {
    alici_adi: fullName || contact.email,
    alici_eposta: contact.email,
    uye_adi: fullName || contact.email,
    uye_eposta: contact.email,
    uye_telefon: contact.phone,
    abone_adi: fullName || contact.email,
    abone_eposta: contact.email,
    abone_telefon: contact.phone,
  };
  return Object.entries(rawValues).reduce(
    (rendered, [key, raw]) =>
      rendered.replaceAll(`{{${key}}}`, html ? escapeHtml(raw) : raw),
    String(value || '')
  );
}

async function reserveCampaignOutbox(campaignId: string) {
  const client = await connectDbClient();
  try {
    await client.query('BEGIN');
    const campaignResult = await client.query(
      `SELECT
        mc.*,
        ma.hesap_adi AS account_name,
        ma.gonderen_adi AS sender_name,
        ma.gonderen_eposta AS sender_email,
        ma.servis_tipi AS service_type,
        ma.gonderim_modu AS sending_mode,
        ma.smtp_sunucu AS smtp_host,
        ma.smtp_port,
        ma.smtp_kullanici AS smtp_username,
        ma.smtp_sifre AS smtp_password_encrypted,
        ma.smtp_guvenlik AS smtp_secure,
        ma.varsayilan_reply_to AS default_reply_to,
        ma.aktif_mi AS account_active
       FROM public.mail_campaigns mc
       JOIN public.mail_accounts ma ON ma.id = mc.hesap_id
       WHERE mc.id = $1::bigint
       FOR UPDATE OF mc`,
      [campaignId]
    );
    const campaign = campaignResult.rows[0];
    if (!campaign || campaign.durum !== 'sending' || !campaign.account_active) {
      await client.query('COMMIT');
      return null;
    }

    const batchSize = Math.min(Math.max(Number(campaign.gonderim_hizi || 50), 1), 100);
    const queued = await client.query(
      `SELECT id::text AS id, alici_eposta AS email, alici_adi AS recipient_name,
              konu AS subject, icerik_html AS content_html, icerik_text AS content_text
       FROM public.mail_outbox
       WHERE kampanya_id = $1::bigint AND durum = 'queued'
       ORDER BY id
       LIMIT $2`,
      [campaignId, batchSize]
    );

    if (queued.rows.length < batchSize) {
      const contacts = await client.query<CampaignContact>(
        `SELECT
          c.id::text AS id,
          c.eposta AS email,
          COALESCE(c.ad, '') AS first_name,
          COALESCE(c.soyad, '') AS last_name,
          COALESCE(c.telefon, '') AS phone
         FROM public.mail_contacts c
         JOIN public.mail_contact_list_memberships m ON m.contact_id = c.id
         WHERE m.list_id = $1::bigint
           AND c.aktif_mi IS TRUE
           AND c.unsubscribe_tarihi IS NULL
           AND COALESCE(c.bounce_durumu, 'none') <> 'hard'
           AND COALESCE(c.dogrulama_durumu, 'unknown') <> 'invalid'
           AND NOT EXISTS (
             SELECT 1 FROM public.mail_outbox o
             WHERE o.kampanya_id = $2::bigint
               AND lower(o.alici_eposta) = lower(c.eposta)
           )
         ORDER BY c.id
         LIMIT $3`,
        [campaign.kisi_listesi_id, campaignId, batchSize - queued.rows.length]
      );

      for (const contact of contacts.rows) {
        const recipientName = [contact.first_name, contact.last_name].filter(Boolean).join(' ').trim();
        const subject = renderContactVariables(campaign.konu, contact);
        const contentHtml = renderContactVariables(campaign.icerik_html, contact, true);
        await client.query(
          `INSERT INTO public.mail_outbox (
            hesap_id, kampanya_id, alici_eposta, alici_adi, konu,
            icerik_html, icerik_text, ek_dosyalar_json, sablon_id,
            durum, kullanici
          )
          VALUES ($1, $2, $3, $4, $5, $6, $7, '[]', $8, 'queued', $9)`,
          [
            campaign.hesap_id,
            campaignId,
            contact.email,
            recipientName,
            subject,
            contentHtml,
            plainTextFromHtml(contentHtml),
            campaign.sablon_id,
            campaign.kullanici,
          ]
        );
      }
    }

    const outbox = await client.query(
      `SELECT id::text AS id, alici_eposta AS email, alici_adi AS recipient_name,
              konu AS subject, icerik_html AS content_html, icerik_text AS content_text
       FROM public.mail_outbox
       WHERE kampanya_id = $1::bigint AND durum = 'queued'
       ORDER BY id
       LIMIT $2`,
      [campaignId, batchSize]
    );
    await client.query('COMMIT');
    return { campaign, outbox: outbox.rows };
  } catch (error) {
    await client.query('ROLLBACK').catch(() => undefined);
    throw error;
  } finally {
    await client.release();
  }
}

async function processCampaignBatch(campaignId: string) {
  const reserved = await reserveCampaignOutbox(campaignId);
  if (!reserved) return;

  let sentCount = 0;
  let firstError = '';
  for (const item of reserved.outbox) {
    try {
      const result = await sendMailWithAccount(reserved.campaign, {
        to: item.email,
        subject: item.subject,
        html: item.content_html,
        text: item.content_text,
      });
      await dbQuery(
        `UPDATE public.mail_outbox
         SET durum = 'sent', servis_message_id = $1, gonderim_tarihi = now(), hata_mesaji = null
         WHERE id = $2::bigint`,
        [result.messageId, item.id]
      );
      await dbQuery(
        `UPDATE public.mail_contacts
         SET toplam_gonderilen = COALESCE(toplam_gonderilen, 0) + 1,
             son_gonderim = now()
         WHERE lower(eposta) = lower($1)`,
        [item.email]
      );
      sentCount += 1;
    } catch (error: any) {
      firstError ||= error.message || 'Campaign send failed';
      await dbQuery(
        `UPDATE public.mail_outbox
         SET durum = 'failed', hata_mesaji = $1
         WHERE id = $2::bigint`,
        [firstError, item.id]
      );
      break;
    }
  }

  await dbQuery(
    `UPDATE public.mail_accounts
     SET bu_gun_gonderilen = COALESCE(bu_gun_gonderilen, 0) + $1,
         bu_ay_gonderilen = COALESCE(bu_ay_gonderilen, 0) + $1,
         baglanti_durumu = $2,
         son_hata_mesaji = NULLIF($3, ''),
         guncelleme_tarihi = now()
     WHERE id = $4::bigint`,
    [
      sentCount,
      firstError ? 'error' : 'ok',
      firstError,
      reserved.campaign.hesap_id,
    ]
  );

  const totals = await dbQuery(
    `SELECT
       COUNT(*) FILTER (
         WHERE durum IN ('sent', 'delivered', 'opened', 'clicked')
       )::integer AS sent,
       COUNT(*) FILTER (WHERE durum = 'queued')::integer AS queued,
       COUNT(*) FILTER (WHERE durum IN ('failed', 'bounce'))::integer AS failed
     FROM public.mail_outbox
     WHERE kampanya_id = $1::bigint`,
    [campaignId]
  );
  const remaining = await dbQuery(
    `SELECT COUNT(*)::integer AS count
     FROM public.mail_contacts c
     JOIN public.mail_contact_list_memberships m ON m.contact_id = c.id
     WHERE m.list_id = $1::bigint
       AND c.aktif_mi IS TRUE
       AND c.unsubscribe_tarihi IS NULL
       AND COALESCE(c.bounce_durumu, 'none') <> 'hard'
       AND COALESCE(c.dogrulama_durumu, 'unknown') <> 'invalid'
       AND NOT EXISTS (
         SELECT 1 FROM public.mail_outbox o
         WHERE o.kampanya_id = $2::bigint
           AND lower(o.alici_eposta) = lower(c.eposta)
       )`,
    [reserved.campaign.kisi_listesi_id, campaignId]
  );
  const sent = Number(totals.rows[0]?.sent || 0);
  const queued = Number(totals.rows[0]?.queued || 0);
  const failed = Number(totals.rows[0]?.failed || 0);
  const complete = !firstError && queued === 0 && failed === 0 && Number(remaining.rows[0]?.count || 0) === 0;

  await dbQuery(
    `UPDATE public.mail_campaigns
     SET gonderilen_sayisi = $1,
         son_gonderilen_index = $2,
         durum = $3,
         bitis_tarihi = CASE WHEN $3 = 'completed' THEN now() ELSE bitis_tarihi END,
         guncelleme_tarihi = now()
     WHERE id = $4::bigint`,
    [
      sent,
      sent + queued + failed,
      firstError ? 'paused' : complete ? 'completed' : 'sending',
      campaignId,
    ]
  );
}

export async function processMailCampaigns(options: {
  campaignId?: string;
  maxCampaigns?: number;
} = {}) {
  await dbQuery(
    `UPDATE public.mail_campaigns
     SET durum = 'sending',
         baslangic_tarihi = COALESCE(baslangic_tarihi, now()),
         guncelleme_tarihi = now()
     WHERE durum = 'scheduled'
       AND zamanlanmis_baslangic IS NOT NULL
       AND zamanlanmis_baslangic <= now()`
  );

  const campaignIds = options.campaignId
    ? [{ id: options.campaignId }]
    : (
      await dbQuery<{ id: string }>(
        `SELECT id::text AS id
         FROM public.mail_campaigns
         WHERE durum = 'sending'
         ORDER BY COALESCE(baslangic_tarihi, olusturma_tarihi), id
         LIMIT $1`,
        [Math.min(Math.max(options.maxCampaigns || 5, 1), 20)]
      )
    ).rows;

  for (const campaign of campaignIds) {
    await processCampaignBatch(campaign.id);
  }
}
