import type { APIRoute } from 'astro';
import {
  getStorageType,
  publicStorageUrl,
  type StorageType,
  storageObjectPath,
} from '@/lib/server/supabaseStorage';
import {
  LOCAL_STATIC_CACHE,
  exactLocalStaticPath,
  localStaticPath,
} from '@/lib/server/localUploadStorage';

const REMOTE_IMAGE_CACHE = 'public, max-age=86400, stale-while-revalidate=604800';
const REMOTE_MUTABLE_CACHE = 'public, max-age=3600, stale-while-revalidate=86400';

function parseBoundedInt(value: string | null, min: number, max: number) {
  if (!value) return null;
  const parsed = Number.parseInt(value, 10);
  if (!Number.isFinite(parsed)) return null;
  return Math.min(Math.max(parsed, min), max);
}

function isLocalRequest(request: Request) {
  const hostname = new URL(request.url).hostname;
  return hostname === 'localhost' || hostname === '127.0.0.1' || hostname === '::1' || hostname === '[::1]' || import.meta.env.DEV;
}

function redirect(location: URL | string, cacheControl: string) {
  return new Response(null, {
    status: 302,
    headers: {
      Location: location.toString(),
      'Cache-Control': cacheControl,
      'CDN-Cache-Control': cacheControl,
      'Cloudflare-CDN-Cache-Control': cacheControl,
    },
  });
}

function remoteRedirectCache(type: StorageType) {
  return type === 'image' ? REMOTE_IMAGE_CACHE : REMOTE_MUTABLE_CACHE;
}

export const GET: APIRoute = async ({ params, request }) => {
  const filePath = params.path;
  if (!filePath) return new Response('Path is required', { status: 400 });

  const [firstSegment, ...rest] = filePath.split('/');
  const type = getStorageType(firstSegment);
  const objectPath = storageObjectPath(type, rest.length ? rest.join('/') : filePath);
  const url = new URL(request.url);
  const width = parseBoundedInt(url.searchParams.get('w'), 64, 2400);
  const quality = parseBoundedInt(url.searchParams.get('q'), 40, 100);
  const staticPath = exactLocalStaticPath(objectPath);

  if (staticPath) return redirect(new URL(staticPath, url.origin), LOCAL_STATIC_CACHE);

  if (isLocalRequest(request)) {
    const fallbackPath = localStaticPath(type, objectPath);
    if (fallbackPath) return redirect(new URL(fallbackPath, url.origin), LOCAL_STATIC_CACHE);
  }

  return redirect(publicStorageUrl(objectPath, request, { width, quality }), remoteRedirectCache(type));
};
