import type { APIRoute } from 'astro';
import crypto from 'crypto';
import { dbQuery } from '@/lib/server/supabaseDb';
import { getSessionFromRequest, json, withTransaction } from '@/lib/server/appDb';
import {
  adminCreateAuthUser,
  adminDeleteAuthUser,
  markProfileSignedIn,
  markProfileSignedOut,
  setPasswordForUser,
  signInWithPassword,
  signInWithSocialToken,
} from '@/lib/server/appAuth';
import { getRequestLocation } from '@/lib/server/requestLocation';
import {
  clearLoginFailures,
  getLoginAttemptLock,
  getSecuritySettings,
  recordLoginFailure,
  validatePasswordWithSecuritySettings,
} from '@/lib/server/securitySettings';
import { normalizeTurkeyCity } from '@/lib/server/turkeyCities';
import { notifyAdminsForUserSignup } from '@/lib/server/notifications/adminEvents';
import { sendMailWithAccount } from '@/lib/server/mail/providers';
import { readRuntimeEnv } from '@/lib/server/runtimeEnv';

const SIGNUP_VERIFICATION_PURPOSE = 'signup';
const SIGNUP_VERIFICATION_TEMPLATE = 'Yeni Üye Kod Doğrulama';
const SIGNUP_CODE_TTL_SECONDS = 150;
const SIGNUP_CODE_RESEND_SECONDS = 120;
const SIGNUP_CODE_MAX_ATTEMPTS = 5;

function cleanText(value: unknown) {
  return String(value || '').trim();
}

function cleanEmail(value: unknown) {
  return cleanText(value).toLowerCase();
}

function cleanIdentifier(value: unknown) {
  return cleanText(value).replace(/^@+/, '').trim();
}

function looksLikeEmail(value: string) {
  return /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(value);
}

function verificationHash(email: string, code: string) {
  const secret =
    readRuntimeEnv('PATEEZ_AUTH_JWT_SECRET') ||
    readRuntimeEnv('AUTH_JWT_SECRET') ||
    readRuntimeEnv('MAIL_SECRET_KEY') ||
    'pateez-signup-verification';
  return crypto
    .createHmac('sha256', secret)
    .update(`${SIGNUP_VERIFICATION_PURPOSE}:${email.toLowerCase()}:${code}`)
    .digest('hex');
}

function generateVerificationCode() {
  return String(crypto.randomInt(100000, 1000000));
}

function secondsUntil(value: unknown) {
  const time = Date.parse(String(value || ''));
  if (!Number.isFinite(time)) return 0;
  return Math.max(0, Math.ceil((time - Date.now()) / 1000));
}

function escapeHtml(value: string) {
  return value
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;')
    .replaceAll("'", '&#39;');
}

function replaceVerificationVariables(value: unknown, variables: Record<string, string>, html = false) {
  return Object.entries(variables).reduce((text, [key, raw]) => {
    const replacement = html ? escapeHtml(raw) : raw;
    return text.replaceAll(`{{${key}}}`, replacement);
  }, String(value || ''));
}

function plainTextFromHtml(html: string) {
  return String(html || '')
    .replace(/<style[\s\S]*?<\/style>/gi, ' ')
    .replace(/<script[\s\S]*?<\/script>/gi, ' ')
    .replace(/<[^>]+>/g, ' ')
    .replace(/\s+/g, ' ')
    .trim();
}

async function emailForIdentifier(identifier: string) {
  const clean = cleanIdentifier(identifier);
  if (!clean) return '';
  if (looksLikeEmail(clean)) return clean.toLowerCase();

  const result = await dbQuery<{ email: string | null }>(
    `SELECT email
     FROM public.profiles
     WHERE lower(username) = lower($1)
        OR lower(slug) = lower($1)
     LIMIT 1`,
    [clean]
  );
  return cleanEmail(result.rows[0]?.email);
}

