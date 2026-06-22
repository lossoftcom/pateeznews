import { readRuntimeEnv } from './runtimeEnv';

const CLOUDFLARE_API_BASE = 'https://api.cloudflare.com/client/v4';
const MAX_PURGE_FILES_PER_REQUEST = 30;

type CloudflarePurgeResponse = {
  success?: boolean;
  errors?: Array<{ message?: string }>;
};

function firstRuntimeEnv(names: string[]) {
  for (const name of names) {
    const value = readRuntimeEnv(name).trim();
    if (value) return value;
  }
  return '';
}

function cloudflarePurgeConfig() {
  const zoneId = firstRuntimeEnv(['CLOUDFLARE_ZONE_ID', 'CF_ZONE_ID']);
  const token = firstRuntimeEnv([
    'CLOUDFLARE_CACHE_PURGE_TOKEN',
    'CLOUDFLARE_API_TOKEN',
    'CF_API_TOKEN',
  ]);
  return zoneId && token ? { zoneId, token } : null;
}

function normalizePurgeUrl(value: string) {
  try {
    const url = new URL(value);
    if (url.protocol !== 'http:' && url.protocol !== 'https:') return '';
    url.hash = '';
    return url.toString();
  } catch {
    return '';
  }
}

function chunks<T>(items: T[], size: number) {
  const result: T[][] = [];
  for (let index = 0; index < items.length; index += size) {
    result.push(items.slice(index, index + size));
  }
  return result;
}

export async function purgeCloudflareCacheFiles(values: Iterable<string>) {
  const config = cloudflarePurgeConfig();
  if (!config) return;

  const files = Array.from(
    new Set(Array.from(values).map(normalizePurgeUrl).filter(Boolean)),
  );
  if (!files.length) return;

  for (const batch of chunks(files, MAX_PURGE_FILES_PER_REQUEST)) {
    try {
      const response = await fetch(
        `${CLOUDFLARE_API_BASE}/zones/${encodeURIComponent(config.zoneId)}/purge_cache`,
        {
          method: 'POST',
          headers: {
            Authorization: `Bearer ${config.token}`,
            'Content-Type': 'application/json',
          },
          body: JSON.stringify({ files: batch }),
        },
      );
      const body = await response.json().catch(() => null) as CloudflarePurgeResponse | null;
      if (!response.ok || body?.success === false) {
        const details = body?.errors?.map((error) => error.message).filter(Boolean).join('; ');
        console.warn(
          'Cloudflare cache purge skipped:',
          details || `HTTP ${response.status}`,
        );
      }
    } catch (error) {
      console.warn(
        'Cloudflare cache purge skipped:',
        error instanceof Error ? error.message : error,
      );
    }
  }
}
