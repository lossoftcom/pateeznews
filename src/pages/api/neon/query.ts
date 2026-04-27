import type { APIRoute } from 'astro';
import { executeQuerySpec, executeRpc } from '@/lib/server/neonQuery';

export const POST: APIRoute = async ({ request }) => {
  try {
    const body = await request.json();
    const result = body?.kind === 'rpc'
      ? await executeRpc(body.name, body.args || {})
      : await executeQuerySpec(body);

    return new Response(JSON.stringify(result), {
      status: result.error ? 400 : 200,
      headers: { 'Content-Type': 'application/json' },
    });
  } catch (error: any) {
    return new Response(JSON.stringify({
      data: null,
      error: { message: error.message || 'Query failed' },
      count: null,
    }), {
      status: 500,
      headers: { 'Content-Type': 'application/json' },
    });
  }
};
