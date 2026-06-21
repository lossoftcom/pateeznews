import React, { useEffect, useMemo, useState } from 'react';
import RemixIcon from '@/components/ui/RemixIcon';
import { navigateImmediately } from '@/utils/immediateNavigation';
import { openSiteSearch } from '@/utils/searchNavigation';

type MarketRate = {
  id: string;
  symbol: string;
  name: string;
  bid: number;
  ask: number;
  changeAmount: number | null;
  changePercent: number | null;
  isUp: boolean;
  currencyCode: string;
  currencySymbol: string;
  secondaryBid?: number | null;
  secondaryAsk?: number | null;
  secondaryCurrencyCode?: string;
  secondaryCurrencySymbol?: string;
  timestamp: string;
};

type MarketsPayload = {
  enabled: boolean;
  provider: string;
  source: string;
  serviceDateLabel: string;
  fetchedAt: string;
  updateIntervalSeconds: number;
  currencies: MarketRate[];
  gold: MarketRate[];
  error?: string;
};

const EMPTY_DATA: MarketsPayload = {
  enabled: true,
  provider: 'genelpara',
  source: 'GenelPara',
  serviceDateLabel: '',
  fetchedAt: '',
  updateIntervalSeconds: 300,
  currencies: [],
  gold: [],
};

const numberValue = (value: unknown) => {
  const parsed = Number.parseFloat(String(value ?? '').replace(',', '.'));
  return Number.isFinite(parsed) ? parsed : 0;
};

const nullableNumber = (value: unknown) => {
  if (value === null || value === undefined || value === '') return null;
  const parsed = Number.parseFloat(String(value).replace(',', '.'));
  return Number.isFinite(parsed) ? parsed : null;
};

const formatMarketValue = (value: number) => {
  const safe = Number.isFinite(value) ? value : 0;
  const digits = safe >= 100 ? 2 : 4;
  const fixed = safe.toFixed(digits);
  const [whole, decimal = ''] = fixed.split('.');
  const grouped = whole.replace(/\B(?=(\d{3})+(?!\d))/g, '.');
  return decimal ? `${grouped},${decimal}` : grouped;
};

const rateLabel = (rate: MarketRate, value: number) => (
  `${rate.currencySymbol || '₺'}${formatMarketValue(value)}`
);

const secondaryAskLabel = (rate: MarketRate) => {
  if (rate.secondaryAsk === null || rate.secondaryAsk === undefined) return '';
  if (!rate.secondaryCurrencyCode || !rate.secondaryCurrencySymbol) return '';
  return `${rate.secondaryCurrencySymbol}${formatMarketValue(rate.secondaryAsk)}`;
};

const changeLabel = (rate: MarketRate) => {
  const value = rate.changePercent;
  if (value === null || value === undefined || !Number.isFinite(value)) return 'Canlı';
  const sign = value > 0 ? '+' : '';
  return `${sign}${value.toFixed(2).replace('.', ',')}%`;
};

const normalizeRate = (item: any): MarketRate => ({
  id: String(item?.id || item?.symbol || ''),
  symbol: String(item?.symbol || ''),
  name: String(item?.name || ''),
  bid: numberValue(item?.bid),
  ask: numberValue(item?.ask),
  changeAmount: nullableNumber(item?.changeAmount),
  changePercent: nullableNumber(item?.changePercent),
  isUp: item?.isUp !== false,
  currencyCode: String(item?.currencyCode || 'TRY'),
  currencySymbol: String(item?.currencySymbol || '₺'),
  secondaryBid: nullableNumber(item?.secondaryBid),
  secondaryAsk: nullableNumber(item?.secondaryAsk),
  secondaryCurrencyCode: String(item?.secondaryCurrencyCode || ''),
  secondaryCurrencySymbol: String(item?.secondaryCurrencySymbol || ''),
  timestamp: String(item?.timestamp || ''),
});

