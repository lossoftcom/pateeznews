import type { APIRoute } from 'astro';
import { json } from '@/lib/server/appDb';
import { dbQuery } from '@/lib/server/supabaseDb';
import { createPost, createUploadFromUrl } from '@/lib/server/social/bundle';
import { readJsonBody, requireSocialAccess } from '@/lib/server/social/api';
import { getSocialAccountById, resolveBundleApiKey } from '@/lib/server/social/store';

export const prerender = false;

const BUNDLE_TYPES = new Set([
  'TIKTOK',
  'YOUTUBE',
  'INSTAGRAM',
  'FACEBOOK',
  'TWITTER',
  'THREADS',
  'LINKEDIN',
  'PINTEREST',
  'REDDIT',
  'MASTODON',
  'DISCORD',
  'SLACK',
  'BLUESKY',
  'GOOGLE_BUSINESS',
]);

function stringList(value: unknown) {
  if (!Array.isArray(value)) return [];
  return value.map((item) => String(item || '').trim()).filter(Boolean);
}

function normalizeBundleTypes(value: unknown) {
  return Array.from(
    new Set(
      stringList(value)
        .map((item) => item.toUpperCase())
        .filter((item) => BUNDLE_TYPES.has(item))
    )
  );
}

function normalizeSelectedConnectedAccountIds(value: unknown) {
  if (!value || typeof value !== 'object' || Array.isArray(value)) return {};
  const selected: Record<string, string> = {};
  for (const [key, rawId] of Object.entries(value as Record<string, unknown>)) {
    const platform = String(key || '').trim().toUpperCase();
    const id = String(rawId || '').trim();
    if (!BUNDLE_TYPES.has(platform) || !id) continue;
    selected[platform] = id;
  }
  return selected;
}

type PlatformOptions = Record<string, Record<string, any>>;

function normalizePlatformOptions(value: unknown): PlatformOptions {
  if (!value || typeof value !== 'object' || Array.isArray(value)) return {};
  const normalized: PlatformOptions = {};
  for (const [key, rawValue] of Object.entries(value as Record<string, unknown>)) {
    const platform = String(key || '').trim().toUpperCase();
    if (!BUNDLE_TYPES.has(platform) || !rawValue || typeof rawValue !== 'object' || Array.isArray(rawValue)) {
      continue;
    }
    const cleaned: Record<string, any> = {};
    for (const [optionKey, optionValue] of Object.entries(rawValue as Record<string, unknown>)) {
      if (optionValue === null || optionValue === undefined) continue;
      if (typeof optionValue === 'string' && optionValue.trim() === '') continue;
      if (Array.isArray(optionValue) && optionValue.length === 0) continue;
      if (
        typeof optionValue === 'object' &&
        !Array.isArray(optionValue) &&
        Object.keys(optionValue as Record<string, unknown>).length === 0
      ) {
        continue;
      }
      cleaned[optionKey] = optionValue;
    }
    if (Object.keys(cleaned).length) normalized[platform] = cleaned;
  }
  return normalized;
}

function siteBaseUrl() {
  const env = import.meta.env as Record<string, string | undefined>;
  return String(process.env.PUBLIC_SITE_URL || process.env.SITE_URL || env.PUBLIC_SITE_URL || env.SITE_URL || 'https://pateeznews.com')
    .trim()
    .replace(/\/+$/g, '');
}

