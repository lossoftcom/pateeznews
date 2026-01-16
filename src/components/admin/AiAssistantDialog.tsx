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

### 5. SEO VE DERİNLİK (ONLINE PİRAMİT)
- Uzunluk: Konu detaylıysa SEO için uzun yazmaktan çekinme (1000+ kelime), modüler parçalarla böl.
- Kapanış: "Sırada ne var?" başlığıyla aksiyon odaklı bitir.

### ÇIKTI FORMATI (ZORUNLU):
Yanıtını MUTLAKA aşağıdaki formatta ver, başka hiçbir metin ekleme:
[TITLE]Haber Başlığı Buraya[/TITLE]
[SUMMARY]Haberin Spot Özeti Buraya[/SUMMARY]
[KEYWORDS]anahtar, kelime, listesi, buraya[/KEYWORDS]
[METATITLE]SEO Başlığı Buraya[/METATITLE]
[METADESC]SEO Açıklaması Buraya[/METADESC]
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

        return {
            title: extract('TITLE'),
            summary: extract('SUMMARY'),
            content: extract('CONTENT'),
            keywords: extract('KEYWORDS').split(',').map(k => k.trim()).filter(k => k),
            metaTitle: extract('METATITLE'),
            metaDesc: extract('METADESC')
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
[KEYWORDS]anahtar, kelime, listesi[/KEYWORDS]
[METATITLE]SEO Başlığı[/METATITLE]
[METADESC]SEO Açıklaması[/METADESC]
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
            className="fixed z-[9999] shadow-2xl border border-palette-maroon/15 rounded-[8px] flex flex-col overflow-hidden bg-white/95 backdrop-blur-xl animate-in zoom-in-95 duration-200"
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
                className="drag-handle h-12 bg-palette-maroon/5 border-b border-palette-maroon/10 flex items-center justify-between px-4 cursor-grab active:cursor-grabbing shrink-0 group"
            >
                <div className="flex items-center gap-3">
                    <div className="p-1.5 bg-palette-maroon rounded-[4px] text-white shadow-md flex items-center justify-center">
                        <span className="material-symbols-rounded" style={{ fontSize: '18px' }}>auto_fix_high</span>
                    </div>
                    <span className="text-sm font-black text-palette-maroon tracking-widest uppercase selection:bg-transparent">
                        {t('admin.ai_assistant.title')}
                    </span>
                </div>
                <div className="flex items-center gap-2">
                    <button
                        onClick={onClose}
                        className="w-8 h-8 rounded-full flex items-center justify-center hover:bg-palette-red/10 text-palette-maroon/40 hover:text-palette-red transition-all"
                    >
                        <span className="material-symbols-rounded" style={{ fontSize: '20px' }}>close</span>
                    </button>
                </div>
            </div>

            {/* Split View Content */}
            <div className="flex-1 flex overflow-hidden bg-palette-beige/5">
                {/* Left Panel: Input */}
                <div className="flex-1 flex flex-col border-r border-palette-tan/10 p-5">
                    <div className="flex items-center justify-between mb-2">
                        <label className="text-[11px] font-black text-palette-tan uppercase tracking-widest ml-1">
                            {t('admin.ai_assistant.input')}
                        </label>
                        <div className="flex items-center gap-2">
                            {/* Model Select */}
                            <div className="relative">
                                <span className="absolute left-2 top-1/2 -translate-y-1/2 material-symbols-rounded text-palette-tan/50 pointer-events-none" style={{ fontSize: '12px' }}>psychology</span>
                                <select
                                    value={selectedModel}
                                    onChange={(e) => setSelectedModel(e.target.value)}
                                    className="appearance-none bg-white border border-palette-tan/10 rounded pl-6 pr-4 py-1 text-[10px] font-bold text-palette-maroon outline-none focus:border-palette-maroon/30 cursor-pointer shadow-sm hover:bg-palette-beige/5 transition-all"
                                >
                                    {models.map(m => <option key={m} value={m}>{m}</option>)}
                                </select>
                            </div>

                            {/* Prompt Select */}
                            <div className="relative">
                                <span className="absolute left-2 top-1/2 -translate-y-1/2 material-symbols-rounded text-palette-tan/50 pointer-events-none" style={{ fontSize: '12px' }}>description</span>
                                <select
                                    value={selectedFormat}
                                    onChange={(e) => setSelectedFormat(e.target.value)}
                                    className="appearance-none bg-white border border-palette-tan/10 rounded pl-6 pr-4 py-1 text-[10px] font-bold text-palette-maroon outline-none focus:border-palette-maroon/30 cursor-pointer shadow-sm hover:bg-palette-beige/5 transition-all max-w-[200px]"
                                >
                                    <option value="">{t('ai_settings.tab.formats')}</option>
                                    {readyFormats.map(f => <option key={f.id} value={f.id}>{f.title}</option>)}
                                </select>
                            </div>
                        </div>
                    </div>
                    <textarea
                        value={content}
                        onChange={(e) => setContent(e.target.value)}
                        placeholder={t('admin.ai_assistant.placeholder')}
                        className="flex-1 w-full p-5 bg-white border border-palette-tan/10 rounded-[6px] text-sm font-medium text-palette-maroon outline-none focus:border-palette-maroon/30 transition-all resize-none shadow-inner leading-relaxed overflow-y-auto custom-scrollbar"
                    />
                </div>

                {/* Right Panel: Output */}
                <div className="flex-1 flex flex-col p-5 bg-white/40">
                    <div className="flex items-center justify-between mb-2">
                        <label className="text-[11px] font-black text-palette-tan uppercase tracking-widest ml-1">
                            {t('admin.ai_assistant.output')}
                        </label>
                        <div className="flex items-center gap-2">
                            {canApply && (
                                <button
                                    onClick={handleApplyData}
                                    className="flex items-center gap-1.5 px-3 py-1 rounded bg-emerald-500 text-white hover:bg-emerald-600 transition-all shadow-lg shadow-emerald-500/10 animate-in fade-in slide-in-from-right-2"
                                >
                                    <span className="material-symbols-rounded" style={{ fontSize: '16px' }}>send</span>
                                    <span className="text-[10px] font-bold uppercase tracking-tight">{t('admin.ai_assistant.apply')}</span>
                                </button>
                            )}
                            {resultContent && (
                                <button
                                    onClick={handleCopy}
                                    className="flex items-center gap-1.5 px-2 py-1 rounded bg-palette-maroon/5 text-palette-maroon hover:bg-palette-maroon/10 transition-all"
                                >
                                    <span className="material-symbols-rounded" style={{ fontSize: '14px' }}>
                                        {isCopied ? 'check' : 'content_copy'}
                                    </span>
                                    <span className="text-[10px] font-bold uppercase tracking-tight">
                                        {isCopied ? t('admin.ai_assistant.copied') : t('admin.ai_assistant.copy')}
                                    </span>
                                </button>
                            )}
                        </div>
                    </div>
                    <div className="flex-1 w-full p-5 bg-white border border-palette-tan/10 rounded-[6px] text-sm font-medium text-palette-maroon shadow-inner leading-relaxed overflow-y-auto custom-scrollbar selection:bg-palette-maroon/10">
                        {isGenerating ? (
                            <div className="h-full flex flex-col items-center justify-center text-palette-maroon/40 select-none">
                                <span className="material-symbols-rounded animate-spin mb-3" style={{ fontSize: '32px' }}>progress_activity</span>
                                <p className="text-[11px] font-bold uppercase tracking-widest">{t('common.processing')}</p>
                            </div>
                        ) : (
                            resultContent ? (
                                <div className="whitespace-pre-wrap font-medium">
                                    {resultContent.replace(/\[\/?[A-Z]+\]/g, (match) => {
                                        return ''; // Keep it clean for preview, but logic needs full text
                                    })}
                                    {/* Temporary display of raw tags for testing */}
                                    <div className="mt-4 pt-4 border-t border-palette-maroon/5 text-[10px] opacity-20 hidden">
                                        {resultContent}
                                    </div>
                                </div>
                            ) : (
                                <div className="h-full flex flex-col items-center justify-center text-palette-tan/30 select-none">
                                    <span className="material-symbols-rounded mb-2" style={{ fontSize: '48px' }}>magic_button</span>
                                    <p className="text-[11px] font-bold uppercase tracking-widest">{t('admin.ai_assistant.ready')}</p>
                                </div>
                            )
                        )}
                    </div>
                </div>
            </div>

            {/* Footer Actions */}
            <div className="h-20 bg-white border-t border-palette-maroon/10 flex items-center justify-between px-6 shrink-0 gap-4">
                <div className="shrink-0 flex items-center gap-1.5">
                    <span className="w-1.5 h-1.5 rounded-full bg-emerald-500 animate-pulse"></span>
                    <span className="text-[10px] font-bold text-palette-tan/40 uppercase tracking-widest">{t('admin.ai_assistant.ready')}</span>
                </div>

                <div className="flex items-center gap-3">
                    <button
                        onClick={() => handleGenerate('organize')}
                        disabled={!content || isGenerating}
                        className="flex items-center gap-2 px-5 py-2.5 bg-palette-maroon/5 text-palette-maroon border border-palette-maroon/10 rounded-[4px] font-black text-[11px] tracking-widest hover:bg-palette-maroon/10 transition-all disabled:opacity-50 disabled:cursor-not-allowed"
                    >
                        <span className="material-symbols-rounded" style={{ fontSize: '18px' }}>auto_fix</span>
                        {t('admin.ai_assistant.organize')}
                    </button>

                    <button
                        onClick={() => handleGenerate('make-ready')}
                        disabled={!content || isGenerating}
                        className="flex items-center gap-2 px-8 py-2.5 bg-palette-maroon text-white rounded-[4px] font-black text-[11px] tracking-widest hover:bg-palette-red transition-all shadow-xl shadow-palette-maroon/20 active:scale-95 disabled:opacity-50 disabled:cursor-not-allowed group relative overflow-hidden"
                    >
                        <div className="absolute inset-0 bg-gradient-to-r from-transparent via-white/10 to-transparent -translate-x-full group-hover:animate-shimmer" />
                        <span className="material-symbols-rounded" style={{ fontSize: '18px' }}>stars</span>
                        {t('admin.ai_assistant.make_ready')}
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
