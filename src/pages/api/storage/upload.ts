import type { APIRoute } from 'astro';
import { spawn } from 'child_process';
import fs from 'fs';
import os from 'os';
import path from 'path';
import ffmpegStaticPath from 'ffmpeg-static';
import sharp from 'sharp';
import { setStorageUploadProgress } from '../../../lib/server/storageUploadProgress';
import {
    MEDIA_BUCKET,
    STORAGE_TYPES,
    contentTypeForFilename,
    getStorageType,
    normalizeStoragePath,
    relativeStorageId,
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
const VIDEO_EXTENSIONS = new Set(['.mp4', '.webm', '.mov', '.avi', '.m4v', '.mkv']);
const VIDEO_CRF = 21;
const VIDEO_PRESET = 'slow';
const VIDEO_THUMB_WIDTH = 1280;
const VIDEO_THUMB_QUALITY = 86;

const ffmpegPath = process.env.FFMPEG_PATH || process.env.FFMPEG_BIN || ffmpegStaticPath || 'ffmpeg';

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

const shouldOptimizeVideo = (type: StorageType, file: File) => {
    const ext = path.posix.extname(file.name || '').toLowerCase();
    return type === 'video' && (file.type.startsWith('video/') || VIDEO_EXTENSIONS.has(ext));
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

const durationPattern = /Duration:\s*(\d+):(\d+):(\d+(?:\.\d+)?)/;

const secondsFromDurationText = (value: string) => {
    const match = durationPattern.exec(value);
    if (!match) return null;
    const [, hours, minutes, seconds] = match;
    return Number(hours) * 3600 + Number(minutes) * 60 + Number(seconds);
};

const secondsFromOutTimeText = (value: string) => {
    const parts = value.trim().split(':');
    if (parts.length !== 3) return null;
    return Number(parts[0]) * 3600 + Number(parts[1]) * 60 + Number(parts[2]);
};

const getVideoDurationSeconds = (inputPath: string) => new Promise<number | null>((resolve) => {
    const child = spawn(ffmpegPath, ['-hide_banner', '-i', inputPath], { windowsHide: true });
    const stderr: Buffer[] = [];

    child.stderr.on('data', (chunk) => {
        stderr.push(Buffer.from(chunk));
    });

    child.on('error', () => resolve(null));
    child.on('close', () => {
        resolve(secondsFromDurationText(Buffer.concat(stderr).toString('utf8')));
    });
});

const runFfmpeg = (
    args: string[],
    options: { onProgress?: (seconds: number) => void } = {}
) => new Promise<void>((resolve, reject) => {
    const child = spawn(ffmpegPath, args, { windowsHide: true });
    const stderr: Buffer[] = [];
    let stdoutBuffer = '';

    child.stderr.on('data', (chunk) => {
        if (stderr.reduce((sum, item) => sum + item.length, 0) < 12000) {
            stderr.push(Buffer.from(chunk));
        }
    });

    child.stdout.on('data', (chunk) => {
        if (!options.onProgress) return;
        stdoutBuffer += Buffer.from(chunk).toString('utf8');
        const lines = stdoutBuffer.split(/\r?\n/);
        stdoutBuffer = lines.pop() ?? '';
        for (const line of lines) {
            const [key, rawValue] = line.split('=');
            const value = rawValue?.trim();
            if (!key || !value) continue;
            if (key === 'out_time_us' || key === 'out_time_ms') {
                const numeric = Number(value);
                if (Number.isFinite(numeric)) options.onProgress(numeric / 1_000_000);
            } else if (key === 'out_time') {
                const seconds = secondsFromOutTimeText(value);
                if (seconds !== null && Number.isFinite(seconds)) options.onProgress(seconds);
            } else if (key === 'progress' && value === 'end') {
                options.onProgress(Number.POSITIVE_INFINITY);
            }
        }
    });

    child.on('error', reject);
    child.on('close', (code) => {
        if (code === 0) {
            resolve();
            return;
        }
        const message = Buffer.concat(stderr).toString('utf8').trim();
        reject(new Error(message || `FFmpeg exited with code ${code}`));
    });
});

const optimizeVideoToMp4 = async (
    inputPath: string,
    outputPath: string,
    uploadId: string | null
) => {
    const durationSeconds = await getVideoDurationSeconds(inputPath);
    const startedAt = Date.now();

    await runFfmpeg([
        '-y',
        '-hide_banner',
        '-loglevel', 'error',
        '-nostats',
        '-progress', 'pipe:1',
        '-i', inputPath,
        '-map', '0:v:0',
        '-map', '0:a?',
        '-map_metadata', '-1',
        '-vf', "scale='min(3840,iw)':'min(2160,ih)':force_original_aspect_ratio=decrease:force_divisible_by=2",
        '-c:v', 'libx264',
        '-preset', VIDEO_PRESET,
        '-crf', String(VIDEO_CRF),
        '-pix_fmt', 'yuv420p',
        '-profile:v', 'high',
        '-level:v', '5.2',
        '-movflags', '+faststart',
        '-c:a', 'aac',
        '-b:a', '160k',
        '-ar', '48000',
        '-ac', '2',
        outputPath
    ], {
        onProgress: (seconds) => {
            if (!uploadId || !durationSeconds || durationSeconds <= 0) return;
            const done = seconds === Number.POSITIVE_INFINITY;
            const progress = done ? 0.98 : Math.min(Math.max(seconds / durationSeconds, 0), 0.98);
            const elapsedSeconds = (Date.now() - startedAt) / 1000;
            const etaSeconds = progress > 0 && !done
                ? (elapsedSeconds / progress) * (1 - progress)
                : null;

            setStorageUploadProgress(uploadId, {
                phase: 'processing',
                progress,
                etaSeconds,
            });
        },
    });
};

const createVideoThumbnailWebp = async (videoPath: string, thumbPath: string) => {
    const tempPng = path.join(
        os.tmpdir(),
        `pateez-thumb-${Date.now()}-${Math.random().toString(16).slice(2)}.png`
    );

    const hasUsableFrame = () => fs.existsSync(tempPng) && fs.statSync(tempPng).size > 0;

    try {
        try {
            await runFfmpeg([
                '-y',
                '-hide_banner',
                '-loglevel', 'error',
                '-i', videoPath,
                '-ss', '00:00:01.000',
                '-frames:v', '1',
                '-vf', `scale='min(${VIDEO_THUMB_WIDTH},iw)':-2`,
                tempPng
            ]);
        } catch {
            // Short or unusual videos can fail at the 1s seek point; retry from the first frame below.
        }

        if (!hasUsableFrame()) {
            await runFfmpeg([
                '-y',
                '-hide_banner',
                '-loglevel', 'error',
                '-i', videoPath,
                '-frames:v', '1',
                '-vf', `scale='min(${VIDEO_THUMB_WIDTH},iw)':-2`,
                tempPng
            ]);
        }

        if (!hasUsableFrame()) {
            throw new Error('Video thumbnail frame could not be generated');
        }

        const thumbBuffer = await sharp(tempPng)
            .rotate()
            .resize({
                width: VIDEO_THUMB_WIDTH,
                fit: 'inside',
                withoutEnlargement: true,
                kernel: 'lanczos3',
            })
            .webp({
                quality: VIDEO_THUMB_QUALITY,
                effort: WEBP_EFFORT,
                smartSubsample: true,
                smartDeblock: true,
                preset: 'photo',
            })
            .toBuffer();

        fs.writeFileSync(thumbPath, thumbBuffer);
    } finally {
        if (fs.existsSync(tempPng)) fs.unlinkSync(tempPng);
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
    const tempFiles: string[] = [];

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
        const optimizeAsVideo = shouldOptimizeVideo(type, file);

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
            finalFilename = optimizeAsVideo
                ? withExtension(parsed.base, '.mp4')
                : optimizeAsImage
                    ? withExtension(parsed.base, '.webp')
                    : sanitizeFilename(parsed.base);
            oldObjectPathToRemove = storageObjectPath(type, replaceId);
        } else if (customFilename) {
            customFilename = sanitizeFilename(customFilename);
            if (optimizeAsVideo || optimizeAsImage) {
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
        } else if (optimizeAsVideo) {
            finalFilename = withExtension(finalFilename, '.mp4');
        }

        const relativeId = [targetPrefix, finalFilename].filter(Boolean).join('/');
        const objectPath = storageObjectPath(type, relativeId);

        const arrayBuffer = await file.arrayBuffer();
        const inputBuffer = Buffer.from(arrayBuffer);
        let outputSize = inputBuffer.length;
        let thumbRelativeId: string | null = null;

        if (optimizeAsVideo) {
            setStorageUploadProgress(uploadId, {
                phase: 'processing',
                progress: 0,
                etaSeconds: null,
            });
            const tempInputPath = path.join(
                os.tmpdir(),
                `pateez-video-${Date.now()}-${Math.random().toString(16).slice(2)}${path.posix.extname(file.name) || '.video'}`
            );
            const tempOutputPath = path.join(
                os.tmpdir(),
                `pateez-video-output-${Date.now()}-${Math.random().toString(16).slice(2)}.mp4`
            );
            const tempThumbPath = path.join(
                os.tmpdir(),
                `pateez-video-thumb-${Date.now()}-${Math.random().toString(16).slice(2)}.webp`
            );
            tempFiles.push(tempInputPath, tempOutputPath, tempThumbPath);
            fs.writeFileSync(tempInputPath, inputBuffer);

            await optimizeVideoToMp4(tempInputPath, tempOutputPath, uploadId);
            setStorageUploadProgress(uploadId, {
                phase: 'processing',
                progress: 0.99,
                etaSeconds: null,
            });
            await createVideoThumbnailWebp(tempOutputPath, tempThumbPath);

            const videoBuffer = fs.readFileSync(tempOutputPath);
            const thumbBuffer = fs.readFileSync(tempThumbPath);
            outputSize = videoBuffer.length;
            const thumbObjectPath = videoThumbObjectPathFor(objectPath);
            thumbRelativeId = relativeStorageId(type, thumbObjectPath);

            await uploadObject(client, objectPath, videoBuffer, 'video/mp4');
            await uploadObject(client, thumbObjectPath, thumbBuffer, 'image/webp');
        } else {
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
        }

        if (oldObjectPathToRemove && oldObjectPathToRemove !== objectPath) {
            const paths = [oldObjectPathToRemove];
            if (type === 'video') paths.push(videoThumbObjectPathFor(oldObjectPathToRemove));
            await client.storage.from(MEDIA_BUCKET).remove(paths);
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
            thumb: `/api/storage/file/${type}/${thumbRelativeId || relativeId}`,
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
    } finally {
        for (const filePath of tempFiles) {
            if (fs.existsSync(filePath)) fs.unlinkSync(filePath);
        }
    }
};
