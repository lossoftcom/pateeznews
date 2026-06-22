import type { APIRoute } from 'astro';
import { adminError, adminJson, requireAdminRequest } from '@/lib/server/adminAuth';
import { submitIndexNowForPosts } from '@/lib/server/indexNow';
import { deleteTrashPostsByIds } from '@/lib/server/postTrash';
import { dbQuery } from '@/lib/server/supabaseDb';
import { invalidateNewsDataCache } from '@/services/dataService';
import { invalidateServerNewsDataCache } from '@/services/dataService.server';

export const POST: APIRoute = async ({ request }) => {
  try {
    const adminContext = await requireAdminRequest(request, 'manage_content');
    const body = await request.json();
    const ids = (Array.isArray(body?.ids) ? body.ids : [body?.id])
      .map((value: unknown) => Number(value))
      .filter((value: number) => Number.isFinite(value));
    if (!ids.length) return adminJson({ data: null, error: { message: 'At least one post id is required' } }, 400);

    if (body?.permanent === true) {
      const cleanupLanguage = String(body?.language || '').trim() || 'tr';
      const result = await deleteTrashPostsByIds(ids, cleanupLanguage);

      if (result.rows.length) {
        invalidateNewsDataCache();
        invalidateServerNewsDataCache();
        try {
          await submitIndexNowForPosts(request, result.rows);
        } catch (error) {
          console.warn('IndexNow submission failed:', error instanceof Error ? error.message : error);
        }
      }

      return adminJson({ data: { deleted: result.rows.map((row) => row.id) }, error: null });
    }

    const result = await dbQuery(
      `UPDATE public.posts
       SET
         deleted_at = COALESCE(deleted_at, now()),
         deleted_by = $2,
         deleted_from_status = COALESCE(deleted_from_status, NULLIF(status, 'trash'), 'draft'),
         status = 'trash',
         is_pinned = false,
         updated_at = now()
       WHERE id = ANY($1::bigint[])
         AND deleted_at IS NULL
       RETURNING id, slug, language_code, status`,
      [ids, adminContext.profile.id]
    );

    if (result.rows.length) {
      invalidateNewsDataCache();
      invalidateServerNewsDataCache();
      try {
        await submitIndexNowForPosts(request, result.rows);
      } catch (error) {
        console.warn('IndexNow submission failed:', error instanceof Error ? error.message : error);
      }
    }

    return adminJson({ data: { trashed: result.rows.map((row) => row.id) }, error: null });
  } catch (error) {
    return adminError(error);
  }
};
