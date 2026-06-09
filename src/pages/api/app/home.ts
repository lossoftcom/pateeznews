import type { APIRoute } from 'astro';
import { json } from '@/lib/server/appDb';
import { dataService } from '@/services/dataService.server';
import type { NewsItem, OptimizedImage } from '@/types';

export const prerender = false;

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

const numberParam = (
  value: string | null,
  fallback: number,
  min: number,
  max: number,
): number => {
  const parsed = Number(value ?? fallback);
  if (!Number.isFinite(parsed)) return fallback;
  return Math.min(Math.max(parsed, min), max);
};

const getNewsTime = (item: NewsItem): number => {
  const date = new Date(item.timestamp || '');
  return Number.isNaN(date.getTime()) ? 0 : date.getTime();
};

const imageAspectRatio = (image?: OptimizedImage): number | undefined => {
  const width = Number(image?.width || 0);
  const height = Number(image?.height || 0);
  if (!Number.isFinite(width) || !Number.isFinite(height) || width <= 0 || height <= 0) {
    return undefined;
  }
  return width / height;
};

const firstMediaUrl = (item: NewsItem): string => {
  const mediaListItem = Array.isArray(item.mediaList)
    ? item.mediaList.find((media) => String(media || '').trim())
    : '';
  return String(
    item.optimizedCoverThumbnail?.src ||
      item.optimizedThumbnail?.src ||
      item.coverThumbnail ||
      item.thumbnail ||
      mediaListItem ||
      item.mediaUrl ||
      '',
  );
};

const toIsoDate = (value: string | undefined): string => {
  const date = value ? new Date(value) : null;
  return date && !Number.isNaN(date.getTime())
    ? date.toISOString()
    : new Date().toISOString();
};

