#!/usr/bin/env node
import fs from 'node:fs';
import http from 'node:http';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import multiparty from 'multiparty';
import sharp from 'sharp';

const PORT = Number(process.env.PATEEZ_LOCAL_STORAGE_PORT || 4322);
const PROJECT_ROOT = process.env.PATEEZNEWS_PROJECT_ROOT ||
  path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const ROOT = path.resolve(PROJECT_ROOT, 'public', 'local-upload');
const TYPES = new Set(['image', 'video', 'audio', 'file', 'logo', 'profile', 'font']);
const IMAGE_TYPES = new Set(['image', 'profile']);
const IMAGE_EXTENSIONS = new Set(['.jpg', '.jpeg', '.png', '.webp', '.gif', '.avif', '.tif', '.tiff', '.svg']);
const THUMB_EXTENSIONS = ['.webp', '.jpg', '.jpeg', '.png'];
const IMAGE_VARIANT_WIDTHS = [180, 260, 800, 900, 1200, 1440, 1600];
const IMAGE_VARIANT_QUALITY = 86;
const VARIANT_ROOT = path.resolve(ROOT, '.variants');

function json(res, status, body) {
  res.writeHead(status, {
    'Content-Type': 'application/json',
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Headers': 'authorization,content-type',
    'Access-Control-Allow-Methods': 'GET,POST,DELETE,OPTIONS',
  });
  res.end(JSON.stringify(body));
}

