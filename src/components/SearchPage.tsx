import React, { useEffect, useMemo, useRef, useState } from 'react';
import type { SiteSettings } from '@/types';
import { searchSite } from '@/services/appActions';
import { getPostHref } from '@/utils/postUrl';
import { getRelativeTime } from '@/utils/helpers';
import { navigateImmediately, updateUrlImmediately } from '@/utils/immediateNavigation';
import { getSiteSearchHref } from '@/utils/searchNavigation';
import RemixIcon from './ui/RemixIcon';

type SearchPost = {
  id?: string | number;
  slug?: string;
  title?: string;
  summary?: string;
  category?: string;
  imageUrl?: string;
  thumbnail_url?: string;
  publishedAt?: string;
  published_at?: string;
};

type SearchProfile = {
  id?: string;
  username?: string;
  full_name?: string;
  avatar_url?: string;
  role?: string;
  expertise?: string;
};

type SearchResults = {
  posts: SearchPost[];
  profiles: SearchProfile[];
};

type SearchAppItem = {
  id: string;
  label: string;
  tagline: string;
  icon: string;
  route: string;
  accent: string;
};

interface SearchPageProps {
  initialQuery?: string;
  initialLang?: {
    code?: string;
  };
  siteSettings?: SiteSettings | null;
}

const SEARCH_APPS: SearchAppItem[] = [
  {
    id: 'nobetci-eczane',
    label: 'Nöbetçi Eczane',
    tagline: 'Adres, telefon ve yol tarifi',
    icon: 'ri-capsule-fill',
    route: '/nobetci-eczane',
    accent: '#E30613',
  },
  {
    id: 'duyurular',
    label: 'Duyurular',
    tagline: 'Kurum ilanları ve son duyurular',
    icon: 'ri-notification-3-fill',
    route: '/duyurular',
    accent: '#F39C12',
  },
  {
    id: 'hava-durumu',
    label: 'Hava Durumu',
    tagline: 'Niğde için anlık tahmin',
    icon: 'ri-sun-line',
    route: '/hava-durumu',
    accent: '#2D9CDB',
  },
  {
    id: 'namaz-vakitleri',
    label: 'Namaz Vakitleri',
    tagline: 'Güncel vakit ve sayaç',
    icon: 'ri-moon-clear-fill',
    route: '/namaz-vakitleri',
    accent: '#12A18C',
  },
  {
    id: 'doviz-altin',
    label: 'Döviz & Altın',
    tagline: 'Piyasa ekranı ve günlük değerler',
    icon: 'ri-coins-fill',
    route: '/doviz-altin',
    accent: '#1FA971',
  },
  {
    id: 'olum-ilanlari',
    label: 'Ölüm İlanları',
    tagline: 'Vefat ve taziye bilgileri',
    icon: 'ri-leaf-line',
    route: '/olum-ilanlari',
    accent: '#2C3E50',
  },
];

const EMPTY_RESULTS: SearchResults = { posts: [], profiles: [] };

const cleanText = (value: unknown) => String(value || '').replace(/\s+/g, ' ').trim();

const normalize = (value: unknown) => (
  cleanText(value)
    .toLocaleLowerCase('tr-TR')
    .normalize('NFD')
    .replace(/[\u0300-\u036f]/g, '')
);

const readQueryFromLocation = () => {
  if (typeof window === 'undefined') return '';
  return cleanText(new URLSearchParams(window.location.search).get('q'));
};

const profileLabel = (profile: SearchProfile) => (
  cleanText(profile.full_name) || cleanText(profile.username) || 'Pateez'
);

const profileHandle = (profile: SearchProfile) => {
  const username = cleanText(profile.username).replace(/^@+/, '');
  return username ? `@${username}` : cleanText(profile.role);
};

const postHref = (post: SearchPost, siteSettings?: SiteSettings | null) => (
  getPostHref({ id: cleanText(post.id), slug: cleanText(post.slug) }, siteSettings)
);

const postImage = (post: SearchPost) => cleanText(post.imageUrl || post.thumbnail_url);

const postTime = (post: SearchPost, lang: string) => (
  getRelativeTime(cleanText(post.publishedAt || post.published_at), lang)
);

