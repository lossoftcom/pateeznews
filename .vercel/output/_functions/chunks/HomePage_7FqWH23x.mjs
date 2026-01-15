import { jsx, jsxs, Fragment } from 'react/jsx-runtime';
import React, { useMemo, useState, useEffect, useCallback, useRef } from 'react';
import { u as useLanguage, n as navigate, a as useToast, p as prefetch, L as LanguageProvider, T as ToastProvider } from './Layout_DohV3HSJ.mjs';
import { s as slugify, i as isPostId, g as getRelativeTime } from './helpers_xme2WEyl.mjs';
import { Zap, ArrowLeft, Search, LayoutGrid, TrendingUp, MapPin, Flame } from 'lucide-react';
import { s as supabase, N as NewsType, d as dataService } from './dataService_CXfGU90R.mjs';
import { S as Skeleton, C as CommentSection, b as ParagraphCard, a as VSCard, P as PollCard, G as GalleryCard, V as VideoCard, A as AudioCard, E as EmbedCard, F as FlipCard, B as BeforeAfterCard, R as ReviewCard, c as RightSidebar } from './RightSidebar_BSnntYD2.mjs';

const Footer = () => {
  const { t } = useLanguage();
  return /* @__PURE__ */ jsx("div", { className: "px-3 mt-4", children: /* @__PURE__ */ jsx("p", { className: "text-[11px] text-gray-400", children: t("footer.rights") }) });
};

const ICON_COLORS = [
  "#FF6B00",
  "#448AFF",
  "#9C27B0",
  "#E91E63",
  "#3F51B5",
  "#00BCD4",
  "#4CAF50",
  "#FF5252",
  "#FF9800",
  "#673AB7",
  "#2196F3",
  "#009688"
];
const Sidebar = ({
  items,
  activeCategory,
  onCategoryItemClick,
  onAllCategoriesClick,
  onAllDistrictsClick,
  onAllTrendsClick,
  loading
}) => {
  const { t } = useLanguage();
  const navigateToCategory = (category) => {
    if (onCategoryItemClick) {
      onCategoryItemClick(category);
      return;
    }
    if (!category || category === "home" || category === "null") {
      void navigate();
      return;
    }
    void navigate(`/kategori/${slugify(category)}`);
  };
  const rootItems = useMemo(() => {
    return items.filter((i) => !i.parent_id || i.parent_id === "root").sort((a, b) => a.order_index - b.order_index);
  }, [items]);
  const selectedItem = useMemo(() => {
    if (!activeCategory) return null;
    const normalizedSlug = slugify(activeCategory);
    return items.find(
      (i) => i.value === activeCategory || i.label === activeCategory || i.value && slugify(i.value) === normalizedSlug || i.label && slugify(i.label) === normalizedSlug
    );
  }, [activeCategory, items]);
  const findRootId = (itemId) => {
    if (!itemId) return null;
    const item = items.find((i) => i.id === itemId);
    if (!item) return null;
    if (!item.parent_id || item.parent_id === "root") return item.id;
    return findRootId(item.parent_id);
  };
  const selectedRootId = useMemo(() => selectedItem ? findRootId(selectedItem.id) : null, [selectedItem, items]);
  const children = useMemo(() => {
    if (!selectedRootId) return [];
    return items.filter((i) => i.parent_id === selectedRootId).sort((a, b) => a.order_index - b.order_index);
  }, [selectedRootId, items]);
  const districts = children.filter((c) => c.type === "district");
  const categoriesSub = children.filter(
    (c) => c.type === "category" || c.type === "dropdown" || c.type === "link" || !c.type
  );
  const trendsSub = children.filter((c) => c.type === "trends");
  const renderIcon = (iconName, size = 20, color, isSelected = false) => {
    if (!iconName) return null;
    return /* @__PURE__ */ jsx(
      "span",
      {
        className: "material-symbols-rounded transition-all duration-300",
        style: {
          fontSize: `${size}px`,
          color: isSelected ? "inherit" : color || "inherit",
          fontWeight: isSelected ? "700" : "500"
        },
        children: iconName.toLowerCase()
      }
    );
  };
  return /* @__PURE__ */ jsxs("div", { className: "w-[300px] h-full flex flex-col border-r border-palette-beige/20 overflow-y-auto overflow-x-hidden no-scrollbar pt-4 pb-8 gap-10", children: [
    /* @__PURE__ */ jsx("div", { className: "px-3", children: /* @__PURE__ */ jsx("div", { className: "flex flex-col gap-1", children: rootItems.map((item, index) => {
      const isActive = selectedRootId === item.id;
      const iconColor = ICON_COLORS[index % ICON_COLORS.length];
      return /* @__PURE__ */ jsx(
        "button",
        {
          onClick: () => navigateToCategory(item.value || item.label || null),
          className: `w-full relative flex items-center py-2.5 px-3 rounded-[5px] transition-all group ${isActive ? "text-palette-red bg-palette-beige/5" : "text-gray-600 hover:bg-palette-beige/10"}`,
          children: /* @__PURE__ */ jsxs("div", { className: "flex items-center gap-3", children: [
            /* @__PURE__ */ jsx("div", { className: `transition-all duration-150 ${isActive ? "text-emerald-500 scale-110" : "text-gray-400"}`, children: renderIcon(isActive ? "where_to_vote" : item.icon || "grid_view", 20, isActive ? void 0 : iconColor, isActive) }),
            /* @__PURE__ */ jsx("span", { className: `text-[14px] font-bold tracking-tight ${isActive ? "text-gray-900 font-black" : ""}`, children: t(item.label) })
          ] })
        },
        item.id
      );
    }) }) }),
    selectedRootId && /* @__PURE__ */ jsxs("div", { className: "flex flex-col gap-8", children: [
      districts.length > 0 && /* @__PURE__ */ jsxs("div", { className: "px-3", children: [
        /* @__PURE__ */ jsxs(
          "h3",
          {
            onClick: onAllDistrictsClick,
            className: "text-[10px] font-black text-palette-tan/40 uppercase tracking-[0.2em] mb-3 ml-1 cursor-pointer hover:text-palette-red transition-all flex items-center gap-2 group/dis-header",
            children: [
              t("sidebar.districts"),
              /* @__PURE__ */ jsx("span", { className: "material-symbols-rounded text-[12px] opacity-0 group-hover/dis-header:opacity-100 transition-all translate-x-[-4px] group-hover/dis-header:translate-x-0", children: "chevron_right" })
            ]
          }
        ),
        /* @__PURE__ */ jsx("div", { className: "flex flex-col gap-1", children: districts.map((child, idx) => {
          const isActive = activeCategory === child.value || activeCategory === child.label;
          const iconColor = ICON_COLORS[(idx + 8) % ICON_COLORS.length];
          return /* @__PURE__ */ jsxs(
            "button",
            {
              onClick: () => navigateToCategory(child.value || child.label || null),
              className: `w-full flex items-center gap-3 py-2 px-3 rounded-[5px] transition-all group ${isActive ? "text-palette-red bg-palette-beige/5" : "text-gray-600 hover:bg-palette-beige/10"}`,
              children: [
                /* @__PURE__ */ jsx("div", { className: `transition-all duration-150 ${isActive ? "text-emerald-500 scale-110" : ""}`, children: renderIcon(isActive ? "where_to_vote" : child.icon || "location_on", 18, isActive ? void 0 : iconColor, isActive) }),
                /* @__PURE__ */ jsx("span", { className: `text-[13px] font-bold tracking-tight ${isActive ? "text-gray-900 font-black" : ""}`, children: t(child.label) })
              ]
            },
            child.id
          );
        }) })
      ] }),
      categoriesSub.length > 0 && /* @__PURE__ */ jsxs("div", { className: "px-3", children: [
        /* @__PURE__ */ jsxs(
          "h3",
          {
            onClick: onAllCategoriesClick,
            className: "text-[10px] font-black text-palette-tan/40 uppercase tracking-[0.2em] mb-3 ml-1 cursor-pointer hover:text-palette-red transition-all flex items-center gap-2 group/cat-header",
            children: [
              t("sidebar.categories"),
              /* @__PURE__ */ jsx("span", { className: "material-symbols-rounded text-[12px] opacity-0 group-hover/cat-header:opacity-100 transition-all translate-x-[-4px] group-hover/cat-header:translate-x-0", children: "chevron_right" })
            ]
          }
        ),
        /* @__PURE__ */ jsx("div", { className: "flex flex-col gap-1", children: categoriesSub.map((child, idx) => {
          const isActive = activeCategory === child.value || activeCategory === child.label;
          const iconColor = ICON_COLORS[(idx + 5) % ICON_COLORS.length];
          return /* @__PURE__ */ jsxs(
            "button",
            {
              onClick: () => navigateToCategory(child.value || child.label || null),
              className: `w-full flex items-center gap-3 py-2 px-3 rounded-[5px] transition-all group ${isActive ? "text-palette-red" : "text-gray-600 hover:bg-palette-beige/10"}`,
              children: [
                /* @__PURE__ */ jsx("div", { className: `transition-colors ${isActive ? "text-palette-red" : ""}`, children: renderIcon(child.icon || "grid_view", 18, iconColor, isActive) }),
                /* @__PURE__ */ jsx("span", { className: `text-[13px] font-bold tracking-tight ${isActive ? "text-gray-900 font-black" : ""}`, children: t(child.label) })
              ]
            },
            child.id
          );
        }) })
      ] }),
      trendsSub.length > 0 && /* @__PURE__ */ jsxs("div", { className: "px-3", children: [
        /* @__PURE__ */ jsxs(
          "h3",
          {
            onClick: onAllTrendsClick,
            className: "text-[10px] font-black text-palette-tan/40 uppercase tracking-[0.2em] mb-3 ml-1 cursor-pointer hover:text-palette-red transition-all flex items-center gap-2 group/trend-header",
            children: [
              t("cat.trends"),
              /* @__PURE__ */ jsx("span", { className: "material-symbols-rounded text-[12px] opacity-0 group-hover/trend-header:opacity-100 transition-all translate-x-[-4px] group-hover/trend-header:translate-x-0", children: "chevron_right" })
            ]
          }
        ),
        /* @__PURE__ */ jsx("div", { className: "flex flex-col gap-1", children: trendsSub.map((child, idx) => {
          const isActive = activeCategory === child.value || activeCategory === child.label;
          const iconColor = ICON_COLORS[(idx + 2) % ICON_COLORS.length];
          return /* @__PURE__ */ jsxs(
            "button",
            {
              onClick: () => navigateToCategory(child.value || child.label || null),
              className: `w-full flex items-center gap-3 py-2 px-3 rounded-[5px] transition-all group ${isActive ? "text-palette-red" : "text-gray-600 hover:bg-palette-beige/10"}`,
              children: [
                /* @__PURE__ */ jsx("div", { className: `transition-colors ${isActive ? "text-palette-red" : ""}`, children: renderIcon(child.icon || "trending_up", 18, iconColor, isActive) }),
                /* @__PURE__ */ jsx("span", { className: `text-[13px] font-bold tracking-tight ${isActive ? "text-gray-900 font-black" : ""}`, children: t(child.label) })
              ]
            },
            child.id
          );
        }) })
      ] })
    ] }),
    /* @__PURE__ */ jsx(Footer, {})
  ] });
};

const StoryBar = ({ initialStories }) => {
  const [stories, setStories] = useState(initialStories || []);
  const [loading, setLoading] = useState(!initialStories || initialStories.length === 0);
  useEffect(() => {
    if (initialStories && initialStories.length > 0) {
      setStories(initialStories);
      setLoading(false);
      return;
    }
    const fetchStories = async () => {
      try {
        setLoading(true);
        const { data, error } = await supabase.from("stories").select("*").eq("is_active", true).order("created_at", { ascending: false });
        if (!error && data) {
          setStories(data);
        }
      } catch (err) {
        console.error("Error fetching stories:", err);
      } finally {
        setLoading(false);
      }
    };
    fetchStories();
  }, [initialStories]);
  if (loading) {
    return /* @__PURE__ */ jsx("div", { className: "w-full pb-1 pt-2", children: /* @__PURE__ */ jsx("div", { className: "flex gap-2 overflow-x-auto px-1 pb-4 no-scrollbar items-start", children: [1, 2, 3, 4, 5, 6].map((i) => /* @__PURE__ */ jsx("div", { className: "flex-shrink-0 w-[120px] h-[200px] rounded-[5px] bg-palette-beige/5 animate-pulse border border-palette-beige/10" }, i)) }) });
  }
  if (stories.length === 0) return null;
  return /* @__PURE__ */ jsx("div", { className: "w-full pb-1 pt-2", children: /* @__PURE__ */ jsx("div", { className: "flex gap-2 overflow-x-auto px-1 pb-4 no-scrollbar items-start", children: stories.map((story) => /* @__PURE__ */ jsxs(
    "div",
    {
      className: "group relative flex-shrink-0 w-[120px] h-[200px] rounded-[5px] cursor-pointer transition-all duration-75 hover:-translate-y-1.5",
      children: [
        /* @__PURE__ */ jsx("div", { className: "absolute inset-2 bg-blue-500/20 rounded-[5px] blur-xl opacity-0 group-hover:opacity-100 transition-opacity duration-100" }),
        /* @__PURE__ */ jsxs("div", { className: "relative w-full h-full rounded-[5px] overflow-hidden shadow-sm hover:shadow-xl border border-gray-100 bg-gray-900 transition-all duration-100 z-10", children: [
          /* @__PURE__ */ jsx(
            "img",
            {
              src: story.media_url || story.image,
              alt: story.title,
              className: "w-full h-full object-cover opacity-90 group-hover:opacity-100 group-hover:scale-110 transition-transform duration-200 ease-out"
            }
          ),
          /* @__PURE__ */ jsx("div", { className: "absolute inset-0 bg-gradient-to-t from-black/90 via-black/20 to-transparent" }),
          /* @__PURE__ */ jsx("div", { className: "absolute inset-0 bg-gradient-to-b from-black/30 via-transparent to-transparent opacity-60" }),
          /* @__PURE__ */ jsx("div", { className: "absolute top-3 left-3 flex items-center gap-1.5", children: /* @__PURE__ */ jsx("div", { className: "relative w-8 h-8 p-[1.5px] rounded-[5px] bg-gradient-to-tr from-blue-400 to-purple-500 shadow-lg", children: /* @__PURE__ */ jsx("div", { className: "w-full h-full rounded-[5px] overflow-hidden border border-black/20", children: /* @__PURE__ */ jsx(
            "img",
            {
              src: `https://picsum.photos/seed/src${story.id}/100`,
              alt: "Source",
              className: "w-full h-full object-cover"
            }
          ) }) }) }),
          /* @__PURE__ */ jsxs("div", { className: "absolute bottom-0 left-0 w-full p-3.5 pt-6 bg-gradient-to-t from-black/80 via-black/40 to-transparent", children: [
            /* @__PURE__ */ jsxs("div", { className: "flex items-center gap-1 mb-1.5 opacity-80", children: [
              /* @__PURE__ */ jsx(Zap, { size: 10, className: "text-yellow-400 fill-yellow-400" }),
              /* @__PURE__ */ jsx("span", { className: "text-[9px] font-black text-blue-200 uppercase tracking-widest", children: story.source_name || story.source || "Pateez" })
            ] }),
            /* @__PURE__ */ jsx("p", { className: "text-[11px] font-bold text-white leading-snug line-clamp-3 drop-shadow-sm group-hover:text-blue-50 transition-colors", children: story.title })
          ] }),
          /* @__PURE__ */ jsx("div", { className: "absolute inset-0 rounded-[5px] border-2 border-white/0 group-hover:border-white/20 transition-all duration-300 pointer-events-none" })
        ] })
      ]
    },
    story.id
  )) }) });
};

const StandardCard = ({ data }) => {
  return /* @__PURE__ */ jsxs("div", { className: "mt-1 space-y-3 overflow-hidden", children: [
    /* @__PURE__ */ jsx("div", { className: "px-1 mb-3", children: /* @__PURE__ */ jsx(
      "div",
      {
        className: "rich-text-content text-gray-600/80 text-[16px] leading-relaxed font-medium text-left [&>p]:mb-0",
        dangerouslySetInnerHTML: { __html: data.summary }
      }
    ) }),
    /* @__PURE__ */ jsx("div", { className: "relative rounded-lg overflow-hidden group flex items-center justify-center", children: /* @__PURE__ */ jsx(
      "img",
      {
        src: data.optimizedThumbnail?.src || data.thumbnail,
        srcSet: data.optimizedThumbnail?.srcSet,
        sizes: data.optimizedThumbnail?.sizes,
        alt: data.thumbnailAlt || data.seoTitle || data.title,
        className: "w-auto h-auto max-w-full max-h-[400px] object-contain transition-transform duration-1000 group-hover:scale-[1.02] mx-auto"
      }
    ) })
  ] });
};

