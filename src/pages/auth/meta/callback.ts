import type { APIRoute } from 'astro';
import { signInWithSocialToken } from '@/lib/server/appAuth';
import { readRuntimeEnv } from '@/lib/server/runtimeEnv';

export const prerender = false;

const META_OAUTH_COOKIE = 'pateez_meta_oauth';

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

function readStateCookie(request: Request) {
  const raw = parseCookie(request.headers.get('cookie') || '', META_OAUTH_COOKIE);
  if (!raw) return null;
  try {
    return JSON.parse(Buffer.from(raw, 'base64url').toString('utf8')) as {
      state?: string;
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
      'Set-Cookie': `${META_OAUTH_COOKIE}=; Path=/auth/meta; Max-Age=0; HttpOnly; Secure; SameSite=Lax`,
    },
  });
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

function socialResponse(
  stateCookie: NonNullable<ReturnType<typeof readStateCookie>>,
  origin: string,
  payload: Record<string, unknown>,
) {
  if (stateCookie.mode === 'mobile') {
    return new Response(null, {
      status: 302,
      headers: {
        Location: mobileRedirectUrl({
          scheme: cleanText(stateCookie.scheme) || 'com.pateez.app',
          host: cleanText(stateCookie.host) || 'login-callback',
          data: {
            session: payload.session,
            profile: payload.profile,
          },
        }),
        'Cache-Control': 'no-store',
        'Set-Cookie': `${META_OAUTH_COOKIE}=; Path=/auth/meta; Max-Age=0; HttpOnly; Secure; SameSite=Lax`,
      },
    });
  }
  return popupHtml(origin, {
    type: 'pateez-social-auth',
    provider: 'facebook',
    session: payload.session,
    profile: payload.profile,
  });
}

function socialError(
  stateCookie: ReturnType<typeof readStateCookie>,
  origin: string,
  message: string,
  status = 400,
) {
  if (stateCookie?.mode === 'mobile') {
    return new Response(null, {
      status: 302,
      headers: {
        Location: mobileRedirectUrl({
          scheme: cleanText(stateCookie.scheme) || 'com.pateez.app',
          host: cleanText(stateCookie.host) || 'login-callback',
          error: message,
        }),
        'Cache-Control': 'no-store',
        'Set-Cookie': `${META_OAUTH_COOKIE}=; Path=/auth/meta; Max-Age=0; HttpOnly; Secure; SameSite=Lax`,
      },
    });
  }
  return popupHtml(origin, {
    type: 'pateez-social-auth',
    provider: 'facebook',
    error: message,
  }, status);
}

async function exchangeMetaCode(input: {
  code: string;
  redirectUri: string;
}) {
  const appId = readRuntimeEnv('FACEBOOK_APP_ID') || readRuntimeEnv('META_APP_ID') || '929495530098255';
  const appSecret = readRuntimeEnv('FACEBOOK_APP_SECRET') || readRuntimeEnv('META_APP_SECRET');
  if (!appId) throw new Error('FACEBOOK_APP_ID eksik');
  if (!appSecret) throw new Error('FACEBOOK_APP_SECRET eksik');

  const tokenUrl = new URL('https://graph.facebook.com/v25.0/oauth/access_token');
  tokenUrl.searchParams.set('client_id', appId);
  tokenUrl.searchParams.set('client_secret', appSecret);
  tokenUrl.searchParams.set('redirect_uri', input.redirectUri);
  tokenUrl.searchParams.set('code', input.code);
  const response = await fetch(tokenUrl);
  const payload = await response.json().catch(() => null);
  if (!response.ok || !payload?.access_token) {
    throw new Error(payload?.error?.message || 'Facebook token alınamadı');
  }
  return String(payload.access_token);
}

export const GET: APIRoute = async ({ request, url }) => {
  const requestOrigin = new URL(request.url).origin;
  const stateCookie = readStateCookie(request);
  const origin = stateCookie?.origin === requestOrigin ? stateCookie.origin : requestOrigin;
  const error = cleanText(url.searchParams.get('error_description') || url.searchParams.get('error_message') || url.searchParams.get('error'));
  if (error) return socialError(stateCookie, origin, error, 400);

  const code = cleanText(url.searchParams.get('code'));
  const state = cleanText(url.searchParams.get('state'));
  if (!stateCookie?.state || !stateCookie.redirectUri) {
    return socialError(stateCookie, origin, 'Facebook giriş durumu bulunamadı', 400);
  }
  if (!code || state !== stateCookie.state) {
    return socialError(stateCookie, origin, 'Facebook giriş doğrulaması geçersiz', 400);
  }

  try {
    const accessToken = await exchangeMetaCode({
      code,
      redirectUri: stateCookie.redirectUri,
    });
    const result = await signInWithSocialToken({
      provider: 'facebook',
      accessToken,
    });
    return socialResponse(stateCookie, origin, {
      session: result.data.session,
      profile: result.data.profile,
    });
  } catch (metaError: any) {
    return socialError(stateCookie, origin, metaError?.message || 'Facebook giriş tamamlanamadı', 400);
  }
};
