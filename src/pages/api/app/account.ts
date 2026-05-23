import type { APIRoute } from 'astro';
import crypto from 'crypto';
import bcrypt from 'bcryptjs';
import { ensureAppSchema, getProfileRole, getSessionFromRequest, json, withTransaction } from '@/lib/server/appDb';
import { dbQuery } from '@/lib/server/neonDb';

async function verifyPassword(userId: string, password: string) {
  const result = await dbQuery<{ encrypted_password: string | null }>(
    'SELECT encrypted_password FROM auth.users WHERE id = $1 AND deleted_at IS NULL LIMIT 1',
    [userId]
  );
  const hash = result.rows[0]?.encrypted_password;
  return hash ? bcrypt.compare(password, hash) : false;
}

async function setPassword(userId: string, password: string) {
  const hash = await bcrypt.hash(password, 10);
  await dbQuery('UPDATE auth.users SET encrypted_password = $1, updated_at = now() WHERE id = $2', [hash, userId]);
}

async function requireAdmin(userId: string) {
  const role = String(await getProfileRole(userId)).toLowerCase();
  return role === 'admin' || role === 'super_admin';
}

function cleanText(value: unknown) {
  return String(value || '').trim();
}

function cleanEmail(value: unknown) {
  return cleanText(value).toLowerCase();
}

function userPayload(body: any, passwordRequired: boolean) {
  const email = cleanEmail(body.email);
  const password = String(body.password || '');
  const fullName = cleanText(body.fullName);
  const username = cleanText(body.username);
  const role = cleanText(body.role) || 'member';
  const status = cleanText(body.status) || 'Aktif';
  const rewardEnabled = body.rewardEnabled === true;

  if (!fullName || !username || !email) {
    return { error: 'Ad soyad, kullanıcı adı ve e-posta zorunlu' };
  }
  if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)) {
    return { error: 'Geçerli bir e-posta girin' };
  }
  if (passwordRequired && password.length < 6) {
    return { error: 'Şifre en az 6 karakter olmalı' };
  }
  if (!passwordRequired && password && password.length < 6) {
    return { error: 'Şifre en az 6 karakter olmalı' };
  }

  return { email, password, fullName, username, role, status, rewardEnabled };
}

async function ensureUniqueUserFields(client: any, input: { userId?: string; email: string; username: string }) {
  const profileConflict = await client.query(
    `SELECT id, username, email
     FROM public.profiles
     WHERE ($3::uuid IS NULL OR id <> $3::uuid)
       AND (lower(username) = lower($1) OR lower(email) = lower($2))
     LIMIT 1`,
    [input.username, input.email, input.userId || null]
  );
  const profile = profileConflict.rows[0];
  if (profile?.username?.toLowerCase() === input.username.toLowerCase()) {
    throw new Error('Kullanıcı adı zaten kullanılıyor');
  }
  if (profile?.email?.toLowerCase() === input.email.toLowerCase()) {
    throw new Error('E-posta zaten kullanılıyor');
  }

  const authConflict = await client.query(
    `SELECT id
     FROM auth.users
     WHERE ($2::uuid IS NULL OR id <> $2::uuid)
       AND lower(email) = lower($1)
       AND deleted_at IS NULL
     LIMIT 1`,
    [input.email, input.userId || null]
  );
  if (authConflict.rows[0]) throw new Error('E-posta zaten kullanılıyor');
}

async function profileForClient(client: any, userId: string) {
  const result = await client.query(
    `SELECT id, username, full_name, avatar_url, role, status, reward_system, email, created_at
     FROM public.profiles
     WHERE id = $1::uuid
     LIMIT 1`,
    [userId]
  );
  return result.rows[0] || null;
}

function cleanRoleName(value: unknown) {
  return cleanText(value).toLowerCase().replace(/\s+/g, '_');
}

