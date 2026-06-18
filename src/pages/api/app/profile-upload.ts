import type { APIRoute } from 'astro';
import fs from 'fs';
import { getSessionFromRequest, json } from '@/lib/server/appDb';
import { deleteLocalStorageFile, uploadLocalStorageFile } from '@/lib/server/localStorageProxy';
import { resolveLocalUploadPath } from '@/lib/server/localUploadStorage';
import {
  getStorageSettings,
  isLocalStorageActive,
  isS3CompatibleStorageActive,
  localBackupEnabled,
  recordLocalMediaFile,
  recordStorageMediaFile,
} from '@/lib/server/storageSettings';
import { remoteApiPath, uploadRemoteStorageFile } from '@/lib/server/remoteObjectStorage';
import {
  IMAGE_UPLOAD_EXTENSIONS,
  loadContentUploadSettings,
  normalizeUploadExtension,
  uploadExtensionFromFilename,
} from '@/lib/server/contentUploadSettings';
import { contentTypeForFilename, getStorageType } from '@/lib/server/supabaseStorage';

const PROFILE_IMAGE_MAX_BYTES = 5 * 1024 * 1024;
const PROFILE_IMAGE_EXTENSIONS = new Set(['jpg', 'jpeg', 'png', 'webp']);

function cleanText(value: unknown) {
  return String(value || '').trim();
}

function cleanKind(value: unknown) {
  return cleanText(value) === 'cover' ? 'cover' : 'avatar';
}

function validateProfileImage(file: File) {
  const extension = normalizeUploadExtension(uploadExtensionFromFilename(file.name));
  if (!extension || !IMAGE_UPLOAD_EXTENSIONS.has(extension) || !PROFILE_IMAGE_EXTENSIONS.has(extension)) {
    throw Object.assign(new Error('Profil görseli JPG, PNG veya WEBP olmalı'), { status: 400 });
  }
  if (file.size > PROFILE_IMAGE_MAX_BYTES) {
    throw Object.assign(new Error('Profil görseli en fazla 5 MB olabilir'), { status: 413 });
  }
}

async function readProfileLocalBuffer(id: string) {
  const resolved = resolveLocalUploadPath('profile', id);
  if (!resolved || !fs.existsSync(resolved.absolutePath)) {
    throw Object.assign(new Error('Processed profile upload file is missing'), { status: 500 });
  }
  return fs.promises.readFile(resolved.absolutePath);
}

async function cleanupProfileLocalUpload(id: string) {
  await deleteLocalStorageFile({ type: 'profile', id }).catch((error) => {
    console.warn('Temporary profile upload cleanup skipped:', error instanceof Error ? error.message : error);
  });
}

function profileLocalMediaRecord(localResult: Record<string, unknown>) {
  return {
    id: String(localResult.id || ''),
    type: getStorageType(localResult.type),
    value: String(localResult.value || ''),
    path: String(localResult.path || ''),
    size: Number(localResult.size || 0),
    contentType: String(localResult.contentType || ''),
    src: String(localResult.src || ''),
    publicSrc: String(localResult.publicSrc || ''),
    thumb: String(localResult.thumb || localResult.src || ''),
  };
}

function profileLocalFallbackResult(localResult: Record<string, unknown>, kind: 'avatar' | 'cover') {
  const record = profileLocalMediaRecord(localResult);
  const objectPath = `${record.type}/${record.id}`;
  const src = remoteApiPath(objectPath);
  return {
    ok: true,
    kind,
    id: record.id,
    src,
    publicSrc: src,
    contentType: record.contentType,
    size: record.size,
  };
}

export const POST: APIRoute = async ({ request }) => {
  try {
    const session = await getSessionFromRequest(request);
    if (!session?.user?.id) return json({ error: { message: 'Auth required' } }, 401);

    const storageSettings = await getStorageSettings();
    const formData = await request.formData();
    const file = formData.get('file');
    if (!(file instanceof File)) {
      return json({ error: { message: 'No file uploaded' } }, 400);
    }
    validateProfileImage(file);

    const kind = cleanKind(formData.get('kind'));
    const uploadSettings = await loadContentUploadSettings(
      cleanText(formData.get('languageCode')) || 'tr',
    );
    const uploadFormData = new FormData();
    uploadFormData.set('type', 'profile');
    uploadFormData.set('customPath', session.user.id);
    uploadFormData.set('customFilename', `${kind}.webp`);
    uploadFormData.set('imageOutputFormat', uploadSettings.imageOutputFormat);
    uploadFormData.set('file', file);

    if (isS3CompatibleStorageActive(storageSettings)) {
      const keepLocalBackup = localBackupEnabled(storageSettings);
      let localResult: Record<string, unknown> | null = null;
      try {
        const processed = await uploadLocalStorageFile(uploadFormData);
        localResult = processed;
        const resultId = String(processed.id || '');
        const buffer = await readProfileLocalBuffer(resultId);
        const contentType = String(processed.contentType || contentTypeForFilename(resultId));
        let result;
        try {
          result = await uploadRemoteStorageFile(storageSettings, {
            type: 'profile',
            id: resultId,
            body: buffer,
            contentType,
          });
        } catch (error) {
          if (!keepLocalBackup) throw error;
          await recordLocalMediaFile(profileLocalMediaRecord(processed));
          return json(profileLocalFallbackResult(processed, kind));
        }

        await recordStorageMediaFile(result.provider, {
          id: result.id,
          type: result.type,
          value: result.value,
          path: result.path,
          size: result.size,
          contentType,
          src: result.src,
          publicSrc: result.publicSrc,
          thumb: result.thumb,
        });

        if (keepLocalBackup) {
          await recordLocalMediaFile(profileLocalMediaRecord(processed));
        }

        return json({
          ok: true,
          kind,
          id: result.id,
          src: result.src,
          publicSrc: result.publicSrc,
          contentType,
          size: result.size,
        });
      } finally {
        if (!keepLocalBackup && localResult?.id) {
          await cleanupProfileLocalUpload(String(localResult.id));
        }
      }
    }

    if (!isLocalStorageActive(storageSettings)) {
      return json({ error: { message: `Selected storage provider is not implemented: ${storageSettings.activeStorage}` } }, 501);
    }

    const result = await uploadLocalStorageFile(uploadFormData);
    await recordLocalMediaFile({
      id: String(result.id || ''),
      type: getStorageType(result.type),
      value: String(result.value || ''),
      path: String(result.path || ''),
      size: Number(result.size || 0),
      contentType: String(result.contentType || ''),
      src: String(result.src || ''),
      publicSrc: String(result.publicSrc || ''),
      thumb: String(result.thumb || result.src || ''),
    });

    return json({
      ok: true,
      kind,
      id: String(result.id || ''),
      src: String(result.src || ''),
      publicSrc: String(result.publicSrc || ''),
      contentType: String(result.contentType || ''),
      size: Number(result.size || 0),
    });
  } catch (error: any) {
    return json(
      { error: { message: error.message || 'Profile image upload failed' } },
      error?.status || 500,
    );
  }
};
