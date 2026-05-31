import type { APIRoute } from 'astro';
import fs from 'node:fs/promises';
import path from 'node:path';
import {
  contentTypeForFilename,
  getStorageType,
  publicStorageUrl,
  type StorageType,
  storageObjectPath,
} from '@/lib/server/supabaseStorage';

const LOCAL_FALLBACKS: Partial<Record<StorageType, string[]>> = {
  image: [
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

const RANGEABLE_MEDIA_EXTENSIONS = new Set([
  '.mp4',
  '.m4v',
  '.webm',
  '.mov',
  '.mp3',
  '.wav',
  '.ogg',
  '.oga',
  '.m4a',
  '.aac',
]);

function parseBoundedInt(value: string | null, min: number, max: number) {
  if (!value) return null;
  const parsed = Number.parseInt(value, 10);
  if (!Number.isFinite(parsed)) return null;
  return Math.min(Math.max(parsed, min), max);
}

function isLocalUploadFallbackEnabled() {
  return import.meta.env.DEV || process.env.NODE_ENV !== 'production';
}

function localUploadPath(objectPath: string) {
  const uploadRoot = path.resolve(process.cwd(), 'Upload');
  const candidate = path.resolve(uploadRoot, objectPath);
  if (!candidate.startsWith(`${uploadRoot}${path.sep}`)) return null;
  return candidate;
}

async function existingLocalUploadPath(objectPath: string) {
  const candidate = localUploadPath(objectPath);
  if (!candidate) return null;
  try {
    const stats = await fs.stat(candidate);
    return stats.isFile() ? candidate : null;
  } catch {
    return null;
  }
}

async function existingFallbackPath(type: StorageType) {
  for (const fallback of LOCAL_FALLBACKS[type] || []) {
    const candidate = await existingLocalUploadPath(fallback);
    if (candidate) return candidate;
  }
  return null;
}

async function localFileResponse(filePath: string, request: Request) {
  const stats = await fs.stat(filePath);
  const ext = path.extname(filePath).toLowerCase();
  const headers: Record<string, string> = {
    'Content-Type': contentTypeForFilename(filePath),
    'Cache-Control': 'public, max-age=60',
    'Access-Control-Allow-Origin': '*',
  };

  if (RANGEABLE_MEDIA_EXTENSIONS.has(ext)) {
    headers['Accept-Ranges'] = 'bytes';
    const range = request.headers.get('range');
    if (range) {
      const match = /^bytes=(\d*)-(\d*)$/.exec(range.trim());
      if (!match) {
        return new Response('Invalid Range', {
          status: 416,
          headers: {
            ...headers,
            'Content-Range': `bytes */${stats.size}`,
          },
        });
      }

      const [, startRaw, endRaw] = match;
      let start = startRaw ? Number.parseInt(startRaw, 10) : 0;
      let end = endRaw ? Number.parseInt(endRaw, 10) : stats.size - 1;

      if (!startRaw && endRaw) {
        const suffixLength = Number.parseInt(endRaw, 10);
        start = Math.max(stats.size - suffixLength, 0);
        end = stats.size - 1;
      }

      if (!Number.isFinite(start) || !Number.isFinite(end) || start < 0 || end < start || start >= stats.size) {
        return new Response('Range Not Satisfiable', {
          status: 416,
          headers: {
            ...headers,
            'Content-Range': `bytes */${stats.size}`,
          },
        });
      }

      end = Math.min(end, stats.size - 1);
      const fileContent = await fs.readFile(filePath);
      const chunk = fileContent.subarray(start, end + 1);
      return new Response(chunk, {
        status: 206,
        headers: {
          ...headers,
          'Content-Range': `bytes ${start}-${end}/${stats.size}`,
          'Content-Length': String(chunk.length),
        },
      });
    }
  }

  const fileContent = await fs.readFile(filePath);
  return new Response(fileContent, {
    status: 200,
    headers: {
      ...headers,
      'Content-Length': String(stats.size),
    },
  });
}

export const GET: APIRoute = async ({ params, request }) => {
  const filePath = params.path;
  if (!filePath) return new Response('Path is required', { status: 400 });

  const [firstSegment, ...rest] = filePath.split('/');
  const type = getStorageType(firstSegment);
  const objectPath = storageObjectPath(type, rest.length ? rest.join('/') : filePath);
  const url = new URL(request.url);
  const width = parseBoundedInt(url.searchParams.get('w'), 64, 2400);
  const quality = parseBoundedInt(url.searchParams.get('q'), 40, 100);

  if (isLocalUploadFallbackEnabled()) {
    const localPath = await existingLocalUploadPath(objectPath);
    if (localPath) return localFileResponse(localPath, request);

    const fallbackPath = await existingFallbackPath(type);
    if (fallbackPath) return localFileResponse(fallbackPath, request);
  }

  return Response.redirect(publicStorageUrl(objectPath, request, { width, quality }), 302);
};
