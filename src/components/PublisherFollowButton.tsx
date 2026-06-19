import React, { useCallback, useEffect, useState } from 'react';
import { supabase } from '@/lib/supabase';
import { postAction } from '@/services/appActions';
import { useLanguage } from '@/context/LanguageContext';
import { useToast } from '@/context/ToastContext';

interface PublisherFollowButtonProps {
  publisherId?: string | null;
  postId?: string | number | null;
  initialFollowing?: boolean;
  as?: 'button' | 'span';
  className?: string;
}

const BASE_CLASS = 'inline-flex items-center justify-center tracking-normal text-[9px] font-[800] px-2 py-0.5 rounded-full transition-all';

const PublisherFollowButton: React.FC<PublisherFollowButtonProps> = ({
  publisherId,
  postId,
  initialFollowing = false,
  as = 'button',
  className = '',
}) => {
  const { t } = useLanguage();
  const { showToast } = useToast();
  const [userId, setUserId] = useState<string | null>(null);
  const [isFollowing, setIsFollowing] = useState(initialFollowing);
  const [isLoading, setIsLoading] = useState(false);

  useEffect(() => {
    let mounted = true;

    const syncUser = async () => {
      const { data } = await supabase.auth.getSession();
      if (mounted) setUserId(data.session?.user?.id || null);
    };

    void syncUser();
    const { data: { subscription } } = supabase.auth.onAuthStateChange((_event, session) => {
      if (mounted) setUserId(session?.user?.id || null);
    });

    return () => {
      mounted = false;
      subscription.unsubscribe();
    };
  }, []);

  useEffect(() => {
    setIsFollowing(initialFollowing);
  }, [initialFollowing, publisherId]);

  useEffect(() => {
    if (!userId || !publisherId || !postId) return;
    let mounted = true;

    postAction<{ userState?: { following?: boolean } }>('state', { postId, publisherId })
      .then((result) => {
        if (mounted && typeof result?.userState?.following === 'boolean') {
          setIsFollowing(result.userState.following);
        }
      })
      .catch(() => null);

    return () => {
      mounted = false;
    };
  }, [postId, publisherId, userId]);

  const toggleFollow = useCallback(async () => {
    if (!publisherId || !userId || isLoading) return;

    setIsLoading(true);
    try {
      const result = await postAction<{ following: boolean }>('toggle_follow', { publisherId });
      setIsFollowing(result.following);
    } catch {
      showToast(t('common.follow_failed'), 'error');
    } finally {
      setIsLoading(false);
    }
  }, [isLoading, publisherId, showToast, t, userId]);

  const handleClick = useCallback((event: React.MouseEvent<HTMLElement>) => {
    event.preventDefault();
    event.stopPropagation();
    void toggleFollow();
  }, [toggleFollow]);

  const handleKeyDown = useCallback((event: React.KeyboardEvent<HTMLElement>) => {
    if (event.key !== 'Enter' && event.key !== ' ') return;
    event.preventDefault();
    event.stopPropagation();
    void toggleFollow();
  }, [toggleFollow]);

  if (!userId || !publisherId || publisherId === userId) return null;

  const buttonClass = `${BASE_CLASS} ${isFollowing ? 'text-gray-400 bg-gray-100' : 'text-blue-600 bg-blue-50 hover:bg-blue-600 hover:text-white'} ${isLoading ? 'opacity-60' : ''} ${className}`.trim();
  const label = isFollowing ? t('common.following') : t('common.follow');

  if (as === 'span') {
    return (
      <span
        role="button"
        tabIndex={0}
        aria-disabled={isLoading}
        onClick={handleClick}
        onKeyDown={handleKeyDown}
        className={buttonClass}
      >
        {label}
      </span>
    );
  }

  return (
    <button
      type="button"
      disabled={isLoading}
      onClick={handleClick}
      className={buttonClass}
    >
      {label}
    </button>
  );
};

export default PublisherFollowButton;
