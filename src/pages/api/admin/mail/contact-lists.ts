import type { APIRoute } from 'astro';
import { dbQuery } from '@/lib/server/neonDb';
import { json } from '@/lib/server/appDb';
import { numericLimit, numericOffset, readJsonBody, requireMailAccess, sqlSetClause } from '@/lib/server/mail/api';

export const prerender = false;

const LIST_SELECT = `
  id::text AS id,
  liste_adi AS list_name,
  aciklama AS description,
  (
    SELECT COUNT(*)::integer
    FROM public.mail_contact_list_memberships m
    WHERE m.list_id = mail_contact_lists.id
  ) AS contact_count,
  kaynak AS source,
  otomatik_sync AS auto_sync,
  COALESCE(NULLIF(sync_filtresi_json, ''), '{}')::jsonb AS sync_filter,
  aktif_mi AS is_active,
  olusturma_tarihi AS created_at,
  guncelleme_tarihi AS updated_at,
  kullanici AS created_by
`;

async function refreshListCount(listId: string) {
  await dbQuery('SELECT id FROM public.mail_contact_lists WHERE id = $1::bigint LIMIT 1', [listId]);
}

export const GET: APIRoute = async ({ request, url }) => {
  try {
    const access = await requireMailAccess(request);
    if (access.response) return access.response;

    const listId = String(url.searchParams.get('listId') || '').trim();
    if (listId) {
      const contacts = await dbQuery(
        `SELECT c.*
         FROM public.mail_contacts c
         JOIN public.mail_contact_list_memberships m ON m.contact_id = c.id
         WHERE m.list_id = $1::bigint
         ORDER BY c.olusturma_tarihi DESC
         LIMIT 500`,
        [listId]
      );
      return json({ contacts: contacts.rows });
    }

    const limit = numericLimit(url.searchParams.get('limit'), 25, 100);
    const offset = numericOffset(url.searchParams.get('offset'));
    const search = String(url.searchParams.get('search') || '').trim();
    const values: any[] = [];
    const where: string[] = [];
    if (search) {
      values.push(`%${search}%`);
      where.push(`(liste_adi ILIKE $${values.length} OR aciklama ILIKE $${values.length})`);
    }
    const whereSql = where.length ? `WHERE ${where.join(' AND ')}` : '';

    const [items, total, stats] = await Promise.all([
      dbQuery(
        `SELECT ${LIST_SELECT}
         FROM public.mail_contact_lists
         ${whereSql}
         ORDER BY aktif_mi DESC, olusturma_tarihi DESC
         LIMIT $${values.length + 1} OFFSET $${values.length + 2}`,
        [...values, limit, offset]
      ),
      dbQuery<{ count: string }>(`SELECT COUNT(*)::bigint AS count FROM public.mail_contact_lists ${whereSql}`, values),
      dbQuery(
        `SELECT
          COUNT(*)::bigint AS lists,
          (
            SELECT COUNT(*)::bigint
            FROM public.mail_contact_list_memberships
          ) AS contacts,
          COUNT(*) FILTER (WHERE otomatik_sync IS TRUE)::bigint AS synced
         FROM public.mail_contact_lists`
      ),
    ]);

    return json({
      items: items.rows,
      total: Number(total.rows[0]?.count || 0),
      limit,
      offset,
      stats: {
        lists: Number(stats.rows[0]?.lists || 0),
        contacts: Number(stats.rows[0]?.contacts || 0),
        synced: Number(stats.rows[0]?.synced || 0),
      },
    });
  } catch (error: any) {
    return json({ error: { message: error.message || 'Contact lists could not be loaded' } }, 500);
  }
};

