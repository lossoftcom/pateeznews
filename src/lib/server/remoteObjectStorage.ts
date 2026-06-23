import {
  contentTypeForFilename,
  getStorageType,
  normalizeStoragePath,
  relativeStorageId,
  storageObjectPath,
  type StorageType,
} from './supabaseStorage';
import path from 'path';
import type { ActiveStorage, StorageSettings } from './storageSettings';

type S3CompatibleProvider = Extract<ActiveStorage, 'awsS3' | 'cloudflareR2' | 'backblazeB2'>;
type BunnyProvider = Extract<ActiveStorage, 'bunnyNet'>;
type GoogleDriveProvider = Extract<ActiveStorage, 'googleDrive'>;
type RemoteProvider = S3CompatibleProvider | BunnyProvider | GoogleDriveProvider;

type S3CompatibleConfig = {
  provider: S3CompatibleProvider;
  accessKeyId: string;
  secretAccessKey: string;
  bucketName: string;
  endpoint: string;
  region: string;
  addressing: 'path' | 'virtualHost';
  pathPrefix: string;
};

type BunnyConfig = {
  provider: BunnyProvider;
  storageZoneName: string;
  accessKey: string;
  endpoint: string;
  pullZoneUrl: string;
  pathPrefix: string;
};

type GoogleDriveConfig = {
  provider: GoogleDriveProvider;
  clientId: string;
  clientSecret: string;
  refreshToken: string;
  folderId: string;
};

type RemoteObject = {
  key: string;
  size: number;
  lastModified: string;
};

type RemoteObjectMetadata = {
  exists: boolean;
  etag: string;
  size: number | null;
  contentType: string;
};

export type RemoteStorageItem = {
  id: string;
  value: string;
  size: number;
  date: number;
  type: StorageType;
  src: string;
  thumb: string;
  publicSrc: string;
  path: string;
  provider: RemoteProvider;
  objectPath: string;
  contentType?: string;
};

const STORAGE_TYPES = ['image', 'video', 'audio', 'file', 'logo', 'profile'] as const;
const VIDEO_THUMB_EXTENSIONS = ['.webp', '.jpg', '.jpeg', '.png'];
const EMPTY_SHA256 = 'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855';
const S3_SERVICE = 's3';

const textEncoder = new TextEncoder();

function cleanSetting(value: unknown) {
  return String(value || '').trim();
}

function normalizedEndpoint(value: string) {
  const clean = cleanSetting(value).replace(/\/+$/, '');
  return clean.startsWith('http://') || clean.startsWith('https://') ? clean : `https://${clean}`;
}

function normalizedPathPrefix(value: unknown) {
  return normalizeStoragePath(cleanSetting(value) || 'pateez');
}

function regionFromBackblazeEndpoint(endpoint: string) {
  try {
    const host = new URL(endpoint).hostname;
    const match = host.match(/^s3\.([a-z0-9-]+)\.backblazeb2\.com$/i);
    return match?.[1] || '';
  } catch {
    return '';
  }
}

function requireS3CompatibleConfig(settings: StorageSettings): S3CompatibleConfig {
  if (settings.activeStorage === 'cloudflareR2') {
    const provider = settings.providers.cloudflareR2 || {};
    const accountId = cleanSetting(provider.accountId);
    const accessKeyId = cleanSetting(provider.accessKey);
    const secretAccessKey = cleanSetting(provider.secretKey);
    const bucketName = cleanSetting(provider.bucketName);

    if (!accountId || !accessKeyId || !secretAccessKey || !bucketName) {
      throw Object.assign(new Error('Cloudflare R2 ayarları eksik'), { status: 400 });
    }

    return {
      provider: 'cloudflareR2',
      accessKeyId,
      secretAccessKey,
      bucketName,
      endpoint: `https://${accountId}.r2.cloudflarestorage.com`,
      region: 'auto',
      addressing: 'path',
      pathPrefix: normalizedPathPrefix(provider.pathPrefix),
    };
  }

  if (settings.activeStorage === 'awsS3') {
    const provider = settings.providers.awsS3 || {};
    const accessKeyId = cleanSetting(provider.accessKey);
    const secretAccessKey = cleanSetting(provider.secretKey);
    const bucketName = cleanSetting(provider.bucketName);
    const region = cleanSetting(provider.region);

    if (!accessKeyId || !secretAccessKey || !bucketName || !region) {
      throw Object.assign(new Error('AWS S3 ayarları eksik'), { status: 400 });
    }

    return {
      provider: 'awsS3',
      accessKeyId,
      secretAccessKey,
      bucketName,
      endpoint: `https://s3.${region}.amazonaws.com`,
      region,
      addressing: 'virtualHost',
      pathPrefix: normalizedPathPrefix(provider.pathPrefix),
    };
  }

  if (settings.activeStorage === 'backblazeB2') {
    const provider = settings.providers.backblazeB2 || {};
    const accessKeyId = cleanSetting(provider.keyId);
    const secretAccessKey = cleanSetting(provider.applicationKey);
    const bucketName = cleanSetting(provider.bucketName);
    const endpoint = normalizedEndpoint(provider.endpoint || '');
    const region = regionFromBackblazeEndpoint(endpoint);

    if (!accessKeyId || !secretAccessKey || !bucketName || !endpoint || !region) {
      throw Object.assign(new Error('Backblaze B2 S3 ayarları eksik'), { status: 400 });
    }

    return {
      provider: 'backblazeB2',
      accessKeyId,
      secretAccessKey,
      bucketName,
      endpoint,
      region,
      addressing: 'path',
      pathPrefix: normalizedPathPrefix(provider.pathPrefix),
    };
  }

  throw Object.assign(new Error(`Selected storage provider is not implemented: ${settings.activeStorage}`), { status: 501 });
}

