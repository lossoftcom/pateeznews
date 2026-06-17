import type { APIRoute } from 'astro';
import { dbQuery } from '@/lib/server/supabaseDb';
import { json } from '@/lib/server/appDb';
import {
  numericLimit,
  numericOffset,
  readJsonBody,
  requireMailAccess,
} from '@/lib/server/mail/api';
import { syncMailInboxFromImap } from '@/lib/server/mail/imapSync';

export const prerender = false;

const INBOX_SELECT = `
  mi.id::text AS id,
  mi.hesap_id::text AS account_id,
  mi.message_id,
  mi.gonderen_eposta AS sender_email,
  mi.gonderen_adi AS sender_name,
  mi.alici_eposta AS recipient_email,
  mi.konu AS subject,
  mi.icerik_text AS content_text,
  mi.icerik_html AS content_html,
  COALESCE(NULLIF(mi.ek_dosyalar_json, ''), '[]')::jsonb AS attachments,
  COALESCE(NULLIF(mi.resimler_json, ''), '[]')::jsonb AS images,
  mi.okundu AS is_read,
  mi.yildizli AS is_starred,
  COALESCE(NULLIF(mi.etiketler_json, ''), '[]')::jsonb AS labels,
  mi.klasor AS folder,
  mi.mail_tarihi AS mail_date,
  mi.okunma_tarihi AS read_at,
  mi.olusturma_tarihi AS created_at,
  ma.hesap_adi AS account_name,
  ma.gonderen_eposta AS account_email
`;

export const GET: APIRoute = async ({ request, url }) => {
  try {
    const access = await requireMailAccess(request);
    if (access.response) return access.response;

    if (url.searchParams.get('unreadCount')) {
      const count = await dbQuery<{ count: string }>(
        `SELECT COUNT(*)::bigint AS count
         FROM public.mail_inbox
         WHERE okundu IS NOT TRUE AND klasor NOT IN ('trash', 'spam')`,
      );
      return json({ unreadCount: Number(count.rows[0]?.count || 0) });
    }

    const limit = numericLimit(url.searchParams.get('limit'), 25, 100);
    const offset = numericOffset(url.searchParams.get('offset'));
    const search = String(url.searchParams.get('search') || '').trim();
    const folder = String(url.searchParams.get('folder') || '').trim();
    const accountId = String(url.searchParams.get('accountId') || '').trim();
    const status = String(url.searchParams.get('status') || '').trim();
    const dateFrom = String(url.searchParams.get('dateFrom') || '').trim();
    const dateTo = String(url.searchParams.get('dateTo') || '').trim();
    let sync: Awaited<ReturnType<typeof syncMailInboxFromImap>> | null = null;
    if (url.searchParams.get('sync') === '1') {
      try {
        sync = await syncMailInboxFromImap({
          accountId: accountId || undefined,
          maxMessages: 30,
        });
      } catch (error: any) {
        sync = {
          attempted: 0,
          imported: 0,
          errors: [error.message || 'IMAP sync failed'],
        };
      }
    }

    const where: string[] = [];
    const values: any[] = [];
    const add = (clause: string, value?: any) => {
      if (value !== undefined) values.push(value);
      where.push(
        value === undefined ? clause : clause.replace('?', `$${values.length}`),
      );
    };

    if (folder && folder !== 'all') add('mi.klasor = ?', folder);
    if (accountId) add('mi.hesap_id = ?::bigint', accountId);
    if (dateFrom) add('mi.mail_tarihi >= ?::date', dateFrom);
    if (dateTo) add("mi.mail_tarihi < (?::date + interval '1 day')", dateTo);
    if (status === 'unread') add('mi.okundu IS NOT TRUE');
    if (status === 'starred') add('mi.yildizli IS TRUE');
    if (status === 'attachments')
      add(
        "jsonb_array_length(COALESCE(NULLIF(mi.ek_dosyalar_json, ''), '[]')::jsonb) > 0",
      );
    if (search)
      add(
        '(mi.konu ILIKE ? OR mi.gonderen_eposta ILIKE ? OR mi.gonderen_adi ILIKE ?)',
        `%${search}%`,
      );
    if (search) {
      values.push(`%${search}%`, `%${search}%`);
      where[where.length - 1] =
        `(mi.konu ILIKE $${values.length - 2} OR mi.gonderen_eposta ILIKE $${values.length - 1} OR mi.gonderen_adi ILIKE $${values.length})`;
    }

    const whereSql = where.length ? `WHERE ${where.join(' AND ')}` : '';

    const [items, total, stats, folderCounts] = await Promise.all([
      dbQuery(
        `SELECT ${INBOX_SELECT}
         FROM public.mail_inbox mi
         LEFT JOIN public.mail_accounts ma ON ma.id = mi.hesap_id
         ${whereSql}
         ORDER BY mi.mail_tarihi DESC, mi.olusturma_tarihi DESC
         LIMIT $${values.length + 1} OFFSET $${values.length + 2}`,
        [...values, limit, offset],
      ),
      dbQuery<{ count: string }>(
        `SELECT COUNT(*)::bigint AS count
         FROM public.mail_inbox mi
         ${whereSql}`,
        values,
      ),
      dbQuery(
        `SELECT
          COUNT(*)::bigint AS total,
          COUNT(*) FILTER (WHERE okundu IS NOT TRUE AND klasor NOT IN ('trash', 'spam'))::bigint AS unread,
          COUNT(*) FILTER (WHERE klasor = 'archive')::bigint AS archived,
          COUNT(*) FILTER (WHERE jsonb_array_length(COALESCE(NULLIF(ek_dosyalar_json, ''), '[]')::jsonb) > 0)::bigint AS with_attachments
         FROM public.mail_inbox`,
      ),
      dbQuery(
        `SELECT klasor AS folder, COUNT(*)::bigint AS count
         FROM public.mail_inbox
         GROUP BY klasor`,
      ),
    ]);

    return json({
      items: items.rows,
      total: Number(total.rows[0]?.count || 0),
      limit,
      offset,
      stats: {
        total: Number(stats.rows[0]?.total || 0),
        unread: Number(stats.rows[0]?.unread || 0),
        archived: Number(stats.rows[0]?.archived || 0),
        withAttachments: Number(stats.rows[0]?.with_attachments || 0),
      },
      folderCounts: Object.fromEntries(
        folderCounts.rows.map((row: any) => [
          row.folder || 'inbox',
          Number(row.count || 0),
        ]),
      ),
      sync,
    });
  } catch (error: any) {
    return json(
      { error: { message: error.message || 'Inbox could not be loaded' } },
      500,
    );
  }
};

