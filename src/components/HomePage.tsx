
import React, { useCallback, useMemo, useState } from 'react';
// import Navbar from './Navbar'; // Removed - Global
import Sidebar from './Sidebar';
import Feed from './Feed';
import RightSidebar from './RightSidebar';
import { navigate } from 'astro:transitions/client';
import { LanguageProvider } from '@/context/LanguageContext';
import { ToastProvider } from '@/context/ToastContext';
import type { SiteSettings, NavigationItem, NewsItem } from '@/types';
import { slugify } from '@/utils/helpers';

import { dataService } from '@/services/dataService';
import CategoriesList from './CategoriesList';
import CategoryDetail from './CategoryDetail';
import DistrictsList from './DistrictsList';
import TrendsList from './TrendsList';
import { getSpecialContentConfig } from '@/utils/specialContent';

const NORMAL_CATEGORY_LABELS: Record<string, string> = {
    spor: 'Spor',
};

interface HomePageProps {
    initialLang: any;
    initialTranslations: Record<string, string>;
    siteSettings: SiteSettings | null;
    navigationItems: NavigationItem[];
    newsItems: NewsItem[];
    sidebarSnapshot?: any;
    categoryPagination?: {
        category: string;
        limit: number;
        nextOffset: number;
        total: number;
        totalViews: number;
        hasMore: boolean;
    };
    selectedCategory?: string;
    isInitialHome?: boolean;
}

