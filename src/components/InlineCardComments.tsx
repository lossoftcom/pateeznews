import React, { useCallback, useEffect, useRef, useState } from 'react';
import { supabase } from '@/lib/supabase';
import { commentAction } from '@/services/appActions';
import { getRelativeTime } from '@/utils/helpers';
import { useLanguage } from '@/context/LanguageContext';
import { useToast } from '@/context/ToastContext';
import RemixIcon from './ui/RemixIcon';
import type { EmojiClickData } from 'emoji-picker-react';

const GUEST_NAME_KEY = 'pateez_guest_comment_name';
const GUEST_EMAIL_KEY = 'pateez_guest_comment_email';
const COLLAPSED_LIMIT = 2;
const EXPANDED_LIMIT = 20;
const COMMENT_MAX_LENGTH = 2000;
const COMMENT_GUIDANCE_TEXT = "Pateez.com'da paylaştığın yorumlar haber tartışmasına katkı sağlar. Farklı görüşlere saygılı kal; hakaret, hedef gösterme ve ayrımcı ifadeler kullanma.";

const EmojiPicker = React.lazy(async () => {
  const module = await import('emoji-picker-react');
  const Picker = (module.default as any).default || module.default;
  return { default: Picker as React.ComponentType<any> };
});

interface InlineCommentAuthor {
  id: string;
  name: string;
  avatarUrl: string;
  handle?: string;
  isVerified?: boolean;
  isOfficial?: boolean;
}

interface InlineComment {
  id: string;
  parentId?: string;
  body: string;
  publishedAt: string;
  likes: number;
  userLiked: boolean;
  canDelete: boolean;
  author: InlineCommentAuthor;
  replies?: InlineComment[];
}

interface CommentsResponse {
  ok?: boolean;
  status?: 'pending' | 'approved' | string;
  comments?: InlineComment[];
  error?: { message?: string };
}

interface InlineCardCommentsProps {
  postId: string | number;
  totalCount: number;
  publisherId?: string;
  commentApprovalEnabled?: boolean;
  emojiEnabled?: boolean;
  loadImmediately?: boolean;
  showGuidance?: boolean;
}

interface InlineProfileCache {
  username?: string;
  full_name?: string;
  avatar_url?: string;
}

const normalizeComments = (value: unknown): InlineComment[] => (
  Array.isArray(value) ? value as InlineComment[] : []
);

const validEmail = (value: string) => /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(value.trim());

const avatarForName = (name: string) =>
  `https://ui-avatars.com/api/?name=${encodeURIComponent(name || 'Misafir')}&background=f3f4f6&color=94a3b8`;

const readProfileCache = (): InlineProfileCache | null => {
  if (typeof window === 'undefined') return null;
  try {
    const raw = localStorage.getItem('pateez_profile_cache');
    return raw ? JSON.parse(raw) as InlineProfileCache : null;
  } catch {
    return null;
  }
};

