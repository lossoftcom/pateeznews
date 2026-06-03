import { createRemoteJWKSet, decodeJwt, decodeProtectedHeader, jwtVerify, type JWTPayload } from 'jose';
import { readRuntimeEnv } from './runtimeEnv';

export interface SupabaseUser {
  id: string;
  email: string | null;
  role?: string | null;
  aud?: string | null;
  user_metadata?: Record<string, any>;
  app_metadata?: Record<string, any>;
}

export interface SupabaseSession {
  access_token: string;
  refresh_token?: string;
  token_type: 'bearer';
  expires_at: number;
  expires_in?: number;
  user: SupabaseUser;
}

type AuthGlobal = typeof globalThis & {
  __pateezSupabaseJwks?: ReturnType<typeof createRemoteJWKSet>;
  __pateezSupabaseJwksUrl?: string;
};

const JWT_CLOCK_TOLERANCE_SECONDS = 30;

function deriveSupabaseUrlFromDatabaseUrl() {
  const databaseUrl = readRuntimeEnv('SUPABASE_DATABASE_URL') || readRuntimeEnv('DATABASE_URL') || readRuntimeEnv('POSTGRES_URL');
  if (!databaseUrl) return '';
  try {
    const parsed = new URL(databaseUrl);
    const match = parsed.hostname.match(/^db\.([a-z0-9-]+)\.supabase\.co$/i);
    return match ? `https://${match[1]}.supabase.co` : '';
  } catch {
    return '';
  }
}

export function getSupabaseUrl() {
  return (
    readRuntimeEnv('SUPABASE_URL') ||
    readRuntimeEnv('PUBLIC_SUPABASE_URL') ||
    deriveSupabaseUrlFromDatabaseUrl()
  ).replace(/\/$/, '');
}

export function getSupabasePublishableKey() {
  return (
    readRuntimeEnv('SUPABASE_PUBLISHABLE_KEY') ||
    readRuntimeEnv('PUBLIC_SUPABASE_PUBLISHABLE_KEY') ||
    ''
  );
}

function getSupabaseIssuer() {
  const url = getSupabaseUrl();
  if (!url) throw new Error('SUPABASE_URL is required for Supabase JWT verification');
  return `${url}/auth/v1`;
}

function getSupabaseJwks() {
  const g = globalThis as AuthGlobal;
  const jwksUrl = `${getSupabaseIssuer()}/.well-known/jwks.json`;
  if (!g.__pateezSupabaseJwks || g.__pateezSupabaseJwksUrl !== jwksUrl) {
    g.__pateezSupabaseJwks = createRemoteJWKSet(new URL(jwksUrl), {
      cacheMaxAge: 10 * 60 * 1000,
      cooldownDuration: 30 * 1000,
      timeoutDuration: 1500,
    });
    g.__pateezSupabaseJwksUrl = jwksUrl;
  }
  return g.__pateezSupabaseJwks;
}

function getSupabaseJwtSecret() {
  return readRuntimeEnv('SUPABASE_JWT_SECRET') || '';
}

export function getSupabaseServiceRoleKey() {
  return readRuntimeEnv('SUPABASE_SERVICE_ROLE_KEY') || '';
}

function requireSupabaseAuthConfig() {
  const url = getSupabaseUrl();
  const key = getSupabasePublishableKey();
  if (!url || !key) {
    throw new Error('SUPABASE_URL and SUPABASE_PUBLISHABLE_KEY are required for Supabase Auth');
  }
  return { url, key };
}

function isAuthenticatedAudience(audience: JWTPayload['aud']) {
  if (Array.isArray(audience)) return audience.includes('authenticated');
  return audience === 'authenticated';
}

