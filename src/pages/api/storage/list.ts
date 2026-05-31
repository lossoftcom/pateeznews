import type { APIRoute } from 'astro';
import path from 'path';
import { dbQuery } from '@/lib/server/supabaseDb';
import { getStorageType, publicStorageUrl, relativeStorageId } from '@/lib/server/supabaseStorage';
import { requireStorageAdminRequest } from '@/lib/server/storageAdminAuth';

export const GET: APIRoute = async ({ request }) => {
  try {
    const url = new URL(request.url);
    const type = getStorageType(url.searchParams.get('type'));
    await requireStorageAdminRequest(request, type);
    const prefix = `${type}/`;

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

    const files = result.rows
      .filter((row) => !(type === 'video' && row.name.endsWith('_thumb.webp')))
      .map((row) => {
        const relativeId = relativeStorageId(type, row.name);
        const parsed = path.posix.parse(relativeId);
        const thumbRelativeId = type === 'video'
          ? `${parsed.dir ? `${parsed.dir}/` : ''}${parsed.name}_thumb.webp`
          : relativeId;
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
