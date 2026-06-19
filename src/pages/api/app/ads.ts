import type { APIRoute } from 'astro';
import { getPublicAdSettings } from '@/lib/server/publicAds';
import type { PublicAdPlatform } from '@/types';

export const prerender = false;

const publicJson = (data: unknown, status = 200) => new Response(JSON.stringify(data), {
  status,
  headers: {
    'Content-Type': 'application/json; charset=utf-8',
    'Cache-Control': 'public, max-age=30, stale-while-revalidate=120',
    'CDN-Cache-Control': 'public, max-age=60, stale-while-revalidate=300',
    'Cloudflare-CDN-Cache-Control': 'public, max-age=60, stale-while-revalidate=300',
  },
});

const normalizePlatform = (value: string | null): PublicAdPlatform | undefined => {
  const platform = String(value || '').trim();
  if (platform === 'web' || platform === 'mobile') return platform;
  return undefined;
};

export const GET: APIRoute = async ({ url }) => {
  const platform = normalizePlatform(url.searchParams.get('platform'));
  const settings = await getPublicAdSettings(platform);
  return publicJson({ data: settings, error: null });
};
