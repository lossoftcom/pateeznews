import type { APIRoute } from 'astro';
import fs from 'fs';
import path from 'path';

const STORAGE_TYPES = ['image', 'video', 'audio', 'file', 'logo', 'profile'] as const;
type StorageType = typeof STORAGE_TYPES[number];

const jsonHeaders = { 'Content-Type': 'application/json' };

const safeDecode = (value: string) => {
    let decoded = value;

    for (let i = 0; i < 3; i++) {
        try {
            const next = decodeURIComponent(decoded);
            if (next === decoded) break;
            decoded = next;
        } catch {
            break;
        }
    }

    return decoded;
};

const getStorageType = (value: unknown): StorageType | null => {
    return typeof value === 'string' && STORAGE_TYPES.includes(value as StorageType)
        ? value as StorageType
        : null;
};

const isInside = (baseDir: string, targetPath: string) => {
    const relative = path.relative(baseDir, targetPath);
    return relative === '' || (!relative.startsWith('..') && !path.isAbsolute(relative));
};

const normalizeId = (value: string) => {
    return safeDecode(value)
        .replace(/\\/g, '/')
        .replace(/^\/+/, '')
        .replace(/^Upload\//i, '');
};

const unique = <T,>(items: T[]) => Array.from(new Set(items));

export const DELETE: APIRoute = async ({ params, request }) => {
    try {
        const url = new URL(request.url);
        let body: { id?: unknown; type?: unknown } = {};

        if ((request.headers.get('content-type') || '').includes('application/json')) {
            try {
                body = await request.json();
            } catch {
                body = {};
            }
        }

        const rawId = typeof body.id === 'string'
            ? body.id
            : url.searchParams.get('id') || params.id;

        if (!rawId) {
            return new Response(JSON.stringify({ error: 'File ID required' }), {
                status: 400,
                headers: jsonHeaders
            });
        }

        let fileId = normalizeId(rawId);
        let typeHint = getStorageType(body.type) || getStorageType(url.searchParams.get('type'));

        const firstSegment = fileId.split('/')[0];
        if (STORAGE_TYPES.includes(firstSegment as StorageType)) {
            typeHint = typeHint || firstSegment as StorageType;
            fileId = fileId.split('/').slice(1).join('/');
        }

        if (!fileId || fileId.includes('\0')) {
            return new Response(JSON.stringify({ error: 'Invalid file ID' }), {
                status: 400,
                headers: jsonHeaders
            });
        }

        const uploadRootDir = path.resolve(process.cwd(), 'Upload');
        const searchTypes = typeHint
            ? unique([typeHint, ...STORAGE_TYPES])
            : [...STORAGE_TYPES];

        const candidateIds = unique([
            fileId,
            fileId.normalize('NFC'),
            fileId.normalize('NFD')
        ]);

        for (const type of searchTypes) {
            const baseDir = path.resolve(uploadRootDir, type);

            for (const candidateId of candidateIds) {
                const fullPath = path.resolve(baseDir, candidateId);

                if (!isInside(baseDir, fullPath)) {
                    continue;
                }

                if (!fs.existsSync(fullPath) || !fs.statSync(fullPath).isFile()) {
                    continue;
                }

                fs.unlinkSync(fullPath);

                return new Response(JSON.stringify({ success: true, id: candidateId, type }), {
                    status: 200,
                    headers: jsonHeaders
                });
            }
        }

        return new Response(JSON.stringify({
            error: 'File not found',
            id: fileId,
            type: typeHint,
            searchedTypes: searchTypes
        }), {
            status: 404,
            headers: jsonHeaders
        });
    } catch (err: any) {
        console.error('Delete Error:', err);
        return new Response(JSON.stringify({ error: err.message }), {
            status: 500,
            headers: jsonHeaders
        });
    }
};
