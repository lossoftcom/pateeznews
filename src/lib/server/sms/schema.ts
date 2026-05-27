import { ensureAppSchema } from '@/lib/server/appDb';
import { dbQuery } from '@/lib/server/neonDb';

let smsSchemaReady: Promise<void> | null = null;

export async function ensureSmsSchema() {
  if (!smsSchemaReady) {
    smsSchemaReady = (async () => {
      await ensureAppSchema();
      await dbQuery(`
        CREATE TABLE IF NOT EXISTS public.sms_accounts (
          id bigserial PRIMARY KEY,
          hesap_adi text NOT NULL,
          gonderen_adi text DEFAULT '',
          telefon text NOT NULL,
          gonderici_basligi text DEFAULT '',
          servis_tipi text NOT NULL DEFAULT 'custom_sms_api',
          gonderim_modu text NOT NULL DEFAULT 'api',
          api_base_url text DEFAULT '',
          api_anahtari text,
          api_sifresi text,
          api_token text,
          phone_number_id text DEFAULT '',
          webhook_url text DEFAULT '',
          gunluk_limit integer DEFAULT 5000,
          aylik_limit integer DEFAULT 150000,
          saatlik_limit integer DEFAULT 700,
          bugun_gonderilen integer DEFAULT 0,
          bu_ay_gonderilen integer DEFAULT 0,
          token_dogrulandi boolean DEFAULT false,
          webhook_dogrulandi boolean DEFAULT false,
          sablon_senkron boolean DEFAULT false,
          aktif_mi boolean DEFAULT true,
          baglanti_durumu text DEFAULT 'not_tested',
          son_hata_mesaji text,
          olusturma_tarihi timestamptz DEFAULT now(),
          guncelleme_tarihi timestamptz DEFAULT now(),
          kullanici text
        );

        CREATE TABLE IF NOT EXISTS public.sms_templates (
          id bigserial PRIMARY KEY,
          sablon_adi text NOT NULL,
          kategori text NOT NULL DEFAULT 'campaign',
          baslik text DEFAULT '',
          onizleme_metni text DEFAULT '',
          icerik_text text NOT NULL DEFAULT '',
          degiskenler_json text DEFAULT '[]',
          media_tipi text DEFAULT 'none',
          hazir_mi boolean DEFAULT false,
          aktif_mi boolean DEFAULT true,
          olusturma_tarihi timestamptz DEFAULT now(),
          guncelleme_tarihi timestamptz DEFAULT now(),
          kullanici text
        );

        CREATE TABLE IF NOT EXISTS public.sms_contact_lists (
          id bigserial PRIMARY KEY,
          liste_adi text NOT NULL,
          aciklama text DEFAULT '',
          kaynak text DEFAULT 'csv',
          otomatik_sync boolean DEFAULT false,
          sync_filtresi_json text DEFAULT '{}',
          aktif_mi boolean DEFAULT true,
          olusturma_tarihi timestamptz DEFAULT now(),
          guncelleme_tarihi timestamptz DEFAULT now(),
          kullanici text
        );

        CREATE TABLE IF NOT EXISTS public.sms_contacts (
          id bigserial PRIMARY KEY,
          telefon text NOT NULL,
          ad text DEFAULT '',
          soyad text DEFAULT '',
          eposta text DEFAULT '',
          lospos_cari_id bigint,
          aktif_mi boolean DEFAULT true,
          unsubscribe_tarihi timestamptz,
          dogrulama_durumu text DEFAULT 'unknown',
          toplam_gonderilen integer DEFAULT 0,
          toplam_teslim integer DEFAULT 0,
          toplam_okunan integer DEFAULT 0,
          son_gonderim timestamptz,
          olusturma_tarihi timestamptz DEFAULT now()
        );

        CREATE TABLE IF NOT EXISTS public.sms_contact_list_memberships (
          list_id bigint NOT NULL REFERENCES public.sms_contact_lists(id) ON DELETE CASCADE,
          contact_id bigint NOT NULL REFERENCES public.sms_contacts(id) ON DELETE CASCADE,
          PRIMARY KEY (list_id, contact_id)
        );

        CREATE TABLE IF NOT EXISTS public.sms_campaigns (
          id bigserial PRIMARY KEY,
          hesap_id bigint REFERENCES public.sms_accounts(id) ON DELETE SET NULL,
          kampanya_adi text NOT NULL,
          konu text NOT NULL DEFAULT '',
          onizleme_metni text DEFAULT '',
          icerik_text text DEFAULT '',
          sablon_id bigint REFERENCES public.sms_templates(id) ON DELETE SET NULL,
          kisi_listesi_id bigint REFERENCES public.sms_contact_lists(id) ON DELETE SET NULL,
          alici_sayisi integer DEFAULT 0,
          gonderilen_sayisi integer DEFAULT 0,
          zamanlanmis_baslangic timestamptz,
          baslangic_tarihi timestamptz,
          bitis_tarihi timestamptz,
          durum text DEFAULT 'draft',
          teslim_edilen integer DEFAULT 0,
          okunan integer DEFAULT 0,
          tiklanan integer DEFAULT 0,
          bouncelar integer DEFAULT 0,
          olusturma_tarihi timestamptz DEFAULT now(),
          guncelleme_tarihi timestamptz DEFAULT now(),
          kullanici text
        );

        CREATE TABLE IF NOT EXISTS public.sms_chats (
          id bigserial PRIMARY KEY,
          ad text NOT NULL,
          telefon text NOT NULL,
          avatar_url text DEFAULT '',
          online_mi boolean DEFAULT false,
          okunmamis_sayisi integer DEFAULT 0,
          son_mesaj text DEFAULT '',
          son_mesaj_tarihi timestamptz DEFAULT now(),
          aktif_mi boolean DEFAULT true,
          olusturma_tarihi timestamptz DEFAULT now(),
          guncelleme_tarihi timestamptz DEFAULT now()
        );

        CREATE TABLE IF NOT EXISTS public.sms_messages (
          id bigserial PRIMARY KEY,
          chat_id bigint NOT NULL REFERENCES public.sms_chats(id) ON DELETE CASCADE,
          hesap_id bigint REFERENCES public.sms_accounts(id) ON DELETE SET NULL,
          servis_message_id text,
          yon text NOT NULL DEFAULT 'outgoing',
          mesaj text NOT NULL DEFAULT '',
          durum text DEFAULT 'queued',
          ek_adi text,
          ek_tipi text,
          hata_mesaji text,
          gonderim_tarihi timestamptz,
          teslim_tarihi timestamptz,
          okunma_tarihi timestamptz,
          olusturma_tarihi timestamptz DEFAULT now(),
          kullanici text
        );

        ALTER TABLE public.sms_accounts
          ADD COLUMN IF NOT EXISTS gonderici_basligi text DEFAULT '',
          ADD COLUMN IF NOT EXISTS phone_number_id text DEFAULT '',
          ADD COLUMN IF NOT EXISTS webhook_url text DEFAULT '',
          ADD COLUMN IF NOT EXISTS token_dogrulandi boolean DEFAULT false,
          ADD COLUMN IF NOT EXISTS webhook_dogrulandi boolean DEFAULT false,
          ADD COLUMN IF NOT EXISTS sablon_senkron boolean DEFAULT false;

        CREATE INDEX IF NOT EXISTS idx_sms_accounts_active_created
          ON public.sms_accounts (aktif_mi, olusturma_tarihi DESC);
        CREATE INDEX IF NOT EXISTS idx_sms_templates_active_category
          ON public.sms_templates (aktif_mi, kategori, sablon_adi);
        CREATE INDEX IF NOT EXISTS idx_sms_contact_lists_active_created
          ON public.sms_contact_lists (aktif_mi, olusturma_tarihi DESC);
        CREATE UNIQUE INDEX IF NOT EXISTS idx_sms_contacts_phone_normalized
          ON public.sms_contacts (regexp_replace(telefon, '[^0-9+]', '', 'g'));
        CREATE INDEX IF NOT EXISTS idx_sms_memberships_contact
          ON public.sms_contact_list_memberships (contact_id);
        CREATE INDEX IF NOT EXISTS idx_sms_memberships_list
          ON public.sms_contact_list_memberships (list_id);
        CREATE INDEX IF NOT EXISTS idx_sms_campaigns_status_created
          ON public.sms_campaigns (durum, olusturma_tarihi DESC);
        CREATE INDEX IF NOT EXISTS idx_sms_chats_last_message
          ON public.sms_chats (son_mesaj_tarihi DESC);
        CREATE INDEX IF NOT EXISTS idx_sms_messages_chat_created
          ON public.sms_messages (chat_id, olusturma_tarihi ASC);

        INSERT INTO public.permissions (key, label, group_name, description)
        VALUES ('manage_sms', 'SMS Modülü', 'content', 'SMS hesapları, mesajları, listeleri ve kampanyalarını yönetme yetkisi.')
        ON CONFLICT (key) DO UPDATE SET
          label = EXCLUDED.label,
          group_name = EXCLUDED.group_name,
          description = EXCLUDED.description;

        INSERT INTO public.role_permissions (role_id, permission_key)
        SELECT id, 'manage_sms'
        FROM public.roles
        WHERE name = 'admin'
        ON CONFLICT DO NOTHING;
      `);
    })();
  }

  return smsSchemaReady;
}
