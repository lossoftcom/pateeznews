import React, { useEffect, useMemo, useState } from 'react';
import RemixIcon from '@/components/ui/RemixIcon';
import { navigateImmediately } from '@/utils/immediateNavigation';

// ---------------------------------------------------------------------------
// Veri tipleri — /api/app/weather çıktısıyla birebir aynı (Flutter WeatherData).
// ---------------------------------------------------------------------------

type WeatherCurrent = {
  temperature?: number;
  apparentTemperature?: number;
  humidity?: number;
  weatherCode?: number;
  isDay?: number;
  cloudCover?: number;
  pressure?: number;
  windSpeed?: number;
};

type WeatherHour = {
  label?: string;
  temperature?: number;
  weatherCode?: number;
  isDay?: number;
  precipitationProbability?: number;
};

type WeatherDay = {
  label?: string;
  weatherCode?: number;
  max?: number;
  min?: number;
  precipitationProbability?: number;
  precipitationHourLabel?: string;
  sunset?: string;
  uvIndex?: number;
};

type WeatherPayload = {
  location?: string;
  current?: WeatherCurrent | null;
  hourly?: WeatherHour[];
  daily?: WeatherDay[];
  error?: string;
};

// ---------------------------------------------------------------------------
// Renkler — Flutter app_colors.dart + weather_screen.dart sabitleri.
// ---------------------------------------------------------------------------

const C = {
  ink: '#1B2A37',
  inkStrong: '#0F1B26',
  inkSoft: '#536270',
  support: '#8A949B',
  deepOcean: '#2C3E50',
  warmHorizon: '#F39C12',
  actionRed: '#EA4335',
  weatherTan: '#B7A27A',
  weatherSun: '#FFA313',
  weatherCloud: '#FFB21A',
};

// ---------------------------------------------------------------------------
// Hava yardımcıları — Flutter weather_repository.dart ile birebir.
// ---------------------------------------------------------------------------

type MotionKind = 'clearDay' | 'clearNight' | 'cloudy' | 'fog' | 'rain' | 'snow' | 'storm';

const weatherMotionKind = (code: number, isDay: boolean): MotionKind => {
  if (code >= 95) return 'storm';
  if ((code >= 71 && code <= 77) || code === 85 || code === 86) return 'snow';
  if ((code >= 51 && code <= 67) || (code >= 80 && code <= 82)) return 'rain';
  if (code === 45 || code === 48) return 'fog';
  if (code === 0) return isDay ? 'clearDay' : 'clearNight';
  return 'cloudy';
};

const weatherIcon = (code: number, isDay: boolean) => {
  switch (weatherMotionKind(code, isDay)) {
    case 'clearDay':
      return 'ri-sun-fill';
    case 'clearNight':
      return 'ri-moon-clear-fill';
    case 'cloudy':
      return isDay ? 'ri-sun-cloudy-fill' : 'ri-moon-cloudy-fill';
    case 'fog':
      return 'ri-foggy-fill';
    case 'rain':
      return 'ri-rainy-fill';
    case 'snow':
      return 'ri-cloudy-fill';
    case 'storm':
      return 'ri-rainy-fill';
  }
};

const weatherTint = (code: number, isDay: boolean) => {
  switch (weatherMotionKind(code, isDay)) {
    case 'clearDay':
    case 'cloudy':
      return C.warmHorizon;
    case 'clearNight':
      return C.deepOcean;
    case 'fog':
      return C.support;
    case 'rain':
    case 'snow':
    case 'storm':
      return C.deepOcean;
  }
};

const weatherPrecipitationLabel = (code: number, isDay: boolean) => {
  switch (weatherMotionKind(code, isDay)) {
    case 'snow':
      return 'Kar';
    case 'rain':
    case 'storm':
      return 'Yağmur';
    default:
      return 'Yağış';
  }
};

const weatherConditionLabel = (code: number) => {
  if (code === 0) return 'Açık';
  if (code === 1) return 'Az bulutlu';
  if (code === 2) return 'Parçalı bulutlu';
  if (code === 3) return 'Kapalı';
  if (code === 45 || code === 48) return 'Sisli';
  if (code >= 51 && code <= 57) return 'Çisenti';
  if (code >= 61 && code <= 67) return 'Yağmurlu';
  if (code >= 71 && code <= 77) return 'Karlı';
  if (code >= 80 && code <= 82) return 'Sağanak yağışlı';
  if (code === 85 || code === 86) return 'Kar sağanağı';
  if (code >= 95) return 'Gök gürültülü';
  return 'Parçalı bulutlu';
};

