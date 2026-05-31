import type { APIRoute } from 'astro';
import { adminError, adminJson, requireAdminRequest } from '@/lib/server/adminAuth';
import { dbQuery } from '@/lib/server/supabaseDb';

export const POST: APIRoute = async ({ request }) => {
  try {
    await requireAdminRequest(request, 'manage_users');
    const body = await request.json();
    const userId = String(body?.userId || '').trim();
    const role = String(body?.role || '').trim();
    if (!userId || !role) return adminJson({ data: null, error: { message: 'User id and role are required' } }, 400);

    const roleResult = await dbQuery('SELECT name FROM public.roles WHERE name = $1 LIMIT 1', [role]);
    if (!roleResult.rows[0]) return adminJson({ data: null, error: { message: 'Role does not exist' } }, 400);

    const result = await dbQuery(
      `UPDATE public.profiles
       SET role = $1,
           updated_at = now()
       WHERE id = $2::uuid
       RETURNING id, role, email, username, full_name`,
      [role, userId]
    );

    return adminJson({ data: result.rows[0] || null, error: null }, result.rows[0] ? 200 : 404);
  } catch (error) {
    return adminError(error);
  }
};
