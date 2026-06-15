import type { APIRoute } from 'astro';
import fs from 'fs';
import path from 'path';
import { dbQuery } from '@/lib/server/supabaseDb';
import { requireStorageAdminRequest } from '@/lib/server/storageAdminAuth';
import { LOCAL_UPLOAD_ROOT } from '@/lib/server/localUploadStorage';
import { geminiFastModelAttempts, geminiThinkingConfigForModel, isGeminiFallbackWorthTrying, normalizeGeminiModelName } from '@/lib/geminiModelFallback';
import { buildAltTextFallback, cleanAiScalarText, extractJsonStringField, htmlToPlainText, isBoilerplateAiText, isTechnicalMediaText } from '@/lib/mediaSeoText';
import { fetchMediaSeoSystemPrompt } from '@/lib/server/mediaSeoPrompt';

const STORAGE_FILE_MARKER = '/api/storage/file/';
const JSON_HEADERS = { 'Content-Type': 'application/json' };
const MAX_CONTEXT_LENGTH = 6000;
const AI_REQUEST_TIMEOUT_MS = 24_000;
const MAX_AI_IMAGE_BYTES = 4_000_000;

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

const stripUrlNoise = (value: string) => value.split(/[?#]/)[0];

const normalizeRelativePath = (value: string) => {
    return safeDecode(value)
        .replace(/\\/g, '/')
        .replace(/^\/+/, '')
        .replace(/^Upload\//i, '');
};

const isInside = (baseDir: string, targetPath: string) => {
    const relative = path.relative(baseDir, targetPath);
    return relative === '' || (!relative.startsWith('..') && !path.isAbsolute(relative));
};

const parseLocalImageRef = (src: string): string | null => {
    const cleanSrc = stripUrlNoise(src);
    const markerIndex = cleanSrc.indexOf(STORAGE_FILE_MARKER);
    if (markerIndex < 0) return null;

    let rawPath = normalizeRelativePath(cleanSrc.slice(markerIndex + STORAGE_FILE_MARKER.length));
    const [firstSegment, ...rest] = rawPath.split('/');
    if (firstSegment === 'image' && rest.length > 0) rawPath = rest.join('/');
    if (!rawPath || rawPath.includes('\0')) return null;
    return rawPath;
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

    return null;
};

const filenameFromSrc = (src: string) => {
    const clean = stripUrlNoise(src);
    const last = clean.split('/').filter(Boolean).pop() || '';
    return safeDecode(last);
};

const sanitizeAltText = (value: string) => {
    const cleaned = htmlToPlainText(value)
        .replace(/```json|```/g, '')
        .replace(/^(alt\s*text|alternatif\s*metin|görsel\s*açıklaması|image\s*alt)\s*[:=-]\s*/i, '')
        .replace(/^["']|["']$/g, '')
        .replace(/\s+/g, ' ')
        .trim();

    if (cleaned.length <= 180) return cleaned;
    return `${cleaned.slice(0, 177).replace(/\s+\S*$/, '').trim()}...`;
};

const extractAltText = (text: string) => {
    const jsonAltText = cleanAiScalarText(extractJsonStringField(text, 'altText'));
    if (jsonAltText) return sanitizeAltText(jsonAltText);

    const scalar = cleanAiScalarText(String(text || ''));
    return scalar ? sanitizeAltText(scalar) : '';
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

const usableAltText = (value: string) => {
    const text = sanitizeAltText(value);
    if (!text) return false;
    if (isBoilerplateAiText(text)) return false;
    if (isTechnicalMediaText(text)) return false;
    return true;
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
    currentAlt: string;
    mediaKind: string;
    hasImage: boolean;
}) => `
	Kapak görseli için tek bir profesyonel Türkçe alt text üret.

	Kurallar:
- Çıktı SADECE JSON olsun: {"altText":"..."}
- JSON öncesine veya sonrasına açıklama, "Here is the JSON requested", markdown, kod bloğu, yorum, not veya giriş cümlesi yazma.
- 90-160 karakter arası, doğal ve tek cümlelik Türkçe yaz.
- Anahtar kelime doldurma yapma; haber bağlamı ve görseldeki ana eylemi net anlat.
- Görsel eklendiyse görseli doğrudan analiz et; görünmeyen kişi, kurum, yer veya olayı uydurma.
- Haber bağlamında açık olan kişi/kurum/yer bilgilerini, görselle çelişmiyorsa kullan.
- "resimde", "fotoğrafta", "görselde" gibi gereksiz başlangıçlardan kaçın.
- "SEO", "kapak görseli", "haber görseli", dosya uzantısı veya teknik ifade yazma.
- Tarafsız, erişilebilirlik dostu ve haber diliyle uyumlu ol.

Medya konumu: ${input.mediaKind}
Görsel verisi eklendi mi: ${input.hasImage ? 'evet' : 'hayır'}
Mevcut dosya adı: ${input.currentName}
Mevcut alt text: ${input.currentAlt || 'yok'}

Haber bağlamı:
${input.context}
`;

const generateAltText = async (input: {
    apiKey: string;
    model: string;
    context: string;
    currentName: string;
	    currentAlt: string;
	    mediaKind: string;
	    inlineImage: { mimeType: string; data: string } | null;
	    systemPrompt: string;
	}) => {
    const prompt = buildPrompt({
        context: input.context,
        currentName: input.currentName,
        currentAlt: input.currentAlt,
        mediaKind: input.mediaKind,
        hasImage: Boolean(input.inlineImage)
    });

	    const makePayload = (modelId: string, inlineImage: typeof input.inlineImage) => {
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
	            temperature: 0.15,
	            topK: 24,
	            topP: 0.85,
	            maxOutputTokens: 180,
	            responseMimeType: 'application/json',
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

    const call = async (apiVersion: 'v1beta' | 'v1', payload: ReturnType<typeof makePayload>, modelId: string) => {
        const response = await fetch(
            `https://generativelanguage.googleapis.com/${apiVersion}/models/${encodeURIComponent(modelId)}:generateContent?key=${encodeURIComponent(input.apiKey)}`,
            {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify(payload),
                signal: AbortSignal.timeout(AI_REQUEST_TIMEOUT_MS)
            }
        );
        const data = await response.json().catch(() => ({}));
        if (!response.ok || data?.error) {
            const message = data?.error?.message || `Gemini HTTP ${response.status}`;
            return { ok: false as const, status: response.status, message, modelId };
        }
        return { ok: true as const, data, modelId };
    };

    const modelQueue = geminiFastModelAttempts(input.model || 'gemini-2.5-flash');
    const fallbackAltText = buildAltTextFallback({
        context: input.context,
        currentName: input.currentName,
        mediaKind: input.mediaKind
    });

    let result: Awaited<ReturnType<typeof call>> | null = null;
    for (let index = 0; index < modelQueue.length; index++) {
        const modelId = modelQueue[index];
        try {
	            const payload = makePayload(modelId, input.inlineImage);
	            result = await call('v1beta', payload, modelId);
	            if (!result.ok && result.status === 404) result = await call('v1', payload, modelId);
	            if (!result.ok && input.inlineImage && shouldRetryTextOnly(result)) {
	                const textOnlyPayload = makePayload(modelId, null);
	                result = await call('v1beta', textOnlyPayload, modelId);
	                if (!result.ok && result.status === 404) result = await call('v1', textOnlyPayload, modelId);
            }
        } catch (error: any) {
            result = {
                ok: false as const,
                status: error?.name === 'TimeoutError' ? 408 : 0,
                message: error?.message || 'Gemini request failed',
                modelId,
            };
        }
        if (result.ok) {
            const aiText = result.data?.candidates?.[0]?.content?.parts?.[0]?.text || '';
            const altText = extractAltText(aiText);
            if (usableAltText(altText)) return altText;
            result = {
                ok: false as const,
                status: 422,
                message: 'Gemini returned unusable alt text',
                modelId,
            };
        }

        const canTryFallback = index < modelQueue.length - 1 && isGeminiFallbackWorthTrying(result.status, result.message);
        if (canTryFallback || result.status === 422) continue;
        break;
    }
    return usableAltText(fallbackAltText)
        ? fallbackAltText
        : 'Haber içeriğiyle ilişkili erişilebilir kapak görseli.';
};

export const POST: APIRoute = async ({ request }) => {
    try {
        const body = await request.json().catch(() => ({}));
        const src = String(body?.src || '').trim();
        if (!src) return json({ error: 'Image source required' }, 400);
        await requireStorageAdminRequest(request, 'image');

        const languageCode = String(body?.languageCode || 'tr').trim() || 'tr';
        const settings = await fetchAiSettings(languageCode);
        if (!settings?.google_ai_api_key) return json({ error: 'Google AI API key not configured' }, 400);

        const uploadRootDir = LOCAL_UPLOAD_ROOT;
        const baseDir = path.resolve(uploadRootDir, 'image');
        const localId = parseLocalImageRef(src);
        const candidateId = localId ? getCandidateId(baseDir, localId) : null;
        const localPath = candidateId ? path.resolve(baseDir, candidateId) : null;

        let inlineImage: { mimeType: string; data: string } | null = null;
        if (localPath && isInside(baseDir, localPath)) {
            try {
                inlineImage = await prepareInlineImage(localPath);
            } catch (imageError) {
                console.warn('SEO Alt Text image preparation skipped:', imageError);
            }
        }

        const context = String(body?.context || '').slice(0, MAX_CONTEXT_LENGTH);
        const currentAlt = String(body?.currentAlt || '').slice(0, 500);
	        const mediaKind = String(body?.mediaKind || 'haber kapak görseli').slice(0, 120);
	        const currentName = candidateId ? path.basename(candidateId) : filenameFromSrc(src);
	        const model = normalizeGeminiModelName(settings.google_ai_model) || 'gemini-2.5-flash';
	        const systemPrompt = await fetchMediaSeoSystemPrompt(languageCode);

	        const altText = await generateAltText({
            apiKey: settings.google_ai_api_key,
            model,
            context,
	            currentName,
	            currentAlt,
	            mediaKind,
	            inlineImage,
	            systemPrompt
	        });

        return json({
            success: true,
            altText,
            usedVision: Boolean(inlineImage)
        });
    } catch (error: any) {
        if ((error?.status || 500) >= 500) console.error('SEO Alt Text Error:', error);
        return json({ error: error.message || 'SEO alt text failed' }, error?.status || 500);
    }
};
