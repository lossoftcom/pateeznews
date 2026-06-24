import type { APIRoute } from 'astro';
import { requireAdminRequest } from '@/lib/server/adminAuth';
import { adminSecurityHeaders } from '@/lib/server/securityHeaders';
import { fetchRemoteHeadlineSourceImage } from '@/lib/server/headlineImage';

export const GET: APIRoute = async ({ request }) => {
  try {
    await requireAdminRequest(request, 'manage_content');
    const requestUrl = new URL(request.url);
    const sourceUrl = requestUrl.searchParams.get('url') || '';
    const image = await fetchRemoteHeadlineSourceImage(sourceUrl);
    return new Response(image.bytes, {
      status: 200,
      headers: {
        'Content-Type': image.contentType,
        'Cache-Control': 'private, max-age=300',
        Vary: 'Authorization',
        ...adminSecurityHeaders(),
      },
    });
  } catch (error) {
    const anyError = error as { message?: string; status?: number };
    return new Response(anyError?.message || 'Source image failed', {
      status: anyError?.status || 500,
      headers: {
        'Content-Type': 'text/plain; charset=utf-8',
        'Cache-Control': 'no-store',
        Vary: 'Authorization',
        ...adminSecurityHeaders(),
      },
    });
  }
};
