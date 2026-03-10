import type { APIRoute } from 'astro';
import fs from 'fs';
import path from 'path';

export const DELETE: APIRoute = async ({ params }) => {
    try {
        let fileId = params.id;

        if (!fileId) {
            return new Response('File ID required', { status: 400 });
        }

        // Try decoding if encoded
        try {
            fileId = decodeURIComponent(fileId);
        } catch (e) { }

        const uploadRootDir = path.resolve(process.cwd(), 'Upload');

        // Since we don't receive the 'type', search across all type directories
        const types = ['image', 'video', 'audio', 'file', 'logo', 'profile'];
        let deleted = false;

        for (const type of types) {
            const fullPath = path.join(uploadRootDir, type, fileId);
            if (fs.existsSync(fullPath)) {
                fs.unlinkSync(fullPath);
                deleted = true;
                break;
            }
        }

        if (deleted) {
            return new Response(JSON.stringify({ success: true }), {
                status: 200,
                headers: { 'Content-Type': 'application/json' }
            });
        } else {
            return new Response('File not found', { status: 404 });
        }
    } catch (err: any) {
        console.error('Delete Error:', err);
        return new Response(JSON.stringify({ error: err.message }), {
            status: 500,
            headers: { 'Content-Type': 'application/json' }
        });
    }
};
