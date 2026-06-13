import type { APIRoute } from 'astro';
import { adminError, adminJson, requireAdminRequest } from '@/lib/server/adminAuth';
import { purgeExpiredTrashPosts } from '@/lib/server/postTrash';
import { dbQuery } from '@/lib/server/supabaseDb';

const ALL = 'Tümü';
const MAX_PAGE_SIZE = 500;
const SORT_COLUMNS: Record<string, string> = {
  id: 'p.id',
  post: 'p.title',
  category: 'p.category',
  status: 'p.status',
  language: 'p.language_code',
  author: 'p.publisher_id',
  views: 'p.views_count',
  comments: 'p.comments_count',
  date: 'p.created_at',
};

const VIDEO_THUMB_EXTENSIONS = ['.webp', '.jpg', '.jpeg', '.png'];
const VIDEO_THUMB_FIELDS = [
  'thumbnailUrl',
  'thumbUrl',
  'posterUrl',
  'videoThumbUrl',
  'mediaThumbUrl',
  'thumbnail',
  'thumb',
  'poster',
];

function escapeSearchTerm(value: unknown) {
  return String(value || '')
    .trim()
    .replaceAll('\\', '\\\\')
    .replaceAll('%', '\\%')
    .replaceAll('_', '\\_')
    .replaceAll(',', ' ')
    .replaceAll('\n', ' ')
    .replaceAll('\r', ' ');
}

function safePositiveInt(value: unknown, fallback: number) {
  const parsed = Number(value);
  if (!Number.isFinite(parsed) || parsed < 1) return fallback;
  return Math.floor(parsed);
}

function asObject(value: unknown): Record<string, any> {
  return value && typeof value === 'object' && !Array.isArray(value)
    ? value as Record<string, any>
    : {};
}

function asArray(value: unknown): any[] {
  return Array.isArray(value) ? value : [];
}

function cleanText(value: unknown) {
  return String(value || '').trim();
}

function youtubeIdFrom(url: string) {
  const raw = cleanText(url);
  if (/^[_\-a-zA-Z0-9]{11}$/.test(raw)) return raw;
  let parsed: URL;
  try {
    parsed = new URL(raw);
  } catch {
    try {
      parsed = new URL(`https://${raw}`);
    } catch {
      return '';
    }
  }
  const host = parsed.hostname.toLowerCase();
  if (!host.includes('youtube.com') && !host.includes('youtu.be') && !host.includes('youtube-nocookie.com')) {
    return '';
  }
  if (host.includes('youtu.be')) return cleanYoutubeId(parsed.pathname.split('/').filter(Boolean)[0]);
  const fromQuery = cleanYoutubeId(parsed.searchParams.get('v') || '');
  if (fromQuery) return fromQuery;
  const segments = parsed.pathname.split('/').filter(Boolean);
  for (let index = 0; index < segments.length - 1; index += 1) {
    const segment = segments[index].toLowerCase();
    if (segment === 'shorts' || segment === 'embed' || segment === 'live') {
      return cleanYoutubeId(segments[index + 1]);
    }
  }
  return '';
}

function cleanYoutubeId(value: unknown) {
  const match = String(value || '').match(/[_\-a-zA-Z0-9]{11}/);
  return match?.[0] || '';
}

function safeDecodePath(pathname: string) {
  try {
    return decodeURIComponent(pathname);
  } catch {
    return pathname;
  }
}

function localVideoObjectPath(pathname: string) {
  const decoded = safeDecodePath(pathname);
  if (decoded.startsWith('/api/storage/file/video/')) {
    return `video/${decoded.slice('/api/storage/file/video/'.length)}`;
  }
  if (decoded.startsWith('/local-upload/video/')) {
    return `video/${decoded.slice('/local-upload/video/'.length)}`;
  }
  return '';
}

function localVideoThumbUrl(videoUrl: string, origin: string) {
  let parsed: URL;
  try {
    parsed = new URL(videoUrl, origin);
  } catch {
    return '';
  }
  const objectPath = localVideoObjectPath(parsed.pathname);
  if (!objectPath) return '';
  const slash = objectPath.lastIndexOf('/');
  const dir = slash >= 0 ? objectPath.slice(0, slash + 1) : '';
  const file = slash >= 0 ? objectPath.slice(slash + 1) : objectPath;
  const dot = file.lastIndexOf('.');
  const stem = dot >= 0 ? file.slice(0, dot) : file;
  return `/api/storage/file/${dir}${stem}_thumb${VIDEO_THUMB_EXTENSIONS[0]}`;
}

