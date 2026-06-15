BEGIN;

CREATE TABLE IF NOT EXISTS public.social_accounts (
  id bigserial PRIMARY KEY,
  hesap_adi text NOT NULL,
  workspace_name text DEFAULT '',
  platformlar text DEFAULT '',
  provider_id text NOT NULL DEFAULT 'bundle_social',
  provider_name text NOT NULL DEFAULT 'Bundle.social',
  baglanti_modu text NOT NULL DEFAULT 'bundle',
  api_base_url text NOT NULL DEFAULT 'https://api.bundle.social/api/v1',
  team_id text NOT NULL DEFAULT '',
  api_anahtari text,
  client_secret text,
  redirect_url text DEFAULT '',
  webhook_url text DEFAULT '',
  scopes text DEFAULT '',
  gunluk_limit integer DEFAULT 10000,
  aylik_limit integer DEFAULT 100000,
  saatlik_limit integer DEFAULT 700,
  bugun_gonderilen integer DEFAULT 0,
  bu_ay_gonderilen integer DEFAULT 0,
  api_dogrulandi boolean DEFAULT false,
  oauth_dogrulandi boolean DEFAULT false,
  webhook_dogrulandi boolean DEFAULT false,
  onay_gerekli boolean DEFAULT false,
  aktif_mi boolean DEFAULT true,
  baglanti_durumu text DEFAULT 'not_tested',
  son_hata_mesaji text,
  bundle_team_json jsonb DEFAULT '{}'::jsonb,
  son_senkron_tarihi timestamp with time zone,
  olusturma_tarihi timestamp with time zone DEFAULT now(),
  guncelleme_tarihi timestamp with time zone DEFAULT now(),
  kullanici text
);

