import { exactLocalStaticPath } from "@/lib/server/localUploadStorage";
import { dbQuery } from "@/lib/server/supabaseDb";
import {
  LOCAL_VARIANT_PREFIXES,
  TRANSFORMABLE_IMAGE_EXTENSIONS,
  nearestVariantWidth,
  objectExtension,
  variantObjectPath,
} from "@/lib/server/imageVariants";
import type { NewsItem, OptimizedImage } from "@/types";

type ImageVariantOptions = {
  width?: number;
  quality?: number;
};

const LOCAL_IMAGE_PATH_PREFIXES = ["/api/storage/file/", "/local-upload/"];
const VIDEO_THUMB_EXTENSIONS = [".webp", ".jpg", ".jpeg", ".png"];
const VIDEO_THUMB_FIELDS = [
  "thumbnailUrl",
  "thumbUrl",
  "posterUrl",
  "videoThumbUrl",
  "mediaThumbUrl",
  "thumbnail",
  "thumb",
  "poster",
];

const withLocalImageVariant = (
  resolvedUrl: string,
  base: string,
  options: ImageVariantOptions = {},
): string => {
  const width = Math.round(Number(options.width || 0));
  if (!resolvedUrl || width <= 0) return resolvedUrl;

  try {
    const baseUrl = new URL(base);
    const parsed = new URL(resolvedUrl, baseUrl);
    if (parsed.origin !== baseUrl.origin) return resolvedUrl;
    if (
      !LOCAL_IMAGE_PATH_PREFIXES.some((prefix) =>
        parsed.pathname.startsWith(prefix),
      )
    ) {
      return resolvedUrl;
    }

    // "/api/storage/file/image/.." veya "/local-upload/image/.." -> "image/.."
    const objectPath = parsed.pathname
      .replace(/^\/api\/storage\/file\//, "")
      .replace(/^\/local-upload\//, "");
    const extension = objectExtension(objectPath);
    const isVariantEligible =
      LOCAL_VARIANT_PREFIXES.some((prefix) => objectPath.startsWith(prefix)) &&
      TRANSFORMABLE_IMAGE_EXTENSIONS.has(extension);

    if (isVariantEligible) {
      // Doğrudan statik varyant: tek istek, CDN'den, redirect yok.
      const target = nearestVariantWidth(Math.min(Math.max(width, 64), 3840));
      const variantPath = variantObjectPath(objectPath, target);
      return new URL(`/local-upload/${variantPath}`, baseUrl).toString();
    }

    // Diğer durumlar (ör. cdn-cgi yolu gereken haller) eski davranışta kalır.
    parsed.searchParams.set("w", String(Math.min(Math.max(width, 64), 3840)));
    const quality = Math.round(Number(options.quality || 0));
    if (quality > 0) {
      parsed.searchParams.set("q", String(Math.min(Math.max(quality, 40), 95)));
    }
    return parsed.toString();
  } catch {
    return resolvedUrl;
  }
};

export const resolveAppImageUrl = (
  url: string,
  base: string,
  options: ImageVariantOptions = {},
): string => {
  if (!url) return "";
  let resolved = url;
  try {
    const parsed = new URL(url);
    if (parsed.protocol !== "http:" && parsed.protocol !== "https:") return url;
  } catch {
    if (url.startsWith("/")) resolved = `${base}${url}`;
  }
  return withLocalImageVariant(resolved, base, options);
};

export const getNewsTime = (item: NewsItem): number => {
  const date = new Date(item.timestamp || "");
  return Number.isNaN(date.getTime()) ? 0 : date.getTime();
};

const imageAspectRatio = (image?: OptimizedImage): number | undefined => {
  const width = Number(image?.width || 0);
  const height = Number(image?.height || 0);
  if (
    !Number.isFinite(width) ||
    !Number.isFinite(height) ||
    width <= 0 ||
    height <= 0
  ) {
    return undefined;
  }
  return width / height;
};

const firstMediaUrl = (item: NewsItem): string => {
  const mediaListItem = Array.isArray(item.mediaList)
    ? item.mediaList.find((media) => String(media || "").trim())
    : "";
  return String(
    item.optimizedCoverThumbnail?.src ||
      item.optimizedThumbnail?.src ||
      item.coverThumbnail ||
      item.thumbnail ||
      mediaListItem ||
      item.mediaUrl ||
      "",
  );
};

type VideoMediaItem = {
  url: string;
  thumbUrl: string;
};

const youtubeThumbUrl = (url: string): string => {
  const id = youtubeIdFrom(url);
  return id ? `https://img.youtube.com/vi/${id}/hqdefault.jpg` : "";
};

const youtubeIdFrom = (url: string): string => {
  const raw = String(url || "").trim();
  if (/^[_\-a-zA-Z0-9]{11}$/.test(raw)) return raw;
  let parsed: URL;
  try {
    parsed = new URL(raw);
  } catch {
    try {
      parsed = new URL(`https://${raw}`);
    } catch {
      return "";
    }
  }
  const host = parsed.hostname.toLowerCase();
  if (
    !host.includes("youtube.com") &&
    !host.includes("youtu.be") &&
    !host.includes("youtube-nocookie.com")
  ) {
    return "";
  }
  if (host.includes("youtu.be")) {
    return cleanYoutubeId(parsed.pathname.split("/").filter(Boolean)[0]);
  }
  const fromQuery = cleanYoutubeId(parsed.searchParams.get("v") || "");
  if (fromQuery) return fromQuery;
  const segments = parsed.pathname.split("/").filter(Boolean);
  for (let index = 0; index < segments.length - 1; index += 1) {
    const segment = segments[index].toLowerCase();
    if (segment === "shorts" || segment === "embed" || segment === "live") {
      return cleanYoutubeId(segments[index + 1]);
    }
  }
  return "";
};

const cleanYoutubeId = (value: string): string => {
  const match = String(value || "").match(/[_\-a-zA-Z0-9]{11}/);
  return match?.[0] || "";
};

const localVideoThumbUrl = (videoUrl: string, origin: string): string => {
  let parsed: URL;
  let originUrl: URL;
  try {
    originUrl = new URL(origin);
    parsed = new URL(videoUrl, originUrl);
  } catch {
    return "";
  }
  if (parsed.origin !== originUrl.origin) return "";
  const objectPath = localVideoObjectPath(parsed.pathname);
  if (!objectPath) return "";
  const slash = objectPath.lastIndexOf("/");
  const dir = slash >= 0 ? objectPath.slice(0, slash + 1) : "";
  const file = slash >= 0 ? objectPath.slice(slash + 1) : objectPath;
  const dot = file.lastIndexOf(".");
  const stem = dot >= 0 ? file.slice(0, dot) : file;
  for (const extension of VIDEO_THUMB_EXTENSIONS) {
    const staticPath = exactLocalStaticPath(`${dir}${stem}_thumb${extension}`);
    if (staticPath) {
      return resolveAppImageUrl(staticPath, origin, {
        width: 1200,
        quality: 86,
      });
    }
  }
  return "";
};

const localVideoObjectPath = (pathname: string): string => {
  const decoded = safeDecodePath(pathname);
  if (decoded.startsWith("/api/storage/file/video/")) {
    return `video/${decoded.slice("/api/storage/file/video/".length)}`;
  }
  if (decoded.startsWith("/local-upload/video/")) {
    return `video/${decoded.slice("/local-upload/video/".length)}`;
  }
  return "";
};

const safeDecodePath = (pathname: string): string => {
  try {
    return decodeURIComponent(pathname);
  } catch {
    return pathname;
  }
};

const explicitVideoThumbUrl = (entry: any, origin: string): string => {
  for (const field of VIDEO_THUMB_FIELDS) {
    const value = String(entry?.[field] || "").trim();
    if (value) {
      return resolveAppImageUrl(value, origin, { width: 1200, quality: 86 });
    }
  }
  return "";
};

const videoMediaItem = (
  entry: any,
  origin: string,
  options: ImageVariantOptions = {},
): VideoMediaItem | null => {
  const mediaUrl = String(entry?.mediaUrl || "").trim();
  if (!mediaUrl) return null;
  const url = resolveAppImageUrl(mediaUrl, origin, options);
  if (!url) return null;
  return {
    url,
    thumbUrl:
      explicitVideoThumbUrl(entry, origin) ||
      youtubeThumbUrl(url) ||
      localVideoThumbUrl(url, origin),
  };
};

const blockVideoMediaItems = (
  blocks: any[],
  origin: string,
): VideoMediaItem[] =>
  blocks
    .filter((entry: any) => {
      if (!entry) return false;
      return (
        String(entry.type || "")
          .trim()
          .toLowerCase() === "video"
      );
    })
    .map((entry: any) => videoMediaItem(entry, origin))
    .filter((entry): entry is VideoMediaItem => Boolean(entry));

const toIsoDate = (value: string | undefined): string => {
  const date = value ? new Date(value) : null;
  return date && !Number.isNaN(date.getTime())
    ? date.toISOString()
    : new Date().toISOString();
};

const stripHtml = (value: string): string =>
  value
    .replace(/<[^>]*>/g, " ")
    .replace(/&nbsp;/gi, " ")
    .replace(/&amp;/gi, "&")
    .replace(/&quot;/gi, '"')
    .replace(/&#39;/g, "'")
    .replace(/\s+/g, " ")
    .trim();

type CommentPreview = {
  id: string;
  parentId: string;
  body: string;
  publishedAt: string;
  likes: number;
  userLiked: boolean;
  canDelete: boolean;
  author: {
    id: string;
    name: string;
    avatarUrl: string;
    handle: string;
    isVerified: boolean;
    isOfficial: boolean;
  };
  replies: CommentPreview[];
};

type ViewerPostState = {
  userLiked: boolean;
  userDisliked: boolean;
  userSaved: boolean;
};

const authorName = (row: any): string =>
  String(
    row.user_full_name || row.user_name || row.guest_name || "Misafir",
  ).trim();

const authorHandle = (row: any): string => {
  const username = String(row.user_name || "").trim();
  return username ? (username.startsWith("@") ? username : `@${username}`) : "";
};

const isOfficialRole = (role: unknown) => {
  const value = String(role || "")
    .trim()
    .toLowerCase();
  return value === "admin" || value === "super_admin" || value === "editor";
};

const mapCommentPreview = (
  row: any,
  origin: string,
  userId: string | null,
): CommentPreview => ({
  id: String(row.id || ""),
  parentId: String(row.parent_id || ""),
  body: stripHtml(String(row.content || "")),
  publishedAt: toIsoDate(row.created_at),
  likes: Number(row.likes_count || 0),
  userLiked: row.user_liked === true,
  canDelete: Boolean(userId && String(row.user_id || "") === userId),
  author: {
    id: String(row.user_id || ""),
    name: authorName(row),
    avatarUrl: resolveAppImageUrl(String(row.user_avatar || ""), origin, {
      width: 180,
      quality: 86,
    }),
    handle: authorHandle(row),
    isVerified: Boolean(row.user_id),
    isOfficial: isOfficialRole(row.user_role),
  },
  replies: Array.isArray(row.replies)
    ? row.replies.map((reply: any) => mapCommentPreview(reply, origin, userId))
    : [],
});

async function loadPreviewComments(
  postIds: number[],
  origin: string,
  userId: string | null,
): Promise<Map<string, CommentPreview[]>> {
  if (postIds.length === 0) return new Map();
  try {
    const result = await dbQuery(
      `WITH root_comments AS (
         SELECT
           c.id, c.post_id, c.user_id, c.guest_name, c.parent_id, c.content,
           c.created_at, c.likes_count, c.is_pinned,
           p.username AS user_name, p.full_name AS user_full_name,
           p.avatar_url AS user_avatar, p.role AS user_role,
           ROW_NUMBER() OVER (
             PARTITION BY c.post_id
             ORDER BY c.is_pinned DESC, c.created_at ASC, c.id ASC
           ) AS rn
         FROM public.comments c
         LEFT JOIN public.profiles p ON p.id = c.user_id
         WHERE c.post_id = ANY($1::bigint[])
           AND c.status = 'approved'
           AND c.parent_id IS NULL
       ),
       selected_roots AS (
         SELECT * FROM root_comments WHERE rn <= 2
       )
       SELECT
         sr.*,
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
             WHERE r.parent_id = sr.id
               AND r.status = 'approved'
             ORDER BY r.is_pinned DESC, r.created_at ASC, r.id ASC
             LIMIT 1
           ) replies
         ), '[]'::json) AS replies
       FROM selected_roots sr
       ORDER BY sr.post_id, sr.is_pinned DESC, sr.created_at ASC, sr.id ASC`,
      [postIds],
    );

    const byPost = new Map<string, CommentPreview[]>();
    for (const row of result.rows) {
      const key = String(row.post_id || "");
      if (!key) continue;
      const list = byPost.get(key) || [];
      list.push(mapCommentPreview(row, origin, userId));
      byPost.set(key, list);
    }
    return byPost;
  } catch {
    return new Map();
  }
}

async function loadViewerPostStates(
  postIds: number[],
  userId: string | null,
): Promise<Map<string, ViewerPostState>> {
  const states = new Map<string, ViewerPostState>();
  if (!userId || postIds.length === 0) return states;
  const [likesRes, dislikesRes, savesRes] = await Promise.all([
    dbQuery<{ post_id: string }>(
      "SELECT post_id FROM public.post_likes WHERE user_id = $1::uuid AND post_id = ANY($2::bigint[])",
      [userId, postIds],
    ),
    dbQuery<{ post_id: string }>(
      "SELECT post_id FROM public.post_dislikes WHERE user_id = $1::uuid AND post_id = ANY($2::bigint[])",
      [userId, postIds],
    ),
    dbQuery<{ post_id: string }>(
      "SELECT post_id FROM public.post_saves WHERE user_id = $1::uuid AND post_id = ANY($2::bigint[])",
      [userId, postIds],
    ),
  ]);
  const ensure = (postId: string) => {
    const current = states.get(postId);
    if (current) return current;
    const initial = { userLiked: false, userDisliked: false, userSaved: false };
    states.set(postId, initial);
    return initial;
  };
  likesRes.rows.forEach((row) => {
    ensure(String(row.post_id)).userLiked = true;
  });
  dislikesRes.rows.forEach((row) => {
    ensure(String(row.post_id)).userDisliked = true;
  });
  savesRes.rows.forEach((row) => {
    ensure(String(row.post_id)).userSaved = true;
  });
  return states;
}

async function loadApprovedCommentCounts(
  postIds: number[],
): Promise<Map<string, number>> {
  if (postIds.length === 0) return new Map();
  try {
    const result = await dbQuery(
      `SELECT post_id, COUNT(*)::int AS comments_count
       FROM public.comments
       WHERE post_id = ANY($1::bigint[])
         AND status = 'approved'
       GROUP BY post_id`,
      [postIds],
    );
    const byPost = new Map<string, number>();
    for (const row of result.rows) {
      const key = String(row.post_id || "");
      if (!key) continue;
      byPost.set(key, Number(row.comments_count || 0));
    }
    return byPost;
  } catch {
    return new Map();
  }
}

const extractSocialSourceUrl = (raw: string): string => {
  const value = String(raw || "").trim();
  if (!value) return "";

  const twitterMatch = value.match(
    /href="(https?:\/\/(?:twitter\.com|x\.com)\/[^"]*\/status\/\d+[^"]*)"/i,
  );
  if (twitterMatch) return twitterMatch[1].split("?")[0];

  const instagramMatch = value.match(
    /(https?:\/\/(?:www\.)?instagram\.com\/(?:p|reel|tv)\/[^/\s"]+)/i,
  );
  if (instagramMatch) return instagramMatch[1].replace(/\/embed.*$/, "/");

  if (value.includes("facebook.com/plugins/")) {
    try {
      const parsed = new URL(value);
      const href = parsed.searchParams.get("href");
      if (href) return href;
    } catch {
      // generic fallback below
    }
  }

  if (value.includes("assets.pinterest.com/ext/embed.html")) {
    try {
      const parsed = new URL(value);
      const id = parsed.searchParams.get("id");
      if (id) return `https://www.pinterest.com/pin/${id}/`;
    } catch {
      // generic fallback below
    }
  }

  const genericMatch = value.match(/https?:\/\/[^\s"<>]+/i);
  if (genericMatch) return genericMatch[0].split("?")[0];

  return value.startsWith("http") ? value : "";
};

const detectSocialPlatform = (raw: string): string => {
  const value = String(raw || "").toLowerCase();
  if (value.includes("instagram.com")) return "instagram";
  if (value.includes("twitter.com") || value.includes("x.com")) return "x";
  if (value.includes("facebook.com") || value.includes("fb.watch"))
    return "facebook";
  if (value.includes("tiktok.com")) return "tiktok";
  if (value.includes("pinterest.com") || value.includes("pin.it"))
    return "pinterest";
  if (value.includes("nsosyal.com")) return "nsosyal";
  return value ? "link" : "";
};

const scoreValue = (value: unknown): number => {
  const parsed = Number(value || 0);
  if (!Number.isFinite(parsed)) return 0;
  return Math.min(Math.max(Math.round(parsed), 0), 100);
};

const textList = (value: unknown): string[] => {
  if (!Array.isArray(value)) return [];
  return value
    .map((entry) => stripHtml(String(entry || "")))
    .filter((entry) => Boolean(entry));
};

const normalizeReviewData = (value: unknown, origin: string) => {
  if (!value || typeof value !== "object") return undefined;
  const raw = value as any;
  const productName = stripHtml(String(raw.productName || ""));
  const productImage = resolveAppImageUrl(
    String(raw.productImage || ""),
    origin,
    {
      width: 900,
      quality: 86,
    },
  );
  const pros = textList(raw.pros);
  const cons = textList(raw.cons);
  const breakdown = Array.isArray(raw.breakdown)
    ? raw.breakdown
        .map((entry: any) => ({
          label: stripHtml(String(entry?.label || "")),
          score: scoreValue(entry?.score),
        }))
        .filter((entry: any) => Boolean(entry.label))
    : [];
  const verdict = stripHtml(String(raw.verdict || ""));
  if (
    !productName &&
    !productImage &&
    pros.length === 0 &&
    cons.length === 0 &&
    breakdown.length === 0 &&
    !verdict
  ) {
    return undefined;
  }
  return {
    productName,
    productImage,
    score: scoreValue(raw.score),
    pros,
    cons,
    breakdown,
    verdict,
  };
};

const normalizePollData = (
  item: NewsItem,
  origin: string,
):
  | {
      title: string;
      description: string;
      options: Array<{
        id: string;
        text: string;
        votes: number;
        imageUrl: string;
      }>;
      isImagePoll: boolean;
      columns: 1 | 2 | 3;
      totalVotes: number;
    }
  | undefined => {
  const raw = item as any;
  const itemType = String(item.type || "")
    .trim()
    .toLowerCase();
  if (itemType !== "poll") return undefined;

  const options = Array.isArray(raw.options)
    ? raw.options
        .map((option: any, index: number) => {
          const text = stripHtml(String(option?.text || ""));
          if (!text) return null;
          const imageUrl = resolveAppImageUrl(
            String(option?.imageUrl || option?.image || "").trim(),
            origin,
            { width: 800, quality: 86 },
          );
          return {
            id: String(option?.id || `poll-option-${index + 1}`),
            text,
            votes: Math.max(0, Math.round(Number(option?.votes || 0))),
            imageUrl,
          };
        })
        .filter(Boolean)
    : [];

  const title = stripHtml(String(raw.blockTitle || item.title || ""));
  if (!title || options.length < 2) return undefined;

  const optionVoteTotal = options.reduce(
    (total: number, option: any) => total + option.votes,
    0,
  );
  const rawTotalVotes = Number(raw.totalVotes || 0);
  const isImagePoll = raw.isImagePoll === true;
  const columns = isImagePoll ? (Number(raw.pollColumns) === 3 ? 3 : 2) : 1;

  return {
    title,
    description: stripHtml(String(raw.blockDescription || item.summary || "")),
    options,
    isImagePoll,
    columns,
    totalVotes: Math.max(0, Math.round(rawTotalVotes || optionVoteTotal)),
  };
};

const normalizeVsData = (
  item: NewsItem,
  origin: string,
):
  | {
      title: string;
      description: string;
      options: Array<{
        id: string;
        text: string;
        votes: number;
        imageUrl: string;
      }>;
      totalVotes: number;
    }
  | undefined => {
  const raw = item as any;
  const itemType = String(item.type || "")
    .trim()
    .toLowerCase();
  if (itemType !== "vs") return undefined;

  const options = Array.isArray(raw.options)
    ? raw.options
        .slice(0, 2)
        .map((option: any, index: number) => {
          const text = stripHtml(String(option?.text || ""));
          if (!text) return null;
          const imageUrl = resolveAppImageUrl(
            String(option?.imageUrl || option?.image || "").trim(),
            origin,
            { width: 900, quality: 86 },
          );
          return {
            id: String(option?.id || `vs-option-${index + 1}`),
            text,
            votes: Math.max(0, Math.round(Number(option?.votes || 0))),
            imageUrl,
          };
        })
        .filter(Boolean)
    : [];

  const title = stripHtml(String(raw.blockTitle || item.title || ""));
  if (!title || options.length < 2) return undefined;

  const optionVoteTotal = options.reduce(
    (total: number, option: any) => total + option.votes,
    0,
  );
  const rawTotalVotes = Number(raw.totalVotes || 0);

  return {
    title,
    description: stripHtml(String(raw.blockDescription || item.summary || "")),
    options,
    totalVotes: Math.max(0, Math.round(rawTotalVotes || optionVoteTotal)),
  };
};

const normalizeQuoteData = (
  value: unknown,
): { text: string; author: string; sourceUrl: string } | undefined => {
  if (!value || typeof value !== "object") return undefined;
  const raw = value as any;
  const paragraphItems = Array.isArray(raw.paragraphData?.items)
    ? raw.paragraphData.items
    : [];
  const paragraphText = paragraphItems.find((entry: any) =>
    Boolean(String(entry || "").trim()),
  );
  const text = stripHtml(
    String(raw.description || raw.blockDescription || paragraphText || ""),
  );
  if (!text) return undefined;
  return {
    text,
    author: stripHtml(
      String(
        raw.title || raw.quoteAuthor || raw.paragraphData?.quoteAuthor || "",
      ),
    ),
    sourceUrl: String(raw.source || raw.sourceUrl || "").trim(),
  };
};

const normalizeKeywords = (value: unknown): string[] => {
  const values = Array.isArray(value) ? value : String(value || "").split(",");
  const seen = new Set<string>();
  const keywords: string[] = [];
  for (const item of values) {
    const keyword = stripHtml(String(item || ""))
      .replace(/^#+/, "")
      .trim();
    if (!keyword) continue;
    const key = keyword.toLocaleLowerCase("tr");
    if (seen.has(key)) continue;
    seen.add(key);
    keywords.push(keyword);
    if (keywords.length >= 14) break;
  }
  return keywords;
};

const normalizeFaqData = (value: unknown): Array<{ q: string; a: string }> => {
  if (!Array.isArray(value)) return [];
  const faq: Array<{ q: string; a: string }> = [];
  for (const item of value) {
    if (!item || typeof item !== "object") continue;
    const raw = item as Record<string, unknown>;
    const q = stripHtml(String(raw.q || raw.question || raw.name || ""));
    const a = stripHtml(String(raw.a || raw.answer || raw.text || ""));
    if (!q || !a) continue;
    faq.push({ q, a });
    if (faq.length >= 8) break;
  }
  return faq;
};

const normalizeCategoryTrail = (item: NewsItem): string[] => {
  const payload = item as unknown as {
    categoryTrail?: unknown;
    categoryPath?: unknown;
  };
  const raw = payload.categoryTrail ?? payload.categoryPath;
  const source = Array.isArray(raw)
    ? raw
    : typeof raw === "string"
      ? raw.split(/[>/]/)
      : [];
  const trail: string[] = [];
  const seen = new Set<string>();
  for (const entry of source) {
    const label = stripHtml(String(entry || "")).trim();
    const key = label.toLocaleLowerCase("tr-TR");
    if (!label || seen.has(key)) continue;
    seen.add(key);
    trail.push(label);
  }
  return trail;
};

const normalizeQuizData = (value: unknown, origin: string) => {
  if (!value || typeof value !== "object") return undefined;
  const raw = value as any;
  const data =
    raw.quizData && typeof raw.quizData === "object" ? raw.quizData : raw;
  const questions = Array.isArray(data.questions)
    ? data.questions
        .map((question: any, questionIndex: number) => {
          const answers = Array.isArray(question?.answers)
            ? question.answers
                .map((answer: any, answerIndex: number) => {
                  const text = stripHtml(String(answer?.text || ""));
                  if (!text) return null;
                  return {
                    id: String(
                      answer?.id ||
                        `quiz-answer-${questionIndex + 1}-${answerIndex + 1}`,
                    ),
                    text,
                    imageUrl: resolveAppImageUrl(
                      String(answer?.imageUrl || answer?.image || "").trim(),
                      origin,
                      { width: 800, quality: 86 },
                    ),
                    resultId: String(answer?.resultId || ""),
                    isCorrect: answer?.isCorrect === true,
                    explanation: stripHtml(String(answer?.explanation || "")),
                  };
                })
                .filter(Boolean)
            : [];
          const title = stripHtml(String(question?.title || ""));
          if (!title || answers.length === 0) return null;
          return {
            id: String(question?.id || `quiz-question-${questionIndex + 1}`),
            title,
            imageUrl: resolveAppImageUrl(
              String(question?.imageUrl || question?.image || "").trim(),
              origin,
              { width: 1000, quality: 86 },
            ),
            description: stripHtml(String(question?.description || "")),
            layout: String(question?.layout || "list").trim() || "list",
            answers,
          };
        })
        .filter(Boolean)
    : [];

  if (questions.length === 0) return undefined;

  const results = Array.isArray(data.results)
    ? data.results
        .map((result: any, index: number) => {
          const title = stripHtml(String(result?.title || ""));
          const description = stripHtml(String(result?.description || ""));
          const imageUrl = resolveAppImageUrl(
            String(result?.imageUrl || result?.image || "").trim(),
            origin,
            { width: 1000, quality: 86 },
          );
          if (!title && !description && !imageUrl) return null;
          return {
            id: String(result?.id || `quiz-result-${index + 1}`),
            title,
            imageUrl,
            description,
            minScore: result?.minScore,
            maxScore: result?.maxScore,
            answerCount: result?.answerCount,
          };
        })
        .filter(Boolean)
    : [];

  return {
    quizType: String(data.quizType || "personality").trim() || "personality",
    questionSorting: String(data.questionSorting || "asc").trim() || "asc",
    allowMultiple: data.allowMultiple === true,
    showResults: data.showResults !== false,
    endDate: String(data.endDate || "").trim(),
    results,
    questions,
  };
};

const tocListStyles = new Set([
  "none",
  "decimal",
  "decimal-leading-zero",
  "circle",
  "disc",
  "square",
  "lower-alpha",
  "upper-alpha",
  "lower-roman",
  "upper-roman",
]);

const normalizeTocStyle = (value: unknown): string => {
  const style = String(value || "")
    .trim()
    .toLowerCase();
  return tocListStyles.has(style) ? style : "none";
};

const normalizeTocData = (value: unknown, origin: string) => {
  if (!value || typeof value !== "object") return undefined;
  const raw = value as any;
  const data =
    raw.tocData && typeof raw.tocData === "object" ? raw.tocData : raw;
  const sourceItems = Array.isArray(data.items) ? data.items : [];
  const items = sourceItems
    .map((entry: any, index: number) => {
      if (!entry || typeof entry !== "object") return null;
      const title = stripHtml(String(entry.title || ""));
      const content = stripHtml(
        String(entry.content || entry.description || entry.body || ""),
      );
      const imageUrl = resolveAppImageUrl(
        String(entry.imageUrl || entry.image || entry.mediaUrl || "").trim(),
        origin,
        { width: 1200, quality: 86 },
      );
      const imageDescription = stripHtml(
        String(entry.imageDescription || entry.altText || entry.caption || ""),
      );
      if (!title && !content && !imageUrl) return null;
      const parsedOrder = Number(entry.orderNumber || index + 1);
      return {
        id: String(entry.id || `toc-item-${index + 1}`),
        title,
        parentId: String(entry.parentId || entry.parent || "").trim(),
        imageUrl,
        imageDescription,
        content,
        orderNumber:
          Number.isFinite(parsedOrder) && parsedOrder > 0
            ? Math.round(parsedOrder)
            : index + 1,
      };
    })
    .filter(Boolean);

  if (items.length === 0) return undefined;

  const styles = data.linkListStyle || {};
  const show = data.showInText || {};
  return {
    title: stripHtml(String(data.title || raw.title || raw.blockTitle || "")),
    linkListStyle: {
      level1: normalizeTocStyle(styles.level1),
      level2: normalizeTocStyle(styles.level2),
      level3: normalizeTocStyle(styles.level3),
    },
    showInText: {
      level1: show.level1 === true,
      level2: show.level2 === true,
      level3: show.level3 === true,
    },
    items,
  };
};

const normalizeRecipeData = (value: unknown, origin: string) => {
  if (!value || typeof value !== "object") return undefined;
  const raw = value as any;
  const data =
    raw.recipeData && typeof raw.recipeData === "object" ? raw.recipeData : raw;
  const ingredients = Array.isArray(data.ingredients)
    ? data.ingredients
        .map((entry: any) => {
          const text = stripHtml(String(entry?.text || ""));
          return text ? { text } : null;
        })
        .filter(Boolean)
    : [];
  const nutrition = Array.isArray(data.nutrition)
    ? data.nutrition
        .map((entry: any) => {
          const label = stripHtml(String(entry?.label || ""));
          const rowValue = stripHtml(String(entry?.value || ""));
          return label || rowValue ? { label, value: rowValue } : null;
        })
        .filter(Boolean)
    : [];
  const directions = Array.isArray(data.directions)
    ? data.directions
        .map((entry: any, index: number) => {
          if (!entry || typeof entry !== "object") return null;
          const title = stripHtml(String(entry.title || ""));
          const content = stripHtml(
            String(entry.content || entry.description || ""),
          );
          const imageUrl = resolveAppImageUrl(
            String(
              entry.imageUrl || entry.image || entry.mediaUrl || "",
            ).trim(),
            origin,
            { width: 1200, quality: 86 },
          );
          const imageDescription = stripHtml(
            String(
              entry.imageDescription || entry.altText || entry.caption || "",
            ),
          );
          if (!title && !content && !imageUrl) return null;
          const parsedOrder = Number(entry.orderNumber || index + 1);
          return {
            id: String(entry.id || `recipe-step-${index + 1}`),
            title,
            content,
            imageUrl,
            imageDescription,
            orderNumber:
              Number.isFinite(parsedOrder) && parsedOrder > 0
                ? Math.round(parsedOrder)
                : index + 1,
          };
        })
        .filter(Boolean)
    : [];

  const prepTime = stripHtml(String(data.prepTime || ""));
  const cookTime = stripHtml(String(data.cookTime || ""));
  const serving = stripHtml(String(data.serving || ""));
  const difficulty = String(data.difficulty || "")
    .trim()
    .toLowerCase();
  const normalizedDifficulty =
    difficulty === "easy" || difficulty === "medium" || difficulty === "hard"
      ? difficulty
      : difficulty === "kolay"
        ? "easy"
        : difficulty === "orta" || difficulty === "intermediate"
          ? "medium"
          : difficulty === "zor" || difficulty === "advanced"
            ? "hard"
            : "";

  if (
    !prepTime &&
    !cookTime &&
    !serving &&
    !normalizedDifficulty &&
    ingredients.length === 0 &&
    nutrition.length === 0 &&
    directions.length === 0
  ) {
    return undefined;
  }

  return {
    prepTime,
    cookTime,
    serving,
    difficulty: normalizedDifficulty,
    ingredients,
    nutrition,
    directions,
  };
};

const normalizeEventRegistrationType = (value: unknown) => {
  const type = String(value || "")
    .trim()
    .toLowerCase();
  return type === "required" || type === "tickets" || type === "external"
    ? type
    : "none";
};

const normalizeEventData = (value: unknown, origin: string) => {
  if (!value || typeof value !== "object") return undefined;
  const raw = value as any;
  const data =
    raw.eventData && typeof raw.eventData === "object" ? raw.eventData : raw;

  const schedule = Array.isArray(data.schedule)
    ? data.schedule
        .map((entry: any, index: number) => {
          if (!entry || typeof entry !== "object") return null;
          const date = stripHtml(String(entry.date || ""));
          const time = stripHtml(String(entry.time || ""));
          const title = stripHtml(String(entry.title || ""));
          const description = stripHtml(
            String(entry.description || entry.content || ""),
          );
          const imageUrl = resolveAppImageUrl(
            String(
              entry.imageUrl || entry.image || entry.mediaUrl || "",
            ).trim(),
            origin,
            { width: 1200, quality: 86 },
          );
          const imageDescription = stripHtml(
            String(
              entry.imageDescription || entry.altText || entry.caption || "",
            ),
          );
          if (!date && !time && !title && !description && !imageUrl)
            return null;
          const parsedOrder = Number(entry.orderNumber || index + 1);
          return {
            id: String(entry.id || `event-schedule-${index + 1}`),
            date,
            time,
            title,
            description,
            imageUrl,
            imageDescription,
            orderNumber:
              Number.isFinite(parsedOrder) && parsedOrder > 0
                ? Math.round(parsedOrder)
                : index + 1,
          };
        })
        .filter(Boolean)
    : [];
  const highlights = Array.isArray(data.highlights)
    ? data.highlights
        .map((entry: any) => {
          const label = stripHtml(String(entry?.label || ""));
          const rowValue = stripHtml(String(entry?.value || ""));
          return label || rowValue ? { label, value: rowValue } : null;
        })
        .filter(Boolean)
    : [];
  const speakers = Array.isArray(data.speakers)
    ? data.speakers
        .map((entry: any, index: number) => {
          if (!entry || typeof entry !== "object") return null;
          const name = stripHtml(String(entry.name || ""));
          const role = stripHtml(String(entry.role || ""));
          const bio = stripHtml(String(entry.bio || ""));
          const imageUrl = resolveAppImageUrl(
            String(
              entry.imageUrl || entry.image || entry.mediaUrl || "",
            ).trim(),
            origin,
            { width: 900, quality: 86 },
          );
          const imageDescription = stripHtml(
            String(
              entry.imageDescription || entry.altText || entry.caption || "",
            ),
          );
          if (!name && !role && !bio && !imageUrl) return null;
          return {
            id: String(entry.id || `event-speaker-${index + 1}`),
            name,
            role,
            bio,
            imageUrl,
            imageDescription,
          };
        })
        .filter(Boolean)
    : [];

  const startDateTime = stripHtml(String(data.startDateTime || ""));
  const endDateTime = stripHtml(String(data.endDateTime || ""));
  const organizer = stripHtml(String(data.organizer || ""));
  const venueName = stripHtml(String(data.venueName || ""));
  const address = stripHtml(String(data.address || ""));
  const latitude = stripHtml(String(data.latitude || ""));
  const longitude = stripHtml(String(data.longitude || ""));
  const registrationType = normalizeEventRegistrationType(
    data.registrationType,
  );
  const ticketUrl = String(data.ticketUrl || "").trim();
  const ticketPrice = stripHtml(String(data.ticketPrice || ""));
  const capacity = stripHtml(String(data.capacity || ""));
  const scheduleTitle = stripHtml(String(data.scheduleTitle || ""));
  const highlightsTitle = stripHtml(String(data.highlightsTitle || ""));
  const speakersTitle = stripHtml(String(data.speakersTitle || ""));

  if (
    !startDateTime &&
    !endDateTime &&
    !organizer &&
    !venueName &&
    !address &&
    !latitude &&
    !longitude &&
    registrationType === "none" &&
    !ticketUrl &&
    !ticketPrice &&
    !capacity &&
    schedule.length === 0 &&
    highlights.length === 0 &&
    speakers.length === 0
  ) {
    return undefined;
  }

  return {
    startDateTime,
    endDateTime,
    organizer,
    venueName,
    address,
    latitude,
    longitude,
    registrationType,
    ticketUrl,
    ticketPrice,
    capacity,
    scheduleTitle,
    highlightsTitle,
    speakersTitle,
    schedule,
    highlights,
    speakers,
  };
};

const normalizeDetailItems = (blocks: any[], origin: string) => {
  return blocks
    .map((block: any, index: number) => {
      if (!block || typeof block !== "object") return null;
      const rawType = String(block.type || "")
        .trim()
        .toLowerCase();
      if (!rawType) return null;
      if (rawType === "faq") return null;
      const type =
        rawType === "before_after" || rawType === "before-after"
          ? "beforeafter"
          : rawType === "flip"
            ? "flipcard"
            : rawType;
      const videoItem = type === "video" ? videoMediaItem(block, origin) : null;
      const mediaUrl =
        type === "video"
          ? videoItem?.url || ""
          : type === "image" || type === "audio"
            ? resolveAppImageUrl(String(block.mediaUrl || "").trim(), origin, {
                width: 1200,
                quality: 86,
              })
            : type === "social" || type === "iframe" || type === "embed"
              ? String(block.mediaUrl || "").trim()
              : "";
      const mediaUrls =
        type === "slider" && Array.isArray(block.mediaUrls)
          ? block.mediaUrls
              .map((url: any) =>
                resolveAppImageUrl(String(url || "").trim(), origin, {
                  width: 1200,
                  quality: 86,
                }),
              )
              .filter((url: string) => Boolean(url))
          : [];
      const pollData =
        type === "poll"
          ? normalizePollData(
              {
                ...block,
                type: "poll",
                title: block.title || block.blockTitle,
                summary: block.description || block.blockDescription,
              } as NewsItem,
              origin,
            )
          : undefined;
      const quizData =
        type === "quiz" ? normalizeQuizData(block, origin) : undefined;
      const vsData =
        type === "vs"
          ? normalizeVsData(
              {
                ...block,
                type: "vs",
                title: block.title || block.blockTitle,
                summary: block.description || block.blockDescription,
              } as NewsItem,
              origin,
            )
          : undefined;
      const reviewData =
        type === "review"
          ? normalizeReviewData(block.reviewData || block, origin)
          : undefined;
      const quoteData =
        type === "quote" || type === "paragraph"
          ? normalizeQuoteData(block)
          : undefined;
      const tocData =
        type === "toc" || type === "contents" || type === "table_of_contents"
          ? normalizeTocData(block, origin)
          : undefined;
      const recipeData =
        type === "recipe" || type === "tarif"
          ? normalizeRecipeData(block, origin)
          : undefined;
      const eventData =
        type === "event" || type === "etkinlik"
          ? normalizeEventData(block, origin)
          : undefined;
      const beforeAfterData =
        type === "beforeafter" && block.beforeAfterData
          ? {
              ...block.beforeAfterData,
              beforeImage: resolveAppImageUrl(
                block.beforeAfterData.beforeImage,
                origin,
                { width: 1200, quality: 86 },
              ),
              afterImage: resolveAppImageUrl(
                block.beforeAfterData.afterImage,
                origin,
                { width: 1200, quality: 86 },
              ),
            }
          : undefined;
      const flipData =
        type === "flipcard" && block.flipData
          ? {
              ...block.flipData,
              frontImage: resolveAppImageUrl(
                block.flipData.frontImage,
                origin,
                { width: 1200, quality: 86 },
              ),
              backImage: resolveAppImageUrl(block.flipData.backImage, origin, {
                width: 1200,
                quality: 86,
              }),
            }
          : undefined;

      const title = stripHtml(String(block.title || block.blockTitle || ""));
      const description = stripHtml(
        String(block.description || block.blockDescription || block.body || ""),
      );
      const source = stripHtml(
        String(block.source || block.sourceName || block.credit || ""),
      );
      const moreInfoUrl = String(
        block.moreInfoUrl || block.sourceUrl || block.link || "",
      ).trim();

      const item = {
        id: String(block.id || `detail-item-${index + 1}`),
        type,
        title,
        description,
        source,
        moreInfoUrl,
        mediaUrl,
        mediaUrls,
        altText: stripHtml(String(block.altText || "")),
        videoThumbUrl: videoItem?.thumbUrl || "",
        flipData,
        beforeAfterData,
        reviewData,
        pollData,
        quizData,
        tocData,
        recipeData,
        eventData,
        vsData,
        quoteData,
      };

      const hasContent =
        title ||
        description ||
        source ||
        moreInfoUrl ||
        mediaUrl ||
        mediaUrls.length > 0 ||
        flipData ||
        beforeAfterData ||
        reviewData ||
        pollData ||
        quizData ||
        tocData ||
        recipeData ||
        eventData ||
        vsData ||
        quoteData;
      return hasContent ? item : null;
    })
    .filter(Boolean);
};

const calculateReadingMinutes = (item: NewsItem): number => {
  const raw = item as NewsItem & {
    content?: string;
    items?: Array<{ title?: string; description?: string; body?: string }>;
  };
  const itemContent = Array.isArray(raw.items)
    ? raw.items
        .map((entry) =>
          [
            entry?.title,
            entry?.description,
            entry?.body,
            ...(Array.isArray((entry as any)?.tocData?.items)
              ? (entry as any).tocData.items.flatMap((tocItem: any) => [
                  tocItem?.title,
                  tocItem?.content,
                ])
              : []),
            ...(Array.isArray((entry as any)?.recipeData?.ingredients)
              ? (entry as any).recipeData.ingredients.map(
                  (ingredient: any) => ingredient?.text,
                )
              : []),
            ...(Array.isArray((entry as any)?.recipeData?.nutrition)
              ? (entry as any).recipeData.nutrition.flatMap((row: any) => [
                  row?.label,
                  row?.value,
                ])
              : []),
            ...(Array.isArray((entry as any)?.recipeData?.directions)
              ? (entry as any).recipeData.directions.flatMap((step: any) => [
                  step?.title,
                  step?.content,
                ])
              : []),
            (entry as any)?.eventData?.startDateTime,
            (entry as any)?.eventData?.endDateTime,
            (entry as any)?.eventData?.organizer,
            (entry as any)?.eventData?.venueName,
            (entry as any)?.eventData?.address,
            (entry as any)?.eventData?.ticketPrice,
            (entry as any)?.eventData?.capacity,
            ...(Array.isArray((entry as any)?.eventData?.schedule)
              ? (entry as any).eventData.schedule.flatMap((slot: any) => [
                  slot?.date,
                  slot?.time,
                  slot?.title,
                  slot?.description,
                ])
              : []),
            ...(Array.isArray((entry as any)?.eventData?.highlights)
              ? (entry as any).eventData.highlights.flatMap((row: any) => [
                  row?.label,
                  row?.value,
                ])
              : []),
            ...(Array.isArray((entry as any)?.eventData?.speakers)
              ? (entry as any).eventData.speakers.flatMap((speaker: any) => [
                  speaker?.name,
                  speaker?.role,
                  speaker?.bio,
                ])
              : []),
          ]
            .map((part) => String(part || ""))
            .join(" "),
        )
        .join(" ")
    : "";
  const totalContent = stripHtml(
    [item.title, item.summary, raw.content, itemContent]
      .map((part) => String(part || ""))
      .join(" "),
  );
  const words = totalContent
    ? totalContent.split(/\s+/).filter(Boolean).length
    : 0;
  return Math.max(1, Math.ceil(words / 200));
};

const mapFeedItem = (
  item: NewsItem,
  origin: string,
  previewComments: CommentPreview[] = [],
  approvedCommentCount?: number,
  viewerState?: ViewerPostState,
) => {
  const raw = item as NewsItem & {
    sourceAvatar?: string;
    isPinned?: boolean;
    publisherId?: string;
    publisherHandle?: string;
    isOfficial?: boolean;
    isVerified?: boolean;
    region?: string;
  };
  const optimizedImage =
    item.optimizedCoverThumbnail || item.optimizedThumbnail;
  const blocks = Array.isArray((item as any).items) ? (item as any).items : [];
  const homepageBlock = blocks.find((b: any) => b && b.showOnHomepage === true);
  const homepageType = String(homepageBlock?.type || "")
    .trim()
    .toLowerCase();
  const itemVideoItems = blockVideoMediaItems(blocks, origin);
  const itemType = String(item.type || "")
    .trim()
    .toLowerCase();

  const sliderImages: string[] =
    homepageBlock &&
    homepageType === "slider" &&
    Array.isArray(homepageBlock.mediaUrls)
      ? homepageBlock.mediaUrls
          .map((u: any) =>
            resolveAppImageUrl(String(u || "").trim(), origin, {
              width: 1200,
              quality: 86,
            }),
          )
          .filter((u: string) => Boolean(u))
      : [];

  const homepageImage =
    homepageBlock &&
    homepageType === "image" &&
    typeof homepageBlock.mediaUrl === "string" &&
    homepageBlock.mediaUrl.trim()
      ? resolveAppImageUrl(homepageBlock.mediaUrl.trim(), origin, {
          width: 1200,
          quality: 86,
        })
      : "";

  const homepageVideoItem =
    homepageBlock && homepageType === "video"
      ? videoMediaItem(homepageBlock, origin, {
          width: 1200,
          quality: 86,
        })
      : null;
  const videoItems =
    homepageVideoItem &&
    !itemVideoItems.some((entry) => entry.url === homepageVideoItem.url)
      ? [homepageVideoItem, ...itemVideoItems]
      : itemVideoItems;
  const videoUrls = videoItems.map((entry) => entry.url);
  const videoThumbUrls = videoItems.map((entry) => entry.thumbUrl);
  const homepageVideoUrl = homepageVideoItem?.url || "";
  const videoUrl = homepageVideoUrl || videoUrls[0] || "";

  const audioUrl =
    homepageBlock &&
    homepageType === "audio" &&
    typeof homepageBlock.mediaUrl === "string" &&
    homepageBlock.mediaUrl.trim()
      ? resolveAppImageUrl(homepageBlock.mediaUrl.trim(), origin)
      : "";

  const homepageVsImage =
    homepageBlock &&
    homepageType === "vs" &&
    typeof homepageBlock.mediaUrl === "string" &&
    homepageBlock.mediaUrl.trim()
      ? resolveAppImageUrl(homepageBlock.mediaUrl.trim(), origin)
      : "";

  const socialEmbed =
    homepageBlock &&
    (homepageType === "social" ||
      homepageType === "iframe" ||
      homepageType === "embed") &&
    typeof homepageBlock.mediaUrl === "string" &&
    homepageBlock.mediaUrl.trim()
      ? homepageBlock.mediaUrl.trim()
      : itemType === "embed" &&
          typeof item.mediaUrl === "string" &&
          item.mediaUrl.trim()
        ? item.mediaUrl.trim()
        : "";
  const socialSourceUrl = extractSocialSourceUrl(socialEmbed);
  const socialPlatform = detectSocialPlatform(socialSourceUrl || socialEmbed);
  const reviewData =
    normalizeReviewData(
      homepageType === "review" ? homepageBlock?.reviewData : item.reviewData,
      origin,
    ) || normalizeReviewData(item.reviewData, origin);
  const pollData = normalizePollData(item, origin);
  const quizData =
    itemType === "quiz" ? normalizeQuizData(item, origin) : undefined;
  const vsData = normalizeVsData(item, origin);
  const quoteData =
    homepageType === "quote"
      ? normalizeQuoteData(homepageBlock)
      : itemType === "paragraph"
        ? normalizeQuoteData(item)
        : undefined;

  const usingHomepageMedia =
    Boolean(homepageImage) ||
    sliderImages.length > 0 ||
    Boolean(homepageVsImage);
  const fallbackImage = socialEmbed
    ? String(optimizedImage?.src || item.coverThumbnail || item.thumbnail || "")
    : firstMediaUrl(item);
  const imageUrl =
    homepageImage ||
    sliderImages[0] ||
    homepageVsImage ||
    reviewData?.productImage ||
    resolveAppImageUrl(fallbackImage, origin, { width: 1200, quality: 86 });

  return {
    id: String(item.id || ""),
    category: String(item.category || ""),
    categoryTrail: normalizeCategoryTrail(item),
    title: String(item.title || ""),
    summary: String(item.summary || ""),
    imageUrl,
    sliderImages,
    videoUrl,
    videoUrls,
    videoThumbUrls,
    audioUrl,
    socialEmbed,
    socialSourceUrl,
    socialPlatform,
    flipData: item.flipData
      ? {
          ...item.flipData,
          frontImage: resolveAppImageUrl(item.flipData.frontImage, origin, {
            width: 1200,
            quality: 86,
          }),
          backImage: resolveAppImageUrl(item.flipData.backImage, origin, {
            width: 1200,
            quality: 86,
          }),
        }
      : undefined,
    beforeAfterData: item.beforeAfterData
      ? {
          ...item.beforeAfterData,
          beforeImage: resolveAppImageUrl(
            item.beforeAfterData.beforeImage,
            origin,
            {
              width: 1200,
              quality: 86,
            },
          ),
          afterImage: resolveAppImageUrl(
            item.beforeAfterData.afterImage,
            origin,
            {
              width: 1200,
              quality: 86,
            },
          ),
        }
      : undefined,
    reviewData,
    pollData,
    quizData,
    vsData,
    quoteData,
    detailItems: normalizeDetailItems(blocks, origin),
    tags: normalizeKeywords(item.keywords),
    faqData: normalizeFaqData(item.faqData),
    publishedAt: toIsoDate(item.timestamp),
    source: String(item.source || item.author || "Pateez"),
    sourceAvatar: resolveAppImageUrl(String(raw.sourceAvatar || ""), origin, {
      width: 180,
      quality: 86,
    }),
    slug: String(item.slug || ""),
    region: String(raw.region || ""),
    likes: Number(item.likes || 0),
    dislikes: Number(item.dislikes || 0),
    comments: Number(approvedCommentCount ?? item.comments ?? 0),
    shares: Number(item.shares || 0),
    views: Number(item.views || 0),
    saves: Number(item.saves || 0),
    userLiked: viewerState?.userLiked === true,
    userDisliked: viewerState?.userDisliked === true,
    userSaved: viewerState?.userSaved === true,
    readMinutes: calculateReadingMinutes(item),
    publisherId: String(raw.publisherId || ""),
    publisherHandle: String(raw.publisherHandle || ""),
    isPinned: raw.isPinned === true,
    isManset: item.isManset === true,
    isOfficial: raw.isOfficial === true,
    isVerified: raw.isVerified === true,
    previewComments,
    imageAspectRatio:
      usingHomepageMedia || socialEmbed || reviewData || quoteData
        ? undefined
        : imageAspectRatio(optimizedImage),
  };
};

export async function mapAppFeedItems(
  items: NewsItem[],
  origin: string,
  userId: string | null,
) {
  const postIds = items
    .map((item: NewsItem) => Number(item.id))
    .filter((id: number) => Number.isInteger(id) && id > 0);
  const [commentPreviewByPost, approvedCommentCountsByPost, viewerStateByPost] =
    await Promise.all([
      loadPreviewComments(postIds, origin, userId),
      loadApprovedCommentCounts(postIds),
      loadViewerPostStates(postIds, userId),
    ]);

  return items.map((item: NewsItem) =>
    mapFeedItem(
      item,
      origin,
      commentPreviewByPost.get(String(item.id || "")) || [],
      approvedCommentCountsByPost.get(String(item.id || "")) ?? 0,
      viewerStateByPost.get(String(item.id || "")),
    ),
  );
}
