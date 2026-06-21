import type { APIRoute } from 'astro';
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
  }>(
    `SELECT id, username, full_name, avatar_url, cover_url, phone, address,
            role, email, status, city, auth_provider, auth_providers
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

  await withTransaction(async (client) => {
    const existingResult = await client.query(
      `SELECT username
       FROM public.profiles
       WHERE id = $1::uuid
       LIMIT 1`,
      [user.id],
    );
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
  });
  await markProfileSignedIn(user.id, {
    ipAddress: location.ip,
    signupCity: location.city,
  });
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

export const POST: APIRoute = async ({ request, clientAddress }) => {
  try {
    const body = await request.json();
    const action = cleanText(body.action);
    const location = getRequestLocation(request, clientAddress);

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

    if (action === 'signUpWithPassword') {
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
        return json(
          { data: { user: null, session: null, profile: null }, error: { message: 'Kayıt geçici olarak kilitli. Lütfen daha sonra tekrar deneyin.' } },
          429,
        );
      }

      if (!fullName || !email || !password || !city) {
        await recordLoginFailure('app-signup', attemptIdentifier, settings);
        return json(
          { data: { user: null, session: null, profile: null }, error: { message: 'Ad soyad, e-posta, şifre ve şehir zorunlu' } },
          400,
        );
      }
      if (!looksLikeEmail(email)) {
        await recordLoginFailure('app-signup', attemptIdentifier, settings);
        return json(
          { data: { user: null, session: null, profile: null }, error: { message: 'Geçerli bir e-posta girin' } },
          400,
        );
      }
      if (passwordAgain && password !== passwordAgain) {
        await recordLoginFailure('app-signup', attemptIdentifier, settings);
        return json(
          { data: { user: null, session: null, profile: null }, error: { message: 'Şifreler eşleşmiyor' } },
          400,
        );
      }
      const passwordError = validatePasswordWithSecuritySettings(password, settings);
      if (passwordError) {
        await recordLoginFailure('app-signup', attemptIdentifier, settings);
        return json(
          { data: { user: null, session: null, profile: null }, error: { message: passwordError } },
          400,
        );
      }

      let createdAuthUserId: string | null = null;
      let createdProfileId: string | null = null;
      try {
        const usernameBase = cleanSignupUsernameBase(fullName, email);
        const authUser = await withTransaction(async (client) => {
          await ensureSignupEmailAvailable(client, email);
          const username = await uniqueSignupUsername(client, usernameBase);
          const created = await adminCreateAuthUser({
            email,
            password,
            userMetadata: {
              full_name: fullName,
              username,
              email,
              city,
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
            [created.id, fullName, username, email, city, location.ip || '', signupCity || ''],
          );
          await setPasswordForUser(created.id, password, client);
          createdProfileId = created.id;
          return created;
        });

        const signInResult = await signInWithPassword(email, password);
        if (signInResult.error || !signInResult.data.session?.user?.id) {
          throw new Error(signInResult.error?.message || 'Kayıt oturumu oluşturulamadı');
        }
        await clearLoginFailures('app-signup', attemptIdentifier);
        await markProfileSignedIn(authUser.id, {
          ipAddress: location.ip,
          signupCity,
        });
        const profile = await profileForUser(authUser.id);
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
        await recordLoginFailure('app-signup', attemptIdentifier, settings);
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
