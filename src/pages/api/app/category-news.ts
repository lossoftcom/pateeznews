import type { APIRoute } from 'astro';
import { getSessionFromRequest, json } from '@/lib/server/appDb';
import { getNewsTime, mapAppFeedItems } from '@/lib/server/appFeed';
import { dbQuery } from '@/lib/server/supabaseDb';
import { dataService } from '@/services/dataService.server';
import type { NewsItem } from '@/types';

export const prerender = false;

const trendValues = new Set([
  'weekly_trends',
  'weekly_likes',
  'weekly_comments',
  'weekly_shares',
  'weekly_reads',
]);

const numberValue = (value: unknown) => {
  const parsed = Number(value || 0);
  return Number.isFinite(parsed) ? parsed : 0;
};

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

const loadContentPageSize = async (lang: string) => {
  const languageCode = String(lang || 'tr').trim() || 'tr';
  const fetchSettings = async (code: string) => {
    const result = await dbQuery(
      `SELECT content_home_page_size
       FROM public.site_settings
       WHERE language_code = $1
       LIMIT 1`,
      [code],
    );
    return result.rows[0] || null;
  };
  try {
    const row =
      (await fetchSettings(languageCode)) ||
      (languageCode === 'tr' ? null : await fetchSettings('tr'));
    return numberParam(
      row?.content_home_page_size == null ? null : String(row.content_home_page_size),
      16,
      1,
      50,
    );
  } catch {
    return 16;
  }
};

const trendScore = (item: NewsItem, trendValue: string) => {
  const likes = numberValue(item.likes);
  const comments = numberValue(item.comments);
  const shares = numberValue(item.shares);
  const views = numberValue(item.views);
  const saves = numberValue(item.saves);
  const dislikes = numberValue(item.dislikes);
  switch (trendValue) {
    case 'weekly_likes':
      return likes;
    case 'weekly_comments':
      return comments;
    case 'weekly_shares':
      return shares;
    case 'weekly_reads':
      return views;
    default:
      return (
        Math.log1p(views) +
        Math.log1p(likes) * 2.4 +
        Math.log1p(comments) * 2.2 +
        Math.log1p(shares) * 2.8 +
        Math.log1p(saves) * 2.5 -
        Math.log1p(dislikes) * 1.1
      );
  }
};

const weeklyTrendPage = async (
  lang: string,
  trendValue: string,
  limit: number,
  offset: number,
) => {
  const sourceLimit = Math.max(80, offset + limit + 20);
  const items = await dataService.getNewsItems(lang, 'home', sourceLimit);
  const weekStart = Date.now() - 7 * 24 * 60 * 60 * 1000;
  const weeklyItems = items.filter((item) => getNewsTime(item) >= weekStart);
  const source = weeklyItems.length > 0 ? weeklyItems : items;
  const sorted = [...source].sort((a, b) => {
    const score = trendScore(b, trendValue) - trendScore(a, trendValue);
    return score !== 0 ? score : getNewsTime(b) - getNewsTime(a);
  });
  const pageItems = sorted.slice(offset, offset + limit);
  const nextOffset = offset + pageItems.length;
  return {
    items: pageItems,
    total: sorted.length,
    totalViews: sorted.reduce((sum, item) => sum + numberValue(item.views), 0),
    nextOffset,
    hasMore: nextOffset < sorted.length,
    limit,
    offset,
  };
};

export const GET: APIRoute = async ({ url, request }) => {
  try {
    const lang = String(url.searchParams.get('lang') || 'tr').trim() || 'tr';
    const category = String(url.searchParams.get('category') || '').trim();
    const type = String(url.searchParams.get('type') || '').trim().toLowerCase();
    const value = String(url.searchParams.get('value') || '').trim().toLowerCase();
    const settingsLimit = await loadContentPageSize(lang);
    const limit = numberParam(url.searchParams.get('limit'), settingsLimit, 1, 50);
    const offset = Math.max(Number(url.searchParams.get('offset') || 0), 0);

    if (!category) {
      return json({
        items: [],
        total: 0,
        totalViews: 0,
        nextOffset: offset,
        hasMore: false,
        limit,
        offset,
      });
    }

    const page = type === 'trends' || trendValues.has(value)
      ? await weeklyTrendPage(
          lang,
          trendValues.has(value) ? value : 'weekly_trends',
          limit,
          offset,
        )
      : await dataService.getCategoryNewsPage(lang, category, limit, offset, {
          includeTypeAliases: false,
        });
    const origin = new URL(url).origin;
    const session = await getSessionFromRequest(request);
    const userId = session?.user?.id || null;
    const items = await mapAppFeedItems(page.items, origin, userId);
    return json({ ...page, items });
  } catch (error: any) {
    return json({ error: { message: error?.message || 'Category news failed' } }, 500);
  }
};
