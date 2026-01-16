/* empty css                                     */
import { c as createComponent, b as createAstro, r as renderComponent, a as renderTemplate } from '../../chunks/astro/server_CUMT7Dv3.mjs';
import 'piccolore';
import { u as useLanguage, a as useToast, L as LanguageProvider, T as ToastProvider, l as loadLocaleData, $ as $$Layout } from '../../chunks/Layout_DqQfhmns.mjs';
import { jsxs, jsx } from 'react/jsx-runtime';
import React, { useState, useEffect } from 'react';
import { Home, ChevronRight, CheckCircle2, Calendar, Clock, Share2, ArrowLeft, Twitter, Facebook, Linkedin, Link, Heart, Bookmark } from 'lucide-react';
import { N as NewsType, d as dataService } from '../../chunks/dataService_Bp0vcODm.mjs';
import { E as EmbedCard, A as AudioCard, V as VideoCard, R as ReviewCard, F as FlipCard, B as BeforeAfterCard, a as VSCard, P as PollCard, G as GalleryCard, b as ParagraphCard, C as CommentSection, c as RightSidebar } from '../../chunks/RightSidebar_cFIEXALx.mjs';
import { s as slugify } from '../../chunks/helpers_xme2WEyl.mjs';
import { r as resolveLangCode } from '../../chunks/lang_B1d4Ts2g.mjs';
import { a as getImage } from '../../chunks/_astro_assets_DfkzboBU.mjs';
export { renderers } from '../../renderers.mjs';

