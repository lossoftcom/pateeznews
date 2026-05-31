
import React, { useState, useEffect, useMemo } from 'react';
import { supabase } from '@/lib/supabase';
import { useLanguage } from '@/context/LanguageContext';
import {
    ArrowLeft, Search, Flame, Eye, Heart, Share2, TrendingUp, Zap
} from 'lucide-react';

interface Trend {
    id: string;
    label: string;
    value: string;
    icon: string;
    color: string;
    bg: string;
    description: string;
    count: number;
    likes: number;
    comments: number;
    shares: number;
    views: number;
    trendingScore: number;
}

const TREND_STYLES = [
    { color: 'text-palette-red', bg: 'bg-palette-red/5', border: 'border-palette-red/10' },
    { color: 'text-palette-accent', bg: 'bg-palette-accent/10', border: 'border-palette-accent/15' },
    { color: 'text-palette-maroon', bg: 'bg-palette-maroon/5', border: 'border-palette-maroon/10' },
    { color: 'text-palette-tan', bg: 'bg-palette-tan/10', border: 'border-palette-tan/15' },
];

interface TrendsListProps {
    onBack: () => void;
    onTrendSelect: (value: string) => void;
}

const TrendsList: React.FC<TrendsListProps> = ({ onBack, onTrendSelect }) => {
    const { currentLang, t } = useLanguage();
    const [trends, setTrends] = useState<Trend[]>([]);
    const [loading, setLoading] = useState(true);
    const [searchTerm, setSearchTerm] = useState('');
    const [currentPage, setCurrentPage] = useState(1);
    const pageSize = 12;

    useEffect(() => {
        const fetchLiveData = async () => {
            try {
                setLoading(true);
                // 1. Fetch Trends from Nav Items
                const { data: navData, error: navError } = await supabase
                    .from('navigation_items')
                    .select('*')
                    .eq('type', 'trends')
                    .eq('is_active', true)
                    .eq('language_code', currentLang.code)
                    .order('order_index');

                if (navError) throw navError;

                // 2. Fetch Post Metrics
                const { data: postMetrics, error: metricsError } = await supabase
                    .from('posts')
                    .select('category, likes_count, comments_count, shares_count')
                    .eq('status', 'published')
                    .eq('language_code', currentLang.code);

                if (metricsError) throw metricsError;

                const stats: Record<string, any> = {};
                postMetrics?.forEach((p: any) => {
                    if (!p.category) return;
                    if (!stats[p.category]) stats[p.category] = { count: 0, likes: 0, comments: 0, shares: 0, views: 0 };
                    stats[p.category].count += 1;
                    stats[p.category].likes += (p.likes_count || 0);
                    stats[p.category].comments += (p.comments_count || 0);
                    stats[p.category].shares += (p.shares_count || 0);
                    stats[p.category].views += (p.likes_count || 0);
                });

                if (navData) {
                    const mapped = navData.map((item: any, idx: number) => {
                        const style = TREND_STYLES[idx % TREND_STYLES.length];
                        const val = item.value || item.label;
                        const s = stats[val] || stats[item.label] || { count: 0, likes: 0, comments: 0, shares: 0, views: 0 };
                        return {
                            id: item.id,
                            label: item.label,
                            value: val,
                            icon: item.icon || 'flame',
                            ...style,
                            description:
                                t(`${item.label}.description`) !== `${item.label}.description` ? t(`${item.label}.description`) :
                                    t(`trend.${val.toLowerCase()}.description`) !== `trend.${val.toLowerCase()}.description` ? t(`trend.${val.toLowerCase()}.description`) :
                                        t('trends.description_fallback').replace('{trend}', t(item.label)),
                            count: s.count,
                            likes: s.likes,
                            comments: s.comments,
                            shares: s.shares,
                            views: s.views,
                            trendingScore: s.likes + (s.comments * 2) + s.shares
                        };
                    });
                    setTrends(mapped);
                }
            } catch (err) {
                console.error('Error:', err);
            } finally {
                setLoading(false);
            }
        };
        fetchLiveData();
    }, [currentLang.code, t]);

    const filteredTrends = useMemo(() => {
        return trends.filter(trend =>
            t(trend.label).toLowerCase().includes(searchTerm.toLowerCase())
        );
    }, [trends, searchTerm, t]);

    const paginatedTrends = useMemo(() => {
        const start = (currentPage - 1) * pageSize;
        return filteredTrends.slice(start, start + pageSize);
    }, [filteredTrends, currentPage]);

    const totalPages = Math.ceil(filteredTrends.length / pageSize);

    const popularTrend = useMemo(() => {
        if (trends.length === 0) return null;
        return [...trends].sort((a, b) => b.trendingScore - a.trendingScore)[0];
    }, [trends]);

    const formatNumber = (num: number) => {
        if (num >= 1000) return (num / 1000).toFixed(1) + 'K';
        return num.toString();
    };

    return (
        <div className="bg-white rounded-[5px] border border-gray-200 overflow-hidden mb-10 min-h-screen flex flex-col">

            {/* 🚀 MINIMAL HEADER */}
            <div className="p-6 md:p-8 border-b border-gray-100 bg-gray-50/30">
                <div className="flex flex-col md:flex-row md:items-center justify-between gap-4 mb-8">
                    <button
                        onClick={onBack}
                        className="flex items-center gap-2 text-gray-500 hover:text-palette-red font-bold text-[11px] uppercase tracking-widest transition-all"
                    >
                        <ArrowLeft size={16} />
                        <span>{t('admin.post.go_back')}</span>
                    </button>

                    <div className="relative w-full md:max-w-xs">
                        <Search size={16} className="absolute left-3 top-1/2 -translate-y-1/2 text-gray-400" />
                        <input
                            type="text"
                            placeholder={t('trends.search_placeholder')}
                            value={searchTerm}
                            onChange={(e) => { setSearchTerm(e.target.value); setCurrentPage(1); }}
                            className="w-full h-10 pl-10 pr-4 bg-white border border-gray-200 rounded-[5px] text-sm font-medium focus:border-palette-red outline-none transition-all"
                        />
                    </div>
                </div>

                <div className="flex items-center gap-2 text-palette-red text-[10px] font-black uppercase tracking-[0.2em] mb-2">
                    <Flame size={14} />
                    {t('trends.hero_tag')}
                </div>
                <h1 className="text-3xl font-black text-gray-900 tracking-tight">{t('trends.hero_title')}</h1>
            </div>

            {/* 📦 COMPACT TREND LIST/GRID */}
            <div className="p-6 md:p-8 flex-1">
                {loading ? (
                    <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
                        {Array(6).fill(0).map((_, i) => (
                            <div key={i} className="h-40 bg-gray-50 animate-pulse rounded-[5px] border border-gray-100" />
                        ))}
                    </div>
                ) : filteredTrends.length === 0 ? (
                    <div className="py-20 text-center text-gray-400 font-bold uppercase tracking-widest text-xs">{t('common.no_results_found')}</div>
                ) : (
                    <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
                        {paginatedTrends.map((trend) => (
                            <button
                                key={trend.id}
                                onClick={() => onTrendSelect(trend.value)}
                                className="group flex flex-col p-5 rounded-[5px] border border-gray-100 bg-white hover:border-palette-red/30 hover:shadow-lg transition-all text-left"
                            >
                                <div className="flex items-start gap-4 mb-4">
                                    <div className={`w-12 h-12 ${trend.bg} ${trend.color} rounded-[5px] flex items-center justify-center shrink-0`}>
                                        <span className="material-symbols-rounded" style={{ fontSize: '24px' }}>{trend.icon.toLowerCase()}</span>
                                    </div>
                                    <div>
                                        <h3 className="text-lg font-black text-gray-900 group-hover:text-palette-red transition-colors leading-tight">{t(trend.label)}</h3>
                                        <p className="text-[11px] text-gray-400 font-bold mt-1 uppercase tracking-wider">{trend.count} {t('common.news_upper')}</p>
                                    </div>
                                </div>

                                <p className="text-sm text-gray-500 font-medium line-clamp-2 mb-4 h-10">
                                    {trend.description}
                                </p>

                                {/* 📊 MINIMAL METRICS - VERTICAL STACKED (Alt Alta) */}
                                <div className="grid grid-cols-4 gap-2 pt-4 border-t border-gray-50">
                                    <div className="flex flex-col items-center">
                                        <span className="text-[9px] font-black text-gray-400 uppercase tracking-tighter">{t('metrics.views')}</span>
                                        <span className="text-xs font-black text-gray-700">{formatNumber(trend.views)}</span>
                                    </div>
                                    <div className="flex flex-col items-center border-l border-gray-50">
                                        <span className="text-[9px] font-black text-gray-400 uppercase tracking-tighter">{t('metrics.likes')}</span>
                                        <span className="text-xs font-black text-gray-700">{formatNumber(trend.likes)}</span>
                                    </div>
                                    <div className="flex flex-col items-center border-l border-gray-50">
                                        <span className="text-[9px] font-black text-gray-400 uppercase tracking-tighter">{t('metrics.comments')}</span>
                                        <span className="text-xs font-black text-gray-700">{formatNumber(trend.comments)}</span>
                                    </div>
                                    <div className="flex flex-col items-center border-l border-gray-50">
                                        <span className="text-[9px] font-black text-gray-400 uppercase tracking-tighter">{t('metrics.shares')}</span>
                                        <span className="text-xs font-black text-gray-700">{formatNumber(trend.shares)}</span>
                                    </div>
                                </div>
                            </button>
                        ))}
                    </div>
                )}
            </div>

            {/* 📄 MINIMAL PAGINATION */}
            {totalPages > 1 && !loading && (
                <div className="p-6 border-t border-gray-100 flex items-center justify-between">
                    <span className="text-[10px] font-bold text-gray-400 uppercase tracking-widest">
                        {filteredTrends.length} {t('common.trend_topic_upper')}
                    </span>
                    <div className="flex items-center gap-2">
                        <button
                            onClick={() => { setCurrentPage(p => Math.max(1, p - 1)); window.scrollTo(0, 0); }}
                            disabled={currentPage === 1}
                            className="w-8 h-8 flex items-center justify-center rounded-[5px] border border-gray-200 text-gray-400 hover:text-palette-red disabled:opacity-30"
                        >
                            <ArrowLeft size={16} />
                        </button>
                        <span className="text-xs font-black text-gray-900 mx-2">{currentPage} / {totalPages}</span>
                        <button
                            onClick={() => { setCurrentPage(p => Math.min(totalPages, p + 1)); window.scrollTo(0, 0); }}
                            disabled={currentPage === totalPages}
                            className="w-8 h-8 flex items-center justify-center rounded-[5px] border border-gray-200 text-gray-400 hover:text-palette-red disabled:opacity-30 rotate-180"
                        >
                            <ArrowLeft size={16} />
                        </button>
                    </div>
                </div>
            )}

            {/* 🌟 INTEGRATED SMALL BANNER (Haftanın Yıldızı) */}
            {!loading && popularTrend && currentPage === 1 && (
                <div className="m-6 md:m-8 p-8 bg-gray-900 rounded-[5px] relative overflow-hidden group">
                    <div className="absolute top-0 right-0 w-40 h-40 bg-palette-red rounded-full blur-[80px] opacity-20" />

                    <div className="relative z-10 flex flex-col md:flex-row items-center justify-between gap-6">
                        <div className="flex-1">
                            <div className="flex items-center gap-2 text-palette-red text-[10px] font-black uppercase tracking-[0.2em] mb-2">
                                <TrendingUp size={14} />
                                {t('common.week_star')}
                            </div>
                            <h2 className="text-2xl font-black text-white tracking-tight mb-2">
                                {t(popularTrend.label)} <span className="text-gray-400 font-normal">| {t('trends.banner.cta')}</span>
                            </h2>
                            <p className="text-gray-400 text-sm font-medium">
                                {t('trends.banner.description').replace('{count}', formatNumber(popularTrend.views))}
                            </p>
                        </div>
                        <button
                            onClick={() => onTrendSelect(popularTrend.value)}
                            className="shrink-0 px-8 py-3 bg-white text-gray-900 rounded-[5px] font-black text-xs h-fit hover:bg-palette-red hover:text-white transition-all shadow-xl"
                        >
                            {t('common.discover_now')}
                        </button>
                    </div>
                </div>
            )}
        </div>
    );
};

export default TrendsList;
