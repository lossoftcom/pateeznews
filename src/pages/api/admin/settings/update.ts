import type { APIRoute } from 'astro';
import { adminError, adminJson, requireAdminRequest } from '@/lib/server/adminAuth';
import { dbQuery } from '@/lib/server/supabaseDb';
import { invalidateSiteSettingsCache } from '@/services/dataService';
import { invalidateServerSiteSettingsCache } from '@/services/dataService.server';

const ALLOWED_COLUMNS = new Set([
  'site_name',
  'timezone',
  'footer_about',
  'optional_url_button_name',
  'copyright_text',
  'logo_url',
  'footer_logo_url',
  'dark_logo_url',
  'email_logo_url',
  'favicon_url',
  'home_title',
  'meta_description',
  'meta_keywords',
  'canonical_url',
  'og_image_url',
  'google_analytics_id',
  'google_search_console_code',
  'bing_verification_code',
  'twitter_username',
  'fb_app_id',
  'organization_legal_name',
  'organization_phone',
  'organization_address',
  'robots_txt',
  'header_custom_codes',
  'footer_custom_codes',
  'site_primary_font',
  'site_title_font',
  'site_content_font',
  'site_font_sizes',
  'content_show_featured_section',
  'content_comment_system_enabled',
  'content_comment_approval_enabled',
  'content_emoji_reactions_enabled',
  'content_home_page_size',
  'content_featured_source',
  'content_featured_sorting',
  'content_featured_duration_days',
  'content_featured_limit',
  'content_enabled_post_formats',
  'content_upload_image_format',
  'content_upload_allowed_extensions',
  'content_upload_max_image_mb',
  'content_upload_max_video_mb',
  'content_upload_max_audio_mb',
  'content_upload_max_file_mb',
  'content_post_url_structure',
  'content_bulk_post_upload_enabled',
  'content_delete_media_with_post_enabled',
  'content_audio_download_enabled',
  'content_show_post_author',
  'content_show_post_date',
  'content_show_post_view_count',
  'content_require_new_post_approval',
  'content_require_edited_post_approval',
  'content_redirect_rss_posts',
  'content_popular_post_limit',
  'content_related_post_limit',
  'content_trash_auto_delete_enabled',
  'content_trash_auto_delete_days',
  'content_trash_auto_delete_scope',
  'google_ai_api_key',
  'google_ai_model',
  'google_ai_active',
  'weather_enabled',
  'weather_location_name',
  'weather_location_country',
  'weather_latitude',
  'weather_longitude',
  'weather_timezone',
  'weather_update_interval_minutes',
  'market_enabled',
  'market_provider',
  'market_altinapi_key',
  'market_altinapi_base_url',
  'market_genelpara_base_url',
  'market_update_interval_seconds',
  'market_currency_symbols',
  'market_gold_symbols',
  'prayer_enabled',
  'prayer_diyanet_base_url',
  'prayer_location_name',
  'prayer_location_country',
  'prayer_location_state_id',
  'prayer_location_city_id',
  'prayer_timezone',
  'prayer_refresh_lead_days',
  'prayer_cache_days',
  'daily_ayah_enabled',
  'daily_ayah_start_date',
  'daily_ayah_quran_api_base_url',
  'daily_ayah_quran_api_token',
]);

const JSON_COLUMNS = new Set([
  'site_font_sizes',
  'content_enabled_post_formats',
  'content_upload_allowed_extensions',
]);

function quoteIdent(identifier: string) {
  if (!/^[A-Za-z_][A-Za-z0-9_]*$/.test(identifier)) throw new Error(`Unsafe settings column: ${identifier}`);
  return `"${identifier}"`;
}

export const POST: APIRoute = async ({ request }) => {
  try {
    await requireAdminRequest(request, 'settings_access');
    const body = await request.json();
    const languageCode = String(body?.language_code || body?.languageCode || 'tr').trim() || 'tr';
    const values = body?.values && typeof body.values === 'object' ? body.values : {};
    const entries = Object.entries(values).filter(([key]) => ALLOWED_COLUMNS.has(key));
    if (!entries.length) return adminJson({ data: null, error: { message: 'No valid settings values provided' } }, 400);

    const columns = ['language_code', ...entries.map(([key]) => key), 'updated_at'];
    const placeholders = ['$1', ...entries.map((_, index) => `$${index + 2}`), 'now()'];
    const updateSql = entries
      .map(([key], index) => `${quoteIdent(key)} = $${index + 2}`)
      .concat('updated_at = now()')
      .join(', ');
    const params = [
      languageCode,
      ...entries.map(([key, value]) =>
        JSON_COLUMNS.has(key) ? JSON.stringify(value) : value
      ),
    ];

    const result = await dbQuery(
      `INSERT INTO public.site_settings (${columns.map(quoteIdent).join(', ')})
       VALUES (${placeholders.join(', ')})
       ON CONFLICT (language_code) DO UPDATE SET ${updateSql}
       RETURNING *`,
      params
    );

    invalidateSiteSettingsCache(languageCode);
    invalidateServerSiteSettingsCache(languageCode);

    return adminJson({ data: result.rows[0] || null, error: null });
  } catch (error) {
    return adminError(error);
  }
};
