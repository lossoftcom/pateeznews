import { neon } from '@/lib/neon';

async function authHeaders() {
  const { data: { session } } = await neon.auth.getSession();
  return {
    'Content-Type': 'application/json',
    ...(session?.access_token ? { Authorization: `Bearer ${session.access_token}` } : {}),
  };
}

async function requestMail(path: string, options: RequestInit = {}) {
  const headers = await authHeaders();
  const response = await fetch(`/api/admin/mail/${path}`, {
    ...options,
    headers: {
      ...headers,
      ...(options.headers || {}),
    },
  });
  const payload = await response.json().catch(() => ({}));
  if (!response.ok || payload?.error) {
    throw new Error(payload?.error?.message || 'Posta işlemi başarısız oldu');
  }
  return payload;
}

export const mailClient = {
  getAccounts: () => requestMail('accounts'),
  getProviders: () => requestMail('accounts?providers=1'),
  saveAccount: (payload: Record<string, any>) =>
    requestMail('accounts', { method: payload.id ? 'PATCH' : 'POST', body: JSON.stringify(payload) }),
  deleteAccount: (id: string) => requestMail('accounts', { method: 'DELETE', body: JSON.stringify({ id }) }),
  checkDns: (id: string) => requestMail('accounts', { method: 'PATCH', body: JSON.stringify({ id, action: 'dns-check' }) }),

  getInbox: (params: URLSearchParams) => requestMail(`inbox?${params.toString()}`),
  updateInbox: (payload: Record<string, any>) => requestMail('inbox', { method: 'PATCH', body: JSON.stringify(payload) }),
  getOutbox: (params: URLSearchParams) => requestMail(`outbox?${params.toString()}`),
  send: (payload: Record<string, any>) => requestMail('send', { method: 'POST', body: JSON.stringify(payload) }),

  getCampaigns: (params: URLSearchParams) => requestMail(`campaigns?${params.toString()}`),
  saveCampaign: (payload: Record<string, any>) =>
    requestMail('campaigns', { method: payload.id ? 'PATCH' : 'POST', body: JSON.stringify(payload) }),
  campaignAction: (id: string, action: string, extra: Record<string, any> = {}) =>
    requestMail('campaigns', { method: 'PATCH', body: JSON.stringify({ id, action, ...extra }) }),
  deleteCampaign: (id: string) => requestMail('campaigns', { method: 'DELETE', body: JSON.stringify({ id }) }),

  getTemplates: (params: URLSearchParams) => requestMail(`templates?${params.toString()}`),
  saveTemplate: (payload: Record<string, any>) =>
    requestMail('templates', { method: payload.id ? 'PATCH' : 'POST', body: JSON.stringify(payload) }),
  deleteTemplate: (id: string) => requestMail('templates', { method: 'DELETE', body: JSON.stringify({ id }) }),

  getContactLists: (params: URLSearchParams) => requestMail(`contact-lists?${params.toString()}`),
  saveContactList: (payload: Record<string, any>) =>
    requestMail('contact-lists', { method: payload.id ? 'PATCH' : 'POST', body: JSON.stringify(payload) }),
  deleteContactList: (id: string) => requestMail('contact-lists', { method: 'DELETE', body: JSON.stringify({ id }) }),
  importContacts: (payload: Record<string, any>) => requestMail('import', { method: 'POST', body: JSON.stringify(payload) }),
};
