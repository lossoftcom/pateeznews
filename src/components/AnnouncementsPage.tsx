import React, { useEffect, useMemo, useState } from 'react';
import RemixIcon from '@/components/ui/RemixIcon';
import { navigateImmediately } from '@/utils/immediateNavigation';
import { openSiteSearch } from '@/utils/searchNavigation';

type AnnouncementCategory = 'official' | 'power' | 'road';

type AnnouncementLinkedPost = {
  id?: string;
  title?: string;
  slug?: string;
  summary?: string;
  category?: string;
  imageUrl?: string;
  publishedAt?: string;
};

type AnnouncementItem = {
  id: string;
  category: AnnouncementCategory;
  source: string;
  title: string;
  summary: string;
  body?: string;
  place: string;
  district: string;
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
  linkedPost?: AnnouncementLinkedPost | null;
  publishedAt: string;
  startsAt: string;
  endsAt: string;
};

type AnnouncementPayload = {
  city: string;
  serviceDateLabel: string;
  updateIntervalMinutes: number;
  announcements: AnnouncementItem[];
  meta?: {
    total?: number;
    officialCount?: number;
    powerCount?: number;
    roadCount?: number;
  };
  error?: string;
};

const EMPTY_DATA: AnnouncementPayload = {
  city: 'Niğde',
  serviceDateLabel: '',
  updateIntervalMinutes: 30,
  announcements: [],
};

const CATEGORY_META: Record<AnnouncementCategory, { label: string; longLabel: string; color: string; icon: string }> = {
  official: { label: 'Resmî', longLabel: 'Resmî Duyuru', color: '#2F6F9F', icon: 'ri-building-4-line' },
  power: { label: 'Elektrik', longLabel: 'Elektrik Kesintisi', color: '#E59A22', icon: 'ri-flashlight-fill' },
  road: { label: 'Yol', longLabel: 'Yol Durumu', color: '#2F8F67', icon: 'ri-navigation-fill' },
};

const WEEKDAY_SHORT = ['Pzt', 'Sal', 'Çar', 'Per', 'Cum', 'Cmt', 'Paz'];
const MONTH_NAMES = ['Ocak', 'Şubat', 'Mart', 'Nisan', 'Mayıs', 'Haziran', 'Temmuz', 'Ağustos', 'Eylül', 'Ekim', 'Kasım', 'Aralık'];

const validCategory = (value: unknown): AnnouncementCategory => {
  const raw = String(value || '').trim().toLowerCase();
  return raw === 'power' || raw === 'road' ? raw : 'official';
};

const compactText = (value: unknown) => String(value || '').replace(/\s+/g, ' ').trim();

const formatFullDate = (date: Date) => `${date.getDate()} ${MONTH_NAMES[date.getMonth()]} ${date.getFullYear()}`;

const startOfToday = () => {
  const now = new Date();
  return new Date(now.getFullYear(), now.getMonth(), now.getDate());
};

const addDays = (date: Date, days: number) => {
  const next = new Date(date);
  next.setDate(next.getDate() + days);
  return next;
};

const sameDay = (a: Date, b: Date) => (
  a.getFullYear() === b.getFullYear() &&
  a.getMonth() === b.getMonth() &&
  a.getDate() === b.getDate()
);

const weekdayShort = (date: Date) => WEEKDAY_SHORT[(date.getDay() + 6) % 7];

const sourceHost = (value: string) => {
  try {
    return new URL(value).hostname.replace(/^www\./, '') || 'Kaynak';
  } catch {
    return 'Kaynak';
  }
};

const postHrefFor = (item: AnnouncementItem) => {
  const slug = compactText(item.linkedPost?.slug || item.linkedPostSlug);
  return slug ? `/haber/${encodeURIComponent(slug)}` : '';
};

const placeLabelFor = (value: string) => {
  const clean = compactText(value);
  if (!clean) return 'Niğde geneli';
  const normalized = clean
    .toLocaleLowerCase('tr-TR')
    .replaceAll('ı', 'i')
    .replaceAll('ğ', 'g')
    .replaceAll('ü', 'u')
    .replaceAll('ş', 's')
    .replaceAll('ö', 'o')
    .replaceAll('ç', 'c');
  const districtCount = ['merkez', 'altunhisar', 'bor', 'camardi', 'ciftlik', 'ulukisla']
    .filter((district) => normalized.includes(district)).length;
  return districtCount >= 3 ? 'Niğde geneli' : clean;
};

