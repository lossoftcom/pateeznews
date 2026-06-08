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
  return redirect(new URL(staticPath, url.origin), LOCAL_STATIC_CACHE);
};
