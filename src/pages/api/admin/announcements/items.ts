import type { APIRoute } from 'astro';
import { adminError, adminJson, requireAdminRequest } from '@/lib/server/adminAuth';
import {
  deleteAnnouncement,
  listAdminAnnouncements,
  setAnnouncementActive,
  updateAnnouncement,
} from '@/lib/server/announcementsData';

export const GET: APIRoute = async ({ request, url }) => {
  try {
    await requireAdminRequest(request, 'view_settings');
    const payload = await listAdminAnnouncements({
      includeInactive: url.searchParams.get('includeInactive') !== '0',
      search: url.searchParams.get('search') || '',
      dateFrom: url.searchParams.get('dateFrom') || '',
      dateTo: url.searchParams.get('dateTo') || '',
      limit: Number(url.searchParams.get('limit') || 200),
    });
    return adminJson({ data: withAbsoluteAnnouncementMedia(payload, url.origin), error: null });
  } catch (error) {
    return adminError(error);
  }
};

export const POST: APIRoute = async ({ request, url }) => {
  try {
    await requireAdminRequest(request, 'settings_access');
    const body = await request.json();
    const action = String(body?.action || 'save');
    if (action === 'delete') {
      const id = String(body?.id || '').trim();
      if (!id) return adminJson({ data: null, error: { message: 'Duyuru id gerekli' } }, 400);
      return adminJson({ data: await deleteAnnouncement(id), error: null });
    }
    if (action === 'setActive') {
      const id = String(body?.id || '').trim();
      if (!id) return adminJson({ data: null, error: { message: 'Duyuru id gerekli' } }, 400);
      return adminJson({
        data: withAbsoluteAnnouncementItem(await setAnnouncementActive(id, body?.isActive !== false), url.origin),
        error: null,
      });
    }
    const values = body?.values && typeof body.values === 'object' ? body.values : body;
    return adminJson({
      data: withAbsoluteAnnouncementItem(await updateAnnouncement(values || {}), url.origin),
      error: null,
    });
  } catch (error) {
    return adminError(error);
  }
};

function withAbsoluteAnnouncementMedia(payload: any, origin: string) {
  const announcements = Array.isArray(payload?.announcements) ? payload.announcements : [];
  return {
    ...payload,
    announcements: announcements.map((item: any) => withAbsoluteAnnouncementItem(item, origin)),
  };
}

function withAbsoluteAnnouncementItem(item: any, origin: string) {
  const linkedPost = item?.linkedPost && typeof item.linkedPost === 'object'
    ? {
        ...item.linkedPost,
        imageUrl: absoluteMediaUrl(item.linkedPost.imageUrl, origin),
      }
    : item?.linkedPost;
  return {
    ...item,
    imageUrl: absoluteMediaUrl(item?.imageUrl, origin),
    linkedPostThumbnailUrl: absoluteMediaUrl(item?.linkedPostThumbnailUrl, origin),
    linkedPost,
  };
}

function absoluteMediaUrl(value: unknown, origin: string) {
  const clean = String(value || '').trim();
  if (!clean || !clean.startsWith('/')) return clean;
  try {
    return new URL(clean, origin).toString();
  } catch {
    return clean;
  }
}
