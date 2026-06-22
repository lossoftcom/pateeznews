import type { APIRoute } from 'astro';
import { requireStorageAdminRequest } from '@/lib/server/storageAdminAuth';
import {
  getStorageType,
  normalizeStoragePath,
  relativeStorageId,
  storageObjectPath,
  type StorageType,
} from '@/lib/server/supabaseStorage';
import {
  deleteLocalMediaRecords,
  deleteStorageMediaRecords,
  getStorageSettings,
  isLocalStorageActive,
  isS3CompatibleStorageActive,
  localBackupEnabled,
} from '@/lib/server/storageSettings';
import { deleteLocalStorageFile } from '@/lib/server/localStorageProxy';
import { activeRemoteProvider, deleteRemoteStorageFile } from '@/lib/server/remoteObjectStorage';
import { dbQuery } from '@/lib/server/supabaseDb';

function json(data: unknown, status = 200) {
  return new Response(JSON.stringify(data), {
    status,
    headers: { 'Content-Type': 'application/json' },
  });
}

async function readBody(request: Request) {
  try {
    const body = await request.json();
    return body && typeof body === 'object' && !Array.isArray(body)
      ? body as Record<string, unknown>
      : {};
  } catch {
    return {};
  }
}

function mediaPaths(type: StorageType, rawId: string) {
  const objectPath = storageObjectPath(type, rawId);
  const id = relativeStorageId(type, objectPath);
  return { objectPath, id };
}

async function findMediaUsage(objectPath: string, id: string) {
  const needles = [...new Set([
    objectPath,
    id,
    `/api/storage/file/${objectPath}`,
    `/local-upload/${objectPath}`,
  ].filter(Boolean))];

  const result = await dbQuery<{ id: string; title: string | null; total_count: number | string }>(
    `SELECT id::text,
            COALESCE(title, '') AS title,
            COUNT(*) OVER() AS total_count
       FROM public.posts
      WHERE EXISTS (
        SELECT 1
          FROM unnest($1::text[]) AS needle(value)
         WHERE concat_ws(' ',
                 COALESCE(thumbnail_url, ''),
                 COALESCE(card_data::text, ''),
                 COALESCE(items::text, ''),
                 COALESCE(faq_data::text, '')
               ) ILIKE '%' || needle.value || '%'
      )
      ORDER BY updated_at DESC NULLS LAST, id DESC
      LIMIT 6`,
    [needles],
  ).catch((error) => {
    console.warn('Media usage check skipped:', error?.message || error);
    return { rows: [] as Array<{ id: string; title: string | null; total_count: number | string }> };
  });

  return {
    count: Number(result.rows[0]?.total_count || 0),
    posts: result.rows.map((row) => ({ id: row.id, title: row.title || '' })),
  };
}

async function deleteLocalCopy(type: StorageType, id: string) {
  await deleteLocalStorageFile({ type, id }).catch((error) => {
    console.warn('Local media delete skipped:', error instanceof Error ? error.message : error);
  });
  await deleteLocalMediaRecords(type, [id]);
}

export const DELETE: APIRoute = async ({ request }) => {
  try {
    const body = await readBody(request);
    const type = getStorageType(body.type);
    const rawId = normalizeStoragePath(String(body.id || ''));
    const force = body.force === true;

    if (!rawId) return json({ error: 'Media id is required' }, 400);

    await requireStorageAdminRequest(request, type);

    const { objectPath, id } = mediaPaths(type, rawId);
    if (!force) {
      const usage = await findMediaUsage(objectPath, id);
      if (usage.count > 0) {
        return json({
          error: 'MEDIA_IN_USE',
          message: 'Media is used in posts',
          usage,
        }, 409);
      }
    }

    const settings = await getStorageSettings();

    if (isS3CompatibleStorageActive(settings)) {
      const provider = activeRemoteProvider(settings);
      const deleted = await deleteRemoteStorageFile(settings, { id, type });
      const groups = deleted.deleted.length ? deleted.deleted : [{ type, ids: [id] }];

      for (const group of groups) {
        await deleteStorageMediaRecords(provider, group.type, group.ids);
      }

      if (localBackupEnabled(settings)) {
        await deleteLocalCopy(type, id);
      }

      return json({ success: true, deleted: groups });
    }

    if (!isLocalStorageActive(settings)) {
      return json({ error: `Selected storage provider is not implemented: ${settings.activeStorage}` }, 501);
    }

    await deleteLocalStorageFile({ type, id, force });
    await deleteLocalMediaRecords(type, [id]);
    return json({ success: true, deleted: [{ type, ids: [id] }] });
  } catch (error: any) {
    console.error('Storage Delete Error:', error);
    return json({ error: error?.message || 'Storage delete failed' }, error?.status || 500);
  }
};
