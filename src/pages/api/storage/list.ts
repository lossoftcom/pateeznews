import type { APIRoute } from 'astro';
import { getStorageType } from '@/lib/server/supabaseStorage';
import { requireStorageAdminRequest } from '@/lib/server/storageAdminAuth';
import {
  getStorageSettings,
  isLocalStorageActive,
  isS3CompatibleStorageActive,
  localBackupEnabled,
} from '@/lib/server/storageSettings';
import { listLocalStorageFiles } from '@/lib/server/localStorageProxy';
import { listRemoteStorageFiles } from '@/lib/server/remoteObjectStorage';

export const GET: APIRoute = async ({ request }) => {
  try {
    const url = new URL(request.url);
    const type = getStorageType(url.searchParams.get('type'));
    await requireStorageAdminRequest(request, type);
    const storageSettings = await getStorageSettings();

    if (isS3CompatibleStorageActive(storageSettings)) {
      let files;
      try {
        files = await listRemoteStorageFiles(storageSettings, type);
      } catch (error) {
        const localFiles = await listLocalStorageFiles(type);
        if (!localFiles.length && !localBackupEnabled(storageSettings)) throw error;
        files = localFiles;
      }
      return new Response(JSON.stringify(files), {
        status: 200,
        headers: { 'Content-Type': 'application/json' },
      });
    }

    if (!isLocalStorageActive(storageSettings)) {
      return new Response(JSON.stringify({
        error: `Selected storage provider is not implemented: ${storageSettings.activeStorage}`,
      }), {
        status: 501,
        headers: { 'Content-Type': 'application/json' },
      });
    }

    const files = await listLocalStorageFiles(type);
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
