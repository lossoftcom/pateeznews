import { ensureAppSchema } from './appDb';
import { dbQuery } from './supabaseDb';

const FETCH_TIMEOUT_MS = 8500;
const MIN_REFRESH_SECONDS = 15;
// Sert üst sınır: tek tek fetch'ler AbortSignal.timeout ile sınırlı olsa da bazı
// runtime'larda (örn. workerd dev) abort her zaman tetiklenmeyebilir; bu durumda
// uç sonsuza takılıp istemcide TimeoutException'a yol açıyordu. Bu yarış (race)
// sınırı, sağlayıcı yavaş/engelliyse bile yanıtın daima dönmesini garantiler.
const FRESH_TOTAL_TIMEOUT_MS = 9000;
// Başarısız/zaman aşımına uğramış yanıtları kısa süre cache'le: sağlayıcı toparlayınca
// hızlı yeniden denenir ama her istekte tekrar takılma/hammer yaşanmaz.
const ERROR_CACHE_MS = 15000;
const DEFAULT_CURRENCY_SYMBOLS = [
  'USD',
  'EUR',
  'BTC',
  'GBP',
  'CHF',
  'CAD',
  'AUD',
  'JPY',
  'SAR',
  'KWD',
  'NOK',
  'SEK',
  'DKK',
  'RUB',
  'CNY',
  'AED',
];
const DEFAULT_GOLD_SYMBOLS = [
  'HAS',
  'ONS',
  'AYAR22',
  'GRAM',
  'ALTINGUMUS',
  'CEYREK',
  'YARIM',
  'TAM',
  'CUMHURIYET',
  'GREMSE',
  'AYAR14',
  'GUMUS',
  'AYAR18',
  'RESAT',
  'ATA',
  'BESLI',
  'HAMIT',
  'IKIBUCUK',
];
const LEGACY_CURRENCY_SYMBOLS = 'USD,EUR,GBP,CHF';
const LEGACY_WIDE_CURRENCY_SYMBOLS = 'USD,EUR,GBP,CHF,CAD,AUD,JPY,SAR,KWD,NOK,SEK,DKK,RUB,CNY,AED';
const LEGACY_GOLD_SYMBOLS = 'GRAM,CEYREK,YARIM,TAM,ONS,HAS';
const DEFAULT_MARKET_SETTINGS = {
  enabled: true,
  provider: 'genelpara',
  altinApiKey: '',
  altinApiBaseUrl: 'https://altinapi.com/api/v1',
  genelParaBaseUrl: 'https://api.genelpara.com/json/',
  updateIntervalSeconds: 300,
  currencySymbols: DEFAULT_CURRENCY_SYMBOLS,
  goldSymbols: DEFAULT_GOLD_SYMBOLS,
};

type MarketProvider = 'auto' | 'altinapi' | 'genelpara';
type MarketKind = 'currency' | 'gold';

export type MarketSettings = {
  enabled: boolean;
  provider: MarketProvider;
  altinApiKey: string;
  altinApiBaseUrl: string;
  genelParaBaseUrl: string;
  updateIntervalSeconds: number;
  currencySymbols: string[];
  goldSymbols: string[];
};

export type MarketRatePayload = {
  id: string;
  kind: MarketKind;
  symbol: string;
  sourceSymbol: string;
  name: string;
  bid: number;
  ask: number;
  changeAmount: number | null;
  changePercent: number | null;
  isUp: boolean;
  currencyCode: string;
  currencySymbol: string;
  secondaryBid?: number;
  secondaryAsk?: number;
  secondaryCurrencyCode?: string;
  secondaryCurrencySymbol?: string;
  timestamp: string;
};

export type MarketsPayload = {
  enabled: boolean;
  provider: MarketProvider;
  source: string;
  serviceDateLabel: string;
  fetchedAt: string;
  updateIntervalSeconds: number;
  currencies: MarketRatePayload[];
  gold: MarketRatePayload[];
  cache: Record<string, unknown>;
  error?: string;
};

type CachedPayload = {
  key: string;
  expiresAt: number;
  payload: MarketsPayload;
};

let schemaReady: Promise<void> | null = null;
const memoryCache = new Map<string, CachedPayload>();

const CURRENCY_META: Record<string, { symbol: string; name: string }> = {
  USD: { symbol: 'USD', name: 'Amerikan Doları' },
  EUR: { symbol: 'EUR', name: 'Euro' },
  GBP: { symbol: 'GBP', name: 'İngiliz Sterlini' },
  CHF: { symbol: 'CHF', name: 'İsviçre Frangı' },
  CAD: { symbol: 'CAD', name: 'Kanada Doları' },
  AUD: { symbol: 'AUD', name: 'Avustralya Doları' },
  JPY: { symbol: 'JPY', name: 'Japon Yeni' },
  SAR: { symbol: 'SAR', name: 'Suudi Arabistan Riyali' },
  KWD: { symbol: 'KWD', name: 'Kuveyt Dinarı' },
  NOK: { symbol: 'NOK', name: 'Norveç Kronu' },
  SEK: { symbol: 'SEK', name: 'İsveç Kronu' },
  DKK: { symbol: 'DKK', name: 'Danimarka Kronu' },
  RUB: { symbol: 'RUB', name: 'Rus Rublesi' },
  CNY: { symbol: 'CNY', name: 'Çin Yuanı' },
  AED: { symbol: 'AED', name: 'BAE Dirhemi' },
  BTC: { symbol: 'BTC', name: 'Bitcoin' },
};

