import type { APIRoute } from 'astro';
import { json } from '@/lib/server/appDb';
import { dbQuery } from '@/lib/server/neonDb';
import { encryptSecret, hasSecret } from '@/lib/server/mail/secrets';
import { readJsonBody, requireWhatsappAccess, sqlSetClause } from '@/lib/server/whatsapp/api';

export const prerender = false;

const ACCOUNT_COLUMNS = `
  id::text AS id,
  hesap_adi AS account_name,
  gonderen_adi AS sender_name,
  telefon AS sender_phone,
  waba_id AS business_account_id,
  servis_tipi AS service_type,
  gonderim_modu AS sending_mode,
  api_base_url,
  phone_number_id,
  webhook_url,
  gunluk_limit AS daily_limit,
  aylik_limit AS monthly_limit,
  saatlik_limit AS hourly_limit,
  bugun_gonderilen AS sent_today,
  bu_ay_gonderilen AS sent_this_month,
  token_dogrulandi AS token_verified,
  webhook_dogrulandi AS webhook_verified,
  sablon_senkron AS templates_synced,
  aktif_mi AS is_active,
  baglanti_durumu AS connection_status,
  son_hata_mesaji AS last_error_message,
  olusturma_tarihi AS created_at,
  guncelleme_tarihi AS updated_at,
  kullanici AS created_by,
  api_anahtari AS api_key_encrypted,
  api_sifresi AS api_secret_encrypted,
  api_token AS api_token_encrypted
`;

function accountForClient(row: any) {
  if (!row) return row;
  const { api_key_encrypted, api_secret_encrypted, api_token_encrypted, ...rest } = row;
  return {
    ...rest,
    has_api_key: hasSecret(api_key_encrypted),
    has_api_secret: hasSecret(api_secret_encrypted),
    has_api_token: hasSecret(api_token_encrypted),
  };
}

function normalizeAccountPayload(body: Record<string, any>, userId?: string) {
  const fieldMap: Record<string, string> = {
    account_name: 'hesap_adi',
    sender_name: 'gonderen_adi',
    sender_phone: 'telefon',
    business_account_id: 'waba_id',
    service_type: 'servis_tipi',
    sending_mode: 'gonderim_modu',
    api_base_url: 'api_base_url',
    phone_number_id: 'phone_number_id',
    webhook_url: 'webhook_url',
    daily_limit: 'gunluk_limit',
    monthly_limit: 'aylik_limit',
    hourly_limit: 'saatlik_limit',
    token_verified: 'token_dogrulandi',
    webhook_verified: 'webhook_dogrulandi',
    templates_synced: 'sablon_senkron',
    is_active: 'aktif_mi',
    connection_status: 'baglanti_durumu',
    last_error_message: 'son_hata_mesaji',
  };
  const update: Record<string, any> = {};
  for (const [clientKey, dbKey] of Object.entries(fieldMap)) {
    if (Object.prototype.hasOwnProperty.call(body, clientKey)) update[dbKey] = body[clientKey];
  }

  for (const key of ['gunluk_limit', 'aylik_limit', 'saatlik_limit']) {
    if (Object.prototype.hasOwnProperty.call(update, key)) update[key] = Number(update[key] || 0) || null;
  }

  for (const [source, target] of [
    ['api_key', 'api_anahtari'],
    ['api_secret', 'api_sifresi'],
    ['api_token', 'api_token'],
  ] as const) {
    if (String(body[source] || '').trim()) update[target] = encryptSecret(body[source]);
  }

  update.guncelleme_tarihi = new Date().toISOString();
  if (userId) update.kullanici = userId;
  return update;
}

export const GET: APIRoute = async ({ request }) => {
  try {
    const access = await requireWhatsappAccess(request);
    if (access.response) return access.response;

    const result = await dbQuery(
      `SELECT ${ACCOUNT_COLUMNS}
       FROM public.whatsapp_accounts
       ORDER BY aktif_mi DESC, olusturma_tarihi DESC`
    );

    return json({ accounts: result.rows.map(accountForClient) });
  } catch (error: any) {
    return json({ error: { message: error.message || 'WhatsApp accounts could not be loaded' } }, 500);
  }
};

