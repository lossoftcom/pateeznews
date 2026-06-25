import { dbQuery } from '@/lib/server/supabaseDb';
import { processNotificationOutbox } from './processor';

type AdminNotificationEventInput = {
  eventKey: string;
  type: string;
  campaignName: string;
  title: string;
  body: string;
  imageUrl?: string;
  deepLink?: string;
  data?: Record<string, unknown>;
};

type UserSignupNotificationInput = {
  userId: string;
  name?: string | null;
  email?: string | null;
  provider?: string | null;
  city?: string | null;
};

type SubscriberNotificationInput = {
  subscriberId: string | number;
  email: string;
  source?: string | null;
  city?: string | null;
  languageCode?: string | null;
};

type CommentNotificationInput = {
  commentId: string | number;
  postId: string | number;
  postTitle?: string | null;
  authorName?: string | null;
  authorEmail?: string | null;
  status?: string | null;
  content?: string | null;
};

type AutomaticNewsNotificationInput = {
  source: {
    display_name?: string | null;
    source_type?: string | null;
  };
  title: string;
  status?: string | null;
  category?: string | null;
  imageUrl?: string | null;
};

type AutomaticNewsInsertedInput = {
  id: string | number;
  display_id?: string | number | null;
};

const normalizeNotificationText = (value: unknown) =>
  String(value || '')
    .replace(/\u00a0/g, ' ')
    .replace(/[ \t\r\f\v]+/g, ' ')
    .replace(/\n\s+/g, '\n')
    .replace(/\n{3,}/g, '\n\n')
    .trim();

export const truncateNotificationText = (value: unknown, maxLength: number) => {
  const text = normalizeNotificationText(value);
  if (text.length <= maxLength) return text;
  return `${text.slice(0, Math.max(0, maxLength - 3)).trim()}...`;
};

const compactParts = (parts: Array<unknown>) =>
  parts
    .map((part) => normalizeNotificationText(part))
    .filter(Boolean)
    .join(' - ');

export const adminNotificationTargetUserIds = async () => {
  const result = await dbQuery<{ id: string }>(
    `SELECT DISTINCT p.id::text
     FROM public.profiles p
     JOIN public.notification_device_tokens dt
       ON dt.user_id = p.id
      AND dt.is_active IS TRUE
      AND dt.invalidated_at IS NULL
      AND dt.permission_status IN ('authorized', 'granted', 'provisional', 'unknown')
     WHERE p.role IN ('admin', 'super_admin')
     ORDER BY p.id::text`,
  );
  return result.rows.map((row) => row.id).filter(Boolean);
};

export async function dispatchAdminNotificationEvent(input: AdminNotificationEventInput) {
  const idempotencyKey = normalizeNotificationText(input.eventKey).slice(0, 180);
  if (!idempotencyKey) return;

  const adminUserIds = await adminNotificationTargetUserIds();
  if (!adminUserIds.length) return;

  const dataJson = JSON.stringify({
    ...(input.data || {}),
    type: input.type,
    adminOnly: true,
  });

  const result = await dbQuery<{ id: string }>(
    `INSERT INTO public.notification_campaigns (
       campaign_name,
       target_type,
       target_user_ids,
       title,
       body,
       image_url,
       deep_link,
       data_json,
       priority,
       ttl_seconds,
       channel_id,
       status,
       started_at,
       idempotency_key
     )
     VALUES (
       $1,
       'user',
       $2::uuid[],
       $3,
       $4,
       $5,
       $6,
       $7::jsonb,
       'high',
       86400,
       'pateez_general',
       'sending',
       now(),
       $8
     )
     ON CONFLICT (idempotency_key) DO NOTHING
     RETURNING id::text`,
    [
      truncateNotificationText(input.campaignName, 160),
      adminUserIds,
      truncateNotificationText(input.title, 120),
      truncateNotificationText(input.body, 180),
      normalizeNotificationText(input.imageUrl),
      input.deepLink == null ? '' : normalizeNotificationText(input.deepLink),
      dataJson,
      idempotencyKey,
    ],
  );

  const campaignId = result.rows[0]?.id || (
    await dbQuery<{ id: string }>(
      `SELECT id::text
       FROM public.notification_campaigns
       WHERE idempotency_key = $1
       LIMIT 1`,
      [idempotencyKey],
    )
  ).rows[0]?.id;

  if (!campaignId) return;
  await processNotificationOutbox(Math.max(25, adminUserIds.length * 4), campaignId);
}

