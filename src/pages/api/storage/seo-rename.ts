import type { APIRoute } from 'astro';
import fs from 'fs';
import path from 'path';
import { dbQuery } from '@/lib/server/supabaseDb';
import { requireStorageAdminRequest } from '@/lib/server/storageAdminAuth';
import { LOCAL_UPLOAD_ROOT } from '@/lib/server/localUploadStorage';
import { renameLocalStorageFile } from '@/lib/server/localStorageProxy';
import {
    getStorageSettings,
    isLocalStorageActive,
    isRemoteStorageActive,
    localBackupEnabled,
    renameLocalMediaRecord,
    renameStorageMediaRecord,
    type StorageMediaProvider,
} from '@/lib/server/storageSettings';
import { activeRemoteProvider, deleteRemoteStorageFile, deleteRemoteStorageRenameSources, remoteObjectExists, renameRemoteStorageFile } from '@/lib/server/remoteObjectStorage';
import { geminiFastModelAttempts, geminiThinkingConfigForModel, isGeminiFallbackWorthTrying, normalizeGeminiModelName } from '@/lib/geminiModelFallback';
import { buildSeoFilenameFallback, cleanAiScalarText, extractJsonStringField, isBoilerplateAiText, isTechnicalMediaText, toSeoSlug } from '@/lib/mediaSeoText';
import { fetchMediaSeoSystemPrompt } from '@/lib/server/mediaSeoPrompt';

const STORAGE_TYPES = ['image', 'video', 'audio', 'file', 'logo', 'profile'] as const;
type StorageType = typeof STORAGE_TYPES[number];

const STORAGE_FILE_MARKER = '/api/storage/file/';
const LOCAL_STATIC_MARKER = '/local-upload/';
const JSON_HEADERS = { 'Content-Type': 'application/json' };
const AI_REQUEST_TIMEOUT_MS = 24_000;
const MAX_AI_IMAGE_BYTES = 4_000_000;

const MEDIA_SEO_FILENAME_SCHEMA = {
    type: 'object',
    properties: {
        filename: {
            type: 'string',
            description: 'Uzantisiz, ASCII, kisa ve benzersiz SEO dosya adi kokudur.',
        },
    },
    required: ['filename'],
} as const;

const json = (body: unknown, status = 200) =>
    new Response(JSON.stringify(body), { status, headers: JSON_HEADERS });

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

const getStorageType = (value: unknown): StorageType | null => {
    return typeof value === 'string' && STORAGE_TYPES.includes(value as StorageType)
        ? value as StorageType
        : null;
};

const isInside = (baseDir: string, targetPath: string) => {
    const relative = path.relative(baseDir, targetPath);
    return relative === '' || (!relative.startsWith('..') && !path.isAbsolute(relative));
};

