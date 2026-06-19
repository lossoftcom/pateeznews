import React from 'react';
import type { NavigationItem } from '@/types';
import Sidebar from '@/components/Sidebar';

interface ProfilePageLayoutProps {
  navigationItems: NavigationItem[];
  children: React.ReactNode;
  contentClassName?: string;
}

const ProfilePageLayout: React.FC<ProfilePageLayoutProps> = ({
  navigationItems,
  children,
  contentClassName = 'max-w-[940px]',
}) => (
  <>
    <style>{`
      .profile-page-sidebar h3 {
        text-transform: none !important;
        letter-spacing: 0 !important;
      }
    `}</style>
    <main className="max-w-[1280px] pt-[92px] gap-8 px-4 mx-auto flex justify-center items-start">
      <aside className="profile-page-sidebar hidden lg:block w-[260px] flex-shrink-0 sticky top-[92px] h-[calc(100vh-92px)] overflow-y-auto pb-8 no-scrollbar">
        <Sidebar
          items={navigationItems}
          activeCategory={null}
          loading={navigationItems.length === 0}
        />
      </aside>

      <section className="flex-1 min-w-0 pb-10 flex justify-center w-full">
        <div className={`w-full ${contentClassName}`}>
          {children}
        </div>
      </section>
    </main>
  </>
);

export default ProfilePageLayout;