const NewsCard = ({ data, onClick, onSourceClick, siteSettings, navItems }) => {
  const { t, currentLang } = useLanguage();
  const { showToast } = useToast();
  const detailHref = useMemo(() => {
    const slugOrId = data.slug || data.id;
    return `/haber/${encodeURIComponent(slugOrId)}`;
  }, [data.id, data.slug]);
  const categoryHierarchy = useMemo(() => {
    if (!data.category || !navItems) return [data.category];
    const findItem = (label) => navItems.find((n) => n.label === label || n.value === label);
    let currentItem = findItem(data.category);
    if (!currentItem) return [data.category];
    const hierarchy = [currentItem.label];
    let parentId = currentItem.parent_id;
    while (parentId && parentId !== "root") {
      const parent = navItems.find((n) => n.id === parentId);
      if (parent) {
        hierarchy.unshift(parent.label);
        parentId = parent.parent_id;
      } else {
        break;
      }
    }
    return hierarchy;
  }, [data.category, navItems]);
  const [isLiked, setIsLiked] = useState(data.userLiked || false);
  const [isDisliked, setIsDisliked] = useState(data.userDisliked || false);
  const [showComments, setShowComments] = useState(true);
  const [isBookmarked, setIsBookmarked] = useState(data.userSaved || false);
  const [likesCount, setLikesCount] = useState(data.likes || 0);
  const [dislikesCount, setDislikesCount] = useState(data.dislikes || 0);
  const [savesCount, setSavesCount] = useState(data.shares || 0);
  const [isLoading, setIsLoading] = useState(false);
  const [userId, setUserId] = useState(null);
  const [publisherId, setPublisherId] = useState(data.publisherId || null);
  const [isFollowing, setIsFollowing] = useState(data.isFollowingPublisher || false);
  useEffect(() => {
    let isMounted = true;
    const checkUserAndStatus = async () => {
      if (!isPostId(data.id)) return;
      try {
        const { data: { session } } = await supabase.auth.getSession();
        const user = session?.user;
        if (user && isMounted) {
          setUserId(user.id);
          const [likeRes, saveRes, dislikeRes, postRes] = await Promise.all([
            supabase.from("post_likes").select("id").eq("post_id", data.id).eq("user_id", user.id).maybeSingle(),
            supabase.from("post_saves").select("id").eq("post_id", data.id).eq("user_id", user.id).maybeSingle(),
            supabase.from("post_dislikes").select("id").eq("post_id", data.id).eq("user_id", user.id).maybeSingle(),
            supabase.from("posts").select("publisher_id, dislikes_count").eq("id", data.id).maybeSingle()
          ]);
          if (!isMounted) return;
          if (likeRes.data) setIsLiked(true);
          if (saveRes.data) setIsBookmarked(true);
          if (dislikeRes.data) setIsDisliked(true);
          if (postRes.data) {
            if (postRes.data.dislikes_count) setDislikesCount(postRes.data.dislikes_count);
            if (postRes.data.publisher_id) {
              setPublisherId(postRes.data.publisher_id);
              const { data: followData } = await supabase.from("publisher_follows").select("id").eq("publisher_id", postRes.data.publisher_id).eq("user_id", user.id).maybeSingle();
              if (followData && isMounted) setIsFollowing(true);
            }
          }
        }
      } catch (error) {
        console.error("Error checking user status:", error);
      }
    };
    checkUserAndStatus();
    return () => {
      isMounted = false;
    };
  }, [data.id]);
  const handleLike = useCallback(async (e) => {
    e.stopPropagation();
    if (isLoading) return;
    if (!userId || !isPostId(data.id)) {
      if (!userId) showToast(t("auth.login_required_like"), "info");
      return;
    }
    const newIsLiked = !isLiked;
    const wasDisliked = isDisliked;
    setIsLiked(newIsLiked);
    setLikesCount((prev) => newIsLiked ? prev + 1 : Math.max(0, prev - 1));
    if (newIsLiked && wasDisliked) {
      setIsDisliked(false);
      setDislikesCount((prev) => Math.max(0, prev - 1));
    }
    setIsLoading(true);
    try {
      if (newIsLiked) {
        await supabase.from("post_likes").insert({ post_id: data.id, user_id: userId });
        await supabase.from("posts").update({ likes_count: likesCount + 1 }).eq("id", data.id);
        if (wasDisliked) {
          await supabase.from("post_dislikes").delete().eq("post_id", data.id).eq("user_id", userId);
          await supabase.from("posts").update({ dislikes_count: Math.max(0, dislikesCount - 1) }).eq("id", data.id);
        }
      } else {
        await supabase.from("post_likes").delete().eq("post_id", data.id).eq("user_id", userId);
        await supabase.from("posts").update({ likes_count: Math.max(0, likesCount - 1) }).eq("id", data.id);
      }
    } catch (error) {
      setIsLiked(!newIsLiked);
      setLikesCount((prev) => newIsLiked ? Math.max(0, prev - 1) : prev + 1);
      if (newIsLiked && wasDisliked) {
        setIsDisliked(true);
        setDislikesCount((prev) => prev + 1);
      }
      showToast(t("common.like_failed"), "error");
    } finally {
      setIsLoading(false);
    }
  }, [isLiked, isDisliked, isLoading, userId, data.id, likesCount, dislikesCount, showToast]);
  const handleDislike = useCallback(async (e) => {
    e.stopPropagation();
    if (isLoading) return;
    if (!userId || !isPostId(data.id)) {
      if (!userId) showToast(t("auth.login_required_dislike"), "info");
      return;
    }
    const newIsDisliked = !isDisliked;
    const wasLiked = isLiked;
    setIsDisliked(newIsDisliked);
    setDislikesCount((prev) => newIsDisliked ? prev + 1 : Math.max(0, prev - 1));
    if (newIsDisliked && wasLiked) {
      setIsLiked(false);
      setLikesCount((prev) => Math.max(0, prev - 1));
    }
    setIsLoading(true);
    try {
      if (newIsDisliked) {
        await supabase.from("post_dislikes").insert({ post_id: data.id, user_id: userId });
        await supabase.from("posts").update({ dislikes_count: dislikesCount + 1 }).eq("id", data.id);
        if (wasLiked) {
          await supabase.from("post_likes").delete().eq("post_id", data.id).eq("user_id", userId);
          await supabase.from("posts").update({ likes_count: Math.max(0, likesCount - 1) }).eq("id", data.id);
        }
      } else {
        await supabase.from("post_dislikes").delete().eq("post_id", data.id).eq("user_id", userId);
        await supabase.from("posts").update({ dislikes_count: Math.max(0, dislikesCount - 1) }).eq("id", data.id);
      }
    } catch (error) {
      setIsDisliked(!newIsDisliked);
      setDislikesCount((prev) => newIsDisliked ? Math.max(0, prev - 1) : prev + 1);
      if (newIsDisliked && wasLiked) {
        setIsLiked(true);
        setLikesCount((prev) => prev + 1);
      }
      showToast(t("common.dislike_failed"), "error");
    } finally {
      setIsLoading(false);
    }
  }, [isLiked, isDisliked, isLoading, userId, data.id, likesCount, dislikesCount, showToast]);
  const handleFollow = useCallback(async (e) => {
    e.stopPropagation();
    if (isLoading || !publisherId || !userId) {
      if (!userId) showToast(t("auth.login_required_follow"), "info");
      return;
    }
    const newIsFollowing = !isFollowing;
    setIsFollowing(newIsFollowing);
    setIsLoading(true);
    try {
      if (newIsFollowing) {
        await supabase.from("publisher_follows").insert({ publisher_id: publisherId, user_id: userId });
      } else {
        await supabase.from("publisher_follows").delete().eq("publisher_id", publisherId).eq("user_id", userId);
      }
    } catch (error) {
      setIsFollowing(!newIsFollowing);
      showToast(t("common.follow_failed"), "error");
    } finally {
      setIsLoading(false);
    }
  }, [isFollowing, isLoading, publisherId, userId, showToast]);
  const handleSave = useCallback(async (e) => {
    e.stopPropagation();
    if (isLoading) return;
    if (!userId || !isPostId(data.id)) {
      if (!userId) showToast(t("auth.login_required_bookmark"), "info");
      return;
    }
    const newIsBookmarked = !isBookmarked;
    setIsBookmarked(newIsBookmarked);
    setSavesCount((prev) => newIsBookmarked ? prev + 1 : prev - 1);
    setIsLoading(true);
    try {
      if (newIsBookmarked) {
        await supabase.from("post_saves").insert({ post_id: data.id, user_id: userId });
      } else {
        await supabase.from("post_saves").delete().eq("post_id", data.id).eq("user_id", userId);
      }
    } catch (error) {
      setIsBookmarked(!newIsBookmarked);
      setSavesCount((prev) => newIsBookmarked ? prev - 1 : prev + 1);
      showToast(t("common.bookmark_failed"), "error");
    } finally {
      setIsLoading(false);
    }
  }, [isBookmarked, isLoading, userId, data.id, showToast]);
  const [showShareMenu, setShowShareMenu] = useState(false);
  const handleShare = (e) => {
    e.stopPropagation();
    setShowShareMenu(!showShareMenu);
  };
  const shareMenuRef = useRef(null);
  useEffect(() => {
    const handleClickOutside = (event) => {
      if (shareMenuRef.current && !shareMenuRef.current.contains(event.target)) {
        setShowShareMenu(false);
      }
    };
    if (showShareMenu) {
      document.addEventListener("mousedown", handleClickOutside);
    }
    return () => {
      document.removeEventListener("mousedown", handleClickOutside);
    };
  }, [showShareMenu]);
  const shareUrl = typeof window !== "undefined" ? data.slug ? `${window.location.origin}/haber/${data.slug}` : `${window.location.origin}/post/${data.id}` : "";
  const getUtmUrl = (platform) => {
    const separator = shareUrl.includes("?") ? "&" : "?";
    return `${shareUrl}${separator}utm_source=${platform}&utm_medium=social&utm_campaign=share_card&utm_content=${data.id}`;
  };
  const getAIOptimizedText = () => {
    const stripHtml = (html) => html.replace(/<[^>]*>?/gm, "").replace(/&nbsp;/g, " ").trim();
    const cleanTitle = stripHtml(data.title);
    const cleanSummary = data.summary ? stripHtml(data.summary).substring(0, 100) : "";
    const siteName = siteSettings?.site_name?.replace(/\s+/g, "") || "Haber";
    const categoryTag = data.category ? `#${data.category.replace(/\s+/g, "")}` : `#${siteName}`;
    const siteKeywords = siteSettings?.meta_keywords ? siteSettings.meta_keywords.split(",").slice(0, 2).map((k) => `#${k.trim().replace(/\s+/g, "")}`).join(" ") : `#${siteName} #Gündem`;
    const summaryPart = cleanSummary ? `

"${cleanSummary}..."` : "";
    return `📢 ${cleanTitle}${summaryPart}

📌 ${categoryTag} ${siteKeywords}`;
  };
  const shareToWhatsApp = () => {
    const text = getAIOptimizedText();
    const url = getUtmUrl("whatsapp");
    const finalMessage = `${text}

🔗 Hemen oku: ${url}`;
    const waUrl = `https://wa.me/?text=${encodeURIComponent(finalMessage)}`;
    window.open(waUrl, "_blank", "noopener,noreferrer");
    setShowShareMenu(false);
  };
  const shareToTelegram = () => {
    const text = getAIOptimizedText();
    const url = getUtmUrl("telegram");
    window.open(`https://t.me/share/url?url=${encodeURIComponent(url)}&text=${encodeURIComponent(text)}`, "_blank");
    setShowShareMenu(false);
  };
  const shareToTwitter = () => {
    const stripHtml = (html) => html.replace(/<[^>]*>?/gm, "").replace(/&nbsp;/g, " ").trim();
    const cleanTitle = stripHtml(data.title);
    const text = `🔥 ${cleanTitle}`;
    const url = getUtmUrl("twitter");
    const siteTag = siteSettings?.site_name?.replace(/\s+/g, "") || "haber";
    const hashtags = `${data.category?.replace(/\s+/g, "") || "gündem"},${siteTag}`;
    window.open(`https://twitter.com/intent/tweet?text=${encodeURIComponent(text)}&url=${encodeURIComponent(url)}&hashtags=${hashtags}`, "_blank", "noopener,noreferrer");
    setShowShareMenu(false);
  };
  const shareToFacebook = () => {
    const url = getUtmUrl("facebook");
    window.open(`https://www.facebook.com/sharer/sharer.php?u=${encodeURIComponent(url)}`, "_blank");
    setShowShareMenu(false);
  };
  const shareToInstagram = async () => {
    await copyLink(false);
    showToast(t("common.link_copied_instagram"), "info");
    setTimeout(() => {
      window.open("https://www.instagram.com/", "_blank");
    }, 1e3);
    setShowShareMenu(false);
  };
  const shareToTikTok = async () => {
    await copyLink(false);
    showToast(t("common.link_copied_tiktok"), "info");
    setTimeout(() => {
      window.open("https://www.tiktok.com/", "_blank");
    }, 1e3);
    setShowShareMenu(false);
  };
  const shareToSocial = async () => {
    const url = getUtmUrl("nsosyal");
    const text = getAIOptimizedText();
    const stripHtml = (html) => html.replace(/<[^>]*>?/gm, "").replace(/&nbsp;/g, " ").trim();
    const cleanTitle = stripHtml(data.title);
    if (navigator.share) {
      try {
        await navigator.share({
          title: cleanTitle,
          text,
          url
        });
      } catch (error) {
        if (error.name !== "AbortError") copyLink();
      }
    } else {
      copyLink();
    }
    setShowShareMenu(false);
  };
  const copyLink = async (showNotification = true) => {
    const url = getUtmUrl("copy_link");
    try {
      await navigator.clipboard.writeText(url);
      if (showNotification) showToast(t("common.link_copied_short"), "success");
    } catch (error) {
      if (showNotification) showToast(t("common.copy_failed_alt"), "error");
    }
    setShowShareMenu(false);
  };
  const renderContent = () => {
    switch (data.type) {
      case NewsType.REVIEW:
        return /* @__PURE__ */ jsx(ReviewCard, { data });
      case NewsType.BEFORE_AFTER:
        return /* @__PURE__ */ jsx(BeforeAfterCard, { data });
      case NewsType.FLIP_CARD:
        return /* @__PURE__ */ jsx(FlipCard, { data });
      case NewsType.EMBED:
        return /* @__PURE__ */ jsx(EmbedCard, { data });
      case NewsType.AUDIO:
        return /* @__PURE__ */ jsx(AudioCard, { data });
      case NewsType.VIDEO:
        return /* @__PURE__ */ jsx(VideoCard, { data });
      case NewsType.GALLERY:
        return /* @__PURE__ */ jsx(GalleryCard, { data });
      case NewsType.POLL:
        return /* @__PURE__ */ jsx(PollCard, { data });
      case NewsType.VS:
        return /* @__PURE__ */ jsx(VSCard, { data });
      case NewsType.PARAGRAPH:
        return /* @__PURE__ */ jsx(ParagraphCard, { data });
      case NewsType.IMAGE:
      case NewsType.STANDARD:
      default:
        return /* @__PURE__ */ jsx(StandardCard, { data });
    }
  };
  const handleCardNavigate = (e) => {
    if (e.defaultPrevented || e.button !== 0 || e.metaKey || e.ctrlKey || e.shiftKey || e.altKey) {
      return;
    }
    e.preventDefault();
    if (onClick) {
      onClick();
      return;
    }
    void navigate();
  };
  const handleSourceAction = (e) => {
    e.stopPropagation();
    onSourceClick?.();
  };
  return /* @__PURE__ */ jsxs(
    "div",
    {
      className: "bg-white rounded-[5px] border border-palette-beige/30 shadow-[0_2px_20px_rgba(24,37,64,0.03)] transition-all duration-100 hover:shadow-[0_8px_30px_rgba(24,37,64,0.06)] hover:border-palette-red/10 cursor-pointer group/card relative",
      children: [
        /* @__PURE__ */ jsx(
          "a",
          {
            href: detailHref,
            onClick: handleCardNavigate,
            onMouseEnter: () => prefetch(detailHref),
            onFocus: () => prefetch(detailHref),
            className: "absolute inset-0 cursor-pointer",
            "aria-label": data.title,
            children: /* @__PURE__ */ jsx("span", { className: "sr-only", children: data.title })
          }
        ),
        /* @__PURE__ */ jsxs("div", { className: "relative pointer-events-none [&_button]:pointer-events-auto [&_input]:pointer-events-auto [&_textarea]:pointer-events-auto [&_select]:pointer-events-auto [&_a]:pointer-events-auto", children: [
          /* @__PURE__ */ jsxs("div", { className: "px-6 pt-6 pb-2 flex items-center justify-between", children: [
            /* @__PURE__ */ jsxs("div", { className: "flex items-center gap-3.5", children: [
              /* @__PURE__ */ jsxs(
                "div",
                {
                  onClick: handleSourceAction,
                  className: "w-11 h-11 rounded-[5px] bg-palette-beige/20 p-[2px] border border-palette-beige shadow-sm cursor-pointer group/avatar relative pointer-events-auto",
                  children: [
                    /* @__PURE__ */ jsx("div", { className: "w-full h-full rounded-[5px] overflow-hidden", children: /* @__PURE__ */ jsx(
                      "img",
                      {
                        src: data.sourceAvatar || `https://picsum.photos/seed/source${data.id}/100`,
                        className: "w-full h-full object-cover transition-transform duration-500 group-hover/avatar:scale-110",
                        alt: data.source
                      }
                    ) }),
                    /* @__PURE__ */ jsx("div", { className: "absolute -bottom-1 -right-1 w-3.5 h-3.5 bg-white rounded-[5px] flex items-center justify-center", children: /* @__PURE__ */ jsx("div", { className: "w-2 h-2 bg-green-500 rounded-[5px] animate-pulse" }) })
                  ]
                }
              ),
              /* @__PURE__ */ jsxs("div", { children: [
                /* @__PURE__ */ jsxs("div", { className: "flex items-center gap-2", children: [
                  /* @__PURE__ */ jsxs(
                    "div",
                    {
                      onClick: handleSourceAction,
                      className: "flex items-center gap-1.5 cursor-pointer group/title pointer-events-auto",
                      children: [
                        /* @__PURE__ */ jsx("h5", { className: "text-[15px] font-[800] text-gray-900 tracking-tight group-hover/title:text-palette-red transition-colors", children: data.source }),
                        /* @__PURE__ */ jsx("span", { className: "material-symbols-rounded text-palette-red", style: { fontSize: "16px", fontVariationSettings: "'FILL' 1" }, children: "verified" })
                      ]
                    }
                  ),
                  /* @__PURE__ */ jsx(
                    "button",
                    {
                      onClick: handleFollow,
                      className: `uppercase tracking-tighter text-[9px] font-[900] px-2 py-0.5 rounded-full transition-all ${isFollowing ? "text-gray-400 bg-gray-100" : "text-blue-600 bg-blue-50 hover:bg-blue-600 hover:text-white"}`,
                      children: isFollowing ? t("common.following") : t("common.follow")
                    }
                  )
                ] }),
                /* @__PURE__ */ jsxs("div", { className: "flex items-center gap-1.5 text-[10px] font-bold text-palette-tan/40 leading-none mt-1", children: [
                  /* @__PURE__ */ jsx("div", { className: "flex items-center gap-1", children: categoryHierarchy.map((cat, idx) => /* @__PURE__ */ jsxs(React.Fragment, { children: [
                    /* @__PURE__ */ jsx("span", { className: "text-gray-500 font-[800] uppercase tracking-wider text-[9px]", children: t(cat) }),
                    idx < categoryHierarchy.length - 1 && /* @__PURE__ */ jsx("span", { className: "text-gray-500 mx-0.5 text-[8px]", children: "/" })
                  ] }, idx)) }),
                  /* @__PURE__ */ jsx("span", { className: "w-0.5 h-0.5 bg-palette-beige rounded-[5px]" }),
                  /* @__PURE__ */ jsx("span", { className: "font-medium", children: getRelativeTime(data.timestamp, currentLang.code) })
                ] })
              ] })
            ] }),
            data.isPinned && /* @__PURE__ */ jsxs("div", { className: "flex items-center gap-1.5 px-3 py-1 bg-amber-500/5 border border-amber-100 rounded-[5px] text-amber-600 animate-in fade-in slide-in-from-right-4 duration-500", children: [
              /* @__PURE__ */ jsx("span", { className: "material-symbols-rounded", style: { fontSize: "16px", fontVariationSettings: "'FILL' 1" }, children: "push_pin" }),
              /* @__PURE__ */ jsx("span", { className: "text-[10px] font-black uppercase tracking-widest hidden sm:inline-block", children: t("news.featured") })
            ] })
          ] }),
          /* @__PURE__ */ jsx("div", { className: "px-6 pt-2 pb-0.5", children: data.type !== NewsType.EMBED && /* @__PURE__ */ jsx("h3", { className: "text-[38px] font-[900] text-gray-900 tracking-[-0.01em] leading-tight group-hover/card:text-palette-red transition-colors", children: data.title }) }),
          /* @__PURE__ */ jsx("div", { className: "px-6 pb-2 rounded-[5px] overflow-hidden", children: renderContent() }),
          /* @__PURE__ */ jsx("div", { className: "mt-0.5 px-6 py-1 border-t border-palette-beige/20 bg-white/50 backdrop-blur-md relative z-[100]", children: /* @__PURE__ */ jsxs("div", { className: "flex items-center justify-between", children: [
            /* @__PURE__ */ jsxs("div", { className: "flex items-center gap-1 relative", children: [
              /* @__PURE__ */ jsxs(
                "button",
                {
                  onClick: handleShare,
                  className: "flex items-center gap-2 px-2.5 py-1.5 rounded-[5px] text-palette-tan/50 hover:text-palette-red hover:bg-palette-red/5 transition-all duration-100 active:scale-95 group/share",
                  children: [
                    /* @__PURE__ */ jsx("span", { className: "text-[12px] font-bold leading-none", children: data.shares.toLocaleString() }),
                    /* @__PURE__ */ jsx("span", { className: "material-symbols-rounded leading-none animate-heartbeat-1", style: { fontSize: "20px" }, children: "share" }),
                    /* @__PURE__ */ jsx("span", { className: "text-[10px] font-[900] uppercase tracking-widest leading-none", children: t("common.share") })
                  ]
                }
              ),
              showShareMenu && /* @__PURE__ */ jsx(
                "div",
                {
                  ref: shareMenuRef,
                  className: "absolute bottom-full left-0 mb-4 bg-white/95 backdrop-blur-xl rounded-[12px] shadow-[0_25px_60px_rgba(24,37,64,0.2)] border border-palette-beige/30 p-1.5 min-w-[220px] z-[99999] animate-in fade-in zoom-in-95 slide-in-from-bottom-2 duration-300 pointer-events-auto",
                  onClick: (e) => e.stopPropagation(),
                  children: /* @__PURE__ */ jsxs("div", { className: "grid grid-cols-1 gap-0.5", children: [
                    /* @__PURE__ */ jsxs("button", { onClick: shareToWhatsApp, className: "w-full h-[38px] flex items-center gap-3 px-3 rounded-[8px] hover:bg-[#25D366]/5 transition-all duration-300 group", children: [
                      /* @__PURE__ */ jsx("div", { className: "w-[20px] h-[20px] flex items-center justify-center text-[#25D366]/70 group-hover:text-[#25D366] group-hover:scale-110 transition-all", children: /* @__PURE__ */ jsx("svg", { viewBox: "0 0 24 24", fill: "currentColor", className: "w-full h-full", children: /* @__PURE__ */ jsx("path", { d: "M17.472 14.382c-.297-.149-1.758-.867-2.03-.967-.273-.099-.471-.148-.67.15-.197.297-.767.966-.94 1.164-.173.199-.347.223-.644.075-.297-.15-1.255-.463-2.39-1.475-.883-.788-1.48-1.761-1.653-2.059-.173-.297-.018-.458.13-.606.134-.133.298-.347.446-.52.149-.174.198-.298.298-.497.099-.198.05-.371-.025-.52-.075-.149-.669-1.612-.916-2.207-.242-.579-.487-.5-.669-.51-.173-.008-.371-.01-.57-.01-.198 0-.52.074-.792.372-.272.297-1.04 1.016-1.04 2.479 0 1.462 1.065 2.875 1.213 3.074.149.198 2.096 3.2 5.077 4.487.709.306 1.262.489 1.694.625.712.227 1.36.195 1.871.118.571-.085 1.758-.719 2.006-1.413.248-.694.248-1.289.173-1.413-.074-.124-.272-.198-.57-.347m-5.421 7.403h-.004a9.87 9.87 0 01-5.031-1.378l-.361-.214-3.741.982.998-3.648-.235-.374a9.86 9.86 0 01-1.51-5.26c.001-5.45 4.436-9.884 9.888-9.884 2.64 0 5.122 1.03 6.988 2.898a9.825 9.825 0 012.893 6.994c-.003 5.45-4.437 9.884-9.885 9.884m8.413-18.297A11.815 11.815 0 0012.05 0C5.495 0 .16 5.335.157 11.892c0 2.096.547 4.142 1.588 5.945L.003 24l6.335-1.652a11.882 11.882 0 005.71 1.453h.006c6.554 0 11.89-5.335 11.893-11.893a11.821 11.821 0 00-3.48-8.413z" }) }) }),
                      /* @__PURE__ */ jsx("span", { className: "text-[11px] font-bold text-gray-600 group-hover:text-gray-900 transition-colors", children: t("share.whatsapp") })
                    ] }),
                    /* @__PURE__ */ jsxs("button", { onClick: shareToTelegram, className: "w-full h-[38px] flex items-center gap-3 px-3 rounded-[8px] hover:bg-[#0088cc]/5 transition-all duration-300 group", children: [
                      /* @__PURE__ */ jsx("div", { className: "w-[20px] h-[20px] flex items-center justify-center text-[#0088cc]/70 group-hover:text-[#0088cc] group-hover:scale-110 transition-all", children: /* @__PURE__ */ jsx("svg", { viewBox: "0 0 24 24", fill: "currentColor", className: "w-full h-full", children: /* @__PURE__ */ jsx("path", { d: "M11.944 0A12 12 0 0 0 0 12a12 12 0 0 0 12 12 12 12 0 0 0 12-12A12 12 0 0 0 12 0a12 12 0 0 0-.056 0zm4.962 7.224c.1-.002.321.023.465.14a.506.506 0 0 1 .171.325c.016.093.036.306.02.472-.18 1.898-.962 6.502-1.36 8.627-.168.9-.499 1.201-.82 1.23-.696.065-1.225-.46-1.9-.902-1.056-.693-1.653-1.124-2.678-1.8-1.185-.78-.417-1.21.258-1.91.177-.184 3.247-2.977 3.307-3.23.007-.032.014-.15-.056-.212s-.174-.041-.249-.024c-.106.024-1.793 1.14-5.061 3.345-.48.33-.913.49-1.302.48-.428-.008-1.252-.241-1.865-.44-.752-.245-1.349-.374-1.297-.789.027-.216.325-.437.893-.663 3.498-1.524 5.83-2.529 6.998-3.014 3.332-1.386 4.025-1.627 4.476-1.635z" }) }) }),
                      /* @__PURE__ */ jsx("span", { className: "text-[11px] font-bold text-gray-600 group-hover:text-gray-900 transition-colors", children: t("share.telegram") })
                    ] }),
                    /* @__PURE__ */ jsxs("button", { onClick: shareToTwitter, className: "w-full h-[38px] flex items-center gap-3 px-3 rounded-[8px] hover:bg-black/5 transition-all duration-300 group", children: [
                      /* @__PURE__ */ jsx("div", { className: "w-[20px] h-[20px] flex items-center justify-center text-black/70 group-hover:text-black group-hover:scale-110 transition-all", children: /* @__PURE__ */ jsx("svg", { viewBox: "0 0 24 24", fill: "currentColor", className: "w-full h-full", children: /* @__PURE__ */ jsx("path", { d: "M18.244 2.25h3.308l-7.227 8.26 8.502 11.24H16.17l-5.214-6.817L4.99 21.75H1.68l7.73-8.835L1.254 2.25H8.08l4.713 6.231zm-1.161 17.52h1.833L7.084 4.126H5.117z" }) }) }),
                      /* @__PURE__ */ jsx("span", { className: "text-[11px] font-bold text-gray-600 group-hover:text-gray-900 transition-colors", children: t("share.x_twitter") })
                    ] }),
                    /* @__PURE__ */ jsxs("button", { onClick: shareToFacebook, className: "w-full h-[38px] flex items-center gap-3 px-3 rounded-[8px] hover:bg-[#1877F2]/5 transition-all duration-300 group", children: [
                      /* @__PURE__ */ jsx("div", { className: "w-[20px] h-[20px] flex items-center justify-center text-[#1877F2]/70 group-hover:text-[#1877F2] group-hover:scale-110 transition-all", children: /* @__PURE__ */ jsx("svg", { viewBox: "0 0 24 24", fill: "currentColor", className: "w-full h-full", children: /* @__PURE__ */ jsx("path", { d: "M24 12.073c0-6.627-5.373-12-12-12s-12 5.373-12 12c0 5.99 4.388 10.954 10.125 11.854v-8.385H7.078v-3.47h3.047V9.43c0-3.007 1.792-4.669 4.533-4.669 1.312 0 2.686.235 2.686.235v2.953H15.83c-1.491 0-1.956.925-1.956 1.874v2.25h3.328l-.532 3.47h-2.796v8.385C19.612 23.027 24 18.062 24 12.073z" }) }) }),
                      /* @__PURE__ */ jsx("span", { className: "text-[11px] font-bold text-gray-600 group-hover:text-gray-900 transition-colors", children: t("share.facebook") })
                    ] }),
                    /* @__PURE__ */ jsxs("button", { onClick: shareToInstagram, className: "w-full h-[38px] flex items-center gap-3 px-3 rounded-[8px] hover:bg-[#E4405F]/5 transition-all duration-300 group", children: [
                      /* @__PURE__ */ jsx("div", { className: "w-[20px] h-[20px] flex items-center justify-center text-[#E4405F]/70 group-hover:text-[#E4405F] group-hover:scale-110 transition-all", children: /* @__PURE__ */ jsx("svg", { viewBox: "0 0 24 24", fill: "currentColor", className: "w-full h-full", children: /* @__PURE__ */ jsx("path", { d: "M12 0C8.74 0 8.333.015 7.053.072 5.775.132 4.905.333 4.14.63c-.789.306-1.459.717-2.126 1.384S.935 3.35.63 4.14C.333 4.905.131 5.775.072 7.053.012 8.333 0 8.74 0 12s.015 3.667.072 4.947c.06 1.277.261 2.148.558 2.913.306.788.717 1.459 1.384 2.126.667.666 1.336 1.079 2.126 1.384.766.296 1.636.499 2.913.558C8.333 23.988 8.74 24 12 24s3.667-.015 4.947-.072c1.277-.06 2.148-.262 2.913-.558.788-.306 1.459-.718 2.126-1.384.666-.667 1.079-1.335 1.384-2.126.296-.765.499-1.636.558-2.913.06-1.28.072-1.687.072-4.947s-.015-3.667-.072-4.947c-.06-1.277-.262-2.149-.558-2.913-.306-.789-.718-1.459-1.384-2.126C21.319 1.347 20.651.935 19.86.63c-.765-.297-1.636-.499-2.913-.558C15.667.012 15.26 0 12 0zm0 2.16c3.203 0 3.585.016 4.85.071 1.17.055 1.805.249 2.227.415.562.217.96.477 1.382.896.419.42.679.819.896 1.381.164.422.36 1.057.413 2.227.057 1.266.07 1.646.07 4.85s-.015 3.585-.074 4.85c-.061 1.17-.256 1.805-.421 2.227-.224.562-.479.96-.899 1.382-.419.419-.824.679-1.38.896-.42.164-1.065.36-2.235.413-1.274.057-1.649.07-4.859.07-3.211 0-3.586-.015-4.859-.074-1.171-.061-1.816-.256-2.236-.421-.569-.224-.96-.479-1.379-.899-.421-.419-.69-.824-.9-1.38-.165-.42-.359-1.065-.42-2.235-.045-1.26-.061-1.649-.061-4.844 0-3.196.016-3.586.061-4.861.061-1.17.255-1.814.42-2.234.21-.57.479-.96.9-1.381.419-.419.81-.689 1.379-.898.42-.166 1.051-.361 2.221-.421 1.275-.045 1.65-.06 4.859-.06l.045.03zm0 3.678c-3.405 0-6.162 2.76-6.162 6.162 0 3.405 2.76 6.162 6.162 6.162 3.405 0 6.162-2.76 6.162-6.162 0-3.405-2.76-6.162-6.162-6.162zM12 16c-2.21 0-4-1.79-4-4s1.79-4 4-4 4 1.79 4 4-1.79 4-4 4zm7.846-10.405c0 .795-.646 1.44-1.44 1.44-.795 0-1.44-.646-1.44-1.44 0-.794.646-1.439 1.44-1.439.793-.001 1.44.645 1.44 1.439z" }) }) }),
                      /* @__PURE__ */ jsx("span", { className: "text-[11px] font-bold text-gray-600 group-hover:text-gray-900 transition-colors", children: t("share.instagram") })
                    ] }),
                    /* @__PURE__ */ jsxs("button", { onClick: shareToTikTok, className: "w-full h-[38px] flex items-center gap-3 px-3 rounded-[8px] hover:bg-black/5 transition-all duration-300 group", children: [
                      /* @__PURE__ */ jsx("div", { className: "w-[20px] h-[20px] flex items-center justify-center text-black/70 group-hover:text-black group-hover:scale-110 transition-all", children: /* @__PURE__ */ jsx("svg", { viewBox: "0 0 24 24", fill: "currentColor", className: "w-full h-full", children: /* @__PURE__ */ jsx("path", { d: "M12.525.02c1.31-.02 2.61-.01 3.91-.02.08 1.53.63 3.09 1.75 4.17 1.12 1.11 2.7 1.62 4.24 1.79v4.03c-1.44-.05-2.89-.35-4.2-.97-.57-.26-1.1-.59-1.62-.93-.01 2.92.01 5.84-.02 8.75-.08 1.4-.54 2.79-1.35 3.94-1.31 1.92-3.58 3.17-5.91 3.21-1.43.08-2.86-.31-4.08-1.03-2.02-1.19-3.44-3.37-3.65-5.71-.02-.5-.03-1-.01-1.49.18-1.9 1.12-3.72 2.58-4.96 1.66-1.44 3.98-2.13 6.15-1.72.02 1.48-.04 2.96-.04 4.44-.99-.32-2.15-.23-3.02.37-.63.41-1.11 1.04-1.36 1.75-.21.51-.15 1.07-.14 1.61.24 1.64 1.82 3.02 3.5 2.87 1.12-.01 2.19-.66 2.77-1.61.19-.33.4-.67.41-1.06.1-1.79.06-3.57.07-5.36.01-4.03-.01-8.05.02-12.07z" }) }) }),
                      /* @__PURE__ */ jsx("span", { className: "text-[11px] font-bold text-gray-600 group-hover:text-gray-900 transition-colors", children: t("share.tiktok") })
                    ] }),
                    /* @__PURE__ */ jsxs("button", { onClick: shareToSocial, className: "w-full h-[38px] flex items-center gap-3 px-3 rounded-[8px] hover:bg-palette-red/5 transition-all duration-300 group", children: [
                      /* @__PURE__ */ jsx("div", { className: "w-[20px] h-[20px] flex items-center justify-center text-palette-red/70 group-hover:text-palette-red group-hover:scale-110 transition-all", children: /* @__PURE__ */ jsx("svg", { viewBox: "0 0 24 24", fill: "currentColor", className: "w-full h-full", children: /* @__PURE__ */ jsx("path", { d: "M12 2C6.48 2 2 6.48 2 12s4.48 10 10 10 10-4.48 10-10S17.52 2 12 2zm-1 17.93c-3.95-.49-7-3.85-7-7.93 0-.62.08-1.21.21-1.79L9 15v1c0 1.1.9 2 2 2v1.93zm6.9-2.54c-.26-.81-1-1.39-1.9-1.39h-1v-3c0-.55-.45-1-1-1H8v-2h2c.55 0 1-.45 1-1V7h2c1.1 0 2-.9 2-2v-.41c2.93 1.19 5 4.06 5 7.41 0 2.08-.8 3.97-2.1 5.39z" }) }) }),
                      /* @__PURE__ */ jsx("span", { className: "text-[11px] font-bold text-gray-600 group-hover:text-gray-900 transition-colors", children: t("share.nsosyal") })
                    ] }),
                    /* @__PURE__ */ jsx("div", { className: "h-px bg-palette-beige/10 my-1 mx-2" }),
                    /* @__PURE__ */ jsxs("button", { onClick: () => copyLink(), className: "w-full h-[38px] flex items-center gap-3 px-3 rounded-[8px] hover:bg-palette-beige/10 transition-all duration-300 group", children: [
                      /* @__PURE__ */ jsx("div", { className: "w-[20px] h-[20px] flex items-center justify-center text-palette-tan/60 group-hover:text-palette-tan group-hover:scale-110 transition-all", children: /* @__PURE__ */ jsxs("svg", { viewBox: "0 0 24 24", fill: "none", stroke: "currentColor", strokeWidth: "2", strokeLinecap: "round", strokeLinejoin: "round", className: "w-full h-full", children: [
                        /* @__PURE__ */ jsx("path", { d: "M10 13a5 5 0 0 0 7.54.54l3-3a5 5 0 0 0-7.07-7.07l-1.72 1.71" }),
                        /* @__PURE__ */ jsx("path", { d: "M14 11a5 5 0 0 0-7.54-.54l-3 3a5 5 0 0 0 7.07 7.07l1.71-1.71" })
                      ] }) }),
                      /* @__PURE__ */ jsx("span", { className: "text-[11px] font-bold text-gray-600 group-hover:text-gray-900 transition-colors", children: t("share.copy_link") })
                    ] })
                  ] })
                }
              ),
              /* @__PURE__ */ jsxs(
                "button",
                {
                  onClick: (e) => {
                    e.stopPropagation();
                    setShowComments(!showComments);
                  },
                  className: "flex items-center gap-2 px-2.5 py-1.5 rounded-[5px] transition-all duration-100 group/comment text-palette-tan/50 hover:text-palette-maroon hover:bg-palette-tan/5",
                  children: [
                    /* @__PURE__ */ jsx(
                      "span",
                      {
                        className: "material-symbols-rounded transition-all duration-300 animate-heartbeat-2",
                        style: {
                          fontSize: "20px",
                          fontVariationSettings: showComments ? "'FILL' 1, 'wght' 400" : "'FILL' 0, 'wght' 300"
                        },
                        children: "chat_bubble"
                      }
                    ),
                    /* @__PURE__ */ jsx("span", { className: "text-[12px] font-bold leading-none", children: data.comments.toLocaleString() })
                  ]
                }
              )
            ] }),
            /* @__PURE__ */ jsxs("div", { className: "flex items-center gap-2", children: [
              /* @__PURE__ */ jsx(
                "button",
                {
                  onClick: handleSave,
                  className: `flex items-center justify-center w-10 h-10 rounded-[5px] transition-all duration-150 group/bookmark ${isBookmarked ? "text-palette-red bg-palette-red/5" : "text-palette-tan/40 hover:text-palette-red hover:bg-palette-red/5"}`,
                  children: /* @__PURE__ */ jsx(
                    "span",
                    {
                      className: "material-symbols-rounded transition-all duration-300 animate-heartbeat-3",
                      style: {
                        fontSize: "22px",
                        fontVariationSettings: isBookmarked ? "'FILL' 1, 'wght' 400" : "'FILL' 0, 'wght' 300"
                      },
                      children: "bookmark"
                    }
                  )
                }
              ),
              /* @__PURE__ */ jsxs("div", { className: "flex items-center bg-palette-beige/10 rounded-[5px] border border-palette-beige/30 p-1", children: [
                /* @__PURE__ */ jsxs(
                  "button",
                  {
                    onClick: handleLike,
                    className: `
                  flex items-center gap-2 px-3 py-1.5 rounded-[5px] transition-all duration-300
                  ${isLiked ? "bg-palette-red text-white shadow-md" : "text-palette-maroon/60 hover:bg-white hover:text-palette-red"}
                `,
                    children: [
                      /* @__PURE__ */ jsx("span", { className: "material-symbols-rounded !text-[20px]", style: { fontVariationSettings: isLiked ? "'FILL' 1" : "'FILL' 0" }, children: "thumb_up" }),
                      /* @__PURE__ */ jsx("span", { className: "text-[12px] font-[900]", children: likesCount.toLocaleString() })
                    ]
                  }
                ),
                /* @__PURE__ */ jsx("div", { className: "w-px h-4 bg-palette-beige/60 mx-1" }),
                /* @__PURE__ */ jsxs(
                  "button",
                  {
                    onClick: handleDislike,
                    className: `
                  flex items-center gap-2 px-3 py-1.5 rounded-[5px] transition-all duration-300
                  ${isDisliked ? "bg-gray-800 text-white shadow-md" : "text-palette-maroon/60 hover:bg-white hover:text-gray-900"}
                `,
                    children: [
                      /* @__PURE__ */ jsx("span", { className: "material-symbols-rounded !text-[20px]", style: { fontVariationSettings: isDisliked ? "'FILL' 1" : "'FILL' 0" }, children: "thumb_down" }),
                      /* @__PURE__ */ jsx("span", { className: "text-[12px] font-[900]", children: dislikesCount.toLocaleString() })
                    ]
                  }
                )
              ] })
            ] })
          ] }) }),
          showComments && /* @__PURE__ */ jsx("div", { onClick: (e) => e.stopPropagation(), className: "animate-in fade-in slide-in-from-top-1 duration-300 pointer-events-auto", children: /* @__PURE__ */ jsx(CommentSection, { postId: data.id, publisherId: data.publisherId }) })
        ] })
      ]
    }
  );
};
const NewsCardSkeleton = () => {
  return /* @__PURE__ */ jsxs("div", { className: "bg-white rounded-[5px] border border-palette-beige/30 shadow-[0_2px_20px_rgba(24,37,64,0.03)] p-6 space-y-4", children: [
    /* @__PURE__ */ jsxs("div", { className: "flex items-center gap-3.5", children: [
      /* @__PURE__ */ jsx(Skeleton, { variant: "rectangular", className: "w-11 h-11" }),
      /* @__PURE__ */ jsxs("div", { className: "space-y-2", children: [
        /* @__PURE__ */ jsx(Skeleton, { className: "w-24 h-4" }),
        /* @__PURE__ */ jsx(Skeleton, { className: "w-32 h-3" })
      ] })
    ] }),
    /* @__PURE__ */ jsx(Skeleton, { className: "w-full h-[60px]" }),
    /* @__PURE__ */ jsx(Skeleton, { className: "w-full h-[300px]" }),
    /* @__PURE__ */ jsxs("div", { className: "pt-4 flex justify-between", children: [
      /* @__PURE__ */ jsxs("div", { className: "flex gap-2", children: [
        /* @__PURE__ */ jsx(Skeleton, { className: "w-20 h-8" }),
        /* @__PURE__ */ jsx(Skeleton, { className: "w-20 h-8" })
      ] }),
      /* @__PURE__ */ jsx(Skeleton, { className: "w-24 h-10" })
    ] })
  ] });
};

