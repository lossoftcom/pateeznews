import { ensureAppSchema } from './appDb';
import { dbQuery } from './supabaseDb';
import { readRuntimeEnv } from './runtimeEnv';

const FETCH_TIMEOUT_MS = 8500;
const REFRESH_LOCK_MS = 12000;
const DEFAULT_DIYANET_BASE_URL = 'https://namazvakitleri.diyanet.gov.tr';
const DEFAULT_QURAN_BASE_URL = 'https://t061.diyanet.gov.tr/apigateway/acikkaynakkuran';
const DEFAULT_LOCATION_ID = 9766;
const DEFAULT_SETTINGS = {
  enabled: true,
  diyanetBaseUrl: DEFAULT_DIYANET_BASE_URL,
  locationName: 'Niğde',
  locationCountry: 'Türkiye',
  locationStateId: 561,
  locationCityId: DEFAULT_LOCATION_ID,
  timezone: 'Europe/Istanbul',
  refreshLeadDays: 3,
  cacheDays: 370,
  ayahEnabled: true,
  ayahStartDate: '2026-06-05',
  quranApiBaseUrl: DEFAULT_QURAN_BASE_URL,
  quranApiToken: '',
};

type PrayerTimeName = 'imsak' | 'gunes' | 'ogle' | 'ikindi' | 'aksam' | 'yatsi';

export type PrayerSettings = typeof DEFAULT_SETTINGS;

export type PrayerTimePayload = {
  key: PrayerTimeName;
  name: string;
  time: string;
};

export type PrayerDayPayload = {
  date: string;
  gregorianDateLabel: string;
  hijriDateLabel: string;
  times: PrayerTimePayload[];
  qiblaAngle: string;
};

export type DailyAyahPayload = {
  surahId: number;
  surahName: string;
  verseNumber: number;
  arabicText: string;
  translation: string;
  source: string;
};

export type PrayerPayload = {
  enabled: boolean;
  source: string;
  location: string;
  country: string;
  timezone: string;
  serviceDateLabel: string;
  fetchedAt: string;
  refreshLeadDays: number;
  cacheDays: number;
  today: PrayerDayPayload | null;
  days: PrayerDayPayload[];
  dailyAyah: DailyAyahPayload | null;
  cache?: Record<string, unknown>;
  error?: string;
};

type CachedPayload = {
  key: string;
  expiresAt: number;
  payload: PrayerPayload;
};

type QuranChapter = {
  id: number;
  name: string;
  verseCount: number;
};

let schemaReady: Promise<void> | null = null;
const memoryCache = new Map<string, CachedPayload>();
const refreshInFlight = new Map<
  string,
  { startedAt: number; promise: Promise<PrayerPayload> }
>();

const PRAYER_LABELS: Record<PrayerTimeName, string> = {
  imsak: 'İmsak',
  gunes: 'Güneş',
  ogle: 'Öğle',
  ikindi: 'İkindi',
  aksam: 'Akşam',
  yatsi: 'Yatsı',
};

const DIANET_HTML_HEADERS = {
  Accept: 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
  'Accept-Language': 'tr-TR,tr;q=0.9',
  'User-Agent':
    'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/137.0.0.0 Safari/537.36',
};

const HTML_ENTITIES: Record<string, string> = {
  amp: '&',
  apos: "'",
  ccedil: 'ç',
  Ccedil: 'Ç',
  gbreve: 'ğ',
  Gbreve: 'Ğ',
  gt: '>',
  lt: '<',
  nbsp: ' ',
  odot: 'ö',
  Odot: 'Ö',
  quot: '"',
  scedil: 'ş',
  Scedil: 'Ş',
  uuml: 'ü',
  Uuml: 'Ü',
};

const TURKISH_MONTHS: Record<string, number> = {
  ocak: 1,
  subat: 2,
  şubat: 2,
  mart: 3,
  nisan: 4,
  mayis: 5,
  mayıs: 5,
  haziran: 6,
  temmuz: 7,
  agustos: 8,
  ağustos: 8,
  eylul: 9,
  eylül: 9,
  ekim: 10,
  kasim: 11,
  kasım: 11,
  aralik: 12,
  aralık: 12,
};

