import type { APIRoute } from 'astro';
import { json } from '@/lib/server/appDb';
import { dbQuery } from '@/lib/server/supabaseDb';
import { readRuntimeEnv } from '@/lib/server/runtimeEnv';
import { encryptSecret } from '@/lib/server/mail/secrets';
import { checkFirebaseConnection } from '@/lib/server/notifications/fcm';
import {
  normalizeText,
  readJsonBody,
  requireNotificationAccess,
  sqlSetClause,
} from '@/lib/server/notifications/api';

export const prerender = false;

const SETTINGS_SELECT = `
  id::text,
  provider_id,
  provider_name,
  project_id,
  client_email,
  web_vapid_key,
  api_base_url,
  default_language_code,
  daily_limit,
  monthly_limit,
  hourly_limit,
  batch_size,
  android_enabled,
  ios_enabled,
  flutter_web_enabled,
  astro_web_enabled,
  token_verified,
  is_active,
  connection_status,
  last_error_message,
  last_checked_at,
  created_at,
  updated_at,
  private_key_encrypted IS NOT NULL AS has_private_key
`;

type NotificationSettingsRow = {
  id: string;
  [key: string]: unknown;
};

function serverConfigured() {
  return Boolean(
    (readRuntimeEnv('FIREBASE_PROJECT_ID') || readRuntimeEnv('FCM_PROJECT_ID')) &&
      (readRuntimeEnv('FIREBASE_CLIENT_EMAIL') || readRuntimeEnv('FCM_CLIENT_EMAIL')) &&
      (readRuntimeEnv('FIREBASE_PRIVATE_KEY') || readRuntimeEnv('FCM_PRIVATE_KEY'))
  );
}

async function selectedSettings(id?: string) {
  const result = await dbQuery<NotificationSettingsRow>(
    `SELECT ${SETTINGS_SELECT}
     FROM public.notification_settings
     WHERE ${id ? 'id = $1::bigint' : "provider_id = 'firebase_fcm'"}
     ORDER BY id ASC
     LIMIT 1`,
    id ? [id] : []
  );
  const row = result.rows[0] || null;
  return row ? { ...row, server_credentials_configured: serverConfigured() } : null;
}

function numberValue(value: unknown, fallback: number, min: number, max: number) {
  const number = Number(value);
  if (!Number.isFinite(number)) return fallback;
  return Math.min(max, Math.max(min, Math.floor(number)));
}

function settingsPayload(body: Record<string, any>) {
  const payload: Record<string, any> = {};
  const fields = [
    'provider_id',
    'provider_name',
    'project_id',
    'client_email',
    'web_vapid_key',
    'api_base_url',
    'default_language_code',
    'android_enabled',
    'ios_enabled',
    'flutter_web_enabled',
    'astro_web_enabled',
    'is_active',
  ];

  for (const key of fields) {
    if (Object.prototype.hasOwnProperty.call(body, key)) payload[key] = body[key];
  }

  if (Object.prototype.hasOwnProperty.call(body, 'daily_limit')) {
    payload.daily_limit = numberValue(body.daily_limit, 100000, 1, 10000000);
  }
  if (Object.prototype.hasOwnProperty.call(body, 'monthly_limit')) {
    payload.monthly_limit = numberValue(body.monthly_limit, 3000000, 1, 100000000);
  }
  if (Object.prototype.hasOwnProperty.call(body, 'hourly_limit')) {
    payload.hourly_limit = numberValue(body.hourly_limit, 10000, 1, 1000000);
  }
  if (Object.prototype.hasOwnProperty.call(body, 'batch_size')) {
    payload.batch_size = numberValue(body.batch_size, 100, 1, 500);
  }
  if (normalizeText(body.private_key)) {
    payload.private_key_encrypted = encryptSecret(body.private_key);
  }

  payload.updated_at = new Date().toISOString();
  return payload;
}

export const GET: APIRoute = async ({ request }) => {
  try {
    const access = await requireNotificationAccess(request);
    if (access.response) return access.response;
    return json({ settings: await selectedSettings() });
  } catch (error: any) {
    return json({ error: { message: error.message || 'Notification settings could not be loaded' } }, 500);
  }
};

