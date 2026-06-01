import type { APIRoute } from 'astro';
import { dataService } from '@/services/dataService.server';

const DEFAULT_FONT_SIZES: Record<string, number> = {
  'fs-base': 15,
  'fs-post-title': 32,
  'fs-post-summary': 18,
  'fs-content': 17,
  'fs-main-nav': 14,
  'fs-tiny': 11,
  'fs-xs': 12,
  'fs-sm': 13,
  'fs-md': 15,
  'fs-lg': 16,
  'fs-xl': 18,
  'fs-title-xs': 14,
  'fs-title-sm': 16,
  'fs-title-md': 18,
  'fs-title-lg': 20,
  'fs-title-xl': 22,
  'fs-title-2xl': 24,
  'fs-title-3xl': 28,
  'fs-title-4xl': 30,
  'fs-title-5xl': 32,
};

const normalizeLanguageCode = (value: unknown) => {
  const code = String(value || 'tr').trim().toLowerCase().replace(/_/g, '-');
  return code || 'tr';
};

const normalizeFontSizes = (value: unknown) => {
  let source: Record<string, unknown> = {};
  if (typeof value === 'string' && value.trim()) {
    try {
      const decoded = JSON.parse(value);
      if (decoded && typeof decoded === 'object') source = decoded as Record<string, unknown>;
    } catch {
      source = {};
    }
  } else if (value && typeof value === 'object') {
    source = value as Record<string, unknown>;
  }

  const result = { ...DEFAULT_FONT_SIZES };
  for (const key of Object.keys(DEFAULT_FONT_SIZES)) {
    const numeric = Number(source[key]);
    if (Number.isFinite(numeric)) {
      result[key] = Math.min(96, Math.max(8, Math.round(numeric)));
    }
  }
  return result;
};

const fallbackPayload = (languageCode: string) => ({
  settings: {
    languageCode,
    primaryFont: 'PateezInter',
    titleFont: 'PateezInter',
    contentFont: 'PateezInter',
    fontSizes: { ...DEFAULT_FONT_SIZES },
  },
  fonts: [],
});

const publicJson = (data: unknown, status = 200) => new Response(JSON.stringify(data), {
  status,
  headers: {
    'Content-Type': 'application/json',
    'Cache-Control': 'public, max-age=60, stale-while-revalidate=300',
    'CDN-Cache-Control': 'public, max-age=300, stale-while-revalidate=1800',
    'Cloudflare-CDN-Cache-Control': 'public, max-age=300, stale-while-revalidate=1800',
  },
});

export const GET: APIRoute = async ({ url }) => {
  const languageCode = normalizeLanguageCode(url.searchParams.get('lang'));

  try {
    const [settingsRow, fonts] = await Promise.all([
      dataService.getSiteSettings(languageCode),
      dataService.getSiteFonts(),
    ]);

    return publicJson({
      settings: {
        languageCode: String(settingsRow?.language_code || languageCode),
        primaryFont: String(settingsRow?.site_primary_font || 'PateezInter'),
        titleFont: String(settingsRow?.site_title_font || 'PateezInter'),
        contentFont: String(settingsRow?.site_content_font || 'PateezInter'),
        fontSizes: normalizeFontSizes(settingsRow?.site_font_sizes),
      },
      fonts: fonts || [],
    });
  } catch (error) {
    console.error('Error fetching font settings:', error);
    return publicJson(fallbackPayload(languageCode));
  }
};
