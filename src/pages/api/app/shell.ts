import type { APIRoute } from "astro";
import { dbQuery } from "@/lib/server/supabaseDb";
import { dataService } from "@/services/dataService.server";
import type { NavigationItem, SiteSettings } from "@/types";

export const prerender = false;

const normalizeLanguageCode = (value: unknown) => {
  const code = String(value || "tr")
    .trim()
    .toLowerCase()
    .replace(/_/g, "-");
  return code || "tr";
};

const text = (value: unknown) => String(value || "").trim();

type AppAuthProviderStatus = {
  googleEnabled?: boolean;
  appleEnabled?: boolean;
  facebookEnabled?: boolean;
  xEnabled?: boolean;
};

const socialProviderEnabled = (
  siteEnabled: boolean | undefined,
  providerEnabled: boolean | undefined,
) => siteEnabled !== false && providerEnabled !== false;

const defaultLogoPaths = {
  logoUrl: "/local-upload/logo/tr/pateezlogoson.png",
  emailLogoUrl: "/local-upload/logo/tr/pateezlogoepost.png",
  darkLogoUrl: "/local-upload/logo/tr/pateezlogodark.png",
  faviconUrl: "/local-upload/logo/tr/pateezlogoicon.png",
} as const;

const siteSettingsPayload = (
  settings: SiteSettings | null,
  authProviders: AppAuthProviderStatus | null,
) => ({
  siteName: text(settings?.site_name),
  logoUrl: text(settings?.logo_url) || defaultLogoPaths.logoUrl,
  emailLogoUrl: text(settings?.email_logo_url) || defaultLogoPaths.emailLogoUrl,
  darkLogoUrl: text(settings?.dark_logo_url) || defaultLogoPaths.darkLogoUrl,
  faviconUrl: text(settings?.favicon_url) || defaultLogoPaths.faviconUrl,
  socialAuth: {
    googleEnabled: socialProviderEnabled(
      settings?.social_auth_google_enabled,
      authProviders?.googleEnabled,
    ),
    appleEnabled: socialProviderEnabled(
      settings?.social_auth_apple_enabled,
      authProviders?.appleEnabled,
    ),
    facebookEnabled: socialProviderEnabled(
      settings?.social_auth_facebook_enabled,
      authProviders?.facebookEnabled,
    ),
    xEnabled: socialProviderEnabled(
      settings?.social_auth_x_enabled,
      authProviders?.xEnabled,
    ),
    redirectScheme: text(settings?.social_auth_redirect_scheme) || "com.pateez.app",
    redirectHost: text(settings?.social_auth_redirect_host) || "login-callback",
  },
});

const navigationItemPayload = (item: NavigationItem) => ({
  id: text(item.id),
  menuId: text(item.menu_id),
  menuCode: text(item.menu_code),
  parentId: item.parent_id ? text(item.parent_id) : null,
  label: text(item.label),
  type: text(item.type),
  value: text(item.value),
  icon: text(item.icon),
  imageUrl: text(item.image_url),
  orderIndex: Number.isFinite(Number(item.order_index))
    ? Number(item.order_index)
    : 0,
  isActive: item.is_active !== false,
  languageCode: text(item.language_code),
});

const pagePayload = (row: any) => ({
  id: text(row.id),
  title: text(row.title),
  slug: text(row.slug),
  categoryId: text(row.category_id),
  category: text(row.category),
  pageGroup: text(row.page_group),
  pageType: text(row.page_type),
  menuOrder: Number.isFinite(Number(row.menu_order))
    ? Number(row.menu_order)
    : 0,
  contentPlain: text(row.content_plain),
  metaDescription: text(row.meta_description),
  canonicalUrl: text(row.canonical_url),
});

async function getShellPages(languageCode: string) {
  const result = await dbQuery<any>(
    `SELECT
        id,
        title,
        slug,
        category_id,
        category,
        page_group,
        page_type,
        menu_order,
        content_plain,
        meta_description,
        canonical_url
     FROM public.pages
     WHERE language_code = $1
       AND status = 'active'
     ORDER BY page_group ASC, menu_order ASC, title ASC`,
    [languageCode],
  );
  return result.rows || [];
}

const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), {
    status,
    headers: {
      "Content-Type": "application/json",
      "Cache-Control":
        "public, max-age=30, s-maxage=120, stale-while-revalidate=300",
    },
  });

export const GET: APIRoute = async ({ url }) => {
  const lang = normalizeLanguageCode(url.searchParams.get("lang"));

  try {
    const [settings, navigationItems, pages] = await Promise.all([
      dataService.getSiteSettings(lang),
      dataService.getNavigationItems(lang),
      getShellPages(lang),
    ]);

    return json({
      languageCode: lang,
      siteSettings: siteSettingsPayload(settings, null),
      navigationItems: navigationItems.map(navigationItemPayload),
      pages: pages.map(pagePayload),
    });
  } catch (error) {
    const message = import.meta.env.PROD
      ? "Request failed"
      : (error as Error).message;
    return json({ error: { message } }, 500);
  }
};
