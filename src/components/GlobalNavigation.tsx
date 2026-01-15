import React, { useState, useEffect } from 'react';
import Navbar from '@/components/Navbar';
import Login from '@/components/auth/Login';
import type { SiteSettings, NavigationItem } from '@/types';
import { useSupabaseSession } from '@/hooks/useSupabaseSession';
import { supabase } from '@/lib/supabase';
import { LanguageProvider } from '@/context/LanguageContext';
import { ToastProvider } from '@/context/ToastContext';
import { navigate } from 'astro:transitions/client';

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

    const handleHomeClick = () => {
        void navigate('/');
    };

    const handleAdminClick = () => {
        void navigate('/admin');
    };

    const handleLogout = async () => {
        document.cookie = "pateez_active_cat=; path=/; expires=Thu, 01 Jan 1970 00:00:00 UTC";
        await supabase.auth.signOut();
        await navigate('/');
    };

    return (
        <LanguageProvider initialLang={initialLang} initialTranslations={initialTranslations}>
            <ToastProvider>
                <div className="fixed top-0 left-0 w-full z-[999]">
                    <Navbar
                        siteSettings={siteSettings}
                        navItems={navigationItems}
                        onHomeClick={handleHomeClick}
                        onProfileClick={() => setIsLoginOpen(true)}
                        onAdminClick={handleAdminClick}
                        onProfileViewClick={() => { void navigate('/profil'); }}
                        onEditProfileClick={() => { void navigate('/profil-duzenle'); }}
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
                    />
                )}
            </ToastProvider>
        </LanguageProvider>
    );
};

export default GlobalNavigation;