const HomePage: React.FC<HomePageProps> = ({
    initialLang,
    initialTranslations,
    siteSettings,
    navigationItems,
    newsItems: initialNews,
    sidebarSnapshot,
    categoryPagination,
    selectedCategory: initialCategory,
    isInitialHome = true
}) => {
    const getInitialFilterFromUrl = () => {
        if (typeof window === 'undefined') return null;
        return new URLSearchParams(window.location.search).get('kategori');
    };

    const [displayNews, setDisplayNews] = useState<NewsItem[]>(initialNews);
    const [activeCat, setActiveCat] = useState<string | null>(() => initialCategory || getInitialFilterFromUrl());
    const [isNewsLoading, setIsNewsLoading] = useState(false);
    const [activeView, setActiveView] = useState<'feed' | 'categories' | 'districts' | 'trends'>('feed');

    const activeNavItem = useMemo(() => {
        if (!activeCat) return null;
        const normalized = String(activeCat).trim();
        const normalizedSlug = slugify(normalized);
        return navigationItems.find((item) =>
            item.value === normalized ||
            item.label === normalized ||
            (item.value && slugify(item.value) === normalizedSlug) ||
            slugify(item.label) === normalizedSlug
        ) || null;
    }, [navigationItems, activeCat]);

    const activeSpecialContent = useMemo(() => (
        getSpecialContentConfig(activeCat, activeNavItem?.value, activeNavItem?.label)
    ), [activeCat, activeNavItem]);

    const isCategoryDetailView = activeView === 'feed' && !isInitialHome && !!activeCat && !activeSpecialContent && activeNavItem?.type !== 'trends';

    const handleCategoryNavigation = useCallback(async (category: string | null) => {
        const normalize = (value: string | null) => {
            const v = (value || '').trim();
            if (!v || v === 'home' || v === 'null') return null;
            return v;
        };

        const normalized = normalize(category);
        if (!normalized) {
            setActiveCat(null);
            setDisplayNews(initialNews);
            return;
        }

        const normalizedSlug = slugify(normalized);
        const navItem = navigationItems.find((item) =>
            item.value === normalized ||
            item.label === normalized ||
            (item.value && slugify(item.value) === normalizedSlug) ||
            slugify(item.label) === normalizedSlug
        );

        const specialContent = getSpecialContentConfig(normalized, navItem?.value, navItem?.label);
        if (specialContent) {
            setIsNewsLoading(true);
            try {
                document.cookie = `pateez_active_cat=${encodeURIComponent(specialContent.value)}; path=/; max-age=31536000; SameSite=Lax`;

                const targetUrl = `/?kategori=${encodeURIComponent(specialContent.value)}`;
                if (window.location.pathname !== '/' && window.location.pathname !== '') {
                    void navigate(targetUrl);
                    return;
                }

                const langCode = typeof initialLang === 'object' && initialLang !== null ? initialLang.code : initialLang;
                const news = await dataService.getNewsItems(langCode, specialContent.value);

                setDisplayNews(news);
                setActiveCat(navItem?.value || navItem?.label || specialContent.value);

                const url = new URL(window.location.href);
                url.searchParams.set('kategori', specialContent.value);
                window.history.replaceState({}, '', `${url.pathname}${url.search}${url.hash}`);
            } catch (err) {
                console.error('Special content filtering error:', err);
                setActiveCat(null);
                setDisplayNews(initialNews);
            } finally {
                setIsNewsLoading(false);
            }
            return;
        }

        if (!navItem) {
            void navigate(`/kategori/${slugify(normalized)}`);
            return;
        }

        const isMain = !navItem.parent_id || navItem.parent_id === 'root';
        const isTrend = navItem.type === 'trends';
        const isDistrict = navItem.type === 'district';

        // 🚀 SMART INTERNAL NAVIGATION (2026 LIGHT-SPEED)
        if (isMain) {
            // Find ALL recursively nested children to fetch broad content
            const children = navigationItems.filter(i => i.parent_id === navItem.id);

            // Collect all possible identifiers (Value, Label, and Slugified versions)
            const rootSlug = (navItem.value || navItem.label || '').trim();
            const subSlugs = children.map(c => (c.value || c.label || '').trim()).filter(Boolean);

            // Build a broad list for the database query including lowercase and slugified variants
            const broadFilters = Array.from(new Set([
                rootSlug,
                rootSlug.toLowerCase(),
                slugify(rootSlug),
                ...subSlugs,
                ...subSlugs.map(s => s.toLowerCase()),
                ...subSlugs.map(s => slugify(s))
            ])).filter(Boolean) as string[];

            setIsNewsLoading(true);
            try {
                // 🚀 SET PERMANENT CACHE (2026 LIGHT-SPEED)
                document.cookie = `pateez_active_cat=${encodeURIComponent(normalized)}; path=/; max-age=31536000; SameSite=Lax`;

                // If we are not on the home page, we should redirect to / to reset any sub-path (districts, trends etc)
                // This ensures "seçimler kalkacak" requirement is met globally.
                if (window.location.pathname !== '/' && window.location.pathname !== '') {
                    void navigate('/');
                    return;
                }

                // Wide fetch: fetches everything associated with this root and its children
                // CRITICAL FIX: Use initialLang.code (string) instead of initialLang (object)
                const langCode = typeof initialLang === 'object' && initialLang !== null ? initialLang.code : initialLang;
                const news = await dataService.getNewsItems(langCode, broadFilters);

                setDisplayNews(news);
                setActiveCat(normalized);
            } catch (err) {
                console.error('Filtering error:', err);
                setActiveCat(null);
                setDisplayNews(initialNews);
            } finally {
                setIsNewsLoading(false);
            }
        } else {
            // If it's a sub-category or trend, we redirect to its specific page for full SEO
            void navigate(`/kategori/${slugify(normalized)}`);
        }
    }, [navigationItems, initialNews, initialLang]);

    React.useEffect(() => {
        if (typeof window === 'undefined') return;

        const applySpecialFilter = (value?: string | null) => {
            const rawValue = value ?? new URLSearchParams(window.location.search).get('kategori');
            const specialContent = getSpecialContentConfig(rawValue);
            if (!specialContent) return;
            setActiveView('feed');
            void handleCategoryNavigation(specialContent.value);
        };

        const handleFilterEvent = (event: Event) => {
            const category = (event as CustomEvent<{ category?: string }>).detail?.category;
            applySpecialFilter(category);
        };

        const handlePopState = () => applySpecialFilter();

        applySpecialFilter();
        window.addEventListener('pateez:content-filter', handleFilterEvent as EventListener);
        window.addEventListener('popstate', handlePopState);

        return () => {
            window.removeEventListener('pateez:content-filter', handleFilterEvent as EventListener);
            window.removeEventListener('popstate', handlePopState);
        };
    }, [handleCategoryNavigation]);

    const handleNewsSelect = useCallback((id: string) => {
        const selected = displayNews.find((n) => n.id === id);
        const slugOrId = selected?.slug || id;
        void navigate(`/haber/${encodeURIComponent(slugOrId)}`);
    }, [displayNews]);

    const categoryTitleKey = useMemo(() => {
        if (!activeCat) return undefined;
        const normalized = String(activeCat).trim();

        if (activeSpecialContent) return activeSpecialContent.title;

        // 🚀 CRITICAL FIX: If it's a main category (Root), we return undefined 
        // to keep "Sizin İçin Seçtiklerimiz" as the title.
        const isMain = activeNavItem && (!activeNavItem.parent_id || activeNavItem.parent_id === 'root');
        if (isMain) return undefined;

        return activeNavItem?.label || NORMAL_CATEGORY_LABELS[slugify(normalized)] || normalized;
    }, [activeNavItem, activeCat, activeSpecialContent]);

    return (
        <LanguageProvider initialLang={initialLang} initialTranslations={initialTranslations}>
            <ToastProvider>
                <div className="min-h-screen bg-gray-50 text-gray-900 transition-opacity duration-300 opacity-100">

                    <main className="max-w-[1280px] pt-[92px] gap-8 px-4 mx-auto flex justify-center items-start">
                        <aside className="hidden lg:block w-[260px] flex-shrink-0 sticky top-[92px] h-[calc(100vh-92px)] overflow-y-auto pb-8 no-scrollbar">
                            <Sidebar
                                items={navigationItems}
                                activeCategory={activeCat}
                                onCategoryItemClick={(cat) => {
                                    setActiveView('feed');
                                    handleCategoryNavigation(cat);
                                }}
                                onAllCategoriesClick={() => setActiveView('categories')}
                                onAllDistrictsClick={() => setActiveView('districts')}
                                onAllTrendsClick={() => setActiveView('trends')}
                                loading={navigationItems.length === 0}
                            />
                        </aside>

                        <section className="flex-1 min-w-0 pb-10 flex justify-center w-full">
                            <div className={`w-full ${isCategoryDetailView ? 'max-w-none' : 'max-w-[840px]'}`}>
                                {activeView === 'feed' ? (
                                    isCategoryDetailView ? (
                                        <CategoryDetail
                                            category={categoryTitleKey || activeCat}
                                            newsItems={displayNews}
                                            navItems={navigationItems}
                                            pagination={categoryPagination}
                                            siteSettings={siteSettings}
                                            onNewsSelect={handleNewsSelect}
                                            onBack={() => void navigate('/')}
                                        />
                                    ) : (
                                        <Feed
                                            newsData={displayNews}
                                            siteSettings={siteSettings}
                                            navItems={navigationItems}
                                            selectedCategory={activeCat || undefined}
                                            title={categoryTitleKey}
                                            onNewsSelect={handleNewsSelect}
                                            loading={isNewsLoading || initialNews.length === 0}
                                        />
                                    )
                                ) : activeView === 'categories' ? (
                                    <CategoriesList
                                        onBack={() => setActiveView('feed')}
                                        onCategorySelect={(val) => {
                                            setActiveView('feed');
                                            handleCategoryNavigation(val);
                                        }}
                                    />
                                ) : activeView === 'districts' ? (
                                    <DistrictsList
                                        onBack={() => setActiveView('feed')}
                                        onDistrictSelect={(val) => {
                                            setActiveView('feed');
                                            handleCategoryNavigation(val);
                                        }}
                                    />
                                ) : (
                                    <TrendsList
                                        onBack={() => setActiveView('feed')}
                                        onTrendSelect={(val) => {
                                            setActiveView('feed');
                                            handleCategoryNavigation(val);
                                        }}
                                    />
                                )}
                            </div>
                        </section>

                        {activeView === 'feed' && !isCategoryDetailView && (
                            <aside className="hidden xl:block w-[320px] flex-shrink-0 pb-8">
                                <RightSidebar newsData={displayNews} loading={initialNews.length === 0} siteSettings={siteSettings} initialSidebarData={sidebarSnapshot} />
                            </aside>
                        )}
                    </main>
                </div>
            </ToastProvider>
        </LanguageProvider>
    );
};

export default HomePage;
