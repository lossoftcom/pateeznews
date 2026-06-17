import type { APIRoute } from "astro";
import { json } from "@/lib/server/appDb";
import { dbQuery } from "@/lib/server/supabaseDb";
import {
  normalizePhone,
  readJsonBody,
  requireWhatsappAccess,
} from "@/lib/server/whatsapp/api";
import {
  sendWhatsappTemplateWithAccount,
  sendWhatsappTextWithAccount,
} from "@/lib/server/whatsapp/providers";

export const prerender = false;

const CHAT_SELECT = `
  c.id::text AS id,
  c.ad AS name,
  c.telefon AS phone,
  c.avatar_url,
  c.online_mi AS is_online,
  c.okunmamis_sayisi AS unread_count,
  c.son_mesaj AS last_message,
  c.son_mesaj_tarihi AS last_message_at,
  c.aktif_mi AS is_active,
  c.olusturma_tarihi AS created_at,
  c.guncelleme_tarihi AS updated_at,
  (
    SELECT MAX(wm.olusturma_tarihi)
    FROM public.whatsapp_messages wm
    WHERE wm.chat_id = c.id AND wm.yon = 'incoming'
  ) AS last_inbound_at,
  COALESCE((
    SELECT MAX(wm.olusturma_tarihi) > now() - interval '24 hours'
    FROM public.whatsapp_messages wm
    WHERE wm.chat_id = c.id AND wm.yon = 'incoming'
  ), false) AS can_send_freeform,
  (
    SELECT MAX(wm.olusturma_tarihi) + interval '24 hours'
    FROM public.whatsapp_messages wm
    WHERE wm.chat_id = c.id AND wm.yon = 'incoming'
  ) AS customer_service_expires_at
`;

const MESSAGE_SELECT = `
  id::text AS id,
  chat_id::text AS chat_id,
  hesap_id::text AS account_id,
  servis_message_id AS service_message_id,
  yon AS direction,
  mesaj AS body,
  durum AS status,
  ek_adi AS attachment_name,
  ek_tipi AS attachment_type,
  hata_mesaji AS error_message,
  gonderim_tarihi AS sent_at,
  teslim_tarihi AS delivered_at,
  okunma_tarihi AS read_at,
  olusturma_tarihi AS created_at,
  kullanici AS created_by
`;

async function messagesForChat(chatId: string) {
  const result = await dbQuery(
    `SELECT ${MESSAGE_SELECT}
     FROM public.whatsapp_messages
     WHERE chat_id = $1::bigint
     ORDER BY olusturma_tarihi ASC
     LIMIT 500`,
    [chatId],
  );
  return result.rows;
}

async function selectedChat(chatId: string) {
  const result = await dbQuery(
    `SELECT ${CHAT_SELECT}
     FROM public.whatsapp_chats c
     WHERE c.id = $1::bigint
     LIMIT 1`,
    [chatId],
  );
  return result.rows[0] || null;
}

async function chatPayload(
  chatId: string,
  overrides: Record<string, any> = {},
) {
  const chat = await selectedChat(chatId);
  return {
    chat: chat ? { ...chat, ...overrides } : null,
    messages: await messagesForChat(chatId),
  };
}

async function findActiveAccount(accountId?: string) {
  const result = accountId
    ? await dbQuery(
        `SELECT *,
        servis_tipi AS service_type,
        telefon AS phone,
        api_anahtari AS api_key_encrypted,
        api_sifresi AS api_secret_encrypted,
        api_token AS api_token_encrypted
       FROM public.whatsapp_accounts
       WHERE id = $1::bigint AND aktif_mi IS TRUE
       LIMIT 1`,
        [accountId],
      )
    : await dbQuery(
        `SELECT *,
        servis_tipi AS service_type,
        telefon AS phone,
        api_anahtari AS api_key_encrypted,
        api_sifresi AS api_secret_encrypted,
        api_token AS api_token_encrypted
       FROM public.whatsapp_accounts
       WHERE aktif_mi IS TRUE
       ORDER BY olusturma_tarihi DESC
       LIMIT 1`,
      );
  return result.rows[0] || null;
}

async function ensureChat(input: {
  chatId?: string;
  phone?: string;
  name?: string;
}) {
  const chatId = String(input.chatId || "").trim();
  if (chatId) {
    const result = await dbQuery(
      `SELECT ${CHAT_SELECT} FROM public.whatsapp_chats c WHERE c.id = $1::bigint LIMIT 1`,
      [chatId],
    );
    if (result.rows[0]) return result.rows[0];
  }

  const phone = normalizePhone(input.phone);
  if (!phone) throw new Error("Recipient phone is required");
  const existing = await dbQuery(
    `SELECT ${CHAT_SELECT}
     FROM public.whatsapp_chats c
     WHERE regexp_replace(c.telefon, '[^0-9+]', '', 'g') = $1
     LIMIT 1`,
    [phone],
  );
  if (existing.rows[0]) return existing.rows[0];

  const created = await dbQuery(
    `INSERT INTO public.whatsapp_chats (ad, telefon, son_mesaj, son_mesaj_tarihi)
     VALUES ($1, $2, '', now())
     RETURNING id`,
    [String(input.name || phone).trim(), phone],
  );
  const selected = await dbQuery(
    `SELECT ${CHAT_SELECT} FROM public.whatsapp_chats c WHERE c.id = $1::bigint LIMIT 1`,
    [created.rows[0].id],
  );
  return selected.rows[0];
}

