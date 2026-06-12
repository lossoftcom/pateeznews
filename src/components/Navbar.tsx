
import React, { useState, useRef, useEffect } from 'react';
import { navigate } from 'astro:transitions/client';
import { prefetch } from 'astro:prefetch';
import { useLanguage } from '@/context/LanguageContext';
import { type NavigationItem, type SiteSettings } from '@/types';
import { slugify } from '@/utils/helpers';
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

const APPLE_NAV_FONT = '"PateezAppleText", "SF Pro Text", -apple-system, BlinkMacSystemFont, "Helvetica Neue", Arial, sans-serif';
const DESKTOP_NAV_ITEM_CLASS = 'relative h-full flex items-center gap-2.5 px-1 text-[13px] font-extrabold tracking-widest transition-all group text-gray-500 hover:text-palette-red';
const MOBILE_NAV_ITEM_CLASS = 'w-full flex items-center gap-3 px-4 py-3 rounded-[5px] text-[13px] font-black tracking-widest text-gray-500 hover:bg-palette-beige/10 hover:text-palette-red';
const DESKTOP_NAV_ICON_SIZE = '20px';
const MOBILE_NAV_ICON_SIZE = '19px';
const SHOW_MOBILE_TOP_NAVIGATION = false;

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
  const [searchTerm, setSearchTerm] = useState('');
  const [searchLoading, setSearchLoading] = useState(false);
  const [searchResults, setSearchResults] = useState<{ posts: any[]; profiles: any[] }>({ posts: [], profiles: [] });
  const langMenuRef = useRef<HTMLDivElement>(null);
  const userMenuRef = useRef<HTMLDivElement>(null);

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

  const goHome = () => {
    if (onHomeClick) return onHomeClick();
    void navigate('/');
  };

  const navigateHeaderItem = (item: NavigationItem) => {
    const raw = (item.value || item.label || '').trim();
    if (!raw) return;
    if (raw.startsWith('http://') || raw.startsWith('https://')) {
      window.location.href = raw;
      return;
    }
    if (raw.startsWith('/')) {
      void navigate(raw);
      return;
    }
    void navigate(`/kategori/${slugify(raw)}`);
  };

  const navigateSpecialContent = (config: SpecialContentConfig) => {
    const href = getSpecialContentUrl(config.value);
    if (typeof window !== 'undefined' && (window.location.pathname === '/' || window.location.pathname === '')) {
      window.history.pushState({}, '', href);
      window.dispatchEvent(new CustomEvent('pateez:content-filter', { detail: { category: config.value } }));
      return;
    }
    void navigate(href);
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
        setShowUserMenu(false);
      }
    };
    if (showLangMenu || showUserMenu) document.addEventListener('mousedown', handleClickOutside);
    return () => document.removeEventListener('mousedown', handleClickOutside);
  }, [showLangMenu, showUserMenu]);

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
    void navigate(href);
  };

  const handleSearchSubmit = (event: React.FormEvent) => {
    event.preventDefault();
    const firstPost = searchResults.posts[0];
    const firstProfile = searchResults.profiles[0];
    if (firstPost) {
      openSearchResult(`/haber/${encodeURIComponent(firstPost.slug || firstPost.id)}`);
      return;
    }
    if (firstProfile) {
      openSearchResult(`/profil/${encodeURIComponent(firstProfile.username || firstProfile.id)}`);
      return;
    }
    if (searchTerm.trim()) openSearchResult(`/kategori/${slugify(searchTerm.trim())}`);
  };

  return (
    <header className="fixed top-0 left-0 w-full z-[250]">
      <div className="h-[72px] bg-white/80 backdrop-blur-2xl border-b border-palette-beige/20 shadow-sm relative z-[251]">
        <div className="max-w-[1280px] mx-auto h-full flex items-center px-4">

          {/* LOGO */}
          <div
            onClick={goHome}
            onMouseEnter={() => prefetch('/')}
            className="flex items-center gap-3 cursor-pointer group select-none z-20 flex-shrink-0 lg:w-[260px] pl-5"
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
                <span className="material-symbols-rounded text-white" style={{ fontSize: '26px', fontVariationSettings: "'FILL' 1, 'wght' 600" }}>bolt</span>
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
          <nav className="hidden lg:flex items-center gap-8 h-full px-10 flex-1">
            {!hasExplicitTopNav && (
              <button
                onClick={goHome}
                onMouseEnter={() => prefetch('/')}
                className={DESKTOP_NAV_ITEM_CLASS}
                style={{ fontFamily: APPLE_NAV_FONT }}
              >
                <span className="material-symbols-rounded transition-all duration-150 scale-110"
                  style={{ fontSize: DESKTOP_NAV_ICON_SIZE, fontVariationSettings: "'FILL' 1, 'wght' 500" }}>
                  home
                </span>
                <span>{t('nav.home')}</span>
              </button>
            )}

            {hasExplicitTopNav ? explicitTopNavItems.map((item) => {
              const config = getSpecialContentConfig(item.value, item.label);
              const icon = item.icon || config?.icon || '';
              return (
                <button
                  key={item.id}
                  onClick={() => config ? navigateSpecialContent(config) : navigateHeaderItem(item)}
                  onMouseEnter={() => config ? prefetchSpecialContent(config) : prefetchHeaderItem(item)}
                  className={DESKTOP_NAV_ITEM_CLASS}
                  style={{ fontFamily: APPLE_NAV_FONT }}
                >
                  {icon && (
                    <span className="material-symbols-rounded transition-all duration-100 group-hover:-translate-y-0.5 opacity-60 group-hover:opacity-100"
                      style={{ fontSize: DESKTOP_NAV_ICON_SIZE, fontVariationSettings: "'FILL' 0, 'wght' 400" }}>
                      {icon.toLowerCase()}
                    </span>
                  )}
                  <span>{t(item.label || config?.label || '')}</span>
                </button>
              );
            }) : (
              <>
                {specialHeaderItems.map((item) => (
                  <button
                    key={item.id}
                    onClick={() => navigateSpecialContent(item.config)}
                    onMouseEnter={() => prefetchSpecialContent(item.config)}
                    className={DESKTOP_NAV_ITEM_CLASS}
                    style={{ fontFamily: APPLE_NAV_FONT }}
                  >
                    <span className="material-symbols-rounded transition-all duration-100 group-hover:-translate-y-0.5 opacity-60 group-hover:opacity-100"
                      style={{ fontSize: DESKTOP_NAV_ICON_SIZE, fontVariationSettings: "'FILL' 0, 'wght' 400" }}>
                      {item.icon.toLowerCase()}
                    </span>
                    <span>{t(item.label)}</span>
                  </button>
                ))}

                {headerItems.map((item) => (
                  <button
                    key={item.id}
                    onClick={() => navigateHeaderItem(item)}
                    onMouseEnter={() => prefetchHeaderItem(item)}
                    className={DESKTOP_NAV_ITEM_CLASS}
                    style={{ fontFamily: APPLE_NAV_FONT }}
                  >
                    {item.icon && (
                      <span className="material-symbols-rounded transition-all duration-100 group-hover:-translate-y-0.5 opacity-60 group-hover:opacity-100"
                        style={{ fontSize: DESKTOP_NAV_ICON_SIZE, fontVariationSettings: "'FILL' 0, 'wght' 400" }}>
                        {item.icon.toLowerCase()}
                      </span>
                    )}
                    <span>{t(item.label)}</span>
                  </button>
                ))}
              </>
            )}
          </nav>

          <div className="flex items-center gap-1 ml-auto z-20">
            <button
              onClick={() => setIsSearchOpen(!isSearchOpen)}
              className={`w-10 h-10 flex items-center justify-center rounded-[5px] transition-colors duration-100 ${isSearchOpen
                ? 'bg-gray-900 text-white shadow-md'
                : 'text-palette-tan hover:bg-palette-beige/10'
                }`}
            >
              <span className="material-symbols-rounded" style={{ fontSize: '22px', fontVariationSettings: isSearchOpen ? "'FILL' 1" : "'FILL' 0" }}>
                {isSearchOpen ? 'close' : 'search'}
              </span>
            </button>

            <div className="relative" ref={langMenuRef}>
              <button onClick={() => setShowLangMenu(!showLangMenu)} className="h-10 flex items-center gap-0.5 px-2 rounded-[5px] text-palette-tan hover:bg-palette-beige/10 transition-colors font-bold text-[10px] uppercase">
                <span className="material-symbols-rounded" style={{ fontSize: '20px' }}>public</span>
                <span className={`material-symbols-rounded transition-transform duration-200 ${showLangMenu ? 'rotate-180' : ''}`} style={{ fontSize: '16px' }}>expand_more</span>
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
                <div className="flex items-center justify-center w-10 h-10">
                  <div className="w-7 h-7 rounded-[5px] bg-palette-beige/20 border border-palette-beige/10" />
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
                  className={`flex items-center justify-center w-10 h-10 rounded-[5px] transition-all duration-200 group/profile active:scale-95 ${isLoggedIn
                    ? 'bg-palette-beige/5 border border-palette-beige/20 hover:border-palette-tan/30'
                    : 'hover:bg-palette-beige/10'
                    }`}
                >
                  <div className={`flex items-center justify-center transition-all duration-150 ${isLoggedIn
                    ? 'w-7 h-7 rounded-[5px] border border-palette-tan/20 overflow-hidden shadow-sm'
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
                            <span className="material-symbols-rounded" style={{ fontSize: '18px' }}>person</span>
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
                            className="w-full h-full object-cover"
                            alt={t('navbar.profile_alt')}
                            onError={(e) => {
                              (e.target as HTMLImageElement).style.display = 'none';
                              (e.target as HTMLImageElement).parentElement!.classList.add('bg-palette-beige');
                              // Show icon fallback
                              const parent = (e.target as HTMLImageElement).parentElement;
                              if (parent) {
                                const icon = document.createElement('span');
                                icon.className = 'material-symbols-rounded text-palette-tan/20';
                                icon.style.fontSize = '18px';
                                icon.innerText = 'person';
                                parent.appendChild(icon);
                              }
                            }}
                          />
                        );
                      })()
                    ) : (
                      <span className="material-symbols-rounded text-palette-red" style={{ fontSize: '24px', fontVariationSettings: "'FILL' 0, 'wght' 500" }}>person</span>
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
                    <p className="text-[9px] font-bold text-palette-tan/60 truncate uppercase tracking-tighter">
                      {user?.email}
                    </p>
                  </div>

                  <div className="px-1.5 space-y-0.5">
                    {onProfileViewClick && (
                      <button
                        onClick={() => { onProfileViewClick(); setShowUserMenu(false); }}
                        className="w-full flex items-center gap-3 px-3 py-2 rounded-[8px] text-gray-700 hover:bg-palette-beige/10 hover:text-palette-red transition-all group"
                      >
                        <span className="material-symbols-rounded text-[20px] opacity-60 group-hover:opacity-100" style={{ fontVariationSettings: "'FILL' 0" }}>person</span>
                        <span className="text-[12px] font-bold tracking-tight">{t('navbar.my_profile')}</span>
                      </button>
                    )}

                    {onEditProfileClick && (
                      <button
                        onClick={() => { onEditProfileClick(); setShowUserMenu(false); }}
                        className="w-full flex items-center gap-3 px-3 py-2 rounded-[8px] text-gray-700 hover:bg-palette-beige/10 hover:text-palette-red transition-all group"
                      >
                        <span className="material-symbols-rounded text-[20px] opacity-60 group-hover:opacity-100" style={{ fontVariationSettings: "'FILL' 0" }}>edit</span>
                        <span className="text-[12px] font-bold tracking-tight">{t('navbar.edit_profile')}</span>
                      </button>
                    )}

                    <div className="h-px bg-palette-beige/10 my-1.5 mx-2"></div>

                    {onLogout && (
                      <button
                        onClick={() => { onLogout(); setShowUserMenu(false); }}
                        className="w-full flex items-center gap-3 px-3 py-2 rounded-[8px] text-palette-red hover:bg-palette-red/5 transition-all group"
                      >
                        <span className="material-symbols-rounded text-[20px] opacity-60 group-hover:opacity-100" style={{ fontVariationSettings: "'FILL' 0" }}>logout</span>
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
                <span className="material-symbols-rounded" style={{ fontSize: '22px' }}>{isMobileMenuOpen ? 'close' : 'menu'}</span>
              </button>
            )}
          </div>
        </div>
      </div >

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
                  <span className="material-symbols-rounded" style={{ fontSize: MOBILE_NAV_ICON_SIZE }}>home</span>
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
                    <span className="material-symbols-rounded" style={{ fontSize: MOBILE_NAV_ICON_SIZE }}>{icon}</span>
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
                      <span className="material-symbols-rounded" style={{ fontSize: MOBILE_NAV_ICON_SIZE }}>{item.icon}</span>
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
                      <span className="material-symbols-rounded" style={{ fontSize: MOBILE_NAV_ICON_SIZE }}>{item.icon || 'chevron_right'}</span>
                      {t(item.label)}
                    </button>
                  ))}
                </>
              )}
            </div>
          </div>
        </div>
      )}

      {/* SEARCH BAR */}
      < div
        className={`absolute top-[72px] left-0 w-full bg-white border-b border-palette-beige shadow-2xl transition-all duration-75 ease-linear overflow-hidden z-[250] ${isSearchOpen ? 'max-h-[420px] opacity-100 py-3.5' : 'max-h-0 opacity-0 py-0'
          }`}
      >
        <div className="max-w-[1280px] mx-auto px-4">
          <form onSubmit={handleSearchSubmit} className="relative flex items-center">
            <div className="absolute left-4 flex items-center justify-center z-10">
              <span className="material-symbols-rounded text-palette-tan/30" style={{ fontSize: '22px' }}>
                search
              </span>
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
                <span className="material-symbols-rounded" style={{ fontSize: '18px' }}>close</span>
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
                      onClick={() => openSearchResult(`/haber/${encodeURIComponent(post.slug || post.id)}`)}
                      onMouseEnter={() => prefetch(`/haber/${encodeURIComponent(post.slug || post.id)}`)}
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
