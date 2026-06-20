import React, { useEffect, useMemo, useRef, useState } from 'react';
import type { PublicAdCreative, PublicAdSettings, PublicAdSlot } from '@/types';

type AdSlotProps = {
  settings?: PublicAdSettings | null;
  slotKey: string;
  className?: string;
};

type AdSenseStatus = 'pending' | 'filled' | 'unfilled';

declare global {
  interface Window {
    adsbygoogle?: unknown[];
  }
}

const hashString = (value: string) => {
  let hash = 0;
  for (let index = 0; index < value.length; index += 1) {
    hash = (hash * 31 + value.charCodeAt(index)) >>> 0;
  }
  return hash;
};

const pickCreative = (slot: PublicAdSlot): PublicAdCreative | null => {
  const creatives = slot.creatives.filter((creative) => creative.weight > 0);
  if (creatives.length === 0) return null;
  const totalWeight = creatives.reduce(
    (total, creative) => total + creative.weight,
    0,
  );
  if (totalWeight <= 0) return creatives[0] || null;

  const target =
    hashString(`${slot.key}:${creatives.map((item) => item.id).join('|')}`) %
    totalWeight;
  let cursor = 0;
  for (const creative of creatives) {
    cursor += creative.weight;
    if (target < cursor) return creative;
  }
  return creatives[0] || null;
};

const cleanDimension = (value: number | undefined, fallback = 0) => {
  const numeric = Number(value || fallback);
  return Number.isFinite(numeric) && numeric > 0 ? Math.round(numeric) : 0;
};

const ADSENSE_PENDING_COLLAPSE_MS = 12_000;

const fallbackSlotKeys: Record<string, string> = {
  web_home_below_hero: 'web_home_top',
  web_article_sidebar: 'web_profile_sidebar',
  web_home_sidebar: 'web_profile_sidebar',
};

const firstImageCreative = (slot?: PublicAdSlot | null) =>
  slot?.creatives.find(
    (creative) => creative.type === 'image' && Boolean(creative.imageUrl),
  ) || null;

