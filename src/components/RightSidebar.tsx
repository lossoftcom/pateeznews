import React, { useEffect, useMemo, useState } from 'react';
import { TrendingUp, ArrowUpRight, ArrowDownRight, Sun, Cloud, CloudRain, CloudSun, CloudSnow, CloudFog, CloudLightning, DollarSign, Euro, Bitcoin, Coins, MapPin, Mail, Phone, Navigation, Clock3 } from 'lucide-react';
import { useLanguage } from '@/context/LanguageContext';
import { type NewsItem, type SiteSettings } from '@/types';
import Skeleton from '@/components/ui/Skeleton';
import { navigate } from 'astro:transitions/client';
import { prefetch } from 'astro:prefetch';
import { subscribeNewsletter } from '@/services/appActions';
import { useToast } from '@/context/ToastContext';

interface RightSidebarProps {
   newsData?: NewsItem[];
   loading?: boolean;
   siteSettings?: SiteSettings | null;
   initialSidebarData?: any;
}

type IconComponent = React.ComponentType<{ size?: number; className?: string; strokeWidth?: number }>;
type ForecastItem = { day: string; icon: IconComponent; temp: string };
type MarketItem = { symbol: string; name: string; price: string; change: string; isUp: boolean; icon: IconComponent; color: string; bg: string };
type WeatherMotionKind = 'clear-day' | 'clear-night' | 'cloudy' | 'fog' | 'rain' | 'snow' | 'storm';
type DutyPharmacy = {
   id: string;
   name: string;
   district: string;
   address: string;
   phone: string;
   phoneHref: string;
   mapUrl: string;
   directionUrl: string;
   note?: string;
};
type DeathNotice = {
   id: string;
   name: string;
   deathDate: string;
   deathDateLabel: string;
   prayerTime: string;
   burialPlace: string;
   description: string;
};

const MemorialDoveIcon: React.FC<{ className?: string }> = ({ className = '' }) => (
   <svg viewBox="0 0 64 64" aria-hidden="true" className={className} fill="none">
      {/* Dove body */}
      <path
         d="M14 40c2-8 8-14 16-18 2-1 4-1.5 6-1.5 3 0 5.5 1.5 7 4 1 1.8 1.5 3.8 1.5 6 0 3-1 5.5-3 7.5-2.5 2.5-5.5 3.5-9 3.5-4 0-8-1-12-2.5L14 40z"
         fill="currentColor"
         opacity="0.9"
      />
      {/* Dove wing */}
      <path
         d="M36 24.5c-3-4-7-6.5-12-7.5 6-2 11-1 15 3 3 3 4.5 6.5 4.5 10.5 0 1-.1 2-.3 3-1.5-3.5-4-6.5-7.2-9z"
         fill="currentColor"
         opacity="0.65"
      />
      {/* Dove head */}
      <ellipse cx="42" cy="22" rx="4" ry="3.5" fill="currentColor" opacity="0.95" />
      {/* Eye */}
      <circle cx="43.5" cy="21.5" r="0.8" fill="#111" />
      {/* Beak */}
      <path d="M46 22l4-0.5-3.5 2" fill="#C9A96E" />
      {/* Olive branch */}
      <path
         d="M18 44c6 2 12 3 18 2"
         stroke="#5A7A5A"
         strokeWidth="1.5"
         strokeLinecap="round"
         opacity="0.6"
      />
      <ellipse cx="22" cy="43" rx="2" ry="1" fill="#5A7A5A" opacity="0.5" transform="rotate(-20 22 43)" />
      <ellipse cx="26" cy="44" rx="2" ry="1" fill="#5A7A5A" opacity="0.5" transform="rotate(-10 26 44)" />
      <ellipse cx="30" cy="44.5" rx="2" ry="1" fill="#5A7A5A" opacity="0.4" transform="rotate(-5 30 44.5)" />
      {/* Tail */}
      <path
         d="M14 40c-2 1-4 3-5 6 3-1 5-2.5 6.5-4.5"
         fill="currentColor"
         opacity="0.5"
      />
   </svg>
);

const weatherMotionKind = (code?: number, isDay?: boolean | number): WeatherMotionKind => {
   const value = Number(code ?? 2);
   const daylight = isDay !== false && Number(isDay ?? 1) !== 0;

   if (value >= 95) return 'storm';
   if ((value >= 71 && value <= 77) || value === 85 || value === 86) return 'snow';
   if ((value >= 51 && value <= 67) || (value >= 80 && value <= 82)) return 'rain';
   if (value === 45 || value === 48) return 'fog';
   if (value === 0) return daylight ? 'clear-day' : 'clear-night';
   return 'cloudy';
};