const upperCaseTr = (value: string) =>
  value.trim().replaceAll('i', 'İ').replaceAll('ı', 'I').toLocaleUpperCase('tr-TR');

const timeOnly = (value: string) => (value.length >= 16 ? value.slice(11, 16) : '--');

const toInt = (value: unknown, fallback = 0) => {
  const numeric = Number(value);
  return Number.isFinite(numeric) ? Math.round(numeric) : fallback;
};

const withAlpha = (hex: string, alpha: number) => {
  const value = hex.replace('#', '');
  const r = parseInt(value.slice(0, 2), 16);
  const g = parseInt(value.slice(2, 4), 16);
  const b = parseInt(value.slice(4, 6), 16);
  return `rgba(${r}, ${g}, ${b}, ${alpha})`;
};

// ---------------------------------------------------------------------------
// Çözümlenmiş görünüm modeli.
// ---------------------------------------------------------------------------

type CurrentView = {
  temperature: number;
  apparentTemperature: number;
  humidity: number;
  weatherCode: number;
  isDay: boolean;
  cloudCover: number;
  pressure: number;
  windSpeed: number;
};

type HourView = {
  label: string;
  temperature: number;
  weatherCode: number;
  isDay: boolean;
  precipitationProbability: number;
};

type DayView = {
  label: string;
  weatherCode: number;
  max: number;
  min: number;
  precipitationProbability: number;
  precipitationHourLabel: string;
  sunset: string;
  uvIndex: number;
};

type WeatherView = {
  location: string;
  current: CurrentView;
  hourly: HourView[];
  daily: DayView[];
  weekMin: number;
  weekMax: number;
};

const resolveWeather = (payload: WeatherPayload | null): WeatherView | null => {
  const current = payload?.current;
  if (!current) return null;

  const code = toInt(current.weatherCode, 2);
  const isDay = toInt(current.isDay, 1) !== 0;

  const hourly: HourView[] = (payload?.hourly || []).slice(0, 12).map((hour, index) => ({
    label: index === 0 ? 'Şimdi' : String(hour.label || '--:--'),
    temperature: toInt(hour.temperature),
    weatherCode: toInt(hour.weatherCode, code),
    isDay: toInt(hour.isDay, isDay ? 1 : 0) !== 0,
    precipitationProbability: toInt(hour.precipitationProbability),
  }));

  const daily: DayView[] = (payload?.daily || []).slice(0, 7).map((day) => ({
    label: String(day.label || ''),
    weatherCode: toInt(day.weatherCode, 2),
    max: toInt(day.max),
    min: toInt(day.min),
    precipitationProbability: toInt(day.precipitationProbability),
    precipitationHourLabel: String(day.precipitationHourLabel || ''),
    sunset: String(day.sunset || ''),
    uvIndex: Number(day.uvIndex) || 0,
  }));

  const temperature = toInt(current.temperature);
  const weekMin = daily.length ? Math.min(...daily.map((d) => d.min)) : temperature;
  const weekMax = daily.length ? Math.max(...daily.map((d) => d.max)) : temperature;

  return {
    location: String(payload?.location || 'Niğde'),
    current: {
      temperature,
      apparentTemperature: toInt(current.apparentTemperature),
      humidity: toInt(current.humidity),
      weatherCode: code,
      isDay,
      cloudCover: toInt(current.cloudCover),
      pressure: toInt(current.pressure),
      windSpeed: toInt(current.windSpeed),
    },
    hourly,
    daily,
    weekMin,
    weekMax,
  };
};

// ---------------------------------------------------------------------------
// Animasyonlu hava ikonu — Flutter WeatherMotionIcon birebir karşılığı.
// ---------------------------------------------------------------------------

