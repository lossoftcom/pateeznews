
import React, { useEffect, useRef, useState } from 'react';
import { type NewsItem, NewsType, type NavigationItem, type SiteSettings, type PublicAdSettings } from '@/types';
import { useLanguage } from '@/context/LanguageContext';
import { useToast } from '@/context/ToastContext';
import Skeleton from '@/components/ui/Skeleton';
import { hasPostActionSession, postAction } from '@/services/appActions';
import { getPostHref, getPostPathSegment } from '@/utils/postUrl';
import { formatPostDateParts, isPostId } from '@/utils/helpers';
import {
  buildFacebookShareUrl,
  buildShareHashtags,
  buildShareText,
  buildTelegramShareUrl,
  buildTrackedShareUrl,
  buildWhatsAppShareUrl,
  buildXShareUrl,
  isShareAbortError,
  openShareWindow,
  writeToClipboard,
} from '@/utils/socialShare';
import RemixIcon from './ui/RemixIcon';

// Kart bileşenleri
import ReviewCard from './cards/ReviewCard';
import BeforeAfterCard from './cards/BeforeAfterCard';
import FlipCard from './cards/FlipCard';
import EmbedCard from './cards/EmbedCard';
import AudioCard from './cards/AudioCard';
import VideoCard from './cards/VideoCard';
import GalleryCard from './cards/GalleryCard';
import PollCard from './cards/PollCard';
import VSCard from './cards/VSCard';
import ParagraphCard from './cards/ParagraphCard';
import InlineCardComments from './InlineCardComments';
import PublisherFollowButton from './PublisherFollowButton';
import AdSlot from './ads/AdSlot';
import MobileVideoFeedOverlay from './MobileVideoFeedOverlay';

const MOBILE_VIDEO_FEED_EVENT = 'pateez:open-video-feed';

interface NewsDetailProps {
  data: NewsItem;
  onBack: () => void;
  navItems: NavigationItem[];
  siteSettings?: SiteSettings | null;
  adSettings?: PublicAdSettings | null;
  loading?: boolean;
}

type ShareMenuItem = {
  key: string;
  label: string;
  hoverClass: string;
  onClick: () => void | Promise<void>;
  icon?: string;
  iconClass?: string;
  imageSrc?: string;
  imageClass?: string;
  customIcon?: 'tiktok';
};

const NSOSYAL_ICON_SRC = '/images/nsosyal-icon.png';

const TEXT_ENTITY_MAP: Record<string, string> = {
  amp: '&',
  apos: "'",
  Ccedil: 'Ç',
  ccedil: 'ç',
  Gbreve: 'Ğ',
  gbreve: 'ğ',
  hellip: '...',
  Idot: 'İ',
  imath: 'ı',
  laquo: '"',
  ldquo: '"',
  lsquo: "'",
  nbsp: ' ',
  Ouml: 'Ö',
  ouml: 'ö',
  quot: '"',
  raquo: '"',
  rdquo: '"',
  rsquo: "'",
  Scedil: 'Ş',
  scedil: 'ş',
  Uuml: 'Ü',
  uuml: 'ü',
};

const decodeTextCodePoint = (value: string, radix: number, fallback: string) => {
  const codePoint = Number.parseInt(value, radix);
  if (!Number.isFinite(codePoint) || codePoint <= 0) return fallback;
  try {
    return String.fromCodePoint(codePoint);
  } catch {
    return fallback;
  }
};

