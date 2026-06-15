import type { APIRoute } from 'astro';
import { dbQuery } from '@/lib/server/supabaseDb';
import { json } from '@/lib/server/appDb';
import {
  isEmail,
  normalizeEmail,
  numericLimit,
  numericOffset,
  readJsonBody,
  requireMailAccess,
} from '@/lib/server/mail/api';

export const prerender = false;

const CONTACT_SELECT = `
  c.id::text AS id,
  c.eposta AS email,
  c.ad AS first_name,
  c.soyad AS last_name,
  c.telefon AS phone,
  c.aktif_mi AS is_active,
  c.dogrulama_durumu AS verification_status,
  c.bounce_durumu AS bounce_status,
  c.unsubscribe_tarihi AS unsubscribed_at,
  c.olusturma_tarihi AS created_at
`;

const CONTACT_RETURNING = `
  id::text AS id,
  eposta AS email,
  ad AS first_name,
  soyad AS last_name,
  telefon AS phone,
  aktif_mi AS is_active,
  dogrulama_durumu AS verification_status,
  bounce_durumu AS bounce_status,
  unsubscribe_tarihi AS unsubscribed_at,
  olusturma_tarihi AS created_at
`;

async function listExists(listId: string) {
  const result = await dbQuery(
    'SELECT id FROM public.mail_contact_lists WHERE id = $1::bigint LIMIT 1',
    [listId]
  );
  return Boolean(result.rows[0]);
}

export const GET: APIRoute = async ({ request, url }) => {
  try {
    const access = await requireMailAccess(request);
    if (access.response) return access.response;

    const listId = String(url.searchParams.get('list_id') || '').trim();
    if (!listId) return json({ error: { message: 'Contact list id required' } }, 400);

    const limit = numericLimit(url.searchParams.get('limit'), 100, 500);
    const offset = numericOffset(url.searchParams.get('offset'));
    const search = String(url.searchParams.get('search') || '').trim();
    const values: any[] = [listId];
    let searchSql = '';
    if (search) {
      values.push(`%${search}%`);
      searchSql = `AND (
        c.eposta ILIKE $${values.length}
        OR c.ad ILIKE $${values.length}
        OR c.soyad ILIKE $${values.length}
        OR c.telefon ILIKE $${values.length}
      )`;
    }

    const [items, total] = await Promise.all([
      dbQuery(
        `SELECT ${CONTACT_SELECT}
         FROM public.mail_contacts c
         JOIN public.mail_contact_list_memberships m ON m.contact_id = c.id
         WHERE m.list_id = $1::bigint
         ${searchSql}
         ORDER BY c.olusturma_tarihi DESC, c.id DESC
         LIMIT $${values.length + 1} OFFSET $${values.length + 2}`,
        [...values, limit, offset]
      ),
      dbQuery<{ count: string }>(
        `SELECT COUNT(*)::bigint AS count
         FROM public.mail_contacts c
         JOIN public.mail_contact_list_memberships m ON m.contact_id = c.id
         WHERE m.list_id = $1::bigint
         ${searchSql}`,
        values
      ),
    ]);

    return json({
      items: items.rows,
      total: Number(total.rows[0]?.count || 0),
      limit,
      offset,
    });
  } catch (error: any) {
    return json({ error: { message: error.message || 'Contacts could not be loaded' } }, 500);
  }
};