[
  {
    id: "n_review_1",
    type: NewsType.REVIEW,
    title: "iPhone 15 Pro Max İncelemesi: Titanyum Devrimi mi?",
    summary: "Apple'ın en yeni amiral gemisini 2 hafta boyunca test ettik. Hafifleyen gövdesi, Type-C portu ve 5x zoom kamerası ile yükseltmeye değer mi? İşte detaylı incelememiz.",
    category: "Teknoloji / İnceleme",
    source: "Global Tech",
    author: "Tekno Editör",
    timestamp: "2 saat önce",
    mediaUrl: "",
    thumbnail: "https://images.unsplash.com/photo-1695048133142-1a20484d2569?auto=format&fit=crop&q=80&w=1000",
    likes: 18500,
    comments: 940,
    shares: 2300,
    views: 45e3,
    reviewData: {
      productName: "iPhone 15 Pro Max",
      productImage: "https://images.unsplash.com/photo-1696446701796-da61225697cc?auto=format&fit=crop&q=80&w=800",
      score: 92,
      verdict: "Piyasadaki en iyi akıllı telefonlardan biri. Özellikle video çekimi ve performans konusunda rakipsiz, ancak şarj hızı hala rakiplerinin gerisinde.",
      pros: [
        "Titanyum kasa ile çok daha hafif",
        "Type-C portu nihayet geldi",
        "A17 Pro çip performansı inanılmaz",
        "5x Telefoto kamera çok başarılı"
      ],
      cons: [
        "Şarj hızı hala yavaş (20W-27W)",
        "Kutu içeriği zayıf",
        "Yüksek fiyat etiketi"
      ],
      breakdown: [
        { label: "Tasarım & Malzeme", score: 95 },
        { label: "Ekran & Görüntü", score: 98 },
        { label: "Kamera Performansı", score: 94 },
        { label: "Pil Ömrü", score: 85 },
        { label: "Fiyat / Performans", score: 75 }
      ]
    }
  },
  {
    id: "n_ba_1",
    type: NewsType.BEFORE_AFTER,
    title: "Büyük Restorasyon Tamamlandı: Tarihin Renkleri Geri Döndü",
    summary: "Yıllara meydan okuyan tarihi kütüphane binası, 5 yıl süren titiz restorasyonun ardından eski ihtişamına kavuştu. Değişimi görmek için çubuğu kaydırın.",
    category: "Mimari / Sanat",
    source: "Global Culture",
    author: "Sanat Ekibi",
    timestamp: "Şimdi",
    mediaUrl: "",
    thumbnail: "https://images.unsplash.com/photo-1548013146-72479768bada?auto=format&fit=crop&q=80&w=1000",
    likes: 34500,
    comments: 2100,
    shares: 8700,
    views: 125e3,
    beforeAfterData: {
      // Before: Siyah Beyaz ve biraz daha kontrastlı (Eski havası)
      beforeImage: "https://images.unsplash.com/photo-1548013146-72479768bada?auto=format&fit=crop&q=80&w=1000&sat=-100&bri=-10&con=20",
      // After: Orijinal canlı renkler
      afterImage: "https://images.unsplash.com/photo-1548013146-72479768bada?auto=format&fit=crop&q=80&w=1000",
      beforeLabel: "1920 (ARŞİV)",
      afterLabel: "2024 (GÜNCEL)"
    }
  },
  {
    id: "n_flip_1",
    type: NewsType.FLIP_CARD,
    title: "Tarihin Sıfır Noktası: Göbeklitepe'nin Gerçek Yüzü",
    summary: "Arkeolojik kazılar sonucu ortaya çıkan gerçekler bildiğimiz tarihi değiştiriyor. Kartı çevir ve 12.000 yıl öncesine tanıklık et.",
    category: "Tarih / Gizem",
    source: "Arşiv Haber",
    author: "Prof. Dr. Arkeo",
    timestamp: "Şimdi",
    mediaUrl: "",
    thumbnail: "https://images.unsplash.com/photo-1574515546176-7c93c1a3579b?auto=format&fit=crop&q=80&w=1000",
    likes: 24500,
    comments: 1890,
    shares: 5600,
    views: 89e3,
    flipData: {
      frontImage: "https://images.unsplash.com/photo-1599739291060-4578e77dac5d?auto=format&fit=crop&q=80&w=1000",
      // Güncel çalışan görsel
      frontTitle: "Günümüz: Kazı Alanı",
      backImage: "https://images.unsplash.com/photo-1518709268805-4e9042af9f23?auto=format&fit=crop&q=80&w=1000",
      // Temsili antik dönem (atmosferik)
      backTitle: "M.Ö. 10.000: Tapınaklar",
      backDescription: "Burası sadece bir yerleşim yeri değil, insanlık tarihinin ilk inanç merkeziydi. Sütunların üzerindeki hayvan figürleri, o dönemin mitolojisini anlatıyor."
    }
  },
  {
    id: "n_embed_twitter_1",
    type: NewsType.EMBED,
    title: "Gündemi Sarsan Açıklama Geldi",
    summary: "Sosyal medya bu paylaşımı konuşuyor. Binlerce etkileşim alan o tweet gündeme bomba gibi düştü.",
    category: "Gündem / Sosyal Medya",
    source: "X (Twitter)",
    author: "Erdogan Ozegen",
    timestamp: "Az önce",
    mediaUrl: "https://x.com/erdoganozegenn/status/2004226044140659051?s=20",
    thumbnail: "",
    // Embed için kullanılmıyor
    likes: 15420,
    comments: 2300,
    shares: 4500,
    views: 67e3
  },
  {
    id: "n_audio_podcast_1",
    type: NewsType.AUDIO,
    title: "Geleceğin Teknolojisi: Yapay Zeka ve Biz",
    summary: "Bu hafta PateezCast'te yapay zekanın gündelik hayatımızı nasıl değiştirdiğini ve gelecekte bizi nelerin beklediğini konuşuyoruz. Kulaklıklarınızı takın!",
    category: "Podcast / Teknoloji",
    source: "PateezCast",
    author: "Teknoloji Masası",
    timestamp: "Yeni Bölüm",
    // Gerçek bir ses dosyası örneği (Telif hakkı olmayan bir sample)
    mediaUrl: "https://www.soundhelix.com/examples/mp3/SoundHelix-Song-1.mp3",
    thumbnail: "https://images.unsplash.com/photo-1478737270239-2f02b77ac6d5?auto=format&fit=crop&q=80&w=1000",
    videoDuration: "06:12",
    // Podcast süresi
    likes: 3420,
    comments: 156,
    shares: 890,
    views: 12500
  },
  {
    id: "n_embed_facebook_1",
    type: NewsType.EMBED,
    title: "Facebook'ta Paylaşım Rekoru Kıran Haber",
    summary: "DMC Haber tarafından paylaşılan ve binlerce yorum alan o gönderi, sosyal medyanın en çok konuşulanları arasına girdi.",
    category: "Gündem / Haber",
    source: "Facebook",
    author: "DMC Haber",
    timestamp: "2 saat önce",
    // Kullanıcının verdiği iframe içindeki link
    mediaUrl: "https://www.facebook.com/dmchaber/posts/pfbid02HduSa4swGEhqa2Powbbwo2r6UDfuij8VrYuR6WpRkHx8peqCmKzDPW1DZ83J4psxl",
    thumbnail: "",
    likes: 8500,
    comments: 450,
    shares: 12e3,
    views: 56e3
  },
  {
    id: "n_video_landscape",
    type: NewsType.VIDEO,
    title: "Şehrin Altında Gizli Bir Dünya: İstanbul Sarnıçları",
    summary: "Yerebatan Sarnıcı'nın ötesinde, binlerce yıllık tarihin izini süren gizemli bir yolculuğa çıkıyoruz. Restorasyonu tamamlanan bu yeni yapı görenleri büyülüyor.",
    category: "Tarih / Seyahat",
    source: "Arşiv Haber",
    author: "İlber O.",
    timestamp: "Şimdi",
    // Yatay Video (16:9)
    // Yatay Video (16:9) - Yanlış Pexels linki Unsplash ile değiştirildi (403 fix)
    mediaUrl: "https://images.unsplash.com/photo-1628108427771-46da5252b47f?auto=format&fit=crop&q=80&w=1000",
    thumbnail: "https://images.unsplash.com/photo-1628108427771-46da5252b47f?auto=format&fit=crop&q=80&w=1000",
    videoDuration: "12:45",
    likes: 15400,
    comments: 890,
    shares: 3200,
    views: 48e3
  },
  {
    id: "n_embed_instagram_1",
    type: NewsType.EMBED,
    title: "Instagram'da Günün En Çok Beğenilen Karesi",
    summary: "Fotoğrafçılık tutkunlarını mest eden o kare. Işık, kompozisyon ve anın büyüsü bir arada.",
    category: "Sanat / Fotoğraf",
    source: "Instagram",
    author: "Lens Master",
    timestamp: "45 dk önce",
    mediaUrl: "https://www.instagram.com/p/DSsRKqRiH6z/?utm_source=ig_web_button_share_sheet&igsh=ZDNlZDc0MzIxNw==",
    thumbnail: "",
    likes: 42300,
    comments: 120,
    shares: 560,
    views: 92e3
  },
  {
    id: "n_video_portrait",
    type: NewsType.VIDEO,
    title: "Doğanın Kalbinde: Nehir ve Ormanın Dansı",
    summary: "Şehrin gürültüsünden uzaklaşın ve doğanın dinginliğine kendinizi bırakın. İşte huzurun sesi.",
    category: "Doğa / Yaşam",
    source: "Doğa Günlüğü",
    author: "Seda G.",
    timestamp: "1 saat önce",
    // Dikey Video (Gerçek Vertical Video - Nehir/Orman Temalı)
    // Dikey Video - Yanlış Pexels linki Unsplash ile değiştirildi (403 fix)
    mediaUrl: "https://images.unsplash.com/photo-1574515546176-7c93c1a3579b?auto=format&fit=crop&q=80&w=1000",
    // Thumbnail boş bırakıldı, böylece video yüklenince kendi karesi görünür, eski resim görünmez.
    thumbnail: "",
    videoDuration: "00:15",
    // Placeholder, gerçek süre yüklenince güncellenir
    likes: 22100,
    comments: 1200,
    shares: 5600,
    views: 78e3
  },
  {
    id: "n_image_1",
    type: NewsType.IMAGE,
    title: "James Webb Uzay Teleskobu'ndan Büyüleyici Yeni Kare!",
    summary: "Derin uzayın en net görüntüsü paylaşıldı. Bilim dünyası bu keşifle heyecan içerisinde.",
    category: "Bilim / Uzay",
    source: "Uzay Bilim",
    author: "Aylin Yıldız",
    timestamp: "Yeni",
    mediaUrl: "",
    thumbnail: "https://images.unsplash.com/photo-1464802686167-b939a6910659?auto=format&fit=crop&q=80&w=1000",
    likes: 12500,
    comments: 230,
    shares: 4500,
    views: 34e3
  },
  {
    id: "n_gallery_1",
    type: NewsType.GALLERY,
    title: "Doğanın En Büyüleyici Anları: Haftanın Seçkisi",
    summary: "National Geographic fotoğrafçılarının dünyanın dört bir yanından yakaladığı, nefes kesen doğa manzaraları ve vahşi yaşam kareleri. Hem zirvelerin soğuğu hem de tropik ormanların canlılığı bu galeride.",
    category: "Doğa / Seyahat",
    source: "Doğa Günlüğü",
    author: "Cem Doğa",
    timestamp: "1 saat önce",
    mediaUrl: "",
    thumbnail: "https://images.unsplash.com/photo-1472214103451-9374bd1c798e?auto=format&fit=crop&q=80&w=1000",
    mediaList: [
      "https://images.unsplash.com/photo-1472214103451-9374bd1c798e?auto=format&fit=crop&q=80&w=1000",
      // Landscape - Mountain
      "https://images.unsplash.com/photo-1555169062-013468b47731?auto=format&fit=crop&q=80&w=600&h=800",
      // Portrait - Bird
      "https://images.unsplash.com/photo-1507525428034-b723cf961d3e?auto=format&fit=crop&q=80&w=1000",
      // Landscape - Beach
      "https://images.unsplash.com/photo-1549740425-5e9ed4d8cd34?auto=format&fit=crop&q=80&w=600&h=800",
      // Portrait - Architecture/Nature Mix
      "https://images.unsplash.com/photo-1501854140884-074cf2b2c3af?auto=format&fit=crop&q=80&w=1000"
      // Landscape - Forest
    ],
    likes: 8900,
    comments: 450,
    shares: 1200,
    views: 28e3
  },
  {
    id: "n_vs_pro",
    type: NewsType.VS,
    title: "Hangi Konsol Senin Favorin?",
    summary: "Oyun dünyasının devleri karşı karşıya. Sen hangi taraftasın?",
    category: "Oyun / Teknoloji",
    source: "Oyuncu Dünyası",
    author: "Efe Yılmaz",
    timestamp: "2 dk önce",
    mediaUrl: "",
    thumbnail: "https://images.unsplash.com/photo-1493711662062-fa541adb3fc8?auto=format&fit=crop&q=80&w=800",
    likes: 4200,
    comments: 890,
    shares: 340,
    views: 15e3,
    totalVotes: 52e3,
    options: [
      { id: "vs_ps", text: "PlayStation 5", votes: 28500, image: "https://images.unsplash.com/photo-1606144042614-b2417e99c4e3?auto=format&fit=crop&q=80&w=800" },
      { id: "vs_xbox", text: "Xbox Series X", votes: 23500, image: "https://images.unsplash.com/photo-1605901309584-818e25960a8f?auto=format&fit=crop&q=80&w=800" }
    ]
  },
  {
    id: "n_text_poll_1",
    type: NewsType.POLL,
    isImagePoll: false,
    title: "Haftanın En Çok Tartışılan Konusu: Yapay Zeka",
    summary: "Yapay zekanın sanat dünyasındaki yerini nasıl görüyorsun? Gelecek bizi korkutmalı mı?",
    category: "Teknoloji / Sanat",
    source: "Sanat Galerisi",
    author: "Selin Su",
    timestamp: "15 dk önce",
    mediaUrl: "",
    thumbnail: "https://images.unsplash.com/photo-1677442136019-21780ecad995?auto=format&fit=crop&q=80&w=800",
    likes: 1200,
    comments: 45,
    shares: 88,
    views: 5600,
    totalVotes: 3200,
    options: [
      { id: "tp1", text: "İnsan yaratıcılığını asla geçemez", votes: 1400 },
      { id: "tp2", text: "Yeni bir sanat devriminin kapısıdır", votes: 1200 },
      { id: "tp3", text: "Sanatçıların emeğini sömürüyor", votes: 600 }
    ]
  },
  {
    id: "n1_3col_poll",
    type: NewsType.POLL,
    isImagePoll: true,
    pollColumns: 3,
    title: "Hafta Sonu İçin En İyi Rota Sence Hangisi?",
    summary: "Şehrin gürültüsünden kaçmak için sabırsızlananlar burada mı? Senin hayalindeki kaçamak hangisi?",
    category: "Yaşam / Gezi",
    source: "Gezi Rehberi",
    author: "Caner Öz",
    timestamp: "12 dk önce",
    mediaUrl: "",
    thumbnail: "https://images.unsplash.com/photo-1464822759023-fed622ff2c3b?auto=format&fit=crop&q=80&w=800",
    likes: 5600,
    comments: 420,
    shares: 890,
    views: 18e3,
    totalVotes: 24500,
    options: [
      { id: "v1", text: "Doğa & Kamp", votes: 12500, image: "https://images.unsplash.com/photo-1504280390367-361c6d9f38f4?auto=format&fit=crop&q=80&w=400" },
      { id: "v2", text: "Şehir & Kültür", votes: 8200, image: "https://images.unsplash.com/photo-1449824913935-59a10b8d2000?auto=format&fit=crop&q=80&w=400" },
      { id: "v3", text: "Lüks & Otel", votes: 3800, image: "https://images.unsplash.com/photo-1566073771259-6a8506099945?auto=format&fit=crop&q=80&w=400" }
    ]
  },
  {
    id: "n1_2col_poll",
    type: NewsType.POLL,
    isImagePoll: true,
    pollColumns: 2,
    title: "Geleceğin Otomobili Sence Hangisi Olacak?",
    summary: "Otomobil dünyasında devrim kapıda. Sen hangi teknolojiye yatırım yapardın?",
    category: "Otomobil / Teknoloji",
    source: "Oto Haber",
    author: "Murat Aras",
    timestamp: "45 dk önce",
    mediaUrl: "",
    thumbnail: "https://images.unsplash.com/photo-1503376780353-7e6692767b70?auto=format&fit=crop&q=80&w=800",
    likes: 3100,
    comments: 156,
    shares: 230,
    views: 12e3,
    totalVotes: 18200,
    options: [
      { id: "c1", text: "Tamamen Elektrikli", votes: 11e3, image: "https://images.unsplash.com/photo-1593941707882-a5bba14938c7?auto=format&fit=crop&q=80&w=400" },
      { id: "c2", text: "Hidrojen Yakıtlı", votes: 7200, image: "https://images.unsplash.com/photo-1533106418989-88406c7cc8ca?auto=format&fit=crop&q=80&w=400" }
    ]
  },
  {
    id: "n_paragraph_1",
    type: NewsType.PARAGRAPH,
    title: "Günün İlham Veren Sözü",
    summary: "Hayatın anlamı ve bakış açısı üzerine Albert Einstein'dan unutulmaz bir düşünce.",
    category: "Yaşam / Psikoloji",
    source: "Günün Sözü",
    author: "Editör",
    timestamp: "Yeni",
    mediaUrl: "",
    thumbnail: "https://images.unsplash.com/photo-1499750310107-5fef28a66643?auto=format&fit=crop&q=80&w=800",
    likes: 12500,
    comments: 450,
    shares: 2300,
    views: 42e3,
    paragraphData: {
      items: [
        "Hayatınızı yaşamanın sadece iki yolu vardır. Biri, sanki hiçbir şey mucize değilmiş gibi. Diğeri ise, sanki her şey bir mucizeymiş gibi."
      ],
      quoteAuthor: "Albert Einstein"
    }
  }
];

