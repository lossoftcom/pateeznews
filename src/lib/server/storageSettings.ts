import { dbQuery } from './supabaseDb';
import type { StorageType } from './supabaseStorage';

export type ActiveStorage =
  | 'localStorage'
  | 'awsS3'
  | 'cloudflareR2'
  | 'backblazeB2'
  | 'bunnyNet'
  | 'googleDrive';

export type RemoteStorageProvider =
  | 'awsS3'
  | 'cloudflareR2'
  | 'backblazeB2'
  | 'bunnyNet'
  | 'googleDrive';

export interface StorageSettings {
  activeStorage: ActiveStorage;
  selectedProvider: RemoteStorageProvider;
  providers: Record<string, Record<string, string>>;
}

export interface LocalMediaRecord {
  id: string;
  type: StorageType;
  value: string;
  path: string;
  size: number;
  contentType: string;
  src: string;
  publicSrc: string;
  thumb?: string;
}

const STORAGE_SETTINGS_KEY = 'storage.settings';
const LOCAL_MEDIA_KEY_PREFIX = 'storage.local.media.';
const PERSISTENT_EXPIRES_AT = '2099-12-31T23:59:59.000Z';

const ACTIVE_STORAGE_VALUES = new Set<ActiveStorage>([
  'localStorage',
  'awsS3',
  'cloudflareR2',
  'backblazeB2',
  'bunnyNet',
  'googleDrive',
]);

const REMOTE_PROVIDER_VALUES = new Set<RemoteStorageProvider>([
  'awsS3',
  'cloudflareR2',
  'backblazeB2',
  'bunnyNet',
  'googleDrive',
]);

const DEFAULT_STORAGE_SETTINGS: StorageSettings = {
  activeStorage: 'localStorage',
  selectedProvider: 'awsS3',
  providers: {},
};

function normalizeActiveStorage(value: unknown): ActiveStorage {
  const raw = String(value || '').trim();
  const normalized = raw
    .replace(/^storageSettings\.option\./, '')
    .replace(/^local$/, 'localStorage');
  return ACTIVE_STORAGE_VALUES.has(normalized as ActiveStorage)
    ? normalized as ActiveStorage
    : DEFAULT_STORAGE_SETTINGS.activeStorage;
}

function normalizeRemoteProvider(value: unknown): RemoteStorageProvider {
  const raw = String(value || '').trim().replace(/^storageSettings\.provider\./, '');
  return REMOTE_PROVIDER_VALUES.has(raw as RemoteStorageProvider)
    ? raw as RemoteStorageProvider
    : DEFAULT_STORAGE_SETTINGS.selectedProvider;
}

function normalizeProviders(value: unknown): Record<string, Record<string, string>> {
  if (!value || typeof value !== 'object' || Array.isArray(value)) return {};
  const providers: Record<string, Record<string, string>> = {};
  for (const [provider, rawSettings] of Object.entries(value)) {
    if (!REMOTE_PROVIDER_VALUES.has(provider as RemoteStorageProvider)) continue;
    if (!rawSettings || typeof rawSettings !== 'object' || Array.isArray(rawSettings)) continue;
    providers[provider] = Object.fromEntries(
      Object.entries(rawSettings)
        .map(([key, rawValue]) => [key, String(rawValue ?? '').trim()])
        .filter(([key]) => /^[A-Za-z][A-Za-z0-9]*$/.test(key))
    );
  }
  return providers;
}

export function normalizeStorageSettings(value: unknown): StorageSettings {
  const input = value && typeof value === 'object' && !Array.isArray(value)
    ? value as Record<string, unknown>
    : {};
  return {
    activeStorage: normalizeActiveStorage(input.activeStorage),
    selectedProvider: normalizeRemoteProvider(input.selectedProvider),
    providers: normalizeProviders(input.providers),
  };
}

export function isLocalStorageActive(settings: StorageSettings) {
  return settings.activeStorage === 'localStorage';
}

