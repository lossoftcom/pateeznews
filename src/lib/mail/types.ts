export const MAIL_TABS = [
  'mail_inbox',
  'mail_send',
  'mail_campaigns',
  'mail_templates',
  'mail_contacts',
  'mail_settings',
] as const;

export type MailTab = typeof MAIL_TABS[number];

export const MAIL_PROVIDERS = [
  'amazon_ses',
  'sendgrid',
  'mailgun',
  'postmark',
  'resend',
  'mailtrap',
  'brevo',
  'mailersend',
  'elastic_email',
  'sparkpost',
  'mailchimp',
  'mailerlite',
  'purelymail',
  'gmail_oauth',
  'sendmail',
  'smtp_generic',
] as const;

export type MailProviderId = typeof MAIL_PROVIDERS[number];

export type MailAccount = {
  id: string;
  account_name: string;
  sender_name: string;
  sender_email: string;
  service_type: MailProviderId | string;
  sending_mode: 'api' | 'smtp' | 'sendmail';
  smtp_host?: string | null;
  smtp_port?: number | null;
  smtp_username?: string | null;
  smtp_secure?: string | null;
  receiving_enabled?: boolean;
  imap_host?: string | null;
  imap_port?: number | null;
  imap_username?: string | null;
  spf_registered?: boolean;
  dkim_registered?: boolean;
  dmarc_registered?: boolean;
  dmarc_policy?: string | null;
  dns_last_checked_at?: string | null;
  daily_limit?: number;
  monthly_limit?: number;
  hourly_limit?: number;
  sent_today?: number;
  sent_this_month?: number;
  default_signature?: string | null;
  default_reply_to?: string | null;
  is_active?: boolean;
  connection_status?: string | null;
  last_error_message?: string | null;
  created_at?: string;
  updated_at?: string;
  created_by?: string | null;
  has_api_key?: boolean;
  has_api_secret?: boolean;
  has_api_token?: boolean;
  has_smtp_password?: boolean;
  has_imap_password?: boolean;
};

export type MailInboxItem = {
  id: string;
  account_id?: string | null;
  message_id?: string | null;
  sender_email: string;
  sender_name?: string | null;
  recipient_email?: string | null;
  subject: string;
  content_text?: string | null;
  content_html?: string | null;
  attachments?: any[];
  images?: any[];
  is_read?: boolean;
  is_starred?: boolean;
  labels?: string[];
  folder?: string;
  mail_date?: string;
  read_at?: string | null;
  created_at?: string;
  account_name?: string | null;
};

export type MailOutboxItem = {
  id: string;
  account_id?: string | null;
  campaign_id?: string | null;
  service_message_id?: string | null;
  recipient_email: string;
  recipient_name?: string | null;
  subject: string;
  content_html?: string | null;
  content_text?: string | null;
  attachments?: any[];
  template_id?: string | null;
  status: 'queued' | 'sent' | 'delivered' | 'opened' | 'clicked' | 'bounce' | 'failed' | 'cancelled';
  error_message?: string | null;
  bounce_reason?: string | null;
  scheduled_at?: string | null;
  sent_at?: string | null;
  delivered_at?: string | null;
  opened_at?: string | null;
  clicked_at?: string | null;
  created_at?: string;
  created_by?: string | null;
  account_name?: string | null;
};

export type MailCampaign = {
  id: string;
  account_id?: string | null;
  campaign_name: string;
  subject: string;
  preview_text?: string | null;
  content_html?: string | null;
  template_id?: string | null;
  contact_list_id?: string | null;
  recipient_count?: number;
  sent_count?: number;
  scheduled_start_at?: string | null;
  started_at?: string | null;
  finished_at?: string | null;
  status: 'draft' | 'scheduled' | 'sending' | 'paused' | 'completed' | 'cancelled';
  send_rate?: number;
  last_sent_index?: number;
  delivered_count?: number;
  opened_count?: number;
  clicked_count?: number;
  bounce_count?: number;
  complaint_count?: number;
  unsubscribe_count?: number;
  add_unsubscribe_link?: boolean;
  add_tracking_pixel?: boolean;
  created_at?: string;
  updated_at?: string;
  created_by?: string | null;
  account_name?: string | null;
  contact_list_name?: string | null;
};

export type MailTemplate = {
  id: string;
  template_name: string;
  category: 'kampanya' | 'bilgi' | 'davet' | 'siparis' | 'teklif' | string;
  content_html: string;
  content_mjml?: string | null;
  design_json?: Record<string, any> | null;
  variables?: Array<{ key: string; label: string; fallback?: string }>;
  preview_image?: string | null;
  is_ready?: boolean;
  is_active?: boolean;
  created_at?: string;
  updated_at?: string;
  created_by?: string | null;
};

export type MailContact = {
  id: string;
  email: string;
  first_name?: string | null;
  last_name?: string | null;
  phone?: string | null;
  list_ids?: string[];
  is_active?: boolean;
  unsubscribed_at?: string | null;
  bounce_status?: string | null;
  bounce_at?: string | null;
  validation_status?: string | null;
  total_sent?: number;
  total_opened?: number;
  total_clicked?: number;
  last_sent_at?: string | null;
  created_at?: string;
};

export type MailContactList = {
  id: string;
  list_name: string;
  description?: string | null;
  contact_count?: number;
  auto_sync?: boolean;
  sync_filter?: Record<string, any> | null;
  is_active?: boolean;
  created_at?: string;
  updated_at?: string;
  created_by?: string | null;
};

export type MailStats = {
  total: number;
  unread?: number;
  archived?: number;
  withAttachments?: number;
  successful?: number;
  queued?: number;
  failed?: number;
};
