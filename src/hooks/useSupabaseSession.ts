import { useEffect, useState } from 'react';
import { supabase, type Session, type User } from '@/lib/supabase';

export interface Profile {
  id: string;
  username: string;
  full_name: string;
  avatar_url: string;
  role: string;
  email?: string;
}

export function useSupabaseSession(): {
  session: Session | null;
  user: User | null;
  profile: Profile | null;
  loading: boolean;
} {
  // Initial state must match SSR output to avoid hydration mismatch.
  const [session, setSession] = useState<Session | null>(null);
  const [profile, setProfile] = useState<Profile | null>(null);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    let isMounted = true;

    const hasAuthToken = () => {
      try {
        return Object.keys(localStorage).some(
          (key) => key === 'pateeznews-supabase-auth'
        );
      } catch {
        return false;
      }
    };

    const hydrateProfileCache = () => {
      try {
        const cached = localStorage.getItem('pateez_profile_cache');
        if (!cached) return null;
        return JSON.parse(cached) as Profile;
      } catch {
        return null;
      }
    };

    async function fetchProfile(userId: string) {
      const { data, error } = await supabase
        .from('profiles')
        .select('id,username,full_name,avatar_url,role,email')
        .eq('id', userId)
        .single();

      if (isMounted && data && !error) {
        setProfile(data as Profile);
        // Cache for instant access on next hydration
        try {
          localStorage.setItem('pateez_profile_cache', JSON.stringify(data));
        } catch { }
      }
    }

    // Hydrate cached avatar/profile after mount (prevents SSR/client mismatch).
    const tokenExists = hasAuthToken();
    const cachedProfile = tokenExists ? hydrateProfileCache() : null;
    if (cachedProfile && isMounted) {
      setProfile(cachedProfile);
    }

    // If we have no auth token, don't block UI waiting for auth resolution.
    if (!tokenExists) {
      setLoading(false);
    }

    supabase.auth.getSession().then(({ data: { session: currentSession } }) => {
      if (!isMounted) return;
      if (currentSession) {
        setSession(currentSession);
        fetchProfile(currentSession.user.id);
      } else {
        setSession(null);
        setProfile(null);
        try {
          localStorage.removeItem('pateez_profile_cache');
        } catch { }
      }
      setLoading(false);
    });

    const { data: { subscription } } = supabase.auth.onAuthStateChange((_event, nextSession) => {
      if (isMounted) {
        setSession(nextSession);
        if (nextSession) {
          fetchProfile(nextSession.user.id);
        } else {
          setProfile(null);
          // Clear cache on logout
          try {
            localStorage.removeItem('pateez_profile_cache');
          } catch { }
        }
        setLoading(false);
      }
    });

    return () => {
      isMounted = false;
      subscription.unsubscribe();
    };
  }, []);

  return { session, user: session?.user ?? null, profile, loading };
}
