import React, { useEffect, useMemo, useState } from 'react';
import { useLanguage } from '@/context/LanguageContext';
import { type NewsItem, type SiteSettings } from '@/types';
import Skeleton from '@/components/ui/Skeleton';
import { prefetch } from 'astro:prefetch';
import { subscribeNewsletter } from '@/services/appActions';
import { useToast } from '@/context/ToastContext';
import { getPostHref } from '@/utils/postUrl';
import { navigateImmediately } from '@/utils/immediateNavigation';
import { isOpinionColumn } from '@/utils/opinionColumns';
import { getProfileHref } from '@/utils/profileUrl';
import RemixIcon from './ui/RemixIcon';
import PublisherFollowButton from './PublisherFollowButton';
import AdSlot from './ads/AdSlot';
import type { PublicAdSettings } from '@/types';

interface RightSidebarProps {
   newsData?: NewsItem[];
   loading?: boolean;
   siteSettings?: SiteSettings | null;
   initialSidebarData?: any;
   adSettings?: PublicAdSettings | null;
   adSlotKey?: string;
}

type ForecastItem = { day: string; icon: string; temp: string };
type MarketItem = { symbol: string; name: string; price: string; change: string; isUp: boolean; icon: string; color: string; bg: string };
type TrendingItem = {
   id: string;
   title: string;
   hits: string;
   category: string;
   rising: boolean;
   href: string;
   image?: string;
   imageAlt?: string;
   imageSrcSet?: string;
   imageWidth?: number;
   imageHeight?: number;
};
type ColumnistItem = {
   id: string;
   title: string;
   summary: string;
   author: string;
   handle: string;
   avatar: string;
   initials: string;
   dateLabel: string;
   href: string;
   profileHref: string;
   publisherId: string;
   isFollowingPublisher: boolean;
};
type SidebarSocialItem = {
   key: string;
   label: string;
   href: string;
   icon: string;
   background: string;
   shadowColor: string;
};
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

const SIDEBAR_TIMEZONE = 'Europe/Istanbul';

