/// <reference types="astro/client" />
/// <reference types="@astrojs/cloudflare" />
/// <reference types="@cloudflare/workers-types" />

declare global {
  interface Body {
    json(): Promise<any>;
  }

  interface Request {
    json(): Promise<any>;
  }

  interface Response {
    json(): Promise<any>;
  }
}

export {};
