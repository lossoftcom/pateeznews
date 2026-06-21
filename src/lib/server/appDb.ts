import { connectDbClient, dbQuery, type DatabaseClient } from './supabaseDb';
import { getSessionFromToken, type AppAuthSession } from './appAuth';
import { adminSecurityHeaders } from './securityHeaders';

export async function ensureAppSchema() {
  return Promise.resolve();
}

export async function withTransaction<T>(fn: (client: DatabaseClient) => Promise<T>) {
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

export async function getSessionFromRequest(request: Request, body?: Record<string, any>): Promise<AppAuthSession | null> {
  return getSessionFromToken(getTokenFromRequest(request, body));
}

export async function getProfileRole(userId: string) {
  const result = await dbQuery<{ role: string | null }>(
    'SELECT role FROM public.profiles WHERE id = $1 LIMIT 1',
    [userId]
  );
  return result.rows[0]?.role || 'member';
}

export function json(
  data: any,
  status = 200,
  options: { cacheControl?: string } = {}
) {
  const isProduction = import.meta.env.PROD || process.env.NODE_ENV === 'production';
  const body = status >= 500 && isProduction && data?.error?.message
    ? { ...data, error: { ...data.error, message: 'Request failed' } }
    : data;
  // Cache başlığı YALNIZCA açıkça istenirse ve yanıt 2xx ise uygulanır; aksi
  // halde (varsayılan + hata yanıtları) no-store kalır. Böylece mevcut tüm
  // çağıranlar değişmeden no-store davranışını sürdürür.
  const useCache = Boolean(options.cacheControl) && status >= 200 && status < 300;
  const cacheControl = useCache
    ? options.cacheControl!
    : 'no-store, no-cache, must-revalidate, proxy-revalidate';
  const cdnCacheControl = useCache ? options.cacheControl! : 'no-store';
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      'Content-Type': 'application/json',
      'Cache-Control': cacheControl,
      'CDN-Cache-Control': cdnCacheControl,
      'Cloudflare-CDN-Cache-Control': cdnCacheControl,
      'Vary': 'Authorization',
      ...adminSecurityHeaders(),
    },
  });
}
