-- Secure Supabase Data API access.
-- This migration removes broad anon/authenticated table access, enables RLS
-- across public tables, and only re-opens narrowly scoped client-safe access.

BEGIN;

REVOKE ALL PRIVILEGES ON ALL TABLES IN SCHEMA public FROM anon, authenticated;
REVOKE ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public FROM anon, authenticated;

DO $$
DECLARE
  target_table text;
BEGIN
  FOREACH target_table IN ARRAY ARRAY[
    'ai_ready_formats',
    'app_cache',
    'comment_likes',
    'comment_reports',
    'comments',
    'language_translations',
    'languages',
    'mail_accounts',
    'mail_campaigns',
    'mail_contact_list_memberships',
    'mail_contact_lists',
    'mail_contacts',
    'mail_inbox',
    'mail_outbox',
    'mail_settings',
    'mail_templates',
    'navigation_items',
    'navigation_menus',
    'newsletter_subscribers',
    'pages',
    'password_reset_requests',
    'permissions',
    'post_dislikes',
    'post_likes',
    'post_reactions',
    'post_saves',
    'post_shares',
    'posts',
    'profiles',
    'publisher_blocks',
    'publisher_categories',
    'publisher_follows',
    'publisher_users',
    'role_permissions',
    'roles',
    'site_settings',
    'sms_accounts',
    'sms_campaigns',
    'sms_chats',
    'sms_contact_list_memberships',
    'sms_contact_lists',
    'sms_contacts',
    'sms_messages',
    'sms_templates',
    'social_accounts',
    'social_connected_accounts',
    'social_posts',
    'stories',
    'whatsapp_accounts',
    'whatsapp_campaigns',
    'whatsapp_chats',
    'whatsapp_contact_list_memberships',
    'whatsapp_contact_lists',
    'whatsapp_contacts',
    'whatsapp_messages',
    'whatsapp_templates'
  ] LOOP
    EXECUTE format('ALTER TABLE public.%I ENABLE ROW LEVEL SECURITY', target_table);
  END LOOP;
END $$;

DO $$
DECLARE
  policy_record record;
BEGIN
  FOR policy_record IN
    SELECT schemaname, tablename, policyname
    FROM pg_policies
    WHERE schemaname = 'public'
      AND tablename = ANY(ARRAY[
        'ai_ready_formats',
        'comment_likes',
        'comment_reports',
        'comments',
        'language_translations',
        'languages',
        'navigation_items',
        'navigation_menus',
        'newsletter_subscribers',
        'pages',
        'permissions',
        'post_dislikes',
        'post_likes',
        'post_reactions',
        'post_saves',
        'post_shares',
        'posts',
        'profiles',
        'publisher_blocks',
        'publisher_follows',
        'role_permissions',
        'roles',
        'site_settings',
        'stories'
      ])
  LOOP
    EXECUTE format(
      'DROP POLICY IF EXISTS %I ON %I.%I',
      policy_record.policyname,
      policy_record.schemaname,
      policy_record.tablename
    );
  END LOOP;
END $$;

GRANT SELECT ON public.posts TO anon, authenticated;
CREATE POLICY "public can read published posts"
ON public.posts
FOR SELECT
TO anon, authenticated
USING (status = 'published');

GRANT SELECT ON public.pages TO anon, authenticated;
CREATE POLICY "public can read published pages"
ON public.pages
FOR SELECT
TO anon, authenticated
USING (status = 'published' AND COALESCE(registered_only, false) = false);

GRANT SELECT ON public.languages TO anon, authenticated;
CREATE POLICY "public can read active languages"
ON public.languages
FOR SELECT
TO anon, authenticated
USING (status = 'active');

GRANT SELECT ON public.language_translations TO anon, authenticated;
CREATE POLICY "public can read active language translations"
ON public.language_translations
FOR SELECT
TO anon, authenticated
USING (
  EXISTS (
    SELECT 1
    FROM public.languages
    WHERE languages.code = language_translations.language_code
      AND languages.status = 'active'
  )
);

GRANT SELECT ON public.navigation_menus TO anon, authenticated;
CREATE POLICY "public can read navigation menus"
ON public.navigation_menus
FOR SELECT
TO anon, authenticated
USING (true);

GRANT SELECT ON public.navigation_items TO anon, authenticated;
CREATE POLICY "public can read active navigation items"
ON public.navigation_items
FOR SELECT
TO anon, authenticated
USING (COALESCE(is_active, true) = true);

GRANT SELECT ON public.stories TO anon, authenticated;
CREATE POLICY "public can read active stories"
ON public.stories
FOR SELECT
TO anon, authenticated
USING (is_active = true AND (expires_at IS NULL OR expires_at > now()));

GRANT SELECT, INSERT, DELETE ON public.comments TO anon, authenticated;
CREATE POLICY "public can read approved comments"
ON public.comments
FOR SELECT
TO anon, authenticated
USING (status = 'approved');

CREATE POLICY "visitors can submit pending comments"
ON public.comments
FOR INSERT
TO anon, authenticated
WITH CHECK (
  status = 'pending'
  AND (
    (auth.uid() IS NULL AND user_id IS NULL)
    OR auth.uid() = user_id
  )
);

CREATE POLICY "users can delete own comments"
ON public.comments
FOR DELETE
TO authenticated
USING (auth.uid() = user_id);

GRANT INSERT ON public.comment_reports TO anon, authenticated;
CREATE POLICY "visitors can report comments"
ON public.comment_reports
FOR INSERT
TO anon, authenticated
WITH CHECK (
  comment_id IS NOT NULL
  AND length(trim(reason)) > 0
  AND (
    (auth.uid() IS NULL AND user_id IS NULL)
    OR auth.uid() = user_id
  )
);

