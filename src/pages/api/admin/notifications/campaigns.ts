import type { APIRoute } from 'astro';
import { json } from '@/lib/server/appDb';
import { dbQuery } from '@/lib/server/supabaseDb';
import { processNotificationOutbox } from '@/lib/server/notifications/processor';
import {
  normalizeJsonObject,
  normalizeNumberArray,
  normalizePriority,
  normalizeStatus,
  normalizeStringArray,
  normalizeTargetType,
  normalizeText,
  numericLimit,
  numericOffset,
  readJsonBody,
  requireNotificationAccess,
  sqlSetClause,
} from '@/lib/server/notifications/api';

export const prerender = false;

const CAMPAIGN_SELECT = `
  c.id::text AS id,
  c.campaign_name,
  c.template_id::text,
  c.target_type,
  c.target_platforms,
  c.target_topics,
  c.target_user_ids,
  c.target_token_ids,
  c.title,
  c.body,
  c.image_url,
  c.deep_link,
  c.data_json,
  c.priority,
  c.ttl_seconds,
  c.channel_id,
  c.status,
  c.recipient_count,
  c.queued_count,
  c.sent_count,
  c.failed_count,
  c.opened_count,
  c.clicked_count,
  c.scheduled_start_at,
  c.started_at,
  c.finished_at,
  c.idempotency_key,
  c.created_at,
  c.updated_at,
  t.template_name
`;

const FIELD_MAP: Record<string, string> = {
  campaign_name: 'campaign_name',
  template_id: 'template_id',
  target_type: 'target_type',
  title: 'title',
  body: 'body',
  image_url: 'image_url',
  deep_link: 'deep_link',
  priority: 'priority',
  ttl_seconds: 'ttl_seconds',
  channel_id: 'channel_id',
  status: 'status',
  scheduled_start_at: 'scheduled_start_at',
  idempotency_key: 'idempotency_key',
};

function campaignPayload(body: Record<string, any>) {
  const payload: Record<string, any> = {};
  for (const [clientKey, dbKey] of Object.entries(FIELD_MAP)) {
    if (Object.prototype.hasOwnProperty.call(body, clientKey)) payload[dbKey] = body[clientKey];
  }
  if (Object.prototype.hasOwnProperty.call(body, 'target_platforms')) {
    payload.target_platforms = normalizeStringArray(body.target_platforms);
  }
  if (Object.prototype.hasOwnProperty.call(body, 'target_topics')) {
    payload.target_topics = normalizeStringArray(body.target_topics);
  }
  if (Object.prototype.hasOwnProperty.call(body, 'target_user_ids')) {
    payload.target_user_ids = normalizeStringArray(body.target_user_ids);
  }
  if (Object.prototype.hasOwnProperty.call(body, 'target_token_ids')) {
    payload.target_token_ids = normalizeNumberArray(body.target_token_ids);
  }
  if (Object.prototype.hasOwnProperty.call(body, 'data_json')) {
    payload.data_json = normalizeJsonObject(body.data_json);
  }
  if (Object.prototype.hasOwnProperty.call(payload, 'target_type')) {
    payload.target_type = normalizeTargetType(payload.target_type);
  }
  if (Object.prototype.hasOwnProperty.call(payload, 'priority')) {
    payload.priority = normalizePriority(payload.priority);
  }
  if (Object.prototype.hasOwnProperty.call(payload, 'status')) {
    payload.status = normalizeStatus(payload.status);
  }
  if (Object.prototype.hasOwnProperty.call(payload, 'ttl_seconds')) {
    const ttl = Number(payload.ttl_seconds);
    payload.ttl_seconds = Number.isFinite(ttl) ? Math.max(0, Math.min(Math.floor(ttl), 2419200)) : 3600;
  }
  if (Object.prototype.hasOwnProperty.call(payload, 'template_id') && !normalizeText(payload.template_id)) {
    payload.template_id = null;
  }
  if (Object.prototype.hasOwnProperty.call(payload, 'scheduled_start_at') && !normalizeText(payload.scheduled_start_at)) {
    payload.scheduled_start_at = null;
  }
  if (Object.prototype.hasOwnProperty.call(payload, 'idempotency_key') && !normalizeText(payload.idempotency_key)) {
    payload.idempotency_key = null;
  }
  return payload;
}