function rolePayload(body: any) {
  const name = cleanRoleName(body.name);
  const label = cleanText(body.label);
  const description = cleanText(body.description);
  const color = cleanText(body.color) || '#2C3E50';

  if (!name || !label) {
    return { error: 'Rol adı ve sistem anahtarı zorunlu' };
  }
  if (!/^[a-z0-9_]+$/.test(name)) {
    return { error: 'Rol sistem anahtarı sadece küçük harf, rakam ve alt çizgi içerebilir' };
  }
  if (!/^#[0-9a-fA-F]{6}$/.test(color)) {
    return { error: 'Rol rengi geçerli hex formatında olmalı' };
  }

  return { name, label, description, color };
}

async function ensureUniqueRoleName(client: any, input: { roleId?: string; name: string }) {
  const conflict = await client.query(
    `SELECT id
     FROM public.roles
     WHERE lower(name) = lower($1)
       AND ($2::uuid IS NULL OR id <> $2::uuid)
     LIMIT 1`,
    [input.name, input.roleId || null]
  );
  if (conflict.rows[0]) throw new Error('Rol sistem anahtarı zaten kullanılıyor');
}

function rolePermissionKeys(body: any) {
  if (!Array.isArray(body.permissionKeys)) return [];
  const keys = body.permissionKeys
    .map((value: unknown) => cleanText(value))
    .filter(Boolean) as string[];
  return Array.from(new Set<string>(keys));
}

const CORE_LANGUAGE_CODES = new Set(['tr', 'en', 'ar']);

function cleanLanguageCode(value: unknown) {
  return cleanText(value).toLowerCase().replace(/_/g, '-');
}

function languagePayload(body: any) {
  const code = cleanLanguageCode(body.code || body.languageCode);
  const name = cleanText(body.name);
  const direction = cleanText(body.direction).toLowerCase() === 'rtl' ? 'rtl' : 'ltr';
  const rawStatus = cleanText(body.status).toLowerCase();
  const status = CORE_LANGUAGE_CODES.has(code)
    ? 'active'
    : rawStatus === 'passive' || rawStatus === 'inactive'
      ? 'passive'
      : 'active';
  const flagCode = cleanLanguageCode(body.flagCode || body.flag_code || code);

  if (!code || !name) {
    return { error: 'Dil adı ve dil kodu zorunlu' };
  }
  if (!/^[a-z]{2,3}(-[a-z0-9]{2,8})?$/.test(code)) {
    return { error: 'Dil kodu geçerli formatta olmalı' };
  }

  return { code, name, direction, status, flagCode: flagCode || code };
}

function languageTranslationsPayload(body: any) {
  const languageCode = cleanLanguageCode(body.code || body.languageCode);
  const translations = body.translations;
  if (!languageCode) return { error: 'Dil kodu zorunlu' };
  if (!translations || typeof translations !== 'object' || Array.isArray(translations)) {
    return { error: 'Çeviri verisi geçerli JSON nesnesi olmalı' };
  }

  const keys: string[] = [];
  const values: string[] = [];
  for (const [rawKey, rawValue] of Object.entries(translations)) {
    const key = cleanText(rawKey);
    if (!key) continue;
    keys.push(key);
    values.push(String(rawValue ?? ''));
  }
  return { languageCode, keys, values };
}

async function assertLanguageExists(client: any, code: string) {
  const result = await client.query(
    'SELECT code, status, is_default FROM public.languages WHERE code = $1 LIMIT 1',
    [code]
  );
  const language = result.rows[0];
  if (!language) throw new Error('Dil bulunamadı');
  return language;
}

