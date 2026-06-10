import type { APIRoute } from 'astro';
import { getSessionFromRequest, json, withTransaction } from '@/lib/server/appDb';
import { dataService } from '@/services/dataService.server';
import { mapAppFeedItems } from '@/lib/server/appFeed';
import { updateUser } from '@/lib/server/supabaseAuth';

const PROFILE_POST_SELECT = `
            p.id,
            p.created_at,
            p.published_at,
            p.updated_at,
            p.publisher_id,
            p.title,
            p.summary,
            p.category,
            p.type,
            p.thumbnail_url,
            p.thumbnail_alt,
            p.media_url,
            p.likes_count,
            p.dislikes_count,
            p.comments_count,
            p.shares_count,
            p.views_count,
            p.saves_count,
            p.slug,
            p.status,
            p.seo_title,
            p.seo_description,
            p.keywords,
            p.language_code,
            p.is_pinned,
            p.show_in_manset,
            p.fact_checked,
            p.schema_type,
            p.card_data,
            p.items,
            p.faq_data,
            json_build_object(
                'id', pr.id,
                'username', pr.username,
                'full_name', pr.full_name,
                'avatar_url', pr.avatar_url,
                'role', pr.role
            ) AS profiles`;

function cleanText(value: unknown) {
  return String(value || '').trim();
}

function cleanEmail(value: unknown) {
  return cleanText(value).toLowerCase();
}

function cleanUsername(value: unknown) {
  return cleanText(value).replace(/^@+/, '');
}

function cleanUuid(value: unknown) {
  const text = cleanText(value);
  return /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(text)
    ? text
    : '';
}

function nullableText(value: unknown, maxLength = 500) {
  const text = cleanText(value).slice(0, maxLength);
  return text || null;
}

function profileUrl(value: unknown) {
  const text = cleanText(value).slice(0, 1000);
  if (!text) return null;
  if (text.startsWith('/local-upload/profile/') || text.startsWith('/api/storage/file/profile/')) {
    return text;
  }
  try {
    const url = new URL(text);
    if (url.protocol === 'http:' || url.protocol === 'https:') return text;
  } catch {
    return null;
  }
  return null;
}

function socialLinks(value: unknown) {
  const input = value && typeof value === 'object' && !Array.isArray(value)
    ? value as Record<string, unknown>
    : {};
  const allowed = [
    'x',
    'instagram',
    'facebook',
    'youtube',
    'whatsapp',
    'linkedin',
    'tiktok',
    'pinterest',
    'snapchat',
    'telegram',
    'discord',
    'reddit',
    'bluesky',
    'twitch',
  ];
  const output: Record<string, string> = {};
  for (const key of allowed) {
    const text = cleanText(input[key]).slice(0, 500);
    if (text) output[key] = text;
  }
  return output;
}

function validEmail(value: string) {
  return /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(value);
}

function slugForUsername(username: string) {
  return username
    .toLowerCase()
    .replace(/[^a-z0-9._-]+/g, '-')
    .replace(/^-+|-+$/g, '')
    .slice(0, 80);
}

async function ensureUniqueProfileFields(
  client: any,
  input: { userId: string; email: string; username: string },
) {
  const conflict = await client.query(
    `SELECT id, username, email
       FROM public.profiles
      WHERE id <> $3::uuid
        AND (lower(username) = lower($1) OR lower(email) = lower($2))
      LIMIT 1`,
    [input.username, input.email, input.userId],
  );
  const row = conflict.rows[0];
  if (row?.username?.toLowerCase() === input.username.toLowerCase()) {
    throw new Error('Kullanıcı adı zaten kullanılıyor');
  }
  if (row?.email?.toLowerCase() === input.email.toLowerCase()) {
    throw new Error('E-posta zaten kullanılıyor');
  }
}

async function resolveProfileId(
  client: any,
  input: { userId?: string | null; username?: string | null; fallbackUserId?: string | null },
) {
  const userId = cleanUuid(input.userId);
  if (userId) return userId;
  const username = cleanUsername(input.username).slice(0, 80);
  if (username) {
    const result = await client.query(
      'SELECT id FROM public.profiles WHERE lower(username) = lower($1) LIMIT 1',
      [username],
    );
    return result.rows[0]?.id ? String(result.rows[0].id) : null;
  }
  return cleanUuid(input.fallbackUserId);
}

