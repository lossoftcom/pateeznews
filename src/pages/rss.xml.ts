import type { APIRoute } from 'astro';
import { supabase } from '@/lib/supabase';
import { dataService } from '@/services/dataService.server';
import { resolveLangCode } from '@/utils/lang';

const CACHE_TTL_MS = 0;
const cacheByKey: Record<string, { body: string; expiry: number; contentType: string }> = {};

const escapeXml = (value: string) => value
  .replace(/&/g, '&amp;')
  .replace(/</g, '&lt;')
  .replace(/>/g, '&gt;')
  .replace(/"/g, '&quot;')
  .replace(/'/g, '&apos;');

const TEXT_ENTITY_MAP: Record<string, string> = {
  amp: '&',
  apos: "'",
  Ccedil: 'Ç',
  ccedil: 'ç',
  Gbreve: 'Ğ',
  gbreve: 'ğ',
  hellip: '...',
  Idot: 'İ',
  imath: 'ı',
  laquo: '"',
  ldquo: '"',
  lsquo: "'",
  nbsp: ' ',
  Ouml: 'Ö',
  ouml: 'ö',
  quot: '"',
  raquo: '"',
  rdquo: '"',
  rsquo: "'",
  Scedil: 'Ş',
  scedil: 'ş',
  Uuml: 'Ü',
  uuml: 'ü',
};

const decodeTextCodePoint = (value: string, radix: number, fallback: string) => {
  const codePoint = Number.parseInt(value, radix);
  if (!Number.isFinite(codePoint) || codePoint <= 0) return fallback;
  try {
    return String.fromCodePoint(codePoint);
  } catch {
    return fallback;
  }
};

const decodeTextEntities = (value: string) => {
  const decodeOnce = (input: string) => input
    .replace(/&([a-zA-Z][a-zA-Z0-9]+);/g, (match, entity: string) => TEXT_ENTITY_MAP[entity] ?? match)
    .replace(/&#x([0-9a-fA-F]+);/g, (match, hex: string) => decodeTextCodePoint(hex, 16, match))
    .replace(/&#(\d+);/g, (match, decimal: string) => decodeTextCodePoint(decimal, 10, match));

  return decodeOnce(decodeOnce(value));
};

const stripHtml = (html: string) => decodeTextEntities((html || '').replace(/<[^>]*>?/gm, ' ').replace(/&nbsp;/g, ' '))
  .replace(/\s+/g, ' ')
  .trim();

const toRfc822 = (value: string | null | undefined) => {
  const raw = String(value || '').trim();
  if (!raw) return undefined;
  const d = new Date(raw);
  if (Number.isNaN(d.getTime())) return undefined;
  return d.toUTCString();
};

const normalizeBase = (value: string | null | undefined) => String(value || '').trim().replace(/\/$/, '');

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
        'Content-Type': cached.contentType,
        'Cache-Control': 'no-cache, max-age=0',
      },
    });
  }

  const fetchSettings = async (languageCode: string) => {
    const { data } = await supabase
      .from('site_settings')
      .select('site_name, meta_description, canonical_url')
      .eq('language_code', languageCode)
      .maybeSingle();
    return data || null;
  };

  let settings = await fetchSettings(lang);
  if (!settings && lang !== defaultLangCode) settings = await fetchSettings(defaultLangCode);

  const base = normalizeBase(settings?.canonical_url || requestUrl.origin) || requestUrl.origin;
  const siteName = String(settings?.site_name || 'Pateez').trim() || 'Pateez';
  const channelDescription = String(settings?.meta_description || '').trim();

  const selfUrl = applyLangParam(new URL('/rss.xml', requestUrl.origin), lang, shouldUseLangParam, defaultLangCode).toString();

  const { data: posts } = await supabase
    .from('posts')
    .select('id, slug, title, summary, seo_description, published_at, updated_at')
    .eq('status', 'published')
    .eq('language_code', lang)
    .not('slug', 'is', null)
    .order('published_at', { ascending: false })
    .limit(50);

  const buildItemLink = (slug: string) => {
    const url = new URL(`/haber/${encodeURIComponent(slug)}`, base);
    return applyLangParam(url, lang, shouldUseLangParam, defaultLangCode).toString();
  };

  const itemsXml = (posts || []).map((post: any) => {
    const slug = String(post?.slug || '').trim();
    if (!slug) return '';

    const link = buildItemLink(slug);
    const title = stripHtml(String(post?.title || ''));
    const descriptionSource = String(post?.seo_description || post?.summary || '').trim();
    const description = stripHtml(descriptionSource);
    const pubDate = toRfc822(post?.published_at || post?.updated_at);
    const guid = link;

    return [
      '<item>',
      `<title>${escapeXml(title)}</title>`,
      `<link>${escapeXml(link)}</link>`,
      `<guid isPermaLink="true">${escapeXml(guid)}</guid>`,
      pubDate ? `<pubDate>${escapeXml(pubDate)}</pubDate>` : '',
      description ? `<description><![CDATA[${description}]]></description>` : '',
      '</item>',
    ].filter(Boolean).join('');
  }).filter(Boolean).join('\n');

  const channelLink = applyLangParam(new URL('/', base), lang, shouldUseLangParam, defaultLangCode).toString();

  const body = [
    '<?xml version="1.0" encoding="UTF-8"?>',
    '<rss version="2.0" xmlns:atom="http://www.w3.org/2005/Atom">',
    '<channel>',
    `<title>${escapeXml(siteName)}</title>`,
    `<link>${escapeXml(channelLink)}</link>`,
    channelDescription ? `<description>${escapeXml(channelDescription)}</description>` : '<description></description>',
    `<language>${escapeXml(lang)}</language>`,
    `<atom:link href="${escapeXml(selfUrl)}" rel="self" type="application/rss+xml" />`,
    itemsXml,
    '</channel>',
    '</rss>',
    '',
  ].join('\n');

  cacheByKey[cacheKey] = { body, expiry: now + CACHE_TTL_MS, contentType: 'application/rss+xml; charset=utf-8' };

  return new Response(body, {
    headers: {
      'Content-Type': 'application/rss+xml; charset=utf-8',
      'Cache-Control': 'no-cache, max-age=0',
    },
  });
};
