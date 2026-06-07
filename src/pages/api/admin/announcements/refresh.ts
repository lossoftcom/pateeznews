import type { APIRoute } from 'astro';
import { adminError, adminJson, requireAdminRequest } from '@/lib/server/adminAuth';
import {
  getAnnouncementPayload,
  runAnnouncementsRefresh,
} from '@/lib/server/announcementsData';

export const POST: APIRoute = async ({ request }) => {
  try {
    await requireAdminRequest(request, 'settings_access');
    const totals = await runAnnouncementsRefresh({
      force: true,
      runType: 'manual',
      discoverSources: true,
    });
    const payload = await getAnnouncementPayload({ limit: 80 });
    return adminJson({ data: { totals, payload }, error: null });
  } catch (error) {
    return adminError(error);
  }
};
