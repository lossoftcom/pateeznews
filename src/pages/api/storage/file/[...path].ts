import type { APIRoute } from 'astro';
import {
  getStorageType,
  storageObjectPath,
} from '@/lib/server/supabaseStorage';
import {
  LOCAL_STATIC_CACHE,
  LOCAL_STATIC_PREFIX,
} from '@/lib/server/localUploadStorage';
import { getStorageSettings, isLocalStorageActive } from '@/lib/server/storageSettings';

import {
  SUPPORTED_VARIANT_QUALITY,
  TRANSFORMABLE_IMAGE_EXTENSIONS,
  LOCAL_VARIANT_PREFIXES,
  nearestVariantWidth,
  objectExtension,
  variantObjectPath,
} from '@/lib/server/imageVariants';

const IMAGE_VARIANT_CACHE = 'public, max-age=86400, stale-while-revalidate=604800';

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
    return redirect(
      new URL(`${LOCAL_STATIC_PREFIX}${variantPath}`, url.origin),
      IMAGE_VARIANT_CACHE,
    );
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

export const GET: APIRoute = async ({ params, request }) => {
  const filePath = params.path;
  if (!filePath) return new Response('Path is required', { status: 400 });

  const [firstSegment, ...rest] = filePath.split('/');
  const type = getStorageType(firstSegment);
  const objectPath = storageObjectPath(type, rest.length ? rest.join('/') : filePath);
  const url = new URL(request.url);

  const storageSettings = await getStorageSettings();
  if (!isLocalStorageActive(storageSettings)) {
    return new Response('Storage provider is not implemented for file serving', { status: 501 });
  }

  const staticPath = `${LOCAL_STATIC_PREFIX}${objectPath}`;
  const variantRedirect = localImageVariantRedirect(objectPath, staticPath, url);
  if (variantRedirect) return variantRedirect;

  return redirect(new URL(staticPath, url.origin), LOCAL_STATIC_CACHE);
};
