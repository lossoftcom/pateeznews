import type { APIRoute } from "astro";
import { getSessionFromRequest, json } from "@/lib/server/appDb";
import { dbQuery } from "@/lib/server/supabaseDb";
import { mapAppFeedItems } from "@/lib/server/appFeed";
import { dataService } from "@/services/dataService";

const POST_SEARCH_SELECT = `
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
  ) AS profiles
`;

const TEXT_ENTITY_MAP: Record<string, string> = {
  amp: "&",
  apos: "'",
  Ccedil: "Ç",
  ccedil: "ç",
  Gbreve: "Ğ",
  gbreve: "ğ",
  hellip: "...",
  Idot: "İ",
  imath: "ı",
  laquo: '"',
  ldquo: '"',
  lsquo: "'",
  nbsp: " ",
  Ouml: "Ö",
  ouml: "ö",
  quot: '"',
  raquo: '"',
  rdquo: '"',
  rsquo: "'",
  Scedil: "Ş",
  scedil: "ş",
  Uuml: "Ü",
  uuml: "ü",
};

const decodeTextCodePoint = (
  value: string,
  radix: number,
  fallback: string,
) => {
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
  const decodeOnce = (input: string) =>
    input
      .replace(
        /&([a-zA-Z][a-zA-Z0-9]+);/g,
        (match, entity: string) => TEXT_ENTITY_MAP[entity] ?? match,
      )
      .replace(/&#x([0-9a-fA-F]+);/g, (match, hex: string) =>
        decodeTextCodePoint(hex, 16, match),
      )
      .replace(/&#(\d+);/g, (match, decimal: string) =>
        decodeTextCodePoint(decimal, 10, match),
      );

  return decodeOnce(decodeOnce(String(value ?? "")))
    .replace(/\u00a0/g, " ")
    .trim();
};

const escapeLikePattern = (value: string) =>
  value.replace(/[!%_]/g, (match) => `!${match}`);

