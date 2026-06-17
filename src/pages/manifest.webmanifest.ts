import type { APIRoute } from 'astro';
import { supabase } from '@/lib/supabase';
import { dataService } from '@/services/dataService.server';
import { resolveLangCode } from '@/utils/lang';

const CACHE_TTL_MS = 0;
const cacheByKey: Record<string, { body: string; expiry: number }> = {};

const normalizeBase = (value: string | null | undefined) => String(value || '').trim().replace(/\/$/, '');

const toAbsoluteUrl = (value: string | null | undefined, origin: string) => {
  const raw = String(value || '').trim();
  if (!raw) return '';
  if (raw.startsWith('http://') || raw.startsWith('https://') || raw.startsWith('data:')) return raw;
  try {
    return new URL(raw, origin).toString();
  } catch {
    return raw;
  }
};

const buildStartUrl = (origin: string, lang: string, shouldUseLangParam: boolean, defaultLangCode: string) => {
  const url = new URL('/', origin);
  if (shouldUseLangParam && lang && lang !== defaultLangCode) {
    url.searchParams.set('lang', lang);
  }
  return `${url.pathname}${url.search}`;
};

export const GET: APIRoute = async ({ request }) => {
  const now = Date.now();
  const requestUrl = new URL(request.url);

  const seoAlternates = await dataService.getSeoAlternates();
  const defaultLangCode = seoAlternates.find((entry) => entry.isDefault)?.code || 'tr';
  const supported = seoAlternates.map((entry) => ({ code: entry.code, isDefault: entry.isDefault }));

  const alternateBases = seoAlternates.map((entry) => normalizeBase(entry.canonicalUrl) || normalizeBase(requestUrl.origin));
  const shouldUseLangParam = new Set(alternateBases).size <= 1;

  const cookies = request.headers.get('cookie') || '';
  const cookieLang = cookies.match(/pateez_lang=([^;]+)/)?.[1];
  const urlLang = requestUrl.searchParams.get('lang');
  const lang = resolveLangCode({
    urlLang,
    cookieLang,
    acceptLanguageHeader: request.headers.get('accept-language'),
    supported,
    fallback: defaultLangCode,
  });

  const cacheKey = `${requestUrl.origin}|lang:${lang}|param:${shouldUseLangParam ? '1' : '0'}`;
  const cached = cacheByKey[cacheKey];
  if (cached && cached.expiry > now) {
    return new Response(cached.body, {
      headers: {
        'Content-Type': 'application/manifest+json; charset=utf-8',
        'Cache-Control': 'no-cache, max-age=0',
      },
    });
  }

  const fetchSettings = async (languageCode: string) => {
    const { data } = await supabase
      .from('site_settings')
      .select('site_name, meta_description, canonical_url, favicon_url, logo_url, og_image_url')
      .eq('language_code', languageCode)
      .maybeSingle();
    return data || null;
  };

  let settings = await fetchSettings(lang);
  if (!settings && lang !== defaultLangCode) settings = await fetchSettings(defaultLangCode);

  const origin = requestUrl.origin;
  const siteName = String(settings?.site_name || 'Pateez').trim() || 'Pateez';
  const description = String(settings?.meta_description || '').trim();

  const iconUrlRaw = settings?.favicon_url || settings?.logo_url || settings?.og_image_url || '';
  const iconUrl = toAbsoluteUrl(iconUrlRaw, origin);

  const manifest = {
    id: buildStartUrl(origin, lang, shouldUseLangParam, defaultLangCode),
    name: siteName,
    short_name: siteName.length > 24 ? `${siteName.slice(0, 24).trim()}…` : siteName,
    description,
    start_url: buildStartUrl(origin, lang, shouldUseLangParam, defaultLangCode),
    scope: '/',
    display: 'standalone',
    background_color: '#fcfcfb',
    theme_color: '#fcfcfb',
    lang,
    ...(iconUrl ? {
      icons: [
        { src: iconUrl, sizes: '128x128', purpose: 'any maskable' },
      ],
    } : {}),
  };

  const body = `${JSON.stringify(manifest, null, 2)}\n`;
  cacheByKey[cacheKey] = { body, expiry: now + CACHE_TTL_MS };

  return new Response(body, {
    headers: {
      'Content-Type': 'application/manifest+json; charset=utf-8',
      'Cache-Control': 'no-cache, max-age=0',
    },
  });
};
