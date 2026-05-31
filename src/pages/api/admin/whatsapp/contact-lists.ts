import type { APIRoute } from 'astro';
import { json } from '@/lib/server/appDb';
import { dbQuery } from '@/lib/server/supabaseDb';
import { numericLimit, numericOffset, readJsonBody, requireWhatsappAccess, sqlSetClause } from '@/lib/server/whatsapp/api';

export const prerender = false;

const LIST_SELECT = `
  id::text AS id,
  liste_adi AS list_name,
  aciklama AS description,
  (
    SELECT COUNT(*)::integer
    FROM public.whatsapp_contact_list_memberships m
    WHERE m.list_id = whatsapp_contact_lists.id
  ) AS contact_count,
  kaynak AS source,
  otomatik_sync AS auto_sync,
  COALESCE(NULLIF(sync_filtresi_json, ''), '{}')::jsonb AS sync_filter,
  aktif_mi AS is_active,
  olusturma_tarihi AS created_at,
  guncelleme_tarihi AS updated_at,
  kullanici AS created_by
`;

const FIELD_MAP: Record<string, string> = {
  list_name: 'liste_adi',
  description: 'aciklama',
  source: 'kaynak',
  auto_sync: 'otomatik_sync',
  sync_filter: 'sync_filtresi_json',
  is_active: 'aktif_mi',
};

function normalizePayload(body: Record<string, any>, userId?: string) {
  const payload: Record<string, any> = {};
  for (const [clientKey, dbKey] of Object.entries(FIELD_MAP)) {
    if (Object.prototype.hasOwnProperty.call(body, clientKey)) payload[dbKey] = body[clientKey];
  }
  if (Object.prototype.hasOwnProperty.call(payload, 'sync_filtresi_json')) {
    payload.sync_filtresi_json = JSON.stringify(payload.sync_filtresi_json || {});
  }
  payload.guncelleme_tarihi = new Date().toISOString();
  if (userId) payload.kullanici = userId;
  return payload;
}

export const GET: APIRoute = async ({ request, url }) => {
  try {
    const access = await requireWhatsappAccess(request);
    if (access.response) return access.response;

    const listId = String(url.searchParams.get('listId') || '').trim();
    if (listId) {
      const contacts = await dbQuery(
        `SELECT c.*
         FROM public.whatsapp_contacts c
         JOIN public.whatsapp_contact_list_memberships m ON m.contact_id = c.id
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
         FROM public.whatsapp_contact_lists
         ${whereSql}
         ORDER BY aktif_mi DESC, olusturma_tarihi DESC
         LIMIT $${values.length + 1} OFFSET $${values.length + 2}`,
        [...values, limit, offset]
      ),
      dbQuery<{ count: string }>(`SELECT COUNT(*)::bigint AS count FROM public.whatsapp_contact_lists ${whereSql}`, values),
      dbQuery(
        `SELECT
          COUNT(*)::bigint AS total,
          COUNT(*) FILTER (WHERE aktif_mi IS TRUE)::bigint AS active,
          COUNT(*) FILTER (WHERE otomatik_sync IS TRUE)::bigint AS synced
         FROM public.whatsapp_contact_lists`
      ),
    ]);

    return json({
      items: items.rows,
      total: Number(total.rows[0]?.count || 0),
      limit,
      offset,
      stats: {
        total: Number(stats.rows[0]?.total || 0),
        active: Number(stats.rows[0]?.active || 0),
        synced: Number(stats.rows[0]?.synced || 0),
      },
    });
  } catch (error: any) {
    return json({ error: { message: error.message || 'WhatsApp contact lists could not be loaded' } }, 500);
  }
};

export const POST: APIRoute = async ({ request }) => {
  const body = await readJsonBody(request);
  try {
    const access = await requireWhatsappAccess(request, body);
    if (access.response) return access.response;

    const payload = normalizePayload(body, access.session!.user.id);
    payload.liste_adi = String(payload.liste_adi || '').trim();
    payload.kaynak = String(payload.kaynak || 'csv').trim() || 'csv';
    if (!payload.liste_adi) return json({ error: { message: 'List name is required' } }, 400);

    const keys = Object.keys(payload);
    const result = await dbQuery(
      `INSERT INTO public.whatsapp_contact_lists (${keys.join(', ')})
       VALUES (${keys.map((_, index) => `$${index + 1}`).join(', ')})
       RETURNING ${LIST_SELECT}`,
      keys.map((key) => payload[key])
    );

    return json({ list: result.rows[0] });
  } catch (error: any) {
    return json({ error: { message: error.message || 'WhatsApp contact list could not be saved' } }, 500);
  }
};

export const PATCH: APIRoute = async ({ request }) => {
  const body = await readJsonBody(request);
  try {
    const access = await requireWhatsappAccess(request, body);
    if (access.response) return access.response;

    const id = String(body.id || '').trim();
    if (!id) return json({ error: { message: 'List id required' } }, 400);

    const update = normalizePayload(body);
    const set = sqlSetClause(update);
    if (!set.keys.length) return json({ error: { message: 'No changes' } }, 400);

    const result = await dbQuery(
      `UPDATE public.whatsapp_contact_lists
       SET ${set.clause}
       WHERE id = $${set.values.length + 1}::bigint
       RETURNING ${LIST_SELECT}`,
      [...set.values, id]
    );

    return json({ list: result.rows[0] });
  } catch (error: any) {
    return json({ error: { message: error.message || 'WhatsApp contact list could not be updated' } }, 500);
  }
};

export const DELETE: APIRoute = async ({ request, url }) => {
  const body = await readJsonBody(request);
  try {
    const access = await requireWhatsappAccess(request, body);
    if (access.response) return access.response;

    const id = String(body.id || url.searchParams.get('id') || '').trim();
    if (!id) return json({ error: { message: 'List id required' } }, 400);
    await dbQuery('DELETE FROM public.whatsapp_contact_lists WHERE id = $1::bigint', [id]);
    return json({ ok: true });
  } catch (error: any) {
    return json({ error: { message: error.message || 'WhatsApp contact list could not be deleted' } }, 500);
  }
};