const Feed = ({ newsData, title, onNewsSelect, onSourceClick, storiesData, siteSettings, navItems, selectedCategory, loading }) => {
  const [activeFilter, setActiveFilter] = useState("latest");
  const { t } = useLanguage();
  const resolvedTitle = title ? t(title) : void 0;
  const displayData = useMemo(() => {
    let sorted = [...newsData];
    if (activeFilter === "popular") {
      sorted.sort((a, b) => {
        if (a.isPinned !== b.isPinned) return b.isPinned ? -1 : 1;
        return b.likes + b.comments - (a.likes + a.comments);
      });
    }
    return sorted;
  }, [newsData, activeFilter]);
  return /* @__PURE__ */ jsxs("div", { className: "flex flex-col gap-6 pb-4", children: [
    /* @__PURE__ */ jsx(StoryBar, { initialStories: storiesData }),
    /* @__PURE__ */ jsx("div", { className: "px-1 mt-1 mb-2", children: /* @__PURE__ */ jsxs("div", { className: "flex flex-col sm:flex-row sm:items-center justify-between gap-4", children: [
      /* @__PURE__ */ jsx("div", { className: "space-y-1 overflow-hidden", children: /* @__PURE__ */ jsx("h2", { className: "text-xl sm:text-2xl font-bold text-gray-900 tracking-tight leading-none font-display whitespace-nowrap overflow-hidden text-ellipsis", children: resolvedTitle ? (() => {
        const words = resolvedTitle.split(" ");
        if (words.length <= 1) return resolvedTitle;
        const mid = Math.ceil(words.length / 2);
        const firstPart = words.slice(0, mid).join(" ");
        const secondPart = words.slice(mid).join(" ");
        return /* @__PURE__ */ jsxs(Fragment, { children: [
          firstPart,
          " ",
          /* @__PURE__ */ jsx("span", { className: "text-palette-tan font-medium opacity-60 ml-1", children: secondPart })
        ] });
      })() : loading ? /* @__PURE__ */ jsx(Skeleton, { className: "w-48 h-8 mb-1" }) : /* @__PURE__ */ jsxs(Fragment, { children: [
        t("feed.title_prefix"),
        " ",
        /* @__PURE__ */ jsx("span", { className: "text-palette-tan font-medium opacity-60 ml-1", children: t("feed.title_suffix") })
      ] }) }) }),
      /* @__PURE__ */ jsxs("div", { className: "flex p-1 bg-palette-beige/10 rounded-[5px] border border-palette-beige/20 backdrop-blur-sm self-start sm:self-auto shadow-inner", children: [
        /* @__PURE__ */ jsxs(
          "button",
          {
            onClick: () => setActiveFilter("latest"),
            className: `flex items-center gap-1.5 px-4 py-1.5 rounded-[5px] text-[11px] font-bold tracking-tight transition-all duration-75 ${activeFilter === "latest" ? "bg-palette-red text-white shadow-lg shadow-palette-red/20" : "text-palette-tan hover:text-palette-red"}`,
            children: [
              /* @__PURE__ */ jsx("span", { className: "material-symbols-rounded", style: { fontSize: "16px" }, children: "schedule" }),
              t("feed.latest")
            ]
          }
        ),
        /* @__PURE__ */ jsxs(
          "button",
          {
            onClick: () => setActiveFilter("popular"),
            className: `flex items-center gap-1.5 px-4 py-1.5 rounded-[5px] text-[11px] font-bold tracking-tight transition-all duration-75 ${activeFilter === "popular" ? "bg-palette-red text-white shadow-lg shadow-palette-red/20" : "text-palette-tan hover:text-palette-red"}`,
            children: [
              /* @__PURE__ */ jsx("span", { className: "material-symbols-rounded", style: { fontSize: "16px" }, children: "local_fire_department" }),
              t("feed.popular")
            ]
          }
        )
      ] })
    ] }) }),
    /* @__PURE__ */ jsx("div", { className: "flex flex-col gap-8", children: loading ? /* @__PURE__ */ jsx(Fragment, { children: [1, 2, 3].map((i) => /* @__PURE__ */ jsx(NewsCardSkeleton, {}, i)) }) : /* @__PURE__ */ jsxs(Fragment, { children: [
      displayData.map((news) => /* @__PURE__ */ jsx(
        NewsCard,
        {
          data: news,
          onClick: () => onNewsSelect?.(news.id),
          onSourceClick: () => onSourceClick?.(news.source),
          siteSettings,
          navItems
        },
        news.id
      )),
      displayData.length === 0 && /* @__PURE__ */ jsx("div", { className: "text-center py-20 bg-palette-beige/5 rounded-[5px] border border-dashed border-palette-beige/40", children: /* @__PURE__ */ jsx("span", { className: "text-palette-tan font-bold tracking-widest text-xs uppercase", children: t("feed.empty") }) })
    ] }) })
  ] });
};

