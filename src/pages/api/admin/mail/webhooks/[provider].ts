import type { APIRoute } from 'astro';
import { dbQuery } from '@/lib/server/neonDb';
import { json } from '@/lib/server/appDb';
import { ensureMailSchema } from '@/lib/server/mail/schema';

export const prerender = false;

function normalizeEvents(payload: any) {
  if (Array.isArray(payload)) return payload;
  if (Array.isArray(payload?.events)) return payload.events;
  if (payload?.event) return [payload];
  return [];
}

function eventStatus(event: any) {
  const type = String(event.event || event.type || event.event_type || '').toLowerCase();
  if (type.includes('open')) return 'opened';
  if (type.includes('click')) return 'clicked';
  if (type.includes('deliver')) return 'delivered';
  if (type.includes('bounce')) return 'bounce';
  if (type.includes('fail')) return 'failed';
  if (type.includes('unsubscribe')) return 'unsubscribed';
  return '';
}

export const POST: APIRoute = async ({ request, params }) => {
  try {
    await ensureMailSchema();
    const provider = String(params.provider || '').trim();
    const body = await request.json().catch(() => ({}));
    const events = normalizeEvents(body);
    const handled: any[] = [];

    for (const event of events) {
      const status = eventStatus(event);
      const messageId = String(event.message_id || event.sg_message_id || event.MessageID || event.id || '').trim();
      const email = String(event.email || event.recipient || event.to || '').trim().toLowerCase();
      if (!status || (!messageId && !email)) continue;

      if (status === 'unsubscribed' && email) {
        await dbQuery('UPDATE public.mail_contacts SET unsubscribe_tarihi = now() WHERE lower(eposta) = lower($1)', [email]);
        handled.push({ status, email });
        continue;
      }

      if (status === 'opened' || status === 'clicked' || status === 'delivered') {
        const column = status === 'opened' ? 'acilma_tarihi' : status === 'clicked' ? 'tiklanma_tarihi' : 'teslim_tarihi';
        await dbQuery(
          `UPDATE public.mail_outbox
           SET durum = $1, ${column} = now()
           WHERE ($2 <> '' AND servis_message_id = $2)
              OR ($3 <> '' AND lower(alici_eposta) = lower($3))`,
          [status, messageId, email]
        );
      } else {
        const message = String(event.reason || event.error || provider || status);
        await dbQuery(
          `UPDATE public.mail_outbox
           SET durum = $1,
               hata_mesaji = CASE WHEN $1 = 'failed' THEN $2 ELSE hata_mesaji END,
               bounce_nedeni = CASE WHEN $1 = 'bounce' THEN $2 ELSE bounce_nedeni END
           WHERE ($3 <> '' AND servis_message_id = $3)
              OR ($4 <> '' AND lower(alici_eposta) = lower($4))`,
          [status, message, messageId, email]
        );
      }
      handled.push({ status, messageId, email });
    }

    return json({ ok: true, provider, handled });
  } catch (error: any) {
    return json({ error: { message: error.message || 'Webhook could not be processed' } }, 500);
  }
};
