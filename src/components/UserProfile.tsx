
import React, { useEffect, useLayoutEffect, useMemo, useState } from 'react';
import { ArrowLeft, MessageSquare, Share2, Calendar, User as UserIcon, Mail, Link as LinkIcon, Globe, Users, FileText, Eye, Heart, MapPin, AtSign, Edit3, Clock3 } from 'lucide-react';
import { NewsType, type NewsItem, type SiteSettings } from '@/types';
import { useLanguage } from '@/context/LanguageContext';
import { formatPostDateParts } from '@/utils/helpers';

interface UserProfileProps {
  userId?: string;
  name: string;
  onBack: () => void;
  onNewsSelect: (id: string) => void;
  onEditClick?: () => void;
  siteSettings?: SiteSettings | null;
  showEmail?: boolean;
  initialProfile?: Record<string, any> | null;
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

const AUTH_STORAGE_KEYS = ['pateeznews-supabase-auth', 'supabase-auth-token'];
const useBrowserLayoutEffect = typeof window !== 'undefined' ? useLayoutEffect : useEffect;

interface ProfilePreview {
  id: string;
  name: string;
  username: string;
  avatar: string;
  initials: string;
}

const decodeTextCodePoint = (value: string, radix: number, fallback: string) => {
  const codePoint = Number.parseInt(value, radix);
  if (!Number.isFinite(codePoint) || codePoint <= 0) return fallback;
  if (codePoint === 60 || codePoint === 62) return fallback;
  try {
    return String.fromCodePoint(codePoint);
  } catch {
    return fallback;
  }
};

const normalizeStoredPlainText = (value: unknown) => {
  const decodeOnce = (input: string) => input
    .replace(/&([a-zA-Z][a-zA-Z0-9]+);/g, (match, entity: string) => TEXT_ENTITY_MAP[entity] ?? match)
    .replace(/&#x([0-9a-fA-F]+);/g, (match, hex: string) => decodeTextCodePoint(hex, 16, match))
    .replace(/&#(\d+);/g, (match, decimal: string) => decodeTextCodePoint(decimal, 10, match));

  return decodeOnce(decodeOnce(String(value ?? ''))).replace(/\u00a0/g, ' ').trim();
};

const normalizeProfileMediaUrl = (input: any): string => {
  if (!input) return '';
  const url = String(input).trim();
  if (!url) return '';
  if (
    url.startsWith('http://') ||
    url.startsWith('https://') ||
    url.startsWith('data:') ||
    url.startsWith('/')
  ) {
    return url;
  }
  if (url.startsWith('api/storage/file/')) return `/${url}`;
  if (url.startsWith('profile/')) return `/api/storage/file/${url}`;
  return `/api/storage/file/profile/${url}`;
};

const parseProfileSocialLinks = (value: unknown) => {
  try {
    if (!value) return {};
    if (typeof value === 'string') return JSON.parse(value);
    if (typeof value === 'object' && !Array.isArray(value)) return value as Record<string, any>;
  } catch (error) {
    console.error('Social links parsing error:', error);
  }
  return {};
};

const readStoredProfileAccessToken = () => {
  if (typeof window === 'undefined') return '';
  for (const key of AUTH_STORAGE_KEYS) {
    const raw = window.localStorage.getItem(key);
    if (!raw) continue;
    try {
      const parsed = JSON.parse(raw);
      const token =
        parsed?.access_token ||
        parsed?.currentSession?.access_token ||
        parsed?.session?.access_token;
      if (token) return String(token);
    } catch {
      // Ignore invalid legacy auth payloads and keep checking known keys.
    }
  }
  return '';
};

const readStoredProfileUserId = () => {
  if (typeof window === 'undefined') return '';
  for (const key of AUTH_STORAGE_KEYS) {
    const raw = window.localStorage.getItem(key);
    if (!raw) continue;
    try {
      const parsed = JSON.parse(raw);
      const userId =
        parsed?.user?.id ||
        parsed?.currentSession?.user?.id ||
        parsed?.session?.user?.id;
      if (userId) return String(userId);
    } catch {
      // Ignore invalid legacy auth payloads and keep checking known keys.
    }
  }
  return '';
};

const profileIdFrom = (profile: Record<string, any> | null | undefined, fallbackId?: string) => (
  String(profile?.id || fallbackId || '').trim()
);

const isStoredOwnProfile = (profile: Record<string, any> | null | undefined, fallbackId?: string) => {
  const targetId = profileIdFrom(profile, fallbackId).toLowerCase();
  const storedUserId = readStoredProfileUserId().toLowerCase();
  return Boolean(targetId && storedUserId && targetId === storedUserId);
};

const hasFullProfilePayload = (profile: Record<string, any> | null | undefined) => (
  Boolean(profile?.stats && Array.isArray(profile?.posts))
);

const joinedDateLabel = (value: unknown, lang = 'tr') => (
  formatPostDateParts(String(value || ''), lang).date
);

const joinedYearLabel = (value: unknown, lang = 'tr') => {
  const date = new Date(String(value || ''));
  if (Number.isNaN(date.getTime())) return '';
  return new Intl.DateTimeFormat(lang === 'tr' ? 'tr-TR' : 'en-US', {
    year: 'numeric',
    timeZone: 'Europe/Istanbul',
  }).format(date);
};

const profileInitials = (name: string) => {
  const initials = name
    .split(/\s+/)
    .map((part) => part.trim()[0])
    .filter(Boolean)
    .slice(0, 2)
    .join('')
    .toLocaleUpperCase('tr-TR');
  return initials || 'P';
};

const mapProfilePreview = (row: any, fallbackAvatar = ''): ProfilePreview => {
  const username = normalizeStoredPlainText(row?.username);
  const name = normalizeStoredPlainText(row?.full_name || username || 'Profil');
  return {
    id: String(row?.id || username || fallbackAvatar || name),
    name,
    username,
    avatar: normalizeProfileMediaUrl(row?.avatar_url || fallbackAvatar),
    initials: profileInitials(name),
  };
};

const mapProfilePreviewList = (profiles: unknown, avatarUrls: unknown) => {
  const rows = Array.isArray(profiles) ? profiles : [];
  const avatars = Array.isArray(avatarUrls) ? avatarUrls : [];
  const length = Math.max(rows.length, avatars.length);
  return Array.from({ length }, (_item, index) => mapProfilePreview(rows[index] || {}, String(avatars[index] || '')))
    .filter((profile) => profile.avatar || profile.name);
};

const formatCount = (value: unknown, lang = 'tr') => (
  Math.max(0, Number(value) || 0).toLocaleString(lang || 'tr')
);

const socialUrl = (value: unknown) => {
  const text = String(value || '').trim();
  if (!text) return '';
  if (/^https?:\/\//i.test(text)) return text;
  if (/^[\w.-]+\.[a-z]{2,}(\/.*)?$/i.test(text)) return `https://${text}`;
  return text;
};

const mapProfileToViewData = (
  profile: Record<string, any>,
  showEmail: boolean,
  fallbackUserLabel: string,
  fallbackCategoryLabel: string,
  lang = 'tr',
) => {
  const socialLinks = parseProfileSocialLinks(profile.social_links);
  const stats = profile.stats && typeof profile.stats === 'object' ? profile.stats : {};
  const shouldShowEmail = showEmail && profile.show_email !== false;
  const role = String(profile.role || '').toLowerCase();
  const joinedDate = joinedDateLabel(profile.created_at, lang);
  const followersCount = Number(stats.followers ?? profile.followers ?? 0);
  const followingCount = Number(stats.following ?? profile.following ?? 0);
  const postsCount = Number(stats.posts ?? profile.posts_count ?? 0);

  return {
    id: profile.id,
    name: normalizeStoredPlainText(profile.full_name || profile.username || fallbackUserLabel),
    handle: profile.username ? `@${profile.username}` : '',
    category: normalizeStoredPlainText(profile.expertise || fallbackCategoryLabel),
    description: normalizeStoredPlainText(profile.about_me),
    email: shouldShowEmail ? (profile.email || '') : '',
    website: normalizeStoredPlainText(profile.website),
    avatar: normalizeProfileMediaUrl(profile.avatar_url),
    cover: normalizeProfileMediaUrl(profile.cover_url || (socialLinks as any)?.cover_url),
    followers: formatCount(followersCount, lang),
    following: formatCount(followingCount, lang),
    postsCount: formatCount(postsCount, lang),
    followersCount,
    followingCount,
    postsCountRaw: postsCount,
    joinedDate,
    joinedYear: joinedYearLabel(profile.created_at, lang),
    city: normalizeStoredPlainText(profile.city),
    likedPosts: formatCount(stats.liked_posts ?? 0, lang),
    commentsCount: formatCount(stats.comments ?? 0, lang),
    verified: role === 'admin' || role === 'editor',
    social_links: socialLinks,
    followerProfiles: mapProfilePreviewList(profile.follower_profiles, profile.follower_avatars),
    followingProfiles: mapProfilePreviewList(profile.following_profiles, profile.following_avatars),
  };
};

const mapProfilePosts = (profile: Record<string, any>): NewsItem[] => {
  const posts = Array.isArray(profile.posts) ? profile.posts : [];
  return posts.map((item: any) => ({
    id: String(item.id || ''),
    type: NewsType.STANDARD,
    title: normalizeStoredPlainText(item.title),
    summary: normalizeStoredPlainText(item.summary),
    category: normalizeStoredPlainText(item.category),
    source: normalizeStoredPlainText(item.source || profile.full_name || profile.username),
    author: normalizeStoredPlainText(item.source || profile.full_name || profile.username),
    timestamp: item.publishedAt || item.timestamp || '',
    mediaUrl: item.videoUrl || item.imageUrl || item.mediaUrl || '',
    thumbnail: item.imageUrl || item.thumbnail || item.coverThumbnail || item.mediaUrl || '',
    likes: Number(item.likes || 0),
    comments: Number(item.comments || 0),
    shares: Number(item.shares || 0),
    views: Number(item.views || 0),
    slug: item.slug || '',
    sourceAvatar: item.sourceAvatar || profile.avatar_url || '',
    publisherId: item.publisherId || profile.id || '',
    publisherHandle: item.publisherHandle || profile.username || '',
    seoTitle: normalizeStoredPlainText(item.seoTitle),
    seoDescription: normalizeStoredPlainText(item.seoDescription),
    thumbnailAlt: normalizeStoredPlainText(item.thumbnailAlt),
    ...(Number((item as any).imageAspectRatio || 0) > 0
      ? { imageAspectRatio: Number((item as any).imageAspectRatio) }
      : {}),
  } as NewsItem & { imageAspectRatio?: number }));
};

const UserProfile: React.FC<UserProfileProps> = ({ userId, name, onBack, onNewsSelect, onEditClick, siteSettings, showEmail = true, initialProfile = null }) => {
  const { t, currentLang } = useLanguage();
  const langCode = currentLang?.code || 'tr';

  const [isFollowing, setIsFollowing] = useState(Boolean(initialProfile?.viewer_following));
  const [userData, setUserData] = useState<any>(() => (
    initialProfile ? mapProfileToViewData(initialProfile, showEmail, t('common.user'), t('users_list.default_description'), langCode) : null
  ));
  const [userNews, setUserNews] = useState<NewsItem[]>(() => (
    initialProfile ? mapProfilePosts(initialProfile) : []
  ));
  const [loading, setLoading] = useState(!initialProfile);
  const [isOwnProfile, setIsOwnProfile] = useState(Boolean(initialProfile?.is_own_profile));
  const [isProfileActionReady, setIsProfileActionReady] = useState(Boolean(initialProfile?.is_own_profile));
  const [isMobileProfileAppbarVisible, setIsMobileProfileAppbarVisible] = useState(false);
  const socialEntries = useMemo(() => {
    const links = userData?.social_links || {};
    const platforms = ['x', 'facebook', 'instagram', 'tiktok', 'youtube', 'discord', 'linkedin', 'telegram', 'whatsapp', 'pinterest'];
    const entries = platforms
      .map((key) => ({ key, href: socialUrl(links[key]) }))
      .filter((entry) => Boolean(entry.href));
    const website = socialUrl(userData?.website || links.personal_website_url);
    return website ? [...entries, { key: 'website', href: website }] : entries;
  }, [userData?.social_links, userData?.website]);

  useBrowserLayoutEffect(() => {
    if (!initialProfile) {
      setIsProfileActionReady(false);
      return;
    }

    const localOwnProfile = Boolean(initialProfile.is_own_profile) || isStoredOwnProfile(initialProfile, userId);
    if (localOwnProfile) {
      setIsOwnProfile(true);
      setIsProfileActionReady(true);
      return;
    }

    setIsProfileActionReady(!readStoredProfileAccessToken());
  }, [initialProfile, userId]);

  useEffect(() => {
    let isMounted = true;

    const fetchData = async () => {
      const queryUserId = String(userId || initialProfile?.id || '').trim();
      const queryUsername = String(initialProfile?.username || name || '').trim().replace(/^@+/, '');
      if (!queryUserId && !queryUsername) {
        setLoading(false);
        return;
      }

      const token = readStoredProfileAccessToken();
      if (initialProfile && hasFullProfilePayload(initialProfile) && !token) {
        setIsProfileActionReady(true);
        setLoading(false);
        return;
      }

      try {
        if (!initialProfile) setLoading(true);
        if (token && !isStoredOwnProfile(initialProfile, userId)) {
          setIsProfileActionReady(false);
        }

        const url = new URL('/api/app/profile', window.location.origin);
        url.searchParams.set('lang', langCode);
        if (queryUserId) {
          url.searchParams.set('userId', queryUserId);
        } else {
          url.searchParams.set('username', queryUsername);
        }

        const response = await fetch(url, {
          headers: {
            Accept: 'application/json',
            ...(token ? { Authorization: `Bearer ${token}` } : {}),
          },
        });
        const payload = await response.json().catch(() => ({}));
        if (!response.ok || payload?.error || !payload?.profile) {
          throw new Error(payload?.error?.message || 'Profile load failed');
        }

        if (!isMounted) return;
        const profile = payload.profile as Record<string, any>;
        setIsOwnProfile(profile.is_own_profile === true);
        setIsProfileActionReady(true);
        setIsFollowing(profile.viewer_following === true);
        setUserData(mapProfileToViewData(profile, showEmail, t('common.user'), t('users_list.default_description'), langCode));
        setUserNews(mapProfilePosts(profile));
      } catch (err) {
        console.error('Error fetching user profile:', err);
        if (isMounted) setIsProfileActionReady(true);
      } finally {
        if (isMounted) setLoading(false);
      }
    };

    void fetchData();
    return () => {
      isMounted = false;
    };
  }, [initialProfile, langCode, name, showEmail, t, userId]);

  useEffect(() => {
    if (typeof window === 'undefined') return;
    const syncAppbar = () => {
      const isMobile = window.matchMedia('(max-width: 767px)').matches;
      setIsMobileProfileAppbarVisible(isMobile && window.scrollY >= 126);
    };
    syncAppbar();
    window.addEventListener('scroll', syncAppbar, { passive: true });
    window.addEventListener('resize', syncAppbar);
    return () => {
      window.removeEventListener('scroll', syncAppbar);
      window.removeEventListener('resize', syncAppbar);
    };
  }, []);

  const renderProfileStack = (profiles: ProfilePreview[], totalCount: number, emptyLabel: string) => {
    const visibleProfiles = profiles.slice(0, 5);
    const remaining = Math.max(0, totalCount - visibleProfiles.length);

    if (visibleProfiles.length === 0) {
      return <p className="text-xs font-semibold text-gray-400">{emptyLabel}</p>;
    }

    return (
      <div className="flex -space-x-3">
        {visibleProfiles.map((profile) => (
          <div
            key={profile.id}
            title={profile.username ? `${profile.name} (@${profile.username})` : profile.name}
            className="w-10 h-10 rounded-full border-[3px] border-white shadow-md overflow-hidden bg-gray-100 flex items-center justify-center text-[11px] font-black text-gray-500"
          >
            {profile.avatar ? (
              <img src={profile.avatar} className="w-full h-full object-cover" alt={profile.name} loading="lazy" decoding="async" />
            ) : (
              <span>{profile.initials}</span>
            )}
          </div>
        ))}
        {remaining > 0 && (
          <div className="w-10 h-10 rounded-full bg-gradient-to-br from-gray-100 to-gray-200 border-[3px] border-white flex items-center justify-center text-xs font-bold text-gray-600 shadow-md">
            +{remaining}
          </div>
        )}
      </div>
    );
  };

  const renderMobileProfileStack = (profiles: ProfilePreview[], totalCount: number, emptyLabel: string) => {
    const visibleProfiles = profiles.slice(0, 5);
    const remaining = Math.max(0, totalCount - visibleProfiles.length);

    if (visibleProfiles.length === 0) {
      return <p className="profile-mobile-follow-empty">{emptyLabel}</p>;
    }

    return (
      <div className="profile-mobile-follow-avatars">
        {visibleProfiles.map((profile) => (
          <span key={profile.id} className="profile-mobile-follow-avatar" title={profile.username ? `${profile.name} (@${profile.username})` : profile.name}>
            {profile.avatar ? (
              <img src={profile.avatar} alt={profile.name} loading="lazy" decoding="async" />
            ) : (
              profile.initials
            )}
          </span>
        ))}
        {remaining > 0 && <span className="profile-mobile-follow-avatar">+{remaining}</span>}
      </div>
    );
  };

  if (loading) return (
    <div className="flex justify-center items-center min-h-[400px]">
      <div className="animate-spin rounded-full h-8 w-8 border-b-2 border-palette-red"></div>
    </div>
  );

  if (!userData) return (
    <div className="text-center py-20">
      <p className="text-gray-500 font-medium">{t('user_profile.not_found')}</p>
      <button onClick={onBack} className="mt-4 px-6 py-2.5 bg-gray-900 text-white rounded-[5px] font-semibold text-sm hover:bg-gray-800 transition-all">{t('admin.post.go_back')}</button>
    </div>
  );

  return (
    <>
    <div className="profile-mobile-shell">
      <header className={`profile-mobile-sticky-appbar${isMobileProfileAppbarVisible ? ' is-visible' : ''}`} aria-hidden={!isMobileProfileAppbarVisible}>
        <div>
          <span aria-hidden="true" />
          <strong>{userData.name}</strong>
        </div>
        <button type="button" onClick={onBack} aria-label={t('admin.post.go_back')}>
          <ArrowLeft size={20} strokeWidth={2.2} />
        </button>
      </header>

      <section className="profile-mobile-cover">
        {userData.cover ? (
          <img
            src={userData.cover}
            alt={t('user_edit_profile.cover_alt')}
            loading="eager"
            decoding="async"
            fetchPriority="high"
          />
        ) : (
          <div className="profile-mobile-cover-empty">
            <UserIcon size={52} strokeWidth={1.5} />
          </div>
        )}
        <div className="profile-mobile-cover-shade" />
        <button
          type="button"
          className="profile-mobile-back"
          onClick={onBack}
          aria-label={t('admin.post.go_back')}
        >
          <ArrowLeft size={20} strokeWidth={2.2} />
        </button>
      </section>

      <section className="profile-mobile-identity">
        <div className="profile-mobile-avatar">
          {userData.avatar ? (
            <img
              src={userData.avatar}
              alt={t('user_edit_profile.avatar_alt')}
              loading="eager"
              decoding="async"
              fetchPriority="high"
            />
          ) : (
            <UserIcon size={44} strokeWidth={1.5} />
          )}
          {userData.verified && <span className="profile-mobile-verified" aria-hidden="true">✓</span>}
        </div>

        <div className="profile-mobile-edit-wrap">
          {!isProfileActionReady ? (
            <span className="profile-mobile-action-skeleton" aria-hidden="true" />
          ) : isOwnProfile ? (
            <button type="button" className="profile-mobile-edit-button" onClick={onEditClick}>
              <Edit3 size={14} strokeWidth={2} />
              <span>{t('user_profile.edit_profile')}</span>
            </button>
          ) : (
            <button
              type="button"
              className={`profile-mobile-edit-button${isFollowing ? ' is-following' : ''}`}
              onClick={() => setIsFollowing(!isFollowing)}
            >
              <Users size={14} strokeWidth={2} />
              <span>{isFollowing ? t('common.following') : t('common.follow')}</span>
            </button>
          )}
        </div>

        <h1>{userData.name}</h1>
        <div className="profile-mobile-meta">
          {userData.handle && <span>{userData.handle}</span>}
          {userData.category && <b>{userData.category}</b>}
          <em>{t('user_profile.online')}</em>
        </div>
      </section>

      <section className="profile-mobile-stats" aria-label="Profil istatistikleri">
        <div>
          <strong>{userData.postsCount}</strong>
          <span>{t('user_profile.stats.news').toLocaleUpperCase('tr-TR')}</span>
        </div>
        <div>
          <strong>{userData.followers}</strong>
          <span>{t('users_list.followers').toLocaleUpperCase('tr-TR')}</span>
        </div>
        <div>
          <strong>{userData.following || '0'}</strong>
          <span>{t('user_profile.stats.following').toLocaleUpperCase('tr-TR')}</span>
        </div>
        <div>
          <strong>{userData.joinedYear || '-'}</strong>
          <span>{t('user_profile.stats.joined').toLocaleUpperCase('tr-TR')}</span>
        </div>
      </section>

      <section className="profile-mobile-card">
        <h2>{t('user_profile.about_title')}</h2>
        <p>{userData.description || t('user_profile.about_empty')}</p>
        <div className="profile-mobile-info-list">
          {userData.joinedDate && (
            <span><Calendar size={15} strokeWidth={2} />{userData.joinedDate} tarihinde katıldı</span>
          )}
          {userData.city && (
            <span><MapPin size={15} strokeWidth={2} />{userData.city}</span>
          )}
          {userData.email && (
            <span><AtSign size={15} strokeWidth={2} />{userData.email}</span>
          )}
        </div>
      </section>

      <section className="profile-mobile-card">
        <h2>{t('user_profile.social_links_title')}</h2>
        {socialEntries.length > 0 ? (
          <div className="profile-mobile-socials">
            {socialEntries.map((entry) => (
              <a key={entry.key} href={entry.href} target="_blank" rel="noopener noreferrer" aria-label={entry.key}>
                {entry.key === 'website' ? <LinkIcon size={18} strokeWidth={2} /> : <Globe size={18} strokeWidth={2} />}
              </a>
            ))}
          </div>
        ) : (
          <p>{t('user_profile.about_empty')}</p>
        )}
      </section>

      <section className="profile-mobile-card">
        <h2>Aktivite</h2>
        <div className="profile-mobile-activity">
          <div>
            <Heart size={18} strokeWidth={2} />
            <strong>{userData.likedPosts}</strong>
            <span>Beğendiği haberler</span>
          </div>
          <div>
            <MessageSquare size={18} strokeWidth={2} />
            <strong>{userData.commentsCount}</strong>
            <span>Yaptığı yorumlar</span>
          </div>
        </div>
      </section>

      <section className="profile-mobile-card profile-mobile-follows">
        <div className="profile-mobile-follow-block">
          <h2>Takipçiler <small>({userData.followers})</small></h2>
          {renderMobileProfileStack(userData.followerProfiles || [], userData.followersCount || 0, 'Henüz kimse yok.')}
        </div>
        <div className="profile-mobile-follow-divider" />
        <div className="profile-mobile-follow-block">
          <h2>Takip Edilen <small>({userData.following || '0'})</small></h2>
          {renderMobileProfileStack(userData.followingProfiles || [], userData.followingCount || 0, 'Henüz kimse yok.')}
        </div>
      </section>

      {userNews.length > 0 && (
        <section className="profile-mobile-posts">
          <div className="profile-mobile-section-title">
            <span aria-hidden="true" />
            <h2>Gönderiler</h2>
            <small>{userData.postsCount} haber</small>
          </div>
          <div className="profile-mobile-post-list">
            {userNews.slice(0, 8).map((news) => {
              const image = news.thumbnail || news.mediaUrl;
              const title = normalizeStoredPlainText(news.seoTitle || news.title);
              const publishedAt = formatPostDateParts(news.timestamp, langCode);
              return (
                <button key={news.id} type="button" onClick={() => onNewsSelect(news.id)} className="profile-mobile-post-card">
                  <span className="profile-mobile-post-thumb">
                    {image ? (
                      <img src={image} alt={news.thumbnailAlt || title} loading="lazy" decoding="async" />
                    ) : (
                      <FileText size={24} strokeWidth={1.5} />
                    )}
                    {news.category && <em>{news.category}</em>}
                  </span>
                  <span className="profile-mobile-post-body">
                    <strong>{title}</strong>
                    <span className="profile-mobile-post-date">
                      {publishedAt.date && <time dateTime={publishedAt.iso || undefined}>{publishedAt.date}</time>}
                      {publishedAt.time && (
                        <>
                          <Clock3 size={12} strokeWidth={2.2} />
                          <time dateTime={publishedAt.iso || undefined}>{publishedAt.time}</time>
                        </>
                      )}
                    </span>
                    <span className="profile-mobile-post-meta">
                      <span><Eye size={13} strokeWidth={2} />{formatCount(news.views, langCode)}</span>
                      <span><MessageSquare size={13} strokeWidth={2} />{formatCount(news.comments, langCode)}</span>
                      <span><Heart size={13} strokeWidth={2} />{formatCount(news.likes, langCode)}</span>
                    </span>
                  </span>
                </button>
              );
            })}
          </div>
        </section>
      )}
    </div>

    <div className="profile-desktop-shell bg-gray-50 min-h-screen">
      <style>{`
        .profile-news-list-item {
          position: relative;
          isolation: isolate;
        }

        .profile-news-list-item::before {
          content: "";
          position: absolute;
          inset: 0 auto 0 0;
          width: 3px;
          background: linear-gradient(180deg, #EA4335 0%, #F39C12 100%);
          opacity: 0;
          transition: opacity 180ms ease;
          z-index: 1;
        }

        .profile-news-list-item:hover::before {
          opacity: 1;
        }

        .profile-news-list .profile-news-list-media {
          display: flex;
          align-items: center;
          justify-content: center;
          aspect-ratio: var(--profile-list-image-ratio, 4 / 3);
        }

        .profile-news-list .profile-news-list-media img {
          width: 100%;
          height: 100%;
          object-fit: contain;
          object-position: center;
        }

        .profile-news-list .profile-news-list-title {
          font-size: var(--web-category-card-title-size, 19px) !important;
          font-weight: var(--web-category-card-title-weight, 700) !important;
          line-height: 1.2;
          overflow-wrap: anywhere;
        }

        .profile-news-list .profile-news-list-summary {
          font-size: var(--web-category-card-summary-size, 13px) !important;
          font-weight: var(--web-category-card-summary-weight, 400) !important;
          line-height: 1.52;
          overflow-wrap: anywhere;
        }

        @media (max-width: 760px) {
          .profile-news-list .profile-news-list-title {
            font-size: var(--web-category-card-title-size, 19px) !important;
          }
        }
      `}</style>

      {/* HEADER: Cover with editorial profile strip */}
      <div className="relative w-full h-48 md:h-56 overflow-hidden rounded-[4px] border border-gray-100 bg-white shadow-sm">
        {userData.cover ? (
          <img
            src={userData.cover}
            className="w-full h-full object-cover"
            alt={t('user_edit_profile.cover_alt')}
            loading="eager"
            decoding="async"
            fetchPriority="high"
          />
        ) : (
          <div className="w-full h-full bg-gray-100 flex items-center justify-center">
            <UserIcon className="text-gray-300" size={64} strokeWidth={1.5} />
          </div>
        )}
        <div className="absolute inset-0 bg-gradient-to-t from-black/25 via-black/0 to-black/10" />

        {/* Navigation Buttons */}
        <div className="absolute top-5 left-5 right-5 flex justify-between z-30">
          <button
            onClick={onBack}
            className="flex h-10 w-10 items-center justify-center bg-white/90 backdrop-blur-xl rounded-[4px] text-gray-900 hover:bg-white transition-all shadow-sm active:scale-95"
            aria-label={t('admin.post.go_back')}
          >
            <ArrowLeft size={18} strokeWidth={2.4} />
          </button>
          <button
            className="flex h-10 w-10 items-center justify-center bg-white/90 backdrop-blur-xl rounded-[4px] text-gray-900 hover:bg-white transition-all shadow-sm active:scale-95"
            aria-label={t('common.share')}
          >
            <Share2 size={18} strokeWidth={2.4} />
          </button>
        </div>
      </div>

      <div className="max-w-7xl mx-auto px-4 md:px-6 relative">

        {/* Profile Identity Bar */}
        <div className="grid grid-cols-[auto_1fr] md:grid-cols-[auto_1fr_auto] items-center gap-4 md:gap-5 -mt-9 relative z-20 mb-8 rounded-[4px] border border-gray-100 bg-white/95 px-4 py-4 shadow-[0_10px_30px_rgba(15,23,42,0.08)] backdrop-blur">

          {/* Avatar */}
          <div className="relative">
            <div className="w-24 h-24 md:w-28 md:h-28 rounded-full border-[3px] border-white shadow-[0_10px_24px_rgba(15,23,42,0.14)] overflow-hidden bg-white">
              {userData.avatar ? (
                <img
                  src={userData.avatar}
                  className="w-full h-full object-cover"
                  alt={t('user_edit_profile.avatar_alt')}
                  loading="eager"
                  decoding="async"
                  fetchPriority="high"
                />
              ) : (
                <div className="w-full h-full flex items-center justify-center bg-gradient-to-br from-gray-100 to-gray-200">
                  <UserIcon className="text-gray-400" size={42} strokeWidth={1.5} />
                </div>
              )}
            </div>
          </div>

          <div className="min-w-0">
            <div className="mb-1.5 flex min-w-0 items-center gap-3">
              <h1 className="truncate text-[22px] md:text-[28px] font-bold leading-tight text-gray-900">
                {userData.name}
              </h1>
            </div>
            <div className="flex flex-wrap items-center gap-x-2.5 gap-y-1.5 text-sm">
              <span className="text-sm font-semibold text-gray-600">{userData.handle}</span>
              <span className="hidden h-1 w-1 rounded-full bg-gray-300 md:inline-block" />
              <span className="inline-flex items-center rounded-full border border-palette-red/15 bg-palette-red/5 px-2.5 py-1 text-xs font-semibold text-palette-red">
                {userData.category}
              </span>
              <span className="hidden h-1 w-1 rounded-full bg-gray-300 md:inline-block" />
              <span className="inline-flex items-center gap-1.5 text-xs font-semibold text-palette-accent">
                <span className="h-1.5 w-1.5 rounded-full bg-palette-accent" />
                {t('user_profile.online')}
              </span>
            </div>
          </div>

          {/* Action Buttons */}
          <div className="col-span-2 justify-self-start md:col-span-1 md:justify-self-end">
            {!isProfileActionReady ? (
              <div className="h-10 min-w-[118px] rounded-[4px] border border-gray-100 bg-gray-100/90 shadow-sm" aria-hidden="true" />
            ) : isOwnProfile ? (
              <button
                onClick={onEditClick}
                className="h-10 rounded-[4px] bg-gray-900 px-4 text-xs font-semibold text-white shadow-[0_8px_20px_rgba(15,23,42,0.16)] transition-all hover:bg-gray-800 active:scale-95"
              >
                {t('user_profile.edit_profile')}
              </button>
            ) : (
              <button
                onClick={() => setIsFollowing(!isFollowing)}
                className={`h-10 min-w-[108px] rounded-[4px] px-4 text-xs font-semibold transition-all active:scale-95 ${isFollowing
                  ? 'border border-gray-200 bg-white text-gray-600 hover:border-gray-300 hover:bg-gray-50'
                  : 'bg-palette-accent text-white shadow-[0_8px_20px_rgba(243,156,18,0.24)] hover:bg-[#e08d0c]'
                  }`}
              >
                {isFollowing ? t('common.following') : t('common.follow')}
              </button>
            )}
          </div>
        </div>

        {/* Stats Cards */}
        <div className="grid grid-cols-2 md:grid-cols-4 gap-4 mb-10">
          <div className="bg-white rounded-[5px] p-5 shadow-sm border border-gray-100 hover:shadow-md transition-all">
            <div className="flex items-center gap-3 mb-2">
              <div className="p-2 bg-blue-50 rounded-[5px]">
                <FileText size={20} className="text-blue-600" strokeWidth={2} />
              </div>
              <p className="text-xs font-semibold text-gray-500 tracking-normal">{t('user_profile.stats.news')}</p>
            </div>
            <p className="text-2xl font-bold text-gray-900">{userData.postsCount}</p>
          </div>
          <div className="bg-white rounded-[5px] p-5 shadow-sm border border-gray-100 hover:shadow-md transition-all">
            <div className="flex items-center gap-3 mb-2">
              <div className="p-2 bg-palette-accent/10 rounded-[5px]">
                <Users size={20} className="text-palette-accent" strokeWidth={2} />
              </div>
              <p className="text-xs font-semibold text-gray-500 tracking-normal">{t('users_list.followers')}</p>
            </div>
            <p className="text-2xl font-bold text-gray-900">{userData.followers}</p>
          </div>
          <div className="bg-white rounded-[5px] p-5 shadow-sm border border-gray-100 hover:shadow-md transition-all">
            <div className="flex items-center gap-3 mb-2">
              <div className="p-2 bg-palette-red/5 rounded-[5px]">
                <Users size={20} className="text-palette-red" strokeWidth={2} />
              </div>
              <p className="text-xs font-semibold text-gray-500 tracking-normal">{t('user_profile.stats.following')}</p>
            </div>
            <p className="text-2xl font-bold text-gray-900">{userData.following || '0'}</p>
          </div>
          <div className="bg-white rounded-[5px] p-5 shadow-sm border border-gray-100 hover:shadow-md transition-all">
            <div className="flex items-center gap-3 mb-2">
              <div className="p-2 bg-gray-100 rounded-[5px]">
                <Calendar size={20} className="text-gray-600" strokeWidth={2} />
              </div>
              <p className="text-xs font-semibold text-gray-500 tracking-normal">{t('user_profile.stats.joined')}</p>
            </div>
            <p className="text-sm font-semibold text-gray-700">{userData.joinedYear || '-'}</p>
          </div>
        </div>

        {/* Content Layout */}
        <div className="grid grid-cols-12 gap-8 pb-20">

          {/* Left Column: Sidebar Details */}
          <div className="col-span-12 md:col-span-4 lg:col-span-3 space-y-6">

            {/* About Card */}
            <div className="bg-white rounded-[5px] p-6 shadow-sm border border-gray-100">
              <h3 className="text-sm font-bold text-gray-900 mb-4">{t('user_profile.about_title')}</h3>
              <p className="text-sm text-gray-600 leading-relaxed mb-5">
                {userData.description || t('user_profile.about_empty')}
              </p>

              <div className="space-y-3 pt-3 border-t border-gray-100">
                {userData.joinedDate && (
                  <div className="flex items-center gap-3 text-sm text-gray-600">
                    <Calendar size={16} className="text-gray-400" strokeWidth={2} />
                    <span>
                      <span className="font-semibold text-gray-700">{t('user_profile.joined_date')}:</span>{' '}
                      {userData.joinedDate}
                    </span>
                  </div>
                )}
                {userData.email && (
                  <div className="flex items-center gap-3 text-sm text-gray-600">
                    <Mail size={16} className="text-gray-400" strokeWidth={2} />
                    <span className="truncate">{userData.email}</span>
                  </div>
                )}
              </div>
            </div>

            {/* Social Links Card */}
            <div className="bg-white rounded-[5px] p-6 shadow-sm border border-gray-100">
              <h3 className="text-sm font-bold text-gray-900 mb-4">{t('user_profile.social_links_title')}</h3>
              <div className="flex flex-wrap gap-2">
                {socialEntries.length > 0 ? socialEntries.map((entry) => (
                  <a
                    key={entry.key}
                    href={entry.href}
                    target="_blank"
                    rel="noopener noreferrer"
                    aria-label={entry.key}
                    className="flex-1 min-w-[40px] h-11 rounded-[5px] bg-gray-50 text-gray-600 flex items-center justify-center hover:bg-gradient-to-br hover:from-palette-red hover:to-red-600 hover:text-white transition-all hover:shadow-md hover:scale-105 active:scale-95"
                  >
                    {entry.key === 'website' ? <LinkIcon size={18} strokeWidth={2} /> : <Globe size={18} strokeWidth={2} />}
                  </a>
                )) : (
                  <p className="text-xs font-semibold text-gray-400">{t('user_profile.about_empty')}</p>
                )}
              </div>
            </div>

            {/* Following Preview Card */}
            <div className="bg-white rounded-[5px] p-6 shadow-sm border border-gray-100">
              <h3 className="text-sm font-bold text-gray-900 mb-4">Takip Edilen ({userData.following})</h3>
              {renderProfileStack(userData.followingProfiles || [], userData.followingCount || 0, 'Henüz takip edilen yok')}
            </div>

            {/* Followers Preview Card */}
            <div className="bg-white rounded-[5px] p-6 shadow-sm border border-gray-100">
              <h3 className="text-sm font-bold text-gray-900 mb-4">{t('user_profile.followers_title')} ({userData.followers})</h3>
              {renderProfileStack(userData.followerProfiles || [], userData.followersCount || 0, 'Henüz takipçi yok')}
            </div>

          </div>

          {/* Right Column: News */}
          <div className="col-span-12 md:col-span-8 lg:col-span-9">

            {/* News List */}
            <div className="profile-news-list grid grid-cols-1 gap-4">
              {userNews.length > 0 ? (
                userNews.map((news) => {
                  const image = news.thumbnail || news.mediaUrl;
                  const title = normalizeStoredPlainText(news.seoTitle || news.title);
                  const summary = normalizeStoredPlainText(news.summary || news.seoDescription);
                  const publishedAt = formatPostDateParts(news.timestamp, langCode);
                  const imageAspectRatio = Number((news as any).imageAspectRatio || 0);
                  const imageFrameStyle = imageAspectRatio > 0
                    ? { '--profile-list-image-ratio': `${imageAspectRatio}` } as React.CSSProperties
                    : undefined;

                  return (
                    <button
                      key={news.id}
                      type="button"
                      onClick={() => onNewsSelect(news.id)}
                      className={`profile-news-list-item group grid grid-cols-1 ${image ? 'sm:grid-cols-[150px_minmax(0,1fr)] lg:grid-cols-[156px_minmax(0,1fr)]' : 'sm:grid-cols-1'} items-center overflow-hidden rounded-[4px] border border-gray-100 bg-white text-left shadow-sm transition-all duration-200 hover:-translate-y-0.5 hover:border-palette-accent/20 hover:shadow-md active:scale-[0.995]`}
                    >
                      {image && (
                        <div className="profile-news-list-media overflow-hidden bg-gray-50 sm:self-center" style={imageFrameStyle}>
                          <img
                            src={image}
                            className="h-full w-full object-contain"
                            alt={news.thumbnailAlt || title}
                            loading="lazy"
                            decoding="async"
                          />
                        </div>
                      )}
                      <div className="flex min-w-0 flex-col justify-between p-4 sm:min-h-[118px] md:p-4">
                        <div className="min-w-0">
                          <h3 className="profile-news-list-title news-title-font text-gray-800 tracking-normal transition-colors group-hover:text-palette-red">
                            {title}
                          </h3>
                          {summary && (
                            <p className="profile-news-list-summary news-subtitle-font mt-2 text-gray-600">
                              {summary}
                            </p>
                          )}
                        </div>
                        <div className="mt-3 flex flex-wrap items-center gap-x-3 gap-y-1.5 border-t border-palette-beige/20 pt-2.5 text-[11px] font-semibold text-palette-tan/45">
                          {publishedAt.date && (
                            <span className="inline-flex min-w-0 items-center gap-1.5 normal-case tracking-normal">
                              <Calendar size={13} className="opacity-80" strokeWidth={2} />
                              <time dateTime={publishedAt.iso || undefined}>{publishedAt.date}</time>
                            </span>
                          )}
                          {publishedAt.time && (
                            <span className="inline-flex items-center gap-1.5 normal-case tracking-normal">
                              <span className="h-1 w-1 rounded-full bg-current opacity-50" />
                              <time dateTime={publishedAt.iso || undefined}>{publishedAt.time}</time>
                            </span>
                          )}
                          <span className="inline-flex items-center gap-1.5">
                            <Eye size={13} className="opacity-80" strokeWidth={2} />
                            <span>{formatCount(news.views, langCode)}</span>
                          </span>
                          <span className="inline-flex items-center gap-1.5">
                            <MessageSquare size={13} className="opacity-80" strokeWidth={2} />
                            <span>{formatCount(news.comments, langCode)}</span>
                          </span>
                          <span className="inline-flex items-center gap-1.5">
                            <Heart size={13} className="opacity-80" strokeWidth={2} />
                            <span>{formatCount(news.likes, langCode)}</span>
                          </span>
                        </div>
                      </div>
                    </button>
                  );
                })
              ) : (
                <div className="text-center py-20 bg-white rounded-[5px] border-2 border-dashed border-gray-200">
                  <div className="w-16 h-16 bg-gray-100 rounded-[5px] flex items-center justify-center mx-auto mb-4">
                    <FileText size={32} className="text-gray-400" strokeWidth={1.5} />
                  </div>
                  <p className="text-sm font-semibold text-gray-500">{t('user_profile.no_content')}</p>
                </div>
              )}
            </div>

          </div>

        </div>

      </div>

    </div>
    </>
  );
};

export default UserProfile;
