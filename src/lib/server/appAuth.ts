import crypto from 'crypto';
import {
  createRemoteJWKSet,
  decodeJwt,
  jwtVerify,
  SignJWT,
  type JWTPayload,
} from 'jose';
import { connectDbClient, dbQuery, type DatabaseClient } from './supabaseDb';
import { readRuntimeEnv } from './runtimeEnv';
import { signInWithPassword as signInWithSupabasePassword } from './supabaseAuth';

export type AppAuthProvider = 'email' | 'google' | 'apple' | 'facebook' | 'x' | 'twitter';

export interface AppAuthUser {
  id: string;
  email: string | null;
  role?: string | null;
  aud?: string | null;
  user_metadata?: Record<string, any>;
  app_metadata?: Record<string, any>;
}

export interface AppAuthSession {
  access_token: string;
  refresh_token?: string;
  token_type: 'bearer';
  expires_at: number;
  expires_in?: number;
  user: AppAuthUser;
}

interface ProfileAuthRow {
  id: string;
  username: string | null;
  full_name: string | null;
  avatar_url: string | null;
  cover_url: string | null;
  phone: string | null;
  address: string | null;
  role: string | null;
  email: string | null;
  status: string | null;
  city: string | null;
  auth_provider: string | null;
  auth_providers: string[] | null;
  writer_application_status?: string | null;
  writer_application_at?: string | null;
}

interface ProviderProfile {
  provider: Exclude<AppAuthProvider, 'email'>;
  providerUserId: string;
  email: string;
  emailVerified: boolean | null;
  displayName: string;
  username: string;
  avatarUrl: string;
  coverUrl: string;
  phone: string;
  address: string;
  rawProfile: Record<string, any>;
}

export interface ProfileLoginLocation {
  ipAddress?: string | null;
  signupCity?: string | null;
}

type AppAuthGlobal = typeof globalThis & {
  __pateezGoogleJwks?: ReturnType<typeof createRemoteJWKSet>;
  __pateezAppleJwks?: ReturnType<typeof createRemoteJWKSet>;
};

const AUTH_AUDIENCE = 'authenticated';
const DEFAULT_SESSION_TTL_SECONDS = 60 * 60 * 24 * 30;
const LOCAL_DEV_AUTH_SECRET = 'pateez-local-development-auth-secret-only';
const DEFAULT_CITY = 'Niğde';

const DEFAULT_GOOGLE_CLIENT_IDS = [
  '219689188237-jprruujk8knn7noafs2nbvdgnuc67mbe.apps.googleusercontent.com',
  '219689188237-bro0ndlr7s1t0m0c6erhfiag4dfguss7.apps.googleusercontent.com',
  '219689188237-nujlogsppna6kq2g3m3vjdlp0gfgvgmj.apps.googleusercontent.com',
];

const DEFAULT_APPLE_CLIENT_IDS = [
  'com.pateez.app',
  'com.pateez.pateezcom.web',
];

function cleanText(value: unknown) {
  return String(value || '').trim();
}

function cleanEmail(value: unknown) {
  return cleanText(value).toLowerCase();
}

function cleanIpAddress(value: unknown) {
  return cleanText(value).slice(0, 64);
}

function cleanSignupCity(value: unknown) {
  return cleanText(value).slice(0, 120);
}

export async function markProfileSignedIn(
  userId: string,
  location: ProfileLoginLocation = {},
) {
  const cleanUserId = cleanText(userId);
  if (!cleanUserId) return;
  await dbQuery(
    `UPDATE public.profiles
        SET is_logged_in = true,
            last_login_at = now(),
            ip_address = COALESCE(NULLIF(ip_address, ''), NULLIF($2::text, ''), ip_address),
            signup_city = COALESCE(NULLIF(signup_city, ''), NULLIF($3::text, ''), signup_city),
            updated_at = now()
      WHERE id = $1::uuid`,
    [
      cleanUserId,
      cleanIpAddress(location.ipAddress),
      cleanSignupCity(location.signupCity),
    ],
  );
}

export async function markProfileSignedOut(userId: string) {
  const cleanUserId = cleanText(userId);
  if (!cleanUserId) return;
  await dbQuery(
    `UPDATE public.profiles
        SET is_logged_in = false,
            updated_at = now()
      WHERE id = $1::uuid`,
    [cleanUserId],
  );
}

function splitEnvList(value: string) {
  return value
    .split(',')
    .map((item) => item.trim())
    .filter(Boolean);
}