async function profileForUser(userId: string) {
  if (!userId) return null;
  const result = await dbQuery<{
    id: string;
    username: string | null;
    full_name: string | null;
    avatar_url: string | null;
    cover_url: string | null;
    phone: string | null;
    address: string | null;
    role: string | null;
    email: string | null;
    status: string | null;
    city: string | null;
    auth_provider: string | null;
    auth_providers: string[] | null;
    writer_application_status: string | null;
    writer_application_at: string | null;
  }>(
    `SELECT id, username, full_name, avatar_url, cover_url, phone, address,
            role, email, status, city, auth_provider, auth_providers,
            writer_application_status, writer_application_at
     FROM public.profiles
     WHERE id = $1::uuid
     LIMIT 1`,
    [userId]
  );
  return result.rows[0] || null;
}

function profileForClient(profile: Awaited<ReturnType<typeof profileForUser>>) {
  if (!profile) return null;
  const { status: _status, ...safeProfile } = profile;
  return safeProfile;
}

function cleanSignupUsernameBase(fullName: string, email: string) {
  const source = fullName || email.split('@')[0] || 'uye';
  const normalized = source
    .toLocaleLowerCase('tr-TR')
    .replace(/ğ/g, 'g')
    .replace(/ü/g, 'u')
    .replace(/ş/g, 's')
    .replace(/ı/g, 'i')
    .replace(/ö/g, 'o')
    .replace(/ç/g, 'c')
    .normalize('NFD')
    .replace(/[\u0300-\u036f]/g, '')
    .replace(/[^a-z0-9._-]+/g, '-')
    .replace(/^-+|-+$/g, '')
    .slice(0, 70);
  return normalized.length >= 3 ? normalized : `uye-${normalized || 'pateez'}`;
}

async function uniqueSignupUsername(client: any, base: string, excludeUserId = '') {
  for (let index = 0; index < 50; index += 1) {
    const candidate = index === 0 ? base : `${base}${index + 1}`;
    const result = await client.query(
      `SELECT 1
       FROM public.profiles
       WHERE ($2::uuid IS NULL OR id <> $2::uuid)
         AND (
           lower(username) = lower($1)
           OR lower(slug) = lower($1)
         )
       LIMIT 1`,
      [candidate, excludeUserId || null],
    );
    if (!result.rows[0]) return candidate;
  }
  return `${base.slice(0, 58)}-${Date.now().toString(36).slice(-6)}`;
}

function cleanAuthProvider(value: unknown) {
  const provider = cleanText(value).toLowerCase();
  return ['email', 'google', 'apple', 'facebook', 'x', 'twitter'].includes(provider)
    ? provider
    : 'email';
}

function cleanProviderList(value: unknown, fallback: string) {
  const source = Array.isArray(value) ? value : [fallback];
  const providers = source
    .map((item) => cleanAuthProvider(item))
    .filter(Boolean);
  return Array.from(new Set(providers.length ? providers : [fallback]));
}

function firstMetadataText(metadata: Record<string, any>, keys: string[]) {
  for (const key of keys) {
    const value = cleanText(metadata[key]);
    if (value) return value;
  }
  return '';
}