const InlineCardComments: React.FC<InlineCardCommentsProps> = ({
  postId,
  totalCount,
  commentApprovalEnabled = true,
  emojiEnabled = true,
  loadImmediately = false,
  showGuidance = false,
}) => {
  const { t, currentLang } = useLanguage();
  const { showToast } = useToast();
  const [comments, setComments] = useState<InlineComment[]>([]);
  const [expanded, setExpanded] = useState(false);
  const [loading, setLoading] = useState(loadImmediately || totalCount > 0);
  const [submitting, setSubmitting] = useState(false);
  const [busyCommentId, setBusyCommentId] = useState<string | null>(null);
  const [replyTo, setReplyTo] = useState<InlineComment | null>(null);
  const [user, setUser] = useState<any | null | undefined>(undefined);
  const [profile, setProfile] = useState<InlineProfileCache | null>(null);
  const [guestName, setGuestName] = useState('');
  const [guestEmail, setGuestEmail] = useState('');
  const [newComment, setNewComment] = useState('');
  const [showEmojiPicker, setShowEmojiPicker] = useState(false);
  const emojiRef = useRef<HTMLDivElement>(null);

  const limit = expanded ? EXPANDED_LIMIT : COLLAPSED_LIMIT;
  const visibleComments = expanded ? comments : comments.slice(0, COLLAPSED_LIMIT);
  const canToggleMore = totalCount > COLLAPSED_LIMIT || comments.length > COLLAPSED_LIMIT;
  const canSend = newComment.trim().length > 0
    && newComment.trim().length <= COMMENT_MAX_LENGTH
    && (user ? true : user === null && guestName.trim().length >= 2 && validEmail(guestEmail));

  const loadComments = useCallback(async (nextLimit = COLLAPSED_LIMIT) => {
    setLoading(true);
    try {
      const result = await commentAction<CommentsResponse>('list', { postId, limit: nextLimit });
      setComments(normalizeComments(result.comments));
    } catch {
      setComments([]);
    } finally {
      setLoading(false);
    }
  }, [postId]);

  useEffect(() => {
    let mounted = true;
    const bootstrap = async () => {
      if (typeof window !== 'undefined') {
        setGuestName(localStorage.getItem(GUEST_NAME_KEY) || '');
        setGuestEmail(localStorage.getItem(GUEST_EMAIL_KEY) || '');
        setProfile(readProfileCache());
      }
      const sessionPromise = supabase.auth.getSession();
      if (loadImmediately || totalCount > 0) {
        void loadComments(COLLAPSED_LIMIT);
      } else {
        setComments([]);
        setLoading(false);
      }
      const { data } = await sessionPromise;
      if (!mounted) return;
      setUser(data.session?.user || null);
      setProfile(data.session?.user ? readProfileCache() : null);
    };
    const { data: { subscription } } = supabase.auth.onAuthStateChange((_event, session) => {
      if (!mounted) return;
      setUser(session?.user || null);
      setProfile(session?.user ? readProfileCache() : null);
    });
    void bootstrap();
    return () => {
      mounted = false;
      subscription.unsubscribe();
    };
  }, [postId, loadComments, loadImmediately, totalCount]);

  useEffect(() => {
    const handleOutside = (event: MouseEvent) => {
      if (emojiRef.current && !emojiRef.current.contains(event.target as Node)) {
        setShowEmojiPicker(false);
      }
    };
    document.addEventListener('mousedown', handleOutside);
    return () => document.removeEventListener('mousedown', handleOutside);
  }, []);

  const saveGuestIdentity = () => {
    if (typeof window === 'undefined' || user) return;
    localStorage.setItem(GUEST_NAME_KEY, guestName.trim());
    localStorage.setItem(GUEST_EMAIL_KEY, guestEmail.trim());
  };

  const handleSubmit = async () => {
    if (user === undefined) return;
    if (!canSend || submitting) {
      if (!user && newComment.trim() && (!guestName.trim() || !validEmail(guestEmail))) {
        showToast(t('comments.enter_name_email'), 'info');
      }
      return;
    }
    setSubmitting(true);
    try {
      saveGuestIdentity();
      const result = await commentAction<CommentsResponse>('submit', {
        postId,
        content: newComment.trim(),
        guestName: guestName.trim(),
        guestEmail: guestEmail.trim(),
        parentId: replyTo?.id,
        limit,
      });
      setComments(normalizeComments(result.comments));
      setNewComment('');
      setReplyTo(null);
      setShowEmojiPicker(false);
      showToast(
        result.status === 'approved' || commentApprovalEnabled === false
          ? t('comments.reply_sent_success')
          : t('comments.submitted_pending'),
        'success',
      );
    } catch (error: any) {
      showToast(error?.message || t('comments.submit_error'), 'error');
    } finally {
      setSubmitting(false);
    }
  };

  const handleEmojiClick = (emojiData: EmojiClickData) => {
    setNewComment((value) => `${value}${emojiData.emoji}`);
  };

  const handleToggleExpanded = async () => {
    const nextExpanded = !expanded;
    setExpanded(nextExpanded);
    await loadComments(nextExpanded ? EXPANDED_LIMIT : COLLAPSED_LIMIT);
  };

  const handleCommentLike = async (comment: InlineComment) => {
    if (!user) {
      showToast(t('auth.login_required_like'), 'info');
      return;
    }
    setBusyCommentId(comment.id);
    try {
      const result = await commentAction<CommentsResponse>('toggle_like', {
        postId,
        commentId: comment.id,
        limit,
      });
      setComments(normalizeComments(result.comments));
    } catch (error: any) {
      showToast(error?.message || t('common.like_failed'), 'error');
    } finally {
      setBusyCommentId(null);
    }
  };

  const handleDelete = async (comment: InlineComment) => {
    if (!comment.canDelete) return;
    setBusyCommentId(comment.id);
    try {
      const result = await commentAction<CommentsResponse>('delete', {
        postId,
        commentId: comment.id,
        limit,
      });
      setComments(normalizeComments(result.comments));
      setReplyTo(null);
      showToast(t('comments.deleted_short'), 'success');
    } catch (error: any) {
      showToast(error?.message || t('comments.delete_failed'), 'error');
    } finally {
      setBusyCommentId(null);
    }
  };

  const activeProfile = profile || (user as any)?.profile || null;
  const activeName = user
    ? (
      activeProfile?.full_name ||
      activeProfile?.username ||
      user.user_metadata?.full_name ||
      user.user_metadata?.name ||
      user.email?.split('@')[0] ||
      t('comments.guest')
    )
    : t('comments.guest');
  const activeAvatar = activeProfile?.avatar_url || user?.user_metadata?.avatar_url || avatarForName(activeName);
  const sessionReady = user !== undefined;

  return (
    <div
      className="pointer-events-auto border-t border-palette-beige/30 bg-white"
      onClick={(event) => event.stopPropagation()}
      data-news-card-comments
    >
      <div className="px-6 pt-2">
        {loading ? null : visibleComments.length > 0 ? (
          <div className="space-y-2 pb-2">
            {visibleComments.map((comment) => (
              <InlineCommentTile
                key={comment.id}
                comment={comment}
                currentLang={currentLang.code}
                busy={busyCommentId === comment.id}
                onLike={handleCommentLike}
                onReply={setReplyTo}
                onDelete={handleDelete}
              />
            ))}
            {canToggleMore && (
              <button
                type="button"
                onClick={handleToggleExpanded}
                className="mx-auto flex items-center gap-1 rounded-full px-2 py-1 text-[10px] font-black text-palette-tan/50 hover:text-gray-800 transition-colors"
              >
                <RemixIcon name={expanded ? 'ri-arrow-up-s-fill' : 'ri-arrow-down-s-fill'} size={13} />
                {expanded ? t('common.less') : t('common.show_all')}
              </button>
            )}
          </div>
        ) : null}
      </div>

      <div className="px-6 py-3">
        {replyTo && (
          <div className="mb-2 flex items-center justify-between rounded-[8px] border border-palette-beige/40 bg-gray-50 px-3 py-2">
            <div className="min-w-0 text-[11px] font-bold text-gray-500">
              <span className="text-gray-900">{replyTo.author.name}</span>
              <span> {t('comments.replying_to_suffix')}</span>
            </div>
            <button type="button" onClick={() => setReplyTo(null)} className="text-palette-tan/50 hover:text-palette-red">
              <RemixIcon name="ri-close-line" size={16} />
            </button>
          </div>
        )}

        {sessionReady && !user && (
          <div className="mb-2 grid grid-cols-2 gap-2">
            <InlineGuestInput
              icon="ri-user-3-line"
              placeholder="Ad soyad"
              value={guestName}
              onChange={setGuestName}
            />
            <InlineGuestInput
              icon="ri-at-line"
              placeholder="E-posta"
              value={guestEmail}
              onChange={setGuestEmail}
              type="email"
            />
          </div>
        )}

        <div className="flex items-center gap-2">
          <div className="flex h-[31px] w-[31px] shrink-0 items-center justify-center overflow-hidden rounded-full border border-palette-beige/40 bg-gray-50 text-palette-tan/50">
            {!sessionReady ? (
              <div className="h-3 w-3 rounded-full bg-palette-tan/20" />
            ) : user ? (
              <img src={activeAvatar} alt={activeName} className="h-full w-full object-cover" />
            ) : (
              <RemixIcon name="ri-chat-3-line" size={15} />
            )}
          </div>

          <div className="min-h-[36px] flex-1 rounded-[16px] border border-palette-beige/40 bg-gray-50 px-3 py-1.5 focus-within:border-gray-300 transition-colors">
            <textarea
              value={newComment}
              onChange={(event) => setNewComment(event.target.value.slice(0, COMMENT_MAX_LENGTH))}
              onKeyDown={(event) => {
                if (event.key === 'Enter' && !event.shiftKey) {
                  event.preventDefault();
                  void handleSubmit();
                }
              }}
              disabled={!sessionReady}
              rows={1}
              maxLength={COMMENT_MAX_LENGTH}
              placeholder={replyTo ? 'Yanıtınızı yazın' : 'Yorumunuzu ekleyin'}
              className="block max-h-24 min-h-[22px] w-full resize-none bg-transparent text-[13px] font-semibold leading-snug text-gray-800 outline-none placeholder:text-palette-tan/30"
            />
          </div>

          {emojiEnabled && (
            <div className="relative" ref={emojiRef}>
              <button
                type="button"
                onClick={() => setShowEmojiPicker((value) => !value)}
                className={`flex h-[31px] w-[31px] items-center justify-center rounded-full transition-colors ${showEmojiPicker ? 'bg-gray-100 text-gray-900' : 'text-palette-tan/45 hover:text-gray-900'}`}
                title={t('comments.add_emoji')}
              >
                <RemixIcon name="ri-emotion-happy-line" size={18} />
              </button>
              {showEmojiPicker && (
                <div
                  className="absolute bottom-full right-0 z-[240] mb-2 shadow-2xl animate-in fade-in zoom-in-95 slide-in-from-bottom-2"
                  data-inline-emoji-panel
                >
                  <React.Suspense fallback={null}>
                    <EmojiPicker
                      onEmojiClick={handleEmojiClick}
                      autoFocusSearch={false}
                      theme="light"
                      searchPlaceholder={t('comments.emoji_search_placeholder')}
                      width={300}
                      height={400}
                    />
                  </React.Suspense>
                </div>
              )}
            </div>
          )}

          <button
            type="button"
            onClick={() => void handleSubmit()}
            disabled={!sessionReady || !canSend || submitting}
            className={`px-2 py-1 text-[12px] font-black transition-colors ${canSend && !submitting ? 'text-gray-800 hover:text-palette-red' : 'text-palette-tan/30'}`}
          >
            {submitting ? 'Gönderiliyor' : 'Gönder'}
          </button>
        </div>
        {showGuidance && (
          <p className="mt-3 max-w-[620px] text-[11px] font-medium leading-[1.35] text-palette-tan/45">
            {COMMENT_GUIDANCE_TEXT}
          </p>
        )}
      </div>
    </div>
  );
};

