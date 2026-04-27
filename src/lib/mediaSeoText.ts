const TURKISH_CHAR_MAP: Record<string, string> = {
    'ğ': 'g',
    'Ğ': 'G',
    'ü': 'u',
    'Ü': 'U',
    'ş': 's',
    'Ş': 'S',
    'ı': 'i',
    'İ': 'I',
    'ö': 'o',
    'Ö': 'O',
    'ç': 'c',
    'Ç': 'C'
};

const BOILERPLATE_PATTERNS = [
    'here is the json requested',
    'here is the requested json',
    'here is the json',
    'json requested',
    'requested json',
    'as requested',
    'sure here',
    'certainly',
    'filename',
    'alttext',
    'alt text',
    'output',
    'response',
    'iste json',
    'istenen json',
    'json ciktisi',
    'json çıktısı',
    'tabii',
    'elbette'
];

export const htmlToPlainText = (value: unknown) => String(value || '')
    .replace(/<style[\s\S]*?<\/style>/gi, ' ')
    .replace(/<script[\s\S]*?<\/script>/gi, ' ')
    .replace(/<[^>]+>/g, ' ')
    .replace(/&nbsp;/g, ' ')
    .replace(/&amp;/g, '&')
    .replace(/&quot;/g, '"')
    .replace(/&#39;/g, "'")
    .replace(/\s+/g, ' ')
    .trim();

export const transliterateTurkish = (value: string) => String(value || '')
    .replace(/[ğĞüÜşŞıİöÖçÇ]/g, (char) => TURKISH_CHAR_MAP[char] || char);

export const toSeoSlug = (value: string, fallback = 'medya') => {
    const cleaned = transliterateTurkish(String(value || ''))
        .normalize('NFKD')
        .replace(/[\u0300-\u036f]/g, '')
        .toLowerCase()
        .replace(/[^a-z0-9]+/g, '-')
        .replace(/^-+|-+$/g, '')
        .replace(/-{2,}/g, '-')
        .slice(0, 90)
        .replace(/-+$/g, '');

    return cleaned || `${fallback}-${Date.now()}`;
};

export const isBoilerplateAiText = (value: unknown) => {
    const text = transliterateTurkish(String(value || ''))
        .toLowerCase()
        .replace(/[^a-z0-9]+/g, ' ')
        .replace(/\s+/g, ' ')
        .trim();

    if (!text) return true;
    return BOILERPLATE_PATTERNS.some((pattern) => text.includes(pattern));
};

const stripCodeFences = (value: string) => String(value || '')
    .replace(/```(?:json)?/gi, '')
    .replace(/```/g, '')
    .trim();

const collectJsonObjects = (value: string) => {
    const objects: string[] = [];
    let start = -1;
    let depth = 0;
    let inString = false;
    let escaped = false;

    for (let index = 0; index < value.length; index++) {
        const char = value[index];

        if (inString) {
            if (escaped) {
                escaped = false;
            } else if (char === '\\') {
                escaped = true;
            } else if (char === '"') {
                inString = false;
            }
            continue;
        }

        if (char === '"') {
            inString = true;
            continue;
        }

        if (char === '{') {
            if (depth === 0) start = index;
            depth++;
        } else if (char === '}') {
            depth--;
            if (depth === 0 && start >= 0) {
                objects.push(value.slice(start, index + 1));
                start = -1;
            }
        }
    }

    return objects;
};

export const extractJsonStringField = (text: string, fieldName: string) => {
    const cleaned = stripCodeFences(text);

    for (const candidate of [cleaned, ...collectJsonObjects(cleaned)]) {
        try {
            const parsed = JSON.parse(candidate);
            const value = parsed?.[fieldName];
            if (typeof value === 'string' && value.trim()) return value.trim();
        } catch {
            // Try the next candidate.
        }
    }

    const fieldPattern = new RegExp(`["']?${fieldName}["']?\\s*[:=]\\s*["“”']?([^"“”'\\n\\r}]+)`, 'i');
    const match = cleaned.match(fieldPattern);
    return match?.[1]?.trim() || '';
};

export const cleanAiScalarText = (value: string) => {
    const cleaned = stripCodeFences(value)
        .replace(/^(filename|alt\s*text|altText|alternatif\s*metin|görsel\s*açıklaması|image\s*alt)\s*[:=]\s*/i, '')
        .replace(/^["'“”]+|["'“”]+$/g, '')
        .replace(/\s+/g, ' ')
        .trim();

    return isBoilerplateAiText(cleaned) ? '' : cleaned;
};

const getContextLine = (context: string, label: string) => {
    const normalizedLabel = transliterateTurkish(label).toLowerCase();
    const line = String(context || '').split('\n').find((item) => {
        const normalizedLine = transliterateTurkish(item).toLowerCase();
        return normalizedLine.startsWith(`${normalizedLabel}:`);
    });

    return htmlToPlainText(line?.slice(line.indexOf(':') + 1) || '');
};

const getFocusedMediaText = (mediaKind: string) => {
    const cleaned = htmlToPlainText(mediaKind);
    const separators = [' | ', ':'];
    for (const separator of separators) {
        if (!cleaned.includes(separator)) continue;
        const parts = cleaned.split(separator).map((part) => part.trim()).filter(Boolean);
        const useful = parts.find((part, index) => index > 0 && part.length > 8);
        if (useful) {
            return useful
                .replace(/^(başlık|baslik|metin|açıklama|aciklama|alt metin|seçenekler|secenekler|kaynak|inceleme|quiz|flip ön|flip on|flip arka|before after)\s*:\s*/i, '')
                .trim();
        }
    }

    return '';
};

const removeDuplicatePieces = (pieces: string[]) => {
    const seen = new Set<string>();
    return pieces.filter((piece) => {
        const key = transliterateTurkish(piece).toLowerCase().replace(/\W+/g, ' ').trim();
        if (!key || seen.has(key)) return false;
        seen.add(key);
        return true;
    });
};

export const buildSeoFilenameFallback = (input: {
    context: string;
    currentName: string;
    mediaKind: string;
}) => {
    const focused = getFocusedMediaText(input.mediaKind);
    const title = getContextLine(input.context, 'Haber başlığı');
    const seoTitle = getContextLine(input.context, 'SEO başlık');
    const summary = getContextLine(input.context, 'Kısa özet/spot');
    const keywords = getContextLine(input.context, 'Anahtar kelimeler');

    const pieces = removeDuplicatePieces([focused, title, seoTitle, summary, keywords])
        .filter((piece) => !isBoilerplateAiText(piece));

    const source = pieces.join(' ');
    const fallback = htmlToPlainText(input.currentName).replace(/\.[a-z0-9]+$/i, '');
    const slug = toSeoSlug(source || fallback, 'haber-gorseli');

    return isBoilerplateAiText(slug) ? `haber-gorseli-${Date.now()}` : slug;
};

export const buildAltTextFallback = (input: {
    context: string;
    currentName: string;
    mediaKind: string;
}) => {
    const focused = getFocusedMediaText(input.mediaKind);
    const title = getContextLine(input.context, 'Haber başlığı');
    const summary = getContextLine(input.context, 'Kısa özet/spot');
    const seoDescription = getContextLine(input.context, 'SEO açıklama');

    const pieces = removeDuplicatePieces([focused, title, summary, seoDescription])
        .filter((piece) => !isBoilerplateAiText(piece));
    const source = pieces.join('. ') || htmlToPlainText(input.currentName).replace(/\.[a-z0-9]+$/i, '');
    const sentence = source.replace(/\s+/g, ' ').trim();
    if (!sentence) return 'Haber içeriğiyle ilişkili kapak görseli';
    if (sentence.length <= 180) return sentence.replace(/[. ]*$/, '.');

    return `${sentence.slice(0, 177).replace(/\s+\S*$/, '').trim()}.`;
};