CREATE TABLE IF NOT EXISTS public.social_connected_accounts (
  id bigserial PRIMARY KEY,
  social_account_id bigint REFERENCES public.social_accounts(id) ON DELETE CASCADE,
  bundle_social_account_id text,
  platform_tipi text NOT NULL,
  display_name text DEFAULT '',
  username text DEFAULT '',
  avatar_url text DEFAULT '',
  channel_id text DEFAULT '',
  channel_name text DEFAULT '',
  durum text DEFAULT 'connected',
  raw_json jsonb DEFAULT '{}'::jsonb,
  baglanma_tarihi timestamp with time zone,
  guncelleme_tarihi timestamp with time zone DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.social_posts (
  id bigserial PRIMARY KEY,
  social_account_id bigint REFERENCES public.social_accounts(id) ON DELETE SET NULL,
  bundle_post_id text,
  team_id text NOT NULL DEFAULT '',
  baslik text NOT NULL DEFAULT '',
  durum text NOT NULL DEFAULT 'DRAFT',
  post_date timestamp with time zone,
  platform_tipleri text[] DEFAULT ARRAY[]::text[],
  icerik_text text NOT NULL DEFAULT '',
  link_url text DEFAULT '',
  media_urls text[] DEFAULT ARRAY[]::text[],
  upload_ids text[] DEFAULT ARRAY[]::text[],
  request_json jsonb DEFAULT '{}'::jsonb,
  response_json jsonb DEFAULT '{}'::jsonb,
  son_hata_mesaji text,
  olusturma_tarihi timestamp with time zone DEFAULT now(),
  guncelleme_tarihi timestamp with time zone DEFAULT now(),
  kullanici text
);

ALTER TABLE public.social_accounts
  ADD COLUMN IF NOT EXISTS workspace_name text DEFAULT '',
  ADD COLUMN IF NOT EXISTS platformlar text DEFAULT '',
  ADD COLUMN IF NOT EXISTS provider_id text NOT NULL DEFAULT 'bundle_social',
  ADD COLUMN IF NOT EXISTS provider_name text NOT NULL DEFAULT 'Bundle.social',
  ADD COLUMN IF NOT EXISTS baglanti_modu text NOT NULL DEFAULT 'bundle',
  ADD COLUMN IF NOT EXISTS api_base_url text NOT NULL DEFAULT 'https://api.bundle.social/api/v1',
  ADD COLUMN IF NOT EXISTS team_id text NOT NULL DEFAULT '',
  ADD COLUMN IF NOT EXISTS api_anahtari text,
  ADD COLUMN IF NOT EXISTS client_secret text,
  ADD COLUMN IF NOT EXISTS redirect_url text DEFAULT '',
  ADD COLUMN IF NOT EXISTS webhook_url text DEFAULT '',
  ADD COLUMN IF NOT EXISTS scopes text DEFAULT '',
  ADD COLUMN IF NOT EXISTS gunluk_limit integer DEFAULT 10000,
  ADD COLUMN IF NOT EXISTS aylik_limit integer DEFAULT 100000,
  ADD COLUMN IF NOT EXISTS saatlik_limit integer DEFAULT 700,
  ADD COLUMN IF NOT EXISTS bugun_gonderilen integer DEFAULT 0,
  ADD COLUMN IF NOT EXISTS bu_ay_gonderilen integer DEFAULT 0,
  ADD COLUMN IF NOT EXISTS api_dogrulandi boolean DEFAULT false,
  ADD COLUMN IF NOT EXISTS oauth_dogrulandi boolean DEFAULT false,
  ADD COLUMN IF NOT EXISTS webhook_dogrulandi boolean DEFAULT false,
  ADD COLUMN IF NOT EXISTS onay_gerekli boolean DEFAULT false,
  ADD COLUMN IF NOT EXISTS aktif_mi boolean DEFAULT true,
  ADD COLUMN IF NOT EXISTS baglanti_durumu text DEFAULT 'not_tested',
  ADD COLUMN IF NOT EXISTS son_hata_mesaji text,
  ADD COLUMN IF NOT EXISTS bundle_team_json jsonb DEFAULT '{}'::jsonb,
  ADD COLUMN IF NOT EXISTS son_senkron_tarihi timestamp with time zone,
  ADD COLUMN IF NOT EXISTS olusturma_tarihi timestamp with time zone DEFAULT now(),
  ADD COLUMN IF NOT EXISTS guncelleme_tarihi timestamp with time zone DEFAULT now(),
  ADD COLUMN IF NOT EXISTS kullanici text;

ALTER TABLE public.social_connected_accounts
  ADD COLUMN IF NOT EXISTS social_account_id bigint,
  ADD COLUMN IF NOT EXISTS bundle_social_account_id text,
  ADD COLUMN IF NOT EXISTS platform_tipi text,
  ADD COLUMN IF NOT EXISTS display_name text DEFAULT '',
  ADD COLUMN IF NOT EXISTS username text DEFAULT '',
  ADD COLUMN IF NOT EXISTS avatar_url text DEFAULT '',
  ADD COLUMN IF NOT EXISTS channel_id text DEFAULT '',
  ADD COLUMN IF NOT EXISTS channel_name text DEFAULT '',
  ADD COLUMN IF NOT EXISTS durum text DEFAULT 'connected',
  ADD COLUMN IF NOT EXISTS raw_json jsonb DEFAULT '{}'::jsonb,
  ADD COLUMN IF NOT EXISTS baglanma_tarihi timestamp with time zone,
  ADD COLUMN IF NOT EXISTS guncelleme_tarihi timestamp with time zone DEFAULT now();

ALTER TABLE public.social_posts
  ADD COLUMN IF NOT EXISTS social_account_id bigint,
  ADD COLUMN IF NOT EXISTS bundle_post_id text,
  ADD COLUMN IF NOT EXISTS team_id text NOT NULL DEFAULT '',
  ADD COLUMN IF NOT EXISTS baslik text NOT NULL DEFAULT '',
  ADD COLUMN IF NOT EXISTS durum text NOT NULL DEFAULT 'DRAFT',
  ADD COLUMN IF NOT EXISTS post_date timestamp with time zone,
  ADD COLUMN IF NOT EXISTS platform_tipleri text[] DEFAULT ARRAY[]::text[],
  ADD COLUMN IF NOT EXISTS icerik_text text NOT NULL DEFAULT '',
  ADD COLUMN IF NOT EXISTS link_url text DEFAULT '',
  ADD COLUMN IF NOT EXISTS media_urls text[] DEFAULT ARRAY[]::text[],
  ADD COLUMN IF NOT EXISTS upload_ids text[] DEFAULT ARRAY[]::text[],
  ADD COLUMN IF NOT EXISTS request_json jsonb DEFAULT '{}'::jsonb,
  ADD COLUMN IF NOT EXISTS response_json jsonb DEFAULT '{}'::jsonb,
  ADD COLUMN IF NOT EXISTS son_hata_mesaji text,
  ADD COLUMN IF NOT EXISTS olusturma_tarihi timestamp with time zone DEFAULT now(),
  ADD COLUMN IF NOT EXISTS guncelleme_tarihi timestamp with time zone DEFAULT now(),
  ADD COLUMN IF NOT EXISTS kullanici text;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conname = 'social_connected_accounts_social_account_id_fkey'
      AND conrelid = 'public.social_connected_accounts'::regclass
  ) THEN
    ALTER TABLE public.social_connected_accounts
      ADD CONSTRAINT social_connected_accounts_social_account_id_fkey
      FOREIGN KEY (social_account_id)
      REFERENCES public.social_accounts(id)
      ON DELETE CASCADE;
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conname = 'social_posts_social_account_id_fkey'
      AND conrelid = 'public.social_posts'::regclass
  ) THEN
    ALTER TABLE public.social_posts
      ADD CONSTRAINT social_posts_social_account_id_fkey
      FOREIGN KEY (social_account_id)
      REFERENCES public.social_accounts(id)
      ON DELETE SET NULL;
  END IF;
