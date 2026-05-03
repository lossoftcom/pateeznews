import type { APIRoute } from 'astro';
import { dbQuery } from '@/lib/server/neonDb';
import { json } from '@/lib/server/appDb';
import { numericLimit, numericOffset, readJsonBody, requireMailAccess, sqlSetClause } from '@/lib/server/mail/api';

export const prerender = false;

const TEMPLATE_SELECT = `
  id::text AS id,
  sablon_adi AS template_name,
  kategori AS category,
  icerik_html AS content_html,
  icerik_mjml AS content_mjml,
  COALESCE(NULLIF(tasarim_json, ''), '{}')::jsonb AS design_json,
  COALESCE(NULLIF(degiskenler_json, ''), '[]')::jsonb AS variables,
  onizleme_gorseli AS preview_image,
  hazir_mi AS is_ready,
  aktif_mi AS is_active,
  olusturma_tarihi AS created_at,
  olusturma_tarihi AS updated_at,
  kullanici AS created_by
`;

const FIELD_MAP: Record<string, string> = {
  template_name: 'sablon_adi',
  category: 'kategori',
  content_html: 'icerik_html',
  content_mjml: 'icerik_mjml',
  design_json: 'tasarim_json',
  variables: 'degiskenler_json',
  preview_image: 'onizleme_gorseli',
  is_ready: 'hazir_mi',
  is_active: 'aktif_mi',
};

function normalizePayload(body: Record<string, any>, userId?: string) {
  const payload: Record<string, any> = {};
  for (const [clientKey, dbKey] of Object.entries(FIELD_MAP)) {
    if (Object.prototype.hasOwnProperty.call(body, clientKey)) payload[dbKey] = body[clientKey];
  }
  if (Object.prototype.hasOwnProperty.call(payload, 'degiskenler_json')) payload.degiskenler_json = JSON.stringify(payload.degiskenler_json || []);
  if (Object.prototype.hasOwnProperty.call(payload, 'tasarim_json')) payload.tasarim_json = JSON.stringify(payload.tasarim_json || {});
  if (userId) payload.kullanici = userId;
  return payload;
}

export const GET: APIRoute = async ({ request, url }) => {
  try {
    const access = await requireMailAccess(request);
    if (access.response) return access.response;

    const limit = numericLimit(url.searchParams.get('limit'), 50, 200);
    const offset = numericOffset(url.searchParams.get('offset'));
    const search = String(url.searchParams.get('search') || '').trim();
    const category = String(url.searchParams.get('category') || '').trim();

    const values: any[] = [];
    const where: string[] = [];
    if (category && category !== 'all') {
      values.push(category);
      where.push(`kategori = $${values.length}`);
    }
    if (search) {
      values.push(`%${search}%`);
      where.push(`sablon_adi ILIKE $${values.length}`);
    }
    const whereSql = where.length ? `WHERE ${where.join(' AND ')}` : '';

    const [items, total, stats] = await Promise.all([
      dbQuery(
        `SELECT ${TEMPLATE_SELECT}
         FROM public.mail_templates
         ${whereSql}
         ORDER BY aktif_mi DESC, kategori ASC, sablon_adi ASC
         LIMIT $${values.length + 1} OFFSET $${values.length + 2}`,
        [...values, limit, offset]
      ),
      dbQuery<{ count: string }>(`SELECT COUNT(*)::bigint AS count FROM public.mail_templates ${whereSql}`, values),
      dbQuery(
        `SELECT
          COUNT(*)::bigint AS total,
          COUNT(*) FILTER (WHERE hazir_mi IS TRUE)::bigint AS ready,
          COUNT(*) FILTER (WHERE aktif_mi IS TRUE)::bigint AS active
         FROM public.mail_templates`
      ),
    ]);

    return json({
      items: items.rows,
      total: Number(total.rows[0]?.count || 0),
      limit,
      offset,
      stats: {
        total: Number(stats.rows[0]?.total || 0),
        ready: Number(stats.rows[0]?.ready || 0),
        active: Number(stats.rows[0]?.active || 0),
      },
      categories: ['kampanya', 'bilgi', 'davet', 'siparis', 'teklif'],
    });
  } catch (error: any) {
    return json({ error: { message: error.message || 'Templates could not be loaded' } }, 500);
  }
};

export const POST: APIRoute = async ({ request }) => {
  const body = await readJsonBody(request);
  try {
    const access = await requireMailAccess(request, body);
    if (access.response) return access.response;

    const payload = normalizePayload(body, access.session!.user.id);
    payload.sablon_adi = String(payload.sablon_adi || '').trim();
    payload.kategori = String(payload.kategori || 'kampanya').trim() || 'kampanya';
    payload.icerik_html = String(payload.icerik_html || '').trim();
    if (!payload.sablon_adi || !payload.icerik_html) return json({ error: { message: 'Template name and content are required' } }, 400);

    const keys = Object.keys(payload);
    const result = await dbQuery(
      `INSERT INTO public.mail_templates (${keys.join(', ')})
       VALUES (${keys.map((_, index) => `$${index + 1}`).join(', ')})
       RETURNING ${TEMPLATE_SELECT}`,
      keys.map((key) => payload[key])
    );

    return json({ template: result.rows[0] });
  } catch (error: any) {
    return json({ error: { message: error.message || 'Template could not be saved' } }, 500);
  }
};

export const PATCH: APIRoute = async ({ request }) => {
  const body = await readJsonBody(request);
  try {
    const access = await requireMailAccess(request, body);
    if (access.response) return access.response;

    const id = String(body.id || '').trim();
    if (!id) return json({ error: { message: 'Template id required' } }, 400);

    const update = normalizePayload(body);
    const set = sqlSetClause(update);
    if (!set.keys.length) return json({ error: { message: 'No changes' } }, 400);

    const result = await dbQuery(
      `UPDATE public.mail_templates
       SET ${set.clause}
       WHERE id = $${set.values.length + 1}::bigint
       RETURNING ${TEMPLATE_SELECT}`,
      [...set.values, id]
    );

    return json({ template: result.rows[0] });
  } catch (error: any) {
    return json({ error: { message: error.message || 'Template could not be updated' } }, 500);
  }
};

export const DELETE: APIRoute = async ({ request, url }) => {
  const body = await readJsonBody(request);
  try {
    const access = await requireMailAccess(request, body);
    if (access.response) return access.response;

    const id = String(body.id || url.searchParams.get('id') || '').trim();
    if (!id) return json({ error: { message: 'Template id required' } }, 400);
    await dbQuery('DELETE FROM public.mail_templates WHERE id = $1::bigint', [id]);
    return json({ ok: true });
  } catch (error: any) {
    return json({ error: { message: error.message || 'Template could not be deleted' } }, 500);
  }
};