const WeatherGlyph: React.FC<{ code: number; isDay: boolean; size?: number }> = ({
  code,
  isDay,
  size = 54,
}) => {
  const kind = weatherMotionKind(code, isDay);
  const cloudColor =
    kind === 'rain' || kind === 'storm'
      ? C.deepOcean
      : kind === 'fog' || kind === 'snow'
        ? C.support
        : C.weatherCloud;

  const showSun = kind === 'clearDay' || kind === 'cloudy';
  const showMoon = kind === 'clearNight';
  const showCloud = kind !== 'clearDay' && kind !== 'clearNight';
  const showDrops = kind === 'rain' || kind === 'storm';
  const showFog = kind === 'fog';

  const SS = size * 0.46; // güneş kutusu
  const sunCircle = SS * 0.62;
  const CS = size * 0.72; // bulut kutusu
  const cloudH = CS * 0.58;
  const cloudBottom = kind === 'fog' ? 12 : 9;

  return (
    <span className="weather-glyph" style={{ width: size, height: size }} aria-hidden="true">
      {showSun && (
        <span
          className="weather-glyph-sun"
          style={{
            width: SS,
            height: SS,
            right: kind === 'cloudy' ? 5 : 12,
            top: kind === 'cloudy' ? 5 : 10,
          }}
        >
          {kind === 'clearDay' &&
            Array.from({ length: 8 }).map((_, i) => (
              <span
                key={i}
                className="weather-glyph-ray-layer"
                style={{ transform: `rotate(${i * 45}deg)` }}
              >
                <span
                  className="weather-glyph-ray"
                  style={{ height: SS * 0.15, background: withAlpha(C.weatherSun, 0.58) }}
                />
              </span>
            ))}
          <span
            className="weather-glyph-sun-core"
            style={{
              width: sunCircle,
              height: sunCircle,
              left: (SS - sunCircle) / 2,
              top: (SS - sunCircle) / 2,
              background: C.weatherSun,
            }}
          />
        </span>
      )}

      {showMoon && (
        <span className="weather-glyph-moon" style={{ right: 14, top: 12 }}>
          <RemixIcon name="ri-moon-clear-fill" size={size * 0.52} style={{ color: C.deepOcean }} />
        </span>
      )}

      {showCloud && (
        <span
          className="weather-glyph-cloud"
          style={{ width: CS, height: cloudH, left: 5, top: size - cloudH - cloudBottom }}
        >
          <span
            className="weather-glyph-cloud-base"
            style={{ left: CS * 0.08, width: CS * 0.8, height: CS * 0.36, background: cloudColor }}
          />
          <span
            className="weather-glyph-cloud-puff"
            style={{ left: CS * 0.18, bottom: CS * 0.15, width: CS * 0.34, height: CS * 0.34, background: cloudColor }}
          />
          <span
            className="weather-glyph-cloud-puff"
            style={{ left: CS * 0.42, bottom: CS * 0.12, width: CS * 0.42, height: CS * 0.42, background: cloudColor }}
          />
        </span>
      )}

      {showDrops &&
        Array.from({ length: 3 }).map((_, i) => (
          <span
            key={i}
            className="weather-glyph-drop"
            style={
              {
                left: size * (0.3 + i * 0.15),
                top: size * 0.6,
                background: withAlpha(C.deepOcean, 0.54),
                animationDelay: `-${(i * 0.22 * 3.6).toFixed(3)}s`,
                ['--drop-travel' as string]: `${(size * 0.17).toFixed(2)}px`,
              } as React.CSSProperties
            }
          />
        ))}

      {showFog &&
        Array.from({ length: 3 }).map((_, i) => (
          <span
            key={i}
            className="weather-glyph-fog"
            style={{
              left: size * 0.18,
              top: size * (0.6 + i * 0.11),
              width: size * 0.56,
              background: withAlpha(C.support, 0.55),
              animationDelay: `-${(i * 0.2 * 3.6).toFixed(3)}s`,
            }}
          />
        ))}
    </span>
  );
};

// ---------------------------------------------------------------------------
// Küçük yapı taşları.
// ---------------------------------------------------------------------------

const SectionTitle: React.FC<{ title: string }> = ({ title }) => (
  <div className="weather-section-title">
    <span aria-hidden="true" />
    <strong>{title}</strong>
  </div>
);

const PrecipChance: React.FC<{ probability: number; tint: string; hourLabel?: string }> = ({
  probability,
  tint,
  hourLabel = '',
}) => (
  <span className="weather-precip">
    <RemixIcon name="ri-drop-fill" size={10} style={{ color: withAlpha(tint, 0.72) }} />
    <span>%{probability}</span>
    {hourLabel ? <span className="weather-precip-hour">{hourLabel}</span> : null}
  </span>
);

const RangeBar: React.FC<{ lo: number; hi: number; min: number; max: number }> = ({ lo, hi, min, max }) => {
  const width = 58;
  const span = max - min === 0 ? 1 : max - min;
  const leftFrac = Math.min(Math.max((lo - min) / span, 0), 1);
  const widthFrac = Math.min(Math.max((hi - lo) / span, 0.08), 1);
  const fillWidth = Math.min(Math.max(width * widthFrac, 8), width);
  return (
    <span className="weather-range">
      <span className="weather-range-track" />
      <span className="weather-range-fill" style={{ left: width * leftFrac, width: fillWidth }} />
    </span>
  );
};

