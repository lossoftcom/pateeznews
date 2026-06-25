import { isIP } from 'node:net';

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

const forwardedForIps = (value: string) =>
  value
    .split(',')
    .map((part) => part.trim())
    .filter(Boolean);

const forwardedHeaderIps = (value: string) =>
  value
    .split(',')
    .map((part) => part.match(/(?:^|;)\s*for=(?:"([^"]+)"|([^;,\s]+))/i))
    .map((match) => (match ? match[1] || match[2] || '' : ''))
    .filter(Boolean);

export const normalizeClientIp = (value: unknown) => {
  if (!value) return null;
  const raw = Array.isArray(value) ? value[0] : value;
  if (typeof raw !== 'string' && typeof raw !== 'number') return null;
  let ip = String(raw).trim().replace(/^"|"$/g, '');
  if (!ip) return null;
  if (ip.startsWith('[')) {
    const end = ip.indexOf(']');
    if (end > 0) ip = ip.slice(1, end);
  } else if (/^\d{1,3}(?:\.\d{1,3}){3}:\d+$/.test(ip)) {
    ip = ip.replace(/:\d+$/, '');
  }
  ip = ip.replace(/%.+$/, '').slice(0, 64);
  return isIP(ip) ? ip : null;
};

export function getRequestLocation(request: Request, clientAddress?: string) {
  const cf = (request as CloudflareRequest).cf || {};
  const city = normalizeDetectedCity(
    cf.city ||
      headerValue(request, 'cf-ipcity') ||
      cf.region ||
      headerValue(request, 'cf-region'),
  );
  const forwarded = headerValue(request, 'forwarded');
  const ip =
    normalizeClientIp(headerValue(request, 'cf-connecting-ip')) ||
    normalizeClientIp(headerValue(request, 'true-client-ip')) ||
    normalizeClientIp(headerValue(request, 'x-real-ip')) ||
    forwardedForIps(headerValue(request, 'x-forwarded-for')).map(normalizeClientIp).find(Boolean) ||
    forwardedHeaderIps(forwarded).map(normalizeClientIp).find(Boolean) ||
    normalizeClientIp(clientAddress);

  return { city, ip };
}
