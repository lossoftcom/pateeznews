import React, { useMemo, useState } from 'react';
import ReactQuill from 'react-quill-new';
import {
    QUILL_FORMATS,
    QUILL_MODULES,
    type PostItem,
    type RecipeData,
    type RecipeDifficulty,
    type RecipeDirectionItem,
    type RecipeIngredientItem,
    type RecipeNutritionItem,
} from './PostTextItem';
import { useLanguage } from '@/context/LanguageContext';
import MediaFilenameBadge from './MediaFilenameBadge';

interface PostRecipeItemProps {
    item: PostItem;
    index: number;
    totalItems: number;
    showBlockNumbers: boolean;
    displayMode?: 'all' | 'info' | 'details';
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

const makeId = () => Math.random().toString(36).slice(2, 11);

const makeIngredient = (): RecipeIngredientItem => ({
    id: makeId(),
    text: '',
});

const makeNutrition = (): RecipeNutritionItem => ({
    id: makeId(),
    label: '',
    value: '',
});

const makeDirection = (orderNumber: number): RecipeDirectionItem => ({
    id: makeId(),
    orderNumber,
    title: '',
    image: '',
    imageDescription: '',
    content: '',
});

export const createDefaultRecipeData = (): RecipeData => ({
    optionalUrl: '',
    prepTime: '',
    cookTime: '',
    serving: '',
    difficulty: '',
    videoUrl: '',
    videoEmbedCode: '',
    ingredients: [makeIngredient()],
    nutrition: [makeNutrition()],
    directions: [makeDirection(1)],
});

const normalizeRecipeData = (value: PostItem['recipeData']): RecipeData => {
    const base = createDefaultRecipeData();
    const ingredients = Array.isArray(value?.ingredients) && value.ingredients.length > 0
        ? value.ingredients.map((entry) => ({
            id: entry.id || makeId(),
            text: entry.text || '',
        }))
        : base.ingredients;
    const nutrition = Array.isArray(value?.nutrition) && value.nutrition.length > 0
        ? value.nutrition.map((entry) => ({
            id: entry.id || makeId(),
            label: entry.label || '',
            value: entry.value || '',
        }))
        : base.nutrition;
    const directions = Array.isArray(value?.directions) && value.directions.length > 0
        ? value.directions.map((entry, entryIndex) => ({
            id: entry.id || makeId(),
            orderNumber: Number(entry.orderNumber) || entryIndex + 1,
            title: entry.title || '',
            image: entry.image || '',
            imageDescription: entry.imageDescription || '',
            content: entry.content || '',
        }))
        : base.directions;

    return {
        optionalUrl: value?.optionalUrl || '',
        prepTime: value?.prepTime || '',
        cookTime: value?.cookTime || '',
        serving: value?.serving || '',
        difficulty: value?.difficulty || '',
        videoUrl: value?.videoUrl || '',
        videoEmbedCode: value?.videoEmbedCode || '',
        ingredients,
        nutrition,
        directions,
    };
};

const PostRecipeItem: React.FC<PostRecipeItemProps> = ({
    item,
    displayMode = 'all',
    onUpdate,
    onOpenFileManager,
    onOpenUrlMode,
    onOpenImageEditor,
    onRenameMedia,
}) => {
    const { t } = useLanguage();
    const [collapsedDirections, setCollapsedDirections] = useState<Set<string>>(new Set());
    const recipeData = useMemo(() => normalizeRecipeData(item.recipeData), [item.recipeData]);
    const showInfoSection = displayMode === 'all' || displayMode === 'info';
    const showDetailsSection = displayMode === 'all' || displayMode === 'details';
    const Quill: any = ReactQuill;

    React.useEffect(() => {
        if (!item.recipeData || !Array.isArray(item.recipeData.directions) || item.recipeData.directions.length === 0) {
            onUpdate(item.id, 'recipeData', recipeData);
        }
        // initialize only missing legacy data
        // eslint-disable-next-line react-hooks/exhaustive-deps
    }, []);

    const updateRecipeData = (nextData: RecipeData) => {
        onUpdate(item.id, 'recipeData', nextData);
    };

    const updateField = (field: keyof RecipeData, value: any) => {
        updateRecipeData({ ...recipeData, [field]: value });
    };

    const updateIngredient = (ingredientId: string, value: string) => {
        updateRecipeData({
            ...recipeData,
            ingredients: recipeData.ingredients.map((entry) =>
                entry.id === ingredientId ? { ...entry, text: value } : entry
            ),
        });
    };

    const addIngredient = () => {
        updateRecipeData({ ...recipeData, ingredients: [...recipeData.ingredients, makeIngredient()] });
    };

    const removeIngredient = (ingredientId: string) => {
        const next = recipeData.ingredients.filter((entry) => entry.id !== ingredientId);
        updateRecipeData({ ...recipeData, ingredients: next.length > 0 ? next : [makeIngredient()] });
    };

    const updateNutrition = (nutritionId: string, field: keyof RecipeNutritionItem, value: string) => {
        updateRecipeData({
            ...recipeData,
            nutrition: recipeData.nutrition.map((entry) =>
                entry.id === nutritionId ? { ...entry, [field]: value } : entry
            ),
        });
    };

    const addNutrition = () => {
        updateRecipeData({ ...recipeData, nutrition: [...recipeData.nutrition, makeNutrition()] });
    };

    const removeNutrition = (nutritionId: string) => {
        const next = recipeData.nutrition.filter((entry) => entry.id !== nutritionId);
        updateRecipeData({ ...recipeData, nutrition: next.length > 0 ? next : [makeNutrition()] });
    };

    const updateDirection = (directionId: string, field: keyof RecipeDirectionItem, value: any) => {
        updateRecipeData({
            ...recipeData,
            directions: recipeData.directions.map((direction) =>
                direction.id === directionId ? { ...direction, [field]: value } : direction
            ),
        });
    };

    const addDirection = () => {
        const nextOrder = recipeData.directions.length > 0
            ? Math.max(...recipeData.directions.map((direction) => Number(direction.orderNumber) || 0)) + 1
            : 1;
        updateRecipeData({
            ...recipeData,
            directions: [...recipeData.directions, makeDirection(nextOrder)],
        });
    };

    const removeDirection = (directionId: string) => {
        if (recipeData.directions.length <= 1) return;
        updateRecipeData({
            ...recipeData,
            directions: recipeData.directions
                .filter((direction) => direction.id !== directionId)
                .map((direction, directionIndex) => ({
                    ...direction,
                    orderNumber: directionIndex + 1,
                })),
        });
    };

    const moveDirection = (directionId: string, direction: 'up' | 'down') => {
        const currentIndex = recipeData.directions.findIndex((entry) => entry.id === directionId);
        const targetIndex = direction === 'up' ? currentIndex - 1 : currentIndex + 1;
        if (currentIndex < 0 || targetIndex < 0 || targetIndex >= recipeData.directions.length) return;

        const nextDirections = [...recipeData.directions];
        const current = nextDirections[currentIndex];
        nextDirections[currentIndex] = nextDirections[targetIndex];
        nextDirections[targetIndex] = current;

        updateRecipeData({
            ...recipeData,
            directions: nextDirections.map((entry, entryIndex) => ({
                ...entry,
                orderNumber: entryIndex + 1,
            })),
        });
    };

    const toggleDirection = (directionId: string) => {
        setCollapsedDirections((prev) => {
            const next = new Set(prev);
            if (next.has(directionId)) next.delete(directionId);
            else next.add(directionId);
            return next;
        });
    };

    const renderInfoField = (
        label: string,
        field: keyof RecipeData,
        placeholder: string
    ) => (
        <div className="space-y-1.5">
            <label className="text-[12px] font-black text-palette-tan/60 uppercase tracking-wider">{label}</label>
            <input
                type="text"
                value={String(recipeData[field] || '')}
                onChange={(event) => updateField(field, event.target.value)}
                placeholder={placeholder}
                className="w-full h-11 bg-palette-beige/5 border border-palette-tan/20 rounded-[3px] px-3 text-sm font-bold text-palette-maroon outline-none focus:border-palette-red transition-all placeholder:text-palette-tan/35"
            />
        </div>
    );

    return (
        <div className="space-y-6 animate-in slide-in-from-top-4 duration-500 admin-font">
            {showInfoSection && (
            <div className="space-y-4">
                <div className="flex items-center gap-2">
                    <span className="material-symbols-rounded text-palette-tan/60" style={{ fontSize: '18px' }}>restaurant</span>
                    <label className="text-[12px] font-bold text-palette-tan/60">{t('admin.post.recipe.info_title')}</label>
                </div>
                <div className="grid grid-cols-1 sm:grid-cols-2 xl:grid-cols-4 gap-4">
                    {renderInfoField(t('admin.post.recipe.prep_time'), 'prepTime', t('admin.post.recipe.prep_time_placeholder'))}
                    {renderInfoField(t('admin.post.recipe.cook_time'), 'cookTime', t('admin.post.recipe.cook_time_placeholder'))}
                    {renderInfoField(t('admin.post.recipe.serving'), 'serving', t('admin.post.recipe.serving_placeholder'))}
                    <div className="space-y-1.5">
                        <label className="text-[12px] font-black text-palette-tan/60 uppercase tracking-wider">{t('admin.post.recipe.difficulty')}</label>
                        <select
                            value={recipeData.difficulty || ''}
                            onChange={(event) => updateField('difficulty', event.target.value as RecipeDifficulty)}
                            className="w-full h-11 bg-palette-beige/5 border border-palette-tan/20 rounded-[3px] px-3 text-sm font-bold text-palette-maroon outline-none focus:border-palette-red transition-all"
                        >
                            <option value="">{t('admin.post.recipe.difficulty_select')}</option>
                            <option value="easy">{t('admin.post.recipe.difficulty_easy')}</option>
                            <option value="medium">{t('admin.post.recipe.difficulty_medium')}</option>
                            <option value="hard">{t('admin.post.recipe.difficulty_hard')}</option>
                        </select>
                    </div>
                </div>
            </div>
            )}

            {showDetailsSection && (
            <>
            <div className="grid grid-cols-1 xl:grid-cols-2 gap-5">
                <div className="rounded-[3px] border border-palette-tan/20 bg-white shadow-sm p-5 space-y-4">
                    <div className="flex items-center justify-between gap-3 border-b border-palette-tan/10 pb-3">
                        <div className="flex items-center gap-2">
                            <span className="material-symbols-rounded text-palette-red" style={{ fontSize: '19px' }}>grocery</span>
                            <h4 className="text-base font-black text-palette-maroon">{t('admin.post.recipe.ingredients')}</h4>
                        </div>
                        <button
                            type="button"
                            onClick={addIngredient}
                            className="h-8 px-3 rounded-[3px] bg-emerald-600 text-white text-[10px] font-black uppercase tracking-widest hover:bg-emerald-700 transition-all active:scale-95"
                        >
                            + {t('admin.post.recipe.add_ingredient')}
                        </button>
                    </div>
                    <div className="space-y-3">
                        {recipeData.ingredients.map((ingredient, ingredientIndex) => (
                            <div key={ingredient.id} className="flex items-center gap-3">
                                <span className="w-8 h-8 rounded-[3px] bg-palette-maroon text-white flex items-center justify-center text-xs font-black shrink-0">
                                    {ingredientIndex + 1}
                                </span>
                                <input
                                    type="text"
                                    value={ingredient.text}
                                    onChange={(event) => updateIngredient(ingredient.id, event.target.value)}
                                    placeholder={t('admin.post.recipe.ingredient_placeholder')}
                                    className="w-full h-10 bg-palette-beige/5 border border-palette-tan/20 rounded-[3px] px-3 text-sm font-bold text-palette-maroon outline-none focus:border-palette-red transition-all placeholder:text-palette-tan/30"
                                />
                                <button
                                    type="button"
                                    onClick={() => removeIngredient(ingredient.id)}
                                    className="w-9 h-9 rounded-[3px] text-palette-tan/30 hover:text-white hover:bg-palette-red transition-all flex items-center justify-center"
                                    title={t('common.delete')}
                                >
                                    <span className="material-symbols-rounded" style={{ fontSize: '18px' }}>delete</span>
                                </button>
                            </div>
                        ))}
                    </div>
                    <p className="text-[11px] font-bold text-palette-tan/45">{t('admin.post.recipe.ingredient_example')}</p>
                </div>

                <div className="rounded-[3px] border border-palette-tan/20 bg-white shadow-sm p-5 space-y-4">
                    <div className="flex items-center justify-between gap-3 border-b border-palette-tan/10 pb-3">
                        <div className="flex items-center gap-2">
                            <span className="material-symbols-rounded text-palette-red" style={{ fontSize: '19px' }}>nutrition</span>
                            <h4 className="text-base font-black text-palette-maroon">{t('admin.post.recipe.nutrition')}</h4>
                        </div>
                        <button
                            type="button"
                            onClick={addNutrition}
                            className="h-8 px-3 rounded-[3px] bg-emerald-600 text-white text-[10px] font-black uppercase tracking-widest hover:bg-emerald-700 transition-all active:scale-95"
                        >
                            + {t('admin.post.recipe.add_nutrition')}
                        </button>
                    </div>
                    <div className="space-y-3">
                        {recipeData.nutrition.map((nutrition) => (
                            <div key={nutrition.id} className="grid grid-cols-[minmax(0,1fr)_minmax(0,1fr)_36px] gap-3 items-center">
                                <input
                                    type="text"
                                    value={nutrition.label}
                                    onChange={(event) => updateNutrition(nutrition.id, 'label', event.target.value)}
                                    placeholder={t('admin.post.recipe.nutrition_label_placeholder')}
                                    className="w-full h-10 bg-palette-beige/5 border border-palette-tan/20 rounded-[3px] px-3 text-sm font-bold text-palette-maroon outline-none focus:border-palette-red transition-all placeholder:text-palette-tan/30"
                                />
                                <input
                                    type="text"
                                    value={nutrition.value}
                                    onChange={(event) => updateNutrition(nutrition.id, 'value', event.target.value)}
                                    placeholder={t('admin.post.recipe.nutrition_value_placeholder')}
                                    className="w-full h-10 bg-palette-beige/5 border border-palette-tan/20 rounded-[3px] px-3 text-sm font-bold text-palette-maroon outline-none focus:border-palette-red transition-all placeholder:text-palette-tan/30"
                                />
                                <button
                                    type="button"
                                    onClick={() => removeNutrition(nutrition.id)}
                                    className="w-9 h-9 rounded-[3px] text-palette-tan/30 hover:text-white hover:bg-palette-red transition-all flex items-center justify-center"
                                    title={t('common.delete')}
                                >
                                    <span className="material-symbols-rounded" style={{ fontSize: '18px' }}>delete</span>
                                </button>
                            </div>
                        ))}
                    </div>
                    <p className="text-[11px] font-bold text-palette-tan/45">{t('admin.post.recipe.nutrition_example')}</p>
                </div>
            </div>

            <div className="space-y-6 pt-2">
                <div className="space-y-6">
                    {recipeData.directions.map((direction, directionIndex) => {
                        const isCollapsed = collapsedDirections.has(direction.id);
                        const displayIndex = Number(direction.orderNumber) || directionIndex + 1;

                        return (
                            <div key={direction.id} className="group bg-white rounded-[3px] border border-palette-tan/20 shadow-md flex overflow-hidden animate-in slide-in-from-left duration-300">
                                <div className="w-12 shrink-0 bg-palette-beige/5 border-r border-palette-tan/10 flex flex-col items-center py-6 justify-between transition-colors group-hover:bg-palette-beige/10">
                                    <div className="flex flex-col gap-2 items-center">
                                        {recipeData.directions.length > 1 && (
                                            <>
                                                <button
                                                    type="button"
                                                    onClick={() => moveDirection(direction.id, 'up')}
                                                    disabled={directionIndex === 0}
                                                    className="w-8 h-8 flex items-center justify-center rounded-[3px] text-palette-tan/40 hover:text-palette-maroon hover:bg-white hover:shadow-sm transition-all active:scale-90 disabled:opacity-20 disabled:cursor-not-allowed"
                                                    title={t('common.move_up')}
                                                >
                                                    <span className="material-symbols-rounded rotate-180" style={{ fontSize: '20px' }}>expand_more</span>
                                                </button>
                                                <button
                                                    type="button"
                                                    onClick={() => moveDirection(direction.id, 'down')}
                                                    disabled={directionIndex === recipeData.directions.length - 1}
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
                                        onClick={() => removeDirection(direction.id)}
                                        disabled={recipeData.directions.length <= 1}
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
                                            <h3 className="text-base font-black text-palette-maroon truncate">{t('admin.post.recipe.direction')} #{displayIndex}</h3>
                                        </div>
                                        <button
                                            type="button"
                                            onClick={() => toggleDirection(direction.id)}
                                            className="w-8 h-8 rounded-[3px] flex items-center justify-center text-palette-tan/45 hover:text-palette-maroon hover:bg-palette-beige/20 transition-all"
                                            title={isCollapsed ? t('common.show_all') : t('common.hide_details')}
                                        >
                                            <span className={`material-symbols-rounded transition-transform ${isCollapsed ? '-rotate-90' : ''}`} style={{ fontSize: '19px' }}>expand_more</span>
                                        </button>
                                    </div>

                                    {!isCollapsed && (
                                        <div className="space-y-6">
                                            <div className="space-y-2">
                                                <label className="text-[13px] font-black text-palette-tan ml-1">{t('admin.post.recipe.direction_title')}</label>
                                                <div className="flex items-center gap-3">
                                                    <div className="w-9 h-9 shrink-0 rounded-[3px] bg-palette-maroon text-white flex items-center justify-center text-base font-black shadow-md shadow-palette-maroon/10">
                                                        {displayIndex}
                                                    </div>
                                                    <input
                                                        type="text"
                                                        value={direction.title}
                                                        onChange={(event) => updateDirection(direction.id, 'title', event.target.value)}
                                                        placeholder={t('admin.post.recipe.direction_title_placeholder')}
                                                        className="w-full h-10 bg-palette-beige/5 border border-palette-tan/20 rounded-[3px] px-4 text-base font-bold text-palette-maroon outline-none focus:border-palette-red transition-all placeholder:text-palette-tan/20"
                                                    />
                                                </div>
                                            </div>

                                            <div className="grid grid-cols-1 md:grid-cols-12 gap-6 items-start">
                                                <div className="md:col-span-4 space-y-2">
                                                    <label className="text-[13px] font-black text-palette-tan ml-1 uppercase tracking-wider">{t('admin.post.recipe.direction_image')}</label>
                                                    <div className="rounded-[3px] bg-palette-beige/5 border-2 border-dashed border-palette-tan/20 flex flex-col items-center justify-center overflow-hidden transition-all relative group/image w-full min-h-[220px]">
                                                        {direction.image ? (
                                                            <div className="relative w-full h-full flex items-center justify-center bg-palette-beige/5 min-h-[220px]">
                                                                <img
                                                                    src={direction.image}
                                                                    className="max-w-full max-h-[220px] object-contain block"
                                                                    alt={direction.imageDescription || direction.title}
                                                                />
                                                                <MediaFilenameBadge src={direction.image} type="image" onRename={onRenameMedia} />
                                                                <div className="absolute inset-0 bg-black/40 opacity-0 group-hover/image:opacity-100 transition-all flex items-center justify-center gap-2">
                                                                    <button
                                                                        type="button"
                                                                        onClick={() => onOpenImageEditor(item.id, 'recipeDirections', direction.id)}
                                                                        className="p-3 bg-white/10 backdrop-blur-md rounded-[3px] text-white hover:bg-emerald-600 transition-all flex items-center justify-center"
                                                                        title={t('common.edit')}
                                                                    >
                                                                        <span className="material-symbols-rounded" style={{ fontSize: '20px' }}>edit_square</span>
                                                                    </button>
                                                                    <button
                                                                        type="button"
                                                                        onClick={() => updateDirection(direction.id, 'image', '')}
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
                                                                    onClick={() => onOpenFileManager(item.id, 'recipeDirections', direction.id)}
                                                                    className="flex flex-col items-center cursor-pointer group/pick mb-4"
                                                                >
                                                                    <span className="material-symbols-rounded text-palette-tan/20 group-hover/pick:text-palette-maroon transition-all mb-2" style={{ fontSize: '48px' }}>add</span>
                                                                    <span className="text-[14px] font-bold text-palette-tan/50 px-4 text-center">{t('admin.post.pick_image')}</span>
                                                                </button>
                                                                <button
                                                                    type="button"
                                                                    onClick={() => onOpenUrlMode(item.id, 'recipeDirections', direction.id)}
                                                                    className="mt-2 text-[10px] font-black text-palette-tan/60 hover:text-palette-maroon border border-palette-tan/20 px-3 py-1.5 rounded-[3px] bg-white shadow-sm hover:shadow-md transition-all flex items-center gap-1.5 uppercase tracking-wider"
                                                                >
                                                                    <span className="material-symbols-rounded" style={{ fontSize: '11px' }}>public</span> {t('admin.post.url_or_upload')}
                                                                </button>
                                                            </div>
                                                        )}
                                                    </div>
                                                    <input
                                                        type="text"
                                                        value={direction.imageDescription}
                                                        onChange={(event) => updateDirection(direction.id, 'imageDescription', event.target.value)}
                                                        placeholder={t('admin.post.recipe.image_desc_placeholder')}
                                                        className="w-full bg-palette-beige/5 border border-palette-tan/20 rounded-[3px] px-3 py-2 text-xs font-bold text-palette-maroon outline-none focus:border-palette-red transition-all placeholder:text-palette-tan/25"
                                                    />
                                                </div>

                                                <div className="md:col-span-8 h-full flex flex-col">
                                                    <div className="space-y-2 group/editor flex-1 flex flex-col">
                                                        <div className="flex flex-wrap items-center justify-between gap-2 px-1">
                                                            <label className="text-[13px] font-black text-palette-tan uppercase tracking-wider">{t('admin.post.recipe.direction_content')}</label>
                                                        </div>
                                                        <div className="quill-modern-wrapper compact-quill border border-palette-tan/20 rounded-[3px] overflow-hidden focus-within:border-palette-red/40 transition-all shadow-sm bg-white flex-1 min-h-[220px]">
                                                            <Quill
                                                                theme="snow"
                                                                value={direction.content}
                                                                onChange={(content: string) => updateDirection(direction.id, 'content', content)}
                                                                modules={QUILL_MODULES}
                                                                formats={QUILL_FORMATS}
                                                                placeholder={t('admin.post.recipe.direction_content_placeholder')}
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
                        onClick={addDirection}
                        className="px-8 py-2.5 border-2 border-dashed border-palette-red/30 rounded-[3px] text-palette-red/60 text-[11px] font-black uppercase tracking-widest hover:bg-palette-red/5 hover:border-palette-red transition-all shadow-sm active:scale-95"
                    >
                        + {t('admin.post.recipe.add_direction')}
                    </button>
                </div>
            </div>
            </>
            )}
        </div>
    );
};

export default PostRecipeItem;
