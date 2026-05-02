
import React, { useCallback, useEffect, useMemo, useRef, useState } from 'react';
import { ArrowLeft, ChevronLeft, ChevronRight, Zap, Filter, TrendingUp } from 'lucide-react';
import { type NavigationItem, type NewsItem, NewsType, type SiteSettings } from '@/types';
import { useLanguage } from '@/context/LanguageContext';
import { subscribeNewsletter } from '@/services/appActions';
import { useToast } from '@/context/ToastContext';
import { slugify } from '@/utils/helpers';

const CATEGORY_TYPE_ALIASES: Record<string, NewsType[]> = {
  anket: [NewsType.POLL],
  anketler: [NewsType.POLL],
  poll: [NewsType.POLL],
  polls: [NewsType.POLL],
  test: [NewsType.QUIZ],
  testler: [NewsType.QUIZ],
  quiz: [NewsType.QUIZ],
  quizzes: [NewsType.QUIZ],
  video: [NewsType.VIDEO],
  videolar: [NewsType.VIDEO],
  videos: [NewsType.VIDEO],
};

const CATEGORY_SLIDER_AUTOPLAY_DELAY = 5500;
const CATEGORY_SLIDER_HEIGHT = 260;
const CATEGORY_PAGE_SIZE = 12;

interface CategorySlide {
  id: string;
  title: string;
  description: string;
  image: string;
  alt: string;
  width?: number;
  height?: number;
  ratio?: number;
}

const HTML_ENTITY_MAP: Record<string, string> = {
  amp: '&',
  apos: "'",
  Ccedil: 'Ç',
  ccedil: 'ç',
  Gbreve: 'Ğ',
  gbreve: 'ğ',
  gt: '>',
  hellip: '...',
  Idot: 'İ',
  imath: 'ı',
  laquo: '"',
  ldquo: '"',
  lsquo: "'",
  lt: '<',
  nbsp: ' ',
  Ouml: 'Ö',
  ouml: 'ö',
  quot: '"',
  raquo: '"',
  rdquo: '"',
  rsquo: "'",
  Scedil: 'Ş',
  scedil: 'ş',
  Uuml: 'Ü',
  uuml: 'ü',
};

const decodeCodePoint = (value: string, radix: number) => {
  const codePoint = Number.parseInt(value, radix);
  if (!Number.isFinite(codePoint)) return '';
  try {
    return String.fromCodePoint(codePoint);
  } catch {
    return '';
  }
};

