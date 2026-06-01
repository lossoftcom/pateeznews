import type { APIRoute } from 'astro';
import { adminError, adminJson, requireAdminRequest } from '@/lib/server/adminAuth';
import { dbQuery } from '@/lib/server/supabaseDb';

const normalizeLanguageCode = (value: unknown) => {
  const code = String(value || 'tr').trim().toLowerCase().replace(/_/g, '-');
  return code || 'tr';
};

export const POST: APIRoute = async ({ request }) => {
  try {
    await requireAdminRequest(request, 'view_settings');
    const body = await request.json().catch(() => ({}));
    const languageCode = normalizeLanguageCode(body?.languageCode || body?.lang);

    const [settingsResult, fontsResult] = await Promise.all([
      dbQuery(
        `SELECT language_code, site_primary_font, site_title_font, site_content_font, site_font_sizes
         FROM public.site_settings
         WHERE language_code = $1
         LIMIT 1`,
        [languageCode]
      ),
      dbQuery(
        `SELECT id, name, family, type, source, web_font_path, flutter_family,
                fallback_stack, font_files, is_active, sort_order
         FROM public.site_fonts
         WHERE is_active = true
         ORDER BY sort_order DESC, id DESC`
      ),
    ]);

    return adminJson({
      data: {
        settings: settingsResult.rows[0] || null,
        fonts: fontsResult.rows || [],
      },
      error: null,
    });
  } catch (error) {
    return adminError(error);
  }
};
