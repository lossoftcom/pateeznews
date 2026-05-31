import type { APIRoute } from 'astro';
import path from 'path';
import {
  getStorageType,
  adminStorageClient,
  storageObjectPath,
  STORAGE_TYPES,
  type StorageType,
} from '@/lib/server/supabaseStorage';
import { requireStorageAdminRequest } from '@/lib/server/storageAdminAuth';

const jsonHeaders = { 'Content-Type': 'application/json' };

function videoThumbObjectPath(objectPath: string) {
  const parsed = path.posix.parse(objectPath);
  return `${parsed.dir ? `${parsed.dir}/` : ''}${parsed.name}_thumb.webp`;
}

function objectCandidates(rawId: string, typeHint?: StorageType | null) {
  const types = typeHint ? [typeHint, ...STORAGE_TYPES.filter((type) => type !== typeHint)] : [...STORAGE_TYPES];
  const candidates = new Set<string>();
  for (const type of types) {
    try {
      const objectPath = storageObjectPath(type, rawId);
      candidates.add(objectPath);
      if (type === 'video') candidates.add(videoThumbObjectPath(objectPath));
    } catch {
      // Ignore invalid path candidates and let the final remove call decide.
    }
  }
  return Array.from(candidates);
}

export const DELETE: APIRoute = async ({ params, request }) => {
  try {
    const url = new URL(request.url);
    let body: { id?: unknown; type?: unknown } = {};

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
    const client = adminStorageClient();
    const paths = objectCandidates(rawId, typeHint);
    if (!paths.length) {
      return new Response(JSON.stringify({ error: 'Invalid file ID' }), {
        status: 400,
        headers: jsonHeaders,
      });
    }

    const { data, error } = await client.storage.from('media').remove(paths);
    if (error) throw error;

    return new Response(JSON.stringify({ success: true, deleted: data || [], paths }), {
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
