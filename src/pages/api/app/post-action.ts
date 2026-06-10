import type { APIRoute } from 'astro';
import {
  ensureAppSchema,
  getSessionFromRequest,
  json,
  withTransaction,
} from '@/lib/server/appDb';
import { dbQuery, type DatabaseClient } from '@/lib/server/supabaseDb';

const numericPostId = (value: unknown) => {
  const id = Number(value);
  return Number.isInteger(id) && id > 0 ? id : null;
};

const positiveInt = (value: unknown) => {
  const number = Number(value);
  return Number.isFinite(number) && number >= 0 ? Math.round(number) : null;
};

const cleanSource = (value: unknown, fallback: string) => {
  const source = String(value || fallback)
    .trim()
    .toLowerCase()
    .replace(/[^a-z0-9_:-]+/g, '_')
    .replace(/^_+|_+$/g, '')
    .slice(0, 60);
  return source || fallback;
};

const cleanVideoUrl = (value: unknown) => String(value || '').trim().slice(0, 2048);

async function sha256Hex(value: string) {
  const hash = await crypto.subtle.digest('SHA-256', new TextEncoder().encode(value));
  return Array.from(new Uint8Array(hash))
    .map((byte) => byte.toString(16).padStart(2, '0'))
    .join('');
}

function fallbackViewerSeed(request: Request) {
  const forwardedFor =
    request.headers.get('cf-connecting-ip') ||
    request.headers.get('x-real-ip') ||
    request.headers.get('x-forwarded-for') ||
    '';
  const userAgent = request.headers.get('user-agent') || '';
  return `fallback:${forwardedFor.split(',')[0].trim()}:${userAgent}`;
}

async function viewerKeyFromRequest(request: Request, body: Record<string, any>, userId?: string | null) {
  if (userId) return `user:${(await sha256Hex(userId)).slice(0, 64)}`;
  const viewerId = String(body.viewerId || body.clientViewerId || '').trim();
  const seed = viewerId.length >= 8 ? `anon:${viewerId}` : fallbackViewerSeed(request);
  return `anon:${(await sha256Hex(seed)).slice(0, 64)}`;
}

async function recordReadEvent(
  client: DatabaseClient,
  {
    postId,
    userId,
    viewerKey,
    source,
  }: {
    postId: number;
    userId: string | null;
    viewerKey: string;
    source: string;
  }
) {
  const result = await client.query<{ counted: boolean }>(
    `WITH inserted AS (
       INSERT INTO public.post_read_events (post_id, user_id, viewer_key, source)
       VALUES ($1, $2, $3, $4)
       ON CONFLICT (post_id, viewer_key, counted_on) DO NOTHING
       RETURNING id
     ),
     updated AS (
       UPDATE public.posts
       SET views_count = COALESCE(views_count, 0) + 1
       WHERE id = $1
         AND EXISTS (SELECT 1 FROM inserted)
       RETURNING views_count
     )
     SELECT EXISTS (SELECT 1 FROM inserted) AS counted`,
    [postId, userId, viewerKey, source]
  );
  return Boolean(result.rows[0]?.counted);
}

async function readState(postId: number, userId?: string | null, publisherId?: string | null) {
  const [postRes, savesRes, reactionRes] = await Promise.all([
    dbQuery(
      `SELECT likes_count, dislikes_count, shares_count, views_count, saves_count
       FROM public.posts
       WHERE id = $1
       LIMIT 1`,
      [postId]
    ),
    dbQuery<{ count: string }>('SELECT COUNT(*)::bigint AS count FROM public.post_saves WHERE post_id = $1', [postId]),
    dbQuery<{ reaction: string; count: string }>(
      'SELECT reaction, COUNT(*)::bigint AS count FROM public.post_reactions WHERE post_id = $1 GROUP BY reaction',
      [postId]
    ),
  ]);

  const post = postRes.rows[0] || {};
  const reactions = Object.fromEntries(reactionRes.rows.map((row: { reaction: string; count: string }) => [row.reaction, Number(row.count || 0)]));

  let userState = {
    liked: false,
    disliked: false,
    saved: false,
    following: false,
    reactions: [] as string[],
  };

  if (userId) {
    const [likeRes, dislikeRes, saveRes, followRes, userReactionRes] = await Promise.all([
      dbQuery('SELECT id FROM public.post_likes WHERE post_id = $1 AND user_id = $2 LIMIT 1', [postId, userId]),
      dbQuery('SELECT id FROM public.post_dislikes WHERE post_id = $1 AND user_id = $2 LIMIT 1', [postId, userId]),
      dbQuery('SELECT id FROM public.post_saves WHERE post_id = $1 AND user_id = $2 LIMIT 1', [postId, userId]),
      publisherId
        ? dbQuery('SELECT id FROM public.publisher_follows WHERE publisher_id = $1 AND user_id = $2 LIMIT 1', [publisherId, userId])
        : Promise.resolve({ rows: [] } as any),
      dbQuery<{ reaction: string }>('SELECT reaction FROM public.post_reactions WHERE post_id = $1 AND user_id = $2', [postId, userId]),
    ]);

    userState = {
      liked: !!likeRes.rows[0],
      disliked: !!dislikeRes.rows[0],
      saved: !!saveRes.rows[0],
      following: !!followRes.rows[0],
      reactions: userReactionRes.rows.map((row: { reaction: string }) => row.reaction),
    };
  }

  return {
    counts: {
      likes: Number(post.likes_count || 0),
      dislikes: Number(post.dislikes_count || 0),
      shares: Number(post.shares_count || 0),
      views: Number(post.views_count || 0),
      saves: Number(post.saves_count ?? savesRes.rows[0]?.count ?? 0),
    },
    reactions,
    userState,
  };
}

