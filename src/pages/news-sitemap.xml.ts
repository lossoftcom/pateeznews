import type { APIRoute } from 'astro';
import { supabase } from '@/lib/supabase';
import { dataService } from '@/services/dataService.server';
import { resolveLangCode } from '@/utils/lang';
import { getPostPathSegment } from '@/utils/postUrl';

const escapeXml = (value: string) => value
  .replace(/&/g, '&amp;')
  .replace(/</g, '&lt;')
  .replace(/>/g, '&gt;')
  .replace(/"/g, '&quot;')
  .replace(/'/g, '&apos;');

const normalizeBase = (value: string | null | undefined) => String(value || '').trim().replace(/\/$/, '');

const toBaseUrl = (value: string | null | undefined, fallbackOrigin: string) => {
  try {
    const url = new URL(normalizeBase(value) || fallbackOrigin);
    if (!url.pathname.endsWith('/')) url.pathname = `${url.pathname.replace(/\/?$/, '')}/`;
    return url;
  } catch {
    const url = new URL(fallbackOrigin);
    if (!url.pathname.endsWith('/')) url.pathname = `${url.pathname.replace(/\/?$/, '')}/`;
    return url;
  }
};

const toIso = (value: string | null | undefined) => {
  const raw = String(value || '').trim();
  if (!raw) return '';
  const date = new Date(raw);
  return Number.isNaN(date.getTime()) ? '' : date.toISOString();
};

const stripText = (value: string) => String(value || '')
  .replace(/<[^>]*>?/gm, ' ')
  .replace(/\s+/g, ' ')
  .trim();

export const GET: APIRoute = async ({ request }) => {
  const requestUrl = new URL(request.url);
  const seoAlternates = await dataService.getSeoAlternates();
  const defaultLangCode = seoAlternates.find((entry) => entry.isDefault)?.code || 'tr';
  const urlLang = requestUrl.searchParams.get('lang');
  const cookieLang = (request.headers.get('cookie') || '').match(/pateez_lang=([^;]+)/)?.[1];
  const lang = resolveLangCode({
    urlLang,
    cookieLang,
    acceptLanguageHeader: request.headers.get('accept-language'),
    supported: seoAlternates.map((entry) => ({ code: entry.code, isDefault: entry.isDefault })),
    fallback: defaultLangCode,
  });

  const siteSettings = await dataService.getSiteSettings(lang);
  const langMeta = seoAlternates.find((entry) => entry.code === lang);
  const baseUrl = toBaseUrl(langMeta?.canonicalUrl || siteSettings?.canonical_url || requestUrl.origin, requestUrl.origin);
  const since = new Date(Date.now() - 48 * 60 * 60 * 1000).toISOString();

  const { data } = await supabase
    .from('posts')
    .select('id, slug, title, seo_title, published_at')
    .eq('status', 'published')
    .is('deleted_at', null)
    .eq('language_code', lang)
    .gte('published_at', since)
    .lte('published_at', new Date().toISOString())
    .order('published_at', { ascending: false })
    .limit(1000);

  const publicationName = stripText(
    siteSettings?.google_news_publication_name ||
    siteSettings?.site_name ||
    siteSettings?.organization_legal_name ||
    'Pateez'
  );
  const newsLanguage = (lang || defaultLangCode || 'tr').split(/[-_]/)[0].toLowerCase();

  const entries = (data || []).map((post: any) => {
    const pathSegment = getPostPathSegment(post, siteSettings);
    const publicationDate = toIso(post?.published_at);
    const title = stripText(post?.seo_title || post?.title || '');
    if (!pathSegment || !publicationDate || !title) return '';
    const loc = new URL(`haber/${encodeURIComponent(pathSegment)}`, baseUrl).toString();
    return [
      '<url>',
      `<loc>${escapeXml(loc)}</loc>`,
      '<news:news>',
      '<news:publication>',
      `<news:name>${escapeXml(publicationName)}</news:name>`,
      `<news:language>${escapeXml(newsLanguage)}</news:language>`,
      '</news:publication>',
      `<news:publication_date>${escapeXml(publicationDate)}</news:publication_date>`,
      `<news:title>${escapeXml(title)}</news:title>`,
      '</news:news>',
      '</url>',
    ].join('');
  }).filter(Boolean);

  const body = [
    '<?xml version="1.0" encoding="UTF-8"?>',
    '<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9" xmlns:news="http://www.google.com/schemas/sitemap-news/0.9">',
    ...entries,
    '</urlset>',
    '',
  ].join('\n');

  return new Response(body, {
    headers: {
      'Content-Type': 'application/xml; charset=utf-8',
      'Cache-Control': 'no-cache, max-age=0',
    },
  });
};
