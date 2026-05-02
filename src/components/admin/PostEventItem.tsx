import React, { useMemo, useState } from 'react';
import ReactQuill from 'react-quill-new';
import {
    QUILL_FORMATS,
    QUILL_MODULES,
    type EventData,
    type EventHighlightItem,
    type EventRegistrationType,
    type EventScheduleItem,
    type EventSpeakerItem,
    type PostItem,
} from './PostTextItem';
import { useLanguage } from '@/context/LanguageContext';
import MediaFilenameBadge from './MediaFilenameBadge';

interface PostEventItemProps {
    item: PostItem;
    index: number;
    totalItems: number;
    showBlockNumbers: boolean;
    displayMode?: 'all' | 'settings' | 'sections';
    onUpdate: (id: string, field: keyof PostItem, value: any) => void;
    onRemove: (id: string) => void;
    isDeletable?: boolean;
    onMoveUp?: (index: number) => void;
    onMoveDown?: (index: number) => void;
    onOpenFileManager: (id: string, subField?: string, optionId?: string) => void;
    onOpenUrlMode: (id: string, subField?: string, optionId?: string) => void;
    onOpenImageEditor: (id: string, subField?: string, optionId?: string) => void;
    onRenameMedia?: (src: string, type: 'image') => Promise<string | null>;
}

const makeId = () => Math.random().toString(36).slice(2, 11);

const makeScheduleItem = (orderNumber: number): EventScheduleItem => ({
    id: makeId(),
    orderNumber,
    date: '',
    time: '',
    title: '',
    description: '',
    image: '',
    imageDescription: '',
});

const makeHighlightItem = (): EventHighlightItem => ({
    id: makeId(),
    label: '',
    value: '',
});

const makeSpeakerItem = (): EventSpeakerItem => ({
    id: makeId(),
    name: '',
    role: '',
    image: '',
    imageDescription: '',
    bio: '',
});

export const createDefaultEventData = (): EventData => ({
    startDateTime: '',
    endDateTime: '',
    organizer: '',
    venueName: '',
    address: '',
    latitude: '',
    longitude: '',
    registrationType: 'none',
    ticketUrl: '',
    ticketPrice: '',
    capacity: '',
    scheduleTitle: '',
    highlightsTitle: '',
    speakersTitle: '',
    schedule: [makeScheduleItem(1)],
    highlights: [makeHighlightItem()],
    speakers: [makeSpeakerItem()],
});

const normalizeEventData = (value: PostItem['eventData']): EventData => {
    const base = createDefaultEventData();
    const schedule = Array.isArray(value?.schedule) && value.schedule.length > 0
        ? value.schedule.map((entry, entryIndex) => ({
            id: entry.id || makeId(),
            orderNumber: Number(entry.orderNumber) || entryIndex + 1,
            date: entry.date || '',
            time: entry.time || '',
            title: entry.title || '',
            description: entry.description || '',
            image: entry.image || '',
            imageDescription: entry.imageDescription || '',
        }))
        : base.schedule;
    const highlights = Array.isArray(value?.highlights) && value.highlights.length > 0
        ? value.highlights.map((entry) => ({
            id: entry.id || makeId(),
            label: entry.label || '',
            value: entry.value || '',
        }))
        : base.highlights;
    const speakers = Array.isArray(value?.speakers) && value.speakers.length > 0
        ? value.speakers.map((entry) => ({
            id: entry.id || makeId(),
            name: entry.name || '',
            role: entry.role || '',
            image: entry.image || '',
            imageDescription: entry.imageDescription || '',
            bio: entry.bio || '',
        }))
        : base.speakers;

    return {
        ...base,
        ...value,
        registrationType: (value?.registrationType || base.registrationType) as EventRegistrationType,
        schedule,
        highlights,
        speakers,
    };
};

