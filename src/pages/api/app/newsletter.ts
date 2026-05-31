import type { APIRoute } from 'astro';
import { ensureAppSchema, json } from '@/lib/server/appDb';
import { dbQuery } from '@/lib/server/supabaseDb';

const EMAIL_RE = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;

export const POST: APIRoute = async ({ request }) => {
  try {
    const body = await request.json();
    const email = String(body.email || '').trim().toLowerCase();
    const languageCode = String(body.languageCode || 'tr').trim().slice(0, 10) || 'tr';
    const source = String(body.source || 'site').trim().slice(0, 60) || 'site';

    if (!EMAIL_RE.test(email)) {
      return json({ error: { message: 'Invalid email' } }, 400);
    }

    await ensureAppSchema();

    const existing = await dbQuery(
      'SELECT id FROM public.newsletter_subscribers WHERE lower(email) = lower($1) LIMIT 1',
      [email]
    );

    const result = existing.rows[0]
      ? await dbQuery(
        `UPDATE public.newsletter_subscribers
         SET status = 'active', language_code = $2, source = $3, updated_at = now()
         WHERE id = $1
         RETURNING *`,
        [existing.rows[0].id, languageCode, source]
      )
      : await dbQuery(
        `INSERT INTO public.newsletter_subscribers (email, language_code, source)
         VALUES ($1, $2, $3)
         RETURNING *`,
        [email, languageCode, source]
      );

    return json({ ok: true, subscriber: result.rows[0] });
  } catch (error: any) {
    return json({ error: { message: error.message || 'Newsletter subscription failed' } }, 500);
  }
};

