
import React, { useState, useEffect, useRef } from 'react';
import { RotateCw } from 'lucide-react';
import { NewsType, type NewsItem } from '@/types';
import { useLanguage } from '@/context/LanguageContext';

interface FlipCardProps {
  data: NewsItem;
}

const FlipCard: React.FC<FlipCardProps> = ({ data }) => {
  const { t } = useLanguage();
  const [isFlipped, setIsFlipped] = useState(false);
  const [cardHeight, setCardHeight] = useState<number>(0);
  const [isReady, setIsReady] = useState(false);
  const containerRef = useRef<HTMLDivElement>(null);

  useEffect(() => {
    if (!data.flipData) return;

    const img1 = new Image();

    const getOptimalHeight = (width: number, imgH: number, imgW: number) => {
      const ratio = imgH / imgW;
      if (ratio > 1.05) { // Dikey
        return 450;
      } else if (ratio >= 0.95 && ratio <= 1.05) { // Kare
        return width;
      } else { // Yatay
        return width * ratio;
      }
    };

    img1.onload = () => {
      const containerWidth = containerRef.current?.offsetWidth || 600;
      setCardHeight(getOptimalHeight(containerWidth, img1.naturalHeight, img1.naturalWidth));
      setIsReady(true);
    };

    img1.src = data.flipData.frontImage;

    // Arka yüz resmini de önceden yükle (ama bekleme)
    const img2 = new Image();
    img2.src = data.flipData.backImage;

    const handleResize = () => {
      if (img1.complete) {
        const containerWidth = containerRef.current?.offsetWidth || 600;
        setCardHeight(getOptimalHeight(containerWidth, img1.naturalHeight, img1.naturalWidth));
      }
    };

    window.addEventListener('resize', handleResize);
    return () => window.removeEventListener('resize', handleResize);
  }, [data.flipData]);

  if (!data.flipData) return null;

  return (
    <div className="mt-1 space-y-3 overflow-hidden">
      <div className="px-1 mb-3">
        <div
          className="rich-text-content text-gray-600/80 text-[16px] leading-relaxed font-medium text-left [&>p]:mb-0"
          dangerouslySetInnerHTML={{ __html: data.summary }}
        />
      </div>

      {/* Card Container with Perspective */}
      <div
        ref={containerRef}
        className="card-interact-area w-full cursor-pointer group perspective-1000 relative"
        onClick={(e) => {
          e.preventDefault();
          e.stopPropagation();
          setIsFlipped(!isFlipped);
        }}
        style={{
          perspective: '1000px',
          height: isReady ? `${cardHeight}px` : '0px',
          opacity: isReady ? 1 : 0,
          overflow: 'hidden',
        }}
      >
        {/* Inner Flipper Container */}
        <div
          className="relative w-full h-full transition-transform duration-700 ease-in-out transform-style-3d overflow-visible"
          style={{
            transformStyle: 'preserve-3d',
            transform: isFlipped ? 'rotateY(180deg)' : 'rotateY(0deg)'
          }}
        >

          {/* FRONT FACE */}
          <div
            className="absolute inset-0 w-full h-full backface-hidden flex items-center justify-center overflow-hidden"
            style={{ backfaceVisibility: 'hidden' }}
          >
            {/* Creative Blurred Background Layer */}
            <div className="absolute inset-0 z-0 pointer-events-none">
              <img
                src={data.flipData.frontImage}
                alt=""
                className="w-full h-full object-cover blur-[60px] opacity-40 scale-110"
              />
              <div className="absolute inset-0 bg-white/10" />
            </div>

            <div className="absolute inset-0 bg-gradient-to-t from-black/90 via-black/20 to-transparent z-[1] pointer-events-none" />
            <img src={data.flipData.frontImage?.replace('_sm', '_xl')} alt={t('flip_card.alt_front')} className="w-full h-full object-contain relative z-[2]" />

            {/* Front Content */}
            <div className="absolute bottom-0 left-0 w-full p-8 text-white z-10">
              <div className="flex items-center gap-2 mb-3">
                <span className="bg-blue-600/90 backdrop-blur-md px-3 py-1 rounded-[5px] text-[10px] font-black uppercase tracking-widest shadow-lg border border-white/20">
                  {t('flip_card.tap_flip')}
                </span>
              </div>
              {data.flipData.frontLink ? (
                <a
                  href={data.flipData.frontLink}
                  target="_blank"
                  rel="noopener noreferrer"
                  onClick={(e) => e.stopPropagation()}
                  className="block hover:opacity-80 transition-opacity"
                >
                  <h3 className="text-3xl font-black leading-tight mb-2 drop-shadow-md">{data.flipData.frontTitle}</h3>
                </a>
              ) : (
                <h3 className="text-3xl font-black leading-tight mb-2 drop-shadow-md">{data.flipData.frontTitle}</h3>
              )}
              {data.flipData.frontDescription && (
                <div
                  className="text-white/90 text-sm leading-relaxed mb-5 line-clamp-2 font-medium"
                  dangerouslySetInnerHTML={{ __html: data.flipData.frontDescription }}
                />
              )}
              <div className="flex items-center gap-2.5 text-white/70 text-[10px] font-bold uppercase tracking-widest">
                <div className="p-1.5 rounded-full bg-white/10 backdrop-blur-md border border-white/20">
                  <RotateCw size={12} className="animate-spin-slow" />
                </div>
                <span>{t('flip_card.tap_for_back')}</span>
              </div>
            </div>

            <div className="absolute top-5 right-5 bg-black/30 backdrop-blur-md p-2.5 rounded-full border border-white/20 z-10 shadow-lg group-hover:scale-110 transition-transform">
              <RotateCw size={18} className="text-white" />
            </div>
          </div>

          {/* BACK FACE */}
          <div
            className="absolute inset-0 w-full h-full backface-hidden flex items-center justify-center overflow-hidden"
            style={{
              backfaceVisibility: 'hidden',
              transform: 'rotateY(180deg)'
            }}
          >
            {/* Creative Blurred Background Layer */}
            <div className="absolute inset-0 z-0 pointer-events-none">
              <img
                src={data.flipData.backImage}
                alt=""
                className="w-full h-full object-cover blur-[60px] opacity-40 scale-110"
              />
              <div className="absolute inset-0 bg-white/10" />
            </div>

            <div className="absolute inset-0 bg-gradient-to-t from-black/90 via-black/20 to-transparent z-[1] pointer-events-none" />
            <img src={data.flipData.backImage?.replace('_sm', '_xl')} alt={t('flip_card.alt_back')} className="w-full h-full object-contain relative z-[2]" />

            {/* Back Content - Matches Front layout */}
            <div className="absolute bottom-0 left-0 w-full p-8 text-white z-10">
              <div className="flex items-center gap-2 mb-3">
                <span className="bg-emerald-600/90 backdrop-blur-md px-3 py-1 rounded-[5px] text-[10px] font-black uppercase tracking-widest shadow-lg border border-white/20">
                  {t('flip_card.back_badge')}
                </span>
              </div>
              {data.flipData.backLink ? (
                <a
                  href={data.flipData.backLink}
                  target="_blank"
                  rel="noopener noreferrer"
                  onClick={(e) => e.stopPropagation()}
                  className="block hover:opacity-80 transition-opacity"
                >
                  <h3 className="text-3xl font-black leading-tight mb-2 drop-shadow-md">{data.flipData.backTitle}</h3>
                </a>
              ) : (
                <h3 className="text-3xl font-black leading-tight mb-2 drop-shadow-md">{data.flipData.backTitle}</h3>
              )}
              {data.flipData.backDescription && (
                <div
                  className="text-white/90 text-sm leading-relaxed mb-5 line-clamp-2 font-medium"
                  dangerouslySetInnerHTML={{ __html: data.flipData.backDescription }}
                />
              )}
              <div className="flex items-center gap-2.5 text-white/70 text-[10px] font-bold uppercase tracking-widest">
                <div className="p-1.5 rounded-full bg-white/10 backdrop-blur-md border border-white/20">
                  <RotateCw size={12} className="animate-spin-slow" />
                </div>
                <span>{t('flip_card.tap_for_front')}</span>
              </div>
            </div>

            <div className="absolute top-5 right-5 bg-black/30 backdrop-blur-md p-2.5 rounded-full border border-white/20 z-10 shadow-lg group-hover:scale-110 transition-transform">
              <RotateCw size={18} className="text-white" />
            </div>
          </div>

        </div>
      </div>
    </div>
  );
};

export default FlipCard;
