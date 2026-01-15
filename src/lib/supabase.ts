import { createClient } from '@supabase/supabase-js';

// Helper to get env vars with fallbacks for Vercel/Node environments
const getEnv = (key: string) => {
  if (typeof import.meta !== 'undefined' && import.meta.env && import.meta.env[key]) {
    return import.meta.env[key];
  }
  if (typeof process !== 'undefined' && process.env && process.env[key]) {
    return process.env[key];
  }
  return undefined;
};

const SUPABASE_URL = getEnv('PUBLIC_SUPABASE_URL') || getEnv('VITE_SUPABASE_URL');
const SUPABASE_ANON_KEY = getEnv('PUBLIC_SUPABASE_ANON_KEY') || getEnv('VITE_SUPABASE_ANON_KEY');

if (!SUPABASE_URL || !SUPABASE_ANON_KEY) {
  if (typeof window === 'undefined') {
    console.warn('CRITICAL: Supabase environment variables are missing! Check Vercel Settings.');
  }
}

// Create client only if URL is valid to prevent crash during initialization
export const supabase = (SUPABASE_URL && SUPABASE_URL.startsWith('http'))
  ? createClient(SUPABASE_URL, SUPABASE_ANON_KEY || '')
  : {
    from: () => ({
      select: () => ({
        eq: () => ({
          maybeSingle: () => Promise.resolve({ data: null, error: { message: 'Keys missing' } }),
          single: () => Promise.resolve({ data: null, error: { message: 'Keys missing' } }),
          order: () => ({ limit: () => Promise.resolve({ data: [], error: null }) }),
          in: () => ({ limit: () => Promise.resolve({ data: [], error: null }) }),
        }),
        order: () => ({ limit: () => Promise.resolve({ data: [], error: null }) }),
        single: () => Promise.resolve({ data: null, error: { message: 'Keys missing' } }),
        maybeSingle: () => Promise.resolve({ data: null, error: { message: 'Keys missing' } }),
        in: () => ({ limit: () => Promise.resolve({ data: [], error: null }) }),
      }),
    }),
    auth: {
      getSession: () => Promise.resolve({ data: { session: null }, error: null }),
      onAuthStateChange: () => ({ data: { subscription: { unsubscribe: () => { } } } }),
    }
  } as any; 