async function selectedCampaign(id: string) {
  const result = await dbQuery(
    `SELECT ${CAMPAIGN_SELECT}
     FROM public.notification_campaigns c
     LEFT JOIN public.notification_templates t ON t.id = c.template_id
     WHERE c.id = $1::bigint`,
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
    const status = normalizeText(url.searchParams.get('status'));
    const adminOnly = ['1', 'true', 'yes'].includes(normalizeText(url.searchParams.get('admin_only')).toLowerCase());
    const values: any[] = [];
    const where: string[] = [];

    if (status && status !== 'all') {
      values.push(status);
      where.push(`c.status = $${values.length}`);
    }
    if (search) {
      values.push(`%${search}%`);
      where.push(`(c.campaign_name ILIKE $${values.length} OR c.title ILIKE $${values.length} OR c.body ILIKE $${values.length})`);
    }
    if (adminOnly) {
      where.push(`(
        c.data_json->>'adminOnly' = 'true'
        OR c.data_json->>'admin_only' = 'true'
      )`);
    }

    const whereSql = where.length ? `WHERE ${where.join(' AND ')}` : '';
    const [items, total, stats] = await Promise.all([
      dbQuery(
        `SELECT ${CAMPAIGN_SELECT}
         FROM public.notification_campaigns c
         LEFT JOIN public.notification_templates t ON t.id = c.template_id
         ${whereSql}
         ORDER BY c.created_at DESC
         LIMIT $${values.length + 1} OFFSET $${values.length + 2}`,
        [...values, limit, offset]
      ),
      dbQuery<{ count: string }>(
        `SELECT COUNT(*)::bigint AS count FROM public.notification_campaigns c ${whereSql}`,
        values
      ),
      dbQuery(
        `SELECT
          COUNT(*)::bigint AS total,
          COUNT(*) FILTER (WHERE status = 'sending')::bigint AS sending,
          COUNT(*) FILTER (WHERE status = 'scheduled')::bigint AS scheduled,
          COUNT(*) FILTER (WHERE status = 'completed')::bigint AS completed,
          COALESCE(SUM(sent_count), 0)::bigint AS sent,
          COALESCE(SUM(failed_count), 0)::bigint AS failed
         FROM public.notification_campaigns`
      ),
    ]);

    return json({
      items: items.rows,
      total: Number(total.rows[0]?.count || 0),
      limit,
      offset,
      stats: {
        total: Number(stats.rows[0]?.total || 0),
        sending: Number(stats.rows[0]?.sending || 0),
        scheduled: Number(stats.rows[0]?.scheduled || 0),
        completed: Number(stats.rows[0]?.completed || 0),
        sent: Number(stats.rows[0]?.sent || 0),
        failed: Number(stats.rows[0]?.failed || 0),
      },
    });
  } catch (error: any) {
    return json({ error: { message: error.message || 'Notification campaigns could not be loaded' } }, 500);
  }
};

export const POST: APIRoute = async ({ request }) => {
  const body = await readJsonBody(request);
  try {
    const access = await requireNotificationAccess(request, body);
    if (access.response) return access.response;

    const payload = campaignPayload(body);
    payload.campaign_name = normalizeText(payload.campaign_name);
    payload.title = normalizeText(payload.title);
    payload.body = normalizeText(payload.body);
    payload.target_type = normalizeTargetType(payload.target_type);
    payload.priority = normalizePriority(payload.priority);
    payload.status = normalizeStatus(payload.status);
    payload.channel_id = normalizeText(payload.channel_id) || 'pateez_general';
    payload.created_by = access.session!.user.id;
    payload.updated_by = access.session!.user.id;
    payload.updated_at = new Date().toISOString();

    if (!payload.campaign_name || !payload.title || !payload.body) {
      return json({ error: { message: 'Campaign name, title and body are required' } }, 400);
    }

    const keys = Object.keys(payload);
    const result = await dbQuery(
      `INSERT INTO public.notification_campaigns (${keys.join(', ')})
       VALUES (${keys.map((_, index) => `$${index + 1}`).join(', ')})
       RETURNING id::text`,
      keys.map((key) => payload[key])
    );

    return json({ campaign: await selectedCampaign(String(result.rows[0]?.id || '')) });
  } catch (error: any) {
    return json({ error: { message: error.message || 'Notification campaign could not be saved' } }, 500);
  }
};