function youtubeThumbUrl(videoUrl: string) {
  const id = youtubeIdFrom(videoUrl);
  return id ? `https://img.youtube.com/vi/${id}/hqdefault.jpg` : '';
}

function explicitVideoThumbUrl(entry: Record<string, any>) {
  for (const field of VIDEO_THUMB_FIELDS) {
    const value = cleanText(entry[field]);
    if (value) return value;
  }
  return '';
}

function canonicalVideoKey(videoUrl: string, origin: string) {
  const raw = cleanText(videoUrl);
  if (!raw) return '';
  const youtubeId = youtubeIdFrom(raw);
  if (youtubeId) return `youtube:${youtubeId}`;
  try {
    const parsed = new URL(raw, origin);
    const localPath = localVideoObjectPath(parsed.pathname);
    if (localPath) return `local:${localPath}`;
    parsed.hash = '';
    return `url:${parsed.href}`;
  } catch {
    return `raw:${raw}`;
  }
}

function videoSizeLabel(entry: Record<string, any>) {
  const size = Number(entry.sizeBytes ?? entry.fileSizeBytes ?? entry.bytes ?? entry.size ?? entry.fileSize);
  if (!Number.isFinite(size) || size <= 0) return '-';
  if (size >= 1024 * 1024 * 1024) return `${(size / (1024 * 1024 * 1024)).toFixed(1)} GB`;
  if (size >= 1024 * 1024) return `${(size / (1024 * 1024)).toFixed(1)} MB`;
  if (size >= 1024) return `${(size / 1024).toFixed(1)} KB`;
  return `${Math.round(size)} B`;
}

function videoExtension(url: string, origin: string) {
  let pathname = url;
  try {
    pathname = new URL(url, origin).pathname;
  } catch {
    pathname = url.split('?')[0] || url;
  }
  const file = pathname.split('/').filter(Boolean).pop() || '';
  const dot = file.lastIndexOf('.');
  if (dot < 0 || dot === file.length - 1) return '';
  const extension = file.slice(dot + 1).toLowerCase();
  return extension.length <= 6 ? extension : '';
}

function videoPlatformLabel(entry: Record<string, any>, url: string, origin: string) {
  const explicit = cleanText(entry.videoPlatform ?? entry.platform ?? entry.platformLabel);
  if (explicit) return explicit;
  const youtubeId = youtubeIdFrom(url);
  if (youtubeId) return 'YouTube';
  const extension = videoExtension(url, origin);
  const suffix = extension ? ` · ${extension.toUpperCase()}` : '';
  try {
    const parsed = new URL(url, origin);
    const host = parsed.hostname.toLowerCase().replace(/^www\./, '');
    const localPath = localVideoObjectPath(parsed.pathname);
    if (localPath) return `Yerel Depo${suffix}`;
    if (host.includes('pexels.com')) return `Pexels${suffix}`;
    if (host.includes('vimeo.com')) return `Vimeo${suffix}`;
    if (host.includes('dailymotion.com')) return `Dailymotion${suffix}`;
    return `${host}${suffix}`;
  } catch {
    return `Yerel Depo${suffix}`;
  }
}

function videoPublishedAt(entry: Record<string, any>) {
  return cleanText(
    entry.videoPublishedAt ??
      entry.publishedAt ??
      entry.datePublished ??
      entry.videoAddedAt ??
      entry.addedAt ??
      entry.createdAt
  );
}

function addVideoCandidate(
  candidates: Record<string, any>[],
  entry: Record<string, any>,
  fallbackTitle: string
) {
  const url = cleanText(entry.mediaUrl ?? entry.videoUrl ?? entry.url);
  if (!url) return;
  candidates.push({
    ...entry,
    mediaUrl: url,
    title: cleanText(entry.title ?? entry.videoTitle) || fallbackTitle,
  });
}

