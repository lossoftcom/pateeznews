import type { APIRoute } from 'astro';
import path from 'path';
import { setStorageUploadProgress } from '../../../lib/server/storageUploadProgress';
import {
    contentTypeForFilename,
    getStorageType,
    type StorageType,
} from '@/lib/server/supabaseStorage';
import { requireStorageAdminRequest } from '@/lib/server/storageAdminAuth';
import {
    getStorageSettings,
    isLocalStorageActive,
    recordLocalMediaFile,
} from '@/lib/server/storageSettings';
import { uploadLocalStorageFile } from '@/lib/server/localStorageProxy';
import {
    allowedExtensionsForRuleType,
    loadContentUploadSettings,
    maxUploadBytesForRuleType,
    normalizeUploadExtension,
    uploadExtensionFromFilename,
    uploadRuleTypeForStorageType,
    type ContentUploadSettings,
} from '@/lib/server/contentUploadSettings';

const OPTIMIZED_IMAGE_STORAGE_TYPES = new Set<StorageType>(['image', 'profile']);
const IMAGE_EXTENSIONS = new Set(['.jpg', '.jpeg', '.png', '.webp', '.gif', '.avif', '.tif', '.tiff', '.svg']);
const REMOTE_IMAGE_FETCH_TIMEOUT_MS = 20000;

type UploadInput = Pick<File, 'name' | 'type' | 'size' | 'arrayBuffer'>;

const extensionForContentType = (contentType: string) => {
    const normalized = contentType.toLowerCase().split(';')[0].trim();
    const map: Record<string, string> = {
        'image/jpeg': '.jpg',
        'image/jpg': '.jpg',
        'image/png': '.png',
        'image/webp': '.webp',
        'image/gif': '.gif',
        'image/avif': '.avif',
        'image/tiff': '.tif',
        'image/svg+xml': '.svg',
    };
    return map[normalized] || '';
};

const remoteImageFilename = (url: URL, contentType: string) => {
    const lastSegment = url.pathname.split('/').filter(Boolean).pop() || `source-image-${Date.now()}`;
    const decoded = decodeURIComponent(lastSegment).trim() || `source-image-${Date.now()}`;
    const ext = path.posix.extname(decoded) || extensionForContentType(contentType) || '.jpg';
    return path.posix.extname(decoded) ? decoded : `${decoded}${ext}`;
};

const isRemoteImageResponse = (url: URL, contentType: string) => {
    const normalizedType = contentType.toLowerCase().split(';')[0].trim();
    if (normalizedType.startsWith('image/')) return true;
    return IMAGE_EXTENSIONS.has(path.posix.extname(url.pathname).toLowerCase());
};

async function remoteImageUploadInput(
    remoteUrl: string,
    uploadSettings: ContentUploadSettings,
): Promise<UploadInput> {
    let parsed: URL;
    try {
        parsed = new URL(remoteUrl.trim());
    } catch {
        throw new Error('Invalid remote image URL');
    }
    if (parsed.protocol !== 'http:' && parsed.protocol !== 'https:') {
        throw new Error('Invalid remote image URL');
    }

    const controller = new AbortController();
    const timeout = setTimeout(() => controller.abort(), REMOTE_IMAGE_FETCH_TIMEOUT_MS);
    let response: Response;
    try {
        response = await fetch(parsed, {
            headers: {
                Accept: 'image/avif,image/webp,image/apng,image/svg+xml,image/*,*/*;q=0.8',
                'User-Agent': 'PateezNewsAdmin/1.0 (+https://pateeznews.com) AppleWebKit/605.1.15',
            },
            redirect: 'follow',
            signal: controller.signal,
        });
    } finally {
        clearTimeout(timeout);
    }

    if (!response.ok) {
        throw new Error(`Remote image download failed: HTTP ${response.status}`);
    }

    const contentType = response.headers.get('content-type') || contentTypeForFilename(parsed.pathname, '');
    if (!isRemoteImageResponse(parsed, contentType)) {
        throw new Error('Remote URL is not an image');
    }

    const contentLength = Number(response.headers.get('content-length') || 0);
    if (contentLength > uploadSettings.maxImageBytes) {
        throw new Error('Remote image is too large');
    }

    const arrayBuffer = await response.arrayBuffer();
    if (!arrayBuffer.byteLength) throw new Error('Remote image is empty');
    if (arrayBuffer.byteLength > uploadSettings.maxImageBytes) {
        throw new Error('Remote image is too large');
    }
    const name = remoteImageFilename(parsed, contentType);
    validateUploadInput({
        name,
        size: arrayBuffer.byteLength,
        storageType: 'image',
        settings: uploadSettings,
    });

    return {
        name,
        type: contentType.split(';')[0].trim() || contentTypeForFilename(parsed.pathname),
        size: arrayBuffer.byteLength,
        arrayBuffer: async () => arrayBuffer,
    };
}

