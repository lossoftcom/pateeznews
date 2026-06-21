import React, { useEffect, useMemo, useState } from 'react';
import type { PublicAdSettings } from '@/types';
import RemixIcon from '@/components/ui/RemixIcon';
import AdSlot from './AdSlot';

type MobileAnchorAdProps = {
  adSettings?: PublicAdSettings | null;
};

const MOBILE_ANCHOR_SLOT_KEY = 'mobile_anchor';

const MobileAnchorAd: React.FC<MobileAnchorAdProps> = ({ adSettings }) => {
  const [mounted, setMounted] = useState(false);
  const [dismissed, setDismissed] = useState(false);
  const slot = useMemo(
    () =>
      adSettings?.masterEnabled
        ? adSettings.slots.find((item) => item.key === MOBILE_ANCHOR_SLOT_KEY) || null
        : null,
    [adSettings],
  );

  useEffect(() => {
    setMounted(true);
  }, []);

  if (!mounted || dismissed || !slot || slot.creatives.length === 0) return null;

  return (
    <div className="mobile-anchor-ad-dock" data-mobile-anchor-ad>
      <div className="mobile-anchor-ad-dock__frame">
        <AdSlot
          settings={adSettings}
          slotKey={MOBILE_ANCHOR_SLOT_KEY}
          className="mobile-anchor-ad-dock__slot"
        />
        <button
          type="button"
          className="mobile-anchor-ad-dock__close"
          onClick={() => setDismissed(true)}
          aria-label="Reklamı kapat"
        >
          <RemixIcon name="ri-close-line" size={14} />
        </button>
      </div>
    </div>
  );
};

export default MobileAnchorAd;
