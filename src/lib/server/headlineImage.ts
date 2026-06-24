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
const TARGET_SIZES: Record<string, { width: number; height: number }> = {
  headline_square: { width: 1200, height: 1200 },
  article_4x3: { width: 1200, height: 900 },
  landscape_16x9: { width: 1280, height: 720 },
  social_9x16: { width: 1080, height: 1920 },
};
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
    return fetchRemoteHeadlineSourceImage(src);
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

export async function fetchRemoteHeadlineSourceImage(src: string) {
  let url: URL;
  try {
    url = new URL(String(src || '').trim());
  } catch {
    throw Object.assign(new Error('Invalid source image'), { status: 400 });
  }
  if (url.protocol !== 'http:' && url.protocol !== 'https:') {
    throw Object.assign(new Error('Invalid source image'), { status: 400 });
  }
  if (isBlockedRemoteImageHost(url.hostname)) {
    throw Object.assign(new Error('Blocked source image host'), { status: 400 });
  }

  const response = await fetch(url, {
    headers: {
      Accept: 'image/avif,image/webp,image/png,image/jpeg,image/svg+xml,image/*,*/*;q=0.8',
      'User-Agent': 'PateezAdmin/1.0 (+https://pateeznews.com) AppleWebKit/605.1.15',
      Referer: `${url.origin}/`,
    },
    redirect: 'follow',
    signal: AbortSignal.timeout(18_000),
  });
  if (!response.ok) {
    throw Object.assign(new Error('Source image could not be read'), { status: response.status });
  }
  const contentType = sourceImageContentType(response, url);
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
    svgAllowed: settings.allowedExtensions.has('svg'),
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

export function renderHeadlineSvgFallback(input: {
  sourceBase64: string;
  sourceMimeType: string;
  plan: HeadlinePlan;
  target: string;
  fileName: string;
  maxBytes: number;
}) {
  const target = normalizeHeadlineTarget(input.target);
  const size = TARGET_SIZES[target] || TARGET_SIZES.headline_square;
  const plan = normalizeHeadlinePlan(input.plan, target);
  const sourceMimeType = String(input.sourceMimeType || 'image/jpeg')
    .split(';')[0]
    .trim()
    .toLowerCase();
  const sourceBase64 = String(input.sourceBase64 || '').trim();
  if (!sourceBase64) {
    throw Object.assign(new Error('Source image is empty'), { status: 400 });
  }

  const svg = buildHeadlineSvg({
    sourceDataUri: `data:${sourceMimeType};base64,${sourceBase64}`,
    plan,
    size,
  });
  const bytes = Buffer.from(svg, 'utf8');
  if (input.maxBytes > 0 && bytes.length > input.maxBytes) {
    throw Object.assign(new Error('Rendered headline image exceeds upload limit'), { status: 413 });
  }
  return {
    base64: bytes.toString('base64'),
    contentType: 'image/svg+xml',
    fileName: input.fileName.replace(/\.[a-z0-9]+$/i, '.svg') || 'manset.svg',
    width: size.width,
    height: size.height,
  };
}

function sourceImageContentType(response: Response, url: URL) {
  const headerType = (response.headers.get('content-type') || '').split(';')[0].trim().toLowerCase();
  if (headerType.startsWith('image/')) return headerType;
  const extension = extensionFromPath(url.pathname);
  const map: Record<string, string> = {
    jpg: 'image/jpeg',
    jpeg: 'image/jpeg',
    png: 'image/png',
    webp: 'image/webp',
    gif: 'image/gif',
    avif: 'image/avif',
    svg: 'image/svg+xml',
  };
  return map[extension] || headerType;
}

function extensionFromPath(pathname: string) {
  const clean = pathname.split(/[?#]/)[0] || '';
  const match = clean.match(/\.([a-z0-9]+)$/i);
  return match?.[1]?.toLowerCase() || '';
}

function isBlockedRemoteImageHost(hostname: string) {
  const host = hostname.trim().toLowerCase().replace(/^\[|\]$/g, '');
  if (!host) return true;
  if (host === 'localhost' || host.endsWith('.localhost')) return true;
  if (host === 'metadata.google.internal') return true;
  if (host === '::1' || host === '0:0:0:0:0:0:0:1') return true;
  const ipv4 = host.match(/^(\d{1,3})\.(\d{1,3})\.(\d{1,3})\.(\d{1,3})$/);
  if (!ipv4) return false;
  const octets = ipv4.slice(1).map((part) => Number(part));
  if (octets.some((part) => !Number.isInteger(part) || part < 0 || part > 255)) return true;
  const [a, b] = octets;
  return (
    a === 0 ||
    a === 10 ||
    a === 127 ||
    (a === 169 && b === 254) ||
    (a === 172 && b >= 16 && b <= 31) ||
    (a === 192 && b === 168)
  );
}

function buildHeadlineSvg(input: {
  sourceDataUri: string;
  plan: HeadlinePlan;
  size: { width: number; height: number };
}) {
  const { sourceDataUri, plan, size } = input;
  const margin = Math.round(Math.min(size.width, size.height) * 0.07);
  const maxTextWidth = Math.round(size.width - margin * 2);
  const align = plan.layout?.alignment === 'center' ? 'middle' : 'start';
  const x = align === 'middle' ? Math.round(size.width / 2) : margin;
  const lines = headlineSvgLines(plan, maxTextWidth, size);
  const textHeight = lines.reduce((sum, line) => sum + line.size * line.height, 0);
  const yStart = Math.max(
    margin,
    Math.min(size.height - margin - textHeight, headlineTextBoxY(plan.layout?.preferredTextZone, size, margin)),
  );
  const overlayOpacity = plan.layout?.overlayStrength === 'low'
    ? 0.44
    : plan.layout?.overlayStrength === 'high'
      ? 0.72
      : 0.6;
  const bandHeight = Math.round(textHeight + margin * 1.3);
  const bandY = Math.max(0, Math.min(size.height - bandHeight, yStart - margin * 0.55));
  const brushY = Math.round(bandY + bandHeight - Math.min(size.height * 0.08, 78));
  let y = yStart;
  const textParts = lines.map((line) => {
    y += line.size;
    const node = `<text x="${x}" y="${Math.round(y)}" text-anchor="${align}" font-family="Poppins, Arial, sans-serif" font-size="${line.size}" font-weight="${line.bold ? 800 : 650}" fill="${line.color}" stroke="${line.stroke || 'none'}" stroke-width="${line.strokeWidth || 0}" paint-order="stroke" letter-spacing="0">${escapeXml(line.text)}</text>`;
    y += line.size * (line.height - 1);
    return node;
  });

  return `<?xml version="1.0" encoding="UTF-8"?>
<svg xmlns="http://www.w3.org/2000/svg" width="${size.width}" height="${size.height}" viewBox="0 0 ${size.width} ${size.height}">
  <defs>
    <linearGradient id="headlineFade" x1="0" x2="0" y1="0" y2="1">
      <stop offset="0" stop-color="#0f2434" stop-opacity="0"/>
      <stop offset="0.48" stop-color="#0f2434" stop-opacity="${overlayOpacity}"/>
      <stop offset="1" stop-color="#0f2434" stop-opacity="${Math.min(0.88, overlayOpacity + 0.16)}"/>
    </linearGradient>
  </defs>
  <image href="${escapeXml(sourceDataUri)}" x="0" y="0" width="${size.width}" height="${size.height}" preserveAspectRatio="xMidYMid slice"/>
  <rect width="100%" height="100%" fill="url(#headlineFade)"/>
  <path d="M ${Math.round(margin * 0.4)} ${brushY} C ${Math.round(size.width * 0.28)} ${brushY - 34}, ${Math.round(size.width * 0.52)} ${brushY + 34}, ${Math.round(size.width - margin * 0.2)} ${brushY - 10} L ${Math.round(size.width - margin * 0.15)} ${brushY + 78} C ${Math.round(size.width * 0.56)} ${brushY + 115}, ${Math.round(size.width * 0.28)} ${brushY + 64}, ${Math.round(margin * 0.2)} ${brushY + 96} Z" fill="#ef3b2d" opacity="0.92"/>
  <rect x="${margin}" y="${Math.max(margin, bandY - 16)}" width="${Math.min(size.width * 0.38, 420)}" height="12" rx="3" fill="#ffd233" opacity="0.98"/>
  <rect x="${margin}" y="${Math.max(margin, bandY + bandHeight - 28)}" width="${Math.min(size.width * 0.28, 320)}" height="10" rx="3" fill="#16456a" opacity="0.96"/>
  ${textParts.join('\n  ')}
</svg>`;
}

function headlineSvgLines(plan: HeadlinePlan, maxWidth: number, size: { width: number; height: number }) {
  const headline = plan.headline || {};
  const minSide = Math.min(size.width, size.height);
  const scale = minSide / 1200;
  const rows = [
    { text: headline.kicker, size: Math.round(34 * scale), color: '#ffd233', bold: true, upper: true, maxLines: 1 },
    { text: headline.top, size: Math.round(54 * scale), color: '#ffffff', bold: true, maxLines: 2, stroke: '#0f2434', strokeWidth: 2 },
    { text: headline.main, size: Math.round(82 * scale), color: '#ffd233', bold: true, maxLines: 2, stroke: '#0f2434', strokeWidth: 3 },
    { text: headline.bottom, size: Math.round(62 * scale), color: '#ffffff', bold: true, maxLines: 2, stroke: '#0f2434', strokeWidth: 2 },
    { text: headline.support, size: Math.round(34 * scale), color: '#ffffff', bold: false, maxLines: 2, stroke: '#0f2434', strokeWidth: 1 },
    { text: headline.tagline, size: Math.round(30 * scale), color: '#ffd233', bold: true, upper: true, maxLines: 1 },
  ];
  const output: Array<Record<string, any>> = [];
  for (const row of rows) {
    const value = String(row.text || '').replace(/\s+/g, ' ').trim();
    if (!value) continue;
    const text = row.upper ? value.toLocaleUpperCase('tr-TR') : value;
    for (const wrapped of wrapHeadlineSvgText(text, maxWidth, row.size, row.maxLines)) {
      output.push({ ...row, text: wrapped, height: row.size >= 70 * scale ? 1.04 : 1.12 });
    }
  }
  return output.length ? output : [{ text: 'PATEEZ', size: Math.round(72 * scale), color: '#ffd233', bold: true, height: 1.05 }];
}

function wrapHeadlineSvgText(text: string, maxWidth: number, fontSize: number, maxLines: number) {
  const words = text.split(/\s+/).filter(Boolean);
  const lines: string[] = [];
  let current = '';
  for (const word of words) {
    const candidate = current ? `${current} ${word}` : word;
    if (estimatedHeadlineTextWidth(candidate, fontSize) <= maxWidth || !current) {
      current = candidate;
      continue;
    }
    lines.push(current);
    current = word;
    if (lines.length >= maxLines) break;
  }
  if (current && lines.length < maxLines) lines.push(current);
  return lines;
}

function estimatedHeadlineTextWidth(text: string, fontSize: number) {
  let units = 0;
  for (const char of text) {
    if (char === ' ') units += 0.33;
    else if ('Iıijlft'.includes(char)) units += 0.36;
    else if ('mwMW@#'.includes(char)) units += 0.95;
    else units += 0.64;
  }
  return units * fontSize;
}

function headlineTextBoxY(zone: unknown, size: { width: number; height: number }, margin: number) {
  const value = String(zone || 'bottom');
  if (value === 'top') return margin * 1.5;
  if (value === 'left' || value === 'right' || value === 'center-left' || value === 'center-right') {
    return Math.round(size.height * 0.48);
  }
  return Math.round(size.height * 0.58);
}

function escapeXml(value: unknown) {
  return String(value || '')
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
    .replace(/'/g, '&apos;');
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
