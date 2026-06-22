import type { APIRoute } from 'astro';
import { adminError, adminJson, requireAdminRequest } from '@/lib/server/adminAuth';
import { adminSecurityHeaders } from '@/lib/server/securityHeaders';
import { dbQuery } from '@/lib/server/supabaseDb';

const USER_AGENT = 'Pateez-AutomaticNewsMedia/1.0 (+https://www.pateez.com)';
const IMAGE_RE = /\.(avif|webp|jpe?g|png|gif)(\?|$)/i;

type Row = {
  source_url: string | null;
  canonical_url: string | null;
  image_url: string | null;
  raw_payload: unknown;
};

const clean = (value: unknown) => String(value || '').replace(/\s+/g, ' ').trim();

function absoluteUrl(base: string, value: string) {
  const raw = clean(value);
  if (!raw || raw.startsWith('data:') || raw.startsWith('blob:') || raw.startsWith('#')) return '';
  try {
    const url = new URL(raw, base);
    if (url.protocol !== 'http:' && url.protocol !== 'https:') return '';
    url.hash = '';
    return url.toString();
  } catch {
    return '';
  }
}

function addUnique(list: string[], value: string) {
  const url = clean(value);
  if (!url) return;
  const key = url.replace(/\?.*$/, '');
  if (!list.some((item) => item.replace(/\?.*$/, '') === key)) list.push(url);
}

function isUsefulImage(url: string, context = '') {
  if (!url) return false;
  const haystack = `${url} ${context}`.toLowerCase();
  if (!IMAGE_RE.test(url) && !/(image|uploads|media|cdn|crop)/i.test(url)) return false;
  if (/(logo|favicon|sprite|icon|avatar|author|profile|placeholder|default|loading|blank|pixel|emoji|whatsapp|telegram|advert|banner|reklam|share|social|footer|header|menu|nav|breadcrumb|comment|yorum)/i.test(haystack)) return false;
  return true;
}

function payloadImages(payload: unknown) {
  const images: string[] = [];
  const visit = (value: unknown, depth = 0) => {
    if (depth > 5 || value == null) return;
    if (typeof value === 'string') {
      if (/^https?:\/\//i.test(value) && isUsefulImage(value)) addUnique(images, value);
      return;
    }
    if (Array.isArray(value)) {
      for (const item of value) visit(item, depth + 1);
      return;
    }
    if (typeof value === 'object') {
      for (const [key, item] of Object.entries(value as Record<string, unknown>)) {
        if (/(image|photo|picture|media|display|thumbnail|carousel|sidecar|url)/i.test(key)) {
          visit(item, depth + 1);
        }
      }
    }
  };
  visit(payload);
  return images;
}

function srcsetBest(srcset: string) {
  return clean(srcset).split(',').map((part) => part.trim()).filter(Boolean).pop()?.split(/\s+/)[0] || '';
}

function htmlImages(html: string, baseUrl: string, primary: string) {
  const images: string[] = [];
  addUnique(images, absoluteUrl(baseUrl, primary));
  for (const match of html.matchAll(/<meta[^>]+(?:property|name)=["'](?:og:image|twitter:image)["'][^>]+content=["']([^"']+)["'][^>]*>/gi)) {
    addUnique(images, absoluteUrl(baseUrl, match[1]));
  }
  for (const match of html.matchAll(/<img[^>]+>/gi)) {
    const tag = match[0];
    const src = tag.match(/\s(?:src|data-src|data-original|data-lazy-src|data-large|data-full)=["']([^"']+)["']/i)?.[1]
      || srcsetBest(tag.match(/\ssrcset=["']([^"']+)["']/i)?.[1] || '')
      || srcsetBest(tag.match(/\sdata-srcset=["']([^"']+)["']/i)?.[1] || '');
    const url = absoluteUrl(baseUrl, src);
    if (isUsefulImage(url, tag)) addUnique(images, url);
  }
  return images.slice(0, 12);
}

async function fetchPageImages(pageUrl: string, primary: string) {
  if (!pageUrl) return [];
  const response = await fetch(pageUrl, {
    signal: AbortSignal.timeout(5500),
    redirect: 'follow',
    headers: { Accept: 'text/html,application/xhtml+xml,*/*;q=0.8', 'User-Agent': USER_AGENT },
  });
  if (!response.ok || !/text\/html|application\/xhtml/i.test(response.headers.get('content-type') || '')) return [];
  return htmlImages(await response.text(), response.url || pageUrl, primary);
}

async function loadImages(id: string) {
  const result = await dbQuery<Row>(
    `SELECT source_url, canonical_url, image_url, raw_payload
       FROM public.automatic_news_items
      WHERE id = $1
      LIMIT 1`,
    [id],
  );
  const row = result.rows[0];
  if (!row) return { images: [] as string[], row: null as Row | null };
  const primary = clean(row.image_url);
  const pageUrl = clean(row.canonical_url || row.source_url);
  const images: string[] = [];
  for (const image of payloadImages(row.raw_payload)) addUnique(images, image);
  addUnique(images, primary);
  for (const image of await fetchPageImages(pageUrl, primary).catch(() => [])) addUnique(images, image);
  return { images: images.slice(0, 12), row };
}

export const GET: APIRoute = async ({ request, url }) => {
  try {
    await requireAdminRequest(request, 'view_settings');
    const id = clean(url.searchParams.get('id'));
    if (!id) return adminJson({ data: { images: [] }, error: { message: 'Haber id gerekli' } }, 400);
    const { images, row } = await loadImages(id);
    if (!row) return adminJson({ data: { images: [] }, error: { message: 'Haber bulunamadı' } }, 404);

    const imageIndex = Number(url.searchParams.get('image'));
    if (Number.isInteger(imageIndex) && imageIndex >= 0) {
      const target = images[imageIndex];
      if (!target) return adminJson({ data: null, error: { message: 'Görsel bulunamadı' } }, 404);
      const imageResponse = await fetch(target, {
        signal: AbortSignal.timeout(12000),
        headers: { Accept: 'image/*,*/*;q=0.8', 'User-Agent': USER_AGENT },
      });
      if (!imageResponse.ok) throw Object.assign(new Error('Görsel alınamadı'), { status: imageResponse.status });
      const bytes = await imageResponse.arrayBuffer();
      return new Response(bytes, {
        status: 200,
        headers: {
          'Content-Type': imageResponse.headers.get('content-type') || 'application/octet-stream',
          'Cache-Control': 'private, max-age=120',
          'X-Pateez-Image-Proxy': '1',
          ...adminSecurityHeaders(),
        },
      });
    }

    return adminJson({ data: { images, primaryImageUrl: clean(row.image_url), sourceUrl: row.source_url || '', canonicalUrl: row.canonical_url || '' }, error: null });
  } catch (error) {
    return adminError(error);
  }
};