const QURAN_CHAPTER_VERSE_COUNTS = [
  7, 286, 200, 176, 120, 165, 206, 75, 129, 109, 123, 111, 43, 52, 99, 128,
  111, 110, 98, 135, 112, 78, 118, 64, 77, 227, 93, 88, 69, 60, 34, 30, 73,
  54, 45, 83, 182, 88, 75, 85, 54, 53, 89, 59, 37, 35, 38, 29, 18, 45, 60,
  49, 62, 55, 78, 96, 29, 22, 24, 13, 14, 11, 11, 18, 12, 12, 30, 52, 52,
  44, 28, 28, 20, 56, 40, 31, 50, 40, 46, 42, 29, 19, 36, 25, 22, 17, 19,
  26, 30, 20, 15, 21, 11, 8, 8, 19, 5, 8, 8, 11, 11, 8, 3, 9, 5, 4, 7, 3,
  6, 3, 5, 4, 5, 6,
];

const QURAN_CHAPTER_NAMES = [
  'Fâtiha', 'Bakara', 'Âl-i İmrân', 'Nisâ', 'Mâide', 'Enâm', 'Araf',
  'Enfâl', 'Tevbe', 'Yûnus', 'Hûd', 'Yûsuf', 'Ra’d', 'İbrâhîm', 'Hicr',
  'Nahl', 'İsrâ', 'Kehf', 'Meryem', 'Tâhâ', 'Enbiyâ', 'Hac', 'Müminûn',
  'Nûr', 'Furkân', 'Şuarâ', 'Neml', 'Kasas', 'Ankebût', 'Rûm', 'Lokmân',
  'Secde', 'Ahzâb', 'Sebe', 'Fâtır', 'Yâsîn', 'Sâffât', 'Sâd', 'Zümer',
  'Mümin', 'Fussilet', 'Şûrâ', 'Zuhruf', 'Duhân', 'Câsiye', 'Ahkâf',
  'Muhammed', 'Fetih', 'Hucurât', 'Kâf', 'Zâriyât', 'Tûr', 'Necm', 'Kamer',
  'Rahmân', 'Vâkıa', 'Hadîd', 'Mücâdele', 'Haşr', 'Mümtehine', 'Saf',
  'Cum’a', 'Münâfikûn', 'Teğâbün', 'Talâk', 'Tahrîm', 'Mülk', 'Kalem',
  'Hâkka', 'Meâric', 'Nûh', 'Cin', 'Müzzemmil', 'Müddessir', 'Kıyâmet',
  'İnsân', 'Mürselât', 'Nebe', 'Nâziât', 'Abese', 'Tekvîr', 'İnfitâr',
  'Mutaffifîn', 'İnşikâk', 'Burûc', 'Târık', 'A’lâ', 'Gâşiye', 'Fecr',
  'Beled', 'Şems', 'Leyl', 'Duhâ', 'İnşirâh', 'Tîn', 'Alak', 'Kadir',
  'Beyyine', 'Zilzâl', 'Âdiyât', 'Kâria', 'Tekâsür', 'Asr', 'Hümeze',
  'Fîl', 'Kureyş', 'Mâûn', 'Kevser', 'Kâfirûn', 'Nasr', 'Tebbet',
  'İhlâs', 'Felak', 'Nâs',
];

export const ensurePrayerSettingsSchema = async () => {
  if (schemaReady) return schemaReady;
  schemaReady = (async () => {
    await ensureAppSchema();
  })().catch((error) => {
    schemaReady = null;
    throw error;
  });
  return schemaReady;
};

export const getPrayerSettings = async (languageCode: string): Promise<PrayerSettings> => {
  await ensurePrayerSettingsSchema();
  const lang = cleanLanguageCode(languageCode);
  const result = await dbQuery<any>(
    `SELECT
       prayer_enabled,
       prayer_diyanet_base_url,
       prayer_location_name,
       prayer_location_country,
       prayer_location_state_id,
       prayer_location_city_id,
       prayer_timezone,
       prayer_refresh_lead_days,
       prayer_cache_days,
       daily_ayah_enabled,
       daily_ayah_start_date,
       daily_ayah_quran_api_base_url,
       daily_ayah_quran_api_token
     FROM public.site_settings
     WHERE language_code = $1
     LIMIT 1`,
    [lang]
  );
  let row = result.rows[0] || null;
  if (!row && lang !== 'tr') {
    const fallback = await dbQuery<any>(
      `SELECT
         prayer_enabled,
         prayer_diyanet_base_url,
         prayer_location_name,
         prayer_location_country,
         prayer_location_state_id,
         prayer_location_city_id,
         prayer_timezone,
         prayer_refresh_lead_days,
         prayer_cache_days,
         daily_ayah_enabled,
         daily_ayah_start_date,
         daily_ayah_quran_api_base_url,
         daily_ayah_quran_api_token
       FROM public.site_settings
       WHERE language_code = 'tr'
       LIMIT 1`
    );
    row = fallback.rows[0] || null;
  }
  return settingsFromRow(row);
};

