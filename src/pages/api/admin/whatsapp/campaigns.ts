import type { APIRoute } from "astro";
import { json } from "@/lib/server/appDb";
import { dbQuery } from "@/lib/server/supabaseDb";
import {
  numericLimit,
  numericOffset,
  readJsonBody,
  requireWhatsappAccess,
  sqlSetClause,
} from "@/lib/server/whatsapp/api";

export const prerender = false;

const CAMPAIGN_SELECT = `
  wc.id::text AS id,
  wc.hesap_id::text AS account_id,
  wc.kampanya_adi AS campaign_name,
  wc.konu AS subject,
  wc.onizleme_metni AS preview_text,
  wc.icerik_text AS content_text,
  wc.sablon_id::text AS template_id,
  wc.kisi_listesi_id::text AS contact_list_id,
  wc.alici_sayisi AS recipient_count,
  wc.gonderilen_sayisi AS sent_count,
  wc.zamanlanmis_baslangic AS scheduled_start_at,
  wc.baslangic_tarihi AS started_at,
  wc.bitis_tarihi AS finished_at,
  wc.durum AS status,
  wc.teslim_edilen AS delivered_count,
  wc.okunan AS read_count,
  wc.tiklanan AS clicked_count,
  wc.bouncelar AS bounce_count,
  wc.olusturma_tarihi AS created_at,
  wc.guncelleme_tarihi AS updated_at,
  wc.kullanici AS created_by,
  wa.hesap_adi AS account_name,
  wa.telefon AS account_phone,
  wcl.liste_adi AS contact_list_name,
  wt.sablon_adi AS template_name,
  wt.kategori AS template_category
`;

const FIELD_MAP: Record<string, string> = {
  account_id: "hesap_id",
  campaign_name: "kampanya_adi",
  subject: "konu",
  preview_text: "onizleme_metni",
  content_text: "icerik_text",
  template_id: "sablon_id",
  contact_list_id: "kisi_listesi_id",
  recipient_count: "alici_sayisi",
  scheduled_start_at: "zamanlanmis_baslangic",
  status: "durum",
};

function campaignPayload(body: Record<string, any>) {
  const payload: Record<string, any> = {};
  for (const [clientKey, dbKey] of Object.entries(FIELD_MAP)) {
    if (Object.prototype.hasOwnProperty.call(body, clientKey))
      payload[dbKey] = body[clientKey];
  }
  return normalizeOptionalIds(payload);
}

function normalizeOptionalIds(payload: Record<string, any>) {
  for (const key of ["hesap_id", "sablon_id", "kisi_listesi_id"]) {
    if (
      Object.prototype.hasOwnProperty.call(payload, key) &&
      !String(payload[key] || "").trim()
    ) {
      payload[key] = null;
    }
  }
  return payload;
}

async function contactCount(listId?: string | null) {
  if (!listId) return 0;
  const result = await dbQuery<{ count: string }>(
    `SELECT COUNT(*)::bigint AS count
     FROM public.whatsapp_contact_list_memberships m
     JOIN public.whatsapp_contacts c ON c.id = m.contact_id
     WHERE m.list_id = $1::bigint
       AND c.aktif_mi IS TRUE
       AND c.unsubscribe_tarihi IS NULL
       AND COALESCE(c.dogrulama_durumu, 'unknown') <> 'invalid'`,
    [listId],
  );
  return Number(result.rows[0]?.count || 0);
}

