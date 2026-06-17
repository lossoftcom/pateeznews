import type { APIRoute } from 'astro';
import { json } from '@/lib/server/appDb';
import { dbQuery } from '@/lib/server/supabaseDb';
import {
  normalizeJsonObject,
  normalizePriority,
  normalizeText,
  numericLimit,
  numericOffset,
  readJsonBody,
  requireNotificationAccess,
  sqlSetClause,
} from '@/lib/server/notifications/api';

export const prerender = false;

const TEMPLATE_SELECT = `
  id::text,
  template_name,
  category,
  title,
  body,
  image_url,
  deep_link,
  data_json,
  language_code,
  priority,
  ttl_seconds,
  channel_id,
  is_ready,
  is_active,
  created_at,
  updated_at
`;

const FIELD_MAP: Record<string, string> = {
  template_name: 'template_name',
  category: 'category',
  title: 'title',
  body: 'body',
  image_url: 'image_url',
  deep_link: 'deep_link',
  language_code: 'language_code',
  priority: 'priority',
  ttl_seconds: 'ttl_seconds',
  channel_id: 'channel_id',
  is_ready: 'is_ready',
  is_active: 'is_active',
};

function templatePayload(body: Record<string, any>) {
  const payload: Record<string, any> = {};
  for (const [clientKey, dbKey] of Object.entries(FIELD_MAP)) {
    if (Object.prototype.hasOwnProperty.call(body, clientKey)) payload[dbKey] = body[clientKey];
  }
  if (Object.prototype.hasOwnProperty.call(body, 'data_json')) {
    payload.data_json = normalizeJsonObject(body.data_json);
  }
  if (Object.prototype.hasOwnProperty.call(payload, 'priority')) {
    payload.priority = normalizePriority(payload.priority);
  }
  if (Object.prototype.hasOwnProperty.call(payload, 'ttl_seconds')) {
    const ttl = Number(payload.ttl_seconds);
    payload.ttl_seconds = Number.isFinite(ttl) ? Math.max(0, Math.min(Math.floor(ttl), 2419200)) : 3600;
  }
  return payload;
}

async function selectedTemplate(id: string) {
  const result = await dbQuery(
    `SELECT ${TEMPLATE_SELECT}
     FROM public.notification_templates
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
    const values: any[] = [];
    const where: string[] = [];

    if (search) {
      values.push(`%${search}%`);
      where.push(`(template_name ILIKE $${values.length} OR title ILIKE $${values.length} OR body ILIKE $${values.length} OR category ILIKE $${values.length})`);
    }

    const whereSql = where.length ? `WHERE ${where.join(' AND ')}` : '';
    const [items, total, stats] = await Promise.all([
      dbQuery(
        `SELECT ${TEMPLATE_SELECT}
         FROM public.notification_templates
         ${whereSql}
         ORDER BY updated_at DESC
         LIMIT $${values.length + 1} OFFSET $${values.length + 2}`,
        [...values, limit, offset]
      ),
      dbQuery<{ count: string }>(
        `SELECT COUNT(*)::bigint AS count FROM public.notification_templates ${whereSql}`,
        values
      ),
      dbQuery(
        `SELECT
          COUNT(*)::bigint AS total,
          COUNT(*) FILTER (WHERE is_active IS TRUE)::bigint AS active,
          COUNT(*) FILTER (WHERE is_ready IS TRUE)::bigint AS ready
         FROM public.notification_templates`
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
        ready: Number(stats.rows[0]?.ready || 0),
      },
    });
  } catch (error: any) {
    return json({ error: { message: error.message || 'Notification templates could not be loaded' } }, 500);
  }
};

export const POST: APIRoute = async ({ request }) => {
  const body = await readJsonBody(request);
  try {
    const access = await requireNotificationAccess(request, body);
    if (access.response) return access.response;

    const payload = templatePayload(body);
    payload.template_name = normalizeText(payload.template_name);
    payload.category = normalizeText(payload.category) || 'general';
    payload.title = normalizeText(payload.title);
    payload.body = normalizeText(payload.body);
    payload.language_code = normalizeText(payload.language_code) || 'tr';
    payload.priority = normalizePriority(payload.priority);
    payload.channel_id = normalizeText(payload.channel_id) || 'pateez_general';
    payload.created_by = access.session!.user.id;
    payload.updated_by = access.session!.user.id;
    payload.updated_at = new Date().toISOString();

    if (!payload.template_name || !payload.title || !payload.body) {
      return json({ error: { message: 'Template name, title and body are required' } }, 400);
    }

    const keys = Object.keys(payload);
    const result = await dbQuery(
      `INSERT INTO public.notification_templates (${keys.join(', ')})
       VALUES (${keys.map((_, index) => `$${index + 1}`).join(', ')})
       RETURNING id::text`,
      keys.map((key) => payload[key])
    );
    return json({ template: await selectedTemplate(String(result.rows[0]?.id || '')) });
  } catch (error: any) {
    return json({ error: { message: error.message || 'Notification template could not be saved' } }, 500);
  }
};

export const PATCH: APIRoute = async ({ request }) => {
  const body = await readJsonBody(request);
  try {
    const access = await requireNotificationAccess(request, body);
    if (access.response) return access.response;

    const id = normalizeText(body.id);
    if (!id) return json({ error: { message: 'Template id required' } }, 400);
    const payload = templatePayload(body);
    payload.updated_by = access.session!.user.id;
    payload.updated_at = new Date().toISOString();
    const set = sqlSetClause(payload);
    if (!set.keys.length) return json({ error: { message: 'No changes' } }, 400);
    await dbQuery(
      `UPDATE public.notification_templates SET ${set.clause} WHERE id = $${set.values.length + 1}::bigint`,
      [...set.values, id]
    );
    return json({ template: await selectedTemplate(id) });
  } catch (error: any) {
    return json({ error: { message: error.message || 'Notification template could not be updated' } }, 500);
  }
};

export const DELETE: APIRoute = async ({ request, url }) => {
  const body = await readJsonBody(request);
  try {
    const access = await requireNotificationAccess(request, body);
    if (access.response) return access.response;
    const id = normalizeText(body.id || url.searchParams.get('id'));
    if (!id) return json({ error: { message: 'Template id required' } }, 400);
    await dbQuery('DELETE FROM public.notification_templates WHERE id = $1::bigint', [id]);
    return json({ ok: true });
  } catch (error: any) {
    return json({ error: { message: error.message || 'Notification template could not be deleted' } }, 500);
  }
};
