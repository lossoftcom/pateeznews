import { createHash } from 'node:crypto';
import * as parse5 from 'parse5';
import {
  geminiFastModelAttempts,
  geminiThinkingConfigForModel,
  getOneLowerGeminiModel,
  isGeminiFallbackWorthTrying,
  normalizeGeminiModelName,
} from '../geminiModelFallback';
import { dbQuery } from './supabaseDb';

const CITY = 'Niğde';
const CITY_SLUG = 'nigde';
const TIMEZONE = 'Europe/Istanbul';
const DEFAULT_UPDATE_INTERVAL_MINUTES = 30;
const SOURCE_FETCH_TIMEOUT_MS = 4500;
const DETAIL_FETCH_TIMEOUT_MS = 6500;
const GEMINI_TIMEOUT_MS = 12000;
const MANUAL_GEMINI_TIMEOUT_MS = 18000;
const AI_IMAGE_FETCH_TIMEOUT_MS = 4500;
const MAX_AI_IMAGE_BYTES = 2_500_000;
const MAX_MANUAL_ANNOUNCEMENT_IMAGE_BYTES = 8 * 1024 * 1024;
const MAX_SOURCES_PER_RUN = 80;
const MAX_CANDIDATES_PER_SOURCE = 10;
const MAX_AI_CANDIDATES_PER_RUN = 40;
const MAX_QUEUE_PER_SOURCE = 5;
const MAX_PAYLOAD_SCAN_ROWS = 500;
const USER_AGENT = 'Pateez-Announcements/1.0 (+https://www.pateez.com)';
const INSTAGRAM_WEB_APP_ID = '936619743392459';
const MANUAL_ANNOUNCEMENT_SOURCE_KEY = 'manual-admin';
const MANUAL_ANNOUNCEMENT_SOURCE_NAME = 'Manuel Duyuru';

const DISTRICTS = ['MERKEZ', 'ALTUNHİSAR', 'BOR', 'ÇAMARDI', 'ÇİFTLİK', 'ULUKIŞLA'];
const DISTRICT_LABELS: Record<string, string> = {
  merkez: 'Merkez',
  altunhisar: 'Altunhisar',
  bor: 'Bor',
  camardi: 'Çamardı',
  ciftlik: 'Çiftlik',
  ulukisla: 'Ulukışla',
};
const DISTRICT_KEYS = Object.keys(DISTRICT_LABELS);
const SOCIAL_HOSTS = ['instagram.com', 'facebook.com', 'www.instagram.com', 'www.facebook.com'];
const ANNOUNCEMENT_TERMS = [
  'duyuru',
  'duyurular',
  'duyuruldu',
  'açıklandı',
  'aciklandi',
  'başvuru',
  'basvuru',
  'başladı',
  'basladi',
  'sonuç',
  'sonuc',
  'son gün',
  'son gun',
  'uyarı',
  'uyari',
  'bilgilendirme',
  'program',
  'kurs',
  'eğitim',
  'egitim',
  'etkinlik',
  'festival',
  'konser',
  'yarışma',
  'yarisma',
  'kesinti',
  'yol',
  'trafik',
  'açıklama',
  'aciklama',
  'davet',
  'toplantı',
  'toplanti',
  'destek',
  'planı',
  'plani',
];
const EXCLUDED_TERMS = [
  'resmi ilan',
  'resmî ilan',
  'ilan.gov.tr',
  'ihale',
  'ihalesi',
  'ihaleler',
  'arsa satışı',
  'arsa satisi',
  'taşınmaz satış',
  'tasinmaz satis',
  'taşınmaz mal satış',
  'tasinmaz mal satis',
  'kiralama ihalesi',
  'kiralama ilanı',
  'kiralama ilani',
  'parselasyon',
  'imar planı',
  'imar plani',
  'kamulaştırma',
  'kamulastirma',
  'metruk ilan',
  'başvuru dilekçesi',
  'basvuru dilekcesi',
  'yerleşim planı',
  'yerlesim plani',
  'aplikasyon krokisi',
  'proje kontrolü',
  'proje kontrolu',
];
const CELEBRATION_TERMS = [
  'kutlu olsun',
  'kutlarız',
  'kutlama',
  'tebrik',
  'başsağlığı',
  'bassagligi',
  'anma',
  'rahmet',
  'minnet',
  'bayramınız',
  'bayraminiz',
  'kandiliniz',
  'özel gün',
  'ozel gun',
];
const INTERNAL_ONLY_TERMS = [
  'stajyer',
  'ulusal staj',
  'staj programı',
  'staj programi',
  'personel alımı',
  'personel alimi',
  'işçi alımı',
  'isci alimi',
  'memur alımı',
  'memur alimi',
  'sürekli işçi',
  'surekli isci',
  'sınav sonuçları',
  'sinav sonuclari',
  'asil ve yedek',
  'yeta temizlik',
  'hasta ve ziyaretçileri yönlendirme',
  'hasta ve ziyaretcileri yonlendirme',
  'görev talebi',
  'gorev talebi',
  'görev talepleri',
  'gorev talepleri',
  'açıköğretim programları',
  'acikogretim programlari',
  'bütünleme sınavı',
  'butunleme sinavi',
  'final sınavı görev',
  'final sinavi gorev',
  'telafi için görev',
  'telafi icin gorev',
  'öğrenci alım ilanı',
  'ogrenci alim ilani',
  'uluslararası öğrenci alım',
  'uluslararasi ogrenci alim',
  'bilgi ve belgeye erişim ücret tarifesi',
  'bilgi ve belgeye erisim ucret tarifesi',
  'yetenek kapısı tanıtımı',
  'yetenek kapisi tanitimi',
  'spor aktiviteleri devam ediyor',
  'bilimsel etkinlikler',
];
const NON_ACTIONABLE_CAMPAIGN_TERMS = [
  'dikkatinle yol ver',
  'yol ver hayata',
  'kamu spotu',
  'kadına el kalkamaz',
  'kadina el kalkamaz',
  'kades',
];
const ACTIONABLE_PUBLIC_TERMS = [
  'duyuru',
  'başvuru',
  'basvuru',
  'son gün',
  'son gun',
  'son tarih',
  'hibe',
  'destekleme',
  'destek programı',
  'destek programi',
  'uyarı',
  'uyari',
  'kesinti',
  'arıza',
  'ariza',
  'kapalı',
  'kapali',
  'trafik',
  'güzergah',
  'güzergâh',
  'guzergah',
  'yol çalışması',
  'yol calismasi',
  'asfalt',
  'su kesintisi',
  'elektrik',
  'planlı',
  'planli',
  'çiftçi',
  'ciftci',
  'üretici',
  'uretici',
  'ruhsat',
  'beyanname',
  'vergi',
  'afad',
  'meteoroloji',
];
const WATER_OUTAGE_TERMS = [
  'su kesintisi',
  'sular kesilecek',
  'su verilemeyecek',
  'içme suyu',
  'icme suyu',
  'ana isale',
  'şebeke suyu',
  'sebeke suyu',
  'kanalizasyon arızası',
  'kanalizasyon arizasi',
];
const WEATHER_ALERT_TERMS = [
  'meteoroloji',
  'kuvvetli yağış',
  'kuvvetli yagis',
  'sağanak',
  'saganak',
  'fırtına',
  'firtina',
  'zirai don',
  'don uyarısı',
  'don uyarisi',
  'kar yağışı',
  'kar yagisi',
  'sel',
  'taşkın',
  'taskin',
  'sarı kod',
  'sari kod',
  'turuncu kod',
  'toz taşınımı',
  'toz tasinimi',
];
const PUBLIC_ORDER_TERMS = [
  'sokağa çıkma yasağı',
  'sokaga cikma yasagi',
  'yasaklandı',
  'yasaklandi',
  'valilik kararı',
  'valilik karari',
  'il hıfzıssıhha',
  'il hifzissihha',
  'eğitime ara',
  'egitime ara',
  'okullar tatil',
  'güvenlik tedbiri',
  'guvenlik tedbiri',
  'toplantı ve gösteri',
  'toplanti ve gosteri',
];
const PUBLIC_EXAM_TERMS = [
  'lgs',
  'lks',
  'yks',
  'tyt',
  'ayt',
  'kpss',
  'merkezi sınav',
  'merkezi sinav',
  'sınav merkezi',
  'sinav merkezi',
  'sınav günü',
  'sinav gunu',
  'nüfus müdürlüğü açık',
  'nufus mudurlugu acik',
  'ulaşım düzenlemesi',
  'ulasim duzenlemesi',
];
const MUNICIPAL_SERVICE_TERMS = [
  ...WATER_OUTAGE_TERMS,
  'otobüs sefer',
  'otobus sefer',
  'toplu taşıma',
  'toplu tasima',
  'ulaşım hizmeti',
  'ulasim hizmeti',
  'pazar yeri',
  'mezarlık ziyareti',
  'mezarlik ziyareti',
  'altyapı çalışması',
  'altyapi calismasi',
];
const AGRICULTURE_PUBLIC_TERMS = [
  'karaleke',
  'iç kurdu',
  'ic kurdu',
  'zirai mücadele',
  'zirai mucadele',
  'üretici uyarısı',
  'uretici uyarisi',
  'çiftçi uyarısı',
  'ciftci uyarisi',
];
const ROUTINE_NON_CITY_TERMS = [
  'sergi',
  'sergiledi',
  'kursiyer',
  'halk eğitim',
  'halk egitim',
  'kurslarına ziyaret',
  'kurslarina ziyaret',
  'ziyaret',
  'bilinçlendirme eğitimi',
  'bilinclendirme egitimi',
  'siber suçlara karşı',
  'siber suclara karsi',
  'eğitim programı',
  'egitim programi',
  'kitapçığı',
  'kitapcigi',
  'enerji verimliliği',
  'enerji verimliligi',
  'yeni bir hizmet daha',
  'tören',
  'toren',
  'açılış',
  'acilis',
  'düğün',
  'dugun',
];
const LAW_ENFORCEMENT_SOURCE_TERMS = [
  'emniyet',
  'jandarma',
  'polis',
  'pol.tr',
];
const LAW_ENFORCEMENT_ROUTINE_TERMS = [
  'operasyon',
  'yakalandı',
  'yakalandi',
  'gözaltı',
  'gozalti',
  'tutuklandı',
  'tutuklandi',
  'denetim',
  'rapor',
  'bilgilendirme eğitimi',
  'bilinclendirme egitimi',
  'siber suç',
  'siber suc',
];
const CORE_CITY_SOURCE_KEYS = new Set([
  'nigde-valiligi',
  'nigde-belediyesi',
  'medas-nigde',
  'karayollari-6-bolge',
  'nigde-afad',
  'nigde-il-milli-egitim',
  'nigde-altunhisar-mem',
  'nigde-bor-mem',
  'nigde-camardi-mem',
  'nigde-ciftlik-mem',
  'nigde-ulukisla-mem',
  'altunhisar-kaymakamligi',
  'bor-kaymakamligi',
  'camardi-kaymakamligi',
  'ciftlik-kaymakamligi',
  'ulukisla-kaymakamligi',
  'altunhisar-belediyesi',
  'bor-belediyesi',
  'camardi-belediyesi',
  'ciftlik-belediyesi',
  'ulukisla-belediyesi',
  'nigde-il-saglik',
  'nigde-bor-devlet-hastanesi',
  'nigde-tarim-orman',
  'nigde-csb',
  'nigde-emniyet',
  'nigde-il-ozel-idaresi',
]);
const CORE_CITY_SOURCE_TYPES = new Set(['municipality', 'utility', 'health']);
const GENERAL_SOURCE_TYPES_REQUIRE_STRONG_SIGNAL = new Set(['media', 'chamber', 'union', 'sports', 'other']);
const LOW_QUALITY_TITLE_TERMS = [
  '<![cdata',
  'setupPageDescription',
  '_spBodyOnLoadFunctionNames',
  'DuyuruDetail',
  'function(',
  'javascript:',
];
const GENERIC_PAGE_TITLES = [
  'duyuru',
  'duyurular',
  'duyuru detayı',
  'duyuru detay',
  'haberler',
  'haberler ve duyurular',
  'etkinlikler',
  'announcements',
];
const ROAD_OPERATION_TERMS = [
  'yol çalışması',
  'yol calismasi',
  'yol yapım',
  'yol yapim',
  'yol bakım',
  'yol bakim',
  'yol kapan',
  'yol kapalı',
  'yol kapali',
  'trafiğe kapalı',
  'trafige kapali',
  'trafik düzen',
  'trafik duzen',
  'trafik akışı',
  'trafik akisi',
  'güzergah',
  'güzergâh',
  'guzergah',
  'şerit',
  'serit',
  'asfalt',
  'köprü',
  'kopru',
  'menfez',
  'karayolları',
  'karayollari',
];
const RECENT_WITHOUT_EVENT_DAYS = 45;
const IMAGE_OUTPUT_ROOT = 'local-upload/announcements';
const MIN_ANNOUNCEMENT_IMAGE_WIDTH = 240;
const MIN_ANNOUNCEMENT_IMAGE_HEIGHT = 140;
const LOGO_IMAGE_TERMS = [
  'logo',
  'favicon',
  'icon',
  'sprite',
  'avatar',
  'profile',
  'loader',
  'loading',
  'placeholder',
  'default',
  'og-default',
  'no-image',
  'noimage',
  'blank',
  'brand',
  'header',
  'footer',
  'menu',
  'nav',
  'flag',
  'bayrak',
  'amblem',
  'arma',
];

type AnnouncementCategory = 'official' | 'power' | 'road';
type CrawlStrategy = 'auto' | 'rss' | 'sitemap' | 'html' | 'social_public' | 'search';

export type AnnouncementSource = {
  id: string;
  sourceKey: string;
  name: string;
  sourceType: string;
  categoryHint: AnnouncementCategory;
  district: string;
  websiteUrl: string;
  listUrl: string;
  socialUrl: string;
  facebookUrl: string;
  instagramUrl: string;
  crawlStrategy: CrawlStrategy;
  selectorConfig: Record<string, any>;
  isActive: boolean;
  crawlIntervalMinutes: number;
  lastCheckedAt: string;
  lastSuccessAt: string;
  lastError: string;
  sortOrder: number;
};

export type AnnouncementItem = {
  id: string;
  category: AnnouncementCategory;
  district: string;
  source: string;
  sourceKey?: string;
  title: string;
  summary: string;
  body?: string;
  place: string;
  timeLabel: string;
  statusLabel: string;
  scheduleLabel: string;
  imageUrl: string;
  sourceUrl: string;
  canonicalUrl?: string;
  linkedPostId?: string;
  linkedPostTitle?: string;
  linkedPostSlug?: string;
  linkedPostThumbnailUrl?: string;
  linkedPost?: {
    id: string;
    title: string;
    slug: string;
    summary: string;
    category: string;
    imageUrl: string;
    publishedAt: string;
  } | null;
  publishedAt: string;
  startsAt: string;
  endsAt: string;
  isActive?: boolean;
};

export type AnnouncementPayload = {
  city: string;
  citySlug: string;
  source: string;
  sourceUrl: string;
  timezone: string;
  serviceDate: string;
  serviceDateLabel: string;
  fetchedAt: string;
  updateIntervalMinutes: number;
  districts: Array<{ key: string; label: string; count: number }>;
  announcements: AnnouncementItem[];
  meta: {
    total: number;
    officialCount: number;
    powerCount: number;
    roadCount: number;
    activeSources: number;
  };
};

type Candidate = {
  source: AnnouncementSource;
  title: string;
  summary: string;
  body: string;
  place: string;
  district: string;
  publishedAt: string;
  startsAt: string;
  endsAt: string;
  statusLabel: string;
  scheduleLabel: string;
  imageUrl: string;
  sourceUrl: string;
  canonicalUrl: string;
  category: AnnouncementCategory;
  confidence: number;
  rawPayload: Record<string, any>;
  aiPayload?: Record<string, any>;
};

type AiSettings = {
  active: boolean;
  apiKey: string;
  model: string;
};

type RefreshOptions = {
  force?: boolean;
  runType?: 'manual' | 'cron' | 'discovery';
  sourceLimit?: number;
  candidateLimitPerSource?: number;
  useAi?: boolean;
  discoverSources?: boolean;
};

type RefreshTotals = {
  runId: string;
  sourcesChecked: number;
  candidatesFound: number;
  insertedCount: number;
  updatedCount: number;
  skippedCount: number;
  errors: string[];
};

type CandidateDiscovery = {
  url: string;
  title: string;
  score: number;
  socialPayload?: Record<string, any>;
};

type DefaultSource = {
  sourceKey: string;
  name: string;
  sourceType: string;
  categoryHint: AnnouncementCategory;
  district: string;
  websiteUrl: string;
  listUrl: string;
  socialUrl?: string;
  facebookUrl?: string;
  instagramUrl?: string;
  crawlStrategy?: CrawlStrategy;
  sortOrder: number;
  isActive?: boolean;
};

