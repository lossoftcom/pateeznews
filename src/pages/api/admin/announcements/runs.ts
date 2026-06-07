import type { APIRoute } from 'astro';
import { adminError, adminJson, requireAdminRequest } from '@/lib/server/adminAuth';
import { listAnnouncementRuns } from '@/lib/server/announcementsData';

export const GET: APIRoute = async ({ request, url }) => {
  try {
    await requireAdminRequest(request, 'view_settings');
    const limit = Number(url.searchParams.get('limit') || 30);
    const runs = await listAnnouncementRuns({ limit });
    return adminJson({ data: runs, error: null });
  } catch (error) {
    return adminError(error);
  }
};
