-- Pateeznews admin Posta module schema.
-- Uses the Lospos-compatible Turkish mail_* schema already present in the target Supabase DB.

CREATE TABLE IF NOT EXISTS public.mail_accounts (
  id bigserial PRIMARY KEY,
  hesap_adi text NOT NULL,
  gonderen_adi text DEFAULT '',
  gonderen_eposta text NOT NULL,
  servis_tipi text NOT NULL DEFAULT 'smtp_generic',
  gonderim_modu text NOT NULL DEFAULT 'smtp',
  api_anahtari text,
  api_sifresi text,
  api_token text,
  smtp_sunucu text,
  smtp_port integer,
  smtp_kullanici text,
  smtp_sifre text,
  smtp_guvenlik text DEFAULT 'starttls',
  alim_aktif boolean DEFAULT false,
  imap_sunucu text,
  imap_port integer,
  imap_kullanici text,
  imap_sifre text,
  spf_kayitli boolean DEFAULT false,
  dkim_kayitli boolean DEFAULT false,
  dmarc_kayitli boolean DEFAULT false,
  dmarc_politikasi text DEFAULT 'none',
  dns_son_kontrol timestamptz,
  gunluk_limit integer DEFAULT 500,
  aylik_limit integer DEFAULT 15000,
  saatlik_limit integer DEFAULT 100,
  yenilenme_periyodu text DEFAULT 'daily',
  bu_gun_gonderilen integer DEFAULT 0,
  bu_gun_tarih timestamptz DEFAULT now(),
  bu_ay_gonderilen integer DEFAULT 0,
  bu_ay_tarih timestamptz DEFAULT now(),
  varsayilan_imza text,
  varsayilan_reply_to text,
  aktif_mi boolean DEFAULT true,
  baglanti_durumu text DEFAULT 'not_tested',
  son_hata_mesaji text,
  olusturma_tarihi timestamptz DEFAULT now(),
  guncelleme_tarihi timestamptz DEFAULT now(),
  kullanici text
);

