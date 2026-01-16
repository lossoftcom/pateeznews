/* empty css                                     */
import { c as createComponent, b as createAstro, r as renderComponent, a as renderTemplate } from '../../chunks/astro/server_CUMT7Dv3.mjs';
import 'piccolore';
import { l as loadLocaleData, $ as $$Layout } from '../../chunks/Layout_Dg8OtuKb.mjs';
import { d as dataService } from '../../chunks/dataService_Bp0vcODm.mjs';
import { r as resolveLangCode } from '../../chunks/lang_B1d4Ts2g.mjs';
export { renderers } from '../../renderers.mjs';

const $$Astro = createAstro();
const prerender = false;
const $$ = createComponent(async ($$result, $$props, $$slots) => {
  const Astro2 = $$result.createAstro($$Astro, $$props, $$slots);
  Astro2.self = $$;
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
  const [initialTranslations, siteSettings] = await Promise.all([
    loadLocaleData(lang),
    dataService.getSiteSettings(lang)
  ]);
  const initialLang = {
    code: lang,
    name: langMeta?.name || lang.toUpperCase(),
    direction: langMeta?.direction || "ltr",
    status: "active",
    flag_code: langMeta?.flagCode || lang,
    is_default: langMeta?.isDefault || lang === defaultLangCode
  };
  return renderTemplate`${renderComponent($$result, "Layout", $$Layout, { "title": "Admin Panel | Pateez", "lang": lang, "dir": initialLang.direction, "favicon": siteSettings?.favicon_url, "siteSettings": siteSettings }, { "default": async ($$result2) => renderTemplate` ${renderComponent($$result2, "AdminApp", null, { "client:only": "react", "initialLang": initialLang, "initialTranslations": initialTranslations, "siteSettings": siteSettings, "client:component-hydration": "only", "client:component-path": "@/components/admin/AdminApp", "client:component-export": "default" })} ` })}`;
}, "/Users/pateez/Desktop/pateeznews/src/pages/admin/[...path].astro", void 0);

const $$file = "/Users/pateez/Desktop/pateeznews/src/pages/admin/[...path].astro";
const $$url = "/admin/[...path]";

const _page = /*#__PURE__*/Object.freeze(/*#__PURE__*/Object.defineProperty({
  __proto__: null,
  default: $$,
  file: $$file,
  prerender,
  url: $$url
}, Symbol.toStringTag, { value: 'Module' }));

const page = () => _page;

export { page };