const defaultSources: DefaultSource[] = [
  {
    sourceKey: 'nigde-valiligi',
    name: 'Niğde Valiliği',
    sourceType: 'institution',
    categoryHint: 'official',
    district: 'merkez',
    websiteUrl: 'https://www.nigde.gov.tr',
    listUrl: 'https://www.nigde.gov.tr/duyurular',
    facebookUrl: 'https://www.facebook.com/TC.NigdeValiligi1/',
    instagramUrl: 'https://www.instagram.com/tcnigde/',
    sortOrder: 10,
  },
  {
    sourceKey: 'nigde-belediyesi',
    name: 'Niğde Belediyesi',
    sourceType: 'municipality',
    categoryHint: 'official',
    district: 'merkez',
    websiteUrl: 'https://www.nigde.bel.tr',
    listUrl: 'https://www.nigde.bel.tr/duyurular',
    facebookUrl: 'https://www.facebook.com/nigdebelediyesi',
    instagramUrl: 'https://www.instagram.com/nigdebelediyesi/',
    sortOrder: 20,
  },
  {
    sourceKey: 'nigde-il-saglik',
    name: 'Niğde İl Sağlık Müdürlüğü',
    sourceType: 'health',
    categoryHint: 'official',
    district: 'merkez',
    websiteUrl: 'https://nigdeism.saglik.gov.tr',
    listUrl: 'https://nigdeism.saglik.gov.tr/TR-30548/duyurular.html',
    facebookUrl: 'https://www.facebook.com/nigdeism/',
    instagramUrl: 'https://www.instagram.com/nigdeilsaglik/',
    sortOrder: 30,
  },
  {
    sourceKey: 'nigde-bor-devlet-hastanesi',
    name: 'Bor Devlet Hastanesi',
    sourceType: 'health',
    categoryHint: 'official',
    district: 'bor',
    websiteUrl: 'https://nigdebordh.saglik.gov.tr',
    listUrl: 'https://nigdebordh.saglik.gov.tr/TR-377488/duyurular.html',
    sortOrder: 35,
  },
  {
    sourceKey: 'nigde-il-milli-egitim',
    name: 'Niğde İl Milli Eğitim Müdürlüğü',
    sourceType: 'education',
    categoryHint: 'official',
    district: 'merkez',
    websiteUrl: 'https://nigde.meb.gov.tr',
    listUrl: 'https://nigde.meb.gov.tr/www/duyurular/kategori/2',
    facebookUrl: 'https://www.facebook.com/nigdeilmem51',
    instagramUrl: 'https://www.instagram.com/nigdeilmem/',
    sortOrder: 40,
  },
  {
    sourceKey: 'nigde-altunhisar-mem',
    name: 'Altunhisar İlçe Milli Eğitim Müdürlüğü',
    sourceType: 'education',
    categoryHint: 'official',
    district: 'altunhisar',
    websiteUrl: 'https://altunhisar.meb.gov.tr',
    listUrl: 'https://altunhisar.meb.gov.tr/www/duyurular/kategori/2',
    sortOrder: 45,
  },
  {
    sourceKey: 'nigde-bor-mem',
    name: 'Bor İlçe Milli Eğitim Müdürlüğü',
    sourceType: 'education',
    categoryHint: 'official',
    district: 'bor',
    websiteUrl: 'https://bor.meb.gov.tr',
    listUrl: 'https://bor.meb.gov.tr/www/duyurular/kategori/2',
    sortOrder: 46,
  },
  {
    sourceKey: 'nigde-camardi-mem',
    name: 'Çamardı İlçe Milli Eğitim Müdürlüğü',
    sourceType: 'education',
    categoryHint: 'official',
    district: 'camardi',
    websiteUrl: 'https://camardi.meb.gov.tr',
    listUrl: 'https://camardi.meb.gov.tr/www/duyurular/kategori/2',
    sortOrder: 47,
  },
  {
    sourceKey: 'nigde-ciftlik-mem',
    name: 'Çiftlik İlçe Milli Eğitim Müdürlüğü',
    sourceType: 'education',
    categoryHint: 'official',
    district: 'ciftlik',
    websiteUrl: 'https://ciftlik.meb.gov.tr',
    listUrl: 'https://ciftlik.meb.gov.tr/www/duyurular/kategori/2',
    sortOrder: 48,
  },
  {
    sourceKey: 'nigde-ulukisla-mem',
    name: 'Ulukışla İlçe Milli Eğitim Müdürlüğü',
    sourceType: 'education',
    categoryHint: 'official',
    district: 'ulukisla',
    websiteUrl: 'https://ulukisla.meb.gov.tr',
    listUrl: 'https://ulukisla.meb.gov.tr/www/duyurular/kategori/2',
    sortOrder: 49,
  },
  {
    sourceKey: 'nigde-ohu',
    name: 'Niğde Ömer Halisdemir Üniversitesi',
    sourceType: 'education',
    categoryHint: 'official',
    district: 'merkez',
    websiteUrl: 'https://www.ohu.edu.tr',
    listUrl: 'https://www.ohu.edu.tr/duyurular',
    facebookUrl: 'https://www.facebook.com/NOHUniversitesi',
    instagramUrl: 'https://www.instagram.com/nohuniversitesi/',
    sortOrder: 50,
  },
  {
    sourceKey: 'medas-nigde',
    name: 'MEDAŞ Niğde',
    sourceType: 'utility',
    categoryHint: 'power',
    district: 'merkez',
    websiteUrl: 'https://www.meramedas.com.tr',
    listUrl: 'https://www.meramedas.com.tr/tr/planli-kesintiler',
    sortOrder: 60,
  },
  {
    sourceKey: 'karayollari-6-bolge',
    name: 'Karayolları 6. Bölge',
    sourceType: 'institution',
    categoryHint: 'road',
    district: 'merkez',
    websiteUrl: 'https://www.kgm.gov.tr',
    listUrl: 'https://www.kgm.gov.tr',
    sortOrder: 70,
  },
  {
    sourceKey: 'altunhisar-kaymakamligi',
    name: 'Altunhisar Kaymakamlığı',
    sourceType: 'institution',
    categoryHint: 'official',
    district: 'altunhisar',
    websiteUrl: 'https://www.altunhisar.gov.tr',
    listUrl: 'https://www.altunhisar.gov.tr/duyurular',
    facebookUrl: 'https://www.facebook.com/altunhisarkaymakamligi',
    instagramUrl: 'https://www.instagram.com/tcaltunhisarkaymakamligi/',
    sortOrder: 80,
  },
  {
    sourceKey: 'bor-kaymakamligi',
    name: 'Bor Kaymakamlığı',
    sourceType: 'institution',
    categoryHint: 'official',
    district: 'bor',
    websiteUrl: 'https://www.bor.gov.tr',
    listUrl: 'https://www.bor.gov.tr/duyurular',
    facebookUrl: 'https://www.facebook.com/borkaymakamligi/',
    sortOrder: 81,
  },
  {
    sourceKey: 'camardi-kaymakamligi',
    name: 'Çamardı Kaymakamlığı',
    sourceType: 'institution',
    categoryHint: 'official',
    district: 'camardi',
    websiteUrl: 'https://www.camardi.gov.tr',
    listUrl: 'https://www.camardi.gov.tr/duyurular',
    facebookUrl: 'https://www.facebook.com/camardikaymakamligi2017/',
    instagramUrl: 'https://www.instagram.com/camardi_kaymakamligi/',
    sortOrder: 82,
  },
  {
    sourceKey: 'ciftlik-kaymakamligi',
    name: 'Çiftlik Kaymakamlığı',
    sourceType: 'institution',
    categoryHint: 'official',
    district: 'ciftlik',
    websiteUrl: 'https://www.ciftlik.gov.tr',
    listUrl: 'https://www.ciftlik.gov.tr/duyurular',
    instagramUrl: 'https://www.instagram.com/ciftlik_kaymakamligii/',
    sortOrder: 83,
  },
  {
    sourceKey: 'ulukisla-kaymakamligi',
    name: 'Ulukışla Kaymakamlığı',
    sourceType: 'institution',
    categoryHint: 'official',
    district: 'ulukisla',
    websiteUrl: 'https://www.ulukisla.gov.tr',
    listUrl: 'https://www.ulukisla.gov.tr/duyurular',
    facebookUrl: 'https://www.facebook.com/ulukislakaymakamligi',
    instagramUrl: 'https://www.instagram.com/ulukislakaymakamligi/',
    sortOrder: 84,
  },
  {
    sourceKey: 'altunhisar-belediyesi',
    name: 'Altunhisar Belediyesi',
    sourceType: 'municipality',
    categoryHint: 'official',
    district: 'altunhisar',
    websiteUrl: 'https://altunhisar.bel.tr',
    listUrl: 'https://altunhisar.bel.tr',
    facebookUrl: 'https://www.facebook.com/profile.php?id=61558423491498',
    instagramUrl: 'https://www.instagram.com/altunhisarbel/',
    sortOrder: 90,
  },
  {
    sourceKey: 'bor-belediyesi',
    name: 'Bor Belediyesi',
    sourceType: 'municipality',
    categoryHint: 'official',
    district: 'bor',
    websiteUrl: 'https://www.bor.bel.tr',
    listUrl: 'https://www.bor.bel.tr',
    facebookUrl: 'https://www.facebook.com/tcborbelediyesi/',
    instagramUrl: 'https://www.instagram.com/borbelediyesi_/',
    sortOrder: 91,
  },
  {
    sourceKey: 'camardi-belediyesi',
    name: 'Çamardı Belediyesi',
    sourceType: 'municipality',
    categoryHint: 'official',
    district: 'camardi',
    websiteUrl: 'https://www.camardi.bel.tr',
    listUrl: 'https://www.camardi.bel.tr/duyurular',
    facebookUrl: 'https://www.facebook.com/profile.php?id=100070266062403',
    instagramUrl: 'https://www.instagram.com/camardibelediyesi/',
    sortOrder: 92,
  },
  {
    sourceKey: 'ciftlik-belediyesi',
    name: 'Çiftlik Belediyesi',
    sourceType: 'municipality',
    categoryHint: 'official',
    district: 'ciftlik',
    websiteUrl: '',
    listUrl: 'https://www.instagram.com/ciftlikbelediyesi/',
    instagramUrl: 'https://www.instagram.com/ciftlikbelediyesi/',
    sortOrder: 93,
  },
  {
    sourceKey: 'ulukisla-belediyesi',
    name: 'Ulukışla Belediyesi',
    sourceType: 'municipality',
    categoryHint: 'official',
    district: 'ulukisla',
    websiteUrl: 'https://www.ulukisla.bel.tr',
    listUrl: 'https://www.ulukisla.bel.tr/sayfa/Duyurular',
    facebookUrl: 'https://www.facebook.com/profile.php?id=100036183292717',
    instagramUrl: 'https://www.instagram.com/ulukislabelediyesi/',
    sortOrder: 94,
  },
  {
    sourceKey: 'nigde-tarim-orman',
    name: 'Niğde İl Tarım ve Orman Müdürlüğü',
    sourceType: 'institution',
    categoryHint: 'official',
    district: 'merkez',
    websiteUrl: 'https://nigde.tarimorman.gov.tr',
    listUrl: 'https://nigde.tarimorman.gov.tr/Sayfalar/Detay.aspx?Liste=Duyuru',
    facebookUrl: 'https://www.facebook.com/nigdetarimorman/',
    instagramUrl: 'https://www.instagram.com/nigdetarimorman/',
    sortOrder: 100,
  },
  {
    sourceKey: 'nigde-genclik-spor',
    name: 'Niğde Gençlik ve Spor İl Müdürlüğü',
    sourceType: 'sports',
    categoryHint: 'official',
    district: 'merkez',
    websiteUrl: 'https://nigde.gsb.gov.tr',
    listUrl: 'https://nigde.gsb.gov.tr/HaberListesi/3/65',
    facebookUrl: 'https://www.facebook.com/nigdegenclikvespor/',
    instagramUrl: 'https://www.instagram.com/gsb_nigde/',
    sortOrder: 101,
  },
  {
    sourceKey: 'iskur-nigde',
    name: 'İŞKUR Niğde',
    sourceType: 'institution',
    categoryHint: 'official',
    district: 'merkez',
    websiteUrl: 'https://www.iskur.gov.tr/',
    listUrl: 'https://www.iskur.gov.tr/',
    facebookUrl: 'https://www.facebook.com/iskurnigde1/',
    instagramUrl: 'https://www.instagram.com/iskurnigde/',
    sortOrder: 107,
  },
  {
    sourceKey: 'nigde-aile-sosyal-hizmetler',
    name: 'Niğde Aile ve Sosyal Hizmetler İl Müdürlüğü',
    sourceType: 'institution',
    categoryHint: 'official',
    district: 'merkez',
    websiteUrl: 'https://www.aile.gov.tr/nigde/',
    listUrl: 'https://www.aile.gov.tr/nigde/',
    facebookUrl: 'https://www.facebook.com/719672884554993/',
    instagramUrl: 'https://www.instagram.com/nigdeashm/',
    sortOrder: 108,
  },
  {
    sourceKey: 'nigde-il-ozel-idaresi',
    name: 'Niğde İl Özel İdaresi',
    sourceType: 'institution',
    categoryHint: 'official',
    district: 'merkez',
    websiteUrl: 'https://www.nigdeozelidare.gov.tr/',
    listUrl: 'https://www.nigdeozelidare.gov.tr/',
    facebookUrl: 'https://www.facebook.com/profile.php?id=100064666783388',
    sortOrder: 109,
  },
  {
    sourceKey: 'nigde-defterdarligi',
    name: 'Niğde Defterdarlığı',
    sourceType: 'institution',
    categoryHint: 'official',
    district: 'merkez',
    websiteUrl: 'https://nigde.gib.gov.tr/',
    listUrl: 'https://nigde.gib.gov.tr/',
    facebookUrl: 'https://www.facebook.com/profile.php?id=100064692878624',
    sortOrder: 110,
  },
  {
    sourceKey: 'nigde-kultur-turizm',
    name: 'Niğde İl Kültür ve Turizm Müdürlüğü',
    sourceType: 'institution',
    categoryHint: 'official',
    district: 'merkez',
    websiteUrl: 'https://nigde.ktb.gov.tr',
    listUrl: 'https://nigde.ktb.gov.tr/TR-447131/haberler-ve-duyurular.html',
    facebookUrl: 'https://www.facebook.com/nigdeilkulturveturizmmudurlugu/',
    instagramUrl: 'https://www.instagram.com/nigdekulturizm/',
    sortOrder: 102,
  },
  {
    sourceKey: 'nigde-afad',
    name: 'AFAD Niğde',
    sourceType: 'institution',
    categoryHint: 'official',
    district: 'merkez',
    websiteUrl: 'https://nigde.afad.gov.tr',
    listUrl: 'https://nigde.afad.gov.tr/duyurular',
    facebookUrl: 'https://www.facebook.com/profile.php?id=100068937468482',
    instagramUrl: 'https://www.instagram.com/afad.nigde/',
    sortOrder: 103,
  },
  {
    sourceKey: 'nigde-csb',
    name: 'Niğde Çevre, Şehircilik ve İklim Değişikliği İl Müdürlüğü',
    sourceType: 'institution',
    categoryHint: 'official',
    district: 'merkez',
    websiteUrl: 'https://nigde.csb.gov.tr',
    listUrl: 'https://nigde.csb.gov.tr/duyurular',
    instagramUrl: 'https://www.instagram.com/nigdecsim/',
    sortOrder: 104,
  },
  {
    sourceKey: 'nigde-sgk',
    name: 'Niğde Sosyal Güvenlik İl Müdürlüğü',
    sourceType: 'institution',
    categoryHint: 'official',
    district: 'merkez',
    websiteUrl: 'https://www.sgk.gov.tr/',
    listUrl: 'https://nigde.sgk.gov.tr/duyuru',
    facebookUrl: 'https://www.facebook.com/sgknigde/',
    instagramUrl: 'https://www.instagram.com/nigdesgim/',
    sortOrder: 105,
  },
  {
    sourceKey: 'nigde-emniyet',
    name: 'Niğde Emniyet Müdürlüğü',
    sourceType: 'institution',
    categoryHint: 'official',
    district: 'merkez',
    websiteUrl: 'https://nigde.pol.tr/',
    listUrl: 'https://nigde.pol.tr/',
    instagramUrl: 'https://www.instagram.com/nigdeemnyt/',
    sortOrder: 111,
  },
  {
    sourceKey: 'ahika',
    name: 'Ahiler Kalkınma Ajansı',
    sourceType: 'institution',
    categoryHint: 'official',
    district: 'merkez',
    websiteUrl: 'https://www.ahika.gov.tr',
    listUrl: 'https://www.ahika.gov.tr/haberler',
    instagramUrl: 'https://www.instagram.com/ahilerkalkinmaajansi/',
    sortOrder: 106,
  },
  {
    sourceKey: 'nitso',
    name: 'Niğde Ticaret ve Sanayi Odası',
    sourceType: 'chamber',
    categoryHint: 'official',
    district: 'merkez',
    websiteUrl: 'https://www.nitso.org.tr',
    listUrl: 'https://www.nitso.org.tr/T%C3%BCmHaberler/tabid/20199/articleType/CategoryView/categoryId/550/Duyuru.aspx',
    facebookUrl: 'https://www.facebook.com/nitso.org.tr/',
    instagramUrl: 'https://www.instagram.com/nigdetso/',
    sortOrder: 120,
  },
  {
    sourceKey: 'nigde-ticaret-borsasi',
    name: 'Niğde Ticaret Borsası',
    sourceType: 'chamber',
    categoryHint: 'official',
    district: 'merkez',
    websiteUrl: 'https://www.nigdetb.org.tr',
    listUrl: 'https://www.nigdetb.org.tr/KURUMSAL/Duyurular/tabid/8474/',
    facebookUrl: 'https://www.facebook.com/nigdeborsa/',
    instagramUrl: 'https://www.instagram.com/nigdeticaretborsasi/',
    sortOrder: 121,
  },
  {
    sourceKey: 'nesob',
    name: 'Niğde Esnaf ve Sanatkârları Odaları Birliği (NESOB)',
    sourceType: 'chamber',
    categoryHint: 'official',
    district: 'merkez',
    websiteUrl: 'https://www.nesob.org.tr',
    listUrl: 'https://www.nesob.org.tr',
    facebookUrl: 'https://www.facebook.com/nesobkurumsal/',
    sortOrder: 122,
  },
  {
    sourceKey: 'nigde-ziraat-odasi',
    name: 'Niğde Ziraat Odası',
    sourceType: 'chamber',
    categoryHint: 'official',
    district: 'merkez',
    websiteUrl: '',
    listUrl: 'https://www.instagram.com/nigdeziraatodasi/',
    facebookUrl: 'https://www.facebook.com/profile.php?id=100091391646789',
    instagramUrl: 'https://www.instagram.com/nigdeziraatodasi/',
    sortOrder: 123,
  },
  {
    sourceKey: 'bor-ziraat-odasi',
    name: 'Bor Ziraat Odası',
    sourceType: 'chamber',
    categoryHint: 'official',
    district: 'bor',
    websiteUrl: '',
    listUrl: 'https://www.instagram.com/borziraat/',
    facebookUrl: 'https://www.facebook.com/296266831223647/',
    instagramUrl: 'https://www.instagram.com/borziraat/',
    sortOrder: 124,
  },
  {
    sourceKey: 'altunhisar-ziraat-odasi',
    name: 'Altunhisar Ziraat Odası',
    sourceType: 'chamber',
    categoryHint: 'official',
    district: 'altunhisar',
    websiteUrl: '',
    listUrl: 'https://www.instagram.com/altunhisarziraatodasi51/',
    facebookUrl: 'https://www.facebook.com/profile.php?id=107869538514276',
    instagramUrl: 'https://www.instagram.com/altunhisarziraatodasi51/',
    sortOrder: 125,
  },
  {
    sourceKey: 'nigde-sut-ureticileri-birligi',
    name: 'Niğde İli Süt Üreticileri Birliği',
    sourceType: 'union',
    categoryHint: 'official',
    district: 'merkez',
    websiteUrl: 'https://www.nigdesutbirligi.com/',
    listUrl: 'https://www.nigdesutbirligi.com/',
    facebookUrl: 'https://www.facebook.com/nigde.sutbirligi/',
    instagramUrl: 'https://www.instagram.com/nigde.sutbirligi/',
    sortOrder: 126,
  },
  {
    sourceKey: 'nigde-damizlik-sigir-birligi',
    name: 'Niğde İli Damızlık Sığır Yetiştiricileri Birliği',
    sourceType: 'union',
    categoryHint: 'official',
    district: 'merkez',
    websiteUrl: 'http://www.ndsyb.com',
    listUrl: 'http://www.ndsyb.com',
    sortOrder: 127,
  },
  {
    sourceKey: 'nigde-damizlik-koyun-keci-birligi',
    name: 'Niğde İli Damızlık Koyun Keçi Yetiştiricileri Birliği',
    sourceType: 'union',
    categoryHint: 'official',
    district: 'merkez',
    websiteUrl: 'https://www.turkiyekoyunkeci.org/il-birliklerimiz/niğde',
    listUrl: 'https://www.turkiyekoyunkeci.org/il-birliklerimiz/niğde',
    facebookUrl: 'https://www.facebook.com/profile.php?id=100054597602589',
    sortOrder: 128,
  },
  {
    sourceKey: 'nigde-ari-yetistiricileri-birligi',
    name: 'Niğde Arı Yetiştiricileri Birliği',
    sourceType: 'union',
    categoryHint: 'official',
    district: 'merkez',
    websiteUrl: '',
    listUrl: 'https://www.facebook.com/nuhorhan51/',
    facebookUrl: 'https://www.facebook.com/nuhorhan51/',
    sortOrder: 129,
  },
  {
    sourceKey: 'nigde-kirmizi-et-ureticileri-birligi',
    name: 'Niğde İli Kırmızı Et Üreticileri Birliği',
    sourceType: 'union',
    categoryHint: 'official',
    district: 'merkez',
    websiteUrl: 'https://nkeub.org.tr/',
    listUrl: 'https://nkeub.org.tr/',
    facebookUrl: 'https://www.facebook.com/nkub51/',
    sortOrder: 130,
  },
  {
    sourceKey: 'haykoop-nigde',
    name: 'Haykoop Niğde',
    sourceType: 'union',
    categoryHint: 'official',
    district: 'merkez',
    websiteUrl: 'https://www.haykoop.org.tr',
    listUrl: 'https://haykoop.org.tr/duyurular/',
    sortOrder: 131,
  },
  {
    sourceKey: 'bor-ticaret-sanayi-odasi',
    name: 'Bor Ticaret ve Sanayi Odası',
    sourceType: 'chamber',
    categoryHint: 'official',
    district: 'bor',
    websiteUrl: 'http://www.bortso.tobb.org.tr/index.htm',
    listUrl: 'http://www.bortso.tobb.org.tr/index.htm',
    instagramUrl: 'https://www.instagram.com/borrtso/',
    sortOrder: 132,
  },
  {
    sourceKey: 'nigde-barosu',
    name: 'Niğde Barosu',
    sourceType: 'chamber',
    categoryHint: 'official',
    district: 'merkez',
    websiteUrl: 'https://www.nigdebarosu.org.tr/',
    listUrl: 'https://www.nigdebarosu.org.tr/DuyuruArsivi',
    instagramUrl: 'https://www.instagram.com/nigde_barosu/',
    sortOrder: 133,
  },
  {
    sourceKey: 'nigde-bakkallar-bayiler-odasi',
    name: 'Niğde Bakkallar ve Bayiler Odası',
    sourceType: 'chamber',
    categoryHint: 'official',
    district: 'merkez',
    websiteUrl: '',
    listUrl: 'https://www.facebook.com/nigdebakkallarodasi/',
    facebookUrl: 'https://www.facebook.com/nigdebakkallarodasi/',
    sortOrder: 134,
  },
  {
    sourceKey: 'nigde-elektrikciler-odasi',
    name: 'Niğde Elektrikçiler Fotoğrafçılar Radyo ve TV Tamircileri Odası',
    sourceType: 'chamber',
    categoryHint: 'official',
    district: 'merkez',
    websiteUrl: '',
    listUrl: 'https://www.instagram.com/nigdeelektrikciler/',
    instagramUrl: 'https://www.instagram.com/nigdeelektrikciler/',
    sortOrder: 135,
  },
  {
    sourceKey: 'tarim-kredi-kooperatifleri',
    name: 'Tarım Kredi Kooperatifleri',
    sourceType: 'union',
    categoryHint: 'official',
    district: 'merkez',
    websiteUrl: 'https://tarimkredi.org.tr/',
    listUrl: 'https://tarimkredi.org.tr/',
    facebookUrl: 'https://www.facebook.com/tarimkredi/',
    sortOrder: 136,
  },
  {
    sourceKey: 'koop-market',
    name: 'KOOP Market / Tarım Kredi Kooperatif Market',
    sourceType: 'union',
    categoryHint: 'official',
    district: 'merkez',
    websiteUrl: 'https://www.tkkoop.com.tr/',
    listUrl: 'https://www.tkkoop.com.tr/',
    facebookUrl: 'https://www.facebook.com/tkkoopmarket/',
    instagramUrl: 'https://www.instagram.com/koopmarket/',
    sortOrder: 137,
  },
  {
    sourceKey: 'golcuk-tarim-kredi-kooperatifi',
    name: 'Gölcük Tarım Kredi Kooperatifi',
    sourceType: 'union',
    categoryHint: 'official',
    district: 'merkez',
    websiteUrl: '',
    listUrl: 'https://www.facebook.com/1934GolcukTKK/',
    facebookUrl: 'https://www.facebook.com/1934GolcukTKK/',
    sortOrder: 138,
  },
  {
    sourceKey: 'nigde-tarim-kredi-kooperatifi',
    name: 'Niğde Tarım Kredi Kooperatifi',
    sourceType: 'union',
    categoryHint: 'official',
    district: 'merkez',
    websiteUrl: '',
    listUrl: 'https://www.facebook.com/0022NigdeTKK/',
    facebookUrl: 'https://www.facebook.com/0022NigdeTKK/',
    sortOrder: 139,
  },
  {
    sourceKey: 'bor-seker',
    name: 'Bor Şeker',
    sourceType: 'institution',
    categoryHint: 'official',
    district: 'bor',
    websiteUrl: 'https://www.borseker.com.tr/',
    listUrl: 'https://www.borseker.com.tr/',
    facebookUrl: 'https://www.facebook.com/borseker/',
    instagramUrl: 'https://www.instagram.com/borseker/',
    sortOrder: 140,
  },
  {
    sourceKey: 'nigde-eczaci-odasi',
    name: 'Niğde Eczacı Odası',
    sourceType: 'chamber',
    categoryHint: 'official',
    district: 'merkez',
    websiteUrl: 'https://www.neo.org.tr',
    listUrl: 'https://www.neo.org.tr/haberler-tum',
    sortOrder: 141,
  },
  {
    sourceKey: 'nigde-osb',
    name: 'Niğde OSB',
    sourceType: 'institution',
    categoryHint: 'official',
    district: 'merkez',
    websiteUrl: 'https://www.nigdeosb.com',
    listUrl: 'https://www.nigdeosb.com/haberler',
    facebookUrl: 'https://www.facebook.com/nigdeorganizesanayi/',
    instagramUrl: 'https://www.instagram.com/nigdeosb/',
    sortOrder: 150,
  },
  {
    sourceKey: 'nigde-2-osb',
    name: 'Niğde 2. Organize Sanayi Bölgesi',
    sourceType: 'institution',
    categoryHint: 'official',
    district: 'merkez',
    websiteUrl: 'https://n2osb.org.tr',
    listUrl: 'https://n2osb.org.tr/category/duyuru/',
    sortOrder: 151,
  },
  {
    sourceKey: 'bor-osb',
    name: 'Bor Karma ve Deri İhtisas OSB',
    sourceType: 'institution',
    categoryHint: 'official',
    district: 'bor',
    websiteUrl: 'https://www.borosb.org.tr',
    listUrl: 'https://www.borosb.org.tr/duyurular.php',
    facebookUrl: 'https://www.facebook.com/NigdeBorKarmaVeDeriOSB/',
    instagramUrl: 'https://www.instagram.com/borkarmavederiihtisasosb/',
    sortOrder: 152,
  },
  {
    sourceKey: 'dmc-haber',
    name: 'DMC Haber',
    sourceType: 'media',
    categoryHint: 'official',
    district: 'merkez',
    websiteUrl: 'https://www.dmchaber.com',
    listUrl: 'https://www.dmchaber.com',
    sortOrder: 160,
  },
  {
    sourceKey: 'nigde-haber',
    name: 'Niğde Haber',
    sourceType: 'media',
    categoryHint: 'official',
    district: 'merkez',
    websiteUrl: 'https://www.nigdehaber.com.tr',
    listUrl: 'https://www.nigdehaber.com.tr',
    sortOrder: 161,
  },
  {
    sourceKey: 'hamle-gazetesi',
    name: 'Hamle Gazetesi',
    sourceType: 'media',
    categoryHint: 'official',
    district: 'merkez',
    websiteUrl: 'https://www.hamlegazetesi.com',
    listUrl: 'https://www.hamlegazetesi.com',
    sortOrder: 162,
  },
  {
    sourceKey: 'nigde-gunaydin',
    name: 'Niğde Günaydın',
    sourceType: 'media',
    categoryHint: 'official',
    district: 'merkez',
    websiteUrl: 'https://www.nigdegunaydin.com',
    listUrl: 'https://www.nigdegunaydin.com',
    sortOrder: 163,
  },
  {
    sourceKey: 'elli-bir-haber',
    name: '51 Haber',
    sourceType: 'media',
    categoryHint: 'official',
    district: 'merkez',
    websiteUrl: 'https://51haber.com',
    listUrl: 'https://51haber.com',
    sortOrder: 164,
  },
];

