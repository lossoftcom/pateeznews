import { createHash } from 'node:crypto';
import * as parse5 from 'parse5';
import { dbQuery } from './supabaseDb';

const SOURCE_FETCH_TIMEOUT_MS = 4500;
const DETAIL_FETCH_TIMEOUT_MS = 6500;
const MAX_SOURCES_PER_RUN = 60;
const MAX_CANDIDATES_PER_SOURCE = 8;
const MAX_FEED_URLS_PER_SOURCE = 5;
const MAX_FETCH_BYTES = 2_500_000;
const SOURCE_LEASE_SECONDS = 150;
const DISPATCH_BATCH_SIZE = 25;
const DEFAULT_SOURCE_CONCURRENCY = 8;
const INSTAGRAM_WEB_APP_ID = '936619743392459';
const USER_AGENT = 'Pateez-AutomaticNews/1.0 (+https://www.pateez.com)';
const RECENT_CONTENT_TIME_ZONE = 'Europe/Istanbul';

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
  return collectWebsiteItems(source);
};

const collectSourceLatestItem = async (source: AutomaticNewsSourceRow) => {
  if (source.source_type === 'instagram') {
    return (await collectInstagramItems(source))[0] || null;
  }
  return collectWebsiteLatestItem(source);
};

const insertAutomaticNewsItem = async (item: AutomaticNewsItemInput) => {
  const canonicalUrlHash = item.canonicalUrl ? hash(item.canonicalUrl) : '';
  const sourceUrlHash = item.sourceUrl ? hash(item.sourceUrl) : '';
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
        detection_latency_seconds, raw_payload)
     VALUES
       ($1, $2, $3, $4, $5, $6,
        $7, $8, $9, $10, $11, $12, 'tr',
        $13, $14, $15, $16, $17, $18,
        $19, $20::jsonb, $21, $22,
        $23, $24::jsonb)
     ON CONFLICT DO NOTHING
     RETURNING id`,
    [
      item.source.id,
      item.source.display_name,
      item.source.source_type,
      item.sourceUrl,
      item.canonicalUrl,
      item.externalId,
      item.title,
      titleFingerprint(item.title),
      item.summary,
      item.contentText,
      item.category,
      item.status,
      item.originLabel,
      item.qualityScore,
      item.imageUrl,
      item.videoUrl,
      item.publishedAt,
      item.discoveredAt,
      item.dateConfidence,
      JSON.stringify(item.mediaUrls || []),
      canonicalUrlHash,
      sourceUrlHash,
      detectionLatencySeconds,
      JSON.stringify({
        ...(item.rawPayload || {}),
        mediaUrls: item.mediaUrls || [],
        dateConfidence: item.dateConfidence,
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

const processSource = async (source: AutomaticNewsSourceRow): Promise<ProcessSourceResult> => {
  const startedAt = Date.now();
  try {
    const items = await collectSourceItems(source);
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
      candidatesFound: items.length,
      insertedCount,
      skippedDuplicateCount,
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
  return processSource(source);
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

    const sourceResults = await mapLimited(sources, DEFAULT_SOURCE_CONCURRENCY, processSource);
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

    const sourceResults = await mapLimited(sources, DEFAULT_SOURCE_CONCURRENCY, processSource);
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
  publishedAt: row.published_at || null,
  capturedAt: row.captured_at || null,
});