const decodeHtmlEntities = (value: string) => (
  value
    .replace(/&([a-zA-Z][a-zA-Z0-9]+);/g, (match, entity: string) => HTML_ENTITY_MAP[entity] ?? match)
    .replace(/&#x([0-9a-fA-F]+);/g, (_match, hex: string) => decodeCodePoint(hex, 16))
    .replace(/&#(\d+);/g, (_match, decimal: string) => decodeCodePoint(decimal, 10))
);

const stripHtml = (value?: string) => (
  decodeHtmlEntities(
    String(value || '')
      .replace(/<[^>]*>/g, ' ')
      .replace(/&nbsp;/g, ' ')
      .replace(/\s+/g, ' ')
      .trim()
  )
);

const formatCompactMetric = (value: number) => {
  const safeValue = Math.max(0, Number(value) || 0);
  if (safeValue >= 1_000_000) return `${Number((safeValue / 1_000_000).toFixed(1))}M`;
  if (safeValue >= 1_000) return `${Number((safeValue / 1_000).toFixed(1))}K`;
  return safeValue.toString();
};

const getNewsImage = (news: NewsItem) => (
  news.optimizedCoverThumbnail?.src || news.optimizedThumbnail?.src || news.coverThumbnail || news.thumbnail || news.mediaList?.[0] || news.mediaUrl
);

const getNewsImageDimensions = (news: NewsItem) => {
  const optimized = news.optimizedCoverThumbnail || news.optimizedThumbnail;
  const width = Number(optimized?.width || 0);
  const height = Number(optimized?.height || 0);
  if (width > 0 && height > 0) return { width, height, ratio: width / height };
  return {};
};

const getNewsTime = (news: NewsItem) => {
  const date = new Date(news.timestamp || '');
  return Number.isNaN(date.getTime()) ? 0 : date.getTime();
};

const sortNewsNewest = (items: NewsItem[]) => (
  [...items].sort((a, b) => getNewsTime(b) - getNewsTime(a))
);

const mergeNewsById = (current: NewsItem[], incoming: NewsItem[]) => {
  const seen = new Set<string>();
  return sortNewsNewest([...current, ...incoming].filter((item) => {
    const id = String(item?.id || '');
    if (!id || seen.has(id)) return false;
    seen.add(id);
    return true;
  }));
};

const mapNewsToCategorySlide = (news: NewsItem): CategorySlide | null => {
  const image = getNewsImage(news);
  const title = stripHtml(news.seoTitle || news.title);
  const dimensions = getNewsImageDimensions(news);

  if (!image || !title) return null;

  return {
    id: String(news.id),
    title,
    description: stripHtml(news.summary || news.seoDescription),
    image,
    alt: news.thumbnailAlt || title,
    ...dimensions,
  };
};

interface CategoryDetailProps {
  category: string;
  onBack: () => void;
  onNewsSelect: (id: string) => void;
  siteSettings?: SiteSettings | null;
  newsItems?: NewsItem[];
  navItems?: NavigationItem[];
  pagination?: {
    category: string;
    limit: number;
    nextOffset: number;
    total: number;
    totalViews: number;
    hasMore: boolean;
  };
}

const CategoryDetail: React.FC<CategoryDetailProps> = ({ category, onBack, onNewsSelect, newsItems, navItems, pagination }) => {
  const { t, currentLang } = useLanguage();
  const { showToast } = useToast();
  const [newsletterEmail, setNewsletterEmail] = useState('');
  const [newsletterLoading, setNewsletterLoading] = useState(false);
  const [pagedNews, setPagedNews] = useState<NewsItem[]>(() => sortNewsNewest(newsItems || []));
  const [nextOffset, setNextOffset] = useState(() => pagination?.nextOffset ?? (newsItems?.length || 0));
  const [hasMore, setHasMore] = useState(() => pagination?.hasMore ?? false);
  const [totalCount, setTotalCount] = useState(() => pagination?.total ?? (newsItems?.length || 0));
  const [totalViews, setTotalViews] = useState(() => pagination?.totalViews ?? 0);
  const [isLoadingMore, setIsLoadingMore] = useState(false);
  const [loadMoreError, setLoadMoreError] = useState('');
  const loadMoreRef = useRef<HTMLDivElement | null>(null);
  const abortRef = useRef<AbortController | null>(null);
  const displayCategory = useMemo(() => {
    const categorySlug = slugify(category);
    const match = navItems?.find(item =>
      item.value === category ||
      item.label === category ||
      (item.value && slugify(item.value) === categorySlug) ||
      slugify(item.label) === categorySlug
    );
    return match?.label || category;
  }, [category, navItems]);

  useEffect(() => {
    setPagedNews(sortNewsNewest(newsItems || []));
    setNextOffset(pagination?.nextOffset ?? (newsItems?.length || 0));
    setHasMore(pagination?.hasMore ?? false);
    setTotalCount(pagination?.total ?? (newsItems?.length || 0));
    setTotalViews(pagination?.totalViews ?? 0);
    setLoadMoreError('');
  }, [
    category,
    newsItems,
    pagination?.hasMore,
    pagination?.nextOffset,
    pagination?.total,
    pagination?.totalViews,
  ]);

  useEffect(() => () => abortRef.current?.abort(), []);

  const loadMoreNews = useCallback(async () => {
    if (isLoadingMore || !hasMore) return;
    const requestCategory = (pagination?.category || displayCategory || category || '').trim();
    if (!requestCategory) return;

    setIsLoadingMore(true);
    setLoadMoreError('');
    abortRef.current?.abort();
    const controller = new AbortController();
    abortRef.current = controller;

    try {
      const url = new URL('/api/app/category-news', window.location.origin);
      url.searchParams.set('lang', currentLang.code || 'tr');
      url.searchParams.set('category', requestCategory);
      url.searchParams.set('offset', String(nextOffset));
      url.searchParams.set('limit', String(pagination?.limit || CATEGORY_PAGE_SIZE));

      const response = await fetch(url.toString(), {
        signal: controller.signal,
        headers: { Accept: 'application/json' },
      });

      if (!response.ok) throw new Error(t('common.data_load_error'));

      const payload = await response.json();
      const incoming = Array.isArray(payload?.items) ? payload.items as NewsItem[] : [];

      setPagedNews((current) => mergeNewsById(current, incoming));
      setNextOffset(Number(payload?.nextOffset ?? (nextOffset + incoming.length)));
      setHasMore(Boolean(payload?.hasMore));
      setTotalCount(Number(payload?.total ?? totalCount));
      setTotalViews(Number(payload?.totalViews ?? totalViews));
    } catch (error: any) {
      if (error?.name !== 'AbortError') {
        setLoadMoreError(error?.message || t('common.data_load_error'));
      }
    } finally {
      if (abortRef.current === controller) abortRef.current = null;
      setIsLoadingMore(false);
    }
  }, [
    category,
    currentLang.code,
    displayCategory,
    hasMore,
    isLoadingMore,
    nextOffset,
    pagination?.category,
    pagination?.limit,
    t,
    totalCount,
    totalViews,
  ]);

  useEffect(() => {
    const node = loadMoreRef.current;
    if (!node || !hasMore || isLoadingMore || loadMoreError) return undefined;

    const observer = new IntersectionObserver((entries) => {
      if (entries.some((entry) => entry.isIntersecting)) {
        void loadMoreNews();
      }
    }, {
      root: null,
      rootMargin: '700px 0px',
      threshold: 0.01,
    });

    observer.observe(node);
    return () => observer.disconnect();
  }, [hasMore, isLoadingMore, loadMoreError, loadMoreNews]);

  const categoryNews = useMemo(() => {
    const categorySlug = slugify(displayCategory);
    const typeAliases = CATEGORY_TYPE_ALIASES[categorySlug] || [];
    const sourceNews = pagedNews || [];

    return sortNewsNewest(sourceNews.filter(news => {
      const newsCategory = String(news.category || '');
      const newsCategorySlug = slugify(newsCategory);
      const newsType = String(news.type || '').toUpperCase();
      const hasMatchingBlock = Array.isArray(news.items) && news.items.some((item: any) =>
        typeAliases.some((type) => String(item?.type || '').toUpperCase() === type)
      );

      if (typeAliases.length > 0) {
        return typeAliases.some((type) => news.type === type || newsType === type || hasMatchingBlock);
      }

      return (
        newsCategory.toLowerCase().includes(displayCategory.toLowerCase()) ||
        newsCategorySlug === categorySlug ||
        newsCategorySlug.includes(categorySlug)
      );
    }));
  }, [displayCategory, pagedNews]);

  const categoryStats = useMemo(() => ({
    newsCount: Math.max(totalCount, categoryNews.length),
    totalViews: totalViews || categoryNews.reduce((total, news) => total + (Number(news.views) || 0), 0),
  }), [categoryNews, totalCount, totalViews]);

  const categorySliderItems = useMemo(() => (
    categoryNews
      .map(mapNewsToCategorySlide)
      .filter(Boolean)
      .slice(0, 10) as CategorySlide[]
  ), [categoryNews]);

  const [activeSlideIndex, setActiveSlideIndex] = useState(0);
  const [isSliderPaused, setIsSliderPaused] = useState(false);
  const [slideImageRatios, setSlideImageRatios] = useState<Record<string, number>>({});

  useEffect(() => {
    if (activeSlideIndex >= categorySliderItems.length) {
      setActiveSlideIndex(0);
    }
  }, [activeSlideIndex, categorySliderItems.length]);

  const goToCategorySlide = useCallback((index: number) => {
    if (categorySliderItems.length === 0) return;
    setActiveSlideIndex((index + categorySliderItems.length) % categorySliderItems.length);
  }, [categorySliderItems.length]);

  const goToPreviousSlide = useCallback((event?: React.MouseEvent) => {
    event?.stopPropagation();
    goToCategorySlide(activeSlideIndex - 1);
  }, [activeSlideIndex, goToCategorySlide]);

  const goToNextSlide = useCallback((event?: React.MouseEvent) => {
    event?.stopPropagation();
    goToCategorySlide(activeSlideIndex + 1);
  }, [activeSlideIndex, goToCategorySlide]);

  useEffect(() => {
    if (isSliderPaused || categorySliderItems.length < 2) return undefined;

    const timer = window.setInterval(() => {
      setActiveSlideIndex((current) => (current + 1) % categorySliderItems.length);
    }, CATEGORY_SLIDER_AUTOPLAY_DELAY);

    return () => window.clearInterval(timer);
  }, [categorySliderItems.length, isSliderPaused]);

  const activeSlide = categorySliderItems[activeSlideIndex];
  const activeSlideRatio = activeSlide ? activeSlide.ratio || slideImageRatios[activeSlide.id] || 3 / 2 : 3 / 2;
  const activeSlideImageWidth = Math.round(CATEGORY_SLIDER_HEIGHT * activeSlideRatio);
  const activeSlideStyle = {
    '--category-slide-image-width': `${activeSlideImageWidth}px`,
  } as React.CSSProperties;

  useEffect(() => {
    if (categorySliderItems.length === 0) return undefined;

    let isCancelled = false;
    categorySliderItems.forEach((slide) => {
      if (slide.ratio || slideImageRatios[slide.id]) return;

      const image = new window.Image();
      image.onload = () => {
        if (isCancelled || !image.naturalWidth || !image.naturalHeight) return;
        const ratio = image.naturalWidth / image.naturalHeight;
        setSlideImageRatios((current) => (
          current[slide.id] ? current : { ...current, [slide.id]: ratio }
        ));
      };
      image.src = slide.image;
    });

    return () => {
      isCancelled = true;
    };
  }, [categorySliderItems, slideImageRatios]);

  const handleNewsletterSubmit = async (event: React.FormEvent) => {
    event.preventDefault();
    if (!newsletterEmail.trim()) return;
    setNewsletterLoading(true);
    try {
      await subscribeNewsletter(newsletterEmail, `category:${displayCategory}`, currentLang.code || 'tr');
      setNewsletterEmail('');
      showToast(t('common.success'), 'success');
    } catch (error: any) {
      showToast(error.message || t('common.action_failed'), 'error');
    } finally {
      setNewsletterLoading(false);
    }
  };

  return (
    <div className="category-detail-compact animate-in bg-white rounded-[4px] border border-gray-200 shadow-sm overflow-hidden mb-10">
      <style>{`
        .category-detail-compact {
          --category-card-border: rgba(149, 165, 166, 0.58);
        }

        .category-detail-compact .category-hero-slider-card {
          height: 260px;
          min-height: 0;
        }

        .category-detail-compact .category-hero-slider-media {
          height: 100%;
          min-width: 0;
        }

        .category-detail-compact .category-hero-slider-card img {
          height: 100%;
          min-height: 0;
        }

        .category-detail-compact .category-hero-slider-copy h2 {
          display: -webkit-box;
          -webkit-line-clamp: 2;
          -webkit-box-orient: vertical;
          overflow: hidden;
        }

        .category-detail-compact .category-hero-slider-copy p {
          display: -webkit-box;
          -webkit-line-clamp: 3;
          -webkit-box-orient: vertical;
          overflow: hidden;
        }

        @media (min-width: 768px) {
          .category-detail-compact .category-hero-slider-card {
            grid-template-columns: clamp(280px, var(--category-slide-image-width, 462px), 62%) minmax(0, 1fr);
          }
        }

        @media (max-width: 760px) {
          .category-detail-compact .category-hero-slider-card {
            height: auto;
            min-height: 0;
          }

          .category-detail-compact .category-hero-slider-card img {
            min-height: 190px;
            height: 190px;
          }

          .category-detail-compact .category-hero-slider-copy h2 {
            -webkit-line-clamp: 3;
          }
        }
      `}</style>

      {/* Header Section */}
      <div className="p-6 md:p-8 border-b border-gray-50 bg-gray-50/30">
        <div className="flex items-center justify-between mb-6">
          <button
            onClick={onBack}
            className="p-2.5 bg-white border border-gray-200 text-gray-400 rounded-[4px] hover:text-palette-accent hover:border-palette-accent/20 transition-all shadow-sm group active:scale-90"
          >
            <ArrowLeft size={20} className="group-hover:-translate-x-1 transition-transform" />
          </button>

          <div className="flex items-center gap-2">
            <button className="p-2.5 bg-white border border-gray-200 text-gray-400 rounded-[4px] hover:text-gray-900 transition-all shadow-sm">
              <Filter size={18} />
            </button>
            <button className="p-2.5 bg-white border border-gray-200 text-gray-400 rounded-[4px] hover:text-gray-900 transition-all shadow-sm">
              <TrendingUp size={18} />
            </button>
          </div>
        </div>

        <div className="flex flex-col md:flex-row md:items-end justify-between gap-6">
          <div className="max-w-2xl">
            <h1 className="text-3xl md:text-4xl font-[900] text-gray-900 tracking-tight mb-2">{displayCategory}</h1>
            <p className="text-sm md:text-base text-gray-500 font-medium leading-relaxed">
              {t('category_detail.description').replace('{category}', displayCategory)}
            </p>
          </div>

          <div className="flex items-center gap-4 py-4 px-6 bg-white border border-gray-100 rounded-[4px] shadow-sm">
            <div className="flex flex-col">
              <span className="text-xl font-black text-gray-900 leading-none">{formatCompactMetric(categoryStats.newsCount)}</span>
              <span className="text-[10px] font-bold text-gray-400 uppercase tracking-widest mt-1">{t('common.news')}</span>
            </div>
            <div className="w-px h-8 bg-gray-100" />
            <div className="flex flex-col">
              <span className="text-xl font-black text-gray-900 leading-none">{formatCompactMetric(categoryStats.totalViews)}</span>
              <span className="text-[10px] font-bold text-gray-400 uppercase tracking-widest mt-1">{t('metrics.reads')}</span>
            </div>
          </div>
        </div>

      </div>

      <div className="p-5 md:p-6 lg:p-8 bg-gray-50/20">
        {activeSlide && (
          <section
            className="category-hero-slider relative mb-8"
            onMouseEnter={() => setIsSliderPaused(true)}
            onMouseLeave={() => setIsSliderPaused(false)}
            aria-label={`${displayCategory} haber sliderı`}
          >
            <article
              style={activeSlideStyle}
              className="category-hero-slider-card grid grid-cols-1 overflow-hidden rounded-[4px] bg-white border border-gray-100 shadow-sm cursor-pointer transition-all duration-300 hover:shadow-md"
              onClick={() => onNewsSelect(activeSlide.id)}
            >
              <div className="category-hero-slider-media relative overflow-hidden bg-gray-100">
                <img
                  src={activeSlide.image}
                  alt={activeSlide.alt}
                  width={activeSlide.width}
                  height={activeSlide.height}
                  loading="eager"
                  fetchPriority="high"
                  decoding="async"
                  className="w-full object-cover transition-transform duration-[9000ms] ease-out hover:scale-105"
                />
              </div>
              <div className="category-hero-slider-copy flex flex-col justify-center p-6 md:p-8">
                <h2 className="news-title-font text-[22px] md:text-[26px] font-black text-gray-800 leading-[1.22] tracking-tight mb-3">
                  {activeSlide.title}
                </h2>
                {activeSlide.description && (
                  <p className="news-subtitle-font text-[14px] md:text-[15px] text-gray-600 font-medium leading-relaxed">
                    {activeSlide.description}
                  </p>
                )}
              </div>
            </article>

            <button
              type="button"
              aria-label="Önceki haber"
              onClick={goToPreviousSlide}
              disabled={categorySliderItems.length < 2}
              className="absolute left-0 top-1/2 -translate-x-1/2 -translate-y-1/2 z-20 w-11 h-11 rounded-full bg-slate-400 text-white border-4 border-white shadow-sm flex items-center justify-center hover:bg-slate-500 transition-all active:scale-95 disabled:opacity-70 disabled:cursor-default disabled:hover:bg-slate-400"
            >
              <ChevronLeft size={24} strokeWidth={2.5} />
            </button>
            <button
              type="button"
              aria-label="Sonraki haber"
              onClick={goToNextSlide}
              disabled={categorySliderItems.length < 2}
              className="absolute right-0 top-1/2 translate-x-1/2 -translate-y-1/2 z-20 w-11 h-11 rounded-full bg-slate-400 text-white border-4 border-white shadow-sm flex items-center justify-center hover:bg-slate-500 transition-all active:scale-95 disabled:opacity-70 disabled:cursor-default disabled:hover:bg-slate-400"
            >
              <ChevronRight size={24} strokeWidth={2.5} />
            </button>
          </section>
        )}

        <div className="grid grid-cols-1 xl:grid-cols-[minmax(0,1fr)_320px] gap-5 lg:gap-6 items-start">
          <section className="min-w-0">
            {categoryNews.length > 0 ? (
              <div className="grid grid-cols-1 gap-4">
                {categoryNews.map(news => {
                  const image = getNewsImage(news);
                  const title = stripHtml(news.seoTitle || news.title);
                  const description = stripHtml(news.summary || news.seoDescription);

                  return (
                    <button
                      key={news.id}
                      type="button"
                      onClick={() => onNewsSelect(news.id)}
                      className={`category-news-list-item group grid grid-cols-1 ${image ? 'sm:grid-cols-[250px_minmax(0,1fr)]' : 'sm:grid-cols-1'} overflow-hidden rounded-[4px] border border-gray-100 bg-white text-left shadow-sm transition-all duration-200 hover:border-palette-accent/20 hover:shadow-md active:scale-[0.995]`}
                    >
                      {image && (
                        <div className="h-[160px] sm:h-full min-h-[160px] overflow-hidden bg-gray-100">
                          <img
                            src={image}
                            alt={news.thumbnailAlt || title}
                            className="w-full h-full object-cover transition-transform duration-700 group-hover:scale-[1.02]"
                          />
                        </div>
                      )}
                      <div className="flex min-w-0 flex-col justify-center p-5 md:p-6">
                        <h3 className="news-title-font text-[20px] md:text-[22px] font-black text-gray-800 leading-[1.16] tracking-tight line-clamp-2">
                          {title}
                        </h3>
                        {description && (
                          <p className="news-subtitle-font mt-3 text-[14px] md:text-[15px] text-gray-600 font-medium leading-relaxed line-clamp-3">
                            {description}
                          </p>
                        )}
                      </div>
                    </button>
                  );
                })}
                {(hasMore || isLoadingMore || loadMoreError) && (
                  <div ref={loadMoreRef} className="flex justify-center py-4">
                    {isLoadingMore ? (
                      <div className="flex items-center gap-3 rounded-[4px] border border-gray-100 bg-white px-5 py-3 text-[11px] font-black uppercase tracking-widest text-gray-400 shadow-sm">
                        <span className="h-4 w-4 animate-spin rounded-full border-2 border-gray-200 border-t-palette-accent" />
                        {t('category_detail.loading_more')}
                      </div>
                    ) : (
                      <button
                        type="button"
                        onClick={() => void loadMoreNews()}
                        className="rounded-[4px] border border-gray-200 bg-white px-6 py-3 text-[11px] font-black uppercase tracking-widest text-gray-500 shadow-sm transition-all hover:border-palette-accent/30 hover:text-palette-accent hover:shadow-md active:scale-95"
                      >
                        {loadMoreError ? t('category_detail.load_error') : t('category_detail.load_more')}
                      </button>
                    )}
                  </div>
                )}
              </div>
            ) : (
              <div className="text-center py-24 bg-white rounded-[4px] border border-gray-100 shadow-sm">
                <div className="w-20 h-20 bg-gray-50 rounded-[4px] flex items-center justify-center mx-auto mb-6 text-gray-300">
                  <Zap size={40} />
                </div>
                <h3 className="text-2xl font-black text-gray-900 mb-2">{t('category_detail.empty_title')}</h3>
                <p className="text-gray-400 text-sm font-medium uppercase tracking-widest px-8">
                  {t('category_detail.empty_description')}
                </p>
                <button
                  onClick={onBack}
                  className="mt-8 px-8 py-3 bg-gray-900 text-white rounded-[4px] font-black text-[11px] uppercase tracking-widest hover:bg-palette-accent transition-all shadow-lg active:scale-95"
                >
                  {t('admin.post.go_back')}
                </button>
              </div>
            )}
          </section>

          <aside className="xl:sticky xl:top-[100px]">
            <div className="rounded-[4px] border border-gray-100 bg-white p-6 shadow-sm">
              <h4 className="text-xl font-black text-gray-900 mb-2">{t('category_detail.newsletter_title')}</h4>
              <p className="text-gray-500 text-sm font-medium mb-6 leading-relaxed">{t('category_detail.newsletter_description').replace('{category}', displayCategory)}</p>
              <form onSubmit={handleNewsletterSubmit} className="space-y-3">
                <input
                  type="email"
                  value={newsletterEmail}
                  onChange={(event) => setNewsletterEmail(event.target.value)}
                  placeholder={t('category_detail.email_placeholder')}
                  className="w-full h-12 bg-gray-50 border border-gray-200 rounded-[4px] px-4 text-sm font-bold focus:bg-white focus:border-palette-accent focus:outline-none transition-all"
                />
                <button disabled={newsletterLoading} className="w-full h-12 bg-palette-accent text-palette-maroon rounded-[4px] font-black text-[11px] uppercase tracking-widest hover:bg-palette-maroon hover:text-palette-beige transition-all shadow-lg shadow-palette-accent/20 disabled:opacity-60">
                  {newsletterLoading ? '...' : t('category_detail.subscribe')}
                </button>
              </form>
            </div>
          </aside>
        </div>
      </div>

    </div>
  );
};

export default CategoryDetail;