function toUserFromJwt(payload: JWTPayload): SupabaseUser {
  return {
    id: String(payload.sub || ''),
    email: typeof payload.email === 'string' ? payload.email : null,
    role: typeof payload.role === 'string' ? payload.role : null,
    aud: Array.isArray(payload.aud) ? payload.aud.join(',') : payload.aud?.toString() ?? null,
    user_metadata: typeof payload.user_metadata === 'object' && payload.user_metadata
      ? payload.user_metadata as Record<string, any>
      : {},
    app_metadata: typeof payload.app_metadata === 'object' && payload.app_metadata
      ? payload.app_metadata as Record<string, any>
      : {},
  };
}

async function verifyJwtLocally(token: string): Promise<SupabaseSession | null> {
  const header = decodeProtectedHeader(token);
  const issuer = getSupabaseIssuer();
  const { payload } = header.alg?.startsWith('HS')
    ? await verifyJwtWithSharedSecret(token, issuer)
    : await jwtVerify(token, getSupabaseJwks(), {
      algorithms: ['ES256', 'RS256'],
      issuer,
      clockTolerance: JWT_CLOCK_TOLERANCE_SECONDS,
    });

  if (!payload.sub || !isAuthenticatedAudience(payload.aud)) return null;

  const expiresAt = typeof payload.exp === 'number'
    ? payload.exp
    : Math.floor(Date.now() / 1000);
  return {
    access_token: token,
    token_type: 'bearer',
    expires_at: expiresAt,
    expires_in: Math.max(0, expiresAt - Math.floor(Date.now() / 1000)),
    user: toUserFromJwt(payload),
  };
}

async function verifyJwtWithSharedSecret(token: string, issuer: string) {
  const secret = getSupabaseJwtSecret();
  if (!secret) throw new Error('SUPABASE_JWT_SECRET is required for HS256 JWT verification');
  return jwtVerify(token, new TextEncoder().encode(secret), {
    algorithms: ['HS256'],
    issuer,
    clockTolerance: JWT_CLOCK_TOLERANCE_SECONDS,
  });
}

function toUser(input: any): SupabaseUser {
  return {
    id: String(input?.id || ''),
    email: input?.email ?? null,
    role: input?.role ?? input?.aud ?? null,
    aud: input?.aud ?? null,
    user_metadata: input?.user_metadata || {},
    app_metadata: input?.app_metadata || {},
  };
}

function toSession(input: any): SupabaseSession | null {
  if (!input?.access_token || !input?.user?.id) return null;
  const expiresIn = Number(input.expires_in || 3600);
  const expiresAt = Number(input.expires_at || Math.floor(Date.now() / 1000) + expiresIn);
  return {
    access_token: String(input.access_token),
    refresh_token: input.refresh_token ? String(input.refresh_token) : undefined,
    token_type: 'bearer',
    expires_at: expiresAt,
    expires_in: expiresIn,
    user: toUser(input.user),
  };
}

async function authFetch(path: string, init: RequestInit = {}) {
  const { url, key } = requireSupabaseAuthConfig();
  const response = await fetch(`${url}/auth/v1${path}`, {
    ...init,
    headers: {
      apikey: key,
      'Content-Type': 'application/json',
      ...(init.headers || {}),
    },
  });
  const text = await response.text();
  const body = text ? JSON.parse(text) : null;
  if (!response.ok) {
    const message = body?.msg || body?.message || body?.error_description || body?.error || 'Supabase Auth request failed';
    throw new Error(message);
  }
  return body;
}

async function adminAuthFetch(path: string, init: RequestInit = {}) {
  const url = getSupabaseUrl();
  const serviceRoleKey = getSupabaseServiceRoleKey();
  if (!url || !serviceRoleKey) {
    throw new Error('SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY are required for Supabase Auth admin operations');
  }

  const response = await fetch(`${url}/auth/v1${path}`, {
    ...init,
    headers: {
      apikey: serviceRoleKey,
      Authorization: `Bearer ${serviceRoleKey}`,
      'Content-Type': 'application/json',
      ...(init.headers || {}),
    },
  });
  const text = await response.text();
  const body = text ? JSON.parse(text) : null;
  if (!response.ok) {
    const message = body?.msg || body?.message || body?.error_description || body?.error || 'Supabase Auth admin request failed';
    throw new Error(message);
  }
  return body;
}

