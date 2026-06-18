import type { APIRoute } from 'astro';
import { adminError, adminJson, requireAdminRequest, type AdminContext } from '@/lib/server/adminAuth';
import { decryptSecret, encryptSecret, hasSecret } from '@/lib/server/mail/secrets';
import { dbQuery } from '@/lib/server/supabaseDb';
import { signInWithPassword } from '@/lib/server/supabaseAuth';

export const prerender = false;

const SOCIAL_PASSWORD_COLUMNS = {
  whatsapp: 'social_whatsapp_password_encrypted',
  telegram: 'social_telegram_password_encrypted',
  instagram: 'social_instagram_password_encrypted',
  facebook: 'social_facebook_password_encrypted',
  x: 'social_x_password_encrypted',
  youtube: 'social_youtube_password_encrypted',
  tiktok: 'social_tiktok_password_encrypted',
  linkedin: 'social_linkedin_password_encrypted',
  pinterest: 'social_pinterest_password_encrypted',
  discord: 'social_discord_password_encrypted',
} as const;

type SocialPasswordField = keyof typeof SOCIAL_PASSWORD_COLUMNS;

const SOCIAL_PASSWORD_FIELDS = Object.keys(SOCIAL_PASSWORD_COLUMNS) as SocialPasswordField[];

function cleanLanguageCode(value: unknown) {
  const code = String(value || 'tr').trim().toLowerCase().replaceAll('_', '-');
  return code || 'tr';
}

function cleanText(value: unknown) {
  return String(value || '').trim();
}

function socialPasswordField(value: unknown): SocialPasswordField {
  const key = cleanText(value).toLowerCase();
  if (SOCIAL_PASSWORD_FIELDS.includes(key as SocialPasswordField)) {
    return key as SocialPasswordField;
  }
  throw Object.assign(new Error('Unsupported social password field'), { status: 400 });
}

function assertHighAdmin(context: AdminContext) {
  const role = String(context.profile.role || '').trim().toLowerCase();
  if (role !== 'admin' && role !== 'super_admin') {
    throw Object.assign(new Error('Super admin permission is required'), { status: 403 });
  }
}

async function verifyCurrentAdminPassword(context: AdminContext, password: unknown) {
  const value = cleanText(password);
  if (!value) {
    throw Object.assign(new Error('Super admin password is required'), { status: 400 });
  }

  const email = cleanText(context.profile.email || context.session.user.email).toLowerCase();
  if (!email) {
    throw Object.assign(new Error('Admin email is required'), { status: 403 });
  }

  const result = await signInWithPassword(email, value);
  const verifiedUserId = result.data.user?.id || '';
  if (result.error || verifiedUserId !== context.session.user.id) {
    throw Object.assign(new Error('Super admin password is invalid'), { status: 403 });
  }
}

async function passwordStatus(languageCode: string) {
  const select = SOCIAL_PASSWORD_FIELDS
    .map((field) => `${SOCIAL_PASSWORD_COLUMNS[field]} IS NOT NULL AS ${field}`)
    .join(', ');
  const result = await dbQuery(
    `SELECT ${select}
     FROM public.site_settings
     WHERE language_code = $1
     LIMIT 1`,
    [languageCode]
  );
  const row = result.rows[0] || {};
  return {
    hasPasswords: Object.fromEntries(
      SOCIAL_PASSWORD_FIELDS.map((field) => [field, row[field] === true])
    ),
  };
}

async function savePasswords(languageCode: string, rawPasswords: unknown) {
  const source = rawPasswords && typeof rawPasswords === 'object' && !Array.isArray(rawPasswords)
    ? rawPasswords as Record<string, unknown>
    : {};
  const entries = Object.entries(source)
    .map(([key, value]) => [socialPasswordField(key), cleanText(value)] as const)
    .filter(([, value]) => value.length > 0);

  if (!entries.length) return passwordStatus(languageCode);

  const columns = entries.map(([field]) => SOCIAL_PASSWORD_COLUMNS[field]);
  const insertColumns = ['language_code', ...columns, 'updated_at'];
  const insertPlaceholders = [
    '$1',
    ...entries.map((_, index) => `$${index + 2}`),
    'now()',
  ];
  const updateClause = columns
    .map((column) => `${column} = EXCLUDED.${column}`)
    .concat('updated_at = now()')
    .join(', ');

  await dbQuery(
    `INSERT INTO public.site_settings (${insertColumns.join(', ')})
     VALUES (${insertPlaceholders.join(', ')})
     ON CONFLICT (language_code) DO UPDATE SET ${updateClause}`,
    [languageCode, ...entries.map(([, value]) => encryptSecret(value))]
  );

  return passwordStatus(languageCode);
}

async function revealPassword(languageCode: string, field: SocialPasswordField) {
  const column = SOCIAL_PASSWORD_COLUMNS[field];
  const result = await dbQuery(
    `SELECT ${column} AS value
     FROM public.site_settings
     WHERE language_code = $1
     LIMIT 1`,
    [languageCode]
  );
  const encrypted = result.rows[0]?.value;
  return hasSecret(encrypted) ? decryptSecret(encrypted) : '';
}

export const POST: APIRoute = async ({ request }) => {
  try {
    const body = await request.json();
    const context = await requireAdminRequest(request, 'settings_access');
    assertHighAdmin(context);

    const action = cleanText(body?.action).toLowerCase();
    const languageCode = cleanLanguageCode(body?.language_code || body?.languageCode);

    if (action === 'status') {
      return adminJson({ data: await passwordStatus(languageCode), error: null });
    }

    if (action === 'save') {
      return adminJson({
        data: await savePasswords(languageCode, body?.passwords),
        error: null,
      });
    }

    if (action === 'reveal') {
      await verifyCurrentAdminPassword(context, body?.super_admin_password);
      const field = socialPasswordField(body?.field);
      return adminJson({
        data: { field, value: await revealPassword(languageCode, field) },
        error: null,
      });
    }

    return adminJson({ data: null, error: { message: 'Unsupported social password action' } }, 400);
  } catch (error) {
    return adminError(error);
  }
};
