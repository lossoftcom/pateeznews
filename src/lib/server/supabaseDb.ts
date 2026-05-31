import pg from 'pg';
import type { QueryResultRow } from 'pg';

const { Pool } = pg;

type PoolGlobal = typeof globalThis & {
  __pateezDatabasePool?: pg.Pool;
};

type RolePoolClient = pg.PoolClient & {
  __pateezDatabaseRole?: string;
};

function normalizeDatabaseUrl(url: string) {
  try {
    const parsed = new URL(url);
    const sslMode = parsed.searchParams.get('sslmode');
    const isSupabaseHost =
      parsed.hostname.endsWith('.supabase.co') ||
      parsed.hostname.endsWith('.pooler.supabase.com');
    if (isSupabaseHost) {
      if (!sslMode) parsed.searchParams.set('sslmode', 'require');
      parsed.searchParams.set('uselibpqcompat', 'true');
    } else if (!sslMode || ['prefer', 'require', 'verify-ca'].includes(sslMode)) {
      parsed.searchParams.set('sslmode', 'verify-full');
    }
    // channel_binding is a libpq flag and can break parsing in some Node runtimes.
    parsed.searchParams.delete('channel_binding');
    return parsed.toString();
  } catch {
    return url;
  }
}

function readEnv(name: string) {
  const env = import.meta.env as Record<string, string | undefined>;
  return process.env[name] || env[name];
}

export function getDatabaseUrl() {
  const url =
    readEnv('PATEEZ_ADMIN_API_DATABASE_URL') ||
    readEnv('HYPERDRIVE_DATABASE_URL') ||
    readEnv('CLOUDFLARE_HYPERDRIVE_DATABASE_URL') ||
    readEnv('SUPABASE_POOLER_DATABASE_URL') ||
    readEnv('SUPABASE_DATABASE_URL') ||
    readEnv('POSTGRES_URL') ||
    readEnv('DATABASE_URL');
  if (!url) {
    throw new Error('PATEEZ_ADMIN_API_DATABASE_URL, HYPERDRIVE_DATABASE_URL, SUPABASE_POOLER_DATABASE_URL, SUPABASE_DATABASE_URL, POSTGRES_URL, or DATABASE_URL is missing');
  }
  return normalizeDatabaseUrl(url);
}

function getDatabaseRole() {
  const role = (readEnv('PATEEZ_ADMIN_API_DB_ROLE') || 'pateez_admin_api').trim();
  if (!role) return '';
  if (!/^[A-Za-z_][A-Za-z0-9_]*$/.test(role)) {
    throw new Error(`Unsafe database role: ${role}`);
  }
  return role;
}

function quoteRole(role: string) {
  return `"${role.replaceAll('"', '""')}"`;
}

export function getPool() {
  const g = globalThis as PoolGlobal;
  if (!g.__pateezDatabasePool) {
    g.__pateezDatabasePool = new Pool({
      connectionString: getDatabaseUrl(),
      max: 5,
      idleTimeoutMillis: 10_000,
      connectionTimeoutMillis: 10_000,
    });
  }
  return g.__pateezDatabasePool;
}

export async function connectDbClient() {
  const client = await getPool().connect() as RolePoolClient;
  const role = getDatabaseRole();
  if (role && client.__pateezDatabaseRole !== role) {
    await client.query(`SET ROLE ${quoteRole(role)}`);
    client.__pateezDatabaseRole = role;
  }
  return client;
}

function serializeDatabaseValue(value: any): any {
  if (value instanceof Date) return value.toISOString();
  if (Array.isArray(value)) return value.map(serializeDatabaseValue);
  if (value && typeof value === 'object' && !Buffer.isBuffer(value)) {
    return Object.fromEntries(
      Object.entries(value).map(([key, nestedValue]) => [key, serializeDatabaseValue(nestedValue)])
    );
  }
  return value;
}

export async function dbQuery<T extends QueryResultRow = QueryResultRow>(text: string, values: unknown[] = []) {
  const client = await connectDbClient();
  try {
    const result = await client.query<T>(text, values);
    if (Array.isArray(result)) {
      const lastResult = result[result.length - 1] as typeof result[number] | undefined;
      if (lastResult?.rows) lastResult.rows = lastResult.rows.map(serializeDatabaseValue);
      return (lastResult || { rows: [] }) as any;
    }
    result.rows = (result.rows || []).map(serializeDatabaseValue);
    return result;
  } finally {
    client.release();
  }
}
