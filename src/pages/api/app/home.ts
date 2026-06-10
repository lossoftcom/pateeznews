import type { APIRoute } from "astro";
import { getSessionFromRequest, json } from "@/lib/server/appDb";
import { dbQuery } from "@/lib/server/supabaseDb";
import { dataService } from "@/services/dataService.server";
import type { NewsItem, OptimizedImage } from "@/types";

export const prerender = false;

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

const numberParam = (
  value: string | null,
  fallback: number,
  min: number,
  max: number,
): number => {
  const parsed = Number(value ?? fallback);
  if (!Number.isFinite(parsed)) return fallback;
  return Math.min(Math.max(parsed, min), max);
};

const getNewsTime = (item: NewsItem): number => {
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

const blockMediaUrls = (
  blocks: any[],
  type: string,
  origin: string,
): string[] => {
  const targetType = type.trim().toLowerCase();
  return blocks
    .filter((entry: any) => {
      if (!entry) return false;
      if (
        String(entry.type || "")
          .trim()
          .toLowerCase() !== targetType
      )
        return false;
      return typeof entry.mediaUrl === "string" && entry.mediaUrl.trim();
    })
    .map((entry: any) => resolveImageUrl(entry.mediaUrl.trim(), origin))
    .filter((url: string) => Boolean(url));
};

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
    row.user_full_name ||
      row.user_name ||
      row.guest_name ||
      "Misafir",
  ).trim();

const authorHandle = (row: any): string => {
  const username = String(row.user_name || "").trim();
  return username ? (username.startsWith("@") ? username : `@${username}`) : "";
};

const isOfficialRole = (role: unknown) => {
  const value = String(role || "").trim().toLowerCase();
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
    name: authorName(row),
    avatarUrl: resolveImageUrl(String(row.user_avatar || ""), origin),
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
  const productImage = resolveImageUrl(String(raw.productImage || ""), origin);
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
): {
  title: string;
  description: string;
  options: Array<{ id: string; text: string; votes: number; imageUrl: string }>;
  isImagePoll: boolean;
  columns: 1 | 2 | 3;
  totalVotes: number;
} | undefined => {
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
          const imageUrl = resolveImageUrl(
            String(option?.imageUrl || option?.image || "").trim(),
            origin,
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
  const columns = isImagePoll
    ? Number(raw.pollColumns) === 3
      ? 3
      : 2
    : 1;

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
): {
  title: string;
  description: string;
  options: Array<{ id: string; text: string; votes: number; imageUrl: string }>;
  totalVotes: number;
} | undefined => {
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
          const imageUrl = resolveImageUrl(
            String(option?.imageUrl || option?.image || "").trim(),
            origin,
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
      String(raw.title || raw.quoteAuthor || raw.paragraphData?.quoteAuthor || ""),
    ),
    sourceUrl: String(raw.source || raw.sourceUrl || "").trim(),
  };
};

