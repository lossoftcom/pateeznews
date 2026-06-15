import nodemailer from 'nodemailer';
import { resolveCname, resolveTxt } from 'node:dns/promises';
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

function normalizedDomain(value: string) {
  const domain = String(value || '').trim().toLowerCase().replace(/\.$/, '');
  if (!domain || !/^(?=.{1,253}$)(?:[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?\.)+[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?$/.test(domain)) {
    throw new Error('A valid domain is required for DNS verification');
  }
  return domain;
}

function normalizedDnsName(value: string) {
  return String(value || '').trim().toLowerCase().replace(/\.$/, '');
}

async function txtRecords(host: string) {
  try {
    return (await resolveTxt(host)).map((parts) => parts.join('').trim());
  } catch {
    return [];
  }
}

async function cnameRecords(host: string) {
  try {
    return (await resolveCname(host)).map(normalizedDnsName);
  } catch {
    return [];
  }
}

export async function dnsChecklist(domain: string, providerId: string) {
  const domainName = normalizedDomain(domain);
  const normalizedProvider = String(providerId || '').trim().toLowerCase();
  const isPurelymail = normalizedProvider === 'purelymail' || normalizedProvider.startsWith('purelymail_');

  const rootTxt = await txtRecords(domainName);
  const spfRecords = rootTxt.filter((record) => /^v=spf1(?:\s|$)/i.test(record));
  const expectedSpfInclude = isPurelymail
    ? 'include:_spf.purelymail.com'
    : normalizedProvider.startsWith('sendgrid')
      ? 'include:sendgrid.net'
      : normalizedProvider.startsWith('amazon_ses')
        ? 'include:amazonses.com'
        : '';
  const spfReady = expectedSpfInclude
    ? spfRecords.some((record) => record.toLowerCase().includes(expectedSpfInclude))
    : spfRecords.length > 0;

  const dkimChecks = isPurelymail
    ? await Promise.all(
      [1, 2, 3].map(async (index) => {
        const host = `purelymail${index}._domainkey.${domainName}`;
        const expectedTarget = `key${index}.dkimroot.purelymail.com`;
        const [cnames, txt] = await Promise.all([cnameRecords(host), txtRecords(host)]);
        const ready =
          cnames.includes(expectedTarget) ||
          txt.some((record) => /^v=dkim1(?:;|\s|$)/i.test(record));
        return { host, expectedTarget, cnames, txt, ready };
      })
    )
    : [];
  const dkimReady = dkimChecks.length > 0 && dkimChecks.every((record) => record.ready);

  const dmarcHost = `_dmarc.${domainName}`;
  const [directDmarcTxt, dmarcCnames] = await Promise.all([
    txtRecords(dmarcHost),
    cnameRecords(dmarcHost),
  ]);
  const cnameDmarcTxt = (
    await Promise.all(dmarcCnames.map((target) => txtRecords(target)))
  ).flat();
  const dmarcRecord = [...directDmarcTxt, ...cnameDmarcTxt].find((record) =>
    /^v=dmarc1(?:;|\s|$)/i.test(record)
  ) || '';
  const dmarcPolicy = dmarcRecord.match(/(?:^|;)\s*p\s*=\s*([^;\s]+)/i)?.[1]?.toLowerCase() || '';
  const dmarcReady = Boolean(dmarcRecord);

  return {
    spfReady,
    dkimReady,
    dmarcReady,
    dmarcPolicy,
    checklist: [
      {
        type: 'SPF',
        host: domainName,
        value: spfRecords.join(' | '),
        expected: expectedSpfInclude,
        status: spfReady ? 'verified' : 'missing',
      },
      {
        type: 'DKIM',
        host: isPurelymail ? `purelymail1-3._domainkey.${domainName}` : domainName,
        value: dkimChecks
          .map((record) => `${record.host} -> ${record.cnames.join(', ') || record.txt.join(', ')}`)
          .join(' | '),
        expected: isPurelymail ? 'key1-3.dkimroot.purelymail.com' : '',
        status: dkimReady ? 'verified' : 'missing',
      },
      {
        type: 'DMARC',
        host: dmarcHost,
        value: dmarcRecord,
        expected: 'v=DMARC1',
        status: dmarcReady ? 'verified' : 'missing',
      },
    ],
  };
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
