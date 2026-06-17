import type { APIRoute } from 'astro';
import { getSessionFromRequest, json } from '@/lib/server/appDb';
import { dbQuery } from '@/lib/server/supabaseDb';
import {
  normalizePlatform,
  normalizeStringArray,
  normalizeText,
  readJsonBody,
} from '@/lib/server/notifications/api';

export const prerender = false;

export const POST: APIRoute = async ({ request }) => {
  const body = await readJsonBody(request);
  try {
    const session = await getSessionFromRequest(request, body);
    const fcmToken = normalizeText(body.fcm_token || body.fcmToken || body.token_value);
    if (!fcmToken || fcmToken.length < 20) {
      return json({ error: { message: 'FCM token required' } }, 400);
    }

    const platform = normalizePlatform(body.platform);
    const appSurface = normalizeText(body.app_surface || body.appSurface) || (platform === 'web' ? 'astro_web' : 'flutter_mobile');
    const topics = normalizeStringArray(body.topics);
    const result = await dbQuery(
      `INSERT INTO public.notification_device_tokens (
        user_id,
        fcm_token,
        platform,
        app_surface,
        language_code,
        country_code,
        timezone,
        app_version,
        device_id,
        device_model,
        permission_status,
        topics,
        is_active,
        last_seen_at,
        token_refreshed_at
      )
      VALUES (
        $1::uuid,
        $2,
        $3,
        $4,
        $5,
        $6,
        $7,
        $8,
        $9,
        $10,
        $11,
        $12::text[],
        true,
        now(),
        now()
      )
      ON CONFLICT (fcm_token) DO UPDATE
      SET user_id = COALESCE(EXCLUDED.user_id, notification_device_tokens.user_id),
          platform = EXCLUDED.platform,
          app_surface = EXCLUDED.app_surface,
          language_code = EXCLUDED.language_code,
          country_code = EXCLUDED.country_code,
          timezone = EXCLUDED.timezone,
          app_version = EXCLUDED.app_version,
          device_id = EXCLUDED.device_id,
          device_model = EXCLUDED.device_model,
          permission_status = EXCLUDED.permission_status,
          topics = EXCLUDED.topics,
          is_active = true,
          invalidated_at = NULL,
          invalid_reason = NULL,
          last_seen_at = now(),
          token_refreshed_at = now(),
          updated_at = now()
      RETURNING id::text`,
      [
        session?.user?.id || null,
        fcmToken,
        platform,
        appSurface,
        normalizeText(body.language_code || body.languageCode) || 'tr',
        normalizeText(body.country_code || body.countryCode),
        normalizeText(body.timezone),
        normalizeText(body.app_version || body.appVersion),
        normalizeText(body.device_id || body.deviceId),
        normalizeText(body.device_model || body.deviceModel),
        normalizeText(body.permission_status || body.permissionStatus) || 'unknown',
        topics,
      ]
    );

    await dbQuery(
      `INSERT INTO public.notification_events (device_token_id, user_id, event_type, metadata)
       VALUES ($1::bigint, $2::uuid, 'register', $3::jsonb)`,
      [
        result.rows[0]?.id || null,
        session?.user?.id || null,
        JSON.stringify({ platform, appSurface }),
      ]
    );

    return json({ ok: true, deviceTokenId: result.rows[0]?.id || null });
  } catch (error: any) {
    return json({ error: { message: error.message || 'Notification token could not be registered' } }, 500);
  }
};
