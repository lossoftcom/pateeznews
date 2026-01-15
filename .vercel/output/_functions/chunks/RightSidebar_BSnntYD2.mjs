import { jsx, jsxs, Fragment } from 'react/jsx-runtime';
import React, { useState, useEffect, useRef } from 'react';
import { Check, X, BarChart3, Award, ArrowLeftRight, RotateCw, ExternalLink, Twitter, Facebook, Instagram, Headphones, Rewind, Pause, Play, FastForward, VolumeX, Volume1, Volume2, Clock, ChevronLeft, ChevronRight, CheckCircle2, Users, Swords, Zap, Quote, ChevronUp, ChevronDown, Reply, Smile, Send, Trash2, ShieldAlert, Flag, UserMinus, Heart, DollarSign, Euro, Coins, Bitcoin, CloudSun, Sun, CloudRain, Cloud, MapPin, TrendingUp, ArrowUpRight, ArrowDownRight, UserPlus, Mail } from 'lucide-react';
import { u as useLanguage, a as useToast } from './Layout_DohV3HSJ.mjs';
import { f as formatTime } from './helpers_xme2WEyl.mjs';
import { s as supabase } from './dataService_CXfGU90R.mjs';
import Picker, { Theme } from 'emoji-picker-react';

const Skeleton = ({ className = "", variant = "rectangular" }) => {
  const baseClasses = "animate-pulse bg-palette-beige/20";
  const variantClasses = variant === "circular" ? "rounded-full" : "rounded-[5px]";
  return /* @__PURE__ */ jsx("div", { className: `${baseClasses} ${variantClasses} ${className}` });
};

const AnimatedNumber = ({ value, suffix = "%", prefix = "" }) => {
  const [displayValue, setDisplayValue] = useState(0);
  useEffect(() => {
    let start = 0;
    const duration = 1e3;
    const increment = value / (duration / 16);
    const timer = setInterval(() => {
      start += increment;
      if (start >= value) {
        setDisplayValue(value);
        clearInterval(timer);
      } else {
        setDisplayValue(Math.floor(start));
      }
    }, 16);
    return () => clearInterval(timer);
  }, [value]);
  return /* @__PURE__ */ jsxs("span", { children: [
    prefix,
    displayValue.toLocaleString(),
    suffix
  ] });
};

const ReviewCard = ({ data }) => {
  const { t } = useLanguage();
  if (!data.reviewData) return null;
  const { productName, productImage, score, pros, cons, breakdown, verdict } = data.reviewData;
  const [imageRatio, setImageRatio] = useState("horizontal");
  useEffect(() => {
    const url = productImage || data.optimizedThumbnail?.src || data.thumbnail;
    if (url) {
      const img = new Image();
      img.onload = () => {
        if (img.height > img.width) {
          setImageRatio("vertical");
        } else {
          setImageRatio("horizontal");
        }
      };
      img.src = url;
    }
  }, [productImage, data.thumbnail, data.optimizedThumbnail?.src]);
  let scoreColor = "text-emerald-500";
  let scoreBg = "bg-emerald-50";
  let scoreBorder = "border-emerald-200";
  if (score < 50) {
    scoreColor = "text-rose-500";
    scoreBg = "bg-rose-50";
    scoreBorder = "border-rose-200";
  } else if (score < 80) {
    scoreColor = "text-amber-500";
    scoreBg = "bg-amber-50";
    scoreBorder = "border-amber-200";
  }
  return /* @__PURE__ */ jsxs("div", { className: "mt-1 space-y-3 overflow-hidden", children: [
    /* @__PURE__ */ jsx("div", { className: "px-1 mb-3", children: /* @__PURE__ */ jsx(
      "div",
      {
        className: "rich-text-content text-gray-600/80 text-[16px] leading-relaxed font-medium text-left [&>p]:mb-0",
        dangerouslySetInnerHTML: { __html: data.summary }
      }
    ) }),
    /* @__PURE__ */ jsxs("div", { className: "bg-white rounded-[5px] border border-gray-200 overflow-hidden shadow-sm", children: [
      /* @__PURE__ */ jsxs("div", { className: `relative w-full bg-gray-900 group overflow-hidden flex items-center justify-center transition-all duration-700 ${imageRatio === "vertical" ? "h-[400px]" : "h-auto min-h-[240px]"}`, children: [
        imageRatio === "vertical" && /* @__PURE__ */ jsx(
          "div",
          {
            className: "absolute inset-0 bg-center bg-no-repeat bg-cover blur-2xl opacity-20 scale-110",
            style: { backgroundImage: `url(${productImage || data.optimizedThumbnail?.src || data.thumbnail})` }
          }
        ),
        /* @__PURE__ */ jsx(
          "img",
          {
            src: productImage || data.optimizedThumbnail?.src || data.thumbnail,
            srcSet: !productImage ? data.optimizedThumbnail?.srcSet : void 0,
            sizes: !productImage ? data.optimizedThumbnail?.sizes : void 0,
            alt: productName,
            className: `relative z-10 transition-transform duration-1000 group-hover:scale-105 mx-auto ${imageRatio === "vertical" ? "h-full w-auto object-contain" : "w-full h-auto block"}`,
            onError: (e) => {
              const target = e.target;
              if (data.thumbnail && target.src !== data.thumbnail) {
                target.src = data.thumbnail;
              }
            }
          }
        ),
        /* @__PURE__ */ jsx("div", { className: "absolute inset-0 z-20 bg-gradient-to-t from-black via-transparent to-transparent opacity-90" }),
        /* @__PURE__ */ jsx("div", { className: "absolute bottom-0 left-0 w-full p-6 text-white z-30", children: /* @__PURE__ */ jsxs("div", { className: "flex items-center justify-between", children: [
          /* @__PURE__ */ jsxs("div", { children: [
            /* @__PURE__ */ jsx("span", { className: "inline-block px-3 py-1 bg-blue-600 text-white text-[10px] font-black uppercase tracking-widest rounded-[5px] mb-2", children: t("review.badge") }),
            /* @__PURE__ */ jsx("h3", { className: "text-3xl font-black leading-none tracking-tight", children: productName })
          ] }),
          /* @__PURE__ */ jsxs("div", { className: `w-20 h-20 rounded-[5px] ${scoreBg} ${scoreBorder} border-4 flex flex-col items-center justify-center shadow-[0_0_20px_rgba(0,0,0,0.3)] backdrop-blur-md transform rotate-3`, children: [
            /* @__PURE__ */ jsx("span", { className: `text-2xl font-black ${scoreColor} leading-none`, children: /* @__PURE__ */ jsx(AnimatedNumber, { value: score, suffix: "" }) }),
            /* @__PURE__ */ jsx("span", { className: "text-[10px] font-bold text-gray-500 uppercase tracking-wider", children: t("review.score_label") })
          ] })
        ] }) })
      ] }),
      /* @__PURE__ */ jsxs("div", { className: "p-6", children: [
        /* @__PURE__ */ jsxs("div", { className: "grid grid-cols-1 md:grid-cols-2 gap-6 mb-8", children: [
          /* @__PURE__ */ jsxs("div", { className: "bg-emerald-50/50 rounded-[5px] p-5 border border-emerald-100", children: [
            /* @__PURE__ */ jsxs("div", { className: "flex items-center gap-2 mb-4", children: [
              /* @__PURE__ */ jsx("div", { className: "bg-emerald-500 p-1 rounded-[5px] text-white", children: /* @__PURE__ */ jsx(Check, { size: 14, strokeWidth: 4 }) }),
              /* @__PURE__ */ jsx("h4", { className: "text-emerald-900 font-extrabold text-sm uppercase tracking-wide", children: t("review.pros") })
            ] }),
            /* @__PURE__ */ jsx("ul", { className: "space-y-3", children: pros.map((pro, idx) => /* @__PURE__ */ jsxs("li", { className: "flex items-start gap-2.5", children: [
              /* @__PURE__ */ jsx(Check, { size: 16, className: "text-emerald-600 mt-0.5 flex-shrink-0" }),
              /* @__PURE__ */ jsx("span", { className: "text-emerald-900 text-xs font-bold leading-relaxed", children: pro })
            ] }, idx)) })
          ] }),
          /* @__PURE__ */ jsxs("div", { className: "bg-rose-50/50 rounded-[5px] p-5 border border-rose-100", children: [
            /* @__PURE__ */ jsxs("div", { className: "flex items-center gap-2 mb-4", children: [
              /* @__PURE__ */ jsx("div", { className: "bg-rose-500 p-1 rounded-[5px] text-white", children: /* @__PURE__ */ jsx(X, { size: 14, strokeWidth: 4 }) }),
              /* @__PURE__ */ jsx("h4", { className: "text-rose-900 font-extrabold text-sm uppercase tracking-wide", children: t("review.cons") })
            ] }),
            /* @__PURE__ */ jsx("ul", { className: "space-y-3", children: cons.map((con, idx) => /* @__PURE__ */ jsxs("li", { className: "flex items-start gap-2.5", children: [
              /* @__PURE__ */ jsx(X, { size: 16, className: "text-rose-600 mt-0.5 flex-shrink-0" }),
              /* @__PURE__ */ jsx("span", { className: "text-rose-900 text-xs font-bold leading-relaxed", children: con })
            ] }, idx)) })
          ] })
        ] }),
        /* @__PURE__ */ jsxs("div", { className: "space-y-4 mb-8", children: [
          /* @__PURE__ */ jsxs("h4", { className: "font-extrabold text-gray-900 text-sm uppercase tracking-wide flex items-center gap-2", children: [
            /* @__PURE__ */ jsx(BarChart3, { size: 16, className: "text-blue-500" }),
            " ",
            t("review.detailed_scoring")
          ] }),
          /* @__PURE__ */ jsx("div", { className: "space-y-3", children: breakdown.map((item, idx) => /* @__PURE__ */ jsxs("div", { className: "flex flex-col gap-1", children: [
            /* @__PURE__ */ jsxs("div", { className: "flex justify-between text-xs font-bold", children: [
              /* @__PURE__ */ jsx("span", { className: "text-gray-600", children: item.label }),
              /* @__PURE__ */ jsxs("span", { className: "text-gray-900", children: [
                item.score,
                "/100"
              ] })
            ] }),
            /* @__PURE__ */ jsx("div", { className: "w-full h-2 bg-gray-100 rounded-[5px] overflow-hidden", children: /* @__PURE__ */ jsx(
              "div",
              {
                className: `h-full rounded-[5px] transition-all duration-1000 ease-out ${item.score >= 90 ? "bg-emerald-500" : item.score >= 70 ? "bg-blue-500" : "bg-amber-500"}`,
                style: { width: `${item.score}%` }
              }
            ) })
          ] }, idx)) })
        ] }),
        /* @__PURE__ */ jsxs("div", { className: "bg-gray-900 text-white rounded-[5px] p-6 relative overflow-hidden", children: [
          /* @__PURE__ */ jsx("div", { className: "absolute top-0 right-0 w-32 h-32 bg-blue-500 rounded-[5px] blur-[60px] opacity-20" }),
          /* @__PURE__ */ jsxs("div", { className: "relative z-10", children: [
            /* @__PURE__ */ jsxs("div", { className: "flex items-center gap-2 mb-3 text-blue-300", children: [
              /* @__PURE__ */ jsx(Award, { size: 20 }),
              /* @__PURE__ */ jsx("span", { className: "text-xs font-black uppercase tracking-widest", children: t("review.verdict_label") })
            ] }),
            /* @__PURE__ */ jsx(
              "div",
              {
                className: "rich-text-content text-sm leading-relaxed font-medium text-gray-300 italic [&>p]:mb-0",
                dangerouslySetInnerHTML: { __html: verdict }
              }
            )
          ] })
        ] })
      ] })
    ] })
  ] });
};

const BeforeAfterCard = ({ data }) => {
  const [sliderPosition, setSliderPosition] = useState(50);
  const handleBeforeAfterChange = (e) => {
    setSliderPosition(Number(e.target.value));
  };
  if (!data.beforeAfterData) return null;
  return /* @__PURE__ */ jsxs("div", { className: "mt-1 space-y-3 overflow-hidden", children: [
    /* @__PURE__ */ jsx("div", { className: "px-1 mb-3", children: /* @__PURE__ */ jsx(
      "div",
      {
        className: "rich-text-content text-gray-600/80 text-[16px] leading-relaxed font-medium text-left [&>p]:mb-0",
        dangerouslySetInnerHTML: { __html: data.summary }
      }
    ) }),
    /* @__PURE__ */ jsxs("div", { className: "relative w-full h-[450px] rounded-[5px] overflow-hidden shadow-2xl select-none group border border-gray-100", children: [
      /* @__PURE__ */ jsx(
        "img",
        {
          src: data.beforeAfterData.afterImage,
          alt: "After",
          className: "absolute inset-0 w-full h-full object-cover"
        }
      ),
      /* @__PURE__ */ jsx(
        "div",
        {
          className: "absolute inset-0 w-full h-full overflow-hidden",
          style: { clipPath: `inset(0 ${100 - sliderPosition}% 0 0)` },
          children: /* @__PURE__ */ jsx(
            "img",
            {
              src: data.beforeAfterData.beforeImage,
              alt: "Before",
              className: "absolute inset-0 w-full h-full object-cover"
            }
          )
        }
      ),
      /* @__PURE__ */ jsx(
        "div",
        {
          className: "absolute top-0 bottom-0 w-1 bg-white/80 cursor-ew-resize z-20 shadow-[0_0_20px_rgba(0,0,0,0.5)] backdrop-blur-sm",
          style: { left: `${sliderPosition}%` },
          children: /* @__PURE__ */ jsx("div", { className: "absolute top-1/2 left-1/2 -translate-x-1/2 -translate-y-1/2 w-10 h-10 bg-white rounded-[5px] flex items-center justify-center shadow-[0_4px_20px_rgba(0,0,0,0.4)] transform active:scale-95 transition-transform border-4 border-white/20", children: /* @__PURE__ */ jsx(ArrowLeftRight, { size: 18, className: "text-blue-600" }) })
        }
      ),
      /* @__PURE__ */ jsx(
        "input",
        {
          type: "range",
          min: "0",
          max: "100",
          value: sliderPosition,
          onChange: handleBeforeAfterChange,
          className: "absolute inset-0 w-full h-full opacity-0 cursor-ew-resize z-30"
        }
      ),
      /* @__PURE__ */ jsx("div", { className: "absolute bottom-6 left-6 z-10 pointer-events-none transition-opacity duration-300", style: { opacity: sliderPosition < 10 ? 0 : 1 }, children: /* @__PURE__ */ jsxs("div", { className: "bg-black/40 backdrop-blur-md text-white px-4 py-2 rounded-[5px] border border-white/20 shadow-lg flex items-center gap-2", children: [
        /* @__PURE__ */ jsx("div", { className: "w-2 h-2 rounded-[5px] bg-white/50" }),
        /* @__PURE__ */ jsx("span", { className: "text-[11px] font-black uppercase tracking-widest leading-none mt-0.5", children: data.beforeAfterData.beforeLabel })
      ] }) }),
      /* @__PURE__ */ jsx("div", { className: "absolute bottom-6 right-6 z-10 pointer-events-none transition-opacity duration-300", style: { opacity: sliderPosition > 90 ? 0 : 1 }, children: /* @__PURE__ */ jsxs("div", { className: "bg-white/40 backdrop-blur-md text-white px-4 py-2 rounded-[5px] border border-white/30 shadow-lg flex items-center gap-2", children: [
        /* @__PURE__ */ jsx("span", { className: "text-[11px] font-black uppercase tracking-widest leading-none mt-0.5 text-black", children: data.beforeAfterData.afterLabel }),
        /* @__PURE__ */ jsx("div", { className: "w-2 h-2 rounded-[5px] bg-blue-500 animate-pulse" })
      ] }) }),
      /* @__PURE__ */ jsx("div", { className: "absolute top-6 left-6 bg-black/30 backdrop-blur-sm px-3 py-1 rounded-[5px] border border-white/10 pointer-events-none", children: /* @__PURE__ */ jsx("span", { className: "text-[10px] text-white/80 font-bold uppercase tracking-widest", children: "Karşılaştırmak için kaydır" }) })
    ] })
  ] });
};

