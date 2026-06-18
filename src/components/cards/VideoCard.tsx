
import React, { useState, useRef, useEffect } from 'react';
import { NewsType, type NewsItem } from '@/types';
import { formatTime } from '@/utils/helpers';
import RemixIcon from '@/components/ui/RemixIcon';

interface VideoCardProps {
  data: NewsItem;
  layout?: 'default' | 'feed';
}

const youtubeParser = (url: string) => {
  if (!url) return null;
  const regExp = /^.*(youtu.be\/|v\/|u\/\w\/|embed\/|watch\?v=|&v=|shorts\/)([^#&?]*).*/;
  const match = url.match(regExp);
  if (match && match[2].length === 11) {
    const id = match[2];
    const isShorts = url.includes('/shorts/');
    return {
      id,
      embed: `https://www.youtube.com/embed/${id}?enablejsapi=1&autoplay=0&mute=1&controls=0&rel=0&showinfo=0&modestbranding=1&disablekb=1&fs=0&iv_load_policy=3&playsinline=1`,
      thumbnail: `https://img.youtube.com/vi/${id}/maxresdefault.jpg`,
      isShorts
    };
  }
  return null;
};

const VideoCard: React.FC<VideoCardProps> = ({ data, layout = 'default' }) => {
  const [isPlaying, setIsPlaying] = useState(false);
  const [isMuted, setIsMuted] = useState(true);
  const [progress, setProgress] = useState(0);
  const [timeDisplay, setTimeDisplay] = useState(data.videoDuration || "00:00");
  const [isDirectVerticalVideo, setIsDirectVerticalVideo] = useState(false);
  const [directVideoAspectRatio, setDirectVideoAspectRatio] = useState<number | null>(null);

  const videoRef = useRef<HTMLVideoElement>(null);
  const iframeRef = useRef<HTMLIFrameElement>(null);
  const videoContainerRef = useRef<HTMLDivElement>(null);
  const userHasPaused = useRef(false);

  // YouTube state tracking
  const ytDurationRef = useRef<number>(0);
  const ytCurrentTimeRef = useRef<number>(0);
  const ytPlayerReady = useRef<boolean>(false);
  const ytPlayerStateRef = useRef<number>(-1);
  const hasUnmutedOnce = useRef(false);

  const ytInfo = youtubeParser(data.mediaUrl);
  const isYoutube = !!ytInfo;
  const hasDirectVideo = !isYoutube && !!String(data.mediaUrl || '').trim();
  const posterSrc = data.optimizedThumbnail?.src || data.thumbnail;
  const usePendingDirectFeedLayout = layout === 'feed' && hasDirectVideo && directVideoAspectRatio === null;
  const useFeedTallLayout = layout === 'feed' && (ytInfo?.isShorts || isDirectVerticalVideo || usePendingDirectFeedLayout);
  const feedVerticalStyle: React.CSSProperties | undefined = useFeedTallLayout
    ? { height: 500, maxHeight: 500 }
    : undefined;
  const directFeedVideoStyle: React.CSSProperties | undefined = useFeedTallLayout
    ? { height: 500, width: directVideoAspectRatio ? Math.round(500 * directVideoAspectRatio) : 281.25, maxWidth: '100%' }
    : undefined;

  const sendYoutubeCommand = (func: string, args: any = "") => {
    if (iframeRef.current && iframeRef.current.contentWindow) {
      iframeRef.current.contentWindow.postMessage(
        JSON.stringify({ event: "command", func, args }),
        "*"
      );
    }
  };

  // YouTube Listener Kaydı - iframe yüklendikten sonra çağrılacak
  const initYoutubeListeners = () => {
    if (iframeRef.current && iframeRef.current.contentWindow) {
      // YouTube Player'a event listener kaydı yap
      iframeRef.current.contentWindow.postMessage(
        JSON.stringify({ event: "listening" }),
        "*"
      );

      // iframe yüklendi, şimdi görünürlük kontrolü yap ve videoyu başlat
      setTimeout(() => {
        if (iframeRef.current && iframeRef.current.contentWindow) {
          // Duration bilgisini al
          iframeRef.current.contentWindow.postMessage(
            JSON.stringify({ event: "command", func: "getDuration" }),
            "*"
          );

          // Video tamamen görünürse otomatik başlat
          if (videoContainerRef.current && !userHasPaused.current) {
            const rect = videoContainerRef.current.getBoundingClientRect();
            // Navbar yüksekliği hesaba katılıyor (72px)
            const navbarHeight = 72;
            const isFullyVisible =
              rect.top >= navbarHeight &&
              rect.left >= 0 &&
              rect.bottom <= (window.innerHeight || document.documentElement.clientHeight) &&
              rect.right <= (window.innerWidth || document.documentElement.clientWidth);

            if (isFullyVisible) {
              // Video başlamadan önce duration'ı kontrol et ve timeDisplay'i güncelle
              if (ytDurationRef.current > 0) {
                setTimeDisplay(formatTime(ytDurationRef.current));
              } else if (data.videoDuration) {
                // data.videoDuration'dan parse et
                let parsedDuration = 0;
                const numeric = Number(data.videoDuration);
                if (!isNaN(numeric) && numeric > 0 && !String(data.videoDuration).includes(':')) {
                  parsedDuration = numeric;
                } else if (typeof data.videoDuration === 'string' && data.videoDuration.includes(':')) {
                  const parts = data.videoDuration.split(':').map(Number);
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

  // Robust Duration Parsing from data.videoDuration
  useEffect(() => {
    let duration = 0;
    if (data.videoDuration) {
      // 1. Try parsing as pure number (seconds)
      const numeric = Number(data.videoDuration);
      if (!isNaN(numeric) && numeric > 0 && !data.videoDuration.includes(':')) {
        duration = numeric;
      }
      // 2. Parse MM:SS or HH:MM:SS
      else if (typeof data.videoDuration === 'string' && data.videoDuration.includes(':')) {
        const parts = data.videoDuration.split(':').map(Number);
        if (parts.length === 2) duration = parts[0] * 60 + parts[1];
        else if (parts.length === 3) duration = parts[0] * 3600 + parts[1] * 60 + parts[2];
      }
    }

    if (duration > 0) {
      ytDurationRef.current = duration;
      // If stopped/initial, show total time immediately
      if (!isPlaying && progress === 0) {
        setTimeDisplay(formatTime(duration));
      }
    }
  }, [data.videoDuration, isPlaying, progress]);

  // Normal video için sayfa açılışında görünürlük kontrolü
  useEffect(() => {
    if (isYoutube) return; // YouTube için ayrı kontrol var

    const checkAndPlayVideo = () => {
      if (videoRef.current && videoContainerRef.current && !userHasPaused.current) {
        const rect = videoContainerRef.current.getBoundingClientRect();
        // Navbar yüksekliği hesaba katılıyor (72px)
        const navbarHeight = 72;
        const isFullyVisible =
          rect.top >= navbarHeight &&
          rect.left >= 0 &&
          rect.bottom <= (window.innerHeight || document.documentElement.clientHeight) &&
          rect.right <= (window.innerWidth || document.documentElement.clientWidth);

        if (isFullyVisible && videoRef.current.paused) {
          videoRef.current.muted = true;
          videoRef.current.play()
            .then(() => { setIsPlaying(true); setIsMuted(true); })
            .catch(() => setIsPlaying(false));
        }
      }
    };

    // Video yüklendikten sonra kontrol et
    const timer = setTimeout(checkAndPlayVideo, 50);
    return () => clearTimeout(timer);
  }, [isYoutube]);

  useEffect(() => {
    setIsDirectVerticalVideo(false);
    setDirectVideoAspectRatio(null);
  }, [data.mediaUrl]);

  useEffect(() => {
    if (layout !== 'feed' || !hasDirectVideo) return;
    videoRef.current?.load();
  }, [data.mediaUrl, hasDirectVideo, layout]);

  // YouTube Message Listener
  useEffect(() => {
    if (!isYoutube) return;

    const handleMessage = (event: MessageEvent) => {
      // Allow youtube.com subdomains
      if (!event.origin.includes('youtube.com')) return;

      let msg;
      try {
        msg = typeof event.data === 'string' ? JSON.parse(event.data) : event.data;
      } catch (e) {
        return;
      }

      if (!msg) return;

      // Player hazır olduğunda listener başlat
      if (msg.event === 'onReady' || (msg.event === 'initialDelivery')) {
        ytPlayerReady.current = true;
      }

      // Info update'leri işle
      if (msg.event === 'infoDelivery' && msg.info) {
        const info = msg.info;

        // Player durumunu kaydet (1 = oynatılıyor, 2 = duraklatıldı)
        if (typeof info.playerState !== 'undefined') {
          ytPlayerStateRef.current = info.playerState;
        }

        // Duration bilgisini al
        if (info.duration) {
          const d = Number(info.duration);
          if (!isNaN(d) && d > 0) {
            ytDurationRef.current = d;
          }
        }

        // Current time bilgisini al ve UI'ı güncelle
        if (typeof info.currentTime !== 'undefined') {
          const c = Number(info.currentTime);
          if (!isNaN(c) && c >= 0) {
            ytCurrentTimeRef.current = c;
            ytLastUpdateTime.current = Date.now();

            const dur = ytDurationRef.current;
            if (dur > 0) {
              setProgress((c / dur) * 100);
              setTimeDisplay(formatTime(Math.max(0, dur - c)));
            }
          }
        }
      }

      // Eski format desteği (bazı YouTube embed'leri için)
      if (msg.info && !msg.event) {
        const info = msg.info;

        if (info.duration) {
          const d = Number(info.duration);
          if (!isNaN(d) && d > 0) ytDurationRef.current = d;
        }

        if (typeof info.currentTime !== 'undefined') {
          const c = Number(info.currentTime);
          if (!isNaN(c) && c >= 0) {
            ytCurrentTimeRef.current = c;
            ytLastUpdateTime.current = Date.now();

            const dur = ytDurationRef.current;
            if (dur > 0) {
              setProgress((c / dur) * 100);
              setTimeDisplay(formatTime(Math.max(0, dur - c)));
            }
          }
        }
      }
    };

    window.addEventListener('message', handleMessage);
    return () => window.removeEventListener('message', handleMessage);
  }, [isYoutube]);

  // Timer interval for smooth playback display
  // YouTube'dan gelen gerçek currentTime TEK doğru kaynaktır.
  // Interval sadece YouTube'dan güncel bilgi ister ve ara kareleri pürüzsüz gösterir.
  const ytLastUpdateTime = useRef<number>(0); // Son YouTube güncellemesinin yerel zaman damgası

  useEffect(() => {
    if (!isYoutube || !isPlaying) return;

    const interval = setInterval(() => {
      // YouTube'dan güncel bilgileri talep et
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

      const dur = ytDurationRef.current;
      if (dur <= 0) return;

      // YouTube'dan son gelen gerçek currentTime'a, geçen süreyi ekleyerek pürüzsüz tahmin yap
      const now = Date.now();
      const elapsed = ytLastUpdateTime.current > 0
        ? (now - ytLastUpdateTime.current) / 1000
        : 0;
      const estimatedCur = Math.min(ytCurrentTimeRef.current + elapsed, dur);

      // Progress %
      setProgress((estimatedCur / dur) * 100);

      // Countdown (geriye doğru)
      const remaining = Math.max(0, dur - estimatedCur);
      setTimeDisplay(formatTime(remaining));
    }, 250);

    return () => clearInterval(interval);
  }, [isYoutube, isPlaying]);

  // Scroll Observer - Manuel görünürlük kontrolü (navbar hesaba katılıyor)
  useEffect(() => {
    const NAVBAR_HEIGHT = 72; // Navbar yüksekliği

    const checkVisibility = () => {
      if (!videoContainerRef.current) return;

      const rect = videoContainerRef.current.getBoundingClientRect();
      const windowHeight = window.innerHeight || document.documentElement.clientHeight;
      const windowWidth = window.innerWidth || document.documentElement.clientWidth;

      // Video tamamen görünür mü? (navbar altında ve ekran içinde)
      const isFullyVisible =
        rect.top >= NAVBAR_HEIGHT &&
        rect.left >= 0 &&
        rect.bottom <= windowHeight &&
        rect.right <= windowWidth;

      if (isFullyVisible) {
        // Video tamamen görünür - oynat
        if (!userHasPaused.current && !isPlaying) {
          if (isYoutube) {
            // Video başlamadan önce duration'ı kontrol et ve timeDisplay'i güncelle
            if (ytDurationRef.current > 0) {
              setTimeDisplay(formatTime(ytDurationRef.current));
            } else if (data.videoDuration) {
              // data.videoDuration'dan parse et
              let parsedDuration = 0;
              const numeric = Number(data.videoDuration);
              if (!isNaN(numeric) && numeric > 0 && !String(data.videoDuration).includes(':')) {
                parsedDuration = numeric;
              } else if (typeof data.videoDuration === 'string' && data.videoDuration.includes(':')) {
                const parts = data.videoDuration.split(':').map(Number);
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
            videoRef.current.play()
              .then(() => { setIsPlaying(true); setIsMuted(true); })
              .catch(() => setIsPlaying(false));
          }
        }
      } else {
        // Video görünür değil - durdur
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

    // Scroll ve resize event'lerini dinle
    window.addEventListener('scroll', checkVisibility, { passive: true });
    window.addEventListener('resize', checkVisibility, { passive: true });

    // İlk yüklemede kontrol et
    checkVisibility();

    return () => {
      window.removeEventListener('scroll', checkVisibility);
      window.removeEventListener('resize', checkVisibility);
    };
  }, [isYoutube, isPlaying]);

  // Auto-unmute: 2 saniye sonra sesi açmayı dene.
  // Tarayıcı izin verirse ses açılır. Vermezse videoyu durdurmadan sessiz moda geri döner.
  // SADECE ilk seferde çalışır, diğer özellikleri ETKİLEMEZ.
  // Tüm video tipleri için çalışır: YouTube Normal, YouTube Shorts, Yerel Video.
  useEffect(() => {
    if (isPlaying && !hasUnmutedOnce.current) {
      hasUnmutedOnce.current = true;

      const timer = setTimeout(() => {
        if (userHasPaused.current) return;

        if (isYoutube) {
          sendYoutubeCommand("unMute");
          sendYoutubeCommand("playVideo");
          setIsMuted(false);

          // 300ms sonra kontrol et: tarayıcı videoyu durdurdu mu?
          setTimeout(() => {
            if (ytPlayerStateRef.current === 2 && !userHasPaused.current) {
              // Tarayıcı engelledi → sessiz moda geri dön, videoyu devam ettir
              sendYoutubeCommand("mute");
              sendYoutubeCommand("playVideo");
              setIsMuted(true);
            }
          }, 300);
        } else if (videoRef.current) {
          videoRef.current.muted = false;
          setIsMuted(false);

          // Eğer tarayıcı durdurduysa anında geri al
          const checkAndRecover = () => {
            if (videoRef.current?.paused && !userHasPaused.current) {
              videoRef.current.muted = true;
              setIsMuted(true);
              videoRef.current.play().catch(() => {});
            }
          };
          setTimeout(checkAndRecover, 100);
          setTimeout(checkAndRecover, 300);
        }
      }, 2000);

      return () => clearTimeout(timer);
    }
  }, [isPlaying, isYoutube]);

  const toggleMute = (e: React.MouseEvent) => {
    e.preventDefault();
    e.stopPropagation();
    if (isYoutube) {
      sendYoutubeCommand(isMuted ? "unMute" : "mute");
      setIsMuted(!isMuted);
    } else if (videoRef.current) {
      videoRef.current.muted = !isMuted;
      setIsMuted(!isMuted);
    }
  };

  const togglePlay = (e: React.MouseEvent) => {
    e.preventDefault();
    e.stopPropagation();
    if (isYoutube) {
      if (isPlaying) { sendYoutubeCommand("pauseVideo"); setIsPlaying(false); userHasPaused.current = true; }
      else { sendYoutubeCommand("playVideo"); setIsPlaying(true); userHasPaused.current = false; }
    } else if (videoRef.current) {
      if (isPlaying) { videoRef.current.pause(); setIsPlaying(false); userHasPaused.current = true; }
      else { videoRef.current.play(); setIsPlaying(true); userHasPaused.current = false; }
    }
  };

  const handleTimeUpdate = () => {
    if (videoRef.current) {
      const dur = videoRef.current.duration;
      const cur = videoRef.current.currentTime;
      if (dur > 0 && !isNaN(dur) && dur !== Infinity) {
        setProgress((cur / dur) * 100);
        setTimeDisplay(formatTime(Math.max(0, dur - cur)));
      }
    }
  };

  const handleLoadedMetadata = (event: React.SyntheticEvent<HTMLVideoElement>) => {
    const video = event.currentTarget;
    const aspectRatio = video.videoHeight > 0 ? video.videoWidth / video.videoHeight : null;
    setTimeDisplay(formatTime(video.duration));
    setDirectVideoAspectRatio(aspectRatio);
    setIsDirectVerticalVideo(!!aspectRatio && aspectRatio < 1);
  };

  return (
    <div className="mt-1 space-y-3 overflow-hidden">
      <div className="px-1 mb-3">
        <div
          className="news-subtitle-font rich-text-content text-gray-600/80 text-[16px] leading-relaxed font-medium text-left [&>p]:mb-0"
          dangerouslySetInnerHTML={{ __html: data.summary }}
        />
      </div>

      <div
        ref={videoContainerRef}
        onClick={togglePlay}
        className={`video-interact-area relative w-full bg-black shadow-lg border border-gray-100 group flex justify-center items-center overflow-hidden cursor-pointer rounded-[5px] ${useFeedTallLayout ? 'h-[500px]' : ''}`}
        style={feedVerticalStyle}
      >
        {isYoutube ? (
          <div
            className={`mx-auto ${useFeedTallLayout ? 'h-[500px] w-auto max-w-full aspect-[9/16]' : `w-full aspect-video ${ytInfo.isShorts ? 'max-w-[300px] aspect-[9/16]' : ''}`}`}
            style={useFeedTallLayout ? { height: 500, width: 281.25, maxWidth: '100%' } : undefined}
          >
            <iframe
              ref={iframeRef}
              src={ytInfo.embed}
              className={`w-full h-full pointer-events-none ${useFeedTallLayout ? '' : 'scale-105'}`}
              allow="autoplay; encrypted-media; fullscreen"
              title="YouTube video player"
              onLoad={initYoutubeListeners}
            />
          </div>
        ) : hasDirectVideo ? (
          <video
            ref={videoRef}
            src={data.mediaUrl}
            poster={posterSrc || undefined}
            className={useFeedTallLayout ? 'h-[500px] flex-none object-contain mx-auto' : 'w-auto h-auto max-h-[450px] object-contain mx-auto'}
            style={directFeedVideoStyle}
            muted={true}
            playsInline
            loop
            preload="metadata"
            onLoadedMetadata={handleLoadedMetadata}
            onTimeUpdate={handleTimeUpdate}
          />
        ) : posterSrc ? (
          <img
            src={posterSrc}
            alt={data.thumbnailAlt || data.seoTitle || data.title}
            className="w-auto h-auto max-h-[450px] object-contain mx-auto"
          />
        ) : null}

        {/* Custom Poster Overlay for YouTube when not playing to hide YouTube UI */}
        {isYoutube && !isPlaying && (data.optimizedThumbnail?.src || data.thumbnail) && (
          <div
            className="absolute inset-0 z-[15] bg-cover bg-center bg-no-repeat transition-opacity duration-300 pointer-events-none"
            style={{ backgroundImage: `url(${data.optimizedThumbnail?.src || data.thumbnail})` }}
          />
        )}

        {/* Timer */}
        <div className="absolute bottom-4 right-4 bg-black/60 backdrop-blur-md px-2.5 py-1 rounded-[5px] border border-white/10 flex items-center gap-1.5 z-20 mb-1.5 pointer-events-none">
          <RemixIcon name="ri-time-line" size={12} className="text-white/80" />
          <span className="text-xs font-bold text-white tracking-wide font-mono min-w-[35px] text-left">{timeDisplay}</span>
        </div>

        {/* Overlay Controls */}
        <div className={`absolute inset-0 z-20 bg-black/10 transition-opacity duration-300 ${isPlaying ? 'opacity-0 group-hover:opacity-100' : 'opacity-100'}`}>
          <button
            onClick={toggleMute}
            className="absolute top-4 right-4 w-9 h-9 flex items-center justify-center rounded-[5px] bg-black/50 backdrop-blur-md border border-white/20 text-white z-20"
          >
            <RemixIcon name={isMuted ? 'ri-volume-mute-line' : 'ri-volume-up-line'} size={16} />
          </button>



          <div className="absolute inset-0 flex items-center justify-center p-8 pointer-events-none">
            <div className={`
              w-14 h-14 rounded-full bg-black/20 backdrop-blur-md border-2 border-white/40 
              flex items-center justify-center transition-all duration-300
              group-hover:scale-110 group-hover:bg-white/10 group-hover:border-white
            `}>
              <RemixIcon name={isPlaying ? 'ri-pause-fill' : 'ri-play-fill'} size={28} className="text-white" />
            </div>
          </div>
        </div>

        {/* Progress Bar - Clickable for seeking */}
        <div
          className="absolute bottom-0 left-0 w-full h-1.5 bg-gray-800/30 z-30 cursor-pointer group/progress"
          onClick={(e) => {
            e.preventDefault();
            e.stopPropagation();
            const rect = e.currentTarget.getBoundingClientRect();
            const clickX = e.clientX - rect.left;
            const pct = Math.max(0, Math.min(1, clickX / rect.width));

            if (isYoutube) {
              const dur = ytDurationRef.current;
              if (dur > 0) {
                const seekTo = pct * dur;
                ytCurrentTimeRef.current = seekTo;
                setProgress(pct * 100);
                setTimeDisplay(formatTime(Math.max(0, dur - seekTo)));
                sendYoutubeCommand("seekTo", [seekTo, true]);
              }
            } else if (videoRef.current) {
              const dur = videoRef.current.duration;
              if (dur > 0 && !isNaN(dur) && dur !== Infinity) {
                videoRef.current.currentTime = pct * dur;
              }
            }
          }}
        >
          <div className="h-full bg-palette-red transition-all duration-100 ease-linear" style={{ width: `${progress}%` }} />
        </div>
      </div>
    </div>
  );
};

export default VideoCard;
