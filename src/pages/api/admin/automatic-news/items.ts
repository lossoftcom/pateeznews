import type { APIRoute } from 'astro';
import { adminError, adminJson, requireAdminRequest } from '@/lib/server/adminAuth';
import { deleteAutomaticNewsItems, listAutomaticNewsItems } from '@/lib/server/automaticNewsData';

export const GET: APIRoute = async ({ request, url }) => {
  try {
    await requireAdminRequest(request, 'view_settings');
    const payload = await listAutomaticNewsItems({
      search: url.searchParams.get('search') || '',
      platform: url.searchParams.get('platform') || '',
      category: url.searchParams.get('category') || '',
      status: url.searchParams.get('status') || '',
      language: url.searchParams.get('language') || '',
      page: Number(url.searchParams.get('page') || 1),
      pageSize: Number(url.searchParams.get('pageSize') || 25),
      sortKey: url.searchParams.get('sortKey') || 'date',
      sortAscending: url.searchParams.get('sortAscending') === '1',
    });
    return adminJson({ data: payload.items, count: payload.totalCount, error: null });
  } catch (error) {
    return adminError(error);
  }
};

export const POST: APIRoute = async ({ request }) => {
  try {
    await requireAdminRequest(request, 'settings_access');
    const body = await request.json().catch(() => ({}));
    const action = String(body?.action || '').trim();
    if (action !== 'delete') {
      return adminJson({ data: null, error: { message: 'Geçersiz işlem' } }, 400);
    }
    const ids = Array.isArray(body?.ids)
      ? body.ids.map((value: unknown) => String(value || '').trim()).filter(Boolean)
      : [];
    return adminJson({
      data: await deleteAutomaticNewsItems(ids),
      error: null,
    });
  } catch (error) {
    return adminError(error);
  }
};