const stripHtml = (value: string): string =>
  value
    .replace(/<[^>]*>/g, ' ')
    .replace(/&nbsp;/gi, ' ')
    .replace(/&amp;/gi, '&')
    .replace(/&quot;/gi, '"')
    .replace(/&#39;/g, "'")
    .replace(/\s+/g, ' ')
    .trim();

const calculateReadingMinutes = (item: NewsItem): number => {
  const raw = item as NewsItem & {
    content?: string;
    items?: Array<{ title?: string; description?: string; body?: string }>;
  };
  const itemContent = Array.isArray(raw.items)
    ? raw.items
        .map((entry) =>
          [entry?.title, entry?.description, entry?.body]
            .map((part) => String(part || ''))
            .join(' '),
        )
        .join(' ')
    : '';
  const totalContent = stripHtml(
    [item.title, item.summary, raw.content, itemContent]
      .map((part) => String(part || ''))
      .join(' '),
  );
  const words = totalContent ? totalContent.split(/\s+/).filter(Boolean).length : 0;
  return Math.max(1, Math.ceil(words / 200));
};

const mapFeaturedItem = (item: NewsItem, origin: string) => {
  const optimizedImage = item.optimizedCoverThumbnail || item.optimizedThumbnail;
  return {
    id: String(item.id || ''),
    category: String(item.category || ''),
    title: String(item.title || ''),
    summary: String(item.summary || ''),
    imageUrl: resolveImageUrl(
      String(
        item.mansetImageUrl ||
          optimizedImage?.src ||
          item.coverThumbnail ||
          item.thumbnail ||
          '',
      ),
      origin,
    ),
    publishedAt: toIsoDate(item.timestamp),
    source: String(item.source || 'Pateeznews'),
    slug: String(item.slug || ''),
    imageAspectRatio: imageAspectRatio(optimizedImage),
  };
};

const mapFeedItem = (item: NewsItem, origin: string) => {
  const raw = item as NewsItem & {
    sourceAvatar?: string;
    isPinned?: boolean;
    publisherId?: string;
    isOfficial?: boolean;
    isVerified?: boolean;
    region?: string;
  };
  const optimizedImage = item.optimizedCoverThumbnail || item.optimizedThumbnail;

  // "Ana sayfada görünsün" seçili blok (görsel veya slider) varsa, kapak yerine
  // o blok ana sayfa kartında gösterilir. Hiçbir blok seçili değilse kapak görseli
  // kullanılır (mevcut davranış).
  const blocks = Array.isArray((item as any).items) ? (item as any).items : [];
  const homepageBlock = blocks.find((b: any) => b && b.showOnHomepage === true);
  const homepageType = String(homepageBlock?.type || '').trim().toLowerCase();

  const sliderImages: string[] =
    homepageBlock && homepageType === 'slider' && Array.isArray(homepageBlock.mediaUrls)
      ? homepageBlock.mediaUrls
          .map((u: any) => resolveImageUrl(String(u || '').trim(), origin))
          .filter((u: string) => Boolean(u))
      : [];

  const homepageImage =
    homepageBlock &&
    homepageType === 'image' &&
    typeof homepageBlock.mediaUrl === 'string' &&
    homepageBlock.mediaUrl.trim()
      ? resolveImageUrl(homepageBlock.mediaUrl.trim(), origin)
      : '';

  const videoUrl =
    homepageBlock &&
    homepageType === 'video' &&
    typeof homepageBlock.mediaUrl === 'string' &&
    homepageBlock.mediaUrl.trim()
      ? resolveImageUrl(homepageBlock.mediaUrl.trim(), origin)
      : '';

  const audioUrl =
    homepageBlock &&
    homepageType === 'audio' &&
    typeof homepageBlock.mediaUrl === 'string' &&
    homepageBlock.mediaUrl.trim()
      ? resolveImageUrl(homepageBlock.mediaUrl.trim(), origin)
      : '';

  const usingHomepageMedia = Boolean(homepageImage) || sliderImages.length > 0;
  const imageUrl = homepageImage || sliderImages[0] || resolveImageUrl(firstMediaUrl(item), origin);

  return {
    id: String(item.id || ''),
    category: String(item.category || ''),
    title: String(item.title || ''),
    summary: String(item.summary || ''),
    imageUrl,
    sliderImages,
    videoUrl,
    audioUrl,
    publishedAt: toIsoDate(item.timestamp),
    source: String(item.source || item.author || 'Pateeznews'),
    sourceAvatar: resolveImageUrl(String(raw.sourceAvatar || ''), origin),
    slug: String(item.slug || ''),
    region: String(raw.region || ''),
    likes: Number(item.likes || 0),
    dislikes: Number(item.dislikes || 0),
    comments: Number(item.comments || 0),
    shares: Number(item.shares || 0),
    views: Number(item.views || 0),
    saves: Number(item.saves || 0),
    readMinutes: calculateReadingMinutes(item),
    publisherId: String(raw.publisherId || ''),
    isPinned: raw.isPinned === true,
    isManset: item.isManset === true,
    isOfficial: raw.isOfficial === true,
    isVerified: raw.isVerified === true,
    imageAspectRatio: usingHomepageMedia ? undefined : imageAspectRatio(optimizedImage),
  };
};

export const GET: APIRoute = async ({ url, request }) => {
  try {
    const lang = String(url.searchParams.get('lang') || 'tr').trim() || 'tr';
    const limit = numberParam(url.searchParams.get('limit'), 10, 1, 20);
    const feedLimit = numberParam(url.searchParams.get('feedLimit'), 30, 1, 50);

    const origin = new URL(request.url).origin;
    const items = await dataService.getNewsItems(lang, 'home', 50);

    const mansetItems = items
      .filter((item: NewsItem) => item.isManset === true)
      .sort((a: NewsItem, b: NewsItem) => getNewsTime(b) - getNewsTime(a));
    const hiddenMansetIds = new Set(
      mansetItems.slice(0, 20).map((item: NewsItem) => String(item.id)),
    );

    const featured = mansetItems
      .slice(0, limit)
      .map((item: NewsItem) => mapFeaturedItem(item, origin));
    const feed = items
      .filter((item: NewsItem) => !hiddenMansetIds.has(String(item.id)))
      .slice(0, feedLimit)
      .map((item: NewsItem) => mapFeedItem(item, origin));

    return json({ featured, feed });
  } catch (error: any) {
    return json({ error: { message: error?.message || 'Home fetch failed' } }, 500);
  }
};
