import type { APIRoute } from 'astro';
import { json } from '@/lib/server/appDb';
import { dbQuery } from '@/lib/server/supabaseDb';
import { isPhone, normalizePhone, readJsonBody, requireWhatsappAccess } from '@/lib/server/whatsapp/api';

export const prerender = false;

type ImportContact = {
  phone: string;
  first_name?: string;
  last_name?: string;
  email?: string;
};

function splitName(name: string) {
  const parts = String(name || '').trim().split(/\s+/).filter(Boolean);
  if (parts.length <= 1) return { first_name: parts[0] || '', last_name: '' };
  return { first_name: parts.slice(0, -1).join(' '), last_name: parts.at(-1) || '' };
}

function parseDelimited(text: string): ImportContact[] {
  return String(text || '')
    .split(/\r?\n/g)
    .map((line) => line.trim())
    .filter(Boolean)
    .map((line) => {
      const columns = line.split(/[;,|\t]/g).map((value) => value.trim());
      const phoneIndex = columns.findIndex(isPhone);
      const phone = phoneIndex >= 0 ? normalizePhone(columns[phoneIndex]) : '';
      const email = columns.find((value) => /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(value)) || '';
      const name = columns.find((value, index) => index !== phoneIndex && value && value !== email && !/^\+?\d/.test(value)) || '';
      return { phone, email, ...splitName(name) };
    })
    .filter((contact) => isPhone(contact.phone));
}

function normalizeContacts(input: unknown): ImportContact[] {
  if (Array.isArray(input)) {
    return input
      .map((item: any) => ({
        phone: normalizePhone(item.phone || item.telefon),
        first_name: String(item.first_name || item.ad || '').trim(),
        last_name: String(item.last_name || item.soyad || '').trim(),
        email: String(item.email || item.eposta || '').trim().toLowerCase(),
      }))
      .filter((contact) => isPhone(contact.phone));
  }
  return parseDelimited(String(input || ''));
}

async function ensureList(body: Record<string, any>, userId: string) {
  const listId = String(body.list_id || '').trim();
  if (listId) return listId;

  const listName = String(body.list_name || 'İçe Aktarılan WhatsApp Kişileri').trim();
  const source = String(body.source || 'csv').trim() || 'csv';
  const result = await dbQuery(
    `INSERT INTO public.whatsapp_contact_lists (liste_adi, aciklama, kaynak, kullanici)
     VALUES ($1, $2, $3, $4)
     RETURNING id`,
    [listName, String(body.description || '').trim(), source, userId]
  );
  return result.rows[0].id;
}

export const POST: APIRoute = async ({ request }) => {
  const body = await readJsonBody(request);
  try {
    const access = await requireWhatsappAccess(request, body);
    if (access.response) return access.response;

    const listId = await ensureList(body, access.session!.user.id);
    const contacts = normalizeContacts(body.contacts || body.text || body.csv || '');
    const seen = new Set<string>();
    const unique = contacts.filter((contact) => {
      if (seen.has(contact.phone)) return false;
      seen.add(contact.phone);
      return true;
    });

    let inserted = 0;
    let updated = 0;
    let attached = 0;

    for (const contact of unique) {
      const existing = await dbQuery(
        `SELECT id FROM public.whatsapp_contacts
         WHERE regexp_replace(telefon, '[^0-9+]', '', 'g') = $1
         LIMIT 1`,
        [contact.phone]
      );
      const contactResult = existing.rows[0]
        ? await dbQuery(
          `UPDATE public.whatsapp_contacts
           SET ad = COALESCE(NULLIF($2, ''), ad),
               soyad = COALESCE(NULLIF($3, ''), soyad),
               eposta = COALESCE(NULLIF($4, ''), eposta)
           WHERE id = $1::bigint
           RETURNING id`,
          [existing.rows[0].id, contact.first_name || '', contact.last_name || '', contact.email || '']
        )
        : await dbQuery(
          `INSERT INTO public.whatsapp_contacts (telefon, ad, soyad, eposta, dogrulama_durumu)
           VALUES ($1, $2, $3, $4, 'valid')
           RETURNING id`,
          [contact.phone, contact.first_name || '', contact.last_name || '', contact.email || '']
        );

      if (existing.rows[0]) updated += 1;
      else inserted += 1;

      await dbQuery(
        `INSERT INTO public.whatsapp_contact_list_memberships (list_id, contact_id)
         VALUES ($1, $2)
         ON CONFLICT DO NOTHING`,
        [listId, contactResult.rows[0].id]
      );
      attached += 1;
    }

    return json({ ok: true, listId, received: contacts.length, valid: unique.length, inserted, updated, attached });
  } catch (error: any) {
    return json({ error: { message: error.message || 'WhatsApp contacts could not be imported' } }, 500);
  }
};
