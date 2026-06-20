import React, { useEffect, useMemo, useState } from 'react';
import { useLanguage } from '@/context/LanguageContext';
import { dataService } from '@/services/dataService';
import { navigateImmediately } from '@/utils/immediateNavigation';
import { isOpinionColumn } from '@/utils/opinionColumns';
import type { NewsItem } from '@/types';
import RemixIcon from './ui/RemixIcon';

type MarketRate = {
  id?: string;
  symbol?: string;
  sourceSymbol?: string;
  name?: string;
  ask?: number;
  bid?: number;
  changePercent?: number | null;
  isUp?: boolean;
  currencySymbol?: string;
};

type MarketsPayload = {
  currencies?: MarketRate[];
  gold?: MarketRate[];
};

type MarketCard = {
  key: string;
  title: string;
  subtitle: string;
  price: string;
  change: string;
  isUp: boolean;
  icon: string;
  accent: string;
  spark: number[];
};

type WeatherCurrent = {
  temperature?: number;
  apparentTemperature?: number;
  humidity?: number;
  weatherCode?: number;
  isDay?: number;
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
  max?: number;
  min?: number;
  precipitationProbability?: number;
  windSpeedMax?: number;
};

type WeatherPayload = {
  location?: string;
  current?: WeatherCurrent | null;
  hourly?: WeatherHour[];
  daily?: WeatherDay[];
};

type WeatherView = {
  location: string;
  temp: number;
  feelsLike: number;
  condition: string;
  humidity: number;
  wind: number;
  precipitation: number;
  min: number;
  max: number;
  code: number;
  isDay: boolean;
  hours: Required<Pick<WeatherHour, 'label' | 'temperature' | 'weatherCode' | 'isDay' | 'precipitationProbability'>>[];
};

type ColumnistSummary = {
  key: string;
  name: string;
  initials: string;
  info: string;
  date: string;
  avatarUrl: string;
  latestArticle: NewsItem;
  count: number;
};

const FALLBACK_MARKETS: MarketCard[] = [
  {
    key: 'usd',
    title: 'Dolar',
    subtitle: 'USD/TRY',
    price: '₺46,4471',
    change: '-0,08%',
    isUp: false,
    icon: 'ri-money-dollar-circle-fill',
    accent: '#16A34A',
    spark: [0.66, 0.62, 0.58, 0.61, 0.48, 0.44, 0.36],
  },
  {
    key: 'eur',
    title: 'Euro',
    subtitle: 'EUR/TRY',
    price: '₺53,3126',
    change: '+0,08%',
    isUp: true,
    icon: 'ri-money-euro-circle-fill',
    accent: '#2563EB',
    spark: [0.38, 0.36, 0.44, 0.43, 0.52, 0.57, 0.68],
  },
  {
    key: 'borsa',
    title: 'Borsa',
    subtitle: 'BIST 100',
    price: '14.827,4',
    change: '+2,82%',
    isUp: true,
    icon: 'ri-line-chart-fill',
    accent: '#7C3AED',
    spark: [0.32, 0.31, 0.38, 0.35, 0.49, 0.51, 0.63],
  },
  {
    key: 'gram',
    title: 'Gram Altın',
    subtitle: 'TL/GRAM',
    price: '₺4.321,0',
    change: '+0,42%',
    isUp: true,
    icon: 'ri-coins-fill',
    accent: '#F59E0B',
    spark: [0.35, 0.39, 0.36, 0.44, 0.50, 0.54, 0.61],
  },
  {
    key: 'ceyrek',
    title: 'Çeyrek Altın',
    subtitle: 'TL/ADET',
    price: '₺7.061,0',
    change: '+0,39%',
    isUp: true,
    icon: 'ri-medal-fill',
    accent: '#D97706',
    spark: [0.34, 0.36, 0.41, 0.39, 0.47, 0.52, 0.58],
  },
  {
    key: 'btc',
    title: 'Bitcoin',
    subtitle: 'BTC/USD',
    price: '$104.200',
    change: '+1,85%',
    isUp: true,
    icon: 'ri-btc-fill',
    accent: '#F7931A',
    spark: [0.42, 0.48, 0.45, 0.56, 0.52, 0.61, 0.68],
  },
];

