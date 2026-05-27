import { decryptSecret } from '@/lib/server/mail/secrets';

export async function sendSmsTextWithAccount(account: any, input: { to: string; text: string }) {
  const provider = String(account?.service_type || account?.servis_tipi || '').trim();
  const apiBaseUrl = String(account?.api_base_url || '').trim();
  const apiKey = decryptSecret(account?.api_key_encrypted || account?.api_anahtari || account?.api_token);
  const apiSecret = decryptSecret(account?.api_secret_encrypted || account?.api_sifresi);
  const apiToken = decryptSecret(account?.api_token_encrypted || account?.api_token || account?.api_anahtari);
  const to = String(input.to || '').trim();
  const text = String(input.text || '').trim();
  const from = String(account?.sender_id || account?.gonderici_basligi || account?.phone || account?.telefon || '').trim();
  const callbackUrl = String(account?.webhook_url || '').trim();

  if (!apiBaseUrl) {
    throw new Error('Active SMS account API URL is missing');
  }
  if (!to || !text) {
    throw new Error('Recipient phone and message text are required');
  }

  if (provider === 'iletimerkezi') {
    if (!apiKey || !apiSecret || !from) {
      throw new Error('İleti Merkezi API key, hash and approved sender ID are required');
    }
    const response = await fetch(apiBaseUrl || 'https://api.iletimerkezi.com/v1/send-sms/json', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', Accept: 'application/json' },
      body: JSON.stringify({
        request: {
          authentication: { key: apiKey, hash: apiSecret },
          order: {
            sender: from,
            iys: '0',
            message: {
              text,
              receipents: { number: [to] },
            },
          },
        },
      }),
    });
    const result = await responseResult(response);
    const statusCode = Number(result.response?.response?.status?.code || result.response?.status?.code || 0);
    if (statusCode && statusCode !== 200) {
      throw new Error(String(result.response?.response?.status?.message || result.response?.status?.message || 'İleti Merkezi request failed'));
    }
    const messageId = result.response?.response?.order?.id || result.response?.order?.id || result.messageId;
    return { ...result, messageId: String(messageId) };
  }

  if (provider === 'twilio_sms') {
    if (!apiKey || !apiSecret || !from) {
      throw new Error('Twilio Account SID, Auth Token and From number are required');
    }
    const url = apiBaseUrl.replace('{account_sid}', encodeURIComponent(apiKey));
    const body = new URLSearchParams({
      To: to,
      From: from,
      Body: text,
    });
    if (callbackUrl) body.set('StatusCallback', callbackUrl);
    const response = await fetch(url, {
      method: 'POST',
      headers: {
        Authorization: `Basic ${Buffer.from(`${apiKey}:${apiSecret}`).toString('base64')}`,
        'Content-Type': 'application/x-www-form-urlencoded',
      },
      body,
    });
    return responseResult(response);
  }

  if (provider === 'vonage_sms') {
    if (!apiKey || !apiSecret || !from) {
      throw new Error('Vonage API key, secret and sender are required');
    }
    const body = new URLSearchParams({
      from,
      to,
      text,
      type: /[^\u0000-\u007f]/.test(text) ? 'unicode' : 'text',
    });
    if (callbackUrl) body.set('callback', callbackUrl);
    const response = await fetch(apiBaseUrl || 'https://rest.nexmo.com/sms/json', {
      method: 'POST',
      headers: {
        Authorization: `Basic ${Buffer.from(`${apiKey}:${apiSecret}`).toString('base64')}`,
        'Content-Type': 'application/x-www-form-urlencoded',
        Accept: 'application/json',
      },
      body,
    });
    return responseResult(response);
  }

  if (provider === 'infobip_sms') {
    if (!apiToken && !apiKey) {
      throw new Error('Infobip API key is required');
    }
    const response = await fetch(apiBaseUrl || 'https://api.infobip.com/sms/3/messages', {
      method: 'POST',
      headers: {
        Authorization: String(apiToken || apiKey).startsWith('App ')
          ? String(apiToken || apiKey)
          : `App ${apiToken || apiKey}`,
        'Content-Type': 'application/json',
        Accept: 'application/json',
      },
      body: JSON.stringify({
        messages: [
          {
            sender: from || undefined,
            destinations: [{ to }],
            content: { text },
          },
        ],
      }),
    });
    return responseResult(response);
  }

  if (provider !== 'custom_sms_api') {
    throw new Error(`SMS provider is not implemented from verified documentation: ${provider}`);
  }

  const payload = { to, from, text, message: text };

  const response = await fetch(apiBaseUrl, {
    method: 'POST',
    headers: {
      ...(apiToken || apiKey ? { Authorization: `Bearer ${apiToken || apiKey}` } : {}),
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
      `SMS provider request failed with ${response.status}`;
    throw new Error(String(message));
  }

  const messageId =
    decoded?.messages?.[0]?.id ||
    decoded?.sid ||
    decoded?.message_id ||
    decoded?.id ||
    `sms-${Date.now()}`;
  return { ok: true, messageId: String(messageId), response: decoded };
}
