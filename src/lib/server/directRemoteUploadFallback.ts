import path from 'path';

import { contentTypeForFilename, normalizeStoragePath, type StorageType } from './supabaseStorage';
import { uploadRemoteStorageFile } from './remoteObjectStorage';
import { recordStorageMediaFile, type StorageSettings } from './storageSettings';

type UploadInput = Pick<File, 'name' | 'type' | 'arrayBuffer'>;
type ImageOutputFormat = 'webp' | 'jpeg' | 'png';

const OPTIMIZED_IMAGE_STORAGE_TYPES = new Set<StorageType>(['image', 'profile']);
const IMAGE_EXTENSIONS = new Set([
  '.jpg',
  '.jpeg',
  '.png',
  '.webp',
  '.gif',
  '.avif',
  '.tif',
  '.tiff',
  '.svg',
]);

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

function normalizeImageOutputFormat(value: string): ImageOutputFormat {
  const normalized = String(value || '').trim().toLowerCase();
  if (normalized === 'jpg' || normalized === 'jpeg') return 'jpeg';
  if (normalized === 'png') return 'png';
  return 'webp';
}

function extensionForImageOutputFormat(format: ImageOutputFormat) {
  return format === 'jpeg' ? 'jpg' : format;
}

function contentTypeForImageOutputFormat(format: ImageOutputFormat) {
  if (format === 'jpeg') return 'image/jpeg';
  if (format === 'png') return 'image/png';
  return 'image/webp';
}

function withImageOutputExtension(id: string, format: ImageOutputFormat) {
  const parsed = path.posix.parse(normalizeStoragePath(id));
  const fileName = `${parsed.name}.${extensionForImageOutputFormat(format)}`;
  return normalizeStoragePath(
    parsed.dir ? `${parsed.dir}/${fileName}` : fileName,
  );
}

function imageUploadMatchesOutputFormat(
  id: string,
  contentType: string,
  outputFormat: ImageOutputFormat,
) {
  const extension = path.posix.extname(id).toLowerCase().replace(/^\./, '');
  if (outputFormat === 'jpeg' && (extension === 'jpg' || extension === 'jpeg')) {
    return true;
  }
  if (extension === extensionForImageOutputFormat(outputFormat)) {
    return true;
  }
  const normalizedContentType = String(contentType || '').split(';')[0].trim().toLowerCase();
  return normalizedContentType === contentTypeForImageOutputFormat(outputFormat);
}

function imageConversionUnavailableError(outputFormat: ImageOutputFormat) {
  const error = new Error(
    `Image conversion to ${extensionForImageOutputFormat(outputFormat).toUpperCase()} requires the local upload processor.`,
  ) as Error & { status?: number };
  error.status = 503;
  return error;
}

function imageBytesMatchOutputFormat(
  body: ArrayBuffer | Uint8Array,
  outputFormat: ImageOutputFormat,
) {
  const bytes = body instanceof Uint8Array ? body : new Uint8Array(body);
  if (outputFormat === 'jpeg') {
    return bytes.length >= 3 &&
      bytes[0] === 0xff &&
      bytes[1] === 0xd8 &&
      bytes[2] === 0xff;
  }
  if (outputFormat === 'png') {
    return bytes.length >= 8 &&
      bytes[0] === 0x89 &&
      bytes[1] === 0x50 &&
      bytes[2] === 0x4e &&
      bytes[3] === 0x47 &&
      bytes[4] === 0x0d &&
      bytes[5] === 0x0a &&
      bytes[6] === 0x1a &&
      bytes[7] === 0x0a;
  }
  return bytes.length >= 12 &&
    bytes[0] === 0x52 &&
    bytes[1] === 0x49 &&
    bytes[2] === 0x46 &&
    bytes[3] === 0x46 &&
    bytes[8] === 0x57 &&
    bytes[9] === 0x45 &&
    bytes[10] === 0x42 &&
    bytes[11] === 0x50;
}

function shouldOptimizeImage(type: StorageType, id: string, contentType: string) {
  return OPTIMIZED_IMAGE_STORAGE_TYPES.has(type) &&
    (
      String(contentType || '').startsWith('image/') ||
      IMAGE_EXTENSIONS.has(path.posix.extname(id).toLowerCase())
    );
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

  if (shouldOptimizeImage(type, id, contentType)) {
    const outputFormat = normalizeImageOutputFormat(field(formData, 'imageOutputFormat'));
    const fileContentType = contentTypeForUpload(
      file.name,
      file.type || contentTypeForFilename(file.name),
    );
    if (!imageUploadMatchesOutputFormat(file.name, fileContentType, outputFormat) &&
        !imageUploadMatchesOutputFormat(id, contentType, outputFormat) &&
        !imageBytesMatchOutputFormat(body, outputFormat)) {
      throw imageConversionUnavailableError(outputFormat);
    }
    id = withImageOutputExtension(id, outputFormat);
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
