import { dbQuery } from '@/lib/server/supabaseDb';
import { readRuntimeEnv } from '@/lib/server/runtimeEnv';
import { decryptSecret, hasSecret } from '@/lib/server/mail/secrets';
import { getTeam } from './bundle';

export const SOCIAL_ACCOUNT_COLUMNS = `
  id::text AS id,
  hesap_adi AS account_name,
  workspace_name,
  platformlar AS platforms,
  provider_id,
  provider_name,
  baglanti_modu AS connection_mode,
  api_base_url,
  team_id,
  redirect_url,
  webhook_url,
  scopes,
  gunluk_limit AS daily_limit,
  aylik_limit AS monthly_limit,
  saatlik_limit AS hourly_limit,
  bugun_gonderilen AS sent_today,
  bu_ay_gonderilen AS sent_this_month,
  api_dogrulandi AS api_verified,
  oauth_dogrulandi AS oauth_verified,
  webhook_dogrulandi AS webhook_verified,
  onay_gerekli AS requires_approval,
  aktif_mi AS is_active,
  baglanti_durumu AS connection_status,
  son_hata_mesaji AS last_error_message,
  son_senkron_tarihi AS last_sync_at,
  olusturma_tarihi AS created_at,
  guncelleme_tarihi AS updated_at,
  kullanici AS created_by,
  api_anahtari AS api_key_encrypted,
  client_secret AS client_secret_encrypted
`;

export function socialAccountForClient(row: any) {
  if (!row) return row;
  const { api_key_encrypted, client_secret_encrypted, ...rest } = row;
  return {
    ...rest,
    has_api_key: hasSecret(api_key_encrypted),
    has_client_secret: hasSecret(client_secret_encrypted),
    server_api_key_configured: Boolean(bundleSocialEnvApiKey()),
  };
}

function bundleSocialEnvApiKey() {
  return String(readRuntimeEnv('BUNDLE_SOCIAL_API_KEY') || '').trim();
}

export function resolveBundleApiKey(row: any) {
  const envKey = bundleSocialEnvApiKey();
  if (envKey) return envKey;
  return decryptSecret(row?.api_key_encrypted || row?.api_anahtari || '');
}

export async function getSocialAccountById(id?: unknown) {
  const value = String(id || '').trim();
  if (value) {
    const result = await dbQuery(
      `SELECT ${SOCIAL_ACCOUNT_COLUMNS}
       FROM public.social_accounts
       WHERE id = $1::bigint
       LIMIT 1`,
      [value]
    );
    if (result.rows[0]) return result.rows[0];
  }

  const fallback = await dbQuery(
    `SELECT ${SOCIAL_ACCOUNT_COLUMNS}
     FROM public.social_accounts
     WHERE aktif_mi IS TRUE
     ORDER BY api_dogrulandi DESC, oauth_dogrulandi DESC, olusturma_tarihi DESC
     LIMIT 1`
  );
  return fallback.rows[0] || null;
}

function firstChannel(account: any) {
  const channels = Array.isArray(account?.channels) ? account.channels : [];
  return channels.find((item: any) => item && typeof item === 'object') || {};
}

export async function syncBundleTeam(account: any, apiKey: string) {
  const teamId = String(account?.team_id || '').trim();
  if (!teamId) throw new Error('Bundle Social teamId is missing');

  const team = await getTeam({
    apiKey,
    apiBaseUrl: account?.api_base_url,
    teamId,
  });

  const socialAccounts = Array.isArray(team?.socialAccounts) ? team.socialAccounts : [];

  for (const item of socialAccounts) {
    const type = String(item?.type || item?.socialAccountType || item?.platform || item?.provider || '').trim().toUpperCase();
    const bundleId = String(item?.id || '').trim();
    if (!type || !bundleId) continue;
    const channel = firstChannel(item);

    await dbQuery(
      `INSERT INTO public.social_connected_accounts (
         social_account_id,
         bundle_social_account_id,
         platform_tipi,
         display_name,
         username,
         avatar_url,
         channel_id,
         channel_name,
         durum,
         raw_json,
         baglanma_tarihi,
         guncelleme_tarihi
       )
       VALUES (
         $1::bigint,
         $2,
         $3,
         $4,
         $5,
         $6,
         $7,
         $8,
         'connected',
         $9::jsonb,
         COALESCE($10::timestamptz, now()),
         now()
       )
       ON CONFLICT (social_account_id, bundle_social_account_id)
       WHERE bundle_social_account_id IS NOT NULL AND bundle_social_account_id <> ''
       DO UPDATE SET
         platform_tipi = EXCLUDED.platform_tipi,
         display_name = EXCLUDED.display_name,
         username = EXCLUDED.username,
         avatar_url = EXCLUDED.avatar_url,
         channel_id = EXCLUDED.channel_id,
         channel_name = EXCLUDED.channel_name,
         durum = 'connected',
         raw_json = EXCLUDED.raw_json,
         guncelleme_tarihi = now()`,
      [
        account.id,
        bundleId,
        type,
        String(item.displayName || item.name || item.userDisplayName || '').trim(),
        String(item.username || item.userUsername || '').trim(),
        String(item.avatarUrl || '').trim(),
        String(channel.id || '').trim(),
        String(channel.name || channel.username || channel.address || '').trim(),
        JSON.stringify(item || {}),
        item.createdAt || null,
      ]
    );
  }

  await dbQuery(
    `UPDATE public.social_accounts
     SET api_dogrulandi = true,
         oauth_dogrulandi = $1,
         webhook_dogrulandi = webhook_url <> '',
         baglanti_durumu = $2,
         son_hata_mesaji = null,
         bundle_team_json = $3::jsonb,
         son_senkron_tarihi = now(),
         guncelleme_tarihi = now()
     WHERE id = $4::bigint`,
    [socialAccounts.length > 0, socialAccounts.length > 0 ? 'connected' : 'configured', JSON.stringify(team || {}), account.id]
  );

  return { team, socialAccounts };
}

export async function updateSocialAccountError(id: unknown, message: string) {
  await dbQuery(
    `UPDATE public.social_accounts
     SET baglanti_durumu = 'error',
         son_hata_mesaji = $1,
         guncelleme_tarihi = now()
     WHERE id = $2::bigint`,
    [message, String(id)]
  );
}

export async function fetchConnectedAccounts() {
  const result = await dbQuery(
    `SELECT
       ca.id::text AS id,
       ca.social_account_id::text AS social_account_id,
       ca.bundle_social_account_id,
       ca.platform_tipi AS platform_type,
       ca.display_name,
       ca.username,
       ca.avatar_url,
       ca.channel_id,
       ca.channel_name,
       ca.raw_json,
       COALESCE(
         NULLIF(ca.raw_json->>'twitterSubType', ''),
         NULLIF(ca.raw_json->>'twitter_sub_type', ''),
         ''
       ) AS twitter_sub_type,
       ca.durum AS status,
       ca.baglanma_tarihi AS connected_at,
       ca.guncelleme_tarihi AS updated_at,
       sa.hesap_adi AS account_name,
       sa.team_id
     FROM public.social_connected_accounts ca
     JOIN public.social_accounts sa ON sa.id = ca.social_account_id
     WHERE sa.aktif_mi IS TRUE
     ORDER BY ca.guncelleme_tarihi DESC, ca.id DESC`
  );
  return result.rows;
}