export async function notifyAdminsForUserSignup(input: UserSignupNotificationInput) {
  const userId = normalizeNotificationText(input.userId);
  if (!userId) return;

  const name = normalizeNotificationText(input.name);
  const email = normalizeNotificationText(input.email).toLowerCase();
  const provider = normalizeNotificationText(input.provider || 'email');
  const city = normalizeNotificationText(input.city);
  const label = name || email || 'Yeni kullanıcı';
  const details = compactParts([city, provider ? `Kayıt: ${provider}` : '']);

  await dispatchAdminNotificationEvent({
    eventKey: `user-signup:${userId}`,
    type: 'user_signup',
    campaignName: `Yeni Kullanıcı #${userId}`,
    title: 'Yeni kullanıcı kaydoldu',
    body: `${label}${details ? ` - ${details}` : ''}`,
    data: {
      adminPage: 'users',
      admin_page: 'users',
      userId,
      user_id: userId,
      name,
      email,
      provider,
      city,
    },
  });
}

export async function notifyAdminsForAutomaticNewsItem(
  item: AutomaticNewsNotificationInput,
  inserted: AutomaticNewsInsertedInput,
) {
  const itemId = normalizeNotificationText(inserted.id);
  if (!itemId) return;

  const displayId = normalizeNotificationText(inserted.display_id);
  const sourceName = normalizeNotificationText(item.source.display_name || item.source.source_type);
  const sourceType = normalizeNotificationText(item.source.source_type);
  const status = normalizeNotificationText(item.status);
  const category = normalizeNotificationText(item.category);
  const bodyPrefix = compactParts([status, sourceName]);

  await dispatchAdminNotificationEvent({
    eventKey: `automatic-news-admin:${itemId}`,
    type: 'automatic_news',
    campaignName: `Otomatik Haber #${displayId || itemId}`,
    title: 'Otomatik haber düştü',
    body: `${bodyPrefix ? `${bodyPrefix}: ` : ''}${normalizeNotificationText(item.title)}`,
    imageUrl: normalizeNotificationText(item.imageUrl),
    data: {
      adminPage: 'automaticNews',
      admin_page: 'automaticNews',
      automaticNewsItemId: itemId,
      automaticNewsDisplayId: displayId,
      automatic_news_item_id: itemId,
      automatic_news_display_id: displayId,
      sourceName,
      sourceType,
      source_name: sourceName,
      source_type: sourceType,
      status,
      category,
    },
  });
}

export async function notifyAdminsForSubscriber(input: SubscriberNotificationInput) {
  const subscriberId = normalizeNotificationText(input.subscriberId);
  const email = normalizeNotificationText(input.email).toLowerCase();
  if (!subscriberId || !email) return;

  const source = normalizeNotificationText(input.source);
  const city = normalizeNotificationText(input.city);
  const languageCode = normalizeNotificationText(input.languageCode || 'tr');
  const details = compactParts([city, source]);

  await dispatchAdminNotificationEvent({
    eventKey: `newsletter-subscriber:${subscriberId}`,
    type: 'newsletter_subscriber',
    campaignName: `Yeni Abone #${subscriberId}`,
    title: 'Yeni abone geldi',
    body: `${email}${details ? ` - ${details}` : ''}`,
    data: {
      adminPage: 'subscribers',
      admin_page: 'subscribers',
      subscriberId,
      subscriber_id: subscriberId,
      email,
      source,
      city,
      languageCode,
      language_code: languageCode,
    },
  });
}

export async function notifyAdminsForComment(input: CommentNotificationInput) {
  const commentId = normalizeNotificationText(input.commentId);
  const postId = normalizeNotificationText(input.postId);
  if (!commentId || !postId) return;

  const postTitle = normalizeNotificationText(input.postTitle) || `Haber #${postId}`;
  const authorName = normalizeNotificationText(input.authorName) || 'Misafir';
  const authorEmail = normalizeNotificationText(input.authorEmail).toLowerCase();
  const status = normalizeNotificationText(input.status);
  const content = truncateNotificationText(input.content, 90);
  const details = compactParts([status, postTitle]);

  await dispatchAdminNotificationEvent({
    eventKey: `comment-created:${commentId}`,
    type: 'comment_created',
    campaignName: `Yeni Yorum #${commentId}`,
    title: 'Yeni yorum geldi',
    body: `${authorName}${details ? ` - ${details}` : ''}${content ? `: ${content}` : ''}`,
    data: {
      adminPage: 'comments',
      admin_page: 'comments',
      commentId,
      comment_id: commentId,
      postId,
      post_id: postId,
      postTitle,
      post_title: postTitle,
      authorName,
      author_name: authorName,
      authorEmail,
      author_email: authorEmail,
      status,
    },
  });
}
