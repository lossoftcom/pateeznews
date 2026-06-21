import type { APIRoute } from 'astro';
import { getSessionFromRequest, json } from '@/lib/server/appDb';
import { mapAppFeedItems } from '@/lib/server/appFeed';
import { dbQuery } from '@/lib/server/supabaseDb';
import { dataService } from '@/services/dataService.server';

export const prerender = false;

const numberParam = (
  value: string | null,
  fallback: number,
  min: number,
  max: number,
) => {
  const parsed = Number(value ?? fallback);
  if (!Number.isFinite(parsed)) return fallback;
  return Math.min(Math.max(parsed, min), max);
};

const resolveImageUrl = (url: string, base: string): string => {
  if (!url) return '';
  try {
    const parsed = new URL(url);
    if (parsed.protocol === 'http:' || parsed.protocol === 'https:') return url;
  } catch {
    // relative path
  }
  if (url.startsWith('/')) return `${base}${url}`;
  return url;
};

const asObject = (value: unknown): Record<string, any> => {
  if (!value) return {};
  if (typeof value === 'string') {
    try {
      const parsed = JSON.parse(value);
      return parsed && typeof parsed === 'object' && !Array.isArray(parsed)
        ? parsed
        : {};
    } catch {
      return {};
    }
  }
  return value && typeof value === 'object' && !Array.isArray(value)
    ? (value as Record<string, any>)
    : {};
};

const asArray = (value: unknown): any[] => {
  if (Array.isArray(value)) return value;
  if (typeof value === 'string') {
    try {
      const parsed = JSON.parse(value);
      return Array.isArray(parsed) ? parsed : [];
    } catch {
      return [];
    }
  }
  return [];
};

const str = (value: unknown): string => String(value ?? '').trim();

const eventItemFromPost = (row: any) => {
  const cardData = asObject(row.card_data);
  const items = asArray(row.items).map(asObject);
  const candidates = [cardData, ...items].filter((item) => {
    const type = str(item.type).toLowerCase();
    return type === 'event' || asObject(item.eventData);
  });
  return candidates.find((item) => asObject(item.eventData)) || candidates[0] || {};
};

const mapEvent = (row: any, origin: string, article?: any) => {
  const item = eventItemFromPost(row);
  const eventData = asObject(item.eventData);
  const imageUrl = resolveImageUrl(
    str(item.mediaUrl) ||
      str(row.thumbnail_url) ||
      str(row.media_url) ||
      str(asObject(row.card_data).mediaUrl),
    origin,
  );

  return {
    id: String(row.id || ''),
    title: str(item.title) || str(row.title),
    summary: str(item.description) || str(row.summary),
    category: str(row.category) || 'etkinlik',
    imageUrl,
    slug: str(row.slug),
    publishedAt: row.published_at || row.created_at || '',
    startDateTime: str(eventData.startDateTime),
    endDateTime: str(eventData.endDateTime),
    organizer: str(eventData.organizer),
    venueName: str(eventData.venueName),
    address: str(eventData.address),
    registrationType: str(eventData.registrationType),
    ticketUrl: str(eventData.ticketUrl),
    ticketPrice: str(eventData.ticketPrice),
    capacity: str(eventData.capacity),
    article,
  };
};

export const GET: APIRoute = async ({ request, url }) => {
  try {
    const lang = String(url.searchParams.get('lang') || 'tr').trim() || 'tr';
    const limit = numberParam(url.searchParams.get('limit'), 30, 1, 50);
    const origin = new URL(url).origin;
    const session = await getSessionFromRequest(request);
    const result = await dbQuery(
      `SELECT
         p.id, p.created_at, p.published_at, p.updated_at, p.publisher_id,
         p.title, p.summary, p.content, p.category, p.type,
         p.thumbnail_url, p.thumbnail_alt, p.media_url,
         p.likes_count, p.dislikes_count, p.comments_count, p.shares_count,
         p.views_count, p.saves_count, p.slug, p.status, p.seo_title,
         p.seo_description, p.keywords, p.language_code, p.is_pinned,
         p.show_in_manset, p.fact_checked, p.schema_type, p.card_data,
         p.items, p.faq_data,
         json_build_object(
           'id', pr.id,
           'username', pr.username,
           'full_name', pr.full_name,
           'avatar_url', pr.avatar_url,
           'role', pr.role
         ) AS profiles
       FROM public.posts p
       LEFT JOIN public.profiles pr ON pr.id = p.publisher_id
       WHERE p.status = 'published'
         AND p.deleted_at IS NULL
         AND p.language_code = $1
         AND (p.published_at <= now() OR p.published_at IS NULL)
         AND (
           lower(coalesce(p.type, '')) = 'event'
           OR lower(coalesce(p.card_data->>'type', '')) = 'event'
           OR coalesce(p.card_data, '{}'::jsonb) ? 'eventData'
           OR EXISTS (
             SELECT 1
             FROM jsonb_array_elements(
               CASE
                 WHEN jsonb_typeof(p.items) = 'array' THEN p.items
                 ELSE '[]'::jsonb
               END
             ) AS item
             WHERE lower(coalesce(item->>'type', '')) = 'event'
                OR item ? 'eventData'
           )
         )
       ORDER BY p.published_at DESC NULLS LAST, p.created_at DESC NULLS LAST, p.id DESC
       LIMIT $2`,
      [lang, limit],
    );

    const feedItems = result.rows.map((row) => dataService.mapPost(row));
    const articles = await mapAppFeedItems(
      feedItems,
      origin,
      session?.user?.id || null,
    );
    const articleById = new Map(
      articles.map((article) => [String(article.id || ''), article]),
    );
    const items = result.rows.map((row) =>
      mapEvent(row, origin, articleById.get(String(row.id || ''))),
    );
    return json({ items });
  } catch (error: any) {
    return json({ error: error?.message || 'Events failed', items: [] }, 500);
  }
};
