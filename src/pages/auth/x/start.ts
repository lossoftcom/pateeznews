import type { APIRoute } from 'astro';
import { readRuntimeEnv } from '@/lib/server/runtimeEnv';

export const prerender = false;

const X_OAUTH_COOKIE = 'pateez_x_oauth';
const X_SCOPES = 'tweet.read users.read users.email';

function base64Url(bytes: Uint8Array) {
  return Buffer.from(bytes).toString('base64url');
}

function randomBase64Url(byteLength: number) {
  const bytes = new Uint8Array(byteLength);
  crypto.getRandomValues(bytes);
  return base64Url(bytes);
}

async function codeChallenge(verifier: string) {
  const digest = await crypto.subtle.digest('SHA-256', new TextEncoder().encode(verifier));
  return Buffer.from(digest).toString('base64url');
}

function cleanText(value: unknown) {
  return String(value || '').trim();
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
  const clientId = readRuntimeEnv('X_CLIENT_ID') || readRuntimeEnv('TWITTER_CLIENT_ID');

  if (!clientId) {
    return popupHtml(origin, {
      type: 'pateez-social-auth',
      provider: 'x',
      error: 'X_CLIENT_ID eksik',
    }, 500);
  }

  const verifier = randomBase64Url(48);
  const state = randomBase64Url(24);
  const redirectUri = `${requestOrigin}/auth/x/callback`;
  const payload = Buffer.from(JSON.stringify({
    state,
    verifier,
    mode,
    origin,
    scheme,
    host,
    redirectUri,
  })).toString('base64url');

  const authorizeUrl = new URL('https://x.com/i/oauth2/authorize');
  authorizeUrl.searchParams.set('response_type', 'code');
  authorizeUrl.searchParams.set('client_id', clientId);
  authorizeUrl.searchParams.set('redirect_uri', redirectUri);
  authorizeUrl.searchParams.set('scope', X_SCOPES);
  authorizeUrl.searchParams.set('state', state);
  authorizeUrl.searchParams.set('code_challenge', await codeChallenge(verifier));
  authorizeUrl.searchParams.set('code_challenge_method', 'S256');

  return new Response(null, {
    status: 302,
    headers: {
      Location: authorizeUrl.toString(),
      'Set-Cookie': `${X_OAUTH_COOKIE}=${payload}; Path=/auth/x; Max-Age=600; HttpOnly; Secure; SameSite=Lax`,
      'Cache-Control': 'no-store',
    },
  });
};
