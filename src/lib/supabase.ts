import { createClient, type Session, type SupabaseClient, type User } from '@supabase/supabase-js';

export type { Session, User };

function readEnv(name: string) {
  return (import.meta.env as Record<string, string | undefined>)[name] || '';
}

function deriveSupabaseUrlFromDatabaseUrl() {
  const databaseUrl = readEnv('SUPABASE_DATABASE_URL') || readEnv('DATABASE_URL') || readEnv('POSTGRES_URL');
  if (!databaseUrl) return '';
  try {
    const parsed = new URL(databaseUrl);
    const match = parsed.hostname.match(/^db\.([a-z0-9-]+)\.supabase\.co$/i);
    return match ? `https://${match[1]}.supabase.co` : '';
  } catch {
    return '';
  }
}

export function getSupabaseClientConfig() {
  const url = (
    readEnv('PUBLIC_SUPABASE_URL') ||
    readEnv('SUPABASE_URL') ||
    deriveSupabaseUrlFromDatabaseUrl()
  ).replace(/\/$/, '');

  const publishableKey =
    readEnv('PUBLIC_SUPABASE_PUBLISHABLE_KEY') ||
    readEnv('PUBLIC_SUPABASE_ANON_KEY') ||
    readEnv('SUPABASE_PUBLISHABLE_KEY') ||
    readEnv('SUPABASE_ANON_KEY');

  return { url, publishableKey };
}

let browserClient: SupabaseClient | null = null;

export function getSupabaseClient() {
  if (browserClient) return browserClient;
  const { url, publishableKey } = getSupabaseClientConfig();
  if (!url || !publishableKey) {
    throw new Error('PUBLIC_SUPABASE_URL and PUBLIC_SUPABASE_PUBLISHABLE_KEY are required for the Supabase client');
  }
  browserClient = createClient(url, publishableKey, {
    auth: {
      persistSession: true,
      autoRefreshToken: true,
      detectSessionInUrl: true,
      storageKey: 'pateeznews-supabase-auth',
    },
    realtime: {
      params: {
        eventsPerSecond: 5,
      },
    },
  });
  return browserClient;
}

export const supabase = new Proxy({} as SupabaseClient, {
  get(_target, property) {
    return (getSupabaseClient() as any)[property];
  },
});