async function completeOAuthProfile(
  session: NonNullable<Awaited<ReturnType<typeof getSessionFromRequest>>>,
  location: { ip: string | null; city: string | null },
) {
  const user = session.user;
  const metadata = user.user_metadata || {};
  const appMetadata = user.app_metadata || {};
  const provider = cleanAuthProvider(
    appMetadata.provider ||
      (Array.isArray(appMetadata.providers) ? appMetadata.providers[0] : ''),
  );
  const providers = cleanProviderList(appMetadata.providers, provider);
  const email = cleanEmail(user.email || metadata.email);
  const fullName = firstMetadataText(metadata, [
    'full_name',
    'name',
    'display_name',
    'user_name',
    'preferred_username',
  ]).slice(0, 160);
  const avatarUrl = firstMetadataText(metadata, [
    'avatar_url',
    'picture',
    'picture_url',
  ]);
  const phone = cleanText((user as any).phone || metadata.phone || metadata.phone_number);
  const address = cleanText(metadata.address || metadata.location);
  const usernameBase = cleanSignupUsernameBase(
    fullName || email.split('@')[0] || user.id,
    email || user.id,
  );

  const completedProfile = await withTransaction(async (client) => {
    const existingResult = await client.query(
      `SELECT username
       FROM public.profiles
       WHERE id = $1::uuid
       LIMIT 1`,
      [user.id],
    );
    const profileAlreadyExists = Boolean(existingResult.rows[0]);
    const existingUsername = cleanText(existingResult.rows[0]?.username);
    const username = existingUsername ||
      (await uniqueSignupUsername(client, usernameBase, user.id));
    const displayName = fullName || username || email.split('@')[0] || 'Pateez';

    await client.query(
      `INSERT INTO public.profiles (
         id, username, slug, full_name, email, avatar_url, phone, address,
         role, status, auth_provider, auth_providers, updated_at
       )
       VALUES (
         $1::uuid, $2, $2, $3, $4, NULLIF($5, ''), NULLIF($6, ''),
         NULLIF($7, ''), 'member', 'Aktif', $8, $9::text[], now()
       )
       ON CONFLICT (id) DO UPDATE
       SET username = COALESCE(NULLIF(public.profiles.username, ''), EXCLUDED.username),
           slug = COALESCE(NULLIF(public.profiles.slug, ''), EXCLUDED.slug),
           full_name = COALESCE(NULLIF(public.profiles.full_name, ''), EXCLUDED.full_name),
           email = COALESCE(NULLIF(public.profiles.email, ''), EXCLUDED.email),
           avatar_url = COALESCE(NULLIF(public.profiles.avatar_url, ''), EXCLUDED.avatar_url),
           phone = COALESCE(NULLIF(public.profiles.phone, ''), EXCLUDED.phone),
           address = COALESCE(NULLIF(public.profiles.address, ''), EXCLUDED.address),
           status = COALESCE(NULLIF(public.profiles.status, ''), 'Aktif'),
           auth_provider = EXCLUDED.auth_provider,
           auth_providers = EXCLUDED.auth_providers,
           updated_at = now()`,
      [
        user.id,
        username,
        displayName,
        email,
        avatarUrl,
        phone,
        address,
        provider,
        providers,
      ],
    );
    return { created: !profileAlreadyExists, displayName };
  });
  await markProfileSignedIn(user.id, {
    ipAddress: location.ip,
    signupCity: location.city,
  });
  if (completedProfile.created) {
    await notifyAdminsForUserSignup({
      userId: user.id,
      name: completedProfile.displayName,
      email,
      provider,
      city: location.city,
    }).catch((notifyError) => {
      console.warn(
        'OAuth signup admin notification failed:',
        notifyError?.message || notifyError,
      );
    });
  }
}

async function ensureSignupEmailAvailable(client: any, email: string) {
  const result = await client.query(
    `SELECT 1
     FROM public.profiles
     WHERE lower(email) = lower($1)
     LIMIT 1`,
    [email],
  );
  if (result.rows[0]) throw new Error('E-posta zaten kullanılıyor');
}

type SignupInput = {
  fullName: string;
  email: string;
  password: string;
  passwordAgain: string;
  city: string;
  signupCity: string;
  attemptIdentifier: string;
};

async function readSignupInput(
  request: Request,
  body: Record<string, any>,
  location: { ip: string | null; city: string | null },
): Promise<
  | { ok: true; input: SignupInput; settings: Awaited<ReturnType<typeof getSecuritySettings>> }
  | { ok: false; response: Response }
