import type { APIRoute } from 'astro';
import { json } from '@/lib/server/appDb';
import { dbQuery } from '@/lib/server/neonDb';

export const GET: APIRoute = async ({ url }) => {
  try {
    const q = String(url.searchParams.get('q') || '').trim();
    const lang = String(url.searchParams.get('lang') || 'tr').trim() || 'tr';
    if (q.length < 2) return json({ posts: [], profiles: [] });

    const search = `%${q}%`;
    const [posts, profiles] = await Promise.all([
      dbQuery(
        `SELECT id, title, summary, slug, category, thumbnail_url, published_at
         FROM public.posts
         WHERE status = 'published'
           AND language_code = $2
           AND (title ILIKE $1 OR summary ILIKE $1 OR category ILIKE $1 OR keywords ILIKE $1)
         ORDER BY published_at DESC NULLS LAST, created_at DESC
         LIMIT 8`,
        [search, lang]
      ),
      dbQuery(
        `SELECT id, username, full_name, avatar_url, role
         FROM public.profiles
         WHERE username ILIKE $1 OR full_name ILIKE $1 OR expertise ILIKE $1
         ORDER BY updated_at DESC NULLS LAST
         LIMIT 5`,
        [search]
      ),
    ]);

    return json({ posts: posts.rows, profiles: profiles.rows });
  } catch (error: any) {
    return json({ error: { message: error.message || 'Search failed' } }, 500);
  }
};