function videoCandidatesFromRow(row: Record<string, any>) {
  const candidates: Record<string, any>[] = [];
  const fallbackTitle = cleanText(row.title) || 'Video';
  const rowType = cleanText(row.type).toLowerCase();
  const cardData = asObject(row.card_data);

  if (rowType === 'video') {
    addVideoCandidate(candidates, {
      id: `post-${row.id}-main`,
      title: fallbackTitle,
      mediaUrl: row.media_url || cardData.mediaUrl || cardData.videoUrl,
      thumbnailUrl: row.thumbnail_url,
    }, fallbackTitle);
  }
  if (cleanText(cardData.mediaUrl || cardData.videoUrl) && cleanText(cardData.type).toLowerCase() === 'video') {
    addVideoCandidate(candidates, cardData, fallbackTitle);
  }

  for (const item of asArray(row.items).map(asObject)) {
    const type = cleanText(item.type).toLowerCase();
    if (type === 'video') {
      addVideoCandidate(candidates, item, fallbackTitle);
      for (const [index, url] of asArray(item.mediaUrls).entries()) {
        addVideoCandidate(candidates, {
          ...item,
          id: `${cleanText(item.id) || 'video'}-${index + 1}`,
          mediaUrl: url,
        }, fallbackTitle);
      }
    }
    const recipeData = asObject(item.recipeData);
    if (cleanText(recipeData.videoUrl)) {
      addVideoCandidate(candidates, {
        ...recipeData,
        id: `${cleanText(item.id) || 'recipe'}-video`,
        title: recipeData.videoTitle || item.title,
        mediaUrl: recipeData.videoUrl,
      }, fallbackTitle);
    }
  }

  return candidates;
}

function videoSummariesFromRow(
  row: Record<string, any>,
  origin: string,
  viewCounts: Map<string, number>
) {
  const seen = new Set<string>();
  const videos = [];
  for (const [index, entry] of videoCandidatesFromRow(row).entries()) {
    const url = cleanText(entry.mediaUrl);
    const key = canonicalVideoKey(url, origin);
    if (!key || seen.has(key)) continue;
    seen.add(key);
    const thumb =
      explicitVideoThumbUrl(entry) ||
      youtubeThumbUrl(url) ||
      localVideoThumbUrl(url, origin);
    videos.push({
      id: cleanText(entry.id) || `video-${index + 1}`,
      title: cleanText(entry.title) || `Video ${index + 1}`,
      url,
      thumbnail_url: thumb,
      platform_label: videoPlatformLabel(entry, url, origin),
      published_at: videoPublishedAt(entry),
      size_label: videoSizeLabel(entry),
      views_count: viewCounts.get(`${row.id}|${key}`) || 0,
    });
  }
  return videos;
}

