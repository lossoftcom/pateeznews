import { createClient } from '@supabase/supabase-js';

const SUPABASE_URL = "https://glrvuonvwmiclusrrjtj.supabase.co";
const SUPABASE_ANON_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImdscnZ1b252d21pY2x1c3JyanRqIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjcwMjMxMjAsImV4cCI6MjA4MjU5OTEyMH0.tDfzQbEH07ANXOMKAS-ob2PFfNpVPjzv1izHZRd3K4g";
const supabase = createClient(SUPABASE_URL, SUPABASE_ANON_KEY);

var NewsType = /* @__PURE__ */ ((NewsType2) => {
  NewsType2["VIDEO"] = "VIDEO";
  NewsType2["AUDIO"] = "AUDIO";
  NewsType2["GALLERY"] = "GALLERY";
  NewsType2["EMBED"] = "EMBED";
  NewsType2["STANDARD"] = "STANDARD";
  NewsType2["POLL"] = "POLL";
  NewsType2["QUIZ"] = "QUIZ";
  NewsType2["VS"] = "VS";
  NewsType2["IMAGE"] = "IMAGE";
  NewsType2["FLIP_CARD"] = "FLIP_CARD";
  NewsType2["BEFORE_AFTER"] = "BEFORE_AFTER";
  NewsType2["REVIEW"] = "REVIEW";
  NewsType2["PARAGRAPH"] = "PARAGRAPH";
  return NewsType2;
})(NewsType || {});

