-- WARNING: This schema is for context only and is not meant to be run.
-- Table order and constraints may not be valid for execution.

CREATE TABLE public.comment_likes (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  comment_id bigint,
  user_id uuid,
  created_at timestamp with time zone DEFAULT now(),
  CONSTRAINT comment_likes_pkey PRIMARY KEY (id),
  CONSTRAINT comment_likes_comment_id_fkey FOREIGN KEY (comment_id) REFERENCES public.comments(id),
  CONSTRAINT comment_likes_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.profiles(id)
);
CREATE TABLE public.comment_reports (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  comment_id bigint,
  user_id uuid,
  guest_email text,
  reason text NOT NULL,
  created_at timestamp with time zone DEFAULT now(),
  CONSTRAINT comment_reports_pkey PRIMARY KEY (id),
  CONSTRAINT comment_reports_comment_id_fkey FOREIGN KEY (comment_id) REFERENCES public.comments(id),
  CONSTRAINT comment_reports_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.profiles(id)
);
CREATE TABLE public.comments (
  id bigint GENERATED ALWAYS AS IDENTITY NOT NULL,
  post_id bigint NOT NULL,
  user_id uuid NOT NULL,
  parent_id bigint,
  content text NOT NULL,
  status text NOT NULL DEFAULT 'pending'::text CHECK (status = ANY (ARRAY['pending'::text, 'approved'::text, 'rejected'::text])),
  is_pinned boolean DEFAULT false,
  likes_count integer DEFAULT 0,
  created_at timestamp with time zone DEFAULT now(),
  updated_at timestamp with time zone DEFAULT now(),
  guest_name text,
  guest_email text,
  CONSTRAINT comments_pkey PRIMARY KEY (id),
  CONSTRAINT comments_post_id_fkey FOREIGN KEY (post_id) REFERENCES public.posts(id),
  CONSTRAINT comments_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.profiles(id),
  CONSTRAINT comments_parent_id_fkey FOREIGN KEY (parent_id) REFERENCES public.comments(id)
);
CREATE TABLE public.languages (
  code text NOT NULL,
  name text NOT NULL,
  direction text DEFAULT 'ltr'::text,
  status text DEFAULT 'active'::text,
  flag_code text,
  is_default boolean DEFAULT false,
  CONSTRAINT languages_pkey PRIMARY KEY (code)
);
CREATE TABLE public.navigation_items (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  menu_id uuid,
  parent_id uuid,
  label text NOT NULL,
  type text NOT NULL DEFAULT 'link'::text,
  value text,
  icon text,
  order_index integer DEFAULT 0,
  is_active boolean DEFAULT true,
  created_at timestamp with time zone DEFAULT now(),
  language_code text DEFAULT 'tr'::text,
  CONSTRAINT navigation_items_pkey PRIMARY KEY (id),
  CONSTRAINT navigation_items_menu_id_fkey FOREIGN KEY (menu_id) REFERENCES public.navigation_menus(id),
  CONSTRAINT navigation_items_parent_id_fkey FOREIGN KEY (parent_id) REFERENCES public.navigation_items(id)
);
CREATE TABLE public.navigation_menus (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  code text NOT NULL UNIQUE,
  name text NOT NULL,
  description text,
  created_at timestamp with time zone DEFAULT now(),
  CONSTRAINT navigation_menus_pkey PRIMARY KEY (id)
);
CREATE TABLE public.permissions (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  key text NOT NULL UNIQUE,
  label text NOT NULL,
  group_name text NOT NULL,
  description text,
  created_at timestamp with time zone DEFAULT now(),
  CONSTRAINT permissions_pkey PRIMARY KEY (id)
);
CREATE TABLE public.post_dislikes (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  user_id uuid,
  created_at timestamp with time zone DEFAULT now(),
  post_id bigint,
  CONSTRAINT post_dislikes_pkey PRIMARY KEY (id),
  CONSTRAINT post_dislikes_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id),
  CONSTRAINT post_dislikes_post_id_fkey FOREIGN KEY (post_id) REFERENCES public.posts(id)
);
CREATE TABLE public.post_likes (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  user_id uuid,
  created_at timestamp with time zone DEFAULT now(),
  post_id bigint,
  CONSTRAINT post_likes_pkey PRIMARY KEY (id),
  CONSTRAINT post_likes_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id),
  CONSTRAINT post_likes_post_id_fkey FOREIGN KEY (post_id) REFERENCES public.posts(id)
);
CREATE TABLE public.post_saves (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  user_id uuid,
  created_at timestamp with time zone DEFAULT now(),
  post_id bigint,
  CONSTRAINT post_saves_pkey PRIMARY KEY (id),
  CONSTRAINT post_saves_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id),
  CONSTRAINT post_saves_post_id_fkey FOREIGN KEY (post_id) REFERENCES public.posts(id)
);
CREATE TABLE public.post_shares (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  user_id uuid,
  platform text,
  created_at timestamp with time zone DEFAULT now(),
  post_id bigint,
  CONSTRAINT post_shares_pkey PRIMARY KEY (id),
  CONSTRAINT post_shares_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id),
  CONSTRAINT post_shares_post_id_fkey FOREIGN KEY (post_id) REFERENCES public.posts(id)
);
CREATE TABLE public.posts (
  created_at timestamp with time zone NOT NULL DEFAULT timezone('utc'::text, now()),
  publisher_id uuid,
  title text,
  summary text,
  content text,
  category text,
  type text,
  thumbnail_url text,
  media_url text,
  likes_count integer DEFAULT 0,
  comments_count integer DEFAULT 0,
  shares_count integer DEFAULT 0,
  card_data jsonb,
  slug text UNIQUE,
  items jsonb DEFAULT '[]'::jsonb,
  status text DEFAULT 'draft'::text,
  seo_title text,
  seo_description text,
  keywords text,
  language_code text DEFAULT 'tr'::text,
  published_at timestamp with time zone,
  updated_at timestamp with time zone DEFAULT now(),
  is_pinned boolean DEFAULT false,
  show_in_manset boolean DEFAULT false,
  search_vector tsvector,
  dislikes_count integer DEFAULT 0,
  id bigint GENERATED ALWAYS AS IDENTITY NOT NULL,
  fact_checked boolean DEFAULT false,
  schema_type text DEFAULT 'NewsArticle'::text,
  thumbnail_alt text,
  faq_data jsonb DEFAULT '[]'::jsonb,
  CONSTRAINT posts_pkey PRIMARY KEY (id),
  CONSTRAINT posts_publisher_id_fk_profiles FOREIGN KEY (publisher_id) REFERENCES public.profiles(id)
);
CREATE TABLE public.profiles (
  id uuid NOT NULL,
  username text,
  full_name text,
  avatar_url text,
  updated_at timestamp with time zone,
  role text DEFAULT 'member'::text,
  slug text,
  about_me text,
  social_links jsonb DEFAULT '{}'::jsonb,
  balance numeric DEFAULT 0,
  pageviews integer DEFAULT 0,
  status text DEFAULT 'Aktif'::text,
  reward_system boolean DEFAULT false,
  phone text,
  expertise text,
  foundation_date text,
  website text,
  address text,
  meta_title text,
  meta_keywords text,
  meta_description text,
  canonical_url text,
  email text,
  created_at timestamp with time zone DEFAULT now(),
  search_vector tsvector,
  CONSTRAINT profiles_pkey PRIMARY KEY (id),
  CONSTRAINT profiles_id_fkey FOREIGN KEY (id) REFERENCES auth.users(id)
);
CREATE TABLE public.publisher_blocks (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  publisher_id uuid,
  blocked_user_id uuid,
  created_at timestamp with time zone DEFAULT now(),
  CONSTRAINT publisher_blocks_pkey PRIMARY KEY (id),
  CONSTRAINT publisher_blocks_publisher_id_fkey FOREIGN KEY (publisher_id) REFERENCES public.profiles(id),
  CONSTRAINT publisher_blocks_blocked_user_id_fkey FOREIGN KEY (blocked_user_id) REFERENCES public.profiles(id)
);
CREATE TABLE public.publisher_categories (
  id uuid NOT NULL DEFAULT uuid_generate_v4(),
  publisher_id uuid,
  category_id uuid,
  created_at timestamp with time zone DEFAULT now(),
  CONSTRAINT publisher_categories_pkey PRIMARY KEY (id),
  CONSTRAINT publisher_categories_publisher_id_fkey FOREIGN KEY (publisher_id) REFERENCES public.profiles(id),
  CONSTRAINT publisher_categories_category_id_fkey FOREIGN KEY (category_id) REFERENCES public.navigation_items(id)
);
CREATE TABLE public.publisher_follows (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  publisher_id uuid,
  user_id uuid,
  created_at timestamp with time zone DEFAULT now(),
  CONSTRAINT publisher_follows_pkey PRIMARY KEY (id),
  CONSTRAINT publisher_follows_publisher_id_fkey FOREIGN KEY (publisher_id) REFERENCES public.profiles(id),
  CONSTRAINT publisher_follows_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id)
);
CREATE TABLE public.publisher_users (
  id uuid NOT NULL DEFAULT uuid_generate_v4(),
  publisher_id uuid,
  user_id uuid,
  created_at timestamp with time zone DEFAULT now(),
  CONSTRAINT publisher_users_pkey PRIMARY KEY (id),
  CONSTRAINT publisher_users_publisher_id_fkey FOREIGN KEY (publisher_id) REFERENCES public.profiles(id),
  CONSTRAINT publisher_users_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.profiles(id)
);
CREATE TABLE public.role_permissions (
  role_id uuid NOT NULL,
  permission_key text NOT NULL,
  CONSTRAINT role_permissions_pkey PRIMARY KEY (role_id, permission_key),
  CONSTRAINT role_permissions_role_id_fkey FOREIGN KEY (role_id) REFERENCES public.roles(id),
  CONSTRAINT role_permissions_permission_key_fkey FOREIGN KEY (permission_key) REFERENCES public.permissions(key)
);
CREATE TABLE public.roles (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  name text NOT NULL UNIQUE,
  label text NOT NULL,
  description text,
  color text DEFAULT '#1D4259'::text,
  created_at timestamp with time zone DEFAULT now(),
  CONSTRAINT roles_pkey PRIMARY KEY (id)
);
CREATE TABLE public.site_settings (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  language_code text NOT NULL UNIQUE,
  site_name text DEFAULT 'Buzz Haber'::text,
  timezone text DEFAULT 'Europe/Istanbul'::text,
  footer_about text,
  optional_url_button_name text,
  copyright_text text,
  logo_url text,
  footer_logo_url text,
  dark_logo_url text,
  email_logo_url text,
  favicon_url text,
  created_at timestamp with time zone DEFAULT now(),
  updated_at timestamp with time zone DEFAULT now(),
  home_title text,
  meta_description text,
  meta_keywords text,
  canonical_url text,
  og_image_url text,
  google_analytics_id text,
  google_search_console_code text,
  bing_verification_code text,
  twitter_username text,
  fb_app_id text,
  organization_legal_name text,
  organization_phone text,
  organization_address text,
  robots_txt text DEFAULT 'User-agent: *
Disallow: /admin/
Allow: /
Sitemap: https://yourdomain.com/sitemap.xml'::text,
  header_custom_codes text,
  footer_custom_codes text,
  site_primary_font text DEFAULT 'PateezInter'::text NOT NULL,
  site_title_font text DEFAULT 'PateezInter'::text NOT NULL,
  site_content_font text DEFAULT 'PateezInter'::text NOT NULL,
  site_font_sizes jsonb DEFAULT '{"fs-lg": 16, "fs-md": 15, "fs-sm": 13, "fs-xl": 18, "fs-xs": 12, "fs-base": 15, "fs-tiny": 11, "fs-content": 17, "fs-main-nav": 14, "fs-title-lg": 20, "fs-title-md": 18, "fs-title-sm": 16, "fs-title-xl": 22, "fs-title-xs": 14, "fs-post-title": 32, "fs-title-2xl": 24, "fs-title-3xl": 28, "fs-title-4xl": 30, "fs-title-5xl": 32, "fs-post-summary": 18}'::jsonb NOT NULL,
  weather_enabled boolean DEFAULT true,
  weather_location_name text DEFAULT 'Niğde'::text,
  weather_location_country text DEFAULT 'Türkiye'::text,
  weather_latitude double precision DEFAULT 37.96583,
  weather_longitude double precision DEFAULT 34.67935,
  weather_timezone text DEFAULT 'Europe/Istanbul'::text,
  weather_update_interval_minutes integer DEFAULT 30,
  market_enabled boolean DEFAULT true,
  market_provider text DEFAULT 'genelpara'::text,
  market_altinapi_key text,
  market_altinapi_base_url text DEFAULT 'https://altinapi.com/api/v1'::text,
  market_genelpara_base_url text DEFAULT 'https://api.genelpara.com/json/'::text,
  market_update_interval_seconds integer DEFAULT 300,
  market_currency_symbols text DEFAULT 'USD,EUR,BTC,GBP,CHF,CAD,AUD,JPY,SAR,KWD,NOK,SEK,DKK,RUB,CNY,AED'::text,
  market_gold_symbols text DEFAULT 'HAS,ONS,AYAR22,GRAM,ALTINGUMUS,CEYREK,YARIM,TAM,CUMHURIYET,GREMSE,AYAR14,GUMUS,AYAR18,RESAT,ATA,BESLI,HAMIT,IKIBUCUK'::text,
  prayer_enabled boolean DEFAULT true,
  prayer_diyanet_base_url text DEFAULT 'https://namazvakitleri.diyanet.gov.tr'::text,
  prayer_location_name text DEFAULT 'Niğde'::text,
  prayer_location_country text DEFAULT 'Türkiye'::text,
  prayer_location_state_id integer DEFAULT 561,
  prayer_location_city_id integer DEFAULT 9766,
  prayer_timezone text DEFAULT 'Europe/Istanbul'::text,
  prayer_refresh_lead_days integer DEFAULT 3,
  prayer_cache_days integer DEFAULT 370,
  daily_ayah_enabled boolean DEFAULT true,
  daily_ayah_start_date date DEFAULT '2026-06-05'::date,
  daily_ayah_quran_api_base_url text DEFAULT 'https://t061.diyanet.gov.tr/apigateway/acikkaynakkuran'::text,
  daily_ayah_quran_api_token text,
  CONSTRAINT site_settings_pkey PRIMARY KEY (id)
);
CREATE TABLE public.site_fonts (
  id integer GENERATED BY DEFAULT AS IDENTITY,
  name text NOT NULL UNIQUE,
  family text NOT NULL UNIQUE,
  type text NOT NULL DEFAULT 'sans_serif'::text,
  source text NOT NULL DEFAULT 'local'::text,
  web_font_path text,
  flutter_family text,
  fallback_stack text,
  font_files jsonb NOT NULL DEFAULT '{}'::jsonb,
  is_active boolean NOT NULL DEFAULT true,
  sort_order integer NOT NULL DEFAULT 0,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  updated_at timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT site_fonts_pkey PRIMARY KEY (id),
  CONSTRAINT site_fonts_source_check CHECK (source IN ('local'::text, 'system'::text)),
  CONSTRAINT site_fonts_type_check CHECK (type IN ('sans_serif'::text, 'serif'::text, 'monospace'::text, 'cursive'::text, 'fantasy'::text, 'system_ui'::text))
);
CREATE TABLE public.pages (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  title text NOT NULL DEFAULT ''::text,
  slug text,
  language_code text DEFAULT 'tr'::text,
  category_id uuid,
  category text DEFAULT ''::text,
  page_group text NOT NULL DEFAULT 'Kurumsal'::text,
  page_type text DEFAULT 'custom'::text,
  status text DEFAULT 'active'::text,
  location text DEFAULT 'top_menu'::text,
  parent_page_id uuid,
  show_title boolean DEFAULT true,
  show_breadcrumb boolean DEFAULT true,
  show_sidebar boolean DEFAULT true,
  registered_only boolean DEFAULT false,
  menu_order integer DEFAULT 1,
  content_delta jsonb DEFAULT '[{"insert":"\\n"}]'::jsonb,
  content_plain text DEFAULT ''::text,
  meta_title text DEFAULT ''::text,
  meta_keywords text DEFAULT ''::text,
  meta_description text DEFAULT ''::text,
  canonical_url text DEFAULT ''::text,
  created_at timestamp with time zone DEFAULT now(),
  updated_at timestamp with time zone DEFAULT now(),
  CONSTRAINT pages_pkey PRIMARY KEY (id),
  CONSTRAINT pages_category_id_fkey FOREIGN KEY (category_id) REFERENCES public.navigation_items(id) ON DELETE SET NULL,
  CONSTRAINT pages_language_code_fkey FOREIGN KEY (language_code) REFERENCES public.languages(code) ON DELETE SET DEFAULT,
  CONSTRAINT pages_parent_page_id_fkey FOREIGN KEY (parent_page_id) REFERENCES public.pages(id) ON DELETE SET NULL
);
CREATE UNIQUE INDEX pages_language_slug_unique ON public.pages USING btree (language_code, slug) WHERE ((slug IS NOT NULL) AND (slug <> ''::text));
CREATE INDEX pages_status_created_idx ON public.pages USING btree (status, created_at DESC);
CREATE INDEX pages_category_idx ON public.pages USING btree (category);
CREATE INDEX pages_group_idx ON public.pages USING btree (language_code, category_id, page_group, menu_order);
CREATE TABLE public.app_cache (
  key text NOT NULL,
  payload jsonb NOT NULL,
  expires_at timestamp with time zone NOT NULL,
  updated_at timestamp with time zone DEFAULT now(),
  CONSTRAINT app_cache_pkey PRIMARY KEY (key)
);
CREATE INDEX app_cache_expires_at_idx ON public.app_cache USING btree (expires_at);
CREATE TABLE public.announcement_sources (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  source_key text NOT NULL,
  name text NOT NULL,
  source_type text NOT NULL DEFAULT 'other'::text CHECK (source_type = ANY (ARRAY['institution'::text, 'municipality'::text, 'chamber'::text, 'union'::text, 'ngo'::text, 'education'::text, 'health'::text, 'sports'::text, 'utility'::text, 'media'::text, 'social'::text, 'other'::text])),
  category_hint text NOT NULL DEFAULT 'official'::text CHECK (category_hint = ANY (ARRAY['official'::text, 'power'::text, 'road'::text])),
  district text NOT NULL DEFAULT 'merkez'::text CHECK (district = ANY (ARRAY['merkez'::text, 'altunhisar'::text, 'bor'::text, 'camardi'::text, 'ciftlik'::text, 'ulukisla'::text])),
  website_url text,
  list_url text NOT NULL,
  social_url text,
  facebook_url text,
  instagram_url text,
  crawl_strategy text NOT NULL DEFAULT 'auto'::text CHECK (crawl_strategy = ANY (ARRAY['auto'::text, 'rss'::text, 'sitemap'::text, 'html'::text, 'social_public'::text, 'search'::text])),
  selector_config jsonb NOT NULL DEFAULT '{}'::jsonb,
  is_active boolean NOT NULL DEFAULT true,
  crawl_interval_minutes integer NOT NULL DEFAULT 30,
  last_checked_at timestamp with time zone,
  last_success_at timestamp with time zone,
  last_error text,
  sort_order integer NOT NULL DEFAULT 0,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  updated_at timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT announcement_sources_pkey PRIMARY KEY (id),
  CONSTRAINT announcement_sources_source_key_key UNIQUE (source_key)
);
CREATE INDEX announcement_sources_active_idx ON public.announcement_sources USING btree (is_active, sort_order, name);
CREATE INDEX announcement_sources_district_idx ON public.announcement_sources USING btree (district, is_active);
CREATE TABLE public.announcements (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  source_id uuid,
  source_key text NOT NULL,
  source_name text NOT NULL,
  category text NOT NULL DEFAULT 'official'::text CHECK (category = ANY (ARRAY['official'::text, 'power'::text, 'road'::text])),
  title text NOT NULL,
  summary text NOT NULL DEFAULT ''::text,
  body text NOT NULL DEFAULT ''::text,
  place text NOT NULL DEFAULT 'Niğde'::text,
  district text NOT NULL DEFAULT 'merkez'::text CHECK (district = ANY (ARRAY['merkez'::text, 'altunhisar'::text, 'bor'::text, 'camardi'::text, 'ciftlik'::text, 'ulukisla'::text])),
  time_label text NOT NULL DEFAULT ''::text,
  published_at timestamp with time zone,
  starts_at timestamp with time zone,
  ends_at timestamp with time zone,
  status_label text NOT NULL DEFAULT ''::text,
  schedule_label text NOT NULL DEFAULT ''::text,
  image_url text NOT NULL DEFAULT ''::text,
  source_url text NOT NULL,
  canonical_url text NOT NULL DEFAULT ''::text,
  linked_post_id bigint,
  external_id text NOT NULL DEFAULT ''::text,
  content_hash text NOT NULL,
  raw_payload jsonb NOT NULL DEFAULT '{}'::jsonb,
  ai_payload jsonb NOT NULL DEFAULT '{}'::jsonb,
  confidence numeric(4,3) NOT NULL DEFAULT 0,
  is_active boolean NOT NULL DEFAULT true,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  updated_at timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT announcements_pkey PRIMARY KEY (id),
  CONSTRAINT announcements_content_hash_key UNIQUE (content_hash),
  CONSTRAINT announcements_source_id_fkey FOREIGN KEY (source_id) REFERENCES public.announcement_sources(id) ON DELETE SET NULL,
  CONSTRAINT announcements_linked_post_id_fkey FOREIGN KEY (linked_post_id) REFERENCES public.posts(id) ON DELETE SET NULL
);
CREATE INDEX announcements_active_published_idx ON public.announcements USING btree (is_active, published_at DESC NULLS LAST, created_at DESC);
CREATE INDEX announcements_category_idx ON public.announcements USING btree (category, is_active);
CREATE INDEX announcements_district_idx ON public.announcements USING btree (district, is_active);
CREATE INDEX announcements_source_idx ON public.announcements USING btree (source_key, is_active);
CREATE INDEX announcements_linked_post_idx ON public.announcements USING btree (linked_post_id) WHERE linked_post_id IS NOT NULL;
CREATE TABLE public.announcement_media (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  announcement_id uuid NOT NULL,
  url text NOT NULL,
  alt_text text NOT NULL DEFAULT ''::text,
  source_url text NOT NULL DEFAULT ''::text,
  width integer,
  height integer,
  sort_order integer NOT NULL DEFAULT 0,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT announcement_media_pkey PRIMARY KEY (id),
  CONSTRAINT announcement_media_announcement_url_key UNIQUE (announcement_id, url),
  CONSTRAINT announcement_media_announcement_id_fkey FOREIGN KEY (announcement_id) REFERENCES public.announcements(id) ON DELETE CASCADE
);
CREATE TABLE public.announcement_crawl_runs (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  source_id uuid,
  run_type text NOT NULL DEFAULT 'manual'::text CHECK (run_type = ANY (ARRAY['manual'::text, 'cron'::text, 'discovery'::text, 'source'::text])),
  status text NOT NULL DEFAULT 'running'::text CHECK (status = ANY (ARRAY['running'::text, 'success'::text, 'partial'::text, 'error'::text])),
  started_at timestamp with time zone NOT NULL DEFAULT now(),
  finished_at timestamp with time zone,
  candidates_found integer NOT NULL DEFAULT 0,
  inserted_count integer NOT NULL DEFAULT 0,
  updated_count integer NOT NULL DEFAULT 0,
  skipped_count integer NOT NULL DEFAULT 0,
  error_message text,
  details jsonb NOT NULL DEFAULT '{}'::jsonb,
  CONSTRAINT announcement_crawl_runs_pkey PRIMARY KEY (id),
  CONSTRAINT announcement_crawl_runs_source_id_fkey FOREIGN KEY (source_id) REFERENCES public.announcement_sources(id) ON DELETE SET NULL
);
CREATE INDEX announcement_crawl_runs_started_idx ON public.announcement_crawl_runs USING btree (started_at DESC);
CREATE TABLE public.stories (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  created_at timestamp with time zone NOT NULL DEFAULT timezone('utc'::text, now()),
  publisher_id uuid NOT NULL,
  title text NOT NULL,
  media_url text NOT NULL,
  media_type text NOT NULL DEFAULT 'image'::text,
  source_name text,
  expires_at timestamp with time zone,
  is_active boolean DEFAULT true,
  view_count integer DEFAULT 0,
  story_data jsonb DEFAULT '{}'::jsonb,
  story_markup text DEFAULT ''::text,
  CONSTRAINT stories_pkey PRIMARY KEY (id),
  CONSTRAINT stories_publisher_id_fkey FOREIGN KEY (publisher_id) REFERENCES auth.users(id)
);
