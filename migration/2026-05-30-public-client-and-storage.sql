-- Client-safe public grants and Supabase Storage baseline.

BEGIN;

ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public
  REVOKE SELECT, INSERT, UPDATE, DELETE ON TABLES FROM anon, authenticated, service_role;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public
  REVOKE USAGE, SELECT ON SEQUENCES FROM anon, authenticated, service_role;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public
  REVOKE EXECUTE ON FUNCTIONS FROM PUBLIC, anon, authenticated, service_role;

DROP POLICY IF EXISTS "users can read own profile" ON public.profiles;
DROP POLICY IF EXISTS "public can read safe profiles" ON public.profiles;

GRANT SELECT (
  id,
  username,
  full_name,
  avatar_url,
  role,
  slug,
  about_me,
  social_links,
  created_at,
  expertise,
  foundation_date,
  website,
  meta_title,
  meta_keywords,
  meta_description,
  canonical_url,
  show_email,
  rss_feeds
) ON public.profiles TO anon, authenticated;

CREATE POLICY "public can read safe profiles"
ON public.profiles
FOR SELECT
TO anon, authenticated
USING (COALESCE(status, 'active') <> 'blocked');

DROP POLICY IF EXISTS "public can read site settings" ON public.site_settings;

GRANT SELECT (
  id,
  language_code,
  site_name,
  timezone,
  footer_about,
  optional_url_button_name,
  copyright_text,
  logo_url,
  footer_logo_url,
  dark_logo_url,
  email_logo_url,
  favicon_url,
  home_title,
  meta_description,
  meta_keywords,
  canonical_url,
  og_image_url,
  google_analytics_id,
  google_search_console_code,
  bing_verification_code,
  twitter_username,
  fb_app_id,
  organization_legal_name,
  organization_phone,
  organization_address,
  robots_txt,
  weather_enabled,
  weather_location_name,
  weather_location_country,
  weather_latitude,
  weather_longitude,
  weather_timezone,
  weather_update_interval_minutes
) ON public.site_settings TO anon, authenticated;

CREATE POLICY "public can read site settings"
ON public.site_settings
FOR SELECT
TO anon, authenticated
USING (true);

INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
  'media',
  'media',
  true,
  104857600,
  ARRAY[
    'image/jpeg',
    'image/png',
    'image/webp',
    'image/gif',
    'image/avif',
    'image/svg+xml',
    'image/tiff',
    'video/mp4',
    'video/webm',
    'video/quicktime',
    'audio/mpeg',
    'audio/mp4',
    'audio/wav',
    'audio/ogg',
    'audio/aac',
    'application/pdf',
    'application/octet-stream'
  ]
)
ON CONFLICT (id) DO UPDATE SET
  public = EXCLUDED.public,
  file_size_limit = EXCLUDED.file_size_limit,
  allowed_mime_types = EXCLUDED.allowed_mime_types,
  updated_at = now();

DROP POLICY IF EXISTS "public can read media objects" ON storage.objects;
DROP POLICY IF EXISTS "authenticated can upload media objects" ON storage.objects;
DROP POLICY IF EXISTS "authenticated can update media objects" ON storage.objects;
DROP POLICY IF EXISTS "authenticated can delete media objects" ON storage.objects;
DROP POLICY IF EXISTS "admin can upload media objects" ON storage.objects;
DROP POLICY IF EXISTS "admin can update media objects" ON storage.objects;
DROP POLICY IF EXISTS "admin can delete media objects" ON storage.objects;

CREATE POLICY "public can read media objects"
ON storage.objects
FOR SELECT
TO anon, authenticated
USING (bucket_id = 'media');

CREATE POLICY "admin can upload media objects"
ON storage.objects
FOR INSERT
TO authenticated
WITH CHECK (
  bucket_id = 'media'
  AND EXISTS (
    SELECT 1
    FROM public.profiles p
    WHERE p.id = auth.uid()
      AND p.role = 'admin'
  )
);

CREATE POLICY "admin can update media objects"
ON storage.objects
FOR UPDATE
TO authenticated
USING (
  bucket_id = 'media'
  AND EXISTS (
    SELECT 1
    FROM public.profiles p
    WHERE p.id = auth.uid()
      AND p.role = 'admin'
  )
)
WITH CHECK (
  bucket_id = 'media'
  AND EXISTS (
    SELECT 1
    FROM public.profiles p
    WHERE p.id = auth.uid()
      AND p.role = 'admin'
  )
);

CREATE POLICY "admin can delete media objects"
ON storage.objects
FOR DELETE
TO authenticated
USING (
  bucket_id = 'media'
  AND EXISTS (
    SELECT 1
    FROM public.profiles p
    WHERE p.id = auth.uid()
      AND p.role = 'admin'
  )
);

COMMIT;
