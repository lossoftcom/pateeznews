import type { APIRoute } from 'astro';
import { ensureAppSchema, json } from '@/lib/server/appDb';
import { dbQuery } from '@/lib/server/supabaseDb';

const WEATHER_REFRESH_MS = 30 * 60 * 1000;
const SIDEBAR_FETCH_TIMEOUT_MS = 7000;
const SIDEBAR_REFRESH_LOCK_MS = 15_000;
const DEFAULT_WEATHER = {
  enabled: true,
  location: 'Niğde',
  country: 'Türkiye',
  latitude: 37.96583,
  longitude: 34.67935,
  timezone: 'Europe/Istanbul',
};

type WeatherSettings = typeof DEFAULT_WEATHER & {
  updateIntervalMinutes: number;
};

type WeatherCacheEntry = {
  key: string;
  expiresAt: number;
  data: any;
};

let weatherCache: WeatherCacheEntry | null = null;
const refreshInFlight = new Map<string, { promise: Promise<any>; startedAt: number }>();

async function fetchJson<T>(url: string, timeoutMs = SIDEBAR_FETCH_TIMEOUT_MS): Promise<T | null> {
  let timeout: ReturnType<typeof setTimeout> | null = null;
  const request = (async () => {
    const response = await fetch(url, {
      signal: AbortSignal.timeout(timeoutMs),
      headers: { Accept: 'application/json' },
    });
    if (!response.ok) return null;
    return await response.json() as T;
  })();

  try {
    return await Promise.race([
      request,
      new Promise<null>((resolve) => {
        timeout = setTimeout(() => {
          resolve(null);
        }, timeoutMs);
      }),
    ]);
  } catch {
    return null;
  } finally {
    if (timeout) clearTimeout(timeout);
  }
}

const round = (value: number, digits = 2) => Number.isFinite(value) ? Number(value.toFixed(digits)) : 0;

const asFiniteNumber = (value: unknown, fallback: number) => {
  const numeric = Number(value);
  return Number.isFinite(numeric) ? numeric : fallback;
};

const ensureSidebarCacheSchema = async () => {
  await ensureAppSchema();
};

const getWeatherSettings = async (languageCode: string): Promise<WeatherSettings> => {
  try {
    await ensureAppSchema();

    const selectSql = `
      SELECT
        weather_enabled,
        weather_location_name,
        weather_location_country,
        weather_latitude,
        weather_longitude,
        weather_timezone,
        weather_update_interval_minutes
      FROM public.site_settings
      WHERE language_code = $1
      LIMIT 1
    `;

    const lang = String(languageCode || 'tr').trim() || 'tr';
    const result = await dbQuery<any>(selectSql, [lang]);
    let row = result.rows[0] || null;

    if (!row && lang !== 'tr') {
      const fallbackResult = await dbQuery<any>(selectSql, ['tr']);
      row = fallbackResult.rows[0] || null;
    }

    if (!row) {
      const anyResult = await dbQuery<any>(`
        SELECT
          weather_enabled,
          weather_location_name,
          weather_location_country,
          weather_latitude,
          weather_longitude,
          weather_timezone,
          weather_update_interval_minutes
        FROM public.site_settings
        ORDER BY created_at ASC
        LIMIT 1
      `);
      row = anyResult.rows[0] || null;
    }

    return {
      enabled: row?.weather_enabled !== false,
      location: String(row?.weather_location_name || DEFAULT_WEATHER.location).trim() || DEFAULT_WEATHER.location,
      country: String(row?.weather_location_country || DEFAULT_WEATHER.country).trim() || DEFAULT_WEATHER.country,
      latitude: asFiniteNumber(row?.weather_latitude, DEFAULT_WEATHER.latitude),
      longitude: asFiniteNumber(row?.weather_longitude, DEFAULT_WEATHER.longitude),
      timezone: String(row?.weather_timezone || DEFAULT_WEATHER.timezone).trim() || DEFAULT_WEATHER.timezone,
      updateIntervalMinutes: 30,
    };
  } catch (error) {
    return { ...DEFAULT_WEATHER, updateIntervalMinutes: 30 };
  }
};

