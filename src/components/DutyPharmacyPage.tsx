import React, { useEffect, useMemo, useState } from 'react';
import RemixIcon from '@/components/ui/RemixIcon';
import { navigateImmediately } from '@/utils/immediateNavigation';
import { openSiteSearch } from '@/utils/searchNavigation';

type DutyPharmacy = {
  id: string;
  name: string;
  district: string;
  address: string;
  phone: string;
  phoneHref: string;
  mapUrl: string;
  directionUrl: string;
  note?: string;
};

type DutyPharmacyPayload = {
  city: string;
  serviceDateLabel: string;
  updateIntervalMinutes: number;
  districts: string[];
  pharmacies: DutyPharmacy[];
  error?: string;
};

const EMPTY_DATA: DutyPharmacyPayload = {
  city: 'Niğde',
  serviceDateLabel: '',
  updateIntervalMinutes: 15,
  districts: [],
  pharmacies: [],
};

const DISTRICT_LABELS: Record<string, string> = {
  'MERKEZ': 'Merkez',
  'ALTUNHİSAR': 'Altunhisar',
  'BOR': 'Bor',
  'ÇAMARDI': 'Çamardı',
  'ÇİFTLİK': 'Çiftlik',
  'ULUKIŞLA': 'Ulukışla',
};

const districtLabel = (district: string) => (
  DISTRICT_LABELS[district.trim().toLocaleUpperCase('tr-TR')] || district
);

const titleCaseTr = (value: string) => (
  String(value || '')
    .split(' ')
    .map((word) => {
      if (!word) return word;
      const lower = word.replaceAll('İ', 'i').toLocaleLowerCase('tr-TR');
      const first = lower[0] === 'i' ? 'İ' : lower[0].toLocaleUpperCase('tr-TR');
      return `${first}${lower.slice(1)}`;
    })
    .join(' ')
);

const uniqueDistricts = (data: DutyPharmacyPayload) => {
  const source = data.districts.length ? data.districts : data.pharmacies.map((pharmacy) => pharmacy.district);
  return Array.from(new Set(source.map((district) => district.trim()).filter(Boolean)));
};

const preferredDistrict = (districts: string[]) => {
  if (!districts.length) return '';
  return districts.includes('MERKEZ') ? 'MERKEZ' : districts[0];
};

const callHrefFor = (pharmacy: DutyPharmacy) => {
  const digits = String(pharmacy.phoneHref || pharmacy.phone || '').replace(/\D/g, '');
  return digits ? `tel:${digits}` : undefined;
};

const routeHrefFor = (pharmacy: DutyPharmacy) => pharmacy.directionUrl || pharmacy.mapUrl || undefined;