const statusColor = (item: AnnouncementItem) => {
  const status = compactText(item.statusLabel).toLocaleLowerCase('tr-TR');
  if (status === 'kapalı' || status === 'arıza') return '#EA4335';
  if (status === 'açık') return '#2F8F67';
  if (status === 'planlı' || status === 'çalışma' || status === 'uyarı') return '#E59A22';
  return CATEGORY_META[validCategory(item.category)].color;
};

const dateLabelFromIso = (value: string) => {
  const parsed = new Date(value);
  if (!value || Number.isNaN(parsed.getTime())) return '';
  const two = (number: number) => String(number).padStart(2, '0');
  const date = `${two(parsed.getDate())}.${two(parsed.getMonth() + 1)}.${parsed.getFullYear()}`;
  const hasTime = parsed.getHours() !== 0 || parsed.getMinutes() !== 0;
  return hasTime ? `${date} ${two(parsed.getHours())}:${two(parsed.getMinutes())}` : date;
};

const announcementDateInfo = (item: AnnouncementItem) => {
  const parts: string[] = [];
  const published = dateLabelFromIso(item.publishedAt);
  if (published) parts.push(`Yayın: ${published}`);
  else if (compactText(item.timeLabel)) parts.push(`Yayın: ${compactText(item.timeLabel)}`);
  const starts = dateLabelFromIso(item.startsAt);
  if (starts) parts.push(`Başlangıç: ${starts}`);
  const ends = dateLabelFromIso(item.endsAt);
  if (ends) parts.push(`Bitiş: ${ends}`);
  return parts.join(' · ');
};

const announcementDetailText = (item: AnnouncementItem) => {
  const summary = compactText(item.summary);
  const body = compactText(item.body);
  if (!summary) return body;
  if (!body) return summary;
  const lowerSummary = summary.toLocaleLowerCase('tr-TR');
  const lowerBody = body.toLocaleLowerCase('tr-TR');
  if (lowerBody.includes(lowerSummary) || lowerSummary.includes(lowerBody)) {
    return body.length >= summary.length ? body : summary;
  }
  return `${summary}\n\n${body}`;
};

const CountChip: React.FC<{
  label: string;
  count: number;
  color: string;
  selected: boolean;
  onClick: () => void;
}> = ({ label, count, color, selected, onClick }) => (
  <button
    type="button"
    className={selected ? 'is-selected' : ''}
    onClick={onClick}
    style={{ '--announcement-chip-color': color } as React.CSSProperties}
  >
    <span aria-hidden="true" />
    <strong>{label}</strong>
    <small>{count}</small>
  </button>
);

