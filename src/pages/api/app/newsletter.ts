import type { APIRoute } from 'astro';
import { ensureAppSchema, json } from '@/lib/server/appDb';
import { dbQuery } from '@/lib/server/supabaseDb';
import { TURKEY_CITIES, normalizeTurkeyCity } from '@/lib/server/turkeyCities';

const EMAIL_RE = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;

type CloudflareRequest = Request & {
  cf?: Record<string, unknown>;
};

const stripTurkishMarks = (value: string) =>
  value
    .normalize('NFD')
    .replace(/[\u0300-\u036f]/g, '')
    .replace(/ı/g, 'i')
    .replace(/İ/g, 'I')
    .toLocaleLowerCase('tr-TR');

const normalizeDetectedCity = (value: unknown) => {
  const city = String(value || '').trim().slice(0, 120);
  if (!city) return null;

  const exactTurkeyCity = normalizeTurkeyCity(city);
  if (exactTurkeyCity) return exactTurkeyCity;

  const foldedCity = stripTurkishMarks(city);
  const canonicalTurkeyCity = TURKEY_CITIES.find(
    (candidate) => stripTurkishMarks(candidate) === foldedCity
  );
  return canonicalTurkeyCity || city;
};

const headerValue = (request: Request, name: string) =>
  request.headers.get(name)?.trim() || '';

const firstForwardedIp = (value: string) =>
  value
    .split(',')
    .map((part) => part.trim())
    .find(Boolean) || '';

const normalizeClientIp = (value: unknown) => {
  if (!value) return null;
  const raw = Array.isArray(value) ? value[0] : value;
  if (typeof raw !== 'string' && typeof raw !== 'number') return null;
  const ip = String(raw).trim().slice(0, 64);
  return ip || null;
};

const getRequestLocation = (request: Request, clientAddress?: string) => {
  const cf = (request as CloudflareRequest).cf || {};
  const city = normalizeDetectedCity(
    cf.city ||
    headerValue(request, 'cf-ipcity') ||
    cf.region ||
    headerValue(request, 'cf-region')
  );
  const ip = normalizeClientIp(
    headerValue(request, 'cf-connecting-ip') ||
    headerValue(request, 'true-client-ip') ||
    headerValue(request, 'x-real-ip') ||
    firstForwardedIp(headerValue(request, 'x-forwarded-for')) ||
    clientAddress
  );

  return { city, ip };
};

export const POST: APIRoute = async ({ request }) => {
  try {
    const body = await request.json();
    const email = String(body.email || '').trim().toLowerCase();
    const languageCode = String(body.languageCode || 'tr').trim().slice(0, 10) || 'tr';
    const source = String(body.source || 'site').trim().slice(0, 60) || 'site';
    const location = getRequestLocation(request);

    if (!EMAIL_RE.test(email)) {
      return json({ error: { message: 'Invalid email' } }, 400);
    }

    await ensureAppSchema();

    const existing = await dbQuery(
      'SELECT id FROM public.newsletter_subscribers WHERE lower(email) = lower($1) LIMIT 1',
      [email]
    );

    const result = existing.rows[0]
      ? await dbQuery(
        `UPDATE public.newsletter_subscribers
         SET status = 'active',
             language_code = $2,
             source = $3,
             ip_address = COALESCE($4::text, ip_address),
             city = COALESCE($5::text, city),
             updated_at = now()
         WHERE id = $1
         RETURNING *`,
        [existing.rows[0].id, languageCode, source, location.ip, location.city]
      )
      : await dbQuery(
        `INSERT INTO public.newsletter_subscribers (email, language_code, source, ip_address, city)
         VALUES ($1, $2, $3, $4, $5)
         RETURNING *`,
        [email, languageCode, source, location.ip, location.city]
      );

    return json({ ok: true, subscriber: result.rows[0] });
  } catch (error: any) {
    return json({ error: { message: error.message || 'Newsletter subscription failed' } }, 500);
  }
};
