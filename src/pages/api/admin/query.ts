import type { APIRoute } from 'astro';
import { adminError, adminJson, requireAdminRequest } from '@/lib/server/adminAuth';
import { executeQuerySpec, executeRpc, type QuerySpec } from '@/lib/server/supabaseQuery';
import { submitIndexNowForPosts } from '@/lib/server/indexNow';
import { invalidateDataCache, invalidateSiteSettingsCache } from '@/services/dataService';
import { invalidateServerDataCache, invalidateServerSiteSettingsCache } from '@/services/dataService.server';

type QueryMethod = QuerySpec['method'];

interface AccessRule {
  select: string;
  mutate: string;
}

const IDENTIFIER_PATTERN = /^[A-Za-z_][A-Za-z0-9_]*$/;
const CONTENT: AccessRule = { select: 'posts_access', mutate: 'manage_content' };
const STORIES: AccessRule = { select: 'stories_access', mutate: 'manage_stories' };
const PAGES: AccessRule = { select: 'pages_access', mutate: 'manage_pages' };
const SUBSCRIBERS: AccessRule = { select: 'subscribers_access', mutate: 'manage_subscribers' };
const COMMENTS: AccessRule = { select: 'comments_manage', mutate: 'comments_manage' };
const NAVIGATION: AccessRule = { select: 'navigation_access', mutate: 'manage_navigation' };
const SETTINGS: AccessRule = { select: 'view_settings', mutate: 'settings_access' };
const USERS: AccessRule = { select: 'users_access', mutate: 'manage_users' };
const ROLES: AccessRule = { select: 'roles_access', mutate: 'manage_roles' };
const LANGUAGES: AccessRule = { select: 'view_languages', mutate: 'view_languages' };

const TABLE_RULES: Record<string, AccessRule> = {
  admin_comment_details: COMMENTS,
  ai_ready_formats: SETTINGS,
  app_cache: SETTINGS,
  comments: COMMENTS,
  language_translations: LANGUAGES,
  languages: LANGUAGES,
  navigation_items: NAVIGATION,
  navigation_menus: NAVIGATION,
  newsletter_subscribers: SUBSCRIBERS,
  pages: PAGES,
  permissions: ROLES,
  posts: CONTENT,
  profiles: USERS,
  role_permissions: ROLES,
  roles: ROLES,
  site_fonts: SETTINGS,
  site_settings: SETTINGS,
  stories: STORIES,
};

const RPC_RULES: Record<string, string> = {
  get_admin_comment_stats: 'comments_manage',
};

