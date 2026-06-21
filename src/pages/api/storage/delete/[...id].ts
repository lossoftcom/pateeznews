import type { APIRoute } from 'astro';
import { getStorageType, normalizeStoragePath, type StorageType } from '@/lib/server/supabaseStorage';
import { dbQuery } from '@/lib/server/supabaseDb';
import { requireStorageAdminRequest } from '@/lib/server/storageAdminAuth';
import {
  deleteLocalMediaRecords,
  deleteStorageMediaRecords,
  getStorageSettings,
  isLocalStorageActive,
  isS3CompatibleStorageActive,
} from '@/lib/server/storageSettings';
import { deleteLocalStorageFile } from '@/lib/server/localStorageProxy';
import { activeRemoteProvider, deleteRemoteStorageFile } from '@/lib/server/remoteObjectStorage';

const jsonHeaders = { 'Content-Type': 'application/json' };
const NEWS_MEDIA_TYPES = new Set<StorageType>(['image', 'video', 'audio', 'file']);
const VIDEO_THUMB_EXTENSIONS = ['.webp', '.jpg', '.jpeg', '.png'];

type MediaUsagePost = {
  id: string | number;
  title: string | null;
  slug: string | null;
  language_code: string | null;
  status: string | null;
  total_count: string | number;
};

function relativeIdForType(type: StorageType, rawId: string) {
  const normalized = normalizeStoragePath(rawId);
  const prefix = `${type}/`;
  return normalized.startsWith(prefix) ? normalized.slice(prefix.length) : normalized;
}

function deleteUsageCandidates(rawId: string, typeHint: StorageType | null) {
  if (typeHint) {
    return NEWS_MEDIA_TYPES.has(typeHint)
      ? [{ type: typeHint, id: relativeIdForType(typeHint, rawId) }]
      : [];
  }

  const normalized = normalizeStoragePath(rawId);
  const [first, ...rest] = normalized.split('/').filter(Boolean);
  if (NEWS_MEDIA_TYPES.has(first as StorageType) && rest.length) {
    return [{ type: first as StorageType, id: rest.join('/') }];
  }
  return Array.from(NEWS_MEDIA_TYPES, (type) => ({ type, id: normalized }));
}

function videoThumbIds(id: string) {
  const dotIndex = id.lastIndexOf('.');
  const root = dotIndex > -1 ? id.slice(0, dotIndex) : id;
  return VIDEO_THUMB_EXTENSIONS.map((extension) => `${root}_thumb${extension}`);
}

function mediaReferenceNeedles(rawId: string, typeHint: StorageType | null) {
  const objectPaths = new Set<string>();
  for (const candidate of deleteUsageCandidates(rawId, typeHint)) {
    if (!candidate.id || candidate.id === '.' || candidate.id.startsWith('../')) continue;
    objectPaths.add(`${candidate.type}/${candidate.id}`);
    if (candidate.type === 'video') {
      for (const thumbId of videoThumbIds(candidate.id)) objectPaths.add(`video/${thumbId}`);
    }
  }

  const needles = new Set<string>();
  for (const objectPath of objectPaths) {
    needles.add(objectPath);
    needles.add(`/api/storage/file/${objectPath}`);
    needles.add(`api/storage/file/${objectPath}`);
    needles.add(`/local-upload/${objectPath}`);
    needles.add(`local-upload/${objectPath}`);
  }
  return Array.from(needles).filter(Boolean);
}