export const PATCH: APIRoute = async ({ request }) => {
  const body = await readJsonBody(request);
  try {
    const access = await requireNotificationAccess(request, body);
    if (access.response) return access.response;

    const id = normalizeText(body.id);
    if (!id) return json({ error: { message: 'Campaign id required' } }, 400);

    const action = normalizeText(body.action);
    if (action) {
      if (action === 'schedule') {
        const scheduled = normalizeText(body.scheduled_start_at);
        if (!scheduled) return json({ error: { message: 'Schedule date required' } }, 400);
        await dbQuery(
          `UPDATE public.notification_campaigns
           SET status = 'scheduled',
               scheduled_start_at = $1,
               updated_at = now(),
               updated_by = $3::uuid
           WHERE id = $2::bigint`,
          [scheduled, id, access.session!.user.id]
        );
      } else if (action === 'dispatch') {
        await dbQuery(
          `UPDATE public.notification_campaigns
           SET status = 'sending',
               started_at = COALESCE(started_at, now()),
               scheduled_start_at = NULL,
               updated_at = now(),
               updated_by = $2::uuid
           WHERE id = $1::bigint`,
          [id, access.session!.user.id]
        );
        const result = await processNotificationOutbox(100);
        return json({ campaign: await selectedCampaign(id), dispatch: result });
      } else {
        const actionSql: Record<string, string> = {
          pause: "status = 'paused'",
          resume: "status = 'sending', started_at = COALESCE(started_at, now())",
          cancel: "status = 'cancelled', finished_at = COALESCE(finished_at, now())",
          complete: "status = 'completed', finished_at = COALESCE(finished_at, now())",
          remove_schedule: "status = 'draft', scheduled_start_at = NULL",
        };
        if (!actionSql[action]) return json({ error: { message: 'Unsupported campaign action' } }, 400);
        await dbQuery(
          `UPDATE public.notification_campaigns
           SET ${actionSql[action]},
               updated_at = now(),
               updated_by = $2::uuid
           WHERE id = $1::bigint`,
          [id, access.session!.user.id]
        );
      }
    } else {
      const payload = campaignPayload(body);
      payload.updated_by = access.session!.user.id;
      payload.updated_at = new Date().toISOString();
      const set = sqlSetClause(payload);
      if (!set.keys.length) return json({ error: { message: 'No changes' } }, 400);
      await dbQuery(
        `UPDATE public.notification_campaigns SET ${set.clause} WHERE id = $${set.values.length + 1}::bigint`,
        [...set.values, id]
      );
    }

    return json({ campaign: await selectedCampaign(id) });
  } catch (error: any) {
    return json({ error: { message: error.message || 'Notification campaign could not be updated' } }, 500);
  }
};

export const DELETE: APIRoute = async ({ request, url }) => {
  const body = await readJsonBody(request);
  try {
    const access = await requireNotificationAccess(request, body);
    if (access.response) return access.response;
    const id = normalizeText(body.id || url.searchParams.get('id'));
    if (!id) return json({ error: { message: 'Campaign id required' } }, 400);
    await dbQuery('DELETE FROM public.notification_campaigns WHERE id = $1::bigint', [id]);
    return json({ ok: true });
  } catch (error: any) {
    return json({ error: { message: error.message || 'Notification campaign could not be deleted' } }, 500);
  }
};