const calculateReadingMinutes = (item: NewsItem): number => {
  const raw = item as NewsItem & {
    content?: string;
    items?: Array<{ title?: string; description?: string; body?: string }>;
  };
  const itemContent = Array.isArray(raw.items)
    ? raw.items
        .map((entry) =>
          [entry?.title, entry?.description, entry?.body]
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

const mapFeaturedItem = (item: NewsItem, origin: string) => {
  const optimizedImage =
    item.optimizedCoverThumbnail || item.optimizedThumbnail;
  return {
    id: String(item.id || ""),
    category: String(item.category || ""),
    title: String(item.title || ""),
    summary: String(item.summary || ""),
    imageUrl: resolveImageUrl(
      String(
        item.mansetImageUrl ||
          optimizedImage?.src ||
          item.coverThumbnail ||
          item.thumbnail ||
          "",
      ),
      origin,
    ),
    publishedAt: toIsoDate(item.timestamp),
    source: String(item.source || "Pateeznews"),
    slug: String(item.slug || ""),
    imageAspectRatio: imageAspectRatio(optimizedImage),
  };
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
    isOfficial?: boolean;
    isVerified?: boolean;
    region?: string;
  };
  const optimizedImage =
    item.optimizedCoverThumbnail || item.optimizedThumbnail;

  // "Ana sayfada görünsün" seçili blok (görsel veya slider) varsa, kapak yerine
  // o blok ana sayfa kartında gösterilir. Hiçbir blok seçili değilse kapak görseli
  // kullanılır (mevcut davranış). Video akışı ise bu switch'e bağlı değildir;
  // haber içindeki tüm video blokları mobil tam ekran akışa gider.
  const blocks = Array.isArray((item as any).items) ? (item as any).items : [];
  const homepageBlock = blocks.find((b: any) => b && b.showOnHomepage === true);
  const homepageType = String(homepageBlock?.type || "")
    .trim()
    .toLowerCase();
  const itemVideoUrls = blockMediaUrls(blocks, "video", origin);
  const itemType = String(item.type || "")
    .trim()
    .toLowerCase();

  const sliderImages: string[] =
    homepageBlock &&
    homepageType === "slider" &&
    Array.isArray(homepageBlock.mediaUrls)
      ? homepageBlock.mediaUrls
          .map((u: any) => resolveImageUrl(String(u || "").trim(), origin))
          .filter((u: string) => Boolean(u))
      : [];

  const homepageImage =
    homepageBlock &&
    homepageType === "image" &&
    typeof homepageBlock.mediaUrl === "string" &&
    homepageBlock.mediaUrl.trim()
      ? resolveImageUrl(homepageBlock.mediaUrl.trim(), origin)
      : "";

  const homepageVideoUrl =
    homepageBlock &&
    homepageType === "video" &&
    typeof homepageBlock.mediaUrl === "string" &&
    homepageBlock.mediaUrl.trim()
      ? resolveImageUrl(homepageBlock.mediaUrl.trim(), origin)
      : "";
  const videoUrls =
    homepageVideoUrl && !itemVideoUrls.includes(homepageVideoUrl)
      ? [homepageVideoUrl, ...itemVideoUrls]
      : itemVideoUrls;
  const videoUrl = homepageVideoUrl || videoUrls[0] || "";

  const audioUrl =
    homepageBlock &&
    homepageType === "audio" &&
    typeof homepageBlock.mediaUrl === "string" &&
    homepageBlock.mediaUrl.trim()
      ? resolveImageUrl(homepageBlock.mediaUrl.trim(), origin)
      : "";

  const homepageVsImage =
    homepageBlock &&
    homepageType === "vs" &&
    typeof homepageBlock.mediaUrl === "string" &&
    homepageBlock.mediaUrl.trim()
      ? resolveImageUrl(homepageBlock.mediaUrl.trim(), origin)
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
  const vsData = normalizeVsData(item, origin);
  const quoteData =
    homepageType === "quote"
      ? normalizeQuoteData(homepageBlock)
      : itemType === "paragraph"
        ? normalizeQuoteData(item)
        : undefined;

  const usingHomepageMedia =
    Boolean(homepageImage) || sliderImages.length > 0 || Boolean(homepageVsImage);
  const fallbackImage = socialEmbed
    ? String(optimizedImage?.src || item.coverThumbnail || item.thumbnail || "")
    : firstMediaUrl(item);
  const imageUrl =
    homepageImage ||
    sliderImages[0] ||
    homepageVsImage ||
    reviewData?.productImage ||
    resolveImageUrl(fallbackImage, origin);

  return {
    id: String(item.id || ""),
    category: String(item.category || ""),
    title: String(item.title || ""),
    summary: String(item.summary || ""),
    imageUrl,
    sliderImages,
    videoUrl,
    videoUrls,
    audioUrl,
    socialEmbed,
    socialSourceUrl,
    socialPlatform,
    flipData: item.flipData
      ? {
          ...item.flipData,
          frontImage: resolveImageUrl(item.flipData.frontImage, origin),
          backImage: resolveImageUrl(item.flipData.backImage, origin),
        }
      : undefined,
    beforeAfterData: item.beforeAfterData
      ? {
          ...item.beforeAfterData,
          beforeImage: resolveImageUrl(item.beforeAfterData.beforeImage, origin),
          afterImage: resolveImageUrl(item.beforeAfterData.afterImage, origin),
        }
      : undefined,
    reviewData,
    pollData,
    vsData,
    quoteData,
    publishedAt: toIsoDate(item.timestamp),
    source: String(item.source || item.author || "Pateeznews"),
    sourceAvatar: resolveImageUrl(String(raw.sourceAvatar || ""), origin),
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

export const GET: APIRoute = async ({ url, request }) => {
  try {
    const lang = String(url.searchParams.get("lang") || "tr").trim() || "tr";
    const limit = numberParam(url.searchParams.get("limit"), 10, 1, 20);
    const feedLimit = numberParam(url.searchParams.get("feedLimit"), 30, 1, 50);

    const origin = new URL(request.url).origin;
    const session = await getSessionFromRequest(request);
    const userId = session?.user?.id || null;
    const items = await dataService.getNewsItems(lang, "home", 50);

    const mansetItems = items
      .filter((item: NewsItem) => item.isManset === true)
      .sort((a: NewsItem, b: NewsItem) => getNewsTime(b) - getNewsTime(a));
    const hiddenMansetIds = new Set(
      mansetItems.slice(0, 20).map((item: NewsItem) => String(item.id)),
    );

    const featured = mansetItems
      .slice(0, limit)
      .map((item: NewsItem) => mapFeaturedItem(item, origin));
    const feedItems = items
      .filter((item: NewsItem) => !hiddenMansetIds.has(String(item.id)))
      .slice(0, feedLimit);
    const feedPostIds = feedItems
      .map((item: NewsItem) => Number(item.id))
      .filter((id: number) => Number.isInteger(id) && id > 0);
    const [commentPreviewByPost, approvedCommentCountsByPost, viewerStateByPost] =
      await Promise.all([
        loadPreviewComments(feedPostIds, origin, userId),
        loadApprovedCommentCounts(feedPostIds),
        loadViewerPostStates(feedPostIds, userId),
      ]);
    const feed = feedItems.map((item: NewsItem) =>
      mapFeedItem(
        item,
        origin,
        commentPreviewByPost.get(String(item.id || "")) || [],
        approvedCommentCountsByPost.get(String(item.id || "")) ?? 0,
        viewerStateByPost.get(String(item.id || "")),
      ),
    );

    return json({ featured, feed });
  } catch (error: any) {
    return json(
      { error: { message: error?.message || "Home fetch failed" } },
      500,
    );
  }
};
