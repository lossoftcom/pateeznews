import type { APIRoute } from 'astro';
import fs from 'fs';
import path from 'path';
import { requireStorageAdminRequest } from '@/lib/server/storageAdminAuth';
import {
  getStorageSettings,
  isLocalStorageActive,
  isS3CompatibleStorageActive,
  localBackupEnabled,
  recordLocalMediaFile,
  recordStorageMediaFile,
} from '@/lib/server/storageSettings';
import { deleteLocalStorageFile, resolveLocalStorageVideoThumb } from '@/lib/server/localStorageProxy';
import { resolveLocalUploadPath } from '@/lib/server/localUploadStorage';
import { contentTypeForFilename, getStorageType, normalizeStoragePath } from '@/lib/server/supabaseStorage';
import { activeRemoteProvider, remoteApiPath, uploadRemoteStorageObject } from '@/lib/server/remoteObjectStorage';

const JSON_HEADERS = { 'Content-Type': 'application/json' };

const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), { status, headers: JSON_HEADERS });

const cleanYoutubeId = (value: string) => {
  const match = String(value || '').match(/[_\-a-zA-Z0-9]{11}/);
  return match?.[0] || '';
};

const youtubeIdFrom = (value: string) => {
  try {
    const parsed = new URL(value, 'https://example.invalid');
    const host = parsed.hostname.toLowerCase();
    if (
      !host.includes('youtube.com') &&
      !host.includes('youtu.be') &&
      !host.includes('youtube-nocookie.com')
    ) {
      return '';
    }
    if (host.includes('youtu.be')) {
      return cleanYoutubeId(parsed.pathname.split('/').filter(Boolean)[0] || '');
    }
    const queryId = cleanYoutubeId(parsed.searchParams.get('v') || '');
    if (queryId) return queryId;
    const segments = parsed.pathname.split('/').filter(Boolean);
    for (let index = 0; index < segments.length - 1; index += 1) {
      const segment = segments[index].toLowerCase();
      if (segment === 'shorts' || segment === 'embed' || segment === 'live') {
        return cleanYoutubeId(segments[index + 1]);
      }
    }
  } catch {
    return '';
  }
  return '';
};

const youtubeThumbUrl = (url: string) => {
  const id = youtubeIdFrom(url);
  return id ? `https://img.youtube.com/vi/${id}/hqdefault.jpg` : '';
};

function storageObjectPathFromMediaUrl(value: string) {
  const clean = String(value || '').split(/[?#]/)[0];
  const apiMarker = '/api/storage/file/';
  const localMarker = '/local-upload/';
  const apiIndex = clean.indexOf(apiMarker);
  if (apiIndex >= 0) return normalizeStoragePath(clean.slice(apiIndex + apiMarker.length));
  const localIndex = clean.indexOf(localMarker);
  if (localIndex >= 0) return normalizeStoragePath(clean.slice(localIndex + localMarker.length));
  return '';
}

async function readLocalVideoThumb(objectPath: string) {
  const [typeValue, ...rest] = normalizeStoragePath(objectPath).split('/');
  const type = getStorageType(typeValue);
  if (type !== 'video' || !rest.length) return null;
  const id = rest.join('/');
  const resolved = resolveLocalUploadPath(type, id);
  if (!resolved || !fs.existsSync(resolved.absolutePath)) return null;
  const stat = await fs.promises.stat(resolved.absolutePath);
  if (!stat.isFile()) return null;
  const parsed = path.posix.parse(id);
  return {
    id,
    type,
    value: parsed.base,
    path: parsed.dir,
    size: stat.size,
    contentType: contentTypeForFilename(id),
    buffer: await fs.promises.readFile(resolved.absolutePath),
  };
}

export const POST: APIRoute = async ({ request }) => {
  try {
    await requireStorageAdminRequest(request, 'video');
    const body = await request.json().catch(() => ({}));
    const url = String(body?.url || body?.videoUrl || '').trim();
    const title = String(body?.title || body?.context || '').trim();
    if (!url) return json({ error: 'Video URL required' }, 400);

    const youtubeThumb = youtubeThumbUrl(url);
    if (youtubeThumb) {
      return json({
        success: true,
        thumb: youtubeThumb,
        thumbnailUrl: youtubeThumb,
        provider: 'youtube',
      });
    }

    const settings = await getStorageSettings();
    if (isS3CompatibleStorageActive(settings)) {
      const result = await resolveLocalStorageVideoThumb({ url, title });
      const localThumb = String(result?.thumb || '').trim();
      const objectPath = storageObjectPathFromMediaUrl(localThumb);
      const localFile = objectPath ? await readLocalVideoThumb(objectPath) : null;
      if (!localFile) {
        return json({
          success: false,
          thumb: '',
          thumbnailUrl: '',
          provider: settings.activeStorage,
        });
      }

      const remoteThumb = remoteApiPath(objectPath);
      const record = {
        id: localFile.id,
        type: localFile.type,
        value: localFile.value,
        path: localFile.path,
        size: localFile.size,
        contentType: localFile.contentType,
        src: remoteThumb,
        publicSrc: remoteThumb,
        thumb: remoteThumb,
      };

      try {
        await uploadRemoteStorageObject(settings, {
          objectPath,
          body: localFile.buffer,
          contentType: localFile.contentType,
        });
        await recordStorageMediaFile(activeRemoteProvider(settings), record);
      } catch (error) {
        if (!localBackupEnabled(settings)) throw error;
      }

      if (localBackupEnabled(settings)) {
        await recordLocalMediaFile({
          ...record,
          src: localThumb,
          publicSrc: localThumb.replace('/api/storage/file/', '/local-upload/'),
          thumb: localThumb,
        });
      } else {
        await deleteLocalStorageFile({ type: 'video', id: localFile.id });
      }

      return json({
        success: true,
        thumb: remoteThumb,
        thumbnailUrl: remoteThumb,
        provider: settings.activeStorage,
      });
    }

    if (!isLocalStorageActive(settings)) {
      return json({
        success: false,
        thumb: '',
        thumbnailUrl: '',
        provider: settings.activeStorage,
      });
    }

    const result = await resolveLocalStorageVideoThumb({ url, title });
    const thumb = String(result?.thumb || '').trim();
    return json({
      success: Boolean(thumb),
      thumb,
      thumbnailUrl: thumb,
      provider: String(result?.provider || 'local'),
    });
  } catch (error: any) {
    console.error('Video Thumbnail Error:', error);
    return json({ error: error.message || 'Video thumbnail failed' }, error?.status || 500);
  }
};