async function campaignSendError(id: string) {
  const result = await dbQuery(
    `SELECT
       wc.hesap_id,
       wc.sablon_id,
       wc.kisi_listesi_id,
       wc.icerik_text,
       wa.aktif_mi AS account_active,
       COALESCE(wa.gunluk_limit, 0) AS daily_limit,
       COALESCE(wa.bugun_gonderilen, 0) AS sent_today,
       wt.hazir_mi AS template_ready,
       wt.aktif_mi AS template_active,
       wcl.aktif_mi AS list_active
     FROM public.whatsapp_campaigns wc
     LEFT JOIN public.whatsapp_accounts wa ON wa.id = wc.hesap_id
     LEFT JOIN public.whatsapp_templates wt ON wt.id = wc.sablon_id
     LEFT JOIN public.whatsapp_contact_lists wcl ON wcl.id = wc.kisi_listesi_id
     WHERE wc.id = $1::bigint
     LIMIT 1`,
    [id],
  );
  const campaign = result.rows[0];
  if (!campaign) return "Campaign not found";
  if (!campaign.hesap_id || !campaign.account_active)
    return "An active WhatsApp sender account is required";
  if (
    !campaign.sablon_id ||
    !campaign.template_active ||
    !campaign.template_ready
  ) {
    return "A ready and active Meta-approved WhatsApp template is required";
  }
  if (!String(campaign.icerik_text || "").trim())
    return "Campaign content is required";
  if (!campaign.kisi_listesi_id || !campaign.list_active)
    return "An active contact list is required";
  const recipients = await contactCount(campaign.kisi_listesi_id);
  if (recipients <= 0)
    return "The contact list has no sendable WhatsApp contacts";
  const dailyLimit = Number(campaign.daily_limit || 0);
  const sentToday = Number(campaign.sent_today || 0);
  if (dailyLimit > 0 && sentToday + recipients > dailyLimit) {
    return "This campaign would exceed the sender account daily WhatsApp limit";
  }
  return "";
}

function normalizeSchedule(payload: Record<string, any>, defaultDraft = false) {
  const hasStatus = Object.prototype.hasOwnProperty.call(payload, "durum");
  const hasSchedule = Object.prototype.hasOwnProperty.call(
    payload,
    "zamanlanmis_baslangic",
  );
  if (!defaultDraft && !hasStatus && !hasSchedule) return "";

  const scheduled = String(payload.zamanlanmis_baslangic || "").trim();
  if (hasStatus || defaultDraft) {
    payload.durum = String(payload.durum || "draft").trim();
  }
  if (scheduled && (!payload.durum || payload.durum === "draft")) {
    payload.durum = "scheduled";
  }
  if (payload.durum === "scheduled" && !scheduled)
    return "Schedule date required";
  if (!scheduled) return "";
  const scheduledAt = Date.parse(scheduled);
  if (Number.isNaN(scheduledAt)) return "Schedule date is invalid";
  if (scheduledAt <= Date.now()) return "Schedule date must be in the future";
  return "";
}

async function selectedCampaign(id: string) {
  const result = await dbQuery(
    `SELECT ${CAMPAIGN_SELECT}
     FROM public.whatsapp_campaigns wc
     LEFT JOIN public.whatsapp_accounts wa ON wa.id = wc.hesap_id
     LEFT JOIN public.whatsapp_contact_lists wcl ON wcl.id = wc.kisi_listesi_id
     LEFT JOIN public.whatsapp_templates wt ON wt.id = wc.sablon_id
     WHERE wc.id = $1::bigint`,
    [id],
  );
  return result.rows[0];
}

