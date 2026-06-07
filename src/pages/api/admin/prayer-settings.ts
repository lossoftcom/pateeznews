import type { APIRoute } from 'astro';
import { adminError, adminJson, requireAdminRequest } from '@/lib/server/adminAuth';
import {
  getPrayerSettings,
  invalidatePrayerCache,
  savePrayerSettings,
} from '@/lib/server/prayerData';
import { invalidateDataCache, invalidateSiteSettingsCache } from '@/services/dataService';
import { invalidateServerDataCache, invalidateServerSiteSettingsCache } from '@/services/dataService.server';

export const GET: APIRoute = async ({ request }) => {
  try {
    await requireAdminRequest(request, 'view_settings');
    const url = new URL(request.url);
    const languageCode = url.searchParams.get('lang') || 'tr';
    const settings = await getPrayerSettings(languageCode);
    return adminJson({ data: settings, error: null });
  } catch (error) {
    return adminError(error);
  }
};

export const POST: APIRoute = async ({ request }) => {
  try {
    await requireAdminRequest(request, 'settings_access');
    const body = await request.json();
    const languageCode = String(body?.languageCode || body?.language_code || 'tr').trim() || 'tr';
    const values = body?.values && typeof body.values === 'object' ? body.values : {};
    const settings = await savePrayerSettings(languageCode, {
      enabled: values.enabled,
      diyanetBaseUrl: values.diyanetBaseUrl,
      locationName: values.locationName,
      locationCountry: values.locationCountry,
      locationStateId: values.locationStateId,
      locationCityId: values.locationCityId,
      timezone: values.timezone,
      refreshLeadDays: values.refreshLeadDays,
      cacheDays: values.cacheDays,
      ayahEnabled: values.ayahEnabled,
      ayahStartDate: values.ayahStartDate,
      quranApiBaseUrl: values.quranApiBaseUrl,
      quranApiToken: values.quranApiToken,
    });

    await invalidatePrayerCache(languageCode);
    invalidateSiteSettingsCache(languageCode);
    invalidateServerSiteSettingsCache(languageCode);
    invalidateDataCache((key) => key.startsWith('settings_'));
    invalidateServerDataCache((key) => key.startsWith('settings_'));

    return adminJson({ data: settings, error: null });
  } catch (error) {
    return adminError(error);
  }
};