export async function getStorageSettings(): Promise<StorageSettings> {
  const result = await dbQuery<{ payload: unknown }>(
    `SELECT payload
     FROM public.app_cache
     WHERE key = $1
       AND expires_at > now()
     LIMIT 1`,
    [STORAGE_SETTINGS_KEY]
  ).catch(() => ({ rows: [] as Array<{ payload: unknown }> }));

  return normalizeStorageSettings(result.rows[0]?.payload || DEFAULT_STORAGE_SETTINGS);
}

export async function saveStorageSettings(input: unknown) {
  const settings = normalizeStorageSettings(input);
  await dbQuery(
    `INSERT INTO public.app_cache (key, payload, expires_at, updated_at)
     VALUES ($1, $2::jsonb, $3::timestamptz, now())
     ON CONFLICT (key) DO UPDATE SET
       payload = EXCLUDED.payload,
       expires_at = EXCLUDED.expires_at,
       updated_at = now()`,
    [STORAGE_SETTINGS_KEY, JSON.stringify(settings), PERSISTENT_EXPIRES_AT]
  );
  return settings;
}

function localMediaKey(type: StorageType, id: string) {
  return `${LOCAL_MEDIA_KEY_PREFIX}${type}/${id}`;
}

export async function recordLocalMediaFile(record: LocalMediaRecord) {
  const payload = {
    provider: 'local',
    ...record,
    updatedAt: new Date().toISOString(),
  };
  await dbQuery(
    `INSERT INTO public.app_cache (key, payload, expires_at, updated_at)
     VALUES ($1, $2::jsonb, $3::timestamptz, now())
     ON CONFLICT (key) DO UPDATE SET
       payload = EXCLUDED.payload,
       expires_at = EXCLUDED.expires_at,
       updated_at = now()`,
    [localMediaKey(record.type, record.id), JSON.stringify(payload), PERSISTENT_EXPIRES_AT]
  ).catch((error) => {
    console.warn('Local media DB index skipped:', error?.message || error);
  });
}

export async function renameLocalMediaRecord(record: LocalMediaRecord & { oldId: string }) {
  const oldKey = localMediaKey(record.type, record.oldId);
  const newKey = localMediaKey(record.type, record.id);
  const existing = await dbQuery<{ payload: Record<string, unknown> | null }>(
    `SELECT payload
     FROM public.app_cache
     WHERE key = $1
     LIMIT 1`,
    [oldKey]
  ).catch(() => ({ rows: [] as Array<{ payload: Record<string, unknown> | null }> }));

  const payload = {
    ...(existing.rows[0]?.payload || {}),
    provider: 'local',
    id: record.id,
    type: record.type,
    value: record.value,
    path: record.path,
    size: record.size,
    contentType: record.contentType,
    src: record.src,
    publicSrc: record.publicSrc,
    thumb: record.thumb,
    updatedAt: new Date().toISOString(),
  };

  await dbQuery(
    `DELETE FROM public.app_cache WHERE key = $1`,
    [oldKey]
  ).catch((error) => {
    console.warn('Local media old DB index cleanup skipped:', error?.message || error);
  });

  await dbQuery(
    `INSERT INTO public.app_cache (key, payload, expires_at, updated_at)
     VALUES ($1, $2::jsonb, $3::timestamptz, now())
     ON CONFLICT (key) DO UPDATE SET
       payload = EXCLUDED.payload,
       expires_at = EXCLUDED.expires_at,
       updated_at = now()`,
    [newKey, JSON.stringify(payload), PERSISTENT_EXPIRES_AT]
  ).catch((error) => {
    console.warn('Local media DB index rename skipped:', error?.message || error);
  });
}

export async function deleteLocalMediaRecords(type: StorageType, ids: string[]) {
  const keys = ids.map((id) => localMediaKey(type, id));
  if (!keys.length) return;
  await dbQuery(
    `DELETE FROM public.app_cache WHERE key = ANY($1::text[])`,
    [keys]
  ).catch((error) => {
    console.warn('Local media DB index cleanup skipped:', error?.message || error);
  });
}
