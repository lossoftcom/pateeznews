
import React, { useMemo } from 'react';
import { useLanguage } from '@/context/LanguageContext';
import { type NavigationItem } from '@/types';
import Footer from './Footer';
import Skeleton from '@/components/ui/Skeleton';
import { slugify } from '@/utils/helpers';
import { navigate } from 'astro:transitions/client';

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
  '#FF6B00', '#448AFF', '#9C27B0', '#E91E63', '#3F51B5', '#00BCD4',
  '#4CAF50', '#FF5252', '#FF9800', '#673AB7', '#2196F3', '#009688'
];

const Sidebar: React.FC<SidebarProps> = ({
  items, activeCategory, onCategoryItemClick,
  onAllCategoriesClick, onAllDistrictsClick, onAllTrendsClick,
  loading
}) => {
  const { t } = useLanguage();

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
    return items.filter(i => !i.parent_id || i.parent_id === 'root')
      .sort((a, b) => a.order_index - b.order_index);
  }, [items]);

  // 2. Detect selected item and its root ancestor
  const selectedItem = useMemo(() => {
    if (!activeCategory) return null;
    const normalizedSlug = slugify(activeCategory);
    return items.find(i =>
      i.value === activeCategory ||
      i.label === activeCategory ||
      (i.value && slugify(i.value) === normalizedSlug) ||
      (i.label && slugify(i.label) === normalizedSlug)
    );
  }, [activeCategory, items]);

  const findRootId = (itemId: string | null): string | null => {
    if (!itemId) return null;
    const item = items.find(i => i.id === itemId);
    if (!item) return null;
    if (!item.parent_id || item.parent_id === 'root') return item.id;
    return findRootId(item.parent_id);
  };

  const selectedRootId = useMemo(() => selectedItem ? findRootId(selectedItem.id) : null, [selectedItem, items]);

  // 3. Group children of the selected root category
  const children = useMemo(() => {
    if (!selectedRootId) return [];
    return items.filter(i => i.parent_id === selectedRootId).sort((a, b) => a.order_index - b.order_index);
  }, [selectedRootId, items]);

  const districts = children.filter(c => c.type === 'district');
  const categoriesSub = children.filter(c =>
    (c.type === 'category' || c.type === 'dropdown' || c.type === 'link' || !c.type)
  );
  const trendsSub = children.filter(c => c.type === 'trends');

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
                  <div className={`transition-all duration-150 ${isActive ? 'text-emerald-500 scale-110' : 'text-gray-400'}`}>
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
                  const isActive = activeCategory === child.value || activeCategory === child.label;
                  const iconColor = ICON_COLORS[(idx + 8) % ICON_COLORS.length];
                  return (
                    <button
                      key={child.id}
                      onClick={() => navigateToCategory(child.value || child.label || null)}
                      className={`w-full flex items-center gap-3 py-2 px-3 rounded-[5px] transition-all group ${isActive ? 'text-palette-red bg-palette-beige/5' : 'text-gray-600 hover:bg-palette-beige/10'}`}
                    >
                      <div className={`transition-all duration-150 ${isActive ? 'text-emerald-500 scale-110' : ''}`}>
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
                  const isActive = activeCategory === child.value || activeCategory === child.label;
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
                  const isActive = activeCategory === child.value || activeCategory === child.label;
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
