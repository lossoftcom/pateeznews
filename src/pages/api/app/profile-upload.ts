import type { APIRoute } from 'astro';
import { getSessionFromRequest, json } from '@/lib/server/appDb';
import { uploadLocalStorageFile } from '@/lib/server/localStorageProxy';
import {
  getStorageSettings,
  isLocalStorageActive,
  recordLocalMediaFile,
} from '@/lib/server/storageSettings';
import {
  IMAGE_UPLOAD_EXTENSIONS,
  loadContentUploadSettings,
  normalizeUploadExtension,
  uploadExtensionFromFilename,
} from '@/lib/server/contentUploadSettings';
import { getStorageType } from '@/lib/server/supabaseStorage';

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

export const POST: APIRoute = async ({ request }) => {
  try {
    const session = await getSessionFromRequest(request);
    if (!session?.user?.id) return json({ error: { message: 'Auth required' } }, 401);

    const storageSettings = await getStorageSettings();
    if (!isLocalStorageActive(storageSettings)) {
      return json({ error: { message: `Selected storage provider is not implemented: ${storageSettings.activeStorage}` } }, 501);
    }

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
