import type { APIRoute } from 'astro';
import { adminError, adminJson, requireAdminRequest } from '@/lib/server/adminAuth';
import {
  getStorageSettings,
  saveStorageSettings,
} from '@/lib/server/storageSettings';

export const GET: APIRoute = async ({ request }) => {
  try {
    await requireAdminRequest(request, 'view_settings');
    const settings = await getStorageSettings();
    return adminJson({ data: settings, error: null });
  } catch (error) {
    return adminError(error);
  }
};

export const POST: APIRoute = async ({ request }) => {
  try {
    await requireAdminRequest(request, 'settings_access');
    const body = await request.json().catch(() => ({}));
    const values = body?.values && typeof body.values === 'object' ? body.values : body;
    const settings = await saveStorageSettings(values);
    return adminJson({ data: settings, error: null });
  } catch (error) {
    return adminError(error);
  }
};