export const POST: APIRoute = async ({ request }) => {
  const body = await readJsonBody(request);
  try {
    const access = await requireNotificationAccess(request, body);
    if (access.response) return access.response;

    const payload = settingsPayload(body);
    payload.provider_id = normalizeText(payload.provider_id) || 'firebase_fcm';
    payload.provider_name = normalizeText(payload.provider_name) || 'Firebase Cloud Messaging';
    payload.updated_by = access.session!.user.id;
    payload.created_by = access.session!.user.id;

    const existing = await selectedSettings();
    if (existing?.id) {
      const set = sqlSetClause(payload);
      await dbQuery(
        `UPDATE public.notification_settings SET ${set.clause} WHERE id = $${set.values.length + 1}::bigint`,
        [...set.values, existing.id]
      );
      return json({ settings: await selectedSettings(existing.id) });
    }

    const keys = Object.keys(payload);
    const result = await dbQuery(
      `INSERT INTO public.notification_settings (${keys.join(', ')})
       VALUES (${keys.map((_, index) => `$${index + 1}`).join(', ')})
       RETURNING id::text`,
      keys.map((key) => payload[key])
    );
    return json({ settings: await selectedSettings(String(result.rows[0]?.id || '')) });
  } catch (error: any) {
    return json({ error: { message: error.message || 'Notification settings could not be saved' } }, 500);
  }
};

export const PATCH: APIRoute = async ({ request }) => {
  const body = await readJsonBody(request);
  try {
    const access = await requireNotificationAccess(request, body);
    if (access.response) return access.response;

    const id = normalizeText(body.id);
    const current = await selectedSettings(id || undefined);
    if (!current?.id) return json({ error: { message: 'Notification settings not found' } }, 404);

    const action = normalizeText(body.action);
    if (action === 'connection-check') {
      const credentialRow = await dbQuery(
        `SELECT project_id, client_email, private_key_encrypted, api_base_url
         FROM public.notification_settings
         WHERE id = $1::bigint`,
        [current.id]
      );
      try {
        await checkFirebaseConnection(credentialRow.rows[0]);
        await dbQuery(
          `UPDATE public.notification_settings
           SET token_verified = true,
               connection_status = 'ready',
               last_error_message = NULL,
               last_checked_at = now(),
               updated_at = now(),
               updated_by = $2::uuid
           WHERE id = $1::bigint`,
          [current.id, access.session!.user.id]
        );
      } catch (error: any) {
        await dbQuery(
          `UPDATE public.notification_settings
           SET token_verified = false,
               connection_status = 'error',
               last_error_message = $2,
               last_checked_at = now(),
               updated_at = now(),
               updated_by = $3::uuid
           WHERE id = $1::bigint`,
          [current.id, error?.message || 'Firebase connection failed', access.session!.user.id]
        );
      }
      return json({ settings: await selectedSettings(current.id) });
    }

    const payload = settingsPayload(body);
    payload.updated_by = access.session!.user.id;
    const set = sqlSetClause(payload);
    if (!set.keys.length) return json({ error: { message: 'No changes' } }, 400);
    await dbQuery(
      `UPDATE public.notification_settings SET ${set.clause} WHERE id = $${set.values.length + 1}::bigint`,
      [...set.values, current.id]
    );
    return json({ settings: await selectedSettings(current.id) });
  } catch (error: any) {
    return json({ error: { message: error.message || 'Notification settings could not be updated' } }, 500);
  }
};

export const DELETE: APIRoute = async ({ request, url }) => {
  const body = await readJsonBody(request);
  try {
    const access = await requireNotificationAccess(request, body);
    if (access.response) return access.response;
    const id = normalizeText(body.id || url.searchParams.get('id'));
    if (!id) return json({ error: { message: 'Notification settings id required' } }, 400);
    await dbQuery('DELETE FROM public.notification_settings WHERE id = $1::bigint', [id]);
    return json({ ok: true });
  } catch (error: any) {
    return json({ error: { message: error.message || 'Notification settings could not be deleted' } }, 500);
  }
};
