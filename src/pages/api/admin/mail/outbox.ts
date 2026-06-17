import type { APIRoute } from 'astro';
import { dbQuery } from '@/lib/server/supabaseDb';
import { json } from '@/lib/server/appDb';
import {
  numericLimit,
  numericOffset,
  requireMailAccess,
} from '@/lib/server/mail/api';
import { processDirectMailOutbox } from '@/lib/server/mail/campaignProcessor';

export const prerender = false;

function attachmentMetadata(value: unknown) {
  const items = Array.isArray(value) ? value : [];
  return items.map((item) => {
    const source =
      item && typeof item === 'object' ? (item as Record<string, any>) : {};
    return {
      filename: String(source.filename || source.name || 'dosya'),
      content_type: String(
        source.content_type || source.contentType || 'application/octet-stream',
      ),
      size: Number(source.size || 0),
      inline: source.inline === true,
      cid: source.cid ? String(source.cid) : undefined,
    };
  });
}

export const GET: APIRoute = async ({ request, url }) => {
  try {
    const access = await requireMailAccess(request);
    if (access.response) return access.response;

    await processDirectMailOutbox({ maxItems: 10 });

    const limit = numericLimit(url.searchParams.get('limit'), 25, 100);
    const offset = numericOffset(url.searchParams.get('offset'));
    const search = String(url.searchParams.get('search') || '').trim();
    const accountId = String(url.searchParams.get('accountId') || '').trim();
    const dateFrom = String(url.searchParams.get('dateFrom') || '').trim();
    const dateTo = String(url.searchParams.get('dateTo') || '').trim();

    const values: any[] = [];
    const where: string[] = [];
    if (accountId) {
      values.push(accountId);
      where.push(`mo.hesap_id = $${values.length}::bigint`);
    }
    if (dateFrom) {
      values.push(dateFrom);
      where.push(
        `COALESCE(mo.gonderim_tarihi, mo.olusturma_tarihi) >= $${values.length}::date`,
      );
    }
    if (dateTo) {
      values.push(dateTo);
      where.push(
        `COALESCE(mo.gonderim_tarihi, mo.olusturma_tarihi) < ($${values.length}::date + interval '1 day')`,
      );
    }
    if (search) {
      values.push(`%${search}%`);
      where.push(
        `(mo.konu ILIKE $${values.length} OR mo.alici_eposta ILIKE $${values.length})`,
      );
    }
    const whereSql = where.length ? `WHERE ${where.join(' AND ')}` : '';

    const [items, total, stats] = await Promise.all([
      dbQuery(
        `SELECT
           mo.id::text AS id,
           mo.hesap_id::text AS account_id,
           mo.kampanya_id::text AS campaign_id,
           mo.servis_message_id AS service_message_id,
           mo.alici_eposta AS recipient_email,
           mo.alici_adi AS recipient_name,
           mo.konu AS subject,
           mo.icerik_html AS content_html,
           mo.icerik_text AS content_text,
           COALESCE(NULLIF(mo.ek_dosyalar_json, ''), '[]')::jsonb AS attachments,
           mo.sablon_id::text AS template_id,
           mo.durum AS status,
           mo.hata_mesaji AS error_message,
           mo.bounce_nedeni AS bounce_reason,
           mo.zamanlanmis_tarih AS scheduled_at,
           mo.gonderim_tarihi AS sent_at,
           mo.teslim_tarihi AS delivered_at,
           mo.acilma_tarihi AS opened_at,
           mo.tiklanma_tarihi AS clicked_at,
           mo.olusturma_tarihi AS created_at,
           mo.kullanici AS created_by,
           ma.hesap_adi AS account_name,
           ma.gonderen_eposta AS account_email,
           ma.gonderen_adi AS sender_name,
           ma.gonderen_eposta AS sender_email
         FROM public.mail_outbox mo
         LEFT JOIN public.mail_accounts ma ON ma.id = mo.hesap_id
         ${whereSql}
         ORDER BY COALESCE(mo.gonderim_tarihi, mo.olusturma_tarihi) DESC
         LIMIT $${values.length + 1} OFFSET $${values.length + 2}`,
        [...values, limit, offset],
      ),
      dbQuery<{ count: string }>(
        `SELECT COUNT(*)::bigint AS count
         FROM public.mail_outbox mo
         ${whereSql}`,
        values,
      ),
      dbQuery(
        `SELECT
          COUNT(*)::bigint AS total,
          COUNT(*) FILTER (WHERE durum IN ('sent', 'delivered', 'opened', 'clicked'))::bigint AS successful,
          COUNT(*) FILTER (WHERE durum = 'queued')::bigint AS queued,
          COUNT(*) FILTER (WHERE durum = 'failed')::bigint AS failed
         FROM public.mail_outbox`,
      ),
    ]);

    return json({
      items: items.rows.map((row: any) => ({
        ...row,
        attachments: attachmentMetadata(row.attachments),
      })),
      total: Number(total.rows[0]?.count || 0),
      limit,
      offset,
      stats: {
        total: Number(stats.rows[0]?.total || 0),
        successful: Number(stats.rows[0]?.successful || 0),
        queued: Number(stats.rows[0]?.queued || 0),
        failed: Number(stats.rows[0]?.failed || 0),
      },
    });
  } catch (error: any) {
    return json(
      { error: { message: error.message || 'Outbox could not be loaded' } },
      500,
    );
  }
};
