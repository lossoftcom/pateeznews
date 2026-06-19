
export enum NewsType {
  VIDEO = 'VIDEO',
  AUDIO = 'AUDIO',
  GALLERY = 'GALLERY',
  EMBED = 'EMBED',
  STANDARD = 'STANDARD',
  POLL = 'POLL',
  QUIZ = 'QUIZ',
  VS = 'VS',
  IMAGE = 'IMAGE',
  FLIP_CARD = 'FLIP_CARD',
  BEFORE_AFTER = 'BEFORE_AFTER',
  REVIEW = 'REVIEW',
  PARAGRAPH = 'PARAGRAPH'
}

export interface PollOption {
  id: string;
  text: string;
  votes: number;
  image?: string;
}

export interface OptimizedImage {
  src: string;
  srcSet?: string;
  sizes?: string;
  width?: number;
  height?: number;
}

export interface NewsItem {
  id: string;
  type: NewsType;
  title: string;
  summary: string;
  content?: string; // Detaylı haber içeriği
  category: string;
  categoryTrail?: string[];
  categoryPath?: string[];
  source: string;
  author: string;
  timestamp: string;
  modifiedAt?: string;
  mediaUrl: string;
  mediaList?: string[];
  thumbnail: string;
  thumbnailAlt?: string;
  mansetImageUrl?: string;
  coverThumbnail?: string;
  optimizedThumbnail?: OptimizedImage;
  optimizedCoverThumbnail?: OptimizedImage;
  likes: number;
  dislikes?: number;
  comments: number;
  shares: number;
  views: number;
  saves?: number;
  options?: PollOption[];
  quizDescription?: string;
  totalVotes?: number;
  isImagePoll?: boolean;
  pollColumns?: 2 | 3;
  videoDuration?: string;
  flipData?: {
    frontImage: string;
    frontTitle: string;
    backImage: string;
    backTitle: string;
    frontDescription?: string;
    backDescription?: string;
    frontLink?: string;
    backLink?: string;
  };
  beforeAfterData?: {
    beforeImage: string;
    afterImage: string;
    beforeLabel: string;
    afterLabel: string;
  };
  reviewData?: {
    productName: string;
    productImage: string;
    score: number;
    pros: string[];
    cons: string[];
    breakdown: { label: string; score: number }[];
    verdict: string;
  };
  paragraphData?: {
    items: string[];
    quoteAuthor?: string;
  };
  items?: any[];
  sourceAvatar?: string;
  publisherHandle?: string;
  publisherBio?: string;
  publisherExpertise?: string;
  isPinned?: boolean;
  isManset?: boolean;
  // User specific interaction states (pre-fetched for speed)
  userLiked?: boolean;
  userSaved?: boolean;
  userDisliked?: boolean;
  publisherId?: string;
  isFollowingPublisher?: boolean;
  // SEO & AI Properties
  seoTitle?: string;
  seoDescription?: string;
  keywords?: string;
  slug?: string;
  factChecked?: boolean;
  schemaType?: string;
  faqData?: { q: string; a: string }[];
}

export interface StoryItem {
  id: string;
  title: string;
  mediaUrl: string;
  mediaType: 'image' | 'video';
  sourceName?: string;
  publisherId?: string;
  createdAt?: string;
  expiresAt?: string;
  isActive: boolean;
  viewCount?: number;
  storyData?: any;
  storyMarkup?: string;
}

// --- NEW ROLE & PERMISSION TYPES ---

export interface Role {
  id: string;
  name: string; // admin, moderator etc.
  label: string; // Yönetici, Moderatör
  description: string;
  color: string;
}

export interface Permission {
  id: string;
  key: string;
  label: string;
  group_name: 'sidebar' | 'system' | 'content';
  description: string;
}

export interface RolePermission {
  role_id: string;
  permission_key: string;
}

// --- NAVIGATION TYPES ---

export interface NavigationMenu {
  id: string;
  code: string;
  name: string;
  description: string;
}

export interface NavigationItem {
  id: string;
  menu_id: string;
  menu_code?: string;
  parent_id: string | null;
  label: string;
  type: 'link' | 'header' | 'dropdown' | 'category' | 'trends' | 'district';
  value: string;
  icon: string;
  image_url?: string;
  order_index: number;
  is_active: boolean;
  language_code?: string;
  children?: NavigationItem[]; // UI için hiyerarşi
}

