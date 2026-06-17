type RegisterPushTokenInput = {
  fcmToken: string;
  platform?: string;
  appSurface?: string;
  languageCode?: string;
  countryCode?: string;
  timezone?: string;
  appVersion?: string;
  deviceId?: string;
  deviceModel?: string;
  permissionStatus?: string;
  topics?: string[];
  authToken?: string;
};

type BrowserPushRegistrationInput = {
  authToken?: string;
  topics?: string[];
};

type NotificationEventInput = {
  eventType: 'open' | 'click' | 'read' | 'dismiss' | 'unsubscribe';
  campaignId?: string;
  outboxId?: string;
  inboxId?: string;
  deviceTokenId?: string;
  authToken?: string;
};

const firebaseConfig = {
  apiKey: import.meta.env.PUBLIC_FIREBASE_API_KEY || 'AIzaSyBuYEFAQzo5E9bNHPeLdYWoY3sdz-HPEVc',
  authDomain: import.meta.env.PUBLIC_FIREBASE_AUTH_DOMAIN || 'pateez-ac151.firebaseapp.com',
  projectId: import.meta.env.PUBLIC_FIREBASE_PROJECT_ID || 'pateez-ac151',
  storageBucket: import.meta.env.PUBLIC_FIREBASE_STORAGE_BUCKET || 'pateez-ac151.firebasestorage.app',
  messagingSenderId: import.meta.env.PUBLIC_FIREBASE_MESSAGING_SENDER_ID || '868646509784',
  appId: import.meta.env.PUBLIC_FIREBASE_APP_ID || '1:868646509784:web:cacd099bbcfa60553a8bad',
};

const webVapidKey =
  import.meta.env.PUBLIC_FIREBASE_WEB_VAPID_KEY ||
  'BLK4FyGCmz6MUPSmCQmWX7JYVFJNW7GRq5J1VnRIKFif093p4W8rpF9fhs7U9N_m6UnOiiermjIJJDRLT76e6q8';

let foregroundListenerBound = false;
let lastBrowserRegistrationKey = '';

function jsonHeaders(authToken?: string) {
  const token = authToken?.trim() || '';
  return {
    Accept: 'application/json',
    'Content-Type': 'application/json; charset=UTF-8',
    ...(token ? { Authorization: `Bearer ${token}` } : {}),
  };
}

async function requestJson(path: string, body: Record<string, unknown>, authToken?: string) {
  const response = await fetch(path, {
    method: 'POST',
    headers: jsonHeaders(authToken),
    body: JSON.stringify(body),
  });
  const payload = await response.json().catch(() => ({}));
  if (!response.ok || payload?.error) {
    throw new Error(payload?.error?.message || 'Notification request failed');
  }
  return payload;
}

export async function ensureNotificationServiceWorker() {
  if (typeof navigator === 'undefined' || !('serviceWorker' in navigator)) return null;
  return navigator.serviceWorker.register('/firebase-messaging-sw.js');
}

function browserDeviceId() {
  const key = 'pateez_fcm_web_device_id';
  try {
    const existing = localStorage.getItem(key);
    if (existing) return existing;
    const bytes = new Uint8Array(18);
    crypto.getRandomValues(bytes);
    const created = `web-${btoa(String.fromCharCode(...bytes)).replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/g, '')}`;
    localStorage.setItem(key, created);
    return created;
  } catch {
    return `web-${Date.now()}`;
  }
}

function notificationPermission() {
  if (typeof Notification === 'undefined') return 'unsupported';
  return Notification.permission || 'unknown';
}

async function browserPermission() {
  if (typeof Notification === 'undefined') return 'unsupported';
  if (Notification.permission === 'default') {
    return Notification.requestPermission();
  }
  return Notification.permission;
}

function pickPayloadData(payload: any) {
  return {
    ...(payload?.data || {}),
    ...(payload?.notification?.data || {}),
  } as Record<string, string>;
}

