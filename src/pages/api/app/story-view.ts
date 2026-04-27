import type { APIRoute } from 'astro';
import { json } from '@/lib/server/appDb';
import { dbQuery } from '@/lib/server/neonDb';

export const POST: APIRoute = async ({ request }) => {
  try {
    const body = await request.json();
    const storyId = String(body.storyId || '').trim();
    if (!storyId) return json({ error: { message: 'Story missing' } }, 400);

    const result = await dbQuery<{ view_count: number }>(
      `UPDATE public.stories
       SET view_count = COALESCE(view_count, 0) + 1
       WHERE id = $1
       RETURNING view_count`,
      [storyId]
    );

    return json({ ok: true, viewCount: Number(result.rows[0]?.view_count || 0) });
  } catch (error: any) {
    return json({ error: { message: error.message || 'Story view failed' } }, 500);
  }
};

