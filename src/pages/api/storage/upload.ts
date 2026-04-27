import type { APIRoute } from 'astro';
import fs from 'fs';
import path from 'path';
import sharp from 'sharp';

const STORAGE_TYPES = ['image', 'video', 'audio', 'file', 'logo', 'profile'] as const;
type StorageType = typeof STORAGE_TYPES[number];

const IMAGE_STORAGE_TYPES = new Set<StorageType>(['image', 'logo', 'profile']);
const IMAGE_EXTENSIONS = new Set(['.jpg', '.jpeg', '.png', '.webp', '.gif', '.avif', '.tif', '.tiff', '.svg']);
const MAX_IMAGE_DIMENSION = 7680;
const WEBP_QUALITY = 86;
const WEBP_ALPHA_QUALITY = 95;
const WEBP_EFFORT = 6;

const safeDecode = (value: string) => {
    let decoded = value;
    for (let i = 0; i < 3; i++) {
        try {
            const next = decodeURIComponent(decoded);
            if (next === decoded) break;
            decoded = next;
        } catch {
            break;
        }
    }
    return decoded;
};

const normalizeRelativePath = (value: string) => {
    return safeDecode(value)
        .replace(/\\/g, '/')
        .replace(/^\/+/, '')
        .replace(/^Upload\//i, '');
};

const getStorageType = (value: unknown): StorageType => {
    return typeof value === 'string' && STORAGE_TYPES.includes(value as StorageType)
        ? value as StorageType
        : 'image';
};

const isInside = (baseDir: string, targetPath: string) => {
    const relative = path.relative(baseDir, targetPath);
    return relative === '' || (!relative.startsWith('..') && !path.isAbsolute(relative));
};

const sanitizeFilename = (filename: string) => {
    const normalized = filename.normalize('NFC').replace(/[^a-zA-Z0-9._-]/g, '_');
    return normalized || `upload-${Date.now()}`;
};

const withExtension = (filename: string, extension: string) => {
    const parsed = path.parse(filename);
    const base = parsed.name || 'image';
    return `${base}${extension}`;
};

const shouldOptimizeImage = (type: StorageType, file: File) => {
    const ext = path.extname(file.name || '').toLowerCase();
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

export const POST: APIRoute = async ({ request }) => {
    try {
        const formData = await request.formData();
        const file = formData.get('file') as File;

        if (!file || !(file instanceof File)) {
            return new Response('No file uploaded', { status: 400 });
        }

        const type = getStorageType(formData.get('type'));
        const replaceIdRaw = formData.get('replaceId') as string | null;
        const optimizeAsImage = shouldOptimizeImage(type, file);

        let customPath = formData.get('customPath') as string;
        if (!customPath) {
            const today = new Date();
            customPath = `${today.getFullYear()}-${String(today.getMonth() + 1).padStart(2, '0')}-${String(today.getDate()).padStart(2, '0')}`;
        }
        customPath = normalizeRelativePath(customPath);

        const uploadRootDir = path.resolve(process.cwd(), 'Upload');
        const typeDir = path.resolve(uploadRootDir, type);
        let targetDir = path.resolve(typeDir, customPath);

        let customFilename = formData.get('customFilename') as string;
        let finalFilename = sanitizeFilename(file.name);
        let oldPathToRemove: string | null = null;

        if (replaceIdRaw) {
            let replaceId = normalizeRelativePath(replaceIdRaw);
            const firstSegment = replaceId.split('/')[0];
            if (STORAGE_TYPES.includes(firstSegment as StorageType)) {
                replaceId = replaceId.split('/').slice(1).join('/');
            }

            if (!replaceId || replaceId.includes('\0')) {
                return new Response('Invalid replacement file ID', { status: 400 });
            }

            const oldFullPath = path.resolve(typeDir, replaceId);
            if (!isInside(typeDir, oldFullPath)) {
                return new Response('Invalid replacement path', { status: 400 });
            }

            const parsed = path.parse(replaceId);
            targetDir = path.resolve(typeDir, parsed.dir);
            finalFilename = optimizeAsImage
                ? withExtension(parsed.base, '.webp')
                : sanitizeFilename(parsed.base);
            oldPathToRemove = oldFullPath;
        } else if (customFilename) {
            customFilename = sanitizeFilename(customFilename);
            if (optimizeAsImage) {
                finalFilename = customFilename;
            } else {
                const ext = path.extname(file.name);
                finalFilename = customFilename.endsWith(ext) ? customFilename : `${customFilename}${ext}`;
            }
        } else {
            finalFilename = `${Date.now()}-${sanitizeFilename(file.name)}`;
        }

        if (optimizeAsImage) {
            finalFilename = withExtension(finalFilename, '.webp');
        }

        if (!isInside(typeDir, targetDir)) {
            return new Response('Invalid upload path', { status: 400 });
        }

        if (!fs.existsSync(targetDir)) {
            fs.mkdirSync(targetDir, { recursive: true });
        }

        const fullPath = path.resolve(targetDir, finalFilename);
        if (!isInside(typeDir, fullPath)) {
            return new Response('Invalid file path', { status: 400 });
        }

        const arrayBuffer = await file.arrayBuffer();
        const inputBuffer = Buffer.from(arrayBuffer);
        const outputBuffer = optimizeAsImage
            ? await optimizeImageToWebp(inputBuffer)
            : inputBuffer;

        fs.writeFileSync(fullPath, outputBuffer);

        if (oldPathToRemove && oldPathToRemove !== fullPath && fs.existsSync(oldPathToRemove) && fs.statSync(oldPathToRemove).isFile()) {
            fs.unlinkSync(oldPathToRemove);
        }

        const relativeId = path.relative(typeDir, fullPath).split(path.sep).join('/');

        return new Response(JSON.stringify({
            id: relativeId,
            value: finalFilename,
            src: `/api/storage/file/${type}/${relativeId}`,
            thumb: `/api/storage/file/${type}/${relativeId}`,
            type,
            size: outputBuffer.length
        }), {
            status: 200,
            headers: {
                'Content-Type': 'application/json'
            }
        });

    } catch (err: any) {
        console.error('Upload Error:', err);
        return new Response(err.message || 'Server Error', { status: 500 });
    }
};