export const POST: APIRoute = async ({ request }) => {
  try {
    const body = await request.json();
    await ensureAppSchema();

    const action = String(body.action || '');
    const session = await getSessionFromRequest(request, body);
    const userId = session?.user?.id || null;
    const postId = numericPostId(body.postId);
    const publisherId = body.publisherId ? String(body.publisherId) : null;

    if (action === 'toggle_follow') {
      if (!userId) return json({ error: { message: 'Auth required' } }, 401);
      if (!publisherId) return json({ error: { message: 'Publisher missing' } }, 400);
      if (publisherId === userId) return json({ error: { message: 'Kendi profilinizi takip edemezsiniz' } }, 400);

      const result = await withTransaction(async (client) => {
        const existing = await client.query(
          'SELECT id FROM public.publisher_follows WHERE publisher_id = $1 AND user_id = $2 LIMIT 1',
          [publisherId, userId]
        );
        if (existing.rows[0]) {
          await client.query('DELETE FROM public.publisher_follows WHERE publisher_id = $1 AND user_id = $2', [publisherId, userId]);
          return { following: false };
        }
        await client.query(
          'INSERT INTO public.publisher_follows (publisher_id, user_id) VALUES ($1, $2) ON CONFLICT DO NOTHING',
          [publisherId, userId]
        );
        return { following: true };
      });

      return json({ ok: true, ...result });
    }

    if (!postId) return json({ error: { message: 'Post missing' } }, 400);

    if (action === 'state') {
      return json({ ok: true, ...(await readState(postId, userId, publisherId)) });
    }

    if (action === 'view') {
      const viewerKey = await viewerKeyFromRequest(request, body, userId);
      const source = cleanSource(body.source, 'read');
      const counted = await withTransaction((client) =>
        recordReadEvent(client, { postId, userId, viewerKey, source })
      );
      return json({ ok: true, counted, ...(await readState(postId, userId, publisherId)) });
    }

    if (action === 'video_view') {
      const viewerKey = await viewerKeyFromRequest(request, body, userId);
      const source = cleanSource(body.source, 'video');
      const videoUrl = cleanVideoUrl(body.videoUrl);
      const videoKey = await sha256Hex(videoUrl || `post:${postId}`);
      const watchedSeconds = positiveInt(body.watchedSeconds) ?? 0;
      const durationSeconds = positiveInt(body.durationSeconds);
      const thresholdSeconds = positiveInt(body.thresholdSeconds);
      const counted = await withTransaction(async (client) => {
        await client.query(
          `INSERT INTO public.post_video_views (
             post_id,
             user_id,
             viewer_key,
             video_key,
             video_url,
             source,
             watched_seconds,
             duration_seconds,
             threshold_seconds,
             counted
           )
           VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, true)
           ON CONFLICT (post_id, viewer_key, video_key, counted_on)
           DO UPDATE SET
             user_id = COALESCE(EXCLUDED.user_id, public.post_video_views.user_id),
             source = EXCLUDED.source,
             watched_seconds = GREATEST(public.post_video_views.watched_seconds, EXCLUDED.watched_seconds),
             duration_seconds = COALESCE(EXCLUDED.duration_seconds, public.post_video_views.duration_seconds),
             threshold_seconds = COALESCE(EXCLUDED.threshold_seconds, public.post_video_views.threshold_seconds),
             counted = public.post_video_views.counted OR EXCLUDED.counted,
             updated_at = now()`,
          [
            postId,
            userId,
            viewerKey,
            videoKey,
            videoUrl,
            source,
            watchedSeconds,
            durationSeconds,
            thresholdSeconds,
          ]
        );
        return recordReadEvent(client, { postId, userId, viewerKey, source });
      });
      return json({ ok: true, counted, ...(await readState(postId, userId, publisherId)) });
    }

    if (action === 'share') {
      const platform = String(body.platform || 'share').slice(0, 50);
      await withTransaction(async (client) => {
        await client.query(
          'INSERT INTO public.post_shares (post_id, user_id, platform) VALUES ($1, $2, $3)',
          [postId, userId, platform]
        );
        await client.query('UPDATE public.posts SET shares_count = COALESCE(shares_count, 0) + 1 WHERE id = $1', [postId]);
      });
      return json({ ok: true, ...(await readState(postId, userId, publisherId)) });
    }

    if (!userId) return json({ error: { message: 'Auth required' } }, 401);

    if (action === 'toggle_like' || action === 'toggle_dislike') {
      const targetTable = action === 'toggle_like' ? 'post_likes' : 'post_dislikes';
      const oppositeTable = action === 'toggle_like' ? 'post_dislikes' : 'post_likes';

      await withTransaction(async (client) => {
        const existing = await client.query(
          `SELECT id FROM public.${targetTable} WHERE post_id = $1 AND user_id = $2 LIMIT 1`,
          [postId, userId]
        );

        if (existing.rows[0]) {
          await client.query(`DELETE FROM public.${targetTable} WHERE post_id = $1 AND user_id = $2`, [postId, userId]);
        } else {
          await client.query(
            `INSERT INTO public.${targetTable} (post_id, user_id) VALUES ($1, $2) ON CONFLICT DO NOTHING`,
            [postId, userId]
          );
          await client.query(`DELETE FROM public.${oppositeTable} WHERE post_id = $1 AND user_id = $2`, [postId, userId]);
        }

        await client.query(
          `UPDATE public.posts
           SET likes_count = (SELECT COUNT(*)::int FROM public.post_likes WHERE post_id = $1),
               dislikes_count = (SELECT COUNT(*)::int FROM public.post_dislikes WHERE post_id = $1)
           WHERE id = $1`,
          [postId]
        );
      });

      return json({ ok: true, ...(await readState(postId, userId, publisherId)) });
    }

    if (action === 'toggle_save') {
      await withTransaction(async (client) => {
        const existing = await client.query(
          'SELECT id FROM public.post_saves WHERE post_id = $1 AND user_id = $2 LIMIT 1',
          [postId, userId]
        );
        if (existing.rows[0]) {
          await client.query('DELETE FROM public.post_saves WHERE post_id = $1 AND user_id = $2', [postId, userId]);
        } else {
          await client.query(
            'INSERT INTO public.post_saves (post_id, user_id) VALUES ($1, $2) ON CONFLICT DO NOTHING',
            [postId, userId]
          );
        }
        await client.query(
          'UPDATE public.posts SET saves_count = (SELECT COUNT(*)::int FROM public.post_saves WHERE post_id = $1) WHERE id = $1',
          [postId]
        );
      });

      return json({ ok: true, ...(await readState(postId, userId, publisherId)) });
    }

    if (action === 'toggle_reaction') {
      const reaction = String(body.reaction || '').trim().slice(0, 40);
      if (!reaction) return json({ error: { message: 'Reaction missing' } }, 400);

      await withTransaction(async (client) => {
        const existing = await client.query(
          'SELECT id FROM public.post_reactions WHERE post_id = $1 AND user_id = $2 AND reaction = $3 LIMIT 1',
          [postId, userId, reaction]
        );
        if (existing.rows[0]) {
          await client.query(
            'DELETE FROM public.post_reactions WHERE post_id = $1 AND user_id = $2 AND reaction = $3',
            [postId, userId, reaction]
          );
          return;
        }

        const count = await client.query<{ count: string }>(
          'SELECT COUNT(*)::bigint AS count FROM public.post_reactions WHERE post_id = $1 AND user_id = $2',
          [postId, userId]
        );
        if (Number(count.rows[0]?.count || 0) >= 3) throw new Error('Maximum reactions reached');

        await client.query(
          'INSERT INTO public.post_reactions (post_id, user_id, reaction) VALUES ($1, $2, $3) ON CONFLICT DO NOTHING',
          [postId, userId, reaction]
        );
      });

      return json({ ok: true, ...(await readState(postId, userId, publisherId)) });
    }

    return json({ error: { message: 'Unsupported action' } }, 400);
  } catch (error: any) {
    return json({ error: { message: error.message || 'Action failed' } }, 500);
  }
};
