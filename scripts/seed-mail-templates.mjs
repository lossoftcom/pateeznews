#!/usr/bin/env node
// Seeds the Pateez verification mail templates into public.mail_templates.
// Idempotent: matches by sablon_adi (updates if present, inserts if not).
// Data source: scripts/seed-mail-templates.data.json (HTML + MJML + variables).
//
// Usage:  node scripts/seed-mail-templates.mjs
// Optional env: SEED_KULLANICI=<profile-uuid> to force the "created_by" value.
//
// Connects to the Supabase Postgres named in .env.local (DATABASE_URL / pooler).

import fs from 'node:fs';
import pg from 'pg';

const ROOT = new URL('../', import.meta.url);
const dataUrl = new URL('./seed-mail-templates.data.json', import.meta.url);
const LEGACY_TEMPLATE_NAMES = [
  'Üyelik Doğrulama Kodu',
  'Şifre Sıfırlama Kodu',
  'Hoş Geldin',
  'Haber Özeti (Günlük / Haftalık)',
];

function loadEnv() {
  const env = {};
  try {
    const txt = fs.readFileSync(new URL('.env.local', ROOT), 'utf8');
    for (const line of txt.split('\n')) {
      const m = line.match(/^([A-Z0-9_]+)=(.*)$/);
      if (m) env[m[1]] = m[2].replace(/^["']|["']$/g, '');
    }
  } catch {}
  return env;
}

function pickUrl(env) {
  const candidates = [
    env.SUPABASE_POOLER_DATABASE_URL,
    env.DATABASE_URL,
    env.SUPABASE_DATABASE_URL,
    env.POSTGRES_URL,
  ].filter(Boolean);
  if (!candidates.length) throw new Error('No database URL found in .env.local');
  const u = new URL(candidates[0]);
  u.searchParams.delete('channel_binding');
  return u.toString();
}

function firstNonEmpty(...values) {
  for (const value of values) {
    const text = String(value || '').trim();
    if (text) return text;
  }
  return '';
}

function normalizeBaseUrl(value) {
  const text = String(value || '').trim();
  if (!text) return 'https://www.pateez.com/';
  try {
    const url = new URL(text);
    url.pathname = url.pathname || '/';
    return url.toString().replace(/\/?$/, '/');
  } catch {
    return 'https://www.pateez.com/';
  }
}

function absoluteUrl(base, value) {
  const text = String(value || '').trim();
  if (!text) return '';
  try {
    return new URL(text, base).toString();
  } catch {
    return text;
  }
}

function escapeHtml(value) {
  return String(value || '')
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
    .replace(/'/g, '&#039;');
}

function extractEmail(value) {
  const match = String(value || '').match(/[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}/i);
  return match ? match[0] : '';
}

async function loadTemplateContext(client) {
  const settings = await client.query(
    `SELECT site_name, copyright_text, logo_url, footer_logo_url, email_logo_url, canonical_url
       FROM public.site_settings
      WHERE language_code = 'tr'
      LIMIT 1`
  ).catch(() => ({ rows: [] }));
  const setting = settings.rows[0] || {};
  const siteUrl = normalizeBaseUrl(setting.canonical_url);
  const contact = await client.query(
    `SELECT title, slug, canonical_url, content_plain
       FROM public.pages
     WHERE language_code = 'tr'
        AND status = 'active'
        AND lower(slug) IN ('iletisim', 'contact')
      ORDER BY CASE WHEN lower(slug) = 'iletisim' THEN 0 ELSE 1 END, id
      LIMIT 1`
  ).catch(() => ({ rows: [] }));
  const contactPage = contact.rows[0] || {};

  const logoPath = firstNonEmpty(
    setting.email_logo_url,
    setting.logo_url,
    setting.footer_logo_url
  );
  const contactUrl = firstNonEmpty(contactPage.canonical_url, '/kurumsal/iletisim');

  return {
    SITE_NAME: firstNonEmpty(setting.site_name, 'Pateez.com'),
    SITE_URL: siteUrl,
    SITE_LOGO_URL: absoluteUrl(siteUrl, logoPath),
    COPYRIGHT_TEXT: firstNonEmpty(setting.copyright_text, '2026 Pateez'),
    CONTACT_URL: absoluteUrl(siteUrl, contactUrl),
    SUPPORT_EMAIL: firstNonEmpty(extractEmail(contactPage.content_plain), 'info@pateez.com'),
  };
}

function hydrateTemplate(template, context) {
  const textReplacements = Object.fromEntries(
    Object.entries(context).map(([key, value]) => [`__${key}__`, String(value || '')])
  );
  const markupReplacements = Object.fromEntries(
    Object.entries(context).map(([key, value]) => [`__${key}__`, escapeHtml(value)])
  );
  const replaceWith = (value, replacements) => Object.entries(replacements).reduce(
    (text, [token, replacement]) => text.replaceAll(token, replacement),
    String(value || '')
  );
  return {
    ...template,
    konu: replaceWith(template.konu, textReplacements),
    onizleme_metni: replaceWith(template.onizleme_metni, textReplacements),
    icerik_html: replaceWith(template.icerik_html, markupReplacements),
    icerik_mjml: replaceWith(template.icerik_mjml, markupReplacements),
  };
}

async function main() {
  const env = loadEnv();
  const data = JSON.parse(fs.readFileSync(dataUrl, 'utf8'));
  const client = new pg.Client({ connectionString: pickUrl(env), ssl: { rejectUnauthorized: false } });
  await client.connect();
  const templateContext = await loadTemplateContext(client);
  const templates = data.map((template) => hydrateTemplate(template, templateContext));

  if (process.argv.includes('--verify')) {
    const r = await client.query(
      `SELECT id::text AS id, sablon_adi, kategori, hazir_mi, aktif_mi,
              length(icerik_html) AS html_len, length(icerik_mjml) AS mjml_len,
              jsonb_array_length(COALESCE(NULLIF(degiskenler_json,'')::jsonb,'[]'::jsonb)) AS vars
         FROM public.mail_templates WHERE sablon_adi = ANY($1) ORDER BY id`,
      [templates.map((t) => t.sablon_adi)]
    );
    const legacy = await client.query(
      'SELECT COUNT(*)::integer AS count FROM public.mail_templates WHERE sablon_adi = ANY($1)',
      [LEGACY_TEMPLATE_NAMES]
    );
    console.table(r.rows);
    console.log('legacy template count:', legacy.rows[0]?.count || 0);
    await client.end();
    return;
  }

  console.log('Connected. Seeding %d templates into public.mail_templates …', templates.length);

  // Introspect columns so we only write what exists and learn kullanici rules.
  const cols = (await client.query(
    `SELECT column_name, is_nullable, column_default, data_type
       FROM information_schema.columns
      WHERE table_schema='public' AND table_name='mail_templates'`
  )).rows;
  if (!cols.length) throw new Error('public.mail_templates not found.');
  const byName = Object.fromEntries(cols.map((c) => [c.column_name, c]));
  const has = (n) => Boolean(byName[n]);

  // Resolve a creator id for kullanici only if the column is NOT NULL without a default.
  let kullanici = process.env.SEED_KULLANICI || null;
  const kc = byName['kullanici'];
  const kullaniciRequired = kc && kc.is_nullable === 'NO' && !kc.column_default;
  if (kullaniciRequired && !kullanici) {
    const r = await client.query(
      `SELECT id::text AS id FROM public.profiles
        WHERE lower(role) IN ('admin','super_admin') ORDER BY created_at NULLS LAST LIMIT 1`
    ).catch(() => ({ rows: [] }));
    kullanici = r.rows[0]?.id || null;
    if (!kullanici) console.warn('  ! kullanici is required but no admin profile found; set SEED_KULLANICI=<uuid>.');
  }

  const desiredNames = new Set(templates.map((t) => t.sablon_adi));
  const legacyToDelete = LEGACY_TEMPLATE_NAMES.filter((name) => !desiredNames.has(name));
  if (legacyToDelete.length) {
    const removed = await client.query(
      'DELETE FROM public.mail_templates WHERE sablon_adi = ANY($1)',
      [legacyToDelete]
    );
    console.log('  - removed %d legacy templates', removed.rowCount || 0);
  }

  let inserted = 0, updated = 0;
  for (const t of templates) {
    const row = {
      sablon_adi: t.sablon_adi,
      kategori: t.kategori,
      konu: t.konu,
      onizleme_metni: t.onizleme_metni,
      icerik_html: t.icerik_html,
      icerik_mjml: t.icerik_mjml,
      tasarim_json: '{}',
      degiskenler_json: JSON.stringify(t.degiskenler || []),
      hazir_mi: true,
      aktif_mi: true,
    };
    if (has('guncelleme_tarihi')) row.guncelleme_tarihi = new Date().toISOString();
    if (kullaniciRequired && kullanici && has('kullanici')) row.kullanici = kullanici;

    const existing = await client.query(
      'SELECT id::text AS id FROM public.mail_templates WHERE sablon_adi = $1 LIMIT 1',
      [t.sablon_adi]
    );

    if (existing.rows[0]) {
      const keys = Object.keys(row).filter((k) => k !== 'sablon_adi');
      const set = keys.map((k, i) => `${k} = $${i + 1}`).join(', ');
      await client.query(
        `UPDATE public.mail_templates SET ${set} WHERE id = $${keys.length + 1}::bigint`,
        [...keys.map((k) => row[k]), existing.rows[0].id]
      );
      updated++;
      console.log('  ~ updated  %s  (#%s)', t.sablon_adi, existing.rows[0].id);
    } else {
      if (has('olusturma_tarihi')) row.olusturma_tarihi = new Date().toISOString();
      const keys = Object.keys(row);
      const res = await client.query(
        `INSERT INTO public.mail_templates (${keys.join(', ')})
         VALUES (${keys.map((_, i) => `$${i + 1}`).join(', ')}) RETURNING id::text AS id`,
        keys.map((k) => row[k])
      );
      inserted++;
      console.log('  + inserted %s  (#%s)', t.sablon_adi, res.rows[0].id);
    }
  }

  await client.end();
  console.log('Done. %d inserted, %d updated.', inserted, updated);
}

main().catch((e) => { console.error('Seed failed:', e.message); process.exit(1); });
