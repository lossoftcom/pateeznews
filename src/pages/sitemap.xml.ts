import type { APIRoute } from 'astro';
import { supabase } from '@/lib/supabase';
import { slugify } from '@/utils/helpers';
import { dataService } from '@/services/dataService.server';
import { resolveLangCode } from '@/utils/lang';

const CACHE_TTL_MS = 1000 * 60 * 5;
const cacheByKey: Record<string, { body: string; expiry: number; contentType: string }> = {};

const escapeXml = (value: string) => value
  .replace(/&/g, '&amp;')
  .replace(/</g, '&lt;')
  .replace(/>/g, '&gt;')
  .replace(/"/g, '&quot;')
  .replace(/'/g, '&apos;');

const toIso = (value: string | null | undefined) => {
  const raw = String(value || '').trim();
  if (!raw) return undefined;
  const d = new Date(raw);
  if (Number.isNaN(d.getTime())) return undefined;
  return d.toISOString();
};

const normalizeBase = (value: string | null | undefined) => String(value || '').trim().replace(/\/$/, '');

const toBaseUrl = (value: string | null | undefined, fallbackOrigin: string) => {
  const raw = normalizeBase(value) || normalizeBase(fallbackOrigin);
  try {
    const url = new URL(raw);
    if (!url.pathname.endsWith('/')) url.pathname = `${url.pathname.replace(/\/?$/, '')}/`;
    return url;
  } catch {
    const url = new URL(fallbackOrigin);
    if (!url.pathname.endsWith('/')) url.pathname = `${url.pathname.replace(/\/?$/, '')}/`;
    return url;
  }
};

const applyLangParam = (url: URL, lang: string, shouldUseLangParam: boolean, defaultLangCode: string) => {
  if (shouldUseLangParam && lang && lang !== defaultLangCode) {
    url.searchParams.set('lang', lang);
  } else {
    url.searchParams.delete('lang');
  }
  return url;
};

export const GET: APIRoute = async ({ request }) => {
  const now = Date.now();
  const requestUrl = new URL(request.url);

  const seoAlternates = await dataService.getSeoAlternates();
  const defaultLangCode = seoAlternates.find((entry) => entry.isDefault)?.code || 'tr';
  const supported = seoAlternates.map((entry) => ({ code: entry.code, isDefault: entry.isDefault }));

  const alternateBases = seoAlternates.map((entry) => normalizeBase(entry.canonicalUrl) || normalizeBase(requestUrl.origin));
  const shouldUseLangParam = new Set(alternateBases).size <= 1;

  const urlLang = requestUrl.searchParams.get('lang');

  const cacheKeyBase = `${requestUrl.origin}|${shouldUseLangParam ? 'param' : 'domain'}`;

  // If no lang parameter, serve a deterministic sitemap index.
  if (!urlLang) {
    const indexKey = `${cacheKeyBase}|index`;
    const cachedIndex = cacheByKey[indexKey];
    if (cachedIndex && cachedIndex.expiry > now) {
      return new Response(cachedIndex.body, {
        headers: {
          'Content-Type': cachedIndex.contentType,
          'Cache-Control': 'public, max-age=300',
        },
      });
    }

    const requestOrigin = requestUrl.origin;

    const entriesForHost = (() => {
      if (shouldUseLangParam) return seoAlternates;

      const matches = seoAlternates.filter((entry) => {
        const base = toBaseUrl(entry.canonicalUrl || requestOrigin, requestOrigin);
        return base.origin === requestOrigin;
      });

      return matches.length > 0 ? matches : seoAlternates;
    })();

    const indexBaseUrl = toBaseUrl(requestOrigin, requestOrigin);
    const sitemapLocs = entriesForHost
      .filter((entry) => !!entry.code)
      .map((entry) => {
        const loc = new URL('sitemap.xml', indexBaseUrl);
        loc.searchParams.set('lang', entry.code);
        return loc.toString();
      });

    const body = [
      '<?xml version="1.0" encoding="UTF-8"?>',
      '<sitemapindex xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">',
      ...sitemapLocs.map((loc) => `<sitemap><loc>${escapeXml(loc)}</loc></sitemap>`),
      '</sitemapindex>',
      '',
    ].join('\n');

    cacheByKey[indexKey] = { body, expiry: now + CACHE_TTL_MS, contentType: 'application/xml; charset=utf-8' };

    return new Response(body, {
      headers: {
        'Content-Type': 'application/xml; charset=utf-8',
        'Cache-Control': 'public, max-age=300',
      },
    });
  }

  const cookies = request.headers.get('cookie') || '';
  const cookieLang = cookies.match(/pateez_lang=([^;]+)/)?.[1];
  const lang = resolveLangCode({
    urlLang,
    cookieLang,
    acceptLanguageHeader: request.headers.get('accept-language'),
    supported,
    fallback: defaultLangCode,
  });

  const cacheKey = `${cacheKeyBase}|lang:${lang}`;
  const cached = cacheByKey[cacheKey];
  if (cached && cached.expiry > now) {
    return new Response(cached.body, {
      headers: {
        'Content-Type': cached.contentType,
        'Cache-Control': 'public, max-age=300',
      },
    });
  }

  const langMeta = seoAlternates.find((entry) => entry.code === lang);
  const baseUrl = toBaseUrl(langMeta?.canonicalUrl || requestUrl.origin, requestUrl.origin);
  const safeBaseUrl = (!shouldUseLangParam && baseUrl.origin !== requestUrl.origin)
    ? toBaseUrl(requestUrl.origin, requestUrl.origin)
    : baseUrl;

  const [postsRes, navRes, profilesRes] = await Promise.all([
    supabase
      .from('posts')
      .select('slug, updated_at, published_at')
      .eq('status', 'published')
      .eq('language_code', lang)
      .not('slug', 'is', null),
    supabase
      .from('navigation_items')
      .select('label, value, is_active, created_at')
      .eq('language_code', lang)
      .eq('is_active', true),
    supabase
      .from('profiles')
      .select('username, created_at, updated_at, role')
      .eq('role', 'publisher')
      .not('username', 'is', null),
  ]);

  const urls: { loc: string; lastmod?: string }[] = [];
  const toLoc = (path: string) => {
    const url = new URL(path.replace(/^\//, ''), safeBaseUrl);
    return applyLangParam(url, lang, shouldUseLangParam, defaultLangCode).toString();
  };

  urls.push({ loc: toLoc('/') });

  const categorySlugs = new Set<string>();
  for (const item of (navRes.data || [])) {
    const raw = String(item.value || item.label || '').trim();
    if (!raw) continue;
    if (raw.startsWith('http://') || raw.startsWith('https://')) continue;
    if (raw.startsWith('/')) continue;

    const s = slugify(raw);
    if (!s || s === 'home') continue;
    if (categorySlugs.has(s)) continue;
    categorySlugs.add(s);

    urls.push({
      loc: toLoc(`/kategori/${encodeURIComponent(s)}`),
      lastmod: toIso(item.created_at) || undefined,
    });
  }

  for (const post of (postsRes.data || [])) {
    const slug = String((post as any).slug || '').trim();
    if (!slug) continue;
    const lastmod = toIso((post as any).updated_at) || toIso((post as any).published_at);
    urls.push({
      loc: toLoc(`/haber/${encodeURIComponent(slug)}`),
      ...(lastmod ? { lastmod } : {}),
    });
  }

  const publisherUsernames = new Set<string>();
  for (const profile of (profilesRes.data || [])) {
    const username = String((profile as any)?.username || '').trim();
    if (!username) continue;
    if (publisherUsernames.has(username)) continue;
    publisherUsernames.add(username);

    const lastmod = toIso((profile as any)?.updated_at) || toIso((profile as any)?.created_at);
    urls.push({
      loc: toLoc(`/profil/${encodeURIComponent(username)}`),
      ...(lastmod ? { lastmod } : {}),
    });
  }

  const body = [
    '<?xml version="1.0" encoding="UTF-8"?>',
    '<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">',
    ...urls.map((u) => [
      '<url>',
      `<loc>${escapeXml(u.loc)}</loc>`,
      ...(u.lastmod ? [`<lastmod>${escapeXml(u.lastmod)}</lastmod>`] : []),
      '</url>',
    ].join('')),
    '</urlset>',
    '',
  ].join('\n');

  cacheByKey[cacheKey] = { body, expiry: now + CACHE_TTL_MS, contentType: 'application/xml; charset=utf-8' };

  return new Response(body, {
    headers: {
      'Content-Type': 'application/xml; charset=utf-8',
      'Cache-Control': 'public, max-age=300',
    },
  });
};
