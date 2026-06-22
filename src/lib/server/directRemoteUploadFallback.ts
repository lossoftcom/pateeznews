import path from 'path';

import { contentTypeForFilename, normalizeStoragePath, type StorageType } from './supabaseStorage';
import { uploadRemoteStorageFile } from './remoteObjectStorage';
import { recordStorageMediaFile, type StorageSettings } from './storageSettings';

type UploadInput = Pick<File, 'name' | 'type' | 'arrayBuffer'>;

function extensionForContentType(contentType: string) {
  const normalized = contentType.toLowerCase().split(';')[0].trim();
  const map: Record<string, string> = {
    'image/jpeg': '.jpg',
    'image/jpg': '.jpg',
    'image/png': '.png',
    'image/webp': '.webp',
    'image/gif': '.gif',
    'image/avif': '.avif',
    'image/tiff': '.tif',
    'image/svg+xml': '.svg',
  };
  return map[normalized] || '';
}

function field(formData: FormData, key: string) {
  const value = formData.get(key);
  return typeof value === 'string' ? value.trim() : '';
}

function safeSegment(value: string, fallback: string) {
  const normalized = normalizeStoragePath(value);
  const base = path.posix.basename(normalized || fallback);
  const safe = base
    .replace(/[çÇ]/g, 'c')
    .replace(/[ğĞ]/g, 'g')
    .replace(/[ıİ]/g, 'i')
    .replace(/[öÖ]/g, 'o')
    .replace(/[şŞ]/g, 's')
    .replace(/[üÜ]/g, 'u')
    .normalize('NFKD')
    .replace(/[\u0300-\u036f]/g, '')
    .replace(/[^A-Za-z0-9._-]+/g, '-')
    .replace(/-+/g, '-')
    .replace(/^[-.]+|[-.]+$/g, '');
  return safe || fallback;
}

function safePath(value: string) {
  return normalizeStoragePath(value)
    .split('/')
    .map((segment) => safeSegment(segment, ''))
    .filter(Boolean)
    .join('/');
}

function fileExtension(file: UploadInput) {
  const fromName = path.posix.extname(file.name).toLowerCase();
  if (fromName) return fromName;
  return extensionForContentType(file.type) || '.bin';
}

function withExtension(fileName: string, fallbackExtension: string) {
  if (path.posix.extname(fileName)) return fileName;
  return `${fileName}${fallbackExtension}`;
}

function contentTypeForUpload(id: string, contentType: string) {
  const normalized = String(contentType || '').split(';')[0].trim().toLowerCase();
  const inferred = contentTypeForFilename(id, '');
  if (!normalized || normalized === 'application/octet-stream') {
    return inferred || 'application/octet-stream';
  }
  return normalized;
}

function remoteId(file: UploadInput, formData: FormData) {
  const replaceId = normalizeStoragePath(field(formData, 'replaceId'));
  if (replaceId) return replaceId;

  const fallbackExtension = fileExtension(file);
  const customFilename = field(formData, 'customFilename');
  const rawName = customFilename || file.name || `upload-${Date.now()}${fallbackExtension}`;
  const safeName = withExtension(safeSegment(rawName, `upload-${Date.now()}`), fallbackExtension);
  const finalName = customFilename
    ? safeName
    : `${Date.now()}-${Math.random().toString(36).slice(2, 10)}-${safeName}`;

  return normalizeStoragePath([safePath(field(formData, 'customPath')), finalName].filter(Boolean).join('/'));
}

export function shouldUseDirectRemoteUploadFallback(error: unknown) {
  const message = error instanceof Error ? error.message : String(error || '');
  return /fetch|network|connection|local storage/i.test(message);
}

export async function uploadOriginalFileDirectlyToRemoteStorage({
  storageSettings,
  file,
  type,
  formData,
}: {
  storageSettings: StorageSettings;
  file: UploadInput;
  type: StorageType;
  formData: FormData;
}) {
  const id = remoteId(file, formData);
  const body = await file.arrayBuffer();
  const contentType = contentTypeForUpload(id, file.type || contentTypeForFilename(file.name));
  const result = await uploadRemoteStorageFile(storageSettings, {
    type,
    id,
    body,
    contentType,
  });

  await recordStorageMediaFile(result.provider, {
    id: result.id,
    type: result.type,
    value: result.value,
    path: result.path,
    size: result.size,
    contentType: result.contentType || contentType,
    src: result.src,
    publicSrc: result.publicSrc,
    thumb: result.thumb,
  });

  return result;
}