export const PATCH: APIRoute = async ({ request }) => {
  const body = await readJsonBody(request);
  try {
    const access = await requireMailAccess(request, body);
    if (access.response) return access.response;

    const ids = Array.isArray(body.ids)
      ? body.ids.map(String).filter(Boolean)
      : [String(body.id || '').trim()].filter(Boolean);
    if (!ids.length)
      return json({ error: { message: 'Mail id required' } }, 400);

    const action = String(body.action || '').trim();
    const values: any[] = [ids];
    let setSql = '';

    switch (action) {
      case 'read':
        setSql = 'okundu = true, okunma_tarihi = now()';
        break;
      case 'unread':
        setSql = 'okundu = false, okunma_tarihi = null';
        break;
      case 'star':
        setSql = 'yildizli = true';
        break;
      case 'unstar':
        setSql = 'yildizli = false';
        break;
      case 'archive':
        setSql = "klasor = 'archive'";
        break;
      case 'spam':
        setSql = "klasor = 'spam'";
        break;
      case 'trash':
        setSql = "klasor = 'trash'";
        break;
      case 'inbox':
        setSql = "klasor = 'inbox'";
        break;
      case 'label':
        values.push(JSON.stringify(body.labels || []));
        setSql = `etiketler_json = $2`;
        break;
      default:
        return json({ error: { message: 'Unsupported inbox action' } }, 400);
    }

    await dbQuery(
      `UPDATE public.mail_inbox SET ${setSql} WHERE id = ANY($1::bigint[])`,
      values,
    );
    const count = await dbQuery<{ count: string }>(
      `SELECT COUNT(*)::bigint AS count
       FROM public.mail_inbox
       WHERE okundu IS NOT TRUE AND klasor NOT IN ('trash', 'spam')`,
    );

    return json({ ok: true, unreadCount: Number(count.rows[0]?.count || 0) });
  } catch (error: any) {
    return json(
      { error: { message: error.message || 'Inbox action failed' } },
      500,
    );
  }
};

export const DELETE: APIRoute = async ({ request, url }) => {
  const body = await readJsonBody(request);
  try {
    const access = await requireMailAccess(request, body);
    if (access.response) return access.response;

    const ids = Array.isArray(body.ids)
      ? body.ids.map(String).filter(Boolean)
      : [String(body.id || url.searchParams.get('id') || '').trim()].filter(
          Boolean,
        );
    if (!ids.length)
      return json({ error: { message: 'Mail id required' } }, 400);

    await dbQuery(
      'DELETE FROM public.mail_inbox WHERE id = ANY($1::bigint[])',
      [ids],
    );
    const count = await dbQuery<{ count: string }>(
      `SELECT COUNT(*)::bigint AS count
       FROM public.mail_inbox
       WHERE okundu IS NOT TRUE AND klasor NOT IN ('trash', 'spam')`,
    );

    return json({ ok: true, unreadCount: Number(count.rows[0]?.count || 0) });
  } catch (error: any) {
    return json(
      { error: { message: error.message || 'Mail could not be deleted' } },
      500,
    );
  }
};
