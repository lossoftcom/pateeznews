import type { APIRoute } from 'astro';
import { dbQuery } from '@/lib/server/supabaseDb';
import { getSessionFromRequest, json } from '@/lib/server/appDb';
import { signInWithPassword } from '@/lib/server/supabaseAuth';

function cleanText(value: unknown) {
  return String(value || '').trim();
}

function cleanEmail(value: unknown) {
  return cleanText(value).toLowerCase();
}

function cleanIdentifier(value: unknown) {
  return cleanText(value).replace(/^@+/, '').trim();
}

function looksLikeEmail(value: string) {
  return /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(value);
}

async function emailForIdentifier(identifier: string) {
  const clean = cleanIdentifier(identifier);
  if (!clean) return '';
  if (looksLikeEmail(clean)) return clean.toLowerCase();

  const result = await dbQuery<{ email: string | null }>(
    `SELECT email
     FROM public.profiles
     WHERE lower(username) = lower($1)
        OR lower(slug) = lower($1)
     LIMIT 1`,
    [clean]
  );
  return cleanEmail(result.rows[0]?.email);
}

async function profileForUser(userId: string) {
  if (!userId) return null;
  const result = await dbQuery<{
    id: string;
    username: string | null;
    full_name: string | null;
    avatar_url: string | null;
    role: string | null;
    email: string | null;
    status: string | null;
  }>(
    `SELECT id, username, full_name, avatar_url, role, email, status
     FROM public.profiles
     WHERE id = $1::uuid
     LIMIT 1`,
    [userId]
  );
  return result.rows[0] || null;
}

function profileForClient(profile: Awaited<ReturnType<typeof profileForUser>>) {
  if (!profile) return null;
  const { status: _status, ...safeProfile } = profile;
  return safeProfile;
}

export const POST: APIRoute = async ({ request }) => {
  try {
    const body = await request.json();
    const action = cleanText(body.action);

    if (action === 'signInWithPassword') {
      const identifier = cleanIdentifier(body.identifier || body.email);
      const password = String(body.password || '');
      const email = await emailForIdentifier(identifier);
      if (!email || !password) {
        return json(
          { data: { user: null, session: null, profile: null }, error: { message: 'Invalid login credentials' } },
          401
        );
      }

      const result = await signInWithPassword(email, password);
      if (result.error || !result.data.session?.user?.id) {
        return json({ ...result, data: { ...result.data, profile: null } }, 401);
      }

      const profile = await profileForUser(result.data.session.user.id);
      if (String(profile?.status || '').toLowerCase() === 'blocked') {
        return json(
          { data: { user: null, session: null, profile: null }, error: { message: 'Account is blocked' } },
          403
        );
      }

      return json({
        data: { ...result.data, profile: profileForClient(profile) },
        error: null,
      });
    }

    if (action === 'getSession' || action === 'profile') {
      const session = await getSessionFromRequest(request, body);
      if (!session?.user?.id) {
        return json({ data: { session: null, profile: null }, error: null });
      }
      const profile = await profileForUser(session.user.id);
      return json({
        data: { session, profile: profileForClient(profile) },
        error: null,
      });
    }

    return json({ data: null, error: { message: 'Unsupported auth action' } }, 400);
  } catch (error: any) {
    return json(
      { data: null, error: { message: error?.message || 'Auth failed' } },
      500
    );
  }
};