const WeatherMotionIcon: React.FC<{ code?: number; isDay?: boolean | number; label: string }> = ({ code, isDay, label }) => {
   const kind = weatherMotionKind(code, isDay);
   const isClear = kind === 'clear-day' || kind === 'clear-night';

   return (
      <div className={`weather-motion weather-motion--${kind}`} role="img" aria-label={label}>
         {isClear && (
            <>
               <span className="weather-motion__orb" />
               {kind === 'clear-day' && (
                  <>
                     <span className="weather-motion__ray weather-motion__ray--1" />
                     <span className="weather-motion__ray weather-motion__ray--2" />
                     <span className="weather-motion__ray weather-motion__ray--3" />
                     <span className="weather-motion__ray weather-motion__ray--4" />
                  </>
               )}
               {kind === 'clear-night' && <span className="weather-motion__moon-cut" />}
            </>
         )}

         {kind !== 'clear-day' && kind !== 'clear-night' && (
            <>
               {(kind === 'cloudy' || kind === 'rain' || kind === 'snow' || kind === 'storm') && (
                  <span className="weather-motion__back-orb" />
               )}
               <span className="weather-motion__cloud weather-motion__cloud--main" />
               <span className="weather-motion__cloud weather-motion__cloud--small" />

               {kind === 'rain' && (
                  <>
                     <span className="weather-motion__drop weather-motion__drop--1" />
                     <span className="weather-motion__drop weather-motion__drop--2" />
                     <span className="weather-motion__drop weather-motion__drop--3" />
                  </>
               )}

               {kind === 'snow' && (
                  <>
                     <span className="weather-motion__flake weather-motion__flake--1" />
                     <span className="weather-motion__flake weather-motion__flake--2" />
                     <span className="weather-motion__flake weather-motion__flake--3" />
                  </>
               )}

               {kind === 'storm' && (
                  <>
                     <span className="weather-motion__bolt" />
                     <span className="weather-motion__drop weather-motion__drop--1" />
                     <span className="weather-motion__drop weather-motion__drop--3" />
                  </>
               )}

               {kind === 'fog' && (
                  <>
                     <span className="weather-motion__fog weather-motion__fog--1" />
                     <span className="weather-motion__fog weather-motion__fog--2" />
                     <span className="weather-motion__fog weather-motion__fog--3" />
                  </>
               )}
            </>
         )}
      </div>
   );
};

