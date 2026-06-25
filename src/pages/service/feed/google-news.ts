import type { APIRoute } from 'astro';
import { supabase } from '@/lib/supabase';
import { dbQuery } from '@/lib/server/supabaseDb';
import { dataService } from '@/services/dataService.server';
import { resolveLangCode } from '@/utils/lang';
import { getPostPathSegment } from '@/utils/postUrl';

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

const clampLimit = (value: unknown, fallback = 50) => {
  const parsed = Number.parseInt(String(value ?? ''), 10);
  const limit = Number.isFinite(parsed) ? parsed : fallback;
  return Math.min(Math.max(limit, 1), 100);
};

const normalizeType = (value: string | null) => {
  const type = String(value || '').trim().toLowerCase();
  if (type === 'video') return 'video';
  if (type === 'article' || type === 'news') return 'article';
  return '';
};

interface GoogleNewsFeedSettings {
  site_name?: string | null;
  meta_description?: string | null;
  canonical_url?: string | null;
  content_post_url_structure?: string | null;
  content_redirect_rss_posts?: boolean | null;
  google_news_enabled?: boolean | null;
  google_news_publication_name?: string | null;
  google_news_rss_content_mode?: string | null;
  google_news_feed_limit?: number | null;
}

const absoluteAssetUrl = (value: string, base: string) => {
  const raw = String(value || '').trim();
  if (!raw) return '';
  try {
    return new URL(raw, base).toString();
  } catch {
    return '';
  }
};

export const GET: APIRoute = async ({ request }) => {
  const now = Date.now();
  const requestUrl = new URL(request.url);

  const seoAlternates = await dataService.getSeoAlternates();
  const defaultLangCode = seoAlternates.find((entry) => entry.isDefault)?.code || 'tr';
  const supported = seoAlternates.map((entry) => ({ code: entry.code, isDefault: entry.isDefault }));
  const urlLang = requestUrl.searchParams.get('lang');
  const lang = resolveLangCode({
    urlLang,
    cookieLang: null,
    acceptLanguageHeader: request.headers.get('accept-language'),
    supported,
    fallback: defaultLangCode,
  });

  const type = normalizeType(requestUrl.searchParams.get('type'));
  const category = String(requestUrl.searchParams.get('category') || '').trim();
  const alternateBases = seoAlternates.map((entry) => normalizeBase(entry.canonicalUrl) || normalizeBase(requestUrl.origin));
  const shouldUseLangParam = new Set(alternateBases).size <= 1;
  const cacheKey = `${requestUrl.origin}|lang:${lang}|type:${type || 'all'}|cat:${category || 'all'}|param:${shouldUseLangParam ? '1' : '0'}`;
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
    const result = await dbQuery<GoogleNewsFeedSettings>(
      `SELECT site_name,
              meta_description,
              canonical_url,
              content_post_url_structure,
              content_redirect_rss_posts,
              google_news_enabled,
              google_news_publication_name,
              google_news_rss_content_mode,
              google_news_feed_limit
         FROM public.site_settings
        WHERE language_code = $1
        LIMIT 1`,
      [languageCode]
    );
    return result.rows[0] || null;
  };

  let settings = await fetchSettings(lang);
  if (!settings && lang !== defaultLangCode) settings = await fetchSettings(defaultLangCode);

  if (settings?.google_news_enabled === false) {
    return new Response('Google News feed is disabled', {
      status: 404,
      headers: { 'Content-Type': 'text/plain; charset=utf-8' },
    });
  }

  const base = normalizeBase(settings?.canonical_url || requestUrl.origin) || requestUrl.origin;
  const publicationName = stripHtml(String(settings?.google_news_publication_name || settings?.site_name || 'Pateez.com'));
  const channelDescription = stripHtml(String(settings?.meta_description || ''));
  const feedLimit = clampLimit(requestUrl.searchParams.get('limit'), clampLimit(settings?.google_news_feed_limit, 50));
  const useFullContent = String(settings?.google_news_rss_content_mode || 'full').trim().toLowerCase() !== 'summary';

  let postsQuery = supabase
    .from('posts')
    .select('id, slug, title, summary, content, seo_description, published_at, updated_at, thumbnail_url, card_data, category, type')
    .eq('status', 'published')
    .is('deleted_at', null)
    .eq('language_code', lang)
    .lte('published_at', new Date().toISOString())
    .order('published_at', { ascending: false })
    .limit(feedLimit);

  if (type) postsQuery = postsQuery.eq('type', type);
  if (category) postsQuery = postsQuery.ilike('category', category);

  const { data: posts } = await postsQuery;

  const getExternalRssLink = (post: any) => {
    if (settings?.content_redirect_rss_posts !== true) return '';
    const cardData = post?.card_data && typeof post.card_data === 'object' ? post.card_data : {};
    const raw = String(cardData.sourceUrl || cardData.source_url || cardData.originalUrl || cardData.original_url || cardData.url || '').trim();
    if (!raw.startsWith('http://') && !raw.startsWith('https://')) return '';
    return raw;
  };

  const buildItemLink = (post: any) => {
    const externalUrl = getExternalRssLink(post);
    if (externalUrl) return externalUrl;
    const segment = getPostPathSegment(post, settings as any);
    if (!segment) return '';
    const url = new URL(`/haber/${encodeURIComponent(segment)}`, base);
    return applyLangParam(url, lang, shouldUseLangParam, defaultLangCode).toString();
  };

  const itemsXml = (posts || []).map((post: any) => {
    const link = buildItemLink(post);
    if (!link) return '';
    const title = stripHtml(String(post?.title || ''));
    const descriptionSource = useFullContent
      ? String(post?.content || post?.summary || post?.seo_description || '')
      : String(post?.seo_description || post?.summary || '');
    const description = stripHtml(descriptionSource);
    const pubDate = toRfc822(post?.published_at || post?.updated_at);
    const imageUrl = absoluteAssetUrl(String(post?.thumbnail_url || ''), base);

    return [
      '<item>',
      `<title>${escapeXml(title)}</title>`,
      `<link>${escapeXml(link)}</link>`,
      `<guid isPermaLink="true">${escapeXml(link)}</guid>`,
      pubDate ? `<pubDate>${escapeXml(pubDate)}</pubDate>` : '',
      description ? `<description><![CDATA[${description}]]></description>` : '',
      post?.category ? `<category>${escapeXml(stripHtml(String(post.category)))}</category>` : '',
      imageUrl ? `<media:content url="${escapeXml(imageUrl)}" medium="image" />` : '',
      '</item>',
    ].filter(Boolean).join('');
  }).filter(Boolean).join('\n');

  const selfUrl = new URL('/service/feed/google-news', requestUrl.origin);
  selfUrl.searchParams.set('lang', lang);
  if (type) selfUrl.searchParams.set('type', type);
  if (category) selfUrl.searchParams.set('category', category);
  const channelLink = applyLangParam(new URL('/', base), lang, shouldUseLangParam, defaultLangCode).toString();

  const body = [
    '<?xml version="1.0" encoding="UTF-8"?>',
    '<rss version="2.0" xmlns:atom="http://www.w3.org/2005/Atom" xmlns:media="http://search.yahoo.com/mrss/">',
    '<channel>',
    `<title>${escapeXml(publicationName)}</title>`,
    `<link>${escapeXml(channelLink)}</link>`,
    channelDescription ? `<description>${escapeXml(channelDescription)}</description>` : '<description></description>',
    `<language>${escapeXml(lang)}</language>`,
    `<atom:link href="${escapeXml(selfUrl.toString())}" rel="self" type="application/rss+xml" />`,
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
