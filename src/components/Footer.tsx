
import React from 'react';
import { useLanguage } from '@/context/LanguageContext';

const Footer: React.FC = () => {
  const { t } = useLanguage();
  return (
    <div className="px-3 mt-4">
      <nav className="mb-2 flex flex-wrap gap-x-3 gap-y-1 text-[11px] font-bold text-gray-500">
        <a href="/kurumsal/hakkimizda" className="hover:text-palette-red">Hakkımızda</a>
        <a href="/kurumsal/kunye" className="hover:text-palette-red">Künye</a>
        <a href="/kurumsal/iletisim" className="hover:text-palette-red">İletişim</a>
        <a href="/kurumsal/gizlilik-politikasi" className="hover:text-palette-red">Gizlilik</a>
      </nav>
      <p className="text-[11px] text-gray-400">
        {t('footer.rights')}
      </p>
    </div>
  );
};

export default Footer;
