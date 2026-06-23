import type { APIRoute } from 'astro';
import fs from 'fs';
import path from 'path';
import { setStorageUploadProgress } from '../../../lib/server/storageUploadProgress';
import {
    contentTypeForFilename,
    getStorageType,
    normalizeStoragePath,
    type StorageType,
} from '@/lib/server/supabaseStorage';
import { requireStorageAdminRequest } from '@/lib/server/storageAdminAuth';
import {
    getStorageSettings,
    isLocalStorageActive,
    isS3CompatibleStorageActive,
    localBackupEnabled,
    recordLocalMediaFile,
    recordStorageMediaFile,
} from '@/lib/server/storageSettings';
import { resolveLocalUploadPath } from '@/lib/server/localUploadStorage';
import { deleteLocalStorageFile, readLocalStorageFile, uploadLocalStorageFile } from '@/lib/server/localStorageProxy';
import { remoteApiPath, uploadRemoteStorageFile, uploadRemoteStorageObject } from '@/lib/server/remoteObjectStorage';
import { purgeCloudflareCacheFiles } from '@/lib/server/cloudflareCache';
import {
    LOCAL_VARIANT_PREFIXES,
    SUPPORTED_VARIANT_QUALITY,
    SUPPORTED_VARIANT_WIDTHS,
    TRANSFORMABLE_IMAGE_EXTENSIONS,
    objectExtension,
    variantObjectPath,
} from '@/lib/server/imageVariants';
import {
    allowedExtensionsForRuleType,
    loadContentUploadSettings,
    maxUploadBytesForRuleType,
    normalizeUploadExtension,
    uploadExtensionFromFilename,
    uploadRuleTypeForStorageType,
    type ContentUploadSettings,
} from '@/lib/server/contentUploadSettings';
import { isTechnicalMediaText } from '@/lib/mediaSeoText';
import {
    shouldUseDirectRemoteUploadFallback,
    uploadOriginalFileDirectlyToRemoteStorage,
} from '@/lib/server/directRemoteUploadFallback';

// Flags uploads whose final name is machine-generated/meaningless so the admin
// UI can prompt for an SEO-friendly rename. The stored `value` is the source of
// truth for the displayed filename.
const mediaUploadResponse = (payload: Record<string, unknown>) =>
    new Response(
        JSON.stringify({
            ...payload,
            needsSeoRename: isTechnicalMediaText(payload.value),
        }),
        { status: 200, headers: { 'Content-Type': 'application/json' } },
    );

const OPTIMIZED_IMAGE_STORAGE_TYPES = new Set<StorageType>(['image', 'profile']);
const IMAGE_EXTENSIONS = new Set(['.jpg', '.jpeg', '.png', '.webp', '.gif', '.avif', '.tif', '.tiff', '.svg']);
const REMOTE_IMAGE_FETCH_TIMEOUT_MS = 20000;
const IMAGE_PURGE_QUALITIES = Array.from(new Set([SUPPORTED_VARIANT_QUALITY, 82]));

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
                'User-Agent': 'PateezAdmin/1.0 (+https://pateeznews.com) AppleWebKit/605.1.15',
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

