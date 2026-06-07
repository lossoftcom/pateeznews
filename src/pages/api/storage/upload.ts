import type { APIRoute } from 'astro';
import path from 'path';
import { setStorageUploadProgress } from '../../../lib/server/storageUploadProgress';
import {
    MEDIA_BUCKET,
    STORAGE_TYPES,
    contentTypeForFilename,
    getStorageType,
    normalizeStoragePath,
    adminStorageClient,
    publicStorageUrl,
    storageObjectPath,
    type StorageType,
} from '@/lib/server/supabaseStorage';
import { requireStorageAdminRequest } from '@/lib/server/storageAdminAuth';

const OPTIMIZED_IMAGE_STORAGE_TYPES = new Set<StorageType>(['image', 'profile']);
const IMAGE_EXTENSIONS = new Set(['.jpg', '.jpeg', '.png', '.webp', '.gif', '.avif', '.tif', '.tiff', '.svg']);
const MAX_IMAGE_DIMENSION = 7680;
const WEBP_QUALITY = 92;
const WEBP_ALPHA_QUALITY = 95;
const WEBP_EFFORT = 6;
const REMOTE_IMAGE_MAX_BYTES = 35 * 1024 * 1024;
const REMOTE_IMAGE_FETCH_TIMEOUT_MS = 20000;

type SharpFactory = typeof import('sharp');
type UploadInput = Pick<File, 'name' | 'type' | 'arrayBuffer'>;

let sharpFactoryPromise: Promise<SharpFactory | null> | null = null;

const sanitizeFilename = (filename: string) => {
    const normalized = filename.normalize('NFC').replace(/[^a-zA-Z0-9._-]/g, '_');
    return normalized || `upload-${Date.now()}`;
};

const withExtension = (filename: string, extension: string) => {
    const parsed = path.posix.parse(filename);
    const base = parsed.name || 'image';
    return `${base}${extension}`;
};

const shouldOptimizeImage = (type: StorageType, file: UploadInput) => {
    const ext = path.posix.extname(file.name || '').toLowerCase();
    return OPTIMIZED_IMAGE_STORAGE_TYPES.has(type) && (file.type.startsWith('image/') || IMAGE_EXTENSIONS.has(ext));
};

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

async function remoteImageUploadInput(remoteUrl: string): Promise<UploadInput> {
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
    if (contentLength > REMOTE_IMAGE_MAX_BYTES) {
        throw new Error('Remote image is too large');
    }

    const arrayBuffer = await response.arrayBuffer();
    if (!arrayBuffer.byteLength) throw new Error('Remote image is empty');
    if (arrayBuffer.byteLength > REMOTE_IMAGE_MAX_BYTES) {
        throw new Error('Remote image is too large');
    }

    return {
        name: remoteImageFilename(parsed, contentType),
        type: contentType.split(';')[0].trim() || contentTypeForFilename(parsed.pathname),
        arrayBuffer: async () => arrayBuffer,
    };
}

const loadSharp = async () => {
    sharpFactoryPromise ??= import('sharp')
        .then((module) => ((module as { default?: SharpFactory }).default ?? module) as SharpFactory)
        .catch((error) => {
            console.warn('Sharp image optimization unavailable, uploading original file:', error?.message || error);
            return null;
        });
    return sharpFactoryPromise;
};

const optimizeImageToWebp = async (input: Buffer) => {
    const sharp = await loadSharp();
    if (!sharp) return null;

    try {
        const image = sharp(input, { animated: true });
        const metadata = await image.metadata();
        const preset = metadata.hasAlpha ? 'picture' : 'photo';

        return sharp(input, { animated: Boolean(metadata.pages && metadata.pages > 1) })
            .rotate()
            .resize({
                width: MAX_IMAGE_DIMENSION,
                height: MAX_IMAGE_DIMENSION,
                fit: 'inside',
                withoutEnlargement: true,
                kernel: 'lanczos3'
            })
            .webp({
                quality: WEBP_QUALITY,
                alphaQuality: WEBP_ALPHA_QUALITY,
                effort: WEBP_EFFORT,
                smartSubsample: true,
                smartDeblock: true,
                preset
            })
            .toBuffer();
    } catch (error: any) {
        console.warn('Image optimization skipped, uploading original file:', error?.message || error);
        return null;
    }
};

const videoThumbObjectPathFor = (objectPath: string) => {
    const parsed = path.posix.parse(objectPath);
    return `${parsed.dir ? `${parsed.dir}/` : ''}${parsed.name}_thumb.webp`;
};

