import type { APIRoute } from 'astro';
import {
  ensureAppSchema,
  getSessionFromRequest,
  json,
  withTransaction,
} from '@/lib/server/appDb';
import { dbQuery } from '@/lib/server/neonDb';

const numericPostId = (value: unknown) => {
  const id = Number(value);
  return Number.isInteger(id) && id > 0 ? id : null;
};

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
      await dbQuery('UPDATE public.posts SET views_count = COALESCE(views_count, 0) + 1 WHERE id = $1', [postId]);
      return json({ ok: true, ...(await readState(postId, userId, publisherId)) });
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
