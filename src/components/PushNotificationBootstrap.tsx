import { useEffect } from 'react';
import { supabase } from '@/lib/supabase';
import { requestAndRegisterBrowserPush } from '@/services/pushNotificationService';

export default function PushNotificationBootstrap() {
  useEffect(() => {
    let disposed = false;

    async function sync(authToken?: string) {
      if (disposed) return;
      try {
        await requestAndRegisterBrowserPush({
          authToken,
          topics: ['general'],
        });
      } catch (error) {
        console.warn('Pateez push registration failed', error);
      }
    }

    let unsubscribe = () => {};
    supabase.auth.getSession().then(({ data }) => {
      if (disposed) return;
      void sync(data.session?.access_token);
    });

    const { data } = supabase.auth.onAuthStateChange((_event, session) => {
      void sync(session?.access_token);
    });
    unsubscribe = () => data.subscription.unsubscribe();

    return () => {
      disposed = true;
      unsubscribe();
    };
  }, []);

  return null;
}
