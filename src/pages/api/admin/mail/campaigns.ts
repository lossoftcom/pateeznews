import type { APIRoute } from 'astro';
import { dbQuery } from '@/lib/server/supabaseDb';
import { json } from '@/lib/server/appDb';
import { numericLimit, numericOffset, readJsonBody, requireMailAccess, sqlSetClause } from '@/lib/server/mail/api';

export const prerender = false;

const CAMPAIGN_SELECT = `
  mc.id::text AS id,
  mc.hesap_id::text AS account_id,
  mc.kampanya_adi AS campaign_name,
  mc.konu AS subject,
  mc.onizleme_metni AS preview_text,
  mc.icerik_html AS content_html,
  mc.sablon_id::text AS template_id,
  mc.kisi_listesi_id::text AS contact_list_id,
  mc.alici_sayisi AS recipient_count,
  mc.gonderilen_sayisi AS sent_count,
  mc.zamanlanmis_baslangic AS scheduled_start_at,
  mc.baslangic_tarihi AS started_at,
  mc.bitis_tarihi AS finished_at,
  mc.durum AS status,
  mc.gonderim_hizi AS send_rate,
  mc.son_gonderilen_index AS last_sent_index,
  mc.teslim_edilen AS delivered_count,
  mc.acilan AS opened_count,
  mc.tiklanan AS clicked_count,
  mc.bouncelar AS bounce_count,
  mc.sikayetler AS complaint_count,
  mc.iptaller AS unsubscribe_count,
  mc.unsubscribe_linki_ekle AS add_unsubscribe_link,
  mc.takip_pikseli_ekle AS add_tracking_pixel,
  mc.olusturma_tarihi AS created_at,
  mc.guncelleme_tarihi AS updated_at,
  mc.kullanici AS created_by,
  ma.hesap_adi AS account_name,
  ma.gonderen_eposta AS account_email,
  mcl.liste_adi AS contact_list_name,
  mt.sablon_adi AS template_name,
  mt.kategori AS template_category
`;

const FIELD_MAP: Record<string, string> = {
  account_id: 'hesap_id',
  campaign_name: 'kampanya_adi',
  subject: 'konu',
  preview_text: 'onizleme_metni',
  content_html: 'icerik_html',
  template_id: 'sablon_id',
  contact_list_id: 'kisi_listesi_id',
  recipient_count: 'alici_sayisi',
  scheduled_start_at: 'zamanlanmis_baslangic',
  status: 'durum',
  send_rate: 'gonderim_hizi',
  add_unsubscribe_link: 'unsubscribe_linki_ekle',
  add_tracking_pixel: 'takip_pikseli_ekle',
};

function campaignPayload(body: Record<string, any>) {
  const payload: Record<string, any> = {};
  for (const [clientKey, dbKey] of Object.entries(FIELD_MAP)) {
    if (Object.prototype.hasOwnProperty.call(body, clientKey)) payload[dbKey] = body[clientKey];
  }
  return normalizeOptionalUuids(payload);
}

async function contactCount(listId?: string | null) {
  if (!listId) return 0;
  const result = await dbQuery<{ count: string }>(
    `SELECT COUNT(*)::bigint AS count
     FROM public.mail_contact_list_memberships m
     JOIN public.mail_contacts c ON c.id = m.contact_id
     WHERE m.list_id = $1::bigint
       AND c.aktif_mi IS TRUE
       AND c.unsubscribe_tarihi IS NULL
       AND COALESCE(c.bounce_durumu, 'none') <> 'hard'
       AND COALESCE(c.dogrulama_durumu, 'unknown') <> 'invalid'`,
    [listId]
  );
  return Number(result.rows[0]?.count || 0);
}

async function campaignSendError(id: string) {
  const result = await dbQuery(
    `SELECT
       mc.icerik_html,
       mc.sablon_id,
       mc.kisi_listesi_id,
       ma.aktif_mi AS account_active
     FROM public.mail_campaigns mc
     LEFT JOIN public.mail_accounts ma ON ma.id = mc.hesap_id
     WHERE mc.id = $1::bigint
     LIMIT 1`,
    [id]
  );
  const campaign = result.rows[0];
  if (!campaign) return 'Campaign not found';
  if (!campaign.account_active) return 'An active sender account is required';
  if (!campaign.sablon_id || !String(campaign.icerik_html || '').trim()) {
    return 'A mail template is required';
  }
  if (!campaign.kisi_listesi_id || (await contactCount(campaign.kisi_listesi_id)) === 0) {
    return 'The contact list has no sendable contacts';
  }
  return '';
}

