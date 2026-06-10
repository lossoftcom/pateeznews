import crypto from 'crypto';
import { dbQuery } from './supabaseDb';

export type SecuritySpamPostPolicy = 'nofollow' | 'sanitize_html' | 'allow_trusted';
export type SecuritySpamInteractionPolicy = 'remove_links' | 'nofollow' | 'sanitize_html';
export type SecurityCaptchaProvider = 'cloudflare_turnstile' | 'google_recaptcha';

export interface SecuritySettings {
  languageCode: string;
  maxLoginAttempts: number;
  lockoutMinutes: number;
  passwordMinLength: number;
  passwordComplexityRequired: boolean;
  spamPostPolicy: SecuritySpamPostPolicy;
  spamInteractionPolicy: SecuritySpamInteractionPolicy;
  captchaEnabled: boolean;
  captchaProvider: SecurityCaptchaProvider;
  captchaSiteKey: string;
  captchaSecretConfigured: boolean;
  captchaSecretKey?: string;
}

type SecuritySettingsRow = {
  language_code: string | null;
  security_max_login_attempts: number | null;
  security_lockout_minutes: number | null;
  security_password_min_length: number | null;
  security_password_complexity_required: boolean | null;
  security_spam_post_policy: string | null;
  security_spam_interaction_policy: string | null;
  security_captcha_enabled: boolean | null;
  security_captcha_provider: string | null;
  security_captcha_site_key: string | null;
  security_captcha_secret_key?: string | null;
};

type LoginAttemptRow = {
  failed_count: number;
  locked: boolean;
};

const DEFAULT_SECURITY_SETTINGS: SecuritySettings = {
  languageCode: 'tr',
  maxLoginAttempts: 5,
  lockoutMinutes: 5,
  passwordMinLength: 6,
  passwordComplexityRequired: false,
  spamPostPolicy: 'nofollow',
  spamInteractionPolicy: 'remove_links',
  captchaEnabled: false,
  captchaProvider: 'cloudflare_turnstile',
  captchaSiteKey: '',
  captchaSecretConfigured: false,
};

const SECURITY_COLUMNS = `
  language_code,
  security_max_login_attempts,
  security_lockout_minutes,
  security_password_min_length,
  security_password_complexity_required,
  security_spam_post_policy,
  security_spam_interaction_policy,
  security_captcha_enabled,
  security_captcha_provider,
  security_captcha_site_key,
  security_captcha_secret_key
`;

function cleanLanguageCode(value: unknown) {
  const code = String(value || '').trim().toLowerCase().replace(/_/g, '-');
  return code || 'tr';
}

function clampInt(value: unknown, fallback: number, min: number, max: number) {
  const parsed = Number(value);
  if (!Number.isFinite(parsed)) return fallback;
  return Math.min(Math.max(Math.trunc(parsed), min), max);
}

function cleanString(value: unknown, max = 2000) {
  return String(value ?? '').trim().slice(0, max);
}

function cleanBool(value: unknown, fallback = false) {
  if (typeof value === 'boolean') return value;
  if (value === 'true') return true;
  if (value === 'false') return false;
  return fallback;
}

function cleanPostPolicy(value: unknown): SecuritySpamPostPolicy {
  const text = cleanString(value, 80);
  if (text === 'sanitize_html' || text === 'allow_trusted') return text;
  return 'nofollow';
}

function cleanInteractionPolicy(value: unknown): SecuritySpamInteractionPolicy {
  const text = cleanString(value, 80);
  if (text === 'nofollow' || text === 'sanitize_html') return text;
  return 'remove_links';
}

function cleanCaptchaProvider(value: unknown): SecurityCaptchaProvider {
  return cleanString(value, 80) === 'google_recaptcha'
    ? 'google_recaptcha'
    : 'cloudflare_turnstile';
}

function settingsFromRow(
  row: SecuritySettingsRow | null,
  languageCode: string,
  includeSecret: boolean,
): SecuritySettings {
  const fallback = { ...DEFAULT_SECURITY_SETTINGS, languageCode };
  if (!row) return fallback;
  const secretKey = cleanString(row.security_captcha_secret_key, 2000);
  return {
    languageCode: cleanLanguageCode(row.language_code || languageCode),
    maxLoginAttempts: clampInt(
      row.security_max_login_attempts,
      fallback.maxLoginAttempts,
      1,
      20,
    ),
    lockoutMinutes: clampInt(
      row.security_lockout_minutes,
      fallback.lockoutMinutes,
      1,
      1440,
    ),
    passwordMinLength: clampInt(
      row.security_password_min_length,
      fallback.passwordMinLength,
      4,
      128,
    ),
    passwordComplexityRequired: cleanBool(
      row.security_password_complexity_required,
      fallback.passwordComplexityRequired,
    ),
    spamPostPolicy: cleanPostPolicy(row.security_spam_post_policy),
    spamInteractionPolicy: cleanInteractionPolicy(
      row.security_spam_interaction_policy,
    ),
    captchaEnabled: cleanBool(row.security_captcha_enabled, fallback.captchaEnabled),
    captchaProvider: cleanCaptchaProvider(row.security_captcha_provider),
    captchaSiteKey: cleanString(row.security_captcha_site_key, 500),
    captchaSecretConfigured: secretKey.length > 0,
    ...(includeSecret ? { captchaSecretKey: secretKey } : {}),
  };
}

