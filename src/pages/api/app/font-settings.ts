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

const DEFAULT_WEB_FONT_SIZES: Record<string, number> = {
  'web-nav-label': 14,
  'web-featured-title': 36,
  'web-featured-summary': 16,
  'web-card-title': 38,
  'web-card-summary': 16,
  'web-detail-title': 48,
  'web-detail-summary': 18,
  'web-detail-body': 17,
};

const DEFAULT_MOBILE_FONT_SIZES: Record<string, number> = {
  'mobile-nav-label': 14,
  'mobile-featured-title': 28,
  'mobile-featured-summary': 15,
  'mobile-card-title': 28,
  'mobile-card-summary': 15,
  'mobile-detail-title': 32,
  'mobile-detail-summary': 18,
  'mobile-detail-body': 17,
};

const DEFAULT_WEB_FONT_WEIGHTS: Record<string, number> = {
  'web-nav-label': 700,
  'web-featured-title': 800,
  'web-featured-summary': 500,
  'web-card-title': 800,
  'web-card-summary': 500,
  'web-detail-title': 800,
  'web-detail-summary': 500,
  'web-detail-body': 400,
};

const DEFAULT_MOBILE_FONT_WEIGHTS: Record<string, number> = {
  'mobile-nav-label': 600,
  'mobile-featured-title': 800,
  'mobile-featured-summary': 400,
  'mobile-card-title': 800,
  'mobile-card-summary': 400,
  'mobile-detail-title': 800,
  'mobile-detail-summary': 500,
  'mobile-detail-body': 400,
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

const mapFromUnknown = (value: unknown): Record<string, unknown> => {
  if (typeof value === 'string' && value.trim()) {
    try {
      const decoded = JSON.parse(value);
      return decoded && typeof decoded === 'object' ? decoded as Record<string, unknown> : {};
    } catch {
      return {};
    }
  }
  return value && typeof value === 'object' ? value as Record<string, unknown> : {};
};

const clampSize = (value: unknown, fallback: number) => {
  const numeric = Number(value);
  return Number.isFinite(numeric) ? Math.min(96, Math.max(8, Math.round(numeric))) : fallback;
};

const clampWeight = (value: unknown, fallback: number) => {
  const numeric = Number(value);
  const safe = Number.isFinite(numeric) ? Math.min(900, Math.max(100, Math.round(numeric))) : fallback;
  return Math.min(900, Math.max(100, Math.round(safe / 100) * 100));
};

const webDefaultsFromLegacy = (legacySizes: Record<string, number>): Record<string, number> => ({
  'web-nav-label': legacySizes['fs-main-nav'] ?? DEFAULT_WEB_FONT_SIZES['web-nav-label'],
  'web-featured-title': legacySizes['fs-title-4xl'] ?? legacySizes['fs-title-5xl'] ?? DEFAULT_WEB_FONT_SIZES['web-featured-title'],
  'web-featured-summary': legacySizes['fs-post-summary'] ?? DEFAULT_WEB_FONT_SIZES['web-featured-summary'],
  'web-card-title': legacySizes['fs-title-5xl'] ?? legacySizes['fs-title-3xl'] ?? DEFAULT_WEB_FONT_SIZES['web-card-title'],
  'web-card-summary': legacySizes['fs-content'] ? Math.min(96, Math.max(8, legacySizes['fs-content'] - 2)) : DEFAULT_WEB_FONT_SIZES['web-card-summary'],
  'web-detail-title': legacySizes['fs-post-title'] ?? DEFAULT_WEB_FONT_SIZES['web-detail-title'],
  'web-detail-summary': legacySizes['fs-post-summary'] ?? DEFAULT_WEB_FONT_SIZES['web-detail-summary'],
  'web-detail-body': legacySizes['fs-content'] ?? DEFAULT_WEB_FONT_SIZES['web-detail-body'],
});

const normalizeWebFontSizes = (value: unknown, legacySizes: Record<string, number>) => {
  const root = mapFromUnknown(value);
  const source = root.web && typeof root.web === 'object' ? root.web as Record<string, unknown> : {};
  const result = webDefaultsFromLegacy(legacySizes);
  for (const key of Object.keys(DEFAULT_WEB_FONT_SIZES)) {
    result[key] = clampSize(source[key], result[key] ?? DEFAULT_WEB_FONT_SIZES[key]);
  }
  return result;
};

const legacyFromWeb = (webSizes: Record<string, number>) => ({
  ...DEFAULT_FONT_SIZES,
  'fs-base': webSizes['web-detail-body'] ?? DEFAULT_FONT_SIZES['fs-base'],
  'fs-main-nav': webSizes['web-nav-label'] ?? DEFAULT_FONT_SIZES['fs-main-nav'],
  'fs-post-title': webSizes['web-detail-title'] ?? DEFAULT_FONT_SIZES['fs-post-title'],
  'fs-post-summary': webSizes['web-detail-summary'] ?? DEFAULT_FONT_SIZES['fs-post-summary'],
  'fs-content': webSizes['web-detail-body'] ?? DEFAULT_FONT_SIZES['fs-content'],
  'fs-md': webSizes['web-card-summary'] ?? DEFAULT_FONT_SIZES['fs-md'],
  'fs-title-3xl': webSizes['web-card-title'] ?? DEFAULT_FONT_SIZES['fs-title-3xl'],
  'fs-title-4xl': webSizes['web-featured-title'] ?? DEFAULT_FONT_SIZES['fs-title-4xl'],
  'fs-title-5xl': webSizes['web-card-title'] ?? DEFAULT_FONT_SIZES['fs-title-5xl'],
});

const mobileDefaultsFromWeb = (webSizes: Record<string, number>): Record<string, number> => ({
  'mobile-nav-label': webSizes['web-nav-label'] ?? DEFAULT_MOBILE_FONT_SIZES['mobile-nav-label'],
  'mobile-featured-title': webSizes['web-featured-title'] ?? DEFAULT_MOBILE_FONT_SIZES['mobile-featured-title'],
  'mobile-featured-summary': webSizes['web-featured-summary'] ?? DEFAULT_MOBILE_FONT_SIZES['mobile-featured-summary'],
  'mobile-card-title': webSizes['web-card-title'] ?? DEFAULT_MOBILE_FONT_SIZES['mobile-card-title'],
  'mobile-card-summary': webSizes['web-card-summary'] ?? DEFAULT_MOBILE_FONT_SIZES['mobile-card-summary'],
  'mobile-detail-title': webSizes['web-detail-title'] ?? DEFAULT_MOBILE_FONT_SIZES['mobile-detail-title'],
  'mobile-detail-summary': webSizes['web-detail-summary'] ?? DEFAULT_MOBILE_FONT_SIZES['mobile-detail-summary'],
  'mobile-detail-body': webSizes['web-detail-body'] ?? DEFAULT_MOBILE_FONT_SIZES['mobile-detail-body'],
});

const normalizeMobileFontSizes = (value: unknown, webSizes: Record<string, number>) => {
  const root = mapFromUnknown(value);
  const source = root.mobile && typeof root.mobile === 'object' ? root.mobile as Record<string, unknown> : {};
  const result: Record<string, number> = mobileDefaultsFromWeb(webSizes);
  for (const key of Object.keys(DEFAULT_MOBILE_FONT_SIZES)) {
    result[key] = clampSize(source[key], result[key] ?? DEFAULT_MOBILE_FONT_SIZES[key]);
  }
  return result;
};

const normalizeFontWeights = (
  value: unknown,
  target: 'web' | 'mobile',
  defaults: Record<string, number>
) => {
  const root = mapFromUnknown(value);
  const weights = root.weights && typeof root.weights === 'object' ? root.weights as Record<string, unknown> : {};
  const source = weights[target] && typeof weights[target] === 'object' ? weights[target] as Record<string, unknown> : {};
  const result = { ...defaults };
  for (const key of Object.keys(defaults)) {
    result[key] = clampWeight(source[key], result[key]);
  }
  return result;
};

const normalizeFontTargets = (
  value: unknown,
  target: 'web' | 'mobile',
  fallback: { primary: string; title: string; content: string }
) => {
  const root = mapFromUnknown(value);
  const fonts = root.fonts && typeof root.fonts === 'object' ? root.fonts as Record<string, unknown> : {};
  const source = fonts[target] && typeof fonts[target] === 'object' ? fonts[target] as Record<string, unknown> : {};
  return {
    primary: String(source.primary || fallback.primary || 'PateezInter'),
    title: String(source.title || fallback.title || 'PateezInter'),
    content: String(source.content || fallback.content || 'PateezInter'),
  };
};

const fallbackPayload = (languageCode: string) => ({
  settings: {
    languageCode,
    primaryFont: 'PateezInter',
    titleFont: 'PateezInter',
    contentFont: 'PateezInter',
    mobilePrimaryFont: 'PateezInter',
    mobileTitleFont: 'PateezInter',
    mobileContentFont: 'PateezInter',
    fontSizes: legacyFromWeb(DEFAULT_WEB_FONT_SIZES),
    webFontSizes: { ...DEFAULT_WEB_FONT_SIZES },
    mobileFontSizes: mobileDefaultsFromWeb(DEFAULT_WEB_FONT_SIZES),
    fontWeights: { ...DEFAULT_WEB_FONT_WEIGHTS },
    mobileFontWeights: { ...DEFAULT_MOBILE_FONT_WEIGHTS },
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

    const legacyFontSizes = normalizeFontSizes(settingsRow?.site_font_sizes);
    const webFontSizes = normalizeWebFontSizes(
      settingsRow?.site_font_sizes,
      legacyFontSizes,
    );
    const webFonts = normalizeFontTargets(settingsRow?.site_font_sizes, 'web', {
      primary: String(settingsRow?.site_primary_font || 'PateezInter'),
      title: String(settingsRow?.site_title_font || 'PateezInter'),
      content: String(settingsRow?.site_content_font || 'PateezInter'),
    });
    const mobileFonts = normalizeFontTargets(settingsRow?.site_font_sizes, 'mobile', webFonts);

    return publicJson({
      settings: {
        languageCode: String(settingsRow?.language_code || languageCode),
        primaryFont: webFonts.primary,
        titleFont: webFonts.title,
        contentFont: webFonts.content,
        mobilePrimaryFont: mobileFonts.primary,
        mobileTitleFont: mobileFonts.title,
        mobileContentFont: mobileFonts.content,
        fontSizes: legacyFromWeb(webFontSizes),
        webFontSizes,
        mobileFontSizes: normalizeMobileFontSizes(
          settingsRow?.site_font_sizes,
          webFontSizes,
        ),
        fontWeights: normalizeFontWeights(
          settingsRow?.site_font_sizes,
          'web',
          DEFAULT_WEB_FONT_WEIGHTS,
        ),
        mobileFontWeights: normalizeFontWeights(
          settingsRow?.site_font_sizes,
          'mobile',
          DEFAULT_MOBILE_FONT_WEIGHTS,
        ),
      },
      fonts: fonts || [],
    });
  } catch (error) {
    console.error('Error fetching font settings:', error);
    return publicJson(fallbackPayload(languageCode));
  }
};
