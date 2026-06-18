const PUBLIC_HTML_CACHE = 'public, max-age=0, s-maxage=60, stale-while-revalidate=300';
const PUBLIC_HTML_VARY = ['Accept-Language', 'Cookie'];

function mergeHeaderList(current: string | null, additions: string[]) {
  const values = new Set(
    String(current || '')
      .split(',')
      .map((value) => value.trim())
      .filter(Boolean)
  );
  for (const addition of additions) values.add(addition);
  return Array.from(values).join(', ');
}

export function setPublicHtmlCache(response: Response) {
  response.headers.set('Cache-Control', PUBLIC_HTML_CACHE);
  response.headers.set('CDN-Cache-Control', PUBLIC_HTML_CACHE);
  response.headers.set('Cloudflare-CDN-Cache-Control', PUBLIC_HTML_CACHE);
  response.headers.set('Vary', mergeHeaderList(response.headers.get('Vary'), PUBLIC_HTML_VARY));
}
