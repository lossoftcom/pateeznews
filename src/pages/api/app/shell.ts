import type { APIRoute } from 'astro';
import { dataService } from '@/services/dataService.server';
import type { NavigationItem, SiteSettings } from '@/types';

export const prerender = false;

const normalizeLanguageCode = (value: unknown) => {
  const code = String(value || 'tr').trim().toLowerCase().replace(/_/g, '-');
  return code || 'tr';
};

const text = (value: unknown) => String(value || '').trim();

const siteSettingsPayload = (settings: SiteSettings | null) => ({
  siteName: text(settings?.site_name),
  logoUrl: text(settings?.logo_url),
  darkLogoUrl: text(settings?.dark_logo_url),
  faviconUrl: text(settings?.favicon_url),
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
  orderIndex: Number.isFinite(Number(item.order_index))
    ? Number(item.order_index)
    : 0,
  isActive: item.is_active !== false,
  languageCode: text(item.language_code),
});

const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), {
    status,
    headers: {
      'Content-Type': 'application/json',
      'Cache-Control': 'public, max-age=30, s-maxage=120, stale-while-revalidate=300',
    },
  });

export const GET: APIRoute = async ({ url }) => {
  const lang = normalizeLanguageCode(url.searchParams.get('lang'));

  try {
    const [settings, navigationItems] = await Promise.all([
      dataService.getSiteSettings(lang),
      dataService.getNavigationItems(lang),
    ]);

    return json({
      languageCode: lang,
      siteSettings: siteSettingsPayload(settings),
      navigationItems: navigationItems.map(navigationItemPayload),
    });
  } catch (error) {
    const message = import.meta.env.PROD ? 'Request failed' : (error as Error).message;
    return json({ error: { message } }, 500);
  }
};
