import type { APIRoute } from 'astro';
import { json } from '@/lib/server/appDb';
import { dbQuery } from '@/lib/server/supabaseDb';
import { createPortalLink } from '@/lib/server/social/bundle';
import { readJsonBody, requireSocialAccess } from '@/lib/server/social/api';
import {
  SOCIAL_ACCOUNT_COLUMNS,
  fetchConnectedAccounts,
  getSocialAccountById,
  resolveBundleApiKey,
  syncBundleTeam,
  updateSocialAccountError,
} from '@/lib/server/social/store';

export const prerender = false;

const DEFAULT_SOCIAL_TYPES = [
  'INSTAGRAM',
  'FACEBOOK',
  'TWITTER',
  'THREADS',
  'LINKEDIN',
  'TIKTOK',
  'YOUTUBE',
  'PINTEREST',
  'REDDIT',
  'MASTODON',
  'BLUESKY',
  'GOOGLE_BUSINESS',
  'DISCORD',
  'SLACK',
];

function normalizeTypes(value: unknown) {
  const source = Array.isArray(value) ? value : DEFAULT_SOCIAL_TYPES;
  return Array.from(
    new Set(
      source
        .map((item) => String(item || '').trim().toUpperCase())
        .filter((item) => DEFAULT_SOCIAL_TYPES.includes(item))
    )
  );
}

async function syncConfiguredAccounts() {
  const configs = await dbQuery(
    `SELECT ${SOCIAL_ACCOUNT_COLUMNS}
     FROM public.social_accounts
     WHERE aktif_mi IS TRUE
     ORDER BY olusturma_tarihi DESC`
  );

  for (const account of configs.rows) {
    const apiKey = resolveBundleApiKey(account);
    const teamId = String(account.team_id || '').trim();
    if (!apiKey || !teamId) continue;
    try {
      await syncBundleTeam(account, apiKey);
    } catch (error: any) {
      await updateSocialAccountError(account.id, error.message || 'Bundle Social account sync failed');
    }
  }
}

export const GET: APIRoute = async ({ request }) => {
  try {
    const access = await requireSocialAccess(request);
    if (access.response) return access.response;

    await syncConfiguredAccounts();
    return json({ accounts: await fetchConnectedAccounts() });
  } catch (error: any) {
    return json({ error: { message: error.message || 'Social media accounts could not be loaded' } }, 500);
  }
};

export const POST: APIRoute = async ({ request }) => {
  const body = await readJsonBody(request);
  try {
    const access = await requireSocialAccess(request, body);
    if (access.response) return access.response;

    const account = await getSocialAccountById(body.social_account_id || body.account_id);
    if (!account) return json({ error: { message: 'Bundle Social settings are required before connecting accounts' } }, 400);

    const apiKey = resolveBundleApiKey(account);
    if (!apiKey) return json({ error: { message: 'Bundle Social API key is missing' } }, 400);

    const socialAccountTypes = normalizeTypes(body.social_account_types || body.platform_types);
    if (!socialAccountTypes.length) return json({ error: { message: 'At least one Bundle Social account type is required' } }, 400);

    const result = await createPortalLink({
      apiKey,
      apiBaseUrl: account.api_base_url,
      teamId: account.team_id,
      redirectUrl: String(body.redirect_url || account.redirect_url || '').trim(),
      socialAccountTypes,
    });

    return json({ url: result.url });
  } catch (error: any) {
    return json({ error: { message: error.message || 'Bundle Social portal link could not be created' } }, error.status || 500);
  }
};
