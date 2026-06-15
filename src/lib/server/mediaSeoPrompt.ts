import { transliterateTurkish } from '../mediaSeoText';
import { dbQuery } from './supabaseDb';

export const DEFAULT_MEDIA_SEO_SYSTEM_PROMPT = `
Sen, PateezNews CMS için medya SEO uzmanısın.
Görevin haberlerde kullanılan kapak görseli, görsel blok, video, ses ve dosya medyalarını
Google Images, Yandex Images, Google News, Discover ve yapay zeka tarayıcıları için
doğal, güvenli ve haberle birebir ilişkili şekilde adlandırmaya yardımcı olmaktır.

Genel kurallar:
- Kaynak metinde, haber bağlamında veya görselde kanıtı olmayan kişi, kurum, mekan, tarih ya da olay uydurma.
- Mevcut dosya adındaki ChatGPT, image, foto, screenshot, WhatsApp, tarih-saat ve rastgele sayı parçalarını anlamlı bilgi sayma.
- Dosya adı istenirse sadece küçük ASCII harf, rakam ve tire içeren kısa SEO kökü üret; uzantı yazma.
- Alt text istenirse erişilebilirlik dostu, doğal, tek cümlelik Türkçe açıklama üret.
- Anahtar kelime doldurma, clickbait, abartı ve teknik ifade kullanma.
- Çıktı istenen JSON şemasına birebir uysun; açıklama, markdown veya kod bloğu ekleme.
`.trim();

type MediaSeoPromptRow = {
    title: string | null;
    prompt: string | null;
};

const normalizePromptTitle = (value: unknown) => transliterateTurkish(String(value || ''))
    .toLowerCase()
    .replace(/\s+/g, ' ')
    .trim();

const isMediaSeoPromptTitle = (title: unknown) => {
    const normalized = normalizePromptTitle(title);
    return normalized.includes('medya seo') ||
        normalized.includes('media seo') ||
        normalized.includes('ai medya') ||
        normalized.includes('yapay zeka medya');
};

const selectMediaSeoPrompt = (rows: MediaSeoPromptRow[]) => {
    const exact = rows.find((row) => isMediaSeoPromptTitle(row.title) && String(row.prompt || '').trim());
    return String(exact?.prompt || '').trim();
};

export const fetchMediaSeoSystemPrompt = async (languageCode: string) => {
    const code = String(languageCode || 'tr').trim() || 'tr';

    try {
        const localized = await dbQuery<MediaSeoPromptRow>(
            `SELECT title, prompt
             FROM public.ai_ready_formats
             WHERE language_code = $1
               AND COALESCE(is_active, true) = true
             ORDER BY created_at DESC
             LIMIT 50`,
            [code],
        );
        const localizedPrompt = selectMediaSeoPrompt(localized.rows);
        if (localizedPrompt) return localizedPrompt;

        const fallback = await dbQuery<MediaSeoPromptRow>(
            `SELECT title, prompt
             FROM public.ai_ready_formats
             WHERE COALESCE(is_active, true) = true
             ORDER BY CASE WHEN language_code = 'tr' THEN 0 ELSE 1 END,
                      created_at DESC
             LIMIT 50`,
        );
        const fallbackPrompt = selectMediaSeoPrompt(fallback.rows);
        if (fallbackPrompt) return fallbackPrompt;
    } catch (error) {
        console.warn('Media SEO prompt fallback used:', (error as Error)?.message || error);
    }

    return DEFAULT_MEDIA_SEO_SYSTEM_PROMPT;
};