export async function getSecuritySettings(
  languageCode = 'tr',
  options: { includeSecret?: boolean } = {},
) {
  const code = cleanLanguageCode(languageCode);
  const includeSecret = options.includeSecret === true;
  const fetchSettings = async (targetCode: string) => {
    const result = await dbQuery<SecuritySettingsRow>(
      `SELECT ${SECURITY_COLUMNS}
       FROM public.site_settings
       WHERE language_code = $1
       LIMIT 1`,
      [targetCode],
    );
    return result.rows[0] || null;
  };

  const row = (await fetchSettings(code)) || (code === 'tr' ? null : await fetchSettings('tr'));
  return settingsFromRow(row, code, includeSecret);
}

export function publicSecuritySettings(settings: SecuritySettings) {
  const { captchaSecretKey: _secret, ...safeSettings } = settings;
  return safeSettings;
}

export async function saveSecuritySettings(
  values: Record<string, unknown>,
  languageCode = 'tr',
) {
  const code = cleanLanguageCode(languageCode);
  const current = await getSecuritySettings(code, { includeSecret: true });
  const hasSecret = Object.prototype.hasOwnProperty.call(values, 'captchaSecretKey');
  const secretKey = hasSecret
    ? cleanString(values.captchaSecretKey, 2000)
    : current.captchaSecretKey || '';

  const next: SecuritySettings = {
    languageCode: code,
    maxLoginAttempts: clampInt(
      values.maxLoginAttempts,
      current.maxLoginAttempts,
      1,
      20,
    ),
    lockoutMinutes: clampInt(values.lockoutMinutes, current.lockoutMinutes, 1, 1440),
    passwordMinLength: clampInt(
      values.passwordMinLength,
      current.passwordMinLength,
      4,
      128,
    ),
    passwordComplexityRequired: cleanBool(
      values.passwordComplexityRequired,
      current.passwordComplexityRequired,
    ),
    spamPostPolicy: Object.prototype.hasOwnProperty.call(values, 'spamPostPolicy')
      ? cleanPostPolicy(values.spamPostPolicy)
      : current.spamPostPolicy,
    spamInteractionPolicy: Object.prototype.hasOwnProperty.call(values, 'spamInteractionPolicy')
      ? cleanInteractionPolicy(values.spamInteractionPolicy)
      : current.spamInteractionPolicy,
    captchaEnabled: cleanBool(values.captchaEnabled, current.captchaEnabled),
    captchaProvider: Object.prototype.hasOwnProperty.call(values, 'captchaProvider')
      ? cleanCaptchaProvider(values.captchaProvider)
      : current.captchaProvider,
    captchaSiteKey: Object.prototype.hasOwnProperty.call(values, 'captchaSiteKey')
      ? cleanString(values.captchaSiteKey, 500)
      : current.captchaSiteKey,
    captchaSecretConfigured: secretKey.length > 0,
    captchaSecretKey: secretKey,
  };

  const result = await dbQuery<SecuritySettingsRow>(
    `INSERT INTO public.site_settings (
       language_code,
       security_max_login_attempts,
       security_lockout_minutes,
       security_password_min_length,
       security_password_complexity_required,
       security_spam_post_policy,
       security_spam_interaction_policy,
       security_captcha_enabled,
       security_captcha_provider,
       security_captcha_site_key,
       security_captcha_secret_key,
       updated_at
     )
     VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, now())
     ON CONFLICT (language_code) DO UPDATE SET
       security_max_login_attempts = EXCLUDED.security_max_login_attempts,
       security_lockout_minutes = EXCLUDED.security_lockout_minutes,
       security_password_min_length = EXCLUDED.security_password_min_length,
       security_password_complexity_required = EXCLUDED.security_password_complexity_required,
       security_spam_post_policy = EXCLUDED.security_spam_post_policy,
       security_spam_interaction_policy = EXCLUDED.security_spam_interaction_policy,
       security_captcha_enabled = EXCLUDED.security_captcha_enabled,
       security_captcha_provider = EXCLUDED.security_captcha_provider,
       security_captcha_site_key = EXCLUDED.security_captcha_site_key,
       security_captcha_secret_key = EXCLUDED.security_captcha_secret_key,
       updated_at = now()
     RETURNING ${SECURITY_COLUMNS}`,
    [
      next.languageCode,
      next.maxLoginAttempts,
      next.lockoutMinutes,
      next.passwordMinLength,
      next.passwordComplexityRequired,
      next.spamPostPolicy,
      next.spamInteractionPolicy,
      next.captchaEnabled,
      next.captchaProvider,
      next.captchaSiteKey,
      next.captchaSecretKey || '',
    ],
  );

  return settingsFromRow(result.rows[0] || null, code, false);
}