function configuredGoogleClientIds() {
  const values = [
    readRuntimeEnv('GOOGLE_WEB_CLIENT_ID'),
    readRuntimeEnv('GOOGLE_ANDROID_CLIENT_ID'),
    readRuntimeEnv('GOOGLE_IOS_CLIENT_ID'),
    ...splitEnvList(readRuntimeEnv('GOOGLE_CLIENT_IDS')),
  ].filter(Boolean);
  return Array.from(new Set(values.length ? values : DEFAULT_GOOGLE_CLIENT_IDS));
}

function configuredAppleClientIds() {
  const values = [
    readRuntimeEnv('APPLE_BUNDLE_ID'),
    readRuntimeEnv('APPLE_SERVICE_ID'),
    ...splitEnvList(readRuntimeEnv('APPLE_CLIENT_IDS')),
  ].filter(Boolean);
  return Array.from(new Set(values.length ? values : DEFAULT_APPLE_CLIENT_IDS));
}

function appAuthSecret() {
  const secret =
    readRuntimeEnv('PATEEZ_AUTH_JWT_SECRET') ||
    readRuntimeEnv('AUTH_JWT_SECRET') ||
    readRuntimeEnv('MAIL_SECRET_KEY');
  if ((!secret || secret.length < 16) && (import.meta.env.DEV || readRuntimeEnv('NODE_ENV') === 'development')) {
    return new TextEncoder().encode(LOCAL_DEV_AUTH_SECRET);
  }
  if (!secret || secret.length < 16) {
    throw new Error('PATEEZ_AUTH_JWT_SECRET or MAIL_SECRET_KEY is required for app auth');
  }
  return new TextEncoder().encode(secret);
}

function appAuthIssuer() {
  return readRuntimeEnv('PATEEZ_AUTH_ISSUER') || 'https://pateez.com';
}

function sessionTtlSeconds() {
  const value = Number(readRuntimeEnv('PATEEZ_AUTH_SESSION_TTL_SECONDS'));
  return Number.isFinite(value) && value >= 300
    ? Math.floor(value)
    : DEFAULT_SESSION_TTL_SECONDS;
}

function googleJwks() {
  const g = globalThis as AppAuthGlobal;
  if (!g.__pateezGoogleJwks) {
    g.__pateezGoogleJwks = createRemoteJWKSet(new URL('https://www.googleapis.com/oauth2/v3/certs'), {
      cacheMaxAge: 10 * 60 * 1000,
      cooldownDuration: 30 * 1000,
      timeoutDuration: 2500,
    });
  }
  return g.__pateezGoogleJwks;
}

function appleJwks() {
  const g = globalThis as AppAuthGlobal;
  if (!g.__pateezAppleJwks) {
    g.__pateezAppleJwks = createRemoteJWKSet(new URL('https://appleid.apple.com/auth/keys'), {
      cacheMaxAge: 10 * 60 * 1000,
      cooldownDuration: 30 * 1000,
      timeoutDuration: 2500,
    });
  }
  return g.__pateezAppleJwks;
}

function authProvider(value: unknown): AppAuthProvider {
  const provider = cleanText(value).toLowerCase();
  if (provider === 'twitter') return 'x';
  if (['email', 'google', 'apple', 'facebook', 'x'].includes(provider)) {
    return provider as AppAuthProvider;
  }
  return 'email';
}

function providerList(value: unknown, fallback: AppAuthProvider) {
  const source = Array.isArray(value) ? value : [fallback];
  const providers = source.map(authProvider).filter(Boolean);
  return Array.from(new Set(providers.length ? providers : [fallback]));
}

function profileUserMetadata(profile: ProfileAuthRow) {
  return {
    full_name: profile.full_name || '',
    username: profile.username || '',
    avatar_url: profile.avatar_url || '',
    cover_url: profile.cover_url || '',
    phone: profile.phone || '',
    address: profile.address || '',
    city: profile.city || DEFAULT_CITY,
    role: profile.role || 'member',
    status: profile.status || 'Aktif',
    email: profile.email || '',
  };
}

function profileAppMetadata(profile: ProfileAuthRow) {
  const provider = authProvider(profile.auth_provider);
  return {
    provider,
    providers: providerList(profile.auth_providers, provider),
  };
}

function userFromProfile(profile: ProfileAuthRow): AppAuthUser {
  return {
    id: profile.id,
    email: profile.email || null,
    role: 'authenticated',
    aud: AUTH_AUDIENCE,
    user_metadata: profileUserMetadata(profile),
    app_metadata: profileAppMetadata(profile),
  };
}

