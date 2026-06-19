import { dataService as sharedDataService } from './dataService';
import { ensureAppSchema } from '@/lib/server/appDb';
import { dbQuery } from '@/lib/server/supabaseDb';
import type { NavigationItem, NewsItem, SiteFont, SiteSettings } from '@/types';
import { slugify } from '@/utils/helpers';

const parsePayload = (value: unknown) => {
    if (!value) return null;
    return typeof value === 'string' ? JSON.parse(value) : value;
};

const SIDEBAR_SERVICE_TIMEZONE = 'Europe/Istanbul';

const getSidebarServiceDateKey = (date = new Date()) => {
    const parts = new Intl.DateTimeFormat('en-CA', {
        timeZone: SIDEBAR_SERVICE_TIMEZONE,
        year: 'numeric',
        month: '2-digit',
        day: '2-digit',
    }).formatToParts(date);
    const pick = (type: string) => parts.find((part) => part.type === type)?.value || '';
    return `${pick('year')}-${pick('month')}-${pick('day')}`;
};

const isCurrentNigdeServicePayload = (payload: any, serviceDate: string) => (
    payload?.citySlug === 'nigde' &&
    payload?.serviceDate === serviceDate
);

const usableSidebarServicePayload = (payload: any, expiresAt: unknown, serviceDate: string) => {
    if (!payload) return null;
    const expires = expiresAt ? new Date(String(expiresAt)).getTime() : 0;
    if (expires > Date.now()) return payload;
    return isCurrentNigdeServicePayload(payload, serviceDate) ? payload : null;
};

