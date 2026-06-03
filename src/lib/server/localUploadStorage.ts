import path from 'path';
import type { StorageType } from './supabaseStorage';

export const LOCAL_STATIC_PREFIX = '/local-upload/';
export const LOCAL_STATIC_CACHE = 'public, max-age=86400, stale-while-revalidate=604800';

const LOCAL_FALLBACKS: Partial<Record<StorageType, string[]>> = {
  image: [
    'image/fallback/pateez-news-placeholder.webp',
    'image/2026-05-24/1779656233738-d-s-c02472.webp',
    'image/2026-05-24/1779656103320-Ekran_Resmi_2026-05-24_23.39.03.webp',
  ],
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

const LOCAL_STATIC_FILES = new Set([
  'image/fallback/pateez-news-placeholder.webp',
  'image/2026-05-24/1779656233738-d-s-c02472.webp',
  'image/2026-05-24/1779656103320-Ekran_Resmi_2026-05-24_23.39.03.webp',
  'image/2026-05-25/1779657593087-hugging-asian-couple-stands-before-beautiful-waterfall-mountains.webp',
  'image/2026-05-25/1779657690981-5972469.webp',
  'image/2026-05-25/1779657607042-numerology-concept-with-woman-beach.webp',
  'logo/tr/pateezlogoson.png',
  'logo/tr/pateezlogowhite.png',
  'logo/tr/pateezlogoicon.png',
  'logo/tr/pateezlogodark.png',
  'logo/tr/pateezlogoepost.png',
  'logo/tr/pateezlogofooter.png',
  'profile/6c1a27d3-ce8e-4c42-bec1-fc092139e3ee-avatar.webp',
  'profile/6c1a27d3-ce8e-4c42-bec1-fc092139e3ee-cover.webp',
  'profile/nasip-avatar.webp',
  'profile/nasip-cover.webp',
]);

function localDateFromPath(objectPath: string) {
  const match = objectPath.match(/(?:^|\/)(\d{4}-\d{2}-\d{2})(?:\/|$)/);
  if (!match) return 0;
  const time = new Date(`${match[1]}T00:00:00Z`).getTime();
  return Number.isFinite(time) ? Math.floor(time / 1000) : 0;
}

export function exactLocalStaticPath(objectPath: string) {
  return LOCAL_STATIC_FILES.has(objectPath) ? `${LOCAL_STATIC_PREFIX}${objectPath}` : null;
}

export function localStaticPath(type: StorageType, objectPath: string) {
  const exact = exactLocalStaticPath(objectPath);
  if (exact) return exact;
  const fallback = LOCAL_FALLBACKS[type]?.[0];
  return fallback ? `${LOCAL_STATIC_PREFIX}${fallback}` : null;
}

export function localUploadItemsForType(type: StorageType) {
  const prefix = `${type}/`;
  return Array.from(LOCAL_STATIC_FILES)
    .filter((objectPath) => objectPath.startsWith(prefix))
    .map((objectPath) => {
      const relativeId = objectPath.slice(prefix.length);
      const parsed = path.posix.parse(relativeId);
      const src = `/api/storage/file/${type}/${relativeId}`;
      return {
        id: relativeId,
        value: parsed.base,
        size: 0,
        date: localDateFromPath(objectPath),
        type,
        src,
        thumb: src,
        publicSrc: `${LOCAL_STATIC_PREFIX}${objectPath}`,
        path: parsed.dir,
        provider: 'local',
      };
    });
}
