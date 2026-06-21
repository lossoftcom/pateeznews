import { navigateImmediately } from '@/utils/immediateNavigation';

export const getSiteSearchHref = (query = '', languageCode = '') => {
  const params = new URLSearchParams();
  const cleanQuery = query.trim();
  const cleanLang = languageCode.trim() || (
    typeof window === 'undefined'
      ? ''
      : String(new URLSearchParams(window.location.search).get('lang') || '').trim()
  );

  if (cleanQuery) params.set('q', cleanQuery);
  if (cleanLang && cleanLang !== 'tr') params.set('lang', cleanLang);

  const suffix = params.toString();
  return suffix ? `/arama?${suffix}` : '/arama';
};

export const openSiteSearch = (query = '', languageCode = '') => (
  navigateImmediately(getSiteSearchHref(query, languageCode))
);
