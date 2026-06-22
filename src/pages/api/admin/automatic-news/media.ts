import type { APIRoute } from 'astro';
import { adminJson, requireAdminRequest } from '@/lib/server/adminAuth';

export const GET: APIRoute = async ({ request }) => {
  await requireAdminRequest(request, 'view_settings');
  return adminJson({ data: { images: [] }, error: null });
};