const TABLE_COLUMNS: Record<string, Set<string>> = Object.fromEntries(
  Object.entries({
    admin_comment_details: [
      'id', 'post_id', 'user_id', 'guest_name', 'guest_email', 'parent_id',
      'content', 'status', 'is_pinned', 'likes_count', 'created_at',
      'updated_at', 'post_title', 'user_name', 'user_avatar',
      'replies_count', 'reports_count', 'content_search', 'meta_search',
    ],
    ai_ready_formats: [
      'id', 'title', 'prompt', 'language_code', 'is_active', 'created_at',
      'updated_at',
    ],
    app_cache: ['key', 'payload', 'expires_at', 'updated_at'],
    comments: [
      'id', 'post_id', 'user_id', 'parent_id', 'content', 'status',
      'is_pinned', 'likes_count', 'created_at', 'updated_at', 'guest_name',
      'guest_email', 'post_title', 'user_name',
    ],
    language_translations: ['language_code', 'key', 'value', 'updated_at'],
    languages: [
      'code', 'name', 'direction', 'status', 'flag_code', 'is_default',
      'created_at', 'updated_at',
    ],
    navigation_items: [
      'id', 'menu_id', 'parent_id', 'label', 'type', 'value', 'icon',
      'image_url', 'order_index', 'is_active', 'created_at', 'language_code',
    ],
    navigation_menus: ['id', 'code', 'name', 'description', 'created_at'],
    newsletter_subscribers: [
      'id', 'email', 'full_name', 'phone', 'ip_address', 'city', 'status',
      'language_code', 'source', 'created_at', 'updated_at', 'admin_search_text',
    ],
    pages: [
      'id', 'title', 'slug', 'language_code', 'category_id', 'category',
      'page_group', 'page_type', 'status', 'location', 'parent_page_id',
      'show_title', 'show_breadcrumb', 'show_sidebar', 'registered_only',
      'menu_order', 'content_delta', 'content_plain', 'meta_title',
      'meta_keywords', 'meta_description', 'canonical_url', 'created_at',
      'updated_at', 'admin_search_text',
    ],
    permissions: ['id', 'key', 'label', 'group_name', 'description', 'created_at'],
    posts: [
      'id', 'created_at', 'updated_at', 'publisher_id', 'title', 'summary',
      'content', 'category', 'type', 'thumbnail_url', 'thumbnail_alt',
      'media_url', 'likes_count', 'dislikes_count', 'comments_count',
      'shares_count', 'views_count', 'saves_count', 'card_data', 'slug',
      'items', 'status', 'seo_title', 'seo_description', 'keywords',
      'language_code', 'published_at', 'is_pinned', 'show_in_manset',
      'fact_checked', 'schema_type', 'faq_data', 'deleted_at', 'deleted_by',
      'deleted_from_status',
    ],
    profiles: [
      'id', 'username', 'full_name', 'avatar_url', 'cover_url', 'updated_at', 'role',
      'slug', 'about_me', 'social_links', 'balance', 'pageviews', 'status',
      'reward_system', 'phone', 'expertise', 'foundation_date', 'website',
      'address', 'city', 'meta_title', 'meta_keywords', 'meta_description',
      'canonical_url', 'email', 'created_at', 'show_email', 'rss_feeds',
      'auth_provider', 'auth_providers',
    ],
    role_permissions: ['role_id', 'permission_key'],
    roles: ['id', 'name', 'label', 'description', 'color', 'created_at'],
    site_fonts: [
      'id', 'name', 'family', 'type', 'source', 'web_font_path',
      'flutter_family', 'fallback_stack', 'font_files', 'is_active',
      'sort_order', 'created_at', 'updated_at',
    ],
    site_settings: [
      'id', 'language_code', 'site_name', 'timezone', 'footer_about',
      'optional_url_button_name', 'copyright_text', 'logo_url',
      'footer_logo_url', 'dark_logo_url', 'email_logo_url', 'favicon_url',
      'home_title', 'meta_description', 'meta_keywords', 'canonical_url',
      'og_image_url', 'google_analytics_id', 'google_search_console_code',
      'bing_verification_code', 'yandex_verification_code', 'indexnow_key',
      'twitter_username', 'fb_app_id',
      'social_whatsapp_url', 'social_telegram_url', 'social_instagram_url',
      'social_facebook_url', 'social_x_url', 'social_youtube_url',
      'social_tiktok_url', 'social_linkedin_url', 'social_pinterest_url',
      'social_discord_url',
      'social_auth_google_enabled', 'social_auth_apple_enabled',
      'social_auth_facebook_enabled', 'social_auth_x_enabled',
      'social_auth_redirect_scheme', 'social_auth_redirect_host',
      'organization_legal_name', 'organization_phone', 'organization_address',
      'contact_phone', 'contact_city', 'contact_address',
      'contact_location_url', 'contact_whatsapp_url', 'contact_telegram_url',
      'contact_email_info', 'contact_email_support', 'contact_email_news',
      'contact_email_ads',
      'robots_txt', 'header_custom_codes', 'footer_custom_codes',
      'site_primary_font', 'site_title_font', 'site_content_font',
      'site_font_sizes',
      'content_show_featured_section', 'content_comment_system_enabled',
      'content_comment_approval_enabled', 'content_emoji_reactions_enabled',
      'content_home_page_size',
      'content_featured_source', 'content_featured_sorting',
      'content_featured_limit',
      'content_featured_show_news_info',
      'content_enabled_post_formats', 'content_upload_image_format',
      'content_upload_allowed_extensions', 'content_upload_max_image_mb',
      'content_upload_max_video_mb', 'content_upload_max_audio_mb',
      'content_upload_max_file_mb',
      'content_post_url_structure', 'content_bulk_post_upload_enabled',
      'content_delete_media_with_post_enabled',
      'content_audio_download_enabled', 'content_show_post_author',
      'content_show_post_date', 'content_show_post_view_count',
      'content_require_new_post_approval',
      'content_require_edited_post_approval', 'content_redirect_rss_posts',
      'content_popular_post_limit', 'content_related_post_limit',
      'content_trash_auto_delete_enabled',
      'content_trash_auto_delete_days', 'content_trash_auto_delete_scope',
      'google_ai_api_key', 'google_ai_model', 'google_ai_active',
      'weather_enabled', 'weather_location_name', 'weather_location_country',
      'weather_latitude', 'weather_longitude', 'weather_timezone',
      'weather_update_interval_minutes',
      'market_enabled', 'market_provider', 'market_altinapi_key',
      'market_altinapi_base_url', 'market_genelpara_base_url',
      'market_update_interval_seconds', 'market_currency_symbols',
      'market_gold_symbols',
      'prayer_enabled', 'prayer_diyanet_base_url',
      'prayer_location_name', 'prayer_location_country',
      'prayer_location_state_id', 'prayer_location_city_id',
      'prayer_timezone', 'prayer_refresh_lead_days',
      'prayer_cache_days', 'daily_ayah_enabled',
      'daily_ayah_start_date', 'daily_ayah_quran_api_base_url',
      'daily_ayah_quran_api_token', 'created_at', 'updated_at',
    ],
    stories: [
      'id', 'created_at', 'publisher_id', 'title', 'media_url', 'media_type',
      'source_name', 'expires_at', 'is_active', 'view_count', 'story_data',
      'story_markup',
    ],
  }).map(([table, columns]) => [table, new Set(columns)])
);