function requireBunnyConfig(settings: StorageSettings): BunnyConfig {
  const provider = settings.providers.bunnyNet || {};
  const storageZoneName = cleanSetting(provider.storageZoneName);
  const accessKey = cleanSetting(provider.accessKey);
  const hostname = cleanSetting(provider.hostname) || 'storage.bunnycdn.com';
  if (!storageZoneName || !accessKey) {
    throw Object.assign(new Error('Bunny.net Storage ayarları eksik'), { status: 400 });
  }
  return {
    provider: 'bunnyNet',
    storageZoneName,
    accessKey,
    endpoint: normalizedEndpoint(hostname),
    pullZoneUrl: cleanSetting(provider.pullZoneUrl).replace(/\/+$/, ''),
    pathPrefix: normalizedPathPrefix(provider.pathPrefix),
  };
}

function requireGoogleDriveConfig(settings: StorageSettings): GoogleDriveConfig {
  const provider = settings.providers.googleDrive || {};
  const clientId = cleanSetting(provider.clientId);
  const clientSecret = cleanSetting(provider.clientSecret);
  const refreshToken = cleanSetting(provider.refreshToken);
  const folderId = cleanSetting(provider.folderId);
  if (!clientId || !clientSecret || !refreshToken || !folderId) {
    throw Object.assign(new Error('Google Drive ayarları eksik'), { status: 400 });
  }
  return {
    provider: 'googleDrive',
    clientId,
    clientSecret,
    refreshToken,
    folderId,
  };
}

function isS3CompatibleProvider(value: ActiveStorage): value is S3CompatibleProvider {
  return value === 'awsS3' || value === 'cloudflareR2' || value === 'backblazeB2';
}

export function activeRemoteProvider(settings: StorageSettings): RemoteProvider {
  if (isS3CompatibleProvider(settings.activeStorage)) return settings.activeStorage;
  if (settings.activeStorage === 'bunnyNet') return 'bunnyNet';
  if (settings.activeStorage === 'googleDrive') return 'googleDrive';
  throw Object.assign(new Error(`Selected storage provider is not remote: ${settings.activeStorage}`), { status: 400 });
}