function bindForegroundMessages(messaging: any) {
  if (foregroundListenerBound) return;
  foregroundListenerBound = true;
  import('firebase/messaging').then(({ onMessage }) => {
    onMessage(messaging, (payload) => {
      if (typeof Notification === 'undefined' || Notification.permission !== 'granted') return;
      const data = pickPayloadData(payload);
      const title = payload?.notification?.title || data.title || 'Pateez';
      const body = payload?.notification?.body || data.body || '';
      const deepLink = data.deepLink || data.deep_link || '/';
      const notification = new Notification(title, {
        body,
        icon: '/local-upload/logo/tr/pateezlogoicon.png',
        badge: '/local-upload/logo/tr/pateezlogoicon.png',
        data: { ...data, deepLink },
      });
      notification.onclick = () => {
        window.focus();
        void recordNotificationEvent({
          eventType: 'click',
          campaignId: data.campaignId || data.campaign_id,
          outboxId: data.outboxId || data.outbox_id || data.notificationId || data.notification_id,
          deviceTokenId: data.deviceTokenId || data.device_token_id,
        }).catch(() => undefined);
        if (deepLink) window.location.href = deepLink;
      };
    });
  }).catch(() => undefined);
}

export async function requestAndRegisterBrowserPush(input: BrowserPushRegistrationInput = {}) {
  if (typeof window === 'undefined' || typeof navigator === 'undefined') return { ok: false };
  const permission = await browserPermission();
  if (permission !== 'granted') return { ok: false, permission };

  const registration = await ensureNotificationServiceWorker();
  const [{ initializeApp, getApps }, { getMessaging, getToken, isSupported }] = await Promise.all([
    import('firebase/app'),
    import('firebase/messaging'),
  ]);
  if (!(await isSupported())) return { ok: false, permission, unsupported: true };

  const app = getApps().find((item) => item.name === 'pateez-web') || initializeApp(firebaseConfig, 'pateez-web');
  const messaging = getMessaging(app);
  const fcmToken = await getToken(messaging, {
    vapidKey: webVapidKey,
    serviceWorkerRegistration: registration || undefined,
  });
  if (!fcmToken) return { ok: false, permission };

  const authKey = input.authToken?.trim() || 'anon';
  const registrationKey = `${fcmToken}|${authKey}|${permission}`;
  if (registrationKey === lastBrowserRegistrationKey) return { ok: true, reused: true };

  const result = await registerPushToken({
    fcmToken,
    platform: 'astro_web',
    appSurface: 'astro_web',
    languageCode: document.documentElement.lang || 'tr',
    countryCode: 'TR',
    timezone: Intl.DateTimeFormat().resolvedOptions().timeZone || '',
    appVersion: import.meta.env.PUBLIC_APP_VERSION || '',
    deviceId: browserDeviceId(),
    deviceModel: navigator.userAgent,
    permissionStatus: permission,
    topics: input.topics || ['general'],
    authToken: input.authToken,
  });
  bindForegroundMessages(messaging);
  lastBrowserRegistrationKey = registrationKey;
  return result;
}

export async function registerPushToken(input: RegisterPushTokenInput) {
  return requestJson(
    '/api/app/notifications/register',
    {
      fcm_token: input.fcmToken,
      platform: input.platform || 'web',
      app_surface: input.appSurface || 'astro_web',
      language_code: input.languageCode || document.documentElement.lang || 'tr',
      country_code: input.countryCode || '',
      timezone: input.timezone || Intl.DateTimeFormat().resolvedOptions().timeZone || '',
      app_version: input.appVersion || '',
      device_id: input.deviceId || '',
      device_model: input.deviceModel || navigator.userAgent,
      permission_status: input.permissionStatus || notificationPermission(),
      topics: input.topics || [],
    },
    input.authToken
  );
}

export async function recordNotificationEvent(input: NotificationEventInput) {
  return requestJson(
    '/api/app/notifications/event',
    {
      event_type: input.eventType,
      campaign_id: input.campaignId || '',
      outbox_id: input.outboxId || '',
      inbox_id: input.inboxId || '',
      device_token_id: input.deviceTokenId || '',
    },
    input.authToken
  );
}
