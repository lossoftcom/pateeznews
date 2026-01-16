/* empty css                                     */
import { c as createComponent, b as createAstro, r as renderComponent, a as renderTemplate } from '../../chunks/astro/server_CUMT7Dv3.mjs';
import 'piccolore';
import { l as loadLocaleData, $ as $$Layout } from '../../chunks/Layout_DwLhRwnK.mjs';
import { H as HomePage } from '../../chunks/HomePage_DpvHX0PO.mjs';
import { d as dataService } from '../../chunks/dataService_Bp0vcODm.mjs';
import { s as slugify } from '../../chunks/helpers_xme2WEyl.mjs';
import { r as resolveLangCode } from '../../chunks/lang_B1d4Ts2g.mjs';
import { a as getImage } from '../../chunks/_astro_assets_DfkzboBU.mjs';
export { renderers } from '../../renderers.mjs';

const $$Astro = createAstro();
const prerender = false;
const $$slug = createComponent(async ($$result, $$props, $$slots) => {
  const Astro2 = $$result.createAstro($$Astro, $$props, $$slots);
  Astro2.self = $$slug;
  const { slug } = Astro2.params;
  const cookies = Astro2.request.headers.get("cookie") || "";
  const cookieLang = cookies.match(/pateez_lang=([^;]+)/)?.[1];
  const acceptLanguageHeader = Astro2.request.headers.get("accept-language");
  const urlLang = Astro2.url.searchParams.get("lang");
  const seoAlternates = await dataService.getSeoAlternates();
  const defaultLangCode = seoAlternates.find((entry) => entry.isDefault)?.code || "tr";
  const lang = resolveLangCode({
    urlLang,
    cookieLang,
    acceptLanguageHeader,
    supported: seoAlternates.map((entry) => ({ code: entry.code, isDefault: entry.isDefault })),
    fallback: defaultLangCode
  });
  const langMeta = seoAlternates.find((entry) => entry.code === lang);
  const [initialTranslations, siteSettings, navigationItems, storiesItems] = await Promise.all([
    loadLocaleData(lang),
    dataService.getSiteSettings(lang),
    dataService.getNavigationItems(lang),
    dataService.getStories(lang)
  ]);
  const initialLang = {
    code: lang,
    name: langMeta?.name || lang.toUpperCase(),
    direction: langMeta?.direction || "ltr",
    status: "active",
    flag_code: langMeta?.flagCode || lang,
    is_default: langMeta?.isDefault || lang === defaultLangCode
  };
  const resolvedCategory = (() => {
    if (!slug) return null;
    const match = navigationItems.find((item) => item.value === slug || slugify(item.label) === slug || slugify(item.value) === slug);
    return match?.label || slug;
  })();
  const newsItems = await dataService.getNewsItems(lang, resolvedCategory);
  const title = `${resolvedCategory || slug} | ${siteSettings?.site_name || "Pateez News"}`;
  const canonicalBase = String(siteSettings?.canonical_url || Astro2.url.origin).trim();
  const canonicalUrl = new URL(`/kategori/${encodeURIComponent(String(slug || ""))}`, canonicalBase).toString();
  const stripHtml = (html) => (html || "").replace(/<[^>]*>?/gm, "").replace(/&nbsp;/g, " ").trim();
  const breadcrumbLd = {
    "@context": "https://schema.org",
    "@type": "BreadcrumbList",
    itemListElement: [
      {
        "@type": "ListItem",
        position: 1,
        name: siteSettings?.site_name || "Home",
        item: new URL("/", canonicalBase).toString()
      },
      {
        "@type": "ListItem",
        position: 2,
        name: stripHtml(String(resolvedCategory || slug || "")),
        item: canonicalUrl
      }
    ]
  };
  const itemListLd = {
    "@context": "https://schema.org",
    "@type": "ItemList",
    itemListElement: (newsItems || []).slice(0, 10).map((item, index) => ({
      "@type": "ListItem",
      position: index + 1,
      name: stripHtml(String(item?.seoTitle || item?.title || "")),
      url: new URL(`/haber/${encodeURIComponent(String(item?.slug || item?.id || ""))}`, canonicalBase).toString()
    }))
  };
  const THUMB_WIDTHS = [320, 480, 640, 840, 1280];
  const THUMB_SIZES = "(max-width: 840px) 100vw, 840px";
  const MAX_OPTIMIZED_ITEMS = 12;
  const buildOptimizedThumbnail = async (src) => {
    const raw = String(src || "").trim();
    if (!raw || raw.startsWith("data:")) return null;
    try {
      const result = await getImage({ src: raw, widths: THUMB_WIDTHS, format: "webp", quality: "mid" });
      return { src: result.src, srcSet: result.srcSet.attribute, sizes: THUMB_SIZES };
    } catch {
      return null;
    }
  };
  const newsItemsWithOptimized = await Promise.all(
    (newsItems || []).map(async (item, index) => {
      if (index >= MAX_OPTIMIZED_ITEMS) return item;
      const optimizedThumbnail = await buildOptimizedThumbnail(item?.thumbnail);
      if (!optimizedThumbnail) return item;
      return { ...item, optimizedThumbnail };
    })
  );
  return renderTemplate`${renderComponent($$result, "Layout", $$Layout, { "title": title, "lang": lang, "dir": initialLang.direction, "favicon": siteSettings?.favicon_url, "canonical": canonicalUrl, "jsonLd": [breadcrumbLd, itemListLd], "siteSettings": siteSettings, "navigationItems": navigationItems, "initialTranslations": initialTranslations, "initialLang": initialLang }, { "default": async ($$result2) => renderTemplate` ${renderComponent($$result2, "HomePage", HomePage, { "client:idle": true, "initialLang": initialLang, "initialTranslations": initialTranslations, "siteSettings": siteSettings, "navigationItems": navigationItems, "newsItems": newsItemsWithOptimized, "storiesItems": storiesItems, "selectedCategory": slug, "isInitialHome": false, "client:component-hydration": "idle", "client:component-path": "@/components/HomePage", "client:component-export": "default" })} ` })}`;
}, "/Users/pateez/Desktop/pateeznews/src/pages/kategori/[slug].astro", void 0);

const $$file = "/Users/pateez/Desktop/pateeznews/src/pages/kategori/[slug].astro";
const $$url = "/kategori/[slug]";

const _page = /*#__PURE__*/Object.freeze(/*#__PURE__*/Object.defineProperty({
  __proto__: null,
  default: $$slug,
  file: $$file,
  prerender,
  url: $$url
}, Symbol.toStringTag, { value: 'Module' }));

const page = () => _page;

export { page };
