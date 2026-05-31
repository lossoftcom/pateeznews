import type { APIRoute } from 'astro';
import path from 'path';
import sharp from 'sharp';
import { setStorageUploadProgress } from '../../../lib/server/storageUploadProgress';
import {
    MEDIA_BUCKET,
    STORAGE_TYPES,
    contentTypeForFilename,
    getStorageType,
    normalizeStoragePath,
    adminStorageClient,
    storageObjectPath,
    type StorageType,
} from '@/lib/server/supabaseStorage';
import { requireStorageAdminRequest } from '@/lib/server/storageAdminAuth';

const IMAGE_STORAGE_TYPES = new Set<StorageType>(['image', 'logo', 'profile']);
const IMAGE_EXTENSIONS = new Set(['.jpg', '.jpeg', '.png', '.webp', '.gif', '.avif', '.tif', '.tiff', '.svg']);
const MAX_IMAGE_DIMENSION = 7680;
const WEBP_QUALITY = 92;
const WEBP_ALPHA_QUALITY = 95;
const WEBP_EFFORT = 6;

const sanitizeFilename = (filename: string) => {
    const normalized = filename.normalize('NFC').replace(/[^a-zA-Z0-9._-]/g, '_');
    return normalized || `upload-${Date.now()}`;
};

const withExtension = (filename: string, extension: string) => {
    const parsed = path.posix.parse(filename);
    const base = parsed.name || 'image';
    return `${base}${extension}`;
};

const shouldOptimizeImage = (type: StorageType, file: File) => {
    const ext = path.posix.extname(file.name || '').toLowerCase();
    return IMAGE_STORAGE_TYPES.has(type) && (file.type.startsWith('image/') || IMAGE_EXTENSIONS.has(ext));
};

const optimizeImageToWebp = async (input: Buffer) => {
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
        const file = formData.get('file') as File;

        if (!file || !(file instanceof File)) {
            return new Response('No file uploaded', { status: 400 });
        }

        const type = getStorageType(formData.get('type'));
        await requireStorageAdminRequest(request, type);
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
            finalFilename = optimizeAsImage
                ? withExtension(parsed.base, '.webp')
                : sanitizeFilename(parsed.base);
            oldObjectPathToRemove = storageObjectPath(type, replaceId);
        } else if (customFilename) {
            customFilename = sanitizeFilename(customFilename);
            if (optimizeAsImage) {
                finalFilename = customFilename;
            } else {
                const ext = path.posix.extname(file.name);
                finalFilename = customFilename.endsWith(ext) ? customFilename : `${customFilename}${ext}`;
            }
        } else {
            finalFilename = `${Date.now()}-${sanitizeFilename(file.name)}`;
        }

        if (optimizeAsImage) {
            finalFilename = withExtension(finalFilename, '.webp');
        }

        const relativeId = [targetPrefix, finalFilename].filter(Boolean).join('/');
        const objectPath = storageObjectPath(type, relativeId);

        const arrayBuffer = await file.arrayBuffer();
        const inputBuffer = Buffer.from(arrayBuffer);
        let outputSize = inputBuffer.length;
        const outputBuffer = optimizeAsImage
            ? await optimizeImageToWebp(inputBuffer)
            : inputBuffer;
        outputSize = outputBuffer.length;
        await uploadObject(
            client,
            objectPath,
            outputBuffer,
            optimizeAsImage ? 'image/webp' : file.type || contentTypeForFilename(finalFilename)
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