export const POST: APIRoute = async ({ request }) => {
  const body = await readJsonBody(request);
  try {
    const access = await requireWhatsappAccess(request, body);
    if (access.response) return access.response;

    const accountName = String(body.account_name || '').trim();
    const phone = String(body.sender_phone || '').trim();
    if (!accountName || !phone) return json({ error: { message: 'Account name and sender phone are required' } }, 400);

    const payload = normalizeAccountPayload({ ...body, account_name: accountName, sender_phone: phone }, access.session!.user.id);
    const keys = Object.keys(payload);
    const result = await dbQuery(
      `INSERT INTO public.whatsapp_accounts (${keys.join(', ')})
       VALUES (${keys.map((_, index) => `$${index + 1}`).join(', ')})
       RETURNING ${ACCOUNT_COLUMNS}`,
      keys.map((key) => payload[key])
    );

    return json({ account: accountForClient(result.rows[0]) });
  } catch (error: any) {
    return json({ error: { message: error.message || 'WhatsApp account could not be saved' } }, 500);
  }
};

export const PATCH: APIRoute = async ({ request }) => {
  const body = await readJsonBody(request);
  try {
    const access = await requireWhatsappAccess(request, body);
    if (access.response) return access.response;

    const id = String(body.id || '').trim();
    if (!id) return json({ error: { message: 'Account id required' } }, 400);

    if (body.action === 'connection-check') {
      const result = await dbQuery(`SELECT ${ACCOUNT_COLUMNS} FROM public.whatsapp_accounts WHERE id = $1::bigint LIMIT 1`, [id]);
      const account = result.rows[0];
      if (!account) return json({ error: { message: 'Account not found' } }, 404);
      const hasUrl = String(account.api_base_url || '').trim().length > 0;
      const hasToken = hasSecret(account.api_token_encrypted || account.api_key_encrypted);
      await dbQuery(
        `UPDATE public.whatsapp_accounts
         SET token_dogrulandi = $1,
             webhook_dogrulandi = webhook_url <> '',
             baglanti_durumu = $2,
             son_hata_mesaji = $3,
             guncelleme_tarihi = now()
         WHERE id = $4::bigint`,
        [hasToken, hasUrl && hasToken ? 'configured' : 'missing_credentials', hasUrl && hasToken ? null : 'API URL or token is missing', id]
      );
      const updated = await dbQuery(`SELECT ${ACCOUNT_COLUMNS} FROM public.whatsapp_accounts WHERE id = $1::bigint LIMIT 1`, [id]);
      return json({ account: accountForClient(updated.rows[0]) });
    }

    const update = normalizeAccountPayload(body);
    delete update.kullanici;
    const set = sqlSetClause(update);
    if (!set.keys.length) return json({ error: { message: 'No changes' } }, 400);

    const result = await dbQuery(
      `UPDATE public.whatsapp_accounts
       SET ${set.clause}
       WHERE id = $${set.values.length + 1}::bigint
       RETURNING ${ACCOUNT_COLUMNS}`,
      [...set.values, id]
    );

    return json({ account: accountForClient(result.rows[0]) });
  } catch (error: any) {
    return json({ error: { message: error.message || 'WhatsApp account could not be updated' } }, 500);
  }
};

export const DELETE: APIRoute = async ({ request, url }) => {
  const body = await readJsonBody(request);
  try {
    const access = await requireWhatsappAccess(request, body);
    if (access.response) return access.response;

    const id = String(body.id || url.searchParams.get('id') || '').trim();
    if (!id) return json({ error: { message: 'Account id required' } }, 400);

    await dbQuery('DELETE FROM public.whatsapp_accounts WHERE id = $1::bigint', [id]);
    return json({ ok: true });
  } catch (error: any) {
    return json({ error: { message: error.message || 'WhatsApp account could not be deleted' } }, 500);
  }
};