export const GET: APIRoute = async ({ request, url }) => {
  try {
    const access = await requireWhatsappAccess(request);
    if (access.response) return access.response;

    const limit = numericLimit(url.searchParams.get("limit"), 25, 100);
    const offset = numericOffset(url.searchParams.get("offset"));
    const search = String(url.searchParams.get("search") || "").trim();
    const status = String(url.searchParams.get("status") || "").trim();
    const values: any[] = [];
    const where: string[] = [];
    if (status && status !== "all") {
      values.push(status);
      where.push(`wc.durum = $${values.length}`);
    }
    if (search) {
      values.push(`%${search}%`);
      where.push(
        `(wc.kampanya_adi ILIKE $${values.length} OR wc.konu ILIKE $${values.length} OR wc.onizleme_metni ILIKE $${values.length})`,
      );
    }
    const whereSql = where.length ? `WHERE ${where.join(" AND ")}` : "";

    const [items, total, stats] = await Promise.all([
      dbQuery(
        `SELECT ${CAMPAIGN_SELECT}
         FROM public.whatsapp_campaigns wc
         LEFT JOIN public.whatsapp_accounts wa ON wa.id = wc.hesap_id
         LEFT JOIN public.whatsapp_contact_lists wcl ON wcl.id = wc.kisi_listesi_id
         LEFT JOIN public.whatsapp_templates wt ON wt.id = wc.sablon_id
         ${whereSql}
         ORDER BY wc.olusturma_tarihi DESC
         LIMIT $${values.length + 1} OFFSET $${values.length + 2}`,
        [...values, limit, offset],
      ),
      dbQuery<{ count: string }>(
        `SELECT COUNT(*)::bigint AS count FROM public.whatsapp_campaigns wc ${whereSql}`,
        values,
      ),
      dbQuery(
        `SELECT
          COUNT(*)::bigint AS total,
          COUNT(*) FILTER (WHERE durum = 'sending')::bigint AS sending,
          COUNT(*) FILTER (WHERE durum = 'scheduled')::bigint AS scheduled,
          COUNT(*) FILTER (WHERE durum = 'completed')::bigint AS completed
         FROM public.whatsapp_campaigns`,
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
    return json(
      {
        error: {
          message: error.message || "WhatsApp campaigns could not be loaded",
        },
      },
      500,
    );
  }
};

export const POST: APIRoute = async ({ request }) => {
  const body = await readJsonBody(request);
  try {
    const access = await requireWhatsappAccess(request, body);
    if (access.response) return access.response;

    const payload = campaignPayload(body);
    payload.kampanya_adi = String(payload.kampanya_adi || "").trim();
    payload.konu = String(payload.konu || "").trim();
    payload.onizleme_metni = String(payload.onizleme_metni || "").trim();
    payload.icerik_text = String(
      payload.icerik_text || payload.onizleme_metni || "",
    ).trim();
    const scheduleError = normalizeSchedule(payload, true);
    if (scheduleError) return json({ error: { message: scheduleError } }, 400);
    payload.alici_sayisi =
      Number(
        payload.alici_sayisi || (await contactCount(payload.kisi_listesi_id)),
      ) || 0;
    payload.kullanici = access.session!.user.id;
    payload.guncelleme_tarihi = new Date().toISOString();

    if (!payload.kampanya_adi || !payload.konu) {
      return json(
        { error: { message: "Campaign name and subject are required" } },
        400,
      );
    }
    if (
      payload.durum &&
      payload.durum !== "draft" &&
      (!payload.hesap_id || !payload.sablon_id || !payload.kisi_listesi_id)
    ) {
      return json(
        {
          error: {
            message:
              "Sender account, approved template, and contact list are required",
          },
        },
        400,
      );
    }

    const keys = Object.keys(payload);
    const result = await dbQuery(
      `INSERT INTO public.whatsapp_campaigns (${keys.join(", ")})
       VALUES (${keys.map((_, index) => `$${index + 1}`).join(", ")})
       RETURNING id`,
      keys.map((key) => payload[key]),
    );

    return json({
      campaign: await selectedCampaign(String(result.rows[0]?.id)),
    });
  } catch (error: any) {
    return json(
      {
        error: {
          message: error.message || "WhatsApp campaign could not be saved",
        },
      },
      500,
    );
  }
};

export const PATCH: APIRoute = async ({ request }) => {
  const body = await readJsonBody(request);
  try {
    const access = await requireWhatsappAccess(request, body);
    if (access.response) return access.response;

    const id = String(body.id || "").trim();
    if (!id) return json({ error: { message: "Campaign id required" } }, 400);

    const action = String(body.action || "").trim();
    if (action) {
      const actionSql: Record<string, string> = {
        pause: "durum = 'paused'",
        cancel:
          "durum = 'cancelled', bitis_tarihi = COALESCE(bitis_tarihi, now())",
        complete:
          "durum = 'completed', bitis_tarihi = COALESCE(bitis_tarihi, now())",
        remove_schedule: "durum = 'draft', zamanlanmis_baslangic = null",
      };

      if (action === "schedule") {
        const scheduled = String(body.scheduled_start_at || "").trim();
        if (!scheduled)
          return json({ error: { message: "Schedule date required" } }, 400);
        const scheduledAt = Date.parse(scheduled);
        if (Number.isNaN(scheduledAt))
          return json({ error: { message: "Schedule date is invalid" } }, 400);
        if (scheduledAt <= Date.now())
          return json(
            { error: { message: "Schedule date must be in the future" } },
            400,
          );
        const sendError = await campaignSendError(id);
        if (sendError) return json({ error: { message: sendError } }, 400);
        await dbQuery(
          "UPDATE public.whatsapp_campaigns SET durum = 'scheduled', zamanlanmis_baslangic = $1, guncelleme_tarihi = now() WHERE id = $2::bigint",
          [scheduled, id],
        );
      } else if (action === "start") {
        const sendError = await campaignSendError(id);
        if (sendError) return json({ error: { message: sendError } }, 400);
        await dbQuery(
          `UPDATE public.whatsapp_campaigns
           SET durum = 'sending',
               baslangic_tarihi = COALESCE(baslangic_tarihi, now()),
               zamanlanmis_baslangic = null,
               guncelleme_tarihi = now()
           WHERE id = $1::bigint`,
          [id],
        );
      } else if (action === "resume") {
        const sendError = await campaignSendError(id);
        if (sendError) return json({ error: { message: sendError } }, 400);
        await dbQuery(
          `UPDATE public.whatsapp_campaigns
           SET durum = 'sending', guncelleme_tarihi = now()
           WHERE id = $1::bigint`,
          [id],
        );
      } else if (actionSql[action]) {
        await dbQuery(
          `UPDATE public.whatsapp_campaigns SET ${actionSql[action]}, guncelleme_tarihi = now() WHERE id = $1::bigint`,
          [id],
        );
      } else {
        return json({ error: { message: "Unsupported campaign action" } }, 400);
      }
    } else {
      const update = campaignPayload(body);
      const scheduleError = normalizeSchedule(update);
      if (scheduleError)
        return json({ error: { message: scheduleError } }, 400);
      if (Object.prototype.hasOwnProperty.call(update, "kisi_listesi_id")) {
        update.alici_sayisi =
          Number(
            update.alici_sayisi || (await contactCount(update.kisi_listesi_id)),
          ) || 0;
      }
      update.guncelleme_tarihi = new Date().toISOString();
      const set = sqlSetClause(update);
      if (!set.keys.length)
        return json({ error: { message: "No changes" } }, 400);
      await dbQuery(
        `UPDATE public.whatsapp_campaigns SET ${set.clause} WHERE id = $${set.values.length + 1}::bigint`,
        [...set.values, id],
      );
    }

    return json({ campaign: await selectedCampaign(id) });
  } catch (error: any) {
    return json(
      {
        error: {
          message: error.message || "WhatsApp campaign could not be updated",
        },
      },
      500,
    );
  }
};

export const DELETE: APIRoute = async ({ request, url }) => {
  const body = await readJsonBody(request);
  try {
    const access = await requireWhatsappAccess(request, body);
    if (access.response) return access.response;

    const id = String(body.id || url.searchParams.get("id") || "").trim();
    if (!id) return json({ error: { message: "Campaign id required" } }, 400);
    await dbQuery(
      "DELETE FROM public.whatsapp_campaigns WHERE id = $1::bigint",
      [id],
    );
    return json({ ok: true });
  } catch (error: any) {
    return json(
      {
        error: {
          message: error.message || "WhatsApp campaign could not be deleted",
        },
      },
      500,
    );
  }
};
