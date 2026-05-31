import fs from 'node:fs';

const ENV_FILES = ['.env', '.env.local', '.dev.vars'];

function unquoteEnvValue(value) {
  const trimmed = String(value || '').trim();
  if (
    (trimmed.startsWith('"') && trimmed.endsWith('"')) ||
    (trimmed.startsWith("'") && trimmed.endsWith("'"))
  ) {
    return trimmed.slice(1, -1);
  }
  return trimmed;
}

export function readLocalEnv(cwd = process.cwd()) {
  const values = {};
  for (const fileName of ENV_FILES) {
    const path = `${cwd}/${fileName}`;
    if (!fs.existsSync(path)) continue;
    for (const rawLine of fs.readFileSync(path, 'utf8').split(/\r?\n/)) {
      const line = rawLine.trim();
      if (!line || line.startsWith('#')) continue;
      const separatorIndex = line.indexOf('=');
      if (separatorIndex === -1) continue;
      const key = line.slice(0, separatorIndex).trim();
      if (!key) continue;
      values[key] = unquoteEnvValue(line.slice(separatorIndex + 1));
    }
  }
  return values;
}

export function mergedCloudflareEnv(cwd = process.cwd()) {
  const localEnv = readLocalEnv(cwd);
  const env = { ...localEnv, ...process.env };
  const supabaseUrl =
    env.SUPABASE_URL ||
    env.PUBLIC_SUPABASE_URL ||
    deriveSupabaseUrl(env.SUPABASE_DATABASE_URL || env.DATABASE_URL || env.POSTGRES_URL);
  const publishableKey =
    env.SUPABASE_PUBLISHABLE_KEY ||
    env.PUBLIC_SUPABASE_PUBLISHABLE_KEY;
  const hyperdriveLocalConnection =
    env.CLOUDFLARE_HYPERDRIVE_LOCAL_CONNECTION_STRING_HYPERDRIVE ||
    env.PATEEZ_ADMIN_API_DATABASE_URL ||
    env.SUPABASE_POOLER_DATABASE_URL ||
    env.SUPABASE_DATABASE_URL ||
    env.DATABASE_URL ||
    env.POSTGRES_URL;

  return {
    ...env,
    ...(supabaseUrl ? {
      SUPABASE_URL: supabaseUrl,
      PUBLIC_SUPABASE_URL: env.PUBLIC_SUPABASE_URL || supabaseUrl,
    } : {}),
    ...(publishableKey ? {
      SUPABASE_PUBLISHABLE_KEY: publishableKey,
      PUBLIC_SUPABASE_PUBLISHABLE_KEY: env.PUBLIC_SUPABASE_PUBLISHABLE_KEY || publishableKey,
    } : {}),
    ...(hyperdriveLocalConnection ? {
      CLOUDFLARE_HYPERDRIVE_LOCAL_CONNECTION_STRING_HYPERDRIVE: hyperdriveLocalConnection,
    } : {}),
    PATEEZ_ADMIN_API_DB_ROLE: env.PATEEZ_ADMIN_API_DB_ROLE || 'pateez_admin_api',
    NODE_OPTIONS: mergeNodeOption(env.NODE_OPTIONS || '', '--no-deprecation'),
  };
}

function deriveSupabaseUrl(databaseUrl) {
  if (!databaseUrl) return '';
  try {
    const parsed = new URL(databaseUrl);
    const match = parsed.hostname.match(/^db\.([a-z0-9-]+)\.supabase\.co$/i);
    return match ? `https://${match[1]}.supabase.co` : '';
  } catch {
    return '';
  }
}

function mergeNodeOption(existing, option) {
  const parts = String(existing || '').split(/\s+/).filter(Boolean);
  if (!parts.includes(option)) parts.push(option);
  return parts.join(' ');
}