const normalizeSidebarSocialUrl = (value: string | null | undefined) => {
   const raw = String(value || '').trim();
   if (!raw) return '';
   const candidate = raw.startsWith('//')
      ? `https:${raw}`
      : (/^https?:\/\//i.test(raw) ? raw : `https://${raw}`);

   try {
      const parsed = new URL(candidate);
      return parsed.protocol === 'http:' || parsed.protocol === 'https:' ? parsed.toString() : '';
   } catch {
      return '';
   }
};

const withSidebarImageVariant = (src: string | null | undefined, width: number, quality = 82) => {
   const raw = String(src || '').trim();
   if (!raw || width <= 0 || raw.startsWith('data:')) return raw;
   try {
      const placeholderOrigin = 'https://pateez.local';
      const parsed = new URL(raw, placeholderOrigin);
      const isLocal =
         parsed.pathname.startsWith('/api/storage/file/') ||
         parsed.pathname.startsWith('/local-upload/');
      if (!isLocal) return raw;
      parsed.searchParams.set('w', String(Math.min(Math.max(Math.round(width), 64), 512)));
      parsed.searchParams.set('q', String(Math.min(Math.max(Math.round(quality), 40), 95)));
      return raw.startsWith('http://') || raw.startsWith('https://')
         ? parsed.toString()
         : `${parsed.pathname}${parsed.search}${parsed.hash}`;
   } catch {
      return raw;
   }
};

const isLikelyImageUrl = (src: string | null | undefined) => {
   const raw = String(src || '').trim();
   if (!raw) return false;
   if (raw.startsWith('data:image/')) return true;
   if (raw.includes('/api/storage/file/') || raw.includes('/local-upload/')) return true;
   try {
      const pathname = new URL(raw, 'https://pateez.local').pathname.toLowerCase();
      return /\.(avif|webp|png|jpe?g|gif|svg)(?:$|\?)/.test(pathname);
   } catch {
      return /\.(avif|webp|png|jpe?g|gif|svg)(?:$|\?)/i.test(raw);
   }
};

const toReadableCase = (value: string, lang = 'tr') => {
   const text = String(value || '').trim();
   if (!text) return text;
   const locale = String(lang || '').toLowerCase().startsWith('tr') ? 'tr-TR' : 'en-US';
   const lower = text.toLocaleLowerCase(locale);
   if (text === lower) return text;
   const upper = text.toLocaleUpperCase(locale);
   if (text !== upper) return text;
   return lower.replace(/(^|[.!?]\s+)(\p{L})/gu, (match) => match.toLocaleUpperCase(locale));
};

const sidebarNewsTime = (item: NewsItem) => {
   const date = new Date(item.timestamp || '');
   return Number.isNaN(date.getTime()) ? 0 : date.getTime();
};

const initialsForAuthor = (name: string) => {
   const words = String(name || '')
      .trim()
      .split(/\s+/)
      .filter(Boolean);
   if (!words.length) return 'P';
   return words
      .slice(0, 2)
      .map((word) => word[0])
      .join('')
      .toLocaleUpperCase('tr-TR');
};

const getTrendingImage = (item: NewsItem) => {
   const optimized = item.optimizedCoverThumbnail || item.optimizedThumbnail;
   const candidates = [
      optimized?.src,
      item.coverThumbnail,
      item.thumbnail,
      item.mansetImageUrl,
      item.mediaList?.[0],
      item.mediaUrl,
   ];
   const image = candidates.find(isLikelyImageUrl) || '';
   return {
      image,
      imageSrcSet: optimized?.srcSet,
      imageWidth: optimized?.width,
      imageHeight: optimized?.height,
   };
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

const RightSidebar: React.FC<RightSidebarProps> = ({ newsData, loading, siteSettings, initialSidebarData, adSettings, adSlotKey = 'web_home_sidebar' }) => {
   const { t, currentLang } = useLanguage();
   const { showToast } = useToast();
   const [liveSidebar, setLiveSidebar] = useState<any>(initialSidebarData || null);
   const [livePharmacyData, setLivePharmacyData] = useState<any>(initialSidebarData?.dutyPharmacies || null);
   const [liveDeathData, setLiveDeathData] = useState<any>(initialSidebarData?.deathNotices || null);
   const [activePharmacyDistrict, setActivePharmacyDistrict] = useState('MERKEZ');
   const [newsletterEmail, setNewsletterEmail] = useState('');
   const [newsletterLoading, setNewsletterLoading] = useState(false);
   const hasSidebarData = Boolean(initialSidebarData || liveSidebar || livePharmacyData || liveDeathData);
   const hasInitialPharmacyData = Boolean(initialSidebarData?.dutyPharmacies);
   const hasInitialDeathData = Boolean(initialSidebarData?.deathNotices);

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

      if (!hasInitialPharmacyData) fetchPharmacies();
      const refreshTimer = window.setInterval(fetchPharmacies, 15 * 60 * 1000);

      return () => {
         isMounted = false;
         window.clearInterval(refreshTimer);
      };
   }, [hasInitialPharmacyData]);

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

      if (!hasInitialDeathData) fetchDeathNotices();
      const refreshTimer = window.setInterval(fetchDeathNotices, 30 * 60 * 1000);

      return () => {
         isMounted = false;
         window.clearInterval(refreshTimer);
      };
   }, [hasInitialDeathData]);

   const formatMetric = (value: number) => {
      return new Intl.NumberFormat(currentLang.code || 'tr', {
         notation: 'compact',
         maximumFractionDigits: 1
      }).format(Math.max(0, value || 0)).toUpperCase();
   };
   const popularPostLimit = Math.min(
      Math.max(Number(siteSettings?.content_popular_post_limit || 4), 1),
      12
   );
   const socialFollowLabel = String(currentLang.code || '').toLowerCase().startsWith('en') ? 'Follow' : 'Takip et';
   const socialLinks = useMemo<SidebarSocialItem[]>(() => {
      const candidates: Array<Omit<SidebarSocialItem, 'href'> & { url?: string }> = [
         {
            key: 'instagram',
            label: 'Instagram',
            url: siteSettings?.social_instagram_url,
            icon: 'ri-instagram-fill',
            background: 'linear-gradient(135deg, #833AB4 0%, #E1306C 48%, #F77737 100%)',
            shadowColor: 'rgba(225,48,108,0.28)',
         },
         {
            key: 'facebook',
            label: 'Facebook',
            url: siteSettings?.social_facebook_url,
            icon: 'ri-facebook-fill',
            background: 'linear-gradient(135deg, #1877F2 0%, #0B5FCC 100%)',
            shadowColor: 'rgba(24,119,242,0.24)',
         },
         {
            key: 'x',
            label: 'X',
            url: siteSettings?.social_x_url,
            icon: 'ri-twitter-x-fill',
            background: 'linear-gradient(135deg, #111827 0%, #030712 100%)',
            shadowColor: 'rgba(17,24,39,0.22)',
         },
         {
            key: 'youtube',
            label: 'YouTube',
            url: siteSettings?.social_youtube_url,
            icon: 'ri-youtube-fill',
            background: 'linear-gradient(135deg, #FF0033 0%, #C90000 100%)',
            shadowColor: 'rgba(255,0,51,0.24)',
         },
         {
            key: 'tiktok',
            label: 'TikTok',
            url: siteSettings?.social_tiktok_url,
            icon: 'ri-tiktok-fill',
            background: 'linear-gradient(135deg, #111827 0%, #000000 64%, #00F2EA 160%)',
            shadowColor: 'rgba(0,0,0,0.22)',
         },
         {
            key: 'whatsapp',
            label: 'WhatsApp',
            url: siteSettings?.social_whatsapp_url,
            icon: 'ri-whatsapp-fill',
            background: 'linear-gradient(135deg, #25D366 0%, #128C7E 100%)',
            shadowColor: 'rgba(37,211,102,0.24)',
         },
         {
            key: 'telegram',
            label: 'Telegram',
            url: siteSettings?.social_telegram_url,
            icon: 'ri-telegram-fill',
            background: 'linear-gradient(135deg, #2AABEE 0%, #229ED9 100%)',
            shadowColor: 'rgba(34,158,217,0.24)',
         },
         {
            key: 'linkedin',
            label: 'LinkedIn',
            url: siteSettings?.social_linkedin_url,
            icon: 'ri-linkedin-fill',
            background: 'linear-gradient(135deg, #0A66C2 0%, #004182 100%)',
            shadowColor: 'rgba(10,102,194,0.24)',
         },
         {
            key: 'pinterest',
            label: 'Pinterest',
            url: siteSettings?.social_pinterest_url,
            icon: 'ri-pinterest-fill',
            background: 'linear-gradient(135deg, #E60023 0%, #B6001C 100%)',
            shadowColor: 'rgba(230,0,35,0.24)',
         },
         {
            key: 'discord',
            label: 'Discord',
            url: siteSettings?.social_discord_url,
            icon: 'ri-discord-fill',
            background: 'linear-gradient(135deg, #5865F2 0%, #404EED 100%)',
            shadowColor: 'rgba(88,101,242,0.24)',
         },
      ];

      return candidates.reduce<SidebarSocialItem[]>((items, item) => {
         const href = normalizeSidebarSocialUrl(item.url);
         if (!href) return items;
         items.push({
            key: item.key,
            label: item.label,
            href,
            icon: item.icon,
            background: item.background,
            shadowColor: item.shadowColor,
         });
         return items;
      }, []);
   }, [
      siteSettings?.social_discord_url,
      siteSettings?.social_facebook_url,
      siteSettings?.social_instagram_url,
      siteSettings?.social_linkedin_url,
      siteSettings?.social_pinterest_url,
      siteSettings?.social_telegram_url,
      siteSettings?.social_tiktok_url,
      siteSettings?.social_whatsapp_url,
      siteSettings?.social_x_url,
      siteSettings?.social_youtube_url,
   ]);

   const opinionColumns = useMemo<ColumnistItem[]>(() => {
      return (newsData || [])
         .filter((item) => item?.title && isOpinionColumn(item))
         .sort((a, b) => sidebarNewsTime(b) - sidebarNewsTime(a))
         .slice(0, 3)
         .map((item) => {
            const author = String(item.author || item.source || 'Pateez').trim();
            const date = new Date(item.timestamp || '');
            const dateLabel = Number.isNaN(date.getTime())
               ? ''
               : new Intl.DateTimeFormat(currentLang.code || 'tr', {
                  day: '2-digit',
                  month: 'short',
                  timeZone: SIDEBAR_TIMEZONE,
               }).format(date);
            const handle = String(item.publisherHandle || '').trim();

            return {
               id: String(item.id || ''),
               title: String(item.title || ''),
               summary: String(item.summary || item.seoDescription || ''),
               author,
               handle,
               avatar: String(item.sourceAvatar || ''),
               initials: initialsForAuthor(author),
               dateLabel,
               href: getPostHref(item, siteSettings),
               profileHref: getProfileHref(handle),
               publisherId: String(item.publisherId || ''),
               isFollowingPublisher: item.isFollowingPublisher === true,
            };
         });
   }, [currentLang.code, newsData, siteSettings]);

   const fallbackTrending = useMemo<TrendingItem[]>(() => [
      { id: '01', title: t('right.trending.01.title'), hits: '128K', category: t('right.trending.01.category'), rising: true, href: '' },
      { id: '02', title: t('right.trending.02.title'), hits: '85K', category: t('right.trending.02.category'), rising: true, href: '' },
      { id: '03', title: t('right.trending.03.title'), hits: '64K', category: t('right.trending.03.category'), rising: false, href: '' },
      { id: '04', title: t('right.trending.04.title'), hits: '42K', category: t('right.trending.04.category'), rising: true, href: '' },
   ].slice(0, popularPostLimit), [t, popularPostLimit]);

   const trending = useMemo<TrendingItem[]>(() => {
      const source = (newsData || [])
         .filter((item) => item?.title)
         .filter((item) => !isOpinionColumn(item))
         .sort((a, b) => {
            const bScore = (b.views || 0) + (b.likes || 0) + ((b.comments || 0) * 2) + (b.shares || 0);
            const aScore = (a.views || 0) + (a.likes || 0) + ((a.comments || 0) * 2) + (a.shares || 0);
            return bScore - aScore;
         })
         .slice(0, popularPostLimit);

      if (!source.length) return fallbackTrending;

      return source.map((item, idx) => {
         const score = (item.views || 0) || (item.likes || 0) + (item.comments || 0) + (item.shares || 0);
         const image = getTrendingImage(item);
         return {
            id: String(idx + 1).padStart(2, '0'),
            title: item.title,
            hits: formatMetric(score),
            category: toReadableCase(item.category || t('right.agenda'), currentLang.code),
            rising: idx < 3,
            href: getPostHref(item, siteSettings),
            image: image.image,
            imageAlt: item.thumbnailAlt || item.seoTitle || item.title,
            imageSrcSet: image.imageSrcSet,
            imageWidth: image.imageWidth,
            imageHeight: image.imageHeight,
         };
      });
   }, [fallbackTrending, newsData, t, currentLang.code, popularPostLimit, siteSettings]);

   const fallbackMarkets: MarketItem[] = [
      { symbol: 'USDT', name: t('right.markets.usdt_try'), price: '34.42', change: '%0.45', isUp: true, icon: 'ri-money-dollar-circle-line', color: 'text-palette-red', bg: 'bg-palette-red/5' },
      { symbol: 'EUR', name: t('right.markets.eur_try'), price: '37.15', change: '%0.12', isUp: true, icon: 'ri-money-euro-circle-line', color: 'text-palette-tan', bg: 'bg-palette-beige/50' },
      { symbol: 'GA', name: t('right.markets.gold_gram'), price: '2.450', change: '%-0.23', isUp: false, icon: 'ri-copper-coin-line', color: 'text-palette-accent', bg: 'bg-palette-accent/10' },
      { symbol: 'BTC', name: t('right.markets.bitcoin'), price: '$64.200', change: '%1.85', isUp: true, icon: 'ri-btc-line', color: 'text-palette-maroon', bg: 'bg-palette-maroon/5' },
   ];

   const marketStyle: Record<string, any> = {
      USDT: { icon: 'ri-money-dollar-circle-line', color: 'text-palette-red', bg: 'bg-palette-red/5' },
      EUR: { icon: 'ri-money-euro-circle-line', color: 'text-palette-tan', bg: 'bg-palette-beige/50' },
      GA: { icon: 'ri-copper-coin-line', color: 'text-palette-accent', bg: 'bg-palette-accent/10' },
      BTC: { icon: 'ri-btc-line', color: 'text-palette-maroon', bg: 'bg-palette-maroon/5' },
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
      { day: t('days.mon_short'), icon: 'ri-sun-cloudy-line', temp: '--°' },
      { day: t('days.tue_short'), icon: 'ri-sun-line', temp: '--°' },
      { day: t('days.wed_short'), icon: 'ri-showers-line', temp: '--°' },
      { day: t('days.thu_short'), icon: 'ri-cloudy-line', temp: '--°' },
      { day: t('days.fri_short'), icon: 'ri-sun-line', temp: '--°' },
   ];

   const weatherIcon = (code?: number) => {
      const value = Number(code || 0);
      if ([0, 1].includes(value)) return 'ri-sun-line';
      if ([2, 3].includes(value)) return 'ri-sun-cloudy-line';
      if ([45, 48].includes(value)) return 'ri-mist-line';
      if ((value >= 71 && value <= 77) || [85, 86].includes(value)) return 'ri-snowy-line';
      if (value >= 51 && value <= 82) return 'ri-showers-line';
      if (value >= 95) return 'ri-thunderstorms-line';
      return 'ri-cloudy-line';
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
         day: new Intl.DateTimeFormat(currentLang.code || 'tr', { weekday: 'short', timeZone: SIDEBAR_TIMEZONE }).format(new Date(day.day)),
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
      ? new Intl.DateTimeFormat(currentLang.code || 'tr', { hour: '2-digit', minute: '2-digit', timeZone: SIDEBAR_TIMEZONE }).format(new Date(livePharmacyData.fetchedAt))
      : null;
   const deathNotices = Array.isArray(liveDeathData?.notices)
      ? liveDeathData.notices as DeathNotice[]
      : [];
   const visibleDeathNotices = deathNotices.slice(0, 3);
   const deathUpdatedAt = liveDeathData?.fetchedAt
      ? new Intl.DateTimeFormat(currentLang.code || 'tr', { hour: '2-digit', minute: '2-digit', timeZone: SIDEBAR_TIMEZONE }).format(new Date(liveDeathData.fetchedAt))
      : null;

   const openHref = (href?: string) => {
      if (!href) return;
      void navigateImmediately(href);
   };

   const openNestedHref = (event: React.MouseEvent, href?: string) => {
      event.preventDefault();
      event.stopPropagation();
      openHref(href);
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

   if (loading && !hasSidebarData) {
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
                           <h3 className="text-sm font-semibold text-gray-800 tracking-[0.02em] truncate">{t('right.pharmacy_title')}</h3>
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
                        <RemixIcon name="ri-medicine-bottle-line" size={22} className="text-palette-red/80 shrink-0" />
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
                           <RemixIcon name="ri-phone-line" size={13} />
                           {pharmacy.phone || t('right.pharmacy_call')}
                        </a>
                        <a
                           href={pharmacy.directionUrl || pharmacy.mapUrl}
                           target="_blank"
                           rel="noreferrer"
                           className="h-9 rounded-[5px] bg-palette-accent text-palette-maroon flex items-center justify-center gap-2 text-[11px] font-medium shadow-lg shadow-palette-accent/20 hover:bg-palette-maroon hover:text-palette-beige transition-colors"
                        >
                           <RemixIcon name="ri-navigation-line" size={13} />
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
                  <RemixIcon name="ri-time-line" size={11} />
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
                     <RemixIcon name="ri-map-pin-line" size={12} />
                     <span className="text-[10px] font-medium tracking-[0.02em]">{weatherLocation}</span>
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
                     <RemixIcon name={day.icon} size={16} className="text-palette-tan/60" />
                     <span className="text-sm font-medium text-gray-800">{day.temp}</span>
                  </div>
               ))}
            </div>
         </div>

         {/* 2. Sosyal Medya */}
         {socialLinks.length > 0 && (
            <div className={`order-first grid gap-2 ${socialLinks.length === 1 ? 'grid-cols-1' : 'grid-cols-2'}`}>
               {socialLinks.map((item) => (
                  <a
                     key={item.key}
                     href={item.href}
                     target="_blank"
                     rel="noopener noreferrer"
                     aria-label={`${item.label} ${socialFollowLabel}`}
                     className="group relative flex min-h-[44px] min-w-0 items-center gap-2 overflow-hidden rounded-[5px] px-3 py-2 text-left text-white shadow-[0_10px_24px_-18px_rgba(24,37,64,0.45)] transition-all duration-150 hover:-translate-y-0.5 hover:brightness-[1.03] focus:outline-none focus-visible:ring-2 focus-visible:ring-palette-red/25"
                     style={{
                        background: item.background,
                        boxShadow: `0 10px 24px -18px ${item.shadowColor}`,
                     }}
                  >
                     <span className="pointer-events-none absolute inset-0 bg-[linear-gradient(135deg,rgba(255,255,255,0.18)_0%,rgba(255,255,255,0.03)_42%,rgba(0,0,0,0.10)_100%)] opacity-90 transition-opacity group-hover:opacity-100"></span>
                     <span className="relative flex h-7 w-7 shrink-0 items-center justify-center rounded-[5px] bg-white/20 text-white shadow-[inset_0_1px_0_rgba(255,255,255,0.22)]">
                        <RemixIcon name={item.icon} size={16} />
                     </span>
                     <span className="relative min-w-0 flex-1">
                        <span className="block truncate text-[12px] font-semibold leading-tight tracking-normal text-white">
                           {item.label}
                        </span>
                        <span className="mt-0.5 block truncate text-[10px] font-medium leading-tight tracking-normal text-white/70">
                           {socialFollowLabel}
                        </span>
                     </span>
                  </a>
               ))}
            </div>
         )}

         {/* 2. Köşe Yazarları */}
         {opinionColumns.length > 0 && (
            <div className="order-first overflow-hidden rounded-[5px] bg-white shadow-[0_4px_16px_-4px_rgba(0,0,0,0.05)]">
               <div className="border-b border-palette-beige/30 bg-white px-5 pb-3 pt-5">
                  <div className="flex items-center justify-between gap-3">
                     <div className="flex items-center gap-3 min-w-0">
                        <div className="h-1.5 w-1.5 rounded-[5px] bg-palette-accent"></div>
                        <h3 className="text-[13px] font-semibold tracking-[0.02em] text-gray-800">
                           {t('right.columnists')}
                        </h3>
                     </div>
                     <button
                        type="button"
                        onClick={() => openHref('/kategori/kose-yazisi')}
                        className="shrink-0 text-[10px] font-medium tracking-normal text-palette-tan/55 transition-colors hover:text-palette-red"
                     >
                        {t('right.all')}
                     </button>
                  </div>
               </div>

               <div className="space-y-5 px-5 pb-5 pt-4">
                  {opinionColumns.map((item, idx) => (
                     <button
                        key={item.id || idx}
                        type="button"
                        onClick={() => openHref(item.href)}
                        onMouseEnter={() => item.href && prefetch(item.href)}
                        className="group w-full rounded-[5px] bg-white px-1 py-1 text-left transition-all duration-150 hover:-translate-y-0.5 hover:bg-white"
                     >
                        <h4 className="break-words text-[18px] font-[900] leading-[1.16] tracking-normal text-gray-950 transition-colors group-hover:text-palette-red" style={{ fontFamily: 'var(--site-font-title, var(--site-font-primary, inherit))' }}>
                           {item.title}
                        </h4>
                        {item.summary && (
                           <p className="mt-2 break-words text-[12.5px] font-medium leading-[1.55] text-gray-500">
                              {item.summary}
                           </p>
                        )}

                        <div className="mt-3 flex items-end justify-between gap-3">
                           <div
                              onClick={(event) => openNestedHref(event, item.profileHref)}
                              className="min-w-0 flex-1 cursor-pointer"
                           >
                              <div className="flex flex-wrap items-center gap-x-1.5 gap-y-1">
                                 <span className="break-words text-[11px] font-semibold leading-tight text-gray-700">
                                    {item.author}
                                 </span>
                                 <RemixIcon name="ri-verified-badge-fill" size={13} className="shrink-0 text-palette-red" />
                                 <PublisherFollowButton
                                    as="span"
                                    publisherId={item.publisherId}
                                    postId={item.id}
                                    initialFollowing={item.isFollowingPublisher}
                                 />
                              </div>
                              <div className="mt-1 flex flex-wrap items-center gap-x-2 gap-y-1 text-[10px] font-medium leading-tight text-palette-tan/60">
                                 {item.handle && <span className="break-words">@{item.handle}</span>}
                                 {item.dateLabel && (
                                    <>
                                       <span className="h-1 w-1 rounded-full bg-palette-tan/25"></span>
                                       <span>{item.dateLabel}</span>
                                    </>
                                 )}
                              </div>
                           </div>

                           <div
                              onClick={(event) => openNestedHref(event, item.profileHref)}
                              className="relative h-12 w-12 shrink-0 cursor-pointer overflow-hidden rounded-full border border-palette-beige/35 bg-white p-[2px]"
                           >
                              {item.avatar ? (
                                 <img
                                    src={item.avatar}
                                    alt={item.author}
                                    loading={idx === 0 ? 'eager' : 'lazy'}
                                    decoding="async"
                                    className="h-full w-full rounded-full object-cover"
                                 />
                              ) : (
                                 <span className="flex h-full w-full items-center justify-center rounded-full bg-palette-beige/40 text-[12px] font-black text-palette-tan">
                                    {item.initials}
                                 </span>
                              )}
                           </div>
                        </div>
                     </button>
                  ))}
               </div>

               <button
                  type="button"
                  onClick={() => openHref('/kategori/kose-yazisi')}
                  className="w-full border-t border-palette-beige/30 px-4 py-4 text-[11px] font-semibold tracking-normal text-palette-tan/55 transition-all hover:bg-palette-beige/20 hover:text-gray-800"
               >
                  {t('right.read_all_columnists')}
               </button>
            </div>
         )}

         <AdSlot settings={adSettings} slotKey={adSlotKey} className="order-first" />

         {/* 3. Gündem (Trending) */}
         <div className="order-first bg-[#FFFFFF] rounded-[5px] border border-gray-200 shadow-[0_4px_16px_-4px_rgba(0,0,0,0.05)] overflow-hidden">
            <div className="px-5 pt-5 pb-3 flex items-center justify-between border-b border-palette-beige/30 bg-white">
               <div className="flex items-center gap-3">
                  <div className="w-1.5 h-1.5 bg-palette-red rounded-[5px]"></div>
                  <h3 className="font-semibold text-gray-800 tracking-[0.02em] text-[13px]">{t('right.agenda')}</h3>
               </div>
               <span className="text-[10px] font-medium text-palette-red bg-palette-red/5 px-2 py-1 rounded-[5px] border border-palette-red/10 animate-pulse">{t('right.live')}</span>
            </div>

            <div className="flex flex-col p-3 divide-y divide-palette-beige/45">
               {trending.map((item, idx) => (
                  <div
                     key={idx}
                     onClick={() => openHref(item.href)}
                     onMouseEnter={() => item.href && prefetch(item.href)}
                     className="group relative flex items-center gap-3 px-3 py-4 hover:bg-palette-beige/15 transition-all duration-100 cursor-pointer"
                  >
                     {item.image && (
                        <div className="flex h-[84px] w-[84px] shrink-0 items-center justify-center overflow-hidden rounded-[4px] border border-palette-beige/40 bg-white">
                           <img
                              src={withSidebarImageVariant(item.image, 160)}
                              srcSet={item.imageSrcSet}
                              sizes="84px"
                              alt={item.imageAlt || item.title}
                              width={item.imageWidth || 168}
                              height={item.imageHeight || 140}
                              loading={idx < 3 ? 'eager' : 'lazy'}
                              decoding="async"
                              fetchPriority={idx === 0 ? 'high' : 'low'}
                              className="h-full w-full object-contain object-center"
                           />
                        </div>
                     )}

                     <div className="flex-1 min-w-0">
                        <div className="flex items-center justify-between mb-1">
                           <span className="text-[9px] font-medium text-palette-tan/50 tracking-[0.02em]">{item.category}</span>
                           <span className="text-[10px] font-medium text-palette-tan/40">{item.hits}</span>
                        </div>
                        <h4 className="text-[14px] font-semibold text-gray-800 leading-snug tracking-tight group-hover:text-palette-red transition-colors break-words" style={{ fontFamily: 'var(--site-font-title, var(--site-font-primary, inherit))' }}>
                           {item.title}
                        </h4>
                     </div>

                     <div className="flex w-7 shrink-0 justify-end">
                        <span className="text-2xl font-light text-palette-tan/20 group-hover:text-palette-tan/40 transition-colors leading-none italic">
                           {item.id}
                        </span>
                     </div>
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
                  <h3 className="font-semibold text-gray-800 tracking-[0.02em] text-[13px]">{t('right.markets')}</h3>
               </div>
               <button onClick={() => openHref('/kategori/ekonomi')} className="text-[10px] font-medium tracking-normal text-palette-tan/50 transition-colors hover:text-palette-red">{t('right.all')}</button>
            </div>
            <div className="p-3 space-y-1.5">
               {markets.map((m, i) => (
                  <div key={i} className="flex items-center justify-between p-4 rounded-[5px] hover:bg-palette-beige/10 transition-all border border-transparent hover:border-palette-beige/30 cursor-pointer group">
                     <div className="flex items-center gap-4">
                        <div className={`w-10 h-10 rounded-[5px] ${m.bg} ${m.color} flex items-center justify-center shadow-sm border border-black/5`}>
                           <RemixIcon name={m.icon} size={18} />
                        </div>
                        <div className="flex flex-col">
                           <span className="text-[13px] font-semibold text-gray-800">{m.symbol}</span>
                           <span className="text-[10px] font-medium text-palette-tan/40 uppercase tracking-tight">{m.name}</span>
                        </div>
                     </div>
                     <div className="flex flex-col items-end">
                        <span className="text-[13px] font-semibold text-gray-800">{m.price}</span>
                        <span className={`text-[10px] font-medium flex items-center gap-0.5 mt-0.5 ${m.isUp ? 'text-palette-red' : 'text-palette-accent'}`}>
                           <RemixIcon name={m.isUp ? 'ri-arrow-up-right-line' : 'ri-arrow-down-right-line'} size={10} />
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
                  <h3 className="font-bold text-white/90 tracking-[0.02em] text-[12px]">{t('right.death_title')}</h3>
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
                           <RemixIcon name="ri-candle-line" size={18} />
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
                  <RemixIcon name="ri-mail-line" size={20} />
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