function absoluteUrl(value: string) {
  if (/^https?:\/\//i.test(value)) return value;
  if (value.startsWith('/')) return `${siteBaseUrl()}${value}`;
  return value;
}

function postTypeFor(platform: string, requestedType: string) {
  const type = requestedType.toLowerCase();
  if (platform === 'TIKTOK') {
    return type === 'photo' || type === 'image' ? 'IMAGE' : 'VIDEO';
  }
  if (platform === 'YOUTUBE') return type === 'feed' ? 'VIDEO' : 'SHORT';
  if (type === 'story') return 'STORY';
  if (type === 'reels' || type === 'shortvideo' || type === 'short_video') return 'REEL';
  return 'POST';
}

function connectionFor(rows: any[], platform: string, selectedIds: Record<string, string>) {
  const selectedId = selectedIds[platform];
  if (selectedId) {
    const selected = rows.find(
      (row) =>
        String(row.id || '').trim() === selectedId &&
        String(row.platform_tipi || '').toUpperCase() === platform
    );
    if (selected) return selected;
  }
  return rows.find((row) => String(row.platform_tipi || '').toUpperCase() === platform) || null;
}

function optionsFor(platformOptions: PlatformOptions, platform: string) {
  return platformOptions[platform] || {};
}

function optionString(options: Record<string, any>, key: string) {
  return String(options[key] || '').trim();
}

function optionNumber(options: Record<string, any>, key: string) {
  const value = options[key];
  if (typeof value === 'number' && Number.isFinite(value)) return value;
  if (typeof value === 'string' && value.trim() !== '') {
    const parsed = Number(value);
    if (Number.isFinite(parsed)) return parsed;
  }
  return undefined;
}

function optionBoolean(options: Record<string, any>, key: string) {
  return typeof options[key] === 'boolean' ? options[key] : undefined;
}

function optionEnum(options: Record<string, any>, key: string, allowed: Set<string>) {
  const value = optionString(options, key).toUpperCase();
  return allowed.has(value) ? value : '';
}

function optionStringList(options: Record<string, any>, key: string) {
  const value = options[key];
  if (Array.isArray(value)) {
    return value.map((item) => String(item || '').trim()).filter(Boolean);
  }
  return String(value || '')
    .split(/[,;\n]/g)
    .map((item) => item.trim())
    .filter(Boolean);
}

function optionTaggedUsers(options: Record<string, any>) {
  const tagged = options.tagged;
  if (!Array.isArray(tagged)) return [];
  return tagged
    .map((item) => {
      if (!item || typeof item !== 'object' || Array.isArray(item)) return null;
      const record = item as Record<string, unknown>;
      const username = String(record.username || '').replace(/^@/, '').trim();
      if (!username) return null;
      const x = Number(record.x);
      const y = Number(record.y);
      return {
        username,
        ...(Number.isFinite(x) ? { x } : {}),
        ...(Number.isFinite(y) ? { y } : {}),
      };
    })
    .filter(Boolean);
}

function optionMusicSoundInfo(options: Record<string, any>) {
  const music = options.musicSoundInfo;
  if (!music || typeof music !== 'object' || Array.isArray(music)) return null;
  const record = music as Record<string, unknown>;
  const musicSoundId = String(record.musicSoundId || '').trim();
  if (!musicSoundId) return null;
  return { musicSoundId };
}

function platformData(options: {
  platform: string;
  text: string;
  title: string;
  postType: string;
  uploadIds: string[];
  link: string;
  connectedRows: any[];
  selectedConnectedAccountIds: Record<string, string>;
  platformOptions: PlatformOptions;
}) {
  const {
    platform,
    text,
    title,
    postType,
    uploadIds,
    link,
    connectedRows,
    selectedConnectedAccountIds,
    platformOptions,
  } = options;
  const connected = connectionFor(connectedRows, platform, selectedConnectedAccountIds);
  const channelId = String(connected?.channel_id || '').trim();
  const channelName = String(connected?.channel_name || connected?.username || '').trim();
  const common: Record<string, any> = { text };
  if (uploadIds.length) common.uploadIds = uploadIds;
  const platformOption = optionsFor(platformOptions, platform);

  switch (platform) {
    case 'FACEBOOK': {
      const type = postTypeFor(platform, postType);
      const altText = optionString(platformOption, 'altText');
      const mediaItems =
        uploadIds.length && altText
          ? uploadIds.map((uploadId) => ({ uploadId, altText }))
          : [];
      return {
        type,
        text,
        ...(uploadIds.length ? { uploadIds } : {}),
        ...(mediaItems.length ? { mediaItems } : {}),
        ...(type === 'POST' && link ? { link } : {}),
        ...(optionString(platformOption, 'thumbnail') ? { thumbnail: optionString(platformOption, 'thumbnail') } : {}),
        ...(optionString(platformOption, 'nativeScheduleTime')
          ? { nativeScheduleTime: optionString(platformOption, 'nativeScheduleTime') }
          : {}),
        ...(title ? { mediaTitle: title } : {}),
      };
    }
    case 'INSTAGRAM': {
      const type = postTypeFor(platform, postType);
      const shareToFeed = optionBoolean(platformOption, 'shareToFeed');
      const collaborators = optionStringList(platformOption, 'collaborators');
      const tagged = optionTaggedUsers(platformOption);
      return {
        type,
        text,
        ...(uploadIds.length ? { uploadIds } : {}),
        ...(type === 'POST' && optionString(platformOption, 'altText')
          ? { altText: optionString(platformOption, 'altText') }
          : {}),
        ...(type === 'REEL' ? { shareToFeed: shareToFeed !== false } : {}),
        ...(optionString(platformOption, 'thumbnail') ? { thumbnail: optionString(platformOption, 'thumbnail') } : {}),
        ...(optionNumber(platformOption, 'thumbnailOffset') !== undefined
          ? { thumbnailOffset: optionNumber(platformOption, 'thumbnailOffset') }
          : {}),
        ...(optionString(platformOption, 'locationId') ? { locationId: optionString(platformOption, 'locationId') } : {}),
        ...(collaborators.length ? { collaborators } : {}),
        ...(tagged.length ? { tagged } : {}),
        ...(optionBoolean(platformOption, 'autoFitImage') === true ? { autoFitImage: true } : {}),
        ...(optionBoolean(platformOption, 'autoCropImage') === true ? { autoCropImage: true } : {}),
      };
    }
    case 'TIKTOK': {
      if (!uploadIds.length) throw new Error('TikTok gönderimi için medya yüklemesi gerekir.');
      const type = postTypeFor(platform, postType);
      const privacy =
        optionEnum(
          platformOption,
          'privacy',
          new Set([
            'PUBLIC_TO_EVERYONE',
            'MUTUAL_FOLLOW_FRIENDS',
            'FOLLOWER_OF_CREATOR',
            'SELF_ONLY',
          ])
        ) || 'PUBLIC_TO_EVERYONE';
      const musicSoundInfo = optionMusicSoundInfo(platformOption);
      return {
        type,
        text,
        uploadIds,
        privacy,
        ...(optionString(platformOption, 'thumbnail') ? { thumbnail: optionString(platformOption, 'thumbnail') } : {}),
        ...(optionNumber(platformOption, 'thumbnailOffset') !== undefined
          ? { thumbnailOffset: optionNumber(platformOption, 'thumbnailOffset') }
          : {}),
        ...(optionNumber(platformOption, 'photoCoverIndex') !== undefined
          ? { photoCoverIndex: optionNumber(platformOption, 'photoCoverIndex') }
          : {}),
        ...(musicSoundInfo ? { musicSoundInfo } : {}),
        ...(optionBoolean(platformOption, 'disableComments') === true ? { disableComments: true } : {}),
        ...(optionBoolean(platformOption, 'disableDuet') === true ? { disableDuet: true } : {}),
        ...(optionBoolean(platformOption, 'disableStitch') === true ? { disableStitch: true } : {}),
        ...(optionBoolean(platformOption, 'isAiGenerated') === true ? { isAiGenerated: true } : {}),
        ...(optionBoolean(platformOption, 'isBrandContent') === true ? { isBrandContent: true } : {}),
        ...(optionBoolean(platformOption, 'isOrganicBrandContent') === true ? { isOrganicBrandContent: true } : {}),
        ...(optionBoolean(platformOption, 'autoAddMusic') === true ? { autoAddMusic: true } : {}),
        ...(optionBoolean(platformOption, 'autoScale') === true ? { autoScale: true } : {}),
        ...(optionBoolean(platformOption, 'uploadToDraft') === true ? { uploadToDraft: true } : {}),
      };
    }
    case 'TWITTER': {
      const replySettings = optionEnum(
        platformOption,
        'replySettings',
        new Set(['EVERYONE', 'FOLLOWING', 'MENTIONED_USERS', 'SUBSCRIBERS', 'VERIFIED'])
      );
      return { ...common, ...(replySettings ? { replySettings } : {}) };
    }
    case 'YOUTUBE':
      if (!uploadIds.length) throw new Error('YouTube gönderimi için video yüklemesi gerekir.');
      return {
        type: postTypeFor(platform, postType),
        text: title || text.slice(0, 90),
        description: text,
        uploadIds,
        privacy: 'PUBLIC',
        madeForKids: false,
        containsSyntheticMedia: false,
        hasPaidProductPlacement: false,
      };
    case 'PINTEREST':
      if (!uploadIds.length) throw new Error('Pinterest gönderimi için medya yüklemesi gerekir.');
      if (!channelName) throw new Error('Pinterest gönderimi için Bundle Social kanal/board bilgisi gerekir.');
      return {
        boardName: channelName,
        text: title || text.slice(0, 80),
        description: text,
        uploadIds,
        ...(link ? { link } : {}),
      };
    case 'REDDIT':
      if (!channelName) throw new Error('Reddit gönderimi için Bundle Social subreddit bilgisi gerekir.');
      return {
        sr: channelName,
        text: title || text.slice(0, 120),
        description: text,
        ...(uploadIds.length ? { uploadIds } : {}),
        ...(link ? { link } : {}),
      };
    case 'DISCORD':
    case 'SLACK':
      if (!channelId) throw new Error(`${platform} gönderimi için Bundle Social channelId gerekir.`);
      return { channelId, ...common };
    case 'LINKEDIN':
      return { ...common, ...(link ? { link } : {}), privacy: 'PUBLIC' };
    case 'MASTODON':
      return { ...common, privacy: 'PUBLIC' };
    case 'BLUESKY':
      return { ...common, ...(link ? { externalUrl: link, externalTitle: title || undefined } : {}) };
    case 'GOOGLE_BUSINESS':
      return { ...common, topicType: 'STANDARD', ...(link ? { callToActionType: 'LEARN_MORE', callToActionUrl: link } : {}) };
    default:
      return common;
  }
}

export const POST: APIRoute = async ({ request }) => {
  const body = await readJsonBody(request);
  try {
    const access = await requireSocialAccess(request, body);
    if (access.response) return access.response;

    const account = await getSocialAccountById(body.social_account_id || body.account_id);
    if (!account) return json({ error: { message: 'Bundle Social settings are required before publishing' } }, 400);

    const apiKey = resolveBundleApiKey(account);
    if (!apiKey) return json({ error: { message: 'Bundle Social API key is missing' } }, 400);

    const teamId = String(account.team_id || '').trim();
    if (!teamId) return json({ error: { message: 'Bundle Social teamId is missing' } }, 400);

    const socialAccountTypes = normalizeBundleTypes(body.social_account_types || body.platform_types);
    if (!socialAccountTypes.length) return json({ error: { message: 'At least one social platform must be selected' } }, 400);
    const selectedConnectedAccountIds = normalizeSelectedConnectedAccountIds(
      body.selected_connected_account_ids || body.selectedConnectedAccountIds
    );
    const platformOptions = normalizePlatformOptions(body.platform_options || body.platformOptions);

    const title = String(body.title || body.campaign_name || 'Pateez social post').trim();
    const text = String(body.text || body.caption || '').trim();
    if (!text) return json({ error: { message: 'Social post text is required' } }, 400);

    const mediaUrls = stringList(body.media_urls || body.mediaUrls).map(absoluteUrl);
    const uploadIds: string[] = [];
    for (const mediaUrl of mediaUrls) {
      const upload = await createUploadFromUrl({
        apiKey,
        apiBaseUrl: account.api_base_url,
        teamId,
        url: mediaUrl,
      });
      if (upload.id) uploadIds.push(upload.id);
    }

    const connected = await dbQuery(
      `SELECT *
       FROM public.social_connected_accounts
       WHERE social_account_id = $1::bigint
         AND durum = 'connected'`,
      [account.id]
    );

    const link = String(body.link_url || body.link || '').trim();
    const postType = String(body.post_type || 'feed').trim();
    const data: Record<string, any> = {};
    for (const platform of socialAccountTypes) {
      data[platform] = platformData({
        platform,
        text,
        title,
        postType,
        uploadIds,
        link,
        connectedRows: connected.rows,
        selectedConnectedAccountIds,
        platformOptions,
      });
    }

    const postDate = body.scheduled_at
      ? new Date(String(body.scheduled_at)).toISOString()
      : new Date().toISOString();
    const status = body.scheduled_at ? 'SCHEDULED' : 'SCHEDULED';
    const requestBody = {
      teamId,
      title,
      postDate,
      status,
      socialAccountTypes,
      data,
    };
    const storedRequestBody = { ...requestBody, selectedConnectedAccountIds, platformOptions };

    const created = await createPost({
      apiKey,
      apiBaseUrl: account.api_base_url,
      body: requestBody,
    });

    const result = await dbQuery(
      `INSERT INTO public.social_posts (
         social_account_id,
         bundle_post_id,
         team_id,
         baslik,
         durum,
         post_date,
         platform_tipleri,
         icerik_text,
         link_url,
         media_urls,
         upload_ids,
         request_json,
         response_json,
         kullanici
       )
       VALUES (
         $1::bigint,
         $2,
         $3,
         $4,
         $5,
         $6::timestamptz,
         $7::text[],
         $8,
         $9,
         $10::text[],
         $11::text[],
         $12::jsonb,
         $13::jsonb,
         $14
       )
       RETURNING id::text AS id, bundle_post_id, durum AS status, post_date`,
      [
        account.id,
        created.id || null,
        teamId,
        title,
        created.status || status,
        created.postDate || postDate,
        socialAccountTypes,
        text,
        link,
        mediaUrls,
        uploadIds,
        JSON.stringify(storedRequestBody),
        JSON.stringify(created || {}),
        access.session!.user.id,
      ]
    );

    return json({ post: result.rows[0], bundle: created });
  } catch (error: any) {
    return json({ error: { message: error.message || 'Bundle Social post could not be created' } }, error.status || 500);
  }
};
