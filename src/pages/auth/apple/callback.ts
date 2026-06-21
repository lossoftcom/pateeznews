import type { APIRoute } from 'astro';

export const prerender = false;

const closeHtml = '<!doctype html><meta charset="utf-8"><script>window.close();</script>';

export const GET: APIRoute = async () =>
  new Response(closeHtml, {
    headers: {
      'Content-Type': 'text/html; charset=utf-8',
      'Cache-Control': 'no-store',
    },
  });

export const POST: APIRoute = async () =>
  new Response(closeHtml, {
    headers: {
      'Content-Type': 'text/html; charset=utf-8',
      'Cache-Control': 'no-store',
    },
  });