> {
  const fullName = cleanText(body.fullName || body.full_name).slice(0, 160);
  const email = cleanEmail(body.email);
  const password = String(body.password || '');
  const passwordAgain = String(body.passwordAgain || body.password_again || '');
  const city = normalizeTurkeyCity(body.city);
  const signupCity = location.city || city;
  const attemptIdentifier =
    email ||
    request.headers.get('cf-connecting-ip') ||
    request.headers.get('x-real-ip') ||
    'unknown';

  const settings = await getSecuritySettings('tr');
  const lock = await getLoginAttemptLock('app-signup', attemptIdentifier);
  if (lock.locked) {
    return {
      ok: false,
      response: json(
        { data: { user: null, session: null, profile: null }, error: { message: 'Kayıt geçici olarak kilitli. Lütfen daha sonra tekrar deneyin.' } },
        429,
      ),
    };
  }

  const fail = async (message: string, status = 400) => {
    await recordLoginFailure('app-signup', attemptIdentifier, settings);
    return {
      ok: false as const,
      response: json(
        { data: { user: null, session: null, profile: null }, error: { message } },
        status,
      ),
    };
  };

  if (!fullName || !email || !password || !city) {
    return fail('Ad soyad, e-posta, şifre ve şehir zorunlu');
  }
  if (!looksLikeEmail(email)) {
    return fail('Geçerli bir e-posta girin');
  }
  if (passwordAgain && password !== passwordAgain) {
    return fail('Şifreler eşleşmiyor');
  }
  const passwordError = validatePasswordWithSecuritySettings(password, settings);
  if (passwordError) {
    return fail(passwordError);
  }

  return {
    ok: true,
    input: {
      fullName,
      email,
      password,
      passwordAgain,
      city,
      signupCity,
      attemptIdentifier,
    },
    settings,
  };
}

async function findSignupMailAccount() {
  const result = await dbQuery(
    `SELECT *,
            hesap_adi AS account_name,
            gonderen_adi AS sender_name,
            gonderen_eposta AS sender_email,
            servis_tipi AS service_type,
            gonderim_modu AS sending_mode,
            smtp_sunucu AS smtp_host,
            smtp_kullanici AS smtp_username,
            smtp_sifre AS smtp_password_encrypted,
            smtp_guvenlik AS smtp_secure,
            varsayilan_reply_to AS default_reply_to
       FROM public.mail_accounts
      WHERE aktif_mi IS TRUE
        AND lower(gonderen_eposta) = ANY($1::text[])
      ORDER BY CASE lower(gonderen_eposta)
                 WHEN 'destek@pateez.com' THEN 0
                 WHEN 'info@pateez.com' THEN 1
                 WHEN 'haber@pateez.com' THEN 2
                 ELSE 3
               END,
               olusturma_tarihi DESC
      LIMIT 1`,
    [['destek@pateez.com', 'info@pateez.com', 'haber@pateez.com', 'pateez@pateez.com']],
  );
  if (result.rows[0]) return result.rows[0];
  const fallback = await dbQuery(
    `SELECT *,
            hesap_adi AS account_name,
            gonderen_adi AS sender_name,
            gonderen_eposta AS sender_email,
            servis_tipi AS service_type,
            gonderim_modu AS sending_mode,
            smtp_sunucu AS smtp_host,
            smtp_kullanici AS smtp_username,
            smtp_sifre AS smtp_password_encrypted,
            smtp_guvenlik AS smtp_secure,
            varsayilan_reply_to AS default_reply_to
       FROM public.mail_accounts
      WHERE aktif_mi IS TRUE
      ORDER BY olusturma_tarihi DESC
      LIMIT 1`,
  );
  return fallback.rows[0] || null;
}

