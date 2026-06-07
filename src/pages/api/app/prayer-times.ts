import type { APIRoute } from 'astro';
import { json } from '@/lib/server/appDb';
import { fetchPrayerPayload } from '@/lib/server/prayerData';

export const GET: APIRoute = async ({ url }) => {
  const languageCode = String(url.searchParams.get('lang') || 'tr').trim() || 'tr';
  const forceRefresh = url.searchParams.get('refresh') === '1';
  const payload = await fetchPrayerPayload(languageCode, forceRefresh);
  return json(payload, payload.error && !payload.today ? 502 : 200);
};
