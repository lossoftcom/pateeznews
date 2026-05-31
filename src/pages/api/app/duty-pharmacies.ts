import type { APIRoute } from 'astro';
import * as parse5 from 'parse5';
import { ensureAppSchema, json } from '@/lib/server/appDb';
import { dbQuery } from '@/lib/server/supabaseDb';

const SOURCE_URL = 'https://www.neo.org.tr/nobetci-eczaneler';
const CITY = 'Niğde';
const CITY_SLUG = 'nigde';
const TIMEZONE = 'Europe/Istanbul';
const PHARMACY_REFRESH_MS = 15 * 60 * 1000;
const CACHE_KEY = `duty_pharmacies:${CITY_SLUG}`;
const DISTRICT_ORDER = ['MERKEZ', 'ALTUNHİSAR', 'BOR', 'ÇAMARDI', 'ÇİFTLİK', 'ULUKIŞLA'];

type DutyPharmacy = {
  id: string;
  name: string;
  district: string;
  address: string;
  phone: string;
  phoneHref: string;
  mapUrl: string;
  directionUrl: string;
  latitude: number | null;
  longitude: number | null;
  note: string;
  isUntilMidnight: boolean;
  expiresAt: string | null;
};

type DutyPharmacyPayload = {
  city: string;
  citySlug: string;
  source: string;
  sourceUrl: string;
  timezone: string;
  serviceDate: string;
  serviceDateLabel: string;
  fetchedAt: string;
  updateIntervalMinutes: number;
  districts: string[];
  pharmacies: DutyPharmacy[];
  meta: {
    total: number;
    centerCount: number;
    midnightGuard: boolean;
  };
};

let memoryCache: { expiresAt: number; payload: DutyPharmacyPayload } | null = null;
let refreshInFlight: Promise<DutyPharmacyPayload> | null = null;

const normalizeText = (value: unknown) =>
  String(value || '')
    .replace(/\u00a0/g, ' ')
    .replace(/[ \t\r\f\v]+/g, ' ')
    .replace(/\n\s+/g, '\n')
    .trim();

const trUpper = (value: string) => normalizeText(value).toLocaleUpperCase('tr-TR');

const slugify = (value: string) =>
  trUpper(value)
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

const getAttr = (node: any, name: string) => {
  const attrs = Array.isArray(node?.attrs) ? node.attrs : [];
  return attrs.find((attr: any) => attr?.name === name)?.value || '';
};

