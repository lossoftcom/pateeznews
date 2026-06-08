import type { APIRoute } from 'astro';
import { json } from '@/lib/server/appDb';
import { dataService } from '@/services/dataService.server';

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

export const GET: APIRoute = async ({ url, request }) => {
  try {
    const lang = String(url.searchParams.get('lang') || 'tr').trim() || 'tr';
    const limit = Math.min(Math.max(Number(url.searchParams.get('limit') || 10), 1), 20);

    const origin = new URL(request.url).origin;
    const items = await dataService.getNewsItems(lang, 'home', 50);

    const mansetItems = items
      .filter((item: any) => item.isManset === true)
      .slice(0, limit);

    const featured = mansetItems.map((item: any) => ({
      id: String(item.id || ''),
      category: String(item.category || ''),
      title: String(item.title || ''),
      summary: String(item.summary || ''),
      imageUrl: resolveImageUrl(
        String(
          item.mansetImageUrl || item.coverThumbnail || item.thumbnail || '',
        ),
        origin,
      ),
      publishedAt: item.timestamp ? new Date(item.timestamp).toISOString() : new Date().toISOString(),
      source: String(item.source || 'Pateeznews'),
      slug: String(item.slug || ''),
    }));

    return json({ featured });
  } catch (error: any) {
    return json({ error: { message: error?.message || 'Home fetch failed' } }, 500);
  }
};
