import React, { useEffect, useState } from 'react';
import { neon } from '@/lib/neon';
import { useLanguage } from '@/context/LanguageContext';
import { useToast } from '@/context/ToastContext';

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

const WeatherSettings: React.FC = () => {
    const { t, currentLang } = useLanguage();
    const { showToast } = useToast();
    const [loading, setLoading] = useState(true);
    const [saving, setSaving] = useState(false);
    const [languages, setLanguages] = useState<{ code: string; name: string }[]>([]);
    const [settingsLanguage, setSettingsLanguage] = useState(() => String(currentLang?.code || 'tr'));
    const [weatherFormData, setWeatherFormData] = useState(DEFAULT_WEATHER_FORM);
    const [weatherSearchTerm, setWeatherSearchTerm] = useState('Niğde');
    const [weatherSearchResults, setWeatherSearchResults] = useState<WeatherLocationResult[]>([]);
    const [weatherSearching, setWeatherSearching] = useState(false);
    const [weatherPreview, setWeatherPreview] = useState<any>(null);
    const [weatherTesting, setWeatherTesting] = useState(false);

    useEffect(() => {
        fetchLanguages();
    }, []);

    useEffect(() => {
        fetchSettings();
    }, [settingsLanguage]);

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

    const fetchSettings = async () => {
        setLoading(true);
        try {
            const { data, error } = await neon
                .from('site_settings')
                .select('weather_enabled, weather_location_name, weather_location_country, weather_latitude, weather_longitude, weather_timezone, weather_update_interval_minutes')
                .eq('language_code', settingsLanguage)
                .maybeSingle();

            if (error) throw error;

            const nextWeather = {
                weather_enabled: data?.weather_enabled !== false,
                weather_location_name: data?.weather_location_name || DEFAULT_WEATHER_FORM.weather_location_name,
                weather_location_country: data?.weather_location_country || DEFAULT_WEATHER_FORM.weather_location_country,
                weather_latitude: String(data?.weather_latitude ?? DEFAULT_WEATHER_FORM.weather_latitude),
                weather_longitude: String(data?.weather_longitude ?? DEFAULT_WEATHER_FORM.weather_longitude),
                weather_timezone: data?.weather_timezone || DEFAULT_WEATHER_FORM.weather_timezone,
                weather_update_interval_minutes: 30
            };

            setWeatherFormData(nextWeather);
            setWeatherSearchTerm(nextWeather.weather_location_name);
            setWeatherPreview(null);
            setWeatherSearchResults([]);
        } catch (err: any) {
            console.error('Error fetching weather settings:', err);
            showToast(t('ai_settings.weather.search_error'), 'error');
        } finally {
            setLoading(false);
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

    const warmSidebarCache = async () => {
        const cacheKey = `sidebar:${settingsLanguage}`;
        try {
            await neon.from('app_cache').delete().eq('key', cacheKey);
        } catch {
            // Cache table is maintained by the server schema guard.
        }

        try {
            await fetch(`/api/app/sidebar?lang=${encodeURIComponent(settingsLanguage)}`, { cache: 'no-store' });
        } catch {
            // The next page request will rebuild the cache if this warm-up fails.
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
            await warmSidebarCache();
            showToast(t('ai_settings.weather.save_success'), 'success');
        } catch (err: any) {
            console.error('Error saving weather settings:', err);
            showToast(`${t('ai_settings.weather.save_error')} (${err.message})`, 'error');
        } finally {
            setSaving(false);
        }
    };

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
                        {t('weather_settings.page_title')}
                    </h2>
                    <p className="text-[12px] font-bold text-palette-tan/50 tracking-wider">
                        {t('weather_settings.page_desc')}
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

            <form onSubmit={handleSaveWeather} className="space-y-6">
                <div className="bg-white rounded-[5px] border border-palette-tan/20 shadow-sm overflow-hidden text-palette-maroon">
                    <div className="p-6 border-b border-palette-tan/10 bg-palette-beige/5 flex items-center justify-between gap-4">
                        <h3 className="text-[14px] font-black tracking-widest flex items-center gap-2 uppercase">
                            <span className="material-symbols-rounded text-palette-red text-[20px]">partly_cloudy_day</span>
                            {t('weather_settings.card_title')}
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
        </div>
    );
};

export default WeatherSettings;
