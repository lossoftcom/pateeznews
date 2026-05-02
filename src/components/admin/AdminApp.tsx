import React, { useCallback, useEffect, useRef, useState } from 'react';
import type { SiteSettings } from '@/types';
import { LanguageProvider } from '@/context/LanguageContext';
import { ToastProvider } from '@/context/ToastContext';
import AdminDashboard from '@/components/admin/AdminDashboard';
import { navigate } from 'astro:transitions/client';
import { isPostId, isUUID, slugify } from '@/utils/helpers';

interface AdminAppProps {
  initialLang: any;
  initialTranslations: Record<string, string>;
  siteSettings: SiteSettings | null;
}

type AdminRouteState = { tab: string; userId: string | null };

const DEFAULT_ADMIN_TAB = 'overview';

const ADMIN_TABS = new Set([
  'overview',
  'posts',
  'news_list',
  'edit_post',
  'stories',
  'comments',
  'users',
  'edit_user',
  'publishers',
  'edit_publisher',
  'navigation',
  'roles',
  'settings',
  'ai_settings',
  'duty_pharmacy_settings',
  'weather_settings',
  'death_notice_settings',
  'languages',
  'my_profile',
  'hikaye-editor',
]);

const ADMIN_TAB_SLUGS: Record<string, { default: string; tr?: string; en?: string }> = {
  overview: { default: '' },
  posts: { default: 'add-post', tr: 'haber-ekle', en: 'add-post' },
  news_list: { default: 'posts', tr: 'haberler', en: 'posts' },
  stories: { default: 'stories', tr: 'hikayeler', en: 'stories' },
  comments: { default: 'comments', tr: 'yorumlar', en: 'comments' },
  users: { default: 'users', tr: 'kullanicilar', en: 'users' },
  publishers: { default: 'publishers', tr: 'yayincilar', en: 'publishers' },
  navigation: { default: 'navigation', tr: 'menu-kategori', en: 'navigation' },
  roles: { default: 'roles-permissions', tr: 'roller-izinler', en: 'roles-permissions' },
  settings: { default: 'settings', tr: 'ayarlar', en: 'settings' },
  ai_settings: { default: 'ai-settings', tr: 'ai-ayarlari', en: 'ai-settings' },
  duty_pharmacy_settings: { default: 'duty-pharmacy-settings', tr: 'nobetci-eczane-ayarlari', en: 'duty-pharmacy-settings' },
  weather_settings: { default: 'weather-settings', tr: 'hava-durumu-ayarlari', en: 'weather-settings' },
  death_notice_settings: { default: 'death-notice-settings', tr: 'olum-ilanlari-ayari', en: 'death-notice-settings' },
  languages: { default: 'languages', tr: 'dil-ayarlari', en: 'languages' },
  my_profile: { default: 'profile', tr: 'profilim', en: 'profile' },
  // Internal/special tabs
  edit_post: { default: 'posts', tr: 'haberler', en: 'posts' },
  edit_user: { default: 'users', tr: 'kullanicilar', en: 'users' },
  edit_publisher: { default: 'publishers', tr: 'yayincilar', en: 'publishers' },
  'hikaye-editor': { default: 'story-editor', tr: 'hikaye-editor', en: 'story-editor' },
};

const ADMIN_SLUG_TO_TAB: Record<string, string> = (() => {
  const map: Record<string, string> = {};
  const add = (slug: string, tab: string) => {
    const normalized = slugify(slug);
    if (!normalized) return;
    if (!map[normalized]) map[normalized] = tab;
  };

  Object.entries(ADMIN_TAB_SLUGS).forEach(([tab, value]) => {
    add(tab, tab);
    add(tab.replace(/_/g, '-'), tab);
    Object.values(value).forEach((slug) => add(slug, tab));
  });

  // Common aliases
  add('dashboard', 'overview');
  add('genel-bakis', 'overview');
  add('overview', 'overview');

  return map;
})();

const normalizeLangCode = (code: string) => String(code || '').trim().toLowerCase().split(/[-_]/)[0] || '';

const getAdminRouteLangCode = (fallback: string) => {
  try {
    const saved = localStorage.getItem('pateez_lang');
    if (saved) return normalizeLangCode(saved);
  } catch {
    // ignore
  }

  try {
    const htmlLang = document.documentElement.lang;
    if (htmlLang) return normalizeLangCode(htmlLang);
  } catch {
    // ignore
  }

  return normalizeLangCode(fallback) || 'tr';
};

const getAdminTabSlug = (tab: string, langCode: string) => {
  const normalizedTab = String(tab || DEFAULT_ADMIN_TAB).trim() || DEFAULT_ADMIN_TAB;
  const record = ADMIN_TAB_SLUGS[normalizedTab];
  if (!record) return slugify(normalizedTab.replace(/_/g, '-')) || normalizedTab.replace(/_/g, '-');
  const normalizedLang = normalizeLangCode(langCode);
  return record[normalizedLang as keyof typeof record] || record.default || normalizedTab.replace(/_/g, '-');
};