const PostEventItem: React.FC<PostEventItemProps> = ({
    item,
    displayMode = 'all',
    onUpdate,
    onOpenFileManager,
    onOpenUrlMode,
    onOpenImageEditor,
    onRenameMedia,
}) => {
    const { t } = useLanguage();
    const [collapsedSpeakers, setCollapsedSpeakers] = useState<Set<string>>(new Set());
    const eventData = useMemo(() => normalizeEventData(item.eventData), [item.eventData]);
    const showSettingsSection = displayMode === 'all' || displayMode === 'settings';
    const showSections = displayMode === 'all' || displayMode === 'sections';
    const Quill: any = ReactQuill;

    React.useEffect(() => {
        if (!item.eventData) {
            onUpdate(item.id, 'eventData', eventData);
        }
        // initialize only missing event data
        // eslint-disable-next-line react-hooks/exhaustive-deps
    }, []);

    const updateEventData = (nextData: EventData) => {
        onUpdate(item.id, 'eventData', nextData);
    };

    const updateField = (field: keyof EventData, value: any) => {
        updateEventData({ ...eventData, [field]: value });
    };

    const addSchedule = () => {
        const nextOrder = eventData.schedule.length > 0
            ? Math.max(...eventData.schedule.map((entry) => Number(entry.orderNumber) || 0)) + 1
            : 1;
        updateEventData({ ...eventData, schedule: [...eventData.schedule, makeScheduleItem(nextOrder)] });
    };

    const updateSchedule = (scheduleId: string, field: keyof EventScheduleItem, value: string) => {
        updateEventData({
            ...eventData,
            schedule: eventData.schedule.map((entry) => entry.id === scheduleId ? { ...entry, [field]: value } : entry),
        });
    };

    const removeSchedule = (scheduleId: string) => {
        const next = eventData.schedule.filter((entry) => entry.id !== scheduleId);
        updateEventData({
            ...eventData,
            schedule: (next.length > 0 ? next : [makeScheduleItem(1)]).map((entry, entryIndex) => ({
                ...entry,
                orderNumber: entryIndex + 1,
            })),
        });
    };

    const addHighlight = () => {
        updateEventData({ ...eventData, highlights: [...eventData.highlights, makeHighlightItem()] });
    };

    const updateHighlight = (highlightId: string, field: keyof EventHighlightItem, value: string) => {
        updateEventData({
            ...eventData,
            highlights: eventData.highlights.map((entry) => entry.id === highlightId ? { ...entry, [field]: value } : entry),
        });
    };

    const removeHighlight = (highlightId: string) => {
        const next = eventData.highlights.filter((entry) => entry.id !== highlightId);
        updateEventData({ ...eventData, highlights: next.length > 0 ? next : [makeHighlightItem()] });
    };

    const addSpeaker = () => {
        updateEventData({ ...eventData, speakers: [...eventData.speakers, makeSpeakerItem()] });
    };

    const updateSpeaker = (speakerId: string, field: keyof EventSpeakerItem, value: string) => {
        updateEventData({
            ...eventData,
            speakers: eventData.speakers.map((entry) => entry.id === speakerId ? { ...entry, [field]: value } : entry),
        });
    };

    const removeSpeaker = (speakerId: string) => {
        const next = eventData.speakers.filter((entry) => entry.id !== speakerId);
        updateEventData({ ...eventData, speakers: next.length > 0 ? next : [makeSpeakerItem()] });
    };

    const toggleSpeaker = (speakerId: string) => {
        setCollapsedSpeakers((prev) => {
            const next = new Set(prev);
            if (next.has(speakerId)) next.delete(speakerId);
            else next.add(speakerId);
            return next;
        });
    };

    const renderField = (
        label: string,
        field: keyof EventData,
        placeholder: string,
        type: 'text' | 'datetime-local' = 'text'
    ) => (
        <div className="space-y-1.5">
            <label className="text-[12px] font-black text-palette-tan/60 uppercase tracking-wider">{label}</label>
            <input
                type={type}
                value={String(eventData[field] || '')}
                onChange={(event) => updateField(field, event.target.value)}
                placeholder={placeholder}
                className="w-full h-11 bg-palette-beige/5 border border-palette-tan/20 rounded-[3px] px-3 text-sm font-bold text-palette-maroon outline-none focus:border-palette-red transition-all placeholder:text-palette-tan/35"
            />
        </div>
    );

    const renderSectionTitle = (field: 'scheduleTitle' | 'highlightsTitle' | 'speakersTitle', placeholder: string) => (
        <div className="space-y-1.5">
            <label className="text-[12px] font-black text-palette-tan/60 uppercase tracking-wider">{t('admin.post.event.section_title')}</label>
            <input
                type="text"
                value={eventData[field]}
                onChange={(event) => updateField(field, event.target.value)}
                placeholder={placeholder}
                className="w-full h-10 bg-palette-beige/5 border border-palette-tan/20 rounded-[3px] px-3 text-sm font-bold text-palette-maroon outline-none focus:border-palette-red transition-all placeholder:text-palette-tan/30"
            />
        </div>
    );

    const sectionCardClass = "rounded-[3px] border border-palette-tan/20 bg-white shadow-sm p-5 space-y-4";

    return (
        <div className="space-y-6 animate-in slide-in-from-top-4 duration-500 admin-font">
            {showSettingsSection && (
                <div className="space-y-4">
                    <div className="flex items-center gap-2">
                        <span className="material-symbols-rounded text-palette-tan/60" style={{ fontSize: '18px' }}>event</span>
                        <label className="text-[12px] font-bold text-palette-tan/60">{t('admin.post.event.settings_title')}</label>
                    </div>
                    <div className="grid grid-cols-1 sm:grid-cols-2 xl:grid-cols-4 gap-4">
                        {renderField(t('admin.post.event.start_datetime'), 'startDateTime', '', 'datetime-local')}
                        {renderField(t('admin.post.event.end_datetime'), 'endDateTime', '', 'datetime-local')}
                        {renderField(t('admin.post.event.organizer'), 'organizer', t('admin.post.event.organizer_placeholder'))}
                        {renderField(t('admin.post.event.venue_name'), 'venueName', t('admin.post.event.venue_placeholder'))}
                    </div>
                    <div className="grid grid-cols-1 xl:grid-cols-[minmax(0,2fr)_minmax(0,1fr)_minmax(0,1fr)] gap-4">
                        <div className="space-y-1.5">
                            <label className="text-[12px] font-black text-palette-tan/60 uppercase tracking-wider">{t('admin.post.event.address')}</label>
                            <textarea
                                value={eventData.address}
                                onChange={(event) => updateField('address', event.target.value)}
                                placeholder={t('admin.post.event.address_placeholder')}
                                rows={3}
                                className="w-full bg-palette-beige/5 border border-palette-tan/20 rounded-[3px] px-3 py-2 text-sm font-bold text-palette-maroon outline-none focus:border-palette-red transition-all resize-none placeholder:text-palette-tan/35"
                            />
                        </div>
                        {renderField(t('admin.post.event.latitude'), 'latitude', '0.000000')}
                        {renderField(t('admin.post.event.longitude'), 'longitude', '0.000000')}
                    </div>
                    <div className="grid grid-cols-1 sm:grid-cols-2 xl:grid-cols-4 gap-4">
                        <div className="space-y-1.5">
                            <label className="text-[12px] font-black text-palette-tan/60 uppercase tracking-wider">{t('admin.post.event.registration_type')}</label>
                            <select
                                value={eventData.registrationType || 'none'}
                                onChange={(event) => updateField('registrationType', event.target.value as EventRegistrationType)}
                                className="w-full h-11 bg-palette-beige/5 border border-palette-tan/20 rounded-[3px] px-3 text-sm font-bold text-palette-maroon outline-none focus:border-palette-red transition-all"
                            >
                                <option value="none">{t('admin.post.event.registration_none')}</option>
                                <option value="required">{t('admin.post.event.registration_required')}</option>
                                <option value="tickets">{t('admin.post.event.registration_tickets')}</option>
                                <option value="external">{t('admin.post.event.registration_external')}</option>
                            </select>
                        </div>
                        {renderField(t('admin.post.event.ticket_url'), 'ticketUrl', t('admin.post.event.ticket_url_placeholder'))}
                        {renderField(t('admin.post.event.ticket_price'), 'ticketPrice', t('admin.post.event.ticket_price_placeholder'))}
                        {renderField(t('admin.post.event.capacity'), 'capacity', t('admin.post.event.capacity_placeholder'))}
                    </div>
                </div>
            )}

            {showSections && (
                <div className="space-y-5">
                    <div className={sectionCardClass}>
                        <div className="flex items-center justify-between gap-3 border-b border-palette-tan/10 pb-3">
                            <div className="flex items-center gap-2">
                                <span className="material-symbols-rounded text-palette-red" style={{ fontSize: '19px' }}>pending_actions</span>
                                <h4 className="text-base font-black text-palette-maroon">{t('admin.post.event.schedule')}</h4>
                            </div>
                            <button
                                type="button"
                                onClick={addSchedule}
                                className="h-8 px-3 rounded-[3px] bg-emerald-600 text-white text-[10px] font-black uppercase tracking-widest hover:bg-emerald-700 transition-all active:scale-95"
                            >
                                + {t('admin.post.event.add_schedule')}
                            </button>
                        </div>
                        {renderSectionTitle('scheduleTitle', t('admin.post.event.schedule_title_placeholder'))}
                        <div className="space-y-3">
                            {eventData.schedule.map((entry, entryIndex) => (
                                <div key={entry.id} className="rounded-[3px] border border-palette-tan/15 bg-palette-beige/[0.025] p-3 space-y-3">
                                    <div className="grid grid-cols-1 xl:grid-cols-[36px_minmax(0,0.9fr)_minmax(0,0.75fr)_minmax(0,1.25fr)_minmax(0,1.45fr)_36px] gap-3 items-center">
                                        <span className="w-9 h-9 rounded-[3px] bg-palette-maroon text-white flex items-center justify-center text-xs font-black">
                                            {entryIndex + 1}
                                        </span>
                                        <input
                                            type="date"
                                            value={entry.date}
                                            onChange={(event) => updateSchedule(entry.id, 'date', event.target.value)}
                                            className="w-full h-10 bg-palette-beige/5 border border-palette-tan/20 rounded-[3px] px-3 text-sm font-bold text-palette-maroon outline-none focus:border-palette-red transition-all placeholder:text-palette-tan/30"
                                        />
                                        <input
                                            type="text"
                                            value={entry.time}
                                            onChange={(event) => updateSchedule(entry.id, 'time', event.target.value)}
                                            placeholder={t('admin.post.event.schedule_time_placeholder')}
                                            className="w-full h-10 bg-palette-beige/5 border border-palette-tan/20 rounded-[3px] px-3 text-sm font-bold text-palette-maroon outline-none focus:border-palette-red transition-all placeholder:text-palette-tan/30"
                                        />
                                        <input
                                            type="text"
                                            value={entry.title}
                                            onChange={(event) => updateSchedule(entry.id, 'title', event.target.value)}
                                            placeholder={t('admin.post.event.schedule_item_placeholder')}
                                            className="w-full h-10 bg-palette-beige/5 border border-palette-tan/20 rounded-[3px] px-3 text-sm font-bold text-palette-maroon outline-none focus:border-palette-red transition-all placeholder:text-palette-tan/30"
                                        />
                                        <input
                                            type="text"
                                            value={entry.description}
                                            onChange={(event) => updateSchedule(entry.id, 'description', event.target.value)}
                                            placeholder={t('admin.post.event.schedule_desc_placeholder')}
                                            className="w-full h-10 bg-palette-beige/5 border border-palette-tan/20 rounded-[3px] px-3 text-sm font-bold text-palette-maroon outline-none focus:border-palette-red transition-all placeholder:text-palette-tan/30"
                                        />
                                        <button
                                            type="button"
                                            onClick={() => removeSchedule(entry.id)}
                                            className="w-9 h-9 rounded-[3px] text-palette-tan/30 hover:text-white hover:bg-palette-red transition-all flex items-center justify-center"
                                            title={t('common.delete')}
                                        >
                                            <span className="material-symbols-rounded" style={{ fontSize: '18px' }}>delete</span>
                                        </button>
                                    </div>
                                    <div className="grid grid-cols-1 md:grid-cols-[180px_minmax(0,1fr)] gap-3 items-start pl-0 xl:pl-12">
                                        <div className="space-y-2">
                                            <label className="text-[11px] font-black text-palette-tan/55 uppercase tracking-wider">{t('admin.post.event.schedule_image')}</label>
                                            <div className="rounded-[3px] bg-white border-2 border-dashed border-palette-tan/20 flex flex-col items-center justify-center overflow-hidden transition-all relative group/image w-full min-h-[118px]">
                                                {entry.image ? (
                                                    <div className="relative w-full h-full flex items-center justify-center bg-palette-beige/5 min-h-[118px]">
                                                        <img
                                                            src={entry.image}
                                                            className="max-w-full max-h-[118px] object-contain block"
                                                            alt={entry.imageDescription || entry.title}
                                                        />
                                                        <MediaFilenameBadge src={entry.image} type="image" onRename={onRenameMedia} />
                                                        <div className="absolute inset-0 bg-black/40 opacity-0 group-hover/image:opacity-100 transition-all flex items-center justify-center gap-2">
                                                            <button
                                                                type="button"
                                                                onClick={() => onOpenImageEditor(item.id, 'eventSchedule', entry.id)}
                                                                className="p-2.5 bg-white/10 backdrop-blur-md rounded-[3px] text-white hover:bg-emerald-600 transition-all flex items-center justify-center"
                                                                title={t('common.edit')}
                                                            >
                                                                <span className="material-symbols-rounded" style={{ fontSize: '18px' }}>edit_square</span>
                                                            </button>
                                                            <button
                                                                type="button"
                                                                onClick={() => updateSchedule(entry.id, 'image', '')}
                                                                className="p-2.5 bg-white/10 backdrop-blur-md rounded-[3px] text-white hover:bg-palette-red transition-all flex items-center justify-center"
                                                                title={t('common.delete')}
                                                            >
                                                                <span className="material-symbols-rounded" style={{ fontSize: '18px' }}>delete</span>
                                                            </button>
                                                        </div>
                                                    </div>
                                                ) : (
                                                    <div className="flex flex-col items-center justify-center py-5">
                                                        <button
                                                            type="button"
                                                            onClick={() => onOpenFileManager(item.id, 'eventSchedule', entry.id)}
                                                            className="flex flex-col items-center cursor-pointer group/pick mb-2"
                                                        >
                                                            <span className="material-symbols-rounded text-palette-tan/20 group-hover/pick:text-palette-maroon transition-all mb-1" style={{ fontSize: '34px' }}>add</span>
                                                            <span className="text-[12px] font-bold text-palette-tan/50 px-3 text-center">{t('admin.post.pick_image')}</span>
                                                        </button>
                                                        <button
                                                            type="button"
                                                            onClick={() => onOpenUrlMode(item.id, 'eventSchedule', entry.id)}
                                                            className="mt-1 text-[9px] font-black text-palette-tan/60 hover:text-palette-maroon border border-palette-tan/20 px-2.5 py-1.5 rounded-[3px] bg-white shadow-sm hover:shadow-md transition-all flex items-center gap-1 uppercase tracking-wider"
                                                        >
                                                            <span className="material-symbols-rounded" style={{ fontSize: '10px' }}>public</span> {t('admin.post.url_or_upload')}
                                                        </button>
                                                    </div>
                                                )}
                                            </div>
                                        </div>
                                        <div className="space-y-2">
                                            <label className="text-[11px] font-black text-palette-tan/55 uppercase tracking-wider">{t('admin.post.event.image_desc')}</label>
                                            <input
                                                type="text"
                                                value={entry.imageDescription}
                                                onChange={(event) => updateSchedule(entry.id, 'imageDescription', event.target.value)}
                                                placeholder={t('admin.post.event.image_desc_placeholder')}
                                                className="w-full h-10 bg-white border border-palette-tan/20 rounded-[3px] px-3 text-xs font-bold text-palette-maroon outline-none focus:border-palette-red transition-all placeholder:text-palette-tan/25"
                                            />
                                        </div>
                                    </div>
                                </div>
                            ))}
                        </div>
                        <p className="text-[11px] font-bold text-palette-tan/45">{t('admin.post.event.schedule_example')}</p>
                    </div>

                    <div className={sectionCardClass}>
                        <div className="flex items-center justify-between gap-3 border-b border-palette-tan/10 pb-3">
                            <div className="flex items-center gap-2">
                                <span className="material-symbols-rounded text-palette-red" style={{ fontSize: '19px' }}>info</span>
                                <h4 className="text-base font-black text-palette-maroon">{t('admin.post.event.highlights')}</h4>
                            </div>
                            <button
                                type="button"
                                onClick={addHighlight}
                                className="h-8 px-3 rounded-[3px] bg-emerald-600 text-white text-[10px] font-black uppercase tracking-widest hover:bg-emerald-700 transition-all active:scale-95"
                            >
                                + {t('admin.post.event.add_highlight')}
                            </button>
                        </div>
                        {renderSectionTitle('highlightsTitle', t('admin.post.event.highlights_title_placeholder'))}
                        <div className="space-y-3">
                            {eventData.highlights.map((entry, entryIndex) => (
                                <div key={entry.id} className="grid grid-cols-1 xl:grid-cols-[36px_minmax(0,1fr)_minmax(0,1fr)_36px] gap-3 items-center">
                                    <span className="w-9 h-9 rounded-[3px] bg-palette-maroon text-white flex items-center justify-center text-xs font-black">
                                        {entryIndex + 1}
                                    </span>
                                    <input
                                        type="text"
                                        value={entry.label}
                                        onChange={(event) => updateHighlight(entry.id, 'label', event.target.value)}
                                        placeholder={t('admin.post.event.highlight_label_placeholder')}
                                        className="w-full h-10 bg-palette-beige/5 border border-palette-tan/20 rounded-[3px] px-3 text-sm font-bold text-palette-maroon outline-none focus:border-palette-red transition-all placeholder:text-palette-tan/30"
                                    />
                                    <input
                                        type="text"
                                        value={entry.value}
                                        onChange={(event) => updateHighlight(entry.id, 'value', event.target.value)}
                                        placeholder={t('admin.post.event.highlight_value_placeholder')}
                                        className="w-full h-10 bg-palette-beige/5 border border-palette-tan/20 rounded-[3px] px-3 text-sm font-bold text-palette-maroon outline-none focus:border-palette-red transition-all placeholder:text-palette-tan/30"
                                    />
                                    <button
                                        type="button"
                                        onClick={() => removeHighlight(entry.id)}
                                        className="w-9 h-9 rounded-[3px] text-palette-tan/30 hover:text-white hover:bg-palette-red transition-all flex items-center justify-center"
                                        title={t('common.delete')}
                                    >
                                        <span className="material-symbols-rounded" style={{ fontSize: '18px' }}>delete</span>
                                    </button>
                                </div>
                            ))}
                        </div>
                        <p className="text-[11px] font-bold text-palette-tan/45">{t('admin.post.event.highlights_example')}</p>
                    </div>

                    <div className={sectionCardClass}>
                        <div className="flex items-center justify-between gap-3 border-b border-palette-tan/10 pb-3">
                            <div className="flex items-center gap-2">
                                <span className="material-symbols-rounded text-palette-red" style={{ fontSize: '19px' }}>groups</span>
                                <h4 className="text-base font-black text-palette-maroon">{t('admin.post.event.speakers')}</h4>
                            </div>
                            <button
                                type="button"
                                onClick={addSpeaker}
                                className="h-8 px-3 rounded-[3px] bg-emerald-600 text-white text-[10px] font-black uppercase tracking-widest hover:bg-emerald-700 transition-all active:scale-95"
                            >
                                + {t('admin.post.event.add_speaker')}
                            </button>
                        </div>
                        {renderSectionTitle('speakersTitle', t('admin.post.event.speakers_title_placeholder'))}
                        <div className="space-y-4">
                            {eventData.speakers.map((speaker, speakerIndex) => {
                                const isCollapsed = collapsedSpeakers.has(speaker.id);

                                return (
                                    <div key={speaker.id} className="group bg-white rounded-[3px] border border-palette-tan/20 shadow-sm flex overflow-hidden animate-in slide-in-from-left duration-300">
                                        <div className="w-12 shrink-0 bg-palette-beige/5 border-r border-palette-tan/10 flex flex-col items-center py-5 justify-between">
                                            <span className="w-8 h-8 rounded-[3px] bg-palette-maroon text-white flex items-center justify-center text-xs font-black">
                                                {speakerIndex + 1}
                                            </span>
                                            <button
                                                type="button"
                                                onClick={() => removeSpeaker(speaker.id)}
                                                className="w-8 h-8 flex items-center justify-center rounded-[3px] text-palette-tan/30 hover:text-white hover:bg-palette-red hover:shadow-md transition-all active:scale-90"
                                                title={t('common.delete')}
                                            >
                                                <span className="material-symbols-rounded" style={{ fontSize: '18px' }}>delete</span>
                                            </button>
                                        </div>
                                        <div className="flex-1 p-5 space-y-5">
                                            <div className="flex items-center justify-between gap-4 border-b border-palette-tan/15 pb-3">
                                                <div className="flex items-center gap-3 min-w-0">
                                                    <div className="p-2 bg-palette-red/10 rounded-[3px] text-palette-red">
                                                        <span className="material-symbols-rounded" style={{ fontSize: '18px' }}>person</span>
                                                    </div>
                                                    <h3 className="text-base font-black text-palette-maroon truncate">{t('admin.post.event.speaker')} #{speakerIndex + 1}</h3>
                                                </div>
                                                <button
                                                    type="button"
                                                    onClick={() => toggleSpeaker(speaker.id)}
                                                    className="w-8 h-8 rounded-[3px] flex items-center justify-center text-palette-tan/45 hover:text-palette-maroon hover:bg-palette-beige/20 transition-all"
                                                    title={isCollapsed ? t('common.show_all') : t('common.hide_details')}
                                                >
                                                    <span className={`material-symbols-rounded transition-transform ${isCollapsed ? '-rotate-90' : ''}`} style={{ fontSize: '19px' }}>expand_more</span>
                                                </button>
                                            </div>
                                            {!isCollapsed && (
                                                <div className="space-y-5">
                                                    <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
                                                        <div className="space-y-1.5">
                                                            <label className="text-[12px] font-black text-palette-tan/60 uppercase tracking-wider">{t('admin.post.event.speaker_name')}</label>
                                                            <input
                                                                type="text"
                                                                value={speaker.name}
                                                                onChange={(event) => updateSpeaker(speaker.id, 'name', event.target.value)}
                                                                placeholder={t('admin.post.event.speaker_name_placeholder')}
                                                                className="w-full h-10 bg-palette-beige/5 border border-palette-tan/20 rounded-[3px] px-3 text-sm font-bold text-palette-maroon outline-none focus:border-palette-red transition-all placeholder:text-palette-tan/30"
                                                            />
                                                        </div>
                                                        <div className="space-y-1.5">
                                                            <label className="text-[12px] font-black text-palette-tan/60 uppercase tracking-wider">{t('admin.post.event.speaker_role')}</label>
                                                            <input
                                                                type="text"
                                                                value={speaker.role}
                                                                onChange={(event) => updateSpeaker(speaker.id, 'role', event.target.value)}
                                                                placeholder={t('admin.post.event.speaker_role_placeholder')}
                                                                className="w-full h-10 bg-palette-beige/5 border border-palette-tan/20 rounded-[3px] px-3 text-sm font-bold text-palette-maroon outline-none focus:border-palette-red transition-all placeholder:text-palette-tan/30"
                                                            />
                                                        </div>
                                                    </div>
                                                    <div className="grid grid-cols-1 md:grid-cols-12 gap-5 items-start">
                                                        <div className="md:col-span-4 space-y-2">
                                                            <label className="text-[13px] font-black text-palette-tan ml-1 uppercase tracking-wider">{t('admin.post.event.speaker_image')}</label>
                                                            <div className="rounded-[3px] bg-palette-beige/5 border-2 border-dashed border-palette-tan/20 flex flex-col items-center justify-center overflow-hidden transition-all relative group/image w-full min-h-[190px]">
                                                                {speaker.image ? (
                                                                    <div className="relative w-full h-full flex items-center justify-center bg-palette-beige/5 min-h-[190px]">
                                                                        <img
                                                                            src={speaker.image}
                                                                            className="max-w-full max-h-[190px] object-contain block"
                                                                            alt={speaker.imageDescription || speaker.name}
                                                                        />
                                                                        <MediaFilenameBadge src={speaker.image} type="image" onRename={onRenameMedia} />
                                                                        <div className="absolute inset-0 bg-black/40 opacity-0 group-hover/image:opacity-100 transition-all flex items-center justify-center gap-2">
                                                                            <button
                                                                                type="button"
                                                                                onClick={() => onOpenImageEditor(item.id, 'eventSpeakers', speaker.id)}
                                                                                className="p-3 bg-white/10 backdrop-blur-md rounded-[3px] text-white hover:bg-emerald-600 transition-all flex items-center justify-center"
                                                                                title={t('common.edit')}
                                                                            >
                                                                                <span className="material-symbols-rounded" style={{ fontSize: '20px' }}>edit_square</span>
                                                                            </button>
                                                                            <button
                                                                                type="button"
                                                                                onClick={() => updateSpeaker(speaker.id, 'image', '')}
                                                                                className="p-3 bg-white/10 backdrop-blur-md rounded-[3px] text-white hover:bg-palette-red transition-all flex items-center justify-center"
                                                                                title={t('common.delete')}
                                                                            >
                                                                                <span className="material-symbols-rounded" style={{ fontSize: '20px' }}>delete</span>
                                                                            </button>
                                                                        </div>
                                                                    </div>
                                                                ) : (
                                                                    <div className="flex flex-col items-center justify-center py-10">
                                                                        <button
                                                                            type="button"
                                                                            onClick={() => onOpenFileManager(item.id, 'eventSpeakers', speaker.id)}
                                                                            className="flex flex-col items-center cursor-pointer group/pick mb-4"
                                                                        >
                                                                            <span className="material-symbols-rounded text-palette-tan/20 group-hover/pick:text-palette-maroon transition-all mb-2" style={{ fontSize: '44px' }}>add</span>
                                                                            <span className="text-[14px] font-bold text-palette-tan/50 px-4 text-center">{t('admin.post.pick_image')}</span>
                                                                        </button>
                                                                        <button
                                                                            type="button"
                                                                            onClick={() => onOpenUrlMode(item.id, 'eventSpeakers', speaker.id)}
                                                                            className="mt-2 text-[10px] font-black text-palette-tan/60 hover:text-palette-maroon border border-palette-tan/20 px-3 py-1.5 rounded-[3px] bg-white shadow-sm hover:shadow-md transition-all flex items-center gap-1.5 uppercase tracking-wider"
                                                                        >
                                                                            <span className="material-symbols-rounded" style={{ fontSize: '11px' }}>public</span> {t('admin.post.url_or_upload')}
                                                                        </button>
                                                                    </div>
                                                                )}
                                                            </div>
                                                            <input
                                                                type="text"
                                                                value={speaker.imageDescription}
                                                                onChange={(event) => updateSpeaker(speaker.id, 'imageDescription', event.target.value)}
                                                                placeholder={t('admin.post.event.image_desc_placeholder')}
                                                                className="w-full bg-palette-beige/5 border border-palette-tan/20 rounded-[3px] px-3 py-2 text-xs font-bold text-palette-maroon outline-none focus:border-palette-red transition-all placeholder:text-palette-tan/25"
                                                            />
                                                        </div>
                                                        <div className="md:col-span-8 h-full flex flex-col">
                                                            <div className="space-y-2 group/editor flex-1 flex flex-col">
                                                                <label className="text-[13px] font-black text-palette-tan uppercase tracking-wider">{t('admin.post.event.speaker_bio')}</label>
                                                                <div className="quill-modern-wrapper compact-quill border border-palette-tan/20 rounded-[3px] overflow-hidden focus-within:border-palette-red/40 transition-all shadow-sm bg-white flex-1 min-h-[190px]">
                                                                    <Quill
                                                                        theme="snow"
                                                                        value={speaker.bio}
                                                                        onChange={(content: string) => updateSpeaker(speaker.id, 'bio', content)}
                                                                        modules={QUILL_MODULES}
                                                                        formats={QUILL_FORMATS}
                                                                        placeholder={t('admin.post.event.speaker_bio_placeholder')}
                                                                        className="modern-quill-editor h-full"
                                                                    />
                                                                </div>
                                                            </div>
                                                        </div>
                                                    </div>
                                                </div>
                                            )}
                                        </div>
                                    </div>
                                );
                            })}
                        </div>
                    </div>
                </div>
            )}
        </div>
    );
};

export default PostEventItem;
