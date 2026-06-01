import type { APIRoute } from 'astro';
import { supabase } from '@/lib/supabase';
import { dataService } from '@/services/dataService.server';
import { resolveLangCode } from '@/utils/lang';

const CACHE_TTL_MS = 0;
const cacheByLang: Record<string, { body: string; expiry: number }> = {};

export const GET: APIRoute = async ({ request }) => {
  const now = Date.now();
  const requestUrl = new URL(request.url);

  const seoAlternates = await dataService.getSeoAlternates();
  const defaultLangCode = seoAlternates.find((entry) => entry.isDefault)?.code || 'tr';

  const cookies = request.headers.get('cookie') || '';
  const cookieLang = cookies.match(/pateez_lang=([^;]+)/)?.[1];
  const urlLang = requestUrl.searchParams.get('lang');
  const lang = resolveLangCode({
    urlLang,
    cookieLang,
    acceptLanguageHeader: request.headers.get('accept-language'),
    supported: seoAlternates.map((entry) => ({ code: entry.code, isDefault: entry.isDefault })),
    fallback: defaultLangCode,
  });

  const cached = cacheByLang[lang];
  if (cached && cached.expiry > now) {
    return new Response(cached.body, {
      headers: {
        'Content-Type': 'text/plain; charset=utf-8',
        'Cache-Control': 'no-cache, max-age=0',
      },
    });
  }

  const fetchSettings = async (languageCode: string) => {
    const { data } = await supabase
      .from('site_settings')
      .select('robots_txt, canonical_url')
      .eq('language_code', languageCode)
      .maybeSingle();
    return data || null;
  };

  let settings = await fetchSettings(lang);
  if (!settings && lang !== defaultLangCode) settings = await fetchSettings(defaultLangCode);

  const base = String(settings?.canonical_url || requestUrl.origin).replace(/\/$/, '');
  let body = String(settings?.robots_txt || '').trim();

  if (!body) {
    body = [
      'User-agent: *',
      'Disallow: /admin/',
      'Allow: /',
      `Sitemap: ${base}/sitemap.xml`,
    ].join('\n');
  }

  if (body.includes('https://yourdomain.com')) {
    body = body.replaceAll('https://yourdomain.com', base);
  }

  if (!/^\s*Sitemap:/im.test(body)) {
    body = `${body}\nSitemap: ${base}/sitemap.xml`;
  }

  if (!body.endsWith('\n')) body += '\n';

  cacheByLang[lang] = { body, expiry: now + CACHE_TTL_MS };

  return new Response(body, {
    headers: {
      'Content-Type': 'text/plain; charset=utf-8',
      'Cache-Control': 'no-cache, max-age=0',
    },
  });
};
