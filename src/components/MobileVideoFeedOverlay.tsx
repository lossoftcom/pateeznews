import React, { useCallback, useEffect, useMemo, useRef, useState } from 'react';
import type { NewsItem, SiteSettings } from '@/types';
import { hasPostActionSession, postAction } from '@/services/appActions';
import { useLanguage } from '@/context/LanguageContext';
import { useToast } from '@/context/ToastContext';
import RemixIcon from '@/components/ui/RemixIcon';
import { formatPostDateParts, isPostId } from '@/utils/helpers';
import { navigateImmediately } from '@/utils/immediateNavigation';
import { getPostHref } from '@/utils/postUrl';
import { getProfileHref } from '@/utils/profileUrl';
import { openSiteSearch } from '@/utils/searchNavigation';
import {
  buildFacebookShareUrl,
  buildShareHashtags,
  buildShareText,
  buildTelegramShareUrl,
  buildTrackedShareUrl,
  buildWhatsAppShareUrl,
  buildXShareUrl,
  cleanShareText,
  isShareAbortError,
  openShareWindow,
  writeToClipboard,
} from '@/utils/socialShare';

type VideoFeedItem = {
  key: string;
  postId: string;
  url: string;
  poster: string;
  title: string;
  summary: string;
  keywords: string;
  source: string;
  sourceAvatar: string;
  publisherHandle: string;
  publisherId?: string;
  category: string;
  categoryTrail: string[];
  timestamp: string;
  slug?: string;
  likes: number;
  dislikes: number;
  comments: number;
  shares: number;
  saves: number;
  userLiked: boolean;
  userDisliked: boolean;
  userSaved: boolean;
};

type PostActionState = {
  counts?: {
    likes?: number;
    dislikes?: number;
    shares?: number;
    saves?: number;
  };
  userState?: {
    liked?: boolean;
    disliked?: boolean;
    saved?: boolean;
  };
};

type VideoBlock = {
  type?: unknown;
  mediaUrl?: unknown;
  videoThumbUrl?: unknown;
  thumbnailUrl?: unknown;
  thumbUrl?: unknown;
  mediaThumbUrl?: unknown;
  thumb?: unknown;
  showOnHomepage?: unknown;
};

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

interface MobileVideoFeedOverlayProps {
  newsItems: NewsItem[];
  siteSettings?: SiteSettings | null;
  initialVideoUrl?: string;
  initialPostId?: string;
  onClose: () => void;
}

const NSOSYAL_ICON_SRC = '/images/nsosyal-icon.png';
const PLAYBACK_SPEEDS = [1, 1.5, 2];
const VIEW_THRESHOLD_FALLBACK_SECONDS = 30;

const cleanText = (value: unknown) => String(value || '').trim();

const mediaUrl = (value: unknown) => {
  const raw = cleanText(value);
  if (!raw) return '';
  if (/^(https?:|data:|blob:)/i.test(raw) || raw.startsWith('/')) return raw;
  return `/${raw.replace(/^public\//, '')}`;
};

const youtubeIdFrom = (url: string) => {
  const raw = cleanText(url);
  if (/^[_\-a-zA-Z0-9]{11}$/.test(raw)) return raw;
  let parsed: URL;
  try {
    parsed = new URL(raw);
  } catch {
    try {
      parsed = new URL(`https://${raw}`);
    } catch {
      return '';
    }
  }
  const host = parsed.hostname.toLowerCase();
  if (!host.includes('youtube.com') && !host.includes('youtu.be') && !host.includes('youtube-nocookie.com')) {
    return '';
  }
  if (host.includes('youtu.be')) return cleanText(parsed.pathname.split('/').filter(Boolean)[0]).match(/[_\-a-zA-Z0-9]{11}/)?.[0] || '';
  const queryId = cleanText(parsed.searchParams.get('v')).match(/[_\-a-zA-Z0-9]{11}/)?.[0] || '';
  if (queryId) return queryId;
  const segments = parsed.pathname.split('/').filter(Boolean);
  for (let index = 0; index < segments.length - 1; index += 1) {
    if (['shorts', 'embed', 'live'].includes(segments[index].toLowerCase())) {
      return cleanText(segments[index + 1]).match(/[_\-a-zA-Z0-9]{11}/)?.[0] || '';
    }
  }
  return '';
};

const isShortsUrl = (url: string) => cleanText(url).toLowerCase().includes('/shorts/');

const youtubeThumb = (url: string) => {
  const id = youtubeIdFrom(url);
  return id ? `https://img.youtube.com/vi/${id}/hqdefault.jpg` : '';
};

const videoThumbFromBlock = (block: VideoBlock) => (
  mediaUrl(block.videoThumbUrl) ||
  mediaUrl(block.thumbnailUrl) ||
  mediaUrl(block.thumbUrl) ||
  mediaUrl(block.mediaThumbUrl) ||
  mediaUrl(block.thumb)
);

