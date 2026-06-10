import type { APIRoute } from 'astro';
import { adminError, adminJson, requireAdminRequest } from '@/lib/server/adminAuth';
import { dbQuery } from '@/lib/server/supabaseDb';

export const GET: APIRoute = async ({ request }) => {
  try {
    await requireAdminRequest(request, 'posts_access');
    const result = await dbQuery<{
      languages: any[];
      categories: any[];
      types: any[];
      publishers: any[];
    }>(
      `WITH used_categories AS (
       SELECT DISTINCT btrim(category) AS label
       FROM public.posts
         WHERE btrim(coalesce(category, '')) <> ''
           AND deleted_at IS NULL
           AND COALESCE(status, '') <> 'trash'
       ),
       category_rows AS (
         SELECT DISTINCT n.label, parent.label AS parent_label
         FROM public.navigation_items n
         JOIN used_categories used ON used.label = n.label
         LEFT JOIN public.navigation_items parent ON parent.id = n.parent_id
         WHERE btrim(coalesce(n.label, '')) <> ''
       ),
       type_rows AS (
       SELECT DISTINCT btrim(type) AS label
       FROM public.posts
         WHERE btrim(coalesce(type, '')) <> ''
           AND deleted_at IS NULL
           AND COALESCE(status, '') <> 'trash'
       ),
       publisher_rows AS (
         SELECT DISTINCT p.id, p.full_name
       FROM public.profiles p
       JOIN public.posts post ON post.publisher_id = p.id
         WHERE btrim(coalesce(p.full_name, '')) <> ''
           AND post.deleted_at IS NULL
           AND COALESCE(post.status, '') <> 'trash'
       )
       SELECT
         COALESCE((
           SELECT jsonb_agg(jsonb_build_object('id', code, 'label', name) ORDER BY name)
           FROM public.languages
         ), '[]'::jsonb) AS languages,
         COALESCE((
           SELECT jsonb_agg(
             jsonb_build_object('id', label, 'label', label, 'parent_label', parent_label)
             ORDER BY coalesce(parent_label, ''), label
           )
           FROM category_rows
         ), '[]'::jsonb) AS categories,
         COALESCE((
           SELECT jsonb_agg(jsonb_build_object('id', label, 'label', label) ORDER BY label)
           FROM type_rows
         ), '[]'::jsonb) AS types,
         COALESCE((
           SELECT jsonb_agg(jsonb_build_object('id', id, 'label', full_name) ORDER BY full_name)
           FROM publisher_rows
         ), '[]'::jsonb) AS publishers`
    );

    return adminJson({ data: result.rows[0], error: null });
  } catch (error) {
    return adminError(error);
  }
};
