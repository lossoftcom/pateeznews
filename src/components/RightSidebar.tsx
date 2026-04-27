import React, { useEffect, useMemo, useState } from 'react';
import { TrendingUp, ArrowUpRight, ArrowDownRight, Sun, Cloud, CloudRain, CloudSun, CloudSnow, CloudFog, CloudLightning, DollarSign, Euro, Bitcoin, Coins, UserPlus, CheckCircle2, MapPin, Mail, Zap, Phone, Navigation, Clock3 } from 'lucide-react';
import { useLanguage } from '@/context/LanguageContext';
import { type NewsItem, type SiteSettings } from '@/types';
import Skeleton from '@/components/ui/Skeleton';
import { navigate } from 'astro:transitions/client';
import { prefetch } from 'astro:prefetch';
import { postAction, subscribeNewsletter } from '@/services/appActions';
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
   const [activePharmacyDistrict, setActivePharmacyDistrict] = useState('MERKEZ');
   const [newsletterEmail, setNewsletterEmail] = useState('');
   const [newsletterLoading, setNewsletterLoading] = useState(false);
   const [followedPublishers, setFollowedPublishers] = useState<Record<string, boolean>>({});

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
      { symbol: 'USDT', name: t('right.markets.usdt_try'), price: '34.42', change: '%0.45', isUp: true, icon: DollarSign, color: 'text-emerald-500', bg: 'bg-emerald-50' },
      { symbol: 'EUR', name: t('right.markets.eur_try'), price: '37.15', change: '%0.12', isUp: true, icon: Euro, color: 'text-palette-tan', bg: 'bg-palette-beige/50' },
      { symbol: 'GA', name: t('right.markets.gold_gram'), price: '2.450', change: '%-0.23', isUp: false, icon: Coins, color: 'text-amber-600', bg: 'bg-amber-50' },
      { symbol: 'BTC', name: t('right.markets.bitcoin'), price: '$64.200', change: '%1.85', isUp: true, icon: Bitcoin, color: 'text-orange-500', bg: 'bg-orange-50' },
   ];

   const marketStyle: Record<string, any> = {
      USDT: { icon: DollarSign, color: 'text-emerald-500', bg: 'bg-emerald-50' },
      EUR: { icon: Euro, color: 'text-palette-tan', bg: 'bg-palette-beige/50' },
      GA: { icon: Coins, color: 'text-amber-600', bg: 'bg-amber-50' },
      BTC: { icon: Bitcoin, color: 'text-orange-500', bg: 'bg-orange-50' },
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

   const asImageSrc = (value?: string) => {
      const raw = String(value || '').trim();
      if (!raw || raw.includes('<')) return '';
      if (raw.startsWith('http://') || raw.startsWith('https://') || raw.startsWith('/api/storage/file/') || raw.startsWith('/Upload/')) return raw;
      return '';
   };

   const suggestions = useMemo(() => {
      const unique = new Map<string, { name: string; handle: string; img: string; bg: string; href: string; publisherId?: string }>();

      (newsData || []).forEach((item) => {
         const name = (item.source || item.author || '').trim();
         if (!name || unique.has(name)) return;
         unique.set(name, {
            name,
            handle: `@${name.toLowerCase().replace(/\s+/g, '').replace(/[^a-z0-9_.-]/g, '') || 'pateez'}`,
            img: item.publisherId || name,
            bg: asImageSrc(item.coverThumbnail || item.thumbnail || item.mediaUrl) || `https://picsum.photos/seed/${encodeURIComponent(name)}/400`,
            href: '',
            publisherId: item.publisherId,
         });
      });

      const liveSuggestions = Array.from(unique.values()).slice(0, 2);
      if (liveSuggestions.length) return liveSuggestions;

      return [
         { name: t('right.suggestions.space_explorer'), handle: '@uzaykasifi', img: 'space', bg: 'https://images.unsplash.com/photo-1451187580459-43490279c0fa?auto=format&fit=crop&q=80&w=400', href: '' },
         { name: t('right.suggestions.gourmet_guide'), handle: '@gurmeist', img: 'food', bg: 'https://images.unsplash.com/photo-1504674900247-0877df9cc836?auto=format&fit=crop&q=80&w=400', href: '' },
      ];
   }, [newsData, t]);

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

   const handleSuggestionFollow = async (event: React.MouseEvent, publisherId?: string) => {
      event.stopPropagation();
      if (!publisherId) return;
      try {
         const result = await postAction<{ following: boolean }>('toggle_follow', { publisherId });
         setFollowedPublishers((prev) => ({ ...prev, [publisherId]: result.following }));
      } catch {
         showToast(t('auth.login_required_follow'), 'info');
      }
   };

   if (loading) {
      return <RightSidebarSkeleton />;
   }

   return (
      <div className="flex flex-col gap-8 pt-0 pb-10">

         {/* 1. Duty Pharmacy Widget */}
         <div className="bg-white rounded-[5px] border border-palette-beige/60 shadow-sm overflow-hidden relative group">
            <div className="p-5 pb-0">
               <div className="flex items-start justify-between gap-3 mb-4">
                  <div className="flex items-center gap-3 min-w-0">
                     <div className="w-11 h-11 rounded-[5px] bg-white flex items-center justify-center border border-palette-red/20 shadow-sm p-1.5">
                        <img src="/images/duty-pharmacy-logo.svg" alt="" className="w-full h-full object-contain" loading="eager" />
                     </div>
                     <div className="min-w-0">
                        <div className="flex items-center gap-2">
                           <span className="w-1.5 h-1.5 rounded-[5px] bg-palette-red animate-pulse"></span>
                           <h3 className="text-[13px] font-black text-palette-red uppercase tracking-[0.12em] truncate">{t('right.pharmacy_title')}</h3>
                        </div>
                        <p className="text-[10px] font-bold text-palette-tan/45 mt-1 truncate">
                           {livePharmacyData?.city || 'Niğde'}{livePharmacyData?.serviceDateLabel ? ` · ${livePharmacyData.serviceDateLabel}` : ''}
                        </p>
                     </div>
                  </div>
                  <span className="shrink-0 text-[9px] font-black text-palette-red bg-palette-red/5 border border-palette-red/10 px-2 py-1 rounded-[5px]">
                     {t('right.pharmacy_update_15')}
                  </span>
               </div>

               <div className="grid grid-cols-3 gap-1.5 pb-2">
                  {pharmacyDistricts.map((district) => {
                     const count = dutyPharmacies.filter((pharmacy) => pharmacy.district === district).length;
                     const active = district === activeDistrict;
                     return (
                        <button
                           key={district}
                           type="button"
                           onClick={() => setActivePharmacyDistrict(district)}
                           className={`h-7 w-full min-w-0 px-2 rounded-[5px] border text-[9px] font-black transition-all flex items-center justify-center gap-1 ${active
                              ? 'bg-gray-900 text-white border-gray-900 shadow-lg shadow-gray-900/10'
                              : 'bg-palette-beige/10 text-palette-tan border-palette-beige/60 hover:bg-white hover:text-gray-900'
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
                  <div key={pharmacy.id} className="rounded-[5px] border border-palette-beige/60 bg-gradient-to-br from-palette-beige/10 via-white to-white p-4 shadow-sm">
                     <div className="flex items-start justify-between gap-3 mb-2">
                        <div className="min-w-0">
                           <h4 className="text-[15px] font-black text-gray-900 tracking-tight truncate">{pharmacy.name}</h4>
                           <div className="flex items-center gap-1.5 mt-1 text-[10px] font-black text-palette-red uppercase tracking-widest">
                              <span className="w-1 h-1 rounded-[5px] bg-palette-red"></span>
                              {pharmacy.district}
                           </div>
                        </div>
                        <span className="material-symbols-rounded text-palette-red/80 shrink-0" style={{ fontSize: '22px' }}>local_pharmacy</span>
                     </div>

                     {pharmacy.note && (
                        <div className="mb-2 rounded-[5px] bg-palette-red/5 border border-palette-red/10 px-3 py-2 text-[10px] font-black text-palette-red leading-snug">
                           {pharmacy.note}
                        </div>
                     )}

                     <p className="text-[11px] font-bold text-palette-tan/70 leading-relaxed mb-3 line-clamp-2">
                        {pharmacy.address || t('right.pharmacy_address_empty')}
                     </p>

                     <div className="grid grid-cols-2 gap-2">
                        <a
                           href={pharmacy.phoneHref ? `tel:${pharmacy.phoneHref}` : undefined}
                           className="h-9 rounded-[5px] bg-palette-beige/30 text-gray-900 border border-palette-beige/60 flex items-center justify-center gap-2 text-[10px] font-black hover:bg-white transition-colors"
                        >
                           <Phone size={13} />
                           {pharmacy.phone || t('right.pharmacy_call')}
                        </a>
                        <a
                           href={pharmacy.directionUrl || pharmacy.mapUrl}
                           target="_blank"
                           rel="noreferrer"
                           className="h-9 rounded-[5px] bg-emerald-600 text-white flex items-center justify-center gap-2 text-[10px] font-black shadow-lg shadow-emerald-600/15 hover:bg-emerald-700 transition-colors"
                        >
                           <Navigation size={13} />
                           {t('right.pharmacy_route')}
                        </a>
                     </div>
                  </div>
               )) : (
                  <div className="rounded-[5px] border border-dashed border-palette-beige/70 bg-palette-beige/10 p-4 text-center">
                     <p className="text-[12px] font-black text-gray-900">{t('right.pharmacy_loading')}</p>
                     <p className="text-[10px] font-bold text-palette-tan/50 mt-1">{t('right.pharmacy_empty')}</p>
                  </div>
               )}
            </div>

            <div className="border-t border-palette-beige/40 bg-palette-beige/5 px-5 py-3 flex items-center justify-between gap-3">
               <div className="flex items-center gap-1.5 text-[9px] font-bold text-palette-tan/45 min-w-0">
                  <Clock3 size={11} />
                  <span className="truncate">{t('right.pharmacy_midnight_guard')}</span>
               </div>
               {pharmacyUpdatedAt && (
                  <span className="text-[9px] font-black text-palette-tan/35 shrink-0">{pharmacyUpdatedAt}</span>
               )}
            </div>
         </div>

         {/* 2. Weather Widget */}
         <div className="bg-white rounded-[5px] border border-palette-beige/60 shadow-sm overflow-hidden relative group">
            <div className="p-6 pb-0 flex items-start justify-between">
               <div>
                  <div className="flex items-center gap-1.5 text-palette-tan/40 mb-2">
                     <MapPin size={12} />
                     <span className="text-[10px] font-bold uppercase tracking-[0.2em]">{weatherLocation}</span>
                  </div>
                  <div className="flex items-center gap-3">
                     <span className="text-4xl font-[900] text-gray-900 tracking-tighter">{currentTemperature ?? '--'}°</span>
                     <div className="flex flex-col min-w-0">
                        <span className="text-xs font-black text-palette-tan max-w-[130px] truncate">{weatherCondition}</span>
                        <span className="text-[10px] text-palette-tan/40 font-bold">{t('right.weather_feels_like_26').replace('26', String(apparentTemperature ?? '--'))}</span>
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
                     <span className="text-[9px] font-black text-palette-tan/30 uppercase">{day.day}</span>
                     <day.icon size={16} className="text-palette-tan/60" />
                     <span className="text-[11px] font-black text-gray-900">{day.temp}</span>
                  </div>
               ))}
            </div>
         </div>

         {/* 2. Gündem (Trending) */}
         <div className="bg-white rounded-[5px] border border-palette-beige/60 shadow-sm overflow-hidden">
            <div className="p-6 pb-2 flex items-center justify-between">
               <div className="flex items-center gap-3">
                  <div className="w-1.5 h-1.5 bg-palette-red rounded-[5px]"></div>
                  <h3 className="font-bold text-gray-900 uppercase tracking-[0.12em] text-[13px]">{t('right.agenda')}</h3>
               </div>
               <span className="text-[9px] font-black text-palette-red bg-palette-red/5 px-2 py-1 rounded-[5px] border border-palette-red/10 animate-pulse">{t('right.live')}</span>
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
                        <span className="text-2xl font-[900] text-palette-tan/10 group-hover:text-palette-tan/30 transition-colors leading-none italic">
                           {item.id}
                        </span>
                     </div>

                     <div className="flex-1 min-w-0">
                        <div className="flex items-center justify-between mb-1">
                           <span className="text-[8px] font-black text-palette-tan/40 uppercase tracking-[0.2em]">{item.category}</span>
                           <span className="text-[9px] font-bold text-palette-tan/30">{item.hits}</span>
                        </div>
                        <h4 className="text-sm font-extrabold text-gray-900 leading-snug group-hover:text-palette-red transition-colors line-clamp-2 tracking-tight">
                           {item.title}
                        </h4>
                     </div>

                     {item.rising && (
                        <div className="flex-shrink-0 w-8 h-8 rounded-[5px] bg-palette-beige/30 flex items-center justify-center opacity-0 group-hover:opacity-100 transition-all">
                           <TrendingUp size={14} className="text-emerald-500" />
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
               className="w-full py-4 text-[10px] font-black text-palette-tan/40 uppercase tracking-[0.2em] hover:bg-palette-beige/20 hover:text-gray-900 transition-all border-t border-palette-beige/40"
            >
               {t('right.explore_all_agenda')}
            </button>
         </div>

         {/* 3. Markets Widget */}
         <div className="bg-white rounded-[5px] border border-palette-beige/60 shadow-sm overflow-hidden">
            <div className="p-6 pb-2 flex items-center justify-between">
               <div className="flex items-center gap-3">
                  <div className="w-1.5 h-1.5 bg-palette-tan/20 rounded-[5px]"></div>
                  <h3 className="font-bold text-gray-900 uppercase tracking-[0.12em] text-[13px]">{t('right.markets')}</h3>
               </div>
               <button onClick={() => openHref('/kategori/ekonomi')} className="text-[10px] font-bold text-palette-tan/40 hover:text-palette-red uppercase tracking-widest transition-colors">{t('right.all')}</button>
            </div>
            <div className="p-3 space-y-1.5">
               {markets.map((m, i) => (
                  <div key={i} className="flex items-center justify-between p-4 rounded-[5px] hover:bg-palette-beige/10 transition-all border border-transparent hover:border-palette-beige/30 cursor-pointer group">
                     <div className="flex items-center gap-4">
                        <div className={`w-10 h-10 rounded-[5px] ${m.bg} ${m.color} flex items-center justify-center shadow-sm border border-black/5`}>
                           <m.icon size={18} />
                        </div>
                        <div className="flex flex-col">
                           <span className="text-[11px] font-black text-gray-900">{m.symbol}</span>
                           <span className="text-[9px] font-bold text-palette-tan/30 uppercase tracking-tighter">{m.name}</span>
                        </div>
                     </div>
                     <div className="flex flex-col items-end">
                        <span className="text-xs font-black text-palette-tan">{m.price}</span>
                        <span className={`text-[9px] font-black flex items-center gap-0.5 mt-0.5 ${m.isUp ? 'text-emerald-500' : 'text-palette-red'}`}>
                           {m.isUp ? <ArrowUpRight size={10} strokeWidth={3} /> : <ArrowDownRight size={10} strokeWidth={3} />}
                           {m.change}
                        </span>
                     </div>
                  </div>
               ))}
            </div>
         </div>

         {/* 4. Keşfet (Suggestions) */}
         <div>
            <div className="flex items-center justify-between px-3 mb-4">
               <div className="flex items-center gap-2">
                  <Zap size={16} className="text-palette-red" />
                  <h3 className="font-bold text-gray-900 uppercase tracking-[0.12em] text-[13px]">{t('right.discover')}</h3>
               </div>
               <button onClick={() => openHref(suggestions.find((item) => item.href)?.href || '')} className="text-[10px] font-bold text-palette-tan/40 hover:underline uppercase tracking-widest">{t('right.all')}</button>
            </div>

            <div className="space-y-4">
               {suggestions.map((source, i) => (
                  <div
                     key={i}
                     onClick={() => openHref(source.href)}
                     className="group bg-white rounded-[5px] border border-palette-beige/60 p-4 shadow-sm hover:shadow-xl hover:border-palette-tan/10 transition-all duration-150 cursor-pointer relative overflow-hidden"
                  >
                     <div className="absolute top-0 left-0 w-full h-16 bg-palette-beige/10">
                        <img src={source.bg} className="w-full h-full object-cover opacity-20 group-hover:opacity-40 transition-opacity duration-200" />
                        <div className="absolute inset-0 bg-gradient-to-t from-white via-white/40 to-transparent"></div>
                     </div>

                     <div className="relative flex items-center justify-between">
                        <div className="flex items-center gap-4">
                           <div className="w-14 h-14 rounded-[5px] bg-white p-1 shadow-2xl border border-palette-beige relative z-10 group-hover:scale-105 transition-transform duration-150">
                              <img src={`https://picsum.photos/seed/${source.img}/100`} alt={source.name} className="w-full h-full object-cover rounded-[5px]" />
                           </div>
                           <div className="mt-1">
                              <div className="flex items-center gap-1.5">
                                 <h5 className="text-sm font-black text-gray-900">{source.name}</h5>
                                 <CheckCircle2 size={12} className="text-palette-tan fill-palette-tan/5" />
                              </div>
                              <p className="text-[10px] text-palette-tan/40 font-bold uppercase tracking-widest">{source.handle}</p>
                           </div>
                        </div>
                        <button
                           onClick={(event) => handleSuggestionFollow(event, source.publisherId)}
                           className={`w-10 h-10 rounded-[5px] flex items-center justify-center transition-all shadow-lg active:scale-90 ${source.publisherId && followedPublishers[source.publisherId] ? 'bg-emerald-500 text-white shadow-emerald-500/20' : 'bg-palette-tan text-white hover:bg-gray-900 shadow-palette-tan/20'}`}
                        >
                           {source.publisherId && followedPublishers[source.publisherId] ? <CheckCircle2 size={16} strokeWidth={2.5} /> : <UserPlus size={16} strokeWidth={2.5} />}
                        </button>
                     </div>
                  </div>
               ))}
            </div>
         </div>

         {/* 5. Newsletter Box */}
         <div className="bg-gradient-to-br from-gray-900 to-palette-tan rounded-[5px] p-7 text-white shadow-2xl shadow-palette-tan/30 relative overflow-hidden group">
            <div className="absolute top-0 right-0 w-32 h-32 bg-white/10 rounded-[5px] blur-[50px] -translate-y-10 translate-x-10 group-hover:bg-white/20 transition-all duration-700"></div>
            <div className="relative z-10">
               <div className="w-10 h-10 bg-white/10 rounded-[5px] flex items-center justify-center mb-5 border border-white/10">
                  <Mail size={20} />
               </div>
               <h4 className="font-bold text-xl leading-tight mb-2 tracking-tighter">{t('right.newsletter_title')}</h4>
               <p className="text-[11px] text-white/60 mb-6 font-bold uppercase tracking-widest leading-relaxed">{t('right.newsletter_desc')}</p>
               <form onSubmit={handleNewsletterSubmit} className="flex flex-col gap-3">
                  <input
                     type="email"
                     value={newsletterEmail}
                     onChange={(event) => setNewsletterEmail(event.target.value)}
                     placeholder={t('common.email_address')}
                     className="w-full bg-white/10 border border-white/20 rounded-[5px] px-5 py-3.5 text-xs text-white placeholder:text-white/30 focus:outline-none focus:bg-white/20 focus:border-white/40 transition-all font-bold"
                  />
                  <button disabled={newsletterLoading} className="w-full bg-white text-gray-900 py-3.5 rounded-[5px] font-black text-[10px] uppercase tracking-[0.2em] hover:bg-palette-beige transition-all shadow-xl active:scale-95 disabled:opacity-60">
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

         {/* Discover Skeleton */}
         <div className="space-y-4">
            <Skeleton className="w-24 h-4 ml-3" />
            {[1, 2].map(i => (
               <div key={i} className="bg-white rounded-[5px] border border-palette-beige/60 p-4 space-y-3">
                  <div className="flex items-center gap-4">
                     <Skeleton variant="rectangular" className="w-14 h-14" />
                     <div className="space-y-2">
                        <Skeleton className="w-24 h-4" />
                        <Skeleton className="w-16 h-3" />
                     </div>
                  </div>
               </div>
            ))}
         </div>
      </div>
   );
};

export default RightSidebar;
