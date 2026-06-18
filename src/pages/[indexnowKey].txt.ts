import type { APIRoute } from 'astro';
import { getIndexNowKeys } from '@/lib/server/indexNow';

export const GET: APIRoute = async ({ params }) => {
  const requestedKey = String(params.indexnowKey || '').replace(/\.txt$/i, '').trim();
  const keys = await getIndexNowKeys();
  if (!requestedKey || !keys.includes(requestedKey)) {
    return new Response('Not found', {
      status: 404,
      headers: { 'Content-Type': 'text/plain; charset=utf-8' },
    });
  }

  return new Response(requestedKey, {
    headers: {
      'Content-Type': 'text/plain; charset=utf-8',
      'Cache-Control': 'no-cache, max-age=0',
    },
  });
};