function normalizeOptionalUuids(payload: Record<string, any>) {
  for (const key of ['hesap_id', 'sablon_id', 'kisi_listesi_id']) {
    if (Object.prototype.hasOwnProperty.call(payload, key) && !String(payload[key] || '').trim()) {
      payload[key] = null;
    }
  }
  return payload;
}

export const GET: APIRoute = async ({ request, url }) => {
  try {
    const access = await requireMailAccess(request);
    if (access.response) return access.response;

    const limit = numericLimit(url.searchParams.get('limit'), 25, 100);
    const offset = numericOffset(url.searchParams.get('offset'));
    const search = String(url.searchParams.get('search') || '').trim();
    const status = String(url.searchParams.get('status') || '').trim();
    const id = String(url.searchParams.get('id') || '').trim();

    const values: any[] = [];
    const where: string[] = [];
    if (id) {
      values.push(id);
      where.push(`mc.id = $${values.length}::bigint`);
    }
    if (status && status !== 'all') {
      values.push(status);
      where.push(`mc.durum = $${values.length}`);
    }
    if (search) {
      values.push(`%${search}%`);
      where.push(`(mc.kampanya_adi ILIKE $${values.length} OR mc.konu ILIKE $${values.length})`);
    }
    const whereSql = where.length ? `WHERE ${where.join(' AND ')}` : '';

    const [items, total, stats] = await Promise.all([
      dbQuery(
        `SELECT ${CAMPAIGN_SELECT}
	         FROM public.mail_campaigns mc
	         LEFT JOIN public.mail_accounts ma ON ma.id = mc.hesap_id
	         LEFT JOIN public.mail_contact_lists mcl ON mcl.id = mc.kisi_listesi_id
	         LEFT JOIN public.mail_templates mt ON mt.id = mc.sablon_id
	         ${whereSql}
         ORDER BY mc.olusturma_tarihi DESC
         LIMIT $${values.length + 1} OFFSET $${values.length + 2}`,
        [...values, limit, offset]
      ),
      dbQuery<{ count: string }>(
        `SELECT COUNT(*)::bigint AS count
         FROM public.mail_campaigns mc
         ${whereSql}`,
        values
      ),
      dbQuery(
        `SELECT
          COUNT(*)::bigint AS total,
          COUNT(*) FILTER (WHERE durum = 'sending')::bigint AS sending,
          COUNT(*) FILTER (WHERE durum = 'scheduled')::bigint AS scheduled,
          COUNT(*) FILTER (WHERE durum = 'completed')::bigint AS completed
         FROM public.mail_campaigns`
      ),
    ]);

    return json({
      items: items.rows,
      total: Number(total.rows[0]?.count || 0),
      limit,
      offset,
      stats: {
        total: Number(stats.rows[0]?.total || 0),
        sending: Number(stats.rows[0]?.sending || 0),
        scheduled: Number(stats.rows[0]?.scheduled || 0),
        completed: Number(stats.rows[0]?.completed || 0),
      },
    });
  } catch (error: any) {
    return json({ error: { message: error.message || 'Campaigns could not be loaded' } }, 500);
  }
};

export const POST: APIRoute = async ({ request }) => {
  const body = await readJsonBody(request);
  try {
    const access = await requireMailAccess(request, body);
    if (access.response) return access.response;

    const payload = campaignPayload(body);
    payload.kampanya_adi = String(payload.kampanya_adi || '').trim();
    payload.konu = String(payload.konu || '').trim();
    payload.durum = String(payload.durum || 'draft').trim();
    payload.alici_sayisi = Number(payload.alici_sayisi || await contactCount(payload.kisi_listesi_id)) || 0;
    payload.kullanici = access.session!.user.id;
    payload.guncelleme_tarihi = new Date().toISOString();

    if (!payload.kampanya_adi || !payload.konu) return json({ error: { message: 'Campaign name and subject are required' } }, 400);
    if (!payload.hesap_id || !payload.sablon_id || !payload.kisi_listesi_id || !String(payload.icerik_html || '').trim()) {
      return json({ error: { message: 'Sender account, template, contact list, and content are required' } }, 400);
    }

    const keys = Object.keys(payload);
    const result = await dbQuery(
      `INSERT INTO public.mail_campaigns (${keys.join(', ')})
       VALUES (${keys.map((_, index) => `$${index + 1}`).join(', ')})
       RETURNING id`,
      keys.map((key) => payload[key])
    );

    const saved = await dbQuery(
      `SELECT ${CAMPAIGN_SELECT}
       FROM public.mail_campaigns mc
       LEFT JOIN public.mail_accounts ma ON ma.id = mc.hesap_id
       LEFT JOIN public.mail_contact_lists mcl ON mcl.id = mc.kisi_listesi_id
       LEFT JOIN public.mail_templates mt ON mt.id = mc.sablon_id
       WHERE mc.id = $1::bigint`,
      [result.rows[0]?.id]
    );

    return json({ campaign: saved.rows[0] });
  } catch (error: any) {
    return json({ error: { message: error.message || 'Campaign could not be saved' } }, 500);
  }
};

