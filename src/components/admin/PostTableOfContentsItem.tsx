import React, { useMemo, useState } from 'react';
import ReactQuill from 'react-quill-new';
import { QUILL_FORMATS, QUILL_MODULES, type PostItem, type TocListItem, type TocListStyle } from './PostTextItem';
import { useLanguage } from '@/context/LanguageContext';
import MediaFilenameBadge from './MediaFilenameBadge';

interface PostTableOfContentsItemProps {
    item: PostItem;
    index: number;
    totalItems: number;
    showBlockNumbers: boolean;
    displayMode?: 'all' | 'style' | 'items';
    onUpdate: (id: string, field: keyof PostItem, value: any) => void;
    onRemove: (id: string) => void;
    isDeletable?: boolean;
    onMoveUp?: (index: number) => void;
    onMoveDown?: (index: number) => void;
    onOpenFileManager: (id: string, subField?: string, optionId?: string) => void;
    onOpenUrlMode: (id: string, subField?: string, optionId?: string) => void;
    onOpenImageEditor: (id: string, subField?: string, optionId?: string) => void;
    onRenameMedia?: (src: string, type: 'image') => Promise<string | null>;
}

const LIST_STYLE_OPTIONS: { value: TocListStyle; label: string; labelKey?: string }[] = [
    { value: 'none', label: 'none', labelKey: 'admin.post.toc.style_none' },
    { value: 'decimal', label: 'decimal' },
    { value: 'decimal-leading-zero', label: 'decimal-leading-zero' },
    { value: 'circle', label: 'circle' },
    { value: 'disc', label: 'disc' },
    { value: 'square', label: 'square' },
    { value: 'lower-alpha', label: 'lower-alpha' },
    { value: 'upper-alpha', label: 'upper-alpha' },
    { value: 'lower-roman', label: 'lower-roman' },
    { value: 'upper-roman', label: 'upper-roman' },
];

const makeTocListItem = (orderNumber: number): TocListItem => ({
    id: Math.random().toString(36).slice(2, 11),
    orderNumber,
    title: '',
    parentLink: '',
    image: '',
    imageDescription: '',
    content: '',
});

const DEFAULT_LINK_STYLE: NonNullable<NonNullable<PostItem['tocData']>['linkListStyle']> = {
    level1: 'none',
    level2: 'none',
    level3: 'none',
    showLevel1InText: false,
    showLevel2InText: false,
    showLevel3InText: false,
};

type NormalizedTocData = Omit<NonNullable<PostItem['tocData']>, 'linkListStyle'> & {
    linkListStyle: NonNullable<NonNullable<PostItem['tocData']>['linkListStyle']>;
};

export const createDefaultTocData = (): NormalizedTocData => ({
    optionalUrl: '',
    linkListStyle: { ...DEFAULT_LINK_STYLE },
    items: [makeTocListItem(1)],
});

const normalizeTocData = (value: PostItem['tocData']): NormalizedTocData => {
    const base = createDefaultTocData();
    const items = Array.isArray(value?.items) && value.items.length > 0
        ? value.items.map((entry, entryIndex) => ({
            id: entry.id || Math.random().toString(36).slice(2, 11),
            orderNumber: Number(entry.orderNumber) || entryIndex + 1,
            title: entry.title || '',
            parentLink: entry.parentLink || '',
            image: entry.image || '',
            imageDescription: entry.imageDescription || '',
            content: entry.content || '',
        }))
        : base.items;

    return {
        optionalUrl: value?.optionalUrl || '',
        linkListStyle: {
            ...base.linkListStyle,
            ...(value?.linkListStyle || {}),
        },
        items,
    };
};

