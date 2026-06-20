
import React, { useState, useRef, useEffect } from 'react';
import { prefetch } from 'astro:prefetch';
import { useLanguage } from '@/context/LanguageContext';
import { type NavigationItem, type SiteSettings } from '@/types';
import { slugify } from '@/utils/helpers';
import { getPostHref } from '@/utils/postUrl';
import { navigateImmediately } from '@/utils/immediateNavigation';
import RemixIcon from './ui/RemixIcon';
import {
  SPECIAL_CONTENT_FILTERS,
  getSpecialContentConfig,
  getSpecialContentUrl,
  type SpecialContentConfig
} from '@/utils/specialContent';
import { searchSite } from '@/services/appActions';

interface NavbarProps {
  onHomeClick?: () => void;
  onProfileClick?: () => void;
  onProfileViewClick?: () => void;
  onEditProfileClick?: () => void;
  onLogout?: () => void;
  isLoggedIn?: boolean;
  navItems?: NavigationItem[];
  siteSettings?: SiteSettings | null;
  user?: any;
  authLoading?: boolean;
}

const APPLE_NAV_FONT = 'var(--site-font-primary, "PateezAppleText"), "SF Pro Text", -apple-system, BlinkMacSystemFont, "Helvetica Neue", Arial, sans-serif';
const DESKTOP_NAV_ITEM_BASE_CLASS = 'relative h-full flex items-center gap-1.5 px-0.5 text-[13px] font-medium tracking-[0.055em] whitespace-nowrap transition-all group focus:outline-none focus-visible:text-palette-red';
const MOBILE_NAV_ITEM_CLASS = 'w-full flex items-center gap-3 px-4 py-3 rounded-[5px] text-[13px] font-black tracking-widest text-gray-500 hover:bg-palette-beige/10 hover:text-palette-red';
const DESKTOP_NAV_ICON_SIZE = 17;
const MOBILE_NAV_ICON_SIZE = '19px';
const DESKTOP_NAV_ICON_BASE_CLASS = 'transition-all duration-100 group-hover:-translate-y-0.5 group-hover:opacity-95';
const NAV_ICON_THIN_STYLE: React.CSSProperties = { fontWeight: 300, lineHeight: 1 };
const SHOW_MOBILE_TOP_NAVIGATION = false;
const REMIX_ICON_BY_MATERIAL: Record<string, string> = {
  home: 'ri-home-5-line',
  bolt: 'ri-flashlight-line',
  search: 'ri-search-line',
  close: 'ri-close-line',
  public: 'ri-global-line',
  expand_more: 'ri-arrow-down-s-line',
  person: 'ri-user-3-line',
  edit: 'ri-edit-line',
  logout: 'ri-logout-box-r-line',
  menu: 'ri-menu-line',
  chevron_right: 'ri-arrow-right-s-line',
  poll: 'ri-survey-line',
  bar_chart: 'ri-bar-chart-box-line',
  quiz: 'ri-questionnaire-line',
  smart_display: 'ri-video-line',
  format_list_bulleted: 'ri-list-check-2',
  format_list_numbered: 'ri-file-list-3-line',
  restaurant: 'ri-restaurant-2-line',
  calendar_month: 'ri-calendar-event-line',
};

type MobileAppItem = {
  id: string;
  label: string;
  icon: string;
  accent: string;
  accentRgb: string;
  accentStart: string;
  accentEnd: string;
  specialValue?: string;
};

const MOBILE_APP_ITEMS: MobileAppItem[] = [
  {
    id: 'nobetci-eczane',
    label: 'Nöbetçi Eczane',
    icon: 'ri-capsule-fill',
    accent: '#E30613',
    accentRgb: '227, 6, 19',
    accentStart: '#E72E39',
    accentEnd: '#A3040E',
  },
  {
    id: 'etkinlik',
    label: 'Etkinlik',
    icon: 'ri-calendar-event-line',
    accent: '#6C5CE7',
    accentRgb: '108, 92, 231',
    accentStart: '#8476EB',
    accentEnd: '#4E42A6',
    specialValue: 'etkinlik',
  },
  {
    id: 'duyurular',
    label: 'Duyurular',
    icon: 'ri-notification-fill',
    accent: '#F39C12',
    accentRgb: '243, 156, 18',
    accentStart: '#F5AC38',
    accentEnd: '#AF700D',
  },
  {
    id: 'olum-ilanlari',
    label: 'Ölüm İlanları',
    icon: 'ri-leaf-line',
    accent: '#2C3E50',
    accentRgb: '44, 62, 80',
    accentStart: '#4E5D6C',
    accentEnd: '#202D3A',
  },
  {
    id: 'hava-durumu',
    label: 'Hava Durumu',
    icon: 'ri-sun-line',
    accent: '#2D9CDB',
    accentRgb: '45, 156, 219',
    accentStart: '#4FACE1',
    accentEnd: '#20709E',
  },
  {
    id: 'namaz-vakitleri',
    label: 'Namaz Vakitleri',
    icon: 'ri-moon-clear-fill',
    accent: '#12A18C',
    accentRgb: '18, 161, 140',
    accentStart: '#38B09E',
    accentEnd: '#0D7465',
  },
  {
    id: 'doviz-altin',
    label: 'Döviz & Altın',
    icon: 'ri-coins-fill',
    accent: '#1FA971',
    accentRgb: '31, 169, 113',
    accentStart: '#43B788',
    accentEnd: '#167A51',
  },
];

const MOBILE_APP_ROUTES: Record<string, string> = {
  'nobetci-eczane': '/nobetci-eczane',
  'duyurular': '/duyurular',
  'olum-ilanlari': '/olum-ilanlari',
  'hava-durumu': '/hava-durumu',
  'namaz-vakitleri': '/namaz-vakitleri',
  'doviz-altin': '/doviz-altin',
};

const remixIconFor = (icon?: string) => {
  const key = String(icon || '').trim().toLowerCase();
  if (!key) return 'ri-arrow-right-s-line';
  if (key.startsWith('ri-')) return key;
  return REMIX_ICON_BY_MATERIAL[key] || 'ri-arrow-right-s-line';
};

const DRAWER_MATERIAL_ICON_BY_KEY: Record<string, string> = {
  home: 'home',
  where_to_vote: 'location_on',
  location_on: 'location_on',
  forum: 'forum',
  auto_stories: 'auto_stories',
  poll: 'assignment',
  bar_chart: 'assignment',
  quiz: 'quiz',
  smart_display: 'play_circle',
  format_list_bulleted: 'format_list_bulleted',
  format_list_numbered: 'format_list_bulleted',
  restaurant: 'restaurant',
  calendar_month: 'calendar_month',
  account_balance: 'account_balance',
  spa: 'eco',
  trending_up: 'monitoring',
};

const isDrawerCategoryType = (type?: string) => {
  const normalized = String(type || '').trim().toLowerCase();
  return !normalized || normalized === 'category' || normalized === 'dropdown' || normalized === 'link';
};

