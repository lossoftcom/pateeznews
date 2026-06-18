import type { APIRoute } from 'astro';
import { json } from '@/lib/server/appDb';
import { dbQuery } from '@/lib/server/supabaseDb';

const MAX_NAME_LENGTH = 120;
const MAX_EMAIL_LENGTH = 180;
const MAX_PHONE_LENGTH = 40;
const MAX_SUBJECT_LENGTH = 160;
const MAX_MESSAGE_LENGTH = 5000;
const EMAIL_PATTERN = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;

type ContactBody = Record<string, FormDataEntryValue | string | null | undefined>;

function compact(value: unknown, maxLength: number) {
  return String(value || '')
    .replace(/\s+/g, ' ')
    .trim()
    .slice(0, maxLength);
}

function messageText(value: unknown) {
  return String(value || '')
    .replace(/\r\n/g, '\n')
    .trim()
    .slice(0, MAX_MESSAGE_LENGTH);
}

function escapeHtml(value: string) {
  return value
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
    .replace(/'/g, '&#39;');
}

function buildHtmlMessage(fields: {
  name: string;
  email: string;
  phone: string;
  subject: string;
  message: string;
}) {
  const rows = [
    ['Ad Soyad', fields.name],
    ['E-posta', fields.email],
    ['Telefon', fields.phone],
    ['Konu', fields.subject],
  ].filter(([, value]) => value);

  return [
    '<div>',
    '<h2>Yeni iletişim mesajı</h2>',
    '<ul>',
    ...rows.map(
      ([label, value]) => `<li><strong>${escapeHtml(label)}:</strong> ${escapeHtml(value)}</li>`,
    ),
    '</ul>',
    '<hr>',
    `<p>${escapeHtml(fields.message).replace(/\n/g, '<br>')}</p>`,
    '</div>',
  ].join('');
}

async function parseBody(request: Request): Promise<ContactBody> {
  const contentType = request.headers.get('content-type') || '';
  if (contentType.includes('application/json')) {
    const body = await request.json();
    return body && typeof body === 'object' ? body : {};
  }
  const formData = await request.formData();
  return Object.fromEntries(formData.entries());
}

export const POST: APIRoute = async ({ request }) => {
  try {
    const body = await parseBody(request);
    if (compact(body.company, 120)) {
      return json({ ok: true, message: 'Mesajınız alındı.' });
    }

    const name = compact(body.name, MAX_NAME_LENGTH);
    const email = compact(body.email, MAX_EMAIL_LENGTH).toLowerCase();
    const phone = compact(body.phone, MAX_PHONE_LENGTH);
    const subject = compact(body.subject, MAX_SUBJECT_LENGTH) || 'İletişim mesajı';
    const message = messageText(body.message);

    if (!name) {
      return json({ ok: false, error: { message: 'Ad soyad zorunludur.' } }, 400);
    }
    if (!EMAIL_PATTERN.test(email)) {
      return json({ ok: false, error: { message: 'Geçerli bir e-posta giriniz.' } }, 400);
    }
    if (!message || message.length < 10) {
      return json({ ok: false, error: { message: 'Mesaj en az 10 karakter olmalıdır.' } }, 400);
    }

    const accountResult = await dbQuery<{ id: string; gonderen_eposta: string }>(
      `SELECT id::text, gonderen_eposta
       FROM public.mail_accounts
       WHERE COALESCE(aktif_mi, true) = true
       ORDER BY id ASC
       LIMIT 1`,
    );
    const account = accountResult.rows[0];
    if (!account) {
      return json({ ok: false, error: { message: 'İletişim mesajı için aktif mail hesabı bulunamadı.' } }, 503);
    }

    const randomId = typeof crypto !== 'undefined' && 'randomUUID' in crypto
      ? crypto.randomUUID()
      : Math.random().toString(36).slice(2);
    const messageId = `contact-${Date.now()}-${randomId}`;
    const inboxSubject = `İletişim: ${subject}`;
    const textContent = [
      `Ad Soyad: ${name}`,
      `E-posta: ${email}`,
      phone ? `Telefon: ${phone}` : '',
      `Konu: ${subject}`,
      '',
      message,
    ].filter(Boolean).join('\n');

    await dbQuery(
      `INSERT INTO public.mail_inbox (
        hesap_id,
        message_id,
        gonderen_eposta,
        gonderen_adi,
        alici_eposta,
        konu,
        icerik_text,
        icerik_html,
        ek_dosyalar_json,
        resimler_json,
        okundu,
        yildizli,
        etiketler_json,
        klasor,
        mail_tarihi,
        olusturma_tarihi
      ) VALUES (
        $1::bigint,
        $2,
        $3,
        $4,
        $5,
        $6,
        $7,
        $8,
        '[]',
        '[]',
        false,
        false,
        $9,
        'gelen',
        now(),
        now()
      )`,
      [
        account.id,
        messageId,
        email,
        name,
        account.gonderen_eposta || null,
        inboxSubject,
        textContent,
        buildHtmlMessage({ name, email, phone, subject, message }),
        JSON.stringify(['iletisim']),
      ],
    );

    return json({ ok: true, message: 'Mesajınız alındı.' });
  } catch (error) {
    const message = error instanceof Error ? error.message : 'İletişim mesajı gönderilemedi.';
    return json({ ok: false, error: { message } }, 500);
  }
};
