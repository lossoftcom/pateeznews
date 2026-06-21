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
const IMAGE_FILE_PATTERN = /\.(?:avif|webp|png|jpe?g)(?:[?#].*)?$/i;

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

const collectImageValues = (value: unknown, output: Set<string>) => {
  if (!value) return;
  if (typeof value === 'string') {
    const trimmed = value.trim();
    if (IMAGE_FILE_PATTERN.test(trimmed)) {
      output.add(trimmed);
    }
    return;
  }
  if (Array.isArray(value)) {
    for (const item of value) collectImageValues(item, output);
    return;
  }
  if (typeof value === 'object') {
    const record = value as Record<string, unknown>;
    for (const key of ['thumbnail', 'thumbnailUrl', 'thumbnail_url', 'mediaUrl', 'media_url', 'image', 'imageUrl', 'coverImageUrl', 'mansetImageUrl']) {
      collectImageValues(record[key], output);
    }
    for (const key of ['mediaUrls', 'images', 'items', 'slides', 'directions', 'questions', 'answers', 'results']) {
      collectImageValues(record[key], output);
    }
  }
};

const toAbsoluteImageUrl = (value: string, baseUrl: URL) => {
  try {
    const url = new URL(value, baseUrl);
    if (url.protocol !== 'http:' && url.protocol !== 'https:') return '';
    return url.toString();
  } catch {
    return '';
  }
};

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

  const { data } = await supabase
    .from('posts')
    .select('id, slug, updated_at, published_at, thumbnail_url, media_url, card_data, items')
    .eq('status', 'published')
    .eq('language_code', lang)
    .order('published_at', { ascending: false })
    .limit(1000);

  const entries = (data || []).map((post: any) => {
    const pathSegment = getPostPathSegment(post, siteSettings);
    if (!pathSegment) return '';
    const loc = new URL(`haber/${encodeURIComponent(pathSegment)}`, baseUrl).toString();
    const imageValues = new Set<string>();
    collectImageValues(post?.thumbnail_url, imageValues);
    collectImageValues(post?.media_url, imageValues);
    collectImageValues(post?.card_data, imageValues);
    collectImageValues(post?.items, imageValues);

    const imageLocs = Array.from(imageValues)
      .map((value) => toAbsoluteImageUrl(value, baseUrl))
      .filter(Boolean)
      .slice(0, 1000);
    if (!imageLocs.length) return '';

    return [
      '<url>',
      `<loc>${escapeXml(loc)}</loc>`,
      ...imageLocs.map((imageLoc) => `<image:image><image:loc>${escapeXml(imageLoc)}</image:loc></image:image>`),
      '</url>',
    ].join('');
  }).filter(Boolean);

  const body = [
    '<?xml version="1.0" encoding="UTF-8"?>',
    '<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9" xmlns:image="http://www.google.com/schemas/sitemap-image/1.1">',
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
