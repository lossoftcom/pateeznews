-- Focused indexes for public feed, admin lists, comment reads, and media listing.

CREATE EXTENSION IF NOT EXISTS pg_trgm;

CREATE INDEX IF NOT EXISTS idx_posts_public_feed
ON public.posts (language_code, published_at DESC NULLS LAST, created_at DESC NULLS LAST, id DESC)
WHERE status = 'published';

CREATE INDEX IF NOT EXISTS idx_posts_public_category_lower
ON public.posts (language_code, lower(coalesce(category, '')))
WHERE status = 'published';

CREATE INDEX IF NOT EXISTS idx_posts_public_type_lower
ON public.posts (language_code, lower(coalesce(type, '')))
WHERE status = 'published';

CREATE INDEX IF NOT EXISTS idx_posts_admin_status_created
ON public.posts (status, created_at DESC, id DESC);

CREATE INDEX IF NOT EXISTS idx_posts_admin_publisher_created
ON public.posts (publisher_id, created_at DESC, id DESC);

CREATE INDEX IF NOT EXISTS idx_posts_admin_language_created
ON public.posts (language_code, created_at DESC, id DESC);

CREATE INDEX IF NOT EXISTS idx_posts_title_trgm
ON public.posts USING gin (title gin_trgm_ops);

CREATE INDEX IF NOT EXISTS idx_posts_summary_trgm
ON public.posts USING gin (summary gin_trgm_ops);

CREATE INDEX IF NOT EXISTS idx_posts_category_trgm
ON public.posts USING gin (category gin_trgm_ops);

CREATE INDEX IF NOT EXISTS idx_posts_slug_trgm
ON public.posts USING gin (slug gin_trgm_ops);

CREATE INDEX IF NOT EXISTS idx_posts_keywords_trgm
ON public.posts USING gin (keywords gin_trgm_ops);

CREATE INDEX IF NOT EXISTS idx_comments_post_status_created
ON public.comments (post_id, status, created_at DESC, id DESC);

CREATE INDEX IF NOT EXISTS idx_comments_status_created
ON public.comments (status, created_at DESC, id DESC);

CREATE INDEX IF NOT EXISTS idx_navigation_items_active_order
ON public.navigation_items (parent_id, order_index, id)
WHERE coalesce(is_active, true) = true;

CREATE INDEX IF NOT EXISTS idx_stories_active_expires_created
ON public.stories (is_active, expires_at DESC, created_at DESC, id DESC);

CREATE INDEX IF NOT EXISTS idx_pages_status_created
ON public.pages (status, created_at DESC, id DESC);

CREATE INDEX IF NOT EXISTS idx_pages_language_created
ON public.pages (language_code, created_at DESC, id DESC);

CREATE INDEX IF NOT EXISTS idx_pages_title_trgm
ON public.pages USING gin (title gin_trgm_ops);

CREATE INDEX IF NOT EXISTS idx_pages_slug_trgm
ON public.pages USING gin (slug gin_trgm_ops);

CREATE INDEX IF NOT EXISTS idx_profiles_role_status_created
ON public.profiles (role, status, created_at DESC, id);

CREATE INDEX IF NOT EXISTS idx_profiles_username_trgm
ON public.profiles USING gin (username gin_trgm_ops);

CREATE INDEX IF NOT EXISTS idx_profiles_full_name_trgm
ON public.profiles USING gin (full_name gin_trgm_ops);

CREATE INDEX IF NOT EXISTS idx_profiles_email_trgm
ON public.profiles USING gin (email gin_trgm_ops);

CREATE INDEX IF NOT EXISTS idx_newsletter_subscribers_status_created
ON public.newsletter_subscribers (status, created_at DESC, id);

CREATE INDEX IF NOT EXISTS idx_newsletter_subscribers_email_trgm
ON public.newsletter_subscribers USING gin (email gin_trgm_ops);

CREATE INDEX IF NOT EXISTS idx_newsletter_subscribers_full_name_trgm
ON public.newsletter_subscribers USING gin (full_name gin_trgm_ops);

CREATE INDEX IF NOT EXISTS idx_newsletter_subscribers_phone_trgm
ON public.newsletter_subscribers USING gin (phone gin_trgm_ops);

-- Hosted Supabase owns storage.objects with the supabase_storage_admin role.
-- App migrations run as postgres cannot create indexes on that managed table.
