import type { APIRoute } from 'astro';
import { ensureAppSchema, json } from '@/lib/server/appDb';
import { dbQuery } from '@/lib/server/supabaseDb';

const WEATHER_REFRESH_MS = 30 * 60 * 1000;
const FETCH_TIMEOUT_MS = 8500;
const DEFAULT_WEATHER = {
  enabled: true,
  location: 'Niğde',
  country: 'Türkiye',
  latitude: 37.96583,
  longitude: 34.67935,
  timezone: 'Europe/Istanbul',
  updateIntervalMinutes: 30,
};

type WeatherSettings = typeof DEFAULT_WEATHER;
type WeatherPayload = {
  location: string;
  country: string;
  latitude: number;
  longitude: number;
  timezone: string;
  source: string;
  serviceDateLabel: string;
  fetchedAt: string;
  updateIntervalMinutes: number;
  current: Record<string, unknown>;
  hourly: Record<string, unknown>[];
  daily: Record<string, unknown>[];
  cache?: Record<string, unknown>;
};

let memoryCache: { key: string; expiresAt: number; payload: WeatherPayload } | null = null;
let refreshInFlight: { key: string; startedAt: number; promise: Promise<WeatherPayload> } | null = null;

const asFiniteNumber = (value: unknown, fallback: number) => {
  const numeric = Number(value);
  return Number.isFinite(numeric) ? numeric : fallback;
};

const asString = (value: unknown, fallback = '') => {
  const result = String(value || '').trim();
  return result || fallback;
};

const round = (value: unknown, digits = 0) => {
  const numeric = Number(value);
  if (!Number.isFinite(numeric)) return 0;
  return Number(numeric.toFixed(digits));
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

const localDateLabel = (timezone: string) =>
  new Intl.DateTimeFormat('tr-TR', {
    timeZone: timezone,
    day: 'numeric',
    month: 'long',
    year: 'numeric',
    weekday: 'long',
  }).format(new Date());

const shortDayLabel = (date: string, index: number, timezone: string) => {
  if (index === 0) return 'Bugün';
  if (index === 1) return 'Yarın';
  return new Intl.DateTimeFormat('tr-TR', {
    timeZone: timezone,
    weekday: 'short',
  }).format(new Date(`${date}T12:00:00`));
};

const hourLabel = (value: string, index: number) => {
  if (index === 0) return 'Şimdi';
  return value.slice(11, 16);
};

const peakPrecipitationHourLabel = (
  date: string,
  currentHour: string,
  hourlyTimes: string[],
  hourlyData: any
) => {
  let peakProbability = 0;
  let peakTime = '';
  hourlyTimes.forEach((time, index) => {
    const value = String(time || '');
    if (!value.startsWith(date) || value.slice(0, 13) < currentHour) return;
    const probability = round(hourlyData?.precipitation_probability?.[index]);
    const amount = round(hourlyData?.precipitation?.[index], 1);
    if (probability <= 0 && amount <= 0) return;
    if (probability > peakProbability) {
      peakProbability = probability;
      peakTime = value;
    }
  });
  return peakTime.length >= 16 ? peakTime.slice(11, 16) : '';
};

const weatherCacheKey = (languageCode: string, settings: WeatherSettings) =>
  [
    'weather',
    String(languageCode || 'tr').trim() || 'tr',
    settings.location,
    settings.latitude.toFixed(4),
    settings.longitude.toFixed(4),
    settings.timezone,
  ].join(':');

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
      const fallback = await dbQuery<any>(selectSql, ['tr']);
      row = fallback.rows[0] || null;
    }

    return {
      enabled: row?.weather_enabled !== false,
      location: asString(row?.weather_location_name, DEFAULT_WEATHER.location),
      country: asString(row?.weather_location_country, DEFAULT_WEATHER.country),
      latitude: asFiniteNumber(row?.weather_latitude, DEFAULT_WEATHER.latitude),
      longitude: asFiniteNumber(row?.weather_longitude, DEFAULT_WEATHER.longitude),
      timezone: asString(row?.weather_timezone, DEFAULT_WEATHER.timezone),
      updateIntervalMinutes: Math.max(5, Math.round(asFiniteNumber(row?.weather_update_interval_minutes, 30))),
    };
  } catch {
    return DEFAULT_WEATHER;
  }
};

