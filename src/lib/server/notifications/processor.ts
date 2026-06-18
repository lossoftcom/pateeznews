import { dbQuery } from '@/lib/server/supabaseDb';
import { resolveFirebaseCredentials, sendFcmMessage } from './fcm';

type OutboxRow = {
  id: string;
  campaign_id: string;
  device_token_id: string | null;
  user_id: string | null;
  fcm_token: string;
  title: string;
  body: string;
  image_url: string;
  deep_link: string;
  data_json: Record<string, unknown>;
  priority: string;
  ttl_seconds: number;
  channel_id: string;
  attempts: number;
  max_attempts: number;
};

export type NotificationOutboxResult = {
  queued: number;
  processed: number;
  sent: number;
  failed: number;
  invalidTokens: number;
  error?: string;
};

async function activateScheduledCampaigns() {
  await dbQuery(
    `UPDATE public.notification_campaigns
     SET status = 'sending',
         started_at = COALESCE(started_at, now()),
         updated_at = now()
     WHERE status = 'scheduled'
       AND scheduled_start_at <= now()`
  );
}

async function queueCampaignOutbox(limit: number) {
  const campaigns = await dbQuery<{ id: string }>(
    `SELECT id::text
     FROM public.notification_campaigns
     WHERE status = 'sending'
     ORDER BY COALESCE(started_at, created_at) ASC
     LIMIT $1`,
    [Math.max(1, Math.min(limit, 25))]
  );

  let queued = 0;
  for (const campaign of campaigns.rows) {
    const inserted = await dbQuery<{ id: string }>(
      `INSERT INTO public.notification_outbox (
        campaign_id,
        device_token_id,
        user_id,
        fcm_token,
        title,
        body,
        image_url,
        deep_link,
        data_json,
        priority,
        ttl_seconds,
        channel_id
      )
      SELECT
        c.id,
        dt.id,
        dt.user_id,
        dt.fcm_token,
        c.title,
        c.body,
        c.image_url,
        c.deep_link,
        jsonb_build_object(
          'campaignId', c.id::text,
          'deepLink', c.deep_link,
          'type', 'notification'
        ) || c.data_json,
        c.priority,
        c.ttl_seconds,
        c.channel_id
      FROM public.notification_campaigns c
      JOIN public.notification_device_tokens dt
        ON dt.is_active IS TRUE
       AND dt.invalidated_at IS NULL
       AND dt.permission_status IN ('authorized', 'granted', 'provisional', 'unknown')
      WHERE c.id = $1::bigint
        AND (
          c.target_type = 'all'
          OR (
            c.target_type = 'platform'
            AND (
              array_length(c.target_platforms, 1) IS NULL
              OR dt.platform = ANY(c.target_platforms)
              OR dt.app_surface = ANY(c.target_platforms)
            )
          )
          OR (
            c.target_type = 'topic'
            AND dt.topics && c.target_topics
          )
          OR (
            c.target_type = 'user'
            AND dt.user_id = ANY(c.target_user_ids)
          )
          OR (
            c.target_type = 'token'
            AND dt.id = ANY(c.target_token_ids)
          )
          OR (
            c.target_type = 'segment'
            AND (
              array_length(c.target_platforms, 1) IS NULL
              OR dt.platform = ANY(c.target_platforms)
              OR dt.app_surface = ANY(c.target_platforms)
            )
            AND (
              array_length(c.target_topics, 1) IS NULL
              OR dt.topics && c.target_topics
            )
          )
        )
      ON CONFLICT (campaign_id, device_token_id) DO NOTHING
      RETURNING id::text`,
      [campaign.id]
    );

    queued += inserted.rowCount || 0;

    await dbQuery(
      `INSERT INTO public.notification_inbox (
        campaign_id,
        outbox_id,
        user_id,
        title,
        body,
        image_url,
        deep_link,
        data_json,
        expires_at
      )
      SELECT
        o.campaign_id,
        o.id,
        o.user_id,
        o.title,
        o.body,
        o.image_url,
        o.deep_link,
        o.data_json,
        CASE WHEN o.ttl_seconds > 0 THEN now() + make_interval(secs => o.ttl_seconds) ELSE NULL END
      FROM public.notification_outbox o
      WHERE o.campaign_id = $1::bigint
        AND o.user_id IS NOT NULL
      ON CONFLICT (user_id, outbox_id) DO NOTHING`,
      [campaign.id]
    );

    await refreshCampaignCounts(campaign.id);
  }

  return queued;
}