const GOLD_META: Record<string, { symbol: string; name: string; unit: string }> = {
  AYAR14: { symbol: '14 Ayar', name: 'TL / gram', unit: 'TRY' },
  AYAR18: { symbol: '18 Ayar', name: 'TL / gram', unit: 'TRY' },
  AYAR22: { symbol: '22 Ayar', name: 'TL / gram', unit: 'TRY' },
  GRAM: { symbol: 'Gram Altın', name: 'TL / gram', unit: 'TRY' },
  ONS: { symbol: 'Ons Altın', name: 'USD / ons', unit: 'USD' },
  CEYREK: { symbol: 'Çeyrek Altın', name: 'TL / adet', unit: 'TRY' },
  YARIM: { symbol: 'Yarım Altın', name: 'TL / adet', unit: 'TRY' },
  TAM: { symbol: 'Tam Altın', name: 'TL / adet', unit: 'TRY' },
  CUMHURIYET: { symbol: 'Cumhuriyet Altını', name: 'TL / adet', unit: 'TRY' },
  GREMSE: { symbol: 'Gremse Altın', name: 'TL / adet', unit: 'TRY' },
  HAS: { symbol: 'Has Altın', name: 'TL / gram', unit: 'TRY' },
  RESAT: { symbol: 'Reşat Altın', name: 'TL / adet', unit: 'TRY' },
  ATA: { symbol: 'Ata Altın', name: 'TL / adet', unit: 'TRY' },
  BESLI: { symbol: 'Beşli Altın', name: 'TL / adet', unit: 'TRY' },
  HAMIT: { symbol: 'Hamit Altın', name: 'TL / adet', unit: 'TRY' },
  IKIBUCUK: { symbol: 'İkibuçuk Altın', name: 'TL / adet', unit: 'TRY' },
  ALTINGUMUS: { symbol: 'Altın Gümüş', name: 'Altın / gümüş oranı', unit: 'USD' },
  GUMUS: { symbol: 'Gümüş TL', name: 'TL / gram', unit: 'TRY' },
};

const GENELPARA_CURRENCY_CODES = [
  'USD', 'EUR', 'GBP', 'CHF', 'CAD', 'RUB', 'AED', 'AUD', 'DKK', 'SEK',
  'NOK', 'JPY', 'KWD', 'ZAR', 'ALL', 'ARS', 'AZN', 'BAM', 'BGN', 'BHD',
  'BRL', 'CLP', 'CNY', 'COP', 'CRC', 'DZD', 'EGP', 'GEL', 'HKD', 'HUF',
  'IDR', 'INR', 'IQD', 'IRR', 'ISK', 'KRW', 'KZT', 'LBP', 'LKR', 'LYD',
  'MAD', 'MDL', 'MKD', 'MXN', 'MYR', 'NZD', 'OMR', 'PEN', 'PHP', 'PKR',
  'PLN', 'QAR', 'RON', 'RSD', 'SAR', 'SGD', 'SYP', 'THB', 'TND', 'TWD',
  'UAH', 'UYU', 'TRY',
];

const GENELPARA_CURRENCY: Record<string, string> = Object.fromEntries(
  GENELPARA_CURRENCY_CODES.map((symbol) => [symbol, symbol])
);

const GENELPARA_GOLD: Record<string, string> = {
  AYAR14: '14',
  AYAR18: '18',
  AYAR22: '22',
  GRAM: 'GA',
  ONS: 'XAUUSD',
  CEYREK: 'C',
  YARIM: 'Y',
  TAM: 'T',
  CUMHURIYET: 'CMR',
  GREMSE: 'GR',
  HAS: 'XHGLD',
  RESAT: 'RA',
  ATA: 'ATA',
  BESLI: 'BSL',
  HAMIT: 'HA',
  IKIBUCUK: 'IKB',
  ALTINGUMUS: 'XAUXAG',
  GUMUS: 'GAG',
};

const ALTINAPI_CURRENCY: Record<string, string> = {
  USD: 'USDTRY',
  EUR: 'EURTRY',
  GBP: 'GBPTRY',
  CHF: 'CHFTRY',
  CAD: 'CADTRY',
  AUD: 'AUDTRY',
};

const ALTINAPI_GOLD: Record<string, string> = {
  GRAM: 'ALTIN',
  CEYREK: 'CEYREK_YENI',
  YARIM: 'YARIM_YENI',
  TAM: 'TEK_YENI',
  ONS: 'XAUUSD',
  HAS: 'ALTIN',
  AYAR22: 'AYAR22',
};

const FRANKFURTER_CURRENCIES = new Set([
  'AUD', 'BGN', 'BRL', 'CAD', 'CHF', 'CNY', 'CZK', 'DKK', 'EUR', 'GBP',
  'HKD', 'HUF', 'IDR', 'ILS', 'INR', 'ISK', 'JPY', 'KRW', 'MXN', 'MYR',
  'NOK', 'NZD', 'PHP', 'PLN', 'RON', 'SEK', 'SGD', 'THB', 'TRY', 'USD',
  'ZAR',
]);

const TROY_OUNCE_GRAMS = 31.1034768;
const GOLD_SPOT_FACTORS: Record<string, number> = {
  HAS: 1,
  GRAM: 1,
  AYAR22: 22 / 24,
  AYAR18: 18 / 24,
  AYAR14: 14 / 24,
};

export const ensureMarketSettingsSchema = async () => {
  if (schemaReady) return schemaReady;
  schemaReady = (async () => {
    await ensureAppSchema();
    await dbQuery(`
      ALTER TABLE public.site_settings
        ADD COLUMN IF NOT EXISTS market_enabled boolean DEFAULT true,
        ADD COLUMN IF NOT EXISTS market_provider text DEFAULT 'genelpara',
        ADD COLUMN IF NOT EXISTS market_altinapi_key text,
        ADD COLUMN IF NOT EXISTS market_altinapi_base_url text DEFAULT 'https://altinapi.com/api/v1',
        ADD COLUMN IF NOT EXISTS market_genelpara_base_url text DEFAULT 'https://api.genelpara.com/json/',
        ADD COLUMN IF NOT EXISTS market_update_interval_seconds integer DEFAULT 300,
        ADD COLUMN IF NOT EXISTS market_currency_symbols text DEFAULT '${DEFAULT_CURRENCY_SYMBOLS.join(',')}',
        ADD COLUMN IF NOT EXISTS market_gold_symbols text DEFAULT '${DEFAULT_GOLD_SYMBOLS.join(',')}'
    `);
    await dbQuery(`
      ALTER TABLE public.site_settings
        ALTER COLUMN market_currency_symbols SET DEFAULT '${DEFAULT_CURRENCY_SYMBOLS.join(',')}',
        ALTER COLUMN market_gold_symbols SET DEFAULT '${DEFAULT_GOLD_SYMBOLS.join(',')}',
        ALTER COLUMN market_update_interval_seconds SET DEFAULT 300
    `);
    await dbQuery(
      `UPDATE public.site_settings
          SET market_currency_symbols = $1,
              updated_at = now()
        WHERE COALESCE(market_currency_symbols, '') IN ('', $2, $3)`,
      [
        DEFAULT_CURRENCY_SYMBOLS.join(','),
        LEGACY_CURRENCY_SYMBOLS,
        LEGACY_WIDE_CURRENCY_SYMBOLS,
      ]
    );
    await dbQuery(
      `UPDATE public.site_settings
          SET market_gold_symbols = $1,
              updated_at = now()
        WHERE COALESCE(market_gold_symbols, '') IN ('', $2)`,
      [DEFAULT_GOLD_SYMBOLS.join(','), LEGACY_GOLD_SYMBOLS]
    );
    await dbQuery(
      `UPDATE public.site_settings
          SET market_update_interval_seconds = 300,
              updated_at = now()
        WHERE COALESCE(market_update_interval_seconds, 0) < 300`
    );
  })().catch((error) => {
    schemaReady = null;
    throw error;
  });
  return schemaReady;
};

