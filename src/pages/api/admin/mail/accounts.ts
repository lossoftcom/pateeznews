import type { APIRoute } from 'astro';
import { dbQuery } from '@/lib/server/neonDb';
import { json } from '@/lib/server/appDb';
import { readJsonBody, requireMailAccess, sqlSetClause } from '@/lib/server/mail/api';
import { encryptSecret, hasSecret } from '@/lib/server/mail/secrets';
import { dnsChecklist, MAIL_PROVIDER_OPTIONS } from '@/lib/server/mail/providers';

export const prerender = false;

const ACCOUNT_COLUMNS = `
  id::text AS id,
  hesap_adi AS account_name,
  gonderen_adi AS sender_name,
  gonderen_eposta AS sender_email,
  servis_tipi AS service_type,
  gonderim_modu AS sending_mode,
  smtp_sunucu AS smtp_host,
  smtp_port,
  smtp_kullanici AS smtp_username,
  smtp_guvenlik AS smtp_secure,
  alim_aktif AS receiving_enabled,
  imap_sunucu AS imap_host,
  imap_port,
  imap_kullanici AS imap_username,
  spf_kayitli AS spf_registered,
  dkim_kayitli AS dkim_registered,
  dmarc_kayitli AS dmarc_registered,
  dmarc_politikasi AS dmarc_policy,
  dns_son_kontrol AS dns_last_checked_at,
  gunluk_limit AS daily_limit,
  aylik_limit AS monthly_limit,
  saatlik_limit AS hourly_limit,
  bu_gun_gonderilen AS sent_today,
  bu_ay_gonderilen AS sent_this_month,
  varsayilan_imza AS default_signature,
  varsayilan_reply_to AS default_reply_to,
  aktif_mi AS is_active,
  baglanti_durumu AS connection_status,
  son_hata_mesaji AS last_error_message,
  olusturma_tarihi AS created_at,
  guncelleme_tarihi AS updated_at,
  kullanici AS created_by,
  api_anahtari AS api_key_encrypted,
  api_sifresi AS api_secret_encrypted,
  api_token AS api_token_encrypted,
  smtp_sifre AS smtp_password_encrypted,
  imap_sifre AS imap_password_encrypted
`;

function accountForClient(row: any) {
  if (!row) return row;
  const {
    api_key_encrypted,
    api_secret_encrypted,
    api_token_encrypted,
    smtp_password_encrypted,
    imap_password_encrypted,
    ...rest
  } = row;

  return {
    ...rest,
    has_api_key: hasSecret(api_key_encrypted),
    has_api_secret: hasSecret(api_secret_encrypted),
    has_api_token: hasSecret(api_token_encrypted),
    has_smtp_password: hasSecret(smtp_password_encrypted),
    has_imap_password: hasSecret(imap_password_encrypted),
  };
}

function normalizeAccountPayload(body: Record<string, any>, userId?: string) {
  const fieldMap: Record<string, string> = {
    account_name: 'hesap_adi',
    sender_name: 'gonderen_adi',
    sender_email: 'gonderen_eposta',
    service_type: 'servis_tipi',
    sending_mode: 'gonderim_modu',
    smtp_host: 'smtp_sunucu',
    smtp_port: 'smtp_port',
    smtp_username: 'smtp_kullanici',
    smtp_secure: 'smtp_guvenlik',
    receiving_enabled: 'alim_aktif',
    imap_host: 'imap_sunucu',
    imap_port: 'imap_port',
    imap_username: 'imap_kullanici',
    spf_registered: 'spf_kayitli',
    dkim_registered: 'dkim_kayitli',
    dmarc_registered: 'dmarc_kayitli',
    dmarc_policy: 'dmarc_politikasi',
    daily_limit: 'gunluk_limit',
    monthly_limit: 'aylik_limit',
    hourly_limit: 'saatlik_limit',
    default_signature: 'varsayilan_imza',
    default_reply_to: 'varsayilan_reply_to',
    is_active: 'aktif_mi',
    connection_status: 'baglanti_durumu',
    last_error_message: 'son_hata_mesaji',
  };
  const update: Record<string, any> = {};
  for (const [clientKey, dbKey] of Object.entries(fieldMap)) {
    if (Object.prototype.hasOwnProperty.call(body, clientKey)) update[dbKey] = body[clientKey];
  }

  for (const key of ['smtp_port', 'imap_port', 'gunluk_limit', 'aylik_limit', 'saatlik_limit']) {
    if (Object.prototype.hasOwnProperty.call(update, key)) update[key] = Number(update[key] || 0) || null;
  }

  for (const [source, target] of [
    ['api_key', 'api_anahtari'],
    ['api_secret', 'api_sifresi'],
    ['api_token', 'api_token'],
    ['smtp_password', 'smtp_sifre'],
    ['imap_password', 'imap_sifre'],
  ] as const) {
    if (String(body[source] || '').trim()) update[target] = encryptSecret(body[source]);
  }

  update.guncelleme_tarihi = new Date().toISOString();
  if (userId) update.kullanici = userId;
  return update;
}

