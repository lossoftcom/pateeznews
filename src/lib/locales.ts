const flattenTranslations = (input: any, prefix = '', out: Record<string, string> = {}) => {
  if (!input || typeof input !== 'object') return out;

  for (const [key, value] of Object.entries(input)) {
    const nextKey = prefix ? `${prefix}.${key}` : key;

    if (value && typeof value === 'object' && !Array.isArray(value)) {
      flattenTranslations(value, nextKey, out);
      continue;
    }

    if (typeof value === 'string') out[nextKey] = value;
    else if (typeof value === 'number' || typeof value === 'boolean') out[nextKey] = String(value);
    else if (value == null) out[nextKey] = '';
    else out[nextKey] = Array.isArray(value) ? JSON.stringify(value) : String(value);
  }

  return out;
};

const translationCache: Record<string, any> = {};

export const loadLocaleData = async (langCode: string) => {
  if (translationCache[langCode]) return translationCache[langCode];

  try {
    const baseLang = 'tr';

    // 1. Önce sonradan eklenmiş (Import edilmiş) dilleri kontrol et
    if (typeof window !== 'undefined') {
      const storedTranslation = localStorage.getItem(`pateez_locale_${langCode}`);
      if (storedTranslation) {
        try {
          const parsed = JSON.parse(storedTranslation);
          if (parsed && Object.keys(parsed).length > 0) {
            const userFlat = flattenTranslations(parsed);
            if (langCode === baseLang) {
              translationCache[langCode] = userFlat;
              return userFlat;
            }
            const fallback = await import('./locales/tr');
            const fallbackFlat = flattenTranslations(fallback.default || fallback);
            const merged = { ...fallbackFlat, ...userFlat };
            translationCache[langCode] = merged;
            return merged;
          }
        } catch (e) {
          console.error("Local storage parse error", e);
        }
      }
    }

    // 2. Statik Dosyalar (Daha Hızlı Import - Paralel)
    let data;
    const loadTarget = async () => {
      switch (langCode) {
        case 'tr': return import('./locales/tr').then(m => m.default || m);
        case 'en': return import('./locales/en').then(m => m.default || m);
        case 'ar': return import('./locales/ar').then(m => m.default || m);
        default: return import('./locales/tr').then(m => m.default || m);
      }
    };

    if (langCode === baseLang) {
      data = await loadTarget();
      const flat = flattenTranslations(data);
      translationCache[langCode] = flat;
      return flat;
    }

    // Hedef dil + TR Fallback'i aynı anda yükle
    const [targetData, baseData] = await Promise.all([
      loadTarget(),
      import('./locales/tr').then(m => m.default || m)
    ]);

    const flat = flattenTranslations(targetData);
    const baseFlat = flattenTranslations(baseData);
    const merged = { ...baseFlat, ...flat };
    translationCache[langCode] = merged;
    return merged;
  } catch (error) {
    console.error(`Critical: Language load failed for ${langCode}`, error);
    // Acil durum kurtarma: Hardcoded temel çeviriler
    return { "nav.home": "AKIŞ" };
  }
};
