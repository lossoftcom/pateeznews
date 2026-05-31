import { createServerClient } from '@supabase/ssr';
import { readRuntimeEnv } from './runtimeEnv';

function readEnv(name: string) {
  return readRuntimeEnv(name);
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

function getServerSupabaseConfig() {
  const url = (
    readEnv('PUBLIC_SUPABASE_URL') ||
    readEnv('SUPABASE_URL') ||
    deriveSupabaseUrlFromDatabaseUrl()
  ).replace(/\/$/, '');

  const publishableKey =
    readEnv('PUBLIC_SUPABASE_PUBLISHABLE_KEY') ||
    readEnv('SUPABASE_PUBLISHABLE_KEY');

  if (!url || !publishableKey) {
    throw new Error('PUBLIC_SUPABASE_URL and PUBLIC_SUPABASE_PUBLISHABLE_KEY are required for Astro Supabase SSR');
  }

  return { url, publishableKey };
}

export function createAstroSupabaseClient(astro: { cookies: any }) {
  const { url, publishableKey } = getServerSupabaseConfig();

  return createServerClient(url, publishableKey, {
    auth: {
      persistSession: true,
      autoRefreshToken: false,
      detectSessionInUrl: false,
    },
    cookies: {
      getAll() {
        return astro.cookies.getAll().map((cookie: any) => ({
          name: cookie.name,
          value: cookie.value,
        }));
      },
      setAll(cookiesToSet) {
        for (const cookie of cookiesToSet) {
          astro.cookies.set(cookie.name, cookie.value, cookie.options);
        }
      },
    },
  });
}