async function uploadObject(
    client: ReturnType<typeof adminStorageClient>,
    objectPath: string,
    buffer: Buffer,
    contentType: string
) {
    const { error } = await client.storage.from(MEDIA_BUCKET).upload(objectPath, buffer, {
        cacheControl: '31536000',
        contentType,
        upsert: true,
    });
    if (error) throw error;
}

export const POST: APIRoute = async ({ request }) => {
    let activeUploadId: string | null = null;

    try {
        const formData = await request.formData();
        const type = getStorageType(formData.get('type'));
        await requireStorageAdminRequest(request, type);
        const fileField = formData.get('file');
        const remoteUrl = (formData.get('remoteUrl') as string | null)?.trim() || '';
        let file: UploadInput | null = fileField instanceof File ? fileField : null;
        if (!file && remoteUrl) {
            if (!OPTIMIZED_IMAGE_STORAGE_TYPES.has(type)) {
                return new Response('Remote upload is only available for images', { status: 400 });
            }
            file = await remoteImageUploadInput(remoteUrl);
        }
        if (!file) {
            return new Response('No file uploaded', { status: 400 });
        }

        const client = adminStorageClient();
        const uploadId = (formData.get('uploadId') as string | null)?.trim() || null;
        activeUploadId = uploadId;
        const replaceIdRaw = formData.get('replaceId') as string | null;
        const optimizeAsImage = shouldOptimizeImage(type, file);

        let customPath = formData.get('customPath') as string;
        if (!customPath) {
            const today = new Date();
            customPath = `${today.getFullYear()}-${String(today.getMonth() + 1).padStart(2, '0')}-${String(today.getDate()).padStart(2, '0')}`;
        }
        customPath = normalizeStoragePath(customPath);

        let customFilename = formData.get('customFilename') as string;
        let finalFilename = sanitizeFilename(file.name);
        let targetPrefix = customPath;
        let oldObjectPathToRemove: string | null = null;

        if (replaceIdRaw) {
            let replaceId = normalizeStoragePath(replaceIdRaw);
            const firstSegment = replaceId.split('/')[0];
            if (STORAGE_TYPES.includes(firstSegment as StorageType)) {
                replaceId = replaceId.split('/').slice(1).join('/');
            }

            if (!replaceId) return new Response('Invalid replacement file ID', { status: 400 });

            const parsed = path.posix.parse(replaceId);
            targetPrefix = parsed.dir;
            finalFilename = sanitizeFilename(parsed.base);
            oldObjectPathToRemove = storageObjectPath(type, replaceId);
        } else if (customFilename) {
            customFilename = sanitizeFilename(customFilename);
            const ext = path.posix.extname(file.name);
            finalFilename = path.posix.extname(customFilename)
                ? customFilename
                : `${customFilename}${ext}`;
        } else {
            finalFilename = `${Date.now()}-${sanitizeFilename(file.name)}`;
        }

        const arrayBuffer = await file.arrayBuffer();
        const inputBuffer = Buffer.from(arrayBuffer);
        let outputBuffer = inputBuffer;
        let contentType = file.type || contentTypeForFilename(finalFilename);

        if (optimizeAsImage) {
            const optimizedBuffer = await optimizeImageToWebp(inputBuffer);
            if (optimizedBuffer) {
                finalFilename = withExtension(finalFilename, '.webp');
                outputBuffer = optimizedBuffer;
                contentType = 'image/webp';
            }
        }

        const relativeId = [targetPrefix, finalFilename].filter(Boolean).join('/');
        const objectPath = storageObjectPath(type, relativeId);
        const outputSize = outputBuffer.length;
        await uploadObject(
            client,
            objectPath,
            outputBuffer,
            contentType
        );

        if (oldObjectPathToRemove) {
            const paths = oldObjectPathToRemove === objectPath ? [] : [oldObjectPathToRemove];
            if (type === 'video') paths.push(videoThumbObjectPathFor(oldObjectPathToRemove));
            if (paths.length) await client.storage.from(MEDIA_BUCKET).remove(paths);
        }

        setStorageUploadProgress(uploadId, {
            phase: 'done',
            progress: 1,
            etaSeconds: 0,
        });

        return new Response(JSON.stringify({
            id: relativeId,
            value: finalFilename,
            src: `/api/storage/file/${type}/${relativeId}`,
            publicSrc: publicStorageUrl(objectPath),
            thumb: `/api/storage/file/${type}/${relativeId}`,
            type,
            size: outputSize
        }), {
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
