import type { APIRoute } from 'astro';
import fs from 'fs';
import path from 'path';
import { dbQuery } from '@/lib/server/supabaseDb';
import { requireStorageAdminRequest } from '@/lib/server/storageAdminAuth';
import { getOneLowerGeminiModel, isGeminiFallbackWorthTrying, normalizeGeminiModelName } from '@/lib/geminiModelFallback';
import { buildSeoFilenameFallback, cleanAiScalarText, extractJsonStringField, isBoilerplateAiText, toSeoSlug } from '@/lib/mediaSeoText';

const STORAGE_TYPES = ['image', 'video', 'audio', 'file', 'logo', 'profile'] as const;
type StorageType = typeof STORAGE_TYPES[number];

const STORAGE_FILE_MARKER = '/api/storage/file/';
const JSON_HEADERS = { 'Content-Type': 'application/json' };
const IMAGE_VARIANT_SUFFIXES = ['_sm', '_xl', '_md', '_lg'] as const;

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

const stripKnownVariant = (baseName: string) => {
    for (const suffix of IMAGE_VARIANT_SUFFIXES) {
        if (baseName.toLowerCase().endsWith(suffix)) {
            return {
                rootBase: baseName.slice(0, -suffix.length),
                variant: baseName.slice(-suffix.length)
            };
        }
    }

    return { rootBase: baseName, variant: '' };
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

const escapeRegExp = (value: string) => value.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');

const collectRenameTargets = (baseDir: string, type: StorageType, fileId: string) => {
    const exactFullPath = path.resolve(baseDir, fileId);
    const parsed = path.parse(fileId);
    const dir = parsed.dir;
    const fullDir = path.dirname(exactFullPath);
    const { rootBase } = stripKnownVariant(parsed.name);

    const targets = new Map<string, { id: string; variant: string; ext: string }>();
    targets.set(fileId, { id: fileId, variant: stripKnownVariant(parsed.name).variant, ext: parsed.ext });

    if (type === 'image' && fs.existsSync(fullDir) && fs.statSync(fullDir).isDirectory()) {
        const siblingRegex = new RegExp(`^${escapeRegExp(rootBase)}(?:_sm|_xl|_md|_lg)?\\.[^.]+$`, 'i');
        for (const entry of fs.readdirSync(fullDir, { withFileTypes: true })) {
            if (!entry.isFile() || !siblingRegex.test(entry.name)) continue;
            const siblingParsed = path.parse(entry.name);
            const siblingVariant = stripKnownVariant(siblingParsed.name).variant;
            const siblingId = dir ? `${dir}/${entry.name}` : entry.name;
            targets.set(siblingId, { id: siblingId, variant: siblingVariant, ext: siblingParsed.ext });
        }
    }

    return Array.from(targets.values());
};

const chooseUniqueBase = (baseDir: string, type: StorageType, targets: Array<{ id: string; variant: string; ext: string }>, requestedBase: string) => {
    const oldIds = new Set(targets.map((target) => target.id));

    for (let attempt = 0; attempt < 100; attempt++) {
        const suffix = attempt === 0 ? '' : `-${attempt + 1}`;
        const candidateBase = `${requestedBase}${suffix}`;
        const conflicts = targets.some((target) => {
            const parsed = path.parse(target.id);
            const newId = `${parsed.dir ? `${parsed.dir}/` : ''}${candidateBase}${target.variant}${target.ext.toLowerCase() || '.webp'}`;
            const fullPath = path.resolve(baseDir, newId);
            return !oldIds.has(newId) && fs.existsSync(fullPath);
        });

        if (!conflicts) return candidateBase;
    }

    return `${requestedBase}-${Date.now()}`;
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

const buildPrompt = (input: {
    context: string;
    currentName: string;
    mediaKind: string;
    type: StorageType;
}) => `
Sen uluslararası SEO, Google News, Yandex News, Discover ve yapay zeka tarayıcıları için görsel/video dosya adlandırma uzmanısın.

Görev: Aşağıdaki haber bağlamına ve mevcut medya adına göre tek bir mükemmel dosya adı kökü üret.

Kurallar:
- Çıktı SADECE JSON olsun: {"filename":"kisa-seo-dosya-adi"}
- JSON öncesine veya sonrasına açıklama, "Here is the JSON requested", markdown, kod bloğu, yorum, not veya Türkçe/İngilizce giriş cümlesi yazma.
- Uzantı yazma. .webp, .jpg, .mp4 gibi ekleme.
- Türkçe karakter kullanma; ASCII küçük harf, rakam ve tire kullan.
- 4-10 kelime arası, 80 karakteri geçmeyen, okunabilir ve haberle birebir alakalı bir ad üret.
- Google SEO, Yandex SEO, Google Images, Discover ve AI crawler anlayışı için somut kişi/yer/konu/olay kelimelerini öne al.
- "image", "foto", "resim", "whatsapp", "img", "edited", "screenshot", tarih-saat, rastgele sayı gibi anlamsız kelimeleri kullanma.
- Clickbait, iddia, abartı veya olmayan bilgi ekleme.
- Haber metninde belirsizse mevcut dosya adından ve medya türünden güvenli çıkarım yap; uydurma isim/kurum ekleme.

Medya türü: ${input.type}
Medya konumu: ${input.mediaKind}
Mevcut dosya adı: ${input.currentName}

Haber bağlamı:
${input.context}
`;

const extractAiFilename = (text: string) => {
    const jsonFilename = cleanAiScalarText(extractJsonStringField(text, 'filename'));
    if (jsonFilename) return jsonFilename;

    return cleanAiScalarText(String(text || ''));
};

const generateSeoName = async (input: {
    apiKey: string;
    model: string;
    context: string;
    currentName: string;
    mediaKind: string;
    type: StorageType;
}) => {
    const prompt = buildPrompt(input);
    const payload = {
        contents: [{ parts: [{ text: prompt }] }],
        generationConfig: {
            temperature: 0.2,
            topK: 32,
            topP: 0.9,
            maxOutputTokens: 160,
            responseMimeType: 'application/json',
        },
    };

    const call = async (apiVersion: 'v1beta' | 'v1', modelId: string) => {
        const response = await fetch(
            `https://generativelanguage.googleapis.com/${apiVersion}/models/${encodeURIComponent(modelId)}:generateContent?key=${encodeURIComponent(input.apiKey)}`,
            {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify(payload)
            }
        );
        const data = await response.json().catch(() => ({}));
        if (!response.ok || data?.error) {
            const message = data?.error?.message || `Gemini HTTP ${response.status}`;
            return { ok: false as const, status: response.status, message, modelId };
        }
        return { ok: true as const, data, modelId };
    };

    const primaryModel = normalizeGeminiModelName(input.model) || 'gemini-2.5-flash';
    const fallbackModel = getOneLowerGeminiModel(primaryModel);
    const modelQueue = [primaryModel];
    if (fallbackModel && fallbackModel !== primaryModel) modelQueue.push(fallbackModel);
    const fallbackFilename = buildSeoFilenameFallback({
        context: input.context,
        currentName: input.currentName,
        mediaKind: input.mediaKind
    });

    let result: Awaited<ReturnType<typeof call>> | null = null;
    for (let index = 0; index < modelQueue.length; index++) {
        const modelId = modelQueue[index];
        result = await call('v1beta', modelId);
        if (!result.ok && result.status === 404) result = await call('v1', modelId);
        if (result.ok) break;

        const canTryFallback = index === 0 && modelQueue.length > 1 && isGeminiFallbackWorthTrying(result.status, result.message);
        if (canTryFallback) continue;
        break;
    }

    if (!result?.ok) return fallbackFilename;

    const aiText = result.data?.candidates?.[0]?.content?.parts?.[0]?.text || '';
    const aiFilename = extractAiFilename(aiText);
    const selectedName = aiFilename && !isBoilerplateAiText(aiFilename) ? aiFilename : fallbackFilename;
    const selectedSlug = toSeoSlug(selectedName, 'haber-gorseli');

    return isBoilerplateAiText(selectedSlug) ? fallbackFilename : selectedSlug;
};

export const POST: APIRoute = async ({ request }) => {
    try {
        const body = await request.json().catch(() => ({}));
        const src = String(body?.src || '').trim();
        const ref = parseStorageRef(src, body?.type);
        if (!ref) return json({ error: 'Local storage file required' }, 400);
        await requireStorageAdminRequest(request, ref.type);

        const uploadRootDir = path.resolve(process.cwd(), 'Upload');
        const baseDir = path.resolve(uploadRootDir, ref.type);
        const candidateId = getCandidateId(baseDir, ref.id);
        if (!candidateId) return json({ error: 'File not found' }, 404);

        const exactPath = path.resolve(baseDir, candidateId);
        if (!isInside(baseDir, exactPath)) return json({ error: 'Invalid file path' }, 400);

        const languageCode = String(body?.languageCode || 'tr').trim() || 'tr';
        const settings = await fetchAiSettings(languageCode);
        if (!settings?.google_ai_api_key) return json({ error: 'Google AI API key not configured' }, 400);

        const currentName = path.basename(candidateId);
        const context = String(body?.context || '').slice(0, 6000);
        const mediaKind = String(body?.mediaKind || 'haber medyası').slice(0, 120);
        const model = normalizeGeminiModelName(settings.google_ai_model) || 'gemini-2.5-flash';
        const requestedBase = await generateSeoName({
            apiKey: settings.google_ai_api_key,
            model,
            context,
            currentName,
            mediaKind,
            type: ref.type
        });

        const targets = collectRenameTargets(baseDir, ref.type, candidateId);
        const uniqueBase = chooseUniqueBase(baseDir, ref.type, targets, requestedBase);
        const replacements: Array<{ oldId: string; newId: string; oldSrc: string; newSrc: string }> = [];

        for (const target of targets) {
            const parsed = path.parse(target.id);
            const ext = target.ext.toLowerCase() || (ref.type === 'video' ? '.mp4' : '.webp');
            const newFileName = `${uniqueBase}${target.variant}${ext}`;
            const newId = parsed.dir ? `${parsed.dir}/${newFileName}` : newFileName;
            const oldFullPath = path.resolve(baseDir, target.id);
            const newFullPath = path.resolve(baseDir, newId);

            if (!isInside(baseDir, oldFullPath) || !isInside(baseDir, newFullPath)) continue;
            if (!fs.existsSync(oldFullPath) || target.id === newId) continue;

            fs.renameSync(oldFullPath, newFullPath);
            replacements.push({
                oldId: target.id,
                newId,
                oldSrc: `/api/storage/file/${ref.type}/${target.id}`,
                newSrc: `/api/storage/file/${ref.type}/${newId}`
            });
        }

        const selectedReplacement = replacements.find((item) => item.oldId === candidateId) || replacements[0];

        return json({
            success: true,
            filename: uniqueBase,
            src: selectedReplacement?.newSrc || `/api/storage/file/${ref.type}/${candidateId}`,
            replacements
        });
    } catch (error: any) {
        console.error('SEO Rename Error:', error);
        return json({ error: error.message || 'SEO rename failed' }, error?.status || 500);
    }
};
