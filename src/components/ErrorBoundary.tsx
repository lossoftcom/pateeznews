
import React, { Component, ErrorInfo, ReactNode } from 'react';
import tr from '@/lib/locales/tr';
import en from '@/lib/locales/en';
import ar from '@/lib/locales/ar';

const LOCALES: Record<string, Record<string, string>> = { tr, en, ar };

interface Props {
    children: ReactNode;
}

interface State {
    hasError: boolean;
    error: Error | null;
}

class ErrorBoundary extends Component<Props, State> {
    public state: State = {
        hasError: false,
        error: null
    };

    public static getDerivedStateFromError(error: Error): State {
        return { hasError: true, error };
    }

    public componentDidCatch(error: Error, errorInfo: ErrorInfo) {
        console.error('Uncaught error:', error, errorInfo);
    }

	    private getLangCode(): string {
	        try {
	            if (typeof window !== 'undefined') {
	                const saved = localStorage.getItem('pateez_lang');
	                if (saved) return saved;
	                const browserLang = navigator.language.split('-')[0];
	                if (browserLang) return browserLang;
	            }
	        } catch {
	            // ignore
	        }
	        return 'tr';
	    }

    private t(key: string): string {
        const lang = this.getLangCode();
        return LOCALES[lang]?.[key] || LOCALES.tr?.[key] || key;
    }

    public render() {
        if (this.state.hasError) {
            return (
                <div className="min-h-screen bg-palette-beige flex flex-col items-center justify-center p-8 text-center">
                    <div className="w-16 h-16 bg-palette-red rounded-[5px] flex items-center justify-center text-white shadow-xl mb-6">
                        <span className="material-symbols-rounded text-3xl font-bold">error</span>
                    </div>
                    <h1 className="text-2xl font-bold text-palette-tan mb-4">{this.t('error_boundary.title')}</h1>
                    <p className="text-palette-tan/60 mb-8 max-w-md">{this.t('error_boundary.description')}</p>
                    <button
                        onClick={() => window.location.reload()}
                        className="px-6 py-3 bg-palette-red text-white rounded-[5px] font-bold hover:bg-red-700 transition-colors"
                    >
                        {this.t('error_boundary.refresh')}
                    </button>
                    {process.env.NODE_ENV === 'development' && (
                        <pre className="mt-8 p-4 bg-black/5 rounded-[5px] text-left text-xs overflow-auto max-w-full">
                            {this.state.error?.toString()}
                        </pre>
                    )}
                </div>
            );
        }

        return this.props.children;
    }
}

export default ErrorBoundary;
