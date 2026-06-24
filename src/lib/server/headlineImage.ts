import { dbQuery } from './supabaseDb';
import { loadContentUploadSettings } from './contentUploadSettings';

export const HEADLINE_TEMPLATE_ID = 'classic-red-yellow-blue';
export const HEADLINE_PURPOSE = 'headline_image';

const TARGETS = new Set([
  'headline_square',
  'article_4x3',
  'landscape_16x9',
  'social_9x16',
]);
const ZONES = new Set(['top', 'bottom', 'left', 'right', 'center-left', 'center-right']);
const ALIGNMENTS = new Set(['left', 'center']);
const OVERLAY_STRENGTHS = new Set(['low', 'medium', 'high']);
const RISKS = new Set(['low', 'medium', 'high']);
const MAX_SOURCE_BYTES = 8 * 1024 * 1024;

export type HeadlinePlan = Record<string, any>;

export function normalizeHeadlineTarget(value: unknown) {
  const target = String(value || '').trim();
  return TARGETS.has(target) ? target : 'headline_square';
}

export function outputFormatExtension(format: string) {
  if (format === 'jpeg') return 'jpg';
  if (format === 'png') return 'png';
  return 'webp';
}

export function outputContentType(format: string) {
  if (format === 'jpeg') return 'image/jpeg';
  if (format === 'png') return 'image/png';
  return 'image/webp';
}

export async function fetchHeadlineAiSettings(languageCode: string) {
  const result = await dbQuery<{
    google_ai_active: boolean | null;
    google_ai_api_key: string | null;
    google_ai_model: string | null;
  }>(
    `SELECT google_ai_active, google_ai_api_key, google_ai_model
       FROM public.site_settings
      WHERE language_code = $1
      LIMIT 1`,
    [languageCode || 'tr'],
  );
  return result.rows[0] || null;
}

export async function fetchHeadlinePrompt(promptId: string, languageCode: string) {
  const result = await dbQuery<{
    id: string;
    title: string | null;
    prompt: string | null;
    language_code: string | null;
    purpose: string | null;
    is_active: boolean | null;
  }>(
    `SELECT id, title, prompt, language_code, purpose, is_active
       FROM public.ai_ready_formats
      WHERE id = $1
        AND language_code = $2
        AND purpose = $3
        AND COALESCE(is_active, true) = true
      LIMIT 1`,
    [promptId, languageCode || 'tr', HEADLINE_PURPOSE],
  );
  return result.rows[0] || null;
}

export async function fetchHeadlineSourceImage(input: {
  request: Request;
  src: string;
}) {
  const src = String(input.src || '').trim();
  if (!src) throw Object.assign(new Error('Source image required'), { status: 400 });

  const requestUrl = new URL(input.request.url);
  let url: URL;
  try {
    url = new URL(src, requestUrl.origin);
  } catch {
    throw Object.assign(new Error('Invalid source image'), { status: 400 });
  }

  if (url.origin !== requestUrl.origin) {
    throw Object.assign(new Error('Only existing internal media can be used'), { status: 400 });
  }
  if (
    !url.pathname.startsWith('/api/storage/file/image/') &&
    !url.pathname.startsWith('/local-upload/image/')
  ) {
    throw Object.assign(new Error('Only existing image media can be used'), { status: 400 });
  }

  const response = await fetch(url, {
    headers: { Accept: 'image/avif,image/webp,image/png,image/jpeg,image/*' },
    redirect: 'follow',
    signal: AbortSignal.timeout(18_000),
  });
  if (!response.ok) {
    throw Object.assign(new Error('Source image could not be read'), {
      status: response.status,
    });
  }
  const contentType = (response.headers.get('content-type') || '').split(';')[0].trim().toLowerCase();
  if (!contentType.startsWith('image/')) {
    throw Object.assign(new Error('Unsupported source image MIME'), { status: 415 });
  }
  const contentLength = Number(response.headers.get('content-length') || 0);
  if (contentLength > MAX_SOURCE_BYTES) {
    throw Object.assign(new Error('Source image is too large'), { status: 413 });
  }
  const bytes = new Uint8Array(await response.arrayBuffer());
  if (!bytes.byteLength) {
    throw Object.assign(new Error('Source image is empty'), { status: 400 });
  }
  if (bytes.byteLength > MAX_SOURCE_BYTES) {
    throw Object.assign(new Error('Source image is too large'), { status: 413 });
  }
  return { bytes, contentType };
}

export async function headlineOutputSettings(languageCode: string) {
  const settings = await loadContentUploadSettings(languageCode || 'tr');
  const format = settings.imageOutputFormat;
  const extension = outputFormatExtension(format);
  if (!settings.allowedExtensions.has(extension)) {
    throw Object.assign(new Error('Configured image output format is not allowed'), { status: 400 });
  }
  return {
    format,
    extension,
    contentType: outputContentType(format),
    maxBytes: settings.maxImageBytes,
  };
}