function userFromPayload(payload: JWTPayload): AppAuthUser {
  return {
    id: String(payload.sub || ''),
    email: typeof payload.email === 'string' ? payload.email : null,
    role: typeof payload.role === 'string' ? payload.role : 'authenticated',
    aud: Array.isArray(payload.aud) ? payload.aud.join(',') : payload.aud?.toString() ?? AUTH_AUDIENCE,
    user_metadata: typeof payload.user_metadata === 'object' && payload.user_metadata
      ? payload.user_metadata as Record<string, any>
      : {},
    app_metadata: typeof payload.app_metadata === 'object' && payload.app_metadata
      ? payload.app_metadata as Record<string, any>
      : {},
  };
}

function sessionFromTokenAndPayload(token: string, payload: JWTPayload): AppAuthSession | null {
  if (!payload.sub) return null;
  const expiresAt = typeof payload.exp === 'number'
    ? payload.exp
    : Math.floor(Date.now() / 1000);
  return {
    access_token: token,
    token_type: 'bearer',
    expires_at: expiresAt,
    expires_in: Math.max(0, expiresAt - Math.floor(Date.now() / 1000)),
    user: userFromPayload(payload),
  };
}

async function createSession(profile: ProfileAuthRow): Promise<AppAuthSession> {
  const user = userFromProfile(profile);
  const now = Math.floor(Date.now() / 1000);
  const ttl = sessionTtlSeconds();
  const expiresAt = now + ttl;
  const token = await new SignJWT({
    email: user.email || undefined,
    role: 'authenticated',
    user_metadata: user.user_metadata || {},
    app_metadata: user.app_metadata || {},
  })
    .setProtectedHeader({ alg: 'HS256', typ: 'JWT' })
    .setSubject(user.id)
    .setIssuer(appAuthIssuer())
    .setAudience(AUTH_AUDIENCE)
    .setIssuedAt(now)
    .setExpirationTime(expiresAt)
    .sign(appAuthSecret());

  return {
    access_token: token,
    token_type: 'bearer',
    expires_at: expiresAt,
    expires_in: ttl,
    user,
  };
}

export async function getSessionFromToken(token?: string | null): Promise<AppAuthSession | null> {
  const cleanToken = cleanText(token);
  if (!cleanToken) return null;
  try {
    const { payload } = await jwtVerify(cleanToken, appAuthSecret(), {
      algorithms: ['HS256'],
      audience: AUTH_AUDIENCE,
      issuer: appAuthIssuer(),
      clockTolerance: 30,
    });
    return sessionFromTokenAndPayload(cleanToken, payload);
  } catch {
    return null;
  }
}

export function expiresAtFromToken(token: string) {
  try {
    const payload = decodeJwt(token);
    if (typeof payload.exp === 'number') return payload.exp;
  } catch {
    // Invalid tokens are handled by getSessionFromToken.
  }
  return Math.floor(Date.now() / 1000);
}

async function profileById(userId: string, client?: DatabaseClient) {
  const query = client?.query.bind(client) || dbQuery;
  const result = await query<ProfileAuthRow>(
    `SELECT id, username, full_name, avatar_url, cover_url, phone, address,
            role, email, status, city, auth_provider, auth_providers,
            writer_application_status, writer_application_at
       FROM public.profiles
      WHERE id = $1::uuid
      LIMIT 1`,
    [userId],
  );
  return result.rows[0] || null;
}

async function profileByEmail(email: string, client?: DatabaseClient) {
  const query = client?.query.bind(client) || dbQuery;
  const result = await query<ProfileAuthRow>(
    `SELECT id, username, full_name, avatar_url, cover_url, phone, address,
            role, email, status, city, auth_provider, auth_providers,
            writer_application_status, writer_application_at
       FROM public.profiles
      WHERE lower(email) = lower($1)
      LIMIT 1`,
    [cleanEmail(email)],
  );
  return result.rows[0] || null;
}

export async function setPasswordForUser(
  userId: string,
  password: string,
  client?: DatabaseClient,
) {
  const cleanUserId = cleanText(userId);
  if (!cleanUserId || !password) return;
  const query = client?.query.bind(client) || dbQuery;
  await query(
    `INSERT INTO public.profile_auth_credentials (
       user_id, password_hash, password_algorithm, migrated_from, updated_at
     )
     VALUES ($1::uuid, extensions.crypt($2::text, extensions.gen_salt('bf')), 'pg_crypt_bf', NULL, now())
     ON CONFLICT (user_id) DO UPDATE
     SET password_hash = EXCLUDED.password_hash,
         password_algorithm = EXCLUDED.password_algorithm,
         migrated_from = NULL,
         updated_at = now()`,
    [cleanUserId, password],
  );
}

