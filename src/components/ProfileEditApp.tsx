import React, { useCallback, useEffect, useMemo, useState } from 'react';
import type { NavigationItem, SiteSettings } from '@/types';
import { LanguageProvider } from '@/context/LanguageContext';
import { ToastProvider } from '@/context/ToastContext';
import { useSupabaseSession } from '@/hooks/useSupabaseSession';
import { clearSupabaseAuthStorage, supabase } from '@/lib/supabase';
import { navigateImmediately } from '@/utils/immediateNavigation';
// import Navbar from '@/components/Navbar'; // Removed - Global
import Login from '@/components/auth/Login';
import UserEditProfile from '@/components/UserEditProfile';
import ProfilePageLayout from '@/components/ProfilePageLayout';

interface ProfileEditAppProps {
  initialLang: any;
  initialTranslations: Record<string, string>;
  siteSettings: SiteSettings | null;
  navigationItems: NavigationItem[];
}

const ProfileEditApp: React.FC<ProfileEditAppProps> = ({ initialLang, initialTranslations, siteSettings, navigationItems }) => {
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

  return (
    <LanguageProvider initialLang={initialLang} initialTranslations={initialTranslations}>
      <ToastProvider>

        <ProfilePageLayout navigationItems={navigationItems}>
          {loading ? (
            <div className="h-40" />
          ) : user ? (
            <UserEditProfile
              userId={user.id}
              name={profileName}
              onBack={goProfile}
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

export default ProfileEditApp;
