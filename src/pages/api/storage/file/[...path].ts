import type { APIRoute } from 'astro';
import {
  getStorageType,
  publicStorageUrl,
  type StorageType,
  storageObjectPath,
} from '@/lib/server/supabaseStorage';

const LOCAL_STATIC_PREFIX = '/local-upload/';
const LOCAL_STATIC_CACHE = 'public, max-age=86400, stale-while-revalidate=604800';
const REMOTE_IMAGE_CACHE = 'public, max-age=86400, stale-while-revalidate=604800';
const REMOTE_MUTABLE_CACHE = 'public, max-age=3600, stale-while-revalidate=86400';

const LOCAL_FALLBACKS: Partial<Record<StorageType, string[]>> = {
  image: [
    'image/fallback/pateez-news-placeholder.webp',
    'image/2026-05-24/1779656233738-d-s-c02472.webp',
    'image/2026-05-24/1779656103320-Ekran_Resmi_2026-05-24_23.39.03.webp',
  ],
  logo: [
    'logo/tr/pateezlogoson.png',
    'logo/tr/pateezlogowhite.png',
    'logo/tr/pateezlogoicon.png',
  ],
  profile: [
    'profile/6c1a27d3-ce8e-4c42-bec1-fc092139e3ee-avatar.webp',
    'profile/nasip-avatar.webp',
  ],
};

const LOCAL_STATIC_FILES = new Set([
  'image/fallback/pateez-news-placeholder.webp',
  'image/2026-05-24/1779656233738-d-s-c02472.webp',
  'image/2026-05-24/1779656103320-Ekran_Resmi_2026-05-24_23.39.03.webp',
  'image/2026-05-25/1779657593087-hugging-asian-couple-stands-before-beautiful-waterfall-mountains.webp',
  'image/2026-05-25/1779657690981-5972469.webp',
  'image/2026-05-25/1779657607042-numerology-concept-with-woman-beach.webp',
  'logo/tr/pateezlogoson.png',
  'logo/tr/pateezlogowhite.png',
  'logo/tr/pateezlogoicon.png',
  'logo/tr/pateezlogodark.png',
  'logo/tr/pateezlogoepost.png',
  'logo/tr/pateezlogofooter.png',
  'profile/6c1a27d3-ce8e-4c42-bec1-fc092139e3ee-avatar.webp',
  'profile/6c1a27d3-ce8e-4c42-bec1-fc092139e3ee-cover.webp',
  'profile/nasip-avatar.webp',
  'profile/nasip-cover.webp',
]);

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

function localStaticPath(type: StorageType, objectPath: string) {
  if (LOCAL_STATIC_FILES.has(objectPath)) return `${LOCAL_STATIC_PREFIX}${objectPath}`;
  const fallback = LOCAL_FALLBACKS[type]?.[0];
  return fallback ? `${LOCAL_STATIC_PREFIX}${fallback}` : null;
}

function exactLocalStaticPath(objectPath: string) {
  return LOCAL_STATIC_FILES.has(objectPath) ? `${LOCAL_STATIC_PREFIX}${objectPath}` : null;
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
