import crypto from 'crypto';
import bcrypt from 'bcryptjs';
import { dbQuery } from './neonDb';

export interface NeonUser {
  id: string;
  email: string | null;
  role?: string | null;
  aud?: string | null;
  user_metadata?: Record<string, any>;
  app_metadata?: Record<string, any>;
}

export interface NeonSession {
  access_token: string;
  token_type: 'bearer';
  expires_at: number;
  user: NeonUser;
}

function authSecret() {
  const env = import.meta.env as Record<string, string | undefined>;
  return process.env.NEON_AUTH_SECRET || env.NEON_AUTH_SECRET || process.env.DATABASE_URL || env.DATABASE_URL || 'pateeznews-dev-secret';
}

function base64url(input: Buffer | string) {
  return Buffer.from(input).toString('base64url');
}

function sign(payload: string) {
  return crypto.createHmac('sha256', authSecret()).update(payload).digest('base64url');
}

function makeToken(user: NeonUser) {
  const expiresAt = Math.floor(Date.now() / 1000) + 60 * 60 * 24 * 30;
  const payload = base64url(JSON.stringify({
    sub: user.id,
    email: user.email,
    role: 'authenticated',
    exp: expiresAt,
  }));
  return {
    token: `${payload}.${sign(payload)}`,
    expiresAt,
  };
}

function verifyToken(token?: string | null) {
  if (!token || !token.includes('.')) return null;
  const [payload, signature] = token.split('.');
  if (!payload || !signature) return null;
  const expected = sign(payload);
  if (signature.length !== expected.length) return null;
  if (!crypto.timingSafeEqual(Buffer.from(signature), Buffer.from(expected))) return null;

  const parsed = JSON.parse(Buffer.from(payload, 'base64url').toString('utf8'));
  if (!parsed.exp || parsed.exp < Math.floor(Date.now() / 1000)) return null;
  return parsed as { sub: string; email?: string; exp: number };
}

function toUser(row: any): NeonUser {
  return {
    id: row.id,
    email: row.email,
    role: row.role,
    aud: row.aud,
    user_metadata: row.raw_user_meta_data || {},
    app_metadata: row.raw_app_meta_data || {},
  };
}

async function sessionForUser(user: NeonUser): Promise<NeonSession> {
  const { token, expiresAt } = makeToken(user);
  return {
    access_token: token,
    token_type: 'bearer',
    expires_at: expiresAt,
    user,
  };
}

export async function getSessionFromToken(token?: string | null) {
  const payload = verifyToken(token);
  if (!payload) return null;

  const result = await dbQuery(
    `SELECT id, email, role, aud, raw_user_meta_data, raw_app_meta_data
     FROM auth.users
     WHERE id = $1 AND deleted_at IS NULL
     LIMIT 1`,
    [payload.sub]
  );

  const user = result.rows[0] ? toUser(result.rows[0]) : null;
  return user ? sessionForUser(user) : null;
}

export async function signInWithPassword(email: string, password: string) {
  const result = await dbQuery(
    `SELECT id, email, role, aud, encrypted_password, raw_user_meta_data, raw_app_meta_data
     FROM auth.users
     WHERE lower(email) = lower($1) AND deleted_at IS NULL
     LIMIT 1`,
    [email]
  );

  const row = result.rows[0];
  const ok = row?.encrypted_password
    ? await bcrypt.compare(password, row.encrypted_password)
    : false;

  if (!ok) {
    return { data: { user: null, session: null }, error: { message: 'Invalid login credentials' } };
  }

  await dbQuery('UPDATE auth.users SET last_sign_in_at = now(), updated_at = now() WHERE id = $1', [row.id]);
  const user = toUser(row);
  return { data: { user, session: await sessionForUser(user) }, error: null };
}

export async function signUpWithPassword(email: string, password: string, metadata: Record<string, any> = {}) {
  const existing = await dbQuery('SELECT id FROM auth.users WHERE lower(email) = lower($1) LIMIT 1', [email]);
  if (existing.rows[0]) {
    return { data: { user: null, session: null }, error: { message: 'User already registered' } };
  }

  const hash = await bcrypt.hash(password, 10);
  const result = await dbQuery(
    `INSERT INTO auth.users (
       id, aud, role, email, encrypted_password, email_confirmed_at,
       raw_app_meta_data, raw_user_meta_data, created_at, updated_at
     )
     VALUES (
       gen_random_uuid(), 'authenticated', 'authenticated', $1, $2, now(),
       '{"provider":"email","providers":["email"]}'::jsonb, $3::jsonb, now(), now()
     )
     RETURNING id, email, role, aud, raw_user_meta_data, raw_app_meta_data`,
    [email, hash, JSON.stringify(metadata || {})]
  );

  const user = toUser(result.rows[0]);
  return { data: { user, session: await sessionForUser(user) }, error: null };
}

export async function updateUser(token: string | null | undefined, attrs: { password?: string; email?: string }) {
  const session = await getSessionFromToken(token);
  if (!session) return { data: { user: null }, error: { message: 'Auth session missing' } };

  if (attrs.password) {
    const hash = await bcrypt.hash(attrs.password, 10);
    await dbQuery('UPDATE auth.users SET encrypted_password = $1, updated_at = now() WHERE id = $2', [hash, session.user.id]);
  }

  if (attrs.email) {
    await dbQuery('UPDATE auth.users SET email = $1, updated_at = now() WHERE id = $2', [attrs.email, session.user.id]);
  }

  const nextSession = await getSessionFromToken(session.access_token);
  return { data: { user: nextSession?.user || session.user }, error: null };
}