export const GET: APIRoute = async ({ url, request }) => {
  try {
    const q = String(url.searchParams.get("q") || "")
      .trim()
      .slice(0, 96);
    const lang = String(url.searchParams.get("lang") || "tr").trim() || "tr";
    if (q.length < 2) return json({ posts: [], profiles: [] });

    const like = `%${escapeLikePattern(q)}%`;
    const postsLimit = Math.min(
      Math.max(Number(url.searchParams.get("limit") || 12), 1),
      20,
    );
    const profilesLimit = Math.min(
      Math.max(Number(url.searchParams.get("profilesLimit") || 6), 1),
      12,
    );
    const [posts, profiles] = await Promise.all([
      dbQuery(
        `WITH input AS (
           SELECT
             $1::text AS q,
             $2::text AS like_query,
             websearch_to_tsquery('turkish', unaccent($1::text)) AS tsq
         ),
         ranked AS (
           SELECT
             ${POST_SEARCH_SELECT},
             CASE
               WHEN numnode(input.tsq) > 0
               THEN ts_rank_cd(COALESCE(p.search_vector, ''::tsvector), input.tsq)
               ELSE 0
             END AS search_rank,
             GREATEST(
               similarity(COALESCE(p.title, ''), input.q),
               similarity(COALESCE(p.summary, ''), input.q),
               similarity(COALESCE(p.category, ''), input.q),
               similarity(COALESCE(p.keywords, ''), input.q),
               similarity(COALESCE(p.slug, ''), input.q)
             ) AS typo_rank,
             CASE WHEN COALESCE(p.title, '') ILIKE input.like_query ESCAPE '!' THEN 1 ELSE 0 END AS title_exact
           FROM public.posts p
           LEFT JOIN public.profiles pr ON pr.id = p.publisher_id
           CROSS JOIN input
           WHERE p.status = 'published'
             AND p.language_code = $3
             AND (p.published_at <= now() OR p.published_at IS NULL)
             AND (
               (numnode(input.tsq) > 0 AND COALESCE(p.search_vector, ''::tsvector) @@ input.tsq)
               OR COALESCE(p.title, '') ILIKE input.like_query ESCAPE '!'
               OR COALESCE(p.summary, '') ILIKE input.like_query ESCAPE '!'
               OR COALESCE(p.category, '') ILIKE input.like_query ESCAPE '!'
               OR COALESCE(p.keywords, '') ILIKE input.like_query ESCAPE '!'
               OR COALESCE(p.slug, '') ILIKE input.like_query ESCAPE '!'
               OR COALESCE(p.title, '') % input.q
               OR COALESCE(p.summary, '') % input.q
               OR COALESCE(p.category, '') % input.q
               OR COALESCE(p.keywords, '') % input.q
               OR COALESCE(p.slug, '') % input.q
             )
         )
         SELECT *
         FROM ranked
         ORDER BY
           (title_exact * 8) + (search_rank * 12) + (typo_rank * 4) DESC,
           published_at DESC NULLS LAST,
           created_at DESC NULLS LAST,
           id DESC
         LIMIT $4`,
        [q, like, lang, postsLimit],
      ),
      dbQuery(
        `WITH input AS (
           SELECT
             $1::text AS q,
             $2::text AS like_query,
             websearch_to_tsquery('turkish', unaccent($1::text)) AS tsq
         ),
         ranked AS (
           SELECT
             p.id,
             p.username,
             p.full_name,
             p.avatar_url,
             p.role,
             p.expertise,
             CASE
               WHEN numnode(input.tsq) > 0
               THEN ts_rank_cd(COALESCE(p.search_vector, ''::tsvector), input.tsq)
               ELSE 0
             END AS search_rank,
             GREATEST(
               similarity(COALESCE(p.username, ''), input.q),
               similarity(COALESCE(p.full_name, ''), input.q),
               similarity(COALESCE(p.expertise, ''), input.q)
             ) AS typo_rank,
             CASE
               WHEN COALESCE(p.username, '') ILIKE input.like_query ESCAPE '!'
                 OR COALESCE(p.full_name, '') ILIKE input.like_query ESCAPE '!'
               THEN 1
               ELSE 0
             END AS name_exact
           FROM public.profiles p
           CROSS JOIN input
           WHERE COALESCE(p.status, 'Aktif') = 'Aktif'
             AND (
               (numnode(input.tsq) > 0 AND COALESCE(p.search_vector, ''::tsvector) @@ input.tsq)
               OR COALESCE(p.username, '') ILIKE input.like_query ESCAPE '!'
               OR COALESCE(p.full_name, '') ILIKE input.like_query ESCAPE '!'
               OR COALESCE(p.expertise, '') ILIKE input.like_query ESCAPE '!'
               OR COALESCE(p.about_me, '') ILIKE input.like_query ESCAPE '!'
               OR COALESCE(p.username, '') % input.q
               OR COALESCE(p.full_name, '') % input.q
               OR COALESCE(p.expertise, '') % input.q
             )
         )
         SELECT id, username, full_name, avatar_url, role, expertise
         FROM ranked
         ORDER BY
           (name_exact * 8) + (search_rank * 10) + (typo_rank * 4) DESC,
           full_name ASC NULLS LAST,
           username ASC NULLS LAST
         LIMIT $3`,
        [q, like, profilesLimit],
      ),
    ]);

    const origin = new URL(request.url).origin;
    const session = await getSessionFromRequest(request).catch(() => null);
    const mappedPosts = await mapAppFeedItems(
      posts.rows.map((post: any) => dataService.mapPost(post)),
      origin,
      session?.user?.id || null,
    );

    return json({
      posts: mappedPosts.map((post: any) => ({
        ...post,
        title: decodeTextEntities(post.title),
        summary: decodeTextEntities(post.summary),
        category: decodeTextEntities(post.category),
        thumbnail_url: post.imageUrl || post.thumbnail_url || "",
        published_at: post.publishedAt || post.published_at || "",
      })),
      profiles: profiles.rows.map((profile: any) => ({
        ...profile,
        full_name: decodeTextEntities(profile.full_name),
        expertise: decodeTextEntities(profile.expertise),
      })),
    });
  } catch (error: any) {
    return json({ error: { message: error.message || "Search failed" } }, 500);
  }
};