async function reserveOutbox(limit: number) {
  const result = await dbQuery<OutboxRow>(
    `UPDATE public.notification_outbox
     SET status = 'sending',
         attempts = attempts + 1,
         updated_at = now()
     WHERE id IN (
       SELECT id
       FROM public.notification_outbox
       WHERE status IN ('queued', 'failed')
         AND attempts < max_attempts
         AND COALESCE(error_code, '') <> 'THIRD_PARTY_AUTH_ERROR'
         AND next_attempt_at <= now()
       ORDER BY next_attempt_at ASC, created_at ASC
       LIMIT $1
       FOR UPDATE SKIP LOCKED
     )
     RETURNING
       id::text,
       campaign_id::text,
       device_token_id::text,
       user_id::text,
       fcm_token,
       title,
       body,
       image_url,
       deep_link,
       data_json,
       priority,
       ttl_seconds,
       channel_id,
       attempts,
       max_attempts`,
    [Math.max(1, Math.min(limit, 500))]
  );
  return result.rows;
}

function retryDelaySeconds(attempts: number, retryAfterSeconds?: number) {
  if (retryAfterSeconds !== undefined) return Math.max(5, retryAfterSeconds);
  const base = Math.min(3600, Math.max(30, Math.pow(2, Math.max(0, attempts - 1)) * 30));
  const jitter = Math.floor(Math.random() * 15);
  return base + jitter;
}

function isNonRetryableProviderAuthError(errorCode: string) {
  return String(errorCode || '').toUpperCase() === 'THIRD_PARTY_AUTH_ERROR';
}

async function markSuccess(row: OutboxRow, messageId: string) {
  await dbQuery(
    `UPDATE public.notification_outbox
     SET status = 'sent',
         sent_at = now(),
         fcm_message_id = $2,
         error_code = NULL,
         error_message = NULL,
         updated_at = now()
     WHERE id = $1::bigint`,
    [row.id, messageId]
  );

  await dbQuery(
    `INSERT INTO public.notification_events (
       campaign_id, outbox_id, device_token_id, user_id, event_type, metadata
     )
     VALUES ($1::bigint, $2::bigint, $3::bigint, $4::uuid, 'sent', $5::jsonb)`,
    [
      row.campaign_id,
      row.id,
      row.device_token_id || null,
      row.user_id || null,
      JSON.stringify({ fcmMessageId: messageId }),
    ]
  );
}

async function markFailure(
  row: OutboxRow,
  errorCode: string,
  errorMessage: string,
  invalidToken: boolean,
  retryAfterSeconds?: number
) {
  if (invalidToken && row.device_token_id) {
    await dbQuery(
      `UPDATE public.notification_device_tokens
       SET is_active = false,
           invalidated_at = now(),
           invalid_reason = $2,
           updated_at = now()
       WHERE id = $1::bigint`,
      [row.device_token_id, errorCode || errorMessage]
    );
  }

  const finalFailure =
    invalidToken ||
    isNonRetryableProviderAuthError(errorCode) ||
    row.attempts >= row.max_attempts;
  const nextAttemptAt = finalFailure
    ? null
    : new Date(Date.now() + retryDelaySeconds(row.attempts, retryAfterSeconds) * 1000).toISOString();

  await dbQuery(
    `UPDATE public.notification_outbox
     SET status = $2,
         error_code = $3,
         error_message = $4,
         next_attempt_at = COALESCE($5::timestamptz, next_attempt_at),
         updated_at = now()
     WHERE id = $1::bigint`,
    [
      row.id,
      invalidToken ? 'invalid_token' : finalFailure ? 'failed' : 'queued',
      errorCode,
      errorMessage,
      nextAttemptAt,
    ]
  );

  await dbQuery(
    `INSERT INTO public.notification_events (
       campaign_id, outbox_id, device_token_id, user_id, event_type, metadata
     )
     VALUES ($1::bigint, $2::bigint, $3::bigint, $4::uuid, $5, $6::jsonb)`,
    [
      row.campaign_id,
      row.id,
      row.device_token_id || null,
      row.user_id || null,
      invalidToken ? 'invalid-token' : 'fail',
      JSON.stringify({ errorCode, errorMessage, attempts: row.attempts }),
    ]
  );
}

