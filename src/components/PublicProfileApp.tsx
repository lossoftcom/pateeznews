import React, { useCallback } from 'react';
import type { NavigationItem, PublicAdSettings, SiteSettings } from '@/types';
import { LanguageProvider } from '@/context/LanguageContext';
import { ToastProvider } from '@/context/ToastContext';
import UserProfile from '@/components/UserProfile';
import ProfilePageLayout from '@/components/ProfilePageLayout';
import { navigateImmediately } from '@/utils/immediateNavigation';

interface PublicProfileAppProps {
  initialLang: any;
  initialTranslations: Record<string, string>;
  siteSettings: SiteSettings | null;
  navigationItems: NavigationItem[];
  profileId: string;
  profileName: string;
  initialProfile?: Record<string, any> | null;
  adSettings?: PublicAdSettings | null;
}

const PublicProfileApp: React.FC<PublicProfileAppProps> = ({
  initialLang,
  initialTranslations,
  siteSettings,
  navigationItems,
  profileId,
  profileName,
  initialProfile = null,
  adSettings = null,
}) => {
  const goHome = useCallback(() => {
    void navigateImmediately('/');
  }, []);

  const goEditProfile = useCallback(() => {
    void navigateImmediately('/profil-duzenle');
  }, []);

  const handleNewsSelect = useCallback((id: string) => {
    void navigateImmediately(`/haber/${encodeURIComponent(id)}`);
  }, []);

  return (
    <LanguageProvider initialLang={initialLang} initialTranslations={initialTranslations}>
      <ToastProvider>
        <ProfilePageLayout navigationItems={navigationItems} adSettings={adSettings}>
          <UserProfile
            userId={profileId}
            name={profileName}
            onBack={goHome}
            onNewsSelect={handleNewsSelect}
            onEditClick={goEditProfile}
            siteSettings={siteSettings}
            showEmail={false}
            initialProfile={initialProfile}
          />
        </ProfilePageLayout>
      </ToastProvider>
    </LanguageProvider>
  );
};

export default PublicProfileApp;