GRANT SELECT, INSERT, DELETE ON public.comment_likes TO authenticated;
CREATE POLICY "users can read own comment likes"
ON public.comment_likes
FOR SELECT
TO authenticated
USING (auth.uid() = user_id);

CREATE POLICY "users can insert own comment likes"
ON public.comment_likes
FOR INSERT
TO authenticated
WITH CHECK (auth.uid() = user_id);

CREATE POLICY "users can delete own comment likes"
ON public.comment_likes
FOR DELETE
TO authenticated
USING (auth.uid() = user_id);

GRANT SELECT, INSERT, DELETE ON public.post_likes TO authenticated;
CREATE POLICY "users can read own post likes"
ON public.post_likes
FOR SELECT
TO authenticated
USING (auth.uid() = user_id);

CREATE POLICY "users can insert own post likes"
ON public.post_likes
FOR INSERT
TO authenticated
WITH CHECK (auth.uid() = user_id);

CREATE POLICY "users can delete own post likes"
ON public.post_likes
FOR DELETE
TO authenticated
USING (auth.uid() = user_id);

GRANT SELECT, INSERT, DELETE ON public.post_dislikes TO authenticated;
CREATE POLICY "users can read own post dislikes"
ON public.post_dislikes
FOR SELECT
TO authenticated
USING (auth.uid() = user_id);

CREATE POLICY "users can insert own post dislikes"
ON public.post_dislikes
FOR INSERT
TO authenticated
WITH CHECK (auth.uid() = user_id);

CREATE POLICY "users can delete own post dislikes"
ON public.post_dislikes
FOR DELETE
TO authenticated
USING (auth.uid() = user_id);

GRANT SELECT, INSERT, DELETE ON public.post_saves TO authenticated;
CREATE POLICY "users can read own post saves"
ON public.post_saves
FOR SELECT
TO authenticated
USING (auth.uid() = user_id);

CREATE POLICY "users can insert own post saves"
ON public.post_saves
FOR INSERT
TO authenticated
WITH CHECK (auth.uid() = user_id);

CREATE POLICY "users can delete own post saves"
ON public.post_saves
FOR DELETE
TO authenticated
USING (auth.uid() = user_id);

GRANT SELECT, INSERT, DELETE ON public.post_shares TO authenticated;
CREATE POLICY "users can read own post shares"
ON public.post_shares
FOR SELECT
TO authenticated
USING (auth.uid() = user_id);

CREATE POLICY "users can insert own post shares"
ON public.post_shares
FOR INSERT
TO authenticated
WITH CHECK (auth.uid() = user_id);

CREATE POLICY "users can delete own post shares"
ON public.post_shares
FOR DELETE
TO authenticated
USING (auth.uid() = user_id);

GRANT SELECT, INSERT, DELETE ON public.post_reactions TO authenticated;
CREATE POLICY "users can read own post reactions"
ON public.post_reactions
FOR SELECT
TO authenticated
USING (auth.uid() = user_id);

CREATE POLICY "users can insert own post reactions"
ON public.post_reactions
FOR INSERT
TO authenticated
WITH CHECK (auth.uid() = user_id);

CREATE POLICY "users can delete own post reactions"
ON public.post_reactions
FOR DELETE
TO authenticated
USING (auth.uid() = user_id);

GRANT SELECT, INSERT, DELETE ON public.publisher_follows TO authenticated;
CREATE POLICY "users can read own publisher follows"
ON public.publisher_follows
FOR SELECT
TO authenticated
USING (auth.uid() = user_id);

CREATE POLICY "users can insert own publisher follows"
ON public.publisher_follows
FOR INSERT
TO authenticated
WITH CHECK (auth.uid() = user_id);

CREATE POLICY "users can delete own publisher follows"
ON public.publisher_follows
FOR DELETE
TO authenticated
USING (auth.uid() = user_id);

GRANT SELECT, INSERT, DELETE ON public.publisher_blocks TO authenticated;
CREATE POLICY "publishers can read own blocks"
ON public.publisher_blocks
FOR SELECT
TO authenticated
USING (auth.uid() = publisher_id);

CREATE POLICY "publishers can insert own blocks"
ON public.publisher_blocks
FOR INSERT
TO authenticated
WITH CHECK (auth.uid() = publisher_id);

CREATE POLICY "publishers can delete own blocks"
ON public.publisher_blocks
FOR DELETE
TO authenticated
USING (auth.uid() = publisher_id);

GRANT SELECT, INSERT, UPDATE ON public.profiles TO authenticated;
CREATE POLICY "users can read own profile"
ON public.profiles
FOR SELECT
TO authenticated
USING (auth.uid() = id);

CREATE POLICY "users can insert own profile"
ON public.profiles
FOR INSERT
TO authenticated
WITH CHECK (auth.uid() = id);

CREATE POLICY "users can update own profile"
ON public.profiles
FOR UPDATE
TO authenticated
USING (auth.uid() = id)
WITH CHECK (auth.uid() = id);

GRANT INSERT ON public.newsletter_subscribers TO anon, authenticated;
CREATE POLICY "visitors can subscribe to newsletter"
ON public.newsletter_subscribers
FOR INSERT
TO anon, authenticated
WITH CHECK (length(trim(email)) > 0);

REVOKE ALL ON FUNCTION public.increment_comment_likes(bigint) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.decrement_comment_likes(bigint) FROM PUBLIC, anon, authenticated;

COMMIT;
