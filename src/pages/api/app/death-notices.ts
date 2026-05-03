import type { APIRoute } from 'astro';
import * as parse5 from 'parse5';
import { ensureAppSchema, json } from '@/lib/server/appDb';
import { dbQuery } from '@/lib/server/neonDb';

const SOURCE_URL = 'https://nigde.bel.tr/vefat-edenler';
const FETCH_URL = 'https://vefatedenler.nigde.bel.tr/vefatedenler.php';
const CITY = 'Niğde';
const CITY_SLUG = 'nigde';
const TIMEZONE = 'Europe/Istanbul';
const REFRESH_MS = 30 * 60 * 1000;
const CACHE_KEY = `death_notices:${CITY_SLUG}`;

type DeathNotice = {
  id: string;
  name: string;
  deathDate: string;
  deathDateLabel: string;
  prayerTime: string;
  burialPlace: string;
  description: string;
};

type DeathNoticePayload = {
  city: string;
  citySlug: string;
  source: string;
  sourceUrl: string;
  fetchUrl: string;
  timezone: string;
  serviceDate: string;
  serviceDateLabel: string;
  fetchedAt: string;
  updateIntervalMinutes: number;
  notices: DeathNotice[];
  meta: {
    total: number;
    todayOnly: boolean;
    dateGuard: boolean;
  };
};

let memoryCache: { expiresAt: number; payload: DeathNoticePayload } | null = null;
let refreshInFlight: Promise<DeathNoticePayload> | null = null;

const normalizeText = (value: unknown) =>
  String(value || '')
    .replace(/\u00a0/g, ' ')
    .replace(/[ \t\r\f\v]+/g, ' ')
    .replace(/\n\s+/g, '\n')
    .trim();

const slugify = (value: string) =>
  normalizeText(value)
    .toLocaleLowerCase('tr-TR')
    .normalize('NFD')
    .replace(/[\u0300-\u036f]/g, '')
    .replace(/ı/g, 'i')
    .replace(/ğ/g, 'g')
    .replace(/ü/g, 'u')
    .replace(/ş/g, 's')
    .replace(/ö/g, 'o')
    .replace(/ç/g, 'c')
    .replace(/[^a-z0-9]+/g, '-')
    .replace(/^-+|-+$/g, '');

