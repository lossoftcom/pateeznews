
import React, { useState, useEffect, useMemo, useRef } from 'react';
import PostTextItem, { type EventData, type EventHighlightItem, type EventRegistrationType, type EventScheduleItem, type EventSpeakerItem, type PostItem, type RecipeData, type RecipeDifficulty, type RecipeDirectionItem, type RecipeIngredientItem, type RecipeNutritionItem, type TocListItem, type TocListStyle } from './PostTextItem';
import PostImageItem from './PostImageItem';
import PostSliderImageItem from './PostSliderImageItem';
import PostVideoItem from './PostVideoItem';
import PostAudioItem from './PostAudioItem';
import PostFileItem from './PostFileItem';
import PostSocialItem from './PostSocialItem';
import PostFlipCardItem from './PostFlipCardItem';
import PostBeforeAfterItem from './PostBeforeAfterItem';
import PostPollItem from './PostPollItem';
import PostVSItem from './PostVSItem';
import PostReviewItem from './PostReviewItem';
import PostQuoteItem from './PostQuoteItem';
import PostIframeItem from './PostIframeItem';
import PostQuizItem from './PostQuizItem';
import PostTableOfContentsItem, { createDefaultTocData } from './PostTableOfContentsItem';
import PostRecipeItem, { createDefaultRecipeData } from './PostRecipeItem';
import PostEventItem, { createDefaultEventData } from './PostEventItem';
import AiAssistantDialog from './AiAssistantDialog';
import MediaFilenameBadge from './MediaFilenameBadge';
import 'react-quill-new/dist/quill.snow.css';
import { useDropzone } from 'react-dropzone';
import { type NavigationItem } from '@/types';
import { neon } from '@/lib/neon';
import { storageService, type MediaItem } from '@/services/storageService';
import { useLanguage } from '@/context/LanguageContext';
import { useToast } from '@/context/ToastContext';
import { SPECIAL_CONTENT_FILTERS, getSpecialContentConfig } from '@/utils/specialContent';

const STORAGE_FILE_MARKER = '/api/storage/file/';
const STORAGE_FILE_TYPES = ['image', 'video', 'audio', 'file', 'logo', 'profile'] as const;
type StorageFileType = typeof STORAGE_FILE_TYPES[number];

const safeDecodeStoragePath = (value: string) => {
    let decoded = value;
    for (let i = 0; i < 3; i++) {
        try {
            const next = decodeURIComponent(decoded);
            if (next === decoded) break;
            decoded = next;
        } catch {
            break;
        }
    }
    return decoded;
};

const stripUrlNoise = (value: string) => value.split(/[?#]/)[0];

const normalizeMediaReferenceForCompare = (value: unknown) => {
    const clean = stripUrlNoise(String(value || ''));
    const markerIndex = clean.indexOf(STORAGE_FILE_MARKER);
    const comparable = markerIndex >= 0 ? clean.slice(markerIndex) : clean;
    return safeDecodeStoragePath(comparable).replace(/\\/g, '/').normalize('NFC');
};

const getStorageFileReference = (src: string): { type: StorageFileType; id: string } | null => {
    if (!src || !src.includes(STORAGE_FILE_MARKER)) return null;

    const cleanSrc = stripUrlNoise(src);
    const markerIndex = cleanSrc.indexOf(STORAGE_FILE_MARKER);
    if (markerIndex < 0) return null;

    const rawPath = safeDecodeStoragePath(cleanSrc.slice(markerIndex + STORAGE_FILE_MARKER.length))
        .replace(/\\/g, '/')
        .replace(/^\/+/, '');
    if (!rawPath || rawPath.includes('\0')) return null;

    const [firstSegment, ...rest] = rawPath.split('/');
    if (STORAGE_FILE_TYPES.includes(firstSegment as StorageFileType) && rest.length > 0) {
        return { type: firstSegment as StorageFileType, id: rest.join('/') };
    }

    return { type: 'image', id: rawPath };
};

const filenameBaseFromStorageId = (id: string) => {
    const filename = id.split('/').pop() || `edited-${Date.now()}`;
    return filename.replace(/\.[a-z0-9]+$/i, '') || `edited-${Date.now()}`;
};

const STORED_TEXT_ENTITY_MAP: Record<string, string> = {
    amp: '&',
    apos: "'",
    Ccedil: 'Ç',
    ccedil: 'ç',
    Gbreve: 'Ğ',
    gbreve: 'ğ',
    hellip: '...',
    Idot: 'İ',
    imath: 'ı',
    laquo: '"',
    ldquo: '"',
    lsquo: "'",
    nbsp: ' ',
    Ouml: 'Ö',
    ouml: 'ö',
    quot: '"',
    raquo: '"',
    rdquo: '"',
    rsquo: "'",
    Scedil: 'Ş',
    scedil: 'ş',
    Uuml: 'Ü',
    uuml: 'ü',
};

const decodeStoredCodePoint = (value: string, radix: number, fallback: string) => {
    const codePoint = Number.parseInt(value, radix);
    if (!Number.isFinite(codePoint) || codePoint <= 0) return fallback;
    if (codePoint === 60 || codePoint === 62) return fallback;
    try {
        return String.fromCodePoint(codePoint);
    } catch {
        return fallback;
    }
};

const decodeStoredTextEntities = (value: unknown) => {
    const decodeOnce = (input: string) => input
        .replace(/&([a-zA-Z][a-zA-Z0-9]+);/g, (match, entity: string) => STORED_TEXT_ENTITY_MAP[entity] ?? match)
        .replace(/&#x([0-9a-fA-F]+);/g, (match, hex: string) => decodeStoredCodePoint(hex, 16, match))
        .replace(/&#(\d+);/g, (match, decimal: string) => decodeStoredCodePoint(decimal, 10, match));

    const raw = String(value ?? '');
    return decodeOnce(decodeOnce(raw)).replace(/\u00a0/g, ' ');
};

const normalizeStoredPlainText = (value: unknown) => decodeStoredTextEntities(value).trim();

const STORED_TEXT_PAYLOAD_KEYS = new Set([
    'title',
    'summary',
    'category',
    'source',
    'author',
    'thumbnailAlt',
    'altText',
    'seoTitle',
    'seoDescription',
    'keywords',
    'blockTitle',
    'label',
    'text',
    'name',
    'question',
    'answer',
    'q',
    'a',
    'frontTitle',
    'backTitle',
    'beforeLabel',
    'afterLabel',
    'productName',
    'quoteAuthor',
]);

const STORED_TEXT_ARRAY_KEYS = new Set(['items', 'pros', 'cons']);

const normalizeStoredPlainTextPayload = <T,>(value: T, key = ''): T => {
    if (typeof value === 'string') {
        return (STORED_TEXT_PAYLOAD_KEYS.has(key) || STORED_TEXT_ARRAY_KEYS.has(key)
            ? normalizeStoredPlainText(value)
            : value) as T;
    }

    if (Array.isArray(value)) {
        return value.map((entry) => normalizeStoredPlainTextPayload(entry, key)) as T;
    }

    if (value && typeof value === 'object') {
        return Object.fromEntries(
            Object.entries(value as Record<string, unknown>)
                .map(([childKey, childValue]) => [childKey, normalizeStoredPlainTextPayload(childValue, childKey)])
        ) as T;
    }

    return value;
};

const htmlToPlainText = (value: unknown) => decodeStoredTextEntities(
    String(value || '')
        .replace(/<style[\s\S]*?<\/style>/gi, ' ')
        .replace(/<script[\s\S]*?<\/script>/gi, ' ')
        .replace(/<[^>]+>/g, ' ')
        .replace(/&nbsp;/g, ' ')
)
    .replace(/\s+/g, ' ')
    .trim();

const FIE_FEATURED_FONTS = ['Montserrat', 'Playfair Display', 'Oswald', 'Space Grotesk'] as const;
const FIE_FEATURED_FONT_SET = new Set(FIE_FEATURED_FONTS.map((font) => font.toLowerCase()));

const FIE_TEXT_FONTS = [
    ...FIE_FEATURED_FONTS,
    'Bebas Neue',
    'Anton',
    'Archivo Black',
    'Fjalla One',
    'Teko',
    'Inter',
    'Roboto',
    'Montserrat',
    'Poppins',
    'Oswald',
    'Raleway',
    'Open Sans',
    'Lato',
    'Roboto Slab',
    'Merriweather',
    'Libre Baskerville',
    'Cormorant Garamond',
    'Source Serif 4',
    'DM Serif Display',
    'Playfair Display',
    'Cinzel',
    'Ubuntu',
    'Arial'
].filter((font, index, arr) => arr.indexOf(font) === index);

const FIE_TEXT_FONT_OPTIONS = FIE_TEXT_FONTS.map((font) => ({
    label: FIE_FEATURED_FONT_SET.has(font.toLowerCase()) ? `${font} ★` : font,
    value: font.toLowerCase()
}));

const FIE_TEXT_DEFAULT_FONT = 'arial';

const FIE_EMOJI_BASE = [
    '😀', '😃', '😄', '😁', '😆', '😅', '😂', '🤣',
    '😊', '😇', '🙂', '🙃', '😉', '😌',
    '😍', '🥰', '😘', '😗', '😙', '😚',
    '😋', '😛', '😜', '🤪', '😝',
    '🤨', '🧐', '🤓', '😎', '🥸',
    '🤩', '🥳',
    '😏', '😒', '😞', '😔', '😟', '😕', '🙁', '☹️',
    '😣', '😖', '😫', '😩', '🥺',
    '😢', '😭',
    '😤', '😠', '😡', '🤬',
    '🤯', '😳',
    '🥵', '🥶',
    '😱', '😨', '😰', '😥', '😓',
    '🤗', '🤔', '🤭', '🤫', '🤥',
    '😶', '😐', '😑', '😬', '🙄',
    '😯', '😦', '😧', '😮', '😲',
    '🥱', '😴', '🤤', '😪',
    '😵', '😵‍💫', '🤐', '🥴',
    '🤢', '🤮', '🤧',
    '😷', '🤒', '🤕',
    '🤑', '🤠',
    '😈', '👿', '👹', '👺', '🤡', '💩', '👻', '👽', '👾', '🤖',
    '🎃',

    '👍', '👎', '👊', '✊', '🤛', '🤜',
    '🤞', '✌️', '🤟', '🤘', '👌', '🤌', '🤏',
    '👋', '🤚', '✋', '🖐️', '🖖',
    '✍️', '🙏', '🤝',
    '💪', '🦾', '🦵', '🦿',
    '👂', '🦻', '👃', '🧠', '🫀', '🫁', '🦷', '🦴',
    '👀', '👁️', '👅', '👄', '🫦',

    '❤️', '🧡', '💛', '💚', '💙', '💜', '🤎', '🖤', '🤍',
    '💔', '❤️‍🔥', '❤️‍🩹',
    '💖', '💗', '💓', '💞', '💕', '💘', '💝', '💟',

    '🚨', '⚡', '🔥', '💥', '💫', '⭐', '🌟', '✨',
    '✅', '☑️', '✔️', '✖️', '❌', '❎',
    '❗', '❕', '❓', '❔', '‼️', '⁉️',
    '🛑',
    '🔴', '🟠', '🟡', '🟢', '🔵', '🟣', '⚫', '⚪',
    '🔶', '🔷', '🔸', '🔹', '🔺', '🔻',
    '➕', '➖', '➗',
    '⬆️', '⬇️', '⬅️', '➡️', '↗️', '↘️', '↙️', '↖️', '⤴️', '⤵️',
    '🔄', '🔃', '🔁', '🔀',

    '☀️', '🌤️', '⛅', '🌥️', '🌦️', '🌧️', '⛈️', '🌩️', '❄️', '🌪️',
    '💧', '🌊', '🌈',

    '📢', '📣', '📰', '🗞️',
    '🎙️', '🎤', '🎧',
    '📸', '🎥', '📽️',
    '🔔', '🔕',
    '💡', '🔦', '🔍', '🔎',
    '🔒', '🔓', '🗝️',
    '📌', '📍', '🧭',
    '🧨', '🎯',
    '🎉', '🎊', '🎈', '🎁',
    '🏆', '🥇', '🥈', '🥉',

    '💰', '💵', '💶', '💷', '💴', '🪙', '💳',
    '📈', '📉',

    '☕', '🍿', '🍔', '🍟', '🍕', '🌭',
    '🍺', '🍷',
] as const;

const FIE_FLAG_COUNTRY_CODES = [
    'AD', 'AE', 'AF', 'AG', 'AI', 'AL', 'AM', 'AO', 'AQ', 'AR', 'AS', 'AT', 'AU', 'AW', 'AX', 'AZ',
    'BA', 'BB', 'BD', 'BE', 'BF', 'BG', 'BH', 'BI', 'BJ', 'BL', 'BM', 'BN', 'BO', 'BQ', 'BR', 'BS', 'BT', 'BV', 'BW', 'BY', 'BZ',
    'CA', 'CC', 'CD', 'CF', 'CG', 'CH', 'CI', 'CK', 'CL', 'CM', 'CN', 'CO', 'CR', 'CU', 'CV', 'CW', 'CX', 'CY', 'CZ',
    'DE', 'DJ', 'DK', 'DM', 'DO', 'DZ',
    'EC', 'EE', 'EG', 'EH', 'ER', 'ES', 'ET',
    'FI', 'FJ', 'FK', 'FM', 'FO', 'FR',
    'GA', 'GB', 'GD', 'GE', 'GF', 'GG', 'GH', 'GI', 'GL', 'GM', 'GN', 'GP', 'GQ', 'GR', 'GS', 'GT', 'GU', 'GW', 'GY',
    'HK', 'HM', 'HN', 'HR', 'HT', 'HU',
    'ID', 'IE', 'IL', 'IM', 'IN', 'IO', 'IQ', 'IR', 'IS', 'IT',
    'JE', 'JM', 'JO', 'JP',
    'KE', 'KG', 'KH', 'KI', 'KM', 'KN', 'KP', 'KR', 'KW', 'KY', 'KZ',
    'LA', 'LB', 'LC', 'LI', 'LK', 'LR', 'LS', 'LT', 'LU', 'LV', 'LY',
    'MA', 'MC', 'MD', 'ME', 'MF', 'MG', 'MH', 'MK', 'ML', 'MM', 'MN', 'MO', 'MP', 'MQ', 'MR', 'MS', 'MT', 'MU', 'MV', 'MW', 'MX', 'MY', 'MZ',
    'NA', 'NC', 'NE', 'NF', 'NG', 'NI', 'NL', 'NO', 'NP', 'NR', 'NU', 'NZ',
    'OM',
    'PA', 'PE', 'PF', 'PG', 'PH', 'PK', 'PL', 'PM', 'PN', 'PR', 'PS', 'PT', 'PW', 'PY',
    'QA',
    'RE', 'RO', 'RS', 'RU', 'RW',
    'SA', 'SB', 'SC', 'SD', 'SE', 'SG', 'SH', 'SI', 'SJ', 'SK', 'SL', 'SM', 'SN', 'SO', 'SR', 'SS', 'ST', 'SV', 'SX', 'SY', 'SZ',
    'TC', 'TD', 'TF', 'TG', 'TH', 'TJ', 'TK', 'TL', 'TM', 'TN', 'TO', 'TR', 'TT', 'TV', 'TW', 'TZ',
    'UA', 'UG', 'UM', 'US', 'UY', 'UZ',
    'VA', 'VC', 'VE', 'VG', 'VI', 'VN', 'VU',
    'WF', 'WS',
    'YE', 'YT',
    'ZA', 'ZM', 'ZW',
    'XK',
] as const;

const countryCodeToFlagEmoji = (countryCode: string) => {
    const code = countryCode.trim().toUpperCase();
    if (!/^[A-Z]{2}$/.test(code)) return '';
    const regionalIndicatorA = 0x1F1E6;
    return String.fromCodePoint(
        ...code.split('').map((char) => regionalIndicatorA + (char.charCodeAt(0) - 65))
    );
};

const FIE_FLAG_EMOJIS = Array.from(
    new Set(FIE_FLAG_COUNTRY_CODES.map(countryCodeToFlagEmoji).filter(Boolean))
);

const FIE_EMOJI_LIST = Array.from(new Set([...FIE_EMOJI_BASE, ...FIE_FLAG_EMOJIS]));

const FIE_EMOJI_TOOL_ID = 'Emoji';
const FIE_EMOJI_TOGGLE_EVENT = 'fie:emoji-toggle';

const FIE_EMOJI_STICKER_CACHE = new Map<string, string>();

type FilerobotDeps = {
    FilerobotEditor: any;
    TABS: any;
    TOOLS: any;
    StyleSheetManager: React.ComponentType<any>;
    isPropValid: (prop: string) => boolean;
    Popper: React.ComponentType<any>;
    EmojiIcon: React.ComponentType<any>;
    ToolsBarItemButton: React.ComponentType<any>;
    useStore: () => any;
    SET_ANNOTATION: any;
    FIE_DEFAULT_TOOLS_ITEMS: Record<string, any>;
};

let filerobotDepsPromise: Promise<FilerobotDeps> | null = null;

const loadFilerobotDeps = () => {
    if (!filerobotDepsPromise) {
        filerobotDepsPromise = (async () => {
            // Filerobot beta ships a few ESM files that call React.createElement without importing React.
            (globalThis as any).React = React;

            const [
                editorModule,
                styledComponentsModule,
                isPropValidModule,
                popperModule,
                iconsModule,
                toolsBarItemButtonModule,
                useStoreModule,
                actionsModule,
                toolsConstantsModule,
            ] = await Promise.all([
                import('react-filerobot-image-editor'),
                import('styled-components'),
                import('@emotion/is-prop-valid'),
                import('@scaleflex/ui/core/popper'),
                import('@scaleflex/icons'),
                import('react-filerobot-image-editor/lib/components/ToolsBar/ToolsBarItemButton'),
                import('react-filerobot-image-editor/lib/hooks/useStore'),
                import('react-filerobot-image-editor/lib/actions'),
                import('react-filerobot-image-editor/lib/components/tools/tools.constants'),
            ]);

            return {
                FilerobotEditor: (editorModule as any).default || editorModule,
                TABS: (editorModule as any).TABS,
                TOOLS: (editorModule as any).TOOLS,
                StyleSheetManager: (styledComponentsModule as any).StyleSheetManager,
                isPropValid: (isPropValidModule as any).default || isPropValidModule,
                Popper: (popperModule as any).default || popperModule,
                EmojiIcon: (iconsModule as any).Emoji,
                ToolsBarItemButton: (toolsBarItemButtonModule as any).default || toolsBarItemButtonModule,
                useStore: (useStoreModule as any).default || useStoreModule,
                SET_ANNOTATION: (actionsModule as any).SET_ANNOTATION,
                FIE_DEFAULT_TOOLS_ITEMS: (toolsConstantsModule as any).TOOLS_ITEMS || {},
            };
        })();
    }
    return filerobotDepsPromise;
};

const createEmojiStickerDataUrl = (emoji: string, sizePx = 128) => {
    if (typeof document === 'undefined') return '';

    const dpr = typeof window !== 'undefined' && typeof window.devicePixelRatio === 'number'
        ? Math.max(1, Math.min(window.devicePixelRatio, 3))
        : 1;

    const cacheKey = `${emoji}|${sizePx}|${dpr}`;
    const cached = FIE_EMOJI_STICKER_CACHE.get(cacheKey);
    if (cached) return cached;

    const canvas = document.createElement('canvas');
    canvas.width = Math.round(sizePx * dpr);
    canvas.height = Math.round(sizePx * dpr);

    const ctx = canvas.getContext('2d');
    if (!ctx) return '';

    ctx.scale(dpr, dpr);
    ctx.clearRect(0, 0, sizePx, sizePx);
    ctx.textAlign = 'center';
    ctx.textBaseline = 'middle';

    const fontSize = Math.round(sizePx * 0.78);
    ctx.font = `${fontSize}px "Apple Color Emoji", "Segoe UI Emoji", "Noto Color Emoji", sans-serif`;
    ctx.fillText(emoji, sizePx / 2, sizePx / 2);

    const url = canvas.toDataURL('image/png');
    FIE_EMOJI_STICKER_CACHE.set(cacheKey, url);
    return url;
};

const createFieEmojiComponents = (deps: FilerobotDeps) => {
    const { EmojiIcon, Popper, SET_ANNOTATION, TOOLS, ToolsBarItemButton, useStore } = deps;

    const FieEmojiToolButton = ({ selectTool, isSelected }: any) => (
        <ToolsBarItemButton
            className="FIE_emoji-tool-button"
            id={FIE_EMOJI_TOOL_ID}
            label="Emoji"
            Icon={EmojiIcon}
            onClick={(toolId: string) => {
                selectTool(toolId);
                if (typeof window !== 'undefined') {
                    window.dispatchEvent(new Event(FIE_EMOJI_TOGGLE_EVENT));
                }
            }}
            isSelected={isSelected}
        />
    );

    const FieEmojiToolOptions = () => {
        const { t } = useLanguage();
        const store: any = useStore();
        const dispatch = store?.dispatch;
        const originalSource = store?.originalSource;
        const shownImageDimensions = store?.shownImageDimensions;
        const crop = store?.adjustments?.crop ?? {};

        const [open, setOpen] = useState(true);
        const [tab, setTab] = useState<'emoji' | 'flags'>('emoji');
        const [anchorEl, setAnchorEl] = useState<HTMLElement | null>(null);

        useEffect(() => {
            if (typeof document === 'undefined') return;
            const el = document.querySelector(
                `[data-testid="FIE-tools-bar-item-button-${FIE_EMOJI_TOOL_ID.toLowerCase()}"]`
            ) as HTMLElement | null;
            setAnchorEl(el);
        }, []);

        useEffect(() => {
            if (typeof window === 'undefined') return;
            const handler = () => setOpen(true);
            window.addEventListener(FIE_EMOJI_TOGGLE_EVENT, handler);
            return () => window.removeEventListener(FIE_EMOJI_TOGGLE_EVENT, handler);
        }, []);

        const items = tab === 'flags' ? FIE_FLAG_EMOJIS : (FIE_EMOJI_BASE as unknown as string[]);

        const addSticker = React.useCallback((emoji: string) => {
            const dataUrl = createEmojiStickerDataUrl(emoji, 128);
            if (!dataUrl || typeof Image === 'undefined' || typeof dispatch !== 'function') return;

            const img = new Image();
            img.onload = () => {
                const initialScale = shownImageDimensions?.originalSourceInitialScale || 1;
                const baseWidth = (crop?.width ? crop.width / initialScale : undefined) || originalSource?.width || 0;
                const baseHeight = (crop?.height ? crop.height / initialScale : undefined) || originalSource?.height || 0;
                const baseX = (crop?.x ? crop.x / initialScale : undefined) || 0;
                const baseY = (crop?.y ? crop.y / initialScale : undefined) || 0;

                const spacing = 0.15;
                const fitScale = Math.min(
                    1,
                    baseWidth / (img.width + img.width * spacing),
                    baseHeight / (img.height + img.height * spacing)
                );

                dispatch({
                    type: SET_ANNOTATION,
                    payload: {
                        name: TOOLS.IMAGE,
                        image: img,
                        x: baseX + baseWidth / 2 - (img.width * fitScale) / 2,
                        y: baseY + baseHeight / 2 - (img.height * fitScale) / 2,
                        width: img.width * fitScale,
                        height: img.height * fitScale,
                        opacity: 1,
                        selectOnSet: false,
                    },
                });

                setOpen(false);
            };
            img.src = dataUrl;
        }, [dispatch, shownImageDimensions?.originalSourceInitialScale, crop?.width, crop?.height, crop?.x, crop?.y, originalSource?.width, originalSource?.height]);

        return (
            <div className="FIE_emoji-tool-options" style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
                <button
                    type="button"
                    onClick={() => { setTab('emoji'); setOpen(true); }}
                    style={{
                        border: '1px solid rgba(0,0,0,0.12)',
                        borderRadius: 4,
                        padding: '6px 10px',
                        background: tab === 'emoji' ? 'rgba(0,0,0,0.04)' : '#fff',
                        fontSize: 12,
                        fontWeight: 700,
                        cursor: 'pointer',
                    }}
                >
                    {t('admin.post.emoji_tab.emojis')}
                </button>
                <button
                    type="button"
                    onClick={() => { setTab('flags'); setOpen(true); }}
                    style={{
                        border: '1px solid rgba(0,0,0,0.12)',
                        borderRadius: 4,
                        padding: '6px 10px',
                        background: tab === 'flags' ? 'rgba(0,0,0,0.04)' : '#fff',
                        fontSize: 12,
                        fontWeight: 700,
                        cursor: 'pointer',
                    }}
                >
                    {t('admin.post.emoji_tab.flags')}
                </button>
                <button
                    type="button"
                    onClick={() => setOpen((v) => !v)}
                    style={{
                        border: '1px solid rgba(0,0,0,0.12)',
                        borderRadius: 4,
                        padding: '6px 10px',
                        background: '#fff',
                        fontSize: 12,
                        fontWeight: 700,
                        cursor: 'pointer',
                    }}
                >
                    {open ? t('common.close_action') : t('common.open_action')}
                </button>

                <Popper
                    className="FIE_emoji-picker"
                    anchorEl={anchorEl}
                    open={open && !!anchorEl}
                    position="top"
                    overlay
                    onClick={() => setOpen(false)}
                    wrapperStyles={{ maxWidth: 520 }}
                >
                    <div style={{ background: '#fff', borderRadius: 6, padding: 8, maxWidth: 520, maxHeight: 360, overflow: 'auto' }}>
                        <div style={{ display: 'grid', gridTemplateColumns: 'repeat(12, 1fr)', gap: 6 }}>
                            {items.map((emoji) => (
                                <button
                                    key={`${tab}-${emoji}`}
                                    type="button"
                                    onClick={() => addSticker(emoji)}
                                    style={{
                                        width: 34,
                                        height: 34,
                                        border: '1px solid rgba(0,0,0,0.08)',
                                        borderRadius: 6,
                                        background: '#fff',
                                        cursor: 'pointer',
                                        fontSize: 20,
                                        lineHeight: '32px',
                                        padding: 0,
                                    }}
                                    aria-label={emoji}
                                >
                                    {emoji}
                                </button>
                            ))}
                        </div>
                    </div>
                </Popper>
            </div>
        );
    };

    return { FieEmojiToolButton, FieEmojiToolOptions };
};

const SC_DOM_PROP_BLOCKLIST = new Set([
    'showTabsDrawer',
    'isPhoneScreen',
    'noMargin',
    'active',
    'showBackButton',
    'hasChildren',
    'fullWidth',
    'isValueExists',
    'hideEllipsis',
    'watermarkTool',
    'maxWidth',
    'icon',
    'isWarning',
    'isError',
    'primary',
    'variant',
    'iconShadow',
    'alignment',
    'align',
    'warning',
]);

// SC v6 filter: only filter DOM props, forward all props to custom components.
const createShouldForwardProp = (isPropValidFn: (prop: string) => boolean) =>
    (prop: string, elementToBeRendered: unknown) => {
        if (prop.startsWith('$')) return false; // transient props
        if (typeof elementToBeRendered === 'string') {
            return isPropValidFn(prop) && !SC_DOM_PROP_BLOCKLIST.has(prop);
        }
        return true;
    };

// Premium Quill Overrides
const QUILL_CUSTOM_STYLE = `
  .quill-modern-wrapper .ql-toolbar.ql-snow {
    border: none !important;
    background: #fdfaf5 !important;
    border-bottom: 1px solid #e8e2d9 !important;
    padding: 12px 16px !important;
    border-radius: 3px 3px 0 0 !important;
  }
  .quill-modern-wrapper .ql-container.ql-snow {
    border: none !important;
    font-family: inherit !important;
    font-size: 15px !important;
    color: #4a0404 !important;
    min-height: 200px !important;
  }
  .quill-modern-wrapper.compact-quill .ql-container.ql-snow {
    min-height: 140px !important;
  }
  .quill-modern-wrapper .ql-editor {
    padding: 24px !important;
    line-height: 1.6 !important;
  }
  .quill-modern-wrapper .ql-editor.ql-blank::before {
    color: rgba(140, 120, 100, 0.3) !important;
    font-style: normal !important;
    font-weight: 500 !important;
    left: 24px !important;
  }
  .quill-modern-wrapper .ql-snow .ql-stroke {
    stroke: #8c7864 !important;
  }
  .quill-modern-wrapper .ql-snow .ql-fill {
    fill: #8c7864 !important;
  }
  .quill-modern-wrapper .ql-snow .ql-picker {
    color: #8c7864 !important;
    font-weight: 600 !important;
  }
`;

interface Language {
    code: string;
    name: string;
}

interface PostManagementProps {
    postId?: string;
    onBack?: () => void;
    onDirtyChange?: (isDirty: boolean) => void;
}

const SCHEMA_TYPE_OPTIONS = [
    'NewsArticle',
    'ReportageNewsArticle',
    'OpinionNewsArticle',
    'AnalysisNewsArticle',
    'LiveBlogPosting',
    'BlogPosting',
    'Article',
    'Quiz',
    'Recipe',
    'Event',
] as const;

const normalizeNavigationOptionKey = (value: unknown) =>
    String(value || '')
        .toLocaleLowerCase('tr-TR')
        .normalize('NFD')
        .replace(/[\u0300-\u036f]/g, '')
        .replace(/ı/g, 'i')
        .replace(/ş/g, 's')
        .replace(/ğ/g, 'g')
        .replace(/ç/g, 'c')
        .replace(/ö/g, 'o')
        .replace(/ü/g, 'u')
        .replace(/[^a-z0-9]+/g, '-')
        .replace(/^-+|-+$/g, '');

const ADMIN_SPECIAL_CATEGORY_FILTERS = SPECIAL_CONTENT_FILTERS;
const ADMIN_NORMAL_CATEGORY_FILTERS = [
    { label: 'Spor', value: 'spor', icon: 'sports_soccer', rank: 7 },
];

const normalizeAiNewlines = (value: unknown) =>
    String(value ?? '').replace(/\r\n/g, '\n').replace(/\r/g, '\n');

const escapeHtml = (value: string) =>
    value
        .replace(/&/g, '&amp;')
        .replace(/</g, '&lt;')
        .replace(/>/g, '&gt;')
        .replace(/"/g, '&quot;')
        .replace(/'/g, '&#39;');

const stripMarkdownEmphasis = (value: string) =>
    String(value || '')
        .replace(/\*\*(.+?)\*\*/g, '$1')
        .replace(/__(.+?)__/g, '$1')
        .replace(/\*(.+?)\*/g, '$1')
        .replace(/\*\*/g, '')
        .replace(/__/g, '')
        .trim();

const stripMarkdownHeadingPrefix = (value: string) =>
    String(value || '').replace(/^#{1,6}\s*/, '').trim();

const markdownInlineToSafeHtml = (value: string) => {
    const escaped = escapeHtml(String(value || ''));
    return escaped
        .replace(/\*\*(.+?)\*\*/g, '<strong>$1</strong>')
        .replace(/\*\*/g, '')
        .replace(/__/g, '');
};

const buildQuillHtmlFromLines = (lines: string[]) => {
    const htmlParts: string[] = [];
    let inList: 'ul' | 'ol' | null = null;
    let paragraphBuf: string[] = [];

    const flushParagraph = () => {
        const joined = paragraphBuf.join(' ').trim();
        if (!joined) {
            paragraphBuf = [];
            return;
        }
        htmlParts.push(`<p>${markdownInlineToSafeHtml(joined)}</p>`);
        paragraphBuf = [];
    };

    const closeList = () => {
        if (!inList) return;
        htmlParts.push(inList === 'ol' ? '</ol>' : '</ul>');
        inList = null;
    };

    const normalized = (Array.isArray(lines) ? lines : []).map((l) => String(l ?? ''));
    for (const rawLine of normalized) {
        const trimmed = rawLine.trim();
        if (!trimmed) {
            flushParagraph();
            closeList();
            continue;
        }

        const ulMatch = trimmed.match(/^[-*•–]\s+(.+)$/);
        const olMatch = trimmed.match(/^\d+\.\s+(.+)$/);
        const listValue = (ulMatch?.[1] || olMatch?.[1] || '').trim();

        if (listValue) {
            flushParagraph();
            const nextType: 'ul' | 'ol' = ulMatch ? 'ul' : 'ol';
            if (inList && inList !== nextType) closeList();
            if (!inList) {
                htmlParts.push(nextType === 'ol' ? '<ol>' : '<ul>');
                inList = nextType;
            }
            htmlParts.push(`<li>${markdownInlineToSafeHtml(listValue)}</li>`);
            continue;
        }

        closeList();
        paragraphBuf.push(trimmed);
    }

    flushParagraph();
    closeList();

    return htmlParts.join('');
};

const normalizeQuillEmpty = (value: unknown) => {
    const html = String(value || '').trim();
    if (!html) return '';
    if (html === '<p><br></p>' || html === '<p></p>') return '';
    return html;
};

const parseSmartBrevitySummary = (rawSummary: string) => {
    const normalized = normalizeAiNewlines(rawSummary).trim();
    const lines = normalized
        .split('\n')
        .map((l) => l.trim())
        .filter(Boolean);

    const normalizeLine = (line: string) => stripMarkdownEmphasis(line).replace(/^[-*•–]\s*/, '').trim();
    const isYeni = (line: string) => /yeni\s*ne\s*var/i.test(line);
    const isNeden = (line: string) => /neden\s*önemli/i.test(line);
    const isLabelLine = (line: string) => isYeni(line) || isNeden(line);

    const splitLineIntoEmojiBullets = (input: string) => {
        const text = String(input ?? '').trim();
        if (!text) return [] as string[];

        const bulletStartRe = /\p{Extended_Pictographic}\uFE0F?\s*[^:\n]{2,120}:\s*/gu;
        const starts = Array.from(text.matchAll(bulletStartRe))
            .map((m) => m.index)
            .filter((idx): idx is number => typeof idx === 'number');

        if (starts.length <= 1) return [text];

        const parts: string[] = [];
        if (starts[0] > 0) {
            const prefix = text.slice(0, starts[0]).trim();
            if (prefix) parts.push(prefix);
        }

        for (let i = 0; i < starts.length; i++) {
            const start = starts[i];
            const end = i + 1 < starts.length ? starts[i + 1] : text.length;
            const part = text.slice(start, end).trim();
            if (part) parts.push(part);
        }

        return parts.length > 0 ? parts : [text];
    };

    const extractValueAfterColon = (line: string) => {
        const cleaned = normalizeLine(line);
        const parts = cleaned.split(/:\s*/);
        if (parts.length < 2) return '';
        return parts.slice(1).join(':').trim();
    };

    const expandedLines = lines
        .map(normalizeLine)
        .flatMap((l) => splitLineIntoEmojiBullets(l))
        .map((l) => String(l ?? '').trim())
        .filter(Boolean);

    const yeniLine = expandedLines.find((l) => isYeni(l));
    const nedenLine = expandedLines.find((l) => isNeden(l));

    const spotLines = expandedLines
        .filter((l) => l && !isLabelLine(l));

    const spot = spotLines.join('\n').trim();

    return {
        spot,
        yeniNeVar: yeniLine ? extractValueAfterColon(yeniLine) : '',
        nedenOnemli: nedenLine ? extractValueAfterColon(nedenLine) : '',
    };
};

type AiContentBlock =
    | { kind: 'text'; title: string; lines: string[]; blockNo?: number }
    | { kind: 'image'; title: string; caption: string; altText?: string }
    | { kind: 'video'; title: string; caption: string }
    | { kind: 'audio'; title: string; caption: string };

const parseAiContentBlocks = (rawContent: string): AiContentBlock[] => {
    const normalized = normalizeAiNewlines(rawContent);
    const lines = normalized.split('\n');

    const blocks: AiContentBlock[] = [];
    let currentTitle = '';
    let currentLines: string[] = [];
    let currentTextBlockNo: number | null = null;
    let capturedSpotLines: string[] = [];

    const flushText = () => {
        const title = stripMarkdownEmphasis(currentTitle);
        const bodyLines = currentLines.map((l) => String(l ?? '')).filter((l) => l !== undefined);
        const hasBody = bodyLines.some((l) => l.trim());
        if (!title && !hasBody) {
            currentTitle = '';
            currentLines = [];
            return;
        }
        blocks.push({ kind: 'text', title, lines: bodyLines, blockNo: currentTextBlockNo || undefined });
        currentTitle = '';
        currentLines = [];
    };

    const normalizeTrKey = (value: string) =>
        String(value || '')
            .toLocaleLowerCase('tr-TR')
            .normalize('NFD')
            .replace(/[\u0300-\u036f]/g, '')
            .replace(/ı/g, 'i')
            .replace(/ş/g, 's')
            .replace(/ğ/g, 'g')
            .replace(/ç/g, 'c')
            .replace(/ö/g, 'o')
            .replace(/ü/g, 'u')
            .replace(/\s+/g, ' ')
            .trim();

    const parseItemMarkerLine = (input: string) => {
        const trimmed = String(input ?? '').trim();
        if (!trimmed) return null;

        // Preferred format: [İTEM: ...]
        if (trimmed.startsWith('[')) {
            const closeIdx = trimmed.indexOf(']');
            if (closeIdx !== -1) {
                const inside = trimmed.slice(1, closeIdx).trim();
                const restRaw = trimmed.slice(closeIdx + 1).trim();

                const colonIdx = inside.indexOf(':');
                if (colonIdx !== -1) {
                    const prefix = inside.slice(0, colonIdx).trim();
                    const markerRaw = inside.slice(colonIdx + 1).trim();

                    if (normalizeTrKey(prefix) === 'item' && markerRaw) {
                        return { markerRaw, restRaw };
                    }
                }
            }
        }

        // Fallback (no brackets): İTEM: ...
        const colonIdx = trimmed.indexOf(':');
        if (colonIdx !== -1) {
            const prefix = trimmed.slice(0, colonIdx).trim();
            const markerRaw = trimmed.slice(colonIdx + 1).trim();
            if (normalizeTrKey(prefix) === 'item' && markerRaw) {
                return { markerRaw, restRaw: '' };
            }
        }

        return null;
    };

    const parseMediaDetailLine = (input: string) => {
        const cleaned = stripMarkdownEmphasis(String(input || '')).replace(/^[-*•–]\s*/, '').trim();
        const colonIdx = cleaned.indexOf(':');
        if (colonIdx === -1) return null;
        const keyRaw = cleaned.slice(0, colonIdx).trim();
        const valueRaw = cleaned.slice(colonIdx + 1).trim();
        if (!keyRaw || !valueRaw) return null;

        const key = normalizeTrKey(keyRaw);
        const value = valueRaw.trim();
        if (!value) return null;

        if (key.includes('medya') && (key.includes('baslik') || key.includes('baslig'))) return { field: 'title' as const, value };
        if (key.includes('alt') && key.includes('aciklama')) return { field: 'caption' as const, value };
        if (key.includes('tasvir') || key.includes('talimat')) return { field: 'altText' as const, value };
        return null;
    };

    const isMediaDetailCandidateLine = (input: string) => {
        const cleaned = stripMarkdownEmphasis(String(input || '')).trim();
        return /^[-*•–]\s*[^:]{2,}:\s*.+/.test(cleaned);
    };

    const parseMediaDetails = (detailLines: string[]) => {
        let title = '';
        let caption = '';
        let altText = '';
        const fallbacks: string[] = [];

        for (const line of detailLines) {
            const parsed = parseMediaDetailLine(line);
            if (parsed?.field === 'title') {
                title = parsed.value;
                continue;
            }
            if (parsed?.field === 'caption') {
                caption = parsed.value;
                continue;
            }
            if (parsed?.field === 'altText') {
                altText = parsed.value;
                continue;
            }

            const cleaned = stripMarkdownEmphasis(String(line || '')).replace(/^[-*•–]\s*/, '').trim();
            if (cleaned) fallbacks.push(cleaned);
        }

        if (!caption && fallbacks.length > 0) caption = fallbacks.join(' ');

        return {
            title: stripMarkdownEmphasis(title),
            caption: stripMarkdownEmphasis(caption),
            altText: stripMarkdownEmphasis(altText),
        };
    };

    const extractTextBlockTitleFromMarker = (markerRaw: string) => {
        const cleaned = stripMarkdownHeadingPrefix(stripMarkdownEmphasis(markerRaw || ''));
        const match = cleaned.match(/\d+\s*[-–—:|]\s*(.+)$/);
        return stripMarkdownHeadingPrefix(stripMarkdownEmphasis(match?.[1] || '')).trim();
    };

    // Supports:
    // [BURAYA İLGİLİ GÖRSEL GELECEK: ...]
    // [BURAYA İLGİLİ GRAFİK GELECEK: ...]
    // [BURAYA İLGİLİ GÖRSEL/GRAFİK GELECEK: ...]
    const imagePlaceholderRegex = /^\[?\s*BURAYA\s+İLGİLİ\s+(?:GÖRSEL(?:\s*\/\s*GRAF[İI]K)?|GRAF[İI]K)\s+GELECEK\s*:\s*(.+?)\s*\]?\s*$/i;

    const trimEdgeEmptyLines = (value: string[]) => {
        const arr = Array.isArray(value) ? value.map((v) => String(v ?? '')) : [];
        let start = 0;
        let end = arr.length;
        while (start < end && !arr[start].trim()) start++;
        while (end > start && !arr[end - 1].trim()) end--;
        return arr.slice(start, end);
    };

    const splitSpotLineIntoEmojiBullets = (input: string) => {
        const text = String(input ?? '').trim();
        if (!text) return [] as string[];

        const bulletStartRe = /\p{Extended_Pictographic}\uFE0F?\s*[^:\n]{2,120}:\s*/gu;
        const starts = Array.from(text.matchAll(bulletStartRe))
            .map((m) => m.index)
            .filter((idx): idx is number => typeof idx === 'number');

        if (starts.length <= 1) return [text];

        const parts: string[] = [];
        if (starts[0] > 0) {
            const prefix = text.slice(0, starts[0]).trim();
            if (prefix) parts.push(prefix);
        }

        for (let i = 0; i < starts.length; i++) {
            const start = starts[i];
            const end = i + 1 < starts.length ? starts[i + 1] : text.length;
            const part = text.slice(start, end).trim();
            if (part) parts.push(part);
        }

        return parts.length > 0 ? parts : [text];
    };

    const isListLine = (value: string) => /^[-*•–]\s+/.test(value) || /^\d+\.\s+/.test(value);

    const formatSpotLinesForQuill = (lines: string[]) => {
        const expanded: string[] = [];
        for (const rawLine of Array.isArray(lines) ? lines : []) {
            const trimmed = String(rawLine ?? '').trim();
            if (!trimmed) {
                expanded.push('');
                continue;
            }
            const parts = splitSpotLineIntoEmojiBullets(trimmed);
            if (parts.length > 0) expanded.push(...parts);
        }

        const out: string[] = [];
        for (const rawLine of expanded) {
            const trimmed = String(rawLine ?? '').trim();
            if (!trimmed) {
                if (out.length > 0 && out[out.length - 1] !== '') out.push('');
                continue;
            }

            const prev = out.length > 0 ? String(out[out.length - 1] ?? '').trim() : '';
            const prevIsList = prev ? isListLine(prev) : false;
            const currIsList = isListLine(trimmed);

            // Force separate paragraphs for non-list SPOT lines (emoji bullets etc.)
            if (prev && !prevIsList && !currIsList) out.push('');

            out.push(trimmed);
        }

        return trimEdgeEmptyLines(out);
    };

    for (let i = 0; i < lines.length; i++) {
        const rawLine = String(lines[i] ?? '');
        let line = rawLine.trim();

        if (!line) {
            currentLines.push('');
            continue;
        }

        const markerInfo = parseItemMarkerLine(line);
        if (markerInfo) {
            const markerRaw = stripMarkdownEmphasis(markerInfo.markerRaw || '');
            const restRaw = String(markerInfo.restRaw || '').trim();
            const marker = normalizeTrKey(markerRaw);

            const isMedia = marker.includes('medya');
            const isVideo = marker.includes('video');
            const isAudio = marker.includes('ses') || marker.includes('audio');
            const isImage = marker.includes('gorsel') || marker.includes('grafik') || marker.includes('resim') || marker.includes('foto');
            const isImageSuggestion = marker.includes('gorsel') && marker.includes('oneri');
            const isTextBlockMarker = marker.includes('metin blok');
            const isSpotSection = marker.includes('spot') || marker.includes('ozet');
            let nextTextBlockNo: number | null = null;

            if (isTextBlockMarker) {
                const match = marker.match(/metin blok\s*(\d+)/i);
                if (match) {
                    const parsedNo = Number(match[1]);
                    if (Number.isFinite(parsedNo) && parsedNo > 0) nextTextBlockNo = parsedNo;
                }
            }

            const shouldSkipSection =
                !isMedia &&
                !isTextBlockMarker &&
                (
                    marker === 'baslik' ||
                    marker.startsWith('seo') ||
                    marker.includes('seo ') ||
                    marker.includes('seo meta')
                );

            if (isTextBlockMarker) {
                // Split blocks and move SPOT under block-1 at the end (handled later).
                // Important: flush before changing the active text block number.
                flushText();
                if (nextTextBlockNo) currentTextBlockNo = nextTextBlockNo;
                currentTitle = extractTextBlockTitleFromMarker(markerRaw);
                if (!restRaw) continue;
                line = restRaw;
            }

            if (isMedia && (isVideo || isAudio || isImage)) {
                flushText();

                const detailLines: string[] = [];
                if (restRaw) detailLines.push(restRaw);

                let j = i + 1;
                for (; j < lines.length; j++) {
                    const next = String(lines[j] ?? '').trim();
                    if (!next) continue;
                    if (parseItemMarkerLine(next)) break;

                    const parsed = parseMediaDetailLine(next);
                    if (!parsed && !isMediaDetailCandidateLine(next)) break;
                    detailLines.push(next);
                }

                const details = parseMediaDetails(detailLines);
                const title = details.title || '';
                const caption = details.caption || '';
                const altText = details.altText || '';

                if (isImage) {
                    blocks.push({ kind: 'image', title, caption, altText: altText || caption || '' });
                } else if (isVideo) {
                    blocks.push({ kind: 'video', title, caption });
                } else if (isAudio) {
                    blocks.push({ kind: 'audio', title, caption });
                }

                i = j - 1;
                continue;
            }

            if (isSpotSection) {
                flushText();

                const collected: string[] = [];
                if (restRaw) collected.push(restRaw);

                let j = i + 1;
                for (; j < lines.length; j++) {
                    const nextRaw = String(lines[j] ?? '');
                    const nextTrim = nextRaw.trim();
                    if (parseItemMarkerLine(nextTrim)) break;
                    collected.push(nextTrim);
                }

                const trimmedCollected = trimEdgeEmptyLines(collected);
                if (trimmedCollected.some((l) => l.trim())) capturedSpotLines = trimmedCollected;

                i = j - 1;
                continue;
            }

            if (isImageSuggestion) {
                flushText();

                let caption = restRaw;
                let j = i + 1;
                if (!caption) {
                    while (j < lines.length) {
                        const next = String(lines[j] ?? '').trim();
                        if (!next) {
                            j++;
                            continue;
                        }
                        if (parseItemMarkerLine(next)) break;
                        caption = next;
                        j++;
                        break;
                    }
                }

                caption = stripMarkdownEmphasis(caption)
                    .replace(/^\(\s*/, '')
                    .replace(/\s*\)$/, '')
                    .trim();

                if (caption) blocks.push({ kind: 'image', title: '', caption, altText: caption });

                i = j - 1;
                continue;
            }

            if (shouldSkipSection) {
                flushText();

                let j = i + 1;
                for (; j < lines.length; j++) {
                    const next = String(lines[j] ?? '').trim();
                    if (!next) continue;
                    if (parseItemMarkerLine(next)) break;
                }

                i = j - 1;
                continue;
            }

            if (!isTextBlockMarker) {
                // Non-media markers are structural only; split blocks and keep any inline remainder.
                flushText();
                if (!restRaw) continue;
                line = restRaw;
            }
        }

        const imageMatch = line.match(imagePlaceholderRegex);
        if (imageMatch) {
            flushText();
            const caption = stripMarkdownEmphasis(imageMatch[1] || '');
            if (caption) blocks.push({ kind: 'image', title: '', caption, altText: caption });
            continue;
        }

        const boldHeadingMatch = line.match(/^\*\*(.+?)\*\*$/);
        const hashHeadingMatch = line.match(/^#{2,6}\s+(.+)$/);
        const heading = stripMarkdownEmphasis(boldHeadingMatch?.[1] || hashHeadingMatch?.[1] || '');

        if (heading) {
            if (currentTitle && !currentLines.some((l) => String(l || '').trim())) {
                currentTitle = heading;
                continue;
            }
            flushText();
            currentTitle = heading;
            continue;
        }

        currentLines.push(line);
    }

    flushText();

    // Merge [İTEM: SPOT / ÖZET] into [İTEM: METİN BLOK 1 - GİRİŞ] and keep it at the bottom.
    if (capturedSpotLines.length > 0) {
        const spotLines = formatSpotLinesForQuill(trimEdgeEmptyLines(capturedSpotLines));
        if (spotLines.length > 0) {
            const block1Indices = blocks
                .map((b, idx) => (b.kind === 'text' && (b as any)?.blockNo === 1 ? idx : -1))
                .filter((idx) => idx !== -1);
            const targetIdx = block1Indices.length > 0
                ? block1Indices[block1Indices.length - 1]
                : blocks.findIndex((b) => b.kind === 'text');

            if (targetIdx !== -1) {
                const target = blocks[targetIdx] as any;
                const existingLines = Array.isArray(target?.lines) ? target.lines.map((l: any) => String(l ?? '')) : [];
                const hasExisting = existingLines.some((l: string) => l.trim());
                target.lines = [...existingLines, ...(hasExisting ? [''] : []), ...spotLines];
            }
        }
    }

    return blocks;
};

const buildItemsFromAiContent = (rawContent: string) => {
    const blocks = parseAiContentBlocks(String(rawContent || ''));
    const items: PostItem[] = [];

    const now = Date.now();
    const makeId = (type: string) => `${type}-${Math.random().toString(36).slice(2, 10)}`;

    blocks.forEach((block) => {
        if (block.kind === 'image') {
            const caption = block.caption.trim();
            const captionHtml = caption ? `<p>${markdownInlineToSafeHtml(caption)}</p>` : '';
            const title = stripMarkdownHeadingPrefix(stripMarkdownEmphasis(block.title || ''));
            const altText = stripMarkdownEmphasis(block.altText || caption || '');
            items.push({
                id: makeId('image'),
                type: 'image',
                title,
                description: captionHtml,
                mediaUrl: '',
                altText,
                source: '',
                createdAt: now,
                orderNumber: items.length + 1,
            });
            return;
        }

        if (block.kind === 'video' || block.kind === 'audio') {
            const caption = block.caption.trim();
            const captionHtml = caption ? `<p>${markdownInlineToSafeHtml(caption)}</p>` : '';
            const title = stripMarkdownHeadingPrefix(stripMarkdownEmphasis(block.title || ''));
            const type = block.kind;
            items.push({
                id: makeId(type),
                type,
                title,
                description: captionHtml,
                mediaUrl: '',
                source: '',
                createdAt: now,
                orderNumber: items.length + 1,
            });
            return;
        }

        const html = buildQuillHtmlFromLines(block.lines);
        items.push({
            id: makeId('text'),
            type: 'text',
            title: block.title || '',
            description: html,
            mediaUrl: '',
            createdAt: now,
            orderNumber: items.length + 1,
        });
    });

    return items;
};

const makeGeneratedId = (prefix: string) => `${prefix}-${Math.random().toString(36).slice(2, 10)}`;

const hasHtmlTags = (value: string) => /<\/?[a-z][\s\S]*>/i.test(value);

const normalizeAiHtml = (value: unknown) => {
    const raw = String(value ?? '').trim();
    if (!raw) return '';
    if (hasHtmlTags(raw)) return raw;
    return `<p>${markdownInlineToSafeHtml(stripMarkdownEmphasis(raw))}</p>`;
};

const normalizeRecipeAiContentForItems = (value: unknown) => {
    const panelLabelRe = /^(?:haber\s*başlığı|haber\s*basligi|başlık|baslik|kısa\s*özet|kisa\s*ozet|spot|meta\s*başlık|meta\s*baslik|meta\s*açıklama|meta\s*aciklama|url\s*(?:slug|uzantısı|uzantisi)|slug|schema(?:\.org)?(?:\s*türü|\s*turu)?|odak\s*anahtar\s*kelimeler|anahtar\s*kelimeler|seo(?:\s*&\s*ai)?|sıkça\s*sorulan\s*sorular|sikca\s*sorulan\s*sorular|faq|malzemeler|tarif\s*ayarları|tarif\s*ayarlari|hazırlık\s*süresi|hazirlik\s*suresi|pişirme\s*süresi|pisirme\s*suresi|porsiyon|zorluk|adım\s*adım|adim\s*adim|hazırlanışı|hazirlanisi|yapılış|yapilis|püf\s*noktaları|puf\s*noktalari|besin\s*değerleri|besin\s*degerleri)\b/i;
    const labelsThatOwnNextLineRe = /^(?:haber\s*başlığı|haber\s*basligi|başlık|baslik|kısa\s*özet|kisa\s*ozet|spot|meta\s*başlık|meta\s*baslik|meta\s*açıklama|meta\s*aciklama|url\s*(?:slug|uzantısı|uzantisi)|slug|schema(?:\.org)?(?:\s*türü|\s*turu)?|odak\s*anahtar\s*kelimeler|anahtar\s*kelimeler|seo(?:\s*&\s*ai)?|sıkça\s*sorulan\s*sorular|sikca\s*sorulan\s*sorular|faq)$/i;

    let normalized = decodeStoredTextEntities(value)
        .replace(/&lt;/gi, '<')
        .replace(/&gt;/gi, '>')
        .replace(/<\s*br\s*\/?\s*>/gi, '\n')
        .replace(/<\s*\/p\s*>\s*<\s*p[^>]*>/gi, '\n\n')
        .replace(/<\s*\/?p[^>]*>/gi, '\n')
        .replace(/<[^>]+>/g, ' ');

    normalized = normalizeAiNewlines(normalized)
        .replace(/[ \t]+/g, ' ')
        .replace(/\n{3,}/g, '\n\n')
        .trim();

    const output: string[] = [];
    let skipNextValue = false;

    for (const rawLine of normalized.split('\n')) {
        let line = rawLine.trim();
        if (!line) {
            if (output.length > 0 && output[output.length - 1] !== '') output.push('');
            continue;
        }

        if (/^\[\/?CONTENT\]$/i.test(line)) continue;
        if (/^\[(?:İ?TEM|ITEM)\s*:/i.test(line)) {
            skipNextValue = false;
            output.push(line);
            continue;
        }

        const labelCandidate = line.replace(/\s*:\s*.*$/, '').trim();
        if (panelLabelRe.test(labelCandidate)) {
            skipNextValue = labelsThatOwnNextLineRe.test(labelCandidate) && !line.includes(':');
            continue;
        }

        if (skipNextValue) {
            skipNextValue = false;
            continue;
        }

        line = line
            .replace(/(^|\s)#[\p{L}\p{N}_-]+/gu, ' ')
            .replace(/\s{2,}/g, ' ')
            .trim();

        if (line) output.push(line);
    }

    return output
        .join('\n')
        .replace(/\n{3,}/g, '\n\n')
        .trim();
};

const readAiBoolean = (value: unknown, fallback = false) => {
    if (typeof value === 'boolean') return value;
    const normalized = String(value ?? '').trim().toLowerCase();
    if (['true', '1', 'yes', 'evet'].includes(normalized)) return true;
    if (['false', '0', 'no', 'hayir', 'hayır'].includes(normalized)) return false;
    return fallback;
};

const readAiNumber = (value: unknown) => {
    const num = Number(value);
    return Number.isFinite(num) ? num : undefined;
};

const normalizeAiQuizType = (value: unknown, hasCorrectAnswers: boolean): 'personality' | 'trivia' | 'checklist' => {
    const normalized = String(value || '').trim().toLowerCase();
    if (normalized === 'personality' || normalized.includes('kişilik') || normalized.includes('kisilik')) return 'personality';
    if (normalized === 'trivia' || normalized.includes('bilgi')) return 'trivia';
    if (normalized === 'checklist' || normalized.includes('kontrol')) return 'checklist';
    return hasCorrectAnswers ? 'trivia' : 'personality';
};

const normalizeAiQuizLayout = (value: unknown, answerCount: number): 'list' | 'grid2' | 'grid3' => {
    const normalized = String(value || '').trim().toLowerCase();
    if (
        normalized === 'grid3' ||
        normalized === '3' ||
        normalized.includes('3') ||
        normalized.includes('üç') ||
        normalized.includes('uc') ||
        normalized.includes('triple')
    ) return 'grid3';
    if (
        normalized === 'grid2' ||
        normalized === 'grid' ||
        normalized === '2' ||
        normalized.includes('2') ||
        normalized.includes('iki') ||
        normalized.includes('double')
    ) return 'grid2';
    return answerCount <= 3 ? 'grid2' : 'list';
};

const normalizeAiQuestionSorting = (value: unknown): 'asc' | 'desc' | 'hidden' => {
    const normalized = String(value || '').trim().toLowerCase();
    if (normalized === 'desc') return 'desc';
    if (normalized === 'hidden' || normalized === 'hide') return 'hidden';
    return 'asc';
};

const buildFallbackQuizResults = (questionCount: number) => {
    const total = Math.max(1, questionCount);
    const firstEnd = Math.max(0, Math.floor(total * 0.25));
    const secondEnd = Math.max(firstEnd + 1, Math.floor(total * 0.5));
    const thirdEnd = Math.max(secondEnd + 1, Math.floor(total * 0.75));

    return [
        { key: 'baslangic', title: 'Daha Yeni Başlıyorsun', description: '<p>Bu konuda keşfedecek çok detayın var.</p>', minScore: 0, maxScore: firstEnd },
        { key: 'orta', title: 'Fena Değil', description: '<p>Temeli biliyorsun ama birkaç kritik detay kaçmış.</p>', minScore: firstEnd + 1, maxScore: secondEnd },
        { key: 'iyi', title: 'Gayet İyisin', description: '<p>Bilgin güçlü; birkaç soruyla zirveyi kaçırdın.</p>', minScore: secondEnd + 1, maxScore: thirdEnd },
        { key: 'zirve', title: 'Tam İsabet', description: '<p>Bu testi gerçekten konuya hakim biri gibi çözdün.</p>', minScore: thirdEnd + 1, maxScore: total },
    ].filter((result) => result.minScore <= result.maxScore);
};

const buildQuizItemFromAiQuiz = (rawQuiz: any): PostItem | null => {
    if (!rawQuiz || typeof rawQuiz !== 'object') return null;

    const rawQuestions = Array.isArray(rawQuiz.questions) ? rawQuiz.questions : [];
    const hasCorrectAnswers = rawQuestions.some((question: any) =>
        Array.isArray(question?.answers) &&
        question.answers.some((answer: any) => readAiBoolean(answer?.isCorrect ?? answer?.correct ?? answer?.is_correct, false))
    );
    const quizType = normalizeAiQuizType(rawQuiz.quizType ?? rawQuiz.type, hasCorrectAnswers);
    const sourceResults = Array.isArray(rawQuiz.results) && rawQuiz.results.length > 0
        ? rawQuiz.results
        : buildFallbackQuizResults(rawQuestions.length);
    const globalLayout =
        rawQuiz.layout ??
        rawQuiz.answerLayout ??
        rawQuiz.answerFormat ??
        rawQuiz.cevapFormati ??
        rawQuiz.cevap_formatı ??
        rawQuiz.cevap_format ??
        '';

    const resultKeyToId = new Map<string, string>();
    const results = sourceResults
        .map((result: any, index: number) => {
            const id = makeGeneratedId('quiz-result');
            const title = stripMarkdownEmphasis(String(result?.title || `Sonuç ${index + 1}`)).trim() || `Sonuç ${index + 1}`;
            const keyCandidates = [
                result?.key,
                result?.id,
                result?.resultKey,
                result?.slug,
                title,
            ];
            keyCandidates.forEach((candidate) => {
                const key = String(candidate ?? '').trim();
                if (key) resultKeyToId.set(key, id);
            });

            return {
                id,
                title,
                image: String(result?.image || '').trim(),
                description: normalizeAiHtml(result?.description || result?.desc || ''),
                minScore: readAiNumber(result?.minScore),
                maxScore: readAiNumber(result?.maxScore),
                answerCount: readAiNumber(result?.answerCount),
            };
        })
        .filter((result: any) => result.title);

    const firstResultId = results[0]?.id || '';
    const questions = rawQuestions
        .map((question: any, questionIndex: number) => {
            const rawAnswers = Array.isArray(question?.answers) ? question.answers : [];
            const answers = rawAnswers
                .map((answer: any) => {
                    const text = stripMarkdownEmphasis(String(answer?.text || answer?.title || answer?.label || '')).trim();
                    if (!text) return null;
                    const rawResultKey = String(
                        answer?.resultKey ??
                        answer?.resultId ??
                        answer?.result ??
                        answer?.resultTitle ??
                        ''
                    ).trim();
                    const resultIndex = readAiNumber(answer?.resultIndex);
                    const mappedResultId =
                        (rawResultKey ? resultKeyToId.get(rawResultKey) : '') ||
                        (typeof resultIndex === 'number' ? results[Math.max(0, resultIndex - 1)]?.id : '') ||
                        firstResultId;

                    return {
                        id: makeGeneratedId('quiz-answer'),
                        text,
                        image: String(answer?.image || '').trim(),
                        resultId: quizType === 'personality' ? mappedResultId : '',
                        isCorrect: quizType === 'trivia'
                            ? readAiBoolean(answer?.isCorrect ?? answer?.correct ?? answer?.is_correct, false)
                            : false,
                    };
                })
                .filter(Boolean) as NonNullable<PostItem['quizData']>['questions'][number]['answers'];

            if (!String(question?.title || '').trim() || answers.length === 0) return null;

            if (quizType === 'trivia' && !answers.some((answer) => answer.isCorrect)) {
                answers[0] = { ...answers[0], isCorrect: true };
            }

            return {
                id: makeGeneratedId('quiz-question'),
                title: stripMarkdownEmphasis(String(question?.title || `Soru ${questionIndex + 1}`)).trim(),
                image: String(question?.image || '').trim(),
                description: normalizeAiHtml(question?.description || question?.comment || question?.explanation || ''),
                showOnCover: readAiBoolean(question?.showOnCover, questionIndex === 0),
                layout: normalizeAiQuizLayout(
                    question?.layout ??
                    question?.answerLayout ??
                    question?.answerFormat ??
                    question?.cevapFormati ??
                    question?.cevap_formatı ??
                    question?.cevap_format ??
                    globalLayout,
                    answers.length
                ),
                answers,
            };
        })
        .filter(Boolean) as NonNullable<PostItem['quizData']>['questions'];

    if (questions.length === 0) return null;

    return {
        id: makeGeneratedId('quiz'),
        type: 'quiz',
        title: stripMarkdownEmphasis(String(rawQuiz.title || '')).trim(),
        description: normalizeAiHtml(rawQuiz.description || rawQuiz.summary || ''),
        orderNumber: 1,
        quizData: {
            quizType,
            results,
            questions,
            questionSorting: normalizeAiQuestionSorting(rawQuiz.questionSorting),
            allowMultiple: readAiBoolean(rawQuiz.allowMultiple, false),
            showResults: readAiBoolean(rawQuiz.showResults, true),
            endDate: String(rawQuiz.endDate || '').trim(),
        },
    };
};

const readOptionalAiBoolean = (value: unknown) => {
    if (value === undefined || value === null || String(value).trim() === '') return undefined;
    return readAiBoolean(value, false);
};

const normalizeAiPollColumns = (value: unknown, optionCount: number): 2 | 3 => {
    const normalized = String(value || '').trim().toLowerCase();
    if (
        normalized === '3' ||
        normalized === 'grid3' ||
        normalized.includes('3') ||
        normalized.includes('üç') ||
        normalized.includes('uc') ||
        normalized.includes('triple')
    ) return 3;
    if (
        normalized === '2' ||
        normalized === 'grid2' ||
        normalized.includes('2') ||
        normalized.includes('iki') ||
        normalized.includes('double')
    ) return 2;
    return optionCount === 3 ? 3 : 2;
};

const normalizeAiPollImageMode = (rawPoll: any, columns: 2 | 3, options: NonNullable<PostItem['options']> = []) => {
    const explicit = readOptionalAiBoolean(
        rawPoll?.isImagePoll ??
        rawPoll?.imagePoll ??
        rawPoll?.hasImages ??
        rawPoll?.gorselli ??
        rawPoll?.görselli
    );
    if (typeof explicit === 'boolean') return explicit;

    const layoutText = String(
        rawPoll?.layout ??
        rawPoll?.answerLayout ??
        rawPoll?.answerFormat ??
        rawPoll?.cevapFormati ??
        rawPoll?.cevap_formatı ??
        rawPoll?.cevap_format ??
        ''
    ).trim().toLowerCase();

    if (layoutText.includes('liste') || layoutText.includes('list') || layoutText.includes('yazi') || layoutText.includes('yazı') || layoutText.includes('text')) {
        return false;
    }
    if (layoutText.includes('resim') || layoutText.includes('görsel') || layoutText.includes('gorsel') || layoutText.includes('image') || layoutText.includes('grid')) {
        return true;
    }
    if (options.some((option) => String(option?.image || '').trim())) return true;
    return false;
};

const readAiPollList = (rawPoll: any) => {
    const candidates = [rawPoll?.items, rawPoll?.polls, rawPoll?.questions];
    return candidates.find((candidate) => Array.isArray(candidate) && candidate.length > 0) || [];
};

const readAiPollOptions = (rawPoll: any) => {
    if (Array.isArray(rawPoll?.options)) return rawPoll.options;
    if (Array.isArray(rawPoll?.answers)) return rawPoll.answers;
    if (Array.isArray(rawPoll?.choices)) return rawPoll.choices;
    if (Array.isArray(rawPoll?.secenekler)) return rawPoll.secenekler;
    if (Array.isArray(rawPoll?.seçenekler)) return rawPoll.seçenekler;
    return [];
};

const readAiPollImagePrompt = (rawPoll: any) => stripMarkdownEmphasis(String(
    rawPoll?.imagePrompt ??
    rawPoll?.visualIdea ??
    rawPoll?.visualPrompt ??
    rawPoll?.gorselFikri ??
    rawPoll?.görselFikri ??
    rawPoll?.soruGorseliFikri ??
    rawPoll?.soruGörseliFikri ??
    rawPoll?.source ??
    ''
)).trim();

const clipAiPollDescriptionText = (value: string, maxLength = 120) => {
    const normalized = String(value || '').replace(/\s+/g, ' ').trim();
    if (normalized.length <= maxLength) return normalized;
    return normalized.slice(0, maxLength).replace(/\s+\S*$/g, '').trim() || normalized.slice(0, maxLength).trim();
};

const buildAiPollDescriptionFallback = (title: string, options: NonNullable<PostItem['options']>) => {
    const question = clipAiPollDescriptionText(
        stripMarkdownEmphasis(String(title || '')).replace(/[?!.\s]+$/g, ''),
        86
    );
    const optionPreview = clipAiPollDescriptionText(
        options
            .map((option) => stripMarkdownEmphasis(String(option?.text || '')).trim())
            .filter(Boolean)
            .slice(0, 2)
            .join(' veya '),
        70
    );

    const sentence = question
        ? `${question} için 2026 anketinde tercihini seç, güncel sonuçlara katıl.`
        : optionPreview
            ? `${optionPreview} seçenekleri için 2026 anketinde tercihini seç, güncel sonuçlara katıl.`
            : '';

    return normalizeAiHtml(sentence);
};

const buildSinglePollItemFromAiPoll = (rawPoll: any, index = 0): PostItem | null => {
    if (!rawPoll || typeof rawPoll !== 'object') return null;

    const rawOptions = readAiPollOptions(rawPoll);

    const options = rawOptions
        .map((option: any) => {
            const text = stripMarkdownEmphasis(String(
                option?.text ??
                option?.title ??
                option?.label ??
                option?.name ??
                ''
            )).trim();
            if (!text) return null;

            const votes = readAiNumber(option?.votes ?? option?.voteCount ?? option?.oy ?? option?.oySayisi ?? option?.oy_sayisi);

            return {
                id: makeGeneratedId('poll-option'),
                text,
                votes: Math.max(0, Math.round(votes ?? 0)),
                image: String(option?.image ?? option?.mediaUrl ?? option?.media ?? '').trim(),
            };
        })
        .filter(Boolean) as NonNullable<PostItem['options']>;

    if (options.length < 2) return null;

    const globalLayout =
        rawPoll.layout ??
        rawPoll.answerLayout ??
        rawPoll.answerFormat ??
        rawPoll.cevapFormati ??
        rawPoll.cevap_formatı ??
        rawPoll.cevap_format ??
        '';
    const pollColumns = normalizeAiPollColumns(rawPoll.pollColumns ?? rawPoll.columns ?? globalLayout, options.length);
    const title = stripMarkdownEmphasis(String(rawPoll.title || rawPoll.question || rawPoll.soru || rawPoll.questionTitle || '')).trim();
    const description = normalizeAiHtml(rawPoll.description || rawPoll.summary || rawPoll.spot || '') || buildAiPollDescriptionFallback(title, options);

    return {
        id: makeGeneratedId('poll'),
        type: 'poll',
        title,
        description,
        mediaUrl: String(rawPoll.mediaUrl || rawPoll.image || rawPoll.mainImage || rawPoll.thumbnail || '').trim(),
        source: readAiPollImagePrompt(rawPoll),
        orderNumber: index + 1,
        options,
        isImagePoll: normalizeAiPollImageMode(rawPoll, pollColumns, options),
        pollColumns,
    };
};

const buildPollItemsFromAiPoll = (rawPoll: any): PostItem[] => {
    if (!rawPoll || typeof rawPoll !== 'object') return [];

    const pollList = readAiPollList(rawPoll);
    const inheritedLayout =
        rawPoll.layout ??
        rawPoll.answerLayout ??
        rawPoll.answerFormat ??
        rawPoll.cevapFormati ??
        rawPoll.cevap_formatı ??
        rawPoll.cevap_format ??
        '';

    const inheritedFields = {
        isImagePoll: rawPoll.isImagePoll ?? rawPoll.imagePoll ?? rawPoll.hasImages ?? rawPoll.gorselli ?? rawPoll.görselli,
        pollColumns: rawPoll.pollColumns ?? rawPoll.columns,
        layout: inheritedLayout,
        answerLayout: rawPoll.answerLayout,
        answerFormat: rawPoll.answerFormat,
        cevapFormati: rawPoll.cevapFormati,
        cevap_formatı: rawPoll.cevap_formatı,
        cevap_format: rawPoll.cevap_format,
    };

    const pollItems = (pollList.length > 0
        ? pollList
            .map((poll: any, index: number) => buildSinglePollItemFromAiPoll({
                ...inheritedFields,
                ...poll,
                options: readAiPollOptions(poll),
            }, index))
        : [buildSinglePollItemFromAiPoll(rawPoll, 0)]
    ).filter(Boolean) as PostItem[];

    if (pollItems.length === 0) return [];

    const withHomepageFlag = pollItems.map((item, index) => ({
        ...item,
        showOnHomepage: index === 0 ? true : item.showOnHomepage,
        orderNumber: index + 1,
    }));

    const closingRaw = String(
        rawPoll.closing ??
        rawPoll.closingText ??
        rawPoll.miniClosing ??
        rawPoll.outro ??
        rawPoll.footer ??
        ''
    ).trim();
    const closingHtml = normalizeAiHtml(closingRaw);

    if (!closingHtml) return withHomepageFlag;

    return [
        ...withHomepageFlag,
        {
            id: makeGeneratedId('poll-closing'),
            type: 'text',
            title: '',
            description: closingHtml,
            mediaUrl: '',
            createdAt: Date.now(),
            orderNumber: withHomepageFlag.length + 1,
        },
    ];
};

const normalizeAiVideoUrlText = (value: unknown) => String(value || '').trim().replace(/&amp;/g, '&');

const extractAiVideoUrlFromValue = (value: unknown) => {
    const raw = normalizeAiVideoUrlText(value);
    if (!raw) return '';

    const iframeSrc = raw.match(/<iframe\b[^>]*\bsrc=["']([^"']+)["'][^>]*>/i)?.[1];
    if (iframeSrc) return normalizeAiVideoUrlText(iframeSrc);

    const srcAttr = raw.match(/\bsrc=["']([^"']+)["']/i)?.[1];
    if (srcAttr) return normalizeAiVideoUrlText(srcAttr);

    const urls = raw.match(/https?:\/\/[^\s"'<>]+/gi);
    return urls?.[0] ? normalizeAiVideoUrlText(urls[0]) : raw;
};

const readAiVideoMediaUrl = (rawVideo: any) => {
    const directCandidates = [
        rawVideo?.mediaUrl,
        rawVideo?.videoUrl,
        rawVideo?.youtubeUrl,
        rawVideo?.url,
        rawVideo?.sourceUrl,
        rawVideo?.src,
        rawVideo?.embedUrl,
    ];

    for (const candidate of directCandidates) {
        const parsed = extractAiVideoUrlFromValue(candidate);
        if (parsed) return parsed;
    }

    const embedCandidates = [
        rawVideo?.embedCode,
        rawVideo?.iframe,
        rawVideo?.html,
    ];

    for (const candidate of embedCandidates) {
        const parsed = extractAiVideoUrlFromValue(candidate);
        if (parsed) return parsed;
    }

    return '';
};

const buildAiVideoDescriptionFallback = (title: string, source: string) => {
    const cleanTitle = stripMarkdownEmphasis(String(title || '')).replace(/[?!.\s]+$/g, '').trim();
    const cleanSource = stripMarkdownEmphasis(String(source || '')).trim();
    if (!cleanTitle && !cleanSource) return '';
    const base = cleanTitle || `${cleanSource} videosu`;
    return normalizeAiHtml(`${base}, 2026 gündeminde öne çıkan görüntüleri ve gelişmeleri kısa video formatında aktarıyor.`);
};

const buildVideoItemFromAiVideo = (rawVideo: any): PostItem | null => {
    if (!rawVideo || typeof rawVideo !== 'object') return null;

    const title = stripMarkdownEmphasis(String(rawVideo.title || rawVideo.videoTitle || rawVideo.headline || '')).trim();
    const source = stripMarkdownEmphasis(String(
        rawVideo.source ||
        rawVideo.kaynak ||
        rawVideo.channel ||
        rawVideo.kanal ||
        ''
    )).trim();
    const description = normalizeAiHtml(
        rawVideo.description ||
        rawVideo.siteDescription ||
        rawVideo.shortDescription ||
        rawVideo.summary ||
        rawVideo.caption ||
        rawVideo.spot ||
        ''
    ) || buildAiVideoDescriptionFallback(title, source);
    const mediaUrl = readAiVideoMediaUrl(rawVideo);

    if (!title && !description && !mediaUrl && !source) return null;

    return {
        id: makeGeneratedId('video'),
        type: 'video',
        title,
        description,
        mediaUrl,
        source,
        createdAt: Date.now(),
        orderNumber: 1,
    };
};

const buildVideoItemsFromAiVideo = (rawVideo: any): PostItem[] => {
    const normalizeVideoEntry = (entry: any, parent: any, index: number, total: number) => {
        if (typeof entry === 'string') {
            return {
                title: total > 1 && parent?.title ? `${parent.title} - Video ${index + 1}` : parent?.title || '',
                description: parent?.description || parent?.summary || parent?.caption || '',
                mediaUrl: entry,
                source: parent?.source || parent?.channel || parent?.kanal || '',
            };
        }

        if (!entry || typeof entry !== 'object') return null;

        return {
            source: parent?.source || parent?.channel || parent?.kanal || '',
            ...entry,
            title: entry.title || entry.videoTitle || entry.headline || (total > 1 && parent?.title ? `${parent.title} - Video ${index + 1}` : parent?.title || ''),
            description: entry.description || entry.siteDescription || entry.shortDescription || entry.summary || entry.caption || entry.spot || '',
        };
    };

    const readEntries = (): { parent: any; entries: any[] } => {
        if (Array.isArray(rawVideo)) return { parent: {}, entries: rawVideo };
        if (!rawVideo || typeof rawVideo !== 'object') return { parent: {}, entries: [] as any[] };

        const nested =
            (Array.isArray(rawVideo.videos) && rawVideo.videos) ||
            (Array.isArray(rawVideo.videoItems) && rawVideo.videoItems) ||
            (Array.isArray(rawVideo.items) && rawVideo.items) ||
            (Array.isArray(rawVideo.blocks) && rawVideo.blocks) ||
            [];

        if (nested.length > 0) {
            const parentUrl = readAiVideoMediaUrl(rawVideo);
            const firstNestedUrl = readAiVideoMediaUrl(nested[0]);
            const entries = parentUrl && parentUrl !== firstNestedUrl ? [rawVideo, ...nested] : nested;
            return { parent: rawVideo, entries };
        }

        return { parent: rawVideo, entries: [rawVideo] };
    };

    const { parent, entries } = readEntries();
    return entries
        .map((entry, index) => normalizeVideoEntry(entry, parent, index, entries.length))
        .map((entry) => buildVideoItemFromAiVideo(entry))
        .filter((item): item is PostItem => Boolean(item));
};

const pickAiContentExcerptForMedia = (rawContent: unknown) => {
    const blocks = parseAiContentBlocks(String(rawContent || ''));
    for (const block of blocks) {
        if (block.kind !== 'text') continue;
        const line = block.lines
            .map((value) => stripMarkdownHeadingPrefix(stripMarkdownEmphasis(String(value || ''))).trim())
            .find(Boolean);
        if (line) return line.replace(/\s+/g, ' ').trim();
    }
    return '';
};

const buildRequestedImageItemFromAi = (title: unknown, summary: unknown, rawContent: unknown): PostItem => {
    const cleanPlain = (value: unknown) =>
        stripMarkdownHeadingPrefix(stripMarkdownEmphasis(String(value || '')))
            .replace(/\s+/g, ' ')
            .trim();

    const cleanTitle = cleanPlain(title);
    const cleanSummary = cleanPlain(summary);
    const contentExcerpt = pickAiContentExcerptForMedia(rawContent);
    const caption = cleanSummary || contentExcerpt || (cleanTitle ? `${cleanTitle} haberine ait görsel.` : 'Haberle ilgili görsel.');

    return {
        id: makeGeneratedId('image'),
        type: 'image',
        title: cleanTitle ? `${cleanTitle} görseli` : 'Haber görseli',
        description: normalizeAiHtml(caption),
        mediaUrl: '',
        altText: cleanTitle || caption,
        source: '',
        createdAt: Date.now(),
        orderNumber: 1,
    };
};

const buildRequestedMediaItemFromAi = (
    type: 'image' | 'video' | 'audio',
    title: unknown,
    summary: unknown,
    rawContent: unknown,
): PostItem => {
    if (type === 'image') return buildRequestedImageItemFromAi(title, summary, rawContent);

    const cleanPlain = (value: unknown) =>
        stripMarkdownHeadingPrefix(stripMarkdownEmphasis(String(value || '')))
            .replace(/\s+/g, ' ')
            .trim();

    const cleanTitle = cleanPlain(title);
    const cleanSummary = cleanPlain(summary);
    const contentExcerpt = pickAiContentExcerptForMedia(rawContent);
    const label = type === 'video' ? 'video' : 'ses';
    const caption = cleanSummary || contentExcerpt || (cleanTitle ? `${cleanTitle} haberine ait ${label}.` : `Haberle ilgili ${label}.`);

    return {
        id: makeGeneratedId(type),
        type,
        title: cleanTitle ? `${cleanTitle} ${label}` : `Haber ${label}`,
        description: normalizeAiHtml(caption),
        mediaUrl: '',
        source: '',
        createdAt: Date.now(),
        orderNumber: 1,
    };
};

const withReadableEventTextItems = (
    items: PostItem[],
    fallbackTitles = ['Etkinlik Detayları', 'Programdan Öne Çıkanlar', 'Katılım Bilgileri'],
    defaultTitle = 'Etkinlik Bilgileri',
) => {
    const output: PostItem[] = [];

    const splitLongPlainText = (value: string) => {
        const plain = htmlToPlainText(value);
        if (plain.length < 650) return [];

        const sentences = plain
            .split(/(?<=[.!?])\s+/)
            .map((sentence) => sentence.trim())
            .filter(Boolean);
        if (sentences.length < 4) return [];

        const chunks: string[] = [];
        let current = '';
        for (const sentence of sentences) {
            const next = current ? `${current} ${sentence}` : sentence;
            if (next.length > 520 && current) {
                chunks.push(current);
                current = sentence;
            } else {
                current = next;
            }
        }
        if (current) chunks.push(current);

        return chunks.length > 1 ? chunks.slice(0, 3) : [];
    };

    items.forEach((item) => {
        if (item.type !== 'text') {
            output.push(item);
            return;
        }

        const cleanedTitle = stripMarkdownHeadingPrefix(stripMarkdownEmphasis(item.title || '')).trim();
        const fallbackTitle = fallbackTitles[output.filter((entry) => entry.type === 'text').length] || defaultTitle;
        const chunks = splitLongPlainText(item.description || '');

        if (chunks.length > 1) {
            chunks.forEach((chunk, chunkIndex) => {
                output.push({
                    ...item,
                    id: chunkIndex === 0 ? item.id : makeGeneratedId('text'),
                    title: chunkIndex === 0 ? (cleanedTitle || fallbackTitle) : (fallbackTitles[output.filter((entry) => entry.type === 'text').length] || fallbackTitle),
                    description: buildQuillHtmlFromLines([chunk]),
                    orderNumber: output.length + 1,
                });
            });
            return;
        }

        output.push({
            ...item,
            title: cleanedTitle || fallbackTitle,
        });
    });

    return output;
};

const TOC_LIST_STYLES: TocListStyle[] = [
    'none',
    'decimal',
    'decimal-leading-zero',
    'circle',
    'disc',
    'square',
    'lower-alpha',
    'upper-alpha',
    'lower-roman',
    'upper-roman',
];

const normalizeAiTocListStyleValue = (value: unknown, fallback: TocListStyle): TocListStyle => {
    const normalized = String(value || '').trim();
    return TOC_LIST_STYLES.includes(normalized as TocListStyle) ? normalized as TocListStyle : fallback;
};

const normalizeAiTocLinkStyle = (value: any): NonNullable<NonNullable<PostItem['tocData']>['linkListStyle']> => {
    const base = createDefaultTocData().linkListStyle!;
    const style = value && typeof value === 'object' ? value : {};

    return {
        level1: normalizeAiTocListStyleValue(style.level1, 'decimal'),
        level2: normalizeAiTocListStyleValue(style.level2, base.level2),
        level3: normalizeAiTocListStyleValue(style.level3, base.level3),
        showLevel1InText: readAiBoolean(style.showLevel1InText, true),
        showLevel2InText: readAiBoolean(style.showLevel2InText, false),
        showLevel3InText: readAiBoolean(style.showLevel3InText, false),
    };
};

const slugifyTocAnchor = (value: unknown) => {
    const text = stripMarkdownEmphasis(String(value || '')).toLocaleLowerCase('tr-TR');
    return text
        .replace(/ğ/g, 'g')
        .replace(/ü/g, 'u')
        .replace(/ş/g, 's')
        .replace(/ı/g, 'i')
        .replace(/ö/g, 'o')
        .replace(/ç/g, 'c')
        .replace(/[^a-z0-9\s-]/g, '')
        .replace(/\s+/g, '-')
        .replace(/-+/g, '-')
        .replace(/^-|-$/g, '');
};

const normalizeAiTocContent = (value: unknown): string => {
    if (Array.isArray(value)) {
        return value
            .map((entry: unknown) => {
                if (entry && typeof entry === 'object') {
                    return normalizeAiTocContent((entry as any).content ?? (entry as any).body ?? (entry as any).text ?? (entry as any).description);
                }
                return normalizeAiTocContent(entry);
            })
            .filter(Boolean)
            .join('');
    }

    const raw = String(value ?? '').trim();
    if (!raw) return '';
    if (hasHtmlTags(raw)) return raw;
    return buildQuillHtmlFromLines(normalizeAiNewlines(raw).split('\n'));
};

const readAiTocItems = (rawToc: any) => {
    if (Array.isArray(rawToc)) return rawToc;
    if (!rawToc || typeof rawToc !== 'object') return [];
    const candidates = [
        rawToc.items,
        rawToc.tocItems,
        rawToc.sections,
        rawToc.tableOfContents,
        rawToc.contents,
        rawToc.headings,
        rawToc.basliklar,
        rawToc.bolumler,
        rawToc.bölümler,
    ];
    const found = candidates.find((candidate) => Array.isArray(candidate));
    return Array.isArray(found) ? found : [];
};

const readAiTocOptionalUrl = (rawToc: any) => {
    const candidates = [
        rawToc?.optionalUrl,
        rawToc?.url,
        rawToc?.videoUrl,
        rawToc?.sourceUrl,
        rawToc?.video?.mediaUrl,
        rawToc?.video?.videoUrl,
        rawToc?.video?.url,
        rawToc?.video?.embedCode,
        rawToc?.embedCode,
    ];

    for (const candidate of candidates) {
        const parsed = extractAiVideoUrlFromValue(candidate);
        if (parsed) return parsed;
    }

    return '';
};

const buildAiTocImageDescriptionFallback = (title: string) => {
    const cleanTitle = stripMarkdownEmphasis(String(title || '')).replace(/[?!.\s]+$/g, '').trim();
    if (!cleanTitle) return '2026 güncel rehber içeriği için görsel açıklaması';
    return `${cleanTitle} için 2026 güncel rehber görseli`;
};

const buildTocItemFromAiToc = (rawToc: any): PostItem | null => {
    if (!rawToc || (typeof rawToc !== 'object' && !Array.isArray(rawToc))) return null;

    const rawItems = readAiTocItems(rawToc);
    const items = rawItems
        .map((entry: any, index: number): TocListItem | null => {
            const stringEntry = typeof entry === 'string' ? entry : '';
            const titleCandidate =
                stringEntry ||
                entry?.title ||
                entry?.heading ||
                entry?.name ||
                entry?.label ||
                entry?.baslik ||
                entry?.başlık ||
                '';
            const title = stripMarkdownEmphasis(String(
                titleCandidate
            )).trim();
            const content = normalizeAiTocContent(
                stringEntry ? '' : (
                    entry?.content ??
                    entry?.body ??
                    entry?.description ??
                    entry?.text ??
                    entry?.html ??
                    entry?.paragraphs ??
                    entry?.paragraflar ??
                    ''
                )
            );

            if (!title && !normalizeQuillEmpty(content)) return null;

            const safeTitle = title || `Bölüm ${index + 1}`;
            const imageDescription = stripMarkdownEmphasis(String(
                entry?.imageDescription ??
                entry?.altText ??
                entry?.alt ??
                entry?.imageAlt ??
                entry?.gorselAciklama ??
                entry?.görselAçıklama ??
                ''
            )).trim() || buildAiTocImageDescriptionFallback(safeTitle);

            return {
                id: makeGeneratedId('toc-entry'),
                orderNumber: index + 1,
                title: safeTitle,
                parentLink: stripMarkdownEmphasis(String(entry?.parentLink ?? entry?.anchor ?? entry?.slug ?? '')).trim() || slugifyTocAnchor(safeTitle),
                image: String(entry?.image ?? entry?.mediaUrl ?? entry?.thumbnail ?? '').trim(),
                imageDescription,
                content,
            };
        })
        .filter(Boolean) as TocListItem[];

    if (items.length === 0) return null;

    const title = stripMarkdownEmphasis(String(rawToc.title || rawToc.blockTitle || 'İçindekiler')).trim();
    const rawStyle = rawToc.linkListStyle || rawToc.listStyle || rawToc.style || {};

    return {
        id: makeGeneratedId('toc'),
        type: 'toc',
        title,
        description: '',
        createdAt: Date.now(),
        orderNumber: 1,
        tocData: {
            optionalUrl: readAiTocOptionalUrl(rawToc),
            linkListStyle: normalizeAiTocLinkStyle(rawStyle),
            items,
        },
    };
};

const readNestedPath = (source: any, path: string) => {
    if (!source || !path) return undefined;
    return path.split('.').reduce((current, segment) => {
        if (current == null) return undefined;
        return current[segment as keyof typeof current];
    }, source);
};

const setNestedPath = (source: any, path: string, value: unknown) => {
    const parts = path.split('.').filter(Boolean);
    if (parts.length === 0) return source;

    const root = Array.isArray(source) ? [...source] : { ...(source || {}) };
    let cursor: any = root;

    for (let i = 0; i < parts.length - 1; i++) {
        const key = parts[i];
        const next = cursor[key];
        cursor[key] = Array.isArray(next) ? [...next] : { ...(next || {}) };
        cursor = cursor[key];
    }

    cursor[parts[parts.length - 1]] = value;
    return root;
};

const createTocPostItem = (): PostItem => ({
    id: Math.random().toString(36).substr(2, 9),
    type: 'toc',
    title: '',
    description: '',
    createdAt: Date.now(),
    orderNumber: 1,
    tocData: createDefaultTocData(),
});

const ensureTocPostItems = (items: PostItem[]) => {
    if (items.some((item) => item.type === 'toc')) return items;

    const tocItem = createTocPostItem();
    if (items.length === 0) return [tocItem];

    return [{
        ...tocItem,
        tocData: {
            ...tocItem.tocData!,
            items: items.map((item, index) => ({
                id: item.id || Math.random().toString(36).substr(2, 9),
                orderNumber: Number(item.orderNumber) || index + 1,
                title: item.title || '',
                parentLink: '',
                image: item.mediaUrl || '',
                imageDescription: item.altText || '',
                content: item.description || '',
            })),
        },
    }];
};

const readTocItemImage = (item: PostItem, tocItemId?: string | null) => {
    if (!tocItemId || !item.tocData?.items) return '';
    return item.tocData.items.find((tocItem) => tocItem.id === tocItemId)?.image || '';
};

const withUpdatedTocItemImage = (item: PostItem, tocItemId: string, image: string) => {
    const fallback = createDefaultTocData();
    const currentTocData = item.tocData || fallback;
    const currentItems = Array.isArray(currentTocData.items) && currentTocData.items.length > 0
        ? currentTocData.items
        : fallback.items;

    return {
        ...fallback,
        ...currentTocData,
        linkListStyle: {
            ...fallback.linkListStyle,
            ...(currentTocData.linkListStyle || {}),
        },
        items: currentItems.map((tocItem) =>
            tocItem.id === tocItemId ? { ...tocItem, image } : tocItem
        ),
    };
};

const createRecipePostItem = (): PostItem => ({
    id: Math.random().toString(36).substr(2, 9),
    type: 'recipe',
    title: '',
    description: '',
    createdAt: Date.now(),
    orderNumber: 1,
    recipeData: createDefaultRecipeData(),
});

const createRecipeVideoPostItem = (): PostItem => ({
    id: Math.random().toString(36).substr(2, 9),
    type: 'video',
    title: '',
    description: '',
    mediaUrl: '',
    createdAt: Date.now(),
    orderNumber: 1,
    showOnHomepage: false,
});

const createRecipePostItems = (): PostItem[] => [
    createRecipePostItem(),
    createRecipeVideoPostItem(),
];

const normalizeAiRecipeDifficulty = (value: unknown): RecipeDifficulty => {
    const normalized = String(value || '').trim().toLocaleLowerCase('tr-TR');
    if (!normalized) return '';
    if (normalized === 'easy' || normalized.includes('kolay') || normalized.includes('basit')) return 'easy';
    if (normalized === 'hard' || normalized.includes('zor') || normalized.includes('güç') || normalized.includes('guc')) return 'hard';
    if (normalized === 'medium' || normalized.includes('orta')) return 'medium';
    return '';
};

const cleanAiRecipeListText = (value: unknown) =>
    stripMarkdownEmphasis(String(value || ''))
        .replace(/^[-*•–]\s+/, '')
        .replace(/^\d+[.)]\s+/, '')
        .trim();

const makeAiRecipeIngredient = (text: string): RecipeIngredientItem => ({
    id: makeGeneratedId('recipe-ingredient'),
    text,
});

const makeAiRecipeNutrition = (label: string, value: string): RecipeNutritionItem => ({
    id: makeGeneratedId('recipe-nutrition'),
    label,
    value,
});

const makeAiRecipeDirection = (
    orderNumber: number,
    title: string,
    content: string,
    image = '',
    imageDescription = '',
): RecipeDirectionItem => ({
    id: makeGeneratedId('recipe-direction'),
    orderNumber,
    title,
    image,
    imageDescription,
    content,
});

const normalizeAiRecipeHtml = (value: unknown): string => {
    if (Array.isArray(value)) {
        return value
            .map((entry: unknown) => normalizeAiRecipeHtml(entry))
            .filter(Boolean)
            .join('');
    }

    if (value && typeof value === 'object') {
        return normalizeAiRecipeHtml((value as any).content ?? (value as any).body ?? (value as any).text ?? (value as any).description ?? '');
    }

    const raw = String(value ?? '').trim();
    if (!raw) return '';
    if (hasHtmlTags(raw)) return raw;
    return buildQuillHtmlFromLines(normalizeAiNewlines(raw).split('\n'));
};

const flattenAiRecipeIngredients = (value: any, group = ''): RecipeIngredientItem[] => {
    if (!value) return [];

    if (typeof value === 'string') {
        return normalizeAiNewlines(value)
            .split('\n')
            .map(cleanAiRecipeListText)
            .filter(Boolean)
            .map((text) => makeAiRecipeIngredient(group && !text.toLocaleLowerCase('tr-TR').includes(group.toLocaleLowerCase('tr-TR'))
                ? `${group}: ${text}`
                : text));
    }

    if (Array.isArray(value)) {
        return value.flatMap((entry) => flattenAiRecipeIngredients(entry, group));
    }

    if (typeof value === 'object') {
        const nextGroup = cleanAiRecipeListText(value.group ?? value.category ?? value.title ?? value.heading ?? value.baslik ?? value.başlık ?? group);
        const nested = value.items ?? value.ingredients ?? value.malzemeler ?? value.list;
        if (nested) return flattenAiRecipeIngredients(nested, nextGroup || group);

        const text = cleanAiRecipeListText(value.text ?? value.name ?? value.label ?? value.value ?? '');
        if (text) {
            return [makeAiRecipeIngredient(nextGroup && !text.toLocaleLowerCase('tr-TR').includes(nextGroup.toLocaleLowerCase('tr-TR'))
                ? `${nextGroup}: ${text}`
                : text)];
        }

        return Object.entries(value as Record<string, unknown>).flatMap(([key, entryValue]) =>
            ['group', 'category', 'title', 'heading', 'baslik', 'başlık'].includes(key)
                ? []
                : flattenAiRecipeIngredients(entryValue, cleanAiRecipeListText(key) || group)
        );
    }

    return [];
};

const readAiRecipeIngredients = (rawRecipe: any) => {
    const candidates = [
        rawRecipe?.ingredients,
        rawRecipe?.malzemeler,
        rawRecipe?.ingredientList,
        rawRecipe?.materials,
    ];
    const found = candidates.find((candidate) => candidate);
    return flattenAiRecipeIngredients(found);
};

const readAiRecipeNutrition = (rawRecipe: any): RecipeNutritionItem[] => {
    const value =
        rawRecipe?.nutrition ??
        rawRecipe?.nutritionFacts ??
        rawRecipe?.besinDegerleri ??
        rawRecipe?.besinDeğerleri ??
        rawRecipe?.nutrients;

    if (!value) return [];

    const readEntry = (entry: any): RecipeNutritionItem | null => {
        if (typeof entry === 'string') {
            const text = cleanAiRecipeListText(entry);
            if (!text) return null;
            const [label, ...rest] = text.split(':');
            if (rest.length > 0) return makeAiRecipeNutrition(label.trim(), rest.join(':').trim());
            const parts = text.split(/\s+-\s+|\s+=\s+/);
            return makeAiRecipeNutrition(parts[0]?.trim() || text, parts.slice(1).join(' - ').trim());
        }

        if (!entry || typeof entry !== 'object') return null;
        const label = cleanAiRecipeListText(entry.label ?? entry.name ?? entry.title ?? entry.key ?? '');
        const itemValue = cleanAiRecipeListText(entry.value ?? entry.amount ?? entry.text ?? '');
        if (!label && !itemValue) return null;
        return makeAiRecipeNutrition(label, itemValue);
    };

    const entries = Array.isArray(value)
        ? value
        : typeof value === 'object'
            ? Object.entries(value as Record<string, unknown>).map(([label, entryValue]) => ({ label, value: entryValue }))
            : normalizeAiNewlines(String(value)).split('\n');

    return entries.map(readEntry).filter(Boolean) as RecipeNutritionItem[];
};

const buildAiRecipeDirectionImageDescription = (title: string) => {
    const cleanTitle = stripMarkdownEmphasis(String(title || '')).replace(/[?!.\s]+$/g, '').trim();
    if (!cleanTitle) return '2026 güncel tarif adımı görsel açıklaması';
    return `${cleanTitle} için 2026 güncel tarif görseli`;
};

const readAiRecipeDirections = (rawRecipe: any): RecipeDirectionItem[] => {
    const value =
        rawRecipe?.directions ??
        rawRecipe?.steps ??
        rawRecipe?.instructions ??
        rawRecipe?.adimlar ??
        rawRecipe?.adımlar ??
        rawRecipe?.yapilis ??
        rawRecipe?.yapılış ??
        rawRecipe?.hazirlanis ??
        rawRecipe?.hazırlanış;

    const entries = Array.isArray(value)
        ? value
        : typeof value === 'string'
            ? normalizeAiNewlines(value).split(/\n(?=\s*\d+[.)]\s+)/).filter(Boolean)
            : [];

    const directions = entries
        .map((entry: any, index: number): RecipeDirectionItem | null => {
            if (typeof entry === 'string') {
                const raw = cleanAiRecipeListText(entry);
                if (!raw) return null;
                const split = raw.match(/^(.{3,90}?)(?:\n|:\s+)([\s\S]+)$/);
                const title = split?.[1]?.trim() || `Adım ${index + 1}`;
                const content = normalizeAiRecipeHtml(split?.[2]?.trim() || raw);
                return makeAiRecipeDirection(index + 1, title, content, '', buildAiRecipeDirectionImageDescription(title));
            }

            if (!entry || typeof entry !== 'object') return null;
            const title = cleanAiRecipeListText(entry.title ?? entry.heading ?? entry.name ?? entry.label ?? entry.baslik ?? entry.başlık ?? `Adım ${index + 1}`);
            const content = normalizeAiRecipeHtml(entry.content ?? entry.description ?? entry.text ?? entry.body ?? entry.detail ?? '');
            const image = String(entry.image ?? entry.mediaUrl ?? entry.thumbnail ?? '').trim();
            const imageDescription = cleanAiRecipeListText(
                entry.imageDescription ??
                entry.altText ??
                entry.alt ??
                entry.imageAlt ??
                ''
            ) || buildAiRecipeDirectionImageDescription(title);
            if (!title && !normalizeQuillEmpty(content) && !image) return null;
            return makeAiRecipeDirection(index + 1, title || `Adım ${index + 1}`, content, image, imageDescription);
        })
        .filter(Boolean) as RecipeDirectionItem[];

    const tipsValue =
        rawRecipe?.tips ??
        rawRecipe?.pufNoktalari ??
        rawRecipe?.püfNoktaları ??
        rawRecipe?.puf_noktalari ??
        rawRecipe?.notes;

    const tips = Array.isArray(tipsValue)
        ? tipsValue.map(cleanAiRecipeListText).filter(Boolean)
        : typeof tipsValue === 'string'
            ? normalizeAiNewlines(tipsValue).split('\n').map(cleanAiRecipeListText).filter(Boolean)
            : [];

    if (tips.length === 0) return directions;

    const tipsContent = `<ul>${tips.map((tip) => `<li>${markdownInlineToSafeHtml(tip)}</li>`).join('')}</ul>`;
    return [
        ...directions,
        makeAiRecipeDirection(
            directions.length + 1,
            'Püf Noktaları',
            tipsContent,
            '',
            'Tarifin püf noktaları için 2026 güncel mutfak görseli',
        ),
    ];
};

const readAiRecipeOptionalUrl = (rawRecipe: any) => {
    const candidates = [
        rawRecipe?.optionalUrl,
        rawRecipe?.sourceUrl,
        rawRecipe?.sourceLink,
        rawRecipe?.kaynakUrl,
        rawRecipe?.url,
    ];
    const videoUrl = readAiVideoMediaUrl(rawRecipe?.video || {});
    for (const candidate of candidates) {
        const parsed = extractAiVideoUrlFromValue(candidate);
        if (parsed && parsed !== videoUrl) return parsed;
    }
    return '';
};

const readAiRecipeVideoItem = (rawRecipe: any, fallbackTitle: string): PostItem => {
    const rawVideo = rawRecipe?.video && typeof rawRecipe.video === 'object'
        ? rawRecipe.video
        : {
            title: rawRecipe?.videoTitle ?? rawRecipe?.videoBaslik ?? rawRecipe?.videoBaşlık ?? '',
            description: rawRecipe?.videoDescription ?? rawRecipe?.videoAciklama ?? rawRecipe?.videoAçıklama ?? '',
            mediaUrl: rawRecipe?.videoUrl ?? rawRecipe?.youtubeUrl ?? rawRecipe?.mediaUrl ?? '',
            embedCode: rawRecipe?.embedCode ?? rawRecipe?.iframe ?? '',
            source: rawRecipe?.videoSource ?? rawRecipe?.source ?? '',
        };

    const videoItem = buildVideoItemFromAiVideo(rawVideo);
    if (!videoItem) return createRecipeVideoPostItem();

    return {
        ...videoItem,
        title: videoItem.title || (fallbackTitle ? `${fallbackTitle} videosu` : ''),
        showOnHomepage: false,
    };
};

const buildRecipeItemsFromAiRecipe = (rawRecipe: any): PostItem[] => {
    if (!rawRecipe || typeof rawRecipe !== 'object') return [];

    const title = cleanAiRecipeListText(rawRecipe.title ?? rawRecipe.recipeTitle ?? rawRecipe.baslik ?? rawRecipe.başlık ?? '');
    const description = normalizeAiHtml(rawRecipe.description ?? rawRecipe.summary ?? rawRecipe.spot ?? '');
    const ingredients = readAiRecipeIngredients(rawRecipe);
    const nutrition = readAiRecipeNutrition(rawRecipe);
    const directions = readAiRecipeDirections(rawRecipe);
    const fallbackRecipeData = createDefaultRecipeData();

    const hasRecipePayload =
        title ||
        normalizeQuillEmpty(description) ||
        ingredients.length > 0 ||
        nutrition.length > 0 ||
        directions.length > 0 ||
        rawRecipe.prepTime ||
        rawRecipe.cookTime ||
        rawRecipe.serving;

    if (!hasRecipePayload) return [];

    const recipeData: RecipeData = {
        optionalUrl: readAiRecipeOptionalUrl(rawRecipe),
        prepTime: cleanAiRecipeListText(rawRecipe.prepTime ?? rawRecipe.hazirlikSuresi ?? rawRecipe.hazırlıkSüresi ?? rawRecipe.preparationTime ?? ''),
        cookTime: cleanAiRecipeListText(rawRecipe.cookTime ?? rawRecipe.pisirmeSuresi ?? rawRecipe.pişirmeSüresi ?? rawRecipe.cookingTime ?? ''),
        serving: cleanAiRecipeListText(rawRecipe.serving ?? rawRecipe.portion ?? rawRecipe.porsiyon ?? rawRecipe.serves ?? ''),
        difficulty: normalizeAiRecipeDifficulty(rawRecipe.difficulty ?? rawRecipe.zorluk),
        videoUrl: '',
        videoEmbedCode: '',
        ingredients: ingredients.length > 0 ? ingredients : fallbackRecipeData.ingredients,
        nutrition: nutrition.length > 0 ? nutrition : fallbackRecipeData.nutrition,
        directions: directions.length > 0 ? directions : fallbackRecipeData.directions,
    };

    const recipeItem: PostItem = {
        id: makeGeneratedId('recipe'),
        type: 'recipe',
        title,
        description,
        createdAt: Date.now(),
        orderNumber: 1,
        recipeData,
    };

    return [recipeItem, readAiRecipeVideoItem(rawRecipe, title)];
};

const ensureRecipeVideoPostItem = (items: PostItem[]) => {
    if (items.some((item) => item.type === 'video')) return items;

    const nextItems = [...items];
    const recipeIndex = nextItems.findIndex((item) => item.type === 'recipe');
    const insertIndex = recipeIndex >= 0 ? recipeIndex + 1 : 0;
    nextItems.splice(insertIndex, 0, createRecipeVideoPostItem());
    return nextItems;
};

const ensureRecipePostItems = (items: PostItem[]) => {
    if (items.some((item) => item.type === 'recipe')) return ensureRecipeVideoPostItem(items);

    const recipeItem = createRecipePostItem();
    if (items.length === 0) return createRecipePostItems();

    return [{
        ...recipeItem,
        recipeData: {
            ...recipeItem.recipeData!,
            directions: items.map((item, index) => ({
                id: item.id || Math.random().toString(36).substr(2, 9),
                orderNumber: Number(item.orderNumber) || index + 1,
                title: item.title || '',
                image: item.mediaUrl || '',
                imageDescription: item.altText || '',
                content: item.description || '',
            })),
        },
    }, createRecipeVideoPostItem()];
};

const readRecipeDirectionImage = (item: PostItem, directionId?: string | null) => {
    if (!directionId || !item.recipeData?.directions) return '';
    return item.recipeData.directions.find((direction) => direction.id === directionId)?.image || '';
};

const withUpdatedRecipeDirectionImage = (item: PostItem, directionId: string, image: string) => {
    const fallback = createDefaultRecipeData();
    const currentRecipeData = item.recipeData || fallback;
    const currentDirections = Array.isArray(currentRecipeData.directions) && currentRecipeData.directions.length > 0
        ? currentRecipeData.directions
        : fallback.directions;

    return {
        ...fallback,
        ...currentRecipeData,
        ingredients: Array.isArray(currentRecipeData.ingredients) && currentRecipeData.ingredients.length > 0
            ? currentRecipeData.ingredients
            : fallback.ingredients,
        nutrition: Array.isArray(currentRecipeData.nutrition) && currentRecipeData.nutrition.length > 0
            ? currentRecipeData.nutrition
            : fallback.nutrition,
        directions: currentDirections.map((direction) =>
            direction.id === directionId ? { ...direction, image } : direction
        ),
    };
};

const cleanAiEventValue = (value: unknown) => cleanAiRecipeListText(value);

const cleanOptionalAiEventValue = (value: unknown) => {
    const text = cleanAiEventValue(value);
    const normalized = text.toLocaleLowerCase('tr-TR');
    if (!text) return '';
    if (
        normalized === 'yok' ||
        normalized === 'boş' ||
        normalized === 'bos' ||
        normalized.includes('boş bırak') ||
        normalized.includes('bos birak') ||
        normalized.includes('belirtilm') ||
        normalized.includes('yazmıyor') ||
        normalized.includes('yazmiyor')
    ) {
        return '';
    }
    return text;
};

const extractAiHttpUrl = (value: unknown) => {
    const raw = normalizeAiVideoUrlText(value);
    if (!raw) return '';
    const iframeSrc = raw.match(/<iframe\b[^>]*\bsrc=["']([^"']+)["'][^>]*>/i)?.[1];
    if (iframeSrc && /^https?:\/\//i.test(iframeSrc)) return normalizeAiVideoUrlText(iframeSrc);
    const srcAttr = raw.match(/\bsrc=["']([^"']+)["']/i)?.[1];
    if (srcAttr && /^https?:\/\//i.test(srcAttr)) return normalizeAiVideoUrlText(srcAttr);
    return normalizeAiVideoUrlText(raw.match(/https?:\/\/[^\s"'<>]+/i)?.[0] || '');
};

const normalizeAiEventDateParts = (value: unknown) => {
    const raw = cleanOptionalAiEventValue(value);
    if (!raw) return { date: '', time: '' };

    const monthMap: Record<string, string> = {
        ocak: '01',
        şubat: '02',
        subat: '02',
        mart: '03',
        nisan: '04',
        mayıs: '05',
        mayis: '05',
        haziran: '06',
        temmuz: '07',
        ağustos: '08',
        agustos: '08',
        eylül: '09',
        eylul: '09',
        ekim: '10',
        kasım: '11',
        kasim: '11',
        aralık: '12',
        aralik: '12',
    };
    const pad = (part: string | number) => String(part).padStart(2, '0');

    const isoMatch = raw.match(/(\d{4})-(\d{1,2})-(\d{1,2})(?:[T\s]+(\d{1,2}):(\d{2}))?/);
    if (isoMatch) {
        return {
            date: `${isoMatch[1]}-${pad(isoMatch[2])}-${pad(isoMatch[3])}`,
            time: isoMatch[4] ? `${pad(isoMatch[4])}:${isoMatch[5]}` : '',
        };
    }

    const dottedMatch = raw.match(/(\d{1,2})[./-](\d{1,2})[./-](\d{4})(?:\s+(\d{1,2}):(\d{2}))?/);
    if (dottedMatch) {
        return {
            date: `${dottedMatch[3]}-${pad(dottedMatch[2])}-${pad(dottedMatch[1])}`,
            time: dottedMatch[4] ? `${pad(dottedMatch[4])}:${dottedMatch[5]}` : '',
        };
    }

    const monthNameMatch = raw.match(/(\d{1,2})\s+([a-zğüşöçıİĞÜŞÖÇ]+)\s+(\d{4})(?:\s+(\d{1,2}):(\d{2}))?/i);
    if (monthNameMatch) {
        const month = monthMap[monthNameMatch[2].toLocaleLowerCase('tr-TR')];
        if (month) {
            return {
                date: `${monthNameMatch[3]}-${month}-${pad(monthNameMatch[1])}`,
                time: monthNameMatch[4] ? `${pad(monthNameMatch[4])}:${monthNameMatch[5]}` : '',
            };
        }
    }

    const timeOnly = raw.match(/(\d{1,2}):(\d{2})/);
    return { date: '', time: timeOnly ? `${pad(timeOnly[1])}:${timeOnly[2]}` : '' };
};

const normalizeAiEventDateTime = (value: unknown) => {
    const parts = normalizeAiEventDateParts(value);
    return parts.date ? `${parts.date}T${parts.time || '00:00'}` : '';
};

const normalizeAiEventScheduleDate = (value: unknown) => normalizeAiEventDateParts(value).date;

const normalizeAiEventTime = (value: unknown) => {
    const parts = normalizeAiEventDateParts(value);
    if (parts.time) return parts.time;
    const raw = cleanOptionalAiEventValue(value);
    const match = raw.match(/(\d{1,2}):(\d{2})/);
    return match ? `${match[1].padStart(2, '0')}:${match[2]}` : raw;
};

const normalizeAiEventRegistrationType = (value: unknown): EventRegistrationType => {
    const normalized = cleanAiEventValue(value).toLocaleLowerCase('tr-TR');
    if (!normalized) return 'none';
    if (normalized === 'tickets' || normalized.includes('bilet')) return 'tickets';
    if (normalized === 'external' || normalized.includes('harici') || normalized.includes('dış') || normalized.includes('dis')) return 'external';
    if (normalized === 'required' || normalized.includes('kayıt') || normalized.includes('kayit') || normalized.includes('gerekiyor')) return 'required';
    return 'none';
};

const makeAiEventSchedule = (entry: any, index: number): EventScheduleItem | null => {
    if (!entry) return null;
    if (typeof entry === 'string') {
        const title = cleanAiEventValue(entry);
        if (!title) return null;
        return {
            id: makeGeneratedId('event-schedule'),
            orderNumber: index + 1,
            date: '',
            time: '',
            title,
            description: '',
            image: '',
            imageDescription: `${title} etkinlik afişi`,
        };
    }

    const dateRaw = entry.date ?? entry.tarih ?? entry.startDate ?? entry.startDateTime ?? '';
    const timeRaw = entry.time ?? entry.saat ?? dateRaw ?? '';
    const title = cleanAiEventValue(entry.title ?? entry.sessionTitle ?? entry.oturumBasligi ?? entry.oturumBaşlığı ?? entry.name ?? entry.label ?? '');
    const description = cleanAiEventValue(entry.description ?? entry.shortDescription ?? entry.kisaAciklama ?? entry.kısaAçıklama ?? entry.summary ?? '');
    const imageDescription = cleanAiEventValue(
        entry.imageDescription ??
        entry.gorselAciklamasi ??
        entry.görselAçıklaması ??
        entry.altText ??
        entry.alt ??
        ''
    ) || (title ? `${title} etkinlik afişi` : 'Etkinlik programı görsel açıklaması');

    if (!title && !description && !dateRaw) return null;

    return {
        id: makeGeneratedId('event-schedule'),
        orderNumber: index + 1,
        date: normalizeAiEventScheduleDate(dateRaw),
        time: normalizeAiEventTime(timeRaw),
        title,
        description,
        image: String(entry.image ?? entry.mediaUrl ?? entry.thumbnail ?? '').trim(),
        imageDescription,
    };
};

const readAiEventSchedule = (rawEvent: any): EventScheduleItem[] => {
    const rawSchedule =
        rawEvent?.schedule ??
        rawEvent?.program ??
        rawEvent?.sessions ??
        rawEvent?.programs ??
        rawEvent?.etkinlikProgrami ??
        rawEvent?.etkinlikProgramı;
    const entries = Array.isArray(rawSchedule)
        ? rawSchedule
        : typeof rawSchedule === 'string'
            ? normalizeAiNewlines(rawSchedule).split(/\n(?=\s*(?:Program\s*)?\d+)/i).filter(Boolean)
            : [];

    return entries.map(makeAiEventSchedule).filter(Boolean) as EventScheduleItem[];
};

const makeAiEventHighlight = (entry: any, index: number): EventHighlightItem | null => {
    if (typeof entry === 'string') {
        const value = cleanAiEventValue(entry);
        return value ? { id: makeGeneratedId('event-highlight'), label: `Not ${index + 1}`, value } : null;
    }

    if (!entry || typeof entry !== 'object') return null;
    const label = cleanAiEventValue(entry.label ?? entry.title ?? entry.name ?? `Not ${index + 1}`);
    const value = cleanAiEventValue(entry.value ?? entry.text ?? entry.description ?? entry.note ?? '');
    if (!label && !value) return null;
    return { id: makeGeneratedId('event-highlight'), label: label || `Not ${index + 1}`, value };
};

const readAiEventHighlights = (rawEvent: any): EventHighlightItem[] => {
    const rawHighlights =
        rawEvent?.highlights ??
        rawEvent?.notes ??
        rawEvent?.eventNotes ??
        rawEvent?.etkinlikNotlari ??
        rawEvent?.etkinlikNotları ??
        rawEvent?.notlar;
    const entries = Array.isArray(rawHighlights)
        ? rawHighlights
        : typeof rawHighlights === 'string'
            ? normalizeAiNewlines(rawHighlights).split('\n').map(cleanAiEventValue).filter(Boolean)
            : [];

    return entries.map(makeAiEventHighlight).filter(Boolean) as EventHighlightItem[];
};

const hasNoAiEventSpeakers = (value: unknown) => {
    const normalized = cleanAiEventValue(value).toLocaleLowerCase('tr-TR');
    return !normalized || normalized === 'yok' || normalized.includes('doldurulmaz') || normalized.includes('konuşmacı/moderatör alanı doldurulmaz') || normalized.includes('konusmaci/moderator alani doldurulmaz');
};

const makeAiEventSpeaker = (entry: any): EventSpeakerItem | null => {
    if (typeof entry === 'string') {
        if (hasNoAiEventSpeakers(entry)) return null;
        const name = cleanAiEventValue(entry);
        return name ? {
            id: makeGeneratedId('event-speaker'),
            name,
            role: '',
            image: '',
            imageDescription: `${name} etkinlik konuğu görseli`,
            bio: '',
        } : null;
    }

    if (!entry || typeof entry !== 'object') return null;
    const name = cleanAiEventValue(entry.name ?? entry.title ?? entry.label ?? '');
    const role = cleanAiEventValue(entry.role ?? entry.unvan ?? entry.gorev ?? entry.görev ?? '');
    const bio = normalizeAiRecipeHtml(entry.bio ?? entry.description ?? entry.text ?? '');
    if (!name && !role && !normalizeQuillEmpty(bio)) return null;
    const safeName = name || role || 'Konuk';
    return {
        id: makeGeneratedId('event-speaker'),
        name: safeName,
        role,
        image: String(entry.image ?? entry.mediaUrl ?? entry.thumbnail ?? '').trim(),
        imageDescription: cleanAiEventValue(entry.imageDescription ?? entry.altText ?? entry.alt ?? '') || `${safeName} etkinlik konuğu görseli`,
        bio,
    };
};

const readAiEventSpeakers = (rawEvent: any): EventSpeakerItem[] => {
    const rawSpeakers =
        rawEvent?.speakers ??
        rawEvent?.guests ??
        rawEvent?.konusmacilar ??
        rawEvent?.konuşmacılar ??
        rawEvent?.konuklar;
    if (typeof rawSpeakers === 'string' && hasNoAiEventSpeakers(rawSpeakers)) return [];
    const entries = Array.isArray(rawSpeakers)
        ? rawSpeakers
        : typeof rawSpeakers === 'string'
            ? normalizeAiNewlines(rawSpeakers).split('\n').filter(Boolean)
            : [];
    return entries.map(makeAiEventSpeaker).filter(Boolean) as EventSpeakerItem[];
};

const buildEventItemFromAiEvent = (rawEvent: any): PostItem | null => {
    if (!rawEvent || typeof rawEvent !== 'object') return null;

    const schedule = readAiEventSchedule(rawEvent);
    const highlights = readAiEventHighlights(rawEvent);
    const speakers = readAiEventSpeakers(rawEvent);
    const title = cleanAiEventValue(rawEvent.title ?? rawEvent.eventTitle ?? rawEvent.baslik ?? rawEvent.başlık ?? '');
    const description = normalizeAiHtml(rawEvent.description ?? rawEvent.summary ?? rawEvent.spot ?? '');
    const eventData: EventData = {
        startDateTime: normalizeAiEventDateTime(rawEvent.startDateTime ?? rawEvent.start ?? rawEvent.baslangicTarihiSaati ?? rawEvent.başlangıçTarihiSaati ?? ''),
        endDateTime: normalizeAiEventDateTime(rawEvent.endDateTime ?? rawEvent.end ?? rawEvent.bitisTarihiSaati ?? rawEvent.bitişTarihiSaati ?? ''),
        organizer: cleanAiEventValue(rawEvent.organizer ?? rawEvent.organizator ?? rawEvent.organizatör ?? ''),
        venueName: cleanAiEventValue(rawEvent.venueName ?? rawEvent.venue ?? rawEvent.mekan ?? rawEvent.mekân ?? ''),
        address: cleanAiEventValue(rawEvent.address ?? rawEvent.adres ?? ''),
        latitude: cleanOptionalAiEventValue(rawEvent.latitude ?? rawEvent.lat ?? rawEvent.enlem ?? ''),
        longitude: cleanOptionalAiEventValue(rawEvent.longitude ?? rawEvent.lng ?? rawEvent.lon ?? rawEvent.boylam ?? ''),
        registrationType: normalizeAiEventRegistrationType(rawEvent.registrationType ?? rawEvent.kayitTipi ?? rawEvent.kayıtTipi ?? ''),
        ticketUrl: extractAiHttpUrl(rawEvent.ticketUrl ?? rawEvent.registrationUrl ?? rawEvent.kayitUrl ?? rawEvent.kayıtUrl ?? rawEvent.biletUrl ?? ''),
        ticketPrice: cleanOptionalAiEventValue(rawEvent.ticketPrice ?? rawEvent.biletUcreti ?? rawEvent.biletÜcreti ?? ''),
        capacity: cleanOptionalAiEventValue(rawEvent.capacity ?? rawEvent.kontenjan ?? ''),
        scheduleTitle: cleanAiEventValue(rawEvent.scheduleTitle ?? rawEvent.programTitle ?? rawEvent.programBasligi ?? rawEvent.programBaşlığı ?? '') || (schedule.length > 0 ? 'Etkinlik Programı' : ''),
        highlightsTitle: cleanAiEventValue(rawEvent.highlightsTitle ?? rawEvent.notesTitle ?? rawEvent.notlarBasligi ?? rawEvent.notlarBaşlığı ?? '') || (highlights.length > 0 ? 'Etkinlik Notları' : ''),
        speakersTitle: cleanAiEventValue(rawEvent.speakersTitle ?? rawEvent.konusmacilarBasligi ?? rawEvent.konuşmacılarBaşlığı ?? '') || (speakers.length > 0 ? 'Konuşmacılar ve Konuklar' : ''),
        schedule,
        highlights,
        speakers,
    };

    const hasEventPayload =
        title ||
        normalizeQuillEmpty(description) ||
        eventData.startDateTime ||
        eventData.endDateTime ||
        eventData.organizer ||
        eventData.venueName ||
        schedule.length > 0 ||
        highlights.length > 0 ||
        speakers.length > 0;

    if (!hasEventPayload) return null;

    return {
        id: makeGeneratedId('event'),
        type: 'event',
        title,
        description,
        createdAt: Date.now(),
        orderNumber: 1,
        eventData,
    };
};

const createEventPostItem = (): PostItem => ({
    id: Math.random().toString(36).substr(2, 9),
    type: 'event',
    title: '',
    description: '',
    createdAt: Date.now(),
    orderNumber: 1,
    eventData: createDefaultEventData(),
});

const ensureEventPostItems = (items: PostItem[]) => {
    if (items.some((item) => item.type === 'event')) return items;
    const eventItem = createEventPostItem();
    return [eventItem];
};

const readEventSpeakerImage = (item: PostItem, speakerId?: string | null) => {
    if (!speakerId || !item.eventData?.speakers) return '';
    return item.eventData.speakers.find((speaker) => speaker.id === speakerId)?.image || '';
};

const readEventScheduleImage = (item: PostItem, scheduleId?: string | null) => {
    if (!scheduleId || !item.eventData?.schedule) return '';
    return item.eventData.schedule.find((entry) => entry.id === scheduleId)?.image || '';
};

const withUpdatedEventScheduleImage = (item: PostItem, scheduleId: string, image: string) => {
    const fallback = createDefaultEventData();
    const currentEventData = item.eventData || fallback;
    const currentSchedule = Array.isArray(currentEventData.schedule) && currentEventData.schedule.length > 0
        ? currentEventData.schedule
        : fallback.schedule;

    return {
        ...fallback,
        ...currentEventData,
        schedule: currentSchedule.map((entry) =>
            entry.id === scheduleId ? { ...entry, image } : entry
        ),
        highlights: Array.isArray(currentEventData.highlights) && currentEventData.highlights.length > 0
            ? currentEventData.highlights
            : fallback.highlights,
        speakers: Array.isArray(currentEventData.speakers) && currentEventData.speakers.length > 0
            ? currentEventData.speakers
            : fallback.speakers,
    };
};

const withUpdatedEventSpeakerImage = (item: PostItem, speakerId: string, image: string) => {
    const fallback = createDefaultEventData();
    const currentEventData = item.eventData || fallback;
    const currentSpeakers = Array.isArray(currentEventData.speakers) && currentEventData.speakers.length > 0
        ? currentEventData.speakers
        : fallback.speakers;

    return {
        ...fallback,
        ...currentEventData,
        schedule: Array.isArray(currentEventData.schedule) && currentEventData.schedule.length > 0
            ? currentEventData.schedule
            : fallback.schedule,
        highlights: Array.isArray(currentEventData.highlights) && currentEventData.highlights.length > 0
            ? currentEventData.highlights
            : fallback.highlights,
        speakers: currentSpeakers.map((speaker) =>
            speaker.id === speakerId ? { ...speaker, image } : speaker
        ),
    };
};

const PostManagement: React.FC<PostManagementProps> = ({ postId, onBack, onDirtyChange }) => {
    const { t } = useLanguage();
    const { showToast } = useToast();
    const [formData, setFormData] = useState({
        id: '',
        title: '',
        summary: '',
        category: '',
        thumbnail: '',
        thumbnailAlt: '',
        seoTitle: '',
        seoDescription: '',
        keywords: '',
        slug: '',
        factChecked: false,
        schemaType: 'NewsArticle',
        publishAt: '',
        publisher_id: '',
        isPinned: false,
        showInManset: false,
        faqData: [] as { q: string, a: string }[],
        items: [] as PostItem[]
    });

    const [validationErrors, setValidationErrors] = useState<{ title?: string; summary?: string }>({});

    const [showBlockNumbers, setShowBlockNumbers] = useState(true);
    const [activeSort, setActiveSort] = useState<'asc' | 'desc' | null>('asc');
    const [isUrlMode, setIsUrlMode] = useState(false);
    const [showFileManager, setShowFileManager] = useState(false);
    const [showImageEditor, setShowImageEditor] = useState(false);
    const [imageEditorDeps, setImageEditorDeps] = useState<FilerobotDeps | null>(null);
    const [imageEditorLoadError, setImageEditorLoadError] = useState<string | null>(null);
    const [isEditorSaving, setIsEditorSaving] = useState(false);
    const [isThumbnailLoading, setIsThumbnailLoading] = useState(false);
    const [isGeneratingThumbnailAlt, setIsGeneratingThumbnailAlt] = useState(false);
    const editorSaveInFlightRef = React.useRef(false);
    const [localFiles, setLocalFiles] = useState<any[]>([]);
    const [validatingUrl, setValidatingUrl] = useState(false);
    const [urlError, setUrlError] = useState<string | null>(null);
    const [tempUrl, setTempUrl] = useState('');
    const [activeMediaTarget, setActiveMediaTarget] = useState<string | 'thumbnail' | null>(null);
    const [activeMediaSubTarget, setActiveMediaSubTarget] = useState<string | null>(null);
    const [activeMediaOptionTarget, setActiveMediaOptionTarget] = useState<string | null>(null);
    const [tagInput, setTagInput] = useState('');
    const [activeDetailTab, setActiveDetailTab] = useState<'article' | 'quiz' | 'poll' | 'video' | 'contents' | 'recipe' | 'event' | 'TABLE OF CONTENTS' | 'paragraph'>('article');
    const [activeMediaType, setActiveMediaType] = useState<'image' | 'video' | 'audio' | 'file'>('image');
    const [categories, setCategories] = useState<NavigationItem[]>([]);
    const [languages, setLanguages] = useState<Language[]>([]);
    const [selectedLanguage, setSelectedLanguage] = useState('tr');
    const [selectedParentId, setSelectedParentId] = useState<string>('');
    const [selectedSubId, setSelectedSubId] = useState<string>('');
    const [selectedThirdId, setSelectedThirdId] = useState<string>('');
    const [selectedFourthId, setSelectedFourthId] = useState<string>('');
    const [publishers, setPublishers] = useState<any[]>([]);
    const loadedCardDataRef = useRef<Record<string, any> | null>(null);

    const titleRef = useRef<HTMLInputElement>(null);
    const summaryRef = useRef<HTMLTextAreaElement>(null);
    const categoryRef = useRef<HTMLSelectElement>(null);
    const initialCategoryRef = useRef<string>('');
    const initialSelectedLanguageRef = useRef<string>(selectedLanguage);
    const initialDetailTabRef = useRef<typeof activeDetailTab>(activeDetailTab);
    const initialFormDataRef = useRef<typeof formData | null>(null);
    const [isInitialized, setIsInitialized] = useState(false);
    const [showAiDialog, setShowAiDialog] = useState(false);
    const initDirtyTimerRef = useRef<number | null>(null);
    const [isLoadingPost, setIsLoadingPost] = useState(!!postId);
    const postLoadRef = useRef<string | null>(null);

    const toDateTimeLocal = (value: string) => {
        if (!value) return '';
        const date = new Date(value);
        if (Number.isNaN(date.getTime())) return '';
        const pad = (num: number) => String(num).padStart(2, '0');
        return `${date.getFullYear()}-${pad(date.getMonth() + 1)}-${pad(date.getDate())}T${pad(date.getHours())}:${pad(date.getMinutes())}`;
    };

    const toIsoString = (value: string) => {
        if (!value) return '';
        const date = new Date(value);
        if (Number.isNaN(date.getTime())) return '';
        return date.toISOString();
    };

    const ensureUniqueItemIds = (items: PostItem[]) => {
        const seen = new Set<string>();
        return items.map((item) => {
            let nextId = item.id || '';
            if (!nextId || seen.has(nextId)) {
                nextId = `${item.type}-${Math.random().toString(36).slice(2, 9)}`;
            }
            seen.add(nextId);
            return nextId === item.id ? item : { ...item, id: nextId };
        });
    };

    const treeCategories = useMemo(() => {
        // Sadece Ana Kategori öğelerini döndürür (Ağaç görünümü kaldırıldı)
        return categories.filter(c => {
            if (c.type === 'header' || c.type === 'trends') return false;
            // Ebeveyni olmayanlar veya ebeveyni bir header (başlık) olanlar ana kategoridir
            if (!c.parent_id || c.parent_id === 'root') return true;
            const parent = categories.find(p => p.id === c.parent_id);
            return parent && parent.type === 'header';
        }).map(parent => ({ id: parent.id, label: parent.label }));
    }, [categories]);

    const selectedMainCategoryId = selectedSubId || selectedParentId;
    const subCategoryOptions = useMemo(() => {
        if (!selectedMainCategoryId) return [] as NavigationItem[];

        const rawRealOptions = categories.filter(c =>
            c.parent_id === selectedMainCategoryId &&
            (c.type === 'category' || c.type === 'district')
        );
        const seenRealOptionKeys = new Set<string>();
        const realOptions = rawRealOptions
            .map((item) => {
                const specialConfig = getSpecialContentConfig(item.value, item.label);
                if (!specialConfig) return item;
                return {
                    ...item,
                    label: specialConfig.title,
                    value: specialConfig.value,
                    icon: item.icon || specialConfig.icon,
                    order_index: Math.min(Number(item.order_index) || 0, 900 + specialConfig.rank),
                };
            })
            .filter((item) => {
                const specialConfig = getSpecialContentConfig(item.value, item.label);
                const key = specialConfig
                    ? `special:${specialConfig.key}`
                    : `normal:${normalizeNavigationOptionKey(item.value || item.label)}`;
                if (!key || seenRealOptionKeys.has(key)) return false;
                seenRealOptionKeys.add(key);
                return true;
            });
        const existingKeys = new Set(
            realOptions.flatMap((item) => [
                normalizeNavigationOptionKey(item.label),
                normalizeNavigationOptionKey(item.value),
            ]).filter(Boolean)
        );
        const selectedParent = categories.find((item) => item.id === selectedMainCategoryId);
        const menuId = selectedParent?.menu_id || categories[0]?.menu_id || '';

        const syntheticOptions = ADMIN_SPECIAL_CATEGORY_FILTERS
            .filter((config) => {
                const labelKey = normalizeNavigationOptionKey(config.title);
                const valueKey = normalizeNavigationOptionKey(config.value);
                return !existingKeys.has(labelKey) && !existingKeys.has(valueKey);
            })
            .map((config, index): NavigationItem => ({
                id: `admin-special-category-${selectedMainCategoryId}-${config.value}`,
                menu_id: menuId,
                parent_id: selectedMainCategoryId,
                label: config.title,
                type: 'category',
                value: config.value,
                icon: config.icon,
                order_index: 900 + config.rank + index,
                is_active: true,
                language_code: selectedLanguage,
            }));
        const normalSyntheticOptions = ADMIN_NORMAL_CATEGORY_FILTERS
            .filter((config) => !existingKeys.has(normalizeNavigationOptionKey(config.value)) && !existingKeys.has(normalizeNavigationOptionKey(config.label)))
            .map((config, index): NavigationItem => ({
                id: `admin-normal-category-${selectedMainCategoryId}-${config.value}`,
                menu_id: menuId,
                parent_id: selectedMainCategoryId,
                label: config.label,
                type: 'category',
                value: config.value,
                icon: config.icon,
                order_index: 920 + config.rank + index,
                is_active: true,
                language_code: selectedLanguage,
            }));

        return [...realOptions, ...syntheticOptions, ...normalSyntheticOptions]
            .sort((a, b) => (Number(a.order_index) || 0) - (Number(b.order_index) || 0));
    }, [categories, selectedLanguage, selectedMainCategoryId]);

    const isDirty = useMemo(() => {
        // Henüz başlangıç verileri yüklenmediyse dirty sayma
        if (!isInitialized || !initialFormDataRef.current) return false;

        const initial = initialFormDataRef.current;

        // Items karşılaştırması için yardımcı fonksiyon
        const normalizeDescription = (desc: string | undefined) => {
            if (!desc) return '';
            // Boş quill içeriğini normalize et
            if (desc === '<p><br></p>' || desc === '<p></p>') return '';
            return desc.trim();
        };

        const deepEqual = (a: any, b: any): boolean => {
            if (a === b) return true;
            if (Number.isNaN(a) && Number.isNaN(b)) return true;
            if (typeof a !== typeof b) return false;
            if (a == null || b == null) return a === b;

            if (Array.isArray(a)) {
                if (!Array.isArray(b)) return false;
                if (a.length !== b.length) return false;
                for (let i = 0; i < a.length; i++) {
                    if (!deepEqual(a[i], b[i])) return false;
                }
                return true;
            }

            if (typeof a === 'object') {
                if (Array.isArray(b)) return false;
                const keysA = Object.keys(a);
                const keysB = Object.keys(b);
                if (keysA.length !== keysB.length) return false;
                for (const key of keysA) {
                    if (!Object.prototype.hasOwnProperty.call(b, key)) return false;
                    if (!deepEqual(a[key], b[key])) return false;
                }
                return true;
            }

            return false;
        };

        const normalizeForCompare = <T,>(value: T): T => {
            try {
                return JSON.parse(JSON.stringify(value));
            } catch {
                return value;
            }
        };

        const normalizeItemForCompare = (item: any) => {
            const clean = normalizeForCompare(item);
            if (clean && typeof clean === 'object' && typeof (clean as any).description === 'string') {
                (clean as any).description = normalizeDescription((clean as any).description);
            }
            return clean;
        };

        const areItemsEqual = () => {
            const currentItems = (formData.items || []).map(normalizeItemForCompare);
            const initialItems = (initial.items || []).map(normalizeItemForCompare);
            return deepEqual(currentItems, initialItems);
        };

        const areFaqEqual = () => {
            const currentFaq = normalizeForCompare(formData.faqData || []);
            const initialFaq = normalizeForCompare(initial.faqData || []);
            return deepEqual(currentFaq, initialFaq);
        };

        // Tüm alanları karşılaştır
        const hasChanges = (
            selectedLanguage !== initialSelectedLanguageRef.current ||
            activeDetailTab !== initialDetailTabRef.current ||
            formData.title.trim() !== initial.title.trim() ||
            formData.summary.trim() !== initial.summary.trim() ||
            formData.category !== initial.category ||
            formData.thumbnail !== initial.thumbnail ||
            formData.thumbnailAlt !== initial.thumbnailAlt ||
            formData.seoTitle !== initial.seoTitle ||
            formData.seoDescription !== initial.seoDescription ||
            formData.keywords !== initial.keywords ||
            formData.slug !== initial.slug ||
            formData.factChecked !== initial.factChecked ||
            formData.schemaType !== initial.schemaType ||
            formData.isPinned !== initial.isPinned ||
            formData.showInManset !== initial.showInManset ||
            formData.publishAt !== initial.publishAt ||
            formData.publisher_id !== initial.publisher_id ||
            !areFaqEqual() ||
            !areItemsEqual()
        );

        return hasChanges;
    }, [formData, isInitialized, selectedLanguage, activeDetailTab]);

    useEffect(() => {
        if (onDirtyChange) onDirtyChange(isDirty);
    }, [isDirty, onDirtyChange]);

    useEffect(() => {
        return () => {
            if (onDirtyChange) onDirtyChange(false);
        };
    }, [onDirtyChange]);

    useEffect(() => {
        const fetchUserAndPublishers = async () => {
            const { data: { user } } = await neon.auth.getUser();
            if (user) {
                const { data: profile } = await neon.from('profiles').select('role').eq('id', user.id).single();
                const role = profile?.role;

                if (role === 'admin') {
                    const { data } = await neon.from('profiles').select('id, full_name').eq('role', 'publisher');
                    setPublishers(data || []);
                } else {
                    const { data: assignments } = await neon
                        .from('publisher_users')
                        .select('publisher_id')
                        .eq('user_id', user.id);

                    if (assignments && assignments.length > 0) {
                        const ids = assignments.map((a: any) => a.publisher_id);
                        const { data } = await neon.from('profiles').select('id, full_name').in('id', ids);
                        setPublishers(data || []);
                    }
                }
            }
        };
        fetchUserAndPublishers();
    }, []);

    useEffect(() => {
        if (!postId) {
            postLoadRef.current = null;
            setIsLoadingPost(false);
            loadedCardDataRef.current = null;
            return;
        }
        if (postLoadRef.current === String(postId)) return;

        postLoadRef.current = String(postId);
        setIsLoadingPost(true);

        const fetchPostData = async () => {
            try {
                const { data, error } = await neon
                    .from('posts')
                    .select('*')
                    .eq('id', postId)
                    .single();

                if (error) throw error;
                if (data) {
                    loadedCardDataRef.current = (data.card_data && typeof data.card_data === 'object' && !Array.isArray(data.card_data))
                        ? normalizeStoredPlainTextPayload(data.card_data as Record<string, any>)
                        : null;
	                    const loadedLanguage = data.language_code || 'tr';
	                    const postType = data.type === 'contents' ? 'TABLE OF CONTENTS' : (data.type as any || 'article');
	                    const storedItems = ensureUniqueItemIds(
	                        normalizeStoredPlainTextPayload((data.items || []).filter((i: any) => i.type !== 'faq') as PostItem[])
	                    );
	                    const loadedItems = postType === 'TABLE OF CONTENTS'
	                        ? ensureTocPostItems(storedItems)
                            : postType === 'recipe'
                                ? ensureRecipePostItems(storedItems)
                                : postType === 'event'
                                    ? ensureEventPostItems(storedItems)
	                            : storedItems;
	                    const loadedData = {
	                        id: data.id,
                        title: normalizeStoredPlainText(data.title),
                        summary: normalizeStoredPlainText(data.summary),
                        category: normalizeStoredPlainText(data.category),
                        thumbnail: data.thumbnail_url || '',
                        thumbnailAlt: normalizeStoredPlainText(data.thumbnail_alt),
                        seoTitle: normalizeStoredPlainText(data.seo_title),
                        seoDescription: normalizeStoredPlainText(data.seo_description),
                        keywords: normalizeStoredPlainText(data.keywords),
                        slug: data.slug || '',
                        factChecked: data.fact_checked || false,
                        schemaType: data.schema_type || (postType === 'recipe' ? 'Recipe' : postType === 'event' ? 'Event' : 'NewsArticle'),
                        publishAt: toDateTimeLocal(data.published_at || ''),
                        publisher_id: data.publisher_id || '',
                        isPinned: data.is_pinned || false,
                        showInManset: data.show_in_manset || false,
                        faqData: normalizeStoredPlainTextPayload(
                            data.faq_data || (data.items || []).find((i: any) => i.type === 'faq')?.faqData || [] as { q: string, a: string }[]
                        ),
	                        items: loadedItems
	                    };
                    setFormData(loadedData);
                    // Düzenleme modu için başlangıç verilerini kaydet
                    initialFormDataRef.current = JSON.parse(JSON.stringify(loadedData));
                    initialSelectedLanguageRef.current = loadedLanguage;
                    initialDetailTabRef.current = postType;

                    setSelectedLanguage(loadedLanguage);
                    setActiveDetailTab(postType);

                    // Set parent and sub category if possible
                    if (data.category && categories.length > 0) {
                        const foundCat = categories.find(c => c.label === data.category);
                        if (foundCat) {
                            if (foundCat.parent_id) {
                                setSelectedParentId(foundCat.parent_id);
                                setSelectedSubId(foundCat.id);
                            } else {
                                setSelectedParentId(foundCat.id);
                                setSelectedSubId('');
                            }
                        }
                    }
                }
            } catch (err) {
                console.error("Error fetching post:", err);
                postLoadRef.current = null;
                loadedCardDataRef.current = null;
            } finally {
                setIsLoadingPost(false);
            }
        };
        fetchPostData();
    }, [postId, categories]);

    useEffect(() => {
        fetchLanguages();
    }, []);

    useEffect(() => {
        if (postId && formData.items.length > 0) return;

        if (activeDetailTab === 'article') {
            const hasQuiz = formData.items.some((item: PostItem) => item.type === 'quiz' as any);
            const hasPoll = formData.items.some((item: PostItem) => item.type === 'poll');
            const hasVideo = formData.items.some((item: PostItem) => item.type === 'video');
            const hasToc = formData.items.some((item: PostItem) => item.type === 'toc');
            const hasRecipe = formData.items.some((item: PostItem) => item.type === 'recipe');
            const hasEvent = formData.items.some((item: PostItem) => item.type === 'event');

            if (hasQuiz || hasRecipe || hasEvent || (formData.items.length === 1 && (hasPoll || hasVideo || hasToc)) || formData.items.length === 0) {
                if (hasQuiz || hasPoll || hasVideo || hasToc || hasRecipe || hasEvent || formData.items.length === 0) {
                    const newItem: PostItem = {
                        id: Math.random().toString(36).substr(2, 9),
                        type: 'text',
                        title: '',
                        description: '',
                        mediaUrl: '',
                        createdAt: Date.now(),
                        orderNumber: 1
                    };
                    setFormData(prev => {
                        const nextItems = [newItem];
                        if (
                            postId &&
                            initialFormDataRef.current &&
                            (initialFormDataRef.current.items?.length || 0) === (prev.items?.length || 0) &&
                            (prev.items?.length || 0) === 0
                        ) {
                            initialFormDataRef.current.items = JSON.parse(JSON.stringify(nextItems));
                        }
                        return { ...prev, schemaType: 'NewsArticle', items: nextItems };
                    });
                }
            }
        } else if (activeDetailTab === 'poll') {
            const hasPoll = formData.items.some((item: PostItem) => item.type === 'poll');
            if (!hasPoll) {
                const pollItem: PostItem = {
                    id: Math.random().toString(36).substr(2, 9),
                    type: 'poll',
                    title: '',
                    description: '',
                    orderNumber: 1,
                    options: [
                        { id: Math.random().toString(36).substr(2, 9), text: '', votes: 0, image: '' },
                        { id: Math.random().toString(36).substr(2, 9), text: '', votes: 0, image: '' }
                    ],
                    isImagePoll: true,
                    pollColumns: 2
                };
                setFormData(prev => {
                    const nextItems = [pollItem];
                    if (
                        postId &&
                        initialFormDataRef.current &&
                        (initialFormDataRef.current.items?.length || 0) === (prev.items?.length || 0) &&
                        (prev.items?.length || 0) === 0
                    ) {
                        initialFormDataRef.current.items = JSON.parse(JSON.stringify(nextItems));
                    }
                    return { ...prev, items: nextItems };
                });
            }
        } else if (activeDetailTab === 'TABLE OF CONTENTS') {
            const hasToc = formData.items.some((item: PostItem) => item.type === 'toc');
            const onlyToc = formData.items.length === 1 && hasToc;
            if (!onlyToc) {
                const tocItem = createTocPostItem();
                setFormData(prev => {
                    const nextItems = [tocItem];
                    if (
                        postId &&
                        initialFormDataRef.current &&
                        (initialFormDataRef.current.items?.length || 0) === (prev.items?.length || 0) &&
                        (prev.items?.length || 0) === 0
                    ) {
                        initialFormDataRef.current.items = JSON.parse(JSON.stringify(nextItems));
                    }
                    return { ...prev, items: nextItems };
                });
            }
        } else if (activeDetailTab === 'recipe') {
            const hasRecipe = formData.items.some((item: PostItem) => item.type === 'recipe');
            const hasRecipeVideo = formData.items.some((item: PostItem) => item.type === 'video');
            if (!hasRecipe) {
                setFormData(prev => {
                    const nextItems = createRecipePostItems();
                    if (
                        postId &&
                        initialFormDataRef.current &&
                        (initialFormDataRef.current.items?.length || 0) === (prev.items?.length || 0) &&
                        (prev.items?.length || 0) === 0
                    ) {
                        initialFormDataRef.current.items = JSON.parse(JSON.stringify(nextItems));
                    }
                    return { ...prev, schemaType: 'Recipe', items: nextItems };
                });
            } else if (!hasRecipeVideo) {
                setFormData(prev => ({ ...prev, schemaType: 'Recipe', items: ensureRecipeVideoPostItem(prev.items) }));
            } else if (formData.schemaType !== 'Recipe') {
                setFormData(prev => ({ ...prev, schemaType: 'Recipe' }));
            }
        } else if (activeDetailTab === 'event') {
            const hasEvent = formData.items.some((item: PostItem) => item.type === 'event');
            const onlyEvent = formData.items.length === 1 && hasEvent;
            if (!onlyEvent) {
                setFormData(prev => {
                    const nextItems = [createEventPostItem()];
                    if (
                        postId &&
                        initialFormDataRef.current &&
                        (initialFormDataRef.current.items?.length || 0) === (prev.items?.length || 0) &&
                        (prev.items?.length || 0) === 0
                    ) {
                        initialFormDataRef.current.items = JSON.parse(JSON.stringify(nextItems));
                    }
                    return { ...prev, schemaType: 'Event', items: nextItems };
                });
            } else if (formData.schemaType !== 'Event') {
                setFormData(prev => ({ ...prev, schemaType: 'Event' }));
            }
        } else if (activeDetailTab === 'video') {
            const hasVideo = formData.items.some((item: PostItem) => item.type === 'video');
            if (!hasVideo) {
                const videoItem: PostItem = {
                    id: Math.random().toString(36).substr(2, 9),
                    type: 'video',
                    title: '',
                    description: '',
                    mediaUrl: '',
                    createdAt: Date.now(),
                    orderNumber: 1
                };
                setFormData(prev => {
                    const nextItems = [videoItem];
                    if (
                        postId &&
                        initialFormDataRef.current &&
                        (initialFormDataRef.current.items?.length || 0) === (prev.items?.length || 0) &&
                        (prev.items?.length || 0) === 0
                    ) {
                        initialFormDataRef.current.items = JSON.parse(JSON.stringify(nextItems));
                    }
                    return { ...prev, items: nextItems };
                });
            }
        } else if (activeDetailTab === 'quiz') {
            const hasQuiz = formData.items.some((item: PostItem) => item.type === 'quiz' as any);
            const onlyQuiz = formData.items.length === 1 && hasQuiz;
            if (!onlyQuiz) {
                const quizItem: PostItem = {
                    id: Math.random().toString(36).substr(2, 9),
                    type: 'quiz' as any,
                    title: '',
                    description: '',
                    orderNumber: 1,
                    quizData: {
                        quizType: 'personality',
                        results: [
                            { id: Math.random().toString(36).substr(2, 9), title: '', description: '', image: '' }
                        ],
                        questions: [
                            {
                                id: Math.random().toString(36).substr(2, 9),
                                title: '',
                                description: '',
                                image: '',
                                showOnCover: true,
                                layout: 'list',
                                answers: [
                                    { id: Math.random().toString(36).substr(2, 9), text: '', image: '', resultId: '' },
                                    { id: Math.random().toString(36).substr(2, 9), text: '', image: '', resultId: '' }
                                ]
                            }
                        ],
                        questionSorting: 'asc',
                        showResults: true,
                        allowMultiple: false
                    }
                };
                setFormData(prev => {
                    const nextItems = [quizItem];
                    if (
                        postId &&
                        initialFormDataRef.current &&
                        (initialFormDataRef.current.items?.length || 0) === (prev.items?.length || 0) &&
                        (prev.items?.length || 0) === 0
                    ) {
                        initialFormDataRef.current.items = JSON.parse(JSON.stringify(nextItems));
                    }
                    return { ...prev, items: nextItems };
                });
            }
        } else if (activeDetailTab === 'paragraph') {
            const hasQuote = formData.items.some((item: PostItem) => item.type === 'quote');
            if (!hasQuote) {
                const quoteItem: PostItem = {
                    id: Math.random().toString(36).substr(2, 9),
                    type: 'quote',
                    title: '',
                    description: '',
                    orderNumber: 1,
                    showOnHomepage: true
                };
                setFormData(prev => {
                    const nextItems = [quoteItem];
                    if (
                        postId &&
                        initialFormDataRef.current &&
                        (initialFormDataRef.current.items?.length || 0) === (prev.items?.length || 0) &&
                        (prev.items?.length || 0) === 0
                    ) {
                        initialFormDataRef.current.items = JSON.parse(JSON.stringify(nextItems));
                    }
                    return { ...prev, items: nextItems };
                });
            }
        }
    }, [activeDetailTab]);

    // İlk açılışta (yeni + düzenleme) otomatik doldurulan alanlar için snapshot'ı stabilize et
    useEffect(() => {
        if (isInitialized) return;

        const ready = postId ? !!formData.id : formData.items.length > 0;
        if (!ready) return;

        // Her otomatik güncellemede başlangıç snapshot'ını güncelle ve debounce ile kilitle
        initialFormDataRef.current = JSON.parse(JSON.stringify(formData));
        initialSelectedLanguageRef.current = selectedLanguage;
        initialDetailTabRef.current = activeDetailTab;

        if (initDirtyTimerRef.current) window.clearTimeout(initDirtyTimerRef.current);
        initDirtyTimerRef.current = window.setTimeout(() => {
            setIsInitialized(true);
            initDirtyTimerRef.current = null;
        }, 120);

        return () => {
            if (initDirtyTimerRef.current) {
                window.clearTimeout(initDirtyTimerRef.current);
                initDirtyTimerRef.current = null;
            }
        };
    }, [postId, formData, selectedLanguage, activeDetailTab, isInitialized]);

    const getActiveEditorSource = React.useCallback(() => {
        if (activeMediaTarget === 'thumbnail') return formData.thumbnail || '';
        const item = formData.items.find((i: PostItem) => i.id === activeMediaTarget);
        if (!item) return '';

        if (item.type === 'flipcard' && activeMediaSubTarget) {
            return (item.flipData as any)?.[activeMediaSubTarget] || '';
        }

        if (item.type === 'beforeafter' && activeMediaSubTarget) {
            return (item.beforeAfterData as any)?.[activeMediaSubTarget] || '';
        }

        if ((item.type === 'poll' || item.type === 'vs') && activeMediaSubTarget === 'options' && activeMediaOptionTarget) {
            return item.options?.find(o => o.id === activeMediaOptionTarget)?.image || '';
        }

        if (item.type === 'quiz' && activeMediaSubTarget) {
            return String(readNestedPath(item.quizData, activeMediaSubTarget) || '');
        }

        if (item.type === 'toc' && activeMediaSubTarget === 'tocItems') {
            return readTocItemImage(item, activeMediaOptionTarget);
        }

        if (item.type === 'recipe' && activeMediaSubTarget === 'recipeDirections') {
            return readRecipeDirectionImage(item, activeMediaOptionTarget);
        }

        if (item.type === 'event' && activeMediaSubTarget === 'eventSchedule') {
            return readEventScheduleImage(item, activeMediaOptionTarget);
        }

        if (item.type === 'event' && activeMediaSubTarget === 'eventSpeakers') {
            return readEventSpeakerImage(item, activeMediaOptionTarget);
        }

        return item.mediaUrl || '';
    }, [activeMediaOptionTarget, activeMediaSubTarget, activeMediaTarget, formData.items, formData.thumbnail]);

    const handleEditorSave = React.useCallback(async (editedImageObject: any) => {
        if (editorSaveInFlightRef.current) return;
        editorSaveInFlightRef.current = true;
        setIsEditorSaving(true);

        try {
            const currentMediaUrl = getActiveEditorSource();
            const storageRef = getStorageFileReference(currentMediaUrl);
            const originalName = storageRef
                ? filenameBaseFromStorageId(storageRef.id)
                : `edited-${Date.now()}`;

            let file: File;

            const mimeType: string = 'image/webp';

            const normalizeQuality = (q: unknown) => {
                if (typeof q !== 'number' || Number.isNaN(q)) return undefined;
                if (q <= 0) return undefined;
                if (q > 1) return Math.min(q / 100, 1);
                return q;
            };
            const quality = normalizeQuality(editedImageObject?.quality) ?? 0.92;

            const safeBaseName = originalName.replace(/\.[a-z0-9]+$/i, '') || `edited-${Date.now()}`;

            let blob: Blob | null = null;
            if (editedImageObject?.imageCanvas && typeof editedImageObject.imageCanvas.toBlob === 'function') {
                const canvas: HTMLCanvasElement = editedImageObject.imageCanvas;
                const makeBlob = (type: string, q?: number) =>
                    new Promise<Blob | null>((resolve) => canvas.toBlob(resolve, type, q));

                const withTimeout = <T,>(p: Promise<T>, ms: number, label: string) =>
                    Promise.race([
                        p,
                        new Promise<T>((_, reject) => setTimeout(() => reject(new Error(`${label} timed out after ${ms}ms`)), ms))
                    ]);

                blob = await withTimeout(makeBlob(mimeType, quality), 30_000, 'Canvas export');
                if (!blob && mimeType !== 'image/png') {
                    blob = await withTimeout(makeBlob('image/png'), 30_000, 'Canvas export (png fallback)');
                }
                if (!blob) throw new Error('Canvas export failed');
            } else if (editedImageObject?.imageBlob) {
                blob = editedImageObject.imageBlob;
            } else if (editedImageObject?.imageBase64) {
                const base64Str: string = editedImageObject.imageBase64;
                const dataUrl = base64Str.startsWith('data:')
                    ? base64Str
                    : `data:${mimeType};base64,${base64Str}`;
                try {
                    const response = await fetch(dataUrl);
                    blob = await response.blob();
                } catch (fetchErr) {
                    console.error('Base64 conversion failed:', fetchErr);
                    throw fetchErr;
                }
            } else if (editedImageObject?.cloudimageUrl) {
                const response = await fetch(editedImageObject.cloudimageUrl);
                blob = await response.blob();
            } else {
                console.error('No image data received from editor');
                setShowImageEditor(false);
                return;
            }

            if (!blob) {
                console.error('Blob creation failed');
                setShowImageEditor(false);
                return;
            }

            file = new File([blob], `${safeBaseName}.webp`, { type: blob.type || mimeType });

            const result = storageRef
                ? await storageService.replaceFile(file, storageRef.id, storageRef.type)
                : await storageService.uploadFile(file, undefined, 'image');

            if (result) {
                // Force cache bust
                const newSrc = `${result.src}?v=${Date.now()}`;

                if (activeMediaTarget === 'thumbnail') {
                    setIsThumbnailLoading(true);
                    setFormData(prev => ({ ...prev, thumbnail: newSrc }));
                } else if (activeMediaTarget) {
                    const targetItem = formData.items.find((i: PostItem) => i.id === activeMediaTarget);
                    if (targetItem?.type === 'flipcard' && activeMediaSubTarget) {
                        const currentFlipData = targetItem.flipData || {
                            frontImage: '',
                            backImage: '',
                            frontTitle: '',
                            backTitle: '',
                            backDescription: ''
                        };
                        handleUpdateItem(activeMediaTarget, 'flipData', {
                            ...currentFlipData,
                            [activeMediaSubTarget]: newSrc
                        });
                    } else if (targetItem?.type === 'beforeafter' && activeMediaSubTarget) {
                        const currentData = targetItem.beforeAfterData || {
                            beforeImage: '',
                            afterImage: '',
                            beforeLabel: t('admin.post.before_label_short'),
                            afterLabel: t('admin.post.after_label_short')
                        };
                        handleUpdateItem(activeMediaTarget, 'beforeAfterData', {
                            ...currentData,
                            [activeMediaSubTarget]: newSrc
                        });
                    } else if (targetItem?.type === 'poll' || targetItem?.type === 'vs') {
                        if (activeMediaSubTarget === 'options' && activeMediaOptionTarget) {
                            const currentOptions = targetItem.options || [];
                            handleUpdateItem(activeMediaTarget, 'options', currentOptions.map((o: any) =>
                                o.id === activeMediaOptionTarget ? { ...o, image: newSrc } : o
                            ));
                        } else {
                            handleUpdateItem(activeMediaTarget, 'mediaUrl', newSrc);
                        }
                    } else if (targetItem?.type === 'quiz' && activeMediaSubTarget) {
                        handleUpdateItem(activeMediaTarget, 'quizData', setNestedPath(targetItem.quizData || {}, activeMediaSubTarget, newSrc));
                    } else if (targetItem?.type === 'toc' && activeMediaSubTarget === 'tocItems' && activeMediaOptionTarget) {
                        handleUpdateItem(activeMediaTarget, 'tocData', withUpdatedTocItemImage(targetItem, activeMediaOptionTarget, newSrc));
                    } else if (targetItem?.type === 'recipe' && activeMediaSubTarget === 'recipeDirections' && activeMediaOptionTarget) {
                        handleUpdateItem(activeMediaTarget, 'recipeData', withUpdatedRecipeDirectionImage(targetItem, activeMediaOptionTarget, newSrc));
                    } else if (targetItem?.type === 'event' && activeMediaSubTarget === 'eventSchedule' && activeMediaOptionTarget) {
                        handleUpdateItem(activeMediaTarget, 'eventData', withUpdatedEventScheduleImage(targetItem, activeMediaOptionTarget, newSrc));
                    } else if (targetItem?.type === 'event' && activeMediaSubTarget === 'eventSpeakers' && activeMediaOptionTarget) {
                        handleUpdateItem(activeMediaTarget, 'eventData', withUpdatedEventSpeakerImage(targetItem, activeMediaOptionTarget, newSrc));
                    } else {
                        handleUpdateItem(activeMediaTarget, 'mediaUrl', newSrc);
                    }
                }

                // Update local files list
                setLocalFiles(prev => {
                    const currentSrcWithoutQuery = currentMediaUrl ? stripUrlNoise(currentMediaUrl) : '';
                    const filtered = prev.filter((p: any) => {
                        const oldIdMatch = storageRef && p.id === storageRef.id;
                        const newIdMatch = p.id === result.id;
                        const srcMatch = currentSrcWithoutQuery && stripUrlNoise(p.src || '') === currentSrcWithoutQuery;
                        return !oldIdMatch && !newIdMatch && !srcMatch;
                    });
                    return [result, ...filtered];
                });
            } else {
                console.error('Upload failed');
            }
        } catch (err) {
            console.error('Editor save failed:', err);
        } finally {
            // ALWAYS close the editor
            editorSaveInFlightRef.current = false;
            setIsEditorSaving(false);
            setShowImageEditor(false);
        }
    }, [activeMediaOptionTarget, activeMediaSubTarget, activeMediaTarget, formData.items, getActiveEditorSource, t]);

    const handleEditorClose = React.useCallback((closeReason?: any, haveNotSavedChanges?: any) => {
        editorSaveInFlightRef.current = false;
        setIsEditorSaving(false);
        setShowImageEditor(false);
    }, []);

    const handleEditorBeforeSave = React.useCallback((savedImageData: any) => {
        setIsEditorSaving(true);
        // Skip the default "Save As" modal and trigger save immediately
        // (we overwrite the existing file path on the backend via customPath).
        return false;
    }, []);

    useEffect(() => {
        if (!showImageEditor || imageEditorDeps) return;

        let active = true;
        setImageEditorLoadError(null);
        loadFilerobotDeps()
            .then((deps) => {
                if (active) setImageEditorDeps(deps);
            })
            .catch((error: any) => {
                if (!active) return;
                setImageEditorLoadError(error?.message || 'Image editor could not be loaded');
            });

        return () => {
            active = false;
        };
    }, [imageEditorDeps, showImageEditor]);

    const editorConfig = React.useMemo(() => {
        if (!imageEditorDeps) return null;

        const { FieEmojiToolButton, FieEmojiToolOptions } = createFieEmojiComponents(imageEditorDeps);
        const { FIE_DEFAULT_TOOLS_ITEMS, TABS, TOOLS } = imageEditorDeps;

        return {
            annotationsCommon: { fill: '#ff0000' },
            theme: {
                typography: {
                    fontFamily: `${FIE_TEXT_FONTS.join(', ')}, sans-serif`
                }
            },
            tools: {
                ...FIE_DEFAULT_TOOLS_ITEMS,
                [FIE_EMOJI_TOOL_ID]: {
                    id: FIE_EMOJI_TOOL_ID,
                    Item: FieEmojiToolButton,
                    ItemOptions: FieEmojiToolOptions,
                },
            },
            Text: {
                fonts: FIE_TEXT_FONT_OPTIONS,
                fontSize: 120,
                onFontChange: (fontFamily: string, reRenderCanvas: () => void) => {
                    if (typeof document === 'undefined' || !document.fonts?.load) {
                        reRenderCanvas();
                        return;
                    }
                    const match = FIE_TEXT_FONTS.find((font) => font.toLowerCase() === fontFamily) || fontFamily;
                    document.fonts.load(`16px "${match}"`).finally(reRenderCanvas);
                }
            },
            Rotate: { angle: 90, componentType: 'slider' },
            tabsIds: [TABS.ADJUST, TABS.FILTERS, TABS.FINETUNE, TABS.ANNOTATE, TABS.WATERMARK],
            defaultTabId: TABS.ANNOTATE,
            defaultToolId: TOOLS.TEXT,
            closeAfterSave: true,
            defaultSavedImageType: 'webp',
            defaultSavedImageQuality: 1,
            onBeforeSave: handleEditorBeforeSave,
            savingPixelRatio: 1,
            previewPixelRatio: 1,
            willReadFrequently: true,
            tabsToolsIds: {
                [TABS.ADJUST]: [TOOLS.CROP, TOOLS.ROTATE, TOOLS.FLIP_X, TOOLS.FLIP_Y],
                [TABS.FINETUNE]: [TOOLS.BRIGHTNESS, TOOLS.CONTRAST, TOOLS.HSV, TOOLS.BLUR, TOOLS.WARMTH],
                [TABS.FILTERS]: [TOOLS.FILTERS],
                [TABS.WATERMARK]: [TOOLS.WATERMARK],
                [TABS.ANNOTATE]: [TOOLS.TEXT, TOOLS.IMAGE, TOOLS.RECT, TOOLS.ELLIPSE, TOOLS.POLYGON, TOOLS.PEN, TOOLS.LINE, TOOLS.ARROW, FIE_EMOJI_TOOL_ID],
            },
            [TABS.ADJUST]: {
                hideResize: true,
            },
        };
    }, [handleEditorBeforeSave, imageEditorDeps]);

    const editorShouldForwardProp = React.useMemo(
        () => imageEditorDeps ? createShouldForwardProp(imageEditorDeps.isPropValid) : undefined,
        [imageEditorDeps]
    );
    const ImageEditorStyleSheetManager = imageEditorDeps?.StyleSheetManager;
    const ImageEditorComponent = imageEditorDeps?.FilerobotEditor;

    useEffect(() => {
        if (selectedLanguage) {
            fetchCategories(selectedLanguage);
            if (formData.id === '' && !postId) {
                setSelectedParentId('');
                setSelectedSubId('');
                setFormData(prev => ({ ...prev, category: '' }));
            }
        }
    }, [selectedLanguage]);

    const fetchLanguages = async () => {
        try {
            const { data } = await neon.from('languages').select('code, name');
            if (data) setLanguages(data);
        } catch (error) {
            console.error("Error fetching languages:", error);
        }
    };

    const fetchCategories = async (langCode: string) => {
        try {
            const { data: itemData } = await neon
                .from('navigation_items')
                .select('*')
                .eq('language_code', langCode)
                .order('order_index', { ascending: true });

            setCategories(itemData || []);

            if (itemData && itemData.length > 0) {
                // 1. Try to find the existing category
                let matchedItem = formData.category
                    ? itemData.find((i: NavigationItem) => i.label === formData.category)
                    : null;

                // 2. If no category set, try to pick a reasonable default
                if (!matchedItem) {
                    matchedItem = itemData.find((i: NavigationItem) => !i.parent_id && i.type !== 'header');
                }

                if (matchedItem) {
                    const parentItem = itemData.find((i: NavigationItem) => i.id === matchedItem.parent_id);
                    const grandParentItem = parentItem ? itemData.find((i: NavigationItem) => i.id === parentItem.parent_id) : null;

                    if (grandParentItem && grandParentItem.id !== 'root' && grandParentItem.type !== 'header') {
                        // Level 3 category matched
                        setSelectedParentId(grandParentItem.id);
                        setSelectedThirdId(parentItem!.id);
                        setSelectedFourthId(matchedItem.id);
                    } else if (parentItem && parentItem.id !== 'root' && parentItem.type !== 'header') {
                        // Level 2 category matched
                        setSelectedParentId(parentItem.id);
                        setSelectedThirdId(matchedItem.id);
                        setSelectedFourthId('');
                    } else {
                        // Level 1 category matched
                        setSelectedParentId(matchedItem.id);
                        setSelectedThirdId('');
                        setSelectedFourthId('');
                    }

                    if (formData.category !== matchedItem.label) {
                        const nextCategoryLabel = matchedItem.label;
                        if (!postId && !initialCategoryRef.current) {
                            initialCategoryRef.current = nextCategoryLabel;
                        }
                        setFormData(prev => {
                            if (initialFormDataRef.current && initialFormDataRef.current.category === prev.category) {
                                initialFormDataRef.current.category = nextCategoryLabel;
                            }
                            return { ...prev, category: nextCategoryLabel };
                        });
                    }
                }
            }
        } catch (error) {
            console.error("Error fetching categories:", error);
        }
    };

    const handleParentCategoryChange = (catId: string) => {
        const treeItem = treeCategories.find(c => c.id === catId);
        setSelectedThirdId(''); // Her ana seçimde alt seçimi sıfırla
        setSelectedFourthId(''); // Üçüncü seviye seçimi sıfırla

        if (!treeItem) {
            setSelectedParentId('');
            setSelectedSubId('');
            setFormData({ ...formData, category: '' });
            return;
        }

        // Sadece Ana Kategori seçimi aktif (Ağaç yapısı kaldırıldığı için parentId kontrolüne gerek yok)
        setSelectedParentId(treeItem.id);
        setSelectedSubId('');
        setFormData({ ...formData, category: treeItem.label });
    };

    const handleSubCategoryChange = (catId: string) => {
        setSelectedThirdId(catId);
        setSelectedFourthId(''); // İkinci seviye değişince üçüncü seviyeyi sıfırla
        const cat = subCategoryOptions.find(c => c.id === catId) || categories.find(c => c.id === catId);
        if (cat) {
            setFormData({ ...formData, category: cat.label });
        }
    };

    const handleSubSubCategoryChange = (catId: string) => {
        setSelectedFourthId(catId);
        const cat = categories.find(c => c.id === catId);
        if (cat) {
            setFormData({ ...formData, category: cat.label });
        }
    };

    const fetchMedia = async (type: 'image' | 'video' | 'audio' | 'file' = 'image') => {
        const files = await storageService.getFiles(type);
        setLocalFiles(files);
    };

    const validateImageUrl = (url: string): Promise<boolean> => {
        return new Promise((resolve) => {
            const img = new Image();
            img.onload = () => resolve(true);
            img.onerror = () => resolve(false);
            img.src = url;
            setTimeout(() => resolve(false), 5000);
        });
    };

    const handleUrlSubmit = async () => {
        const trimmedUrl = tempUrl.trim();
        if (!trimmedUrl) {
            setUrlError(t('common.error'));
            return;
        }
        setValidatingUrl(true);
        setUrlError(null);

        // Skip image validation if we are in video or audio mode
        if (activeMediaType === 'video' || activeMediaType === 'audio') {
            if (activeMediaTarget) {
                handleUpdateItem(activeMediaTarget, 'mediaUrl', trimmedUrl);
            }
            setIsUrlMode(false);
            setTempUrl('');
        } else {
            const isValid = await validateImageUrl(trimmedUrl);
            if (isValid) {
                if (activeMediaTarget === 'thumbnail') {
                    setFormData({ ...formData, thumbnail: trimmedUrl });
                } else if (activeMediaTarget) {
                    const targetItem = formData.items.find((i: PostItem) => i.id === activeMediaTarget);
                    if (targetItem?.type === 'flipcard' && activeMediaSubTarget) {
                        const currentFlipData = targetItem.flipData || {
                            frontImage: '',
                            backImage: '',
                            frontTitle: '',
                            backTitle: '',
                            backDescription: ''
                        };
                        handleUpdateItem(activeMediaTarget, 'flipData', {
                            ...currentFlipData,
                            [activeMediaSubTarget]: trimmedUrl
                        });
                    } else if (targetItem?.type === 'beforeafter' && activeMediaSubTarget) {
                        const currentData = targetItem.beforeAfterData || {
                            beforeImage: '',
                            afterImage: '',
                            beforeLabel: t('admin.post.before_label_short'),
                            afterLabel: t('admin.post.after_label_short')
                        };
                        handleUpdateItem(activeMediaTarget, 'beforeAfterData', {
                            ...currentData,
                            [activeMediaSubTarget]: trimmedUrl
                        });
                    } else if (targetItem?.type === 'poll' || targetItem?.type === 'vs') {
                        if (activeMediaSubTarget === 'options' && activeMediaOptionTarget) {
                            const currentOptions = targetItem.options || [];
                            handleUpdateItem(activeMediaTarget, 'options', currentOptions.map((o: any) =>
                                o.id === activeMediaOptionTarget ? { ...o, image: trimmedUrl } : o
                            ));
                        } else {
                            handleUpdateItem(activeMediaTarget, 'mediaUrl', trimmedUrl);
                        }
                    } else if (targetItem?.type === 'quiz' && activeMediaSubTarget) {
                        handleUpdateItem(activeMediaTarget, 'quizData', setNestedPath(targetItem.quizData || {}, activeMediaSubTarget, trimmedUrl));
                    } else if (targetItem?.type === 'toc' && activeMediaSubTarget === 'tocItems' && activeMediaOptionTarget) {
                        handleUpdateItem(activeMediaTarget, 'tocData', withUpdatedTocItemImage(targetItem, activeMediaOptionTarget, trimmedUrl));
                    } else if (targetItem?.type === 'recipe' && activeMediaSubTarget === 'recipeDirections' && activeMediaOptionTarget) {
                        handleUpdateItem(activeMediaTarget, 'recipeData', withUpdatedRecipeDirectionImage(targetItem, activeMediaOptionTarget, trimmedUrl));
                    } else if (targetItem?.type === 'event' && activeMediaSubTarget === 'eventSchedule' && activeMediaOptionTarget) {
                        handleUpdateItem(activeMediaTarget, 'eventData', withUpdatedEventScheduleImage(targetItem, activeMediaOptionTarget, trimmedUrl));
                    } else if (targetItem?.type === 'event' && activeMediaSubTarget === 'eventSpeakers' && activeMediaOptionTarget) {
                        handleUpdateItem(activeMediaTarget, 'eventData', withUpdatedEventSpeakerImage(targetItem, activeMediaOptionTarget, trimmedUrl));
                    } else {
                        handleUpdateItem(activeMediaTarget, 'mediaUrl', trimmedUrl);
                    }
                }
                setIsUrlMode(false);
                setTempUrl('');
            } else {
                setUrlError(t('admin.generic_error').replace('{error}', 'Invalid URL'));
            }
        }
        setValidatingUrl(false);
    };

    const handleAddItem = () => {
        const newItem: PostItem = {
            id: Math.random().toString(36).substr(2, 9),
            type: 'text',
            title: '',
            description: '',
            mediaUrl: '',
            createdAt: Date.now(),
            orderNumber: 0 // Will be set by re-sequencing
        };

        let newItems = [...formData.items, newItem];

        // Always re-sequence if activeSort is set, otherwise just give it a number
        if (activeSort) {
            newItems = newItems.map((item: PostItem, idx: number) => ({
                ...item,
                orderNumber: activeSort === 'asc' ? (idx + 1) : (newItems.length - idx)
            }));
        } else {
            const nextOrder = formData.items.length > 0
                ? Math.max(...formData.items.map((i: PostItem) => i.orderNumber || 0)) + 1
                : 1;
            newItems[newItems.length - 1].orderNumber = nextOrder;
        }

        setFormData({ ...formData, items: newItems });
    };

    const handleAddImageItem = () => {
        const newItem: PostItem = {
            id: Math.random().toString(36).substr(2, 9),
            type: 'image',
            title: '',
            description: '',
            mediaUrl: '',
            createdAt: Date.now(),
            orderNumber: 0 // Will be set by re-sequencing
        };

        let newItems = [...formData.items, newItem];

        if (activeSort) {
            newItems = newItems.map((item: PostItem, idx: number) => ({
                ...item,
                orderNumber: activeSort === 'asc' ? (idx + 1) : (newItems.length - idx)
            }));
        } else {
            const nextOrder = formData.items.length > 0
                ? Math.max(...formData.items.map((i: PostItem) => i.orderNumber || 0)) + 1
                : 1;
            newItems[newItems.length - 1].orderNumber = nextOrder;
        }

        setFormData({ ...formData, items: newItems });
    };

    const handleAddSliderItem = () => {
        const newItem: PostItem = {
            id: Math.random().toString(36).substr(2, 9),
            type: 'slider',
            title: '',
            description: '',
            mediaUrls: [],
            createdAt: Date.now(),
            orderNumber: 0
        };

        let newItems = [...formData.items, newItem];

        if (activeSort) {
            newItems = newItems.map((item: PostItem, idx: number) => ({
                ...item,
                orderNumber: activeSort === 'asc' ? (idx + 1) : (newItems.length - idx)
            }));
        } else {
            const nextOrder = formData.items.length > 0
                ? Math.max(...formData.items.map((i: PostItem) => i.orderNumber || 0)) + 1
                : 1;
            newItems[newItems.length - 1].orderNumber = nextOrder;
        }

        setFormData({ ...formData, items: newItems });
    };

    const handleAddVideoItem = () => {
        const newItem: PostItem = {
            id: Math.random().toString(36).substr(2, 9),
            type: 'video',
            title: '',
            description: '',
            mediaUrl: '',
            createdAt: Date.now(),
            orderNumber: 0
        };

        const newItems = [...formData.items, newItem];

        let finalItems = newItems;
        if (activeSort) {
            finalItems = newItems.map((item: PostItem, idx: number) => ({
                ...item,
                orderNumber: activeSort === 'asc' ? (idx + 1) : (newItems.length - idx)
            }));
        } else {
            const nextOrder = formData.items.length > 0
                ? Math.max(...formData.items.map((i: PostItem) => i.orderNumber || 0)) + 1
                : 1;
            finalItems[finalItems.length - 1].orderNumber = nextOrder;
        }

        setFormData({ ...formData, items: finalItems });
    };

    const handleAddAudioItem = () => {
        const newItem: PostItem = {
            id: Math.random().toString(36).substr(2, 9),
            type: 'audio',
            title: '',
            description: '',
            mediaUrl: '',
            createdAt: Date.now(),
            orderNumber: 0
        };

        const newItems = [...formData.items, newItem];
        let finalItems = newItems;
        if (activeSort) {
            finalItems = newItems.map((item: PostItem, idx: number) => ({
                ...item,
                orderNumber: activeSort === 'asc' ? (idx + 1) : (newItems.length - idx)
            }));
        } else {
            const nextOrder = formData.items.length > 0
                ? Math.max(...formData.items.map((i: PostItem) => i.orderNumber || 0)) + 1
                : 1;
            finalItems[finalItems.length - 1].orderNumber = nextOrder;
        }
        setFormData({ ...formData, items: finalItems });
    };

    const handleAddFileItem = () => {
        const newItem: PostItem = {
            id: Math.random().toString(36).substr(2, 9),
            type: 'file',
            title: '',
            description: '',
            mediaUrl: '',
            createdAt: Date.now(),
            orderNumber: 0
        };

        const newItems = [...formData.items, newItem];
        let finalItems = newItems;
        if (activeSort) {
            finalItems = newItems.map((item: PostItem, idx: number) => ({
                ...item,
                orderNumber: activeSort === 'asc' ? (idx + 1) : (newItems.length - idx)
            }));
        } else {
            const nextOrder = formData.items.length > 0
                ? Math.max(...formData.items.map((i: PostItem) => i.orderNumber || 0)) + 1
                : 1;
            finalItems[finalItems.length - 1].orderNumber = nextOrder;
        }
        setFormData({ ...formData, items: finalItems });
    };

    const handleAddSocialItem = () => {
        const newItem: PostItem = {
            id: Math.random().toString(36).substr(2, 9),
            type: 'social',
            title: '',
            description: '',
            mediaUrl: '',
            createdAt: Date.now(),
            orderNumber: 0
        };

        const newItems = [...formData.items, newItem];
        let finalItems = newItems;
        if (activeSort) {
            finalItems = newItems.map((item: PostItem, idx: number) => ({
                ...item,
                orderNumber: activeSort === 'asc' ? (idx + 1) : (newItems.length - idx)
            }));
        } else {
            const nextOrder = formData.items.length > 0
                ? Math.max(...formData.items.map((i: PostItem) => i.orderNumber || 0)) + 1
                : 1;
            finalItems[finalItems.length - 1].orderNumber = nextOrder;
        }
        setFormData({ ...formData, items: finalItems });
    };

    const handleAddFlipCardItem = () => {
        const newItem: PostItem = {
            id: Math.random().toString(36).substr(2, 9),
            type: 'flipcard',
            title: '',
            description: '',
            createdAt: Date.now(),
            orderNumber: 0,
            flipData: {
                frontImage: '',
                backImage: '',
                frontTitle: '',
                backTitle: '',
                frontDescription: '',
                backDescription: '',
                frontLink: '',
                backLink: ''
            }
        };

        const newItems = [...formData.items, newItem];
        let finalItems = newItems;
        if (activeSort) {
            finalItems = newItems.map((item: PostItem, idx: number) => ({
                ...item,
                orderNumber: activeSort === 'asc' ? (idx + 1) : (newItems.length - idx)
            }));
        } else {
            const nextOrder = formData.items.length > 0
                ? Math.max(...formData.items.map((i: PostItem) => i.orderNumber || 0)) + 1
                : 1;
            finalItems[finalItems.length - 1].orderNumber = nextOrder;
        }
        setFormData({ ...formData, items: finalItems });
    };

    const handleAddBeforeAfterItem = () => {
        const newItem: PostItem = {
            id: Math.random().toString(36).substr(2, 9),
            type: 'beforeafter',
            title: '',
            description: '',
            orderNumber: 0,
            beforeAfterData: {
                beforeImage: '',
                afterImage: '',
                beforeLabel: t('admin.post.before_label_short'),
                afterLabel: t('admin.post.after_label_short')
            }
        };

        const newItems = [...formData.items, newItem];
        let finalItems = newItems;
        if (activeSort) {
            finalItems = newItems.map((item: PostItem, idx: number) => ({
                ...item,
                orderNumber: activeSort === 'asc' ? (idx + 1) : (newItems.length - idx)
            }));
        } else {
            const nextOrder = formData.items.length > 0
                ? Math.max(...formData.items.map((i: PostItem) => i.orderNumber || 0)) + 1
                : 1;
            finalItems[finalItems.length - 1].orderNumber = nextOrder;
        }
        setFormData({ ...formData, items: finalItems });
    };

    const handleAddPollItem = () => {
        const newItem: PostItem = {
            id: Math.random().toString(36).substr(2, 9),
            type: 'poll',
            title: '',
            description: '',
            orderNumber: 0,
            options: [
                { id: Math.random().toString(36).substr(2, 9), text: '', votes: 0, image: '' },
                { id: Math.random().toString(36).substr(2, 9), text: '', votes: 0, image: '' }
            ],
            isImagePoll: true,
            pollColumns: 2
        };

        const newItems = [...formData.items, newItem];
        let finalItems = newItems;
        if (activeSort) {
            finalItems = newItems.map((item: PostItem, idx: number) => ({
                ...item,
                orderNumber: activeSort === 'asc' ? (idx + 1) : (newItems.length - idx)
            }));
        } else {
            const nextOrder = formData.items.length > 0
                ? Math.max(...formData.items.map((i: PostItem) => i.orderNumber || 0)) + 1
                : 1;
            finalItems[finalItems.length - 1].orderNumber = nextOrder;
        }
        setFormData({ ...formData, items: finalItems });
    };

    const handleUpdateItem = (id: string, field: keyof PostItem, value: any) => {
        setFormData(prev => {
            let updatedItems;

            if (field === 'showOnHomepage' && value === true) {
                // Eğer bu item ana sayfada gösterilecekse, diğer hepsini kapat
                updatedItems = prev.items.map((item: PostItem) => ({
                    ...item,
                    showOnHomepage: item.id === id ? true : false
                }));
            } else {
                // Diğer güncellemeler normal şekilde devam etsin
                updatedItems = prev.items.map((item: PostItem) =>
                    item.id === id ? { ...item, [field]: value } : item
                );
            }

            return {
                ...prev,
                items: updatedItems
            };
        });
    };

    type MediaRenameType = 'image' | 'video' | 'audio' | 'file' | 'logo' | 'profile';

    const buildMediaRenameContext = React.useCallback(() => {
        const lines: string[] = [
            `Haber başlığı: ${formData.title || ''}`,
            `Kısa özet/spot: ${formData.summary || ''}`,
            `SEO başlık: ${formData.seoTitle || ''}`,
            `SEO açıklama: ${formData.seoDescription || ''}`,
            `Kategori: ${formData.category || ''}`,
            `Anahtar kelimeler: ${formData.keywords || ''}`,
            `Yayın dili: ${selectedLanguage || 'tr'}`,
        ];

        if (formData.faqData.length > 0) {
            lines.push('FAQ:');
            formData.faqData.forEach((faq, index) => {
                lines.push(`${index + 1}. Soru: ${faq.q || ''}`);
                lines.push(`${index + 1}. Cevap: ${faq.a || ''}`);
            });
        }

        formData.items.forEach((item, index) => {
            lines.push(`İçerik bloğu ${index + 1} (${item.type || 'text'}):`);
            if (item.title) lines.push(`Başlık: ${item.title}`);
            if (item.description) lines.push(`Açıklama/metin: ${htmlToPlainText(item.description)}`);
            if (item.altText) lines.push(`Alt metin: ${item.altText}`);
            if (item.source) lines.push(`Kaynak: ${item.source}`);
            if (item.flipData) {
                lines.push(`Flip ön başlık: ${item.flipData.frontTitle || ''}`);
                lines.push(`Flip arka başlık: ${item.flipData.backTitle || ''}`);
                lines.push(`Flip ön açıklama: ${htmlToPlainText(item.flipData.frontDescription)}`);
                lines.push(`Flip arka açıklama: ${htmlToPlainText(item.flipData.backDescription)}`);
            }
            if (item.beforeAfterData) {
                lines.push(`Before/After önce etiketi: ${item.beforeAfterData.beforeLabel || ''}`);
                lines.push(`Before/After sonra etiketi: ${item.beforeAfterData.afterLabel || ''}`);
            }
            if (item.reviewData) {
                lines.push(`İnceleme ürünü/konusu: ${item.reviewData.productName || ''}`);
                lines.push(`İnceleme kararı: ${htmlToPlainText(item.reviewData.verdict)}`);
                lines.push(`Artılar: ${(item.reviewData.pros || []).join(', ')}`);
                lines.push(`Eksiler: ${(item.reviewData.cons || []).join(', ')}`);
            }
            if (item.options?.length) {
                lines.push(`Seçenekler: ${item.options.map((option) => option.text).filter(Boolean).join(', ')}`);
            }
            if (item.quizData) {
                lines.push(`Quiz tipi: ${item.quizData.quizType}`);
                lines.push(`Quiz sonuçları: ${(item.quizData.results || []).map((result) => `${result.title} ${htmlToPlainText(result.description)}`).join(' | ')}`);
                lines.push(`Quiz soruları: ${(item.quizData.questions || []).map((question) => {
                    const answers = (question.answers || []).map((answer) => answer.text).filter(Boolean).join(', ');
                    return `${question.title} ${htmlToPlainText(question.description)} Cevaplar: ${answers}`;
                }).join(' | ')}`);
            }
            if (item.tocData?.items?.length) {
                lines.push(`İçindekiler URL: ${item.tocData.optionalUrl || ''}`);
                lines.push(`İçindekiler maddeleri: ${item.tocData.items.map((tocItem) =>
                    `${tocItem.orderNumber}. ${tocItem.title} ${htmlToPlainText(tocItem.content)}`
                ).join(' | ')}`);
            }
            if (item.recipeData) {
                lines.push(`Tarif URL: ${item.recipeData.optionalUrl || ''}`);
                lines.push(`Tarif süreleri: Hazırlık ${item.recipeData.prepTime || ''}, pişirme ${item.recipeData.cookTime || ''}, porsiyon ${item.recipeData.serving || ''}, zorluk ${item.recipeData.difficulty || ''}`);
                lines.push(`Malzemeler: ${(item.recipeData.ingredients || []).map((ingredient) => ingredient.text).filter(Boolean).join(', ')}`);
                lines.push(`Besin değerleri: ${(item.recipeData.nutrition || []).map((nutrition) => `${nutrition.label} ${nutrition.value}`.trim()).filter(Boolean).join(', ')}`);
                lines.push(`Tarif adımları: ${(item.recipeData.directions || []).map((direction) =>
                    `${direction.orderNumber}. ${direction.title} ${htmlToPlainText(direction.content)}`
                ).join(' | ')}`);
            }
            if (item.eventData) {
                lines.push(`Etkinlik zamanları: ${item.eventData.startDateTime || ''} - ${item.eventData.endDateTime || ''}`);
                lines.push(`Etkinlik organizatörü: ${item.eventData.organizer || ''}`);
                lines.push(`Etkinlik konumu: ${item.eventData.venueName || ''} ${item.eventData.address || ''}`.trim());
                lines.push(`Etkinlik programı: ${(item.eventData.schedule || []).map((entry) => `${entry.date} ${entry.time} ${entry.title} ${entry.description}`.trim()).filter(Boolean).join(' | ')}`);
                lines.push(`Etkinlik öne çıkanlar: ${(item.eventData.highlights || []).map((entry) => `${entry.label} ${entry.value}`.trim()).filter(Boolean).join(' | ')}`);
                lines.push(`Etkinlik konuşmacıları: ${(item.eventData.speakers || []).map((speaker) => `${speaker.name} ${speaker.role} ${htmlToPlainText(speaker.bio)}`.trim()).filter(Boolean).join(' | ')}`);
            }
        });

        return lines.filter(Boolean).join('\n').slice(0, 6000);
    }, [formData, selectedLanguage]);

    const buildFocusedMediaKind = React.useCallback((item: PostItem, index: number, label: string) => {
        const parts = [label, `blok ${index + 1}`];

        if (item.title) parts.push(`başlık: ${item.title}`);
        if (item.description) parts.push(`metin: ${htmlToPlainText(item.description).slice(0, 220)}`);
        if (item.altText) parts.push(`alt metin: ${item.altText}`);
        if (item.source) parts.push(`kaynak: ${item.source}`);
        if (item.options?.length) {
            parts.push(`seçenekler: ${item.options.map((option) => option.text).filter(Boolean).join(', ')}`);
        }
        if (item.flipData) {
            parts.push(`flip ön: ${item.flipData.frontTitle || ''} ${htmlToPlainText(item.flipData.frontDescription).slice(0, 120)}`.trim());
            parts.push(`flip arka: ${item.flipData.backTitle || ''} ${htmlToPlainText(item.flipData.backDescription).slice(0, 120)}`.trim());
        }
        if (item.beforeAfterData) {
            parts.push(`before after: ${item.beforeAfterData.beforeLabel || ''} / ${item.beforeAfterData.afterLabel || ''}`);
        }
        if (item.reviewData) {
            parts.push(`inceleme: ${item.reviewData.productName || ''} ${htmlToPlainText(item.reviewData.verdict).slice(0, 160)}`.trim());
        }
        if (item.quizData) {
            parts.push(`quiz: ${(item.quizData.questions || []).map((question) => question.title).filter(Boolean).join(', ')}`);
        }
        if (item.tocData?.items?.length) {
            parts.push(`içindekiler: ${item.tocData.items.map((tocItem) => tocItem.title).filter(Boolean).join(', ')}`);
        }
        if (item.recipeData) {
            parts.push(`tarif: ${(item.recipeData.directions || []).map((direction) => direction.title).filter(Boolean).join(', ')}`);
            parts.push(`malzemeler: ${(item.recipeData.ingredients || []).map((ingredient) => ingredient.text).filter(Boolean).join(', ')}`);
        }
        if (item.eventData) {
            parts.push(`etkinlik: ${item.eventData.venueName || ''} ${item.eventData.organizer || ''}`.trim());
            parts.push(`konuşmacılar: ${(item.eventData.speakers || []).map((speaker) => speaker.name).filter(Boolean).join(', ')}`);
        }

        return parts.filter(Boolean).join(' | ').slice(0, 700);
    }, []);

    const replaceMediaReferences = React.useCallback((value: any, replacements: Array<{ oldSrc: string; newSrc: string }>, cacheToken: number): any => {
        if (typeof value === 'string') {
            const cleanValue = normalizeMediaReferenceForCompare(value);
            const match = replacements.find((item) => normalizeMediaReferenceForCompare(item.oldSrc) === cleanValue);
            return match ? `${match.newSrc}?v=${cacheToken}` : value;
        }

        if (Array.isArray(value)) {
            return value.map((item) => replaceMediaReferences(item, replacements, cacheToken));
        }

        if (value && typeof value === 'object') {
            return Object.fromEntries(
                Object.entries(value).map(([key, nestedValue]) => [key, replaceMediaReferences(nestedValue, replacements, cacheToken)])
            );
        }

        return value;
    }, []);

    const handleRenameMediaWithAi = React.useCallback(async (src: string, type: MediaRenameType = 'image', mediaKind = 'haber medyası') => {
        const result = await storageService.renameMediaWithAi({
            src,
            type,
            languageCode: selectedLanguage,
            mediaKind,
            context: buildMediaRenameContext()
        });

        if (!result || !result.replacements?.length) {
            showToast('AI dosya adı oluşturulamadı veya medya yeniden adlandırılamadı.', 'error');
            return null;
        }

        const cacheToken = Date.now();
        setFormData(prev => replaceMediaReferences(prev, result.replacements, cacheToken));
        setLocalFiles(prev => prev.map((file: any) => {
            const replacement = result.replacements.find((item) =>
                normalizeMediaReferenceForCompare(item.oldId) === normalizeMediaReferenceForCompare(file.id) ||
                normalizeMediaReferenceForCompare(item.oldSrc) === normalizeMediaReferenceForCompare(file.src)
            );
            return replacement
                ? {
                    ...file,
                    id: replacement.newId,
                    value: replacement.newId.split('/').pop(),
                    src: replacement.newSrc,
                    thumb: replacement.newSrc,
                    path: replacement.newId.split('/')[0],
                    date: cacheToken / 1000
                }
                : file;
        }));
        showToast('Medya adı SEO uyumlu olarak güncellendi.', 'success');

        const selectedReplacement = result.replacements.find((item) => normalizeMediaReferenceForCompare(item.oldSrc) === normalizeMediaReferenceForCompare(src)) || result.replacements[0];
        return `${selectedReplacement.newSrc}?v=${cacheToken}`;
    }, [buildMediaRenameContext, replaceMediaReferences, selectedLanguage, showToast]);

    const handleGenerateThumbnailAltWithAi = React.useCallback(async () => {
        if (!formData.thumbnail || isGeneratingThumbnailAlt) return;

        setIsGeneratingThumbnailAlt(true);
        try {
            const result = await storageService.generateMediaAltTextWithAi({
                src: formData.thumbnail,
                languageCode: selectedLanguage,
                mediaKind: `haber kapak görseli | ${formData.title || formData.summary || ''}`,
                currentAlt: formData.thumbnailAlt,
                context: buildMediaRenameContext()
            });

            if (!result?.altText) {
                showToast('Kapak görseli için AI alt text üretilemedi.', 'error');
                return;
            }

            setFormData(prev => ({ ...prev, thumbnailAlt: result.altText }));
            showToast('Kapak görseli alt text AI ile üretildi.', 'success');
        } finally {
            setIsGeneratingThumbnailAlt(false);
        }
    }, [buildMediaRenameContext, formData.thumbnail, formData.thumbnailAlt, isGeneratingThumbnailAlt, selectedLanguage, showToast]);

    const handleAddVSItem = () => {
        const newItem: PostItem = {
            id: Math.random().toString(36).substr(2, 9),
            type: 'vs',
            title: '',
            description: '',
            orderNumber: 0,
            options: [
                { id: Math.random().toString(36).substr(2, 9), text: t('admin.post.vs.left_side'), votes: 0, image: '' },
                { id: Math.random().toString(36).substr(2, 9), text: t('admin.post.vs.right_side'), votes: 0, image: '' }
            ],
            isImagePoll: true,
            pollColumns: 2
        };

        const newItems = [...formData.items, newItem];
        let finalItems = newItems;
        if (activeSort) {
            finalItems = newItems.map((item: PostItem, idx: number) => ({
                ...item,
                orderNumber: activeSort === 'asc' ? (idx + 1) : (newItems.length - idx)
            }));
        } else {
            const nextOrder = formData.items.length > 0
                ? Math.max(...formData.items.map((i: PostItem) => i.orderNumber || 0)) + 1
                : 1;
            finalItems[finalItems.length - 1].orderNumber = nextOrder;
        }
        setFormData({ ...formData, items: finalItems });
    };

    const handleAddReviewItem = () => {
        const newItem: PostItem = {
            id: Math.random().toString(36).substr(2, 9),
            type: 'review',
            title: '',
            description: '',
            orderNumber: 0,
            reviewData: {
                productName: '',
                productImage: '',
                score: 85,
                pros: [t('admin.post.review.pros_placeholder')],
                cons: [t('admin.post.review.cons_placeholder')],
                breakdown: [
                    { label: t('admin.post.review.criteria.design'), score: 80 },
                    { label: t('admin.post.review.criteria.performance'), score: 80 }
                ],
                verdict: t('admin.post.review.verdict_placeholder')
            }
        };

        const newItems = [...formData.items, newItem];
        let finalItems = newItems;
        if (activeSort) {
            finalItems = newItems.map((item: PostItem, idx: number) => ({
                ...item,
                orderNumber: activeSort === 'asc' ? (idx + 1) : (newItems.length - idx)
            }));
        } else {
            const nextOrder = formData.items.length > 0
                ? Math.max(...formData.items.map((i: PostItem) => i.orderNumber || 0)) + 1
                : 1;
            finalItems[finalItems.length - 1].orderNumber = nextOrder;
        }
        setFormData({ ...formData, items: finalItems });
    };

    const handleAddQuoteItem = () => {
        const newItem: PostItem = {
            id: Math.random().toString(36).substr(2, 9),
            type: 'quote',
            title: '',
            description: '',
            orderNumber: 0
        };

        const newItems = [...formData.items, newItem];
        let finalItems = newItems;
        if (activeSort) {
            finalItems = newItems.map((item: PostItem, idx: number) => ({
                ...item,
                orderNumber: activeSort === 'asc' ? (idx + 1) : (newItems.length - idx)
            }));
        } else {
            const nextOrder = formData.items.length > 0
                ? Math.max(...formData.items.map((i: PostItem) => i.orderNumber || 0)) + 1
                : 1;
            finalItems[finalItems.length - 1].orderNumber = nextOrder;
        }
        setFormData({ ...formData, items: finalItems });
    };

    const handleAddIframeItem = () => {
        const newItem: PostItem = {
            id: Math.random().toString(36).substr(2, 9),
            type: 'iframe',
            title: '',
            description: '',
            orderNumber: 0
        };

        const newItems = [...formData.items, newItem];
        let finalItems = newItems;
        if (activeSort) {
            finalItems = newItems.map((item: PostItem, idx: number) => ({
                ...item,
                orderNumber: activeSort === 'asc' ? (idx + 1) : (newItems.length - idx)
            }));
        } else {
            const nextOrder = formData.items.length > 0
                ? Math.max(...formData.items.map((i: PostItem) => i.orderNumber || 0)) + 1
                : 1;
            finalItems[finalItems.length - 1].orderNumber = nextOrder;
        }
        setFormData({ ...formData, items: finalItems });
    };

    const handleRemoveItem = (id: string) => {
        if ((activeDetailTab === 'article' || activeDetailTab === 'poll' || activeDetailTab === 'video' || activeDetailTab === 'quiz' || activeDetailTab === 'TABLE OF CONTENTS' || activeDetailTab === 'recipe' || activeDetailTab === 'event') && formData.items.length <= 1) return;
        let filtered = formData.items.filter((item: PostItem) => item.id !== id);
        if (activeSort) {
            // Re-sequence remaining items
            filtered = filtered.map((item: PostItem, idx: number) => ({
                ...item,
                orderNumber: activeSort === 'asc' ? (idx + 1) : (filtered.length - idx)
            }));
        }
        setFormData({ ...formData, items: filtered });
    };

    const handleSortItems = (order: 'asc' | 'desc') => {
        // Re-sequence based on current visual positions in the array
        const resequenced = formData.items.map((item: PostItem, idx: number) => ({
            ...item,
            orderNumber: order === 'asc' ? (idx + 1) : (formData.items.length - idx)
        }));

        setFormData({ ...formData, items: resequenced });
        setShowBlockNumbers(true);
        setActiveSort(order);
    };

    const handleMoveItem = (index: number, direction: 'up' | 'down') => {
        const newItems = [...formData.items];
        const targetIndex = direction === 'up' ? index - 1 : index + 1;
        if (targetIndex < 0 || targetIndex >= newItems.length) return;
        const currentItem = { ...newItems[index] };
        const targetItem = { ...newItems[targetIndex] };

        // Swap positions in the array
        newItems[index] = targetItem;
        newItems[targetIndex] = currentItem;

        if (activeSort) {
            // Re-sequence based on new visual order
            newItems.forEach((item, idx) => {
                if (activeSort === 'asc') {
                    item.orderNumber = idx + 1;
                } else {
                    item.orderNumber = newItems.length - idx;
                }
            });
        }
        setFormData({ ...formData, items: newItems });
    };

    const normalizeSeoDescriptionInput = (value: string) =>
        String(value || '')
            .replace(/\s*\n+\s*/g, ' ')
            .trim()
            .slice(0, 160);

    const handleTitleChange = (val: string) => {
        const slug = val.toLowerCase()
            .replace(/ğ/g, 'g')
            .replace(/ü/g, 'u')
            .replace(/ş/g, 's')
            .replace(/ı/g, 'i')
            .replace(/ö/g, 'o')
            .replace(/ç/g, 'c')
            .replace(/[^a-z0-9\s-]/g, '')
            .replace(/\s+/g, '-')
            .replace(/-+/g, '-')
            .trim()
            .slice(0, 50);
        setValidationErrors(prev => ({ ...prev, title: undefined }));
        setFormData({
            ...formData,
            title: val,
            slug: slug,
            seoTitle: val.slice(0, 60),
            seoDescription: normalizeSeoDescriptionInput(formData.summary || val)
        });
    };

    const handleSummaryChange = (val: string) => {
        setValidationErrors(prev => ({ ...prev, summary: undefined }));
        setFormData({
            ...formData,
            summary: val,
            seoDescription: normalizeSeoDescriptionInput(val)
        });
    };

    const handleTogglePinned = async () => {
        const newPinnedValue = !formData.isPinned;

        if (newPinnedValue) {
            // Check current pinned count from database
            const { count, error: countError } = await neon
                .from('posts')
                .select('*', { count: 'exact', head: true })
                .eq('is_pinned', true)
                .neq('id', formData.id || 'new-post-id'); // Exclude current post if it's being edited

            if (countError) {
                showToast(t('admin.error.fetch_failed'), 'error');
                return;
            }

            if (count && count >= 2) {
                showToast(t('admin.post.max_pinned_error'), 'error');
                return;
            }
        }

        setFormData(prev => ({ ...prev, isPinned: newPinnedValue }));
    };

    const handleToggleManset = () => {
        setFormData(prev => ({ ...prev, showInManset: !prev.showInManset }));
    };

    const buildCardDataPatch = (items: PostItem[]) => {
        const safeItems = Array.isArray(items) ? items : [];
        const clean = (value: unknown) => String(value || '').trim();
        const normalizedTab = clean(activeDetailTab).toLowerCase();

        const normalizeHtml = (value: unknown) => {
            const html = clean(value);
            if (!html) return '';
            if (html === '<p><br></p>' || html === '<p></p>') return '';
            return html;
        };

        const pickFeaturedItem = (): PostItem | undefined => {
            const flagged = safeItems.find((i) => !!(i as any)?.showOnHomepage) as PostItem | undefined;
            if (flagged) return flagged;

            // For single-type posts, pick the first relevant block even if not flagged.
            if (normalizedTab === 'video') {
                return safeItems.find((i) => clean((i as any)?.type).toLowerCase() === 'video') as PostItem | undefined;
            }
            if (normalizedTab === 'poll') {
                return safeItems.find((i) => clean((i as any)?.type).toLowerCase() === 'poll') as PostItem | undefined;
            }
            if (normalizedTab === 'paragraph') {
                return safeItems.find((i) => clean((i as any)?.type).toLowerCase() === 'quote') as PostItem | undefined;
            }

            return undefined;
        };

        const featured = pickFeaturedItem();

        // Reset/clear all homepage-card overrides to avoid stale card state when the selection changes.
        const patch: Record<string, any> = {
            type: null,
            mediaUrl: null,
            mediaList: null,
            thumbnail: null,
            thumbnailAlt: null,
            flipData: null,
            beforeAfterData: null,
            reviewData: null,
            options: null,
            isImagePoll: null,
            pollColumns: null,
            totalVotes: null,
            blockTitle: null,
            blockDescription: null,
            paragraphData: null,
        };

        if (!featured) return patch;

        const featuredType = clean((featured as any)?.type).toLowerCase();
        const featuredMediaUrl = clean((featured as any)?.mediaUrl);
        const featuredTitle = clean((featured as any)?.title);
        const featuredDescription = normalizeHtml((featured as any)?.description);

        const cleanUrlArray = (value: unknown) =>
            Array.isArray(value) ? value.map((u) => clean(u)).filter(Boolean) : [];

        const voteSum = (options: any[]) => options.reduce((sum, opt) => sum + (Number(opt?.votes) || 0), 0);

        switch (featuredType) {
            case 'video': {
                if (!featuredMediaUrl) return patch;
                patch.type = 'video';
                patch.mediaUrl = featuredMediaUrl;
                return patch;
            }
            case 'audio': {
                if (!featuredMediaUrl) return patch;
                patch.type = 'audio';
                patch.mediaUrl = featuredMediaUrl;
                return patch;
            }
            case 'social':
            case 'iframe': {
                if (!featuredMediaUrl) return patch;
                patch.type = 'embed';
                patch.mediaUrl = featuredMediaUrl;
                return patch;
            }
            case 'slider': {
                const mediaUrls = cleanUrlArray((featured as any)?.mediaUrls);
                if (mediaUrls.length === 0) return patch;
                patch.type = 'gallery';
                patch.mediaList = mediaUrls;
                return patch;
            }
            case 'image': {
                if (!featuredMediaUrl) return patch;
                patch.type = 'image';
                patch.thumbnail = featuredMediaUrl;
                patch.thumbnailAlt = clean((featured as any)?.altText) || null;
                return patch;
            }
            case 'flipcard': {
                const flipData = (featured as any)?.flipData;
                if (!flipData) return patch;
                const frontImage = clean(flipData.frontImage);
                const backImage = clean(flipData.backImage);
                if (!frontImage || !backImage) return patch;
                patch.type = 'flip_card';
                patch.flipData = flipData;
                return patch;
            }
            case 'beforeafter': {
                const beforeAfterData = (featured as any)?.beforeAfterData;
                if (!beforeAfterData) return patch;
                const beforeImage = clean(beforeAfterData.beforeImage);
                const afterImage = clean(beforeAfterData.afterImage);
                if (!beforeImage || !afterImage) return patch;
                patch.type = 'before_after';
                patch.beforeAfterData = beforeAfterData;
                return patch;
            }
            case 'review': {
                const reviewData = (featured as any)?.reviewData;
                if (!reviewData) return patch;
                if (!clean(reviewData.productName)) return patch;
                patch.type = 'review';
                patch.reviewData = reviewData;
                return patch;
            }
            case 'poll': {
                const options = Array.isArray((featured as any)?.options) ? (featured as any).options : [];
                if (options.length === 0) return patch;
                patch.type = 'poll';
                patch.thumbnail = featuredMediaUrl || null;
                patch.options = options;
                patch.isImagePoll = (featured as any)?.isImagePoll ?? null;
                patch.pollColumns = (featured as any)?.pollColumns ?? null;
                patch.totalVotes = voteSum(options);
                patch.blockTitle = featuredTitle || null;
                patch.blockDescription = featuredDescription || null;
                return patch;
            }
            case 'vs': {
                const options = Array.isArray((featured as any)?.options) ? (featured as any).options : [];
                if (options.length < 2) return patch;
                patch.type = 'vs';
                patch.thumbnail = featuredMediaUrl || null;
                patch.options = options.slice(0, 2);
                patch.totalVotes = voteSum(options);
                patch.blockTitle = featuredTitle || null;
                patch.blockDescription = featuredDescription || null;
                return patch;
            }
            case 'quote': {
                if (!featuredDescription) return patch;
                patch.type = 'paragraph';
                patch.paragraphData = {
                    items: [featuredDescription],
                    quoteAuthor: featuredTitle || undefined,
                };
                return patch;
            }
            default:
                return patch;
        }
    };

    const handleSave = async (status: 'published' | 'draft') => {
        const titleForStorage = normalizeStoredPlainText(formData.title);
        const summaryForStorage = normalizeStoredPlainText(formData.summary);
        const categoryForStorage = normalizeStoredPlainText(formData.category);
        const faqDataForStorage = normalizeStoredPlainTextPayload(formData.faqData || []);
        const errors: { title?: string; summary?: string } = {};
        if (!titleForStorage) {
            errors.title = t('admin.post.title_required');
        }
        if (!summaryForStorage) {
            errors.summary = t('admin.post.summary_required');
        }

        if (Object.keys(errors).length > 0) {
            setValidationErrors(errors);
            if (errors.title) {
                titleRef.current?.scrollIntoView({ behavior: 'smooth', block: 'center' });
                titleRef.current?.focus();
            } else if (errors.summary) {
                summaryRef.current?.scrollIntoView({ behavior: 'smooth', block: 'center' });
                summaryRef.current?.focus();
            }
            return;
        }

        if (!categoryForStorage) {
            showToast(t('admin.post.category_required'), 'error');
            categoryRef.current?.focus();
            return;
        }

        try {
            const { data: { user } } = await neon.auth.getUser();
            if (!user) {
                showToast(t('auth.login_required'), 'error');
                return;
            }

            const slug = formData.slug || titleForStorage.toLowerCase()
                .replace(/ğ/g, 'g')
                .replace(/ü/g, 'u')
                .replace(/ş/g, 's')
                .replace(/ı/g, 'i')
                .replace(/ö/g, 'o')
                .replace(/ç/g, 'c')
                .replace(/[^a-z0-9\s-]/g, '')
                .replace(/\s+/g, '-')
                .replace(/-+/g, '-')
                .trim();

            const itemsForStorage = ensureUniqueItemIds(normalizeStoredPlainTextPayload([...formData.items]));
            const finalItems = [...itemsForStorage];
            if (faqDataForStorage && faqDataForStorage.length > 0) {
                finalItems.push({
                    id: 'faq-schema-block',
                    type: 'faq',
                    title: t('admin.post.faq_short'),
                    description: '',
                    faqData: faqDataForStorage
                } as any);
            }

            const cardDataBase = loadedCardDataRef.current || {};
            const cardDataPatch = buildCardDataPatch(finalItems);
            const mergedCardData = normalizeStoredPlainTextPayload({ ...cardDataBase, ...cardDataPatch });

            const normalizedPublishAt = toIsoString(formData.publishAt);
            const postData: any = {
                title: titleForStorage,
                summary: summaryForStorage,
                category: categoryForStorage,
                thumbnail_url: formData.thumbnail,
                thumbnail_alt: normalizeStoredPlainText(formData.thumbnailAlt),
                seo_title: normalizeStoredPlainText(formData.seoTitle),
                seo_description: normalizeStoredPlainText(formData.seoDescription),
                keywords: normalizeStoredPlainText(formData.keywords),
                slug: slug,
                fact_checked: formData.factChecked,
                schema_type: formData.schemaType,
                faq_data: faqDataForStorage,
                items: finalItems,
                card_data: mergedCardData,
                published_at: status === 'published' ? (normalizedPublishAt || new Date().toISOString()) : null,
                status: status,
                language_code: selectedLanguage,
                publisher_id: formData.publisher_id || user?.id,
                is_pinned: formData.isPinned,
                show_in_manset: formData.showInManset,
                type: activeDetailTab === 'TABLE OF CONTENTS' ? 'contents' : activeDetailTab,
                updated_at: new Date().toISOString(),
                ...(formData.id ? {} : { likes_count: 0, shares_count: 0, comments_count: 0 })
            };
            const savedFormData = {
                ...formData,
                title: titleForStorage,
                summary: summaryForStorage,
                category: categoryForStorage,
                thumbnailAlt: normalizeStoredPlainText(formData.thumbnailAlt),
                seoTitle: normalizeStoredPlainText(formData.seoTitle),
                seoDescription: normalizeStoredPlainText(formData.seoDescription),
                keywords: normalizeStoredPlainText(formData.keywords),
                slug,
                faqData: faqDataForStorage,
                items: itemsForStorage,
            };

            if (formData.id) {
                // Update
                const { error } = await neon
                    .from('posts')
                    .update(postData)
                    .eq('id', formData.id);
                if (error) throw error;
                loadedCardDataRef.current = mergedCardData;
                showToast(t('admin.post.update_success'), 'success');
                // Kaydedildiyse artık dirty değil
                setFormData(savedFormData);
                initialFormDataRef.current = JSON.parse(JSON.stringify(savedFormData));
                initialSelectedLanguageRef.current = selectedLanguage;
                initialDetailTabRef.current = activeDetailTab;
            } else {
                // Insert
                const { data, error } = await neon
                    .from('posts')
                    .insert([postData])
                    .select()
                    .single();
                if (error) throw error;
                if (data) {
                    loadedCardDataRef.current = mergedCardData;
                    showToast(t('admin.post.create_success'), 'success');
                    // Reset page if it was a new post
                    if (!postId) {
                        // Yeni ekleme ekranını sıfırlarken dirty snapshot'ını da sıfırla
                        setIsInitialized(false);
                        initialFormDataRef.current = null;
                        if (initDirtyTimerRef.current) {
                            window.clearTimeout(initDirtyTimerRef.current);
                            initDirtyTimerRef.current = null;
                        }
                        setFormData({
                            id: '',
                            title: '',
                            summary: '',
                            category: '',
                            thumbnail: '',
                            thumbnailAlt: '',
                            seoTitle: '',
                            seoDescription: '',
                            keywords: '',
                            slug: '',
                            factChecked: false,
                            schemaType: activeDetailTab === 'recipe' ? 'Recipe' : activeDetailTab === 'event' ? 'Event' : 'NewsArticle',
                            publishAt: '',
                            publisher_id: '',
                            isPinned: false,
                            showInManset: false,
                            faqData: [] as { q: string, a: string }[],
                            items: activeDetailTab === 'recipe' ? createRecipePostItems() : activeDetailTab === 'event' ? [createEventPostItem()] : [
                                activeDetailTab === 'paragraph' ? {
                                    id: Math.random().toString(36).substr(2, 9),
                                    type: 'quote',
                                    title: '',
                                    description: '',
                                    orderNumber: 1,
                                    showOnHomepage: true
                                } : {
                                    id: Math.random().toString(36).substr(2, 9),
                                    type: 'text',
                                    title: '',
                                    description: '',
                                    mediaUrl: '',
                                    createdAt: Date.now(),
                                    orderNumber: 1
                                }
                            ]
                        });
                        setSelectedParentId('');
                        setSelectedSubId('');
                        setSelectedSubId('');
                        setActiveDetailTab('article');
                        window.scrollTo({ top: 0, behavior: 'smooth' });
                    } else {
                        setFormData(prev => ({ ...prev, id: data.id }));
                    }
                }
            }
        } catch (error: any) {
            console.error('Save error:', error);
            showToast(t('common.error_prefix') + error.message, 'error');
        }
    };

    const renderTableOfContentsEditor = (item: PostItem, index: number, displayMode: 'all' | 'style' | 'items' = 'all') => (
        <PostTableOfContentsItem
            key={`${item.id}-${index}`}
            item={item}
            index={index}
            totalItems={formData.items.length}
            showBlockNumbers={showBlockNumbers}
            displayMode={displayMode}
            onUpdate={handleUpdateItem}
            onRemove={handleRemoveItem}
            isDeletable={(activeDetailTab !== 'article' && activeDetailTab !== 'poll' && activeDetailTab !== 'video' && activeDetailTab !== 'quiz' && activeDetailTab !== 'TABLE OF CONTENTS') || formData.items.length > 1}
            onMoveUp={(idx) => handleMoveItem(idx, 'up')}
            onMoveDown={(idx) => handleMoveItem(idx, 'down')}
            onOpenFileManager={(id, subField, optionId) => {
                setActiveMediaTarget(id);
                setActiveMediaSubTarget(subField || null);
                setActiveMediaOptionTarget(optionId || null);
                setActiveMediaType('image');
                fetchMedia('image');
                setShowFileManager(true);
            }}
            onOpenUrlMode={(id, subField, optionId) => {
                setActiveMediaTarget(id);
                setActiveMediaSubTarget(subField || null);
                setActiveMediaOptionTarget(optionId || null);
                setActiveMediaType('image');
                setTempUrl('');
                setUrlError(null);
                setIsUrlMode(true);
            }}
            onOpenImageEditor={(id, subField, optionId) => {
                setActiveMediaTarget(id);
                setActiveMediaSubTarget(subField || null);
                setActiveMediaOptionTarget(optionId || null);
                editorSaveInFlightRef.current = false;
                setIsEditorSaving(false);
                setShowImageEditor(true);
            }}
            onRenameMedia={(src, type) => handleRenameMediaWithAi(src, type, buildFocusedMediaKind(item, index, 'içindekiler görseli'))}
        />
    );

    const renderRecipeEditor = (item: PostItem, index: number, displayMode: 'all' | 'info' | 'details' = 'all') => (
        <PostRecipeItem
            key={`${item.id}-${index}`}
            item={item}
            index={index}
            totalItems={formData.items.length}
            showBlockNumbers={showBlockNumbers}
            displayMode={displayMode}
            onUpdate={handleUpdateItem}
            onRemove={handleRemoveItem}
            isDeletable={(activeDetailTab !== 'article' && activeDetailTab !== 'poll' && activeDetailTab !== 'video' && activeDetailTab !== 'quiz' && activeDetailTab !== 'TABLE OF CONTENTS' && activeDetailTab !== 'recipe') || formData.items.length > 1}
            onMoveUp={(idx) => handleMoveItem(idx, 'up')}
            onMoveDown={(idx) => handleMoveItem(idx, 'down')}
            onOpenFileManager={(id, subField, optionId) => {
                setActiveMediaTarget(id);
                setActiveMediaSubTarget(subField || null);
                setActiveMediaOptionTarget(optionId || null);
                setActiveMediaType('image');
                fetchMedia('image');
                setShowFileManager(true);
            }}
            onOpenUrlMode={(id, subField, optionId) => {
                setActiveMediaTarget(id);
                setActiveMediaSubTarget(subField || null);
                setActiveMediaOptionTarget(optionId || null);
                setActiveMediaType('image');
                setTempUrl('');
                setUrlError(null);
                setIsUrlMode(true);
            }}
            onOpenImageEditor={(id, subField, optionId) => {
                setActiveMediaTarget(id);
                setActiveMediaSubTarget(subField || null);
                setActiveMediaOptionTarget(optionId || null);
                editorSaveInFlightRef.current = false;
                setIsEditorSaving(false);
                setShowImageEditor(true);
            }}
            onRenameMedia={(src, type) => handleRenameMediaWithAi(src, type, buildFocusedMediaKind(item, index, 'tarif görseli'))}
        />
    );

    const renderEventEditor = (item: PostItem, index: number, displayMode: 'all' | 'settings' | 'sections' = 'all') => (
        <PostEventItem
            key={`${item.id}-${index}`}
            item={item}
            index={index}
            totalItems={formData.items.length}
            showBlockNumbers={showBlockNumbers}
            displayMode={displayMode}
            onUpdate={handleUpdateItem}
            onRemove={handleRemoveItem}
            isDeletable={(activeDetailTab !== 'article' && activeDetailTab !== 'poll' && activeDetailTab !== 'video' && activeDetailTab !== 'quiz' && activeDetailTab !== 'TABLE OF CONTENTS' && activeDetailTab !== 'recipe' && activeDetailTab !== 'event') || formData.items.length > 1}
            onMoveUp={(idx) => handleMoveItem(idx, 'up')}
            onMoveDown={(idx) => handleMoveItem(idx, 'down')}
            onOpenFileManager={(id, subField, optionId) => {
                setActiveMediaTarget(id);
                setActiveMediaSubTarget(subField || null);
                setActiveMediaOptionTarget(optionId || null);
                setActiveMediaType('image');
                fetchMedia('image');
                setShowFileManager(true);
            }}
            onOpenUrlMode={(id, subField, optionId) => {
                setActiveMediaTarget(id);
                setActiveMediaSubTarget(subField || null);
                setActiveMediaOptionTarget(optionId || null);
                setActiveMediaType('image');
                setTempUrl('');
                setUrlError(null);
                setIsUrlMode(true);
            }}
            onOpenImageEditor={(id, subField, optionId) => {
                setActiveMediaTarget(id);
                setActiveMediaSubTarget(subField || null);
                setActiveMediaOptionTarget(optionId || null);
                editorSaveInFlightRef.current = false;
                setIsEditorSaving(false);
                setShowImageEditor(true);
            }}
            onRenameMedia={(src, type) => handleRenameMediaWithAi(src, type, buildFocusedMediaKind(item, index, 'etkinlik görseli'))}
        />
    );

    const renderVideoEditor = (
        item: PostItem,
        index: number,
        options: { blockTitle?: string; titlePlaceholder?: string; mediaKindLabel?: string } = {}
    ) => (
        <PostVideoItem
            key={`${item.id}-${index}`}
            item={item}
            index={index}
            totalItems={formData.items.length}
            showBlockNumbers={showBlockNumbers}
            blockTitle={options.blockTitle}
            titlePlaceholder={options.titlePlaceholder}
            onUpdate={handleUpdateItem}
            onRemove={handleRemoveItem}
            isDeletable={(activeDetailTab !== 'article' && activeDetailTab !== 'poll' && activeDetailTab !== 'video' && activeDetailTab !== 'quiz' && activeDetailTab !== 'recipe') || formData.items.length > 1}
            onMoveUp={(idx) => handleMoveItem(idx, 'up')}
            onMoveDown={(idx) => handleMoveItem(idx, 'down')}
            onOpenFileManager={(id) => {
                setActiveMediaTarget(id);
                setActiveMediaType('video');
                fetchMedia('video');
                setShowFileManager(true);
            }}
            onOpenUrlMode={(id) => {
                setActiveMediaTarget(id);
                setActiveMediaType('video');
                setTempUrl('');
                setUrlError(null);
                setIsUrlMode(true);
            }}
            onRenameMedia={(src, type) => handleRenameMediaWithAi(src, type, buildFocusedMediaKind(item, index, options.mediaKindLabel || 'video bloğu'))}
        />
    );

    return (
        <div className="animate-in fade-in duration-500 admin-font relative">
            <style dangerouslySetInnerHTML={{ __html: QUILL_CUSTOM_STYLE }} />
            {isLoadingPost && (
                <div className="absolute inset-0 z-50 flex items-center justify-center bg-white/80 backdrop-blur-[2px]">
                    <div className="flex items-center gap-3 px-5 py-3 bg-white rounded-[3px] border border-palette-tan/20 shadow-lg">
                        <span className="material-symbols-rounded animate-spin text-palette-maroon" style={{ fontSize: '22px' }}>progress_activity</span>
                        <div className="flex flex-col">
                            <span className="text-[12px] font-black text-palette-maroon uppercase tracking-wider">{t('admin.post.loading_title')}</span>
                            <span className="text-[11px] font-bold text-palette-tan/60">{t('admin.post.loading_subtitle')}</span>
                        </div>
                    </div>
                </div>
            )}
            <div className={isLoadingPost ? 'pointer-events-none select-none opacity-70' : ''}>
                {/* MODERN COMPACT HEADER */}
                <div className="flex items-center justify-between mb-6 bg-white p-4 rounded-[3px] border border-palette-tan/20 shadow-sm">
                    <div className="flex items-center gap-4">
                        {onBack && (
                            <button
                                onClick={onBack}
                                className="w-10 h-10 flex items-center justify-center rounded-[3px] bg-palette-beige/50 text-palette-maroon border border-palette-tan/20 hover:bg-palette-tan/10 transition-all"
                            >
                                <span className="material-symbols-rounded">arrow_back</span>
                            </button>
                        )}
                        <div>
                            <h2 className="text-xl font-bold text-palette-maroon">
                                {postId ? t('admin.post.edit_title') : t('admin.post.new_title')}
                            </h2>
                            <p className="text-[13px] font-bold text-palette-tan/50 tracking-wider">{t('admin.post.panel_desc')}</p>
                        </div>
                    </div>
                </div>

                <div className="flex gap-6 items-start">
                    {/* MAIN CONTENT AREA */}
                    <div className="flex-1 space-y-6">
                        {/* JOINED TABS AND CONTENT SECTION */}
                        <div className="bg-white rounded-[3px] border border-palette-tan/20 shadow-sm overflow-hidden">
                            {/* PREMIUM TAB NAVIGATION - IMAGE STYLE */}
                            <div className="border-b border-palette-tan/15 bg-white">
                                <div className="flex h-24">
                                    {[
                                        { id: 'article', label: t('admin.post.tab.article'), icon: 'description' },
                                        { id: 'quiz', label: t('admin.post.tab.quiz'), icon: 'quiz' },
                                        { id: 'poll', label: t('admin.post.tab.poll'), icon: 'poll' },
                                        { id: 'video', label: t('admin.post.tab.video'), icon: 'smart_display' },
                                        { id: 'TABLE OF CONTENTS', label: t('admin.post.tab.contents'), icon: 'format_list_numbered' },
                                        { id: 'recipe', label: t('admin.post.tab.recipe'), icon: 'restaurant' },
                                        { id: 'event', label: t('admin.post.tab.event'), icon: 'event' }
                                    ].map((tab, idx, arr) => (
                                        <button
                                            key={tab.id}
                                            onClick={() => setActiveDetailTab(tab.id as any)}
                                            className={`
                                            flex-1 flex flex-col items-center justify-center gap-1 transition-all duration-300 relative group
                                            ${idx !== arr.length - 1 ? 'border-r border-palette-tan/10' : ''}
                                            ${activeDetailTab === tab.id
                                                    ? 'bg-palette-beige/20 text-palette-maroon'
                                                    : 'text-palette-tan/40 hover:bg-palette-beige/5 hover:text-palette-maroon'}
                                        `}
                                        >
                                            <span
                                                className={`material-symbols-rounded ${activeDetailTab === tab.id ? 'text-palette-maroon' : 'text-palette-tan/30 group-hover:text-palette-maroon'} transition-colors`}
                                                style={{ fontSize: '28px' }}
                                            >
                                                {tab.icon}
                                            </span>
                                            <span className={`text-[12px] uppercase font-black tracking-widest ${activeDetailTab === tab.id ? 'opacity-100' : 'opacity-60'}`}>
                                                {tab.label}
                                            </span>

                                            {/* ACTIVE TRIANGLE POINTER (Points into content area) */}
                                            {activeDetailTab === tab.id && (
                                                <div className="absolute top-full left-1/2 -translate-x-1/2 w-0 h-0 border-l-[8px] border-l-transparent border-r-[8px] border-r-transparent border-t-[8px] border-t-white z-20" />
                                            )}
                                            {activeDetailTab === tab.id && (
                                                <div className="absolute top-[calc(100%+0.5px)] left-1/2 -translate-x-1/2 w-0 h-0 border-l-[9px] border-l-transparent border-r-[9px] border-r-transparent border-t-[9px] border-t-palette-tan/20 z-10" />
                                            )}

                                            {activeDetailTab === tab.id && (
                                                <div className="absolute bottom-0 left-0 right-0 h-0.5 bg-palette-maroon" />
                                            )}
                                        </button>
                                    ))}
                                </div>
                            </div>

                            {/* BASIC & SEO INTEGRATED INFO */}
                            <div className="p-8 space-y-6">
                                <div className="flex items-center justify-between border-b border-palette-tan/15 pb-4">
                                    <div className="flex items-center gap-3">
                                        <span className="material-symbols-rounded text-palette-red" style={{ fontSize: '20px' }}>description</span>
                                        <h3 className="text-base font-bold text-palette-maroon uppercase tracking-widest">{t('admin.post.content_info')}</h3>
                                    </div>
                                    <div className="flex flex-wrap items-center justify-end gap-4 sm:gap-6">
                                        <div className="flex items-center gap-3">
                                            <span className="text-[13px] font-bold text-palette-tan">{t('admin.post.manset_slider')}</span>
                                            <button
                                                type="button"
                                                onClick={handleToggleManset}
                                                aria-pressed={formData.showInManset}
                                                className={`w-10 h-5 rounded-full relative transition-all shadow-inner ${formData.showInManset ? 'bg-palette-red' : 'bg-palette-tan/20'}`}
                                            >
                                                <div className={`absolute top-1 w-3 h-3 bg-white rounded-full transition-all shadow-sm ${formData.showInManset ? 'right-1' : 'left-1'}`} />
                                            </button>
                                        </div>

                                        <div className="flex items-center gap-3">
                                            <span className="text-[13px] font-bold text-palette-tan">{t('admin.post.pin_to_top')}</span>
                                            <button
                                                type="button"
                                                onClick={handleTogglePinned}
                                                aria-pressed={formData.isPinned}
                                                className={`w-10 h-5 rounded-full relative transition-all shadow-inner ${formData.isPinned ? 'bg-amber-500' : 'bg-palette-tan/20'}`}
                                            >
                                                <div className={`absolute top-1 w-3 h-3 bg-white rounded-full transition-all shadow-sm ${formData.isPinned ? 'right-1' : 'left-1'}`} />
                                            </button>
                                        </div>

                                        <button
                                            type="button"
                                            onClick={() => setShowAiDialog(true)}
                                            className="flex items-center gap-2 px-3 py-1.5 bg-palette-maroon/5 border border-palette-maroon/10 text-palette-maroon rounded-[4px] hover:bg-palette-maroon/10 hover:border-palette-maroon/20 transition-all active:scale-95 group shadow-sm"
                                        >
                                            <span className="material-symbols-rounded group-hover:rotate-12 transition-transform duration-300" style={{ fontSize: '18px' }}>auto_fix_high</span>
                                            <span className="text-[11px] font-black tracking-widest uppercase leading-none">{t('admin.ai_assistant.button')}</span>
                                        </button>
                                    </div>
                                </div>
	                                <AiAssistantDialog
	                                    isOpen={showAiDialog}
	                                    onClose={() => setShowAiDialog(false)}
	                                    contentType={activeDetailTab === 'quiz' ? 'quiz' : activeDetailTab === 'poll' ? 'poll' : activeDetailTab === 'video' ? 'video' : activeDetailTab === 'TABLE OF CONTENTS' ? 'toc' : activeDetailTab === 'recipe' ? 'recipe' : activeDetailTab === 'event' ? 'event' : 'article'}
	                                    onApply={(data) => {
	                                        const generatedQuizItem = activeDetailTab === 'quiz' && data.quiz
	                                            ? buildQuizItemFromAiQuiz(data.quiz)
	                                            : null;
	                                        const generatedPollItems = activeDetailTab === 'poll' && data.poll
	                                            ? buildPollItemsFromAiPoll(data.poll)
	                                            : [];
	                                        const generatedVideoItems = activeDetailTab === 'video' && data.video
	                                            ? buildVideoItemsFromAiVideo(data.video)
	                                            : [];
	                                        const generatedTocItem = activeDetailTab === 'TABLE OF CONTENTS' && data.toc
	                                            ? buildTocItemFromAiToc(data.toc)
	                                            : null;
	                                        const generatedRecipeItems = activeDetailTab === 'recipe' && data.recipe
	                                            ? buildRecipeItemsFromAiRecipe(data.recipe)
	                                            : [];
	                                        const generatedEventItem = activeDetailTab === 'event' && data.event
	                                            ? buildEventItemFromAiEvent(data.event)
	                                            : null;

                                        if (activeDetailTab === 'quiz' && !generatedQuizItem) {
                                            showToast('AI test içeriği forma dönüştürülemedi. Lütfen tekrar üretin.', 'error');
                                            return;
                                        }

	                                        if (activeDetailTab === 'poll' && generatedPollItems.length === 0) {
	                                            showToast('AI anket içeriği forma dönüştürülemedi. Lütfen tekrar üretin.', 'error');
	                                            return;
	                                        }

                                        if (activeDetailTab === 'video' && generatedVideoItems.length === 0) {
                                            showToast('AI video içeriği forma dönüştürülemedi. Lütfen tekrar üretin.', 'error');
                                            return;
                                        }

                                        if (activeDetailTab === 'TABLE OF CONTENTS' && !generatedTocItem) {
                                            showToast('AI içindekiler içeriği forma dönüştürülemedi. Lütfen tekrar üretin.', 'error');
                                            return;
                                        }

                                        if (activeDetailTab === 'recipe' && generatedRecipeItems.length === 0) {
                                            showToast('AI tarif içeriği forma dönüştürülemedi. Lütfen tekrar üretin.', 'error');
                                            return;
                                        }

                                        if (activeDetailTab === 'event' && !generatedEventItem) {
                                            showToast('AI etkinlik içeriği forma dönüştürülemedi. Lütfen tekrar üretin.', 'error');
                                            return;
                                        }

                                        const normalizeCategoryLabel = (value: unknown) =>
                                            stripMarkdownEmphasis(String(value || ''))
                                                .trim()
                                                .toLocaleLowerCase('tr-TR')
                                                .replace(/ğ/g, 'g')
                                                .replace(/ü/g, 'u')
                                                .replace(/ş/g, 's')
                                                .replace(/ı/g, 'i')
                                                .replace(/ö/g, 'o')
                                                .replace(/ç/g, 'c')
                                                .replace(/\s+/g, ' ');

                                        const eventCategoryCandidates = activeDetailTab === 'event'
                                            ? [
                                                data.event?.subCategory,
                                                'Tiyatro',
                                                'Kültür Sanat',
                                                data.event?.category,
                                                'Etkinlik',
                                                'Niğde',
                                            ]
                                                .map((label) => stripMarkdownEmphasis(String(label || '')).trim())
                                                .filter(Boolean)
                                            : [];

                                        const applyAiEventCategorySelection = () => {
                                            if (eventCategoryCandidates.length === 0) return '';
                                            const matchedCategory = eventCategoryCandidates
                                                .map((label) => {
                                                    const normalizedLabel = normalizeCategoryLabel(label);
                                                    return categories.find((category) =>
                                                        category.type !== 'header' &&
                                                        category.type !== 'trends' &&
                                                        normalizeCategoryLabel(category.label) === normalizedLabel
                                                    );
                                                })
                                                .find(Boolean) as NavigationItem | undefined;

                                            if (!matchedCategory) return eventCategoryCandidates[0] || '';

                                            const parentItem = categories.find((category) => category.id === matchedCategory.parent_id);
                                            const grandParentItem = parentItem ? categories.find((category) => category.id === parentItem.parent_id) : null;
                                            setSelectedSubId('');

                                            if (grandParentItem && grandParentItem.id !== 'root' && grandParentItem.type !== 'header') {
                                                setSelectedParentId(grandParentItem.id);
                                                setSelectedThirdId(parentItem!.id);
                                                setSelectedFourthId(matchedCategory.id);
                                            } else if (parentItem && parentItem.id !== 'root' && parentItem.type !== 'header') {
                                                setSelectedParentId(parentItem.id);
                                                setSelectedThirdId(matchedCategory.id);
                                                setSelectedFourthId('');
                                            } else {
                                                setSelectedParentId(matchedCategory.id);
                                                setSelectedThirdId('');
                                                setSelectedFourthId('');
                                            }

                                            return matchedCategory.label;
                                        };

                                        const aiEventCategoryLabel = applyAiEventCategorySelection();

                                        setFormData(prev => {
                                            const cleanedTitle = stripMarkdownEmphasis(data.title || '');
                                            const cleanedMetaTitle = stripMarkdownEmphasis(data.metaTitle || '');
                                            const cleanedMetaDesc = stripMarkdownEmphasis(data.metaDesc || '');
                                            const cleanedSlug = stripMarkdownEmphasis(data.slug || '');

                                            const summaryParts = parseSmartBrevitySummary(String(data.summary || ''));
                                            const cleanedSummary =
                                                summaryParts.spot ||
                                                summaryParts.yeniNeVar ||
                                                '';

                                            const existingItems = Array.isArray(prev.items) ? prev.items : [];
                                            const aiContentForItems = activeDetailTab === 'recipe'
                                                ? normalizeRecipeAiContentForItems(data.content)
                                                : String(data.content || '');
                                            let generatedItems = aiContentForItems ? buildItemsFromAiContent(aiContentForItems) : [];
                                            const shouldApplyRequestedMedia =
                                                activeDetailTab === 'article' ||
                                                activeDetailTab === 'video' ||
                                                activeDetailTab === 'recipe' ||
                                                activeDetailTab === 'event';
                                            const requestedMediaTitle = cleanedTitle || data.video?.title || data.recipe?.title || data.event?.scheduleTitle || data.event?.venueName;

                                            if (shouldApplyRequestedMedia && data.requestedMedia?.image && !generatedItems.some((item) => item.type === 'image')) {
                                                generatedItems.push(buildRequestedMediaItemFromAi('image', requestedMediaTitle, cleanedSummary || data.summary, aiContentForItems));
                                            }
                                            if (
                                                shouldApplyRequestedMedia &&
                                                data.requestedMedia?.video &&
                                                activeDetailTab !== 'video' &&
                                                activeDetailTab !== 'recipe' &&
                                                !generatedItems.some((item) => item.type === 'video')
                                            ) {
                                                generatedItems.push(buildRequestedMediaItemFromAi('video', requestedMediaTitle, cleanedSummary || data.summary, aiContentForItems));
                                            }
                                            if (shouldApplyRequestedMedia && data.requestedMedia?.audio && !generatedItems.some((item) => item.type === 'audio')) {
                                                generatedItems.push(buildRequestedMediaItemFromAi('audio', requestedMediaTitle, cleanedSummary || data.summary, aiContentForItems));
                                            }

                                            // If Smart Brevity bullets were produced in SUMMARY, move them into the body (first text block)
                                            // so SUMMARY stays clean and professional.
                                            const contentAlreadyHasLead = /(yeni\s*ne\s*var|neden\s*önemli)/i.test(String(data.content || ''));
                                            const leadLis: string[] = [];
                                            if (!contentAlreadyHasLead) {
                                                if (summaryParts.yeniNeVar) {
                                                    leadLis.push(`<li><strong>Yeni ne var?</strong> ${markdownInlineToSafeHtml(summaryParts.yeniNeVar)}</li>`);
                                                }
                                                if (summaryParts.nedenOnemli) {
                                                    leadLis.push(`<li><strong>Neden önemli?</strong> ${markdownInlineToSafeHtml(summaryParts.nedenOnemli)}</li>`);
                                                }
                                            }
                                            const leadHtml = leadLis.length > 0 ? `<ul>${leadLis.join('')}</ul>` : '';

                                            if (generatedItems.length > 0 && leadHtml) {
                                                const firstTextIdx = generatedItems.findIndex((i) => (i.type || 'text') === 'text');
                                                if (firstTextIdx !== -1) {
                                                    const existingDesc = normalizeQuillEmpty(generatedItems[firstTextIdx].description);
                                                    generatedItems[firstTextIdx] = {
                                                        ...generatedItems[firstTextIdx],
                                                        description: `${leadHtml}${existingDesc ? existingDesc : ''}`,
                                                    };
                                                } else {
                                                    generatedItems.unshift({
                                                        id: `text-${Math.random().toString(36).slice(2, 10)}`,
                                                        type: 'text',
                                                        title: '',
                                                        description: leadHtml,
                                                        mediaUrl: '',
                                                        createdAt: Date.now(),
                                                        orderNumber: 1,
                                                    });
                                                }
                                            }

                                            if (activeDetailTab === 'event' && generatedItems.length > 0) {
                                                generatedItems = withReadableEventTextItems(generatedItems);
                                            }
                                            if (activeDetailTab === 'recipe' && generatedItems.length > 0) {
                                                generatedItems = withReadableEventTextItems(
                                                    generatedItems,
                                                    ['Tarifin Hikayesi', 'Yöresel Lezzetin Sırrı', 'Servis Önerisi'],
                                                    'Tarif Bilgileri',
                                                );
                                            }

                                            const isMeaningfulItem = (item: PostItem) => {
                                                const type = String(item?.type || 'text');
                                                if (type !== 'text') return true;
                                                if (stripMarkdownEmphasis(String(item?.title || '')).trim()) return true;
                                                if (normalizeQuillEmpty(item?.description)) return true;
                                                return false;
                                            };

                                            const shouldReplaceItems = existingItems.length === 0 || !existingItems.some(isMeaningfulItem);

                                            let nextItems = existingItems;
                                            if (generatedItems.length > 0 && activeDetailTab === 'article') {
                                                nextItems = shouldReplaceItems ? generatedItems : [...existingItems, ...generatedItems];
                                            }
                                            if (generatedQuizItem && activeDetailTab === 'quiz') {
                                                nextItems = [{
                                                    ...generatedQuizItem,
                                                    title: generatedQuizItem.title || cleanedTitle,
                                                    description: normalizeQuillEmpty(generatedQuizItem.description) || normalizeAiHtml(cleanedSummary || data.summary),
                                                }];
                                            }
	                                            if (generatedPollItems.length > 0 && activeDetailTab === 'poll') {
	                                                nextItems = generatedPollItems.map((item, idx) => ({
	                                                    ...item,
	                                                    title: item.title || (idx === 0 ? cleanedTitle : item.title),
	                                                    orderNumber: idx + 1,
	                                                }));
	                                            }
	                                            if (generatedVideoItems.length > 0 && activeDetailTab === 'video') {
	                                                const videoItems = generatedVideoItems.map((item, idx) => ({
	                                                    ...item,
	                                                    title: item.title || cleanedTitle,
	                                                    description: normalizeQuillEmpty(item.description) || normalizeAiHtml(cleanedSummary || data.summary),
                                                        showOnHomepage: idx === 0 ? true : item.showOnHomepage,
	                                                }));
	                                                nextItems = generatedItems.length > 0
	                                                    ? [...videoItems, ...generatedItems]
	                                                    : videoItems;
	                                            }
	                                            if (generatedTocItem && activeDetailTab === 'TABLE OF CONTENTS') {
	                                                nextItems = [{
	                                                    ...generatedTocItem,
	                                                    title: generatedTocItem.title || 'İçindekiler',
	                                                }];
	                                            }
	                                            if (generatedRecipeItems.length > 0 && activeDetailTab === 'recipe') {
                                                    const hasGeneratedVideoItem = generatedItems.some((item) => item.type === 'video');
                                                    const recipeItems = hasGeneratedVideoItem
                                                        ? generatedRecipeItems.filter((item) =>
                                                            item.type !== 'video' ||
                                                            stripMarkdownEmphasis(String(item.title || '')).trim() ||
                                                            normalizeQuillEmpty(item.description) ||
                                                            String(item.mediaUrl || '').trim()
                                                        )
                                                        : generatedRecipeItems;
	                                                nextItems = generatedItems.length > 0
	                                                    ? [...generatedItems, ...recipeItems]
	                                                    : recipeItems;
	                                            }
	                                            if (generatedEventItem && activeDetailTab === 'event') {
	                                                nextItems = generatedItems.length > 0
	                                                    ? [...generatedItems, generatedEventItem]
	                                                    : [generatedEventItem];
	                                            }

                                            // Renumber order to keep block numbering stable.
                                            const renumberedItems = nextItems.map((item, idx) => ({
                                                ...item,
                                                orderNumber: idx + 1,
                                            }));

                                            // Validate schemaType against SCHEMA_TYPE_OPTIONS
                                            const finalSchema = activeDetailTab === 'recipe'
                                                ? 'Recipe'
                                                : activeDetailTab === 'event'
                                                    ? 'Event'
                                                    : SCHEMA_TYPE_OPTIONS.includes(data.schemaType as any)
                                                        ? data.schemaType as any
                                                        : 'NewsArticle';

                                            return {
                                                ...prev,
                                                title: cleanedTitle || prev.title,
                                                summary: cleanedSummary || prev.summary,
                                                category: aiEventCategoryLabel || prev.category,
                                                thumbnailAlt: activeDetailTab === 'recipe' && data.recipe?.imageAlt
                                                    ? stripMarkdownEmphasis(String(data.recipe.imageAlt || ''))
                                                    : prev.thumbnailAlt,
                                                seoTitle: cleanedMetaTitle || prev.seoTitle,
                                                seoDescription: cleanedMetaDesc || prev.seoDescription,
                                                keywords: data.keywords && data.keywords.length > 0 ? data.keywords.join(', ') : prev.keywords,
                                                slug: cleanedSlug || prev.slug,
                                                schemaType: finalSchema,
                                                faqData: data.faqs && data.faqs.length > 0 ? data.faqs : prev.faqData,
                                                items: renumberedItems
                                            };
                                        });
                                    }}
                                />

                                <div className="grid grid-cols-1 gap-5">
                                    <div className="space-y-1.5">
                                        <label className="text-[13px] font-bold text-palette-tan ml-1">{t('admin.post.post_title')}</label>
                                        <input
                                            ref={titleRef}
                                            type="text"
                                            value={formData.title}
                                            onChange={(e) => handleTitleChange(e.target.value)}
                                            placeholder={t('admin.post.post_title_placeholder')}
                                            className={`w-full bg-palette-beige/5 border ${validationErrors.title ? 'border-palette-red/50 bg-palette-red/5' : 'border-palette-tan/20'} rounded-[3px] p-3.5 text-[18px] font-bold text-palette-maroon focus:border-palette-red outline-none transition-all`}
                                        />
                                        {validationErrors.title && (
                                            <p className="text-[11px] font-black text-palette-red ml-1 animate-in slide-in-from-top-1 duration-200">
                                                {validationErrors.title}
                                            </p>
                                        )}
                                    </div>

                                    <div className="space-y-1.5">
                                        <label className="text-[13px] font-bold text-palette-tan ml-1">{t('admin.post.summary')}</label>
                                        <textarea
                                            ref={summaryRef}
                                            rows={2}
                                            value={formData.summary}
                                            onChange={(e) => handleSummaryChange(e.target.value)}
                                            placeholder={t('admin.post.summary_placeholder')}
                                            className={`w-full bg-palette-beige/5 border ${validationErrors.summary ? 'border-palette-red/50 bg-palette-red/5' : 'border-palette-tan/20'} rounded-[3px] p-3.5 text-base font-medium text-palette-maroon focus:border-palette-red outline-none transition-all resize-none`}
                                        />
                                        {validationErrors.summary && (
                                            <p className="text-[11px] font-black text-palette-red ml-1 animate-in slide-in-from-top-1 duration-200">
                                                {validationErrors.summary}
                                            </p>
                                        )}
                                    </div>
                                </div>

                                {/* AUTOMATED SEO SECTION */}
                                <div className="mt-8 pt-8 border-t border-palette-tan/15 space-y-5">
                                    <div className="flex items-center justify-between">
                                        <div className="flex items-center gap-3">
                                            <span className="material-symbols-rounded text-palette-tan" style={{ fontSize: '20px' }}>settings</span>
                                            <h3 className="text-[13px] font-bold text-palette-tan uppercase tracking-tighter">{t('admin.post.seo_ai')}</h3>
                                        </div>
                                        <span className="text-[11px] font-black text-green-600 bg-green-50 px-2 py-1 rounded-[3px] border border-green-100 italic">{t('admin.post.google_ai_ready')}</span>
                                    </div>

                                    <div className="grid grid-cols-2 gap-4">
                                        <div className="space-y-1.5">
                                            <label className="text-[12px] font-bold text-palette-tan/60">{t('posts.form.meta_title')}</label>
                                            <input
                                                type="text"
                                                value={formData.seoTitle}
                                                onChange={(e) => setFormData({ ...formData, seoTitle: e.target.value })}
                                                placeholder={t('posts.form.meta_title_placeholder')}
                                                className="w-full bg-palette-beige/5 border border-palette-tan/20 rounded-[3px] p-2 text-sm font-bold text-palette-maroon outline-none"
                                            />
                                        </div>
                                        <div className="space-y-1.5">
                                            <label className="text-[12px] font-bold text-palette-tan/60">{t('posts.form.slug')}</label>
                                            <input
                                                type="text"
                                                value={formData.slug}
                                                onChange={(e) => setFormData({ ...formData, slug: e.target.value })}
                                                placeholder={t('posts.form.slug_placeholder')}
                                                className="w-full bg-palette-beige/5 border border-palette-tan/20 rounded-[3px] p-2 text-sm font-bold text-palette-red outline-none"
                                            />
                                        </div>
                                    </div>
                                    <div className="space-y-1.5">
                                        <label className="text-[12px] font-bold text-palette-tan/60">{t('posts.form.meta_desc')}</label>
                                        <input
                                            type="text"
                                            value={formData.seoDescription}
                                            onChange={(e) => setFormData({ ...formData, seoDescription: e.target.value })}
                                            placeholder={t('posts.form.meta_desc_placeholder')}
                                            className="w-full bg-palette-beige/5 border border-palette-tan/20 rounded-[3px] p-2 text-sm font-medium text-palette-tan outline-none"
                                        />
                                    </div>
                                    <div className="space-y-1.5">
                                        <label className="text-[12px] font-bold text-palette-tan/60">{t('posts.form.schema_type')}</label>
                                        <select
                                            value={formData.schemaType}
                                            onChange={(e) => setFormData({ ...formData, schemaType: e.target.value })}
                                            className="w-full bg-palette-beige/5 border border-palette-tan/20 rounded-[3px] p-2 text-sm font-bold text-palette-maroon outline-none cursor-pointer"
                                        >
                                            {SCHEMA_TYPE_OPTIONS.map((schemaType) => (
                                                <option key={schemaType} value={schemaType}>{schemaType}</option>
                                            ))}
                                        </select>
                                    </div>
                                    <div className="space-y-1.5">
                                        <label className="text-[12px] font-bold text-palette-tan/60">{t('posts.form.keywords')}</label>
                                        <div className="flex flex-wrap gap-2 p-2 bg-palette-beige/5 border border-palette-tan/20 rounded-[3px] min-h-[38px] transition-all focus-within:border-palette-red/40">
                                            {formData.keywords.split(',').filter(t => t.trim() !== '').map((tag, idx) => (
                                                <span key={idx} className="flex items-center gap-1.5 px-2 py-0.5 bg-palette-maroon text-white text-[11px] font-bold rounded-[3px] animate-in zoom-in duration-200">
                                                    {tag.trim()}
                                                    <button
                                                        type="button"
                                                        onClick={() => {
                                                            const newTags = formData.keywords.split(',').filter((_, i) => i !== idx);
                                                            setFormData({ ...formData, keywords: newTags.join(',') });
                                                        }}
                                                        className="hover:text-palette-beige transition-colors flex items-center"
                                                    >
                                                        <span className="material-symbols-rounded" style={{ fontSize: '12px' }}>close</span>
                                                    </button>
                                                </span>
                                            ))}
                                            <input
                                                type="text"
                                                value={tagInput}
                                                onChange={(e) => setTagInput(e.target.value)}
                                                onKeyDown={(e) => {
                                                    if (e.key === 'Enter' || e.key === ',') {
                                                        e.preventDefault();
                                                        const val = tagInput.trim().replace(',', '');
                                                        if (val) {
                                                            const currentTags = formData.keywords ? formData.keywords.split(',').map(t => t.trim()) : [];
                                                            if (!currentTags.includes(val)) {
                                                                setFormData({ ...formData, keywords: [...currentTags, val].filter(t => t).join(',') });
                                                            }
                                                            setTagInput('');
                                                        }
                                                    } else if (e.key === 'Backspace' && !tagInput && formData.keywords) {
                                                        const currentTags = formData.keywords.split(',');
                                                        currentTags.pop();
                                                        setFormData({ ...formData, keywords: currentTags.join(',') });
                                                    }
                                                }}
                                                placeholder={formData.keywords ? "" : t('admin.post.enter_to_add')}
                                                className="flex-1 bg-transparent border-none outline-none text-sm font-medium text-palette-tan min-w-[120px]"
                                            />
                                        </div>
                                    </div>
                                </div>
                                <div className="space-y-3 pt-4 border-t border-palette-tan/10">
                                    <div className="flex items-center justify-between">
                                        <label className="text-[12px] font-bold text-palette-tan/60 flex items-center gap-2">
                                            <span className="material-symbols-rounded" style={{ fontSize: '18px' }}>quiz</span> {t('admin.post.faq_title')}
                                        </label>
                                        <button
                                            type="button"
                                            onClick={() => setFormData({ ...formData, faqData: [...formData.faqData, { q: '', a: '' }] })}
                                            className="text-[11px] font-black text-palette-maroon hover:bg-palette-maroon/5 px-2 py-1 rounded transition-colors flex items-center gap-1"
                                        >
                                            <span className="material-symbols-rounded" style={{ fontSize: '16px' }}>add</span> {t('admin.post.faq_add_btn')}
                                        </button>
                                    </div>
	                                    <div className="space-y-4">
	                                        {formData.faqData.map((faq, idx) => (
                                            <div key={idx} className="p-3 bg-palette-beige/5 border border-palette-tan/10 rounded-[3px] space-y-3 relative group/faq">
                                                <button
                                                    type="button"
                                                    onClick={() => setFormData({ ...formData, faqData: formData.faqData.filter((_, i) => i !== idx) })}
                                                    className="absolute -top-2 -right-2 w-6 h-6 bg-white border border-palette-tan/20 text-palette-tan/40 hover:text-palette-red hover:border-palette-red rounded-full flex items-center justify-center shadow-sm opacity-0 group-hover/faq:opacity-100 transition-all z-10"
                                                >
                                                    <span className="material-symbols-rounded" style={{ fontSize: '14px' }}>close</span>
                                                </button>
                                                <div className="space-y-1">
                                                    <div className="flex items-center gap-2 mb-1">
                                                        <span className="text-[10px] font-black text-palette-tan/40 uppercase">#{idx + 1} {t('admin.post.faq_question')}</span>
                                                    </div>
                                                    <input
                                                        type="text"
                                                        value={faq.q}
                                                        onChange={(e) => {
                                                            const newFaq = [...formData.faqData];
                                                            newFaq[idx].q = e.target.value;
                                                            setFormData({ ...formData, faqData: newFaq });
                                                        }}
                                                        placeholder={t('admin.post.faq_question') + "..."}
                                                        className="w-full bg-white border border-palette-tan/20 rounded-[3px] px-3 py-1.5 text-sm font-bold text-palette-maroon outline-none"
                                                    />
                                                </div>
                                                <div className="space-y-1">
                                                    <div className="flex items-center gap-2 mb-1">
                                                        <span className="text-[10px] font-black text-palette-tan/40 uppercase">{t('admin.post.faq_answer')}</span>
                                                    </div>
                                                    <textarea
                                                        value={faq.a}
                                                        onChange={(e) => {
                                                            const newFaq = [...formData.faqData];
                                                            newFaq[idx].a = e.target.value;
                                                            setFormData({ ...formData, faqData: newFaq });
                                                        }}
                                                        rows={2}
                                                        placeholder={t('admin.post.faq_answer') + "..."}
                                                        className="w-full bg-white border border-palette-tan/20 rounded-[3px] px-3 py-1.5 text-sm font-medium text-palette-tan focus:border-palette-red outline-none transition-all resize-none"
                                                    />
                                                </div>
	                                            </div>
	                                        ))}
	                                    </div>
	                                        {activeDetailTab === 'TABLE OF CONTENTS' && (
	                                            <div className="mt-5 pt-5 border-t border-palette-tan/10">
	                                                {formData.items.map((item, index) => (
	                                                    item.type === 'toc' ? (
	                                                        <div key={`${item.id}-${index}-inline-toc`}>
	                                                            {renderTableOfContentsEditor(item, index, 'style')}
	                                                        </div>
	                                                    ) : null
	                                                ))}
	                                            </div>
	                                        )}
                                        {activeDetailTab === 'recipe' && (
                                            <div className="mt-5 pt-5 border-t border-palette-tan/10">
                                                {formData.items.map((item, index) => (
	                                                    item.type === 'recipe' ? (
	                                                        <div key={`${item.id}-${index}-inline-recipe`}>
	                                                            {renderRecipeEditor(item, index, 'info')}
	                                                        </div>
	                                                    ) : null
	                                                ))}
	                                            </div>
	                                        )}
                                        {activeDetailTab === 'event' && (
                                            <div className="mt-5 pt-5 border-t border-palette-tan/10">
                                                {formData.items.map((item, index) => (
                                                    item.type === 'event' ? (
                                                        <div key={`${item.id}-${index}-inline-event`}>
                                                            {renderEventEditor(item, index, 'settings')}
                                                        </div>
                                                    ) : null
                                                ))}
                                            </div>
                                        )}
	                                </div>
                            </div>
                        </div>
                        {activeDetailTab === 'TABLE OF CONTENTS' && (
                            <div className="mt-6">
                                {formData.items.map((item, index) => (
                                    item.type === 'toc' ? (
                                        <div key={`${item.id}-${index}-outside-toc`}>
                                            {renderTableOfContentsEditor(item, index, 'items')}
                                        </div>
                                    ) : null
	                                ))}
	                            </div>
	                        )}
                        {activeDetailTab === 'recipe' && (
                            <div className="mt-6 space-y-6">
                                {formData.items.map((item, index) => (
                                    item.type === 'video' ? (
                                        <div key={`${item.id}-${index}-outside-recipe-video`}>
                                            {renderVideoEditor(item, index, {
                                                blockTitle: t('admin.post.recipe.food_video'),
                                                titlePlaceholder: t('admin.post.recipe.food_video_title_placeholder'),
                                                mediaKindLabel: 'yemek videosu',
                                            })}
                                        </div>
                                    ) : null
                                ))}
                                {formData.items.map((item, index) => (
                                    item.type === 'recipe' ? (
                                        <div key={`${item.id}-${index}-outside-recipe`}>
                                            {renderRecipeEditor(item, index, 'details')}
                                        </div>
                                    ) : null
                                ))}
                            </div>
                        )}
                        {activeDetailTab === 'event' && (
                            <div className="mt-6 space-y-6">
                                {formData.items.map((item, index) => (
                                    item.type === 'event' ? (
                                        <div key={`${item.id}-${index}-outside-event`}>
                                            {renderEventEditor(item, index, 'sections')}
                                        </div>
                                    ) : null
                                ))}
                            </div>
                        )}
                        {/* ITEM LIST CONTROLS */}
                        {activeDetailTab !== 'quiz' && activeDetailTab !== 'TABLE OF CONTENTS' && activeDetailTab !== 'recipe' && activeDetailTab !== 'event' && (
                            <div className="flex justify-center items-center py-4">
                                <div className="inline-flex bg-white border border-palette-tan/20 rounded-[3px] p-1.5 shadow-sm gap-1">
                                    <button
                                        onClick={() => handleSortItems('asc')}
                                        className={`flex items-center justify-center gap-2 px-4 py-2 rounded-[3px] text-[12px] font-black transition-all active:scale-95 leading-none group ${activeSort === 'asc'
                                            ? 'bg-palette-maroon text-white shadow-md shadow-palette-maroon/20 scale-[1.02]'
                                            : 'text-palette-tan hover:text-palette-maroon hover:bg-palette-beige/30'
                                            }`}
                                    >
                                        <span className="material-symbols-rounded" style={{ fontSize: '18px' }}>sort</span>
                                        <span className="leading-none">{t('admin.post.sort.asc')}</span>
                                    </button>
                                    <button
                                        onClick={() => handleSortItems('desc')}
                                        className={`flex items-center justify-center gap-2 px-4 py-2 rounded-[3px] text-[12px] font-black transition-all active:scale-95 leading-none group ${activeSort === 'desc'
                                            ? 'bg-palette-maroon text-white shadow-md shadow-palette-maroon/20 scale-[1.02]'
                                            : 'text-palette-tan hover:text-palette-maroon hover:bg-palette-beige/30'
                                            }`}
                                    >
                                        <span className="material-symbols-rounded" style={{ fontSize: '18px' }}>sort</span>
                                        <span className="leading-none">{t('admin.post.sort.desc')}</span>
                                    </button>
                                    <button
                                        onClick={() => { setActiveSort(null); setShowBlockNumbers(false); }}
                                        className={`flex items-center justify-center gap-2 px-4 py-2 rounded-[3px] text-[12px] font-black transition-all active:scale-95 leading-none group ${activeSort === null
                                            ? 'bg-palette-maroon text-white shadow-md shadow-palette-maroon/20 scale-[1.02]'
                                            : 'text-palette-tan hover:text-palette-maroon hover:bg-palette-beige/30'
                                            }`}
                                    >
                                        <span className="material-symbols-rounded" style={{ fontSize: '18px' }}>numbers</span>
                                        <span className="leading-none">{t('admin.post.sort.hide')}</span>
                                    </button>
                                </div>
                            </div>
                        )}

                        <div className="space-y-6">
                            {formData.items.map((item, index) => {
                                const itemKey = `${item.id}-${index}`;
                                return item.type === 'slider' ? (
                                    <PostSliderImageItem
                                        key={itemKey}
                                        item={item}
                                        index={index}
                                        totalItems={formData.items.length}
                                        showBlockNumbers={showBlockNumbers}
                                        onUpdate={handleUpdateItem}
                                        onRemove={handleRemoveItem}
                                        isDeletable={(activeDetailTab !== 'article' && activeDetailTab !== 'poll' && activeDetailTab !== 'video' && activeDetailTab !== 'quiz') || formData.items.length > 1}
                                        onMoveUp={(idx) => handleMoveItem(idx, 'up')}
                                        onMoveDown={(idx) => handleMoveItem(idx, 'down')}
                                        onOpenFileManager={(id) => {
                                            setActiveMediaTarget(id);
                                            setActiveMediaType('image');
                                            fetchMedia('image');
                                            setShowFileManager(true);
                                        }}
                                        onRenameMedia={(src, type) => handleRenameMediaWithAi(src, type, buildFocusedMediaKind(item, index, 'slider görseli'))}
                                    />
                                ) : item.type === 'image' ? (
                                    <PostImageItem
                                        key={itemKey}
                                        item={item}
                                        index={index}
                                        totalItems={formData.items.length}
                                        showBlockNumbers={showBlockNumbers}
                                        onUpdate={handleUpdateItem}
                                        onRemove={handleRemoveItem}
                                        isDeletable={(activeDetailTab !== 'article' && activeDetailTab !== 'poll' && activeDetailTab !== 'video' && activeDetailTab !== 'quiz') || formData.items.length > 1}
                                        onMoveUp={(idx) => handleMoveItem(idx, 'up')}
                                        onMoveDown={(idx) => handleMoveItem(idx, 'down')}
                                        onOpenFileManager={(id) => {
                                            setActiveMediaTarget(id);
                                            setActiveMediaType('image');
                                            fetchMedia('image');
                                            setShowFileManager(true);
                                        }}
                                        onOpenUrlMode={(id) => { setActiveMediaTarget(id); setActiveMediaType('image'); setTempUrl(''); setUrlError(null); setIsUrlMode(true); }}
                                        onOpenImageEditor={(id) => {
                                            setActiveMediaTarget(id);
                                            editorSaveInFlightRef.current = false;
                                            setIsEditorSaving(false);
                                            setShowImageEditor(true);
                                        }}
                                        onRenameMedia={(src, type) => handleRenameMediaWithAi(src, type, buildFocusedMediaKind(item, index, 'görsel bloğu'))}
                                    />
                                ) : item.type === 'video' ? (
                                    activeDetailTab === 'recipe' ? null : renderVideoEditor(item, index)
                                ) : item.type === 'audio' ? (
                                    <PostAudioItem
                                        key={itemKey}
                                        item={item}
                                        index={index}
                                        totalItems={formData.items.length}
                                        showBlockNumbers={showBlockNumbers}
                                        onUpdate={handleUpdateItem}
                                        onRemove={handleRemoveItem}
                                        isDeletable={(activeDetailTab !== 'article' && activeDetailTab !== 'poll' && activeDetailTab !== 'video' && activeDetailTab !== 'quiz') || formData.items.length > 1}
                                        onMoveUp={(idx) => handleMoveItem(idx, 'up')}
                                        onMoveDown={(idx) => handleMoveItem(idx, 'down')}
                                        onOpenFileManager={(id) => {
                                            setActiveMediaTarget(id);
                                            setActiveMediaType('audio');
                                            fetchMedia('audio');
                                            setShowFileManager(true);
                                        }}
                                        onOpenUrlMode={(id) => { setActiveMediaTarget(id); setActiveMediaType('audio'); setTempUrl(''); setUrlError(null); setIsUrlMode(true); }}
                                    />
                                ) : item.type === 'file' ? (
                                    <PostFileItem
                                        key={itemKey}
                                        item={item}
                                        index={index}
                                        totalItems={formData.items.length}
                                        showBlockNumbers={showBlockNumbers}
                                        onUpdate={handleUpdateItem}
                                        onRemove={handleRemoveItem}
                                        isDeletable={(activeDetailTab !== 'article' && activeDetailTab !== 'poll' && activeDetailTab !== 'video' && activeDetailTab !== 'quiz') || formData.items.length > 1}
                                        onMoveUp={(idx) => handleMoveItem(idx, 'up')}
                                        onMoveDown={(idx) => handleMoveItem(idx, 'down')}
                                        onOpenFileManager={(id) => {
                                            setActiveMediaTarget(id);
                                            setActiveMediaType('file');
                                            fetchMedia('file');
                                            setShowFileManager(true);
                                        }}
                                    />
                                ) : item.type === 'social' ? (
                                    <PostSocialItem
                                        key={itemKey}
                                        item={item}
                                        index={index}
                                        totalItems={formData.items.length}
                                        showBlockNumbers={showBlockNumbers}
                                        onUpdate={handleUpdateItem}
                                        onRemove={handleRemoveItem}
                                        isDeletable={(activeDetailTab !== 'article' && activeDetailTab !== 'poll' && activeDetailTab !== 'video' && activeDetailTab !== 'quiz') || formData.items.length > 1}
                                        onMoveUp={(idx) => handleMoveItem(idx, 'up')}
                                        onMoveDown={(idx) => handleMoveItem(idx, 'down')}
                                    />
                                ) : item.type === 'flipcard' ? (
                                    <PostFlipCardItem
                                        key={itemKey}
                                        item={item}
                                        index={index}
                                        totalItems={formData.items.length}
                                        showBlockNumbers={showBlockNumbers}
                                        onUpdate={handleUpdateItem}
                                        onRemove={handleRemoveItem}
                                        isDeletable={(activeDetailTab !== 'article' && activeDetailTab !== 'poll' && activeDetailTab !== 'video' && activeDetailTab !== 'quiz') || formData.items.length > 1}
                                        onMoveUp={(idx) => handleMoveItem(idx, 'up')}
                                        onMoveDown={(idx) => handleMoveItem(idx, 'down')}
                                        onOpenFileManager={(id, subField) => {
                                            setActiveMediaTarget(id);
                                            setActiveMediaSubTarget(subField || null);
                                            setActiveMediaType('image');
                                            fetchMedia('image');
                                            setShowFileManager(true);
                                        }}
                                        onOpenUrlMode={(id, subField) => {
                                            setActiveMediaTarget(id);
                                            setActiveMediaSubTarget(subField || null);
                                            setActiveMediaType('image');
                                            setTempUrl('');
                                            setUrlError(null);
                                            setIsUrlMode(true);
                                        }}
                                        onOpenImageEditor={(id, subField) => {
                                            setActiveMediaTarget(id);
                                            setActiveMediaSubTarget(subField || null);
                                            editorSaveInFlightRef.current = false;
                                            setIsEditorSaving(false);
                                            setShowImageEditor(true);
                                        }}
                                        onRenameMedia={(src, type) => handleRenameMediaWithAi(src, type, buildFocusedMediaKind(item, index, 'flipcard görseli'))}
                                    />
                                ) : item.type === 'beforeafter' ? (
                                    <PostBeforeAfterItem
                                        key={itemKey}
                                        item={item}
                                        index={index}
                                        totalItems={formData.items.length}
                                        showBlockNumbers={showBlockNumbers}
                                        onUpdate={handleUpdateItem}
                                        onRemove={handleRemoveItem}
                                        isDeletable={(activeDetailTab !== 'article' && activeDetailTab !== 'poll' && activeDetailTab !== 'video' && activeDetailTab !== 'quiz') || formData.items.length > 1}
                                        onMoveUp={(idx) => handleMoveItem(idx, 'up')}
                                        onMoveDown={(idx) => handleMoveItem(idx, 'down')}
                                        onOpenFileManager={(id, subField) => {
                                            setActiveMediaTarget(id);
                                            setActiveMediaSubTarget(subField || null);
                                            setActiveMediaType('image');
                                            fetchMedia('image');
                                            setShowFileManager(true);
                                        }}
                                        onOpenUrlMode={(id, subField) => {
                                            setActiveMediaTarget(id);
                                            setActiveMediaSubTarget(subField || null);
                                            setActiveMediaType('image');
                                            setTempUrl('');
                                            setUrlError(null);
                                            setIsUrlMode(true);
                                        }}
                                        onOpenImageEditor={(id, subField) => {
                                            setActiveMediaTarget(id);
                                            setActiveMediaSubTarget(subField || null);
                                            editorSaveInFlightRef.current = false;
                                            setIsEditorSaving(false);
                                            setShowImageEditor(true);
                                        }}
                                        onRenameMedia={(src, type) => handleRenameMediaWithAi(src, type, buildFocusedMediaKind(item, index, 'before after görseli'))}
                                    />
                                ) : item.type === ('quiz' as any) ? (
	                                    <PostQuizItem
	                                        key={itemKey}
                                        item={item}
                                        index={index}
                                        totalItems={formData.items.length}
                                        showBlockNumbers={showBlockNumbers}
                                        onUpdate={handleUpdateItem}
                                        onRemove={handleRemoveItem}
                                        isDeletable={(activeDetailTab !== 'article' && activeDetailTab !== 'poll' && activeDetailTab !== 'video' && activeDetailTab !== 'quiz') || formData.items.length > 1}
                                        onMoveUp={(idx) => handleMoveItem(idx, 'up')}
                                        onMoveDown={(idx) => handleMoveItem(idx, 'down')}
                                        onOpenFileManager={(id, subField, optionId) => {
                                            setActiveMediaTarget(id);
                                            setActiveMediaSubTarget(subField || null);
                                            setActiveMediaOptionTarget(optionId || null);
                                            setActiveMediaType('image');
                                            fetchMedia('image');
                                            setShowFileManager(true);
                                        }}
                                        onOpenUrlMode={(id, subField, optionId) => {
                                            setActiveMediaTarget(id);
                                            setActiveMediaSubTarget(subField || null);
                                            setActiveMediaOptionTarget(optionId || null);
                                            setActiveMediaType('image');
                                            setTempUrl('');
                                            setUrlError(null);
                                            setIsUrlMode(true);
                                        }}
                                        onOpenImageEditor={(id, subField, optionId) => {
                                            setActiveMediaTarget(id);
                                            setActiveMediaSubTarget(subField || null);
                                            setActiveMediaOptionTarget(optionId || null);
                                            editorSaveInFlightRef.current = false;
                                            setIsEditorSaving(false);
                                            setShowImageEditor(true);
                                        }}
	                                        onRenameMedia={(src, type) => handleRenameMediaWithAi(src, type, buildFocusedMediaKind(item, index, 'quiz görseli'))}
	                                    />
		                                ) : item.type === 'toc' ? (
                                            activeDetailTab === 'TABLE OF CONTENTS' ? null : renderTableOfContentsEditor(item, index)
		                                ) : item.type === 'recipe' ? (
                                            activeDetailTab === 'recipe' ? null : renderRecipeEditor(item, index)
                                    ) : item.type === 'event' ? (
                                            activeDetailTab === 'event' ? null : renderEventEditor(item, index)
	                                ) : item.type === 'iframe' ? (
	                                    <PostIframeItem
                                        key={itemKey}
                                        item={item}
                                        index={index}
                                        totalItems={formData.items.length}
                                        showBlockNumbers={showBlockNumbers}
                                        onUpdate={handleUpdateItem}
                                        onRemove={handleRemoveItem}
                                        isDeletable={(activeDetailTab !== 'article' && activeDetailTab !== 'poll' && activeDetailTab !== 'video' && activeDetailTab !== 'quiz') || formData.items.length > 1}
                                        onMoveUp={(idx) => handleMoveItem(idx, 'up')}
                                        onMoveDown={(idx) => handleMoveItem(idx, 'down')}
                                    />
                                ) : item.type === 'quote' ? (
                                    <PostQuoteItem
                                        key={itemKey}
                                        item={item}
                                        index={index}
                                        totalItems={formData.items.length}
                                        showBlockNumbers={showBlockNumbers}
                                        onUpdate={handleUpdateItem}
                                        onRemove={handleRemoveItem}
                                        isDeletable={(activeDetailTab !== 'article' && activeDetailTab !== 'poll' && activeDetailTab !== 'video' && activeDetailTab !== 'quiz') || formData.items.length > 1}
                                        onMoveUp={(idx) => handleMoveItem(idx, 'up')}
                                        onMoveDown={(idx) => handleMoveItem(idx, 'down')}
                                    />
                                ) : item.type === 'poll' ? (
                                    <PostPollItem
                                        key={itemKey}
                                        item={item}
                                        index={index}
                                        totalItems={formData.items.length}
                                        showBlockNumbers={showBlockNumbers}
                                        onUpdate={handleUpdateItem}
                                        onRemove={handleRemoveItem}
                                        isDeletable={(activeDetailTab !== 'article' && activeDetailTab !== 'poll' && activeDetailTab !== 'video' && activeDetailTab !== 'quiz') || formData.items.length > 1}
                                        onMoveUp={(idx) => handleMoveItem(idx, 'up')}
                                        onMoveDown={(idx) => handleMoveItem(idx, 'down')}
                                        onOpenFileManager={(id, subField, optionId) => {
                                            setActiveMediaTarget(id);
                                            setActiveMediaSubTarget(subField || null);
                                            setActiveMediaOptionTarget(optionId || null);
                                            setActiveMediaType('image');
                                            fetchMedia('image');
                                            setShowFileManager(true);
                                        }}
                                        onOpenUrlMode={(id, subField, optionId) => {
                                            setActiveMediaTarget(id);
                                            setActiveMediaSubTarget(subField || null);
                                            setActiveMediaOptionTarget(optionId || null);
                                            setActiveMediaType('image');
                                            setTempUrl('');
                                            setUrlError(null);
                                            setIsUrlMode(true);
                                        }}
                                        onOpenImageEditor={(id, subField, optionId) => {
                                            setActiveMediaTarget(id);
                                            setActiveMediaSubTarget(subField || null);
                                            setActiveMediaOptionTarget(optionId || null);
                                            editorSaveInFlightRef.current = false;
                                            setIsEditorSaving(false);
                                            setShowImageEditor(true);
                                        }}
                                        onRenameMedia={(src, type) => handleRenameMediaWithAi(src, type, buildFocusedMediaKind(item, index, 'anket görseli'))}
                                    />
                                ) : item.type === 'vs' ? (
                                    <PostVSItem
                                        key={itemKey}
                                        item={item}
                                        index={index}
                                        totalItems={formData.items.length}
                                        showBlockNumbers={showBlockNumbers}
                                        onUpdate={handleUpdateItem}
                                        onRemove={handleRemoveItem}
                                        isDeletable={(activeDetailTab !== 'article' && activeDetailTab !== 'poll' && activeDetailTab !== 'video' && activeDetailTab !== 'quiz') || formData.items.length > 1}
                                        onMoveUp={(idx) => handleMoveItem(idx, 'up')}
                                        onMoveDown={(idx) => handleMoveItem(idx, 'down')}
                                        onOpenFileManager={(id, subField, optionId) => {
                                            setActiveMediaTarget(id);
                                            setActiveMediaSubTarget(subField || null);
                                            setActiveMediaOptionTarget(optionId || null);
                                            setActiveMediaType('image');
                                            fetchMedia('image');
                                            setShowFileManager(true);
                                        }}
                                        onOpenUrlMode={(id, subField, optionId) => {
                                            setActiveMediaTarget(id);
                                            setActiveMediaSubTarget(subField || null);
                                            setActiveMediaOptionTarget(optionId || null);
                                            setActiveMediaType('image');
                                            setTempUrl('');
                                            setUrlError(null);
                                            setIsUrlMode(true);
                                        }}
                                        onOpenImageEditor={(id, subField, optionId) => {
                                            setActiveMediaTarget(id);
                                            setActiveMediaSubTarget(subField || null);
                                            setActiveMediaOptionTarget(optionId || null);
                                            editorSaveInFlightRef.current = false;
                                            setIsEditorSaving(false);
                                            setShowImageEditor(true);
                                        }}
                                        onRenameMedia={(src, type) => handleRenameMediaWithAi(src, type, buildFocusedMediaKind(item, index, 'vs görseli'))}
                                    />
                                ) : item.type === 'review' ? (
                                    <PostReviewItem
                                        key={itemKey}
                                        item={item}
                                        index={index}
                                        totalItems={formData.items.length}
                                        showBlockNumbers={showBlockNumbers}
                                        onUpdate={handleUpdateItem}
                                        onRemove={handleRemoveItem}
                                        isDeletable={(activeDetailTab !== 'article' && activeDetailTab !== 'poll' && activeDetailTab !== 'video' && activeDetailTab !== 'quiz') || formData.items.length > 1}
                                        onMoveUp={(idx) => handleMoveItem(idx, 'up')}
                                        onMoveDown={(idx) => handleMoveItem(idx, 'down')}
                                        onOpenFileManager={(id, subField, optionId) => {
                                            setActiveMediaTarget(id);
                                            setActiveMediaSubTarget(subField || null);
                                            setActiveMediaOptionTarget(optionId || null);
                                            setActiveMediaType('image');
                                            fetchMedia('image');
                                            setShowFileManager(true);
                                        }}
                                        onOpenUrlMode={(id, subField, optionId) => {
                                            setActiveMediaTarget(id);
                                            setActiveMediaSubTarget(subField || null);
                                            setActiveMediaOptionTarget(optionId || null);
                                            setActiveMediaType('image');
                                            setTempUrl('');
                                            setUrlError(null);
                                            setIsUrlMode(true);
                                        }}
                                        onOpenImageEditor={(id, subField, optionId) => {
                                            setActiveMediaTarget(id);
                                            setActiveMediaSubTarget(subField || null);
                                            setActiveMediaOptionTarget(optionId || null);
                                            editorSaveInFlightRef.current = false;
                                            setIsEditorSaving(false);
                                            setShowImageEditor(true);
                                        }}
                                        onRenameMedia={(src, type) => handleRenameMediaWithAi(src, type, buildFocusedMediaKind(item, index, 'inceleme görseli'))}
                                    />
                                ) : (
                                    <PostTextItem
                                        key={itemKey}
                                        item={item}
                                        index={index}
                                        totalItems={formData.items.length}
                                        showBlockNumbers={showBlockNumbers}
                                        onUpdate={handleUpdateItem}
                                        onRemove={handleRemoveItem}
                                        isDeletable={(activeDetailTab !== 'article' && activeDetailTab !== 'poll' && activeDetailTab !== 'video' && activeDetailTab !== 'quiz') || formData.items.length > 1}
                                        onMoveUp={(idx) => handleMoveItem(idx, 'up')}
                                        onMoveDown={(idx) => handleMoveItem(idx, 'down')}
                                    />
                                );
                            })}

                            {activeDetailTab !== 'quiz' && (
                                <div className="flex flex-wrap pt-4 gap-3">
                                    <button
                                        onClick={handleAddItem}
                                        className="admin-add-button admin-add-button--text flex items-center justify-center gap-2 px-4 py-2 bg-palette-maroon text-white rounded-[3px] text-[11px] font-black tracking-[0.15em] hover:opacity-90 transition-all active:scale-95 shadow-lg shadow-palette-maroon/10 leading-none"
                                    >
                                        <span className="material-symbols-rounded shrink-0" style={{ fontSize: '18px' }}>title</span>
                                        <span className="leading-none mt-[1px]">{t('admin.post.add.text')}</span>
                                    </button>
                                    <button
                                        onClick={handleAddImageItem}
                                        className="admin-add-button admin-add-button--image flex items-center justify-center gap-2 px-4 py-2 bg-emerald-600 text-white rounded-[3px] text-[11px] font-black tracking-[0.15em] hover:opacity-90 transition-all active:scale-95 shadow-lg shadow-emerald-600/10 leading-none"
                                    >
                                        <span className="material-symbols-rounded shrink-0" style={{ fontSize: '18px' }}>image</span>
                                        <span className="leading-none mt-[1px]">{t('admin.post.add.image')}</span>
                                    </button>
                                    <button
                                        onClick={handleAddSliderItem}
                                        className="admin-add-button admin-add-button--slider flex items-center justify-center gap-2 px-4 py-2 bg-indigo-600 text-white rounded-[3px] text-[11px] font-black tracking-[0.15em] hover:opacity-90 transition-all active:scale-95 shadow-lg shadow-indigo-600/10 leading-none"
                                    >
                                        <span className="material-symbols-rounded shrink-0" style={{ fontSize: '18px' }}>gallery_thumbnail</span>
                                        <span className="leading-none mt-[1px]">{t('admin.post.add.slider')}</span>
                                    </button>
                                    <button
                                        onClick={handleAddVideoItem}
                                        className="admin-add-button admin-add-button--video flex items-center justify-center gap-2 px-4 py-2 bg-rose-600 text-white rounded-[3px] text-[11px] font-black tracking-[0.15em] hover:opacity-90 transition-all active:scale-95 shadow-lg shadow-rose-600/10 leading-none"
                                    >
                                        <span className="material-symbols-rounded shrink-0" style={{ fontSize: '18px' }}>videocam</span>
                                        <span className="leading-none mt-[1px]">{t('admin.post.add.video')}</span>
                                    </button>
                                    <button
                                        onClick={handleAddAudioItem}
                                        className="admin-add-button admin-add-button--audio flex items-center justify-center gap-2 px-4 py-2 bg-amber-600 text-white rounded-[3px] text-[11px] font-black tracking-[0.15em] hover:opacity-90 transition-all active:scale-95 shadow-lg shadow-amber-600/10 leading-none"
                                    >
                                        <span className="material-symbols-rounded shrink-0" style={{ fontSize: '18px' }}>mic</span>
                                        <span className="leading-none mt-[1px]">{t('admin.post.add.audio')}</span>
                                    </button>
                                    <button
                                        onClick={handleAddFileItem}
                                        className="admin-add-button admin-add-button--file flex items-center justify-center gap-2 px-4 py-2 bg-slate-600 text-white rounded-[3px] text-[11px] font-black tracking-[0.15em] hover:opacity-90 transition-all active:scale-95 shadow-lg shadow-slate-600/10 leading-none"
                                    >
                                        <span className="material-symbols-rounded shrink-0" style={{ fontSize: '18px' }}>attach_file</span>
                                        <span className="leading-none mt-[1px]">{t('admin.post.add.file')}</span>
                                    </button>
                                    <button
                                        onClick={handleAddSocialItem}
                                        className="admin-add-button admin-add-button--social flex items-center justify-center gap-2 px-4 py-2 bg-blue-500 text-white rounded-[3px] text-[11px] font-black tracking-[0.15em] hover:opacity-90 transition-all active:scale-95 shadow-lg shadow-blue-500/10 leading-none"
                                    >
                                        <span className="material-symbols-rounded shrink-0" style={{ fontSize: '18px' }}>share</span>
                                        <span className="leading-none mt-[1px]">{t('admin.post.add.social')}</span>
                                    </button>
                                    <button
                                        onClick={handleAddFlipCardItem}
                                        className="admin-add-button admin-add-button--flip flex items-center justify-center gap-2 px-4 py-2 bg-orange-600 text-white rounded-[3px] text-[11px] font-black tracking-[0.15em] hover:opacity-90 transition-all active:scale-95 shadow-lg shadow-orange-600/10 leading-none"
                                    >
                                        <span className="material-symbols-rounded shrink-0" style={{ fontSize: '18px' }}>sync</span>
                                        <span className="leading-none mt-[1px]">{t('admin.post.add.flip')}</span>
                                    </button>
                                    <button
                                        onClick={handleAddBeforeAfterItem}
                                        className="admin-add-button admin-add-button--before-after flex items-center justify-center gap-2 px-4 py-2 bg-blue-600 text-white rounded-[3px] text-[11px] font-black tracking-[0.15em] hover:opacity-90 transition-all active:scale-95 shadow-lg shadow-blue-600/10 leading-none"
                                    >
                                        <span className="material-symbols-rounded shrink-0" style={{ fontSize: '18px' }}>compare</span>
                                        <span className="leading-none mt-[1px]">{t('admin.post.add.before_after')}</span>
                                    </button>
                                    <button
                                        onClick={handleAddPollItem}
                                        className="admin-add-button admin-add-button--poll flex items-center justify-center gap-2 px-4 py-2 bg-indigo-600 text-white rounded-[3px] text-[11px] font-black tracking-[0.15em] hover:opacity-90 transition-all active:scale-95 shadow-lg shadow-indigo-600/10 leading-none"
                                    >
                                        <span className="material-symbols-rounded shrink-0" style={{ fontSize: '18px' }}>poll</span>
                                        <span className="leading-none mt-[1px]">{t('admin.post.add.poll_alt')}</span>
                                    </button>
                                    <button
                                        onClick={handleAddVSItem}
                                        className="admin-add-button admin-add-button--vs flex items-center justify-center gap-2 px-4 py-2 bg-rose-600 text-white rounded-[3px] text-[11px] font-black tracking-[0.15em] hover:opacity-90 transition-all active:scale-95 shadow-lg shadow-rose-600/10 leading-none"
                                    >
                                        <span className="material-symbols-rounded shrink-0" style={{ fontSize: '18px' }}>swords</span>
                                        <span className="leading-none mt-[1px]">{t('admin.post.add.vs')}</span>
                                    </button>
                                    <button
                                        onClick={handleAddReviewItem}
                                        className="admin-add-button admin-add-button--review flex items-center justify-center gap-2 px-4 py-2 bg-emerald-600 text-white rounded-[3px] text-[11px] font-black tracking-[0.15em] hover:opacity-90 transition-all active:scale-95 shadow-lg shadow-emerald-600/10 leading-none"
                                    >
                                        <span className="material-symbols-rounded shrink-0" style={{ fontSize: '18px' }}>stars</span>
                                        <span className="leading-none mt-[1px]">{t('admin.post.add.review_alt')}</span>
                                    </button>
                                    <button
                                        onClick={handleAddQuoteItem}
                                        className="admin-add-button admin-add-button--quote flex items-center justify-center gap-2 px-4 py-2 bg-slate-800 text-white rounded-[3px] text-[11px] font-black tracking-[0.15em] hover:opacity-90 transition-all active:scale-95 shadow-lg shadow-slate-800/10 leading-none"
                                    >
                                        <span className="material-symbols-rounded shrink-0" style={{ fontSize: '18px' }}>format_quote</span>
                                        <span className="leading-none mt-[1px]">{t('admin.post.add.quote')}</span>
                                    </button>
                                    <button
                                        onClick={handleAddIframeItem}
                                        className="admin-add-button admin-add-button--iframe flex items-center justify-center gap-2 px-4 py-2 bg-indigo-700 text-white rounded-[3px] text-[11px] font-black tracking-[0.15em] hover:opacity-90 transition-all active:scale-95 shadow-lg shadow-indigo-700/10 leading-none"
                                    >
                                        <span className="material-symbols-rounded shrink-0" style={{ fontSize: '18px' }}>public</span>
                                        <span className="leading-none mt-[1px]">{t('admin.post.add.iframe')}</span>
                                    </button>
                                </div>
                            )}


                        </div>
                    </div>

                    {/* SIDEBAR */}
                    <div className="w-96 shrink-0 space-y-6">
                        <div className="bg-white p-6 rounded-[3px] border border-palette-tan/20 shadow-sm space-y-5">
                            <div className="space-y-4">
                                <h4 className="text-[13px] font-bold text-palette-tan ml-1 border-b border-palette-tan/15 pb-2 uppercase tracking-widest">{t('admin.post.cover')}</h4>
                                <div className="rounded-[3px] bg-palette-beige/5 border-2 border-dashed border-palette-tan/20 flex flex-col items-center justify-center overflow-hidden transition-all relative group w-full min-h-[160px]">
                                    {formData.thumbnail ? (
                                        <div className="relative w-full">
                                            <img
                                                src={formData.thumbnail}
                                                onLoad={() => setIsThumbnailLoading(false)}
                                                onError={() => setIsThumbnailLoading(false)}
                                                className="w-full h-auto object-contain block"
                                            />
                                            <MediaFilenameBadge
                                                src={formData.thumbnail}
                                                type="image"
                                                onRename={(src, type) => handleRenameMediaWithAi(src, type, `haber kapak görseli | ${formData.title || formData.summary || ''}`)}
                                            />
                                            <div className="absolute inset-0 bg-black/40 opacity-0 group-hover:opacity-100 transition-all flex items-center justify-center gap-2">
                                                <button
                                                    onClick={() => {
                                                        setActiveMediaTarget('thumbnail');
                                                        setActiveMediaType('image');
                                                        fetchMedia('image');
                                                        editorSaveInFlightRef.current = false;
                                                        setIsEditorSaving(false);
                                                        setShowImageEditor(true);
                                                    }}
                                                    className="p-3 bg-white/10 backdrop-blur-md rounded-[3px] text-white hover:bg-emerald-600 transition-all"
                                                    title={t('common.edit')}
                                                >
                                                    <span className="material-symbols-rounded" style={{ fontSize: '20px' }}>edit</span>
                                                </button>
                                                <button
                                                    onClick={() => setFormData({ ...formData, thumbnail: '' })}
                                                    className="p-3 bg-white/10 backdrop-blur-md rounded-[3px] text-white hover:bg-palette-red transition-all"
                                                    title={t('common.delete')}
                                                >
                                                    <span className="material-symbols-rounded" style={{ fontSize: '20px' }}>delete</span>
                                                </button>
                                            </div>
                                            {isThumbnailLoading && (
                                                <div className="absolute inset-0 flex items-center justify-center bg-white/60 pointer-events-none">
                                                    <span className="material-symbols-rounded animate-spin text-palette-maroon" style={{ fontSize: '22px' }}>progress_activity</span>
                                                </div>
                                            )}
                                        </div>
                                    ) : (
                                        <div className="flex flex-col items-center justify-center py-8">
                                            <div onClick={() => { setActiveMediaTarget('thumbnail'); setActiveMediaType('image'); fetchMedia('image'); setShowFileManager(true); }} className="flex flex-col items-center cursor-pointer group/pick mb-2">
                                                <span className="material-symbols-rounded text-palette-tan/20 group-hover/pick:text-palette-maroon transition-all mb-2" style={{ fontSize: '40px' }}>add</span>
                                                <span className="text-[13px] font-bold text-palette-tan/50 px-4 text-center">{t('admin.post.pick_image_alt')}</span>
                                            </div>
                                            <button
                                                onClick={() => { setActiveMediaTarget('thumbnail'); setActiveMediaType('image'); setIsUrlMode(true); setTempUrl(''); setUrlError(null); }}
                                                className="mt-2 text-[10px] font-black text-palette-tan/60 hover:text-palette-maroon border border-palette-tan/20 px-3 py-1.5 rounded-[3px] bg-white shadow-sm hover:shadow-md transition-all flex items-center gap-1.5 uppercase tracking-wider"
                                            >
                                                <span className="material-symbols-rounded" style={{ fontSize: '11px' }}>public</span> {t('admin.post.add_with_url')}
                                            </button>
                                        </div>
                                    )}
                                </div>
                            </div>
                            {formData.thumbnail && (
                                <div className="space-y-1.5 animate-in slide-in-from-top-2 duration-300">
                                    <div className="ml-1 flex items-center justify-between gap-2">
                                        <label className="flex items-center gap-1.5 text-[11px] font-black uppercase text-palette-tan/60">
                                            <span className="material-symbols-rounded normal-case" style={{ fontSize: '12px' }}>language</span> {t('admin.post.image_alt')}
                                        </label>
                                        <button
                                            type="button"
                                            onClick={handleGenerateThumbnailAltWithAi}
                                            disabled={isGeneratingThumbnailAlt}
                                            className="flex h-7 shrink-0 items-center gap-1.5 rounded-[3px] border border-palette-tan/20 bg-white px-2 text-[9px] font-black uppercase tracking-tight text-palette-maroon shadow-sm transition-all hover:border-emerald-400 hover:bg-emerald-50 hover:text-emerald-700 disabled:cursor-not-allowed disabled:opacity-60"
                                            title="AI ile SEO alt text üret"
                                            aria-label="AI ile kapak görseli SEO alt text üret"
                                        >
                                            <span className={`material-symbols-rounded ${isGeneratingThumbnailAlt ? 'animate-spin' : ''}`} style={{ fontSize: '13px' }}>
                                                {isGeneratingThumbnailAlt ? 'progress_activity' : 'auto_awesome'}
                                            </span>
                                            <span>{isGeneratingThumbnailAlt ? 'Üretiyor' : 'AI Üret'}</span>
                                        </button>
                                    </div>
                                    <input
                                        type="text"
                                        value={formData.thumbnailAlt}
                                        onChange={(e) => setFormData({ ...formData, thumbnailAlt: e.target.value })}
                                        className="w-full bg-palette-beige/5 border border-palette-tan/20 rounded-[3px] p-2 text-xs font-bold text-palette-maroon outline-none focus:border-palette-red transition-all"
                                        placeholder={t('admin.post.image_alt')}
                                    />
                                </div>
                            )}
                        </div>

                        <div className="bg-white p-6 rounded-[3px] border border-palette-tan/20 shadow-sm space-y-5">
                            <h4 className="text-[13px] font-bold text-palette-tan ml-1 border-b border-palette-tan/15 pb-2 uppercase tracking-widest flex items-center justify-between">
                                {t('admin.post.cat_settings')}
                                <span className="material-symbols-rounded text-palette-tan/30" style={{ fontSize: '14px' }}>settings</span>
                            </h4>

                            <div className="space-y-4">
                                {/* DİL SEÇİMİ */}
                                <div className="space-y-1.5">
                                    <label className="text-[11px] font-black text-palette-tan/60 ml-1 flex items-center gap-1.5">
                                        <span className="material-symbols-rounded" style={{ fontSize: '12px' }}>language</span> {t('admin.post.post_lang')}
                                    </label>
                                    <div className="relative group">
                                        <select
                                            value={selectedLanguage}
                                            onChange={(e) => setSelectedLanguage(e.target.value)}
                                            className="w-full bg-palette-beige/5 border border-palette-tan/20 rounded-[3px] p-3 text-sm font-bold text-palette-maroon outline-none appearance-none cursor-pointer focus:border-palette-red transition-all"
                                        >
                                            {languages.map(lang => (
                                                <option key={lang.code} value={lang.code}>{lang.name}</option>
                                            ))}
                                        </select>
                                        <span className="material-symbols-rounded absolute right-3 top-1/2 -translate-y-1/2 text-palette-tan/40 pointer-events-none group-hover:text-palette-maroon transition-colors" style={{ fontSize: '16px' }}>expand_more</span>
                                    </div>
                                </div>

                                {/* ANA KATEGORİ SEÇİMİ */}
                                <div className="space-y-1.5">
                                    <label className="text-[11px] font-black text-palette-tan/60 ml-1 flex items-center gap-1.5">
                                        <span className="material-symbols-rounded" style={{ fontSize: '12px' }}>category</span> {t('admin.post.main_cat')}
                                    </label>
                                    <div className="relative group">
                                        <select
                                            ref={categoryRef}
                                            value={selectedSubId || selectedParentId}
                                            onChange={(e) => handleParentCategoryChange(e.target.value)}
                                            className="w-full bg-palette-beige/5 border border-palette-tan/20 rounded-[3px] p-3 text-sm font-bold text-palette-maroon outline-none appearance-none cursor-pointer focus:border-palette-red transition-all"
                                        >
                                            <option value="">{t('admin.post.select_cat')}</option>
                                            {treeCategories.map(cat => (
                                                <option key={cat.id} value={cat.id}>{cat.label}</option>
                                            ))}
                                        </select>
                                        <span className="material-symbols-rounded absolute right-3 top-1/2 -translate-y-1/2 text-palette-tan/40 pointer-events-none group-hover:text-palette-maroon transition-colors" style={{ fontSize: '16px' }}>expand_more</span>
                                    </div>
                                </div>

                                {/* ALT KATEGORİ SEÇİMİ */}
                                <div className="space-y-1.5">
                                    <label className="text-[11px] font-black text-palette-tan/60 ml-1 flex items-center gap-1.5">
                                        <span className="material-symbols-rounded" style={{ fontSize: '12px' }}>list</span> {t('admin.post.sub_cat')}
                                    </label>
                                    <div className="relative group">
                                        <select
                                            value={selectedThirdId}
                                            onChange={(e) => handleSubCategoryChange(e.target.value)}
                                            disabled={!(selectedSubId || selectedParentId)}
                                            className={`w-full bg-palette-beige/5 border border-palette-tan/20 rounded-[3px] p-3 text-sm font-bold text-palette-maroon outline-none appearance-none cursor-pointer focus:border-palette-red transition-all ${!(selectedSubId || selectedParentId) ? 'opacity-50 cursor-not-allowed' : ''}`}
                                        >
                                            <option value="">{t('admin.post.select_sub_cat')}</option>
                                            {subCategoryOptions.map(cat => (
                                                <option key={cat.id} value={cat.id}>{cat.label}</option>
                                            ))}
                                        </select>
                                        <span className="material-symbols-rounded absolute right-3 top-1/2 -translate-y-1/2 text-palette-tan/40 pointer-events-none group-hover:text-palette-maroon transition-colors" style={{ fontSize: '16px' }}>expand_more</span>
                                    </div>
                                </div>

                                {/* ALT KATEGORİNİN ALT KATEGORİSİ SEÇİMİ (3. Seviye) */}
                                {selectedThirdId && categories.filter(c => c.parent_id === selectedThirdId).length > 0 && (
                                    <div className="space-y-1.5 animate-in slide-in-from-top-2 duration-300">
                                        <label className="text-[11px] font-black text-palette-tan/60 ml-1 flex items-center gap-1.5">
                                            <span className="material-symbols-rounded" style={{ fontSize: '12px' }}>subdirectory_arrow_right</span> {t('admin.post.sub_sub_cat')}
                                        </label>
                                        <div className="relative group">
                                            <select
                                                value={selectedFourthId}
                                                onChange={(e) => handleSubSubCategoryChange(e.target.value)}
                                                className="w-full bg-palette-beige/5 border border-palette-tan/20 rounded-[3px] p-3 text-sm font-bold text-palette-maroon outline-none appearance-none cursor-pointer focus:border-palette-red transition-all"
                                            >
                                                <option value="">{t('admin.post.select_sub_sub_cat')}</option>
                                                {categories.filter(c => c.parent_id === selectedThirdId).map(cat => (
                                                    <option key={cat.id} value={cat.id}>{cat.label}</option>
                                                ))}
                                            </select>
                                            <span className="material-symbols-rounded absolute right-3 top-1/2 -translate-y-1/2 text-palette-tan/40 pointer-events-none group-hover:text-palette-maroon transition-colors" style={{ fontSize: '16px' }}>expand_more</span>
                                        </div>
                                    </div>
                                )}
                            </div>

                            <div className="pt-2">
                                <div className="px-3 py-2 bg-palette-red/5 border border-palette-red/10 rounded-[3px]">
                                    <p className="text-[10px] font-black text-palette-red uppercase tracking-wider">{t('admin.post.selected_cat')}</p>
                                    <p className="text-[12px] font-bold text-palette-maroon">{formData.category || t('common.not_specified')}</p>
                                </div>
                            </div>
                        </div>



                        <div className="bg-white p-6 rounded-[3px] border border-palette-tan/20 shadow-sm space-y-5">
                            <div className="space-y-4">
                                <h4 className="text-[13px] font-bold text-palette-tan ml-1 border-b border-palette-tan/15 pb-2 uppercase tracking-widest">{t('admin.post.publishing')}</h4>

                                <div className="flex items-center justify-between p-4 bg-palette-beige/10 rounded-[3px] border border-palette-tan/20">
                                    <div className="flex items-center gap-2">
                                        <span className={`material-symbols-rounded ${formData.factChecked ? 'text-green-500' : 'text-palette-tan/30'}`} style={{ fontSize: '16px' }}>verified_user</span>
                                        <span className="text-[13px] font-bold text-palette-maroon">{t('admin.post.fact_check')}</span>
                                    </div>
                                    <button onClick={() => setFormData({ ...formData, factChecked: !formData.factChecked })} className={`w-10 h-5 rounded-full relative transition-all ${formData.factChecked ? 'bg-green-500' : 'bg-palette-tan/20'}`}>
                                        <div className={`absolute top-1 w-3 h-3 bg-white rounded-full transition-all ${formData.factChecked ? 'right-1' : 'left-1'}`} />
                                    </button>
                                </div>

                                <div className="space-y-2">
                                    <label className="text-[11px] font-black text-palette-tan/60 ml-1 uppercase">{t('admin.post.publish_future')}</label>
                                    <input
                                        type="datetime-local"
                                        value={formData.publishAt}
                                        onChange={(e) => setFormData({ ...formData, publishAt: e.target.value })}
                                        className="w-full bg-palette-beige/10 border border-palette-tan/20 rounded-[3px] p-3 text-sm font-bold text-palette-maroon outline-none cursor-pointer"
                                    />
                                </div>

                                <div className="pt-4 space-y-2">
                                    <div className="grid grid-cols-2 gap-2">
                                        <button
                                            onClick={() => handleSave('published')}
                                            className="flex items-center justify-center gap-2 py-2.5 bg-palette-red text-white rounded-[3px] font-black text-[11px] tracking-widest hover:opacity-90 transition-all shadow-lg shadow-palette-red/10"
                                        >
                                            {t('admin.post.publish_btn')}
                                        </button>
                                        <button
                                            onClick={() => handleSave('draft')}
                                            className="flex items-center justify-center gap-2 py-2.5 bg-palette-maroon text-white rounded-[3px] font-black text-[11px] tracking-widest hover:opacity-90 transition-all shadow-lg shadow-palette-maroon/10"
                                        >
                                            {t('admin.post.draft_btn')}
                                        </button>
                                    </div>
                                    <button
                                        onClick={() => handleSave('published')}
                                        className="w-full flex items-center justify-center gap-2 py-2.5 bg-palette-tan text-white rounded-[3px] font-black text-[11px] tracking-widest hover:opacity-90 transition-all shadow-lg shadow-palette-tan/10"
                                    >
                                        {t('admin.post.schedule_btn')}
                                    </button>
                                </div>
                            </div>
                        </div>
                    </div>
                </div>

                {/* MEDIA MANAGER MODAL */}
                {
                    showFileManager && (
                        <MediaManagerModal
                            onClose={() => setShowFileManager(false)}
                            onSelect={(src) => {
                                if (activeMediaTarget === 'thumbnail') {
                                    setFormData({ ...formData, thumbnail: src });
                                } else if (activeMediaTarget) {
                                    // Find target item to check type
                                    const targetItem = formData.items.find((i: PostItem) => i.id === activeMediaTarget);
                                    if (targetItem?.type === 'slider') {
                                        const currentUrls = targetItem.mediaUrls || [];
                                        handleUpdateItem(activeMediaTarget, 'mediaUrls', [...currentUrls, src] as any);
                                    } else if (targetItem?.type === 'flipcard' && activeMediaSubTarget) {
                                        const currentFlipData = targetItem.flipData || {
                                            frontImage: '',
                                            backImage: '',
                                            frontTitle: '',
                                            backTitle: '',
                                            backDescription: ''
                                        };
                                        const xlSrc = src.replace('_sm', '_xl');
                                        handleUpdateItem(activeMediaTarget, 'flipData', {
                                            ...currentFlipData,
                                            [activeMediaSubTarget]: xlSrc
                                        } as any);
                                    } else if (targetItem?.type === 'beforeafter' && activeMediaSubTarget) {
                                        const currentData = targetItem.beforeAfterData || {
                                            beforeImage: '',
                                            afterImage: '',
                                            beforeLabel: t('common.before'),
                                            afterLabel: t('common.after')
                                        };
                                        handleUpdateItem(activeMediaTarget, 'beforeAfterData', {
                                            ...currentData,
                                            [activeMediaSubTarget]: src
                                        } as any);
                                    } else if (targetItem?.type === 'poll' || targetItem?.type === 'vs') {
                                        if (activeMediaSubTarget === 'options' && activeMediaOptionTarget) {
                                            const currentOptions = targetItem.options || [];
                                            handleUpdateItem(activeMediaTarget, 'options', currentOptions.map((o: any) =>
                                                o.id === activeMediaOptionTarget ? { ...o, image: src } : o
                                            ) as any);
                                        } else {
                                            handleUpdateItem(activeMediaTarget, 'mediaUrl', src);
                                        }
                                    } else if (targetItem?.type === 'quiz' && activeMediaSubTarget) {
                                        handleUpdateItem(activeMediaTarget, 'quizData', setNestedPath(targetItem.quizData || {}, activeMediaSubTarget, src) as any);
                                    } else if (targetItem?.type === 'toc' && activeMediaSubTarget === 'tocItems' && activeMediaOptionTarget) {
                                        handleUpdateItem(activeMediaTarget, 'tocData', withUpdatedTocItemImage(targetItem, activeMediaOptionTarget, src) as any);
                                    } else if (targetItem?.type === 'recipe' && activeMediaSubTarget === 'recipeDirections' && activeMediaOptionTarget) {
                                        handleUpdateItem(activeMediaTarget, 'recipeData', withUpdatedRecipeDirectionImage(targetItem, activeMediaOptionTarget, src) as any);
                                    } else if (targetItem?.type === 'event' && activeMediaSubTarget === 'eventSchedule' && activeMediaOptionTarget) {
                                        handleUpdateItem(activeMediaTarget, 'eventData', withUpdatedEventScheduleImage(targetItem, activeMediaOptionTarget, src) as any);
                                    } else if (targetItem?.type === 'event' && activeMediaSubTarget === 'eventSpeakers' && activeMediaOptionTarget) {
                                        handleUpdateItem(activeMediaTarget, 'eventData', withUpdatedEventSpeakerImage(targetItem, activeMediaOptionTarget, src) as any);
                                    } else {
                                        handleUpdateItem(activeMediaTarget, 'mediaUrl', src);
                                    }
                                }
                                setShowFileManager(false);
                                setUrlError(null);
                            }}
                            localFiles={localFiles}
                            setLocalFiles={setLocalFiles}
                            type={activeMediaType}
                        />
                    )
                }

                {/* URL MODE MODAL */}
                {
                    isUrlMode && (
                        <div className="fixed inset-0 z-[110] flex items-center justify-center p-4">
                            <div className="absolute inset-0 bg-black/60 backdrop-blur-sm" onClick={() => setIsUrlMode(false)} />
                            <div className="bg-white w-full max-w-sm rounded-[3px] overflow-hidden shadow-2xl relative p-8 animate-in zoom-in duration-300 border border-palette-tan/20">
                                <div className="text-center space-y-5">
                                    <div className="flex flex-col items-center gap-2">
                                        <div className="p-3 bg-palette-beige/20 rounded-full">
                                            <span className="material-symbols-rounded text-palette-maroon" style={{ fontSize: '24px' }}>public</span>
                                        </div>
                                        <h3 className="text-lg font-black text-palette-maroon tracking-tight uppercase">
                                            {activeMediaType === 'video' ? t('admin.post.url_title_video') : activeMediaType === 'audio' ? t('admin.post.url_title_audio') : t('admin.post.url_title_image')}
                                        </h3>
                                        <p className="text-[11px] font-bold text-palette-tan/50 leading-relaxed max-w-[250px] mx-auto">
                                            {activeMediaType === 'video'
                                                ? t('admin.post.url_desc_video')
                                                : activeMediaType === 'audio'
                                                    ? t('admin.post.url_desc_audio')
                                                    : t('admin.post.url_desc_image')
                                            }
                                        </p>
                                    </div>

                                    <div className="space-y-3">
                                        <input
                                            autoFocus
                                            type="url"
                                            value={tempUrl}
                                            onChange={(e) => setTempUrl(e.target.value)}
                                            placeholder={activeMediaType === 'video' ? "https://youtube.com/watch?v=..." : activeMediaType === 'audio' ? "https://music.youtube.com/..." : "https://example.com/image.jpg"}
                                            className="w-full bg-palette-beige/5 border border-palette-tan/20 rounded-[3px] px-3 py-2.5 text-sm font-bold text-palette-maroon outline-none focus:border-palette-maroon transition-all placeholder:text-palette-tan/20"
                                            onKeyDown={(e) => e.key === 'Enter' && handleUrlSubmit()}
                                        />
                                        {urlError && <p className="text-xs font-bold text-red-500 animate-pulse">{urlError}</p>}
                                    </div>

                                    <div className="flex gap-2 pt-2">
                                        <button
                                            onClick={handleUrlSubmit}
                                            disabled={validatingUrl}
                                            className="flex-1 py-2.5 bg-palette-maroon text-white font-black text-[11px] tracking-widest rounded-[3px] hover:bg-palette-red transition-all shadow-md active:scale-95"
                                        >
                                            {validatingUrl ? t('admin.post.processing') + '...' : (activeMediaType === 'video' ? t('admin.post.get_video') : activeMediaType === 'audio' ? t('admin.post.get_audio') : t('admin.post.get_image'))}
                                        </button>
                                        <button onClick={() => setIsUrlMode(false)} className="px-5 py-2.5 bg-palette-beige/20 text-palette-tan font-black text-[11px] tracking-widest rounded-[3px] hover:bg-palette-beige/40 transition-all">
                                            {t('common.cancel')}
                                        </button>
                                    </div>
                                </div>
                            </div>
                        </div>
                    )
                }

                {
                    showImageEditor && (
                        <div className="fixed inset-0 z-[9999] flex items-center justify-center p-4 animate-in fade-in duration-500">
                            <div
                                className="absolute inset-0 bg-palette-maroon/80 backdrop-blur-sm"
                                onClick={() => {
                                    if (isEditorSaving) return;
                                    setShowImageEditor(false);
                                }}
                            />

                            <div className="bg-white w-full max-w-7xl h-[85vh] rounded-[3px] overflow-hidden shadow-2xl relative flex flex-col border border-palette-tan/20 animate-in zoom-in-95 duration-300">
                                {isEditorSaving && (
                                    <div className="absolute inset-0 z-[99999] flex items-center justify-center bg-white/60">
                                        <div className="flex items-center gap-2 px-4 py-2 rounded-[3px] bg-white shadow-md border border-palette-tan/20">
                                            <span className="material-symbols-rounded animate-spin text-palette-maroon" style={{ fontSize: '18px' }}>progress_activity</span>
                                            <span className="text-[11px] font-black tracking-widest text-palette-maroon uppercase">{t('common.processing')}</span>
                                        </div>
                                    </div>
                                )}
                                {imageEditorLoadError ? (
                                    <div className="flex flex-1 flex-col items-center justify-center gap-4 p-8 text-center">
                                        <span className="material-symbols-rounded text-palette-red" style={{ fontSize: '40px' }}>error</span>
                                        <div>
                                            <h3 className="text-sm font-black text-palette-maroon">{t('common.error')}</h3>
                                            <p className="mt-2 text-xs font-bold text-palette-tan">{imageEditorLoadError}</p>
                                        </div>
                                        <button
                                            type="button"
                                            onClick={() => {
                                                filerobotDepsPromise = null;
                                                setImageEditorDeps(null);
                                                setImageEditorLoadError(null);
                                            }}
                                            className="h-10 rounded-[3px] bg-palette-red px-5 text-[11px] font-black uppercase tracking-widest text-white"
                                        >
                                            {t('error_boundary.refresh')}
                                        </button>
                                    </div>
                                ) : !ImageEditorStyleSheetManager || !ImageEditorComponent || !editorShouldForwardProp || !editorConfig ? (
                                    <div className="flex flex-1 items-center justify-center">
                                        <div className="flex items-center gap-2 px-4 py-2 rounded-[3px] bg-white shadow-md border border-palette-tan/20">
                                            <span className="material-symbols-rounded animate-spin text-palette-maroon" style={{ fontSize: '18px' }}>progress_activity</span>
                                            <span className="text-[11px] font-black tracking-widest text-palette-maroon uppercase">{t('common.loading_short')}</span>
                                        </div>
                                    </div>
                                ) : (
                                    /*
                                    StyleSheetManager is loaded with the editor and keeps aggressive filtering to
                                    prevent Filerobot/styled-components props from leaking to DOM nodes.
                                    */
                                    <ImageEditorStyleSheetManager shouldForwardProp={editorShouldForwardProp}>
                                        <ImageEditorComponent
                                            {...editorConfig}
                                            source={getActiveEditorSource()}
                                            onSave={handleEditorSave}
                                            onClose={handleEditorClose}
                                        />
                                    </ImageEditorStyleSheetManager>
                                )}
                            </div>
                        </div>
                    )
                }
            </div>
        </div>
    );
};

// --- MEDIA MANAGER MODAL COMPONENT ---
const MediaManagerModal: React.FC<{
    onClose: () => void;
    onSelect: (src: string) => void;
    localFiles: any[];
    setLocalFiles: React.Dispatch<React.SetStateAction<any[]>>;
    type?: 'image' | 'video' | 'audio' | 'file';
}> = ({ onClose, onSelect, localFiles, setLocalFiles, type = 'image' }) => {
    const { t } = useLanguage();
    const [searchTerm, setSearchTerm] = useState('');
    const [selectedImage, setSelectedImage] = useState<string | null>(null);
    const [selectedImages, setSelectedImages] = useState<string[]>([]);
    const [uploading, setUploading] = useState(false);
    const [uploadProgress, setUploadProgress] = useState(0);
    const [uploadPreview, setUploadPreview] = useState<string | null>(null);
    const [deleting, setDeleting] = useState(false);
    const [bulkDeleting, setBulkDeleting] = useState(false);

    const { getRootProps, getInputProps, isDragActive } = useDropzone({
        onDrop: async (acceptedFiles) => {
            const file = acceptedFiles[0];
            setUploading(true);
            setUploadPreview(URL.createObjectURL(file));
            setUploadProgress(20);
            try {
                const timer = setInterval(() => setUploadProgress(p => p < 90 ? p + 10 : p), 200);
                const result = await storageService.uploadFile(file, undefined, type);
                clearInterval(timer);
                setUploadProgress(100);
                if (result) {
                    setLocalFiles(prev => [result, ...prev]);
                }
            } catch (err) {
                console.error(err);
            } finally {
                setTimeout(() => { setUploading(false); setUploadPreview(null); }, 500);
            }
        },
        accept: type === 'video'
            ? { 'video/*': ['.mp4', '.webm', '.mov', '.avi'] }
            : type === 'audio'
                ? { 'audio/*': ['.mp3', '.wav', '.ogg', '.m4a', '.aac'] }
                : type === 'file'
                    ? { 'application/*': ['.pdf', '.doc', '.docx', '.xls', '.xlsx', '.ppt', '.pptx', '.txt'] }
                    : { 'image/*': ['.jpg', '.jpeg', '.png', '.webp', '.gif'] }
    });

    const filteredFiles = useMemo(() => {
        if (!searchTerm) return localFiles;

        const normalize = (str: string) =>
            str.toLocaleLowerCase('tr-TR')
                .replace(/ı/g, 'i')
                .replace(/ğ/g, 'g')
                .replace(/ü/g, 'u')
                .replace(/ş/g, 's')
                .replace(/ö/g, 'o')
                .replace(/ç/g, 'c')
                .normalize("NFD")
                .replace(/[\u0300-\u036f]/g, "");

        const term = normalize(searchTerm);

        return localFiles.filter((f: any) =>
            normalize(f.name || '').includes(term) ||
            normalize(f.value || '').includes(term)
        );
    }, [localFiles, searchTerm]);

    const selectedImageSet = useMemo(() => new Set(selectedImages), [selectedImages]);
    const selectedFiles = useMemo(
        () => localFiles.filter((file: any) => selectedImageSet.has(file.src)),
        [localFiles, selectedImageSet]
    );

    const clearSelection = () => {
        setSelectedImage(null);
        setSelectedImages([]);
    };

    const handleSelectFile = (file: any, event: React.MouseEvent) => {
        event.stopPropagation();

        if (event.shiftKey) {
            const anchorSrc = selectedImage;
            const fileIndex = filteredFiles.findIndex((item: any) => item.src === file.src);
            const anchorIndex = anchorSrc
                ? filteredFiles.findIndex((item: any) => item.src === anchorSrc)
                : -1;

            setSelectedImages(prev => {
                const next = new Set(prev);

                if (anchorIndex >= 0 && fileIndex >= 0) {
                    const start = Math.min(anchorIndex, fileIndex);
                    const end = Math.max(anchorIndex, fileIndex);
                    filteredFiles.slice(start, end + 1).forEach((item: any) => next.add(item.src));
                } else {
                    next.add(file.src);
                }

                return Array.from(next);
            });
            setSelectedImage(file.src);
            return;
        }

        setSelectedImage(file.src);
        setSelectedImages([file.src]);
    };

    const handleDelete = async () => {
        if (!selectedImage || deleting || bulkDeleting) return;
        const fileToDelete = localFiles.find((f: any) => f.src === selectedImage);
        if (!fileToDelete) return;

        setDeleting(true);
        try {
            const success = await storageService.deleteFile(fileToDelete.id, fileToDelete.type || type);
            if (success) {
                setLocalFiles(prev => prev.filter((f: any) => f.src !== fileToDelete.src));
                setSelectedImage(null);
                setSelectedImages(prev => prev.filter(src => src !== fileToDelete.src));
            }
        } catch (err) {
            console.error("Delete failed:", err);
        } finally {
            setDeleting(false);
        }
    };

    const handleDeleteSelected = async () => {
        if (selectedFiles.length === 0 || deleting || bulkDeleting) return;

        const confirmed = window.confirm(
            t('admin.post.delete_selected_confirm').replace('{count}', String(selectedFiles.length))
        );
        if (!confirmed) return;

        setBulkDeleting(true);
        const filesToDelete = [...selectedFiles];
        const deletedSrcs = new Set<string>();

        try {
            for (const file of filesToDelete) {
                const success = await storageService.deleteFile(file.id, file.type || type);
                if (success) {
                    deletedSrcs.add(file.src);
                }
            }

            if (deletedSrcs.size > 0) {
                setLocalFiles(prev => prev.filter((file: any) => !deletedSrcs.has(file.src)));
                setSelectedImages(prev => prev.filter(src => !deletedSrcs.has(src)));
                if (selectedImage && deletedSrcs.has(selectedImage)) {
                    setSelectedImage(null);
                }
            }

            if (deletedSrcs.size !== filesToDelete.length) {
                window.alert(
                    t('admin.post.delete_selected_partial')
                        .replace('{deleted}', String(deletedSrcs.size))
                        .replace('{total}', String(filesToDelete.length))
                );
            }
        } finally {
            setBulkDeleting(false);
        }
    };

    return (
        <div className="fixed inset-0 z-[100] flex items-center justify-center p-4 animate-in fade-in duration-500">
            <div className="absolute inset-0 bg-palette-maroon/80 backdrop-blur-sm" onClick={onClose} />

            <div className="bg-white w-full max-w-7xl h-[85vh] rounded-[3px] overflow-hidden shadow-2xl relative flex flex-col border border-palette-tan/20 animate-in zoom-in-95 duration-300">
                {/* HEADER */}
                <div className="px-8 py-5 border-b border-palette-tan/10 flex items-center justify-between bg-white relative z-10">
                    <div className="flex items-center gap-8 flex-1">
                        <div className="flex items-center gap-3">
                            <div className="w-1.5 h-6 bg-palette-red rounded-full" />
                            <h3 className="text-xl font-black text-palette-maroon tracking-tight uppercase">{t('admin.post.media_library')}</h3>
                        </div>
                        <div className="relative flex-1 max-w-lg group">
                            <span className="material-symbols-rounded absolute left-4 top-1/2 -translate-y-1/2 text-palette-tan/30 group-focus-within:text-palette-maroon transition-colors" style={{ fontSize: '18px' }}>search</span>
                            <input
                                type="text"
                                placeholder={t('admin.post.search_storage')}
                                value={searchTerm}
                                onChange={(e) => setSearchTerm(e.target.value)}
                                className="w-full h-11 bg-palette-beige/5 border border-palette-tan/15 rounded-[3px] pl-11 pr-4 text-[13px] font-bold text-palette-maroon outline-none focus:border-palette-maroon focus:bg-white focus:ring-4 focus:ring-palette-maroon/5 transition-all text-sm"
                            />
                        </div>
                    </div>
                    <button onClick={onClose} className="w-10 h-10 flex items-center justify-center rounded-[3px] text-palette-tan/30 hover:text-palette-red hover:bg-red-50 transition-all border border-transparent hover:border-red-100"><span className="material-symbols-rounded" style={{ fontSize: '22px' }}>close</span></button>
                </div>

                <div className="flex-1 flex overflow-hidden">
                    {/* LEFT SIDEBAR: UPLOAD ZONE (Aligned Top) */}
                    <div className="w-80 border-r border-palette-tan/10 p-6 flex flex-col bg-palette-beige/5 shrink-0 relative overflow-hidden">
                        <div
                            {...getRootProps()}
                            className={`flex flex-col items-center justify-start pt-12 border-2 border-dashed rounded-[3px] h-full p-8 text-center transition-all cursor-pointer relative z-10 ${isDragActive ? 'border-palette-maroon bg-white shadow-xl scale-[0.98]' : 'border-palette-tan/15 hover:border-palette-maroon hover:bg-white bg-white/40'
                                }`}
                        >
                            <input {...getInputProps()} />

                            {/* Extensions Tags (Up High) */}
                            <div className="flex flex-wrap justify-center gap-1.5 mb-10">
                                {type === 'video'
                                    ? ['MP4', 'WEBM', 'MOV', 'AVI'].map(ext => (
                                        <span key={ext} className="text-[10px] font-black text-white bg-rose-500 border border-rose-400 px-2.5 py-1 rounded-[3px] shadow-sm tracking-tighter">
                                            {ext}
                                        </span>
                                    ))
                                    : type === 'audio'
                                        ? ['MP3', 'WAV', 'OGG', 'M4A', 'AAC'].map(ext => (
                                            <span key={ext} className="text-[10px] font-black text-white bg-amber-500 border border-amber-400 px-2.5 py-1 rounded-[3px] shadow-sm tracking-tighter">
                                                {ext}
                                            </span>
                                        ))
                                        : type === 'file'
                                            ? ['PDF', 'DOCX', 'XLSX', 'PPTX'].map(ext => (
                                                <span key={ext} className="text-[10px] font-black text-white bg-slate-500 border border-slate-400 px-2.5 py-1 rounded-[3px] shadow-sm tracking-tighter">
                                                    {ext}
                                                </span>
                                            ))
                                            : ['JPG', 'JPEG', 'WEBP', 'PNG', 'GIF'].map(ext => (
                                                <span key={ext} className="text-[10px] font-black text-palette-tan/40 bg-white border border-palette-tan/10 px-2.5 py-1 rounded-[3px] shadow-sm tracking-tighter">
                                                    {ext}
                                                </span>
                                            ))
                                }
                            </div>

                            <div className="mb-6 relative">
                                <div className={`w-16 h-16 rounded-full flex items-center justify-center transition-all duration-500 ${isDragActive ? 'bg-palette-maroon scale-110' : 'bg-palette-tan/5'}`}>
                                    <span className={`material-symbols-rounded transition-colors duration-500 ${isDragActive ? 'text-white' : 'text-palette-tan/20'}`} style={{ fontSize: '28px' }}>upload</span>
                                </div>
                                {!isDragActive && (
                                    <div className="absolute inset-0 border-4 border-palette-tan/10 border-t-palette-maroon/20 rounded-full animate-spin-slow opacity-30" />
                                )}
                            </div>

                            <p className="text-[13px] font-bold text-palette-tan/60 mb-8 px-6 leading-relaxed">
                                {isDragActive ? t('admin.post.drop_to_upload') : t('admin.post.drag_drop_files')}
                            </p>

                            <button className="flex items-center justify-center gap-2 w-full h-10 bg-white border border-palette-tan/20 text-palette-maroon text-[11px] font-black tracking-widest rounded-[3px] hover:bg-palette-maroon hover:text-white hover:border-palette-maroon transition-all shadow-sm active:scale-95">
                                <span className="material-symbols-rounded" style={{ fontSize: '14px' }}>add</span>
                                {t('admin.post.browse_files')}
                            </button>

                            {/* UPLOADING PREVIEW (Inside Dropzone) */}
                            {uploading && (
                                <div
                                    onClick={(e) => e.stopPropagation()}
                                    className="mt-10 w-full animate-in zoom-in-95 duration-300 flex flex-col items-center"
                                >
                                    <div className="relative aspect-square w-full max-w-[160px] rounded-[3px] overflow-hidden border border-palette-tan/20 shadow-2xl ring-4 ring-white bg-slate-900">
                                        {type === 'video' ? (
                                            <div className="w-full h-full relative">
                                                <video
                                                    src={uploadPreview || ''}
                                                    className="w-full h-full object-cover opacity-60"
                                                    muted
                                                    playsInline
                                                />
                                                <div className="absolute inset-0 flex items-center justify-center pointer-events-none">
                                                    <span className="material-symbols-rounded text-white opacity-20" style={{ fontSize: '48px' }}>videocam</span>
                                                </div>
                                            </div>
                                        ) : (
                                            <img src={uploadPreview || ''} className="w-full h-full object-cover opacity-40 blur-[1px]" />
                                        )}
                                        <div className="absolute inset-0 flex flex-col items-center justify-center bg-palette-maroon/10 backdrop-blur-[1px]">
                                            <div className="relative">
                                                <span className="material-symbols-rounded text-palette-maroon animate-spin" style={{ fontSize: '32px' }}>progress_activity</span>
                                                <div className="absolute inset-0 flex items-center justify-center">
                                                    <span className="text-[8px] font-black text-palette-maroon">{uploadProgress}%</span>
                                                </div>
                                            </div>
                                            <span className="mt-3 text-[9px] font-black text-palette-maroon tracking-[0.2em] uppercase">{t('admin.post.processing')}</span>
                                        </div>
                                    </div>
                                    <div className="mt-4 w-full px-4">
                                        <div className="h-1 bg-palette-tan/10 rounded-full overflow-hidden">
                                            <div
                                                className="h-full bg-palette-red transition-all duration-300 shadow-[0_0_8px_rgba(239,68,68,0.4)]"
                                                style={{ width: `${uploadProgress}%` }}
                                            />
                                        </div>
                                    </div>
                                </div>
                            )}
                        </div>
                    </div>

                    {/* MAIN CONTENT: IMAGES GRID (Refined Typography) */}
                    <div
                        className="flex-1 p-8 overflow-y-auto bg-white custom-scrollbar"
                        onClick={clearSelection}
                    >
                        {filteredFiles.length === 0 ? (
                            <div className="h-full flex flex-col items-center justify-center text-palette-tan/10">
                                {type === 'video' ? <span className="material-symbols-rounded mb-6" style={{ fontSize: '80px' }}>movie</span> : type === 'audio' ? <span className="material-symbols-rounded mb-6" style={{ fontSize: '80px' }}>mic</span> : type === 'file' ? <span className="material-symbols-rounded mb-6" style={{ fontSize: '80px' }}>description</span> : <span className="material-symbols-rounded mb-6" style={{ fontSize: '80px' }}>image</span>}
                                <p className="text-[12px] font-black tracking-[0.3em] uppercase opacity-50">
                                    {t(`admin.post.empty_vault_${type}`)}
                                </p>
                            </div>
                        ) : (
                            <div className="grid grid-cols-2 sm:grid-cols-3 md:grid-cols-4 lg:grid-cols-5 xl:grid-cols-6 gap-8 pb-10">
                                {filteredFiles.map((file) => (
                                    <div
                                        key={file.id}
                                        onClick={(e) => handleSelectFile(file, e)}
                                        onDoubleClick={(e) => {
                                            e.stopPropagation();
                                            onSelect(file.src);
                                        }}
                                        className="group flex flex-col cursor-pointer"
                                    >
                                        <div className={`relative aspect-square rounded-[3px] border-2 transition-all duration-300 overflow-hidden flex items-center justify-center ${selectedImageSet.has(file.src)
                                            ? 'border-emerald-500 ring-[8px] ring-emerald-500/5 shadow-2xl'
                                            : 'border-palette-tan/10 hover:border-palette-maroon/40 group-hover:shadow-xl bg-palette-beige/5'
                                            }`}>
                                            {type === 'video' ? (
                                                file.thumb ? (
                                                    <img
                                                        src={file.thumb}
                                                        className={`w-full h-full object-cover transition-all duration-700 ${selectedImageSet.has(file.src) ? 'scale-105' : 'group-hover:scale-105 group-hover:rotate-1'
                                                            }`}
                                                        loading="lazy"
                                                    />
                                                ) : (
                                                    <div className="w-full h-full flex flex-col items-center justify-center bg-slate-900">
                                                        <span className="material-symbols-rounded text-white/20 mb-2" style={{ fontSize: '48px' }}>videocam</span>
                                                        <span className="text-[8px] font-black text-white/40 uppercase tracking-widest">{file.value?.split('.').pop()}</span>
                                                    </div>
                                                )
                                            ) : type === 'audio' ? (
                                                <div className="w-full h-full flex flex-col items-center justify-center bg-amber-50">
                                                    <span className="material-symbols-rounded text-amber-500 mb-2 opacity-40 group-hover:opacity-100 transition-opacity" style={{ fontSize: '48px' }}>mic</span>
                                                    <span className="text-[8px] font-black text-amber-800/40 uppercase tracking-widest">{file.value?.split('.').pop()}</span>
                                                </div>
                                            ) : type === 'file' ? (
                                                <div className="w-full h-full flex flex-col items-center justify-center bg-slate-50">
                                                    <span className="material-symbols-rounded text-slate-500 mb-2 opacity-40 group-hover:opacity-100 transition-opacity" style={{ fontSize: '48px' }}>attach_file</span>
                                                    <span className="text-[8px] font-black text-slate-800/40 uppercase tracking-widest">{file.value?.split('.').pop()}</span>
                                                </div>
                                            ) : (
                                                <img
                                                    src={file.thumb || file.src}
                                                    className={`w-full h-full object-contain p-1 transition-all duration-700 ${selectedImageSet.has(file.src) ? 'scale-105' : 'group-hover:scale-105 group-hover:rotate-1'
                                                        }`}
                                                    loading="lazy"
                                                />
                                            )}

                                            {/* Status Badge */}
                                            {selectedImageSet.has(file.src) && (
                                                <div className="absolute inset-0 bg-emerald-500/5 flex items-center justify-center">
                                                    <div className="bg-emerald-500 text-white rounded-full p-2 shadow-2xl animate-in zoom-in-50 duration-300 ring-4 ring-white">
                                                        <span className="material-symbols-rounded" style={{ fontSize: '18px' }}>check</span>
                                                    </div>
                                                </div>
                                            )}

                                            <div className="absolute top-2 left-2 flex items-center gap-1 opacity-0 group-hover:opacity-100 transition-opacity">
                                                <span className="text-[8px] font-black text-white bg-palette-maroon/80 px-1.5 py-0.5 rounded-[3px] backdrop-blur-md uppercase tracking-tighter">
                                                    {file.src.split('.').pop()}
                                                </span>
                                            </div>
                                        </div>
                                        <p className={`mt-3 text-[10px] font-black tracking-tight truncate px-1 transition-all duration-300 ${selectedImageSet.has(file.src) ? 'text-emerald-700 font-bold' : 'text-palette-tan/60 group-hover:text-palette-maroon'
                                            }`}>
                                            {file.value || file.name || 'document.bin'}
                                        </p>
                                        <div className="flex items-center justify-between px-1 mt-0.5">
                                            <span className="text-[8px] font-bold text-palette-tan/30 uppercase tracking-widest">{t('admin.post.asset_label')}</span>
                                        </div>
                                    </div>
                                ))}
                            </div>
                        )}
                    </div>
                </div>

                {/* FOOTER: Perfectly Aligned */}
                <div className="px-8 py-4 border-t border-palette-tan/10 flex items-center justify-between bg-palette-beige/5">
                    <div className="flex items-center gap-3">
                        <button
                            onClick={handleDelete}
                            disabled={!selectedImage || deleting || bulkDeleting}
                            className="flex items-center justify-center gap-2 h-9 px-5 bg-palette-red text-white rounded-[3px] text-[11px] font-black tracking-widest hover:bg-red-700 transition-all shadow-xl shadow-palette-red/10 disabled:opacity-20 disabled:shadow-none active:scale-95"
                        >
                            <span className="material-symbols-rounded" style={{ fontSize: '16px' }}>{deleting ? 'progress_activity' : 'delete'}</span>
                            {deleting ? t('common.deleting') : t('admin.post.delete_permanently')}
                        </button>

                        <button
                            onClick={handleDeleteSelected}
                            disabled={selectedFiles.length === 0 || deleting || bulkDeleting || uploading}
                            className="flex items-center justify-center gap-2 h-9 px-5 bg-white text-palette-red border border-palette-red/20 rounded-[3px] text-[11px] font-black tracking-widest hover:bg-red-50 hover:border-palette-red/40 transition-all shadow-sm disabled:opacity-20 disabled:shadow-none active:scale-95"
                        >
                            <span className="material-symbols-rounded" style={{ fontSize: '16px' }}>{bulkDeleting ? 'progress_activity' : 'delete_sweep'}</span>
                            {bulkDeleting
                                ? t('common.deleting')
                                : `${t('admin.post.delete_selected_media')} (${selectedFiles.length})`}
                        </button>
                    </div>

                    <div className="flex items-center gap-4">
                        <button
                            disabled={!selectedImage || uploading || deleting || bulkDeleting}
                            onClick={() => selectedImage && onSelect(selectedImage)}
                            className="flex items-center justify-center gap-2 h-10 px-8 bg-emerald-600 text-white rounded-[3px] text-[11px] font-black tracking-[0.2em] shadow-2xl shadow-emerald-600/20 hover:bg-emerald-700 transition-all disabled:opacity-20 disabled:shadow-none active:scale-95"
                        >
                            <span className="material-symbols-rounded" style={{ fontSize: '18px' }}>check_circle</span>
                            <span>{t('admin.post.use_this').replace('{type}', type.toUpperCase())}</span>
                        </button>
                        <button
                            onClick={onClose}
                            className="flex items-center justify-center h-10 px-6 text-[11px] font-black text-palette-tan/50 hover:text-palette-maroon border border-palette-tan/15 rounded-[3px] hover:bg-white transition-all bg-white shadow-sm active:scale-95 uppercase tracking-widest"
                        >
                            {t('common.close')}
                        </button>
                    </div>
                </div>
                {/* HIDDEN FONT LOADER - Ensures browser loads fonts before Filerobot needs them */}
                <div className="fie-font-preload" style={{ visibility: 'hidden', position: 'absolute', top: -1000, height: 0, overflow: 'hidden' }}>
                    {FIE_TEXT_FONTS.map((font) => (
                        <span key={font} style={{ fontFamily: font }}> {font} </span>
                    ))}
                </div>
            </div>
        </div>
    );
};

export default PostManagement;
