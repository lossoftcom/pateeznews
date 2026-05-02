import type { APIRoute } from 'astro';
import { json } from '@/lib/server/appDb';
import { dataService } from '@/services/dataService.server';

export const prerender = false;

export const GET: APIRoute = async ({ url }) => {
  try {
    const lang = String(url.searchParams.get('lang') || 'tr').trim() || 'tr';
    const category = String(url.searchParams.get('category') || '').trim();
    const limit = Math.min(Math.max(Number(url.searchParams.get('limit') || 12), 1), 24);
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

    const page = await dataService.getCategoryNewsPage(lang, category, limit, offset);
    return json(page);
  } catch (error: any) {
    return json({ error: { message: error?.message || 'Category news failed' } }, 500);
  }
};