async function loadProfile(client: any, userId: string, origin: string, viewerId: string | null) {
  const profileResult = await client.query(
    `SELECT id, username, full_name, avatar_url, cover_url, role, status,
            reward_system, email, created_at, about_me, social_links,
            show_email, rss_feeds, expertise, website, address
       FROM public.profiles
      WHERE id = $1::uuid
      LIMIT 1`,
    [userId],
  );
  const profile = profileResult.rows[0] || null;
  if (!profile) return null;

  const [
    postsCount,
    followerCount,
    followingCount,
    followerAvatars,
    followingAvatars,
    likedPostsCount,
    commentsWrittenCount,
    viewerFollow,
    postRows,
  ] = await Promise.all([
    client.query(
      `SELECT COUNT(*)::int AS count
         FROM public.posts
        WHERE publisher_id = $1::uuid
          AND status = 'published'
          AND (published_at <= now() OR published_at IS NULL)`,
      [userId],
    ),
    client.query(
      'SELECT COUNT(*)::int AS count FROM public.publisher_follows WHERE publisher_id = $1::uuid',
      [userId],
    ),
    client.query(
      'SELECT COUNT(*)::int AS count FROM public.publisher_follows WHERE user_id = $1::uuid',
      [userId],
    ),
    client.query(
      `SELECT p.id, p.username, p.full_name, p.avatar_url, p.role
         FROM public.publisher_follows f
         JOIN public.profiles p ON p.id = f.user_id
        WHERE f.publisher_id = $1::uuid
        ORDER BY f.created_at DESC NULLS LAST
        LIMIT 5`,
      [userId],
    ),
    client.query(
      `SELECT p.id, p.username, p.full_name, p.avatar_url, p.role
         FROM public.publisher_follows f
         JOIN public.profiles p ON p.id = f.publisher_id
        WHERE f.user_id = $1::uuid
        ORDER BY f.created_at DESC NULLS LAST
       LIMIT 5`,
      [userId],
    ),
    client.query(
      'SELECT COUNT(*)::int AS count FROM public.post_likes WHERE user_id = $1::uuid',
      [userId],
    ),
    client.query(
      `SELECT COUNT(*)::int AS count
         FROM public.comments
        WHERE user_id = $1::uuid
          AND status = 'approved'`,
      [userId],
    ),
    viewerId && viewerId !== userId
      ? client.query(
          `SELECT EXISTS(
             SELECT 1
               FROM public.publisher_follows
              WHERE publisher_id = $1::uuid
                AND user_id = $2::uuid
           ) AS following`,
          [userId, viewerId],
        )
      : Promise.resolve({ rows: [{ following: false }] }),
    client.query(
      `SELECT ${PROFILE_POST_SELECT}
         FROM public.posts p
         LEFT JOIN public.profiles pr ON pr.id = p.publisher_id
        WHERE p.publisher_id = $1::uuid
          AND p.status = 'published'
          AND (p.published_at <= now() OR p.published_at IS NULL)
        ORDER BY p.published_at DESC NULLS LAST,
                 p.created_at DESC NULLS LAST,
                 p.id DESC
        LIMIT 20`,
      [userId],
    ),
  ]);

  const newsItems = postRows.rows.map((row: any) => dataService.mapPost(row));
  const posts = await mapAppFeedItems(newsItems, origin, viewerId);

  return {
    ...profile,
    is_own_profile: Boolean(viewerId && viewerId === userId),
    viewer_following: viewerFollow.rows[0]?.following === true,
    stats: {
      posts: Number(postsCount.rows[0]?.count || 0),
      followers: Number(followerCount.rows[0]?.count || 0),
      following: Number(followingCount.rows[0]?.count || 0),
      liked_posts: Number(likedPostsCount.rows[0]?.count || 0),
      comments: Number(commentsWrittenCount.rows[0]?.count || 0),
    },
    follower_avatars: followerAvatars.rows.map((row: any) => row.avatar_url).filter(Boolean),
    following_avatars: followingAvatars.rows.map((row: any) => row.avatar_url).filter(Boolean),
    follower_profiles: followerAvatars.rows,
    following_profiles: followingAvatars.rows,
    posts,
  };
}

