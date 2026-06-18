import type { NewsItem } from '@/types';

const OPINION_LABELS = new Set([
  'kose yazisi',
  'kose yazilari',
  'opinion',
  'opinion column',
]);

const normalizeText = (value: unknown): string => {
  return String(value || '')
    .trim()
    .toLocaleLowerCase('tr-TR')
    .replace(/ı/g, 'i')
    .normalize('NFD')
    .replace(/[\u0300-\u036f]/g, '')
    .replace(/[^\p{L}\p{N}]+/gu, ' ')
    .replace(/\s+/g, ' ')
    .trim();
};

const normalizeSlug = (value: unknown): string => normalizeText(value).replace(/\s+/g, '-');

export const isOpinionColumn = (item?: Pick<NewsItem, 'category' | 'categoryTrail' | 'categoryPath'> | null): boolean => {
  if (!item) return false;
  const candidates = [
    item.category,
    ...(Array.isArray(item.categoryTrail) ? item.categoryTrail : []),
    ...(Array.isArray(item.categoryPath) ? item.categoryPath : []),
  ];

  return candidates.some((candidate) => {
   const normalized = normalizeText(candidate);
   if (!normalized) return false;
    return OPINION_LABELS.has(normalized) ||
      normalized.includes('kose yazisi') ||
      normalizeSlug(normalized) === 'kose-yazisi';
  });
};

export const filterOutOpinionColumns = <T extends Pick<NewsItem, 'category' | 'categoryTrail' | 'categoryPath'>>(
  items: T[],
): T[] => items.filter((item) => !isOpinionColumn(item));
