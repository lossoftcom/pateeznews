import { createHash } from 'node:crypto';
import * as parse5 from 'parse5';
import { dbQuery } from './supabaseDb';

const SOURCE_FETCH_TIMEOUT_MS = 4500;
const DETAIL_FETCH_TIMEOUT_MS = 6500;
const MAX_SOURCES_PER_RUN = 60;
const MAX_CANDIDATES_PER_SOURCE = 8;
const MAX_FEED_URLS_PER_SOURCE = 5;
const MAX_NIGDE_ANADOLU_CANDIDATES = 24;
const MAX_FETCH_BYTES = 2_500_000;
const SOURCE_LEASE_SECONDS = 150;
const DISPATCH_BATCH_SIZE = 25;
const DEFAULT_SOURCE_CONCURRENCY = 8;
const INSTAGRAM_WEB_APP_ID = '936619743392459';
const USER_AGENT = 'Pateez-AutomaticNews/1.0 (+https://www.pateez.com)';
const RECENT_CONTENT_TIME_ZONE = 'Europe/Istanbul';
const AUTOMATIC_NEWS_SETTINGS_KEY = 'automatic_news.automation';
const PERSISTENT_EXPIRES_AT = '2099-12-31T23:59:59.000Z';
const NIGDE_ANADOLU_HOST = 'nigdeanadoluhaber.com.tr';

type AutomaticNewsSourceType = 'website' | 'instagram' | 'rss' | 'other';

interface AutomaticNewsSourceRow {
  id: string;
  url: string;
  display_name: string;
  source_type: AutomaticNewsSourceType;
  is_active: boolean;
  poll_interval_minutes: number;
  last_checked_at: string | null;
  last_success_at: string | null;
  last_error: string | null;
  next_poll_at?: string | null;
  lease_owner?: string | null;
  lease_expires_at?: string | null;
  last_started_at?: string | null;
  last_finished_at?: string | null;
  consecutive_failures?: number | null;
  resolved_feed_url?: string | null;
  etag?: string | null;
  last_modified?: string | null;
  last_seen_external_id?: string | null;
  health_state?: string | null;
  priority?: number | null;
  sla_tier?: string | null;
  last_duration_ms?: number | null;
  last_detected_latency_seconds?: number | null;
  sort_order: number;
  created_at: string;
  updated_at: string;
}

type DateConfidence = 'source' | 'fallback' | 'unknown';
type DuplicateState = 'none' | 'exact' | 'possible';

interface AutomaticNewsItemInput {
  source: AutomaticNewsSourceRow;
  sourceUrl: string;
  canonicalUrl: string;
  externalId: string;
  title: string;
  summary: string;
  contentText: string;
  category: string;
  status: string;
  originLabel: string;
  qualityScore: number;
  imageUrl: string;
  videoUrl: string;
  mediaUrls: string[];
  publishedAt: string | null;
  dateConfidence: DateConfidence;
  discoveredAt: string;
  rawPayload: Record<string, unknown>;
}

interface DuplicateCandidateRow {
  record_type: 'automatic' | 'post';
  id: string;
  source_label: string;
  title: string;
  summary: string;
  content_text: string;
  published_at: string | null;
  captured_at: string | null;
  canonical_url: string;
  source_url: string;
  image_url: string;
  video_url: string;
  media_urls: unknown;
}

interface DuplicateMatch {
  state: DuplicateState;
  score: number;
  matchTable: string;
  matchId: string;
  matchSource: string;
  matchTitle: string;
  matchUrl: string;
  reason: string;
}

interface WebsiteCandidate {
  url: string;
  title: string;
  summary: string;
  publishedAt: string | null;
  imageUrl: string;
  videoUrl: string;
  mediaUrls: string[];
  score: number;
  originLabel: string;
}

export interface AutomaticNewsQueueMessage {
  sourceId: string;
  scheduledAt: string;
  traceId: string;
  leaseOwner: string;
  enabledAt?: string | null;
  runId?: string;
}

interface RefreshOptions {
  force?: boolean;
  runType?: 'manual' | 'cron' | 'source';
  sourceId?: string;
}

interface ProcessSourceResult {
  sourceId: string;
  sourceName: string;
  sourceUrl: string;
  latestTitle?: string;
  latestUrl?: string;
  candidatesFound: number;
  insertedCount: number;
  skippedDuplicateCount: number;
  errorMessage: string;
}

export interface AutomaticNewsAutomationSettings {
  enabled: boolean;
  enabledAt: string | null;
  updatedAt: string | null;
}

interface ProcessSourceOptions {
  enabledAt?: string | null;
}

const normalizeText = (value: unknown) =>
  String(value || '')
    .replace(/\u00a0/g, ' ')
    .replace(/[ \t\r\f\v]+/g, ' ')
    .replace(/\n\s+/g, '\n')
    .replace(/\n{3,}/g, '\n\n')
    .trim();

const trLower = (value: string) => normalizeText(value).toLocaleLowerCase('tr-TR');

const hash = (value: string) => createHash('sha256').update(value).digest('hex');

const titleFingerprint = (title: string) =>
  hash(trLower(title).replace(/[^\p{L}\p{N}]+/gu, ' ').trim());