const RightSidebar: React.FC<RightSidebarProps> = ({ newsData, loading, siteSettings, initialSidebarData }) => {
   const { t, currentLang } = useLanguage();
   const { showToast } = useToast();
   const [liveSidebar, setLiveSidebar] = useState<any>(initialSidebarData || null);
   const [livePharmacyData, setLivePharmacyData] = useState<any>(initialSidebarData?.dutyPharmacies || null);
   const [liveDeathData, setLiveDeathData] = useState<any>(initialSidebarData?.deathNotices || null);
   const [activePharmacyDistrict, setActivePharmacyDistrict] = useState('MERKEZ');
   const [newsletterEmail, setNewsletterEmail] = useState('');
   const [newsletterLoading, setNewsletterLoading] = useState(false);

   useEffect(() => {
      let isMounted = true;
      const fetchSidebar = () => {
         fetch(`/api/app/sidebar?lang=${encodeURIComponent(currentLang.code || 'tr')}`)
            .then((res) => res.json())
            .then((data) => {
               if (isMounted) setLiveSidebar(data);
            })
            .catch(() => {
               if (isMounted) setLiveSidebar(null);
            });
      };

      fetchSidebar();
      const refreshTimer = window.setInterval(fetchSidebar, 30 * 60 * 1000);

      return () => {
         isMounted = false;
         window.clearInterval(refreshTimer);
      };
   }, [currentLang.code]);

   useEffect(() => {
      let isMounted = true;
      const fetchPharmacies = () => {
         fetch('/api/app/duty-pharmacies?city=nigde')
            .then((res) => res.json())
            .then((data) => {
               if (isMounted) setLivePharmacyData(data);
            })
            .catch(() => {
               if (isMounted && !livePharmacyData) setLivePharmacyData(null);
            });
      };

      fetchPharmacies();
      const refreshTimer = window.setInterval(fetchPharmacies, 15 * 60 * 1000);

      return () => {
         isMounted = false;
         window.clearInterval(refreshTimer);
      };
   }, []);

   useEffect(() => {
      let isMounted = true;
      const fetchDeathNotices = () => {
         fetch('/api/app/death-notices?city=nigde')
            .then((res) => res.json())
            .then((data) => {
               if (isMounted) setLiveDeathData(data);
            })
            .catch(() => {
               if (isMounted && !liveDeathData) setLiveDeathData(null);
            });
      };

      fetchDeathNotices();
      const refreshTimer = window.setInterval(fetchDeathNotices, 30 * 60 * 1000);

      return () => {
         isMounted = false;
         window.clearInterval(refreshTimer);
      };
   }, []);

   const formatMetric = (value: number) => {
      return new Intl.NumberFormat(currentLang.code || 'tr', {
         notation: 'compact',
         maximumFractionDigits: 1
      }).format(Math.max(0, value || 0)).toUpperCase();
   };

   const fallbackTrending = useMemo(() => [
      { id: '01', title: t('right.trending.01.title'), hits: '128K', category: t('right.trending.01.category'), rising: true, href: '' },
      { id: '02', title: t('right.trending.02.title'), hits: '85K', category: t('right.trending.02.category'), rising: true, href: '' },
      { id: '03', title: t('right.trending.03.title'), hits: '64K', category: t('right.trending.03.category'), rising: false, href: '' },
      { id: '04', title: t('right.trending.04.title'), hits: '42K', category: t('right.trending.04.category'), rising: true, href: '' },
   ], [t]);

   const trending = useMemo(() => {
      const source = (newsData || [])
         .filter((item) => item?.title)
         .sort((a, b) => {
            const bScore = (b.views || 0) + (b.likes || 0) + ((b.comments || 0) * 2) + (b.shares || 0);
            const aScore = (a.views || 0) + (a.likes || 0) + ((a.comments || 0) * 2) + (a.shares || 0);
            return bScore - aScore;
         })
         .slice(0, 4);

      if (!source.length) return fallbackTrending;

      return source.map((item, idx) => {
         const score = (item.views || 0) || (item.likes || 0) + (item.comments || 0) + (item.shares || 0);
         return {
            id: String(idx + 1).padStart(2, '0'),
            title: item.title,
            hits: formatMetric(score),
            category: item.category || t('right.agenda'),
            rising: idx < 3,
            href: `/haber/${encodeURIComponent(item.slug || item.id)}`
         };
      });
   }, [fallbackTrending, newsData, t, currentLang.code]);

   const fallbackMarkets: MarketItem[] = [
      { symbol: 'USDT', name: t('right.markets.usdt_try'), price: '34.42', change: '%0.45', isUp: true, icon: DollarSign, color: 'text-palette-red', bg: 'bg-palette-red/5' },
      { symbol: 'EUR', name: t('right.markets.eur_try'), price: '37.15', change: '%0.12', isUp: true, icon: Euro, color: 'text-palette-tan', bg: 'bg-palette-beige/50' },
      { symbol: 'GA', name: t('right.markets.gold_gram'), price: '2.450', change: '%-0.23', isUp: false, icon: Coins, color: 'text-palette-accent', bg: 'bg-palette-accent/10' },
      { symbol: 'BTC', name: t('right.markets.bitcoin'), price: '$64.200', change: '%1.85', isUp: true, icon: Bitcoin, color: 'text-palette-maroon', bg: 'bg-palette-maroon/5' },
   ];

   const marketStyle: Record<string, any> = {
      USDT: { icon: DollarSign, color: 'text-palette-red', bg: 'bg-palette-red/5' },
      EUR: { icon: Euro, color: 'text-palette-tan', bg: 'bg-palette-beige/50' },
      GA: { icon: Coins, color: 'text-palette-accent', bg: 'bg-palette-accent/10' },
      BTC: { icon: Bitcoin, color: 'text-palette-maroon', bg: 'bg-palette-maroon/5' },
   };

   const markets = useMemo<MarketItem[]>(() => {
      const liveMarkets = Array.isArray(liveSidebar?.markets) ? liveSidebar.markets : [];
      if (!liveMarkets.length) return fallbackMarkets;

      return liveMarkets.map((market: any) => {
         const style = marketStyle[market.symbol] || marketStyle.USDT;
         const fallback = fallbackMarkets.find((item) => item.symbol === market.symbol);
         const change = typeof market.change === 'number'
            ? `%${Math.abs(market.change).toLocaleString(currentLang.code || 'tr', { maximumFractionDigits: 2 })}`
            : fallback?.change || '%0.00';
         return {
            symbol: market.symbol,
            name: t(market.nameKey || fallback?.name || ''),
            price: market.price || fallback?.price || '-',
            change,
            isUp: market.isUp !== false,
            ...style,
         };
      });
   }, [liveSidebar, t, currentLang.code]);

   const fallbackForecast: ForecastItem[] = [
      { day: t('days.mon_short'), icon: CloudSun, temp: '--°' },
      { day: t('days.tue_short'), icon: Sun, temp: '--°' },
      { day: t('days.wed_short'), icon: CloudRain, temp: '--°' },
      { day: t('days.thu_short'), icon: Cloud, temp: '--°' },
      { day: t('days.fri_short'), icon: Sun, temp: '--°' },
   ];

   const weatherIcon = (code?: number) => {
      const value = Number(code || 0);
      if ([0, 1].includes(value)) return Sun;
      if ([2, 3].includes(value)) return CloudSun;
      if ([45, 48].includes(value)) return CloudFog;
      if ((value >= 71 && value <= 77) || [85, 86].includes(value)) return CloudSnow;
      if (value >= 51 && value <= 82) return CloudRain;
      if (value >= 95) return CloudLightning;
      return Cloud;
   };

   const weatherConditionLabel = (code?: number) => {
      const value = Number(code || 0);
      const isEnglish = String(currentLang.code || '').toLowerCase().startsWith('en');
      if (value === 0) return isEnglish ? 'Clear' : 'Açık';
      if (value === 1) return isEnglish ? 'Mostly Clear' : 'Az Bulutlu';
      if (value === 2) return isEnglish ? 'Partly Cloudy' : 'Parçalı Bulutlu';
      if (value === 3) return isEnglish ? 'Cloudy' : 'Bulutlu';
      if ([45, 48].includes(value)) return isEnglish ? 'Foggy' : 'Sisli';
      if (value >= 51 && value <= 57) return isEnglish ? 'Drizzle' : 'Çisenti';
      if ((value >= 61 && value <= 67) || (value >= 80 && value <= 82)) return isEnglish ? 'Rainy' : 'Yağmurlu';
      if ((value >= 71 && value <= 77) || [85, 86].includes(value)) return isEnglish ? 'Snowy' : 'Karlı';
      if (value >= 95) return isEnglish ? 'Stormy' : 'Fırtınalı';
      return t('right.weather_partly_cloudy');
   };

   const liveWeather = liveSidebar?.weather;
   const weatherLocation = String(liveWeather?.location || siteSettings?.weather_location_name || t('right.weather')).trim();
   const currentTemperature = typeof liveWeather?.current?.temperature === 'number' ? liveWeather.current.temperature : null;
   const apparentTemperature = typeof liveWeather?.current?.apparentTemperature === 'number' ? liveWeather.current.apparentTemperature : null;
   const weatherCondition = liveWeather?.current ? weatherConditionLabel(liveWeather.current.weatherCode) : t('right.weather_partly_cloudy');
   const currentWeatherCode = liveWeather?.current?.weatherCode;
   const currentWeatherIsDay = liveWeather?.current?.isDay;
   const forecast: ForecastItem[] = liveWeather?.forecast?.length
      ? liveWeather.forecast.map((day: any) => ({
         day: new Intl.DateTimeFormat(currentLang.code || 'tr', { weekday: 'short' }).format(new Date(day.day)),
         icon: weatherIcon(day.weatherCode),
         temp: `${day.max}°`,
      }))
      : fallbackForecast;

   const pharmacyDistricts = useMemo(() => {
      const districts = Array.isArray(livePharmacyData?.districts) ? livePharmacyData.districts : [];
      return districts.length ? districts : ['MERKEZ'];
   }, [livePharmacyData]);

   useEffect(() => {
      if (!pharmacyDistricts.length || pharmacyDistricts.includes(activePharmacyDistrict)) return;
      setActivePharmacyDistrict(pharmacyDistricts.includes('MERKEZ') ? 'MERKEZ' : pharmacyDistricts[0]);
   }, [activePharmacyDistrict, pharmacyDistricts]);

   const activeDistrict = pharmacyDistricts.includes(activePharmacyDistrict)
      ? activePharmacyDistrict
      : (pharmacyDistricts.includes('MERKEZ') ? 'MERKEZ' : pharmacyDistricts[0]);

   const dutyPharmacies = Array.isArray(livePharmacyData?.pharmacies)
      ? livePharmacyData.pharmacies as DutyPharmacy[]
      : [];
   const selectedPharmacies = dutyPharmacies.filter((pharmacy) => pharmacy.district === activeDistrict);
   const pharmacyUpdatedAt = livePharmacyData?.fetchedAt
      ? new Intl.DateTimeFormat(currentLang.code || 'tr', { hour: '2-digit', minute: '2-digit' }).format(new Date(livePharmacyData.fetchedAt))
      : null;
   const deathNotices = Array.isArray(liveDeathData?.notices)
      ? liveDeathData.notices as DeathNotice[]
      : [];
   const visibleDeathNotices = deathNotices.slice(0, 3);
   const deathUpdatedAt = liveDeathData?.fetchedAt
      ? new Intl.DateTimeFormat(currentLang.code || 'tr', { hour: '2-digit', minute: '2-digit' }).format(new Date(liveDeathData.fetchedAt))
      : null;

   const openHref = (href?: string) => {
      if (!href) return;
      void navigate(href);
   };

   const handleNewsletterSubmit = async (event: React.FormEvent) => {
      event.preventDefault();
      const email = newsletterEmail.trim();
      if (!email) return;

      setNewsletterLoading(true);
      try {
         await subscribeNewsletter(email, 'right-sidebar', currentLang.code || 'tr');
         setNewsletterEmail('');
         showToast(t('common.success'), 'success');
      } catch (error: any) {
         showToast(error.message || t('common.action_failed'), 'error');
      } finally {
         setNewsletterLoading(false);
      }
   };

   if (loading) {
      return <RightSidebarSkeleton />;
   }

   return (
      <div className="flex flex-col gap-8 pt-0 pb-10">

         {/* 1. Duty Pharmacy Widget */}
         <div className="bg-[#FFFFFF] rounded-[5px] border border-gray-200 shadow-[0_4px_16px_-4px_rgba(0,0,0,0.05)] overflow-hidden relative group">
            <div className="p-5 pb-0">
               <div className="flex items-start justify-between gap-3 mb-4">
                  <div className="flex items-center gap-3 min-w-0">
                     <div className="w-11 h-11 rounded-[5px] bg-white flex items-center justify-center border border-palette-red/20 shadow-sm p-1.5">
                        <img src="/images/duty-pharmacy-logo.svg" alt="" className="w-full h-full object-contain" loading="eager" />
                     </div>
                     <div className="min-w-0">
                        <div className="flex items-center gap-2">
                           <span className="w-1.5 h-1.5 rounded-[5px] bg-palette-red animate-pulse"></span>
                           <h3 className="text-sm font-semibold text-gray-800 uppercase tracking-widest truncate">{t('right.pharmacy_title')}</h3>
                        </div>
                        <p className="text-[11px] font-medium text-palette-tan/60 mt-1 truncate">
                           {livePharmacyData?.city || 'Niğde'}{livePharmacyData?.serviceDateLabel ? ` · ${livePharmacyData.serviceDateLabel}` : ''}
                        </p>
                     </div>
                  </div>
                  <span className="shrink-0 text-[10px] font-medium text-palette-red bg-palette-red/5 border border-palette-red/10 px-2 py-1 rounded-[5px]">
                     {t('right.pharmacy_update_15')}
                  </span>
               </div>

               <div className="flex flex-wrap gap-1.5 pb-2">
                  {pharmacyDistricts.map((district: string) => {
                     const count = dutyPharmacies.filter((pharmacy) => pharmacy.district === district).length;
                     const active = district === activeDistrict;
                     return (
                        <button
                           key={district}
                           type="button"
                           onClick={() => setActivePharmacyDistrict(district)}
                           className={`h-7 flex-auto basis-[28%] min-w-0 px-1 rounded-[5px] border text-[9px] font-semibold tracking-tight transition-all flex items-center justify-center gap-1 ${active
                              ? 'bg-gray-800 text-white border-gray-800 shadow-lg shadow-gray-800/10'
                              : 'bg-palette-beige/10 text-palette-tan border-palette-beige/60 hover:bg-white hover:text-gray-800'
                              }`}
                           title={district}
                        >
                           <span className="truncate">{district}</span>
                           {count > 0 && <span className={`shrink-0 ${active ? 'text-white/55' : 'text-palette-tan/40'}`}>{count}</span>}
                        </button>
                     );
                  })}
               </div>
            </div>

            <div className="px-4 pb-4 pt-2 space-y-3">
               {selectedPharmacies.length > 0 ? selectedPharmacies.map((pharmacy) => (
                  <div key={pharmacy.id} className="rounded-[5px] border border-gray-200 bg-[#FFFFFF] p-4 shadow-sm">
                     <div className="flex items-start justify-between gap-3 mb-2">
                        <div className="min-w-0">
                           <h4 className="text-[15px] font-semibold text-gray-800 tracking-tight truncate">{pharmacy.name}</h4>
                           <div className="flex items-center gap-1.5 mt-1 text-[10px] font-medium text-palette-red uppercase tracking-widest">
                              <span className="w-1 h-1 rounded-[5px] bg-palette-red"></span>
                              {pharmacy.district}
                           </div>
                        </div>
                        <span className="material-symbols-rounded text-palette-red/80 shrink-0" style={{ fontSize: '22px' }}>local_pharmacy</span>
                     </div>

                     {pharmacy.note && (
                        <div className="mb-2 rounded-[5px] bg-palette-red/5 border border-palette-red/10 px-3 py-2 text-[11px] font-medium text-palette-red leading-relaxed">
                           {pharmacy.note}
                        </div>
                     )}

                     <p className="text-[11px] font-medium text-palette-tan/80 leading-relaxed mb-3 line-clamp-2">
                        {pharmacy.address || t('right.pharmacy_address_empty')}
                     </p>

                     <div className="grid grid-cols-2 gap-2">
                        <a
                           href={pharmacy.phoneHref ? `tel:${pharmacy.phoneHref}` : undefined}
                           className="h-9 rounded-[5px] bg-palette-beige/30 text-gray-800 border border-palette-beige/60 flex items-center justify-center gap-2 text-[11px] font-medium hover:bg-white transition-colors"
                        >
                           <Phone size={13} />
                           {pharmacy.phone || t('right.pharmacy_call')}
                        </a>
                        <a
                           href={pharmacy.directionUrl || pharmacy.mapUrl}
                           target="_blank"
                           rel="noreferrer"
                           className="h-9 rounded-[5px] bg-palette-accent text-palette-maroon flex items-center justify-center gap-2 text-[11px] font-medium shadow-lg shadow-palette-accent/20 hover:bg-palette-maroon hover:text-palette-beige transition-colors"
                        >
                           <Navigation size={13} />
                           {t('right.pharmacy_route')}
                        </a>
                     </div>
                  </div>
               )) : (
                  <div className="rounded-[5px] border border-dashed border-palette-beige/70 bg-palette-beige/10 p-4 text-center">
                     <p className="text-[12px] font-medium text-gray-800">{t('right.pharmacy_loading')}</p>
                     <p className="text-[11px] font-medium text-palette-tan/60 mt-1">{t('right.pharmacy_empty')}</p>
                  </div>
               )}
            </div>

            <div className="border-t border-palette-beige/40 bg-palette-beige/5 px-5 py-3 flex items-center justify-between gap-3">
               <div className="flex items-center gap-1.5 text-[10px] font-medium text-palette-tan/50 min-w-0">
                  <Clock3 size={11} />
                  <span className="truncate">{t('right.pharmacy_midnight_guard')}</span>
               </div>
               {pharmacyUpdatedAt && (
                  <span className="text-[10px] font-medium text-palette-tan/40 shrink-0">{pharmacyUpdatedAt}</span>
               )}
            </div>
         </div>

         {/* 2. Weather Widget */}
         <div className="bg-[#FFFFFF] rounded-[5px] border border-gray-200 shadow-[0_4px_16px_-4px_rgba(0,0,0,0.05)] overflow-hidden relative group">
            <div className="p-6 pb-0 flex items-start justify-between">
               <div>
                  <div className="flex items-center gap-1.5 text-palette-tan/50 mb-2">
                     <MapPin size={12} />
                     <span className="text-[10px] font-medium uppercase tracking-[0.15em]">{weatherLocation}</span>
                  </div>
                  <div className="flex items-center gap-3">
                     <span className="text-5xl font-light text-gray-800 tracking-tighter">{currentTemperature ?? '--'}°</span>
                     <div className="flex flex-col min-w-0">
                        <span className="text-sm font-medium text-palette-tan max-w-[130px] truncate">{weatherCondition}</span>
                        <span className="text-[11px] text-palette-tan/50 font-normal">{t('right.weather_feels_like_26').replace('26', String(apparentTemperature ?? '--'))}</span>
                     </div>
                  </div>
               </div>
               <div className="w-12 h-12 rounded-[5px] flex items-center justify-center overflow-hidden">
                  <WeatherMotionIcon code={currentWeatherCode} isDay={currentWeatherIsDay} label={weatherCondition} />
               </div>
            </div>

            <div className="mt-8 grid grid-cols-5 border-t border-palette-beige/40 bg-palette-beige/5">
               {forecast.map((day, idx) => (
                  <div key={idx} className={`flex flex-col items-center justify-center py-4 gap-2 ${idx !== forecast.length - 1 ? 'border-r border-palette-beige/40' : ''} hover:bg-white transition-colors cursor-default`}>
                     <span className="text-[10px] font-medium text-palette-tan/50 uppercase">{day.day}</span>
                     <day.icon size={16} className="text-palette-tan/60" />
                     <span className="text-sm font-medium text-gray-800">{day.temp}</span>
                  </div>
               ))}
            </div>
         </div>

         {/* 2. Gündem (Trending) */}
         <div className="bg-[#FFFFFF] rounded-[5px] border border-gray-200 shadow-[0_4px_16px_-4px_rgba(0,0,0,0.05)] overflow-hidden">
            <div className="p-6 pb-2 flex items-center justify-between">
               <div className="flex items-center gap-3">
                  <div className="w-1.5 h-1.5 bg-palette-red rounded-[5px]"></div>
                  <h3 className="font-semibold text-gray-800 uppercase tracking-[0.1em] text-[13px]">{t('right.agenda')}</h3>
               </div>
               <span className="text-[10px] font-medium text-palette-red bg-palette-red/5 px-2 py-1 rounded-[5px] border border-palette-red/10 animate-pulse">{t('right.live')}</span>
            </div>

            <div className="flex flex-col p-3 space-y-1">
               {trending.map((item, idx) => (
                  <div
                     key={idx}
                     onClick={() => openHref(item.href)}
                     onMouseEnter={() => item.href && prefetch(item.href)}
                     className="group relative flex items-center gap-5 p-4 rounded-[5px] hover:bg-palette-beige/20 transition-all duration-100 cursor-pointer border border-transparent hover:border-palette-beige/50"
                  >
                     <div className="flex flex-col items-center">
                        <span className="text-3xl font-light text-palette-tan/20 group-hover:text-palette-tan/40 transition-colors leading-none italic">
                           {item.id}
                        </span>
                     </div>

                     <div className="flex-1 min-w-0">
                        <div className="flex items-center justify-between mb-1">
                           <span className="text-[9px] font-medium text-palette-tan/50 uppercase tracking-wider">{item.category}</span>
                           <span className="text-[10px] font-medium text-palette-tan/40">{item.hits}</span>
                        </div>
                        <h4 className="news-title-font text-[15px] font-semibold text-gray-800 leading-snug group-hover:text-palette-red transition-colors line-clamp-2">
                           {item.title}
                        </h4>
                     </div>

                     {item.rising && (
                        <div className="flex-shrink-0 w-8 h-8 rounded-[5px] bg-palette-beige/30 flex items-center justify-center opacity-0 group-hover:opacity-100 transition-all">
                           <TrendingUp size={14} className="text-palette-red" />
                        </div>
                     )}
                  </div>
               ))}
            </div>

            <button
               onClick={() => {
                  const firstLiveHref = trending.find((item) => item.href)?.href;
                  openHref(firstLiveHref || '/');
               }}
               className="w-full py-4 text-[11px] font-medium text-palette-tan/50 uppercase tracking-widest hover:bg-palette-beige/20 hover:text-gray-800 transition-all border-t border-palette-beige/40"
            >
               {t('right.explore_all_agenda')}
            </button>
         </div>

         {/* 3. Markets Widget */}
         <div className="bg-[#FFFFFF] rounded-[5px] border border-gray-200 shadow-[0_4px_16px_-4px_rgba(0,0,0,0.05)] overflow-hidden">
            <div className="p-6 pb-2 flex items-center justify-between">
               <div className="flex items-center gap-3">
                  <div className="w-1.5 h-1.5 bg-palette-tan/20 rounded-[5px]"></div>
                  <h3 className="font-semibold text-gray-800 uppercase tracking-[0.1em] text-[13px]">{t('right.markets')}</h3>
               </div>
               <button onClick={() => openHref('/kategori/ekonomi')} className="text-[10px] font-medium text-palette-tan/50 hover:text-palette-red uppercase tracking-widest transition-colors">{t('right.all')}</button>
            </div>
            <div className="p-3 space-y-1.5">
               {markets.map((m, i) => (
                  <div key={i} className="flex items-center justify-between p-4 rounded-[5px] hover:bg-palette-beige/10 transition-all border border-transparent hover:border-palette-beige/30 cursor-pointer group">
                     <div className="flex items-center gap-4">
                        <div className={`w-10 h-10 rounded-[5px] ${m.bg} ${m.color} flex items-center justify-center shadow-sm border border-black/5`}>
                           <m.icon size={18} />
                        </div>
                        <div className="flex flex-col">
                           <span className="text-[13px] font-semibold text-gray-800">{m.symbol}</span>
                           <span className="text-[10px] font-medium text-palette-tan/40 uppercase tracking-tight">{m.name}</span>
                        </div>
                     </div>
                     <div className="flex flex-col items-end">
                        <span className="text-[13px] font-semibold text-gray-800">{m.price}</span>
                        <span className={`text-[10px] font-medium flex items-center gap-0.5 mt-0.5 ${m.isUp ? 'text-palette-red' : 'text-palette-accent'}`}>
                           {m.isUp ? <ArrowUpRight size={10} strokeWidth={2.5} /> : <ArrowDownRight size={10} strokeWidth={2.5} />}
                           {m.change}
                        </span>
                     </div>
                  </div>
               ))}
            </div>
         </div>

         {/* 4. Death Notices - 2026 Premium Black Memorial Design */}
         <div className="relative overflow-hidden rounded-[5px] border border-neutral-800 bg-[#111111] shadow-[0_28px_70px_-42px_rgba(0,0,0,0.95)]">
            {/* Subtle decorative elements */}
            <div className="pointer-events-none absolute inset-0">
               <div className="absolute inset-0 bg-[radial-gradient(circle_at_0%_0%,rgba(201,169,110,0.06),transparent_40%),radial-gradient(circle_at_100%_100%,rgba(201,169,110,0.04),transparent_40%)]"></div>
               <div className="absolute inset-x-6 top-0 h-px bg-gradient-to-r from-transparent via-[#C9A96E]/20 to-transparent"></div>
            </div>

            {/* Header */}
            <div className="relative px-5 pt-5 pb-4 flex items-start gap-3.5">
               <div className="w-11 h-11 rounded-full bg-[#1a1a1a] text-[#C9A96E] flex items-center justify-center border border-[#C9A96E]/20 shadow-[0_0_20px_rgba(201,169,110,0.08)]">
                  <MemorialDoveIcon className="w-7 h-7" />
               </div>
               <div className="min-w-0 flex-1 pt-0.5">
                  <h3 className="font-bold text-white/90 uppercase tracking-[0.15em] text-[12px]">{t('right.death_title')}</h3>
                  <p className="text-[10px] font-medium text-[#C9A96E]/50 mt-1 tracking-wide truncate">
                     {liveDeathData?.city || 'Niğde'}{liveDeathData?.serviceDateLabel ? ` · ${liveDeathData.serviceDateLabel}` : ''}
                  </p>
               </div>
            </div>

            {/* Notices list */}
            <div className="relative px-4 pb-4 space-y-2">
               {visibleDeathNotices.length > 0 ? visibleDeathNotices.map((notice) => (
                  <a
                     key={notice.id}
                     href={liveDeathData?.sourceUrl || 'https://nigde.bel.tr/vefat-edenler'}
                     target="_blank"
                     rel="noreferrer"
                     className="block rounded-[5px] border border-neutral-800 bg-[#1a1a1a] p-4 hover:bg-[#222] hover:border-[#C9A96E]/15 hover:-translate-y-0.5 transition-all duration-200"
                  >
                     <div className="flex items-start justify-between gap-3 mb-1.5">
                        <div className="min-w-0">
                           <h4 className="text-[14px] font-bold text-white/90 tracking-tight truncate">{notice.name}</h4>
                           <p className="text-[10px] font-semibold text-[#C9A96E]/70 uppercase tracking-widest mt-1 truncate">
                              {notice.prayerTime || t('right.death_time_empty')}{notice.burialPlace ? ` · ${notice.burialPlace}` : ''}
                           </p>
                        </div>
                        <span className="text-[9px] font-medium text-white/25 shrink-0 bg-white/5 px-2 py-0.5 rounded">{notice.deathDateLabel}</span>
                     </div>
                     <p className="text-[11px] font-medium text-white/45 leading-relaxed line-clamp-2 mt-2">
                        {notice.description}
                     </p>
                  </a>
               )) : (
                  <div className="rounded-[5px] border border-neutral-800 bg-[#1a1a1a] p-5">
                     <div className="flex items-center gap-3">
                        <div className="w-10 h-10 rounded-full bg-[#222] border border-neutral-700 flex items-center justify-center text-[#C9A96E]/50">
                           <span className="material-symbols-rounded" style={{ fontSize: '18px' }}>candle</span>
                        </div>
                        <div className="min-w-0">
                           <p className="text-[12px] font-semibold text-white/80">{t('right.death_empty_title')}</p>
                           <p className="text-[10px] font-medium text-white/35 leading-relaxed">{t('right.death_empty_desc')}</p>
                        </div>
                     </div>
                  </div>
               )}
            </div>

            {/* Footer */}
            <div className="relative border-t border-neutral-800 bg-[#0a0a0a] px-5 py-2.5 flex items-center justify-between gap-3">
               <a
                  href={liveDeathData?.sourceUrl || 'https://nigde.bel.tr/vefat-edenler'}
                  target="_blank"
                  rel="noreferrer"
                  className="text-[10px] font-medium text-white/30 hover:text-[#C9A96E]/70 transition-colors truncate"
               >
                  {t('right.death_source')}
               </a>
               {deathUpdatedAt && (
                  <span className="text-[9px] font-medium text-white/20 shrink-0">{deathUpdatedAt}</span>
               )}
            </div>
         </div>

         {/* 5. Newsletter Box */}
         <div className="bg-gradient-to-br from-gray-900 to-palette-tan rounded-[5px] p-7 text-white shadow-2xl shadow-palette-tan/30 relative overflow-hidden group">
            <div className="absolute top-0 right-0 w-32 h-32 bg-white/10 rounded-[5px] blur-[50px] -translate-y-10 translate-x-10 group-hover:bg-white/20 transition-all duration-700"></div>
            <div className="relative z-10">
               <div className="w-10 h-10 bg-white/10 rounded-[5px] flex items-center justify-center mb-5 border border-white/10">
                  <Mail size={20} />
               </div>
               <h4 className="font-semibold text-xl leading-tight mb-2 tracking-tight">{t('right.newsletter_title')}</h4>
               <p className="text-[12px] text-white/70 mb-6 font-medium leading-relaxed">{t('right.newsletter_desc')}</p>
               <form onSubmit={handleNewsletterSubmit} className="flex flex-col gap-3">
                  <input
                     type="email"
                     value={newsletterEmail}
                     onChange={(event) => setNewsletterEmail(event.target.value)}
                     placeholder={t('common.email_address')}
                     className="w-full bg-white/10 border border-white/20 rounded-[5px] px-5 py-3.5 text-sm text-white placeholder:text-white/40 focus:outline-none focus:bg-white/20 focus:border-white/40 transition-all font-medium"
                  />
                  <button disabled={newsletterLoading} className="w-full bg-palette-accent text-palette-maroon py-3.5 rounded-[5px] font-semibold text-[11px] uppercase tracking-wider hover:bg-palette-beige transition-all shadow-xl active:scale-95 disabled:opacity-60">
                     {newsletterLoading ? '...' : t('right.subscribe')}
                  </button>
               </form>
            </div>
         </div>

      </div>
   );
};