const PostTableOfContentsItem: React.FC<PostTableOfContentsItemProps> = ({
    item,
    displayMode = 'all',
    onUpdate,
    onOpenFileManager,
    onOpenUrlMode,
    onOpenImageEditor,
    onRenameMedia,
}) => {
    const { t } = useLanguage();
    const [collapsedItems, setCollapsedItems] = useState<Set<string>>(new Set());
    const tocData = useMemo(() => normalizeTocData(item.tocData), [item.tocData]);
    const showStyleSection = displayMode === 'all' || displayMode === 'style';
    const showItemsSection = displayMode === 'all' || displayMode === 'items';

    React.useEffect(() => {
        if (!item.tocData || !Array.isArray(item.tocData.items) || item.tocData.items.length === 0) {
            onUpdate(item.id, 'tocData', tocData);
        }
        // initialize only missing legacy data
        // eslint-disable-next-line react-hooks/exhaustive-deps
    }, []);

    const updateTocData = (nextData: NormalizedTocData) => {
        onUpdate(item.id, 'tocData', nextData);
    };

    const updateLinkStyle = (field: keyof NonNullable<NonNullable<PostItem['tocData']>['linkListStyle']>, value: any) => {
        updateTocData({
            ...tocData,
            linkListStyle: {
                ...tocData.linkListStyle,
                [field]: value,
            },
        });
    };

    const updateListItem = (tocItemId: string, field: keyof TocListItem, value: any) => {
        updateTocData({
            ...tocData,
            items: tocData.items.map((tocItem) =>
                tocItem.id === tocItemId ? { ...tocItem, [field]: value } : tocItem
            ),
        });
    };

    const addListItem = () => {
        const nextOrder = tocData.items.length > 0
            ? Math.max(...tocData.items.map((tocItem) => Number(tocItem.orderNumber) || 0)) + 1
            : 1;
        updateTocData({
            ...tocData,
            items: [...tocData.items, makeTocListItem(nextOrder)],
        });
    };

    const removeListItem = (tocItemId: string) => {
        if (tocData.items.length <= 1) return;
        updateTocData({
            ...tocData,
            items: tocData.items
                .filter((tocItem) => tocItem.id !== tocItemId)
                .map((tocItem, itemIndex) => ({
                    ...tocItem,
                    orderNumber: Number(tocItem.orderNumber) || itemIndex + 1,
                })),
        });
    };

    const moveListItem = (tocItemId: string, direction: 'up' | 'down') => {
        const currentIndex = tocData.items.findIndex((tocItem) => tocItem.id === tocItemId);
        const targetIndex = direction === 'up' ? currentIndex - 1 : currentIndex + 1;
        if (currentIndex < 0 || targetIndex < 0 || targetIndex >= tocData.items.length) return;

        const nextItems = [...tocData.items];
        const current = nextItems[currentIndex];
        nextItems[currentIndex] = nextItems[targetIndex];
        nextItems[targetIndex] = current;
        updateTocData({
            ...tocData,
            items: nextItems.map((tocItem, itemIndex) => ({
                ...tocItem,
                orderNumber: itemIndex + 1,
            })),
        });
    };

    const toggleCollapsed = (tocItemId: string) => {
        setCollapsedItems((prev) => {
            const next = new Set(prev);
            if (next.has(tocItemId)) {
                next.delete(tocItemId);
            } else {
                next.add(tocItemId);
            }
            return next;
        });
    };

    const renderStyleControl = (
        levelLabel: string,
        levelField: 'level1' | 'level2' | 'level3',
        checkboxField: 'showLevel1InText' | 'showLevel2InText' | 'showLevel3InText'
    ) => (
        <div className="space-y-2">
            <label className="text-[12px] font-black text-palette-tan/60 uppercase tracking-wider">{levelLabel}</label>
            <select
                value={tocData.linkListStyle[levelField]}
                onChange={(event) => updateLinkStyle(levelField, event.target.value as TocListStyle)}
                className="w-full h-11 bg-palette-beige/5 border border-palette-tan/20 rounded-[3px] px-3 text-sm font-bold text-palette-maroon outline-none focus:border-palette-red transition-all"
            >
                {LIST_STYLE_OPTIONS.map((option) => (
                    <option key={option.value} value={option.value}>{option.labelKey ? t(option.labelKey) : option.label}</option>
                ))}
            </select>
            <label className="flex items-center gap-2 text-[12px] font-bold text-palette-tan cursor-pointer select-none">
                <input
                    type="checkbox"
                    checked={tocData.linkListStyle[checkboxField]}
                    onChange={(event) => updateLinkStyle(checkboxField, event.target.checked)}
                    className="w-4 h-4 rounded-[3px] border-palette-tan/30 text-palette-maroon focus:ring-palette-red"
                />
                {t('admin.post.toc.show_style_in_text')}
            </label>
        </div>
    );

    const Quill: any = ReactQuill;

    return (
        <div className="space-y-6 animate-in slide-in-from-top-4 duration-500 admin-font">
            {showStyleSection && (
            <div className="space-y-4">
                <div className="flex items-center gap-2">
                    <span className="material-symbols-rounded text-palette-tan/60" style={{ fontSize: '18px' }}>format_list_bulleted</span>
                    <label className="text-[12px] font-bold text-palette-tan/60">{t('admin.post.toc.link_list_style')}</label>
                </div>
                <div className="grid grid-cols-1 lg:grid-cols-3 gap-4">
                    {renderStyleControl(t('admin.post.toc.level_1'), 'level1', 'showLevel1InText')}
                    {renderStyleControl(t('admin.post.toc.level_2'), 'level2', 'showLevel2InText')}
                    {renderStyleControl(t('admin.post.toc.level_3'), 'level3', 'showLevel3InText')}
                </div>
            </div>
            )}

            {showItemsSection && (
            <div className={`space-y-6 ${showStyleSection ? 'pt-4 border-t border-palette-tan/10' : ''}`}>
                <div className="space-y-6">
                    {tocData.items.map((tocItem, tocIndex) => {
                        const isCollapsed = collapsedItems.has(tocItem.id);
                        const displayIndex = Number(tocItem.orderNumber) || tocIndex + 1;

                        return (
                            <div key={tocItem.id} className="group bg-white rounded-[3px] border border-palette-tan/20 shadow-md flex overflow-hidden animate-in slide-in-from-left duration-300">
                                <div className="w-12 shrink-0 bg-palette-beige/5 border-r border-palette-tan/10 flex flex-col items-center py-6 justify-between transition-colors group-hover:bg-palette-beige/10">
                                    <div className="flex flex-col gap-2 items-center">
                                        {tocData.items.length > 1 && (
                                            <>
                                                <button
                                                    type="button"
                                                    onClick={() => moveListItem(tocItem.id, 'up')}
                                                    disabled={tocIndex === 0}
                                                    className="w-8 h-8 flex items-center justify-center rounded-[3px] text-palette-tan/40 hover:text-palette-maroon hover:bg-white hover:shadow-sm transition-all active:scale-90 disabled:opacity-20 disabled:cursor-not-allowed"
                                                    title={t('common.move_up')}
                                                >
                                                    <span className="material-symbols-rounded rotate-180" style={{ fontSize: '20px' }}>expand_more</span>
                                                </button>
                                                <button
                                                    type="button"
                                                    onClick={() => moveListItem(tocItem.id, 'down')}
                                                    disabled={tocIndex === tocData.items.length - 1}
                                                    className="w-8 h-8 flex items-center justify-center rounded-[3px] text-palette-tan/40 hover:text-palette-maroon hover:bg-white hover:shadow-sm transition-all active:scale-90 disabled:opacity-20 disabled:cursor-not-allowed"
                                                    title={t('common.move_down')}
                                                >
                                                    <span className="material-symbols-rounded" style={{ fontSize: '20px' }}>expand_more</span>
                                                </button>
                                            </>
                                        )}
                                    </div>

                                    <button
                                        type="button"
                                        onClick={() => removeListItem(tocItem.id)}
                                        disabled={tocData.items.length <= 1}
                                        className="w-8 h-8 flex items-center justify-center rounded-[3px] text-palette-tan/30 hover:text-white hover:bg-palette-red hover:shadow-md transition-all active:scale-90 disabled:opacity-20 disabled:cursor-not-allowed"
                                        title={t('common.delete')}
                                    >
                                        <span className="material-symbols-rounded" style={{ fontSize: '18px' }}>delete</span>
                                    </button>
                                </div>

                                <div className="flex-1 p-6 space-y-6">
                                    <div className="flex items-center justify-between gap-4 border-b border-palette-tan/15 pb-3">
                                        <div className="flex items-center gap-3 min-w-0">
                                            <div className="p-2 bg-palette-red/10 rounded-[3px] text-palette-red">
                                                <span className="material-symbols-rounded" style={{ fontSize: '18px' }}>format_list_numbered</span>
                                            </div>
                                            <h3 className="text-base font-black text-palette-maroon truncate">{t('admin.post.toc.item')} #{tocIndex + 1}</h3>
                                        </div>
                                        <button
                                            type="button"
                                            onClick={() => toggleCollapsed(tocItem.id)}
                                            className="w-8 h-8 rounded-[3px] flex items-center justify-center text-palette-tan/45 hover:text-palette-maroon hover:bg-palette-beige/20 transition-all"
                                            title={isCollapsed ? t('common.show_all') : t('common.hide_details')}
                                        >
                                            <span className={`material-symbols-rounded transition-transform ${isCollapsed ? '-rotate-90' : ''}`} style={{ fontSize: '19px' }}>expand_more</span>
                                        </button>
                                    </div>

                                    {!isCollapsed && (
                                        <div className="space-y-6">
                                            <div className="grid grid-cols-1 xl:grid-cols-[minmax(0,1fr)_220px] gap-4 items-end">
                                                <div className="space-y-2">
                                                    <label className="text-[13px] font-black text-palette-tan ml-1">{t('admin.post.toc.item_title')}</label>
                                                    <div className="flex items-center gap-3">
                                                        <div className="w-9 h-9 shrink-0 rounded-[3px] bg-palette-maroon text-white flex items-center justify-center text-base font-black shadow-md shadow-palette-maroon/10">
                                                            {displayIndex}
                                                        </div>
                                                        <input
                                                            type="text"
                                                            value={tocItem.title}
                                                            onChange={(event) => updateListItem(tocItem.id, 'title', event.target.value)}
                                                            placeholder={t('admin.post.toc.item_title_placeholder')}
                                                            className="w-full h-9 bg-palette-beige/5 border border-palette-tan/20 rounded-[3px] px-4 text-base font-bold text-palette-maroon outline-none focus:border-palette-red transition-all placeholder:text-palette-tan/20"
                                                        />
                                                    </div>
                                                </div>
                                                <div className="space-y-2">
                                                    <label className="text-[13px] font-black text-palette-tan ml-1">{t('admin.post.toc.parent_link')}</label>
                                                    <input
                                                        type="text"
                                                        value={tocItem.parentLink}
                                                        onChange={(event) => updateListItem(tocItem.id, 'parentLink', event.target.value)}
                                                        placeholder={t('admin.post.toc.parent_link_placeholder')}
                                                        className="w-full h-9 bg-palette-beige/5 border border-palette-tan/20 rounded-[3px] px-4 text-sm font-bold text-palette-maroon outline-none focus:border-palette-red transition-all placeholder:text-palette-tan/25"
                                                    />
                                                </div>
                                            </div>

                                            <div className="grid grid-cols-1 md:grid-cols-12 gap-6 items-start">
                                                <div className="md:col-span-4 space-y-2">
                                                    <label className="text-[13px] font-black text-palette-tan ml-1 uppercase tracking-wider">{t('admin.post.toc.item_image')}</label>
                                                    <div className="rounded-[3px] bg-palette-beige/5 border-2 border-dashed border-palette-tan/20 flex flex-col items-center justify-center overflow-hidden transition-all relative group/image w-full min-h-[220px]">
                                                        {tocItem.image ? (
                                                            <div className="relative w-full h-full flex items-center justify-center bg-palette-beige/5 min-h-[220px]">
                                                                <img
                                                                    src={tocItem.image}
                                                                    className="max-w-full max-h-[220px] object-contain block"
                                                                    alt={tocItem.imageDescription || tocItem.title}
                                                                />
                                                                <MediaFilenameBadge src={tocItem.image} type="image" onRename={onRenameMedia} />
                                                                <div className="absolute inset-0 bg-black/40 opacity-0 group-hover/image:opacity-100 transition-all flex items-center justify-center gap-2">
                                                                    <button
                                                                        type="button"
                                                                        onClick={() => onOpenImageEditor(item.id, 'tocItems', tocItem.id)}
                                                                        className="p-3 bg-white/10 backdrop-blur-md rounded-[3px] text-white hover:bg-emerald-600 transition-all flex items-center justify-center"
                                                                        title={t('common.edit')}
                                                                    >
                                                                        <span className="material-symbols-rounded" style={{ fontSize: '20px' }}>edit_square</span>
                                                                    </button>
                                                                    <button
                                                                        type="button"
                                                                        onClick={() => updateListItem(tocItem.id, 'image', '')}
                                                                        className="p-3 bg-white/10 backdrop-blur-md rounded-[3px] text-white hover:bg-palette-red transition-all flex items-center justify-center"
                                                                        title={t('common.delete')}
                                                                    >
                                                                        <span className="material-symbols-rounded" style={{ fontSize: '20px' }}>delete</span>
                                                                    </button>
                                                                </div>
                                                            </div>
                                                        ) : (
                                                            <div className="flex flex-col items-center justify-center py-12">
                                                                <button
                                                                    type="button"
                                                                    onClick={() => onOpenFileManager(item.id, 'tocItems', tocItem.id)}
                                                                    className="flex flex-col items-center cursor-pointer group/pick mb-4"
                                                                >
                                                                    <span className="material-symbols-rounded text-palette-tan/20 group-hover/pick:text-palette-maroon transition-all mb-2" style={{ fontSize: '48px' }}>add</span>
                                                                    <span className="text-[14px] font-bold text-palette-tan/50 px-4 text-center">{t('admin.post.pick_image')}</span>
                                                                </button>
                                                                <button
                                                                    type="button"
                                                                    onClick={() => onOpenUrlMode(item.id, 'tocItems', tocItem.id)}
                                                                    className="mt-2 text-[10px] font-black text-palette-tan/60 hover:text-palette-maroon border border-palette-tan/20 px-3 py-1.5 rounded-[3px] bg-white shadow-sm hover:shadow-md transition-all flex items-center gap-1.5 uppercase tracking-wider"
                                                                >
                                                                    <span className="material-symbols-rounded" style={{ fontSize: '11px' }}>public</span> {t('admin.post.url_or_upload')}
                                                                </button>
                                                            </div>
                                                        )}
                                                    </div>
                                                    <input
                                                        type="text"
                                                        value={tocItem.imageDescription}
                                                        onChange={(event) => updateListItem(tocItem.id, 'imageDescription', event.target.value)}
                                                        placeholder={t('admin.post.toc.image_desc_placeholder')}
                                                        className="w-full bg-palette-beige/5 border border-palette-tan/20 rounded-[3px] px-3 py-2 text-xs font-bold text-palette-maroon outline-none focus:border-palette-red transition-all placeholder:text-palette-tan/25"
                                                    />
                                                </div>

                                                <div className="md:col-span-8 h-full flex flex-col">
                                                    <div className="space-y-2 group/editor flex-1 flex flex-col">
                                                        <div className="flex flex-wrap items-center justify-between gap-2 px-1">
                                                            <label className="text-[13px] font-black text-palette-tan uppercase tracking-wider">{t('admin.post.toc.item_content')}</label>
                                                        </div>
                                                        <div className="quill-modern-wrapper compact-quill border border-palette-tan/20 rounded-[3px] overflow-hidden focus-within:border-palette-red/40 transition-all shadow-sm bg-white flex-1 min-h-[220px]">
                                                            <Quill
                                                                theme="snow"
                                                                value={tocItem.content}
                                                                onChange={(content: string) => updateListItem(tocItem.id, 'content', content)}
                                                                modules={QUILL_MODULES}
                                                                formats={QUILL_FORMATS}
                                                                placeholder={t('admin.post.toc.item_content_placeholder')}
                                                                className="modern-quill-editor h-full"
                                                            />
                                                        </div>
                                                    </div>
                                                </div>
                                            </div>
                                        </div>
                                    )}
                                </div>
                            </div>
                        );
                    })}
                </div>

                <div className="flex justify-center pt-2 pb-2">
                    <button
                        type="button"
                        onClick={addListItem}
                        className="px-8 py-2.5 border-2 border-dashed border-palette-red/30 rounded-[3px] text-palette-red/60 text-[11px] font-black uppercase tracking-widest hover:bg-palette-red/5 hover:border-palette-red transition-all shadow-sm active:scale-95"
                    >
                        + {t('admin.post.toc.add_item')}
                    </button>
                </div>
            </div>
            )}
        </div>
    );
};

export default PostTableOfContentsItem;
