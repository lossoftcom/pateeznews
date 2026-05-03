import React, { useState } from 'react';

type MediaType = 'image' | 'video' | 'audio' | 'file' | 'logo' | 'profile';
type MediaRenameHandler = {
    bivarianceHack(src: string, type: MediaType): Promise<string | null>;
}['bivarianceHack'];

interface MediaFilenameBadgeProps {
    src?: string;
    type?: MediaType;
    onRename?: MediaRenameHandler;
    className?: string;
}

const decodeSafe = (value: string) => {
    try {
        return decodeURIComponent(value);
    } catch {
        return value;
    }
};

export const mediaFileNameFromUrl = (src?: string) => {
    if (!src) return '';
    const clean = String(src).split(/[?#]/)[0];
    const last = clean.split('/').filter(Boolean).pop() || '';
    return decodeSafe(last);
};

const MediaFilenameBadge: React.FC<MediaFilenameBadgeProps> = ({
    src,
    type = 'image',
    onRename,
    className = ''
}) => {
    const [renaming, setRenaming] = useState(false);
    const fileName = mediaFileNameFromUrl(src);
    if (!src || !fileName) return null;
    const canRename = Boolean(onRename && src.includes('/api/storage/file/'));

    const handleRename = async (event: React.MouseEvent<HTMLButtonElement>) => {
        event.preventDefault();
        event.stopPropagation();
        if (!canRename || !onRename || renaming) return;

        setRenaming(true);
        try {
            await onRename(src, type);
        } finally {
            setRenaming(false);
        }
    };

    return (
        <div
            className={`absolute bottom-2 right-2 z-20 flex max-w-[92%] items-center gap-1.5 rounded-[3px] bg-black/70 p-1 text-white shadow-lg backdrop-blur-md ${className}`}
            onClick={(event) => event.stopPropagation()}
        >
            <span
                className="max-w-[180px] truncate px-1 text-[9px] font-black leading-none tracking-tight"
                title={fileName}
            >
                {fileName}
            </span>
            {canRename && (
                <button
                    type="button"
                    onClick={handleRename}
                    disabled={renaming}
                    aria-label="AI ile SEO dosya adını düzenle"
                    className="flex h-6 shrink-0 items-center gap-1 rounded-[2px] bg-white px-1.5 text-[9px] font-black uppercase tracking-tight text-palette-maroon transition-all hover:bg-emerald-500 hover:text-white disabled:opacity-60"
                    title="AI ile SEO dosya adı oluştur"
                >
                    <span className={`material-symbols-rounded ${renaming ? 'animate-spin' : ''}`} style={{ fontSize: '13px' }}>
                        {renaming ? 'progress_activity' : 'drive_file_rename_outline'}
                    </span>
                    <span>İsim</span>
                </button>
            )}
        </div>
    );
};

export default MediaFilenameBadge;