const DutyPharmacyPage: React.FC = () => {
  const [data, setData] = useState<DutyPharmacyPayload>(EMPTY_DATA);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');
  const [activeDistrict, setActiveDistrict] = useState('MERKEZ');

  useEffect(() => {
    const controller = new AbortController();
    const timeout = window.setTimeout(() => controller.abort(), 13000);

    setLoading(true);
    fetch('/api/app/duty-pharmacies?city=nigde', {
      headers: { Accept: 'application/json' },
      signal: controller.signal,
    })
      .then(async (response) => {
        const payload = await response.json().catch(() => null);
        if (!payload || typeof payload !== 'object') throw new Error('Nöbetçi eczaneler alınamadı');
        setData({
          city: String(payload.city || 'Niğde'),
          serviceDateLabel: String(payload.serviceDateLabel || ''),
          updateIntervalMinutes: Number(payload.updateIntervalMinutes || 15),
          districts: Array.isArray(payload.districts) ? payload.districts.map(String) : [],
          pharmacies: Array.isArray(payload.pharmacies) ? payload.pharmacies as DutyPharmacy[] : [],
          error: String(payload.error || ''),
        });
        if (!response.ok && payload.error) setError(String(payload.error));
      })
      .catch(() => setError('Nöbetçi eczaneler alınamadı'))
      .finally(() => {
        window.clearTimeout(timeout);
        setLoading(false);
      });

    return () => {
      window.clearTimeout(timeout);
      controller.abort();
    };
  }, []);

  const districts = useMemo(() => uniqueDistricts(data), [data]);

  useEffect(() => {
    if (!districts.length) return;
    if (districts.includes(activeDistrict)) return;
    setActiveDistrict(preferredDistrict(districts));
  }, [activeDistrict, districts]);

  const selectedDistrict = districts.includes(activeDistrict)
    ? activeDistrict
    : preferredDistrict(districts);

  const visiblePharmacies = selectedDistrict
    ? data.pharmacies.filter((pharmacy) => pharmacy.district === selectedDistrict)
    : data.pharmacies;

  const dateLabel = data.serviceDateLabel || 'Bugün';

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

  return (
    <main className="duty-pharmacy-mobile-page" aria-label="Nöbetçi Eczane">
      <div className="duty-pharmacy-shell">
        <header className="duty-pharmacy-appbar">
          <button type="button" className="duty-pharmacy-icon-button duty-pharmacy-search-button" onClick={openSearch} aria-label="Ara">
            <RemixIcon name="ri-search-line" size={25} />
          </button>
          <div className="duty-pharmacy-appbar-title">
            <span aria-hidden="true" />
            <strong>Nöbetçi Eczane</strong>
          </div>
          <button type="button" className="duty-pharmacy-back-button" onClick={goBack} aria-label="Geri">
            <RemixIcon name="ri-arrow-left-line" size={22} />
          </button>
        </header>

        <section className="duty-pharmacy-content">
          <div className="duty-pharmacy-info-card">
            <div className="duty-pharmacy-logo-box">
              <img src="/admin/assets/assets/images/nobetci_eczane.webp" alt="" loading="eager" decoding="async" />
            </div>
            <div className="duty-pharmacy-info-copy">
              <div className="duty-pharmacy-info-title">
                <span aria-hidden="true" />
                <strong>Nöbetçi Eczane</strong>
              </div>
              <p>{data.city || 'Niğde'} · {dateLabel}</p>
            </div>
            <span className="duty-pharmacy-update-pill">
              {data.updateIntervalMinutes || 15} dk
            </span>
          </div>

          {districts.length > 0 && (
            <div className="duty-pharmacy-district-grid" aria-label="İlçeler">
              {districts.map((district) => {
                const count = data.pharmacies.filter((pharmacy) => pharmacy.district === district).length;
                const selected = district === selectedDistrict;
                return (
                  <button
                    key={district}
                    type="button"
                    className={selected ? 'is-selected' : ''}
                    onClick={() => setActiveDistrict(district)}
                  >
                    <span>{districtLabel(district)}</span>
                    {count > 0 && <small>{count}</small>}
                  </button>
                );
              })}
            </div>
          )}

          <div className="duty-pharmacy-list">
            {visiblePharmacies.length > 0 ? (
              visiblePharmacies.map((pharmacy) => (
                <article className="duty-pharmacy-card" key={pharmacy.id || `${pharmacy.district}-${pharmacy.name}`}>
                  <div className="duty-pharmacy-card-head">
                    <div>
                      <h2>{titleCaseTr(pharmacy.name)}</h2>
                      <p className="duty-pharmacy-district-line">
                        <span aria-hidden="true" />
                        {districtLabel(pharmacy.district)}
                      </p>
                    </div>
                    <span className="duty-pharmacy-card-mark" aria-hidden="true">
                      <RemixIcon name="ri-capsule-fill" size={17} />
                    </span>
                  </div>

                  {pharmacy.note && (
                    <p className="duty-pharmacy-note">{titleCaseTr(pharmacy.note)}</p>
                  )}

                  <p className="duty-pharmacy-address">
                    {pharmacy.address ? titleCaseTr(pharmacy.address) : 'Adres bilgisi bekleniyor'}
                  </p>

                  <div className="duty-pharmacy-actions">
                    <a className="duty-pharmacy-call" href={callHrefFor(pharmacy)} aria-disabled={!callHrefFor(pharmacy)}>
                      <RemixIcon name="ri-phone-fill" size={14} />
                      <span>Ara</span>
                    </a>
                    <a
                      className="duty-pharmacy-route"
                      href={routeHrefFor(pharmacy)}
                      target="_blank"
                      rel="noreferrer"
                      aria-disabled={!routeHrefFor(pharmacy)}
                    >
                      <RemixIcon name="ri-navigation-fill" size={14} />
                      <span>Yol Tarifi</span>
                    </a>
                  </div>
                </article>
              ))
            ) : (
              <div className="duty-pharmacy-empty">
                <strong>{loading ? 'Liste hazırlanıyor' : 'Nöbetçi eczane bulunamadı'}</strong>
                <p>{error || data.error || 'Niğde Eczacı Odası kaynağı kontrol ediliyor.'}</p>
              </div>
            )}
          </div>
        </section>
      </div>
    </main>
  );
};

export default DutyPharmacyPage;
