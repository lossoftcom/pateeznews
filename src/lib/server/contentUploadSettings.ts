import { dbQuery } from './supabaseDb';

export type UploadRuleType = 'image' | 'video' | 'audio' | 'file' | 'font';

export interface ContentUploadSettings {
    imageOutputFormat: 'webp' | 'jpeg' | 'png';
    allowedExtensions: Set<string>;
    maxImageBytes: number;
    maxVideoBytes: number;
    maxAudioBytes: number;
    maxFileBytes: number;
}

const MB = 1024 * 1024;

const DEFAULT_ALLOWED_EXTENSIONS = [
    'jpg', 'jpeg', 'webp', 'png', 'gif', 'avif', 'heic', 'svg',
    'mp4', 'm4v', 'webm', 'mov', 'avi', 'mkv', '3gp',
    'mp3', 'wav', 'ogg', 'm4a', 'aac', 'flac', 'opus',
    'pdf', 'doc', 'docx', 'ppt', 'pptx', 'xls', 'xlsx', 'txt', 'csv', 'zip', 'rar',
];

export const IMAGE_UPLOAD_EXTENSIONS = new Set([
    'jpg', 'jpeg', 'webp', 'png', 'gif', 'avif', 'bmp', 'tif', 'tiff', 'heic', 'heif', 'svg',
]);

export const VIDEO_UPLOAD_EXTENSIONS = new Set([
    'mp4', 'm4v', 'webm', 'mov', 'avi', 'mkv', '3gp', '3g2',
]);

export const AUDIO_UPLOAD_EXTENSIONS = new Set([
    'mp3', 'wav', 'ogg', 'oga', 'm4a', 'aac', 'flac', 'opus',
]);

export const FILE_UPLOAD_EXTENSIONS = new Set([
    'pdf', 'doc', 'docx', 'ppt', 'pptx', 'xls', 'xlsx', 'txt', 'csv', 'zip', 'rar',
]);

export function normalizeUploadExtension(value: string) {
    return String(value || '').trim().toLowerCase().replace(/^\.+/, '');
}

export function uploadExtensionFromFilename(filename: string) {
    const clean = String(filename || '').split('?')[0]?.split('#')[0] || '';
    const index = clean.lastIndexOf('.');
    if (index < 0 || index === clean.length - 1) return '';
    return normalizeUploadExtension(clean.slice(index + 1));
}

export function uploadRuleTypeForStorageType(type: string): UploadRuleType {
    if (type === 'video') return 'video';
    if (type === 'audio') return 'audio';
    if (type === 'file') return 'file';
    if (type === 'font') return 'font';
    return 'image';
}

export function allowedExtensionsForRuleType(type: UploadRuleType) {
    if (type === 'video') return VIDEO_UPLOAD_EXTENSIONS;
    if (type === 'audio') return AUDIO_UPLOAD_EXTENSIONS;
    if (type === 'file') return FILE_UPLOAD_EXTENSIONS;
    if (type === 'font') return new Set<string>();
    return IMAGE_UPLOAD_EXTENSIONS;
}

export function maxUploadBytesForRuleType(settings: ContentUploadSettings, type: UploadRuleType) {
    if (type === 'video') return settings.maxVideoBytes;
    if (type === 'audio') return settings.maxAudioBytes;
    if (type === 'file') return settings.maxFileBytes;
    return settings.maxImageBytes;
}

export async function loadContentUploadSettings(languageCode = 'tr'): Promise<ContentUploadSettings> {
    const normalizedLanguageCode = String(languageCode || 'tr').trim() || 'tr';
    try {
        const result = await dbQuery<any>(
            `SELECT content_upload_image_format,
                    content_upload_allowed_extensions,
                    content_upload_max_image_mb,
                    content_upload_max_video_mb,
                    content_upload_max_audio_mb,
                    content_upload_max_file_mb
               FROM public.site_settings
              WHERE language_code = $1
              LIMIT 1`,
            [normalizedLanguageCode],
        );
        const row = result.rows[0] || null;
        return normalizeContentUploadSettings(row);
    } catch {
        return normalizeContentUploadSettings(null);
    }
}

function normalizeContentUploadSettings(row: any): ContentUploadSettings {
    const imageFormat = String(row?.content_upload_image_format || 'webp').trim().toLowerCase();
    const allowedRaw = row?.content_upload_allowed_extensions;
    const allowed = Array.isArray(allowedRaw)
        ? allowedRaw
        : typeof allowedRaw === 'string'
            ? parseAllowedExtensionsString(allowedRaw)
            : DEFAULT_ALLOWED_EXTENSIONS;

    return {
        imageOutputFormat: imageFormat === 'jpeg' || imageFormat === 'jpg'
            ? 'jpeg'
            : imageFormat === 'png'
                ? 'png'
                : 'webp',
        allowedExtensions: new Set(
            allowed
                .map((item) => normalizeUploadExtension(String(item)))
                .filter(Boolean),
        ),
        maxImageBytes: megabytes(row?.content_upload_max_image_mb, 20),
        maxVideoBytes: megabytes(row?.content_upload_max_video_mb, 50),
        maxAudioBytes: megabytes(row?.content_upload_max_audio_mb, 20),
        maxFileBytes: megabytes(row?.content_upload_max_file_mb, 50),
    };
}

function parseAllowedExtensionsString(value: string) {
    try {
        const decoded = JSON.parse(value);
        if (Array.isArray(decoded)) return decoded;
    } catch {
        return value.split(/[\s,;]+/);
    }
    return DEFAULT_ALLOWED_EXTENSIONS;
}

function megabytes(value: unknown, fallback: number) {
    const parsed = Number(value);
    const safe = Number.isFinite(parsed) ? parsed : fallback;
    return Math.min(1024, Math.max(1, Math.round(safe))) * MB;
}
