import type { APIRoute } from 'astro';
import fs from 'fs';
import path from 'path';

export const POST: APIRoute = async ({ request }) => {
    try {
        const formData = await request.formData();
        const file = formData.get('file') as File;

        if (!file || !(file instanceof File)) {
            return new Response('No file uploaded', { status: 400 });
        }

        const type = (formData.get('type') as string) || 'image';

        let customPath = formData.get('customPath') as string;
        if (!customPath) {
            const today = new Date();
            customPath = `${today.getFullYear()}-${String(today.getMonth() + 1).padStart(2, '0')}-${String(today.getDate()).padStart(2, '0')}`;
        }

        const uploadRootDir = path.resolve(process.cwd(), 'Upload');
        const typeDir = path.join(uploadRootDir, type);
        const targetDir = path.join(typeDir, customPath);

        if (!fs.existsSync(targetDir)) {
            fs.mkdirSync(targetDir, { recursive: true });
        }

        let customFilename = formData.get('customFilename') as string;
        let finalFilename = file.name;

        if (customFilename) {
            const ext = path.extname(file.name);
            finalFilename = customFilename.endsWith(ext) ? customFilename : `${customFilename}${ext}`;
        } else {
            // Ensure unique filename
            finalFilename = `${Date.now()}-${file.name.replace(/[^a-zA-Z0-9.-]/g, '_')}`;
        }

        const fullPath = path.join(targetDir, finalFilename);

        // Write file
        const arrayBuffer = await file.arrayBuffer();
        fs.writeFileSync(fullPath, Buffer.from(arrayBuffer));

        const relativeId = `${customPath}/${finalFilename}`;

        return new Response(JSON.stringify({
            id: relativeId,
            value: finalFilename,
            src: `/api/storage/file/${type}/${relativeId}`,
            thumb: `/api/storage/file/${type}/${relativeId}`
        }), {
            status: 200,
            headers: {
                'Content-Type': 'application/json'
            }
        });

    } catch (err: any) {
        console.error('Upload Error:', err);
        return new Response(err.message || 'Server Error', { status: 500 });
    }
};
