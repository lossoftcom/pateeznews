import type { APIRoute } from 'astro';
import { adminError, adminJson, requireAnyAdminPermission } from '@/lib/server/adminAuth';
import { adminSecurityHeaders } from '@/lib/server/securityHeaders';
import { dbQuery } from '@/lib/server/supabaseDb';

const USER_AGENT = 'Pateez-AutomaticNews/1.0 (+https://www.pateez.com)';
const MAX_IMAGE_BYTES = 8_000_000;

export const GET: APIRoute = async ({ request, url }) => {
  try {
    await requireAnyAdminPermission(request, ['automatic_news_view', 'view_settings', 'settings_access']);
    const id = String(url.searchParams.get('id') || '').trim();
    const inline = String(url.searchParams.get('disposition') || '').trim() === 'inline';
    if (!id) {
      return adminJson({ data: null, error: { message: 'İndirilecek haber seçilmedi' } }, 400);
    }

    const result = await dbQuery<{ display_id: number; title: string | null; image_url: string | null }>(
      `SELECT display_id, title, image_url
       FROM public.automatic_news_items
       WHERE id = $1::uuid
       LIMIT 1`,
      [id],
    );
    const row = result.rows[0];
    const imageUrl = String(row?.image_url || '').trim();
    if (!row || !imageUrl) {
      return adminJson({ data: null, error: { message: 'Bu otomatik haberde indirilecek görsel yok' } }, 404);
    }

    const targetUrl = resolveImageUrl(imageUrl, request.url);
    assertSafeFetchUrl(targetUrl);
    const response = await fetch(targetUrl, {
      signal: AbortSignal.timeout(12000),
      headers: {
        Accept: 'image/*,*/*;q=0.8',
        'User-Agent': USER_AGENT,
      },
    });
    assertSafeFetchUrl(response.url || targetUrl);
    if (!response.ok) {
      throw Object.assign(new Error('Görsel indirilemedi'), { status: response.status });
    }

    const contentType = response.headers.get('content-type') || 'application/octet-stream';
    if (!/^image\//i.test(contentType)) {
      throw Object.assign(new Error('Görsel yanıtı geçersiz'), { status: 415 });
    }
    const bytes = await readArrayBufferLimited(response, MAX_IMAGE_BYTES);
    const fileName = imageFileName(String(row.title || ''), Number(row.display_id || 0), contentType, targetUrl);
    return new Response(bytes, {
      status: 200,
      headers: {
        'Content-Type': contentType,
        'Content-Length': String(bytes.byteLength),
        'Content-Disposition': inline ? inlineContentDisposition(fileName) : contentDisposition(fileName),
        'Cache-Control': 'no-store, no-cache, must-revalidate, proxy-revalidate',
        'CDN-Cache-Control': 'no-store',
        'Cloudflare-CDN-Cache-Control': 'no-store',
        'Vary': 'Authorization',
        ...(inline
          ? { 'X-Pateez-Image-Proxy': '1' }
          : { 'X-Pateez-File-Name': encodeURIComponent(fileName) }),
        ...adminSecurityHeaders(),
      },
    });
  } catch (error) {
    return adminError(error);
  }
};

function resolveImageUrl(imageUrl: string, requestUrl: string) {
  try {
    const parsed = new URL(imageUrl);
    if (parsed.protocol === 'http:' || parsed.protocol === 'https:') return parsed.toString();
  } catch {
    // Relative upload paths are resolved against the current admin origin.
  }
  return new URL(imageUrl, new URL(requestUrl).origin).toString();
}

function assertSafeFetchUrl(value: string) {
  const parsed = new URL(value);
  if (parsed.protocol !== 'http:' && parsed.protocol !== 'https:') {
    throw Object.assign(new Error('Geçersiz görsel adresi'), { status: 400 });
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
    throw Object.assign(new Error('Güvenli olmayan görsel adresi engellendi'), { status: 400 });
  }
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

function imageFileName(title: string, displayId: number, contentType: string, imageUrl: string) {
  const base = slugifyFileName(title) || `otomatik-haber-${displayId || Date.now()}`;
  const extension = extensionFromContentType(contentType) || extensionFromUrl(imageUrl) || 'jpg';
  return `${base}.${extension}`;
}

function slugifyFileName(value: string) {
  return value
    .trim()
    .toLocaleLowerCase('tr-TR')
    .replace(/ğ/g, 'g')
    .replace(/ü/g, 'u')
    .replace(/ş/g, 's')
    .replace(/ı/g, 'i')
    .replace(/ö/g, 'o')
    .replace(/ç/g, 'c')
    .normalize('NFD')
    .replace(/[\u0300-\u036f]/g, '')
    .replace(/[^a-z0-9]+/g, '-')
    .replace(/^-+|-+$/g, '')
    .slice(0, 90);
}

function extensionFromContentType(contentType: string) {
  const type = contentType.split(';')[0]?.trim().toLowerCase();
  if (type === 'image/jpeg' || type === 'image/jpg') return 'jpg';
  if (type === 'image/png') return 'png';
  if (type === 'image/webp') return 'webp';
  if (type === 'image/gif') return 'gif';
  if (type === 'image/avif') return 'avif';
  return '';
}

function extensionFromUrl(imageUrl: string) {
  try {
    const pathname = new URL(imageUrl).pathname;
    const match = pathname.match(/\.([a-z0-9]{2,5})$/i);
    return match ? match[1].toLowerCase() : '';
  } catch {
    return '';
  }
}

function contentDisposition(fileName: string) {
  const asciiName = fileName.replace(/[^a-zA-Z0-9._-]+/g, '-');
  return `attachment; filename="${asciiName}"; filename*=UTF-8''${encodeURIComponent(fileName)}`;
}

function inlineContentDisposition(fileName: string) {
  const asciiName = fileName.replace(/[^a-zA-Z0-9._-]+/g, '-');
  return `inline; filename="${asciiName}"; filename*=UTF-8''${encodeURIComponent(fileName)}`;
}