export const POST: APIRoute = async ({ request }) => {
  const body = await readJsonBody(request);
  try {
    const access = await requireMailAccess(request, body);
    if (access.response) return access.response;

    const listId = String(body.list_id || '').trim();
    const email = normalizeEmail(body.email);
    if (!listId || !(await listExists(listId))) {
      return json({ error: { message: 'Contact list not found' } }, 404);
    }
    if (!isEmail(email)) return json({ error: { message: 'A valid email is required' } }, 400);

    const existing = await dbQuery(
      'SELECT id FROM public.mail_contacts WHERE lower(eposta) = lower($1) LIMIT 1',
      [email]
    );
    const contact = existing.rows[0]
      ? await dbQuery(
        `UPDATE public.mail_contacts
         SET ad = $2, soyad = $3, telefon = $4, aktif_mi = $5
         WHERE id = $1::bigint
         RETURNING ${CONTACT_RETURNING}`,
        [
          existing.rows[0].id,
          String(body.first_name || '').trim(),
          String(body.last_name || '').trim(),
          String(body.phone || '').trim(),
          body.is_active !== false,
        ]
      )
      : await dbQuery(
        `INSERT INTO public.mail_contacts (
          eposta, ad, soyad, telefon, aktif_mi, dogrulama_durumu
        )
        VALUES ($1, $2, $3, $4, $5, 'valid')
        RETURNING ${CONTACT_RETURNING}`,
        [
          email,
          String(body.first_name || '').trim(),
          String(body.last_name || '').trim(),
          String(body.phone || '').trim(),
          body.is_active !== false,
        ]
      );

    await dbQuery(
      `INSERT INTO public.mail_contact_list_memberships (list_id, contact_id)
       VALUES ($1::bigint, $2::bigint)
       ON CONFLICT DO NOTHING`,
      [listId, contact.rows[0].id]
    );

    return json({ contact: contact.rows[0] });
  } catch (error: any) {
    return json({ error: { message: error.message || 'Contact could not be saved' } }, 500);
  }
};

export const PATCH: APIRoute = async ({ request }) => {
  const body = await readJsonBody(request);
  try {
    const access = await requireMailAccess(request, body);
    if (access.response) return access.response;

    const id = String(body.id || '').trim();
    const email = normalizeEmail(body.email);
    if (!id) return json({ error: { message: 'Contact id required' } }, 400);
    if (!isEmail(email)) return json({ error: { message: 'A valid email is required' } }, 400);

    const duplicate = await dbQuery(
      `SELECT id FROM public.mail_contacts
       WHERE lower(eposta) = lower($1) AND id <> $2::bigint
       LIMIT 1`,
      [email, id]
    );
    if (duplicate.rows[0]) {
      return json({ error: { message: 'A contact with this email already exists' } }, 409);
    }

    const result = await dbQuery(
      `UPDATE public.mail_contacts
       SET eposta = $1, ad = $2, soyad = $3, telefon = $4, aktif_mi = $5
       WHERE id = $6::bigint
       RETURNING ${CONTACT_RETURNING}`,
      [
        email,
        String(body.first_name || '').trim(),
        String(body.last_name || '').trim(),
        String(body.phone || '').trim(),
        body.is_active !== false,
        id,
      ]
    );
    if (!result.rows[0]) return json({ error: { message: 'Contact not found' } }, 404);
    return json({ contact: result.rows[0] });
  } catch (error: any) {
    return json({ error: { message: error.message || 'Contact could not be updated' } }, 500);
  }
};

export const DELETE: APIRoute = async ({ request, url }) => {
  const body = await readJsonBody(request);
  try {
    const access = await requireMailAccess(request, body);
    if (access.response) return access.response;

    const id = String(body.id || url.searchParams.get('id') || '').trim();
    const listId = String(body.list_id || url.searchParams.get('list_id') || '').trim();
    if (!id || !listId) {
      return json({ error: { message: 'Contact and list ids are required' } }, 400);
    }

    await dbQuery(
      `DELETE FROM public.mail_contact_list_memberships
       WHERE contact_id = $1::bigint AND list_id = $2::bigint`,
      [id, listId]
    );
    await dbQuery(
      `DELETE FROM public.mail_contacts c
       WHERE c.id = $1::bigint
         AND NOT EXISTS (
           SELECT 1 FROM public.mail_contact_list_memberships m
           WHERE m.contact_id = c.id
         )`,
      [id]
    );
    return json({ ok: true });
  } catch (error: any) {
    return json({ error: { message: error.message || 'Contact could not be deleted' } }, 500);
  }
};
