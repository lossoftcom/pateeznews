import type { APIRoute } from 'astro';
import { getStorageType } from '@/lib/server/supabaseStorage';
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
