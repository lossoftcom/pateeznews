import type { APIRoute } from 'astro';
import { requireStorageAdminRequest } from '@/lib/server/storageAdminAuth';
import { getStorageSettings, isLocalStorageActive } from '@/lib/server/storageSettings';
import { resolveLocalStorageVideoThumb } from '@/lib/server/localStorageProxy';

const JSON_HEADERS = { 'Content-Type': 'application/json' };

const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), { status, headers: JSON_HEADERS });

const cleanYoutubeId = (value: string) => {
  const match = String(value || '').match(/[_\-a-zA-Z0-9]{11}/);
  return match?.[0] || '';
};

const youtubeIdFrom = (value: string) => {
  try {
    const parsed = new URL(value, 'https://example.invalid');
    const host = parsed.hostname.toLowerCase();
    if (
      !host.includes('youtube.com') &&
      !host.includes('youtu.be') &&
      !host.includes('youtube-nocookie.com')
    ) {
      return '';
    }
    if (host.includes('youtu.be')) {
      return cleanYoutubeId(parsed.pathname.split('/').filter(Boolean)[0] || '');
    }
    const queryId = cleanYoutubeId(parsed.searchParams.get('v') || '');
    if (queryId) return queryId;
    const segments = parsed.pathname.split('/').filter(Boolean);
    for (let index = 0; index < segments.length - 1; index += 1) {
      const segment = segments[index].toLowerCase();
      if (segment === 'shorts' || segment === 'embed' || segment === 'live') {
        return cleanYoutubeId(segments[index + 1]);
      }
    }
  } catch {
    return '';
  }
  return '';
};

const youtubeThumbUrl = (url: string) => {
  const id = youtubeIdFrom(url);
  return id ? `https://img.youtube.com/vi/${id}/hqdefault.jpg` : '';
};

export const POST: APIRoute = async ({ request }) => {
  try {
    await requireStorageAdminRequest(request, 'video');
    const body = await request.json().catch(() => ({}));
    const url = String(body?.url || body?.videoUrl || '').trim();
    const title = String(body?.title || body?.context || '').trim();
    if (!url) return json({ error: 'Video URL required' }, 400);

    const youtubeThumb = youtubeThumbUrl(url);
    if (youtubeThumb) {
      return json({
        success: true,
        thumb: youtubeThumb,
        thumbnailUrl: youtubeThumb,
        provider: 'youtube',
      });
    }

    const settings = await getStorageSettings();
    if (!isLocalStorageActive(settings)) {
      return json({
        success: false,
        thumb: '',
        thumbnailUrl: '',
        provider: settings.activeStorage,
      });
    }

    const result = await resolveLocalStorageVideoThumb({ url, title });
    const thumb = String(result?.thumb || '').trim();
    return json({
      success: Boolean(thumb),
      thumb,
      thumbnailUrl: thumb,
      provider: String(result?.provider || 'local'),
    });
  } catch (error: any) {
    console.error('Video Thumbnail Error:', error);
    return json({ error: error.message || 'Video thumbnail failed' }, error?.status || 500);
  }
};
