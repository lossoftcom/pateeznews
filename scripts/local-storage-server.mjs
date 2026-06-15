#!/usr/bin/env node
import fs from 'node:fs';
import http from 'node:http';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import crypto from 'node:crypto';
import { spawn } from 'node:child_process';
import multiparty from 'multiparty';
import sharp from 'sharp';
import ffmpegStaticPath from 'ffmpeg-static';

const PORT = Number(process.env.PATEEZ_LOCAL_STORAGE_PORT || 4322);
const PROJECT_ROOT = process.env.PATEEZNEWS_PROJECT_ROOT ||
  path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const ROOT = path.resolve(PROJECT_ROOT, 'public', 'local-upload');
const TYPES = new Set(['image', 'video', 'audio', 'file', 'logo', 'profile', 'font']);
const IMAGE_TYPES = new Set(['image', 'profile']);
const IMAGE_EXTENSIONS = new Set(['.jpg', '.jpeg', '.png', '.webp', '.gif', '.avif', '.tif', '.tiff', '.svg']);
const IMAGE_VARIANT_SUFFIXES = ['_sm', '_xl', '_md', '_lg'];
const THUMB_EXTENSIONS = ['.webp', '.jpg', '.jpeg', '.png'];
const IMAGE_VARIANT_WIDTHS = [180, 260, 800, 900, 1200, 1440, 1600];
const IMAGE_VARIANT_QUALITY = 86;
const VARIANT_ROOT = path.resolve(ROOT, '.variants');
const FFMPEG_BIN = process.env.FFMPEG_PATH || ffmpegStaticPath || 'ffmpeg';
const VIDEO_THUMB_MAX_DIMENSION = 1280;
const VIDEO_THUMB_QUALITY = 80;
const VIDEO_THUMB_TIMEOUT_MS = 22000;
const VIDEO_THUMB_MAX_FRAME_BYTES = 64 * 1024 * 1024;
const VIDEO_EXTENSIONS = new Set(['.3gp', '.avi', '.m4v', '.mkv', '.mov', '.mp4', '.webm']);

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

async function renameImageVariants(type, oldId, newId) {
  if (!IMAGE_TYPES.has(type)) return;
  const oldVariants = imageVariantIds(type, oldId);
  const newVariants = imageVariantIds(type, newId);
  await Promise.all(oldVariants.map(async ({ id: oldVariantId }, index) => {
    const newVariantId = newVariants[index]?.id;
    if (!newVariantId) return;
    const oldPath = resolveVariantPath(oldVariantId);
    const newPath = resolveVariantPath(newVariantId);
    if (!oldPath || !newPath) return;
    if (!fs.existsSync(oldPath)) return;
    await fs.promises.mkdir(path.dirname(newPath), { recursive: true });
    if (fs.existsSync(newPath)) {
      await fs.promises.unlink(newPath).catch((error) => {
        if (error?.code !== 'ENOENT') throw error;
      });
    }
    await fs.promises.rename(oldPath, newPath);
  }));
}

function stripKnownVariant(baseName) {
  for (const suffix of IMAGE_VARIANT_SUFFIXES) {
    if (baseName.toLowerCase().endsWith(suffix)) {
      return {
        rootBase: baseName.slice(0, -suffix.length),
        variant: baseName.slice(-suffix.length),
      };
    }
  }
  return { rootBase: baseName, variant: '' };
}

function escapeRegExp(value) {
  return String(value).replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
}