const fetchWeather = async (settings: WeatherSettings) => {
  if (!settings.enabled) return null;

  const cacheKey = [
    settings.location,
    settings.latitude.toFixed(4),
    settings.longitude.toFixed(4),
    settings.timezone,
  ].join('|');
  const now = Date.now();

  if (weatherCache?.key === cacheKey && weatherCache.expiresAt > now) {
    return weatherCache.data;
  }

  const weatherUrl = new URL('https://api.open-meteo.com/v1/forecast');
  weatherUrl.searchParams.set('latitude', String(settings.latitude));
  weatherUrl.searchParams.set('longitude', String(settings.longitude));
  weatherUrl.searchParams.set('current', 'temperature_2m,apparent_temperature,weather_code,is_day,precipitation,rain,showers,snowfall');
  weatherUrl.searchParams.set('daily', 'weather_code,temperature_2m_max,temperature_2m_min');
  weatherUrl.searchParams.set('forecast_days', '5');
  weatherUrl.searchParams.set('timezone', settings.timezone);

  const weather = await fetchJson<any>(weatherUrl.toString());
  if (!weather) {
    return weatherCache?.key === cacheKey ? weatherCache.data : null;
  }

  const data = {
    location: settings.location,
    country: settings.country,
    timezone: settings.timezone,
    source: 'Open-Meteo',
    updateIntervalMinutes: settings.updateIntervalMinutes,
    current: {
      temperature: round(Number(weather.current?.temperature_2m || 0), 0),
      apparentTemperature: round(Number(weather.current?.apparent_temperature || 0), 0),
      weatherCode: Number(weather.current?.weather_code || 0),
      isDay: Number(weather.current?.is_day ?? 1),
      precipitation: round(Number(weather.current?.precipitation || 0), 1),
      rain: round(Number(weather.current?.rain || 0), 1),
      showers: round(Number(weather.current?.showers || 0), 1),
      snowfall: round(Number(weather.current?.snowfall || 0), 1),
      time: weather.current?.time || null,
    },
    forecast: (weather.daily?.time || []).slice(0, 5).map((day: string, index: number) => ({
      day,
      weatherCode: Number(weather.daily?.weather_code?.[index] || 0),
      max: round(Number(weather.daily?.temperature_2m_max?.[index] || 0), 0),
      min: round(Number(weather.daily?.temperature_2m_min?.[index] || 0), 0),
    })),
    fetchedAt: new Date().toISOString(),
  };

  weatherCache = {
    key: cacheKey,
    data,
    expiresAt: now + WEATHER_REFRESH_MS,
  };

  return data;
};

const sidebarCacheKey = (languageCode: string) => `sidebar:${String(languageCode || 'tr').trim() || 'tr'}`;

const readSidebarCache = async (key: string) => {
  try {
    await ensureSidebarCacheSchema();
    const result = await dbQuery<{ payload: any; expires_at: string; updated_at: string }>(
      `SELECT payload, expires_at, updated_at
       FROM public.app_cache
       WHERE key = $1
       LIMIT 1`,
      [key]
    );
    const row = result.rows[0];
    if (!row?.payload) return null;
    return {
      payload: typeof row.payload === 'string' ? JSON.parse(row.payload) : row.payload,
      expiresAt: new Date(row.expires_at).getTime(),
      updatedAt: row.updated_at,
    };
  } catch {
    return null;
  }
};

const writeSidebarCache = async (key: string, payload: any) => {
  try {
    await ensureSidebarCacheSchema();
    const expiresAt = new Date(Date.now() + WEATHER_REFRESH_MS).toISOString();
    await dbQuery(
      `INSERT INTO public.app_cache (key, payload, expires_at, updated_at)
       VALUES ($1, $2::jsonb, $3, now())
       ON CONFLICT (key) DO UPDATE SET
         payload = EXCLUDED.payload,
         expires_at = EXCLUDED.expires_at,
         updated_at = now()`,
      [key, JSON.stringify(payload), expiresAt]
    );
  } catch {
    // Cache is an optimization; sidebar data must still render when the runtime role cannot write it.
  }
};

const cacheMatchesSettings = (payload: any, settings: WeatherSettings) => {
  const weather = payload?.weather;
  if (!settings.enabled) return weather === null;
  if (!weather) return false;
  if (!weather.current || !Object.prototype.hasOwnProperty.call(weather.current, 'isDay')) return false;
  return (
    String(weather.location || '') === settings.location &&
    Number(weather.latitude || 0).toFixed(4) === settings.latitude.toFixed(4) &&
    Number(weather.longitude || 0).toFixed(4) === settings.longitude.toFixed(4) &&
    String(weather.timezone || '') === settings.timezone
  );
};