export const getMarketSettings = async (languageCode: string): Promise<MarketSettings> => {
  try {
    await ensureAppSchema();
    const selectSql = `
      SELECT
        market_enabled,
        market_provider,
        market_altinapi_key,
        market_altinapi_base_url,
        market_genelpara_base_url,
        market_update_interval_seconds,
        market_currency_symbols,
        market_gold_symbols
      FROM public.site_settings
      WHERE language_code = $1
      LIMIT 1
    `;
    const lang = cleanLanguageCode(languageCode);
    const result = await dbQuery<any>(selectSql, [lang]);
    let row = result.rows[0] || null;
    if (!row && lang !== 'tr') {
      const fallback = await dbQuery<any>(selectSql, ['tr']);
      row = fallback.rows[0] || null;
    }
    return marketSettingsFromRow(row);
  } catch {
    return { ...DEFAULT_MARKET_SETTINGS, provider: 'genelpara' };
  }
};

export const saveMarketSettings = async (
  languageCode: string,
  settings: Partial<MarketSettings>
) => {
  await ensureMarketSettingsSchema();
  const normalized = normalizeMarketSettings(settings);
  const result = await dbQuery(
    `INSERT INTO public.site_settings (
       language_code,
       market_enabled,
       market_provider,
       market_altinapi_key,
       market_altinapi_base_url,
       market_genelpara_base_url,
       market_update_interval_seconds,
       market_currency_symbols,
       market_gold_symbols,
       updated_at
     )
     VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, now())
     ON CONFLICT (language_code) DO UPDATE SET
       market_enabled = EXCLUDED.market_enabled,
       market_provider = EXCLUDED.market_provider,
       market_altinapi_key = EXCLUDED.market_altinapi_key,
       market_altinapi_base_url = EXCLUDED.market_altinapi_base_url,
       market_genelpara_base_url = EXCLUDED.market_genelpara_base_url,
       market_update_interval_seconds = EXCLUDED.market_update_interval_seconds,
       market_currency_symbols = EXCLUDED.market_currency_symbols,
       market_gold_symbols = EXCLUDED.market_gold_symbols,
       updated_at = now()
     RETURNING
       market_enabled,
       market_provider,
       market_altinapi_key,
       market_altinapi_base_url,
       market_genelpara_base_url,
       market_update_interval_seconds,
       market_currency_symbols,
       market_gold_symbols`,
    [
      cleanLanguageCode(languageCode),
      normalized.enabled,
      normalized.provider,
      normalized.altinApiKey,
      normalized.altinApiBaseUrl,
      normalized.genelParaBaseUrl,
      normalized.updateIntervalSeconds,
      normalized.currencySymbols.join(','),
      normalized.goldSymbols.join(','),
    ]
  );
  return marketSettingsFromRow(result.rows[0]);
};

export const invalidateMarketsCache = async (languageCode: string) => {
  const lang = cleanLanguageCode(languageCode);
  for (const key of Array.from(memoryCache.keys())) {
    if (key.startsWith(`markets:${lang}:`) || key.startsWith('sidebar:')) {
      memoryCache.delete(key);
    }
  }
  try {
    await dbQuery(`DELETE FROM public.app_cache WHERE key LIKE $1 OR key = $2`, [
      `markets:${lang}:%`,
      `sidebar:${lang}`,
    ]);
  } catch {
    // Cache cleanup is best effort; the next expiry will rebuild it.
  }
};

export const fetchMarketsPayload = async (
  languageCode: string,
  forceRefresh = false
): Promise<MarketsPayload> => {
  const settings = await getMarketSettings(languageCode);
  const key = marketCacheKey(languageCode, settings);
  const intervalMs = Math.max(
    MIN_REFRESH_SECONDS,
    settings.updateIntervalSeconds
  ) * 1000;
  const now = Date.now();
  const hot = memoryCache.get(key);
  if (hot && hot.expiresAt > now) {
    return withCacheInfo(hot.payload, true, false, 'memory', intervalMs, forceRefresh);
  }
  const stored = await readCache(key);
  if (stored && stored.expiresAt > now) {
    memoryCache.set(key, { key, payload: stored.payload, expiresAt: stored.expiresAt });
    return withCacheInfo(stored.payload, true, false, 'database', intervalMs, forceRefresh);
  }

  // ASIL KÖK NEDEN: workerd/Cloudflare Workers, bir isteğin context'inde oluşturulan
  // promise'i başka bir istekte sürdüremez ("cross-request promise resolution" →
  // continuation iptal edilir). Eski refreshInFlight, bir isteğin promise'ini saklayıp
  // başka isteklere döndürdüğü için o istekler SONSUZA kilitleniyor ve istemcide 18sn
  // TimeoutException oluşuyordu. Çözüm: istekler-arası promise paylaşımını kaldır — her
  // istek taze veriyi kendi context'inde çeker; tekrarlı sağlayıcı çağrısını zaten
  // cache (memory + DB) önler, üst-zaman sınırı da takılmayı engeller.
  const payload = await withHardTimeout(
    fetchMarketsFresh(settings, stored?.payload),
    FRESH_TOTAL_TIMEOUT_MS,
    () => timeoutFallbackPayload(settings, stored?.payload)
  );
  // Başarılı yanıt tam aralık kadar, hatalı/zaman aşımı yanıtı kısa süre cache'lenir.
  writeCacheLater(key, payload, payload.error ? ERROR_CACHE_MS : intervalMs);
  return payload;
};

