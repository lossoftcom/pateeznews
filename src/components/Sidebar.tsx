
import React, { useMemo } from 'react';
import { useLanguage } from '@/context/LanguageContext';
import { type NavigationItem } from '@/types';
import Footer from './Footer';
import Skeleton from '@/components/ui/Skeleton';
import { slugify } from '@/utils/helpers';
import { navigate } from 'astro:transitions/client';
import {
  SPECIAL_CONTENT_FILTERS,
  getSpecialContentConfig,
  getSpecialContentConfigForItem,
  getSpecialContentRank
} from '@/utils/specialContent';

interface SidebarProps {
  items: NavigationItem[];
  activeCategory?: string | null;
  onPublisherItemClick?: (publisher: string) => void;
  onCategoryItemClick?: (category: string | null) => void;
  onAllCategoriesClick?: () => void;
  onAllDistrictsClick?: () => void;
  onAllTrendsClick?: () => void;
  loading?: boolean;
}

// 🌈 SIRA TABANLI RENK MOTORU (SEQUENTIAL COLOR ENGINE) - Consistency with brand aesthetics
const ICON_COLORS = [
  '#EA4335', '#F39C12', '#2C3E50', '#95A5A6',
  '#EA4335', '#F39C12', '#2C3E50', '#95A5A6'
];

const HIDDEN_SIDEBAR_SPECIAL_KEYS = new Set(['poll', 'quiz', 'video', 'event']);
const SIDEBAR_END_SPECIAL_KEYS = new Set(['contents']);
const NORMAL_SIDEBAR_CATEGORY_FALLBACKS: NavigationItem[] = [
  {
    id: 'sidebar-normal-spor',
    menu_id: 'virtual',
    parent_id: '',
    label: 'Spor',
    type: 'category',
    value: 'spor',
    icon: 'sports_soccer',
    order_index: 7,
    is_active: true,
  },
];

const getSpecialSidebarOrder = (rank: number) => Number.isFinite(rank) ? rank : 9999;

const getDefaultRootItem = (items: NavigationItem[]) => (
  items.find((item) => {
    const value = item.value || item.label || '';
    return slugify(value) === 'nigde' || slugify(item.label) === 'nigde';
  }) || items[0] || null
);

