import type { APIRoute } from "astro";
import { getSessionFromRequest, json, withTransaction } from "@/lib/server/appDb";
import { dbQuery } from "@/lib/server/supabaseDb";

export const prerender = false;

type PublicComment = {
  id: string;
  parentId: string;
  body: string;
  publishedAt: string;
  likes: number;
  userLiked: boolean;
  canDelete: boolean;
  author: {
    name: string;
    avatarUrl: string;
    handle: string;
    isVerified: boolean;
    isOfficial: boolean;
  };
  replies: PublicComment[];
};

const numericId = (value: unknown) => {
  const parsed = Number(value);
  return Number.isInteger(parsed) && parsed > 0 ? parsed : null;
};

const cleanText = (value: unknown, max = 2000) =>
  String(value || "").replace(/\s+/g, " ").trim().slice(0, max);

const cleanEmail = (value: unknown) => cleanText(value, 254).toLowerCase();

const looksLikeEmail = (value: string) => /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(value);

const resolveImageUrl = (url: string, base: string): string => {
  if (!url) return "";
  try {
    const parsed = new URL(url);
    if (parsed.protocol === "http:" || parsed.protocol === "https:") return url;
  } catch {
    // relative path
  }
  if (url.startsWith("/")) return `${base}${url}`;
  return url;
};

const toIsoDate = (value: unknown): string => {
  const date = value ? new Date(String(value)) : null;
  return date && !Number.isNaN(date.getTime())
    ? date.toISOString()
    : new Date().toISOString();
};

const authorName = (row: any) =>
  cleanText(row.user_full_name || row.user_name || row.guest_name || "Misafir", 80);

const authorHandle = (row: any) => {
  const username = cleanText(row.user_name, 60);
  return username ? (username.startsWith("@") ? username : `@${username}`) : "";
};

const isOfficialRole = (role: unknown) => {
  const value = String(role || "").trim().toLowerCase();
  return value === "admin" || value === "super_admin" || value === "editor";
};

const mapComment = (row: any, origin: string, userId: string | null): PublicComment => ({
  id: String(row.id || ""),
  parentId: String(row.parent_id || ""),
  body: cleanText(row.content, 2000),
  publishedAt: toIsoDate(row.created_at),
  likes: Number(row.likes_count || 0),
  userLiked: row.user_liked === true,
  canDelete: Boolean(userId && String(row.user_id || "") === userId),
  author: {
    name: authorName(row),
    avatarUrl: resolveImageUrl(String(row.user_avatar || ""), origin),
    handle: authorHandle(row),
    isVerified: Boolean(row.user_id),
    isOfficial: isOfficialRole(row.user_role),
  },
  replies: Array.isArray(row.replies)
    ? row.replies.map((reply: any) => mapComment(reply, origin, userId))
    : [],
});

async function readComments(
  postId: number,
  userId: string | null,
  limit: number,
  origin: string,
) {
  const safeLimit = Math.min(Math.max(limit || 2, 1), 20);
  const result = await dbQuery(
    `WITH root_comments AS (
       SELECT
         c.id, c.post_id, c.user_id, c.guest_name, c.parent_id, c.content,
         c.created_at, c.likes_count, c.is_pinned,
         p.username AS user_name, p.full_name AS user_full_name,
         p.avatar_url AS user_avatar, p.role AS user_role,
         EXISTS (
           SELECT 1
           FROM public.comment_likes cl
           WHERE cl.comment_id = c.id
             AND cl.user_id = $2::uuid
         ) AS user_liked
       FROM public.comments c
       LEFT JOIN public.profiles p ON p.id = c.user_id
       WHERE c.post_id = $1
         AND c.status = 'approved'
         AND c.parent_id IS NULL
       ORDER BY c.is_pinned DESC, c.created_at ASC, c.id ASC
       LIMIT $3
     )
     SELECT
       rc.*,
       COALESCE((
         SELECT json_agg(reply_row ORDER BY (reply_row->>'created_at') ASC)
         FROM (
           SELECT json_build_object(
             'id', r.id,
             'post_id', r.post_id,
             'user_id', r.user_id,
             'guest_name', r.guest_name,
             'parent_id', r.parent_id,
             'content', r.content,
             'created_at', r.created_at,
             'likes_count', r.likes_count,
             'user_name', rp.username,
             'user_full_name', rp.full_name,
             'user_avatar', rp.avatar_url,
             'user_role', rp.role,
	             'user_liked', EXISTS (
	               SELECT 1
	               FROM public.comment_likes rcl
	               WHERE rcl.comment_id = r.id
	                 AND rcl.user_id = $2::uuid
	             ),
	             'replies', COALESCE((
	               SELECT json_agg(nested_row ORDER BY (nested_row->>'created_at') ASC)
	               FROM (
	                 SELECT json_build_object(
	                   'id', nr.id,
	                   'post_id', nr.post_id,
	                   'user_id', nr.user_id,
	                   'guest_name', nr.guest_name,
	                   'parent_id', nr.parent_id,
	                   'content', nr.content,
	                   'created_at', nr.created_at,
	                   'likes_count', nr.likes_count,
	                   'user_name', np.username,
	                   'user_full_name', np.full_name,
	                   'user_avatar', np.avatar_url,
	                   'user_role', np.role,
	                   'user_liked', EXISTS (
	                     SELECT 1
	                     FROM public.comment_likes ncl
	                     WHERE ncl.comment_id = nr.id
	                       AND ncl.user_id = $2::uuid
	                   ),
	                   'replies', '[]'::json
	                 ) AS nested_row
	                 FROM public.comments nr
	                 LEFT JOIN public.profiles np ON np.id = nr.user_id
	                 WHERE nr.parent_id = r.id
	                   AND nr.status = 'approved'
	                 ORDER BY nr.is_pinned DESC, nr.created_at ASC, nr.id ASC
	                 LIMIT 1
	               ) nested_replies
	             ), '[]'::json)
	           ) AS reply_row
           FROM public.comments r
           LEFT JOIN public.profiles rp ON rp.id = r.user_id
           WHERE r.parent_id = rc.id
             AND r.status = 'approved'
           ORDER BY r.is_pinned DESC, r.created_at ASC, r.id ASC
           LIMIT 1
         ) replies
       ), '[]'::json) AS replies
     FROM root_comments rc`,
    [postId, userId, safeLimit],
  );
  return result.rows.map((row) => mapComment(row, origin, userId));
}

