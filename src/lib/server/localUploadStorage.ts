import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';
import type { StorageType } from './supabaseStorage';
import { readRuntimeEnv } from './runtimeEnv';

export const LOCAL_STATIC_PREFIX = '/local-upload/';
export const LOCAL_STATIC_CACHE = 'public, max-age=86400, stale-while-revalidate=604800';

function resolveProjectRoot() {
  const moduleRoot = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '../../..');
  const candidates = [
    readRuntimeEnv('PATEEZNEWS_PROJECT_ROOT'),
    readRuntimeEnv('INIT_CWD'),
    readRuntimeEnv('PWD'),
    moduleRoot,
    '/Users/nasip/Desktop/pateeznews',
    process.cwd(),
  ].filter(Boolean) as string[];

  for (const candidate of candidates) {
    const root = path.resolve(candidate);
    if (fs.existsSync(path.join(root, 'public', 'local-upload'))) return root;
    if (fs.existsSync(path.join(root, 'package.json')) && fs.existsSync(path.join(root, 'public'))) return root;
  }

  return process.cwd();
}

export const LOCAL_UPLOAD_ROOT = path.resolve(resolveProjectRoot(), 'public', 'local-upload');

const LOCAL_FALLBACKS: Partial<Record<StorageType, string[]>> = {
  image: ['image/fallback/pateez-news-placeholder.webp'],
  logo: [
    'logo/tr/pateezlogoson.png',
    'logo/tr/pateezlogowhite.png',
    'logo/tr/pateezlogoicon.png',
  ],
  profile: [
    'profile/6c1a27d3-ce8e-4c42-bec1-fc092139e3ee-avatar.webp',
    'profile/nasip-avatar.webp',
  ],
};

const VIDEO_THUMB_EXTENSIONS = ['.webp', '.jpg', '.jpeg', '.png'];

export interface LocalUploadItem {
  id: string;
  value: string;
  size: number;
  date: number;
  type: StorageType;
  src: string;
  thumb: string;
  publicSrc: string;
  path: string;
  provider: 'local';
}

function isInside(baseDir: string, targetPath: string) {
  const relative = path.relative(baseDir, targetPath);
  return relative === '' || (!!relative && !relative.startsWith('..') && !path.isAbsolute(relative));
}

function normalizeRelativePath(input: string) {
  const normalized = path.posix.normalize(String(input || '').replace(/\\/g, '/').replace(/^\/+/, ''));
  if (!normalized || normalized === '.' || normalized.startsWith('../') || normalized.includes('/../')) {
    return '';
  }
  return normalized;
}

export function normalizeLocalRelativeId(type: StorageType, id: string) {
  const normalized = normalizeRelativePath(id);
  const prefix = `${type}/`;
  return normalized.startsWith(prefix) ? normalized.slice(prefix.length) : normalized;
}

export function localObjectPath(type: StorageType, id: string) {
  const relativeId = normalizeLocalRelativeId(type, id);
  if (!relativeId) throw new Error('Invalid local storage path');
  return `${type}/${relativeId}`;
}

export function localPublicPath(type: StorageType, id: string) {
  return `${LOCAL_STATIC_PREFIX}${localObjectPath(type, id)}`;
}

export function localApiPath(type: StorageType, id: string) {
  return `/api/storage/file/${type}/${normalizeLocalRelativeId(type, id)}`;
}

export function resolveLocalUploadPath(type: StorageType, id: string) {
  const relativeId = normalizeLocalRelativeId(type, id);
  if (!relativeId) return null;
  const baseDir = path.resolve(LOCAL_UPLOAD_ROOT, type);
  const absolutePath = path.resolve(baseDir, relativeId);
  if (!isInside(baseDir, absolutePath)) return null;
  return {
    relativeId,
    objectPath: `${type}/${relativeId}`,
    absolutePath,
    baseDir,
  };
}

function resolveLocalObjectPath(objectPath: string) {
  const normalized = normalizeRelativePath(objectPath);
  if (!normalized) return null;
  const absolutePath = path.resolve(LOCAL_UPLOAD_ROOT, normalized);
  if (!isInside(LOCAL_UPLOAD_ROOT, absolutePath)) return null;
  return { objectPath: normalized, absolutePath };
}

export function exactLocalStaticPath(objectPath: string) {
  const resolved = resolveLocalObjectPath(objectPath);
  if (!resolved || !fs.existsSync(resolved.absolutePath)) return null;
  const stat = fs.statSync(resolved.absolutePath);
  if (!stat.isFile()) return null;
  return `${LOCAL_STATIC_PREFIX}${resolved.objectPath}`;
}