CREATE TABLE IF NOT EXISTS public.mail_inbox (
  id bigserial PRIMARY KEY,
  hesap_id bigint REFERENCES public.mail_accounts(id) ON DELETE SET NULL,
  message_id text,
  gonderen_eposta text NOT NULL,
  gonderen_adi text DEFAULT '',
  alici_eposta text DEFAULT '',
  konu text NOT NULL DEFAULT '',
  icerik_text text,
  icerik_html text,
  ek_dosyalar_json text DEFAULT '[]',
  resimler_json text DEFAULT '[]',
  lospos_cari_id bigint,
  okundu boolean DEFAULT false,
  yildizli boolean DEFAULT false,
  etiketler_json text DEFAULT '[]',
  klasor text DEFAULT 'inbox',
  mail_tarihi timestamptz DEFAULT now(),
  okunma_tarihi timestamptz,
  olusturma_tarihi timestamptz DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.mail_templates (
  id bigserial PRIMARY KEY,
  sablon_adi text NOT NULL,
  kategori text NOT NULL DEFAULT 'kampanya',
  icerik_html text NOT NULL DEFAULT '',
  icerik_mjml text,
  tasarim_json text DEFAULT '{}',
  degiskenler_json text DEFAULT '[]',
  onizleme_gorseli text,
  hazir_mi boolean DEFAULT false,
  aktif_mi boolean DEFAULT true,
  olusturma_tarihi timestamptz DEFAULT now(),
  kullanici text
);

CREATE TABLE IF NOT EXISTS public.mail_contact_lists (
  id bigserial PRIMARY KEY,
  liste_adi text NOT NULL,
  aciklama text DEFAULT '',
  otomatik_sync boolean DEFAULT false,
  sync_filtresi_json text DEFAULT '{}',
  aktif_mi boolean DEFAULT true,
  olusturma_tarihi timestamptz DEFAULT now(),
  kullanici text
);

CREATE TABLE IF NOT EXISTS public.mail_contacts (
  id bigserial PRIMARY KEY,
  eposta text NOT NULL,
  ad text DEFAULT '',
  soyad text DEFAULT '',
  telefon text DEFAULT '',
  lospos_cari_id bigint,
  aktif_mi boolean DEFAULT true,
  unsubscribe_tarihi timestamptz,
  bounce_durumu text DEFAULT 'none',
  bounce_tarihi timestamptz,
  dogrulama_durumu text DEFAULT 'unknown',
  toplam_gonderilen integer DEFAULT 0,
  toplam_acilan integer DEFAULT 0,
  toplam_tiklanan integer DEFAULT 0,
  son_gonderim timestamptz,
  olusturma_tarihi timestamptz DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.mail_campaigns (
  id bigserial PRIMARY KEY,
  hesap_id bigint REFERENCES public.mail_accounts(id) ON DELETE SET NULL,
  kampanya_adi text NOT NULL,
  konu text NOT NULL DEFAULT '',
  onizleme_metni text,
  icerik_html text,
  sablon_id bigint REFERENCES public.mail_templates(id) ON DELETE SET NULL,
  kisi_listesi_id bigint REFERENCES public.mail_contact_lists(id) ON DELETE SET NULL,
  alici_sayisi integer DEFAULT 0,
  gonderilen_sayisi integer DEFAULT 0,
  zamanlanmis_baslangic timestamptz,
  baslangic_tarihi timestamptz,
  bitis_tarihi timestamptz,
  durum text DEFAULT 'draft',
  gonderim_hizi integer DEFAULT 100,
  son_gonderilen_index integer DEFAULT 0,
  teslim_edilen integer DEFAULT 0,
  acilan integer DEFAULT 0,
  tiklanan integer DEFAULT 0,
  bouncelar integer DEFAULT 0,
  sikayetler integer DEFAULT 0,
  iptaller integer DEFAULT 0,
  unsubscribe_linki_ekle boolean DEFAULT true,
  takip_pikseli_ekle boolean DEFAULT true,
  olusturma_tarihi timestamptz DEFAULT now(),
  kullanici text
);

CREATE TABLE IF NOT EXISTS public.mail_outbox (
  id bigserial PRIMARY KEY,
  hesap_id bigint REFERENCES public.mail_accounts(id) ON DELETE SET NULL,
  kampanya_id bigint REFERENCES public.mail_campaigns(id) ON DELETE SET NULL,
  servis_message_id text,
  alici_eposta text NOT NULL,
  alici_adi text DEFAULT '',
  lospos_cari_id bigint,
  konu text NOT NULL DEFAULT '',
  icerik_html text,
  icerik_text text,
  ek_dosyalar_json text DEFAULT '[]',
  sablon_id bigint REFERENCES public.mail_templates(id) ON DELETE SET NULL,
  durum text DEFAULT 'queued',
  hata_mesaji text,
  bounce_nedeni text,
  zamanlanmis_tarih timestamptz,
  gonderim_tarihi timestamptz,
  teslim_tarihi timestamptz,
  acilma_tarihi timestamptz,
  tiklanma_tarihi timestamptz,
  olusturma_tarihi timestamptz DEFAULT now(),
  kullanici text
);

CREATE TABLE IF NOT EXISTS public.mail_contact_list_memberships (
  list_id bigint NOT NULL REFERENCES public.mail_contact_lists(id) ON DELETE CASCADE,
  contact_id bigint NOT NULL REFERENCES public.mail_contacts(id) ON DELETE CASCADE,
  PRIMARY KEY (list_id, contact_id)
);

CREATE UNIQUE INDEX IF NOT EXISTS mail_inbox_account_message_unique
  ON public.mail_inbox (hesap_id, message_id)
  WHERE message_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_mail_campaigns_created_at
  ON public.mail_campaigns (olusturma_tarihi DESC);
CREATE INDEX IF NOT EXISTS idx_mail_inbox_account_date
  ON public.mail_inbox (hesap_id, mail_tarihi DESC);
CREATE INDEX IF NOT EXISTS idx_mail_outbox_campaign_date
  ON public.mail_outbox (kampanya_id, gonderim_tarihi DESC);
CREATE INDEX IF NOT EXISTS idx_mail_templates_category
  ON public.mail_templates (kategori, sablon_adi);
CREATE UNIQUE INDEX IF NOT EXISTS idx_mail_contacts_lower_email
  ON public.mail_contacts (lower(eposta));
CREATE INDEX IF NOT EXISTS idx_mail_contact_memberships_contact
  ON public.mail_contact_list_memberships (contact_id);
CREATE INDEX IF NOT EXISTS idx_mail_contact_memberships_list
  ON public.mail_contact_list_memberships (list_id);

INSERT INTO public.permissions (key, label, group_name, description)
VALUES ('manage_mail', 'Posta Modülü', 'content', 'Posta modülü, kampanyalar, şablonlar ve posta ayarlarını yönetme yetkisi.')
ON CONFLICT (key) DO UPDATE SET
  label = EXCLUDED.label,
  group_name = EXCLUDED.group_name,
  description = EXCLUDED.description;

INSERT INTO public.role_permissions (role_id, permission_key)
SELECT id, 'manage_mail'
FROM public.roles
WHERE name = 'admin'
ON CONFLICT DO NOTHING;
