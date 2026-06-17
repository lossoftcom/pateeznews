import { getProfileRole, getSessionFromRequest, json } from '@/lib/server/appDb';
import { dbQuery } from '@/lib/server/supabaseDb';
import { ensureNotificationsSchema } from './schema';

const ALLOWED_PLATFORMS = new Set([
  'android',
  'ios',
  'flutter_web',
  'astro_web',
  'web',
]);

export async function readJsonBody(request: Request) {
  try {
    return await request.json();
  } catch {
    return {};
  }
}

export async function requireNotificationAccess(request: Request, body?: Record<string, any>) {
  const session = await getSessionFromRequest(request, body);
  if (!session?.user?.id) {
    return { session: null, response: json({ error: { message: 'Auth required' } }, 401) };
  }

  await ensureNotificationsSchema();

  const role = String(await getProfileRole(session.user.id)).toLowerCase();
  if (role === 'admin' || role === 'super_admin') {
    return { session, response: null };
  }

  const result = await dbQuery(
    `SELECT rp.permission_key
     FROM public.profiles p
     JOIN public.roles r ON r.name = p.role
     JOIN public.role_permissions rp ON rp.role_id = r.id
     WHERE p.id = $1 AND rp.permission_key IN ('notifications_access', 'manage_notifications')
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

export function normalizeText(value: unknown) {
  return String(value || '').trim();
}

export function normalizePriority(value: unknown) {
  const priority = normalizeText(value).toLowerCase();
  return priority === 'high' ? 'high' : 'normal';
}

export function normalizeStatus(value: unknown, fallback = 'draft') {
  const status = normalizeText(value).toLowerCase();
  return [
    'draft',
    'scheduled',
    'sending',
    'paused',
    'completed',
    'failed',
    'cancelled',
  ].includes(status)
    ? status
    : fallback;
}

export function normalizeTargetType(value: unknown) {
  const targetType = normalizeText(value).toLowerCase();
  return ['all', 'platform', 'topic', 'user', 'token', 'segment'].includes(targetType)
    ? targetType
    : 'all';
}

export function normalizePlatform(value: unknown) {
  const platform = normalizeText(value).toLowerCase();
  return ALLOWED_PLATFORMS.has(platform) ? platform : 'web';
}

export function normalizeStringArray(value: unknown) {
  const values = Array.isArray(value) ? value : String(value || '').split(/[\n,;|]+/g);
  return Array.from(
    new Set(
      values
        .map((item) => normalizeText(item))
        .filter(Boolean)
    )
  );
}

export function normalizeNumberArray(value: unknown) {
  const values = Array.isArray(value) ? value : String(value || '').split(/[\n,;|]+/g);
  return Array.from(
    new Set(
      values
        .map((item) => Number(item))
        .filter((item) => Number.isFinite(item) && item > 0)
        .map((item) => Math.floor(item))
    )
  );
}

export function normalizeJsonObject(value: unknown) {
  if (value && typeof value === 'object' && !Array.isArray(value)) return value as Record<string, unknown>;
  if (typeof value === 'string' && value.trim()) {
    try {
      const parsed = JSON.parse(value);
      if (parsed && typeof parsed === 'object' && !Array.isArray(parsed)) return parsed as Record<string, unknown>;
    } catch {
      return {};
    }
  }
  return {};
}

export function sqlSetClause(update: Record<string, any>, startingIndex = 1) {
  const keys = Object.keys(update);
  return {
    keys,
    values: keys.map((key) => update[key]),
    clause: keys.map((key, index) => `${key} = $${startingIndex + index}`).join(', '),
  };
}
