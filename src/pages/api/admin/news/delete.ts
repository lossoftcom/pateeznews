import type { APIRoute } from 'astro';
import { adminError, adminJson, requireAdminRequest } from '@/lib/server/adminAuth';
import { dbQuery } from '@/lib/server/supabaseDb';

export const POST: APIRoute = async ({ request }) => {
  try {
    await requireAdminRequest(request, 'manage_content');
    const body = await request.json();
    const ids = (Array.isArray(body?.ids) ? body.ids : [body?.id])
      .map((value: unknown) => Number(value))
      .filter((value: number) => Number.isFinite(value));
    if (!ids.length) return adminJson({ data: null, error: { message: 'At least one post id is required' } }, 400);

    const result = await dbQuery(
      `DELETE FROM public.posts
       WHERE id = ANY($1::bigint[])
       RETURNING id`,
      [ids]
    );

    return adminJson({ data: { deleted: result.rows.map((row) => row.id) }, error: null });
  } catch (error) {
    return adminError(error);
  }
};
