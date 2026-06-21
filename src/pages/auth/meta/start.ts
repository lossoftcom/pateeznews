import type { APIRoute } from 'astro';
import { readRuntimeEnv } from '@/lib/server/runtimeEnv';

export const prerender = false;

const META_OAUTH_COOKIE = 'pateez_meta_oauth';

function cleanText(value: unknown) {
  return String(value || '').trim();
}

function randomBase64Url(byteLength: number) {
  const bytes = new Uint8Array(byteLength);
  crypto.getRandomValues(bytes);
  return Buffer.from(bytes).toString('base64url');
}

function popupHtml(origin: string, payload: Record<string, unknown>, status = 200) {
  const safeOrigin = JSON.stringify(origin);
  const safePayload = JSON.stringify(payload).replace(/</g, '\\u003c');
  return new Response(`<!doctype html><meta charset="utf-8"><script>
    if (window.opener) window.opener.postMessage(${safePayload}, ${safeOrigin});
    window.close();
  </script>`, {
    status,
    headers: {
      'Content-Type': 'text/html; charset=utf-8',
      'Cache-Control': 'no-store',
    },
  });
}

export const GET: APIRoute = async ({ request, url }) => {
  const requestOrigin = new URL(request.url).origin;
  const originParam = cleanText(url.searchParams.get('origin'));
  const origin = originParam === requestOrigin ? originParam : requestOrigin;
  const requestedMode = cleanText(url.searchParams.get('mode'));
  const mode = requestedMode === 'mobile'
    ? 'mobile'
    : requestedMode === 'popup'
    ? 'popup'
    : 'redirect';
  const scheme = cleanText(url.searchParams.get('scheme')) || 'com.pateez.app';
  const host = cleanText(url.searchParams.get('host')) || 'login-callback';
  const appId = readRuntimeEnv('FACEBOOK_APP_ID') || readRuntimeEnv('META_APP_ID') || '929495530098255';
  if (!appId) {
    return popupHtml(origin, {
      type: 'pateez-social-auth',
      provider: 'facebook',
      error: 'FACEBOOK_APP_ID eksik',
    }, 500);
  }

  const state = randomBase64Url(24);
  const redirectUri = `${requestOrigin}/auth/meta/callback`;
  const payload = Buffer.from(JSON.stringify({
    state,
    mode,
    origin,
    scheme,
    host,
    redirectUri,
  })).toString('base64url');

  const authorizeUrl = new URL('https://www.facebook.com/v25.0/dialog/oauth');
  authorizeUrl.searchParams.set('client_id', appId);
  authorizeUrl.searchParams.set('redirect_uri', redirectUri);
  authorizeUrl.searchParams.set('state', state);
  authorizeUrl.searchParams.set('response_type', 'code');
  authorizeUrl.searchParams.set('scope', 'public_profile,email');

  return new Response(null, {
    status: 302,
    headers: {
      Location: authorizeUrl.toString(),
      'Set-Cookie': `${META_OAUTH_COOKIE}=${payload}; Path=/auth/meta; Max-Age=600; HttpOnly; Secure; SameSite=Lax`,
      'Cache-Control': 'no-store',
    },
  });
};