const decodeXmlText = (value: string) =>
  normalizeText(value)
    .replace(/^<!\[CDATA\[/, '')
    .replace(/\]\]>$/, '')
    .replace(/<[^>]+>/g, ' ')
    .replace(/&amp;/g, '&')
    .replace(/&quot;/g, '"')
    .replace(/&apos;/g, "'")
    .replace(/&#039;/g, "'")
    .replace(/&lt;/g, '<')
    .replace(/&gt;/g, '>');

const sourceTypeFromUrl = (value: string): AutomaticNewsSourceType => {
  try {
    const url = new URL(value);
    const host = url.hostname.replace(/^www\./, '');
    if (host.endsWith('instagram.com')) return 'instagram';
    if (/\/(rss|feed|atom)(\/|\.xml|$)/i.test(url.pathname)) return 'rss';
    return 'website';
  } catch {
    return 'other';
  }
};

const instagramUsernameFromUrl = (value: string) => {
  try {
    const url = new URL(value);
    if (!url.hostname.replace(/^www\./, '').endsWith('instagram.com')) return '';
    const [first] = url.pathname.split('/').filter(Boolean);
    if (!first || ['p', 'reel', 'tv', 'stories', 'explore', 'accounts'].includes(first)) return '';
    return first.replace(/^@/, '');
  } catch {
    return '';
  }
};

const normalizeSourceUrl = (value: string) => {
  const trimmed = normalizeText(value);
  if (!trimmed) return '';
  const withProtocol = /^https?:\/\//i.test(trimmed) ? trimmed : `https://${trimmed}`;
  try {
    const url = new URL(withProtocol);
    url.hash = '';
    url.hostname = url.hostname.toLowerCase();
    for (const key of [...url.searchParams.keys()]) {
      if (/^(utm_|fbclid|igshid|mc_)/i.test(key)) url.searchParams.delete(key);
    }
    if (url.hostname.replace(/^www\./, '').endsWith('instagram.com')) {
      const username = instagramUsernameFromUrl(url.toString());
      return username ? `https://www.instagram.com/${username}/` : '';
    }
    if (!url.pathname) url.pathname = '/';
    return url.toString();
  } catch {
    return '';
  }
};

const displayNameFromUrl = (value: string) => {
  const username = instagramUsernameFromUrl(value);
  if (username) return `@${username}`;
  try {
    return new URL(value).hostname.replace(/^www\./, '');
  } catch {
    return value;
  }
};

const normalizeAutomationSettings = (
  value: unknown,
  updatedAt: string | null = null,
): AutomaticNewsAutomationSettings => {
  const input = value && typeof value === 'object' && !Array.isArray(value)
    ? value as Record<string, unknown>
    : {};
  const enabledAt = normalizeText(input.enabledAt);
  return {
    enabled: input.enabled === true,
    enabledAt: enabledAt && Number.isFinite(Date.parse(enabledAt))
      ? new Date(enabledAt).toISOString()
      : null,
    updatedAt,
  };
};

export async function getAutomaticNewsAutomationSettings(): Promise<AutomaticNewsAutomationSettings> {
  const result = await dbQuery<{ payload: unknown; updated_at: string | null }>(
    `SELECT payload, updated_at
     FROM public.app_cache
     WHERE key = $1
       AND expires_at > now()
     LIMIT 1`,
    [AUTOMATIC_NEWS_SETTINGS_KEY],
  ).catch(() => ({ rows: [] as Array<{ payload: unknown; updated_at: string | null }> }));

  return normalizeAutomationSettings(
    result.rows[0]?.payload,
    result.rows[0]?.updated_at || null,
  );
}

export async function setAutomaticNewsAutomationEnabled(enabled: boolean) {
  const current = await getAutomaticNewsAutomationSettings();
  const now = new Date().toISOString();
  const settings: AutomaticNewsAutomationSettings = {
    enabled,
    enabledAt: enabled ? (current.enabled ? current.enabledAt || now : now) : null,
    updatedAt: now,
  };

  await dbQuery(
    `INSERT INTO public.app_cache (key, payload, expires_at, updated_at)
     VALUES ($1, $2::jsonb, $3::timestamptz, now())
     ON CONFLICT (key) DO UPDATE SET
       payload = EXCLUDED.payload,
       expires_at = EXCLUDED.expires_at,
       updated_at = now()`,
    [AUTOMATIC_NEWS_SETTINGS_KEY, JSON.stringify(settings), PERSISTENT_EXPIRES_AT],
  );

  if (enabled) {
    await dbQuery(
      `UPDATE public.automatic_news_sources
       SET
         next_poll_at = LEAST(COALESCE(next_poll_at, now()), now()),
         lease_owner = NULL,
         lease_expires_at = NULL,
         updated_at = now()
       WHERE is_active = true`,
    );
  } else {
    await dbQuery(
      `UPDATE public.automatic_news_sources
       SET
         lease_owner = NULL,
         lease_expires_at = NULL,
         updated_at = now()
       WHERE lease_owner IS NOT NULL
          OR lease_expires_at IS NOT NULL`,
    );
  }

  return settings;
}

const getAttr = (node: any, name: string) => {
  const attrs = Array.isArray(node?.attrs) ? node.attrs : [];
  return attrs.find((attr: any) => trLower(attr?.name) === trLower(name))?.value || '';
};

const walk = (node: any, visit: (child: any) => void) => {
  visit(node);
  for (const child of node?.childNodes || []) walk(child, visit);
};

const findAll = (node: any, predicate: (child: any) => boolean) => {
  const result: any[] = [];
  walk(node, (child) => {
    if (predicate(child)) result.push(child);
  });
  return result;
};

const nodeSignature = (node: any) =>
  trLower(`${node?.tagName || ''} ${getAttr(node, 'class')} ${getAttr(node, 'id')} ${getAttr(node, 'role')}`);

const nonContentTags = new Set([
  'script',
  'style',
  'noscript',
  'svg',
  'canvas',
  'iframe',
  'header',
  'footer',
  'nav',
  'aside',
  'form',
  'button',
]);

const nonContentNodePattern =
  /(global[_-]?price|price[_-]?content|marquee|ticker|currency|doviz|döviz|altin|altın|piyasa|borsa|kripto|crypto|bitcoin|ethereum|weather|hava|namaz|prayer|breadcrumb|sidebar|menu|navbar|navigation|footer|header|social|share|paylas|paylaş|comment|yorum|similar|related|benzer|popular|advert|reklam|banner|popup|modal|newsletter|search|arama|login|giris|giriş|kunye|künye|authors|yazar)/i;

const isNonContentNode = (node: any) => {
  if (!node?.tagName) return false;
  if (nonContentTags.has(node.tagName)) return true;
  return nonContentNodePattern.test(nodeSignature(node));
};

const textContent = (node: any): string => {
  if (!node) return '';
  if (isNonContentNode(node)) return '';
  if (node.nodeName === '#text') return node.value || '';
  return (node.childNodes || []).map(textContent).join('');
};

const textWithBreaks = (node: any): string => {
  if (!node) return '';
  if (isNonContentNode(node)) return '';
  if (node.nodeName === '#text') return node.value || '';
  if (node.tagName === 'br') return '\n';
  const block = ['article', 'main', 'section', 'p', 'div', 'li', 'h1', 'h2', 'h3'].includes(node.tagName);
  const inner = (node.childNodes || []).map(textWithBreaks).join('');
  return block ? `\n${inner}\n` : inner;
};

const metaContent = (document: any, key: string) => {
  const wanted = trLower(key);
  const node = findAll(document, (child) => child?.tagName === 'meta').find((meta) =>
    trLower(getAttr(meta, 'property')) === wanted ||
    trLower(getAttr(meta, 'name')) === wanted ||
    trLower(getAttr(meta, 'itemprop')) === wanted
  );
  return normalizeText(getAttr(node, 'content'));
};

const linkHref = (document: any, rel: string, baseUrl: string) => {
  const wanted = trLower(rel);
  const node = findAll(document, (child) => child?.tagName === 'link').find((link) =>
    trLower(getAttr(link, 'rel')).split(/\s+/).includes(wanted)
  );
  return toAbsoluteUrl(baseUrl, getAttr(node, 'href'));
};

const pageTitle = (document: any) => {
  const h1 = findAll(document, (node) => node?.tagName === 'h1')[0];
  if (h1) return normalizeText(textContent(h1));
  const title = findAll(document, (node) => node?.tagName === 'title')[0];
  return normalizeText(textContent(title));
};

const toAbsoluteUrl = (baseUrl: string, value: string) => {
  const trimmed = normalizeText(value);
  if (!trimmed || trimmed.startsWith('mailto:') || trimmed.startsWith('tel:') || trimmed.startsWith('#')) {
    return '';
  }
  try {
    const url = new URL(trimmed, baseUrl);
    if (!['http:', 'https:'].includes(url.protocol)) return '';
    url.hash = '';
    for (const key of [...url.searchParams.keys()]) {
      if (/^(utm_|fbclid|igshid|mc_)/i.test(key)) url.searchParams.delete(key);
    }
    return url.toString();
  } catch {
    return '';
  }
};

const sameHost = (a: string, b: string) => {
  try {
    return new URL(a).hostname.replace(/^www\./, '') === new URL(b).hostname.replace(/^www\./, '');
  } catch {
    return false;
  }
};

const privateIpv4Patterns = [
  /^0\./,
  /^10\./,
  /^127\./,
  /^169\.254\./,
  /^172\.(1[6-9]|2\d|3[0-1])\./,
  /^192\.168\./,
];

const assertSafeFetchUrl = (value: string) => {
  const url = new URL(value);
  if (!['http:', 'https:'].includes(url.protocol)) throw new Error('Geçersiz kaynak protokolü');
  const hostname = url.hostname.toLowerCase().replace(/^\[(.*)]$/, '$1');
  if (
    hostname === 'localhost' ||
    hostname.endsWith('.localhost') ||
    hostname === 'metadata.google.internal' ||
    hostname === '169.254.169.254'
  ) {
    throw new Error('Güvenli olmayan kaynak adresi engellendi');
  }
  if (privateIpv4Patterns.some((pattern) => pattern.test(hostname))) {
    throw new Error('Özel ağ kaynak adresi engellendi');
  }
  if (hostname === '::1' || hostname.startsWith('fc') || hostname.startsWith('fd') || hostname.startsWith('fe80:')) {
    throw new Error('Özel ağ kaynak adresi engellendi');
  }
};

const readArrayBufferLimited = async (response: Response, maxBytes = MAX_FETCH_BYTES) => {
  const contentLength = Number(response.headers.get('content-length') || 0);
  if (contentLength > maxBytes) throw new Error('Kaynak yanıtı çok büyük');
  if (!response.body) return new ArrayBuffer(0);
  const reader = response.body.getReader();
  const chunks: Uint8Array[] = [];
  let total = 0;
  while (true) {
    const { done, value } = await reader.read();
    if (done) break;
    if (!value) continue;
    total += value.byteLength;
    if (total > maxBytes) {
      await reader.cancel().catch(() => undefined);
      throw new Error('Kaynak yanıtı çok büyük');
    }
    chunks.push(value);
  }
  const bytes = new Uint8Array(total);
  let offset = 0;
  for (const chunk of chunks) {
    bytes.set(chunk, offset);
    offset += chunk.byteLength;
  }
  return bytes.buffer;
};

const readJsonLimited = async (response: Response) => {
  try {
    return JSON.parse(new TextDecoder('utf-8').decode(await readArrayBufferLimited(response)));
  } catch {
    return null;
  }
};

const fetchText = async (url: string, timeoutMs = SOURCE_FETCH_TIMEOUT_MS) => {
  assertSafeFetchUrl(url);
  const response = await fetch(url, {
    signal: AbortSignal.timeout(timeoutMs),
    headers: {
      Accept: 'text/html,application/xhtml+xml,application/xml,text/xml,application/rss+xml,application/atom+xml;q=0.9,*/*;q=0.8',
      'User-Agent': USER_AGENT,
    },
  });
  assertSafeFetchUrl(response.url || url);
  if (!response.ok) throw new Error(`${url} HTTP ${response.status}`);
  const contentType = response.headers.get('content-type') || '';
  const arrayBuffer = await readArrayBufferLimited(response);
  const decoder = /charset=iso-8859-9/i.test(contentType)
    ? new TextDecoder('iso-8859-9')
    : new TextDecoder('utf-8');
  return {
    url: response.url || url,
    contentType,
    text: decoder.decode(arrayBuffer),
  };
};

const withTimeout = async <T>(promise: Promise<T>, timeoutMs: number, label: string) => {
  let timeout: ReturnType<typeof setTimeout> | undefined;
  try {
    return await Promise.race([
      promise,
      new Promise<T>((_, reject) => {
        timeout = setTimeout(() => reject(new Error(`${label} zaman aşımına uğradı`)), timeoutMs);
      }),
    ]);
  } finally {
    if (timeout) clearTimeout(timeout);
  }
};

const looksXml = (contentType: string, text: string) =>
  /xml|rss|atom/i.test(contentType) || (/^\s*</.test(text) && /<(rss|feed)\b/i.test(text));

const junkPatterns = [
  'gizlilik politikası',
  'çerez politikası',
  'kullanım şartları',
  'kvkk',
  'künye',
  'iletişim',
  'reklam',
  'abone ol',
  'yazarlar',
  'bize ulaşın',
  'arşiv',
  'rss',
];

const isJunkText = (value: string) => {
  const haystack = trLower(value);
  if (!haystack) return true;
  if (junkPatterns.some((item) => haystack.includes(item))) return true;
  if (/^(son dakika|haberler|gündem|anasayfa|home)$/i.test(normalizeText(value))) return true;
  return false;
};

const isGoodNewsTitle = (value: string) => {
  const title = normalizeText(value);
  if (title.length < 18 || title.length > 240) return false;
  if ((title.match(/\p{L}/gu) || []).length < 10) return false;
  if (title.split(/\s+/).length < 3) return false;
  return !isJunkText(title);
};

const scoreWebsiteCandidate = (url: string, title: string) => {
  if (!isGoodNewsTitle(title)) return -100;
  let score = 10;
  const haystack = trLower(`${url} ${title}`);
  if (/\/(haber|son-dakika|gundem|gündem|yerel|nigde|niğde)\b/i.test(url)) score += 12;
  if (haystack.includes('niğde') || haystack.includes('nigde')) score += 8;
  if (haystack.includes('son dakika')) score += 4;
  if (title.length >= 45) score += 3;
  if (/\.(jpg|jpeg|png|webp|gif|pdf)$/i.test(url)) score -= 50;
  return score;
};

const parseXmlCandidates = (xml: string, baseUrl: string): WebsiteCandidate[] => {
  const blocks = [...xml.matchAll(/<(item|entry)\b[\s\S]*?<\/\1>/gi)].slice(0, MAX_CANDIDATES_PER_SOURCE * 3);
  return blocks
    .map((match): WebsiteCandidate | null => {
      const block = match[0];
      const title = decodeXmlText(block.match(/<title[^>]*>([\s\S]*?)<\/title>/i)?.[1] || '');
      const link = decodeXmlText(block.match(/<link[^>]*>([\s\S]*?)<\/link>/i)?.[1] || getXmlAttrLink(block));
      const summary = decodeXmlText(
        block.match(/<(description|summary|content:encoded|content)[^>]*>([\s\S]*?)<\/\1>/i)?.[2] || ''
      );
      const publishedAt = normalizeText(
        block.match(/<(pubDate|published|updated|dc:date)[^>]*>([\s\S]*?)<\/\1>/i)?.[2] || ''
      ) || null;
      const imageUrl = toAbsoluteUrl(baseUrl, getXmlImage(block));
      const videoUrl = toAbsoluteUrl(baseUrl, getXmlVideo(block));
      const url = toAbsoluteUrl(baseUrl, link);
      const score = scoreWebsiteCandidate(url, title) + 8;
      return url && score > 0
        ? { url, title, summary, publishedAt, imageUrl, videoUrl, mediaUrls: mediaUrlsFor(imageUrl, videoUrl), score, originLabel: 'RSS akışı' }
        : null;
    })
    .filter((item): item is WebsiteCandidate => Boolean(item));
};

const getXmlAttrLink = (block: string) =>
  block.match(/<link[^>]+href=["']([^"']+)["'][^>]*>/i)?.[1] || '';

const xmlTagUrl = (tag: string) => tag.match(/\surl=["']([^"']+)["']/i)?.[1] || '';

const getXmlMediaUrl = (block: string, kind: 'image' | 'video') => {
  for (const match of block.matchAll(/<(?:media:content|enclosure)\b[^>]+>/gi)) {
    const tag = match[0];
    const url = xmlTagUrl(tag);
    if (!url) continue;
    if (new RegExp(`(?:medium|type)=["'][^"']*${kind}`, 'i').test(tag)) return url;
    if (kind === 'image' && /\.(avif|webp|jpe?g|png|gif)(\?|$)/i.test(url)) return url;
    if (kind === 'video' && /\.(m3u8|mp4|mov|m4v|webm)(\?|$)/i.test(url)) return url;
  }
  return '';
};

const getXmlImage = (block: string) =>
  block.match(/<media:thumbnail[^>]+url=["']([^"']+)["'][^>]*>/i)?.[1] ||
  getXmlMediaUrl(block, 'image') ||
  '';

const getXmlVideo = (block: string) =>
  getXmlMediaUrl(block, 'video') ||
  '';

const articleContentNodePattern =
  /(articlebody|article[_-]?(body|content|detail)|entry[_-]?content|post[_-]?(content|body)|news[_-]?(content|detail|body)|haber[_-]?(detay|icerik|içerik)|detay|icerik|içerik)/i;

const hasArticleNodeSignal = (node: any) => {
  if (!node?.tagName || isNonContentNode(node)) return false;
  if (['article', 'main'].includes(node.tagName)) return true;
  const property = trLower(getAttr(node, 'property'));
  const itemprop = trLower(getAttr(node, 'itemprop'));
  return property === 'articlebody' ||
    itemprop === 'articlebody' ||
    articleContentNodePattern.test(nodeSignature(node));
};

const articleNodeScore = (node: any) => {
  if (!node?.tagName || isNonContentNode(node)) return -1000;
  const signature = nodeSignature(node);
  const property = trLower(getAttr(node, 'property'));
  const itemprop = trLower(getAttr(node, 'itemprop'));
  let score = 0;
  if (property === 'articlebody' || itemprop === 'articlebody') score += 180;
  if (articleContentNodePattern.test(signature)) score += 120;
  if (node.tagName === 'article') score += 80;
  if (node.tagName === 'main') score += 20;
  const paragraphs = findAll(node, (child) => child?.tagName === 'p' && !isNonContentNode(child)).length;
  const textLength = normalizeText(textWithBreaks(node)).length;
  score += Math.min(paragraphs * 8, 60);
  score += Math.min(Math.floor(textLength / 180), 40);
  if (textLength > 18000) score -= 80;
  return score;
};

const articleRoot = (document: any) => {
  const candidates = findAll(document, hasArticleNodeSignal)
    .map((node) => ({ node, score: articleNodeScore(node) }))
    .filter((item) => item.score > 0)
    .sort((a, b) => b.score - a.score);
  return candidates[0]?.node || document;
};

const isBoilerplateLine = (value: string) => {
  const line = normalizeText(value);
  const lower = trLower(line);
  if (!line) return true;
  if (/^(dolar|euro|sterlin|g\.?\s*altın|gram altın|ç\.?\s*altın|çeyrek altın|bist|bitcoin|ethereum)$/i.test(line)) {
    return true;
  }
  if (/^%?\s*-?\d{1,3}([.,]\d{1,4})?$/.test(line)) return true;
  if (/^(haberler|künye|bilgileri|giriş|giriş yap|yap|rss|yerel haberler|fotoğraf galeri|video galeri)$/i.test(line)) {
    return true;
  }
  if (/^(niğde|nigde|bor|ulukışla|ulukisla|çiftlik|ciftlik|çamardı|camardi|altunhisar|tarım|sağlık|bölge|seyahat|emlak|anne & çocuk|güzellik & estetik|bilim & teknoloji|eğitim|astroloji|kültür & sanat|kadın)$/i.test(line)) {
    return true;
  }
  if (/^(son haberler|benzer haberler|ilginizi çekebilir|etiketler|yorumlar|paylaş|haberi paylaş)$/i.test(lower)) {
    return true;
  }
  if (/^(tıkla izle|tikla izle|görsel kaynağı\s*:?.*|gorsel kaynagi\s*:?.*|haber kaynağı\s*:?.*|haber kaynagi\s*:?.*|muhabir\s*:?.*)$/i.test(lower)) {
    return true;
  }
  return false;
};

const cleanArticleBodyText = (value: string) => {
  const lines = normalizeText(value)
    .split('\n')
    .map((line) => normalizeText(line))
    .filter(Boolean);
  const kept: string[] = [];
  let skipNextCreditLine = false;
  for (const line of lines) {
    const lower = trLower(line);
    if (skipNextCreditLine) {
      skipNextCreditLine = false;
      continue;
    }
    if (/^(benzer haberler|son haberler|ilginizi çekebilir|yorumlar|etiketler)$/i.test(lower)) break;
    if (/^(görsel kaynağı|gorsel kaynagi|haber kaynağı|haber kaynagi)\s*:?\s*$/i.test(lower)) {
      skipNextCreditLine = true;
      continue;
    }
    if (isBoilerplateLine(line)) continue;
    if (kept[kept.length - 1] === line) continue;
    kept.push(line);
  }
  return kept.join('\n').slice(0, 12000);
};

const firstParagraph = (document: any) =>
  findAll(articleRoot(document), (node) => node?.tagName === 'p' && !isNonContentNode(node))
    .map((node) => normalizeText(textContent(node)))
    .find((text) => text.length > 40) || '';

const articleText = (document: any) => {
  return cleanArticleBodyText(textWithBreaks(articleRoot(document)));
};

const extractDate = (document: any, fallback: string | null) => {
  const keys = ['article:published_time', 'datePublished', 'publishdate', 'pubdate', 'dc.date', 'og:updated_time'];
  for (const key of keys) {
    const value = metaContent(document, key);
    if (value && !Number.isNaN(Date.parse(value))) return new Date(value).toISOString();
  }
  if (fallback && !Number.isNaN(Date.parse(fallback))) return new Date(fallback).toISOString();
  return null;
};

const imageFromDocument = (document: any, baseUrl: string, fallback: string) =>
  toAbsoluteUrl(baseUrl, metaContent(document, 'og:image') || metaContent(document, 'twitter:image') || fallback);

const addUniqueUrl = (items: string[], value: string) => {
  const url = normalizeText(value);
  if (!url) return;
  const key = url.replace(/[?#].*$/, '');
  if (!items.some((item) => item.replace(/[?#].*$/, '') === key)) items.push(url);
};

const videoFromDocument = (document: any, baseUrl: string, fallback = '') => {
  const direct = metaContent(document, 'og:video:secure_url') ||
    metaContent(document, 'og:video:url') ||
    metaContent(document, 'og:video') ||
    metaContent(document, 'twitter:player') ||
    fallback;
  const directUrl = toAbsoluteUrl(baseUrl, direct);
  if (directUrl) return directUrl;
  const source = findAll(document, (node) => node?.tagName === 'source' || node?.tagName === 'video')
    .map((node) => toAbsoluteUrl(baseUrl, getAttr(node, 'src') || getAttr(node, 'data-src')))
    .find(Boolean);
  return source || '';
};

const mediaUrlsFor = (imageUrl: string, videoUrl: string, extra: string[] = []) => {
  const urls: string[] = [];
  for (const url of [imageUrl, videoUrl, ...extra]) addUniqueUrl(urls, url);
  return urls.slice(0, 16);
};

const categoryForText = (value: string) => {
  const text = trLower(value);
  if (/(ekonomi|piyasa|fiyat|zam|ihale|ticaret|borsa|esnaf)/i.test(text)) return 'Ekonomi';
  if (/(spor|maç|futbol|basketbol|voleybol|turnuva)/i.test(text)) return 'Spor';
  if (/(sağlık|hastane|doktor|ilaç|ambulans)/i.test(text)) return 'Sağlık';
  if (/(okul|üniversite|öğrenci|eğitim|sınav)/i.test(text)) return 'Eğitim';
  if (/(etkinlik|festival|konser|kültür|sanat|yaşam)/i.test(text)) return 'Yaşam';
  if (/(niğde|nigde|bor|çamardı|camardi|çiftlik|ciftlik|ulukışla|ulukisla|altunhisar)/i.test(text)) return 'Niğde';
  return 'Gündem';
};

const qualityForText = (title: string, summary: string, body: string, sourceType: AutomaticNewsSourceType) => {
  let score = sourceType === 'instagram' ? 68 : 72;
  if (title.length >= 42) score += 8;
  if (summary.length >= 70) score += 6;
  if (body.length >= 500) score += 8;
  if (/(niğde|nigde|bor|çamardı|camardi|çiftlik|ciftlik|ulukışla|ulukisla|altunhisar)/i.test(`${title} ${summary} ${body}`)) {
    score += 8;
  }
  if (isJunkText(`${title} ${summary.slice(0, 120)}`)) score -= 30;
  return Math.max(0, Math.min(100, score));
};

const summaryFor = (summary: string, body: string, title: string) => {
  const clean = normalizeText(summary || firstSentence(body));
  if (!clean || trLower(clean) === trLower(title)) return '';
  return clean.slice(0, 320);
};

const firstSentence = (value: string) => {
  const clean = normalizeText(value).replace(/\s+/g, ' ');
  const match = clean.match(/^(.{40,260}?[.!?])\s/);
  return match?.[1] || clean.slice(0, 240);
};

const istanbulDateKeyFormatter = new Intl.DateTimeFormat('en-CA', {
  timeZone: RECENT_CONTENT_TIME_ZONE,
  year: 'numeric',
  month: '2-digit',
  day: '2-digit',
});

const istanbulDateKey = (date: Date) => istanbulDateKeyFormatter.format(date);

const recentContentDateKeys = () => {
  const now = new Date();
  const yesterday = new Date(now.getTime() - 24 * 60 * 60 * 1000);
  return new Set([istanbulDateKey(now), istanbulDateKey(yesterday)]);
};

const isRecentPublishedAt = (value: string | null) => {
  if (!value) return true;
  const timestamp = Date.parse(value);
  if (!Number.isFinite(timestamp)) return false;
  return recentContentDateKeys().has(istanbulDateKey(new Date(timestamp)));
};

const isRecentAutomaticNewsItem = (item: AutomaticNewsItemInput) =>
  isRecentPublishedAt(item.publishedAt);

const isAfterAutomationWindow = (item: AutomaticNewsItemInput, enabledAt: string | null | undefined) => {
  if (!enabledAt) return true;
  const enabledTimestamp = Date.parse(enabledAt);
  if (!Number.isFinite(enabledTimestamp)) return true;
  const itemTimestamp = item.publishedAt ? Date.parse(item.publishedAt) : Date.parse(item.discoveredAt);
  return Number.isFinite(itemTimestamp) && itemTimestamp >= enabledTimestamp;
};

const filterItemsByAutomationWindow = (
  items: AutomaticNewsItemInput[],
  enabledAt: string | null | undefined,
) => items.filter((item) => isAfterAutomationWindow(item, enabledAt));

const dateConfidenceFor = (publishedAt: string | null): DateConfidence =>
  publishedAt ? 'source' : 'unknown';

const discoveredAtNow = () => new Date().toISOString();

const parseWebsiteArticle = async (
  source: AutomaticNewsSourceRow,
  candidate: WebsiteCandidate,
): Promise<AutomaticNewsItemInput | null> => {
  const response = await fetchText(candidate.url, DETAIL_FETCH_TIMEOUT_MS);
  const document = parse5.parse(response.text);
  const rawTitle = metaContent(document, 'og:title') || pageTitle(document) || candidate.title;
  const title = normalizeText(rawTitle.replace(/\s*[|-]\s*[^|-]{2,45}$/u, ''));
  if (!isGoodNewsTitle(title)) return null;

  const body = articleText(document);
  const summary = summaryFor(
    metaContent(document, 'og:description') || metaContent(document, 'description') || candidate.summary || firstParagraph(document),
    body,
    title,
  );
  if (body.length < 90 && summary.length < 40) return null;
  if (isJunkText(`${title} ${summary}`)) return null;

  const canonicalUrl = linkHref(document, 'canonical', response.url) || response.url;
  const publishedAt = extractDate(document, candidate.publishedAt);
  const qualityScore = qualityForText(title, summary, body, source.source_type);
  const imageUrl = imageFromDocument(document, response.url, candidate.imageUrl);
  const videoUrl = videoFromDocument(document, response.url, candidate.videoUrl);
  const mediaUrls = mediaUrlsFor(imageUrl, videoUrl, candidate.mediaUrls);

  return {
    source,
    sourceUrl: response.url,
    canonicalUrl,
    externalId: canonicalUrl,
    title,
    summary,
    contentText: body,
    category: categoryForText(`${title} ${summary} ${body}`),
    status: qualityScore >= 78 ? 'Hazır' : 'İncele',
    originLabel: candidate.originLabel || 'Kaynak haber sayfası',
    qualityScore,
    imageUrl,
    videoUrl,
    mediaUrls,
    publishedAt,
    dateConfidence: dateConfidenceFor(publishedAt),
    discoveredAt: discoveredAtNow(),
    rawPayload: {
      discoveredUrl: candidate.url,
      canonicalUrl,
      contentType: response.contentType,
      mediaUrls,
    },
  };
};

const itemFromWebsiteCandidate = (
  source: AutomaticNewsSourceRow,
  candidate: WebsiteCandidate,
): AutomaticNewsItemInput => {
  const summary = summaryFor(candidate.summary, candidate.summary, candidate.title);
  const qualityScore = qualityForText(candidate.title, summary, candidate.summary, source.source_type);
  return {
    source,
    sourceUrl: candidate.url,
    canonicalUrl: candidate.url,
    externalId: candidate.url,
    title: candidate.title,
    summary,
    contentText: candidate.summary,
    category: categoryForText(`${candidate.title} ${candidate.summary}`),
    status: qualityScore >= 78 ? 'Hazır' : 'İncele',
    originLabel: candidate.originLabel || 'Kaynak son içerik',
    qualityScore,
    imageUrl: candidate.imageUrl,
    videoUrl: candidate.videoUrl,
    mediaUrls: mediaUrlsFor(candidate.imageUrl, candidate.videoUrl, candidate.mediaUrls),
    publishedAt: candidate.publishedAt,
    dateConfidence: dateConfidenceFor(candidate.publishedAt),
    discoveredAt: discoveredAtNow(),
    rawPayload: {
      discoveredUrl: candidate.url,
      fastPreview: true,
      mediaUrls: mediaUrlsFor(candidate.imageUrl, candidate.videoUrl, candidate.mediaUrls),
    },
  };
};

const isNigdeAnadoluSource = (source: AutomaticNewsSourceRow) => {
  try {
    return new URL(source.url).hostname.replace(/^www\./, '') === NIGDE_ANADOLU_HOST;
  } catch {
    return false;
  }
};

const isNigdeAnadoluNewsUrl = (source: AutomaticNewsSourceRow, value: string) => {
  if (!sameHost(source.url, value)) return false;
  try {
    const pathname = new URL(value).pathname.replace(/\/+$/, '');
    return /^\/haber\/[^/]+$/i.test(pathname);
  } catch {
    return false;
  }
};

const titleFromNigdeAnadoluUrl = (value: string) => {
  try {
    const slug = decodeURIComponent(new URL(value).pathname.split('/').filter(Boolean).pop() || '');
    return normalizeText(slug.replace(/[-_]+/g, ' '));
  } catch {
    return '';
  }
};

const parseNigdeAnadoluSitemapCandidates = (
  source: AutomaticNewsSourceRow,
  xml: string,
  baseUrl: string,
) => {
  const candidates: WebsiteCandidate[] = [];
  for (const match of xml.matchAll(/<url\b[\s\S]*?<\/url>/gi)) {
    const block = match[0];
    const url = toAbsoluteUrl(baseUrl, decodeXmlText(block.match(/<loc[^>]*>([\s\S]*?)<\/loc>/i)?.[1] || ''));
    if (!url || !isNigdeAnadoluNewsUrl(source, url)) continue;
    const imageUrl = toAbsoluteUrl(
      baseUrl,
      decodeXmlText(block.match(/<image:loc[^>]*>([\s\S]*?)<\/image:loc>/i)?.[1] || ''),
    );
    const title = normalizeText(
      decodeXmlText(block.match(/<image:title[^>]*>([\s\S]*?)<\/image:title>/i)?.[1] || '') ||
        titleFromNigdeAnadoluUrl(url),
    );
    const lastmod = normalizeText(block.match(/<lastmod[^>]*>([\s\S]*?)<\/lastmod>/i)?.[1] || '');
    const publishedAt = lastmod && Number.isFinite(Date.parse(lastmod))
      ? new Date(lastmod).toISOString()
      : null;
    const score = Math.max(scoreWebsiteCandidate(url, title), 8) + 14;
    if (!isGoodNewsTitle(title)) continue;
    candidates.push({
      url,
      title,
      summary: '',
      publishedAt,
      imageUrl,
      videoUrl: '',
      mediaUrls: mediaUrlsFor(imageUrl, ''),
      score,
      originLabel: 'Niğde Anadolu sitemap',
    });
    if (candidates.length >= MAX_NIGDE_ANADOLU_CANDIDATES * 3) break;
  }
  return candidates;
};

const imageAltFromAnchor = (anchor: any) =>
  findAll(anchor, (node) => node?.tagName === 'img')
    .map((img) => normalizeText(getAttr(img, 'alt') || getAttr(img, 'title')))
    .find((text) => text.length >= 18) || '';

const parseNigdeAnadoluPageCandidates = (
  source: AutomaticNewsSourceRow,
  document: any,
  baseUrl: string,
) => {
  const candidates: WebsiteCandidate[] = [];
  for (const anchor of findAll(document, (node) => node?.tagName === 'a')) {
    const url = toAbsoluteUrl(baseUrl, getAttr(anchor, 'href'));
    if (!url || !isNigdeAnadoluNewsUrl(source, url)) continue;
    const title = normalizeText(textContent(anchor) || getAttr(anchor, 'title') || imageAltFromAnchor(anchor) || titleFromNigdeAnadoluUrl(url));
    if (!isGoodNewsTitle(title)) continue;
    const imageUrl = toAbsoluteUrl(
      baseUrl,
      findAll(anchor, (node) => node?.tagName === 'img')
        .map((img) => getAttr(img, 'data-src') || getAttr(img, 'src'))
        .find(Boolean) || '',
    );
    candidates.push({
      url,
      title,
      summary: '',
      publishedAt: null,
      imageUrl,
      videoUrl: '',
      mediaUrls: mediaUrlsFor(imageUrl, ''),
      score: Math.max(scoreWebsiteCandidate(url, title), 8) + 18,
      originLabel: 'Niğde Anadolu haber listesi',
    });
  }
  return candidates;
};

const collectNigdeAnadoluItems = async (source: AutomaticNewsSourceRow) => {
  const origin = (() => {
    try {
      return new URL(source.url).origin;
    } catch {
      return 'https://nigdeanadoluhaber.com.tr';
    }
  })();
  const seedUrls = [
    source.url,
    `${origin}/haberler`,
    `${origin}/sitemap.xml`,
  ];
  const responses = await Promise.allSettled(seedUrls.map((url) => fetchText(url)));
  const candidates = new Map<string, WebsiteCandidate>();

  for (const result of responses) {
    if (result.status !== 'fulfilled') continue;
    const response = result.value;
    const parsed = looksXml(response.contentType, response.text)
      ? parseNigdeAnadoluSitemapCandidates(source, response.text, response.url)
      : parseNigdeAnadoluPageCandidates(source, parse5.parse(response.text), response.url);
    for (const item of parsed) {
      const current = candidates.get(item.url);
      if (!current || item.score > current.score) candidates.set(item.url, item);
    }
  }

  const sortedCandidates = [...candidates.values()]
    .sort((a, b) => {
      const dateA = a.publishedAt ? Date.parse(a.publishedAt) || 0 : 0;
      const dateB = b.publishedAt ? Date.parse(b.publishedAt) || 0 : 0;
      if (dateA !== dateB) return dateB - dateA;
      return b.score - a.score;
    })
    .slice(0, MAX_NIGDE_ANADOLU_CANDIDATES);

  const parsedItems = await mapLimited(sortedCandidates, 6, async (candidate) =>
    withTimeout(parseWebsiteArticle(source, candidate), DETAIL_FETCH_TIMEOUT_MS, source.display_name)
      .catch(() => null)
  );

  return parsedItems
    .filter((item): item is AutomaticNewsItemInput => Boolean(item))
    .filter(isRecentAutomaticNewsItem);
};

const collectFeedUrls = (document: any, baseUrl: string) => {
  const links = findAll(document, (node) => node?.tagName === 'link');
  return links
    .filter((node) => {
      const rel = trLower(getAttr(node, 'rel'));
      const type = trLower(getAttr(node, 'type'));
      return rel.includes('alternate') && /(rss|atom|xml)/i.test(type);
    })
    .map((node) => toAbsoluteUrl(baseUrl, getAttr(node, 'href')))
    .filter(Boolean)
    .slice(0, MAX_FEED_URLS_PER_SOURCE);
};

const commonFeedUrls = (baseUrl: string) => {
  try {
    const url = new URL(baseUrl);
    const origin = url.origin;
    return [
      `${origin}/feed/`,
      `${origin}/feed`,
      `${origin}/rss`,
      `${origin}/rss.xml`,
      `${origin}/atom.xml`,
    ];
  } catch {
    return [];
  }
};

const collectWebsiteItems = async (source: AutomaticNewsSourceRow) => {
  const candidates = new Map<string, WebsiteCandidate>();
  const attempted = new Set<string>();
  const feedUrls = new Set<string>([
    source.resolved_feed_url || '',
    source.url,
    ...commonFeedUrls(source.url),
  ].filter(Boolean));

  const collectFromUrl = async (url: string) => {
    if (!url || attempted.has(url)) return;
    attempted.add(url);
    const response = await fetchText(url);
    if (looksXml(response.contentType, response.text)) {
      for (const item of parseXmlCandidates(response.text, response.url)) {
        if (sameHost(source.url, item.url) && (!candidates.has(item.url) || item.score > candidates.get(item.url)!.score)) {
          candidates.set(item.url, item);
        }
      }
      return;
    }

    const document = parse5.parse(response.text);
    for (const feedUrl of collectFeedUrls(document, response.url)) {
      if (feedUrls.size < MAX_FEED_URLS_PER_SOURCE + 2) feedUrls.add(feedUrl);
    }
    const anchors = findAll(document, (node) => node?.tagName === 'a');
    for (const anchor of anchors) {
      const href = toAbsoluteUrl(response.url, getAttr(anchor, 'href'));
      if (!href || !sameHost(source.url, href)) continue;
      const title = normalizeText(textContent(anchor) || getAttr(anchor, 'title'));
      const score = scoreWebsiteCandidate(href, title);
      if (score < 8) continue;
      const item = {
        url: href,
        title,
        summary: '',
        publishedAt: null,
        imageUrl: '',
        videoUrl: '',
        mediaUrls: [],
        score,
        originLabel: 'Kaynak haber sayfası',
      };
      const current = candidates.get(href);
      if (!current || score > current.score) candidates.set(href, item);
    }
  };

  for (const url of [...feedUrls].slice(0, MAX_FEED_URLS_PER_SOURCE + 1)) {
    await collectFromUrl(url).catch(() => undefined);
  }

  const parsedItems: AutomaticNewsItemInput[] = [];
  for (const candidate of [...candidates.values()].sort((a, b) => b.score - a.score).slice(0, MAX_CANDIDATES_PER_SOURCE)) {
    const parsed = await parseWebsiteArticle(source, candidate).catch(() => null);
    const item = parsed || itemFromWebsiteCandidate(source, candidate);
    if (isRecentAutomaticNewsItem(item)) parsedItems.push(item);
  }
  return parsedItems;
};

const collectWebsiteLatestItem = async (source: AutomaticNewsSourceRow) => {
  const candidates = new Map<string, WebsiteCandidate>();
  const seedUrls = [
    source.resolved_feed_url || '',
    source.url,
    ...commonFeedUrls(source.url),
  ].filter(Boolean).slice(0, MAX_FEED_URLS_PER_SOURCE + 1);
  const responses = await Promise.allSettled(seedUrls.map((url) => fetchText(url, 2800)));

  for (const result of responses) {
    if (result.status !== 'fulfilled') continue;
    const response = result.value;
    if (looksXml(response.contentType, response.text)) {
      for (const item of parseXmlCandidates(response.text, response.url)) {
        if (sameHost(source.url, item.url) && (!candidates.has(item.url) || item.score > candidates.get(item.url)!.score)) {
          candidates.set(item.url, item);
        }
      }
      continue;
    }

    const document = parse5.parse(response.text);
    const feedUrls = collectFeedUrls(document, response.url).slice(0, 2);
    const feedResponses = await Promise.allSettled(feedUrls.map((url) => fetchText(url, 2400)));
    for (const feedResult of feedResponses) {
      if (feedResult.status !== 'fulfilled') continue;
      for (const item of parseXmlCandidates(feedResult.value.text, feedResult.value.url)) {
        if (sameHost(source.url, item.url) && (!candidates.has(item.url) || item.score > candidates.get(item.url)!.score)) {
          candidates.set(item.url, item);
        }
      }
    }

    for (const anchor of findAll(document, (node) => node?.tagName === 'a')) {
      const href = toAbsoluteUrl(response.url, getAttr(anchor, 'href'));
      if (!href || !sameHost(source.url, href)) continue;
      const title = normalizeText(textContent(anchor) || getAttr(anchor, 'title'));
      const score = scoreWebsiteCandidate(href, title);
      if (score < 8) continue;
      const current = candidates.get(href);
      if (!current || score > current.score) {
        candidates.set(href, {
          url: href,
          title,
          summary: '',
          publishedAt: null,
          imageUrl: '',
          videoUrl: '',
          mediaUrls: [],
          score,
          originLabel: 'Kaynak son içerik',
        });
      }
    }
  }

  const latestCandidates = [...candidates.values()]
    .filter((candidate) => isGoodNewsTitle(candidate.title))
    .sort((a, b) => {
      const dateA = a.publishedAt ? Date.parse(a.publishedAt) || 0 : 0;
      const dateB = b.publishedAt ? Date.parse(b.publishedAt) || 0 : 0;
      if (dateA !== dateB) return dateB - dateA;
      return b.score - a.score;
    })
    .slice(0, MAX_CANDIDATES_PER_SOURCE);
  if (!latestCandidates.length) return null;

  for (const candidate of latestCandidates) {
    const item = await withTimeout(parseWebsiteArticle(source, candidate), 3600, source.display_name)
      .catch(() => null) || itemFromWebsiteCandidate(source, candidate);
    if (isRecentAutomaticNewsItem(item)) return item;
  }
  return null;
};

const instagramCaption = (node: any) =>
  normalizeText(node?.edge_media_to_caption?.edges?.[0]?.node?.text || '');

const instagramTitleFromCaption = (caption: string, sourceName: string) => {
  const line = caption
    .split(/\n+/)
    .map((item) => normalizeText(item).replace(/^[^\p{L}\p{N}]+/u, '').replace(/[^\p{L}\p{N}]+$/u, ''))
    .find((item) => item.replace(/[^\p{L}\p{N}]/gu, '').length >= 18);
  return (line || `${sourceName} Instagram yeni haber paylaşımı`).slice(0, 180);
};

const addInstagramImageUrl = (images: string[], value: unknown) => {
  const url = normalizeText(value);
  if (!/^https?:\/\//i.test(url)) return;
  const key = url.replace(/[?#].*$/, '');
  if (!images.some((item) => item.replace(/[?#].*$/, '') === key)) {
    images.push(url);
  }
};

const collectInstagramMediaImages = (node: any) => {
  const images: string[] = [];
  const addNodeImage = (mediaNode: any) => {
    const resources = Array.isArray(mediaNode?.display_resources)
      ? mediaNode.display_resources
      : [];
    addInstagramImageUrl(
      images,
      resources[resources.length - 1]?.src ||
        mediaNode?.display_url ||
        mediaNode?.thumbnail_src,
    );
  };

  addNodeImage(node);
  const sidecarEdges = Array.isArray(node?.edge_sidecar_to_children?.edges)
    ? node.edge_sidecar_to_children.edges
    : [];
  for (const edge of sidecarEdges) {
    addNodeImage(edge?.node);
  }
  return images.slice(0, 12);
};

const collectInstagramItems = async (source: AutomaticNewsSourceRow) => {
  const username = instagramUsernameFromUrl(source.url);
  if (!username) return [];
  const response = await fetch(
    `https://www.instagram.com/api/v1/users/web_profile_info/?username=${encodeURIComponent(username)}`,
    {
      signal: AbortSignal.timeout(SOURCE_FETCH_TIMEOUT_MS),
      headers: {
        Accept: 'application/json',
        Referer: `https://www.instagram.com/${username}/`,
        'User-Agent': 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/125.0 Safari/537.36',
        'x-ig-app-id': INSTAGRAM_WEB_APP_ID,
      },
    },
  );
  if (!response.ok) throw new Error(`Instagram ${username} HTTP ${response.status}`);
  const data = await readJsonLimited(response);
  const edges: any[] = Array.isArray(data?.data?.user?.edge_owner_to_timeline_media?.edges)
    ? data.data.user.edge_owner_to_timeline_media.edges
    : [];

  return edges
    .map((edge: any): AutomaticNewsItemInput | null => {
      const node = edge?.node || {};
      const shortcode = normalizeText(node.shortcode);
      const caption = instagramCaption(node);
      const title = instagramTitleFromCaption(caption, source.display_name);
      if (!shortcode || !isGoodNewsTitle(title)) return null;
      const sourceUrl = `https://www.instagram.com/p/${shortcode}/`;
      const summary = summaryFor(caption, caption, title);
      const qualityScore = qualityForText(title, summary, caption, 'instagram');
      if (qualityScore < 58) return null;
      const publishedAt = Number(node.taken_at_timestamp || 0)
        ? new Date(Number(node.taken_at_timestamp) * 1000).toISOString()
        : null;
      const mediaImages = collectInstagramMediaImages(node);
      const videoUrl = Boolean(node.is_video)
        ? normalizeText(node.video_url) || sourceUrl
        : '';
      const mediaUrls = mediaUrlsFor(mediaImages[0] || normalizeText(node.display_url), videoUrl, mediaImages);
      return {
        source,
        sourceUrl,
        canonicalUrl: sourceUrl,
        externalId: shortcode,
        title,
        summary,
        contentText: caption.slice(0, 12000),
        category: categoryForText(`${title} ${caption}`),
        status: qualityScore >= 78 ? 'Hazır' : 'İncele',
        originLabel: 'Instagram gönderisi',
        qualityScore,
        imageUrl: mediaImages[0] || normalizeText(node.display_url),
        videoUrl,
        mediaUrls,
        publishedAt,
        dateConfidence: dateConfidenceFor(publishedAt),
        discoveredAt: discoveredAtNow(),
        rawPayload: {
          instagramUsername: username,
          instagramShortcode: shortcode,
          isVideo: Boolean(node.is_video),
          videoUrl,
          mediaImages,
          mediaUrls,
        },
      } satisfies AutomaticNewsItemInput;
    })
    .filter((item): item is AutomaticNewsItemInput => Boolean(item))
    .filter(isRecentAutomaticNewsItem)
    .slice(0, MAX_CANDIDATES_PER_SOURCE);
};

const collectSourceItems = (source: AutomaticNewsSourceRow) => {
  if (source.source_type === 'instagram') return collectInstagramItems(source);
  if (isNigdeAnadoluSource(source)) return collectNigdeAnadoluItems(source);
  return collectWebsiteItems(source);
};

const collectSourceLatestItem = async (source: AutomaticNewsSourceRow) => {
  if (source.source_type === 'instagram') {
    return (await collectInstagramItems(source))[0] || null;
  }
  if (isNigdeAnadoluSource(source)) {
    return (await collectNigdeAnadoluItems(source))[0] || null;
  }
  return collectWebsiteLatestItem(source);
};

const normalizeComparableUrl = (value: string) => {
  const url = normalizeText(value);
  if (!url) return '';
  try {
    const parsed = new URL(url);
    parsed.hash = '';
    parsed.hostname = parsed.hostname.toLowerCase().replace(/^www\./, '');
    for (const key of [...parsed.searchParams.keys()]) {
      if (/^(utm_|fbclid|igshid|mc_)/i.test(key)) parsed.searchParams.delete(key);
    }
    let output = parsed.toString();
    output = output.replace(/\/+(\?|$)/, '$1');
    return output;
  } catch {
    return url.replace(/[?#].*$/, '').replace(/\/+$/, '').toLocaleLowerCase('tr-TR');
  }
};

const mediaComparisonUrls = (item: Pick<AutomaticNewsItemInput, 'imageUrl' | 'videoUrl' | 'mediaUrls'>) => {
  const urls = new Set<string>();
  for (const url of [item.imageUrl, item.videoUrl, ...(item.mediaUrls || [])]) {
    const normalized = normalizeComparableUrl(url);
    if (normalized) urls.add(normalized);
  }
  return [...urls];
};

const duplicateStopWords = new Set([
  'bir',
  'ile',
  'icin',
  'için',
  'olan',
  'olarak',
  'son',
  'dakika',
  'haber',
  'haberi',
  'iste',
  'işte',
  've',
  'veya',
  'da',
  'de',
  'mi',
  'mu',
  'mı',
  'mü',
  'bu',
  'su',
  'şu',
]);

const duplicateTokens = (value: string) => {
  const normalized = trLower(value)
    .replace(/[^\p{L}\p{N}]+/gu, ' ')
    .split(/\s+/)
    .map((item) => item.trim())
    .filter((item) => item.length >= 3 && !duplicateStopWords.has(item));
  return [...new Set(normalized)].slice(0, 160);
};

const tokenSimilarity = (left: string[], right: string[]) => {
  if (!left.length || !right.length) return 0;
  const rightSet = new Set(right);
  const intersection = left.filter((item) => rightSet.has(item)).length;
  const union = new Set([...left, ...right]).size;
  return union ? intersection / union : 0;
};

const importantDuplicateTokens = (value: string) =>
  duplicateTokens(value).filter((token) =>
    /\d/.test(token) ||
    /(niğde|nigde|bor|çamardı|camardi|çiftlik|ciftlik|ulukışla|ulukisla|altunhisar|emniyet|jandarma|belediye|valilik|kaza|yangın|yangin|operasyon|gözaltı|gozalti|vefat|ihale|okul|hastane)/i.test(token)
  );

const dateDistanceHours = (a: string | null, b: string | null) => {
  if (!a || !b) return null;
  const left = Date.parse(a);
  const right = Date.parse(b);
  if (!Number.isFinite(left) || !Number.isFinite(right)) return null;
  return Math.abs(left - right) / 36e5;
};

const emptyDuplicateMatch = (): DuplicateMatch => ({
  state: 'none',
  score: 0,
  matchTable: '',
  matchId: '',
  matchSource: '',
  matchTitle: '',
  matchUrl: '',
  reason: '',
});

const rowMediaUrls = (row: DuplicateCandidateRow) => {
  const values: string[] = [];
  for (const value of [row.image_url, row.video_url]) {
    const normalized = normalizeComparableUrl(value);
    if (normalized) values.push(normalized);
  }
  if (Array.isArray(row.media_urls)) {
    for (const value of row.media_urls) {
      const normalized = normalizeComparableUrl(String(value || ''));
      if (normalized) values.push(normalized);
    }
  }
  return [...new Set(values)];
};

const duplicateMatchFromRow = (
  state: DuplicateState,
  score: number,
  row: DuplicateCandidateRow,
  reason: string,
): DuplicateMatch => ({
  state,
  score,
  matchTable: row.record_type,
  matchId: row.id,
  matchSource: row.source_label,
  matchTitle: row.title,
  matchUrl: row.canonical_url || row.source_url,
  reason,
});

const compareDuplicateCandidate = (
  item: AutomaticNewsItemInput,
  row: DuplicateCandidateRow,
  itemUrlSet: Set<string>,
  itemMediaSet: Set<string>,
): DuplicateMatch => {
  const rowUrls = [row.canonical_url, row.source_url]
    .map(normalizeComparableUrl)
    .filter(Boolean);
  if (rowUrls.some((url) => itemUrlSet.has(url))) {
    return duplicateMatchFromRow('exact', 100, row, 'Aynı haber URL adresi');
  }

  const rowMedia = rowMediaUrls(row);
  if (itemMediaSet.size > 0 && rowMedia.some((url) => itemMediaSet.has(url))) {
    return duplicateMatchFromRow('exact', 100, row, 'Aynı görsel/video medya adresi');
  }

  const itemTitleFingerprint = titleFingerprint(item.title);
  const rowTitleFingerprint = titleFingerprint(row.title);
  const itemBody = `${item.title} ${item.summary} ${item.contentText}`;
  const rowBody = `${row.title} ${row.summary} ${row.content_text}`;
  const titleScore = tokenSimilarity(duplicateTokens(item.title), duplicateTokens(row.title));
  const bodyScore = tokenSimilarity(duplicateTokens(itemBody), duplicateTokens(rowBody));
  const importantScore = tokenSimilarity(importantDuplicateTokens(itemBody), importantDuplicateTokens(rowBody));
  const distance = dateDistanceHours(item.publishedAt || item.discoveredAt, row.published_at || row.captured_at);
  const closeDate = distance == null || distance <= 72;

  if (
    itemTitleFingerprint === rowTitleFingerprint &&
    closeDate &&
    (bodyScore >= 0.58 || item.summary.length < 30 || row.summary.length < 30)
  ) {
    return duplicateMatchFromRow('exact', 98, row, 'Aynı başlık parmak izi ve uyumlu içerik');
  }

  const score = Math.round(
    Math.min(100, (titleScore * 52) + (bodyScore * 34) + (importantScore * 14) + (closeDate ? 6 : 0)),
  );
  if (score >= 82 && titleScore >= 0.54 && bodyScore >= 0.38) {
    return duplicateMatchFromRow('possible', score, row, 'Başlık/metin/olay benzerliği');
  }

  return emptyDuplicateMatch();
};

const selectBestDuplicateMatch = (matches: DuplicateMatch[]) => {
  const exact = matches
    .filter((match) => match.state === 'exact')
    .sort((a, b) => b.score - a.score)[0];
  if (exact) return exact;
  return matches
    .filter((match) => match.state === 'possible')
    .sort((a, b) => b.score - a.score)[0] || emptyDuplicateMatch();
};

const duplicateCandidateRows = async (
  item: AutomaticNewsItemInput,
  canonicalUrlHash: string,
  sourceUrlHash: string,
) => {
  const urls = [item.canonicalUrl, item.sourceUrl]
    .map(normalizeComparableUrl)
    .filter(Boolean);
  const mediaUrls = mediaComparisonUrls(item);
  const publishedAt = item.publishedAt || item.discoveredAt;
  const titleLike = `%${normalizeText(item.title).slice(0, 80)}%`;

  const automaticExact = await dbQuery<DuplicateCandidateRow>(
    `SELECT
       'automatic'::text AS record_type,
       id::text,
       source_name AS source_label,
       title,
       summary,
       content_text,
       published_at,
       captured_at,
       canonical_url,
       source_url,
       image_url,
       video_url,
       media_urls
     FROM public.automatic_news_items
     WHERE canonical_url_hash = ANY($1::text[])
        OR source_url_hash = ANY($1::text[])
        OR canonical_url = ANY($2::text[])
        OR source_url = ANY($2::text[])
        OR image_url = ANY($3::text[])
        OR video_url = ANY($3::text[])
        OR media_urls ?| $3::text[]
     ORDER BY captured_at DESC
     LIMIT 20`,
    [[canonicalUrlHash, sourceUrlHash].filter(Boolean), urls, mediaUrls],
  );

  const automaticRecent = await dbQuery<DuplicateCandidateRow>(
    `SELECT
       'automatic'::text AS record_type,
       id::text,
       source_name AS source_label,
       title,
       summary,
       content_text,
       published_at,
       captured_at,
       canonical_url,
       source_url,
       image_url,
       video_url,
       media_urls
     FROM public.automatic_news_items
     WHERE captured_at >= COALESCE($1::timestamptz, now()) - interval '10 days'
       AND captured_at <= COALESCE($1::timestamptz, now()) + interval '1 day'
     ORDER BY captured_at DESC
     LIMIT 160`,
    [publishedAt],
  );

  const posts = await dbQuery<DuplicateCandidateRow>(
    `SELECT
       'post'::text AS record_type,
       id::text,
       'Pateez haberleri'::text AS source_label,
       title,
       summary,
       regexp_replace(COALESCE(content, ''), '<[^>]+>', ' ', 'g') AS content_text,
       published_at,
       created_at AS captured_at,
       CASE WHEN COALESCE(slug, '') <> '' THEN '/' || slug ELSE '' END AS canonical_url,
       ''::text AS source_url,
       thumbnail_url AS image_url,
       media_url AS video_url,
       jsonb_build_array(thumbnail_url, media_url) AS media_urls
     FROM public.posts
     WHERE deleted_at IS NULL
       AND created_at >= COALESCE($1::timestamptz, now()) - interval '30 days'
       AND created_at <= COALESCE($1::timestamptz, now()) + interval '1 day'
       AND (
         title ILIKE $2
         OR thumbnail_url = ANY($3::text[])
         OR media_url = ANY($3::text[])
         OR published_at >= COALESCE($1::timestamptz, now()) - interval '10 days'
       )
     ORDER BY created_at DESC
     LIMIT 180`,
    [publishedAt, titleLike, mediaUrls],
  );

  const rows = new Map<string, DuplicateCandidateRow>();
  for (const row of [...automaticExact.rows, ...automaticRecent.rows, ...posts.rows]) {
    rows.set(`${row.record_type}:${row.id}`, row);
  }
  return [...rows.values()];
};

const checkAutomaticNewsDuplicate = async (
  item: AutomaticNewsItemInput,
  canonicalUrlHash: string,
  sourceUrlHash: string,
) => {
  const rows = await duplicateCandidateRows(item, canonicalUrlHash, sourceUrlHash);
  if (!rows.length) return emptyDuplicateMatch();
  const itemUrls = new Set(
    [item.canonicalUrl, item.sourceUrl]
      .map(normalizeComparableUrl)
      .filter(Boolean),
  );
  const itemMedia = new Set(mediaComparisonUrls(item));
  return selectBestDuplicateMatch(
    rows.map((row) => compareDuplicateCandidate(item, row, itemUrls, itemMedia)),
  );
};

const insertAutomaticNewsItem = async (item: AutomaticNewsItemInput) => {
  const canonicalUrlHash = item.canonicalUrl ? hash(item.canonicalUrl) : '';
  const sourceUrlHash = item.sourceUrl ? hash(item.sourceUrl) : '';
  const duplicateMatch = await checkAutomaticNewsDuplicate(item, canonicalUrlHash, sourceUrlHash);
  if (duplicateMatch.state === 'exact') return false;
  const finalItem = duplicateMatch.state === 'possible'
    ? {
        ...item,
        status: 'İncele',
        rawPayload: {
          ...(item.rawPayload || {}),
          duplicateCheck: duplicateMatch,
        },
      }
    : item;
  const detectedAt = Date.parse(item.discoveredAt);
  const publishedAt = item.publishedAt ? Date.parse(item.publishedAt) : NaN;
  const detectionLatencySeconds = Number.isFinite(detectedAt) && Number.isFinite(publishedAt)
    ? Math.max(0, Math.floor((detectedAt - publishedAt) / 1000))
    : null;
  const result = await dbQuery<{ id: string }>(
    `INSERT INTO public.automatic_news_items
       (source_id, source_name, source_type, source_url, canonical_url, external_id,
        title, title_fingerprint, summary, content_text, category, status, language_code,
        origin_label, quality_score, image_url, video_url, published_at, discovered_at,
        date_confidence, media_urls, canonical_url_hash, source_url_hash,
        detection_latency_seconds, duplicate_state, duplicate_score, duplicate_match_table,
        duplicate_match_id, duplicate_match_source, duplicate_match_title, duplicate_match_url,
        duplicate_reason, duplicate_checked_at, raw_payload)
     VALUES
       ($1, $2, $3, $4, $5, $6,
        $7, $8, $9, $10, $11, $12, 'tr',
        $13, $14, $15, $16, $17, $18,
        $19, $20::jsonb, $21, $22,
        $23, $24, $25, $26,
        $27, $28, $29, $30,
        $31, now(), $32::jsonb)
     ON CONFLICT DO NOTHING
     RETURNING id`,
    [
      finalItem.source.id,
      finalItem.source.display_name,
      finalItem.source.source_type,
      finalItem.sourceUrl,
      finalItem.canonicalUrl,
      finalItem.externalId,
      finalItem.title,
      titleFingerprint(finalItem.title),
      finalItem.summary,
      finalItem.contentText,
      finalItem.category,
      finalItem.status,
      finalItem.originLabel,
      finalItem.qualityScore,
      finalItem.imageUrl,
      finalItem.videoUrl,
      finalItem.publishedAt,
      finalItem.discoveredAt,
      finalItem.dateConfidence,
      JSON.stringify(finalItem.mediaUrls || []),
      canonicalUrlHash,
      sourceUrlHash,
      detectionLatencySeconds,
      duplicateMatch.state === 'possible' ? 'possible' : 'none',
      duplicateMatch.state === 'possible' ? duplicateMatch.score : 0,
      duplicateMatch.state === 'possible' ? duplicateMatch.matchTable : '',
      duplicateMatch.state === 'possible' ? duplicateMatch.matchId : '',
      duplicateMatch.state === 'possible' ? duplicateMatch.matchSource : '',
      duplicateMatch.state === 'possible' ? duplicateMatch.matchTitle : '',
      duplicateMatch.state === 'possible' ? duplicateMatch.matchUrl : '',
      duplicateMatch.state === 'possible' ? duplicateMatch.reason : '',
      JSON.stringify({
        ...(finalItem.rawPayload || {}),
        mediaUrls: finalItem.mediaUrls || [],
        dateConfidence: finalItem.dateConfidence,
      }),
    ],
  );
  return (result.rowCount || 0) > 0;
};

const latestDetectionLatency = (items: AutomaticNewsItemInput[]) => {
  const latencies = items
    .map((item) => {
      const publishedAt = item.publishedAt ? Date.parse(item.publishedAt) : NaN;
      const discoveredAt = Date.parse(item.discoveredAt);
      return Number.isFinite(publishedAt) && Number.isFinite(discoveredAt)
        ? Math.max(0, Math.floor((discoveredAt - publishedAt) / 1000))
        : null;
    })
    .filter((value): value is number => value != null);
  return latencies.length ? Math.min(...latencies) : null;
};

const markSourceChecked = async (
  sourceId: string,
  startedAt: number,
  errorMessage = '',
  detectedLatencySeconds: number | null = null,
) => {
  const durationMs = Math.max(0, Date.now() - startedAt);
  await dbQuery(
    `UPDATE public.automatic_news_sources
     SET
       last_checked_at = now(),
       last_finished_at = now(),
       last_success_at = CASE WHEN $2 = '' THEN now() ELSE last_success_at END,
       last_error = NULLIF($2, ''),
       lease_owner = NULL,
       lease_expires_at = NULL,
       consecutive_failures = CASE WHEN $2 = '' THEN 0 ELSE consecutive_failures + 1 END,
       health_state = CASE
         WHEN $2 = '' THEN CASE WHEN health_state = 'disabled' THEN 'disabled' ELSE 'active' END
         WHEN consecutive_failures + 1 >= 3 THEN 'watch'
         ELSE health_state
       END,
       last_duration_ms = $3,
       last_detected_latency_seconds = COALESCE($4, last_detected_latency_seconds),
       updated_at = now()
     WHERE id = $1`,
    [sourceId, errorMessage.slice(0, 500), durationMs, detectedLatencySeconds],
  );
};

const claimAutomaticNewsSources = async (options: {
  force?: boolean;
  sourceId?: string;
  limit?: number;
  leaseOwner?: string;
}) => {
  const leaseOwner = options.leaseOwner || `auto-news-${crypto.randomUUID()}`;
  const result = await dbQuery<AutomaticNewsSourceRow>(
    `WITH due AS (
       SELECT id
       FROM public.automatic_news_sources
       WHERE is_active = true
         AND COALESCE(health_state, 'active') <> 'disabled'
         AND ($1::uuid IS NULL OR id = $1::uuid)
         AND ($2::boolean OR next_poll_at IS NULL OR next_poll_at <= now())
         AND (lease_expires_at IS NULL OR lease_expires_at <= now())
       ORDER BY
         COALESCE(priority, 100) ASC,
         next_poll_at NULLS FIRST,
         last_checked_at NULLS FIRST,
         sort_order ASC,
         created_at ASC
       LIMIT $3
       FOR UPDATE SKIP LOCKED
     )
     UPDATE public.automatic_news_sources AS source
     SET
       lease_owner = $4,
       lease_expires_at = now() + make_interval(secs => $5),
       last_started_at = now(),
       next_poll_at = now() + make_interval(mins => poll_interval_minutes),
       updated_at = now()
     FROM due
     WHERE source.id = due.id
     RETURNING source.*`,
    [
      options.sourceId || null,
      options.force === true,
      Math.min(Math.max(Number(options.limit || MAX_SOURCES_PER_RUN), 1), 120),
      leaseOwner,
      SOURCE_LEASE_SECONDS,
    ],
  );
  return result.rows;
};

const processSource = async (
  source: AutomaticNewsSourceRow,
  options: ProcessSourceOptions = {},
): Promise<ProcessSourceResult> => {
  const startedAt = Date.now();
  try {
    const collectedItems = await collectSourceItems(source);
    const items = filterItemsByAutomationWindow(collectedItems, options.enabledAt);
    let insertedCount = 0;
    let skippedDuplicateCount = 0;
    for (const item of items) {
      if (await insertAutomaticNewsItem(item)) {
        insertedCount += 1;
      } else {
        skippedDuplicateCount += 1;
      }
    }
    await markSourceChecked(source.id, startedAt, '', latestDetectionLatency(items));
    return {
      sourceId: source.id,
      sourceName: source.display_name,
      sourceUrl: source.url,
      candidatesFound: collectedItems.length,
      insertedCount,
      skippedDuplicateCount: skippedDuplicateCount + (collectedItems.length - items.length),
      errorMessage: '',
    };
  } catch (error: any) {
    const message = normalizeText(error?.message || 'kaynak taranamadı');
    await markSourceChecked(source.id, startedAt, message);
    return {
      sourceId: source.id,
      sourceName: source.display_name,
      sourceUrl: source.url,
      candidatesFound: 0,
      insertedCount: 0,
      skippedDuplicateCount: 0,
      errorMessage: message,
    };
  }
};

const processQueueSourceMessage = async (body: AutomaticNewsQueueMessage) => {
  const settings = await getAutomaticNewsAutomationSettings();
  if (!settings.enabled) return null;
  const processingOwner = `queue-${crypto.randomUUID()}`;
  const claimed = await dbQuery<AutomaticNewsSourceRow>(
    `UPDATE public.automatic_news_sources
     SET
       lease_owner = $2,
       lease_expires_at = now() + make_interval(secs => $4),
       updated_at = now()
     WHERE id = $1
       AND lease_owner = $3
       AND (lease_expires_at IS NULL OR lease_expires_at > now())
     RETURNING *`,
    [body.sourceId, processingOwner, body.leaseOwner, SOURCE_LEASE_SECONDS],
  );
  const source = claimed.rows[0];
  if (!source) return null;
  return processSource(source, { enabledAt: settings.enabledAt || body.enabledAt || null });
};

const restoreQueueLeaseForRetry = async (body: AutomaticNewsQueueMessage) => {
  await dbQuery(
    `UPDATE public.automatic_news_sources
     SET
       lease_owner = $2,
       lease_expires_at = now() + make_interval(secs => $3),
       next_poll_at = now(),
       updated_at = now()
     WHERE id = $1`,
    [body.sourceId, body.leaseOwner, SOURCE_LEASE_SECONDS],
  );
};

const processSourceFastTest = async (source: AutomaticNewsSourceRow): Promise<ProcessSourceResult> => {
  try {
    const item = await withTimeout(collectSourceLatestItem(source), 8500, source.display_name);
    if (!item) {
      const message = 'Son içerik bulunamadı';
      return {
        sourceId: source.id,
        sourceName: source.display_name,
        sourceUrl: source.url,
        candidatesFound: 0,
        insertedCount: 0,
        skippedDuplicateCount: 0,
        errorMessage: message,
      };
    }

    return {
      sourceId: source.id,
      sourceName: source.display_name,
      sourceUrl: source.url,
      latestTitle: item.title,
      latestUrl: item.canonicalUrl || item.sourceUrl,
      candidatesFound: 1,
      insertedCount: 0,
      skippedDuplicateCount: 0,
      errorMessage: '',
    };
  } catch (error: any) {
    const message = normalizeText(error?.message || 'kaynak test edilemedi');
    return {
      sourceId: source.id,
      sourceName: source.display_name,
      sourceUrl: source.url,
      candidatesFound: 0,
      insertedCount: 0,
      skippedDuplicateCount: 0,
      errorMessage: message,
    };
  }
};

const mapLimited = async <T, R>(items: T[], limit: number, worker: (item: T) => Promise<R>) => {
  const results = new Array<R>(items.length);
  let index = 0;
  await Promise.all(
    Array.from({ length: Math.min(limit, items.length) }, async () => {
      while (index < items.length) {
        const currentIndex = index;
        index += 1;
        results[currentIndex] = await worker(items[currentIndex]);
      }
    }),
  );
  return results;
};

export async function runAutomaticNewsRefresh(options: RefreshOptions = {}) {
  const automationSettings = await getAutomaticNewsAutomationSettings();
  if (!automationSettings.enabled) {
    return {
      runId: '',
      status: 'disabled',
      checkedSources: 0,
      candidatesFound: 0,
      insertedCount: 0,
      skippedDuplicateCount: 0,
      errorCount: 0,
      errors: [],
    };
  }
  const runType = options.runType || 'manual';
  const runResult = await dbQuery<{ id: string }>(
    `INSERT INTO public.automatic_news_runs (run_type, status)
     VALUES ($1, 'running')
     RETURNING id`,
    [runType],
  );
  const runId = runResult.rows[0]?.id;

  try {
    const sources = await claimAutomaticNewsSources({
      force: options.force,
      sourceId: options.sourceId,
      limit: MAX_SOURCES_PER_RUN,
      leaseOwner: `manual-${runId || crypto.randomUUID()}`,
    });

    const sourceResults = await mapLimited(sources, DEFAULT_SOURCE_CONCURRENCY, (source) =>
      processSource(source, { enabledAt: automationSettings.enabledAt })
    );
    const totals = sourceResults.reduce(
      (sum, item) => ({
        checkedSources: sum.checkedSources + 1,
        candidatesFound: sum.candidatesFound + item.candidatesFound,
        insertedCount: sum.insertedCount + item.insertedCount,
        skippedDuplicateCount: sum.skippedDuplicateCount + item.skippedDuplicateCount,
        errorCount: sum.errorCount + (item.errorMessage ? 1 : 0),
      }),
      {
        checkedSources: 0,
        candidatesFound: 0,
        insertedCount: 0,
        skippedDuplicateCount: 0,
        errorCount: 0,
      },
    );
    const errors = sourceResults
      .filter((item) => item.errorMessage)
      .map((item) => ({
        sourceId: item.sourceId,
        sourceName: item.sourceName,
        sourceUrl: item.sourceUrl,
        message: item.errorMessage,
      }));
    const status = totals.errorCount === 0 ? 'success' : totals.errorCount === totals.checkedSources && totals.checkedSources > 0 ? 'error' : 'partial';

    await dbQuery(
      `UPDATE public.automatic_news_runs
       SET
         status = $2,
         finished_at = now(),
         checked_sources = $3,
         candidates_found = $4,
         inserted_count = $5,
         skipped_duplicate_count = $6,
         error_count = $7,
         error_message = $8,
         details = $9::jsonb
       WHERE id = $1`,
      [
        runId,
        status,
        totals.checkedSources,
        totals.candidatesFound,
        totals.insertedCount,
        totals.skippedDuplicateCount,
        totals.errorCount,
        errors[0]?.message || null,
        JSON.stringify({ errors }),
      ],
    );

    return {
      runId,
      status,
      ...totals,
      errors,
    };
  } catch (error: any) {
    const message = normalizeText(error?.message || 'otomatik haber yenileme başarısız');
    if (runId) {
      await dbQuery(
        `UPDATE public.automatic_news_runs
         SET status = 'error', finished_at = now(), error_count = 1, error_message = $2
         WHERE id = $1`,
        [runId, message.slice(0, 500)],
      );
    }
    throw error;
  }
}

export async function dispatchAutomaticNewsDueSources(options: {
  queue?: Queue<AutomaticNewsQueueMessage>;
  runType?: 'cron' | 'manual';
  limit?: number;
} = {}) {
  const automationSettings = await getAutomaticNewsAutomationSettings();
  if (!automationSettings.enabled) {
    return {
      runId: '',
      status: 'disabled',
      checkedSources: 0,
      candidatesFound: 0,
      insertedCount: 0,
      skippedDuplicateCount: 0,
      errorCount: 0,
      errors: [],
      queuedCount: 0,
    };
  }
  const runType = options.runType || 'cron';
  const runResult = await dbQuery<{ id: string }>(
    `INSERT INTO public.automatic_news_runs (run_type, status)
     VALUES ($1, 'running')
     RETURNING id`,
    [runType],
  );
  const runId = String(runResult.rows[0]?.id || '');
  const leaseOwner = `dispatch-${runId || crypto.randomUUID()}`;

  try {
    const sources = await claimAutomaticNewsSources({
      limit: options.limit || MAX_SOURCES_PER_RUN,
      leaseOwner,
    });

    if (options.queue && sources.length > 0) {
      for (let index = 0; index < sources.length; index += DISPATCH_BATCH_SIZE) {
        const chunk = sources.slice(index, index + DISPATCH_BATCH_SIZE);
        await options.queue.sendBatch(
          chunk.map((source) => ({
            body: {
              sourceId: source.id,
              scheduledAt: new Date().toISOString(),
              traceId: crypto.randomUUID(),
              leaseOwner,
              enabledAt: automationSettings.enabledAt,
              runId,
            },
            contentType: 'json' as const,
          })),
        );
      }
      await dbQuery(
        `UPDATE public.automatic_news_runs
         SET
           status = 'success',
           finished_at = now(),
           checked_sources = $2,
           details = $3::jsonb
         WHERE id = $1`,
        [
          runId,
          sources.length,
          JSON.stringify({
            queued: sources.length,
            queue: 'pateeznews-automatic-news',
          }),
        ],
      );
      return {
        runId,
        status: 'success',
        checkedSources: sources.length,
        candidatesFound: 0,
        insertedCount: 0,
        skippedDuplicateCount: 0,
        errorCount: 0,
        errors: [],
        queuedCount: sources.length,
      };
    }

    const sourceResults = await mapLimited(sources, DEFAULT_SOURCE_CONCURRENCY, (source) =>
      processSource(source, { enabledAt: automationSettings.enabledAt })
    );
    const totals = sourceResults.reduce(
      (sum, item) => ({
        checkedSources: sum.checkedSources + 1,
        candidatesFound: sum.candidatesFound + item.candidatesFound,
        insertedCount: sum.insertedCount + item.insertedCount,
        skippedDuplicateCount: sum.skippedDuplicateCount + item.skippedDuplicateCount,
        errorCount: sum.errorCount + (item.errorMessage ? 1 : 0),
      }),
      {
        checkedSources: 0,
        candidatesFound: 0,
        insertedCount: 0,
        skippedDuplicateCount: 0,
        errorCount: 0,
      },
    );
    const errors = sourceResults
      .filter((item) => item.errorMessage)
      .map((item) => ({
        sourceId: item.sourceId,
        sourceName: item.sourceName,
        sourceUrl: item.sourceUrl,
        message: item.errorMessage,
      }));
    const status = totals.errorCount === 0 ? 'success' : totals.errorCount === totals.checkedSources && totals.checkedSources > 0 ? 'error' : 'partial';
    await dbQuery(
      `UPDATE public.automatic_news_runs
       SET
         status = $2,
         finished_at = now(),
         checked_sources = $3,
         candidates_found = $4,
         inserted_count = $5,
         skipped_duplicate_count = $6,
         error_count = $7,
         error_message = $8,
         details = $9::jsonb
       WHERE id = $1`,
      [
        runId,
        status,
        totals.checkedSources,
        totals.candidatesFound,
        totals.insertedCount,
        totals.skippedDuplicateCount,
        totals.errorCount,
        errors[0]?.message || null,
        JSON.stringify({ errors, fallback: true }),
      ],
    );
    return {
      runId,
      status,
      ...totals,
      errors,
      queuedCount: 0,
    };
  } catch (error: any) {
    const message = normalizeText(error?.message || 'otomatik haber kuyruğa alınamadı');
    if (runId) {
      await dbQuery(
        `UPDATE public.automatic_news_runs
         SET status = 'error', finished_at = now(), error_count = 1, error_message = $2
         WHERE id = $1`,
        [runId, message.slice(0, 500)],
      );
    }
    throw error;
  }
}

export async function processAutomaticNewsQueueBatch(batch: MessageBatch<AutomaticNewsQueueMessage>) {
  await Promise.all(
    batch.messages.map(async (message) => {
      try {
        const result = await processQueueSourceMessage(message.body);
        if (result?.errorMessage) {
          await restoreQueueLeaseForRetry(message.body);
          message.retry({ delaySeconds: 60 });
          return;
        }
        message.ack();
      } catch (error) {
        console.error('automatic news queue message failed', error);
        await restoreQueueLeaseForRetry(message.body).catch(() => undefined);
        message.retry({ delaySeconds: 60 });
      }
    }),
  );
}

export async function testAutomaticNewsSources() {
  const sources = await dbQuery<AutomaticNewsSourceRow>(
    `SELECT *
     FROM public.automatic_news_sources
     WHERE is_active = true
     ORDER BY source_type, sort_order, display_name
     LIMIT $1`,
    [MAX_SOURCES_PER_RUN],
  );

  const sourceResults = await mapLimited(sources.rows, 12, processSourceFastTest);
  const totals = sourceResults.reduce(
    (sum, item) => ({
      checkedSources: sum.checkedSources + 1,
      candidatesFound: sum.candidatesFound + item.candidatesFound,
      insertedCount: sum.insertedCount + item.insertedCount,
      skippedDuplicateCount: sum.skippedDuplicateCount + item.skippedDuplicateCount,
      errorCount: sum.errorCount + (item.errorMessage ? 1 : 0),
    }),
    {
      checkedSources: 0,
      candidatesFound: 0,
      insertedCount: 0,
      skippedDuplicateCount: 0,
      errorCount: 0,
    },
  );
  const errors = sourceResults
    .filter((item) => item.errorMessage)
    .map((item) => ({
      sourceId: item.sourceId,
      sourceName: item.sourceName,
      sourceUrl: item.sourceUrl,
      message: item.errorMessage,
    }));
  const previews = sourceResults
    .filter((item) => item.latestTitle)
    .map((item) => ({
      sourceId: item.sourceId,
      sourceName: item.sourceName,
      sourceUrl: item.sourceUrl,
      title: item.latestTitle,
      url: item.latestUrl,
      inserted: item.insertedCount > 0,
    }));
  const status = totals.errorCount === 0 ? 'success' : totals.errorCount === totals.checkedSources && totals.checkedSources > 0 ? 'error' : 'partial';

  return {
    runId: null,
    status,
    ...totals,
    errors,
    previews,
  };
}

export async function listAutomaticNewsSources({ includeInactive = true } = {}) {
  const result = await dbQuery<AutomaticNewsSourceRow>(
    `SELECT *
     FROM public.automatic_news_sources
     WHERE $1::boolean OR is_active = true
     ORDER BY sort_order, display_name`,
    [includeInactive],
  );
  return result.rows.map(rowToSource);
}

export async function upsertAutomaticNewsSourcesFromUrls(urls: string[]) {
  const normalized = [...new Set(urls.map(normalizeSourceUrl).filter(Boolean))].slice(0, 100);
  const saved = [];
  for (const url of normalized) {
    const sourceType = sourceTypeFromUrl(url);
    const pollIntervalMinutes = sourceType === 'instagram' ? 2 : 1;
    const priority = sourceType === 'instagram' ? 200 : sourceType === 'rss' ? 20 : 50;
    const result = await dbQuery<AutomaticNewsSourceRow>(
      `INSERT INTO public.automatic_news_sources
         (url, display_name, source_type, is_active, poll_interval_minutes, next_poll_at, priority, updated_at)
       VALUES ($1, $2, $3, true, $4, now(), $5, now())
       ON CONFLICT (url) DO UPDATE
       SET
         display_name = EXCLUDED.display_name,
         source_type = EXCLUDED.source_type,
         is_active = true,
         poll_interval_minutes = EXCLUDED.poll_interval_minutes,
         next_poll_at = LEAST(COALESCE(public.automatic_news_sources.next_poll_at, now()), now()),
         priority = EXCLUDED.priority,
         last_error = NULL,
         updated_at = now()
       RETURNING *`,
      [url, displayNameFromUrl(url), sourceType, pollIntervalMinutes, priority],
    );
    if (result.rows[0]) saved.push(rowToSource(result.rows[0]));
  }
  return saved;
}

export async function syncAutomaticNewsSourcesFromUrls(urls: string[]) {
  const normalized = [...new Set(urls.map(normalizeSourceUrl).filter(Boolean))].slice(0, 120);
  if (normalized.length === 0) {
    throw Object.assign(new Error('En az bir geçerli adres gerekli'), { status: 400 });
  }

  await upsertAutomaticNewsSourcesFromUrls(normalized);
  await dbQuery(
    `UPDATE public.automatic_news_sources
     SET is_active = false, updated_at = now()
     WHERE NOT (url = ANY($1::text[]))`,
    [normalized],
  );
  await dbQuery(
    `UPDATE public.automatic_news_sources
     SET is_active = true, updated_at = now()
     WHERE url = ANY($1::text[])`,
    [normalized],
  );
  return listAutomaticNewsSources({ includeInactive: true });
}

export async function setAutomaticNewsSourceActive(id: string, isActive: boolean) {
  const result = await dbQuery<AutomaticNewsSourceRow>(
    `UPDATE public.automatic_news_sources
     SET
       is_active = $2,
       next_poll_at = CASE WHEN $2 THEN now() ELSE next_poll_at END,
       updated_at = now()
     WHERE id = $1
     RETURNING *`,
    [id, isActive],
  );
  return result.rows[0] ? rowToSource(result.rows[0]) : null;
}

export async function deleteAutomaticNewsSource(id: string) {
  await dbQuery(`DELETE FROM public.automatic_news_sources WHERE id = $1`, [id]);
}

export async function listAutomaticNewsItems(options: {
  search?: string;
  platform?: string;
  category?: string;
  status?: string;
  language?: string;
  page?: number;
  pageSize?: number;
  sortKey?: string;
  sortAscending?: boolean;
} = {}) {
  const params: unknown[] = [];
  const where: string[] = [];
  const addParam = (value: unknown) => {
    params.push(value);
    return `$${params.length}`;
  };
  const search = normalizeText(options.search);
  if (search) {
    const placeholder = addParam(`%${search}%`);
    where.push(`(title ILIKE ${placeholder} OR summary ILIKE ${placeholder} OR source_name ILIKE ${placeholder} OR source_url ILIKE ${placeholder})`);
  }
  const platform = normalizeText(options.platform);
  if (platform && platform !== 'Tümü') {
    const type = platform === 'Instagram' ? 'instagram' : platform === 'RSS' ? 'rss' : platform === 'Web' ? 'website' : platform.toLowerCase();
    where.push(`source_type = ${addParam(type)}`);
  }
  const category = normalizeText(options.category);
  if (category && category !== 'Tümü') where.push(`category = ${addParam(category)}`);
  const status = normalizeText(options.status);
  if (status && status !== 'Tümü') where.push(`status = ${addParam(status)}`);
  const language = normalizeText(options.language);
  if (language && language !== 'Tümü') where.push(`language_code = ${addParam(language.toLowerCase())}`);

  const whereSql = where.length ? `WHERE ${where.join(' AND ')}` : '';
  const orderSql = orderBySql(options.sortKey || 'date', options.sortAscending === true);
  const pageSize = Math.min(Math.max(Number(options.pageSize || 25), 1), 250);
  const page = Math.max(Number(options.page || 1), 1);
  const limitPlaceholder = addParam(pageSize);
  const offsetPlaceholder = addParam((page - 1) * pageSize);

  const countParams = params.slice(0, params.length - 2);
  const countResult = await dbQuery<{ count: number }>(
    `SELECT count(*)::int AS count FROM public.automatic_news_items ${whereSql}`,
    countParams,
  );
  const result = await dbQuery(
    `SELECT *
     FROM public.automatic_news_items
     ${whereSql}
     ORDER BY ${orderSql}
     LIMIT ${limitPlaceholder} OFFSET ${offsetPlaceholder}`,
    params,
  );
  return {
    items: result.rows.map(rowToItem),
    totalCount: Number(countResult.rows[0]?.count || 0),
  };
}

export async function deleteAutomaticNewsItems(ids: string[]) {
  const normalized = [...new Set(ids.map((id) => normalizeText(id)).filter(Boolean))].slice(0, 250);
  if (normalized.length === 0) {
    throw Object.assign(new Error('Silinecek haber seçilmedi'), { status: 400 });
  }
  const result = await dbQuery<{ id: string }>(
    `DELETE FROM public.automatic_news_items
     WHERE id = ANY($1::uuid[])
     RETURNING id`,
    [normalized],
  );
  return {
    deletedCount: result.rowCount || 0,
    ids: result.rows.map((row) => String(row.id)),
  };
}

export async function listAutomaticNewsRuns({ limit = 20 } = {}) {
  const result = await dbQuery(
    `SELECT *
     FROM public.automatic_news_runs
     ORDER BY started_at DESC
     LIMIT $1`,
    [Math.min(Math.max(Number(limit || 20), 1), 50)],
  );
  return result.rows;
}

const orderBySql = (sortKey: string, ascending: boolean) => {
  const direction = ascending ? 'ASC' : 'DESC';
  const nulls = ascending ? 'NULLS FIRST' : 'NULLS LAST';
  const column = ({
    id: 'display_id',
    post: 'title',
    source: 'source_name',
    origin: 'origin_label',
    status: 'status',
    language: 'language_code',
    date: 'captured_at',
  } as Record<string, string>)[sortKey] || 'captured_at';
  return `${column} ${direction} ${nulls}, display_id DESC`;
};

const rowToSource = (row: AutomaticNewsSourceRow) => ({
  id: row.id,
  url: row.url,
  displayName: row.display_name,
  sourceType: row.source_type,
  isActive: row.is_active !== false,
  pollIntervalMinutes: Number(row.poll_interval_minutes || 5),
  lastCheckedAt: row.last_checked_at,
  lastSuccessAt: row.last_success_at,
  lastError: row.last_error || '',
  nextPollAt: row.next_poll_at || null,
  lastStartedAt: row.last_started_at || null,
  lastFinishedAt: row.last_finished_at || null,
  consecutiveFailures: Number(row.consecutive_failures || 0),
  healthState: row.health_state || 'active',
  priority: Number(row.priority || 100),
  lastDurationMs: row.last_duration_ms == null ? null : Number(row.last_duration_ms),
  lastDetectedLatencySeconds: row.last_detected_latency_seconds == null
    ? null
    : Number(row.last_detected_latency_seconds),
});

const displayContentText = (row: any) => {
  const text = String(row.content_text || '');
  return String(row.source_type || '') === 'instagram' ? text : cleanArticleBodyText(text);
};

const rowToItem = (row: any) => ({
  id: String(row.id),
  displayId: Number(row.display_id || 0),
  sourceId: row.source_id ? String(row.source_id) : '',
  sourceName: String(row.source_name || ''),
  sourceType: String(row.source_type || ''),
  sourceUrl: String(row.source_url || ''),
  canonicalUrl: String(row.canonical_url || ''),
  externalId: String(row.external_id || ''),
  title: String(row.title || ''),
  summary: String(row.summary || ''),
  contentText: displayContentText(row),
  category: String(row.category || 'Gündem'),
  status: String(row.status || 'Hazır'),
  languageCode: String(row.language_code || 'tr'),
  originLabel: String(row.origin_label || ''),
  qualityScore: Number(row.quality_score || 0),
  imageUrl: String(row.image_url || ''),
  videoUrl: String(row.video_url || ''),
  mediaUrls: Array.isArray(row.media_urls)
    ? row.media_urls.map((item: unknown) => String(item || '').trim()).filter(Boolean)
    : [],
  dateConfidence: String(row.date_confidence || 'source'),
  duplicateState: String(row.duplicate_state || 'none'),
  duplicateScore: Number(row.duplicate_score || 0),
  duplicateMatchTable: String(row.duplicate_match_table || ''),
  duplicateMatchId: String(row.duplicate_match_id || ''),
  duplicateMatchSource: String(row.duplicate_match_source || ''),
  duplicateMatchTitle: String(row.duplicate_match_title || ''),
  duplicateMatchUrl: String(row.duplicate_match_url || ''),
  duplicateReason: String(row.duplicate_reason || ''),
  publishedAt: row.published_at || null,
  capturedAt: row.captured_at || null,
});