async function sendSignupVerificationMail(input: SignupInput, code: string) {
  const [templateResult, account] = await Promise.all([
    dbQuery<{
      id: string;
      konu: string | null;
      icerik_html: string | null;
      onizleme_metni: string | null;
    }>(
      `SELECT id::text, konu, icerik_html, onizleme_metni
         FROM public.mail_templates
        WHERE sablon_adi = $1
          AND aktif_mi IS TRUE
        ORDER BY id DESC
        LIMIT 1`,
      [SIGNUP_VERIFICATION_TEMPLATE],
    ),
    findSignupMailAccount(),
  ]);
  const template = templateResult.rows[0];
  if (!template) throw new Error('Üyelik doğrulama mail şablonu bulunamadı');
  if (!account) throw new Error('Aktif mail hesabı bulunamadı');

  const variables = {
    uye_adi: input.fullName,
    uye_eposta: input.email,
    dogrulama_kodu: code,
  };
  const subject = replaceVerificationVariables(
    template.konu || 'Pateez.com üyelik doğrulama kodun: {{dogrulama_kodu}}',
    variables,
  );
  const html = replaceVerificationVariables(template.icerik_html, variables, true);
  const text = replaceVerificationVariables(
    template.onizleme_metni || plainTextFromHtml(html),
    variables,
  );

  const outbox = await dbQuery(
    `INSERT INTO public.mail_outbox (
       hesap_id, alici_eposta, alici_adi, konu, icerik_html, icerik_text,
       sablon_id, durum, kullanici
     )
     VALUES ($1, $2, $3, $4, $5, $6, $7::bigint, 'sending', NULL)
     RETURNING id`,
    [
      account.id,
      input.email,
      input.fullName,
      subject,
      html,
      text,
      template.id,
    ],
  );

  try {
    const sent = await sendMailWithAccount(account, {
      to: input.email,
      subject,
      html,
      text,
    });
    await dbQuery(
      `UPDATE public.mail_outbox
          SET durum = 'sent',
              servis_message_id = $1,
              gonderim_tarihi = now(),
              hata_mesaji = null
        WHERE id = $2::bigint`,
      [sent.messageId, outbox.rows[0]?.id],
    );
    await dbQuery(
      `UPDATE public.mail_accounts
          SET bu_gun_gonderilen = COALESCE(bu_gun_gonderilen, 0) + 1,
              bu_ay_gonderilen = COALESCE(bu_ay_gonderilen, 0) + 1,
              baglanti_durumu = 'ok',
              son_hata_mesaji = null,
              guncelleme_tarihi = now()
        WHERE id = $1::bigint`,
      [account.id],
    );
  } catch (error: any) {
    await dbQuery(
      `UPDATE public.mail_outbox
          SET durum = 'failed',
              hata_mesaji = $1
        WHERE id = $2::bigint`,
      [error?.message || 'Doğrulama maili gönderilemedi', outbox.rows[0]?.id],
    ).catch(() => undefined);
    await dbQuery(
      `UPDATE public.mail_accounts
          SET baglanti_durumu = 'error',
              son_hata_mesaji = $1,
              guncelleme_tarihi = now()
        WHERE id = $2::bigint`,
      [error?.message || 'Doğrulama maili gönderilemedi', account.id],
    ).catch(() => undefined);
    throw error;
  }
}

