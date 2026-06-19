import React, { useEffect, useMemo, useRef } from 'react';
import type { SiteSettings } from '@/types';
import RemixIcon from './ui/RemixIcon';

type FooterPage = {
  id: string;
  title: string;
  slug: string;
  pageGroup?: string;
  pageType?: string;
  menuOrder?: number;
};

type FooterLink = {
  label: string;
  href: string;
};

interface PublicFooterProps {
  siteSettings: SiteSettings | null;
  pages: FooterPage[];
}

const cleanText = (value: unknown) => String(value || '').replace(/\s+/g, ' ').trim();

const stripWrappingQuotes = (value: string) => {
  const trimmed = value.trim();
  const pairs: Array<[string, string]> = [
    ['"', '"'],
    ["'", "'"],
    ['“', '”'],
    ['‘', '’'],
  ];
  const match = pairs.find(([open, close]) => trimmed.startsWith(open) && trimmed.endsWith(close));
  return match && trimmed.length > 1 ? trimmed.slice(1, -1).trim() : trimmed;
};

const normalizeExternalUrl = (value: unknown) => {
  const raw = String(value || '').trim();
  if (!raw) return '';
  if (/^https?:\/\//i.test(raw) || /^whatsapp:\/\//i.test(raw) || /^tg:\/\//i.test(raw)) return raw;
  if (/^[a-z0-9.-]+\.[a-z]{2,}/i.test(raw)) return `https://${raw}`;
  return '';
};

const normalizeWhatsappUrl = (value: unknown) => {
  const raw = String(value || '').trim();
  if (!raw) return '';
  if (/^https?:\/\//i.test(raw) || /^whatsapp:\/\//i.test(raw)) return raw;
  if (/^wa\.me\//i.test(raw)) return `https://${raw}`;
  const digits = raw.replace(/\D/g, '');
  return digits.length >= 10 ? `https://wa.me/${digits}` : '';
};

const normalizeTelegramUrl = (value: unknown) => {
  const raw = String(value || '').trim();
  if (!raw) return '';
  if (/^https?:\/\//i.test(raw) || /^tg:\/\//i.test(raw)) return raw;
  if (/^t\.me\//i.test(raw)) return `https://${raw}`;
  const username = raw.replace(/^@/, '');
  return /^[a-zA-Z0-9_]{5,32}$/.test(username) ? `https://t.me/${username}` : '';
};

const mailtoHref = (value: unknown) => {
  const email = cleanText(value);
  return /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email) ? `mailto:${email}` : '';
};

const phoneHref = (value: unknown) => {
  const raw = cleanText(value);
  const normalized = raw.replace(/[^\d+]/g, '');
  return normalized.replace(/\D/g, '').length >= 10 ? `tel:${normalized}` : '';
};

const pageHref = (slug: string) => `/kurumsal/${encodeURIComponent(slug)}`;

const isLegalPage = (page: FooterPage) => {
  const haystack = `${page.pageType || ''} ${page.pageGroup || ''} ${page.title || ''} ${page.slug || ''}`
    .toLocaleLowerCase('tr-TR');
  return (
    haystack.includes('legal') ||
    haystack.includes('yasal') ||
    haystack.includes('politika') ||
    haystack.includes('gizlilik') ||
    haystack.includes('çerez') ||
    haystack.includes('cerez') ||
    haystack.includes('kvkk') ||
    haystack.includes('kullanım') ||
    haystack.includes('kullanim')
  );
};

const uniquePageLinks = (pages: FooterPage[]) => {
  const seen = new Set<string>();
  return pages
    .map((page) => ({
      label: cleanText(page.title),
      slug: cleanText(page.slug),
      page,
    }))
    .filter((entry) => {
      if (!entry.label || !entry.slug || seen.has(entry.slug)) return false;
      seen.add(entry.slug);
      return true;
    });
};

const LinkList: React.FC<{ links: FooterLink[] }> = ({ links }) => (
  <ul className="space-y-2.5">
    {links.map((link) => (
      <li key={`${link.href}-${link.label}`}>
        <a
          href={link.href}
          className="group inline-flex items-center gap-2 text-[13px] font-bold leading-5 text-gray-600 transition-colors hover:text-palette-red"
        >
          <span className="h-1.5 w-1.5 rounded-full bg-palette-tan/35 transition-colors group-hover:bg-palette-red" aria-hidden="true"></span>
          <span>{link.label}</span>
        </a>
      </li>
    ))}
  </ul>
);

const PublicFooter: React.FC<PublicFooterProps> = ({ siteSettings, pages }) => {
  const footerRef = useRef<HTMLElement | null>(null);
  const siteName = cleanText(siteSettings?.site_name) || 'Pateez.com';
  const footerLogo = cleanText(siteSettings?.footer_logo_url || siteSettings?.logo_url || siteSettings?.email_logo_url);
  const footerAbout = stripWrappingQuotes(cleanText(siteSettings?.footer_about));
  const copyright = cleanText(siteSettings?.copyright_text) || `© ${new Date().getFullYear()} ${siteName}`;

  const pageGroups = useMemo(() => {
    const entries = uniquePageLinks(pages || []);
    const corporate = entries
      .filter(({ page }) => !isLegalPage(page))
      .map(({ label, slug }) => ({ label, href: pageHref(slug) }));
    const legal = entries
      .filter(({ page }) => isLegalPage(page))
      .map(({ label, slug }) => ({ label, href: pageHref(slug) }));
    const contact = entries.find(({ slug }) => slug === 'iletisim');
    return { corporate, legal, contact };
  }, [pages]);

  const socialLinks = useMemo(() => ([
    { label: 'Instagram', href: normalizeExternalUrl(siteSettings?.social_instagram_url), icon: 'ri-instagram-fill' },
    { label: 'X', href: normalizeExternalUrl(siteSettings?.social_x_url), icon: 'ri-twitter-x-fill' },
    { label: 'YouTube', href: normalizeExternalUrl(siteSettings?.social_youtube_url), icon: 'ri-youtube-fill' },
    { label: 'Facebook', href: normalizeExternalUrl(siteSettings?.social_facebook_url), icon: 'ri-facebook-fill' },
    { label: 'TikTok', href: normalizeExternalUrl(siteSettings?.social_tiktok_url), icon: 'ri-tiktok-fill' },
    { label: 'LinkedIn', href: normalizeExternalUrl(siteSettings?.social_linkedin_url), icon: 'ri-linkedin-fill' },
    { label: 'Pinterest', href: normalizeExternalUrl(siteSettings?.social_pinterest_url), icon: 'ri-pinterest-fill' },
    { label: 'Discord', href: normalizeExternalUrl(siteSettings?.social_discord_url), icon: 'ri-discord-fill' },
  ].filter((item) => item.href)), [siteSettings]);

  const contactItems = useMemo(() => {
    const email = cleanText(
      siteSettings?.contact_email_info ||
      siteSettings?.contact_email_support ||
      siteSettings?.contact_email_news ||
      siteSettings?.contact_email_ads
    );
    const phone = cleanText(siteSettings?.contact_phone || siteSettings?.organization_phone);
    const city = cleanText(siteSettings?.contact_city);
    const address = cleanText(siteSettings?.contact_address || siteSettings?.organization_address);
    const whatsapp = normalizeWhatsappUrl(siteSettings?.contact_whatsapp_url || siteSettings?.social_whatsapp_url);
    const telegram = normalizeTelegramUrl(siteSettings?.contact_telegram_url || siteSettings?.social_telegram_url);

    const baseItems = [
      { label: email, href: mailtoHref(email), icon: 'ri-mail-line' },
      { label: phone, href: phoneHref(phone), icon: 'ri-phone-line' },
      { label: city || address, href: normalizeExternalUrl(siteSettings?.contact_location_url), icon: 'ri-map-pin-line' },
    ].filter((item) => item.label);

    if (whatsapp) baseItems.push({ label: 'WhatsApp', href: whatsapp, icon: 'ri-whatsapp-fill' });
    if (telegram) baseItems.push({ label: 'Telegram', href: telegram, icon: 'ri-telegram-fill' });

    return baseItems;
  }, [siteSettings]);

  useEffect(() => {
    const root = footerRef.current;
    if (!root || window.matchMedia('(prefers-reduced-motion: reduce)').matches) return;

    const revealItems = root.querySelectorAll<HTMLElement>('[data-footer-reveal]');
    if (revealItems.length === 0) return;

    let cancelled = false;
    let context: { revert: () => void } | undefined;

    void Promise.all([
      import('gsap'),
      import('gsap/ScrollTrigger'),
    ]).then(([{ default: gsap }, { ScrollTrigger }]) => {
      if (cancelled) return;

      gsap.registerPlugin(ScrollTrigger);
      context = gsap.context(() => {
        gsap.set(revealItems, { autoAlpha: 0, y: 18, willChange: 'transform, opacity' });
        gsap.timeline({
          defaults: { duration: 0.58, ease: 'power3.out' },
          scrollTrigger: {
            trigger: root,
            start: 'top 88%',
            once: true,
          },
        }).to(revealItems, {
          autoAlpha: 1,
          y: 0,
          stagger: 0.07,
          clearProps: 'willChange',
        });
      }, root);
    });

    return () => {
      cancelled = true;
      context?.revert();
    };
  }, []);

  return (
    <footer
      ref={footerRef}
      className="pateez-public-footer mt-14 border-t border-palette-beige/60 bg-[#F8F9FA]"
      aria-label={`${siteName} alt bilgisi`}
    >
      <div className="mx-auto w-full max-w-[1260px] px-4 pb-24 pt-10 md:px-8 md:py-10 lg:py-12">
        <div className="grid gap-8 md:grid-cols-2 lg:grid-cols-[minmax(0,1.18fr)_minmax(0,0.82fr)_minmax(0,0.82fr)_minmax(0,1fr)]">
          <section data-footer-reveal className="min-w-0">
            <a href="/" className="inline-flex items-center">
              {footerLogo ? (
                <img
                  src={footerLogo}
                  alt={siteName}
                  loading="eager"
                  decoding="async"
                  className="max-h-14 w-auto max-w-[210px] object-contain"
                />
              ) : (
                <span className="text-[26px] font-black leading-none tracking-normal text-gray-900">{siteName}</span>
              )}
            </a>
            {footerAbout && (
              <p className="mt-5 max-w-[420px] text-[13px] font-semibold leading-7 text-gray-600">
                {footerAbout}
              </p>
            )}
          </section>

          {pageGroups.corporate.length > 0 && (
            <section data-footer-reveal>
              <h2 className="mb-4 flex items-center gap-2 text-[12px] font-extrabold tracking-normal text-gray-950">
                <span className="h-3.5 w-1 rounded-full bg-palette-red" aria-hidden="true"></span>
                Kurumsal
              </h2>
              <LinkList links={pageGroups.corporate} />
            </section>
          )}

          {pageGroups.legal.length > 0 && (
            <section data-footer-reveal>
              <h2 className="mb-4 flex items-center gap-2 text-[12px] font-extrabold tracking-normal text-gray-950">
                <span className="h-3.5 w-1 rounded-full bg-palette-accent" aria-hidden="true"></span>
                Yasal
              </h2>
              <LinkList links={pageGroups.legal} />
            </section>
          )}

          <section data-footer-reveal>
            <h2 className="mb-4 flex items-center gap-2 text-[12px] font-extrabold tracking-normal text-gray-950">
              <span className="h-3.5 w-1 rounded-full bg-palette-maroon" aria-hidden="true"></span>
              İletişim
            </h2>

            <div className="space-y-3">
              {contactItems.map((item) => {
                const content = (
                  <>
                    <span className="inline-flex h-8 w-8 shrink-0 items-center justify-center rounded-[5px] border border-palette-beige/70 bg-white text-palette-red transition-colors group-hover:border-palette-red/35 group-hover:bg-palette-red group-hover:text-white">
                      <RemixIcon name={item.icon} size={15} />
                    </span>
                    <span className="min-w-0 truncate text-[13px] font-bold text-gray-600 transition-colors group-hover:text-gray-950">
                      {item.label}
                    </span>
                  </>
                );

                return item.href ? (
                  <a key={`${item.icon}-${item.label}`} href={item.href} className="group flex min-w-0 items-center gap-3">
                    {content}
                  </a>
                ) : (
                  <div key={`${item.icon}-${item.label}`} className="group flex min-w-0 items-center gap-3">
                    {content}
                  </div>
                );
              })}
            </div>

            {socialLinks.length > 0 && (
              <div className="mt-5 flex flex-wrap gap-2">
                {socialLinks.map((item) => (
                  <a
                    key={item.label}
                    href={item.href}
                    target="_blank"
                    rel="noreferrer"
                    aria-label={item.label}
                    className="inline-flex h-9 w-9 items-center justify-center rounded-[5px] border border-palette-beige/70 bg-white text-gray-500 transition-all hover:-translate-y-0.5 hover:border-palette-red/40 hover:bg-palette-red hover:text-white hover:shadow-[0_10px_24px_rgba(234,67,53,0.16)]"
                  >
                    <RemixIcon name={item.icon} size={17} />
                  </a>
                ))}
              </div>
            )}

            {pageGroups.contact && (
              <a
                href={pageHref(pageGroups.contact.slug)}
                className="mt-5 inline-flex h-10 items-center justify-center gap-2 rounded-[5px] bg-palette-red px-4 text-[12px] font-bold tracking-normal text-white shadow-[0_12px_28px_rgba(234,67,53,0.18)] transition-all hover:-translate-y-0.5 hover:bg-red-600"
              >
                <span>{pageGroups.contact.label}</span>
                <RemixIcon name="ri-arrow-right-s-line" size={15} />
              </a>
            )}
          </section>
        </div>

        <div data-footer-reveal className="mt-8 flex flex-col gap-3 border-t border-palette-beige/60 pt-5 md:flex-row md:items-center md:justify-between">
          <p className="text-[12px] font-bold text-gray-400">{copyright}</p>
          {pageGroups.legal.length > 0 && (
            <nav aria-label="Alt bilgi yasal bağlantıları" className="flex flex-wrap gap-x-4 gap-y-2">
              {pageGroups.legal.slice(0, 4).map((link) => (
                <a key={`bottom-${link.href}`} href={link.href} className="text-[12px] font-bold text-gray-400 transition-colors hover:text-palette-red">
                  {link.label}
                </a>
              ))}
            </nav>
          )}
        </div>
      </div>
    </footer>
  );
};

export default PublicFooter;
