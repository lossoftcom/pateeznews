import type { APIRoute } from 'astro';
import { adminError, adminJson, requireAdminRequest } from '@/lib/server/adminAuth';
import { purgeExpiredTrashPosts } from '@/lib/server/postTrash';
import { dbQuery } from '@/lib/server/supabaseDb';

const ALL = 'Tümü';
const MAX_PAGE_SIZE = 500;
const SORT_COLUMNS: Record<string, string> = {
  id: 'p.id',
  post: 'p.title',
  category: 'p.category',
  status: 'p.status',
  language: 'p.language_code',
  author: 'p.publisher_id',
  views: 'p.likes_count',
  comments: 'p.comments_count',
  date: 'p.created_at',
};

function escapeSearchTerm(value: unknown) {
  return String(value || '')
    .trim()
    .replaceAll('\\', '\\\\')
    .replaceAll('%', '\\%')
    .replaceAll('_', '\\_')
    .replaceAll(',', ' ')
    .replaceAll('\n', ' ')
    .replaceAll('\r', ' ');
}

function safePositiveInt(value: unknown, fallback: number) {
  const parsed = Number(value);
  if (!Number.isFinite(parsed) || parsed < 1) return fallback;
  return Math.floor(parsed);
}

export const POST: APIRoute = async ({ request }) => {
  try {
    await requireAdminRequest(request, 'posts_access');
    const body = await request.json().catch(() => ({}));
    const trashMode = body.trash === true;
    const cleanupLanguage = String(body.language || '').trim();
    await purgeExpiredTrashPosts(cleanupLanguage && cleanupLanguage !== ALL ? cleanupLanguage : 'tr').catch((error) => {
      console.warn('Expired trash cleanup skipped:', error);
    });

    const values: unknown[] = [];
    const where: string[] = [];
    const push = (value: unknown) => {
      values.push(value);
      return `$${values.length}`;
    };
    where.push(
      trashMode
        ? 'p.deleted_at IS NOT NULL'
        : `(p.deleted_at IS NULL AND COALESCE(p.status, '') <> 'trash')`
    );

    const search = escapeSearchTerm(body.search);
    if (search) {
      const pattern = push(`%${search}%`);
      where.push(`(
        p.title ILIKE ${pattern} ESCAPE '\\'
        OR p.slug ILIKE ${pattern} ESCAPE '\\'
        OR p.category ILIKE ${pattern} ESCAPE '\\'
        OR p.type ILIKE ${pattern} ESCAPE '\\'
        OR p.status ILIKE ${pattern} ESCAPE '\\'
        OR p.seo_title ILIKE ${pattern} ESCAPE '\\'
        OR p.seo_description ILIKE ${pattern} ESCAPE '\\'
        OR p.keywords ILIKE ${pattern} ESCAPE '\\'
        OR p.summary ILIKE ${pattern} ESCAPE '\\'
      )`);
    }

    for (const [column, value] of [
      ['language_code', body.language],
      ['category', body.category],
      ['type', body.type],
      ['status', body.status],
      ['publisher_id', body.publisher],
    ] as const) {
      const normalized = String(value || '').trim();
      if (normalized && normalized !== ALL) {
        where.push(`p.${column} = ${push(normalized)}`);
      }
    }

    const page = safePositiveInt(body.page, 1);
    const pageSize = Math.min(safePositiveInt(body.pageSize, 25), MAX_PAGE_SIZE);
    const offset = (page - 1) * pageSize;
    const sortColumn = SORT_COLUMNS[String(body.sortKey || '').trim()] || SORT_COLUMNS.date;
    const sortDirection = body.sortAscending === true ? 'ASC' : 'DESC';
    const whereSql = where.length ? `WHERE ${where.join(' AND ')}` : '';
    const countValues = values.slice();
    const limitSql = push(pageSize);
    const offsetSql = push(offset);

    const [result, countResult] = await Promise.all([
      dbQuery<any>(
        `SELECT
         p.id,
         p.title,
         p.category,
         p.type,
         p.status,
         p.slug,
         p.created_at,
         p.thumbnail_url,
         p.likes_count,
         p.comments_count,
         p.language_code,
         p.is_pinned,
         p.publisher_id,
         jsonb_build_object(
           'full_name', publisher.full_name,
           'username', publisher.username,
           'email', publisher.email
         ) AS profiles,
         parent.label AS parent_category,
         CASE
           WHEN jsonb_typeof(p.card_data -> 'categoryPath') = 'array'
             AND jsonb_array_length(p.card_data -> 'categoryPath') > 0
           THEN p.card_data -> 'categoryPath'
           ELSE to_jsonb(
             array_remove(
               ARRAY[grandparent.label, parent.label, category_item.label],
               NULL
             )
           )
         END AS category_path
       FROM public.posts p
       LEFT JOIN public.profiles publisher ON publisher.id = p.publisher_id
       LEFT JOIN LATERAL (
         SELECT item.parent_id, item.label
         FROM public.navigation_items item
         LEFT JOIN public.navigation_menus menu ON menu.id = item.menu_id
         LEFT JOIN public.navigation_items item_parent ON item_parent.id = item.parent_id
         WHERE item.label = p.category
         ORDER BY
           CASE WHEN menu.code = 'sidebar_main' THEN 0 ELSE 1 END,
           CASE WHEN item.parent_id IS NOT NULL THEN 0 ELSE 1 END,
           CASE WHEN item_parent.type = 'district' THEN 1 ELSE 0 END,
           (item.language_code = p.language_code) DESC NULLS LAST,
           item.order_index,
           item.id
         LIMIT 1
       ) category_item ON true
       LEFT JOIN public.navigation_items parent ON parent.id = category_item.parent_id
       LEFT JOIN public.navigation_items grandparent ON grandparent.id = parent.parent_id
       ${whereSql}
       ORDER BY p.is_pinned DESC, ${sortColumn} ${sortDirection} NULLS LAST, p.id DESC
       LIMIT ${limitSql}
       OFFSET ${offsetSql}`,
        values
      ),
      dbQuery<{ count: string }>(
        `SELECT COUNT(*)::bigint AS count
         FROM public.posts p
         ${whereSql}`,
        countValues
      ),
    ]);

    const rows = result.rows || [];
    const count = Number(countResult.rows[0]?.count || 0);
    return adminJson({
      data: rows,
      count,
      error: null,
    });
  } catch (error) {
    return adminError(error);
  }
};