const hasClass = (node: any, className: string) => {
  const classes = getAttr(node, 'class').split(/\s+/).filter(Boolean);
  return classes.includes(className);
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

const textWithBreaks = (node: any): string => {
  if (!node) return '';
  if (node.nodeName === '#text') return node.value || '';
  if (node.tagName === 'br') return '\n';

  const before = ['p', 'div', 'h1', 'h2', 'h3', 'h4'].includes(node.tagName) ? '\n' : '';
  const inner = (node.childNodes || []).map(textWithBreaks).join('');
  const after = ['p', 'div', 'h1', 'h2', 'h3', 'h4'].includes(node.tagName) ? '\n' : '';
  return `${before}${inner}${after}`;
};

const textContent = (node: any): string => {
  if (!node) return '';
  if (node.nodeName === '#text') return node.value || '';
  return (node.childNodes || []).map(textContent).join('');
};

const localParts = (date = new Date()) => {
  const parts = new Intl.DateTimeFormat('en-CA', {
    timeZone: TIMEZONE,
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
    hour: '2-digit',
    minute: '2-digit',
    hourCycle: 'h23',
  }).formatToParts(date);

  const pick = (type: string) => parts.find((part) => part.type === type)?.value || '';
  const year = pick('year');
  const month = pick('month');
  const day = pick('day');
  return {
    year,
    month,
    day,
    hour: Number(pick('hour') || 0),
    minute: Number(pick('minute') || 0),
    dateKey: `${year}-${month}-${day}`,
  };
};

const nextIstanbulMidnight = (date = new Date()) => {
  const parts = localParts(date);
  const todayStart = new Date(`${parts.dateKey}T00:00:00+03:00`).getTime();
  return new Date(todayStart + 24 * 60 * 60 * 1000 + 30 * 1000);
};

const cacheExpiryDate = () => new Date(Math.min(Date.now() + PHARMACY_REFRESH_MS, nextIstanbulMidnight().getTime()));

const districtRank = (district: string) => {
  const index = DISTRICT_ORDER.indexOf(trUpper(district));
  return index === -1 ? 999 : index;
};

const normalizeDistrict = (value: string) => {
  const upper = trUpper(value);
  return DISTRICT_ORDER.find((district) => district === upper) || upper;
};

const normalizePhone = (value: string) => {
  const digits = String(value || '').replace(/\D/g, '');
  const phone = digits.length === 10 && !digits.startsWith('0') ? `0${digits}` : digits;
  if (phone.length === 11) return phone.replace(/(\d{4})(\d{3})(\d{2})(\d{2})/, '$1 $2 $3 $4');
  return phone;
};

const phoneHref = (value: string) => String(value || '').replace(/\D/g, '');

const mapCoordinates = (href: string) => {
  const match = href.match(/[?&]q=(-?\d+(?:\.\d+)?),\s*(-?\d+(?:\.\d+)?)/i);
  if (!match) return { latitude: null, longitude: null };
  return {
    latitude: Number(match[1]),
    longitude: Number(match[2]),
  };
};

const directionUrlFor = (pharmacy: Pick<DutyPharmacy, 'latitude' | 'longitude' | 'address' | 'name'>) => {
  if (typeof pharmacy.latitude === 'number' && typeof pharmacy.longitude === 'number') {
    return `https://www.google.com/maps/dir/?api=1&destination=${pharmacy.latitude},${pharmacy.longitude}`;
  }

  return `https://www.google.com/maps/search/?api=1&query=${encodeURIComponent(`${pharmacy.name} ${pharmacy.address} ${CITY}`)}`;
};

const parseDutyPharmacies = (html: string): DutyPharmacy[] => {
  const document = parse5.parse(html);
  const blocks = findAll(document, (node) =>
    node?.tagName === 'div' &&
    hasClass(node, 'eight') &&
    hasClass(node, 'columns') &&
    hasClass(node, 'bottom-1')
  );

  const nextMidnight = nextIstanbulMidnight().toISOString();

  return blocks
    .map((block): DutyPharmacy | null => {
      const strong = findAll(block, (node) => node?.tagName === 'strong')[0];
      const rawName = normalizeText(textContent(strong));
      const name = rawName.replace(/\s+/g, ' ');
      if (!name || !/ECZANESİ|ECZANESI/i.test(name)) return null;

      const anchors = findAll(block, (node) => node?.tagName === 'a');
      const telAnchor = anchors.find((node) => getAttr(node, 'href').startsWith('tel:'));
      const mapAnchor = anchors.find((node) => getAttr(node, 'href').includes('maps.google'));
      const mapUrl = getAttr(mapAnchor, 'href');
      const coords = mapCoordinates(mapUrl);
      const lines = textWithBreaks(block)
        .split('\n')
        .map(normalizeText)
        .filter(Boolean)
        .filter((line) => trUpper(line) !== trUpper(name))
        .filter((line) => !/Haritada görüntülemek/i.test(line));

      const noteLines = lines.filter((line) => /NÖBET|NOBET|GECE|KADAR|!!/i.test(trUpper(line)));
      const districtLine = lines.find((line) => DISTRICT_ORDER.includes(normalizeDistrict(line))) || '';
      const district = normalizeDistrict(districtLine || 'MERKEZ');
      const phoneText = normalizeText(textContent(telAnchor) || getAttr(telAnchor, 'href').replace(/^tel:/, ''));
      const phone = normalizePhone(phoneText || lines.find((line) => /\d{7,}/.test(line)) || '');
      const districtIndex = lines.findIndex((line) => normalizeDistrict(line) === district);
      const phoneDigits = phone.replace(/\D/g, '');
      const phoneIndex = lines.findIndex((line) => {
        const lineDigits = line.replace(/\D/g, '');
        return lineDigits.length >= 7 && (phoneDigits.endsWith(lineDigits) || lineDigits.endsWith(phoneDigits));
      });
      const addressLines = lines
        .slice(Math.max(0, districtIndex + 1), phoneIndex > -1 ? phoneIndex : undefined)
        .filter((line) => !noteLines.includes(line))
        .filter((line) => {
          const lineDigits = line.replace(/\D/g, '');
          return !(lineDigits.length >= 7 && (phoneDigits.endsWith(lineDigits) || lineDigits.endsWith(phoneDigits)));
        })
        .filter((line) => !DISTRICT_ORDER.includes(normalizeDistrict(line)));
      const note = normalizeText(noteLines.join(' '));
      const isUntilMidnight = /00[:.]?00/.test(note) && /KADAR/i.test(trUpper(note));
      const address = normalizeText(addressLines.join(' '));

      const pharmacy: DutyPharmacy = {
        id: slugify(`${district}-${name}`),
        name,
        district,
        address,
        phone,
        phoneHref: phoneHref(phone),
        mapUrl,
        directionUrl: '',
        latitude: coords.latitude,
        longitude: coords.longitude,
        note,
        isUntilMidnight,
        expiresAt: isUntilMidnight ? nextMidnight : null,
      };

      pharmacy.directionUrl = directionUrlFor(pharmacy);
      return pharmacy;
    })
    .filter(Boolean)
    .sort((a, b) => {
      const districtDiff = districtRank(a!.district) - districtRank(b!.district);
      if (districtDiff !== 0) return districtDiff;
      return a!.name.localeCompare(b!.name, 'tr');
    }) as DutyPharmacy[];
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

const writeCache = async (payload: DutyPharmacyPayload) => {
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
  return payload?.citySlug === CITY_SLUG && payload?.serviceDate === today && Array.isArray(payload?.pharmacies);
};

const fetchFresh = async (): Promise<DutyPharmacyPayload> => {
  if (refreshInFlight) return refreshInFlight;

  refreshInFlight = (async () => {
    const response = await fetch(SOURCE_URL, {
      signal: AbortSignal.timeout(10000),
      headers: {
        Accept: 'text/html,application/xhtml+xml',
        'User-Agent': 'PateezNews/1.0 (+https://www.pateez.com)',
      },
    });

    if (!response.ok) throw new Error(`NEO returned ${response.status}`);

    const html = new TextDecoder('iso-8859-9').decode(await response.arrayBuffer());
    const pharmacies = parseDutyPharmacies(html);
    if (!pharmacies.length) throw new Error('No duty pharmacies parsed');

    const now = new Date();
    const parts = localParts(now);
    const districts = Array.from(new Set(pharmacies.map((pharmacy) => pharmacy.district)))
      .sort((a, b) => districtRank(a) - districtRank(b));

    const payload: DutyPharmacyPayload = {
      city: CITY,
      citySlug: CITY_SLUG,
      source: 'Niğde Eczacı Odası',
      sourceUrl: SOURCE_URL,
      timezone: TIMEZONE,
      serviceDate: parts.dateKey,
      serviceDateLabel: new Intl.DateTimeFormat('tr-TR', {
        timeZone: TIMEZONE,
        day: 'numeric',
        month: 'long',
        year: 'numeric',
      }).format(now),
      fetchedAt: now.toISOString(),
      updateIntervalMinutes: 15,
      districts,
      pharmacies,
      meta: {
        total: pharmacies.length,
        centerCount: pharmacies.filter((pharmacy) => pharmacy.district === 'MERKEZ').length,
        midnightGuard: true,
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
      cache: { hit: true, stale: false, source: 'memory', refreshIntervalMinutes: 15 },
    });
  }

  const cached = forceRefresh ? null : await readCache();
  if (cached?.payload && cacheMatchesToday(cached.payload) && cached.expiresAt > now) {
    memoryCache = { payload: cached.payload, expiresAt: cached.expiresAt };
    return json({
      ...cached.payload,
      cache: { hit: true, stale: false, source: 'database', refreshIntervalMinutes: 15 },
    });
  }

  if (cached?.payload && cacheMatchesToday(cached.payload)) {
    void fetchFresh().catch(() => null);
    return json({
      ...cached.payload,
      cache: { hit: true, stale: true, refreshing: true, source: 'database', refreshIntervalMinutes: 15 },
    });
  }

  try {
    const fresh = await fetchFresh();
    return json({
      ...fresh,
      cache: { hit: false, stale: false, source: 'neo.org.tr', refreshIntervalMinutes: 15 },
    });
  } catch (error: any) {
    return json({
      city: CITY,
      citySlug: CITY_SLUG,
      source: 'Niğde Eczacı Odası',
      sourceUrl: SOURCE_URL,
      timezone: TIMEZONE,
      serviceDate: localParts().dateKey,
      serviceDateLabel: new Intl.DateTimeFormat('tr-TR', { timeZone: TIMEZONE, day: 'numeric', month: 'long', year: 'numeric' }).format(new Date()),
      fetchedAt: new Date().toISOString(),
      updateIntervalMinutes: 15,
      districts: [],
      pharmacies: [],
      meta: { total: 0, centerCount: 0, midnightGuard: true },
      cache: { hit: false, stale: false, source: 'neo.org.tr', refreshIntervalMinutes: 15 },
      error: error?.message || 'Duty pharmacy data could not be fetched',
    }, 502);
  }
};