const AnnouncementsPage: React.FC = () => {
  const [data, setData] = useState<AnnouncementPayload>(EMPTY_DATA);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');
  const [filter, setFilter] = useState<AnnouncementCategory | null>(null);
  const [viewerItem, setViewerItem] = useState<AnnouncementItem | null>(null);
  const [today] = useState(() => startOfToday());
  const [selectedDate, setSelectedDate] = useState(() => startOfToday());

  useEffect(() => {
    const controller = new AbortController();
    const timeout = window.setTimeout(() => controller.abort(), 13000);

    setLoading(true);
    fetch('/api/app/announcements?city=nigde&limit=80', {
      headers: { Accept: 'application/json' },
      signal: controller.signal,
    })
      .then(async (response) => {
        const payload = await response.json().catch(() => null);
        if (!payload || typeof payload !== 'object') throw new Error('Duyurular alınamadı');
        setData({
          city: String(payload.city || 'Niğde'),
          serviceDateLabel: String(payload.serviceDateLabel || ''),
          updateIntervalMinutes: Number(payload.updateIntervalMinutes || 30),
          announcements: Array.isArray(payload.announcements)
            ? payload.announcements.map((item: any) => ({ ...item, category: validCategory(item?.category) }))
            : [],
          meta: payload.meta && typeof payload.meta === 'object' ? payload.meta : undefined,
          error: String(payload.error || ''),
        });
        if (!response.ok && payload.error) setError(String(payload.error));
      })
      .catch(() => setError('Duyurular alınamadı'))
      .finally(() => {
        window.clearTimeout(timeout);
        setLoading(false);
      });

    return () => {
      window.clearTimeout(timeout);
      controller.abort();
    };
  }, []);

  const allItems = data.announcements;
  const visibleItems = filter ? allItems.filter((item) => item.category === filter) : allItems;
  const dateRange = useMemo(() => Array.from({ length: 14 }, (_, index) => addDays(today, index)), [today]);

  const countFor = (category: AnnouncementCategory) => allItems.filter((item) => item.category === category).length;
  const serviceDateLabel = data.serviceDateLabel || formatFullDate(today);

  const goBack = () => {
    if (window.history.length > 1) {
      window.history.back();
      return;
    }
    void navigateImmediately('/');
  };

  const openSearch = () => {
    void openSiteSearch();
  };

  const openAnnouncement = (item: AnnouncementItem) => {
    const postHref = postHrefFor(item);
    if (postHref) {
      void navigateImmediately(postHref);
      return;
    }
    const href = item.sourceUrl || item.canonicalUrl;
    if (href) window.open(href, '_blank', 'noopener,noreferrer');
  };

  return (
    <main className="announcements-mobile-page" aria-label="Duyurular">
      <div className="announcements-shell">
        <header className="announcements-appbar">
          <button type="button" className="announcements-icon-button announcements-search-button" onClick={openSearch} aria-label="Ara">
            <RemixIcon name="ri-search-line" size={25} />
          </button>
          <div className="announcements-appbar-title">
            <span aria-hidden="true" />
            <strong>Duyurular</strong>
          </div>
          <button type="button" className="announcements-back-button" onClick={goBack} aria-label="Geri">
            <RemixIcon name="ri-arrow-left-line" size={22} />
          </button>
        </header>

        <section className="announcements-content">
          {allItems.length > 0 ? (
            <>
              <div className="announcements-hero-card">
                <div className="announcements-hero-icon">
                  <RemixIcon name="ri-notification-3-line" size={23} />
                </div>
                <div className="announcements-hero-copy">
                  <p>
                    <span aria-hidden="true" />
                    {data.city || 'Niğde'} · {serviceDateLabel}
                  </p>
                  <h1>Duyuru Merkezi</h1>
                  <small>Valilik · belediye · kurum</small>
                </div>
                <CountChip
                  label="Tümü"
                  count={allItems.length}
                  color="#2C3E50"
                  selected={filter === null}
                  onClick={() => setFilter(null)}
                />
              </div>

              <div className="announcements-filter-row" aria-label="Duyuru türleri">
                {(Object.keys(CATEGORY_META) as AnnouncementCategory[]).map((category) => (
                  <CountChip
                    key={category}
                    label={CATEGORY_META[category].label}
                    count={countFor(category)}
                    color={CATEGORY_META[category].color}
                    selected={filter === category}
                    onClick={() => setFilter(filter === category ? null : category)}
                  />
                ))}
              </div>

              <div className="announcements-date-strip">
                <div className="announcements-date-head">
                  <div>
                    <RemixIcon name="ri-calendar-event-line" size={15} />
                    <strong>Tarih</strong>
                  </div>
                  <span>{formatFullDate(selectedDate)}</span>
                </div>
                <div className="announcements-day-list" aria-label="Tarih seç">
                  {dateRange.map((date) => {
                    const selected = sameDay(date, selectedDate);
                    const isToday = sameDay(date, today);
                    return (
                      <button
                        key={date.toISOString()}
                        type="button"
                        className={selected ? 'is-selected' : ''}
                        onClick={() => setSelectedDate(date)}
                      >
                        <span>{weekdayShort(date)}</span>
                        <strong>{date.getDate()}</strong>
                        <small className={isToday ? 'is-today' : ''} aria-hidden="true" />
                      </button>
                    );
                  })}
                </div>
              </div>

              <div className="announcements-list">
                {visibleItems.map((item) => {
                  const category = validCategory(item.category);
                  const meta = CATEGORY_META[category];
                  const detailText = announcementDetailText(item);
                  const dateInfo = announcementDateInfo(item);
                  const sourceUrl = item.sourceUrl || item.canonicalUrl || '';
                  return (
                    <article
                      className="announcements-card"
                      key={item.id || `${item.source}-${item.title}`}
                      style={{ '--announcement-accent': meta.color } as React.CSSProperties}
                    >
                      <div
                        className="announcements-card-hit"
                        role="button"
                        tabIndex={0}
                        onClick={() => openAnnouncement(item)}
                        onKeyDown={(event) => {
                          if (event.key === 'Enter' || event.key === ' ') {
                            event.preventDefault();
                            openAnnouncement(item);
                          }
                        }}
                      >
                        <span className="announcements-card-line" aria-hidden="true" />
                        <div className="announcements-card-inner">
                          <div className="announcements-card-body">
                            <div className="announcements-card-top">
                              <span className="announcements-source-badge">
                                <RemixIcon name={meta.icon} size={13} />
                                <b>{item.source || meta.longLabel}</b>
                              </span>
                              <time>{item.timeLabel || 'Bugün'}</time>
                            </div>
                            <h2>{item.title}</h2>
                            {detailText && <p className="announcements-card-detail">{detailText}</p>}
                            {dateInfo && (
                              <p className="announcements-info-line">
                                <RemixIcon name="ri-calendar-event-line" size={13} />
                                <span>{dateInfo}</span>
                              </p>
                            )}
                            {sourceUrl && (
                              <a
                                className="announcements-source-link"
                                href={sourceUrl}
                                target="_blank"
                                rel="noreferrer"
                                onClick={(event) => event.stopPropagation()}
                              >
                                <RemixIcon name="ri-external-link-line" size={13} />
                                <strong>Başvuru / detay linki</strong>
                                <span>{sourceHost(sourceUrl)}</span>
                              </a>
                            )}
                            <div className="announcements-meta">
                              {(item.scheduleLabel || item.statusLabel) && (
                                <div className="announcements-meta-chips">
                                  {item.scheduleLabel && (
                                    <span className="announcements-meta-chip">
                                      <RemixIcon name="ri-time-fill" size={12} />
                                      {item.scheduleLabel}
                                    </span>
                                  )}
                                  {item.statusLabel && (
                                    <span
                                      className="announcements-status-chip"
                                      style={{ '--announcement-status-color': statusColor(item) } as React.CSSProperties}
                                    >
                                      <i aria-hidden="true" />
                                      {item.statusLabel}
                                    </span>
                                  )}
                                </div>
                              )}
                              <p>
                                <RemixIcon name="ri-map-pin-line" size={13} />
                                <span>Kapsam: {placeLabelFor(item.place)}</span>
                              </p>
                            </div>
                          </div>
                          <button
                            type="button"
                            className="announcements-thumb"
                            aria-label="Duyuru görselini büyüt"
                            onClick={(event) => {
                              event.stopPropagation();
                              setViewerItem(item);
                            }}
                          >
                            {item.imageUrl ? (
                              <img src={item.imageUrl} alt="" loading="lazy" decoding="async" />
                            ) : (
                              <div className="announcements-poster">
                                <RemixIcon name={meta.icon} size={32} />
                              </div>
                            )}
                            <span>
                              <RemixIcon name="ri-image-line" size={11} />
                            </span>
                          </button>
                        </div>
                      </div>
                    </article>
                  );
                })}
              </div>
            </>
          ) : (
            <div className="announcements-empty">
              <strong>{loading ? 'Liste hazırlanıyor' : 'Duyuru bulunamadı'}</strong>
              <p>{error || data.error || 'Niğde duyuru ağı kontrol ediliyor.'}</p>
            </div>
          )}
        </section>

        {viewerItem && (
          <div className="announcements-viewer" role="dialog" aria-modal="true" aria-label="Duyuru görseli">
            <button type="button" className="announcements-viewer-backdrop" onClick={() => setViewerItem(null)} aria-label="Kapat" />
            <div className="announcements-viewer-head">
              <button type="button" onClick={() => setViewerItem(null)} aria-label="Kapat">
                <RemixIcon name="ri-close-line" size={19} />
              </button>
              <div>
                <strong>{CATEGORY_META[validCategory(viewerItem.category)].longLabel}</strong>
                <span>{viewerItem.source}</span>
              </div>
            </div>
            <div
              className="announcements-viewer-visual"
              style={{ '--announcement-accent': CATEGORY_META[validCategory(viewerItem.category)].color } as React.CSSProperties}
            >
              {viewerItem.imageUrl ? (
                <img src={viewerItem.imageUrl} alt="" />
              ) : (
                <div className="announcements-poster">
                  <RemixIcon name={CATEGORY_META[validCategory(viewerItem.category)].icon} size={68} />
                </div>
              )}
            </div>
            <div className="announcements-viewer-copy">
              <h2>{viewerItem.title}</h2>
              {viewerItem.summary && <p>{viewerItem.summary}</p>}
              <span>
                <RemixIcon name="ri-map-pin-line" size={13} />
                {placeLabelFor(viewerItem.place)}
              </span>
            </div>
          </div>
        )}
      </div>
    </main>
  );
};

export default AnnouncementsPage;
