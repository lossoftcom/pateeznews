import pg from 'pg';
import type { QueryResultRow } from 'pg';
import {
  getHyperdriveConnectionString,
  readRuntimeEnv,
} from './runtimeEnv';

const { Client, Pool } = pg;

type PoolGlobal = typeof globalThis & {
  __pateezDatabasePool?: pg.Pool;
  __pateezDatabasePoolUrl?: string;
};

export type DatabaseClient = (pg.PoolClient | pg.Client) & {
  __pateezDatabaseRole?: string;
  release: () => void | Promise<void>;
};

interface DatabaseConnectionConfig {
  url: string;
  usesHyperdriveBinding: boolean;
  usesLocalHyperdriveBinding: boolean;
}

type RoleMode = 'direct' | 'set-role';

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

function getDatabaseConnectionConfig(): DatabaseConnectionConfig {
  const hyperdriveUrl = getHyperdriveConnectionString();
  const url =
    hyperdriveUrl ||
    readRuntimeEnv('PATEEZ_ADMIN_API_DATABASE_URL') ||
    readRuntimeEnv('HYPERDRIVE_DATABASE_URL') ||
    readRuntimeEnv('CLOUDFLARE_HYPERDRIVE_DATABASE_URL') ||
    readRuntimeEnv('SUPABASE_POOLER_DATABASE_URL') ||
    readRuntimeEnv('SUPABASE_DATABASE_URL') ||
    readRuntimeEnv('POSTGRES_URL') ||
    readRuntimeEnv('DATABASE_URL');
  if (!url) {
    throw new Error('PATEEZ_ADMIN_API_DATABASE_URL, HYPERDRIVE binding, HYPERDRIVE_DATABASE_URL, SUPABASE_POOLER_DATABASE_URL, SUPABASE_DATABASE_URL, POSTGRES_URL, or DATABASE_URL is missing');
  }
  const normalizedUrl = normalizeDatabaseUrl(url);
  const usesLocalHyperdriveBinding = Boolean(hyperdriveUrl && isLocalHyperdriveEmulation(hyperdriveUrl));
  return {
    url: normalizedUrl,
    usesLocalHyperdriveBinding,
    usesHyperdriveBinding: Boolean(
      hyperdriveUrl &&
      normalizedUrl === normalizeDatabaseUrl(hyperdriveUrl) &&
      !usesLocalHyperdriveBinding
    ),
  };
}

export function getDatabaseUrl() {
  return getDatabaseConnectionConfig().url;
}

function getDatabaseRole() {
  const role = (readRuntimeEnv('PATEEZ_ADMIN_API_DB_ROLE') || 'pateez_admin_api').trim();
  if (!role) return '';
  if (!/^[A-Za-z_][A-Za-z0-9_]*$/.test(role)) {
    throw new Error(`Unsafe database role: ${role}`);
  }
  return role;
}

function quoteRole(role: string) {
  return `"${role.replaceAll('"', '""')}"`;
}

function databaseUrlUser(url: string) {
  try {
    return decodeURIComponent(new URL(url).username || '');
  } catch {
    return '';
  }
}

function isLocalHyperdriveDevelopment() {
  return import.meta.env.DEV || readRuntimeEnv('NODE_ENV') === 'development';
}

function isLocalHyperdriveEmulation(hyperdriveUrl: string) {
  const localUrl = readRuntimeEnv('CLOUDFLARE_HYPERDRIVE_LOCAL_CONNECTION_STRING_HYPERDRIVE');
  if (!localUrl) return false;
  if (normalizeDatabaseUrl(localUrl) === normalizeDatabaseUrl(hyperdriveUrl)) return true;
  return isLocalHyperdriveDevelopment();
}

function databaseRoleMode(url: string, usesHyperdriveBinding: boolean): RoleMode {
  const role = getDatabaseRole();
  if (!role) return 'direct';
  if (usesHyperdriveBinding) return 'direct';
  const user = databaseUrlUser(url);
  if (user === role) return 'direct';
  return 'set-role';
}

export function getPool() {
  const g = globalThis as PoolGlobal;
  const { url, usesHyperdriveBinding, usesLocalHyperdriveBinding } = getDatabaseConnectionConfig();
  if (usesHyperdriveBinding || usesLocalHyperdriveBinding) {
    throw new Error('Cloudflare Hyperdrive uses per-request database clients, not the global pool');
  }
  databaseRoleMode(url, usesHyperdriveBinding);
  if (!g.__pateezDatabasePool || g.__pateezDatabasePoolUrl !== url) {
    if (g.__pateezDatabasePool) {
      void g.__pateezDatabasePool.end();
    }
    g.__pateezDatabasePool = new Pool({
      connectionString: url,
      max: 5,
      idleTimeoutMillis: 10_000,
      connectionTimeoutMillis: 10_000,
    });
    g.__pateezDatabasePoolUrl = url;
  }
  return g.__pateezDatabasePool;
}

async function applyDatabaseRole(client: DatabaseClient, url: string, mode: RoleMode) {
  const role = getDatabaseRole();
  if (!role || client.__pateezDatabaseRole === role) return;
  if (mode === 'direct') {
    client.__pateezDatabaseRole = role;
    return;
  }
  if (mode === 'set-role') {
    await client.query(`SET ROLE ${quoteRole(role)}`);
    client.__pateezDatabaseRole = role;
  }
}

async function connectSingleUseClient(url: string, mode: RoleMode) {
  const pgClient = new Client({
    connectionString: url,
    connectionTimeoutMillis: 10_000,
  });
  await pgClient.connect();
  const client = pgClient as DatabaseClient;
  client.release = () => pgClient.end();
  try {
    await applyDatabaseRole(client, url, mode);
  } catch (error) {
    await client.release();
    throw error;
  }
  return client;
}

export async function connectDbClient(): Promise<DatabaseClient> {
  const { url, usesHyperdriveBinding, usesLocalHyperdriveBinding } = getDatabaseConnectionConfig();
  const mode = databaseRoleMode(url, usesHyperdriveBinding);
  if (usesHyperdriveBinding || usesLocalHyperdriveBinding) {
    return connectSingleUseClient(url, mode);
  }
  const client = await getPool().connect() as DatabaseClient;
  try {
    await applyDatabaseRole(client, url, mode);
  } catch (error) {
    client.release();
    throw error;
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

export async function dbQuery<T extends QueryResultRow = QueryResultRow>(
  text: string,
  values: unknown[] = []
): Promise<pg.QueryResult<T>> {
  const client = await connectDbClient();
  try {
    const result = await client.query<T>(text, values);
    if (Array.isArray(result)) {
      const lastResult = result[result.length - 1] as typeof result[number] | undefined;
      if (lastResult?.rows) lastResult.rows = lastResult.rows.map(serializeDatabaseValue) as T[];
      return (lastResult || { rows: [] }) as pg.QueryResult<T>;
    }
    result.rows = (result.rows || []).map(serializeDatabaseValue) as T[];
    return result;
  } finally {
    await client.release();
  }
}
