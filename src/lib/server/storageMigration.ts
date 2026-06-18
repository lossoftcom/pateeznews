import fs from 'fs';
import path from 'path';
import {
  LOCAL_UPLOAD_ROOT,
  localUploadItemsForType,
  resolveLocalUploadPath,
} from './localUploadStorage';
import { dbQuery } from './supabaseDb';
import { contentTypeForFilename, normalizeStoragePath, type StorageType } from './supabaseStorage';
import { recordStorageMediaFile, type StorageSettings } from './storageSettings';
import { activeRemoteProvider, remoteApiPath, uploadRemoteStorageObject } from './remoteObjectStorage';

type Replacement = {
  oldText: string;
  newText: string;
};

const MIGRATABLE_TYPES = ['image', 'video', 'audio', 'file', 'logo', 'profile'] as const;
const LEGACY_IMAGE_DIRECTORIES = ['announcements', 'navigation'] as const;

const TEXT_TARGETS = [
  { table: 'public.posts', columns: ['thumbnail_url', 'media_url', 'content'] },
  { table: 'public.profiles', columns: ['avatar_url', 'cover_url'] },
  { table: 'public.site_settings', columns: ['logo_url', 'footer_logo_url', 'dark_logo_url', 'email_logo_url', 'favicon_url', 'og_image_url'] },
  { table: 'public.navigation_items', columns: ['image_url'] },
  { table: 'public.pages', columns: ['content_plain'] },
  { table: 'public.announcements', columns: ['image_url'] },
  { table: 'public.announcement_media', columns: ['url'] },
  { table: 'public.stories', columns: ['media_url', 'story_markup'] },
] as const;

const JSON_TARGETS = [
  { table: 'public.posts', columns: ['card_data', 'items', 'faq_data'] },
  { table: 'public.pages', columns: ['content_delta'] },
  { table: 'public.stories', columns: ['story_data'] },
] as const;

