import React, { useCallback, useEffect, useMemo, useState } from 'react';
import type { NewsItem } from '@/types';
import RemixIcon from './ui/RemixIcon';

const AUTOPLAY_DELAY = 5000;
const DISPLAY_TIME_ZONE = 'Europe/Istanbul';
const TEXT_ENTITY_MAP: Record<string, string> = {
    amp: '&',
    apos: "'",
    Ccedil: 'Ç',
    ccedil: 'ç',
    Gbreve: 'Ğ',
    gbreve: 'ğ',
    hellip: '...',
    Idot: 'İ',
    imath: 'ı',
    laquo: '"',
    ldquo: '"',
    lsquo: "'",
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

interface MansetSlide {
    id: string;
    title: string;
    description: string;
    image: string;
    alt: string;
    date: string;
}

interface MansetSliderProps {
    slides?: NewsItem[];
    onNewsSelect?: (id: string) => void;
}

const decodeTextEntityCodePoint = (value: string, radix: number, fallback: string) => {
    const codePoint = Number.parseInt(value, radix);
    if (!Number.isFinite(codePoint) || codePoint <= 0) return fallback;
    try {
        return String.fromCodePoint(codePoint);
    } catch {
        return fallback;
    }
};

const decodeTextEntities = (value: string) => {
    const decodeOnce = (input: string) => input
        .replace(/&([a-zA-Z][a-zA-Z0-9]+);/g, (match, entity: string) => TEXT_ENTITY_MAP[entity] ?? match)
        .replace(/&#x([0-9a-fA-F]+);/g, (match, hex: string) => decodeTextEntityCodePoint(hex, 16, match))
        .replace(/&#(\d+);/g, (match, decimal: string) => decodeTextEntityCodePoint(decimal, 10, match));

    return decodeOnce(decodeOnce(value));
};

const stripHtml = (value: string) => (
    decodeTextEntities(
        value
            .replace(/<[^>]*>/g, ' ')
            .replace(/&nbsp;/g, ' ')
            .replace(/\s+/g, ' ')
            .trim()
    )
);

const formatSlideDate = (value: string) => {
    const date = new Date(value);
    if (Number.isNaN(date.getTime())) return value;

    const datePart = date.toLocaleDateString('tr-TR', {
        timeZone: DISPLAY_TIME_ZONE,
        day: 'numeric',
        month: 'long',
        year: 'numeric',
        weekday: 'long',
    });
    const timePart = date.toLocaleTimeString('tr-TR', {
        timeZone: DISPLAY_TIME_ZONE,
        hour: '2-digit',
        minute: '2-digit',
    });

    return `${datePart} Saat: ${timePart}`;
};

const mapNewsToSlide = (news: NewsItem): MansetSlide | null => {
    const image =
        news.mansetImageUrl ||
        news.coverThumbnail ||
        news.thumbnail ||
        news.mediaList?.[0] ||
        news.mediaUrl;
    if (!image) return null;

    const title = stripHtml(news.seoTitle || news.title || '');
    if (!title) return null;

    return {
        id: String(news.id),
        title,
        description: stripHtml(news.summary || news.seoDescription || ''),
        image,
        alt: news.thumbnailAlt || title,
        date: formatSlideDate(news.timestamp || ''),
    };
};

const withLocalImageVariant = (image: string, width: number) => {
    if (!image) return image;
    try {
        const isBrowser = typeof window !== 'undefined';
        const isRelative = image.startsWith('/');
        if (!isBrowser && !isRelative) return image;
        const base = isBrowser ? window.location.origin : 'https://pateez.local';
        const url = new URL(image, base);
        if (isBrowser && url.origin !== window.location.origin) return image;
        if (!url.pathname.startsWith('/api/storage/file/') && !url.pathname.startsWith('/local-upload/')) {
            return image;
        }
        url.searchParams.set('w', String(width));
        url.searchParams.set('q', '86');
        return isRelative ? `${url.pathname}${url.search}${url.hash}` : url.toString();
    } catch {
        return image;
    }
};

const MansetSlider: React.FC<MansetSliderProps> = ({ slides: newsSlides = [], onNewsSelect }) => {
    const slides = useMemo(() => newsSlides.map(mapNewsToSlide).filter(Boolean) as MansetSlide[], [newsSlides]);
    const [activeIndex, setActiveIndex] = useState(0);
    const [isPaused, setIsPaused] = useState(false);

    useEffect(() => {
        if (activeIndex >= slides.length) {
            setActiveIndex(0);
        }
    }, [activeIndex, slides.length]);

    const goToSlide = useCallback((index: number) => {
        if (slides.length === 0) return;
        setActiveIndex((index + slides.length) % slides.length);
    }, [slides.length]);

    const goToPrevious = useCallback(() => {
        if (slides.length === 0) return;
        setActiveIndex((current) => (current - 1 + slides.length) % slides.length);
    }, [slides.length]);

    const goToNext = useCallback(() => {
        if (slides.length === 0) return;
        setActiveIndex((current) => (current + 1) % slides.length);
    }, [slides.length]);

    useEffect(() => {
        if (isPaused || slides.length < 2) return undefined;

        const timer = window.setInterval(goToNext, AUTOPLAY_DELAY);
        return () => window.clearInterval(timer);
    }, [goToNext, isPaused, slides.length]);

    if (slides.length === 0) return null;

    return (
        <section
            className="manset-slider w-full relative rounded-[5px] overflow-hidden shadow-sm bg-gray-900 group cursor-pointer"
            onMouseEnter={() => setIsPaused(true)}
            onMouseLeave={() => setIsPaused(false)}
            aria-label="Manşet haber sliderı"
        >
            <div className="relative w-full aspect-square">
                {slides.map((slide, index) => {
                    const isActive = index === activeIndex;

                    return (
                        <article
                            key={slide.id}
                            aria-hidden={!isActive}
                            onClick={() => onNewsSelect?.(slide.id)}
                            className={`absolute inset-0 overflow-hidden transition-opacity duration-700 ease-out ${
                                isActive ? 'opacity-100 z-10' : 'opacity-0 z-0 pointer-events-none'
                            }`}
                        >
                            <img
                                src={withLocalImageVariant(slide.image, index === 0 ? 1600 : 1200)}
                                alt={slide.alt}
                                loading={index === 0 ? 'eager' : 'lazy'}
                                decoding="async"
                                fetchPriority={index === 0 ? 'high' : 'low'}
                                className="w-full h-full object-contain bg-gray-950"
                            />
                            <div className="absolute inset-0 bg-gradient-to-t from-black/90 via-black/25 to-transparent opacity-85 transition-opacity duration-500 group-hover:opacity-95" />
                            <div className="absolute bottom-0 left-0 w-full px-6 sm:px-8 md:px-10 pt-6 sm:pt-8 md:pt-10 pb-5 sm:pb-6 md:pb-7 z-10 flex flex-col justify-end transform transition-transform duration-500 translate-y-1 group-hover:translate-y-0">
                                <h2 className="news-title-font text-white text-[23px] sm:text-[30px] md:text-[36px] font-[800] tracking-normal leading-[1.08] mb-2.5 drop-shadow-lg line-clamp-3 transition-colors duration-300 group-hover:text-palette-red">
                                    {slide.title}
                                </h2>
                                {slide.description && (
                                    <p className="news-subtitle-font text-gray-200 text-[14px] sm:text-[16px] line-clamp-3 max-w-4xl font-medium leading-snug drop-shadow-md mb-3.5">
                                        {slide.description}
                                    </p>
                                )}
                                {slide.date && (
                                    <div className="flex items-center mb-0">
                                        <span className="text-gray-400 text-xs font-light flex items-center gap-1.5 drop-shadow-md">
                                            <RemixIcon name="ri-time-line" size={14} className="opacity-70" />
                                            {slide.date}
                                        </span>
                                    </div>
                                )}
                            </div>
                        </article>
                    );
                })}

                {slides.length > 1 && (
                    <>
                        <button
                            type="button"
                            aria-label="Önceki manşet"
                            onClick={goToPrevious}
                            className="manset-nav-button manset-prev absolute top-[24%] md:top-[38%] left-3 md:left-5 -translate-y-1/2 z-30 w-12 h-12 md:w-14 md:h-14 appearance-none border-0 bg-transparent flex items-center justify-center overflow-visible text-white/90 cursor-pointer outline-none focus:outline-none focus-visible:ring-2 focus-visible:ring-white/70 transition-all duration-300 hover:text-white hover:scale-105 active:scale-95"
                        >
                            <RemixIcon name="ri-arrow-left-s-line" className="manset-arrow-icon opacity-0 group-hover:opacity-100 group-focus-within:opacity-100 pointer-events-none" />
                        </button>

                        <button
                            type="button"
                            aria-label="Sonraki manşet"
                            onClick={goToNext}
                            className="manset-nav-button manset-next absolute top-[24%] md:top-[38%] right-3 md:right-5 -translate-y-1/2 z-30 w-12 h-12 md:w-14 md:h-14 appearance-none border-0 bg-transparent flex items-center justify-center overflow-visible text-white/90 cursor-pointer outline-none focus:outline-none focus-visible:ring-2 focus-visible:ring-white/70 transition-all duration-300 hover:text-white hover:scale-105 active:scale-95"
                        >
                            <RemixIcon name="ri-arrow-right-s-line" className="manset-arrow-icon opacity-0 group-hover:opacity-100 group-focus-within:opacity-100 pointer-events-none" />
                        </button>
                    </>
                )}

                <div className="absolute left-1/2 bottom-4 z-30 -translate-x-1/2 flex items-center justify-center gap-[5px] whitespace-nowrap">
                    {slides.map((slide, index) => {
                        const isActive = index === activeIndex;

                        return (
                            <button
                                key={slide.id}
                                type="button"
                                aria-label={`Manşet ${index + 1}`}
                                aria-current={isActive ? 'true' : undefined}
                                onClick={() => goToSlide(index)}
                                className={`h-[9px] rounded-full border-0 p-0 outline-none cursor-pointer transition-all duration-300 ${
                                    isActive
                                        ? 'w-7 bg-palette-red shadow-none'
                                        : 'w-[9px] bg-white/80 shadow-none hover:bg-palette-red/80'
                                }`}
                            />
                        );
                    })}
                </div>
            </div>

            <style>{`
                .manset-slider .manset-arrow-icon {
                    width: 42px;
                    height: 42px;
                    filter: none;
                    transition: opacity 0.25s ease, width 0.25s ease, height 0.25s ease, transform 0.25s ease;
                }

                .manset-slider .manset-nav-button:hover .manset-arrow-icon {
                    transform: scale(1.08);
                }

                @media (min-width: 768px) {
                    .manset-slider .manset-arrow-icon {
                        width: 52px;
                        height: 52px;
                    }
                }
            `}</style>
        </section>
    );
};

export default MansetSlider;
