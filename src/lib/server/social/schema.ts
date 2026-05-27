import { ensureAppSchema } from '@/lib/server/appDb';
import { dbQuery } from '@/lib/server/neonDb';

let socialSchemaReady: Promise<void> | null = null;

export async function ensureSocialSchema() {
  if (!socialSchemaReady) {
    socialSchemaReady = (async () => {
      await ensureAppSchema();
      await dbQuery(`
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
          son_senkron_tarihi timestamptz,
          olusturma_tarihi timestamptz DEFAULT now(),
          guncelleme_tarihi timestamptz DEFAULT now(),
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
          baglanma_tarihi timestamptz,
          guncelleme_tarihi timestamptz DEFAULT now()
        );

        CREATE TABLE IF NOT EXISTS public.social_posts (
          id bigserial PRIMARY KEY,
          social_account_id bigint REFERENCES public.social_accounts(id) ON DELETE SET NULL,
          bundle_post_id text,
          team_id text NOT NULL DEFAULT '',
          baslik text NOT NULL DEFAULT '',
          durum text NOT NULL DEFAULT 'DRAFT',
          post_date timestamptz,
          platform_tipleri text[] DEFAULT ARRAY[]::text[],
          icerik_text text NOT NULL DEFAULT '',
          link_url text DEFAULT '',
          media_urls text[] DEFAULT ARRAY[]::text[],
          upload_ids text[] DEFAULT ARRAY[]::text[],
          request_json jsonb DEFAULT '{}'::jsonb,
          response_json jsonb DEFAULT '{}'::jsonb,
          son_hata_mesaji text,
          olusturma_tarihi timestamptz DEFAULT now(),
          guncelleme_tarihi timestamptz DEFAULT now(),
          kullanici text
        );

        ALTER TABLE public.social_accounts
          ADD COLUMN IF NOT EXISTS api_anahtari text,
          ADD COLUMN IF NOT EXISTS client_secret text,
          ADD COLUMN IF NOT EXISTS bundle_team_json jsonb DEFAULT '{}'::jsonb,
          ADD COLUMN IF NOT EXISTS son_senkron_tarihi timestamptz;

        CREATE INDEX IF NOT EXISTS idx_social_accounts_active_created
          ON public.social_accounts (aktif_mi, olusturma_tarihi DESC);
        CREATE INDEX IF NOT EXISTS idx_social_accounts_provider_team
          ON public.social_accounts (provider_id, team_id);
        CREATE INDEX IF NOT EXISTS idx_social_connected_accounts_platform
          ON public.social_connected_accounts (platform_tipi, durum);
        CREATE INDEX IF NOT EXISTS idx_social_connected_accounts_social_account
          ON public.social_connected_accounts (social_account_id);
        CREATE UNIQUE INDEX IF NOT EXISTS idx_social_connected_accounts_bundle_id
          ON public.social_connected_accounts (social_account_id, bundle_social_account_id)
          WHERE bundle_social_account_id IS NOT NULL AND bundle_social_account_id <> '';
        CREATE INDEX IF NOT EXISTS idx_social_posts_created
          ON public.social_posts (olusturma_tarihi DESC);
        CREATE INDEX IF NOT EXISTS idx_social_posts_status_date
          ON public.social_posts (durum, post_date DESC);

        INSERT INTO public.permissions (key, label, group_name, description)
        VALUES ('manage_social', 'Sosyal Medya Modülü', 'content', 'Bundle Social bağlantıları, hesapları ve sosyal medya gönderilerini yönetme yetkisi.')
        ON CONFLICT (key) DO UPDATE SET
          label = EXCLUDED.label,
          group_name = EXCLUDED.group_name,
          description = EXCLUDED.description;

        INSERT INTO public.role_permissions (role_id, permission_key)
        SELECT id, 'manage_social'
        FROM public.roles
        WHERE name = 'admin'
        ON CONFLICT DO NOTHING;
      `);
    })();
  }

  return socialSchemaReady;
}