const stripUrlNoise = (value: string) => value.split(/[?#]/)[0];

const parseStorageRef = (src: string, typeHint?: unknown): { type: StorageType; id: string } | null => {
    if (!src) return null;

    let rawPath = src;
    const cleanSrc = stripUrlNoise(src);
    const markerIndex = cleanSrc.indexOf(STORAGE_FILE_MARKER);
    if (markerIndex >= 0) {
        rawPath = cleanSrc.slice(markerIndex + STORAGE_FILE_MARKER.length);
    } else {
        const localMarkerIndex = cleanSrc.indexOf(LOCAL_STATIC_MARKER);
        if (localMarkerIndex >= 0) {
            rawPath = cleanSrc.slice(localMarkerIndex + LOCAL_STATIC_MARKER.length);
        }
    }

    rawPath = normalizeRelativePath(rawPath);
    if (!rawPath || rawPath.includes('\0')) return null;

    let type = getStorageType(typeHint) || 'image';
    const [firstSegment, ...rest] = rawPath.split('/');
    if (getStorageType(firstSegment) && rest.length > 0) {
        type = firstSegment as StorageType;
        rawPath = rest.join('/');
    }

    return { type, id: rawPath };
};

const walkFiles = (baseDir: string, currentDir = baseDir): string[] => {
    if (!fs.existsSync(currentDir)) return [];
    return fs.readdirSync(currentDir, { withFileTypes: true }).flatMap((entry) => {
        const fullPath = path.join(currentDir, entry.name);
        if (entry.isDirectory()) return walkFiles(baseDir, fullPath);
        if (!entry.isFile()) return [];
        return path.relative(baseDir, fullPath).split(path.sep).join('/');
    });
};

const basenameEquals = (left: string, right: string) => {
    const a = left.normalize('NFC');
    const b = right.normalize('NFC');
    return a === b || a.normalize('NFD') === b.normalize('NFD');
};

const getCandidateId = (baseDir: string, fileId: string) => {
    const candidates = [
        fileId,
        fileId.normalize('NFC'),
        fileId.normalize('NFD')
    ];

    for (const candidate of Array.from(new Set(candidates))) {
        const fullPath = path.resolve(baseDir, candidate);
        if (!isInside(baseDir, fullPath)) continue;
        if (fs.existsSync(fullPath) && fs.statSync(fullPath).isFile()) return candidate;
    }

    const fileName = path.posix.basename(normalizeRelativePath(fileId));
    if (fileName) {
        const matches = walkFiles(baseDir).filter((id) => basenameEquals(path.posix.basename(id), fileName));
        if (matches.length === 1) return matches[0];
        if (matches.length > 1) {
            throw Object.assign(new Error('Multiple local media files match this filename'), { status: 409 });
        }
    }

    return null;
};

const escapeLikePattern = (value: string) =>
    value.replace(/[\\%_]/g, '\\$&');

const buildStorageFormPairs = (
    oldSrc: string,
    newSrc: string,
) => {
    if (!oldSrc.startsWith('/api/storage/file/') || !newSrc.startsWith('/api/storage/file/')) {
        return [{ oldText: oldSrc, newText: newSrc }];
    }

    const oldObjectPath = oldSrc.slice('/api/storage/file/'.length);
    const newObjectPath = newSrc.slice('/api/storage/file/'.length);
    return [
        { oldText: oldSrc, newText: newSrc },
        { oldText: `/local-upload/${oldObjectPath}`, newText: `/local-upload/${newObjectPath}` },
        { oldText: `local-upload/${oldObjectPath}`, newText: `local-upload/${newObjectPath}` },
    ];
};

const updatePostsMediaReferences = async (
    replacements: Array<{ oldSrc: string; newSrc: string }>,
) => {
    const updateTextColumns = ['thumbnail_url', 'media_url', 'content'];
    const updateJsonColumns = ['card_data', 'items', 'faq_data'];
    const changedPostIds = new Set<string>();

    for (const pair of replacements) {
        if (!pair.oldSrc || !pair.newSrc || pair.oldSrc === pair.newSrc) continue;
        const variants = buildStorageFormPairs(pair.oldSrc, pair.newSrc);

        const uniq = new Map<string, { oldText: string; newText: string }>();
        for (const item of variants) {
            if (!item.oldText || !item.newText || item.oldText === item.newText) continue;
            uniq.set(JSON.stringify(item), item);
        }

        for (const { oldText, newText } of uniq.values()) {
            const safeOld = oldText;
            const safeNew = newText;
            const likePattern = `%${escapeLikePattern(safeOld)}%`;
            const conditionParts = [
                ...updateTextColumns.map(
                    (column) => `COALESCE(${column}, '') LIKE $3 ESCAPE '\\'`,
                ),
                ...updateJsonColumns.map(
                    (column) => `COALESCE(${column}::text, '') LIKE $3 ESCAPE '\\'`,
                ),
            ];

            const sets = [
                ...updateTextColumns.map(
                    (column) =>
                        `${column} = NULLIF(REPLACE(COALESCE(${column}, ''), $1, $2), '')`,
                ),
                ...updateJsonColumns.map(
                    (column) =>
                        `${column} = CASE WHEN COALESCE(${column}::text, '') LIKE $3 ESCAPE '\\' THEN (REPLACE(${column}::text, $1, $2))::jsonb ELSE ${column} END`,
                ),
            ];

            const result = await dbQuery<{ id: string }>(`
                UPDATE public.posts
                SET ${sets.join(',\n            ')}
                WHERE ${conditionParts.join('\n          OR ')}
                RETURNING id
            `, [safeOld, safeNew, likePattern]);
            for (const row of result.rows) {
                if (row.id != null) changedPostIds.add(String(row.id));
            }
        }
    }

    return { updatedPosts: changedPostIds.size };
};

const fetchAiSettings = async (languageCode: string) => {
    const result = await dbQuery<{ google_ai_api_key: string | null; google_ai_model: string | null }>(
        `SELECT google_ai_api_key, google_ai_model
         FROM public.site_settings
         WHERE language_code = $1
         LIMIT 1`,
        [languageCode || 'tr']
    );

    if (result.rows[0]?.google_ai_api_key) return result.rows[0];

    const fallback = await dbQuery<{ google_ai_api_key: string | null; google_ai_model: string | null }>(
        `SELECT google_ai_api_key, google_ai_model
         FROM public.site_settings
         WHERE google_ai_api_key IS NOT NULL AND google_ai_api_key <> ''
         ORDER BY CASE WHEN language_code = 'tr' THEN 0 ELSE 1 END
         LIMIT 1`
    );

    return fallback.rows[0] || null;
};

const typedContextText = (value: unknown) => {
    if (!value || typeof value !== 'object' || Array.isArray(value)) return '';
    const input = value as Record<string, unknown>;
    const lines: string[] = [];
    const add = (label: string, raw: unknown) => {
        const text = Array.isArray(raw)
            ? raw.map((item) => String(item || '').trim()).filter(Boolean).join(', ')
            : String(raw || '').trim();
        if (text) lines.push(`${label}: ${text}`);
    };
    add('Haber başlığı', input.title);
    add('Kısa özet', input.summary);
    add('SEO başlık', input.seoTitle);
    add('Meta açıklama', input.metaDescription);
    add('Odak anahtar kelimeler', input.focusKeywords);
    add('Kategori yolu', input.categoryPath);
    add('Aktif haber tipi', input.formatType);
    const blocks = Array.isArray(input.contentBlocks) ? input.contentBlocks : [];
    if (blocks.length) lines.push('Haber içerik blokları:');
    for (const block of blocks.slice(0, 80)) {
        if (!block || typeof block !== 'object' || Array.isArray(block)) continue;
        const row = block as Record<string, unknown>;
        lines.push('---');
        add('Blok tipi', row.type);
        add('Blok başlığı', row.title);
        add('Blok metni', row.text);
        add('Blok kaynağı', row.source);
    }
    return lines.join('\n').trim();
};

const imageMimeTypeForPath = (filePath: string) => {
    const ext = path.extname(filePath).toLowerCase();
    if (ext === '.jpg' || ext === '.jpeg') return 'image/jpeg';
    if (ext === '.png') return 'image/png';
    if (ext === '.webp') return 'image/webp';
    return '';
};

const prepareInlineImage = async (filePath: string) => {
    const stat = fs.statSync(filePath);
    const mimeType = imageMimeTypeForPath(filePath);
    if (!mimeType || stat.size <= 0 || stat.size > MAX_AI_IMAGE_BYTES) return null;
    const buffer = fs.readFileSync(filePath);

    return {
        mimeType,
        data: buffer.toString('base64')
    };
};

const buildPrompt = (input: {
    context: string;
    currentName: string;
    mediaKind: string;
    type: StorageType;
    hasImage: boolean;
}) => `
	Aşağıdaki medya için SEO uyumlu tek dosya adı kökü üret.

	Kurallar:
	- Çıktı SADECE JSON olsun: {"filename":"kisa-seo-dosya-adi"}
- JSON öncesine veya sonrasına açıklama, "Here is the JSON requested", markdown, kod bloğu, yorum, not veya Türkçe/İngilizce giriş cümlesi yazma.
- Uzantı yazma. .webp, .jpg, .mp4 gibi ekleme.
- Türkçe karakter kullanma; ASCII küçük harf, rakam ve tire kullan.
- 4-10 kelime arası, 80 karakteri geçmeyen, okunabilir ve haberle birebir alakalı bir ad üret.
- Google SEO, Yandex SEO, Google Images, Discover ve AI crawler anlayışı için somut kişi/yer/konu/olay kelimelerini öne al.
- "image", "foto", "resim", "whatsapp", "img", "edited", "screenshot", tarih-saat, rastgele sayı gibi anlamsız kelimeleri kullanma.
- Clickbait, iddia, abartı veya olmayan bilgi ekleme.
- Görsel verisi eklendiyse görseldeki kişi, kurum, mekan ve ana nesneyi doğrudan analiz et.
- Haber bağlamında açık olan kişi/kurum/yer bilgilerini, görselle çelişmiyorsa dosya adında kullan.
- Haber metninde belirsizse mevcut dosya adından ve medya türünden güvenli çıkarım yap; uydurma isim/kurum ekleme.

Medya türü: ${input.type}
Medya konumu: ${input.mediaKind}
Görsel verisi eklendi mi: ${input.hasImage ? 'evet' : 'hayır'}
Mevcut dosya adı: ${input.currentName}

Haber bağlamı:
${input.context}
`;

const extractAiFilename = (text: string) => {
    const jsonFilename = cleanAiScalarText(extractJsonStringField(text, 'filename'));
    if (jsonFilename) return jsonFilename;

    return cleanAiScalarText(String(text || ''));
};

const shouldRetryTextOnly = (result: { ok: boolean; status?: number; message?: unknown }) => {
    if (result.ok || result.status !== 400) return false;
    const message = String(result.message || '').toLowerCase();
    return (
        message.includes('inline') ||
        message.includes('image') ||
        message.includes('mime') ||
        message.includes('data') ||
        message.includes('invalid')
    );
};

const usableSeoFilename = (value: string) => {
    if (!value) return false;
    if (isBoilerplateAiText(value)) return false;
    if (isTechnicalMediaText(value)) return false;
    return true;
};

const generateSeoName = async (input: {
    apiKey: string;
    model: string;
    context: string;
	    currentName: string;
	    mediaKind: string;
	    type: StorageType;
	    inlineImage: { mimeType: string; data: string } | null;
	    systemPrompt: string;
		}) => {
	    const prompt = buildPrompt({ ...input, hasImage: Boolean(input.inlineImage) });
	    const makePayload = (modelId: string, inlineImage = input.inlineImage) => {
	        const parts: Array<any> = [{ text: prompt }];
	        if (inlineImage) {
	            parts.push({
	                inlineData: {
	                    mimeType: inlineImage.mimeType,
	                    data: inlineImage.data
	                }
	            });
	        }
		        const generationConfig: Record<string, unknown> = {
		            temperature: 0.2,
		            topK: 32,
		            topP: 0.9,
		            maxOutputTokens: 160,
		            responseMimeType: 'application/json',
		            responseSchema: MEDIA_SEO_FILENAME_SCHEMA,
		        };
	        const thinkingConfig = geminiThinkingConfigForModel(modelId);
	        if (thinkingConfig) generationConfig.thinkingConfig = thinkingConfig;
	        return {
	            system_instruction: {
	                parts: [{ text: input.systemPrompt.trim() || 'Medya SEO uzmanısın.' }],
	            },
	            contents: [{ role: 'user', parts }],
	            generationConfig,
	        };
	    };

    const call = async (apiVersion: 'v1beta' | 'v1', modelId: string, inlineImage = input.inlineImage) => {
	        const response = await fetch(
            `https://generativelanguage.googleapis.com/${apiVersion}/models/${encodeURIComponent(modelId)}:generateContent?key=${encodeURIComponent(input.apiKey)}`,
            {
	                method: 'POST',
	                headers: { 'Content-Type': 'application/json' },
	                body: JSON.stringify(makePayload(modelId, inlineImage)),
	                signal: AbortSignal.timeout(AI_REQUEST_TIMEOUT_MS)
	            }
	        );
        const data = await response.json().catch(() => ({}));
        if (!response.ok || data?.error) {
            const message = data?.error?.message || `Gemini HTTP ${response.status}`;
            return { ok: false as const, status: response.status, message, modelId, usedVision: Boolean(inlineImage) };
        }
        return { ok: true as const, data, modelId, usedVision: Boolean(inlineImage) };
    };

    const modelQueue = geminiFastModelAttempts(input.model || 'gemini-2.5-flash');
    const fallbackFilename = buildSeoFilenameFallback({
        context: input.context,
        currentName: input.currentName,
        mediaKind: input.mediaKind
    });

    let result: Awaited<ReturnType<typeof call>> | null = null;
    for (let index = 0; index < modelQueue.length; index++) {
        const modelId = modelQueue[index];
        try {
            result = await call('v1beta', modelId);
            if (!result.ok && result.status === 404) result = await call('v1', modelId);
            if (!result.ok && input.inlineImage && shouldRetryTextOnly(result)) {
                result = await call('v1beta', modelId, null);
                if (!result.ok && result.status === 404) result = await call('v1', modelId, null);
            }
        } catch (error: any) {
            result = {
                ok: false as const,
                status: error?.name === 'TimeoutError' ? 408 : 0,
                message: error?.message || 'Gemini request failed',
                modelId,
                usedVision: Boolean(input.inlineImage),
            };
        }
        if (!result) continue;
        if (result.ok) {
            const aiText = result.data?.candidates?.[0]?.content?.parts?.[0]?.text || '';
            const aiFilename = extractAiFilename(aiText);
            const selectedSlug = toSeoSlug(aiFilename, '');
            if (usableSeoFilename(selectedSlug)) {
                return {
                    filename: selectedSlug,
                    generationMode: 'ai' as const,
                    modelUsed: result.modelId,
                    usedVision: result.usedVision,
                    fallbackReason: '',
                };
            }
            result = {
                ok: false as const,
                status: 422,
                message: 'Gemini returned unusable media filename',
                modelId,
                usedVision: result.usedVision,
            };
        }

        const canTryFallback = index < modelQueue.length - 1 && isGeminiFallbackWorthTrying(result.status, result.message);
        if (canTryFallback || result.status === 422) continue;
        break;
    }

    const fallbackReason = result?.message
        ? String(result.message).slice(0, 240)
        : 'Gemini did not return a usable filename';
    return {
        filename: usableSeoFilename(fallbackFilename) ? fallbackFilename : 'haber-gorseli',
        generationMode: 'fallback' as const,
        modelUsed: result?.modelId || '',
        usedVision: false,
        fallbackReason,
    };
};

type LocalRenameReplacement = {
    oldId: string;
    newId: string;
    oldSrc: string;
    newSrc: string;
    oldPublicSrc?: string;
    newPublicSrc?: string;
    value?: string;
    path?: string;
    size?: number;
    contentType?: string;
    thumb?: string;
    type?: StorageType;
};

const normalizeRenameReplacements = (value: unknown): LocalRenameReplacement[] => {
    if (!Array.isArray(value)) return [];
    return value
        .filter((item): item is Record<string, unknown> => Boolean(item) && typeof item === 'object')
        .map((item) => ({
            oldId: String(item.oldId || ''),
            newId: String(item.newId || ''),
            oldSrc: String(item.oldSrc || ''),
            newSrc: String(item.newSrc || ''),
            oldPublicSrc: String(item.oldPublicSrc || ''),
            newPublicSrc: String(item.newPublicSrc || ''),
            value: String(item.value || ''),
            path: String(item.path || ''),
            size: Number(item.size || 0),
            contentType: String(item.contentType || ''),
            thumb: String(item.thumb || ''),
            type: getStorageType(item.type) || undefined,
        }))
        .filter((item) => item.oldId && item.newId && item.oldSrc && item.newSrc);
};

const mediaRecordForReplacement = (
    type: StorageType,
    replacement: LocalRenameReplacement,
) => ({
    oldId: replacement.oldId,
    id: replacement.newId,
    type: replacement.type || type,
    value: replacement.value || path.posix.basename(replacement.newId),
    path: replacement.path || path.posix.dirname(replacement.newId),
    size: Number.isFinite(replacement.size) ? replacement.size || 0 : 0,
    contentType: replacement.contentType || '',
    src: replacement.newSrc,
    publicSrc: replacement.newPublicSrc || replacement.newSrc,
    thumb: replacement.thumb || replacement.newSrc,
});

const updateLocalMediaRecords = async (
    type: StorageType,
    replacements: LocalRenameReplacement[],
) => {
    for (const replacement of replacements) {
        await renameLocalMediaRecord(mediaRecordForReplacement(type, replacement));
    }
};

const MEDIA_FETCH_TIMEOUT_MS = 12_000;

const inlineMimeForContentType = (contentType: string) => {
    const normalized = contentType.split(';')[0].trim().toLowerCase();
    if (normalized === 'image/jpeg' || normalized === 'image/jpg') return 'image/jpeg';
    if (normalized === 'image/png') return 'image/png';
    if (normalized === 'image/webp') return 'image/webp';
    return '';
};

// Workers-safe vision input: downloads the served image over HTTP (works for
// both R2 and locally-backed files, with no filesystem dependency) and inlines
// it as base64, mirroring the proven automatic-news image proxy. Returns null on
// any problem so the AI can still run text-only.
const fetchInlineImageFromUrl = async (src: string, requestUrl: string) => {
    let absolute = '';
    try {
        const parsed = new URL(src);
        if (parsed.protocol === 'http:' || parsed.protocol === 'https:') absolute = parsed.toString();
    } catch {
        // Relative storage paths are resolved against the request origin below.
    }
    if (!absolute) {
        try {
            absolute = new URL(src, new URL(requestUrl).origin).toString();
        } catch {
            return null;
        }
    }

    try {
        const response = await fetch(absolute, {
            signal: AbortSignal.timeout(MEDIA_FETCH_TIMEOUT_MS),
            headers: {
                Accept: 'image/*,*/*;q=0.8',
                'User-Agent': 'PateezAdmin/1.0 (+https://pateeznews.com)',
            },
            redirect: 'follow',
        });
        if (!response.ok) return null;
        const mimeType = inlineMimeForContentType(response.headers.get('content-type') || '');
        if (!mimeType) return null;
        const buffer = await response.arrayBuffer();
        if (!buffer.byteLength || buffer.byteLength > MAX_AI_IMAGE_BYTES) return null;
        return { mimeType, data: Buffer.from(new Uint8Array(buffer)).toString('base64') };
    } catch {
        return null;
    }
};

const apiStorageFilePath = (type: StorageType, id: string) => `/api/storage/file/${type}/${id}`;

const stripExtension = (value: string) => {
    const dotIndex = value.lastIndexOf('.');
    return dotIndex > 0 ? value.slice(0, dotIndex) : value;
};

// Picks the first collision-free key on the remote bucket (base, base-2, …) so
// a generated SEO name never overwrites a different existing object.
const chooseUniqueRemoteBase = async (
    settings: Awaited<ReturnType<typeof getStorageSettings>>,
    type: StorageType,
    oldId: string,
    requestedBase: string,
    ext: string,
    dirPrefix: string,
) => {
    for (let attempt = 0; attempt < 50; attempt += 1) {
        const candidate = attempt === 0 ? requestedBase : `${requestedBase}-${attempt + 1}`;
        const candidateId = `${dirPrefix}${candidate}${ext}`;
        if (candidateId === oldId) return candidate;
        const exists = await remoteObjectExists(settings, type, candidateId).catch(() => true);
        if (!exists) return candidate;
    }
    return `${requestedBase}-${Date.now()}`;
};

const remoteReplacement = (type: StorageType, oldId: string, newId: string): LocalRenameReplacement => ({
    oldId,
    newId,
    oldSrc: apiStorageFilePath(type, oldId),
    newSrc: apiStorageFilePath(type, newId),
    oldPublicSrc: apiStorageFilePath(type, oldId),
    newPublicSrc: apiStorageFilePath(type, newId),
    value: path.posix.basename(newId),
    path: path.posix.dirname(newId),
    size: 0,
    contentType: '',
    thumb: apiStorageFilePath(type, newId),
    type,
});

// The main object plus, for videos, every possible thumbnail key. The main
// object is required; thumbnails are optional variants.
const buildRemoteReplacements = (type: StorageType, oldId: string, newId: string): LocalRenameReplacement[] => {
    const main = remoteReplacement(type, oldId, newId);
    if (type !== 'video') return [main];
    const oldRoot = stripExtension(oldId);
    const newRoot = stripExtension(newId);
    const thumbs = ['.webp', '.jpg', '.jpeg', '.png'].map((thumbExt) =>
        remoteReplacement(type, `${oldRoot}_thumb${thumbExt}`, `${newRoot}_thumb${thumbExt}`),
    );
    return [main, ...thumbs];
};

export const POST: APIRoute = async ({ request }) => {
    try {
        const body = await request.json().catch(() => ({}));
        const src = String(body?.src || '').trim();
        const ref = parseStorageRef(src, body?.type);
        if (!ref) return json({ error: 'Storage file reference required' }, 400);
        await requireStorageAdminRequest(request, ref.type);

        const settings = await getStorageSettings();
        const remoteActive = isRemoteStorageActive(settings);
        const localActive = isLocalStorageActive(settings);
        if (!remoteActive && !localActive) {
            return json({ error: `Storage provider is not implemented: ${settings.activeStorage}` }, 501);
        }

        // A local file (dev / local backup) is optional. On Cloudflare Workers and
        // remote-only setups there is no filesystem, so it is never required —
        // the remote bucket is the source of truth.
        const baseDir = path.resolve(LOCAL_UPLOAD_ROOT, ref.type);
        let candidateId: string | null = null;
        try {
            candidateId = getCandidateId(baseDir, ref.id);
        } catch {
            candidateId = null;
        }
        const localPath = candidateId ? path.resolve(baseDir, candidateId) : null;
        const effectiveId = candidateId || ref.id;

        const languageCode = String(body?.languageCode || 'tr').trim() || 'tr';
        // `filename` lets the admin commit an explicit, user-edited name (no AI
        // call). `suggestOnly` returns an AI proposal without renaming anything,
        // so the modal can pre-fill an editable field before the user confirms.
        const manualName = String(body?.filename || '').trim();
        const suggestOnly = body?.suggestOnly === true;
        const aiSettings = await fetchAiSettings(languageCode);
        const aiApiKey = aiSettings?.google_ai_api_key || '';
        if (!manualName && !aiApiKey) return json({ error: 'Google AI API key not configured' }, 400);

        const currentName = path.posix.basename(effectiveId);
        const structuredContext = typedContextText(body?.contextJson);
        const rawContext = String(body?.context || '').trim();
        const context = [structuredContext, rawContext]
            .filter(Boolean)
            .join('\n')
            .slice(0, 6000);
        const mediaKind = String(body?.mediaKind || 'haber medyası').slice(0, 120);
        const model = normalizeGeminiModelName(aiSettings?.google_ai_model) || 'gemini-2.5-flash';

        let requestedBase: string;
        let generationMode: 'manual' | 'ai' | 'fallback' = manualName ? 'manual' : 'fallback';
        let modelUsed = '';
        let usedVision = false;
        let fallbackReason = '';
        if (manualName) {
            requestedBase = toSeoSlug(stripExtension(manualName), '');
            if (!usableSeoFilename(requestedBase)) {
                return json({ error: 'Provided filename is not a valid SEO name' }, 400);
            }
        } else {
            const systemPrompt = await fetchMediaSeoSystemPrompt(languageCode);
            let inlineImage: { mimeType: string; data: string } | null = null;
            if (ref.type === 'image') {
                if (localPath && isInside(baseDir, localPath)) {
                    try {
                        inlineImage = await prepareInlineImage(localPath);
                    } catch {
                        inlineImage = null;
                    }
                }
                if (!inlineImage) inlineImage = await fetchInlineImageFromUrl(src, request.url);
            }
            const generated = await generateSeoName({
                apiKey: aiApiKey,
                model,
                context,
                currentName,
                mediaKind,
                type: ref.type,
                inlineImage,
                systemPrompt,
            });
            requestedBase = generated.filename;
            generationMode = generated.generationMode;
            modelUsed = generated.modelUsed;
            usedVision = generated.usedVision;
            fallbackReason = generated.fallbackReason;
        }

        if (suggestOnly) {
            return json({
                success: true,
                suggestion: true,
                filename: requestedBase,
                src: apiStorageFilePath(ref.type, effectiveId),
                replacements: [],
                generationMode,
                modelUsed,
                usedVision,
                fallbackReason,
            });
        }

        // ── Google Drive metadata rename (file id stays stable) ──────────────
        if (settings.activeStorage === 'googleDrive') {
            const exists = await remoteObjectExists(settings, ref.type, effectiveId);
            if (!exists) return json({ error: 'File not found' }, 404);
            const requireLocalBackup = localBackupEnabled(settings);
            if (requireLocalBackup && !candidateId) {
                return json({
                    error: 'Local backup file not found while local backup is enabled',
                    generationMode,
                    modelUsed,
                    usedVision,
                    fallbackReason,
                    storage: {
                        remoteCopy: 'not-started',
                        remoteDelete: 'not-started',
                        localBackup: 'missing',
                        database: 'not-started',
                    },
                }, 409);
            }

            const ext = path.posix.extname(currentName) || (ref.type === 'video' ? '.mp4' : ref.type === 'audio' ? '.mp3' : ref.type === 'file' ? '' : '.webp');
            const driveFileName = `${requestedBase}${ext}`;
            const renameOutcome = await renameRemoteStorageFile(settings, {
                type: ref.type,
                replacements: [{ oldId: effectiveId, newId: driveFileName, required: true }],
            });
            let localBackupRenamed = 0;
            if (requireLocalBackup && candidateId) {
                const localRenameResult = await renameLocalStorageFile({
                    type: ref.type,
                    id: candidateId,
                    newBase: requestedBase,
                });
                localBackupRenamed = normalizeRenameReplacements(localRenameResult?.replacements).length || 1;
            }
            const stableReplacement = remoteReplacement(ref.type, effectiveId, effectiveId);
            const stableRecord = {
                ...mediaRecordForReplacement(ref.type, stableReplacement),
                value: driveFileName,
                path: '',
            };
            await renameStorageMediaRecord(activeRemoteProvider(settings), stableRecord, { strict: true });
            await renameLocalMediaRecord(stableRecord, { strict: true });

            return json({
                success: true,
                filename: requestedBase,
                src: stableReplacement.newSrc,
                replacements: [],
                dbUpdatedPosts: 0,
                remoteRenamed: renameOutcome.renamed,
                remoteVerified: renameOutcome.verified,
                localBackupRenamed,
                generationMode,
                modelUsed,
                usedVision,
                fallbackReason,
                storage: {
                    remoteCopy: 'metadata-updated',
                    remoteDelete: 'not-needed',
                    localBackup: requireLocalBackup ? 'verified' : 'disabled',
                    database: 'committed',
                },
                remoteError: '',
            });
        }

        // ── Remote-first rename (R2 / S3-compatible / Bunny) ─────────────────
        if (remoteActive) {
            const exists = await remoteObjectExists(settings, ref.type, effectiveId);
            if (!exists) return json({ error: 'File not found' }, 404);
            const requireLocalBackup = localBackupEnabled(settings);
            if (requireLocalBackup && !candidateId) {
                return json({
                    error: 'Local backup file not found while local backup is enabled',
                    generationMode,
                    modelUsed,
                    usedVision,
                    fallbackReason,
                    storage: {
                        remoteCopy: 'not-started',
                        remoteDelete: 'not-started',
                        localBackup: 'missing',
                        database: 'not-started',
                    },
                }, 409);
            }

            const ext = path.posix.extname(effectiveId) || (ref.type === 'video' ? '.mp4' : '.webp');
            const dir = path.posix.dirname(effectiveId);
            const dirPrefix = dir && dir !== '.' ? `${dir}/` : '';
            const uniqueBase = await chooseUniqueRemoteBase(settings, ref.type, effectiveId, requestedBase, ext, dirPrefix);
            const newId = `${dirPrefix}${uniqueBase}${ext}`;

            if (newId === effectiveId) {
                return json({
                    success: true,
                    filename: uniqueBase,
                    src: apiStorageFilePath(ref.type, effectiveId),
                    replacements: [],
                    dbUpdatedPosts: 0,
                    remoteRenamed: 0,
                    remoteError: '',
                    generationMode,
                    modelUsed,
                    usedVision,
                    fallbackReason,
                    storage: {
                        remoteCopy: 'unchanged',
                        remoteDelete: 'not-needed',
                        localBackup: requireLocalBackup ? 'unchanged' : 'disabled',
                        database: 'not-needed',
                    },
                });
            }

            const replacements = buildRemoteReplacements(ref.type, effectiveId, newId);
            const renameOutcome = await renameRemoteStorageFile(settings, {
                type: ref.type,
                replacements: replacements.map(({ oldId, newId: nextId }, index) => ({
                    oldId,
                    newId: nextId,
                    required: index === 0,
                })),
            });

            const mainReplacement = replacements[0];
            let localBackupRenamed = 0;
            let localBackupRollback: LocalRenameReplacement[] = [];
            let mediaUpdateResult = { updatedPosts: 0 };
            try {
                if (requireLocalBackup && candidateId) {
                    const localRenameResult = await renameLocalStorageFile({
                        type: ref.type,
                        id: candidateId,
                        newBase: uniqueBase,
                    });
                    localBackupRollback = normalizeRenameReplacements(localRenameResult?.replacements);
                    localBackupRenamed = localBackupRollback.length || 1;
                }

                const providers: StorageMediaProvider[] = [activeRemoteProvider(settings)];
                if (requireLocalBackup) providers.push('localStorage');
                for (const provider of providers) {
                    await renameStorageMediaRecord(provider, mediaRecordForReplacement(ref.type, mainReplacement), { strict: true });
                }
                await renameLocalMediaRecord(mediaRecordForReplacement(ref.type, mainReplacement), { strict: true });

                mediaUpdateResult = await updatePostsMediaReferences(replacements);
            } catch (error) {
                for (const replacement of renameOutcome.copied) {
                    await deleteRemoteStorageFile(settings, { type: ref.type, id: replacement.newId }).catch((cleanupError) => {
                        console.warn('Remote copied object rollback skipped:', cleanupError instanceof Error ? cleanupError.message : cleanupError);
                    });
                }
                for (const replacement of localBackupRollback) {
                    await renameLocalStorageFile({
                        type: replacement.type || ref.type,
                        id: replacement.newId,
                        newBase: stripExtension(path.posix.basename(replacement.oldId)),
                    }).catch((cleanupError) => {
                        console.warn('Local backup rollback skipped:', cleanupError instanceof Error ? cleanupError.message : cleanupError);
                    });
                }
                throw error;
            }

            const remoteCleanup = await deleteRemoteStorageRenameSources(settings, {
                type: ref.type,
                replacements: renameOutcome.copied.map(({ oldId }) => ({ oldId })),
            });

            return json({
                success: true,
                filename: uniqueBase,
                src: mainReplacement.newSrc,
                replacements,
                dbUpdatedPosts: mediaUpdateResult.updatedPosts,
                remoteRenamed: renameOutcome.renamed,
                remoteVerified: renameOutcome.verified,
                remoteCleanupErrors: remoteCleanup.errors,
                localBackupRenamed,
                generationMode,
                modelUsed,
                usedVision,
                fallbackReason,
                storage: {
                    remoteCopy: 'verified',
                    remoteDelete: remoteCleanup.errors.length ? 'pending-cleanup' : 'deleted',
                    localBackup: requireLocalBackup ? 'verified' : 'disabled',
                    database: 'committed',
                },
                remoteError: remoteCleanup.errors.join('; '),
            });
        }

        // ── Local-storage-only rename (dev / self-hosted) ────────────────────
        if (!candidateId) return json({ error: 'File not found' }, 404);
        const renameResult = await renameLocalStorageFile({
            type: ref.type,
            id: candidateId,
            newBase: requestedBase,
        });
        const replacements = normalizeRenameReplacements(renameResult?.replacements);
        const selectedReplacement = replacements.find((item) => item.oldId === candidateId) || replacements[0];
        await updateLocalMediaRecords(ref.type, replacements);
        const mediaUpdateResult = await updatePostsMediaReferences(replacements);

        return json({
            success: true,
            filename: String(renameResult?.filename || requestedBase),
            src: String(renameResult?.src || selectedReplacement?.newSrc || apiStorageFilePath(ref.type, candidateId)),
            replacements,
            dbUpdatedPosts: mediaUpdateResult.updatedPosts,
            remoteRenamed: 0,
            remoteVerified: 0,
            localBackupRenamed: replacements.length,
            generationMode,
            modelUsed,
            usedVision,
            fallbackReason,
            storage: {
                remoteCopy: 'disabled',
                remoteDelete: 'not-needed',
                localBackup: 'verified',
                database: 'committed',
            },
            remoteError: '',
        });
    } catch (error: any) {
        if ((error?.status || 500) >= 500) console.error('SEO Rename Error:', error);
        return json({ error: error.message || 'SEO rename failed' }, error?.status || 500);
    }
};
