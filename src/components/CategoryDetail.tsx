
import React, { useCallback, useEffect, useMemo, useRef, useState } from 'react';
import { ArrowLeft, ChevronLeft, ChevronRight, Zap, Filter, TrendingUp } from 'lucide-react';
import { type NavigationItem, type NewsItem, type SiteSettings } from '@/types';
import { useLanguage } from '@/context/LanguageContext';
import { subscribeNewsletter } from '@/services/appActions';
import { useToast } from '@/context/ToastContext';
import { formatPostDateParts, slugify } from '@/utils/helpers';
import RemixIcon from './ui/RemixIcon';

const CATEGORY_TYPE_ALIASES: Record<string, string[]> = {
  anket: ['poll'],
  anketler: ['poll'],
  poll: ['poll'],
  polls: ['poll'],
  test: ['quiz'],
  testler: ['quiz'],
  quiz: ['quiz'],
  quizzes: ['quiz'],
  video: ['video'],
  videolar: ['video'],
  videos: ['video'],
  liste: ['contents'],
  listeler: ['contents'],
  icindekiler: ['contents'],
  'içindekiler': ['contents'],
  contents: ['contents'],
  content: ['contents'],
  'table-of-contents': ['contents'],
  toc: ['contents'],
  tarif: ['recipe'],
  tarifler: ['recipe'],
  recipe: ['recipe'],
  recipes: ['recipe'],
  etkinlik: ['event'],
  etkinlikler: ['event'],
  event: ['event'],
  events: ['event'],
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

const normalizeCategoryImageUrl = (value?: string | null) => {
  const clean = String(value || '').trim();
  if (!clean) return '';
  if (/^(https?:)?\/\//i.test(clean) || clean.startsWith('data:') || clean.startsWith('/')) {
    return clean;
  }
  return `/${clean.replace(/^\/+/, '')}`;
};

const formatCompactMetric = (value: number) => {
  const safeValue = Math.max(0, Number(value) || 0);
  if (safeValue >= 1_000_000) return `${Number((safeValue / 1_000_000).toFixed(1))}M`;
  if (safeValue >= 1_000) return `${Number((safeValue / 1_000).toFixed(1))}K`;
  return safeValue.toString();
};

const formatFullMetric = (value: number, lang = 'tr') => (
  Math.max(0, Number(value) || 0).toLocaleString(lang || 'tr')
);

const getCategoryMetricLabel = (metric: 'likes' | 'comments', lang = 'tr') => {
  const isTurkish = String(lang || '').toLocaleLowerCase('tr-TR').startsWith('tr');
  if (metric === 'likes') return isTurkish ? 'beğeni' : 'likes';
  return isTurkish ? 'yorum' : 'comments';
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

const normalizedToken = (value: unknown) => String(value || '').trim().toLocaleLowerCase('tr-TR');

const getNewsCategoryLabels = (news: NewsItem) => {
  const rawTrail = (news as any).categoryTrail ?? (news as any).categoryPath;
  const trail = Array.isArray(rawTrail) ? rawTrail : [];
  return [news.category, ...trail]
    .map((value) => String(value || '').trim())
    .filter(Boolean);
};

const getNewsTypeTokens = (news: NewsItem) => [
  news.type,
  (news as any).postType,
  (news as any).type,
]
  .map(normalizedToken)
  .filter(Boolean);

const safeDecodePathPart = (value: string) => {
  try {
    return decodeURIComponent(value);
  } catch {
    return value;
  }
};

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
    activeSubcategory?: string | null;
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
  const [activeSubcategory, setActiveSubcategory] = useState<string | null>(() => pagination?.activeSubcategory || null);
  const loadMoreRef = useRef<HTMLDivElement | null>(null);
  const abortRef = useRef<AbortController | null>(null);
  const activeCategoryItem = useMemo(() => {
    const categorySlug = slugify(category);
    return navItems?.find(item =>
      item.value === category ||
      item.label === category ||
      (item.value && slugify(item.value) === categorySlug) ||
      slugify(item.label) === categorySlug
    ) || null;
  }, [category, navItems]);
  const displayCategory = activeCategoryItem?.label || category;
  const categoryImageUrl = normalizeCategoryImageUrl(
    (activeCategoryItem as any)?.image_url || (activeCategoryItem as any)?.imageUrl
  );

  useEffect(() => {
    setPagedNews(sortNewsNewest(newsItems || []));
    setNextOffset(pagination?.nextOffset ?? (newsItems?.length || 0));
    setHasMore(pagination?.hasMore ?? false);
    setTotalCount(pagination?.total ?? (newsItems?.length || 0));
    setTotalViews(pagination?.totalViews ?? 0);
    setLoadMoreError('');
    setActiveSubcategory(pagination?.activeSubcategory || null);
  }, [
    category,
    newsItems,
    pagination?.activeSubcategory,
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

  const matchedCategoryNews = useMemo(() => {
    const categorySlug = slugify(displayCategory);
    const categoryValueSlug = slugify((activeCategoryItem as any)?.value || '');
    const acceptedCategorySlugs = new Set([categorySlug, categoryValueSlug].filter(Boolean));
    const typeAliases = CATEGORY_TYPE_ALIASES[categorySlug] || [];
    const sourceNews = pagedNews || [];

    return sortNewsNewest(sourceNews.filter(news => {
      const newsCategoryLabels = getNewsCategoryLabels(news);
      const newsCategorySlugs = newsCategoryLabels.map(slugify).filter(Boolean);
      const newsTypeTokens = getNewsTypeTokens(news);
      const hasMatchingBlock = Array.isArray(news.items) && news.items.some((item: any) =>
        typeAliases.includes(normalizedToken(item?.type))
      );

      if (typeAliases.length > 0) {
        return typeAliases.some((type) => newsTypeTokens.includes(type)) || hasMatchingBlock;
      }

      return newsCategoryLabels.some((label, index) => {
        const labelSlug = newsCategorySlugs[index] || '';
        return (
          normalizedToken(label).includes(normalizedToken(displayCategory)) ||
          acceptedCategorySlugs.has(labelSlug) ||
          (!!categorySlug && labelSlug.includes(categorySlug))
        );
      });
    }));
  }, [activeCategoryItem, displayCategory, pagedNews]);

  const subcategoryOptions = useMemo(() => {
    if (activeCategoryItem?.type !== 'district') return [];
    const categorySlug = slugify(displayCategory);
    const categoryValueSlug = slugify((activeCategoryItem as any)?.value || '');
    const acceptedCategorySlugs = new Set([categorySlug, categoryValueSlug].filter(Boolean));
    const seen = new Set<string>();
    const options: string[] = [];

    matchedCategoryNews.forEach((news) => {
      const labels = getNewsCategoryLabels(news);
      const parentIndex = labels.findIndex((label) => acceptedCategorySlugs.has(slugify(label)));
      const nextLabel = parentIndex >= 0 ? labels[parentIndex + 1] : '';
      const fallbackLabel = !nextLabel && !acceptedCategorySlugs.has(slugify(news.category)) ? news.category : '';
      const label = String(nextLabel || fallbackLabel || '').trim();
      const key = slugify(label);
      if (!label || !key || seen.has(key)) return;
      seen.add(key);
      options.push(label);
    });

    return options;
  }, [activeCategoryItem, displayCategory, matchedCategoryNews]);

  const categoryPathSlug = useMemo(() => (
    slugify(String((activeCategoryItem as any)?.value || activeCategoryItem?.label || displayCategory || category || ''))
  ), [activeCategoryItem, category, displayCategory]);

  const getSubcategoryFromLocation = useCallback(() => {
    if (typeof window === 'undefined' || subcategoryOptions.length === 0) return null;

    const pathParts = window.location.pathname
      .split('/')
      .filter(Boolean)
      .map(safeDecodePathPart);
    const categoryIndex = pathParts.findIndex((part) => ['kategori', 'kategoriler'].includes(slugify(part)));
    const rawSubcategory = categoryIndex >= 0 ? pathParts[categoryIndex + 2] : '';
    const subcategorySlug = slugify(rawSubcategory || '');

    if (!subcategorySlug) return null;
    return subcategoryOptions.find((label) => slugify(label) === subcategorySlug) || null;
  }, [subcategoryOptions]);

  const updateSubcategoryPath = useCallback((nextSubcategory: string | null) => {
    if (typeof window === 'undefined' || !categoryPathSlug) return;

    const subcategorySlug = nextSubcategory ? slugify(nextSubcategory) : '';
    const nextPath = `/kategori/${categoryPathSlug}${subcategorySlug ? `/${subcategorySlug}` : ''}`;
    const nextUrl = `${nextPath}${window.location.search}${window.location.hash}`;
    const currentUrl = `${window.location.pathname}${window.location.search}${window.location.hash}`;

    if (currentUrl !== nextUrl) {
      window.history.pushState({ category: categoryPathSlug, subcategory: subcategorySlug || null }, '', nextUrl);
    }
  }, [categoryPathSlug]);

  const handleSubcategorySelect = useCallback((nextSubcategory: string | null) => {
    setActiveSubcategory(nextSubcategory);
    updateSubcategoryPath(nextSubcategory);
  }, [updateSubcategoryPath]);

  useEffect(() => {
    if (typeof window === 'undefined') return undefined;

    const syncSubcategoryFromLocation = () => {
      const nextSubcategory = getSubcategoryFromLocation();
      setActiveSubcategory((current) => (
        slugify(current || '') === slugify(nextSubcategory || '') ? current : nextSubcategory
      ));
    };

    syncSubcategoryFromLocation();
    window.addEventListener('popstate', syncSubcategoryFromLocation);
    return () => window.removeEventListener('popstate', syncSubcategoryFromLocation);
  }, [getSubcategoryFromLocation]);

  useEffect(() => {
    if (!activeSubcategory) return;
    const activeSlug = slugify(activeSubcategory);
    if (!subcategoryOptions.some((label) => slugify(label) === activeSlug)) {
      setActiveSubcategory(null);
    }
  }, [activeSubcategory, subcategoryOptions]);

  const categoryNews = useMemo(() => {
    if (!activeSubcategory) return matchedCategoryNews;
    const activeSlug = slugify(activeSubcategory);
    return matchedCategoryNews.filter((news) => (
      getNewsCategoryLabels(news).some((label) => slugify(label) === activeSlug)
    ));
  }, [activeSubcategory, matchedCategoryNews]);

  const categoryStats = useMemo(() => ({
    newsCount: activeSubcategory ? categoryNews.length : Math.max(totalCount, categoryNews.length),
    totalViews: activeSubcategory
      ? categoryNews.reduce((total, news) => total + (Number(news.views) || 0), 0)
      : totalViews || categoryNews.reduce((total, news) => total + (Number(news.views) || 0), 0),
  }), [activeSubcategory, categoryNews, totalCount, totalViews]);

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
          display: flex;
          align-items: center;
          justify-content: center;
          height: 100%;
          min-width: 0;
        }

        .category-detail-compact .category-hero-slider-card img {
          width: 100%;
          height: 100%;
          min-height: 0;
          object-fit: contain;
          object-position: center;
        }

        .category-detail-compact .category-hero-slider-copy h2 {
          font-size: var(--web-category-slider-title-size, 22px) !important;
          font-weight: var(--web-category-slider-title-weight, 700) !important;
          line-height: 1.2;
          display: -webkit-box;
          -webkit-line-clamp: 3;
          -webkit-box-orient: vertical;
          overflow: hidden;
        }

        .category-detail-compact .category-hero-slider-copy p {
          font-size: var(--web-category-slider-summary-size, 14px) !important;
          font-weight: var(--web-category-slider-summary-weight, 400) !important;
          line-height: 1.55;
          display: -webkit-box;
          -webkit-line-clamp: 3;
          -webkit-box-orient: vertical;
          overflow: hidden;
        }

        .category-detail-compact .category-news-list-item {
          position: relative;
          isolation: isolate;
        }

        .category-detail-compact .category-news-list-item::before {
          content: "";
          position: absolute;
          inset: 0 auto 0 0;
          width: 3px;
          background: linear-gradient(180deg, #EA4335 0%, #F39C12 100%);
          opacity: 0;
          transition: opacity 180ms ease;
          z-index: 1;
        }

        .category-detail-compact .category-news-list-item:hover::before {
          opacity: 1;
        }

        .category-detail-compact .category-news-list-media {
          display: flex;
          align-items: center;
          justify-content: center;
          aspect-ratio: var(--category-list-image-ratio, 4 / 3);
          height: auto;
          min-height: 0;
        }

        .category-detail-compact .category-news-list-media img {
          width: 100%;
          height: 100%;
          object-fit: contain;
          object-position: center;
        }

        .category-detail-compact .category-news-list-title {
          font-size: var(--web-category-card-title-size, 19px) !important;
          font-weight: var(--web-category-card-title-weight, 700) !important;
          line-height: 1.2;
          overflow-wrap: anywhere;
        }

        .category-detail-compact .category-news-list-summary {
          font-size: var(--web-category-card-summary-size, 13px) !important;
          font-weight: var(--web-category-card-summary-weight, 400) !important;
          line-height: 1.52;
          overflow-wrap: anywhere;
        }

        .category-detail-compact .category-news-list-meta {
          font-family: var(--site-font-content, 'PateezInter'), 'Inter', system-ui, -apple-system, BlinkMacSystemFont, 'Segoe UI', Arial, sans-serif;
        }

        @media (min-width: 768px) {
          .category-detail-compact .category-hero-slider-card {
            grid-template-columns: clamp(280px, var(--category-slide-image-width, 462px), 62%) minmax(0, 1fr);
          }
        }

        @media (max-width: 760px) {
          .category-detail-compact .category-identity-visual {
            height: 146px;
          }

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

          .category-detail-compact .category-news-list-media {
            height: auto;
          }

          .category-detail-compact .category-news-list-title {
            font-size: var(--web-category-card-title-size, 19px) !important;
          }
        }
      `}</style>

      {/* Header Section */}
      <div className={`${categoryImageUrl ? 'px-6 pt-6 pb-3 md:px-8 md:pt-8 md:pb-3' : 'p-6 md:p-8'} border-b border-gray-50 bg-gray-50/30`}>
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

        {categoryImageUrl && (
          <div className="category-identity-visual relative h-[176px] overflow-hidden rounded-[4px] border border-gray-100 bg-gray-100 shadow-sm md:h-[184px]">
            <img
              src={categoryImageUrl}
              alt={`${displayCategory} kategori görseli`}
              loading="eager"
              fetchPriority="high"
              decoding="async"
              className="h-full w-full object-cover"
            />
            <div className="absolute inset-0 bg-gradient-to-t from-gray-950/55 via-gray-950/10 to-transparent" />
            <div className="absolute right-3 top-3 flex items-center gap-2 sm:right-4 sm:top-4">
              <div className="flex items-center gap-2 rounded-[4px] border border-white/35 bg-white/90 px-2.5 py-2 text-gray-900 shadow-sm backdrop-blur">
                <span className="text-sm font-black leading-none">{formatCompactMetric(categoryStats.newsCount)}</span>
                <span className="text-[9px] font-black uppercase tracking-[0.16em] text-gray-500">{t('common.news')}</span>
              </div>
              <div className="flex items-center gap-2 rounded-[4px] border border-white/35 bg-white/90 px-2.5 py-2 text-gray-900 shadow-sm backdrop-blur">
                <span className="text-sm font-black leading-none">{formatCompactMetric(categoryStats.totalViews)}</span>
                <span className="text-[9px] font-black uppercase tracking-[0.16em] text-gray-500">{t('metrics.reads')}</span>
              </div>
            </div>
            <div className="absolute inset-x-0 bottom-0 flex items-end justify-between gap-4 p-4 md:p-5">
              <div className="min-w-0">
                <span className="block text-[10px] font-black tracking-[0.18em] text-white/75">
                  {activeCategoryItem?.type === 'district' ? 'İlçe' : 'Kategori'}
                </span>
                <h1 className="news-title-font mt-1 block truncate text-2xl font-black leading-none text-white md:text-3xl">
                  {displayCategory}
                </h1>
              </div>
              <span className="hidden h-1.5 w-16 rounded-full bg-palette-accent/90 shadow-[0_0_22px_rgba(243,156,18,0.35)] sm:block" />
            </div>
          </div>
        )}

        {!categoryImageUrl && (
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
        )}

        {subcategoryOptions.length > 0 && (
          <div className="mt-4 flex flex-wrap items-center gap-2">
            <button
              type="button"
              aria-pressed={!activeSubcategory}
              onClick={() => handleSubcategorySelect(null)}
              className={`h-9 rounded-[4px] border px-4 text-[11px] font-black uppercase tracking-widest transition-all ${!activeSubcategory ? 'border-palette-accent bg-palette-accent text-palette-maroon shadow-sm' : 'border-gray-200 bg-white text-gray-500 hover:border-palette-accent/40 hover:text-palette-accent'}`}
            >
              {t('right.all')}
            </button>
            {subcategoryOptions.map((label) => {
              const isActive = slugify(activeSubcategory || '') === slugify(label);
              return (
                <button
                  key={label}
                  type="button"
                  aria-pressed={isActive}
                  onClick={() => handleSubcategorySelect(label)}
                  className={`h-9 rounded-[4px] border px-4 text-[11px] font-black uppercase tracking-widest transition-all ${isActive ? 'border-palette-accent bg-palette-accent text-palette-maroon shadow-sm' : 'border-gray-200 bg-white text-gray-500 hover:border-palette-accent/40 hover:text-palette-accent'}`}
                >
                  {label}
                </button>
              );
            })}
          </div>
        )}

      </div>

      <div className={`${categoryImageUrl ? 'px-5 pt-3 pb-5 md:px-6 md:pt-3 md:pb-6 lg:px-8 lg:pt-4 lg:pb-8' : 'p-5 md:p-6 lg:p-8'} bg-gray-50/20`}>
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
              <div className="category-hero-slider-media relative overflow-hidden bg-gray-50">
                <img
                  src={activeSlide.image}
                  alt={activeSlide.alt}
                  width={activeSlide.width}
                  height={activeSlide.height}
                  loading="eager"
                  fetchPriority="high"
                  decoding="async"
                  className="h-full w-full object-contain"
                />
              </div>
              <div className="category-hero-slider-copy flex flex-col justify-center p-5 md:p-6">
                <h2 className="news-title-font text-gray-800 tracking-normal mb-2.5">
                  {activeSlide.title}
                </h2>
                {activeSlide.description && (
                  <p className="news-subtitle-font text-gray-600">
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

        <div className="grid grid-cols-1 xl:grid-cols-[minmax(0,1fr)_260px] gap-4 lg:gap-5 items-start">
          <section className="min-w-0">
            {categoryNews.length > 0 ? (
              <div className="grid grid-cols-1 gap-4">
                {categoryNews.map(news => {
                  const image = getNewsImage(news);
                  const title = stripHtml(news.seoTitle || news.title);
                  const description = stripHtml(news.summary || news.seoDescription);
                  const imageDimensions = getNewsImageDimensions(news);
                  const imageFrameStyle = imageDimensions.ratio
                    ? { '--category-list-image-ratio': `${imageDimensions.ratio}` } as React.CSSProperties
                    : undefined;
                  const publishedAt = formatPostDateParts(news.timestamp, currentLang.code);
                  const metricLang = currentLang.code || 'tr';

                  return (
                    <button
                      key={news.id}
                      type="button"
                      onClick={() => onNewsSelect(news.id)}
                      className={`category-news-list-item group grid grid-cols-1 ${image ? 'sm:grid-cols-[150px_minmax(0,1fr)] lg:grid-cols-[156px_minmax(0,1fr)]' : 'sm:grid-cols-1'} items-center overflow-hidden rounded-[4px] border border-gray-100 bg-white text-left shadow-sm transition-all duration-200 hover:-translate-y-0.5 hover:border-palette-accent/20 hover:shadow-md active:scale-[0.995]`}
                    >
                      {image && (
                        <div className="category-news-list-media overflow-hidden bg-gray-50 sm:self-center" style={imageFrameStyle}>
                          <img
                            src={image}
                            alt={news.thumbnailAlt || title}
                            loading="lazy"
                            decoding="async"
                            className="h-full w-full object-contain"
                          />
                        </div>
                      )}
                      <div className="category-news-list-content flex min-w-0 flex-col justify-between p-4 sm:min-h-[118px] md:p-4">
                        <div className="min-w-0">
                          <h3 className="category-news-list-title news-title-font text-gray-800 tracking-normal transition-colors group-hover:text-palette-red">
                            {title}
                          </h3>
                          {description && (
                            <p className="category-news-list-summary news-subtitle-font mt-2 text-gray-600">
                              {description}
                            </p>
                          )}
                        </div>
                        <div className="category-news-list-meta mt-3 flex flex-wrap items-center gap-x-3 gap-y-1.5 border-t border-palette-beige/20 pt-2.5 text-[11px] font-semibold text-palette-tan/45">
                          {publishedAt.date && (
                            <span className="inline-flex min-w-0 items-center gap-1.5 normal-case tracking-normal">
                              <RemixIcon name="ri-calendar-line" size={13} className="opacity-80" />
                              <time dateTime={publishedAt.iso || undefined}>{publishedAt.date}</time>
                            </span>
                          )}
                          {publishedAt.time && (
                            <span className="inline-flex items-center gap-1.5 normal-case tracking-normal">
                              <RemixIcon name="ri-time-line" size={13} className="opacity-80" />
                              <time dateTime={publishedAt.iso || undefined}>{publishedAt.time}</time>
                            </span>
                          )}
                          <span className="inline-flex items-center gap-1.5">
                            <RemixIcon name="ri-thumb-up-line" size={13} className="opacity-80" />
                            <span>{formatFullMetric(news.likes, metricLang)}</span>
                            <span>{getCategoryMetricLabel('likes', metricLang)}</span>
                          </span>
                          <span className="inline-flex items-center gap-1.5">
                            <RemixIcon name="ri-chat-3-line" size={13} className="opacity-80" />
                            <span>{formatFullMetric(news.comments, metricLang)}</span>
                            <span>{getCategoryMetricLabel('comments', metricLang)}</span>
                          </span>
                        </div>
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
