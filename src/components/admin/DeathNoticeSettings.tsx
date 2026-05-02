import React, { useEffect, useMemo, useState } from 'react';
import { useLanguage } from '@/context/LanguageContext';
import { useToast } from '@/context/ToastContext';

const DeathNoticeSettings: React.FC = () => {
    const { t } = useLanguage();
    const { showToast } = useToast();
    const [loading, setLoading] = useState(true);
    const [refreshing, setRefreshing] = useState(false);
    const [preview, setPreview] = useState<any>(null);

    const notices = useMemo(() => {
        return Array.isArray(preview?.notices) ? preview.notices : [];
    }, [preview]);

    useEffect(() => {
        fetchPreview(false);
    }, []);

    const fetchPreview = async (force: boolean) => {
        if (force) setRefreshing(true);
        if (!force) setLoading(true);
        try {
            const response = await fetch(`/api/app/death-notices?city=nigde${force ? '&refresh=1' : ''}`, {
                cache: 'no-store',
            });
            const data = await response.json();
            if (!response.ok) throw new Error(data?.error || response.statusText);
            setPreview(data);
            if (force) showToast(t('death_notice_settings.refresh_success'), 'success');
        } catch (err: any) {
            showToast(`${t('death_notice_settings.refresh_error')} (${err.message})`, 'error');
        } finally {
            setLoading(false);
            setRefreshing(false);
        }
    };

    return (
        <div className="max-w-[1500px] mx-auto p-8 animate-fade-in">
            <div className="flex flex-col lg:flex-row lg:items-center justify-between gap-6 mb-10">
                <div>
                    <h1 className="text-[34px] font-black text-palette-maroon tracking-tight leading-none mb-3">
                        {t('death_notice_settings.page_title')}
                    </h1>
                    <p className="text-sm font-bold text-palette-tan/55">
                        {t('death_notice_settings.page_desc')}
                    </p>
                </div>
                <button
                    type="button"
                    onClick={() => fetchPreview(true)}
                    disabled={refreshing}
                    className="h-11 px-5 rounded-[5px] bg-palette-red text-white text-[11px] font-black tracking-widest flex items-center gap-2 shadow-lg shadow-palette-red/15 disabled:opacity-60"
                >
                    <span className={`material-symbols-rounded ${refreshing ? 'animate-spin' : ''}`} style={{ fontSize: '18px' }}>
                        {refreshing ? 'progress_activity' : 'sync'}
                    </span>
                    {t('death_notice_settings.refresh_button')}
                </button>
            </div>

            <div className="grid grid-cols-1 xl:grid-cols-[360px_1fr] gap-8">
                <div className="space-y-4">
                    <div className="bg-white rounded-[5px] border border-palette-tan/20 shadow-sm p-6">
                        <div className="flex items-center gap-3 mb-5">
                            <div className="w-10 h-10 rounded-[5px] bg-gray-900 text-white border border-gray-900/10 flex items-center justify-center">
                                <span className="material-symbols-rounded" style={{ fontSize: '22px' }}>article</span>
                            </div>
                            <div>
                                <p className="text-[13px] font-black text-palette-maroon">{t('death_notice_settings.card_title')}</p>
                                <p className="text-[11px] font-bold text-palette-tan/55">Open cache · 30 dk</p>
                            </div>
                        </div>

                        <div className="space-y-3">
                            <div className="rounded-[5px] border border-palette-beige/70 bg-palette-beige/10 p-4">
                                <p className="text-[10px] font-black text-palette-tan/55 uppercase tracking-widest mb-1">{t('death_notice_settings.city')}</p>
                                <p className="text-xl font-black text-palette-maroon">Niğde</p>
                                <p className="text-[11px] font-bold text-palette-tan/55 mt-1">{t('death_notice_settings.locked_city')}</p>
                            </div>

                            <div className="rounded-[5px] border border-palette-beige/70 bg-white p-4">
                                <p className="text-[10px] font-black text-palette-tan/55 uppercase tracking-widest mb-1">{t('death_notice_settings.source')}</p>
                                <a href="https://nigde.bel.tr/vefat-edenler" target="_blank" rel="noreferrer" className="text-[12px] font-black text-palette-red hover:underline">
                                    nigde.bel.tr/vefat-edenler
                                </a>
                            </div>

                            <div className="rounded-[5px] border border-palette-tan/20 bg-palette-beige/10 p-4">
                                <p className="text-[12px] font-black text-palette-maroon">{t('death_notice_settings.date_guard_title')}</p>
                                <p className="text-[11px] font-bold text-palette-tan/70 leading-relaxed mt-1">{t('death_notice_settings.date_guard_desc')}</p>
                            </div>
                        </div>
                    </div>
                </div>

                <div className="bg-white rounded-[5px] border border-palette-tan/20 shadow-sm overflow-hidden">
                    <div className="p-6 border-b border-palette-beige/60 flex items-center justify-between gap-4">
                        <div>
                            <h2 className="text-[18px] font-black text-palette-maroon">{t('death_notice_settings.live_preview')}</h2>
                            <p className="text-[11px] font-bold text-palette-tan/55 mt-1">
                                {preview?.serviceDateLabel || '-'} · {preview?.meta?.total || 0} {t('death_notice_settings.notice_count')}
                            </p>
                        </div>
                        <span className="text-[10px] font-black text-palette-red bg-palette-red/5 border border-palette-red/10 px-3 py-2 rounded-[5px]">
                            {preview?.cache?.source || 'database'}
                        </span>
                    </div>

                    {loading ? (
                        <div className="h-[360px] flex items-center justify-center">
                            <span className="material-symbols-rounded animate-spin text-palette-tan" style={{ fontSize: '36px' }}>progress_activity</span>
                        </div>
                    ) : (
                        <div className="p-6">
                            {notices.length > 0 ? (
                                <div className="grid grid-cols-1 lg:grid-cols-2 gap-4">
                                    {notices.map((notice: any) => (
                                        <div key={notice.id} className="rounded-[5px] border border-palette-beige/70 p-5 bg-palette-beige/5">
                                            <div className="flex items-start justify-between gap-4 mb-3">
                                                <div className="min-w-0">
                                                    <h3 className="text-[16px] font-black text-palette-maroon truncate">{notice.name}</h3>
                                                    <p className="text-[10px] font-black text-palette-red uppercase tracking-widest mt-1">
                                                        {notice.prayerTime || '-'}{notice.burialPlace ? ` · ${notice.burialPlace}` : ''}
                                                    </p>
                                                </div>
                                                <span className="text-[11px] font-bold text-palette-tan/50 shrink-0">{notice.deathDateLabel}</span>
                                            </div>
                                            <p className="text-[12px] font-bold text-palette-tan/75 leading-relaxed line-clamp-4">{notice.description}</p>
                                        </div>
                                    ))}
                                </div>
                            ) : (
                                <div className="h-[300px] rounded-[5px] border border-dashed border-palette-beige/70 bg-palette-beige/10 flex items-center justify-center text-center p-8">
                                    <div>
                                        <div className="w-12 h-12 rounded-[5px] bg-white border border-palette-beige/70 mx-auto mb-4 flex items-center justify-center text-palette-tan">
                                            <span className="material-symbols-rounded" style={{ fontSize: '24px' }}>event_available</span>
                                        </div>
                                        <p className="text-[16px] font-black text-palette-maroon">{t('death_notice_settings.empty_title')}</p>
                                        <p className="text-[12px] font-bold text-palette-tan/60 mt-2">{t('death_notice_settings.empty_desc')}</p>
                                    </div>
                                </div>
                            )}
                        </div>
                    )}
                </div>
            </div>
        </div>
    );
};

export default DeathNoticeSettings;
