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
      className="public-news-card bg-white rounded-[5px] border border-palette-beige/30 shadow-[0_2px_20px_rgba(24,37,64,0.03)] transition-all duration-100 hover:shadow-[0_8px_30px_rgba(24,37,64,0.06)] hover:border-palette-red/10 cursor-pointer group/card relative"
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

      <div className="relative pointer-events-none [&_button]:pointer-events-auto [&_input]:pointer-events-auto [&_textarea]:pointer-events-auto [&_select]:pointer-events-auto [&_a]:pointer-events-auto [&_.video-interact-area]:pointer-events-auto [&_.card-interact-area]:pointer-events-auto">
        {/* HEADER */}
        <div className="public-news-card-header px-6 pt-6 pb-2 flex items-center justify-between">
          <div className="flex items-center gap-3.5">
            {showPostAuthor && (
              <div
                onClick={handleSourceAction}
                {...sourceHoverHandlers}
                className="w-12 h-12 rounded-full bg-white p-[2px] border border-palette-beige/70 shadow-[0_6px_18px_rgba(24,37,64,0.07)] cursor-pointer group/avatar relative pointer-events-auto"
              >
                <div className="w-full h-full rounded-full overflow-hidden">
                  <img
                    src={data.sourceAvatar || `https://picsum.photos/seed/source${data.id}/100`}
                    className="w-full h-full object-cover transition-transform duration-500 group-hover/avatar:scale-110"
                    alt={displaySourceName || data.source}
                  />
                </div>
                <div className="absolute -bottom-0.5 -right-0.5 w-4 h-4 bg-white rounded-full flex items-center justify-center border border-palette-beige/60 shadow-sm">
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
                    className="flex items-center gap-1.5 cursor-pointer group/title pointer-events-auto"
                  >
                    <h5 className="text-[15px] font-[800] text-gray-900 tracking-tight group-hover/title:text-palette-red transition-colors">
                      {displaySourceName || data.source}
                    </h5>
                    <RemixIcon name="ri-verified-badge-fill" size={16} className="text-palette-red" />
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

              <div className="flex items-center gap-1.5 text-[10px] font-bold text-palette-tan/40 leading-none mt-1">
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

        {/* MEDIA CONTENT */}
        <div className="public-news-card-media px-6 pb-2 rounded-[5px] overflow-hidden">{renderContent()}</div>

        {/* INTERACTION BAR */}
        <div className="mt-0.5 border-t border-palette-beige/20 bg-white relative z-[100]">
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
                    <button onClick={shareToWhatsApp} className="w-full h-[38px] flex items-center gap-3 px-3 rounded-[8px] hover:bg-palette-accent/10 transition-all duration-300 group">
                      <div className="w-[20px] h-[20px] flex items-center justify-center text-palette-accent/70 group-hover:text-palette-accent group-hover:scale-110 transition-all">
                        <svg viewBox="0 0 24 24" fill="currentColor" className="w-full h-full">
                          <path d="M17.472 14.382c-.297-.149-1.758-.867-2.03-.967-.273-.099-.471-.148-.67.15-.197.297-.767.966-.94 1.164-.173.199-.347.223-.644.075-.297-.15-1.255-.463-2.39-1.475-.883-.788-1.48-1.761-1.653-2.059-.173-.297-.018-.458.13-.606.134-.133.298-.347.446-.52.149-.174.198-.298.298-.497.099-.198.05-.371-.025-.52-.075-.149-.669-1.612-.916-2.207-.242-.579-.487-.5-.669-.51-.173-.008-.371-.01-.57-.01-.198 0-.52.074-.792.372-.272.297-1.04 1.016-1.04 2.479 0 1.462 1.065 2.875 1.213 3.074.149.198 2.096 3.2 5.077 4.487.709.306 1.262.489 1.694.625.712.227 1.36.195 1.871.118.571-.085 1.758-.719 2.006-1.413.248-.694.248-1.289.173-1.413-.074-.124-.272-.198-.57-.347m-5.421 7.403h-.004a9.87 9.87 0 01-5.031-1.378l-.361-.214-3.741.982.998-3.648-.235-.374a9.86 9.86 0 01-1.51-5.26c.001-5.45 4.436-9.884 9.888-9.884 2.64 0 5.122 1.03 6.988 2.898a9.825 9.825 0 012.893 6.994c-.003 5.45-4.437 9.884-9.885 9.884m8.413-18.297A11.815 11.815 0 0012.05 0C5.495 0 .16 5.335.157 11.892c0 2.096.547 4.142 1.588 5.945L.003 24l6.335-1.652a11.882 11.882 0 005.71 1.453h.006c6.554 0 11.89-5.335 11.893-11.893a11.821 11.821 0 00-3.48-8.413z" />
                        </svg>
                      </div>
                      <span className="text-[11px] font-bold text-gray-600 group-hover:text-gray-900 transition-colors">{t('share.whatsapp')}</span>
                    </button>

                    <button onClick={shareToTelegram} className="w-full h-[38px] flex items-center gap-3 px-3 rounded-[8px] hover:bg-palette-tan/10 transition-all duration-300 group">
                      <div className="w-[20px] h-[20px] flex items-center justify-center text-palette-tan/70 group-hover:text-palette-tan group-hover:scale-110 transition-all">
                        <svg viewBox="0 0 24 24" fill="currentColor" className="w-full h-full">
                          <path d="M11.944 0A12 12 0 0 0 0 12a12 12 0 0 0 12 12 12 12 0 0 0 12-12A12 12 0 0 0 12 0a12 12 0 0 0-.056 0zm4.962 7.224c.1-.002.321.023.465.14a.506.506 0 0 1 .171.325c.016.093.036.306.02.472-.18 1.898-.962 6.502-1.36 8.627-.168.9-.499 1.201-.82 1.23-.696.065-1.225-.46-1.9-.902-1.056-.693-1.653-1.124-2.678-1.8-1.185-.78-.417-1.21.258-1.91.177-.184 3.247-2.977 3.307-3.23.007-.032.014-.15-.056-.212s-.174-.041-.249-.024c-.106.024-1.793 1.14-5.061 3.345-.48.33-.913.49-1.302.48-.428-.008-1.252-.241-1.865-.44-.752-.245-1.349-.374-1.297-.789.027-.216.325-.437.893-.663 3.498-1.524 5.83-2.529 6.998-3.014 3.332-1.386 4.025-1.627 4.476-1.635z" />
                        </svg>
                      </div>
                      <span className="text-[11px] font-bold text-gray-600 group-hover:text-gray-900 transition-colors">{t('share.telegram')}</span>
                    </button>

                    <button onClick={shareToTwitter} className="w-full h-[38px] flex items-center gap-3 px-3 rounded-[8px] hover:bg-black/5 transition-all duration-300 group">
                      <div className="w-[20px] h-[20px] flex items-center justify-center text-black/70 group-hover:text-black group-hover:scale-110 transition-all">
                        <svg viewBox="0 0 24 24" fill="currentColor" className="w-full h-full">
                          <path d="M18.244 2.25h3.308l-7.227 8.26 8.502 11.24H16.17l-5.214-6.817L4.99 21.75H1.68l7.73-8.835L1.254 2.25H8.08l4.713 6.231zm-1.161 17.52h1.833L7.084 4.126H5.117z" />
                        </svg>
                      </div>
                      <span className="text-[11px] font-bold text-gray-600 group-hover:text-gray-900 transition-colors">{t('share.x_twitter')}</span>
                    </button>

                    <button onClick={shareToFacebook} className="w-full h-[38px] flex items-center gap-3 px-3 rounded-[8px] hover:bg-palette-maroon/5 transition-all duration-300 group">
                      <div className="w-[20px] h-[20px] flex items-center justify-center text-palette-maroon/70 group-hover:text-palette-maroon group-hover:scale-110 transition-all">
                        <svg viewBox="0 0 24 24" fill="currentColor" className="w-full h-full">
                          <path d="M24 12.073c0-6.627-5.373-12-12-12s-12 5.373-12 12c0 5.99 4.388 10.954 10.125 11.854v-8.385H7.078v-3.47h3.047V9.43c0-3.007 1.792-4.669 4.533-4.669 1.312 0 2.686.235 2.686.235v2.953H15.83c-1.491 0-1.956.925-1.956 1.874v2.25h3.328l-.532 3.47h-2.796v8.385C19.612 23.027 24 18.062 24 12.073z" />
                        </svg>
                      </div>
                      <span className="text-[11px] font-bold text-gray-600 group-hover:text-gray-900 transition-colors">{t('share.facebook')}</span>
                    </button>

                    <button onClick={shareToInstagram} className="w-full h-[38px] flex items-center gap-3 px-3 rounded-[8px] hover:bg-palette-red/5 transition-all duration-300 group">
                      <div className="w-[20px] h-[20px] flex items-center justify-center text-palette-red/70 group-hover:text-palette-red group-hover:scale-110 transition-all">
                        <svg viewBox="0 0 24 24" fill="currentColor" className="w-full h-full">
                          <path d="M12 0C8.74 0 8.333.015 7.053.072 5.775.132 4.905.333 4.14.63c-.789.306-1.459.717-2.126 1.384S.935 3.35.63 4.14C.333 4.905.131 5.775.072 7.053.012 8.333 0 8.74 0 12s.015 3.667.072 4.947c.06 1.277.261 2.148.558 2.913.306.788.717 1.459 1.384 2.126.667.666 1.336 1.079 2.126 1.384.766.296 1.636.499 2.913.558C8.333 23.988 8.74 24 12 24s3.667-.015 4.947-.072c1.277-.06 2.148-.262 2.913-.558.788-.306 1.459-.718 2.126-1.384.666-.667 1.079-1.335 1.384-2.126.296-.765.499-1.636.558-2.913.06-1.28.072-1.687.072-4.947s-.015-3.667-.072-4.947c-.06-1.277-.262-2.149-.558-2.913-.306-.789-.718-1.459-1.384-2.126C21.319 1.347 20.651.935 19.86.63c-.765-.297-1.636-.499-2.913-.558C15.667.012 15.26 0 12 0zm0 2.16c3.203 0 3.585.016 4.85.071 1.17.055 1.805.249 2.227.415.562.217.96.477 1.382.896.419.42.679.819.896 1.381.164.422.36 1.057.413 2.227.057 1.266.07 1.646.07 4.85s-.015 3.585-.074 4.85c-.061 1.17-.256 1.805-.421 2.227-.224.562-.479.96-.899 1.382-.419.419-.824.679-1.38.896-.42.164-1.065.36-2.235.413-1.274.057-1.649.07-4.859.07-3.211 0-3.586-.015-4.859-.074-1.171-.061-1.816-.256-2.236-.421-.569-.224-.96-.479-1.379-.899-.421-.419-.69-.824-.9-1.38-.165-.42-.359-1.065-.42-2.235-.045-1.26-.061-1.649-.061-4.844 0-3.196.016-3.586.061-4.861.061-1.17.255-1.814.42-2.234.21-.57.479-.96.9-1.381.419-.419.81-.689 1.379-.898.42-.166 1.051-.361 2.221-.421 1.275-.045 1.65-.06 4.859-.06l.045.03zm0 3.678c-3.405 0-6.162 2.76-6.162 6.162 0 3.405 2.76 6.162 6.162 6.162 3.405 0 6.162-2.76 6.162-6.162 0-3.405-2.76-6.162-6.162-6.162zM12 16c-2.21 0-4-1.79-4-4s1.79-4 4-4 4 1.79 4 4-1.79 4-4 4zm7.846-10.405c0 .795-.646 1.44-1.44 1.44-.795 0-1.44-.646-1.44-1.44 0-.794.646-1.439 1.44-1.439.793-.001 1.44.645 1.44 1.439z" />
                        </svg>
                      </div>
                      <span className="text-[11px] font-bold text-gray-600 group-hover:text-gray-900 transition-colors">{t('share.instagram')}</span>
                    </button>

                    <button onClick={shareToTikTok} className="w-full h-[38px] flex items-center gap-3 px-3 rounded-[8px] hover:bg-black/5 transition-all duration-300 group">
                      <div className="w-[20px] h-[20px] flex items-center justify-center text-black/70 group-hover:text-black group-hover:scale-110 transition-all">
                        <svg viewBox="0 0 24 24" fill="currentColor" className="w-full h-full">
                          <path d="M12.525.02c1.31-.02 2.61-.01 3.91-.02.08 1.53.63 3.09 1.75 4.17 1.12 1.11 2.7 1.62 4.24 1.79v4.03c-1.44-.05-2.89-.35-4.2-.97-.57-.26-1.1-.59-1.62-.93-.01 2.92.01 5.84-.02 8.75-.08 1.4-.54 2.79-1.35 3.94-1.31 1.92-3.58 3.17-5.91 3.21-1.43.08-2.86-.31-4.08-1.03-2.02-1.19-3.44-3.37-3.65-5.71-.02-.5-.03-1-.01-1.49.18-1.9 1.12-3.72 2.58-4.96 1.66-1.44 3.98-2.13 6.15-1.72.02 1.48-.04 2.96-.04 4.44-.99-.32-2.15-.23-3.02.37-.63.41-1.11 1.04-1.36 1.75-.21.51-.15 1.07-.14 1.61.24 1.64 1.82 3.02 3.5 2.87 1.12-.01 2.19-.66 2.77-1.61.19-.33.4-.67.41-1.06.1-1.79.06-3.57.07-5.36.01-4.03-.01-8.05.02-12.07z" />
                        </svg>
                      </div>
                      <span className="text-[11px] font-bold text-gray-600 group-hover:text-gray-900 transition-colors">{t('share.tiktok')}</span>
                    </button>

                    <button onClick={shareToSocial} className="w-full h-[38px] flex items-center gap-3 px-3 rounded-[8px] hover:bg-palette-red/5 transition-all duration-300 group">
                      <div className="w-[20px] h-[20px] flex items-center justify-center text-palette-red/70 group-hover:text-palette-red group-hover:scale-110 transition-all">
                        <svg viewBox="0 0 24 24" fill="currentColor" className="w-full h-full">
                          <path d="M12 2C6.48 2 2 6.48 2 12s4.48 10 10 10 10-4.48 10-10S17.52 2 12 2zm-1 17.93c-3.95-.49-7-3.85-7-7.93 0-.62.08-1.21.21-1.79L9 15v1c0 1.1.9 2 2 2v1.93zm6.9-2.54c-.26-.81-1-1.39-1.9-1.39h-1v-3c0-.55-.45-1-1-1H8v-2h2c.55 0 1-.45 1-1V7h2c1.1 0 2-.9 2-2v-.41c2.93 1.19 5 4.06 5 7.41 0 2.08-.8 3.97-2.1 5.39z" />
                        </svg>
                      </div>
                      <span className="text-[11px] font-bold text-gray-600 group-hover:text-gray-900 transition-colors">{t('share.nsosyal')}</span>
                    </button>

                    <div className="h-px bg-palette-beige/10 my-1 mx-2"></div>

                    <button onClick={() => copyLink()} className="w-full h-[38px] flex items-center gap-3 px-3 rounded-[8px] hover:bg-palette-beige/10 transition-all duration-300 group">
                      <div className="w-[20px] h-[20px] flex items-center justify-center text-palette-tan/60 group-hover:text-palette-tan group-hover:scale-110 transition-all">
                        <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" className="w-full h-full">
                          <path d="M10 13a5 5 0 0 0 7.54.54l3-3a5 5 0 0 0-7.07-7.07l-1.72 1.71" />
                          <path d="M14 11a5 5 0 0 0-7.54-.54l-3 3a5 5 0 0 0 7.07 7.07l1.71-1.71" />
                        </svg>
                      </div>
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
          <div onClick={(e) => e.stopPropagation()} className="animate-in fade-in slide-in-from-top-1 duration-300 pointer-events-auto">
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
