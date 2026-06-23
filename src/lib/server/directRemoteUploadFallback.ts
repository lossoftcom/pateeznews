import path from 'path';

import { contentTypeForFilename, normalizeStoragePath, type StorageType } from './supabaseStorage';
import { uploadRemoteStorageFile } from './remoteObjectStorage';
import { recordStorageMediaFile, type StorageSettings } from './storageSettings';

type UploadInput = Pick<File, 'name' | 'type' | 'arrayBuffer'>;

const OPTIMIZED_IMAGE_STORAGE_TYPES = new Set<StorageType>(['image', 'profile']);
const IMAGE_EXTENSIONS = new Set(['.jpg', '.jpeg', '.png', '.webp', '.gif', '.avif', '.tif', '.tiff', '.svg']);

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

function normalizeImageOutputFormat(value: string) {
  const normalized = String(value || '').trim().toLowerCase();
  if (normalized === 'jpg' || normalized === 'jpeg') return 'jpeg';
  if (normalized === 'png') return 'png';
  return 'webp';
}

function extensionForImageOutputFormat(format: string) {
  return format === 'jpeg' ? '.jpg' : `.${format}`;
}

function contentTypeForImageOutputFormat(format: string) {
  return format === 'jpeg'
    ? 'image/jpeg'
    : format === 'png'
      ? 'image/png'
      : 'image/webp';
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

function shouldOptimizeUpload(type: StorageType, id: string, contentType: string) {
  return OPTIMIZED_IMAGE_STORAGE_TYPES.has(type) &&
    (String(contentType || '').startsWith('image/') || IMAGE_EXTENSIONS.has(path.posix.extname(id).toLowerCase()));
}

function replaceObjectExtension(id: string, extension: string) {
  const parsed = path.posix.parse(id);
  return `${parsed.dir ? `${parsed.dir}/` : ''}${parsed.name}${extension}`;
}

async function optimizeImageUpload(input: ArrayBuffer | Uint8Array, outputFormat: string) {
  const { default: sharp } = await import('sharp');
  const bytes = input instanceof Uint8Array ? input : new Uint8Array(input);
  const image = sharp(bytes, { animated: true });
  const metadata = await image.metadata();
  const preset = metadata.hasAlpha ? 'picture' : 'photo';
  const pipeline = sharp(bytes, { animated: Boolean(metadata.pages && metadata.pages > 1) })
    .rotate()
    .resize({
      width: 7680,
      height: 7680,
      fit: 'inside',
      withoutEnlargement: true,
      kernel: 'lanczos3',
    });
  if (outputFormat === 'jpeg') {
    return pipeline
      .flatten({ background: '#ffffff' })
      .jpeg({
        quality: 92,
        mozjpeg: true,
      })
      .toBuffer();
  }
  if (outputFormat === 'png') {
    return pipeline
      .png({
        compressionLevel: 9,
        adaptiveFiltering: true,
      })
      .toBuffer();
  }
  return pipeline
    .webp({
      quality: 92,
      alphaQuality: 95,
      effort: 6,
      smartSubsample: true,
      smartDeblock: true,
      preset,
    })
    .toBuffer();
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
  let id = remoteId(file, formData);
  let body: ArrayBuffer | Uint8Array = await file.arrayBuffer();
  let contentType = contentTypeForUpload(id, file.type || contentTypeForFilename(file.name));
  if (shouldOptimizeUpload(type, id, contentType)) {
    const outputFormat = normalizeImageOutputFormat(field(formData, 'imageOutputFormat'));
    body = await optimizeImageUpload(body, outputFormat);
    id = replaceObjectExtension(id, extensionForImageOutputFormat(outputFormat));
    contentType = contentTypeForImageOutputFormat(outputFormat);
  }
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
