import type { APIRoute } from 'astro';
import { adminError, adminJson, requireAdminRequest } from '@/lib/server/adminAuth';
import {
  deleteAutomaticNewsSource,
  listAutomaticNewsSources,
  setAutomaticNewsSourceActive,
  syncAutomaticNewsSourcesFromUrls,
  upsertAutomaticNewsSourcesFromUrls,
} from '@/lib/server/automaticNewsData';

export const GET: APIRoute = async ({ request }) => {
  try {
    await requireAdminRequest(request, 'view_settings');
    return adminJson({
      data: await listAutomaticNewsSources({ includeInactive: true }),
      error: null,
    });
  } catch (error) {
    return adminError(error);
  }
};

export const POST: APIRoute = async ({ request }) => {
  try {
    await requireAdminRequest(request, 'settings_access');
    const body = await request.json().catch(() => ({}));
    const action = String(body?.action || 'addMany');

    if (action === 'setActive') {
      const id = String(body?.id || '').trim();
      if (!id) return adminJson({ data: null, error: { message: 'Kaynak id gerekli' } }, 400);
      return adminJson({
        data: await setAutomaticNewsSourceActive(id, body?.isActive !== false),
        error: null,
      });
    }

    if (action === 'delete') {
      const id = String(body?.id || '').trim();
      if (!id) return adminJson({ data: null, error: { message: 'Kaynak id gerekli' } }, 400);
      await deleteAutomaticNewsSource(id);
      return adminJson({ data: { id }, error: null });
    }

    const urls = Array.isArray(body?.urls)
      ? body.urls.map((value: unknown) => String(value || '').trim()).filter(Boolean)
      : String(body?.url || body?.urls || '')
          .split(/\s+/)
          .map((value) => value.trim())
          .filter(Boolean);

    if (urls.length === 0) {
      return adminJson({ data: null, error: { message: 'En az bir adres gerekli' } }, 400);
    }

    if (action === 'sync') {
      return adminJson({
        data: await syncAutomaticNewsSourcesFromUrls(urls),
        error: null,
      });
    }

    return adminJson({
      data: await upsertAutomaticNewsSourcesFromUrls(urls),
      error: null,
    });
  } catch (error) {
    return adminError(error);
  }
};
