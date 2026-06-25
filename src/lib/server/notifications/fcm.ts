import { SignJWT, importPKCS8 } from 'jose';
import { dbQuery } from '@/lib/server/supabaseDb';
import { decryptSecret } from '@/lib/server/mail/secrets';
import { readRuntimeEnv } from '@/lib/server/runtimeEnv';

const FIREBASE_SCOPE = 'https://www.googleapis.com/auth/firebase.messaging';
const FIREBASE_AUDIENCE = 'https://oauth2.googleapis.com/token';
const DEFAULT_API_BASE_URL = 'https://fcm.googleapis.com/v1';
const DEFAULT_WEB_PUSH_ICON_URL = 'https://pateez.com/local-upload/logo/tr/pateezlogoicon.png';

type SettingsRow = {
  project_id?: string;
  client_email?: string;
  private_key_encrypted?: string;
  api_base_url?: string;
};

export type FirebaseCredentials = {
  projectId: string;
  clientEmail: string;
  privateKey: string;
  apiBaseUrl: string;
};

export type FcmMessageInput = {
  token: string;
  title: string;
  body: string;
  imageUrl?: string;
  deepLink?: string;
  data?: Record<string, unknown>;
  priority?: string;
  ttlSeconds?: number;
  channelId?: string;
};

export type FcmSendResult = {
  ok: boolean;
  messageId?: string;
  statusCode?: number;
  errorCode?: string;
  errorMessage?: string;
  invalidToken?: boolean;
  retryAfterSeconds?: number;
};

type AccessTokenCache = {
  cacheKey: string;
  token: string;
  expiresAt: number;
};

let cachedAccessToken: AccessTokenCache | null = null;

function envCredentials() {
  const projectId = readRuntimeEnv('FIREBASE_PROJECT_ID') || readRuntimeEnv('FCM_PROJECT_ID');
  const clientEmail = readRuntimeEnv('FIREBASE_CLIENT_EMAIL') || readRuntimeEnv('FCM_CLIENT_EMAIL');
  const privateKey = readRuntimeEnv('FIREBASE_PRIVATE_KEY') || readRuntimeEnv('FCM_PRIVATE_KEY');
  const apiBaseUrl = readRuntimeEnv('FIREBASE_FCM_API_BASE_URL') || DEFAULT_API_BASE_URL;

  if (!projectId || !clientEmail || !privateKey) return null;
  return {
    projectId,
    clientEmail,
    privateKey: privateKey.replace(/\\n/g, '\n'),
    apiBaseUrl,
  };
}

export async function resolveFirebaseCredentials(settings?: SettingsRow | null): Promise<FirebaseCredentials> {
  const env = envCredentials();
  if (env) return env;

  let row = settings;
  if (!row) {
    const result = await dbQuery<SettingsRow>(
      `SELECT project_id, client_email, private_key_encrypted, api_base_url
       FROM public.notification_settings
       WHERE provider_id = 'firebase_fcm'
       ORDER BY id ASC
       LIMIT 1`
    );
    row = result.rows[0] || null;
  }

  const projectId = String(row?.project_id || '').trim();
  const clientEmail = String(row?.client_email || '').trim();
  const privateKey = decryptSecret(row?.private_key_encrypted).replace(/\\n/g, '\n').trim();
  const apiBaseUrl = String(row?.api_base_url || DEFAULT_API_BASE_URL).trim() || DEFAULT_API_BASE_URL;

  if (!projectId || !clientEmail || !privateKey) {
    throw new Error('Firebase FCM project id, client email and private key are required');
  }

  return { projectId, clientEmail, privateKey, apiBaseUrl };
}

async function createAccessToken(credentials: FirebaseCredentials) {
  const cacheKey = `${credentials.projectId}:${credentials.clientEmail}`;
  const now = Math.floor(Date.now() / 1000);
  if (
    cachedAccessToken &&
    cachedAccessToken.cacheKey === cacheKey &&
    cachedAccessToken.expiresAt > now + 120
  ) {
    return cachedAccessToken.token;
  }

  const key = await importPKCS8(credentials.privateKey, 'RS256');
  const jwt = await new SignJWT({ scope: FIREBASE_SCOPE })
    .setProtectedHeader({ alg: 'RS256', typ: 'JWT' })
    .setIssuer(credentials.clientEmail)
    .setSubject(credentials.clientEmail)
    .setAudience(FIREBASE_AUDIENCE)
    .setIssuedAt(now)
    .setExpirationTime(now + 3600)
    .sign(key);

  const response = await fetch(FIREBASE_AUDIENCE, {
    method: 'POST',
    headers: { 'content-type': 'application/x-www-form-urlencoded' },
    body: new URLSearchParams({
      grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer',
      assertion: jwt,
    }),
  });

  const payload = await response.json().catch(() => ({})) as Record<string, any>;
  if (!response.ok || !payload.access_token) {
    throw new Error(String(payload.error_description || payload.error || 'Firebase access token could not be created'));
  }

  const expiresIn = Number(payload.expires_in || 3600);
  cachedAccessToken = {
    cacheKey,
    token: String(payload.access_token),
    expiresAt: now + Math.max(300, Math.floor(expiresIn)),
  };
  return cachedAccessToken.token;
}