const initials = (value: string) => {
  const letters = value
    .split(/\s+/)
    .map((part) => part[0])
    .filter(Boolean)
    .slice(0, 2)
    .join('')
    .toLocaleUpperCase('tr-TR');
  return letters || 'P';
};

const SearchPage: React.FC<SearchPageProps> = ({
  initialQuery = '',
  initialLang,
  siteSettings,
}) => {
  const languageCode = cleanText(initialLang?.code || 'tr') || 'tr';
  const inputRef = useRef<HTMLInputElement>(null);
  const [query, setQuery] = useState(() => cleanText(initialQuery) || readQueryFromLocation());
  const [activeQuery, setActiveQuery] = useState('');
  const [results, setResults] = useState<SearchResults>(EMPTY_RESULTS);
  const [loading, setLoading] = useState(false);
  const [searched, setSearched] = useState(false);
  const [error, setError] = useState('');

  const appResults = useMemo(() => {
    const normalizedQuery = normalize(query);
    if (!normalizedQuery) return SEARCH_APPS;
    return SEARCH_APPS.filter((item) => (
      normalize(item.label).includes(normalizedQuery) ||
      normalize(item.tagline).includes(normalizedQuery) ||
      normalize(item.id).includes(normalizedQuery)
    ));
  }, [query]);

  const cleanQuery = query.trim();
  const readyToSearch = cleanQuery.length >= 2;
  const visibleAppResults = cleanQuery.length === 0 || readyToSearch ? appResults : [];
  const hasResults = results.posts.length > 0 || results.profiles.length > 0 || visibleAppResults.length > 0;

  useEffect(() => {
    const nextQuery = cleanText(initialQuery) || readQueryFromLocation();
    setQuery(nextQuery);
  }, [initialQuery]);

  useEffect(() => {
    const input = inputRef.current;
    if (!input) return;
    const timer = window.setTimeout(() => input.focus(), 80);
    return () => window.clearTimeout(timer);
  }, []);

  useEffect(() => {
    if (!readyToSearch) {
      setResults(EMPTY_RESULTS);
      setLoading(false);
      setSearched(false);
      setActiveQuery(cleanQuery);
      setError('');
      return;
    }

    let alive = true;
    const timer = window.setTimeout(() => {
      setLoading(true);
      setSearched(true);
      setActiveQuery(cleanQuery);
      setError('');
      updateUrlImmediately(getSiteSearchHref(cleanQuery, languageCode), 'replace');

      searchSite(cleanQuery, languageCode, { limit: 20, profilesLimit: 10 })
        .then((result) => {
          if (!alive) return;
          setResults({
            posts: Array.isArray(result?.posts) ? result.posts : [],
            profiles: Array.isArray(result?.profiles) ? result.profiles : [],
          });
        })
        .catch(() => {
          if (!alive) return;
          setResults(EMPTY_RESULTS);
          setError('Arama sonuçları alınamadı.');
        })
        .finally(() => {
          if (alive) setLoading(false);
        });
    }, 260);

    return () => {
      alive = false;
      window.clearTimeout(timer);
    };
  }, [cleanQuery, languageCode, readyToSearch]);

  const submitSearch = (event: React.FormEvent) => {
    event.preventDefault();
    const nextQuery = query.trim();
    if (nextQuery.length < 2) {
      inputRef.current?.focus();
      return;
    }
    updateUrlImmediately(getSiteSearchHref(nextQuery, languageCode), 'replace');
    setActiveQuery(nextQuery);
    setSearched(true);
  };

  const clearSearch = () => {
    setQuery('');
    setResults(EMPTY_RESULTS);
    setSearched(false);
    setActiveQuery('');
    setError('');
    updateUrlImmediately(getSiteSearchHref('', languageCode), 'replace');
    inputRef.current?.focus();
  };

  const goBack = () => {
    if (typeof window !== 'undefined' && window.history.length > 1) {
      window.history.back();
      return;
    }
    void navigateImmediately('/');
  };

  const openPost = (post: SearchPost) => {
    void navigateImmediately(postHref(post, siteSettings));
  };

  const openProfile = (profile: SearchProfile) => {
    const target = cleanText(profile.username || profile.id);
    if (!target) return;
    void navigateImmediately(`/profil/${encodeURIComponent(target)}`);
  };

  const openApp = (item: SearchAppItem) => {
    void navigateImmediately(item.route);
  };

  const resultCount = results.posts.length + results.profiles.length + visibleAppResults.length;
  const showNoResult = readyToSearch && searched && !loading && !hasResults;
  const showIdle = cleanQuery.length === 0 && !loading;
  const showShortQuery = cleanQuery.length > 0 && cleanQuery.length < 2;

  const searchForm = (
    <form className="public-search-form" onSubmit={submitSearch}>
      <RemixIcon name="ri-search-line" size={22} className="public-search-form-icon" />
      <input
        ref={inputRef}
        value={query}
        onChange={(event) => setQuery(event.target.value)}
        type="search"
        inputMode="search"
        autoComplete="off"
        spellCheck={false}
        placeholder="Haber, video, yazar veya uygulama ara"
        aria-label="Haber, video, yazar veya uygulama ara"
      />
      {query && (
        <button type="button" className="public-search-clear" onClick={clearSearch} aria-label="Aramayı temizle">
          <RemixIcon name="ri-close-line" size={19} />
        </button>
      )}
    </form>
  );

  return (
    <main className="public-search-page" aria-label="Arama">
      <section className="public-search-desktop-shell">
        <div className="public-search-hero">
          <div className="public-search-hero-copy">
            <span className="public-search-kicker">Pateez arama</span>
            <h1>Haber, yazar, video ve araçları tek yerden bul.</h1>
            <p>Yayınlanmış içerikler gerçek arama indeksleriyle taranır; sonuçlar yazarken güncellenir.</p>
          </div>
          <div className="public-search-hero-box">
            {searchForm}
            <div className="public-search-status-row">
              <span>{readyToSearch ? `"${activeQuery || cleanQuery}"` : 'En az iki karakter yaz'}</span>
              <strong>{loading ? 'Aranıyor' : `${resultCount} sonuç`}</strong>
            </div>
          </div>
        </div>

        <SearchResultSections
          appResults={visibleAppResults}
          error={error}
          idle={showIdle}
          languageCode={languageCode}
          loading={loading}
          onAppOpen={openApp}
          onPostOpen={openPost}
          onProfileOpen={openProfile}
          results={results}
          shortQuery={showShortQuery}
          showNoResult={showNoResult}
          siteSettings={siteSettings}
        />
      </section>

      <section className="public-search-mobile-shell">
        <header className="public-search-mobile-header">
          {searchForm}
          <button type="button" className="public-search-mobile-back" onClick={goBack} aria-label="Geri">
            <RemixIcon name="ri-arrow-left-line" size={21} />
          </button>
        </header>
        <SearchResultSections
          appResults={visibleAppResults}
          error={error}
          idle={showIdle}
          languageCode={languageCode}
          loading={loading}
          mobile
          onAppOpen={openApp}
          onPostOpen={openPost}
          onProfileOpen={openProfile}
          results={results}
          shortQuery={showShortQuery}
          showNoResult={showNoResult}
          siteSettings={siteSettings}
        />
      </section>

      <style>{`
        .public-search-page {
          min-height: calc(100vh - var(--public-nav-height, 72px));
          padding: calc(var(--public-nav-height, 72px) + 34px) 18px 70px;
          background: #F8F9FA;
          color: #20303A;
        }

        .public-search-desktop-shell {
          width: min(1160px, 100%);
          margin: 0 auto;
        }

        .public-search-mobile-shell {
          display: none;
        }

        .public-search-hero {
          display: grid;
          grid-template-columns: minmax(0, 0.86fr) minmax(380px, 1fr);
          gap: 24px;
          align-items: stretch;
          margin-bottom: 24px;
        }

        .public-search-hero-copy,
        .public-search-hero-box,
        .public-search-section,
        .public-search-empty-state,
        .public-search-error {
          border: 1px solid #E6ECEE;
          border-radius: 6px;
          background: #FFFFFF;
          box-shadow: 0 18px 40px rgba(20, 31, 45, 0.07);
        }

        .public-search-hero-copy {
          padding: 28px;
        }

        .public-search-kicker {
          display: inline-flex;
          align-items: center;
          height: 28px;
          padding: 0 10px;
          border-radius: 5px;
          background: rgba(227, 6, 19, 0.08);
          color: #E30613;
          font-size: 11px;
          font-weight: 900;
          letter-spacing: 0;
        }

        .public-search-hero h1 {
          margin: 16px 0 10px;
          max-width: 620px;
          color: #1F2933;
          font-family: var(--site-font-title, var(--site-font-primary, sans-serif));
          font-size: 38px;
          line-height: 1.04;
          letter-spacing: 0;
        }

        .public-search-hero p {
          max-width: 560px;
          margin: 0;
          color: #66737D;
          font-size: 15px;
          line-height: 1.55;
        }

        .public-search-hero-box {
          display: flex;
          min-width: 0;
          flex-direction: column;
          justify-content: center;
          gap: 14px;
          padding: 24px;
        }

        .public-search-form {
          position: relative;
          display: flex;
          align-items: center;
          min-width: 0;
          height: 50px;
          border: 1px solid #E2E8EB;
          border-radius: 6px;
          background: #F3F5F6;
        }

        .public-search-form-icon {
          flex: 0 0 auto;
          margin-left: 15px;
          color: #E30613;
        }

        .public-search-form input {
          min-width: 0;
          flex: 1 1 auto;
          height: 100%;
          border: 0;
          outline: 0;
          background: transparent;
          padding: 0 44px 0 11px;
          color: #1F2933;
          font: inherit;
          font-size: 15px;
          font-weight: 750;
        }

        .public-search-form input::placeholder {
          color: #9AA5AD;
          font-weight: 600;
        }

        .public-search-clear {
          position: absolute;
          right: 8px;
          top: 50%;
          display: grid;
          width: 34px;
          height: 34px;
          place-items: center;
          transform: translateY(-50%);
          border: 0;
          border-radius: 999px;
          background: transparent;
          color: #5E6B75;
          cursor: pointer;
        }

        .public-search-clear:hover {
          background: rgba(227, 6, 19, 0.08);
          color: #E30613;
        }

        .public-search-status-row {
          display: flex;
          align-items: center;
          justify-content: space-between;
          gap: 14px;
          color: #7D8A93;
          font-size: 12px;
          font-weight: 750;
        }

        .public-search-status-row strong {
          color: #E30613;
        }

        .public-search-results {
          display: grid;
          gap: 18px;
        }

        .public-search-section {
          overflow: hidden;
        }

        .public-search-section-head {
          display: flex;
          align-items: center;
          justify-content: space-between;
          gap: 14px;
          padding: 16px 18px;
          border-bottom: 1px solid #EAF0F2;
        }

        .public-search-section-head h2 {
          margin: 0;
          color: #24323B;
          font-size: 16px;
          font-weight: 900;
          letter-spacing: 0;
        }

        .public-search-section-head span {
          color: #9AA5AD;
          font-size: 12px;
          font-weight: 800;
        }

        .public-search-post-list,
        .public-search-profile-list {
          display: grid;
          gap: 0;
        }

        .public-search-post-card,
        .public-search-profile-card {
          display: flex;
          width: 100%;
          min-width: 0;
          align-items: center;
          gap: 14px;
          border: 0;
          border-bottom: 1px solid #EEF2F4;
          background: #FFFFFF;
          padding: 13px 16px;
          text-align: left;
          cursor: pointer;
        }

        .public-search-post-card:last-child,
        .public-search-profile-card:last-child {
          border-bottom: 0;
        }

        .public-search-post-card:hover,
        .public-search-profile-card:hover {
          background: #FAFBFB;
        }

        .public-search-post-media {
          display: grid;
          width: 86px;
          height: 72px;
          flex: 0 0 auto;
          place-items: center;
          overflow: hidden;
          border-radius: 6px;
          background: #EEF2F4;
          color: #A2ADB5;
        }

        .public-search-post-media img {
          width: 100%;
          height: 100%;
          object-fit: cover;
        }

        .public-search-post-copy,
        .public-search-profile-copy {
          min-width: 0;
          flex: 1 1 auto;
        }

        .public-search-post-meta {
          display: flex;
          min-width: 0;
          align-items: center;
          gap: 8px;
          color: #E30613;
          font-size: 10.5px;
          font-weight: 900;
        }

        .public-search-post-meta span {
          min-width: 0;
          overflow: hidden;
          text-overflow: ellipsis;
          white-space: nowrap;
        }

        .public-search-post-card h3,
        .public-search-profile-card h3 {
          display: -webkit-box;
          margin: 4px 0 5px;
          overflow: hidden;
          color: #1F2933;
          font-family: var(--site-font-title, var(--site-font-primary, sans-serif));
          font-size: 16px;
          font-weight: 900;
          line-height: 1.2;
          letter-spacing: 0;
          -webkit-box-orient: vertical;
          -webkit-line-clamp: 2;
        }

        .public-search-post-card p,
        .public-search-profile-card p {
          display: -webkit-box;
          margin: 0;
          overflow: hidden;
          color: #6F7D86;
          font-size: 12.5px;
          font-weight: 550;
          line-height: 1.38;
          -webkit-box-orient: vertical;
          -webkit-line-clamp: 2;
        }

        .public-search-card-arrow {
          flex: 0 0 auto;
          color: #AFB8BE;
        }

        .public-search-app-grid {
          display: grid;
          grid-template-columns: repeat(3, minmax(0, 1fr));
          gap: 10px;
          padding: 16px;
        }

        .public-search-app-card {
          display: flex;
          min-width: 0;
          flex-direction: column;
          gap: 10px;
          border: 1px solid #E7ECEF;
          border-radius: 6px;
          background: #FFFFFF;
          padding: 14px;
          text-align: left;
          cursor: pointer;
        }

        .public-search-app-card:hover {
          border-color: rgba(227, 6, 19, 0.25);
          box-shadow: 0 12px 24px rgba(20, 31, 45, 0.08);
        }

        .public-search-app-icon {
          display: grid;
          width: 34px;
          height: 34px;
          place-items: center;
          border-radius: 6px;
          background: color-mix(in srgb, var(--search-app-accent) 12%, #FFFFFF);
          color: var(--search-app-accent);
        }

        .public-search-app-card strong {
          overflow: hidden;
          color: #24323B;
          font-size: 13px;
          font-weight: 900;
          text-overflow: ellipsis;
          white-space: nowrap;
        }

        .public-search-app-card span {
          display: -webkit-box;
          overflow: hidden;
          color: #75818A;
          font-size: 11.5px;
          font-weight: 600;
          line-height: 1.35;
          -webkit-box-orient: vertical;
          -webkit-line-clamp: 2;
        }

        .public-search-profile-avatar {
          display: grid;
          width: 48px;
          height: 48px;
          flex: 0 0 auto;
          place-items: center;
          overflow: hidden;
          border-radius: 999px;
          background: #EEF2F4;
          color: #20303A;
          font-size: 13px;
          font-weight: 900;
        }

        .public-search-profile-avatar img {
          width: 100%;
          height: 100%;
          object-fit: cover;
        }

        .public-search-loading {
          display: grid;
          gap: 9px;
          padding: 16px;
        }

        .public-search-loading span {
          display: block;
          height: 70px;
          border-radius: 6px;
          background: linear-gradient(90deg, #F0F3F4, #FAFBFB, #F0F3F4);
          background-size: 200% 100%;
          animation: public-search-shimmer 1.1s linear infinite;
        }

        @keyframes public-search-shimmer {
          to {
            background-position: -200% 0;
          }
        }

        .public-search-empty-state,
        .public-search-error {
          display: grid;
          place-items: center;
          gap: 8px;
          padding: 34px 18px;
          text-align: center;
        }

        .public-search-empty-state i,
        .public-search-error i {
          color: #E30613;
        }

        .public-search-empty-state strong,
        .public-search-error strong {
          color: #1F2933;
          font-size: 16px;
          font-weight: 900;
        }

        .public-search-empty-state span,
        .public-search-error span {
          max-width: 360px;
          color: #74818A;
          font-size: 13px;
          line-height: 1.45;
        }

        @media (max-width: 900px) {
          .public-search-hero {
            grid-template-columns: 1fr;
          }

          .public-search-app-grid {
            grid-template-columns: repeat(2, minmax(0, 1fr));
          }
        }

        @media (max-width: 767px) {
          body.public-route:has(.public-search-page) .public-site-header,
          body.public-route:has(.public-search-page) .mobile-shell-bottom-nav,
          body.public-route:has(.public-search-page) .mobile-anchor-ad-dock {
            display: none !important;
          }

          body.public-route:has(.public-search-page) main {
            margin: 0 !important;
            padding: 0 !important;
            transform: none !important;
            will-change: auto !important;
          }

          .public-search-page {
            min-height: 100dvh;
            padding: 0;
            background: #F8F9FA;
          }

          body.public-route .public-search-page > .public-search-desktop-shell {
            display: none !important;
          }

          body.public-route .public-search-page > .public-search-mobile-shell {
            display: flex !important;
            min-height: 100dvh;
            flex-direction: column;
          }

          .public-search-mobile-header {
            position: sticky;
            top: 0;
            z-index: 10;
            display: flex;
            align-items: center;
            gap: 10px;
            padding: calc(env(safe-area-inset-top, 0px) + 8px) 14px 8px;
            border-bottom: 1px solid #E7ECEF;
            background: #FFFFFF;
          }

          .public-search-mobile-header .public-search-form {
            height: 46px;
            flex: 1 1 auto;
            border-radius: 6px;
            background: #F3F5F6;
          }

          .public-search-mobile-back {
            display: grid;
            width: 42px;
            height: 42px;
            flex: 0 0 auto;
            place-items: center;
            border: 1px solid #E7ECEF;
            border-radius: 999px;
            background: #FFFFFF;
            color: #26343D;
            box-shadow: 0 8px 20px rgba(22, 32, 44, 0.08);
          }

          .public-search-results {
            flex: 1 1 auto;
            gap: 14px;
            padding: 18px 14px calc(env(safe-area-inset-bottom, 0px) + 26px);
          }

          .public-search-section,
          .public-search-empty-state,
          .public-search-error {
            border-radius: 6px;
            box-shadow: none;
          }

          .public-search-section-head {
            padding: 15px 16px;
          }

          .public-search-post-card {
            gap: 12px;
            padding: 10px;
          }

          .public-search-post-media {
            width: 76px;
            height: 76px;
          }

          .public-search-post-card h3,
          .public-search-profile-card h3 {
            font-size: 14.5px;
            line-height: 1.18;
          }

          .public-search-post-card p {
            font-size: 12px;
          }

          .public-search-app-grid {
            grid-template-columns: repeat(2, minmax(0, 1fr));
            gap: 9px;
            padding: 12px;
          }

          .public-search-app-card {
            padding: 12px;
          }
        }
      `}</style>
    </main>
  );
};

