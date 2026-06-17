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
  id::text,
  user_id::text,
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
  token_refreshed_at,
  invalidated_at,
  invalid_reason,
  created_at,
  updated_at
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
     FROM public.notification_device_tokens
     WHERE id = $1::bigint`,
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
      where.push(`(platform = $${values.length} OR app_surface = $${values.length})`);
    }
    if (search) {
      values.push(`%${search}%`);
      where.push(`(fcm_token ILIKE $${values.length} OR app_surface ILIKE $${values.length} OR device_model ILIKE $${values.length} OR app_version ILIKE $${values.length})`);
    }

    const whereSql = where.length ? `WHERE ${where.join(' AND ')}` : '';
    const [items, total, stats] = await Promise.all([
      dbQuery(
        `SELECT ${DEVICE_SELECT}
         FROM public.notification_device_tokens
         ${whereSql}
         ORDER BY last_seen_at DESC
         LIMIT $${values.length + 1} OFFSET $${values.length + 2}`,
        [...values, limit, offset]
      ),
      dbQuery<{ count: string }>(
        `SELECT COUNT(*)::bigint AS count FROM public.notification_device_tokens ${whereSql}`,
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
