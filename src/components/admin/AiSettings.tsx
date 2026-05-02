import React, { useState, useEffect } from 'react';
import { neon } from '@/lib/neon';
import { useLanguage } from '@/context/LanguageContext';
import { useNeonSession } from '@/hooks/useNeonSession';
import { useToast } from '@/context/ToastContext';
import { BUILTIN_EVENT_READY_FORMATS, BUILTIN_POLL_READY_FORMATS, BUILTIN_QUIZ_READY_FORMATS, BUILTIN_RECIPE_READY_FORMATS, BUILTIN_TOC_READY_FORMATS, BUILTIN_VIDEO_READY_FORMATS } from '@/lib/aiReadyFormats';

type WeatherLocationResult = {
    id?: number;
    name: string;
    latitude: number;
    longitude: number;
    timezone?: string;
    country?: string;
    admin1?: string;
};

const DEFAULT_WEATHER_FORM = {
    weather_enabled: true,
    weather_location_name: 'Niğde',
    weather_location_country: 'Türkiye',
    weather_latitude: '37.96583',
    weather_longitude: '34.67935',
    weather_timezone: 'Europe/Istanbul',
    weather_update_interval_minutes: 30
};

const AiSettings: React.FC = () => {
    const { t } = useLanguage();
    const { user } = useNeonSession();
    const { showToast } = useToast();
    const [loading, setLoading] = useState(true);
    const [saving, setSaving] = useState(false);
    const [activeTab, setActiveTab] = useState('google');
    const [languages, setLanguages] = useState<{ code: string; name: string }[]>([]);
    const [settingsLanguage, setSettingsLanguage] = useState('tr');

    const [formData, setFormData] = useState({
        google_ai_apiKey: '',
        google_ai_model: '',
        google_ai_active: false
    });

    const [formats, setFormats] = useState<any[]>([]);
    const [formatsLoading, setFormatsLoading] = useState(false);
    const [showFormatModal, setShowFormatModal] = useState(false);
    const [editingFormat, setEditingFormat] = useState<any>(null);
    const [formatFormData, setFormatFormData] = useState({ title: '', prompt: '' });
    const [isTesting, setIsTesting] = useState(false);
    const [fetchedModels, setFetchedModels] = useState<string[]>([]);
    const [weatherFormData, setWeatherFormData] = useState(DEFAULT_WEATHER_FORM);
    const [weatherSearchTerm, setWeatherSearchTerm] = useState('Niğde');
    const [weatherSearchResults, setWeatherSearchResults] = useState<WeatherLocationResult[]>([]);
    const [weatherSearching, setWeatherSearching] = useState(false);
    const [weatherPreview, setWeatherPreview] = useState<any>(null);
    const [weatherTesting, setWeatherTesting] = useState(false);

    const fetchGeminiModels = async (apiKey: string, preferredModel?: string) => {
        const encodedKey = encodeURIComponent(apiKey);

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
                if (data?.error) return { modelIds: [] as string[], error: String(data.error.message || 'Unknown error') };
                return { modelIds: extractModelIds(data), error: '' };
            } catch (err: any) {
                return { modelIds: [] as string[], error: String(err?.message || 'Network error') };
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

        if (baseModelIds.length === 0) {
            const message = v1Res.error || v1betaRes.error || 'Model listesi alınamadı.';
            throw new Error(message);
        }
        return baseModelIds;
    };

    useEffect(() => {
        fetchLanguages();
    }, []);

    useEffect(() => {
        fetchSettings();
        if (activeTab === 'formats') {
            fetchFormats();
        }
    }, [settingsLanguage, activeTab]);

    useEffect(() => {
        if (fetchedModels.length === 0) return;
        if (formData.google_ai_model && fetchedModels.includes(formData.google_ai_model)) return;
        const fallback = fetchedModels.find((m) => m.toLowerCase().includes('-flash')) || fetchedModels[0];
        setFormData((prev) => ({ ...prev, google_ai_model: fallback }));
    }, [fetchedModels]);

    const fetchLanguages = async () => {
        try {
            const { data, error } = await neon
                .from('languages')
                .select('code, name')
                .eq('status', 'active')
                .order('name');
            if (error) throw error;
            setLanguages(data || []);
        } catch (err) {
            console.error('Error fetching languages:', err);
        }
    };

    const fetchFormats = async () => {
        setFormatsLoading(true);
        try {
            const { data, error } = await neon
                .from('ai_ready_formats')
                .select('*')
                .eq('language_code', settingsLanguage)
                .order('created_at', { ascending: false });
            if (error) throw error;
            setFormats(data || []);
        } catch (err) {
            console.error('Error fetching formats:', err);
        } finally {
            setFormatsLoading(false);
        }
    };

    const fetchSettings = async () => {
        setLoading(true);
        try {
            const { data, error } = await neon
                .from('site_settings')
                .select('google_ai_api_key, google_ai_model, google_ai_active, weather_enabled, weather_location_name, weather_location_country, weather_latitude, weather_longitude, weather_timezone, weather_update_interval_minutes')
                .eq('language_code', settingsLanguage)
                .maybeSingle();

            if (error) throw error;

            if (data) {
                setFormData({
                    google_ai_apiKey: data.google_ai_api_key || '',
                    google_ai_model: data.google_ai_model || '',
                    google_ai_active: data.google_ai_active || false
                });
                const nextWeather = {
                    weather_enabled: data.weather_enabled !== false,
                    weather_location_name: data.weather_location_name || DEFAULT_WEATHER_FORM.weather_location_name,
                    weather_location_country: data.weather_location_country || DEFAULT_WEATHER_FORM.weather_location_country,
                    weather_latitude: String(data.weather_latitude ?? DEFAULT_WEATHER_FORM.weather_latitude),
                    weather_longitude: String(data.weather_longitude ?? DEFAULT_WEATHER_FORM.weather_longitude),
                    weather_timezone: data.weather_timezone || DEFAULT_WEATHER_FORM.weather_timezone,
                    weather_update_interval_minutes: Number(data.weather_update_interval_minutes || DEFAULT_WEATHER_FORM.weather_update_interval_minutes)
                };
                setWeatherFormData(nextWeather);
                setWeatherSearchTerm(nextWeather.weather_location_name);
                if (data.google_ai_api_key) {
                    fetchGeminiModels(data.google_ai_api_key, data.google_ai_model || '').then(setFetchedModels).catch((err) => {
                        console.error('Error fetching Gemini models:', err);
                        setFetchedModels([]);
                    });
                } else {
                    setFetchedModels([]);
                }
            } else {
                setFormData({
                    google_ai_apiKey: '',
                    google_ai_model: '',
                    google_ai_active: false
                });
                setWeatherFormData(DEFAULT_WEATHER_FORM);
                setWeatherSearchTerm(DEFAULT_WEATHER_FORM.weather_location_name);
                setFetchedModels([]);
            }
        } catch (err) {
            console.error('Error fetching AI settings:', err);
        } finally {
            setLoading(false);
        }
    };

    const handleTestApi = async () => {
        if (!formData.google_ai_apiKey) {
            showToast(t('ai_settings.test_error'), 'error');
            return;
        }

        setIsTesting(true);
        try {
            const models = await fetchGeminiModels(formData.google_ai_apiKey, formData.google_ai_model);
            setFetchedModels(models);
            if (models.length > 0) {
                showToast(t('ai_settings.test_success'), 'success');
            } else {
                showToast(t('ai_settings.no_models'), 'warning');
            }
        } catch (err: any) {
            console.error('API Test Error:', err);
            showToast(`${t('ai_settings.test_error')} (${err.message})`, 'error');
        } finally {
            setIsTesting(false);
        }
    };

    const handleSave = async (e: React.FormEvent) => {
        e.preventDefault();
        setSaving(true);

        try {
            const { error } = await neon
                .from('site_settings')
                .upsert({
                    language_code: settingsLanguage,
                    google_ai_api_key: formData.google_ai_apiKey,
                    google_ai_model: formData.google_ai_model,
                    google_ai_active: formData.google_ai_active,
                    updated_at: new Date().toISOString()
                }, { onConflict: 'language_code' });

            if (error) throw error;
            showToast(t('ai_settings.save_success'), 'success');
        } catch (err) {
            console.error('Error saving AI settings:', err);
            showToast(t('ai_settings.save_error'), 'error');
        } finally {
            setSaving(false);
        }
    };

    const handleWeatherSearch = async () => {
        const query = weatherSearchTerm.trim();
        if (query.length < 2) {
            showToast(t('ai_settings.weather.search_min'), 'warning');
            return;
        }

        setWeatherSearching(true);
        setWeatherSearchResults([]);
        try {
            const searchUrl = new URL('https://geocoding-api.open-meteo.com/v1/search');
            searchUrl.searchParams.set('name', query);
            searchUrl.searchParams.set('count', '8');
            searchUrl.searchParams.set('format', 'json');
            searchUrl.searchParams.set('language', settingsLanguage || 'tr');

            const response = await fetch(searchUrl.toString(), { headers: { Accept: 'application/json' } });
            const data = await response.json().catch(() => ({}));
            if (!response.ok || data?.error) throw new Error(data?.reason || 'Open-Meteo geocoding error');

            setWeatherSearchResults(Array.isArray(data?.results) ? data.results : []);
            if (!data?.results?.length) showToast(t('ai_settings.weather.no_results'), 'info');
        } catch (err: any) {
            console.error('Weather location search error:', err);
            showToast(`${t('ai_settings.weather.search_error')} (${err.message})`, 'error');
        } finally {
            setWeatherSearching(false);
        }
    };

    const handleWeatherSelect = (location: WeatherLocationResult) => {
        const latitude = Number(location.latitude);
        const longitude = Number(location.longitude);
        if (!Number.isFinite(latitude) || !Number.isFinite(longitude)) return;

        setWeatherFormData({
            weather_enabled: true,
            weather_location_name: location.name || DEFAULT_WEATHER_FORM.weather_location_name,
            weather_location_country: location.country || '',
            weather_latitude: String(latitude),
            weather_longitude: String(longitude),
            weather_timezone: location.timezone || DEFAULT_WEATHER_FORM.weather_timezone,
            weather_update_interval_minutes: 30
        });
        setWeatherSearchTerm(location.name || '');
        setWeatherSearchResults([]);
        setWeatherPreview(null);
    };

    const handleWeatherTest = async () => {
        const latitude = Number(weatherFormData.weather_latitude);
        const longitude = Number(weatherFormData.weather_longitude);
        if (!Number.isFinite(latitude) || !Number.isFinite(longitude)) {
            showToast(t('ai_settings.weather.coords_error'), 'error');
            return;
        }

        setWeatherTesting(true);
        setWeatherPreview(null);
        try {
            const forecastUrl = new URL('https://api.open-meteo.com/v1/forecast');
            forecastUrl.searchParams.set('latitude', String(latitude));
            forecastUrl.searchParams.set('longitude', String(longitude));
            forecastUrl.searchParams.set('current', 'temperature_2m,apparent_temperature,weather_code');
            forecastUrl.searchParams.set('daily', 'weather_code,temperature_2m_max,temperature_2m_min');
            forecastUrl.searchParams.set('forecast_days', '5');
            forecastUrl.searchParams.set('timezone', weatherFormData.weather_timezone || DEFAULT_WEATHER_FORM.weather_timezone);

            const response = await fetch(forecastUrl.toString(), { headers: { Accept: 'application/json' } });
            const data = await response.json().catch(() => ({}));
            if (!response.ok || data?.error) throw new Error(data?.reason || 'Open-Meteo forecast error');

            setWeatherPreview(data);
            showToast(t('ai_settings.weather.test_success'), 'success');
        } catch (err: any) {
            console.error('Weather test error:', err);
            showToast(`${t('ai_settings.weather.test_error')} (${err.message})`, 'error');
        } finally {
            setWeatherTesting(false);
        }
    };

    const handleSaveWeather = async (e: React.FormEvent) => {
        e.preventDefault();
        const latitude = Number(weatherFormData.weather_latitude);
        const longitude = Number(weatherFormData.weather_longitude);

        if (!Number.isFinite(latitude) || !Number.isFinite(longitude)) {
            showToast(t('ai_settings.weather.coords_error'), 'error');
            return;
        }

        setSaving(true);
        try {
            const { error } = await neon
                .from('site_settings')
                .upsert({
                    language_code: settingsLanguage,
                    weather_enabled: weatherFormData.weather_enabled,
                    weather_location_name: weatherFormData.weather_location_name.trim() || DEFAULT_WEATHER_FORM.weather_location_name,
                    weather_location_country: weatherFormData.weather_location_country.trim(),
                    weather_latitude: latitude,
                    weather_longitude: longitude,
                    weather_timezone: weatherFormData.weather_timezone.trim() || DEFAULT_WEATHER_FORM.weather_timezone,
                    weather_update_interval_minutes: 30,
                    updated_at: new Date().toISOString()
                }, { onConflict: 'language_code' });

            if (error) throw error;
            showToast(t('ai_settings.weather.save_success'), 'success');
        } catch (err: any) {
            console.error('Error saving weather settings:', err);
            showToast(`${t('ai_settings.weather.save_error')} (${err.message})`, 'error');
        } finally {
            setSaving(false);
        }
    };

    const handleSaveFormat = async (e: React.FormEvent) => {
        e.preventDefault();
        setSaving(true);
        try {
            if (editingFormat) {
                const { error } = await neon
                    .from('ai_ready_formats')
                    .update({
                        title: formatFormData.title,
                        prompt: formatFormData.prompt,
                        updated_at: new Date().toISOString()
                    })
                    .eq('id', editingFormat.id);
                if (error) throw error;
                showToast(t('ai_settings.formats.save_success'), 'success');
            } else {
                const { error } = await neon
                    .from('ai_ready_formats')
                    .insert([{
                        title: formatFormData.title,
                        prompt: formatFormData.prompt,
                        language_code: settingsLanguage
                    }]);
                if (error) throw error;
                showToast(t('ai_settings.formats.save_success'), 'success');
            }
            setShowFormatModal(false);
            setEditingFormat(null);
            setFormatFormData({ title: '', prompt: '' });
            fetchFormats();
        } catch (err) {
            console.error('Error saving format:', err);
            showToast(t('common.error'), 'error');
        } finally {
            setSaving(false);
        }
    };

    const handleDeleteFormat = async (id: string) => {
        if (!confirm(t('ai_settings.formats.delete_confirm'))) return;
        try {
            const { error } = await neon
                .from('ai_ready_formats')
                .delete()
                .eq('id', id);
            if (error) throw error;
            showToast(t('ai_settings.formats.delete_success'), 'success');
            fetchFormats();
        } catch (err) {
            console.error('Error deleting format:', err);
            showToast(t('common.error'), 'error');
        }
    };

    const tabs = [
        { id: 'google', label: t('ai_settings.tab.google'), icon: 'psychology' },
        { id: 'formats', label: t('ai_settings.tab.formats'), icon: 'description' },
    ];
    const builtinReadyFormats = [...BUILTIN_QUIZ_READY_FORMATS, ...BUILTIN_POLL_READY_FORMATS, ...BUILTIN_VIDEO_READY_FORMATS, ...BUILTIN_TOC_READY_FORMATS, ...BUILTIN_RECIPE_READY_FORMATS, ...BUILTIN_EVENT_READY_FORMATS];
    const builtinFormatTitles = new Set(
        builtinReadyFormats.map((format) => format.title.trim().toLocaleLowerCase('tr-TR'))
    );
    const visibleFormats = [
        ...builtinReadyFormats,
        ...formats.filter((format) => !builtinFormatTitles.has(String(format?.title || '').trim().toLocaleLowerCase('tr-TR'))),
    ];

    if (loading) {
        return (
            <div className="flex items-center justify-center p-20">
                <span className="material-symbols-rounded animate-spin text-palette-tan" style={{ fontSize: '40px' }}>progress_activity</span>
            </div>
        );
    }

    return (
        <div className="animate-in fade-in duration-500 admin-font pb-20 text-palette-tan mx-auto px-4 sm:px-6 lg:px-8">
            <div className="mb-10 flex flex-col sm:flex-row sm:items-center sm:justify-between gap-6">
                <div>
                    <h2 className="text-3xl font-black text-palette-maroon tracking-tighter leading-none mb-2">
                        {t('ai_settings.page_title')}
                    </h2>
                    <p className="text-[12px] font-bold text-palette-tan/50 tracking-wider">
                        {t('ai_settings.page_desc')}
                    </p>
                </div>

                <div className="flex items-center gap-2 bg-white/50 p-1.5 rounded-[5px] border border-palette-tan/20">
                    <span className="material-symbols-rounded text-palette-tan text-[18px] ml-1">language</span>
                    <select
                        value={settingsLanguage}
                        onChange={(e) => setSettingsLanguage(e.target.value)}
                        className="bg-transparent border-none text-[12px] font-bold text-palette-maroon focus:ring-0 cursor-pointer pr-8"
                    >
                        {languages.map((lang) => (
                            <option key={lang.code} value={lang.code}>
                                {lang.name}
                            </option>
                        ))}
                    </select>
                </div>
            </div>

            <div className="grid grid-cols-1 lg:grid-cols-4 gap-8">
                {/* Sidebar Nav */}
                <div className="lg:col-span-1">
                    <nav className="flex flex-col gap-2">
                        {tabs.map((tab) => (
                            <button
                                key={tab.id}
                                onClick={() => setActiveTab(tab.id)}
                                className={`w-full text-left p-4 rounded-[3px] border transition-all ${activeTab === tab.id
                                    ? 'bg-palette-maroon border-palette-maroon text-white shadow-xl scale-105'
                                    : 'bg-white border-palette-tan/15 text-palette-tan hover:border-palette-tan/30'
                                    }`}
                            >
                                <div className="flex items-center justify-between">
                                    <div className="flex items-center gap-3">
                                        <span className="material-symbols-rounded" style={{ fontSize: '20px' }}>
                                            {tab.icon}
                                        </span>
                                        <span className="font-bold text-sm">{tab.label}</span>
                                    </div>
                                    {activeTab === tab.id && <span className="material-symbols-rounded" style={{ fontSize: '16px' }}>check_circle</span>}
                                </div>
                            </button>
                        ))}
                    </nav>
                </div>

                {/* Content */}
                <div className="lg:col-span-3">
                    {activeTab === 'google' ? (
                        <form onSubmit={handleSave} className="space-y-6">
                            <div className="bg-white rounded-[5px] border border-palette-tan/20 shadow-sm overflow-hidden text-palette-maroon">
                                <div className="p-6 border-b border-palette-tan/10 bg-palette-beige/5">
                                    <h3 className="text-[14px] font-black tracking-widest flex items-center gap-2 uppercase">
                                        <span className="material-symbols-rounded text-palette-red text-[20px]">psychology</span>
                                        {t('ai_settings.tab.google')}
                                    </h3>
                                </div>

                                <div className="p-6 space-y-6">
                                    <div className="flex items-center justify-between p-4 bg-palette-beige/20 rounded-[5px] border border-palette-tan/10">
                                        <div className="flex items-center gap-3">
                                            <div className="w-10 h-10 bg-white rounded-[5px] border border-palette-tan/20 flex items-center justify-center shadow-sm">
                                                <span className="material-symbols-rounded text-palette-red" style={{ fontSize: '24px' }}>
                                                    {formData.google_ai_active ? 'check_circle' : 'motion_photos_off'}
                                                </span>
                                            </div>
                                            <div>
                                                <p className="text-[13px] font-bold">{t('ai_settings.google_ai_active')}</p>
                                                <p className="text-[11px] text-palette-tan font-medium">Google AI servislerini etkinleştir.</p>
                                            </div>
                                        </div>
                                        <button
                                            type="button"
                                            onClick={() => setFormData({ ...formData, google_ai_active: !formData.google_ai_active })}
                                            className={`w-12 h-6 rounded-full transition-colors relative ${formData.google_ai_active ? 'bg-palette-red' : 'bg-palette-tan/20'
                                                }`}
                                        >
                                            <div
                                                className={`absolute top-1 left-1 w-4 h-4 bg-white rounded-full transition-transform ${formData.google_ai_active ? 'translate-x-6' : 'translate-x-0'
                                                    }`}
                                            />
                                        </button>
                                    </div>

                                    <div className="space-y-4">
                                        <div className="space-y-1.5">
                                            <label className="text-[11px] font-black text-palette-tan tracking-widest uppercase ml-1">
                                                {t('ai_settings.google_ai_apiKey')}
                                            </label>
                                            <div className="flex gap-2">
                                                <div className="relative group flex-1">
                                                    <span className="absolute left-4 top-1/2 -translate-y-1/2 material-symbols-rounded text-palette-tan/50 group-focus-within:text-palette-red transition-colors" style={{ fontSize: '20px' }}>key</span>
                                                    <input
                                                        type="password"
                                                        value={formData.google_ai_apiKey}
                                                        onChange={(e) => setFormData({ ...formData, google_ai_apiKey: e.target.value })}
                                                        className="w-full h-12 bg-palette-beige/10 border border-palette-tan/20 rounded-[5px] pl-12 pr-4 text-[13px] font-bold focus:border-palette-red focus:ring-4 focus:ring-palette-red/5 transition-all outline-none"
                                                        placeholder="Google AI API Key..."
                                                    />
                                                </div>
                                                <button
                                                    type="button"
                                                    onClick={handleTestApi}
                                                    disabled={isTesting || !formData.google_ai_apiKey}
                                                    className="px-4 h-12 bg-palette-beige/20 border border-palette-tan/20 rounded-[5px] text-[11px] font-black text-palette-maroon uppercase tracking-widest hover:bg-palette-maroon hover:text-white transition-all disabled:opacity-50 flex items-center gap-2"
                                                >
                                                    {isTesting ? (
                                                        <span className="material-symbols-rounded animate-spin" style={{ fontSize: '18px' }}>progress_activity</span>
                                                    ) : (
                                                        <span className="material-symbols-rounded" style={{ fontSize: '18px' }}>quiz</span>
                                                    )}
                                                    {isTesting ? t('ai_settings.testing') : t('ai_settings.test_api')}
                                                </button>
                                            </div>
                                        </div>

                                        <div className="space-y-1.5">
                                            <label className="text-[11px] font-black text-palette-tan tracking-widest uppercase ml-1">
                                                {t('ai_settings.google_ai_model')}
                                            </label>
                                            <div className="relative group">
                                                <span className="absolute left-4 top-1/2 -translate-y-1/2 material-symbols-rounded text-palette-tan/50 group-focus-within:text-palette-red transition-colors" style={{ fontSize: '20px' }}>model_training</span>
                                                <select
                                                    value={formData.google_ai_model}
                                                    onChange={(e) => setFormData({ ...formData, google_ai_model: e.target.value })}
                                                    className="w-full h-12 bg-palette-beige/10 border border-palette-tan/20 rounded-[5px] pl-12 pr-10 text-[13px] font-bold focus:border-palette-red focus:ring-4 focus:ring-palette-red/5 transition-all appearance-none cursor-pointer outline-none"
                                                >
                                                    <option value="" disabled>
                                                        {fetchedModels.length > 0 ? 'Model Seçin' : 'API bağlantısını test edin'}
                                                    </option>
                                                    {fetchedModels.map((model) => (
                                                        <option key={model} value={model}>
                                                            {model}
                                                        </option>
                                                    ))}
                                                </select>
                                                <span className="absolute right-4 top-1/2 -translate-y-1/2 material-symbols-rounded text-palette-tan/50 pointer-events-none" style={{ fontSize: '20px' }}>expand_more</span>
                                            </div>
                                        </div>
                                    </div>
                                </div>
                            </div>

                            <div className="flex justify-end pt-8 border-t border-palette-tan/5">
                                <button
                                    type="submit"
                                    disabled={saving}
                                    className="flex items-center gap-2 px-6 h-10 bg-palette-red text-white rounded-[5px] text-[13px] font-black tracking-widest hover:bg-palette-maroon transition-all shadow-lg shadow-palette-red/10 active:scale-95 uppercase disabled:opacity-50"
                                >
                                    {saving ? (
                                        <>
                                            <span className="material-symbols-rounded animate-spin" style={{ fontSize: '20px' }}>progress_activity</span>
                                            {t('common.saving')}
                                        </>
                                    ) : (
                                        <>
                                            <span className="material-symbols-rounded" style={{ fontSize: '20px' }}>save</span>
                                            {t('common.save_changes')}
                                        </>
                                    )}
                                </button>
                            </div>
                        </form>
                    ) : activeTab === 'weather' ? (
                        <form onSubmit={handleSaveWeather} className="space-y-6">
                            <div className="bg-white rounded-[5px] border border-palette-tan/20 shadow-sm overflow-hidden text-palette-maroon">
                                <div className="p-6 border-b border-palette-tan/10 bg-palette-beige/5 flex items-center justify-between gap-4">
                                    <h3 className="text-[14px] font-black tracking-widest flex items-center gap-2 uppercase">
                                        <span className="material-symbols-rounded text-palette-red text-[20px]">partly_cloudy_day</span>
                                        {t('ai_settings.tab.weather')}
                                    </h3>
                                    <span className="px-3 py-1 rounded-[5px] bg-emerald-50 text-emerald-700 border border-emerald-100 text-[10px] font-black uppercase tracking-widest">
                                        Open-Meteo
                                    </span>
                                </div>

                                <div className="p-6 space-y-6">
                                    <div className="flex items-center justify-between p-4 bg-palette-beige/20 rounded-[5px] border border-palette-tan/10">
                                        <div className="flex items-center gap-3">
                                            <div className="w-10 h-10 bg-white rounded-[5px] border border-palette-tan/20 flex items-center justify-center shadow-sm">
                                                <span className="material-symbols-rounded text-palette-red" style={{ fontSize: '24px' }}>
                                                    {weatherFormData.weather_enabled ? 'check_circle' : 'motion_photos_off'}
                                                </span>
                                            </div>
                                            <div>
                                                <p className="text-[13px] font-bold">{t('ai_settings.weather.active')}</p>
                                                <p className="text-[11px] text-palette-tan font-medium">{t('ai_settings.weather.active_desc')}</p>
                                            </div>
                                        </div>
                                        <button
                                            type="button"
                                            onClick={() => setWeatherFormData({ ...weatherFormData, weather_enabled: !weatherFormData.weather_enabled })}
                                            className={`w-12 h-6 rounded-full transition-colors relative ${weatherFormData.weather_enabled ? 'bg-palette-red' : 'bg-palette-tan/20'
                                                }`}
                                        >
                                            <div
                                                className={`absolute top-1 left-1 w-4 h-4 bg-white rounded-full transition-transform ${weatherFormData.weather_enabled ? 'translate-x-6' : 'translate-x-0'
                                                    }`}
                                            />
                                        </button>
                                    </div>

                                    <div className="space-y-2">
                                        <label className="text-[11px] font-black text-palette-tan tracking-widest uppercase ml-1">
                                            {t('ai_settings.weather.search_label')}
                                        </label>
                                        <div className="flex gap-2">
                                            <div className="relative group flex-1">
                                                <span className="absolute left-4 top-1/2 -translate-y-1/2 material-symbols-rounded text-palette-tan/50 group-focus-within:text-palette-red transition-colors" style={{ fontSize: '20px' }}>travel_explore</span>
                                                <input
                                                    type="text"
                                                    value={weatherSearchTerm}
                                                    onChange={(e) => setWeatherSearchTerm(e.target.value)}
                                                    onKeyDown={(event) => {
                                                        if (event.key === 'Enter') {
                                                            event.preventDefault();
                                                            handleWeatherSearch();
                                                        }
                                                    }}
                                                    className="w-full h-12 bg-palette-beige/10 border border-palette-tan/20 rounded-[5px] pl-12 pr-4 text-[13px] font-bold focus:border-palette-red focus:ring-4 focus:ring-palette-red/5 transition-all outline-none"
                                                    placeholder={t('ai_settings.weather.search_placeholder')}
                                                />
                                            </div>
                                            <button
                                                type="button"
                                                onClick={handleWeatherSearch}
                                                disabled={weatherSearching}
                                                className="px-4 h-12 bg-palette-beige/20 border border-palette-tan/20 rounded-[5px] text-[11px] font-black text-palette-maroon uppercase tracking-widest hover:bg-palette-maroon hover:text-white transition-all disabled:opacity-50 flex items-center gap-2"
                                            >
                                                {weatherSearching ? (
                                                    <span className="material-symbols-rounded animate-spin" style={{ fontSize: '18px' }}>progress_activity</span>
                                                ) : (
                                                    <span className="material-symbols-rounded" style={{ fontSize: '18px' }}>search</span>
                                                )}
                                                {t('ai_settings.weather.search_button')}
                                            </button>
                                        </div>

                                        {weatherSearchResults.length > 0 && (
                                            <div className="grid grid-cols-1 gap-2 pt-2">
                                                {weatherSearchResults.map((location) => (
                                                    <button
                                                        type="button"
                                                        key={`${location.id || location.name}-${location.latitude}-${location.longitude}`}
                                                        onClick={() => handleWeatherSelect(location)}
                                                        className="w-full p-4 rounded-[5px] border border-palette-tan/15 bg-palette-beige/5 hover:border-palette-red/30 hover:bg-white transition-all text-left flex items-center justify-between gap-4"
                                                    >
                                                        <div>
                                                            <p className="text-sm font-black text-palette-maroon">{location.name}</p>
                                                            <p className="text-[11px] font-bold text-palette-tan/60">
                                                                {[location.admin1, location.country].filter(Boolean).join(' / ')}
                                                            </p>
                                                        </div>
                                                        <span className="text-[10px] font-black text-palette-tan/50">
                                                            {Number(location.latitude).toFixed(3)}, {Number(location.longitude).toFixed(3)}
                                                        </span>
                                                    </button>
                                                ))}
                                            </div>
                                        )}
                                    </div>

                                    <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
                                        <div className="p-4 rounded-[5px] border border-palette-tan/10 bg-palette-beige/10 md:col-span-1">
                                            <p className="text-[10px] font-black text-palette-tan/50 uppercase tracking-widest mb-2">{t('ai_settings.weather.selected_city')}</p>
                                            <p className="text-xl font-black text-palette-maroon tracking-tight">{weatherFormData.weather_location_name}</p>
                                            <p className="text-[12px] font-bold text-palette-tan/60">{weatherFormData.weather_location_country || weatherFormData.weather_timezone}</p>
                                        </div>

                                        <div className="md:col-span-2 grid grid-cols-1 sm:grid-cols-2 gap-4">
                                            <div className="space-y-1.5">
                                                <label className="text-[11px] font-black text-palette-tan tracking-widest uppercase ml-1">{t('ai_settings.weather.latitude')}</label>
                                                <input
                                                    type="number"
                                                    step="0.000001"
                                                    value={weatherFormData.weather_latitude}
                                                    onChange={(e) => setWeatherFormData({ ...weatherFormData, weather_latitude: e.target.value })}
                                                    className="w-full h-11 bg-palette-beige/10 border border-palette-tan/20 rounded-[5px] px-4 text-[13px] font-bold focus:border-palette-red focus:ring-4 focus:ring-palette-red/5 transition-all outline-none"
                                                />
                                            </div>
                                            <div className="space-y-1.5">
                                                <label className="text-[11px] font-black text-palette-tan tracking-widest uppercase ml-1">{t('ai_settings.weather.longitude')}</label>
                                                <input
                                                    type="number"
                                                    step="0.000001"
                                                    value={weatherFormData.weather_longitude}
                                                    onChange={(e) => setWeatherFormData({ ...weatherFormData, weather_longitude: e.target.value })}
                                                    className="w-full h-11 bg-palette-beige/10 border border-palette-tan/20 rounded-[5px] px-4 text-[13px] font-bold focus:border-palette-red focus:ring-4 focus:ring-palette-red/5 transition-all outline-none"
                                                />
                                            </div>
                                            <div className="space-y-1.5 sm:col-span-2">
                                                <label className="text-[11px] font-black text-palette-tan tracking-widest uppercase ml-1">{t('ai_settings.weather.timezone')}</label>
                                                <input
                                                    type="text"
                                                    value={weatherFormData.weather_timezone}
                                                    onChange={(e) => setWeatherFormData({ ...weatherFormData, weather_timezone: e.target.value })}
                                                    className="w-full h-11 bg-palette-beige/10 border border-palette-tan/20 rounded-[5px] px-4 text-[13px] font-bold focus:border-palette-red focus:ring-4 focus:ring-palette-red/5 transition-all outline-none"
                                                />
                                            </div>
                                        </div>
                                    </div>

                                    <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
                                        <div className="p-4 rounded-[5px] border border-palette-tan/10 bg-white flex items-center gap-3">
                                            <div className="w-10 h-10 rounded-[5px] bg-palette-beige/30 border border-palette-tan/10 flex items-center justify-center">
                                                <span className="material-symbols-rounded text-palette-red" style={{ fontSize: '22px' }}>schedule</span>
                                            </div>
                                            <div>
                                                <p className="text-[12px] font-black text-palette-maroon">{t('ai_settings.weather.refresh_title')}</p>
                                                <p className="text-[11px] font-bold text-palette-tan/60">{t('ai_settings.weather.refresh_desc')}</p>
                                            </div>
                                        </div>

                                        <div className="p-4 rounded-[5px] border border-palette-tan/10 bg-white flex items-center gap-3">
                                            <div className="w-10 h-10 rounded-[5px] bg-orange-50 border border-orange-100 flex items-center justify-center">
                                                <span className="material-symbols-rounded text-orange-500" style={{ fontSize: '22px' }}>thermostat</span>
                                            </div>
                                            <div>
                                                <p className="text-[12px] font-black text-palette-maroon">{t('ai_settings.weather.preview')}</p>
                                                <p className="text-[11px] font-bold text-palette-tan/60">
                                                    {weatherPreview?.current
                                                        ? `${Math.round(Number(weatherPreview.current.temperature_2m || 0))}° / ${t('right.weather_feels_like_26').replace('26', String(Math.round(Number(weatherPreview.current.apparent_temperature || 0))))}`
                                                        : t('ai_settings.weather.preview_empty')}
                                                </p>
                                            </div>
                                        </div>
                                    </div>
                                </div>
                            </div>

                            <div className="flex flex-col sm:flex-row sm:justify-end gap-3 pt-8 border-t border-palette-tan/5">
                                <button
                                    type="button"
                                    onClick={handleWeatherTest}
                                    disabled={weatherTesting || saving}
                                    className="flex items-center justify-center gap-2 px-6 h-10 bg-white border border-palette-tan/20 text-palette-maroon rounded-[5px] text-[12px] font-black tracking-widest hover:bg-palette-beige transition-all active:scale-95 uppercase disabled:opacity-50"
                                >
                                    {weatherTesting ? (
                                        <span className="material-symbols-rounded animate-spin" style={{ fontSize: '20px' }}>progress_activity</span>
                                    ) : (
                                        <span className="material-symbols-rounded" style={{ fontSize: '20px' }}>science</span>
                                    )}
                                    {t('ai_settings.weather.test_button')}
                                </button>
                                <button
                                    type="submit"
                                    disabled={saving}
                                    className="flex items-center justify-center gap-2 px-6 h-10 bg-palette-red text-white rounded-[5px] text-[13px] font-black tracking-widest hover:bg-palette-maroon transition-all shadow-lg shadow-palette-red/10 active:scale-95 uppercase disabled:opacity-50"
                                >
                                    {saving ? (
                                        <>
                                            <span className="material-symbols-rounded animate-spin" style={{ fontSize: '20px' }}>progress_activity</span>
                                            {t('common.saving')}
                                        </>
                                    ) : (
                                        <>
                                            <span className="material-symbols-rounded" style={{ fontSize: '20px' }}>save</span>
                                            {t('common.save_changes')}
                                        </>
                                    )}
                                </button>
                            </div>
                        </form>
                    ) : (
                        <div className="space-y-6">
                            <div className="bg-white rounded-[5px] border border-palette-tan/20 shadow-sm overflow-hidden text-palette-maroon">
                                <div className="p-6 border-b border-palette-tan/10 bg-palette-beige/5 flex items-center justify-between">
                                    <h3 className="text-[14px] font-black tracking-widest flex items-center gap-2 uppercase">
                                        <span className="material-symbols-rounded text-palette-red text-[20px]">description</span>
                                        {t('ai_settings.tab.formats')}
                                    </h3>
                                    <button
                                        onClick={() => {
                                            setEditingFormat(null);
                                            setFormatFormData({ title: '', prompt: '' });
                                            setShowFormatModal(true);
                                        }}
                                        className="px-4 py-2 bg-palette-red text-white rounded-[4px] text-[11px] font-black uppercase tracking-widest hover:bg-palette-maroon transition-all flex items-center gap-2 shadow-lg shadow-palette-red/10"
                                    >
                                        <span className="material-symbols-rounded" style={{ fontSize: '18px' }}>add</span>
                                        {t('ai_settings.formats.add_new')}
                                    </button>
                                </div>

                                <div className="p-6">
                                    {formatsLoading ? (
                                        <div className="flex flex-col items-center justify-center p-10 text-palette-tan/40">
                                            <span className="material-symbols-rounded animate-spin mb-2" style={{ fontSize: '32px' }}>progress_activity</span>
                                            <span className="text-[11px] font-bold tracking-widest uppercase">{t('common.loading_short')}</span>
                                        </div>
                                    ) : (
                                        <div className="space-y-4">
                                            {visibleFormats.length > 0 ? (
                                                <div className="grid grid-cols-1 gap-4">
                                                    {visibleFormats.map((format) => (
                                                        <div key={format.id} className="p-4 bg-palette-beige/5 border border-palette-tan/10 rounded-[5px] group hover:border-palette-red/30 transition-all">
                                                            <div className="flex items-start justify-between">
                                                                <div className="space-y-1">
                                                                    <div className="flex items-center gap-2">
                                                                        <h4 className="font-black text-palette-maroon text-sm tracking-tight">{format.title}</h4>
                                                                        {format.isBuiltin && (
                                                                            <span className="px-2 py-0.5 rounded-[4px] bg-palette-maroon/5 text-[9px] font-black uppercase tracking-widest text-palette-tan">
                                                                                Sistem
                                                                            </span>
                                                                        )}
                                                                    </div>
                                                                    <p className="text-[11px] text-palette-tan font-medium line-clamp-2 leading-relaxed">
                                                                        {format.prompt}
                                                                    </p>
                                                                </div>
                                                                {!format.isBuiltin && (
                                                                    <div className="flex items-center gap-2 opacity-0 group-hover:opacity-100 transition-opacity">
                                                                        <button
                                                                            onClick={() => {
                                                                                setEditingFormat(format);
                                                                                setFormatFormData({ title: format.title, prompt: format.prompt });
                                                                                setShowFormatModal(true);
                                                                            }}
                                                                            className="w-8 h-8 flex items-center justify-center rounded bg-white border border-palette-tan/20 text-palette-tan hover:text-palette-maroon hover:border-palette-maroon transition-all"
                                                                        >
                                                                            <span className="material-symbols-rounded" style={{ fontSize: '18px' }}>edit</span>
                                                                        </button>
                                                                        <button
                                                                            onClick={() => handleDeleteFormat(format.id)}
                                                                            className="w-8 h-8 flex items-center justify-center rounded bg-white border border-palette-tan/20 text-palette-tan hover:text-palette-red hover:border-palette-red transition-all"
                                                                        >
                                                                            <span className="material-symbols-rounded" style={{ fontSize: '18px' }}>delete</span>
                                                                        </button>
                                                                    </div>
                                                                )}
                                                            </div>
                                                        </div>
                                                    ))}
                                                </div>
                                            ) : (
                                                <div className="flex flex-col items-center justify-center p-10 text-palette-tan/30 border-2 border-dashed border-palette-tan/10 rounded-[5px]">
                                                    <span className="material-symbols-rounded mb-2" style={{ fontSize: '40px' }}>info</span>
                                                    <p className="text-[12px] font-bold tracking-tight">{t('ai_settings.formats.empty')}</p>
                                                </div>
                                            )}
                                        </div>
                                    )}
                                </div>
                            </div>
                        </div>
                    )}
                </div>
            </div>

            {/* Format Modal */}
            {showFormatModal && (
                <div className="fixed inset-0 z-[100] flex items-center justify-center p-4 bg-palette-maroon/20 backdrop-blur-sm animate-in fade-in duration-200">
                    <div className="w-full max-w-2xl bg-white rounded-[8px] shadow-2xl border border-palette-maroon/10 overflow-hidden text-palette-maroon">
                        <div className="p-6 border-b border-palette-tan/10 flex items-center justify-between bg-palette-beige/5">
                            <h3 className="text-[15px] font-black tracking-widest uppercase flex items-center gap-2">
                                <span className="material-symbols-rounded text-palette-red" style={{ fontSize: '22px' }}>
                                    {editingFormat ? 'edit' : 'add_circle'}
                                </span>
                                {editingFormat ? t('ai_settings.formats.edit') : t('ai_settings.formats.add_new')}
                            </h3>
                            <button onClick={() => setShowFormatModal(false)} className="text-palette-tan hover:text-palette-red transition-colors">
                                <span className="material-symbols-rounded">close</span>
                            </button>
                        </div>
                        <form onSubmit={handleSaveFormat} className="p-6 space-y-6">
                            <div className="space-y-4">
                                <div className="space-y-1.5">
                                    <label className="text-[11px] font-black text-palette-tan tracking-widest uppercase ml-1">
                                        {t('ai_settings.formats.title')}
                                    </label>
                                    <input
                                        type="text"
                                        required
                                        value={formatFormData.title}
                                        onChange={(e) => setFormatFormData({ ...formatFormData, title: e.target.value })}
                                        className="w-full h-11 bg-palette-beige/5 border border-palette-tan/20 rounded-[4px] px-4 text-sm font-bold focus:border-palette-red outline-none transition-all"
                                        placeholder="Haber Hazırla, Özet Çıkar vb..."
                                    />
                                </div>
                                <div className="space-y-1.5">
                                    <label className="text-[11px] font-black text-palette-tan tracking-widest uppercase ml-1">
                                        {t('ai_settings.formats.prompt')}
                                    </label>
                                    <textarea
                                        required
                                        value={formatFormData.prompt}
                                        onChange={(e) => setFormatFormData({ ...formatFormData, prompt: e.target.value })}
                                        className="w-full h-64 bg-palette-beige/5 border border-palette-tan/20 rounded-[4px] p-4 text-sm font-medium focus:border-palette-red outline-none transition-all resize-none leading-relaxed"
                                        placeholder="AI'ya verilecek sistem talimatları..."
                                    />
                                    <p className="text-[10px] text-palette-tan/60 font-medium leading-normal px-1">
                                        * Bu komut, AI asistanı çalıştırılırken sistem talimatı (System Prompt) olarak eklenecektir.
                                    </p>
                                </div>
                            </div>
                            <div className="flex justify-end gap-3 pt-4 border-t border-palette-tan/5">
                                <button
                                    type="button"
                                    onClick={() => setShowFormatModal(false)}
                                    className="px-6 h-10 border border-palette-tan/20 text-palette-tan rounded-[4px] text-[11px] font-black uppercase tracking-widest hover:bg-palette-beige/10 transition-all"
                                >
                                    {t('common.cancel_short')}
                                </button>
                                <button
                                    type="submit"
                                    disabled={saving}
                                    className="px-8 h-10 bg-palette-red text-white rounded-[4px] text-[11px] font-black uppercase tracking-widest hover:bg-palette-maroon transition-all shadow-lg shadow-palette-red/10 disabled:opacity-50"
                                >
                                    {saving ? t('common.saving') : t('common.save')}
                                </button>
                            </div>
                        </form>
                    </div>
                </div>
            )}
        </div>
    );
};

export default AiSettings;
