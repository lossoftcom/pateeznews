import React, { useEffect, useMemo, useRef, useState } from 'react';
import type { PublicAdCreative, PublicAdSettings, PublicAdSlot } from '@/types';

type AdSlotProps = {
  settings?: PublicAdSettings | null;
  slotKey: string;
  className?: string;
};

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
  const totalWeight = creatives.reduce((total, creative) => total + creative.weight, 0);
  if (totalWeight <= 0) return creatives[0] || null;

  const target = hashString(`${slot.key}:${creatives.map((item) => item.id).join('|')}`) % totalWeight;
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

const AdSlot: React.FC<AdSlotProps> = ({ settings, slotKey, className = '' }) => {
  const slot = useMemo(() => (
    settings?.masterEnabled
      ? settings.slots.find((item) => item.key === slotKey) || null
      : null
  ), [settings, slotKey]);
  const creative = useMemo(() => (slot ? pickCreative(slot) : null), [slot]);
  const pushedAdSenseKey = useRef('');
  const adSenseElementRef = useRef<HTMLModElement | null>(null);
  const [isAdSenseCollapsed, setIsAdSenseCollapsed] = useState(false);
  const adSenseKey = slot && creative?.type === 'adsense'
    ? `${slot.key}:${creative.id}:${creative.adsenseSlotId || ''}`
    : '';

  useEffect(() => {
    setIsAdSenseCollapsed(false);
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
      setIsAdSenseCollapsed(true);
    }
  }, [adSenseKey, creative, slot]);

  useEffect(() => {
    if (!adSenseKey) return undefined;
    const element = adSenseElementRef.current;
    if (!element) return undefined;

    const syncAdSenseStatus = () => {
      const adStatus = element.getAttribute('data-ad-status');
      if (adStatus === 'unfilled') {
        setIsAdSenseCollapsed(true);
      } else if (adStatus === 'filled') {
        setIsAdSenseCollapsed(false);
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
        setIsAdSenseCollapsed(true);
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
  const wrapperClass = [
    'pateez-ad-slot flex w-full max-w-full justify-center overflow-hidden',
    className,
  ].filter(Boolean).join(' ');

  if (creative.type === 'image' && creative.imageUrl) {
    const image = (
      <img
        src={creative.imageUrl}
        alt={creative.name || 'Reklam'}
        width={width || undefined}
        height={height || undefined}
        loading="lazy"
        decoding="async"
        className="block h-auto max-h-[620px] max-w-full rounded-[4px] object-contain"
      />
    );

    return (
      <div className={wrapperClass} data-ad-slot={slot.key}>
        {creative.linkUrl ? (
          <a
            href={creative.linkUrl}
            target="_blank"
            rel="sponsored noopener noreferrer"
            className="block max-w-full"
          >
            {image}
          </a>
        ) : image}
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

  if (creative.type === 'adsense' && creative.publisherId && creative.adsenseSlotId) {
    if (isAdSenseCollapsed) return null;

    const responsive = creative.responsive || slot.responsive || !width || !height;
    const style: React.CSSProperties = responsive
      ? { display: 'block', width: '100%' }
      : { display: 'inline-block', width, height, maxWidth: '100%' };

    return (
      <div className={wrapperClass} data-ad-slot={slot.key}>
        <ins
          ref={adSenseElementRef}
          className="adsbygoogle"
          style={style}
          data-ad-client={creative.publisherId}
          data-ad-slot={creative.adsenseSlotId}
          data-ad-format={responsive ? 'auto' : undefined}
          data-full-width-responsive={responsive ? 'true' : undefined}
        />
      </div>
    );
  }

  return null;
};

export default AdSlot;