const extractVideoMedia = (news: NewsItem) => {
  const explicitUrls = Array.isArray(news.videoUrls) ? news.videoUrls.map(mediaUrl).filter(Boolean) : [];
  const explicitThumbs = Array.isArray(news.videoThumbUrls) ? news.videoThumbUrls.map(mediaUrl) : [];
  const blocks = Array.isArray(news.items) ? news.items as VideoBlock[] : [];
  const videoBlocks = blocks.filter((block) => cleanText(block?.type).toLowerCase() === 'video' && mediaUrl(block.mediaUrl));
  const homepageBlock = videoBlocks.find((block) => block.showOnHomepage === true);
  const orderedBlocks = homepageBlock
    ? [homepageBlock, ...videoBlocks.filter((block) => block !== homepageBlock)]
    : videoBlocks;
  const entries = [
    ...explicitUrls.map((url, index) => ({ url, poster: explicitThumbs[index] || youtubeThumb(url) })),
    ...orderedBlocks.map((block) => {
      const url = mediaUrl(block.mediaUrl);
      return { url, poster: videoThumbFromBlock(block) || youtubeThumb(url) };
    }),
  ];
  const primary = mediaUrl(news.videoUrl || (news.type === 'VIDEO' ? news.mediaUrl : ''));
  if (primary && !entries.some((entry) => entry.url === primary)) {
    entries.unshift({ url: primary, poster: mediaUrl(news.videoThumbUrl) || youtubeThumb(primary) });
  }
  const seen = new Set<string>();
  return entries.filter((entry) => {
    if (!entry.url || seen.has(entry.url)) return false;
    seen.add(entry.url);
    return true;
  });
};

const compactCount = (value: number) => {
  const safe = Math.max(0, Math.round(Number(value) || 0));
  if (safe < 1000) return String(safe);
  if (safe < 10000) return `${String(Number((safe / 1000).toFixed(1))).replace('.', ',')}B`;
  if (safe < 1000000) return `${Math.round(safe / 1000)}B`;
  if (safe < 10000000) return `${String(Number((safe / 1000000).toFixed(1))).replace('.', ',')}M`;
  return `${Math.round(safe / 1000000)}M`;
};

const formatClock = (seconds: number) => {
  const safe = Math.max(0, Math.floor(Number(seconds) || 0));
  const h = Math.floor(safe / 3600);
  const m = Math.floor((safe % 3600) / 60);
  const s = safe % 60;
  const two = (n: number) => String(n).padStart(2, '0');
  return h > 0 ? `${h}:${two(m)}:${two(s)}` : `${two(m)}:${two(s)}`;
};

const nextPlaybackSpeed = (speed: number) => {
  const index = PLAYBACK_SPEEDS.findIndex((item) => Math.abs(item - speed) < 0.01);
  return index < 0 || index === PLAYBACK_SPEEDS.length - 1 ? PLAYBACK_SPEEDS[0] : PLAYBACK_SPEEDS[index + 1];
};

const videoViewThresholdSeconds = (duration: number) => {
  if (!Number.isFinite(duration) || duration <= 0) return VIEW_THRESHOLD_FALLBACK_SECONDS;
  return Math.max(2, Math.min(30, Math.ceil(duration / 2)));
};

const titleCaseTr = (value: string) => cleanText(value)
  .toLocaleLowerCase('tr-TR')
  .replace(/(^|[\s/])(\S)/g, (_, prefix: string, letter: string) => `${prefix}${letter.toLocaleUpperCase('tr-TR')}`);

const authorHandle = (item: VideoFeedItem) => {
  const handle = cleanText(item.publisherHandle).replace(/^@+/, '');
  if (handle) return `@${handle}`;
  const first = cleanText(item.source).split(/\s+/)[0] || 'pateez';
  return `@${first.toLocaleLowerCase('tr-TR').replace(/[^0-9a-zçğıiöşü]/g, '') || 'pateez'}`;
};

const initials = (value: string) => cleanText(value).charAt(0).toLocaleUpperCase('tr-TR') || 'P';