const FlipCard = ({ data }) => {
  const { t } = useLanguage();
  const [isFlipped, setIsFlipped] = useState(false);
  const [cardHeight, setCardHeight] = useState(500);
  const containerRef = useRef(null);
  useEffect(() => {
    if (!data.flipData) return;
    const img1 = new Image();
    const img2 = new Image();
    let loadedCount = 0;
    const calculateHeight = () => {
      loadedCount++;
      if (loadedCount === 2) {
        const containerWidth = containerRef.current?.offsetWidth || 600;
        const isFrontVertical = img1.naturalHeight > img1.naturalWidth;
        const isBackVertical = img2.naturalHeight > img2.naturalWidth;
        if (isFrontVertical && isBackVertical) {
          setCardHeight(400);
        } else {
          const height1 = containerWidth / img1.naturalWidth * img1.naturalHeight;
          const height2 = containerWidth / img2.naturalWidth * img2.naturalHeight;
          setCardHeight(Math.min(height1, height2));
        }
      }
    };
    img1.onload = calculateHeight;
    img2.onload = calculateHeight;
    img1.src = data.flipData.frontImage;
    img2.src = data.flipData.backImage;
    const handleResize = () => {
      if (img1.complete && img2.complete) {
        const containerWidth = containerRef.current?.offsetWidth || 600;
        if (img1.naturalHeight > img1.naturalWidth && img2.naturalHeight > img2.naturalWidth) {
          setCardHeight(400);
        } else {
          const height1 = containerWidth / img1.naturalWidth * img1.naturalHeight;
          const height2 = containerWidth / img2.naturalWidth * img2.naturalHeight;
          setCardHeight(Math.min(height1, height2));
        }
      }
    };
    window.addEventListener("resize", handleResize);
    return () => window.removeEventListener("resize", handleResize);
  }, [data.flipData]);
  if (!data.flipData) return null;
  return /* @__PURE__ */ jsxs("div", { className: "mt-1 space-y-3 overflow-hidden", children: [
    /* @__PURE__ */ jsx("div", { className: "px-1 mb-3", children: /* @__PURE__ */ jsx(
      "div",
      {
        className: "rich-text-content text-gray-600/80 text-[16px] leading-relaxed font-medium text-left [&>p]:mb-0",
        dangerouslySetInnerHTML: { __html: data.summary }
      }
    ) }),
    /* @__PURE__ */ jsx(
      "div",
      {
        ref: containerRef,
        className: "w-full cursor-pointer group perspective-1000 relative",
        onClick: (e) => {
          e.stopPropagation();
          setIsFlipped(!isFlipped);
        },
        style: {
          perspective: "1000px",
          height: `${cardHeight}px`
        },
        children: /* @__PURE__ */ jsxs(
          "div",
          {
            className: "relative w-full h-full transition-transform duration-700 ease-in-out transform-style-3d overflow-visible",
            style: {
              transformStyle: "preserve-3d",
              transform: isFlipped ? "rotateY(180deg)" : "rotateY(0deg)"
            },
            children: [
              /* @__PURE__ */ jsxs(
                "div",
                {
                  className: "absolute inset-0 w-full h-full backface-hidden flex items-center justify-center overflow-hidden",
                  style: { backfaceVisibility: "hidden" },
                  children: [
                    /* @__PURE__ */ jsxs("div", { className: "absolute inset-0 z-0 pointer-events-none", children: [
                      /* @__PURE__ */ jsx(
                        "img",
                        {
                          src: data.flipData.frontImage,
                          alt: "",
                          className: "w-full h-full object-cover blur-[60px] opacity-40 scale-110"
                        }
                      ),
                      /* @__PURE__ */ jsx("div", { className: "absolute inset-0 bg-white/10" })
                    ] }),
                    /* @__PURE__ */ jsx("div", { className: "absolute inset-0 bg-gradient-to-t from-black/90 via-black/20 to-transparent z-[1] pointer-events-none" }),
                    /* @__PURE__ */ jsx("img", { src: data.flipData.frontImage, alt: t("flip_card.alt_front"), className: "max-w-full max-h-full object-contain relative z-[2]" }),
                    /* @__PURE__ */ jsxs("div", { className: "absolute bottom-0 left-0 w-full p-8 text-white z-10", children: [
                      /* @__PURE__ */ jsx("div", { className: "flex items-center gap-2 mb-3", children: /* @__PURE__ */ jsx("span", { className: "bg-blue-600/90 backdrop-blur-md px-3 py-1 rounded-[5px] text-[10px] font-black uppercase tracking-widest shadow-lg border border-white/20", children: t("flip_card.tap_flip") }) }),
                      data.flipData.frontLink ? /* @__PURE__ */ jsx(
                        "a",
                        {
                          href: data.flipData.frontLink,
                          target: "_blank",
                          rel: "noopener noreferrer",
                          onClick: (e) => e.stopPropagation(),
                          className: "block hover:opacity-80 transition-opacity",
                          children: /* @__PURE__ */ jsx("h3", { className: "text-3xl font-black leading-tight mb-2 drop-shadow-md", children: data.flipData.frontTitle })
                        }
                      ) : /* @__PURE__ */ jsx("h3", { className: "text-3xl font-black leading-tight mb-2 drop-shadow-md", children: data.flipData.frontTitle }),
                      data.flipData.frontDescription && /* @__PURE__ */ jsx(
                        "div",
                        {
                          className: "text-white/90 text-sm leading-relaxed mb-5 line-clamp-2 font-medium",
                          dangerouslySetInnerHTML: { __html: data.flipData.frontDescription }
                        }
                      ),
                      /* @__PURE__ */ jsxs("div", { className: "flex items-center gap-2.5 text-white/70 text-[10px] font-bold uppercase tracking-widest", children: [
                        /* @__PURE__ */ jsx("div", { className: "p-1.5 rounded-full bg-white/10 backdrop-blur-md border border-white/20", children: /* @__PURE__ */ jsx(RotateCw, { size: 12, className: "animate-spin-slow" }) }),
                        /* @__PURE__ */ jsx("span", { children: t("flip_card.tap_for_back") })
                      ] })
                    ] }),
                    /* @__PURE__ */ jsx("div", { className: "absolute top-5 right-5 bg-black/30 backdrop-blur-md p-2.5 rounded-full border border-white/20 z-10 shadow-lg group-hover:scale-110 transition-transform", children: /* @__PURE__ */ jsx(RotateCw, { size: 18, className: "text-white" }) })
                  ]
                }
              ),
              /* @__PURE__ */ jsxs(
                "div",
                {
                  className: "absolute inset-0 w-full h-full backface-hidden flex items-center justify-center overflow-hidden",
                  style: {
                    backfaceVisibility: "hidden",
                    transform: "rotateY(180deg)"
                  },
                  children: [
                    /* @__PURE__ */ jsxs("div", { className: "absolute inset-0 z-0 pointer-events-none", children: [
                      /* @__PURE__ */ jsx(
                        "img",
                        {
                          src: data.flipData.backImage,
                          alt: "",
                          className: "w-full h-full object-cover blur-[60px] opacity-40 scale-110"
                        }
                      ),
                      /* @__PURE__ */ jsx("div", { className: "absolute inset-0 bg-white/10" })
                    ] }),
                    /* @__PURE__ */ jsx("div", { className: "absolute inset-0 bg-gradient-to-t from-black/90 via-black/20 to-transparent z-[1] pointer-events-none" }),
                    /* @__PURE__ */ jsx("img", { src: data.flipData.backImage, alt: t("flip_card.alt_back"), className: "max-w-full max-h-full object-contain relative z-[2]" }),
                    /* @__PURE__ */ jsxs("div", { className: "absolute bottom-0 left-0 w-full p-8 text-white z-10", children: [
                      /* @__PURE__ */ jsx("div", { className: "flex items-center gap-2 mb-3", children: /* @__PURE__ */ jsx("span", { className: "bg-emerald-600/90 backdrop-blur-md px-3 py-1 rounded-[5px] text-[10px] font-black uppercase tracking-widest shadow-lg border border-white/20", children: t("flip_card.back_badge") }) }),
                      data.flipData.backLink ? /* @__PURE__ */ jsx(
                        "a",
                        {
                          href: data.flipData.backLink,
                          target: "_blank",
                          rel: "noopener noreferrer",
                          onClick: (e) => e.stopPropagation(),
                          className: "block hover:opacity-80 transition-opacity",
                          children: /* @__PURE__ */ jsx("h3", { className: "text-3xl font-black leading-tight mb-2 drop-shadow-md", children: data.flipData.backTitle })
                        }
                      ) : /* @__PURE__ */ jsx("h3", { className: "text-3xl font-black leading-tight mb-2 drop-shadow-md", children: data.flipData.backTitle }),
                      data.flipData.backDescription && /* @__PURE__ */ jsx(
                        "div",
                        {
                          className: "text-white/90 text-sm leading-relaxed mb-5 line-clamp-2 font-medium",
                          dangerouslySetInnerHTML: { __html: data.flipData.backDescription }
                        }
                      ),
                      /* @__PURE__ */ jsxs("div", { className: "flex items-center gap-2.5 text-white/70 text-[10px] font-bold uppercase tracking-widest", children: [
                        /* @__PURE__ */ jsx("div", { className: "p-1.5 rounded-full bg-white/10 backdrop-blur-md border border-white/20", children: /* @__PURE__ */ jsx(RotateCw, { size: 12, className: "animate-spin-slow" }) }),
                        /* @__PURE__ */ jsx("span", { children: t("flip_card.tap_for_front") })
                      ] })
                    ] }),
                    /* @__PURE__ */ jsx("div", { className: "absolute top-5 right-5 bg-black/30 backdrop-blur-md p-2.5 rounded-full border border-white/20 z-10 shadow-lg group-hover:scale-110 transition-transform", children: /* @__PURE__ */ jsx(RotateCw, { size: 18, className: "text-white" }) })
                  ]
                }
              )
            ]
          }
        )
      }
    )
  ] });
};