const FALLBACK_WEATHER: WeatherView = {
  location: 'Niğde',
  temp: 18,
  feelsLike: 18,
  condition: 'Sağanak yağışlı',
  humidity: 57,
  wind: 3,
  precipitation: 90,
  min: 15,
  max: 22,
  code: 80,
  isDay: true,
  hours: [
    { label: 'Şimdi', temperature: 18, weatherCode: 80, isDay: 1, precipitationProbability: 57 },
    { label: '19:00', temperature: 19, weatherCode: 3, isDay: 1, precipitationProbability: 75 },
    { label: '20:00', temperature: 18, weatherCode: 61, isDay: 0, precipitationProbability: 58 },
    { label: '21:00', temperature: 17, weatherCode: 2, isDay: 0, precipitationProbability: 22 },
  ],
};

const MARKET_META: Record<string, Pick<MarketCard, 'title' | 'subtitle' | 'icon' | 'accent'>> = {
  usd: { title: 'Dolar', subtitle: 'USD/TRY', icon: 'ri-money-dollar-circle-fill', accent: '#16A34A' },
  eur: { title: 'Euro', subtitle: 'EUR/TRY', icon: 'ri-money-euro-circle-fill', accent: '#2563EB' },
  gram: { title: 'Gram Altın', subtitle: 'TL/GRAM', icon: 'ri-coins-fill', accent: '#F59E0B' },
  ceyrek: { title: 'Çeyrek Altın', subtitle: 'TL/ADET', icon: 'ri-medal-fill', accent: '#D97706' },
  btc: { title: 'Bitcoin', subtitle: 'BTC/USD', icon: 'ri-btc-fill', accent: '#F7931A' },
};

const toNumber = (value: unknown) => {
  const numeric = Number(value);
  return Number.isFinite(numeric) ? numeric : null;
};

const isMobileViewport = () =>
  typeof window === 'undefined' || window.matchMedia('(max-width: 767px)').matches;

const formatMarketNumber = (value: number, digits?: number) =>
  new Intl.NumberFormat('tr-TR', {
    minimumFractionDigits: digits ?? (value >= 100 ? 1 : 4),
    maximumFractionDigits: digits ?? (value >= 100 ? 1 : 4),
  }).format(value);

const formatMarketPrice = (rate: MarketRate, fallback: string) => {
  const value = toNumber(rate.ask) ?? toNumber(rate.bid);
  if (value === null) return fallback;
  const prefix = rate.currencySymbol || '₺';
  return `${prefix}${formatMarketNumber(value)}`;
};

const formatChange = (value: number | null | undefined, fallback: string) => {
  if (typeof value !== 'number' || !Number.isFinite(value)) return fallback;
  const sign = value > 0 ? '+' : '';
  return `${sign}${value.toFixed(2).replace('.', ',')}%`;
};

const findRate = (rates: MarketRate[] | undefined, symbols: string[]) => {
  const wanted = new Set(symbols.map((symbol) => symbol.toUpperCase()));
  return (rates || []).find((rate) => {
    const values = [rate.symbol, rate.sourceSymbol, rate.id, rate.name]
      .map((value) => String(value || '').trim().toUpperCase())
      .filter(Boolean);
    return values.some((value) => wanted.has(value) || [...wanted].some((symbol) => value.includes(symbol)));
  });
};

const sparkFromChange = (isUp: boolean, changePercent?: number | null) => {
  const strength = Math.min(Math.abs(Number(changePercent || 0)) / 4, 1);
  const base = isUp
    ? [0.34, 0.38, 0.36, 0.45, 0.48, 0.55, 0.62]
    : [0.64, 0.61, 0.56, 0.58, 0.48, 0.43, 0.36];
  return base.map((point, index) => {
    const drift = (index / (base.length - 1)) * strength * 0.18;
    return Math.max(0.16, Math.min(0.82, isUp ? point + drift : point - drift));
  });
};

