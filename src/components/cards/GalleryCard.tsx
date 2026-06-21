
import React, { useCallback, useState, useEffect, useRef } from 'react';
import { ChevronLeft, ChevronRight } from 'lucide-react';
import { NewsType, type NewsItem } from '@/types';

interface GalleryCardProps {
  data: NewsItem;
  fitMode?: 'bounded' | 'fluidWidth';
}

const GalleryCard: React.FC<GalleryCardProps> = ({ data, fitMode = 'bounded' }) => {
  const [currentSlide, setCurrentSlide] = useState(0);
  const [maxHeight, setMaxHeight] = useState<number>(0);
  const containerRef = useRef<HTMLDivElement>(null);
  const swipeStartRef = useRef<{ x: number; y: number; pointerId: number } | null>(null);
  const ignoreClickRef = useRef(false);
  const slideCount = data.mediaList?.length || 0;
  const isFluidWidth = fitMode === 'fluidWidth';

  // Tüm resimlerin boyutlarını yükle ve en yüksek olanı bul
  useEffect(() => {
    if (isFluidWidth) {
      setMaxHeight(0);
      return;
    }
    if (!data.mediaList || data.mediaList.length === 0) return;

    const loadImageDimensions = async () => {
      const containerWidth = containerRef.current?.offsetWidth || 800;

      const heights = await Promise.all(
        data.mediaList!.map((src) => {
          return new Promise<number>((resolve) => {
            const img = new Image();
            img.onload = () => {
              // Sadece yatay ve kare resimler hesaplamaya dahil (dikey resimler hariç)
              // Dikey resim: yükseklik > genişlik
              if (img.naturalHeight > img.naturalWidth) {
                resolve(0); // Dikey resim - hesaplamaya dahil etme
              } else {
                // Yatay veya kare resim - container genişliğine göre yüksekliği hesapla
                const scale = containerWidth / img.naturalWidth;
                const scaledHeight = img.naturalHeight * scale;
                resolve(scaledHeight);
              }
            };
            img.onerror = () => resolve(0);
            img.src = src;
          });
        })
      );

      const max = Math.max(...heights);
      if (max > 0) {
        setMaxHeight(max);
      }
    };

    loadImageDimensions();

    // Window resize'da yeniden hesapla
    const handleResize = () => loadImageDimensions();
    window.addEventListener('resize', handleResize);
    return () => window.removeEventListener('resize', handleResize);
  }, [data.mediaList, isFluidWidth]);

  // Otomatik slider geçişi (4 saniye aralıkla)
  useEffect(() => {
    if (slideCount <= 1) return;

    const interval = setInterval(() => {
      setCurrentSlide((prev) => (prev + 1) % data.mediaList!.length);
    }, 4000);

    return () => clearInterval(interval);
  }, [data.mediaList, slideCount]);

  const goToNextSlide = useCallback(() => {
    if (data.mediaList) {
      setCurrentSlide((prev) => (prev + 1) % data.mediaList!.length);
    }
  }, [data.mediaList]);

  const goToPreviousSlide = useCallback(() => {
    if (data.mediaList) {
      setCurrentSlide((prev) => (prev - 1 + data.mediaList!.length) % data.mediaList!.length);
    }
  }, [data.mediaList]);

  const nextSlide = (e: React.MouseEvent) => {
    e.stopPropagation();
    goToNextSlide();
  };

  const prevSlide = (e: React.MouseEvent) => {
    e.stopPropagation();
    goToPreviousSlide();
  };

  const resetSwipeClickGuard = () => {
    window.setTimeout(() => {
      ignoreClickRef.current = false;
    }, 250);
  };

  const handlePointerDown = (event: React.PointerEvent<HTMLDivElement>) => {
    if (slideCount <= 1 || event.pointerType === 'mouse') return;
    swipeStartRef.current = {
      x: event.clientX,
      y: event.clientY,
      pointerId: event.pointerId,
    };
    ignoreClickRef.current = false;
    event.currentTarget.setPointerCapture?.(event.pointerId);
  };

  const handlePointerUp = (event: React.PointerEvent<HTMLDivElement>) => {
    const start = swipeStartRef.current;
    if (!start) return;
    swipeStartRef.current = null;

    const deltaX = event.clientX - start.x;
    const deltaY = event.clientY - start.y;
    if (Math.abs(deltaX) < 38 || Math.abs(deltaX) < Math.abs(deltaY) * 1.15) return;

    event.preventDefault();
    event.stopPropagation();
    ignoreClickRef.current = true;
    if (deltaX < 0) {
      goToNextSlide();
    } else {
      goToPreviousSlide();
    }
    resetSwipeClickGuard();
  };

  const handlePointerCancel = () => {
    swipeStartRef.current = null;
  };

  const handleContainerClick = (event: React.MouseEvent<HTMLDivElement>) => {
    if (ignoreClickRef.current) {
      event.preventDefault();
      event.stopPropagation();
      return;
    }

    const card = event.currentTarget.closest('.public-news-card');
    const link = card?.querySelector<HTMLAnchorElement>('a[aria-label]');
    if (!link) return;
    event.preventDefault();
    event.stopPropagation();
    link.click();
  };

  if (!data.mediaList || data.mediaList.length === 0) return null;

  return (
    <div className="mt-1 space-y-3 overflow-hidden">
      <div className="px-1 mb-3">
        <div
          className="news-subtitle-font rich-text-content text-gray-600/80 text-[16px] leading-relaxed font-medium text-left [&>p]:mb-0"
          dangerouslySetInnerHTML={{ __html: data.summary }}
        />
      </div>

      <div
        ref={containerRef}
        onPointerDown={handlePointerDown}
        onPointerUp={handlePointerUp}
        onPointerCancel={handlePointerCancel}
        onClick={handleContainerClick}
        className="gallery-interact-area relative w-full overflow-hidden group select-none flex items-center justify-center"
        style={{ height: !isFluidWidth && maxHeight > 0 ? `${maxHeight}px` : 'auto' }}
      >
        <img
          src={data.mediaList[currentSlide]}
          alt={`Slide ${currentSlide}`}
          draggable={false}
          className={isFluidWidth
            ? 'block w-full h-auto max-w-full object-contain transition-all duration-500'
            : 'max-w-full max-h-full object-contain transition-all duration-500'}
        />
        <button
          onClick={prevSlide}
          className="absolute left-3 top-1/2 -translate-y-1/2 z-20 w-8 h-8 bg-white/10 hover:bg-white/25 border border-white/20 rounded-full flex items-center justify-center text-black transition-all hover:scale-110"
        >
          <ChevronLeft size={18} />
        </button>
        <button
          onClick={nextSlide}
          className="absolute right-3 top-1/2 -translate-y-1/2 z-20 w-8 h-8 bg-white/10 hover:bg-white/25 border border-white/20 rounded-full flex items-center justify-center text-black transition-all hover:scale-110"
        >
          <ChevronRight size={18} />
        </button>

        <div className="absolute top-4 right-4 z-20">
          <div className="bg-black/40 backdrop-blur-md px-3 py-1.5 rounded-[5px] border border-white/10">
            <span className="text-xs font-bold text-white tracking-widest">
              {currentSlide + 1} <span className="text-white/50">/</span> {data.mediaList.length}
            </span>
          </div>
        </div>
        <div className="absolute bottom-4 left-0 right-0 z-20 flex justify-center gap-2">
          {data.mediaList.map((_, idx) => (
            <button
              key={idx}
              onClick={(e) => { e.stopPropagation(); setCurrentSlide(idx); }}
              className={`h-1.5 rounded-[5px] transition-all duration-300 ${currentSlide === idx ? 'w-6 bg-palette-red' : 'w-1.5 bg-white/40 hover:bg-palette-red/60'
                }`}
            />
          ))}
        </div>
      </div>
    </div>
  );
};

export default GalleryCard;
