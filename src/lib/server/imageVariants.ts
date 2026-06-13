// Görsel varyantları için tek kaynak. Hem redirect endpoint'i ([...path].ts)
// hem de API yanıtlarındaki URL üreticileri (appFeed.ts, home.ts) bunu kullanır.

export const SUPPORTED_VARIANT_WIDTHS = [180, 260, 800, 900, 1200, 1440, 1600];
export const SUPPORTED_VARIANT_QUALITY = 86;

// image/ ve profile/ tipleri upload anında 7 genişlikte webp varyant üretir
// (bkz. scripts/local-storage-server.mjs). Yalnızca bu önekler için doğrudan
// statik varyant yolu güvenle kullanılabilir.
export const LOCAL_VARIANT_PREFIXES = ["image/", "profile/"];
export const TRANSFORMABLE_IMAGE_EXTENSIONS = new Set([
  ".jpg",
  ".jpeg",
  ".png",
  ".webp",
  ".avif",
]);

export function nearestVariantWidth(width: number): number {
  for (const candidate of SUPPORTED_VARIANT_WIDTHS) {
    if (width <= candidate) return candidate;
  }
  return SUPPORTED_VARIANT_WIDTHS[SUPPORTED_VARIANT_WIDTHS.length - 1];
}

export function objectExtension(objectPath: string): string {
  const clean = objectPath.split("?")[0].split("#")[0].toLowerCase();
  const dotIndex = clean.lastIndexOf(".");
  return dotIndex === -1 ? "" : clean.slice(dotIndex);
}

// "image/2026-06-12/foo.png" -> ".variants/w1200-q86/image/2026-06-12/foo.webp"
export function variantObjectPath(
  objectPath: string,
  width: number,
  quality: number = SUPPORTED_VARIANT_QUALITY,
): string {
  const clean = objectPath.replace(/^\/+/, "");
  const dotIndex = clean.lastIndexOf(".");
  const withoutExtension = dotIndex === -1 ? clean : clean.slice(0, dotIndex);
  return `.variants/w${width}-q${quality}/${withoutExtension}.webp`;
}
