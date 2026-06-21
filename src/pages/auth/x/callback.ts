import type { APIRoute } from 'astro';
import { signInWithSocialToken } from '@/lib/server/appAuth';
import { readRuntimeEnv } from '@/lib/server/runtimeEnv';

export const prerender = false;

const X_OAUTH_COOKIE = 'pateez_x_oauth';

function cleanText(value: unknown) {
  return String(value || '').trim();
}

function parseCookie(header: string, name: string) {
  const prefix = `${name}=`;
  return header
    .split(';')
    .map((part) => part.trim())
    .find((part) => part.startsWith(prefix))
    ?.slice(prefix.length) || '';
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
      'Set-Cookie': `${X_OAUTH_COOKIE}=; Path=/auth/x; Max-Age=0; HttpOnly; Secure; SameSite=Lax`,
    },
  });
}

function errorResponse(origin: string, message: string, status = 400) {
  return popupHtml(origin, {
    type: 'pateez-social-auth',
    provider: 'x',
    error: message,
  }, status);
}

function readStateCookie(request: Request) {
  const raw = parseCookie(request.headers.get('cookie') || '', X_OAUTH_COOKIE);
  if (!raw) return null;
  try {
    return JSON.parse(Buffer.from(raw, 'base64url').toString('utf8')) as {
      state?: string;
      verifier?: string;
      mode?: string;
      origin?: string;
      scheme?: string;
      host?: string;
      redirectUri?: string;
    };
  } catch {
    return null;
  }
}

function mobileRedirectUrl(input: {
  scheme: string;
  host: string;
  data?: Record<string, unknown>;
  error?: string;
}) {
  const url = new URL(`${input.scheme}://${input.host}`);
  if (input.error) {
    url.searchParams.set('error', input.error);
  } else if (input.data) {
    const payload = Buffer.from(JSON.stringify(input.data)).toString('base64url');
    url.searchParams.set('payload', payload);
  }
  return url.toString();
}

function socialResultResponse(
  stateCookie: NonNullable<ReturnType<typeof readStateCookie>>,
  origin: string,
  payload: Record<string, unknown>,
) {
  if (stateCookie.mode === 'mobile') {
    const location = mobileRedirectUrl({
      scheme: cleanText(stateCookie.scheme) || 'com.pateez.app',
      host: cleanText(stateCookie.host) || 'login-callback',
      data: {
        session: payload.session,
        profile: payload.profile,
      },
    });
    return new Response(null, {
      status: 302,
      headers: {
        Location: location,
        'Cache-Control': 'no-store',
        'Set-Cookie': `${X_OAUTH_COOKIE}=; Path=/auth/x; Max-Age=0; HttpOnly; Secure; SameSite=Lax`,
      },
    });
  }
  return popupHtml(origin, {
    type: 'pateez-social-auth',
    provider: 'x',
    session: payload.session,
    profile: payload.profile,
  });
}

function socialErrorResponse(
  stateCookie: ReturnType<typeof readStateCookie>,
  origin: string,
  message: string,
  status = 400,
) {
  if (stateCookie?.mode === 'mobile') {
    const location = mobileRedirectUrl({
      scheme: cleanText(stateCookie.scheme) || 'com.pateez.app',
      host: cleanText(stateCookie.host) || 'login-callback',
      error: message,
    });
    return new Response(null, {
      status: 302,
      headers: {
        Location: location,
        'Cache-Control': 'no-store',
        'Set-Cookie': `${X_OAUTH_COOKIE}=; Path=/auth/x; Max-Age=0; HttpOnly; Secure; SameSite=Lax`,
      },
    });
  }
  return errorResponse(origin, message, status);
}

async function exchangeXCode(input: {
  code: string;
  codeVerifier: string;
  redirectUri: string;
}) {
  const clientId = readRuntimeEnv('X_CLIENT_ID') || readRuntimeEnv('TWITTER_CLIENT_ID');
  const clientSecret = readRuntimeEnv('X_CLIENT_SECRET') || readRuntimeEnv('TWITTER_CLIENT_SECRET');
  if (!clientId) throw new Error('X_CLIENT_ID eksik');

  const body = new URLSearchParams({
    grant_type: 'authorization_code',
    code: input.code,
    redirect_uri: input.redirectUri,
    code_verifier: input.codeVerifier,
    client_id: clientId,
  });
  const headers: Record<string, string> = {
    Accept: 'application/json',
    'Content-Type': 'application/x-www-form-urlencoded;charset=UTF-8',
  };
  if (clientSecret) {
    headers.Authorization = `Basic ${Buffer.from(`${clientId}:${clientSecret}`).toString('base64')}`;
  }

  const response = await fetch('https://api.x.com/2/oauth2/token', {
    method: 'POST',
    headers,
    body,
  });
  const payload = await response.json().catch(() => null);
  if (!response.ok || !payload?.access_token) {
    throw new Error(payload?.error_description || payload?.error || 'X token alınamadı');
  }
  return String(payload.access_token);
}

export const GET: APIRoute = async ({ request, url }) => {
  const requestOrigin = new URL(request.url).origin;
  const stateCookie = readStateCookie(request);
  const origin = stateCookie?.origin === requestOrigin ? stateCookie.origin : requestOrigin;
  const error = cleanText(url.searchParams.get('error_description') || url.searchParams.get('error'));
  if (error) return socialErrorResponse(stateCookie, origin, error, 400);

  const code = cleanText(url.searchParams.get('code'));
  const state = cleanText(url.searchParams.get('state'));
  if (!stateCookie?.state || !stateCookie.verifier || !stateCookie.redirectUri) {
    return socialErrorResponse(stateCookie, origin, 'X giriş durumu bulunamadı', 400);
  }
  if (!code || state !== stateCookie.state) {
    return socialErrorResponse(stateCookie, origin, 'X giriş doğrulaması geçersiz', 400);
  }

  try {
    const accessToken = await exchangeXCode({
      code,
      codeVerifier: stateCookie.verifier,
      redirectUri: stateCookie.redirectUri,
    });
    const result = await signInWithSocialToken({
      provider: 'x',
      accessToken,
    });
    return socialResultResponse(stateCookie, origin, {
      session: result.data.session,
      profile: result.data.profile,
    });
  } catch (xError: any) {
    return socialErrorResponse(stateCookie, origin, xError?.message || 'X giriş tamamlanamadı', 400);
  }
};
