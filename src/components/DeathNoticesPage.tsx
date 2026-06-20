import React, { useEffect, useState } from 'react';
import RemixIcon from '@/components/ui/RemixIcon';
import { navigateImmediately } from '@/utils/immediateNavigation';

type DeathNotice = {
  id: string;
  name: string;
  deathDateLabel: string;
  prayerTime: string;
  burialPlace: string;
  description: string;
};

type DeathNoticePayload = {
  city: string;
  source: string;
  serviceDateLabel: string;
  fetchedAt: string;
  updateIntervalMinutes: number;
  notices: DeathNotice[];
  error?: string;
};

const EMPTY_DATA: DeathNoticePayload = {
  city: 'Niğde',
  source: 'Niğde Belediyesi',
  serviceDateLabel: '',
  fetchedAt: '',
  updateIntervalMinutes: 30,
  notices: [],
};

const compactText = (value: unknown) => String(value || '').replace(/\s+/g, ' ').trim();

const upperCaseTr = (value: string) =>
  compactText(value).replaceAll('i', 'İ').replaceAll('ı', 'I').toLocaleUpperCase('tr-TR');

const routeLabelFor = (notice: DeathNotice) => (
  [upperCaseTr(notice.prayerTime), upperCaseTr(notice.burialPlace)]
    .filter(Boolean)
    .join(' · ')
);

const timeLabel = (value: string) => {
  const date = new Date(value);
  if (!value || Number.isNaN(date.getTime())) return '';
  return `${String(date.getHours()).padStart(2, '0')}:${String(date.getMinutes()).padStart(2, '0')}`;
};

const goBack = () => {
  if (window.history.length > 1) {
    window.history.back();
    return;
  }
  void navigateImmediately('/');
};

const DeathNoticesPage: React.FC = () => {
  const [data, setData] = useState<DeathNoticePayload>(EMPTY_DATA);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');

  useEffect(() => {
    const controller = new AbortController();
    const timeout = window.setTimeout(() => controller.abort(), 13000);

    setLoading(true);
    fetch('/api/app/death-notices?city=nigde', {
      headers: { Accept: 'application/json' },
      signal: controller.signal,
    })
      .then(async (response) => {
        const payload = await response.json().catch(() => null);
        if (!payload || typeof payload !== 'object') throw new Error('Ölüm ilanları alınamadı');
        setData({
          city: String(payload.city || 'Niğde'),
          source: String(payload.source || 'Niğde Belediyesi'),
          serviceDateLabel: String(payload.serviceDateLabel || ''),
          fetchedAt: String(payload.fetchedAt || ''),
          updateIntervalMinutes: Number(payload.updateIntervalMinutes || 30),
          notices: Array.isArray(payload.notices) ? payload.notices as DeathNotice[] : [],
          error: String(payload.error || ''),
        });
        if (!response.ok && payload.error) setError(String(payload.error));
      })
      .catch(() => setError('Ölüm ilanları alınamadı'))
      .finally(() => {
        window.clearTimeout(timeout);
        setLoading(false);
      });

    return () => {
      window.clearTimeout(timeout);
      controller.abort();
    };
  }, []);

  const dateLabel = data.serviceDateLabel || 'Bugün';
  const fetchedLabel = timeLabel(data.fetchedAt);

  return (
    <main className="death-notices-mobile-page" aria-label="Ölüm İlanları">
      <div className="death-notices-shell">
        <header className="death-notices-appbar">
          <button type="button" className="death-notices-icon-button death-notices-search-button" aria-label="Ara">
            <RemixIcon name="ri-search-line" size={25} />
          </button>
          <div className="death-notices-appbar-title">
            <span aria-hidden="true" />
            <strong>Ölüm İlanları</strong>
          </div>
          <button type="button" className="death-notices-back-button" onClick={goBack} aria-label="Geri">
            <RemixIcon name="ri-arrow-left-line" size={22} />
          </button>
        </header>

        <section className="death-notices-content">
          {data.notices.length > 0 ? (
            <>
              <div className="death-notices-header-card">
                <div className="death-notices-header-icon">
                  <RemixIcon name="ri-leaf-line" size={22} />
                </div>
                <div className="death-notices-header-copy">
                  <strong>ÖLÜM İLANLARI</strong>
                  <p>{data.city || 'Niğde'} · {dateLabel}</p>
                </div>
                <span className="death-notices-update-pill">
                  {data.updateIntervalMinutes || 30} dk
                </span>
              </div>

              <div className="death-notices-list">
                {data.notices.map((notice) => {
                  const routeLabel = routeLabelFor(notice);
                  const description = compactText(notice.description) || 'Açıklama bilgisi bekleniyor.';
                  return (
                    <article className="death-notice-card" key={notice.id || `${notice.name}-${notice.deathDateLabel}`}>
                      <div className="death-notice-panel">
                        <div className="death-notice-head">
                          <h2>{notice.name}</h2>
                          <span>{notice.deathDateLabel || 'Bugün'}</span>
                        </div>
                        {routeLabel && <p className="death-notice-route">{routeLabel}</p>}
                        <p className="death-notice-description">{description}</p>
                      </div>

                      <button
                        type="button"
                        className="death-notice-condolence-button"
                        disabled
                        aria-disabled="true"
                        title="Taziye mesajı yakında etkinleşecek"
                      >
                        <RemixIcon name="ri-heart-3-line" size={16} />
                        <span>Taziye Mesajı Yaz</span>
                      </button>

                      <footer className="death-notice-footer">
                        <span>{data.source || 'Niğde Belediyesi'} kaynağı</span>
                        {fetchedLabel && <time>{fetchedLabel}</time>}
                      </footer>
                    </article>
                  );
                })}
              </div>
            </>
          ) : (
            <div className="death-notices-empty">
              <strong>{loading ? 'Liste hazırlanıyor' : 'Ölüm ilanı bulunamadı'}</strong>
              <p>{error || data.error || 'Niğde Belediyesi kaynağı kontrol ediliyor.'}</p>
            </div>
          )}
        </section>
      </div>
    </main>
  );
};

export default DeathNoticesPage;
