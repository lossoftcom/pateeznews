import { useCallback, useEffect, useRef, useState } from 'react';
import { useStory, useConfig } from '@googleforcreators/story-editor';
import { getStoryMarkup } from '@googleforcreators/output';

// Client-side preview: generates the same self-contained AMP story document the
// editor saves (getStoryMarkup), loads it into a phone-framed iframe via a blob
// URL, and lets the native amp-story runtime drive navigation — i.e. the real
// Google Web Stories player experience, without needing a server preview link.

const PREVIEW_BTN = (disabled) => ({
  flex: '0 0 auto',
  height: '36px',
  padding: '0 16px',
  borderRadius: '6px',
  border: '1px solid #3a3a44',
  background: 'transparent',
  color: disabled ? '#6b6b73' : '#f5f5f7',
  fontSize: '13px',
  fontWeight: 600,
  cursor: disabled ? 'default' : 'pointer',
});

const OVERLAY = {
  position: 'fixed',
  inset: 0,
  zIndex: 2147483600,
  background: 'rgba(10,10,14,0.92)',
  display: 'flex',
  flexDirection: 'column',
  alignItems: 'center',
  justifyContent: 'center',
  gap: '16px',
};

const PHONE = {
  width: 'min(380px, 92vw)',
  height: 'min(675px, 84vh)',
  aspectRatio: '9 / 16',
  borderRadius: '18px',
  overflow: 'hidden',
  background: '#000',
  boxShadow: '0 20px 60px rgba(0,0,0,0.6)',
};

const IFRAME = {
  width: '100%',
  height: '100%',
  border: '0',
  display: 'block',
  background: '#000',
};

const CLOSE_BTN = {
  position: 'fixed',
  top: '18px',
  right: '18px',
  width: '40px',
  height: '40px',
  display: 'inline-flex',
  alignItems: 'center',
  justifyContent: 'center',
  borderRadius: '8px',
  border: '1px solid rgba(255,255,255,0.25)',
  background: 'rgba(0,0,0,0.4)',
  color: '#fff',
  fontSize: '20px',
  lineHeight: 1,
  cursor: 'pointer',
};

const HINT = {
  color: '#c9c9d2',
  fontSize: '13px',
  fontWeight: 500,
};

function PreviewOverlay({ url, onClose }) {
  useEffect(() => {
    const onKey = (e) => {
      if (e.key === 'Escape') onClose();
    };
    window.addEventListener('keydown', onKey);
    return () => window.removeEventListener('keydown', onKey);
  }, [onClose]);

  return (
    <div
      style={OVERLAY}
      role="dialog"
      aria-modal="true"
      aria-label="Hikaye önizlemesi"
      onClick={onClose}
    >
      <button type="button" style={CLOSE_BTN} onClick={onClose} aria-label="Kapat">
        ✕
      </button>
      <div style={PHONE} onClick={(e) => e.stopPropagation()}>
        <iframe title="Hikaye önizlemesi" src={url} style={IFRAME} allow="autoplay" />
      </div>
      <div style={HINT}>Sayfalar arasında geçmek için dokunun · Kapatmak için Esc</div>
    </div>
  );
}

export default function PreviewButton() {
  const { story, pages } = useStory(({ state }) => ({
    story: state.story,
    pages: state.pages,
  }));
  const { metadata, flags } = useConfig();
  const [url, setUrl] = useState(null);
  const urlRef = useRef(null);

  const revoke = useCallback(() => {
    if (urlRef.current) {
      URL.revokeObjectURL(urlRef.current);
      urlRef.current = null;
    }
  }, []);

  const open = useCallback(() => {
    if (!pages || pages.length === 0) return;
    try {
      const markup = getStoryMarkup(story, pages, metadata || {}, flags || {});
      const blob = new Blob([markup], { type: 'text/html' });
      const blobUrl = URL.createObjectURL(blob);
      revoke();
      urlRef.current = blobUrl;
      setUrl(blobUrl);
    } catch (_) {
      /* leave the editor untouched if markup generation fails */
    }
  }, [story, pages, metadata, flags, revoke]);

  const close = useCallback(() => {
    setUrl(null);
    revoke();
  }, [revoke]);

  useEffect(() => () => revoke(), [revoke]);

  const disabled = !pages || pages.length === 0;

  return (
    <>
      <button
        type="button"
        style={PREVIEW_BTN(disabled)}
        onClick={open}
        disabled={disabled}
        title="Önizleme"
      >
        Önizleme
      </button>
      {url && <PreviewOverlay url={url} onClose={close} />}
    </>
  );
}
