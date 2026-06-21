import type { APIRoute } from 'astro';
import { adminError, adminJson, requireAdminRequest } from '@/lib/server/adminAuth';
import { listAutomaticNewsItems, runAutomaticNewsRefresh, testAutomaticNewsSources } from '@/lib/server/automaticNewsData';

export const POST: APIRoute = async ({ request, url }) => {
  try {
    await requireAdminRequest(request, 'settings_access');
    const body = await request.json().catch(() => ({}));
    const mode = String(body?.mode || '').trim();
    const totals = mode === 'test'
      ? await testAutomaticNewsSources()
      : await runAutomaticNewsRefresh({
          force: body?.force !== false,
          runType: 'manual',
          sourceId: String(body?.sourceId || '').trim() || undefined,
        });
    const payload = await listAutomaticNewsItems({
      page: 1,
      pageSize: Number(body?.pageSize || 25),
      sortKey: 'date',
      sortAscending: false,
    });
    return adminJson({
      data: {
        totals,
        items: payload.items,
        count: payload.totalCount,
        origin: url.origin,
      },
      error: null,
    });
  } catch (error) {
    return adminError(error);
  }
};