const CATEGORY_STYLES = [
  { color: "text-[#FF6B00]", bg: "bg-[#FF6B00]/5", border: "border-[#FF6B00]/10" },
  { color: "text-[#448AFF]", bg: "bg-[#448AFF]/5", border: "border-[#448AFF]/10" },
  { color: "text-[#9C27B0]", bg: "bg-[#9C27B0]/5", border: "border-[#9C27B0]/10" },
  { color: "text-[#E91E63]", bg: "bg-[#E91E63]/5", border: "border-[#E91E63]/10" },
  { color: "text-[#3F51B5]", bg: "bg-[#3F51B5]/5", border: "border-[#3F51B5]/10" },
  { color: "text-[#00BCD4]", bg: "bg-[#00BCD4]/5", border: "border-[#00BCD4]/10" },
  { color: "text-[#4CAF50]", bg: "bg-[#4CAF50]/5", border: "border-[#4CAF50]/10" },
  { color: "text-[#FF5252]", bg: "bg-[#FF5252]/5", border: "border-[#FF5252]/10" }
];
const CategoriesList = ({ onBack, onCategorySelect }) => {
  const { currentLang, t } = useLanguage();
  const [categories, setCategories] = useState([]);
  const [loading, setLoading] = useState(true);
  const [searchTerm, setSearchTerm] = useState("");
  const [currentPage, setCurrentPage] = useState(1);
  const pageSize = 12;
  useEffect(() => {
    const fetchLiveData = async () => {
      try {
        setLoading(true);
        const { data: navData, error: navError } = await supabase.from("navigation_items").select("*").eq("type", "category").eq("is_active", true).eq("language_code", currentLang.code).order("order_index");
        if (navError) throw navError;
        const { data: postMetrics, error: metricsError } = await supabase.from("posts").select("category, likes_count, comments_count, shares_count").eq("status", "published").eq("language_code", currentLang.code);
        if (metricsError) throw metricsError;
        const stats = {};
        postMetrics?.forEach((p) => {
          if (!p.category) return;
          if (!stats[p.category]) stats[p.category] = { count: 0, likes: 0, comments: 0, shares: 0, views: 0 };
          stats[p.category].count += 1;
          stats[p.category].likes += p.likes_count || 0;
          stats[p.category].comments += p.comments_count || 0;
          stats[p.category].shares += p.shares_count || 0;
          stats[p.category].views += p.likes_count || 0;
        });
        if (navData) {
          const mapped = navData.map((item, idx) => {
            const style = CATEGORY_STYLES[idx % CATEGORY_STYLES.length];
            const val = item.value || item.label;
            const s = stats[val] || stats[item.label] || { count: 0, likes: 0, comments: 0, shares: 0, views: 0 };
            return {
              id: item.id,
              label: item.label,
              value: val,
              icon: item.icon || "grid_view",
              ...style,
              description: t(`${item.label}.description`) !== `${item.label}.description` ? t(`${item.label}.description`) : t(`cat.${val.toLowerCase()}.description`) !== `cat.${val.toLowerCase()}.description` ? t(`cat.${val.toLowerCase()}.description`) : t("categories.description_fallback").replace("{category}", t(item.label)),
              count: s.count,
              likes: s.likes,
              comments: s.comments,
              shares: s.shares,
              views: s.views,
              trendingScore: s.likes + s.comments * 2 + s.shares
            };
          });
          setCategories(mapped);
        }
      } catch (err) {
        console.error("Error:", err);
      } finally {
        setLoading(false);
      }
    };
    fetchLiveData();
  }, [currentLang.code, t]);
  const filteredCategories = useMemo(() => {
    return categories.filter(
      (cat) => t(cat.label).toLowerCase().includes(searchTerm.toLowerCase())
    );
  }, [categories, searchTerm, t]);
  const paginatedCategories = useMemo(() => {
    const start = (currentPage - 1) * pageSize;
    return filteredCategories.slice(start, start + pageSize);
  }, [filteredCategories, currentPage]);
  const totalPages = Math.ceil(filteredCategories.length / pageSize);
  const popularCategory = useMemo(() => {
    if (categories.length === 0) return null;
    return [...categories].sort((a, b) => b.trendingScore - a.trendingScore)[0];
  }, [categories]);
  const formatNumber = (num) => {
    if (num >= 1e3) return (num / 1e3).toFixed(1) + "K";
    return num.toString();
  };
  return /* @__PURE__ */ jsxs("div", { className: "bg-white rounded-[5px] border border-gray-200 overflow-hidden mb-10 min-h-screen flex flex-col", children: [
    /* @__PURE__ */ jsxs("div", { className: "p-6 md:p-8 border-b border-gray-100 bg-gray-50/30", children: [
      /* @__PURE__ */ jsxs("div", { className: "flex flex-col md:flex-row md:items-center justify-between gap-4 mb-8", children: [
        /* @__PURE__ */ jsxs(
          "button",
          {
            onClick: onBack,
            className: "flex items-center gap-2 text-gray-500 hover:text-palette-red font-bold text-[11px] uppercase tracking-widest transition-all",
            children: [
              /* @__PURE__ */ jsx(ArrowLeft, { size: 16 }),
              /* @__PURE__ */ jsx("span", { children: t("admin.post.go_back") })
            ]
          }
        ),
        /* @__PURE__ */ jsxs("div", { className: "relative w-full md:max-w-xs", children: [
          /* @__PURE__ */ jsx(Search, { size: 16, className: "absolute left-3 top-1/2 -translate-y-1/2 text-gray-400" }),
          /* @__PURE__ */ jsx(
            "input",
            {
              type: "text",
              placeholder: t("categories.search_placeholder"),
              value: searchTerm,
              onChange: (e) => {
                setSearchTerm(e.target.value);
                setCurrentPage(1);
              },
              className: "w-full h-10 pl-10 pr-4 bg-white border border-gray-200 rounded-[5px] text-sm font-medium focus:border-palette-red outline-none transition-all"
            }
          )
        ] })
      ] }),
      /* @__PURE__ */ jsxs("div", { className: "flex items-center gap-2 text-palette-red text-[10px] font-black uppercase tracking-[0.2em] mb-2", children: [
        /* @__PURE__ */ jsx(LayoutGrid, { size: 14 }),
        t("categories.hero_tag")
      ] }),
      /* @__PURE__ */ jsx("h1", { className: "text-3xl font-black text-gray-900 tracking-tight", children: t("categories.hero_title") })
    ] }),
    /* @__PURE__ */ jsx("div", { className: "p-6 md:p-8 flex-1", children: loading ? /* @__PURE__ */ jsx("div", { className: "grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4", children: Array(6).fill(0).map((_, i) => /* @__PURE__ */ jsx("div", { className: "h-40 bg-gray-50 animate-pulse rounded-[5px] border border-gray-100" }, i)) }) : filteredCategories.length === 0 ? /* @__PURE__ */ jsx("div", { className: "py-20 text-center text-gray-400 font-bold uppercase tracking-widest text-xs", children: t("common.no_results_found") }) : /* @__PURE__ */ jsx("div", { className: "grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6", children: paginatedCategories.map((cat) => /* @__PURE__ */ jsxs(
      "button",
      {
        onClick: () => onCategorySelect(cat.value),
        className: "group flex flex-col p-5 rounded-[5px] border border-gray-100 bg-white hover:border-palette-red/30 hover:shadow-lg transition-all text-left",
        children: [
          /* @__PURE__ */ jsxs("div", { className: "flex items-start gap-4 mb-4", children: [
            /* @__PURE__ */ jsx("div", { className: `w-12 h-12 ${cat.bg} ${cat.color} rounded-[5px] flex items-center justify-center shrink-0`, children: /* @__PURE__ */ jsx("span", { className: "material-symbols-rounded", style: { fontSize: "24px" }, children: cat.icon.toLowerCase() }) }),
            /* @__PURE__ */ jsxs("div", { children: [
              /* @__PURE__ */ jsx("h3", { className: "text-lg font-black text-gray-900 group-hover:text-palette-red transition-colors leading-tight", children: t(cat.label) }),
              /* @__PURE__ */ jsxs("p", { className: "text-[11px] text-gray-400 font-bold mt-1 uppercase tracking-wider", children: [
                cat.count,
                " ",
                t("common.news_upper")
              ] })
            ] })
          ] }),
          /* @__PURE__ */ jsx("p", { className: "text-sm text-gray-500 font-medium line-clamp-2 mb-4 h-10", children: cat.description }),
          /* @__PURE__ */ jsxs("div", { className: "grid grid-cols-4 gap-2 pt-4 border-t border-gray-50", children: [
            /* @__PURE__ */ jsxs("div", { className: "flex flex-col items-center", children: [
              /* @__PURE__ */ jsx("span", { className: "text-[9px] font-black text-gray-400 uppercase tracking-tighter", children: t("metrics.views") }),
              /* @__PURE__ */ jsx("span", { className: "text-xs font-black text-gray-700", children: formatNumber(cat.views) })
            ] }),
            /* @__PURE__ */ jsxs("div", { className: "flex flex-col items-center border-l border-gray-50", children: [
              /* @__PURE__ */ jsx("span", { className: "text-[9px] font-black text-gray-400 uppercase tracking-tighter", children: t("metrics.likes") }),
              /* @__PURE__ */ jsx("span", { className: "text-xs font-black text-gray-700", children: formatNumber(cat.likes) })
            ] }),
            /* @__PURE__ */ jsxs("div", { className: "flex flex-col items-center border-l border-gray-50", children: [
              /* @__PURE__ */ jsx("span", { className: "text-[9px] font-black text-gray-400 uppercase tracking-tighter", children: t("metrics.comments") }),
              /* @__PURE__ */ jsx("span", { className: "text-xs font-black text-gray-700", children: formatNumber(cat.comments) })
            ] }),
            /* @__PURE__ */ jsxs("div", { className: "flex flex-col items-center border-l border-gray-50", children: [
              /* @__PURE__ */ jsx("span", { className: "text-[9px] font-black text-gray-400 uppercase tracking-tighter", children: t("metrics.shares") }),
              /* @__PURE__ */ jsx("span", { className: "text-xs font-black text-gray-700", children: formatNumber(cat.shares) })
            ] })
          ] })
        ]
      },
      cat.id
    )) }) }),
    totalPages > 1 && !loading && /* @__PURE__ */ jsxs("div", { className: "p-6 border-t border-gray-100 flex items-center justify-between", children: [
      /* @__PURE__ */ jsxs("span", { className: "text-[10px] font-bold text-gray-400 uppercase tracking-widest", children: [
        filteredCategories.length,
        " ",
        t("common.category_upper")
      ] }),
      /* @__PURE__ */ jsxs("div", { className: "flex items-center gap-2", children: [
        /* @__PURE__ */ jsx(
          "button",
          {
            onClick: () => {
              setCurrentPage((p) => Math.max(1, p - 1));
              window.scrollTo(0, 0);
            },
            disabled: currentPage === 1,
            className: "w-8 h-8 flex items-center justify-center rounded-[5px] border border-gray-200 text-gray-400 hover:text-palette-red disabled:opacity-30",
            children: /* @__PURE__ */ jsx(ArrowLeft, { size: 16 })
          }
        ),
        /* @__PURE__ */ jsxs("span", { className: "text-xs font-black text-gray-900 mx-2", children: [
          currentPage,
          " / ",
          totalPages
        ] }),
        /* @__PURE__ */ jsx(
          "button",
          {
            onClick: () => {
              setCurrentPage((p) => Math.min(totalPages, p + 1));
              window.scrollTo(0, 0);
            },
            disabled: currentPage === totalPages,
            className: "w-8 h-8 flex items-center justify-center rounded-[5px] border border-gray-200 text-gray-400 hover:text-palette-red disabled:opacity-30 rotate-180",
            children: /* @__PURE__ */ jsx(ArrowLeft, { size: 16 })
          }
        )
      ] })
    ] }),
    !loading && popularCategory && currentPage === 1 && /* @__PURE__ */ jsxs("div", { className: "m-6 md:m-8 p-8 bg-gray-900 rounded-[5px] relative overflow-hidden group", children: [
      /* @__PURE__ */ jsx("div", { className: "absolute top-0 right-0 w-40 h-40 bg-palette-red rounded-full blur-[80px] opacity-20" }),
      /* @__PURE__ */ jsxs("div", { className: "relative z-10 flex flex-col md:flex-row items-center justify-between gap-6", children: [
        /* @__PURE__ */ jsxs("div", { className: "flex-1", children: [
          /* @__PURE__ */ jsxs("div", { className: "flex items-center gap-2 text-palette-red text-[10px] font-black uppercase tracking-[0.2em] mb-2", children: [
            /* @__PURE__ */ jsx(TrendingUp, { size: 14 }),
            t("common.week_star")
          ] }),
          /* @__PURE__ */ jsxs("h2", { className: "text-2xl font-black text-white tracking-tight mb-2", children: [
            t(popularCategory.label),
            " ",
            /* @__PURE__ */ jsxs("span", { className: "text-gray-400 font-normal", children: [
              "| ",
              t("categories.banner.cta")
            ] })
          ] }),
          /* @__PURE__ */ jsx("p", { className: "text-gray-400 text-sm font-medium", children: t("categories.banner.description").replace("{count}", formatNumber(popularCategory.views)) })
        ] }),
        /* @__PURE__ */ jsx(
          "button",
          {
            onClick: () => onCategorySelect(popularCategory.value),
            className: "shrink-0 px-8 py-3 bg-white text-gray-900 rounded-[5px] font-black text-xs h-fit hover:bg-palette-red hover:text-white transition-all shadow-xl",
            children: t("common.discover_now")
          }
        )
      ] })
    ] })
  ] });
};

