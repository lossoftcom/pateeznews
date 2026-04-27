import type { APIRoute } from 'astro';
import crypto from 'crypto';
import bcrypt from 'bcryptjs';
import { ensureAppSchema, getProfileRole, getSessionFromRequest, json } from '@/lib/server/appDb';
import { dbQuery } from '@/lib/server/neonDb';

async function verifyPassword(userId: string, password: string) {
  const result = await dbQuery<{ encrypted_password: string | null }>(
    'SELECT encrypted_password FROM auth.users WHERE id = $1 AND deleted_at IS NULL LIMIT 1',
    [userId]
  );
  const hash = result.rows[0]?.encrypted_password;
  return hash ? bcrypt.compare(password, hash) : false;
}

async function setPassword(userId: string, password: string) {
  const hash = await bcrypt.hash(password, 10);
  await dbQuery('UPDATE auth.users SET encrypted_password = $1, updated_at = now() WHERE id = $2', [hash, userId]);
}

async function requireAdmin(userId: string) {
  const role = String(await getProfileRole(userId)).toLowerCase();
  return role === 'admin' || role === 'super_admin';
}

export const POST: APIRoute = async ({ request }) => {
  try {
    const body = await request.json();
    const action = String(body.action || '');

    if (action === 'request-password-reset') {
      const email = String(body.email || '').trim().toLowerCase();
      if (!email) return json({ error: { message: 'Email required' } }, 400);
      await ensureAppSchema();
      const token = crypto.randomBytes(32).toString('base64url');
      const tokenHash = crypto.createHash('sha256').update(token).digest('hex');
      await dbQuery(
        `INSERT INTO public.password_reset_requests (email, token_hash, expires_at)
         VALUES ($1, $2, now() + interval '30 minutes')`,
        [email, tokenHash]
      );
      return json({ ok: true });
    }

    if (action === 'ensure-schema') {
      await ensureAppSchema();
      return json({ ok: true });
    }

    const session = await getSessionFromRequest(request, body);
    if (!session?.user?.id) return json({ error: { message: 'Auth required' } }, 401);

    await ensureAppSchema();

    const userId = session.user.id;

    if (action === 'update-password') {
      const currentPassword = String(body.currentPassword || '');
      const newPassword = String(body.newPassword || '');
      if (newPassword.length < 6) return json({ error: { message: 'Password is too short' } }, 400);
      if (!(await verifyPassword(userId, currentPassword))) {
        return json({ error: { message: 'Current password is invalid' } }, 400);
      }
      await setPassword(userId, newPassword);
      return json({ ok: true });
    }

    if (action === 'delete-self') {
      const currentPassword = String(body.currentPassword || '');
      if (!(await verifyPassword(userId, currentPassword))) {
        return json({ error: { message: 'Current password is invalid' } }, 400);
      }
      await dbQuery('DELETE FROM public.profiles WHERE id = $1', [userId]);
      await dbQuery('DELETE FROM auth.users WHERE id = $1', [userId]);
      return json({ ok: true });
    }

    if (action === 'admin-update-password') {
      if (!(await requireAdmin(userId))) return json({ error: { message: 'Forbidden' } }, 403);
      const targetUserId = String(body.userId || '');
      const newPassword = String(body.newPassword || '');
      if (!targetUserId || newPassword.length < 6) return json({ error: { message: 'Invalid user or password' } }, 400);
      await setPassword(targetUserId, newPassword);
      return json({ ok: true });
    }

    if (action === 'admin-delete-user') {
      if (!(await requireAdmin(userId))) return json({ error: { message: 'Forbidden' } }, 403);
      const targetUserId = String(body.userId || '');
      if (!targetUserId) return json({ error: { message: 'User missing' } }, 400);
      await dbQuery('DELETE FROM public.profiles WHERE id = $1', [targetUserId]);
      await dbQuery('DELETE FROM auth.users WHERE id = $1', [targetUserId]);
      return json({ ok: true });
    }

    return json({ error: { message: 'Unsupported account action' } }, 400);
  } catch (error: any) {
    return json({ error: { message: error.message || 'Account action failed' } }, 500);
  }
};
