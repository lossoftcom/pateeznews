import type { APIRoute } from 'astro';
import {
  getStorageType,
  storageObjectPath,
} from '@/lib/server/supabaseStorage';
import {
  exactLocalStaticPath,
  LOCAL_STATIC_CACHE,
  LOCAL_STATIC_PREFIX,
} from '@/lib/server/localUploadStorage';
import {
  getStorageSettings,
  isLocalStorageActive,
  isS3CompatibleStorageActive,
  localBackupEnabled,
} from '@/lib/server/storageSettings';
import { getRemoteStorageFile } from '@/lib/server/remoteObjectStorage';

import {
  SUPPORTED_VARIANT_QUALITY,
  TRANSFORMABLE_IMAGE_EXTENSIONS,
  LOCAL_VARIANT_PREFIXES,
  nearestVariantWidth,
  objectExtension,
  variantObjectPath,
} from '@/lib/server/imageVariants';

const IMAGE_VARIANT_CACHE = 'public, max-age=86400, stale-while-revalidate=604800';
const REMOTE_READ_FALLBACK_TIMEOUT_MS = 1400;
const LEGACY_IMAGE_LOCAL_PREFIXES = ['image/announcements/', 'image/navigation/'];

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

function boundedNumberParam(
  value: string | null,
  fallback: number,
  min: number,
  max: number,
) {
  const parsed = Number(value ?? fallback);
  if (!Number.isFinite(parsed)) return fallback;
  return Math.min(Math.max(Math.round(parsed), min), max);
}

function imageVariantOptions(url: URL) {
  const width = boundedNumberParam(url.searchParams.get('w'), 0, 0, 3840);
  if (width <= 0) return null;
  return {
    width: nearestVariantWidth(width),
    quality: SUPPORTED_VARIANT_QUALITY,
  };
}

function isLocalDevHost(url: URL) {
  return url.hostname === 'localhost' ||
    url.hostname === '127.0.0.1' ||
    url.hostname === '0.0.0.0' ||
    url.hostname === '::1';
}

function cloudflareImageResizePath(staticPath: string, width: number, quality: number) {
  return `/cdn-cgi/image/width=${width},quality=${quality},format=auto${staticPath}`;
}

function localImageVariantRedirect(objectPath: string, staticPath: string, url: URL) {
  const options = imageVariantOptions(url);
  if (!options) return null;

  const extension = objectExtension(objectPath);
  if (!TRANSFORMABLE_IMAGE_EXTENSIONS.has(extension)) return null;

  if (LOCAL_VARIANT_PREFIXES.some((prefix) => objectPath.startsWith(prefix))) {
    const variantPath = variantObjectPath(
      objectPath,
      options.width,
      options.quality,
    );
    if (exactLocalStaticPath(variantPath)) {
      return redirect(
        new URL(`${LOCAL_STATIC_PREFIX}${variantPath}`, url.origin),
        IMAGE_VARIANT_CACHE,
      );
    }
    return null;
  }

  if (!isLocalDevHost(url)) {
    return redirect(
      new URL(
        cloudflareImageResizePath(staticPath, options.width, options.quality),
        url.origin,
      ),
      IMAGE_VARIANT_CACHE,
    );
  }

  return null;
}

function remoteImageResizeRedirect(_objectPath: string, _url: URL) {
  return null;
}

function localStorageRedirectIfAvailable(objectPath: string, url: URL, options: { force?: boolean } = {}) {
  const legacyStaticPath = legacyImageLocalStaticPath(objectPath);
  const staticPath = exactLocalStaticPath(objectPath) || legacyStaticPath;
  if (staticPath) {
    const variantRedirect = localImageVariantRedirect(objectPath, staticPath, url);
    if (variantRedirect) return variantRedirect;
    return redirect(new URL(staticPath, url.origin), LOCAL_STATIC_CACHE);
  }
  if (!options.force) return null;
  return redirect(new URL(legacyImageLocalPath(objectPath) || `${LOCAL_STATIC_PREFIX}${objectPath}`, url.origin), LOCAL_STATIC_CACHE);
}

function legacyImageLocalPath(objectPath: string) {
  return LEGACY_IMAGE_LOCAL_PREFIXES.some((prefix) => objectPath.startsWith(prefix))
    ? `${LOCAL_STATIC_PREFIX}${objectPath.slice('image/'.length)}`
    : '';
}

function legacyImageLocalStaticPath(objectPath: string) {
  return LEGACY_IMAGE_LOCAL_PREFIXES.some((prefix) => objectPath.startsWith(prefix))
    ? exactLocalStaticPath(objectPath.slice('image/'.length))
    : null;
}

export const GET: APIRoute = async ({ params, request }) => {
  const filePath = params.path;
  if (!filePath) return new Response('Path is required', { status: 400 });

  const [firstSegment, ...rest] = filePath.split('/');
  const type = getStorageType(firstSegment);
  const objectPath = storageObjectPath(type, rest.length ? rest.join('/') : filePath);
  const url = new URL(request.url);

  const storageSettings = await getStorageSettings();
  if (isS3CompatibleStorageActive(storageSettings)) {
    const localFallback = localStorageRedirectIfAvailable(
      objectPath,
      url,
      { force: localBackupEnabled(storageSettings) },
    );
    const remoteResize = remoteImageResizeRedirect(objectPath, url);
    if (remoteResize) return remoteResize;

    try {
      const remoteResponse = await getRemoteStorageFile(
        storageSettings,
        objectPath,
        request,
        localFallback ? { timeoutMs: REMOTE_READ_FALLBACK_TIMEOUT_MS } : {},
      );
      if (remoteResponse.ok || !localFallback) {
        const headers = new Headers(remoteResponse.headers);
        headers.set('Cache-Control', LOCAL_STATIC_CACHE);
        headers.set('CDN-Cache-Control', LOCAL_STATIC_CACHE);
        headers.set('Cloudflare-CDN-Cache-Control', LOCAL_STATIC_CACHE);
        return new Response(remoteResponse.body, {
          status: remoteResponse.status,
          statusText: remoteResponse.statusText,
          headers,
        });
      }
    } catch (error) {
      if (!localFallback) throw error;
    }

    return localFallback;
  }

  if (!isLocalStorageActive(storageSettings)) {
    return new Response('Storage provider is not implemented for file serving', { status: 501 });
  }

  const staticPath = `${LOCAL_STATIC_PREFIX}${objectPath}`;
  const variantRedirect = localImageVariantRedirect(objectPath, staticPath, url);
  if (variantRedirect) return variantRedirect;

  return redirect(new URL(staticPath, url.origin), LOCAL_STATIC_CACHE);
};
