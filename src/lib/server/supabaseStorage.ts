import { createClient, type SupabaseClient } from '@supabase/supabase-js';
import { readRuntimeEnv } from './runtimeEnv';

export const MEDIA_BUCKET = 'media';

export const STORAGE_TYPES = ['image', 'video', 'audio', 'file', 'logo', 'profile', 'font'] as const;
export type StorageType = typeof STORAGE_TYPES[number];

function readEnv(name: string) {
  return readRuntimeEnv(name);
}

function deriveSupabaseUrlFromDatabaseUrl() {
  const databaseUrl = readEnv('SUPABASE_DATABASE_URL') || readEnv('DATABASE_URL') || readEnv('POSTGRES_URL');
  if (!databaseUrl) return '';
  try {
    const parsed = new URL(databaseUrl);
    const match = parsed.hostname.match(/^db\.([a-z0-9-]+)\.supabase\.co$/i);
    return match ? `https://${match[1]}.supabase.co` : '';
  } catch {
    return '';
  }
}

function getSupabaseStorageUrl() {
  const url = (
    readEnv('SUPABASE_URL') ||
    readEnv('PUBLIC_SUPABASE_URL') ||
    deriveSupabaseUrlFromDatabaseUrl()
  ).replace(/\/$/, '');
  if (!url) {
    throw new Error('SUPABASE_URL is required for Supabase Storage');
  }
  return url;
}

export function getSupabaseStorageConfig() {
  const url = getSupabaseStorageUrl();

  const publishableKey =
    readEnv('SUPABASE_PUBLISHABLE_KEY') ||
    readEnv('PUBLIC_SUPABASE_PUBLISHABLE_KEY');

  if (!publishableKey) {
    throw new Error('SUPABASE_PUBLISHABLE_KEY is required for Supabase Storage');
  }

  return { url, publishableKey };
}

function bearerFromRequest(request: Request) {
  const header = request.headers.get('authorization') || '';
  return header.match(/^Bearer\s+(.+)$/i)?.[1]?.trim() || '';
}

export function storageClientForRequest(request: Request): SupabaseClient {
  const { url, publishableKey } = getSupabaseStorageConfig();
  const bearer = bearerFromRequest(request);

  return createClient(url, publishableKey, {
    auth: {
      persistSession: false,
      autoRefreshToken: false,
      detectSessionInUrl: false,
    },
    global: {
      headers: {
        Authorization: `Bearer ${bearer || publishableKey}`,
      },
    },
  });
}

export function adminStorageClient(): SupabaseClient {
  const url = getSupabaseStorageUrl();
  const serviceRoleKey = readEnv('SUPABASE_SERVICE_ROLE_KEY');
  if (!serviceRoleKey) {
    throw new Error('SUPABASE_SERVICE_ROLE_KEY is required for admin storage writes');
  }

  return createClient(url, serviceRoleKey, {
    auth: {
      persistSession: false,
      autoRefreshToken: false,
      detectSessionInUrl: false,
    },
    global: {
      headers: {
        Authorization: `Bearer ${serviceRoleKey}`,
      },
    },
  });
}

export function getStorageType(value: unknown): StorageType {
  return typeof value === 'string' && STORAGE_TYPES.includes(value as StorageType)
    ? value as StorageType
    : 'image';
}

export function safeDecode(value: string) {
  let decoded = value;
  for (let i = 0; i < 3; i++) {
    try {
      const next = decodeURIComponent(decoded);
      if (next === decoded) break;
      decoded = next;
    } catch {
      break;
    }
  }
  return decoded;
}

export function normalizeStoragePath(value: string) {
  return safeDecode(value)
    .replace(/\\/g, '/')
    .replace(/^\/+/, '')
    .replace(/^Upload\//i, '')
    .replace(/\0/g, '')
    .split('/')
    .filter((part) => part && part !== '.' && part !== '..')
    .join('/');
}

export function storageObjectPath(type: StorageType, id: string) {
  const normalized = normalizeStoragePath(id);
  if (!normalized) throw new Error('Storage object path is required');
  const firstSegment = normalized.split('/')[0];
  if (STORAGE_TYPES.includes(firstSegment as StorageType)) return normalized;
  return `${type}/${normalized}`;
}

export function relativeStorageId(type: StorageType, objectPath: string) {
  const prefix = `${type}/`;
  return objectPath.startsWith(prefix) ? objectPath.slice(prefix.length) : objectPath;
}

function encodePath(path: string) {
  return path.split('/').map(encodeURIComponent).join('/');
}

export function publicStorageUrl(objectPath: string, request?: Request, options?: { width?: number | null; quality?: number | null }) {
  const url = getSupabaseStorageUrl();
  const base = `${url}/storage/v1`;
  const encodedPath = encodePath(normalizeStoragePath(objectPath));
  const useImageRender = options?.width || options?.quality;
  const publicUrl = useImageRender
    ? `${base}/render/image/public/${MEDIA_BUCKET}/${encodedPath}`
    : `${base}/object/public/${MEDIA_BUCKET}/${encodedPath}`;
  const parsed = new URL(publicUrl);
  if (options?.width) parsed.searchParams.set('width', String(options.width));
  if (options?.quality) parsed.searchParams.set('quality', String(options.quality));
  if (useImageRender) parsed.searchParams.set('resize', 'contain');
  if (request) {
    const source = new URL(request.url);
    for (const [key, value] of source.searchParams) {
      if (!parsed.searchParams.has(key) && key !== 'w' && key !== 'q') parsed.searchParams.set(key, value);
    }
  }
  return parsed.toString();
}

export function contentTypeForFilename(filename: string, fallback = 'application/octet-stream') {
  const ext = filename.toLowerCase().split('.').pop() || '';
  const map: Record<string, string> = {
    webp: 'image/webp',
    jpg: 'image/jpeg',
    jpeg: 'image/jpeg',
    png: 'image/png',
    gif: 'image/gif',
    ico: 'image/x-icon',
    svg: 'image/svg+xml',
    avif: 'image/avif',
    mp4: 'video/mp4',
    m4v: 'video/mp4',
    webm: 'video/webm',
    mov: 'video/quicktime',
    mp3: 'audio/mpeg',
    wav: 'audio/wav',
    ogg: 'audio/ogg',
    oga: 'audio/ogg',
    m4a: 'audio/mp4',
    aac: 'audio/aac',
    pdf: 'application/pdf',
    otf: 'font/otf',
    ttf: 'font/ttf',
    woff: 'font/woff',
    woff2: 'font/woff2',
  };
  return map[ext] || fallback;
}