async function refreshCampaignCounts(campaignId: string) {
  await dbQuery(
    `UPDATE public.notification_campaigns c
     SET recipient_count = counts.total,
         queued_count = counts.queued,
         sent_count = counts.sent,
         failed_count = counts.failed,
         updated_at = now()
     FROM (
       SELECT
         COUNT(*)::int AS total,
         COUNT(*) FILTER (WHERE status IN ('queued', 'sending'))::int AS queued,
         COUNT(*) FILTER (WHERE status = 'sent')::int AS sent,
         COUNT(*) FILTER (WHERE status IN ('failed', 'invalid_token'))::int AS failed
       FROM public.notification_outbox
       WHERE campaign_id = $1::bigint
     ) counts
     WHERE c.id = $1::bigint`,
    [campaignId]
  );

  await dbQuery(
    `UPDATE public.notification_campaigns c
     SET status = CASE
           WHEN failed_count > 0 AND sent_count = 0 THEN 'failed'
           ELSE 'completed'
         END,
         finished_at = COALESCE(finished_at, now()),
         updated_at = now()
     WHERE c.id = $1::bigint
       AND c.status = 'sending'
       AND c.recipient_count > 0
       AND NOT EXISTS (
         SELECT 1
         FROM public.notification_outbox o
         WHERE o.campaign_id = c.id
           AND (
             o.status IN ('queued', 'sending')
             OR (
               o.status = 'failed'
               AND o.attempts < o.max_attempts
               AND COALESCE(o.error_code, '') <> 'THIRD_PARTY_AUTH_ERROR'
             )
           )
       )`,
    [campaignId]
  );
}

export async function processNotificationOutbox(limit = 100): Promise<NotificationOutboxResult> {
  await activateScheduledCampaigns();
  const queued = await queueCampaignOutbox(limit);

  let credentials;
  try {
    credentials = await resolveFirebaseCredentials();
  } catch (error: any) {
    return {
      queued,
      processed: 0,
      sent: 0,
      failed: 0,
      invalidTokens: 0,
      error: error?.message || 'Firebase credentials are missing',
    };
  }

  const rows = await reserveOutbox(limit);
  const campaignIds = new Set<string>();
  let sent = 0;
  let failed = 0;
  let invalidTokens = 0;

  for (const row of rows) {
    campaignIds.add(row.campaign_id);
    const result = await sendFcmMessage(
      {
        token: row.fcm_token,
        title: row.title,
        body: row.body,
        imageUrl: row.image_url,
        deepLink: row.deep_link,
        data: {
          ...row.data_json,
          notificationId: row.id,
          campaignId: row.campaign_id,
        },
        priority: row.priority,
        ttlSeconds: row.ttl_seconds,
        channelId: row.channel_id,
      },
      credentials
    );

    if (result.ok) {
      sent += 1;
      await markSuccess(row, result.messageId || '');
    } else {
      failed += 1;
      if (result.invalidToken) invalidTokens += 1;
      await markFailure(
        row,
        result.errorCode || '',
        result.errorMessage || 'Firebase FCM send failed',
        Boolean(result.invalidToken),
        result.retryAfterSeconds
      );
    }
  }

  for (const campaignId of campaignIds) {
    await refreshCampaignCounts(campaignId);
  }

  return {
    queued,
    processed: rows.length,
    sent,
    failed,
    invalidTokens,
  };
}
