export const normalizeGeminiModelName = (model: unknown) => {
    return String(model || '')
        .trim()
        .replace(/^models\//i, '');
};

export const getOneLowerGeminiModel = (model: unknown) => {
    const normalized = normalizeGeminiModelName(model);
    const lower = normalized.toLowerCase();

    if (!normalized) return '';
    if (lower.includes('gemini-3.1-pro') || lower.includes('gemini-3-pro')) return 'gemini-3-flash-preview';
    if (lower.includes('gemini-3.1-flash') || lower.includes('gemini-3-flash')) return 'gemini-2.5-flash';
    if (lower.includes('gemini-2.5-pro')) return 'gemini-2.5-flash';
    if (lower === 'gemini-2.5-flash' || lower.includes('gemini-2.5-flash-preview')) return 'gemini-2.5-flash-lite';
    if (lower.includes('gemini-2.0-pro')) return 'gemini-2.0-flash';
    if (lower === 'gemini-2.0-flash' || lower.includes('gemini-2.0-flash-preview')) return 'gemini-2.0-flash-lite';
    if (lower.includes('gemini-1.5-pro')) return 'gemini-1.5-flash';
    if (lower.includes('gemma') && lower.includes('27b')) return normalized.replace(/27b/i, '12b');
    if (lower.includes('gemma') && lower.includes('12b')) return normalized.replace(/12b/i, '9b');

    return '';
};

export const isGeminiFallbackWorthTrying = (status: number | null | undefined, message: unknown) => {
    const text = String(message || '').toLowerCase();

    return (
        status === 429 ||
        status === 500 ||
        status === 502 ||
        status === 503 ||
        status === 504 ||
        text.includes('high demand') ||
        text.includes('overloaded') ||
        text.includes('temporarily unavailable') ||
        text.includes('unavailable') ||
        text.includes('exceeded your current quota') ||
        text.includes('quota exceeded') ||
        text.includes('rate limit') ||
        text.includes('resource_exhausted') ||
        text.includes('free_tier')
    );
};
