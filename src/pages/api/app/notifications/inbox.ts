import type { APIRoute } from 'astro';
import { getSessionFromRequest, json } from '@/lib/server/appDb';
import { dbQuery } from '@/lib/server/supabaseDb';
import {
  normalizeText,
  numericLimit,
  numericOffset,
  readJsonBody,
} from '@/lib/server/notifications/api';

export const prerender = false;

const INBOX_SELECT = `
  id::text,
  campaign_id::text,
  outbox_id::text,
  title,
  body,
  image_url,
  deep_link,
  data_json,
  read_at,
  opened_at,
  clicked_at,
  expires_at,
  created_at,
  updated_at
`;

export const GET: APIRoute = async ({ request, url }) => {
  try {
    const session = await getSessionFromRequest(request);
    if (!session?.user?.id) return json({ error: { message: 'Auth required' } }, 401);

    const limit = numericLimit(url.searchParams.get('limit'), 25, 100);
    const offset = numericOffset(url.searchParams.get('offset'));
    const unreadOnly = normalizeText(url.searchParams.get('unread')) === 'true';
    const values: any[] = [session.user.id];
    const where = [
      'user_id = $1::uuid',
      '(expires_at IS NULL OR expires_at > now())',
    ];
    if (unreadOnly) where.push('read_at IS NULL');

    const whereSql = `WHERE ${where.join(' AND ')}`;
    const [items, total, unread] = await Promise.all([
      dbQuery(
        `SELECT ${INBOX_SELECT}
         FROM public.notification_inbox
         ${whereSql}
         ORDER BY created_at DESC
         LIMIT $${values.length + 1} OFFSET $${values.length + 2}`,
        [...values, limit, offset]
      ),
      dbQuery<{ count: string }>(
        `SELECT COUNT(*)::bigint AS count
         FROM public.notification_inbox
         ${whereSql}`,
        values
      ),
      dbQuery<{ count: string }>(
        `SELECT COUNT(*)::bigint AS count
         FROM public.notification_inbox
         WHERE user_id = $1::uuid
           AND read_at IS NULL
           AND (expires_at IS NULL OR expires_at > now())`,
        [session.user.id]
      ),
    ]);

    return json({
      items: items.rows,
      total: Number(total.rows[0]?.count || 0),
      unread: Number(unread.rows[0]?.count || 0),
      limit,
      offset,
    });
  } catch (error: any) {
    return json({ error: { message: error.message || 'Notifications could not be loaded' } }, 500);
  }
};

export const PATCH: APIRoute = async ({ request }) => {
  const body = await readJsonBody(request);
  try {
    const session = await getSessionFromRequest(request, body);
    if (!session?.user?.id) return json({ error: { message: 'Auth required' } }, 401);

    const id = normalizeText(body.id);
    const action = normalizeText(body.action || 'read');
    if (!id && action !== 'read-all') return json({ error: { message: 'Notification id required' } }, 400);

    if (action === 'read-all') {
      await dbQuery(
        `UPDATE public.notification_inbox
         SET read_at = COALESCE(read_at, now()),
             updated_at = now()
         WHERE user_id = $1::uuid
           AND read_at IS NULL`,
        [session.user.id]
      );
      return json({ ok: true });
    }

    const column = action === 'click'
      ? 'clicked_at'
      : action === 'open'
      ? 'opened_at'
      : 'read_at';

    const result = await dbQuery(
      `UPDATE public.notification_inbox
       SET ${column} = COALESCE(${column}, now()),
           read_at = COALESCE(read_at, now()),
           updated_at = now()
       WHERE id = $1::bigint
         AND user_id = $2::uuid
       RETURNING ${INBOX_SELECT}`,
      [id, session.user.id]
    );

    const row = result.rows[0] || null;
    if (!row) return json({ error: { message: 'Notification not found' } }, 404);

    await dbQuery(
      `INSERT INTO public.notification_events (
         campaign_id, outbox_id, user_id, event_type, metadata
       )
       VALUES ($1::bigint, $2::bigint, $3::uuid, $4, '{}'::jsonb)`,
      [
        row.campaign_id || null,
        row.outbox_id || null,
        session.user.id,
        action === 'click' ? 'click' : action === 'open' ? 'open' : 'read',
      ]
    );

    return json({ item: row });
  } catch (error: any) {
    return json({ error: { message: error.message || 'Notification could not be updated' } }, 500);
  }
};
