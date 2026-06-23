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

const TECHNICAL_FILENAME_WORDS = new Set([
    'chatgpt',
    'image',
    'img',
    'foto',
    'photo',
    'picture',
    'screenshot',
    'screen',
    'whatsapp',
    'edited',
    'copy',
    'upload',
    'file',
    'haz',
    'ocak',
    'subat',
    'şubat',
    'mart',
    'nisan',
    'mayis',
    'mayıs',
    'haziran',
    'temmuz',
    'agustos',
    'ağustos',
    'eylul',
    'eylül',
    'ekim',
    'kasim',
    'kasım',
    'aralik',
    'aralık',
]);

const TEXT_ENTITY_MAP: Record<string, string> = {
    amp: '&',
    apos: "'",
    Ccedil: 'Ç',
    ccedil: 'ç',
    Gbreve: 'Ğ',
    gbreve: 'ğ',
    hellip: '...',
    Idot: 'İ',
    imath: 'ı',
    laquo: '"',
    ldquo: '"',
    lsquo: "'",
    nbsp: ' ',
    Ouml: 'Ö',
    ouml: 'ö',
    quot: '"',
    raquo: '"',
    rdquo: '"',
    rsquo: "'",
    Scedil: 'Ş',
    scedil: 'ş',
    Uuml: 'Ü',
    uuml: 'ü',
};

const decodeTextCodePoint = (value: string, radix: number, fallback: string) => {
    const codePoint = Number.parseInt(value, radix);
    if (!Number.isFinite(codePoint) || codePoint <= 0) return fallback;
    try {
        return String.fromCodePoint(codePoint);
    } catch {
        return fallback;
    }
};

