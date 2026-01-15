import { d as dataService, s as supabase } from '../chunks/dataService_CXfGU90R.mjs';
import { r as resolveLangCode } from '../chunks/lang_B1d4Ts2g.mjs';
export { renderers } from '../renderers.mjs';

const CACHE_TTL_MS = 1e3 * 60 * 5;
const cacheByKey = {};
const escapeXml = (value) => value.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;").replace(/"/g, "&quot;").replace(/'/g, "&apos;");
const stripHtml = (html) => (html || "").replace(/<[^>]*>?/gm, "").replace(/&nbsp;/g, " ").trim();
const toRfc822 = (value) => {
  const raw = String(value || "").trim();
  if (!raw) return void 0;
  const d = new Date(raw);
  if (Number.isNaN(d.getTime())) return void 0;
  return d.toUTCString();
};
const normalizeBase = (value) => String(value || "").trim().replace(/\/$/, "");
const applyLangParam = (url, lang, shouldUseLangParam, defaultLangCode) => {
  if (shouldUseLangParam && lang && lang !== defaultLangCode) {
    url.searchParams.set("lang", lang);
  } else {
    url.searchParams.delete("lang");
  }
  return url;
};
const GET = async ({ request }) => {
  const now = Date.now();
  const requestUrl = new URL(request.url);
  const seoAlternates = await dataService.getSeoAlternates();
  const defaultLangCode = seoAlternates.find((entry) => entry.isDefault)?.code || "tr";
  const supported = seoAlternates.map((entry) => ({ code: entry.code, isDefault: entry.isDefault }));
  const alternateBases = seoAlternates.map((entry) => normalizeBase(entry.canonicalUrl) || normalizeBase(requestUrl.origin));
  const shouldUseLangParam = new Set(alternateBases).size <= 1;
  const cookies = request.headers.get("cookie") || "";
  const cookieLang = cookies.match(/pateez_lang=([^;]+)/)?.[1];
  const urlLang = requestUrl.searchParams.get("lang");
  const lang = resolveLangCode({
    urlLang,
    cookieLang,
    acceptLanguageHeader: request.headers.get("accept-language"),
    supported,
    fallback: defaultLangCode
  });
  const cacheKey = `${requestUrl.origin}|lang:${lang}|param:${shouldUseLangParam ? "1" : "0"}`;
  const cached = cacheByKey[cacheKey];
  if (cached && cached.expiry > now) {
    return new Response(cached.body, {
      headers: {
        "Content-Type": cached.contentType,
        "Cache-Control": "public, max-age=300"
      }
    });
  }
  const fetchSettings = async (languageCode) => {
    const { data } = await supabase.from("site_settings").select("site_name, meta_description, canonical_url").eq("language_code", languageCode).maybeSingle();
    return data || null;
  };
  let settings = await fetchSettings(lang);
  if (!settings && lang !== defaultLangCode) settings = await fetchSettings(defaultLangCode);
  const base = normalizeBase(settings?.canonical_url || requestUrl.origin) || requestUrl.origin;
  const siteName = String(settings?.site_name || "Pateez News").trim() || "Pateez News";
  const channelDescription = String(settings?.meta_description || "").trim();
  const selfUrl = applyLangParam(new URL("/rss.xml", requestUrl.origin), lang, shouldUseLangParam, defaultLangCode).toString();
  const { data: posts } = await supabase.from("posts").select("id, slug, title, summary, seo_description, published_at, updated_at").eq("status", "published").eq("language_code", lang).not("slug", "is", null).order("published_at", { ascending: false }).limit(50);
  const buildItemLink = (slug) => {
    const url = new URL(`/haber/${encodeURIComponent(slug)}`, base);
    return applyLangParam(url, lang, shouldUseLangParam, defaultLangCode).toString();
  };
  const itemsXml = (posts || []).map((post) => {
    const slug = String(post?.slug || "").trim();
    if (!slug) return "";
    const link = buildItemLink(slug);
    const title = stripHtml(String(post?.title || ""));
    const descriptionSource = String(post?.seo_description || post?.summary || "").trim();
    const description = stripHtml(descriptionSource);
    const pubDate = toRfc822(post?.published_at || post?.updated_at);
    const guid = link;
    return [
      "<item>",
      `<title>${escapeXml(title)}</title>`,
      `<link>${escapeXml(link)}</link>`,
      `<guid isPermaLink="true">${escapeXml(guid)}</guid>`,
      pubDate ? `<pubDate>${escapeXml(pubDate)}</pubDate>` : "",
      description ? `<description><![CDATA[${description}]]></description>` : "",
      "</item>"
    ].filter(Boolean).join("");
  }).filter(Boolean).join("\n");
  const channelLink = applyLangParam(new URL("/", base), lang, shouldUseLangParam, defaultLangCode).toString();
  const body = [
    '<?xml version="1.0" encoding="UTF-8"?>',
    '<rss version="2.0" xmlns:atom="http://www.w3.org/2005/Atom">',
    "<channel>",
    `<title>${escapeXml(siteName)}</title>`,
    `<link>${escapeXml(channelLink)}</link>`,
    channelDescription ? `<description>${escapeXml(channelDescription)}</description>` : "<description></description>",
    `<language>${escapeXml(lang)}</language>`,
    `<atom:link href="${escapeXml(selfUrl)}" rel="self" type="application/rss+xml" />`,
    itemsXml,
    "</channel>",
    "</rss>",
    ""
  ].join("\n");
  cacheByKey[cacheKey] = { body, expiry: now + CACHE_TTL_MS, contentType: "application/rss+xml; charset=utf-8" };
  return new Response(body, {
    headers: {
      "Content-Type": "application/rss+xml; charset=utf-8",
      "Cache-Control": "public, max-age=300"
    }
  });
};

const _page = /*#__PURE__*/Object.freeze(/*#__PURE__*/Object.defineProperty({
  __proto__: null,
  GET
}, Symbol.toStringTag, { value: 'Module' }));

const page = () => _page;

export { page };