export const savePrayerSettings = async (
  languageCode: string,
  settings: Partial<PrayerSettings>
): Promise<PrayerSettings> => {
  await ensurePrayerSettingsSchema();
  const normalized = normalizePrayerSettings(settings);
  const result = await dbQuery<any>(
    `INSERT INTO public.site_settings (
       language_code,
       prayer_enabled,
       prayer_diyanet_base_url,
       prayer_location_name,
       prayer_location_country,
       prayer_location_state_id,
       prayer_location_city_id,
       prayer_timezone,
       prayer_refresh_lead_days,
       prayer_cache_days,
       daily_ayah_enabled,
       daily_ayah_start_date,
       daily_ayah_quran_api_base_url,
       daily_ayah_quran_api_token,
       updated_at
     )
     VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13,$14,now())
     ON CONFLICT (language_code) DO UPDATE SET
       prayer_enabled = EXCLUDED.prayer_enabled,
       prayer_diyanet_base_url = EXCLUDED.prayer_diyanet_base_url,
       prayer_location_name = EXCLUDED.prayer_location_name,
       prayer_location_country = EXCLUDED.prayer_location_country,
       prayer_location_state_id = EXCLUDED.prayer_location_state_id,
       prayer_location_city_id = EXCLUDED.prayer_location_city_id,
       prayer_timezone = EXCLUDED.prayer_timezone,
       prayer_refresh_lead_days = EXCLUDED.prayer_refresh_lead_days,
       prayer_cache_days = EXCLUDED.prayer_cache_days,
       daily_ayah_enabled = EXCLUDED.daily_ayah_enabled,
       daily_ayah_start_date = EXCLUDED.daily_ayah_start_date,
       daily_ayah_quran_api_base_url = EXCLUDED.daily_ayah_quran_api_base_url,
       daily_ayah_quran_api_token = EXCLUDED.daily_ayah_quran_api_token,
       updated_at = now()
     RETURNING *`,
    [
      cleanLanguageCode(languageCode),
      normalized.enabled,
      normalized.diyanetBaseUrl,
      normalized.locationName,
      normalized.locationCountry,
      normalized.locationStateId,
      normalized.locationCityId,
      normalized.timezone,
      normalized.refreshLeadDays,
      normalized.cacheDays,
      normalized.ayahEnabled,
      normalized.ayahStartDate,
      normalized.quranApiBaseUrl,
      normalized.quranApiToken,
    ]
  );
  return settingsFromRow(result.rows[0]);
};

export const invalidatePrayerCache = async (languageCode: string) => {
  const prefix = `prayer:${cleanLanguageCode(languageCode)}:`;
  for (const key of memoryCache.keys()) {
    if (key.startsWith(prefix)) memoryCache.delete(key);
  }
  try {
    await dbQuery(`DELETE FROM public.app_cache WHERE key LIKE $1`, [`${prefix}%`]);
  } catch {
    // Cache temizliği cevap yolunu bloklamaz.
  }
};