const normalizeText = (value: unknown) =>
  String(value || '')
    .replace(/\u00a0/g, ' ')
    .replace(/[ \t\r\f\v]+/g, ' ')
    .replace(/\n\s+/g, '\n')
    .trim();

const trLower = (value: string) => normalizeText(value).toLocaleLowerCase('tr-TR');
const trUpper = (value: string) => normalizeText(value).toLocaleUpperCase('tr-TR');

const hash = (value: string) => createHash('sha256').update(value).digest('hex');

const containsAnyTerm = (value: string, terms: readonly string[]) => {
  const haystack = trLower(value);
  return terms.some((term) => haystack.includes(trLower(term)));
};

const slugify = (value: string) =>
  trLower(value)
    .normalize('NFD')
    .replace(/[\u0300-\u036f]/g, '')
    .replace(/ı/g, 'i')
    .replace(/ğ/g, 'g')
    .replace(/ü/g, 'u')
    .replace(/ş/g, 's')
    .replace(/ö/g, 'o')
    .replace(/ç/g, 'c')
    .replace(/[^a-z0-9]+/g, '-')
    .replace(/^-+|-+$/g, '');

const sourceTypeKey = (source: AnnouncementSource) => trLower(source.sourceType || 'other');

const isCoreCitySource = (source: AnnouncementSource) =>
  CORE_CITY_SOURCE_KEYS.has(source.sourceKey) ||
  CORE_CITY_SOURCE_TYPES.has(sourceTypeKey(source));

const isLawEnforcementSource = (source: AnnouncementSource) => {
  const haystack = trLower(`${source.sourceKey} ${source.name} ${source.websiteUrl} ${source.listUrl}`);
  return LAW_ENFORCEMENT_SOURCE_TERMS.some((term) => haystack.includes(term));
};

const sourceRequiresStrongSignal = (source: AnnouncementSource) =>
  isLawEnforcementSource(source) ||
  GENERAL_SOURCE_TYPES_REQUIRE_STRONG_SIGNAL.has(sourceTypeKey(source)) ||
  !isCoreCitySource(source);

const normalizeDistrict = (value: unknown) => {
  const slug = slugify(String(value || ''));
  if (DISTRICT_KEYS.includes(slug)) return slug;
  return 'merkez';
};

const districtLabel = (key: string) => DISTRICT_LABELS[normalizeDistrict(key)] || DISTRICT_LABELS.merkez;

const districtFromText = (value: string) => {
  const upper = trUpper(value);
  if (upper.includes('ALTUNHİSAR') || upper.includes('ALTUNHISAR')) return 'altunhisar';
  if (upper.includes('ÇAMARDI') || upper.includes('CAMARDI')) return 'camardi';
  if (upper.includes('ÇİFTLİK') || upper.includes('CIFTLIK')) return 'ciftlik';
  if (upper.includes('ULUKIŞLA') || upper.includes('ULUKISLA')) return 'ulukisla';
  if (/\bBOR\b/.test(upper)) return 'bor';
  if (upper.includes('MERKEZ')) return 'merkez';
  return '';
};

const hasAnnouncementSignal = (value: string) => {
  const haystack = trLower(value);
  return ANNOUNCEMENT_TERMS.some((term) => haystack.includes(term));
};

const hasExcludedSignal = (value: string) => {
  const haystack = trLower(value);
  return EXCLUDED_TERMS.some((term) => haystack.includes(term));
};

const hasCelebrationSignal = (value: string) => {
  const haystack = trLower(value);
  return CELEBRATION_TERMS.some((term) => {
    const cleanTerm = trLower(term);
    if (cleanTerm === 'anma') return /(^|[^\p{L}\p{N}])anma([^\p{L}\p{N}]|$)/u.test(haystack);
    return haystack.includes(cleanTerm);
  });
};

const hasInternalOnlySignal = (value: string) => {
  const haystack = trLower(value);
  return INTERNAL_ONLY_TERMS.some((term) => haystack.includes(term));
};

const hasNonActionableCampaignSignal = (value: string) => {
  const haystack = trLower(value);
  return NON_ACTIONABLE_CAMPAIGN_TERMS.some((term) => haystack.includes(term));
};

const hasRoutineNonCitySignal = (value: string) => {
  const haystack = trLower(value);
  return ROUTINE_NON_CITY_TERMS.some((term) => haystack.includes(term));
};

const hasLawEnforcementRoutineSignal = (value: string) => {
  const haystack = trLower(value);
  return LAW_ENFORCEMENT_ROUTINE_TERMS.some((term) => haystack.includes(term));
};

const hasActionablePublicSignal = (value: string) => {
  return containsAnyTerm(value, ACTIONABLE_PUBLIC_TERMS);
};

const hasLowQualityNoise = (value: string) => {
  const haystack = trLower(value);
  return LOW_QUALITY_TITLE_TERMS.some((term) => haystack.includes(trLower(term)));
};

const isGenericListingTitle = (title: string, sourceName = '') => {
  const raw = trLower(titleWithoutSourceNoise(title, sourceName)).replace(/\s+/g, ' ').trim();
  const segments = raw
    .split(/\s*(?:[|»>]| - )\s*/g)
    .map((segment) => segment.replace(/[^\p{L}\p{N}\s-]/gu, ' ').replace(/\s+/g, ' ').trim())
    .filter(Boolean);
  if (segments.some((segment) => GENERIC_PAGE_TITLES.includes(segment))) return true;
  const clean = raw.replace(/[^\p{L}\p{N}\s-]/gu, ' ').replace(/\s+/g, ' ').trim();
  if (!clean) return true;
  if (GENERIC_PAGE_TITLES.includes(clean)) return true;
  if (sourceName && GENERIC_PAGE_TITLES.includes(clean.replace(trLower(sourceName), '').trim())) return true;
  if (/^(duyuru|duyurular|haberler|etkinlikler)\s+[a-zçğıöşü0-9-]{2,}$/i.test(clean) && clean.split(/\s+/).length <= 3) return true;
  return /^(kurumsal\s+)?(duyuru|duyurular|haberler|etkinlikler)(\s*[-|]\s*)?$/.test(clean);
};

const isListingUrl = (url: string) => {
  try {
    const path = new URL(url).pathname.replace(/\/+$/, '').toLocaleLowerCase('tr-TR');
    return /\/(duyuru|duyurular|haberler|haberler-ve-duyurular|etkinlikler)$/.test(path);
  } catch {
    return false;
  }
};

const hasRoadSignal = (value: string) => {
  const haystack = trLower(value);
  return ROAD_OPERATION_TERMS.some((term) => haystack.includes(term)) ||
    /\bd-?\d{2,3}\b/i.test(haystack);
};

const hasPowerSignal = (value: string) => {
  const haystack = trLower(value);
  return /\b(medaş|medas|186)\b/i.test(haystack) ||
    /(?:elektrik|enerji|şebeke|sebeke|trafo).{0,80}(?:kesinti|arıza|ariza|bakım|bakim|onarım|onarim|planlı|planli)/i.test(haystack) ||
    /(?:kesinti|arıza|ariza|bakım|bakim|onarım|onarim|planlı|planli).{0,80}(?:elektrik|enerji|şebeke|sebeke|trafo)/i.test(haystack);
};

const hasWaterOutageSignal = (value: string) => containsAnyTerm(value, WATER_OUTAGE_TERMS);
const hasWeatherAlertSignal = (value: string) => containsAnyTerm(value, WEATHER_ALERT_TERMS);
const hasPublicOrderSignal = (value: string) => containsAnyTerm(value, PUBLIC_ORDER_TERMS);
const hasPublicExamSignal = (value: string) => containsAnyTerm(value, PUBLIC_EXAM_TERMS);
const hasMunicipalServiceSignal = (value: string) => containsAnyTerm(value, MUNICIPAL_SERVICE_TERMS);
const hasAgriculturePublicSignal = (value: string) => containsAnyTerm(value, AGRICULTURE_PUBLIC_TERMS);

const hasHardCityCriticalTextSignal = (value: string) =>
  hasPowerSignal(value) ||
  hasRoadSignal(value) ||
  hasWaterOutageSignal(value) ||
  hasWeatherAlertSignal(value) ||
  hasPublicOrderSignal(value) ||
  hasPublicExamSignal(value) ||
  hasAgriculturePublicSignal(value);

const bodyLooksNoisyForDecision = (candidate: Candidate) => {
  const sourceType = sourceTypeKey(candidate.source);
  const summary = trLower(candidate.summary);
  const body = trLower(candidate.body);
  if (sourceType === 'media') return true;
  if (candidate.rawPayload?.socialPlatform || candidate.source.sourceKey === MANUAL_ANNOUNCEMENT_SOURCE_KEY) return false;
  const leading = `${summary} ${body.slice(0, 900)}`;
  return /ana\s*sayfa|anasayfa|hakkımızda|hakkimizda|künye|kunye|kurumsal yapı|kurumsal yapi|görme engelli|gorme engelli|e-belediye|başkanın özgeçmişi|baskanin ozgecmisi|facebook|twitter|arama/.test(leading);
};

const decisionText = (candidate: Candidate) => [
  candidate.source.name,
  candidate.title,
  candidate.summary,
  bodyLooksNoisyForDecision(candidate) ? '' : candidate.body,
  candidate.place,
  candidate.statusLabel,
  candidate.scheduleLabel,
].join(' ');

const cityImpactDecision = (candidate: Candidate) => {
  const text = decisionText(candidate);
  const trustedSource = isCoreCitySource(candidate.source);
  const strongSignalRequired = sourceRequiresStrongSignal(candidate.source);

  if (candidate.category === 'power') {
    return hasPowerSignal(text)
      ? { ok: true, reason: 'elektrik kesintisi/arıza sinyali' }
      : { ok: false, reason: 'elektrik kategorisi için kesinti/arıza kanıtı yok' };
  }
  if (candidate.category === 'road') {
    return hasRoadSignal(text)
      ? { ok: true, reason: 'yol/trafik sinyali' }
      : { ok: false, reason: 'yol kategorisi için yol/trafik kanıtı yok' };
  }
  if (hasWaterOutageSignal(text)) return { ok: true, reason: 'su kesintisi/hizmet sinyali' };
  if (hasWeatherAlertSignal(text)) return { ok: true, reason: 'meteorolojik uyarı sinyali' };
  if (hasPublicOrderSignal(text)) return { ok: true, reason: 'kamu düzeni/valilik kararı sinyali' };
  if (hasPublicExamSignal(text)) return { ok: true, reason: 'şehir geneli sınav/ulaşım sinyali' };
  if (trustedSource && hasMunicipalServiceSignal(text)) {
    return { ok: true, reason: 'belediye/hizmet duyurusu sinyali' };
  }
  if (hasAgriculturePublicSignal(text)) {
    return { ok: true, reason: 'tarım/üretici uyarısı sinyali' };
  }
  if (!strongSignalRequired && hasActionablePublicSignal(text) && /(ruhsat|beyanname)/i.test(trLower(text))) return { ok: true, reason: 'resmi işlem son tarih sinyali' };
  return { ok: false, reason: 'şehir hayatını etkileyen kritik duyuru kanıtı yok' };
};

const hasHardCityCriticalSignal = (candidate: Candidate) => {
  return hasHardCityCriticalTextSignal(decisionText(candidate));
};

const requiresAiConfirmation = (candidate: Candidate) =>
  sourceRequiresStrongSignal(candidate.source) && !hasHardCityCriticalSignal(candidate);

const shouldAttemptAiForRejectedCandidate = (candidate: Candidate) => {
  const text = decisionText(candidate);
  if (candidate.rawPayload?.socialPlatform && (isCoreCitySource(candidate.source) || sourceRequiresStrongSignal(candidate.source))) return true;
  if (candidate.imageUrl && isCoreCitySource(candidate.source) && (hasAnnouncementSignal(text) || hasHardCityCriticalTextSignal(text))) return true;
  if (isCoreCitySource(candidate.source) && hasHardCityCriticalTextSignal(text)) return true;
  return false;
};

const isLocallyScoped = (source: AnnouncementSource, value: string) => {
  const haystack = trLower(`${source.name} ${source.district} ${value}`);
  return haystack.includes('niğde') ||
    haystack.includes('nigde') ||
    DISTRICT_KEYS.some((key) => haystack.includes(key)) ||
    Object.values(DISTRICT_LABELS).some((label) => haystack.includes(trLower(label))) ||
    source.sourceType !== 'media';
};

const publicationDecision = (candidate: Candidate) => {
  const text = decisionText(candidate);
  const compactSummary = normalizeText(`${candidate.summary} ${candidate.body}`).replace(/\s+/g, ' ');

  if (hasLowQualityNoise(candidate.title) || hasLowQualityNoise(candidate.summary)) {
    return { ok: false, reason: 'bozuk sayfa metni' };
  }
  if (isGenericListingTitle(candidate.title, candidate.source.name) || (isListingUrl(candidate.sourceUrl) && compactSummary.length < 80)) {
    return { ok: false, reason: 'liste veya arşiv sayfası' };
  }
  if (hasExcludedSignal(text)) return { ok: false, reason: 'resmi ilan/ihale/imar içeriği' };
  if (hasCelebrationSignal(text)) return { ok: false, reason: 'kutlama veya anma içeriği' };
  if (hasInternalOnlySignal(text)) return { ok: false, reason: 'dar kurum içi/personel içeriği' };
  if (hasNonActionableCampaignSignal(text)) return { ok: false, reason: 'aksiyon içermeyen kampanya/slogan' };
  if (isLawEnforcementSource(candidate.source) && hasLawEnforcementRoutineSignal(text) && !hasHardCityCriticalSignal(candidate)) {
    return { ok: false, reason: 'emniyet/jandarma rutin raporu veya eğitimi' };
  }
  if (hasRoutineNonCitySignal(text) && !hasHardCityCriticalSignal(candidate)) {
    return { ok: false, reason: 'şehir duyurusu olmayan etkinlik/eğitim/ziyaret içeriği' };
  }
  if (!isLocallyScoped(candidate.source, text)) return { ok: false, reason: 'Niğde kapsamı kanıtlanmadı' };
  if (!hasActionablePublicSignal(text)) return { ok: false, reason: 'kullanıcıya dönük aksiyon bilgisi yok' };
  const impact = cityImpactDecision(candidate);
  if (!impact.ok) return impact;
  if (candidate.category === 'road' && !hasRoadSignal(text)) return { ok: false, reason: 'yol/trafik bilgisi kanıtlanmadı' };
  if (candidate.category === 'power' && !hasPowerSignal(text)) return { ok: false, reason: 'elektrik kesintisi bilgisi kanıtlanmadı' };
  if (compactSummary.length < 28 && !candidate.scheduleLabel && !candidate.statusLabel) {
    return { ok: false, reason: 'duyuru ayrıntısı yetersiz' };
  }
  return { ok: true, reason: '' };
};

const toAbsoluteUrl = (base: string, value: string) => {
  const clean = normalizeText(value);
  if (!clean || clean.startsWith('mailto:') || clean.startsWith('tel:') || clean.startsWith('javascript:')) return '';
  try {
    return new URL(clean, base).toString();
  } catch {
    return '';
  }
};

const sameHost = (left: string, right: string) => {
  try {
    const l = new URL(left);
    const r = new URL(right);
    return l.hostname.replace(/^www\./, '') === r.hostname.replace(/^www\./, '');
  } catch {
    return false;
  }
};

const isSocialUrl = (value: string) => {
  try {
    return SOCIAL_HOSTS.includes(new URL(value).hostname.replace(/^m\./, 'www.'));
  } catch {
    return false;
  }
};

const preferredSocialUrl = (source: Pick<AnnouncementSource, 'instagramUrl' | 'facebookUrl' | 'socialUrl'>) =>
  normalizeText(source.instagramUrl) || normalizeText(source.facebookUrl) || normalizeText(source.socialUrl);

const localParts = (date = new Date()) => {
  const parts = new Intl.DateTimeFormat('en-CA', {
    timeZone: TIMEZONE,
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
  }).formatToParts(date);
  const pick = (type: string) => parts.find((part) => part.type === type)?.value || '';
  return {
    year: pick('year'),
    month: pick('month'),
    day: pick('day'),
    dateKey: `${pick('year')}-${pick('month')}-${pick('day')}`,
  };
};

