import React, { useEffect, useMemo, useState } from 'react';
import { subscribeNewsletter } from '@/services/appActions';
import { ToastProvider, useToast } from '@/context/ToastContext';
import type { SiteSettings } from '@/types';

type ConsentValue = 'granted' | 'denied';

type PrivacyConsent = {
  necessary: true;
  analytics: boolean;
  marketing: boolean;
  preferences: boolean;
  updatedAt: string;
};

type StoredNewsletter = {
  dismissedAt?: number;
  subscribedAt?: number;
};

declare global {
  interface Window {
    __pateezConsent?: PrivacyConsent;
    dataLayer?: unknown[];
    gtag?: (...args: unknown[]) => void;
    uetq?: unknown[];
  }
}

const CONSENT_KEY = 'pateez_privacy_consent_v1';
const NEWSLETTER_KEY = 'pateez_newsletter_modal_v1';
const NEWSLETTER_MODAL_IMAGE = '/images/pateez-newsletter-visual.webp';
const LEGACY_NEWSLETTER_DESCRIPTION =
  'Niğde ve İç Anadolu gündeminden öne çıkanları e-postana taşıyalım.';
const DEFAULT_NEWSLETTER_DESCRIPTION =
  'Pateez.com ile haberleri anında e-postanda gör. Niğde’ye dair ne varsa; doğrulanmış bilgi, gerçek habercilik ve başka yerde kolay bulamayacağın özel içeriklerle sana gelsin.';
const NEWSLETTER_SUCCESS_MESSAGE =
  'Bülten kaydın başarıyla kaydedildi. Pateez.com’un doğrulanmış haber özetleri artık e-postana gelecek.';

const defaultConsent = (granted = false): PrivacyConsent => ({
  necessary: true,
  analytics: granted,
  marketing: granted,
  preferences: granted,
  updatedAt: new Date().toISOString(),
});

const readJson = <T,>(key: string): T | null => {
  try {
    const raw = window.localStorage.getItem(key);
    return raw ? (JSON.parse(raw) as T) : null;
  } catch {
    return null;
  }
};

const writeJson = (key: string, value: unknown) => {
  try {
    window.localStorage.setItem(key, JSON.stringify(value));
  } catch {
    // localStorage can be unavailable in private or restricted browser modes.
  }
};

const consentSignal = (value: boolean): ConsentValue =>
  value ? 'granted' : 'denied';

const applyConsent = (consent: PrivacyConsent) => {
  const gtagConsent = {
    ad_storage: consentSignal(consent.marketing),
    ad_user_data: consentSignal(consent.marketing),
    ad_personalization: consentSignal(consent.marketing),
    analytics_storage: consentSignal(consent.analytics),
    functionality_storage: consentSignal(consent.preferences),
    personalization_storage: consentSignal(consent.preferences),
    security_storage: 'granted' as ConsentValue,
  };

  window.__pateezConsent = consent;
  window.gtag?.('consent', 'update', gtagConsent);
  window.uetq = window.uetq || [];
  window.uetq.push('consent', 'update', {
    ad_storage: consentSignal(consent.marketing),
  });
  window.dispatchEvent(new CustomEvent('pateez:consent', { detail: consent }));
};

const clampNumber = (value: unknown, fallback: number, min: number, max: number) => {
  const parsed = Number(value);
  if (!Number.isFinite(parsed)) return fallback;
  return Math.min(max, Math.max(min, Math.round(parsed)));
};

const validEmail = (value: string) => /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(value);

interface Props {
  siteSettings: SiteSettings | null;
  lang?: string;
}

