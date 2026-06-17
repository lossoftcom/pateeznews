// Media apiCallbacks for the embedded editor, backed by the Flutter admin's
// storage API (/api/storage/list, /api/storage/upload, ...) reached through the
// host bridge. The host returns plain {id, src, type} records; the editor needs
// fully-shaped resources with pixel dimensions, so we probe those in the browser
// (the storage list endpoint does not provide them).
import { createResource } from '@googleforcreators/media';

import { hostRequest } from './host.js';

const DEFAULT_IMAGE = { width: 1080, height: 1920 };
const DEFAULT_VIDEO = { width: 1080, height: 1920, length: 0 };

const EXT_MIME = {
  jpg: 'image/jpeg',
  jpeg: 'image/jpeg',
  png: 'image/png',
  gif: 'image/gif',
  webp: 'image/webp',
  avif: 'image/avif',
  svg: 'image/svg+xml',
  mp4: 'video/mp4',
  webm: 'video/webm',
  mov: 'video/quicktime',
  m4v: 'video/mp4',
};

function guessMimeType(item) {
  if (item.mimeType) return item.mimeType;
  const src = String(item.src || '');
  const ext = src.split('?')[0].split('.').pop().toLowerCase();
  if (EXT_MIME[ext]) return EXT_MIME[ext];
  return item.type === 'video' ? 'video/mp4' : 'image/jpeg';
}

function resourceType(item, mimeType) {
  if (item.type === 'video' || mimeType.startsWith('video/')) return 'video';
  return 'image';
}

// Resolve natural pixel dimensions (and video duration) from the media URL.
// Always resolves; falls back to portrait defaults if the probe fails/stalls.
function probeImage(src) {
  return new Promise((resolve) => {
    const img = new Image();
    let done = false;
    const finish = (value) => {
      if (done) return;
      done = true;
      resolve(value);
    };
    img.onload = () =>
      finish({
        width: img.naturalWidth || DEFAULT_IMAGE.width,
        height: img.naturalHeight || DEFAULT_IMAGE.height,
      });
    img.onerror = () => finish(DEFAULT_IMAGE);
    setTimeout(() => finish(DEFAULT_IMAGE), 8000);
    img.src = src;
  });
}

function probeVideo(src) {
  return new Promise((resolve) => {
    const video = document.createElement('video');
    let done = false;
    const finish = (value) => {
      if (done) return;
      done = true;
      resolve(value);
    };
    video.preload = 'metadata';
    video.muted = true;
    video.onloadedmetadata = () =>
      finish({
        width: video.videoWidth || DEFAULT_VIDEO.width,
        height: video.videoHeight || DEFAULT_VIDEO.height,
        length: Math.round(video.duration || 0),
      });
    video.onerror = () => finish(DEFAULT_VIDEO);
    setTimeout(() => finish(DEFAULT_VIDEO), 8000);
    video.src = src;
  });
}

function formatDuration(seconds) {
  const s = Math.max(0, Math.round(seconds || 0));
  const mm = Math.floor(s / 60);
  const ss = String(s % 60).padStart(2, '0');
  return `${mm}:${ss}`;
}

async function toResource(item) {
  const mimeType = guessMimeType(item);
  const type = resourceType(item, mimeType);
  const src = String(item.src || '');
  const base = {
    id: String(item.id || src),
    src,
    mimeType,
    type,
    alt: item.alt || item.value || '',
    isExternal: false,
    isOptimized: true,
  };
  if (type === 'video') {
    const dims = await probeVideo(src);
    return createResource({
      ...base,
      width: dims.width,
      height: dims.height,
      poster: item.thumb || '',
      length: dims.length,
      lengthFormatted: formatDuration(dims.length),
      isMuted: false,
    });
  }
  const dims = await probeImage(src);
  return createResource({ ...base, width: dims.width, height: dims.height });
}

// Bounded-concurrency map so a large library does not open hundreds of parallel
// probes at once.
async function mapLimit(items, limit, fn) {
  const out = new Array(items.length);
  let i = 0;
  const workers = new Array(Math.min(limit, items.length || 1))
    .fill(null)
    .map(async () => {
      while (i < items.length) {
        const index = i++;
        out[index] = await fn(items[index], index);
      }
    });
  await Promise.all(workers);
  return out;
}

// getMedia({ mediaType, searchTerm, pagingNum }) -> { data, headers }
export async function getMedia({ mediaType, searchTerm, pagingNum } = {}) {
  // The storage list endpoint returns everything in one shot, so we only answer
  // the first page and report a single page back to the editor.
  if (pagingNum && pagingNum > 1) {
    return { data: [], headers: { totalItems: 0, totalPages: 1 } };
  }
  const reply = await hostRequest('MEDIA_LIST', { mediaType: mediaType || '' });
  let items = Array.isArray(reply && reply.items) ? reply.items : [];
  const term = String(searchTerm || '').trim().toLowerCase();
  if (term) {
    items = items.filter((it) =>
      String(it.value || it.alt || it.src || '')
        .toLowerCase()
        .includes(term)
    );
  }
  const data = (await mapLimit(items, 6, toResource)).filter(Boolean);
  return { data, headers: { totalItems: data.length, totalPages: 1 } };
}

function readFileAsBase64(file) {
  return new Promise((resolve, reject) => {
    const reader = new FileReader();
    reader.onload = () => {
      const result = String(reader.result || '');
      const comma = result.indexOf(',');
      resolve(comma >= 0 ? result.slice(comma + 1) : result);
    };
    reader.onerror = () => reject(reader.error || new Error('read failed'));
    reader.readAsDataURL(file);
  });
}

// uploadMedia({ file, ... }) -> resource for the freshly uploaded file.
export async function uploadMedia(args = {}) {
  const file = args.file || args.originalFile || args;
  if (!file || typeof file.name === 'undefined') {
    throw new Error('No file to upload');
  }
  const mimeType = file.type || 'application/octet-stream';
  const type = mimeType.startsWith('video/') ? 'video' : 'image';
  const dataBase64 = await readFileAsBase64(file);
  const reply = await hostRequest(
    'MEDIA_UPLOAD',
    { fileName: file.name, mimeType, type, dataBase64 },
    { timeout: 120000 }
  );
  if (!reply || !reply.ok || !reply.item) {
    throw new Error((reply && reply.error) || 'Upload failed');
  }
  return toResource(reply.item);
}

// updateMedia(id, data) -> resolves so alt-text/metadata edits never error. The
// host persists best-effort; we don't block the editor on the result.
export async function updateMedia(id, data = {}) {
  await hostRequest('MEDIA_UPDATE', { id: String(id), data }, { timeout: 15000 });
  return {};
}

// deleteMedia(id) -> resolves once the host acknowledges.
export async function deleteMedia(id) {
  await hostRequest('MEDIA_DELETE', { id: String(id) }, { timeout: 30000 });
  return {};
}