function validateUploadInput({
    name,
    size,
    storageType,
    settings,
}: {
    name: string;
    size: number;
    storageType: StorageType;
    settings: ContentUploadSettings;
}) {
    const ruleType = uploadRuleTypeForStorageType(storageType);
    if (ruleType === 'font') return;

    const extension = normalizeUploadExtension(uploadExtensionFromFilename(name));
    if (!extension) {
        throw Object.assign(new Error('File extension is required'), { status: 400 });
    }

    const typeExtensions = allowedExtensionsForRuleType(ruleType);
    if (!typeExtensions.has(extension)) {
        throw Object.assign(new Error('File extension does not match upload type'), { status: 400 });
    }

    if (!settings.allowedExtensions.has(extension)) {
        throw Object.assign(new Error('File extension is not allowed'), { status: 400 });
    }

    const maxBytes = maxUploadBytesForRuleType(settings, ruleType);
    if (size > maxBytes) {
        throw Object.assign(new Error('File is too large'), { status: 413 });
    }
}

export const POST: APIRoute = async ({ request }) => {
    let activeUploadId: string | null = null;

    try {
        const formData = await request.formData();
        const type = getStorageType(formData.get('type'));
        await requireStorageAdminRequest(request, type);
        const uploadSettings = await loadContentUploadSettings(
            (formData.get('languageCode') as string | null) || 'tr',
        );
        const fileField = formData.get('file');
        const remoteUrl = (formData.get('remoteUrl') as string | null)?.trim() || '';
        let file: UploadInput | null = fileField instanceof File ? fileField : null;
        if (!file && remoteUrl) {
            if (!OPTIMIZED_IMAGE_STORAGE_TYPES.has(type)) {
                return new Response('Remote upload is only available for images', { status: 400 });
            }
            file = await remoteImageUploadInput(remoteUrl, uploadSettings);
        }
        if (!file) {
            return new Response('No file uploaded', { status: 400 });
        }
        validateUploadInput({
            name: file.name,
            size: file.size,
            storageType: type,
            settings: uploadSettings,
        });

        const storageSettings = await getStorageSettings();
        const uploadId = (formData.get('uploadId') as string | null)?.trim() || null;
        activeUploadId = uploadId;

        if (!isLocalStorageActive(storageSettings)) {
            return new Response(`Selected storage provider is not implemented: ${storageSettings.activeStorage}`, { status: 501 });
        }

        const uploadFormData = fileField instanceof File ? formData : new FormData();
        if (!(fileField instanceof File)) {
            const buffer = await file.arrayBuffer();
            uploadFormData.set('file', new File([buffer], file.name, { type: file.type }));
            for (const key of ['type', 'uploadId', 'customPath', 'customFilename', 'replaceId']) {
                const value = formData.get(key);
                if (typeof value === 'string' && value.trim()) uploadFormData.set(key, value);
            }
        }
        if (OPTIMIZED_IMAGE_STORAGE_TYPES.has(type)) {
            uploadFormData.set('imageOutputFormat', uploadSettings.imageOutputFormat);
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

        setStorageUploadProgress(uploadId, {
            phase: 'done',
            progress: 1,
            etaSeconds: 0,
        });

        return new Response(JSON.stringify(result), {
            status: 200,
            headers: {
                'Content-Type': 'application/json'
            }
        });

    } catch (err: any) {
        console.error('Upload Error:', err);
        setStorageUploadProgress(activeUploadId, {
            phase: 'error',
            progress: null,
            etaSeconds: null,
            message: err.message || 'Server Error',
        });
        return new Response(err.message || 'Server Error', { status: err?.status || 500 });
    }
};