const AdSlot: React.FC<AdSlotProps> = ({
  settings,
  slotKey,
  className = '',
}) => {
  const slot = useMemo(
    () =>
      settings?.masterEnabled
        ? settings.slots.find((item) => item.key === slotKey) || null
        : null,
    [settings, slotKey],
  );
  const creative = useMemo(() => (slot ? pickCreative(slot) : null), [slot]);
  const fallbackCreative = useMemo(() => {
    if (!settings?.masterEnabled || !slot) return null;
    const localCreative = firstImageCreative(slot);
    if (localCreative) return localCreative;
    const fallbackSlotKey = fallbackSlotKeys[slot.key];
    if (!fallbackSlotKey) return null;
    return firstImageCreative(
      settings.slots.find((item) => item.key === fallbackSlotKey),
    );
  }, [settings, slot]);
  const pushedAdSenseKey = useRef('');
  const adSenseElementRef = useRef<HTMLModElement | null>(null);
  const [adSenseStatus, setAdSenseStatus] = useState<AdSenseStatus>('pending');
  const adSenseKey =
    slot && creative?.type === 'adsense'
      ? `${slot.key}:${creative.id}:${creative.adsenseSlotId || ''}`
      : '';

  useEffect(() => {
    setAdSenseStatus('pending');
  }, [adSenseKey]);

  useEffect(() => {
    if (!slot || !creative || creative.type !== 'adsense') return;
    if (pushedAdSenseKey.current === adSenseKey) return;
    pushedAdSenseKey.current = adSenseKey;
    try {
      window.adsbygoogle = window.adsbygoogle || [];
      window.adsbygoogle.push({});
    } catch {
      // Ad blockers or delayed AdSense loading should never break the page.
      setAdSenseStatus('unfilled');
    }
  }, [adSenseKey, creative, slot]);

  useEffect(() => {
    if (!adSenseKey) return undefined;
    const element = adSenseElementRef.current;
    if (!element) return undefined;

    const syncAdSenseStatus = () => {
      const adStatus = element.getAttribute('data-ad-status');
      if (adStatus === 'unfilled') {
        setAdSenseStatus('unfilled');
      } else if (adStatus === 'filled') {
        setAdSenseStatus('filled');
      }
    };

    syncAdSenseStatus();

    const observer = new MutationObserver(syncAdSenseStatus);
    observer.observe(element, {
      attributes: true,
      attributeFilter: ['data-ad-status', 'data-adsbygoogle-status', 'style'],
      childList: true,
    });

    const pendingTimer = window.setTimeout(() => {
      const adStatus = element.getAttribute('data-ad-status');
      const googleStatus = element.getAttribute('data-adsbygoogle-status');
      if (!adStatus && !googleStatus && element.childElementCount === 0) {
        setAdSenseStatus('unfilled');
      }
    }, ADSENSE_PENDING_COLLAPSE_MS);

    return () => {
      observer.disconnect();
      window.clearTimeout(pendingTimer);
    };
  }, [adSenseKey]);

  if (!slot || !creative) return null;

  const width = cleanDimension(creative.width, slot.width);
  const height = cleanDimension(creative.height, slot.height);
  const fallbackWidth = cleanDimension(fallbackCreative?.width, slot.width);
  const fallbackHeight = cleanDimension(fallbackCreative?.height, slot.height);
  const wrapperClass = [
    'pateez-ad-slot flex w-full max-w-full justify-center overflow-hidden',
    className,
  ]
    .filter(Boolean)
    .join(' ');

  const renderImageCreative = (
    imageCreative: PublicAdCreative,
    imageWidth: number,
    imageHeight: number,
    imageClassName = 'block h-auto max-h-[620px] max-w-full rounded-[4px] object-contain',
  ) => {
    const image = (
      <img
        src={imageCreative.imageUrl}
        alt={imageCreative.name || 'Reklam'}
        width={imageWidth || undefined}
        height={imageHeight || undefined}
        loading="lazy"
        decoding="async"
        className={imageClassName}
      />
    );

    return imageCreative.linkUrl ? (
      <a
        href={imageCreative.linkUrl}
        target="_blank"
        rel="sponsored noopener noreferrer"
        className="block max-w-full"
      >
        {image}
      </a>
    ) : (
      image
    );
  };

  if (creative.type === 'image' && creative.imageUrl) {
    return (
      <div className={wrapperClass} data-ad-slot={slot.key}>
        {renderImageCreative(creative, width, height)}
      </div>
    );
  }

  if (creative.type === 'html' && creative.htmlCode) {
    return (
      <div
        className={wrapperClass}
        data-ad-slot={slot.key}
        dangerouslySetInnerHTML={{ __html: creative.htmlCode }}
      />
    );
  }

  if (
    creative.type === 'adsense' &&
    creative.publisherId &&
    creative.adsenseSlotId
  ) {
    if (adSenseStatus === 'unfilled') {
      return fallbackCreative ? (
        <div className={wrapperClass} data-ad-slot={slot.key}>
          {renderImageCreative(fallbackCreative, fallbackWidth, fallbackHeight)}
        </div>
      ) : null;
    }

    const responsive =
      creative.responsive || slot.responsive || !width || !height;
    const frameWidth = width || fallbackWidth;
    const frameHeight = height || fallbackHeight;
    const hasFallbackFrame = Boolean(
      fallbackCreative && frameWidth && frameHeight,
    );
    const frameStyle: React.CSSProperties | undefined = hasFallbackFrame
      ? {
          width: '100%',
          maxWidth: frameWidth,
          aspectRatio: `${frameWidth} / ${frameHeight}`,
          overflow: 'hidden',
        }
      : frameHeight
        ? { minHeight: frameHeight }
        : undefined;
    const style: React.CSSProperties = hasFallbackFrame
      ? { display: 'block', width: '100%', height: '100%' }
      : responsive
        ? {
            display: 'block',
            width: '100%',
            height: hasFallbackFrame ? '100%' : undefined,
          }
        : { display: 'inline-block', width, height, maxWidth: '100%' };

    return (
      <div className={wrapperClass} data-ad-slot={slot.key}>
        <div
          className={hasFallbackFrame ? 'relative max-w-full' : 'max-w-full'}
          style={frameStyle}
        >
          {fallbackCreative && adSenseStatus !== 'filled' && (
            <div
              className={
                hasFallbackFrame
                  ? 'absolute inset-0 flex items-center justify-center'
                  : undefined
              }
            >
              {renderImageCreative(
                fallbackCreative,
                fallbackWidth,
                fallbackHeight,
                hasFallbackFrame
                  ? 'block h-full w-full rounded-[4px] object-contain'
                  : 'block h-auto max-h-[620px] max-w-full rounded-[4px] object-contain',
              )}
            </div>
          )}
          <ins
            ref={adSenseElementRef}
            className="adsbygoogle"
            style={{
              ...style,
              ...(hasFallbackFrame
                ? {
                    position: 'absolute',
                    inset: 0,
                    opacity: adSenseStatus === 'filled' ? 1 : 0,
                    pointerEvents: adSenseStatus === 'filled' ? 'auto' : 'none',
                  }
                : {}),
            }}
            data-ad-client={creative.publisherId}
            data-ad-slot={creative.adsenseSlotId}
            data-ad-format={responsive ? 'auto' : undefined}
            data-full-width-responsive={responsive ? 'true' : undefined}
          />
        </div>
      </div>
    );
  }

  return null;
};

export default AdSlot;
