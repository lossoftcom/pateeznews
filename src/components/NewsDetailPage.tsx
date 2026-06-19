
import React from 'react';
import NewsDetail from './NewsDetail';
import RightSidebar from './RightSidebar';
import { LanguageProvider } from '@/context/LanguageContext';
import { ToastProvider } from '@/context/ToastContext';
import type { SiteSettings, NavigationItem, NewsItem, PublicAdSettings } from '@/types';

interface NewsDetailPageProps {
    initialLang: any;
    initialTranslations: Record<string, string>;
    siteSettings: SiteSettings | null;
    navigationItems: NavigationItem[];
    newsItem: NewsItem;
    newsItems: NewsItem[];
    sidebarSnapshot?: any;
    adSettings?: PublicAdSettings | null;
}

const NewsDetailPage: React.FC<NewsDetailPageProps> = ({
    initialLang,
    initialTranslations,
    siteSettings,
    navigationItems,
    newsItem,
    newsItems,
    sidebarSnapshot,
    adSettings
}) => {
    // 🚀 NO MORE DELAYS (2026 LIGHT-SPEED) - Page is visible instantly
    return (
        <LanguageProvider initialLang={initialLang} initialTranslations={initialTranslations}>
            <ToastProvider>
                <div className="min-h-screen bg-palette-white">

                    {/* Navbar is Global */}

                    <main className="public-page-main public-detail-page-main max-w-[1280px] pt-[92px] gap-8 px-4 mx-auto flex justify-center items-start">
                        <section className="flex-1 min-w-0 pb-10 flex justify-center xl:justify-end w-full">
                            <div className="w-full max-w-[840px] xl:max-w-[880px]">
                                <NewsDetail
                                    data={newsItem as any}
                                    navItems={navigationItems}
                                    siteSettings={siteSettings}
                                    adSettings={adSettings}
                                    onBack={() => window.history.back()}
                                    loading={!newsItem}
                                />
                            </div>
                        </section>

                        <aside className="hidden xl:block w-[320px] flex-shrink-0 pb-8 sticky top-[88px]">
                            <RightSidebar newsData={newsItems} loading={newsItems.length === 0} siteSettings={siteSettings} initialSidebarData={sidebarSnapshot} adSettings={adSettings} adSlotKey="web_article_sidebar" />
                        </aside>
                    </main>
                </div>
            </ToastProvider>
        </LanguageProvider>
    );
};

export default NewsDetailPage;