function assertIdentifier(value: string, context: string) {
  if (!IDENTIFIER_PATTERN.test(value)) {
    throw Object.assign(new Error(`Unsafe ${context}: ${value}`), { status: 400 });
  }
}

function assertColumnAllowed(table: string, column: string, context: string) {
  assertIdentifier(column, context);
  if (!TABLE_COLUMNS[table]?.has(column)) {
    throw Object.assign(new Error(`Admin query column is not allowed: ${table}.${column}`), { status: 403 });
  }
}

function validateSelect(spec: QuerySpec) {
  if (spec.select == null) return;
  const select = String(spec.select || '').trim();
  if (!select || select === '*') {
    throw Object.assign(new Error('Admin query must request explicit columns'), { status: 400 });
  }
  for (const rawColumn of select.split(',')) {
    const column = rawColumn.trim();
    if (!column) continue;
    assertColumnAllowed(spec.table, column, 'select column');
  }
}

function validateFilters(spec: QuerySpec) {
  for (const filter of spec.filters || []) {
    if (filter.type === 'comparison' || filter.type === 'not') {
      assertColumnAllowed(spec.table, filter.column, 'filter column');
    }
    if (filter.type === 'or') {
      for (const item of String(filter.value || '').split(',')) {
        const column = item.trim().split('.')[0];
        if (column) assertColumnAllowed(spec.table, column, 'or filter column');
      }
    }
  }
}

function validateOrders(spec: QuerySpec) {
  for (const order of spec.orders || []) {
    assertColumnAllowed(spec.table, order.column, 'order column');
  }
}

function validateMutationValues(spec: QuerySpec) {
  if (!['insert', 'update', 'upsert'].includes(String(spec.method))) return;
  const rows = Array.isArray(spec.values) ? spec.values : [spec.values];
  for (const row of rows) {
    if (!row || typeof row !== 'object' || Array.isArray(row)) continue;
    for (const column of Object.keys(row)) {
      assertColumnAllowed(spec.table, column, 'mutation column');
    }
  }
}

function validateOptions(spec: QuerySpec) {
  const onConflict = spec.options?.onConflict;
  if (typeof onConflict === 'string') {
    for (const column of onConflict.split(',').map((value) => value.trim()).filter(Boolean)) {
      assertColumnAllowed(spec.table, column, 'conflict column');
    }
  }
}

function validateSpec(spec: QuerySpec) {
  if (spec.schema && spec.schema !== 'public') {
    throw Object.assign(new Error('Admin query schema is not allowed'), { status: 403 });
  }
  if (!TABLE_RULES[spec.table]) {
    throw Object.assign(new Error(`Admin query table is not allowed: ${spec.table}`), { status: 403 });
  }
  if (!['select', 'insert', 'update', 'delete', 'upsert'].includes(String(spec.method))) {
    throw Object.assign(new Error(`Unsupported admin query method: ${String(spec.method)}`), { status: 400 });
  }
  if (['update', 'delete'].includes(String(spec.method)) && !(spec.filters || []).length) {
    throw Object.assign(new Error('Admin update/delete requires at least one filter'), { status: 400 });
  }
  if (typeof spec.limit === 'number' && spec.limit > 500) {
    throw Object.assign(new Error('Admin query limit exceeds 500 rows'), { status: 400 });
  }
  if (spec.range && spec.range.to - spec.range.from + 1 > 500) {
    throw Object.assign(new Error('Admin query range exceeds 500 rows'), { status: 400 });
  }

  validateSelect(spec);
  validateFilters(spec);
  validateOrders(spec);
  validateMutationValues(spec);
  validateOptions(spec);
}