function stripQuery(value: string) {
  return String(value || '').split(/[?#]/)[0];
}

function storageObjectPathFromUrl(value: string) {
  const clean = stripQuery(value);
  const apiMarker = '/api/storage/file/';
  const localMarker = '/local-upload/';
  const apiIndex = clean.indexOf(apiMarker);
  if (apiIndex >= 0) return normalizeStoragePath(clean.slice(apiIndex + apiMarker.length));
  const localIndex = clean.indexOf(localMarker);
  if (localIndex >= 0) return normalizeStoragePath(clean.slice(localIndex + localMarker.length));
  return '';
}

function replacementPairs(objectPath: string): Replacement[] {
  const normalized = normalizeStoragePath(objectPath);
  const remotePath = remoteApiPath(normalized);
  return [
    { oldText: `/local-upload/${normalized}`, newText: remotePath },
    { oldText: `local-upload/${normalized}`, newText: remotePath.replace(/^\//, '') },
  ];
}

function escapeLikePattern(value: string) {
  return value.replace(/[\\%_]/g, '\\$&');
}

function uniqReplacements(replacements: Replacement[]) {
  const map = new Map<string, Replacement>();
  for (const replacement of replacements) {
    if (!replacement.oldText || !replacement.newText || replacement.oldText === replacement.newText) continue;
    map.set(JSON.stringify(replacement), replacement);
  }
  return [...map.values()];
}

function isInside(baseDir: string, targetPath: string) {
  const relative = path.relative(baseDir, targetPath);
  return relative === '' || (!!relative && !relative.startsWith('..') && !path.isAbsolute(relative));
}

async function walkLocalFiles(baseDir: string, currentDir = baseDir): Promise<string[]> {
  if (!fs.existsSync(currentDir)) return [];
  const entries = await fs.promises.readdir(currentDir, { withFileTypes: true });
  const files: string[] = [];
  for (const entry of entries) {
    const fullPath = path.join(currentDir, entry.name);
    if (entry.isDirectory()) {
      files.push(...await walkLocalFiles(baseDir, fullPath));
    } else if (entry.isFile()) {
      files.push(path.relative(baseDir, fullPath).split(path.sep).join('/'));
    }
  }
  return files;
}

async function updateTextTargets(replacement: Replacement) {
  let updatedRows = 0;
  const likePattern = `%${escapeLikePattern(replacement.oldText)}%`;

  for (const target of TEXT_TARGETS) {
    const sets = target.columns.map(
      (column) => `${column} = NULLIF(REPLACE(COALESCE(${column}, ''), $1, $2), '')`,
    );
    const conditions = target.columns.map(
      (column) => `COALESCE(${column}, '') LIKE $3 ESCAPE '\\\\'`,
    );
    const result = await dbQuery(
      `UPDATE ${target.table}
       SET ${sets.join(', ')}
       WHERE ${conditions.join(' OR ')}`,
      [replacement.oldText, replacement.newText, likePattern],
    );
    updatedRows += result.rowCount || 0;
  }

  return updatedRows;
}

async function updateJsonTargets(replacement: Replacement) {
  let updatedRows = 0;
  const likePattern = `%${escapeLikePattern(replacement.oldText)}%`;

  for (const target of JSON_TARGETS) {
    const sets = target.columns.map(
      (column) =>
        `${column} = CASE WHEN COALESCE(${column}::text, '') LIKE $3 ESCAPE '\\\\' THEN (REPLACE(${column}::text, $1, $2))::jsonb ELSE ${column} END`,
    );
    const conditions = target.columns.map(
      (column) => `COALESCE(${column}::text, '') LIKE $3 ESCAPE '\\\\'`,
    );
    const result = await dbQuery(
      `UPDATE ${target.table}
       SET ${sets.join(', ')}
       WHERE ${conditions.join(' OR ')}`,
      [replacement.oldText, replacement.newText, likePattern],
    );
    updatedRows += result.rowCount || 0;
  }

  return updatedRows;
}

async function updateLocalUploadReferences(replacements: Replacement[]) {
  let updatedRows = 0;
  for (const replacement of uniqReplacements(replacements)) {
    updatedRows += await updateTextTargets(replacement);
    updatedRows += await updateJsonTargets(replacement);
  }
  return updatedRows;
}

async function uploadLocalObject(settings: StorageSettings, objectPath: string) {
  const normalized = normalizeStoragePath(objectPath);
  const [type, ...rest] = normalized.split('/');
  if (!MIGRATABLE_TYPES.includes(type as (typeof MIGRATABLE_TYPES)[number]) || !rest.length) return false;

  const resolved = resolveLocalUploadPath(type as StorageType, rest.join('/'));
  if (!resolved || !fs.existsSync(resolved.absolutePath)) return false;
  const stat = await fs.promises.stat(resolved.absolutePath);
  if (!stat.isFile()) return false;

  const buffer = await fs.promises.readFile(resolved.absolutePath);
  await uploadRemoteStorageObject(settings, {
    objectPath: normalized,
    body: buffer,
    contentType: contentTypeForFilename(normalized),
  });
  return true;
}

async function uploadLegacyLocalImageObject(settings: StorageSettings, directory: string, relativeId: string) {
  const baseDir = path.resolve(LOCAL_UPLOAD_ROOT, directory);
  const absolutePath = path.resolve(baseDir, relativeId);
  if (!isInside(baseDir, absolutePath) || !fs.existsSync(absolutePath)) return null;
  const stat = await fs.promises.stat(absolutePath);
  if (!stat.isFile()) return null;

  const objectPath = `image/${directory}/${relativeId}`;
  const buffer = await fs.promises.readFile(absolutePath);
  await uploadRemoteStorageObject(settings, {
    objectPath,
    body: buffer,
    contentType: contentTypeForFilename(objectPath),
  });

  return { objectPath, stat };
}

export async function migrateLocalMediaToRemote(settings: StorageSettings) {
  const provider = activeRemoteProvider(settings);
  const uploadedObjects = new Set<string>();
  const replacements: Replacement[] = [];

  for (const type of MIGRATABLE_TYPES) {
    const items = localUploadItemsForType(type);
    for (const item of items) {
      const objectPath = `${type}/${item.id}`;
      if (await uploadLocalObject(settings, objectPath)) {
        uploadedObjects.add(objectPath);
        replacements.push(...replacementPairs(objectPath));
        await recordStorageMediaFile(provider, {
          id: item.id,
          type,
          value: item.value,
          path: item.path,
          size: item.size,
          contentType: contentTypeForFilename(objectPath),
          src: remoteApiPath(objectPath),
          publicSrc: remoteApiPath(objectPath),
          thumb: remoteApiPath(storageObjectPathFromUrl(item.thumb || '') || objectPath),
        });
      }

      const thumbObjectPath = storageObjectPathFromUrl(item.thumb || '');
      if (thumbObjectPath && thumbObjectPath !== objectPath && await uploadLocalObject(settings, thumbObjectPath)) {
        uploadedObjects.add(thumbObjectPath);
        replacements.push(...replacementPairs(thumbObjectPath));
      }
    }
  }

  for (const directory of LEGACY_IMAGE_DIRECTORIES) {
    const baseDir = path.resolve(LOCAL_UPLOAD_ROOT, directory);
    const items = await walkLocalFiles(baseDir);
    for (const relativeId of items) {
      const result = await uploadLegacyLocalImageObject(settings, directory, relativeId);
      if (!result) continue;
      uploadedObjects.add(result.objectPath);
      replacements.push(
        { oldText: `/local-upload/${directory}/${relativeId}`, newText: remoteApiPath(result.objectPath) },
        { oldText: `local-upload/${directory}/${relativeId}`, newText: remoteApiPath(result.objectPath).replace(/^\//, '') },
      );
      await recordStorageMediaFile(provider, {
        id: `${directory}/${relativeId}`,
        type: 'image',
        value: path.posix.basename(relativeId),
        path: path.posix.dirname(`${directory}/${relativeId}`).replace(/^\.$/, ''),
        size: result.stat.size,
        contentType: contentTypeForFilename(result.objectPath),
        src: remoteApiPath(result.objectPath),
        publicSrc: remoteApiPath(result.objectPath),
        thumb: remoteApiPath(result.objectPath),
      });
    }
  }

  const updatedReferences = await updateLocalUploadReferences(replacements);
  return {
    uploaded: uploadedObjects.size,
    updatedReferences,
  };
}