async function findPostMediaUsage(rawId: string, typeHint: StorageType | null) {
  const needles = mediaReferenceNeedles(rawId, typeHint);
  if (!needles.length) return { count: 0, posts: [] as Array<Record<string, string>> };

  const needleChecks = needles
    .map((_, index) => `POSITION($${index + 1} IN {column}) > 0`)
    .join(' OR ');
  const columns = [
    "COALESCE(p.thumbnail_url, '')",
    "COALESCE(p.media_url, '')",
    "COALESCE(p.content, '')",
    "COALESCE(p.card_data::text, '')",
    "COALESCE(p.items::text, '')",
    "COALESCE(p.faq_data::text, '')",
  ];
  const whereSql = columns
    .map((column) => `(${needleChecks.replaceAll('{column}', column)})`)
    .join(' OR ');
  const limitParam = needles.length + 1;

  const result = await dbQuery<MediaUsagePost>(
    `SELECT p.id, p.title, p.slug, p.language_code, p.status,
            COUNT(*) OVER() AS total_count
     FROM public.posts p
     WHERE ${whereSql}
     ORDER BY p.created_at DESC NULLS LAST, p.id DESC
     LIMIT $${limitParam}`,
    [...needles, 5]
  );

  const posts = (result.rows || []).map((row) => ({
    id: String(row.id ?? ''),
    title: String(row.title || '').trim(),
    slug: String(row.slug || '').trim(),
    languageCode: String(row.language_code || '').trim(),
    status: String(row.status || '').trim(),
  }));
  const count = Number(result.rows?.[0]?.total_count || posts.length || 0);
  return { count, posts };
}

export const DELETE: APIRoute = async ({ params, request }) => {
  try {
    const url = new URL(request.url);
    let body: { id?: unknown; type?: unknown; force?: unknown } = {};

    if ((request.headers.get('content-type') || '').includes('application/json')) {
      try {
        body = await request.json();
      } catch {
        body = {};
      }
    }

    const rawId = typeof body.id === 'string'
      ? body.id
      : url.searchParams.get('id') || params.id;

    if (!rawId) {
      return new Response(JSON.stringify({ error: 'File ID required' }), {
        status: 400,
        headers: jsonHeaders,
      });
    }

    const typeHint = typeof body.type === 'string' || url.searchParams.get('type')
      ? getStorageType(String(body.type || url.searchParams.get('type')))
      : null;

    await requireStorageAdminRequest(request, typeHint);
    const forceDelete = body.force === true || url.searchParams.get('force') === 'true';
    if (!forceDelete) {
      const usage = await findPostMediaUsage(rawId, typeHint);
      if (usage.count > 0) {
        return new Response(JSON.stringify({
          error: 'MEDIA_IN_USE',
          message: `This media is used in ${usage.count} post(s).`,
          usage,
        }), {
          status: 409,
          headers: jsonHeaders,
        });
      }
    }

    const storageSettings = await getStorageSettings();

    if (isS3CompatibleStorageActive(storageSettings)) {
      const provider = activeRemoteProvider(storageSettings);
      const result = await deleteRemoteStorageFile(storageSettings, {
        id: rawId,
        type: typeHint,
      });
      for (const item of result.deleted || []) {
        await deleteStorageMediaRecords(provider, item.type, item.ids || []);
      }
      const localResult = await deleteLocalStorageFile({ id: rawId, type: typeHint });
      for (const item of localResult.deleted || []) {
        await deleteLocalMediaRecords(item.type, item.ids || []);
      }
      return new Response(JSON.stringify(result), {
        status: 200,
        headers: jsonHeaders,
      });
    }

    if (!isLocalStorageActive(storageSettings)) {
      return new Response(JSON.stringify({
        error: `Selected storage provider is not implemented: ${storageSettings.activeStorage}`,
      }), {
        status: 501,
        headers: jsonHeaders,
      });
    }

    const result = await deleteLocalStorageFile({ id: rawId, type: typeHint });
    for (const item of result.deleted || []) {
      await deleteLocalMediaRecords(item.type, item.ids || []);
    }

    return new Response(JSON.stringify(result), {
      status: 200,
      headers: jsonHeaders,
    });
  } catch (err: any) {
    console.error('Delete Error:', err);
    return new Response(JSON.stringify({ error: err.message }), {
      status: err?.status || 500,
      headers: jsonHeaders,
    });
  }
};
