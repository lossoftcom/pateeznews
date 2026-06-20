import React, { useEffect, useMemo, useState } from 'react';
import RemixIcon from '@/components/ui/RemixIcon';
import { navigateImmediately } from '@/utils/immediateNavigation';

type PrayerTimeKey = 'imsak' | 'gunes' | 'ogle' | 'ikindi' | 'aksam' | 'yatsi';

type PrayerTime = {
  key: PrayerTimeKey;
  name: string;
  time: string;
};

type PrayerDay = {
  date: string;
  gregorianDateLabel: string;
  hijriDateLabel: string;
  times: PrayerTime[];
  qiblaAngle: string;
};

type DailyAyah = {
  surahId: number;
  surahName: string;
  verseNumber: number;
  arabicText: string;
  translation: string;
  source: string;
};

type PrayerPayload = {
  enabled: boolean;
  source: string;
  location: string;
  country: string;
  timezone: string;
  serviceDateLabel: string;
  fetchedAt: string;
  today: PrayerDay | null;
  days: PrayerDay[];
  dailyAyah: DailyAyah | null;
  error?: string;
};

type PrayerStatus = 'passed' | 'current' | 'next' | 'upcoming';

type PrayerCalculation = {
  nextPrayer: PrayerTime;
  nextIndex: number;
  currentIndex: number;
  remaining: number;
  progress: number;
  times: Date[];
  allPassed: boolean;
};

const EMPTY_DATA: PrayerPayload = {
  enabled: true,
  source: 'Diyanet Namaz Vakitleri',
  location: 'Niğde',
  country: 'Türkiye',
  timezone: 'Europe/Istanbul',
  serviceDateLabel: '',
  fetchedAt: '',
  today: null,
  days: [],
  dailyAyah: null,
};

const parseTime = (time: string) => {
  const [hour, minute] = String(time || '').split(':').map((part) => Number.parseInt(part, 10));
  return {
    hour: Number.isFinite(hour) ? hour : 0,
    minute: Number.isFinite(minute) ? minute : 0,
  };
};

const two = (value: number) => String(Math.max(0, Math.trunc(value))).padStart(2, '0');

const formatRemaining = (milliseconds: number) => {
  const safeSeconds = Math.max(0, Math.floor(milliseconds / 1000));
  const hours = Math.floor(safeSeconds / 3600);
  const minutes = Math.floor((safeSeconds % 3600) / 60);
  const seconds = safeSeconds % 60;
  return `${two(hours)}:${two(minutes)}:${two(seconds)}`;
};

const calculatePrayer = (prayers: PrayerTime[], now: Date): PrayerCalculation | null => {
  if (!prayers.length) return null;
  const times = prayers.map((prayer) => {
    const parsed = parseTime(prayer.time);
    return new Date(now.getFullYear(), now.getMonth(), now.getDate(), parsed.hour, parsed.minute);
  });
  const rawNext = times.findIndex((time) => time.getTime() > now.getTime());
  const allPassed = rawNext === -1;
  const nextIndex = allPassed ? 0 : rawNext;
  const currentIndex = allPassed ? times.length - 1 : nextIndex - 1;
  const nextTime = allPassed
    ? new Date(times[0].getTime() + 24 * 60 * 60 * 1000)
    : times[nextIndex];
  const currentTime = currentIndex < 0
    ? new Date(times[times.length - 1].getTime() - 24 * 60 * 60 * 1000)
    : times[currentIndex];
  const total = nextTime.getTime() - currentTime.getTime();
  const elapsed = now.getTime() - currentTime.getTime();
  return {
    nextPrayer: prayers[nextIndex],
    nextIndex,
    currentIndex,
    remaining: nextTime.getTime() - now.getTime(),
    progress: total <= 0 ? 0 : Math.min(1, Math.max(0, elapsed / total)),
    times,
    allPassed,
  };
};

const statusFor = (index: number, calc: PrayerCalculation, now: Date): PrayerStatus => {
  if (index === calc.nextIndex && (!calc.allPassed || index === 0)) return 'next';
  if (index === calc.currentIndex) return 'current';
  if (calc.times[index].getTime() > now.getTime()) return 'upcoming';
  return 'passed';
};

