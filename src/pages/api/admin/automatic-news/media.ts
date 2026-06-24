import type { APIRoute } from 'astro';
import { adminError, adminJson, requireAnyAdminPermission } from '@/lib/server/adminAuth';
import { adminSecurityHeaders } from '@/lib/server/securityHeaders';
import { dbQuery } from '@/lib/server/supabaseDb';

const USER_AGENT = 'Pateez-AutomaticNewsMedia/1.0 (+https://www.pateez.com)';
const IMAGE_RE = /\.(avif|webp|jpe?g|png|gif)(\?|$)/i;
const VIDEO_RE = /\.(m3u8|mp4|mov|m4v|webm)(\?|$)/i;
const MAX_PAGE_BYTES = 2_500_000;
const MAX_IMAGE_BYTES = 8_000_000;

type Row = {
  source_url: string | null;
  canonical_url: string | null;
  image_url: string | null;
  video_url: string | null;
  media_urls: unknown;
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

function isUsefulVideo(url: string, context = '') {
  if (!url) return false;
  const haystack = `${url} ${context}`;
  return VIDEO_RE.test(url)
    || /(video|reel|player|stream|instagram\.com\/(?:p|reel)\b)/i.test(haystack)
    || (/cdninstagram\.com/i.test(url) && /\/o1\/v\//i.test(url));
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

function payloadVideos(payload: unknown) {
  const videos: string[] = [];
  const visit = (value: unknown, depth = 0) => {
    if (depth > 5 || value == null) return;
    if (typeof value === 'string') {
      if (/^https?:\/\//i.test(value) && isUsefulVideo(value)) addUnique(videos, value);
      return;
    }
    if (Array.isArray(value)) {
      for (const item of value) visit(item, depth + 1);
      return;
    }
    if (typeof value === 'object') {
      for (const [key, item] of Object.entries(value as Record<string, unknown>)) {
        if (/(video|player|stream|media|url|shortcode|reel)/i.test(key)) {
          visit(item, depth + 1);
        }
      }
    }
  };
  visit(payload);
  return videos;
}

function payloadMediaUrls(payload: unknown, mediaUrls: unknown) {
  const urls: string[] = [];
  const visit = (value: unknown, depth = 0) => {
    if (depth > 4 || value == null) return;
    if (typeof value === 'string') {
      if (/^https?:\/\//i.test(value)) addUnique(urls, value);
      return;
    }
    if (Array.isArray(value)) {
      for (const item of value) visit(item, depth + 1);
      return;
    }
    if (typeof value === 'object') {
      for (const [key, item] of Object.entries(value as Record<string, unknown>)) {
        if (/(image|photo|picture|media|display|thumbnail|carousel|sidecar|video|player|url)/i.test(key)) {
          visit(item, depth + 1);
        }
      }
    }
  };
  visit(mediaUrls);
  visit(payload);
  return urls;
}

function srcsetBest(srcset: string) {
  return clean(srcset).split(',').map((part) => part.trim()).filter(Boolean).pop()?.split(/\s+/)[0] || '';
}

function htmlVideos(html: string, baseUrl: string, primary: string) {
  const videos: string[] = [];
  addUnique(videos, absoluteUrl(baseUrl, primary));
  for (const match of html.matchAll(/<meta[^>]+(?:property|name)=["'](?:og:video(?::secure_url|:url)?|twitter:player)["'][^>]+content=["']([^"']+)["'][^>]*>/gi)) {
    addUnique(videos, absoluteUrl(baseUrl, match[1]));
  }
  for (const match of html.matchAll(/<(?:video|source|iframe)[^>]+>/gi)) {
    const tag = match[0];
    const src = tag.match(/\s(?:src|data-src)=["']([^"']+)["']/i)?.[1] || '';
    const url = absoluteUrl(baseUrl, src);
    if (isUsefulVideo(url, tag)) addUnique(videos, url);
  }
  return videos.slice(0, 12);
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

async function readTextLimited(response: Response) {
  const contentLength = Number(response.headers.get('content-length') || 0);
  if (contentLength > MAX_PAGE_BYTES) throw new Error('Sayfa yanıtı çok büyük');
  if (!response.body) return '';
  const reader = response.body.getReader();
  const chunks: Uint8Array[] = [];
  let total = 0;
  while (true) {
    const { done, value } = await reader.read();
    if (done) break;
    if (!value) continue;
    total += value.byteLength;
    if (total > MAX_PAGE_BYTES) {
      await reader.cancel().catch(() => undefined);
      throw new Error('Sayfa yanıtı çok büyük');
    }
    chunks.push(value);
  }
  const bytes = new Uint8Array(total);
  let offset = 0;
  for (const chunk of chunks) {
    bytes.set(chunk, offset);
    offset += chunk.byteLength;
  }
  return new TextDecoder('utf-8').decode(bytes);
}

async function readArrayBufferLimited(response: Response, maxBytes: number) {
  const contentLength = Number(response.headers.get('content-length') || 0);
  if (contentLength > maxBytes) throw Object.assign(new Error('Görsel çok büyük'), { status: 413 });
  if (!response.body) return new ArrayBuffer(0);
  const reader = response.body.getReader();
  const chunks: Uint8Array[] = [];
  let total = 0;
  while (true) {
    const { done, value } = await reader.read();
    if (done) break;
    if (!value) continue;
    total += value.byteLength;
    if (total > maxBytes) {
      await reader.cancel().catch(() => undefined);
      throw Object.assign(new Error('Görsel çok büyük'), { status: 413 });
    }
    chunks.push(value);
  }
  const bytes = new Uint8Array(total);
  let offset = 0;
  for (const chunk of chunks) {
    bytes.set(chunk, offset);
    offset += chunk.byteLength;
  }
  return bytes.buffer;
}

async function fetchPageMedia(pageUrl: string, primaryImage: string, primaryVideo: string) {
  if (!pageUrl) return { images: [] as string[], videos: [] as string[] };
  assertSafeFetchUrl(pageUrl);
  const response = await fetch(pageUrl, {
    signal: AbortSignal.timeout(5500),
    redirect: 'follow',
    headers: { Accept: 'text/html,application/xhtml+xml,*/*;q=0.8', 'User-Agent': USER_AGENT },
  });
  assertSafeFetchUrl(response.url || pageUrl);
  if (!response.ok || !/text\/html|application\/xhtml/i.test(response.headers.get('content-type') || '')) {
    return { images: [], videos: [] };
  }
  const html = await readTextLimited(response);
  const baseUrl = response.url || pageUrl;
  return {
    images: htmlImages(html, baseUrl, primaryImage),
    videos: htmlVideos(html, baseUrl, primaryVideo),
  };
}

async function loadMedia(id: string) {
  const result = await dbQuery<Row>(
    `SELECT source_url, canonical_url, image_url, video_url, media_urls, raw_payload
       FROM public.automatic_news_items
      WHERE id = $1
      LIMIT 1`,
    [id],
  );
  const row = result.rows[0];
  if (!row) return { images: [] as string[], videos: [] as string[], mediaUrls: [] as string[], row: null as Row | null };
  const primary = clean(row.image_url);
  const primaryVideo = clean(row.video_url);
  const pageUrl = clean(row.canonical_url || row.source_url);
  const images: string[] = [];
  const videos: string[] = [];
  const mediaUrls: string[] = [];
  addUnique(images, primary);
  for (const image of payloadImages(row.raw_payload)) addUnique(images, image);
  for (const video of payloadVideos(row.raw_payload)) addUnique(videos, video);
  for (const url of payloadMediaUrls(row.raw_payload, row.media_urls)) addUnique(mediaUrls, url);
  for (const url of mediaUrls) {
    if (isUsefulImage(url)) addUnique(images, url);
  }
  addUnique(videos, primaryVideo);
  for (const mediaUrl of [primary, primaryVideo]) addUnique(mediaUrls, mediaUrl);
  const pageMedia = await fetchPageMedia(pageUrl, primary, primaryVideo).catch(() => ({ images: [], videos: [] }));
  for (const image of pageMedia.images) addUnique(images, image);
  for (const video of pageMedia.videos) addUnique(videos, video);
  for (const image of images) addUnique(mediaUrls, image);
  for (const video of videos) addUnique(mediaUrls, video);
  return { images: images.slice(0, 12), videos: videos.slice(0, 12), mediaUrls: mediaUrls.slice(0, 20), row };
}

export const GET: APIRoute = async ({ request, url }) => {
  try {
    await requireAnyAdminPermission(request, ['automatic_news_view', 'view_settings', 'settings_access']);
    const id = clean(url.searchParams.get('id'));
    if (!id) return adminJson({ data: { images: [] }, error: { message: 'Haber id gerekli' } }, 400);
    const { images, videos, mediaUrls, row } = await loadMedia(id);
    if (!row) return adminJson({ data: { images: [] }, error: { message: 'Haber bulunamadı' } }, 404);

    const imageIndex = Number(url.searchParams.get('image'));
    if (Number.isInteger(imageIndex) && imageIndex >= 0) {
      const target = images[imageIndex];
      if (!target) return adminJson({ data: null, error: { message: 'Görsel bulunamadı' } }, 404);
      assertSafeFetchUrl(target);
      const imageResponse = await fetch(target, {
        signal: AbortSignal.timeout(12000),
        headers: { Accept: 'image/*,*/*;q=0.8', 'User-Agent': USER_AGENT },
      });
      assertSafeFetchUrl(imageResponse.url || target);
      if (!imageResponse.ok) throw Object.assign(new Error('Görsel alınamadı'), { status: imageResponse.status });
      const bytes = await readArrayBufferLimited(imageResponse, MAX_IMAGE_BYTES);
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

    const videoIndex = Number(url.searchParams.get('video'));
    if (Number.isInteger(videoIndex) && videoIndex >= 0) {
      const target = videos[videoIndex];
      if (!target) return adminJson({ data: null, error: { message: 'Video bulunamadı' } }, 404);
      assertSafeFetchUrl(target);
      const range = clean(request.headers.get('range'));
      const headers: Record<string, string> = {
        Accept: 'video/*,*/*;q=0.8',
        'User-Agent': USER_AGENT,
      };
      if (/^bytes=/i.test(range)) headers.Range = range;
      const videoResponse = await fetch(target, {
        signal: AbortSignal.timeout(30000),
        headers,
      });
      assertSafeFetchUrl(videoResponse.url || target);
      if (!videoResponse.ok && videoResponse.status !== 206) {
        throw Object.assign(new Error('Video alınamadı'), { status: videoResponse.status });
      }
      const responseHeaders = new Headers({
        'Content-Type': videoResponse.headers.get('content-type') || 'video/mp4',
        'Cache-Control': 'private, max-age=120',
        'Accept-Ranges': videoResponse.headers.get('accept-ranges') || 'bytes',
        'X-Pateez-Video-Proxy': '1',
        ...adminSecurityHeaders(),
      });
      const contentLength = videoResponse.headers.get('content-length');
      const contentRange = videoResponse.headers.get('content-range');
      if (contentLength) responseHeaders.set('Content-Length', contentLength);
      if (contentRange) responseHeaders.set('Content-Range', contentRange);
      return new Response(videoResponse.body, {
        status: videoResponse.status,
        headers: responseHeaders,
      });
    }

    return adminJson({
      data: {
        images,
        videos,
        mediaUrls,
        primaryImageUrl: clean(row.image_url),
        primaryVideoUrl: clean(row.video_url),
        sourceUrl: row.source_url || '',
        canonicalUrl: row.canonical_url || '',
      },
      error: null,
    });
  } catch (error) {
    return adminError(error);
  }
};

function assertSafeFetchUrl(value: string) {
  const parsed = new URL(value);
  if (parsed.protocol !== 'http:' && parsed.protocol !== 'https:') {
    throw Object.assign(new Error('Geçersiz medya adresi'), { status: 400 });
  }
  const host = parsed.hostname.toLowerCase().replace(/^\[(.*)]$/, '$1');
  if (
    host === 'localhost' ||
    host.endsWith('.localhost') ||
    host === 'metadata.google.internal' ||
    host === '169.254.169.254' ||
    /^0\./.test(host) ||
    /^10\./.test(host) ||
    /^127\./.test(host) ||
    /^169\.254\./.test(host) ||
    /^172\.(1[6-9]|2\d|3[0-1])\./.test(host) ||
    /^192\.168\./.test(host) ||
    host === '::1' ||
    host.startsWith('fc') ||
    host.startsWith('fd') ||
    host.startsWith('fe80:')
  ) {
    throw Object.assign(new Error('Güvenli olmayan medya adresi engellendi'), { status: 400 });
  }
}