const NewsDetail = ({ data, onBack, navItems, loading }) => {
  const [scrollProgress, setScrollProgress] = useState(0);
  const [selectedEmojis, setSelectedEmojis] = useState([]);
  const { t, currentLang } = useLanguage();
  const { showToast } = useToast();
  const stripHtml = (html) => (html || "").replace(/<[^>]*>?/gm, "").replace(/&nbsp;/g, " ").trim();
  const shareUrl = typeof window !== "undefined" ? `${window.location.origin}/haber/${data.slug || data.id}` : "";
  const getUtmUrl = (source) => {
    return `${shareUrl}?utm_source=${source}&utm_medium=social&utm_campaign=news_detail&utm_content=${data.slug || data.id}`;
  };
  const shareToTwitter = () => {
    const cleanTitle = stripHtml(data.title);
    const url = getUtmUrl("twitter");
    window.open(`https://twitter.com/intent/tweet?text=${encodeURIComponent("🔥 " + cleanTitle)}&url=${encodeURIComponent(url)}`, "_blank", "noopener,noreferrer");
  };
  const shareToFacebook = () => {
    const url = getUtmUrl("facebook");
    window.open(`https://www.facebook.com/sharer/sharer.php?u=${encodeURIComponent(url)}`, "_blank", "noopener,noreferrer");
  };
  const copyLink = async () => {
    const url = getUtmUrl("copy_link");
    try {
      await navigator.clipboard.writeText(url);
      showToast(t("common.link_copied"), "success");
    } catch (e) {
      showToast(t("common.copy_failed"), "error");
    }
  };
  const handleNativeShare = async () => {
    const cleanTitle = stripHtml(data.title);
    const cleanSummary = stripHtml(data.summary).substring(0, 100);
    const url = getUtmUrl("nsosyal");
    if (navigator.share) {
      try {
        await navigator.share({
          title: cleanTitle,
          text: `📢 ${cleanTitle}

"${cleanSummary}..."`,
          url
        });
      } catch (e) {
        copyLink();
      }
    } else {
      copyLink();
    }
  };
  const MAX_REACTIONS = 3;
  const emojis = [
    { id: "bravo", emoji: "👏", label: t("reactions.bravo"), count: 3 },
    { id: "dislike", emoji: "👎", label: t("reactions.dislike"), count: 1 },
    { id: "love", emoji: "😍", label: t("reactions.love"), count: 1 },
    { id: "sad", emoji: "🥺", label: t("reactions.sad"), count: 0 },
    { id: "great", emoji: "🙌", label: t("reactions.great"), count: 0 },
    { id: "laugh", emoji: "😂", label: t("reactions.laugh"), count: 0 },
    { id: "angry", emoji: "😡", label: t("reactions.angry"), count: 0 }
  ];
  const toggleEmoji = (id) => {
    if (selectedEmojis.includes(id)) {
      setSelectedEmojis(selectedEmojis.filter((e) => e !== id));
    } else if (selectedEmojis.length < MAX_REACTIONS) {
      setSelectedEmojis([...selectedEmojis, id]);
    }
  };
  const getBreadcrumbs = () => {
    const crumbs = [];
    let currentCategory = data.category;
    const findItem = (val) => navItems.find((item2) => item2.value === val || item2.label === val);
    let item = findItem(currentCategory);
    while (item) {
      crumbs.unshift({ label: item.label, value: item.value });
      if (item.parent_id && item.parent_id !== "root") {
        item = navItems.find((i) => i.id === item?.parent_id);
      } else {
        item = void 0;
      }
    }
    return crumbs;
  };
  const breadcrumbs = getBreadcrumbs();
  useEffect(() => {
    const handleScroll = () => {
      const totalHeight = document.documentElement.scrollHeight - window.innerHeight;
      const progress = window.scrollY / totalHeight * 100;
      setScrollProgress(progress);
    };
    window.addEventListener("scroll", handleScroll);
    return () => window.removeEventListener("scroll", handleScroll);
  }, []);
  const renderMedia = () => {
    const postType = String(data.postType || "").toLowerCase();
    const coverThumbnail = data.coverThumbnail || data.thumbnail;
    if (postType === "article") {
      const coverOptimized = data.optimizedCoverThumbnail || data.optimizedThumbnail;
      const coverSrc = coverOptimized?.src || coverThumbnail;
      return /* @__PURE__ */ jsx("div", { className: "rounded-[5px] overflow-hidden border border-gray-100 shadow-xl mt-4 mb-8", children: /* @__PURE__ */ jsx(
        "img",
        {
          src: coverSrc,
          srcSet: coverOptimized?.srcSet,
          sizes: coverOptimized?.sizes,
          alt: data.thumbnailAlt || data.seoTitle || data.title,
          title: data.thumbnailAlt || data.seoTitle || data.title,
          className: "w-full h-auto object-cover max-h-[600px]"
        }
      ) });
    }
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
      default:
        return /* @__PURE__ */ jsx("div", { className: "rounded-[5px] overflow-hidden border border-gray-100 shadow-xl mt-4 mb-8", children: /* @__PURE__ */ jsx(
          "img",
          {
            src: data.optimizedThumbnail?.src || data.thumbnail,
            srcSet: data.optimizedThumbnail?.srcSet,
            sizes: data.optimizedThumbnail?.sizes,
            alt: data.thumbnailAlt || data.seoTitle || data.title,
            title: data.thumbnailAlt || data.seoTitle || data.title,
            className: "w-full h-auto object-cover max-h-[600px]"
          }
        ) });
    }
  };
  const calculateReadingTime = () => {
    const wordsPerMinute = 200;
    const itemContent = data.items?.map((i) => (i.title || "") + " " + (i.description || "")).join(" ") || "";
    const totalContent = (data.title || "") + " " + (data.summary || "") + " " + (data.content || "") + " " + itemContent;
    const words = totalContent.trim().split(/\s+/).length;
    return Math.max(1, Math.ceil(words / wordsPerMinute));
  };
  const readingTime = calculateReadingTime();
  return /* @__PURE__ */ jsxs("div", { className: "animate-in bg-white rounded-[5px] border border-gray-200 shadow-sm relative min-h-screen mb-10 max-w-full mt-2 overflow-x-clip", children: [
    /* @__PURE__ */ jsx("div", { className: "fixed top-0 left-0 w-full h-1 z-[60] bg-gray-100/50 backdrop-blur-sm", children: /* @__PURE__ */ jsx(
      "div",
      {
        className: "h-full bg-blue-600 transition-all duration-100 shadow-md",
        style: { width: `${scrollProgress}%` }
      }
    ) }),
    /* @__PURE__ */ jsxs("div", { className: "px-6 md:px-10 pt-8 pb-6 border-b border-gray-50 bg-gray-50/30 rounded-t-[5px]", children: [
      /* @__PURE__ */ jsxs("nav", { className: "flex flex-wrap items-center gap-2 text-[10px] font-bold text-gray-400 capitalize tracking-widest mb-6", children: [
        /* @__PURE__ */ jsxs("button", { onClick: onBack, className: "flex items-center gap-1.5 hover:text-blue-600 transition-colors", children: [
          /* @__PURE__ */ jsx(Home, { size: 12 }),
          /* @__PURE__ */ jsx("span", { children: t("nav.home") })
        ] }),
        breadcrumbs.map((crumb, idx) => /* @__PURE__ */ jsxs(React.Fragment, { children: [
          /* @__PURE__ */ jsx(ChevronRight, { size: 10 }),
          /* @__PURE__ */ jsx("span", { className: "hover:text-gray-600 transition-colors cursor-default", children: t(crumb.label).toLowerCase() })
        ] }, idx))
      ] }),
      /* @__PURE__ */ jsxs("div", { className: "w-full mb-10 overflow-hidden max-w-full", children: [
        /* @__PURE__ */ jsx("h1", { className: "text-4xl md:text-5xl lg:text-6xl font-[900] text-gray-900 leading-[1.05] tracking-tighter mb-6", children: data.title }),
        /* @__PURE__ */ jsx(
          "div",
          {
            dangerouslySetInnerHTML: { __html: data.summary },
            className: "rich-text-content text-xl md:text-2xl font-bold text-gray-500 leading-relaxed max-w-full"
          }
        )
      ] }),
      /* @__PURE__ */ jsxs("div", { className: "flex items-center justify-between mt-10 pt-6 border-t border-gray-100", children: [
        /* @__PURE__ */ jsxs("div", { className: "flex items-center gap-4", children: [
          /* @__PURE__ */ jsx("div", { className: "w-12 h-12 rounded-[5px] bg-gray-100 overflow-hidden shadow-sm", children: /* @__PURE__ */ jsx("img", { src: data.sourceAvatar || `https://picsum.photos/seed/auth${data.id}/100`, alt: data.author, className: "w-full h-full object-cover" }) }),
          /* @__PURE__ */ jsxs("div", { children: [
            /* @__PURE__ */ jsxs("div", { className: "flex items-center gap-1.5", children: [
              /* @__PURE__ */ jsx("span", { className: "text-sm font-black text-gray-900", children: data.author }),
              /* @__PURE__ */ jsx(CheckCircle2, { size: 14, className: "text-blue-500" })
            ] }),
            /* @__PURE__ */ jsxs("div", { className: "flex items-center gap-3 text-[10px] text-gray-400 font-bold uppercase tracking-widest mt-0.5", children: [
              /* @__PURE__ */ jsxs("span", { className: "flex items-center gap-1", children: [
                /* @__PURE__ */ jsx(Calendar, { size: 12 }),
                " ",
                data.timestamp
              ] }),
              /* @__PURE__ */ jsxs("span", { className: "flex items-center gap-1", children: [
                /* @__PURE__ */ jsx(Clock, { size: 12 }),
                " ",
                readingTime,
                " ",
                t("news.reading_time")
              ] })
            ] })
          ] })
        ] }),
        /* @__PURE__ */ jsxs("div", { className: "flex items-center gap-2", children: [
          /* @__PURE__ */ jsxs(
            "button",
            {
              onClick: handleNativeShare,
              className: "flex items-center gap-2 px-5 py-2.5 bg-gray-900 text-white rounded-[5px] text-xs font-black transition-all hover:bg-gray-800 shadow-md active:scale-95",
              children: [
                /* @__PURE__ */ jsx(Share2, { size: 14 }),
                /* @__PURE__ */ jsx("span", { children: t("common.share") })
              ]
            }
          ),
          /* @__PURE__ */ jsx("button", { onClick: onBack, className: "p-2.5 bg-white border border-gray-200 text-gray-400 rounded-[5px] hover:text-blue-600 transition-all", children: /* @__PURE__ */ jsx(ArrowLeft, { size: 20 }) })
        ] })
      ] })
    ] }),
    /* @__PURE__ */ jsxs("div", { className: "flex flex-col md:flex-row relative", children: [
      /* @__PURE__ */ jsxs("aside", { className: "hidden md:flex flex-col items-center gap-3 sticky top-24 p-6 border-r border-gray-50 z-10", style: { height: "fit-content", alignSelf: "flex-start" }, children: [
        /* @__PURE__ */ jsxs("div", { className: "flex flex-col items-center mb-2", children: [
          /* @__PURE__ */ jsx("span", { className: "text-[10px] font-black text-gray-400 uppercase tracking-widest [writing-mode:vertical-lr] rotate-180 mb-2", children: t("card.share") }),
          /* @__PURE__ */ jsx("div", { className: "w-px h-8 bg-gray-100 mb-2" }),
          /* @__PURE__ */ jsx("span", { className: "text-xs font-black text-blue-600 mb-2", children: data.shares.toLocaleString() })
        ] }),
        /* @__PURE__ */ jsx(
          "button",
          {
            onClick: shareToTwitter,
            className: "w-10 h-10 flex items-center justify-center rounded-[5px] bg-[#1DA1F2] text-white hover:scale-110 transition-all shadow-sm active:scale-95",
            children: /* @__PURE__ */ jsx(Twitter, { size: 18, className: "fill-current" })
          }
        ),
        /* @__PURE__ */ jsx(
          "button",
          {
            onClick: shareToFacebook,
            className: "w-10 h-10 flex items-center justify-center rounded-[5px] bg-[#4267B2] text-white hover:scale-110 transition-all shadow-sm active:scale-95",
            children: /* @__PURE__ */ jsx(Facebook, { size: 18, className: "fill-current" })
          }
        ),
        /* @__PURE__ */ jsx(
          "button",
          {
            onClick: () => {
              const url = getUtmUrl("linkedin");
              window.open(`https://www.linkedin.com/sharing/share-offsite/?url=${encodeURIComponent(url)}`, "_blank", "noopener,noreferrer");
            },
            className: "w-10 h-10 flex items-center justify-center rounded-[5px] bg-[#0077B5] text-white hover:scale-110 transition-all shadow-sm active:scale-95",
            children: /* @__PURE__ */ jsx(Linkedin, { size: 18, className: "fill-current" })
          }
        ),
        /* @__PURE__ */ jsx(
          "button",
          {
            onClick: copyLink,
            className: "w-10 h-10 flex items-center justify-center rounded-[5px] bg-gray-100 text-gray-500 hover:bg-gray-900 hover:text-white transition-all shadow-sm active:scale-95",
            children: /* @__PURE__ */ jsx(Link, { size: 18 })
          }
        ),
        /* @__PURE__ */ jsx("div", { className: "w-px h-6 bg-gray-100 my-1" }),
        /* @__PURE__ */ jsxs("div", { className: "flex flex-col items-center", children: [
          /* @__PURE__ */ jsx("button", { className: "w-10 h-10 flex items-center justify-center rounded-[5px] bg-rose-50 text-rose-500 hover:bg-rose-500 hover:text-white transition-all shadow-sm group", children: /* @__PURE__ */ jsx(Heart, { size: 18, className: "group-hover:scale-110 transition-transform" }) }),
          /* @__PURE__ */ jsx("span", { className: "text-[10px] font-black text-rose-500 mt-1", children: data.likes.toLocaleString() })
        ] }),
        /* @__PURE__ */ jsx("button", { className: "w-10 h-10 flex items-center justify-center rounded-[5px] bg-gray-50 text-gray-400 hover:bg-blue-500 hover:text-white transition-all shadow-sm border border-gray-100", children: /* @__PURE__ */ jsx(Bookmark, { size: 18 }) })
      ] }),
      /* @__PURE__ */ jsxs("article", { className: "flex-1 min-w-0 px-6 md:px-12 pt-6 pb-8 max-w-full md:mx-0 break-words overflow-hidden", children: [
        /* @__PURE__ */ jsx("div", { className: "mb-10 overflow-hidden max-w-full", children: renderMedia() }),
        /* @__PURE__ */ jsx("div", { className: "space-y-12 overflow-hidden", children: data.items && data.items.length > 0 ? data.items.map((item, index) => {
          const isLastItem = index === (data.items?.length || 0) - 1;
          switch (item.type) {
            case "text":
              return /* @__PURE__ */ jsxs("div", { className: "rich-text-content prose prose-lg max-w-full text-gray-800", children: [
                item.title && /* @__PURE__ */ jsx("h3", { className: "text-2xl font-black text-gray-900 mb-4", children: item.title }),
                /* @__PURE__ */ jsx("div", { dangerouslySetInnerHTML: { __html: item.description || "" }, className: "leading-[1.85] font-medium text-gray-700" }),
                item.source && /* @__PURE__ */ jsxs("p", { className: "text-xs text-gray-400 mt-2 italic flex items-center gap-1", children: [
                  /* @__PURE__ */ jsx(Link, { size: 12 }),
                  " ",
                  t("news.source_prefix"),
                  " ",
                  item.source
                ] })
              ] }, item.id);
            case "image":
              return /* @__PURE__ */ jsxs("div", { className: "space-y-4 max-w-full overflow-hidden", children: [
                item.title && /* @__PURE__ */ jsx("h3", { className: "text-2xl font-black text-gray-900 break-normal", children: item.title }),
                /* @__PURE__ */ jsxs("div", { className: "relative w-full bg-gray-50 rounded-[5px] overflow-hidden border border-gray-100 shadow-lg flex items-center justify-center max-h-[600px]", children: [
                  /* @__PURE__ */ jsx(
                    "div",
                    {
                      className: "absolute inset-0 bg-center bg-no-repeat bg-cover blur-2xl opacity-10 scale-110",
                      style: { backgroundImage: `url(${item.mediaUrl})` }
                    }
                  ),
                  /* @__PURE__ */ jsx(
                    "img",
                    {
                      src: item.mediaUrl,
                      alt: item.altText || item.title || t("news.image_alt_default"),
                      className: "relative z-10 w-full h-auto max-h-[600px] object-contain"
                    }
                  )
                ] }),
                item.description && /* @__PURE__ */ jsx(
                  "div",
                  {
                    dangerouslySetInnerHTML: { __html: item.description },
                    className: "rich-text-content text-sm text-gray-500 font-medium italic text-left px-0 leading-relaxed"
                  }
                )
              ] }, item.id);
            case "paragraph":
            case "quote":
              return /* @__PURE__ */ jsx("div", { className: "py-4", children: /* @__PURE__ */ jsx(
                ParagraphCard,
                {
                  data: {
                    ...data,
                    summary: "",
                    // Ana özetle karışmasın
                    paragraphData: {
                      items: item.description ? [item.description] : item.paragraphData?.items || [],
                      quoteAuthor: item.title || item.paragraphData?.quoteAuthor
                    }
                  }
                }
              ) }, item.id);
            case "slider":
              return /* @__PURE__ */ jsxs("div", { className: "space-y-4", children: [
                item.title && /* @__PURE__ */ jsx("h3", { className: "text-2xl font-black text-gray-900", children: item.title }),
                /* @__PURE__ */ jsx(GalleryCard, { data: { ...data, mediaList: item.mediaUrls } })
              ] }, item.id);
            case "poll":
              return /* @__PURE__ */ jsxs("div", { className: "space-y-6 pt-12 border-t-2 border-palette-beige/30 mt-16 relative", children: [
                isLastItem && /* @__PURE__ */ jsxs("div", { className: "absolute -top-4 left-1/2 -translate-x-1/2 bg-white px-4 py-1 flex items-center gap-2", children: [
                  /* @__PURE__ */ jsx("div", { className: "w-2 h-2 rounded-full bg-palette-red" }),
                  /* @__PURE__ */ jsx("span", { className: "text-[10px] font-black uppercase tracking-[0.3em] text-palette-tan", children: t("news.end") }),
                  /* @__PURE__ */ jsx("div", { className: "w-2 h-2 rounded-full bg-palette-red" })
                ] }),
                item.title && /* @__PURE__ */ jsxs("h3", { className: "text-3xl md:text-4xl font-[1000] text-gray-900 leading-tight tracking-tighter", children: [
                  item.title,
                  !item.title.trim().endsWith("?") && !item.title.trim().endsWith("!") ? "?" : ""
                ] }),
                /* @__PURE__ */ jsx(PollCard, { data: { ...data, title: item.title, summary: item.description, options: item.options, isImagePoll: item.isImagePoll, pollColumns: item.pollColumns } })
              ] }, item.id);
            case "vs":
              return /* @__PURE__ */ jsxs("div", { className: "space-y-4", children: [
                item.title && /* @__PURE__ */ jsx("h3", { className: "text-2xl font-black text-gray-900", children: item.title }),
                /* @__PURE__ */ jsx(VSCard, { data: { ...data, title: item.title, options: item.options } })
              ] }, item.id);
            case "beforeafter":
              return /* @__PURE__ */ jsxs("div", { className: "space-y-4", children: [
                item.title && /* @__PURE__ */ jsx("h3", { className: "text-2xl font-black text-gray-900", children: item.title }),
                /* @__PURE__ */ jsx(BeforeAfterCard, { data: { ...data, beforeAfterData: item.beforeAfterData } })
              ] }, item.id);
            case "flipcard":
              return /* @__PURE__ */ jsxs("div", { className: "space-y-4", children: [
                item.title && /* @__PURE__ */ jsx("h3", { className: "text-2xl font-black text-gray-900", children: item.title }),
                /* @__PURE__ */ jsx(FlipCard, { data: { ...data, flipData: item.flipData } })
              ] }, item.id);
            case "review":
              return /* @__PURE__ */ jsxs("div", { className: "space-y-4", children: [
                item.title && /* @__PURE__ */ jsx("h3", { className: "text-2xl font-black text-gray-900", children: item.title }),
                /* @__PURE__ */ jsx(ReviewCard, { data: { ...data, reviewData: item.reviewData } })
              ] }, item.id);
            case "video":
              return /* @__PURE__ */ jsxs("div", { className: "space-y-4", children: [
                item.title && /* @__PURE__ */ jsx("h3", { className: "text-2xl font-black text-gray-900", children: item.title }),
                /* @__PURE__ */ jsx(VideoCard, { data: { ...data, mediaUrl: item.mediaUrl } })
              ] }, item.id);
            case "audio":
              return /* @__PURE__ */ jsxs("div", { className: "space-y-4", children: [
                item.title && /* @__PURE__ */ jsx("h3", { className: "text-2xl font-black text-gray-900", children: item.title }),
                /* @__PURE__ */ jsx(AudioCard, { data: { ...data, mediaUrl: item.mediaUrl } })
              ] }, item.id);
            case "social":
            case "iframe":
              return /* @__PURE__ */ jsxs("div", { className: "space-y-4", children: [
                item.title && /* @__PURE__ */ jsx("h3", { className: "text-2xl font-black text-gray-900", children: item.title }),
                /* @__PURE__ */ jsx(EmbedCard, { data: { ...data, mediaUrl: item.mediaUrl } })
              ] }, item.id);
            default:
              return null;
          }
        }) : /* @__PURE__ */ jsx(
          "div",
          {
            className: "rich-text-content prose prose-lg max-w-full text-gray-800",
            dangerouslySetInnerHTML: { __html: data.content || t("news.content_not_found") }
          }
        ) }),
        data.faqData && data.faqData.length > 0 && /* @__PURE__ */ jsxs("div", { className: "mt-16 pt-10 border-t border-gray-100 space-y-8", children: [
          /* @__PURE__ */ jsxs("div", { className: "flex items-center gap-3", children: [
            /* @__PURE__ */ jsx("div", { className: "w-10 h-10 bg-blue-50 rounded-[5px] flex items-center justify-center text-blue-600", children: /* @__PURE__ */ jsx(CheckCircle2, { size: 24 }) }),
            /* @__PURE__ */ jsx("h3", { className: "text-2xl font-black text-gray-900 uppercase tracking-tighter", children: t("news.faq_title") })
          ] }),
          /* @__PURE__ */ jsx("div", { className: "grid gap-4", children: data.faqData.map((faq, idx) => /* @__PURE__ */ jsx("div", { className: "bg-gray-50/50 rounded-[10px] border border-gray-100/50 p-6 transition-all hover:bg-white hover:shadow-xl hover:shadow-blue-500/5 group", children: /* @__PURE__ */ jsxs("div", { className: "flex gap-4", children: [
            /* @__PURE__ */ jsx("div", { className: "shrink-0 w-8 h-8 rounded-full bg-blue-600 text-white flex items-center justify-center text-xs font-black shadow-lg shadow-blue-500/20 group-hover:scale-110 transition-transform", children: "?" }),
            /* @__PURE__ */ jsxs("div", { className: "space-y-3", children: [
              /* @__PURE__ */ jsx("h4", { className: "text-lg font-black text-gray-900 leading-tight", children: faq.q }),
              /* @__PURE__ */ jsx("p", { className: "text-gray-600 leading-relaxed font-medium", children: faq.a })
            ] })
          ] }) }, idx)) })
        ] }),
        data.keywords && /* @__PURE__ */ jsx("div", { className: "flex flex-wrap gap-2 mt-12 pb-6 border-b border-gray-50", children: data.keywords.split(",").map((tag, idx) => /* @__PURE__ */ jsxs(
          "button",
          {
            className: "px-4 py-2 bg-gray-100 text-gray-500 text-[10px] font-black uppercase tracking-widest rounded-[5px] hover:bg-gray-200 transition-all",
            children: [
              "#",
              tag.trim()
            ]
          },
          idx
        )) }),
        /* @__PURE__ */ jsxs("div", { className: "mt-10 pt-8 border-t-2 border-palette-beige/50", children: [
          /* @__PURE__ */ jsxs("div", { className: "flex items-center justify-center gap-3 mb-6", children: [
            /* @__PURE__ */ jsx("div", { className: "h-px flex-1 bg-gradient-to-r from-transparent via-palette-beige to-transparent" }),
            /* @__PURE__ */ jsxs("div", { className: "flex items-center gap-2 px-4 py-2 bg-palette-beige/30 rounded-full border border-palette-beige", children: [
              /* @__PURE__ */ jsx("svg", { className: "w-4 h-4 text-palette-tan", viewBox: "0 0 24 24", fill: "currentColor", children: /* @__PURE__ */ jsx("path", { d: "M12 2C6.48 2 2 6.48 2 12s4.48 10 10 10 10-4.48 10-10S17.52 2 12 2zm0 18c-4.41 0-8-3.59-8-8s3.59-8 8-8 8 3.59 8 8-3.59 8-8 8zm3.5-9c.83 0 1.5-.67 1.5-1.5S16.33 8 15.5 8 14 8.67 14 9.5s.67 1.5 1.5 1.5zm-7 0c.83 0 1.5-.67 1.5-1.5S9.33 8 8.5 8 7 8.67 7 9.5 7.67 11 8.5 11zm3.5 6.5c2.33 0 4.31-1.46 5.11-3.5H6.89c.8 2.04 2.78 3.5 5.11 3.5z" }) }),
              /* @__PURE__ */ jsx("span", { className: "text-[11px] font-bold text-palette-tan uppercase tracking-widest", children: t("news.react_title") })
            ] }),
            /* @__PURE__ */ jsx("div", { className: "h-px flex-1 bg-gradient-to-r from-transparent via-palette-beige to-transparent" })
          ] }),
          /* @__PURE__ */ jsx("div", { className: "flex items-center justify-center gap-2 md:gap-4 flex-nowrap overflow-visible pt-2 pb-2", children: emojis.map((item) => {
            const isSelected = selectedEmojis.includes(item.id);
            const isDisabled = !isSelected && selectedEmojis.length >= MAX_REACTIONS;
            return /* @__PURE__ */ jsxs(
              "button",
              {
                onClick: () => toggleEmoji(item.id),
                disabled: isDisabled,
                className: `group relative flex flex-col items-center gap-1.5 p-3 rounded-xl transition-all duration-300 flex-shrink-0
                      ${isSelected ? "bg-emerald-50 border-2 border-emerald-400 shadow-lg shadow-emerald-500/20 -translate-y-1" : "bg-white border-2 border-transparent hover:border-palette-beige hover:bg-palette-beige/20 hover:-translate-y-1 hover:shadow-lg"}
                      ${isDisabled ? "opacity-40 cursor-not-allowed hover:translate-y-0 hover:shadow-none" : "cursor-pointer"}
                    `,
                children: [
                  isSelected && /* @__PURE__ */ jsx("div", { className: "absolute -top-1 -right-1 w-5 h-5 bg-emerald-500 rounded-full flex items-center justify-center shadow-md", children: /* @__PURE__ */ jsx("svg", { className: "w-3 h-3 text-white", fill: "none", viewBox: "0 0 24 24", stroke: "currentColor", strokeWidth: 3, children: /* @__PURE__ */ jsx("path", { strokeLinecap: "round", strokeLinejoin: "round", d: "M5 13l4 4L19 7" }) }) }),
                  /* @__PURE__ */ jsx("span", { className: `text-3xl md:text-4xl transition-transform duration-300 select-none ${isSelected ? "scale-110" : "group-hover:scale-110"}`, children: item.emoji }),
                  /* @__PURE__ */ jsx("span", { className: `text-[9px] font-bold uppercase tracking-wider transition-colors ${isSelected ? "text-emerald-600" : "text-palette-tan/40 group-hover:text-palette-tan"}`, children: item.label }),
                  /* @__PURE__ */ jsx("span", { className: `text-sm font-black transition-colors ${isSelected ? "text-emerald-600" : "text-palette-tan"}`, children: isSelected ? item.count + 1 : item.count })
                ]
              },
              item.id
            );
          }) }),
          /* @__PURE__ */ jsx("p", { className: `text-center text-xs font-medium mt-4 transition-colors ${selectedEmojis.length >= MAX_REACTIONS ? "text-palette-red" : "text-palette-tan/40"}`, children: selectedEmojis.length >= MAX_REACTIONS ? t("reactions.max_reactions").replace("{max}", String(MAX_REACTIONS)) : t("reactions.remaining").replace("{remaining}", String(MAX_REACTIONS - selectedEmojis.length)) })
        ] }),
        /* @__PURE__ */ jsxs("div", { className: "mt-10 pt-8 border-t border-gray-100", children: [
          /* @__PURE__ */ jsxs("div", { className: "flex items-center gap-3 mb-6", children: [
            /* @__PURE__ */ jsx("div", { className: "w-1 h-8 bg-palette-red rounded-full" }),
            /* @__PURE__ */ jsx("h3", { className: "text-xl font-black text-gray-900 tracking-tight", children: t("news.share_thoughts") }),
            /* @__PURE__ */ jsxs("span", { className: "text-xs font-bold text-gray-400 bg-gray-100 px-2.5 py-1 rounded-full", children: [
              data.comments,
              " ",
              t("card.comments")
            ] })
          ] }),
          /* @__PURE__ */ jsx(CommentSection, { postId: data.id, publisherId: data.publisherId })
        ] })
      ] })
    ] }),
    /* @__PURE__ */ jsx(
      "button",
      {
        onClick: () => window.scrollTo({ top: 0, behavior: "smooth" }),
        className: `fixed bottom-8 right-8 p-4 bg-white border border-gray-200 rounded-[5px] shadow-xl text-gray-400 hover:text-blue-600 transition-all z-50 ${scrollProgress > 20 ? "translate-y-0 opacity-100" : "translate-y-10 opacity-0 pointer-events-none"}`,
        children: /* @__PURE__ */ jsx(ChevronRight, { size: 20, className: "-rotate-90" })
      }
    )
  ] });
};

