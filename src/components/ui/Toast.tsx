
import React, { useEffect, useState } from 'react';

interface ToastProps {
    message: string;
    type?: 'success' | 'error' | 'info' | 'warning';
    onClose: () => void;
}

const Toast: React.FC<ToastProps> = ({ message, type = 'success', onClose }) => {
    const [isVisible, setIsVisible] = useState(false);

    useEffect(() => {
        setIsVisible(true);
        const timer = setTimeout(() => {
            setIsVisible(false);
            setTimeout(onClose, 500);
        }, 2800);

        return () => clearTimeout(timer);
    }, [onClose]);

    const getIcon = () => {
        switch (type) {
            case 'success': return 'check';
            case 'error': return 'error';
            case 'warning': return 'warning';
            default: return 'info';
        }
    };

    const toneClass = {
        success: 'text-emerald-600 bg-emerald-50',
        error: 'text-palette-red bg-palette-red/5',
        warning: 'text-amber-600 bg-amber-50',
        info: 'text-blue-600 bg-blue-50',
    }[type];

    const progressClass = {
        success: 'bg-emerald-500',
        error: 'bg-palette-red',
        warning: 'bg-amber-500',
        info: 'bg-blue-500',
    }[type];

    return (
        <div className={`fixed bottom-10 left-1/2 -translate-x-1/2 z-[999999] px-4 transition-all duration-500 ease-[cubic-bezier(0.23,1,0.32,1)] ${isVisible ? 'opacity-100 translate-y-0 scale-100' : 'opacity-0 translate-y-5 scale-95'}`}>
            <div className="relative flex min-w-[280px] max-w-[360px] items-center gap-3 overflow-hidden rounded-[6px] border border-gray-200/80 bg-white/95 px-4 py-3 shadow-[0_14px_36px_rgba(24,37,64,0.12)] backdrop-blur-xl">
                <div className={`flex h-8 w-8 shrink-0 items-center justify-center rounded-[5px] ${toneClass}`}>
                    <span className="material-symbols-rounded" style={{ fontSize: '19px', fontVariationSettings: "'FILL' 1" }}>{getIcon()}</span>
                </div>

                <div className="min-w-0 flex-1">
                    <p className="text-[13px] font-semibold text-palette-maroon tracking-tight leading-snug">{message}</p>
                </div>

                <button
                    onClick={() => { setIsVisible(false); setTimeout(onClose, 500); }}
                    className="flex h-7 w-7 shrink-0 items-center justify-center rounded-[5px] text-palette-tan/45 transition-all hover:bg-gray-100 hover:text-palette-maroon active:scale-90"
                    aria-label="Kapat"
                >
                    <span className="material-symbols-rounded" style={{ fontSize: '18px' }}>close</span>
                </button>

                <div className="absolute bottom-0 left-0 h-[2px] w-full bg-gray-100">
                    <div
                        className={`h-full rounded-r-full transition-all duration-[2800ms] ease-linear ${progressClass}`}
                        style={{ width: isVisible ? '100%' : '0%' }}
                    />
                </div>
            </div>
        </div>
    );
};

export default Toast;