async function canSendFreeform(chatId: string) {
  const result = await dbQuery<{ allowed: boolean }>(
    `SELECT COALESCE(MAX(olusturma_tarihi) > now() - interval '24 hours', false) AS allowed
     FROM public.whatsapp_messages
     WHERE chat_id = $1::bigint AND yon = 'incoming'`,
    [chatId],
  );
  return Boolean(result.rows[0]?.allowed);
}

async function sendableTemplate(templateId: string) {
  const result = await dbQuery(
    `SELECT
       id::text AS id,
       sablon_adi AS template_name,
       icerik_text AS content_text,
       COALESCE(NULLIF(degiskenler_json, ''), '[]')::jsonb AS variables,
       hazir_mi AS is_ready,
       aktif_mi AS is_active
     FROM public.whatsapp_templates
     WHERE id = $1::bigint
     LIMIT 1`,
    [templateId],
  );
  const template = result.rows[0];
  if (!template) throw new Error("Approved WhatsApp template not found");
  if (!template.is_active || !template.is_ready) {
    throw new Error(
      "Only active and Meta-approved WhatsApp templates can be sent outside the 24-hour window",
    );
  }
  const variables = Array.isArray(template.variables) ? template.variables : [];
  if (
    variables.length > 0 ||
    /\{\{[^}]+\}\}/.test(String(template.content_text || ""))
  ) {
    throw new Error(
      "Template variables must be mapped before this template can be sent one-to-one",
    );
  }
  return template;
}

async function markMessageSent(messageId: string, providerMessageId: string) {
  await dbQuery(
    `UPDATE public.whatsapp_messages
     SET durum = 'sent', servis_message_id = $1, gonderim_tarihi = now(), hata_mesaji = null
     WHERE id = $2::bigint`,
    [providerMessageId, messageId],
  );
}

async function markMessageFailed(messageId: string, error: any) {
  await dbQuery(
    `UPDATE public.whatsapp_messages
     SET durum = 'failed', hata_mesaji = $1
     WHERE id = $2::bigint`,
    [error.message || "Send failed", messageId],
  );
}

async function markAccountResult(
  accountId: string,
  ok: boolean,
  message?: string,
) {
  if (ok) {
    await dbQuery(
      `UPDATE public.whatsapp_accounts
       SET bugun_gonderilen = bugun_gonderilen + 1,
           bu_ay_gonderilen = bu_ay_gonderilen + 1,
           baglanti_durumu = 'ok',
           son_hata_mesaji = null,
           guncelleme_tarihi = now()
       WHERE id = $1::bigint`,
      [accountId],
    );
    return;
  }

  await dbQuery(
    `UPDATE public.whatsapp_accounts
     SET baglanti_durumu = 'error', son_hata_mesaji = $1, guncelleme_tarihi = now()
     WHERE id = $2::bigint`,
    [message || "Send failed", accountId],
  );
}

async function updateChatPreview(chatId: string, text: string) {
  await dbQuery(
    `UPDATE public.whatsapp_chats
     SET son_mesaj = $1, son_mesaj_tarihi = now(), guncelleme_tarihi = now()
     WHERE id = $2::bigint`,
    [text, chatId],
  );
}

