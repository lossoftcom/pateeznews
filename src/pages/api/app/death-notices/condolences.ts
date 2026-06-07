import type { APIRoute } from 'astro';
import { getSessionFromRequest, json } from '@/lib/server/appDb';
import { dbQuery } from '@/lib/server/supabaseDb';

const MAX_MESSAGE_LENGTH = 600;

const normalizeText = (value: unknown) =>
  String(value || '')
    .replace(/\u00a0/g, ' ')
    .replace(/[ \t\r\f\v]+/g, ' ')
    .trim();

const ensureCondolenceSchema = async () => {
  await dbQuery(`
    CREATE TABLE IF NOT EXISTS public.death_notice_condolences (
      id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
      notice_id text NOT NULL,
      notice_name text NOT NULL,
      user_id uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
      guest_name text,
      guest_email text,
      message text NOT NULL,
      status text NOT NULL DEFAULT 'pending'
        CHECK (status IN ('pending', 'approved', 'rejected')),
      created_at timestamptz NOT NULL DEFAULT now()
    )
  `);
  await dbQuery(`
    CREATE INDEX IF NOT EXISTS death_notice_condolences_notice_status_idx
    ON public.death_notice_condolences (notice_id, status, created_at DESC)
  `);
};

export const POST: APIRoute = async ({ request }) => {
  let body: any;
  try {
    body = await request.json();
  } catch {
    return json({ ok: false, error: 'Geçersiz istek' }, 400);
  }

  const noticeId = normalizeText(body?.noticeId);
  const noticeName = normalizeText(body?.noticeName);
  const message = normalizeText(body?.message).slice(0, MAX_MESSAGE_LENGTH);
  const guestName = normalizeText(body?.guestName);
  const guestEmail = normalizeText(body?.guestEmail);
  const hasAuth = Boolean(request.headers.get('authorization'));
  const session = hasAuth ? await getSessionFromRequest(request).catch(() => null) : null;

  if (!noticeId || !noticeName || !message) {
    return json({ ok: false, error: 'Taziye mesajı eksik' }, 400);
  }

  if (!session && (!guestName || !guestEmail)) {
    return json({ ok: false, error: 'Misafir adı ve e-posta gerekli' }, 400);
  }

  try {
    await ensureCondolenceSchema();
    await dbQuery(
      `INSERT INTO public.death_notice_condolences
       (notice_id, notice_name, user_id, guest_name, guest_email, message, status)
       VALUES ($1, $2, $3, $4, $5, $6, 'pending')`,
      [
        noticeId,
        noticeName,
        session?.user?.id || null,
        session ? null : guestName,
        session ? null : guestEmail,
        message,
      ]
    );
    return json({ ok: true, status: 'pending' });
  } catch (error: any) {
    return json(
      { ok: false, error: error?.message || 'Taziye mesajı gönderilemedi' },
      502
    );
  }
};