const drawerMaterialIconFor = (item: NavigationItem) => {
  const rawIcon = String(item.icon || '').trim().toLowerCase();
  if (rawIcon && !rawIcon.startsWith('ri-')) return DRAWER_MATERIAL_ICON_BY_KEY[rawIcon] || rawIcon;

  const text = `${item.label || ''} ${item.value || ''}`.toLocaleLowerCase('tr-TR');
  if (item.type === 'district') return 'location_on';
  if (item.type === 'trends') return 'monitoring';
  if (text.includes('köşe')) return 'forum';
  if (text.includes('anket')) return 'assignment';
  if (text.includes('test')) return 'quiz';
  if (text.includes('video')) return 'play_circle';
  if (text.includes('içindekiler') || text.includes('icindekiler')) return 'format_list_bulleted';
  if (text.includes('tarif')) return 'restaurant';
  if (text.includes('etkinlik')) return 'calendar_month';
  if (text.includes('siyaset')) return 'account_balance';
  if (text.includes('yaşam') || text.includes('yasam')) return 'eco';
  return 'grid_view';
};

const getDefaultDrawerRootItem = (items: NavigationItem[]) => (
  items.find((item) => {
    const value = item.value || item.label || '';
    return slugify(value) === 'nigde' || slugify(item.label || '') === 'nigde';
  }) || items[0] || null
);

const desktopNavItemClass = (isActive: boolean) => (
  `${DESKTOP_NAV_ITEM_BASE_CLASS} ${isActive ? 'text-palette-red' : 'text-gray-600 hover:text-palette-red'}`
);

const desktopNavIconClass = (isActive: boolean) => (
  `${DESKTOP_NAV_ICON_BASE_CLASS} ${isActive ? 'opacity-95' : 'opacity-60'}`
);

const normalizePath = (path: string) => {
  const cleanPath = path.split('?')[0].replace(/\/+$/, '');
  return cleanPath || '/';
};

const readCurrentLocation = () => {
  if (typeof window === 'undefined') return { pathname: '', search: '' };
  return {
    pathname: window.location.pathname || '/',
    search: window.location.search || '',
  };
};

const profileFromUser = (user: any) => user?.profile || {};

const accountDisplayName = (user: any) => {
  const profile = profileFromUser(user);
  return String(
    profile.full_name ||
    profile.username ||
    user?.user_metadata?.full_name ||
    user?.email?.split('@')[0] ||
    'Pateez'
  ).trim();
};

const accountSubtitle = (user: any) => {
  const profile = profileFromUser(user);
  const username = String(profile.username || '').trim().replace(/^@+/, '');
  if (username) return `@${username}`;
  const email = String(profile.email || user?.email || '').trim().toLowerCase();
  return email || '@pateez';
};

const accountAvatarUrl = (user: any) => {
  const profile = profileFromUser(user);
  return String(profile.avatar_url || user?.user_metadata?.avatar_url || '').trim();
};

const accountInitials = (user: any) => {
  const name = accountDisplayName(user);
  const initials = name
    .split(/\s+/)
    .map((part) => part.trim()[0])
    .filter(Boolean)
    .slice(0, 2)
    .join('')
    .toLocaleUpperCase('tr-TR');
  return initials || 'P';
};