const NewsDetailPage = ({
  initialLang,
  initialTranslations,
  siteSettings,
  navigationItems,
  newsItem,
  newsItems
}) => {
  return /* @__PURE__ */ jsx(LanguageProvider, { initialLang, initialTranslations, children: /* @__PURE__ */ jsx(ToastProvider, { children: /* @__PURE__ */ jsx("div", { className: "min-h-screen bg-palette-white", children: /* @__PURE__ */ jsxs("main", { className: "max-w-[1280px] pt-[84px] gap-8 px-4 mx-auto flex justify-center items-start", children: [
    /* @__PURE__ */ jsx("section", { className: "flex-1 min-w-0 pb-10 flex justify-center w-full", children: /* @__PURE__ */ jsx("div", { className: "w-full max-w-[840px]", children: /* @__PURE__ */ jsx(
      NewsDetail,
      {
        data: newsItem,
        navItems: navigationItems,
        onBack: () => window.history.back(),
        loading: !newsItem
      }
    ) }) }),
    /* @__PURE__ */ jsx("aside", { className: "hidden xl:block w-[320px] flex-shrink-0 pb-8 sticky top-[72px]", children: /* @__PURE__ */ jsx(RightSidebar, { newsData: newsItems, loading: newsItems.length === 0 }) })
  ] }) }) }) });
};

