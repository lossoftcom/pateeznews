import type { APIRoute } from 'astro';
import { getSessionFromRequest, json } from '@/lib/server/appDb';
import { mapAppFeedItems } from '@/lib/server/appFeed';
import { dbQuery } from '@/lib/server/supabaseDb';
import { dataService } from '@/services/dataService.server';

export const prerender = false;

const trendValues = new Set([
  'weekly_trends',
  'weekly_likes',
  'weekly_comments',
  'weekly_shares',
  'weekly_reads',
]);

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
      ? await dataService.getWeeklyTrendNewsPage(
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