export function validatePasswordWithSecuritySettings(
  password: string,
  settings: Pick<SecuritySettings, 'passwordMinLength' | 'passwordComplexityRequired'>,
) {
  const minLength = clampInt(settings.passwordMinLength, 6, 4, 128);
  if (password.length < minLength) {
    return `Şifre en az ${minLength} karakter olmalı`;
  }
  if (
    settings.passwordComplexityRequired &&
    (!/[0-9]/.test(password) || !/[^A-Za-z0-9]/.test(password))
  ) {
    return 'Şifre en az bir sayı ve bir özel karakter içermeli';
  }
  return '';
}

export function sanitizePublicInteractionText(
  value: unknown,
  policy: SecuritySpamInteractionPolicy,
  max = 2000,
) {
  const normalized = String(value || '').replace(/\s+/g, ' ').trim().slice(0, max);
  if (policy === 'sanitize_html') {
    return normalized
      .replace(/<script[\s\S]*?<\/script>/gi, ' ')
      .replace(/<style[\s\S]*?<\/style>/gi, ' ')
      .replace(/<[^>]*>/g, ' ')
      .replace(/\s+/g, ' ')
      .trim()
      .slice(0, max);
  }
  if (policy === 'remove_links') {
    return normalized
      .replace(/\bhttps?:\/\/[^\s<>"']+/gi, ' ')
      .replace(/\bwww\.[^\s<>"']+/gi, ' ')
      .replace(/\s+/g, ' ')
      .trim()
      .slice(0, max);
  }
  return normalized;
}

function cleanLoginScope(value: string) {
  const scope = value.trim().toLowerCase().replace(/[^a-z0-9_-]/g, '');
  return scope || 'default';
}

function loginAttemptHash(scope: string, identifier: string) {
  const normalized = `${cleanLoginScope(scope)}:${identifier.trim().toLowerCase()}`;
  return crypto.createHash('sha256').update(normalized).digest('hex');
}

export async function getLoginAttemptLock(
  scope: string,
  identifier: string,
): Promise<{ locked: boolean }> {
  const id = identifier.trim();
  if (!id) return { locked: false };
  const result = await dbQuery<LoginAttemptRow>(
    `SELECT failed_count,
            locked_until IS NOT NULL AND locked_until > now() AS locked
     FROM public.security_login_attempts
     WHERE scope = $1 AND identifier_hash = $2
     LIMIT 1`,
    [cleanLoginScope(scope), loginAttemptHash(scope, id)],
  );
  return { locked: result.rows[0]?.locked === true };
}

export async function recordLoginFailure(
  scope: string,
  identifier: string,
  settings: Pick<SecuritySettings, 'maxLoginAttempts' | 'lockoutMinutes'>,
) {
  const id = identifier.trim();
  if (!id) return { locked: false };
  const maxAttempts = clampInt(settings.maxLoginAttempts, 5, 1, 20);
  const lockoutMinutes = clampInt(settings.lockoutMinutes, 5, 1, 1440);
  const result = await dbQuery<LoginAttemptRow>(
    `INSERT INTO public.security_login_attempts (
       scope,
       identifier_hash,
       failed_count,
       locked_until,
       last_failed_at,
       updated_at
     )
     VALUES (
       $1,
       $2,
       1,
       CASE WHEN $3::int <= 1 THEN now() + ($4::int * interval '1 minute') ELSE NULL END,
       now(),
       now()
     )
     ON CONFLICT (scope, identifier_hash) DO UPDATE SET
       failed_count = CASE
         WHEN public.security_login_attempts.locked_until IS NOT NULL
          AND public.security_login_attempts.locked_until > now()
         THEN public.security_login_attempts.failed_count
         ELSE public.security_login_attempts.failed_count + 1
       END,
       locked_until = CASE
         WHEN public.security_login_attempts.locked_until IS NOT NULL
          AND public.security_login_attempts.locked_until > now()
         THEN public.security_login_attempts.locked_until
         WHEN public.security_login_attempts.failed_count + 1 >= $3::int
         THEN now() + ($4::int * interval '1 minute')
         ELSE NULL
       END,
       last_failed_at = now(),
       updated_at = now()
     RETURNING failed_count,
               locked_until IS NOT NULL AND locked_until > now() AS locked`,
    [cleanLoginScope(scope), loginAttemptHash(scope, id), maxAttempts, lockoutMinutes],
  );
  return { locked: result.rows[0]?.locked === true };
}

export async function clearLoginFailures(scope: string, identifier: string) {
  const id = identifier.trim();
  if (!id) return;
  await dbQuery(
    `DELETE FROM public.security_login_attempts
     WHERE scope = $1 AND identifier_hash = $2`,
    [cleanLoginScope(scope), loginAttemptHash(scope, id)],
  );
}