// ---------------------------------------------------------------------------
// Sayfa.
// ---------------------------------------------------------------------------

const WeatherPage: React.FC = () => {
  const [view, setView] = useState<WeatherView | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');

  useEffect(() => {
    const controller = new AbortController();
    const timeout = window.setTimeout(() => controller.abort(), 13000);

    setLoading(true);
    fetch('/api/app/weather?lang=tr', {
      headers: { Accept: 'application/json' },
      signal: controller.signal,
    })
      .then(async (response) => {
        const payload = (await response.json().catch(() => null)) as WeatherPayload | null;
        const resolved = resolveWeather(payload);
        if (resolved) {
          setView(resolved);
          setError('');
        } else {
          setError(String(payload?.error || 'Hava durumu alınamadı'));
        }
      })
      .catch(() => setError('Hava durumu alınamadı'))
      .finally(() => {
        window.clearTimeout(timeout);
        setLoading(false);
      });

    return () => {
      window.clearTimeout(timeout);
      controller.abort();
    };
  }, []);

  const goBack = () => {
    if (window.history.length > 1) {
      window.history.back();
      return;
    }
    void navigateImmediately('/');
  };

  const heroMetrics = useMemo(() => {
    if (!view) return [];
    const { current, daily } = view;
    const today = daily[0];
    const precip =
      today?.precipitationProbability ??
      (view.hourly.length ? view.hourly[0].precipitationProbability : 0);
    return [
      { label: 'Nem', value: `%${current.humidity}` },
      { label: 'Rüzgar', value: `${current.windSpeed} km/s` },
      { label: weatherPrecipitationLabel(current.weatherCode, current.isDay), value: `%${precip}` },
      { label: 'Min / Maks', value: today ? `${today.min}° / ${today.max}°` : '--' },
    ];
  }, [view]);

  const detailCards = useMemo(() => {
    if (!view) return [];
    const { current, daily } = view;
    const today = daily[0];
    return [
      { icon: 'ri-temp-hot-fill', label: 'Hissedilen', value: `${current.apparentTemperature}°` },
      { icon: 'ri-water-percent-fill', label: 'Nem', value: `%${current.humidity}` },
      { icon: 'ri-windy-fill', label: 'Rüzgar', value: `${current.windSpeed} km/s` },
      { icon: 'ri-compass-fill', label: 'Basınç', value: `${current.pressure} hPa` },
      {
        icon: 'ri-drop-fill',
        label: weatherPrecipitationLabel(current.weatherCode, current.isDay),
        value: today ? `%${today.precipitationProbability}` : '--',
      },
      { icon: 'ri-cloudy-fill', label: 'Bulut', value: `%${current.cloudCover}` },
      { icon: 'ri-sun-fill', label: 'UV', value: today ? today.uvIndex.toFixed(1) : '--' },
      { icon: 'ri-moon-clear-fill', label: 'Gün batımı', value: timeOnly(today?.sunset || '') },
    ];
  }, [view]);

  return (
    <main className="weather-mobile-page" aria-label="Hava Durumu">
      <div className="weather-shell">
        <header className="weather-appbar">
          <button type="button" className="weather-icon-button" aria-label="Ara">
            <RemixIcon name="ri-search-line" size={23} />
          </button>
          <div className="weather-appbar-title">
            <span aria-hidden="true" />
            <strong>Hava Durumu</strong>
          </div>
          <button type="button" className="weather-back-button" onClick={goBack} aria-label="Geri">
            <RemixIcon name="ri-arrow-left-line" size={20} />
          </button>
        </header>

        <section className="weather-content">
          {view ? (
            <>
              {(() => {
                const { current } = view;
                const condition = weatherConditionLabel(current.weatherCode);
                return (
                  <article className="weather-current-card">
                    <div className="weather-loc">
                      <RemixIcon name="ri-map-pin-line" size={15} style={{ color: C.weatherTan }} />
                      <span>{upperCaseTr(view.location)}</span>
                    </div>
                    <div className="weather-now-row">
                      <div className="weather-now-lead">
                        <div className="weather-now-temp">{current.temperature}°</div>
                        <div className="weather-now-text">
                          <strong>{condition}</strong>
                          <small>Hissedilen: {current.apparentTemperature}°</small>
                        </div>
                      </div>
                      <div className="weather-now-glyph-box">
                        <WeatherGlyph code={current.weatherCode} isDay={current.isDay} size={54} />
                      </div>
                    </div>
                    <div className="weather-hero-metrics">
                      {heroMetrics.map((metric, index) => (
                        <React.Fragment key={metric.label}>
                          {index > 0 && <span className="weather-hero-divider" aria-hidden="true" />}
                          <div className="weather-hero-metric">
                            <span className="lbl">{metric.label}</span>
                            <span className="val">{metric.value}</span>
                          </div>
                        </React.Fragment>
                      ))}
                    </div>
                  </article>
                );
              })()}

              <SectionTitle title="Saatlik tahmin" />
              <div className="weather-hourly-card">
                <div className="weather-hourly-scroll">
                  {view.hourly.map((hour, index) => {
                    const tint = weatherTint(hour.weatherCode, hour.isDay);
                    return (
                      <div className="weather-hour" key={`${hour.label}-${index}`}>
                        <span className={`weather-hour-label${index === 0 ? ' is-now' : ''}`}>{hour.label}</span>
                        <RemixIcon name={weatherIcon(hour.weatherCode, hour.isDay)} size={25} style={{ color: tint }} />
                        <PrecipChance probability={hour.precipitationProbability} tint={tint} />
                        <strong className="weather-hour-temp">{hour.temperature}°</strong>
                      </div>
                    );
                  })}
                </div>
              </div>

              <SectionTitle title="7 günlük tahmin" />
              <div className="weather-weekly-card">
                {view.daily.map((day, index) => {
                  const isToday = index === 0;
                  const tint = weatherTint(day.weatherCode, true);
                  return (
                    <React.Fragment key={`${day.label}-${index}`}>
                      {index > 0 && <span className="weather-weekly-divider" aria-hidden="true" />}
                      <div className="weather-weekly-row">
                        <span className={`weather-weekly-day${isToday ? ' is-today' : ''}`}>{day.label}</span>
                        <RemixIcon name={weatherIcon(day.weatherCode, true)} size={21} style={{ color: tint }} />
                        <div className="weather-weekly-mid">
                          <span className="weather-weekly-cond">{weatherConditionLabel(day.weatherCode)}</span>
                          <PrecipChance
                            probability={day.precipitationProbability}
                            tint={tint}
                            hourLabel={day.precipitationHourLabel}
                          />
                        </div>
                        <span className="weather-weekly-min">{day.min}°</span>
                        <RangeBar lo={day.min} hi={day.max} min={view.weekMin} max={view.weekMax} />
                        <span className="weather-weekly-max">{day.max}°</span>
                      </div>
                    </React.Fragment>
                  );
                })}
              </div>

              <SectionTitle title="Detaylar" />
              <div className="weather-details-grid">
                {detailCards.map((detail) => (
                  <div className="weather-detail-card" key={detail.label}>
                    <span className="weather-detail-icon">
                      <RemixIcon name={detail.icon} size={18} style={{ color: C.deepOcean }} />
                    </span>
                    <div className="weather-detail-text">
                      <span className="weather-detail-label">{detail.label}</span>
                      <span className="weather-detail-value">{detail.value}</span>
                    </div>
                  </div>
                ))}
              </div>
            </>
          ) : loading ? (
            <article className="weather-current-card">
              <div className="weather-loc">
                <RemixIcon name="ri-map-pin-line" size={15} style={{ color: C.weatherTan }} />
                <span>NİĞDE</span>
              </div>
              <div className="weather-now-row">
                <div className="weather-now-lead">
                  <div className="weather-now-temp">--°</div>
                  <div className="weather-now-text">
                    <strong>Canlı veri bekleniyor</strong>
                    <small>Canlı veri alınıyor</small>
                  </div>
                </div>
                <div className="weather-now-glyph-box">
                  <span className="weather-spinner" aria-hidden="true" />
                </div>
              </div>
              <div className="weather-hero-metrics">
                {['Nem', 'Rüzgar', 'Yağış', 'Min / Maks'].map((label, index) => (
                  <React.Fragment key={label}>
                    {index > 0 && <span className="weather-hero-divider" aria-hidden="true" />}
                    <div className="weather-hero-metric">
                      <span className="lbl">{label}</span>
                      <span className="val">--</span>
                    </div>
                  </React.Fragment>
                ))}
              </div>
            </article>
          ) : (
            <div className="weather-empty">
              <RemixIcon name="ri-cloudy-2-line" size={64} style={{ color: C.support, opacity: 0.3 }} />
              <strong>Veri yüklenemedi</strong>
              <p>{error || 'Hava durumu şu anda alınamıyor.'}</p>
            </div>
          )}
        </section>
      </div>
    </main>
  );
};

export default WeatherPage;
