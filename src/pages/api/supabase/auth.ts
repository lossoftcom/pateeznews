import type { APIRoute } from 'astro';
import {
  getSessionFromToken,
  signInWithPassword,
  updateUser,
} from '@/lib/server/supabaseAuth';

function json(data: any, status = 200) {
  return new Response(JSON.stringify(data), {
    status,
    headers: { 'Content-Type': 'application/json' },
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
      const result = await signInWithPassword(body.email, body.password);
      return json(result, result.error ? 401 : 200);
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
