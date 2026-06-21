import { TURKEY_CITIES, normalizeTurkeyCity } from './turkeyCities';

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
    (candidate) => stripTurkishMarks(candidate) === foldedCity,
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

export function getRequestLocation(request: Request, clientAddress?: string) {
  const cf = (request as CloudflareRequest).cf || {};
  const city = normalizeDetectedCity(
    cf.city ||
      headerValue(request, 'cf-ipcity') ||
      cf.region ||
      headerValue(request, 'cf-region'),
  );
  const ip = normalizeClientIp(
    headerValue(request, 'cf-connecting-ip') ||
      headerValue(request, 'true-client-ip') ||
      headerValue(request, 'x-real-ip') ||
      firstForwardedIp(headerValue(request, 'x-forwarded-for')) ||
      clientAddress,
  );

  return { city, ip };
}
