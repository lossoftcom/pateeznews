import React, { useCallback } from 'react';
import type { SiteSettings } from '@/types';
import { LanguageProvider } from '@/context/LanguageContext';
import { ToastProvider } from '@/context/ToastContext';
import UserProfile from '@/components/UserProfile';
import { navigate } from 'astro:transitions/client';

interface PublicProfileAppProps {
  initialLang: any;
  initialTranslations: Record<string, string>;
  siteSettings: SiteSettings | null;
  profileId: string;
  profileName: string;
}

const PublicProfileApp: React.FC<PublicProfileAppProps> = ({
  initialLang,
  initialTranslations,
  siteSettings,
  profileId,
  profileName,
}) => {
  const goHome = useCallback(() => {
    void navigate('/');
  }, []);

  const goEditProfile = useCallback(() => {
    void navigate('/profil-duzenle');
  }, []);

  const handleNewsSelect = useCallback((id: string) => {
    void navigate(`/haber/${encodeURIComponent(id)}`);
  }, []);

  return (
    <LanguageProvider initialLang={initialLang} initialTranslations={initialTranslations}>
      <ToastProvider>
        <main className="max-w-[1280px] pt-[84px] gap-8 px-4 mx-auto flex justify-center items-start">
          <section className="flex-1 min-w-0 pb-10 flex justify-center w-full">
            <div className="w-full">
              <UserProfile
                userId={profileId}
                name={profileName}
                onBack={goHome}
                onNewsSelect={handleNewsSelect}
                onEditClick={goEditProfile}
                siteSettings={siteSettings}
                showEmail={false}
              />
            </div>
          </section>
        </main>
      </ToastProvider>
    </LanguageProvider>
  );
};

export default PublicProfileApp;