const textContent = (node: any): string => {
  if (!node) return '';
  if (node.nodeName === '#text') return node.value || '';
  return (node.childNodes || []).map(textContent).join('');
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

const localParts = (date = new Date()) => {
  const parts = new Intl.DateTimeFormat('en-CA', {
    timeZone: TIMEZONE,
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
  }).formatToParts(date);

  const pick = (type: string) => parts.find((part) => part.type === type)?.value || '';
  const year = pick('year');
  const month = pick('month');
  const day = pick('day');
  return {
    year,
    month,
    day,
    dateKey: `${year}-${month}-${day}`,
  };
};

const nextIstanbulMidnight = (date = new Date()) => {
  const parts = localParts(date);
  const todayStart = new Date(`${parts.dateKey}T00:00:00+03:00`).getTime();
  return new Date(todayStart + 24 * 60 * 60 * 1000 + 30 * 1000);
};

const cacheExpiryDate = () => new Date(Math.min(Date.now() + REFRESH_MS, nextIstanbulMidnight().getTime()));

const serviceDateLabel = (date = new Date()) =>
  new Intl.DateTimeFormat('tr-TR', {
    timeZone: TIMEZONE,
    day: 'numeric',
    month: 'long',
    year: 'numeric',
  }).format(date);

const TURKISH_MONTHS: Record<string, string> = {
  ocak: '01',
  şubat: '02',
  subat: '02',
  mart: '03',
  nisan: '04',
  mayıs: '05',
  mayis: '05',
  haziran: '06',
  temmuz: '07',
  ağustos: '08',
  agustos: '08',
  eylül: '09',
  eylul: '09',
  ekim: '10',
  kasım: '11',
  kasim: '11',
  aralık: '12',
  aralik: '12',
};

const parseTurkishDate = (value: string) => {
  const match = normalizeText(value).match(/^(\d{1,2})\s+([A-Za-zÇĞİÖŞÜçğıöşü]+)\s+(\d{4})$/);
  if (!match) return '';
  const day = match[1].padStart(2, '0');
  const monthKey = match[2].toLocaleLowerCase('tr-TR');
  const month = TURKISH_MONTHS[monthKey] || TURKISH_MONTHS[monthKey.normalize('NFD').replace(/[\u0300-\u036f]/g, '')];
  if (!month) return '';
  return `${match[3]}-${month}-${day}`;
};

const parseDeathNotices = (html: string, serviceDate: string): DeathNotice[] => {
  const document = parse5.parse(html);
  const rows = findAll(document, (node) => node?.tagName === 'tr');

  return rows
    .map((row): DeathNotice | null => {
      const cells = (row.childNodes || []).filter((node: any) => node?.tagName === 'td');
      if (cells.length < 5) return null;

      const name = normalizeText(textContent(cells[0])).toLocaleUpperCase('tr-TR');
      const deathDateLabel = normalizeText(textContent(cells[1]));
      const deathDate = parseTurkishDate(deathDateLabel);
      const prayerTime = normalizeText(textContent(cells[2])).toLocaleUpperCase('tr-TR');
      const burialPlace = normalizeText(textContent(cells[3])).toLocaleUpperCase('tr-TR');
      const description = normalizeText(textContent(cells[4]));

      if (!name || !deathDate || deathDate !== serviceDate) return null;

      return {
        id: slugify(`${serviceDate}-${name}-${burialPlace}`),
        name,
        deathDate,
        deathDateLabel,
        prayerTime,
        burialPlace,
        description,
      };
    })
    .filter(Boolean) as DeathNotice[];
};

const ensureCacheSchema = async () => {
  await ensureAppSchema();
};

const readCache = async () => {
  try {
    await ensureCacheSchema();
    const result = await dbQuery<{ payload: any; expires_at: string }>(
      `SELECT payload, expires_at
       FROM public.app_cache
       WHERE key = $1
       LIMIT 1`,
      [CACHE_KEY]
    );
    const row = result.rows[0];
    if (!row?.payload) return null;
    return {
      payload: typeof row.payload === 'string' ? JSON.parse(row.payload) : row.payload,
      expiresAt: new Date(row.expires_at).getTime(),
    };
  } catch {
    return null;
  }
};

const writeCache = async (payload: DeathNoticePayload) => {
  await ensureCacheSchema();
  const expiresAt = cacheExpiryDate().toISOString();
  await dbQuery(
    `INSERT INTO public.app_cache (key, payload, expires_at, updated_at)
     VALUES ($1, $2::jsonb, $3, now())
     ON CONFLICT (key) DO UPDATE SET
       payload = EXCLUDED.payload,
       expires_at = EXCLUDED.expires_at,
       updated_at = now()`,
    [CACHE_KEY, JSON.stringify(payload), expiresAt]
  );
  memoryCache = { payload, expiresAt: new Date(expiresAt).getTime() };
};

const cacheMatchesToday = (payload: any) => {
  const today = localParts().dateKey;
  return payload?.citySlug === CITY_SLUG && payload?.serviceDate === today && Array.isArray(payload?.notices);
};

const fetchFresh = async (): Promise<DeathNoticePayload> => {
  if (refreshInFlight) return refreshInFlight;

  refreshInFlight = (async () => {
    const now = new Date();
    const serviceDate = localParts(now).dateKey;
    const fetchUrl = new URL(FETCH_URL);
    fetchUrl.searchParams.set('araTarih', serviceDate);

    const response = await fetch(fetchUrl.toString(), {
      signal: AbortSignal.timeout(10000),
      headers: {
        Accept: 'text/html,application/xhtml+xml',
        'User-Agent': 'PateezNews/1.0 (+https://www.pateez.com)',
      },
    });

    if (!response.ok) throw new Error(`Niğde Belediyesi returned ${response.status}`);

    const html = await response.text();
    const notices = parseDeathNotices(html, serviceDate);
    const payload: DeathNoticePayload = {
      city: CITY,
      citySlug: CITY_SLUG,
      source: 'Niğde Belediyesi',
      sourceUrl: SOURCE_URL,
      fetchUrl: fetchUrl.toString(),
      timezone: TIMEZONE,
      serviceDate,
      serviceDateLabel: serviceDateLabel(now),
      fetchedAt: now.toISOString(),
      updateIntervalMinutes: 30,
      notices,
      meta: {
        total: notices.length,
        todayOnly: true,
        dateGuard: true,
      },
    };

    await writeCache(payload);
    return payload;
  })().finally(() => {
    refreshInFlight = null;
  });

  return refreshInFlight;
};

export const GET: APIRoute = async ({ url }) => {
  const forceRefresh = url.searchParams.get('refresh') === '1';
  const now = Date.now();
  const currentMemoryCache = memoryCache;

  if (!forceRefresh && currentMemoryCache && currentMemoryCache.expiresAt > now && cacheMatchesToday(currentMemoryCache.payload)) {
    return json({
      ...currentMemoryCache.payload,
      cache: { hit: true, stale: false, source: 'memory', refreshIntervalMinutes: 30 },
    });
  }

  const cached = forceRefresh ? null : await readCache();
  if (cached?.payload && cacheMatchesToday(cached.payload) && cached.expiresAt > now) {
    memoryCache = { payload: cached.payload, expiresAt: cached.expiresAt };
    return json({
      ...cached.payload,
      cache: { hit: true, stale: false, source: 'database', refreshIntervalMinutes: 30 },
    });
  }

  if (cached?.payload && cacheMatchesToday(cached.payload)) {
    void fetchFresh().catch(() => null);
    return json({
      ...cached.payload,
      cache: { hit: true, stale: true, refreshing: true, source: 'database', refreshIntervalMinutes: 30 },
    });
  }

  try {
    const fresh = await fetchFresh();
    return json({
      ...fresh,
      cache: { hit: false, stale: false, source: 'nigde.bel.tr', refreshIntervalMinutes: 30 },
    });
  } catch (error: any) {
    return json({
      city: CITY,
      citySlug: CITY_SLUG,
      source: 'Niğde Belediyesi',
      sourceUrl: SOURCE_URL,
      fetchUrl: FETCH_URL,
      timezone: TIMEZONE,
      serviceDate: localParts().dateKey,
      serviceDateLabel: serviceDateLabel(new Date()),
      fetchedAt: new Date().toISOString(),
      updateIntervalMinutes: 30,
      notices: [],
      meta: { total: 0, todayOnly: true, dateGuard: true },
      cache: { hit: false, stale: false, source: 'nigde.bel.tr', refreshIntervalMinutes: 30 },
      error: error?.message || 'Death notices could not be fetched',
    }, 502);
  }
};
