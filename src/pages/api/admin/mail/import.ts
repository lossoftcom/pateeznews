import type { APIRoute } from 'astro';
import { dbQuery } from '@/lib/server/supabaseDb';
import { json } from '@/lib/server/appDb';
import { isEmail, normalizeEmail, readJsonBody, requireMailAccess } from '@/lib/server/mail/api';

export const prerender = false;

type ImportContact = {
  email: string;
  first_name?: string;
  last_name?: string;
  phone?: string;
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
      const emailIndex = columns.findIndex(isEmail);
      const email = emailIndex >= 0 ? normalizeEmail(columns[emailIndex]) : '';
      const name = columns.find((value, index) => index !== emailIndex && value && !/^\+?\d/.test(value)) || '';
      const phone = columns.find((value) => /^\+?\d[\d\s()-]+$/.test(value)) || '';
      return { email, ...splitName(name), phone };
    })
    .filter((contact) => isEmail(contact.email));
}

function normalizeContacts(input: unknown): ImportContact[] {
  if (Array.isArray(input)) {
    return input
      .map((item: any) => ({
        email: normalizeEmail(item.email || item.eposta),
        first_name: String(item.first_name || item.ad || '').trim(),
        last_name: String(item.last_name || item.soyad || '').trim(),
        phone: String(item.phone || item.telefon || '').trim(),
      }))
      .filter((contact) => isEmail(contact.email));
  }
  return parseDelimited(String(input || ''));
}

async function ensureList(body: Record<string, any>, userId: string) {
  const listId = String(body.list_id || '').trim();
  if (listId) return listId;

  const listName = String(body.list_name || 'İçe Aktarılan Kişiler').trim();
  const source = String(body.source || 'csv').trim() || 'csv';
  const result = await dbQuery(
    `INSERT INTO public.mail_contact_lists (liste_adi, aciklama, kaynak, kullanici)
     VALUES ($1, $2, $3, $4)
     RETURNING id`,
    [listName, String(body.description || '').trim(), source, userId]
  );
  return result.rows[0].id;
}

export const POST: APIRoute = async ({ request }) => {
  const body = await readJsonBody(request);
  try {
    const access = await requireMailAccess(request, body);
    if (access.response) return access.response;

    const source = String(body.source || 'manual').trim();
    const listId = await ensureList(body, access.session!.user.id);
    let contacts: ImportContact[] = [];

    if (source === 'newsletter') {
      const subscribers = await dbQuery(
        `SELECT email
         FROM public.newsletter_subscribers
         WHERE status = 'active'
         ORDER BY created_at DESC
         LIMIT 5000`
      );
      contacts = subscribers.rows
        .map((row: any) => ({ email: normalizeEmail(row.email) }))
        .filter((contact: ImportContact) => isEmail(contact.email));
    } else {
      contacts = normalizeContacts(body.contacts || body.text || body.csv || '');
    }

    const seen = new Set<string>();
    const unique = contacts.filter((contact) => {
      if (seen.has(contact.email)) return false;
      seen.add(contact.email);
      return true;
    });

    let inserted = 0;
    let updated = 0;
    let attached = 0;

    for (const contact of unique) {
      const existing = await dbQuery('SELECT id FROM public.mail_contacts WHERE lower(eposta) = lower($1) LIMIT 1', [contact.email]);
      const contactResult = existing.rows[0]
        ? await dbQuery(
          `UPDATE public.mail_contacts
           SET ad = COALESCE(NULLIF($2, ''), ad),
               soyad = COALESCE(NULLIF($3, ''), soyad),
               telefon = COALESCE(NULLIF($4, ''), telefon)
           WHERE id = $1::bigint
           RETURNING id`,
          [existing.rows[0].id, contact.first_name || '', contact.last_name || '', contact.phone || '']
        )
        : await dbQuery(
          `INSERT INTO public.mail_contacts (eposta, ad, soyad, telefon, dogrulama_durumu)
           VALUES ($1, $2, $3, $4, 'valid')
           RETURNING id`,
          [contact.email, contact.first_name || '', contact.last_name || '', contact.phone || '']
        );

      if (existing.rows[0]) updated += 1;
      else inserted += 1;

      await dbQuery(
        `INSERT INTO public.mail_contact_list_memberships (list_id, contact_id)
         VALUES ($1, $2)
         ON CONFLICT DO NOTHING`,
        [listId, contactResult.rows[0].id]
      );
      attached += 1;
    }

    return json({ ok: true, listId, received: contacts.length, valid: unique.length, inserted, updated, attached });
  } catch (error: any) {
    return json({ error: { message: error.message || 'Contacts could not be imported' } }, 500);
  }
};