const decodeTextEntities = (value: string) => {
    const decodeOnce = (input: string) => input
        .replace(/&([a-zA-Z][a-zA-Z0-9]+);/g, (match, entity: string) => TEXT_ENTITY_MAP[entity] ?? match)
        .replace(/&#x([0-9a-fA-F]+);/g, (match, hex: string) => decodeTextCodePoint(hex, 16, match))
        .replace(/&#(\d+);/g, (match, decimal: string) => decodeTextCodePoint(decimal, 10, match));

    return decodeOnce(decodeOnce(value));
};

export const htmlToPlainText = (value: unknown) => decodeTextEntities(
    String(value || '')
        .replace(/<style[\s\S]*?<\/style>/gi, ' ')
        .replace(/<script[\s\S]*?<\/script>/gi, ' ')
        .replace(/<[^>]+>/g, ' ')
        .replace(/&nbsp;/g, ' ')
)
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

// Detects machine-generated, high-entropy tokens such as hex hashes
// (e.g. "605ec1f66e43a2f91370"), UUID fragments, or base36/62 ids. Kept
// conservative so real words/place names (which contain no digits) are never
// flagged: a token must be long AND mix letters with a meaningful share of
// digits to be considered random.
// Specific multi-word screenshot phrases (Turkish + English). Matched as whole
// phrases — never single words like "resmi" (official) or "ekran" (screen) on
// their own — so legitimate news filenames are not falsely flagged.
const SCREENSHOT_PHRASES = [
    'ekran resmi',
    'ekran goruntusu',
    'ekran goruntu',
    'ekrani goruntusu',
    'screen shot',
];

const isRandomLookingToken = (word: string) => {
    if (word.length < 12) return false;
    const hasLetter = /[a-z]/.test(word);
    const hasDigit = /[0-9]/.test(word);
    if (!hasLetter || !hasDigit) return false;
    // Pure hexadecimal hash mixing digits and letters.
    if (/^[a-f0-9]+$/.test(word)) return true;
    // Long alphanumeric id with a high digit ratio.
    const digitCount = (word.match(/[0-9]/g) || []).length;
    return digitCount / word.length >= 0.3;
};

export const isTechnicalMediaText = (value: unknown) => {
    const text = transliterateTurkish(String(value || ''))
        .toLowerCase()
        .replace(/\.[a-z0-9]{2,5}\b/g, ' ')
        .replace(/[^a-z0-9]+/g, ' ')
        .replace(/\s+/g, ' ')
        .trim();

    if (!text) return true;
    if (/\b\d{10,}\b/.test(text)) return true;
    if (SCREENSHOT_PHRASES.some((phrase) => text.includes(phrase))) return true;
    const words = text.split(' ').filter(Boolean);
    if (words.some(isRandomLookingToken)) return true;
    const technicalCount = words.filter((word) => TECHNICAL_FILENAME_WORDS.has(word)).length;
    if (technicalCount > 0 && words.length <= 8) return true;
    if (technicalCount >= 2) return true;
    return false;
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

const getContextAnyLine = (context: string, labels: string[]) => {
    for (const label of labels) {
        const value = getContextLine(context, label);
        if (value) return value;
    }
    return '';
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

const cleanCurrentFilenameText = (value: string) => {
    const stem = htmlToPlainText(value)
        .replace(/\.[a-z0-9]{2,5}$/i, '')
        .replace(/[_-]+/g, ' ');
    const words = stem
        .split(/\s+/)
        .map((word) => word.trim())
        .filter(Boolean)
        .filter((word) => {
            const normalized = transliterateTurkish(word)
                .toLowerCase()
                .replace(/[^a-z0-9]/g, '');
            if (!normalized || normalized.length <= 2) return false;
            if (/^\d+$/.test(normalized)) return false;
            if (TECHNICAL_FILENAME_WORDS.has(normalized)) return false;
            return true;
        });
    const cleaned = words.join(' ').replace(/\s+/g, ' ').trim();
    return isTechnicalMediaText(cleaned) ? '' : cleaned;
};

export const buildSeoFilenameFallback = (input: {
    context: string;
    currentName: string;
    mediaKind: string;
}) => {
    const focused = getFocusedMediaText(input.mediaKind);
    const title = getContextLine(input.context, 'Haber başlığı');
    const seoTitle = getContextLine(input.context, 'SEO başlık');
    const summary = getContextAnyLine(input.context, ['Kısa özet', 'Kısa özet/spot']);
    const metaDescription = getContextAnyLine(input.context, ['Meta açıklama', 'SEO açıklama']);
    const keywords = getContextAnyLine(input.context, ['Odak anahtar kelimeler', 'Anahtar kelimeler']);

    const pieces = removeDuplicatePieces([focused, title, seoTitle, summary, metaDescription, keywords])
        .filter((piece) => !isBoilerplateAiText(piece));

    const source = pieces.join(' ');
    const fallback = cleanCurrentFilenameText(input.currentName);
    const normalizedKind = transliterateTurkish(htmlToPlainText(input.mediaKind)).toLowerCase();
    const generic = (normalizedKind.includes('kapak') || normalizedKind.includes('kapagi'))
        ? 'haber kapagi'
        : 'haber medyasi';
    const slug = toSeoSlug(source || fallback || generic, 'haber-gorseli');

    return isBoilerplateAiText(slug) || isTechnicalMediaText(slug)
        ? toSeoSlug(generic, 'haber-gorseli')
        : slug;
};

export const buildAltTextFallback = (input: {
    context: string;
    currentName: string;
    mediaKind: string;
}) => {
    const focused = getFocusedMediaText(input.mediaKind);
    const title = getContextLine(input.context, 'Haber başlığı');
    const summary = getContextAnyLine(input.context, ['Kısa özet', 'Kısa özet/spot']);
    const seoDescription = getContextAnyLine(input.context, ['Meta açıklama', 'SEO açıklama']);
    const filenameText = cleanCurrentFilenameText(input.currentName);

    const pieces = removeDuplicatePieces([focused, title, summary, seoDescription, filenameText])
        .filter((piece) => !isBoilerplateAiText(piece));
    const source = pieces.join('. ');
    const sentence = source.replace(/\s+/g, ' ').trim();
    if (!sentence || isTechnicalMediaText(sentence)) {
        return 'Haber içeriğiyle ilişkili erişilebilir kapak görseli.';
    }
    if (sentence.length <= 180) return sentence.replace(/[. ]*$/, '.');

    return `${sentence.slice(0, 177).replace(/\s+\S*$/, '').trim()}.`;
};
