import type { APIRoute } from 'astro';
import { getSessionFromRequest, json } from '@/lib/server/appDb';
import { dbQuery } from '@/lib/server/supabaseDb';
import {
  normalizeJsonObject,
  normalizeText,
  readJsonBody,
} from '@/lib/server/notifications/api';

export const prerender = false;

const EVENT_TYPES = new Set(['open', 'click', 'read', 'dismiss', 'unsubscribe']);

async function refreshCampaignEventCounts(campaignId: string) {
  if (!campaignId) return;
  await dbQuery(
    `UPDATE public.notification_campaigns c
     SET opened_count = counts.opened,
         clicked_count = counts.clicked,
         updated_at = now()
     FROM (
       SELECT
         COUNT(DISTINCT outbox_id) FILTER (WHERE event_type = 'open')::int AS opened,
         COUNT(DISTINCT outbox_id) FILTER (WHERE event_type = 'click')::int AS clicked
       FROM public.notification_events
       WHERE campaign_id = $1::bigint
     ) counts
     WHERE c.id = $1::bigint`,
    [campaignId]
  );
}

export const POST: APIRoute = async ({ request }) => {
  const body = await readJsonBody(request);
  try {
    const session = await getSessionFromRequest(request, body);
    const eventType = EVENT_TYPES.has(normalizeText(body.event_type || body.eventType))
      ? normalizeText(body.event_type || body.eventType)
      : 'open';
    const campaignId = normalizeText(body.campaign_id || body.campaignId);
    const outboxId = normalizeText(body.outbox_id || body.outboxId || body.notification_id || body.notificationId);
    const deviceTokenId = normalizeText(body.device_token_id || body.deviceTokenId);
    const inboxId = normalizeText(body.inbox_id || body.inboxId);

    if (!campaignId && !outboxId && !deviceTokenId && !inboxId) {
      return json({ error: { message: 'Notification event target required' } }, 400);
    }

    let resolvedCampaignId = campaignId;
    let resolvedOutboxId = outboxId;

    if (inboxId && session?.user?.id) {
      const column = eventType === 'click' ? 'clicked_at' : eventType === 'open' ? 'opened_at' : 'read_at';
      const result = await dbQuery(
        `UPDATE public.notification_inbox
         SET ${column} = COALESCE(${column}, now()),
             read_at = COALESCE(read_at, now()),
             updated_at = now()
         WHERE id = $1::bigint
           AND user_id = $2::uuid
         RETURNING campaign_id::text, outbox_id::text`,
        [inboxId, session.user.id]
      );
      resolvedCampaignId = resolvedCampaignId || String(result.rows[0]?.campaign_id || '');
      resolvedOutboxId = resolvedOutboxId || String(result.rows[0]?.outbox_id || '');
    }

    await dbQuery(
      `INSERT INTO public.notification_events (
        campaign_id,
        outbox_id,
        device_token_id,
        user_id,
        event_type,
        metadata
      )
      VALUES ($1::bigint, $2::bigint, $3::bigint, $4::uuid, $5, $6::jsonb)`,
      [
        resolvedCampaignId || null,
        resolvedOutboxId || null,
        deviceTokenId || null,
        session?.user?.id || null,
        eventType,
        JSON.stringify(normalizeJsonObject(body.metadata)),
      ]
    );

    await refreshCampaignEventCounts(resolvedCampaignId);
    return json({ ok: true });
  } catch (error: any) {
    return json({ error: { message: error.message || 'Notification event could not be saved' } }, 500);
  }
};