const Sidebar: React.FC<SidebarProps> = ({
  items, activeCategory, onCategoryItemClick,
  onAllCategoriesClick, onAllDistrictsClick, onAllTrendsClick,
  loading
}) => {
  const { t } = useLanguage();
  const sidebarItems = useMemo(() => {
    const scoped = items.filter((item) => item.menu_code === 'sidebar_main');
    return scoped.length > 0 ? scoped : items.filter((item) => item.menu_code !== 'top_navbar');
  }, [items]);

  const navigateToCategory = (category: string | null) => {
    if (onCategoryItemClick) {
      onCategoryItemClick(category);
      return;
    }
    if (!category || category === 'home' || category === 'null') {
      void navigate('/');
      return;
    }
    void navigate(`/kategori/${slugify(category)}`);
  };

  // 1. Root items are considered "Ana Kategoriler"
  const rootItems = useMemo(() => {
    return sidebarItems.filter(i => !i.parent_id || i.parent_id === 'root')
      .sort((a, b) => a.order_index - b.order_index);
  }, [sidebarItems]);

  // 2. Detect selected item and its root ancestor
  const selectedItem = useMemo(() => {
    if (!activeCategory) return null;
    const normalizedSlug = slugify(activeCategory);
    return sidebarItems.find(i =>
      i.value === activeCategory ||
      i.label === activeCategory ||
      (i.value && slugify(i.value) === normalizedSlug) ||
      (i.label && slugify(i.label) === normalizedSlug)
    );
  }, [activeCategory, sidebarItems]);

  const findRootId = (itemId: string | null): string | null => {
    if (!itemId) return null;
    const item = sidebarItems.find(i => i.id === itemId);
    if (!item) return null;
    if (!item.parent_id || item.parent_id === 'root') return item.id;
    return findRootId(item.parent_id);
  };

  const selectedRootId = useMemo(() => {
    if (selectedItem) return findRootId(selectedItem.id);
    if (getSpecialContentConfig(activeCategory)) {
      return getDefaultRootItem(rootItems)?.id || null;
    }
    return getDefaultRootItem(rootItems)?.id || null;
  }, [activeCategory, rootItems, selectedItem, sidebarItems]);

  // 3. Group children of the selected root category
  const children = useMemo(() => {
    if (!selectedRootId) return [];
    return sidebarItems.filter(i => i.parent_id === selectedRootId).sort((a, b) => a.order_index - b.order_index);
  }, [selectedRootId, sidebarItems]);

  const districts = children.filter(c => c.type === 'district');
  const rawCategoryItems = children
    .filter(c => (c.type === 'category' || c.type === 'dropdown' || c.type === 'link' || !c.type))
    .filter(c => {
      const specialConfig = getSpecialContentConfigForItem(c);
      return !specialConfig || !HIDDEN_SIDEBAR_SPECIAL_KEYS.has(specialConfig.key);
    })
    .map((c) => {
      const specialConfig = getSpecialContentConfigForItem(c);
      if (!specialConfig) return c;
      return {
        ...c,
        label: specialConfig.label,
        value: specialConfig.value,
        icon: c.icon || specialConfig.icon,
        order_index: getSpecialSidebarOrder(specialConfig.rank),
      };
    });
  const seenCategoryKeys = new Set<string>();
  const categoryItems = rawCategoryItems.filter((item) => {
    const specialConfig = getSpecialContentConfigForItem(item);
    const key = specialConfig
      ? `special:${specialConfig.key}`
      : `normal:${slugify(item.value || item.label || '')}`;
    if (!key || seenCategoryKeys.has(key)) return false;
    seenCategoryKeys.add(key);
    return true;
  });
  const existingSpecialKeys = new Set(
    categoryItems
      .map((item) => getSpecialContentConfigForItem(item)?.key)
      .filter(Boolean)
  );
  const injectedSidebarCategories: NavigationItem[] = selectedRootId
    ? SPECIAL_CONTENT_FILTERS
      .filter((config) => config.injectInSidebar && !existingSpecialKeys.has(config.key))
      .map((config) => ({
        id: `sidebar-special-${config.key}`,
        menu_id: 'virtual',
        parent_id: selectedRootId,
        label: config.label,
        type: 'category',
        value: config.value,
        icon: config.icon,
        order_index: getSpecialSidebarOrder(config.rank),
        is_active: true,
      }))
    : [];
  const existingNormalCategoryKeys = new Set(
    [...categoryItems, ...injectedSidebarCategories]
      .flatMap((item) => [slugify(item.value || ''), slugify(item.label || '')])
      .filter(Boolean)
  );
  const injectedNormalCategories = selectedRootId
    ? NORMAL_SIDEBAR_CATEGORY_FALLBACKS
      .filter((item) => !existingNormalCategoryKeys.has(slugify(item.value || item.label || '')))
      .map((item) => ({ ...item, parent_id: selectedRootId }))
    : [];
  const categoriesSub = [...categoryItems, ...injectedSidebarCategories, ...injectedNormalCategories]
    .sort((a, b) => {
      const configA = getSpecialContentConfigForItem(a);
      const configB = getSpecialContentConfigForItem(b);
      const endA = !!configA && SIDEBAR_END_SPECIAL_KEYS.has(configA.key);
      const endB = !!configB && SIDEBAR_END_SPECIAL_KEYS.has(configB.key);
      if (endA !== endB) return endA ? 1 : -1;
      const rankA = getSpecialContentRank(a);
      const rankB = getSpecialContentRank(b);
      return rankA !== rankB ? rankA - rankB : a.order_index - b.order_index;
    });
  const trendsSub = children.filter(c => c.type === 'trends');

  const isActiveItem = (item: NavigationItem) => {
    if (!activeCategory) return false;
    const normalized = String(activeCategory).trim();
    const normalizedSlug = slugify(normalized);
    return item.value === normalized ||
      item.label === normalized ||
      (item.value && slugify(item.value) === normalizedSlug) ||
      slugify(item.label) === normalizedSlug;
  };

  const renderIcon = (iconName: string, size = 20, color?: string, isSelected = false) => {
    if (!iconName) return null;
    return (
      <span
        className="material-symbols-rounded transition-all duration-300"
        style={{
          fontSize: `${size}px`,
          color: isSelected ? 'inherit' : (color || 'inherit'),
          fontWeight: isSelected ? '700' : '500'
        }}
      >
        {iconName.toLowerCase()}
      </span>
    );
  };

  return (
    <div className="w-[300px] h-full flex flex-col border-r border-palette-beige/20 overflow-y-auto overflow-x-hidden no-scrollbar pt-4 pb-8 gap-10">

      {/* 1. ANA KATEGORİ SECTION */}
      <div className="px-3">
        <div className="flex flex-col gap-1">
          {rootItems.map((item, index) => {
            const isActive = selectedRootId === item.id;
            const iconColor = ICON_COLORS[index % ICON_COLORS.length];

            return (
              <button
                key={item.id}
                onClick={() => navigateToCategory(item.value || item.label || null)}
                className={`w-full relative flex items-center py-2.5 px-3 rounded-[5px] transition-all group ${isActive ? 'text-palette-red bg-palette-beige/5' : 'text-gray-600 hover:bg-palette-beige/10'}`}
              >
                <div className="flex items-center gap-3">
                  <div className={`transition-all duration-150 ${isActive ? 'text-palette-red scale-110' : 'text-gray-400'}`}>
                    {renderIcon(isActive ? 'where_to_vote' : (item.icon || 'grid_view'), 20, isActive ? undefined : iconColor, isActive)}
                  </div>
                  <span className={`text-[14px] font-bold tracking-tight ${isActive ? 'text-gray-900 font-black' : ''}`}>
                    {t(item.label)}
                  </span>
                </div>
              </button>
            );
          })}
        </div>
      </div>

      {/* 2. DYNAMIC SUB-SECTIONS (Grouped by Type) */}
      {selectedRootId && (
        <div className="flex flex-col gap-8">

          {/* İLÇELER HEADER & ITEMS */}
          {districts.length > 0 && (
            <div className="px-3">
              <h3
                onClick={onAllDistrictsClick}
                className="text-[10px] font-black text-palette-tan/40 uppercase tracking-[0.2em] mb-3 ml-1 cursor-pointer hover:text-palette-red transition-all flex items-center gap-2 group/dis-header"
              >
                {t('sidebar.districts')}
                <span className="material-symbols-rounded text-[12px] opacity-0 group-hover/dis-header:opacity-100 transition-all translate-x-[-4px] group-hover/dis-header:translate-x-0">chevron_right</span>
              </h3>
              <div className="flex flex-col gap-1">
                {districts.map((child, idx) => {
                  const isActive = isActiveItem(child);
                  const iconColor = ICON_COLORS[(idx + 8) % ICON_COLORS.length];
                  return (
                    <button
                      key={child.id}
                      onClick={() => navigateToCategory(child.value || child.label || null)}
                      className={`w-full flex items-center gap-3 py-2 px-3 rounded-[5px] transition-all group ${isActive ? 'text-palette-red bg-palette-beige/5' : 'text-gray-600 hover:bg-palette-beige/10'}`}
                    >
                      <div className={`transition-all duration-150 ${isActive ? 'text-palette-red scale-110' : ''}`}>
                        {renderIcon(isActive ? 'where_to_vote' : (child.icon || 'location_on'), 18, isActive ? undefined : iconColor, isActive)}
                      </div>
                      <span className={`text-[13px] font-bold tracking-tight ${isActive ? 'text-gray-900 font-black' : ''}`}>
                        {t(child.label)}
                      </span>
                    </button>
                  );
                })}
              </div>
            </div>
          )}

          {/* KATEGORİLER HEADER & ITEMS */}
          {categoriesSub.length > 0 && (
            <div className="px-3">
              <h3
                onClick={onAllCategoriesClick}
                className="text-[10px] font-black text-palette-tan/40 uppercase tracking-[0.2em] mb-3 ml-1 cursor-pointer hover:text-palette-red transition-all flex items-center gap-2 group/cat-header"
              >
                {t('sidebar.categories')}
                <span className="material-symbols-rounded text-[12px] opacity-0 group-hover/cat-header:opacity-100 transition-all translate-x-[-4px] group-hover/cat-header:translate-x-0">chevron_right</span>
              </h3>
              <div className="flex flex-col gap-1">
                {categoriesSub.map((child, idx) => {
                  const isActive = isActiveItem(child);
                  const iconColor = ICON_COLORS[(idx + 5) % ICON_COLORS.length];
                  return (
                    <button
                      key={child.id}
                      onClick={() => navigateToCategory(child.value || child.label || null)}
                      className={`w-full flex items-center gap-3 py-2 px-3 rounded-[5px] transition-all group ${isActive ? 'text-palette-red' : 'text-gray-600 hover:bg-palette-beige/10'}`}
                    >
                      <div className={`transition-colors ${isActive ? 'text-palette-red' : ''}`}>
                        {renderIcon(child.icon || 'grid_view', 18, iconColor, isActive)}
                      </div>
                      <span className={`text-[13px] font-bold tracking-tight ${isActive ? 'text-gray-900 font-black' : ''}`}>
                        {t(child.label)}
                      </span>
                    </button>
                  );
                })}
              </div>
            </div>
          )}

          {/* TRENDLER HEADER & ITEMS */}
          {trendsSub.length > 0 && (
            <div className="px-3">
              <h3
                onClick={onAllTrendsClick}
                className="text-[10px] font-black text-palette-tan/40 uppercase tracking-[0.2em] mb-3 ml-1 cursor-pointer hover:text-palette-red transition-all flex items-center gap-2 group/trend-header"
              >
                {t('cat.trends')}
                <span className="material-symbols-rounded text-[12px] opacity-0 group-hover/trend-header:opacity-100 transition-all translate-x-[-4px] group-hover/trend-header:translate-x-0">chevron_right</span>
              </h3>
              <div className="flex flex-col gap-1">
                {trendsSub.map((child, idx) => {
                  const isActive = isActiveItem(child);
                  const iconColor = ICON_COLORS[(idx + 2) % ICON_COLORS.length];
                  return (
                    <button
                      key={child.id}
                      onClick={() => navigateToCategory(child.value || child.label || null)}
                      className={`w-full flex items-center gap-3 py-2 px-3 rounded-[5px] transition-all group ${isActive ? 'text-palette-red' : 'text-gray-600 hover:bg-palette-beige/10'}`}
                    >
                      <div className={`transition-colors ${isActive ? 'text-palette-red' : ''}`}>
                        {renderIcon(child.icon || 'trending_up', 18, iconColor, isActive)}
                      </div>
                      <span className={`text-[13px] font-bold tracking-tight ${isActive ? 'text-gray-900 font-black' : ''}`}>
                        {t(child.label)}
                      </span>
                    </button>
                  );
                })}
              </div>
            </div>
          )}

        </div>
      )}

      <Footer />
    </div>
  );
};

export const SidebarSkeleton: React.FC = () => {
  return (
    <div className="w-[300px] h-full flex flex-col py-8 gap-10 px-3">
      <div className="space-y-4">
        <Skeleton className="w-24 h-3 ml-1" />
        <div className="space-y-2">
          {[1, 2, 3, 4, 5, 6].map(i => (
            <div key={i} className="flex items-center gap-3 py-2 px-3">
              <Skeleton variant="rectangular" className="w-5 h-5" />
              <Skeleton className="w-32 h-4" />
            </div>
          ))}
        </div>
      </div>
      <div className="space-y-4">
        <Skeleton className="w-20 h-3 ml-1" />
        <div className="space-y-2">
          {[1, 2, 3].map(i => (
            <div key={i} className="flex items-center gap-3 py-2 px-3">
              <Skeleton variant="rectangular" className="w-4 h-4" />
              <Skeleton className="w-24 h-3" />
            </div>
          ))}
        </div>
      </div>
    </div>
  );
};

export default Sidebar;