export function safeHeadlineFilename(input: {
  stem: string;
  slug: string;
  target: string;
  extension: string;
}) {
  const ratio = input.target === 'article_4x3'
    ? '4x3'
    : input.target === 'landscape_16x9'
      ? '16x9'
      : input.target === 'social_9x16'
        ? '9x16'
        : '1x1';
  const stem = slugifyAscii(input.stem) || slugifyAscii(input.slug) || 'haber';
  return `${stem}-manset-${ratio}.${input.extension}`;
}

export function normalizeHeadlinePlan(input: unknown, target: string): HeadlinePlan {
  const source = input && typeof input === 'object' && !Array.isArray(input)
    ? input as Record<string, any>
    : {};
  const headlineSource = source.headline && typeof source.headline === 'object'
    ? source.headline
    : {};
  const layoutSource = source.layout && typeof source.layout === 'object'
    ? source.layout
    : {};
  const focalSource = layoutSource.focalPoint && typeof layoutSource.focalPoint === 'object'
    ? layoutSource.focalPoint
    : {};
  const mediaSource = source.media && typeof source.media === 'object'
    ? source.media
    : {};
  const readabilitySource = source.readability && typeof source.readability === 'object'
    ? source.readability
    : {};

  const plan: HeadlinePlan = {
    schemaVersion: 1,
    templateId: HEADLINE_TEMPLATE_ID,
    target: normalizeHeadlineTarget(source.target || target),
    headline: {
      kicker: limitText(headlineSource.kicker, 28),
      top: limitText(headlineSource.top, 38),
      main: limitText(headlineSource.main, 64),
      bottom: limitText(headlineSource.bottom, 64),
      support: limitText(headlineSource.support, 90),
      tagline: limitText(headlineSource.tagline, 34),
    },
    highlights: stringList(source.highlights, 4, 42),
    emphasisWords: stringList(source.emphasisWords, 4, 28),
    layout: {
      preferredTextZone: enumValue(layoutSource.preferredTextZone, ZONES, 'bottom'),
      alignment: enumValue(layoutSource.alignment, ALIGNMENTS, 'left'),
      overlayStrength: enumValue(layoutSource.overlayStrength, OVERLAY_STRENGTHS, 'medium'),
      avoidSubjectOverlap: layoutSource.avoidSubjectOverlap !== false,
      focalPoint: {
        x: clamp01(focalSource.x, 0.5),
        y: clamp01(focalSource.y, 0.5),
        confidence: clamp01(focalSource.confidence, 0.5),
      },
      avoidZones: normalizeAvoidZones(layoutSource.avoidZones),
    },
    media: {
      filenameStem: slugifyAscii(mediaSource.filenameStem),
      title: limitText(mediaSource.title, 90),
      altText: limitText(mediaSource.altText, 180),
      caption: limitText(mediaSource.caption, 180),
    },
    readability: {
      risk: enumValue(readabilitySource.risk, RISKS, 'low'),
      notes: stringList(readabilitySource.notes, 8, 120),
    },
    warnings: stringList(source.warnings, 8, 140),
  };
  return plan;
}

function normalizeAvoidZones(value: unknown) {
  if (!Array.isArray(value)) return [];
  return value.slice(0, 6).map((zone) => {
    const item = zone && typeof zone === 'object' ? zone as Record<string, any> : {};
    return {
      x: clamp01(item.x, 0),
      y: clamp01(item.y, 0),
      width: clamp01(item.width, 0),
      height: clamp01(item.height, 0),
      reason: limitText(item.reason, 80),
      confidence: clamp01(item.confidence, 0),
    };
  });
}

function enumValue(value: unknown, allowed: Set<string>, fallback: string) {
  const text = String(value || '').trim();
  return allowed.has(text) ? text : fallback;
}

function stringList(value: unknown, limit: number, maxLength: number) {
  if (!Array.isArray(value)) return [];
  return value
    .map((item) => limitText(item, maxLength))
    .filter(Boolean)
    .slice(0, limit);
}

function limitText(value: unknown, maxLength: number) {
  const text = String(value || '').replace(/\s+/g, ' ').trim();
  if (text.length <= maxLength) return text;
  return text.slice(0, maxLength).replace(/\s+\S*$/, '').trim();
}

function clamp01(value: unknown, fallback: number) {
  const parsed = Number(value);
  if (!Number.isFinite(parsed)) return fallback;
  return Math.max(0, Math.min(1, parsed));
}

export function slugifyAscii(value: unknown) {
  return String(value || '')
    .normalize('NFKD')
    .replace(/[\u0300-\u036f]/g, '')
    .replace(/[ıİ]/g, 'i')
    .replace(/[ğĞ]/g, 'g')
    .replace(/[üÜ]/g, 'u')
    .replace(/[şŞ]/g, 's')
    .replace(/[öÖ]/g, 'o')
    .replace(/[çÇ]/g, 'c')
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, '-')
    .replace(/^-+|-+$/g, '')
    .slice(0, 72)
    .replace(/-+$/g, '');
}
