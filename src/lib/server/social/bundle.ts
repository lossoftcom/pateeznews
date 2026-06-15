import { readRuntimeEnv } from '@/lib/server/runtimeEnv';

export const BUNDLE_SOCIAL_API_BASE_URL = 'https://api.bundle.social/api/v1';

type BundleRequestOptions = {
  apiKey: string;
  apiBaseUrl?: string;
  method?: 'GET' | 'POST' | 'DELETE' | 'PATCH';
  path: string;
  body?: Record<string, any>;
};

export class BundleSocialError extends Error {
  constructor(message: string, public readonly status = 502) {
    super(message);
  }
}

function normalizeBundleBaseUrl(value?: string) {
  const input = String(
    value ||
      readRuntimeEnv('BUNDLE_SOCIAL_API_BASE_URL') ||
      BUNDLE_SOCIAL_API_BASE_URL
  ).trim();
  if (!input) return BUNDLE_SOCIAL_API_BASE_URL;
  const withoutTrailingSlash = input.replace(/\/+$/g, '');
  return withoutTrailingSlash.endsWith('/api/v1')
    ? withoutTrailingSlash
    : `${withoutTrailingSlash}/api/v1`;
}

function safeBundleMessage(payload: any, fallback: string) {
  if (payload && typeof payload === 'object') {
    const direct = payload.message || payload.error || payload.detail;
    if (typeof direct === 'string' && direct.trim()) return direct.trim();
    if (payload.error && typeof payload.error === 'object') {
      const nested = payload.error.message || payload.error.detail;
      if (typeof nested === 'string' && nested.trim()) return nested.trim();
    }
  }
  if (typeof payload === 'string' && payload.trim()) return payload.trim().slice(0, 500);
  return fallback;
}

export async function bundleRequest<T>(options: BundleRequestOptions): Promise<T> {
  const apiKey = String(options.apiKey || '').trim();
  if (!apiKey) throw new BundleSocialError('Bundle Social API key is missing', 400);

  const path = options.path.startsWith('/') ? options.path : `/${options.path}`;
  const response = await fetch(`${normalizeBundleBaseUrl(options.apiBaseUrl)}${path}`, {
    method: options.method || 'GET',
    headers: {
      Accept: 'application/json',
      'Content-Type': 'application/json',
      'x-api-key': apiKey,
    },
    body: options.body ? JSON.stringify(options.body) : undefined,
  });

  const text = await response.text();
  let payload: any = null;
  if (text) {
    try {
      payload = JSON.parse(text);
    } catch {
      payload = text;
    }
  }

  if (!response.ok) {
    throw new BundleSocialError(
      safeBundleMessage(payload, `Bundle Social request failed with ${response.status}`),
      response.status
    );
  }

  return (payload || {}) as T;
}

export function createPortalLink(options: {
  apiKey: string;
  apiBaseUrl?: string;
  teamId: string;
  redirectUrl?: string;
  socialAccountTypes: string[];
}) {
  const redirectUrl = String(options.redirectUrl || '').trim();
  return bundleRequest<{ url: string }>({
    apiKey: options.apiKey,
    apiBaseUrl: options.apiBaseUrl,
    method: 'POST',
    path: '/social-account/create-portal-link',
    body: {
      teamId: options.teamId,
      socialAccountTypes: options.socialAccountTypes,
      ...(redirectUrl ? { redirectUrl } : {}),
      language: 'tr',
      forceBrowserOAuth: true,
      withBusinessScope: true,
      expiresIn: 1440,
      showModalOnConnectSuccess: true,
    },
  });
}

export function getTeam(options: { apiKey: string; apiBaseUrl?: string; teamId: string }) {
  return bundleRequest<Record<string, any>>({
    apiKey: options.apiKey,
    apiBaseUrl: options.apiBaseUrl,
    path: `/team/${encodeURIComponent(options.teamId)}`,
  });
}

export function createUploadFromUrl(options: {
  apiKey: string;
  apiBaseUrl?: string;
  teamId: string;
  url: string;
}) {
  return bundleRequest<{ id: string }>({
    apiKey: options.apiKey,
    apiBaseUrl: options.apiBaseUrl,
    method: 'POST',
    path: '/upload/from-url',
    body: {
      teamId: options.teamId,
      url: options.url,
    },
  });
}

export function createPost(options: {
  apiKey: string;
  apiBaseUrl?: string;
  body: Record<string, any>;
}) {
  return bundleRequest<Record<string, any>>({
    apiKey: options.apiKey,
    apiBaseUrl: options.apiBaseUrl,
    method: 'POST',
    path: '/post/',
    body: options.body,
  });
}
