import type { APIRoute } from 'astro';
import { adminError, adminJson, requireAdminRequest } from '@/lib/server/adminAuth';
import { dbQuery } from '@/lib/server/supabaseDb';

export const GET: APIRoute = async ({ request }) => {
  try {
    await requireAdminRequest(request, 'posts_access');
    const result = await dbQuery<{
      total: string | number;
      published: string | number;
      views: string | number | null;
    }>(
      `SELECT
         COUNT(*)::bigint AS total,
         COUNT(*) FILTER (WHERE status = 'published')::bigint AS published,
         COALESCE(SUM(COALESCE(views_count, 0)), 0)::bigint AS views
       FROM public.posts`
    );
    const row = result.rows[0] || { total: 0, published: 0, views: 0 };
    return adminJson({
      data: {
        total: Number(row.total || 0),
        published: Number(row.published || 0),
        views: Number(row.views || 0),
        scheduled: 0,
      },
      error: null,
    });
  } catch (error) {
    return adminError(error);
  }
};