// fetchMarketsFresh hiçbir zaman reject etmez (içeride yakalar); yine de güvenli
// olması için reject'i de zaman aşımı yedeğine düşürürüz. Zamanlayıcı dolarsa
// arkadaki fetch arka planda bitebilir, ama istek bloke olmadan yanıt döner.
const withHardTimeout = <T>(
  promise: Promise<T>,
  ms: number,
  onTimeout: () => T
): Promise<T> =>
  new Promise<T>((resolve) => {
    let settled = false;
    const finish = (value: T) => {
      if (settled) return;
      settled = true;
      resolve(value);
    };
    const timer = setTimeout(() => finish(onTimeout()), ms);
    promise.then(
      (value) => {
        clearTimeout(timer);
        finish(value);
      },
      () => {
        clearTimeout(timer);
        finish(onTimeout());
      }
    );
  });

const timeoutFallbackPayload = (
  settings: MarketSettings,
  stalePayload?: MarketsPayload
): MarketsPayload => {
  const reason = 'Piyasa verisi zaman aşımına uğradı';
  if (stalePayload) {
    return {
      ...stalePayload,
      cache: {
        ...(stalePayload.cache || {}),
        hit: true,
        stale: true,
        refreshFailed: reason,
      },
    };
  }
  return {
    ...buildPayload(settings, settings.provider, [], [], {
      hit: false,
      stale: true,
      source: 'none',
    }),
    error: reason,
  };
};

const fetchMarketsFresh = async (
  settings: MarketSettings,
  stalePayload?: MarketsPayload
): Promise<MarketsPayload> => {
  if (!settings.enabled) {
    return buildPayload(settings, 'disabled', [], [], {
      hit: false,
      stale: false,
      source: 'disabled',
    });
  }

  const attempts: Array<'altinapi' | 'genelpara'> = [];
  if ((settings.provider === 'auto' || settings.provider === 'altinapi') && settings.altinApiKey.trim()) {
    attempts.push('altinapi');
  }
  if (settings.provider === 'auto' || settings.provider === 'genelpara' || attempts.length === 0) {
    attempts.push('genelpara');
  }
  if (settings.provider === 'altinapi' && !attempts.includes('genelpara')) {
    attempts.push('genelpara');
  }

  let lastError = '';
  for (const provider of attempts) {
    try {
      const result = provider === 'altinapi'
        ? await fetchAltinApi(settings)
        : await fetchGenelPara(settings);
      return buildPayload(settings, provider, result.currencies, result.gold, {
        hit: false,
        stale: false,
        source: result.source,
        remaining: result.remaining,
        fallback: provider !== settings.provider && settings.provider !== 'auto',
      });
    } catch (error) {
      lastError = error instanceof Error ? error.message : String(error);
    }
  }

  try {
    const fallback = await fetchPublicMarketFallback(settings);
    if (fallback.currencies.length || fallback.gold.length) {
      return buildPayload(settings, settings.provider, fallback.currencies, fallback.gold, {
        hit: false,
        stale: false,
        source: fallback.source,
        fallback: true,
        failedProvider: lastError || undefined,
      });
    }
  } catch (error) {
    lastError = error instanceof Error ? error.message : String(error);
  }

  if (stalePayload) {
    return {
      ...stalePayload,
      cache: {
        ...(stalePayload.cache || {}),
        hit: true,
        stale: true,
        refreshFailed: lastError || 'Piyasa verisi yenilenemedi',
      },
    };
  }
  return {
    ...buildPayload(settings, settings.provider, [], [], {
      hit: false,
      stale: true,
      source: 'none',
    }),
    error: lastError || 'Piyasa verisi alınamadı',
  };
};

const fetchAltinApi = async (settings: MarketSettings) => {
  const url = new URL('/api/v1/prices', ensureTrailingSlash(settings.altinApiBaseUrl));
  const wantsBitcoin = settings.currencySymbols.some((symbol) => symbol === 'BTC');
  const [response, bitcoin] = await Promise.all([
    fetchWithTimeout(url.toString(), {
      headers: {
        Accept: 'application/json',
        'X-API-Key': settings.altinApiKey.trim(),
      },
    }),
    wantsBitcoin ? fetchBitcoinTry() : Promise.resolve(null),
  ]);
  if (!response.ok) throw new Error(`AltinAPI ${response.status}`);
  const decoded: any = await response.json();
  const rows = Array.isArray(decoded?.data) ? decoded.data : [];
  const currencies = orderCurrencyRates(settings.currencySymbols, [
    ...normalizeAltinApiRows(settings.currencySymbols, rows, 'currency'),
    ...(bitcoin ? [bitcoin] : []),
  ]);
  const gold = normalizeAltinApiRows(settings.goldSymbols, rows, 'gold');
  if (!currencies.length && !gold.length) throw new Error('AltinAPI empty response');
  return {
    source: bitcoin ? 'AltinAPI + BTC' : 'AltinAPI',
    remaining: response.headers.get('x-ratelimit-remaining') || null,
    currencies,
    gold,
  };
};

