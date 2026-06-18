
import React, { useCallback, useEffect, useMemo, useState } from 'react';
import MansetSlider from './MansetSlider';
import NewsCard, { NewsCardSkeleton } from './NewsCard';
import { type NewsItem, type SiteSettings, type NavigationItem } from '@/types';
import { useLanguage } from '@/context/LanguageContext';
import Skeleton from './ui/Skeleton';
import RemixIcon from './ui/RemixIcon';
import { dataService } from '@/services/dataService';

interface FeedProps {
  newsData: NewsItem[];
  title?: string;
  onNewsSelect?: (id: string) => void;
  onSourceClick?: (name: string) => void;
  siteSettings?: SiteSettings | null;
  navItems?: NavigationItem[];
  selectedCategory?: string;
  loading?: boolean;
}

const getNewsTime = (news: NewsItem) => {
  const date = new Date(news.timestamp || '');
  return Number.isNaN(date.getTime()) ? 0 : date.getTime();
};

const getPopularityScore = (news: NewsItem) => {
  const now = Date.now();
  const publishedAt = getNewsTime(news);
  const ageHours = publishedAt > 0 ? Math.max((now - publishedAt) / 36e5, 0) : 168;
  const freshness = Math.exp(-ageHours / 72) * 24;
  const views = Math.log1p(Math.max(news.views || 0, 0)) * 1.8;
  const likes = Math.log1p(Math.max(news.likes || 0, 0)) * 4.5;
  const comments = Math.log1p(Math.max(news.comments || 0, 0)) * 7;
  const shares = Math.log1p(Math.max(news.shares || 0, 0)) * 8.5;
  const saves = Math.log1p(Math.max(news.saves || 0, 0)) * 7.5;
  const dislikes = Math.log1p(Math.max(news.dislikes || 0, 0)) * 3;
  const pinned = news.isPinned ? 16 : 0;
  return freshness + views + likes + comments + shares + saves + pinned - dislikes;
};