export const PATCH: APIRoute = async ({ request }) => {
  const body = await readJsonBody(request);
  try {
    const access = await requireMailAccess(request, body);
    if (access.response) return access.response;

    const id = String(body.id || '').trim();
    if (!id) return json({ error: { message: 'Campaign id required' } }, 400);

    const action = String(body.action || '').trim();
    if (action) {
      const actionSql: Record<string, string> = {
        start: "durum = 'sending', baslangic_tarihi = COALESCE(baslangic_tarihi, now())",
        pause: "durum = 'paused'",
        resume: "durum = 'sending'",
        cancel: "durum = 'cancelled', bitis_tarihi = COALESCE(bitis_tarihi, now())",
        complete: "durum = 'completed', bitis_tarihi = COALESCE(bitis_tarihi, now())",
        remove_schedule: "durum = 'draft', zamanlanmis_baslangic = null",
      };

      if (action === 'schedule') {
        const scheduled = String(body.scheduled_start_at || '').trim();
        if (!scheduled) return json({ error: { message: 'Schedule date required' } }, 400);
        const sendError = await campaignSendError(id);
        if (sendError) return json({ error: { message: sendError } }, 400);
        await dbQuery("UPDATE public.mail_campaigns SET durum = 'scheduled', zamanlanmis_baslangic = $1, guncelleme_tarihi = now() WHERE id = $2::bigint", [scheduled, id]);
      } else if (action === 'start') {
        const sendError = await campaignSendError(id);
        if (sendError) return json({ error: { message: sendError } }, 400);
        await dbQuery(
          `UPDATE public.mail_campaigns
           SET durum = 'sending',
               baslangic_tarihi = COALESCE(baslangic_tarihi, now()),
               zamanlanmis_baslangic = null,
               guncelleme_tarihi = now()
           WHERE id = $1::bigint`,
          [id]
        );
      } else if (action === 'resume') {
        await dbQuery(
          `UPDATE public.mail_outbox
           SET durum = 'queued', hata_mesaji = null
           WHERE kampanya_id = $1::bigint AND durum = 'failed'`,
          [id]
        );
        await dbQuery(
          `UPDATE public.mail_campaigns
           SET durum = 'sending', guncelleme_tarihi = now()
           WHERE id = $1::bigint`,
          [id]
        );
      } else if (actionSql[action]) {
        await dbQuery(`UPDATE public.mail_campaigns SET ${actionSql[action]}, guncelleme_tarihi = now() WHERE id = $1::bigint`, [id]);
      } else {
        return json({ error: { message: 'Unsupported campaign action' } }, 400);
      }
    } else {
      const update = campaignPayload(body);
      if (Object.prototype.hasOwnProperty.call(update, 'kisi_listesi_id')) {
        update.alici_sayisi = Number(update.alici_sayisi || await contactCount(update.kisi_listesi_id)) || 0;
      }
      update.guncelleme_tarihi = new Date().toISOString();
      const set = sqlSetClause(update);
      if (!set.keys.length) return json({ error: { message: 'No changes' } }, 400);
      await dbQuery(`UPDATE public.mail_campaigns SET ${set.clause} WHERE id = $${set.values.length + 1}::bigint`, [...set.values, id]);
    }

    const result = await dbQuery(
      `SELECT ${CAMPAIGN_SELECT}
       FROM public.mail_campaigns mc
       LEFT JOIN public.mail_accounts ma ON ma.id = mc.hesap_id
       LEFT JOIN public.mail_contact_lists mcl ON mcl.id = mc.kisi_listesi_id
       LEFT JOIN public.mail_templates mt ON mt.id = mc.sablon_id
       WHERE mc.id = $1::bigint`,
      [id]
    );

    return json({ campaign: result.rows[0] });
  } catch (error: any) {
    return json({ error: { message: error.message || 'Campaign could not be updated' } }, 500);
  }
};

export const DELETE: APIRoute = async ({ request, url }) => {
  const body = await readJsonBody(request);
  try {
    const access = await requireMailAccess(request, body);
    if (access.response) return access.response;

    const id = String(body.id || url.searchParams.get('id') || '').trim();
    if (!id) return json({ error: { message: 'Campaign id required' } }, 400);
    await dbQuery('DELETE FROM public.mail_campaigns WHERE id = $1::bigint', [id]);
    return json({ ok: true });
  } catch (error: any) {
    return json({ error: { message: error.message || 'Campaign could not be deleted' } }, 500);
  }
};