const $$Astro = createAstro();
const prerender = false;
const $$slug = createComponent(async ($$result, $$props, $$slots) => {
  const Astro2 = $$result.createAstro($$Astro, $$props, $$slots);
  Astro2.self = $$slug;
  const { slug } = Astro2.params;
  const cookies = Astro2.request.headers.get("cookie") || "";
  const cookieLang = cookies.match(/pateez_lang=([^;]+)/)?.[1];
  cookies.match(/pateez_active_cat=([^;]+)/)?.[1];
  const acceptLanguageHeader = Astro2.request.headers.get("accept-language");
  const urlLang = Astro2.url.searchParams.get("lang");
  const seoAlternates = await dataService.getSeoAlternates();
  const defaultLangCode = seoAlternates.find((entry) => entry.isDefault)?.code || "tr";
  const lang = resolveLangCode({
    urlLang,
    cookieLang,
    acceptLanguageHeader,
    supported: seoAlternates.map((entry) => ({ code: entry.code, isDefault: entry.isDefault })),
    fallback: defaultLangCode
  });
  const langMeta = seoAlternates.find((entry) => entry.code === lang);
  const [initialTranslations, siteSettings, navigationItems, newsItem, newsItems] = await Promise.all([
    loadLocaleData(lang),
    dataService.getSiteSettings(lang),
    dataService.getNavigationItems(lang),
    dataService.getNewsBySlug(slug),
    dataService.getNewsItems(lang)
  ]);
  const initialLang = {
    code: lang,
    name: langMeta?.name || lang.toUpperCase(),
    direction: langMeta?.direction || "ltr",
    status: "active",
    flag_code: langMeta?.flagCode || lang,
    is_default: langMeta?.isDefault || lang === defaultLangCode
  };
  if (!newsItem) {
    return Astro2.redirect("/404");
  }
  const THUMB_WIDTHS = [320, 480, 640, 840, 1280];
  const COVER_WIDTHS = [640, 960, 1280, 1600];
  const IMAGE_SIZES = "(max-width: 840px) 100vw, 840px";
  const buildOptimizedImage = async (src, widths) => {
    const raw = String(src || "").trim();
    if (!raw || raw.startsWith("data:")) return null;
    try {
      const result = await getImage({ src: raw, widths, format: "webp", quality: "mid" });
      return { src: result.src, srcSet: result.srcSet.attribute, sizes: IMAGE_SIZES };
    } catch {
      return null;
    }
  };
  const resolvedThumbnailSrc = String(newsItem.thumbnail || "").trim();
  const resolvedCoverSrc = String(newsItem?.coverThumbnail || resolvedThumbnailSrc).trim();
  const optimizedThumbnail = resolvedThumbnailSrc ? await buildOptimizedImage(resolvedThumbnailSrc, THUMB_WIDTHS) : null;
  const optimizedCoverThumbnail = resolvedCoverSrc ? resolvedCoverSrc === resolvedThumbnailSrc ? optimizedThumbnail : await buildOptimizedImage(resolvedCoverSrc, COVER_WIDTHS) : null;
  const newsItemWithOptimized = {
    ...newsItem,
    optimizedThumbnail: optimizedThumbnail || void 0,
    optimizedCoverThumbnail: optimizedCoverThumbnail || void 0
  };
  const title = newsItem.seoTitle || `${newsItem.title} | ${siteSettings?.site_name || "Pateez"}`;
  const description = newsItem.seoDescription || newsItem.summary;
  const ogImage = newsItem.thumbnail || newsItem.mediaUrl || siteSettings?.og_image_url || "";
  const canonicalBase = (siteSettings?.canonical_url || Astro2.url.origin).trim();
  const canonicalPathSegment = encodeURIComponent(newsItem.slug || slug || newsItem.id);
  const canonicalUrl = new URL(`/haber/${canonicalPathSegment}`, canonicalBase).toString();
  const toAbsoluteUrl = (value) => {
    const raw = String(value || "").trim();
    if (!raw) return "";
    if (raw.startsWith("http://") || raw.startsWith("https://") || raw.startsWith("data:")) return raw;
    try {
      return new URL(raw, canonicalBase).toString();
    } catch {
      return raw;
    }
  };
  const stripHtml = (html) => (html || "").replace(/<[^>]*>?/gm, "").replace(/&nbsp;/g, " ").trim();
  const toIso = (value) => {
    const raw = String(value || "").trim();
    if (!raw) return void 0;
    const d = new Date(raw);
    if (Number.isNaN(d.getTime())) return void 0;
    return d.toISOString();
  };
  const orgName = (siteSettings?.organization_legal_name || siteSettings?.site_name || "Pateez").trim();
  const orgLogo = toAbsoluteUrl(siteSettings?.logo_url || siteSettings?.favicon_url);
  const articleLd = {
    "@context": "https://schema.org",
    "@type": newsItem.schemaType || "NewsArticle",
    mainEntityOfPage: {
      "@type": "WebPage",
      "@id": canonicalUrl
    },
    headline: stripHtml(newsItem.seoTitle || newsItem.title),
    description: stripHtml(newsItem.seoDescription || newsItem.summary),
    ...toAbsoluteUrl(ogImage) ? { image: [toAbsoluteUrl(ogImage)] } : {},
    ...toIso(newsItem.timestamp) ? { datePublished: toIso(newsItem.timestamp) } : {},
    ...newsItem.category ? { articleSection: stripHtml(newsItem.category) } : {},
    ...newsItem.keywords ? { keywords: stripHtml(newsItem.keywords) } : {},
    author: {
      "@type": "Person",
      name: stripHtml(newsItem.author || newsItem.source || orgName)
    },
    publisher: {
      "@type": "Organization",
      name: orgName,
      ...orgLogo ? { logo: { "@type": "ImageObject", url: orgLogo } } : {}
    },
    ...newsItem.factChecked ? {
      reviewedBy: {
        "@type": "Organization",
        name: orgName
      }
    } : {},
    inLanguage: lang,
    isAccessibleForFree: true
  };
  const categoryLabel = String(newsItem.category || "").trim();
  const categorySlug = categoryLabel ? slugify(categoryLabel) : "";
  const breadcrumbItems = [
    {
      "@type": "ListItem",
      position: 1,
      name: siteSettings?.site_name || orgName || "Home",
      item: new URL("/", canonicalBase).toString()
    },
    ...categorySlug ? [{
      "@type": "ListItem",
      position: 2,
      name: stripHtml(categoryLabel),
      item: new URL(`/kategori/${encodeURIComponent(categorySlug)}`, canonicalBase).toString()
    }] : [],
    {
      "@type": "ListItem",
      position: categorySlug ? 3 : 2,
      name: stripHtml(newsItem.seoTitle || newsItem.title),
      item: canonicalUrl
    }
  ];
  const breadcrumbLd = {
    "@context": "https://schema.org",
    "@type": "BreadcrumbList",
    itemListElement: breadcrumbItems
  };
  const faqItems = Array.isArray(newsItem.faqData) ? newsItem.faqData.filter((f) => f?.q && f?.a) : [];
  const faqLd = faqItems.length > 0 ? {
    "@context": "https://schema.org",
    "@type": "FAQPage",
    mainEntity: faqItems.map((f) => ({
      "@type": "Question",
      name: stripHtml(String(f.q)),
      acceptedAnswer: {
        "@type": "Answer",
        text: stripHtml(String(f.a))
      }
    }))
  } : null;
  return renderTemplate`${renderComponent($$result, "Layout", $$Layout, { "title": title, "description": description, "keywords": newsItem.keywords, "ogType": "article", "ogImage": ogImage, "canonical": canonicalUrl, "jsonLd": faqLd ? [articleLd, breadcrumbLd, faqLd] : [articleLd, breadcrumbLd], "favicon": siteSettings?.favicon_url, "lang": lang, "dir": initialLang.direction, "siteSettings": siteSettings, "navigationItems": navigationItems, "initialTranslations": initialTranslations, "initialLang": initialLang }, { "default": async ($$result2) => renderTemplate` ${renderComponent($$result2, "NewsDetailPage", NewsDetailPage, { "client:idle": true, "initialLang": initialLang, "initialTranslations": initialTranslations, "siteSettings": siteSettings, "navigationItems": navigationItems, "newsItem": newsItemWithOptimized, "newsItems": newsItems, "client:component-hydration": "idle", "client:component-path": "@/components/NewsDetailPage", "client:component-export": "default" })} ` })}`;
}, "/Users/pateez/Desktop/pateeznews/src/pages/haber/[slug].astro", void 0);

const $$file = "/Users/pateez/Desktop/pateeznews/src/pages/haber/[slug].astro";
const $$url = "/haber/[slug]";

const _page = /*#__PURE__*/Object.freeze(/*#__PURE__*/Object.defineProperty({
  __proto__: null,
  default: $$slug,
  file: $$file,
  prerender,
  url: $$url
}, Symbol.toStringTag, { value: 'Module' }));

const page = () => _page;

export { page };