export const POST: APIRoute = async ({ request }) => {
  try {
    await requireAdminRequest(request, 'posts_access');
    const origin = new URL(request.url).origin;
    const body = await request.json().catch(() => ({}));
    const trashMode = body.trash === true;
    const cleanupLanguage = String(body.language || '').trim();
    await purgeExpiredTrashPosts(cleanupLanguage && cleanupLanguage !== ALL ? cleanupLanguage : 'tr').catch((error) => {
      console.warn('Expired trash cleanup skipped:', error);
    });

    const values: unknown[] = [];
    const where: string[] = [];
    const push = (value: unknown) => {
      values.push(value);
      return `$${values.length}`;
    };
    where.push(
      trashMode
        ? 'p.deleted_at IS NOT NULL'
        : `(p.deleted_at IS NULL AND COALESCE(p.status, '') <> 'trash')`
    );

    const search = escapeSearchTerm(body.search);
    if (search) {
      const pattern = push(`%${search}%`);
      where.push(`(
        p.title ILIKE ${pattern} ESCAPE '\\'
        OR p.slug ILIKE ${pattern} ESCAPE '\\'
        OR p.category ILIKE ${pattern} ESCAPE '\\'
        OR p.type ILIKE ${pattern} ESCAPE '\\'
        OR p.status ILIKE ${pattern} ESCAPE '\\'
        OR p.seo_title ILIKE ${pattern} ESCAPE '\\'
        OR p.seo_description ILIKE ${pattern} ESCAPE '\\'
        OR p.keywords ILIKE ${pattern} ESCAPE '\\'
        OR p.summary ILIKE ${pattern} ESCAPE '\\'
      )`);
    }

    for (const [column, value] of [
      ['language_code', body.language],
      ['category', body.category],
      ['type', body.type],
      ['status', body.status],
      ['publisher_id', body.publisher],
    ] as const) {
      const normalized = String(value || '').trim();
      if (normalized && normalized !== ALL) {
        where.push(`p.${column} = ${push(normalized)}`);
      }
    }

    const page = safePositiveInt(body.page, 1);
    const pageSize = Math.min(safePositiveInt(body.pageSize, 25), MAX_PAGE_SIZE);
    const offset = (page - 1) * pageSize;
    const sortColumn = SORT_COLUMNS[String(body.sortKey || '').trim()] || SORT_COLUMNS.date;
    const sortDirection = body.sortAscending === true ? 'ASC' : 'DESC';
    const whereSql = where.length ? `WHERE ${where.join(' AND ')}` : '';
    const countValues = values.slice();
    const limitSql = push(pageSize);
    const offsetSql = push(offset);

    const [result, countResult] = await Promise.all([
      dbQuery<any>(
        `SELECT
         p.id,
         p.title,
         p.category,
         p.type,
         p.status,
         p.slug,
         p.created_at,
         p.thumbnail_url,
         p.media_url,
         p.likes_count,
         p.comments_count,
         p.views_count,
         p.card_data,
         p.items,
         p.language_code,
         p.is_pinned,
         p.publisher_id,
         jsonb_build_object(
           'full_name', publisher.full_name,
           'username', publisher.username,
           'email', publisher.email
         ) AS profiles,
         parent.label AS parent_category,
         CASE
           WHEN jsonb_typeof(p.card_data -> 'categoryPath') = 'array'
             AND jsonb_array_length(p.card_data -> 'categoryPath') > 0
           THEN p.card_data -> 'categoryPath'
           ELSE to_jsonb(
             array_remove(
               ARRAY[grandparent.label, parent.label, category_item.label],
               NULL
             )
           )
         END AS category_path
       FROM public.posts p
       LEFT JOIN public.profiles publisher ON publisher.id = p.publisher_id
       LEFT JOIN LATERAL (
         SELECT item.parent_id, item.label
         FROM public.navigation_items item
         LEFT JOIN public.navigation_menus menu ON menu.id = item.menu_id
         LEFT JOIN public.navigation_items item_parent ON item_parent.id = item.parent_id
         WHERE item.label = p.category
         ORDER BY
           CASE WHEN menu.code = 'sidebar_main' THEN 0 ELSE 1 END,
           CASE WHEN item.parent_id IS NOT NULL THEN 0 ELSE 1 END,
           CASE WHEN item_parent.type = 'district' THEN 1 ELSE 0 END,
           (item.language_code = p.language_code) DESC NULLS LAST,
           item.order_index,
           item.id
         LIMIT 1
       ) category_item ON true
       LEFT JOIN public.navigation_items parent ON parent.id = category_item.parent_id
       LEFT JOIN public.navigation_items grandparent ON grandparent.id = parent.parent_id
       ${whereSql}
       ORDER BY p.is_pinned DESC, ${sortColumn} ${sortDirection} NULLS LAST, p.id DESC
       LIMIT ${limitSql}
       OFFSET ${offsetSql}`,
        values
      ),
      dbQuery<{ count: string }>(
        `SELECT COUNT(*)::bigint AS count
         FROM public.posts p
         ${whereSql}`,
        countValues
      ),
    ]);

    const rawRows = result.rows || [];
    const postIds = rawRows
      .map((row: any) => Number(row.id))
      .filter((id: number) => Number.isFinite(id) && id > 0);
    const videoViewCounts = new Map<string, number>();
    if (postIds.length > 0) {
      const videoViewResult = await dbQuery<{
        post_id: string | number;
        video_url: string | null;
        views: string | number;
      }>(
        `SELECT post_id, video_url, (COUNT(*) FILTER (WHERE counted = true))::int AS views
         FROM public.post_video_views
         WHERE post_id = ANY($1::bigint[])
         GROUP BY post_id, video_url`,
        [postIds]
      );
      for (const row of videoViewResult.rows || []) {
        const key = canonicalVideoKey(row.video_url || '', origin);
        if (!key) continue;
        const mapKey = `${row.post_id}|${key}`;
        videoViewCounts.set(mapKey, (videoViewCounts.get(mapKey) || 0) + Number(row.views || 0));
      }
    }
    const rows = rawRows.map((row: any) => ({
      ...row,
      video_summaries: videoSummariesFromRow(row, origin, videoViewCounts),
    }));
    const count = Number(countResult.rows[0]?.count || 0);
    return adminJson({
      data: rows,
      count,
      error: null,
    });
  } catch (error) {
    return adminError(error);
  }
};