const EmbedCard = ({ data }) => {
  useEffect(() => {
    const isTwitter = data.mediaUrl.includes("twitter.com") || data.mediaUrl.includes("x.com");
    if (isTwitter) {
      const src = "https://platform.twitter.com/widgets.js";
      const existing = document.querySelector(`script[src="${src}"]`);
      if (!existing) {
        const script = document.createElement("script");
        script.src = src;
        script.async = true;
        script.onload = () => window.twttr?.widgets?.load();
        document.body.appendChild(script);
      } else if (window.twttr?.widgets) {
        window.twttr.widgets.load();
      }
    }
  }, [data.mediaUrl]);
  let embedContent = null;
  let platformColor = "bg-gray-100";
  let platformIcon = /* @__PURE__ */ jsx(ExternalLink, { size: 16, className: "text-gray-500" });
  let platformName = "Bağlantı";
  if (data.mediaUrl.includes("twitter.com") || data.mediaUrl.includes("x.com")) {
    platformName = "X (Twitter)";
    platformColor = "bg-black text-white";
    platformIcon = /* @__PURE__ */ jsx(Twitter, { size: 14, className: "fill-current" });
    embedContent = /* @__PURE__ */ jsx("div", { className: "w-full flex justify-center bg-white overflow-hidden", children: /* @__PURE__ */ jsx("blockquote", { className: "twitter-tweet", "data-dnt": "true", "data-theme": "light", children: /* @__PURE__ */ jsx("a", { href: data.mediaUrl }) }) });
  } else if (data.mediaUrl.includes("facebook.com")) {
    platformName = "Facebook";
    platformColor = "bg-[#1877F2] text-white";
    platformIcon = /* @__PURE__ */ jsx(Facebook, { size: 14, className: "fill-current" });
    const encodedUrl = encodeURIComponent(data.mediaUrl);
    embedContent = /* @__PURE__ */ jsx("div", { className: "w-full flex justify-center bg-white overflow-hidden", children: /* @__PURE__ */ jsx(
      "iframe",
      {
        src: `https://www.facebook.com/plugins/post.php?href=${encodedUrl}&show_text=true&width=500`,
        width: "100%",
        height: "460",
        style: { border: "none", overflow: "hidden" },
        scrolling: "no",
        frameBorder: "0",
        allowFullScreen: true,
        allow: "autoplay; clipboard-write; encrypted-media; picture-in-picture; web-share",
        className: "w-full max-w-[500px]"
      }
    ) });
  } else if (data.mediaUrl.includes("instagram.com")) {
    platformName = "Instagram";
    platformColor = "bg-gradient-to-tr from-yellow-400 via-red-500 to-purple-500 text-white";
    platformIcon = /* @__PURE__ */ jsx(Instagram, { size: 14, className: "text-white" });
    const instaMatch = data.mediaUrl.match(/instagram\.com\/(p|reel|tv)\/([^/?#]+)/i);
    const instaType = instaMatch?.[1] || "p";
    const instaCode = instaMatch?.[2];
    const embedUrl = instaCode ? `https://www.instagram.com/${instaType}/${instaCode}/embed/captioned/?utm_source=ig_embed&captioned=1` : "";
    embedContent = embedUrl ? /* @__PURE__ */ jsx("div", { className: "w-full flex justify-center bg-white overflow-hidden", children: /* @__PURE__ */ jsx(
      "iframe",
      {
        src: embedUrl,
        title: "Instagram embed",
        width: "100%",
        height: "820",
        loading: "eager",
        style: { border: "none", overflow: "hidden" },
        scrolling: "no",
        frameBorder: "0",
        allow: "autoplay; clipboard-write; encrypted-media; picture-in-picture; web-share",
        className: "w-full max-w-[540px]"
      }
    ) }) : /* @__PURE__ */ jsx("div", { className: "w-full flex justify-center bg-white overflow-hidden", children: /* @__PURE__ */ jsxs("a", { href: data.mediaUrl, target: "_blank", rel: "noreferrer", className: "text-xs font-bold text-blue-600 hover:underline flex items-center gap-1", children: [
      /* @__PURE__ */ jsx(ExternalLink, { size: 12 }),
      "Instagram gönderisini aç"
    ] }) });
  } else if (data.mediaUrl.includes("pinterest.com") || data.mediaUrl.includes("pin.it")) {
    platformName = "Pinterest";
    platformColor = "bg-[#E60023] text-white";
    platformIcon = /* @__PURE__ */ jsx(ExternalLink, { size: 14, className: "text-white" });
    const pinId = data.mediaUrl.split("/").filter(Boolean).pop()?.split("?")[0];
    const isNumericId = !!pinId && /^\d+$/.test(pinId);
    embedContent = isNumericId ? /* @__PURE__ */ jsx("div", { className: "w-full flex justify-center bg-white overflow-hidden", children: /* @__PURE__ */ jsx(
      "iframe",
      {
        src: `https://assets.pinterest.com/ext/embed.html?id=${pinId}`,
        width: "100%",
        height: "1000",
        style: { border: "none", overflow: "hidden" },
        scrolling: "no",
        frameBorder: "0",
        allowFullScreen: true,
        className: "w-full max-w-[500px]"
      }
    ) }) : /* @__PURE__ */ jsx("div", { className: "w-full flex justify-center bg-white overflow-hidden", children: /* @__PURE__ */ jsxs("a", { href: data.mediaUrl, target: "_blank", rel: "noreferrer", className: "text-xs font-bold text-blue-600 hover:underline flex items-center gap-1", children: [
      /* @__PURE__ */ jsx(ExternalLink, { size: 12 }),
      "Pinterest pini"
    ] }) });
  }
  return /* @__PURE__ */ jsxs("div", { className: "mt-1 space-y-3 overflow-hidden", children: [
    /* @__PURE__ */ jsxs("div", { className: "px-1 space-y-2", children: [
      /* @__PURE__ */ jsx("div", { className: "flex items-center justify-between", children: /* @__PURE__ */ jsxs("div", { className: `inline-flex items-center gap-1.5 px-2.5 py-1 rounded-[5px] text-xs font-bold shadow-sm ${platformColor}`, children: [
        platformIcon,
        /* @__PURE__ */ jsx("span", { children: platformName })
      ] }) }),
      /* @__PURE__ */ jsx("h3", { className: "text-xl font-extrabold text-gray-900 leading-tight", children: data.title }),
      /* @__PURE__ */ jsx(
        "div",
        {
          className: "rich-text-content text-gray-600/80 text-[16px] leading-relaxed font-medium text-left [&>p]:mb-0",
          dangerouslySetInnerHTML: { __html: data.summary }
        }
      )
    ] }),
    /* @__PURE__ */ jsx("div", { className: "w-full flex justify-center mt-2", children: embedContent }),
    /* @__PURE__ */ jsx("div", { className: "flex justify-start pt-2", children: /* @__PURE__ */ jsxs("a", { href: data.mediaUrl, target: "_blank", rel: "noreferrer", className: "text-xs font-bold text-blue-600 hover:underline flex items-center gap-1", children: [
      /* @__PURE__ */ jsx(ExternalLink, { size: 12 }),
      "Kaynağa Git"
    ] }) })
  ] });
};

const youtubeParser$1 = (url) => {
  if (!url) return null;
  const regExp = /^.*(youtu.be\/|v\/|u\/\w\/|embed\/|watch\?v=|&v=|shorts\/)([^#&?]*).*/;
  const match = url.match(regExp);
  if (match && match[2].length === 11) {
    const id = match[2];
    return {
      id,
      embed: `https://www.youtube.com/embed/${id}?enablejsapi=1&autoplay=0&mute=0&controls=0&rel=0&showinfo=0&modestbranding=1&disablekb=1&fs=0&iv_load_policy=3&playsinline=1`
    };
  }
  return null;
};
const AudioCard = ({ data }) => {
  const [isPlaying, setIsPlaying] = useState(false);
  const [progress, setProgress] = useState(0);
  const [timeDisplay, setTimeDisplay] = useState(data.videoDuration || "00:00");
  const [volume, setVolume] = useState(1);
  const audioRef = useRef(null);
  const iframeRef = useRef(null);
  const ytInfo = youtubeParser$1(data.mediaUrl);
  const isYoutube = !!ytInfo;
  const ytDurationRef = useRef(0);
  const ytCurrentTimeRef = useRef(0);
  const sendYoutubeCommand = (func, args = "") => {
    if (iframeRef.current && iframeRef.current.contentWindow) {
      iframeRef.current.contentWindow.postMessage(
        JSON.stringify({ event: "command", func, args }),
        "*"
      );
    }
  };
  const toggleAudioPlay = (e) => {
    e.stopPropagation();
    if (isYoutube) {
      if (isPlaying) {
        sendYoutubeCommand("pauseVideo");
        setIsPlaying(false);
      } else {
        sendYoutubeCommand("playVideo");
        setIsPlaying(true);
      }
    } else if (audioRef.current) {
      if (isPlaying) {
        audioRef.current.pause();
        setIsPlaying(false);
      } else {
        audioRef.current.play();
        setIsPlaying(true);
      }
    }
  };
  const handleTimeUpdate = () => {
    if (audioRef.current) {
      const duration = audioRef.current.duration;
      const currentTime = audioRef.current.currentTime;
      if (duration > 0) {
        setProgress(currentTime / duration * 100);
        const remaining = duration - currentTime;
        setTimeDisplay(formatTime(Math.max(0, remaining)));
      }
    }
  };
  const handleSeek = (e) => {
    e.stopPropagation();
    const newTime = parseFloat(e.target.value);
    if (isYoutube) {
      sendYoutubeCommand("seekTo", [newTime, true]);
      const dur = ytDurationRef.current;
      if (dur > 0) setProgress(newTime / dur * 100);
    } else if (audioRef.current) {
      audioRef.current.currentTime = newTime;
      setProgress(newTime / audioRef.current.duration * 100);
    }
  };
  const handleVolumeChange = (e) => {
    e.stopPropagation();
    const newVolume = parseFloat(e.target.value);
    setVolume(newVolume);
    if (isYoutube) {
      sendYoutubeCommand("setVolume", newVolume * 100);
    } else if (audioRef.current) {
      audioRef.current.volume = newVolume;
    }
  };
  const skipAudio = (seconds) => {
    if (isYoutube) {
      const newTime = ytCurrentTimeRef.current + seconds;
      sendYoutubeCommand("seekTo", [newTime, true]);
    } else if (audioRef.current) {
      audioRef.current.currentTime += seconds;
    }
  };
  useEffect(() => {
    if (!isYoutube) return;
    const handleMessage = (event) => {
      if (!event.origin.includes("youtube.com")) return;
      let msg;
      try {
        msg = typeof event.data === "string" ? JSON.parse(event.data) : event.data;
      } catch (e) {
        return;
      }
      if (!msg) return;
      if (msg.event === "infoDelivery" && msg.info) {
        const info = msg.info;
        if (info.duration) ytDurationRef.current = info.duration;
        if (typeof info.currentTime !== "undefined") {
          ytCurrentTimeRef.current = info.currentTime;
          const dur = ytDurationRef.current;
          if (dur > 0) {
            setProgress(info.currentTime / dur * 100);
            setTimeDisplay(formatTime(Math.max(0, dur - info.currentTime)));
          }
        }
      }
    };
    window.addEventListener("message", handleMessage);
    return () => window.removeEventListener("message", handleMessage);
  }, [isYoutube]);
  useEffect(() => {
    if (!isYoutube || !isPlaying) return;
    const interval = setInterval(() => {
      sendYoutubeCommand("getCurrentTime");
      sendYoutubeCommand("getDuration");
    }, 500);
    return () => clearInterval(interval);
  }, [isYoutube, isPlaying]);
  const handleLoadedMetadata = (e) => {
    const el = e.currentTarget;
    if (el) {
      setTimeDisplay(formatTime(el.duration));
    }
  };
  return /* @__PURE__ */ jsxs("div", { className: "mt-1 space-y-3 overflow-hidden", children: [
    /* @__PURE__ */ jsx("div", { className: "px-1 mb-3", children: /* @__PURE__ */ jsx(
      "div",
      {
        className: "rich-text-content text-gray-600/80 text-[16px] leading-relaxed font-medium text-left [&>p]:mb-0",
        dangerouslySetInnerHTML: { __html: data.summary }
      }
    ) }),
    /* @__PURE__ */ jsxs("div", { className: "bg-gradient-to-br from-slate-900 to-slate-800 rounded-[5px] p-6 shadow-xl border border-slate-700/50 relative overflow-hidden group", children: [
      /* @__PURE__ */ jsx("div", { className: "absolute top-0 right-0 w-64 h-64 bg-blue-500 rounded-[5px] mix-blend-overlay filter blur-[64px] opacity-20 animate-pulse" }),
      /* @__PURE__ */ jsx("div", { className: "absolute bottom-0 left-0 w-64 h-64 bg-purple-500 rounded-[5px] mix-blend-overlay filter blur-[64px] opacity-20 animate-pulse", style: { animationDelay: "1s" } }),
      /* @__PURE__ */ jsx(
        "audio",
        {
          ref: audioRef,
          src: data.mediaUrl,
          onTimeUpdate: handleTimeUpdate,
          onLoadedMetadata: handleLoadedMetadata,
          onEnded: () => setIsPlaying(false)
        }
      ),
      /* @__PURE__ */ jsxs("div", { className: "relative z-10 flex flex-col items-start gap-6", children: [
        /* @__PURE__ */ jsxs("div", { className: "w-full flex flex-col items-start text-left space-y-2", children: [
          /* @__PURE__ */ jsxs("div", { className: "inline-flex items-center gap-1.5 px-3 py-1 rounded-[5px] bg-white/10 border border-white/5 backdrop-blur-sm shadow-sm", children: [
            /* @__PURE__ */ jsx(Headphones, { size: 12, className: "text-blue-300" }),
            /* @__PURE__ */ jsx("span", { className: "text-[10px] font-bold text-blue-100 uppercase tracking-widest", children: "PateezCast Özel" })
          ] }),
          /* @__PURE__ */ jsx("h3", { className: "text-2xl font-black text-white leading-tight", children: data.title }),
          /* @__PURE__ */ jsx("p", { className: "text-sm text-slate-400 font-medium", children: data.author })
        ] }),
        /* @__PURE__ */ jsxs("div", { className: "relative w-48 h-48 sm:w-56 sm:h-56 flex-shrink-0 my-2 mx-auto", children: [
          isYoutube && /* @__PURE__ */ jsx("div", { className: "absolute inset-0 opacity-0 pointer-events-none", children: /* @__PURE__ */ jsx(
            "iframe",
            {
              ref: iframeRef,
              src: ytInfo.embed,
              allow: "autoplay; encrypted-media",
              title: "YouTube Audio Player"
            }
          ) }),
          /* @__PURE__ */ jsx(
            "div",
            {
              className: `absolute top-0 left-0 w-full h-full rounded-full bg-black border-4 border-gray-800 shadow-2xl flex items-center justify-center transition-all duration-700 ease-out z-0
                ${isPlaying ? "translate-x-[35%] rotate-[360deg]" : "translate-x-0 rotate-0"}
              `,
              children: /* @__PURE__ */ jsxs("div", { className: "w-full h-full rounded-full border-[12px] border-gray-900/40 relative flex items-center justify-center", children: [
                /* @__PURE__ */ jsx("div", { className: "absolute inset-0 border border-white/5 rounded-full m-4" }),
                /* @__PURE__ */ jsx("div", { className: "absolute inset-0 border border-white/5 rounded-full m-8" }),
                /* @__PURE__ */ jsx("div", { className: "absolute inset-0 border border-white/5 rounded-full m-12" }),
                /* @__PURE__ */ jsx("div", { className: "w-16 h-16 bg-gradient-to-tr from-red-600 to-orange-500 rounded-full flex items-center justify-center shadow-inner relative z-10", children: /* @__PURE__ */ jsx("div", { className: "w-4 h-4 bg-slate-900 rounded-full border-2 border-black/20" }) })
              ] })
            }
          ),
          /* @__PURE__ */ jsxs("div", { className: `relative z-10 w-full h-full rounded-[5px] overflow-hidden shadow-2xl border-4 border-slate-700/50 bg-slate-800 transition-transform duration-700`, children: [
            /* @__PURE__ */ jsx(
              "img",
              {
                src: data.optimizedThumbnail?.src || data.thumbnail,
                srcSet: data.optimizedThumbnail?.srcSet,
                sizes: data.optimizedThumbnail?.sizes,
                alt: data.thumbnailAlt || data.seoTitle || data.title || "Cover",
                className: "w-full h-full object-contain"
              }
            ),
            /* @__PURE__ */ jsx("div", { className: `absolute inset-0 bg-black/40 flex items-center justify-center transition-opacity duration-300 ${isPlaying ? "opacity-100" : "opacity-0"}`, children: /* @__PURE__ */ jsxs("div", { className: "flex gap-1.5 items-end h-10", children: [
              /* @__PURE__ */ jsx("div", { className: "w-1.5 bg-white rounded-[5px] animate-equalizer", style: { animationDuration: "0.6s" } }),
              /* @__PURE__ */ jsx("div", { className: "w-1.5 bg-white rounded-[5px] animate-equalizer", style: { animationDuration: "1.1s" } }),
              /* @__PURE__ */ jsx("div", { className: "w-1.5 bg-white rounded-[5px] animate-equalizer", style: { animationDuration: "0.8s" } }),
              /* @__PURE__ */ jsx("div", { className: "w-1.5 bg-white rounded-[5px] animate-equalizer", style: { animationDuration: "0.5s" } })
            ] }) })
          ] })
        ] }),
        /* @__PURE__ */ jsxs("div", { className: "w-full space-y-4 px-2", children: [
          /* @__PURE__ */ jsxs("div", { className: "w-full group/seek", children: [
            /* @__PURE__ */ jsxs("div", { className: "flex items-center justify-between text-[11px] font-bold text-slate-400 mb-2", children: [
              /* @__PURE__ */ jsx("span", { children: isYoutube ? formatTime(ytCurrentTimeRef.current) : audioRef.current ? formatTime(audioRef.current.currentTime) : "00:00" }),
              /* @__PURE__ */ jsx("span", { children: timeDisplay })
            ] }),
            /* @__PURE__ */ jsxs("div", { className: "relative w-full h-2 bg-slate-700/50 rounded-[5px] overflow-hidden cursor-pointer", children: [
              /* @__PURE__ */ jsx(
                "div",
                {
                  className: "absolute top-0 left-0 h-full bg-gradient-to-r from-blue-500 to-purple-500 rounded-[5px] transition-all duration-100 ease-linear shadow-[0_0_10px_rgba(59,130,246,0.5)]",
                  style: { width: `${progress}%` }
                }
              ),
              /* @__PURE__ */ jsx(
                "input",
                {
                  type: "range",
                  min: "0",
                  max: isYoutube ? ytDurationRef.current || 100 : audioRef.current?.duration || 100,
                  value: isYoutube ? ytCurrentTimeRef.current || 0 : audioRef.current?.currentTime || 0,
                  onChange: handleSeek,
                  className: "absolute inset-0 w-full h-full opacity-0 cursor-pointer"
                }
              )
            ] })
          ] }),
          /* @__PURE__ */ jsxs("div", { className: "flex items-center justify-center gap-8", children: [
            /* @__PURE__ */ jsx("button", { onClick: () => skipAudio(-15), className: "text-slate-400 hover:text-white transition-colors p-3 hover:bg-white/5 rounded-[5px]", children: /* @__PURE__ */ jsx(Rewind, { size: 24, className: "fill-current" }) }),
            /* @__PURE__ */ jsx(
              "button",
              {
                onClick: toggleAudioPlay,
                className: "w-16 h-16 bg-white text-slate-900 rounded-[5px] flex items-center justify-center hover:scale-105 active:scale-95 transition-all shadow-[0_0_20px_rgba(255,255,255,0.2)]",
                children: isPlaying ? /* @__PURE__ */ jsx(Pause, { size: 28, className: "fill-slate-900 ml-0.5" }) : /* @__PURE__ */ jsx(Play, { size: 28, className: "fill-slate-900 ml-1" })
              }
            ),
            /* @__PURE__ */ jsx("button", { onClick: () => skipAudio(15), className: "text-slate-400 hover:text-white transition-colors p-3 hover:bg-white/5 rounded-[5px]", children: /* @__PURE__ */ jsx(FastForward, { size: 24, className: "fill-current" }) })
          ] }),
          /* @__PURE__ */ jsxs("div", { className: "flex items-center justify-center gap-3 pt-2", children: [
            /* @__PURE__ */ jsx("button", { onClick: () => {
              const newVol = volume === 0 ? 1 : 0;
              setVolume(newVol);
              if (isYoutube) {
                sendYoutubeCommand("setVolume", newVol * 100);
              } else if (audioRef.current) {
                audioRef.current.volume = newVol;
              }
            }, className: "text-slate-400 hover:text-white transition-colors", children: volume === 0 ? /* @__PURE__ */ jsx(VolumeX, { size: 18 }) : volume < 0.5 ? /* @__PURE__ */ jsx(Volume1, { size: 18 }) : /* @__PURE__ */ jsx(Volume2, { size: 18 }) }),
            /* @__PURE__ */ jsxs("div", { className: "w-32 relative h-1.5 bg-slate-700 rounded-[5px] cursor-pointer group/vol", children: [
              /* @__PURE__ */ jsx(
                "div",
                {
                  className: "absolute top-0 left-0 h-full bg-slate-400 group-hover/vol:bg-blue-400 rounded-[5px] transition-all",
                  style: { width: `${volume * 100}%` }
                }
              ),
              /* @__PURE__ */ jsx(
                "input",
                {
                  type: "range",
                  min: "0",
                  max: "1",
                  step: "0.05",
                  value: volume,
                  onChange: handleVolumeChange,
                  className: "absolute inset-0 w-full h-full opacity-0 cursor-pointer"
                }
              )
            ] })
          ] })
        ] })
      ] })
    ] })
  ] });
};

const youtubeParser = (url) => {
  if (!url) return null;
  const regExp = /^.*(youtu.be\/|v\/|u\/\w\/|embed\/|watch\?v=|&v=|shorts\/)([^#&?]*).*/;
  const match = url.match(regExp);
  if (match && match[2].length === 11) {
    const id = match[2];
    const isShorts = url.includes("/shorts/");
    return {
      id,
      embed: `https://www.youtube.com/embed/${id}?enablejsapi=1&autoplay=0&mute=1&controls=0&rel=0&showinfo=0&modestbranding=1&disablekb=1&fs=0&iv_load_policy=3&playsinline=1`,
      thumbnail: `https://img.youtube.com/vi/${id}/maxresdefault.jpg`,
      isShorts
    };
  }
  return null;
};
const VideoCard = ({ data }) => {
  const [isPlaying, setIsPlaying] = useState(false);
  const [isMuted, setIsMuted] = useState(true);
  const [progress, setProgress] = useState(0);
  const [timeDisplay, setTimeDisplay] = useState(data.videoDuration || "00:00");
  const videoRef = useRef(null);
  const iframeRef = useRef(null);
  const videoContainerRef = useRef(null);
  const userHasPaused = useRef(false);
  const ytDurationRef = useRef(0);
  const ytCurrentTimeRef = useRef(0);
  const ytPlayerReady = useRef(false);
  const ytPlayerStateRef = useRef(-1);
  const ytInfo = youtubeParser(data.mediaUrl);
  const isYoutube = !!ytInfo;
  const sendYoutubeCommand = (func, args = "") => {
    if (iframeRef.current && iframeRef.current.contentWindow) {
      iframeRef.current.contentWindow.postMessage(
        JSON.stringify({ event: "command", func, args }),
        "*"
      );
    }
  };
  const initYoutubeListeners = () => {
    if (iframeRef.current && iframeRef.current.contentWindow) {
      iframeRef.current.contentWindow.postMessage(
        JSON.stringify({ event: "listening" }),
        "*"
      );
      setTimeout(() => {
        if (iframeRef.current && iframeRef.current.contentWindow) {
          iframeRef.current.contentWindow.postMessage(
            JSON.stringify({ event: "command", func: "getDuration" }),
            "*"
          );
          if (videoContainerRef.current && !userHasPaused.current) {
            const rect = videoContainerRef.current.getBoundingClientRect();
            const navbarHeight = 72;
            const isFullyVisible = rect.top >= navbarHeight && rect.left >= 0 && rect.bottom <= (window.innerHeight || document.documentElement.clientHeight) && rect.right <= (window.innerWidth || document.documentElement.clientWidth);
            if (isFullyVisible) {
              if (ytDurationRef.current > 0) {
                setTimeDisplay(formatTime(ytDurationRef.current));
              } else if (data.videoDuration) {
                let parsedDuration = 0;
                const numeric = Number(data.videoDuration);
                if (!isNaN(numeric) && numeric > 0 && !String(data.videoDuration).includes(":")) {
                  parsedDuration = numeric;
                } else if (typeof data.videoDuration === "string" && data.videoDuration.includes(":")) {
                  const parts = data.videoDuration.split(":").map(Number);
                  if (parts.length === 2) parsedDuration = parts[0] * 60 + parts[1];
                  else if (parts.length === 3) parsedDuration = parts[0] * 3600 + parts[1] * 60 + parts[2];
                }
                if (parsedDuration > 0) {
                  ytDurationRef.current = parsedDuration;
                  setTimeDisplay(formatTime(parsedDuration));
                }
              }
              sendYoutubeCommand("playVideo");
              setIsPlaying(true);
            }
          }
        }
      }, 50);
    }
  };
  useEffect(() => {
    let duration = 0;
    if (data.videoDuration) {
      const numeric = Number(data.videoDuration);
      if (!isNaN(numeric) && numeric > 0 && !data.videoDuration.includes(":")) {
        duration = numeric;
      } else if (typeof data.videoDuration === "string" && data.videoDuration.includes(":")) {
        const parts = data.videoDuration.split(":").map(Number);
        if (parts.length === 2) duration = parts[0] * 60 + parts[1];
        else if (parts.length === 3) duration = parts[0] * 3600 + parts[1] * 60 + parts[2];
      }
    }
    if (duration > 0) {
      ytDurationRef.current = duration;
      if (!isPlaying && progress === 0) {
        setTimeDisplay(formatTime(duration));
      }
    }
  }, [data.videoDuration, isPlaying, progress]);
  useEffect(() => {
    if (isYoutube) return;
    const checkAndPlayVideo = () => {
      if (videoRef.current && videoContainerRef.current && !userHasPaused.current) {
        const rect = videoContainerRef.current.getBoundingClientRect();
        const navbarHeight = 72;
        const isFullyVisible = rect.top >= navbarHeight && rect.left >= 0 && rect.bottom <= (window.innerHeight || document.documentElement.clientHeight) && rect.right <= (window.innerWidth || document.documentElement.clientWidth);
        if (isFullyVisible && videoRef.current.paused) {
          videoRef.current.muted = true;
          videoRef.current.play().then(() => {
            setIsPlaying(true);
            setIsMuted(true);
          }).catch(() => setIsPlaying(false));
        }
      }
    };
    const timer = setTimeout(checkAndPlayVideo, 50);
    return () => clearTimeout(timer);
  }, [isYoutube]);
  useEffect(() => {
    if (!isYoutube) return;
    const handleMessage = (event) => {
      if (!event.origin.includes("youtube.com")) return;
      let msg;
      try {
        msg = typeof event.data === "string" ? JSON.parse(event.data) : event.data;
      } catch (e) {
        return;
      }
      if (!msg) return;
      if (msg.event === "onReady" || msg.event === "initialDelivery") {
        ytPlayerReady.current = true;
      }
      if (msg.event === "infoDelivery" && msg.info) {
        const info = msg.info;
        if (typeof info.playerState !== "undefined") {
          ytPlayerStateRef.current = info.playerState;
        }
        if (info.duration) {
          const d = Number(info.duration);
          if (!isNaN(d) && d > 0) {
            ytDurationRef.current = d;
          }
        }
        if (typeof info.currentTime !== "undefined") {
          const c = Number(info.currentTime);
          if (!isNaN(c) && c >= 0) {
            ytCurrentTimeRef.current = c;
            const dur = ytDurationRef.current;
            if (dur > 0) {
              setProgress(c / dur * 100);
              setTimeDisplay(formatTime(Math.max(0, dur - c)));
            }
          }
        }
      }
      if (msg.info && !msg.event) {
        const info = msg.info;
        if (info.duration) {
          const d = Number(info.duration);
          if (!isNaN(d) && d > 0) ytDurationRef.current = d;
        }
        if (typeof info.currentTime !== "undefined") {
          const c = Number(info.currentTime);
          if (!isNaN(c) && c >= 0) {
            ytCurrentTimeRef.current = c;
            const dur = ytDurationRef.current;
            if (dur > 0) {
              setProgress(c / dur * 100);
              setTimeDisplay(formatTime(Math.max(0, dur - c)));
            }
          }
        }
      }
    };
    window.addEventListener("message", handleMessage);
    return () => window.removeEventListener("message", handleMessage);
  }, [isYoutube]);
  useEffect(() => {
    if (!isYoutube || !isPlaying) return;
    const interval = setInterval(() => {
      if (iframeRef.current && iframeRef.current.contentWindow) {
        iframeRef.current.contentWindow.postMessage(
          JSON.stringify({ event: "command", func: "getCurrentTime" }),
          "*"
        );
        iframeRef.current.contentWindow.postMessage(
          JSON.stringify({ event: "command", func: "getDuration" }),
          "*"
        );
      }
      ytCurrentTimeRef.current = (ytCurrentTimeRef.current || 0) + 0.25;
      const dur = ytDurationRef.current;
      const cur = ytCurrentTimeRef.current;
      if (dur > 0) {
        const visualCur = Math.min(cur, dur);
        setProgress(visualCur / dur * 100);
        const remaining = Math.max(0, dur - visualCur);
        setTimeDisplay(formatTime(remaining));
      }
    }, 250);
    return () => clearInterval(interval);
  }, [isYoutube, isPlaying]);
  useEffect(() => {
    const NAVBAR_HEIGHT = 72;
    const checkVisibility = () => {
      if (!videoContainerRef.current) return;
      const rect = videoContainerRef.current.getBoundingClientRect();
      const windowHeight = window.innerHeight || document.documentElement.clientHeight;
      const windowWidth = window.innerWidth || document.documentElement.clientWidth;
      const isFullyVisible = rect.top >= NAVBAR_HEIGHT && rect.left >= 0 && rect.bottom <= windowHeight && rect.right <= windowWidth;
      if (isFullyVisible) {
        if (!userHasPaused.current && !isPlaying) {
          if (isYoutube) {
            if (ytDurationRef.current > 0) {
              setTimeDisplay(formatTime(ytDurationRef.current));
            } else if (data.videoDuration) {
              let parsedDuration = 0;
              const numeric = Number(data.videoDuration);
              if (!isNaN(numeric) && numeric > 0 && !String(data.videoDuration).includes(":")) {
                parsedDuration = numeric;
              } else if (typeof data.videoDuration === "string" && data.videoDuration.includes(":")) {
                const parts = data.videoDuration.split(":").map(Number);
                if (parts.length === 2) parsedDuration = parts[0] * 60 + parts[1];
                else if (parts.length === 3) parsedDuration = parts[0] * 3600 + parts[1] * 60 + parts[2];
              }
              if (parsedDuration > 0) {
                ytDurationRef.current = parsedDuration;
                setTimeDisplay(formatTime(parsedDuration));
              }
            }
            sendYoutubeCommand("playVideo");
            setIsPlaying(true);
          } else if (videoRef.current && videoRef.current.paused) {
            videoRef.current.muted = true;
            videoRef.current.play().then(() => {
              setIsPlaying(true);
              setIsMuted(true);
            }).catch(() => setIsPlaying(false));
          }
        }
      } else {
        if (isPlaying) {
          if (isYoutube) {
            sendYoutubeCommand("pauseVideo");
            setIsPlaying(false);
          } else if (videoRef.current && !videoRef.current.paused) {
            videoRef.current.pause();
            setIsPlaying(false);
          }
        }
      }
    };
    window.addEventListener("scroll", checkVisibility, { passive: true });
    window.addEventListener("resize", checkVisibility, { passive: true });
    checkVisibility();
    return () => {
      window.removeEventListener("scroll", checkVisibility);
      window.removeEventListener("resize", checkVisibility);
    };
  }, [isYoutube, isPlaying]);
  const toggleMute = (e) => {
    e.stopPropagation();
    if (isYoutube) {
      sendYoutubeCommand(isMuted ? "unMute" : "mute");
      setIsMuted(!isMuted);
    } else if (videoRef.current) {
      videoRef.current.muted = !isMuted;
      setIsMuted(!isMuted);
    }
  };
  const togglePlay = (e) => {
    e.stopPropagation();
    if (isYoutube) {
      if (isPlaying) {
        sendYoutubeCommand("pauseVideo");
        setIsPlaying(false);
        userHasPaused.current = true;
      } else {
        sendYoutubeCommand("playVideo");
        setIsPlaying(true);
        userHasPaused.current = false;
      }
    } else if (videoRef.current) {
      if (isPlaying) {
        videoRef.current.pause();
        setIsPlaying(false);
        userHasPaused.current = true;
      } else {
        videoRef.current.play();
        setIsPlaying(true);
        userHasPaused.current = false;
      }
    }
  };
  const handleTimeUpdate = () => {
    if (videoRef.current) {
      const dur = videoRef.current.duration;
      const cur = videoRef.current.currentTime;
      if (dur > 0) {
        setProgress(cur / dur * 100);
        setTimeDisplay(formatTime(Math.max(0, dur - cur)));
      }
    }
  };
  return /* @__PURE__ */ jsxs("div", { className: "mt-1 space-y-3 overflow-hidden", children: [
    /* @__PURE__ */ jsx("div", { className: "px-1 mb-3", children: /* @__PURE__ */ jsx(
      "div",
      {
        className: "rich-text-content text-gray-600/80 text-[16px] leading-relaxed font-medium text-left [&>p]:mb-0",
        dangerouslySetInnerHTML: { __html: data.summary }
      }
    ) }),
    /* @__PURE__ */ jsxs(
      "div",
      {
        ref: videoContainerRef,
        onClick: togglePlay,
        className: "relative w-full bg-black shadow-lg border border-gray-100 group flex justify-center items-center overflow-hidden cursor-pointer rounded-[5px]",
        children: [
          isYoutube ? /* @__PURE__ */ jsx("div", { className: `w-full mx-auto aspect-video ${ytInfo.isShorts ? "max-w-[300px] aspect-[9/16]" : ""}`, children: /* @__PURE__ */ jsx(
            "iframe",
            {
              ref: iframeRef,
              src: ytInfo.embed,
              className: "w-full h-full pointer-events-none scale-105",
              allow: "autoplay; encrypted-media; fullscreen",
              title: "YouTube video player",
              onLoad: initYoutubeListeners
            }
          ) }) : /* @__PURE__ */ jsx(
            "video",
            {
              ref: videoRef,
              src: data.mediaUrl,
              poster: data.optimizedThumbnail?.src || data.thumbnail,
              className: "w-auto h-auto max-h-[450px] object-contain mx-auto",
              muted: true,
              playsInline: true,
              loop: true,
              onLoadedMetadata: (e) => setTimeDisplay(formatTime(e.currentTarget.duration)),
              onTimeUpdate: handleTimeUpdate
            }
          ),
          /* @__PURE__ */ jsxs("div", { className: "absolute bottom-4 right-4 bg-black/60 backdrop-blur-md px-2.5 py-1 rounded-[5px] border border-white/10 flex items-center gap-1.5 z-20 mb-1.5 pointer-events-none", children: [
            /* @__PURE__ */ jsx(Clock, { size: 12, className: "text-white/80" }),
            /* @__PURE__ */ jsx("span", { className: "text-xs font-bold text-white tracking-wide font-mono min-w-[35px] text-left", children: timeDisplay })
          ] }),
          /* @__PURE__ */ jsxs("div", { className: `absolute inset-0 bg-black/10 transition-opacity duration-300 ${isPlaying ? "opacity-0 group-hover:opacity-100" : "opacity-100"}`, children: [
            /* @__PURE__ */ jsx(
              "button",
              {
                onClick: toggleMute,
                className: "absolute top-4 right-4 w-9 h-9 flex items-center justify-center rounded-[5px] bg-black/50 backdrop-blur-md border border-white/20 text-white z-20",
                children: isMuted ? /* @__PURE__ */ jsx(VolumeX, { size: 16 }) : /* @__PURE__ */ jsx(Volume2, { size: 16 })
              }
            ),
            /* @__PURE__ */ jsx("div", { className: "absolute inset-0 flex items-center justify-center p-8 pointer-events-none", children: /* @__PURE__ */ jsx("div", { className: `
              w-14 h-14 rounded-full bg-black/20 backdrop-blur-md border-2 border-white/40 
              flex items-center justify-center transition-all duration-300
              group-hover:scale-110 group-hover:bg-white/10 group-hover:border-white
            `, children: /* @__PURE__ */ jsx("span", { className: "material-symbols-rounded text-white", style: { fontSize: "28px", fontVariationSettings: "'FILL' 1" }, children: isPlaying ? "pause" : "play_arrow" }) }) })
          ] }),
          /* @__PURE__ */ jsx("div", { className: "absolute bottom-0 left-0 w-full h-1 bg-gray-800/30 z-30", children: /* @__PURE__ */ jsx("div", { className: "h-full bg-red-600 transition-all duration-100 ease-linear", style: { width: `${progress}%` } }) })
        ]
      }
    )
  ] });
};

const GalleryCard = ({ data }) => {
  const [currentSlide, setCurrentSlide] = useState(0);
  const [maxHeight, setMaxHeight] = useState(0);
  const containerRef = useRef(null);
  useEffect(() => {
    if (!data.mediaList || data.mediaList.length === 0) return;
    const loadImageDimensions = async () => {
      const containerWidth = containerRef.current?.offsetWidth || 800;
      const heights = await Promise.all(
        data.mediaList.map((src) => {
          return new Promise((resolve) => {
            const img = new Image();
            img.onload = () => {
              if (img.naturalHeight > img.naturalWidth) {
                resolve(0);
              } else {
                const scale = containerWidth / img.naturalWidth;
                const scaledHeight = img.naturalHeight * scale;
                resolve(scaledHeight);
              }
            };
            img.onerror = () => resolve(0);
            img.src = src;
          });
        })
      );
      const max = Math.max(...heights);
      if (max > 0) {
        setMaxHeight(max);
      }
    };
    loadImageDimensions();
    const handleResize = () => loadImageDimensions();
    window.addEventListener("resize", handleResize);
    return () => window.removeEventListener("resize", handleResize);
  }, [data.mediaList]);
  useEffect(() => {
    if (!data.mediaList || data.mediaList.length <= 1) return;
    const interval = setInterval(() => {
      setCurrentSlide((prev) => (prev + 1) % data.mediaList.length);
    }, 4e3);
    return () => clearInterval(interval);
  }, [data.mediaList]);
  const nextSlide = (e) => {
    e.stopPropagation();
    if (data.mediaList) {
      setCurrentSlide((prev) => (prev + 1) % data.mediaList.length);
    }
  };
  const prevSlide = (e) => {
    e.stopPropagation();
    if (data.mediaList) {
      setCurrentSlide((prev) => (prev - 1 + data.mediaList.length) % data.mediaList.length);
    }
  };
  if (!data.mediaList || data.mediaList.length === 0) return null;
  return /* @__PURE__ */ jsxs("div", { className: "mt-1 space-y-3 overflow-hidden", children: [
    /* @__PURE__ */ jsx("div", { className: "px-1 mb-3", children: /* @__PURE__ */ jsx(
      "div",
      {
        className: "rich-text-content text-gray-600/80 text-[16px] leading-relaxed font-medium text-left [&>p]:mb-0",
        dangerouslySetInnerHTML: { __html: data.summary }
      }
    ) }),
    /* @__PURE__ */ jsxs(
      "div",
      {
        ref: containerRef,
        className: "relative w-full overflow-hidden group select-none flex items-center justify-center",
        style: { height: maxHeight > 0 ? `${maxHeight}px` : "auto" },
        children: [
          /* @__PURE__ */ jsx(
            "img",
            {
              src: data.mediaList[currentSlide],
              alt: `Slide ${currentSlide}`,
              className: "max-w-full max-h-full object-contain transition-all duration-500"
            }
          ),
          /* @__PURE__ */ jsx(
            "button",
            {
              onClick: prevSlide,
              className: "absolute left-3 top-1/2 -translate-y-1/2 z-20 w-8 h-8 bg-white/10 hover:bg-white/25 border border-white/20 rounded-full flex items-center justify-center text-black transition-all hover:scale-110",
              children: /* @__PURE__ */ jsx(ChevronLeft, { size: 18 })
            }
          ),
          /* @__PURE__ */ jsx(
            "button",
            {
              onClick: nextSlide,
              className: "absolute right-3 top-1/2 -translate-y-1/2 z-20 w-8 h-8 bg-white/10 hover:bg-white/25 border border-white/20 rounded-full flex items-center justify-center text-black transition-all hover:scale-110",
              children: /* @__PURE__ */ jsx(ChevronRight, { size: 18 })
            }
          ),
          /* @__PURE__ */ jsx("div", { className: "absolute top-4 right-4 z-20", children: /* @__PURE__ */ jsx("div", { className: "bg-black/40 backdrop-blur-md px-3 py-1.5 rounded-[5px] border border-white/10", children: /* @__PURE__ */ jsxs("span", { className: "text-xs font-bold text-white tracking-widest", children: [
            currentSlide + 1,
            " ",
            /* @__PURE__ */ jsx("span", { className: "text-white/50", children: "/" }),
            " ",
            data.mediaList.length
          ] }) }) }),
          /* @__PURE__ */ jsx("div", { className: "absolute bottom-4 left-0 right-0 z-20 flex justify-center gap-2", children: data.mediaList.map((_, idx) => /* @__PURE__ */ jsx(
            "button",
            {
              onClick: (e) => {
                e.stopPropagation();
                setCurrentSlide(idx);
              },
              className: `h-1.5 rounded-[5px] transition-all duration-300 ${currentSlide === idx ? "w-6 bg-palette-red" : "w-1.5 bg-white/40 hover:bg-palette-red/60"}`
            },
            idx
          )) })
        ]
      }
    )
  ] });
};

const PollCard = ({ data }) => {
  const { t } = useLanguage();
  const [hasVoted, setHasVoted] = useState(false);
  const [votedOption, setVotedOption] = useState(null);
  const handleVote = (id) => {
    if (hasVoted) return;
    setVotedOption(id);
    setHasVoted(true);
  };
  const isImage = data.isImagePoll;
  const columnClass = isImage ? data.pollColumns === 3 ? "grid-cols-3" : "grid-cols-2" : "grid-cols-1";
  return /* @__PURE__ */ jsxs("div", { className: "mt-1 space-y-4 overflow-hidden", children: [
    /* @__PURE__ */ jsx("div", { className: "px-1 mb-2", children: /* @__PURE__ */ jsx(
      "div",
      {
        className: "text-palette-maroon/60 text-[15px] leading-relaxed font-[500] italic [&>p]:m-0",
        dangerouslySetInnerHTML: { __html: data.summary }
      }
    ) }),
    /* @__PURE__ */ jsxs("div", { className: "relative bg-gradient-to-br from-palette-beige/10 via-white to-palette-beige/5 rounded-[5px] border border-palette-beige/40 overflow-hidden shadow-sm", children: [
      data.thumbnail && /* @__PURE__ */ jsxs("div", { className: "relative w-full overflow-hidden group/image", children: [
        /* @__PURE__ */ jsx(
          "img",
          {
            src: data.optimizedThumbnail?.src || data.thumbnail,
            srcSet: data.optimizedThumbnail?.srcSet,
            sizes: data.optimizedThumbnail?.sizes,
            alt: data.thumbnailAlt || data.seoTitle || data.title,
            className: "w-full h-auto object-contain transition-transform duration-[2s] group-hover/image:scale-[1.02]"
          }
        ),
        /* @__PURE__ */ jsx("div", { className: "absolute inset-0 bg-gradient-to-t from-black/50 via-black/10 to-transparent pointer-events-none" }),
        /* @__PURE__ */ jsx("div", { className: "absolute bottom-4 right-4 z-20 flex items-center gap-2", children: /* @__PURE__ */ jsxs("div", { className: "flex items-center gap-1.5 bg-palette-red px-3 py-1.5 rounded-[3px] shadow-lg", children: [
          /* @__PURE__ */ jsx("span", { className: "material-symbols-rounded text-white", style: { fontSize: "14px", fontVariationSettings: "'FILL' 1" }, children: "poll" }),
          /* @__PURE__ */ jsx("span", { className: "text-[10px] font-black text-white uppercase tracking-widest", children: t("poll.badge") })
        ] }) }),
        /* @__PURE__ */ jsx("div", { className: "absolute top-4 left-4 z-20", children: /* @__PURE__ */ jsxs("div", { className: "flex items-center gap-2 bg-black/40 backdrop-blur-md px-3 py-1.5 rounded-[3px] border border-white/10", children: [
          /* @__PURE__ */ jsx("div", { className: "w-2 h-2 bg-emerald-400 rounded-full animate-pulse shadow-[0_0_8px_rgba(52,211,153,0.6)]" }),
          /* @__PURE__ */ jsx("span", { className: "text-[9px] font-black text-white uppercase tracking-widest", children: t("right.live") })
        ] }) })
      ] }),
      data.blockTitle && /* @__PURE__ */ jsxs("div", { className: "px-6 pt-6 pb-4", children: [
        /* @__PURE__ */ jsxs("h3", { className: "text-[20px] md:text-[24px] font-[900] text-palette-maroon tracking-tight leading-snug", children: [
          data.blockTitle,
          !String(data.blockTitle).trim().endsWith("?") && !String(data.blockTitle).trim().endsWith("!") ? "?" : ""
        ] }),
        data.blockDescription && /* @__PURE__ */ jsx(
          "div",
          {
            className: "mt-2 text-[13px] font-[600] text-palette-tan/60 leading-relaxed [&>p]:m-0",
            dangerouslySetInnerHTML: { __html: data.blockDescription }
          }
        )
      ] }),
      /* @__PURE__ */ jsx("div", { className: `px-6 pb-6 ${data.blockTitle ? "pt-0" : "pt-6"}`, children: /* @__PURE__ */ jsx("div", { className: `grid ${columnClass} gap-3`, children: data.options?.map((option, index) => {
        const isSelected = votedOption === option.id;
        const displayTotalVotes = hasVoted ? (data.totalVotes || 0) + 1 : data.totalVotes || 0;
        const currentOptionVotes = isSelected && hasVoted ? (option.votes || 0) + 1 : option.votes || 0;
        const percentage = displayTotalVotes > 0 ? Math.round(currentOptionVotes / displayTotalVotes * 100) : 0;
        if (isImage) {
          return /* @__PURE__ */ jsxs(
            "button",
            {
              disabled: hasVoted,
              onClick: () => handleVote(option.id),
              className: `group relative flex flex-col rounded-[5px] overflow-hidden transition-all duration-500 bg-palette-beige/5 border ${hasVoted ? isSelected ? "ring-2 ring-palette-maroon shadow-xl z-10 border-palette-maroon/40" : "opacity-40 grayscale-[50%] scale-[0.98] border-palette-beige/30" : "border-palette-beige/40 hover:shadow-xl hover:scale-[1.02] active:scale-[0.99]"}`,
              children: [
                /* @__PURE__ */ jsxs("div", { className: "relative w-full h-[240px] overflow-hidden", children: [
                  /* @__PURE__ */ jsx(
                    "div",
                    {
                      className: "absolute inset-0 bg-center bg-cover blur-2xl opacity-50 scale-110",
                      style: { backgroundImage: `url(${option.image})` }
                    }
                  ),
                  /* @__PURE__ */ jsx(
                    "img",
                    {
                      src: option.image,
                      alt: option.text,
                      className: `relative z-10 w-full h-full object-contain transition-transform duration-700 ${!hasVoted ? "group-hover:scale-105" : ""}`
                    }
                  ),
                  !hasVoted && /* @__PURE__ */ jsx("div", { className: "absolute inset-0 z-20 bg-gradient-to-t from-palette-maroon/60 via-transparent to-transparent opacity-0 group-hover:opacity-100 transition-opacity duration-300 flex items-end justify-center pb-4", children: /* @__PURE__ */ jsx("span", { className: "text-white text-[10px] font-black uppercase tracking-widest", children: t("poll.vote_action") }) }),
                  hasVoted && /* @__PURE__ */ jsxs("div", { className: `absolute inset-0 z-20 flex flex-col items-center justify-center transition-all duration-500 ${isSelected ? "bg-palette-maroon/70" : "bg-black/50"}`, children: [
                    /* @__PURE__ */ jsxs("div", { className: "text-white text-5xl font-[1000] italic tracking-tighter drop-shadow-lg animate-in zoom-in duration-500", children: [
                      /* @__PURE__ */ jsx(AnimatedNumber, { value: percentage, suffix: "" }),
                      "%"
                    ] }),
                    /* @__PURE__ */ jsxs("div", { className: "text-white/80 text-[11px] font-bold mt-1 animate-in fade-in slide-in-from-bottom-2 duration-700", children: [
                      currentOptionVotes,
                      " ",
                      t("poll.vote_unit")
                    ] }),
                    isSelected && /* @__PURE__ */ jsx("div", { className: "absolute top-3 right-3 w-8 h-8 bg-white text-palette-maroon rounded-full flex items-center justify-center shadow-lg animate-in zoom-in duration-300", children: /* @__PURE__ */ jsx(CheckCircle2, { size: 20, strokeWidth: 3 }) }),
                    /* @__PURE__ */ jsx("div", { className: "absolute bottom-0 left-0 right-0 h-1.5 bg-white/20", children: /* @__PURE__ */ jsx(
                      "div",
                      {
                        className: `h-full transition-all duration-[1500ms] ease-out ${isSelected ? "bg-white" : "bg-white/50"}`,
                        style: { width: `${percentage}%` }
                      }
                    ) })
                  ] })
                ] }),
                /* @__PURE__ */ jsx("div", { className: `px-4 py-3 transition-colors duration-300 ${hasVoted && isSelected ? "bg-palette-maroon/5" : "bg-white"}`, children: /* @__PURE__ */ jsx("span", { className: `text-[13px] font-[800] text-left block line-clamp-1 ${isSelected && hasVoted ? "text-palette-maroon" : "text-palette-maroon/70"}`, children: option.text }) })
              ]
            },
            option.id
          );
        }
        return /* @__PURE__ */ jsxs(
          "button",
          {
            disabled: hasVoted,
            onClick: () => handleVote(option.id),
            className: `group relative w-full rounded-[5px] transition-all duration-400 bg-white border overflow-hidden ${hasVoted ? isSelected ? "border-palette-maroon/50 shadow-sm" : "border-palette-beige/30 opacity-60" : "border-palette-beige/50 hover:border-palette-tan hover:bg-palette-beige/[0.03] active:scale-[0.99]"}`,
            children: [
              hasVoted && /* @__PURE__ */ jsx(
                "div",
                {
                  className: `absolute left-0 top-0 bottom-0 transition-all duration-[1200ms] ease-out ${isSelected ? "bg-palette-maroon/10" : "bg-palette-beige/40"}`,
                  style: { width: `${percentage}%` }
                }
              ),
              /* @__PURE__ */ jsxs("div", { className: "relative px-5 py-4 flex items-center justify-between gap-4", children: [
                /* @__PURE__ */ jsxs("div", { className: "flex items-center gap-3.5", children: [
                  /* @__PURE__ */ jsx("div", { className: `w-5 h-5 rounded-full border-2 flex items-center justify-center flex-shrink-0 transition-all duration-300 ${isSelected && hasVoted ? "border-palette-maroon bg-palette-maroon" : hasVoted ? "border-palette-beige/50" : "border-palette-beige group-hover:border-palette-tan"}`, children: isSelected && hasVoted && /* @__PURE__ */ jsx("div", { className: "w-2 h-2 bg-white rounded-full animate-in zoom-in duration-200" }) }),
                  /* @__PURE__ */ jsx("span", { className: `text-[15px] font-[700] tracking-tight transition-colors ${isSelected && hasVoted ? "text-palette-maroon" : "text-palette-maroon/70"}`, children: option.text })
                ] }),
                hasVoted && /* @__PURE__ */ jsxs("div", { className: "flex items-center gap-3 flex-shrink-0", children: [
                  /* @__PURE__ */ jsxs("div", { className: "text-right", children: [
                    /* @__PURE__ */ jsx("span", { className: `text-[14px] font-[900] tabular-nums block ${isSelected ? "text-palette-maroon" : "text-palette-tan/60"}`, children: /* @__PURE__ */ jsx(AnimatedNumber, { value: percentage, suffix: "%" }) }),
                    /* @__PURE__ */ jsxs("span", { className: "text-[10px] font-[600] text-palette-tan/50", children: [
                      currentOptionVotes,
                      " ",
                      t("poll.vote_unit")
                    ] })
                  ] }),
                  isSelected && /* @__PURE__ */ jsx(CheckCircle2, { size: 18, className: "text-palette-maroon animate-in zoom-in duration-300" })
                ] })
              ] })
            ]
          },
          option.id
        );
      }) }) }),
      /* @__PURE__ */ jsxs("div", { className: "px-6 py-4 bg-palette-beige/[0.04] border-t border-palette-beige/20 flex items-center justify-between", children: [
        /* @__PURE__ */ jsxs("div", { className: "flex items-center gap-2 text-palette-tan/50", children: [
          /* @__PURE__ */ jsx(Users, { size: 14 }),
          /* @__PURE__ */ jsxs("span", { className: "text-[11px] font-[800] tracking-wide", children: [
            /* @__PURE__ */ jsx(AnimatedNumber, { value: hasVoted ? (data.totalVotes || 0) + 1 : data.totalVotes || 0, suffix: "" }),
            " ",
            t("poll.participant_unit")
          ] })
        ] }),
        hasVoted && /* @__PURE__ */ jsxs("div", { className: "flex items-center gap-1.5 text-emerald-600 animate-in fade-in slide-in-from-right-2 duration-500", children: [
          /* @__PURE__ */ jsx(CheckCircle2, { size: 14 }),
          /* @__PURE__ */ jsx("span", { className: "text-[10px] font-black uppercase tracking-widest", children: t("card.vote") })
        ] })
      ] })
    ] })
  ] });
};

const VSCard = ({ data }) => {
  const [hasVoted, setHasVoted] = useState(false);
  const [votedOption, setVotedOption] = useState(null);
  const [imageRatio, setImageRatio] = useState("horizontal");
  const [hoveredSide, setHoveredSide] = useState(null);
  React.useEffect(() => {
    if (data.thumbnail) {
      const img = new Image();
      img.onload = () => {
        if (img.height > img.width) {
          setImageRatio("vertical");
        } else {
          setImageRatio("horizontal");
        }
      };
      img.src = data.thumbnail;
    }
  }, [data.thumbnail]);
  const handleVote = (id) => {
    if (hasVoted) return;
    setVotedOption(id);
    setHasVoted(true);
  };
  const left = data.options?.[0];
  const right = data.options?.[1];
  const displayTotalVotes = hasVoted ? (data.totalVotes || 0) + 1 : data.totalVotes || 0;
  const leftVotes = votedOption === left?.id && hasVoted ? (left?.votes || 0) + 1 : left?.votes || 0;
  const rightVotes = votedOption === right?.id && hasVoted ? (right?.votes || 0) + 1 : right?.votes || 0;
  const leftPct = displayTotalVotes > 0 ? Math.round(leftVotes / displayTotalVotes * 100) : 50;
  const rightPct = 100 - leftPct;
  const leftFlex = hasVoted ? leftPct : hoveredSide === "left" ? 55 : hoveredSide === "right" ? 45 : 50;
  const rightFlex = 100 - leftFlex;
  return /* @__PURE__ */ jsxs("div", { className: "mt-1 space-y-4 overflow-hidden", children: [
    /* @__PURE__ */ jsx("div", { className: "px-1 mb-3", children: /* @__PURE__ */ jsx(
      "div",
      {
        className: "rich-text-content text-gray-600/80 text-[16px] leading-relaxed font-medium text-left [&>p]:mb-0",
        dangerouslySetInnerHTML: { __html: data.summary }
      }
    ) }),
    /* @__PURE__ */ jsxs("div", { className: `relative rounded-[5px] overflow-hidden shadow-lg border border-palette-beige/50 bg-black/5 flex items-center justify-center transition-all duration-700 ${imageRatio === "vertical" ? "h-[400px]" : "w-full h-auto"}`, children: [
      /* @__PURE__ */ jsx(
        "div",
        {
          className: "absolute inset-0 bg-center bg-no-repeat bg-cover blur-2xl opacity-20 scale-110",
          style: { backgroundImage: `url(${data.thumbnail})` }
        }
      ),
      /* @__PURE__ */ jsx(
        "img",
        {
          src: data.optimizedThumbnail?.src || data.thumbnail,
          srcSet: data.optimizedThumbnail?.srcSet,
          sizes: data.optimizedThumbnail?.sizes,
          alt: data.thumbnailAlt || data.seoTitle || data.title,
          className: `relative z-10 transition-transform duration-1000 group-hover:scale-105 ${imageRatio === "vertical" ? "w-auto h-full max-w-full object-contain" : "w-full h-auto block"}`
        }
      ),
      /* @__PURE__ */ jsx("div", { className: "absolute inset-0 z-20 bg-gradient-to-t from-palette-maroon/40 via-transparent to-transparent pointer-events-none" }),
      /* @__PURE__ */ jsx("div", { className: "absolute bottom-4 left-4 z-30 group/arena transform-gpu", children: /* @__PURE__ */ jsxs("div", { className: "flex items-center rounded-[4px] overflow-hidden shadow-[0_12px_24px_-8px_rgba(0,0,0,0.5)] border border-white/10 backdrop-blur-md", children: [
        /* @__PURE__ */ jsxs("div", { className: "bg-palette-red p-2.5 relative flex items-center justify-center", children: [
          /* @__PURE__ */ jsx("div", { className: "absolute inset-0 bg-white/20 animate-pulse pointer-events-none" }),
          /* @__PURE__ */ jsx(Swords, { size: 18, className: "text-white animate-bounce-subtle relative z-10" })
        ] }),
        /* @__PURE__ */ jsxs("div", { className: "bg-palette-maroon/85 px-4 py-2 border-l border-white/5 leading-none flex flex-col justify-center", children: [
          /* @__PURE__ */ jsx("span", { className: "text-white text-[11px] font-[1000] uppercase tracking-[0.2em] drop-shadow-md", children: "DÜELLO BAŞLASIN" }),
          /* @__PURE__ */ jsx("div", { className: "h-[1px] w-full bg-gradient-to-r from-palette-red to-transparent mt-1 opacity-50" })
        ] })
      ] }) })
    ] }),
    /* @__PURE__ */ jsxs("div", { className: "bg-white p-2 rounded-[5px] border border-palette-beige shadow-sm overflow-hidden", children: [
      (data.items?.[0]?.title || data.blockTitle) && /* @__PURE__ */ jsxs("div", { className: "pt-4 pb-2 px-4 text-left", children: [
        /* @__PURE__ */ jsx("h3", { className: "text-[18px] font-[900] italic text-palette-maroon tracking-tighter uppercase leading-none drop-shadow-sm", children: data.items?.[0]?.title || data.blockTitle }),
        /* @__PURE__ */ jsx("div", { className: "w-12 h-[3px] bg-palette-red/10 mt-2 rounded-full" })
      ] }),
      /* @__PURE__ */ jsxs("div", { className: "relative flex items-stretch h-[320px] rounded-[5px] overflow-hidden bg-black/5", style: { contain: "layout style paint" }, children: [
        /* @__PURE__ */ jsxs(
          "button",
          {
            onClick: () => handleVote(left.id),
            onMouseEnter: () => !hasVoted && setHoveredSide("left"),
            onMouseLeave: () => setHoveredSide(null),
            disabled: hasVoted,
            className: "relative overflow-hidden group/left",
            style: {
              width: `${leftFlex}%`,
              transition: "width 600ms cubic-bezier(0.4, 0, 0.2, 1)",
              willChange: "width",
              contain: "strict"
            },
            children: [
              /* @__PURE__ */ jsx(
                "img",
                {
                  src: left.image,
                  className: `absolute inset-0 w-full h-full object-cover ${!hasVoted ? "group-hover/left:scale-110" : ""}`,
                  style: {
                    transform: "translate3d(0, 0, 0)",
                    transition: "transform 600ms cubic-bezier(0.4, 0, 0.2, 1)",
                    willChange: "transform",
                    backfaceVisibility: "hidden"
                  }
                }
              ),
              /* @__PURE__ */ jsx(
                "div",
                {
                  className: `absolute inset-0 ${hasVoted ? votedOption === left.id ? "bg-palette-maroon/20" : "bg-black/60 brightness-50 grayscale-[0.8]" : "bg-gradient-to-r from-palette-maroon/60 to-transparent group-hover/left:opacity-40"}`,
                  style: {
                    transition: "opacity 500ms cubic-bezier(0.25, 0.46, 0.45, 0.94)",
                    willChange: "opacity"
                  }
                }
              ),
              /* @__PURE__ */ jsxs("div", { className: `absolute inset-0 p-6 flex flex-col justify-end items-start text-left ${hasVoted ? "opacity-100" : "opacity-80"}`, style: { transition: "opacity 500ms cubic-bezier(0.25, 0.46, 0.45, 0.94)" }, children: [
                /* @__PURE__ */ jsx(
                  "span",
                  {
                    className: `text-white text-[10px] font-black uppercase tracking-[0.2em] mb-2 ${hasVoted ? "scale-110 origin-left" : ""}`,
                    style: { transition: "transform 500ms cubic-bezier(0.25, 0.46, 0.45, 0.94)" },
                    children: left.text
                  }
                ),
                hasVoted && /* @__PURE__ */ jsxs("div", { className: "flex flex-col items-start animate-in slide-in-from-left duration-700", children: [
                  /* @__PURE__ */ jsx("div", { className: "text-white text-5xl font-[900] italic tracking-tighter leading-none", children: /* @__PURE__ */ jsx(AnimatedNumber, { value: leftPct }) }),
                  /* @__PURE__ */ jsx("div", { className: "text-white/80 text-[10px] font-black uppercase tracking-widest mt-2 bg-white/10 backdrop-blur-sm px-2 py-0.5 rounded-[2px] self-start", children: /* @__PURE__ */ jsx(AnimatedNumber, { value: leftVotes, suffix: " OY" }) })
                ] })
              ] }),
              hasVoted && votedOption === left.id && /* @__PURE__ */ jsx("div", { className: "absolute top-4 left-4 bg-palette-red text-white p-1.5 rounded-full shadow-lg border-2 border-white animate-bounce-subtle z-30", children: /* @__PURE__ */ jsx(CheckCircle2, { size: 16, strokeWidth: 3 }) })
            ]
          }
        ),
        /* @__PURE__ */ jsxs(
          "div",
          {
            className: "absolute top-0 bottom-0 z-40 flex items-center justify-center pointer-events-none",
            style: {
              left: `${leftFlex}%`,
              transition: "left 600ms cubic-bezier(0.4, 0, 0.2, 1)",
              willChange: "left",
              transform: "translate3d(0, 0, 0)"
            },
            children: [
              /* @__PURE__ */ jsx("div", { className: "w-[1.5px] h-full bg-gradient-to-b from-transparent via-white/40 to-transparent z-10" }),
              /* @__PURE__ */ jsx("div", { className: "absolute top-1/2 left-1/2 -translate-x-1/2 -translate-y-1/2 z-40", style: { transform: "translate3d(-50%, -50%, 0)" }, children: /* @__PURE__ */ jsxs("div", { className: "relative group/vs", children: [
                /* @__PURE__ */ jsx("div", { className: "absolute inset-0 bg-white/10 blur-xl rounded-full scale-110" }),
                /* @__PURE__ */ jsxs("div", { className: "relative w-[68px] h-[68px] transform rotate-45 flex items-center justify-center p-[2.5px] shadow-[0_15px_35px_rgba(0,0,0,0.6)]", children: [
                  /* @__PURE__ */ jsx("div", { className: "absolute inset-0 rounded-[12px] border-[2.5px] border-white/90 bg-white" }),
                  /* @__PURE__ */ jsxs("div", { className: "relative w-full h-full rounded-[8px] overflow-hidden flex items-center justify-center shadow-inner", children: [
                    /* @__PURE__ */ jsx("div", { className: "absolute inset-0 bg-gradient-to-br from-[#1B2838] via-[#0F172A] to-[#020617]" }),
                    /* @__PURE__ */ jsx("div", { className: "absolute inset-0 flex items-center justify-center opacity-15 transform -rotate-45", children: /* @__PURE__ */ jsx(Zap, { size: 52, fill: "white", className: "text-white blur-[0.5px]" }) }),
                    /* @__PURE__ */ jsx("div", { className: "absolute inset-0 bg-gradient-to-tr from-transparent via-white/5 to-white/20" }),
                    /* @__PURE__ */ jsx("span", { className: "relative z-10 font-[1000] italic text-[24px] text-white tracking-[-0.05em] transform -rotate-45 mr-1 drop-shadow-[0_4px_6px_rgba(0,0,0,0.9)]", children: "VS" })
                  ] })
                ] })
              ] }) })
            ]
          }
        ),
        /* @__PURE__ */ jsxs(
          "button",
          {
            onClick: () => handleVote(right.id),
            onMouseEnter: () => !hasVoted && setHoveredSide("right"),
            onMouseLeave: () => setHoveredSide(null),
            disabled: hasVoted,
            className: "relative overflow-hidden group/right",
            style: {
              width: `${rightFlex}%`,
              transition: "width 600ms cubic-bezier(0.4, 0, 0.2, 1)",
              willChange: "width",
              contain: "strict"
            },
            children: [
              /* @__PURE__ */ jsx(
                "img",
                {
                  src: right.image,
                  className: `absolute inset-0 w-full h-full object-cover ${!hasVoted ? "group-hover/right:scale-110" : ""}`,
                  style: {
                    transform: "translate3d(0, 0, 0)",
                    transition: "transform 600ms cubic-bezier(0.4, 0, 0.2, 1)",
                    willChange: "transform",
                    backfaceVisibility: "hidden"
                  }
                }
              ),
              /* @__PURE__ */ jsx(
                "div",
                {
                  className: `absolute inset-0 ${hasVoted ? votedOption === right.id ? "bg-palette-maroon/20" : "bg-black/60 brightness-50 grayscale-[0.8]" : "bg-gradient-to-l from-palette-maroon/60 to-transparent group-hover/right:opacity-40"}`,
                  style: {
                    transition: "opacity 500ms cubic-bezier(0.25, 0.46, 0.45, 0.94)",
                    willChange: "opacity"
                  }
                }
              ),
              /* @__PURE__ */ jsxs("div", { className: `absolute inset-0 p-6 flex flex-col justify-end items-start text-left ${hasVoted ? "opacity-100" : "opacity-80"}`, style: { transition: "opacity 500ms cubic-bezier(0.25, 0.46, 0.45, 0.94)" }, children: [
                /* @__PURE__ */ jsx(
                  "span",
                  {
                    className: `text-white text-[10px] font-black uppercase tracking-[0.2em] mb-2 ${hasVoted ? "scale-110 origin-left" : ""}`,
                    style: { transition: "transform 500ms cubic-bezier(0.25, 0.46, 0.45, 0.94)" },
                    children: right.text
                  }
                ),
                hasVoted && /* @__PURE__ */ jsxs("div", { className: "flex flex-col items-start animate-in slide-in-from-right duration-700", children: [
                  /* @__PURE__ */ jsx("div", { className: "text-white text-5xl font-[900] italic tracking-tighter leading-none", children: /* @__PURE__ */ jsx(AnimatedNumber, { value: rightPct }) }),
                  /* @__PURE__ */ jsx("div", { className: "text-white/80 text-[10px] font-black uppercase tracking-widest mt-2 bg-white/10 backdrop-blur-sm px-2 py-0.5 rounded-[2px] self-start", children: /* @__PURE__ */ jsx(AnimatedNumber, { value: rightVotes, suffix: " OY" }) })
                ] })
              ] }),
              hasVoted && votedOption === right.id && /* @__PURE__ */ jsx("div", { className: "absolute top-4 right-4 bg-palette-red text-white p-1.5 rounded-full shadow-lg border-2 border-white animate-bounce-subtle z-30", children: /* @__PURE__ */ jsx(CheckCircle2, { size: 16, strokeWidth: 3 }) })
            ]
          }
        )
      ] }),
      /* @__PURE__ */ jsxs("div", { className: "p-4 flex items-center justify-start gap-2 text-palette-tan/40", children: [
        /* @__PURE__ */ jsx("div", { className: "p-1 rounded-[4px] bg-palette-beige/50 border border-palette-tan/10", children: /* @__PURE__ */ jsx(Users, { size: 14 }) }),
        /* @__PURE__ */ jsx("span", { className: "text-[10px] font-[900] uppercase tracking-[0.15em]", children: /* @__PURE__ */ jsx(AnimatedNumber, { value: hasVoted ? (data.totalVotes || 0) + 1 : data.totalVotes || 0, suffix: " Oy Verildi" }) })
      ] })
    ] })
  ] });
};

const ParagraphCard = ({ data }) => {
  const items = data.paragraphData?.items || [];
  const quoteAuthor = data.paragraphData?.quoteAuthor;
  return /* @__PURE__ */ jsxs("div", { className: "mt-1 space-y-4 overflow-hidden", children: [
    /* @__PURE__ */ jsx("div", { className: "px-1 mb-2", children: /* @__PURE__ */ jsx(
      "div",
      {
        className: "rich-text-content text-palette-tan/60 text-[16px] font-medium leading-relaxed text-left [&>p]:mb-0",
        dangerouslySetInnerHTML: { __html: data.summary }
      }
    ) }),
    /* @__PURE__ */ jsxs("div", { className: "relative bg-palette-beige/20 rounded-[5px] border border-palette-beige/50 p-8 md:p-12 overflow-hidden shadow-sm group", children: [
      /* @__PURE__ */ jsx("div", { className: "absolute -top-4 -left-4 text-palette-red/5 select-none pointer-events-none group-hover:scale-110 transition-transform duration-1000", children: /* @__PURE__ */ jsx(Quote, { size: 200 }) }),
      /* @__PURE__ */ jsxs("div", { className: "relative z-10 flex flex-col items-start text-left", children: [
        /* @__PURE__ */ jsx("div", { className: "bg-white p-4 rounded-full shadow-md border border-palette-beige/30 mb-8 transform -rotate-3 group-hover:rotate-0 transition-transform duration-700 ml-0 mr-auto", children: /* @__PURE__ */ jsx(Quote, { size: 32, className: "text-palette-red drop-shadow-sm", fill: "currentColor" }) }),
        /* @__PURE__ */ jsx("div", { className: "space-y-6 max-w-[90%] ml-0 mr-auto", children: items.map((item, index) => /* @__PURE__ */ jsx(
          "div",
          {
            className: "rich-text-content text-[22px] md:text-[26px] font-[800] text-palette-maroon/90 leading-snug tracking-tight italic flex flex-col items-start break-words",
            dangerouslySetInnerHTML: { __html: item }
          },
          index
        )) }),
        quoteAuthor && /* @__PURE__ */ jsxs("div", { className: "mt-10 flex items-center gap-3 ml-0 mr-auto", children: [
          /* @__PURE__ */ jsx("div", { className: "w-10 h-[2px] bg-palette-red/20 rounded-full" }),
          /* @__PURE__ */ jsx("span", { className: "text-[14px] font-black uppercase tracking-[0.2em] text-palette-tan/60", children: quoteAuthor })
        ] })
      ] }),
      /* @__PURE__ */ jsx("div", { className: "absolute -bottom-20 -right-20 w-64 h-64 bg-palette-red/5 rounded-full blur-[80px] pointer-events-none" })
    ] })
  ] });
};

const EmojiPicker = Picker.default || Picker;
const CommentItem = ({
  comment,
  isReply = false,
  onReply,
  onLike,
  onReport,
  onDelete,
  onBlock,
  isPublisher,
  currentUserId
}) => {
  const { t, currentLang } = useLanguage();
  const [showOptions, setShowOptions] = useState(false);
  const formatTime = (dateString) => {
    const now = /* @__PURE__ */ new Date();
    const date = new Date(dateString);
    const diffInSeconds = Math.floor((now.getTime() - date.getTime()) / 1e3);
    if (diffInSeconds < 60) return t("time.just_now");
    if (diffInSeconds < 3600) return t("time.minutes_ago").replace("{count}", String(Math.floor(diffInSeconds / 60)));
    if (diffInSeconds < 86400) return t("time.hours_ago").replace("{count}", String(Math.floor(diffInSeconds / 3600)));
    return date.toLocaleDateString(currentLang.code);
  };
  const displayName = comment.user_name || comment.guest_name || t("comments.guest");
  const displayAvatar = comment.user_avatar || `https://ui-avatars.com/api/?name=${encodeURIComponent(displayName)}&background=f3f4f6&color=94a3b8`;
  return /* @__PURE__ */ jsxs("div", { className: `flex flex-col ${isReply ? "mt-3" : "mt-4 animate-in fade-in slide-in-from-top-1"}`, children: [
    /* @__PURE__ */ jsxs("div", { className: `flex gap-3 ${isReply ? "ml-11 relative" : ""}`, children: [
      isReply && /* @__PURE__ */ jsx("div", { className: "absolute -left-5 top-0 w-4 h-4 border-b-2 border-l-2 border-palette-beige rounded-bl-[5px]" }),
      /* @__PURE__ */ jsx("div", { className: "flex-shrink-0", children: /* @__PURE__ */ jsx("div", { className: `rounded-[5px] overflow-hidden border border-palette-beige ${isReply ? "w-7 h-7" : "w-9 h-9"} shadow-sm`, children: /* @__PURE__ */ jsx("img", { src: displayAvatar, alt: displayName, className: "w-full h-full object-cover" }) }) }),
      /* @__PURE__ */ jsxs("div", { className: "flex-1", children: [
        /* @__PURE__ */ jsxs("div", { className: "bg-palette-beige/30 rounded-[5px] rounded-tl-none p-3 px-3.5 border border-palette-beige/50 group relative", children: [
          /* @__PURE__ */ jsxs("div", { className: "flex items-center justify-between mb-0.5", children: [
            /* @__PURE__ */ jsxs("div", { className: "flex items-center gap-2", children: [
              /* @__PURE__ */ jsxs("h6", { className: "text-xs font-bold text-palette-maroon flex items-center gap-1", children: [
                displayName,
                comment.is_pinned && /* @__PURE__ */ jsx("span", { className: "material-symbols-rounded text-[14px] text-amber-500 fill-current", children: "push_pin" })
              ] }),
              /* @__PURE__ */ jsxs("span", { className: "text-[10px] text-palette-tan/40 font-medium", children: [
                "• ",
                formatTime(comment.created_at)
              ] })
            ] }),
            /* @__PURE__ */ jsxs("div", { className: "flex items-center gap-1", children: [
              (currentUserId === comment.user_id || isPublisher) && /* @__PURE__ */ jsx(
                "button",
                {
                  onClick: () => onDelete(comment),
                  className: "text-palette-tan/20 hover:text-palette-red transition-colors p-1",
                  title: t("common.delete"),
                  children: /* @__PURE__ */ jsx(Trash2, { size: 11 })
                }
              ),
              /* @__PURE__ */ jsxs("div", { className: "relative", children: [
                /* @__PURE__ */ jsx(
                  "button",
                  {
                    onClick: () => setShowOptions(!showOptions),
                    className: "text-palette-tan/20 hover:text-palette-maroon transition-colors p-1",
                    children: /* @__PURE__ */ jsx(ShieldAlert, { size: 11 })
                  }
                ),
                showOptions && /* @__PURE__ */ jsxs("div", { className: "absolute right-0 top-full mt-1 bg-white border border-palette-beige shadow-xl rounded-[5px] z-50 py-1 min-w-[120px] animate-in zoom-in-95", children: [
                  /* @__PURE__ */ jsxs(
                    "button",
                    {
                      onClick: () => {
                        onReport(comment);
                        setShowOptions(false);
                      },
                      className: "w-full px-3 py-1.5 text-left text-[10px] font-bold text-palette-tan hover:bg-palette-beige/30 flex items-center gap-2",
                      children: [
                        /* @__PURE__ */ jsx(Flag, { size: 10 }),
                        " ",
                        t("comments.report")
                      ]
                    }
                  ),
                  isPublisher && comment.user_id && /* @__PURE__ */ jsxs(
                    "button",
                    {
                      onClick: () => {
                        onBlock(comment);
                        setShowOptions(false);
                      },
                      className: "w-full px-3 py-1.5 text-left text-[10px] font-bold text-red-500 hover:bg-red-50 flex items-center gap-2",
                      children: [
                        /* @__PURE__ */ jsx(UserMinus, { size: 10 }),
                        " ",
                        t("comments.block_user")
                      ]
                    }
                  )
                ] })
              ] })
            ] })
          ] }),
          /* @__PURE__ */ jsx("p", { className: "text-[12px] text-palette-tan/80 leading-relaxed font-medium", children: comment.content })
        ] }),
        /* @__PURE__ */ jsxs("div", { className: "flex items-center gap-4 mt-1 ml-1", children: [
          /* @__PURE__ */ jsxs(
            "button",
            {
              onClick: () => onLike(comment),
              className: `flex items-center gap-1.5 text-[10px] font-bold transition-colors group ${comment.userLiked ? "text-palette-red" : "text-palette-tan/40 hover:text-palette-red"}`,
              children: [
                /* @__PURE__ */ jsx(Heart, { size: 12, className: `transition-transform group-active:scale-125 ${comment.userLiked ? "fill-palette-red" : ""}` }),
                /* @__PURE__ */ jsx("span", { children: comment.likes_count > 0 ? comment.likes_count : t("comments.like") })
              ]
            }
          ),
          /* @__PURE__ */ jsxs(
            "button",
            {
              onClick: () => onReply(comment),
              className: "flex items-center gap-1.5 text-[10px] font-bold text-palette-tan/40 hover:text-palette-red transition-colors",
              children: [
                /* @__PURE__ */ jsx(Reply, { size: 12, className: "scale-x-[-1]" }),
                /* @__PURE__ */ jsx("span", { children: t("comments.reply") })
              ]
            }
          )
        ] })
      ] })
    ] }),
    comment.replies && comment.replies.length > 0 && /* @__PURE__ */ jsx("div", { className: "space-y-1", children: comment.replies.map((reply) => /* @__PURE__ */ jsx(
      CommentItem,
      {
        comment: reply,
        isReply: true,
        onReply,
        onLike,
        onReport,
        onDelete,
        onBlock,
        isPublisher,
        currentUserId
      },
      reply.id
    )) })
  ] });
};
const CommentSection = ({ postId, publisherId }) => {
  const { showToast } = useToast();
  const { t } = useLanguage();
  const [comments, setComments] = useState([]);
  const [loading, setLoading] = useState(true);
  const [isExpanded, setIsExpanded] = useState(false);
  const [newComment, setNewComment] = useState("");
  const [guestName, setGuestName] = useState("");
  const [guestEmail, setGuestEmail] = useState("");
  const [replyTo, setReplyTo] = useState(null);
  const [user, setUser] = useState(null);
  const [isBlocked, setIsBlocked] = useState(false);
  const [showEmojiPicker, setShowEmojiPicker] = useState(false);
  const emojiPickerRef = useRef(null);
  useEffect(() => {
    checkUser();
    fetchComments();
  }, [postId]);
  const checkUser = async () => {
    const { data: { user: user2 } } = await supabase.auth.getUser();
    setUser(user2);
    if (user2 && publisherId) {
      const { data: block } = await supabase.from("publisher_blocks").select("id").eq("publisher_id", publisherId).eq("blocked_user_id", user2.id).maybeSingle();
      if (block) setIsBlocked(true);
    }
  };
  useEffect(() => {
    const handleClickOutside = (event) => {
      if (emojiPickerRef.current && !emojiPickerRef.current.contains(event.target)) {
        setShowEmojiPicker(false);
      }
    };
    document.addEventListener("mousedown", handleClickOutside);
    return () => document.removeEventListener("mousedown", handleClickOutside);
  }, []);
  const onEmojiClick = (emojiData) => {
    setNewComment((prev) => prev + emojiData.emoji);
  };
  const fetchComments = async () => {
    try {
      setLoading(true);
      const { data, error } = await supabase.from("comments").select(`
          *,
          profiles:user_id (username, avatar_url)
        `).eq("post_id", postId).eq("status", "approved").order("created_at", { ascending: true });
      if (error) throw error;
      let likedIds = [];
      if (user) {
        const { data: likes } = await supabase.from("comment_likes").select("comment_id").eq("user_id", user.id);
        likedIds = likes?.map((l) => String(l.comment_id)) || [];
      }
      const formattedComments = data.map((c) => ({
        ...c,
        id: String(c.id),
        user_name: c.profiles?.username,
        user_avatar: c.profiles?.avatar_url,
        userLiked: likedIds.includes(String(c.id)),
        replies: []
      }));
      const commentMap = /* @__PURE__ */ new Map();
      const rootComments = [];
      formattedComments.forEach((c) => commentMap.set(c.id, c));
      formattedComments.forEach((c) => {
        if (c.parent_id && commentMap.has(String(c.parent_id))) {
          commentMap.get(String(c.parent_id)).replies.push(c);
        } else {
          rootComments.push(c);
        }
      });
      setComments(rootComments);
    } catch (err) {
      console.error("Error fetching comments:", err);
    } finally {
      setLoading(false);
    }
  };
  const handlePostComment = async () => {
    if (isBlocked) {
      showToast(t("comments.blocked_cannot_comment"), "error");
      return;
    }
    if (!newComment.trim()) return;
    if (!user && (!guestName.trim() || !guestEmail.trim())) {
      showToast(t("comments.enter_name_email"), "info");
      return;
    }
    try {
      const numericPostId = typeof postId === "string" ? parseInt(postId, 10) : postId;
      if (isNaN(numericPostId)) {
        throw new Error(t("comments.invalid_post_id"));
      }
      const commentData = {
        post_id: numericPostId,
        content: newComment.trim(),
        parent_id: replyTo?.id ? parseInt(replyTo.id, 10) : null,
        user_id: user?.id || null,
        guest_name: user ? null : guestName.trim(),
        guest_email: user ? null : guestEmail.trim(),
        status: "pending"
      };
      const { error } = await supabase.from("comments").insert([commentData]);
      if (error) throw error;
      showToast(t("comments.submitted_pending"), "success");
      setNewComment("");
      setReplyTo(null);
      if (!user) {
        setGuestName("");
        setGuestEmail("");
      }
    } catch (err) {
      showToast(t("comments.submit_error").replace("{error}", err.message), "error");
    }
  };
  const handleLike = async (comment) => {
    if (!user) {
      showToast(t("auth.login_required_like"), "info");
      return;
    }
    try {
      if (comment.userLiked) {
        await supabase.from("comment_likes").delete().eq("comment_id", comment.id).eq("user_id", user.id);
        await supabase.rpc("decrement_comment_likes", { comment_id: comment.id });
      } else {
        await supabase.from("comment_likes").insert({ comment_id: comment.id, user_id: user.id });
        await supabase.rpc("increment_comment_likes", { comment_id: comment.id });
      }
      fetchComments();
    } catch (err) {
      console.error("Like error:", err);
    }
  };
  const handleReport = async (comment) => {
    const reason = prompt(t("comments.report_prompt"));
    if (!reason) return;
    try {
      const { error } = await supabase.from("comment_reports").insert({
        comment_id: comment.id,
        user_id: user?.id || null,
        guest_email: user ? null : guestEmail,
        reason
      });
      if (error) throw error;
      showToast(t("comments.report_received"), "success");
    } catch (err) {
      showToast(t("common.action_failed"), "error");
    }
  };
  const handleDelete = async (comment) => {
    if (!window.confirm(t("comments.delete_confirm_user"))) return;
    try {
      const { error } = await supabase.from("comments").delete().eq("id", comment.id);
      if (error) throw error;
      showToast(t("comments.deleted_short"), "success");
      fetchComments();
    } catch (err) {
      showToast(t("comments.delete_failed"), "error");
    }
  };
  const handleBlock = async (comment) => {
    if (!comment.user_id || !publisherId) return;
    if (!window.confirm(t("comments.block_confirm"))) return;
    try {
      const { error } = await supabase.from("publisher_blocks").insert({
        publisher_id: publisherId,
        blocked_user_id: comment.user_id
      });
      if (error) throw error;
      showToast(t("comments.block_success"), "success");
    } catch (err) {
      showToast(t("comments.block_failed"), "error");
    }
  };
  const isPublisher = user && publisherId === user.id;
  const visibleComments = isExpanded ? comments : comments.slice(0, 2);
  const hiddenCount = Math.max(0, comments.length - 2);
  return /* @__PURE__ */ jsxs("div", { className: `bg-white/50 px-5 pt-0 pb-4 ${showEmojiPicker ? "relative z-[245]" : ""}`, children: [
    /* @__PURE__ */ jsx("div", { className: "space-y-1", children: loading ? /* @__PURE__ */ jsx("div", { className: "py-10 text-center text-palette-tan/20 text-xs font-bold uppercase tracking-widest animate-pulse", children: t("comments.loading") }) : comments.length === 0 ? /* @__PURE__ */ jsx("div", { className: "py-10 text-center text-palette-tan/20 text-xs font-bold uppercase tracking-widest", children: t("comments.empty_prompt") }) : visibleComments.map((comment) => /* @__PURE__ */ jsx(
      CommentItem,
      {
        comment,
        onReply: setReplyTo,
        onLike: handleLike,
        onReport: handleReport,
        onDelete: handleDelete,
        onBlock: handleBlock,
        isPublisher,
        currentUserId: user?.id
      },
      comment.id
    )) }),
    comments.length > 2 && /* @__PURE__ */ jsxs("div", { className: "relative flex items-center justify-center mt-5 mb-5", children: [
      /* @__PURE__ */ jsx("div", { className: "absolute inset-0 flex items-center", "aria-hidden": "true", children: /* @__PURE__ */ jsx("div", { className: "w-full border-t border-palette-beige/50" }) }),
      /* @__PURE__ */ jsx(
        "button",
        {
          onClick: () => setIsExpanded(!isExpanded),
          className: "relative flex items-center gap-1.5 bg-white border border-palette-beige text-[10px] font-bold text-palette-tan/50 px-4 py-2 rounded-[5px] shadow-sm hover:bg-palette-beige/20 hover:text-palette-red hover:border-palette-red/20 transition-all group z-10",
          children: isExpanded ? /* @__PURE__ */ jsxs(Fragment, { children: [
            /* @__PURE__ */ jsx("span", { children: t("common.show_less") }),
            /* @__PURE__ */ jsx(ChevronUp, { size: 12, className: "group-hover:-translate-y-0.5 transition-transform" })
          ] }) : /* @__PURE__ */ jsxs(Fragment, { children: [
            /* @__PURE__ */ jsxs("span", { children: [
              t("common.show_all"),
              " (",
              hiddenCount,
              ")"
            ] }),
            /* @__PURE__ */ jsx(ChevronDown, { size: 12, className: "group-hover:translate-y-0.5 transition-transform" })
          ] })
        }
      )
    ] }),
    replyTo && /* @__PURE__ */ jsxs("div", { className: "mt-4 flex items-center justify-between bg-palette-beige/20 px-3 py-1.5 rounded-[5px] border border-palette-beige animate-in slide-in-from-bottom-2", children: [
      /* @__PURE__ */ jsxs("span", { className: "text-[10px] font-bold text-palette-tan flex items-center gap-1.5", children: [
        /* @__PURE__ */ jsx(Reply, { size: 10, className: "scale-x-[-1]" }),
        /* @__PURE__ */ jsx("span", { className: "text-palette-maroon", children: replyTo.user_name || replyTo.guest_name }),
        " ",
        t("comments.replying_to_suffix")
      ] }),
      /* @__PURE__ */ jsx("button", { onClick: () => setReplyTo(null), className: "text-palette-tan/40 hover:text-palette-red transition-colors", children: /* @__PURE__ */ jsx(ChevronDown, { size: 14, className: "rotate-45" }) })
    ] }),
    /* @__PURE__ */ jsxs("div", { className: "flex flex-col gap-3 mt-4", children: [
      !user && /* @__PURE__ */ jsxs("div", { className: "grid grid-cols-1 md:grid-cols-2 gap-3 animate-in fade-in slide-in-from-top-1", children: [
        /* @__PURE__ */ jsx(
          "input",
          {
            type: "text",
            placeholder: t("comments.form.name_placeholder"),
            value: guestName,
            onChange: (e) => setGuestName(e.target.value),
            className: "w-full h-10 px-4 rounded-[5px] bg-white border border-palette-beige/60 focus:border-palette-red/40 text-[13px] font-medium text-palette-maroon placeholder:text-palette-tan/30 focus:outline-none focus:ring-4 focus:ring-palette-red/5 transition-all shadow-sm"
          }
        ),
        /* @__PURE__ */ jsx(
          "input",
          {
            type: "email",
            placeholder: t("comments.form.email_placeholder"),
            value: guestEmail,
            onChange: (e) => setGuestEmail(e.target.value),
            className: "w-full h-10 px-4 rounded-[5px] bg-white border border-palette-beige/60 focus:border-palette-red/40 text-[13px] font-medium text-palette-maroon placeholder:text-palette-tan/30 focus:outline-none focus:ring-4 focus:ring-palette-red/5 transition-all shadow-sm"
          }
        )
      ] }),
      /* @__PURE__ */ jsxs("div", { className: "flex gap-3 items-center", children: [
        /* @__PURE__ */ jsx("div", { className: "w-9 h-9 rounded-[5px] bg-palette-beige overflow-hidden flex-shrink-0 border border-palette-beige shadow-sm", children: /* @__PURE__ */ jsx(
          "img",
          {
            src: user?.user_metadata?.avatar_url || `https://ui-avatars.com/api/?name=${user ? "User" : "Guest"}&background=f3f4f6&color=94a3b8`,
            className: "w-full h-full object-cover"
          }
        ) }),
        /* @__PURE__ */ jsxs("div", { className: "flex-1 relative group", children: [
          /* @__PURE__ */ jsx(
            "input",
            {
              type: "text",
              value: newComment,
              onChange: (e) => setNewComment(e.target.value),
              onKeyPress: (e) => e.key === "Enter" && handlePostComment(),
              placeholder: isBlocked ? t("comments.input_blocked") : t("comments.input_placeholder"),
              disabled: isBlocked,
              className: "w-full h-10 pl-4 pr-20 rounded-[5px] bg-white border border-palette-beige/60 focus:border-palette-red/40 text-[13px] font-medium text-palette-maroon placeholder:text-palette-tan/30 focus:outline-none focus:ring-4 focus:ring-palette-red/5 transition-all shadow-sm"
            }
          ),
          /* @__PURE__ */ jsxs("div", { className: "absolute right-1.5 top-1/2 -translate-y-1/2 flex items-center gap-1", children: [
            /* @__PURE__ */ jsxs("div", { className: "relative", ref: emojiPickerRef, children: [
              /* @__PURE__ */ jsx(
                "button",
                {
                  type: "button",
                  onClick: () => setShowEmojiPicker(!showEmojiPicker),
                  disabled: isBlocked,
                  className: "w-7 h-7 flex items-center justify-center text-palette-tan/40 hover:text-palette-maroon transition-all",
                  title: t("comments.add_emoji"),
                  children: /* @__PURE__ */ jsx(Smile, { size: 18 })
                }
              ),
              showEmojiPicker && /* @__PURE__ */ jsx("div", { className: "absolute bottom-full right-0 mb-2 z-[240] shadow-2xl animate-in fade-in zoom-in-95 slide-in-from-bottom-2", children: /* @__PURE__ */ jsx(
                EmojiPicker,
                {
                  onEmojiClick,
                  autoFocusSearch: false,
                  theme: Theme.LIGHT,
                  searchPlaceholder: t("comments.emoji_search_placeholder"),
                  width: 300,
                  height: 400
                }
              ) })
            ] }),
            /* @__PURE__ */ jsx(
              "button",
              {
                onClick: handlePostComment,
                disabled: isBlocked,
                className: "w-7 h-7 flex items-center justify-center bg-palette-beige text-palette-tan/40 rounded-[5px] hover:bg-palette-red hover:text-white transition-all shadow-sm group-focus-within:bg-palette-red group-focus-within:text-white disabled:opacity-50",
                children: /* @__PURE__ */ jsx(Send, { size: 14 })
              }
            )
          ] })
        ] })
      ] })
    ] })
  ] });
};

const RightSidebar = ({ newsData, loading }) => {
  const { t } = useLanguage();
  const trending = [
    { id: "01", title: t("right.trending.01.title"), hits: "128K", category: t("right.trending.01.category"), rising: true },
    { id: "02", title: t("right.trending.02.title"), hits: "85K", category: t("right.trending.02.category"), rising: true },
    { id: "03", title: t("right.trending.03.title"), hits: "64K", category: t("right.trending.03.category"), rising: false },
    { id: "04", title: t("right.trending.04.title"), hits: "42K", category: t("right.trending.04.category"), rising: true }
  ];
  const markets = [
    { symbol: "USDT", name: t("right.markets.usdt_try"), price: "34.42", change: "%0.45", isUp: true, icon: DollarSign, color: "text-emerald-500", bg: "bg-emerald-50" },
    { symbol: "EUR", name: t("right.markets.eur_try"), price: "37.15", change: "%0.12", isUp: true, icon: Euro, color: "text-palette-tan", bg: "bg-palette-beige/50" },
    { symbol: "GA", name: t("right.markets.gold_gram"), price: "2.450", change: "%-0.23", isUp: false, icon: Coins, color: "text-amber-600", bg: "bg-amber-50" },
    { symbol: "BTC", name: t("right.markets.bitcoin"), price: "$64.200", change: "%1.85", isUp: true, icon: Bitcoin, color: "text-orange-500", bg: "bg-orange-50" }
  ];
  const forecast = [
    { day: t("days.mon_short"), icon: CloudSun, temp: "24°" },
    { day: t("days.tue_short"), icon: Sun, temp: "26°" },
    { day: t("days.wed_short"), icon: CloudRain, temp: "21°" },
    { day: t("days.thu_short"), icon: Cloud, temp: "22°" },
    { day: t("days.fri_short"), icon: Sun, temp: "25°" }
  ];
  const suggestions = [
    { name: t("right.suggestions.space_explorer"), handle: "@uzaykasifi", img: "space", bg: "https://images.unsplash.com/photo-1451187580459-43490279c0fa?auto=format&fit=crop&q=80&w=400" },
    { name: t("right.suggestions.gourmet_guide"), handle: "@gurmeist", img: "food", bg: "https://images.unsplash.com/photo-1504674900247-0877df9cc836?auto=format&fit=crop&q=80&w=400" }
  ];
  if (loading) {
    return /* @__PURE__ */ jsx(RightSidebarSkeleton, {});
  }
  return /* @__PURE__ */ jsxs("div", { className: "flex flex-col gap-8 pt-2 pb-10", children: [
    /* @__PURE__ */ jsxs("div", { className: "bg-white rounded-[5px] border border-palette-beige/60 shadow-sm overflow-hidden relative group", children: [
      /* @__PURE__ */ jsxs("div", { className: "p-6 pb-0 flex items-start justify-between", children: [
        /* @__PURE__ */ jsxs("div", { children: [
          /* @__PURE__ */ jsxs("div", { className: "flex items-center gap-1.5 text-palette-tan/40 mb-2", children: [
            /* @__PURE__ */ jsx(MapPin, { size: 12 }),
            /* @__PURE__ */ jsx("span", { className: "text-[10px] font-bold uppercase tracking-[0.2em]", children: t("right.weather") })
          ] }),
          /* @__PURE__ */ jsxs("div", { className: "flex items-center gap-3", children: [
            /* @__PURE__ */ jsx("span", { className: "text-4xl font-[900] text-gray-900 tracking-tighter", children: "24°" }),
            /* @__PURE__ */ jsxs("div", { className: "flex flex-col", children: [
              /* @__PURE__ */ jsx("span", { className: "text-xs font-black text-palette-tan", children: t("right.weather_partly_cloudy") }),
              /* @__PURE__ */ jsx("span", { className: "text-[10px] text-palette-tan/40 font-bold", children: t("right.weather_feels_like_26") })
            ] })
          ] })
        ] }),
        /* @__PURE__ */ jsx("div", { className: "w-12 h-12 bg-orange-50 rounded-[5px] flex items-center justify-center", children: /* @__PURE__ */ jsx(Sun, { size: 28, className: "text-orange-400" }) })
      ] }),
      /* @__PURE__ */ jsx("div", { className: "mt-8 grid grid-cols-5 border-t border-palette-beige/40 bg-palette-beige/5", children: forecast.map((day, idx) => /* @__PURE__ */ jsxs("div", { className: `flex flex-col items-center justify-center py-4 gap-2 ${idx !== forecast.length - 1 ? "border-r border-palette-beige/40" : ""} hover:bg-white transition-colors cursor-default`, children: [
        /* @__PURE__ */ jsx("span", { className: "text-[9px] font-black text-palette-tan/30 uppercase", children: day.day }),
        /* @__PURE__ */ jsx(day.icon, { size: 16, className: "text-palette-tan/60" }),
        /* @__PURE__ */ jsx("span", { className: "text-[11px] font-black text-gray-900", children: day.temp })
      ] }, idx)) })
    ] }),
    /* @__PURE__ */ jsxs("div", { className: "bg-white rounded-[5px] border border-palette-beige/60 shadow-sm overflow-hidden", children: [
      /* @__PURE__ */ jsxs("div", { className: "p-6 pb-2 flex items-center justify-between", children: [
        /* @__PURE__ */ jsxs("div", { className: "flex items-center gap-3", children: [
          /* @__PURE__ */ jsx("div", { className: "w-1.5 h-1.5 bg-palette-red rounded-[5px]" }),
          /* @__PURE__ */ jsx("h3", { className: "font-bold text-gray-900 uppercase tracking-[0.12em] text-[13px]", children: t("right.agenda") })
        ] }),
        /* @__PURE__ */ jsx("span", { className: "text-[9px] font-black text-palette-red bg-palette-red/5 px-2 py-1 rounded-[5px] border border-palette-red/10 animate-pulse", children: t("right.live") })
      ] }),
      /* @__PURE__ */ jsx("div", { className: "flex flex-col p-3 space-y-1", children: trending.map((item, idx) => /* @__PURE__ */ jsxs("div", { className: "group relative flex items-center gap-5 p-4 rounded-[5px] hover:bg-palette-beige/20 transition-all duration-100 cursor-pointer border border-transparent hover:border-palette-beige/50", children: [
        /* @__PURE__ */ jsx("div", { className: "flex flex-col items-center", children: /* @__PURE__ */ jsx("span", { className: "text-2xl font-[900] text-palette-tan/10 group-hover:text-palette-tan/30 transition-colors leading-none italic", children: item.id }) }),
        /* @__PURE__ */ jsxs("div", { className: "flex-1 min-w-0", children: [
          /* @__PURE__ */ jsxs("div", { className: "flex items-center justify-between mb-1", children: [
            /* @__PURE__ */ jsx("span", { className: "text-[8px] font-black text-palette-tan/40 uppercase tracking-[0.2em]", children: item.category }),
            /* @__PURE__ */ jsx("span", { className: "text-[9px] font-bold text-palette-tan/30", children: item.hits })
          ] }),
          /* @__PURE__ */ jsx("h4", { className: "text-sm font-extrabold text-gray-900 leading-snug group-hover:text-palette-red transition-colors line-clamp-2 tracking-tight", children: item.title })
        ] }),
        item.rising && /* @__PURE__ */ jsx("div", { className: "flex-shrink-0 w-8 h-8 rounded-[5px] bg-palette-beige/30 flex items-center justify-center opacity-0 group-hover:opacity-100 transition-all", children: /* @__PURE__ */ jsx(TrendingUp, { size: 14, className: "text-emerald-500" }) })
      ] }, idx)) }),
      /* @__PURE__ */ jsx("button", { className: "w-full py-4 text-[10px] font-black text-palette-tan/40 uppercase tracking-[0.2em] hover:bg-palette-beige/20 hover:text-gray-900 transition-all border-t border-palette-beige/40", children: t("right.explore_all_agenda") })
    ] }),
    /* @__PURE__ */ jsxs("div", { className: "bg-white rounded-[5px] border border-palette-beige/60 shadow-sm overflow-hidden", children: [
      /* @__PURE__ */ jsxs("div", { className: "p-6 pb-2 flex items-center justify-between", children: [
        /* @__PURE__ */ jsxs("div", { className: "flex items-center gap-3", children: [
          /* @__PURE__ */ jsx("div", { className: "w-1.5 h-1.5 bg-palette-tan/20 rounded-[5px]" }),
          /* @__PURE__ */ jsx("h3", { className: "font-bold text-gray-900 uppercase tracking-[0.12em] text-[13px]", children: t("right.markets") })
        ] }),
        /* @__PURE__ */ jsx("button", { className: "text-[10px] font-bold text-palette-tan/40 hover:text-palette-red uppercase tracking-widest transition-colors", children: t("right.all") })
      ] }),
      /* @__PURE__ */ jsx("div", { className: "p-3 space-y-1.5", children: markets.map((m, i) => /* @__PURE__ */ jsxs("div", { className: "flex items-center justify-between p-4 rounded-[5px] hover:bg-palette-beige/10 transition-all border border-transparent hover:border-palette-beige/30 cursor-pointer group", children: [
        /* @__PURE__ */ jsxs("div", { className: "flex items-center gap-4", children: [
          /* @__PURE__ */ jsx("div", { className: `w-10 h-10 rounded-[5px] ${m.bg} ${m.color} flex items-center justify-center shadow-sm border border-black/5`, children: /* @__PURE__ */ jsx(m.icon, { size: 18 }) }),
          /* @__PURE__ */ jsxs("div", { className: "flex flex-col", children: [
            /* @__PURE__ */ jsx("span", { className: "text-[11px] font-black text-gray-900", children: m.symbol }),
            /* @__PURE__ */ jsx("span", { className: "text-[9px] font-bold text-palette-tan/30 uppercase tracking-tighter", children: m.name })
          ] })
        ] }),
        /* @__PURE__ */ jsxs("div", { className: "flex flex-col items-end", children: [
          /* @__PURE__ */ jsx("span", { className: "text-xs font-black text-palette-tan", children: m.price }),
          /* @__PURE__ */ jsxs("span", { className: `text-[9px] font-black flex items-center gap-0.5 mt-0.5 ${m.isUp ? "text-emerald-500" : "text-palette-red"}`, children: [
            m.isUp ? /* @__PURE__ */ jsx(ArrowUpRight, { size: 10, strokeWidth: 3 }) : /* @__PURE__ */ jsx(ArrowDownRight, { size: 10, strokeWidth: 3 }),
            m.change
          ] })
        ] })
      ] }, i)) })
    ] }),
    /* @__PURE__ */ jsxs("div", { children: [
      /* @__PURE__ */ jsxs("div", { className: "flex items-center justify-between px-3 mb-4", children: [
        /* @__PURE__ */ jsxs("div", { className: "flex items-center gap-2", children: [
          /* @__PURE__ */ jsx(Zap, { size: 16, className: "text-palette-red" }),
          /* @__PURE__ */ jsx("h3", { className: "font-bold text-gray-900 uppercase tracking-[0.12em] text-[13px]", children: t("right.discover") })
        ] }),
        /* @__PURE__ */ jsx("button", { className: "text-[10px] font-bold text-palette-tan/40 hover:underline uppercase tracking-widest", children: t("right.all") })
      ] }),
      /* @__PURE__ */ jsx("div", { className: "space-y-4", children: suggestions.map((source, i) => /* @__PURE__ */ jsxs("div", { className: "group bg-white rounded-[5px] border border-palette-beige/60 p-4 shadow-sm hover:shadow-xl hover:border-palette-tan/10 transition-all duration-150 cursor-pointer relative overflow-hidden", children: [
        /* @__PURE__ */ jsxs("div", { className: "absolute top-0 left-0 w-full h-16 bg-palette-beige/10", children: [
          /* @__PURE__ */ jsx("img", { src: source.bg, className: "w-full h-full object-cover opacity-20 group-hover:opacity-40 transition-opacity duration-200" }),
          /* @__PURE__ */ jsx("div", { className: "absolute inset-0 bg-gradient-to-t from-white via-white/40 to-transparent" })
        ] }),
        /* @__PURE__ */ jsxs("div", { className: "relative flex items-center justify-between", children: [
          /* @__PURE__ */ jsxs("div", { className: "flex items-center gap-4", children: [
            /* @__PURE__ */ jsx("div", { className: "w-14 h-14 rounded-[5px] bg-white p-1 shadow-2xl border border-palette-beige relative z-10 group-hover:scale-105 transition-transform duration-150", children: /* @__PURE__ */ jsx("img", { src: `https://picsum.photos/seed/${source.img}/100`, alt: source.name, className: "w-full h-full object-cover rounded-[5px]" }) }),
            /* @__PURE__ */ jsxs("div", { className: "mt-1", children: [
              /* @__PURE__ */ jsxs("div", { className: "flex items-center gap-1.5", children: [
                /* @__PURE__ */ jsx("h5", { className: "text-sm font-black text-gray-900", children: source.name }),
                /* @__PURE__ */ jsx(CheckCircle2, { size: 12, className: "text-palette-tan fill-palette-tan/5" })
              ] }),
              /* @__PURE__ */ jsx("p", { className: "text-[10px] text-palette-tan/40 font-bold uppercase tracking-widest", children: source.handle })
            ] })
          ] }),
          /* @__PURE__ */ jsx("button", { className: "w-10 h-10 bg-palette-tan text-white rounded-[5px] flex items-center justify-center hover:bg-gray-900 transition-all shadow-lg shadow-palette-tan/20 active:scale-90", children: /* @__PURE__ */ jsx(UserPlus, { size: 16, strokeWidth: 2.5 }) })
        ] })
      ] }, i)) })
    ] }),
    /* @__PURE__ */ jsxs("div", { className: "bg-gradient-to-br from-gray-900 to-palette-tan rounded-[5px] p-7 text-white shadow-2xl shadow-palette-tan/30 relative overflow-hidden group", children: [
      /* @__PURE__ */ jsx("div", { className: "absolute top-0 right-0 w-32 h-32 bg-white/10 rounded-[5px] blur-[50px] -translate-y-10 translate-x-10 group-hover:bg-white/20 transition-all duration-700" }),
      /* @__PURE__ */ jsxs("div", { className: "relative z-10", children: [
        /* @__PURE__ */ jsx("div", { className: "w-10 h-10 bg-white/10 rounded-[5px] flex items-center justify-center mb-5 border border-white/10", children: /* @__PURE__ */ jsx(Mail, { size: 20 }) }),
        /* @__PURE__ */ jsx("h4", { className: "font-bold text-xl leading-tight mb-2 tracking-tighter", children: t("right.newsletter_title") }),
        /* @__PURE__ */ jsx("p", { className: "text-[11px] text-white/60 mb-6 font-bold uppercase tracking-widest leading-relaxed", children: t("right.newsletter_desc") }),
        /* @__PURE__ */ jsxs("div", { className: "flex flex-col gap-3", children: [
          /* @__PURE__ */ jsx(
            "input",
            {
              type: "email",
              placeholder: t("common.email_address"),
              className: "w-full bg-white/10 border border-white/20 rounded-[5px] px-5 py-3.5 text-xs text-white placeholder:text-white/30 focus:outline-none focus:bg-white/20 focus:border-white/40 transition-all font-bold"
            }
          ),
          /* @__PURE__ */ jsx("button", { className: "w-full bg-white text-gray-900 py-3.5 rounded-[5px] font-black text-[10px] uppercase tracking-[0.2em] hover:bg-palette-beige transition-all shadow-xl active:scale-95", children: t("right.subscribe") })
        ] })
      ] })
    ] })
  ] });
};
const RightSidebarSkeleton = () => {
  return /* @__PURE__ */ jsxs("div", { className: "flex flex-col gap-8 pt-2 pb-10", children: [
    /* @__PURE__ */ jsxs("div", { className: "bg-white rounded-[5px] border border-palette-beige/60 p-6 space-y-4", children: [
      /* @__PURE__ */ jsx(Skeleton, { className: "w-24 h-3" }),
      /* @__PURE__ */ jsxs("div", { className: "flex items-center gap-4", children: [
        /* @__PURE__ */ jsx(Skeleton, { className: "w-16 h-10" }),
        /* @__PURE__ */ jsx(Skeleton, { className: "w-20 h-6" })
      ] })
    ] }),
    /* @__PURE__ */ jsxs("div", { className: "bg-white rounded-[5px] border border-palette-beige/60 p-6 space-y-4", children: [
      /* @__PURE__ */ jsx(Skeleton, { className: "w-32 h-4" }),
      /* @__PURE__ */ jsx("div", { className: "space-y-4", children: [1, 2, 3, 4].map((i) => /* @__PURE__ */ jsxs("div", { className: "flex gap-4", children: [
        /* @__PURE__ */ jsx(Skeleton, { className: "w-8 h-8" }),
        /* @__PURE__ */ jsxs("div", { className: "flex-1 space-y-2", children: [
          /* @__PURE__ */ jsx(Skeleton, { className: "w-16 h-2" }),
          /* @__PURE__ */ jsx(Skeleton, { className: "w-full h-4" })
        ] })
      ] }, i)) })
    ] }),
    /* @__PURE__ */ jsxs("div", { className: "space-y-4", children: [
      /* @__PURE__ */ jsx(Skeleton, { className: "w-24 h-4 ml-3" }),
      [1, 2].map((i) => /* @__PURE__ */ jsx("div", { className: "bg-white rounded-[5px] border border-palette-beige/60 p-4 space-y-3", children: /* @__PURE__ */ jsxs("div", { className: "flex items-center gap-4", children: [
        /* @__PURE__ */ jsx(Skeleton, { variant: "rectangular", className: "w-14 h-14" }),
        /* @__PURE__ */ jsxs("div", { className: "space-y-2", children: [
          /* @__PURE__ */ jsx(Skeleton, { className: "w-24 h-4" }),
          /* @__PURE__ */ jsx(Skeleton, { className: "w-16 h-3" })
        ] })
      ] }) }, i))
    ] })
  ] });
};

export { AudioCard as A, BeforeAfterCard as B, CommentSection as C, EmbedCard as E, FlipCard as F, GalleryCard as G, PollCard as P, ReviewCard as R, Skeleton as S, VideoCard as V, VSCard as a, ParagraphCard as b, RightSidebar as c };
