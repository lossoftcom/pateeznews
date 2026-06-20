
import React, { useState } from 'react';
import { NewsType, type NewsItem } from '@/types';
import AnimatedNumber from '../ui/AnimatedNumber';
import { useLanguage } from '@/context/LanguageContext';
import RemixIcon from '@/components/ui/RemixIcon';

interface PollCardProps {
  data: NewsItem;
}

const PollCard: React.FC<PollCardProps> = ({ data }) => {
  const { t } = useLanguage();
  const [hasVoted, setHasVoted] = useState(false);
  const [votedOption, setVotedOption] = useState<string | null>(null);

  const handleVote = (id: string) => {
    if (hasVoted) return;
    setVotedOption(id);
    setHasVoted(true);
  };

  const isImage = data.isImagePoll;
  const columnClass = isImage ? (data.pollColumns === 3 ? 'grid-cols-3' : 'grid-cols-2') : 'grid-cols-1';
  const pollOptions = Array.isArray(data.options) ? data.options : [];
  const hasPollOptions = pollOptions.length > 0;

  return (
    <div className="mt-1 space-y-4 overflow-hidden">
      {/* SUMMARY - Creative Style */}
      <div className="px-1 mb-2">
        <div
          className="news-subtitle-font text-palette-maroon/60 text-[15px] leading-relaxed font-[500] italic [&>p]:m-0"
          dangerouslySetInnerHTML={{ __html: data.summary }}
        />
      </div>

      {/* MAIN POLL CONTAINER */}
      <div
        className="relative bg-gradient-to-br from-palette-beige/10 via-white to-palette-beige/5 rounded-[4px] border border-palette-beige/40 overflow-hidden shadow-sm"
      >

        {/* IMAGE SECTION */}
        {data.thumbnail && (
          <div className="relative w-full overflow-hidden rounded-[4px] group/image">
            <img
              src={(data.optimizedThumbnail?.src || data.thumbnail)?.replace('_sm', '_xl')}
              alt={data.thumbnailAlt || data.seoTitle || data.title}
              className="w-full h-auto object-contain transition-transform duration-[2s] group-hover/image:scale-[1.02]"
            />
            {/* Gradient Overlay */}
            <div className="absolute inset-0 bg-gradient-to-t from-black/50 via-black/10 to-transparent pointer-events-none" />

            {/* Media badges - Bottom Right */}
            <div className="absolute bottom-3 right-3 z-20 flex items-center gap-2 transition-all duration-400 hover:-translate-y-px cursor-default group/badge">
              {!hasPollOptions && (
                <div className="relative flex items-center gap-1.5 overflow-hidden rounded-[3px] bg-black/50 px-2.5 py-[5px] shadow-[0_2px_12px_-2px_rgba(0,0,0,0.3)] backdrop-blur-xl">
                  <RemixIcon name="ri-group-line" size={13} className="relative z-10 text-white/80" />
                  <span className="relative z-10 text-[9.5px] font-[600] leading-none tracking-[0.08em] text-white/85">
                    <AnimatedNumber value={data.totalVotes || 0} suffix="" /> {t('poll.participant_unit')}
                  </span>
                </div>
              )}
              <div className="relative flex items-center gap-1.5 bg-black/50 backdrop-blur-xl px-2.5 py-[5px] rounded-[3px] shadow-[0_2px_12px_-2px_rgba(0,0,0,0.3)] overflow-hidden">
                <div className="absolute inset-0 bg-gradient-to-r from-transparent via-white/[0.08] to-transparent -translate-x-full group-hover/badge:translate-x-full transition-transform duration-[800ms] ease-out pointer-events-none" />
                <RemixIcon name="ri-bar-chart-box-line" size={13} className="text-white/80 relative z-10" />
                <div className="w-px h-3 bg-white/15 relative z-10" />
                <span className="text-[9.5px] font-[600] text-white/85 capitalize tracking-[0.08em] relative z-10 leading-none">
                  {t('poll.badge').charAt(0).toUpperCase() + t('poll.badge').slice(1).toLowerCase()}
                </span>
              </div>
            </div>


          </div>
        )}

        {/* POLL QUESTION TITLE */}
        {(data as any).blockTitle && (
          <div className="px-6 pt-6 pb-4">
            <h3 className="text-[20px] md:text-[24px] font-[900] text-palette-maroon tracking-tight leading-snug">
              {(data as any).blockTitle}
              {(!String((data as any).blockTitle).trim().endsWith('?') && !String((data as any).blockTitle).trim().endsWith('!')) ? '?' : ''}
            </h3>
            {(data as any).blockDescription && (
              <div
                className="mt-2 text-[13px] font-[600] text-palette-tan/60 leading-relaxed [&>p]:m-0"
                dangerouslySetInnerHTML={{ __html: (data as any).blockDescription }}
              />
            )}
          </div>
        )}

        {/* OPTIONS GRID */}
        {hasPollOptions && (
          <div
            className={`card-interact-area px-6 pb-6 ${(data as any).blockTitle ? 'pt-0' : 'pt-6'}`}
            onClick={(e) => {
              e.preventDefault();
              e.stopPropagation();
            }}
            onPointerDown={(e) => e.stopPropagation()}
          >
            <div className={`grid ${columnClass} gap-3`}>
              {pollOptions.map((option, index) => {
              const isSelected = votedOption === option.id;
              const displayTotalVotes = hasVoted ? (data.totalVotes || 0) + 1 : (data.totalVotes || 0);
              const currentOptionVotes = (isSelected && hasVoted) ? (option.votes || 0) + 1 : (option.votes || 0);
              const percentage = displayTotalVotes > 0 ? Math.round((currentOptionVotes / displayTotalVotes) * 100) : 0;

              if (isImage) {
                return (
                  <button
                    key={option.id}
                    disabled={hasVoted}
                    onClick={() => handleVote(option.id)}
                    className={`group relative flex flex-col text-left rounded-[4px] overflow-hidden transition-all duration-400 bg-white border ${hasVoted
                      ? isSelected
                        ? 'ring-2 ring-palette-maroon shadow-lg z-10 border-palette-maroon/40 bg-palette-beige/[0.02]'
                        : 'opacity-40 grayscale-[50%] scale-[0.98] border-palette-beige/30'
                      : 'border-palette-tan/25 shadow-[0_2px_8px_-4px_rgba(0,0,0,0.1)] hover:border-palette-tan/80 hover:shadow-lg hover:-translate-y-[2px] active:scale-[0.98] cursor-pointer'
                      }`}
                  >
                    {/* Hover Accent Line (Top for images) */}
                    {!hasVoted && (
                      <div className="absolute top-0 left-0 right-0 h-[3px] bg-palette-tan/0 group-hover:bg-palette-tan/60 transition-colors duration-400 z-30 pointer-events-none" />
                    )}

                    {/* Image Container - Fixed Height with Blurred Background */}
                    <div className="relative w-full h-[240px] overflow-hidden rounded-t-[4px] border-b border-palette-beige/20">
                      {/* Blurred Background Fill */}
                      <div
                        className="absolute inset-0 bg-center bg-cover blur-2xl opacity-50 scale-110"
                        style={{ backgroundImage: `url(${option.image?.replace('_sm', '_xl')})` }}
                      />
                      {/* Main Image - Object Contain */}
                      <img
                        src={option.image?.replace('_sm', '_xl')}
                        alt={option.text}
                        className={`relative z-10 w-full h-full object-contain transition-transform duration-700 ${!hasVoted ? 'group-hover:scale-105' : ''}`}
                      />

                      {/* Hover Overlay - Before Vote */}
                      {!hasVoted && (
                        <div className="absolute inset-0 z-20 bg-gradient-to-t from-palette-maroon/60 via-transparent to-transparent opacity-0 group-hover:opacity-100 transition-opacity duration-300 flex items-end justify-center pb-4">
                          <span className="text-white text-[10px] font-black uppercase tracking-widest">{t('poll.vote_action')}</span>
                        </div>
                      )}

                      {/* Result Overlay - After Vote */}
                      {hasVoted && (
                        <div className={`absolute inset-0 z-20 flex flex-col items-center justify-center transition-all duration-500 ${isSelected ? 'bg-palette-maroon/70' : 'bg-black/50'}`}>
                          {/* Percentage */}
                          <div className="text-white text-5xl font-[1000] italic tracking-tighter drop-shadow-lg animate-in zoom-in duration-500">
                            <AnimatedNumber value={percentage} suffix="" />%
                          </div>
                          {/* Vote Count */}
                          <div className="text-white/80 text-[11px] font-bold mt-1 animate-in fade-in slide-in-from-bottom-2 duration-700">
                            {currentOptionVotes} {t('poll.vote_unit')}
                          </div>
                          {/* Selected Check */}
                          {isSelected && (
                            <div className="absolute top-3 right-3 w-8 h-8 bg-white text-palette-maroon rounded-full flex items-center justify-center shadow-lg animate-in zoom-in duration-300">
                              <RemixIcon name="ri-check-line" size={20} />
                            </div>
                          )}
                          {/* Progress Bar Inside */}
                          <div className="absolute bottom-0 left-0 right-0 h-1.5 bg-white/20">
                            <div
                              className={`h-full transition-all duration-[1500ms] ease-out ${isSelected ? 'bg-white' : 'bg-white/50'}`}
                              style={{ width: `${percentage}%` }}
                            />
                          </div>
                        </div>
                      )}
                    </div>

                    {/* Option Label */}
                    <div className={`px-4 py-3.5 w-full flex items-center gap-3 transition-colors duration-300 ${hasVoted && isSelected ? 'bg-palette-maroon/5' : 'bg-white'}`}>
                      {/* Radio Circle */}
                      <div className={`w-[18px] h-[18px] rounded-full border-[2px] flex items-center justify-center flex-shrink-0 transition-all duration-300 ${isSelected && hasVoted
                        ? 'border-palette-maroon bg-palette-maroon shadow-sm shadow-palette-maroon/20'
                        : hasVoted
                          ? 'border-palette-beige/50'
                          : 'border-palette-tan/40 group-hover:border-palette-tan group-hover:scale-110 bg-white'
                        }`}>
                        {isSelected && hasVoted && (
                          <div className="w-1.5 h-1.5 bg-white rounded-full animate-in zoom-in duration-200" />
                        )}
                        {!hasVoted && (
                          <div className="w-1 h-1 bg-palette-tan/0 group-hover:bg-palette-tan/30 rounded-full transition-colors duration-300" />
                        )}
                      </div>

                      {/* Text */}
                      <span className={`text-[14px] italic font-[600] text-left block line-clamp-2 leading-snug flex-1 ${isSelected && hasVoted ? 'text-palette-maroon font-[800]' : 'text-palette-maroon/85 group-hover:text-palette-maroon'}`}>
                        {option.text}
                      </span>
                    </div>
                  </button>
                );
              }

              // TEXT OPTIONS
              return (
                <button
                  key={option.id}
                  disabled={hasVoted}
                  onClick={() => handleVote(option.id)}
                  className={`group relative w-full text-left rounded-[4px] transition-all duration-400 bg-white border overflow-hidden ${hasVoted
                    ? isSelected
                      ? 'border-palette-maroon/40 shadow-md bg-palette-beige/[0.02]'
                      : 'border-palette-beige/30 opacity-60'
                    : 'border-palette-tan/25 shadow-[0_2px_8px_-4px_rgba(0,0,0,0.1)] hover:border-palette-tan/80 hover:shadow-md hover:-translate-y-[2px] hover:bg-palette-beige/[0.03] active:scale-[0.98] cursor-pointer'
                    }`}
                >
                  {/* Hover Accent Line */}
                  {!hasVoted && (
                    <div className="absolute left-0 top-0 bottom-0 w-[4px] bg-palette-tan/0 group-hover:bg-palette-tan/60 transition-colors duration-400 z-10" />
                  )}

                  {/* Progress Bar Background */}
                  {hasVoted && (
                    <div
                      className={`absolute left-0 top-0 bottom-0 transition-all duration-[1200ms] ease-out z-0 ${isSelected ? 'bg-palette-maroon/10' : 'bg-palette-beige/40'}`}
                      style={{ width: `${percentage}%` }}
                    />
                  )}

                  {/* Content */}
                  <div className="relative z-10 px-5 py-4 flex items-center justify-between gap-4">
                    <div className="flex items-center gap-4 flex-1">
                      {/* Radio Circle */}
                      <div className={`w-[22px] h-[22px] rounded-full border-2 flex items-center justify-center flex-shrink-0 transition-all duration-300 ${isSelected && hasVoted
                        ? 'border-palette-maroon bg-palette-maroon shadow-sm shadow-palette-maroon/20'
                        : hasVoted
                          ? 'border-palette-beige/50'
                          : 'border-palette-tan/40 group-hover:border-palette-tan group-hover:scale-110 bg-white'
                        }`}>
                        {isSelected && hasVoted && (
                          <div className="w-2 h-2 bg-white rounded-full animate-in zoom-in duration-200" />
                        )}
                        {!hasVoted && (
                          <div className="w-1.5 h-1.5 bg-palette-tan/0 group-hover:bg-palette-tan/30 rounded-full transition-colors duration-300" />
                        )}
                      </div>

                      {/* Option Text */}
                      <span className={`text-[15px] italic font-[600] text-left leading-relaxed tracking-tight transition-colors flex-1 ${isSelected && hasVoted ? 'text-palette-maroon font-[800]' : 'text-palette-maroon/85 group-hover:text-palette-maroon'
                        }`}>
                        {option.text}
                      </span>
                    </div>

                    {/* Percentage, Votes & Check */}
                    {hasVoted && (
                      <div className="flex items-center gap-3 flex-shrink-0">
                        <div className="text-right">
                          <span className={`text-[15px] font-[900] tabular-nums block ${isSelected ? 'text-palette-maroon' : 'text-palette-tan/70'}`}>
                            <AnimatedNumber value={percentage} suffix="%" />
                          </span>
                          <span className="text-[11px] font-[600] text-palette-tan/60">
                            {currentOptionVotes} {t('poll.vote_unit')}
                          </span>
                        </div>
                        {isSelected && (
                          <RemixIcon name="ri-check-line" size={20} className="text-palette-maroon animate-in zoom-in duration-300" />
                        )}
                      </div>
                    )}
                  </div>
                </button>
              );
              })}
            </div>
          </div>
        )}

        {/* FOOTER - Minimal Stats */}
        {hasPollOptions && (
          <div className="px-6 py-4 bg-palette-beige/[0.04] border-t border-palette-beige/20 flex items-center justify-between">
            <div className="flex items-center gap-2 text-palette-tan/50">
              <RemixIcon name="ri-group-line" size={14} />
              <span className="text-[11px] font-[800] tracking-wide">
                <AnimatedNumber value={hasVoted ? (data.totalVotes || 0) + 1 : (data.totalVotes || 0)} suffix="" /> {t('poll.participant_unit')}
              </span>
            </div>
            {hasVoted && (
              <div className="flex items-center gap-1.5 text-emerald-600 animate-in fade-in slide-in-from-right-2 duration-500">
                <RemixIcon name="ri-check-line" size={14} />
                <span className="text-[10px] font-black uppercase tracking-widest">{t('card.vote')}</span>
              </div>
            )}
          </div>
        )}
      </div>
    </div>
  );
};

export default PollCard;
