import React, { useEffect, useMemo, useState } from 'react';
import { useLanguage } from '@/context/LanguageContext';
import { useToast } from '@/context/ToastContext';

const DutyPharmacySettings: React.FC = () => {
    const { t } = useLanguage();
    const { showToast } = useToast();
    const [loading, setLoading] = useState(true);
    const [refreshing, setRefreshing] = useState(false);
    const [preview, setPreview] = useState<any>(null);
    const [activeDistrict, setActiveDistrict] = useState('MERKEZ');

    const districts = useMemo(() => {
        const values = Array.isArray(preview?.districts) ? preview.districts : [];
        return values.length ? values : ['MERKEZ'];
    }, [preview]);

    const pharmacies = Array.isArray(preview?.pharmacies) ? preview.pharmacies : [];
    const selectedPharmacies = pharmacies.filter((pharmacy: any) => pharmacy.district === activeDistrict);

    useEffect(() => {
        fetchPreview(false);
    }, []);

    useEffect(() => {
        if (!districts.includes(activeDistrict)) {
            setActiveDistrict(districts.includes('MERKEZ') ? 'MERKEZ' : districts[0]);
        }
    }, [activeDistrict, districts]);

    const fetchPreview = async (force: boolean) => {
        if (force) setRefreshing(true);
        if (!force) setLoading(true);
        try {
            const response = await fetch(`/api/app/duty-pharmacies?city=nigde${force ? '&refresh=1' : ''}`, {
                cache: 'no-store',
            });
            const data = await response.json();
            if (!response.ok) throw new Error(data?.error || response.statusText);
            setPreview(data);
            if (force) showToast(t('duty_pharmacy_settings.refresh_success'), 'success');
        } catch (err: any) {
            showToast(`${t('duty_pharmacy_settings.refresh_error')} (${err.message})`, 'error');
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
                        {t('duty_pharmacy_settings.page_title')}
                    </h1>
                    <p className="text-sm font-bold text-palette-tan/55">
                        {t('duty_pharmacy_settings.page_desc')}
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
                    {t('duty_pharmacy_settings.refresh_button')}
                </button>
            </div>

            <div className="grid grid-cols-1 xl:grid-cols-[360px_1fr] gap-8">
                <div className="space-y-4">
                    <div className="bg-white rounded-[5px] border border-palette-tan/20 shadow-sm p-6">
                        <div className="flex items-center gap-3 mb-5">
                            <div className="w-10 h-10 rounded-[5px] bg-emerald-50 text-emerald-600 border border-emerald-500/10 flex items-center justify-center">
                                <span className="material-symbols-rounded" style={{ fontSize: '22px' }}>local_pharmacy</span>
                            </div>
                            <div>
                                <p className="text-[13px] font-black text-palette-maroon">{t('duty_pharmacy_settings.card_title')}</p>
                                <p className="text-[11px] font-bold text-palette-tan/55">Open cache · 15 dk</p>
                            </div>
                        </div>

                        <div className="space-y-3">
                            <div className="rounded-[5px] border border-palette-beige/70 bg-palette-beige/10 p-4">
                                <p className="text-[10px] font-black text-palette-tan/55 uppercase tracking-widest mb-1">{t('duty_pharmacy_settings.city')}</p>
                                <p className="text-xl font-black text-palette-maroon">Niğde</p>
                                <p className="text-[11px] font-bold text-palette-tan/55 mt-1">{t('duty_pharmacy_settings.locked_city')}</p>
                            </div>

                            <div className="rounded-[5px] border border-palette-beige/70 bg-white p-4">
                                <p className="text-[10px] font-black text-palette-tan/55 uppercase tracking-widest mb-1">{t('duty_pharmacy_settings.source')}</p>
                                <a href="https://www.neo.org.tr/nobetci-eczaneler" target="_blank" rel="noreferrer" className="text-[12px] font-black text-palette-red hover:underline">
                                    neo.org.tr/nobetci-eczaneler
                                </a>
                            </div>

                            <div className="rounded-[5px] border border-amber-200 bg-amber-50 p-4">
                                <p className="text-[12px] font-black text-amber-800">{t('duty_pharmacy_settings.midnight_guard_title')}</p>
                                <p className="text-[11px] font-bold text-amber-700/70 leading-relaxed mt-1">{t('duty_pharmacy_settings.midnight_guard_desc')}</p>
                            </div>
                        </div>
                    </div>
                </div>

                <div className="bg-white rounded-[5px] border border-palette-tan/20 shadow-sm overflow-hidden">
                    <div className="p-6 border-b border-palette-beige/60 flex items-center justify-between gap-4">
                        <div>
                            <h2 className="text-[18px] font-black text-palette-maroon">{t('duty_pharmacy_settings.live_preview')}</h2>
                            <p className="text-[11px] font-bold text-palette-tan/55 mt-1">
                                {preview?.serviceDateLabel || '-'} · {preview?.meta?.total || 0} eczane
                            </p>
                        </div>
                        <span className="text-[10px] font-black text-emerald-600 bg-emerald-50 border border-emerald-500/10 px-3 py-2 rounded-[5px]">
                            {preview?.cache?.source || 'database'}
                        </span>
                    </div>

                    {loading ? (
                        <div className="h-[360px] flex items-center justify-center">
                            <span className="material-symbols-rounded animate-spin text-palette-tan" style={{ fontSize: '36px' }}>progress_activity</span>
                        </div>
                    ) : (
                        <div className="p-6">
                            <div className="flex flex-wrap gap-2 mb-6">
                                {districts.map((district: string) => (
                                    <button
                                        key={district}
                                        type="button"
                                        onClick={() => setActiveDistrict(district)}
                                        className={`h-9 px-4 rounded-[5px] text-[11px] font-black border transition-all ${district === activeDistrict
                                            ? 'bg-palette-maroon text-white border-palette-maroon'
                                            : 'bg-palette-beige/10 text-palette-tan border-palette-beige/70 hover:bg-white'
                                            }`}
                                    >
                                        {district}
                                    </button>
                                ))}
                            </div>

                            <div className="grid grid-cols-1 lg:grid-cols-2 gap-4">
                                {selectedPharmacies.map((pharmacy: any) => (
                                    <div key={pharmacy.id} className="rounded-[5px] border border-palette-beige/70 p-5 bg-palette-beige/5">
                                        <div className="flex items-start justify-between gap-4 mb-3">
                                            <div>
                                                <h3 className="text-[16px] font-black text-palette-maroon">{pharmacy.name}</h3>
                                                <p className="text-[10px] font-black text-emerald-600 uppercase tracking-widest mt-1">{pharmacy.district}</p>
                                            </div>
                                            <span className="material-symbols-rounded text-palette-red/80" style={{ fontSize: '22px' }}>local_pharmacy</span>
                                        </div>
                                        {pharmacy.note && (
                                            <p className="mb-3 rounded-[5px] bg-palette-red/5 border border-palette-red/10 px-3 py-2 text-[11px] font-black text-palette-red">{pharmacy.note}</p>
                                        )}
                                        <p className="text-[12px] font-bold text-palette-tan/70 leading-relaxed mb-4">{pharmacy.address}</p>
                                        <div className="flex flex-wrap gap-2">
                                            <a href={`tel:${pharmacy.phoneHref}`} className="h-9 px-4 rounded-[5px] border border-palette-beige/70 bg-white text-[11px] font-black text-palette-maroon flex items-center gap-2">
                                                <span className="material-symbols-rounded" style={{ fontSize: '16px' }}>call</span>
                                                {pharmacy.phone}
                                            </a>
                                            <a href={pharmacy.directionUrl} target="_blank" rel="noreferrer" className="h-9 px-4 rounded-[5px] bg-palette-red text-white text-[11px] font-black flex items-center gap-2">
                                                <span className="material-symbols-rounded" style={{ fontSize: '16px' }}>navigation</span>
                                                {t('right.pharmacy_route')}
                                            </a>
                                        </div>
                                    </div>
                                ))}
                            </div>
                        </div>
                    )}
                </div>
            </div>
        </div>
    );
};

export default DutyPharmacySettings;