const Navbar: React.FC<NavbarProps> = ({
  onHomeClick,
  onProfileClick,
  onProfileViewClick,
  onEditProfileClick,
  onLogout,
  isLoggedIn,
  navItems = [],
  siteSettings,
  user,
  authLoading
}) => {
  const { currentLang, availableLanguages, setLanguage, t } = useLanguage();
  const [showLangMenu, setShowLangMenu] = useState(false);
  const [showUserMenu, setShowUserMenu] = useState(false);
  const [isSearchOpen, setIsSearchOpen] = useState(false);
  const [isMobileMenuOpen, setIsMobileMenuOpen] = useState(false);
  const [isMobileDrawerOpen, setIsMobileDrawerOpen] = useState(false);
  const [isMobileDrawerGroupOpen, setIsMobileDrawerGroupOpen] = useState(true);
  const [isMobileAppsOpen, setIsMobileAppsOpen] = useState(false);
  const [searchTerm, setSearchTerm] = useState('');
  const [searchLoading, setSearchLoading] = useState(false);
  const [searchResults, setSearchResults] = useState<{ posts: any[]; profiles: any[] }>({ posts: [], profiles: [] });
  const [currentLocation, setCurrentLocation] = useState({ pathname: '', search: '' });
  const langMenuRef = useRef<HTMLDivElement>(null);
  const userMenuRef = useRef<HTMLDivElement>(null);
  const mobileAccountMenuRef = useRef<HTMLDivElement>(null);

  const explicitTopNavItems = React.useMemo(
    () => navItems.filter((item) => item.menu_code === 'top_navbar'),
    [navItems]
  );
  const hasExplicitTopNav = explicitTopNavItems.length > 0;

  const headerItems = React.useMemo(() => {
    const sourceItems = hasExplicitTopNav ? explicitTopNavItems : navItems;
    return sourceItems.filter(item => {
      const isSpecial = !!getSpecialContentConfig(item.value, item.label);
      return hasExplicitTopNav ? !isSpecial : item.type === 'header' && !isSpecial;
    });
  }, [hasExplicitTopNav, explicitTopNavItems, navItems]);

  const specialHeaderItems = React.useMemo(() => {
    if (hasExplicitTopNav) {
      return explicitTopNavItems
        .map((item) => {
          const config = getSpecialContentConfig(item.value, item.label);
          if (!config) return null;
          return {
            id: item.id,
            label: item.label || config.label,
            value: item.value || config.value,
            icon: item.icon || config.icon,
            config,
          };
        })
        .filter((item): item is {
          id: string;
          label: string;
          value: string;
          icon: string;
          config: SpecialContentConfig;
        } => item !== null);
    }
    return SPECIAL_CONTENT_FILTERS.filter((config) => config.showInHeader !== false).map((config) => {
      const source = navItems.find((item) => getSpecialContentConfig(item.value, item.label)?.key === config.key);
      return {
        id: source?.id || `special-${config.key}`,
        label: config.label,
        value: config.value,
        icon: source?.icon || config.icon,
        config,
      };
    });
  }, [hasExplicitTopNav, explicitTopNavItems, navItems]);

  const mobileDrawerItems = React.useMemo(() => {
    const scoped = navItems.filter((item) => item.menu_code === 'sidebar_main');
    return (scoped.length > 0 ? scoped : navItems.filter((item) => item.menu_code !== 'top_navbar'))
      .slice()
      .sort((a, b) => (a.order_index || 0) - (b.order_index || 0));
  }, [navItems]);

  const mobileDrawerRootItems = React.useMemo(() => (
    mobileDrawerItems
      .filter((item) => !item.parent_id || item.parent_id === 'root')
      .sort((a, b) => (a.order_index || 0) - (b.order_index || 0))
  ), [mobileDrawerItems]);

  const mobileDrawerRoot = React.useMemo(
    () => getDefaultDrawerRootItem(mobileDrawerRootItems),
    [mobileDrawerRootItems]
  );

  const mobileDrawerChildren = React.useMemo(() => {
    if (!mobileDrawerRoot) return [];
    return mobileDrawerItems
      .filter((item) => item.parent_id === mobileDrawerRoot.id)
      .sort((a, b) => (a.order_index || 0) - (b.order_index || 0));
  }, [mobileDrawerItems, mobileDrawerRoot]);

  const mobileDrawerMenuItems = mobileDrawerChildren.filter((item) => isDrawerCategoryType(item.type));
  const mobileDrawerDistricts = mobileDrawerChildren.filter((item) => item.type === 'district');
  const mobileDrawerTrends = mobileDrawerChildren.filter((item) => item.type === 'trends');
  const mobileDrawerOtherItems = mobileDrawerChildren.filter((item) => (
    item.type !== 'district' && item.type !== 'trends' && !isDrawerCategoryType(item.type)
  ));

  const closeMobileOverlays = () => {
    setIsMobileDrawerOpen(false);
    setIsMobileAppsOpen(false);
    setShowUserMenu(false);
    if (typeof window !== 'undefined' && window.matchMedia('(max-width: 767px)').matches) {
      setIsSearchOpen(false);
    }
  };

  const goHome = () => {
    closeMobileOverlays();
    if (onHomeClick) return onHomeClick();
    void navigateImmediately('/');
  };

  const navigateHeaderItem = (item: NavigationItem) => {
    const raw = (item.value || item.label || '').trim();
    if (!raw) return;
    if (raw.startsWith('http://') || raw.startsWith('https://')) {
      window.location.href = raw;
      return;
    }
    if (raw.startsWith('/')) {
      void navigateImmediately(raw);
      return;
    }
    void navigateImmediately(`/kategori/${slugify(raw)}`);
  };

  const navigateSpecialContent = (config: SpecialContentConfig) => {
    const href = getSpecialContentUrl(config.value);
    closeMobileOverlays();
    void navigateImmediately(href);
  };

  const prefetchHeaderItem = (item: NavigationItem) => {
    const raw = (item.value || item.label || '').trim();
    if (!raw) return;
    if (raw.startsWith('http://') || raw.startsWith('https://')) return;
    if (raw.startsWith('/')) {
      prefetch(raw);
      return;
    }
    prefetch(`/kategori/${slugify(raw)}`);
  };

  const prefetchSpecialContent = (config: SpecialContentConfig) => {
    prefetch(getSpecialContentUrl(config.value));
  };

  useEffect(() => {
    const handleClickOutside = (event: MouseEvent) => {
      if (langMenuRef.current && !langMenuRef.current.contains(event.target as Node)) {
        setShowLangMenu(false);
      }
      if (userMenuRef.current && !userMenuRef.current.contains(event.target as Node)) {
        const isInMobileAccountMenu = mobileAccountMenuRef.current?.contains(event.target as Node);
        if (!isInMobileAccountMenu) setShowUserMenu(false);
      }
    };
    if (showLangMenu || showUserMenu) document.addEventListener('mousedown', handleClickOutside);
    return () => document.removeEventListener('mousedown', handleClickOutside);
  }, [showLangMenu, showUserMenu]);

  useEffect(() => {
    if (typeof window === 'undefined') return;
    const syncCurrentLocation = () => setCurrentLocation(readCurrentLocation());

    syncCurrentLocation();
    window.addEventListener('popstate', syncCurrentLocation);
    window.addEventListener('pateez:content-filter', syncCurrentLocation as EventListener);
    document.addEventListener('astro:page-load', syncCurrentLocation);

    return () => {
      window.removeEventListener('popstate', syncCurrentLocation);
      window.removeEventListener('pateez:content-filter', syncCurrentLocation as EventListener);
      document.removeEventListener('astro:page-load', syncCurrentLocation);
    };
  }, []);

  useEffect(() => {
    if (typeof document === 'undefined') return;
    document.body.classList.toggle('mobile-drawer-open', isMobileDrawerOpen);
    return () => document.body.classList.remove('mobile-drawer-open');
  }, [isMobileDrawerOpen]);

  useEffect(() => {
    if (typeof window === 'undefined' || typeof document === 'undefined') return;

    const getShiftTargets = () => ({
      header: document.querySelector<HTMLElement>('.public-site-header-bar'),
      main: document.querySelector<HTMLElement>('main'),
      bottomNav: document.querySelector<HTMLElement>('.mobile-shell-bottom-nav'),
    });
    const resetShift = () => {
      const { header, main, bottomNav } = getShiftTargets();
      [header, main].forEach((element) => {
        if (element) element.style.transform = '';
      });
      if (bottomNav) {
        bottomNav.style.transform = '';
      }
    };
    const syncShift = () => {
      resetShift();
      if (!isMobileDrawerOpen || !window.matchMedia('(max-width: 767px)').matches) return;

      const screenWidth = window.innerWidth;
      const drawerWidth = Math.min(276, Math.max(220, screenWidth * 0.68), screenWidth - 84);
      const shift = `${drawerWidth}px`;
      const { header, main, bottomNav } = getShiftTargets();

      [header, main].forEach((element) => {
        if (element) element.style.transform = `translate3d(${shift}, 0, 0)`;
      });
      if (bottomNav) {
        bottomNav.style.transform = `translate3d(${shift}, 0, 0)`;
      }
    };

    syncShift();
    window.addEventListener('resize', syncShift);
    document.addEventListener('astro:page-load', syncShift);

    return () => {
      window.removeEventListener('resize', syncShift);
      document.removeEventListener('astro:page-load', syncShift);
      resetShift();
    };
  }, [isMobileDrawerOpen]);

  useEffect(() => {
    if (!isSearchOpen || searchTerm.trim().length < 2) {
      setSearchResults({ posts: [], profiles: [] });
      return;
    }

    let isMounted = true;
    const timer = window.setTimeout(() => {
      setSearchLoading(true);
      searchSite(searchTerm.trim(), currentLang.code || 'tr')
        .then((result) => {
          if (isMounted) setSearchResults({ posts: result.posts || [], profiles: result.profiles || [] });
        })
        .catch(() => {
          if (isMounted) setSearchResults({ posts: [], profiles: [] });
        })
        .finally(() => {
          if (isMounted) setSearchLoading(false);
        });
    }, 220);

    return () => {
      isMounted = false;
      window.clearTimeout(timer);
    };
  }, [isSearchOpen, searchTerm, currentLang.code]);

  const openSearchResult = (href: string) => {
    setIsSearchOpen(false);
    setSearchTerm('');
    void navigateImmediately(href);
  };

  const handleSearchSubmit = (event: React.FormEvent) => {
    event.preventDefault();
    const firstPost = searchResults.posts[0];
    const firstProfile = searchResults.profiles[0];
    if (firstPost) {
      openSearchResult(getPostHref(firstPost, siteSettings));
      return;
    }
    if (firstProfile) {
      openSearchResult(`/profil/${encodeURIComponent(firstProfile.username || firstProfile.id)}`);
      return;
    }
    if (searchTerm.trim()) openSearchResult(`/kategori/${slugify(searchTerm.trim())}`);
  };

  const activeQueryCategory = new URLSearchParams(currentLocation.search).get('kategori');
  const activePath = currentLocation.pathname ? normalizePath(currentLocation.pathname) : '';
  const activeCategorySlug = activePath.startsWith('/kategori/')
    ? activePath.split('/').filter(Boolean)[1] || ''
    : '';

  const isSpecialActive = (config: SpecialContentConfig) => {
    const queryConfig = getSpecialContentConfig(activeQueryCategory);
    if (queryConfig?.key === config.key) return true;
    const pathConfig = getSpecialContentConfig(activeCategorySlug);
    return pathConfig?.key === config.key;
  };

  const isHeaderItemActive = (item: NavigationItem, config?: SpecialContentConfig | null) => {
    if (config) return isSpecialActive(config);

    const raw = (item.value || item.label || '').trim();
    if (!raw || raw.startsWith('http://') || raw.startsWith('https://')) return false;

    if (raw.startsWith('/')) {
      const targetPath = normalizePath(raw);
      if (targetPath === '/') return activePath === '/' && !activeQueryCategory;
      return activePath === targetPath || activePath.startsWith(`${targetPath}/`);
    }

    return activeCategorySlug === slugify(raw);
  };

  const videoConfig = getSpecialContentConfig('video');
  const isMobileOverlayActive = isMobileAppsOpen || isSearchOpen || showUserMenu;
  const isHomeActive = !isMobileOverlayActive && activePath === '/' && !activeQueryCategory;
  const isVideoActive = !isMobileOverlayActive && videoConfig ? isSpecialActive(videoConfig) : false;
  const isAccountRouteActive = activePath === '/profil' || activePath === '/profil-duzenle' || activePath.startsWith('/profil/');
  const isAccountActive = showUserMenu || (!isMobileOverlayActive && isAccountRouteActive);
  const accountName = accountDisplayName(user);
  const accountSubline = accountSubtitle(user);
  const accountAvatar = accountAvatarUrl(user);
  const accountLetters = accountInitials(user);

  const openMobileApps = () => {
    setIsMobileDrawerOpen(false);
    setIsSearchOpen(false);
    setShowUserMenu(false);
    setIsMobileAppsOpen((value) => !value);
  };

  const openMobileSearch = () => {
    setIsMobileDrawerOpen(false);
    setIsMobileAppsOpen(false);
    setShowUserMenu(false);
    setIsSearchOpen(true);
  };

  const openMobileAccount = () => {
    setIsMobileDrawerOpen(false);
    setIsMobileAppsOpen(false);
    setIsSearchOpen(false);
    if (authLoading) return;
    if (isLoggedIn) {
      setShowUserMenu((value) => !value);
      return;
    }
    setShowUserMenu(false);
    onProfileClick?.();
  };

  const openAdminPanel = () => {
    setShowUserMenu(false);
    void navigateImmediately('/admin');
  };

  const openProfileFromAccountMenu = () => {
    setShowUserMenu(false);
    onProfileViewClick?.();
  };

  const logoutFromAccountMenu = () => {
    setShowUserMenu(false);
    onLogout?.();
  };

  const handleMobileAppSelect = (item: MobileAppItem) => {
    const appRoute = MOBILE_APP_ROUTES[item.id];
    if (appRoute) {
      closeMobileOverlays();
      void navigateImmediately(appRoute);
      return;
    }
    if (item.specialValue) {
      const config = getSpecialContentConfig(item.specialValue);
      if (config) {
        navigateSpecialContent(config);
        return;
      }
    }
    setIsMobileAppsOpen(false);
  };

  const openMobileDrawer = () => {
    setIsMobileAppsOpen(false);
    setIsSearchOpen(false);
    setShowUserMenu(false);
    setIsMobileDrawerOpen((value) => !value);
  };

  const navigateMobileDrawerItem = (item: NavigationItem) => {
    const specialConfig = getSpecialContentConfig(item.value, item.label);
    setIsMobileDrawerOpen(false);
    if (specialConfig) {
      navigateSpecialContent(specialConfig);
      return;
    }
    navigateHeaderItem(item);
  };

  const renderDrawerIcon = (item: NavigationItem, selected = false) => (
    <span
      className="material-symbols-rounded mobile-shell-drawer-row-icon"
      style={{ fontVariationSettings: selected ? "'FILL' 1" : "'FILL' 0" }}
      aria-hidden="true"
    >
      {drawerMaterialIconFor(item)}
    </span>
  );

  const renderDrawerRow = (item: NavigationItem) => {
    const specialConfig = getSpecialContentConfig(item.value, item.label);
    const active = isHeaderItemActive(item, specialConfig);
    return (
      <button
        key={`mobile-drawer-${item.id}`}
        type="button"
        className={`mobile-shell-drawer-row mobile-shell-drawer-row-dense${active ? ' is-selected' : ''}`}
        onClick={() => navigateMobileDrawerItem(item)}
      >
        <span className="mobile-shell-drawer-active-mark" aria-hidden="true" />
        {renderDrawerIcon(item, active)}
        <span className="mobile-shell-drawer-row-label">{t(item.label)}</span>
      </button>
    );
  };

  return (
    <header className="public-site-header fixed top-0 left-0 w-full z-[250]">
      <div className="public-site-header-bar h-[72px] bg-white/80 backdrop-blur-2xl border-b border-palette-beige/20 shadow-sm relative z-[251]">
        <div className="max-w-[1280px] mx-auto h-full flex items-center px-4">
          <button
            type="button"
            onClick={openMobileDrawer}
            className="mobile-shell-top-button mobile-shell-menu-button lg:hidden"
            aria-label="Menü"
            aria-expanded={isMobileDrawerOpen}
          >
            <RemixIcon name="ri-menu-line" size={22} />
          </button>

          {/* LOGO */}
          <div
            onClick={goHome}
            onMouseEnter={() => prefetch('/')}
            className="public-site-brand flex items-center gap-3 cursor-pointer group select-none z-20 flex-shrink-0 lg:w-[260px] pl-5"
          >
            {siteSettings?.logo_url ? (
              <div className="h-[46px] transition-opacity duration-200 group-hover:opacity-95">
                <img
                  src={siteSettings.logo_url}
                  alt={siteSettings?.site_name || "Site Logo"}
                  className="h-full w-auto object-contain select-none"
                  loading="eager"
                  decoding="async"
                  fetchPriority="high"
                />
              </div>
            ) : (
              <div className="w-[42px] h-[42px] bg-palette-red rounded-[5px] flex items-center justify-center shadow-lg shadow-palette-red/10 group-hover:scale-105 transition-all duration-150">
                <RemixIcon name="ri-flashlight-fill" size={24} className="text-white" />
              </div>
            )}
            {!siteSettings?.logo_url && (
              <div className="flex flex-col justify-center">
                <h1 className="text-xl font-bold tracking-tight text-gray-900 leading-none font-display">
                  {siteSettings?.site_name ? (
                    <>
                      {siteSettings.site_name.split(' ')[0].toUpperCase()}
                      {siteSettings.site_name.split(' ').slice(1).length > 0 && (
                        <span className="text-palette-tan font-medium">
                          {siteSettings.site_name.split(' ').slice(1).join(' ').toUpperCase()}
                        </span>
                      )}
                    </>
                  ) : (
                    <>PATEEZ<span className="text-palette-tan font-medium">{t('brand.news')}</span></>
                  )}
                </h1>
              </div>
            )}
          </div>

          {/* NAV */}
          <nav
            className="hidden lg:flex items-center justify-start gap-7 h-full ml-8 pl-0 pr-4 flex-1 min-w-0 overflow-hidden"
            style={{ '--web-nav-label-weight': 500 } as React.CSSProperties}
          >
            {!hasExplicitTopNav && (
              <button
                onClick={goHome}
                onMouseEnter={() => prefetch('/')}
                className={desktopNavItemClass(activePath === '/' && !activeQueryCategory)}
                aria-current={activePath === '/' && !activeQueryCategory ? 'page' : undefined}
                style={{ fontFamily: APPLE_NAV_FONT }}
              >
                <RemixIcon name="ri-home-5-line" size={DESKTOP_NAV_ICON_SIZE} className={desktopNavIconClass(activePath === '/' && !activeQueryCategory)} style={NAV_ICON_THIN_STYLE} />
                <span>{t('nav.home')}</span>
              </button>
            )}

            {hasExplicitTopNav ? explicitTopNavItems.map((item) => {
              const config = getSpecialContentConfig(item.value, item.label);
              const icon = item.icon || config?.icon || '';
              const isActive = isHeaderItemActive(item, config);
              return (
                <button
                  key={item.id}
                  onClick={() => config ? navigateSpecialContent(config) : navigateHeaderItem(item)}
                  onMouseEnter={() => config ? prefetchSpecialContent(config) : prefetchHeaderItem(item)}
                  className={desktopNavItemClass(isActive)}
                  aria-current={isActive ? 'page' : undefined}
                  style={{ fontFamily: APPLE_NAV_FONT }}
                >
                  {icon && (
                    <RemixIcon name={remixIconFor(icon)} size={DESKTOP_NAV_ICON_SIZE} className={desktopNavIconClass(isActive)} style={NAV_ICON_THIN_STYLE} />
                  )}
                  <span>{t(item.label || config?.label || '')}</span>
                </button>
              );
            }) : (
              <>
                {specialHeaderItems.map((item) => {
                  const isActive = isSpecialActive(item.config);
                  return (
                    <button
                      key={item.id}
                      onClick={() => navigateSpecialContent(item.config)}
                      onMouseEnter={() => prefetchSpecialContent(item.config)}
                      className={desktopNavItemClass(isActive)}
                      aria-current={isActive ? 'page' : undefined}
                      style={{ fontFamily: APPLE_NAV_FONT }}
                    >
                      <RemixIcon name={remixIconFor(item.icon)} size={DESKTOP_NAV_ICON_SIZE} className={desktopNavIconClass(isActive)} style={NAV_ICON_THIN_STYLE} />
                      <span>{t(item.label)}</span>
                    </button>
                  );
                })}

                {headerItems.map((item) => {
                  const isActive = isHeaderItemActive(item);
                  return (
                    <button
                      key={item.id}
                      onClick={() => navigateHeaderItem(item)}
                      onMouseEnter={() => prefetchHeaderItem(item)}
                      className={desktopNavItemClass(isActive)}
                      aria-current={isActive ? 'page' : undefined}
                      style={{ fontFamily: APPLE_NAV_FONT }}
                    >
                      {item.icon && (
                        <RemixIcon name={remixIconFor(item.icon)} size={DESKTOP_NAV_ICON_SIZE} className={desktopNavIconClass(isActive)} style={NAV_ICON_THIN_STYLE} />
                      )}
                      <span>{t(item.label)}</span>
                    </button>
                  );
                })}
              </>
            )}
          </nav>

          <div className="public-site-header-actions flex items-center gap-1 ml-auto z-20">
            <button
              onClick={() => setIsSearchOpen(!isSearchOpen)}
              className={`w-10 h-10 flex items-center justify-center rounded-[5px] transition-colors duration-100 ${isSearchOpen
                ? 'bg-gray-900 text-white shadow-md'
                : 'text-palette-tan hover:bg-palette-beige/10'
                }`}
            >
              <RemixIcon name={isSearchOpen ? 'ri-close-line' : 'ri-search-line'} size={21} />
            </button>

            <div className="relative hidden" ref={langMenuRef} aria-hidden="true">
              <button onClick={() => setShowLangMenu(!showLangMenu)} className="h-10 flex items-center gap-0.5 px-2 rounded-[5px] text-palette-tan hover:bg-palette-beige/10 transition-colors font-bold text-[10px] uppercase">
                <RemixIcon name="ri-global-line" size={19} />
                <RemixIcon name="ri-arrow-down-s-line" size={15} className={`transition-transform duration-200 ${showLangMenu ? 'rotate-180' : ''}`} />
              </button>
              {showLangMenu && (
                <div className="absolute top-full right-0 mt-2 w-40 bg-white rounded-[5px] shadow-2xl border border-palette-beige/10 py-1 overflow-hidden animate-in">
                  {availableLanguages.map((lang) => (
                    <button key={lang.code} onClick={() => { setLanguage(lang.code); setShowLangMenu(false); }}
                      className={`w-full flex items-center gap-3 px-4 py-2.5 text-[11px] font-bold transition-all ${currentLang.code === lang.code ? 'bg-palette-beige/10 text-palette-red' : 'text-palette-tan hover:bg-palette-beige/5'}`}>
                      <span className="uppercase">{lang.code}</span>
                      <span className="opacity-60">{lang.name}</span>
                    </button>
                  ))}
                </div>
              )}
            </div>

            <div className="relative" ref={userMenuRef}>
              {authLoading ? (
                /* AUTH LOADING (STABILIZED) - No pulse, no jump */
                <div className="flex items-center justify-center w-11 h-11">
                  <div className="w-9 h-9 rounded-full bg-white border border-palette-beige/70 shadow-[0_6px_18px_rgba(24,37,64,0.07)]" />
                </div>
              ) : (
                <button
                  onClick={() => {
                    if (isLoggedIn) {
                      setShowUserMenu(!showUserMenu);
                    } else {
                      onProfileClick?.();
                    }
                  }}
                  className={`flex items-center justify-center rounded-full transition-all duration-200 group/profile active:scale-95 ${isLoggedIn
                    ? 'w-12 h-12'
                    : 'w-11 h-11'
                    } ${isLoggedIn
                    ? 'bg-palette-beige/5 border border-palette-beige/20 hover:border-palette-tan/30'
                    : 'hover:bg-palette-beige/10'
                    }`}
                >
                  <div className={`flex items-center justify-center transition-all duration-150 ${isLoggedIn
                    ? 'w-10 h-10 rounded-full bg-white p-[2px] border border-palette-beige/70 overflow-hidden shadow-[0_6px_18px_rgba(24,37,64,0.07)]'
                    : 'w-7 h-7'
                    }`}>
                    {isLoggedIn ? (
                      (() => {
                        // Source of Truth: (user as any).profile is passed from HomePage/ProfileApp
                        // We align with UserManagement.tsx logic which trusts the DB value
                        const profileAvatar = (user as any)?.profile?.avatar_url;
                        const metadataAvatar = user?.user_metadata?.avatar_url;
                        const rawUrl = profileAvatar || metadataAvatar;

                        if (!rawUrl) return (
                          <div className="w-full h-full flex items-center justify-center bg-palette-beige text-palette-tan/20">
                            <RemixIcon name="ri-user-3-line" size={18} />
                          </div>
                        );

                        const url = String(rawUrl).trim();
                        // 2026 Logic: UserManagement uses the URL directly.
                        // We only ensure it's absolute if logical, but trust the value mostly.
                        // If it starts with http, data, or /, use it.
                        // If it is a bare filename, we assume it's a relative path that needs / locally or external.
                        // However, UserManagement example works without prefixing, so we default to rawURL 
                        // unless we know for sure (e.g. legacy prefixes).

                        let finalUrl = url;
                        // ONLY handle the specific legacy case if we are sure, otherwise trust the input
                        if (!url.startsWith('http') && !url.startsWith('data:') && !url.startsWith('/')) {
                          // If it's a bare string, UserManagement renders it as is.
                          // We will try not to touch it, or maybe just ensure it is not empty.
                          finalUrl = url;
                        }

                        return (
                          <img
                            src={finalUrl}
                            className="w-full h-full rounded-full object-cover"
                            alt={t('navbar.profile_alt')}
                            onError={(e) => {
                              (e.target as HTMLImageElement).style.display = 'none';
                              (e.target as HTMLImageElement).parentElement!.classList.add('bg-palette-beige');
                              // Show icon fallback
                              const parent = (e.target as HTMLImageElement).parentElement;
                              if (parent) {
                                const icon = document.createElement('i');
                                icon.className = 'ri-user-3-line inline-flex items-center justify-center leading-none text-palette-tan/20';
                                icon.style.fontSize = '18px';
                                parent.appendChild(icon);
                              }
                            }}
                          />
                        );
                      })()
                    ) : (
                      <RemixIcon name="ri-user-3-line" size={23} className="text-palette-red" />
                    )}
                  </div>
                </button>
              )}
              {/* USER DROPDOWN MENU */}
              {isLoggedIn && showUserMenu && (
                <div className="absolute top-full right-0 mt-2 w-56 bg-white/95 backdrop-blur-xl rounded-[12px] shadow-[0_20px_50px_rgba(0,0,0,0.15)] border border-palette-beige/20 py-2.5 z-[300] animate-in fade-in slide-in-from-top-1 duration-75">
                  <div className="px-4 py-2 mb-2 border-b border-palette-beige/10">
                    <p className="text-[11px] font-black text-gray-900 truncate">
                      {user?.user_metadata?.full_name || user?.email?.split('@')[0]}
                    </p>
                    <p className="text-[9px] font-bold text-palette-tan/60 truncate tracking-tighter">
                      {String(user?.email || '').toLowerCase()}
                    </p>
                  </div>

                  <div className="px-1.5 space-y-0.5">
                    <button
                      type="button"
                      className="w-full flex items-center gap-3 px-3 py-2 rounded-[8px] text-gray-700 hover:bg-palette-beige/10 hover:text-palette-red transition-all group"
                    >
                      <RemixIcon name="ri-dashboard-line" size={20} className="opacity-60 group-hover:opacity-100" />
                      <span className="text-[12px] font-bold tracking-tight">{t('navbar.admin_panel')}</span>
                    </button>

                    {onProfileViewClick && (
                      <button
                        onClick={() => { onProfileViewClick(); setShowUserMenu(false); }}
                        className="w-full flex items-center gap-3 px-3 py-2 rounded-[8px] text-gray-700 hover:bg-palette-beige/10 hover:text-palette-red transition-all group"
                      >
                        <RemixIcon name="ri-user-3-line" size={20} className="opacity-60 group-hover:opacity-100" />
                        <span className="text-[12px] font-bold tracking-tight">{t('navbar.my_profile')}</span>
                      </button>
                    )}

                    {onEditProfileClick && (
                      <button
                        onClick={() => { onEditProfileClick(); setShowUserMenu(false); }}
                        className="w-full flex items-center gap-3 px-3 py-2 rounded-[8px] text-gray-700 hover:bg-palette-beige/10 hover:text-palette-red transition-all group"
                      >
                        <RemixIcon name="ri-edit-line" size={20} className="opacity-60 group-hover:opacity-100" />
                        <span className="text-[12px] font-bold tracking-tight">{t('navbar.edit_profile')}</span>
                      </button>
                    )}

                    <div className="h-px bg-palette-beige/10 my-1.5 mx-2"></div>

                    {onLogout && (
                      <button
                        onClick={() => { onLogout(); setShowUserMenu(false); }}
                        className="w-full flex items-center gap-3 px-3 py-2 rounded-[8px] text-palette-red hover:bg-palette-red/5 transition-all group"
                      >
                        <RemixIcon name="ri-logout-box-r-line" size={20} className="opacity-60 group-hover:opacity-100" />
                        <span className="text-[12px] font-[900] tracking-tight truncate">{t('common.logout')}</span>
                      </button>
                    )}
                  </div>
                </div>
              )}
            </div>

            {SHOW_MOBILE_TOP_NAVIGATION && (
              <button
                onClick={() => setIsMobileMenuOpen((value) => !value)}
                className="lg:hidden w-10 h-10 flex items-center justify-center rounded-[5px] bg-palette-beige/10 text-gray-900 ml-1"
              >
                <RemixIcon name={isMobileMenuOpen ? 'ri-close-line' : 'ri-menu-line'} size={22} />
              </button>
            )}
          </div>

          <button
            type="button"
            onClick={openMobileApps}
            className="mobile-shell-top-button mobile-shell-pharmacy-button lg:hidden"
            aria-label="Nöbetçi eczane"
            aria-expanded={isMobileAppsOpen}
          >
            <img
              src="/admin/assets/assets/images/nobetci_eczane.webp"
              alt=""
              className="mobile-shell-pharmacy-logo"
              loading="eager"
              decoding="async"
            />
          </button>
        </div>
      </div >

      {isMobileDrawerOpen && (
        <div className="mobile-shell-drawer-layer lg:hidden">
          <aside className="mobile-shell-side-drawer" role="dialog" aria-label="Menü">
            <div className="mobile-shell-drawer-header">
              <button type="button" className="mobile-shell-drawer-brand" onClick={goHome} aria-label="Ana sayfa">
                {siteSettings?.logo_url ? (
                  <img src={siteSettings.logo_url} alt={siteSettings?.site_name || 'Pateez'} loading="eager" decoding="async" />
                ) : (
                  <span>pateez</span>
                )}
              </button>
              <button
                type="button"
                className="mobile-shell-drawer-close"
                onClick={() => setIsMobileDrawerOpen(false)}
                aria-label="Menüyü kapat"
              >
                <span className="material-symbols-rounded" aria-hidden="true">close</span>
              </button>
            </div>

            <div className="mobile-shell-drawer-scroll">
              {mobileDrawerRoot && (
                <button
                  type="button"
                  className="mobile-shell-drawer-row is-selected"
                  onClick={() => setIsMobileDrawerGroupOpen((value) => !value)}
                >
                  <span className="mobile-shell-drawer-active-mark" aria-hidden="true" />
                  {renderDrawerIcon(mobileDrawerRoot, true)}
                  <span className="mobile-shell-drawer-row-label">{t(mobileDrawerRoot.label)}</span>
                  <span
                    className={`material-symbols-rounded mobile-shell-drawer-chevron${isMobileDrawerGroupOpen ? ' is-open' : ''}`}
                    aria-hidden="true"
                  >
                    keyboard_arrow_down
                  </span>
                </button>
              )}

              {isMobileDrawerGroupOpen && (
                <>
                  {mobileDrawerMenuItems.map(renderDrawerRow)}
                  {mobileDrawerDistricts.length > 0 && (
                    <>
                      <p className="mobile-shell-drawer-group-title">İlçeler</p>
                      {mobileDrawerDistricts.map(renderDrawerRow)}
                    </>
                  )}
                  {mobileDrawerTrends.length > 0 && (
                    <>
                      <p className="mobile-shell-drawer-group-title">Trendler</p>
                      {mobileDrawerTrends.map(renderDrawerRow)}
                    </>
                  )}
                  {mobileDrawerOtherItems.length > 0 && mobileDrawerOtherItems.map(renderDrawerRow)}
                </>
              )}
            </div>

            <div className="mobile-shell-drawer-footer">
              <button
                type="button"
                className="mobile-shell-drawer-about"
                onClick={() => {
                  setIsMobileDrawerOpen(false);
                  void navigateImmediately('/kurumsal/hakkimizda');
                }}
              >
                Hakkımızda
              </button>
              <button type="button" className="mobile-shell-drawer-mode" aria-label="Normal mod">
                <span className="material-symbols-rounded" aria-hidden="true">light_mode</span>
              </button>
            </div>
          </aside>
          <button
            type="button"
            className="mobile-shell-drawer-hit-area"
            onClick={() => setIsMobileDrawerOpen(false)}
            aria-label="Menüyü kapat"
          />
        </div>
      )}

      {SHOW_MOBILE_TOP_NAVIGATION && isMobileMenuOpen && (
        <div className="lg:hidden absolute top-[72px] left-0 w-full bg-white border-b border-palette-beige shadow-2xl z-[252] animate-in slide-in-from-top-2">
          <div className="max-w-[1280px] mx-auto px-4 py-3">
            <div className="grid gap-1">
              {!hasExplicitTopNav && (
                <button
                  onClick={() => { setIsMobileMenuOpen(false); goHome(); }}
                  className={MOBILE_NAV_ITEM_CLASS}
                  style={{ fontFamily: APPLE_NAV_FONT }}
                >
                  <RemixIcon name="ri-home-5-line" size={MOBILE_NAV_ICON_SIZE} />
                  {t('nav.home')}
                </button>
              )}
              {hasExplicitTopNav ? explicitTopNavItems.map((item) => {
                const config = getSpecialContentConfig(item.value, item.label);
                const icon = item.icon || config?.icon || 'chevron_right';
                return (
                  <button
                    key={item.id}
                    onClick={() => {
                      setIsMobileMenuOpen(false);
                      config ? navigateSpecialContent(config) : navigateHeaderItem(item);
                    }}
                    className={MOBILE_NAV_ITEM_CLASS}
                    style={{ fontFamily: APPLE_NAV_FONT }}
                  >
                    <RemixIcon name={remixIconFor(icon)} size={MOBILE_NAV_ICON_SIZE} />
                    {t(item.label || config?.label || '')}
                  </button>
                );
              }) : (
                <>
                  {specialHeaderItems.map((item) => (
                    <button
                      key={item.id}
                      onClick={() => { setIsMobileMenuOpen(false); navigateSpecialContent(item.config); }}
                      className={MOBILE_NAV_ITEM_CLASS}
                      style={{ fontFamily: APPLE_NAV_FONT }}
                    >
                      <RemixIcon name={remixIconFor(item.icon)} size={MOBILE_NAV_ICON_SIZE} />
                      {t(item.label)}
                    </button>
                  ))}
                  {headerItems.map((item) => (
                    <button
                      key={item.id}
                      onClick={() => { setIsMobileMenuOpen(false); navigateHeaderItem(item); }}
                      className={MOBILE_NAV_ITEM_CLASS}
                      style={{ fontFamily: APPLE_NAV_FONT }}
                    >
                      <RemixIcon name={remixIconFor(item.icon || 'chevron_right')} size={MOBILE_NAV_ICON_SIZE} />
                      {t(item.label)}
                    </button>
                  ))}
                </>
              )}
            </div>
          </div>
        </div>
      )}

      {isMobileAppsOpen && (
        <>
          <div
            className="mobile-shell-sheet-backdrop lg:hidden"
            onClick={() => setIsMobileAppsOpen(false)}
            aria-hidden="true"
          />
          <div className="mobile-shell-apps-sheet lg:hidden" role="dialog" aria-label="Uygulamalar">
            <div className="mobile-shell-sheet-handle" />
            <div className="mobile-shell-sheet-head">
              <span aria-hidden="true" />
              <p>Uygulamalar</p>
            </div>
            <div className="mobile-shell-app-grid">
              {MOBILE_APP_ITEMS.map((item) => (
                <button
                  key={`mobile-app-${item.id}`}
                  type="button"
                  onClick={() => handleMobileAppSelect(item)}
                  style={{
                    '--mobile-app-accent': item.accent,
                    '--mobile-app-accent-rgb': item.accentRgb,
                    '--mobile-app-accent-start': item.accentStart,
                    '--mobile-app-accent-end': item.accentEnd,
                  } as React.CSSProperties}
                >
                  <span className="mobile-shell-app-icon">
                    <RemixIcon name={item.icon} size={30} />
                  </span>
                  <strong>{item.label}</strong>
                </button>
              ))}
            </div>
          </div>
        </>
      )}

      {isLoggedIn && showUserMenu && (
        <>
          <button
            type="button"
            className="mobile-shell-account-hit-area lg:hidden"
            onClick={() => setShowUserMenu(false)}
            aria-label="Hesap menüsünü kapat"
          />
          <div
            className="mobile-shell-account-menu lg:hidden"
            ref={mobileAccountMenuRef}
            role="menu"
            aria-label="Hesap menüsü"
          >
            <div className="mobile-shell-account-head">
              <span className="mobile-shell-account-avatar">
                {accountAvatar ? (
                  <img src={accountAvatar} alt={accountName} loading="eager" decoding="async" />
                ) : (
                  accountLetters
                )}
              </span>
              <span className="mobile-shell-account-id">
                <strong>{accountName}</strong>
                <small>{accountSubline}</small>
              </span>
            </div>

            {isLoggedIn && (
              <button
                type="button"
                className="mobile-shell-account-action"
                onClick={openAdminPanel}
                role="menuitem"
              >
                <RemixIcon name="ri-external-link-line" size={18} />
                <span>Admin panel</span>
              </button>
            )}

            {onProfileViewClick && (
              <button
                type="button"
                className="mobile-shell-account-action"
                onClick={openProfileFromAccountMenu}
                role="menuitem"
              >
                <RemixIcon name="ri-user-3-fill" size={18} />
                <span>Profilim</span>
              </button>
            )}

            {onLogout && (
              <button
                type="button"
                className="mobile-shell-account-action is-danger"
                onClick={logoutFromAccountMenu}
                role="menuitem"
              >
                <RemixIcon name="ri-logout-box-r-line" size={18} />
                <span>Çıkış yap</span>
              </button>
            )}
          </div>
        </>
      )}

      <nav className="mobile-shell-bottom-nav lg:hidden" aria-label="Mobil ana gezinme">
        <button type="button" onClick={goHome} className={isHomeActive ? 'is-active' : undefined}>
          <RemixIcon name={isHomeActive ? 'ri-home-5-fill' : 'ri-home-5-line'} size={isHomeActive ? 22 : 21} />
          <span>Anasayfa</span>
        </button>
        <button
          type="button"
          onClick={() => videoConfig && navigateSpecialContent(videoConfig)}
          className={isVideoActive ? 'is-active' : undefined}
        >
          <RemixIcon name={isVideoActive ? 'ri-play-circle-fill' : 'ri-play-circle-line'} size={isVideoActive ? 22 : 21} />
          <span>Video</span>
        </button>
        <button type="button" onClick={openMobileApps} className={isMobileAppsOpen ? 'is-active' : undefined}>
          <RemixIcon name={isMobileAppsOpen ? 'ri-apps-fill' : 'ri-apps-line'} size={isMobileAppsOpen ? 22 : 21} />
          <span>Uygulamalar</span>
        </button>
        <button type="button" onClick={openMobileSearch} className={isSearchOpen ? 'is-active' : undefined}>
          <RemixIcon name={isSearchOpen ? 'ri-search-fill' : 'ri-search-line'} size={isSearchOpen ? 22 : 21} />
          <span>Arama</span>
        </button>
        <button type="button" onClick={openMobileAccount} className={isAccountActive ? 'is-active' : undefined}>
          {isLoggedIn ? (
            <span className="mobile-shell-bottom-avatar" aria-hidden="true">
              {accountAvatar ? (
                <img src={accountAvatar} alt="" loading="eager" decoding="async" />
              ) : (
                accountLetters
              )}
            </span>
          ) : (
            <RemixIcon name={isAccountActive ? 'ri-user-3-fill' : 'ri-user-3-line'} size={isAccountActive ? 22 : 21} />
          )}
          <span>Hesap</span>
        </button>
      </nav>

      {/* SEARCH BAR */}
      < div
        className={`public-search-panel absolute top-[72px] left-0 w-full bg-white border-b border-palette-beige shadow-2xl transition-all duration-75 ease-linear overflow-hidden z-[250] ${isSearchOpen ? 'max-h-[420px] opacity-100 py-3.5' : 'max-h-0 opacity-0 py-0'
          }`}
      >
        <div className="max-w-[1280px] mx-auto px-4">
          <form onSubmit={handleSearchSubmit} className="relative flex items-center">
            <div className="absolute left-4 flex items-center justify-center z-10">
              <RemixIcon name="ri-search-line" size={21} className="text-palette-tan/30" />
            </div>
            <input
              type="text"
              autoFocus={isSearchOpen}
              value={searchTerm}
              onChange={(event) => setSearchTerm(event.target.value)}
              placeholder={t('nav.search')}
              className="w-full h-11 bg-palette-beige/10 rounded-[5px] border border-palette-beige focus:border-palette-tan/30 text-sm font-bold text-gray-900 placeholder:text-palette-tan/20 outline-none pl-11 pr-11 transition-none"
            />
            <div className="absolute right-3.5 flex items-center gap-2 z-10">
              <button
                onClick={() => setIsSearchOpen(false)}
                className="p-1 text-palette-tan/30 hover:text-palette-red"
              >
                <RemixIcon name="ri-close-line" size={18} />
              </button>
            </div>
          </form>

          {(searchTerm.trim().length >= 2 || searchLoading) && (
            <div className="mt-3 bg-white rounded-[5px] border border-palette-beige/60 shadow-sm overflow-hidden">
              {searchLoading ? (
                <div className="px-4 py-5 text-[11px] font-black text-palette-tan/40 uppercase tracking-widest">
                  {t('comments.loading')}
                </div>
              ) : searchResults.posts.length === 0 && searchResults.profiles.length === 0 ? (
                <button
                  onClick={() => openSearchResult(`/kategori/${slugify(searchTerm.trim())}`)}
                  className="w-full px-4 py-5 text-left text-[12px] font-bold text-palette-tan hover:bg-palette-beige/10"
                >
                  {searchTerm.trim()}
                </button>
              ) : (
                <div className="divide-y divide-palette-beige/40">
                  {searchResults.posts.map((post) => (
                    <button
                      key={`post-${post.id}`}
                      onClick={() => openSearchResult(getPostHref(post, siteSettings))}
                      onMouseEnter={() => prefetch(getPostHref(post, siteSettings))}
                      className="w-full px-4 py-3 flex items-center gap-3 text-left hover:bg-palette-beige/10 transition-colors"
                    >
                      <div className="w-10 h-10 rounded-[5px] bg-palette-beige/20 overflow-hidden flex-shrink-0">
                        {post.thumbnail_url ? <img src={post.thumbnail_url} className="w-full h-full object-cover" alt={post.title} /> : null}
                      </div>
                      <div className="min-w-0">
                        <p className="news-title-font text-[12px] font-black text-gray-900 truncate">{post.title}</p>
                        <p className="text-[9px] font-bold text-palette-tan/40 uppercase tracking-widest truncate">{post.category}</p>
                      </div>
                    </button>
                  ))}
                  {searchResults.profiles.map((profile) => (
                    <button
                      key={`profile-${profile.id}`}
                      onClick={() => openSearchResult(`/profil/${encodeURIComponent(profile.username || profile.id)}`)}
                      className="w-full px-4 py-3 flex items-center gap-3 text-left hover:bg-palette-beige/10 transition-colors"
                    >
                      <div className="w-10 h-10 rounded-[5px] bg-palette-beige/20 overflow-hidden flex-shrink-0">
                        {profile.avatar_url ? <img src={profile.avatar_url} className="w-full h-full object-cover" alt={profile.full_name || profile.username} /> : null}
                      </div>
                      <div className="min-w-0">
                        <p className="text-[12px] font-black text-gray-900 truncate">{profile.full_name || profile.username}</p>
                        <p className="text-[9px] font-bold text-palette-tan/40 uppercase tracking-widest truncate">@{profile.username || profile.role}</p>
                      </div>
                    </button>
                  ))}
                </div>
              )}
            </div>
          )}
        </div>
      </div >

      {isSearchOpen && (
        <div
          onClick={() => setIsSearchOpen(false)}
          className="fixed inset-0 bg-gray-900/5 backdrop-blur-[1px] z-[249]"
        />
      )}
    </header >
  );
};

export default Navbar;