function normalizePath(value) {
  return String(value || '')
    .replace(/\\/g, '/')
    .replace(/^\/+/, '')
    .replace(/^Upload\//i, '')
    .replace(/\0/g, '')
    .split('/')
    .filter((part) => part && part !== '.' && part !== '..')
    .join('/');
}

function storageType(value) {
  return TYPES.has(String(value || '')) ? String(value) : 'image';
}

function sanitizeFilename(filename) {
  const normalized = String(filename || '').normalize('NFC').replace(/[^a-zA-Z0-9._-]/g, '_');
  return normalized || `upload-${Date.now()}`;
}

function todayPath() {
  const parts = new Intl.DateTimeFormat('en-CA', {
    timeZone: 'Europe/Istanbul',
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
  }).formatToParts(new Date());
  const byType = Object.fromEntries(parts.map((part) => [part.type, part.value]));
  return `${byType.year}-${byType.month}-${byType.day}`;
}

function inside(base, target) {
  const relative = path.relative(base, target);
  return relative === '' || (!!relative && !relative.startsWith('..') && !path.isAbsolute(relative));
}

function resolveUploadPath(type, id) {
  const relativeId = normalizePath(id).replace(new RegExp(`^${type}/`), '');
  if (!relativeId) return null;
  const base = path.resolve(ROOT, type);
  const absolutePath = path.resolve(base, relativeId);
  if (!inside(base, absolutePath)) return null;
  return { relativeId, absolutePath };
}

function localApiPath(type, id) {
  return `/api/storage/file/${type}/${normalizePath(id).replace(new RegExp(`^${type}/`), '')}`;
}

function localPublicPath(type, id) {
  return `/local-upload/${type}/${normalizePath(id).replace(new RegExp(`^${type}/`), '')}`;
}

function imageVariantIds(type, id) {
  const relativeId = normalizePath(id).replace(new RegExp(`^${type}/`), '');
  if (!relativeId) return [];
  const objectPath = `${type}/${relativeId}`;
  const parsed = path.posix.parse(objectPath);
  const basePath = `${parsed.dir ? `${parsed.dir}/` : ''}${parsed.name}`;
  return IMAGE_VARIANT_WIDTHS.map((width) => ({
    width,
    id: `w${width}-q${IMAGE_VARIANT_QUALITY}/${basePath}.webp`,
  }));
}

function resolveVariantPath(variantId) {
  const cleanId = normalizePath(variantId);
  if (!cleanId) return null;
  const absolutePath = path.resolve(VARIANT_ROOT, cleanId);
  if (!inside(VARIANT_ROOT, absolutePath)) return null;
  return absolutePath;
}

function contentTypeForFilename(filename, fallback = 'application/octet-stream') {
  const ext = filename.toLowerCase().split('.').pop() || '';
  return {
    webp: 'image/webp',
    jpg: 'image/jpeg',
    jpeg: 'image/jpeg',
    png: 'image/png',
    gif: 'image/gif',
    avif: 'image/avif',
    svg: 'image/svg+xml',
    mp4: 'video/mp4',
    mov: 'video/quicktime',
    webm: 'video/webm',
    mp3: 'audio/mpeg',
    wav: 'audio/wav',
    pdf: 'application/pdf',
  }[ext] || fallback;
}

function normalizeImageOutputFormat(value) {
  const normalized = String(value || '').trim().toLowerCase();
  if (normalized === 'jpg' || normalized === 'jpeg') return 'jpeg';
  if (normalized === 'png') return 'png';
  return 'webp';
}

function extensionForImageOutputFormat(format) {
  return format === 'jpeg' ? 'jpg' : format;
}

function contentTypeForImageOutputFormat(format) {
  return format === 'jpeg'
    ? 'image/jpeg'
    : format === 'png'
      ? 'image/png'
      : 'image/webp';
}

async function optimizeImage(input, outputFormat = 'webp') {
  const image = sharp(input, { animated: true });
  const metadata = await image.metadata();
  const preset = metadata.hasAlpha ? 'picture' : 'photo';
  const pipeline = sharp(input, { animated: Boolean(metadata.pages && metadata.pages > 1) })
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

async function writeImageVariants(type, id, buffer) {
  if (!IMAGE_TYPES.has(type)) return;
  await Promise.all(imageVariantIds(type, id).map(async ({ width, id: variantId }) => {
    const outputPath = resolveVariantPath(variantId);
    if (!outputPath) return;
    try {
      await fs.promises.mkdir(path.dirname(outputPath), { recursive: true });
      await sharp(buffer, { animated: false, failOn: 'none' })
        .rotate()
        .resize({
          width,
          fit: 'inside',
          withoutEnlargement: true,
          kernel: 'lanczos3',
        })
        .webp({
          quality: IMAGE_VARIANT_QUALITY,
          alphaQuality: 95,
          effort: 4,
          smartSubsample: true,
        })
        .toFile(outputPath);
    } catch (error) {
      console.warn(`Image variant skipped (${width}px):`, error?.message || error);
    }
  }));
}

async function deleteImageVariants(type, id) {
  if (!IMAGE_TYPES.has(type)) return;
  await Promise.all(imageVariantIds(type, id).map(async ({ id: variantId }) => {
    const outputPath = resolveVariantPath(variantId);
    if (!outputPath) return;
    await fs.promises.unlink(outputPath).catch((error) => {
      if (error?.code !== 'ENOENT') throw error;
    });
  }));
}

function shouldOptimize(type, filename, contentType) {
  return IMAGE_TYPES.has(type) &&
    (String(contentType || '').startsWith('image/') || IMAGE_EXTENSIONS.has(path.posix.extname(filename).toLowerCase()));
}

function walk(base, current = base) {
  if (!fs.existsSync(current)) return [];
  return fs.readdirSync(current, { withFileTypes: true }).flatMap((entry) => {
    const fullPath = path.join(current, entry.name);
    if (entry.isDirectory()) return walk(base, fullPath);
    if (!entry.isFile()) return [];
    return path.relative(base, fullPath).split(path.sep).join('/');
  });
}

function videoThumbIds(id) {
  const parsed = path.posix.parse(id);
  return THUMB_EXTENSIONS.map((ext) => `${parsed.dir ? `${parsed.dir}/` : ''}${parsed.name}_thumb${ext}`);
}

function isVideoThumb(id) {
  const parsed = path.posix.parse(id);
  return parsed.name.endsWith('_thumb') && THUMB_EXTENSIONS.includes(parsed.ext.toLowerCase());
}

function dateFromPath(id, stat) {
  const match = id.match(/(?:^|\/)(\d{4}-\d{2}-\d{2})(?:\/|$)/);
  if (match) {
    const time = new Date(`${match[1]}T00:00:00Z`).getTime();
    if (Number.isFinite(time)) return Math.floor(time / 1000);
  }
  return Math.floor(stat.mtimeMs / 1000);
}

function listItems(type) {
  const base = path.resolve(ROOT, type);
  return walk(base)
    .filter((id) => !(type === 'video' && isVideoThumb(id)))
    .map((id) => {
      const resolved = resolveUploadPath(type, id);
      if (!resolved) return null;
      const stat = fs.statSync(resolved.absolutePath);
      const parsed = path.posix.parse(id);
      const thumbId = type === 'video'
        ? videoThumbIds(id).find((candidate) => {
          const thumb = resolveUploadPath(type, candidate);
          return thumb && fs.existsSync(thumb.absolutePath);
        }) || id
        : id;
      return {
        id,
        value: parsed.base,
        size: stat.size,
        date: dateFromPath(id, stat),
        type,
        src: localApiPath(type, id),
        thumb: localApiPath(type, thumbId),
        publicSrc: localPublicPath(type, id),
        path: parsed.dir,
        provider: 'local',
      };
    })
    .filter(Boolean)
    .sort((a, b) => b.date - a.date);
}

function parseMultipart(req) {
  return new Promise((resolve, reject) => {
    const form = new multiparty.Form();
    form.parse(req, (error, fields, files) => {
      if (error) reject(error);
      else resolve({ fields, files });
    });
  });
}

function field(fields, name) {
  return fields[name]?.[0] ? String(fields[name][0]) : '';
}

async function upload(req, res) {
  const { fields, files } = await parseMultipart(req);
  const type = storageType(field(fields, 'type'));
  const file = files.file?.[0];
  if (!file) return json(res, 400, { error: 'No file uploaded' });

  let targetPrefix = normalizePath(field(fields, 'customPath') || todayPath());
  let finalFilename = sanitizeFilename(file.originalFilename || file.fieldName);
  let replaceId = normalizePath(field(fields, 'replaceId'));
  const customFilename = field(fields, 'customFilename');

  if (replaceId) {
    const firstSegment = replaceId.split('/')[0];
    if (TYPES.has(firstSegment)) replaceId = replaceId.split('/').slice(1).join('/');
    const parsed = path.posix.parse(replaceId);
    targetPrefix = parsed.dir;
    finalFilename = sanitizeFilename(parsed.base);
  } else if (customFilename) {
    const cleanName = sanitizeFilename(customFilename);
    const ext = path.posix.extname(finalFilename);
    finalFilename = path.posix.extname(cleanName) ? cleanName : `${cleanName}${ext}`;
  } else {
    finalFilename = `${Date.now()}-${finalFilename}`;
  }

  let buffer = await fs.promises.readFile(file.path);
  let contentType = file.headers?.['content-type'] || contentTypeForFilename(finalFilename);
  if (shouldOptimize(type, finalFilename, contentType)) {
    try {
      const outputFormat = normalizeImageOutputFormat(field(fields, 'imageOutputFormat'));
      buffer = await optimizeImage(buffer, outputFormat);
      finalFilename = `${path.posix.parse(finalFilename).name}.${extensionForImageOutputFormat(outputFormat)}`;
      contentType = contentTypeForImageOutputFormat(outputFormat);
    } catch (error) {
      console.warn('Image optimization skipped:', error?.message || error);
    }
  }

  const relativeId = [targetPrefix, finalFilename].filter(Boolean).join('/');
  const resolved = resolveUploadPath(type, relativeId);
  if (!resolved) return json(res, 400, { error: 'Invalid local path' });
  await fs.promises.mkdir(path.dirname(resolved.absolutePath), { recursive: true });
  await fs.promises.writeFile(resolved.absolutePath, buffer);
  await writeImageVariants(type, relativeId, buffer);

  if (replaceId && replaceId !== relativeId) {
    for (const id of [replaceId, ...(type === 'video' ? videoThumbIds(replaceId) : [])]) {
      const old = resolveUploadPath(type, id);
      if (!old) continue;
      await fs.promises.unlink(old.absolutePath).catch((error) => {
        if (error?.code !== 'ENOENT') throw error;
      });
      await deleteImageVariants(type, id);
    }
  }

  const parsed = path.posix.parse(relativeId);
  const src = localApiPath(type, relativeId);
  const publicSrc = localPublicPath(type, relativeId);
  return json(res, 200, {
    id: relativeId,
    value: finalFilename,
    src,
    publicSrc,
    thumb: src,
    type,
    path: parsed.dir,
    size: buffer.length,
    contentType,
    provider: 'local',
    objectPath: `${type}/${relativeId}`,
  });
}

async function readBody(req) {
  const chunks = [];
  for await (const chunk of req) chunks.push(chunk);
  return Buffer.concat(chunks).toString('utf8');
}

async function remove(req, res) {
  const body = JSON.parse(await readBody(req) || '{}');
  const rawId = normalizePath(body.id);
  const type = body.type ? storageType(body.type) : null;
  const types = type ? [type] : [...TYPES].filter((value) => value !== 'font');
  const deleted = [];
  for (const itemType of types) {
    const ids = [rawId, ...(itemType === 'video' ? videoThumbIds(rawId) : [])];
    const removed = [];
    for (const id of ids) {
      const resolved = resolveUploadPath(itemType, id);
      if (!resolved) continue;
      await fs.promises.unlink(resolved.absolutePath).then(() => removed.push(id)).catch((error) => {
        if (error?.code !== 'ENOENT') throw error;
      });
      await deleteImageVariants(itemType, id);
    }
    if (removed.length) deleted.push({ type: itemType, ids: removed });
  }
  return json(res, 200, { success: true, deleted, paths: deleted });
}

const server = http.createServer(async (req, res) => {
  try {
    if (req.method === 'OPTIONS') return json(res, 204, null);
    const url = new URL(req.url || '/', `http://${req.headers.host || `127.0.0.1:${PORT}`}`);
    if (req.method === 'GET' && url.pathname === '/api/local-storage/list') {
      return json(res, 200, listItems(storageType(url.searchParams.get('type'))));
    }
    if (req.method === 'POST' && url.pathname === '/api/local-storage/upload') return upload(req, res);
    if (req.method === 'DELETE' && url.pathname === '/api/local-storage/delete') return remove(req, res);
    return json(res, 404, { error: 'Not found' });
  } catch (error) {
    console.error('Local storage server error:', error);
    return json(res, 500, { error: error?.message || 'Local storage server error' });
  }
});

server.on('error', (error) => {
  if (error?.code === 'EADDRINUSE') {
    console.error(
      `Local storage server port ${PORT} is already in use. Stop the existing dev server before running npm run dev again.`,
    );
    process.exit(1);
  }
  console.error('Local storage server failed:', error);
  process.exit(1);
});

server.listen(PORT, '127.0.0.1', () => {
  console.log(`Local storage server ready at http://127.0.0.1:${PORT}`);
  console.log(`Local storage root: ${ROOT}`);
});