function PrivacyConsentExperienceContent({ siteSettings, lang = 'tr' }: Props) {
  const { showToast } = useToast();
  const cookieEnabled = siteSettings?.cookie_banner_enabled !== false;
  const preferencesEnabled = siteSettings?.cookie_preferences_enabled !== false;
  const newsletterEnabled = siteSettings?.newsletter_popup_enabled !== false;
  const [bannerOpen, setBannerOpen] = useState(false);
  const [preferencesOpen, setPreferencesOpen] = useState(false);
  const [newsletterOpen, setNewsletterOpen] = useState(false);
  const [analytics, setAnalytics] = useState(true);
  const [marketing, setMarketing] = useState(true);
  const [preferences, setPreferences] = useState(true);
  const [email, setEmail] = useState('');
  const [newsletterLoading, setNewsletterLoading] = useState(false);
  const [newsletterMessage, setNewsletterMessage] = useState('');

  const settings = useMemo(() => ({
    cookieTitle: siteSettings?.cookie_banner_title?.trim() ||
      'Gizliliğinize önem veriyoruz',
    cookieDescription: siteSettings?.cookie_banner_description?.trim() ||
      'Pateez, sitenin güvenli çalışması için zorunlu çerezleri kullanır. Onayınızla ölçüm, reklam ve deneyim iyileştirme çerezleri de etkinleşir.',
    cookiePolicyUrl: siteSettings?.cookie_policy_url?.trim() || '',
    newsletterTitle: siteSettings?.newsletter_popup_title?.trim() ||
      'Pateez bültenine katıl',
    newsletterDescription: (() => {
      const value = siteSettings?.newsletter_popup_description?.trim() || '';
      return value && value !== LEGACY_NEWSLETTER_DESCRIPTION
        ? value
        : DEFAULT_NEWSLETTER_DESCRIPTION;
    })(),
    newsletterButton: siteSettings?.newsletter_popup_button_label?.trim() ||
      'Abone ol',
    newsletterDelay: clampNumber(
      siteSettings?.newsletter_popup_delay_seconds,
      3,
      0,
      60,
    ),
    newsletterFrequencyDays: clampNumber(
      siteSettings?.newsletter_popup_frequency_days,
      14,
      1,
      365,
    ),
    logo: siteSettings?.logo_url?.trim() || '',
  }), [siteSettings]);

  useEffect(() => {
    const stored = readJson<PrivacyConsent>(CONSENT_KEY);
    if (stored?.necessary) {
      setAnalytics(!!stored.analytics);
      setMarketing(!!stored.marketing);
      setPreferences(!!stored.preferences);
      applyConsent(stored);
      return;
    }

    if (cookieEnabled) {
      setBannerOpen(true);
    }
  }, [cookieEnabled]);

  useEffect(() => {
    if (!newsletterEnabled) return;
    const stored = readJson<StoredNewsletter>(NEWSLETTER_KEY);
    const now = Date.now();
    const frequencyMs = settings.newsletterFrequencyDays * 24 * 60 * 60 * 1000;
    const lastSeen = stored?.subscribedAt || stored?.dismissedAt || 0;
    if (lastSeen && now - lastSeen < frequencyMs) return;

    const timer = window.setTimeout(
      () => setNewsletterOpen(true),
      settings.newsletterDelay * 1000,
    );
    return () => window.clearTimeout(timer);
  }, [
    newsletterEnabled,
    settings.newsletterDelay,
    settings.newsletterFrequencyDays,
  ]);

  useEffect(() => {
    document.body.classList.toggle(
      'pateez-newsletter-modal-open',
      newsletterOpen,
    );
    return () => document.body.classList.remove('pateez-newsletter-modal-open');
  }, [newsletterOpen]);

  const saveConsent = (next: PrivacyConsent) => {
    writeJson(CONSENT_KEY, next);
    applyConsent(next);
    setBannerOpen(false);
    setPreferencesOpen(false);
  };

  const acceptAll = () => saveConsent(defaultConsent(true));

  const rejectOptional = () => saveConsent(defaultConsent(false));

  const savePreferences = () => saveConsent({
    necessary: true,
    analytics,
    marketing,
    preferences,
    updatedAt: new Date().toISOString(),
  });

  const dismissNewsletter = (subscribed = false) => {
    writeJson(NEWSLETTER_KEY, subscribed
      ? { subscribedAt: Date.now() }
      : { dismissedAt: Date.now() });
    setNewsletterOpen(false);
  };

  const handleNewsletterSubmit = async (event: React.FormEvent) => {
    event.preventDefault();
    const normalizedEmail = email.trim();
    if (!validEmail(normalizedEmail)) {
      setNewsletterMessage('Geçerli bir e-posta adresi yazın.');
      return;
    }

    setNewsletterLoading(true);
    setNewsletterMessage('');
    try {
      await subscribeNewsletter(normalizedEmail, 'first-open-modal', lang || 'tr');
      showToast(NEWSLETTER_SUCCESS_MESSAGE, 'success');
      setEmail('');
      dismissNewsletter(true);
    } catch {
      setNewsletterMessage('Abonelik kaydedilemedi. Lütfen tekrar deneyin.');
    } finally {
      setNewsletterLoading(false);
    }
  };

  return (
    <>
      {newsletterOpen && (
        <div className="pateez-newsletter-overlay" role="presentation">
          <section
            className="pateez-newsletter-modal"
            role="dialog"
            aria-modal="true"
            aria-labelledby="pateez-newsletter-title"
          >
            <button
              type="button"
              className="pateez-newsletter-close"
              aria-label="Bülteni kapat"
              onClick={() => dismissNewsletter(false)}
            >
              <span className="material-symbols-rounded" aria-hidden="true">close</span>
            </button>
            <div className="pateez-newsletter-visual">
              {settings.logo && (
                <div className="pateez-newsletter-logo" aria-hidden="true">
                  <img src={settings.logo} alt="" loading="eager" decoding="async" />
                </div>
              )}
              <img src={NEWSLETTER_MODAL_IMAGE} alt="" loading="eager" decoding="async" />
              <div className="pateez-newsletter-glow" aria-hidden="true" />
            </div>
            <form className="pateez-newsletter-content" onSubmit={handleNewsletterSubmit}>
              <span className="pateez-newsletter-kicker">Gündem Cebinde</span>
              <h2 id="pateez-newsletter-title">{settings.newsletterTitle}</h2>
              <p>{settings.newsletterDescription}</p>
              <label className="pateez-newsletter-input">
                <span>E-posta adresi</span>
                <input
                  type="email"
                  value={email}
                  onChange={(event) => setEmail(event.target.value)}
                  placeholder="ornek@eposta.com"
                  autoComplete="email"
                />
              </label>
              {newsletterMessage && (
                <p className="pateez-newsletter-message">{newsletterMessage}</p>
              )}
              <button type="submit" disabled={newsletterLoading}>
                {newsletterLoading ? 'Kaydediliyor...' : settings.newsletterButton}
              </button>
            </form>
          </section>
        </div>
      )}

      {bannerOpen && (
        <section
          className="pateez-cookie-banner"
          aria-label="Çerez tercihleri"
        >
          <div className="pateez-cookie-copy">
            <span className="material-symbols-rounded" aria-hidden="true">cookie</span>
            <div>
              <h2>{settings.cookieTitle}</h2>
              <p>
                {settings.cookieDescription}
                {settings.cookiePolicyUrl && (
                  <>
                    {' '}
                    <a href={settings.cookiePolicyUrl}>Detayları oku</a>
                  </>
                )}
              </p>
            </div>
          </div>
          {preferencesOpen && preferencesEnabled && (
            <div className="pateez-cookie-preferences">
              <label>
                <input type="checkbox" checked disabled />
                <span>Zorunlu</span>
              </label>
              <label>
                <input
                  type="checkbox"
                  checked={analytics}
                  onChange={(event) => setAnalytics(event.target.checked)}
                />
                <span>Analitik</span>
              </label>
              <label>
                <input
                  type="checkbox"
                  checked={marketing}
                  onChange={(event) => setMarketing(event.target.checked)}
                />
                <span>Reklam</span>
              </label>
              <label>
                <input
                  type="checkbox"
                  checked={preferences}
                  onChange={(event) => setPreferences(event.target.checked)}
                />
                <span>Deneyim</span>
              </label>
            </div>
          )}
          <div className="pateez-cookie-actions">
            {preferencesEnabled && (
              <button
                type="button"
                className="pateez-cookie-secondary"
                onClick={() => setPreferencesOpen((value) => !value)}
              >
                Tercihler
              </button>
            )}
            <button
              type="button"
              className="pateez-cookie-secondary"
              onClick={rejectOptional}
            >
              Reddet
            </button>
            <button
              type="button"
              className="pateez-cookie-primary"
              onClick={preferencesOpen ? savePreferences : acceptAll}
            >
              {preferencesOpen ? 'Kaydet' : 'Tümünü kabul et'}
            </button>
          </div>
        </section>
      )}
    </>
  );
}

export default function PrivacyConsentExperience(props: Props) {
  return (
    <ToastProvider>
      <PrivacyConsentExperienceContent {...props} />
    </ToastProvider>
  );
}
