import type { APIRoute } from 'astro';
import { json } from '@/lib/server/appDb';
import { dbQuery } from '@/lib/server/neonDb';

const TEXT_ENTITY_MAP: Record<string, string> = {
  amp: '&',
  apos: "'",
  Ccedil: 'Ç',
  ccedil: 'ç',
  Gbreve: 'Ğ',
  gbreve: 'ğ',
  hellip: '...',
  Idot: 'İ',
  imath: 'ı',
  laquo: '"',
  ldquo: '"',
  lsquo: "'",
  nbsp: ' ',
  Ouml: 'Ö',
  ouml: 'ö',
  quot: '"',
  raquo: '"',
  rdquo: '"',
  rsquo: "'",
  Scedil: 'Ş',
  scedil: 'ş',
  Uuml: 'Ü',
  uuml: 'ü',
};

const decodeTextCodePoint = (value: string, radix: number, fallback: string) => {
  const codePoint = Number.parseInt(value, radix);
  if (!Number.isFinite(codePoint) || codePoint <= 0) return fallback;
  if (codePoint === 60 || codePoint === 62) return fallback;
  try {
    return String.fromCodePoint(codePoint);
  } catch {
    return fallback;
  }
};

const decodeTextEntities = (value: unknown) => {
  const decodeOnce = (input: string) => input
    .replace(/&([a-zA-Z][a-zA-Z0-9]+);/g, (match, entity: string) => TEXT_ENTITY_MAP[entity] ?? match)
    .replace(/&#x([0-9a-fA-F]+);/g, (match, hex: string) => decodeTextCodePoint(hex, 16, match))
    .replace(/&#(\d+);/g, (match, decimal: string) => decodeTextCodePoint(decimal, 10, match));

  return decodeOnce(decodeOnce(String(value ?? ''))).replace(/\u00a0/g, ' ').trim();
};

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

    return json({
      posts: posts.rows.map((post: any) => ({
        ...post,
        title: decodeTextEntities(post.title),
        summary: decodeTextEntities(post.summary),
        category: decodeTextEntities(post.category),
      })),
      profiles: profiles.rows,
    });
  } catch (error: any) {
    return json({ error: { message: error.message || 'Search failed' } }, 500);
  }
};
