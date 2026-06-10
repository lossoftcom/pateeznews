import type { APIRoute } from 'astro';
import { adminError, adminJson, requireAdminRequest } from '@/lib/server/adminAuth';
import {
  getSecuritySettings,
  publicSecuritySettings,
  saveSecuritySettings,
} from '@/lib/server/securitySettings';

function languageFromUrl(request: Request) {
  try {
    return new URL(request.url).searchParams.get('language_code') || 'tr';
  } catch {
    return 'tr';
  }
}

export const GET: APIRoute = async ({ request }) => {
  try {
    await requireAdminRequest(request, 'view_settings');
    const settings = await getSecuritySettings(languageFromUrl(request));
    return adminJson({ data: publicSecuritySettings(settings), error: null });
  } catch (error) {
    return adminError(error);
  }
};

export const POST: APIRoute = async ({ request }) => {
  try {
    await requireAdminRequest(request, 'settings_access');
    const body = await request.json().catch(() => ({}));
    const values = body?.values && typeof body.values === 'object' ? body.values : {};
    const languageCode = String(body?.language_code || body?.languageCode || 'tr');
    const settings = await saveSecuritySettings(values, languageCode);
    return adminJson({ data: publicSecuritySettings(settings), error: null });
  } catch (error) {
    return adminError(error);
  }
};