export const fetchPrayerPayload = async (
  languageCode: string,
  forceRefresh = false
): Promise<PrayerPayload> => {
  const settings = await getPrayerSettings(languageCode);
  const lang = cleanLanguageCode(languageCode);
  const key = prayerCacheKey(lang, settings);
  const now = Date.now();
  const currentMemory = memoryCache.get(key) || null;

  if (!forceRefresh && currentMemory && currentMemory.expiresAt > now) {
    return {
      ...currentMemory.payload,
      cache: { hit: true, stale: false, source: 'memory' },
    };
  }

  const cached = await withTimeout(readCache(key), 900, null);
  if (!forceRefresh && cached?.payload && cached.expiresAt > now) {
    memoryCache.set(key, { key, payload: cached.payload, expiresAt: cached.expiresAt });
    return {
      ...cached.payload,
      cache: { hit: true, stale: false, source: 'database' },
    };
  }

  if (!forceRefresh && cached?.payload) {
    void fetchPrayerFresh(key, lang, settings).catch(() => null);
    return {
      ...cached.payload,
      cache: { hit: true, stale: true, refreshing: true, source: 'database' },
    };
  }

  try {
    const fresh = await fetchPrayerFresh(key, lang, settings);
    return {
      ...fresh,
      cache: { hit: false, stale: false, source: 'Diyanet' },
    };
  } catch (error: any) {
    const fallback = cached?.payload || currentMemory?.payload;
    if (fallback) {
      return {
        ...fallback,
        cache: {
          hit: true,
          stale: true,
          refreshFailed: true,
          source: cached?.payload ? 'database' : 'memory',
        },
        error: error?.message || 'Namaz vakitleri yenilenemedi',
      };
    }
    return emptyPrayerPayload(settings, error?.message || 'Namaz vakitleri alınamadı');
  }
};

const fetchPrayerFresh = async (
  key: string,
  languageCode: string,
  settings: PrayerSettings
): Promise<PrayerPayload> => {
  const active = refreshInFlight.get(key);
  if (active && Date.now() - active.startedAt < REFRESH_LOCK_MS) return active.promise;
  refreshInFlight.delete(key);

  let trackedPromise: Promise<PrayerPayload>;
  trackedPromise = (async () => {
    if (!settings.enabled) throw new Error('Namaz vakitleri modülü kapalı');

    const days = await fetchDiyanetDays(settings);
    const today = selectToday(days, settings.timezone);
    const dailyAyah = settings.ayahEnabled
      ? await fetchDailyAyah(settings, languageCode).catch(() => null)
      : null;
    const payload: PrayerPayload = {
      enabled: settings.enabled,
      source: 'Diyanet Namaz Vakitleri',
      location: settings.locationName,
      country: settings.locationCountry,
      timezone: settings.timezone,
      serviceDateLabel: localDateLabel(settings.timezone),
      fetchedAt: new Date().toISOString(),
      refreshLeadDays: settings.refreshLeadDays,
      cacheDays: settings.cacheDays,
      today,
      days,
      dailyAyah,
    };

    await writeCache(key, payload, cacheExpiry(settings));
    return payload;
  })().finally(() => {
    if (refreshInFlight.get(key)?.promise === trackedPromise) {
      refreshInFlight.delete(key);
    }
  });

  refreshInFlight.set(key, { startedAt: Date.now(), promise: trackedPromise });
  return trackedPromise;
};

const fetchDiyanetDays = async (settings: PrayerSettings): Promise<PrayerDayPayload[]> => {
  const html = await fetchDiyanetPrayerHtml(settings);
  const days = parseDiyanetDays(html, settings);
  if (!days.length) throw new Error('Diyanet namaz vakitleri tablosu okunamadı');
  return days;
};