interface InlineGuestInputProps {
  icon: string;
  placeholder: string;
  value: string;
  onChange: (value: string) => void;
  type?: string;
}

const InlineGuestInput: React.FC<InlineGuestInputProps> = ({ icon, placeholder, value, onChange, type = 'text' }) => (
  <label className="flex h-[31px] items-center gap-2 rounded-[7px] border border-palette-beige/40 bg-gray-50 px-2 text-palette-tan/35">
    <RemixIcon name={icon} size={13} />
    <input
      type={type}
      value={value}
      onChange={(event) => onChange(event.target.value)}
      placeholder={placeholder}
      className="min-w-0 flex-1 bg-transparent text-[11px] font-semibold text-gray-700 outline-none placeholder:text-palette-tan/30"
    />
  </label>
);

interface InlineCommentTileProps {
  comment: InlineComment;
  currentLang: string;
  busy: boolean;
  onLike: (comment: InlineComment) => void;
  onReply: (comment: InlineComment) => void;
  onDelete: (comment: InlineComment) => void;
}

const InlineCommentTile: React.FC<InlineCommentTileProps> = ({
  comment,
  currentLang,
  busy,
  onLike,
  onReply,
  onDelete,
}) => {
  const avatar = comment.author.avatarUrl || avatarForName(comment.author.name);
  const replies = Array.isArray(comment.replies) ? comment.replies.slice(0, 1) : [];
  return (
    <div className="flex gap-2">
      <img src={avatar} alt={comment.author.name} className="h-[29px] w-[29px] shrink-0 rounded-full border border-palette-beige/40 object-cover" />
      <div className="min-w-0 flex-1">
        <div className="rounded-[12px] rounded-tl-[4px] bg-gray-50 px-3 py-2">
          <div className="mb-1 flex items-center gap-2">
            <span className="truncate text-[11px] font-black text-gray-800">{comment.author.name}</span>
            <span className="shrink-0 text-[10px] font-semibold text-palette-tan/40">{getRelativeTime(comment.publishedAt, currentLang)}</span>
          </div>
          <p className="text-[12px] font-medium leading-relaxed text-gray-600">{comment.body}</p>
        </div>
        <div className="mt-1 flex items-center gap-3 pl-1">
          <button
            type="button"
            disabled={busy}
            onClick={() => onLike(comment)}
            className={`flex items-center gap-1 text-[10px] font-bold transition-colors ${comment.userLiked ? 'text-palette-red' : 'text-palette-tan/45 hover:text-palette-red'}`}
          >
            <RemixIcon name={comment.userLiked ? 'ri-heart-3-fill' : 'ri-heart-3-line'} size={12} />
            <span>{comment.likes > 0 ? comment.likes : 'Beğen'}</span>
          </button>
          <button
            type="button"
            onClick={() => onReply(comment)}
            className="flex items-center gap-1 text-[10px] font-bold text-palette-tan/45 hover:text-gray-800 transition-colors"
          >
            <RemixIcon name="ri-reply-line" size={12} />
            <span>Yanıtla</span>
          </button>
          {comment.canDelete && (
            <button
              type="button"
              disabled={busy}
              onClick={() => onDelete(comment)}
              className="flex items-center gap-1 text-[10px] font-bold text-palette-tan/35 hover:text-palette-red transition-colors"
            >
              <RemixIcon name="ri-delete-bin-line" size={12} />
              <span>Sil</span>
            </button>
          )}
        </div>
        {replies.map((reply) => (
          <div key={reply.id} className="mt-2 ml-4 border-l border-palette-beige/50 pl-2">
            <InlineCommentTile
              comment={reply}
              currentLang={currentLang}
              busy={busy}
              onLike={onLike}
              onReply={onReply}
              onDelete={onDelete}
            />
          </div>
        ))}
      </div>
    </div>
  );
};

export default InlineCardComments;
