import React, { useState, useEffect, useRef, useCallback } from 'react';
import { useLanguage } from '@/context/LanguageContext';

interface AiAssistantDialogProps {
    isOpen: boolean;
    onClose: () => void;
}

const AiAssistantDialog: React.FC<AiAssistantDialogProps> = ({ isOpen, onClose }) => {
    const { t } = useLanguage();
    const [position, setPosition] = useState({ x: 100, y: 100 });
    const [size, setSize] = useState({ width: 900, height: 600 });
    const [isDragging, setIsDragging] = useState(false);
    const [isResizing, setIsResizing] = useState(false);
    const [content, setContent] = useState('');
    const [resultContent, setResultContent] = useState('');
    const [isCopied, setIsCopied] = useState(false);

    const dragOffset = useRef({ x: 0, y: 0 });
    const dialogRef = useRef<HTMLDivElement>(null);

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
        navigator.clipboard.writeText(resultContent).then(() => {
            setIsCopied(true);
            setTimeout(() => setIsCopied(false), 2000);
        });
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
                    <div className="flex-1 w-full p-5 bg-white border border-palette-tan/10 rounded-[6px] text-sm font-medium text-palette-maroon shadow-inner leading-relaxed overflow-y-auto custom-scrollbar selection:bg-palette-maroon/10">
                        {resultContent || (
                            <div className="h-full flex flex-col items-center justify-center text-palette-tan/30 select-none">
                                <span className="material-symbols-rounded mb-2" style={{ fontSize: '48px' }}>magic_button</span>
                                <p className="text-[11px] font-bold uppercase tracking-widest">{t('admin.ai_assistant.ready')}</p>
                            </div>
                        )}
                    </div>
                </div>
            </div>

            {/* Footer Actions */}
            <div className="h-16 bg-white border-t border-palette-maroon/10 flex items-center justify-between px-6 shrink-0">
                <div className="text-[10px] font-bold text-palette-tan/40 flex items-center gap-1.5">
                    <span className="w-1.5 h-1.5 rounded-full bg-emerald-500 animate-pulse"></span>
                    {t('admin.ai_assistant.ready')}
                </div>
                <button
                    onClick={() => setResultContent(content)} // Temporary: For testing split view
                    className="flex items-center gap-2 px-8 py-2.5 bg-palette-maroon text-white rounded-[4px] font-black text-[11px] tracking-widest hover:bg-palette-red transition-all shadow-xl shadow-palette-maroon/10 active:scale-95"
                >
                    <span className="material-symbols-rounded" style={{ fontSize: '18px' }}>bolt</span>
                    {t('admin.ai_assistant.generate')}
                </button>
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
