type TrackingInput = {
  platform: string;
  campaign: string;
  contentId?: string;
};

type ShareTextInput = {
  title?: string;
  summary?: string;
  category?: string;
  siteName?: string;
  keywords?: string;
};

type XShareInput = {
  text: string;
  url: string;
  hashtags?: string[];
  via?: string;
};

type FacebookShareInput = {
  url: string;
  appId?: string | null;
  redirectUrl?: string;
};

const TEXT_ENTITY_MAP: Record<string, string> = {
  amp: '&',
  apos: "'",
  Ccedil: 'Ç',
  ccedil: 'ç',
  Gbreve: 'Ğ',
  gbreve: 'ğ',
  hellip: '...',
  Idot: 'İ',
  imath: 'ı',
  laquo: '"',
  ldquo: '"',
  lsquo: "'",
  nbsp: ' ',
  Ouml: 'Ö',
  ouml: 'ö',
  quot: '"',
  raquo: '"',
  rdquo: '"',
  rsquo: "'",
  Scedil: 'Ş',
  scedil: 'ş',
  Uuml: 'Ü',
  uuml: 'ü',
};

const decodeTextCodePoint = (value: string, radix: number, fallback: string) => {
  const codePoint = Number.parseInt(value, radix);
  if (!Number.isFinite(codePoint) || codePoint <= 0) return fallback;
  try {
    return String.fromCodePoint(codePoint);
  } catch {
    return fallback;
  }
};

export const cleanShareText = (value: unknown) => {
  const decodeOnce = (input: string) => input
    .replace(/&([a-zA-Z][a-zA-Z0-9]+);/g, (match, entity: string) => TEXT_ENTITY_MAP[entity] ?? match)
    .replace(/&#x([0-9a-fA-F]+);/g, (match, hex: string) => decodeTextCodePoint(hex, 16, match))
    .replace(/&#(\d+);/g, (match, decimal: string) => decodeTextCodePoint(decimal, 10, match));

  return decodeOnce(decodeOnce(String(value || '').replace(/<[^>]*>?/gm, ' ').replace(/&nbsp;/g, ' ')))
    .replace(/\s+/g, ' ')
    .trim();
};

const truncate = (value: string, limit: number) => {
  if (value.length <= limit) return value;
  return `${value.slice(0, Math.max(0, limit - 3)).trimEnd()}...`;
};

const normalizeHashtag = (value: unknown) => {
  const cleaned = cleanShareText(value)
    .replace(/^#+/, '')
    .replace(/[^\p{L}\p{N}_]+/gu, '')
    .trim();
  return cleaned.slice(0, 48);
};

export const buildShareHashtags = ({ category, siteName, keywords }: ShareTextInput, limit = 4) => {
  const candidates = [
    category,
    ...(String(keywords || '').split(',').map((item) => item.trim())),
    siteName,
    'Gundem',
  ];
  const seen = new Set<string>();
  const tags: string[] = [];

  for (const candidate of candidates) {
    const tag = normalizeHashtag(candidate);
    const key = tag.toLocaleLowerCase('tr-TR');
    if (!tag || seen.has(key)) continue;
    seen.add(key);
    tags.push(tag);
    if (tags.length >= limit) break;
  }

  return tags;
};

export const buildShareText = (input: ShareTextInput) => {
  const cleanTitle = truncate(cleanShareText(input.title), 180);
  const cleanSummary = truncate(cleanShareText(input.summary), 120);
  const tags = buildShareHashtags(input).map((tag) => `#${tag}`).join(' ');
  const summaryPart = cleanSummary ? `\n\n"${cleanSummary}"` : '';
  const tagPart = tags ? `\n\n${tags}` : '';
  return `📢 ${cleanTitle}${summaryPart}${tagPart}`.trim();
};

export const buildTrackedShareUrl = (baseUrl: string, tracking: TrackingInput) => {
  const raw = String(baseUrl || '').trim();
  if (!raw) return '';
  try {
    const fallbackBase = typeof window !== 'undefined' ? window.location.href : 'https://pateez.local/';
    const url = new URL(raw, fallbackBase);
    url.searchParams.set('utm_source', tracking.platform);
    url.searchParams.set('utm_medium', 'social');
    url.searchParams.set('utm_campaign', tracking.campaign);
    if (tracking.contentId) url.searchParams.set('utm_content', tracking.contentId);
    return url.toString();
  } catch {
    const separator = raw.includes('?') ? '&' : '?';
    const params = new URLSearchParams({
      utm_source: tracking.platform,
      utm_medium: 'social',
      utm_campaign: tracking.campaign,
      ...(tracking.contentId ? { utm_content: tracking.contentId } : {}),
    });
    return `${raw}${separator}${params.toString()}`;
  }
};

export const buildWhatsAppShareUrl = (message: string) => (
  `https://wa.me/?text=${encodeURIComponent(message)}`
);

export const buildTelegramShareUrl = (url: string, text: string) => {
  const params = new URLSearchParams({ url, text });
  return `https://t.me/share/url?${params.toString()}`;
};

export const buildXShareUrl = ({ text, url, hashtags = [], via }: XShareInput) => {
  const params = new URLSearchParams({
    text,
    url,
  });
  const cleanTags = hashtags.map(normalizeHashtag).filter(Boolean);
  if (cleanTags.length > 0) params.set('hashtags', cleanTags.join(','));
  const cleanVia = normalizeHashtag(via);
  if (cleanVia) params.set('via', cleanVia);
  return `https://x.com/intent/tweet?${params.toString()}`;
};

export const buildFacebookShareUrl = ({ url, appId, redirectUrl }: FacebookShareInput) => {
  const cleanAppId = String(appId || '').trim();
  if (!cleanAppId) {
    return `https://www.facebook.com/sharer/sharer.php?u=${encodeURIComponent(url)}`;
  }

  const params = new URLSearchParams({
    app_id: cleanAppId,
    display: 'popup',
    href: url,
    redirect_uri: redirectUrl || url,
  });
  return `https://www.facebook.com/dialog/share?${params.toString()}`;
};

export const openShareWindow = (url: string) => {
  if (typeof window === 'undefined' || !url) return;
  const popup = window.open(url, '_blank', 'noopener,noreferrer');
  if (popup) popup.opener = null;
};

export const writeToClipboard = async (text: string) => {
  if (!text) return false;

  if (typeof navigator !== 'undefined' && navigator.clipboard?.writeText) {
    try {
      await navigator.clipboard.writeText(text);
      return true;
    } catch {
      // Fall through to the legacy copy path below.
    }
  }

  if (typeof document === 'undefined') return false;

  const textarea = document.createElement('textarea');
  textarea.value = text;
  textarea.setAttribute('readonly', '');
  textarea.style.position = 'fixed';
  textarea.style.left = '-9999px';
  textarea.style.top = '0';
  document.body.appendChild(textarea);
  textarea.select();

  try {
    return document.execCommand('copy');
  } catch {
    return false;
  } finally {
    document.body.removeChild(textarea);
  }
};

export const isShareAbortError = (error: unknown) => (
  typeof error === 'object' &&
  error !== null &&
  'name' in error &&
  String((error as { name?: unknown }).name) === 'AbortError'
);