const buildVideoFeedItems = (newsItems: NewsItem[]) => {
  return newsItems
    .filter((news) => extractVideoMedia(news).length > 0)
    .sort((a, b) => new Date(b.timestamp || 0).getTime() - new Date(a.timestamp || 0).getTime())
    .flatMap((news) => {
      const videos = extractVideoMedia(news);
      return videos.map((video, index): VideoFeedItem => ({
        key: `${news.id}-${index}-${video.url}`,
        postId: cleanText(news.id),
        url: video.url,
        poster: video.poster,
        title: cleanText(news.title),
        summary: cleanText(news.summary),
        keywords: cleanText(news.keywords),
        source: cleanText(news.source || news.author || 'Pateez'),
        sourceAvatar: mediaUrl(news.sourceAvatar),
        publisherHandle: cleanText(news.publisherHandle),
        publisherId: cleanText(news.publisherId),
        category: cleanText(news.category),
        categoryTrail: Array.isArray(news.categoryTrail) ? news.categoryTrail.map(cleanText).filter(Boolean) : [],
        timestamp: cleanText(news.timestamp),
        slug: cleanText(news.slug),
        likes: Number(news.likes || 0),
        dislikes: Number(news.dislikes || 0),
        comments: Number(news.comments || 0),
        shares: Number(news.shares || 0),
        saves: Number(news.saves || 0),
        userLiked: news.userLiked === true,
        userDisliked: news.userDisliked === true,
        userSaved: news.userSaved === true,
      }));
    });
};

const FullscreenBrand: React.FC<{ siteSettings?: SiteSettings | null }> = ({ siteSettings }) => {
  const logo = mediaUrl(siteSettings?.logo_url || siteSettings?.dark_logo_url);
  return (
    <div className="mobile-video-feed-brand" aria-label={siteSettings?.site_name || 'Pateez'}>
      {logo ? (
        <img src={logo} alt={siteSettings?.site_name || 'Pateez'} loading="eager" decoding="async" />
      ) : (
        <span>pateez<small>.com</small></span>
      )}
    </div>
  );
};

const SwipeHint: React.FC<{ visible: boolean }> = ({ visible }) => (
  <div className={`mobile-video-feed-swipe-hint${visible ? ' is-visible' : ''}`} aria-hidden="true">
    <span className="mobile-video-feed-chevrons">
      <RemixIcon name="ri-arrow-up-s-fill" size={20} />
      <RemixIcon name="ri-arrow-up-s-fill" size={20} />
    </span>
    <span>
      <strong>Yukarı kaydır</strong>
      <small>sonraki videoya geç</small>
    </span>
  </div>
);

const ActionButton: React.FC<{
  icon: string;
  activeIcon?: string;
  active?: boolean;
  count?: number;
  badgeCount?: number;
  label: string;
  onClick?: () => void;
}> = ({ icon, activeIcon, active, count = 0, badgeCount = 0, label, onClick }) => (
  <button type="button" className={`mobile-video-feed-action${active ? ' is-active' : ''}`} onClick={onClick} aria-label={label}>
    <span className="mobile-video-feed-action-icon">
      <RemixIcon name={active ? activeIcon || icon : icon} size={19} />
      {badgeCount > 0 && <b>{compactCount(badgeCount)}</b>}
    </span>
    {count > 0 || label === 'Beğen' || label === 'Beğenme' || label === 'Yorumlar' ? <small>{compactCount(count)}</small> : null}
  </button>
);

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

