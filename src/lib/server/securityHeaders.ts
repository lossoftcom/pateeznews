export const ADMIN_CONTENT_SECURITY_POLICY = [
  "default-src 'self'",
  "base-uri 'self'",
  "object-src 'none'",
  "frame-ancestors 'none'",
  "form-action 'self'",
  "img-src 'self' data: blob: https:",
  "font-src 'self' data: https://fonts.gstatic.com",
  "style-src 'self' 'unsafe-inline'",
  "script-src 'self' 'unsafe-inline' 'wasm-unsafe-eval' https://www.gstatic.com",
  "connect-src 'self' http://localhost:* http://127.0.0.1:* http://10.0.2.2:* https://*.supabase.co wss://*.supabase.co https://fonts.gstatic.com https://www.gstatic.com",
  "worker-src 'self' blob:",
  "manifest-src 'self'",
  "media-src 'self' data: blob: https:",
  "upgrade-insecure-requests",
].join('; ');

export const SECURITY_HEADERS = {
  'Strict-Transport-Security': 'max-age=31536000; includeSubDomains; preload',
  'X-Content-Type-Options': 'nosniff',
  'X-Frame-Options': 'DENY',
  'Referrer-Policy': 'no-referrer',
  'Permissions-Policy': 'accelerometer=(), autoplay=(), camera=(), clipboard-read=(), display-capture=(), encrypted-media=(), fullscreen=(self), geolocation=(), gyroscope=(), magnetometer=(), microphone=(), midi=(), payment=(), usb=()',
  'Cross-Origin-Opener-Policy': 'same-origin',
};

export function adminSecurityHeaders() {
  return {
    ...SECURITY_HEADERS,
    'Content-Security-Policy': ADMIN_CONTENT_SECURITY_POLICY,
  };
}
