import type { APIRoute } from 'astro';
import { json } from '@/lib/server/appDb';
import { dbQuery } from '@/lib/server/neonDb';
import { encryptSecret } from '@/lib/server/mail/secrets';
import { readJsonBody, requireSocialAccess, sqlSetClause } from '@/lib/server/social/api';
import {
  SOCIAL_ACCOUNT_COLUMNS,
  resolveBundleApiKey,
  socialAccountForClient,
  syncBundleTeam,
  updateSocialAccountError,
} from '@/lib/server/social/store';

export const prerender = false;

function normalizeAccountPayload(body: Record<string, any>, userId?: string) {
  const fieldMap: Record<string, string> = {
    account_name: 'hesap_adi',
    workspace_name: 'workspace_name',
    platforms: 'platformlar',
    provider_id: 'provider_id',
    provider_name: 'provider_name',
    connection_mode: 'baglanti_modu',
    api_base_url: 'api_base_url',
    team_id: 'team_id',
    redirect_url: 'redirect_url',
    webhook_url: 'webhook_url',
    scopes: 'scopes',
    daily_limit: 'gunluk_limit',
    monthly_limit: 'aylik_limit',
    hourly_limit: 'saatlik_limit',
    api_verified: 'api_dogrulandi',
    oauth_verified: 'oauth_dogrulandi',
    webhook_verified: 'webhook_dogrulandi',
    requires_approval: 'onay_gerekli',
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

  if (!update.provider_id) update.provider_id = 'bundle_social';
  if (!update.provider_name) update.provider_name = 'Bundle.social';
  if (!update.baglanti_modu) update.baglanti_modu = 'bundle';
  if (!update.api_base_url) update.api_base_url = 'https://api.bundle.social/api/v1';

  const apiKey = String(body.api_key || body.client_id || '').trim();
  if (apiKey) update.api_anahtari = encryptSecret(apiKey);
  const secret = String(body.client_secret || '').trim();
  if (secret) update.client_secret = encryptSecret(secret);

  update.guncelleme_tarihi = new Date().toISOString();
  if (userId) update.kullanici = userId;
  return update;
}

async function reloadAccount(id: string) {
  const result = await dbQuery(
    `SELECT ${SOCIAL_ACCOUNT_COLUMNS}
     FROM public.social_accounts
     WHERE id = $1::bigint
     LIMIT 1`,
    [id]
  );
  return socialAccountForClient(result.rows[0]);
}

export const GET: APIRoute = async ({ request }) => {
  try {
    const access = await requireSocialAccess(request);
    if (access.response) return access.response;

    const result = await dbQuery(
      `SELECT ${SOCIAL_ACCOUNT_COLUMNS}
       FROM public.social_accounts
       ORDER BY aktif_mi DESC, olusturma_tarihi DESC`
    );

    return json({ accounts: result.rows.map(socialAccountForClient) });
  } catch (error: any) {
    return json({ error: { message: error.message || 'Social media settings could not be loaded' } }, 500);
  }
};

export const POST: APIRoute = async ({ request }) => {
  const body = await readJsonBody(request);
  try {
    const access = await requireSocialAccess(request, body);
    if (access.response) return access.response;

    const accountName = String(body.account_name || '').trim();
    const teamId = String(body.team_id || '').trim();
    if (!accountName || !teamId) {
      return json({ error: { message: 'Account name and Bundle Social teamId are required' } }, 400);
    }

    const payload = normalizeAccountPayload(
      {
        ...body,
        account_name: accountName,
        team_id: teamId,
        provider_id: 'bundle_social',
        provider_name: 'Bundle.social',
        connection_mode: 'bundle',
      },
      access.session!.user.id
    );
    const keys = Object.keys(payload);
    const result = await dbQuery(
      `INSERT INTO public.social_accounts (${keys.join(', ')})
       VALUES (${keys.map((_, index) => `$${index + 1}`).join(', ')})
       RETURNING ${SOCIAL_ACCOUNT_COLUMNS}`,
      keys.map((key) => payload[key])
    );

    return json({ account: socialAccountForClient(result.rows[0]) });
  } catch (error: any) {
    return json({ error: { message: error.message || 'Social media settings could not be saved' } }, 500);
  }
};

export const PATCH: APIRoute = async ({ request }) => {
  const body = await readJsonBody(request);
  try {
    const access = await requireSocialAccess(request, body);
    if (access.response) return access.response;

    const id = String(body.id || '').trim();
    if (!id) return json({ error: { message: 'Account id required' } }, 400);

    if (body.action === 'connection-check') {
      const result = await dbQuery(
        `SELECT ${SOCIAL_ACCOUNT_COLUMNS}
         FROM public.social_accounts
         WHERE id = $1::bigint
         LIMIT 1`,
        [id]
      );
      const account = result.rows[0];
      if (!account) return json({ error: { message: 'Social media account not found' } }, 404);

      const apiKey = resolveBundleApiKey(account);
      if (!apiKey) {
        await updateSocialAccountError(id, 'Bundle Social API key is missing');
        return json({ account: await reloadAccount(id), error: { message: 'Bundle Social API key is missing' } }, 400);
      }

      try {
        await syncBundleTeam(account, apiKey);
      } catch (error: any) {
        await updateSocialAccountError(id, error.message || 'Bundle Social connection check failed');
        return json({ account: await reloadAccount(id), error: { message: error.message || 'Bundle Social connection check failed' } }, 502);
      }

      return json({ account: await reloadAccount(id) });
    }

    const update = normalizeAccountPayload(body);
    delete update.kullanici;
    const set = sqlSetClause(update);
    if (!set.keys.length) return json({ error: { message: 'No changes' } }, 400);

    const result = await dbQuery(
      `UPDATE public.social_accounts
       SET ${set.clause}
       WHERE id = $${set.values.length + 1}::bigint
       RETURNING ${SOCIAL_ACCOUNT_COLUMNS}`,
      [...set.values, id]
    );

    if (!result.rows[0]) return json({ error: { message: 'Social media account not found' } }, 404);
    return json({ account: socialAccountForClient(result.rows[0]) });
  } catch (error: any) {
    return json({ error: { message: error.message || 'Social media settings could not be updated' } }, 500);
  }
};

export const DELETE: APIRoute = async ({ request, url }) => {
  const body = await readJsonBody(request);
  try {
    const access = await requireSocialAccess(request, body);
    if (access.response) return access.response;

    const id = String(body.id || url.searchParams.get('id') || '').trim();
    if (!id) return json({ error: { message: 'Account id required' } }, 400);

    await dbQuery('DELETE FROM public.social_accounts WHERE id = $1::bigint', [id]);
    return json({ ok: true });
  } catch (error: any) {
    return json({ error: { message: error.message || 'Social media settings could not be deleted' } }, 500);
  }
};
