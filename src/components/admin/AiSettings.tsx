import React, { useState, useEffect } from 'react';
import { supabase } from '@/lib/supabase';
import { useLanguage } from '@/context/LanguageContext';
import { useSupabaseSession } from '@/hooks/useSupabaseSession';
import { useToast } from '@/context/ToastContext';

const AiSettings: React.FC = () => {
    const { t } = useLanguage();
    const { user } = useSupabaseSession();
    const { showToast } = useToast();
    const [loading, setLoading] = useState(true);
    const [saving, setSaving] = useState(false);
    const [activeTab, setActiveTab] = useState('google');
    const [languages, setLanguages] = useState<{ code: string; name: string }[]>([]);
    const [settingsLanguage, setSettingsLanguage] = useState('tr');

    const [formData, setFormData] = useState({
        google_ai_apiKey: '',
        google_ai_model: 'gemini-1.5-flash',
        google_ai_active: false
    });

    const [formats, setFormats] = useState<any[]>([]);
    const [formatsLoading, setFormatsLoading] = useState(false);
    const [showFormatModal, setShowFormatModal] = useState(false);
    const [editingFormat, setEditingFormat] = useState<any>(null);
    const [formatFormData, setFormatFormData] = useState({ title: '', prompt: '' });
    const [isTesting, setIsTesting] = useState(false);
    const [fetchedModels, setFetchedModels] = useState<string[]>([]);

    useEffect(() => {
        fetchLanguages();
    }, []);

    useEffect(() => {
        fetchSettings();
        if (activeTab === 'formats') {
            fetchFormats();
        }
    }, [settingsLanguage, activeTab]);

    const fetchLanguages = async () => {
        try {
            const { data, error } = await supabase
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
            const { data, error } = await supabase
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
            const { data, error } = await supabase
                .from('site_settings')
                .select('google_ai_api_key, google_ai_model, google_ai_active')
                .eq('language_code', settingsLanguage)
                .maybeSingle();

            if (error) throw error;

            if (data) {
                setFormData({
                    google_ai_apiKey: data.google_ai_api_key || '',
                    google_ai_model: data.google_ai_model || 'gemini-1.5-flash',
                    google_ai_active: data.google_ai_active || false
                });
            } else {
                setFormData({
                    google_ai_apiKey: '',
                    google_ai_model: 'gemini-1.5-flash',
                    google_ai_active: false
                });
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
            const response = await fetch(`https://generativelanguage.googleapis.com/v1beta/models?key=${formData.google_ai_apiKey}`);
            const data = await response.json();

            if (data.error) {
                throw new Error(data.error.message);
            }

            if (data.models) {
                // Filter models that support generateContent and start with models/
                const models = data.models
                    .filter((m: any) => m.supportedGenerationMethods.includes('generateContent'))
                    .map((m: any) => m.name.replace('models/', ''));

                setFetchedModels(models);
                if (models.length > 0) {
                    showToast(t('ai_settings.test_success'), 'success');
                } else {
                    showToast(t('ai_settings.no_models'), 'warning');
                }
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
            const { error } = await supabase
                .from('site_settings')
                .update({
                    google_ai_api_key: formData.google_ai_apiKey,
                    google_ai_model: formData.google_ai_model,
                    google_ai_active: formData.google_ai_active,
                    updated_at: new Date().toISOString()
                })
                .eq('language_code', settingsLanguage);

            if (error) throw error;
            showToast(t('ai_settings.save_success'), 'success');
        } catch (err) {
            console.error('Error saving AI settings:', err);
            showToast(t('ai_settings.save_error'), 'error');
        } finally {
            setSaving(false);
        }
    };

    const handleSaveFormat = async (e: React.FormEvent) => {
        e.preventDefault();
        setSaving(true);
        try {
            if (editingFormat) {
                const { error } = await supabase
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
                const { error } = await supabase
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
            const { error } = await supabase
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
                                                    {fetchedModels.length > 0 ? (
                                                        fetchedModels.map(model => (
                                                            <option key={model} value={model}>{model}</option>
                                                        ))
                                                    ) : (
                                                        <>
                                                            <option value="gemini-2.0-flash">Gemini 2.0 Flash</option>
                                                            <option value="gemini-1.5-pro">Gemini 1.5 Pro</option>
                                                            <option value="gemini-1.5-flash">Gemini 1.5 Flash</option>
                                                        </>
                                                    )}
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
                                            {formats.length > 0 ? (
                                                <div className="grid grid-cols-1 gap-4">
                                                    {formats.map((format) => (
                                                        <div key={format.id} className="p-4 bg-palette-beige/5 border border-palette-tan/10 rounded-[5px] group hover:border-palette-red/30 transition-all">
                                                            <div className="flex items-start justify-between">
                                                                <div className="space-y-1">
                                                                    <h4 className="font-black text-palette-maroon text-sm tracking-tight">{format.title}</h4>
                                                                    <p className="text-[11px] text-palette-tan font-medium line-clamp-2 leading-relaxed">
                                                                        {format.prompt}
                                                                    </p>
                                                                </div>
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