const fetchGenelPara = async (settings: MarketSettings) => {
  const wantsBitcoin = settings.currencySymbols.some((symbol) => symbol === 'BTC');
  const currencyMap = providerSymbols(
    settings.currencySymbols.filter((symbol) => symbol !== 'BTC'),
    GENELPARA_CURRENCY
  );
  const currencyProviderSymbols = new Set(Object.values(currencyMap));
  if (wantsBitcoin) currencyProviderSymbols.add('USD');
  const goldMap = providerSymbols(settings.goldSymbols, GENELPARA_GOLD);
  const [currencyResponse, goldResponse, cryptoResponse] = await Promise.all([
    fetchGenelParaList(settings.genelParaBaseUrl, 'doviz', Array.from(currencyProviderSymbols)),
    fetchGenelParaList(settings.genelParaBaseUrl, 'altin', Object.values(goldMap)),
    wantsBitcoin ? fetchGenelParaList(settings.genelParaBaseUrl, 'kripto', ['BTC']) : Promise.resolve(null),
  ]);
  const bitcoin = wantsBitcoin
    ? normalizeGenelParaBitcoin(cryptoResponse?.data?.BTC, currencyResponse.data?.USD)
    : null;
  const currencies = orderCurrencyRates(settings.currencySymbols, [
    ...normalizeGenelParaRows(currencyMap, currencyResponse.data, 'currency'),
    ...(bitcoin ? [bitcoin] : []),
  ]);
  const gold = normalizeGenelParaRows(goldMap, goldResponse.data, 'gold');
  if (!currencies.length && !gold.length) throw new Error('GenelPara empty response');
  return {
    source: 'GenelPara',
    remaining: Math.min(currencyResponse.remaining ?? 999, goldResponse.remaining ?? 999),
    currencies,
    gold,
  };
};

const fetchGenelParaList = async (
  baseUrl: string,
  list: string,
  symbols: string[]
) => {
  const url = new URL(ensureTrailingSlash(baseUrl));
  url.searchParams.set('list', list);
  url.searchParams.set('sembol', symbols.length ? symbols.join(',') : 'all');
  const response = await fetchWithTimeout(url.toString(), {
    headers: { Accept: 'application/json' },
  });
  if (!response.ok) throw new Error(`GenelPara ${response.status}`);
  const decoded: any = await response.json();
  if (decoded?.success !== true || !decoded?.data) {
    throw new Error('GenelPara invalid response');
  }
  return {
    data: decoded.data,
    remaining: asNumber(decoded.remaining, 999),
  };
};

const fetchBitcoinTry = async () => {
  try {
    const binanceResponse = await fetchWithTimeout(
      'https://api.binance.com/api/v3/ticker/24hr?symbol=BTCTRY',
      { headers: { Accept: 'application/json' } }
    );
    if (binanceResponse.ok) {
      const decoded: any = await binanceResponse.json();
      const lastPrice = asNumber(decoded?.lastPrice, 0);
      if (lastPrice) {
        return marketRate({
          canonical: 'BTC',
          sourceSymbol: 'BTCTRY',
          kind: 'currency',
          bid: asNumber(decoded?.bidPrice, lastPrice),
          ask: asNumber(decoded?.askPrice, lastPrice),
          changeAmount: asNullableNumber(decoded?.priceChange),
          changePercent: asNullableNumber(decoded?.priceChangePercent),
          isUp: asNumber(decoded?.priceChangePercent, 0) >= 0,
          currencyCode: 'TRY',
          timestamp: new Date().toISOString(),
        });
      }
    }
    const response = await fetchWithTimeout(
      'https://api.coingecko.com/api/v3/simple/price?ids=bitcoin&vs_currencies=try&include_24hr_change=true',
      { headers: { Accept: 'application/json', 'User-Agent': 'Pateez/1.0' } }
    );
    if (!response.ok) return null;
    const decoded: any = await response.json();
    const price = asNumber(decoded?.bitcoin?.try, 0);
    if (!price) return null;
    const changePercent = asNullableNumber(decoded?.bitcoin?.try_24h_change);
    return marketRate({
      canonical: 'BTC',
      sourceSymbol: 'BTC',
      kind: 'currency',
      bid: price,
      ask: price,
      changeAmount: null,
      changePercent,
      isUp: (changePercent ?? 0) >= 0,
      currencyCode: 'TRY',
      timestamp: new Date().toISOString(),
    });
  } catch {
    return null;
  }
};

const fetchPublicMarketFallback = async (settings: MarketSettings) => {
  const wantsBitcoin = settings.currencySymbols.some((symbol) => symbol === 'BTC');
  const [fiatResult, bitcoin] = await Promise.all([
    fetchFrankfurterTryRates(settings.currencySymbols),
    wantsBitcoin ? fetchBitcoinTry() : Promise.resolve(null),
  ]);
  const [xau, xag] = await Promise.all([
    fetchGoldApiPrice('XAU', 3500).catch(() => null),
    fetchGoldApiPrice('XAG', 2200).catch(() => null),
  ]);
  const currencies = orderCurrencyRates(settings.currencySymbols, [
    ...fiatResult.currencies,
    ...(bitcoin ? [bitcoin] : []),
  ]);
  const gold = orderGoldRates(settings.goldSymbols, buildGoldFallbackRates(
    settings.goldSymbols,
    fiatResult.usdTry,
    xau,
    xag
  ));
  if (!currencies.length && !gold.length) {
    throw new Error('Fallback market sources returned no usable rates');
  }
  const sources = ['Frankfurter'];
  if (xau) sources.push('Gold API');
  if (bitcoin) sources.push('BTC');
  return { source: sources.join(' + '), currencies, gold };
};

const fetchFrankfurterTryRates = async (symbols: string[]) => {
  const fiatSymbols = Array.from(new Set(
    symbols
      .filter((symbol) => symbol !== 'BTC')
      .filter((symbol) => symbol === 'USD' || FRANKFURTER_CURRENCIES.has(symbol))
  ));
  const toSymbols = Array.from(new Set([
    'TRY',
    ...fiatSymbols.filter((symbol) => symbol !== 'USD' && symbol !== 'TRY'),
  ]));
  const url = new URL('https://api.frankfurter.app/latest');
  url.searchParams.set('from', 'USD');
  url.searchParams.set('to', toSymbols.join(','));
  const response = await fetchWithTimeoutMs(url.toString(), {
    headers: { Accept: 'application/json' },
  }, 3500);
  if (!response.ok) throw new Error(`Frankfurter ${response.status}`);
  const decoded: any = await response.json();
  const rates = decoded?.rates || {};
  const usdTry = asNumber(rates.TRY, 0);
  if (!usdTry) throw new Error('Frankfurter missing TRY rate');
  const timestamp = dateTimestamp(decoded?.date);
  const currencies = fiatSymbols.flatMap((symbol) => {
    const ask = symbol === 'USD'
      ? usdTry
      : usdTry / asNumber(rates[symbol], 0);
    if (!Number.isFinite(ask) || ask <= 0) return [];
    return [marketRate({
      canonical: symbol,
      sourceSymbol: `${symbol}TRY`,
      kind: 'currency',
      bid: ask,
      ask,
      changeAmount: null,
      changePercent: null,
      isUp: true,
      currencyCode: 'TRY',
      timestamp,
    })];
  });
  return { usdTry, currencies };
};

