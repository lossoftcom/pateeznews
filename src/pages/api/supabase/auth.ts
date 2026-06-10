import type { APIRoute } from 'astro';
import {
  getSessionFromToken,
  signInWithPassword,
  updateUser,
} from '@/lib/server/supabaseAuth';
import { adminSecurityHeaders } from '@/lib/server/securityHeaders';
import {
  clearLoginFailures,
  getLoginAttemptLock,
  getSecuritySettings,
  recordLoginFailure,
} from '@/lib/server/securitySettings';

function json(data: any, status = 200) {
  const isProduction = import.meta.env.PROD || process.env.NODE_ENV === 'production';
  const body = status >= 500 && isProduction && data?.error?.message
    ? { ...data, error: { ...data.error, message: 'Auth failed' } }
    : data;

  return new Response(JSON.stringify(body), {
    status,
    headers: {
      'Content-Type': 'application/json',
      'Cache-Control': 'no-store, no-cache, must-revalidate, proxy-revalidate',
      'CDN-Cache-Control': 'no-store',
      'Cloudflare-CDN-Cache-Control': 'no-store',
      'Vary': 'Authorization',
      ...adminSecurityHeaders(),
    },
  });
}

export const POST: APIRoute = async ({ request }) => {
  try {
    const body = await request.json();

    if (body.action === 'getSession') {
      const session = await getSessionFromToken(body.token);
      return json({ data: { session }, error: null });
    }

    if (body.action === 'signInWithPassword') {
      const email = String(body.email || '').trim().toLowerCase();
      const attemptIdentifier =
        email ||
        request.headers.get('cf-connecting-ip') ||
        request.headers.get('x-real-ip') ||
        'unknown';
      const settings = await getSecuritySettings('tr');
      const lock = await getLoginAttemptLock('admin', attemptIdentifier);
      if (lock.locked) {
        return json(
          { data: { user: null, session: null }, error: { message: 'Giriş geçici olarak kilitli. Lütfen daha sonra tekrar deneyin.' } },
          429
        );
      }

      const result = await signInWithPassword(email, body.password);
      if (result.error) {
        const failure = await recordLoginFailure('admin', attemptIdentifier, settings);
        if (failure.locked) {
          return json(
            { data: { user: null, session: null }, error: { message: 'Giriş geçici olarak kilitli. Lütfen daha sonra tekrar deneyin.' } },
            429
          );
        }
        return json(result, failure.locked ? 429 : 401);
      }

      await clearLoginFailures('admin', attemptIdentifier);
      return json(result);
    }

    if (body.action === 'signUp') {
      return json({ data: null, error: { message: 'Public sign up is disabled' } }, 403);
    }

    if (body.action === 'updateUser') {
      const result = await updateUser(body.token, body.attrs || {});
      return json(result, result.error ? 401 : 200);
    }

    return json({ data: null, error: { message: 'Unsupported auth action' } }, 400);
  } catch (error: any) {
    return json({ data: null, error: { message: error.message || 'Auth failed' } }, 500);
  }
};