function stringData(data?: Record<string, unknown>) {
  const output: Record<string, string> = {};
  for (const [key, value] of Object.entries(data || {})) {
    if (value === undefined || value === null) continue;
    if (typeof value === 'string') {
      output[key] = value;
    } else {
      output[key] = JSON.stringify(value);
    }
  }
  return output;
}

function retryAfterSeconds(value: string | null) {
  if (!value) return undefined;
  const direct = Number(value);
  if (Number.isFinite(direct)) return Math.max(0, Math.floor(direct));
  const date = Date.parse(value);
  if (!Number.isFinite(date)) return undefined;
  return Math.max(0, Math.ceil((date - Date.now()) / 1000));
}

function fcmErrorCode(payload: Record<string, any>) {
  const direct = payload?.error?.status || payload?.error?.code || payload?.error;
  const details = Array.isArray(payload?.error?.details) ? payload.error.details : [];
  const fcmDetail = details.find((item: any) =>
    String(item?.['@type'] || '').includes('google.firebase.fcm.v1.FcmError')
  );
  return String(fcmDetail?.errorCode || direct || '').trim();
}

function isInvalidToken(errorCode: string, statusCode: number) {
  const normalized = errorCode.toUpperCase();
  return normalized === 'UNREGISTERED' ||
    normalized === 'INVALID_ARGUMENT' ||
    normalized === 'NOT_FOUND' ||
    statusCode === 404;
}

export async function sendFcmMessage(
  input: FcmMessageInput,
  credentials?: FirebaseCredentials
): Promise<FcmSendResult> {
  const resolved = credentials || await resolveFirebaseCredentials();
  const accessToken = await createAccessToken(resolved);
  const ttlSeconds = Math.max(0, Math.min(Number(input.ttlSeconds || 3600), 2419200));
  const highPriority = String(input.priority || '').toLowerCase() === 'high';
  const deepLink = String(input.deepLink || '').trim();
  const image = String(input.imageUrl || '').trim();
  const data = stringData({
    ...input.data,
    deepLink,
    click_action: deepLink,
  });

  const message: Record<string, any> = {
    token: input.token,
    notification: {
      title: input.title,
      body: input.body,
      ...(image ? { image } : {}),
    },
    data,
    android: {
      priority: highPriority ? 'HIGH' : 'NORMAL',
      ttl: `${ttlSeconds}s`,
      notification: {
        channel_id: input.channelId || 'pateez_general',
        ...(image ? { image } : {}),
      },
    },
    apns: {
      headers: {
        'apns-priority': highPriority ? '10' : '5',
      },
      payload: {
        aps: {
          alert: { title: input.title, body: input.body },
          sound: highPriority ? 'default' : undefined,
        },
      },
      fcm_options: {
        ...(image ? { image } : {}),
      },
    },
    webpush: {
      headers: {
        TTL: String(ttlSeconds),
        Urgency: highPriority ? 'high' : 'normal',
      },
      notification: {
        title: input.title,
        body: input.body,
        icon: DEFAULT_WEB_PUSH_ICON_URL,
        badge: DEFAULT_WEB_PUSH_ICON_URL,
        ...(image ? { image } : {}),
      },
      fcm_options: {
        ...(deepLink ? { link: deepLink } : {}),
      },
    },
  };

  const response = await fetch(
    `${resolved.apiBaseUrl.replace(/\/$/, '')}/projects/${encodeURIComponent(resolved.projectId)}/messages:send`,
    {
      method: 'POST',
      headers: {
        authorization: `Bearer ${accessToken}`,
        'content-type': 'application/json',
      },
      body: JSON.stringify({ message }),
    }
  );

  const payload = await response.json().catch(() => ({})) as Record<string, any>;
  if (response.ok) {
    return { ok: true, messageId: String(payload.name || '') };
  }

  const errorCode = fcmErrorCode(payload);
  return {
    ok: false,
    statusCode: response.status,
    errorCode,
    errorMessage: String(payload?.error?.message || payload?.error || 'Firebase FCM send failed'),
    invalidToken: isInvalidToken(errorCode, response.status),
    retryAfterSeconds: retryAfterSeconds(response.headers.get('retry-after')),
  };
}

export async function checkFirebaseConnection(settings?: SettingsRow | null) {
  await createAccessToken(await resolveFirebaseCredentials(settings));
  return true;
}