export async function signInWithPassword(email: string, password: string) {
  try {
    const cleanLoginEmail = cleanEmail(email);
    const result = await dbQuery<ProfileAuthRow & { password_ok: boolean }>(
      `SELECT p.id, p.username, p.full_name, p.avatar_url, p.cover_url, p.phone,
              p.address, p.role, p.email, p.status, p.city, p.auth_provider,
              p.auth_providers, p.writer_application_status, p.writer_application_at,
              CASE
                WHEN c.password_hash IS NULL THEN false
                ELSE (c.password_hash = extensions.crypt($2::text, c.password_hash))
              END AS password_ok
         FROM public.profiles p
         LEFT JOIN public.profile_auth_credentials c ON c.user_id = p.id
        WHERE lower(p.email) = lower($1)
        LIMIT 1`,
      [cleanLoginEmail, password],
    );
    const profile = result.rows[0] || null;
    if (profile && String(profile.status || '').toLowerCase() === 'blocked') {
      return { data: { user: null, session: null }, error: { message: 'Account is blocked' } };
    }
    if (!profile?.password_ok) {
      const legacyResult = await signInWithSupabasePassword(cleanLoginEmail, password);
      const legacyUserId = legacyResult.data.session?.user?.id || legacyResult.data.user?.id || '';
      const legacyProfile = legacyUserId ? await profileById(legacyUserId) : await profileByEmail(cleanLoginEmail);
      if (legacyResult.error || !legacyProfile?.id) {
        return { data: { user: null, session: null }, error: { message: 'Invalid login credentials' } };
      }
      if (String(legacyProfile.status || '').toLowerCase() === 'blocked') {
        return { data: { user: null, session: null }, error: { message: 'Account is blocked' } };
      }
      await setPasswordForUser(legacyProfile.id, password).catch(() => undefined);
      const session = await createSession(legacyProfile);
      return { data: { user: session.user, session }, error: null };
    }
    const session = await createSession(profile);
    return { data: { user: session.user, session }, error: null };
  } catch (error: any) {
    return { data: { user: null, session: null }, error: { message: error.message || 'Invalid login credentials' } };
  }
}

export async function signUpWithPassword(email: string, password: string, metadata: Record<string, any> = {}) {
  const client = await connectDbClient();
  try {
    await client.query('BEGIN');
    const userId = crypto.randomUUID();
    const username = await uniqueUsername(
      client,
      cleanSignupUsernameBase(cleanText(metadata.full_name || metadata.username), email),
    );
    const fullName = cleanText(metadata.full_name || metadata.name || username);
    const city = cleanText(metadata.city) || DEFAULT_CITY;
    await client.query(
      `INSERT INTO public.profiles (
         id, username, slug, full_name, email, city, role, status,
         auth_provider, auth_providers, updated_at
       )
       VALUES (
         $1::uuid, $2, $2, $3, $4, $5, 'member', 'Aktif',
         'email', ARRAY['email']::text[], now()
       )`,
      [userId, username, fullName, cleanEmail(email), city],
    );
    await setPasswordForUser(userId, password, client);
    const profile = await profileById(userId, client);
    if (!profile) throw new Error('Profile could not be created');
    await client.query('COMMIT');
    const session = await createSession(profile);
    return { data: { user: session.user, session }, error: null };
  } catch (error: any) {
    await client.query('ROLLBACK').catch(() => undefined);
    return { data: { user: null, session: null }, error: { message: error.message || 'Sign up failed' } };
  } finally {
    client.release();
  }
}

