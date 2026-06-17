BEGIN;

CREATE TABLE IF NOT EXISTS public.notification_settings (
  id bigserial PRIMARY KEY,
  provider_id text NOT NULL DEFAULT 'firebase_fcm',
  provider_name text NOT NULL DEFAULT 'Firebase Cloud Messaging',
  project_id text NOT NULL DEFAULT '',
  client_email text NOT NULL DEFAULT '',
  private_key_encrypted text,
  private_key_iv text,
  private_key_tag text,
  web_vapid_key text NOT NULL DEFAULT '',
  api_base_url text NOT NULL DEFAULT 'https://fcm.googleapis.com/v1',
  default_language_code text NOT NULL DEFAULT 'tr',
  daily_limit integer NOT NULL DEFAULT 100000,
  monthly_limit integer NOT NULL DEFAULT 3000000,
  hourly_limit integer NOT NULL DEFAULT 10000,
  batch_size integer NOT NULL DEFAULT 100,
  android_enabled boolean NOT NULL DEFAULT true,
  ios_enabled boolean NOT NULL DEFAULT true,
  flutter_web_enabled boolean NOT NULL DEFAULT true,
  astro_web_enabled boolean NOT NULL DEFAULT true,
  token_verified boolean NOT NULL DEFAULT false,
  is_active boolean NOT NULL DEFAULT true,
  connection_status text NOT NULL DEFAULT 'pending',
  last_error_message text,
  last_checked_at timestamptz,
  created_by uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  updated_by uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.notification_device_tokens (
  id bigserial PRIMARY KEY,
  user_id uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  fcm_token text NOT NULL UNIQUE,
  platform text NOT NULL,
  app_surface text NOT NULL DEFAULT 'flutter_mobile',
  language_code text NOT NULL DEFAULT 'tr',
  country_code text NOT NULL DEFAULT '',
  timezone text NOT NULL DEFAULT '',
  app_version text NOT NULL DEFAULT '',
  device_id text NOT NULL DEFAULT '',
  device_model text NOT NULL DEFAULT '',
  permission_status text NOT NULL DEFAULT 'unknown',
  topics text[] NOT NULL DEFAULT ARRAY[]::text[],
  is_active boolean NOT NULL DEFAULT true,
  last_seen_at timestamptz NOT NULL DEFAULT now(),
  token_refreshed_at timestamptz NOT NULL DEFAULT now(),
  invalidated_at timestamptz,
  invalid_reason text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.notification_templates (
  id bigserial PRIMARY KEY,
  template_name text NOT NULL,
  category text NOT NULL DEFAULT 'general',
  title text NOT NULL,
  body text NOT NULL,
  image_url text NOT NULL DEFAULT '',
  deep_link text NOT NULL DEFAULT '',
  data_json jsonb NOT NULL DEFAULT '{}'::jsonb,
  language_code text NOT NULL DEFAULT 'tr',
  priority text NOT NULL DEFAULT 'normal',
  ttl_seconds integer NOT NULL DEFAULT 3600,
  channel_id text NOT NULL DEFAULT 'pateez_general',
  is_ready boolean NOT NULL DEFAULT true,
  is_active boolean NOT NULL DEFAULT true,
  created_by uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  updated_by uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.notification_campaigns (
  id bigserial PRIMARY KEY,
  campaign_name text NOT NULL,
  template_id bigint REFERENCES public.notification_templates(id) ON DELETE SET NULL,
  target_type text NOT NULL DEFAULT 'all',
  target_platforms text[] NOT NULL DEFAULT ARRAY[]::text[],
  target_topics text[] NOT NULL DEFAULT ARRAY[]::text[],
  target_user_ids uuid[] NOT NULL DEFAULT ARRAY[]::uuid[],
  target_token_ids bigint[] NOT NULL DEFAULT ARRAY[]::bigint[],
  title text NOT NULL,
  body text NOT NULL,
  image_url text NOT NULL DEFAULT '',
  deep_link text NOT NULL DEFAULT '',
  data_json jsonb NOT NULL DEFAULT '{}'::jsonb,
  priority text NOT NULL DEFAULT 'normal',
  ttl_seconds integer NOT NULL DEFAULT 3600,
  channel_id text NOT NULL DEFAULT 'pateez_general',
  status text NOT NULL DEFAULT 'draft',
  recipient_count integer NOT NULL DEFAULT 0,
  queued_count integer NOT NULL DEFAULT 0,
  sent_count integer NOT NULL DEFAULT 0,
  failed_count integer NOT NULL DEFAULT 0,
  opened_count integer NOT NULL DEFAULT 0,
  clicked_count integer NOT NULL DEFAULT 0,
  scheduled_start_at timestamptz,
  started_at timestamptz,
  finished_at timestamptz,
  idempotency_key text UNIQUE,
  created_by uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  updated_by uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.notification_outbox (
  id bigserial PRIMARY KEY,
  campaign_id bigint NOT NULL REFERENCES public.notification_campaigns(id) ON DELETE CASCADE,
  device_token_id bigint REFERENCES public.notification_device_tokens(id) ON DELETE SET NULL,
  user_id uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  fcm_token text NOT NULL,
  title text NOT NULL,
  body text NOT NULL,
  image_url text NOT NULL DEFAULT '',
  deep_link text NOT NULL DEFAULT '',
  data_json jsonb NOT NULL DEFAULT '{}'::jsonb,
  priority text NOT NULL DEFAULT 'normal',
  ttl_seconds integer NOT NULL DEFAULT 3600,
  channel_id text NOT NULL DEFAULT 'pateez_general',
  status text NOT NULL DEFAULT 'queued',
  attempts integer NOT NULL DEFAULT 0,
  max_attempts integer NOT NULL DEFAULT 5,
  next_attempt_at timestamptz NOT NULL DEFAULT now(),
  sent_at timestamptz,
  fcm_message_id text,
  error_code text,
  error_message text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (campaign_id, device_token_id)
);

CREATE TABLE IF NOT EXISTS public.notification_inbox (
  id bigserial PRIMARY KEY,
  campaign_id bigint REFERENCES public.notification_campaigns(id) ON DELETE SET NULL,
  outbox_id bigint REFERENCES public.notification_outbox(id) ON DELETE SET NULL,
  user_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  title text NOT NULL,
  body text NOT NULL,
  image_url text NOT NULL DEFAULT '',
  deep_link text NOT NULL DEFAULT '',
  data_json jsonb NOT NULL DEFAULT '{}'::jsonb,
  read_at timestamptz,
  opened_at timestamptz,
  clicked_at timestamptz,
  expires_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (user_id, outbox_id)
);

CREATE TABLE IF NOT EXISTS public.notification_events (
  id bigserial PRIMARY KEY,
  campaign_id bigint REFERENCES public.notification_campaigns(id) ON DELETE SET NULL,
  outbox_id bigint REFERENCES public.notification_outbox(id) ON DELETE SET NULL,
  device_token_id bigint REFERENCES public.notification_device_tokens(id) ON DELETE SET NULL,
  user_id uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  event_type text NOT NULL,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS notification_settings_active_idx
  ON public.notification_settings (is_active, provider_id);

CREATE INDEX IF NOT EXISTS notification_device_tokens_active_idx
  ON public.notification_device_tokens (is_active, platform, app_surface);

CREATE INDEX IF NOT EXISTS notification_device_tokens_user_idx
  ON public.notification_device_tokens (user_id, is_active);

CREATE INDEX IF NOT EXISTS notification_device_tokens_seen_idx
  ON public.notification_device_tokens (last_seen_at DESC);

CREATE INDEX IF NOT EXISTS notification_templates_active_idx
  ON public.notification_templates (is_active, language_code, category);

CREATE INDEX IF NOT EXISTS notification_campaigns_status_idx
  ON public.notification_campaigns (status, scheduled_start_at, created_at DESC);

CREATE INDEX IF NOT EXISTS notification_outbox_status_idx
  ON public.notification_outbox (status, next_attempt_at, created_at);

CREATE INDEX IF NOT EXISTS notification_outbox_campaign_idx
  ON public.notification_outbox (campaign_id, status);

CREATE INDEX IF NOT EXISTS notification_inbox_user_idx
  ON public.notification_inbox (user_id, created_at DESC);

CREATE INDEX IF NOT EXISTS notification_events_campaign_idx
  ON public.notification_events (campaign_id, event_type, created_at DESC);

ALTER TABLE public.notification_settings ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.notification_device_tokens ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.notification_templates ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.notification_campaigns ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.notification_outbox ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.notification_inbox ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.notification_events ENABLE ROW LEVEL SECURITY;

INSERT INTO public.permissions (key, label, group_name, description)
VALUES
  ('notifications_access', 'Bildirimler', 'Bildirimler', 'Bildirim modülünü görüntüleme yetkisi.'),
  ('manage_notifications', 'Bildirimleri Yönet', 'Bildirimler', 'Bildirim kampanyaları, cihaz tokenları ve FCM ayarlarını yönetme yetkisi.')
ON CONFLICT (key) DO UPDATE
SET label = EXCLUDED.label,
    group_name = EXCLUDED.group_name,
    description = EXCLUDED.description;

INSERT INTO public.role_permissions (role_id, permission_key)
SELECT roles.id, permissions.key
FROM public.roles
CROSS JOIN (
  VALUES ('notifications_access'), ('manage_notifications')
) AS permissions(key)
WHERE roles.name IN ('admin', 'super_admin')
ON CONFLICT DO NOTHING;

DO $$
DECLARE
  table_name text;
  policy_name text;
BEGIN
  IF to_regrole('pateez_admin_api') IS NOT NULL THEN
    FOREACH table_name IN ARRAY ARRAY[
      'notification_settings',
      'notification_device_tokens',
      'notification_templates',
      'notification_campaigns',
      'notification_outbox',
      'notification_inbox',
      'notification_events'
    ]
    LOOP
      EXECUTE format('GRANT SELECT, INSERT, UPDATE, DELETE ON public.%I TO pateez_admin_api', table_name);
      policy_name := table_name || '_pateez_admin_api_all';
      IF NOT EXISTS (
        SELECT 1
        FROM pg_policies
        WHERE schemaname = 'public'
          AND tablename = table_name
          AND policyname = policy_name
      ) THEN
        EXECUTE format(
          'CREATE POLICY %I ON public.%I FOR ALL TO pateez_admin_api USING (true) WITH CHECK (true)',
          policy_name,
          table_name
        );
      END IF;
    END LOOP;

    GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO pateez_admin_api;
  END IF;
END $$;

INSERT INTO public.notification_settings (provider_id, provider_name)
SELECT 'firebase_fcm', 'Firebase Cloud Messaging'
WHERE NOT EXISTS (
  SELECT 1
  FROM public.notification_settings
  WHERE provider_id = 'firebase_fcm'
);

COMMIT;