export const RightSidebarSkeleton: React.FC = () => {
   return (
      <div className="flex flex-col gap-8 pt-0 pb-10">
         {/* Duty Pharmacy Skeleton */}
         <div className="bg-white rounded-[5px] border border-palette-beige/60 p-5 space-y-4">
            <div className="flex items-center gap-3">
               <Skeleton variant="rectangular" className="w-11 h-11" />
               <div className="space-y-2 flex-1">
                  <Skeleton className="w-32 h-3" />
                  <Skeleton className="w-24 h-2" />
               </div>
            </div>
            <div className="flex gap-2">
               <Skeleton className="w-16 h-8" />
               <Skeleton className="w-20 h-8" />
               <Skeleton className="w-14 h-8" />
            </div>
            <Skeleton variant="rectangular" className="w-full h-28" />
         </div>

         {/* Weather Skeleton */}
         <div className="bg-white rounded-[5px] border border-palette-beige/60 p-6 space-y-4">
            <Skeleton className="w-24 h-3" />
            <div className="flex items-center gap-4">
               <Skeleton className="w-16 h-10" />
               <Skeleton className="w-20 h-6" />
            </div>
         </div>

         {/* Trending Skeleton */}
         <div className="bg-white rounded-[5px] border border-palette-beige/60 p-6 space-y-4">
            <Skeleton className="w-32 h-4" />
            <div className="space-y-4">
               {[1, 2, 3, 4].map(i => (
                  <div key={i} className="flex gap-4">
                     <Skeleton className="w-8 h-8" />
                     <div className="flex-1 space-y-2">
                        <Skeleton className="w-16 h-2" />
                        <Skeleton className="w-full h-4" />
                     </div>
                  </div>
               ))}
            </div>
         </div>

         {/* Death Notices Skeleton */}
         <div className="bg-palette-maroon rounded-[5px] border border-white/10 p-5 space-y-4">
            <div className="flex items-center gap-3">
               <Skeleton variant="rectangular" className="w-10 h-10" />
               <div className="space-y-2 flex-1">
                  <Skeleton className="w-28 h-3" />
                  <Skeleton className="w-24 h-2" />
               </div>
            </div>
            {[1, 2].map(i => (
               <div key={i} className="rounded-[5px] border border-white/10 bg-white/5 p-4 space-y-3">
                  <Skeleton className="w-32 h-4" />
                  <Skeleton className="w-20 h-3" />
                  <Skeleton className="w-full h-10" />
               </div>
            ))}
         </div>
      </div>
   );
};

export default RightSidebar;