const normalizeNewsType = (value) => {
  const raw = String(value ?? "").trim();
  const normalized = raw.replace(/[\s-]+/g, "_").toUpperCase();
  switch (normalized) {
    case "ARTICLE":
    case "POST":
    case "NEWS":
    case "":
      return NewsType.STANDARD;
    case "VIDEO":
      return NewsType.VIDEO;
    case "AUDIO":
      return NewsType.AUDIO;
    case "GALLERY":
      return NewsType.GALLERY;
    case "EMBED":
    case "IFRAME":
    case "SOCIAL":
      return NewsType.EMBED;
    case "POLL":
      return NewsType.POLL;
    case "QUIZ":
      return NewsType.QUIZ;
    case "VS":
      return NewsType.VS;
    case "IMAGE":
      return NewsType.IMAGE;
    case "FLIP_CARD":
    case "FLIPCARD":
      return NewsType.FLIP_CARD;
    case "BEFORE_AFTER":
    case "BEFOREAFTER":
      return NewsType.BEFORE_AFTER;
    case "REVIEW":
      return NewsType.REVIEW;
    case "PARAGRAPH":
    case "QUOTE":
      return NewsType.PARAGRAPH;
    default:
      return NewsType.STANDARD;
  }
};
const CACHE_TTL = {
  SETTINGS: 1e3 * 60 * 10,
  // 10 minutes
  NAV: 1e3 * 60 * 5,
  // 5 minutes
  NEWS: 1e3 * 30,
  // 30 seconds
  STORIES: 1e3 * 60
  // 1 minute
};
const cache = {};
const inflight = {};
const withCache = async (key, ttl, fetcher) => {
  const now = Date.now();
  if (cache[key] && cache[key].expiry > now) {
    return cache[key].data;
  }
  if (inflight[key]) return inflight[key];
  const promise = (async () => {
    try {
      const data = await fetcher();
      cache[key] = { data, expiry: Date.now() + ttl };
      return data;
    } finally {
      delete inflight[key];
    }
  })();
  inflight[key] = promise;
  return promise;
};
const dataService = {
  async getSiteSettings(lang) {
    return withCache(`settings_${lang}`, CACHE_TTL.SETTINGS, async () => {
      const { data, error } = await supabase.from("site_settings").select("*").eq("language_code", lang).single();
      if (error) {
        console.error("Error fetching site settings:", error);
        return null;
      }
      return data;
    });
  },
  async getSeoAlternates() {
    return withCache("seo_alternates", CACHE_TTL.SETTINGS, async () => {
      const fallback = [{ code: "tr", name: "Türkçe", direction: "ltr", flagCode: "tr", isDefault: true }];
      const { data: langs, error: langsError } = await supabase.from("languages").select("code, is_default, status, name, direction, flag_code").eq("status", "active");
      const normalizedLangs = langsError || !langs || langs.length === 0 ? fallback : langs.map((l) => {
        const code = String(l?.code || "").trim();
        if (!code) return null;
        const name = String(l?.name || "").trim() || code.toUpperCase();
        const direction = String(l?.direction || "").trim() === "rtl" ? "rtl" : "ltr";
        const flagCode = String(l?.flag_code || "").trim() || code;
        return { code, name, direction, flagCode, isDefault: !!l?.is_default };
      }).filter(Boolean);
      if (normalizedLangs.length > 0 && !normalizedLangs.some((l) => l.isDefault)) {
        normalizedLangs[0].isDefault = true;
      }
      const codes = normalizedLangs.map((l) => l.code).filter((code) => !!code);
      const { data: settings, error: settingsError } = await supabase.from("site_settings").select("language_code, canonical_url").in("language_code", codes);
      if (settingsError) {
        return normalizedLangs.map((l) => ({
          ...l,
          canonicalUrl: ""
        }));
      }
      const canonicalMap = /* @__PURE__ */ new Map();
      for (const row of settings || []) {
        const code = String(row.language_code || "").trim();
        if (!code) continue;
        canonicalMap.set(code, String(row.canonical_url || "").trim());
      }
      const result = normalizedLangs.map((l) => ({
        ...l,
        canonicalUrl: canonicalMap.get(l.code) || ""
      }));
      result.sort((a, b) => {
        if (a.isDefault !== b.isDefault) return a.isDefault ? -1 : 1;
        return a.code.localeCompare(b.code);
      });
      return result;
    });
  },
  async getNavigationItems(lang) {
    return withCache(`nav_${lang}`, CACHE_TTL.NAV, async () => {
      const { data, error } = await supabase.from("navigation_items").select("*").eq("language_code", lang).eq("is_active", true).order("order_index", { ascending: true });
      if (error) {
        console.error("Error fetching navigation items:", error);
        return [];
      }
      return data || [];
    });
  },
  async getNewsItems(lang, category, limit = 50) {
    const cacheKey = `news_${lang}_${Array.isArray(category) ? category.join(",") : category || "home"}_${limit}`;
    return withCache(cacheKey, CACHE_TTL.NEWS, async () => {
      let query = supabase.from("posts").select(`id, created_at, published_at, updated_at, publisher_id, title, summary, category, type, thumbnail_url, thumbnail_alt, media_url, likes_count, dislikes_count, comments_count, shares_count, slug, status, seo_title, seo_description, keywords, language_code, is_pinned, fact_checked, schema_type, card_data, profiles:publisher_id (id, username, full_name, avatar_url, role)`).eq("status", "published").eq("language_code", lang).order("is_pinned", { ascending: false }).order("published_at", { ascending: false });
      if (category && category !== "home") {
        if (Array.isArray(category)) {
          query = query.in("category", category);
        } else {
          const catLower = category.toLowerCase();
          query = query.or(`category.eq.${category},category.eq.${catLower},category.ilike.%${category}%`);
        }
      }
      const { data, error } = await query.limit(limit);
      if (error) {
        console.error("Error fetching news items:", error);
        return [];
      }
      return (data || []).map((post) => this.mapPost(post));
    });
  },
  async getNewsBySlug(slugOrId) {
    const normalized = String(slugOrId || "").trim();
    if (!normalized) return null;
    const selectClause = `*, profiles:publisher_id (id, username, full_name, avatar_url, role)`;
    const slugRes = await supabase.from("posts").select(selectClause).eq("slug", normalized).maybeSingle();
    if (slugRes.data) return this.mapPost(slugRes.data);
    if (/^[0-9]+$/.test(normalized)) {
      const idRes = await supabase.from("posts").select(selectClause).eq("id", normalized).maybeSingle();
      if (idRes.data) return this.mapPost(idRes.data);
    }
    return null;
  },
  mapPost(post) {
    const rawPostType = typeof post?.type === "string" ? post.type : "";
    const cardData = post?.card_data && typeof post.card_data === "object" ? post.card_data : {};
    const typeFromCard = cardData?.type;
    const resolvedType = normalizeNewsType(typeFromCard ?? rawPostType);
    const itemsRaw = post?.items ?? cardData?.items;
    const itemsArray = Array.isArray(itemsRaw) ? itemsRaw : [];
    const faqFromItems = itemsArray.find((item) => item?.type === "faq" && item?.faqData)?.faqData;
    const baseSource = post?.profiles?.full_name || post?.profiles?.username || "Pateez";
    const baseAuthor = post?.profiles?.full_name || post?.profiles?.username || "Pateez";
    const merged = {
      ...cardData,
      id: String(post?.id ?? ""),
      type: resolvedType,
      postType: rawPostType,
      title: cardData?.title ?? post?.title ?? "",
      summary: cardData?.summary ?? post?.summary ?? "",
      content: cardData?.content ?? post?.content ?? "",
      category: cardData?.category ?? post?.category ?? "",
      source: cardData?.source ?? baseSource,
      author: cardData?.author ?? baseAuthor,
      timestamp: post?.published_at || post?.created_at,
      mediaUrl: cardData?.mediaUrl ?? post?.media_url ?? "",
      thumbnail: cardData?.thumbnail ?? post?.thumbnail_url ?? "",
      thumbnailAlt: post?.thumbnail_alt ?? cardData?.thumbnailAlt,
      likes: post?.likes_count ?? cardData?.likes ?? 0,
      dislikes: post?.dislikes_count ?? cardData?.dislikes ?? 0,
      comments: post?.comments_count ?? cardData?.comments ?? 0,
      shares: post?.shares_count ?? cardData?.shares ?? 0,
      views: cardData?.views ?? 0,
      seoTitle: post?.seo_title ?? cardData?.seoTitle,
      seoDescription: post?.seo_description ?? cardData?.seoDescription,
      keywords: post?.keywords ?? cardData?.keywords,
      slug: post?.slug ?? cardData?.slug,
      factChecked: post?.fact_checked ?? cardData?.factChecked,
      schemaType: post?.schema_type ?? cardData?.schemaType,
      faqData: post?.faq_data ?? cardData?.faqData ?? faqFromItems,
      items: itemsRaw,
      sourceAvatar: post?.profiles?.avatar_url || cardData?.sourceAvatar || "",
      isPinned: post?.is_pinned ?? cardData?.isPinned ?? false,
      publisherId: post?.publisher_id ?? cardData?.publisherId
    };
    const items = Array.isArray(merged.items) ? merged.items : [];
    const coverFromItems = items.find(
      (item) => item && item.type === "image" && typeof item.mediaUrl === "string" && item.mediaUrl && (item.showOnHomepage || item.orderNumber === 1)
    );
    merged.coverThumbnail = cardData?.coverThumbnail ?? coverFromItems?.mediaUrl ?? merged.thumbnail;
    if (resolvedType === NewsType.GALLERY && (!merged.mediaList || merged.mediaList.length === 0)) {
      const slider = items.find((item) => item?.type === "slider" && Array.isArray(item?.mediaUrls));
      if (slider?.mediaUrls) merged.mediaList = slider.mediaUrls;
    }
    if (resolvedType === NewsType.VIDEO && !merged.mediaUrl) {
      const video = items.find((item) => item?.type === "video" && typeof item?.mediaUrl === "string");
      if (video?.mediaUrl) merged.mediaUrl = video.mediaUrl;
    }
    if (resolvedType === NewsType.AUDIO && !merged.mediaUrl) {
      const audio = items.find((item) => item?.type === "audio" && typeof item?.mediaUrl === "string");
      if (audio?.mediaUrl) merged.mediaUrl = audio.mediaUrl;
    }
    return merged;
  },
  async getStories(lang) {
    return withCache(`stories_${lang}`, CACHE_TTL.STORIES, async () => {
      const { data, error } = await supabase.from("stories").select("*").eq("is_active", true).order("created_at", { ascending: false });
      if (error) {
        console.error("Error fetching stories:", error);
        return [];
      }
      return data || [];
    });
  }
};

export { NewsType as N, dataService as d, supabase as s };
