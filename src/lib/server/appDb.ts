import type { PoolClient } from 'pg';
import { dbQuery, getPool } from './neonDb';
import { getSessionFromToken, type NeonSession } from './neonAuth';

let schemaReady: Promise<void> | null = null;

export async function ensureAppSchema() {
  if (!schemaReady) {
    schemaReady = (async () => {
      await dbQuery(`
        ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS show_email boolean DEFAULT true;
        ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS rss_feeds boolean DEFAULT true;
        ALTER TABLE public.posts ADD COLUMN IF NOT EXISTS views_count integer DEFAULT 0;
        ALTER TABLE public.posts ADD COLUMN IF NOT EXISTS saves_count integer DEFAULT 0;
        ALTER TABLE public.posts ADD COLUMN IF NOT EXISTS show_in_manset boolean DEFAULT false;
        ALTER TABLE public.comments ALTER COLUMN user_id DROP NOT NULL;
        ALTER TABLE public.site_settings ADD COLUMN IF NOT EXISTS weather_enabled boolean DEFAULT true;
        ALTER TABLE public.site_settings ADD COLUMN IF NOT EXISTS weather_location_name text DEFAULT 'Niğde';
        ALTER TABLE public.site_settings ADD COLUMN IF NOT EXISTS weather_location_country text DEFAULT 'Türkiye';
        ALTER TABLE public.site_settings ADD COLUMN IF NOT EXISTS weather_latitude double precision DEFAULT 37.96583;
        ALTER TABLE public.site_settings ADD COLUMN IF NOT EXISTS weather_longitude double precision DEFAULT 34.67935;
        ALTER TABLE public.site_settings ADD COLUMN IF NOT EXISTS weather_timezone text DEFAULT 'Europe/Istanbul';
        ALTER TABLE public.site_settings ADD COLUMN IF NOT EXISTS weather_update_interval_minutes integer DEFAULT 30;

        CREATE TABLE IF NOT EXISTS public.app_cache (
          key text PRIMARY KEY,
          payload jsonb NOT NULL,
          expires_at timestamptz NOT NULL,
          updated_at timestamptz DEFAULT now()
        );

        CREATE INDEX IF NOT EXISTS app_cache_expires_at_idx
          ON public.app_cache (expires_at);

        CREATE TABLE IF NOT EXISTS public.newsletter_subscribers (
          id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
          email text NOT NULL,
          language_code text DEFAULT 'tr',
          source text DEFAULT 'site',
          status text DEFAULT 'active',
          created_at timestamptz DEFAULT now(),
          updated_at timestamptz DEFAULT now()
        );

        CREATE UNIQUE INDEX IF NOT EXISTS newsletter_subscribers_email_unique
          ON public.newsletter_subscribers (lower(email));

        CREATE TABLE IF NOT EXISTS public.password_reset_requests (
          id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
          email text NOT NULL,
          token_hash text NOT NULL,
          used_at timestamptz,
          expires_at timestamptz NOT NULL,
          created_at timestamptz DEFAULT now()
        );

        CREATE TABLE IF NOT EXISTS public.post_reactions (
          id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
          post_id bigint NOT NULL REFERENCES public.posts(id) ON DELETE CASCADE,
          user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
          reaction text NOT NULL,
          created_at timestamptz DEFAULT now()
        );

        CREATE UNIQUE INDEX IF NOT EXISTS post_reactions_post_user_reaction_unique
          ON public.post_reactions (post_id, user_id, reaction);

        DELETE FROM public.post_likes a USING public.post_likes b
          WHERE a.ctid < b.ctid AND a.post_id IS NOT DISTINCT FROM b.post_id AND a.user_id IS NOT DISTINCT FROM b.user_id;
        DELETE FROM public.post_dislikes a USING public.post_dislikes b
          WHERE a.ctid < b.ctid AND a.post_id IS NOT DISTINCT FROM b.post_id AND a.user_id IS NOT DISTINCT FROM b.user_id;
        DELETE FROM public.post_saves a USING public.post_saves b
          WHERE a.ctid < b.ctid AND a.post_id IS NOT DISTINCT FROM b.post_id AND a.user_id IS NOT DISTINCT FROM b.user_id;
        DELETE FROM public.publisher_follows a USING public.publisher_follows b
          WHERE a.ctid < b.ctid AND a.publisher_id IS NOT DISTINCT FROM b.publisher_id AND a.user_id IS NOT DISTINCT FROM b.user_id;
        DELETE FROM public.publisher_blocks a USING public.publisher_blocks b
          WHERE a.ctid < b.ctid AND a.publisher_id IS NOT DISTINCT FROM b.publisher_id AND a.blocked_user_id IS NOT DISTINCT FROM b.blocked_user_id;

        CREATE UNIQUE INDEX IF NOT EXISTS post_likes_post_user_unique
          ON public.post_likes (post_id, user_id) WHERE user_id IS NOT NULL;
        CREATE UNIQUE INDEX IF NOT EXISTS post_dislikes_post_user_unique
          ON public.post_dislikes (post_id, user_id) WHERE user_id IS NOT NULL;
        CREATE UNIQUE INDEX IF NOT EXISTS post_saves_post_user_unique
          ON public.post_saves (post_id, user_id) WHERE user_id IS NOT NULL;
        CREATE UNIQUE INDEX IF NOT EXISTS publisher_follows_publisher_user_unique
          ON public.publisher_follows (publisher_id, user_id) WHERE publisher_id IS NOT NULL AND user_id IS NOT NULL;
        CREATE UNIQUE INDEX IF NOT EXISTS publisher_blocks_publisher_user_unique
          ON public.publisher_blocks (publisher_id, blocked_user_id) WHERE publisher_id IS NOT NULL AND blocked_user_id IS NOT NULL;

        CREATE INDEX IF NOT EXISTS posts_manset_feed_idx
          ON public.posts (language_code, status, published_at DESC)
          WHERE show_in_manset IS TRUE;

        CREATE TABLE IF NOT EXISTS public.languages (
          code text PRIMARY KEY,
          name text NOT NULL,
          direction text DEFAULT 'ltr',
          status text DEFAULT 'active',
          flag_code text,
          is_default boolean DEFAULT false,
          created_at timestamptz DEFAULT now(),
          updated_at timestamptz DEFAULT now()
        );

        ALTER TABLE public.languages ADD COLUMN IF NOT EXISTS direction text DEFAULT 'ltr';
        ALTER TABLE public.languages ADD COLUMN IF NOT EXISTS status text DEFAULT 'active';
        ALTER TABLE public.languages ADD COLUMN IF NOT EXISTS flag_code text;
        ALTER TABLE public.languages ADD COLUMN IF NOT EXISTS is_default boolean DEFAULT false;
        ALTER TABLE public.languages ADD COLUMN IF NOT EXISTS created_at timestamptz DEFAULT now();
        ALTER TABLE public.languages ADD COLUMN IF NOT EXISTS updated_at timestamptz DEFAULT now();

        INSERT INTO public.languages (code, name, direction, status, flag_code, is_default)
        VALUES
          ('tr', 'Türkçe', 'ltr', 'active', 'tr', true),
          ('en', 'English', 'ltr', 'active', 'us', false),
          ('ar', 'العربية', 'rtl', 'active', 'sa', false)
        ON CONFLICT (code) DO NOTHING;

        UPDATE public.languages
        SET status = 'active', updated_at = now()
        WHERE code IN ('tr', 'en', 'ar') AND status <> 'active';

        UPDATE public.languages
        SET is_default = true, updated_at = now()
        WHERE code = 'tr'
          AND NOT EXISTS (
            SELECT 1 FROM public.languages WHERE is_default IS TRUE
          );

        CREATE TABLE IF NOT EXISTS public.language_translations (
          language_code text NOT NULL REFERENCES public.languages(code) ON DELETE CASCADE,
          key text NOT NULL,
          value text NOT NULL DEFAULT '',
          updated_at timestamptz DEFAULT now(),
          PRIMARY KEY (language_code, key)
        );

        CREATE INDEX IF NOT EXISTS language_translations_language_idx
          ON public.language_translations (language_code);
      `);
    })();
  }

  return schemaReady;
}

export async function withTransaction<T>(fn: (client: PoolClient) => Promise<T>) {
  const client = await getPool().connect();
  try {
    await client.query('BEGIN');
    const result = await fn(client);
    await client.query('COMMIT');
    return result;
  } catch (error) {
    await client.query('ROLLBACK');
    throw error;
  } finally {
    client.release();
  }
}

export function getTokenFromRequest(request: Request, body?: Record<string, any>) {
  const authHeader = request.headers.get('authorization') || '';
  const bearer = authHeader.match(/^Bearer\s+(.+)$/i)?.[1];
  return bearer || body?.token || null;
}

export async function getSessionFromRequest(request: Request, body?: Record<string, any>): Promise<NeonSession | null> {
  return getSessionFromToken(getTokenFromRequest(request, body));
}

export async function getProfileRole(userId: string) {
  const result = await dbQuery<{ role: string | null }>(
    'SELECT role FROM public.profiles WHERE id = $1 LIMIT 1',
    [userId]
  );
  return result.rows[0]?.role || 'member';
}

export function json(data: any, status = 200) {
  return new Response(JSON.stringify(data), {
    status,
    headers: { 'Content-Type': 'application/json' },
  });
}