async function requestSignupVerification(input: SignupInput) {
  const existing = await dbQuery<{
    resend_available_at: string | null;
    expires_at: string | null;
  }>(
    `SELECT resend_available_at, expires_at
       FROM public.app_email_verifications
      WHERE purpose = $1
        AND lower(email) = lower($2)
        AND consumed_at IS NULL
      ORDER BY created_at DESC
      LIMIT 1`,
    [SIGNUP_VERIFICATION_PURPOSE, input.email],
  );
  const existingRow = existing.rows[0];
  if (existingRow && secondsUntil(existingRow.resend_available_at) > 0) {
    return {
      verificationRequired: true,
      email: input.email,
      resendAfterSeconds: secondsUntil(existingRow.resend_available_at),
      expiresAt: existingRow.expires_at,
      message: 'Doğrulama kodu zaten gönderildi',
    };
  }

  await dbQuery(
    `DELETE FROM public.app_email_verifications
      WHERE purpose = $1
        AND lower(email) = lower($2)
        AND consumed_at IS NULL`,
    [SIGNUP_VERIFICATION_PURPOSE, input.email],
  );

  const code = generateVerificationCode();
  const expiresAt = new Date(Date.now() + SIGNUP_CODE_TTL_SECONDS * 1000).toISOString();
  const resendAvailableAt = new Date(Date.now() + SIGNUP_CODE_RESEND_SECONDS * 1000).toISOString();
  await dbQuery(
    `INSERT INTO public.app_email_verifications (
       purpose, email, code_hash, payload, resend_available_at, expires_at
     )
     VALUES ($1, $2, $3, $4::jsonb, $5::timestamptz, $6::timestamptz)`,
    [
      SIGNUP_VERIFICATION_PURPOSE,
      input.email,
      verificationHash(input.email, code),
      JSON.stringify({ fullName: input.fullName, city: input.city }),
      resendAvailableAt,
      expiresAt,
    ],
  );

  try {
    await sendSignupVerificationMail(input, code);
  } catch (error) {
    await dbQuery(
      `DELETE FROM public.app_email_verifications
        WHERE purpose = $1
          AND lower(email) = lower($2)
          AND code_hash = $3
          AND consumed_at IS NULL`,
      [SIGNUP_VERIFICATION_PURPOSE, input.email, verificationHash(input.email, code)],
    ).catch(() => undefined);
    throw error;
  }
  return {
    verificationRequired: true,
    email: input.email,
    resendAfterSeconds: SIGNUP_CODE_RESEND_SECONDS,
    expiresAt,
    message: 'Doğrulama kodu e-posta adresine gönderildi',
  };
}

async function consumeSignupVerification(client: any, email: string, code: string) {
  const cleanCode = cleanText(code).replace(/\D/g, '');
  if (!/^\d{6}$/.test(cleanCode)) {
    throw new Error('6 haneli doğrulama kodunu girin');
  }
  const result = await client.query(
    `SELECT id, code_hash, attempt_count, expires_at
       FROM public.app_email_verifications
      WHERE purpose = $1
        AND lower(email) = lower($2)
        AND consumed_at IS NULL
      ORDER BY created_at DESC
      LIMIT 1
      FOR UPDATE`,
    [SIGNUP_VERIFICATION_PURPOSE, email],
  );
  const row = result.rows[0];
  if (!row) throw new Error('Doğrulama kodu bulunamadı. Yeni kod isteyin');
  if (Date.parse(String(row.expires_at)) <= Date.now()) {
    await client.query(
      `UPDATE public.app_email_verifications
          SET consumed_at = now(),
              updated_at = now()
        WHERE id = $1::bigint`,
      [row.id],
    );
    throw new Error('Doğrulama kodunun süresi doldu. Yeni kod isteyin');
  }
  if (Number(row.attempt_count || 0) >= SIGNUP_CODE_MAX_ATTEMPTS) {
    throw new Error('Çok fazla hatalı kod denendi. Yeni kod isteyin');
  }
  if (row.code_hash !== verificationHash(email, cleanCode)) {
    await client.query(
      `UPDATE public.app_email_verifications
          SET attempt_count = attempt_count + 1,
              updated_at = now()
        WHERE id = $1::bigint`,
      [row.id],
    );
    throw new Error('Doğrulama kodu hatalı');
  }
  await client.query(
    `UPDATE public.app_email_verifications
        SET consumed_at = now(),
            updated_at = now()
      WHERE id = $1::bigint`,
    [row.id],
  );
}

