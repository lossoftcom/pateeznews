
import React, { createContext, useContext, useEffect, useState, useCallback, useMemo } from 'react';
import { neon } from '@/lib/neon';
import { loadLocaleData } from '@/lib/locales';

interface Language {
  code: string;
  name: string;
  direction: 'ltr' | 'rtl';
  status: string;
  flag_code: string;
  is_default: boolean;
}

interface LanguageContextType {
  currentLang: Language;
  availableLanguages: Language[];
  setLanguage: (code: string) => void;
  t: (key: string) => string;
  loading: boolean;
}

const LanguageContext = createContext<LanguageContextType | undefined>(undefined);

const DEFAULT_LANG: Language = {
  code: 'tr',
  name: 'Türkçe',
  direction: 'ltr',
  status: 'active',
  flag_code: 'tr',
  is_default: true
};

// 2025 Static Fallback (Sıfır Key Görünümü Garanti)
const STATIC_TR: Record<string, string> = {
  "nav.home": "Ana Sayfa",
  "nav.agenda": "Gündem",
  "nav.pateezvideotv": "Video",
  "nav.special": "Eğlence",
  "nav.search": "Haber ara...",
  "nav.login": "Giriş Yap",
  "sidebar.publishers": "Yayıncılar",
  "sidebar.categories": "Kategoriler",
  "feed.title_prefix": "Sizin İçin",
  "feed.title_suffix": "Seçtiklerimiz",
  "feed.latest": "En Yeni",
  "feed.popular": "Popüler",
  "right.weather": "Niğde",
  "right.weather_partly_cloudy": "Parçalı Bulutlu",
  "right.weather_feels_like_26": "Hissedilen: 26°",
};

export const LanguageProvider: React.FC<{
  children: React.ReactNode,
  initialLang?: Language,
  initialTranslations?: Record<string, string>
}> = ({ children, initialLang, initialTranslations }) => {
  const [currentLang, setCurrentLang] = useState<Language>(initialLang || DEFAULT_LANG);
  const [availableLanguages, setAvailableLanguages] = useState<Language[]>([initialLang || DEFAULT_LANG]);
  const [translations, setTranslations] = useState<Record<string, string> | null>(initialTranslations || STATIC_TR);
  const [loading, setLoading] = useState(!initialTranslations);

  // 1. Dili saniyeler içinde belirle (Sync)
  const getInitialLangCode = useCallback(() => {
    const saved = localStorage.getItem('pateez_lang');
    if (saved) return saved;

    const browserLang = navigator.language.split('-')[0];
    return browserLang || DEFAULT_LANG.code;
  }, []);

  const writeLangCookie = useCallback((code: string) => {
    try {
      document.cookie = `pateez_lang=${encodeURIComponent(code)}; path=/; max-age=31536000; SameSite=Lax`;
    } catch {
      // ignore
    }
  }, []);

  // 2. Çevirileri yükle (Paralel)
  const loadTranslations = useCallback(async (lang: Language) => {
    try {
      const data = await loadLocaleData(lang.code);
      if (data && Object.keys(data).length > 0) {
        setTranslations(data);
        document.documentElement.dir = lang.direction;
        document.documentElement.lang = lang.code;
        setCurrentLang(lang);
      }
    } catch (err) {
      console.error('Translation load error:', err);
      setTranslations({}); // Fallback
    }
  }, []);

  useEffect(() => {
    let isMounted = true;
    const init = async () => {
      const matchLang = (code: string, langs: Language[]) => {
        const normalizedCode = String(code || '').trim();
        if (!normalizedCode) return null;

        const lower = normalizedCode.toLowerCase();
        const direct = langs.find((l) => String(l.code || '').trim().toLowerCase() === lower);
        if (direct) return direct;

        const base = lower.split(/[-_]/)[0];
        if (base && base !== lower) {
          return langs.find((l) => String(l.code || '').trim().toLowerCase() === base) || null;
        }

        return null;
      };

      const hasUserLocale = (code: string) => {
        try {
          return !!localStorage.getItem(`pateez_locale_${code}`);
        } catch {
          return false;
        }
      };

      // If we already have initialTranslations, we don't need a full reload during init
      if (initialTranslations && Object.keys(initialTranslations).length > 0) {
        try {
          document.documentElement.dir = initialLang?.direction || DEFAULT_LANG.direction;
          document.documentElement.lang = initialLang?.code || DEFAULT_LANG.code;
        } catch {
          // ignore
        }
        if (isMounted) setLoading(false);
      } else {
        const initialCode = getInitialLangCode();
        const initialLangObj = { ...DEFAULT_LANG, code: initialCode };
        await loadTranslations(initialLangObj);
        if (isMounted) setLoading(false);
      }

      // Arka planda Neon'den güncel dil listesini al (Bloke etme)
      try {
        const { data: dbLangs } = await neon
          .from('languages')
          .select('*')
          .eq('status', 'active');

        if (isMounted && dbLangs && dbLangs.length > 0) {
          const normalized = (dbLangs as any[]).map((l) => ({
            ...l,
            direction: String(l?.direction || '').trim() === 'rtl' ? 'rtl' : 'ltr',
            flag_code: String(l?.flag_code || '').trim() || String(l?.code || '').trim(),
          })) as Language[];

          setAvailableLanguages(normalized);

          const defaultFromDb = normalized.find((l) => l.is_default)?.code || normalized[0]?.code || DEFAULT_LANG.code;
          const desiredCode = getInitialLangCode() || initialLang?.code || defaultFromDb;
          const resolvedLang = matchLang(desiredCode, normalized) || matchLang(defaultFromDb, normalized);

          if (resolvedLang) {
            try {
              localStorage.setItem('pateez_lang', resolvedLang.code);
              writeLangCookie(resolvedLang.code);
              document.documentElement.dir = resolvedLang.direction;
              document.documentElement.lang = resolvedLang.code;
            } catch {
              // ignore
            }

            const shouldLoadUserPack = hasUserLocale(resolvedLang.code);
            const shouldSyncLang = resolvedLang.code !== (initialLang?.code || DEFAULT_LANG.code);
            if (shouldLoadUserPack || shouldSyncLang) {
              await loadTranslations(resolvedLang);
            } else {
              setCurrentLang(resolvedLang);
            }
          }
        }
      } catch (e) {
        console.warn('DB Language list fallback used');
      }
    };

    init();
    return () => { isMounted = false; };
  }, [getInitialLangCode, loadTranslations, initialLang, initialTranslations, writeLangCookie]);

  const setLanguage = async (code: string) => {
    const lang = availableLanguages.find(l => l.code === code) || { ...DEFAULT_LANG, code };
    setLoading(true);
    localStorage.setItem('pateez_lang', code);
    writeLangCookie(code);
    try {
      await loadTranslations(lang as Language);
    } finally {
      setLoading(false);
    }
  };

  const t = useCallback((key: string): string => {
    if (!translations) return STATIC_TR[key] || key;
    return translations[key] || STATIC_TR[key] || key;
  }, [translations]);

  const contextValue = useMemo(() => ({
    currentLang,
    availableLanguages,
    setLanguage,
    t,
    loading: loading && !initialTranslations
  }), [currentLang, availableLanguages, setLanguage, t, loading, initialTranslations]);

  return (
    <LanguageContext.Provider value={contextValue}>
      {children}
    </LanguageContext.Provider>
  );
};

export const useLanguage = () => {
  const context = useContext(LanguageContext);
  if (context === undefined) {
    throw new Error('useLanguage must be used within a LanguageProvider');
  }
  return context;
};
