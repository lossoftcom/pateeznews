import { getProfileRole, getSessionFromRequest, json } from '@/lib/server/appDb';
import { dbQuery } from '@/lib/server/neonDb';
import { ensureMailSchema } from './schema';

const EMAIL_RE = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;

export async function readJsonBody(request: Request) {
  try {
    return await request.json();
  } catch {
    return {};
  }
}

export async function requireMailAccess(request: Request, body?: Record<string, any>) {
  const session = await getSessionFromRequest(request, body);
  if (!session?.user?.id) {
    return { session: null, response: json({ error: { message: 'Auth required' } }, 401) };
  }

  await ensureMailSchema();

  const role = String(await getProfileRole(session.user.id)).toLowerCase();
  if (role === 'admin' || role === 'super_admin') {
    return { session, response: null };
  }

  const result = await dbQuery(
    `SELECT rp.permission_key
     FROM public.profiles p
     JOIN public.roles r ON r.name = p.role
     JOIN public.role_permissions rp ON rp.role_id = r.id
     WHERE p.id = $1 AND rp.permission_key = 'manage_mail'
     LIMIT 1`,
    [session.user.id]
  );

  if (!result.rows[0]) {
    return { session: null, response: json({ error: { message: 'Forbidden' } }, 403) };
  }

  return { session, response: null };
}

export function numericLimit(value: unknown, fallback = 25, max = 200) {
  const number = Number(value);
  if (!Number.isFinite(number)) return fallback;
  return Math.min(Math.max(Math.floor(number), 1), max);
}

export function numericOffset(value: unknown) {
  const number = Number(value);
  if (!Number.isFinite(number)) return 0;
  return Math.max(Math.floor(number), 0);
}

export function normalizeEmail(value: unknown) {
  return String(value || '').trim().toLowerCase();
}

export function isEmail(value: unknown) {
  return EMAIL_RE.test(normalizeEmail(value));
}

export function parseEmailList(value: unknown) {
  const items = Array.isArray(value)
    ? value
    : String(value || '').split(/[\n,;]+/g);

  return Array.from(new Set(items.map(normalizeEmail).filter(isEmail)));
}

export function compactUpdate<T extends Record<string, any>>(input: T, allowed: string[]) {
  const update: Record<string, any> = {};
  for (const key of allowed) {
    if (Object.prototype.hasOwnProperty.call(input, key)) update[key] = input[key];
  }
  return update;
}

export function sqlSetClause(update: Record<string, any>, startingIndex = 1) {
  const keys = Object.keys(update);
  return {
    keys,
    values: keys.map((key) => update[key]),
    clause: keys.map((key, index) => `${key} = $${startingIndex + index}`).join(', '),
  };
}

export function rowCount(value: any) {
  return Number(value?.count || value?.total || 0);
}