async function currentEmail(client: any, userId: string) {
  const result = await client.query(
    'SELECT email FROM public.profiles WHERE id = $1::uuid LIMIT 1',
    [userId],
  );
  return cleanEmail(result.rows[0]?.email);
}

export const GET: APIRoute = async ({ request, url }) => {
  try {
    const session = await getSessionFromRequest(request);
    const viewerId = cleanUuid(session?.user?.id);
    const targetUserId = cleanUuid(url.searchParams.get('userId'));
    const targetUsername = cleanUsername(url.searchParams.get('username')).slice(0, 80);
    if (!viewerId && !targetUserId && !targetUsername) {
      return json({ error: { message: 'Auth required' } }, 401);
    }

    const profile = await withTransaction(async (client) => {
      const profileId = await resolveProfileId(client, {
        userId: targetUserId,
        username: targetUsername,
        fallbackUserId: viewerId,
      });
      if (!profileId) return null;
      return loadProfile(client, profileId, new URL(request.url).origin, viewerId || null);
    });
    if (!profile) return json({ error: { message: 'Profile not found' } }, 404);
    return json({ profile, languageCode: cleanText(url.searchParams.get('lang')) || 'tr' });
  } catch (error: any) {
    return json({ error: { message: error.message || 'Profile load failed' } }, 500);
  }
};

export const POST: APIRoute = async ({ request }) => {
  try {
    const body = await request.json();
    const action = cleanText(body.action);
    if (action !== 'update-profile') {
      return json({ error: { message: 'Unsupported profile action' } }, 400);
    }

    const session = await getSessionFromRequest(request, body);
    if (!session?.user?.id) return json({ error: { message: 'Auth required' } }, 401);

    const userId = session.user.id;
    const fullName = cleanText(body.fullName || body.full_name).slice(0, 160);
    const username = cleanUsername(body.username).slice(0, 80);
    const email = cleanEmail(body.email);
    if (!fullName || !username || !email) {
      return json({ error: { message: 'Ad soyad, kullanıcı adı ve e-posta zorunlu' } }, 400);
    }
    if (/\s/.test(username) || username.length < 3) {
      return json({ error: { message: 'Kullanıcı adı en az 3 karakter olmalı ve boşluk içermemeli' } }, 400);
    }
    if (!validEmail(email)) {
      return json({ error: { message: 'Geçerli bir e-posta girin' } }, 400);
    }

    const result = await withTransaction(async (client) => {
      await ensureUniqueProfileFields(client, { userId, email, username });
      const existingEmail = await currentEmail(client, userId);
      if (existingEmail && existingEmail !== email) {
        const authUpdate = await updateUser(session.access_token, { email });
        if (authUpdate.error) throw new Error(authUpdate.error.message || 'E-posta güncellenemedi');
      }

      const updateResult = await client.query(
        `UPDATE public.profiles
            SET full_name = $1,
                username = $2,
                email = $3,
                avatar_url = $4,
                cover_url = $5,
                expertise = $6,
                about_me = $7,
                website = $8,
                address = $9,
                social_links = $10::jsonb,
                show_email = $11,
                rss_feeds = $12,
                slug = $13,
                updated_at = now()
          WHERE id = $14::uuid
          RETURNING id`,
        [
          fullName,
          username,
          email,
          profileUrl(body.avatarUrl || body.avatar_url),
          profileUrl(body.coverUrl || body.cover_url),
          nullableText(body.expertise, 120),
          nullableText(body.aboutMe || body.about_me, 2000),
          nullableText(body.website, 500),
          nullableText(body.address, 500),
          JSON.stringify(socialLinks(body.socialLinks || body.social_links)),
          body.showEmail !== false && body.show_email !== false,
          body.rssFeeds !== false && body.rss_feeds !== false,
          slugForUsername(username),
          userId,
        ],
      );
      if (!updateResult.rows[0]) throw new Error('Profil bulunamadı');
      return loadProfile(client, userId, new URL(request.url).origin, userId);
    });

    return json({ ok: true, profile: result });
  } catch (error: any) {
    return json({ error: { message: error.message || 'Profile update failed' } }, 500);
  }
};
