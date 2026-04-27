const AUTH_STORAGE_KEY = 'neon-auth-token';

function readAccessToken() {
  if (typeof window === 'undefined') return null;
  try {
    const raw = localStorage.getItem(AUTH_STORAGE_KEY);
    if (!raw) return null;
    return JSON.parse(raw)?.access_token || null;
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
  | 'share'
  | 'toggle_like'
  | 'toggle_dislike'
  | 'toggle_save'
  | 'toggle_follow'
  | 'toggle_reaction';

export function postAction<T = any>(action: PostAction, payload: Record<string, any>) {
  return postJson<T>('/api/app/post-action', { action, ...payload });
}

export function subscribeNewsletter(email: string, source: string, languageCode: string) {
  return postJson<{ ok: boolean; subscriber: any }>('/api/app/newsletter', {
    email,
    source,
    languageCode,
  });
}

export function trackStoryView(storyId: string) {
  return postJson<{ ok: boolean; viewCount: number }>('/api/app/story-view', { storyId });
}

export function searchSite(query: string, languageCode: string) {
  const url = new URL('/api/app/search', window.location.origin);
  url.searchParams.set('q', query);
  url.searchParams.set('lang', languageCode);
  return fetch(url).then((response) => response.json());
}

export function accountAction<T = any>(action: string, payload: Record<string, any> = {}) {
  return postJson<T>('/api/app/account', { action, ...payload });
}