const fetchDailyAyah = async (
  settings: PrayerSettings,
  languageCode: string
): Promise<DailyAyahPayload | null> => {
  const token =
    settings.quranApiToken ||
    readRuntimeEnv('DIB_KURAN_API_TOKEN') ||
    readRuntimeEnv('QURAN_API_TOKEN');
  if (!token) return null;
  const baseUrl = cleanBaseUrl(settings.quranApiBaseUrl || DEFAULT_QURAN_BASE_URL, DEFAULT_QURAN_BASE_URL);
  const { surahId, verseNumber } = verseForDate(settings.ayahStartDate, settings.timezone);
  const response = await fetch(`${baseUrl}/api/v1/chapters/${surahId}`, {
    headers: {
      Accept: 'application/json',
      Authorization: `Bearer ${token}`,
      'Accept-Language': languageCode,
    },
    signal: AbortSignal.timeout(FETCH_TIMEOUT_MS),
  });
  if (!response.ok) throw new Error(`Diyanet Kur'an API ${response.status}`);
  const decoded = await response.json();
  const chapter = decoded?.data || decoded?.chapter || decoded;
  const verses = Array.isArray(chapter)
    ? chapter
    : Array.isArray(chapter?.verses)
      ? chapter.verses
      : Array.isArray(chapter?.ayahs)
        ? chapter.ayahs
        : [];
  const verse = verses.find((item: any) => {
    const id = Number(
      item?.verseNumber ||
        item?.verse_number ||
        item?.verse_id_in_surah ||
        item?.verseIdInSurah ||
        item?.numberInSurah ||
        item?.id
    );
    return id === verseNumber;
  });
  const arabicText = cleanText(
    verse?.arabic_script?.text ||
      verse?.arabicText ||
      verse?.arabic_text ||
      verse?.textArabic ||
      verse?.originalText
  );
  const translation = cleanText(
    verse?.translation?.text ||
      verse?.translation ||
      verse?.meaning ||
      verse?.meal ||
      verse?.text ||
      verse?.textTranslation ||
      verse?.translationText ||
      verse?.turkishText
  );
  if (!arabicText && !translation) return null;
  return {
    surahId,
    surahName: cleanText(
      verse?.surah_name_turkish ||
        verse?.surahName ||
        chapter?.name ||
        chapter?.nameSimple ||
        QURAN_CHAPTER_NAMES[surahId - 1]
    ),
    verseNumber,
    arabicText,
    translation,
    source: 'Diyanet Kur’an API',
  };
};

const fetchDiyanetPrayerHtml = async (settings: PrayerSettings) => {
  const baseUrl = cleanBaseUrl(settings.diyanetBaseUrl || DEFAULT_DIYANET_BASE_URL, DEFAULT_DIYANET_BASE_URL);
  const slug = `${normalizeKey(settings.locationName) || 'nigde'}-namaz-vakitleri`;
  const cityId = settings.locationCityId || DEFAULT_LOCATION_ID;
  const pageUrl = `${baseUrl}/tr-TR/${cityId}/${slug}`;
  let cookie = '';

  try {
    const bootstrap = await fetchDiyanetText(`${baseUrl}/tr-TR`);
    cookie = extractCookieHeader(bootstrap.headers.get('set-cookie'));
  } catch {
    cookie = '';
  }

  try {
    return await readDiyanetResponse(await fetchDiyanetText(pageUrl, cookie));
  } catch (error: any) {
    if (!cookie) throw error;
    return readDiyanetResponse(await fetchDiyanetText(pageUrl));
  }
};

const fetchDiyanetText = (url: string, cookie = '') =>
  fetch(url, {
    headers: {
      ...DIANET_HTML_HEADERS,
      ...(cookie ? { Cookie: cookie } : {}),
    },
    signal: AbortSignal.timeout(FETCH_TIMEOUT_MS),
  });

const readDiyanetResponse = async (response: Response) => {
  if (!response.ok) throw new Error(`Diyanet namaz vakitleri ${response.status}`);
  const html = await response.text();
  if (!html.includes('vakit-table') && !html.includes('today-pray-times')) {
    throw new Error('Diyanet namaz vakitleri sayfası beklenen tabloyu içermiyor');
  }
  return html;
};

const extractCookieHeader = (setCookie: string | null) => {
  const text = cleanText(setCookie);
  if (!text) return '';
  const cookies = [...text.matchAll(/(?:^|,\s*)([A-Za-z_][A-Za-z0-9_]*=[^;,]+)/g)]
    .map((match) => match[1])
    .filter((cookie) => !cookie.toLowerCase().startsWith('expires='));
  return cookies.length ? cookies.join('; ') : text.split(';')[0] || '';
};

const parseDiyanetDays = (html: string, settings: PrayerSettings): PrayerDayPayload[] => {
  const table =
    extractDiyanetTable(html, 'yourTable') ||
    extractDiyanetTableByCaption(html, 'Yıllık Namaz Vakti') ||
    extractDiyanetTableByCaption(html, 'Aylık Namaz Vakitleri') ||
    extractDiyanetTableByCaption(html, 'Haftalık Namaz Vakti') ||
    html;
  const qiblaAngle = readDiyanetQiblaAngle(html);
  const rows = table.match(/<tr\b[\s\S]*?<\/tr>/gi) || [];

  return rows
    .map((row) => parseDiyanetDayRow(row, settings, qiblaAngle))
    .filter(Boolean)
    .sort((left, right) => left!.date.localeCompare(right!.date)) as PrayerDayPayload[];
};