const CATEGORY_TYPE_ALIASES: Record<string, string[]> = {
    anket: ['poll'],
    anketler: ['poll'],
    poll: ['poll'],
    polls: ['poll'],
    test: ['quiz'],
    testler: ['quiz'],
    quiz: ['quiz'],
    quizzes: ['quiz'],
    video: ['video'],
    videolar: ['video'],
    videos: ['video'],
    liste: ['contents'],
    listeler: ['contents'],
    icindekiler: ['contents'],
    'içindekiler': ['contents'],
    contents: ['contents'],
    content: ['contents'],
    'table-of-contents': ['contents'],
    toc: ['contents'],
    tarif: ['recipe'],
    tarifler: ['recipe'],
    recipe: ['recipe'],
    recipes: ['recipe'],
    etkinlik: ['event'],
    etkinlikler: ['event'],
    event: ['event'],
    events: ['event'],
    'kose-yazisi': ['opinion'],
    'kose-yazilari': ['opinion'],
    'köşe-yazısı': ['opinion'],
    'köşe-yazıları': ['opinion'],
    'kose yazisi': ['opinion'],
    'kose yazilari': ['opinion'],
    'köşe yazısı': ['opinion'],
    'köşe yazıları': ['opinion'],
    opinion: ['opinion'],
    opinions: ['opinion'],
    'yemek-tarifi': ['recipe'],
    'yemek tarifi': ['recipe'],
    yemek: ['recipe'],
    yemekler: ['recipe'],
    food: ['recipe'],
    foods: ['recipe'],
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

const getCategoryTypeAliases = (terms: string[]) => {
    return Array.from(new Set(
        terms.flatMap((term) => CATEGORY_TYPE_ALIASES[slugify(term)] || [])
    ));
};

const WEEKLY_TREND_VALUES = new Set([
    'weekly_trends',
    'weekly_likes',
    'weekly_comments',
    'weekly_shares',
    'weekly_reads',
]);

const normalizeWeeklyTrendValue = (value: string) => {
    const normalized = String(value || '').trim().toLowerCase().replace(/-/g, '_');
    return WEEKLY_TREND_VALUES.has(normalized) ? normalized : 'weekly_trends';
};

const getWeeklyTrendScoreSql = (trendValue: string) => {
    switch (normalizeWeeklyTrendValue(trendValue)) {
        case 'weekly_likes':
            return 'COALESCE(likes_count, 0)';
        case 'weekly_comments':
            return 'COALESCE(comments_count, 0)';
        case 'weekly_shares':
            return 'COALESCE(shares_count, 0)';
        case 'weekly_reads':
            return 'COALESCE(views_count, 0)';
        default:
            return `(
                ln(1 + COALESCE(views_count, 0)) +
                ln(1 + COALESCE(likes_count, 0)) * 2.4 +
                ln(1 + COALESCE(comments_count, 0)) * 2.2 +
                ln(1 + COALESCE(shares_count, 0)) * 2.8 +
                ln(1 + COALESCE(saves_count, 0)) * 2.5 -
                ln(1 + COALESCE(dislikes_count, 0)) * 1.1
            )`;
    }
};

const SITE_SETTINGS_SELECT = [
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
    'yandex_verification_code',
    'indexnow_key',
    'twitter_username',
    'fb_app_id',
    'social_whatsapp_url',
    'social_telegram_url',
    'social_instagram_url',
    'social_facebook_url',
    'social_x_url',
    'social_youtube_url',
    'social_tiktok_url',
    'social_linkedin_url',
    'social_pinterest_url',
    'social_discord_url',
    'social_auth_google_enabled',
    'social_auth_apple_enabled',
    'social_auth_facebook_enabled',
    'social_auth_x_enabled',
    'social_auth_redirect_scheme',
    'social_auth_redirect_host',
    'organization_legal_name',
    'organization_phone',
    'organization_address',
    'contact_phone',
    'contact_city',
    'contact_address',
    'contact_location_url',
    'contact_whatsapp_url',
    'contact_telegram_url',
    'contact_email_info',
    'contact_email_support',
    'contact_email_news',
    'contact_email_ads',
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
    'site_primary_font',
    'site_title_font',
    'site_content_font',
    'site_font_sizes',
    'content_post_url_structure',
    'content_bulk_post_upload_enabled',
    'content_delete_media_with_post_enabled',
    'content_audio_download_enabled',
    'content_comment_system_enabled',
    'content_comment_approval_enabled',
    'content_emoji_reactions_enabled',
    'content_featured_show_news_info',
    'content_show_post_author',
    'content_show_post_date',
    'content_show_post_view_count',
    'content_require_new_post_approval',
    'content_require_edited_post_approval',
    'content_redirect_rss_posts',
    'content_popular_post_limit',
    'content_related_post_limit',
].join(', ');

const POST_FEED_SELECT = `
            p.id,
            p.created_at,
            p.published_at,
            p.updated_at,
            p.publisher_id,
            p.title,
            p.summary,
            p.category,
            p.type,
            p.thumbnail_url,
            p.thumbnail_alt,
            p.media_url,
            p.likes_count,
            p.dislikes_count,
            p.comments_count,
            p.shares_count,
            p.views_count,
            p.saves_count,
            p.slug,
            p.status,
            p.seo_title,
            p.seo_description,
            p.keywords,
            p.language_code,
            p.is_pinned,
            p.show_in_manset,
            p.fact_checked,
            p.schema_type,
            p.card_data,
            p.items,
            p.faq_data,
            json_build_object(
                'id', pr.id,
                'username', pr.username,
                'full_name', pr.full_name,
                'avatar_url', pr.avatar_url,
                'role', pr.role,
                'about_me', pr.about_me,
                'expertise', pr.expertise
            ) AS profiles`;

const POST_DETAIL_SELECT = `
            ${POST_FEED_SELECT},
            p.content`;

const SERVER_CACHE_TTL = {
    SETTINGS: 1000 * 60,
    NAV: 1000 * 60 * 5,
    NEWS: 1000 * 30,
    SIDEBAR: 1000 * 30,
};

const serverCache: Record<string, { data: any; expiry: number }> = {};
const serverInflight: Record<string, Promise<any> | undefined> = {};

const withServerCache = async <T>(key: string, ttl: number, fetcher: () => Promise<T>): Promise<T> => {
    const now = Date.now();
    const cached = serverCache[key];
    if (cached && cached.expiry > now) return cached.data as T;
    if (serverInflight[key]) return serverInflight[key] as Promise<T>;

    const promise = (async () => {
        try {
            const data = await fetcher();
            serverCache[key] = { data, expiry: Date.now() + ttl };
            return data;
        } finally {
            delete serverInflight[key];
        }
    })();

    serverInflight[key] = promise;
    return promise;
};

export const invalidateServerDataCache = (predicate?: (key: string) => boolean) => {
    for (const key of Object.keys(serverCache)) {
        if (!predicate || predicate(key)) delete serverCache[key];
    }
    for (const key of Object.keys(serverInflight)) {
        if (!predicate || predicate(key)) delete serverInflight[key];
    }
};

export const invalidateServerSiteSettingsCache = (lang?: string) => {
    const normalizedLang = String(lang || '').trim().toLowerCase().replace(/_/g, '-');
    invalidateServerDataCache((key) => {
        if (key === 'seo_alternates' || key === 'site_fonts' || key === 'default_language') return true;
        if (!key.startsWith('settings_') && !key.startsWith('font_settings_')) return false;
        return !normalizedLang || key.endsWith(`_${normalizedLang}`);
    });
};

const normalizeLanguageCode = (lang: string) =>
    String(lang || 'tr').trim().toLowerCase().replace(/_/g, '-') || 'tr';

const getDefaultLanguageCode = async () => {
    return withServerCache('default_language', SERVER_CACHE_TTL.NAV, async () => {
        const result = await dbQuery<{ code: string }>(
            `SELECT code
             FROM public.languages
             WHERE status = 'active' AND is_default = true
             ORDER BY code
             LIMIT 1`
        );
        return String(result.rows[0]?.code || 'tr').trim() || 'tr';
    });
};

const getLiveSiteSettings = async (lang: string): Promise<SiteSettings | null> => {
    const languageCode = normalizeLanguageCode(lang);
    return withServerCache(`settings_${languageCode}`, SERVER_CACHE_TTL.SETTINGS, async () => {
        await ensureAppSchema();
        const fetchSettings = async (code: string) => {
            const result = await dbQuery<SiteSettings>(
                `SELECT ${SITE_SETTINGS_SELECT}
                 FROM public.site_settings
                 WHERE language_code = $1
                 LIMIT 1`,
                [code]
            );
            return result.rows[0] || null;
        };

        const exact = await fetchSettings(languageCode);
        if (exact) return exact;

        const defaultLangCode = await getDefaultLanguageCode();
        if (languageCode !== defaultLangCode) {
            const fallback = await fetchSettings(defaultLangCode);
            if (fallback) return fallback;
        }
        if (languageCode !== 'tr' && defaultLangCode !== 'tr') {
            return await fetchSettings('tr');
        }
        return null;
    });
};

const getLiveSiteFonts = async (): Promise<SiteFont[]> => {
    return withServerCache('site_fonts', SERVER_CACHE_TTL.SETTINGS, async () => {
        await ensureAppSchema();
        const result = await dbQuery<SiteFont>(
            `SELECT id, name, family, type, source, web_font_path, flutter_family,
                    fallback_stack, font_files, is_active, sort_order
             FROM public.site_fonts
             WHERE is_active = true
             ORDER BY sort_order DESC, id DESC`
        );
        return result.rows || [];
    });
};

const getLiveSeoAlternates = async (): Promise<{ code: string; canonicalUrl: string; isDefault: boolean; name: string; direction: 'ltr' | 'rtl'; flagCode: string }[]> => {
    return withServerCache('seo_alternates', SERVER_CACHE_TTL.SETTINGS, async () => {
        await ensureAppSchema();
        const result = await dbQuery<any>(
        `SELECT l.code,
                l.name,
                l.direction,
                l.flag_code,
                l.is_default,
                COALESCE(s.canonical_url, '') AS canonical_url
         FROM public.languages l
         LEFT JOIN public.site_settings s ON s.language_code = l.code
         WHERE l.status = 'active'
         ORDER BY l.is_default DESC, l.code ASC`
    );

    const rows = result.rows || [];
    if (!rows.length) {
        return [{ code: 'tr', name: 'Türkçe', direction: 'ltr', flagCode: 'tr', isDefault: true, canonicalUrl: '' }];
    }

    const alternates = rows.map((row: any) => ({
        code: String(row.code || '').trim(),
        name: String(row.name || '').trim() || String(row.code || '').toUpperCase(),
        direction: String(row.direction || '').trim() === 'rtl' ? 'rtl' as const : 'ltr' as const,
        flagCode: String(row.flag_code || '').trim() || String(row.code || '').trim(),
        isDefault: !!row.is_default,
        canonicalUrl: String(row.canonical_url || '').trim(),
    })).filter((entry: any) => !!entry.code);

    if (alternates.length > 0 && !alternates.some((entry) => entry.isDefault)) {
        alternates[0].isDefault = true;
    }
        return alternates;
    });
};

export interface FooterPageEntry {
    id: string;
    title: string;
    slug: string;
    pageGroup: string;
    pageType: string;
    menuOrder: number;
}

const getLiveFooterPages = async (lang: string): Promise<FooterPageEntry[]> => {
    const languageCode = normalizeLanguageCode(lang);
    return withServerCache(`footer_pages_${languageCode}`, SERVER_CACHE_TTL.NAV, async () => {
        await ensureAppSchema();
        const result = await dbQuery<any>(
            `SELECT
                id,
                title,
                slug,
                page_group,
                page_type,
                menu_order
             FROM public.pages
             WHERE language_code = $1
               AND status = 'active'
               AND registered_only IS NOT TRUE
             ORDER BY COALESCE(NULLIF(page_group, ''), 'Kurumsal') ASC,
                      menu_order ASC NULLS LAST,
                      title ASC`,
            [languageCode]
        );

        return (result.rows || [])
            .map((row) => ({
                id: String(row.id || ''),
                title: String(row.title || '').trim(),
                slug: String(row.slug || '').trim(),
                pageGroup: String(row.page_group || '').trim(),
                pageType: String(row.page_type || '').trim(),
                menuOrder: Number.isFinite(Number(row.menu_order)) ? Number(row.menu_order) : 0,
            }))
            .filter((page) => page.id && page.title && page.slug);
    });
};

export interface CategoryNewsPage {
    items: NewsItem[];
    total: number;
    totalViews: number;
    nextOffset: number;
    hasMore: boolean;
    limit: number;
    offset: number;
}

const getLiveCategoryNewsPage = async (
    lang: string,
    category: string | string[],
    limit = 12,
    offset = 0,
    options: { includeTypeAliases?: boolean } = {}
): Promise<CategoryNewsPage> => {
    const terms = getCategoryTerms(category);
    const typeAliases = options.includeTypeAliases === false
        ? []
        : getCategoryTypeAliases(terms);
    const safeLimit = Math.min(Math.max(Number(limit) || 12, 1), 50);
    const safeOffset = Math.max(Number(offset) || 0, 0);

    if (terms.length === 0) {
        return {
            items: [],
            total: 0,
            totalViews: 0,
            nextOffset: safeOffset,
            hasMore: false,
            limit: safeLimit,
            offset: safeOffset,
        };
    }

    const exactTerms = terms.map((term) => term.toLocaleLowerCase('tr-TR'));
    const likeTerms = terms.map((term) => `%${term}%`);

    const result = await dbQuery<any>(
        `SELECT
            p.id,
            p.created_at,
            p.published_at,
            p.updated_at,
            p.publisher_id,
            p.title,
            p.summary,
            p.content,
            p.category,
            p.type,
            p.thumbnail_url,
            p.thumbnail_alt,
            p.media_url,
            p.likes_count,
            p.dislikes_count,
            p.comments_count,
            p.shares_count,
            p.views_count,
            p.saves_count,
            p.slug,
            p.status,
            p.seo_title,
            p.seo_description,
            p.keywords,
            p.language_code,
            p.is_pinned,
            p.show_in_manset,
            p.fact_checked,
            p.schema_type,
            p.card_data,
            p.items,
            p.faq_data,
            COUNT(*) OVER()::int AS total_count,
            COALESCE(SUM(COALESCE(p.views_count, 0)) OVER(), 0)::int AS total_views,
            json_build_object(
                'id', pr.id,
                'username', pr.username,
                'full_name', pr.full_name,
                'avatar_url', pr.avatar_url,
                'role', pr.role,
                'about_me', pr.about_me,
                'expertise', pr.expertise
            ) AS profiles
         FROM public.posts p
         LEFT JOIN public.profiles pr ON pr.id = p.publisher_id
         WHERE p.status = 'published'
           AND p.language_code = $1
           AND (p.published_at <= now() OR p.published_at IS NULL)
           AND (
                lower(coalesce(p.category, '')) = ANY($2::text[])
                OR coalesce(p.category, '') ILIKE ANY($3::text[])
                OR lower(coalesce(p.type, '')) = ANY($4::text[])
                OR lower(coalesce(p.card_data->>'type', '')) = ANY($4::text[])
                OR EXISTS (
                    SELECT 1
                    FROM jsonb_array_elements_text(
                        CASE
                            WHEN jsonb_typeof(p.card_data->'categoryPath') = 'array' THEN p.card_data->'categoryPath'
                            ELSE '[]'::jsonb
                        END
                    ) AS cat_path
                    WHERE lower(cat_path) = ANY($2::text[])
                )
                OR EXISTS (
                    SELECT 1
                    FROM jsonb_array_elements(
                        CASE
                            WHEN jsonb_typeof(p.items) = 'array' THEN p.items
                            ELSE '[]'::jsonb
                        END
                    ) AS item
                    WHERE lower(coalesce(item->>'type', '')) = ANY($4::text[])
                )
           )
         ORDER BY p.published_at DESC NULLS LAST, p.created_at DESC NULLS LAST, p.id DESC
         LIMIT $5 OFFSET $6`,
        [lang, exactTerms, likeTerms, typeAliases, safeLimit, safeOffset]
    );

    const rows = result.rows || [];
    const total = Number(rows[0]?.total_count || 0);
    const totalViews = Number(rows[0]?.total_views || 0);
    const items = rows.map((post: any) => sharedDataService.mapPost(post));
    const nextOffset = safeOffset + items.length;

    return {
        items,
        total,
        totalViews,
        nextOffset,
        hasMore: nextOffset < total,
        limit: safeLimit,
        offset: safeOffset,
    };
};

const getLiveWeeklyTrendNewsPage = async (
    lang: string,
    trendValue: string,
    limit = 12,
    offset = 0
): Promise<CategoryNewsPage> => {
    const languageCode = normalizeLanguageCode(lang);
    const safeLimit = Math.min(Math.max(Number(limit) || 12, 1), 50);
    const safeOffset = Math.max(Number(offset) || 0, 0);
    const scoreSql = getWeeklyTrendScoreSql(trendValue);

    const result = await dbQuery<any>(
        `WITH base AS (
            SELECT
                ${POST_FEED_SELECT},
                COALESCE(p.published_at, p.created_at) AS trend_time
             FROM public.posts p
             LEFT JOIN public.profiles pr ON pr.id = p.publisher_id
             WHERE p.status = 'published'
               AND p.language_code = $1
               AND (p.published_at <= now() OR p.published_at IS NULL)
        ),
        weekly AS (
            SELECT *
            FROM base
            WHERE trend_time >= now() - interval '7 days'
        ),
        scoped AS (
            SELECT *
            FROM weekly
            UNION ALL
            SELECT *
            FROM base
            WHERE NOT EXISTS (SELECT 1 FROM weekly)
        ),
        ranked AS (
            SELECT
                scoped.*,
                COUNT(*) OVER()::int AS total_count,
                COALESCE(SUM(COALESCE(views_count, 0)) OVER(), 0)::int AS total_views,
                ${scoreSql} AS trend_score
            FROM scoped
        )
        SELECT *
        FROM ranked
        ORDER BY trend_score DESC, trend_time DESC NULLS LAST, id DESC
        LIMIT $2 OFFSET $3`,
        [languageCode, safeLimit, safeOffset]
    );

    const rows = result.rows || [];
    const total = Number(rows[0]?.total_count || 0);
    const totalViews = Number(rows[0]?.total_views || 0);
    const items = rows.map((post: any) => sharedDataService.mapPost(post));
    const nextOffset = safeOffset + items.length;

    return {
        items,
        total,
        totalViews,
        nextOffset,
        hasMore: nextOffset < total,
        limit: safeLimit,
        offset: safeOffset,
    };
};

const getLiveCategoryNewsItems = async (lang: string, category: string | string[], limit = 50): Promise<NewsItem[]> => {
    const page = await getLiveCategoryNewsPage(lang, category, limit, 0);
    return page.items;
};

const getLiveNavigationItems = async (lang: string): Promise<NavigationItem[]> => {
    const languageCode = normalizeLanguageCode(lang);
    return withServerCache(`nav_${languageCode}`, SERVER_CACHE_TTL.NAV, async () => {
        await ensureAppSchema();
        const result = await dbQuery<NavigationItem>(
            `SELECT
                ni.id,
                ni.menu_id,
                nm.code AS menu_code,
                ni.parent_id,
                ni.label,
                ni.type,
                ni.value,
                ni.icon,
                ni.image_url,
                ni.order_index,
                ni.is_active,
                ni.language_code
             FROM public.navigation_items ni
             LEFT JOIN public.navigation_menus nm ON nm.id = ni.menu_id
             WHERE ni.language_code = $1
               AND ni.is_active = true
             ORDER BY
                CASE nm.code
                    WHEN 'sidebar_main' THEN 0
                    WHEN 'top_navbar' THEN 2
                    ELSE 1
                END,
                ni.order_index ASC,
                ni.id ASC`,
            [languageCode]
        );
        return result.rows || [];
    });
};

const getLiveHomeNewsItems = async (lang: string, limit = 50): Promise<NewsItem[]> => {
    const languageCode = normalizeLanguageCode(lang);
    const safeLimit = Math.min(Math.max(Number(limit) || 50, 1), 100);

    const baseWhere = `p.status = 'published'
           AND p.language_code = $1
           AND (p.published_at <= now() OR p.published_at IS NULL)`;
    const baseFrom = `FROM public.posts p
         LEFT JOIN public.profiles pr ON pr.id = p.publisher_id
         WHERE ${baseWhere}`;
    const orderBy = `ORDER BY p.is_pinned DESC NULLS LAST,
                p.published_at DESC NULLS LAST,
                p.created_at DESC NULLS LAST,
                p.id DESC`;

    const [feedResult, mansetResult] = await Promise.all([
        dbQuery<any>(
            `SELECT ${POST_FEED_SELECT}
             ${baseFrom}
             ${orderBy}
             LIMIT $2`,
            [languageCode, safeLimit]
        ),
        dbQuery<any>(
            `SELECT ${POST_FEED_SELECT}
             ${baseFrom}
               AND p.show_in_manset = true
             ORDER BY p.published_at DESC NULLS LAST,
                p.created_at DESC NULLS LAST,
                p.id DESC
             LIMIT 20`,
            [languageCode]
        ),
    ]);

    let rows = feedResult.rows || [];
    if (mansetResult.rows?.length) {
        const seen = new Set<string>();
        rows = [...mansetResult.rows, ...rows].filter((post: any) => {
            const id = String(post?.id || '');
            if (!id || seen.has(id)) return false;
            seen.add(id);
            return true;
        });
    }

    return rows.map((post: any) => sharedDataService.mapPost(post));
};

const getLiveNewsItems = async (lang: string, category?: string | string[] | null, limit = 50): Promise<NewsItem[]> => {
    const languageCode = normalizeLanguageCode(lang);
    const categoryKey = Array.isArray(category)
        ? category.map((item) => String(item || '').trim()).join('|')
        : String(category || 'home').trim();
    const safeLimit = Math.min(Math.max(Number(limit) || 50, 1), 100);
    const cacheKey = `news_${languageCode}_${slugify(categoryKey || 'home')}_${safeLimit}`;

    return withServerCache(cacheKey, SERVER_CACHE_TTL.NEWS, async () => {
        await ensureAppSchema();
        if (category && category !== 'home') {
            return getLiveCategoryNewsItems(languageCode, category, safeLimit);
        }
        return getLiveHomeNewsItems(languageCode, safeLimit);
    });
};

const getLiveNewsBySlug = async (slugOrId: string): Promise<NewsItem | null> => {
    const normalized = String(slugOrId || '').trim();
    if (!normalized) return null;

    return withServerCache(`post_${normalized}`, SERVER_CACHE_TTL.NEWS, async () => {
        await ensureAppSchema();
        const slugResult = await dbQuery<any>(
            `SELECT ${POST_DETAIL_SELECT}
             FROM public.posts p
             LEFT JOIN public.profiles pr ON pr.id = p.publisher_id
             WHERE p.slug = $1
             LIMIT 1`,
            [normalized]
        );
        if (slugResult.rows[0]) return sharedDataService.mapPost(slugResult.rows[0]);

        if (/^[0-9]+$/.test(normalized)) {
            const idResult = await dbQuery<any>(
                `SELECT ${POST_DETAIL_SELECT}
                 FROM public.posts p
                 LEFT JOIN public.profiles pr ON pr.id = p.publisher_id
                 WHERE p.id::text = $1
                 LIMIT 1`,
                [normalized]
            );
            if (idResult.rows[0]) return sharedDataService.mapPost(idResult.rows[0]);
        }

        return null;
    });
};

export const dataService = {
    ...sharedDataService,

    async getSiteSettings(lang: string): Promise<SiteSettings | null> {
        return getLiveSiteSettings(lang);
    },

    async getSiteFonts(): Promise<SiteFont[]> {
        return getLiveSiteFonts();
    },

    async getSeoAlternates(): Promise<{ code: string; canonicalUrl: string; isDefault: boolean; name: string; direction: 'ltr' | 'rtl'; flagCode: string }[]> {
        return getLiveSeoAlternates();
    },

    async getFooterPages(lang: string): Promise<FooterPageEntry[]> {
        return getLiveFooterPages(lang);
    },

    async getNavigationItems(lang: string): Promise<NavigationItem[]> {
        return getLiveNavigationItems(lang);
    },

    async getNewsItems(lang: string, category?: string | string[] | null, limit = 50): Promise<NewsItem[]> {
        return getLiveNewsItems(lang, category, limit);
    },

    async getNewsBySlug(slugOrId: string): Promise<NewsItem | null> {
        return getLiveNewsBySlug(slugOrId);
    },

    async getCategoryNewsPage(
        lang: string,
        category: string | string[],
        limit = 12,
        offset = 0,
        options: { includeTypeAliases?: boolean } = {}
    ): Promise<CategoryNewsPage> {
        const languageCode = normalizeLanguageCode(lang);
        const categoryKey = Array.isArray(category)
            ? category.map((item) => String(item || '').trim()).join('|')
            : String(category || '').trim();
        const safeLimit = Math.min(Math.max(Number(limit) || 12, 1), 50);
        const safeOffset = Math.max(Number(offset) || 0, 0);
        const aliasMode = options.includeTypeAliases === false ? 'strict' : 'aliases';
        return withServerCache(
            `category_page_${aliasMode}_${languageCode}_${slugify(categoryKey)}_${safeLimit}_${safeOffset}`,
            SERVER_CACHE_TTL.NEWS,
            () => getLiveCategoryNewsPage(languageCode, category, safeLimit, safeOffset, options)
        );
    },

    async getWeeklyTrendNewsPage(
        lang: string,
        trendValue: string,
        limit = 12,
        offset = 0
    ): Promise<CategoryNewsPage> {
        const languageCode = normalizeLanguageCode(lang);
        const normalizedTrendValue = normalizeWeeklyTrendValue(trendValue);
        const safeLimit = Math.min(Math.max(Number(limit) || 12, 1), 50);
        const safeOffset = Math.max(Number(offset) || 0, 0);
        return withServerCache(
            `weekly_trend_page_${languageCode}_${normalizedTrendValue}_${safeLimit}_${safeOffset}`,
            SERVER_CACHE_TTL.NEWS,
            () => getLiveWeeklyTrendNewsPage(languageCode, normalizedTrendValue, safeLimit, safeOffset)
        );
    },

    async getSidebarSnapshot(lang: string): Promise<any | null> {
        const languageCode = normalizeLanguageCode(lang);
        return withServerCache(`sidebar_${languageCode}`, SERVER_CACHE_TTL.SIDEBAR, async () => {
            try {
                await ensureAppSchema();

                const cacheKeys = [
                    `sidebar:${languageCode}`,
                    'duty_pharmacies:nigde',
                    'death_notices:nigde',
                ];
                const cacheResult = await dbQuery<{ key: string; payload: any; expires_at: string }>(
                    `SELECT key, payload, expires_at
                     FROM public.app_cache
                     WHERE key = ANY($1::text[])`,
                    [cacheKeys]
                );
                const cacheRows = new Map(
                    (cacheResult.rows || []).map((row) => [String(row.key || ''), row])
                );

                const serviceDate = getSidebarServiceDateKey();
                const sidebarPayload = parsePayload(cacheRows.get(`sidebar:${languageCode}`)?.payload);
                const pharmacyRow = cacheRows.get('duty_pharmacies:nigde');
                const deathNoticeRow = cacheRows.get('death_notices:nigde');
                const pharmacyPayload = usableSidebarServicePayload(
                    parsePayload(pharmacyRow?.payload),
                    pharmacyRow?.expires_at,
                    serviceDate
                );
                const deathNoticePayload = usableSidebarServicePayload(
                    parsePayload(deathNoticeRow?.payload),
                    deathNoticeRow?.expires_at,
                    serviceDate
                );

                if (!sidebarPayload && !pharmacyPayload && !deathNoticePayload) return null;
                return {
                    ...(sidebarPayload || {}),
                    dutyPharmacies: pharmacyPayload || null,
                    deathNotices: deathNoticePayload || null,
                };
            } catch {
                return null;
            }
        });
    },
};