const fetchGoldApiPrice = async (symbol: 'XAU' | 'XAG', timeoutMs: number) => {
  const response = await fetchWithTimeoutMs(`https://api.gold-api.com/price/${symbol}`, {
    headers: { Accept: 'application/json' },
  }, timeoutMs);
  if (!response.ok) throw new Error(`Gold API ${symbol} ${response.status}`);
  const decoded: any = await response.json();
  const price = asNumber(decoded?.price, 0);
  if (!price) throw new Error(`Gold API ${symbol} missing price`);
  return {
    price,
    timestamp: timestampFrom(decoded?.updatedAt),
  };
};

const buildGoldFallbackRates = (
  symbols: string[],
  usdTry: number,
  xau: { price: number; timestamp: string } | null,
  xag: { price: number; timestamp: string } | null
) => {
  if (!xau?.price || !usdTry) return [];
  const gramTry = xau.price * usdTry / TROY_OUNCE_GRAMS;
  return symbols.flatMap((symbol) => {
    if (symbol === 'ONS') {
      return [marketRate({
        canonical: symbol,
        sourceSymbol: 'XAUUSD',
        kind: 'gold',
        bid: xau.price,
        ask: xau.price,
        changeAmount: null,
        changePercent: null,
        isUp: true,
        currencyCode: 'USD',
        timestamp: xau.timestamp,
      })];
    }
    if (symbol === 'GUMUS' && xag?.price) {
      const silverGramTry = xag.price * usdTry / TROY_OUNCE_GRAMS;
      return [marketRate({
        canonical: symbol,
        sourceSymbol: 'XAGTRY',
        kind: 'gold',
        bid: silverGramTry,
        ask: silverGramTry,
        changeAmount: null,
        changePercent: null,
        isUp: true,
        currencyCode: 'TRY',
        timestamp: xag.timestamp,
      })];
    }
    const factor = GOLD_SPOT_FACTORS[symbol];
    if (!factor) return [];
    const ask = gramTry * factor;
    return [marketRate({
      canonical: symbol,
      sourceSymbol: symbol === 'GRAM' ? 'XAUTRYG' : `XAUTRYG:${symbol}`,
      kind: 'gold',
      bid: ask,
      ask,
      changeAmount: null,
      changePercent: null,
      isUp: true,
      currencyCode: 'TRY',
      timestamp: xau.timestamp,
    })];
  });
};

const normalizeAltinApiRows = (
  canonicalSymbols: string[],
  rows: any[],
  kind: MarketKind
) => {
  const map = providerSymbols(
    canonicalSymbols,
    kind === 'currency' ? ALTINAPI_CURRENCY : ALTINAPI_GOLD
  );
  return Object.entries(map).flatMap(([canonical, providerSymbol]) => {
    const row = rows.find((item) =>
      String(item?.symbol || '').toUpperCase() === providerSymbol.toUpperCase()
    );
    if (!row) return [];
    const bid = asNumber(row.bid, 0);
    const ask = asNumber(row.ask, bid);
    if (!bid && !ask) return [];
    return [
      marketRate({
        canonical,
        sourceSymbol: providerSymbol,
        kind,
        bid,
        ask,
        changeAmount: null,
        changePercent: null,
        isUp: true,
        currencyCode: kind === 'gold' ? goldCurrency(canonical) : 'TRY',
        timestamp: timestampFrom(row.timestamp),
      }),
    ];
  });
};

const normalizeGenelParaRows = (
  map: Record<string, string>,
  data: Record<string, any>,
  kind: MarketKind
) => Object.entries(map).flatMap(([canonical, providerSymbol]) => {
  const row = data?.[providerSymbol];
  if (!row) return [];
  const bid = asNumber(row.alis, 0);
  const ask = asNumber(row.satis, bid);
  if (!bid && !ask) return [];
  const changePercent = asNullableNumber(row.degisim);
  return [
    marketRate({
      canonical,
      sourceSymbol: providerSymbol,
      kind,
      bid,
      ask,
      changeAmount: asNullableNumber(row.oran),
      changePercent,
      isUp: String(row.yon || '').toLowerCase() !== 'moneydown',
      currencyCode: asString(row.kur, kind === 'gold' ? goldCurrency(canonical) : 'TRY'),
      timestamp: new Date().toISOString(),
    }),
  ];
});

const normalizeGenelParaBitcoin = (btcRow: any, usdRow: any) => {
  if (!btcRow) return null;
  const sourceCurrency = asString(btcRow.kur, 'USD').toUpperCase();
  const usdBid = asNumber(usdRow?.alis, 0);
  const usdAsk = asNumber(usdRow?.satis, usdBid);
  const multiplierBid = sourceCurrency === 'TRY' ? 1 : usdBid;
  const multiplierAsk = sourceCurrency === 'TRY' ? 1 : usdAsk;
  if (!multiplierBid || !multiplierAsk) return null;
  const sourceBid = asNumber(btcRow.alis, 0);
  const sourceAsk = asNumber(btcRow.satis, sourceBid);
  const bid = sourceBid * multiplierBid;
  const ask = sourceAsk * multiplierAsk;
  if (!bid && !ask) return null;
  const changeAmount = asNullableNumber(btcRow.oran);
  const secondaryBid = sourceCurrency === 'USD'
    ? sourceBid
    : sourceCurrency === 'TRY' && usdBid
      ? sourceBid / usdBid
      : null;
  const secondaryAsk = sourceCurrency === 'USD'
    ? sourceAsk
    : sourceCurrency === 'TRY' && usdAsk
      ? sourceAsk / usdAsk
      : null;
  return marketRate({
    canonical: 'BTC',
    sourceSymbol: 'BTC',
    kind: 'currency',
    bid,
    ask,
    changeAmount: changeAmount == null ? null : changeAmount * multiplierAsk,
    changePercent: asNullableNumber(btcRow.degisim),
    isUp: String(btcRow.yon || '').toLowerCase() !== 'moneydown',
    currencyCode: 'TRY',
    secondaryBid,
    secondaryAsk,
    secondaryCurrencyCode: secondaryAsk ? 'USD' : null,
    timestamp: new Date().toISOString(),
  });
};