export const POST: APIRoute = async ({ request }) => {
  const body = await readJsonBody(request);
  try {
    const access = await requireMailAccess(request, body);
    if (access.response) return access.response;

    const payload: Record<string, any> = {};
    if (Object.prototype.hasOwnProperty.call(body, 'list_name')) payload.liste_adi = body.list_name;
    if (Object.prototype.hasOwnProperty.call(body, 'description')) payload.aciklama = body.description;
    if (Object.prototype.hasOwnProperty.call(body, 'source')) payload.kaynak = body.source;
    if (Object.prototype.hasOwnProperty.call(body, 'auto_sync')) payload.otomatik_sync = body.auto_sync;
    if (Object.prototype.hasOwnProperty.call(body, 'sync_filter')) payload.sync_filtresi_json = JSON.stringify(body.sync_filter || {});
    if (Object.prototype.hasOwnProperty.call(body, 'is_active')) payload.aktif_mi = body.is_active;
    payload.liste_adi = String(payload.liste_adi || '').trim();
    payload.kaynak = String(payload.kaynak || 'csv').trim() || 'csv';
    if (!payload.liste_adi) return json({ error: { message: 'List name is required' } }, 400);
    payload.kullanici = access.session!.user.id;
    payload.guncelleme_tarihi = new Date().toISOString();

    const keys = Object.keys(payload);
    const result = await dbQuery(
      `INSERT INTO public.mail_contact_lists (${keys.join(', ')})
       VALUES (${keys.map((_, index) => `$${index + 1}`).join(', ')})
       RETURNING ${LIST_SELECT}`,
      keys.map((key) => payload[key])
    );

    return json({ list: result.rows[0] });
  } catch (error: any) {
    return json({ error: { message: error.message || 'Contact list could not be saved' } }, 500);
  }
};

export const PATCH: APIRoute = async ({ request }) => {
  const body = await readJsonBody(request);
  try {
    const access = await requireMailAccess(request, body);
    if (access.response) return access.response;

    const id = String(body.id || '').trim();
    if (!id) return json({ error: { message: 'Contact list id required' } }, 400);

    const update: Record<string, any> = {};
    if (Object.prototype.hasOwnProperty.call(body, 'list_name')) update.liste_adi = body.list_name;
    if (Object.prototype.hasOwnProperty.call(body, 'description')) update.aciklama = body.description;
    if (Object.prototype.hasOwnProperty.call(body, 'source')) update.kaynak = body.source;
    if (Object.prototype.hasOwnProperty.call(body, 'auto_sync')) update.otomatik_sync = body.auto_sync;
    if (Object.prototype.hasOwnProperty.call(body, 'sync_filter')) update.sync_filtresi_json = JSON.stringify(body.sync_filter || {});
    if (Object.prototype.hasOwnProperty.call(body, 'is_active')) update.aktif_mi = body.is_active;
    update.guncelleme_tarihi = new Date().toISOString();
    const set = sqlSetClause(update);
    if (!set.keys.length) return json({ error: { message: 'No changes' } }, 400);

    const result = await dbQuery(
      `UPDATE public.mail_contact_lists
       SET ${set.clause}
       WHERE id = $${set.values.length + 1}::bigint
       RETURNING ${LIST_SELECT}`,
      [...set.values, id]
    );

    return json({ list: result.rows[0] });
  } catch (error: any) {
    return json({ error: { message: error.message || 'Contact list could not be updated' } }, 500);
  }
};

export const DELETE: APIRoute = async ({ request, url }) => {
  const body = await readJsonBody(request);
  try {
    const access = await requireMailAccess(request, body);
    if (access.response) return access.response;

    const id = String(body.id || url.searchParams.get('id') || '').trim();
    if (!id) return json({ error: { message: 'Contact list id required' } }, 400);
    await dbQuery('DELETE FROM public.mail_contact_lists WHERE id = $1::bigint', [id]);
    return json({ ok: true });
  } catch (error: any) {
    return json({ error: { message: error.message || 'Contact list could not be deleted' } }, 500);
  }
};

export async function updateContactListCount(listId: string) {
  await refreshListCount(listId);
}