const DISTRICT_STYLES = [
  { color: "text-[#FF6B00]", bg: "bg-[#FF6B00]/5", border: "border-[#FF6B00]/10" },
  { color: "text-[#448AFF]", bg: "bg-[#448AFF]/5", border: "border-[#448AFF]/10" },
  { color: "text-[#9C27B0]", bg: "bg-[#9C27B0]/5", border: "border-[#9C27B0]/10" },
  { color: "text-[#E91E63]", bg: "bg-[#E91E63]/5", border: "border-[#E91E63]/10" },
  { color: "text-[#3F51B5]", bg: "bg-[#3F51B5]/5", border: "border-[#3F51B5]/10" },
  { color: "text-[#00BCD4]", bg: "bg-[#00BCD4]/5", border: "border-[#00BCD4]/10" },
  { color: "text-[#4CAF50]", bg: "bg-[#4CAF50]/5", border: "border-[#4CAF50]/10" },
  { color: "text-[#FF5252]", bg: "bg-[#FF5252]/5", border: "border-[#FF5252]/10" }
];
const DistrictsList = ({ onBack, onDistrictSelect }) => {
  const { currentLang, t } = useLanguage();
  const [districts, setDistricts] = useState([]);
  const [loading, setLoading] = useState(true);
  const [searchTerm, setSearchTerm] = useState("");
  const [currentPage, setCurrentPage] = useState(1);
  const pageSize = 12;
  useEffect(() => {
    const fetchLiveData = async () => {
      try {
        setLoading(true);
        const { data: navData, error: navError } = await supabase.from("navigation_items").select("*").eq("type", "district").eq("is_active", true).eq("language_code", currentLang.code).order("order_index");
        if (navError) throw navError;
        const { data: postMetrics, error: metricsError } = await supabase.from("posts").select("category, likes_count, comments_count, shares_count").eq("status", "published").eq("language_code", currentLang.code);
        if (metricsError) throw metricsError;
        const stats = {};
        postMetrics?.forEach((p) => {
          if (!p.category) return;
          if (!stats[p.category]) stats[p.category] = { count: 0, likes: 0, comments: 0, shares: 0, views: 0 };
          stats[p.category].count += 1;
          stats[p.category].likes += p.likes_count || 0;
          stats[p.category].comments += p.comments_count || 0;
          stats[p.category].shares += p.shares_count || 0;
          stats[p.category].views += p.likes_count || 0;
        });
        if (navData) {
          const mapped = navData.map((item, idx) => {
            const style = DISTRICT_STYLES[idx % DISTRICT_STYLES.length];
            const val = item.value || item.label;
            const s = stats[val] || stats[item.label] || { count: 0, likes: 0, comments: 0, shares: 0, views: 0 };
            return {
              id: item.id,
              label: item.label,
              value: val,
              icon: item.icon || "location_on",
              ...style,
              description: t(`${item.label}.description`) !== `${item.label}.description` ? t(`${item.label}.description`) : t(`dist.${val.toLowerCase()}.description`) !== `dist.${val.toLowerCase()}.description` ? t(`dist.${val.toLowerCase()}.description`) : t("districts.description_fallback").replace("{district}", t(item.label)),
              count: s.count,
              likes: s.likes,
              comments: s.comments,
              shares: s.shares,
              views: s.views,
              trendingScore: s.likes + s.comments * 2 + s.shares
            };
          });
          setDistricts(mapped);
        }
      } catch (err) {
        console.error("Error:", err);
      } finally {
        setLoading(false);
      }
    };
    fetchLiveData();
  }, [currentLang.code, t]);
  const filteredDistricts = useMemo(() => {
    return districts.filter(
      (dist) => t(dist.label).toLowerCase().includes(searchTerm.toLowerCase())
    );
  }, [districts, searchTerm, t]);
  const paginatedDistricts = useMemo(() => {
    const start = (currentPage - 1) * pageSize;
    return filteredDistricts.slice(start, start + pageSize);
  }, [filteredDistricts, currentPage]);
  const totalPages = Math.ceil(filteredDistricts.length / pageSize);
  const popularDistrict = useMemo(() => {
    if (districts.length === 0) return null;
    return [...districts].sort((a, b) => b.trendingScore - a.trendingScore)[0];
  }, [districts]);
  const formatNumber = (num) => {
    if (num >= 1e3) return (num / 1e3).toFixed(1) + "K";
    return num.toString();
  };
  return /* @__PURE__ */ jsxs("div", { className: "bg-white rounded-[5px] border border-gray-200 overflow-hidden mb-10 min-h-screen flex flex-col", children: [
    /* @__PURE__ */ jsxs("div", { className: "p-6 md:p-8 border-b border-gray-100 bg-gray-50/30", children: [
      /* @__PURE__ */ jsxs("div", { className: "flex flex-col md:flex-row md:items-center justify-between gap-4 mb-8", children: [
        /* @__PURE__ */ jsxs(
          "button",
          {
            onClick: onBack,
            className: "flex items-center gap-2 text-gray-500 hover:text-palette-red font-bold text-[11px] uppercase tracking-widest transition-all",
            children: [
              /* @__PURE__ */ jsx(ArrowLeft, { size: 16 }),
              /* @__PURE__ */ jsx("span", { children: t("admin.post.go_back") })
            ]
          }
        ),
        /* @__PURE__ */ jsxs("div", { className: "relative w-full md:max-w-xs", children: [
          /* @__PURE__ */ jsx(Search, { size: 16, className: "absolute left-3 top-1/2 -translate-y-1/2 text-gray-400" }),
          /* @__PURE__ */ jsx(
            "input",
            {
              type: "text",
              placeholder: t("districts.search_placeholder"),
              value: searchTerm,
              onChange: (e) => {
                setSearchTerm(e.target.value);
                setCurrentPage(1);
              },
              className: "w-full h-10 pl-10 pr-4 bg-white border border-gray-200 rounded-[5px] text-sm font-medium focus:border-palette-red outline-none transition-all"
            }
          )
        ] })
      ] }),
      /* @__PURE__ */ jsxs("div", { className: "flex items-center gap-2 text-palette-red text-[10px] font-black uppercase tracking-[0.2em] mb-2", children: [
        /* @__PURE__ */ jsx(MapPin, { size: 14 }),
        t("districts.hero_tag")
      ] }),
      /* @__PURE__ */ jsx("h1", { className: "text-3xl font-black text-gray-900 tracking-tight", children: t("districts.hero_title") })
    ] }),
    /* @__PURE__ */ jsx("div", { className: "p-6 md:p-8 flex-1", children: loading ? /* @__PURE__ */ jsx("div", { className: "grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4", children: Array(6).fill(0).map((_, i) => /* @__PURE__ */ jsx("div", { className: "h-40 bg-gray-50 animate-pulse rounded-[5px] border border-gray-100" }, i)) }) : filteredDistricts.length === 0 ? /* @__PURE__ */ jsx("div", { className: "py-20 text-center text-gray-400 font-bold uppercase tracking-widest text-xs", children: t("common.no_results_found") }) : /* @__PURE__ */ jsx("div", { className: "grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6", children: paginatedDistricts.map((dist) => /* @__PURE__ */ jsxs(
      "button",
      {
        onClick: () => onDistrictSelect(dist.value),
        className: "group flex flex-col p-5 rounded-[5px] border border-gray-100 bg-white hover:border-palette-red/30 hover:shadow-lg transition-all text-left",
        children: [
          /* @__PURE__ */ jsxs("div", { className: "flex items-start gap-4 mb-4", children: [
            /* @__PURE__ */ jsx("div", { className: `w-12 h-12 ${dist.bg} ${dist.color} rounded-[5px] flex items-center justify-center shrink-0`, children: /* @__PURE__ */ jsx("span", { className: "material-symbols-rounded", style: { fontSize: "24px" }, children: dist.icon.toLowerCase() }) }),
            /* @__PURE__ */ jsxs("div", { children: [
              /* @__PURE__ */ jsx("h3", { className: "text-lg font-black text-gray-900 group-hover:text-palette-red transition-colors leading-tight", children: t(dist.label) }),
              /* @__PURE__ */ jsxs("p", { className: "text-[11px] text-gray-400 font-bold mt-1 uppercase tracking-wider", children: [
                dist.count,
                " ",
                t("common.news_upper")
              ] })
            ] })
          ] }),
          /* @__PURE__ */ jsx("p", { className: "text-sm text-gray-500 font-medium line-clamp-2 mb-4 h-10", children: dist.description }),
          /* @__PURE__ */ jsxs("div", { className: "grid grid-cols-4 gap-2 pt-4 border-t border-gray-50", children: [
            /* @__PURE__ */ jsxs("div", { className: "flex flex-col items-center", children: [
              /* @__PURE__ */ jsx("span", { className: "text-[9px] font-black text-gray-400 uppercase tracking-tighter", children: t("metrics.views") }),
              /* @__PURE__ */ jsx("span", { className: "text-xs font-black text-gray-700", children: formatNumber(dist.views) })
            ] }),
            /* @__PURE__ */ jsxs("div", { className: "flex flex-col items-center border-l border-gray-50", children: [
              /* @__PURE__ */ jsx("span", { className: "text-[9px] font-black text-gray-400 uppercase tracking-tighter", children: t("metrics.likes") }),
              /* @__PURE__ */ jsx("span", { className: "text-xs font-black text-gray-700", children: formatNumber(dist.likes) })
            ] }),
            /* @__PURE__ */ jsxs("div", { className: "flex flex-col items-center border-l border-gray-50", children: [
              /* @__PURE__ */ jsx("span", { className: "text-[9px] font-black text-gray-400 uppercase tracking-tighter", children: t("metrics.comments") }),
              /* @__PURE__ */ jsx("span", { className: "text-xs font-black text-gray-700", children: formatNumber(dist.comments) })
            ] }),
            /* @__PURE__ */ jsxs("div", { className: "flex flex-col items-center border-l border-gray-50", children: [
              /* @__PURE__ */ jsx("span", { className: "text-[9px] font-black text-gray-400 uppercase tracking-tighter", children: t("metrics.shares") }),
              /* @__PURE__ */ jsx("span", { className: "text-xs font-black text-gray-700", children: formatNumber(dist.shares) })
            ] })
          ] })
        ]
      },
      dist.id
    )) }) }),
    totalPages > 1 && !loading && /* @__PURE__ */ jsxs("div", { className: "p-6 border-t border-gray-100 flex items-center justify-between", children: [
      /* @__PURE__ */ jsxs("span", { className: "text-[10px] font-bold text-gray-400 uppercase tracking-widest", children: [
        filteredDistricts.length,
        " ",
        t("common.district_upper")
      ] }),
      /* @__PURE__ */ jsxs("div", { className: "flex items-center gap-2", children: [
        /* @__PURE__ */ jsx(
          "button",
          {
            onClick: () => {
              setCurrentPage((p) => Math.max(1, p - 1));
              window.scrollTo(0, 0);
            },
            disabled: currentPage === 1,
            className: "w-8 h-8 flex items-center justify-center rounded-[5px] border border-gray-200 text-gray-400 hover:text-palette-red disabled:opacity-30",
            children: /* @__PURE__ */ jsx(ArrowLeft, { size: 16 })
          }
        ),
        /* @__PURE__ */ jsxs("span", { className: "text-xs font-black text-gray-900 mx-2", children: [
          currentPage,
          " / ",
          totalPages
        ] }),
        /* @__PURE__ */ jsx(
          "button",
          {
            onClick: () => {
              setCurrentPage((p) => Math.min(totalPages, p + 1));
              window.scrollTo(0, 0);
            },
            disabled: currentPage === totalPages,
            className: "w-8 h-8 flex items-center justify-center rounded-[5px] border border-gray-200 text-gray-400 hover:text-palette-red disabled:opacity-30 rotate-180",
            children: /* @__PURE__ */ jsx(ArrowLeft, { size: 16 })
          }
        )
      ] })
    ] }),
    !loading && popularDistrict && currentPage === 1 && /* @__PURE__ */ jsxs("div", { className: "m-6 md:m-8 p-8 bg-gray-900 rounded-[5px] relative overflow-hidden group", children: [
      /* @__PURE__ */ jsx("div", { className: "absolute top-0 right-0 w-40 h-40 bg-palette-red rounded-full blur-[80px] opacity-20" }),
      /* @__PURE__ */ jsxs("div", { className: "relative z-10 flex flex-col md:flex-row items-center justify-between gap-6", children: [
        /* @__PURE__ */ jsxs("div", { className: "flex-1", children: [
          /* @__PURE__ */ jsxs("div", { className: "flex items-center gap-2 text-palette-red text-[10px] font-black uppercase tracking-[0.2em] mb-2", children: [
            /* @__PURE__ */ jsx(TrendingUp, { size: 14 }),
            t("common.week_star")
          ] }),
          /* @__PURE__ */ jsxs("h2", { className: "text-2xl font-black text-white tracking-tight mb-2", children: [
            t(popularDistrict.label),
            " ",
            /* @__PURE__ */ jsxs("span", { className: "text-gray-400 font-normal", children: [
              "| ",
              t("districts.banner.cta")
            ] })
          ] }),
          /* @__PURE__ */ jsx("p", { className: "text-gray-400 text-sm font-medium", children: t("districts.banner.description").replace("{count}", formatNumber(popularDistrict.views)) })
        ] }),
        /* @__PURE__ */ jsx(
          "button",
          {
            onClick: () => onDistrictSelect(popularDistrict.value),
            className: "shrink-0 px-8 py-3 bg-white text-gray-900 rounded-[5px] font-black text-xs h-fit hover:bg-palette-red hover:text-white transition-all shadow-xl",
            children: t("common.discover_now")
          }
        )
      ] })
    ] })
  ] });
};

