import { dbQuery } from './supabaseDb';
import { readRuntimeEnv } from './runtimeEnv';
import { getPostPathSegment } from '@/utils/postUrl';
import type { SiteSettings } from '@/types';

const INDEXNOW_ENDPOINT = 'https://api.indexnow.org/indexnow';
const INDEXNOW_TIMEOUT_MS = 2500;
const INDEXNOW_KEY_PATTERN = /^[A-Za-z0-9_-]{8,128}$/;

type IndexNowSettings = Pick<SiteSettings, 'language_code' | 'canonical_url' | 'indexnow_key' | 'content_post_url_structure'>;

const cleanKey = (value: unknown) => {
  const key = String(value || '').trim();
  return INDEXNOW_KEY_PATTERN.test(key) ? key : '';
};

export async function getIndexNowKeys() {
  const envKey = cleanKey(readRuntimeEnv('INDEXNOW_KEY'));
  const result = await dbQuery<{
    language_code: string;
    indexnow_key: string | null;
  }>(
    `SELECT language_code, indexnow_key
     FROM public.site_settings
     WHERE NULLIF(TRIM(COALESCE(indexnow_key, '')), '') IS NOT NULL`
  );

  return Array.from(new Set([
    envKey,
    ...result.rows.map((row) => cleanKey(row.indexnow_key)).filter(Boolean),
  ].filter(Boolean)));
}

async function getIndexNowSettings(languageCode?: string): Promise<IndexNowSettings | null> {
  const result = await dbQuery<IndexNowSettings>(
    `SELECT language_code, canonical_url, indexnow_key, content_post_url_structure
     FROM public.site_settings
     WHERE language_code = COALESCE(NULLIF($1, ''), language_code)
     ORDER BY CASE WHEN language_code = $1 THEN 0 ELSE 1 END, language_code ASC
     LIMIT 1`,
    [String(languageCode || '').trim()]
  );
  return result.rows[0] || null;
}

function normalizeBase(value: string | null | undefined, fallbackOrigin: string) {
  try {
    return new URL(String(value || '').trim() || fallbackOrigin);
  } catch {
    return new URL(fallbackOrigin);
  }
}

function withTimeout<T>(promise: Promise<T>, ms: number): Promise<T> {
  let timer: ReturnType<typeof setTimeout> | undefined;
  const timeout = new Promise<never>((_, reject) => {
    timer = setTimeout(() => reject(new Error('IndexNow request timed out')), ms);
  });
  return Promise.race([promise, timeout]).finally(() => {
    if (timer) clearTimeout(timer);
  });
}

export async function submitIndexNowUrls(request: Request, urls: string[], languageCode?: string) {
  const uniqueUrls = Array.from(new Set(urls.map((url) => String(url || '').trim()).filter(Boolean))).slice(0, 10000);
  if (!uniqueUrls.length) return;

  const requestUrl = new URL(request.url);
  const settings = await getIndexNowSettings(languageCode);
  const key = cleanKey(settings?.indexnow_key) || cleanKey(readRuntimeEnv('INDEXNOW_KEY'));
  if (!key) return;

  const baseUrl = normalizeBase(settings?.canonical_url, requestUrl.origin);
  const host = baseUrl.host;
  const keyLocation = new URL(`${key}.txt`, baseUrl).toString();
  const sameHostUrls = uniqueUrls.filter((url) => {
    try {
      return new URL(url).host === host;
    } catch {
      return false;
    }
  });
  if (!sameHostUrls.length) return;

  const response = await withTimeout(fetch(INDEXNOW_ENDPOINT, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json; charset=utf-8' },
    body: JSON.stringify({
      host,
      key,
      keyLocation,
      urlList: sameHostUrls,
    }),
  }), INDEXNOW_TIMEOUT_MS);

  if (![200, 202].includes(response.status)) {
    throw new Error(`IndexNow returned ${response.status}`);
  }
}

export function postUrlForIndexNow(row: any, settings: IndexNowSettings, fallbackOrigin: string) {
  const baseUrl = normalizeBase(settings.canonical_url, fallbackOrigin);
  const pathSegment = getPostPathSegment(row, settings as SiteSettings);
  return pathSegment ? new URL(`haber/${encodeURIComponent(pathSegment)}`, baseUrl).toString() : '';
}

export async function submitIndexNowForPosts(request: Request, rows: any[]) {
  const normalizedRows = rows.filter(Boolean);
  if (!normalizedRows.length) return;

  const byLanguage = new Map<string, any[]>();
  for (const row of normalizedRows) {
    const languageCode = String(row?.language_code || '').trim();
    if (!byLanguage.has(languageCode)) byLanguage.set(languageCode, []);
    byLanguage.get(languageCode)!.push(row);
  }

  for (const [languageCode, languageRows] of byLanguage) {
    const settings = await getIndexNowSettings(languageCode);
    if (!settings) continue;
    const urls = languageRows
      .map((row) => postUrlForIndexNow(row, settings, new URL(request.url).origin))
      .filter(Boolean);
    await submitIndexNowUrls(request, urls, settings.language_code);
  }
}