const hijriParts = (value: string) => {
  const text = String(value || '').trim();
  const match = text.match(/^(.+?)\s+(\d{3,4})$/);
  if (!match) return { main: text || '-', year: '' };
  return { main: match[1].trim(), year: `${match[2]} Hicri` };
};

const PrayerTimesPage: React.FC = () => {
  const [data, setData] = useState<PrayerPayload>(EMPTY_DATA);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');
  const [now, setNow] = useState(() => new Date());

  useEffect(() => {
    const timer = window.setInterval(() => setNow(new Date()), 1000);
    return () => window.clearInterval(timer);
  }, []);

  useEffect(() => {
    const controller = new AbortController();
    const timeout = window.setTimeout(() => controller.abort(), 13000);

    setLoading(true);
    fetch('/api/app/prayer-times?lang=tr', {
      headers: { Accept: 'application/json' },
      signal: controller.signal,
    })
      .then(async (response) => {
        const payload = await response.json().catch(() => null);
        if (!payload || typeof payload !== 'object') throw new Error('Namaz vakitleri alınamadı');
        setData({
          enabled: payload.enabled !== false,
          source: String(payload.source || 'Diyanet Namaz Vakitleri'),
          location: String(payload.location || 'Niğde'),
          country: String(payload.country || 'Türkiye'),
          timezone: String(payload.timezone || 'Europe/Istanbul'),
          serviceDateLabel: String(payload.serviceDateLabel || ''),
          fetchedAt: String(payload.fetchedAt || ''),
          today: payload.today && typeof payload.today === 'object' ? payload.today as PrayerDay : null,
          days: Array.isArray(payload.days) ? payload.days as PrayerDay[] : [],
          dailyAyah: payload.dailyAyah && typeof payload.dailyAyah === 'object' ? payload.dailyAyah as DailyAyah : null,
          error: String(payload.error || ''),
        });
        if (!response.ok && payload.error) setError(String(payload.error));
      })
      .catch(() => setError('Namaz vakitleri alınamadı'))
      .finally(() => {
        window.clearTimeout(timeout);
        setLoading(false);
      });

    return () => {
      window.clearTimeout(timeout);
      controller.abort();
    };
  }, []);

  const day = data.today;
  const prayers = day?.times || [];
  const calc = useMemo(() => calculatePrayer(prayers, now), [prayers, now]);
  const dateLabel = day
    ? [day.gregorianDateLabel, day.hijriDateLabel].filter(Boolean).join(' · ')
    : data.serviceDateLabel || data.source;
  const hijri = hijriParts(day?.hijriDateLabel || '');
  const progressDegrees = `${(calc?.progress || 0) * 360}deg`;
  const endAngle = -90 + (calc?.progress || 0) * 360;
  const endDotX = 123 + Math.cos((endAngle * Math.PI) / 180) * 99;
  const endDotY = 123 + Math.sin((endAngle * Math.PI) / 180) * 99;

  const goBack = () => {
    if (window.history.length > 1) {
      window.history.back();
      return;
    }
    void navigateImmediately('/');
  };

  return (
    <main className="prayer-times-mobile-page" aria-label="Namaz Vakitleri">
      <div className="prayer-times-shell">
        <header className="prayer-times-appbar">
          <button type="button" className="prayer-times-icon-button prayer-times-search-button" aria-label="Ara">
            <RemixIcon name="ri-search-line" size={25} />
          </button>
          <div className="prayer-times-appbar-title">
            <span aria-hidden="true" />
            <strong>Namaz Vakitleri</strong>
          </div>
          <button type="button" className="prayer-times-back-button" onClick={goBack} aria-label="Geri">
            <RemixIcon name="ri-arrow-left-line" size={22} />
          </button>
        </header>

        <section className="prayer-times-content">
          {prayers.length > 0 && calc ? (
            <>
              <div className="prayer-times-header-card">
                <div className="prayer-times-header-icon">
                  <RemixIcon name="ri-moon-clear-fill" size={22} />
                </div>
                <div className="prayer-times-header-copy">
                  <p>
                    <RemixIcon name="ri-map-pin-line" size={12} />
                    {data.location || 'Niğde'}
                  </p>
                  <h1>Namaz Vakitleri</h1>
                  <small>{dateLabel}</small>
                </div>
              </div>

              <div className="prayer-countdown-card">
                <div className="prayer-ring" style={{ '--prayer-progress': progressDegrees } as React.CSSProperties}>
                  {Array.from({ length: 60 }, (_, index) => (
                    <span
                      key={index}
                      className={index % 5 === 0 ? 'is-major' : undefined}
                      style={{ transform: `rotate(${index * 6}deg) translateY(-120px)` }}
                      aria-hidden="true"
                    />
                  ))}
                  <div className="prayer-ring-track" aria-hidden="true" />
                  <div className="prayer-ring-progress" aria-hidden="true" />
                  <i
                    className="prayer-ring-dot"
                    style={{ left: `${endDotX}px`, top: `${endDotY}px` }}
                    aria-hidden="true"
                  />
                  <div className="prayer-ring-copy">
                    <strong>{calc.nextPrayer.name} vaktine</strong>
                    <time>{formatRemaining(calc.remaining)}</time>
                    <small>kalan süre</small>
                  </div>
                </div>
              </div>

              <div className="prayer-section-title">
                <span aria-hidden="true" />
                <h2>Bugünün Vakitleri</h2>
              </div>

              <div className="prayer-list">
                {prayers.map((prayer, index) => {
                  const status = statusFor(index, calc, now);
                  return (
                    <div className={`prayer-row is-${status}`} key={prayer.key}>
                      <span className="prayer-row-dot" aria-hidden="true" />
                      <strong>{prayer.name}</strong>
                      {status === 'next' && <em>Sıradaki</em>}
                      <time>{prayer.time}</time>
                    </div>
                  );
                })}
              </div>

              <div className="prayer-section-title">
                <span aria-hidden="true" />
                <h2>Kıble ve Güneş</h2>
              </div>

              <div className="prayer-info-grid">
                <div>
                  <span><RemixIcon name="ri-compass-3-fill" size={17} /></span>
                  <p>Kıble Açısı</p>
                  <strong>{day?.qiblaAngle || '-'}</strong>
                </div>
                <div>
                  <span><RemixIcon name="ri-sun-fill" size={17} /></span>
                  <p>Gün Doğumu</p>
                  <strong>{prayers.find((item) => item.key === 'gunes')?.time || '-'}</strong>
                </div>
                <div>
                  <span><RemixIcon name="ri-moon-clear-fill" size={17} /></span>
                  <p>Gün Batımı</p>
                  <strong>{prayers.find((item) => item.key === 'aksam')?.time || '-'}</strong>
                </div>
                <div>
                  <span><RemixIcon name="ri-calendar-event-line" size={17} /></span>
                  <p>Hicri Tarih</p>
                  <strong>{hijri.main}</strong>
                  {hijri.year && <small>{hijri.year}</small>}
                </div>
              </div>

              <div className="prayer-section-title">
                <span aria-hidden="true" />
                <h2>Günün Ayeti</h2>
              </div>

              <div className="prayer-ayah-card">
                <RemixIcon name="ri-sparkling-fill" size={20} />
                {data.dailyAyah && (data.dailyAyah.arabicText || data.dailyAyah.translation) ? (
                  <>
                    {data.dailyAyah.arabicText && <p className="prayer-ayah-arabic">{data.dailyAyah.arabicText}</p>}
                    {data.dailyAyah.translation && <p className="prayer-ayah-translation">“{data.dailyAyah.translation}”</p>}
                    <strong>{data.dailyAyah.surahName} {data.dailyAyah.verseNumber}</strong>
                  </>
                ) : (
                  <p className="prayer-ayah-empty">Günün ayeti için Diyanet Kur’an API tokenı admin ayarlarından tanımlanmalı.</p>
                )}
              </div>
            </>
          ) : (
            <div className="prayer-times-empty">
              <strong>{loading ? 'Vakitler hazırlanıyor' : 'Namaz vakitleri alınamadı'}</strong>
              <p>{error || data.error || 'Diyanet namaz vakitleri kaynağı kontrol ediliyor.'}</p>
            </div>
          )}
        </section>
      </div>
    </main>
  );
};

export default PrayerTimesPage;