export const GET: APIRoute = async ({ request, url }) => {
  try {
    const access = await requireWhatsappAccess(request);
    if (access.response) return access.response;

    const chatId = String(url.searchParams.get("chatId") || "").trim();
    if (chatId) {
      const chat = await dbQuery(
        `SELECT ${CHAT_SELECT} FROM public.whatsapp_chats c WHERE c.id = $1::bigint LIMIT 1`,
        [chatId],
      );
      return json({
        chat: chat.rows[0] || null,
        messages: await messagesForChat(chatId),
      });
    }

    const search = String(url.searchParams.get("search") || "").trim();
    const values: any[] = [];
    const where: string[] = ["c.aktif_mi IS TRUE"];
    if (search) {
      values.push(`%${search}%`);
      where.push(
        `(c.ad ILIKE $${values.length} OR c.telefon ILIKE $${values.length} OR c.son_mesaj ILIKE $${values.length})`,
      );
    }
    const chats = await dbQuery(
      `SELECT ${CHAT_SELECT}
       FROM public.whatsapp_chats c
       WHERE ${where.join(" AND ")}
       ORDER BY c.son_mesaj_tarihi DESC
       LIMIT 100`,
      values,
    );

    const items = [];
    for (const chat of chats.rows) {
      items.push({ ...chat, messages: await messagesForChat(String(chat.id)) });
    }
    return json({ items });
  } catch (error: any) {
    return json(
      {
        error: {
          message: error.message || "WhatsApp chats could not be loaded",
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

    const action = String(body.action || "").trim();

    if (action === "ensure") {
      const chat = await ensureChat({
        chatId: String(body.chat_id || "").trim(),
        phone: body.phone,
        name: body.name,
      });
      return json(await chatPayload(String(chat.id)));
    }

    if (action === "send_template") {
      const templateId = String(body.template_id || "").trim();
      if (!templateId)
        return json(
          { error: { message: "Approved template id is required" } },
          400,
        );

      const account = await findActiveAccount(
        String(body.account_id || "").trim() || undefined,
      );
      if (!account)
        return json(
          { error: { message: "No active WhatsApp account found" } },
          400,
        );

      const chat = await ensureChat({
        chatId: String(body.chat_id || "").trim(),
        phone: body.phone,
        name: body.name,
      });
      const template = await sendableTemplate(templateId);
      const preview = String(
        template.content_text || template.template_name || "WhatsApp template",
      ).trim();

      const inserted = await dbQuery(
        `INSERT INTO public.whatsapp_messages (chat_id, hesap_id, yon, mesaj, durum, kullanici)
         VALUES ($1, $2, 'outgoing', $3, 'queued', $4)
         RETURNING ${MESSAGE_SELECT}`,
        [chat.id, account.id, preview, access.session!.user.id],
      );
      const message = inserted.rows[0];

      try {
        const result = await sendWhatsappTemplateWithAccount(account, {
          to: chat.phone,
          templateName: template.template_name,
          languageCode: String(body.language_code || "").trim() || undefined,
        });
        await markMessageSent(message.id, result.messageId);
        await markAccountResult(account.id, true);
      } catch (error: any) {
        await markMessageFailed(message.id, error);
        await markAccountResult(
          account.id,
          false,
          error.message || "Send failed",
        );
        throw error;
      }

      await updateChatPreview(chat.id, preview);
      return json(
        await chatPayload(String(chat.id), {
          last_message: preview,
          last_message_at: new Date().toISOString(),
        }),
      );
    }

    const text = String(body.text || body.message || "").trim();
    if (!text)
      return json({ error: { message: "Message text is required" } }, 400);

    const account = await findActiveAccount(
      String(body.account_id || "").trim() || undefined,
    );
    if (!account)
      return json(
        { error: { message: "No active WhatsApp account found" } },
        400,
      );

    const chat = await ensureChat({
      chatId: String(body.chat_id || "").trim(),
      phone: body.phone,
      name: body.name,
    });

    if (!(await canSendFreeform(String(chat.id)))) {
      return json(
        {
          error: {
            message:
              "Serbest WhatsApp mesaji yalnizca kullanicinin son mesajindan sonraki 24 saatlik musteri hizmeti penceresinde gonderilebilir. Ilk temas icin onayli bir sablon gonderin.",
          },
        },
        409,
      );
    }

    const inserted = await dbQuery(
      `INSERT INTO public.whatsapp_messages (chat_id, hesap_id, yon, mesaj, durum, kullanici)
       VALUES ($1, $2, 'outgoing', $3, 'queued', $4)
       RETURNING ${MESSAGE_SELECT}`,
      [chat.id, account.id, text, access.session!.user.id],
    );
    const message = inserted.rows[0];

    try {
      const result = await sendWhatsappTextWithAccount(account, {
        to: chat.phone,
        text,
      });
      await markMessageSent(message.id, result.messageId);
      await markAccountResult(account.id, true);
    } catch (error: any) {
      await markMessageFailed(message.id, error);
      await markAccountResult(
        account.id,
        false,
        error.message || "Send failed",
      );
      throw error;
    }

    await updateChatPreview(chat.id, text);

    return json(
      await chatPayload(String(chat.id), {
        last_message: text,
        last_message_at: new Date().toISOString(),
      }),
    );
  } catch (error: any) {
    return json(
      {
        error: {
          message: error.message || "WhatsApp message could not be sent",
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

    const chatId = String(body.chat_id || "").trim();
    if (!chatId) return json({ error: { message: "Chat id required" } }, 400);

    if (body.action === "mark_read") {
      await dbQuery(
        `UPDATE public.whatsapp_chats SET okunmamis_sayisi = 0, guncelleme_tarihi = now() WHERE id = $1::bigint`,
        [chatId],
      );
      await dbQuery(
        `UPDATE public.whatsapp_messages SET okunma_tarihi = COALESCE(okunma_tarihi, now()), durum = CASE WHEN yon = 'incoming' THEN 'read' ELSE durum END WHERE chat_id = $1::bigint AND yon = 'incoming'`,
        [chatId],
      );
      return json({ ok: true, messages: await messagesForChat(chatId) });
    }

    return json({ error: { message: "Unsupported chat action" } }, 400);
  } catch (error: any) {
    return json(
      {
        error: {
          message: error.message || "WhatsApp chat could not be updated",
        },
      },
      500,
    );
  }
};