function normalizeStorageId(type, id) {
  return normalizePath(id)
    .replace(/^api\/storage\/file\//, '')
    .replace(/^local-upload\//, '')
    .replace(new RegExp(`^${type}/`), '');
}

function basenameEquals(left, right) {
  const a = String(left || '').normalize('NFC');
  const b = String(right || '').normalize('NFC');
  return a === b || a.normalize('NFD') === b.normalize('NFD');
}

function getCandidateId(type, id) {
  const base = path.resolve(ROOT, type);
  const normalizedId = normalizeStorageId(type, id);
  const candidates = [
    normalizedId,
    normalizedId.normalize('NFC'),
    normalizedId.normalize('NFD'),
  ];
  for (const candidate of [...new Set(candidates)]) {
    const resolved = resolveUploadPath(type, candidate);
    if (!resolved || !inside(base, resolved.absolutePath)) continue;
    if (fs.existsSync(resolved.absolutePath) && fs.statSync(resolved.absolutePath).isFile()) {
      return candidate;
    }
  }

  const fileName = path.posix.basename(normalizedId);
  if (fileName) {
    const matches = walk(base).filter((candidate) => basenameEquals(path.posix.basename(candidate), fileName));
    if (matches.length === 1) return matches[0];
    if (matches.length > 1) {
      const error = new Error('Multiple local media files match this filename');
      error.status = 409;
      throw error;
    }
  }
  return '';
}

function collectRenameTargets(type, fileId) {
  const resolved = resolveUploadPath(type, fileId);
  if (!resolved) return [];
  const parsed = path.posix.parse(fileId);
  const dir = parsed.dir;
  const fullDir = path.dirname(resolved.absolutePath);
  const known = stripKnownVariant(parsed.name);
  const targets = new Map();
  targets.set(fileId, {
    id: fileId,
    variant: known.variant,
    ext: parsed.ext,
  });

  if (IMAGE_TYPES.has(type) && fs.existsSync(fullDir) && fs.statSync(fullDir).isDirectory()) {
    const siblingRegex = new RegExp(`^${escapeRegExp(known.rootBase)}(?:_sm|_xl|_md|_lg)?\\.[^.]+$`, 'i');
    for (const entry of fs.readdirSync(fullDir, { withFileTypes: true })) {
      if (!entry.isFile() || !siblingRegex.test(entry.name)) continue;
      const siblingParsed = path.posix.parse(entry.name);
      const siblingKnown = stripKnownVariant(siblingParsed.name);
      const siblingId = dir ? `${dir}/${entry.name}` : entry.name;
      targets.set(siblingId, {
        id: siblingId,
        variant: siblingKnown.variant,
        ext: siblingParsed.ext,
      });
    }
  }

  if (type === 'video' && fs.existsSync(fullDir) && fs.statSync(fullDir).isDirectory()) {
    const thumbRegex = new RegExp(`^${escapeRegExp(parsed.name)}_thumb\\.(webp|jpe?g|png)$`, 'i');
    for (const entry of fs.readdirSync(fullDir, { withFileTypes: true })) {
      if (!entry.isFile() || !thumbRegex.test(entry.name)) continue;
      const siblingParsed = path.posix.parse(entry.name);
      const siblingId = dir ? `${dir}/${entry.name}` : entry.name;
      targets.set(siblingId, {
        id: siblingId,
        variant: '_thumb',
        ext: siblingParsed.ext,
      });
    }
  }

  return [...targets.values()];
}

function seoBase(value) {
  const base = normalizePath(value)
    .split('/')
    .pop()
    .replace(/\.[a-z0-9]{2,8}$/i, '')
    .toLowerCase()
    .replace(/[^a-z0-9-]+/g, '-')
    .replace(/^-+|-+$/g, '')
    .replace(/-{2,}/g, '-')
    .slice(0, 90)
    .replace(/-+$/g, '');
  return base || `haber-medyasi-${Date.now()}`;
}

function chooseUniqueBase(type, targets, requestedBase) {
  const oldIds = new Set(targets.map((target) => target.id));
  const baseDir = path.resolve(ROOT, type);

  for (let attempt = 0; attempt < 100; attempt++) {
    const suffix = attempt === 0 ? '' : `-${attempt + 1}`;
    const candidateBase = `${requestedBase}${suffix}`;
    const conflicts = targets.some((target) => {
      const parsed = path.posix.parse(target.id);
      const ext = (target.ext || '').toLowerCase() || (type === 'video' ? '.mp4' : '.webp');
      const newId = `${parsed.dir ? `${parsed.dir}/` : ''}${candidateBase}${target.variant}${ext}`;
      const fullPath = path.resolve(baseDir, newId);
      return !oldIds.has(newId) && fs.existsSync(fullPath);
    });
    if (!conflicts) return candidateBase;
  }

  return `${requestedBase}-${Date.now()}`;
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

function cleanYoutubeId(value) {
  const match = String(value || '').match(/[_\-a-zA-Z0-9]{11}/);
  return match?.[0] || '';
}

function youtubeIdFrom(value) {
  try {
    const parsed = new URL(String(value || '').trim(), 'https://example.invalid');
    const host = parsed.hostname.toLowerCase();
    if (!host.includes('youtube.com') && !host.includes('youtu.be') && !host.includes('youtube-nocookie.com')) {
      return '';
    }
    if (host.includes('youtu.be')) return cleanYoutubeId(parsed.pathname.split('/').filter(Boolean)[0]);
    const queryId = cleanYoutubeId(parsed.searchParams.get('v') || '');
    if (queryId) return queryId;
    const segments = parsed.pathname.split('/').filter(Boolean);
    for (let index = 0; index < segments.length - 1; index += 1) {
      const segment = segments[index].toLowerCase();
      if (segment === 'shorts' || segment === 'embed' || segment === 'live') {
        return cleanYoutubeId(segments[index + 1]);
      }
    }
  } catch {
    return '';
  }
  return '';
}

function youtubeThumbUrl(value) {
  const id = youtubeIdFrom(value);
  return id ? `https://img.youtube.com/vi/${id}/hqdefault.jpg` : '';
}

function safeDecodePath(value) {
  try {
    return decodeURIComponent(value);
  } catch {
    return value;
  }
}

function localVideoIdFromUrl(value) {
  try {
    const parsed = new URL(String(value || '').trim(), 'http://127.0.0.1');
    const decoded = safeDecodePath(parsed.pathname);
    if (decoded.startsWith('/api/storage/file/video/')) {
      return normalizePath(decoded.slice('/api/storage/file/video/'.length));
    }
    if (decoded.startsWith('/local-upload/video/')) {
      return normalizePath(decoded.slice('/local-upload/video/'.length));
    }
  } catch {
    return '';
  }
  return '';
}

function seoSlug(value, fallback = 'video-thumb') {
  const slug = String(value || '')
    .normalize('NFKD')
    .replace(/[\u0300-\u036f]/g, '')
    .replace(/[ıİ]/g, 'i')
    .replace(/[ğĞ]/g, 'g')
    .replace(/[üÜ]/g, 'u')
    .replace(/[şŞ]/g, 's')
    .replace(/[öÖ]/g, 'o')
    .replace(/[çÇ]/g, 'c')
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, '-')
    .replace(/^-+|-+$/g, '')
    .slice(0, 72)
    .replace(/-+$/g, '');
  return slug || fallback;
}

function remoteVideoThumbId(videoUrl, title = '') {
  let sourceName = title;
  try {
    const parsed = new URL(videoUrl);
    sourceName = sourceName || path.posix.parse(safeDecodePath(parsed.pathname)).name || parsed.hostname;
  } catch {
    sourceName = sourceName || 'uzak-video';
  }
  const hash = crypto.createHash('sha256').update(videoUrl).digest('hex').slice(0, 12);
  return `remote-thumbs/${seoSlug(sourceName)}-${hash}_thumb.webp`;
}

function isLikelyDirectVideoUrl(value) {
  try {
    const parsed = new URL(value);
    if (parsed.protocol !== 'http:' && parsed.protocol !== 'https:') return false;
    if (youtubeIdFrom(value)) return false;
    return VIDEO_EXTENSIONS.has(path.posix.extname(parsed.pathname).toLowerCase()) || parsed.pathname.includes('/video/');
  } catch {
    return false;
  }
}

function captureVideoFrame(input, { remote = false, seek = '00:00:01.000' } = {}) {
  return new Promise((resolve, reject) => {
    const args = ['-hide_banner', '-loglevel', 'error', '-y'];
    if (remote) args.push('-user_agent', 'PateezNewsAdmin/1.0');
    args.push(
      '-ss', seek,
      '-i', input,
      '-map', '0:v:0',
      '-frames:v', '1',
      '-an',
      '-f', 'image2pipe',
      '-vcodec', 'png',
      'pipe:1',
    );

    const child = spawn(FFMPEG_BIN, args, { stdio: ['ignore', 'pipe', 'pipe'] });
    const chunks = [];
    const errors = [];
    let total = 0;
    let killedForSize = false;
    const timeout = setTimeout(() => child.kill('SIGKILL'), VIDEO_THUMB_TIMEOUT_MS);

    child.stdout.on('data', (chunk) => {
      total += chunk.length;
      if (total > VIDEO_THUMB_MAX_FRAME_BYTES) {
        killedForSize = true;
        child.kill('SIGKILL');
        return;
      }
      chunks.push(chunk);
    });
    child.stderr.on('data', (chunk) => errors.push(chunk));
    child.on('error', (error) => {
      clearTimeout(timeout);
      reject(error);
    });
    child.on('close', (code) => {
      clearTimeout(timeout);
      if (killedForSize) {
        reject(new Error('Video frame is too large'));
        return;
      }
      const output = Buffer.concat(chunks);
      if (code === 0 && output.length > 0) {
        resolve(output);
        return;
      }
      reject(new Error(Buffer.concat(errors).toString('utf8').trim() || `ffmpeg exited with ${code}`));
    });
  });
}

async function extractVideoFrame(input, options = {}) {
  try {
    return await captureVideoFrame(input, options);
  } catch (firstError) {
    if (options.seek === '00:00:00.000') throw firstError;
    return captureVideoFrame(input, { ...options, seek: '00:00:00.000' });
  }
}

async function writeVideoThumbFromInput(input, thumbId, options = {}) {
  const resolved = resolveUploadPath('video', thumbId);
  if (!resolved) return '';
  const frame = await extractVideoFrame(input, options);
  const thumbBuffer = await sharp(frame, { animated: false, failOn: 'none' })
    .rotate()
    .resize({
      width: VIDEO_THUMB_MAX_DIMENSION,
      height: VIDEO_THUMB_MAX_DIMENSION,
      fit: 'inside',
      withoutEnlargement: true,
      kernel: 'lanczos3',
    })
    .webp({
      quality: VIDEO_THUMB_QUALITY,
      alphaQuality: 90,
      effort: 5,
      smartSubsample: true,
      preset: 'photo',
    })
    .toBuffer();
  await fs.promises.mkdir(path.dirname(resolved.absolutePath), { recursive: true });
  await fs.promises.writeFile(resolved.absolutePath, thumbBuffer);
  return resolved.relativeId;
}

async function ensureLocalVideoThumb(id) {
  const relativeId = normalizePath(id);
  if (!relativeId) return '';
  for (const candidate of videoThumbIds(relativeId)) {
    const resolvedThumb = resolveUploadPath('video', candidate);
    if (resolvedThumb && fs.existsSync(resolvedThumb.absolutePath)) return candidate;
  }
  const resolvedVideo = resolveUploadPath('video', relativeId);
  if (!resolvedVideo || !fs.existsSync(resolvedVideo.absolutePath)) return '';
  return writeVideoThumbFromInput(resolvedVideo.absolutePath, videoThumbIds(relativeId)[0]);
}

function isVideoThumb(id) {
  const parsed = path.posix.parse(id);
  return parsed.name.endsWith('_thumb') && THUMB_EXTENSIONS.includes(parsed.ext.toLowerCase());
}

function uploadDate(stat) {
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
        date: uploadDate(stat),
        type,
        src: localApiPath(type, id),
        thumb: localApiPath(type, thumbId),
        publicSrc: localPublicPath(type, id),
        path: parsed.dir,
        provider: 'local',
      };
    })
    .filter(Boolean)
    .sort((a, b) => b.date - a.date || String(b.id).localeCompare(String(a.id)));
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
  let thumbId = relativeId;
  if (type === 'video') {
    try {
      thumbId = await ensureLocalVideoThumb(relativeId) || relativeId;
    } catch (error) {
      console.warn('Video thumbnail generation skipped:', error?.message || error);
    }
  }

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
  const thumb = localApiPath(type, thumbId);
  return json(res, 200, {
    id: relativeId,
    value: finalFilename,
    src,
    publicSrc,
    thumb,
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

async function resolveVideoThumb(req, res) {
  const body = JSON.parse(await readBody(req) || '{}');
  const videoUrl = String(body.url || body.videoUrl || '').trim();
  const title = String(body.title || body.context || '').trim();
  if (!videoUrl) return json(res, 400, { error: 'Video URL required' });

  const youtubeThumb = youtubeThumbUrl(videoUrl);
  if (youtubeThumb) {
    return json(res, 200, {
      success: true,
      thumb: youtubeThumb,
      provider: 'youtube',
    });
  }

  const localId = localVideoIdFromUrl(videoUrl);
  if (localId) {
    const thumbId = await ensureLocalVideoThumb(localId).catch((error) => {
      console.warn('Local video thumbnail skipped:', error?.message || error);
      return '';
    });
    return json(res, 200, {
      success: Boolean(thumbId),
      thumb: thumbId ? localApiPath('video', thumbId) : '',
      provider: 'local',
    });
  }

  if (!isLikelyDirectVideoUrl(videoUrl)) {
    return json(res, 200, {
      success: false,
      thumb: '',
      provider: 'remote',
    });
  }

  const thumbId = remoteVideoThumbId(videoUrl, title);
  const existing = resolveUploadPath('video', thumbId);
  if (existing && fs.existsSync(existing.absolutePath)) {
    return json(res, 200, {
      success: true,
      thumb: localApiPath('video', thumbId),
      provider: 'remote',
    });
  }

  const generatedId = await writeVideoThumbFromInput(videoUrl, thumbId, {
    remote: true,
  }).catch((error) => {
    console.warn('Remote video thumbnail skipped:', error?.message || error);
    return '';
  });

  return json(res, 200, {
    success: Boolean(generatedId),
    thumb: generatedId ? localApiPath('video', generatedId) : '',
    provider: 'remote',
  });
}

async function renameStoredFile(req, res) {
  const body = JSON.parse(await readBody(req) || '{}');
  const type = storageType(body.type);
  const candidateId = getCandidateId(type, body.id);
  if (!candidateId) return json(res, 404, { error: 'File not found' });

  const targets = collectRenameTargets(type, candidateId);
  if (!targets.length) return json(res, 404, { error: 'File not found' });

  const uniqueBase = chooseUniqueBase(type, targets, seoBase(body.newBase || body.filename));
  const replacements = [];
  for (const target of targets) {
    const parsed = path.posix.parse(target.id);
    const ext = (target.ext || '').toLowerCase() || (type === 'video' ? '.mp4' : '.webp');
    const newFileName = `${uniqueBase}${target.variant}${ext}`;
    const newId = parsed.dir ? `${parsed.dir}/${newFileName}` : newFileName;
    if (target.id === newId) continue;

    const oldResolved = resolveUploadPath(type, target.id);
    const newResolved = resolveUploadPath(type, newId);
    if (!oldResolved || !newResolved) continue;
    if (!fs.existsSync(oldResolved.absolutePath)) continue;

    await fs.promises.mkdir(path.dirname(newResolved.absolutePath), { recursive: true });
    await fs.promises.rename(oldResolved.absolutePath, newResolved.absolutePath);
    await renameImageVariants(type, target.id, newId);

    const stat = await fs.promises.stat(newResolved.absolutePath);
    const parsedNew = path.posix.parse(newId);
    replacements.push({
      oldId: target.id,
      newId,
      oldSrc: localApiPath(type, target.id),
      newSrc: localApiPath(type, newId),
      oldPublicSrc: localPublicPath(type, target.id),
      newPublicSrc: localPublicPath(type, newId),
      value: parsedNew.base,
      path: parsedNew.dir,
      size: stat.size,
      contentType: contentTypeForFilename(newId),
      thumb: localApiPath(type, newId),
      type,
      provider: 'local',
    });
  }

  const selected = replacements.find((item) => item.oldId === candidateId) || replacements[0] || null;
  return json(res, 200, {
    success: true,
    filename: uniqueBase,
    src: selected?.newSrc || localApiPath(type, candidateId),
    replacements,
  });
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
    if (req.method === 'POST' && url.pathname === '/api/local-storage/video-thumb') return resolveVideoThumb(req, res);
    if (req.method === 'POST' && url.pathname === '/api/local-storage/rename') return renameStoredFile(req, res);
    if (req.method === 'DELETE' && url.pathname === '/api/local-storage/delete') return remove(req, res);
    return json(res, 404, { error: 'Not found' });
  } catch (error) {
    console.error('Local storage server error:', error);
    const status = Number(error?.status || 500);
    return json(res, status >= 400 && status < 600 ? status : 500, {
      error: error?.message || 'Local storage server error',
    });
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
