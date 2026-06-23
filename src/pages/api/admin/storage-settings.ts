import type { APIRoute } from 'astro';
import { adminError, adminJson, requireAdminRequest } from '@/lib/server/adminAuth';
import {
  getLocalMediaSummary,
  getStorageSettings,
  isS3CompatibleStorageActive,
  maskStorageSettings,
  normalizeStorageSettings,
  preserveMaskedStorageSecrets,
  saveStorageSettings,
} from '@/lib/server/storageSettings';
import { migrateLocalMediaToRemote } from '@/lib/server/storageMigration';

export const GET: APIRoute = async ({ request }) => {
  try {
    await requireAdminRequest(request, 'view_settings');
    const settings = await getStorageSettings();
    const localMedia = await getLocalMediaSummary();
    return adminJson({ data: maskStorageSettings(settings), localMedia, error: null });
  } catch (error) {
    return adminError(error);
  }
};

export const POST: APIRoute = async ({ request }) => {
  try {
    await requireAdminRequest(request, 'settings_access');
    const body = await request.json().catch(() => ({}));
    const values = body?.values && typeof body.values === 'object' ? body.values : body;
    const currentSettings = await getStorageSettings();
    const nextSettings = preserveMaskedStorageSecrets(
      normalizeStorageSettings(values),
      currentSettings,
    );
    const migration = body?.migrateLocalMedia === true && isS3CompatibleStorageActive(nextSettings)
      ? await migrateLocalMediaToRemote(nextSettings)
      : null;
    const settings = await saveStorageSettings(nextSettings);
    const localMedia = await getLocalMediaSummary();
    return adminJson({ data: maskStorageSettings(settings), localMedia, migration, error: null });
  } catch (error) {
    return adminError(error);
  }
};
