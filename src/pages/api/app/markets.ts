import type { APIRoute } from 'astro';
import { json } from '@/lib/server/appDb';
import { fetchMarketsPayload } from '@/lib/server/marketsData';

export const GET: APIRoute = async ({ request }) => {
  const url = new URL(request.url);
  const languageCode = url.searchParams.get('lang') || 'tr';
  const forceRefresh = url.searchParams.get('refresh') === '1';

  try {
    const payload = await fetchMarketsPayload(languageCode, forceRefresh);
    return json(payload, payload.error ? 503 : 200);
  } catch (error) {
    const message = error instanceof Error ? error.message : 'Piyasa verisi alınamadı';
    return json({ error: message, currencies: [], gold: [] }, 500);
  }
};
