// Media apiCallbacks for the embedded editor, backed by the Flutter admin's
// storage API through the host bridge.
import { createResource } from '@googleforcreators/media';

import { hostRequest } from './host.js';

const DEFAULT_IMAGE = { width: 1080, height: 1920 };
const DEFAULT_VIDEO = { width: 1080, height: 1920, length: 0 };
const DEFAULT_AUDIO = { length: 0 };
const DEFAULT_MEDIA_TYPES = ['image', 'video', 'audio'];

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
  mp3: 'audio/mpeg',
  wav: 'audio/wav',
  ogg: 'audio/ogg',
  oga: 'audio/ogg',
  m4a: 'audio/mp4',
  aac: 'audio/aac',
  flac: 'audio/flac',
  opus: 'audio/opus',
};

function guessMimeType(item) {
  if (item.mimeType) return item.mimeType;
  const src = String(item.src || '');
  const ext = src.split('?')[0].split('.').pop().toLowerCase();
  if (EXT_MIME[ext]) return EXT_MIME[ext];
  if (item.type === 'video') return 'video/mp4';
  if (item.type === 'audio') return 'audio/mpeg';
  return 'image/jpeg';
}

function resourceType(item, mimeType) {
  if (item.type === 'video' || mimeType.startsWith('video/')) return 'video';
  if (item.type === 'audio' || mimeType.startsWith('audio/')) return 'audio';
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

function probeAudio(src) {
  return new Promise((resolve) => {
    const audio = document.createElement('audio');
    let done = false;
    const finish = (value) => {
      if (done) return;
      done = true;
      resolve(value);
    };
    audio.preload = 'metadata';
    audio.onloadedmetadata = () =>
      finish({ length: Math.round(audio.duration || 0) });
    audio.onerror = () => finish(DEFAULT_AUDIO);
    setTimeout(() => finish(DEFAULT_AUDIO), 8000);
    audio.src = src;
  });
}

function formatDuration(seconds) {
  const s = Math.max(0, Math.round(seconds || 0));
  const mm = Math.floor(s / 60);
  const ss = String(s % 60).padStart(2, '0');
  return `${mm}:${ss}`;
}

async function toResource(item, { probe = true } = {}) {
  const mimeType = guessMimeType(item);
  const type = resourceType(item, mimeType);
  const src = String(item.src || '');
  if (!src) return null;
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
    const dims = probe ? await probeVideo(src) : DEFAULT_VIDEO;
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
  if (type === 'audio') {
    const meta = probe ? await probeAudio(src) : DEFAULT_AUDIO;
    return createResource({
      ...base,
      length: meta.length,
      lengthFormatted: formatDuration(meta.length),
    });
  }
  const dims = probe ? await probeImage(src) : DEFAULT_IMAGE;
  return createResource({ ...base, width: dims.width, height: dims.height });
}

function matchesSearch(item, searchTerm) {
  const term = String(searchTerm || '').trim().toLowerCase();
  if (!term) return true;
  return String(item.value || item.alt || item.src || '')
    .toLowerCase()
    .includes(term);
}

async function listMedia(mediaType) {
  const reply = await hostRequest('MEDIA_LIST', { mediaType });
  return Array.isArray(reply && reply.items) ? reply.items : [];
}

// getMedia({ mediaType, searchTerm, pagingNum }) -> { data, headers }
export async function getMedia({ mediaType = '', searchTerm = '', pagingNum } = {}) {
  if (pagingNum && pagingNum > 1) {
    return { data: [], headers: { totalItems: 0, totalPages: 1 } };
  }
  const types = mediaType ? [mediaType] : DEFAULT_MEDIA_TYPES;
  const items = (await Promise.all(types.map(listMedia)))
    .flat()
    .filter((item) => matchesSearch(item, searchTerm));
  const data = (await Promise.all(
    items.map((item) => toResource(item, { probe: false }))
  )).filter(Boolean);
  return { data, headers: { totalItems: data.length, totalPages: 1 } };
}

export async function pickMediaResource(mediaType) {
  const reply = await hostRequest(
    'MEDIA_PICK',
    { mediaType },
    { timeout: 120000 }
  );
  if (!reply || !reply.ok || !reply.item) return null;
  return toResource(reply.item, { probe: false });
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
  const mediaType = mimeType.startsWith('video/')
    ? 'video'
    : mimeType.startsWith('audio/')
      ? 'audio'
      : 'image';
  const dataBase64 = await readFileAsBase64(file);
  const reply = await hostRequest(
    'MEDIA_UPLOAD',
    { fileName: file.name, mimeType, mediaType, dataBase64 },
    { timeout: 120000 }
  );
  if (!reply || !reply.ok || !reply.item) {
    throw new Error((reply && reply.error) || 'Upload failed');
  }
  const resource = await toResource(reply.item, { probe: false });
  if (!resource) throw new Error('Upload failed');
  return resource;
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
