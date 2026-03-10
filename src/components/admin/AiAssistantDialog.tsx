import React, { useState, useEffect, useRef, useCallback } from 'react';
import { useLanguage } from '@/context/LanguageContext';
import { useToast } from '@/context/ToastContext';
import { supabase } from '@/lib/supabase';

interface AiAssistantDialogProps {
    isOpen: boolean;
    onClose: () => void;
    onApply?: (data: {
        title: string;
        summary: string;
        content: string;
        keywords: string[];
        metaTitle: string;
        metaDesc: string;
        slug: string;
        schemaType: string;
        faqs: { q: string, a: string }[];
    }) => void;
}

const NEWS_CONSTITUTION = `
Sen, dijital medya dinamiklerine, nöro-bilişsel okuma alışkanlıklarına ve SEO stratejilerine hakim, ödüllü bir "Dijital Haber Editörü"sün. Görevin, sana vereceğim ham bilgileri veya konu başlığını, modern dijital habercilik tekniklerine (Smart Brevity, Dual Coding, F-Tipi Okuma) göre optimize edilmiş, yüksek etkileşimli bir haber metnine dönüştürmektir.

Aşağıdaki "Dijital Haber Yazım Anayasası" kurallarına sıkı sıkıya bağlı kalarak haberi oluştur:

### 1. BAŞLIK MİMARİSİ (HEADLINE ENGINEERING)
- Kural: Okuyucunun dikkatini 17 milisaniye içinde çekmelisin.
- Teknik: Negatiflik yanlılığını (Negativity Bias) etik sınırlar içinde kullan. "Tehlike, Uyarı, Risk, Kriz" gibi kelimeler tıklamayı artırır ancak asla yalan (clickbait) söyleme.
- Yapı: 60 karakteri geçmemeye çalış. Fiil odaklı ve somut ol.

### 2. GİRİŞ VE SPOT (THE HOOK & SMART BREVITY)
- Kural: Geleneksel "Özet Spot" yerine "Mermi Spot" (Bullet Lead) veya "Axiom" kullan.
- Yapı: Haberin en can alıcı noktasını (Sonuç) en başta tek cümleyle ver.
- Smart Brevity Formatı: Hemen altına şu iki maddeyi ekle:
  - Yeni ne var?: (Olayın en güncel gelişmesi - tek cümle)
  - Neden önemli?: (Okuyucunun hayatına etkisi - tek cümle)

### 3. GÖVDE YAPISI (MODÜLER VE DOĞRUSAL OLMAYAN)
- Kural: Asla "Gri Duvar" (uzun blok metinler) oluşturma. İnsanlar okumaz, tarar (F-Tipi Okuma).
- Paragraf Uzunluğu: Her paragraf maksimum 2-3 cümle olmalı (Mobil uyumluluk için).
- Ara Başlık Enflasyonu: Her 150-200 kelimede bir mutlaka "konuşkan" ara başlık kullan.

### 4. DİL VE ÜSLUP (COGNITIVE EASE)
- Ses Tonu: Otoriter ama konuşma diline yakın.
- Vurgu: Önemli anahtar kelimeleri ve verileri kalın (bold) yap.

### 5. SEO VE TEKNİK YAPILANDIRMA
- Uzunluk: Konu detaylıysa SEO için uzun yazmaktan çekinme (1000+ kelime), modüler parçalarla böl.
- Slug: Haberle uyumlu, kısa ve SEO dostu URL (küçük harf, rakam ve tire).
- Schema: En uygun Schema.org tipini seç (NewsArticle, BlogPosting, Article).
- FAQ: Haberle ilgili 3-4 adet Soru-Cevap hazırla.

### ÇIKTI FORMATI (ZORUNLU):
Yanıtını MUTLAKA aşağıdaki formatta ver, başka hiçbir metin ekleme:
[TITLE]Haber Başlığı Buraya[/TITLE]
[SUMMARY]Haberin Spot Özeti Buraya[/SUMMARY]
[SLUG]haber-slug-buraya[/SLUG]
[KEYWORDS]anahtar, kelime, listesi, buraya[/KEYWORDS]
[METATITLE]SEO Başlığı Buraya[/METATITLE]
[METADESC]SEO Açıklaması Buraya[/METADESC]
[SCHEMA]NewsArticle[/SCHEMA]
[FAQ]
S: Soru 1?
C: Cevap 1.
S: Soru 2?
C: Cevap 2.
[/FAQ]
[CONTENT]
Haberin tüm gövde metni (Anayasa kurallarına göre düzenlenmiş) buraya.
[/CONTENT]
`;