const fetchSidebarFresh = async (cacheKey: string, settings: WeatherSettings) => {
  const existing = refreshInFlight.get(cacheKey);
  if (existing && Date.now() - existing.startedAt < SIDEBAR_REFRESH_LOCK_MS) {
    return existing.promise;
  }
  if (existing) refreshInFlight.delete(cacheKey);

  const promise = (async () => {
    const [weather, usdTry, btc, gold] = await Promise.all([
      fetchWeather(settings),
      fetchJson<any>('https://api.frankfurter.dev/v1/latest?from=USD&to=TRY,EUR', 2500),
      fetchJson<any>('https://api.coingecko.com/api/v3/simple/price?ids=bitcoin&vs_currencies=usd&include_24hr_change=true', 2500),
      fetchJson<any>('https://api.gold-api.com/price/XAU', 2500),
    ]);

    const usdTryRate = Number(usdTry?.rates?.TRY || 0);
    const usdEurRate = Number(usdTry?.rates?.EUR || 0);
    const eurTryRate = usdTryRate && usdEurRate ? usdTryRate / usdEurRate : 0;
    const goldGramTry = Number(gold?.price || 0) && usdTryRate
      ? (Number(gold.price) * usdTryRate) / 31.1034768
      : 0;

    const markets = [
      {
        symbol: 'USDT',
        nameKey: 'right.markets.usdt_try',
        price: usdTryRate ? round(usdTryRate, 2).toLocaleString('tr-TR') : null,
        change: null,
        isUp: true,
        source: 'Frankfurter',
      },
      {
        symbol: 'EUR',
        nameKey: 'right.markets.eur_try',
        price: eurTryRate ? round(eurTryRate, 2).toLocaleString('tr-TR') : null,
        change: null,
        isUp: true,
        source: 'Frankfurter',
      },
      {
        symbol: 'GA',
        nameKey: 'right.markets.gold_gram',
        price: goldGramTry ? round(goldGramTry, 2).toLocaleString('tr-TR') : null,
        change: null,
        isUp: true,
        source: 'Gold API',
      },
      {
        symbol: 'BTC',
        nameKey: 'right.markets.bitcoin',
        price: btc?.bitcoin?.usd ? `$${Number(btc.bitcoin.usd).toLocaleString('en-US')}` : null,
        change: Number.isFinite(Number(btc?.bitcoin?.usd_24h_change)) ? round(Number(btc.bitcoin.usd_24h_change), 2) : null,
        isUp: Number(btc?.bitcoin?.usd_24h_change || 0) >= 0,
        source: 'CoinGecko',
      },
    ];

    const payload = {
      weather: weather ? {
        ...weather,
        latitude: settings.latitude,
        longitude: settings.longitude,
      } : null,
      markets,
      cache: {
        source: 'database',
        refreshIntervalMinutes: 30,
        stale: false,
      },
      updatedAt: new Date().toISOString(),
    };

    await writeSidebarCache(cacheKey, payload);
    return payload;
  })().finally(() => {
    refreshInFlight.delete(cacheKey);
  });

  refreshInFlight.set(cacheKey, { promise, startedAt: Date.now() });
  return promise;
};

export const GET: APIRoute = async ({ url }) => {
  const languageCode = String(url.searchParams.get('lang') || 'tr').trim() || 'tr';
  const baseWeatherSettings = await getWeatherSettings(languageCode);
  const weatherSettings: WeatherSettings = {
    ...baseWeatherSettings,
    latitude: Number(url.searchParams.get('lat')) || baseWeatherSettings.latitude,
    longitude: Number(url.searchParams.get('lon')) || baseWeatherSettings.longitude,
    timezone: String(url.searchParams.get('timezone') || baseWeatherSettings.timezone),
    location: String(url.searchParams.get('location') || baseWeatherSettings.location),
  };
  const cacheKey = sidebarCacheKey(languageCode);
  const cached = await readSidebarCache(cacheKey);
  const hasMatchingCache = cached?.payload && cacheMatchesSettings(cached.payload, weatherSettings);

  if (hasMatchingCache && cached.expiresAt > Date.now()) {
    return json({
      ...cached.payload,
      cache: {
        ...(cached.payload.cache || {}),
        hit: true,
        stale: false,
      },
    });
  }

  if (hasMatchingCache) {
    void fetchSidebarFresh(cacheKey, weatherSettings).catch(() => null);
    return json({
      ...cached.payload,
      cache: {
        ...(cached.payload.cache || {}),
        hit: true,
        stale: true,
        refreshing: true,
      },
    });
  }

  const fresh = await fetchSidebarFresh(cacheKey, weatherSettings);
  return json({
    ...fresh,
    cache: {
      ...(fresh.cache || {}),
      hit: false,
      stale: false,
    },
  });
};
