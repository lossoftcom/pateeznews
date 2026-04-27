import pg from 'pg';
import type { QueryResultRow } from 'pg';

const { Pool } = pg;

type PoolGlobal = typeof globalThis & {
  __pateezNeonPool?: pg.Pool;
};

function normalizeDatabaseUrl(url: string) {
  try {
    const parsed = new URL(url);
    const sslMode = parsed.searchParams.get('sslmode');
    if (!sslMode || ['prefer', 'require', 'verify-ca'].includes(sslMode)) {
      parsed.searchParams.set('sslmode', 'verify-full');
    }
    // channel_binding is a libpq flag and can break parsing in some Node runtimes.
    parsed.searchParams.delete('channel_binding');
    return parsed.toString();
  } catch {
    return url;
  }
}

export function getDatabaseUrl() {
  const env = import.meta.env as Record<string, string | undefined>;
  const url = process.env.NEON_DATABASE_URL || process.env.DATABASE_URL || env.NEON_DATABASE_URL || env.DATABASE_URL;
  if (!url) {
    throw new Error('NEON_DATABASE_URL or DATABASE_URL is missing');
  }
  return normalizeDatabaseUrl(url);
}

export function getPool() {
  const g = globalThis as PoolGlobal;
  if (!g.__pateezNeonPool) {
    g.__pateezNeonPool = new Pool({
      connectionString: getDatabaseUrl(),
      max: 5,
      idleTimeoutMillis: 10_000,
      connectionTimeoutMillis: 10_000,
    });
  }
  return g.__pateezNeonPool;
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
  const result = await getPool().query<T>(text, values);
  if (Array.isArray(result)) {
    const lastResult = result[result.length - 1] as typeof result[number] | undefined;
    if (lastResult?.rows) lastResult.rows = lastResult.rows.map(serializeDatabaseValue);
    return (lastResult || { rows: [] }) as any;
  }
  result.rows = (result.rows || []).map(serializeDatabaseValue);
  return result;
}