END $$;

CREATE INDEX IF NOT EXISTS idx_social_accounts_active_created
  ON public.social_accounts (aktif_mi, olusturma_tarihi DESC);

CREATE INDEX IF NOT EXISTS idx_social_accounts_provider_team
  ON public.social_accounts (provider_id, team_id);

CREATE INDEX IF NOT EXISTS idx_social_connected_accounts_social_account
  ON public.social_connected_accounts (social_account_id);

CREATE INDEX IF NOT EXISTS idx_social_connected_accounts_platform
  ON public.social_connected_accounts (platform_tipi, durum);

CREATE UNIQUE INDEX IF NOT EXISTS idx_social_connected_accounts_bundle_id
  ON public.social_connected_accounts (social_account_id, bundle_social_account_id)
  WHERE bundle_social_account_id IS NOT NULL AND bundle_social_account_id <> '';

CREATE INDEX IF NOT EXISTS idx_social_posts_status_date
  ON public.social_posts (durum, post_date DESC);

CREATE INDEX IF NOT EXISTS idx_social_posts_created
  ON public.social_posts (olusturma_tarihi DESC);

ALTER TABLE public.social_accounts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.social_connected_accounts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.social_posts ENABLE ROW LEVEL SECURITY;

DO $$
BEGIN
  IF to_regrole('pateez_admin_api') IS NOT NULL THEN
    GRANT SELECT, INSERT, UPDATE, DELETE ON public.social_accounts TO pateez_admin_api;
    GRANT SELECT, INSERT, UPDATE, DELETE ON public.social_connected_accounts TO pateez_admin_api;
    GRANT SELECT, INSERT, UPDATE, DELETE ON public.social_posts TO pateez_admin_api;

    GRANT USAGE, SELECT ON SEQUENCE public.social_accounts_id_seq TO pateez_admin_api;
    GRANT USAGE, SELECT ON SEQUENCE public.social_connected_accounts_id_seq TO pateez_admin_api;
    GRANT USAGE, SELECT ON SEQUENCE public.social_posts_id_seq TO pateez_admin_api;

    IF NOT EXISTS (
      SELECT 1 FROM pg_policies
      WHERE schemaname = 'public'
        AND tablename = 'social_accounts'
        AND policyname = 'pateez_admin_api_all'
    ) THEN
      CREATE POLICY pateez_admin_api_all ON public.social_accounts
        FOR ALL TO pateez_admin_api USING (true) WITH CHECK (true);
    END IF;

    IF NOT EXISTS (
      SELECT 1 FROM pg_policies
      WHERE schemaname = 'public'
        AND tablename = 'social_connected_accounts'
        AND policyname = 'pateez_admin_api_all'
    ) THEN
      CREATE POLICY pateez_admin_api_all ON public.social_connected_accounts
        FOR ALL TO pateez_admin_api USING (true) WITH CHECK (true);
    END IF;

    IF NOT EXISTS (
      SELECT 1 FROM pg_policies
      WHERE schemaname = 'public'
        AND tablename = 'social_posts'
        AND policyname = 'pateez_admin_api_all'
    ) THEN
      CREATE POLICY pateez_admin_api_all ON public.social_posts
        FOR ALL TO pateez_admin_api USING (true) WITH CHECK (true);
    END IF;
  END IF;
END $$;

COMMIT;
