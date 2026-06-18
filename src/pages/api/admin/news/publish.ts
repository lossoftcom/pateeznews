import type { APIRoute } from 'astro';
import { adminError, adminJson, requireAdminRequest } from '@/lib/server/adminAuth';
import { submitIndexNowForPosts } from '@/lib/server/indexNow';
import { dbQuery } from '@/lib/server/supabaseDb';

export const POST: APIRoute = async ({ request }) => {
  try {
    await requireAdminRequest(request, 'manage_content');
    const body = await request.json();
    const id = Number(body?.id);
    if (!Number.isFinite(id)) return adminJson({ data: null, error: { message: 'Valid post id is required' } }, 400);

    const result = await dbQuery(
      `UPDATE public.posts
       SET status = 'published',
           published_at = COALESCE(published_at, now()),
           updated_at = now()
       WHERE id = $1
       RETURNING id, slug, language_code, status, published_at, updated_at`,
      [id]
    );

    if (result.rows[0]) {
      try {
        await submitIndexNowForPosts(request, result.rows);
      } catch (error) {
        console.warn('IndexNow submission failed:', error instanceof Error ? error.message : error);
      }
    }

    return adminJson({ data: result.rows[0] || null, error: null }, result.rows[0] ? 200 : 404);
  } catch (error) {
    return adminError(error);
  }
};
