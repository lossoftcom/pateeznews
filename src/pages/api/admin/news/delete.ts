import type { APIRoute } from 'astro';
import { adminError, adminJson, requireAdminRequest } from '@/lib/server/adminAuth';
import { dbQuery } from '@/lib/server/supabaseDb';

export const POST: APIRoute = async ({ request }) => {
  try {
    const adminContext = await requireAdminRequest(request, 'manage_content');
    const body = await request.json();
    const ids = (Array.isArray(body?.ids) ? body.ids : [body?.id])
      .map((value: unknown) => Number(value))
      .filter((value: number) => Number.isFinite(value));
    if (!ids.length) return adminJson({ data: null, error: { message: 'At least one post id is required' } }, 400);

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
       RETURNING id`,
      [ids, adminContext.profile.id]
    );

    return adminJson({ data: { trashed: result.rows.map((row) => row.id) }, error: null });
  } catch (error) {
    return adminError(error);
  }
};
