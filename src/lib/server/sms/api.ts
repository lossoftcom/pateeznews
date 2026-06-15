import { getProfileRole, getSessionFromRequest, json } from '@/lib/server/appDb';
import { dbQuery } from '@/lib/server/supabaseDb';
import { ensureSmsSchema } from './schema';

const PHONE_RE = /^\+?[0-9][0-9\s().-]{6,}$/;

export async function readJsonBody(request: Request) {
  try {
    return await request.json();
  } catch {
    return {};
  }
}

export async function requireSmsAccess(request: Request, body?: Record<string, any>) {
  const session = await getSessionFromRequest(request, body);
  if (!session?.user?.id) {
    return { session: null, response: json({ error: { message: 'Auth required' } }, 401) };
  }

  await ensureSmsSchema();

  const role = String(await getProfileRole(session.user.id)).toLowerCase();
  if (role === 'admin' || role === 'super_admin') {
    return { session, response: null };
  }

  const result = await dbQuery(
    `SELECT rp.permission_key
     FROM public.profiles p
     JOIN public.roles r ON r.name = p.role
     JOIN public.role_permissions rp ON rp.role_id = r.id
     WHERE p.id = $1 AND rp.permission_key IN ('sms_access', 'manage_sms')
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

export function normalizePhone(value: unknown) {
  return String(value || '').replace(/[^\d+]/g, '').trim();
}

export function isPhone(value: unknown) {
  return PHONE_RE.test(String(value || '').trim()) && normalizePhone(value).length >= 7;
}

export function parsePhoneList(value: unknown) {
  const items = Array.isArray(value)
    ? value
    : String(value || '').split(/[\n,;|]+/g);

  return Array.from(new Set(items.map(normalizePhone).filter(isPhone)));
}

export function sqlSetClause(update: Record<string, any>, startingIndex = 1) {
  const keys = Object.keys(update);
  return {
    keys,
    values: keys.map((key) => update[key]),
    clause: keys.map((key, index) => `${key} = $${startingIndex + index}`).join(', '),
  };
}
