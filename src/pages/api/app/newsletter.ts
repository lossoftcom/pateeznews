import type { APIRoute } from 'astro';
import { ensureAppSchema, json } from '@/lib/server/appDb';
import { dbQuery } from '@/lib/server/supabaseDb';
import { getRequestLocation } from '@/lib/server/requestLocation';
import { notifyAdminsForSubscriber } from '@/lib/server/notifications/adminEvents';

const EMAIL_RE = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;

export const POST: APIRoute = async ({ request }) => {
  try {
    const body = await request.json();
    const email = String(body.email || '').trim().toLowerCase();
    const languageCode = String(body.languageCode || 'tr').trim().slice(0, 10) || 'tr';
    const source = String(body.source || 'site').trim().slice(0, 60) || 'site';
    const location = getRequestLocation(request);

    if (!EMAIL_RE.test(email)) {
      return json({ error: { message: 'Invalid email' } }, 400);
    }

    await ensureAppSchema();

    const existing = await dbQuery<{ id: string; status: string | null }>(
      'SELECT id, status FROM public.newsletter_subscribers WHERE lower(email) = lower($1) LIMIT 1',
      [email]
    );
    const wasActive = String(existing.rows[0]?.status || '').toLowerCase() === 'active';
    const shouldNotifyAdmin = !existing.rows[0] || !wasActive;

    const result = existing.rows[0]
      ? await dbQuery(
        `UPDATE public.newsletter_subscribers
         SET status = 'active',
             language_code = $2,
             source = $3,
             ip_address = COALESCE($4::text, ip_address),
             city = COALESCE($5::text, city),
             updated_at = now()
         WHERE id = $1
         RETURNING *`,
        [existing.rows[0].id, languageCode, source, location.ip, location.city]
      )
      : await dbQuery(
        `INSERT INTO public.newsletter_subscribers (email, language_code, source, ip_address, city)
         VALUES ($1, $2, $3, $4, $5)
         RETURNING *`,
        [email, languageCode, source, location.ip, location.city]
      );

    if (shouldNotifyAdmin && result.rows[0]?.id) {
      await notifyAdminsForSubscriber({
        subscriberId: result.rows[0].id,
        email: result.rows[0].email || email,
        source: result.rows[0].source || source,
        city: result.rows[0].city || location.city,
        languageCode: result.rows[0].language_code || languageCode,
      }).catch((notifyError) => {
        console.warn(
          'Subscriber admin notification failed:',
          notifyError?.message || notifyError,
        );
      });
    }

    return json({ ok: true, subscriber: result.rows[0] });
  } catch (error: any) {
    return json({ error: { message: error.message || 'Newsletter subscription failed' } }, 500);
  }
};
