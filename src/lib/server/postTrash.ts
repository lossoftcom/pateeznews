import path from 'path';
import { dbQuery } from './supabaseDb';
import { deleteLocalUploadFiles } from './localUploadStorage';
import type { StorageType } from './supabaseStorage';

type TrashScope = 'all' | 'draft';

interface TrashCleanupSettings {
  enabled: boolean;
  days: number;
  scope: TrashScope;
  deleteMedia: boolean;
}

interface TrashPostRow {
  id: string | number;
  thumbnail_url: string | null;
  media_url: string | null;
  content: string | null;
  card_data: unknown;
  items: unknown;
  faq_data: unknown;
}

interface LocalMediaRef {
  type: StorageType;
  relativeId: string;
  objectPath: string;
}

const CLEANUP_LIMIT = 100;
const MEDIA_TYPES = new Set<StorageType>(['image', 'video', 'audio', 'file']);

function clampDays(value: unknown) {
  const parsed = Number(value);
  if (!Number.isFinite(parsed)) return 30;
  return Math.min(Math.max(Math.floor(parsed), 1), 365);
}

function normalizeScope(value: unknown): TrashScope {
  return value === 'draft' ? 'draft' : 'all';
}

function normalizeLocalPath(value: string) {
  try {
    value = decodeURIComponent(value);
  } catch {
    // Keep the original value when the URL contains partial escaping.
  }
  return value.replace(/\\/g, '/').replace(/^\/+/, '');
}

