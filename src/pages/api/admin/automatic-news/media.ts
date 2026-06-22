import type { APIRoute } from 'astro';
import { adminError, adminJson, requireAdminRequest } from '@/lib/server/adminAuth';
import { dbQuery } from '@/lib/server/supabaseDb';

type Row = { source_url: string | null; canonical_url: string | null; image_url: string | null; raw_payload: unknown };
const clean = (v: unknown) => String(v || '').replace(/\s+/g, ' ').trim();
const add = (a: string[], v: string) => { const u = clean(v); const k = u.replace(/\?.*$/, ''); if (u && !a.some(x => x.replace(/\?.*$/, '') === k)) a.push(u); };
const abs = (base: string, v: string) => { try { const u = new URL(clean(v), base); u.hash = ''; return /^https?:$/.test(u.protocol) ? u.toString() : ''; } catch { return ''; } };
const good = (u: string) => /^https?:\/\//i.test(u) && (/\.(avif|webp|jpe?g|png|gif)(\?|$)/i.test(u) || /(image|uploads|media|cdn|crop)/i.test(u)) && !/(logo|favicon|sprite|icon|avatar|author|profile|placeholder|default|loading|blank|pixel|emoji|whatsapp|telegram|advert|banner|reklam)/i.test(u);

function payloadImages(payload: unknown) {
  const out: string[] = [];
  const visit = (v: unknown, depth = 0) => {
    if (depth > 4 || v == null) return;
    if (typeof v === 'string') { if (good(v)) add(out, v); return; }
    if (Array.isArray(v)) { for (const x of v) visit(x, depth + 1); return; }
    if (typeof v === 'object') {
      for (const [k, x] of Object.entries(v as Record<string, unknown>)) {
        if (/(image|photo|picture|media|display|thumbnail|carousel|sidecar|url)/i.test(k)) visit(x, depth + 1);
      }
    }
  };
  visit(payload);
  return out;
}

function htmlImages(html: string, base: string, primary: string) {
  const out: string[] = [];
  add(out, abs(base, primary));
  for (const m of html.matchAll(/<meta[^>]+(?:property|name)=["'](?:og:image|twitter:image)["'][^>]+content=["']([^"']+)["'][^>]*>/gi)) add(out, abs(base, m[1]));
  for (const m of html.matchAll(/<img[^>]+>/gi)) {
    const tag = m[0];
    if (/(logo|avatar|author|share|social|reklam|advert|banner|footer|header|menu|nav|breadcrumb|comment|yorum)/i.test(tag)) continue;
    const src = tag.match(/\s(?:src|data-src|data-original|data-lazy-src|data-large|data-full)=["']([^"']+)["']/i)?.[1]
      || tag.match(/\ssrcset=["']([^"']+)["']/i)?.[1]?.split(',').pop()?.trim().split(/\s+/)[0]
      || '';
    const u = abs(base, src);
    if (good(u)) add(out, u);
  }
  return out.slice(0, 12);
}

async function fetchImages(pageUrl: string, primary: string) {
  if (!pageUrl) return [];
  const res = await fetch(pageUrl, { signal: AbortSignal.timeout(5500), redirect: 'follow', headers: { 'User-Agent': 'Pateez-AutomaticNewsMedia/1.0' } });
  if (!res.ok || !/text\/html|application\/xhtml/i.test(res.headers.get('content-type') || '')) return [];
  return htmlImages(await res.text(), res.url || pageUrl, primary);
}

export const GET: APIRoute = async ({ request, url }) => {
  try {
    await requireAdminRequest(request, 'view_settings');
    const id = clean(url.searchParams.get('id'));
    if (!id) return adminJson({ data: { images: [] }, error: { message: 'Haber id gerekli' } }, 400);
    const result = await dbQuery<Row>(`SELECT source_url, canonical_url, image_url, raw_payload FROM public.automatic_news_items WHERE id = $1 LIMIT 1`, [id]);
    const row = result.rows[0];
    if (!row) return adminJson({ data: { images: [] }, error: { message: 'Haber bulunamadı' } }, 404);
    const primary = clean(row.image_url);
    const page = clean(row.canonical_url || row.source_url);
    const images: string[] = [];
    for (const x of payloadImages(row.raw_payload)) add(images, x);
    add(images, primary);
    for (const x of await fetchImages(page, primary).catch(() => [])) add(images, x);
    return adminJson({ data: { images: images.slice(0, 12), primaryImageUrl: primary, sourceUrl: row.source_url || '', canonicalUrl: row.canonical_url || '' }, error: null });
  } catch (error) {
    return adminError(error);
  }
};
