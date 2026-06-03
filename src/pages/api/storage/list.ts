import type { APIRoute } from 'astro';
import path from 'path';
import { dbQuery } from '@/lib/server/supabaseDb';
import { getStorageType, publicStorageUrl, relativeStorageId } from '@/lib/server/supabaseStorage';
import { requireStorageAdminRequest } from '@/lib/server/storageAdminAuth';
import { localUploadItemsForType } from '@/lib/server/localUploadStorage';

export const GET: APIRoute = async ({ request }) => {
  try {
    const url = new URL(request.url);
    const type = getStorageType(url.searchParams.get('type'));
    await requireStorageAdminRequest(request, type);
    const prefix = `${type}/`;

    let rows: Array<{
      name: string;
      metadata: Record<string, any> | null;
      updated_at: Date | string | null;
      created_at: Date | string | null;
    }> = [];

    try {
      const result = await dbQuery<{
        name: string;
        metadata: Record<string, any> | null;
        updated_at: Date | string | null;
        created_at: Date | string | null;
      }>(
        `SELECT name, metadata, updated_at, created_at
         FROM storage.objects
         WHERE bucket_id = 'media'
           AND name LIKE $1
         ORDER BY COALESCE(updated_at, created_at) DESC
         LIMIT 1000`,
        [`${prefix}%`]
      );
      rows = result.rows;
    } catch (error) {
      console.error('Storage remote list fallback:', error);
    }

    const objectNames = new Set(rows.map((row) => row.name));
    const remoteFiles = rows
      .filter((row) => !(type === 'video' && row.name.endsWith('_thumb.webp')))
      .map((row) => {
        const relativeId = relativeStorageId(type, row.name);
        const parsed = path.posix.parse(relativeId);
        const expectedThumbRelativeId = type === 'video'
          ? `${parsed.dir ? `${parsed.dir}/` : ''}${parsed.name}_thumb.webp`
          : relativeId;
        const thumbRelativeId = type === 'video' && !objectNames.has(`${type}/${expectedThumbRelativeId}`)
          ? relativeId
          : expectedThumbRelativeId;
        const date = new Date(row.updated_at || row.created_at || Date.now()).getTime();

        return {
          id: relativeId,
          value: parsed.base,
          size: Number(row.metadata?.size || 0),
          date: Math.floor(date / 1000),
          type,
          src: `/api/storage/file/${type}/${relativeId}`,
          thumb: `/api/storage/file/${type}/${thumbRelativeId}`,
          publicSrc: publicStorageUrl(row.name),
          path: parsed.dir,
        };
      });
    const seenIds = new Set(remoteFiles.map((file) => file.id));
    const localFiles = localUploadItemsForType(type).filter((file) => !seenIds.has(file.id));
    const files = [...remoteFiles, ...localFiles].sort((a, b) => b.date - a.date);

    return new Response(JSON.stringify(files), {
      status: 200,
      headers: { 'Content-Type': 'application/json' },
    });
  } catch (err: any) {
    console.error('Storage List Error:', err);
    return new Response(JSON.stringify({ error: err.message }), {
      status: err?.status || 500,
      headers: { 'Content-Type': 'application/json' },
    });
  }
};
