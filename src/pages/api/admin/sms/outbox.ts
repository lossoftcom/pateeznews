import type { APIRoute } from 'astro';
import { json } from '@/lib/server/appDb';
import { dbQuery } from '@/lib/server/neonDb';
import { normalizePhone, readJsonBody, requireSmsAccess } from '@/lib/server/sms/api';
import { sendSmsTextWithAccount } from '@/lib/server/sms/providers';

export const prerender = false;

const MESSAGE_SELECT = `
  m.id::text AS id,
  c.ad AS recipient,
  c.telefon AS phone,
  m.mesaj AS body,
  COALESCE(a.hesap_adi, a.gonderici_basligi, a.telefon, '') AS sender_line,
  m.durum AS status,
  m.servis_message_id AS service_message_id,
  m.hata_mesaji AS error_message,
  COALESCE(m.gonderim_tarihi, m.olusturma_tarihi) AS sent_at,
  m.teslim_tarihi AS delivered_at,
  m.olusturma_tarihi AS created_at
`;

async function findActiveAccount(accountId?: string) {
  const result = accountId
    ? await dbQuery(
        `SELECT *,
          servis_tipi AS service_type,
          gonderici_basligi AS sender_id,
          telefon AS phone,
          api_anahtari AS api_key_encrypted,
          api_sifresi AS api_secret_encrypted,
          api_token AS api_token_encrypted
         FROM public.sms_accounts
         WHERE id = $1::bigint AND aktif_mi IS TRUE
         LIMIT 1`,
        [accountId]
      )
    : await dbQuery(
        `SELECT *,
          servis_tipi AS service_type,
          gonderici_basligi AS sender_id,
          telefon AS phone,
          api_anahtari AS api_key_encrypted,
          api_sifresi AS api_secret_encrypted,
          api_token AS api_token_encrypted
         FROM public.sms_accounts
         WHERE aktif_mi IS TRUE
         ORDER BY olusturma_tarihi DESC
         LIMIT 1`
      );
  return result.rows[0] || null;
}

async function ensureContact(input: { phone?: string; name?: string }) {
  const phone = normalizePhone(input.phone);
  if (!phone) throw new Error('Recipient phone is required');

  const existing = await dbQuery(
    `SELECT id, ad, telefon
     FROM public.sms_chats
     WHERE regexp_replace(telefon, '[^0-9+]', '', 'g') = $1
     LIMIT 1`,
    [phone]
  );
  if (existing.rows[0]) return existing.rows[0];

  const created = await dbQuery(
    `INSERT INTO public.sms_chats (ad, telefon, son_mesaj, son_mesaj_tarihi)
     VALUES ($1, $2, '', now())
     RETURNING id, ad, telefon`,
    [String(input.name || phone).trim(), phone]
  );
  return created.rows[0];
}

async function selectedMessage(id: string) {
  const result = await dbQuery(
    `SELECT ${MESSAGE_SELECT}
     FROM public.sms_messages m
     JOIN public.sms_chats c ON c.id = m.chat_id
     LEFT JOIN public.sms_accounts a ON a.id = m.hesap_id
     WHERE m.id = $1::bigint
     LIMIT 1`,
    [id]
  );
  return result.rows[0] || null;
}

export const GET: APIRoute = async ({ request, url }) => {
  try {
    const access = await requireSmsAccess(request);
    if (access.response) return access.response;

    const search = String(url.searchParams.get('search') || '').trim();
    const status = String(url.searchParams.get('status') || '').trim();
    const values: any[] = [];
    const where: string[] = ['m.yon = $1'];
    values.push('outgoing');
    if (status && status !== 'all') {
      values.push(status);
      where.push(`m.durum = $${values.length}`);
    }
    if (search) {
      values.push(`%${search}%`);
      where.push(`(c.ad ILIKE $${values.length} OR c.telefon ILIKE $${values.length} OR m.mesaj ILIKE $${values.length} OR a.hesap_adi ILIKE $${values.length})`);
    }

    const items = await dbQuery(
      `SELECT ${MESSAGE_SELECT}
       FROM public.sms_messages m
       JOIN public.sms_chats c ON c.id = m.chat_id
       LEFT JOIN public.sms_accounts a ON a.id = m.hesap_id
       WHERE ${where.join(' AND ')}
       ORDER BY m.olusturma_tarihi DESC
       LIMIT 200`,
      values
    );

    return json({ items: items.rows });
  } catch (error: any) {
    return json({ error: { message: error.message || 'SMS outbox could not be loaded' } }, 500);
  }
};

export const POST: APIRoute = async ({ request }) => {
  const body = await readJsonBody(request);
  try {
    const access = await requireSmsAccess(request, body);
    if (access.response) return access.response;

    const text = String(body.text || body.message || '').trim();
    if (!text) return json({ error: { message: 'Message text is required' } }, 400);

    const account = await findActiveAccount(String(body.account_id || '').trim() || undefined);
    if (!account) return json({ error: { message: 'No active SMS account found' } }, 400);

    const contact = await ensureContact({
      phone: body.phone,
      name: body.name || body.recipient,
    });

    const inserted = await dbQuery(
      `INSERT INTO public.sms_messages (chat_id, hesap_id, yon, mesaj, durum, kullanici)
       VALUES ($1, $2, 'outgoing', $3, 'queued', $4)
       RETURNING id`,
      [contact.id, account.id, text, access.session!.user.id]
    );
    const messageId = String(inserted.rows[0].id);

    try {
      const result = await sendSmsTextWithAccount(account, {
        to: contact.telefon,
        text,
      });
      await dbQuery(
        `UPDATE public.sms_messages
         SET durum = 'sent', servis_message_id = $1, gonderim_tarihi = now(), hata_mesaji = null
         WHERE id = $2::bigint`,
        [result.messageId, messageId]
      );
      await dbQuery(
        `UPDATE public.sms_accounts
         SET bugun_gonderilen = bugun_gonderilen + 1,
             bu_ay_gonderilen = bu_ay_gonderilen + 1,
             baglanti_durumu = 'ok',
             son_hata_mesaji = null,
             guncelleme_tarihi = now()
         WHERE id = $1::bigint`,
        [account.id]
      );
    } catch (error: any) {
      await dbQuery(
        `UPDATE public.sms_messages
         SET durum = 'failed', hata_mesaji = $1
         WHERE id = $2::bigint`,
        [error.message || 'Send failed', messageId]
      );
      await dbQuery(
        `UPDATE public.sms_accounts
         SET baglanti_durumu = 'error', son_hata_mesaji = $1, guncelleme_tarihi = now()
         WHERE id = $2::bigint`,
        [error.message || 'Send failed', account.id]
      );
      throw error;
    }

    await dbQuery(
      `UPDATE public.sms_chats
       SET son_mesaj = $1, son_mesaj_tarihi = now(), guncelleme_tarihi = now()
       WHERE id = $2::bigint`,
      [text, contact.id]
    );

    return json({ message: await selectedMessage(messageId) });
  } catch (error: any) {
    return json({ error: { message: error.message || 'SMS message could not be sent' } }, 500);
  }
};
