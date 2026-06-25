import type { APIRoute } from 'astro';
import { json } from '@/lib/server/appDb';
import { dbQuery } from '@/lib/server/supabaseDb';
import {
  normalizePlatform,
  normalizeStringArray,
  normalizeText,
  numericLimit,
  numericOffset,
  readJsonBody,
  requireNotificationAccess,
  sqlSetClause,
} from '@/lib/server/notifications/api';

export const prerender = false;

const DEVICE_SELECT = `
  dt.id::text,
  dt.user_id::text,
  dt.fcm_token,
  dt.platform,
  dt.app_surface,
  dt.language_code,
  dt.country_code,
  dt.timezone,
  dt.app_version,
  dt.device_id,
  dt.device_model,
  dt.permission_status,
  dt.topics,
  dt.is_active,
  dt.last_seen_at,
  dt.token_refreshed_at,
  dt.invalidated_at,
  dt.invalid_reason,
  dt.created_at,
  dt.updated_at,
  COALESCE(p.role, '') AS user_role,
  COALESCE(r.label, '') AS role_label,
  COALESCE(p.username, '') AS username,
  COALESCE(p.full_name, '') AS full_name,
  COALESCE(p.email, '') AS user_email,
  COALESCE(p.auth_provider, '') AS auth_provider
`;

const FIELD_MAP: Record<string, string> = {
  platform: 'platform',
  app_surface: 'app_surface',
  language_code: 'language_code',
  country_code: 'country_code',
  timezone: 'timezone',
  app_version: 'app_version',
  device_id: 'device_id',
  device_model: 'device_model',
  permission_status: 'permission_status',
  is_active: 'is_active',
  invalid_reason: 'invalid_reason',
};

function devicePayload(body: Record<string, any>) {
  const payload: Record<string, any> = {};
  for (const [clientKey, dbKey] of Object.entries(FIELD_MAP)) {
    if (Object.prototype.hasOwnProperty.call(body, clientKey)) payload[dbKey] = body[clientKey];
  }
  if (Object.prototype.hasOwnProperty.call(body, 'topics')) {
    payload.topics = normalizeStringArray(body.topics);
  }
  if (Object.prototype.hasOwnProperty.call(payload, 'platform')) {
    payload.platform = normalizePlatform(payload.platform);
  }
  return payload;
}

async function selectedDevice(id: string) {
  const result = await dbQuery(
    `SELECT ${DEVICE_SELECT}
     FROM public.notification_device_tokens dt
     LEFT JOIN public.profiles p ON p.id = dt.user_id
     LEFT JOIN public.roles r ON r.name = p.role
     WHERE dt.id = $1::bigint`,
    [id]
  );
  return result.rows[0] || null;
}

