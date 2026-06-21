import { createClient, type Session, type SupabaseClient, type User } from '@supabase/supabase-js';

export type { Session, User };

const FALLBACK_SUPABASE_URL = 'https://debgdvrkcqhtwdyrqves.supabase.co';
const PATEEZ_AUTH_STORAGE_KEY = 'pateez-app-auth-session';
const LEGACY_SUPABASE_AUTH_STORAGE_KEYS = [
  'pateeznews-supabase-auth',
  'supabase-auth-token',
] as const;
type AuthEventName = 'SIGNED_IN' | 'SIGNED_OUT' | 'TOKEN_REFRESHED' | 'USER_UPDATED' | 'INITIAL_SESSION';
type AuthListener = (event: AuthEventName, session: Session | null) => void | Promise<void>;

const authListeners = new Set<AuthListener>();

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
    PATEEZ_AUTH_STORAGE_KEY,
    current,
    ...LEGACY_SUPABASE_AUTH_STORAGE_KEYS.filter((key) => key !== current && key !== PATEEZ_AUTH_STORAGE_KEY),
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
  const storageKey = PATEEZ_AUTH_STORAGE_KEY;
  try {
    if (!window.localStorage.getItem(storageKey)) {
      for (const legacyKey of getSupabaseAuthStorageKeys().filter((key) => key !== storageKey)) {
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

function normalizeStoredSession(raw: string | null): Session | null {
  if (!raw) return null;
  try {
    const parsed = JSON.parse(raw);
    const source =
      parsed?.session ||
      parsed?.currentSession ||
      (parsed?.access_token ? parsed : null);
    const token = String(source?.access_token || '').trim();
    if (!token) return null;
    return {
      ...source,
      access_token: token,
      refresh_token: source?.refresh_token || '',
      token_type: source?.token_type || 'bearer',
      expires_at: Number(source?.expires_at || parsed?.expires_at || 0) || undefined,
      expires_in: Number(source?.expires_in || parsed?.expires_in || 0) || undefined,
      user: source?.user || parsed?.user || null,
    } as Session;
  } catch {
    return null;
  }
}

function readStoredPateezSession(): Session | null {
  if (typeof window === 'undefined') return null;
  migrateLegacySupabaseAuthStorage();
  try {
    for (const key of getSupabaseAuthStorageKeys()) {
      const session = normalizeStoredSession(window.localStorage.getItem(key));
      if (session?.access_token) return session;
    }
  } catch {
    // localStorage can be unavailable in restricted browser modes.
  }
  return null;
}

function saveStoredPateezSession(session: Session | null) {
  if (typeof window === 'undefined') return;
  try {
    if (!session?.access_token) {
      clearSupabaseAuthStorage();
      return;
    }
    const payload = JSON.stringify({
      access_token: session.access_token,
      refresh_token: session.refresh_token || '',
      token_type: session.token_type || 'bearer',
      expires_at: session.expires_at || null,
      expires_in: session.expires_in || null,
      user: session.user || null,
      session,
      currentSession: session,
    });
    window.localStorage.setItem(PATEEZ_AUTH_STORAGE_KEY, payload);
    window.localStorage.setItem(getSupabaseAuthStorageKey(), payload);
  } catch {
    // localStorage can be unavailable in restricted browser modes.
  }
}

function emitAuthChange(event: AuthEventName, session: Session | null) {
  for (const listener of authListeners) {
    void listener(event, session);
  }
  if (typeof window !== 'undefined') {
    window.dispatchEvent(new CustomEvent('pateez-auth-change', { detail: { event, session } }));
  }
}

const pateezAuth = {
  async getSession() {
    return { data: { session: readStoredPateezSession() }, error: null };
  },
  async getUser() {
    const session = readStoredPateezSession();
    return { data: { user: session?.user || null }, error: null };
  },
  async setSession(nextSession: Partial<Session> & { access_token?: string; refresh_token?: string }) {
    const session = {
      ...nextSession,
      token_type: nextSession.token_type || 'bearer',
    } as Session;
    saveStoredPateezSession(session);
    emitAuthChange('SIGNED_IN', session);
    return { data: { session, user: session.user || null }, error: null };
  },
  async signOut() {
    clearSupabaseAuthStorage();
    emitAuthChange('SIGNED_OUT', null);
    return { error: null };
  },
  onAuthStateChange(callback: AuthListener) {
    authListeners.add(callback);
    return {
      data: {
        subscription: {
          unsubscribe() {
            authListeners.delete(callback);
          },
        },
      },
    };
  },
  async signInWithOAuth() {
    return {
      data: null,
      error: { message: 'Sosyal giriş artık Pateez auth endpointleri ile çalışıyor' },
    };
  },
};

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
    if (property === 'auth') return pateezAuth;
    return (getSupabaseClient() as any)[property];
  },
});
