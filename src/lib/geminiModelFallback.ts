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
    if (lower.includes('gemini-3.5-flash') || lower.includes('gemini-3.1-flash') || lower.includes('gemini-3-flash')) return 'gemini-2.5-flash';
    if (/^gemini-3(?:[.-][a-z0-9]+)*-flash/.test(lower)) return 'gemini-2.5-flash';
    if (lower.includes('gemini-2.5-pro')) return 'gemini-2.5-flash';
    if (lower === 'gemini-2.5-flash' || lower.includes('gemini-2.5-flash-preview')) return 'gemini-2.5-flash-lite';
    if (lower.includes('gemini-2.0-pro')) return 'gemini-2.0-flash';
    if (lower === 'gemini-2.0-flash' || lower.includes('gemini-2.0-flash-preview')) return 'gemini-2.0-flash-lite';
    if (lower.includes('gemini-1.5-pro')) return 'gemini-1.5-flash';
    if (lower.includes('gemma') && lower.includes('27b')) return normalized.replace(/27b/i, '12b');
    if (lower.includes('gemma') && lower.includes('12b')) return normalized.replace(/12b/i, '9b');

    return '';
};

export const geminiModelAttempts = (selectedModel: unknown) => {
    const selected = normalizeGeminiModelName(selectedModel);
    const oneLower = getOneLowerGeminiModel(selected);
    const attempts = [
        'gemini-3-pro-preview',
        'gemini-3-flash-preview',
        'gemini-2.5-flash',
        'gemini-3.1-flash-lite',
        'gemini-2.5-flash-lite',
        'gemini-2.0-flash-lite',
        'gemini-2.0-flash',
    ];
    if (oneLower) attempts.unshift(oneLower);
    if (selected) attempts.unshift(selected);
    const seen = new Set<string>();
    return attempts.filter((model) => {
        const key = normalizeGeminiModelName(model).toLowerCase();
        if (!key || seen.has(key)) return false;
        seen.add(key);
        return true;
    });
};

export const geminiFastModelAttempts = (selectedModel: unknown) => {
    const selected = normalizeGeminiModelName(selectedModel);
    const lower = selected.toLowerCase();
    const oneLower = getOneLowerGeminiModel(selected);
    const selectedIsFast = Boolean(selected) && (
        lower.includes('flash') ||
        lower.includes('lite')
    ) && !lower.includes('pro');
    const attempts = [
        ...(selectedIsFast ? [selected] : []),
        oneLower,
        'gemini-2.5-flash',
        'gemini-3.1-flash-lite',
        'gemini-2.5-flash-lite',
        ...(!selectedIsFast ? [selected] : []),
        'gemini-3-flash-preview',
        'gemini-3-pro-preview',
        'gemini-2.0-flash-lite',
        'gemini-2.0-flash',
    ];
    const seen = new Set<string>();
    return attempts.filter((model) => {
        const key = normalizeGeminiModelName(model).toLowerCase();
        if (!key || seen.has(key)) return false;
        seen.add(key);
        return true;
    });
};

export const geminiThinkingConfigForModel = (model: unknown) => {
    const id = normalizeGeminiModelName(model).toLowerCase();
    if (id.includes('gemini-3')) {
        return { thinkingLevel: id.includes('lite') ? 'minimal' : 'low' };
    }
    if (id.includes('gemini-2.5-pro')) {
        return { thinkingBudget: 128 };
    }
    if (id.includes('gemini-2.5-flash')) {
        return { thinkingBudget: 0 };
    }
    return null;
};

export const isGeminiFallbackWorthTrying = (status: number | null | undefined, message: unknown) => {
    const text = String(message || '').toLowerCase();

    return (
        status === 0 ||
        status === 408 ||
        status === 429 ||
        status === 500 ||
        status === 502 ||
        status === 503 ||
        status === 504 ||
        (status === 404 && (
            text.includes('not found') ||
            text.includes('not supported') ||
            text.includes('models/') ||
            text.includes('generatecontent')
        )) ||
        (status === 400 && (
            text.includes('not found') ||
            text.includes('not supported') ||
            text.includes('invalid') ||
            text.includes('generatecontent')
        )) ||
        text.includes('high demand') ||
        text.includes('overloaded') ||
        text.includes('temporarily unavailable') ||
        text.includes('unavailable') ||
        text.includes('exceeded your current quota') ||
        text.includes('quota exceeded') ||
        text.includes('rate limit') ||
        text.includes('resource_exhausted') ||
        text.includes('free_tier') ||
        text.includes('timeout') ||
        text.includes('aborted') ||
        text.includes('abort') ||
        text.includes('network')
    );
};