export const GET: APIRoute = async ({ request, url }) => {
  try {
    const access = await requireNotificationAccess(request);
    if (access.response) return access.response;

    const limit = numericLimit(url.searchParams.get('limit'), 25, 100);
    const offset = numericOffset(url.searchParams.get('offset'));
    const search = normalizeText(url.searchParams.get('search'));
    const platform = normalizeText(url.searchParams.get('platform'));
    const values: any[] = [];
    const where: string[] = [];

    if (platform && platform !== 'all') {
      values.push(platform);
      where.push(`(dt.platform = $${values.length} OR dt.app_surface = $${values.length})`);
    }
    if (search) {
      values.push(`%${search}%`);
      where.push(`(dt.fcm_token ILIKE $${values.length} OR dt.app_surface ILIKE $${values.length} OR dt.device_model ILIKE $${values.length} OR dt.app_version ILIKE $${values.length} OR p.username ILIKE $${values.length} OR p.full_name ILIKE $${values.length} OR p.email ILIKE $${values.length} OR p.role ILIKE $${values.length} OR r.label ILIKE $${values.length})`);
    }

    const whereSql = where.length ? `WHERE ${where.join(' AND ')}` : '';
    const [items, total, stats] = await Promise.all([
      dbQuery(
        `SELECT ${DEVICE_SELECT}
         FROM public.notification_device_tokens dt
         LEFT JOIN public.profiles p ON p.id = dt.user_id
         LEFT JOIN public.roles r ON r.name = p.role
         ${whereSql}
         ORDER BY dt.last_seen_at DESC
         LIMIT $${values.length + 1} OFFSET $${values.length + 2}`,
        [...values, limit, offset]
      ),
      dbQuery<{ count: string }>(
        `SELECT COUNT(*)::bigint AS count
         FROM public.notification_device_tokens dt
         LEFT JOIN public.profiles p ON p.id = dt.user_id
         LEFT JOIN public.roles r ON r.name = p.role
         ${whereSql}`,
        values
      ),
      dbQuery(
        `SELECT
          COUNT(*)::bigint AS total,
          COUNT(*) FILTER (WHERE is_active IS TRUE AND invalidated_at IS NULL)::bigint AS active,
          COUNT(*) FILTER (WHERE invalidated_at IS NOT NULL)::bigint AS invalid,
          COUNT(*) FILTER (WHERE platform = 'android')::bigint AS android,
          COUNT(*) FILTER (WHERE platform = 'ios')::bigint AS ios,
          COUNT(*) FILTER (WHERE app_surface IN ('flutter_web', 'astro_web') OR platform = 'web')::bigint AS web
         FROM public.notification_device_tokens`
      ),
    ]);

    return json({
      items: items.rows,
      total: Number(total.rows[0]?.count || 0),
      limit,
      offset,
      stats: {
        total: Number(stats.rows[0]?.total || 0),
        active: Number(stats.rows[0]?.active || 0),
        invalid: Number(stats.rows[0]?.invalid || 0),
        android: Number(stats.rows[0]?.android || 0),
        ios: Number(stats.rows[0]?.ios || 0),
        web: Number(stats.rows[0]?.web || 0),
      },
    });
  } catch (error: any) {
    return json({ error: { message: error.message || 'Notification devices could not be loaded' } }, 500);
  }
};

export const PATCH: APIRoute = async ({ request }) => {
  const body = await readJsonBody(request);
  try {
    const access = await requireNotificationAccess(request, body);
    if (access.response) return access.response;

    const id = normalizeText(body.id);
    if (!id) return json({ error: { message: 'Device id required' } }, 400);

    const action = normalizeText(body.action);
    if (action === 'invalidate') {
      await dbQuery(
        `UPDATE public.notification_device_tokens
         SET is_active = false,
             invalidated_at = now(),
             invalid_reason = COALESCE(NULLIF($2, ''), 'manual'),
             updated_at = now()
         WHERE id = $1::bigint`,
        [id, normalizeText(body.invalid_reason)]
      );
    } else if (action === 'activate') {
      await dbQuery(
        `UPDATE public.notification_device_tokens
         SET is_active = true,
             invalidated_at = NULL,
             invalid_reason = NULL,
             updated_at = now()
         WHERE id = $1::bigint`,
        [id]
      );
    } else {
      const payload = devicePayload(body);
      payload.updated_at = new Date().toISOString();
      const set = sqlSetClause(payload);
      if (!set.keys.length) return json({ error: { message: 'No changes' } }, 400);
      await dbQuery(
        `UPDATE public.notification_device_tokens SET ${set.clause} WHERE id = $${set.values.length + 1}::bigint`,
        [...set.values, id]
      );
    }

    return json({ device: await selectedDevice(id) });
  } catch (error: any) {
    return json({ error: { message: error.message || 'Notification device could not be updated' } }, 500);
  }
};

export const DELETE: APIRoute = async ({ request, url }) => {
  const body = await readJsonBody(request);
  try {
    const access = await requireNotificationAccess(request, body);
    if (access.response) return access.response;
    const id = normalizeText(body.id || url.searchParams.get('id'));
    if (!id) return json({ error: { message: 'Device id required' } }, 400);
    await dbQuery('DELETE FROM public.notification_device_tokens WHERE id = $1::bigint', [id]);
    return json({ ok: true });
  } catch (error: any) {
    return json({ error: { message: error.message || 'Notification device could not be deleted' } }, 500);
  }
};