export interface SiteFont {
  id: number;
  name: string;
  family: string;
  type: 'sans_serif' | 'serif' | 'monospace' | 'cursive' | 'fantasy' | 'system_ui';
  source: 'local' | 'system';
  web_font_path?: string;
  flutter_family?: string;
  fallback_stack?: string;
  font_files?: Record<string, string> | string;
  is_active: boolean;
  sort_order: number;
}

// --- SITE SETTINGS ---
export interface SiteSettings {
  id: string;
  language_code: string;
  site_name: string;
  timezone: string;
  footer_about: string;
  optional_url_button_name: string;
  copyright_text: string;
  logo_url: string;
  footer_logo_url: string;
  dark_logo_url: string;
  email_logo_url: string;
  favicon_url: string;
  home_title?: string;
  meta_description?: string;
  meta_keywords?: string;
  canonical_url?: string;
  og_image_url?: string;
  organization_legal_name?: string;
  organization_phone?: string;
  organization_address?: string;
  contact_phone?: string;
  contact_city?: string;
  contact_address?: string;
  contact_location_url?: string;
  contact_whatsapp_url?: string;
  contact_telegram_url?: string;
  contact_email_info?: string;
  contact_email_support?: string;
  contact_email_news?: string;
  contact_email_ads?: string;
  twitter_username?: string;
  fb_app_id?: string;
  social_whatsapp_url?: string;
  social_telegram_url?: string;
  social_instagram_url?: string;
  social_facebook_url?: string;
  social_x_url?: string;
  social_youtube_url?: string;
  social_tiktok_url?: string;
  social_linkedin_url?: string;
  social_pinterest_url?: string;
  social_discord_url?: string;
  social_auth_google_enabled?: boolean;
  social_auth_apple_enabled?: boolean;
  social_auth_facebook_enabled?: boolean;
  social_auth_x_enabled?: boolean;
  social_auth_redirect_scheme?: string;
  social_auth_redirect_host?: string;
  google_analytics_id?: string;
  google_search_console_code?: string;
  bing_verification_code?: string;
  yandex_verification_code?: string;
  indexnow_key?: string;
  robots_txt?: string;
  header_custom_codes?: string;
  footer_custom_codes?: string;
  // AI Settings
  google_ai_api_key?: string;
  google_ai_model?: string;
  google_ai_active?: boolean;
  // Weather Settings
  weather_enabled?: boolean;
  weather_location_name?: string;
  weather_location_country?: string;
  weather_latitude?: number;
  weather_longitude?: number;
  weather_timezone?: string;
  weather_update_interval_minutes?: number;
  // Market Settings
  market_enabled?: boolean;
  market_provider?: string;
  market_altinapi_key?: string;
  market_altinapi_base_url?: string;
  market_genelpara_base_url?: string;
  market_update_interval_seconds?: number;
  market_currency_symbols?: string;
  market_gold_symbols?: string;
  // Prayer Times Settings
  prayer_enabled?: boolean;
  prayer_diyanet_base_url?: string;
  prayer_location_name?: string;
  prayer_location_country?: string;
  prayer_location_state_id?: number;
  prayer_location_city_id?: number;
  prayer_timezone?: string;
  prayer_refresh_lead_days?: number;
  prayer_cache_days?: number;
  daily_ayah_enabled?: boolean;
  daily_ayah_start_date?: string;
  daily_ayah_quran_api_base_url?: string;
  daily_ayah_quran_api_token?: string;
  // Font Settings
  site_primary_font?: string;
  site_title_font?: string;
  site_content_font?: string;
  site_font_sizes?: Record<string, unknown> | string;
  // Content/Post Settings
  content_post_url_structure?: 'slug' | 'id' | string;
  content_bulk_post_upload_enabled?: boolean;
  content_delete_media_with_post_enabled?: boolean;
  content_audio_download_enabled?: boolean;
  content_comment_system_enabled?: boolean;
  content_comment_approval_enabled?: boolean;
  content_emoji_reactions_enabled?: boolean;
  content_featured_show_news_info?: boolean;
  content_show_post_author?: boolean;
  content_show_post_date?: boolean;
  content_show_post_view_count?: boolean;
  content_require_new_post_approval?: boolean;
  content_require_edited_post_approval?: boolean;
  content_redirect_rss_posts?: boolean;
  content_popular_post_limit?: number;
  content_related_post_limit?: number;
}