function storageObjectPathFromMediaUrl(value: string) {
    const clean = String(value || '').split(/[?#]/)[0];
    const apiMarker = '/api/storage/file/';
    const localMarker = '/local-upload/';
    const apiIndex = clean.indexOf(apiMarker);
    if (apiIndex >= 0) return normalizeStoragePath(clean.slice(apiIndex + apiMarker.length));
    const localIndex = clean.indexOf(localMarker);
    if (localIndex >= 0) return normalizeStoragePath(clean.slice(localIndex + localMarker.length));
    return '';
}

function absolutePurgeUrl(value: string, origin: string) {
    const clean = String(value || '').trim();
    if (!clean) return null;
    try {
        return new URL(clean, origin);
    } catch {
        return null;
    }
}

function addUrl(urls: Set<string>, value: string, origin: string) {
    const url = absolutePurgeUrl(value, origin);
    if (!url || (url.protocol !== 'http:' && url.protocol !== 'https:')) return;
    url.hash = '';
    urls.add(url.toString());
}

function addStorageImagePurgeUrls(urls: Set<string>, objectPath: string, origin: string) {
    const cleanObjectPath = normalizeStoragePath(objectPath);
    if (!cleanObjectPath) return;

    addUrl(urls, `/api/storage/file/${cleanObjectPath}`, origin);
    addUrl(urls, `/local-upload/${cleanObjectPath}`, origin);

    const extension = objectExtension(cleanObjectPath);
    if (!TRANSFORMABLE_IMAGE_EXTENSIONS.has(extension)) return;

    for (const width of SUPPORTED_VARIANT_WIDTHS) {
        addUrl(urls, `/api/storage/file/${cleanObjectPath}?w=${width}`, origin);
        for (const quality of IMAGE_PURGE_QUALITIES) {
            addUrl(
                urls,
                `/api/storage/file/${cleanObjectPath}?w=${width}&q=${quality}`,
                origin,
            );
        }
        if (LOCAL_VARIANT_PREFIXES.some((prefix) => cleanObjectPath.startsWith(prefix))) {
            for (const quality of IMAGE_PURGE_QUALITIES) {
                addUrl(
                    urls,
                    `/local-upload/${variantObjectPath(cleanObjectPath, width, quality)}`,
                    origin,
                );
            }
        } else {
            for (const quality of IMAGE_PURGE_QUALITIES) {
                addUrl(
                    urls,
                    `/cdn-cgi/image/width=${width},quality=${quality},format=auto/local-upload/${cleanObjectPath}`,
                    origin,
                );
            }
        }
    }
}

async function purgeReplacedMediaCache(origin: string, result: Record<string, unknown>) {
    const urls = new Set<string>();
    for (const key of ['src', 'publicSrc', 'thumb']) {
        const value = String(result[key] || '');
        addUrl(urls, value, origin);
        const objectPath = storageObjectPathFromMediaUrl(value);
        if (objectPath) addStorageImagePurgeUrls(urls, objectPath, origin);
    }
    await purgeCloudflareCacheFiles(urls);
}

async function readLocalUploadBuffer(type: StorageType, id: string) {
    try {
        return (await readLocalStorageFile({ type, id })).body;
    } catch {
        // Fall back to direct filesystem access for older local-storage servers.
    }
    const resolved = resolveLocalUploadPath(type, id);
    if (!resolved || !fs.existsSync(resolved.absolutePath)) {
        throw Object.assign(new Error('Processed local upload file is missing'), { status: 500 });
    }
    return fs.promises.readFile(resolved.absolutePath);
}

async function uploadLocalThumbToRemote(
    storageSettings: Awaited<ReturnType<typeof getStorageSettings>>,
    localResult: Record<string, unknown>,
    type: StorageType,
    id: string,
) {
    const objectPath = `${type}/${id}`;
    const thumbObjectPath = storageObjectPathFromMediaUrl(String(localResult.thumb || ''));
    if (!thumbObjectPath || thumbObjectPath === objectPath) return '';

    const [thumbTypeValue, ...thumbParts] = thumbObjectPath.split('/');
    const thumbType = getStorageType(thumbTypeValue);
    if (!thumbParts.length) return '';

    const buffer = await readLocalUploadBuffer(thumbType, thumbParts.join('/'));
    await uploadRemoteStorageObject(storageSettings, {
        objectPath: thumbObjectPath,
        body: buffer,
        contentType: contentTypeForFilename(thumbObjectPath),
    });
    return thumbObjectPath;
}

async function cleanupLocalUpload(type: StorageType, id: string) {
    await deleteLocalStorageFile({ type, id }).catch((error) => {
        console.warn('Temporary local upload cleanup skipped:', error instanceof Error ? error.message : error);
    });
}

function localMediaRecordFromResult(localResult: Record<string, unknown>) {
    const type = getStorageType(localResult.type);
    const id = String(localResult.id || '');
    return {
        id,
        type,
        value: String(localResult.value || ''),
        path: String(localResult.path || ''),
        size: Number(localResult.size || 0),
        contentType: normalizedUploadContentType(id, localResult.contentType),
        src: String(localResult.src || ''),
        publicSrc: String(localResult.publicSrc || ''),
        thumb: String(localResult.thumb || localResult.src || ''),
    };
}

function normalizedUploadContentType(id: string, contentType: unknown) {
    const normalized = String(contentType || '').split(';')[0].trim().toLowerCase();
    const inferred = contentTypeForFilename(id, '');
    if (!normalized || normalized === 'application/octet-stream') {
        return inferred || 'application/octet-stream';
    }
    return normalized;
}

function localFallbackResult(localResult: Record<string, unknown>) {
    const record = localMediaRecordFromResult(localResult);
    const objectPath = `${record.type}/${record.id}`;
    const thumbObjectPath = storageObjectPathFromMediaUrl(record.thumb) || objectPath;
    const src = remoteApiPath(objectPath);
    return {
        id: record.id,
        value: record.value,
        size: record.size,
        date: Math.floor(Date.now() / 1000),
        type: record.type,
        src,
        thumb: remoteApiPath(thumbObjectPath),
        publicSrc: src,
        path: record.path,
        provider: 'localFallback',
        objectPath,
        contentType: record.contentType,
    };
}

export const POST: APIRoute = async ({ request }) => {
    let activeUploadId: string | null = null;

    try {
        const requestUrl = new URL(request.url);
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
        const replaceId = (formData.get('replaceId') as string | null)?.trim() || '';
        activeUploadId = uploadId;

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

        if (isS3CompatibleStorageActive(storageSettings)) {
            const keepLocalBackup = localBackupEnabled(storageSettings);
            let localResult: Record<string, unknown> | null = null;
            try {
                let processed: Record<string, unknown>;
                try {
                    processed = await uploadLocalStorageFile(uploadFormData);
                } catch (error) {
                    if (!shouldUseDirectRemoteUploadFallback(error)) throw error;
                    console.warn(
                        'Local upload processor unavailable; using direct remote upload fallback:',
                        error instanceof Error ? error.message : error,
                    );
                    const result = await uploadOriginalFileDirectlyToRemoteStorage({
                        storageSettings,
                        file,
                        type,
                        formData: uploadFormData,
                    });
                    setStorageUploadProgress(uploadId, {
                        phase: 'done',
                        progress: 1,
                        etaSeconds: 0,
                        message: 'Local processor unavailable; remote fallback upload completed.',
                    });
                    if (replaceId) await purgeReplacedMediaCache(requestUrl.origin, result);
                    return mediaUploadResponse(result);
                }

                localResult = processed;
                const resultType = getStorageType(processed.type);
                const resultId = String(processed.id || '');
                const buffer = await readLocalUploadBuffer(resultType, resultId);
                const contentType = normalizedUploadContentType(resultId, processed.contentType);
                let result;
                try {
                    const thumbObjectPath = await uploadLocalThumbToRemote(
                        storageSettings,
                        processed,
                        resultType,
                        resultId,
                    );
                    result = await uploadRemoteStorageFile(storageSettings, {
                        type: resultType,
                        id: resultId,
                        body: buffer,
                        contentType,
                        thumbObjectPath,
                    });
                } catch (error) {
                    if (!keepLocalBackup) throw error;
                    const fallback = localFallbackResult(processed);
                    await recordLocalMediaFile(localMediaRecordFromResult(processed));
                    setStorageUploadProgress(uploadId, {
                        phase: 'done',
                        progress: 1,
                        etaSeconds: 0,
                        message: 'Remote storage unavailable; local backup used.',
                    });
                    if (replaceId) await purgeReplacedMediaCache(requestUrl.origin, fallback);
                    return mediaUploadResponse(fallback);
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
                    await recordLocalMediaFile(localMediaRecordFromResult(processed));
                }

                setStorageUploadProgress(uploadId, {
                    phase: 'done',
                    progress: 1,
                    etaSeconds: 0,
                });

                if (replaceId) await purgeReplacedMediaCache(requestUrl.origin, result);
                return mediaUploadResponse(result);
            } finally {
                if (!keepLocalBackup && localResult?.id) {
                    await cleanupLocalUpload(getStorageType(localResult.type), String(localResult.id));
                }
            }
        }

        if (!isLocalStorageActive(storageSettings)) {
            return new Response(`Selected storage provider is not implemented: ${storageSettings.activeStorage}`, { status: 501 });
        }

        const result = await uploadLocalStorageFile(uploadFormData);
        const resultId = String(result.id || '');
        await recordLocalMediaFile({
            id: resultId,
            type: getStorageType(result.type),
            value: String(result.value || ''),
            path: String(result.path || ''),
            size: Number(result.size || 0),
            contentType: normalizedUploadContentType(resultId, result.contentType),
            src: String(result.src || ''),
            publicSrc: String(result.publicSrc || ''),
            thumb: String(result.thumb || result.src || ''),
        });

        setStorageUploadProgress(uploadId, {
            phase: 'done',
            progress: 1,
            etaSeconds: 0,
        });

        if (replaceId) await purgeReplacedMediaCache(requestUrl.origin, result);
        return mediaUploadResponse(result);

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