async function assertParentBelongsToPost(parentId: number | null, postId: number) {
  if (!parentId) return;
  const result = await dbQuery(
    `SELECT c.id, c.parent_id, parent.parent_id AS grand_parent_id
     FROM public.comments c
     LEFT JOIN public.comments parent ON parent.id = c.parent_id
     WHERE c.id = $1 AND c.post_id = $2
     LIMIT 1`,
    [parentId, postId],
  );
  const row = result.rows[0];
  if (!row) {
    throw Object.assign(new Error("Yanıtlanacak yorum bulunamadı"), { status: 400 });
  }
  if (row.parent_id && row.grand_parent_id) {
    throw Object.assign(new Error("Bu yanıta daha fazla yanıt eklenemez"), { status: 400 });
  }
}

export const POST: APIRoute = async ({ request }) => {
  try {
    const body = await request.json();
    const origin = new URL(request.url).origin;
    const action = cleanText(body.action, 40);
    const postId = numericId(body.postId);
    if (!postId) return json({ error: { message: "Post missing" } }, 400);

    const session = await getSessionFromRequest(request, body);
    const userId = session?.user?.id || null;
    const limit = Number(body.limit || 2);

    if (action === "list") {
      return json({
        ok: true,
        comments: await readComments(postId, userId, limit, origin),
      });
    }

    if (action === "submit") {
      const content = cleanText(body.content, 2000);
      if (!content) return json({ error: { message: "Yorum boş olamaz" } }, 400);

      const guestName = userId ? "" : cleanText(body.guestName, 80);
      const guestEmail = userId ? "" : cleanEmail(body.guestEmail);
      if (!userId && (!guestName || !looksLikeEmail(guestEmail))) {
        return json({ error: { message: "Ad soyad ve geçerli e-posta gerekli" } }, 400);
      }

      const parentId = numericId(body.parentId);
      await assertParentBelongsToPost(parentId, postId);

      await withTransaction(async (client) => {
        await client.query(
          `INSERT INTO public.comments
             (post_id, user_id, guest_name, guest_email, parent_id, content, status)
           VALUES ($1, $2, $3, $4, $5, $6, 'pending')`,
          [
            postId,
            userId,
            userId ? null : guestName,
            userId ? null : guestEmail,
            parentId,
            content,
          ],
        );
      });

      return json({
        ok: true,
        status: "pending",
        comments: await readComments(postId, userId, limit, origin),
      });
    }

    if (action === "toggle_like") {
      if (!userId) return json({ error: { message: "Auth required" } }, 401);
      const commentId = numericId(body.commentId);
      if (!commentId) return json({ error: { message: "Comment missing" } }, 400);

      await withTransaction(async (client) => {
        const existing = await client.query(
          "SELECT id FROM public.comment_likes WHERE comment_id = $1 AND user_id = $2 LIMIT 1",
          [commentId, userId],
        );
        if (existing.rows[0]) {
          await client.query(
            "DELETE FROM public.comment_likes WHERE comment_id = $1 AND user_id = $2",
            [commentId, userId],
          );
        } else {
          await client.query(
            "INSERT INTO public.comment_likes (comment_id, user_id) VALUES ($1, $2) ON CONFLICT DO NOTHING",
            [commentId, userId],
          );
        }
        await client.query(
          `UPDATE public.comments
           SET likes_count = (
             SELECT COUNT(*)::int
             FROM public.comment_likes
             WHERE comment_id = $1
           )
           WHERE id = $1 AND post_id = $2`,
          [commentId, postId],
        );
      });

      return json({
        ok: true,
        comments: await readComments(postId, userId, limit, origin),
      });
    }

    if (action === "delete") {
      if (!userId) return json({ error: { message: "Auth required" } }, 401);
      const commentId = numericId(body.commentId);
      if (!commentId) return json({ error: { message: "Comment missing" } }, 400);

      await withTransaction(async (client) => {
        const deleted = await client.query(
          `DELETE FROM public.comments
           WHERE id = $1
             AND post_id = $2
             AND user_id = $3::uuid
           RETURNING id`,
          [commentId, postId, userId],
        );
        if (!deleted.rows[0]) {
          throw Object.assign(new Error("Bu yorumu silemezsiniz"), { status: 403 });
        }
      });

      return json({
        ok: true,
        comments: await readComments(postId, userId, limit, origin),
      });
    }

    return json({ error: { message: "Unsupported action" } }, 400);
  } catch (error: any) {
    return json(
      { error: { message: error?.message || "Comments request failed" } },
      Number(error?.status || 500),
    );
  }
};
