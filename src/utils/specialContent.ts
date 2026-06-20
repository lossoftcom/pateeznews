import type { NavigationItem } from '@/types';
import { slugify } from '@/utils/helpers';

export type SpecialContentKey = 'poll' | 'quiz' | 'video' | 'event' | 'recipe' | 'contents';

export interface SpecialContentConfig {
  key: SpecialContentKey;
  label: string;
  title: string;
  value: string;
  icon: string;
  rank: number;
  typeAliases: string[];
  aliases: string[];
  showInHeader?: boolean;
  injectInSidebar?: boolean;
}

export const SPECIAL_CONTENT_FILTERS: SpecialContentConfig[] = [
  {
    key: 'poll',
    label: 'Anket',
    title: 'Anketler',
    value: 'anketler',
    icon: 'poll',
    rank: 0,
    typeAliases: ['poll'],
    aliases: ['anket', 'anketler', 'poll', 'polls'],
  },
  {
    key: 'quiz',
    label: 'Test',
    title: 'Testler',
    value: 'testler',
    icon: 'quiz',
    rank: 1,
    typeAliases: ['quiz'],
    aliases: ['test', 'testler', 'quiz', 'quizzes'],
  },
  {
    key: 'video',
    label: 'Video',
    title: 'Video',
    value: 'video',
    icon: 'smart_display',
    rank: 2,
    typeAliases: ['video'],
    aliases: ['video', 'videolar', 'videos'],
  },
  {
    key: 'event',
    label: 'Etkinlik',
    title: 'Etkinlik',
    value: 'etkinlik',
    icon: 'calendar_month',
    rank: 3,
    typeAliases: ['event'],
    aliases: ['etkinlik', 'etkinlikler', 'event', 'events'],
    showInHeader: true,
    injectInSidebar: false,
  },
  {
    key: 'recipe',
    label: 'Yemek Tarifi',
    title: 'Yemek Tarifi',
    value: 'yemek-tarifi',
    icon: 'restaurant',
    rank: 4,
    typeAliases: ['recipe'],
    aliases: ['yemek tarifi', 'yemek-tarifi', 'tarif', 'tarifler', 'yemek', 'yemekler', 'recipe', 'recipes', 'food', 'foods'],
    showInHeader: false,
    injectInSidebar: true,
  },
  {
    key: 'contents',
    label: 'Liste',
    title: 'Liste',
    value: 'icindekiler',
    icon: 'format_list_numbered',
    rank: Number.POSITIVE_INFINITY,
    typeAliases: ['contents'],
    aliases: ['liste', 'listeler', 'içindekiler', 'icindekiler', 'contents', 'content', 'table-of-contents', 'toc'],
    showInHeader: false,
    injectInSidebar: true,
  },
];

const SPECIAL_CONTENT_BY_ALIAS = SPECIAL_CONTENT_FILTERS.reduce<Record<string, SpecialContentConfig>>((acc, item) => {
  for (const alias of item.aliases) acc[slugify(alias)] = item;
  return acc;
}, {});

export const getSpecialContentConfig = (...values: unknown[]): SpecialContentConfig | null => {
  for (const value of values) {
    const slug = slugify(String(value || '').trim());
    if (slug && SPECIAL_CONTENT_BY_ALIAS[slug]) return SPECIAL_CONTENT_BY_ALIAS[slug];
  }
  return null;
};

export const getSpecialContentConfigForItem = (item?: NavigationItem | null) => (
  item ? getSpecialContentConfig(item.value, item.label) : null
);

export const getSpecialContentTypeAliases = (values: unknown[]) => (
  Array.from(new Set(values.flatMap((value) => getSpecialContentConfig(value)?.typeAliases || [])))
);

export const getSpecialContentRank = (item?: NavigationItem | null) => (
  getSpecialContentConfigForItem(item)?.rank ?? Number.POSITIVE_INFINITY
);

export const getSpecialContentUrl = (value: string) => {
  const config = getSpecialContentConfig(value);
  const routeValue = config?.value || slugify(value);
  return `/kategori/${encodeURIComponent(routeValue)}`;
};