const orderCurrencyRates = (
  symbols: string[],
  rates: MarketRatePayload[]
) => {
  const byCanonical = new Map(
    rates.map((rate) => [rate.id.replace(/^currency:/, ''), rate])
  );
  return symbols.flatMap((symbol) => {
    const rate = byCanonical.get(symbol);
    return rate ? [rate] : [];
  });
};

const orderGoldRates = (
  symbols: string[],
  rates: MarketRatePayload[]
) => {
  const byCanonical = new Map(
    rates.map((rate) => [rate.id.replace(/^gold:/, ''), rate])
  );
  return symbols.flatMap((symbol) => {
    const rate = byCanonical.get(symbol);
    return rate ? [rate] : [];
  });
};

const currencySymbolFor = (currencyCode: string) =>
  currencyCode.toUpperCase() === 'USD' ? '$' : '₺';

const marketRate = (input: {
  canonical: string;
  sourceSymbol: string;
  kind: MarketKind;
  bid: number;
  ask: number;
  changeAmount: number | null;
  changePercent: number | null;
  isUp: boolean;
  currencyCode: string;
  secondaryBid?: number | null;
  secondaryAsk?: number | null;
  secondaryCurrencyCode?: string | null;
  timestamp: string;
}): MarketRatePayload => {
  const meta = input.kind === 'currency'
    ? CURRENCY_META[input.canonical] || { symbol: input.canonical, name: input.canonical }
    : GOLD_META[input.canonical] || { symbol: input.canonical, name: input.canonical };
  const secondaryCurrencyCode = asString(input.secondaryCurrencyCode).toUpperCase();
  const hasSecondary = input.secondaryBid != null && input.secondaryAsk != null && secondaryCurrencyCode;
  return {
    id: `${input.kind}:${input.canonical}`,
    kind: input.kind,
    symbol: meta.symbol,
    sourceSymbol: input.sourceSymbol,
    name: meta.name,
    bid: round(input.bid, 4),
    ask: round(input.ask, 4),
    changeAmount: input.changeAmount == null ? null : round(input.changeAmount, 4),
    changePercent: input.changePercent == null ? null : round(input.changePercent, 4),
    isUp: input.isUp,
    currencyCode: input.currencyCode,
    currencySymbol: currencySymbolFor(input.currencyCode),
    ...(hasSecondary ? {
      secondaryBid: round(input.secondaryBid as number, 4),
      secondaryAsk: round(input.secondaryAsk as number, 4),
      secondaryCurrencyCode,
      secondaryCurrencySymbol: currencySymbolFor(secondaryCurrencyCode),
    } : {}),
    timestamp: input.timestamp,
  };
};

const buildPayload = (
  settings: MarketSettings,
  provider: string,
  currencies: MarketRatePayload[],
  gold: MarketRatePayload[],
  cache: Record<string, unknown>
): MarketsPayload => ({
  enabled: settings.enabled,
  provider: provider as MarketProvider,
  source: String(cache.source || '') || (provider === 'altinapi'
    ? 'AltinAPI'
    : provider === 'genelpara'
      ? 'GenelPara'
      : provider),
  serviceDateLabel: localDateLabel(),
  fetchedAt: new Date().toISOString(),
  updateIntervalSeconds: Math.max(MIN_REFRESH_SECONDS, settings.updateIntervalSeconds),
  currencies,
  gold,
  cache,
});

const withCacheInfo = (
  payload: MarketsPayload,
  hit: boolean,
  stale: boolean,
  source: string,
  intervalMs: number,
  throttled: boolean
): MarketsPayload => ({
  ...payload,
  cache: {
    ...(payload.cache || {}),
    hit,
    stale,
    source,
    refreshIntervalSeconds: Math.round(intervalMs / 1000),
    throttled,
  },
});

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

const writeCacheLater = (key: string, payload: MarketsPayload, intervalMs: number) => {
  const expiresAt = Date.now() + intervalMs;
  memoryCache.set(key, { key, payload, expiresAt });
  void (async () => {
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
      // Cache write must never block live market responses.
    }
  })();
};

const marketCacheKey = (languageCode: string, settings: MarketSettings) => [
  'markets',
  cleanLanguageCode(languageCode),
  settings.provider,
  settings.currencySymbols.join('-'),
  settings.goldSymbols.join('-'),
  settings.updateIntervalSeconds,
].join(':');

const marketSettingsFromRow = (row: any): MarketSettings => normalizeMarketSettings({
  enabled: row?.market_enabled !== false,
  provider: row?.market_provider,
  altinApiKey: row?.market_altinapi_key,
  altinApiBaseUrl: row?.market_altinapi_base_url,
  genelParaBaseUrl: row?.market_genelpara_base_url,
  updateIntervalSeconds: row?.market_update_interval_seconds,
  currencySymbols: splitSymbols(row?.market_currency_symbols, DEFAULT_MARKET_SETTINGS.currencySymbols, 'currency'),
  goldSymbols: splitSymbols(row?.market_gold_symbols, DEFAULT_MARKET_SETTINGS.goldSymbols, 'gold'),
});

