self.addEventListener('push', (event) => {
  let payload = {};
  try {
    payload = event.data ? event.data.json() : {};
  } catch {
    payload = {};
  }

  const notification = payload.notification || payload.webpush?.notification || {};
  const data = {
    ...(payload.data || {}),
    ...(notification.data || {}),
  };
  const title = notification.title || data.title || 'Pateez';
  const body = notification.body || data.body || '';
  const image = notification.image || data.imageUrl || data.image_url || '';
  const deepLink =
    data.deepLink ||
    data.deep_link ||
    payload.fcmOptions?.link ||
    payload.webpush?.fcm_options?.link ||
    '/';

  event.waitUntil(
    self.registration.showNotification(title, {
      body,
      icon: '/favicon.svg',
      badge: '/favicon.svg',
      image: image || undefined,
      data: {
        ...data,
        deepLink,
      },
    }),
  );
});

self.addEventListener('notificationclick', (event) => {
  event.notification.close();
  const data = event.notification.data || {};
  const deepLink = data.deepLink || '/';

  event.waitUntil(
    Promise.all([
      fetch('/api/app/notifications/event', {
        method: 'POST',
        headers: { 'content-type': 'application/json' },
        body: JSON.stringify({
          event_type: 'click',
          campaign_id: data.campaignId || data.campaign_id || '',
          outbox_id: data.notificationId || data.notification_id || '',
          metadata: { source: 'service-worker' },
        }),
      }).catch(() => null),
      clients.matchAll({ type: 'window', includeUncontrolled: true }).then((clientList) => {
        for (const client of clientList) {
          if ('focus' in client && client.url.includes(self.location.origin)) {
            client.focus();
            client.navigate(deepLink);
            return;
          }
        }
        if (clients.openWindow) return clients.openWindow(deepLink);
      }),
    ]),
  );
});
