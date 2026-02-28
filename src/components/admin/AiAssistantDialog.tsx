import React, { useState, useEffect, useRef, useCallback } from 'react';
import { useLanguage } from '@/context/LanguageContext';
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
    const [position, setPosition] = useState({ x: 100, y: 100 });
    const [size, setSize] = useState({ width: 900, height: 600 });
    const [isDragging, setIsDragging] = useState(false);
    const [isResizing, setIsResizing] = useState(false);
    const [content, setContent] = useState('');
    const [resultContent, setResultContent] = useState('');
    const [isCopied, setIsCopied] = useState(false);
    const [isGenerating, setIsGenerating] = useState(false);
    const [canApply, setCanApply] = useState(false);

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
                if (data.google_ai_model) setSelectedModel(data.google_ai_model);
                if (data.google_ai_api_key) {
                    setApiKey(data.google_ai_api_key);
                    fetchModels(data.google_ai_api_key);
                }
            }
        } catch (err) {
            console.error('Error fetching AI settings:', err);
        }
    };

    const fetchModels = async (key: string) => {
        try {
            const response = await fetch(`https://generativelanguage.googleapis.com/v1beta/models?key=${key}`);
            const data = await response.json();
            if (data.models) {
                const availableModels = data.models
                    .filter((m: any) => m.supportedGenerationMethods.includes('generateContent'))
                    .map((m: any) => m.name.replace('models/', ''));
                setModels(availableModels);

                // If current selected model is not in the list, but list is not empty, maybe update?
                // Actually, let's keep the selected one if it's valid, otherwise the dropdown will handle it.
            }
        } catch (err) {
            console.error('Error fetching models:', err);
        }
    };

    const fetchReadyFormats = async () => {
        try {
            const { data, error } = await supabase
                .from('ai_ready_formats')
                .select('*')
                .eq('language_code', currentLang.code)
                .eq('is_active', true)
                .order('title');
            if (data) {
                setReadyFormats(data);
                // No auto-select, let user pick
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
        const extract = (tag: string) => {
            const regex = new RegExp(`\\[${tag}\\]([\\s\\S]*?)\\[\\/${tag}\\]`);
            const match = text.match(regex);
            return match ? match[1].trim() : '';
        };

        const faqRaw = extract('FAQ');
        const faqs: { q: string, a: string }[] = [];
        if (faqRaw) {
            const pairs = faqRaw.split(/S:/).filter(p => p.trim());
            pairs.forEach(p => {
                const parts = p.split(/C:/);
                if (parts.length === 2) {
                    faqs.push({
                        q: parts[0].replace(/\?$/, '').trim() + '?',
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

        if (!apiKey) {
            alert("AI API Key bulunamadı. Lütfen Ayarlar > AI Ayarları kısmından API anahtarınızı girin.");
            return;
        }

        setIsGenerating(true);
        setCanApply(false);
        setResultContent('');

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

            const finalPrompt = systemPrompt + outputInstruction + "\n\nKonu / İçerik:\n" + content;

            const response = await fetch(`https://generativelanguage.googleapis.com/v1beta/models/${selectedModel}:generateContent?key=${apiKey}`, {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json'
                },
                body: JSON.stringify({
                    contents: [{
                        parts: [{
                            text: finalPrompt
                        }]
                    }],
                    generationConfig: {
                        temperature: 0.7,
                        topK: 40,
                        topP: 0.95,
                        maxOutputTokens: 2048,
                    }
                })
            });

            const data = await response.json();

            if (data.error) {
                throw new Error(data.error.message);
            }

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
                                        {models.map(m => <option key={m} value={m}>{m.toUpperCase()}</option>)}
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
                </div>

                <div className="flex items-center gap-3">
                    <button
                        onClick={() => handleGenerate('organize')}
                        disabled={!content || isGenerating}
                        className="flex items-center gap-2 px-4 h-9 bg-white border border-palette-maroon/10 rounded-[6px] text-palette-maroon text-[10px] font-black uppercase tracking-widest hover:border-palette-maroon/30 hover:shadow-md transition-all active:scale-95 disabled:opacity-30 disabled:grayscale"
                    >
                        <span className="material-symbols-rounded" style={{ fontSize: '16px', opacity: 0.6 }}>brush</span>
                        {t('admin.ai_assistant.organize')}
                    </button>

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