function localMediaRefFromString(value: string): LocalMediaRef | null {
  const trimmed = String(value || '').trim();
  if (!trimmed) return null;

  let pathname = trimmed;
  try {
    pathname = new URL(trimmed).pathname;
  } catch {
    // Plain paths from the editor are expected here.
  }

  const normalized = normalizeLocalPath(pathname)
    .replace(/^local-upload\//, '')
    .replace(/^api\/storage\/file\//, '');
  const [type, ...rest] = normalized.split('/').filter(Boolean);
  if (!type || !rest.length || !MEDIA_TYPES.has(type as StorageType)) {
    return null;
  }

  const relativeId = path.posix.normalize(rest.join('/'));
  if (!relativeId || relativeId === '.' || relativeId.startsWith('../')) {
    return null;
  }
  return {
    type: type as StorageType,
    relativeId,
    objectPath: `${type}/${relativeId}`,
  };
}

function collectStrings(value: unknown, output: string[]) {
  if (value == null) return;
  if (typeof value === 'string') {
    output.push(value);
    return;
  }
  if (Array.isArray(value)) {
    for (const item of value) collectStrings(item, output);
    return;
  }
  if (typeof value === 'object') {
    for (const item of Object.values(value as Record<string, unknown>)) {
      collectStrings(item, output);
    }
  }
}

function mediaRefsForPost(row: TrashPostRow) {
  const values: string[] = [];
  collectStrings(row.thumbnail_url, values);
  collectStrings(row.media_url, values);
  collectStrings(row.content, values);
  collectStrings(row.card_data, values);
  collectStrings(row.items, values);
  collectStrings(row.faq_data, values);

  const refs = new Map<string, LocalMediaRef>();
  for (const value of values) {
    const ref = localMediaRefFromString(value);
    if (ref) refs.set(ref.objectPath, ref);
  }
  return refs;
}

async function fetchTrashCleanupSettings(languageCode: string): Promise<TrashCleanupSettings> {
  const result = await dbQuery<{
    content_trash_auto_delete_enabled: boolean | null;
    content_trash_auto_delete_days: string | number | null;
    content_trash_auto_delete_scope: string | null;
    content_delete_media_with_post_enabled: boolean | null;
  }>(
    `SELECT
       content_trash_auto_delete_enabled,
       content_trash_auto_delete_days,
       content_trash_auto_delete_scope,
       content_delete_media_with_post_enabled
     FROM public.site_settings
     WHERE language_code = $1
     LIMIT 1`,
    [languageCode]
  );
  const row = result.rows[0];
  return {
    enabled: row?.content_trash_auto_delete_enabled === true,
    days: clampDays(row?.content_trash_auto_delete_days),
    scope: normalizeScope(row?.content_trash_auto_delete_scope),
    deleteMedia: row?.content_delete_media_with_post_enabled === true,
  };
}

async function fetchExpiredTrashPosts(settings: TrashCleanupSettings) {
  const params: unknown[] = [settings.days];
  let scopeSql = '';
  if (settings.scope === 'draft') {
    params.push('draft');
    scopeSql = `AND COALESCE(deleted_from_status, '') = $${params.length}`;
  }
  params.push(CLEANUP_LIMIT);
  const limitSql = `$${params.length}`;

  const result = await dbQuery<TrashPostRow>(
    `SELECT id, thumbnail_url, media_url, content, card_data, items, faq_data
     FROM public.posts
     WHERE deleted_at IS NOT NULL
       AND deleted_at <= now() - ($1::int * interval '1 day')
       ${scopeSql}
     ORDER BY deleted_at ASC, id ASC
     LIMIT ${limitSql}`,
    params
  );
  return result.rows || [];
}

function referencePatterns(ref: LocalMediaRef) {
  return [
    `%${ref.objectPath}%`,
    `%/local-upload/${ref.objectPath}%`,
    `%/api/storage/file/${ref.objectPath}%`,
    `%/api/storage/file/${ref.type}/${ref.relativeId}%`,
  ];
}

async function mediaReferencedOutsideTrashBatch(ref: LocalMediaRef, purgedIds: number[]) {
  if (!purgedIds.length) return true;
  const patterns = referencePatterns(ref);
  const result = await dbQuery<{ exists: boolean }>(
    `SELECT EXISTS (
       SELECT 1
       FROM public.posts p
       WHERE NOT (p.id = ANY($1::bigint[]))
         AND (
           COALESCE(p.thumbnail_url, '') LIKE ANY($2::text[])
           OR COALESCE(p.media_url, '') LIKE ANY($2::text[])
           OR COALESCE(p.content, '') LIKE ANY($2::text[])
           OR COALESCE(p.card_data::text, '') LIKE ANY($2::text[])
           OR COALESCE(p.items::text, '') LIKE ANY($2::text[])
           OR COALESCE(p.faq_data::text, '') LIKE ANY($2::text[])
         )
       LIMIT 1
     ) AS exists`,
    [purgedIds, patterns]
  );
  return result.rows[0]?.exists === true;
}

async function deleteExclusiveLocalMedia(rows: TrashPostRow[]) {
  const purgedIds = rows
    .map((row) => Number(row.id))
    .filter((id) => Number.isFinite(id));
  const refs = new Map<string, LocalMediaRef>();
  for (const row of rows) {
    for (const [key, ref] of mediaRefsForPost(row)) refs.set(key, ref);
  }

  for (const ref of refs.values()) {
    if (await mediaReferencedOutsideTrashBatch(ref, purgedIds)) continue;
    await deleteLocalUploadFiles(ref.type, ref.relativeId);
  }
}

export async function purgeExpiredTrashPosts(languageCode = 'tr') {
  const settings = await fetchTrashCleanupSettings(languageCode);
  if (!settings.enabled) return { purged: 0 };

  const rows = await fetchExpiredTrashPosts(settings);
  if (!rows.length) return { purged: 0 };

  if (settings.deleteMedia) {
    await deleteExclusiveLocalMedia(rows);
  }

  const ids = rows
    .map((row) => Number(row.id))
    .filter((id) => Number.isFinite(id));
  if (!ids.length) return { purged: 0 };

  const result = await dbQuery<{ id: string | number }>(
    `DELETE FROM public.posts
     WHERE id = ANY($1::bigint[])
       AND deleted_at IS NOT NULL
     RETURNING id`,
    [ids]
  );
  return { purged: result.rows.length };
}