const parseAdminPathname = (pathname: string): AdminRouteState => {
  const segments = String(pathname || '')
    .split('/')
    .map((segment) => segment.trim())
    .filter(Boolean);

  if (segments[0] !== 'admin') return { tab: DEFAULT_ADMIN_TAB, userId: null };
  if (!segments[1]) return { tab: DEFAULT_ADMIN_TAB, userId: null };

  const tabKey = slugify(decodeURIComponent(segments[1]));
  const baseTab = ADMIN_SLUG_TO_TAB[tabKey];
  const resolvedBase = baseTab && ADMIN_TABS.has(baseTab) ? baseTab : DEFAULT_ADMIN_TAB;

  const rawId = segments[2] ? decodeURIComponent(segments[2]) : null;

  if (resolvedBase === 'news_list' && rawId && isPostId(rawId)) return { tab: 'edit_post', userId: rawId };
  if (resolvedBase === 'publishers' && rawId && isUUID(rawId)) return { tab: 'edit_publisher', userId: rawId };
  if (resolvedBase === 'users' && rawId && isUUID(rawId)) return { tab: 'edit_user', userId: rawId };

  return { tab: resolvedBase, userId: null };
};

const readAdminRouteState = (): AdminRouteState => {
  try {
    const url = new URL(window.location.href);
    const legacyTabRaw = String(url.searchParams.get('tab') || '').trim();
    const legacyUserId = String(url.searchParams.get('id') || '').trim() || null;

    const pathState = parseAdminPathname(url.pathname);

    const legacyTab = legacyTabRaw ? (ADMIN_TABS.has(legacyTabRaw) ? legacyTabRaw : null) : null;
    const tab = legacyTab || pathState.tab || DEFAULT_ADMIN_TAB;

    // If the path encodes an "edit" state, prefer its ID; otherwise keep query id (used for search/filter).
    const userIdFromPath = pathState.tab !== tab ? null : pathState.userId;
    const userId = userIdFromPath || (legacyTab ? legacyUserId : legacyUserId);

    return { tab, userId };
  } catch {
    return { tab: DEFAULT_ADMIN_TAB, userId: null };
  }
};

const AdminApp: React.FC<AdminAppProps> = ({ initialLang, initialTranslations, siteSettings }) => {
  const [routeState, setRouteState] = useState<AdminRouteState>(() => readAdminRouteState());
  const didCanonicalizeUrl = useRef(false);

  const updateAdminUrl = useCallback(
    (tab: string, userId: string | null, mode: 'push' | 'replace' = 'push') => {
      const url = new URL(window.location.href);

      const normalizedTab = String(tab || DEFAULT_ADMIN_TAB).trim() || DEFAULT_ADMIN_TAB;
      const langForSlug = getAdminRouteLangCode(String(initialLang?.code || 'tr'));

      const isEditTab = normalizedTab === 'edit_post' || normalizedTab === 'edit_publisher' || normalizedTab === 'edit_user';

      if (normalizedTab === 'overview') {
        url.pathname = '/admin';
      } else if (normalizedTab === 'edit_post') {
        const baseSlug = getAdminTabSlug('news_list', langForSlug);
        url.pathname = userId ? `/admin/${baseSlug}/${encodeURIComponent(userId)}` : `/admin/${baseSlug}`;
      } else if (normalizedTab === 'edit_publisher') {
        const baseSlug = getAdminTabSlug('publishers', langForSlug);
        url.pathname = userId ? `/admin/${baseSlug}/${encodeURIComponent(userId)}` : `/admin/${baseSlug}`;
      } else if (normalizedTab === 'edit_user') {
        const baseSlug = getAdminTabSlug('users', langForSlug);
        url.pathname = userId ? `/admin/${baseSlug}/${encodeURIComponent(userId)}` : `/admin/${baseSlug}`;
      } else {
        const slug = getAdminTabSlug(normalizedTab, langForSlug);
        url.pathname = slug ? `/admin/${slug}` : '/admin';
      }

      // Drop legacy tab query param (path-based routing).
      url.searchParams.delete('tab');

      // Preserve `id` as a query param only for non-edit tabs (used for filters/search).
      if (userId && !isEditTab) url.searchParams.set('id', userId);
      else url.searchParams.delete('id');

      const next = `${url.pathname}${url.search}${url.hash}`;
      const current = `${window.location.pathname}${window.location.search}${window.location.hash}`;
      if (current !== next) window.history[mode === 'replace' ? 'replaceState' : 'pushState'](null, '', next);
    },
    [initialLang?.code]
  );

  useEffect(() => {
    const onPopState = () => {
      setRouteState(readAdminRouteState());
    };
    window.addEventListener('popstate', onPopState);
    return () => window.removeEventListener('popstate', onPopState);
  }, []);

  useEffect(() => {
    if (didCanonicalizeUrl.current) return;
    didCanonicalizeUrl.current = true;
    updateAdminUrl(routeState.tab, routeState.userId, 'replace');
  }, [routeState.tab, routeState.userId, updateAdminUrl]);

  return (
    <LanguageProvider initialLang={initialLang} initialTranslations={initialTranslations}>
      <ToastProvider>
        <AdminDashboard
          initialTab={routeState.tab}
          initialUserId={routeState.userId || undefined}
          onTabChange={(tab, userId) => {
            const normalizedUserId = userId ? String(userId) : null;
            setRouteState({ tab: tab || DEFAULT_ADMIN_TAB, userId: normalizedUserId });
            updateAdminUrl(tab || DEFAULT_ADMIN_TAB, normalizedUserId);
          }}
          onLanguageChange={() => {
            updateAdminUrl(routeState.tab, routeState.userId, 'replace');
          }}
          siteSettings={siteSettings}
          onLogout={() => {
            void navigate('/');
          }}
        />
      </ToastProvider>
    </LanguageProvider>
  );
};

export default AdminApp;