export async function getSessionFromToken(token?: string | null): Promise<SupabaseSession | null> {
  if (!token) return null;
  try {
    return await verifyJwtLocally(token);
  } catch {
    try {
      const user = await authFetch('/user', {
        headers: { Authorization: `Bearer ${token}` },
      });
      const expiresAt = expiresAtFromToken(token);
      return {
        access_token: token,
        token_type: 'bearer',
        expires_at: expiresAt,
        expires_in: Math.max(0, expiresAt - Math.floor(Date.now() / 1000)),
        user: toUser(user),
      };
    } catch {
      return null;
    }
  }
}

function expiresAtFromToken(token: string) {
  try {
    const payload = decodeJwt(token);
    if (typeof payload.exp === 'number') return payload.exp;
  } catch {
    // Auth REST already validated the token; this only affects local cache TTL.
  }
  return Math.floor(Date.now() / 1000) + 3600;
}

export async function signInWithPassword(email: string, password: string) {
  try {
    const body = await authFetch('/token?grant_type=password', {
      method: 'POST',
      body: JSON.stringify({ email, password }),
    });
    return { data: { user: toUser(body.user), session: toSession(body) }, error: null };
  } catch (error: any) {
    return { data: { user: null, session: null }, error: { message: error.message || 'Invalid login credentials' } };
  }
}

export async function signUpWithPassword(email: string, password: string, metadata: Record<string, any> = {}) {
  try {
    const body = await authFetch('/signup', {
      method: 'POST',
      body: JSON.stringify({ email, password, data: metadata || {} }),
    });
    return { data: { user: body?.user ? toUser(body.user) : null, session: toSession(body) }, error: null };
  } catch (error: any) {
    return { data: { user: null, session: null }, error: { message: error.message || 'Sign up failed' } };
  }
}

export async function updateUser(token: string | null | undefined, attrs: { password?: string; email?: string }) {
  if (!token) return { data: { user: null }, error: { message: 'Auth session missing' } };
  try {
    const user = await authFetch('/user', {
      method: 'PUT',
      headers: { Authorization: `Bearer ${token}` },
      body: JSON.stringify(attrs),
    });
    return { data: { user: toUser(user) }, error: null };
  } catch (error: any) {
    return { data: { user: null }, error: { message: error.message || 'User update failed' } };
  }
}

export async function adminCreateAuthUser(input: {
  email: string;
  password: string;
  userMetadata?: Record<string, any>;
  appMetadata?: Record<string, any>;
}) {
  const user = await adminAuthFetch('/admin/users', {
    method: 'POST',
    body: JSON.stringify({
      email: input.email,
      password: input.password,
      email_confirm: true,
      user_metadata: input.userMetadata || {},
      app_metadata: input.appMetadata || {},
    }),
  });
  return toUser(user);
}

export async function adminUpdateAuthUser(userId: string, attrs: {
  email?: string;
  password?: string;
  userMetadata?: Record<string, any>;
  appMetadata?: Record<string, any>;
}) {
  const payload: Record<string, any> = {};
  if (attrs.email) payload.email = attrs.email;
  if (attrs.password) payload.password = attrs.password;
  if (attrs.userMetadata) payload.user_metadata = attrs.userMetadata;
  if (attrs.appMetadata) payload.app_metadata = attrs.appMetadata;

  const user = await adminAuthFetch(`/admin/users/${encodeURIComponent(userId)}`, {
    method: 'PUT',
    body: JSON.stringify(payload),
  });
  return toUser(user);
}

export async function adminDeleteAuthUser(userId: string) {
  await adminAuthFetch(`/admin/users/${encodeURIComponent(userId)}`, {
    method: 'DELETE',
  });
}
