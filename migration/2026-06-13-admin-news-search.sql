CREATE EXTENSION IF NOT EXISTS unaccent;
CREATE EXTENSION IF NOT EXISTS pg_trgm;

ALTER TABLE public.posts
  ADD COLUMN IF NOT EXISTS admin_search_text text NOT NULL DEFAULT '';

CREATE OR REPLACE FUNCTION public.pateez_admin_normalize_search_text(value text)
RETURNS text
LANGUAGE sql
IMMUTABLE
PARALLEL SAFE
AS $$
  SELECT lower(public.unaccent('public.unaccent'::regdictionary, COALESCE(value, '')))
$$;

CREATE OR REPLACE FUNCTION public.pateez_admin_timestamp_search_text(value timestamptz)
RETURNS text
LANGUAGE sql
IMMUTABLE
PARALLEL SAFE
AS $$
  WITH local_value AS (
    SELECT value AT TIME ZONE 'Europe/Istanbul' AS ts
    WHERE value IS NOT NULL
  ),
  parts AS (
    SELECT
      extract(year FROM ts)::int AS year_value,
      extract(month FROM ts)::int AS month_value,
      extract(day FROM ts)::int AS day_value,
      extract(isodow FROM ts)::int AS dow_value,
      extract(hour FROM ts)::int AS hour_value,
      extract(minute FROM ts)::int AS minute_value
    FROM local_value
  ),
  labels AS (
    SELECT
      *,
      CASE month_value
        WHEN 1 THEN 'ocak'
        WHEN 2 THEN 'subat'
        WHEN 3 THEN 'mart'
        WHEN 4 THEN 'nisan'
        WHEN 5 THEN 'mayis'
        WHEN 6 THEN 'haziran'
        WHEN 7 THEN 'temmuz'
        WHEN 8 THEN 'agustos'
        WHEN 9 THEN 'eylul'
        WHEN 10 THEN 'ekim'
        WHEN 11 THEN 'kasim'
        WHEN 12 THEN 'aralik'
        ELSE ''
      END AS month_label,
      CASE dow_value
        WHEN 1 THEN 'pazartesi'
        WHEN 2 THEN 'sali'
        WHEN 3 THEN 'carsamba'
        WHEN 4 THEN 'persembe'
        WHEN 5 THEN 'cuma'
        WHEN 6 THEN 'cumartesi'
        WHEN 7 THEN 'pazar'
        ELSE ''
      END AS day_label
    FROM parts
  )
  SELECT COALESCE(
    concat_ws(
      ' ',
      year_value::text,
      lpad(month_value::text, 2, '0'),
      lpad(day_value::text, 2, '0'),
      lpad(hour_value::text, 2, '0') || ':' || lpad(minute_value::text, 2, '0'),
      lpad(day_value::text, 2, '0') || '.' || lpad(month_value::text, 2, '0') || '.' || year_value::text,
      month_label,
      day_value::text || ' ' || month_label,
      day_value::text || ' ' || month_label || ' ' || year_value::text,
      lpad(day_value::text, 2, '0') || ' ' || month_label,
      lpad(day_value::text, 2, '0') || ' ' || month_label || ' ' || year_value::text,
      month_label || ' ' || year_value::text,
      day_label
    ),
    ''
  )
  FROM labels
$$;

CREATE OR REPLACE FUNCTION public.posts_admin_search_trigger()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  NEW.admin_search_text := public.pateez_admin_normalize_search_text(
    CONCAT_WS(
      ' ',
      NEW.id::text,
      NEW.title,
      NEW.summary,
      regexp_replace(COALESCE(NEW.content, ''), '<[^>]+>', ' ', 'g'),
      NEW.category,
      NEW.type,
      NEW.status,
      NEW.slug,
      NEW.seo_title,
      NEW.seo_description,
      NEW.keywords,
      NEW.language_code,
      NEW.thumbnail_url,
      NEW.media_url,
      COALESCE(NEW.views_count, 0)::text,
      COALESCE(NEW.comments_count, 0)::text,
      public.pateez_admin_timestamp_search_text(NEW.created_at),
      public.pateez_admin_timestamp_search_text(NEW.published_at),
      public.pateez_admin_timestamp_search_text(NEW.updated_at),
      public.pateez_jsonb_search_text(NEW.items),
      public.pateez_jsonb_search_text(NEW.card_data),
      public.pateez_jsonb_search_text(NEW.faq_data)
    )
  );
  RETURN NEW;
END
$$;

DROP TRIGGER IF EXISTS trg_posts_admin_search ON public.posts;
CREATE TRIGGER trg_posts_admin_search
BEFORE INSERT OR UPDATE OF
  title,
  summary,
  content,
  category,
  type,
  status,
  slug,
  seo_title,
  seo_description,
  keywords,
  language_code,
  thumbnail_url,
  media_url,
  views_count,
  comments_count,
  created_at,
  published_at,
  updated_at,
  items,
  card_data,
  faq_data
ON public.posts
FOR EACH ROW
EXECUTE FUNCTION public.posts_admin_search_trigger();

UPDATE public.posts
SET updated_at = updated_at
WHERE true;

CREATE INDEX IF NOT EXISTS idx_posts_admin_search_text_trgm
  ON public.posts USING gin (admin_search_text gin_trgm_ops);

CREATE INDEX IF NOT EXISTS posts_admin_active_filter_sort_idx
  ON public.posts (
    language_code,
    category,
    type,
    status,
    publisher_id,
    created_at DESC,
    id DESC
  )
  WHERE deleted_at IS NULL AND COALESCE(status, '') <> 'trash';

CREATE INDEX IF NOT EXISTS posts_admin_trash_filter_sort_idx
  ON public.posts (
    language_code,
    category,
    type,
    status,
    publisher_id,
    deleted_at DESC,
    id DESC
  )
  WHERE deleted_at IS NOT NULL;
