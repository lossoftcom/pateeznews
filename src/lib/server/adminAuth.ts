import { getSessionFromToken, type AppAuthSession } from './appAuth';
import { dbQuery } from './supabaseDb';
import { adminSecurityHeaders } from './securityHeaders';

type AdminAuthGlobal = typeof globalThis & {
  __pateezAdminContextCache?: Map<string, CachedAdminContext>;
};

export interface AdminContext {
  session: AppAuthSession;
  profile: {
    id: string;
    role: string | null;
    email: string | null;
  };
  permissions: Set<string>;
}

interface CachedAdminContext {
  userId: string;
  expiresAt: number;
  profile: AdminContext['profile'];
  permissions: string[];
}

const ADMIN_CONTEXT_CACHE_TTL_MS = 45_000;
const ADMIN_CONTEXT_CACHE_MAX_ENTRIES = 250;

export function bearerTokenFromRequest(request: Request) {
  const header = request.headers.get('authorization') || '';
  const match = header.match(/^Bearer\s+(.+)$/i);
  return match?.[1]?.trim() || '';
}

function adminContextCache() {
  const g = globalThis as AdminAuthGlobal;
  if (!g.__pateezAdminContextCache) {
    g.__pateezAdminContextCache = new Map();
  }
  return g.__pateezAdminContextCache;
}

function getCachedAdminContext(token: string, userId: string): AdminContext | null {
  const cache = adminContextCache();
  const cached = cache.get(token);
  if (!cached || cached.userId !== userId || cached.expiresAt <= Date.now()) {
    cache.delete(token);
    return null;
  }
  return {
    session: null as unknown as AppAuthSession,
    profile: cached.profile,
    permissions: new Set(cached.permissions),
  };
}

function saveCachedAdminContext(token: string, context: AdminContext) {
  const cache = adminContextCache();
  if (cache.size >= ADMIN_CONTEXT_CACHE_MAX_ENTRIES) {
    const oldestKey = cache.keys().next().value;
    if (oldestKey) cache.delete(oldestKey);
  }
  cache.set(token, {
    userId: context.session.user.id,
    expiresAt: Date.now() + ADMIN_CONTEXT_CACHE_TTL_MS,
    profile: context.profile,
    permissions: [...context.permissions],
  });
}

export async function requireAdminToken(token?: string | null, permission?: string): Promise<AdminContext> {
  const session = await getSessionFromToken(token);
  if (!session?.user?.id) {
    throw Object.assign(new Error('Admin session is required'), { status: 401 });
  }

  const cacheKey = token?.trim() || '';
  if (cacheKey) {
    const cached = getCachedAdminContext(cacheKey, session.user.id);
    if (cached) {
      const cachedContext = { ...cached, session };
      const cachedRole = String(cachedContext.profile.role || '').toLowerCase();
      const cachedIsAdmin = cachedRole === 'admin' || cachedRole === 'super_admin';
      if (!cachedIsAdmin && (!permission || !cachedContext.permissions.has(permission))) {
        throw Object.assign(new Error('Admin permission denied'), { status: 403 });
      }
      return cachedContext;
    }
  }

  const profileResult = await dbQuery<{ id: string; role: string | null; email: string | null }>(
    `SELECT id, role, email
     FROM public.profiles
     WHERE id = $1
     LIMIT 1`,
    [session.user.id]
  );

  const profile = profileResult.rows[0];
  if (!profile) {
    throw Object.assign(new Error('Admin profile is required'), { status: 403 });
  }

  const permissionResult = await dbQuery<{ permission_key: string }>(
    `SELECT rp.permission_key
     FROM public.roles r
     JOIN public.role_permissions rp ON rp.role_id = r.id
     WHERE r.name = $1`,
    [profile.role]
  );
  const permissions = new Set(permissionResult.rows.map((row) => row.permission_key));
  const role = String(profile.role || '').toLowerCase();
  const isAdmin = role === 'admin' || role === 'super_admin';

  if (!isAdmin && (!permission || !permissions.has(permission))) {
    throw Object.assign(new Error('Admin permission denied'), { status: 403 });
  }

  const context = { session, profile, permissions };
  if (cacheKey) saveCachedAdminContext(cacheKey, context);
  return context;
}

export async function requireAdminRequest(request: Request, permission?: string) {
  return requireAdminToken(bearerTokenFromRequest(request), permission);
}

export async function requireAnyAdminPermission(request: Request, permissions: string[]) {
  let permissionError: unknown;
  for (const permission of permissions) {
    try {
      return await requireAdminRequest(request, permission);
    } catch (error) {
      if ((error as { status?: number })?.status !== 403) throw error;
      permissionError = error;
    }
  }
  throw permissionError || Object.assign(new Error('Admin permission denied'), { status: 403 });
}

export function adminJson(data: any, status = 200) {
  return new Response(JSON.stringify(data), {
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

export function adminError(error: unknown) {
  const anyError = error as { message?: string; status?: number };
  const status = anyError?.status || 500;
  const isProduction = import.meta.env.PROD || process.env.NODE_ENV === 'production';
  const message = status >= 500 && isProduction
    ? 'Admin request failed'
    : anyError?.message || 'Admin request failed';
  return adminJson(
    { data: null, error: { message } },
    status
  );
}
