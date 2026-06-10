import { supabase } from '@/lib/supabase';
import { NewsType, type NavigationItem, type NewsItem, type SiteFont, type SiteSettings } from '@/types';
import { slugify } from '@/utils/helpers';
import { getSpecialContentTypeAliases } from '@/utils/specialContent';

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

const TEXT_PAYLOAD_KEYS = new Set([
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

const TEXT_ARRAY_KEYS = new Set(['items', 'pros', 'cons']);

const normalizeStoredTextPayload = (value: unknown, key = ''): unknown => {
    if (typeof value === 'string') {
        return TEXT_PAYLOAD_KEYS.has(key) || TEXT_ARRAY_KEYS.has(key)
            ? normalizeStoredPlainText(value)
            : value;
    }

    if (Array.isArray(value)) {
        return value.map((entry) => normalizeStoredTextPayload(entry, key));
    }

    if (value && typeof value === 'object') {
        return Object.fromEntries(
            Object.entries(value as Record<string, unknown>)
                .map(([childKey, childValue]) => [childKey, normalizeStoredTextPayload(childValue, childKey)])
        );
    }

    return value;
};

const normalizeNewsType = (value: unknown): NewsType => {
    const raw = String(value ?? '').trim();
    const normalized = raw.replace(/[\s-]+/g, '_').toUpperCase();

    switch (normalized) {
        case 'ARTICLE':
        case 'POST':
        case 'NEWS':
        case 'CONTENTS':
        case 'TABLE_OF_CONTENTS':
        case 'RECIPE':
        case '':
            return NewsType.STANDARD;
        case 'VIDEO':
            return NewsType.VIDEO;
        case 'AUDIO':
            return NewsType.AUDIO;
        case 'GALLERY':
        case 'SLIDER':
            return NewsType.GALLERY;
        case 'EMBED':
        case 'IFRAME':
        case 'SOCIAL':
            return NewsType.EMBED;
        case 'POLL':
            return NewsType.POLL;
        case 'QUIZ':
            return NewsType.QUIZ;
        case 'VS':
            return NewsType.VS;
        case 'IMAGE':
            return NewsType.IMAGE;
        case 'FLIP_CARD':
        case 'FLIPCARD':
            return NewsType.FLIP_CARD;
        case 'BEFORE_AFTER':
        case 'BEFOREAFTER':
            return NewsType.BEFORE_AFTER;
        case 'REVIEW':
            return NewsType.REVIEW;
        case 'PARAGRAPH':
        case 'QUOTE':
            return NewsType.PARAGRAPH;
        default:
            return NewsType.STANDARD;
    }
};

const getCategoryTerms = (category?: string | string[] | null) => {
    const rawTerms = (Array.isArray(category) ? category : [category])
        .map((value) => String(value || '').trim())
        .filter(Boolean);

    return Array.from(new Set(rawTerms.flatMap((term) => {
        const slug = slugify(term);
        return [term, term.toLocaleLowerCase('tr-TR'), slug].filter(Boolean);
    })));
};

const getTypeFilterConditions = (terms: string[]) => {
    const typeAliases = getSpecialContentTypeAliases(terms);
    return typeAliases.flatMap((alias) => {
        const upperAlias = alias.toUpperCase();
        return [
            `type.eq.${alias}`,
            `type.eq.${upperAlias}`,
            `type.ilike.%${alias}%`,
        ];
    });
};

// --- INSTANT CACHE ENGINE (2026 LIGHT-SPEED) ---
const CACHE_TTL = {
    SETTINGS: 1000 * 30,      // 30 seconds
    NAV: 1000 * 60 * 5,      // 5 minutes
    NEWS: 1000 * 30,         // 30 seconds
    STORIES: 1000 * 60,      // 1 minute
};

const cache: Record<string, { data: any; expiry: number }> = {};
const inflight: Record<string, Promise<any> | undefined> = {};
const SITE_PUBLIC_COLUMNS = [
    'id',
    'language_code',
    'site_name',
    'timezone',
    'footer_about',
    'optional_url_button_name',
    'copyright_text',
    'logo_url',
    'footer_logo_url',
    'dark_logo_url',
    'email_logo_url',
    'favicon_url',
    'home_title',
    'meta_description',
    'meta_keywords',
    'canonical_url',
    'og_image_url',
    'google_analytics_id',
    'google_search_console_code',
    'bing_verification_code',
    'twitter_username',
    'fb_app_id',
    'organization_legal_name',
    'organization_phone',
    'organization_address',
    'robots_txt',
    'weather_enabled',
    'weather_location_name',
    'weather_location_country',
    'weather_latitude',
    'weather_longitude',
    'weather_timezone',
    'weather_update_interval_minutes',
    'market_enabled',
    'market_provider',
    'market_altinapi_key',
    'market_altinapi_base_url',
    'market_genelpara_base_url',
    'market_update_interval_seconds',
    'market_currency_symbols',
    'market_gold_symbols',
    'prayer_enabled',
    'prayer_diyanet_base_url',
    'prayer_location_name',
    'prayer_location_country',
    'prayer_location_state_id',
    'prayer_location_city_id',
    'prayer_timezone',
    'prayer_refresh_lead_days',
    'prayer_cache_days',
    'daily_ayah_enabled',
    'daily_ayah_start_date',
    'daily_ayah_quran_api_base_url',
    'daily_ayah_quran_api_token',
].join(',');

const withCache = async (key: string, ttl: number, fetcher: () => Promise<any>) => {
    const now = Date.now();
    if (cache[key] && cache[key].expiry > now) {
        return cache[key].data;
    }
    if (inflight[key]) return inflight[key];

    const promise = (async () => {
        try {
            const data = await fetcher();
            cache[key] = { data, expiry: Date.now() + ttl };
            return data;
        } finally {
            delete inflight[key];
        }
    })();

    inflight[key] = promise;
    return promise;
};

export const invalidateDataCache = (predicate?: (key: string) => boolean) => {
    for (const key of Object.keys(cache)) {
        if (!predicate || predicate(key)) delete cache[key];
    }
    for (const key of Object.keys(inflight)) {
        if (!predicate || predicate(key)) delete inflight[key];
    }
};

export const invalidateSiteSettingsCache = (lang?: string) => {
    const normalizedLang = String(lang || '').trim().toLowerCase().replace(/_/g, '-');
    invalidateDataCache((key) => {
        if (key === 'seo_alternates') return true;
        if (key === 'site_fonts') return true;
        if (!key.startsWith('settings_')) return false;
        return !normalizedLang || key === `settings_${normalizedLang}`;
    });
};

export const dataService = {
    async getSiteSettings(lang: string): Promise<SiteSettings | null> {
        const languageCode = String(lang || 'tr').trim().toLowerCase().replace(/_/g, '-') || 'tr';
        return withCache(`settings_${languageCode}`, CACHE_TTL.SETTINGS, async () => {
            const fetchSettings = async (code: string) => {
                const { data, error } = await supabase
                    .from('site_settings')
                    .select(SITE_PUBLIC_COLUMNS)
                    .eq('language_code', code)
                    .maybeSingle();

                if (error) {
                    console.error('Error fetching site settings:', error);
                    return null;
                }
                return data;
            };

            const data = await fetchSettings(languageCode);
            if (data) return data;

            const seoAlternates = await dataService.getSeoAlternates();
            const defaultLangCode = seoAlternates.find((entry) => entry.isDefault)?.code || 'tr';
            if (languageCode !== defaultLangCode) {
                const fallbackData = await fetchSettings(defaultLangCode);
                if (fallbackData) return fallbackData;
            }
            if (languageCode !== 'tr' && defaultLangCode !== 'tr') {
                return await fetchSettings('tr');
            }
            return null;
        });
    },

    async getSiteFonts(): Promise<SiteFont[]> {
        return withCache('site_fonts', CACHE_TTL.SETTINGS, async () => {
            const { data, error } = await supabase
                .from('site_fonts')
                .select('id,name,family,type,source,web_font_path,flutter_family,fallback_stack,font_files,is_active,sort_order')
                .eq('is_active', true)
                .order('sort_order', { ascending: false })
                .order('id', { ascending: false });

            if (error) {
                console.error('Error fetching site fonts:', error);
                return [];
            }
            return (data || []) as SiteFont[];
        });
    },

    async getSeoAlternates(): Promise<{ code: string; canonicalUrl: string; isDefault: boolean; name: string; direction: 'ltr' | 'rtl'; flagCode: string }[]> {
        return withCache('seo_alternates', CACHE_TTL.SETTINGS, async () => {
            const fallback = [{ code: 'tr', name: 'Türkçe', direction: 'ltr' as const, flagCode: 'tr', isDefault: true }];

            const { data: langs, error: langsError } = await supabase
                .from('languages')
                .select('code, is_default, status, name, direction, flag_code')
                .eq('status', 'active');

            const normalizedLangs = (langsError || !langs || langs.length === 0)
                ? fallback
                : (langs as any[])
                    .map((l) => {
                        const code = String(l?.code || '').trim();
                        if (!code) return null;
                        const name = String(l?.name || '').trim() || code.toUpperCase();
                        const direction = (String(l?.direction || '').trim() === 'rtl') ? 'rtl' : 'ltr';
                        const flagCode = String(l?.flag_code || '').trim() || code;
                        return { code, name, direction, flagCode, isDefault: !!l?.is_default };
                    })
                    .filter(Boolean) as { code: string; name: string; direction: 'ltr' | 'rtl'; flagCode: string; isDefault: boolean }[];

            if (normalizedLangs.length > 0 && !normalizedLangs.some((l) => l.isDefault)) {
                normalizedLangs[0].isDefault = true;
            }

            const codes = normalizedLangs
                .map((l) => l.code)
                .filter((code) => !!code);

            const { data: settings, error: settingsError } = await supabase
                .from('site_settings')
                .select('language_code, canonical_url')
                .in('language_code', codes);

            if (settingsError) {
                return normalizedLangs.map((l) => ({
                    ...l,
                    canonicalUrl: '',
                }));
            }

            const canonicalMap = new Map<string, string>();
            for (const row of (settings || [])) {
                const code = String((row as any).language_code || '').trim();
                if (!code) continue;
                canonicalMap.set(code, String((row as any).canonical_url || '').trim());
            }

            const result = normalizedLangs.map((l) => ({
                ...l,
                canonicalUrl: canonicalMap.get(l.code) || '',
            }));

            result.sort((a, b) => {
                if (a.isDefault !== b.isDefault) return a.isDefault ? -1 : 1;
                return a.code.localeCompare(b.code);
            });

            return result;
        });
    },

    async getNavigationItems(lang: string): Promise<NavigationItem[]> {
        return withCache(`nav_${lang}`, CACHE_TTL.NAV, async () => {
            const [{ data: menuData, error: menuError }, { data, error }] = await Promise.all([
              supabase
                .from('navigation_menus')
                .select('id, code'),
              supabase
                .from('navigation_items')
                .select('*')
                .eq('language_code', lang)
                .eq('is_active', true)
                .order('order_index', { ascending: true })
            ]);

            if (menuError) {
                console.error('Error fetching navigation menus:', menuError);
            }
            if (error) {
                console.error('Error fetching navigation items:', error);
                return [];
            }
            const menuCodeById = new Map(
                (menuData || []).map((menu: any) => [String(menu.id), String(menu.code || '')])
            );
            const items = (data || []).map((item: any) => ({
                ...item,
                menu_code: menuCodeById.get(String(item.menu_id)) || '',
            }));
            const menuRank = (code: string) => code === 'sidebar_main' ? 0 : code === 'top_navbar' ? 2 : 1;
            return items.sort((a: any, b: any) => {
                const rank = menuRank(a.menu_code).valueOf() - menuRank(b.menu_code).valueOf();
                return rank || ((a.order_index || 0) - (b.order_index || 0));
            });
        });
    },

    async getNewsItems(lang: string, category?: string | string[] | null, limit = 50): Promise<NewsItem[]> {
        const cacheKey = `news_${lang}_${Array.isArray(category) ? category.join(',') : (category || 'home')}_${limit}`;
        return withCache(cacheKey, CACHE_TTL.NEWS, async () => {
            const isHomeFeed = !category || category === 'home';
            const publishedAtLimit = new Date().toISOString();
            const selectColumns = `id, created_at, published_at, updated_at, publisher_id, title, summary, category, type, thumbnail_url, thumbnail_alt, media_url, likes_count, dislikes_count, comments_count, shares_count, views_count, saves_count, slug, status, seo_title, seo_description, keywords, language_code, is_pinned, show_in_manset, fact_checked, schema_type, card_data, items, faq_data, profiles:publisher_id (id, username, full_name, avatar_url, role)`;
            const createPublishedQuery = () => supabase
                .from('posts')
                .select(selectColumns)
                .eq('status', 'published')
                .eq('language_code', lang)
                .or(`published_at.lte.${publishedAtLimit},published_at.is.null`);

            let query = createPublishedQuery()
                .order('is_pinned', { ascending: false })
                .order('published_at', { ascending: false });

            if (category && category !== 'home') {
                if (Array.isArray(category)) {
                    // Filter by multiple categories (case-insensitive via ilike or array in)
                    // For broad root clicks, we want exact matches for the root or any children slugs provided
                    query = query.in('category', category);
                } else {
                    const terms = getCategoryTerms(category);
                    const categoryConditions = [
                        `category.eq.${category}`,
                        `category.eq.${category.toLocaleLowerCase('tr-TR')}`,
                        `category.ilike.%${category}%`,
                    ];
                    query = query.or([...categoryConditions, ...getTypeFilterConditions(terms)].join(','));
                }
            }

            const { data, error } = await query.limit(limit);

            if (error) {
                console.error('Error fetching news items:', error);
                return [];
            }

            let rows = data || [];

            if (isHomeFeed) {
                const { data: mansetRows, error: mansetError } = await createPublishedQuery()
                    .eq('show_in_manset', true)
                    .order('published_at', { ascending: false })
                    .limit(20);

                if (!mansetError && mansetRows?.length) {
                    const seen = new Set<string>();
                    rows = [...mansetRows, ...rows].filter((post: any) => {
                        const id = String(post?.id || '');
                        if (!id || seen.has(id)) return false;
                        seen.add(id);
                        return true;
                    });
                }
            }

            return rows.map((post: any) => this.mapPost(post));
        });
    },

    async getNewsBySlug(slugOrId: string): Promise<NewsItem | null> {
        const normalized = String(slugOrId || '').trim();
        if (!normalized) return null;

        const selectClause = `*, profiles:publisher_id (id, username, full_name, avatar_url, role)`;

        // 1) Try by slug
        const slugRes = await supabase
            .from('posts')
            .select(selectClause)
            .eq('slug', normalized)
            .maybeSingle();

        if (slugRes.data) return this.mapPost(slugRes.data);

        // 2) Fallback to numeric id
        if (/^[0-9]+$/.test(normalized)) {
            const idRes = await supabase
                .from('posts')
                .select(selectClause)
                .eq('id', normalized)
                .maybeSingle();
            if (idRes.data) return this.mapPost(idRes.data);
        }

        return null;
    },

    mapPost(post: any): NewsItem {
        const rawPostType = typeof post?.type === 'string' ? post.type : '';
        const cardData = (post?.card_data && typeof post.card_data === 'object') ? post.card_data : {};
        const typeFromCard = (cardData as any)?.type;
        const resolvedType = normalizeNewsType(typeFromCard ?? rawPostType);

        const itemsRaw = post?.items ?? (cardData as any)?.items;
        const itemsArray = Array.isArray(itemsRaw) ? itemsRaw : [];
        const faqFromItems = itemsArray.find((item: any) => item?.type === 'faq' && item?.faqData)?.faqData;

        const baseSource = post?.profiles?.full_name || post?.profiles?.username || 'Pateez';
        const baseAuthor = post?.profiles?.full_name || post?.profiles?.username || 'Pateez';

        const merged: any = {
            ...(cardData as any),
            id: String(post?.id ?? ''),
            type: resolvedType,
            postType: rawPostType,
            title: (cardData as any)?.title ?? post?.title ?? '',
            summary: (cardData as any)?.summary ?? post?.summary ?? '',
            content: (cardData as any)?.content ?? post?.content ?? '',
            category: (cardData as any)?.category ?? post?.category ?? '',
            source: (cardData as any)?.source ?? baseSource,
            author: (cardData as any)?.author ?? baseAuthor,
            timestamp: post?.published_at || post?.created_at,
            mediaUrl: (cardData as any)?.mediaUrl ?? post?.media_url ?? '',
            thumbnail: (cardData as any)?.thumbnail ?? post?.thumbnail_url ?? '',
            thumbnailAlt: post?.thumbnail_alt ?? (cardData as any)?.thumbnailAlt,
            mansetImageUrl:
                (cardData as any)?.mansetImageUrl ??
                (cardData as any)?.featuredImageUrl ??
                (cardData as any)?.headlineImageUrl ??
                '',
            likes: post?.likes_count ?? (cardData as any)?.likes ?? 0,
            dislikes: post?.dislikes_count ?? (cardData as any)?.dislikes ?? 0,
            comments: post?.comments_count ?? (cardData as any)?.comments ?? 0,
            shares: post?.shares_count ?? (cardData as any)?.shares ?? 0,
            views: post?.views_count ?? (cardData as any)?.views ?? 0,
            saves: post?.saves_count ?? (cardData as any)?.saves ?? 0,
            seoTitle: post?.seo_title ?? (cardData as any)?.seoTitle,
            seoDescription: post?.seo_description ?? (cardData as any)?.seoDescription,
            keywords: post?.keywords ?? (cardData as any)?.keywords,
            slug: post?.slug ?? (cardData as any)?.slug,
            factChecked: post?.fact_checked ?? (cardData as any)?.factChecked,
            schemaType: post?.schema_type ?? (cardData as any)?.schemaType,
            faqData: post?.faq_data ?? (cardData as any)?.faqData ?? faqFromItems,
            items: itemsRaw,
            sourceAvatar: post?.profiles?.avatar_url || (cardData as any)?.sourceAvatar || '',
            isPinned: post?.is_pinned ?? (cardData as any)?.isPinned ?? false,
            isManset: post?.show_in_manset ?? (cardData as any)?.isManset ?? false,
            publisherId: post?.publisher_id ?? (cardData as any)?.publisherId,
        };

        const items = Array.isArray(merged.items) ? merged.items : [];
        const homepageItem = items.find((item: any) => item && item.showOnHomepage === true);

        // If an item is flagged for homepage rendering, use that item's type and payload
        // so the feed card shows the selected block (video/poll/slider/etc.).
        if (homepageItem) {
            const homepageTypeRaw = String(homepageItem?.type ?? '').trim();
            const homepageType = homepageTypeRaw.toLowerCase() === 'slider'
                ? NewsType.GALLERY
                : normalizeNewsType(homepageTypeRaw);

            const homepageDescription = typeof homepageItem?.description === 'string' ? homepageItem.description : '';
            const homepageMediaUrl = typeof homepageItem?.mediaUrl === 'string' ? homepageItem.mediaUrl : '';
            const homepageAlt = typeof homepageItem?.altText === 'string' ? homepageItem.altText : '';

            merged.type = homepageType;

            if (homepageType === NewsType.POLL || homepageType === NewsType.VS) {
                (merged as any).blockTitle = typeof homepageItem?.title === 'string' ? homepageItem.title : '';
                (merged as any).blockDescription = homepageDescription || '';
                if (Array.isArray((homepageItem as any)?.options)) merged.options = (homepageItem as any).options;
                if (typeof (homepageItem as any)?.totalVotes === 'number') merged.totalVotes = (homepageItem as any).totalVotes;
                if (homepageType === NewsType.POLL) {
                    if (typeof (homepageItem as any)?.isImagePoll === 'boolean') merged.isImagePoll = (homepageItem as any).isImagePoll;
                    if ((homepageItem as any)?.pollColumns === 2 || (homepageItem as any)?.pollColumns === 3) merged.pollColumns = (homepageItem as any).pollColumns;
                }
                if (homepageType === NewsType.VS && homepageMediaUrl) {
                    merged.thumbnail = homepageMediaUrl;
                }
            } else if (homepageDescription.trim()) {
                merged.summary = homepageDescription;
            }

            if (homepageType === NewsType.VIDEO || homepageType === NewsType.AUDIO || homepageType === NewsType.EMBED) {
                if (homepageMediaUrl) merged.mediaUrl = homepageMediaUrl;
            }

            if (homepageType === NewsType.GALLERY) {
                const mediaUrls = Array.isArray((homepageItem as any)?.mediaUrls)
                    ? (homepageItem as any).mediaUrls.filter((u: any) => typeof u === 'string' && u.trim())
                    : [];
                if (mediaUrls.length > 0) {
                    merged.mediaList = mediaUrls;
                }
            }

            if (homepageType === NewsType.IMAGE) {
                if (homepageMediaUrl) {
                    merged.thumbnail = homepageMediaUrl;
                    if (homepageAlt) merged.thumbnailAlt = homepageAlt;
                }
            }
        }

        const coverFromItems = items.find((item: any) =>
            item &&
            item.type === 'image' &&
            typeof item.mediaUrl === 'string' &&
            item.mediaUrl &&
            (item.showOnHomepage || item.orderNumber === 1)
        );

        const savedCoverThumbnail = typeof post?.thumbnail_url === 'string' && post.thumbnail_url.trim()
            ? post.thumbnail_url
            : '';
        merged.coverThumbnail =
            savedCoverThumbnail ||
            (cardData as any)?.coverThumbnail ||
            merged.thumbnail ||
            coverFromItems?.mediaUrl;

        if (resolvedType === NewsType.GALLERY && (!merged.mediaList || merged.mediaList.length === 0)) {
            const slider = items.find((item: any) => item?.type === 'slider' && Array.isArray(item?.mediaUrls));
            if (slider?.mediaUrls) merged.mediaList = slider.mediaUrls;
        }

        if (resolvedType === NewsType.VIDEO && !merged.mediaUrl) {
            const video = items.find((item: any) => item?.type === 'video' && typeof item?.mediaUrl === 'string');
            if (video?.mediaUrl) merged.mediaUrl = video.mediaUrl;
        }

        if (resolvedType === NewsType.AUDIO && !merged.mediaUrl) {
            const audio = items.find((item: any) => item?.type === 'audio' && typeof item?.mediaUrl === 'string');
            if (audio?.mediaUrl) merged.mediaUrl = audio.mediaUrl;
        }

        return normalizeStoredTextPayload(merged) as NewsItem;
    }
};