const MarketRatesPage: React.FC = () => {
  const [data, setData] = useState<MarketsPayload>(EMPTY_DATA);
  const [segment, setSegment] = useState<'currency' | 'gold'>('currency');
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');

  useEffect(() => {
    const controller = new AbortController();
    const timeout = window.setTimeout(() => controller.abort(), 13000);

    setLoading(true);
    fetch('/api/app/markets?lang=tr', {
      headers: { Accept: 'application/json' },
      signal: controller.signal,
    })
      .then(async (response) => {
        const payload = await response.json().catch(() => null);
        if (!payload || typeof payload !== 'object') throw new Error('Piyasa verisi alınamadı');
        setData({
          enabled: payload.enabled !== false,
          provider: String(payload.provider || 'genelpara'),
          source: String(payload.source || 'GenelPara'),
          serviceDateLabel: String(payload.serviceDateLabel || ''),
          fetchedAt: String(payload.fetchedAt || ''),
          updateIntervalSeconds: Number(payload.updateIntervalSeconds || 300),
          currencies: Array.isArray(payload.currencies) ? payload.currencies.map(normalizeRate) : [],
          gold: Array.isArray(payload.gold) ? payload.gold.map(normalizeRate) : [],
          error: String(payload.error || ''),
        });
        if (!response.ok && payload.error) setError(String(payload.error));
      })
      .catch(() => setError('Piyasa verisi alınamadı'))
      .finally(() => {
        window.clearTimeout(timeout);
        setLoading(false);
      });

    return () => {
      window.clearTimeout(timeout);
      controller.abort();
    };
  }, []);

  const rates = useMemo(
    () => (segment === 'currency' ? data.currencies : data.gold),
    [data.currencies, data.gold, segment]
  );
  const hasMarkets = data.currencies.length > 0 || data.gold.length > 0;

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
    <main className="market-rates-mobile-page" aria-label="Döviz ve Altın">
      <div className="market-rates-shell">
        <header className="market-rates-appbar">
          <button type="button" className="market-rates-icon-button market-rates-search-button" onClick={openSearch} aria-label="Ara">
            <RemixIcon name="ri-search-line" size={25} />
          </button>
          <div className="market-rates-appbar-title">
            <span aria-hidden="true" />
            <strong>Döviz & Altın</strong>
          </div>
          <button type="button" className="market-rates-back-button" onClick={goBack} aria-label="Geri">
            <RemixIcon name="ri-arrow-left-line" size={22} />
          </button>
        </header>

        <section className="market-rates-content">
          {hasMarkets ? (
            <>
              <div className="market-rates-hero-card">
                <div className="market-rates-hero-icon">
                  <RemixIcon name="ri-coins-fill" size={23} />
                </div>
                <div className="market-rates-hero-copy">
                  <p>
                    <span aria-hidden="true" />
                    {data.updateIntervalSeconds || 300} sn güncelleme
                  </p>
                  <h1>Canlı Piyasa</h1>
                  <small>Anlık döviz kuru ve altın fiyatları</small>
                </div>
                <span className="market-rates-live-badge">
                  <i aria-hidden="true" />
                  Canlı
                </span>
              </div>

              <div className="market-rates-segment" aria-label="Piyasa türü">
                <button
                  type="button"
                  className={segment === 'currency' ? 'is-active' : undefined}
                  onClick={() => setSegment('currency')}
                >
                  Döviz
                </button>
                <button
                  type="button"
                  className={segment === 'gold' ? 'is-active' : undefined}
                  onClick={() => setSegment('gold')}
                >
                  Altın
                </button>
              </div>

              <div className="market-rates-table-head">
                <span />
                <strong>Alış</strong>
                <strong>Satış</strong>
              </div>

              <div className="market-rates-list">
                {rates.length > 0 ? rates.map((rate) => {
                  const secondary = rate.symbol.toLocaleUpperCase('tr-TR') === 'BTC' ? secondaryAskLabel(rate) : '';
                  return (
                    <article className="market-rate-card" key={rate.id || rate.symbol}>
                      <div className="market-rate-name">
                        <h2>{rate.symbol}</h2>
                        <p>{rate.name}</p>
                        {secondary && <small>USD {secondary}</small>}
                      </div>
                      <div className="market-rate-price">
                        <strong>{rateLabel(rate, rate.bid)}</strong>
                        <em className={rate.isUp ? 'is-up' : 'is-down'}>{changeLabel(rate)}</em>
                      </div>
                      <div className="market-rate-price">
                        <strong>{rateLabel(rate, rate.ask)}</strong>
                        <em className={rate.isUp ? 'is-up' : 'is-down'}>{changeLabel(rate)}</em>
                      </div>
                    </article>
                  );
                }) : (
                  <div className="market-rates-empty is-inline">
                    <strong>{segment === 'currency' ? 'Döviz verisi yok' : 'Altın verisi yok'}</strong>
                    <p>Canlı piyasa kaynağı kontrol ediliyor.</p>
                  </div>
                )}
              </div>
            </>
          ) : (
            <div className="market-rates-empty">
              <strong>{loading ? 'Piyasa hazırlanıyor' : 'Piyasa verisi alınamadı'}</strong>
              <p>{error || data.error || 'Döviz ve altın kaynağı kontrol ediliyor.'}</p>
            </div>
          )}
        </section>
      </div>
    </main>
  );
};

export default MarketRatesPage;
