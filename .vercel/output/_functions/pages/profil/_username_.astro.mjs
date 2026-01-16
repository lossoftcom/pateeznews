/* empty css                                     */
import { c as createComponent, b as createAstro, r as renderComponent, a as renderTemplate } from '../../chunks/astro/server_CUMT7Dv3.mjs';
import 'piccolore';
import { l as loadLocaleData, $ as $$Layout } from '../../chunks/Layout_DqQfhmns.mjs';
import { d as dataService, s as supabase } from '../../chunks/dataService_Bp0vcODm.mjs';
import { r as resolveLangCode } from '../../chunks/lang_B1d4Ts2g.mjs';
export { renderers } from '../../renderers.mjs';

const $$Astro = createAstro();
const prerender = false;
const $$username = createComponent(async ($$result, $$props, $$slots) => {
  const Astro2 = $$result.createAstro($$Astro, $$props, $$slots);
  Astro2.self = $$username;
  const { username } = Astro2.params;
  const rawUsernameParam = String(username || "").trim();
  let rawUsername = rawUsernameParam;
  try {
    rawUsername = decodeURIComponent(rawUsernameParam);
  } catch {
    rawUsername = rawUsernameParam;
  }
  rawUsername = rawUsername.trim();
  if (!rawUsername) {
    return Astro2.redirect("/404");
  }
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
  const [initialTranslations, siteSettings, navigationItems] = await Promise.all([
    loadLocaleData(lang),
    dataService.getSiteSettings(lang),
    dataService.getNavigationItems(lang)
  ]);
  const initialLang = {
    code: lang,
    name: langMeta?.name || lang.toUpperCase(),
    direction: langMeta?.direction || "ltr",
    status: "active",
    flag_code: langMeta?.flagCode || lang,
    is_default: langMeta?.isDefault || lang === defaultLangCode
  };
  const selectProfileFields = "id, username, slug, full_name, avatar_url, about_me, expertise, website, social_links, meta_title, meta_description, meta_keywords, canonical_url, role, created_at, updated_at";
  let profileRes = await supabase.from("profiles").select(selectProfileFields).eq("username", rawUsername).maybeSingle();
  if (!profileRes.data) {
    profileRes = await supabase.from("profiles").select(selectProfileFields).eq("slug", rawUsername).maybeSingle();
  }
  const profile = profileRes.data;
  if (!profile) {
    return Astro2.redirect("/404");
  }
  const stripHtml = (html) => (html || "").replace(/<[^>]*>?/gm, "").replace(/&nbsp;/g, " ").trim();
  const canonicalBase = String(siteSettings?.canonical_url || Astro2.url.origin).trim();
  const profileSlug = String(profile.username || profile.slug || rawUsername).trim() || rawUsername;
  const derivedCanonicalUrl = new URL(`/profil/${encodeURIComponent(profileSlug)}`, canonicalBase).toString();
  const canonicalCandidateRaw = String(profile.canonical_url || "").trim();
  const canonicalUrl = (() => {
    if (!canonicalCandidateRaw) return derivedCanonicalUrl;
    try {
      const candidate = new URL(canonicalCandidateRaw, canonicalBase);
      const allowedOrigins = new Set(
        seoAlternates.map((entry) => String(entry.canonicalUrl || "").trim()).filter(Boolean).map((value) => {
          try {
            return new URL(value).origin;
          } catch {
            return "";
          }
        }).filter(Boolean)
      );
      allowedOrigins.add(Astro2.url.origin);
      return allowedOrigins.has(candidate.origin) ? candidate.toString() : derivedCanonicalUrl;
    } catch {
      return derivedCanonicalUrl;
    }
  })();
  const profileName = String(profile.full_name || profile.username || profileSlug).trim() || (siteSettings?.site_name || "Pateez");
  const title = String(profile.meta_title || "").trim() || `${profileName} | ${siteSettings?.site_name || "Pateez"}`;
  const description = String(profile.meta_description || "").trim() || stripHtml(String(profile.about_me || "")).slice(0, 160);
  const keywords = String(profile.meta_keywords || "").trim();
  const ogImage = String(profile.avatar_url || "").trim() || String(siteSettings?.og_image_url || "").trim();
  const toAbsoluteUrl = (value) => {
    const raw = String(value || "").trim();
    if (!raw) return "";
    if (raw.startsWith("http://") || raw.startsWith("https://") || raw.startsWith("data:")) return raw;
    try {
      return new URL(raw, canonicalBase || Astro2.url).toString();
    } catch {
      return raw;
    }
  };
  const parseSocialLinks = (value) => {
    try {
      if (!value) return {};
      if (typeof value === "string") return JSON.parse(value);
      if (typeof value === "object") return value;
      return {};
    } catch {
      return {};
    }
  };
  const socialLinks = parseSocialLinks(profile.social_links);
  const sameAs = Array.from(/* @__PURE__ */ new Set([
    String(profile.website || "").trim(),
    ...Object.values(socialLinks || {}).map((v) => String(v || "").trim())
  ])).filter((url) => url.startsWith("http://") || url.startsWith("https://"));
  const personLd = {
    "@context": "https://schema.org",
    "@type": "Person",
    name: stripHtml(profileName),
    url: canonicalUrl,
    ...description ? { description: stripHtml(description) } : {},
    ...toAbsoluteUrl(ogImage) ? { image: toAbsoluteUrl(ogImage) } : {},
    ...profile.expertise ? { knowsAbout: stripHtml(String(profile.expertise)) } : {},
    ...sameAs.length > 0 ? { sameAs } : {}
  };
  return renderTemplate`${renderComponent($$result, "Layout", $$Layout, { "title": title, "description": description, "keywords": keywords, "ogType": "profile", "ogImage": ogImage, "canonical": canonicalUrl, "jsonLd": personLd, "favicon": siteSettings?.favicon_url, "lang": lang, "dir": initialLang.direction, "siteSettings": siteSettings, "navigationItems": navigationItems, "initialTranslations": initialTranslations, "initialLang": initialLang }, { "default": async ($$result2) => renderTemplate` ${renderComponent($$result2, "PublicProfileApp", null, { "client:only": "react", "initialLang": initialLang, "initialTranslations": initialTranslations, "siteSettings": siteSettings, "profileId": String(profile.id || ""), "profileName": profileName, "client:component-hydration": "only", "client:component-path": "@/components/PublicProfileApp", "client:component-export": "default" })} ` })}`;
}, "/Users/pateez/Desktop/pateeznews/src/pages/profil/[username].astro", void 0);

const $$file = "/Users/pateez/Desktop/pateeznews/src/pages/profil/[username].astro";
const $$url = "/profil/[username]";

const _page = /*#__PURE__*/Object.freeze(/*#__PURE__*/Object.defineProperty({
  __proto__: null,
  default: $$username,
  file: $$file,
  prerender,
  url: $$url
}, Symbol.toStringTag, { value: 'Module' }));

const page = () => _page;

export { page };
