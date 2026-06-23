import type { APIRoute } from 'astro';
import { adminError, adminJson, requireAnyAdminPermission } from '@/lib/server/adminAuth';
import { listAutomaticNewsItems, runAutomaticNewsRefresh, testAutomaticNewsSources } from '@/lib/server/automaticNewsData';

export const POST: APIRoute = async ({ request, url }) => {
  try {
    const body = await request.json().catch(() => ({}));
    const mode = String(body?.mode || '').trim();
    await requireAnyAdminPermission(
      request,
      mode === 'test'
        ? ['automatic_news_view', 'automatic_news_run', 'settings_access']
        : ['automatic_news_run', 'settings_access'],
    );
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
