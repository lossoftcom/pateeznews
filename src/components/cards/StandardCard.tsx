
import React from 'react';
import { NewsType, type NewsItem } from '@/types';

interface StandardCardProps {
  data: NewsItem;
}

const StandardCard: React.FC<StandardCardProps> = ({ data }) => {
  return (
    <div className="mt-1 space-y-3 overflow-hidden">
      <div className="px-1 mb-3">
        <div
          className="news-subtitle-font rich-text-content text-gray-600/80 text-[16px] leading-relaxed font-medium text-left [&>p]:mb-0"
          dangerouslySetInnerHTML={{ __html: data.summary }}
        />
      </div>
      <div className="relative w-full rounded-[4px] overflow-hidden group flex items-center justify-center">
        <img
          src={data.thumbnail}
          alt={data.thumbnailAlt || data.seoTitle || data.title}
          className="block w-full h-auto object-contain transition-transform duration-1000 group-hover:scale-[1.02]"
        />
      </div>
    </div>
  );
};

export default StandardCard;
