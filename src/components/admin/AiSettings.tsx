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

    useEffect(() => {
        fetchLanguages();
    }, []);

    useEffect(() => {
        fetchSettings();
    }, [settingsLanguage]);

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

    const handleSave = async (e: React.FormEvent) => {
        e.preventDefault();
        setSaving(true);

        try {
            const updateData = {
                google_ai_api_key: formData.google_ai_apiKey,
                google_ai_model: formData.google_ai_model,
                google_ai_active: formData.google_ai_active,
                updated_at: new Promise(resolve => resolve(new Date().toISOString()))
            };

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

    const tabs = [
        { id: 'google', label: t('ai_settings.tab.google') },
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
                                            {tab.id === 'google' ? 'psychology' : 'settings'}
                                        </span>
                                        <span className="font-bold text-sm">{tab.label}</span>
                                    </div>
                                    {activeTab === tab.id && <span className="material-symbols-rounded" style={{ fontSize: '16px' }}>check_circle</span>}
                                </div>
                            </button>
                        ))}
                    </nav>
                </div>

                {/* Form Content */}
                <div className="lg:col-span-3">
                    <form onSubmit={handleSave} className="space-y-6">
                        <div className="bg-white rounded-[5px] border border-palette-tan/20 shadow-sm overflow-hidden">
                            <div className="p-6 border-b border-palette-tan/10 bg-palette-beige/5">
                                <h3 className="text-[14px] font-black text-palette-maroon tracking-widest flex items-center gap-2 uppercase">
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
                                            <p className="text-[13px] font-bold text-palette-maroon">{t('ai_settings.google_ai_active')}</p>
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
                                        <div className="relative group">
                                            <span className="absolute left-4 top-1/2 -translate-y-1/2 material-symbols-rounded text-palette-tan/50 group-focus-within:text-palette-red transition-colors" style={{ fontSize: '20px' }}>key</span>
                                            <input
                                                type="password"
                                                value={formData.google_ai_apiKey}
                                                onChange={(e) => setFormData({ ...formData, google_ai_apiKey: e.target.value })}
                                                className="w-full h-12 bg-palette-beige/10 border border-palette-tan/20 rounded-[5px] pl-12 pr-4 text-[13px] font-bold text-palette-maroon focus:border-palette-red focus:ring-4 focus:ring-palette-red/5 transition-all"
                                                placeholder="Google AI API Key..."
                                            />
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
                                                className="w-full h-12 bg-palette-beige/10 border border-palette-tan/20 rounded-[5px] pl-12 pr-4 text-[13px] font-bold text-palette-maroon focus:border-palette-red focus:ring-4 focus:ring-palette-red/5 transition-all appearance-none cursor-pointer"
                                            >
                                                <option value="gemini-3.0-flash">Gemini 3.0 Flash</option>
                                                <option value="gemini-3.0-pro">Gemini 3.0 Pro</option>
                                                <option value="gemini-3.0-deepthink">Gemini 3.0 Deep Think</option>
                                                <option value="gemini-2.5-pro">Gemini 2.5 Pro</option>
                                                <option value="gemini-2.5-flash">Gemini 2.5 Flash</option>
                                                <option value="gemini-2.0-pro-exp">Gemini 2.0 Pro (Exp)</option>
                                                <option value="gemini-2.0-flash">Gemini 2.0 Flash</option>
                                                <option value="gemini-1.5-pro">Gemini 1.5 Pro</option>
                                                <option value="gemini-1.5-flash">Gemini 1.5 Flash</option>
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
                </div>
            </div>
        </div>
    );
};

export default AiSettings;