const AiAssistantDialog: React.FC<AiAssistantDialogProps> = ({ isOpen, onClose, onApply }) => {
    const { t, currentLang } = useLanguage();
    const { showToast } = useToast();
    const [position, setPosition] = useState({ x: 100, y: 100 });
    const [size, setSize] = useState({ width: 900, height: 600 });
    const [isDragging, setIsDragging] = useState(false);
    const [isResizing, setIsResizing] = useState(false);
    const [content, setContent] = useState('');
    const [resultContent, setResultContent] = useState('');
    const [isCopied, setIsCopied] = useState(false);
    const [isGenerating, setIsGenerating] = useState(false);
    const [canApply, setCanApply] = useState(false);
    const [apiNotice, setApiNotice] = useState('');
    const [newsMedia, setNewsMedia] = useState({ image: false, video: false, audio: false });

    const [models, setModels] = useState<string[]>([]);
    const [selectedModel, setSelectedModel] = useState('');
    const [readyFormats, setReadyFormats] = useState<any[]>([]);
    const [selectedFormat, setSelectedFormat] = useState<string>('');

    const dragOffset = useRef({ x: 0, y: 0 });
    const dialogRef = useRef<HTMLDivElement>(null);

    useEffect(() => {
        if (isOpen) {
            fetchSettings();
            fetchReadyFormats();
        }
    }, [isOpen, currentLang.code]);

    const [apiKey, setApiKey] = useState('');

    const fetchSettings = async () => {
        try {
            const { data, error } = await supabase
                .from('site_settings')
                .select('google_ai_api_key, google_ai_model')
                .eq('language_code', currentLang.code)
                .maybeSingle();
            if (data) {
                const preferredModel = data.google_ai_model || '';
                if (preferredModel) setSelectedModel(preferredModel);
                if (data.google_ai_api_key) {
                    setApiKey(data.google_ai_api_key);
                    fetchModels(data.google_ai_api_key, preferredModel);
                }
            }
        } catch (err) {
            console.error('Error fetching AI settings:', err);
        }
    };

    const fetchModels = async (key: string, preferredModel?: string) => {
        try {
            const encodedKey = encodeURIComponent(key);

            const extractModelIds = (data: any) =>
                (data?.models || [])
                    .filter((m: any) => {
                        const methods = m?.supportedGenerationMethods;
                        return Array.isArray(methods) && methods.includes('generateContent');
                    })
                    .map((m: any) => String(m.name).replace('models/', '').trim())
                    .filter(Boolean);

            const fetchList = async (apiVersion: 'v1' | 'v1beta') => {
                try {
                    const response = await fetch(`https://generativelanguage.googleapis.com/${apiVersion}/models?key=${encodedKey}`);
                    const data = await response.json().catch(() => ({}));
                    if (data?.error) return { modelIds: [] as string[] };
                    return { modelIds: extractModelIds(data) };
                } catch {
                    return { modelIds: [] as string[] };
                }
            };

            const [v1Res, v1betaRes] = await Promise.all([fetchList('v1'), fetchList('v1beta')]);

            const baseModelIds = (() => {
                const seen = new Set<string>();
                const merged = [...v1Res.modelIds, ...v1betaRes.modelIds].map((id) => String(id || '').trim()).filter(Boolean);
                const uniqueModels = merged.filter((id) => {
                    if (seen.has(id)) return false;
                    seen.add(id);
                    return true;
                });

                // Sadece Flash 3, Flash 2.5 ve Gemma'nın en güçlü modelini filtrele
                const isImageVariant = (id: string) => id.toLowerCase().includes('image');

                const geminiFlash = uniqueModels.filter((id) => {
                    const lower = id.toLowerCase();
                    if (isImageVariant(lower)) return false;
                    return lower.includes('gemini-3-flash') || lower.includes('gemini-3.1-flash');
                });

                const pickBestModel = (candidates: string[]) => {
                    const rank = (id: string) => {
                        const lower = id.toLowerCase();
                        let score = 0;
                        if (lower.includes('latest')) score += 1000;
                        if (!lower.includes('preview') && !lower.includes('exp') && !lower.includes('experimental')) score += 200;
                        if (lower.includes('preview')) score -= 50;
                        // "lite" modeller daha hızlı/ucuz ama genelde daha az yetenekli; güç tercihinde geri bırak.
                        if (lower.includes('flash-lite') || lower.includes('-lite')) score -= 2000;
                        return score;
                    };

                    return [...candidates]
                        .sort((a, b) => {
                            const diff = rank(b) - rank(a);
                            if (diff !== 0) return diff;
                            return b.localeCompare(a, undefined, { numeric: true, sensitivity: 'base' });
                        })[0] || '';
                };

                const gemini25FlashCandidates = uniqueModels.filter((id) => {
                    const lower = id.toLowerCase();
                    if (isImageVariant(lower)) return false;
                    return lower.includes('gemini-2.5-flash');
                });
                const exactGemini25Flash = gemini25FlashCandidates.find((m) => m.toLowerCase() === 'gemini-2.5-flash') || '';
                const bestGemini25Flash = exactGemini25Flash || pickBestModel(gemini25FlashCandidates);

                const gemmaModels = uniqueModels.filter(id => id.toLowerCase().includes('gemma'));
                let bestGemma = '';
                if (gemmaModels.length > 0) {
                    if (gemmaModels.find(m => m.includes('27b'))) bestGemma = gemmaModels.find(m => m.includes('27b'))!;
                    else if (gemmaModels.find(m => m.includes('9b'))) bestGemma = gemmaModels.find(m => m.includes('9b'))!;
                    else if (gemmaModels.find(m => m.includes('7b'))) bestGemma = gemmaModels.find(m => m.includes('7b'))!;
                    else bestGemma = gemmaModels[0];
                }

                const finalModels = [...geminiFlash];
                if (bestGemini25Flash && !finalModels.includes(bestGemini25Flash)) finalModels.push(bestGemini25Flash);
                if (bestGemma) finalModels.push(bestGemma);

                return finalModels;
            })();

            setModels(baseModelIds);

            setSelectedModel((current) => {
                const preferred = String(preferredModel || '').trim();
                if (preferred && baseModelIds.includes(preferred)) return preferred;
                if (current && baseModelIds.includes(current)) return current;
                const fallback = baseModelIds.find((m) => m.toLowerCase().includes('-flash')) || baseModelIds[0] || '';
                return fallback || current || '';
            });

            // If current selected model is not in the list, but list is not empty, the dropdown will fall back.
        } catch (err) {
            console.error('Error fetching models:', err);
        }
    };

	    const fetchReadyFormats = async () => {
	        try {
	            const { data } = await supabase
	                .from('ai_ready_formats')
	                .select('*')
	                .eq('language_code', currentLang.code)
	                .eq('is_active', true)
	                .order('title');
	            if (data) {
	                setReadyFormats(data);
	                setSelectedFormat((current) => {
	                    const currentValue = String(current || '').trim();
	                    if (currentValue && data.some((f: any) => String(f?.id) === currentValue)) return currentValue;
	                    const firstId = data[0]?.id;
	                    return firstId ? String(firstId) : '';
	                });
	            }
	        } catch (err) {
	            console.error('Error fetching ready formats:', err);
	        }
	    };

    // Update size to be wider by default if it's the first open
    useEffect(() => {
        if (isOpen) {
            const viewportWidth = window.innerWidth;
            const viewportHeight = window.innerHeight;
            const defaultWidth = Math.min(1000, viewportWidth - 40);
            const defaultHeight = Math.min(700, viewportHeight - 40);

            setSize({ width: defaultWidth, height: defaultHeight });
            setPosition({
                x: (viewportWidth - defaultWidth) / 2,
                y: (viewportHeight - defaultHeight) / 2
            });
        }
    }, [isOpen]);

    const handleCopy = () => {
        if (!resultContent) return;
        const textToCopy = resultContent.replace(/\[\/?[A-Z]+\]/g, '').trim();
        navigator.clipboard.writeText(textToCopy).then(() => {
            setIsCopied(true);
            setTimeout(() => setIsCopied(false), 2000);
        });
    };

    const parseAiResult = (text: string) => {
        const KNOWN_TAGS = ['TITLE', 'SUMMARY', 'SLUG', 'KEYWORDS', 'METATITLE', 'METADESC', 'SCHEMA', 'FAQ', 'CONTENT'] as const;

        const extract = (tag: typeof KNOWN_TAGS[number]) => {
            const open = `[${tag}]`;
            const close = `[/${tag}]`;

            const start = text.indexOf(open);
            if (start === -1) return '';

            const afterOpen = start + open.length;
            const closeIdx = text.indexOf(close, afterOpen);
            if (closeIdx !== -1) return text.slice(afterOpen, closeIdx).trim();

            // If the closing tag is missing (often due to token limit truncation),
            // fall back to reading until the next known tag (or end-of-text).
            const nextTagStarts = KNOWN_TAGS
                .filter((t) => t !== tag)
                .map((t) => text.indexOf(`[${t}]`, afterOpen))
                .filter((idx) => idx !== -1);

            const nextIdx = nextTagStarts.length > 0 ? Math.min(...nextTagStarts) : -1;
            return (nextIdx !== -1 ? text.slice(afterOpen, nextIdx) : text.slice(afterOpen)).trim();
        };

        const faqRaw = extract('FAQ');
        const faqs: { q: string, a: string }[] = [];
        if (faqRaw) {
            const normalizeFaqQuestion = (value: string) => {
                const raw = String(value ?? '').trim();
                if (!raw) return '';
                const base = raw.replace(/\s*[?؟]+$/g, '').trim();
                return `${base || raw}?`;
            };

            const pairs = faqRaw.split(/S:/).filter(p => p.trim());
            pairs.forEach(p => {
                const parts = p.split(/C:/);
                if (parts.length === 2) {
                    faqs.push({
                        q: normalizeFaqQuestion(parts[0]),
                        a: parts[1].trim()
                    });
                }
            });
        }

        return {
            title: extract('TITLE'),
            summary: extract('SUMMARY'),
            content: extract('CONTENT'),
            keywords: extract('KEYWORDS').split(',').map(k => k.trim()).filter(k => k),
            metaTitle: extract('METATITLE'),
            metaDesc: extract('METADESC'),
            slug: extract('SLUG'),
            schemaType: extract('SCHEMA') || 'NewsArticle',
            faqs: faqs
        };
    };

    const handleGenerate = async (mode: 'organize' | 'make-ready') => {
        if (!content || isGenerating) return;

        if (!selectedFormat) {
            showToast('AI hazır formatı seçmelisiniz', 'error');
            return;
        }

        if (!apiKey) {
            alert("AI API Key bulunamadı. Lütfen Ayarlar > AI Ayarları kısmından API anahtarınızı girin.");
            return;
        }

        setIsGenerating(true);
        setCanApply(false);
        setResultContent('');
        setApiNotice('');

        try {
            // Determine system prompt: Default Constitution or Selected Format
            let systemPrompt = mode === 'make-ready' ? NEWS_CONSTITUTION : 'Lütfen bu metni profesyonel bir haber diliyle düzenle.';

            if (selectedFormat) {
                const format = readyFormats.find(f => f.id === selectedFormat);
                if (format) {
                    systemPrompt = format.prompt;
                }
            }

            // Force tags if mode is make-ready or a format is selected (as formats are usually for structured data)
            const forceTags = mode === 'make-ready' || (selectedFormat && !systemPrompt.includes('[TITLE]'));
            const outputInstruction = forceTags ? `
### ÇIKTI FORMATI (ZORUNLU):
Yanıtını MUTLAKA aşağıdaki formatta ver, başka hiçbir ek metin veya yorum ekleme. Sadece etiketler arasındaki metni döndür:
[TITLE]Haber Başlığı[/TITLE]
[SUMMARY]Spot Özet[/SUMMARY]
[SLUG]haber-basligi-url[/SLUG]
[KEYWORDS]anahtar, kelime, listesi[/KEYWORDS]
[METATITLE]SEO Başlığı[/METATITLE]
[METADESC]SEO Açıklaması[/METADESC]
[SCHEMA]NewsArticle[/SCHEMA]
[FAQ]
S: Soru?
C: Cevap.
[/FAQ]
[CONTENT]
Haber içeriği
[/CONTENT]` : '';

            const mediaLines: string[] = [];
            if (newsMedia.image) mediaLines.push(t('admin.ai_assistant.media.image'));
            if (newsMedia.video) mediaLines.push(t('admin.ai_assistant.media.video'));
            if (newsMedia.audio) mediaLines.push(t('admin.ai_assistant.media.audio'));
            const mediaSuffix = mediaLines.length > 0 ? `\n\n${mediaLines.join('\n')}` : '';

            const finalPrompt = systemPrompt + outputInstruction + "\n\nKonu / İçerik:\n" + content + mediaSuffix;

            const payload = {
                contents: [{
                    parts: [{
                        text: finalPrompt
                    }]
                }],
                generationConfig: {
                    temperature: 0.7,
                    topK: 40,
                    topP: 0.95,
                    maxOutputTokens: 4096,
                }
            };

            const sleep = (ms: number) => new Promise((resolve) => setTimeout(resolve, ms));

            const extractRetryDelaySeconds = (error: any, fallbackMessage: string) => {
                const details = Array.isArray(error?.details) ? error.details : [];
                for (const detail of details) {
                    const type = String(detail?.['@type'] || '');
                    if (!type.endsWith('google.rpc.RetryInfo')) continue;
                    const retryDelay = String(detail?.retryDelay || '').trim();
                    const match = retryDelay.match(/^(\d+(?:\.\d+)?)s$/);
                    if (match) return Number(match[1]);
                }

                const match = String(fallbackMessage || '').match(/Please retry in\s+(\d+(?:\.\d+)?)s\./i);
                if (match) return Number(match[1]);
                return null;
            };

            const isFreeTierLimitZero = (error: any, fallbackMessage: string) => {
                const message = String(error?.message || fallbackMessage || '').toLowerCase();
                if (message.includes('free_tier') && message.includes('limit: 0')) return true;

                const details = Array.isArray(error?.details) ? error.details : [];
                for (const detail of details) {
                    const type = String(detail?.['@type'] || '');
                    if (!type.endsWith('google.rpc.QuotaFailure')) continue;
                    const violations = Array.isArray(detail?.violations) ? detail.violations : [];
                    for (const violation of violations) {
                        const description = String(violation?.description || '').toLowerCase();
                        if (description.includes('free_tier') && description.includes('limit: 0')) return true;
                    }
                }

                return false;
            };

            const isHighDemandError = (error: any, fallbackMessage: string) => {
                const message = String(error?.message || fallbackMessage || '').toLowerCase();
                if (!message) return false;
                return message.includes('high demand') || message.includes('please try again later');
            };

            const callGenerate = async (apiVersion: 'v1' | 'v1beta', modelId: string) => {
                const response = await fetch(
                    `https://generativelanguage.googleapis.com/${apiVersion}/models/${encodeURIComponent(modelId)}:generateContent?key=${encodeURIComponent(apiKey)}`,
                    {
                        method: 'POST',
                        headers: { 'Content-Type': 'application/json' },
                        body: JSON.stringify(payload),
                    },
                );

                const data = await response.json().catch(() => ({}));
                if (!response.ok || data?.error) {
                    const error = data?.error || {};
                    const message = String(error?.message || `HTTP ${response.status}`);
                    return { ok: false as const, message, error, status: response.status, apiVersion, modelId };
                }
                return { ok: true as const, message: '', data, apiVersion, modelId };
            };

            const tryGenerateWithModel = async (modelId: string) => {
                // Gemini API docs primarily use v1beta for generateContent.
                // Use v1beta by default and only fall back to v1 when the model is not supported on that version.
                const primaryVersion: 'v1' | 'v1beta' = 'v1beta';
                const secondaryVersion: 'v1' | 'v1beta' = 'v1';

                const primary = await callGenerate(primaryVersion, modelId);
                if (primary.ok) return primary;

                const msg = String(primary.message || '').toLowerCase();
                const isNotFoundForApiVersion =
                    primary.status === 404 ||
                    msg.includes('not found for api version') ||
                    msg.includes('not supported for generatecontent');

                if (isNotFoundForApiVersion) {
                    return await callGenerate(secondaryVersion, modelId);
                }

                return primary;
            };

            const primaryResult = await tryGenerateWithModel(selectedModel);

            let result = primaryResult;
            let handledNoticeOnly = false;
            if (!result.ok) {
                const retryDelaySeconds = extractRetryDelaySeconds(result.error, result.message);

                if (isFreeTierLimitZero(result.error, result.message)) {
                    setApiNotice(
                        `Seçilen model (${selectedModel}) bu API anahtarının mevcut planında kullanılamıyor (free tier limiti 0). ` +
                        `Bu bir kod hatası değil: Pro modeller için billing/ücretli plan gerekir. ` +
                        `Model otomatik olarak değiştirilmedi; Ayarlar > AI Ayarları'ndan başka model seçebilir veya billing açıp tekrar deneyebilirsin.`,
                    );
                    handledNoticeOnly = true;
                } else if (isHighDemandError(result.error, result.message)) {
                    const retryScheduleMs = [1200, 2200];
                    for (const delayMs of retryScheduleMs) {
                        setApiNotice(
                            `Model şu an yoğun. ${Math.ceil(delayMs / 1000)} saniye sonra otomatik tekrar denenecek. ` +
                            `İstersen başka model de seçebilirsin.`,
                        );
                        await sleep(delayMs);
                        result = await tryGenerateWithModel(selectedModel);
                        if (result.ok) {
                            setApiNotice('');
                            break;
                        }
                        if (!isHighDemandError(result.error, result.message)) break;
                    }

                    if (!result.ok && isHighDemandError(result.error, result.message)) {
                        setApiNotice('Model şu an yoğun. Lütfen biraz sonra tekrar deneyin veya başka model seçin.');
                        handledNoticeOnly = true;
                    }
                } else if (typeof retryDelaySeconds === 'number' && Number.isFinite(retryDelaySeconds) && retryDelaySeconds > 0) {
                    // Keep the UI responsive: only auto-retry for short delays.
                    if (retryDelaySeconds <= 5) {
                        await sleep(Math.ceil(retryDelaySeconds * 1000));
                        result = await tryGenerateWithModel(selectedModel);
                        if (!result.ok) {
                            setApiNotice(`Rate limit aşıldı. Lütfen biraz sonra tekrar deneyin veya başka model seçin.`);
                            handledNoticeOnly = true;
                        }
                    } else {
                        setApiNotice(`Rate limit aşıldı. Lütfen ${Math.ceil(retryDelaySeconds)} saniye sonra tekrar deneyin veya başka model seçin.`);
                        handledNoticeOnly = true;
                    }
                } else if (result.status === 429) {
                    setApiNotice('Rate limit aşıldı. Lütfen biraz sonra tekrar deneyin veya başka model seçin.');
                    handledNoticeOnly = true;
                } else {
                    const msg = String(result.message || '').toLowerCase();
                    const looksLikeQuota =
                        msg.includes('exceeded your current quota') ||
                        msg.includes('quota exceeded') ||
                        msg.includes('rate limit') ||
                        msg.includes('resource_exhausted');
                    if (looksLikeQuota) {
                        setApiNotice('Kota/rate limit aşıldı. Lütfen biraz sonra tekrar deneyin veya başka model seçin (gerekirse billing/plan kontrol edin).');
                        handledNoticeOnly = true;
                    }
                }
            }

            // If the error type changes after internal retries (e.g., "high demand" -> rate limit),
            // ensure we still show a clean notice without dumping the raw API error to the UI.
            if (!result.ok && !handledNoticeOnly) {
                const retryDelaySecondsAfterRetry = extractRetryDelaySeconds(result.error, result.message);
                if (
                    typeof retryDelaySecondsAfterRetry === 'number' &&
                    Number.isFinite(retryDelaySecondsAfterRetry) &&
                    retryDelaySecondsAfterRetry > 0
                ) {
                    setApiNotice(
                        retryDelaySecondsAfterRetry > 5
                            ? `Rate limit aşıldı. Lütfen ${Math.ceil(retryDelaySecondsAfterRetry)} saniye sonra tekrar deneyin veya başka model seçin.`
                            : 'Rate limit aşıldı. Lütfen biraz sonra tekrar deneyin veya başka model seçin.',
                    );
                    handledNoticeOnly = true;
                } else if (result.status === 429) {
                    setApiNotice('Rate limit aşıldı. Lütfen biraz sonra tekrar deneyin veya başka model seçin.');
                    handledNoticeOnly = true;
                } else {
                    const msg = String(result.message || '').toLowerCase();
                    const looksLikeQuota =
                        msg.includes('exceeded your current quota') ||
                        msg.includes('quota exceeded') ||
                        msg.includes('rate limit') ||
                        msg.includes('resource_exhausted');
                    if (looksLikeQuota) {
                        setApiNotice('Kota/rate limit aşıldı. Lütfen biraz sonra tekrar deneyin veya başka model seçin (gerekirse billing/plan kontrol edin).');
                        handledNoticeOnly = true;
                    }
                }
            }

            if (!result.ok) {
                if (handledNoticeOnly) return;
                setResultContent(`HATA: ${result.message || 'AI ile bağlantı kurulamadı.'}`);
                return;
            }

            const data = result.data;

            const aiText = data.candidates?.[0]?.content?.parts?.[0]?.text;
            if (!aiText) {
                throw new Error("AI yanıtı boş veya geçersiz.");
            }

            setResultContent(aiText);

            // Check if tags are present
            if (aiText.includes('[TITLE]') && aiText.includes('[CONTENT]')) {
                setCanApply(true);
            } else {
                setCanApply(false);
            }
        } catch (err: any) {
            console.error('Gemini API Error:', err);
            setResultContent(`HATA: ${err.message || 'AI ile bağlantı kurulamadı.'}`);
        } finally {
            setIsGenerating(false);
        }
    };

    const handleApplyData = () => {
        if (!onApply || !resultContent || !canApply) return;
        const parsed = parseAiResult(resultContent);
        onApply(parsed);
        onClose();
    };

    const handleMouseDown = (e: React.MouseEvent) => {
        if ((e.target as HTMLElement).closest('.drag-handle')) {
            setIsDragging(true);
            dragOffset.current = {
                x: e.clientX - position.x,
                y: e.clientY - position.y
            };
            e.preventDefault();
        }
    };

    const handleResizeMouseDown = (e: React.MouseEvent) => {
        setIsResizing(true);
        e.preventDefault();
        e.stopPropagation();
    };

    const handleMouseMove = useCallback((e: MouseEvent) => {
        if (isDragging) {
            const newX = e.clientX - dragOffset.current.x;
            const newY = e.clientY - dragOffset.current.y;

            // Boundary checks
            const viewportWidth = window.innerWidth;
            const viewportHeight = window.innerHeight;

            setPosition({
                x: Math.min(Math.max(0, newX), viewportWidth - size.width),
                y: Math.min(Math.max(0, newY), viewportHeight - size.height)
            });
        }

        if (isResizing && dialogRef.current) {
            const rect = dialogRef.current.getBoundingClientRect();
            const newWidth = Math.max(600, e.clientX - rect.left);
            const newHeight = Math.max(400, e.clientY - rect.top);

            setSize({
                width: newWidth,
                height: newHeight
            });
        }
    }, [isDragging, isResizing, size]);

    const handleMouseUp = useCallback(() => {
        setIsDragging(false);
        setIsResizing(false);
    }, []);

    useEffect(() => {
        if (isDragging || isResizing) {
            window.addEventListener('mousemove', handleMouseMove);
            window.addEventListener('mouseup', handleMouseUp);
        } else {
            window.removeEventListener('mousemove', handleMouseMove);
            window.removeEventListener('mouseup', handleMouseUp);
        }
        return () => {
            window.removeEventListener('mousemove', handleMouseMove);
            window.removeEventListener('mouseup', handleMouseUp);
        };
    }, [isDragging, isResizing, handleMouseMove, handleMouseUp]);

    if (!isOpen) return null;

    return (
        <div
            ref={dialogRef}
            className="fixed z-[9999] shadow-[0_32px_120px_-20px_rgba(74,4,4,0.3)] border border-palette-maroon/15 rounded-[12px] flex flex-col overflow-hidden bg-white/98 backdrop-blur-2xl animate-in zoom-in-95 duration-300 ease-out"
            style={{
                left: `${position.x}px`,
                top: `${position.y}px`,
                width: `${size.width}px`,
                height: `${size.height}px`,
                position: 'fixed'
            }}
        >
            {/* Header / Drag Handle */}
            <div
                onMouseDown={handleMouseDown}
                className="drag-handle h-14 bg-gradient-to-r from-palette-maroon/[0.03] to-transparent border-b border-palette-maroon/5 flex items-center justify-between px-6 cursor-grab active:cursor-grabbing shrink-0 group"
            >
                <div className="flex items-center gap-4">
                    <div className="relative">
                        <div className="absolute inset-0 bg-palette-maroon blur-lg opacity-20 animate-pulse" />
                        <div className="relative w-9 h-9 bg-palette-maroon rounded-[8px] text-white shadow-xl flex items-center justify-center transform group-hover:scale-110 transition-transform duration-500">
                            <span className="material-symbols-rounded" style={{ fontSize: '20px' }}>auto_fix_high</span>
                        </div>
                    </div>
                    <div className="flex flex-col">
                        <span className="text-[14px] font-black text-palette-maroon tracking-[0.2em] uppercase leading-none selection:bg-transparent">
                            {t('admin.ai_assistant.title')}
                        </span>
                        <span className="text-[9px] font-bold text-palette-tan/40 uppercase tracking-widest mt-1 selection:bg-transparent">
                            Professional News Engine v3.4
                        </span>
                    </div>
                </div>
                <div className="flex items-center gap-3">
                    <div className="h-6 w-[1px] bg-palette-maroon/10 mx-2" />
                    <button
                        onClick={onClose}
                        className="w-9 h-9 rounded-full flex items-center justify-center hover:bg-palette-red/10 text-palette-maroon/30 hover:text-palette-red transition-all duration-300 active:scale-90"
                    >
                        <span className="material-symbols-rounded" style={{ fontSize: '22px' }}>close_fullscreen</span>
                    </button>
                </div>
            </div>

            <div className="flex-1 flex overflow-hidden">
                {/* Left Panel: Input */}
                <div className="flex-1 flex flex-col border-r border-palette-maroon/[0.04] bg-white relative">
                    <div className="h-14 flex items-center px-6 border-b border-palette-maroon/[0.02] gap-4">
                        <div className="flex items-center gap-2.5 shrink-0">
                            <span className="material-symbols-rounded text-palette-tan/60" style={{ fontSize: '16px' }}>edit_note</span>
                            <label className="text-[10px] font-black text-palette-tan uppercase tracking-[0.2em]">
                                {t('admin.ai_assistant.input')}
                            </label>
                        </div>

                        <div className="ml-auto flex items-center gap-2">
                            {/* Premium Selects Wrapper */}
                            <div className="flex items-center bg-palette-beige/20 p-1 rounded-[8px] border border-palette-maroon/5">
                                {/* Model Select */}
                                <div className="relative group">
                                    <select
                                        value={selectedModel}
                                        onChange={(e) => setSelectedModel(e.target.value)}
                                        className="appearance-none bg-white/40 hover:bg-white border-none rounded-[6px] pl-8 pr-3 py-1.5 text-[10px] font-black text-palette-maroon outline-none cursor-pointer transition-all min-w-[140px] tracking-tight"
                                    >
                                        <option value="" disabled>Model Seçin</option>
                                        {models.map((m) => (
                                            <option key={m} value={m}>
                                                {m}
                                            </option>
                                        ))}
                                    </select>
                                    <span className="absolute left-2.5 top-1/2 -translate-y-1/2 material-symbols-rounded text-palette-maroon/40" style={{ fontSize: '14px' }}>psychology</span>
                                </div>

                                <div className="w-[1px] h-4 bg-palette-maroon/5 mx-1" />

                                {/* Format Select */}
                                <div className="relative group">
                                    <select
                                        value={selectedFormat}
                                        onChange={(e) => setSelectedFormat(e.target.value)}
                                        className="appearance-none bg-white/40 hover:bg-white border-none rounded-[6px] pl-8 pr-3 py-1.5 text-[10px] font-black text-palette-maroon outline-none cursor-pointer transition-all max-w-[160px] tracking-tight"
                                    >
                                        <option value="">{t('ai_settings.tab.formats')}</option>
                                        {readyFormats.map(f => <option key={f.id} value={f.id}>{f.title}</option>)}
                                    </select>
                                    <span className="absolute left-2.5 top-1/2 -translate-y-1/2 material-symbols-rounded text-palette-maroon/40" style={{ fontSize: '14px' }}>format_list_bulleted</span>
                                </div>
                            </div>
                        </div>
                    </div>

                    <div className="flex-1 p-6 flex flex-col">
                        <textarea
                            value={content}
                            onChange={(e) => setContent(e.target.value)}
                            placeholder={t('admin.ai_assistant.placeholder')}
                            className="flex-1 w-full p-0 bg-transparent text-[15px] font-medium text-palette-maroon outline-none transition-all resize-none leading-relaxed overflow-y-auto custom-scrollbar placeholder:text-palette-tan/30"
                        />
                    </div>
                </div>

                {/* Right Panel: Output */}
                <div className="flex-1 flex flex-col bg-palette-beige/[0.03]">
                    <div className="h-14 flex items-center px-6 border-b border-palette-maroon/[0.02] gap-4">
                        <div className="flex items-center gap-2.5 shrink-0">
                            <span className="material-symbols-rounded text-palette-maroon/40" style={{ fontSize: '16px' }}>auto_awesome</span>
                            <label className="text-[10px] font-black text-palette-tan uppercase tracking-[0.2em]">
                                {t('admin.ai_assistant.output')}
                            </label>
                        </div>

                        <div className="ml-auto flex items-center gap-2">
                            {resultContent && (
                                <button
                                    onClick={handleCopy}
                                    className="flex items-center gap-2 px-3 py-1.5 rounded-[6px] bg-white border border-palette-maroon/5 text-palette-maroon hover:bg-palette-maroon hover:text-white transition-all duration-300 shadow-sm group"
                                >
                                    <span className="material-symbols-rounded group-hover:scale-110 transition-transform" style={{ fontSize: '16px' }}>
                                        {isCopied ? 'check' : 'content_copy'}
                                    </span>
                                    <span className="text-[10px] font-black uppercase tracking-widest">
                                        {isCopied ? t('admin.ai_assistant.copied') : t('admin.ai_assistant.copy')}
                                    </span>
                                </button>
                            )}

                            {canApply && (
                                <button
                                    onClick={handleApplyData}
                                    className="flex items-center gap-2 px-4 py-1.5 rounded-[6px] bg-emerald-500 text-white hover:bg-emerald-600 transition-all shadow-lg shadow-emerald-500/20 active:scale-95 group"
                                >
                                    <span className="material-symbols-rounded group-hover:translate-x-0.5 transition-transform" style={{ fontSize: '16px' }}>rocket_launch</span>
                                    <span className="text-[10px] font-black uppercase tracking-widest">{t('admin.ai_assistant.apply')}</span>
                                </button>
                            )}
                        </div>
                    </div>
                    <div className="flex-1 p-6 relative overflow-hidden">
                        {apiNotice && (
                            <div className="mb-4 flex items-start gap-2 px-4 py-3 bg-amber-500/5 border border-amber-100 rounded-[8px] text-amber-700">
                                <span className="material-symbols-rounded mt-0.5" style={{ fontSize: '16px', opacity: 0.9 }}>info</span>
                                <div className="text-[11px] font-bold leading-relaxed">{apiNotice}</div>
                            </div>
                        )}
                        {isGenerating ? (
                            <div className="h-full flex flex-col items-center justify-center text-palette-maroon/20">
                                <div className="w-16 h-16 relative flex items-center justify-center mb-6">
                                    <div className="absolute inset-0 border-4 border-palette-maroon/5 rounded-full" />
                                    <div className="absolute inset-0 border-4 border-palette-maroon border-t-transparent rounded-full animate-spin" />
                                    <span className="material-symbols-rounded" style={{ fontSize: '24px' }}>neurology</span>
                                </div>
                                <p className="text-[11px] font-black uppercase tracking-[0.4em] animate-pulse">{t('common.processing')}</p>
                            </div>
                        ) : (
                            resultContent ? (
                                <div className="h-full w-full overflow-y-auto custom-scrollbar selection:bg-palette-maroon/10">
                                    <div className="text-[14px] font-medium text-palette-maroon leading-relaxed whitespace-pre-wrap pb-10">
                                        {resultContent.replace(/\[\/?[A-Z]+\]/g, '')}
                                    </div>
                                </div>
                            ) : (
                                <div className="h-full flex flex-col items-center justify-center text-palette-tan/20">
                                    <div className="p-8 rounded-[20px] bg-palette-beige/5 border border-palette-maroon/[0.03] shadow-inner mb-4">
                                        <span className="material-symbols-rounded" style={{ fontSize: '64px', opacity: 0.1 }}>tempest</span>
                                    </div>
                                    <p className="text-[10px] font-black uppercase tracking-[0.3em]">{t('admin.ai_assistant.ready')}</p>
                                </div>
                            )
                        )}
                    </div>
                </div>
            </div>

            {/* Footer Actions */}
            <div className="h-20 bg-white border-t border-palette-maroon/[0.05] flex items-center justify-between px-8 shrink-0 bg-gradient-to-b from-transparent to-palette-beige/[0.03]">
                <div className="flex items-center gap-3">
                    <div className="flex items-center gap-1.5 px-3 py-1.5 rounded-full bg-emerald-50 text-emerald-600/80 border border-emerald-100">
                        <span className="w-1.5 h-1.5 rounded-full bg-emerald-500 animate-pulse"></span>
                        <span className="text-[9px] font-black uppercase tracking-widest">{t('admin.ai_assistant.ready')}</span>
                    </div>
                    <div className="flex items-center gap-2">
                        <label className={`flex items-center gap-2 px-3 py-1.5 rounded-full border transition-colors cursor-pointer select-none ${newsMedia.image ? 'bg-emerald-50 border-emerald-100' : 'bg-palette-beige/20 border-palette-maroon/5 hover:bg-palette-beige/30'}`}>
                            <input
                                type="checkbox"
                                checked={newsMedia.image}
                                onChange={(e) => setNewsMedia(prev => ({ ...prev, image: e.target.checked }))}
                                className={`w-3.5 h-3.5 rounded-[4px] border-palette-tan/30 cursor-pointer ${newsMedia.image ? 'text-emerald-600 focus:ring-emerald-600' : 'text-palette-maroon focus:ring-palette-maroon'}`}
                            />
                            <span className={`text-[9px] font-bold tracking-wide whitespace-nowrap ${newsMedia.image ? 'text-emerald-700' : 'text-palette-maroon/70'}`}>
                                {t('admin.ai_assistant.media.image')}
                            </span>
                        </label>
                        <label className={`flex items-center gap-2 px-3 py-1.5 rounded-full border transition-colors cursor-pointer select-none ${newsMedia.video ? 'bg-emerald-50 border-emerald-100' : 'bg-palette-beige/20 border-palette-maroon/5 hover:bg-palette-beige/30'}`}>
                            <input
                                type="checkbox"
                                checked={newsMedia.video}
                                onChange={(e) => setNewsMedia(prev => ({ ...prev, video: e.target.checked }))}
                                className={`w-3.5 h-3.5 rounded-[4px] border-palette-tan/30 cursor-pointer ${newsMedia.video ? 'text-emerald-600 focus:ring-emerald-600' : 'text-palette-maroon focus:ring-palette-maroon'}`}
                            />
                            <span className={`text-[9px] font-bold tracking-wide whitespace-nowrap ${newsMedia.video ? 'text-emerald-700' : 'text-palette-maroon/70'}`}>
                                {t('admin.ai_assistant.media.video')}
                            </span>
                        </label>
                        <label className={`flex items-center gap-2 px-3 py-1.5 rounded-full border transition-colors cursor-pointer select-none ${newsMedia.audio ? 'bg-emerald-50 border-emerald-100' : 'bg-palette-beige/20 border-palette-maroon/5 hover:bg-palette-beige/30'}`}>
                            <input
                                type="checkbox"
                                checked={newsMedia.audio}
                                onChange={(e) => setNewsMedia(prev => ({ ...prev, audio: e.target.checked }))}
                                className={`w-3.5 h-3.5 rounded-[4px] border-palette-tan/30 cursor-pointer ${newsMedia.audio ? 'text-emerald-600 focus:ring-emerald-600' : 'text-palette-maroon focus:ring-palette-maroon'}`}
                            />
                            <span className={`text-[9px] font-bold tracking-wide whitespace-nowrap ${newsMedia.audio ? 'text-emerald-700' : 'text-palette-maroon/70'}`}>
                                {t('admin.ai_assistant.media.audio')}
                            </span>
                        </label>
                    </div>
                </div>

                <div className="flex items-center gap-3">
                    <button
                        onClick={() => handleGenerate('make-ready')}
                        disabled={!content || isGenerating}
                        className="flex items-center gap-2 px-6 h-9 bg-palette-maroon text-white rounded-[6px] text-[11px] font-black uppercase tracking-[0.2em] hover:bg-palette-red transition-all shadow-[0_8px_20px_-8px_rgba(74,4,4,0.4)] active:scale-95 disabled:opacity-30 disabled:grayscale group relative overflow-hidden"
                    >
                        <span className="material-symbols-rounded" style={{ fontSize: '18px' }}>bolt</span>
                        <span className="relative z-10">{t('admin.ai_assistant.make_ready')}</span>
                        <div className="absolute inset-0 bg-white/10 opacity-0 group-hover:opacity-100 transition-opacity" />
                    </button>
                </div>
            </div>

            {/* Resize Handle */}
            <div
                className="absolute bottom-0 right-0 w-6 h-6 cursor-nwse-resize flex items-end justify-end p-1 group z-[100]"
                onMouseDown={handleResizeMouseDown}
            >
                <div className="w-2 h-2 border-r-2 border-b-2 border-palette-maroon/30 group-hover:border-palette-maroon/60 rounded-br-sm transition-colors" />
            </div>
        </div>
    );
};

export default AiAssistantDialog;