export const POST: APIRoute = async ({ request }) => {
  try {
    const body = await request.json();
    const action = String(body.action || '');

    if (action === 'request-password-reset') {
      const email = String(body.email || '').trim().toLowerCase();
      if (!email) return json({ error: { message: 'Email required' } }, 400);
      await ensureAppSchema();
      const token = crypto.randomBytes(32).toString('base64url');
      const tokenHash = crypto.createHash('sha256').update(token).digest('hex');
      await dbQuery(
        `INSERT INTO public.password_reset_requests (email, token_hash, expires_at)
         VALUES ($1, $2, now() + interval '30 minutes')`,
        [email, tokenHash]
      );
      return json({ ok: true });
    }

    if (action === 'ensure-schema') {
      await ensureAppSchema();
      return json({ ok: true });
    }

    const session = await getSessionFromRequest(request, body);
    if (!session?.user?.id) return json({ error: { message: 'Auth required' } }, 401);

    await ensureAppSchema();

    const userId = session.user.id;

    if (action === 'update-password') {
      const currentPassword = String(body.currentPassword || '');
      const newPassword = String(body.newPassword || '');
      if (newPassword.length < 6) return json({ error: { message: 'Password is too short' } }, 400);
      if (!(await verifyPassword(userId, currentPassword))) {
        return json({ error: { message: 'Current password is invalid' } }, 400);
      }
      await setPassword(userId, newPassword);
      return json({ ok: true });
    }

    if (action === 'delete-self') {
      const currentPassword = String(body.currentPassword || '');
      if (!(await verifyPassword(userId, currentPassword))) {
        return json({ error: { message: 'Current password is invalid' } }, 400);
      }
      await dbQuery('DELETE FROM public.profiles WHERE id = $1', [userId]);
      await dbQuery('DELETE FROM auth.users WHERE id = $1', [userId]);
      return json({ ok: true });
    }

    if (action === 'admin-update-password') {
      if (!(await requireAdmin(userId))) return json({ error: { message: 'Forbidden' } }, 403);
      const targetUserId = String(body.userId || '');
      const newPassword = String(body.newPassword || '');
      if (!targetUserId || newPassword.length < 6) return json({ error: { message: 'Invalid user or password' } }, 400);
      await setPassword(targetUserId, newPassword);
      return json({ ok: true });
    }

    if (action === 'admin-create-user') {
      if (!(await requireAdmin(userId))) return json({ error: { message: 'Forbidden' } }, 403);
      const payload = userPayload(body, true);
      if ('error' in payload) return json({ error: { message: payload.error } }, 400);

      const profile = await withTransaction(async (client) => {
        await ensureUniqueUserFields(client, {
          email: payload.email,
          username: payload.username,
        });
        const hash = await bcrypt.hash(payload.password, 10);
        const authResult = await client.query(
          `INSERT INTO auth.users (
             id, aud, role, email, encrypted_password, email_confirmed_at,
             raw_app_meta_data, raw_user_meta_data, created_at, updated_at
           )
           VALUES (
             gen_random_uuid(), 'authenticated', 'authenticated', $1::text, $2, now(),
             '{"provider":"email","providers":["email"]}'::jsonb,
             jsonb_build_object('full_name', $3::text, 'username', $4::text, 'email', $1::text, 'role', $5::text, 'status', $6::text),
             now(), now()
           )
           RETURNING id`,
          [payload.email, hash, payload.fullName, payload.username, payload.role, payload.status]
        );
        const targetUserId = authResult.rows[0].id;
        await client.query(
          `INSERT INTO public.profiles (
             id, full_name, username, email, role, status, reward_system, updated_at
           )
           VALUES ($1::uuid, $2, $3, $4, $5, $6, $7, now())
           ON CONFLICT (id) DO UPDATE
           SET full_name = EXCLUDED.full_name,
               username = EXCLUDED.username,
               email = EXCLUDED.email,
               role = EXCLUDED.role,
               status = EXCLUDED.status,
               reward_system = EXCLUDED.reward_system,
               updated_at = now()`,
          [
            targetUserId,
            payload.fullName,
            payload.username,
            payload.email,
            payload.role,
            payload.status,
            payload.rewardEnabled,
          ]
        );
        return profileForClient(client, targetUserId);
      });

      return json({ ok: true, profile });
    }

    if (action === 'admin-update-user') {
      if (!(await requireAdmin(userId))) return json({ error: { message: 'Forbidden' } }, 403);
      const targetUserId = String(body.userId || '');
      if (!targetUserId) return json({ error: { message: 'User missing' } }, 400);
      const payload = userPayload(body, false);
      if ('error' in payload) return json({ error: { message: payload.error } }, 400);

      const profile = await withTransaction(async (client) => {
        await ensureUniqueUserFields(client, {
          userId: targetUserId,
          email: payload.email,
          username: payload.username,
        });

        if (payload.password) {
          const hash = await bcrypt.hash(payload.password, 10);
          await client.query(
            'UPDATE auth.users SET encrypted_password = $1, updated_at = now() WHERE id = $2::uuid',
            [hash, targetUserId]
          );
        }

        await client.query(
          `UPDATE auth.users
           SET email = $1::text,
               raw_user_meta_data = coalesce(raw_user_meta_data, '{}'::jsonb)
                 || jsonb_build_object('full_name', $2::text, 'username', $3::text, 'email', $1::text, 'role', $4::text, 'status', $5::text),
               updated_at = now()
           WHERE id = $6::uuid`,
          [payload.email, payload.fullName, payload.username, payload.role, payload.status, targetUserId]
        );

        const updateResult = await client.query(
          `UPDATE public.profiles
           SET full_name = $1,
               username = $2,
               email = $3,
               role = $4,
               status = $5,
               reward_system = $6,
               updated_at = now()
           WHERE id = $7::uuid
           RETURNING id`,
          [
            payload.fullName,
            payload.username,
            payload.email,
            payload.role,
            payload.status,
            payload.rewardEnabled,
            targetUserId,
          ]
        );
        if (!updateResult.rows[0]) throw new Error('Kullanıcı bulunamadı');
        return profileForClient(client, targetUserId);
      });

      return json({ ok: true, profile });
    }

    if (action === 'admin-delete-user') {
      if (!(await requireAdmin(userId))) return json({ error: { message: 'Forbidden' } }, 403);
      const targetUserId = String(body.userId || '');
      if (!targetUserId) return json({ error: { message: 'User missing' } }, 400);
      await withTransaction(async (client) => {
        await client.query('DELETE FROM public.profiles WHERE id = $1::uuid', [targetUserId]);
        await client.query('DELETE FROM auth.users WHERE id = $1::uuid', [targetUserId]);
      });
      return json({ ok: true });
    }

    if (action === 'admin-delete-users') {
      if (!(await requireAdmin(userId))) return json({ error: { message: 'Forbidden' } }, 403);
      const userIds = Array.isArray(body.userIds)
        ? body.userIds.map((value: unknown) => String(value || '').trim()).filter(Boolean)
        : [];
      if (!userIds.length) return json({ error: { message: 'Users missing' } }, 400);
      await withTransaction(async (client) => {
        await client.query('DELETE FROM public.profiles WHERE id = ANY($1::uuid[])', [userIds]);
        await client.query('DELETE FROM auth.users WHERE id = ANY($1::uuid[])', [userIds]);
      });
      return json({ ok: true, deletedIds: userIds });
    }

    if (action === 'admin-create-role') {
      if (!(await requireAdmin(userId))) return json({ error: { message: 'Forbidden' } }, 403);
      const payload = rolePayload(body);
      if ('error' in payload) return json({ error: { message: payload.error } }, 400);

      const role = await withTransaction(async (client) => {
        await ensureUniqueRoleName(client, { name: payload.name });
        const result = await client.query(
          `INSERT INTO public.roles (name, label, description, color)
           VALUES ($1, $2, $3, $4)
           RETURNING id, name, label, description, color, created_at`,
          [payload.name, payload.label, payload.description, payload.color]
        );
        return result.rows[0];
      });

      return json({ ok: true, role });
    }

    if (action === 'admin-update-role') {
      if (!(await requireAdmin(userId))) return json({ error: { message: 'Forbidden' } }, 403);
      const roleId = cleanText(body.roleId);
      if (!roleId) return json({ error: { message: 'Role missing' } }, 400);
      const payload = rolePayload(body);
      if ('error' in payload) return json({ error: { message: payload.error } }, 400);

      const role = await withTransaction(async (client) => {
        const currentResult = await client.query(
          'SELECT id, name FROM public.roles WHERE id = $1::uuid LIMIT 1',
          [roleId]
        );
        const current = currentResult.rows[0];
        if (!current) throw new Error('Rol bulunamadı');
        if (current.name === 'admin') throw new Error('Sistem rolü düzenlenemez');

        await ensureUniqueRoleName(client, { roleId, name: payload.name });
        const result = await client.query(
          `UPDATE public.roles
           SET name = $1,
               label = $2,
               description = $3,
               color = $4
           WHERE id = $5::uuid
           RETURNING id, name, label, description, color, created_at`,
          [payload.name, payload.label, payload.description, payload.color, roleId]
        );
        if (current.name !== payload.name) {
          await client.query(
            'UPDATE public.profiles SET role = $1, updated_at = now() WHERE role = $2',
            [payload.name, current.name]
          );
        }
        return result.rows[0];
      });

      return json({ ok: true, role });
    }

    if (action === 'admin-delete-role') {
      if (!(await requireAdmin(userId))) return json({ error: { message: 'Forbidden' } }, 403);
      const roleId = cleanText(body.roleId);
      if (!roleId) return json({ error: { message: 'Role missing' } }, 400);

      await withTransaction(async (client) => {
        const roleResult = await client.query(
          'SELECT id, name, label FROM public.roles WHERE id = $1::uuid LIMIT 1',
          [roleId]
        );
        const role = roleResult.rows[0];
        if (!role) throw new Error('Rol bulunamadı');
        if (role.name === 'admin') throw new Error('Sistem rolü silinemez');

        const memberResult = await client.query(
          'SELECT COUNT(*)::int AS count FROM public.profiles WHERE role = $1',
          [role.name]
        );
        if (Number(memberResult.rows[0]?.count || 0) > 0) {
          throw new Error('Bu role bağlı kullanıcı olduğu için rol silinemez');
        }

        await client.query('DELETE FROM public.role_permissions WHERE role_id = $1::uuid', [roleId]);
        await client.query('DELETE FROM public.roles WHERE id = $1::uuid', [roleId]);
      });

      return json({ ok: true, deletedId: roleId });
    }

    if (action === 'admin-set-role-permissions') {
      if (!(await requireAdmin(userId))) return json({ error: { message: 'Forbidden' } }, 403);
      const roleId = cleanText(body.roleId);
      if (!roleId) return json({ error: { message: 'Role missing' } }, 400);
      const permissionKeys = rolePermissionKeys(body);

      await withTransaction(async (client) => {
        const roleResult = await client.query(
          'SELECT id, name FROM public.roles WHERE id = $1::uuid LIMIT 1',
          [roleId]
        );
        const role = roleResult.rows[0];
        if (!role) throw new Error('Rol bulunamadı');
        if (role.name === 'admin') throw new Error('Sistem rolü izinleri değiştirilemez');

        await client.query('DELETE FROM public.role_permissions WHERE role_id = $1::uuid', [roleId]);
        if (permissionKeys.length > 0) {
          await client.query(
            `INSERT INTO public.role_permissions (role_id, permission_key)
             SELECT $1::uuid, keys.permission_key
             FROM unnest($2::text[]) AS keys(permission_key)`,
            [roleId, permissionKeys]
          );
        }
      });

      return json({ ok: true, permissionKeys });
    }

    if (action === 'admin-upsert-language') {
      if (!(await requireAdmin(userId))) return json({ error: { message: 'Forbidden' } }, 403);
      const payload = languagePayload(body);
      if ('error' in payload) return json({ error: { message: payload.error } }, 400);

      const language = await withTransaction(async (client) => {
        const result = await client.query(
          `INSERT INTO public.languages (code, name, direction, status, flag_code, is_default, updated_at)
           VALUES ($1, $2, $3, $4, $5, false, now())
           ON CONFLICT (code) DO UPDATE
           SET name = EXCLUDED.name,
               direction = EXCLUDED.direction,
               status = EXCLUDED.status,
               flag_code = EXCLUDED.flag_code,
               updated_at = now()
           RETURNING code, name, direction, status, flag_code, is_default`,
          [payload.code, payload.name, payload.direction, payload.status, payload.flagCode]
        );
        return result.rows[0];
      });

      return json({ ok: true, language });
    }

    if (action === 'admin-set-default-language') {
      if (!(await requireAdmin(userId))) return json({ error: { message: 'Forbidden' } }, 403);
      const code = cleanLanguageCode(body.code || body.languageCode);
      if (!code) return json({ error: { message: 'Dil kodu zorunlu' } }, 400);

      await withTransaction(async (client) => {
        const language = await assertLanguageExists(client, code);
        if (language.status !== 'active') throw new Error('Pasif dil varsayılan yapılamaz');
        await client.query('UPDATE public.languages SET is_default = false, updated_at = now() WHERE is_default IS TRUE');
        await client.query('UPDATE public.languages SET is_default = true, updated_at = now() WHERE code = $1', [code]);
      });

      return json({ ok: true, code });
    }

    if (action === 'admin-delete-language') {
      if (!(await requireAdmin(userId))) return json({ error: { message: 'Forbidden' } }, 403);
      const code = cleanLanguageCode(body.code || body.languageCode);
      if (!code) return json({ error: { message: 'Dil kodu zorunlu' } }, 400);
      if (CORE_LANGUAGE_CODES.has(code)) {
        return json({ error: { message: 'Türkçe, İngilizce ve Arapça silinemez' } }, 400);
      }

      await withTransaction(async (client) => {
        const language = await assertLanguageExists(client, code);
        if (language.is_default === true) throw new Error('Varsayılan dil silinemez');
        await client.query('DELETE FROM public.language_translations WHERE language_code = $1', [code]);
        await client.query('DELETE FROM public.languages WHERE code = $1', [code]);
      });

      return json({ ok: true, deletedCode: code });
    }

    if (action === 'admin-save-language-translations') {
      if (!(await requireAdmin(userId))) return json({ error: { message: 'Forbidden' } }, 403);
      const payload = languageTranslationsPayload(body);
      if ('error' in payload) return json({ error: { message: payload.error } }, 400);

      await withTransaction(async (client) => {
        await assertLanguageExists(client, payload.languageCode);
        await client.query('DELETE FROM public.language_translations WHERE language_code = $1', [payload.languageCode]);
        if (payload.keys.length > 0) {
          await client.query(
            `INSERT INTO public.language_translations (language_code, key, value, updated_at)
             SELECT $1::text, rows.key, rows.value, now()
             FROM unnest($2::text[], $3::text[]) AS rows(key, value)`,
            [payload.languageCode, payload.keys, payload.values]
          );
        }
      });

      return json({ ok: true, languageCode: payload.languageCode, count: payload.keys.length });
    }

    if (action === 'admin-import-language') {
      if (!(await requireAdmin(userId))) return json({ error: { message: 'Forbidden' } }, 403);
      const language = languagePayload(body.language || body.meta || body);
      if ('error' in language) return json({ error: { message: language.error } }, 400);
      const translations = languageTranslationsPayload({
        languageCode: language.code,
        translations: body.translations || {},
      });
      if ('error' in translations) return json({ error: { message: translations.error } }, 400);

      await withTransaction(async (client) => {
        await client.query(
          `INSERT INTO public.languages (code, name, direction, status, flag_code, is_default, updated_at)
           VALUES ($1, $2, $3, $4, $5, false, now())
           ON CONFLICT (code) DO UPDATE
           SET name = EXCLUDED.name,
               direction = EXCLUDED.direction,
               status = EXCLUDED.status,
               flag_code = EXCLUDED.flag_code,
               updated_at = now()`,
          [language.code, language.name, language.direction, language.status, language.flagCode]
        );
        await client.query('DELETE FROM public.language_translations WHERE language_code = $1', [language.code]);
        if (translations.keys.length > 0) {
          await client.query(
            `INSERT INTO public.language_translations (language_code, key, value, updated_at)
             SELECT $1::text, rows.key, rows.value, now()
             FROM unnest($2::text[], $3::text[]) AS rows(key, value)`,
            [language.code, translations.keys, translations.values]
          );
        }
      });

      return json({ ok: true, languageCode: language.code, count: translations.keys.length });
    }

    return json({ error: { message: 'Unsupported account action' } }, 400);
  } catch (error: any) {
    return json({ error: { message: error.message || 'Account action failed' } }, 500);
  }
};