const serviceDateLabel = (date = new Date()) =>
  new Intl.DateTimeFormat('tr-TR', {
    timeZone: TIMEZONE,
    day: 'numeric',
    month: 'long',
    year: 'numeric',
  }).format(date);

const displayTimeLabel = (publishedAt: string) => {
  if (!publishedAt) return 'Bugün';
  const date = new Date(publishedAt);
  if (Number.isNaN(date.getTime())) return 'Bugün';
  const today = localParts().dateKey;
  const dateKey = localParts(date).dateKey;
  const time = new Intl.DateTimeFormat('tr-TR', {
    timeZone: TIMEZONE,
    hour: '2-digit',
    minute: '2-digit',
    hourCycle: 'h23',
  }).format(date);
  if (dateKey === today) return `Bugün ${time}`;
  return new Intl.DateTimeFormat('tr-TR', {
    timeZone: TIMEZONE,
    day: 'numeric',
    month: 'long',
  }).format(date);
};

const localDateStartIso = (dateKey = localParts().dateKey) => new Date(`${dateKey}T00:00:00+03:00`).toISOString();

const recentWithoutEventStartIso = () =>
  new Date(new Date(localDateStartIso()).getTime() - RECENT_WITHOUT_EVENT_DAYS * 24 * 60 * 60 * 1000).toISOString();

const TURKISH_MONTHS: Record<string, number> = {
  ocak: 1,
  subat: 2,
  şubat: 2,
  mart: 3,
  nisan: 4,
  mayis: 5,
  mayıs: 5,
  haziran: 6,
  temmuz: 7,
  agustos: 8,
  ağustos: 8,
  eylul: 9,
  eylül: 9,
  ekim: 10,
  kasim: 11,
  kasım: 11,
  aralik: 12,
  aralık: 12,
};

const localDateIso = (day: number, month: number, year?: number) => {
  const today = localParts();
  const currentYear = Number(today.year);
  const resolvedYear = year || currentYear;
  const date = new Date(`${resolvedYear}-${String(month).padStart(2, '0')}-${String(day).padStart(2, '0')}T12:00:00+03:00`);
  if (Number.isNaN(date.getTime())) return '';
  return date.toISOString();
};

const extractEventWindow = (text: string, publishedAt: string) => {
  const normalized = normalizeText(text);
  const dates = new Set<string>();
  for (const match of normalized.matchAll(/\b(\d{1,2})[./-](\d{1,2})[./-](20\d{2})\b/g)) {
    const iso = localDateIso(Number(match[1]), Number(match[2]), Number(match[3]));
    if (iso) dates.add(iso);
  }
  for (const match of normalized.matchAll(/\b(\d{1,2})\s+(Ocak|Şubat|Subat|Mart|Nisan|Mayıs|Mayis|Haziran|Temmuz|Ağustos|Agustos|Eylül|Eylul|Ekim|Kasım|Kasim|Aralık|Aralik)(?:\s+(20\d{2}))?\b/gi)) {
    const month = TURKISH_MONTHS[trLower(match[2])];
    const iso = localDateIso(Number(match[1]), month, match[3] ? Number(match[3]) : undefined);
    if (iso) dates.add(iso);
  }

  const ordered = [...dates].sort();
  if (ordered.length) {
    return {
      startsAt: ordered[0],
      endsAt: ordered[ordered.length - 1],
    };
  }

  const published = new Date(publishedAt);
  return {
    startsAt: '',
    endsAt: Number.isNaN(published.getTime()) ? '' : '',
  };
};

const isCandidateCurrent = (candidate: Candidate) => {
  const todayStart = new Date(localDateStartIso()).getTime();
  const endsAt = candidate.endsAt ? new Date(candidate.endsAt).getTime() : 0;
  if (endsAt && !Number.isNaN(endsAt) && endsAt < todayStart) return false;
  const startsAt = candidate.startsAt ? new Date(candidate.startsAt).getTime() : 0;
  if (startsAt && !Number.isNaN(startsAt) && startsAt >= todayStart - 24 * 60 * 60 * 1000) return true;
  const publishedAt = new Date(candidate.publishedAt).getTime();
  if (Number.isNaN(publishedAt)) return true;
  return publishedAt >= todayStart - RECENT_WITHOUT_EVENT_DAYS * 24 * 60 * 60 * 1000;
};

const rowToDecisionCandidate = (row: any): Candidate => {
  const source: AnnouncementSource = {
    id: String(row.source_id || ''),
    sourceKey: String(row.source_key || ''),
    name: String(row.source_name || ''),
    sourceType: String(row.source_type || 'other'),
    categoryHint: validCategory(row.category_hint || row.category),
    district: normalizeDistrict(row.district),
    websiteUrl: String(row.website_url || ''),
    listUrl: String(row.list_url || row.source_url || ''),
    socialUrl: String(row.social_url || ''),
    facebookUrl: String(row.facebook_url || ''),
    instagramUrl: String(row.instagram_url || ''),
    crawlStrategy: 'auto',
    selectorConfig: {},
    isActive: true,
    crawlIntervalMinutes: DEFAULT_UPDATE_INTERVAL_MINUTES,
    lastCheckedAt: '',
    lastSuccessAt: '',
    lastError: '',
    sortOrder: 0,
  };
  return {
    source,
    title: String(row.title || ''),
    summary: String(row.summary || ''),
    body: String(row.body || ''),
    place: String(row.place || 'Niğde geneli'),
    district: normalizeDistrict(row.district),
    publishedAt: String(row.published_at || row.created_at || ''),
    startsAt: String(row.starts_at || ''),
    endsAt: String(row.ends_at || ''),
    statusLabel: String(row.status_label || ''),
    scheduleLabel: String(row.schedule_label || ''),
    imageUrl: String(row.image_url || ''),
    sourceUrl: String(row.source_url || ''),
    canonicalUrl: String(row.canonical_url || row.source_url || ''),
    category: validCategory(row.category),
    confidence: Number(row.confidence || 0) || 0,
    rawPayload: {},
  };
};

const rowPassesPublicationDecision = (row: any) => {
  const candidate = rowToDecisionCandidate(row);
  return isCandidateCurrent(candidate) && publicationDecision(candidate).ok;
};

const fetchText = async (url: string, timeoutMs = SOURCE_FETCH_TIMEOUT_MS) => {
  const response = await fetch(url, {
    signal: AbortSignal.timeout(timeoutMs),
    headers: {
      Accept: 'text/html,application/xhtml+xml,application/xml,text/xml;q=0.9,*/*;q=0.8',
      'User-Agent': USER_AGENT,
    },
  });
  if (!response.ok) throw new Error(`${url} HTTP ${response.status}`);
  const contentType = response.headers.get('content-type') || '';
  const arrayBuffer = await response.arrayBuffer();
  const decoder = /charset=iso-8859-9/i.test(contentType)
    ? new TextDecoder('iso-8859-9')
    : new TextDecoder('utf-8');
  return {
    url: response.url || url,
    contentType,
    text: decoder.decode(arrayBuffer),
  };
};

const getAttr = (node: any, name: string) => {
  const attrs = Array.isArray(node?.attrs) ? node.attrs : [];
  return attrs.find((attr: any) => trLower(attr?.name) === trLower(name))?.value || '';
};

const walk = (node: any, visit: (child: any) => void) => {
  visit(node);
  for (const child of node?.childNodes || []) walk(child, visit);
};

const findAll = (node: any, predicate: (child: any) => boolean) => {
  const result: any[] = [];
  walk(node, (child) => {
    if (predicate(child)) result.push(child);
  });
  return result;
};

const textContent = (node: any): string => {
  if (!node) return '';
  if (['script', 'style', 'noscript'].includes(node.tagName)) return '';
  if (node.nodeName === '#text') return node.value || '';
  return (node.childNodes || []).map(textContent).join('');
};

const textWithBreaks = (node: any): string => {
  if (!node) return '';
  if (['script', 'style', 'noscript'].includes(node.tagName)) return '';
  if (node.nodeName === '#text') return node.value || '';
  if (node.tagName === 'br') return '\n';
  const block = ['p', 'div', 'li', 'h1', 'h2', 'h3', 'h4', 'tr'].includes(node.tagName);
  const inner = (node.childNodes || []).map(textWithBreaks).join('');
  return block ? `\n${inner}\n` : inner;
};

const metaContent = (document: any, key: string) => {
  const metas = findAll(document, (node) => node?.tagName === 'meta');
  const wanted = trLower(key);
  const node = metas.find((meta) =>
    trLower(getAttr(meta, 'property')) === wanted ||
    trLower(getAttr(meta, 'name')) === wanted ||
    trLower(getAttr(meta, 'itemprop')) === wanted
  );
  return normalizeText(getAttr(node, 'content'));
};

const linkHref = (document: any, rel: string, baseUrl: string) => {
  const links = findAll(document, (node) => node?.tagName === 'link');
  const wanted = trLower(rel);
  const node = links.find((link) => trLower(getAttr(link, 'rel')) === wanted);
  return toAbsoluteUrl(baseUrl, getAttr(node, 'href'));
};

const pageTitle = (document: any) => {
  const h1 = findAll(document, (node) => node?.tagName === 'h1')[0];
  if (h1) return normalizeText(textContent(h1));
  const title = findAll(document, (node) => node?.tagName === 'title')[0];
  return normalizeText(textContent(title));
};

const titleWithoutSourceNoise = (title: string, sourceName: string) =>
  normalizeText(title)
    .replace(/\s*[|-]\s*Pateez\s*$/i, '')
    .replace(new RegExp(`\\s*[|-]\\s*${sourceName.replace(/[.*+?^${}()|[\]\\]/g, '\\$&')}\\s*$`, 'i'), '')
    .trim();

const extractDate = (document: any, text: string) => {
  const metas = [
    'article:published_time',
    'datePublished',
    'publishdate',
    'pubdate',
    'dc.date',
    'og:updated_time',
  ];
  for (const key of metas) {
    const value = metaContent(document, key);
    if (value) {
      const date = new Date(value);
      if (!Number.isNaN(date.getTime())) return date.toISOString();
    }
  }

  const timeNode = findAll(document, (node) => node?.tagName === 'time')
    .find((node) => getAttr(node, 'datetime'));
  if (timeNode) {
    const date = new Date(getAttr(timeNode, 'datetime'));
    if (!Number.isNaN(date.getTime())) return date.toISOString();
  }

  const numeric = text.match(/\b(\d{1,2})[./-](\d{1,2})[./-](20\d{2})\b/);
  if (numeric) {
    const date = new Date(`${numeric[3]}-${numeric[2].padStart(2, '0')}-${numeric[1].padStart(2, '0')}T09:00:00+03:00`);
    if (!Number.isNaN(date.getTime())) return date.toISOString();
  }

  return new Date().toISOString();
};

const categoryFor = (source: AnnouncementSource, title: string, body: string): AnnouncementCategory => {
  const haystack = trLower(`${source.name} ${title} ${body}`);
  if (source.categoryHint === 'power' || hasPowerSignal(haystack)) return 'power';
  if (source.categoryHint === 'road' || hasRoadSignal(haystack)) return 'road';
  return 'official';
};

const statusFor = (title: string, body: string) => {
  const haystack = trLower(`${title} ${body}`);
  if (/arıza|ariza/.test(haystack)) return 'Arıza';
  if (/uyarı|uyari|fırtına|firtina|toz|sağanak|saganak/.test(haystack)) return 'Uyarı';
  if (/kapalı|kapali|kapatıl/.test(haystack)) return 'Kapalı';
  if (/başvuru|basvuru|kayıt|kayit/.test(haystack)) return 'Başvuru';
  if (/planlı|planli|bakım|bakim|çalışma|calisma/.test(haystack)) return 'Planlı';
  if (/etkinlik|program|festival|konser/.test(haystack)) return 'Etkinlik';
  return '';
};

const scheduleFor = (text: string) => {
  const normalized = normalizeText(text);
  const range = normalized.match(/\b([01]?\d|2[0-3])[:.][0-5]\d\s*[-–—]\s*([01]?\d|2[0-3])[:.][0-5]\d\b/);
  if (range) return range[0].replace(/\./g, ':').replace(/\s*[-–—]\s*/, ' – ');
  const single = normalized.match(/\b([01]?\d|2[0-3])[:.][0-5]\d\b/);
  return single ? single[0].replace(/\./g, ':') : '';
};