const normalizeMarketSettings = (settings: Partial<MarketSettings>): MarketSettings => {
  const provider = normalizeProvider(settings.provider);
  return {
    enabled: settings.enabled !== false,
    provider,
    altinApiKey: asString(settings.altinApiKey),
    altinApiBaseUrl: asString(settings.altinApiBaseUrl, DEFAULT_MARKET_SETTINGS.altinApiBaseUrl),
    genelParaBaseUrl: asString(settings.genelParaBaseUrl, DEFAULT_MARKET_SETTINGS.genelParaBaseUrl),
    updateIntervalSeconds: Math.max(
      MIN_REFRESH_SECONDS,
      Math.round(asNumber(settings.updateIntervalSeconds, DEFAULT_MARKET_SETTINGS.updateIntervalSeconds))
    ),
    currencySymbols: splitSymbols(settings.currencySymbols, DEFAULT_MARKET_SETTINGS.currencySymbols, 'currency'),
    goldSymbols: splitSymbols(settings.goldSymbols, DEFAULT_MARKET_SETTINGS.goldSymbols, 'gold'),
  };
};

const normalizeProvider = (value: unknown): MarketProvider => {
  const provider = String(value || '').trim().toLowerCase();
  if (provider === 'auto' || provider === 'altinapi' || provider === 'genelpara') return provider;
  return 'genelpara';
};

const splitSymbols = (
  value: unknown,
  fallback: string[],
  kind: MarketKind
) => {
  const raw = Array.isArray(value) ? value.join(',') : String(value || '');
  const parts = raw
    .split(',')
    .map((item) => normalizeCanonicalSymbol(item, kind))
    .filter(Boolean);
  return Array.from(new Set(parts.length ? parts : fallback));
};

const normalizeCanonicalSymbol = (value: unknown, kind: MarketKind) => {
  const symbol = String(value || '').trim().toUpperCase().replace(/\s+/g, '');
  if (!symbol) return '';
  if (kind === 'currency') return symbol.replace(/TRY$/, '');
  if (['GA', 'ALTIN', 'GRAMALTIN'].includes(symbol)) return 'GRAM';
  if (['C', 'CEYREK_YENI', 'CEYREK'].includes(symbol)) return 'CEYREK';
  if (['Y', 'YARIM_YENI', 'YARIM'].includes(symbol)) return 'YARIM';
  if (['T', 'TEK_YENI', 'TAM'].includes(symbol)) return 'TAM';
  if (['XAUUSD', 'ONS'].includes(symbol)) return 'ONS';
  if (['XHGLD', 'HAS'].includes(symbol)) return 'HAS';
  if (['22', 'AYAR22'].includes(symbol)) return 'AYAR22';
  if (['18', 'AYAR18'].includes(symbol)) return 'AYAR18';
  if (['14', 'AYAR14'].includes(symbol)) return 'AYAR14';
  if (['CMR', 'CUMHURIYET', 'CUMHURIYETALTINI'].includes(symbol)) return 'CUMHURIYET';
  if (['GR', 'GREMSE', 'GREMSEALTIN'].includes(symbol)) return 'GREMSE';
  if (['RA', 'RESAT', 'RESATALTIN'].includes(symbol)) return 'RESAT';
  if (['ATA', 'ATAALTIN'].includes(symbol)) return 'ATA';
  if (['BSL', 'BESLI', 'BESLIALTIN'].includes(symbol)) return 'BESLI';
  if (['HA', 'HAMIT', 'HAMITALTIN'].includes(symbol)) return 'HAMIT';
  if (['IKB', 'IKIBUCUK', 'IKIBUCUKALTIN'].includes(symbol)) return 'IKIBUCUK';
  if (['XAUXAG', 'ALTINGUMUS'].includes(symbol)) return 'ALTINGUMUS';
  if (['GAG', 'GUMUS', 'GUMUSTL'].includes(symbol)) return 'GUMUS';
  return symbol;
};

const providerSymbols = (
  canonicalSymbols: string[],
  mapping: Record<string, string>
) => Object.fromEntries(
  canonicalSymbols
    .map((symbol) => [symbol, mapping[symbol]] as const)
    .filter((entry): entry is readonly [string, string] => Boolean(entry[1]))
);

const fetchWithTimeout = async (url: string, init: RequestInit) =>
  fetchWithTimeoutMs(url, init, FETCH_TIMEOUT_MS);

const fetchWithTimeoutMs = async (url: string, init: RequestInit, timeoutMs: number) =>
  fetch(url, { ...init, signal: AbortSignal.timeout(timeoutMs) });

const ensureTrailingSlash = (value: string) => {
  const text = asString(value);
  return text.endsWith('/') ? text : `${text}/`;
};

const cleanLanguageCode = (value: string) =>
  String(value || 'tr').trim().toLowerCase().replaceAll('_', '-') || 'tr';

const localDateLabel = () =>
  new Intl.DateTimeFormat('tr-TR', {
    timeZone: 'Europe/Istanbul',
    day: 'numeric',
    month: 'long',
    year: 'numeric',
    weekday: 'long',
  }).format(new Date());

const timestampFrom = (value: unknown) => {
  const numeric = Number(value);
  if (Number.isFinite(numeric) && numeric > 0) return new Date(numeric).toISOString();
  const parsed = Date.parse(String(value || ''));
  if (Number.isFinite(parsed)) return new Date(parsed).toISOString();
  return new Date().toISOString();
};

const dateTimestamp = (value: unknown) => {
  const text = asString(value);
  if (!/^\d{4}-\d{2}-\d{2}$/.test(text)) return new Date().toISOString();
  return new Date(`${text}T12:00:00.000Z`).toISOString();
};

const goldCurrency = (canonical: string) => canonical === 'ONS' ? 'USD' : 'TRY';

const asString = (value: unknown, fallback = '') => {
  const text = String(value || '').trim();
  return text || fallback;
};

const asNumber = (value: unknown, fallback: number) => {
  const parsed = Number(String(value ?? '').replace(',', '.'));
  return Number.isFinite(parsed) ? parsed : fallback;
};

const asNullableNumber = (value: unknown) => {
  const parsed = Number(String(value ?? '').replace(',', '.'));
  return Number.isFinite(parsed) ? parsed : null;
};

const round = (value: number, digits = 2) => Number(value.toFixed(digits));