const stripHtmlToText = (html: string) => {
  const decodeOnce = (input: string) => input
    .replace(/&([a-zA-Z][a-zA-Z0-9]+);/g, (match, entity: string) => TEXT_ENTITY_MAP[entity] ?? match)
    .replace(/&#x([0-9a-fA-F]+);/g, (match, hex: string) => decodeTextCodePoint(hex, 16, match))
    .replace(/&#(\d+);/g, (match, decimal: string) => decodeTextCodePoint(decimal, 10, match));

  return decodeOnce(decodeOnce(String(html || '').replace(/<[^>]*>?/gm, ' ').replace(/&nbsp;/g, ' ')))
    .replace(/\s+/g, ' ')
    .trim();
};

const withImageVariant = (src: string | null | undefined, width: number, quality = 86) => {
  const raw = String(src || '').trim();
  if (!raw || width <= 0 || raw.startsWith('data:')) return raw;
  try {
    const placeholderOrigin = 'https://pateez.local';
    const parsed = new URL(raw, placeholderOrigin);
    const isLocal =
      parsed.pathname.startsWith('/api/storage/file/') ||
      parsed.pathname.startsWith('/local-upload/');
    if (!isLocal) return raw.replace('_sm', '_xl');
    parsed.searchParams.set('w', String(Math.min(Math.max(Math.round(width), 64), 3840)));
    parsed.searchParams.set('q', String(Math.min(Math.max(Math.round(quality), 40), 95)));
    return raw.startsWith('http://') || raw.startsWith('https://')
      ? parsed.toString()
      : `${parsed.pathname}${parsed.search}${parsed.hash}`;
  } catch {
    return raw.replace('_sm', '_xl');
  }
};

const imageSizeAttrs = (image?: { width?: number; height?: number }, fallbackWidth = 1200, fallbackHeight = 675) => {
  const width = Number(image?.width || 0);
  const height = Number(image?.height || 0);
  if (Number.isFinite(width) && Number.isFinite(height) && width > 0 && height > 0) {
    return { width, height };
  }
  return { width: fallbackWidth, height: fallbackHeight };
};

const profileHref = (handle?: string) => {
  const clean = String(handle || '').trim().replace(/^@+/, '');
  return clean ? `/profil/${encodeURIComponent(clean)}` : '';
};

const titleCaseText = (value: string) => {
  const lower = String(value || '').trim().toLocaleLowerCase('tr-TR');
  if (!lower) return lower;
  let result = '';
  let capitalizeNext = true;
  for (const char of lower) {
    if (char === ' ' || char === '\t' || char === '\n' || char === '/' || char === '-' || char === '_' || char === '.') {
      capitalizeNext = true;
      result += char;
      continue;
    }
    result += capitalizeNext ? char.toLocaleUpperCase('tr-TR') : char;
    capitalizeNext = false;
  }
  return result;
};

const normalizeCategoryLabel = (value: unknown) => String(value || '').trim();

const normalizeCategoryKey = (value: unknown) => (
  normalizeCategoryLabel(value).toLocaleLowerCase('tr-TR')
);

const uniqueCategoryLabels = (values: unknown[]) => {
  const seen = new Set<string>();
  const labels: string[] = [];
  values.forEach((value) => {
    const label = normalizeCategoryLabel(value);
    const key = normalizeCategoryKey(label);
    if (!label || seen.has(key)) return;
    seen.add(key);
    labels.push(label);
  });
  return labels;
};

const getStoredCategoryHierarchy = (data: NewsItem) => {
  const rawTrail = Array.isArray(data.categoryTrail)
    ? data.categoryTrail
    : Array.isArray(data.categoryPath)
      ? data.categoryPath
      : [];
  if (rawTrail.length === 0) return [];
  return uniqueCategoryLabels([...rawTrail, data.category]);
};

const resolveCategoryNavItem = (category: string, navItems: NavigationItem[]) => {
  const categoryKey = normalizeCategoryKey(category);
  if (!categoryKey) return undefined;

  const matches = navItems.filter((item) => (
    normalizeCategoryKey(item.value) === categoryKey ||
    normalizeCategoryKey(item.label) === categoryKey
  ));
  if (matches.length <= 1) return matches[0];

  const itemById = new Map(navItems.map((item) => [item.id, item]));
  const isDistrictChild = (item: NavigationItem) => {
    if (!item.parent_id || item.parent_id === 'root') return false;
    return itemById.get(item.parent_id)?.type === 'district';
  };

  return [...matches].sort((a, b) => Number(isDistrictChild(a)) - Number(isDistrictChild(b)))[0];
};

const buildNavigationCategoryHierarchy = (category: string, navItems: NavigationItem[]) => {
  const currentItem = resolveCategoryNavItem(category, navItems);
  if (!currentItem) return uniqueCategoryLabels([category]);

  const itemById = new Map(navItems.map((item) => [item.id, item]));
  const hierarchy: string[] = [];
  const seen = new Set<string>();
  let item: NavigationItem | undefined = currentItem;

  while (item && !seen.has(item.id)) {
    seen.add(item.id);
    hierarchy.unshift(item.label);
    item = item.parent_id && item.parent_id !== 'root'
      ? itemById.get(item.parent_id)
      : undefined;
  }

  return hierarchy.length > 0 ? uniqueCategoryLabels(hierarchy) : uniqueCategoryLabels([category]);
};

const REACTION_ASSET_BASE = '/admin/assets/assets/images/reactions';

type QuizImageOrientation = 'unknown' | 'portrait' | 'wide';
type LoadedQuizImageOrientation = Exclude<QuizImageOrientation, 'unknown'>;

const QuizQuestionImage: React.FC<{ src: string; alt: string }> = ({ src, alt }) => {
  const [orientation, setOrientation] = useState<QuizImageOrientation>('unknown');

  useEffect(() => {
    setOrientation('unknown');
  }, [src]);

  const handleLoad = (event: React.SyntheticEvent<HTMLImageElement>) => {
    const { naturalWidth, naturalHeight } = event.currentTarget;
    if (!naturalWidth || !naturalHeight) {
      setOrientation('wide');
      return;
    }
    setOrientation(naturalHeight > naturalWidth ? 'portrait' : 'wide');
  };

  const wrapperClass = orientation === 'portrait'
    ? 'mt-4 flex h-[400px] w-full items-center justify-center overflow-hidden rounded-[4px] border border-gray-100 bg-gray-50'
    : orientation === 'wide'
      ? 'mt-4 w-full overflow-hidden rounded-[4px] border border-gray-100 bg-gray-50'
      : 'relative mt-4 h-64 w-full overflow-hidden rounded-[4px] border border-gray-100 bg-gray-50';
  const imageClass = orientation === 'portrait'
    ? 'h-full w-auto max-w-full object-contain object-center'
    : orientation === 'wide'
      ? 'block h-auto w-full object-contain object-center'
      : 'absolute inset-0 h-full w-full object-contain opacity-0';

  return (
    <div className={wrapperClass}>
      {orientation === 'unknown' && <div className="h-full w-full animate-pulse bg-gray-100" />}
      <img
        src={src}
        alt={alt}
        loading="lazy"
        decoding="async"
        onLoad={handleLoad}
        onError={() => setOrientation('wide')}
        className={imageClass}
      />
    </div>
  );
};

const QuizAnswerImage: React.FC<{
  src: string;
  alt: string;
  answerIndex: number;
  hasPortraitInGroup: boolean;
  isMarked: boolean;
  onOrientation: (orientation: LoadedQuizImageOrientation) => void;
}> = ({ src, alt, answerIndex, hasPortraitInGroup, isMarked, onOrientation }) => {
  const [orientation, setOrientation] = useState<QuizImageOrientation>('unknown');

  useEffect(() => {
    setOrientation('unknown');
  }, [src]);

  const handleLoad = (event: React.SyntheticEvent<HTMLImageElement>) => {
    const { naturalWidth, naturalHeight } = event.currentTarget;
    const nextOrientation: LoadedQuizImageOrientation = naturalHeight > naturalWidth ? 'portrait' : 'wide';
    setOrientation(nextOrientation);
    onOrientation(nextOrientation);
  };

  const frameHeightClass = hasPortraitInGroup ? 'h-[200px]' : 'h-[150px]';
  const imageClass = orientation === 'portrait'
    ? 'h-full w-auto max-w-full object-contain object-center transition-transform duration-300 group-hover/answer:scale-[1.02]'
    : orientation === 'wide'
      ? 'h-auto max-h-full w-full object-contain object-center transition-transform duration-300 group-hover/answer:scale-[1.02]'
      : 'absolute inset-0 h-full w-full object-contain opacity-0';

  return (
    <div className={`relative flex ${frameHeightClass} w-full items-center justify-center overflow-hidden rounded-[4px] border border-gray-100 bg-gray-50`}>
      {orientation === 'unknown' && <div className="h-full w-full animate-pulse bg-gray-100" />}
      <img
        src={src}
        alt={alt}
        loading="lazy"
        decoding="async"
        onLoad={handleLoad}
        onError={() => {
          setOrientation('wide');
          onOrientation('wide');
        }}
        className={imageClass}
      />
      <span className="detail-quiz-image-answer-badge hidden">
        {String.fromCharCode(65 + (answerIndex % 26))}
      </span>
      <span className={`detail-quiz-answer-check absolute top-2 right-2 w-7 h-7 rounded-full border bg-white/90 backdrop-blur flex items-center justify-center shadow-sm ${isMarked ? 'border-current text-current' : 'border-gray-200 text-transparent'}`}>
        {isMarked && <RemixIcon name="ri-check-line" size={15} />}
      </span>
    </div>
  );
};

const compactCount = (value: unknown) => {
  const number = Number(value);
  const safe = Number.isFinite(number) ? Math.max(0, Math.round(number)) : 0;
  try {
    return new Intl.NumberFormat('tr-TR', {
      notation: 'compact',
      maximumFractionDigits: 1,
    }).format(safe);
  } catch {
    return String(safe);
  }
};

const normalizedOptionImage = (option: any) => String(
  option?.image || option?.imageUrl || option?.mediaUrl || option?.thumbnail || ''
).trim();

const normalizedOptionText = (option: any, fallback: string) => String(
  option?.text || option?.label || option?.title || fallback
).trim();

const normalizedOptionVotes = (option: any) => {
  const votes = Number(option?.votes ?? option?.voteCount ?? option?.count ?? 0);
  return Number.isFinite(votes) ? Math.max(0, Math.round(votes)) : 0;
};

const pollPercent = (votes: number, totalVotes: number) => {
  if (totalVotes <= 0 || votes <= 0) return 0;
  return Math.max(0, Math.min(100, Math.round((votes / totalVotes) * 100)));
};

const DetailPollItemBlock: React.FC<{ item: any }> = ({ item }) => {
  const rawOptions = Array.isArray(item?.options)
    ? item.options
    : Array.isArray(item?.pollData?.options)
      ? item.pollData.options
      : [];
  const options = rawOptions.map((option: any, index: number) => ({
    id: String(option?.id || `detail-poll-option-${index}`),
    text: normalizedOptionText(option, `${index + 1}. seçenek`),
    image: normalizedOptionImage(option),
    votes: normalizedOptionVotes(option),
  }));
  const [selectedOptionId, setSelectedOptionId] = useState<string | null>(null);

  useEffect(() => {
    setSelectedOptionId(null);
  }, [item?.id]);

  const baseTotalVotes = Number(item?.totalVotes ?? item?.pollData?.totalVotes);
  const resolvedBaseTotal = Number.isFinite(baseTotalVotes)
    ? Math.max(0, Math.round(baseTotalVotes))
    : options.reduce((total: number, option: any) => total + option.votes, 0);
  const hasVoted = selectedOptionId !== null;
  const totalVotes = resolvedBaseTotal + (hasVoted ? 1 : 0);
  const isImagePoll = Boolean(item?.isImagePoll || item?.pollData?.isImagePoll || options.some((option: any) => option.image));
  const pollColumns = Number(item?.pollColumns || item?.pollData?.columns) === 3 ? 3 : 2;
  const title = String(item?.title || item?.blockTitle || item?.pollData?.title || '').trim();
  const question = String(item?.question || item?.questionTitle || item?.pollData?.question || '').trim();
  const visibleQuestion = question && question !== title ? question : '';
  const description = String(item?.description || item?.blockDescription || item?.pollData?.description || '').trim();

  return (
    <section className={`detail-poll-block ${isImagePoll ? 'detail-poll-block--image' : 'detail-poll-block--list'}`}>
      <div className="detail-poll-header">
        <span className="detail-poll-header-icon">
          <RemixIcon name="ri-apps-2-fill" size={18} />
        </span>
        <span className="detail-poll-header-copy">
          <strong>Anket</strong>
          <small>{options.length} seçenek · {compactCount(totalVotes)} katılımcı</small>
        </span>
        <span className={`detail-poll-pill ${hasVoted ? 'is-complete' : ''}`}>{hasVoted ? 'Sonuçlar' : 'Oy ver'}</span>
      </div>

      {title && <h3 className="detail-poll-title">{title}</h3>}
      {visibleQuestion && <h4 className="detail-poll-question">{visibleQuestion}</h4>}
      {description && (
        <div
          className="detail-poll-description rich-text-content"
          dangerouslySetInnerHTML={{ __html: description }}
        />
      )}

      <div className="detail-poll-progress-panel">
        <RemixIcon name={hasVoted ? 'ri-check-line' : 'ri-cursor-line'} size={15} />
        <span>{hasVoted ? 'Sonuçlar oyunla birlikte açıldı' : 'Sonuçları görmek için bir seçeneğe oy ver'}</span>
        <strong>{compactCount(totalVotes)} oy</strong>
      </div>

      {isImagePoll ? (
        <div className={`detail-poll-image-grid detail-poll-image-grid--${pollColumns}`}>
          {options.map((option: any, index: number) => {
            const selected = selectedOptionId === option.id;
            const optionVotes = option.votes + (selected && hasVoted ? 1 : 0);
            const percent = pollPercent(optionVotes, totalVotes);
            return (
              <button
                key={option.id}
                type="button"
                disabled={hasVoted}
                onClick={() => setSelectedOptionId(option.id)}
                className={`detail-poll-image-option ${selected ? 'is-selected' : ''} ${hasVoted && !selected ? 'is-muted' : ''}`}
              >
                <span className="detail-poll-option-visual">
                  {option.image ? (
                    <img src={option.image} alt={option.text} loading="lazy" decoding="async" />
                  ) : (
                    <span className="detail-poll-option-fallback">
                      <RemixIcon name="ri-image-line" size={20} />
                    </span>
                  )}
                  <span className="detail-poll-option-badge">{index + 1}</span>
                  <span className="detail-poll-percent-badge">%{hasVoted ? percent : 0}</span>
                </span>
                <span className="detail-poll-image-label">{option.text}</span>
                {hasVoted && (
                  <span className="detail-poll-image-result">
                    <i style={{ width: `${percent}%` }} />
                    <small>{compactCount(optionVotes)} oy</small>
                  </span>
                )}
              </button>
            );
          })}
        </div>
      ) : (
        <div className="detail-poll-list-options">
          {options.map((option: any, index: number) => {
            const selected = selectedOptionId === option.id;
            const optionVotes = option.votes + (selected && hasVoted ? 1 : 0);
            const percent = pollPercent(optionVotes, totalVotes);
            return (
              <button
                key={option.id}
                type="button"
                disabled={hasVoted}
                onClick={() => setSelectedOptionId(option.id)}
                className={`detail-poll-list-option ${selected ? 'is-selected' : ''} ${hasVoted && !selected ? 'is-muted' : ''}`}
              >
                {hasVoted && <span className="detail-poll-list-progress" style={{ width: `${percent}%` }} />}
                <span className="detail-poll-option-badge">{index + 1}</span>
                <span className="detail-poll-list-label">{option.text}</span>
                {hasVoted && (
                  <span className="detail-poll-result-text">
                    <strong>%{percent}</strong>
                    <small>{compactCount(optionVotes)} oy</small>
                  </span>
                )}
              </button>
            );
          })}
        </div>
      )}
    </section>
  );
};

const quizTypeLabel = (value: string) => {
  switch (value.trim().toLowerCase()) {
    case 'trivia':
      return 'Bilgi yarışması';
    case 'checklist':
      return 'Kontrol listesi';
    default:
      return 'Kişilik testi';
  }
};

const normalizedDetailItemType = (item: any) => String(item?.type || '').trim().toLowerCase();

const detailItemTitleText = (item: any) => String(item?.title || '').trim();

const detailItemDescriptionHtml = (item: any) => String(item?.description || '').trim();

const shouldShowDetailItemTitle = (item: any) => {
  const type = normalizedDetailItemType(item);
  return !!detailItemTitleText(item) && type !== 'quote' && type !== 'paragraph' && type !== 'review';
};

const isDetailItemDescriptionInsideMedia = (item: any) => {
  const type = normalizedDetailItemType(item);
  return type === 'review' || type === 'quote';
};

const shouldShowDetailItemDescriptionBeforeMedia = (item: any) => (
  !!detailItemDescriptionHtml(item) && !isDetailItemDescriptionInsideMedia(item)
);

const sourceText = (source: string, moreInfoUrl: string) => {
  const cleanSource = source.trim();
  const cleanUrl = moreInfoUrl.trim();
  if (cleanSource && cleanUrl) return `${cleanSource} · Daha fazla bilgi`;
  return cleanSource || cleanUrl;
};

const sourceHref = (value: string) => {
  const raw = String(value || '').trim();
  if (!raw || /\s/.test(raw)) return '';
  try {
    const parsed = new URL(raw);
    return parsed.protocol === 'http:' || parsed.protocol === 'https:' ? parsed.toString() : '';
  } catch {
    if (raw.startsWith('www.') || /^[a-z0-9-]+(\.[a-z0-9-]+)+/i.test(raw)) {
      try {
        return new URL(`https://${raw}`).toString();
      } catch {
        return '';
      }
    }
    return '';
  }
};

const hasDetailItemExtraInfo = (item: any) => (
  !!String(item?.altText || '').trim() ||
  !!String(item?.source || '').trim() ||
  !!String(item?.moreInfoUrl || '').trim()
);

const DetailMediaIntro: React.FC<{ item: any }> = ({ item }) => {
  const title = shouldShowDetailItemTitle(item) ? detailItemTitleText(item) : '';
  const description = shouldShowDetailItemDescriptionBeforeMedia(item)
    ? detailItemDescriptionHtml(item)
    : '';

  if (!title && !description) return null;

  return (
    <div className="detail-media-intro">
      {title && <h3 className="detail-media-title">{title}</h3>}
      {description && (
        <div
          className="detail-media-description rich-text-content"
          dangerouslySetInnerHTML={{ __html: description }}
        />
      )}
    </div>
  );
};

const DetailItemExtraInfo: React.FC<{ item: any }> = ({ item }) => {
  if (!hasDetailItemExtraInfo(item)) return null;

  const altText = String(item?.altText || '').trim();
  const source = String(item?.source || '').trim();
  const moreInfoUrl = String(item?.moreInfoUrl || '').trim();
  const infoText = sourceText(source, moreInfoUrl);
  const href = sourceHref(moreInfoUrl || source);

  return (
    <div className="detail-media-extra">
      {altText && <p>{altText}</p>}
      {infoText && (
        href ? (
          <a href={href} target="_blank" rel="noreferrer">{infoText}</a>
        ) : (
          <p>{infoText}</p>
        )
      )}
    </div>
  );
};

const QuizBlock: React.FC<{ item: any }> = ({ item }) => {
  const quizData = item?.quizData || {};
  const questionsRaw = Array.isArray(quizData.questions) ? quizData.questions : [];
  const results = Array.isArray(quizData.results) ? quizData.results : [];
  const quizType = String(quizData.quizType || 'personality').toLowerCase();
  const allowMultiple = !!quizData.allowMultiple;
  const showResults = quizData.showResults !== false;
  const [selectedAnswers, setSelectedAnswers] = useState<Record<string, string[]>>({});
  const [answerImageOrientations, setAnswerImageOrientations] = useState<Record<string, LoadedQuizImageOrientation>>({});

  useEffect(() => {
    setAnswerImageOrientations({});
  }, [item?.id]);

  const questions = React.useMemo(() => {
    const normalized = questionsRaw.map((question: any, index: number) => ({
      ...question,
      id: String(question?.id || `quiz-question-${index}`),
      answers: Array.isArray(question?.answers)
        ? question.answers.map((answer: any, answerIndex: number) => ({
          ...answer,
          id: String(answer?.id || `quiz-answer-${index}-${answerIndex}`),
        }))
        : [],
    }));
    if (quizData.questionSorting === 'desc') return [...normalized].reverse();
    return normalized;
  }, [questionsRaw, quizData.questionSorting]);

  const toggleAnswer = (questionId: string, answerId: string) => {
    setSelectedAnswers((prev) => {
      const current = prev[questionId] || [];
      const next = allowMultiple
        ? (current.includes(answerId) ? current.filter((id) => id !== answerId) : [...current, answerId])
        : [answerId];
      return { ...prev, [questionId]: next };
    });
  };

  const registerAnswerImageOrientation = React.useCallback((imageKey: string, orientation: LoadedQuizImageOrientation) => {
    setAnswerImageOrientations((prev) => (
      prev[imageKey] === orientation ? prev : { ...prev, [imageKey]: orientation }
    ));
  }, []);

  const score = questions.reduce((total: number, question: any) => {
    const selected = selectedAnswers[question.id] || [];
    if (quizType === 'trivia') {
      const correctIds = (question.answers || []).filter((answer: any) => !!answer.isCorrect).map((answer: any) => answer.id);
      if (selected.length === 0 || correctIds.length === 0) return total;
      const isExact = selected.every((id) => correctIds.includes(id)) && correctIds.every((id: string) => selected.includes(id));
      return total + (isExact ? 1 : 0);
    }
    return total + selected.length;
  }, 0);

  const selectedResult = React.useMemo(() => {
    if (results.length === 0) return null;

    if (quizType === 'personality') {
      const counts: Record<string, number> = {};
      questions.forEach((question: any) => {
        const selected = selectedAnswers[question.id] || [];
        selected.forEach((answerId) => {
          const answer = (question.answers || []).find((candidate: any) => candidate.id === answerId);
          if (answer?.resultId) counts[answer.resultId] = (counts[answer.resultId] || 0) + 1;
        });
      });
      const bestId = Object.entries(counts).sort((a, b) => b[1] - a[1])[0]?.[0];
      return results.find((result: any) => result.id === bestId) || results[0];
    }

    return results.find((result: any) => {
      const hasMinScore = result?.minScore !== undefined && result?.minScore !== null && result?.minScore !== '';
      const hasMaxScore = result?.maxScore !== undefined && result?.maxScore !== null && result?.maxScore !== '';
      const hasAnswerCount = result?.answerCount !== undefined && result?.answerCount !== null && result?.answerCount !== '';
      const minScore = hasMinScore && Number.isFinite(Number(result?.minScore)) ? Number(result.minScore) : 0;
      const maxScore = hasMaxScore && Number.isFinite(Number(result?.maxScore)) ? Number(result.maxScore) : questions.length;
      const answerCount = hasAnswerCount && Number.isFinite(Number(result?.answerCount)) ? Number(result.answerCount) : null;
      if (!hasMinScore && !hasMaxScore && answerCount !== null) return score === answerCount;
      return score >= minScore && score <= maxScore;
    }) || results[results.length - 1];
  }, [questions, quizType, results, score, selectedAnswers]);

  const answeredCount = questions.filter((question: any) => (selectedAnswers[question.id] || []).length > 0).length;
  const canShowResult = showResults && questions.length > 0 && answeredCount === questions.length;

  if (questions.length === 0) {
    return (
      <div key={item.id} className="detail-quiz-empty space-y-5 p-6 md:p-8 rounded-[5px] border border-palette-beige/60 bg-palette-beige/10">
        {item.title && <h3 className="text-2xl md:text-3xl font-black text-gray-900 tracking-tight">{item.title}</h3>}
        {item.description && <div className="rich-text-content text-sm font-bold text-palette-tan/70" dangerouslySetInnerHTML={{ __html: item.description }} />}
        <div className="grid gap-3">
          {(item.options || []).map((option: any, optionIndex: number) => (
            <div key={option.id || optionIndex} className="flex items-center gap-3 rounded-[5px] border border-palette-beige bg-white px-4 py-3">
              <span className="w-7 h-7 rounded-[5px] bg-palette-beige/60 text-palette-tan flex items-center justify-center text-[11px] font-black">
                {optionIndex + 1}
              </span>
              <span className="text-sm font-bold text-gray-800">{option.text || option.label || option.title}</span>
            </div>
          ))}
        </div>
      </div>
    );
  }

  return (
    <div key={item.id} className="detail-quiz-block space-y-7">
      <div className="detail-quiz-header md:hidden">
        <span className="detail-quiz-header-icon">
          <RemixIcon name="ri-flashlight-fill" size={18} />
        </span>
        <span className="detail-quiz-header-copy">
          <strong>Test</strong>
          <small>{quizTypeLabel(quizType)} · {questions.length} soru · {results.length} sonuç</small>
        </span>
        <span className={`detail-quiz-pill ${canShowResult ? 'is-complete' : ''}`}>{canShowResult ? 'Sonuç hazır' : `${answeredCount}/${questions.length}`}</span>
      </div>

      <div className="detail-quiz-intro space-y-3 px-1">
        {item.title && <h3 className="text-2xl md:text-3xl font-black text-gray-900 tracking-tight">{item.title}</h3>}
        {item.description && <div className="rich-text-content text-sm md:text-base font-bold text-palette-tan/75 leading-relaxed" dangerouslySetInnerHTML={{ __html: item.description }} />}
      </div>

      <div className="detail-quiz-progress-panel md:hidden">
        <span>
          <RemixIcon name={canShowResult ? 'ri-check-line' : 'ri-lock-line'} size={13} />
        </span>
        <strong>{canShowResult ? 'Tüm cevaplar tamamlandı' : 'Sonucu görmek için soruları cevapla'}</strong>
        <small>%{questions.length > 0 ? Math.round((answeredCount / questions.length) * 100) : 0}</small>
        <i>
          {questions.map((question: any) => (
            <b key={`progress-${question.id}`} className={(selectedAnswers[question.id] || []).length > 0 ? 'is-filled' : ''} />
          ))}
        </i>
      </div>

      <div className="detail-quiz-section-label md:hidden">Sorular</div>

      <div className="detail-quiz-questions space-y-6">
        {questions.map((question: any, questionIndex: number) => {
          const selected = selectedAnswers[question.id] || [];
          const reveal = canShowResult && quizType === 'trivia';
          const layout = question.layout === 'grid3' ? 'grid-cols-3 md:grid-cols-3' : question.layout === 'grid2' ? 'grid-cols-2 md:grid-cols-2' : 'grid-cols-1';
          const hasPortraitAnswerImage = (question.answers || []).some((answer: any) => (
            !!answer.image && answerImageOrientations[`${question.id}:${answer.id}`] === 'portrait'
          ));
          const correctAnswerExplanations = reveal
            ? (question.answers || [])
              .filter((answer: any) => !!answer.isCorrect)
              .map((answer: any) => String(answer?.explanation || answer?.correctExplanation || '').trim())
              .filter((explanation: string) => explanation.length > 0)
            : [];
          return (
            <div key={question.id} className={`detail-quiz-question-card rounded-[5px] border border-gray-200 bg-white p-4 md:p-5 shadow-sm ${selected.length > 0 ? 'is-answered' : ''}`}>
              <div className="flex items-start gap-3 md:gap-4">
                {quizData.questionSorting !== 'hidden' && (
                  <span className="detail-quiz-question-number w-9 h-9 shrink-0 rounded-[5px] bg-gray-900 text-white flex items-center justify-center text-sm font-black">
                    {quizData.questionSorting === 'desc' ? questions.length - questionIndex : questionIndex + 1}
                  </span>
                )}
                <div className="min-w-0 flex-1">
                  <h4 className="detail-quiz-question-title text-lg md:text-xl font-black text-gray-900 leading-snug">{question.title}</h4>
                  {question.description && <div className="detail-quiz-question-description rich-text-content mt-2 text-sm font-medium text-gray-500" dangerouslySetInnerHTML={{ __html: question.description }} />}
                </div>
              </div>

              {question.image && <QuizQuestionImage src={question.image} alt={stripHtmlToText(question.title || '')} />}

              <div className={`detail-quiz-answer-grid mt-5 grid ${layout} gap-4`}>
                {(question.answers || []).map((answer: any, answerIndex: number) => {
                  const isSelected = selected.includes(answer.id);
                  const hasImage = !!answer.image;
                  const correctnessClass = reveal && answer.isCorrect
                    ? 'border-palette-red bg-palette-red/5 text-palette-red ring-1 ring-palette-red/10'
                    : reveal && isSelected && !answer.isCorrect
                      ? 'border-palette-accent bg-palette-accent/10 text-palette-maroon ring-1 ring-palette-accent/20'
                      : isSelected
                        ? 'border-gray-900 bg-white text-gray-900 ring-2 ring-gray-900/10 shadow-md'
                        : 'border-palette-beige bg-white text-gray-800 hover:border-gray-300 hover:bg-gray-50 hover:shadow-md';
                  const answerButtonClass = hasImage
                    ? `detail-quiz-answer detail-quiz-answer--image group/answer relative overflow-hidden rounded-[4px] border p-1.5 text-left transition-all duration-200 hover:-translate-y-0.5 ${isSelected ? 'is-selected' : ''} ${correctnessClass}`
                    : `detail-quiz-answer detail-quiz-answer--text flex items-center gap-3 rounded-[4px] border px-4 py-3 text-left transition-all duration-200 ${isSelected ? 'is-selected' : ''} ${correctnessClass}`;

                  return (
                    <button
                      key={answer.id}
                      type="button"
                      onClick={() => toggleAnswer(question.id, answer.id)}
                      className={answerButtonClass}
                    >
                      {hasImage ? (
                        <>
	                          <QuizAnswerImage
	                            src={answer.image}
	                            alt={stripHtmlToText(answer.text || '')}
	                            answerIndex={answerIndex}
	                            hasPortraitInGroup={hasPortraitAnswerImage}
	                            isMarked={isSelected || (reveal && answer.isCorrect)}
	                            onOrientation={(orientation) => registerAnswerImageOrientation(`${question.id}:${answer.id}`, orientation)}
                          />
                          <span className="block px-2.5 pt-3 pb-2 text-[13px] md:text-sm font-semibold leading-snug text-current">
                            {answer.text}
                          </span>
                        </>
                      ) : (
                        <>
	                          <span data-letter={String.fromCharCode(65 + (answerIndex % 26))} className={`detail-quiz-answer-choice w-6 h-6 shrink-0 rounded-full border flex items-center justify-center ${isSelected || (reveal && answer.isCorrect) ? 'border-current' : 'border-gray-200'}`}>
	                            {(isSelected || (reveal && answer.isCorrect)) && <RemixIcon name="ri-check-line" size={14} />}
	                          </span>
                          <span className="text-sm font-semibold leading-snug">{answer.text}</span>
                        </>
                      )}
                    </button>
                  );
                })}
              </div>

              {correctAnswerExplanations.length > 0 && (
                <div className="detail-quiz-explanation mt-4 rounded-[4px] border border-palette-red/15 bg-palette-red/5 px-4 py-3">
                  <p className="text-[10px] font-black uppercase tracking-widest text-palette-red/70">Cevap sonrası açıklama</p>
                  <div className="mt-2 space-y-2">
                    {correctAnswerExplanations.map((explanation: string, explanationIndex: number) => (
                      <div
                        key={`${question.id}-explanation-${explanationIndex}`}
                        className="rich-text-content text-sm font-semibold leading-relaxed text-gray-700"
                        dangerouslySetInnerHTML={{ __html: explanation }}
                      />
                    ))}
                  </div>
                </div>
              )}
            </div>
          );
        })}
      </div>

      {showResults && (
        <div className="detail-quiz-result rounded-[5px] border border-gray-200 bg-white p-5 md:p-6">
          {canShowResult && selectedResult ? (
            <div className="grid gap-5 md:grid-cols-[180px_1fr] items-center">
              {selectedResult.image && <img src={selectedResult.image} alt={stripHtmlToText(selectedResult.title || '')} className="w-full max-h-[180px] rounded-[5px] object-cover bg-gray-50" />}
              <div className="space-y-3">
                <div className="inline-flex items-center gap-2 rounded-full bg-gray-100 px-3 py-1 text-[10px] font-black uppercase tracking-widest text-gray-500">
                  {quizType === 'trivia' ? `${score}/${questions.length}` : `${answeredCount}/${questions.length}`}
                </div>
                <h4 className="text-2xl md:text-3xl font-black text-gray-900">{selectedResult.title}</h4>
                {selectedResult.description && <div className="rich-text-content text-sm md:text-base font-medium text-gray-600" dangerouslySetInnerHTML={{ __html: selectedResult.description }} />}
              </div>
            </div>
          ) : (
            <p className="text-center text-xs font-black uppercase tracking-widest text-palette-tan/50">
              Sonucunu görmek için tüm soruları cevapla.
            </p>
          )}
        </div>
      )}
    </div>
  );
};

const toRoman = (value: number) => {
  const pairs: Array<[number, string]> = [
    [1000, 'm'], [900, 'cm'], [500, 'd'], [400, 'cd'], [100, 'c'],
    [90, 'xc'], [50, 'l'], [40, 'xl'], [10, 'x'], [9, 'ix'], [5, 'v'], [4, 'iv'], [1, 'i'],
  ];
  let remaining = Math.max(1, Math.floor(value));
  let output = '';
  pairs.forEach(([amount, symbol]) => {
    while (remaining >= amount) {
      output += symbol;
      remaining -= amount;
    }
  });
  return output;
};

const toAlpha = (value: number) => {
  let number = Math.max(1, Math.floor(value));
  let output = '';
  while (number > 0) {
    number -= 1;
    output = String.fromCharCode(97 + (number % 26)) + output;
    number = Math.floor(number / 26);
  }
  return output;
};

const markerForStyle = (style: string, orderNumber: number) => {
  switch (style) {
    case 'decimal':
      return String(orderNumber);
    case 'decimal-leading-zero':
      return String(orderNumber).padStart(2, '0');
    case 'lower-alpha':
      return toAlpha(orderNumber);
    case 'upper-alpha':
      return toAlpha(orderNumber).toUpperCase();
    case 'lower-roman':
      return toRoman(orderNumber);
    case 'upper-roman':
      return toRoman(orderNumber).toUpperCase();
    case 'circle':
      return '○';
    case 'square':
      return '▪';
    case 'disc':
      return '•';
    default:
      return '';
  }
};

const TableOfContentsBlock: React.FC<{ item: any }> = ({ item }) => {
  const { t } = useLanguage();
  const tocData = item?.tocData || {};
  const linkStyle = {
    level1: 'none',
    level2: 'none',
    level3: 'none',
    showLevel1InText: false,
    showLevel2InText: false,
    showLevel3InText: false,
    ...(tocData.linkListStyle || {}),
  };
  const items = Array.isArray(tocData.items)
    ? tocData.items
      .map((entry: any, entryIndex: number) => ({
        id: String(entry?.id || `toc-${entryIndex}`),
        orderNumber: Number(entry?.orderNumber) || entryIndex + 1,
        title: String(entry?.title || '').trim(),
        parentLink: String(entry?.parentLink || '').trim(),
        image: String(entry?.image || '').trim(),
        imageDescription: String(entry?.imageDescription || '').trim(),
        content: String(entry?.content || ''),
      }))
      .filter((entry: any) => entry.title || entry.content || entry.image)
      .sort((a: any, b: any) => a.orderNumber - b.orderNumber)
    : [];

  const orderKeys = new Set(items.map((entry: any) => String(entry.orderNumber)));
  const childrenByParent = items.reduce((map: Map<string, any[]>, entry: any) => {
    const parentKey = orderKeys.has(entry.parentLink) ? entry.parentLink : '';
    map.set(parentKey, [...(map.get(parentKey) || []), entry]);
    return map;
  }, new Map<string, any[]>());
  const itemByOrder = new Map(items.map((entry: any) => [String(entry.orderNumber), entry]));
  const levelCache = new Map<string, number>();

  const getLevel = (entry: any): 1 | 2 | 3 => {
    if (levelCache.has(entry.id)) return levelCache.get(entry.id) as 1 | 2 | 3;
    const parent = itemByOrder.get(entry.parentLink);
    const level = parent ? Math.min(getLevel(parent) + 1, 3) : 1;
    levelCache.set(entry.id, level);
    return level as 1 | 2 | 3;
  };

  const getStyleForLevel = (level: number) => {
    if (level === 2) return linkStyle.level2 || 'none';
    if (level === 3) return linkStyle.level3 || 'none';
    return linkStyle.level1 || 'none';
  };

  const shouldShowMarkerInText = (level: number) => {
    if (level === 2) return !!linkStyle.showLevel2InText;
    if (level === 3) return !!linkStyle.showLevel3InText;
    return !!linkStyle.showLevel1InText;
  };

  const renderNavList = (parentKey = '', level = 1): React.ReactNode => {
    const children = childrenByParent.get(parentKey) || [];
    if (children.length === 0) return null;
    const listStyle = getStyleForLevel(level);

    return (
      <ol
        className={`${level === 1 ? 'space-y-2' : 'mt-2 space-y-1.5'} ${listStyle === 'none' ? 'list-none' : ''}`}
        style={{
          listStyleType: listStyle === 'none' ? 'none' : listStyle,
          paddingLeft: level === 1 ? 0 : 20,
        }}
      >
        {children.map((entry: any) => (
          <li key={entry.id} className="pl-1 text-sm font-bold text-gray-700 marker:text-palette-red marker:font-black">
            <a href={`#toc-${entry.id}`} className="inline-flex items-center gap-2 hover:text-palette-red transition-colors">
              <span>{entry.title || `${t('admin.post.toc.item')} ${entry.orderNumber}`}</span>
              <RemixIcon name="ri-arrow-right-s-line" size={14} className="text-gray-300" />
            </a>
            {renderNavList(String(entry.orderNumber), Math.min(level + 1, 3))}
          </li>
        ))}
      </ol>
    );
  };

  if (items.length === 0) return null;

  return (
    <section className="detail-toc-block space-y-8">
      <div className="detail-structured-summary-card rounded-[5px] border border-gray-100 bg-gray-50/70 p-5 md:p-6">
        <div className="mb-4 flex items-center justify-between gap-3 border-b border-gray-200/70 pb-3">
          <h3 className="text-xl font-black text-gray-900">{t('admin.post.tab.contents')}</h3>
          {tocData.optionalUrl && (
            <a
              href={tocData.optionalUrl}
              target="_blank"
              rel="noopener noreferrer"
              className="inline-flex items-center gap-1.5 rounded-[4px] border border-gray-200 bg-white px-3 py-1.5 text-[11px] font-black uppercase tracking-wider text-gray-600 hover:border-palette-red hover:text-palette-red transition-colors"
            >
              <RemixIcon name="ri-link" size={13} />
              URL
            </a>
          )}
        </div>
        {renderNavList()}
      </div>

      <div className="space-y-10">
        {items.map((entry: any) => {
          const level = getLevel(entry);
          const style = getStyleForLevel(level);
          const marker = shouldShowMarkerInText(level) ? markerForStyle(style, entry.orderNumber) : '';

          return (
            <section id={`toc-${entry.id}`} key={entry.id} className="scroll-mt-24 space-y-4">
              <div className="flex items-start gap-3">
                {marker && (
                  <span className="mt-1 flex h-8 min-w-8 shrink-0 items-center justify-center rounded-[4px] bg-gray-900 px-2 text-xs font-black text-white">
                    {marker}
                  </span>
                )}
                <h3 className={`${level === 1 ? 'text-2xl md:text-3xl' : level === 2 ? 'text-xl md:text-2xl' : 'text-lg md:text-xl'} font-black text-gray-900 leading-tight`}>
                  {entry.title}
                </h3>
              </div>

              {entry.image && (
                <figure className="overflow-hidden rounded-[5px] border border-gray-100 bg-gray-50">
                  <img src={entry.image} alt={entry.imageDescription || entry.title} className="w-full max-h-[520px] object-contain" />
                  {entry.imageDescription && (
                    <figcaption className="border-t border-gray-100 px-4 py-2 text-xs font-medium italic text-gray-500">
                      {entry.imageDescription}
                    </figcaption>
                  )}
                </figure>
              )}

              {entry.content && (
                <div
                  className="rich-text-content prose prose-lg max-w-full text-gray-800 leading-[1.85] font-medium"
                  dangerouslySetInnerHTML={{ __html: entry.content }}
                />
              )}
            </section>
          );
        })}
      </div>
    </section>
  );
};

const RecipeBlock: React.FC<{ item: any }> = ({ item }) => {
  const { t } = useLanguage();
  const recipeData = item?.recipeData || {};
  const ingredients = Array.isArray(recipeData.ingredients)
    ? recipeData.ingredients.map((entry: any) => String(entry?.text || '').trim()).filter(Boolean)
    : [];
  const nutrition = Array.isArray(recipeData.nutrition)
    ? recipeData.nutrition
      .map((entry: any) => ({
        label: String(entry?.label || '').trim(),
        value: String(entry?.value || '').trim(),
      }))
      .filter((entry: any) => entry.label || entry.value)
    : [];
  const directions = Array.isArray(recipeData.directions)
    ? recipeData.directions
      .map((entry: any, entryIndex: number) => ({
        id: String(entry?.id || `recipe-step-${entryIndex}`),
        orderNumber: Number(entry?.orderNumber) || entryIndex + 1,
        title: String(entry?.title || '').trim(),
        image: String(entry?.image || '').trim(),
        imageDescription: String(entry?.imageDescription || '').trim(),
        content: String(entry?.content || ''),
      }))
      .filter((entry: any) => entry.title || entry.content || entry.image)
      .sort((a: any, b: any) => a.orderNumber - b.orderNumber)
    : [];
  const metaItems = [
    recipeData.prepTime ? { label: t('news.recipe.prep_time'), value: recipeData.prepTime } : null,
    recipeData.cookTime ? { label: t('news.recipe.cook_time'), value: recipeData.cookTime } : null,
    recipeData.serving ? { label: t('news.recipe.serving'), value: recipeData.serving } : null,
    recipeData.difficulty ? { label: t('news.recipe.difficulty'), value: t(`news.recipe.difficulty_${recipeData.difficulty}`) } : null,
  ].filter(Boolean) as Array<{ label: string; value: string }>;

  if (ingredients.length === 0 && nutrition.length === 0 && directions.length === 0 && !recipeData.videoUrl && !recipeData.videoEmbedCode) {
    return null;
  }

  return (
    <section className="detail-recipe-block space-y-8">
      {(item.title || item.description) && (
        <div className="detail-structured-mobile-intro md:hidden">
          {item.title && <h3>{item.title}</h3>}
          {item.description && (
            <div
              className="rich-text-content"
              dangerouslySetInnerHTML={{ __html: item.description }}
            />
          )}
        </div>
      )}
      <div className="detail-structured-summary-card rounded-[5px] border border-gray-100 bg-gray-50/70 p-5 md:p-6">
        <div className="mb-4 flex flex-col gap-3 border-b border-gray-200/70 pb-4 md:flex-row md:items-center md:justify-between">
          <div>
            <h3 className="text-xl font-black text-gray-900">{t('news.recipe.title')}</h3>
            <p className="mt-1 text-xs font-bold text-gray-500">{t('news.recipe.subtitle')}</p>
          </div>
          {recipeData.optionalUrl && (
            <a
              href={recipeData.optionalUrl}
              target="_blank"
              rel="noopener noreferrer"
              className="inline-flex items-center gap-1.5 rounded-[4px] border border-gray-200 bg-white px-3 py-1.5 text-[11px] font-black uppercase tracking-wider text-gray-600 hover:border-palette-red hover:text-palette-red transition-colors"
            >
              <RemixIcon name="ri-link" size={13} />
              URL
            </a>
          )}
        </div>
        {metaItems.length > 0 && (
          <div className="grid grid-cols-2 gap-3 md:grid-cols-4">
            {metaItems.map((meta) => (
              <div key={meta.label} className="rounded-[5px] border border-gray-100 bg-white p-3 shadow-sm">
                <span className="block text-[10px] font-black uppercase tracking-widest text-gray-400">{meta.label}</span>
                <span className="mt-1 block text-sm font-black text-gray-900">{meta.value}</span>
              </div>
            ))}
          </div>
        )}
      </div>

      {(recipeData.videoEmbedCode || recipeData.videoUrl) && (
        <div className="overflow-hidden rounded-[5px] border border-gray-100 bg-gray-950 shadow-lg">
          {recipeData.videoEmbedCode ? (
            <div
              className="recipe-video-embed aspect-video w-full [&_iframe]:h-full [&_iframe]:w-full [&_iframe]:border-0"
              dangerouslySetInnerHTML={{ __html: recipeData.videoEmbedCode }}
            />
          ) : (
            <VideoCard data={{ mediaUrl: recipeData.videoUrl } as any} />
          )}
        </div>
      )}

      {(ingredients.length > 0 || nutrition.length > 0) && (
        <div className="grid gap-5 md:grid-cols-2">
          {ingredients.length > 0 && (
            <div className="rounded-[5px] border border-gray-100 bg-white p-5 shadow-sm">
              <h4 className="mb-4 text-lg font-black text-gray-900">{t('news.recipe.ingredients')}</h4>
              <ul className="space-y-3">
                {ingredients.map((ingredient: string, index: number) => (
                  <li key={`${ingredient}-${index}`} className="flex items-start gap-3 text-sm font-bold text-gray-700">
                    <RemixIcon name="ri-check-line" size={17} className="mt-0.5 shrink-0 text-palette-red" />
                    <span>{ingredient}</span>
                  </li>
                ))}
              </ul>
            </div>
          )}
          {nutrition.length > 0 && (
            <div className="rounded-[5px] border border-gray-100 bg-white p-5 shadow-sm">
              <h4 className="mb-4 text-lg font-black text-gray-900">{t('news.recipe.nutrition')}</h4>
              <div className="grid grid-cols-1 gap-2 sm:grid-cols-2">
                {nutrition.map((entry: any, index: number) => (
                  <div key={`${entry.label}-${index}`} className="rounded-[4px] border border-gray-100 bg-gray-50 px-3 py-2">
                    <span className="block text-[10px] font-black uppercase tracking-widest text-gray-400">{entry.label || t('news.recipe.nutrition_item')}</span>
                    <span className="mt-0.5 block text-sm font-black text-gray-900">{entry.value}</span>
                  </div>
                ))}
              </div>
            </div>
          )}
        </div>
      )}

      {directions.length > 0 && (
        <div className="space-y-6">
          <h4 className="text-xl font-black text-gray-900">{t('news.recipe.directions')}</h4>
          {directions.map((direction: any) => (
            <section key={direction.id} className="grid gap-5 rounded-[5px] border border-gray-100 bg-white p-5 shadow-sm md:grid-cols-[48px_minmax(0,1fr)]">
              <span className="flex h-12 w-12 items-center justify-center rounded-[5px] bg-gray-900 text-base font-black text-white">
                {direction.orderNumber}
              </span>
              <div className="space-y-4">
                {direction.title && <h5 className="text-xl font-black text-gray-900">{direction.title}</h5>}
                {direction.image && (
                  <figure className="overflow-hidden rounded-[5px] border border-gray-100 bg-gray-50">
                    <img src={direction.image} alt={direction.imageDescription || direction.title} className="w-full max-h-[520px] object-contain" />
                    {direction.imageDescription && (
                      <figcaption className="border-t border-gray-100 px-4 py-2 text-xs font-medium italic text-gray-500">
                        {direction.imageDescription}
                      </figcaption>
                    )}
                  </figure>
                )}
                {direction.content && (
                  <div
                    className="rich-text-content prose prose-lg max-w-full text-gray-800 leading-[1.85] font-medium"
                    dangerouslySetInnerHTML={{ __html: direction.content }}
                  />
                )}
              </div>
            </section>
          ))}
        </div>
      )}
    </section>
  );
};

const EventBlock: React.FC<{ item: any }> = ({ item }) => {
  const { t, currentLang } = useLanguage();
  const eventData = item?.eventData || {};
  const locale = String(currentLang) === 'tr' ? 'tr-TR' : String(currentLang) === 'ar' ? 'ar' : 'en-US';
  const formatDateTime = (value: unknown) => {
    const raw = String(value || '').trim();
    if (!raw) return '';
    const date = new Date(raw);
    if (Number.isNaN(date.getTime())) return raw;
    return new Intl.DateTimeFormat(locale, {
      day: '2-digit',
      month: 'short',
      year: 'numeric',
      hour: '2-digit',
      minute: '2-digit',
    }).format(date);
  };
  const formatDate = (value: unknown) => {
    const raw = String(value || '').trim();
    if (!raw) return '';
    const match = raw.match(/^(\d{4})-(\d{2})-(\d{2})$/);
    if (match) {
      const [, year, month, day] = match;
      const date = new Date(Number(year), Number(month) - 1, Number(day));
      return new Intl.DateTimeFormat(locale, {
        day: '2-digit',
        month: 'short',
        year: 'numeric',
      }).format(date);
    }
    const date = new Date(raw);
    if (Number.isNaN(date.getTime())) return raw;
    return new Intl.DateTimeFormat(locale, {
      day: '2-digit',
      month: 'short',
      year: 'numeric',
    }).format(date);
  };
  const registrationLabel = (type: string) => {
    if (!type) return '';
    return t(`news.event.registration_${type}`);
  };
  const schedule = Array.isArray(eventData.schedule)
    ? eventData.schedule
      .map((entry: any, entryIndex: number) => ({
        id: String(entry?.id || `event-schedule-${entryIndex}`),
        orderNumber: Number(entry?.orderNumber) || entryIndex + 1,
        date: String(entry?.date || '').trim(),
        time: String(entry?.time || '').trim(),
        title: String(entry?.title || '').trim(),
        description: String(entry?.description || '').trim(),
        image: String(entry?.image || '').trim(),
        imageDescription: String(entry?.imageDescription || '').trim(),
      }))
      .filter((entry: any) => entry.date || entry.time || entry.title || entry.description || entry.image)
      .sort((a: any, b: any) => a.orderNumber - b.orderNumber)
    : [];
  const highlights = Array.isArray(eventData.highlights)
    ? eventData.highlights
      .map((entry: any) => ({
        label: String(entry?.label || '').trim(),
        value: String(entry?.value || '').trim(),
      }))
      .filter((entry: any) => entry.label || entry.value)
    : [];
  const speakers = Array.isArray(eventData.speakers)
    ? eventData.speakers
      .map((entry: any, entryIndex: number) => ({
        id: String(entry?.id || `event-speaker-${entryIndex}`),
        name: String(entry?.name || '').trim(),
        role: String(entry?.role || '').trim(),
        image: String(entry?.image || '').trim(),
        imageDescription: String(entry?.imageDescription || '').trim(),
        bio: String(entry?.bio || ''),
      }))
      .filter((entry: any) => entry.name || entry.role || entry.image || entry.bio)
    : [];
  const metaItems = [
    eventData.startDateTime ? { icon: 'ri-calendar-line', label: t('news.event.start'), value: formatDateTime(eventData.startDateTime) } : null,
    eventData.endDateTime ? { icon: 'ri-time-line', label: t('news.event.end'), value: formatDateTime(eventData.endDateTime) } : null,
    eventData.organizer ? { icon: 'ri-group-line', label: t('news.event.organizer'), value: eventData.organizer } : null,
    eventData.venueName ? { icon: 'ri-map-pin-line', label: t('news.event.venue'), value: eventData.venueName } : null,
  ].filter(Boolean) as Array<{ icon: string; label: string; value: string }>;
  const hasRegistration = eventData.registrationType && eventData.registrationType !== 'none';
  const hasLocation = eventData.address || eventData.latitude || eventData.longitude;
  const hasContent = metaItems.length > 0 || hasRegistration || eventData.ticketUrl || eventData.ticketPrice || eventData.capacity || hasLocation || schedule.length > 0 || highlights.length > 0 || speakers.length > 0;

  if (!hasContent) return null;

  return (
    <section className="detail-event-block space-y-8">
      {(item.title || item.description) && (
        <div className="detail-structured-mobile-intro md:hidden">
          {item.title && <h3>{item.title}</h3>}
          {item.description && (
            <div
              className="rich-text-content"
              dangerouslySetInnerHTML={{ __html: item.description }}
            />
          )}
        </div>
      )}
      <div className="detail-structured-summary-card rounded-[5px] border border-gray-100 bg-gray-50/70 p-5 md:p-6">
        <div className="mb-4 border-b border-gray-200/70 pb-4">
          <h3 className="text-xl font-black text-gray-900">{t('news.event.title')}</h3>
          <p className="mt-1 text-xs font-bold text-gray-500">{t('news.event.subtitle')}</p>
        </div>
        {metaItems.length > 0 && (
          <div className="grid grid-cols-1 gap-3 sm:grid-cols-2 lg:grid-cols-4">
            {metaItems.map((meta) => {
              return (
                <div key={meta.label} className="rounded-[5px] border border-gray-100 bg-white p-3 shadow-sm">
                  <span className="flex items-center gap-1.5 text-[10px] font-black uppercase tracking-widest text-gray-400">
                    <RemixIcon name={meta.icon} size={13} />
                    {meta.label}
                  </span>
                  <span className="mt-1 block text-sm font-black text-gray-900">{meta.value}</span>
                </div>
              );
            })}
          </div>
        )}
      </div>

      {(hasLocation || hasRegistration || eventData.ticketUrl || eventData.ticketPrice || eventData.capacity) && (
        <div className="grid gap-5 md:grid-cols-2">
          {hasLocation && (
            <div className="rounded-[5px] border border-gray-100 bg-white p-5 shadow-sm">
              <h4 className="mb-4 flex items-center gap-2 text-lg font-black text-gray-900">
                <RemixIcon name="ri-map-pin-line" size={18} className="text-palette-red" />
                {t('news.event.location')}
              </h4>
              <div className="space-y-3 text-sm font-bold text-gray-700">
                {eventData.address && <p>{eventData.address}</p>}
                {(eventData.latitude || eventData.longitude) && (
                  <p className="rounded-[4px] border border-gray-100 bg-gray-50 px-3 py-2 text-xs font-black text-gray-500">
                    {t('news.event.coordinates')}: {[eventData.latitude, eventData.longitude].filter(Boolean).join(', ')}
                  </p>
                )}
              </div>
            </div>
          )}
          {(hasRegistration || eventData.ticketUrl || eventData.ticketPrice || eventData.capacity) && (
            <div className="rounded-[5px] border border-gray-100 bg-white p-5 shadow-sm">
              <h4 className="mb-4 flex items-center gap-2 text-lg font-black text-gray-900">
                <RemixIcon name="ri-ticket-line" size={18} className="text-palette-red" />
                {t('news.event.registration')}
              </h4>
              <div className="grid grid-cols-1 gap-2 sm:grid-cols-2">
                {eventData.registrationType && (
                  <div className="rounded-[4px] border border-gray-100 bg-gray-50 px-3 py-2">
                    <span className="block text-[10px] font-black uppercase tracking-widest text-gray-400">{t('news.event.registration')}</span>
                    <span className="mt-0.5 block text-sm font-black text-gray-900">{registrationLabel(eventData.registrationType)}</span>
                  </div>
                )}
                {eventData.ticketPrice && (
                  <div className="rounded-[4px] border border-gray-100 bg-gray-50 px-3 py-2">
                    <span className="block text-[10px] font-black uppercase tracking-widest text-gray-400">{t('news.event.price')}</span>
                    <span className="mt-0.5 block text-sm font-black text-gray-900">{eventData.ticketPrice}</span>
                  </div>
                )}
                {eventData.capacity && (
                  <div className="rounded-[4px] border border-gray-100 bg-gray-50 px-3 py-2">
                    <span className="block text-[10px] font-black uppercase tracking-widest text-gray-400">{t('news.event.capacity')}</span>
                    <span className="mt-0.5 block text-sm font-black text-gray-900">{eventData.capacity}</span>
                  </div>
                )}
                {eventData.ticketUrl && (
                  <a
                    href={eventData.ticketUrl}
                    target="_blank"
                    rel="noopener noreferrer"
                    className="inline-flex items-center justify-center gap-1.5 rounded-[4px] border border-gray-200 bg-white px-3 py-2 text-[11px] font-black uppercase tracking-wider text-gray-600 hover:border-palette-red hover:text-palette-red transition-colors"
                  >
                    <RemixIcon name="ri-link" size={13} />
                    {t('news.event.ticket_url')}
                  </a>
                )}
              </div>
            </div>
          )}
        </div>
      )}

      {schedule.length > 0 && (
        <div className="rounded-[5px] border border-gray-100 bg-white p-5 shadow-sm">
          <h4 className="mb-4 text-lg font-black text-gray-900">{eventData.scheduleTitle || t('news.event.schedule')}</h4>
          <div className="space-y-3">
            {schedule.map((entry: any) => (
              <div key={entry.id} className="grid gap-3 rounded-[4px] border border-gray-100 bg-gray-50 p-3 sm:grid-cols-[150px_minmax(0,1fr)]">
                <div className="space-y-1">
                  {entry.date && <span className="block text-xs font-black text-gray-500">{formatDate(entry.date)}</span>}
                  <span className="block text-sm font-black text-palette-red">{entry.time || `#${entry.orderNumber}`}</span>
                </div>
                <div className="grid gap-3 sm:grid-cols-[minmax(0,1fr)_120px]">
                  <div>
                    {entry.title && <h5 className="text-sm font-black text-gray-900">{entry.title}</h5>}
                    {entry.description && <p className="mt-1 text-sm font-medium text-gray-600">{entry.description}</p>}
                  </div>
                  {entry.image && (
                    <figure className="overflow-hidden rounded-[4px] border border-gray-100 bg-white">
                      <img
                        src={entry.image}
                        alt={entry.imageDescription || entry.title}
                        className="h-24 w-full object-cover"
                      />
                    </figure>
                  )}
                </div>
              </div>
            ))}
          </div>
        </div>
      )}

      {highlights.length > 0 && (
        <div className="rounded-[5px] border border-gray-100 bg-white p-5 shadow-sm">
          <h4 className="mb-4 flex items-center gap-2 text-lg font-black text-gray-900">
            <RemixIcon name="ri-information-line" size={18} className="text-palette-red" />
            {eventData.highlightsTitle || t('news.event.highlights')}
          </h4>
          <div className="grid grid-cols-1 gap-2 sm:grid-cols-2">
            {highlights.map((entry: any, index: number) => (
              <div key={`${entry.label}-${index}`} className="rounded-[4px] border border-gray-100 bg-gray-50 px-3 py-2">
                <span className="block text-[10px] font-black uppercase tracking-widest text-gray-400">{entry.label}</span>
                <span className="mt-0.5 block text-sm font-black text-gray-900">{entry.value}</span>
              </div>
            ))}
          </div>
        </div>
      )}

      {speakers.length > 0 && (
        <div className="rounded-[5px] border border-gray-100 bg-white p-5 shadow-sm">
          <h4 className="mb-4 flex items-center gap-2 text-lg font-black text-gray-900">
            <RemixIcon name="ri-group-line" size={18} className="text-palette-red" />
            {eventData.speakersTitle || t('news.event.speakers')}
          </h4>
          <div className="grid gap-4 md:grid-cols-2">
            {speakers.map((speaker: any) => (
              <div key={speaker.id} className="grid gap-4 rounded-[5px] border border-gray-100 bg-gray-50 p-4 sm:grid-cols-[96px_minmax(0,1fr)]">
                {speaker.image && (
                  <img
                    src={speaker.image}
                    alt={speaker.imageDescription || speaker.name}
                    className="h-24 w-24 rounded-[5px] object-cover"
                  />
                )}
                <div className="space-y-2">
                  {speaker.name && <h5 className="text-base font-black text-gray-900">{speaker.name}</h5>}
                  {speaker.role && <p className="text-xs font-black uppercase tracking-widest text-palette-red">{speaker.role}</p>}
                  {speaker.bio && (
                    <div
                      className="rich-text-content prose prose-sm max-w-full text-gray-700"
                      dangerouslySetInnerHTML={{ __html: speaker.bio }}
                    />
                  )}
                </div>
              </div>
            ))}
          </div>
        </div>
      )}
    </section>
  );
};

const NewsDetail: React.FC<NewsDetailProps> = ({ data, onBack, navItems, siteSettings, adSettings, loading }) => {
  const articleProgressRef = useRef<HTMLDivElement | null>(null);
  const articleProgressEndRef = useRef<HTMLDivElement | null>(null);
  const shareMenuRef = useRef<HTMLDivElement | null>(null);
  const heroShareMenuRef = useRef<HTMLDivElement | null>(null);
  const selectedEmojisRef = useRef<string[]>([]);
  const reactionCountsRef = useRef<Record<string, number>>({});
  const [scrollProgress, setScrollProgress] = useState(0);
  const [selectedEmojis, setSelectedEmojis] = useState<string[]>([]);
  const [expandedFaqIndex, setExpandedFaqIndex] = useState<number | null>(null);
  const [showShareMenu, setShowShareMenu] = useState(false);
  const [showHeroShareMenu, setShowHeroShareMenu] = useState(false);
  const [showMobileShareRail, setShowMobileShareRail] = useState(false);
  const [isMobileVideoFeedOpen, setIsMobileVideoFeedOpen] = useState(false);
  const [mobileVideoFeedTarget, setMobileVideoFeedTarget] = useState<string | undefined>(undefined);
  const [mobileVideoFeedTargetPostId, setMobileVideoFeedTargetPostId] = useState<string | undefined>(undefined);
  const [detailScrollOffset, setDetailScrollOffset] = useState(0);
  const [detailCounts, setDetailCounts] = useState({
    likes: data.likes || 0,
    dislikes: data.dislikes || 0,
    shares: data.shares || 0,
    saves: data.saves || 0,
    views: data.views || 0,
  });
  const [detailState, setDetailState] = useState({
    liked: !!data.userLiked,
    disliked: !!data.userDisliked,
    saved: !!data.userSaved,
  });
  const [detailActionBusy, setDetailActionBusy] = useState(false);
  const [reactionCounts, setReactionCounts] = useState<Record<string, number>>({});
  const { t, currentLang } = useLanguage();
  const { showToast } = useToast();
  const showPostAuthor = siteSettings?.content_show_post_author !== false;
  const showPostDate = siteSettings?.content_show_post_date !== false;
  const showPostViewCount = siteSettings?.content_show_post_view_count !== false;
  const commentsEnabled = siteSettings?.content_comment_system_enabled !== false;
  const commentApprovalEnabled = siteSettings?.content_comment_approval_enabled !== false;
  const emojiReactionsEnabled = siteSettings?.content_emoji_reactions_enabled !== false;
  const detailHref = getPostHref(data, siteSettings);
  const postPathSegment = getPostPathSegment(data, siteSettings);

  const stripHtml = stripHtmlToText;

  const shareUrl = typeof window !== 'undefined'
    ? `${window.location.origin}${detailHref}`
    : '';

  const getUtmUrl = (source: string) => {
    return buildTrackedShareUrl(shareUrl, {
      platform: source,
      campaign: 'news_detail',
      contentId: postPathSegment || data.id,
    });
  };

  const getDetailShareText = () => {
    return buildShareText({
      title: data.title,
      summary: data.summary,
      category: data.category,
      siteName: siteSettings?.site_name || 'Haber',
      keywords: data.keywords || siteSettings?.meta_keywords,
    });
  };

  const shareToTwitter = () => {
    void recordShare('twitter');
    const cleanTitle = stripHtml(data.title);
    const url = getUtmUrl('twitter');
    const hashtags = buildShareHashtags({
      category: data.category,
      siteName: siteSettings?.site_name,
      keywords: data.keywords || siteSettings?.meta_keywords,
    }, 3);
    openShareWindow(buildXShareUrl({
      text: cleanTitle,
      url,
      hashtags,
      via: siteSettings?.twitter_username,
    }));
    setShowShareMenu(false);
  };

  const shareToFacebook = () => {
    void recordShare('facebook');
    const url = getUtmUrl('facebook');
    openShareWindow(buildFacebookShareUrl({
      url,
      appId: siteSettings?.fb_app_id,
      redirectUrl: shareUrl || url,
    }));
    setShowShareMenu(false);
  };

  const shareToInstagram = async () => {
    void recordShare('instagram');
    const copied = await copyLink(false, 'instagram');
    showToast(copied ? t('common.link_copied_instagram') : t('common.copy_failed_alt'), copied ? 'info' : 'error');
    window.setTimeout(() => openShareWindow('https://www.instagram.com/'), 1000);
    setShowShareMenu(false);
  };

  const shareToWhatsApp = () => {
    void recordShare('whatsapp');
    const text = getDetailShareText();
    const url = getUtmUrl('whatsapp');
    openShareWindow(buildWhatsAppShareUrl(`${text}\n\n🔗 ${url}`));
    setShowShareMenu(false);
  };

  const shareToTelegram = () => {
    void recordShare('telegram');
    const text = getDetailShareText();
    const url = getUtmUrl('telegram');
    openShareWindow(buildTelegramShareUrl(url, text));
    setShowShareMenu(false);
  };

  const shareToTikTok = async () => {
    void recordShare('tiktok');
    const copied = await copyLink(false, 'tiktok');
    showToast(copied ? t('common.link_copied_tiktok') : t('common.copy_failed_alt'), copied ? 'info' : 'error');
    window.setTimeout(() => openShareWindow('https://www.tiktok.com/'), 1000);
    setShowShareMenu(false);
  };

  const copyLink = async (track = true, platform = 'copy_link', showNotification = false) => {
    if (track) void recordShare(platform);
    const url = getUtmUrl(platform);
    const copied = await writeToClipboard(url);
    if (showNotification) showToast(copied ? t('common.link_copied') : t('common.copy_failed_alt'), copied ? 'success' : 'error');
    if (showShareMenu) setShowShareMenu(false);
    return copied;
  };

  const handleNativeShare = async () => {
    void recordShare('nsosyal');
    const cleanTitle = stripHtml(data.title);
    const text = getDetailShareText();
    const url = getUtmUrl('nsosyal');

    if (navigator.share) {
      try {
        await navigator.share({
          title: cleanTitle,
          text,
          url,
        });
      } catch (e) {
        if (!isShareAbortError(e)) {
          const copied = await copyLink(false, 'nsosyal');
          showToast(copied ? t('common.link_copied') : t('common.copy_failed_alt'), copied ? 'success' : 'error');
          if (copied) window.setTimeout(() => openShareWindow('https://nsosyal.com/'), 600);
        }
      }
    } else {
      const copied = await copyLink(false, 'nsosyal');
      showToast(copied ? t('common.link_copied') : t('common.copy_failed_alt'), copied ? 'success' : 'error');
      if (copied) window.setTimeout(() => openShareWindow('https://nsosyal.com/'), 600);
    }
    setShowShareMenu(false);
  };

  const handleShareMenu = (event: React.MouseEvent<HTMLButtonElement>) => {
    event.stopPropagation();
    setShowShareMenu((value) => !value);
  };

  const closeHeroShareMenu = () => {
    setShowHeroShareMenu(false);
  };

  const handleHeroShareMenu = (event: React.MouseEvent<HTMLButtonElement>) => {
    event.stopPropagation();
    setShowShareMenu(false);
    setShowHeroShareMenu((value) => !value);
  };

  // Emoji Reactions Config
  const MAX_REACTIONS = 3;
  const emojis = [
    { id: 'love', image: 'reaction_like.webp', label: 'Beğendim', count: reactionCounts.love || 0, accent: '#E35D73' },
    { id: 'great', image: 'reaction_illuminating.webp', label: 'Aydınlatıcı', count: reactionCounts.great || 0, accent: '#D98A34' },
    { id: 'bravo', image: 'reaction_thoughtful.webp', label: 'Düşündürdü', count: reactionCounts.bravo || 0, accent: '#66789A' },
    { id: 'laugh', image: 'reaction_surprised.webp', label: 'Şaşırttı', count: reactionCounts.laugh || 0, accent: '#36AFA2' },
    { id: 'sad', image: 'reaction_saddened.webp', label: 'Üzdü', count: reactionCounts.sad || 0, accent: '#5B8FC8' },
    { id: 'angry', image: 'reaction_angering.webp', label: 'Kızdırdı', count: reactionCounts.angry || 0, accent: '#D7634C' },
  ];
  const totalReactions = emojis.reduce((sum, item) => sum + item.count, 0);

  const syncReactionState = (nextSelected: string[], nextCounts: Record<string, number>) => {
    selectedEmojisRef.current = nextSelected;
    reactionCountsRef.current = nextCounts;
    setSelectedEmojis(nextSelected);
    setReactionCounts(nextCounts);
  };

  const showReactionLimitToast = () => {
    showToast(`En fazla ${MAX_REACTIONS} emoji tepkisi seçebilirsiniz.`, 'info');
  };

  const applyPostState = (result: any) => {
    if (result?.counts) {
      setDetailCounts((prev) => ({
        likes: result.counts.likes ?? prev.likes,
        dislikes: result.counts.dislikes ?? prev.dislikes,
        shares: result.counts.shares ?? prev.shares,
        saves: result.counts.saves ?? prev.saves,
        views: result.counts.views ?? prev.views,
      }));
    }
    if (result?.reactions) {
      reactionCountsRef.current = result.reactions;
      setReactionCounts(result.reactions);
    }
    if (result?.userState) {
      const nextSelected = result.userState.reactions || [];
      selectedEmojisRef.current = nextSelected;
      setSelectedEmojis(nextSelected);
      setDetailState({
        liked: !!result.userState.liked,
        disliked: !!result.userState.disliked,
        saved: !!result.userState.saved,
      });
    }
  };

  const requireSignedInForDetailAction = (message: string) => {
    if (!isPostId(data.id)) return false;
    if (hasPostActionSession()) return true;
    showToast(message, 'info');
    return false;
  };

  const restoreDetailActionSnapshot = (
    counts: typeof detailCounts,
    state: typeof detailState
  ) => {
    setDetailCounts(counts);
    setDetailState(state);
  };

  const runDetailAction = async ({
    action,
    signInMessage,
    fallbackMessage,
    optimistic,
  }: {
    action: 'toggle_like' | 'toggle_dislike' | 'toggle_save';
    signInMessage: string;
    fallbackMessage: string;
    optimistic: (counts: typeof detailCounts, state: typeof detailState) => {
      counts: typeof detailCounts;
      state: typeof detailState;
    };
  }) => {
    if (detailActionBusy) return;
    if (!requireSignedInForDetailAction(signInMessage)) return;

    const previousCounts = detailCounts;
    const previousState = detailState;
    const next = optimistic(previousCounts, previousState);

    setDetailActionBusy(true);
    setDetailCounts(next.counts);
    setDetailState(next.state);

    try {
      applyPostState(await postAction(action, { postId: data.id, publisherId: data.publisherId }));
    } catch (error: any) {
      restoreDetailActionSnapshot(previousCounts, previousState);
      const message = String(error?.message || '');
      showToast(
        message.toLocaleLowerCase('tr-TR').includes('auth required') ? signInMessage : fallbackMessage,
        message.toLocaleLowerCase('tr-TR').includes('auth required') ? 'info' : 'error'
      );
    } finally {
      setDetailActionBusy(false);
    }
  };

  useEffect(() => {
    let isMounted = true;
    setDetailCounts({
      likes: data.likes || 0,
      dislikes: data.dislikes || 0,
      shares: data.shares || 0,
      saves: data.saves || 0,
      views: data.views || 0,
    });
    setDetailState({
      liked: !!data.userLiked,
      disliked: !!data.userDisliked,
      saved: !!data.userSaved,
    });
    setDetailActionBusy(false);

    if (isPostId(data.id) && hasPostActionSession()) {
      void postAction('state', { postId: data.id, publisherId: data.publisherId })
        .then((result) => {
          if (isMounted) applyPostState(result);
        })
        .catch(() => {
          // Keep the server-rendered counts if viewer state cannot be refreshed.
        });
    }

    return () => {
      isMounted = false;
    };
  }, [
    data.id,
    data.publisherId,
    data.likes,
    data.dislikes,
    data.shares,
    data.saves,
    data.views,
    data.userLiked,
    data.userDisliked,
    data.userSaved,
  ]);

  const recordShare = async (platform: string) => {
    try {
      applyPostState(await postAction('share', { postId: data.id, publisherId: data.publisherId, platform }));
    } catch {
      setDetailCounts((prev) => ({ ...prev, shares: prev.shares + 1 }));
    }
  };

  const toggleEmoji = async (id: string) => {
    const previousSelected = selectedEmojisRef.current;
    const previousCounts = reactionCountsRef.current;
    const isSelected = previousSelected.includes(id);

    if (!isSelected && previousSelected.length >= MAX_REACTIONS) {
      showReactionLimitToast();
      return;
    }

    const nextSelected = isSelected
      ? previousSelected.filter((reactionId) => reactionId !== id)
      : [...previousSelected, id];
    const nextCounts = {
      ...previousCounts,
      [id]: Math.max(0, (previousCounts[id] || 0) + (isSelected ? -1 : 1)),
    };

    syncReactionState(nextSelected, nextCounts);

    try {
      applyPostState(await postAction('toggle_reaction', { postId: data.id, publisherId: data.publisherId, reaction: id }));
    } catch (error: any) {
      syncReactionState(previousSelected, previousCounts);
      const message = String(error?.message || '');
      if (message.toLocaleLowerCase('tr-TR').includes('fazla') || message.includes(String(MAX_REACTIONS))) {
        showReactionLimitToast();
        return;
      }
      showToast(
        message && message !== 'Request failed' ? message : 'Emoji tepkisi güncellenemedi.',
        'error'
      );
    }
  };

  const toggleDetailLike = async () => {
    await runDetailAction({
      action: 'toggle_like',
      signInMessage: t('auth.login_required_like'),
      fallbackMessage: t('common.like_failed'),
      optimistic: (counts, state) => {
        if (state.liked) {
          return {
            counts: { ...counts, likes: Math.max(0, counts.likes - 1) },
            state: { ...state, liked: false },
          };
        }
        return {
          counts: {
            ...counts,
            likes: counts.likes + 1,
            dislikes: state.disliked ? Math.max(0, counts.dislikes - 1) : counts.dislikes,
          },
          state: { liked: true, disliked: false, saved: state.saved },
        };
      },
    });
  };

  const toggleDetailDislike = async () => {
    await runDetailAction({
      action: 'toggle_dislike',
      signInMessage: t('auth.login_required_dislike'),
      fallbackMessage: t('common.dislike_failed'),
      optimistic: (counts, state) => {
        if (state.disliked) {
          return {
            counts: { ...counts, dislikes: Math.max(0, counts.dislikes - 1) },
            state: { ...state, disliked: false },
          };
        }
        return {
          counts: {
            ...counts,
            likes: state.liked ? Math.max(0, counts.likes - 1) : counts.likes,
            dislikes: counts.dislikes + 1,
          },
          state: { liked: false, disliked: true, saved: state.saved },
        };
      },
    });
  };

  const toggleDetailSave = async () => {
    await runDetailAction({
      action: 'toggle_save',
      signInMessage: t('auth.login_required_bookmark'),
      fallbackMessage: t('common.action_failed'),
      optimistic: (counts, state) => ({
        counts: { ...counts, saves: Math.max(0, counts.saves + (state.saved ? -1 : 1)) },
        state: { ...state, saved: !state.saved },
      }),
    });
  };

  const getBreadcrumbs = () => {
    const storedHierarchy = getStoredCategoryHierarchy(data);
    const hierarchy = storedHierarchy.length > 0
      ? storedHierarchy
      : buildNavigationCategoryHierarchy(data.category, navItems);

    return hierarchy.map((label) => ({ label, value: label }));
  };

  const breadcrumbs = getBreadcrumbs();

  useEffect(() => {
    selectedEmojisRef.current = selectedEmojis;
  }, [selectedEmojis]);

  useEffect(() => {
    reactionCountsRef.current = reactionCounts;
  }, [reactionCounts]);

  useEffect(() => {
    const handleOpenVideoFeed = (event: Event) => {
      event.preventDefault();
      const detail = (event as CustomEvent<{ videoUrl?: string; postId?: string }>).detail;
      setMobileVideoFeedTarget(typeof detail?.videoUrl === 'string' ? detail.videoUrl : undefined);
      setMobileVideoFeedTargetPostId(typeof detail?.postId === 'string' ? detail.postId : undefined);
      setIsMobileVideoFeedOpen(true);
    };

    window.addEventListener(MOBILE_VIDEO_FEED_EVENT, handleOpenVideoFeed);
    return () => window.removeEventListener(MOBILE_VIDEO_FEED_EVENT, handleOpenVideoFeed);
  }, []);

  useEffect(() => {
    const handleClickOutside = (event: MouseEvent) => {
      if (shareMenuRef.current && !shareMenuRef.current.contains(event.target as Node)) {
        setShowShareMenu(false);
      }
    };

    if (showShareMenu) {
      document.addEventListener('mousedown', handleClickOutside);
    }

    return () => {
      document.removeEventListener('mousedown', handleClickOutside);
    };
  }, [showShareMenu]);

  useEffect(() => {
    const handleClickOutside = (event: MouseEvent) => {
      if (heroShareMenuRef.current && !heroShareMenuRef.current.contains(event.target as Node)) {
        setShowHeroShareMenu(false);
      }
    };

    if (showHeroShareMenu) {
      document.addEventListener('mousedown', handleClickOutside);
    }

    return () => {
      document.removeEventListener('mousedown', handleClickOutside);
    };
  }, [showHeroShareMenu]);

  useEffect(() => {
    const handleScroll = () => {
      const progressRoot = articleProgressRef.current;
      const progressEnd = articleProgressEndRef.current;
      const navHeight = Number.parseFloat(
        getComputedStyle(document.documentElement).getPropertyValue('--public-nav-height')
      ) || 0;
      const startY = progressRoot
        ? Math.max(0, progressRoot.getBoundingClientRect().top + window.scrollY - navHeight)
        : 0;
      const endY = progressEnd
        ? Math.max(startY + 1, progressEnd.getBoundingClientRect().top + window.scrollY - window.innerHeight + navHeight)
        : Math.max(startY + 1, document.documentElement.scrollHeight - window.innerHeight);
      const progress = Math.min(100, Math.max(0, ((window.scrollY - startY) / (endY - startY)) * 100));
      setScrollProgress(progress);
      setDetailScrollOffset(Math.max(0, window.scrollY - startY));
    };
    handleScroll();
    window.addEventListener('scroll', handleScroll, { passive: true });
    window.addEventListener('resize', handleScroll);
    window.addEventListener('load', handleScroll);
    return () => {
      window.removeEventListener('scroll', handleScroll);
      window.removeEventListener('resize', handleScroll);
      window.removeEventListener('load', handleScroll);
    };
  }, [data.id]);

  useEffect(() => {
    let isMounted = true;
    postAction('view', { postId: data.id, publisherId: data.publisherId })
      .then((result) => {
        if (isMounted) applyPostState(result);
      })
      .catch(() => null);
    return () => { isMounted = false; };
  }, [data.id, data.publisherId]);

  const renderQuizBlock = (item: any) => <QuizBlock key={item.id} item={item} />;

  const renderMedia = () => {
    const postType = String((data as any).postType || '').toLowerCase();
    const coverThumbnail = ((data as any).coverThumbnail as string) || data.thumbnail;

    // Eğer bu bir "article" haberi ise, ana medya her zaman haberin kapak görseli olmalı.
    if (postType === 'article') {
      const coverOptimized = data.optimizedCoverThumbnail || data.optimizedThumbnail;
      const coverSrc = coverOptimized?.src || coverThumbnail;
      if (!coverSrc) return null;
      const coverSize = imageSizeAttrs(coverOptimized);
      return (
        <div className="rounded-[5px] overflow-hidden border border-gray-100 shadow-xl mt-4 mb-2">
          <img
            src={withImageVariant(coverSrc, 1600)}
            alt={data.thumbnailAlt || data.seoTitle || data.title}
            title={data.thumbnailAlt || data.seoTitle || data.title}
            width={coverSize.width}
            height={coverSize.height}
            loading="eager"
            decoding="async"
            fetchPriority="high"
            className="w-full h-auto object-cover max-h-[600px]"
          />
        </div>
      );
    }

    switch (data.type) {
      case NewsType.REVIEW: return <ReviewCard data={data} />;
      case NewsType.BEFORE_AFTER: return <BeforeAfterCard data={data} />;
      case NewsType.FLIP_CARD: return <FlipCard data={data} />;
      case NewsType.EMBED: return <EmbedCard data={data} />;
      case NewsType.AUDIO: return <AudioCard data={data} allowDownload={siteSettings?.content_audio_download_enabled !== false} />;
      case NewsType.VIDEO: return <VideoCard data={data} />;
      case NewsType.GALLERY: return <GalleryCard data={data} />;
      case NewsType.POLL: return <PollCard data={data} />;
      case NewsType.QUIZ: return null;
      case NewsType.VS: return <VSCard data={data} />;
      case NewsType.PARAGRAPH: return <ParagraphCard data={data} />;
      default:
        if (!data.thumbnail && !data.optimizedThumbnail?.src) return null;
        const image = data.optimizedThumbnail;
        const size = imageSizeAttrs(image);
        return (
          <div className="rounded-[5px] overflow-hidden border border-gray-100 shadow-xl mt-4 mb-2">
            <img
              src={withImageVariant(image?.src || data.thumbnail, 1600)}
              alt={data.thumbnailAlt || data.seoTitle || data.title}
              title={data.thumbnailAlt || data.seoTitle || data.title}
              width={size.width}
              height={size.height}
              loading="eager"
              decoding="async"
              fetchPriority="high"
              className="w-full h-auto object-cover max-h-[600px]"
            />
          </div>
        );
    }
  };

  // 🚀 Dynamic Reading Time Engine
  const calculateReadingTime = () => {
    const wordsPerMinute = 200;
    const itemContent = data.items?.map(i => (i.title || '') + ' ' + (i.description || '')).join(' ') || '';
    const totalContent = (data.title || '') + ' ' + (data.summary || '') + ' ' + (data.content || '') + ' ' + itemContent;
    const words = totalContent.trim().split(/\s+/).length;
    return Math.max(1, Math.ceil(words / wordsPerMinute));
  };

  const readingTime = calculateReadingTime();
  const authorUrl = profileHref(data.publisherHandle);
  const displayAuthorName = titleCaseText(data.author || data.source || '');
  const publishedAt = formatPostDateParts(data.timestamp, currentLang?.code || 'tr');
  const keywordTags = (data.keywords || '')
    .split(',')
    .map((tag) => tag.trim())
    .filter(Boolean);
  const visibleKeywordTags = keywordTags.slice(0, 8);
  const hiddenKeywordCount = Math.max(0, keywordTags.length - visibleKeywordTags.length);
  const shareMenuItems = [
    { key: 'whatsapp', label: t('share.whatsapp'), icon: 'ri-whatsapp-fill', iconClass: 'text-[#25D366]', hoverClass: 'hover:bg-[#25D366]/10', onClick: shareToWhatsApp },
    { key: 'telegram', label: t('share.telegram'), icon: 'ri-telegram-fill', iconClass: 'text-[#229ED9]', hoverClass: 'hover:bg-[#229ED9]/10', onClick: shareToTelegram },
    { key: 'twitter', label: t('share.x_twitter'), icon: 'ri-twitter-x-fill', iconClass: 'text-[#0F1419]', hoverClass: 'hover:bg-black/5', onClick: shareToTwitter },
    { key: 'facebook', label: t('share.facebook'), icon: 'ri-facebook-fill', iconClass: 'text-[#1877F2]', hoverClass: 'hover:bg-[#1877F2]/10', onClick: shareToFacebook },
    { key: 'instagram', label: t('share.instagram'), icon: 'ri-instagram-fill', iconClass: 'text-[#E1306C]', hoverClass: 'hover:bg-[#E1306C]/10', onClick: shareToInstagram },
    { key: 'tiktok', label: t('share.tiktok'), icon: 'ri-tiktok-fill', iconClass: 'text-[#0F1419]', hoverClass: 'hover:bg-black/5', onClick: shareToTikTok },
    { key: 'nsosyal', label: t('share.nsosyal'), icon: 'ri-global-line', iconClass: 'text-palette-red', hoverClass: 'hover:bg-palette-red/5', onClick: handleNativeShare },
  ];
  const heroShareMenuItems: ShareMenuItem[] = [
    { key: 'whatsapp', label: t('share.whatsapp'), icon: 'ri-whatsapp-fill', iconClass: 'text-[#25D366]', hoverClass: 'hover:bg-[#25D366]/10', onClick: () => { shareToWhatsApp(); closeHeroShareMenu(); } },
    { key: 'telegram', label: t('share.telegram'), icon: 'ri-telegram-fill', iconClass: 'text-[#229ED9]', hoverClass: 'hover:bg-[#229ED9]/10', onClick: () => { shareToTelegram(); closeHeroShareMenu(); } },
    { key: 'twitter', label: t('share.x_twitter'), icon: 'ri-twitter-x-fill', iconClass: 'text-[#0F1419]', hoverClass: 'hover:bg-black/5', onClick: () => { shareToTwitter(); closeHeroShareMenu(); } },
    { key: 'facebook', label: t('share.facebook'), icon: 'ri-facebook-fill', iconClass: 'text-[#1877F2]', hoverClass: 'hover:bg-[#1877F2]/10', onClick: () => { shareToFacebook(); closeHeroShareMenu(); } },
    { key: 'instagram', label: t('share.instagram'), icon: 'ri-instagram-fill', iconClass: 'bg-[radial-gradient(circle_at_30%_107%,#fdf497_0%,#fdf497_5%,#fd5949_45%,#d6249f_60%,#285AEB_90%)] bg-clip-text text-transparent', hoverClass: 'hover:bg-[#E1306C]/10', onClick: async () => { await shareToInstagram(); closeHeroShareMenu(); } },
    { key: 'tiktok', label: t('share.tiktok'), customIcon: 'tiktok', hoverClass: 'hover:bg-[#FE2C55]/10', onClick: async () => { await shareToTikTok(); closeHeroShareMenu(); } },
    { key: 'nsosyal', label: t('share.nsosyal'), imageSrc: NSOSYAL_ICON_SRC, imageClass: 'rounded-[4px]', hoverClass: 'hover:bg-[#2F5BFF]/10', onClick: async () => { await handleNativeShare(); closeHeroShareMenu(); } },
  ];
  const renderHeroShareMenuIcon = (item: ShareMenuItem) => {
    if (item.customIcon === 'tiktok') {
      return (
        <span className="relative block h-[20px] w-[20px] transition-transform group-hover:scale-110">
          <RemixIcon name="ri-tiktok-fill" size={20} className="absolute left-[1px] top-0 text-[#25F4EE]" />
          <RemixIcon name="ri-tiktok-fill" size={20} className="absolute -left-[1px] top-0 text-[#FE2C55]" />
          <RemixIcon name="ri-tiktok-fill" size={20} className="relative text-[#010101]" />
        </span>
      );
    }

    if (item.imageSrc) {
      return (
        <img
          src={item.imageSrc}
          alt=""
          loading="lazy"
          decoding="async"
          className={`h-[20px] w-[20px] object-contain transition-transform group-hover:scale-110 ${item.imageClass || ''}`}
        />
      );
    }

    return (
      <RemixIcon
        name={item.icon || ''}
        size={20}
        className={`${item.iconClass || ''} transition-transform group-hover:scale-110`}
      />
    );
  };
  const coverOptimized = data.optimizedCoverThumbnail || data.optimizedThumbnail;
  const mobileHeroRawSrc = coverOptimized?.src || (data as any).coverThumbnail || data.thumbnail || data.mediaUrl || '';
  const mobileHeroSrc = withImageVariant(mobileHeroRawSrc, 1600);
  const mobileHeroSize = imageSizeAttrs(coverOptimized);
  const categoryLine = breadcrumbs
    .map((crumb) => titleCaseText(t(crumb.label) || crumb.label))
    .filter(Boolean)
    .join(' / ');
  const hideMobilePrimaryMedia = data.type === NewsType.STANDARD || data.type === NewsType.IMAGE;
  const scrollToComments = () => {
    document.getElementById('news-detail-comments')?.scrollIntoView({ behavior: 'smooth', block: 'start' });
  };
  const clamp01 = (value: number) => Math.min(1, Math.max(0, value));
  const mobileAppBarProgress = clamp01((detailScrollOffset - 60) / 160);
  const mobileDockProgress = clamp01((detailScrollOffset - 90) / 140);
  const mobileAppBarStyle = {
    '--mobile-detail-appbar-progress': mobileAppBarProgress,
    '--mobile-detail-appbar-offset': `${(1 - mobileAppBarProgress) * -6}px`,
    pointerEvents: mobileAppBarProgress > 0.08 ? 'auto' : 'none',
  } as React.CSSProperties;
  const mobileDockStyle = {
    '--mobile-detail-dock-progress': mobileDockProgress,
    '--mobile-detail-dock-offset': `${(1 - mobileDockProgress) * 18}px`,
    pointerEvents: mobileDockProgress >= 0.4 ? 'auto' : 'none',
  } as React.CSSProperties;

  return (
    <div ref={articleProgressRef} className="public-news-detail animate-in bg-white rounded-[5px] border border-gray-200 shadow-sm relative min-h-screen mb-10 max-w-full mt-2 overflow-x-clip">
      {isMobileVideoFeedOpen && (
        <MobileVideoFeedOverlay
          newsItems={[data]}
          siteSettings={siteSettings}
          initialVideoUrl={mobileVideoFeedTarget}
          initialPostId={mobileVideoFeedTargetPostId}
          onClose={() => setIsMobileVideoFeedOpen(false)}
        />
      )}

      {/* Reading Progress Bar */}
      <div className="fixed top-[var(--public-nav-height)] left-0 w-full h-1 z-[997] bg-gray-100/70 backdrop-blur-sm" aria-hidden="true">
        <div
          className="h-full bg-gradient-to-r from-palette-red via-[#ff5a3d] to-[#f59e0b] transition-[width] duration-100 ease-linear shadow-[0_1px_10px_rgba(239,59,45,0.22)]"
          style={{ width: `${scrollProgress}%` }}
        />
      </div>

      <section className="news-detail-mobile-shell md:hidden" aria-label="Haber detayı">
        <div className="mobile-detail-hero">
          <button type="button" onClick={onBack} className="mobile-detail-back-button" aria-label="Geri dön">
            <RemixIcon name="ri-arrow-left-line" size={21} />
          </button>
          {mobileHeroSrc ? (
            <img
              src={mobileHeroSrc}
              alt={data.thumbnailAlt || data.seoTitle || data.title}
              title={data.thumbnailAlt || data.seoTitle || data.title}
              width={mobileHeroSize.width}
              height={mobileHeroSize.height}
              loading="eager"
              decoding="async"
              fetchPriority="high"
            />
          ) : (
            <div className="mobile-detail-hero-empty">
              <RemixIcon name="ri-image-line" size={34} />
            </div>
          )}
          <div className="mobile-detail-hero-overlay" ref={heroShareMenuRef}>
            <div className="mobile-detail-hero-actions">
              <button type="button" onClick={toggleDetailLike} className={detailState.liked ? 'is-active' : undefined} aria-label="Beğen">
                <RemixIcon name={detailState.liked ? 'ri-thumb-up-fill' : 'ri-thumb-up-line'} size={20} />
                <span>{detailCounts.likes.toLocaleString()}</span>
              </button>
              <button type="button" onClick={toggleDetailDislike} className={detailState.disliked ? 'is-active is-danger' : undefined} aria-label="Beğenme">
                <RemixIcon name={detailState.disliked ? 'ri-thumb-down-fill' : 'ri-thumb-down-line'} size={20} />
                <span>{detailCounts.dislikes.toLocaleString()}</span>
              </button>
              <button type="button" onClick={scrollToComments} aria-label="Yorumlar">
                <RemixIcon name="ri-chat-3-line" size={22} />
                <span>{(data.comments || 0).toLocaleString()}</span>
              </button>
              <button type="button" onClick={handleHeroShareMenu} aria-label="Paylaş" aria-expanded={showHeroShareMenu}>
                <RemixIcon name="ri-share-forward-line" size={22} />
                <span>{detailCounts.shares.toLocaleString()}</span>
              </button>
              <button type="button" onClick={toggleDetailSave} className={`mobile-detail-save ${detailState.saved ? 'is-active' : ''}`} aria-label="Kaydet">
                <RemixIcon name={detailState.saved ? 'ri-bookmark-fill' : 'ri-bookmark-line'} size={25} />
              </button>
            </div>
            {showHeroShareMenu && (
              <div
                className="mobile-detail-hero-share-menu bg-white/95 backdrop-blur-xl rounded-[12px] shadow-[0_25px_60px_rgba(24,37,64,0.2)] border border-palette-beige/30 p-1.5 w-[220px] z-[99999] animate-in fade-in zoom-in-95 slide-in-from-bottom-2 duration-300 pointer-events-auto"
                onClick={(event) => event.stopPropagation()}
              >
                <div className="grid grid-cols-1 gap-0.5">
                  {heroShareMenuItems.map((item) => (
                    <button
                      key={item.key}
                      type="button"
                      onClick={item.onClick}
                      className={`w-full h-[38px] flex items-center gap-3 px-3 rounded-[8px] ${item.hoverClass} transition-all duration-300 group text-left`}
                    >
                      <span className="w-[20px] h-[20px] flex items-center justify-center">
                        {renderHeroShareMenuIcon(item)}
                      </span>
                      <span className="text-[11px] font-bold text-gray-600 group-hover:text-gray-900 transition-colors">{item.label}</span>
                    </button>
                  ))}

                  <div className="h-px bg-palette-beige/10 my-1 mx-2"></div>

                  <button
                    type="button"
                    onClick={() => void copyLink(true, 'copy_link', true).finally(closeHeroShareMenu)}
                    className="w-full h-[38px] flex items-center gap-3 px-3 rounded-[8px] hover:bg-palette-beige/10 transition-all duration-300 group text-left"
                  >
                    <span className="w-[20px] h-[20px] flex items-center justify-center text-palette-tan/60 group-hover:text-palette-tan transition-all">
                      <RemixIcon name="ri-link" size={20} className="transition-transform group-hover:scale-110" />
                    </span>
                    <span className="text-[11px] font-bold text-gray-600 group-hover:text-gray-900 transition-colors">{t('share.copy_link')}</span>
                  </button>
                </div>
              </div>
            )}
            {showPostDate && (
              <time className="mobile-detail-hero-date" dateTime={publishedAt.iso || undefined}>
                <RemixIcon name="ri-time-line" size={12} />
                {publishedAt.date ? publishedAt.date.replace(/\s+(Pazartesi|Salı|Çarşamba|Perşembe|Cuma|Cumartesi|Pazar)$/i, '') : data.timestamp}
                {publishedAt.time && <span>{publishedAt.time}</span>}
              </time>
            )}
          </div>
        </div>

        <div className="mobile-detail-sticky-title" style={mobileAppBarStyle}>
          <span aria-hidden="true" />
          <strong>{data.title}</strong>
          <button type="button" onClick={onBack} aria-label="Geri dön">
            <RemixIcon name="ri-arrow-left-line" size={20} />
          </button>
          <i style={{ width: `${scrollProgress}%` }} aria-hidden="true" />
        </div>

        <div className="mobile-detail-share-row" style={mobileDockStyle}>
          {!showMobileShareRail && (
            <button type="button" onClick={() => setShowMobileShareRail(true)} className="mobile-detail-share-pill">
              <RemixIcon name="ri-share-forward-line" size={12} />
              PAYLAŞ
            </button>
          )}
        </div>

        {showMobileShareRail && (
          <aside className="mobile-detail-share-rail" style={mobileDockStyle} aria-label="Paylaşım seçenekleri">
            <div className="mobile-detail-share-count">
              <strong>{detailCounts.shares.toLocaleString()}</strong>
              <span>PAYLAŞIM</span>
            </div>
            <button type="button" onClick={() => { void shareToInstagram(); setShowMobileShareRail(false); }} className="is-instagram" aria-label="Instagram'da paylaş">
              <RemixIcon name="ri-instagram-fill" size={18} />
            </button>
            <button type="button" onClick={() => { shareToFacebook(); setShowMobileShareRail(false); }} className="is-facebook" aria-label="Facebook'ta paylaş">
              <RemixIcon name="ri-facebook-fill" size={18} />
            </button>
            <button type="button" onClick={() => { shareToTwitter(); setShowMobileShareRail(false); }} className="is-x" aria-label="X'te paylaş">
              <RemixIcon name="ri-twitter-x-fill" size={17} />
            </button>
            <button type="button" onClick={() => { shareToWhatsApp(); setShowMobileShareRail(false); }} className="is-whatsapp" aria-label="WhatsApp'ta paylaş">
              <RemixIcon name="ri-whatsapp-fill" size={18} />
            </button>
            <button type="button" onClick={() => void toggleDetailLike()} className={detailState.liked ? 'is-like is-active' : 'is-like'} aria-label="Beğen" aria-pressed={detailState.liked}>
              <RemixIcon name={detailState.liked ? 'ri-thumb-up-fill' : 'ri-thumb-up-line'} size={17} />
              {detailCounts.likes > 0 && <span>{detailCounts.likes.toLocaleString()}</span>}
            </button>
            <button type="button" onClick={() => void toggleDetailDislike()} className={detailState.disliked ? 'is-dislike is-active' : 'is-dislike'} aria-label="Beğenme" aria-pressed={detailState.disliked}>
              <RemixIcon name={detailState.disliked ? 'ri-thumb-down-fill' : 'ri-thumb-down-line'} size={17} />
            </button>
            <button type="button" onClick={() => void toggleDetailSave()} className={detailState.saved ? 'is-save is-active' : 'is-save'} aria-label="Kaydet" aria-pressed={detailState.saved}>
              <RemixIcon name={detailState.saved ? 'ri-bookmark-fill' : 'ri-bookmark-line'} size={17} />
            </button>
            <button type="button" onClick={() => setShowMobileShareRail(false)} className="mobile-detail-share-close" aria-label="Paylaşımı kapat">
              × KAPAT
            </button>
          </aside>
        )}

        <section className="mobile-detail-lede">
          <div className="mobile-detail-author-row">
            {showPostAuthor && (
              authorUrl ? (
                <a href={authorUrl} className="mobile-detail-author-avatar">
                  <img src={withImageVariant(data.sourceAvatar || `https://picsum.photos/seed/auth${data.id}/100`, 180)} alt={displayAuthorName || data.author} width={92} height={92} loading="lazy" decoding="async" />
                  <span aria-hidden="true" />
                </a>
              ) : (
                <span className="mobile-detail-author-avatar">
                  <img src={withImageVariant(data.sourceAvatar || `https://picsum.photos/seed/auth${data.id}/100`, 180)} alt={displayAuthorName || data.author} width={92} height={92} loading="lazy" decoding="async" />
                  <span aria-hidden="true" />
                </span>
              )
            )}
            <div className="mobile-detail-author-copy">
              {showPostAuthor && (
                <div className="mobile-detail-author-name">
                  {authorUrl ? <a href={authorUrl}>{displayAuthorName || data.author}</a> : <span>{displayAuthorName || data.author}</span>}
                  <RemixIcon name="ri-verified-badge-fill" size={15} />
                </div>
              )}
              {categoryLine && <p>{categoryLine}</p>}
            </div>
            <PublisherFollowButton
              publisherId={data.publisherId}
              postId={data.id}
              initialFollowing={data.isFollowingPublisher}
              className="mobile-detail-follow"
            />
          </div>

          <div className="mobile-detail-read-row">
            <span><RemixIcon name="ri-book-open-line" size={13} /> {readingTime} dk okuma</span>
            {showPostViewCount && <span><RemixIcon name="ri-eye-line" size={13} /> {detailCounts.views.toLocaleString()} görüntüleme</span>}
          </div>

          {data.title && (
            <h1 className="mobile-detail-title">
              <span aria-hidden="true" />
              {data.title}
            </h1>
          )}
          {data.summary && (
            <div
              dangerouslySetInnerHTML={{ __html: data.summary }}
              className="mobile-detail-summary rich-text-content"
            />
          )}
        </section>
      </section>

      {/* TOP HEADER - FULL WIDTH AREA */}
      <div className={`hidden md:block px-6 md:px-10 pt-8 ${data.title || data.summary ? 'pb-6' : 'pb-4'} border-b border-gray-50 bg-gray-50/30 rounded-t-[5px]`}>
        {/* Breadcrumbs */}
        <nav className="flex flex-wrap items-center gap-2 text-[10px] font-bold text-gray-400 capitalize tracking-widest mb-6">
          <button onClick={onBack} className="flex items-center gap-1.5 hover:text-palette-red transition-colors">
            <RemixIcon name="ri-home-5-line" size={12} />
            <span>{t('nav.home')}</span>
          </button>
          {breadcrumbs.map((crumb, idx) => (
            <React.Fragment key={idx}>
              <RemixIcon name="ri-arrow-right-s-line" size={10} />
              <span className="hover:text-gray-600 transition-colors cursor-default">
                {t(crumb.label).toLowerCase()}
              </span>
            </React.Fragment>
          ))}
        </nav>

        {/* Header Section */}
        {(data.title || data.summary) && (
          <div className="w-full mb-6 max-w-full">
            {data.title && (
              <h1 className="news-title-font text-4xl md:text-5xl lg:text-6xl font-[800] text-gray-900 leading-[1.6] tracking-normal mb-4">
                {data.title}
              </h1>
            )}
            {data.summary && (
              <div
                dangerouslySetInnerHTML={{ __html: data.summary }}
                className="news-subtitle-font news-post-summary rich-text-content font-medium text-gray-500 leading-relaxed max-w-full"
              />
            )}
          </div>
        )}

        {/* Meta Info Bar */}
        <div className={`flex items-center justify-between pt-6 border-t border-gray-100 ${data.title || data.summary ? 'mt-6' : 'mt-2'}`}>
          <div className="flex items-center gap-4">
            {showPostAuthor && (
              authorUrl ? (
                <a href={authorUrl} className="w-14 h-14 rounded-full bg-white p-[2px] border border-palette-beige/70 shadow-[0_6px_18px_rgba(24,37,64,0.07)] overflow-hidden">
                  <img src={withImageVariant(data.sourceAvatar || `https://picsum.photos/seed/auth${data.id}/100`, 180)} alt={displayAuthorName || data.author} width={112} height={112} loading="lazy" decoding="async" className="w-full h-full rounded-full object-cover" />
                </a>
              ) : (
                <div className="w-14 h-14 rounded-full bg-white p-[2px] border border-palette-beige/70 shadow-[0_6px_18px_rgba(24,37,64,0.07)] overflow-hidden">
                  <img src={withImageVariant(data.sourceAvatar || `https://picsum.photos/seed/auth${data.id}/100`, 180)} alt={displayAuthorName || data.author} width={112} height={112} loading="lazy" decoding="async" className="w-full h-full rounded-full object-cover" />
                </div>
              )
            )}
            <div>
              {showPostAuthor && (
                <div className="flex items-center gap-2">
                  {authorUrl ? (
                    <a href={authorUrl} className="text-[15px] font-[800] tracking-tight text-gray-900 hover:text-palette-red transition-colors">{displayAuthorName || data.author}</a>
                  ) : (
                    <span className="text-[15px] font-[800] tracking-tight text-gray-900">{displayAuthorName || data.author}</span>
                  )}
                  <RemixIcon name="ri-verified-badge-fill" size={16} className="text-palette-red" />
                  <PublisherFollowButton
                    publisherId={data.publisherId}
                    postId={data.id}
                    initialFollowing={data.isFollowingPublisher}
                  />
                </div>
              )}
              <div className="flex items-center gap-2 text-[10px] text-palette-tan/45 font-bold leading-none mt-1">
                {showPostDate && (
                  <span className="flex items-center gap-1">
                    <RemixIcon name="ri-calendar-line" size={12} />
                    <time dateTime={publishedAt.iso || undefined}>{publishedAt.date || data.timestamp}</time>
                  </span>
                )}
                {publishedAt.time && <span className="flex items-center gap-1"><RemixIcon name="ri-time-line" size={12} /> {publishedAt.time}</span>}
                <span className="flex items-center gap-1"><RemixIcon name="ri-book-open-line" size={12} /> {readingTime} {t('news.reading_time')}</span>
                {showPostViewCount && <span className="flex items-center gap-1"><RemixIcon name="ri-eye-line" size={12} /> {detailCounts.views.toLocaleString()}</span>}
              </div>
            </div>
          </div>

          <div className="flex items-center gap-2 mt-4 md:mt-0">
            <div className="relative" ref={shareMenuRef}>
              <button
                type="button"
                onClick={handleShareMenu}
                aria-expanded={showShareMenu}
                className="flex items-center gap-2 px-5 py-2.5 bg-palette-maroon text-white rounded-[5px] text-xs font-black transition-all hover:bg-palette-red shadow-md active:scale-95"
              >
                <RemixIcon name="ri-share-forward-line" size={14} />
                <span>{t('common.share')}</span>
              </button>

              {showShareMenu && (
                <div
                  className="absolute right-0 top-full mt-3 w-[220px] bg-white/95 backdrop-blur-xl rounded-[12px] shadow-[0_25px_60px_rgba(24,37,64,0.2)] border border-palette-beige/30 p-1.5 z-[99999] animate-in fade-in zoom-in-95 slide-in-from-top-2 duration-300"
                  onClick={(event) => event.stopPropagation()}
                >
                  <div className="grid grid-cols-1 gap-0.5">
                    {shareMenuItems.map((item) => (
                      <button
                        key={item.key}
                        type="button"
                        onClick={item.onClick}
                        className={`w-full h-[38px] flex items-center gap-3 px-3 rounded-[8px] ${item.hoverClass} transition-all duration-300 group text-left`}
                      >
                        <span className={`w-[20px] h-[20px] flex items-center justify-center ${item.iconClass} transition-all group-hover:scale-110`}>
                          <RemixIcon name={item.icon} size={20} />
                        </span>
                        <span className="text-[11px] font-bold text-gray-600 group-hover:text-gray-900 transition-colors">{item.label}</span>
                      </button>
                    ))}

                    <div className="h-px bg-palette-beige/10 my-1 mx-2"></div>

                    <button
                      type="button"
                      onClick={() => void copyLink(true, 'copy_link', true)}
                      className="w-full h-[38px] flex items-center gap-3 px-3 rounded-[8px] hover:bg-palette-beige/10 transition-all duration-300 group text-left"
                    >
                      <span className="w-[20px] h-[20px] flex items-center justify-center text-palette-tan/60 transition-all group-hover:scale-110 group-hover:text-palette-tan">
                        <RemixIcon name="ri-link" size={20} />
                      </span>
                      <span className="text-[11px] font-bold text-gray-600 group-hover:text-gray-900 transition-colors">{t('share.copy_link')}</span>
                    </button>
                  </div>
                </div>
              )}
            </div>
            <button onClick={onBack} className="p-2.5 bg-white border border-gray-200 text-gray-400 rounded-[5px] hover:text-palette-red transition-all">
              <RemixIcon name="ri-arrow-left-line" size={20} />
            </button>
          </div>
        </div>
      </div>

      {/* CONTENT AREA WITH STICKY SIDEBAR */}
      <div className="flex flex-col md:flex-row relative">

        {/* LEFT STICKY SHARE BAR */}
        <aside className="hidden md:flex relative isolate flex-col items-center gap-3 sticky top-24 p-6 border-r border-gray-50 z-10 overflow-visible before:pointer-events-none before:absolute before:left-1/2 before:top-20 before:h-[440px] before:w-[150px] before:-translate-x-1/2 before:rounded-full before:bg-[radial-gradient(ellipse_at_center,rgba(125,190,255,0.22)_0%,rgba(186,226,255,0.13)_38%,rgba(255,255,255,0)_76%)] before:blur-2xl before:-z-10" style={{ height: 'fit-content', alignSelf: 'flex-start' }}>
          <div className="flex flex-col items-center mb-2">
            <span className="text-[10px] font-black text-gray-400 uppercase tracking-widest [writing-mode:vertical-lr] rotate-180 mb-2">{t('card.share')}</span>
            <div className="w-px h-8 bg-gray-100 mb-2"></div>
            <span className="text-xs font-black text-palette-red mb-2">{detailCounts.shares.toLocaleString()}</span>
          </div>

          <button
            onClick={shareToInstagram}
            aria-label="Instagram'da paylaş"
            className="w-10 h-10 flex items-center justify-center rounded-full border border-gray-100 bg-white text-[#E1306C] shadow-[0_8px_18px_rgba(15,23,42,0.08)] hover:scale-110 transition-all active:scale-95"
          >
            <RemixIcon name="ri-instagram-fill" size={18} />
          </button>
          <button
            onClick={shareToFacebook}
            aria-label="Facebook'ta paylaş"
            className="w-10 h-10 flex items-center justify-center rounded-full border border-gray-100 bg-white text-[#1877F2] shadow-[0_8px_18px_rgba(15,23,42,0.08)] hover:scale-110 transition-all active:scale-95"
          >
            <RemixIcon name="ri-facebook-fill" size={18} />
          </button>
          <button
            onClick={shareToTwitter}
            aria-label="X'te paylaş"
            className="w-10 h-10 flex items-center justify-center rounded-full border border-gray-100 bg-white text-[#0F1419] shadow-[0_8px_18px_rgba(15,23,42,0.08)] hover:scale-110 transition-all active:scale-95"
          >
            <RemixIcon name="ri-twitter-x-fill" size={18} />
          </button>
          <button
            onClick={shareToWhatsApp}
            aria-label="WhatsApp'ta paylaş"
            className="w-10 h-10 flex items-center justify-center rounded-full border border-gray-100 bg-white text-[#25D366] shadow-[0_8px_18px_rgba(15,23,42,0.08)] hover:scale-110 transition-all active:scale-95"
          >
            <RemixIcon name="ri-whatsapp-fill" size={18} />
          </button>

          <div className="h-2"></div>

          <div className="relative">
            <button
              onClick={toggleDetailLike}
              aria-label="Beğen"
              className={`w-10 h-10 flex items-center justify-center rounded-full border border-gray-100 shadow-[0_8px_18px_rgba(15,23,42,0.08)] hover:scale-110 transition-all active:scale-95 ${detailState.liked ? 'bg-palette-maroon text-white' : 'bg-white text-palette-maroon'}`}
            >
              <RemixIcon name={detailState.liked ? 'ri-thumb-up-fill' : 'ri-thumb-up-line'} size={17} />
            </button>
            {detailCounts.likes > 0 && (
              <span className="absolute -right-1 -top-1 min-w-[16px] rounded-full bg-palette-maroon px-1 text-center text-[9px] font-black leading-4 text-white shadow-sm">
                {detailCounts.likes.toLocaleString()}
              </span>
            )}
          </div>

          <div className="relative">
            <button
              onClick={toggleDetailDislike}
              aria-label="Beğenme"
              className={`w-10 h-10 flex items-center justify-center rounded-full border border-gray-100 shadow-[0_8px_18px_rgba(15,23,42,0.08)] hover:scale-110 transition-all active:scale-95 ${detailState.disliked ? 'bg-palette-red text-white' : 'bg-white text-palette-red'}`}
            >
              <RemixIcon name={detailState.disliked ? 'ri-thumb-down-fill' : 'ri-thumb-down-line'} size={17} />
            </button>
            {detailCounts.dislikes > 0 && (
              <span className="absolute -right-1 -top-1 min-w-[16px] rounded-full bg-palette-red px-1 text-center text-[9px] font-black leading-4 text-white shadow-sm">
                {detailCounts.dislikes.toLocaleString()}
              </span>
            )}
          </div>

          <div className="relative">
            <button
              onClick={toggleDetailSave}
              aria-label="Kaydet"
              className={`w-10 h-10 flex items-center justify-center rounded-full border border-gray-100 shadow-[0_8px_18px_rgba(15,23,42,0.08)] hover:scale-110 transition-all active:scale-95 ${detailState.saved ? 'bg-palette-accent text-palette-maroon' : 'bg-white text-palette-accent'}`}
            >
              <RemixIcon name={detailState.saved ? 'ri-bookmark-fill' : 'ri-bookmark-line'} size={17} />
            </button>
            {detailCounts.saves > 0 && (
              <span className="absolute -right-1 -top-1 min-w-[16px] rounded-full bg-palette-accent px-1 text-center text-[9px] font-black leading-4 text-palette-maroon shadow-sm">
                {detailCounts.saves.toLocaleString()}
              </span>
            )}
          </div>
        </aside>

        {/* MAIN BODY CONTENT */}
        <article className={`news-detail-body-article flex-1 min-w-0 px-6 md:px-12 ${data.title || data.summary ? 'pt-6' : 'pt-2'} pb-8 max-w-full md:mx-0 overflow-hidden`}>

          <AdSlot settings={adSettings} slotKey="web_article_top" className="news-detail-after-lede-ad mb-6" />

          {/* Main Media (Video, Poll, Gallery etc.) */}
          {(() => {
            const mediaContent = renderMedia();
            return mediaContent ? (
              <>
                <div className={`news-detail-main-media mb-6 overflow-hidden max-w-full ${hideMobilePrimaryMedia ? 'hidden md:block' : ''}`}>
                  {mediaContent}
                </div>
                <AdSlot settings={adSettings} slotKey="web_article_after_media" className={`news-detail-after-media-ad mb-8 ${hideMobilePrimaryMedia ? 'hidden md:block' : ''}`} />
              </>
            ) : null;
          })()}

          {/* Body Items Rendering */}
          <div className="space-y-12 overflow-hidden">
            {data.items && data.items.length > 0 ? (
              data.items.map((item: any, index: number) => {
                const content = (() => {
                switch (item.type) {
                  case 'text':
                    return (
                      <div key={item.id} className="rich-text-content prose prose-lg max-w-full text-gray-800">
                        {item.title && <h3 className="text-2xl font-black text-gray-900 mb-4">{item.title}</h3>}
                        <div dangerouslySetInnerHTML={{ __html: item.description || '' }} className="leading-[1.85] font-medium text-gray-700" />
                        {item.source && <p className="text-xs text-gray-400 mt-2 italic flex items-center gap-1"><RemixIcon name="ri-link" size={12} /> {t('news.source_prefix')} {item.source}</p>}
                      </div>
                    );
                  case 'image':
                    const itemImageSize = imageSizeAttrs({
                      width: item.width || item.imageWidth,
                      height: item.height || item.imageHeight,
                    });
                    return (
                      <div key={item.id} className="detail-media-item detail-media-item--image max-w-full overflow-hidden">
                        <DetailMediaIntro item={item} />
                        <div className="relative w-full bg-gray-50 rounded-[5px] overflow-hidden border border-gray-100 shadow-lg flex items-center justify-center max-h-[600px]">
                          <div
                            className="absolute inset-0 bg-center bg-no-repeat bg-cover blur-2xl opacity-10 scale-110"
                            style={{ backgroundImage: `url(${withImageVariant(item.mediaUrl, 64, 60)})` }}
                          />
                          <img
                            src={withImageVariant(item.mediaUrl, 1200)}
                            alt={item.altText || item.title || t('news.image_alt_default')}
                            width={itemImageSize.width}
                            height={itemImageSize.height}
                            loading="lazy"
                            decoding="async"
                            className="relative z-10 w-full h-auto max-h-[600px] object-contain"
                          />
                        </div>
                        <DetailItemExtraInfo item={item} />
                      </div>
                    );
                  case 'paragraph':
                  case 'quote':
                    return (
                      <div key={item.id} className="py-4">
                        <ParagraphCard
                          data={{
                            ...data,
                            summary: '', // Ana özetle karışmasın
                            paragraphData: {
                              items: item.description ? [item.description] : (item.paragraphData?.items || []),
                              quoteAuthor: item.title || item.paragraphData?.quoteAuthor
                            }
                          } as any}
                        />
                      </div>
                    );
                  case 'slider':
                    return <div key={item.id} className="detail-media-item detail-media-item--slider">
                      <DetailMediaIntro item={item} />
                      <GalleryCard data={{ ...data, summary: '', mediaList: item.mediaUrls } as any} />
                      <DetailItemExtraInfo item={item} />
                    </div>;
	                  case 'poll':
	                    return <DetailPollItemBlock key={item.id} item={item} />;
	                  case 'quiz':
	                    return renderQuizBlock(item);
	                  case 'toc':
	                    return <TableOfContentsBlock key={item.id} item={item} />;
	                  case 'recipe':
	                    return <RecipeBlock key={item.id} item={item} />;
	                  case 'event':
	                    return <EventBlock key={item.id} item={item} />;
	                  case 'vs':
                    return <div key={item.id} className="detail-media-item detail-media-item--vs">
                      <DetailMediaIntro item={item} />
                      <VSCard data={{ ...data, title: '', summary: '', items: [], options: item.options } as any} />
                      <DetailItemExtraInfo item={item} />
                    </div>;
                  case 'beforeafter':
                    return <div key={item.id} className="detail-media-item detail-media-item--beforeafter">
                      <DetailMediaIntro item={item} />
                      <BeforeAfterCard data={{ ...data, summary: '', beforeAfterData: item.beforeAfterData } as any} />
                      <DetailItemExtraInfo item={item} />
                    </div>;
                  case 'flipcard':
                    return <div key={item.id} className="detail-media-item detail-media-item--flipcard">
                      <DetailMediaIntro item={item} />
                      <FlipCard data={{ ...data, summary: '', flipData: item.flipData } as any} />
                      <DetailItemExtraInfo item={item} />
                    </div>;
                  case 'review':
                    return <div key={item.id} className="detail-media-item detail-media-item--review">
                      <ReviewCard data={{ ...data, summary: item.description || '', reviewData: item.reviewData } as any} />
                      <DetailItemExtraInfo item={item} />
                    </div>;
                  case 'video':
                    // Prevent duplicate video rendering at the end of the article if it matches the main media
                    if (data.type === NewsType.VIDEO && (item.mediaUrl === data.mediaUrl || item.mediaUrl === (data as any).videoUrl)) return null;
                    return <div key={item.id} className="detail-media-item detail-media-item--video">
                      <DetailMediaIntro item={item} />
                      <VideoCard data={{ ...data, summary: '', mediaUrl: item.mediaUrl, thumbnail: item.videoThumbUrl || item.thumbnail || data.thumbnail } as any} />
                      <DetailItemExtraInfo item={item} />
                    </div>;
                  case 'audio':
                    return <div key={item.id} className="detail-media-item detail-media-item--audio">
                      <DetailMediaIntro item={item} />
                      <AudioCard data={{ ...data, summary: '', mediaUrl: item.mediaUrl, thumbnail: item.thumbnail || data.thumbnail } as any} allowDownload={siteSettings?.content_audio_download_enabled !== false} />
                      <DetailItemExtraInfo item={item} />
                    </div>;
                  case 'social':
                  case 'iframe':
                  case 'embed':
                    return <div key={item.id} className="detail-media-item detail-media-item--embed">
                      <DetailMediaIntro item={item} />
                      <EmbedCard data={{ ...data, title: '', summary: '', mediaUrl: item.mediaUrl } as any} />
                      <DetailItemExtraInfo item={item} />
                    </div>;
                  default:
                    return null;
                }
                })();
                return (
                  <React.Fragment key={item.id || index}>
                    {content}
                    {index === 1 && (
                      <AdSlot settings={adSettings} slotKey="web_news_incontent" />
                    )}
                    {index === 3 && (
                      <AdSlot settings={adSettings} slotKey="web_article_midcontent" />
                    )}
                  </React.Fragment>
                );
              })
            ) : (
              <div
                className="rich-text-content prose prose-lg max-w-full text-gray-800"
                dangerouslySetInnerHTML={{ __html: data.content || t('news.content_not_found') }}
              />
            )}
          </div>

          {/* FAQ Section */}
          {data.faqData && data.faqData.length > 0 && (
            <div className="mt-8 border-t border-gray-100 pt-5">
              <div className="mb-2 text-[10.5px] font-extrabold uppercase leading-none tracking-[0.06em] text-palette-tan/45">
                FAQ
              </div>

              <div className="grid gap-1.5">
                {data.faqData.map((faq, idx) => (
                  <div
                    key={idx}
                    className={`rounded-[7px] border transition-colors duration-200 ${expandedFaqIndex === idx ? 'border-palette-beige bg-gray-50/80' : 'border-palette-beige/40 bg-gray-50/50'}`}
                  >
                    <button
                      type="button"
                      onClick={() => setExpandedFaqIndex((current) => current === idx ? null : idx)}
                      aria-expanded={expandedFaqIndex === idx}
                      className="flex w-full items-start gap-2 px-2.5 py-2 text-left"
                    >
                      <span className="mt-0.5 flex h-4 w-4 shrink-0 items-center justify-center rounded-[4px] bg-palette-red/5 text-[10px] font-black leading-none text-palette-red/60">
                        ?
                      </span>
                      <span className="min-w-0 flex-1 truncate text-[12px] font-medium leading-[1.2] text-gray-500/80">
                        {faq.q}
                      </span>
                      <RemixIcon
                        name="ri-arrow-down-s-line"
                        size={16}
                        className={`mt-0.5 shrink-0 text-palette-tan/45 transition-transform duration-200 ${expandedFaqIndex === idx ? 'rotate-180' : ''}`}
                      />
                    </button>
                    {expandedFaqIndex === idx && (
                      <div className="pb-3 pl-[34px] pr-6">
                        <p className="text-[11.5px] font-medium leading-[1.45] text-gray-500">
                          {faq.a}
                        </p>
                      </div>
                    )}
                  </div>
                ))}
              </div>
            </div>
          )}

          {/* Keywords/Tags */}
          {visibleKeywordTags.length > 0 && (
            <div className="mt-3 flex flex-wrap items-center gap-x-2 gap-y-1.5 border-b border-gray-100 pb-5 text-[11.2px] leading-[1.2]">
              <span className="font-medium text-gray-500/75">Etiketler:</span>
              {visibleKeywordTags.map((tag, idx) => (
                <button
                  key={idx}
                  type="button"
                  className="font-medium text-gray-500/80 underline decoration-[#f59e0b]/25 decoration-[1.1px] underline-offset-2 transition-colors hover:text-gray-700/90"
                >
                  #{tag.trim()}
                </button>
              ))}
              {hiddenKeywordCount > 0 && (
                <span className="text-[10.8px] font-medium text-palette-tan/45">+{hiddenKeywordCount}</span>
              )}
            </div>
          )}

          <AdSlot settings={adSettings} slotKey="web_article_end" className="mt-8" />

          {/* Emoji Reactions Section */}
          <div className="mt-0 py-5">
            <div className="flex items-center gap-2.5">
              <div className="flex h-[26px] w-[26px] shrink-0 items-center justify-center rounded-[4px] border border-gray-800/15 bg-gray-800/5 text-gray-800">
                <RemixIcon name="ri-questionnaire-line" size={15} />
              </div>
              <div className="min-w-0 flex-1">
                <h3 className="text-[13px] font-black leading-tight text-gray-900">Emojiyle Tepki Ver</h3>
                <p className="mt-0.5 text-[11.5px] font-semibold leading-tight text-palette-tan/55">Bu haber sana ne hissettirdi?</p>
              </div>
              <div className="flex shrink-0 items-center gap-1 rounded-[4px] bg-gray-100 px-2 py-1 text-[11px] font-black text-gray-600">
                <RemixIcon name="ri-group-line" size={12} />
                <span>{totalReactions}</span>
              </div>
            </div>

            <div className="mt-5 flex w-full items-start gap-1">
              {emojis.map((item) => {
                const isSelected = selectedEmojis.includes(item.id);
                const isDisabled = !isSelected && selectedEmojis.length >= MAX_REACTIONS;

                return (
                  <button
                    key={item.id}
                    type="button"
                    onClick={() => void toggleEmoji(item.id)}
                    aria-pressed={isSelected}
                    data-reaction-limited={isDisabled ? 'true' : undefined}
                    className={`news-detail-reaction-button group relative flex min-w-0 flex-1 flex-col items-center rounded-[8px] px-0 py-0 transition-opacity
                      ${isDisabled ? 'cursor-not-allowed opacity-45' : 'cursor-pointer'}
                    `}
                  >
                    <div
                      className="news-detail-reaction-disk relative flex h-[60px] w-[60px] items-center justify-center"
                      style={{
                        '--reaction-accent': item.accent,
                      } as React.CSSProperties}
                    >
                      {isSelected && (
                        <span
                          className="absolute -right-0.5 -top-0.5 z-10 flex h-4 w-4 items-center justify-center rounded-full border border-white text-white shadow-sm"
                          style={{ background: item.accent }}
                        >
                          <RemixIcon name="ri-check-line" size={11} />
                        </span>
                      )}
                      <span
                        className="absolute inset-1 rounded-full border shadow-[0_3px_8px_rgba(24,37,64,0.08)]"
                        style={{
                          borderColor: isSelected ? 'transparent' : `${item.accent}33`,
                          background: isSelected
                            ? `radial-gradient(circle at 25% 15%, color-mix(in srgb, ${item.accent} 72%, white), color-mix(in srgb, ${item.accent} 92%, white) 55%, color-mix(in srgb, ${item.accent} 88%, black))`
                            : `radial-gradient(circle at 25% 15%, color-mix(in srgb, ${item.accent} 10%, white), color-mix(in srgb, ${item.accent} 24%, white) 55%, color-mix(in srgb, ${item.accent} 24%, #f8fafc))`,
                        }}
                      />
                      <img
                        src={`${REACTION_ASSET_BASE}/${item.image}`}
                        alt={item.label}
                        width={46}
                        height={46}
                        loading="lazy"
                        decoding="async"
                        className="news-detail-reaction-image relative h-[46px] w-[46px] object-contain"
                      />
                    </div>
                    <span className={`mt-2 text-[13.5px] font-extrabold leading-none ${isSelected ? '' : 'text-gray-600'}`} style={{ color: isSelected ? item.accent : undefined }}>
                      {item.count}
                    </span>
                    <span
                      className={`mt-1 block min-h-[22px] w-full max-w-[58px] whitespace-normal text-center text-[9.4px] font-semibold leading-[1.08] text-palette-tan/55 sm:h-[14px] sm:min-h-0 sm:max-w-full sm:truncate sm:text-[10.3px] sm:leading-none ${isSelected ? 'font-extrabold' : ''}`}
                      style={{
                        color: isSelected ? item.accent : undefined,
                        overflowWrap: 'break-word',
                      }}
                    >
                      {item.label}
                    </span>
                  </button>
                );
              })}
            </div>
          </div>
          <div ref={articleProgressEndRef} aria-hidden="true" />

          {commentsEnabled && (
            <div id="news-detail-comments" className="news-detail-comments mt-4">
              <InlineCardComments
                postId={data.id}
                publisherId={data.publisherId}
                totalCount={data.comments || 0}
                commentApprovalEnabled={commentApprovalEnabled}
                emojiEnabled={emojiReactionsEnabled}
                loadImmediately
                showGuidance
              />
            </div>
          )}

        </article>
      </div>

      {/* Back to Top */}
      <button
        onClick={() => window.scrollTo({ top: 0, behavior: 'smooth' })}
        className={`hidden md:block fixed bottom-8 right-8 p-4 bg-white border border-gray-200 rounded-[5px] shadow-xl text-gray-400 hover:text-palette-red transition-all z-50 ${scrollProgress > 20 ? 'translate-y-0 opacity-100' : 'translate-y-10 opacity-0 pointer-events-none'}`}
      >
        <RemixIcon name="ri-arrow-right-s-line" size={20} className="-rotate-90" />
      </button>

      <style>{`
        @keyframes detail-reaction-bounce {
          0% { transform: scale(1) rotate(0deg); }
          35% { transform: scale(1.28) rotate(-5.73deg); }
          70% { transform: scale(1.06) rotate(5.73deg); }
          100% { transform: scale(1) rotate(0deg); }
        }
        @keyframes detail-reaction-ripple {
          0% {
            box-shadow: 0 0 0 0 color-mix(in srgb, var(--reaction-accent) 42%, transparent);
          }
          100% {
            box-shadow: 0 0 0 20px color-mix(in srgb, var(--reaction-accent) 0%, transparent);
          }
        }
        .news-detail-reaction-button:not([data-reaction-limited="true"]):hover .news-detail-reaction-disk,
        .news-detail-reaction-button:not([data-reaction-limited="true"]):focus-visible .news-detail-reaction-disk {
          animation: detail-reaction-bounce 540ms ease-out;
        }
        .news-detail-reaction-button:not([data-reaction-limited="true"]):active .news-detail-reaction-disk {
          animation: detail-reaction-bounce 540ms ease-out, detail-reaction-ripple 540ms ease-out;
        }
        @media (prefers-reduced-motion: reduce) {
          .news-detail-reaction-button:not([data-reaction-limited="true"]):hover .news-detail-reaction-disk,
          .news-detail-reaction-button:not([data-reaction-limited="true"]):focus-visible .news-detail-reaction-disk,
          .news-detail-reaction-button:not([data-reaction-limited="true"]):active .news-detail-reaction-disk {
            animation: none;
          }
        }
      `}</style>

    </div>
  );
};

export const NewsDetailSkeleton: React.FC = () => {
  return (
    <div className="bg-white rounded-[5px] border border-gray-200 shadow-sm relative min-h-screen mb-10 mt-2 p-8 space-y-8">
      {/* Header Skeleton */}
      <div className="space-y-4">
        <Skeleton className="w-24 h-3" />
        <Skeleton className="w-full h-12" />
        <Skeleton className="w-3/4 h-12" />
        <Skeleton className="w-full h-6" />
      </div>

      {/* Meta Skeleton */}
      <div className="flex items-center justify-between pt-6 border-t border-gray-100">
        <div className="flex items-center gap-4">
          <Skeleton variant="rectangular" className="w-12 h-12" />
          <div className="space-y-2">
            <Skeleton className="w-24 h-4" />
            <Skeleton className="w-32 h-3" />
          </div>
        </div>
        <Skeleton className="w-32 h-10" />
      </div>

      {/* Media Skeleton */}
      <Skeleton className="w-full h-[400px]" />

      {/* Content Skeleton */}
      <div className="space-y-4">
        <Skeleton className="w-full h-4" />
        <Skeleton className="w-full h-4" />
        <Skeleton className="w-5/6 h-4" />
        <Skeleton className="w-full h-4" />
        <Skeleton className="w-4/6 h-4" />
      </div>
    </div>
  );
};

export default NewsDetail;
