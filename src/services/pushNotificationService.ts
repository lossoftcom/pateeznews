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

type NotificationEventInput = {
  eventType: 'open' | 'click' | 'read' | 'dismiss' | 'unsubscribe';
  campaignId?: string;
  outboxId?: string;
  inboxId?: string;
  authToken?: string;
};

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
  if (!('serviceWorker' in navigator)) return null;
  return navigator.serviceWorker.register('/firebase-messaging-sw.js');
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
      permission_status: input.permissionStatus || Notification.permission || 'unknown',
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
    },
    input.authToken
  );
}