export const POST: APIRoute = async ({ request }) => {
  try {
    const body = await request.json();
    const action = cleanText(body.action);
    const location = getRequestLocation(request);

    if (action === 'completeOAuthProfile') {
      const session = await getSessionFromRequest(request, body);
      if (!session?.user?.id) {
        return json(
          { data: { session: null, profile: null }, error: { message: 'Auth required' } },
          401,
        );
      }
      await completeOAuthProfile(session, location);
      const profile = await profileForUser(session.user.id);
      return json({
        data: { session, profile: profileForClient(profile) },
        error: null,
      });
    }

    if (action === 'signInWithSocialToken') {
      const result = await signInWithSocialToken({
        provider: body.provider,
        idToken: body.idToken || body.id_token,
        accessToken: body.accessToken || body.access_token,
        fullName: body.fullName || body.full_name,
        email: body.email,
        ipAddress: location.ip,
        signupCity: location.city,
      });
      const profile = await profileForUser(result.data.session.user.id);
      return json({
        data: { ...result.data, profile: profileForClient(profile) },
        error: null,
      });
    }

    if (action === 'requestSignupVerification') {
      const validation = await readSignupInput(request, body, location);
      if (!validation.ok) return validation.response;
      try {
        await withTransaction(async (client) => {
          await ensureSignupEmailAvailable(client, validation.input.email);
        });
        const verification = await requestSignupVerification(validation.input);
        return json({ data: verification, error: null });
      } catch (error: any) {
        await recordLoginFailure('app-signup', validation.input.attemptIdentifier, validation.settings);
        return json(
          { data: { verificationRequired: false }, error: { message: error?.message || 'Doğrulama kodu gönderilemedi' } },
          400,
        );
      }
    }

    if (action === 'signUpWithPassword' || action === 'verifySignupWithPassword') {
      const validation = await readSignupInput(request, body, location);
      if (!validation.ok) return validation.response;
      const { input, settings } = validation;
      const verificationCode = cleanText(body.verificationCode || body.verification_code || body.code);

      if (!verificationCode) {
        try {
          await withTransaction(async (client) => {
            await ensureSignupEmailAvailable(client, input.email);
          });
          const verification = await requestSignupVerification(input);
          return json({ data: verification, error: null });
        } catch (error: any) {
          await recordLoginFailure('app-signup', input.attemptIdentifier, settings);
          return json(
            { data: { verificationRequired: false }, error: { message: error?.message || 'Doğrulama kodu gönderilemedi' } },
            400,
          );
        }
      }

      let createdAuthUserId: string | null = null;
      let createdProfileId: string | null = null;
      try {
        const usernameBase = cleanSignupUsernameBase(input.fullName, input.email);
        const authUser = await withTransaction(async (client) => {
          await consumeSignupVerification(client, input.email, verificationCode);
          await ensureSignupEmailAvailable(client, input.email);
          const username = await uniqueSignupUsername(client, usernameBase);
          const created = await adminCreateAuthUser({
            email: input.email,
            password: input.password,
            userMetadata: {
              full_name: input.fullName,
              username,
              email: input.email,
              city: input.city,
              role: 'member',
              status: 'Aktif',
            },
            appMetadata: { provider: 'email', providers: ['email'] },
          });
          createdAuthUserId = created.id;
          await client.query(
            `INSERT INTO public.profiles (
               id, full_name, username, email, role, status, city, slug,
               ip_address, signup_city, is_logged_in, last_login_at, updated_at
             )
             VALUES (
               $1::uuid, $2, $3, $4, 'member', 'Aktif', $5, $3,
               NULLIF($6, ''), NULLIF($7, ''), true, now(), now()
             )`,
            [created.id, input.fullName, username, input.email, input.city, location.ip || '', input.signupCity || ''],
          );
          await setPasswordForUser(created.id, input.password, client);
          createdProfileId = created.id;
          return created;
        });

        const signInResult = await signInWithPassword(input.email, input.password);
        if (signInResult.error || !signInResult.data.session?.user?.id) {
          throw new Error(signInResult.error?.message || 'Kayıt oturumu oluşturulamadı');
        }
        await clearLoginFailures('app-signup', input.attemptIdentifier);
        await markProfileSignedIn(authUser.id, {
          ipAddress: location.ip,
          signupCity: input.signupCity,
        });
        const profile = await profileForUser(authUser.id);
        await notifyAdminsForUserSignup({
          userId: authUser.id,
          name: input.fullName,
          email: input.email,
          provider: 'email',
          city: input.signupCity || input.city,
        }).catch((notifyError) => {
          console.warn(
            'User signup admin notification failed:',
            notifyError?.message || notifyError,
          );
        });
        return json({
          data: { ...signInResult.data, profile: profileForClient(profile) },
          error: null,
        });
      } catch (error: any) {
        if (createdProfileId) {
          await dbQuery('DELETE FROM public.profiles WHERE id = $1::uuid', [createdProfileId]).catch(() => undefined);
        }
        if (createdAuthUserId) {
          await adminDeleteAuthUser(createdAuthUserId).catch(() => undefined);
        }
        await recordLoginFailure('app-signup', input.attemptIdentifier, settings);
        return json(
          { data: { user: null, session: null, profile: null }, error: { message: error?.message || 'Kayıt oluşturulamadı' } },
          400,
        );
      }
    }

    if (action === 'signInWithPassword') {
      const identifier = cleanIdentifier(body.identifier || body.email);
      const password = String(body.password || '');
      const email = await emailForIdentifier(identifier);
      if (!email || !password) {
        return json(
          { data: { user: null, session: null, profile: null }, error: { message: 'Invalid login credentials' } },
          401
        );
      }

      const settings = await getSecuritySettings('tr');
      const attemptIdentifier = email || identifier;
      const lock = await getLoginAttemptLock('app', attemptIdentifier);
      if (lock.locked) {
        return json(
          { data: { user: null, session: null, profile: null }, error: { message: 'Giriş geçici olarak kilitli. Lütfen daha sonra tekrar deneyin.' } },
          429
        );
      }

      const result = await signInWithPassword(email, password);
      if (result.error || !result.data.session?.user?.id) {
        const failure = await recordLoginFailure('app', attemptIdentifier, settings);
        if (failure.locked) {
          return json(
            { data: { user: null, session: null, profile: null }, error: { message: 'Giriş geçici olarak kilitli. Lütfen daha sonra tekrar deneyin.' } },
            429
          );
        }
        return json({ ...result, data: { ...result.data, profile: null } }, 401);
      }

      await clearLoginFailures('app', attemptIdentifier);
      const profile = await profileForUser(result.data.session.user.id);
      if (String(profile?.status || '').toLowerCase() === 'blocked') {
        return json(
          { data: { user: null, session: null, profile: null }, error: { message: 'Account is blocked' } },
          403
        );
      }
      await markProfileSignedIn(result.data.session.user.id, {
        ipAddress: location.ip,
        signupCity: location.city,
      });

      return json({
        data: { ...result.data, profile: profileForClient(profile) },
        error: null,
      });
    }

    if (action === 'signOut') {
      const session = await getSessionFromRequest(request, body);
      if (session?.user?.id) {
        await markProfileSignedOut(session.user.id);
      }
      return json({ data: { session: null, profile: null }, error: null });
    }

    if (action === 'getSession' || action === 'profile') {
      const session = await getSessionFromRequest(request, body);
      if (!session?.user?.id) {
        return json({ data: { session: null, profile: null }, error: null });
      }
      await markProfileSignedIn(session.user.id, {
        ipAddress: location.ip,
        signupCity: location.city,
      });
      const profile = await profileForUser(session.user.id);
      return json({
        data: { session, profile: profileForClient(profile) },
        error: null,
      });
    }

    return json({ data: null, error: { message: 'Unsupported auth action' } }, 400);
  } catch (error: any) {
    return json(
      { data: null, error: { message: error?.message || 'Auth failed' } },
      500
    );
  }
};
