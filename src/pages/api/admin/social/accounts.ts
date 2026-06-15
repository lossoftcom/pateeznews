import type { APIRoute } from 'astro';
import { json } from '@/lib/server/appDb';
import { dbQuery } from '@/lib/server/supabaseDb';
import { createPortalLink } from '@/lib/server/social/bundle';
import { readJsonBody, requireSocialAccess } from '@/lib/server/social/api';
import {
  SOCIAL_ACCOUNT_COLUMNS,
  fetchConnectedAccountById,
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

const ACCOUNT_STATUS_VALUES = new Set(['connected', 'disabled']);

function normalizeTypes(value: unknown) {
  const source = Array.isArray(value) ? value : DEFAULT_SOCIAL_TYPES;
  return Array.from(
    new Set(
      source
        .map((item) =>
          String(item || '')
            .trim()
            .toUpperCase(),
        )
        .filter((item) => DEFAULT_SOCIAL_TYPES.includes(item)),
    ),
  );
}

function normalizeRowId(value: unknown) {
  const id = String(value || '').trim();
  return /^\d+$/.test(id) ? id : '';
}

async function syncConfiguredAccounts() {
  const configs = await dbQuery(
    `SELECT ${SOCIAL_ACCOUNT_COLUMNS}
     FROM public.social_accounts
     WHERE aktif_mi IS TRUE
     ORDER BY olusturma_tarihi DESC`,
  );

  for (const account of configs.rows) {
    try {
      const apiKey = resolveBundleApiKey(account);
      const teamId = String(account.team_id || '').trim();
      if (!apiKey) {
        await updateSocialAccountError(
          account.id,
          'Bundle Social API key is missing or cannot be decrypted',
        );
        continue;
      }
      if (!teamId) {
        await updateSocialAccountError(
          account.id,
          'Bundle Social teamId is missing',
        );
        continue;
      }
      await syncBundleTeam(account, apiKey);
    } catch (error: any) {
      try {
        await updateSocialAccountError(
          account.id,
          error.message || 'Bundle Social account sync failed',
        );
      } catch {
        // Listing must still use the existing local database snapshot.
      }
    }
  }
}

export const GET: APIRoute = async ({ request }) => {
  try {
    const access = await requireSocialAccess(request);
    if (access.response) return access.response;

    await syncConfiguredAccounts().catch(() => undefined);
    return json({ accounts: await fetchConnectedAccounts() });
  } catch (error: any) {
    return json(
      {
        error: {
          message: error.message || 'Social media accounts could not be loaded',
        },
      },
      500,
    );
  }
};

export const POST: APIRoute = async ({ request }) => {
  const body = await readJsonBody(request);
  try {
    const access = await requireSocialAccess(request, body);
    if (access.response) return access.response;

    const account = await getSocialAccountById(
      body.social_account_id || body.account_id,
    );
    if (!account)
      return json(
        {
          error: {
            message:
              'Bundle Social settings are required before connecting accounts',
          },
        },
        400,
      );

    const apiKey = resolveBundleApiKey(account);
    if (!apiKey)
      return json(
        { error: { message: 'Bundle Social API key is missing' } },
        400,
      );

    const socialAccountTypes = normalizeTypes(
      body.social_account_types || body.platform_types,
    );
    if (!socialAccountTypes.length)
      return json(
        {
          error: {
            message: 'At least one Bundle Social account type is required',
          },
        },
        400,
      );

    const result = await createPortalLink({
      apiKey,
      apiBaseUrl: account.api_base_url,
      teamId: account.team_id,
      redirectUrl: String(
        body.redirect_url || account.redirect_url || '',
      ).trim(),
      socialAccountTypes,
    });

    return json({ url: result.url });
  } catch (error: any) {
    return json(
      {
        error: {
          message:
            error.message || 'Bundle Social portal link could not be created',
        },
      },
      error.status || 500,
    );
  }
};

export const PATCH: APIRoute = async ({ request }) => {
  const body = await readJsonBody(request);
  try {
    const access = await requireSocialAccess(request, body);
    if (access.response) return access.response;

    const id = normalizeRowId(body.id || body.connected_account_id);
    if (!id)
      return json(
        { error: { message: 'Connected account id is required' } },
        400,
      );

    const updates: Record<string, string> = {};
    if ('display_name' in body)
      updates.display_name = String(body.display_name || '').trim();
    if ('username' in body)
      updates.username = String(body.username || '')
        .replace(/^@+/, '')
        .trim();
    if ('channel_name' in body)
      updates.channel_name = String(body.channel_name || '').trim();

    if ('status' in body || 'durum' in body) {
      const status = String(body.status || body.durum || '')
        .trim()
        .toLowerCase();
      if (!ACCOUNT_STATUS_VALUES.has(status)) {
        return json(
          { error: { message: 'Unsupported connected account status' } },
          400,
        );
      }
      updates.durum = status;
    }

    const keys = Object.keys(updates);
    if (keys.length > 0) {
      const setClause = keys
        .map((key, index) => `${key} = $${index + 2}`)
        .join(', ');
      await dbQuery(
        `UPDATE public.social_connected_accounts
         SET ${setClause},
             guncelleme_tarihi = now()
         WHERE id = $1::bigint`,
        [id, ...keys.map((key) => updates[key])],
      );
    }

    const account = await fetchConnectedAccountById(id);
    if (!account)
      return json({ error: { message: 'Connected account not found' } }, 404);
    return json({ account });
  } catch (error: any) {
    return json(
      {
        error: {
          message: error.message || 'Connected account could not be updated',
        },
      },
      error.status || 500,
    );
  }
};

export const DELETE: APIRoute = async ({ request }) => {
  const body = await readJsonBody(request);
  try {
    const access = await requireSocialAccess(request, body);
    if (access.response) return access.response;

    const id = normalizeRowId(body.id || body.connected_account_id);
    if (!id)
      return json(
        { error: { message: 'Connected account id is required' } },
        400,
      );

    await dbQuery(
      `UPDATE public.social_connected_accounts
       SET durum = 'deleted',
           guncelleme_tarihi = now()
       WHERE id = $1::bigint`,
      [id],
    );

    return json({ ok: true });
  } catch (error: any) {
    return json(
      {
        error: {
          message: error.message || 'Connected account could not be deleted',
        },
      },
      error.status || 500,
    );
  }
};