const MobileVideoPage: React.FC<{
  item: VideoFeedItem;
  active: boolean;
  siteSettings?: SiteSettings | null;
}> = ({ item, active, siteSettings }) => {
  const { t, currentLang } = useLanguage();
  const { showToast } = useToast();
  const videoRef = useRef<HTMLVideoElement | null>(null);
  const iframeRef = useRef<HTMLIFrameElement | null>(null);
  const shareMenuRef = useRef<HTMLDivElement | null>(null);
  const singleTapTimerRef = useRef<number | null>(null);
  const lastTapRef = useRef<{ time: number; x: number } | null>(null);
  const watchedSecondsRef = useRef(0);
  const viewRecordedRef = useRef(false);
  const userPausedRef = useRef(false);
  const [playing, setPlaying] = useState(false);
  const [muted, setMuted] = useState(true);
  const [duration, setDuration] = useState(0);
  const [position, setPosition] = useState(0);
  const [aspectRatio, setAspectRatio] = useState(isShortsUrl(item.url) ? 9 / 16 : 16 / 9);
  const [speed, setSpeed] = useState(1);
  const [centerVisible, setCenterVisible] = useState(true);
  const [seekFeedback, setSeekFeedback] = useState(0);
  const [busy, setBusy] = useState(false);
  const [likes, setLikes] = useState(item.likes);
  const [dislikes, setDislikes] = useState(item.dislikes);
  const [shares, setShares] = useState(item.shares);
  const [saves, setSaves] = useState(item.saves);
  const [liked, setLiked] = useState(item.userLiked);
  const [disliked, setDisliked] = useState(item.userDisliked);
  const [saved, setSaved] = useState(item.userSaved);
  const [showShareMenu, setShowShareMenu] = useState(false);
  const youtubeId = youtubeIdFrom(item.url);
  const isYoutube = Boolean(youtubeId);
  const vertical = aspectRatio > 0 && aspectRatio < 1;
  const publishedAt = formatPostDateParts(item.timestamp, currentLang.code);
  const categoryLabel = (item.categoryTrail.length > 0 ? item.categoryTrail : [item.category])
    .map(titleCaseTr)
    .filter(Boolean)
    .join(' / ');
  const meta = [categoryLabel, publishedAt.date, publishedAt.time].filter(Boolean).join(' • ');
  const profileHref = getProfileHref(item.publisherHandle);
  const detailHref = getPostHref({ id: item.postId, slug: item.slug }, siteSettings);
  const shareUrl = typeof window !== 'undefined'
    ? new URL(detailHref, window.location.origin).toString()
    : '';

  const sendYoutubeCommand = useCallback((func: string, args: any = '') => {
    iframeRef.current?.contentWindow?.postMessage(JSON.stringify({ event: 'command', func, args }), '*');
  }, []);

  const play = useCallback(() => {
    userPausedRef.current = false;
    if (isYoutube) {
      sendYoutubeCommand(muted ? 'mute' : 'unMute');
      sendYoutubeCommand('setPlaybackRate', speed);
      sendYoutubeCommand('playVideo');
      setPlaying(true);
      return;
    }
    const video = videoRef.current;
    if (!video) return;
    video.muted = muted;
    video.playbackRate = speed;
    video.play().then(() => setPlaying(true)).catch(() => setPlaying(false));
  }, [isYoutube, muted, sendYoutubeCommand, speed]);

  const pause = useCallback(() => {
    if (isYoutube) sendYoutubeCommand('pauseVideo');
    else videoRef.current?.pause();
    setPlaying(false);
  }, [isYoutube, sendYoutubeCommand]);

  useEffect(() => {
    watchedSecondsRef.current = 0;
    viewRecordedRef.current = false;
    userPausedRef.current = false;
    setPlaying(false);
    setPosition(0);
    setCenterVisible(true);
    setSpeed(1);
  }, [item.url]);

  useEffect(() => {
    if (active && !userPausedRef.current) {
      const timer = window.setTimeout(play, 80);
      return () => window.clearTimeout(timer);
    }
    pause();
  }, [active, pause, play]);

  useEffect(() => {
    if (!active || !playing) {
      setCenterVisible(true);
      return;
    }
    const timer = window.setTimeout(() => setCenterVisible(false), 1800);
    return () => window.clearTimeout(timer);
  }, [active, playing, position]);

  useEffect(() => {
    if (!active || !playing || viewRecordedRef.current || !isPostId(item.postId)) return;
    const timer = window.setInterval(() => {
      watchedSecondsRef.current += 1;
      const threshold = videoViewThresholdSeconds(duration);
      if (watchedSecondsRef.current < threshold || viewRecordedRef.current) return;
      viewRecordedRef.current = true;
      void postAction('video_view', {
        postId: item.postId,
        publisherId: item.publisherId,
        videoUrl: item.url,
        source: 'video',
        watchedSeconds: watchedSecondsRef.current,
        durationSeconds: duration > 0 ? Math.round(duration) : undefined,
        thresholdSeconds: threshold,
      }).catch(() => {
        viewRecordedRef.current = false;
      });
    }, 1000);
    return () => window.clearInterval(timer);
  }, [active, duration, item.postId, item.publisherId, item.url, playing]);

  useEffect(() => {
    if (!isYoutube) return;
    const handleMessage = (event: MessageEvent) => {
      if (!String(event.origin || '').includes('youtube.com')) return;
      let payload: any;
      try {
        payload = typeof event.data === 'string' ? JSON.parse(event.data) : event.data;
      } catch {
        return;
      }
      const info = payload?.info;
      if (!info) return;
      if (Number(info.duration) > 0) setDuration(Number(info.duration));
      if (typeof info.currentTime !== 'undefined') {
        const next = Number(info.currentTime);
        if (Number.isFinite(next) && next >= 0) setPosition(next);
      }
      if (typeof info.playerState !== 'undefined') setPlaying(info.playerState === 1);
    };
    window.addEventListener('message', handleMessage);
    return () => window.removeEventListener('message', handleMessage);
  }, [isYoutube]);

  useEffect(() => {
    if (!active || !isYoutube || !playing) return;
    const timer = window.setInterval(() => {
      sendYoutubeCommand('getCurrentTime');
      sendYoutubeCommand('getDuration');
    }, 250);
    return () => window.clearInterval(timer);
  }, [active, isYoutube, playing, sendYoutubeCommand]);

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

  const applyServerState = (state: PostActionState) => {
    setLikes(state.counts?.likes ?? likes);
    setDislikes(state.counts?.dislikes ?? dislikes);
    setShares(state.counts?.shares ?? shares);
    setSaves(state.counts?.saves ?? saves);
    setLiked(state.userState?.liked ?? liked);
    setDisliked(state.userState?.disliked ?? disliked);
    setSaved(state.userState?.saved ?? saved);
  };

  const requireSignedIn = (message: string) => {
    if (hasPostActionSession()) return true;
    showToast(message, 'error');
    return false;
  };

  const toggleVote = async (kind: 'like' | 'dislike') => {
    if (!isPostId(item.postId) || busy) return;
    if (!requireSignedIn(kind === 'like' ? 'Beğenmek için kayıt olmanız gerekiyor.' : 'Beğenmemek için kayıt olmanız gerekiyor.')) return;
    const previous = { likes, dislikes, liked, disliked };
    setBusy(true);
    if (kind === 'like') {
      setLiked(!liked);
      setLikes(Math.max(0, likes + (liked ? -1 : 1)));
      if (disliked && !liked) {
        setDisliked(false);
        setDislikes(Math.max(0, dislikes - 1));
      }
    } else {
      setDisliked(!disliked);
      setDislikes(Math.max(0, dislikes + (disliked ? -1 : 1)));
      if (liked && !disliked) {
        setLiked(false);
        setLikes(Math.max(0, likes - 1));
      }
    }
    try {
      applyServerState(await postAction(kind === 'like' ? 'toggle_like' : 'toggle_dislike', {
        postId: item.postId,
        publisherId: item.publisherId,
      }));
    } catch {
      setLikes(previous.likes);
      setDislikes(previous.dislikes);
      setLiked(previous.liked);
      setDisliked(previous.disliked);
    } finally {
      setBusy(false);
    }
  };

  const toggleSave = async () => {
    if (!isPostId(item.postId) || busy) return;
    if (!requireSignedIn('Kaydetmek için kayıt olmanız gerekiyor.')) return;
    const previous = { saves, saved };
    setBusy(true);
    setSaved(!saved);
    setSaves(Math.max(0, saves + (saved ? -1 : 1)));
    try {
      applyServerState(await postAction('toggle_save', { postId: item.postId, publisherId: item.publisherId }));
    } catch {
      setSaves(previous.saves);
      setSaved(previous.saved);
    } finally {
      setBusy(false);
    }
  };

  const recordShare = async (platform: string) => {
    try {
      if (isPostId(item.postId)) {
        applyServerState(await postAction('share', {
          postId: item.postId,
          publisherId: item.publisherId,
          platform,
        }));
      } else {
        setShares((value) => value + 1);
      }
    } catch {
      setShares((value) => value + 1);
    }
  };

  const getUtmUrl = (platform: string) => (
    buildTrackedShareUrl(shareUrl, {
      platform,
      campaign: 'share_card',
      contentId: item.postId,
    })
  );

  const getShareText = () => (
    buildShareText({
      title: item.title,
      summary: item.summary,
      category: item.category,
      siteName: siteSettings?.site_name || 'Haber',
      keywords: item.keywords || siteSettings?.meta_keywords,
    })
  );

  const copyLink = async (showNotification = true, track = true, platform = 'copy_link') => {
    if (track) void recordShare(platform);
    const copied = await writeToClipboard(getUtmUrl(platform));
    if (showNotification) {
      showToast(copied ? t('common.link_copied_short') : t('common.copy_failed_alt'), copied ? 'success' : 'error');
    }
    setShowShareMenu(false);
    return copied;
  };

  const shareToWhatsApp = () => {
    void recordShare('whatsapp');
    const finalMessage = `${getShareText()}\n\n🔗 Hemen oku: ${getUtmUrl('whatsapp')}`;
    openShareWindow(buildWhatsAppShareUrl(finalMessage));
    setShowShareMenu(false);
  };

  const shareToTelegram = () => {
    void recordShare('telegram');
    openShareWindow(buildTelegramShareUrl(getUtmUrl('telegram'), getShareText()));
    setShowShareMenu(false);
  };

  const shareToTwitter = () => {
    void recordShare('twitter');
    openShareWindow(buildXShareUrl({
      text: cleanShareText(item.title),
      url: getUtmUrl('twitter'),
      hashtags: buildShareHashtags({
        category: item.category,
        siteName: siteSettings?.site_name,
        keywords: item.keywords || siteSettings?.meta_keywords,
      }, 3),
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
    const text = getShareText();

    if (navigator.share) {
      try {
        await navigator.share({
          title: cleanShareText(item.title),
          text,
          url,
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

  const shareMenuItems: ShareMenuItem[] = [
    { key: 'whatsapp', label: t('share.whatsapp'), icon: 'ri-whatsapp-fill', iconClass: 'text-[#25D366]', hoverClass: 'hover:bg-[#25D366]/10', onClick: shareToWhatsApp },
    { key: 'telegram', label: t('share.telegram'), icon: 'ri-telegram-fill', iconClass: 'text-[#229ED9]', hoverClass: 'hover:bg-[#229ED9]/10', onClick: shareToTelegram },
    { key: 'twitter', label: t('share.x_twitter'), icon: 'ri-twitter-x-fill', iconClass: 'text-[#0F1419]', hoverClass: 'hover:bg-black/5', onClick: shareToTwitter },
    { key: 'facebook', label: t('share.facebook'), icon: 'ri-facebook-fill', iconClass: 'text-[#1877F2]', hoverClass: 'hover:bg-[#1877F2]/10', onClick: shareToFacebook },
    { key: 'instagram', label: t('share.instagram'), icon: 'ri-instagram-fill', iconClass: 'bg-[radial-gradient(circle_at_30%_107%,#fdf497_0%,#fdf497_5%,#fd5949_45%,#d6249f_60%,#285AEB_90%)] bg-clip-text text-transparent', hoverClass: 'hover:bg-[#E1306C]/10', onClick: shareToInstagram },
    { key: 'tiktok', label: t('share.tiktok'), customIcon: 'tiktok', hoverClass: 'hover:bg-[#FE2C55]/10', onClick: shareToTikTok },
    { key: 'nsosyal', label: t('share.nsosyal'), imageSrc: NSOSYAL_ICON_SRC, imageClass: 'rounded-[4px]', hoverClass: 'hover:bg-[#2F5BFF]/10', onClick: shareToSocial },
  ];

  const togglePlay = () => {
    setCenterVisible(true);
    if (playing) {
      userPausedRef.current = true;
      pause();
    } else {
      play();
    }
  };

  const toggleMute = () => {
    const next = !muted;
    setMuted(next);
    if (isYoutube) sendYoutubeCommand(next ? 'mute' : 'unMute');
    else if (videoRef.current) videoRef.current.muted = next;
  };

  const toggleSpeed = () => {
    const next = nextPlaybackSpeed(speed);
    setSpeed(next);
    if (isYoutube) sendYoutubeCommand('setPlaybackRate', next);
    else if (videoRef.current) videoRef.current.playbackRate = next;
  };

  const seekToFraction = (fraction: number) => {
    const next = Math.max(0, Math.min(1, fraction));
    const target = duration * next;
    setPosition(target);
    if (isYoutube) sendYoutubeCommand('seekTo', [target, true]);
    else if (videoRef.current && duration > 0) videoRef.current.currentTime = target;
  };

  const seekRelative = (delta: number) => {
    const target = Math.max(0, Math.min(duration || 0, position + delta));
    seekToFraction(duration > 0 ? target / duration : 0);
    setSeekFeedback(delta);
    window.setTimeout(() => setSeekFeedback(0), 980);
  };

  const handleSurfacePointerUp = (event: React.PointerEvent<HTMLDivElement>) => {
    if ((event.target as HTMLElement).closest('button, a, input')) return;
    const now = Date.now();
    const rect = event.currentTarget.getBoundingClientRect();
    const previous = lastTapRef.current;
    if (previous && now - previous.time < 280) {
      if (singleTapTimerRef.current) window.clearTimeout(singleTapTimerRef.current);
      lastTapRef.current = null;
      seekRelative(event.clientX - rect.left >= rect.width / 2 ? 10 : -10);
      return;
    }
    lastTapRef.current = { time: now, x: event.clientX };
    singleTapTimerRef.current = window.setTimeout(togglePlay, 260);
  };

  const remaining = duration > 0 ? Math.max(0, duration - position) : 0;
  const progress = duration > 0 ? Math.max(0, Math.min(1, position / duration)) : 0;

  return (
    <section className={`mobile-video-feed-page${vertical ? ' is-vertical' : ''}`} aria-label={item.title}>
      <div className="mobile-video-feed-media">
        <div className="mobile-video-feed-frame" style={{ aspectRatio }}>
          {isYoutube ? (
            <>
              <iframe
                ref={iframeRef}
                src={`https://www.youtube.com/embed/${youtubeId}?enablejsapi=1&autoplay=0&mute=1&controls=0&rel=0&showinfo=0&modestbranding=1&disablekb=1&fs=0&iv_load_policy=3&playsinline=1&loop=1&playlist=${youtubeId}`}
                title={item.title || 'Video'}
                allow="autoplay; encrypted-media; fullscreen"
                onLoad={() => active && play()}
              />
              {!playing && item.poster && <img src={item.poster} alt="" loading="lazy" decoding="async" />}
            </>
          ) : (
            <video
              ref={videoRef}
              src={item.url}
              poster={item.poster || undefined}
              playsInline
              loop
              muted={muted}
              preload="metadata"
              onLoadedMetadata={(event) => {
                const video = event.currentTarget;
                setDuration(Number.isFinite(video.duration) ? video.duration : 0);
                if (video.videoHeight > 0) setAspectRatio(video.videoWidth / video.videoHeight);
              }}
              onTimeUpdate={(event) => {
                setPosition(event.currentTarget.currentTime || 0);
                setDuration(Number.isFinite(event.currentTarget.duration) ? event.currentTarget.duration : duration);
              }}
            />
          )}
          <div className="mobile-video-feed-touch" onPointerUp={handleSurfacePointerUp}>
            <button type="button" className="mobile-video-feed-round-button mobile-video-feed-mute" onClick={toggleMute} aria-label={muted ? 'Sesi aç' : 'Sessize al'}>
              <RemixIcon name={muted ? 'ri-volume-mute-line' : 'ri-volume-up-line'} size={18} />
            </button>
            <div className={`mobile-video-feed-center${centerVisible || !playing ? ' is-visible' : ''}`} aria-hidden="true">
              <RemixIcon name={playing ? 'ri-pause-fill' : 'ri-play-fill'} size={31} />
            </div>
            {seekFeedback !== 0 && (
              <div className={`mobile-video-feed-seek${seekFeedback > 0 ? ' is-forward' : ' is-back'}`}>
                <span>{Math.abs(seekFeedback)} sn</span>
              </div>
            )}
            {!playing && duration > 0 && (
              <div className="mobile-video-feed-double-hint" aria-hidden="true">
                <span>Çift dokun<br /><small>10 sn geri</small></span>
                <span>Çift dokun<br /><small>10 sn ileri</small></span>
              </div>
            )}
            <div className="mobile-video-feed-bottom-scrim" aria-hidden="true" />
            <div className="mobile-video-feed-playback-pills">
              <button type="button" onClick={toggleSpeed} aria-label="Oynatma hızı">{speed % 1 === 0 ? `${speed}x` : `${speed.toFixed(1)}x`}</button>
              <span>{formatClock(remaining)}</span>
            </div>
            <div
              className="mobile-video-feed-progress"
              onPointerDown={(event) => {
                event.stopPropagation();
                const rect = event.currentTarget.getBoundingClientRect();
                seekToFraction((event.clientX - rect.left) / rect.width);
              }}
            >
              <span style={{ transform: `scaleX(${progress})` }} />
            </div>
          </div>
        </div>
      </div>

      <footer className="mobile-video-feed-info">
        <button
          type="button"
          className="mobile-video-feed-author"
          onClick={() => profileHref && navigateImmediately(profileHref)}
          disabled={!profileHref}
        >
          <span className="mobile-video-feed-avatar">
            {item.sourceAvatar ? <img src={item.sourceAvatar} alt="" loading="lazy" decoding="async" /> : initials(item.source)}
          </span>
          <span className="mobile-video-feed-author-copy">
            <strong>{item.source}<RemixIcon name="ri-verified-badge-fill" size={15} /></strong>
            <small>{authorHandle(item)}</small>
            {meta && <em>{meta}</em>}
          </span>
        </button>
        <a className="mobile-video-feed-title" href={detailHref}>{item.title}</a>
        <div className="mobile-video-feed-actions">
          <ActionButton icon="ri-thumb-up-line" activeIcon="ri-thumb-up-fill" active={liked} count={likes} label="Beğen" onClick={() => void toggleVote('like')} />
          <ActionButton icon="ri-thumb-down-line" activeIcon="ri-thumb-down-fill" active={disliked} count={dislikes} label="Beğenme" onClick={() => void toggleVote('dislike')} />
          <ActionButton icon="ri-chat-3-line" count={item.comments} label="Yorumlar" />
          <span className="mobile-video-feed-action-spacer" />
          <ActionButton icon="ri-bookmark-line" activeIcon="ri-bookmark-fill" active={saved} badgeCount={saves} label="Kaydet" onClick={() => void toggleSave()} />
          <div className="relative" ref={shareMenuRef}>
            <ActionButton icon="ri-share-forward-line" count={shares} label={t('common.share')} onClick={() => setShowShareMenu((value) => !value)} />

            {showShareMenu && (
              <div
                className="absolute bottom-full right-0 mb-3 bg-white/95 backdrop-blur-xl rounded-[12px] shadow-[0_25px_60px_rgba(24,37,64,0.2)] border border-palette-beige/30 p-1.5 min-w-[220px] z-[99999] animate-in fade-in zoom-in-95 slide-in-from-bottom-2 duration-300 pointer-events-auto"
                onClick={(event) => event.stopPropagation()}
              >
                <div className="grid grid-cols-1 gap-0.5">
                  {shareMenuItems.map((shareItem) => (
                    <button
                      key={shareItem.key}
                      type="button"
                      onClick={shareItem.onClick}
                      className={`w-full h-[38px] flex items-center gap-3 px-3 rounded-[8px] ${shareItem.hoverClass} transition-all duration-300 group text-left`}
                    >
                      <span className="w-[20px] h-[20px] flex items-center justify-center">
                        {renderShareMenuIcon(shareItem)}
                      </span>
                      <span className="text-[11px] font-bold text-gray-600 group-hover:text-gray-900 transition-colors">{shareItem.label}</span>
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
      </footer>
    </section>
  );
};

const MobileVideoFeedOverlay: React.FC<MobileVideoFeedOverlayProps> = ({ newsItems, siteSettings, initialVideoUrl, initialPostId, onClose }) => {
  const items = useMemo(() => buildVideoFeedItems(newsItems), [newsItems]);
  const initialIndex = useMemo(() => {
    const target = mediaUrl(initialVideoUrl);
    const targetPostId = cleanText(initialPostId);
    if (!target && !targetPostId) return 0;
    const targetYoutubeId = youtubeIdFrom(target);
    const matchesTargetUrl = (item: VideoFeedItem) => {
      if (!target) return false;
      if (item.url === target) return true;
      const itemYoutubeId = youtubeIdFrom(item.url);
      return Boolean(targetYoutubeId && itemYoutubeId && targetYoutubeId === itemYoutubeId);
    };
    if (targetPostId) {
      const exactPostVideoIndex = items.findIndex((item) => item.postId === targetPostId && matchesTargetUrl(item));
      if (exactPostVideoIndex >= 0) return exactPostVideoIndex;
      const postIndex = items.findIndex((item) => item.postId === targetPostId);
      if (postIndex >= 0) return postIndex;
    }
    const matchIndex = items.findIndex((item) => {
      return matchesTargetUrl(item);
    });
    return matchIndex >= 0 ? matchIndex : 0;
  }, [initialPostId, initialVideoUrl, items]);
  const pagesRef = useRef<HTMLDivElement | null>(null);
  const hintTimerRef = useRef<number | null>(null);
  const repeatTimerRef = useRef<number | null>(null);
  const [activeIndex, setActiveIndex] = useState(initialIndex);
  const [showHint, setShowHint] = useState(items.length > 1);

  const pulseHint = useCallback((duration = 2600) => {
    if (items.length <= 1) return;
    setShowHint(true);
    if (hintTimerRef.current) window.clearTimeout(hintTimerRef.current);
    hintTimerRef.current = window.setTimeout(() => setShowHint(false), duration);
  }, [items.length]);

  useEffect(() => {
    document.body.classList.add('mobile-video-feed-open');
    return () => document.body.classList.remove('mobile-video-feed-open');
  }, []);

  useEffect(() => {
    setActiveIndex(initialIndex);
    const pages = pagesRef.current;
    if (!pages) return;
    window.requestAnimationFrame(() => {
      pages.scrollTo({ top: pages.clientHeight * initialIndex, behavior: 'auto' });
    });
  }, [initialIndex]);

  useEffect(() => {
    if (items.length <= 1) return;
    pulseHint(3600);
    repeatTimerRef.current = window.setInterval(() => pulseHint(2600), 13000);
    return () => {
      if (hintTimerRef.current) window.clearTimeout(hintTimerRef.current);
      if (repeatTimerRef.current) window.clearInterval(repeatTimerRef.current);
    };
  }, [items.length, pulseHint]);

  useEffect(() => {
    const handleKey = (event: KeyboardEvent) => {
      if (event.key === 'Escape') onClose();
    };
    window.addEventListener('keydown', handleKey);
    return () => window.removeEventListener('keydown', handleKey);
  }, [onClose]);

  const handleScroll = () => {
    const pages = pagesRef.current;
    if (!pages) return;
    const next = Math.max(0, Math.min(items.length - 1, Math.round(pages.scrollTop / Math.max(1, pages.clientHeight))));
    if (next !== activeIndex) {
      setActiveIndex(next);
      pulseHint(2600);
    }
  };

  const openSearch = () => {
    onClose();
    void openSiteSearch();
  };

  return (
    <div className="mobile-video-feed-overlay" role="dialog" aria-modal="true" aria-label="Video">
      <header className="mobile-video-feed-topbar">
        <button type="button" className="mobile-video-feed-top-icon" onClick={openSearch} aria-label="Ara">
          <RemixIcon name="ri-search-line" size={19} />
        </button>
        <FullscreenBrand siteSettings={siteSettings} />
        <button type="button" className="mobile-video-feed-exit" onClick={onClose} aria-label="Geri">
          <RemixIcon name="ri-arrow-left-line" size={20} />
        </button>
      </header>

      {items.length === 0 ? (
        <div className="mobile-video-feed-empty">
          <RemixIcon name="ri-play-circle-line" size={34} />
          <span>Video bulunamadı</span>
        </div>
      ) : (
        <div ref={pagesRef} className="mobile-video-feed-pages" onScroll={handleScroll}>
          {items.map((item, index) => (
            <MobileVideoPage
              key={item.key}
              item={item}
              active={index === activeIndex}
              siteSettings={siteSettings}
            />
          ))}
        </div>
      )}

      <SwipeHint visible={showHint} />
    </div>
  );
};

export default MobileVideoFeedOverlay;