const Feed: React.FC<FeedProps> = ({ newsData, title, onNewsSelect, onSourceClick, siteSettings, navItems, selectedCategory, loading }) => {
  const [activeFilter, setActiveFilter] = useState<'latest' | 'popular'>('latest');
  const [liveNewsData, setLiveNewsData] = useState<NewsItem[]>(newsData);
  const [filterLoading, setFilterLoading] = useState(false);
  const { t, currentLang } = useLanguage();

  const resolvedTitle = title ? t(title) : undefined;

  useEffect(() => {
    setLiveNewsData(newsData);
  }, [newsData]);

  const handleFilterChange = useCallback(async (filter: 'latest' | 'popular') => {
    setActiveFilter(filter);
    setFilterLoading(true);
    try {
      const category = selectedCategory && selectedCategory !== 'home' ? selectedCategory : null;
      const freshNews = await dataService.getNewsItems(currentLang.code || 'tr', category, 80, { fresh: true });
      if (freshNews.length > 0) {
        setLiveNewsData(freshNews);
      }
    } catch (error) {
      console.error('Feed refresh error:', error);
    } finally {
      setFilterLoading(false);
    }
  }, [currentLang.code, selectedCategory]);

  const mansetItems = useMemo(() => (
    liveNewsData
      .filter((news) => news.isManset)
      .sort((a, b) => getNewsTime(b) - getNewsTime(a))
      .slice(0, 20)
  ), [liveNewsData]);

  const hiddenMansetIds = useMemo(() => (
    !resolvedTitle ? new Set(mansetItems.map((news) => String(news.id))) : new Set<string>()
  ), [mansetItems, resolvedTitle]);

  const displayData = useMemo(() => {
    const sorted = liveNewsData.filter((news) => !hiddenMansetIds.has(String(news.id)));
    if (activeFilter === 'popular') {
      sorted.sort((a, b) => {
        if (a.isPinned !== b.isPinned) return b.isPinned ? -1 : 1;
        const scoreDiff = getPopularityScore(b) - getPopularityScore(a);
        return scoreDiff || (getNewsTime(b) - getNewsTime(a));
      });
    } else {
      sorted.sort((a, b) => {
        if (a.isPinned !== b.isPinned) return b.isPinned ? -1 : 1;
        return getNewsTime(b) - getNewsTime(a);
      });
    }
    return sorted;
  }, [liveNewsData, hiddenMansetIds, activeFilter]);

  return (
    <div className="flex flex-col gap-6 pb-4">
      {!resolvedTitle && mansetItems.length > 0 && (
        <div className="px-1">
          <MansetSlider
            slides={mansetItems}
            showNewsInfo={siteSettings?.content_featured_show_news_info === true}
            onNewsSelect={onNewsSelect}
          />
        </div>
      )}

      <div className="px-1 mt-1 mb-2">
        <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-4">
          <div className="space-y-1 overflow-hidden">
            <h2 className="text-xl sm:text-2xl font-bold text-gray-900 tracking-tight leading-none font-display whitespace-nowrap overflow-hidden text-ellipsis">
              {resolvedTitle ? (
                (() => {
                  const words = resolvedTitle.split(' ');
                  if (words.length <= 1) return resolvedTitle;
                  const mid = Math.ceil(words.length / 2);
                  const firstPart = words.slice(0, mid).join(' ');
                  const secondPart = words.slice(mid).join(' ');
                  return (
                    <>
                      {firstPart} <span className="text-palette-tan font-medium opacity-60 ml-1">{secondPart}</span>
                    </>
                  );
                })()
              ) : loading ? (
                <Skeleton className="w-48 h-8 mb-1" />
              ) : (
                <>
                  {t('feed.title_prefix')} <span className="text-palette-tan font-medium opacity-60 ml-1">{t('feed.title_suffix')}</span>
                </>
              )}
            </h2>
          </div>

          <div className="flex p-1 bg-palette-beige/10 rounded-[5px] border border-palette-beige/20 backdrop-blur-sm self-start sm:self-auto shadow-inner">
            <button
              onClick={() => void handleFilterChange('latest')}
              disabled={filterLoading && activeFilter === 'latest'}
              className={`flex items-center gap-1.5 px-4 py-1.5 rounded-[5px] text-[11px] font-bold tracking-tight transition-all duration-75 ${activeFilter === 'latest'
                ? 'bg-palette-red text-white shadow-lg shadow-palette-red/20'
                : 'text-palette-tan hover:text-palette-red'
                }`}
            >
              <RemixIcon name={filterLoading && activeFilter === 'latest' ? 'ri-loader-4-line' : 'ri-time-line'} size={16} className={filterLoading && activeFilter === 'latest' ? 'animate-spin' : undefined} />
              {t('feed.latest')}
            </button>

            <button
              onClick={() => void handleFilterChange('popular')}
              disabled={filterLoading && activeFilter === 'popular'}
              className={`flex items-center gap-1.5 px-4 py-1.5 rounded-[5px] text-[11px] font-bold tracking-tight transition-all duration-75 ${activeFilter === 'popular'
                ? 'bg-palette-red text-white shadow-lg shadow-palette-red/20'
                : 'text-palette-tan hover:text-palette-red'
                }`}
            >
              <RemixIcon name={filterLoading && activeFilter === 'popular' ? 'ri-loader-4-line' : 'ri-fire-line'} size={16} className={filterLoading && activeFilter === 'popular' ? 'animate-spin' : undefined} />
              {t('feed.popular')}
            </button>
          </div>
        </div>
      </div>

      <div className="flex flex-col gap-8">
        {loading ? (
          <>
            {[1, 2, 3].map(i => <NewsCardSkeleton key={i} />)}
          </>
        ) : (
          <>
            {displayData.map((news) => (
              <NewsCard
                key={news.id}
                data={news}
                onSourceClick={() => onSourceClick?.(news.source)}
                siteSettings={siteSettings}
                navItems={navItems}
              />
            ))}
            {displayData.length === 0 && (
              <div className="text-center py-20 bg-palette-beige/5 rounded-[5px] border border-dashed border-palette-beige/40">
                <span className="text-palette-tan font-bold tracking-widest text-xs uppercase">{t('feed.empty')}</span>
              </div>
            )}
          </>
        )}
      </div>
    </div>
  );
};

export default Feed;
