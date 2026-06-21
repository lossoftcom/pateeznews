import { getSupabaseAuthStorageKeys, migrateLegacySupabaseAuthStorage } from '@/lib/supabase';

const VIEWER_ID_STORAGE_KEY = 'pateeznews_web_viewer_id';

function readAccessToken() {
  if (typeof window === 'undefined') return null;
  migrateLegacySupabaseAuthStorage();
  for (const key of getSupabaseAuthStorageKeys()) {
    const raw = localStorage.getItem(key);
    if (!raw) continue;
    try {
      const parsed = JSON.parse(raw);
      const token =
        parsed?.access_token ||
        parsed?.currentSession?.access_token ||
        parsed?.session?.access_token;
      if (token) return token;
    } catch {
      // Ignore invalid legacy auth payloads and keep checking known keys.
    }
  }
  return null;
}

export function hasPostActionSession() {
  return Boolean(readAccessToken());
}

function randomHex(bytes: number) {
  if (typeof crypto !== 'undefined' && crypto.getRandomValues) {
    const values = new Uint8Array(bytes);
    crypto.getRandomValues(values);
    return Array.from(values, (value) => value.toString(16).padStart(2, '0')).join('');
  }
  return Array.from({ length: bytes }, () => Math.floor(Math.random() * 256).toString(16).padStart(2, '0')).join('');
}

function readClientViewerId() {
  if (typeof window === 'undefined') return null;
  try {
    const existing = localStorage.getItem(VIEWER_ID_STORAGE_KEY)?.trim();
    if (existing && existing.length >= 8) return existing;
    const generated = `web-${Date.now()}-${randomHex(16)}`;
    localStorage.setItem(VIEWER_ID_STORAGE_KEY, generated);
    return generated;
  } catch {
    return null;
  }
}

async function postJson<T>(url: string, payload: Record<string, any>): Promise<T> {
  const token = readAccessToken();
  const response = await fetch(url, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      ...(token ? { Authorization: `Bearer ${token}` } : {}),
    },
    body: JSON.stringify({ ...payload, token }),
  });

  const result = await response.json().catch(() => ({}));
  if (!response.ok || result?.error) {
    throw new Error(result?.error?.message || result?.message || 'Request failed');
  }
  return result as T;
}

export type PostAction =
  | 'state'
  | 'view'
  | 'video_view'
  | 'share'
  | 'toggle_like'
  | 'toggle_dislike'
  | 'toggle_save'
  | 'toggle_follow'
  | 'toggle_reaction';

export function postAction<T = any>(action: PostAction, payload: Record<string, any>) {
  const viewerId = ['state', 'view', 'video_view', 'toggle_reaction'].includes(action) && !payload.viewerId && !payload.clientViewerId
    ? readClientViewerId()
    : null;
  return postJson<T>('/api/app/post-action', {
    action,
    ...payload,
    ...(viewerId ? { viewerId } : {}),
  });
}

export function commentAction<T = any>(action: string, payload: Record<string, any>) {
  return postJson<T>('/api/app/comments', { action, ...payload });
}

export function subscribeNewsletter(email: string, source: string, languageCode: string) {
  return postJson<{ ok: boolean; subscriber: any }>('/api/app/newsletter', {
    email,
    source,
    languageCode,
  });
}

export function searchSite(
  query: string,
  languageCode: string,
  options: { limit?: number; profilesLimit?: number } = {},
) {
  const url = new URL('/api/app/search', window.location.origin);
  url.searchParams.set('q', query);
  url.searchParams.set('lang', languageCode);
  if (options.limit) url.searchParams.set('limit', String(options.limit));
  if (options.profilesLimit) url.searchParams.set('profilesLimit', String(options.profilesLimit));
  return fetch(url).then((response) => response.json());
}

export function accountAction<T = any>(action: string, payload: Record<string, any> = {}) {
  return postJson<T>('/api/app/account', { action, ...payload });
}
