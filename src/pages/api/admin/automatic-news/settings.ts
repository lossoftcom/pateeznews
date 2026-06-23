import type { APIRoute } from 'astro';
import { adminError, adminJson, requireAnyAdminPermission } from '@/lib/server/adminAuth';
import {
  getAutomaticNewsAutomationSettings,
  setAutomaticNewsAutomationEnabled,
} from '@/lib/server/automaticNewsData';

export const GET: APIRoute = async ({ request }) => {
  try {
    await requireAnyAdminPermission(request, ['automatic_news_view', 'view_settings', 'settings_access']);
    return adminJson({
      data: await getAutomaticNewsAutomationSettings(),
      error: null,
    });
  } catch (error) {
    return adminError(error);
  }
};

export const POST: APIRoute = async ({ request }) => {
  try {
    await requireAnyAdminPermission(request, ['automatic_news_run', 'settings_access']);
    const body = await request.json().catch(() => ({}));
    return adminJson({
      data: await setAutomaticNewsAutomationEnabled(body?.enabled === true),
      error: null,
    });
  } catch (error) {
    return adminError(error);
  }
};
