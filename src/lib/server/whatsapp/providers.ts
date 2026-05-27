import { decryptSecret } from '@/lib/server/mail/secrets';

export async function sendWhatsappTextWithAccount(account: any, input: { to: string; text: string }) {
  const provider = String(account?.service_type || account?.servis_tipi || '').trim();
  const apiBaseUrl = String(account?.api_base_url || '').trim();
  const token = decryptSecret(account?.api_token_encrypted || account?.api_token || account?.api_anahtari);
  const apiSecret = decryptSecret(account?.api_secret_encrypted || account?.api_sifresi);
  const to = String(input.to || '').trim();
  const text = String(input.text || '').trim();

  if (!apiBaseUrl || !token) {
    throw new Error('Active WhatsApp account API URL or token is missing');
  }
  if (!to || !text) {
    throw new Error('Recipient phone and message text are required');
  }

  if (provider === 'twilio_whatsapp') {
    const body = new URLSearchParams({
      To: `whatsapp:${to}`,
      From: `whatsapp:${String(account?.phone || account?.telefon || '').trim()}`,
      Body: text,
    });
    const response = await fetch(apiBaseUrl, {
      method: 'POST',
      headers: {
        Authorization: `Basic ${Buffer.from(`${token}:${apiSecret}`).toString('base64')}`,
        'Content-Type': 'application/x-www-form-urlencoded',
      },
      body,
    });
    return responseResult(response);
  }

  const isMeta = provider === 'meta_cloud_api' || apiBaseUrl.includes('graph.facebook.com');
  const payload = isMeta
    ? { messaging_product: 'whatsapp', to, type: 'text', text: { body: text } }
    : { to, type: 'text', text, message: text };

  const response = await fetch(apiBaseUrl, {
    method: 'POST',
    headers: {
      Authorization: `Bearer ${token}`,
      'Content-Type': 'application/json',
      Accept: 'application/json',
    },
    body: JSON.stringify(payload),
  });
  return responseResult(response);
}

async function responseResult(response: Response) {
  const raw = await response.text();
  let decoded: any = {};
  try {
    decoded = raw ? JSON.parse(raw) : {};
  } catch {
    decoded = { raw };
  }

  if (!response.ok) {
    const message =
      decoded?.error?.message ||
      decoded?.message ||
      raw ||
      `WhatsApp provider request failed with ${response.status}`;
    throw new Error(String(message));
  }

  const messageId =
    decoded?.messages?.[0]?.id ||
    decoded?.sid ||
    decoded?.message_id ||
    decoded?.id ||
    `whatsapp-${Date.now()}`;
  return { ok: true, messageId: String(messageId), response: decoded };
}