const TREND_STYLES = [
  { color: "text-[#FF6B00]", bg: "bg-[#FF6B00]/5", border: "border-[#FF6B00]/10" },
  { color: "text-[#448AFF]", bg: "bg-[#448AFF]/5", border: "border-[#448AFF]/10" },
  { color: "text-[#9C27B0]", bg: "bg-[#9C27B0]/5", border: "border-[#9C27B0]/10" },
  { color: "text-[#E91E63]", bg: "bg-[#E91E63]/5", border: "border-[#E91E63]/10" },
  { color: "text-[#3F51B5]", bg: "bg-[#3F51B5]/5", border: "border-[#3F51B5]/10" },
  { color: "text-[#00BCD4]", bg: "bg-[#00BCD4]/5", border: "border-[#00BCD4]/10" },
  { color: "text-[#4CAF50]", bg: "bg-[#4CAF50]/5", border: "border-[#4CAF50]/10" },
  { color: "text-[#FF5252]", bg: "bg-[#FF5252]/5", border: "border-[#FF5252]/10" }
];
const TrendsList = ({ onBack, onTrendSelect }) => {
  const { currentLang, t } = useLanguage();
  const [trends, setTrends] = useState([]);
  const [loading, setLoading] = useState(true);
  const [searchTerm, setSearchTerm] = useState("");
  const [currentPage, setCurrentPage] = useState(1);
  const pageSize = 12;
  useEffect(() => {
    const fetchLiveData = async () => {
      try {
        setLoading(true);
        const { data: navData, error: navError } = await supabase.from("navigation_items").select("*").eq("type", "trends").eq("is_active", true).eq("language_code", currentLang.code).order("order_index");
        if (navError) throw navError;
        const { data: postMetrics, error: metricsError } = await supabase.from("posts").select("category, likes_count, comments_count, shares_count").eq("status", "published").eq("language_code", currentLang.code);
        if (metricsError) throw metricsError;
        const stats = {};
        postMetrics?.forEach((p) => {
          if (!p.category) return;
          if (!stats[p.category]) stats[p.category] = { count: 0, likes: 0, comments: 0, shares: 0, views: 0 };
          stats[p.category].count += 1;
          stats[p.category].likes += p.likes_count || 0;
          stats[p.category].comments += p.comments_count || 0;
          stats[p.category].shares += p.shares_count || 0;
          stats[p.category].views += p.likes_count || 0;
        });
        if (navData) {
          const mapped = navData.map((item, idx) => {
            const style = TREND_STYLES[idx % TREND_STYLES.length];
            const val = item.value || item.label;
            const s = stats[val] || stats[item.label] || { count: 0, likes: 0, comments: 0, shares: 0, views: 0 };
            return {
              id: item.id,
              label: item.label,
              value: val,
              icon: item.icon || "flame",
              ...style,
              description: t(`${item.label}.description`) !== `${item.label}.description` ? t(`${item.label}.description`) : t(`trend.${val.toLowerCase()}.description`) !== `trend.${val.toLowerCase()}.description` ? t(`trend.${val.toLowerCase()}.description`) : t("trends.description_fallback").replace("{trend}", t(item.label)),
              count: s.count,
              likes: s.likes,
              comments: s.comments,
              shares: s.shares,
              views: s.views,
              trendingScore: s.likes + s.comments * 2 + s.shares
            };
          });
          setTrends(mapped);
        }
      } catch (err) {
        console.error("Error:", err);
      } finally {
        setLoading(false);
      }
    };
    fetchLiveData();
  }, [currentLang.code, t]);
  const filteredTrends = useMemo(() => {
    return trends.filter(
      (trend) => t(trend.label).toLowerCase().includes(searchTerm.toLowerCase())
    );
  }, [trends, searchTerm, t]);
  const paginatedTrends = useMemo(() => {
    const start = (currentPage - 1) * pageSize;
    return filteredTrends.slice(start, start + pageSize);
  }, [filteredTrends, currentPage]);
  const totalPages = Math.ceil(filteredTrends.length / pageSize);
  const popularTrend = useMemo(() => {
    if (trends.length === 0) return null;
    return [...trends].sort((a, b) => b.trendingScore - a.trendingScore)[0];
  }, [trends]);
  const formatNumber = (num) => {
    if (num >= 1e3) return (num / 1e3).toFixed(1) + "K";
    return num.toString();
  };
  return /* @__PURE__ */ jsxs("div", { className: "bg-white rounded-[5px] border border-gray-200 overflow-hidden mb-10 min-h-screen flex flex-col", children: [
    /* @__PURE__ */ jsxs("div", { className: "p-6 md:p-8 border-b border-gray-100 bg-gray-50/30", children: [
      /* @__PURE__ */ jsxs("div", { className: "flex flex-col md:flex-row md:items-center justify-between gap-4 mb-8", children: [
        /* @__PURE__ */ jsxs(
          "button",
          {
            onClick: onBack,
            className: "flex items-center gap-2 text-gray-500 hover:text-palette-red font-bold text-[11px] uppercase tracking-widest transition-all",
            children: [
              /* @__PURE__ */ jsx(ArrowLeft, { size: 16 }),
              /* @__PURE__ */ jsx("span", { children: t("admin.post.go_back") })
            ]
          }
        ),
        /* @__PURE__ */ jsxs("div", { className: "relative w-full md:max-w-xs", children: [
          /* @__PURE__ */ jsx(Search, { size: 16, className: "absolute left-3 top-1/2 -translate-y-1/2 text-gray-400" }),
          /* @__PURE__ */ jsx(
            "input",
            {
              type: "text",
              placeholder: t("trends.search_placeholder"),
              value: searchTerm,
              onChange: (e) => {
                setSearchTerm(e.target.value);
                setCurrentPage(1);
              },
              className: "w-full h-10 pl-10 pr-4 bg-white border border-gray-200 rounded-[5px] text-sm font-medium focus:border-palette-red outline-none transition-all"
            }
          )
        ] })
      ] }),
      /* @__PURE__ */ jsxs("div", { className: "flex items-center gap-2 text-palette-red text-[10px] font-black uppercase tracking-[0.2em] mb-2", children: [
        /* @__PURE__ */ jsx(Flame, { size: 14 }),
        t("trends.hero_tag")
      ] }),
      /* @__PURE__ */ jsx("h1", { className: "text-3xl font-black text-gray-900 tracking-tight", children: t("trends.hero_title") })
    ] }),
    /* @__PURE__ */ jsx("div", { className: "p-6 md:p-8 flex-1", children: loading ? /* @__PURE__ */ jsx("div", { className: "grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4", children: Array(6).fill(0).map((_, i) => /* @__PURE__ */ jsx("div", { className: "h-40 bg-gray-50 animate-pulse rounded-[5px] border border-gray-100" }, i)) }) : filteredTrends.length === 0 ? /* @__PURE__ */ jsx("div", { className: "py-20 text-center text-gray-400 font-bold uppercase tracking-widest text-xs", children: t("common.no_results_found") }) : /* @__PURE__ */ jsx("div", { className: "grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6", children: paginatedTrends.map((trend) => /* @__PURE__ */ jsxs(
      "button",
      {
        onClick: () => onTrendSelect(trend.value),
        className: "group flex flex-col p-5 rounded-[5px] border border-gray-100 bg-white hover:border-palette-red/30 hover:shadow-lg transition-all text-left",
        children: [
          /* @__PURE__ */ jsxs("div", { className: "flex items-start gap-4 mb-4", children: [
            /* @__PURE__ */ jsx("div", { className: `w-12 h-12 ${trend.bg} ${trend.color} rounded-[5px] flex items-center justify-center shrink-0`, children: /* @__PURE__ */ jsx("span", { className: "material-symbols-rounded", style: { fontSize: "24px" }, children: trend.icon.toLowerCase() }) }),
            /* @__PURE__ */ jsxs("div", { children: [
              /* @__PURE__ */ jsx("h3", { className: "text-lg font-black text-gray-900 group-hover:text-palette-red transition-colors leading-tight", children: t(trend.label) }),
              /* @__PURE__ */ jsxs("p", { className: "text-[11px] text-gray-400 font-bold mt-1 uppercase tracking-wider", children: [
                trend.count,
                " ",
                t("common.news_upper")
              ] })
            ] })
          ] }),
          /* @__PURE__ */ jsx("p", { className: "text-sm text-gray-500 font-medium line-clamp-2 mb-4 h-10", children: trend.description }),
          /* @__PURE__ */ jsxs("div", { className: "grid grid-cols-4 gap-2 pt-4 border-t border-gray-50", children: [
            /* @__PURE__ */ jsxs("div", { className: "flex flex-col items-center", children: [
              /* @__PURE__ */ jsx("span", { className: "text-[9px] font-black text-gray-400 uppercase tracking-tighter", children: t("metrics.views") }),
              /* @__PURE__ */ jsx("span", { className: "text-xs font-black text-gray-700", children: formatNumber(trend.views) })
            ] }),
            /* @__PURE__ */ jsxs("div", { className: "flex flex-col items-center border-l border-gray-50", children: [
              /* @__PURE__ */ jsx("span", { className: "text-[9px] font-black text-gray-400 uppercase tracking-tighter", children: t("metrics.likes") }),
              /* @__PURE__ */ jsx("span", { className: "text-xs font-black text-gray-700", children: formatNumber(trend.likes) })
            ] }),
            /* @__PURE__ */ jsxs("div", { className: "flex flex-col items-center border-l border-gray-50", children: [
              /* @__PURE__ */ jsx("span", { className: "text-[9px] font-black text-gray-400 uppercase tracking-tighter", children: t("metrics.comments") }),
              /* @__PURE__ */ jsx("span", { className: "text-xs font-black text-gray-700", children: formatNumber(trend.comments) })
            ] }),
            /* @__PURE__ */ jsxs("div", { className: "flex flex-col items-center border-l border-gray-50", children: [
              /* @__PURE__ */ jsx("span", { className: "text-[9px] font-black text-gray-400 uppercase tracking-tighter", children: t("metrics.shares") }),
              /* @__PURE__ */ jsx("span", { className: "text-xs font-black text-gray-700", children: formatNumber(trend.shares) })
            ] })
          ] })
        ]
      },
      trend.id
    )) }) }),
    totalPages > 1 && !loading && /* @__PURE__ */ jsxs("div", { className: "p-6 border-t border-gray-100 flex items-center justify-between", children: [
      /* @__PURE__ */ jsxs("span", { className: "text-[10px] font-bold text-gray-400 uppercase tracking-widest", children: [
        filteredTrends.length,
        " ",
        t("common.trend_topic_upper")
      ] }),
      /* @__PURE__ */ jsxs("div", { className: "flex items-center gap-2", children: [
        /* @__PURE__ */ jsx(
          "button",
          {
            onClick: () => {
              setCurrentPage((p) => Math.max(1, p - 1));
              window.scrollTo(0, 0);
            },
            disabled: currentPage === 1,
            className: "w-8 h-8 flex items-center justify-center rounded-[5px] border border-gray-200 text-gray-400 hover:text-palette-red disabled:opacity-30",
            children: /* @__PURE__ */ jsx(ArrowLeft, { size: 16 })
          }
        ),
        /* @__PURE__ */ jsxs("span", { className: "text-xs font-black text-gray-900 mx-2", children: [
          currentPage,
          " / ",
          totalPages
        ] }),
        /* @__PURE__ */ jsx(
          "button",
          {
            onClick: () => {
              setCurrentPage((p) => Math.min(totalPages, p + 1));
              window.scrollTo(0, 0);
            },
            disabled: currentPage === totalPages,
            className: "w-8 h-8 flex items-center justify-center rounded-[5px] border border-gray-200 text-gray-400 hover:text-palette-red disabled:opacity-30 rotate-180",
            children: /* @__PURE__ */ jsx(ArrowLeft, { size: 16 })
          }
        )
      ] })
    ] }),
    !loading && popularTrend && currentPage === 1 && /* @__PURE__ */ jsxs("div", { className: "m-6 md:m-8 p-8 bg-gray-900 rounded-[5px] relative overflow-hidden group", children: [
      /* @__PURE__ */ jsx("div", { className: "absolute top-0 right-0 w-40 h-40 bg-palette-red rounded-full blur-[80px] opacity-20" }),
      /* @__PURE__ */ jsxs("div", { className: "relative z-10 flex flex-col md:flex-row items-center justify-between gap-6", children: [
        /* @__PURE__ */ jsxs("div", { className: "flex-1", children: [
          /* @__PURE__ */ jsxs("div", { className: "flex items-center gap-2 text-palette-red text-[10px] font-black uppercase tracking-[0.2em] mb-2", children: [
            /* @__PURE__ */ jsx(TrendingUp, { size: 14 }),
            t("common.week_star")
          ] }),
          /* @__PURE__ */ jsxs("h2", { className: "text-2xl font-black text-white tracking-tight mb-2", children: [
            t(popularTrend.label),
            " ",
            /* @__PURE__ */ jsxs("span", { className: "text-gray-400 font-normal", children: [
              "| ",
              t("trends.banner.cta")
            ] })
          ] }),
          /* @__PURE__ */ jsx("p", { className: "text-gray-400 text-sm font-medium", children: t("trends.banner.description").replace("{count}", formatNumber(popularTrend.views)) })
        ] }),
        /* @__PURE__ */ jsx(
          "button",
          {
            onClick: () => onTrendSelect(popularTrend.value),
            className: "shrink-0 px-8 py-3 bg-white text-gray-900 rounded-[5px] font-black text-xs h-fit hover:bg-palette-red hover:text-white transition-all shadow-xl",
            children: t("common.discover_now")
          }
        )
      ] })
    ] })
  ] });
};

