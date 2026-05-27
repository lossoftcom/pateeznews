import type { APIRoute } from 'astro';
import { getStorageUploadProgress } from '../../../../lib/server/storageUploadProgress';

export const GET: APIRoute = async ({ params }) => {
    const id = params.id?.trim();
    if (!id) {
        return new Response(JSON.stringify({ error: 'Upload progress ID is required' }), {
            status: 400,
            headers: { 'Content-Type': 'application/json' },
        });
    }

    const progress = getStorageUploadProgress(id);
    if (!progress) {
        return new Response(JSON.stringify({ phase: 'waiting', progress: null, etaSeconds: null }), {
            status: 200,
            headers: { 'Content-Type': 'application/json', 'Cache-Control': 'no-store' },
        });
    }

    return new Response(JSON.stringify(progress), {
        status: 200,
        headers: { 'Content-Type': 'application/json', 'Cache-Control': 'no-store' },
    });
};
