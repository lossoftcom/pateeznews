import { dataService as sharedDataService } from './dataService';
import { ensureAppSchema } from '@/lib/server/appDb';
import { dbQuery } from '@/lib/server/neonDb';
import type { NewsItem } from '@/types';
import { slugify } from '@/utils/helpers';

const parsePayload = (value: unknown) => {
    if (!value) return null;
    return typeof value === 'string' ? JSON.parse(value) : value;
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
    offset = 0
): Promise<CategoryNewsPage> => {
    const terms = getCategoryTerms(category);
    const typeAliases = getCategoryTypeAliases(terms);
    const safeLimit = Math.min(Math.max(Number(limit) || 12, 1), 24);
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
                'role', pr.role
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

const getLiveCategoryNewsItems = async (lang: string, category: string | string[], limit = 50): Promise<NewsItem[]> => {
    const page = await getLiveCategoryNewsPage(lang, category, limit, 0);
    return page.items;
};

export const dataService = {
    ...sharedDataService,

    async getNewsItems(lang: string, category?: string | string[] | null, limit = 50): Promise<NewsItem[]> {
        await ensureAppSchema();
        if (category && category !== 'home') {
            return getLiveCategoryNewsItems(lang, category, limit);
        }
        return sharedDataService.getNewsItems(lang, category, limit);
    },

    async getCategoryNewsPage(lang: string, category: string | string[], limit = 12, offset = 0): Promise<CategoryNewsPage> {
        await ensureAppSchema();
        return getLiveCategoryNewsPage(lang, category, limit, offset);
    },

    async getSidebarSnapshot(lang: string): Promise<any | null> {
        try {
            await ensureAppSchema();

            const languageCode = String(lang || 'tr').trim() || 'tr';
            const [sidebarResult, pharmacyResult, deathNoticeResult] = await Promise.all([
                dbQuery<{ payload: any }>(
                    `SELECT payload
                     FROM public.app_cache
                     WHERE key = $1
                     LIMIT 1`,
                    [`sidebar:${languageCode}`]
                ),
                dbQuery<{ payload: any }>(
                    `SELECT payload
                     FROM public.app_cache
                     WHERE key = $1
                       AND expires_at > now()
                     LIMIT 1`,
                    ['duty_pharmacies:nigde']
                ),
                dbQuery<{ payload: any }>(
                    `SELECT payload
                     FROM public.app_cache
                     WHERE key = $1
                       AND expires_at > now()
                     LIMIT 1`,
                    ['death_notices:nigde']
                ),
            ]);

            const sidebarPayload = parsePayload(sidebarResult.rows[0]?.payload);
            const pharmacyPayload = parsePayload(pharmacyResult.rows[0]?.payload);
            const deathNoticePayload = parsePayload(deathNoticeResult.rows[0]?.payload);

            if (!sidebarPayload && !pharmacyPayload && !deathNoticePayload) return null;
            return {
                ...(sidebarPayload || {}),
                dutyPharmacies: pharmacyPayload || null,
                deathNotices: deathNoticePayload || null,
            };
        } catch {
            return null;
        }
    },
};