const placeFor = (text: string) => {
  const upper = trUpper(text);
  const found = DISTRICTS.filter((district) => upper.includes(district));
  if (found.length) {
    return found
      .slice(0, 4)
      .map((district) => district[0] + district.slice(1).toLocaleLowerCase('tr-TR'))
      .join(' · ');
  }
  const mahalle = normalizeText(text).match(/([A-ZÇĞİÖŞÜa-zçğıöşü0-9'’\s.-]{2,40}\sMahallesi)/);
  return mahalle ? normalizeText(mahalle[1]) : 'Niğde geneli';
};

const districtFor = (source: AnnouncementSource, text: string) =>
  districtFromText(text) || normalizeDistrict(source.district);

const candidateScore = (url: string, label: string) => {
  const haystack = trLower(`${url} ${label}`);
  if (hasExcludedSignal(haystack)) return -999;
  let score = 0;
  for (const term of ANNOUNCEMENT_TERMS) {
    if (haystack.includes(term)) score += 4;
  }
  if (/\/(duyuru|duyurular|haberler-ve-duyurular|etkinlik|etkinlikler|program|basvuru|başvuru)/i.test(url)) score += 6;
  if (label.length > 16) score += 2;
  if (/\/(haber|haberler)\b/i.test(url) && !hasAnnouncementSignal(label)) score -= 5;
  if (isSocialUrl(url)) score -= 4;
  return score;
};

const parseXmlCandidates = (source: AnnouncementSource, xml: string, baseUrl: string): CandidateDiscovery[] => {
  const items = [...xml.matchAll(/<(item|entry)\b[\s\S]*?<\/\1>/gi)].slice(0, MAX_CANDIDATES_PER_SOURCE * 2);
  return items
    .map((match) => {
      const block = match[0];
      const title = normalizeText(block.match(/<title[^>]*>([\s\S]*?)<\/title>/i)?.[1]?.replace(/<!\[CDATA\[|\]\]>/g, '') || '');
      const link = normalizeText(block.match(/<link[^>]*>([\s\S]*?)<\/link>/i)?.[1]?.replace(/<!\[CDATA\[|\]\]>/g, '') || getXmlAttrLink(block));
      const url = toAbsoluteUrl(baseUrl, link);
      return url ? { url, title, score: candidateScore(url, title) + 5 } : null;
    })
    .filter((item): item is CandidateDiscovery => Boolean(item))
    .filter((item) => item.score > 0 || sameHost(source.listUrl, item.url));
};

const getXmlAttrLink = (block: string) =>
  block.match(/<link[^>]+href=["']([^"']+)["'][^>]*>/i)?.[1] || '';

const wellKnownUrls = (source: AnnouncementSource) => {
  const base = source.websiteUrl && !isSocialUrl(source.websiteUrl)
    ? source.websiteUrl
    : source.listUrl && !isSocialUrl(source.listUrl)
      ? source.listUrl
      : '';
  const paths = source.sourceType === 'media'
    ? ['/', '/duyurular', '/haberler']
    : ['/', '/duyurular', '/duyuru', '/haberler-ve-duyurular', '/etkinlikler', '/rss.xml'];
  const urls = new Set<string>();
  if (source.listUrl && !isSocialUrl(source.listUrl)) urls.add(source.listUrl);
  if (source.websiteUrl && !isSocialUrl(source.websiteUrl)) urls.add(source.websiteUrl);
  if (!base) return [...urls].slice(0, MAX_QUEUE_PER_SOURCE - 1);
  for (const path of paths) {
    const url = toAbsoluteUrl(base, path);
    if (url) urls.add(url);
  }
  return [...urls].slice(0, MAX_QUEUE_PER_SOURCE - 1);
};

const instagramUsernameFromUrl = (value: string) => {
  try {
    const url = new URL(value);
    if (!url.hostname.replace(/^www\./, '').endsWith('instagram.com')) return '';
    const [first] = url.pathname.split('/').filter(Boolean);
    if (!first || ['p', 'reel', 'tv', 'stories', 'explore', 'accounts'].includes(first)) return '';
    return first.replace(/^@/, '');
  } catch {
    return '';
  }
};

const instagramCaption = (node: any) =>
  normalizeText(node?.edge_media_to_caption?.edges?.[0]?.node?.text || '');

const instagramTitleFromCaption = (caption: string, sourceName: string) => {
  const line = caption
    .split(/\n+/)
    .map((item) => normalizeText(item).replace(/^[^\p{L}\p{N}]+/u, '').replace(/[^\p{L}\p{N}]+$/u, ''))
    .find((item) => item.replace(/[^\p{L}\p{N}]/gu, '').length >= 5);
  return (line || `${sourceName} Instagram duyurusu`).slice(0, 140);
};

const instagramCandidateScore = (source: AnnouncementSource, postUrl: string, caption: string) => {
  const text = `${source.name} ${caption}`;
  if (hasExcludedSignal(text)) return -999;
  const hardSignal = hasHardCityCriticalTextSignal(text);
  if (hasCelebrationSignal(text) && !hardSignal) return -999;
  if (hasRoutineNonCitySignal(text) && !hardSignal) return -20;
  let score = candidateScore(postUrl, caption);
  if (hardSignal) score += 18;
  if (hasActionablePublicSignal(text)) score += 8;
  if (isCoreCitySource(source)) score += 4;
  if (caption.length > 40) score += 2;
  return score;
};

const collectInstagramProfileCandidates = async (
  source: AnnouncementSource,
  instagramUrl: string,
  limit: number,
): Promise<CandidateDiscovery[]> => {
  const username = instagramUsernameFromUrl(instagramUrl);
  if (!username) return [];
  const response = await fetch(
    `https://www.instagram.com/api/v1/users/web_profile_info/?username=${encodeURIComponent(username)}`,
    {
      signal: AbortSignal.timeout(SOURCE_FETCH_TIMEOUT_MS),
      headers: {
        Accept: 'application/json',
        Referer: `https://www.instagram.com/${username}/`,
        'User-Agent': 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/125.0 Safari/537.36',
        'x-ig-app-id': INSTAGRAM_WEB_APP_ID,
      },
    },
  );
  if (!response.ok) throw new Error(`Instagram ${username} HTTP ${response.status}`);
  const data = await response.json().catch(() => null);
  const edges = Array.isArray(data?.data?.user?.edge_owner_to_timeline_media?.edges)
    ? data.data.user.edge_owner_to_timeline_media.edges
    : [];
  return edges
    .map((edge: any) => {
      const node = edge?.node || {};
      const shortcode = normalizeText(node.shortcode);
      const caption = instagramCaption(node);
      if (!shortcode || !caption) return null;
      const url = `https://www.instagram.com/p/${shortcode}/`;
      const title = instagramTitleFromCaption(caption, source.name);
      const score = instagramCandidateScore(source, url, caption);
      if (score < 4) return null;
      return {
        url,
        title,
        score,
        socialPayload: {
          socialPlatform: 'instagram',
          username,
          shortcode,
          caption,
          displayUrl: normalizeText(node.display_url),
          takenAtTimestamp: Number(node.taken_at_timestamp || 0) || 0,
          isVideo: Boolean(node.is_video),
        },
      };
    })
    .filter((item): item is CandidateDiscovery => Boolean(item))
    .slice(0, limit);
};

const parseSocialCandidate = (source: AnnouncementSource, item: CandidateDiscovery): Candidate | null => {
  if (item.socialPayload?.socialPlatform !== 'instagram') return null;
  const caption = normalizeText(item.socialPayload.caption);
  const title = instagramTitleFromCaption(caption, source.name);
  if (!caption || !title || title.length < 6) return null;
  const body = caption.slice(0, 7000);
  const publishedAt = item.socialPayload.takenAtTimestamp
    ? new Date(Number(item.socialPayload.takenAtTimestamp) * 1000).toISOString()
    : new Date().toISOString();
  const category = categoryFor(source, title, body);
  const statusLabel = statusFor(title, body);
  const scheduleLabel = scheduleFor(`${title} ${body}`);
  const place = placeFor(`${title} ${body}`);
  const district = districtFor(source, `${title} ${body}`);
  const eventWindow = extractEventWindow(`${title} ${body}`, publishedAt);
  return {
    source,
    title,
    summary: summarize(caption, title),
    body,
    place,
    district,
    publishedAt,
    startsAt: eventWindow.startsAt,
    endsAt: eventWindow.endsAt,
    statusLabel,
    scheduleLabel,
    imageUrl: normalizeText(item.socialPayload.displayUrl),
    sourceUrl: item.url,
    canonicalUrl: item.url,
    category,
    confidence: 0.68,
    rawPayload: {
      discoveredUrl: item.url,
      canonicalUrl: item.url,
      socialPlatform: 'instagram',
      instagramUsername: item.socialPayload.username,
      instagramShortcode: item.socialPayload.shortcode,
      isVideo: item.socialPayload.isVideo,
    },
  };
};

const collectCandidateUrls = async (source: AnnouncementSource, limit: number) => {
  const socialUrl = preferredSocialUrl(source);
  const queue = [
    ...(source.crawlStrategy === 'social_public' && socialUrl ? [socialUrl] : wellKnownUrls(source)),
    ...(source.crawlStrategy === 'social_public' ? wellKnownUrls(source).slice(0, 1) : []),
    socialUrl,
  ].filter(Boolean).filter((url, index, list) => list.indexOf(url) === index).slice(0, MAX_QUEUE_PER_SOURCE);
  const candidates = new Map<string, CandidateDiscovery>();
  let attempted = 0;
  let reachable = 0;
  const errors: string[] = [];

  if (source.instagramUrl) {
    try {
      for (const item of await collectInstagramProfileCandidates(source, source.instagramUrl, limit)) {
        const current = candidates.get(item.url);
        if (!current || item.score > current.score) candidates.set(item.url, item);
      }
    } catch (error: any) {
      errors.push(normalizeText(error?.message || 'Instagram profili taranamadı'));
    }
  }

  for (const url of queue) {
    if (!url) continue;
    attempted += 1;
    try {
      const response = await fetchText(url);
      reachable += 1;
      const looksXml = /xml|rss|atom/i.test(response.contentType) || /^\s*</.test(response.text) && /<(rss|feed|urlset)\b/i.test(response.text);
      if (looksXml) {
        for (const item of parseXmlCandidates(source, response.text, response.url)) {
          if (!candidates.has(item.url)) candidates.set(item.url, item);
        }
        continue;
      }

      const document = parse5.parse(response.text);
      const anchors = findAll(document, (node) => node?.tagName === 'a');
      const listTitle = pageTitle(document);
      if (
        candidateScore(response.url, listTitle) >= 5 &&
        !isGenericListingTitle(listTitle, source.name) &&
        (!isListingUrl(response.url) || isSocialUrl(response.url))
      ) {
        candidates.set(response.url, { url: response.url, title: listTitle, score: candidateScore(response.url, listTitle) });
      }
      for (const anchor of anchors) {
        const href = toAbsoluteUrl(response.url, getAttr(anchor, 'href'));
        if (!href || (!sameHost(response.url, href) && !isSocialUrl(href))) continue;
        const title = normalizeText(textContent(anchor));
        const score = candidateScore(href, title);
        if (score < 4) continue;
        const current = candidates.get(href);
        if (!current || score > current.score) candidates.set(href, { url: href, title, score });
      }
    } catch (error: any) {
      errors.push(normalizeText(error?.message || 'kaynağa ulaşılamıyor'));
    }
  }

  if (attempted > 0 && reachable === 0 && candidates.size === 0) {
    throw new Error(`kaynağa ulaşılamıyor: ${errors[0] || source.listUrl}`);
  }

  return [...candidates.values()]
    .sort((a, b) => b.score - a.score)
    .slice(0, limit);
};

const parseCandidate = async (source: AnnouncementSource, item: CandidateDiscovery): Promise<Candidate | null> => {
  const socialCandidate = parseSocialCandidate(source, item);
  if (socialCandidate) return socialCandidate;
  const url = item.url;
  const response = await fetchText(url, DETAIL_FETCH_TIMEOUT_MS);
  const document = parse5.parse(response.text);
  const fullText = normalizeText(textWithBreaks(document));
  const rawTitle = metaContent(document, 'og:title') || pageTitle(document);
  const title = normalizeText(titleWithoutSourceNoise(rawTitle, source.name));
  if (!title || title.length < 6) return null;
  if (hasLowQualityNoise(title) || isGenericListingTitle(title, source.name)) return null;
  if (hasExcludedSignal(`${response.url} ${title}`)) return null;

  const description = metaContent(document, 'og:description') ||
    metaContent(document, 'description') ||
    firstParagraph(document);
  const body = fullText.slice(0, 7000);
  const summary = summarize(description || body, title);
  if (!summary && body.length < 20) return null;
  if (hasLowQualityNoise(summary) || hasLowQualityNoise(body.slice(0, 500))) return null;
  if (hasExcludedSignal(`${title} ${summary} ${body}`)) return null;
  if (!hasAnnouncementSignal(`${source.listUrl} ${title} ${summary} ${body}`)) return null;

  const canonicalUrl = linkHref(document, 'canonical', response.url) || response.url;
  const imageUrl = announcementImageUrl(document, response.url);
  const publishedAt = extractDate(document, body);
  const category = categoryFor(source, title, body);
  const statusLabel = statusFor(title, body);
  const scheduleLabel = scheduleFor(`${title} ${summary} ${body}`);
  const place = placeFor(`${title} ${summary} ${body}`);
  const district = districtFor(source, `${title} ${summary} ${body}`);
  const eventWindow = extractEventWindow(`${title} ${summary} ${body}`, publishedAt);

  return {
    source,
    title,
    summary,
    body,
    place,
    district,
    publishedAt,
    startsAt: eventWindow.startsAt,
    endsAt: eventWindow.endsAt,
    statusLabel,
    scheduleLabel,
    imageUrl,
    sourceUrl: response.url,
    canonicalUrl,
    category,
    confidence: 0.72,
    rawPayload: {
      discoveredUrl: url,
      canonicalUrl,
      contentType: response.contentType,
      title: rawTitle,
    },
  };
};

const firstParagraph = (document: any) => {
  const paragraphs = findAll(document, (node) => node?.tagName === 'p')
    .map((node) => normalizeText(textContent(node)))
    .filter((text) => text.length > 40);
  return paragraphs[0] || '';
};

const imageAttrText = (node: any) =>
  [
    getAttr(node, 'src'),
    getAttr(node, 'data-src'),
    getAttr(node, 'data-original'),
    getAttr(node, 'data-lazy-src'),
    getAttr(node, 'alt'),
    getAttr(node, 'title'),
    getAttr(node, 'class'),
    getAttr(node, 'id'),
  ].map(normalizeText).filter(Boolean).join(' ');

const srcFromSet = (value: string) => {
  const first = normalizeText(value).split(',')[0] || '';
  return normalizeText(first.split(/\s+/)[0] || '');
};

const imageNodeUrl = (node: any, baseUrl: string) =>
  toAbsoluteUrl(
    baseUrl,
    getAttr(node, 'src') ||
      getAttr(node, 'data-src') ||
      getAttr(node, 'data-original') ||
      getAttr(node, 'data-lazy-src') ||
      srcFromSet(getAttr(node, 'srcset')),
  );

const isUsableAnnouncementImageSize = (width: number | null, height: number | null) => {
  if (!width || !height) return true;
  if (width < MIN_ANNOUNCEMENT_IMAGE_WIDTH || height < MIN_ANNOUNCEMENT_IMAGE_HEIGHT) return false;
  const ratio = width / height;
  return ratio >= 0.35 && ratio <= 4.5;
};

const imageDimension = (node: any, name: string) => {
  const value = normalizeText(getAttr(node, name)).replace(/[^\d.]/g, '');
  const parsed = Number(value);
  return Number.isFinite(parsed) && parsed > 0 ? parsed : null;
};

const hasLogoImageSignal = (value: string) => containsAnyTerm(value.replace(/[-_]+/g, ' '), LOGO_IMAGE_TERMS);

const isLikelyAnnouncementImageUrl = (url: string, extra = '') => {
  const cleanUrl = normalizeText(url);
  if (!cleanUrl) return false;
  const lower = trLower(`${cleanUrl} ${extra}`);
  if (hasLogoImageSignal(lower)) return false;
  try {
    const pathname = trLower(decodeURIComponent(new URL(cleanUrl).pathname));
    if (pathname.endsWith('.svg')) return false;
    if (pathname.endsWith('.gif') && hasLogoImageSignal(pathname)) return false;
  } catch {
    return false;
  }
  return true;
};

const imageCandidateScore = (url: string, node: any) => {
  const text = trLower(`${url} ${imageAttrText(node)}`);
  let score = 0;
  if (containsAnyTerm(text, ['duyuru', 'haber', 'etkinlik', 'ilan', 'upload', 'uploads', 'media', 'resim', 'image', 'photo', 'files', 'whatsapp'])) score += 3;
  if (containsAnyTerm(text, ['content', 'gallery', 'galeri', 'slider'])) score += 1;
  if (text.includes('.jpg') || text.includes('.jpeg') || text.includes('.png') || text.includes('.webp')) score += 1;
  const width = imageDimension(node, 'width');
  const height = imageDimension(node, 'height');
  if (width && height && width >= 480 && height >= 240) score += 2;
  return score;
};

const announcementImageUrl = (document: any, baseUrl: string) => {
  const metaImage = toAbsoluteUrl(
    baseUrl,
    metaContent(document, 'og:image') || metaContent(document, 'twitter:image')
  );
  if (isLikelyAnnouncementImageUrl(metaImage)) return metaImage;

  const candidates = findAll(document, (node) => node?.tagName === 'img')
    .map((node) => {
      const url = imageNodeUrl(node, baseUrl);
      const width = imageDimension(node, 'width');
      const height = imageDimension(node, 'height');
      return {
        node,
        url,
        width,
        height,
        score: imageCandidateScore(url, node),
      };
    })
    .filter((candidate) =>
      isLikelyAnnouncementImageUrl(candidate.url, imageAttrText(candidate.node)) &&
      isUsableAnnouncementImageSize(candidate.width, candidate.height)
    )
    .sort((a, b) => b.score - a.score);

  return candidates[0]?.url || '';
};

const summarize = (value: string, title: string) => {
  const clean = normalizeText(value).replace(title, '').trim();
  if (!clean) return '';
  if (clean.length <= 220) return clean;
  return `${clean.slice(0, 217).replace(/\s+\S*$/, '')}...`;
};

const rowToSource = (row: any): AnnouncementSource => ({
  id: String(row.id || ''),
  sourceKey: String(row.source_key || ''),
  name: String(row.name || ''),
  sourceType: String(row.source_type || 'other'),
  categoryHint: ['official', 'power', 'road'].includes(row.category_hint) ? row.category_hint : 'official',
  district: normalizeDistrict(row.district),
  websiteUrl: String(row.website_url || ''),
  listUrl: String(row.list_url || ''),
  socialUrl: String(row.social_url || ''),
  facebookUrl: String(row.facebook_url || ''),
  instagramUrl: String(row.instagram_url || ''),
  crawlStrategy: String(row.crawl_strategy || 'auto') as CrawlStrategy,
  selectorConfig: typeof row.selector_config === 'object' && row.selector_config ? row.selector_config : {},
  isActive: row.is_active !== false,
  crawlIntervalMinutes: Number(row.crawl_interval_minutes || DEFAULT_UPDATE_INTERVAL_MINUTES),
  lastCheckedAt: String(row.last_checked_at || ''),
  lastSuccessAt: String(row.last_success_at || ''),
  lastError: String(row.last_error || ''),
  sortOrder: Number(row.sort_order || 0),
});

export async function ensureDefaultAnnouncementSources() {
  const rows = defaultSources.map((source) => {
    const facebookUrl = normalizeText(source.facebookUrl);
    const instagramUrl = normalizeText(source.instagramUrl);
    const socialUrl = normalizeText(source.socialUrl) || instagramUrl || facebookUrl;
    return {
      source_key: source.sourceKey,
      name: source.name,
      source_type: validSourceType(source.sourceType),
      category_hint: validCategory(source.categoryHint),
      district: normalizeDistrict(source.district),
      website_url: source.websiteUrl,
      list_url: source.listUrl,
      social_url: socialUrl,
      facebook_url: facebookUrl,
      instagram_url: instagramUrl,
      crawl_strategy: source.crawlStrategy || (isSocialUrl(source.listUrl) ? 'social_public' : 'auto'),
      is_active: source.isActive !== false,
      crawl_interval_minutes: DEFAULT_UPDATE_INTERVAL_MINUTES,
      sort_order: source.sortOrder,
    };
  });
  if (rows.length === 0) return;
  await dbQuery(
    `INSERT INTO public.announcement_sources
       (source_key, name, source_type, category_hint, district, website_url, list_url,
        social_url, facebook_url, instagram_url, crawl_strategy, is_active,
        crawl_interval_minutes, sort_order)
     SELECT source_key, name, source_type, category_hint, district, website_url, list_url,
            social_url, facebook_url, instagram_url, crawl_strategy, is_active,
            crawl_interval_minutes, sort_order
     FROM jsonb_to_recordset($1::jsonb) AS source_rows(
       source_key text,
       name text,
       source_type text,
       category_hint text,
       district text,
       website_url text,
       list_url text,
       social_url text,
       facebook_url text,
       instagram_url text,
       crawl_strategy text,
       is_active boolean,
       crawl_interval_minutes integer,
       sort_order integer
     )
     ON CONFLICT (source_key) DO UPDATE SET
       name = EXCLUDED.name,
       source_type = EXCLUDED.source_type,
       category_hint = EXCLUDED.category_hint,
       district = EXCLUDED.district,
       website_url = EXCLUDED.website_url,
       list_url = EXCLUDED.list_url,
       social_url = EXCLUDED.social_url,
       facebook_url = EXCLUDED.facebook_url,
       instagram_url = EXCLUDED.instagram_url,
       crawl_strategy = EXCLUDED.crawl_strategy,
       is_active = EXCLUDED.is_active,
       crawl_interval_minutes = CASE
         WHEN announcement_sources.crawl_interval_minutes = 20 THEN EXCLUDED.crawl_interval_minutes
         ELSE announcement_sources.crawl_interval_minutes
       END,
       sort_order = EXCLUDED.sort_order,
       updated_at = now()`,
    [JSON.stringify(rows)]
  );
}

export async function listAnnouncementSources({ includeInactive = false } = {}) {
  await ensureDefaultAnnouncementSources();
  const result = await dbQuery(
    `SELECT id, source_key, name, source_type, category_hint, district, website_url, list_url,
            social_url, facebook_url, instagram_url,
            crawl_strategy, selector_config, is_active, crawl_interval_minutes,
            last_checked_at, last_success_at, last_error, sort_order
     FROM public.announcement_sources
     WHERE ($1::boolean IS TRUE OR is_active IS TRUE)
     ORDER BY sort_order ASC, name ASC`,
    [includeInactive]
  );
  return result.rows.map(rowToSource);
}

const sourceDue = (source: AnnouncementSource, force: boolean) => {
  if (force || !source.lastCheckedAt) return true;
  const last = new Date(source.lastCheckedAt).getTime();
  if (Number.isNaN(last)) return true;
  return Date.now() - last >= Math.max(5, source.crawlIntervalMinutes) * 60 * 1000;
};

const fetchAiSettings = async (): Promise<AiSettings> => {
  try {
    const result = await dbQuery(
      `SELECT google_ai_active, google_ai_api_key, google_ai_model
       FROM public.site_settings
       WHERE language_code = 'tr'
       LIMIT 1`
    );
    const row = result.rows[0] || {};
    return {
      active: row.google_ai_active === true,
      apiKey: String(row.google_ai_api_key || '').trim(),
      model: normalizeGeminiModelName(row.google_ai_model) || 'gemini-2.5-flash',
    };
  } catch {
    return { active: false, apiKey: '', model: 'gemini-2.5-flash' };
  }
};

const aiImagePart = async (candidate: Candidate) => {
  const imageUrl = normalizeText(candidate.imageUrl);
  if (!/^https?:\/\//i.test(imageUrl)) return null;
  try {
    const response = await fetch(imageUrl, {
      signal: AbortSignal.timeout(AI_IMAGE_FETCH_TIMEOUT_MS),
      headers: {
        Accept: 'image/avif,image/webp,image/png,image/jpeg,image/*;q=0.7',
        'User-Agent': USER_AGENT,
      },
    });
    if (!response.ok) return null;
    const contentType = (response.headers.get('content-type') || '').split(';')[0].trim();
    if (!contentType.startsWith('image/')) return null;
    const contentLength = Number(response.headers.get('content-length') || 0);
    if (contentLength > MAX_AI_IMAGE_BYTES) return null;
    const arrayBuffer = await response.arrayBuffer();
    if (arrayBuffer.byteLength > MAX_AI_IMAGE_BYTES) return null;
    return {
      inlineData: {
        mimeType: contentType,
        data: Buffer.from(arrayBuffer).toString('base64'),
      },
    };
  } catch {
    return null;
  }
};

const classifyWithAi = async (settings: AiSettings, candidate: Candidate) => {
  if (!settings.active || !settings.apiKey) return null;

  const prompt = `
Niğde yerel duyuru editörüsün. Aşağıdaki kaynak metni sadece kanıtlanan bilgiyle JSON'a çevir.
Yeni bilgi uydurma. Sosyal medya API kullanmadan, verilmiş sayfa metnine sadık kal.
Kategori sadece official, power veya road olabilir.
Yayın kararı çok sıkı olsun:
- Elektrik kesintisi/arıza/bakım, su kesintisi, yol kapanması/trafik/güzergah, meteorolojik uyarı, valilik/kaymakamlık kamu düzeni kararı, belediye şehir hizmeti kesintisi, okul tatili/eğitime ara, LGS/YKS/KPSS/ALES/DGS gibi şehir geneli sınav ulaşım/nüfus hizmeti veya üreticiye resmi tarım hastalık/zararlı/zirai uyarısı varsa isPublishable true.
- Valilik, kaymakamlık ve belediye Instagram içeriklerinde görselde yazan metni oku; şehir/district hizmeti, uyarı, sınav, nüfus müdürlüğü mesaisi, yol/trafik veya meteoroloji duyurusu ise yayınlanabilir.
- Jandarma/emniyet rutin raporu, operasyon haberi, siber suç/eğitim semineri, ziyaret, tören, açılış, kurs, sergi, kitapçık, enerji verimliliği tanıtımı, genel etkinlik/tanıtım, bilimsel kongre, OSB yerleşim/hizmet sayfası, kooperatif tanıtımı, kutlama, tebrik, anma, resmi ilan, ihale, personel/staj alımı, genel haber, liste/arşiv sayfası veya Niğde ilgisi kanıtlanmayan içerikte isPublishable false.
- Yol kategorisi sadece yol kapanması, trafik, güzergah, yol çalışması gibi kanıtlı bilgilerde road olsun.
- Elektrik kategorisi sadece elektrik kesintisi/arıza/bakım/trafo/şebeke bilgisi kanıtlıysa power olsun; enerji verimliliği veya genel enerji tanıtımı power değildir.
- Görselde duyuru metni varsa body alanına kısa ve temiz şekilde aktar; sayfa menüsü, ilgili haberler ve navigasyon metinlerini body'ye alma.

Kaynak: ${candidate.source.name}
URL: ${candidate.canonicalUrl || candidate.sourceUrl}
Başlık: ${candidate.title}
Özet: ${candidate.summary}
Metin:
${candidate.body.slice(0, 4500)}

JSON alanları:
isPublishable, contentType, rejectReason, category, title, summary, body, place, statusLabel, scheduleLabel, imageUrl, startsAt, endsAt, confidence
  `;
  const imagePart = await aiImagePart(candidate);
  const payload = {
    contents: [{ parts: [{ text: prompt }, ...(imagePart ? [imagePart] : [])] }],
    generationConfig: {
      temperature: 0.1,
      topK: 16,
      topP: 0.75,
      maxOutputTokens: 700,
      responseMimeType: 'application/json',
    },
  };

  const call = async (apiVersion: 'v1beta' | 'v1', modelId: string) => {
    const response = await fetch(
      `https://generativelanguage.googleapis.com/${apiVersion}/models/${encodeURIComponent(modelId)}:generateContent?key=${encodeURIComponent(settings.apiKey)}`,
      {
        method: 'POST',
        signal: AbortSignal.timeout(GEMINI_TIMEOUT_MS),
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(payload),
      }
    );
    const data = await response.json().catch(() => ({}));
    if (!response.ok || data?.error) {
      return {
        ok: false as const,
        status: response.status,
        message: data?.error?.message || `Gemini HTTP ${response.status}`,
      };
    }
    return { ok: true as const, data };
  };

  const primary = settings.model || 'gemini-2.5-flash';
  const fallback = getOneLowerGeminiModel(primary);
  const queue = fallback && fallback !== primary ? [primary, fallback] : [primary];

  for (const model of queue) {
    let result = await call('v1beta', model);
    if (!result.ok && result.status === 404) result = await call('v1', model);
    if (result.ok) {
      const text = result.data?.candidates?.[0]?.content?.parts?.[0]?.text || '';
      try {
        const parsed = JSON.parse(text);
        return typeof parsed === 'object' && parsed ? parsed : null;
      } catch {
        return null;
      }
    }
    if (!isGeminiFallbackWorthTrying(result.status, result.message)) break;
  }

  return null;
};

const aiDateIso = (value: unknown) => {
  const clean = normalizeText(value);
  if (!clean) return '';
  const date = new Date(clean);
  return Number.isNaN(date.getTime()) ? '' : date.toISOString();
};

const aiRejectReason = (ai: Record<string, any> | null) => {
  if (!ai) return '';
  const publishable = ai.isPublishable ?? ai.publishable;
  if (publishable === false) return normalizeText(ai.rejectReason) || 'AI yayınlanabilir bulmadı';
  const type = trLower(String(ai.contentType || ai.type || ''));
  if (/(celebration|kutlama|tebrik|official_ad|resmi_ilan|tender|ihale|job|internship|staj|personnel|personel|generic_news|archive|listing|list|internal|police_report|jandarma_report|security_report|routine_report|operation|visit|ceremony|exhibition|course|training|seminar|booklet|generic_event|non_actionable)/.test(type)) {
    return normalizeText(ai.rejectReason) || `AI içerik türünü reddetti: ${type}`;
  }
  if (ai.isCelebration === true) return normalizeText(ai.rejectReason) || 'AI kutlama/anma olarak işaretledi';
  if (ai.isOfficialAd === true) return normalizeText(ai.rejectReason) || 'AI resmi ilan/ihale olarak işaretledi';
  if (ai.isExpired === true) return normalizeText(ai.rejectReason) || 'AI süresi geçmiş olarak işaretledi';
  return '';
};

const applyAi = (candidate: Candidate, ai: Record<string, any> | null): Candidate => {
  if (!ai) return candidate;
  const category = ['official', 'power', 'road'].includes(ai.category) ? ai.category : candidate.category;
  const startsAt = aiDateIso(ai.startsAt);
  const endsAt = aiDateIso(ai.endsAt);
  const aiImageUrl = toAbsoluteUrl(candidate.sourceUrl, normalizeText(ai.imageUrl));
  return {
    ...candidate,
    category,
    title: normalizeText(ai.title) || candidate.title,
    summary: summarize(normalizeText(ai.summary), candidate.title) || candidate.summary,
    body: normalizeText(ai.body) || candidate.body,
    place: normalizeText(ai.place) || candidate.place,
    district: districtFromText(`${normalizeText(ai.place)} ${candidate.title} ${candidate.summary}`) || candidate.district,
    statusLabel: normalizeText(ai.statusLabel) || candidate.statusLabel,
    scheduleLabel: normalizeText(ai.scheduleLabel) || candidate.scheduleLabel,
    imageUrl: isLikelyAnnouncementImageUrl(aiImageUrl) ? aiImageUrl : candidate.imageUrl,
    startsAt: startsAt || candidate.startsAt,
    endsAt: endsAt || candidate.endsAt,
    confidence: Math.max(candidate.confidence, Number(ai.confidence || 0) || 0),
    aiPayload: ai,
  };
};

const candidateHash = (candidate: Candidate) =>
  hash([
    candidate.source.sourceKey,
    trLower(candidate.title),
    candidate.startsAt.slice(0, 10),
    candidate.endsAt.slice(0, 10),
    candidate.publishedAt.slice(0, 10),
  ].join('|'));

const findExistingAnnouncementId = async (candidate: Candidate, contentHash: string) => {
  const result = await dbQuery(
    `SELECT id
     FROM public.announcements
     WHERE content_hash = $1
        OR (canonical_url <> '' AND canonical_url = $2)
        OR source_url = $3
        OR (source_key = $4 AND title = $5)
     ORDER BY
       CASE
         WHEN content_hash = $1 THEN 0
         WHEN canonical_url <> '' AND canonical_url = $2 THEN 1
         WHEN source_url = $3 THEN 2
         ELSE 3
       END,
       updated_at DESC
     LIMIT 1`,
    [
      contentHash,
      candidate.canonicalUrl || candidate.sourceUrl,
      candidate.sourceUrl,
      candidate.source.sourceKey,
      candidate.title,
    ]
  );
  return String(result.rows[0]?.id || '');
};

const writeAnnouncementImageBuffer = async (
  buffer: Buffer,
  contentHash: string,
  publishedAt: string,
) => {
  const [{ default: sharp }, fs, path] = await Promise.all([
    import('sharp'),
    import('node:fs/promises'),
    import('node:path'),
  ]);
  const metadata = await sharp(buffer, { failOn: 'none' }).metadata();
  const originalWidth = metadata.width || null;
  const originalHeight = metadata.height || null;
  if (!isUsableAnnouncementImageSize(originalWidth, originalHeight)) {
    return { url: '', width: null as number | null, height: null as number | null };
  }

  const dateKey = (publishedAt || new Date().toISOString()).slice(0, 10);
  const relativeDir = `${IMAGE_OUTPUT_ROOT}/${dateKey}`;
  const fileName = `${contentHash.slice(0, 20)}.webp`;
  const outputDir = path.join(process.cwd(), 'public', relativeDir);
  const outputPath = path.join(outputDir, fileName);
  const publicUrl = `/${relativeDir}/${fileName}`;

  await fs.mkdir(outputDir, { recursive: true });
  try {
    await fs.stat(outputPath);
    return { url: publicUrl, width: originalWidth, height: originalHeight };
  } catch {
    // File is not present yet.
  }

  const result = await sharp(buffer, { failOn: 'none' })
    .rotate()
    .resize({ width: 960, withoutEnlargement: true })
    .webp({ quality: 78, effort: 4 })
    .toFile(outputPath);

  return { url: publicUrl, width: result.width || null, height: result.height || null };
};

const optimizeAnnouncementImage = async (candidate: Candidate, contentHash: string) => {
  const originalUrl = normalizeText(candidate.imageUrl);
  if (!originalUrl) return { url: '', width: null as number | null, height: null as number | null };
  if (!isLikelyAnnouncementImageUrl(originalUrl)) return { url: '', width: null, height: null };

  try {
    const response = await fetch(originalUrl, {
      signal: AbortSignal.timeout(9000),
      headers: {
        Accept: 'image/avif,image/webp,image/*,*/*;q=0.7',
        'User-Agent': USER_AGENT,
      },
    });
    if (!response.ok) return { url: '', width: null, height: null };
    const contentType = response.headers.get('content-type') || '';
    if (!contentType.startsWith('image/')) return { url: '', width: null, height: null };
    const arrayBuffer = await response.arrayBuffer();
    if (arrayBuffer.byteLength > 12 * 1024 * 1024) return { url: '', width: null, height: null };

    return writeAnnouncementImageBuffer(Buffer.from(arrayBuffer), contentHash, candidate.publishedAt);
  } catch {
    return { url: '', width: null, height: null };
  }
};

const saveCandidate = async (candidate: Candidate) => {
  const contentHash = candidateHash(candidate);
  const image = await optimizeAnnouncementImage(candidate, contentHash);
  const imageUrl = image.url;
  const existingId = await findExistingAnnouncementId(candidate, contentHash);
  const values = [
    candidate.source.id,
    candidate.source.sourceKey,
    candidate.source.name,
    candidate.category,
    candidate.title,
    candidate.summary,
    candidate.body,
    candidate.place,
    candidate.district,
    displayTimeLabel(candidate.publishedAt),
    candidate.publishedAt,
    candidate.startsAt || null,
    candidate.endsAt || null,
    candidate.statusLabel,
    candidate.scheduleLabel,
    imageUrl,
    candidate.sourceUrl,
    candidate.canonicalUrl,
    contentHash,
    JSON.stringify(candidate.rawPayload),
    JSON.stringify(candidate.aiPayload || {}),
    candidate.confidence,
  ];

  if (existingId) {
    await dbQuery(
      `UPDATE public.announcements
       SET source_id = $1,
           source_key = $2,
           source_name = $3,
           category = $4,
           title = $5,
           summary = $6,
           body = $7,
           place = $8,
           district = $9,
           time_label = $10,
           published_at = $11,
           starts_at = $12,
           ends_at = $13,
           status_label = $14,
           schedule_label = $15,
           image_url = $16,
           source_url = $17,
           canonical_url = $18,
           content_hash = $19,
           raw_payload = $20::jsonb,
           ai_payload = $21::jsonb,
           confidence = $22,
           is_active = true,
           updated_at = now()
       WHERE id = $23`,
      [...values, existingId]
    );
    return { inserted: false };
  }

  const inserted = await dbQuery(
    `INSERT INTO public.announcements
       (source_id, source_key, source_name, category, title, summary, body, place, district,
        time_label, published_at, starts_at, ends_at, status_label, schedule_label, image_url,
        source_url, canonical_url, content_hash, raw_payload, ai_payload, confidence)
     VALUES
       ($1, $2, $3, $4, $5, $6, $7, $8, $9,
        $10, $11, $12, $13, $14, $15, $16,
        $17, $18, $19, $20::jsonb, $21::jsonb, $22)
     RETURNING id`,
    values
  );

  if (imageUrl && inserted.rows[0]?.id) {
    await dbQuery(
      `INSERT INTO public.announcement_media (announcement_id, url, alt_text, source_url, width, height)
       VALUES ($1, $2, $3, $4, $5, $6)
       ON CONFLICT (announcement_id, url) DO NOTHING`,
      [inserted.rows[0].id, imageUrl, candidate.title, candidate.sourceUrl, image.width, image.height]
    );
  }

  return { inserted: true };
};

const updateSourceStatus = async (source: AnnouncementSource, error = '') => {
  await dbQuery(
    `UPDATE public.announcement_sources
     SET last_checked_at = now(),
         last_success_at = CASE WHEN $2 = '' THEN now() ELSE last_success_at END,
         last_error = NULLIF($2, ''),
         updated_at = now()
     WHERE id = $1`,
    [source.id, error.slice(0, 800)]
  );
};

const createRun = async (runType: string) => {
  const result = await dbQuery(
    `INSERT INTO public.announcement_crawl_runs (run_type, status)
     VALUES ($1, 'running')
     RETURNING id`,
    [runType]
  );
  return String(result.rows[0]?.id || '');
};

const finishRun = async (runId: string, totals: RefreshTotals) => {
  if (!runId) return;
  const status = totals.errors.length && (totals.insertedCount || totals.updatedCount)
    ? 'partial'
    : totals.errors.length
      ? 'error'
      : 'success';
  await dbQuery(
    `UPDATE public.announcement_crawl_runs
     SET status = $2,
         finished_at = now(),
         candidates_found = $3,
         inserted_count = $4,
         updated_count = $5,
         skipped_count = $6,
         error_message = NULLIF($7, ''),
         details = $8::jsonb
     WHERE id = $1`,
    [
      runId,
      status,
      totals.candidatesFound,
      totals.insertedCount,
      totals.updatedCount,
      totals.skippedCount,
      totals.errors.join(' | ').slice(0, 1200),
      JSON.stringify({ sourcesChecked: totals.sourcesChecked, errors: totals.errors.slice(0, 20) }),
    ]
  );
};

export async function runAnnouncementsRefresh(options: RefreshOptions = {}) {
  await ensureDefaultAnnouncementSources();
  if (options.discoverSources !== false) {
    await maybeDiscoverSources().catch(() => null);
  }

  const runType = options.runType || 'manual';
  const runId = await createRun(runType);
  const totals: RefreshTotals = {
    runId,
    sourcesChecked: 0,
    candidatesFound: 0,
    insertedCount: 0,
    updatedCount: 0,
    skippedCount: 0,
    errors: [],
  };
  const aiSettings = options.useAi === false ? { active: false, apiKey: '', model: '' } : await fetchAiSettings();
  let aiUsed = 0;

  try {
    const sources = (await listAnnouncementSources())
      .filter((source) => source.isActive && sourceDue(source, Boolean(options.force)))
      .slice(0, options.sourceLimit || MAX_SOURCES_PER_RUN);
    const candidateLimit = options.candidateLimitPerSource || MAX_CANDIDATES_PER_SOURCE;

    for (const source of sources) {
      totals.sourcesChecked += 1;
      try {
        const urls = await collectCandidateUrls(source, candidateLimit);
        totals.candidatesFound += urls.length;
        for (const item of urls) {
          try {
            const parsed = await parseCandidate(source, item);
            if (!parsed) {
              totals.skippedCount += 1;
              continue;
            }
            if (!isCandidateCurrent(parsed)) {
              totals.skippedCount += 1;
              continue;
            }
            const preliminaryDecision = publicationDecision(parsed);
            const shouldAskAi = aiSettings.active && aiSettings.apiKey && aiUsed < MAX_AI_CANDIDATES_PER_RUN &&
              (preliminaryDecision.ok || shouldAttemptAiForRejectedCandidate(parsed));
            const ai = shouldAskAi
              ? await classifyWithAi(aiSettings, parsed).catch(() => null)
              : null;
            if (ai) aiUsed += 1;
            if (!preliminaryDecision.ok && !ai) {
              totals.skippedCount += 1;
              continue;
            }
            if (!ai && aiSettings.active && aiSettings.apiKey && requiresAiConfirmation(parsed)) {
              totals.skippedCount += 1;
              continue;
            }
            const aiRejection = aiRejectReason(ai);
            if (aiRejection) {
              totals.skippedCount += 1;
              continue;
            }
            const candidate = applyAi(parsed, ai);
            const finalDecision = publicationDecision(candidate);
            if (!isCandidateCurrent(candidate) || !finalDecision.ok) {
              totals.skippedCount += 1;
              continue;
            }
            const saved = await saveCandidate(candidate);
            if (saved.inserted) totals.insertedCount += 1;
            else totals.updatedCount += 1;
          } catch {
            totals.skippedCount += 1;
          }
        }
        await updateSourceStatus(source);
      } catch (error: any) {
        const message = `${source.name}: ${normalizeText(error?.message || 'kaynak taranamadı')}`;
        totals.errors.push(message);
        await updateSourceStatus(source, message);
      }
    }
  } finally {
    await finishRun(runId, totals);
  }

  return totals;
}

const shouldRunDiscovery = async () => {
  const result = await dbQuery(
    `SELECT started_at
     FROM public.announcement_crawl_runs
     WHERE run_type = 'discovery'
       AND started_at > now() - interval '24 hours'
     ORDER BY started_at DESC
     LIMIT 1`
  );
  return !result.rows[0];
};

const maybeDiscoverSources = async () => {
  if (!(await shouldRunDiscovery())) return;
  const settings = await fetchAiSettings();
  if (!settings.active || !settings.apiKey) return;

  const runId = await createRun('discovery');
  let inserted = 0;
  let skipped = 0;
  try {
    const prompt = `
Niğde ili için yayınlanabilir resmi/kurumsal duyuru kaynaklarını bul.
Kurum, belediye, oda, borsa, birlik, sendika, STK, üniversite, sağlık, eğitim, ulaşım ve altyapı kaynaklarını düşün.
Sosyal medya API gerektiren bilgi verme; sadece herkese açık web sitesi veya açık sosyal sayfa URL'si ver.
Uydurma yapma; emin olmadığın kaynağı yazma.
JSON döndür:
{"sources":[{"name":"","sourceType":"institution|municipality|chamber|union|ngo|education|health|sports|utility|media|social|other","categoryHint":"official|power|road","websiteUrl":"","listUrl":"","socialUrl":""}]}
`;
    const payload = {
      contents: [{ parts: [{ text: prompt }] }],
      tools: [{ google_search: {} }],
      generationConfig: {
        temperature: 0.1,
        topK: 12,
        topP: 0.7,
        maxOutputTokens: 1800,
        responseMimeType: 'application/json',
      },
    };
    const response = await fetch(
      `https://generativelanguage.googleapis.com/v1beta/models/${encodeURIComponent(settings.model || 'gemini-2.5-flash')}:generateContent?key=${encodeURIComponent(settings.apiKey)}`,
      {
        method: 'POST',
        signal: AbortSignal.timeout(GEMINI_TIMEOUT_MS),
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(payload),
      }
    );
    const data = await response.json().catch(() => ({}));
    const text = data?.candidates?.[0]?.content?.parts?.[0]?.text || '';
    const parsed = JSON.parse(text || '{}');
    const sources = Array.isArray(parsed?.sources) ? parsed.sources.slice(0, 25) : [];

    for (const source of sources) {
      const name = normalizeText(source?.name);
      const websiteUrl = normalizeText(source?.websiteUrl);
      const listUrl = normalizeText(source?.listUrl) || websiteUrl || normalizeText(source?.socialUrl);
      if (!name || !listUrl) {
        skipped += 1;
        continue;
      }
      const absoluteListUrl = toAbsoluteUrl(websiteUrl || listUrl, listUrl);
      if (!absoluteListUrl) {
        skipped += 1;
        continue;
      }
      try {
        await fetchText(absoluteListUrl, 6000);
      } catch {
        skipped += 1;
        continue;
      }
      await dbQuery(
        `INSERT INTO public.announcement_sources
           (source_key, name, source_type, category_hint, website_url, list_url, social_url, crawl_strategy, sort_order)
         VALUES ($1, $2, $3, $4, $5, $6, $7, $8, 500)
         ON CONFLICT (source_key) DO NOTHING`,
        [
          slugify(name),
          name,
          validSourceType(source?.sourceType),
          validCategory(source?.categoryHint),
          toAbsoluteUrl(websiteUrl || absoluteListUrl, websiteUrl),
          absoluteListUrl,
          toAbsoluteUrl(absoluteListUrl, normalizeText(source?.socialUrl)),
          isSocialUrl(absoluteListUrl) ? 'social_public' : 'auto',
        ]
      );
      inserted += 1;
    }
  } catch (error: any) {
    await dbQuery(
      `UPDATE public.announcement_crawl_runs
       SET status = 'error', finished_at = now(), error_message = $2
       WHERE id = $1`,
      [runId, normalizeText(error?.message || 'Kaynak keşfi başarısız').slice(0, 1000)]
    );
    return;
  }

  await dbQuery(
    `UPDATE public.announcement_crawl_runs
     SET status = 'success',
         finished_at = now(),
         inserted_count = $2,
         skipped_count = $3,
         details = $4::jsonb
     WHERE id = $1`,
    [runId, inserted, skipped, JSON.stringify({ inserted, skipped })]
  );
};

const validSourceType = (value: unknown) => {
  const type = String(value || '').trim();
  return ['institution', 'municipality', 'chamber', 'union', 'ngo', 'education', 'health', 'sports', 'utility', 'media', 'social', 'other'].includes(type)
    ? type
    : 'other';
};

const validCategory = (value: unknown): AnnouncementCategory => {
  const category = String(value || '').trim();
  return ['official', 'power', 'road'].includes(category) ? category as AnnouncementCategory : 'official';
};

export async function upsertAnnouncementSource(input: Partial<AnnouncementSource>) {
  const sourceKey = normalizeText(input.sourceKey) || slugify(normalizeText(input.name));
  if (!sourceKey) throw new Error('Kaynak anahtarı gerekli');
  const name = normalizeText(input.name);
  const listUrl = normalizeText(input.listUrl);
  if (!name || !listUrl) throw new Error('Kaynak adı ve liste URL zorunlu');

  const result = await dbQuery(
    `INSERT INTO public.announcement_sources
       (source_key, name, source_type, category_hint, district, website_url, list_url,
        social_url, facebook_url, instagram_url,
        crawl_strategy, is_active, crawl_interval_minutes, sort_order, updated_at)
     VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14, now())
     ON CONFLICT (source_key) DO UPDATE SET
       name = EXCLUDED.name,
       source_type = EXCLUDED.source_type,
       category_hint = EXCLUDED.category_hint,
       district = EXCLUDED.district,
       website_url = EXCLUDED.website_url,
       list_url = EXCLUDED.list_url,
       social_url = EXCLUDED.social_url,
       facebook_url = EXCLUDED.facebook_url,
       instagram_url = EXCLUDED.instagram_url,
       crawl_strategy = EXCLUDED.crawl_strategy,
       is_active = EXCLUDED.is_active,
       crawl_interval_minutes = EXCLUDED.crawl_interval_minutes,
       sort_order = EXCLUDED.sort_order,
       updated_at = now()
     RETURNING id, source_key, name, source_type, category_hint, district, website_url, list_url,
               social_url, facebook_url, instagram_url,
               crawl_strategy, selector_config, is_active, crawl_interval_minutes,
               last_checked_at, last_success_at, last_error, sort_order`,
    [
      sourceKey,
      name,
      validSourceType(input.sourceType),
      validCategory(input.categoryHint),
      normalizeDistrict((input as any).district),
      normalizeText(input.websiteUrl),
      listUrl,
      normalizeText(input.socialUrl),
      normalizeText((input as any).facebookUrl),
      normalizeText((input as any).instagramUrl),
      input.crawlStrategy || 'auto',
      input.isActive !== false,
      Math.max(5, Number(input.crawlIntervalMinutes || DEFAULT_UPDATE_INTERVAL_MINUTES)),
      Number(input.sortOrder || 500),
    ]
  );
  return rowToSource(result.rows[0]);
}

export async function deleteAnnouncementSource(id: string) {
  await dbQuery(`DELETE FROM public.announcement_sources WHERE id = $1`, [id]);
}

const rowToAdminAnnouncement = (row: any): AnnouncementItem => ({
  id: String(row.id || ''),
  category: validCategory(row.category),
  district: normalizeDistrict(row.district),
  source: String(row.source_name || ''),
  sourceKey: String(row.source_key || ''),
  title: String(row.title || ''),
  summary: String(row.summary || ''),
  body: String(row.body || ''),
  place: String(row.place || 'Niğde geneli'),
  timeLabel: String(row.time_label || displayTimeLabel(row.published_at || row.created_at)),
  statusLabel: String(row.status_label || ''),
  scheduleLabel: String(row.schedule_label || ''),
  imageUrl: String(row.image_url || ''),
  sourceUrl: String(row.source_url || ''),
  canonicalUrl: String(row.canonical_url || row.source_url || ''),
  linkedPostId: row.linked_post_id ? String(row.linked_post_id) : '',
  linkedPostTitle: String(row.linked_post_title || ''),
  linkedPostSlug: String(row.linked_post_slug || ''),
  linkedPostThumbnailUrl: String(row.linked_post_thumbnail_url || ''),
  linkedPost: rowToLinkedPost(row),
  publishedAt: String(row.published_at || row.created_at || ''),
  startsAt: String(row.starts_at || ''),
  endsAt: String(row.ends_at || ''),
  isActive: row.is_active !== false,
});

const rowToLinkedPost = (row: any): AnnouncementItem['linkedPost'] => {
  if (!row.linked_post_id || !row.linked_post_title) return null;
  return {
    id: String(row.linked_post_id),
    title: String(row.linked_post_title || ''),
    slug: String(row.linked_post_slug || ''),
    summary: String(row.linked_post_summary || ''),
    category: String(row.linked_post_category || ''),
    imageUrl: String(row.linked_post_thumbnail_url || ''),
    publishedAt: String(row.linked_post_published_at || ''),
  };
};

const ADMIN_ANNOUNCEMENT_SELECT = `a.id, a.source_id, a.source_key, a.category, a.district, a.source_name,
        a.title, a.summary, a.body, a.place, a.time_label, a.status_label,
        a.schedule_label, a.image_url, a.source_url, a.canonical_url,
        a.linked_post_id, a.published_at, a.starts_at, a.ends_at, a.created_at, a.updated_at,
        a.is_active,
        s.source_type, s.category_hint, s.website_url, s.list_url,
        s.social_url, s.facebook_url, s.instagram_url,
        p.title AS linked_post_title, p.slug AS linked_post_slug, p.summary AS linked_post_summary,
        p.category AS linked_post_category, p.thumbnail_url AS linked_post_thumbnail_url,
        p.published_at AS linked_post_published_at`;

async function getAdminAnnouncementById(id: string) {
  const result = await dbQuery(
    `SELECT ${ADMIN_ANNOUNCEMENT_SELECT}
     FROM public.announcements a
     LEFT JOIN public.announcement_sources s ON s.id = a.source_id
     LEFT JOIN public.posts p ON p.id = a.linked_post_id
     WHERE a.id = $1
     LIMIT 1`,
    [id]
  );
  if (!result.rows[0]) throw new Error('Duyuru bulunamadı');
  return rowToAdminAnnouncement(result.rows[0]);
}

export async function listAdminAnnouncements({
  includeInactive = true,
  search = '',
  dateFrom = '',
  dateTo = '',
  limit = 200,
} = {}) {
  const cleanSearch = normalizeText(search);
  const from = normalizeText(dateFrom);
  const to = normalizeText(dateTo);
  const sourceCount = await dbQuery(
    `SELECT count(*)::int AS count FROM public.announcement_sources WHERE is_active IS TRUE`
  ).catch(() => ({ rows: [{ count: 0 }] } as any));
  const result = await dbQuery(
    `SELECT ${ADMIN_ANNOUNCEMENT_SELECT}
     FROM public.announcements a
     LEFT JOIN public.announcement_sources s ON s.id = a.source_id
     LEFT JOIN public.posts p ON p.id = a.linked_post_id
     WHERE ($1::boolean IS TRUE OR a.is_active IS TRUE)
       AND (
         $2 = ''
         OR a.title ILIKE '%' || $2 || '%'
         OR a.summary ILIKE '%' || $2 || '%'
         OR a.body ILIKE '%' || $2 || '%'
         OR a.source_name ILIKE '%' || $2 || '%'
         OR a.place ILIKE '%' || $2 || '%'
         OR a.source_url ILIKE '%' || $2 || '%'
       )
       AND (NULLIF($3, '') IS NULL OR COALESCE(a.starts_at, a.published_at, a.created_at) >= NULLIF($3, '')::timestamptz)
       AND (NULLIF($4, '') IS NULL OR COALESCE(a.starts_at, a.published_at, a.created_at) < (NULLIF($4, '')::date + INTERVAL '1 day'))
     ORDER BY a.is_active DESC, COALESCE(a.starts_at, a.published_at, a.created_at) DESC
     LIMIT $5`,
    [includeInactive, cleanSearch, from, to, Math.min(Math.max(limit, 1), 500)]
  );
  const announcements = result.rows
    .filter(rowPassesPublicationDecision)
    .map(rowToAdminAnnouncement);
  return {
    city: CITY,
    citySlug: CITY_SLUG,
    source: 'Niğde Duyuru Ağı',
    sourceUrl: '',
    timezone: TIMEZONE,
    serviceDate: localParts().dateKey,
    serviceDateLabel: serviceDateLabel(),
    fetchedAt: new Date().toISOString(),
    updateIntervalMinutes: DEFAULT_UPDATE_INTERVAL_MINUTES,
    districts: DISTRICT_KEYS.map((key) => ({
      key,
      label: districtLabel(key),
      count: announcements.filter((item) => item.district === key && item.isActive !== false).length,
    })),
    announcements,
    meta: {
      total: announcements.length,
      officialCount: announcements.filter((item) => item.category === 'official' && item.isActive !== false).length,
      powerCount: announcements.filter((item) => item.category === 'power' && item.isActive !== false).length,
      roadCount: announcements.filter((item) => item.category === 'road' && item.isActive !== false).length,
      activeSources: Number(sourceCount.rows[0]?.count || 0),
    },
  } satisfies AnnouncementPayload;
}

const nullableDateValue = (value: unknown) => {
  const text = normalizeText(value);
  if (!text) return null;
  const date = new Date(text);
  if (Number.isNaN(date.getTime())) return null;
  return date.toISOString();
};

const nullablePostIdValue = (value: unknown) => {
  const text = normalizeText(value);
  if (!text) return null;
  const parsed = Number(text);
  if (!Number.isInteger(parsed) || parsed < 1) return null;
  return parsed;
};

const manualAnnouncementSource = (name = ''): AnnouncementSource => ({
  id: '',
  sourceKey: MANUAL_ANNOUNCEMENT_SOURCE_KEY,
  name: normalizeText(name) || MANUAL_ANNOUNCEMENT_SOURCE_NAME,
  sourceType: 'other',
  categoryHint: 'official',
  district: 'merkez',
  websiteUrl: '',
  listUrl: '',
  socialUrl: '',
  facebookUrl: '',
  instagramUrl: '',
  crawlStrategy: 'auto',
  selectorConfig: {},
  isActive: true,
  crawlIntervalMinutes: DEFAULT_UPDATE_INTERVAL_MINUTES,
  lastCheckedAt: '',
  lastSuccessAt: '',
  lastError: '',
  sortOrder: 0,
});

const MANUAL_ANNOUNCEMENT_AI_SCHEMA = {
  type: 'object',
  properties: {
    isPublishable: { type: 'boolean' },
    contentType: { type: 'string' },
    rejectReason: { type: 'string' },
    category: { type: 'string', enum: ['official', 'power', 'road'] },
    sourceName: { type: 'string' },
    title: { type: 'string' },
    summary: { type: 'string' },
    body: { type: 'string' },
    place: { type: 'string' },
    district: { type: 'string' },
    statusLabel: { type: 'string' },
    scheduleLabel: { type: 'string' },
    startsAt: { type: 'string' },
    endsAt: { type: 'string' },
    confidence: { type: 'number' },
  },
  required: ['isPublishable', 'contentType', 'category', 'title', 'summary', 'body', 'district', 'confidence'],
};

const parseManualAnnouncementAiJson = (value: string) => {
  const clean = normalizeText(value);
  if (!clean) return null;
  const candidates = [
    clean,
    clean.replace(/^```(?:json)?\s*/i, '').replace(/\s*```$/i, ''),
  ];
  const objectStart = clean.indexOf('{');
  const objectEnd = clean.lastIndexOf('}');
  if (objectStart >= 0 && objectEnd > objectStart) {
    candidates.push(clean.slice(objectStart, objectEnd + 1));
  }
  for (const candidate of candidates) {
    try {
      const parsed = JSON.parse(candidate);
      if (parsed && typeof parsed === 'object') return parsed as Record<string, any>;
    } catch {
      // Try the next normalized shape.
    }
  }
  return null;
};

const decodeManualAnnouncementImage = (input: Record<string, any>) => {
  const raw = normalizeText(input.imageBase64 ?? input.image_base64);
  if (!raw) return null;
  const fileName = normalizeText(input.imageFileName ?? input.image_file_name);
  const mimeType = normalizeText(input.imageMimeType ?? input.image_mime_type).split(';')[0] || 'image/jpeg';
  if (!mimeType.startsWith('image/')) throw new Error('Duyuru görseli geçerli bir resim değil');
  if (hasLogoImageSignal(fileName)) throw new Error('Logo/ikon duyuru görseli olarak eklenemez');

  const base64 = raw.includes(',') ? raw.split(',').pop() || '' : raw;
  const buffer = Buffer.from(base64, 'base64');
  if (!buffer.byteLength) throw new Error('Duyuru görseli okunamadı');
  if (buffer.byteLength > MAX_MANUAL_ANNOUNCEMENT_IMAGE_BYTES) {
    throw new Error('Duyuru görseli çok büyük');
  }
  return { buffer, mimeType, fileName };
};

const normalizeManualAnnouncementImageUrl = (input: Record<string, any>) => {
  const clean = normalizeText(input.imageUrl ?? input.image_url);
  if (!clean) return '';
  if (/^data:/i.test(clean)) throw new Error('Duyuru görseli URL olarak seçilmeli');
  if (hasLogoImageSignal(clean)) throw new Error('Logo/ikon duyuru görseli olarak eklenemez');
  return clean;
};

const imageMimeTypeFromPath = (value: string, fallback = 'image/jpeg') => {
  const clean = normalizeText(value).split(/[?#]/)[0].toLowerCase();
  if (clean.endsWith('.png')) return 'image/png';
  if (clean.endsWith('.webp')) return 'image/webp';
  if (clean.endsWith('.gif')) return 'image/gif';
  if (clean.endsWith('.avif')) return 'image/avif';
  if (clean.endsWith('.jpg') || clean.endsWith('.jpeg')) return 'image/jpeg';
  return fallback;
};

const manualAnnouncementLocalObjectPathFromUrl = (value: string) => {
  const clean = normalizeText(value);
  if (!clean) return '';
  let pathname = clean;
  let isAbsolute = false;
  let isLocalHost = false;
  try {
    const parsed = new URL(clean);
    const host = parsed.hostname.replace(/^www\./, '');
    isAbsolute = true;
    isLocalHost = ['pateez.com', 'localhost', '127.0.0.1'].includes(host);
    pathname = parsed.pathname;
  } catch {
    // Relative media library paths are handled below.
  }

  let normalized = pathname.replace(/\\/g, '/').replace(/^\/+/, '');
  try {
    normalized = decodeURIComponent(normalized);
  } catch {
    // Keep the original normalized value when the URL is not decodable.
  }
  const hasLocalMarker =
    normalized.startsWith('api/storage/file/') ||
    normalized.startsWith('local-upload/');
  if (isAbsolute && !isLocalHost && !hasLocalMarker) return '';

  normalized = normalized
    .replace(/^api\/storage\/file\//, '')
    .replace(/^local-upload\//, '');
  if (!normalized || normalized === '.' || normalized.startsWith('../') || normalized.split('/').includes('..')) {
    return '';
  }
  if (!/\.(?:jpe?g|png|webp|gif|avif)$/i.test(normalized)) return '';
  return normalized;
};

const readManualAnnouncementImageUrl = async (imageUrl: string, requestOrigin = '') => {
  const clean = normalizeText(imageUrl);
  if (!clean) return null;
  const objectPath = manualAnnouncementLocalObjectPathFromUrl(clean);
  if (objectPath) {
    try {
      const [fs, path] = await Promise.all([import('node:fs/promises'), import('node:path')]);
      const uploadRoot = path.resolve(process.cwd(), 'public', 'local-upload');
      const absolutePath = path.resolve(uploadRoot, objectPath);
      const relative = path.relative(uploadRoot, absolutePath);
      if (!relative || relative.startsWith('..') || path.isAbsolute(relative)) return null;
      const stat = await fs.stat(absolutePath);
      if (!stat.isFile() || stat.size > MAX_MANUAL_ANNOUNCEMENT_IMAGE_BYTES) return null;
      const buffer = await fs.readFile(absolutePath);
      if (!buffer.byteLength || buffer.byteLength > MAX_MANUAL_ANNOUNCEMENT_IMAGE_BYTES) return null;
      return { buffer, mimeType: imageMimeTypeFromPath(objectPath), fileName: objectPath.split('/').pop() || '' };
    } catch {
      // Production storage paths may be remote/redirected; fall back to HTTP fetch below.
    }
  }

  const fetchUrl = /^https?:\/\//i.test(clean)
    ? clean
    : toAbsoluteUrl(requestOrigin, clean);
  if (!fetchUrl) return null;
  try {
    const response = await fetch(fetchUrl, {
      signal: AbortSignal.timeout(AI_IMAGE_FETCH_TIMEOUT_MS),
      headers: {
        Accept: 'image/avif,image/webp,image/png,image/jpeg,image/*;q=0.7',
        'User-Agent': USER_AGENT,
      },
    });
    if (!response.ok) return null;
    const contentType = (response.headers.get('content-type') || '').split(';')[0].trim();
    if (!contentType.startsWith('image/')) return null;
    const contentLength = Number(response.headers.get('content-length') || 0);
    if (contentLength > MAX_MANUAL_ANNOUNCEMENT_IMAGE_BYTES) return null;
    const arrayBuffer = await response.arrayBuffer();
    const buffer = Buffer.from(arrayBuffer);
    if (!buffer.byteLength || buffer.byteLength > MAX_MANUAL_ANNOUNCEMENT_IMAGE_BYTES) return null;
    return { buffer, mimeType: contentType, fileName: fetchUrl.split(/[/?#]/).pop() || '' };
  } catch {
    return null;
  }
};

const manualAnnouncementAiImagePart = async (
  image: ReturnType<typeof decodeManualAnnouncementImage>,
  imageUrl = '',
  requestOrigin = '',
) => {
  try {
    let buffer = image?.buffer || null;
    let mimeType = image?.mimeType || '';
    if (!buffer && imageUrl) {
      const urlImage = await readManualAnnouncementImageUrl(imageUrl, requestOrigin);
      if (urlImage) {
        buffer = urlImage.buffer;
        mimeType = urlImage.mimeType;
      }
    }
    if (!buffer) return null;
    const supportedInlineType = /^image\/(?:jpeg|jpg|png|webp)$/i.test(mimeType);
    if (!image && !supportedInlineType) return null;
    if (image && (buffer.byteLength > MAX_AI_IMAGE_BYTES || !supportedInlineType)) {
      const { default: sharp } = await import('sharp');
      buffer = await sharp(buffer, { failOn: 'none' })
        .rotate()
        .resize({ width: 1280, withoutEnlargement: true })
        .jpeg({ quality: 72, mozjpeg: true })
        .toBuffer();
      mimeType = 'image/jpeg';
    }
    if (buffer.byteLength > MAX_AI_IMAGE_BYTES) return null;
    return {
      inlineData: {
        mimeType,
        data: buffer.toString('base64'),
      },
    };
  } catch {
    return null;
  }
};

const manualAnnouncementAiModelAttempts = (selectedModel: unknown) => {
  const selected = normalizeGeminiModelName(selectedModel);
  const lower = selected.toLowerCase();
  const selectedIsFast = Boolean(selected) && (
    lower.includes('flash') ||
    lower.includes('lite')
  ) && !lower.includes('pro');
  const attempts = [
    ...(selectedIsFast ? [selected] : []),
    'gemini-3.1-flash-lite',
    getOneLowerGeminiModel(selected),
    'gemini-2.5-flash-lite',
    'gemini-2.5-flash',
    ...(!selectedIsFast ? [selected] : []),
  ];
  const seen = new Set<string>();
  return attempts.filter((model) => {
    const key = normalizeGeminiModelName(model).toLowerCase();
    if (!key || seen.has(key)) return false;
    seen.add(key);
    return true;
  });
};

const geminiFetchFailure = (error: unknown) => {
  const message = error instanceof Error
    ? error.message
    : String(error || 'Gemini network error');
  const name = error && typeof error === 'object' && 'name' in error
    ? String((error as { name?: unknown }).name || '')
    : '';
  const text = `${name} ${message}`.toLowerCase();
  return {
    ok: false as const,
    status: text.includes('abort') || text.includes('timeout') ? 408 : 0,
    message: message || 'Gemini network error',
  };
};

const generateManualAnnouncementAi = async (
  settings: AiSettings,
  input: {
    text: string;
    notes: string;
    selectedDistrict: string;
    selectedSourceName: string;
    image: ReturnType<typeof decodeManualAnnouncementImage>;
    imageUrl: string;
    requestOrigin: string;
  },
) => {
  if (!settings.active || !settings.apiKey) {
    throw new Error('Google AI aktif değil veya API anahtarı eksik');
  }

  const prompt = `
Niğde yerel duyuru editörüsün. Kullanıcının manuel verdiği metni ve varsa görseldeki yazıları OCR ile okuyup sadece kanıtlanan bilgiyle JSON'a çevir.
Yeni bilgi uydurma. Metinde veya görselde yoksa alanı boş bırak. Kişi/kurum adı, tarih, mahalle, ilçe ve hizmet bilgisini tahmin etme.

Yayın kararı çok sıkı olsun:
- Elektrik kesintisi/arıza/bakım, su kesintisi, yol kapanması/trafik/güzergah, meteorolojik uyarı, valilik/kaymakamlık kamu düzeni kararı, belediye şehir hizmeti kesintisi, okul tatili/eğitime ara, LGS/YKS/KPSS/ALES/DGS gibi şehir geneli sınav ulaşım/nüfus hizmeti veya üreticiye resmi tarım hastalık/zararlı/zirai uyarısı varsa isPublishable true.
- Jandarma/emniyet rutin raporu, operasyon haberi, siber suç/eğitim semineri, ziyaret, tören, açılış, kurs, sergi, kitapçık, enerji verimliliği tanıtımı, genel etkinlik/tanıtım, bilimsel kongre, kutlama, tebrik, anma, resmi ilan, ihale, personel/staj alımı, genel haber, liste/arşiv metni veya Niğde ilgisi kanıtlanmayan içerikte isPublishable false.
- Kategori sadece official, power veya road olabilir.
- road sadece yol kapanması, trafik, güzergah veya yol çalışması kanıtlıysa kullan.
- power sadece elektrik kesintisi/arıza/bakım/trafo/şebeke bilgisi kanıtlıysa kullan.
- Başlık kısa, açık ve duyurunun etkisini anlatan Türkçe bir başlık olsun.
- Özet tek cümle veya iki kısa cümle olsun; kaynağın söylemediği sonucu ekleme.
- Body alanı görsel/metindeki kanıtı korusun ama 900 karakteri geçmesin.

Seçili ilçe: ${input.selectedDistrict || 'AI belirlesin'}
Girilen kaynak/kurum: ${input.selectedSourceName || 'Belirtilmedi'}
Görsel adresi: ${input.imageUrl || '-'}
Ek not:
${input.notes.slice(0, 1200) || '-'}

Manuel metin:
${input.text.slice(0, 5000) || '-'}

JSON alanları:
isPublishable, contentType, rejectReason, category, sourceName, title, summary, body, place, district, statusLabel, scheduleLabel, startsAt, endsAt, confidence
  `;
  const imagePart = await manualAnnouncementAiImagePart(input.image, input.imageUrl, input.requestOrigin);
  if (!input.text && (input.image || input.imageUrl) && !imagePart) {
    throw new Error('Görsel AI tarafından okunacak boyuta indirilemedi');
  }

  const makePayload = (modelId: string) => {
    const generationConfig: Record<string, unknown> = {
      temperature: 0.05,
      topK: 12,
      topP: 0.7,
      maxOutputTokens: 4096,
      responseMimeType: 'application/json',
      responseSchema: MANUAL_ANNOUNCEMENT_AI_SCHEMA,
    };
    const thinkingConfig = geminiThinkingConfigForModel(modelId);
    if (thinkingConfig) generationConfig.thinkingConfig = thinkingConfig;
    return {
      contents: [{ parts: [{ text: prompt }, ...(imagePart ? [imagePart] : [])] }],
      generationConfig,
    };
  };

  const call = async (apiVersion: 'v1beta' | 'v1', modelId: string) => {
    try {
      const response = await fetch(
        `https://generativelanguage.googleapis.com/${apiVersion}/models/${encodeURIComponent(modelId)}:generateContent?key=${encodeURIComponent(settings.apiKey)}`,
        {
          method: 'POST',
          signal: AbortSignal.timeout(MANUAL_GEMINI_TIMEOUT_MS),
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify(makePayload(modelId)),
        }
      );
      const data = await response.json().catch(() => ({}));
      if (!response.ok || data?.error) {
        return {
          ok: false as const,
          status: response.status,
          message: data?.error?.message || `Gemini HTTP ${response.status}`,
        };
      }
      return { ok: true as const, data };
    } catch (error) {
      return geminiFetchFailure(error);
    }
  };

  const queue = manualAnnouncementAiModelAttempts(settings.model || 'gemini-2.5-flash');
  let lastError = '';

  for (const model of queue) {
    let result = await call('v1beta', model);
    if (!result.ok && result.status === 404) result = await call('v1', model);
    if (result.ok) {
      const candidate = result.data?.candidates?.[0];
      const text = Array.isArray(candidate?.content?.parts)
        ? candidate.content.parts.map((part: any) => String(part?.text || '')).join('')
        : '';
      const parsed = parseManualAnnouncementAiJson(text);
      if (parsed) return parsed;
      const finishReason = normalizeText(candidate?.finishReason);
      lastError = finishReason
        ? `Gemini cevabı tamamlanmadı veya JSON okunamadı (${finishReason})`
        : 'Gemini boş veya okunamayan JSON döndürdü';
      continue;
    }
    lastError = result.message;
    if (!isGeminiFallbackWorthTrying(result.status, result.message)) break;
  }

  throw new Error(lastError ? `AI duyuruyu işleyemedi: ${lastError}` : 'AI duyuruyu işleyemedi');
};

const manualAnnouncementContentHash = (candidate: Candidate) =>
  hash([
    'manual',
    trLower(candidate.source.name),
    trLower(candidate.title),
    trLower(candidate.summary),
    trLower(candidate.body).slice(0, 1600),
    candidate.startsAt.slice(0, 10),
    candidate.endsAt.slice(0, 10),
  ].join('|'));

const upsertManualAnnouncementCandidate = async (
  candidate: Candidate,
  image: ReturnType<typeof decodeManualAnnouncementImage>,
  selectedImageUrl = '',
) => {
  const contentHash = manualAnnouncementContentHash(candidate);
  const existing = await dbQuery(
    `SELECT id, image_url
     FROM public.announcements
     WHERE content_hash = $1
     LIMIT 1`,
    [contentHash],
  );
  const providedImageUrl = normalizeText(selectedImageUrl);
  const imageResult = image && !providedImageUrl
    ? await writeAnnouncementImageBuffer(image.buffer, contentHash, candidate.publishedAt)
    : { url: '', width: null as number | null, height: null as number | null };
  if (image && !providedImageUrl && !imageResult.url) {
    throw new Error('Duyuru görseli gerçek duyuru görseli olarak doğrulanamadı');
  }
  const imageUrl = providedImageUrl || imageResult.url;
  const oldImageUrl = String(existing.rows[0]?.image_url || '');

  const result = await dbQuery(
    `INSERT INTO public.announcements
       (source_id, source_key, source_name, category, district, title, summary, body, place,
        time_label, published_at, starts_at, ends_at, status_label, schedule_label, image_url,
        source_url, canonical_url, content_hash, raw_payload, ai_payload, confidence, is_active)
     VALUES
       (NULL, $1, $2, $3, $4, $5, $6, $7, $8,
        $9, $10, $11, $12, $13, $14, $15,
        '', '', $16, $17::jsonb, $18::jsonb, $19, TRUE)
     ON CONFLICT (content_hash) DO UPDATE SET
       source_name = EXCLUDED.source_name,
       category = EXCLUDED.category,
       district = EXCLUDED.district,
       title = EXCLUDED.title,
       summary = EXCLUDED.summary,
       body = EXCLUDED.body,
       place = EXCLUDED.place,
       time_label = EXCLUDED.time_label,
       published_at = EXCLUDED.published_at,
       starts_at = EXCLUDED.starts_at,
       ends_at = EXCLUDED.ends_at,
       status_label = EXCLUDED.status_label,
       schedule_label = EXCLUDED.schedule_label,
       image_url = EXCLUDED.image_url,
       raw_payload = EXCLUDED.raw_payload,
       ai_payload = EXCLUDED.ai_payload,
       confidence = EXCLUDED.confidence,
       is_active = TRUE,
       updated_at = now()
     RETURNING id`,
    [
      candidate.source.sourceKey,
      candidate.source.name,
      candidate.category,
      candidate.district,
      candidate.title,
      candidate.summary,
      candidate.body,
      candidate.place,
      displayTimeLabel(candidate.publishedAt),
      candidate.publishedAt,
      nullableDateValue(candidate.startsAt),
      nullableDateValue(candidate.endsAt),
      candidate.statusLabel,
      candidate.scheduleLabel,
      imageUrl,
      contentHash,
      JSON.stringify(candidate.rawPayload),
      JSON.stringify(candidate.aiPayload || {}),
      candidate.confidence,
    ],
  );
  const id = String(result.rows[0]?.id || '');
  if (!id) throw new Error('Duyuru kaydedilemedi');
  if (oldImageUrl && oldImageUrl !== imageUrl) {
    await dbQuery(
      `DELETE FROM public.announcement_media
       WHERE announcement_id = $1 AND url = $2`,
      [id, oldImageUrl],
    );
    await deleteLocalAnnouncementImageFiles([oldImageUrl]);
  }
  if (imageUrl) {
    await dbQuery(
      `INSERT INTO public.announcement_media (announcement_id, url, alt_text, source_url, width, height)
       VALUES ($1, $2, $3, '', $4, $5)
       ON CONFLICT (announcement_id, url) DO UPDATE SET
         alt_text = EXCLUDED.alt_text,
         width = EXCLUDED.width,
         height = EXCLUDED.height`,
      [id, imageUrl, candidate.title, imageResult.width, imageResult.height],
    );
  }
  return id;
};

export async function createManualAnnouncementWithAi(input: Record<string, any>) {
  const text = normalizeText(input.text ?? input.content ?? input.body);
  const notes = normalizeText(input.notes);
  const selectedDistrict = normalizeText(input.district);
  const selectedSourceName = normalizeText(input.sourceName ?? input.source_name);
  const image = decodeManualAnnouncementImage(input);
  const imageUrl = normalizeManualAnnouncementImageUrl(input);
  const requestOrigin = normalizeText(input.requestOrigin ?? input.request_origin ?? input.origin);
  if (!text && !image && !imageUrl) throw new Error('Duyuru metni veya görsel gerekli');

  const settings = await fetchAiSettings();
  const ai = await generateManualAnnouncementAi(settings, {
    text,
    notes,
    selectedDistrict,
    selectedSourceName,
    image,
    imageUrl,
    requestOrigin,
  });
  if (!ai) throw new Error('AI duyuruyu işleyemedi');
  const rejectReason = aiRejectReason(ai);
  if (rejectReason) throw new Error(`AI duyuruyu uygun bulmadı: ${rejectReason}`);

  const publishedAt = new Date().toISOString();
  const aiBody = normalizeText(ai.body) || text;
  const body = text && !aiBody.includes(text) ? `${aiBody}\n\n${text}` : aiBody;
  const title = normalizeText(ai.title);
  if (!title) throw new Error('AI duyuru başlığı üretemedi');
  const summary = summarize(normalizeText(ai.summary) || body, title);
  const eventWindow = extractEventWindow(`${title} ${summary} ${body}`, publishedAt);
  const startsAt = aiDateIso(ai.startsAt) || eventWindow.startsAt;
  const endsAt = aiDateIso(ai.endsAt) || eventWindow.endsAt;
  const sourceName = normalizeText(ai.sourceName) || selectedSourceName || MANUAL_ANNOUNCEMENT_SOURCE_NAME;
  const district = districtFromText(`${normalizeText(ai.district)} ${normalizeText(ai.place)} ${title} ${summary} ${body}`) ||
    normalizeDistrict(selectedDistrict || ai.district);
  const candidate: Candidate = {
    source: manualAnnouncementSource(sourceName),
    title,
    summary,
    body,
    place: normalizeText(ai.place) || districtLabel(district),
    district,
    publishedAt,
    startsAt,
    endsAt,
    statusLabel: normalizeText(ai.statusLabel) || 'Yayında',
    scheduleLabel: normalizeText(ai.scheduleLabel),
    imageUrl: imageUrl || (image ? 'manual-upload' : ''),
    sourceUrl: '',
    canonicalUrl: '',
    category: validCategory(ai.category),
    confidence: Math.max(0.72, Math.min(1, Number(ai.confidence || 0) || 0)),
    rawPayload: {
      source: 'manual-admin',
      text,
      notes,
      imageUrl,
      imageFileName: image?.fileName || '',
    },
    aiPayload: ai,
  };

  const decision = publicationDecision(candidate);
  if (!decision.ok) throw new Error(`Duyuru şehir için uygun bulunmadı: ${decision.reason}`);
  if (!isCandidateCurrent(candidate)) {
    candidate.startsAt = '';
    candidate.endsAt = '';
  }

  const id = await upsertManualAnnouncementCandidate(candidate, image, imageUrl);
  return getAdminAnnouncementById(id);
}

export async function updateAnnouncement(input: Record<string, any>) {
  const id = normalizeText(input.id);
  if (!id) throw new Error('Duyuru id gerekli');
  const title = normalizeText(input.title);
  if (!title) throw new Error('Duyuru başlığı gerekli');
  const result = await dbQuery(
    `UPDATE public.announcements
     SET category = $2,
         district = $3,
         title = $4,
         summary = $5,
         body = $6,
         place = $7,
         status_label = $8,
         schedule_label = $9,
         image_url = $10,
         source_url = $11,
         canonical_url = $12,
         published_at = COALESCE($13::timestamptz, published_at),
         starts_at = $14::timestamptz,
         ends_at = $15::timestamptz,
         is_active = $16,
         linked_post_id = $17::bigint,
         updated_at = now()
     WHERE id = $1
     RETURNING id`,
    [
      id,
      validCategory(input.category),
      normalizeDistrict(input.district),
      title,
      normalizeText(input.summary),
      normalizeText(input.body),
      normalizeText(input.place) || 'Niğde geneli',
      normalizeText(input.statusLabel ?? input.status_label),
      normalizeText(input.scheduleLabel ?? input.schedule_label),
      normalizeText(input.imageUrl ?? input.image_url),
      normalizeText(input.sourceUrl ?? input.source_url),
      normalizeText(input.canonicalUrl ?? input.canonical_url),
      nullableDateValue(input.publishedAt ?? input.published_at),
      nullableDateValue(input.startsAt ?? input.starts_at),
      nullableDateValue(input.endsAt ?? input.ends_at),
      input.isActive !== false && input.is_active !== false,
      nullablePostIdValue(input.linkedPostId ?? input.linked_post_id),
    ]
  );
  if (!result.rows[0]) throw new Error('Duyuru bulunamadı');
  return getAdminAnnouncementById(String(result.rows[0].id || id));
}

export async function setAnnouncementActive(id: string, isActive: boolean) {
  const result = await dbQuery(
    `UPDATE public.announcements
     SET is_active = $2, updated_at = now()
     WHERE id = $1
     RETURNING id`,
    [id, isActive]
  );
  if (!result.rows[0]) throw new Error('Duyuru bulunamadı');
  return getAdminAnnouncementById(String(result.rows[0].id || id));
}

const localAnnouncementObjectPathFromUrl = (value: string) => {
  const clean = normalizeText(value);
  if (!clean) return '';
  let pathname = clean;
  try {
    const parsed = new URL(clean);
    const host = parsed.hostname.replace(/^www\./, '');
    const isLocalHost = ['pateez.com', 'localhost', '127.0.0.1'].includes(host);
    const isLocalAnnouncementPath =
      parsed.pathname.includes('/local-upload/announcements/') ||
      parsed.pathname.includes('/api/storage/file/image/announcements/');
    if (!isLocalHost && !isLocalAnnouncementPath) return '';
    pathname = parsed.pathname;
  } catch {
    // Relative local paths are handled below.
  }
  let normalized = pathname.replace(/\\/g, '/').replace(/^\/+/, '');
  try {
    normalized = decodeURIComponent(normalized);
  } catch {
    // Keep the original normalized value when the URL is not decodable.
  }
  normalized = normalized
    .replace(/^api\/storage\/file\/image\//, '')
    .replace(/^local-upload\//, '');
  if (!normalized.startsWith('announcements/')) return '';
  if (normalized.split('/').includes('..')) return '';
  return normalized;
};

const deleteLocalAnnouncementImageFiles = async (urls: string[]) => {
  const objectPaths = [...new Set(urls.map(localAnnouncementObjectPathFromUrl).filter(Boolean))];
  if (!objectPaths.length) return [] as string[];

  const [fs, path] = await Promise.all([import('node:fs/promises'), import('node:path')]);
  const uploadRoot = path.resolve(process.cwd(), 'public', 'local-upload');
  const announcementRoot = path.resolve(uploadRoot, 'announcements');
  const deleted: string[] = [];

  const isInside = (base: string, target: string) => {
    const relative = path.relative(base, target);
    return relative === '' || (!!relative && !relative.startsWith('..') && !path.isAbsolute(relative));
  };

  for (const objectPath of objectPaths) {
    const absolutePath = path.resolve(uploadRoot, objectPath);
    if (!isInside(announcementRoot, absolutePath)) continue;
    try {
      const stat = await fs.stat(absolutePath);
      if (!stat.isFile()) continue;
      await fs.unlink(absolutePath);
      deleted.push(`/local-upload/${objectPath}`);

      let directory = path.dirname(absolutePath);
      while (isInside(announcementRoot, directory) && directory !== announcementRoot) {
        try {
          await fs.rmdir(directory);
          directory = path.dirname(directory);
        } catch {
          break;
        }
      }
    } catch {
      // Missing local files are already clean; remote URLs are ignored.
    }
  }

  return deleted;
};

export async function deleteAnnouncement(id: string) {
  const result = await deleteAnnouncements([id]);
  if (!result.ids.length) throw new Error('Duyuru bulunamadı');
  return { id: String(result.ids[0] || id) };
}

export async function deleteAnnouncements(ids: string[]) {
  const cleanIds = ids
    .map((id) => String(id || '').trim())
    .filter((id) => id.length > 0);
  if (!cleanIds.length) return { count: 0, ids: [] as string[], mediaCount: 0, deletedFiles: 0 };
  const mediaUrls = await dbQuery(
    `SELECT image_url AS url
     FROM public.announcements
     WHERE id = ANY($1::uuid[]) AND NULLIF(image_url, '') IS NOT NULL
     UNION
     SELECT url
     FROM public.announcement_media
     WHERE announcement_id = ANY($1::uuid[]) AND NULLIF(url, '') IS NOT NULL`,
    [cleanIds],
  );
  const deletedMedia = await dbQuery(
    `DELETE FROM public.announcement_media
     WHERE announcement_id = ANY($1::uuid[])
     RETURNING url`,
    [cleanIds],
  );
  const result = await dbQuery(
    `DELETE FROM public.announcements WHERE id = ANY($1::uuid[]) RETURNING id, image_url`,
    [cleanIds],
  );
  const deletedFiles = await deleteLocalAnnouncementImageFiles([
    ...mediaUrls.rows.map((row) => String(row.url || '')),
    ...deletedMedia.rows.map((row) => String(row.url || '')),
    ...result.rows.map((row) => String(row.image_url || '')),
  ]);
  return {
    count: Number(result.rowCount || 0),
    ids: result.rows.map((row) => String(row.id || '')),
    mediaCount: Number(deletedMedia.rowCount || 0),
    deletedFiles: deletedFiles.length,
  };
}

export async function getAnnouncementPayload({ category = '', district = '', limit = 80 } = {}) {
  const sourceCount = await dbQuery(`SELECT count(*)::int AS count FROM public.announcement_sources WHERE is_active IS TRUE`).catch(() => ({ rows: [{ count: 0 }] } as any));
  const todayStart = localDateStartIso();
  const recentStart = recentWithoutEventStartIso();
  const result = await dbQuery(
    `SELECT a.id, a.source_id, a.source_key, a.category, a.district, a.source_name,
            a.title, a.summary, a.body, a.place, a.time_label, a.status_label,
            a.schedule_label, a.image_url, a.source_url, a.canonical_url,
            a.linked_post_id, a.published_at, a.starts_at, a.ends_at, a.created_at,
            s.source_type, s.category_hint, s.website_url, s.list_url,
            s.social_url, s.facebook_url, s.instagram_url,
            p.title AS linked_post_title, p.slug AS linked_post_slug,
            p.summary AS linked_post_summary, p.category AS linked_post_category,
            p.thumbnail_url AS linked_post_thumbnail_url,
            p.published_at AS linked_post_published_at
     FROM public.announcements a
     LEFT JOIN public.announcement_sources s ON s.id = a.source_id
     LEFT JOIN public.posts p ON p.id = a.linked_post_id AND p.status = 'published'
     WHERE a.is_active IS TRUE
       AND (a.ends_at IS NULL OR a.ends_at >= $1::timestamptz)
       AND (a.starts_at IS NOT NULL OR a.ends_at IS NOT NULL OR COALESCE(a.published_at, a.created_at) >= $2::timestamptz)
     ORDER BY COALESCE(a.starts_at, a.published_at, a.created_at) DESC
     LIMIT $3`,
    [todayStart, recentStart, MAX_PAYLOAD_SCAN_ROWS]
  );

  const cleanRows = result.rows.filter(rowPassesPublicationDecision);

  const allAnnouncements: AnnouncementItem[] = cleanRows.map((row: any) => ({
    id: String(row.id || ''),
    category: validCategory(row.category),
    district: normalizeDistrict(row.district),
    source: String(row.source_name || ''),
    title: String(row.title || ''),
    summary: String(row.summary || ''),
    body: String(row.body || ''),
    place: String(row.place || 'Niğde geneli'),
    timeLabel: String(row.time_label || displayTimeLabel(row.published_at || row.created_at)),
    statusLabel: String(row.status_label || ''),
    scheduleLabel: String(row.schedule_label || ''),
    imageUrl: String(row.image_url || ''),
    sourceUrl: String(row.source_url || ''),
    canonicalUrl: String(row.canonical_url || row.source_url || ''),
    linkedPostId: row.linked_post_id ? String(row.linked_post_id) : '',
    linkedPostTitle: String(row.linked_post_title || ''),
    linkedPostSlug: String(row.linked_post_slug || ''),
    linkedPostThumbnailUrl: String(row.linked_post_thumbnail_url || ''),
    linkedPost: rowToLinkedPost(row),
    publishedAt: String(row.published_at || row.created_at || ''),
    startsAt: String(row.starts_at || ''),
    endsAt: String(row.ends_at || ''),
  }));
  const normalizedCategory = validCategory(category) === category ? category as AnnouncementCategory : '';
  const normalizedDistrict = normalizeText(district) ? normalizeDistrict(district) : '';
  const announcements = allAnnouncements
    .filter((item) => !normalizedCategory || item.category === normalizedCategory)
    .filter((item) => !normalizedDistrict || item.district === normalizedDistrict)
    .slice(0, Math.min(Math.max(limit, 1), 150));
  const districtCounts = new Map<string, number>();
  for (const item of allAnnouncements) {
    districtCounts.set(item.district, (districtCounts.get(item.district) || 0) + 1);
  }

  return {
    city: CITY,
    citySlug: CITY_SLUG,
    source: 'Niğde Duyuru Ağı',
    sourceUrl: '',
    timezone: TIMEZONE,
    serviceDate: localParts().dateKey,
    serviceDateLabel: serviceDateLabel(),
    fetchedAt: new Date().toISOString(),
    updateIntervalMinutes: DEFAULT_UPDATE_INTERVAL_MINUTES,
    districts: DISTRICT_KEYS.map((key) => ({
      key,
      label: districtLabel(key),
      count: districtCounts.get(key) || 0,
    })),
    announcements,
    meta: {
      total: allAnnouncements.length,
      officialCount: allAnnouncements.filter((item) => item.category === 'official').length,
      powerCount: allAnnouncements.filter((item) => item.category === 'power').length,
      roadCount: allAnnouncements.filter((item) => item.category === 'road').length,
      activeSources: Number(sourceCount.rows[0]?.count || 0),
    },
  } satisfies AnnouncementPayload;
}

export async function listAnnouncementRuns({ limit = 30 } = {}) {
  const result = await dbQuery(
    `SELECT r.id, r.run_type, r.status, r.started_at, r.finished_at,
            r.candidates_found, r.inserted_count, r.updated_count, r.skipped_count,
            r.error_message, s.name AS source_name
     FROM public.announcement_crawl_runs r
     LEFT JOIN public.announcement_sources s ON s.id = r.source_id
     ORDER BY r.started_at DESC
     LIMIT $1`,
    [Math.min(Math.max(limit, 1), 100)]
  );
  return result.rows;
}