interface SearchResultSectionsProps {
  appResults: SearchAppItem[];
  error: string;
  idle: boolean;
  languageCode: string;
  loading: boolean;
  mobile?: boolean;
  onAppOpen: (item: SearchAppItem) => void;
  onPostOpen: (post: SearchPost) => void;
  onProfileOpen: (profile: SearchProfile) => void;
  results: SearchResults;
  shortQuery: boolean;
  showNoResult: boolean;
  siteSettings?: SiteSettings | null;
}

const SearchResultSections: React.FC<SearchResultSectionsProps> = ({
  appResults,
  error,
  idle,
  languageCode,
  loading,
  onAppOpen,
  onPostOpen,
  onProfileOpen,
  results,
  shortQuery,
  showNoResult,
  siteSettings,
}) => (
  <div className="public-search-results">
    {idle && (
      <div className="public-search-empty-state" role="status">
        <RemixIcon name="ri-search-eye-line" size={28} />
        <strong>Arama</strong>
        <span>Gündem, yazar, kategori, video ve uygulamalar.</span>
      </div>
    )}

    {shortQuery && (
      <div className="public-search-empty-state" role="status">
        <RemixIcon name="ri-search-line" size={28} />
        <strong>Arama hazır</strong>
        <span>Sonuçlar için en az iki karakter yaz.</span>
      </div>
    )}

    {loading && (
      <div className="public-search-section" aria-live="polite">
        <div className="public-search-loading">
          <span />
          <span />
          <span />
        </div>
      </div>
    )}

    {error && (
      <div className="public-search-error" role="status">
        <RemixIcon name="ri-error-warning-line" size={26} />
        <strong>Arama tamamlanamadı</strong>
        <span>{error}</span>
      </div>
    )}

    {showNoResult && !error && (
      <div className="public-search-empty-state" role="status">
        <RemixIcon name="ri-search-eye-line" size={28} />
        <strong>Sonuç bulunamadı</strong>
        <span>Yazımı değiştirerek haber başlığı, yazar adı veya uygulama adı aramayı dene.</span>
      </div>
    )}

    {appResults.length > 0 && (
      <section className="public-search-section" aria-labelledby="public-search-apps-title">
        <div className="public-search-section-head">
          <h2 id="public-search-apps-title">Uygulamalar</h2>
          <span>{appResults.length}</span>
        </div>
        <div className="public-search-app-grid">
          {appResults.map((item) => (
            <button
              key={item.id}
              type="button"
              className="public-search-app-card"
              style={{ '--search-app-accent': item.accent } as React.CSSProperties}
              onClick={() => onAppOpen(item)}
            >
              <span className="public-search-app-icon">
                <RemixIcon name={item.icon} size={19} />
              </span>
              <strong>{item.label}</strong>
              <span>{item.tagline}</span>
            </button>
          ))}
        </div>
      </section>
    )}

    {results.posts.length > 0 && (
      <section className="public-search-section" aria-labelledby="public-search-posts-title">
        <div className="public-search-section-head">
          <h2 id="public-search-posts-title">Haberler</h2>
          <span>{results.posts.length}</span>
        </div>
        <div className="public-search-post-list">
          {results.posts.map((post) => {
            const href = postHref(post, siteSettings);
            const image = postImage(post);
            const timeLabel = postTime(post, languageCode);
            return (
              <button
                key={`post-${cleanText(post.id) || href}`}
                type="button"
                className="public-search-post-card"
                onClick={() => onPostOpen(post)}
              >
                <span className="public-search-post-media">
                  {image ? (
                    <img src={image} alt={cleanText(post.title) || 'Haber görseli'} loading="lazy" decoding="async" />
                  ) : (
                    <RemixIcon name="ri-article-line" size={24} />
                  )}
                </span>
                <span className="public-search-post-copy">
                  <span className="public-search-post-meta">
                    <span>{cleanText(post.category) || 'Haber'}</span>
                    {timeLabel && <span>{timeLabel}</span>}
                  </span>
                  <h3>{cleanText(post.title) || 'Başlıksız haber'}</h3>
                  {cleanText(post.summary) && <p>{cleanText(post.summary)}</p>}
                </span>
                <RemixIcon name="ri-arrow-right-s-line" size={22} className="public-search-card-arrow" />
              </button>
            );
          })}
        </div>
      </section>
    )}

    {results.profiles.length > 0 && (
      <section className="public-search-section" aria-labelledby="public-search-profiles-title">
        <div className="public-search-section-head">
          <h2 id="public-search-profiles-title">Yayıncılar</h2>
          <span>{results.profiles.length}</span>
        </div>
        <div className="public-search-profile-list">
          {results.profiles.map((profile) => {
            const label = profileLabel(profile);
            const handle = profileHandle(profile);
            return (
              <button
                key={`profile-${cleanText(profile.id) || handle || label}`}
                type="button"
                className="public-search-profile-card"
                onClick={() => onProfileOpen(profile)}
              >
                <span className="public-search-profile-avatar">
                  {cleanText(profile.avatar_url) ? (
                    <img src={cleanText(profile.avatar_url)} alt={label} loading="lazy" decoding="async" />
                  ) : (
                    initials(label)
                  )}
                </span>
                <span className="public-search-profile-copy">
                  <h3>{label}</h3>
                  <p>{[handle, cleanText(profile.expertise)].filter(Boolean).join(' · ')}</p>
                </span>
                <RemixIcon name="ri-arrow-right-s-line" size={22} className="public-search-card-arrow" />
              </button>
            );
          })}
        </div>
      </section>
    )}
  </div>
);

export default SearchPage;