const HomePage = ({
  initialLang,
  initialTranslations,
  siteSettings,
  navigationItems,
  newsItems: initialNews,
  storiesItems,
  selectedCategory: initialCategory,
  isInitialHome = true
}) => {
  const [displayNews, setDisplayNews] = useState(initialNews);
  const [activeCat, setActiveCat] = useState(initialCategory || null);
  const [isNewsLoading, setIsNewsLoading] = useState(false);
  const [activeView, setActiveView] = useState("feed");
  const handleCategoryNavigation = useCallback(async (category) => {
    const normalize = (value) => {
      const v = (value || "").trim();
      if (!v || v === "home" || v === "null") return null;
      return v;
    };
    const normalized = normalize(category);
    if (!normalized) {
      setActiveCat(null);
      setDisplayNews(initialNews);
      return;
    }
    const normalizedSlug = slugify(normalized);
    const navItem = navigationItems.find(
      (item) => item.value === normalized || item.label === normalized || item.value && slugify(item.value) === normalizedSlug || slugify(item.label) === normalizedSlug
    );
    if (!navItem) {
      void navigate(`/kategori/${slugify(normalized)}`);
      return;
    }
    const isMain = !navItem.parent_id || navItem.parent_id === "root";
    navItem.type === "trends";
    navItem.type === "district";
    if (isMain) {
      const children = navigationItems.filter((i) => i.parent_id === navItem.id);
      const rootSlug = (navItem.value || navItem.label || "").trim();
      const subSlugs = children.map((c) => (c.value || c.label || "").trim()).filter(Boolean);
      const broadFilters = Array.from(/* @__PURE__ */ new Set([
        rootSlug,
        rootSlug.toLowerCase(),
        slugify(rootSlug),
        ...subSlugs,
        ...subSlugs.map((s) => s.toLowerCase()),
        ...subSlugs.map((s) => slugify(s))
      ])).filter(Boolean);
      setIsNewsLoading(true);
      try {
        document.cookie = `pateez_active_cat=${encodeURIComponent(normalized)}; path=/; max-age=31536000; SameSite=Lax`;
        if (window.location.pathname !== "/" && window.location.pathname !== "") {
          void navigate("/");
          return;
        }
        const langCode = typeof initialLang === "object" && initialLang !== null ? initialLang.code : initialLang;
        const news = await dataService.getNewsItems(langCode, broadFilters);
        setDisplayNews(news);
        setActiveCat(normalized);
      } catch (err) {
        console.error("Filtering error:", err);
        setActiveCat(null);
        setDisplayNews(initialNews);
      } finally {
        setIsNewsLoading(false);
      }
    } else {
      void navigate(`/kategori/${slugify(normalized)}`);
    }
  }, [navigationItems, initialNews, initialLang]);
  const handleNewsSelect = useCallback((id) => {
    const selected = displayNews.find((n) => n.id === id);
    selected?.slug || id;
    void navigate();
  }, [displayNews]);
  const categoryTitleKey = useMemo(() => {
    if (!activeCat) return void 0;
    const normalized = String(activeCat).trim();
    const normalizedSlug = slugify(normalized);
    const navItem = navigationItems.find(
      (i) => i.value === normalized || i.label === normalized || i.value && slugify(i.value) === normalizedSlug || slugify(i.label) === normalizedSlug
    );
    const isMain = navItem && (!navItem.parent_id || navItem.parent_id === "root");
    if (isMain) return void 0;
    return navItem?.label || normalized;
  }, [navigationItems, activeCat]);
  return /* @__PURE__ */ jsx(LanguageProvider, { initialLang, initialTranslations, children: /* @__PURE__ */ jsx(ToastProvider, { children: /* @__PURE__ */ jsx("div", { className: "min-h-screen bg-gray-50 text-gray-900 transition-opacity duration-300 opacity-100", children: /* @__PURE__ */ jsxs("main", { className: "max-w-[1280px] pt-[84px] gap-8 px-4 mx-auto flex justify-center items-start", children: [
    /* @__PURE__ */ jsx("aside", { className: "hidden lg:block w-[260px] flex-shrink-0 sticky top-[84px] h-[calc(100vh-84px)] overflow-y-auto pb-8 no-scrollbar", children: /* @__PURE__ */ jsx(
      Sidebar,
      {
        items: navigationItems,
        activeCategory: activeCat,
        onCategoryItemClick: (cat) => {
          setActiveView("feed");
          handleCategoryNavigation(cat);
        },
        onAllCategoriesClick: () => setActiveView("categories"),
        onAllDistrictsClick: () => setActiveView("districts"),
        onAllTrendsClick: () => setActiveView("trends"),
        loading: navigationItems.length === 0
      }
    ) }),
    /* @__PURE__ */ jsx("section", { className: "flex-1 min-w-0 pb-10 flex justify-center w-full", children: /* @__PURE__ */ jsx("div", { className: "w-full max-w-[840px]", children: activeView === "feed" ? /* @__PURE__ */ jsx(
      Feed,
      {
        newsData: displayNews,
        storiesData: storiesItems,
        siteSettings,
        navItems: navigationItems,
        selectedCategory: activeCat || void 0,
        title: categoryTitleKey,
        onNewsSelect: handleNewsSelect,
        loading: isNewsLoading || initialNews.length === 0
      }
    ) : activeView === "categories" ? /* @__PURE__ */ jsx(
      CategoriesList,
      {
        onBack: () => setActiveView("feed"),
        onCategorySelect: (val) => {
          setActiveView("feed");
          handleCategoryNavigation(val);
        }
      }
    ) : activeView === "districts" ? /* @__PURE__ */ jsx(
      DistrictsList,
      {
        onBack: () => setActiveView("feed"),
        onDistrictSelect: (val) => {
          setActiveView("feed");
          handleCategoryNavigation(val);
        }
      }
    ) : /* @__PURE__ */ jsx(
      TrendsList,
      {
        onBack: () => setActiveView("feed"),
        onTrendSelect: (val) => {
          setActiveView("feed");
          handleCategoryNavigation(val);
        }
      }
    ) }) }),
    activeView === "feed" && /* @__PURE__ */ jsx("aside", { className: "hidden xl:block w-[320px] flex-shrink-0 pb-8", children: /* @__PURE__ */ jsx(RightSidebar, { newsData: displayNews, loading: initialNews.length === 0 }) })
  ] }) }) }) });
};

export { HomePage as H };
