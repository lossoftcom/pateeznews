import React, { useCallback, useEffect, useMemo, useState } from 'react';
import type { NavigationItem, SiteSettings } from '@/types';
import { LanguageProvider } from '@/context/LanguageContext';
import { ToastProvider } from '@/context/ToastContext';
import { useSupabaseSession } from '@/hooks/useSupabaseSession';
import { supabase } from '@/lib/supabase';
import { navigate } from 'astro:transitions/client';
// import Navbar from '@/components/Navbar'; // Removed - Global
import Login from '@/components/auth/Login';
import MainLoading from '@/components/MainLoading';
import UserProfile from '@/components/UserProfile';

interface ProfileAppProps {
  initialLang: any;
  initialTranslations: Record<string, string>;
  siteSettings: SiteSettings | null;
  navigationItems: NavigationItem[];
}

const ProfileApp: React.FC<ProfileAppProps> = ({ initialLang, initialTranslations, siteSettings, navigationItems }) => {
  const { user, profile, loading } = useSupabaseSession();
  const [isLoginOpen, setIsLoginOpen] = useState(false);

  useEffect(() => {
    if (!loading && !user) setIsLoginOpen(true);
  }, [loading, user]);

  const goHome = useCallback(() => {
    void navigate('/');
  }, []);

  const goProfile = useCallback(() => {
    void navigate('/profil');
  }, []);

  const goEditProfile = useCallback(() => {
    void navigate('/profil-duzenle');
  }, []);

  const handleLogout = useCallback(async () => {
    await supabase.auth.signOut();
    await navigate('/');
  }, []);

  const profileName = useMemo(() => {
    return user?.user_metadata?.full_name || user?.email?.split('@')[0] || '';
  }, [user]);

  const handleNewsSelect = useCallback((id: string) => {
    void navigate(`/haber/${encodeURIComponent(id)}`);
  }, []);

  return (
    <LanguageProvider initialLang={initialLang} initialTranslations={initialTranslations}>
      <ToastProvider>

        <main className="max-w-[1280px] pt-[92px] gap-8 px-4 mx-auto flex justify-center items-start">
          <section className="flex-1 min-w-0 pb-10 flex justify-center w-full">
            <div className="w-full">
              {loading ? (
                <div className="h-40" />
              ) : user ? (
                <UserProfile
                  userId={user.id}
                  name={profileName}
                  onBack={goHome}
                  onEditClick={goEditProfile}
                  onNewsSelect={handleNewsSelect}
                  siteSettings={siteSettings}
                />
              ) : null}
            </div>
          </section>
        </main>

        {isLoginOpen && (
          <Login
            onSuccess={() => setIsLoginOpen(false)}
            onClose={() => goHome()}
          />
        )}
      </ToastProvider>
    </LanguageProvider>
  );
};

export default ProfileApp;