export async function updateUser(token: string | null | undefined, attrs: { password?: string; email?: string }) {
  const session = await getSessionFromToken(token);
  if (!session?.user?.id) return { data: { user: null }, error: { message: 'Auth session missing' } };
  try {
    if (attrs.email) {
      await dbQuery(
        `UPDATE public.profiles
            SET email = $1,
                updated_at = now()
          WHERE id = $2::uuid`,
        [cleanEmail(attrs.email), session.user.id],
      );
    }
    if (attrs.password) {
      await setPasswordForUser(session.user.id, attrs.password);
    }
    const profile = await profileById(session.user.id);
    return { data: { user: profile ? userFromProfile(profile) : session.user }, error: null };
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
  return {
    id: crypto.randomUUID(),
    email: cleanEmail(input.email),
    role: 'authenticated',
    aud: AUTH_AUDIENCE,
    user_metadata: input.userMetadata || {},
    app_metadata: input.appMetadata || { provider: 'email', providers: ['email'] },
  } as AppAuthUser;
}

export async function adminUpdateAuthUser(userId: string, attrs: {
  email?: string;
  password?: string;
  userMetadata?: Record<string, any>;
  appMetadata?: Record<string, any>;
}) {
  const cleanUserId = cleanText(userId);
  if (!cleanUserId) throw new Error('User missing');
  if (attrs.email) {
    await dbQuery(
      `UPDATE public.profiles
          SET email = $1,
              updated_at = now()
        WHERE id = $2::uuid`,
      [cleanEmail(attrs.email), cleanUserId],
    );
  }
  if (attrs.password) {
    await setPasswordForUser(cleanUserId, attrs.password);
  }
  const profile = await profileById(cleanUserId);
  if (!profile) throw new Error('Kullanıcı bulunamadı');
  return userFromProfile(profile);
}

export async function adminDeleteAuthUser(userId: string) {
  const cleanUserId = cleanText(userId);
  if (!cleanUserId) return;
  await dbQuery('DELETE FROM public.profile_auth_credentials WHERE user_id = $1::uuid', [cleanUserId]).catch(() => undefined);
  await dbQuery('DELETE FROM public.profile_auth_identities WHERE user_id = $1::uuid', [cleanUserId]).catch(() => undefined);
}

function cleanSignupUsernameBase(fullName: string, email: string) {
  const source = fullName || email.split('@')[0] || 'uye';
  const normalized = source
    .toLocaleLowerCase('tr-TR')
    .replace(/ğ/g, 'g')
    .replace(/ü/g, 'u')
    .replace(/ş/g, 's')
    .replace(/ı/g, 'i')
    .replace(/ö/g, 'o')
    .replace(/ç/g, 'c')
    .normalize('NFD')
    .replace(/[\u0300-\u036f]/g, '')
    .replace(/[^a-z0-9._-]+/g, '-')
    .replace(/^-+|-+$/g, '')
    .slice(0, 70);
  return normalized.length >= 3 ? normalized : `uye-${normalized || 'pateez'}`;
}

async function uniqueUsername(client: Pick<DatabaseClient, 'query'>, base: string, excludeUserId = '') {
  for (let index = 0; index < 50; index += 1) {
    const candidate = index === 0 ? base : `${base}${index + 1}`;
    const result = await client.query(
      `SELECT 1
         FROM public.profiles
        WHERE ($2::uuid IS NULL OR id <> $2::uuid)
          AND (lower(username) = lower($1) OR lower(slug) = lower($1))
        LIMIT 1`,
      [candidate, excludeUserId || null],
    );
    if (!result.rows[0]) return candidate;
  }
  return `${base.slice(0, 58)}-${Date.now().toString(36).slice(-6)}`;
}

function boolClaim(value: unknown) {
  if (typeof value === 'boolean') return value;
  if (typeof value === 'string') return value.toLowerCase() === 'true';
  return null;
}

async function verifyGoogleIdToken(idToken: string): Promise<ProviderProfile> {
  const { payload } = await jwtVerify(idToken, googleJwks(), {
    algorithms: ['RS256'],
    issuer: ['https://accounts.google.com', 'accounts.google.com'],
    audience: configuredGoogleClientIds(),
    clockTolerance: 30,
  });
  const sub = cleanText(payload.sub);
  if (!sub) throw new Error('Google kullanıcı kimliği alınamadı');
  return {
    provider: 'google',
    providerUserId: sub,
    email: cleanEmail(payload.email),
    emailVerified: boolClaim(payload.email_verified),
    displayName: cleanText(payload.name),
    username: cleanText(payload.preferred_username),
    avatarUrl: cleanText(payload.picture),
    coverUrl: '',
    phone: cleanText((payload as any).phone_number),
    address: cleanText((payload as any).address),
    rawProfile: payload as Record<string, any>,
  };
}

async function verifyGoogleAccessToken(accessToken: string): Promise<ProviderProfile> {
  const tokenInfoUrl = new URL('https://oauth2.googleapis.com/tokeninfo');
  tokenInfoUrl.searchParams.set('access_token', accessToken);
  const tokenInfoResponse = await fetch(tokenInfoUrl);
  const tokenInfo = await tokenInfoResponse.json().catch(() => null);
  if (!tokenInfoResponse.ok || !tokenInfo) throw new Error('Google token doğrulanamadı');
  const aud = cleanText(tokenInfo.aud);
  if (!configuredGoogleClientIds().includes(aud)) throw new Error('Google client ID eşleşmedi');

  const profileResponse = await fetch('https://openidconnect.googleapis.com/v1/userinfo', {
    headers: { Authorization: `Bearer ${accessToken}` },
  });
  const profile = await profileResponse.json().catch(() => null);
  if (!profileResponse.ok || !profile?.sub) throw new Error('Google profil bilgisi alınamadı');
  return {
    provider: 'google',
    providerUserId: cleanText(profile.sub),
    email: cleanEmail(profile.email),
    emailVerified: boolClaim(profile.email_verified),
    displayName: cleanText(profile.name),
    username: cleanText(profile.preferred_username),
    avatarUrl: cleanText(profile.picture),
    coverUrl: '',
    phone: cleanText(profile.phone_number),
    address: cleanText(profile.address),
    rawProfile: { tokenInfo, profile },
  };
}

async function verifyAppleIdToken(
  idToken: string,
  input: { fullName?: unknown; email?: unknown } = {},
): Promise<ProviderProfile> {
  const { payload } = await jwtVerify(idToken, appleJwks(), {
    algorithms: ['RS256'],
    issuer: 'https://appleid.apple.com',
    audience: configuredAppleClientIds(),
    clockTolerance: 30,
  });
  const sub = cleanText(payload.sub);
  if (!sub) throw new Error('Apple kullanıcı kimliği alınamadı');
  return {
    provider: 'apple',
    providerUserId: sub,
    email: cleanEmail(payload.email || input.email),
    emailVerified: boolClaim(payload.email_verified),
    displayName: cleanText(input.fullName || payload.name),
    username: '',
    avatarUrl: '',
    coverUrl: '',
    phone: '',
    address: '',
    rawProfile: payload as Record<string, any>,
  };
}

function facebookAppSecretProof(accessToken: string) {
  const secret = readRuntimeEnv('FACEBOOK_APP_SECRET') || readRuntimeEnv('META_APP_SECRET');
  if (!secret) return '';
  return crypto.createHmac('sha256', secret).update(accessToken).digest('hex');
}

async function verifyFacebookAccessToken(accessToken: string): Promise<ProviderProfile> {
  const url = new URL('https://graph.facebook.com/v25.0/me');
  url.searchParams.set('fields', 'id,name,first_name,last_name,email,picture.width(512).height(512)');
  url.searchParams.set('access_token', accessToken);
  const proof = facebookAppSecretProof(accessToken);
  if (proof) url.searchParams.set('appsecret_proof', proof);
  const response = await fetch(url);
  const profile = await response.json().catch(() => null);
  if (!response.ok || !profile?.id) throw new Error(profile?.error?.message || 'Facebook profil bilgisi alınamadı');
  return {
    provider: 'facebook',
    providerUserId: cleanText(profile.id),
    email: cleanEmail(profile.email),
    emailVerified: profile.email ? true : null,
    displayName: cleanText(profile.name || `${profile.first_name || ''} ${profile.last_name || ''}`),
    username: '',
    avatarUrl: cleanText(profile.picture?.data?.url),
    coverUrl: '',
    phone: '',
    address: '',
    rawProfile: profile,
  };
}

async function fetchXProfileFrom(url: string, accessToken: string) {
  const response = await fetch(url, {
    headers: { Authorization: `Bearer ${accessToken}` },
  });
  const payload = await response.json().catch(() => null);
  if (!response.ok || !payload?.data?.id) {
    throw new Error(payload?.detail || payload?.title || 'X profil bilgisi alınamadı');
  }
  return payload.data as Record<string, any>;
}

async function verifyXAccessToken(accessToken: string): Promise<ProviderProfile> {
  const fields = [
    'id',
    'name',
    'username',
    'profile_image_url',
    'profile_banner_url',
    'confirmed_email',
    'location',
    'url',
    'description',
    'verified',
    'verified_type',
  ].join(',');
  const urls = [
    `https://api.x.com/2/users/me?user.fields=${encodeURIComponent(fields)}`,
    `https://api.twitter.com/2/users/me?user.fields=${encodeURIComponent(fields)}`,
  ];
  let profile: Record<string, any> | null = null;
  let lastError: unknown = null;
  for (const url of urls) {
    try {
      profile = await fetchXProfileFrom(url, accessToken);
      break;
    } catch (error) {
      lastError = error;
    }
  }
  if (!profile) throw lastError instanceof Error ? lastError : new Error('X profil bilgisi alınamadı');
  const avatar = cleanText(profile.profile_image_url).replace('_normal.', '_400x400.');
  return {
    provider: 'x',
    providerUserId: cleanText(profile.id),
    email: cleanEmail(profile.confirmed_email),
    emailVerified: profile.confirmed_email ? true : null,
    displayName: cleanText(profile.name),
    username: cleanText(profile.username),
    avatarUrl: avatar,
    coverUrl: cleanText(profile.profile_banner_url),
    phone: '',
    address: cleanText(profile.location),
    rawProfile: profile,
  };
}

async function providerProfileFromInput(input: {
  provider: unknown;
  idToken?: unknown;
  accessToken?: unknown;
  fullName?: unknown;
  email?: unknown;
}) {
  const provider = authProvider(input.provider);
  const idToken = cleanText(input.idToken);
  const accessToken = cleanText(input.accessToken);
  if (provider === 'google') {
    if (idToken) return verifyGoogleIdToken(idToken);
    if (accessToken) return verifyGoogleAccessToken(accessToken);
  }
  if (provider === 'apple' && idToken) {
    return verifyAppleIdToken(idToken, { fullName: input.fullName, email: input.email });
  }
  if (provider === 'facebook' && accessToken) {
    return verifyFacebookAccessToken(accessToken);
  }
  if ((provider === 'x' || provider === 'twitter') && accessToken) {
    return verifyXAccessToken(accessToken);
  }
  throw new Error('Sosyal giriş token bilgisi eksik');
}

async function existingUserIdForProvider(client: DatabaseClient, profile: ProviderProfile) {
  const identity = await client.query<{ user_id: string }>(
    `SELECT user_id
       FROM public.profile_auth_identities
      WHERE provider = $1
        AND provider_user_id = $2
      LIMIT 1`,
    [profile.provider, profile.providerUserId],
  );
  if (identity.rows[0]?.user_id) return identity.rows[0].user_id;
  if (!profile.email) return '';
  const byEmail = await client.query<{ id: string }>(
    `SELECT id
       FROM public.profiles
      WHERE lower(email) = lower($1)
      LIMIT 1`,
    [profile.email],
  );
  return byEmail.rows[0]?.id || '';
}

async function upsertSocialProfile(
  client: DatabaseClient,
  providerProfile: ProviderProfile,
  location: ProfileLoginLocation = {},
) {
  const existingUserId = await existingUserIdForProvider(client, providerProfile);
  const userId = existingUserId || crypto.randomUUID();
  const ipAddress = cleanIpAddress(location.ipAddress);
  const signupCity = cleanSignupCity(location.signupCity);
  const usernameBase = cleanSignupUsernameBase(
    providerProfile.username || providerProfile.displayName,
    providerProfile.email || `${providerProfile.provider}-${providerProfile.providerUserId}`,
  );
  const username = existingUserId
    ? usernameBase
    : await uniqueUsername(client, usernameBase);
  const displayName =
    providerProfile.displayName ||
    providerProfile.username ||
    (providerProfile.email ? providerProfile.email.split('@')[0] : 'Pateez');

  await client.query(
    `INSERT INTO public.profiles (
       id, username, slug, full_name, email, avatar_url, cover_url, phone,
       address, city, role, status, auth_provider, auth_providers,
       ip_address, signup_city, is_logged_in, last_login_at, updated_at
     )
     VALUES (
       $1::uuid, $2, $2, $3, NULLIF($4, ''), NULLIF($5, ''),
       NULLIF($6, ''), NULLIF($7, ''), NULLIF($8, ''), $9, 'member',
       'Aktif', $10, ARRAY[$10]::text[], NULLIF($11, ''), NULLIF($12, ''),
       true, now(), now()
     )
     ON CONFLICT (id) DO UPDATE
     SET username = COALESCE(NULLIF(public.profiles.username, ''), EXCLUDED.username),
         slug = COALESCE(NULLIF(public.profiles.slug, ''), EXCLUDED.slug),
         full_name = COALESCE(NULLIF(public.profiles.full_name, ''), EXCLUDED.full_name),
         email = COALESCE(NULLIF(public.profiles.email, ''), EXCLUDED.email),
         avatar_url = COALESCE(NULLIF(public.profiles.avatar_url, ''), EXCLUDED.avatar_url),
         cover_url = COALESCE(NULLIF(public.profiles.cover_url, ''), EXCLUDED.cover_url),
         phone = COALESCE(NULLIF(public.profiles.phone, ''), EXCLUDED.phone),
         address = COALESCE(NULLIF(public.profiles.address, ''), EXCLUDED.address),
         city = COALESCE(NULLIF(public.profiles.city, ''), EXCLUDED.city),
         ip_address = COALESCE(NULLIF(public.profiles.ip_address, ''), EXCLUDED.ip_address, ''),
         signup_city = COALESCE(NULLIF(public.profiles.signup_city, ''), EXCLUDED.signup_city, ''),
         status = COALESCE(NULLIF(public.profiles.status, ''), 'Aktif'),
         auth_provider = EXCLUDED.auth_provider,
         auth_providers = (
           SELECT ARRAY(
             SELECT DISTINCT provider_value
               FROM unnest(
                 COALESCE(public.profiles.auth_providers, ARRAY[]::text[]) ||
                 EXCLUDED.auth_providers
              ) AS providers(provider_value)
             WHERE provider_value <> ''
           )
         ),
         is_logged_in = true,
         last_login_at = now(),
         updated_at = now()`,
    [
      userId,
      username,
      displayName,
      providerProfile.email,
      providerProfile.avatarUrl,
      providerProfile.coverUrl,
      providerProfile.phone,
      providerProfile.address,
      DEFAULT_CITY,
      providerProfile.provider,
      ipAddress,
      signupCity,
    ],
  );

  await client.query(
    `INSERT INTO public.profile_auth_identities (
       user_id, provider, provider_user_id, email, email_verified,
       display_name, avatar_url, cover_url, phone, address, raw_profile,
       updated_at
     )
     VALUES (
       $1::uuid, $2, $3, NULLIF($4, ''), $5, NULLIF($6, ''),
       NULLIF($7, ''), NULLIF($8, ''), NULLIF($9, ''), NULLIF($10, ''),
       $11::jsonb, now()
     )
     ON CONFLICT (provider, provider_user_id) DO UPDATE
     SET user_id = EXCLUDED.user_id,
         email = COALESCE(NULLIF(EXCLUDED.email, ''), public.profile_auth_identities.email),
         email_verified = COALESCE(EXCLUDED.email_verified, public.profile_auth_identities.email_verified),
         display_name = COALESCE(NULLIF(EXCLUDED.display_name, ''), public.profile_auth_identities.display_name),
         avatar_url = COALESCE(NULLIF(EXCLUDED.avatar_url, ''), public.profile_auth_identities.avatar_url),
         cover_url = COALESCE(NULLIF(EXCLUDED.cover_url, ''), public.profile_auth_identities.cover_url),
         phone = COALESCE(NULLIF(EXCLUDED.phone, ''), public.profile_auth_identities.phone),
         address = COALESCE(NULLIF(EXCLUDED.address, ''), public.profile_auth_identities.address),
         raw_profile = EXCLUDED.raw_profile,
         updated_at = now()`,
    [
      userId,
      providerProfile.provider,
      providerProfile.providerUserId,
      providerProfile.email,
      providerProfile.emailVerified,
      providerProfile.displayName,
      providerProfile.avatarUrl,
      providerProfile.coverUrl,
      providerProfile.phone,
      providerProfile.address,
      JSON.stringify(providerProfile.rawProfile || {}),
    ],
  );

  const profile = await profileById(userId, client);
  if (!profile) throw new Error('Sosyal profil oluşturulamadı');
  if (String(profile.status || '').toLowerCase() === 'blocked') {
    throw new Error('Account is blocked');
  }
  return profile;
}

export async function signInWithSocialToken(input: {
  provider: unknown;
  idToken?: unknown;
  accessToken?: unknown;
  fullName?: unknown;
  email?: unknown;
  ipAddress?: unknown;
  signupCity?: unknown;
}) {
  const providerProfile = await providerProfileFromInput(input);
  const client = await connectDbClient();
  try {
    await client.query('BEGIN');
    const profile = await upsertSocialProfile(client, providerProfile, {
      ipAddress: input.ipAddress,
      signupCity: input.signupCity,
    });
    await client.query('COMMIT');
    const session = await createSession(profile);
    return { data: { user: session.user, session, profile }, error: null };
  } catch (error) {
    await client.query('ROLLBACK').catch(() => undefined);
    throw error;
  } finally {
    client.release();
  }
}

export function publicSiteUrl() {
  return (
    readRuntimeEnv('PUBLIC_SITE_URL') ||
    readRuntimeEnv('SITE_URL') ||
    readRuntimeEnv('PUBLIC_APP_URL') ||
    'https://pateez.com'
  ).replace(/\/$/, '');
}

export function socialClientConfig() {
  return {
    googleWebClientId: configuredGoogleClientIds()[0] || '',
    appleServiceId: readRuntimeEnv('APPLE_SERVICE_ID') || 'com.pateez.pateezcom.web',
    facebookAppId: readRuntimeEnv('FACEBOOK_APP_ID') || readRuntimeEnv('META_APP_ID') || '929495530098255',
    xClientId: readRuntimeEnv('X_CLIENT_ID') || readRuntimeEnv('TWITTER_CLIENT_ID') || '',
  };
}
