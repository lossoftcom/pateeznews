/* empty css                                  */
import { c as createComponent, b as createAstro, r as renderComponent, a as renderTemplate } from '../chunks/astro/server_CUMT7Dv3.mjs';
import 'piccolore';
import { l as loadLocaleData, $ as $$Layout } from '../chunks/Layout_CKpoT2wu.mjs';
import { H as HomePage } from '../chunks/HomePage_CKZhcSvI.mjs';
import { d as dataService } from '../chunks/dataService_Bp0vcODm.mjs';
import { s as slugify } from '../chunks/helpers_xme2WEyl.mjs';
import { r as resolveLangCode } from '../chunks/lang_B1d4Ts2g.mjs';
export { renderers } from '../renderers.mjs';

const $$Astro = createAstro();
const $$Index = createComponent(async ($$result, $$props, $$slots) => {
  const Astro2 = $$result.createAstro($$Astro, $$props, $$slots);
  Astro2.self = $$Index;
  const cookies = Astro2.request.headers.get("cookie") || "";
  const cookieLang = cookies.match(/pateez_lang=([^;]+)/)?.[1];
  const activeCatCookieValue = cookies.match(/pateez_active_cat=([^;]+)/)?.[1];
  const activeCatCookie = activeCatCookieValue ? decodeURIComponent(activeCatCookieValue) : null;
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
  const getNewsItemsForInitialLoad = async () => {
    if (!activeCatCookie) return dataService.getNewsItems(lang);
    return dataService.getNewsItems(lang);
  };
  const [initialTranslations, siteSettings, navigationItems, storiesItems, newsItems] = await Promise.all([
    loadLocaleData(lang),
    dataService.getSiteSettings(lang),
    dataService.getNavigationItems(lang),
    dataService.getStories(lang),
    getNewsItemsForInitialLoad()
  ]);
  let selectedCategory = void 0;
  if (activeCatCookie) {
    const normalized = activeCatCookie.trim();
    const normalizedSlug = slugify(normalized);
    const navItem = navigationItems.find(
      (item) => item.value === normalized || item.label === normalized || item.value && slugify(item.value) === normalizedSlug || slugify(item.label) === normalizedSlug
    );
    if (navItem && (!navItem.parent_id || navItem.parent_id === "root")) {
      selectedCategory = normalized;
    }
  }
  const initialLang = {
    code: lang,
    name: langMeta?.name || lang.toUpperCase(),
    direction: langMeta?.direction || "ltr",
    status: "active",
    flag_code: langMeta?.flagCode || lang,
    is_default: langMeta?.isDefault || lang === defaultLangCode
  };
  const title = siteSettings?.home_title || siteSettings?.site_name || "Pateez News";
  const description = siteSettings?.meta_description || "";
  const ogImage = siteSettings?.og_image_url || "";
  const canonicalBase = String(siteSettings?.canonical_url || Astro2.url.origin).trim();
  const stripHtml = (html) => (html || "").replace(/<[^>]*>?/gm, "").replace(/&nbsp;/g, " ").trim();
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
  return renderTemplate`${renderComponent($$result, "Layout", $$Layout, { "title": title, "description": description, "ogImage": ogImage, "jsonLd": itemListLd, "favicon": siteSettings?.favicon_url, "lang": lang, "dir": initialLang.direction, "siteSettings": siteSettings, "navigationItems": navigationItems, "initialTranslations": initialTranslations, "initialLang": initialLang }, { "default": async ($$result2) => renderTemplate` ${renderComponent($$result2, "HomePage", HomePage, { "client:load": true, "initialLang": initialLang, "initialTranslations": initialTranslations, "siteSettings": siteSettings, "navigationItems": navigationItems, "newsItems": newsItems, "storiesItems": storiesItems, "selectedCategory": selectedCategory, "isInitialHome": true, "client:component-hydration": "load", "client:component-path": "@/components/HomePage", "client:component-export": "default" })} ` })}`;
}, "/Users/pateez/Desktop/pateeznews/src/pages/index.astro", void 0);

const $$file = "/Users/pateez/Desktop/pateeznews/src/pages/index.astro";
const $$url = "";

const _page = /*#__PURE__*/Object.freeze(/*#__PURE__*/Object.defineProperty({
  __proto__: null,
  default: $$Index,
  file: $$file,
  url: $$url
}, Symbol.toStringTag, { value: 'Module' }));

const page = () => _page;

export { page };
