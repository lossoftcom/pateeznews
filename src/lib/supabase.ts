import { createClient, type Session, type SupabaseClient, type User } from '@supabase/supabase-js';

export type { Session, User };

const FALLBACK_SUPABASE_URL = 'https://debgdvrkcqhtwdyrqves.supabase.co';
const LEGACY_SUPABASE_AUTH_STORAGE_KEYS = [
  'pateeznews-supabase-auth',
  'supabase-auth-token',
] as const;

function readEnv(name: string) {
  return (import.meta.env as Record<string, string | undefined>)[name] || '';
}

export function getSupabaseClientConfig() {
  const url = (
    readEnv('PUBLIC_SUPABASE_URL') ||
    readEnv('SUPABASE_URL')
  ).replace(/\/$/, '');

  const publishableKey =
    readEnv('PUBLIC_SUPABASE_PUBLISHABLE_KEY') ||
    readEnv('SUPABASE_PUBLISHABLE_KEY');

  return { url, publishableKey };
}

export function getSupabaseAuthStorageKey() {
  const { url } = getSupabaseClientConfig();
  try {
    const host = new URL(url || FALLBACK_SUPABASE_URL).hostname;
    return `sb-${host.split('.')[0]}-auth-token`;
  } catch {
    return 'sb-debgdvrkcqhtwdyrqves-auth-token';
  }
}

export function getSupabaseAuthStorageKeys() {
  const current = getSupabaseAuthStorageKey();
  return [
    current,
    ...LEGACY_SUPABASE_AUTH_STORAGE_KEYS.filter((key) => key !== current),
  ];
}

function hasStoredSession(raw: string) {
  try {
    const parsed = JSON.parse(raw);
    return Boolean(
      parsed?.access_token ||
      parsed?.currentSession?.access_token ||
      parsed?.session?.access_token
    );
  } catch {
    return false;
  }
}

export function migrateLegacySupabaseAuthStorage() {
  if (typeof window === 'undefined') return;
  const storageKey = getSupabaseAuthStorageKey();
  try {
    if (!window.localStorage.getItem(storageKey)) {
      for (const legacyKey of LEGACY_SUPABASE_AUTH_STORAGE_KEYS) {
        const raw = window.localStorage.getItem(legacyKey);
        if (raw && hasStoredSession(raw)) {
          window.localStorage.setItem(storageKey, raw);
          break;
        }
      }
    }
    for (const legacyKey of LEGACY_SUPABASE_AUTH_STORAGE_KEYS) {
      if (legacyKey === storageKey) continue;
      window.localStorage.removeItem(legacyKey);
      window.localStorage.removeItem(`${legacyKey}-code-verifier`);
      window.localStorage.removeItem(`${legacyKey}-user`);
    }
  } catch {
    // localStorage can be unavailable in restricted browser modes.
  }
}

export function clearSupabaseAuthStorage() {
  if (typeof window === 'undefined') return;
  try {
    for (const key of getSupabaseAuthStorageKeys()) {
      window.localStorage.removeItem(key);
      window.localStorage.removeItem(`${key}-code-verifier`);
      window.localStorage.removeItem(`${key}-user`);
    }
    window.localStorage.removeItem('pateez_profile_cache');
  } catch {
    // localStorage can be unavailable in restricted browser modes.
  }
}

let browserClient: SupabaseClient | null = null;

export function getSupabaseClient() {
  if (browserClient) return browserClient;
  const { url, publishableKey } = getSupabaseClientConfig();
  if (!url || !publishableKey) {
    throw new Error('PUBLIC_SUPABASE_URL and PUBLIC_SUPABASE_PUBLISHABLE_KEY are required for the Supabase client');
  }
  const storageKey = getSupabaseAuthStorageKey();
  migrateLegacySupabaseAuthStorage();
  browserClient = createClient(url, publishableKey, {
    auth: {
      persistSession: true,
      autoRefreshToken: true,
      detectSessionInUrl: true,
      storageKey,
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