function permissionForSpec(spec: QuerySpec) {
  const table = String(spec?.table || '').trim();
  const rule = TABLE_RULES[table];
  if (!rule) {
    throw Object.assign(new Error(`Admin query table is not allowed: ${table}`), { status: 403 });
  }

  const method = String(spec?.method || '') as QueryMethod;
  return method === 'select' ? rule.select : rule.mutate;
}

function permissionForRpc(name: string) {
  const permission = RPC_RULES[String(name || '').trim()];
  if (!permission) {
    throw Object.assign(new Error(`Admin RPC is not allowed: ${name}`), { status: 403 });
  }
  return permission;
}

export const POST: APIRoute = async ({ request }) => {
  try {
    const body = await request.json();
    if (body?.kind !== 'rpc') validateSpec(body as QuerySpec);
    const permission = body?.kind === 'rpc'
      ? permissionForRpc(body.name)
      : permissionForSpec(body as QuerySpec);

    await requireAdminRequest(request, permission);

    const result = body?.kind === 'rpc'
      ? await executeRpc(body.name, body.args || {})
      : await executeQuerySpec(body);

    if (
      body?.kind !== 'rpc' &&
      !result.error &&
      body?.table === 'site_settings' &&
      ['insert', 'update', 'upsert', 'delete'].includes(String(body?.method))
    ) {
      const values = Array.isArray(body.values) ? body.values[0] : body.values;
      const languageCode = values?.language_code
        || body.filters?.find((filter: any) => filter?.column === 'language_code')?.value;
      invalidateSiteSettingsCache(languageCode ? String(languageCode) : undefined);
      invalidateServerSiteSettingsCache(languageCode ? String(languageCode) : undefined);
    }

    if (
      body?.kind !== 'rpc' &&
      !result.error &&
      body?.table === 'site_fonts' &&
      ['insert', 'update', 'upsert', 'delete'].includes(String(body?.method))
    ) {
      invalidateSiteSettingsCache();
      invalidateServerSiteSettingsCache();
    }

    if (
      body?.kind !== 'rpc' &&
      !result.error &&
      body?.table === 'navigation_items' &&
      ['insert', 'update', 'upsert', 'delete'].includes(String(body?.method))
    ) {
      invalidateDataCache((key) => key.startsWith('nav_'));
      invalidateServerDataCache((key) => key.startsWith('nav_'));
    }

    if (
      body?.kind !== 'rpc' &&
      !result.error &&
      body?.table === 'posts' &&
      ['insert', 'update', 'upsert', 'delete'].includes(String(body?.method))
    ) {
      invalidateDataCache((key) => key.startsWith('news_'));
      invalidateServerDataCache((key) => key.startsWith('news_') || key.startsWith('post_') || key.startsWith('category_page_'));
      const rows = Array.isArray(result.data) ? result.data : [result.data].filter(Boolean);
      const shouldSubmitIndexNow = rows.some((row: any) => String(row?.status || '').trim() === 'published' || String(row?.status || '').trim() === 'trash');
      if (shouldSubmitIndexNow) {
        try {
          await submitIndexNowForPosts(request, rows);
        } catch (error) {
          console.warn('IndexNow submission failed:', error instanceof Error ? error.message : error);
        }
      }
    }

    if (
      body?.kind !== 'rpc' &&
      !result.error &&
      body?.table === 'comments' &&
      ['insert', 'update', 'upsert', 'delete'].includes(String(body?.method))
    ) {
      invalidateDataCache((key) => key.startsWith('news_'));
      invalidateServerDataCache((key) => key.startsWith('news_') || key.startsWith('post_') || key.startsWith('category_page_'));
    }

    return adminJson(result, result.error ? 400 : 200);
  } catch (error) {
    return adminError(error);
  }
};
