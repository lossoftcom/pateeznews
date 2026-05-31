-- Baseline schema formerly executed by ensureAppSchema at request time.

BEGIN;

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
  full_name text DEFAULT '',
  phone text DEFAULT '',
  ip_address text DEFAULT '',
  city text DEFAULT '',
  language_code text DEFAULT 'tr',
  source text DEFAULT 'site',
  status text DEFAULT 'active',
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

ALTER TABLE public.newsletter_subscribers ADD COLUMN IF NOT EXISTS full_name text DEFAULT '';
ALTER TABLE public.newsletter_subscribers ADD COLUMN IF NOT EXISTS phone text DEFAULT '';
ALTER TABLE public.newsletter_subscribers ADD COLUMN IF NOT EXISTS ip_address text DEFAULT '';
ALTER TABLE public.newsletter_subscribers ADD COLUMN IF NOT EXISTS city text DEFAULT '';

CREATE UNIQUE INDEX IF NOT EXISTS newsletter_subscribers_email_unique
  ON public.newsletter_subscribers (lower(email));
CREATE INDEX IF NOT EXISTS newsletter_subscribers_created_at_idx
  ON public.newsletter_subscribers (created_at DESC);
CREATE INDEX IF NOT EXISTS newsletter_subscribers_status_created_idx
  ON public.newsletter_subscribers (status, created_at DESC);

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

CREATE TABLE IF NOT EXISTS public.pages (
  id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  title text NOT NULL DEFAULT '',
  slug text,
  language_code text DEFAULT 'tr' REFERENCES public.languages(code) ON DELETE SET DEFAULT,
  category_id uuid REFERENCES public.navigation_items(id) ON DELETE SET NULL,
  category text DEFAULT '',
  page_type text DEFAULT 'custom',
  status text DEFAULT 'active',
  location text DEFAULT 'top_menu',
  parent_page_id uuid REFERENCES public.pages(id) ON DELETE SET NULL,
  show_title boolean DEFAULT true,
  show_breadcrumb boolean DEFAULT true,
  show_sidebar boolean DEFAULT true,
  registered_only boolean DEFAULT false,
  menu_order integer DEFAULT 1,
  content_delta jsonb DEFAULT '[{"insert":"\\n"}]'::jsonb,
  content_plain text DEFAULT '',
  meta_title text DEFAULT '',
  meta_keywords text DEFAULT '',
  meta_description text DEFAULT '',
  canonical_url text DEFAULT '',
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

CREATE UNIQUE INDEX IF NOT EXISTS pages_language_slug_unique
  ON public.pages (language_code, slug)
  WHERE slug IS NOT NULL AND slug <> '';

CREATE INDEX IF NOT EXISTS pages_status_created_idx
  ON public.pages (status, created_at DESC);

CREATE INDEX IF NOT EXISTS pages_category_idx
  ON public.pages (category);
CREATE INDEX IF NOT EXISTS pages_category_id_idx
  ON public.pages (category_id);
CREATE INDEX IF NOT EXISTS pages_parent_page_id_idx
  ON public.pages (parent_page_id);
CREATE INDEX IF NOT EXISTS pages_language_code_idx
  ON public.pages (language_code);
CREATE INDEX IF NOT EXISTS pages_location_order_idx
  ON public.pages (location, menu_order, created_at DESC);

COMMIT;
