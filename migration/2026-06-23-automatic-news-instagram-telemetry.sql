BEGIN;

CREATE EXTENSION IF NOT EXISTS pgcrypto;

ALTER TABLE public.automatic_news_sources
  ADD COLUMN IF NOT EXISTS cooldown_until timestamp with time zone,
  ADD COLUMN IF NOT EXISTS last_error_code text,
  ADD COLUMN IF NOT EXISTS last_http_status integer;

CREATE TABLE IF NOT EXISTS public.automatic_news_source_checks (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  source_id uuid REFERENCES public.automatic_news_sources(id) ON DELETE CASCADE,
  run_id bigint REFERENCES public.automatic_news_runs(id) ON DELETE SET NULL,
  source_type text NOT NULL DEFAULT 'website',
  status text NOT NULL DEFAULT 'success',
  checked_at timestamp with time zone NOT NULL DEFAULT now(),
  candidates_found integer NOT NULL DEFAULT 0,
  inserted_count integer NOT NULL DEFAULT 0,
  skipped_duplicate_count integer NOT NULL DEFAULT 0,
  error_message text,
  error_code text,
  http_status integer,
  duration_ms integer,
  detected_latency_seconds integer,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT automatic_news_source_checks_pkey PRIMARY KEY (id),
  CONSTRAINT automatic_news_source_checks_type_check CHECK (source_type IN ('website', 'instagram', 'rss', 'other')),
  CONSTRAINT automatic_news_source_checks_status_check CHECK (status IN ('success', 'error'))
);

CREATE INDEX IF NOT EXISTS automatic_news_source_checks_source_checked_idx
  ON public.automatic_news_source_checks (source_id, checked_at DESC);

CREATE INDEX IF NOT EXISTS automatic_news_source_checks_error_idx
  ON public.automatic_news_source_checks (source_type, status, error_code, checked_at DESC);

CREATE INDEX IF NOT EXISTS automatic_news_sources_cooldown_idx
  ON public.automatic_news_sources (source_type, is_active, cooldown_until, next_poll_at)
  WHERE health_state <> 'disabled';

WITH ranked_instagram AS (
  SELECT
    id,
    row_number() OVER (ORDER BY sort_order ASC, display_name ASC, created_at ASC) AS rn
  FROM public.automatic_news_sources
  WHERE source_type = 'instagram'
),
classified AS (
  SELECT
    source.id,
    ranked_instagram.rn,
    CASE
      WHEN source.last_error ~* 'HTTP[[:space:]]+(401|403|429)' AND source.consecutive_failures >= 12
        THEN now() + interval '180 minutes'
      WHEN source.last_error ~* 'HTTP[[:space:]]+(401|403|429)' AND source.consecutive_failures >= 6
        THEN now() + interval '90 minutes'
      WHEN source.last_error ~* 'HTTP[[:space:]]+(401|403|429)' AND source.consecutive_failures >= 3
        THEN now() + interval '45 minutes'
      WHEN source.last_error ~* 'HTTP[[:space:]]+(401|403|429)'
        THEN now() + interval '30 minutes'
      ELSE NULL
    END AS computed_cooldown
  FROM public.automatic_news_sources AS source
  JOIN ranked_instagram ON ranked_instagram.id = source.id
)
UPDATE public.automatic_news_sources AS source
SET
  sla_tier = CASE WHEN classified.rn <= 8 THEN 'urgent' ELSE 'standard' END,
  priority = CASE WHEN classified.rn <= 8 THEN 20 ELSE GREATEST(source.priority, 200) END,
  poll_interval_minutes = CASE WHEN classified.rn <= 8 THEN 5 ELSE 30 END,
  last_error_code = CASE
    WHEN source.last_error ~* 'HTTP[[:space:]]+(401|403)' THEN 'instagram_auth_required'
    WHEN source.last_error ~* 'HTTP[[:space:]]+429' THEN 'instagram_rate_limited'
    WHEN COALESCE(source.last_error, '') <> '' THEN 'instagram_error'
    ELSE NULL
  END,
  last_http_status = CASE
    WHEN substring(source.last_error FROM 'HTTP[[:space:]]+([0-9]{3})') IS NOT NULL
      THEN substring(source.last_error FROM 'HTTP[[:space:]]+([0-9]{3})')::integer
    ELSE NULL
  END,
  cooldown_until = classified.computed_cooldown,
  next_poll_at = CASE
    WHEN classified.computed_cooldown IS NOT NULL THEN classified.computed_cooldown
    WHEN classified.rn <= 8 THEN LEAST(COALESCE(source.next_poll_at, now()), now())
    ELSE GREATEST(COALESCE(source.next_poll_at, now() + interval '30 minutes'), now() + interval '30 minutes')
  END,
  lease_owner = NULL,
  lease_expires_at = NULL,
  updated_at = now()
FROM classified
WHERE source.id = classified.id;

ALTER TABLE public.automatic_news_source_checks ENABLE ROW LEVEL SECURITY;

DO $$
BEGIN
  IF to_regrole('pateez_admin_api') IS NOT NULL THEN
    GRANT SELECT, INSERT, UPDATE, DELETE ON public.automatic_news_source_checks TO pateez_admin_api;

    IF NOT EXISTS (
      SELECT 1 FROM pg_policies
      WHERE schemaname = 'public'
        AND tablename = 'automatic_news_source_checks'
        AND policyname = 'pateez_admin_api_all'
    ) THEN
      CREATE POLICY pateez_admin_api_all ON public.automatic_news_source_checks
        FOR ALL TO pateez_admin_api USING (true) WITH CHECK (true);
    END IF;
  END IF;
END $$;

COMMIT;