const parseDiyanetDayRow = (
  row: string,
  settings: PrayerSettings,
  qiblaAngle: string
): PrayerDayPayload | null => {
  const cells = [...row.matchAll(/<td\b[^>]*>([\s\S]*?)<\/td>/gi)].map((cell) =>
    cleanHtmlCell(cell[1])
  );
  if (cells.length < 8) return null;

  const directTimes = cells.slice(2, 8).map(normalizeTime).filter(Boolean);
  const offset = directTimes.length === 6 ? 0 : 2;
  if (cells.length < offset + 8) return null;

  const date = parseTurkishDateLabel(cells[offset]);
  if (!date) return null;

  const times = (Object.keys(PRAYER_LABELS) as PrayerTimeName[])
    .map((key, index) => {
      const time = normalizeTime(cells[offset + 2 + index]);
      return time ? { key, name: PRAYER_LABELS[key], time } : null;
    })
    .filter(Boolean) as PrayerTimePayload[];
  if (times.length !== 6) return null;

  return {
    date,
    gregorianDateLabel: cleanText(cells[offset]) || dateLabelFromIso(date, settings.timezone),
    hijriDateLabel: cleanText(cells[offset + 1]),
    times,
    qiblaAngle: qiblaAngle || '147°',
  };
};

const extractDiyanetTable = (html: string, id: string) => {
  const pattern = new RegExp(`<table\\\\b[^>]*id=["']${id}["'][\\\\s\\\\S]*?<\\\\/table>`, 'i');
  return html.match(pattern)?.[0] || '';
};

const extractDiyanetTableByCaption = (html: string, caption: string) => {
  const tables = html.match(/<table\b[\s\S]*?<\/table>/gi) || [];
  return tables.find((table) => cleanHtmlCell(table).includes(caption)) || '';
};

