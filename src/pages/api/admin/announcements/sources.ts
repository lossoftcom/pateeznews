import type { APIRoute } from 'astro';
import { adminError, adminJson, requireAdminRequest } from '@/lib/server/adminAuth';
import {
  deleteAnnouncementSource,
  listAnnouncementSources,
  upsertAnnouncementSource,
} from '@/lib/server/announcementsData';

export const GET: APIRoute = async ({ request }) => {
  try {
    await requireAdminRequest(request, 'view_settings');
    const sources = await listAnnouncementSources({ includeInactive: true });
    return adminJson({ data: sources, error: null });
  } catch (error) {
    return adminError(error);
  }
};

export const POST: APIRoute = async ({ request }) => {
  try {
    await requireAdminRequest(request, 'settings_access');
    const body = await request.json();
    if (body?.action === 'delete') {
      const id = String(body?.id || '').trim();
      if (!id) {
        return adminJson({ data: null, error: { message: 'Kaynak id gerekli' } }, 400);
      }
      await deleteAnnouncementSource(id);
      return adminJson({ data: { id }, error: null });
    }

    const values = body?.values && typeof body.values === 'object' ? body.values : body;
    const source = await upsertAnnouncementSource(values || {});
    return adminJson({ data: source, error: null });
  } catch (error) {
    return adminError(error);
  }
};
