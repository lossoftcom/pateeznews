import type {
  PublicAdCreative,
  PublicAdCreativeType,
  PublicAdPlatform,
  PublicAdSettings,
  PublicAdSlot,
} from '@/types';
import { dbQuery } from './supabaseDb';

const ADS_SETTINGS_KEY = 'ads.settings';
const CACHE_TTL_MS = 30_000;

type SettingsCache = {
  value: PublicAdSettings;
  expiresAt: number;
};

let cachedSettings: SettingsCache | null = null;

const EMPTY_SETTINGS: PublicAdSettings = {
  masterEnabled: false,
  adsenseConnected: false,
  adsensePublisherId: '',
  localEnabled: false,
  slots: [],
};

const asRecord = (value: unknown): Record<string, unknown> | null => {
  if (!value || typeof value !== 'object' || Array.isArray(value)) return null;
  return value as Record<string, unknown>;
};

const asString = (value: unknown) => String(value || '').trim();

const asBool = (value: unknown, fallback: boolean) => (
  typeof value === 'boolean' ? value : fallback
);

const asInt = (value: unknown, fallback = 0) => {
  const numeric = Number(value);
  if (!Number.isFinite(numeric)) return fallback;
  return Math.max(0, Math.round(numeric));
};

const asWeight = (value: unknown) => {
  const numeric = Number(value);
  if (!Number.isFinite(numeric)) return 1;
  return Math.max(1, Math.min(100, Math.round(numeric)));
};

const normalizePlatform = (value: unknown): PublicAdPlatform => (
  asString(value) === 'mobile' ? 'mobile' : 'web'
);

const normalizeCreativeType = (value: unknown): PublicAdCreativeType => {
  const type = asString(value);
  if (type === 'adsense' || type === 'html') return type;
  return 'image';
};

const sanitizeCreative = (
  rawValue: unknown,
  settings: PublicAdSettings,
  slot: Pick<PublicAdSlot, 'width' | 'height' | 'responsive'>,
): PublicAdCreative | null => {
  const raw = asRecord(rawValue);
  if (!raw || raw.active === false) return null;

  const type = normalizeCreativeType(raw.type);
  const width = asInt(raw.width, slot.width);
  const height = asInt(raw.height, slot.height);
  const responsive = asBool(raw.responsive, slot.responsive);
  const base = {
    id: asString(raw.id) || `ad_${type}`,
    name: asString(raw.name) || 'Reklam',
    type,
    width,
    height,
    responsive,
    weight: asWeight(raw.weight),
  };

  if (type === 'adsense') {
    const adsenseSlotId = asString(raw.adsenseSlotId);
    if (!settings.adsenseConnected || !settings.adsensePublisherId || !adsenseSlotId) {
      return null;
    }
    return {
      ...base,
      adsenseSlotId,
      publisherId: settings.adsensePublisherId,
    };
  }

  if (!settings.localEnabled) return null;

  if (type === 'html') {
    const htmlCode = asString(raw.htmlCode);
    if (!htmlCode) return null;
    return {
      ...base,
      htmlCode,
      linkUrl: asString(raw.linkUrl) || undefined,
    };
  }

  const imageUrl = asString(raw.imageUrl);
  if (!imageUrl) return null;
  return {
    ...base,
    imageUrl,
    linkUrl: asString(raw.linkUrl) || undefined,
  };
};

const sanitizeSettings = (payload: unknown): PublicAdSettings => {
  const raw = asRecord(payload);
  if (!raw) return EMPTY_SETTINGS;

  const settings: PublicAdSettings = {
    masterEnabled: raw.masterEnabled !== false,
    adsenseConnected: raw.adsenseConnected === true,
    adsensePublisherId: asString(raw.adsensePublisherId),
    localEnabled: raw.localEnabled !== false,
    slots: [],
  };

  if (!settings.masterEnabled) return settings;

  const rawSlots = Array.isArray(raw.slots) ? raw.slots : [];
  settings.slots = rawSlots
    .map((rawSlot): PublicAdSlot | null => {
      const slotRecord = asRecord(rawSlot);
      if (!slotRecord || slotRecord.active === false) return null;

      const slotBase = {
        id: asString(slotRecord.id) || 'slot',
        key: asString(slotRecord.key),
        name: asString(slotRecord.name) || 'Reklam Alanı',
        description: asString(slotRecord.description),
        platform: normalizePlatform(slotRecord.platform),
        width: asInt(slotRecord.width),
        height: asInt(slotRecord.height),
        responsive: slotRecord.responsive === true,
        fullscreen: slotRecord.fullscreen === true,
      };
      if (!slotBase.key) return null;

      const creatives = (Array.isArray(slotRecord.creatives) ? slotRecord.creatives : [])
        .map((creative) => sanitizeCreative(creative, settings, slotBase))
        .filter((creative): creative is PublicAdCreative => Boolean(creative));

      if (creatives.length === 0) return null;
      return { ...slotBase, creatives };
    })
    .filter((slot): slot is PublicAdSlot => Boolean(slot));

  return settings;
};

export async function getPublicAdSettings(platform?: PublicAdPlatform): Promise<PublicAdSettings> {
  const now = Date.now();
  if (cachedSettings && cachedSettings.expiresAt > now) {
    return filterByPlatform(cachedSettings.value, platform);
  }

  try {
    const result = await dbQuery<{ payload: unknown }>(
      `SELECT payload
       FROM public.app_cache
       WHERE key = $1
         AND expires_at > now()
       LIMIT 1`,
      [ADS_SETTINGS_KEY],
    );
    const value = sanitizeSettings(result.rows[0]?.payload);
    cachedSettings = { value, expiresAt: now + CACHE_TTL_MS };
    return filterByPlatform(value, platform);
  } catch (error) {
    console.error('Public ad settings load failed:', error);
    return EMPTY_SETTINGS;
  }
}

function filterByPlatform(settings: PublicAdSettings, platform?: PublicAdPlatform): PublicAdSettings {
  if (!platform) return settings;
  return {
    ...settings,
    slots: settings.slots.filter((slot) => slot.platform === platform),
  };
}
