BEGIN;

ALTER TABLE public.comments
  ADD COLUMN IF NOT EXISTS ip_address text DEFAULT ''::text,
  ADD COLUMN IF NOT EXISTS city text DEFAULT ''::text;

UPDATE public.comments
SET ip_address = ''
WHERE ip_address IS NULL;

UPDATE public.comments
SET city = ''
WHERE city IS NULL;

UPDATE public.comments c
SET city = COALESCE(NULLIF(btrim(p.signup_city), ''), NULLIF(btrim(p.city), ''), '')
FROM public.profiles p
WHERE c.user_id = p.id
  AND (c.city IS NULL OR btrim(c.city) = '')
  AND (
    NULLIF(btrim(p.signup_city), '') IS NOT NULL
    OR NULLIF(btrim(p.city), '') IS NOT NULL
  );

CREATE INDEX IF NOT EXISTS comments_city_idx
  ON public.comments (city)
  WHERE city IS NOT NULL AND btrim(city) <> '';

CREATE OR REPLACE VIEW public.admin_comment_details
WITH (security_invoker = true) AS
SELECT
  c.id,
  c.post_id,
  c.user_id,
  c.guest_name,
  c.guest_email,
  c.parent_id,
  c.content,
  c.status,
  COALESCE(c.is_pinned, false) AS is_pinned,
  COALESCE(c.likes_count, 0) AS likes_count,
  c.created_at,
  c.updated_at,
  p.title AS post_title,
  COALESCE(
    NULLIF(btrim(pr.full_name), ''),
    NULLIF(btrim(pr.username), ''),
    NULLIF(btrim(c.guest_name), ''),
    NULLIF(btrim(c.guest_email), ''),
    'Misafir'
  ) AS user_name,
  pr.avatar_url AS user_avatar,
  (
    SELECT COUNT(*)::int
    FROM public.comments replies
    WHERE replies.parent_id = c.id
  ) AS replies_count,
  (
    SELECT COUNT(*)::int
    FROM public.comment_reports reports
    WHERE reports.comment_id = c.id
  ) AS reports_count,
  public.pateez_admin_normalize_search_text(c.content) AS content_search,
  public.pateez_admin_normalize_search_text(
    concat_ws(
      ' ',
      p.title,
      COALESCE(
        NULLIF(btrim(pr.full_name), ''),
        NULLIF(btrim(pr.username), ''),
        NULLIF(btrim(c.guest_name), ''),
        NULLIF(btrim(c.guest_email), ''),
        'Misafir'
      ),
      c.guest_name,
      c.guest_email,
      c.ip_address,
      c.city,
      c.id::text,
      c.status,
      public.pateez_admin_timestamp_search_text(c.created_at)
    )
  ) AS meta_search,
  c.ip_address,
  c.city
FROM public.comments c
LEFT JOIN public.posts p ON p.id = c.post_id
LEFT JOIN public.profiles pr ON pr.id = c.user_id;

GRANT SELECT ON public.admin_comment_details TO pateez_admin_api;

COMMIT;