function encodeRfc3986(value: string) {
  return encodeURIComponent(value).replace(/[!'()*]/g, (char) =>
    `%${char.charCodeAt(0).toString(16).toUpperCase()}`
  );
}

function encodeObjectPath(value: string) {
  return normalizeStoragePath(value).split('/').map(encodeRfc3986).join('/');
}

function objectPathFor(type: StorageType, id: string) {
  return storageObjectPath(type, id);
}

function providerObjectPath(config: S3CompatibleConfig, objectPath: string) {
  const cleanObjectPath = normalizeStoragePath(objectPath);
  return config.pathPrefix
    ? `${config.pathPrefix}/${cleanObjectPath}`
    : cleanObjectPath;
}

function publicObjectPath(config: S3CompatibleConfig, objectPath: string) {
  const normalized = normalizeStoragePath(objectPath);
  if (!config.pathPrefix) return normalized;
  const prefix = `${config.pathPrefix}/`;
  return normalized.startsWith(prefix) ? normalized.slice(prefix.length) : normalized;
}

export function remoteApiPath(objectPath: string) {
  return `/api/storage/file/${normalizeStoragePath(objectPath)}`;
}

function objectPathParts(objectPath: string) {
  const normalized = normalizeStoragePath(objectPath);
  const [first, ...rest] = normalized.split('/');
  const type = getStorageType(first);
  const id = rest.length ? rest.join('/') : relativeStorageId(type, normalized);
  return { type, id, objectPath: `${type}/${id}` };
}

function baseName(value: string) {
  return value.split('/').filter(Boolean).pop() || value;
}

function dirName(value: string) {
  const parts = value.split('/').filter(Boolean);
  parts.pop();
  return parts.join('/');
}

function videoThumbObjectPaths(objectPath: string) {
  const parsed = objectPathParts(objectPath);
  const dotIndex = parsed.id.lastIndexOf('.');
  const root = dotIndex > -1 ? parsed.id.slice(0, dotIndex) : parsed.id;
  return VIDEO_THUMB_EXTENSIONS.map((extension) => `video/${root}_thumb${extension}`);
}

function isVideoThumbObject(objectPath: string) {
  const parsed = objectPathParts(objectPath);
  if (parsed.type !== 'video') return false;
  const name = baseName(parsed.id).toLowerCase();
  return VIDEO_THUMB_EXTENSIONS.some((extension) => name.endsWith(`_thumb${extension}`));
}

function remoteItemFromObject(
  config: S3CompatibleConfig,
  provider: S3CompatibleProvider,
  object: RemoteObject,
  thumbByObjectPath: Map<string, string>,
): RemoteStorageItem | null {
  const parsed = objectPathParts(publicObjectPath(config, object.key));
  if (!parsed.id || !STORAGE_TYPES.includes(parsed.type as (typeof STORAGE_TYPES)[number])) return null;
  if (parsed.type === 'video' && isVideoThumbObject(parsed.objectPath)) return null;

  const thumbObjectPath = parsed.type === 'video'
    ? thumbByObjectPath.get(parsed.objectPath) || parsed.objectPath
    : parsed.objectPath;
  const date = Math.floor(new Date(object.lastModified || Date.now()).getTime() / 1000);
  const src = remoteApiPath(parsed.objectPath);
  const thumb = remoteApiPath(thumbObjectPath);

  return {
    id: parsed.id,
    value: baseName(parsed.id),
    size: object.size,
    date: Number.isFinite(date) ? date : Math.floor(Date.now() / 1000),
    type: parsed.type,
    src,
    thumb,
    publicSrc: src,
    path: dirName(parsed.id),
    provider,
    objectPath: parsed.objectPath,
    contentType: contentTypeForFilename(parsed.id),
  };
}

async function sha256Hex(input: string | ArrayBuffer | Uint8Array) {
  const data = typeof input === 'string'
    ? textEncoder.encode(input)
    : input instanceof Uint8Array
      ? input
      : new Uint8Array(input);
  const hash = await crypto.subtle.digest('SHA-256', data);
  return bytesToHex(new Uint8Array(hash));
}

async function hmacSha256(key: ArrayBuffer | Uint8Array, value: string) {
  const cryptoKey = await crypto.subtle.importKey(
    'raw',
    key,
    { name: 'HMAC', hash: 'SHA-256' },
    false,
    ['sign'],
  );
  const signature = await crypto.subtle.sign('HMAC', cryptoKey, textEncoder.encode(value));
  return new Uint8Array(signature);
}

function bytesToHex(bytes: Uint8Array) {
  return Array.from(bytes)
    .map((byte) => byte.toString(16).padStart(2, '0'))
    .join('');
}

function bodyBuffer(bytes: Uint8Array) {
  return bytes.byteOffset === 0 && bytes.byteLength === bytes.buffer.byteLength
    ? bytes.buffer
    : bytes.buffer.slice(bytes.byteOffset, bytes.byteOffset + bytes.byteLength);
}

function amzDateParts(date = new Date()) {
  const iso = date.toISOString().replace(/[:-]|\.\d{3}/g, '');
  return {
    amzDate: iso,
    shortDate: iso.slice(0, 8),
  };
}

function canonicalQuery(url: URL) {
  const pairs: Array<[string, string]> = [];
  url.searchParams.forEach((value, key) => pairs.push([key, value]));
  return pairs
    .sort(([leftKey, leftValue], [rightKey, rightValue]) =>
      leftKey === rightKey ? leftValue.localeCompare(rightValue) : leftKey.localeCompare(rightKey)
    )
    .map(([key, value]) => `${encodeRfc3986(key)}=${encodeRfc3986(value)}`)
    .join('&');
}

async function signingKey(secretAccessKey: string, shortDate: string, region: string) {
  const kDate = await hmacSha256(textEncoder.encode(`AWS4${secretAccessKey}`), shortDate);
  const kRegion = await hmacSha256(kDate, region);
  const kService = await hmacSha256(kRegion, S3_SERVICE);
  return hmacSha256(kService, 'aws4_request');
}

async function signedFetch(
  config: S3CompatibleConfig,
  input: {
    method: string;
    url: URL;
    canonicalPath: string;
    headers?: Record<string, string>;
    body?: BodyInit | null;
    payloadHash?: string;
    signal?: AbortSignal;
  },
) {
  const { amzDate, shortDate } = amzDateParts();
  const payloadHash = input.payloadHash || EMPTY_SHA256;
  const headers = new Headers(input.headers || {});
  headers.set('x-amz-date', amzDate);
  headers.set('x-amz-content-sha256', payloadHash);

  const canonicalHeaderValues = new Map<string, string>([['host', input.url.host]]);
  headers.forEach((value, key) => {
    canonicalHeaderValues.set(key.toLowerCase(), value);
  });
  const signedHeaders = Array.from(canonicalHeaderValues.keys()).sort();
  const canonicalHeaders = signedHeaders
    .map((key) => `${key}:${canonicalHeaderValues.get(key)!.trim().replace(/\s+/g, ' ')}\n`)
    .join('');
  const signedHeadersValue = signedHeaders.join(';');
  const canonicalRequest = [
    input.method.toUpperCase(),
    input.canonicalPath,
    canonicalQuery(input.url),
    canonicalHeaders,
    signedHeadersValue,
    payloadHash,
  ].join('\n');

  const credentialScope = `${shortDate}/${config.region}/${S3_SERVICE}/aws4_request`;
  const stringToSign = [
    'AWS4-HMAC-SHA256',
    amzDate,
    credentialScope,
    await sha256Hex(canonicalRequest),
  ].join('\n');
  const signature = bytesToHex(await hmacSha256(
    await signingKey(config.secretAccessKey, shortDate, config.region),
    stringToSign,
  ));
  headers.set(
    'authorization',
    `AWS4-HMAC-SHA256 Credential=${config.accessKeyId}/${credentialScope}, SignedHeaders=${signedHeadersValue}, Signature=${signature}`,
  );

  return fetch(input.url, {
    method: input.method,
    headers,
    body: input.body,
    signal: input.signal,
  });
}

function bucketUrl(config: S3CompatibleConfig, objectPath = '') {
  const encodedBucket = encodeRfc3986(config.bucketName);
  const encodedObjectPath = objectPath ? `/${encodeObjectPath(objectPath)}` : '';
  if (config.addressing === 'virtualHost') {
    const endpoint = new URL(config.endpoint);
    endpoint.hostname = `${config.bucketName}.${endpoint.hostname}`;
    endpoint.pathname = encodedObjectPath || '/';
    return {
      url: endpoint,
      canonicalPath: encodedObjectPath || '/',
    };
  }
  const canonicalPath = `/${encodedBucket}${encodedObjectPath}`;
  return { url: new URL(`${config.endpoint}${canonicalPath}`), canonicalPath };
}

function bunnyObjectPath(config: BunnyConfig, objectPath: string) {
  const cleanObjectPath = normalizeStoragePath(objectPath);
  return config.pathPrefix ? `${config.pathPrefix}/${cleanObjectPath}` : cleanObjectPath;
}

function bunnyUrl(config: BunnyConfig, objectPath: string) {
  const endpoint = new URL(config.endpoint);
  const objectPathPart = encodeObjectPath(bunnyObjectPath(config, objectPath));
  endpoint.pathname = `/${encodeRfc3986(config.storageZoneName)}/${objectPathPart}`;
  return endpoint;
}

async function bunnyFetch(
  config: BunnyConfig,
  objectPath: string,
  init: RequestInit = {},
) {
  const headers = new Headers(init.headers || {});
  headers.set('AccessKey', config.accessKey);
  return fetch(bunnyUrl(config, objectPath), { ...init, headers });
}

async function bunnyObjectExists(config: BunnyConfig, objectPath: string) {
  const response = await bunnyFetch(config, objectPath, {
    method: 'GET',
    headers: { range: 'bytes=0-0' },
  });
  await response.arrayBuffer().catch(() => undefined);
  if (response.status === 404) return false;
  if (!response.ok && response.status !== 206) {
    throw Object.assign(new Error(`${config.provider} head failed`), { status: response.status });
  }
  return true;
}

async function bunnyDownloadObject(config: BunnyConfig, objectPath: string) {
  const response = await bunnyFetch(config, objectPath, { method: 'GET' });
  if (response.status === 404) {
    return { ok: false as const, status: 404, body: null, contentType: '' };
  }
  if (!response.ok) {
    const text = await response.text().catch(() => '');
    throw Object.assign(new Error(text || `${config.provider} download failed`), { status: response.status });
  }
  return {
    ok: true as const,
    status: response.status,
    body: await response.arrayBuffer(),
    contentType: response.headers.get('content-type') || '',
  };
}

async function bunnyUploadObject(
  config: BunnyConfig,
  objectPath: string,
  body: ArrayBuffer | Uint8Array,
  contentType = '',
) {
  const bytes = body instanceof Uint8Array ? body : new Uint8Array(body);
  const checksum = (await sha256Hex(bytes)).toUpperCase();
  const response = await bunnyFetch(config, objectPath, {
    method: 'PUT',
    headers: {
      'content-type': contentType || contentTypeForFilename(objectPath),
      checksum,
    },
    body: bodyBuffer(bytes),
  });
  const text = await response.text().catch(() => '');
  if (!response.ok) {
    throw Object.assign(new Error(text || `${config.provider} upload failed`), { status: response.status });
  }
}

async function bunnyDeleteObject(config: BunnyConfig, objectPath: string) {
  const response = await bunnyFetch(config, objectPath, { method: 'DELETE' });
  if (!response.ok && response.status !== 404) {
    const text = await response.text().catch(() => '');
    throw Object.assign(new Error(text || `${config.provider} delete failed`), { status: response.status });
  }
}

async function googleDriveAccessToken(config: GoogleDriveConfig) {
  const response = await fetch('https://oauth2.googleapis.com/token', {
    method: 'POST',
    headers: { 'content-type': 'application/x-www-form-urlencoded' },
    body: new URLSearchParams({
      client_id: config.clientId,
      client_secret: config.clientSecret,
      refresh_token: config.refreshToken,
      grant_type: 'refresh_token',
    }),
  });
  const data = await response.json().catch(() => ({}));
  if (!response.ok || !data?.access_token) {
    throw Object.assign(new Error(data?.error_description || data?.error || 'Google Drive token refresh failed'), { status: response.status || 401 });
  }
  return String(data.access_token);
}

async function googleDriveFetch(
  config: GoogleDriveConfig,
  url: string,
  init: RequestInit = {},
) {
  const token = await googleDriveAccessToken(config);
  const headers = new Headers(init.headers || {});
  headers.set('authorization', `Bearer ${token}`);
  return fetch(url, { ...init, headers });
}

async function googleDriveFileMetadata(config: GoogleDriveConfig, fileId: string) {
  const url = new URL(`https://www.googleapis.com/drive/v3/files/${encodeURIComponent(fileId)}`);
  url.searchParams.set('fields', 'id,name,size,mimeType,modifiedTime');
  url.searchParams.set('supportsAllDrives', 'true');
  const response = await googleDriveFetch(config, url.toString());
  const data = await response.json().catch(() => ({}));
  if (response.status === 404) return null;
  if (!response.ok) {
    throw Object.assign(new Error(data?.error?.message || 'Google Drive file lookup failed'), { status: response.status });
  }
  return data as { id?: string; name?: string; size?: string; mimeType?: string; modifiedTime?: string };
}

async function googleDriveRenameFile(config: GoogleDriveConfig, fileId: string, name: string) {
  const url = new URL(`https://www.googleapis.com/drive/v3/files/${encodeURIComponent(fileId)}`);
  url.searchParams.set('fields', 'id,name,size,mimeType,modifiedTime');
  url.searchParams.set('supportsAllDrives', 'true');
  const response = await googleDriveFetch(config, url.toString(), {
    method: 'PATCH',
    headers: { 'content-type': 'application/json' },
    body: JSON.stringify({ name }),
  });
  const data = await response.json().catch(() => ({}));
  if (!response.ok) {
    throw Object.assign(new Error(data?.error?.message || 'Google Drive rename failed'), { status: response.status });
  }
  return data as { id?: string; name?: string; size?: string; mimeType?: string; modifiedTime?: string };
}

async function googleDriveDeleteFile(config: GoogleDriveConfig, fileId: string) {
  const url = new URL(`https://www.googleapis.com/drive/v3/files/${encodeURIComponent(fileId)}`);
  url.searchParams.set('supportsAllDrives', 'true');
  const response = await googleDriveFetch(config, url.toString(), { method: 'DELETE' });
  if (!response.ok && response.status !== 404) {
    const data = await response.json().catch(() => ({}));
    throw Object.assign(new Error(data?.error?.message || 'Google Drive delete failed'), { status: response.status });
  }
}

async function renameBunnyStorageFile(
  settings: StorageSettings,
  input: {
    type: StorageType;
    replacements: Array<{ oldId: string; newId: string; required?: boolean }>;
  },
) {
  const config = requireBunnyConfig(settings);
  const copied: Array<{ oldId: string; newId: string; oldObjectPath: string; newObjectPath: string }> = [];
  const skipped: Array<{ oldId: string; newId: string; reason: string }> = [];
  try {
    for (const { oldId, newId, required } of input.replacements) {
      if (!oldId || !newId || oldId === newId) continue;
      const oldObjectPath = objectPathFor(input.type, oldId);
      const newObjectPath = objectPathFor(input.type, newId);
      const source = await bunnyDownloadObject(config, oldObjectPath);
      if (!source.ok || !source.body) {
        if (required) {
          throw Object.assign(new Error(`${config.provider} source object not found: ${oldObjectPath}`), { status: 404 });
        }
        skipped.push({ oldId, newId, reason: 'source-not-found' });
        continue;
      }
      await bunnyUploadObject(config, newObjectPath, source.body, source.contentType);
      const verified = await bunnyObjectExists(config, newObjectPath);
      if (!verified) {
        throw Object.assign(new Error(`${config.provider} copied object verification failed: ${newObjectPath}`), { status: 502 });
      }
      copied.push({ oldId, newId, oldObjectPath, newObjectPath });
    }
  } catch (error) {
    for (const { newObjectPath } of copied) {
      await bunnyDeleteObject(config, newObjectPath).catch((cleanupError) => {
        console.warn('Bunny rename rollback skipped:', cleanupError instanceof Error ? cleanupError.message : cleanupError);
      });
    }
    throw error;
  }
  return { success: true, renamed: copied.length, verified: copied.length, copied, skipped };
}

async function renameGoogleDriveStorageFile(
  settings: StorageSettings,
  input: {
    type: StorageType;
    replacements: Array<{ oldId: string; newId: string; required?: boolean }>;
  },
) {
  const config = requireGoogleDriveConfig(settings);
  const copied: Array<{ oldId: string; newId: string; oldObjectPath: string; newObjectPath: string }> = [];
  const skipped: Array<{ oldId: string; newId: string; reason: string }> = [];
  for (const { oldId, newId, required } of input.replacements.slice(0, 1)) {
    if (!oldId || !newId) continue;
    const metadata = await googleDriveFileMetadata(config, oldId);
    if (!metadata?.id) {
      if (required) {
        throw Object.assign(new Error(`Google Drive file not found: ${oldId}`), { status: 404 });
      }
      skipped.push({ oldId, newId, reason: 'source-not-found' });
      continue;
    }
    await googleDriveRenameFile(config, oldId, path.posix.basename(newId));
    copied.push({ oldId, newId: oldId, oldObjectPath: oldId, newObjectPath: oldId });
  }
  return { success: true, renamed: copied.length, verified: copied.length, copied, skipped, metadataOnly: true };
}

function decodeXml(value: string) {
  return value
    .replace(/&lt;/g, '<')
    .replace(/&gt;/g, '>')
    .replace(/&quot;/g, '"')
    .replace(/&apos;/g, "'")
    .replace(/&amp;/g, '&');
}

function xmlTag(block: string, tag: string) {
  const match = block.match(new RegExp(`<${tag}>([\\s\\S]*?)<\\/${tag}>`, 'i'));
  return match ? decodeXml(match[1]) : '';
}

function parseListObjectsXml(xml: string) {
  const objects: RemoteObject[] = [];
  for (const match of xml.matchAll(/<Contents>([\s\S]*?)<\/Contents>/gi)) {
    const block = match[1];
    const key = xmlTag(block, 'Key');
    if (!key) continue;
    objects.push({
      key,
      size: Number(xmlTag(block, 'Size')) || 0,
      lastModified: xmlTag(block, 'LastModified'),
    });
  }
  return {
    objects,
    isTruncated: /<IsTruncated>true<\/IsTruncated>/i.test(xml),
    nextContinuationToken: xmlTag(xml, 'NextContinuationToken'),
  };
}

async function listRemoteObjects(config: S3CompatibleConfig, prefix: string) {
  const objects: RemoteObject[] = [];
  let continuationToken = '';

  for (let page = 0; page < 50; page += 1) {
    const target = bucketUrl(config);
    target.url.searchParams.set('list-type', '2');
    target.url.searchParams.set('prefix', prefix);
    target.url.searchParams.set('max-keys', '1000');
    if (continuationToken) target.url.searchParams.set('continuation-token', continuationToken);

    const response = await signedFetch(config, {
      method: 'GET',
      url: target.url,
      canonicalPath: target.canonicalPath,
    });
    const text = await response.text();
    if (!response.ok) throw Object.assign(new Error(text || `${config.provider} list failed`), { status: response.status });

    const pageData = parseListObjectsXml(text);
    objects.push(...pageData.objects);
    if (!pageData.isTruncated || !pageData.nextContinuationToken) break;
    continuationToken = pageData.nextContinuationToken;
  }

  return objects;
}

export async function listRemoteStorageFiles(settings: StorageSettings, type: StorageType) {
  const config = requireS3CompatibleConfig(settings);
  const provider = config.provider;
  const objects = await listRemoteObjects(config, providerObjectPath(config, `${type}/`));
  const thumbByObjectPath = new Map<string, string>();
  if (type === 'video') {
    const objectKeys = new Set(objects.map((object) => publicObjectPath(config, object.key)));
    for (const object of objects) {
      const objectPath = publicObjectPath(config, object.key);
      if (isVideoThumbObject(objectPath)) continue;
      const thumb = videoThumbObjectPaths(objectPath).find((candidate) => objectKeys.has(candidate));
      if (thumb) thumbByObjectPath.set(objectPath, thumb);
    }
  }
  return objects
    .map((object) => remoteItemFromObject(config, provider, object, thumbByObjectPath))
    .filter((item): item is RemoteStorageItem => item !== null)
    .sort((a, b) => b.date - a.date || b.id.localeCompare(a.id));
}

export async function uploadRemoteStorageObject(
  settings: StorageSettings,
  input: {
    objectPath: string;
    body: ArrayBuffer | Uint8Array;
    contentType?: string;
  },
) {
  const config = requireS3CompatibleConfig(settings);
  const objectPath = normalizeStoragePath(input.objectPath);
  const remoteObjectPath = providerObjectPath(config, objectPath);
  const bytes = input.body instanceof Uint8Array ? input.body : new Uint8Array(input.body);
  const target = bucketUrl(config, remoteObjectPath);
  const contentType = input.contentType || contentTypeForFilename(objectPath);
  const payloadHash = await sha256Hex(bytes);
  const response = await signedFetch(config, {
    method: 'PUT',
    url: target.url,
    canonicalPath: target.canonicalPath,
    headers: {
      'content-type': contentType,
    },
    body: bodyBuffer(bytes),
    payloadHash,
  });
  const text = await response.text();
  if (!response.ok) throw Object.assign(new Error(text || `${config.provider} upload failed`), { status: response.status });
  return objectPath;
}

export async function uploadRemoteStorageFile(
  settings: StorageSettings,
  input: {
    type: StorageType;
    id: string;
    body: ArrayBuffer | Uint8Array;
    contentType?: string;
    thumbObjectPath?: string;
  },
): Promise<RemoteStorageItem> {
  const provider = activeRemoteProvider(settings);
  const objectPath = objectPathFor(input.type, input.id);
  const bytes = input.body instanceof Uint8Array ? input.body : new Uint8Array(input.body);
  await uploadRemoteStorageObject(settings, {
    objectPath,
    body: bytes,
    contentType: input.contentType || contentTypeForFilename(input.id),
  });
  const relativeId = relativeStorageId(input.type, objectPath);
  const src = remoteApiPath(objectPath);
  const thumb = input.thumbObjectPath ? remoteApiPath(input.thumbObjectPath) : src;
  return {
    id: relativeId,
    value: baseName(relativeId),
    size: bytes.byteLength,
    date: Math.floor(Date.now() / 1000),
    type: input.type,
    src,
    thumb,
    publicSrc: src,
    path: dirName(relativeId),
    provider,
    objectPath,
    contentType: input.contentType || contentTypeForFilename(relativeId),
  };
}

export async function getRemoteStorageFile(
  settings: StorageSettings,
  objectPath: string,
  request: Request,
  options: { timeoutMs?: number } = {},
) {
  if (settings.activeStorage === 'bunnyNet') {
    const config = requireBunnyConfig(settings);
    return bunnyFetch(config, objectPath, {
      method: 'GET',
      headers: {
        ...(request.headers.get('range') ? { range: request.headers.get('range') || '' } : {}),
      },
    });
  }
  if (settings.activeStorage === 'googleDrive') {
    const config = requireGoogleDriveConfig(settings);
    const parsed = objectPathParts(objectPath);
    const url = new URL(`https://www.googleapis.com/drive/v3/files/${encodeURIComponent(parsed.id)}`);
    url.searchParams.set('alt', 'media');
    url.searchParams.set('supportsAllDrives', 'true');
    return googleDriveFetch(config, url.toString(), {
      headers: {
        ...(request.headers.get('range') ? { range: request.headers.get('range') || '' } : {}),
      },
    });
  }
  const config = requireS3CompatibleConfig(settings);
  const target = bucketUrl(config, providerObjectPath(config, objectPath));
  const range = request.headers.get('range') || '';
  const controller = options.timeoutMs ? new AbortController() : null;
  const timeout = controller
    ? setTimeout(() => controller.abort(), options.timeoutMs)
    : null;
  try {
    return await signedFetch(config, {
      method: 'GET',
      url: target.url,
      canonicalPath: target.canonicalPath,
      headers: {
        ...(range ? { range } : {}),
      },
      signal: controller?.signal,
    });
  } finally {
    if (timeout) clearTimeout(timeout);
  }
}

export async function deleteRemoteStorageFile(
  settings: StorageSettings,
  input: {
    id: string;
    type?: StorageType | null;
  },
) {
  if (settings.activeStorage === 'googleDrive') {
    const config = requireGoogleDriveConfig(settings);
    const rawId = normalizeStoragePath(input.id);
    const parsed = input.type ? relativeStorageId(input.type, objectPathFor(input.type, rawId)) : objectPathParts(rawId).id;
    await googleDriveDeleteFile(config, parsed);
    return { success: true, deleted: [{ type: input.type || objectPathParts(rawId).type, ids: [parsed] }], paths: [{ type: input.type || objectPathParts(rawId).type, ids: [parsed] }] };
  }
  if (settings.activeStorage === 'bunnyNet') {
    const config = requireBunnyConfig(settings);
    const rawId = normalizeStoragePath(input.id);
    const candidates = new Map<StorageType, string[]>();
    if (input.type) {
      const objectPath = objectPathFor(input.type, rawId);
      candidates.set(input.type, [relativeStorageId(input.type, objectPath)]);
    } else {
      const first = rawId.split('/')[0];
      if (STORAGE_TYPES.includes(first as (typeof STORAGE_TYPES)[number])) {
        const type = first as StorageType;
        candidates.set(type, [relativeStorageId(type, rawId)]);
      } else {
        for (const type of STORAGE_TYPES) candidates.set(type, [rawId]);
      }
    }
    const deleted: Array<{ type: StorageType; ids: string[] }> = [];
    for (const [type, ids] of candidates.entries()) {
      const expandedIds = new Set(ids);
      for (const id of ids) {
        if (type !== 'video') continue;
        for (const thumb of videoThumbObjectPaths(`${type}/${id}`)) {
          expandedIds.add(relativeStorageId(type, thumb));
        }
      }
      const removed: string[] = [];
      for (const id of expandedIds) {
        await bunnyDeleteObject(config, objectPathFor(type, id));
        removed.push(relativeStorageId(type, objectPathFor(type, id)));
      }
      if (removed.length) deleted.push({ type, ids: removed });
    }
    return { success: true, deleted, paths: deleted };
  }
  const config = requireS3CompatibleConfig(settings);
  const rawId = normalizeStoragePath(input.id);
  const candidates = new Map<StorageType, string[]>();

  if (input.type) {
    const objectPath = objectPathFor(input.type, rawId);
    const id = relativeStorageId(input.type, objectPath);
    candidates.set(input.type, [id]);
  } else {
    const first = rawId.split('/')[0];
    if (STORAGE_TYPES.includes(first as (typeof STORAGE_TYPES)[number])) {
      const type = first as StorageType;
      candidates.set(type, [relativeStorageId(type, rawId)]);
    } else {
      for (const type of STORAGE_TYPES) candidates.set(type, [rawId]);
    }
  }

  const deleted: Array<{ type: StorageType; ids: string[] }> = [];
  for (const [type, ids] of candidates.entries()) {
    const expandedIds = new Set(ids);
    for (const id of ids) {
      if (type !== 'video') continue;
      for (const thumb of videoThumbObjectPaths(`${type}/${id}`)) {
        expandedIds.add(relativeStorageId(type, thumb));
      }
    }

    const removed: string[] = [];
    for (const id of expandedIds) {
      const objectPath = objectPathFor(type, id);
      const target = bucketUrl(config, providerObjectPath(config, objectPath));
      const response = await signedFetch(config, {
        method: 'DELETE',
        url: target.url,
        canonicalPath: target.canonicalPath,
      });
      if (!response.ok && response.status !== 404) {
        const text = await response.text();
        throw Object.assign(new Error(text || `${config.provider} delete failed`), { status: response.status });
      }
      removed.push(relativeStorageId(type, objectPath));
    }
    if (removed.length) deleted.push({ type, ids: removed });
  }

  return { success: true, deleted, paths: deleted };
}

async function headRemoteObject(
  config: S3CompatibleConfig,
  objectPath: string,
): Promise<RemoteObjectMetadata> {
  const target = bucketUrl(config, providerObjectPath(config, objectPath));
  const response = await signedFetch(config, {
    method: 'HEAD',
    url: target.url,
    canonicalPath: target.canonicalPath,
  });
  await response.arrayBuffer().catch(() => undefined);
  if (response.status === 404) {
    return { exists: false, etag: '', size: null, contentType: '' };
  }
  if (!response.ok) {
    throw Object.assign(new Error(`${config.provider} head failed`), { status: response.status });
  }
  const sizeHeader = response.headers.get('content-length') || '';
  const size = sizeHeader ? Number(sizeHeader) : null;
  return {
    exists: true,
    etag: response.headers.get('etag') || '',
    size: Number.isFinite(size) ? size : null,
    contentType: response.headers.get('content-type') || '',
  };
}

async function copyRemoteObject(
  config: S3CompatibleConfig,
  sourceObjectPath: string,
  destObjectPath: string,
  sourceEtag = '',
) {
  const remoteSource = providerObjectPath(config, sourceObjectPath);
  const remoteDest = providerObjectPath(config, destObjectPath);
  const encodedBucket = encodeRfc3986(config.bucketName);
  const copySource = `/${encodedBucket}/${encodeObjectPath(remoteSource)}`;
  const target = bucketUrl(config, remoteDest);
  const headers: Record<string, string> = { 'x-amz-copy-source': copySource };
  if (sourceEtag) headers['x-amz-copy-source-if-match'] = sourceEtag;
  const response = await signedFetch(config, {
    method: 'PUT',
    url: target.url,
    canonicalPath: target.canonicalPath,
    headers,
  });
  const text = await response.text();
  // S3 CopyObject can return HTTP 200 with an <Error> body, so check both.
  const ok = response.ok && !/<Error>/i.test(text);
  return { ok, status: response.status, text };
}

async function deleteRemoteObject(config: S3CompatibleConfig, objectPath: string) {
  const target = bucketUrl(config, providerObjectPath(config, objectPath));
  const response = await signedFetch(config, {
    method: 'DELETE',
    url: target.url,
    canonicalPath: target.canonicalPath,
  });
  if (!response.ok && response.status !== 404) {
    const text = await response.text();
    throw Object.assign(new Error(text || `${config.provider} delete failed`), { status: response.status });
  }
}

// Renames remote objects by copying each source key to its new key. The caller
// deletes originals only after DB/local commit succeeds. Copies are performed first; if any copy fails the
// already-created copies are rolled back so the original keys stay authoritative
// (never a half-renamed state).
export async function renameRemoteStorageFile(
  settings: StorageSettings,
  input: {
    type: StorageType;
    replacements: Array<{ oldId: string; newId: string; required?: boolean }>;
  },
) {
  if (settings.activeStorage === 'bunnyNet') {
    return renameBunnyStorageFile(settings, input);
  }
  if (settings.activeStorage === 'googleDrive') {
    return renameGoogleDriveStorageFile(settings, input);
  }
  const config = requireS3CompatibleConfig(settings);
  const copied: Array<{ oldId: string; newId: string; oldObjectPath: string; newObjectPath: string }> = [];
  const skipped: Array<{ oldId: string; newId: string; reason: string }> = [];

  try {
    for (const { oldId, newId, required } of input.replacements) {
      if (!oldId || !newId || oldId === newId) continue;
      const oldObjectPath = objectPathFor(input.type, oldId);
      const newObjectPath = objectPathFor(input.type, newId);
      const sourceHead = await headRemoteObject(config, oldObjectPath);
      if (!sourceHead.exists) {
        if (required) {
          throw Object.assign(new Error(`${config.provider} source object not found: ${oldObjectPath}`), { status: 404 });
        }
        skipped.push({ oldId, newId, reason: 'source-not-found' });
        continue;
      }
      const result = await copyRemoteObject(config, oldObjectPath, newObjectPath, sourceHead.etag);
      if (!result.ok) {
        throw Object.assign(
          new Error(result.text || `${config.provider} copy failed`),
          { status: result.status || 500 },
        );
      }
      const destHead = await headRemoteObject(config, newObjectPath);
      if (!destHead.exists) {
        throw Object.assign(new Error(`${config.provider} copied object verification failed: ${newObjectPath}`), { status: 502 });
      }
      if (sourceHead.size !== null && destHead.size !== null && sourceHead.size !== destHead.size) {
        throw Object.assign(new Error(`${config.provider} copied object size mismatch: ${newObjectPath}`), { status: 502 });
      }
      copied.push({ oldId, newId, oldObjectPath, newObjectPath });
    }
  } catch (error) {
    for (const { newObjectPath } of copied) {
      await deleteRemoteObject(config, newObjectPath).catch((cleanupError) => {
        console.warn(
          'Remote rename rollback skipped:',
          newObjectPath,
          cleanupError instanceof Error ? cleanupError.message : cleanupError,
        );
      });
    }
    throw error;
  }

  return { success: true, renamed: copied.length, verified: copied.length, copied, skipped };
}

export async function deleteRemoteStorageRenameSources(
  settings: StorageSettings,
  input: {
    type: StorageType;
    replacements: Array<{ oldId: string }>;
  },
) {
  if (settings.activeStorage === 'googleDrive') {
    return { deleted: [] as string[], errors: [] as string[] };
  }
  if (settings.activeStorage === 'bunnyNet') {
    const config = requireBunnyConfig(settings);
    const deleted: string[] = [];
    const errors: string[] = [];
    for (const { oldId } of input.replacements) {
      if (!oldId) continue;
      try {
        await bunnyDeleteObject(config, objectPathFor(input.type, oldId));
        deleted.push(oldId);
      } catch (error) {
        errors.push(error instanceof Error ? error.message : String(error));
      }
    }
    return { deleted, errors };
  }
  const config = requireS3CompatibleConfig(settings);
  const deleted: string[] = [];
  const errors: string[] = [];
  for (const { oldId } of input.replacements) {
    if (!oldId) continue;
    const oldObjectPath = objectPathFor(input.type, oldId);
    try {
      await deleteRemoteObject(config, oldObjectPath);
      deleted.push(oldId);
    } catch (error) {
      errors.push(error instanceof Error ? error.message : String(error));
    }
  }
  return { deleted, errors };
}

// Lightweight existence check (HEAD) used to pick a collision-free key before a
// rename so an SEO name never silently overwrites a different object.
export async function remoteObjectExists(
  settings: StorageSettings,
  type: StorageType,
  id: string,
) {
  if (settings.activeStorage === 'bunnyNet') {
    const config = requireBunnyConfig(settings);
    return bunnyObjectExists(config, objectPathFor(type, id));
  }
  if (settings.activeStorage === 'googleDrive') {
    const config = requireGoogleDriveConfig(settings);
    const metadata = await googleDriveFileMetadata(config, id);
    return Boolean(metadata?.id);
  }
  const config = requireS3CompatibleConfig(settings);
  const objectPath = objectPathFor(type, id);
  const metadata = await headRemoteObject(config, objectPath);
  return metadata.exists;
}
