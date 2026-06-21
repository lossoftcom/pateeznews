import React, { useCallback, useEffect, useMemo, useState } from 'react';
import type { NavigationItem, PublicAdSettings, SiteSettings } from '@/types';
import { LanguageProvider } from '@/context/LanguageContext';
import { ToastProvider } from '@/context/ToastContext';
import { useSupabaseSession } from '@/hooks/useSupabaseSession';
import { clearSupabaseAuthStorage, supabase } from '@/lib/supabase';
import { navigateImmediately } from '@/utils/immediateNavigation';
// import Navbar from '@/components/Navbar'; // Removed - Global
import Login from '@/components/auth/Login';
import UserProfile from '@/components/UserProfile';
import ProfilePageLayout from '@/components/ProfilePageLayout';

interface ProfileAppProps {
  initialLang: any;
  initialTranslations: Record<string, string>;
  siteSettings: SiteSettings | null;
  navigationItems: NavigationItem[];
  adSettings?: PublicAdSettings | null;
}

const ProfileApp: React.FC<ProfileAppProps> = ({ initialLang, initialTranslations, siteSettings, navigationItems, adSettings = null }) => {
  const { user, profile, loading } = useSupabaseSession();
  const [isLoginOpen, setIsLoginOpen] = useState(false);

  useEffect(() => {
    if (!loading && !user) setIsLoginOpen(true);
  }, [loading, user]);

  const goHome = useCallback(() => {
    void navigateImmediately('/');
  }, []);

  const goProfile = useCallback(() => {
    void navigateImmediately('/profil');
  }, []);

  const goEditProfile = useCallback(() => {
    void navigateImmediately('/profil-duzenle');
  }, []);

  const handleLogout = useCallback(async () => {
    await supabase.auth.signOut();
    clearSupabaseAuthStorage();
    await navigateImmediately('/');
  }, []);

  const profileName = useMemo(() => {
    return user?.user_metadata?.full_name || user?.email?.split('@')[0] || '';
  }, [user]);

  const handleNewsSelect = useCallback((id: string) => {
    void navigateImmediately(`/haber/${encodeURIComponent(id)}`);
  }, []);

  return (
    <LanguageProvider initialLang={initialLang} initialTranslations={initialTranslations}>
      <ToastProvider>

        <ProfilePageLayout navigationItems={navigationItems} adSettings={adSettings}>
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
              initialProfile={profile ? {
                id: profile.id,
                username: profile.username,
                full_name: profile.full_name,
                avatar_url: profile.avatar_url,
                role: profile.role,
                email: profile.email,
                writer_application_status: (profile as any).writer_application_status,
                writer_application_at: (profile as any).writer_application_at,
                show_email: true,
                is_own_profile: true,
              } : null}
            />
          ) : null}
        </ProfilePageLayout>

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