const normalizeMarketCard = (
  key: keyof typeof MARKET_META,
  rate: MarketRate | undefined,
  fallback: MarketCard,
): MarketCard => {
  if (!rate) return fallback;
  const changePercent = typeof rate.changePercent === 'number' ? rate.changePercent : null;
  const isUp = typeof rate.isUp === 'boolean' ? rate.isUp : (changePercent ?? 0) >= 0;
  return {
    key,
    ...MARKET_META[key],
    price: formatMarketPrice(rate, fallback.price),
    change: formatChange(changePercent, fallback.change),
    isUp,
    spark: sparkFromChange(isUp, changePercent),
  };
};

const normalizeMarkets = (payload: MarketsPayload | null) => {
  if (!payload) return FALLBACK_MARKETS;
  const cards = [...FALLBACK_MARKETS];
  cards[0] = normalizeMarketCard('usd', findRate(payload.currencies, ['USD']), FALLBACK_MARKETS[0]);
  cards[1] = normalizeMarketCard('eur', findRate(payload.currencies, ['EUR']), FALLBACK_MARKETS[1]);
  cards[3] = normalizeMarketCard('gram', findRate(payload.gold, ['GRAM', 'GA']), FALLBACK_MARKETS[3]);
  cards[4] = normalizeMarketCard('ceyrek', findRate(payload.gold, ['CEYREK', 'C']), FALLBACK_MARKETS[4]);
  cards[5] = normalizeMarketCard('btc', findRate(payload.currencies, ['BTC']), FALLBACK_MARKETS[5]);
  return cards;
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

const weatherIcon = (code: number, isDay: boolean) => {
  if (code === 0) return isDay ? 'ri-sun-fill' : 'ri-moon-clear-fill';
  if (code === 1 || code === 2) return isDay ? 'ri-sun-cloudy-fill' : 'ri-moon-cloudy-fill';
  if (code === 45 || code === 48) return 'ri-sun-foggy-fill';
  if ((code >= 51 && code <= 67) || code >= 80) return 'ri-rainy-fill';
  if (code >= 71 && code <= 77) return 'ri-cloudy-fill';
  return 'ri-cloudy-fill';
};

const weatherTint = (code: number, isDay: boolean) => {
  if (code === 0 && !isDay) return '#2C3E50';
  if ((code >= 51 && code <= 67) || code >= 71 || code >= 80) return '#2563EB';
  if (code === 45 || code === 48) return '#8A949B';
  return '#F39C12';
};

const resolveWeather = (payload: WeatherPayload | null): WeatherView => {
  const current = payload?.current;
  if (!current) return FALLBACK_WEATHER;
  const daily = payload?.daily?.[0];
  const code = Math.round(toNumber(current.weatherCode) ?? FALLBACK_WEATHER.code);
  const isDay = (toNumber(current.isDay) ?? 1) === 1;
  const hours = (payload?.hourly || []).slice(0, 8).map((hour, index) => ({
    label: String(hour.label || (index === 0 ? 'Şimdi' : '--:--')),
    temperature: Math.round(toNumber(hour.temperature) ?? FALLBACK_WEATHER.temp),
    weatherCode: Math.round(toNumber(hour.weatherCode) ?? code),
    isDay: Math.round(toNumber(hour.isDay) ?? (isDay ? 1 : 0)),
    precipitationProbability: Math.round(toNumber(hour.precipitationProbability) ?? 0),
  }));
  return {
    location: String(payload?.location || FALLBACK_WEATHER.location),
    temp: Math.round(toNumber(current.temperature) ?? FALLBACK_WEATHER.temp),
    feelsLike: Math.round(toNumber(current.apparentTemperature) ?? FALLBACK_WEATHER.feelsLike),
    condition: weatherConditionLabel(code),
    humidity: Math.round(toNumber(current.humidity) ?? FALLBACK_WEATHER.humidity),
    wind: Math.round(toNumber(current.windSpeed) ?? toNumber(daily?.windSpeedMax) ?? FALLBACK_WEATHER.wind),
    precipitation: Math.round(toNumber(daily?.precipitationProbability) ?? FALLBACK_WEATHER.precipitation),
    min: Math.round(toNumber(daily?.min) ?? FALLBACK_WEATHER.min),
    max: Math.round(toNumber(daily?.max) ?? FALLBACK_WEATHER.max),
    code,
    isDay,
    hours: hours.length ? hours : FALLBACK_WEATHER.hours,
  };
};

const cleanText = (value: unknown, fallback = '') => String(value || '').trim() || fallback;

const formatColumnDate = (timestamp: string) => {
  const date = new Date(timestamp);
  if (Number.isNaN(date.getTime())) return '';
  return new Intl.DateTimeFormat('tr-TR', {
    day: 'numeric',
    month: 'long',
    year: 'numeric',
  }).format(date);
};

const initials = (name: string) => {
  const parts = name.trim().split(/\s+/).filter(Boolean);
  if (parts.length === 0) return 'P';
  const first = Array.from(parts[0])[0] || '';
  const second = parts.length > 1 ? Array.from(parts[parts.length - 1])[0] || '' : '';
  return `${first}${second}`.toLocaleUpperCase('tr-TR');
};

const authorKey = (item: NewsItem) => {
  const id = cleanText(item.publisherId);
  if (id) return `id:${id}`;
  const handle = cleanText(item.publisherHandle).replace(/^@+/, '').toLocaleLowerCase('tr-TR');
  if (handle) return `handle:${handle}`;
  return `name:${cleanText(item.author || item.source, 'Pateez').toLocaleLowerCase('tr-TR')}`;
};

const buildColumnists = (items: NewsItem[], filterOpinionColumns = true) => {
  const state = new Map<string, ColumnistSummary>();
  const sourceItems = filterOpinionColumns ? items.filter(isOpinionColumn) : items;
  for (const item of sourceItems) {
    const key = authorKey(item);
    const name = cleanText(item.author || item.source, 'Pateez');
    const existing = state.get(key);
    if (!existing) {
      state.set(key, {
        key,
        name,
        initials: initials(name),
        info: cleanText(item.publisherExpertise || item.publisherBio || item.summary, item.summary),
        date: formatColumnDate(item.timestamp),
        avatarUrl: cleanText(item.sourceAvatar),
        latestArticle: item,
        count: 1,
      });
      continue;
    }
    existing.count += 1;
    if (new Date(item.timestamp).getTime() > new Date(existing.latestArticle.timestamp).getTime()) {
      existing.latestArticle = item;
      existing.info = cleanText(item.publisherExpertise || item.publisherBio || item.summary, existing.info);
      existing.date = formatColumnDate(item.timestamp);
    }
    if (!existing.avatarUrl && item.sourceAvatar) existing.avatarUrl = item.sourceAvatar;
  }
  return Array.from(state.values()).sort((a, b) => {
    const latest = new Date(b.latestArticle.timestamp).getTime() - new Date(a.latestArticle.timestamp).getTime();
    return latest || b.count - a.count;
  });
};

const Sparkline: React.FC<{ values: number[]; up: boolean }> = ({ values, up }) => {
  const points = values.map((value, index) => {
    const x = (index / Math.max(values.length - 1, 1)) * 27;
    const y = 14 - Math.max(0, Math.min(1, value)) * 12;
    return `${x.toFixed(1)},${y.toFixed(1)}`;
  }).join(' ');
  return (
    <svg className="home-mobile-market-spark" viewBox="0 0 27 15" aria-hidden="true">
      <polyline points={points} fill="none" stroke={up ? '#16A34A' : '#E5484D'} strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" />
    </svg>
  );
};

export const HomeMarketStrip: React.FC = () => {
  const { currentLang } = useLanguage();
  const [cards, setCards] = useState<MarketCard[]>(FALLBACK_MARKETS);

  useEffect(() => {
    if (!isMobileViewport()) return;
    let active = true;
    fetch(`/api/app/markets?lang=${encodeURIComponent(currentLang.code || 'tr')}`, { headers: { Accept: 'application/json' } })
      .then((response) => response.ok ? response.json() as Promise<MarketsPayload> : null)
      .then((payload) => {
        if (active) setCards(normalizeMarkets(payload));
      })
      .catch(() => {
        if (active) setCards(FALLBACK_MARKETS);
      });
    return () => {
      active = false;
    };
  }, [currentLang.code]);

  return (
    <section className="home-mobile-service home-mobile-market md:hidden" aria-label="Piyasa">
      <div className="home-mobile-strip-header">
        <span className="home-mobile-live-dot" />
        <div className="home-mobile-strip-title">
          <strong>Piyasa</strong>
          <span>Serbest</span>
        </div>
        <span className="home-mobile-strip-link">Döviz &amp; Altın <RemixIcon name="ri-arrow-right-line" size={11} /></span>
      </div>
      <div className="home-mobile-market-list">
        {cards.map((card) => (
          <article className="home-mobile-market-card" key={card.key} style={{ '--market-accent': card.accent } as React.CSSProperties}>
            <div className="home-mobile-market-top">
              <span className="home-mobile-market-icon"><RemixIcon name={card.icon} size={12} /></span>
              <span className={`home-mobile-market-change ${card.isUp ? 'is-up' : 'is-down'}`}>
                <RemixIcon name={card.isUp ? 'ri-arrow-up-s-fill' : 'ri-arrow-down-s-fill'} size={10} />
                {card.change}
              </span>
            </div>
            <div className="home-mobile-market-name">{card.title}</div>
            <div className="home-mobile-market-subtitle">{card.subtitle}</div>
            <div className="home-mobile-market-bottom">
              <strong>{card.price}</strong>
              <Sparkline values={card.spark} up={card.isUp} />
            </div>
          </article>
        ))}
      </div>
    </section>
  );
};

export const HomeWeatherCard: React.FC = () => {
  const { currentLang } = useLanguage();
  const [weather, setWeather] = useState<WeatherView>(FALLBACK_WEATHER);

  useEffect(() => {
    if (!isMobileViewport()) return;
    let active = true;
    fetch(`/api/app/weather?lang=${encodeURIComponent(currentLang.code || 'tr')}`, { headers: { Accept: 'application/json' } })
      .then((response) => response.ok ? response.json() as Promise<WeatherPayload> : null)
      .then((payload) => {
        if (active) setWeather(resolveWeather(payload));
      })
      .catch(() => {
        if (active) setWeather(FALLBACK_WEATHER);
      });
    return () => {
      active = false;
    };
  }, [currentLang.code]);

  const tint = weatherTint(weather.code, weather.isDay);

  return (
    <section className="home-mobile-service home-mobile-feed-service home-mobile-weather md:hidden" aria-label="Hava durumu">
      <div className="home-mobile-strip-header home-mobile-weather-header">
        <RemixIcon name={weatherIcon(weather.code, weather.isDay)} size={16} style={{ color: tint }} />
        <div className="home-mobile-strip-title">
          <strong>{weather.location}</strong>
          <span>Bugün</span>
        </div>
        <span className="home-mobile-strip-link">Hava Durumu <RemixIcon name="ri-arrow-right-line" size={11} /></span>
      </div>
      <div className="home-mobile-weather-scroll">
        <div className="home-mobile-weather-now">
          <div className="home-mobile-weather-main">
            <div>
              <div className="home-mobile-weather-temp">{weather.temp}<span>°</span></div>
              <strong>{weather.condition}</strong>
              <p>Hissedilen {weather.feelsLike}°</p>
            </div>
            <span className="home-mobile-weather-glyph" style={{ '--weather-tint': tint } as React.CSSProperties}>
              <RemixIcon name={weatherIcon(weather.code, weather.isDay)} size={20} />
            </span>
          </div>
          <div className="home-mobile-weather-stats">
            <span className="is-humidity"><RemixIcon name="ri-drop-fill" size={11} /> %{weather.humidity}</span>
            <span className="is-wind"><RemixIcon name="ri-windy-fill" size={11} /> {weather.wind}</span>
            <span className="is-rain"><RemixIcon name="ri-water-percent-fill" size={11} /> %{weather.precipitation}</span>
            <span className="is-temp"><RemixIcon name="ri-temp-hot-fill" size={11} /> {weather.min}°/{weather.max}°</span>
          </div>
        </div>
        <span className="home-mobile-hours-divider" />
        {weather.hours.map((hour, index) => {
          const hourCode = Math.round(toNumber(hour.weatherCode) ?? weather.code);
          const hourIsDay = Math.round(toNumber(hour.isDay) ?? 1) === 1;
          return (
            <div className="home-mobile-hour-tile" key={`${hour.label}-${index}`}>
              <span>{hour.label}</span>
              <RemixIcon name={weatherIcon(hourCode, hourIsDay)} size={16} style={{ color: weatherTint(hourCode, hourIsDay) }} />
              <strong>{Math.round(toNumber(hour.temperature) ?? weather.temp)}°</strong>
              <small>%{Math.round(toNumber(hour.precipitationProbability) ?? 0)}</small>
            </div>
          );
        })}
      </div>
    </section>
  );
};

interface HomeColumnistStripProps {
  articles: NewsItem[];
  onNewsSelect?: (id: string) => void;
}

export const HomeColumnistStrip: React.FC<HomeColumnistStripProps> = ({ articles, onNewsSelect }) => {
  const { currentLang } = useLanguage();
  const initialItems = useMemo(() => buildColumnists(articles), [articles]);
  const [items, setItems] = useState<ColumnistSummary[]>(initialItems);

  useEffect(() => {
    setItems(initialItems);
  }, [initialItems]);

  useEffect(() => {
    if (!isMobileViewport()) return;
    let active = true;
    dataService.getNewsItems(currentLang.code || 'tr', 'kose-yazisi', 12, { fresh: true })
      .then((fresh) => {
        if (!active) return;
        const summaries = buildColumnists(fresh, false);
        if (summaries.length > 0) setItems(summaries);
      })
      .catch(() => null);
    return () => {
      active = false;
    };
  }, [currentLang.code]);

  if (items.length === 0) return null;

  return (
    <section className="home-mobile-service home-mobile-feed-service home-mobile-columnists md:hidden" aria-label="Yazarlar">
      <div className="home-mobile-strip-header home-mobile-columnist-header">
        <div className="home-mobile-columnist-title">
          <span />
          <strong>Yazarlar</strong>
        </div>
        <button type="button" className="home-mobile-strip-link" onClick={() => void navigateImmediately('/kategori/kose-yazisi')}>
          Tümü <RemixIcon name="ri-arrow-right-line" size={11} />
        </button>
      </div>
      <div className="home-mobile-columnist-list">
        {items.slice(0, 8).map((item) => (
          <button
            type="button"
            className="home-mobile-columnist-card"
            key={item.key}
            onClick={() => onNewsSelect?.(item.latestArticle.id)}
          >
            <strong>{item.latestArticle.title}</strong>
            <p>{item.info}</p>
            <span className="home-mobile-columnist-author">
              {item.avatarUrl ? (
                <img src={item.avatarUrl} alt="" loading="lazy" />
              ) : (
                <span className="home-mobile-columnist-avatar">{item.initials}</span>
              )}
              <span>
                <b>{item.name}</b>
                <small>{item.date}</small>
              </span>
            </span>
          </button>
        ))}
      </div>
    </section>
  );
};
