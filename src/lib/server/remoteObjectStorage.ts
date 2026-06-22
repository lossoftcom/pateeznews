import {
  contentTypeForFilename,
  getStorageType,
  normalizeStoragePath,
  relativeStorageId,
  storageObjectPath,
  type StorageType,
} from './supabaseStorage';
import type { ActiveStorage, StorageSettings } from './storageSettings';

type S3CompatibleProvider = Extract<ActiveStorage, 'awsS3' | 'cloudflareR2' | 'backblazeB2'>;

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

type RemoteObject = {
  key: string;
  size: number;
  lastModified: string;
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
  provider: S3CompatibleProvider;
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

export function activeRemoteProvider(settings: StorageSettings): S3CompatibleProvider {
  return requireS3CompatibleConfig(settings).provider;
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

async function copyRemoteObject(
  config: S3CompatibleConfig,
  sourceObjectPath: string,
  destObjectPath: string,
) {
  const remoteSource = providerObjectPath(config, sourceObjectPath);
  const remoteDest = providerObjectPath(config, destObjectPath);
  const encodedBucket = encodeRfc3986(config.bucketName);
  const copySource = `/${encodedBucket}/${encodeObjectPath(remoteSource)}`;
  const target = bucketUrl(config, remoteDest);
  const response = await signedFetch(config, {
    method: 'PUT',
    url: target.url,
    canonicalPath: target.canonicalPath,
    headers: { 'x-amz-copy-source': copySource },
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

// Renames remote objects by copying each source key to its new key and then
// deleting the originals. Copies are performed first; if any copy fails the
// already-created copies are rolled back so the original keys stay authoritative
// (never a half-renamed state). The final deletes are best-effort cleanup: once
// every copy has succeeded the new keys are already serving the file, so a
// failed delete only leaves an orphaned old object rather than breaking the file.
export async function renameRemoteStorageFile(
  settings: StorageSettings,
  input: {
    type: StorageType;
    replacements: Array<{ oldId: string; newId: string }>;
  },
) {
  const config = requireS3CompatibleConfig(settings);
  const copied: Array<{ oldObjectPath: string; newObjectPath: string }> = [];

  try {
    for (const { oldId, newId } of input.replacements) {
      if (!oldId || !newId || oldId === newId) continue;
      const oldObjectPath = objectPathFor(input.type, oldId);
      const newObjectPath = objectPathFor(input.type, newId);
      const result = await copyRemoteObject(config, oldObjectPath, newObjectPath);
      if (!result.ok) {
        // The source is frequently a local-only image variant that was never
        // pushed to the remote bucket; treat "missing source" as a skip.
        if (result.status === 404 || /NoSuchKey|does not exist/i.test(result.text)) continue;
        throw Object.assign(
          new Error(result.text || `${config.provider} copy failed`),
          { status: result.status || 500 },
        );
      }
      copied.push({ oldObjectPath, newObjectPath });
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

  for (const { oldObjectPath } of copied) {
    await deleteRemoteObject(config, oldObjectPath).catch((error) => {
      console.warn(
        'Remote rename old object cleanup skipped:',
        oldObjectPath,
        error instanceof Error ? error.message : error,
      );
    });
  }

  return { success: true, renamed: copied.length };
}

// Lightweight existence check (HEAD) used to pick a collision-free key before a
// rename so an SEO name never silently overwrites a different object.
export async function remoteObjectExists(
  settings: StorageSettings,
  type: StorageType,
  id: string,
) {
  const config = requireS3CompatibleConfig(settings);
  const objectPath = objectPathFor(type, id);
  const target = bucketUrl(config, providerObjectPath(config, objectPath));
  const response = await signedFetch(config, {
    method: 'HEAD',
    url: target.url,
    canonicalPath: target.canonicalPath,
  });
  await response.arrayBuffer().catch(() => undefined);
  return response.status >= 200 && response.status < 300;
}