const readCache = async (key: string) => {
  try {
    await ensureAppSchema();
    const result = await dbQuery<{ payload: any; expires_at: string }>(
      `SELECT payload, expires_at
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
    };
  } catch {
    return null;
  }
};

const writeCacheLater = (key: string, payload: WeatherPayload) => {
  const expiresAt = Date.now() + WEATHER_REFRESH_MS;
  memoryCache = { key, payload, expiresAt };
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
      // Cache yazımı cevap yolunu bloklamaz.
    }
  })();
};

const fetchWeatherFresh = async (key: string, settings: WeatherSettings): Promise<WeatherPayload> => {
  const active = refreshInFlight;
  if (active?.key === key && Date.now() - active.startedAt < FETCH_TIMEOUT_MS + 2000) {
    return active.promise;
  }
  if (active?.key === key) refreshInFlight = null;

  let trackedPromise: Promise<WeatherPayload>;
  trackedPromise = (async () => {
    if (!settings.enabled) throw new Error('Weather is disabled');

    const weatherUrl = new URL('https://api.open-meteo.com/v1/forecast');
    weatherUrl.searchParams.set('latitude', String(settings.latitude));
    weatherUrl.searchParams.set('longitude', String(settings.longitude));
    weatherUrl.searchParams.set(
      'current',
      [
        'temperature_2m',
        'relative_humidity_2m',
        'apparent_temperature',
        'is_day',
        'precipitation',
        'rain',
        'showers',
        'snowfall',
        'weather_code',
        'cloud_cover',
        'pressure_msl',
        'surface_pressure',
        'wind_speed_10m',
        'wind_direction_10m',
        'wind_gusts_10m',
      ].join(',')
    );
    weatherUrl.searchParams.set(
      'hourly',
      [
        'temperature_2m',
        'apparent_temperature',
        'relative_humidity_2m',
        'weather_code',
        'is_day',
        'precipitation_probability',
        'precipitation',
        'wind_speed_10m',
      ].join(',')
    );
    weatherUrl.searchParams.set(
      'daily',
      [
        'weather_code',
        'temperature_2m_max',
        'temperature_2m_min',
        'apparent_temperature_max',
        'apparent_temperature_min',
        'precipitation_sum',
        'precipitation_probability_max',
        'wind_speed_10m_max',
        'sunrise',
        'sunset',
        'uv_index_max',
      ].join(',')
    );
    weatherUrl.searchParams.set('forecast_days', '7');
    weatherUrl.searchParams.set('timezone', settings.timezone);

    const response = await withTimeout(
      fetch(weatherUrl.toString(), {
        signal: AbortSignal.timeout(FETCH_TIMEOUT_MS),
        headers: { Accept: 'application/json' },
      }),
      FETCH_TIMEOUT_MS,
      null
    );
    if (!response) throw new Error('Open-Meteo request timed out');
    if (!response.ok) throw new Error(`Open-Meteo returned ${response.status}`);

    const weather = await response.json();
    const hourlyTimes: string[] = Array.isArray(weather.hourly?.time) ? weather.hourly.time : [];
    const currentTime = String(weather.current?.time || hourlyTimes[0] || '');
    const currentHour = currentTime.slice(0, 13);
    const startIndex = Math.max(0, hourlyTimes.findIndex((time) => String(time).slice(0, 13) >= currentHour));
    const hourly = hourlyTimes.slice(startIndex, startIndex + 12).map((time, offset) => {
      const index = startIndex + offset;
      return {
        time,
        label: hourLabel(time, offset),
        temperature: round(weather.hourly?.temperature_2m?.[index]),
        apparentTemperature: round(weather.hourly?.apparent_temperature?.[index]),
        humidity: round(weather.hourly?.relative_humidity_2m?.[index]),
        weatherCode: Number(weather.hourly?.weather_code?.[index] || 0),
        isDay: Number(weather.hourly?.is_day?.[index] ?? 1),
        precipitationProbability: round(weather.hourly?.precipitation_probability?.[index]),
        precipitation: round(weather.hourly?.precipitation?.[index], 1),
        windSpeed: round(weather.hourly?.wind_speed_10m?.[index]),
      };
    });

    const dailyTimes: string[] = Array.isArray(weather.daily?.time) ? weather.daily.time : [];
    const daily = dailyTimes.slice(0, 7).map((date, index) => ({
      date,
      label: shortDayLabel(date, index, settings.timezone),
      weatherCode: Number(weather.daily?.weather_code?.[index] || 0),
      max: round(weather.daily?.temperature_2m_max?.[index]),
      min: round(weather.daily?.temperature_2m_min?.[index]),
      apparentMax: round(weather.daily?.apparent_temperature_max?.[index]),
      apparentMin: round(weather.daily?.apparent_temperature_min?.[index]),
      precipitationSum: round(weather.daily?.precipitation_sum?.[index], 1),
      precipitationProbability: round(weather.daily?.precipitation_probability_max?.[index]),
      precipitationHourLabel: peakPrecipitationHourLabel(date, currentHour, hourlyTimes, weather.hourly),
      windSpeedMax: round(weather.daily?.wind_speed_10m_max?.[index]),
      sunrise: weather.daily?.sunrise?.[index] || '',
      sunset: weather.daily?.sunset?.[index] || '',
      uvIndex: round(weather.daily?.uv_index_max?.[index], 1),
    }));

    const payload: WeatherPayload = {
      location: settings.location,
      country: settings.country,
      latitude: settings.latitude,
      longitude: settings.longitude,
      timezone: settings.timezone,
      source: 'Open-Meteo',
      serviceDateLabel: localDateLabel(settings.timezone),
      fetchedAt: new Date().toISOString(),
      updateIntervalMinutes: settings.updateIntervalMinutes,
      current: {
        temperature: round(weather.current?.temperature_2m),
        apparentTemperature: round(weather.current?.apparent_temperature),
        humidity: round(weather.current?.relative_humidity_2m),
        weatherCode: Number(weather.current?.weather_code || 0),
        isDay: Number(weather.current?.is_day ?? 1),
        precipitation: round(weather.current?.precipitation, 1),
        rain: round(weather.current?.rain, 1),
        showers: round(weather.current?.showers, 1),
        snowfall: round(weather.current?.snowfall, 1),
        cloudCover: round(weather.current?.cloud_cover),
        pressure: round(weather.current?.pressure_msl),
        surfacePressure: round(weather.current?.surface_pressure),
        windSpeed: round(weather.current?.wind_speed_10m),
        windDirection: round(weather.current?.wind_direction_10m),
        windGusts: round(weather.current?.wind_gusts_10m),
        time: weather.current?.time || null,
      },
      hourly,
      daily,
    };

    writeCacheLater(key, payload);
    return payload;
  })().finally(() => {
    if (refreshInFlight?.promise === trackedPromise) refreshInFlight = null;
  });

  refreshInFlight = { key, startedAt: Date.now(), promise: trackedPromise };
  return trackedPromise;
};

export const GET: APIRoute = async ({ url }) => {
  const languageCode = String(url.searchParams.get('lang') || 'tr').trim() || 'tr';
  const forceRefresh = url.searchParams.get('refresh') === '1';
  const settings = await getWeatherSettings(languageCode);
  const cacheKey = weatherCacheKey(languageCode, settings);
  const currentMemory = memoryCache?.key === cacheKey ? memoryCache : null;
  const now = Date.now();

  if (!forceRefresh && currentMemory && currentMemory.expiresAt > now) {
    return json({
      ...currentMemory.payload,
      cache: { hit: true, stale: false, source: 'memory', refreshIntervalMinutes: settings.updateIntervalMinutes },
    });
  }

  const cached = await withTimeout(readCache(cacheKey), 900, null);
  if (!forceRefresh && cached?.payload && cached.expiresAt > now) {
    memoryCache = { key: cacheKey, payload: cached.payload, expiresAt: cached.expiresAt };
    return json({
      ...cached.payload,
      cache: { hit: true, stale: false, source: 'database', refreshIntervalMinutes: settings.updateIntervalMinutes },
    });
  }

  if (!forceRefresh && cached?.payload) {
    void fetchWeatherFresh(cacheKey, settings).catch(() => null);
    return json({
      ...cached.payload,
      cache: { hit: true, stale: true, refreshing: true, source: 'database', refreshIntervalMinutes: settings.updateIntervalMinutes },
    });
  }

  try {
    const fresh = await fetchWeatherFresh(cacheKey, settings);
    return json({
      ...fresh,
      cache: { hit: false, stale: false, source: 'Open-Meteo', refreshIntervalMinutes: settings.updateIntervalMinutes },
    });
  } catch (error: any) {
    const fallback = cached?.payload || currentMemory?.payload;
    if (fallback) {
      return json({
        ...fallback,
        cache: { hit: true, stale: true, refreshFailed: true, source: cached?.payload ? 'database' : 'memory', refreshIntervalMinutes: settings.updateIntervalMinutes },
        error: error?.message || 'Weather could not be refreshed',
      });
    }
    return json({
      location: settings.location,
      country: settings.country,
      latitude: settings.latitude,
      longitude: settings.longitude,
      timezone: settings.timezone,
      source: 'Open-Meteo',
      serviceDateLabel: localDateLabel(settings.timezone),
      fetchedAt: new Date().toISOString(),
      updateIntervalMinutes: settings.updateIntervalMinutes,
      current: null,
      hourly: [],
      daily: [],
      error: error?.message || 'Weather could not be fetched',
    }, 502);
  }
};
