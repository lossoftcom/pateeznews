import type { APIRoute } from 'astro';
import {
  adminError,
  adminJson,
  requireAdminRequest,
} from '@/lib/server/adminAuth';
import { dbQuery } from '@/lib/server/supabaseDb';

export const prerender = false;

const ADS_SETTINGS_KEY = 'ads.settings';
const PERSISTENT_EXPIRES_AT = '2099-12-31T23:59:59.000Z';
const READ_PERMISSIONS = [
  'ads_access',
  'manage_ads',
  'view_settings',
  'settings_access',
];
const WRITE_PERMISSIONS = ['manage_ads', 'settings_access'];

async function requireAnyAdminPermission(
  request: Request,
  permissions: string[],
) {
  let permissionError: unknown;
  for (const permission of permissions) {
    try {
      return await requireAdminRequest(request, permission);
    } catch (error) {
      if ((error as { status?: number })?.status !== 403) throw error;
      permissionError = error;
    }
  }
  throw (
    permissionError ||
    Object.assign(new Error('Admin permission denied'), { status: 403 })
  );
}

function asSettingsPayload(value: unknown) {
  if (!value || typeof value !== 'object' || Array.isArray(value)) return null;
  return value as Record<string, unknown>;
}

export const GET: APIRoute = async ({ request }) => {
  try {
    await requireAnyAdminPermission(request, READ_PERMISSIONS);
    const result = await dbQuery<{ payload: unknown }>(
      `SELECT payload
       FROM public.app_cache
       WHERE key = $1
         AND expires_at > now()
       LIMIT 1`,
      [ADS_SETTINGS_KEY],
    );
    return adminJson({
      data: asSettingsPayload(result.rows[0]?.payload),
      error: null,
    });
  } catch (error) {
    return adminError(error);
  }
};

export const POST: APIRoute = async ({ request }) => {
  try {
    await requireAnyAdminPermission(request, WRITE_PERMISSIONS);
    const body = await request.json().catch(() => ({}));
    const values = asSettingsPayload(body?.values);
    if (!values) {
      return adminJson(
        { data: null, error: { message: 'No valid ad settings provided' } },
        400,
      );
    }

    const result = await dbQuery<{ payload: unknown }>(
      `INSERT INTO public.app_cache (key, payload, expires_at, updated_at)
       VALUES ($1, $2::jsonb, $3::timestamptz, now())
       ON CONFLICT (key) DO UPDATE SET
         payload = EXCLUDED.payload,
         expires_at = EXCLUDED.expires_at,
         updated_at = now()
       RETURNING payload`,
      [ADS_SETTINGS_KEY, JSON.stringify(values), PERSISTENT_EXPIRES_AT],
    );

    return adminJson({
      data: asSettingsPayload(result.rows[0]?.payload) || values,
      error: null,
    });
  } catch (error) {
    return adminError(error);
  }
};
