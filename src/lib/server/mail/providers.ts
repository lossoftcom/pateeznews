import nodemailer from 'nodemailer';
import type SMTPTransport from 'nodemailer/lib/smtp-transport';
import { decryptSecret } from './secrets';

export const MAIL_PROVIDER_OPTIONS = [
  { id: 'amazon_ses', label: 'Amazon SES', api: true, smtp: true, imap: false, marketing: false },
  { id: 'sendgrid', label: 'SendGrid', api: true, smtp: true, imap: false, marketing: true },
  { id: 'mailgun', label: 'Mailgun', api: true, smtp: true, imap: false, marketing: false },
  { id: 'postmark', label: 'Postmark', api: true, smtp: true, imap: false, marketing: false },
  { id: 'resend', label: 'Resend', api: true, smtp: false, imap: false, marketing: false },
  { id: 'mailtrap', label: 'Mailtrap', api: true, smtp: true, imap: false, marketing: false },
  { id: 'brevo', label: 'Brevo', api: true, smtp: true, imap: false, marketing: true },
  { id: 'mailersend', label: 'MailerSend', api: true, smtp: true, imap: false, marketing: false },
  { id: 'elastic_email', label: 'Elastic Email', api: true, smtp: true, imap: false, marketing: true },
  { id: 'sparkpost', label: 'SparkPost', api: true, smtp: true, imap: false, marketing: false },
  { id: 'mailchimp', label: 'Mailchimp', api: true, smtp: false, imap: false, marketing: true },
  { id: 'mailerlite', label: 'MailerLite', api: true, smtp: false, imap: false, marketing: true },
  { id: 'purelymail', label: 'Purelymail', api: false, smtp: true, imap: true, marketing: false },
  { id: 'gmail_oauth', label: 'Gmail OAuth', api: true, smtp: true, imap: true, marketing: false },
  { id: 'sendmail', label: 'Sendmail', api: false, smtp: false, imap: false, marketing: false },
  { id: 'smtp_generic', label: 'Özel SMTP', api: false, smtp: true, imap: true, marketing: false },
] as const;

export function providerLabel(id: string) {
  return MAIL_PROVIDER_OPTIONS.find((provider) => provider.id === id)?.label || id;
}

export function spamScore(input: { subject?: string; html?: string; text?: string }) {
  const body = `${input.subject || ''} ${input.html || ''} ${input.text || ''}`.toLocaleLowerCase('tr-TR');
  let score = 0;
  const hits: string[] = [];
  for (const word of ['bedava', 'kazan', 'hemen al', 'acil', 'garanti', 'tıkla', 'click here', 'free money']) {
    if (body.includes(word)) {
      score += 12;
      hits.push(word);
    }
  }
  if ((input.subject || '').length > 90) {
    score += 10;
    hits.push('uzun konu');
  }
  if (!input.text && !input.html) {
    score += 20;
    hits.push('boş içerik');
  }
  return { score: Math.min(score, 100), hits, status: score >= 50 ? 'riskli' : score >= 25 ? 'dikkat' : 'temiz' };
}

export function dnsChecklist(domain: string, providerId: string) {
  const domainName = String(domain || '').trim() || 'example.com';
  return [
    {
      type: 'SPF',
      host: '@',
      value: providerId === 'sendgrid' ? 'v=spf1 include:sendgrid.net ~all' : providerId === 'amazon_ses' ? 'v=spf1 include:amazonses.com ~all' : `v=spf1 include:${domainName} ~all`,
      status: 'manual_check_required',
    },
    {
      type: 'DKIM',
      host: `selector._domainkey.${domainName}`,
      value: 'Sağlayıcı panelinden alınan DKIM değeri',
      status: 'manual_check_required',
    },
    {
      type: 'DMARC',
      host: `_dmarc.${domainName}`,
      value: `v=DMARC1; p=none; rua=mailto:dmarc@${domainName}`,
      status: 'manual_check_required',
    },
  ];
}

export async function sendMailWithAccount(account: any, input: {
  to: string;
  subject: string;
  html?: string;
  text?: string;
  attachments?: Array<{ filename?: string; content?: string; path?: string; contentType?: string }>;
}) {
  const mode = String(account?.sending_mode || 'smtp');

  if (mode === 'smtp' && account?.smtp_host) {
    const secureMode = String(account.smtp_secure || '').toLowerCase();
    const transportOptions: SMTPTransport.Options = {
      host: account.smtp_host,
      port: Number(account.smtp_port || 587),
      secure: secureMode === 'ssl' || Number(account.smtp_port || 0) === 465,
      auth: account.smtp_username
        ? {
          user: account.smtp_username,
          pass: decryptSecret(account.smtp_password_encrypted),
        }
        : undefined,
    };

    const transporter = nodemailer.createTransport(transportOptions);
    const result = await transporter.sendMail({
      from: account.sender_name ? `"${account.sender_name}" <${account.sender_email}>` : account.sender_email,
      replyTo: account.default_reply_to || undefined,
      to: input.to,
      subject: input.subject,
      html: input.html || undefined,
      text: input.text || undefined,
      attachments: input.attachments || undefined,
    });

    return { ok: true, messageId: result.messageId || `smtp-${Date.now()}`, provider: providerLabel(account.service_type) };
  }

  return {
    ok: true,
    messageId: `mock-${Date.now()}-${Math.random().toString(16).slice(2)}`,
    provider: providerLabel(account?.service_type || 'smtp_generic'),
    mocked: true,
  };
}
