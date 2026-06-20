import { isPostId, formatPostDateParts } from '@/utils/helpers';
import React, { useState, useEffect, useCallback, useRef, useMemo } from 'react';
import { NewsType, type NewsItem, type SiteSettings, type NavigationItem } from '@/types';
import InlineCardComments from './InlineCardComments';
import { useToast } from '@/context/ToastContext';
import { supabase } from '@/lib/supabase';
import { useLanguage } from '@/context/LanguageContext';
import Skeleton from '@/components/ui/Skeleton';
import { prefetch } from 'astro:prefetch';
import { postAction } from '@/services/appActions';
import { getPostHref } from '@/utils/postUrl';
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

// Kart Bileşenleri
import ReviewCard from './cards/ReviewCard';
import BeforeAfterCard from './cards/BeforeAfterCard';
import FlipCard from './cards/FlipCard';
import EmbedCard from './cards/EmbedCard';
import AudioCard from './cards/AudioCard';
import VideoCard from './cards/VideoCard';
import GalleryCard from './cards/GalleryCard';
import PollCard from './cards/PollCard';
import VSCard from './cards/VSCard';
import StandardCard from './cards/StandardCard';
import ParagraphCard from './cards/ParagraphCard';

interface NewsCardProps {
  data: NewsItem;
  onSourceClick?: () => void;
  siteSettings?: SiteSettings | null;
  navItems?: NavigationItem[];
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

const titleCaseCategory = (value: string) => {
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

interface CardSocialActionProps {
  icon: string;
  activeIcon?: string;
  active?: boolean;
  count?: number;
  label: string;
  onClick: (event: React.MouseEvent<HTMLButtonElement>) => void;
  activeClassName?: string;
  iconSize?: number;
  className?: string;
}

const CardSocialAction: React.FC<CardSocialActionProps> = ({
  icon,
  activeIcon,
  active = false,
  count,
  label,
  onClick,
  activeClassName = 'text-gray-800',
  iconSize = 22,
  className = '',
}) => (
  <button
    type="button"
    onClick={onClick}
    aria-label={label}
    aria-pressed={active}
    className={`inline-flex items-center gap-1.5 rounded-[5px] px-1.5 py-1.5 transition-all duration-150 active:scale-95 ${active ? activeClassName : 'text-palette-tan/55 hover:text-gray-800'} ${className}`}
  >
    <RemixIcon name={active ? (activeIcon || icon) : icon} size={iconSize} className="transition-all duration-150" />
    {count !== undefined && (
      <span className="text-[12px] font-semibold leading-none">{count.toLocaleString()}</span>
    )}
  </button>
);

type VoteChoice = 'like' | 'dislike' | null;

interface VoteSnapshot {
  liked: boolean;
  disliked: boolean;
  likes: number;
  dislikes: number;
}

interface SaveSnapshot {
  saved: boolean;
  saves: number;
}

const getVoteChoice = (liked: boolean, disliked: boolean): VoteChoice => {
  if (liked) return 'like';
  if (disliked) return 'dislike';
  return null;
};

const getVoteToggleAction = (
  serverVote: VoteChoice,
  desiredVote: VoteChoice,
): 'toggle_like' | 'toggle_dislike' | null => {
  if (serverVote === desiredVote) return null;
  if (desiredVote === 'like') return 'toggle_like';
  if (desiredVote === 'dislike') return 'toggle_dislike';
  if (serverVote === 'like') return 'toggle_like';
  if (serverVote === 'dislike') return 'toggle_dislike';
  return null;
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

const NewsCard: React.FC<NewsCardProps> = ({ data, onSourceClick, siteSettings, navItems }) => {
  const { t, currentLang } = useLanguage();
  const { showToast } = useToast();
  const showPostAuthor = siteSettings?.content_show_post_author !== false;
  const showPostDate = siteSettings?.content_show_post_date !== false;
  const showPostViewCount = siteSettings?.content_show_post_view_count !== false;
  const commentsEnabled = siteSettings?.content_comment_system_enabled !== false;
  const commentApprovalEnabled = siteSettings?.content_comment_approval_enabled !== false;
  const emojiReactionsEnabled = siteSettings?.content_emoji_reactions_enabled !== false;
  const displaySourceName = titleCaseCategory(data.source || '');
  const displayPublisherHandle = String(data.publisherHandle || '').trim().replace(/^@+/, '');
  const publishedAt = formatPostDateParts(data.timestamp, currentLang.code);

  const detailHref = useMemo(() => {
    return getPostHref(data, siteSettings);
  }, [data, siteSettings]);

  const categoryHierarchy = useMemo(() => {
    const storedHierarchy = getStoredCategoryHierarchy(data);
    if (storedHierarchy.length > 0) return storedHierarchy;
    if (!data.category || !navItems) return uniqueCategoryLabels([data.category]);
    return buildNavigationCategoryHierarchy(data.category, navItems);
  }, [data, data.category, data.categoryPath, data.categoryTrail, navItems]);

  const [isLiked, setIsLiked] = useState(data.userLiked || false);
  const [isDisliked, setIsDisliked] = useState(data.userDisliked || false);
  const [showComments, setShowComments] = useState(commentsEnabled);
  const [isBookmarked, setIsBookmarked] = useState(data.userSaved || false);
  const [likesCount, setLikesCount] = useState(data.likes || 0);
  const [dislikesCount, setDislikesCount] = useState(data.dislikes || 0);
  const [savesCount, setSavesCount] = useState(data.saves || 0);
  const [sharesCount, setSharesCount] = useState(data.shares || 0);
  const [isLoading, setIsLoading] = useState(false);
  const [userId, setUserId] = useState<string | null>(null);
  const [publisherId, setPublisherId] = useState<string | null>(data.publisherId || null);
  const [isFollowing, setIsFollowing] = useState(data.isFollowingPublisher || false);
  const [isSourceHovering, setIsSourceHovering] = useState(false);
  const voteDraftRef = useRef<VoteSnapshot>({
    liked: data.userLiked || false,
    disliked: data.userDisliked || false,
    likes: data.likes || 0,
    dislikes: data.dislikes || 0,
  });
  const voteSyncRef = useRef<{
    inFlight: boolean;
    pending: VoteChoice | undefined;
    serverVote: VoteChoice;
    serverSnapshot: VoteSnapshot;
  }>({
    inFlight: false,
    pending: undefined,
    serverVote: getVoteChoice(data.userLiked || false, data.userDisliked || false),
    serverSnapshot: {
      liked: data.userLiked || false,
      disliked: data.userDisliked || false,
      likes: data.likes || 0,
      dislikes: data.dislikes || 0,
    },
  });
  const saveDraftRef = useRef<SaveSnapshot>({
    saved: data.userSaved || false,
    saves: data.saves || 0,
  });
  const saveSyncRef = useRef<{
    inFlight: boolean;
    pending: boolean | undefined;
    serverSaved: boolean;
    serverSnapshot: SaveSnapshot;
  }>({
    inFlight: false,
    pending: undefined,
    serverSaved: data.userSaved || false,
    serverSnapshot: {
      saved: data.userSaved || false,
      saves: data.saves || 0,
    },
  });

  const applyVoteSnapshot = useCallback((snapshot: VoteSnapshot) => {
    voteDraftRef.current = snapshot;
    setIsLiked(snapshot.liked);
    setIsDisliked(snapshot.disliked);
    setLikesCount(snapshot.likes);
    setDislikesCount(snapshot.dislikes);
  }, []);

  const applyVoteChoice = useCallback((nextVote: VoteChoice) => {
    const current = voteDraftRef.current;
    const previousVote = getVoteChoice(current.liked, current.disliked);
    let nextLikes = current.likes;
    let nextDislikes = current.dislikes;

    if (previousVote === 'like') nextLikes -= 1;
    if (previousVote === 'dislike') nextDislikes -= 1;
    if (nextVote === 'like') nextLikes += 1;
    if (nextVote === 'dislike') nextDislikes += 1;

    applyVoteSnapshot({
      liked: nextVote === 'like',
      disliked: nextVote === 'dislike',
      likes: Math.max(0, nextLikes),
      dislikes: Math.max(0, nextDislikes),
    });
  }, [applyVoteSnapshot]);

  const syncVotePreference = useCallback(async () => {
    const sync = voteSyncRef.current;
    if (sync.inFlight || !isPostId(data.id)) return;
    sync.inFlight = true;

    try {
      while (sync.pending !== undefined) {
        const desiredVote = sync.pending;
        sync.pending = undefined;
        const action = getVoteToggleAction(sync.serverVote, desiredVote);
        if (!action) continue;

        try {
          const result = await postAction<any>(action, { postId: data.id, publisherId });
          const serverSnapshot = {
            liked: !!result.userState?.liked,
            disliked: !!result.userState?.disliked,
            likes: result.counts?.likes ?? voteDraftRef.current.likes,
            dislikes: result.counts?.dislikes ?? voteDraftRef.current.dislikes,
          };
          sync.serverVote = getVoteChoice(serverSnapshot.liked, serverSnapshot.disliked);
          sync.serverSnapshot = serverSnapshot;
          if (sync.pending === undefined) {
            applyVoteSnapshot(serverSnapshot);
          }
        } catch {
          if (sync.pending !== undefined) continue;
          applyVoteSnapshot(sync.serverSnapshot);
          showToast(
            t(desiredVote === 'dislike' ? 'common.dislike_failed' : 'common.like_failed'),
            'error',
          );
          return;
        }
      }
    } finally {
      sync.inFlight = false;
    }
  }, [data.id, publisherId, applyVoteSnapshot, showToast, t]);

  const applySaveSnapshot = useCallback((snapshot: SaveSnapshot) => {
    saveDraftRef.current = snapshot;
    setIsBookmarked(snapshot.saved);
    setSavesCount(snapshot.saves);
  }, []);

  const applySaveChoice = useCallback((nextSaved: boolean) => {
    const current = saveDraftRef.current;
    const delta = nextSaved === current.saved ? 0 : nextSaved ? 1 : -1;
    applySaveSnapshot({
      saved: nextSaved,
      saves: Math.max(0, current.saves + delta),
    });
  }, [applySaveSnapshot]);

  const syncSavePreference = useCallback(async () => {
    const sync = saveSyncRef.current;
    if (sync.inFlight || !isPostId(data.id)) return;
    sync.inFlight = true;

    try {
      while (sync.pending !== undefined) {
        const desiredSaved = sync.pending;
        sync.pending = undefined;
        if (sync.serverSaved === desiredSaved) continue;

        try {
          const result = await postAction<any>('toggle_save', { postId: data.id, publisherId });
          const serverSnapshot = {
            saved: !!result.userState?.saved,
            saves: result.counts?.saves ?? saveDraftRef.current.saves,
          };
          sync.serverSaved = serverSnapshot.saved;
          sync.serverSnapshot = serverSnapshot;
          if (sync.pending === undefined) {
            applySaveSnapshot(serverSnapshot);
          }
        } catch {
          if (sync.pending !== undefined) continue;
          applySaveSnapshot(sync.serverSnapshot);
          showToast(t('common.bookmark_failed'), 'error');
          return;
        }
      }
    } finally {
      sync.inFlight = false;
    }
  }, [data.id, publisherId, applySaveSnapshot, showToast, t]);

  useEffect(() => {
    setShowComments(commentsEnabled);
  }, [commentsEnabled, data.id]);

  useEffect(() => {
    const voteSnapshot = {
      liked: data.userLiked || false,
      disliked: data.userDisliked || false,
      likes: data.likes || 0,
      dislikes: data.dislikes || 0,
    };
    voteSyncRef.current = {
      inFlight: false,
      pending: undefined,
      serverVote: getVoteChoice(voteSnapshot.liked, voteSnapshot.disliked),
      serverSnapshot: voteSnapshot,
    };
    applyVoteSnapshot(voteSnapshot);
    const saveSnapshot = {
      saved: data.userSaved || false,
      saves: data.saves || 0,
    };
    saveSyncRef.current = {
      inFlight: false,
      pending: undefined,
      serverSaved: saveSnapshot.saved,
      serverSnapshot: saveSnapshot,
    };
    applySaveSnapshot(saveSnapshot);
    setSharesCount(data.shares || 0);
    setPublisherId(data.publisherId || null);
    setIsFollowing(data.isFollowingPublisher || false);
  }, [
    data.id,
    data.userLiked,
    data.userDisliked,
    data.userSaved,
    data.likes,
    data.dislikes,
    data.saves,
    data.shares,
    data.publisherId,
    data.isFollowingPublisher,
    applyVoteSnapshot,
    applySaveSnapshot,
  ]);

  const readingTime = useMemo(() => {
    const wordsPerMinute = 200;
    const itemContent = data.items?.map((item: any) => `${item?.title || ''} ${item?.description || ''}`).join(' ') || '';
    const totalContent = `${data.title || ''} ${data.summary || ''} ${data.content || ''} ${itemContent}`;
    const words = stripHtmlToText(totalContent).split(/\s+/).filter(Boolean).length;
    return Math.max(1, Math.ceil(words / wordsPerMinute));
  }, [data.title, data.summary, data.content, data.items]);

  // Kullanıcı ve mevcut like/save durumunu kontrol et
  useEffect(() => {
    let isMounted = true;
    const checkUserAndStatus = async () => {
      if (!isPostId(data.id)) return;

      try {
        // 🚀 2026 Optimization: Use getSession() which is faster (reads from local storage)
        const { data: { session } } = await supabase.auth.getSession();
        const user = session?.user;

        if (user && isMounted) {
          setUserId(user.id);

          const state = await postAction<any>('state', { postId: data.id, publisherId: data.publisherId });

          if (!isMounted) return;

          const voteSnapshot = {
            liked: !!state.userState?.liked,
            disliked: !!state.userState?.disliked,
            likes: state.counts?.likes ?? data.likes ?? 0,
            dislikes: state.counts?.dislikes ?? data.dislikes ?? 0,
          };
          voteSyncRef.current.serverVote = getVoteChoice(voteSnapshot.liked, voteSnapshot.disliked);
          voteSyncRef.current.serverSnapshot = voteSnapshot;
          if (!voteSyncRef.current.inFlight && voteSyncRef.current.pending === undefined) {
            applyVoteSnapshot(voteSnapshot);
          }
          const saveSnapshot = {
            saved: !!state.userState?.saved,
            saves: state.counts?.saves ?? data.saves ?? 0,
          };
          saveSyncRef.current.serverSaved = saveSnapshot.saved;
          saveSyncRef.current.serverSnapshot = saveSnapshot;
          if (!saveSyncRef.current.inFlight && saveSyncRef.current.pending === undefined) {
            applySaveSnapshot(saveSnapshot);
          }
          setIsFollowing(!!state.userState?.following);
          setSharesCount(state.counts?.shares ?? data.shares ?? 0);
        } else if (isMounted) {
          setUserId(null);
        }
      } catch (error) {
        console.error("Error checking user status:", error);
      }
    };

    checkUserAndStatus();
    const { data: { subscription } } = supabase.auth.onAuthStateChange(() => {
      void checkUserAndStatus();
    });
    return () => {
      isMounted = false;
      subscription.unsubscribe();
    };
  }, [data.id, data.publisherId, data.likes, data.dislikes, data.shares, data.saves, applyVoteSnapshot, applySaveSnapshot]);

  const handleLike = useCallback(async (e: React.MouseEvent) => {
    e.stopPropagation();

    const activeUserId = userId || (await supabase.auth.getSession()).data.session?.user?.id || null;
    if (!activeUserId || !isPostId(data.id)) {
      if (!activeUserId) showToast(t('auth.login_required_like'), 'info');
      return;
    }
    if (!userId) setUserId(activeUserId);

    const nextVote = voteDraftRef.current.liked ? null : 'like';
    applyVoteChoice(nextVote);
    voteSyncRef.current.pending = nextVote;
    void syncVotePreference();
  }, [userId, data.id, applyVoteChoice, syncVotePreference, showToast, t]);

  const handleDislike = useCallback(async (e: React.MouseEvent) => {
    e.stopPropagation();

    const activeUserId = userId || (await supabase.auth.getSession()).data.session?.user?.id || null;
    if (!activeUserId || !isPostId(data.id)) {
      if (!activeUserId) showToast(t('auth.login_required_dislike'), 'info');
      return;
    }
    if (!userId) setUserId(activeUserId);

    const nextVote = voteDraftRef.current.disliked ? null : 'dislike';
    applyVoteChoice(nextVote);
    voteSyncRef.current.pending = nextVote;
    void syncVotePreference();
  }, [userId, data.id, applyVoteChoice, syncVotePreference, showToast, t]);

  const handleFollow = useCallback(async (e: React.MouseEvent) => {
    e.stopPropagation();
    if (isLoading || !publisherId || !userId) {
      if (!userId) showToast(t('auth.login_required_follow'), 'info');
      return;
    }

    setIsLoading(true);
    try {
      const result = await postAction<{ following: boolean }>('toggle_follow', { publisherId });
      setIsFollowing(result.following);
    } catch (error) {
      showToast(t('common.follow_failed'), 'error');
    } finally {
      setIsLoading(false);
    }
  }, [isFollowing, isLoading, publisherId, userId, showToast]);

  // Kaydetme işlemi (giriş gerektirir)
  const handleSave = useCallback(async (e: React.MouseEvent) => {
    e.stopPropagation();

    const activeUserId = userId || (await supabase.auth.getSession()).data.session?.user?.id || null;
    if (!activeUserId || !isPostId(data.id)) {
      if (!activeUserId) showToast(t('auth.login_required_bookmark'), 'info');
      return;
    }
    if (!userId) setUserId(activeUserId);

    const nextSaved = !saveDraftRef.current.saved;
    applySaveChoice(nextSaved);
    saveSyncRef.current.pending = nextSaved;
    void syncSavePreference();
  }, [userId, data.id, applySaveChoice, syncSavePreference, showToast, t]);

  // Paylaş menüsü state
  const [showShareMenu, setShowShareMenu] = useState(false);

  // Paylaş işlemi
  const handleShare = (e: React.MouseEvent) => {
    e.stopPropagation();
    setShowShareMenu(!showShareMenu);
  };

  const shareMenuRef = useRef<HTMLDivElement>(null);

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

  // 2026 SEO & AI Optimized Sharing Config
  const shareUrl = typeof window !== 'undefined'
    ? `${window.location.origin}${detailHref}`
    : '';

  const recordShare = async (platform: string) => {
    try {
      const result = await postAction<any>('share', { postId: data.id, publisherId, platform });
      setSharesCount(result.counts?.shares ?? sharesCount + 1);
    } catch {
      setSharesCount((prev) => prev + 1);
    }
  };

  const getUtmUrl = (platform: string) => {
    return buildTrackedShareUrl(shareUrl, {
      platform,
      campaign: 'share_card',
      contentId: data.id,
    });
  };

  const getAIOptimizedText = () => {
    return buildShareText({
      title: data.title,
      summary: data.summary,
      category: data.category,
      siteName: siteSettings?.site_name || 'Haber',
      keywords: data.keywords || siteSettings?.meta_keywords,
    });
  };

  // Sosyal medya paylaşım fonksiyonları
  const shareToWhatsApp = () => {
    void recordShare('whatsapp');
    const text = getAIOptimizedText();
    const url = getUtmUrl('whatsapp');
    const finalMessage = `${text}\n\n🔗 Hemen oku: ${url}`;
    openShareWindow(buildWhatsAppShareUrl(finalMessage));
    setShowShareMenu(false);
  };

  const shareToTelegram = () => {
    void recordShare('telegram');
    const text = getAIOptimizedText();
    const url = getUtmUrl('telegram');
    openShareWindow(buildTelegramShareUrl(url, text));
    setShowShareMenu(false);
  };

  const shareToTwitter = () => {
    void recordShare('twitter');
    const stripHtml = stripHtmlToText;
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
    const copied = await copyLink(false, false, 'instagram');
    showToast(copied ? t('common.link_copied_instagram') : t('common.copy_failed_alt'), copied ? 'info' : 'error');
    window.setTimeout(() => openShareWindow('https://www.instagram.com/'), 1000);
    setShowShareMenu(false);
  };

  const shareToTikTok = async () => {
    void recordShare('tiktok');
    const copied = await copyLink(false, false, 'tiktok');
    showToast(copied ? t('common.link_copied_tiktok') : t('common.copy_failed_alt'), copied ? 'info' : 'error');
    window.setTimeout(() => openShareWindow('https://www.tiktok.com/'), 1000);
    setShowShareMenu(false);
  };

  const shareToSocial = async () => {
    void recordShare('nsosyal');
    const url = getUtmUrl('nsosyal');
    const text = getAIOptimizedText();

    const stripHtml = stripHtmlToText;
    const cleanTitle = stripHtml(data.title);

    if (navigator.share) {
      try {
        await navigator.share({
          title: cleanTitle,
          text: text,
          url: url,
        });
      } catch (error) {
        if (!isShareAbortError(error)) {
          const copied = await copyLink(false, false, 'nsosyal');
          showToast(copied ? t('common.link_copied_short') : t('common.copy_failed_alt'), copied ? 'success' : 'error');
          if (copied) window.setTimeout(() => openShareWindow('https://nsosyal.com/'), 600);
        }
      }
    } else {
      const copied = await copyLink(false, false, 'nsosyal');
      showToast(copied ? t('common.link_copied_short') : t('common.copy_failed_alt'), copied ? 'success' : 'error');
      if (copied) window.setTimeout(() => openShareWindow('https://nsosyal.com/'), 600);
    }
    setShowShareMenu(false);
  };

  const copyLink = async (showNotification = true, track = true, platform = 'copy_link') => {
    if (track) void recordShare(platform);
    const url = getUtmUrl(platform);
    const copied = await writeToClipboard(url);
    if (showNotification) showToast(copied ? t('common.link_copied_short') : t('common.copy_failed_alt'), copied ? 'success' : 'error');
    setShowShareMenu(false);
    return copied;
  };

  const shareMenuItems: ShareMenuItem[] = [
    { key: 'whatsapp', label: t('share.whatsapp'), icon: 'ri-whatsapp-fill', iconClass: 'text-[#25D366]', hoverClass: 'hover:bg-[#25D366]/10', onClick: shareToWhatsApp },
    { key: 'telegram', label: t('share.telegram'), icon: 'ri-telegram-fill', iconClass: 'text-[#229ED9]', hoverClass: 'hover:bg-[#229ED9]/10', onClick: shareToTelegram },
    { key: 'twitter', label: t('share.x_twitter'), icon: 'ri-twitter-x-fill', iconClass: 'text-[#0F1419]', hoverClass: 'hover:bg-black/5', onClick: shareToTwitter },
    { key: 'facebook', label: t('share.facebook'), icon: 'ri-facebook-fill', iconClass: 'text-[#1877F2]', hoverClass: 'hover:bg-[#1877F2]/10', onClick: shareToFacebook },
    { key: 'instagram', label: t('share.instagram'), icon: 'ri-instagram-fill', iconClass: 'bg-[radial-gradient(circle_at_30%_107%,#fdf497_0%,#fdf497_5%,#fd5949_45%,#d6249f_60%,#285AEB_90%)] bg-clip-text text-transparent', hoverClass: 'hover:bg-[#E1306C]/10', onClick: shareToInstagram },
    { key: 'tiktok', label: t('share.tiktok'), customIcon: 'tiktok', hoverClass: 'hover:bg-[#FE2C55]/10', onClick: shareToTikTok },
    { key: 'nsosyal', label: t('share.nsosyal'), imageSrc: NSOSYAL_ICON_SRC, imageClass: 'rounded-[4px]', hoverClass: 'hover:bg-[#2F5BFF]/10', onClick: shareToSocial },
  ];

  const renderShareMenuIcon = (item: ShareMenuItem) => {
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

  const renderContent = () => {
    switch (data.type) {
      case NewsType.REVIEW: return <ReviewCard data={data} />;
      case NewsType.BEFORE_AFTER: return <BeforeAfterCard data={data} />;
      case NewsType.FLIP_CARD: return <FlipCard data={data} />;
      case NewsType.EMBED: return <EmbedCard data={data} />;
      case NewsType.AUDIO: return <AudioCard data={data} allowDownload={siteSettings?.content_audio_download_enabled !== false} />;
      case NewsType.VIDEO: return <VideoCard data={data} layout="feed" />;
      case NewsType.GALLERY: return <GalleryCard data={data} />;
      case NewsType.POLL: return <PollCard data={data} />;
      case NewsType.QUIZ: return <PollCard data={data} />;
      case NewsType.VS: return <VSCard data={data} />;
      case NewsType.PARAGRAPH: return <ParagraphCard data={data} />;
      case NewsType.IMAGE:
      case NewsType.STANDARD:
      default: return <StandardCard data={data} />;
    }
  };

  const usesMobileMediaOverlay = [
    NewsType.STANDARD,
    NewsType.IMAGE,
    NewsType.VIDEO,
    NewsType.GALLERY,
  ].includes(data.type);

  const handleCardNavigate = (e: React.MouseEvent<HTMLAnchorElement>) => {
    // Allow standard browser behaviors (new tab, etc.)
    if (
      e.defaultPrevented ||
      e.button !== 0 ||
      e.metaKey ||
      e.ctrlKey ||
      e.shiftKey ||
      e.altKey
    ) {
      return;
    }
    document.getElementById('route-loading')?.classList.add('is-active');
  };

  const handleSourceAction = (e: React.MouseEvent) => {
    e.preventDefault();
    e.stopPropagation();
    onSourceClick?.();
  };

  const sourceHoverHandlers = {
    onMouseEnter: () => setIsSourceHovering(true),
    onMouseLeave: () => setIsSourceHovering(false),
    onFocus: () => setIsSourceHovering(true),
    onBlur: () => setIsSourceHovering(false),
  };

  return (
    <div
      className={`public-news-card ${usesMobileMediaOverlay ? 'public-news-card--mobile-media-overlay' : ''} bg-white rounded-[5px] border border-palette-beige/30 shadow-[0_2px_20px_rgba(24,37,64,0.03)] transition-all duration-100 hover:shadow-[0_8px_30px_rgba(24,37,64,0.06)] hover:border-palette-red/10 cursor-pointer group/card relative`}
    >
      <a
        href={detailHref}
        onClick={handleCardNavigate}
        onMouseEnter={() => prefetch(detailHref)}
        onFocus={() => prefetch(detailHref)}
        className="absolute inset-0 cursor-pointer"
        aria-label={data.title}
      >
        <span className="sr-only">{data.title}</span>
      </a>

      <div className="public-news-card-body relative pointer-events-none [&_button]:pointer-events-auto [&_input]:pointer-events-auto [&_textarea]:pointer-events-auto [&_select]:pointer-events-auto [&_a]:pointer-events-auto [&_.video-interact-area]:pointer-events-auto [&_.card-interact-area]:pointer-events-auto">
        {/* HEADER */}
        <div className="public-news-card-header px-6 pt-6 pb-2 flex items-center justify-between">
          <div className="flex items-center gap-3.5">
            {showPostAuthor && (
              <div
                onClick={handleSourceAction}
                {...sourceHoverHandlers}
                className="public-news-card-avatar w-12 h-12 rounded-full bg-white p-[2px] border border-palette-beige/70 shadow-[0_6px_18px_rgba(24,37,64,0.07)] cursor-pointer group/avatar relative pointer-events-auto"
              >
                <div className="w-full h-full rounded-full overflow-hidden">
                  <img
                    src={data.sourceAvatar || `https://picsum.photos/seed/source${data.id}/100`}
                    className="w-full h-full object-cover transition-transform duration-500 group-hover/avatar:scale-110"
                    alt={displaySourceName || data.source}
                  />
                </div>
                <div className="public-news-card-avatar-status absolute -bottom-0.5 -right-0.5 w-4 h-4 bg-white rounded-full flex items-center justify-center border border-palette-beige/60 shadow-sm">
                  <div className="w-2 h-2 bg-green-500 rounded-full animate-pulse"></div>
                </div>
              </div>
            )}

            <div>
              {showPostAuthor && (
                <div className="flex items-center gap-2">
                  <div
                    onClick={handleSourceAction}
                    {...sourceHoverHandlers}
                    className="public-news-card-author-line flex items-center gap-1.5 cursor-pointer group/title pointer-events-auto min-w-0"
                  >
                    <h5 className="public-news-card-source-name text-[15px] font-[800] text-gray-900 tracking-tight group-hover/title:text-palette-red transition-colors truncate">
                      {displaySourceName || data.source}
                    </h5>
                    <RemixIcon name="ri-verified-badge-fill" size={16} className="text-palette-red" />
                    {displayPublisherHandle && (
                      <span className="public-news-card-publisher-handle hidden truncate">
                        @{displayPublisherHandle}
                      </span>
                    )}
                  </div>

                  {userId && publisherId && publisherId !== userId && (
                    <button
                      onClick={handleFollow}
                      className={`tracking-normal text-[9px] font-[800] px-2 py-0.5 rounded-full transition-all ${isFollowing ? 'text-gray-400 bg-gray-100' : 'text-blue-600 bg-blue-50 hover:bg-blue-600 hover:text-white'}`}
                    >
                      {isFollowing ? t('common.following') : t('common.follow')}
                    </button>
                  )}
                </div>
              )}

              <div className="public-news-card-meta flex items-center gap-1.5 text-[10px] font-bold text-palette-tan/40 leading-none mt-1">
                <div className="flex items-center gap-1">
                  {categoryHierarchy.map((cat, idx) => (
                    <React.Fragment key={idx}>
                      {/* CATEGORY COLORS - Changed to gray-500 as requested */}
                      <span className="text-gray-500 font-[800] tracking-normal text-[9px]">{titleCaseCategory(t(cat))}</span>
                      {idx < categoryHierarchy.length - 1 && <span className="text-gray-500 mx-0.5 text-[8px]">/</span>}
                    </React.Fragment>
                  ))}
                </div>
                {showPostDate && (
                  <>
                    <span className="w-0.5 h-0.5 bg-palette-beige rounded-[5px]"></span>
                    <span className="font-medium">{publishedAt.date || data.timestamp}</span>
                    {publishedAt.time && (
                      <>
                        <RemixIcon name="ri-time-line" size={11} className="opacity-80" />
                        <span className="font-medium">{publishedAt.time}</span>
                      </>
                    )}
                  </>
                )}
              </div>
            </div>
          </div>
          {/* PINNED INDICATOR */}
          {data.isPinned && (
            <div className="flex items-center gap-1.5 px-3 py-1 bg-amber-500/5 border border-amber-100 rounded-[5px] text-amber-600 animate-in fade-in slide-in-from-right-4 duration-500">
              <RemixIcon name="ri-pushpin-fill" size={16} />
              <span className="text-[10px] font-black uppercase tracking-widest hidden sm:inline-block">{t('news.featured')}</span>
            </div>
          )}
        </div>

        {/* CONTENT Title */}
        <div className="public-news-card-title px-6 pt-2 pb-0.5">
          {data.type !== NewsType.EMBED && (
            <h3 className={`news-title-font text-[38px] font-[800] leading-[1.08] tracking-[-0.025em] text-gray-900 transition-colors ${isSourceHovering ? '' : 'group-hover/card:text-palette-red'}`}>
              {data.title}
            </h3>
          )}
        </div>

        {usesMobileMediaOverlay && data.summary && (
          <div
            className="public-news-card-mobile-summary hidden news-subtitle-font rich-text-content text-gray-600/80 text-[16px] leading-relaxed font-medium text-left [&>p]:mb-0"
            dangerouslySetInnerHTML={{ __html: data.summary }}
          />
        )}

        {/* MEDIA CONTENT */}
        <div className="public-news-card-media px-6 pb-2 rounded-[5px] overflow-hidden">{renderContent()}</div>

        {/* INTERACTION BAR */}
        <div className="public-news-card-actions mt-0.5 border-t border-palette-beige/20 bg-white relative z-[100]">
          <div className="px-6 pt-3 pb-1 flex items-center gap-3 text-[12px] font-semibold text-palette-tan/45">
            <span className="flex items-center gap-1.5">
              <RemixIcon name="ri-book-open-line" size={14} />
              {readingTime} {t('news.reading_time')}
            </span>
            {showPostViewCount && (
              <span className="flex items-center gap-1.5">
                <RemixIcon name="ri-eye-line" size={14} />
                {(data.views || 0).toLocaleString()} görüntüleme
              </span>
            )}
          </div>

          <div className="px-6 pb-2 flex items-center justify-between">
            <div className="flex items-center gap-1 min-w-0">
              <CardSocialAction
                icon="ri-thumb-up-line"
                activeIcon="ri-thumb-up-fill"
                active={isLiked}
                count={likesCount}
                label="Beğen"
                onClick={handleLike}
                activeClassName="text-gray-800"
                iconSize={22}
              />
              <CardSocialAction
                icon="ri-thumb-down-line"
                activeIcon="ri-thumb-down-fill"
                active={isDisliked}
                count={dislikesCount}
                label="Beğenme"
                onClick={handleDislike}
                activeClassName="text-palette-red"
                iconSize={22}
              />
              {commentsEnabled && (
                <CardSocialAction
                  icon="ri-chat-3-line"
                  activeIcon="ri-chat-3-fill"
                  active={showComments}
                  count={data.comments}
                  label="Yorumlar"
                  onClick={(event) => {
                    event.stopPropagation();
                    setShowComments((value) => !value);
                  }}
                  activeClassName="text-gray-800"
                  iconSize={24}
                />
              )}

              <div className="relative" ref={shareMenuRef}>
                <CardSocialAction
                  icon="ri-share-forward-line"
                  active={false}
                  count={sharesCount}
                  label={t('common.share')}
                  onClick={handleShare}
                  iconSize={24}
                />

                {/* Paylaş Menüsü */}
                {showShareMenu && (
                  <div
                    className="absolute bottom-full left-0 mb-3 bg-white/95 backdrop-blur-xl rounded-[12px] shadow-[0_25px_60px_rgba(24,37,64,0.2)] border border-palette-beige/30 p-1.5 min-w-[220px] z-[99999] animate-in fade-in zoom-in-95 slide-in-from-bottom-2 duration-300 pointer-events-auto"
                    onClick={(e) => e.stopPropagation()}
                  >
                    <div className="grid grid-cols-1 gap-0.5">
                      {shareMenuItems.map((item) => (
                        <button
                          key={item.key}
                          type="button"
                          onClick={item.onClick}
                          className={`w-full h-[38px] flex items-center gap-3 px-3 rounded-[8px] ${item.hoverClass} transition-all duration-300 group text-left`}
                        >
                          <span className="w-[20px] h-[20px] flex items-center justify-center">
                            {renderShareMenuIcon(item)}
                          </span>
                          <span className="text-[11px] font-bold text-gray-600 group-hover:text-gray-900 transition-colors">{item.label}</span>
                        </button>
                      ))}

                      <div className="h-px bg-palette-beige/10 my-1 mx-2"></div>

                      <button type="button" onClick={() => copyLink()} className="w-full h-[38px] flex items-center gap-3 px-3 rounded-[8px] hover:bg-palette-beige/10 transition-all duration-300 group text-left">
                        <span className="w-[20px] h-[20px] flex items-center justify-center text-palette-tan/60 group-hover:text-palette-tan transition-all">
                          <RemixIcon name="ri-link" size={20} className="transition-transform group-hover:scale-110" />
                        </span>
                        <span className="text-[11px] font-bold text-gray-600 group-hover:text-gray-900 transition-colors">{t('share.copy_link')}</span>
                      </button>
                    </div>
                  </div>
                )}
              </div>
            </div>

            <button
              type="button"
              onClick={handleSave}
              aria-label="Kaydet"
              aria-pressed={isBookmarked}
              className={`relative flex h-10 w-10 items-center justify-center rounded-[5px] transition-all duration-150 active:scale-95 ${isBookmarked
                ? 'text-palette-red'
                : 'text-palette-tan/55 hover:text-gray-800'
                }`}
            >
              <RemixIcon name={isBookmarked ? 'ri-bookmark-fill' : 'ri-bookmark-line'} size={28} />
              {savesCount > 0 && (
                <span className="absolute -right-1 -top-1 min-w-[16px] rounded-full bg-palette-red px-1 text-center text-[9px] font-black leading-[16px] text-white">
                  {savesCount > 99 ? '99+' : savesCount}
                </span>
              )}
            </button>
          </div>
        </div>

        {commentsEnabled && showComments && (
          <div onClick={(e) => e.stopPropagation()} className="public-news-card-comments animate-in fade-in slide-in-from-top-1 duration-300 pointer-events-auto">
            <InlineCardComments
              postId={data.id}
              publisherId={data.publisherId}
              totalCount={data.comments || 0}
              commentApprovalEnabled={commentApprovalEnabled}
              emojiEnabled={emojiReactionsEnabled}
            />
          </div>
        )}
      </div>
    </div>
  );
};

export const NewsCardSkeleton: React.FC = () => {
  return (
    <div className="bg-white rounded-[5px] border border-palette-beige/30 shadow-[0_2px_20px_rgba(24,37,64,0.03)] p-6 space-y-4">
      <div className="flex items-center gap-3.5">
        <Skeleton variant="rectangular" className="w-11 h-11" />
        <div className="space-y-2">
          <Skeleton className="w-24 h-4" />
          <Skeleton className="w-32 h-3" />
        </div>
      </div>
      <Skeleton className="w-full h-[60px]" />
      <Skeleton className="w-full h-[300px]" />
      <div className="pt-4 flex justify-between">
        <div className="flex gap-2">
          <Skeleton className="w-20 h-8" />
          <Skeleton className="w-20 h-8" />
        </div>
        <Skeleton className="w-24 h-10" />
      </div>
    </div>
  );
};

export default NewsCard;