const readDiyanetQiblaAngle = (html: string) => {
  const qiblaBlock = html.match(/K(?:ı|i|&#305;)ble A(?:ç|c|&#231;)ısı[\s\S]{0,500}?<div[^>]*class=["'][^"']*tpt-time[^"']*["'][^>]*>([\s\S]*?)<\/div>/i);
  return cleanText(qiblaBlock ? cleanHtmlCell(qiblaBlock[1]) : '');
};

const cleanHtmlCell = (value: string) =>
  decodeHtml(value.replace(/<[^>]*>/g, ' ').replace(/\s+/g, ' ').trim());

const decodeHtml = (value: string) =>
  value
    .replace(/&#x([0-9a-f]+);/gi, (_, code) => String.fromCodePoint(Number.parseInt(code, 16)))
    .replace(/&#(\d+);/g, (_, code) => String.fromCodePoint(Number.parseInt(code, 10)))
    .replace(/&([a-zA-Z]+);/g, (match, name) => HTML_ENTITIES[name] || match);

const parseTurkishDateLabel = (value: string) => {
  const match = cleanText(value).match(/^(\d{1,2})\s+([A-Za-zÇĞİÖŞÜçğıöşü]+)\s+(\d{4})/);
  if (!match) return '';
  const month = TURKISH_MONTHS[normalizeKey(match[2])];
  if (!month) return '';
  return `${match[3]}-${String(month).padStart(2, '0')}-${match[1].padStart(2, '0')}`;
};

const readCache = async (key: string) => {
  try {
    await ensureAppSchema();
    const result = await dbQuery<{ payload: any; expires_at: string }>(
      `SELECT payload, expires_at FROM public.app_cache WHERE key = $1 LIMIT 1`,
      [key]
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

const writeCache = async (key: string, payload: PrayerPayload, expiresAt: number) => {
  memoryCache.set(key, { key, payload, expiresAt });
  try {
    await ensureAppSchema();
    await dbQuery(
      `INSERT INTO public.app_cache (key, payload, expires_at, updated_at)
       VALUES ($1, $2::jsonb, $3, now())
       ON CONFLICT (key) DO UPDATE SET
         payload = EXCLUDED.payload,
         expires_at = EXCLUDED.expires_at,
         updated_at = now()`,
      [key, JSON.stringify(payload), new Date(expiresAt).toISOString()]
    );
  } catch {
    // Cache yazımı veri cevabını düşürmez.
  }
};

const emptyPrayerPayload = (settings: PrayerSettings, error: string): PrayerPayload => ({
  enabled: settings.enabled,
  source: 'Diyanet Namaz Vakitleri',
  location: settings.locationName,
  country: settings.locationCountry,
  timezone: settings.timezone,
  serviceDateLabel: localDateLabel(settings.timezone),
  fetchedAt: new Date().toISOString(),
  refreshLeadDays: settings.refreshLeadDays,
  cacheDays: settings.cacheDays,
  today: null,
  days: [],
  dailyAyah: null,
  error,
});

const settingsFromRow = (row: any): PrayerSettings => normalizePrayerSettings({
  enabled: row?.prayer_enabled,
  diyanetBaseUrl: row?.prayer_diyanet_base_url,
  locationName: row?.prayer_location_name,
  locationCountry: row?.prayer_location_country,
  locationStateId: row?.prayer_location_state_id,
  locationCityId: row?.prayer_location_city_id,
  timezone: row?.prayer_timezone,
  refreshLeadDays: row?.prayer_refresh_lead_days,
  cacheDays: row?.prayer_cache_days,
  ayahEnabled: row?.daily_ayah_enabled,
  ayahStartDate: row?.daily_ayah_start_date,
  quranApiBaseUrl: row?.daily_ayah_quran_api_base_url,
  quranApiToken: row?.daily_ayah_quran_api_token,
});

const normalizePrayerSettings = (settings: Partial<PrayerSettings>): PrayerSettings => ({
  enabled: settings.enabled !== false,
  diyanetBaseUrl: cleanBaseUrl(settings.diyanetBaseUrl || DEFAULT_SETTINGS.diyanetBaseUrl, DEFAULT_DIYANET_BASE_URL),
  locationName: cleanText(settings.locationName) || DEFAULT_SETTINGS.locationName,
  locationCountry: cleanText(settings.locationCountry) || DEFAULT_SETTINGS.locationCountry,
  locationStateId: clampInt(settings.locationStateId, DEFAULT_SETTINGS.locationStateId, 1, 999999),
  locationCityId: clampInt(settings.locationCityId, DEFAULT_SETTINGS.locationCityId, 1, 999999),
  timezone: cleanText(settings.timezone) || DEFAULT_SETTINGS.timezone,
  refreshLeadDays: clampInt(settings.refreshLeadDays, DEFAULT_SETTINGS.refreshLeadDays, 1, 10),
  cacheDays: clampInt(settings.cacheDays, DEFAULT_SETTINGS.cacheDays, 31, 400),
  ayahEnabled: settings.ayahEnabled !== false,
  ayahStartDate: isoDate(cleanText(settings.ayahStartDate)) || DEFAULT_SETTINGS.ayahStartDate,
  quranApiBaseUrl: cleanBaseUrl(settings.quranApiBaseUrl || DEFAULT_SETTINGS.quranApiBaseUrl, DEFAULT_QURAN_BASE_URL),
  quranApiToken: cleanText(settings.quranApiToken),
});

const prayerCacheKey = (languageCode: string, settings: PrayerSettings) =>
  [
    'prayer',
    languageCode,
    settings.locationCityId || 'unset',
    settings.timezone,
    dateParts(new Date(), settings.timezone).year,
  ].join(':');

const cacheExpiry = (settings: PrayerSettings) => {
  const now = new Date();
  const base = now.getTime() + settings.cacheDays * 24 * 60 * 60 * 1000;
  const nextMonthLead = new Date(
    Date.UTC(now.getUTCFullYear(), now.getUTCMonth() + 1, 1 - settings.refreshLeadDays, 0, 0, 0)
  ).getTime();
  return Math.min(base, Math.max(now.getTime() + 24 * 60 * 60 * 1000, nextMonthLead));
};

const selectToday = (days: PrayerDayPayload[], timezone: string) => {
  const today = isoDateInTimezone(new Date(), timezone);
  return days.find((day) => day.date === today) || days[0] || null;
};

const verseForDate = (startDate: string, timezone: string) => {
  const today = new Date(`${isoDateInTimezone(new Date(), timezone)}T00:00:00Z`);
  const start = new Date(`${isoDate(startDate) || DEFAULT_SETTINGS.ayahStartDate}T00:00:00Z`);
  const days = Math.max(0, Math.floor((today.getTime() - start.getTime()) / 86400000));
  let ordinal = (days % 6236) + 1;
  for (let index = 0; index < QURAN_CHAPTER_VERSE_COUNTS.length; index++) {
    const count = QURAN_CHAPTER_VERSE_COUNTS[index];
    if (ordinal <= count) {
      return { surahId: index + 1, verseNumber: ordinal };
    }
    ordinal -= count;
  }
  return { surahId: 1, verseNumber: 1 };
};

const normalizeDate = (value: string, timezone: string) => {
  const iso = isoDate(value);
  if (iso) return iso;
  return isoDateInTimezone(new Date(), timezone);
};

const normalizeTime = (value: string) => {
  const match = String(value || '').match(/([01]?\d|2[0-3])[:.]([0-5]\d)/);
  if (!match) return '';
  return `${match[1].padStart(2, '0')}:${match[2]}`;
};

const isoDate = (value: string) => {
  const text = cleanText(value);
  if (!text) return '';
  const direct = text.match(/^(\d{4})-(\d{2})-(\d{2})/);
  if (direct) return `${direct[1]}-${direct[2]}-${direct[3]}`;
  const tr = text.match(/^(\d{1,2})[./-](\d{1,2})[./-](\d{4})/);
  if (tr) return `${tr[3]}-${tr[2].padStart(2, '0')}-${tr[1].padStart(2, '0')}`;
  const parsed = new Date(text);
  return Number.isNaN(parsed.getTime()) ? '' : parsed.toISOString().slice(0, 10);
};

const dateParts = (date: Date, timezone: string) => {
  const parts = new Intl.DateTimeFormat('en-CA', {
    timeZone: timezone,
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
  }).formatToParts(date);
  return {
    year: Number(parts.find((part) => part.type === 'year')?.value || date.getUTCFullYear()),
    month: Number(parts.find((part) => part.type === 'month')?.value || date.getUTCMonth() + 1),
    day: Number(parts.find((part) => part.type === 'day')?.value || date.getUTCDate()),
  };
};

const isoDateInTimezone = (date: Date, timezone: string) => {
  const parts = dateParts(date, timezone);
  return `${parts.year}-${String(parts.month).padStart(2, '0')}-${String(parts.day).padStart(2, '0')}`;
};

const dateLabelFromIso = (date: string, timezone: string) =>
  new Intl.DateTimeFormat('tr-TR', {
    timeZone: timezone,
    day: 'numeric',
    month: 'long',
    year: 'numeric',
    weekday: 'long',
  }).format(new Date(`${date}T12:00:00Z`));

const localDateLabel = (timezone: string) => dateLabelFromIso(isoDateInTimezone(new Date(), timezone), timezone);

const cleanBaseUrl = (value: string, fallback = DEFAULT_DIYANET_BASE_URL) => {
  const text = cleanText(value);
  return (text || fallback).replace(/\/+$/, '');
};

const cleanLanguageCode = (value: string) => String(value || 'tr').trim().toLowerCase() || 'tr';

const cleanText = (value: unknown) => String(value ?? '').replace(/\s+/g, ' ').trim();

const normalizeKey = (value: unknown) =>
  String(value || '')
    .toLocaleLowerCase('tr-TR')
    .normalize('NFD')
    .replace(/[\u0300-\u036f]/g, '')
    .replace(/ı/g, 'i')
    .replace(/[^a-z0-9]+/g, '');

const clampInt = (value: unknown, fallback: number, min: number, max: number) => {
  const parsed = Number.parseInt(String(value ?? ''), 10);
  if (!Number.isFinite(parsed)) return fallback;
  return Math.min(max, Math.max(min, parsed));
};

const withTimeout = async <T>(promise: Promise<T>, timeoutMs: number, fallback: T): Promise<T> => {
  let timer: ReturnType<typeof setTimeout> | undefined;
  try {
    return await Promise.race([
      promise,
      new Promise<T>((resolve) => {
        timer = setTimeout(() => resolve(fallback), timeoutMs);
      }),
    ]);
  } finally {
    if (timer) clearTimeout(timer);
  }
};