export const GET: APIRoute = async ({ request, url }) => {
  try {
    const access = await requireMailAccess(request);
    if (access.response) return access.response;

    if (url.searchParams.get('providers')) {
      return json({ providers: MAIL_PROVIDER_OPTIONS });
    }

    const result = await dbQuery(
      `SELECT ${ACCOUNT_COLUMNS}
       FROM public.mail_accounts
       ORDER BY aktif_mi DESC, olusturma_tarihi DESC`
    );

    return json({ accounts: result.rows.map(accountForClient) });
  } catch (error: any) {
    return json({ error: { message: error.message || 'Mail accounts could not be loaded' } }, 500);
  }
};

export const POST: APIRoute = async ({ request }) => {
  const body = await readJsonBody(request);
  try {
    const access = await requireMailAccess(request, body);
    if (access.response) return access.response;

    const accountName = String(body.account_name || '').trim();
    const senderEmail = String(body.sender_email || '').trim().toLowerCase();
    if (!accountName || !senderEmail) return json({ error: { message: 'Account name and sender email are required' } }, 400);

    const payload = normalizeAccountPayload({ ...body, account_name: accountName, sender_email: senderEmail }, access.session!.user.id);
    const keys = Object.keys(payload);
    const values = keys.map((key) => payload[key]);
    const placeholders = keys.map((_, index) => `$${index + 1}`).join(', ');

    const result = await dbQuery(
      `INSERT INTO public.mail_accounts (${keys.join(', ')})
       VALUES (${placeholders})
       RETURNING ${ACCOUNT_COLUMNS}`,
      values
    );

    return json({ account: accountForClient(result.rows[0]) });
  } catch (error: any) {
    return json({ error: { message: error.message || 'Mail account could not be saved' } }, 500);
  }
};

export const PATCH: APIRoute = async ({ request }) => {
  const body = await readJsonBody(request);
  try {
    const access = await requireMailAccess(request, body);
    if (access.response) return access.response;

    const id = String(body.id || '').trim();
    if (!id) return json({ error: { message: 'Account id required' } }, 400);

    if (body.action === 'dns-check') {
      const result = await dbQuery(`SELECT ${ACCOUNT_COLUMNS} FROM public.mail_accounts WHERE id = $1::bigint LIMIT 1`, [id]);
      const account = result.rows[0];
      if (!account) return json({ error: { message: 'Account not found' } }, 404);
      const domain = String(account.sender_email || '').split('@')[1] || '';
      const checklist = dnsChecklist(domain, account.service_type);
      await dbQuery('UPDATE public.mail_accounts SET dns_son_kontrol = now(), guncelleme_tarihi = now() WHERE id = $1::bigint', [id]);
      return json({ checklist });
    }

    const update = normalizeAccountPayload(body);
    delete update.kullanici;
    const set = sqlSetClause(update);
    if (!set.keys.length) return json({ error: { message: 'No changes' } }, 400);

    const result = await dbQuery(
      `UPDATE public.mail_accounts
       SET ${set.clause}
       WHERE id = $${set.values.length + 1}::bigint
       RETURNING ${ACCOUNT_COLUMNS}`,
      [...set.values, id]
    );

    return json({ account: accountForClient(result.rows[0]) });
  } catch (error: any) {
    return json({ error: { message: error.message || 'Mail account could not be updated' } }, 500);
  }
};

export const DELETE: APIRoute = async ({ request, url }) => {
  const body = await readJsonBody(request);
  try {
    const access = await requireMailAccess(request, body);
    if (access.response) return access.response;

    const id = String(body.id || url.searchParams.get('id') || '').trim();
    if (!id) return json({ error: { message: 'Account id required' } }, 400);

    await dbQuery('DELETE FROM public.mail_accounts WHERE id = $1::bigint', [id]);
    return json({ ok: true });
  } catch (error: any) {
    return json({ error: { message: error.message || 'Mail account could not be deleted' } }, 500);
  }
};