export function exactLocalStaticPathForRequest(pathname: string) {
  const normalized = normalizeRelativePath(pathname)
    .replace(/^api\/storage\/file\//, '')
    .replace(/^local-upload\//, '');
  return exactLocalStaticPath(normalized);
}

export function localStaticPath(type: StorageType, objectPath: string) {
  const exact = exactLocalStaticPath(objectPath);
  if (exact) return exact;
  for (const fallback of LOCAL_FALLBACKS[type] || []) {
    const fallbackPath = exactLocalStaticPath(fallback);
    if (fallbackPath) return fallbackPath;
  }
  return null;
}

export async function writeLocalUploadFile(type: StorageType, id: string, buffer: Buffer) {
  const resolved = resolveLocalUploadPath(type, id);
  if (!resolved) throw new Error('Invalid local storage path');
  await fs.promises.mkdir(path.dirname(resolved.absolutePath), { recursive: true });
  await fs.promises.writeFile(resolved.absolutePath, buffer);
  return resolved;
}

function videoThumbRelativeIds(relativeId: string) {
  const parsed = path.posix.parse(relativeId);
  return VIDEO_THUMB_EXTENSIONS.map((extension) =>
    `${parsed.dir ? `${parsed.dir}/` : ''}${parsed.name}_thumb${extension}`
  );
}

export async function deleteLocalUploadFiles(type: StorageType, id: string) {
  const ids = [normalizeLocalRelativeId(type, id)];
  if (type === 'video') ids.push(...videoThumbRelativeIds(ids[0]));

  const deleted: string[] = [];
  for (const relativeId of ids.filter(Boolean)) {
    const resolved = resolveLocalUploadPath(type, relativeId);
    if (!resolved) continue;
    try {
      await fs.promises.unlink(resolved.absolutePath);
      deleted.push(relativeId);
    } catch (error: any) {
      if (error?.code !== 'ENOENT') throw error;
    }
  }
  return deleted;
}

function localDateFromPath(relativeId: string) {
  const match = relativeId.match(/(?:^|\/)(\d{4}-\d{2}-\d{2})(?:\/|$)/);
  if (!match) return 0;
  const time = new Date(`${match[1]}T00:00:00Z`).getTime();
  return Number.isFinite(time) ? Math.floor(time / 1000) : 0;
}

function isVideoThumb(relativeId: string) {
  const parsed = path.posix.parse(relativeId);
  return parsed.name.endsWith('_thumb') && VIDEO_THUMB_EXTENSIONS.includes(parsed.ext.toLowerCase());
}

function walkFiles(baseDir: string, currentDir = baseDir): string[] {
  if (!fs.existsSync(currentDir)) return [];
  const entries = fs.readdirSync(currentDir, { withFileTypes: true });
  return entries.flatMap((entry) => {
    const fullPath = path.join(currentDir, entry.name);
    if (entry.isDirectory()) return walkFiles(baseDir, fullPath);
    if (!entry.isFile()) return [];
    return path.relative(baseDir, fullPath).split(path.sep).join('/');
  });
}

function videoThumbFor(type: StorageType, relativeId: string) {
  if (type !== 'video') return relativeId;
  for (const thumbId of videoThumbRelativeIds(relativeId)) {
    const resolved = resolveLocalUploadPath(type, thumbId);
    if (resolved && fs.existsSync(resolved.absolutePath)) return thumbId;
  }
  return relativeId;
}

function isLocalUploadItem(item: LocalUploadItem | null): item is LocalUploadItem {
  return item !== null;
}

export function localUploadItemsForType(type: StorageType): LocalUploadItem[] {
  const baseDir = path.resolve(LOCAL_UPLOAD_ROOT, type);
  return walkFiles(baseDir)
    .filter((relativeId) => !(type === 'video' && isVideoThumb(relativeId)))
    .map((relativeId) => {
      const resolved = resolveLocalUploadPath(type, relativeId);
      if (!resolved) return null;
      const stat = fs.statSync(resolved.absolutePath);
      const parsed = path.posix.parse(relativeId);
      const thumbId = videoThumbFor(type, relativeId);
      const src = localApiPath(type, relativeId);
      return {
        id: relativeId,
        value: parsed.base,
        size: stat.size,
        date: localDateFromPath(relativeId) || Math.floor(stat.mtimeMs / 1000),
        type,
        src,
        thumb: localApiPath(type, thumbId),
        publicSrc: localPublicPath(type, relativeId),
        path: parsed.dir,
        provider: 'local' as const,
      };
    })
    .filter(isLocalUploadItem);
}
