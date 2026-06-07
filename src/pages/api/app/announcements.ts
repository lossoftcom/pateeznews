import type { APIRoute } from 'astro';
import { json } from '@/lib/server/appDb';
import { getAnnouncementPayload } from '@/lib/server/announcementsData';

export const GET: APIRoute = async ({ url }) => {
  const category = url.searchParams.get('category') || '';
  const district = url.searchParams.get('district') || '';
  const limit = Number(url.searchParams.get('limit') || 80);

  try {
    const payload = withAbsoluteAnnouncementMedia(
      await getAnnouncementPayload({ category, district, limit }),
      url.origin
    );
    return json(payload);
  } catch (error: any) {
    return json({
      city: 'Niğde',
      citySlug: 'nigde',
      source: 'Niğde Duyuru Ağı',
      sourceUrl: '',
      timezone: 'Europe/Istanbul',
      serviceDate: new Intl.DateTimeFormat('en-CA', {
        timeZone: 'Europe/Istanbul',
        year: 'numeric',
        month: '2-digit',
        day: '2-digit',
      }).format(new Date()),
      serviceDateLabel: new Intl.DateTimeFormat('tr-TR', {
        timeZone: 'Europe/Istanbul',
        day: 'numeric',
        month: 'long',
        year: 'numeric',
      }).format(new Date()),
      fetchedAt: new Date().toISOString(),
      updateIntervalMinutes: 30,
      districts: [
        { key: 'merkez', label: 'Merkez', count: 0 },
        { key: 'altunhisar', label: 'Altunhisar', count: 0 },
        { key: 'bor', label: 'Bor', count: 0 },
        { key: 'camardi', label: 'Çamardı', count: 0 },
        { key: 'ciftlik', label: 'Çiftlik', count: 0 },
        { key: 'ulukisla', label: 'Ulukışla', count: 0 },
      ],
      announcements: [],
      meta: {
        total: 0,
        officialCount: 0,
        powerCount: 0,
        roadCount: 0,
        activeSources: 0,
      },
      error: error?.message || 'Announcements could not be fetched',
    }, 502);
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
  const url = String(value || '').trim();
  if (!url || !url.startsWith('/')) return url;
  try {
    return new URL(url, origin).toString();
  } catch {
    return url;
  }
}
