import React, { useCallback, useEffect, useRef, useState } from 'react';
import Navbar from '@/components/Navbar';
import Login from '@/components/auth/Login';
import type { SiteSettings, NavigationItem } from '@/types';
import { useSupabaseSession } from '@/hooks/useSupabaseSession';
import { clearSupabaseAuthStorage, supabase } from '@/lib/supabase';
import { LanguageProvider } from '@/context/LanguageContext';
import { ToastProvider } from '@/context/ToastContext';
import { navigateImmediately } from '@/utils/immediateNavigation';

interface GlobalNavigationProps {
    initialLang: any;
    initialTranslations: Record<string, string>;
    siteSettings: SiteSettings | null;
    navigationItems: NavigationItem[];
}

const GlobalNavigation: React.FC<GlobalNavigationProps> = ({
    initialLang,
    initialTranslations,
    siteSettings,
    navigationItems
}) => {
    // 2026 LIGHT-SPEED SESSION
    const { user, profile, loading } = useSupabaseSession();
    const [isLoginOpen, setIsLoginOpen] = useState(false);
    const isAuthenticated = !!user || !!profile;
    const logoutRef = useRef<() => Promise<void>>(async () => undefined);

    const handleHomeClick = () => {
        void navigateImmediately('/');
    };

    const handleLogout = useCallback(async () => {
        document.cookie = "pateez_active_cat=; path=/; expires=Thu, 01 Jan 1970 00:00:00 UTC";
        await supabase.auth.signOut();
        clearSupabaseAuthStorage();
        await navigateImmediately('/');
    }, []);

    useEffect(() => {
        logoutRef.current = handleLogout;
    }, [handleLogout]);

    useEffect(() => {
        if (!isAuthenticated || typeof window === 'undefined') return;

        const timeoutMs = 45 * 60 * 1000;
        const storageKey = 'pateez_auth_last_activity_at';
        const persistIntervalMs = 15 * 1000;
        const activityEvents = [
            'pointerdown',
            'pointermove',
            'keydown',
            'wheel',
            'touchstart',
            'scroll',
        ] as const;
        let timer: number | undefined;
        let loggedOut = false;
        let lastActivityAt = Date.now();
        let lastPersistAt = 0;

        const persistActivity = (value: number) => {
            try {
                window.localStorage.setItem(storageKey, String(value));
                lastPersistAt = value;
            } catch { }
        };

        const readActivity = () => {
            try {
                const stored = Number(window.localStorage.getItem(storageKey) || 0);
                if (Number.isFinite(stored) && stored > 0) {
                    lastActivityAt = Math.max(lastActivityAt, stored);
                }
            } catch { }
            return lastActivityAt;
        };

        const scheduleCheck = () => {
            window.clearTimeout(timer);
            if (loggedOut) return;
            const elapsedMs = Date.now() - readActivity();
            const remainingMs = timeoutMs - elapsedMs;
            if (remainingMs <= 0) {
                loggedOut = true;
                void logoutRef.current();
                return;
            }
            timer = window.setTimeout(scheduleCheck, remainingMs);
        };

        const markActivity = () => {
            if (loggedOut) return;
            const now = Date.now();
            lastActivityAt = now;
            if (now - lastPersistAt >= persistIntervalMs) {
                persistActivity(now);
            }
            scheduleCheck();
        };

        const handleStorage = (event: StorageEvent) => {
            if (event.key !== storageKey) return;
            const next = Number(event.newValue || 0);
            if (Number.isFinite(next) && next > 0) {
                lastActivityAt = Math.max(lastActivityAt, next);
            }
            scheduleCheck();
        };

        const handleVisibilityChange = () => {
            if (document.visibilityState === 'visible') {
                scheduleCheck();
            }
        };

        persistActivity(lastActivityAt);
        scheduleCheck();
        for (const eventName of activityEvents) {
            window.addEventListener(eventName, markActivity, { passive: true });
        }
        window.addEventListener('storage', handleStorage);
        document.addEventListener('visibilitychange', handleVisibilityChange);

        return () => {
            window.clearTimeout(timer);
            for (const eventName of activityEvents) {
                window.removeEventListener(eventName, markActivity);
            }
            window.removeEventListener('storage', handleStorage);
            document.removeEventListener('visibilitychange', handleVisibilityChange);
        };
    }, [isAuthenticated]);

    return (
        <LanguageProvider initialLang={initialLang} initialTranslations={initialTranslations}>
            <ToastProvider>
                <div className="fixed top-0 left-0 w-full z-[999]">
                    <Navbar
                        siteSettings={siteSettings}
                        navItems={navigationItems}
                        onHomeClick={handleHomeClick}
                        onProfileClick={() => setIsLoginOpen(true)}
                        onProfileViewClick={() => { void navigateImmediately('/profil'); }}
                        onEditProfileClick={() => { void navigateImmediately('/profil-duzenle'); }}
                        onLogout={handleLogout}
                        isLoggedIn={!!user || !!profile}
                        user={profile ? (user ? { ...user, profile } : { profile }) : user}
                        authLoading={loading && !profile}
                    />
                </div>

                {isLoginOpen && (
                    <Login
                        onSuccess={() => setIsLoginOpen(false)}
                        onClose={() => setIsLoginOpen(false)}
                        siteSettings={siteSettings}
                    />
                )}
            </ToastProvider>
        </LanguageProvider>
    );
};

export default GlobalNavigation;
