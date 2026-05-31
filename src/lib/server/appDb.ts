import type { PoolClient } from 'pg';
import { connectDbClient, dbQuery } from './supabaseDb';
import { getSessionFromToken, type SupabaseSession } from './supabaseAuth';

export async function ensureAppSchema() {
  return Promise.resolve();
}

export async function withTransaction<T>(fn: (client: PoolClient) => Promise<T>) {
  const client = await connectDbClient();
  try {
    await client.query('BEGIN');
    const result = await fn(client);
    await client.query('COMMIT');
    return result;
  } catch (error) {
    await client.query('ROLLBACK');
    throw error;
  } finally {
    client.release();
  }
}

export function getTokenFromRequest(request: Request, body?: Record<string, any>) {
  const authHeader = request.headers.get('authorization') || '';
  const bearer = authHeader.match(/^Bearer\s+(.+)$/i)?.[1];
  return bearer || body?.token || null;
}

export async function getSessionFromRequest(request: Request, body?: Record<string, any>): Promise<SupabaseSession | null> {
  return getSessionFromToken(getTokenFromRequest(request, body));
}

export async function getProfileRole(userId: string) {
  const result = await dbQuery<{ role: string | null }>(
    'SELECT role FROM public.profiles WHERE id = $1 LIMIT 1',
    [userId]
  );
  return result.rows[0]?.role || 'member';
}

export function json(data: any, status = 200) {
  const isProduction = import.meta.env.PROD || process.env.NODE_ENV === 'production';
  const body = status >= 500 && isProduction && data?.error?.message
    ? { ...data, error: { ...data.error, message: 'Request failed' } }
    : data;
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      'Content-Type': 'application/json',
      'Cache-Control': 'no-store, no-cache, must-revalidate, proxy-revalidate',
      'CDN-Cache-Control': 'no-store',
      'Cloudflare-CDN-Cache-Control': 'no-store',
    },
  });
}
