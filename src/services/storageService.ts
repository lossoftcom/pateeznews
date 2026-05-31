import { supabase } from '@/lib/supabase';

export interface MediaItem {
    id: string;
    value: string;
    size: number;
    date: number;
    type: string;
    src: string;
    thumb?: string; // Add thumb support
    path: string;
}

export interface RenameMediaWithAiPayload {
    src: string;
    type?: 'image' | 'video' | 'audio' | 'file' | 'logo' | 'profile';
    languageCode?: string;
    mediaKind?: string;
    context?: string;
}

export interface RenameMediaWithAiResult {
    success: boolean;
    filename: string;
    src: string;
    replacements: Array<{
        oldId: string;
        newId: string;
        oldSrc: string;
        newSrc: string;
    }>;
}

export interface GenerateMediaAltTextPayload {
    src: string;
    languageCode?: string;
    mediaKind?: string;
    context?: string;
    currentAlt?: string;
}

export interface GenerateMediaAltTextResult {
    success: boolean;
    altText: string;
    usedVision: boolean;
}

export const storageService = {
    async authHeaders(): Promise<Record<string, string>> {
        try {
            const { data: { session } } = await supabase.auth.getSession();
            return session?.access_token ? { Authorization: `Bearer ${session.access_token}` } : {};
        } catch {
            return {};
        }
    },

    async getFiles(type: 'image' | 'video' | 'audio' | 'file' | 'profile' = 'image'): Promise<MediaItem[]> {
        try {
            const response = await fetch(`/api/storage/list?type=${type}`);
            if (!response.ok) throw new Error('Failed to list files');
            const files = await response.json();
            return files.map((f: any) => ({
                ...f,
                type: f.type || type,
                path: f.path || f.id.split('/')[0]
            }));
        } catch (err) {
            console.error('Storage error:', err);
            return [];
        }
    },

    async uploadFile(file: File, customPath?: string, type?: 'image' | 'video' | 'audio' | 'file' | 'logo' | 'profile', lang?: string, customFilename?: string): Promise<MediaItem | null> {
        try {
            const formData = new FormData();
            formData.append('file', file);
            if (customPath) {
                formData.append('customPath', customPath);
            }
            if (type) {
                formData.append('type', type);
            }
            if (lang) {
                formData.append('lang', lang);
            }
            if (customFilename) {
                formData.append('customFilename', customFilename);
            }

            const controller = new AbortController();
            const timeoutId = setTimeout(() => controller.abort(), 120_000);

            const response = await fetch('/api/storage/upload', {
                method: 'POST',
                body: formData,
                headers: await this.authHeaders(),
                signal: controller.signal
            }).finally(() => clearTimeout(timeoutId));

            if (!response.ok) {
                const details = await response.text().catch(() => '');
                throw new Error(`Upload failed (${response.status})${details ? `: ${details}` : ''}`);
            }
            const result = await response.json();

            return {
                id: result.id,
                value: result.value,
                size: result.size || file.size,
                date: Date.now() / 1000,
                type: result.type || type || 'image',
                src: result.src,
                thumb: result.thumb,
                path: result.id.split('/')[0]
            };
        } catch (err) {
            console.error('Upload error:', err);
            return null;
        }
    },

    async replaceFile(file: File, fileId: string, type: 'image' | 'video' | 'audio' | 'file' | 'logo' | 'profile' = 'image'): Promise<MediaItem | null> {
        try {
            const formData = new FormData();
            formData.append('file', file);
            formData.append('replaceId', fileId);
            formData.append('type', type);

            const controller = new AbortController();
            const timeoutId = setTimeout(() => controller.abort(), 120_000);

            const response = await fetch('/api/storage/upload', {
                method: 'POST',
                body: formData,
                headers: await this.authHeaders(),
                signal: controller.signal
            }).finally(() => clearTimeout(timeoutId));

            if (!response.ok) {
                const details = await response.text().catch(() => '');
                throw new Error(`Replace failed (${response.status})${details ? `: ${details}` : ''}`);
            }

            const result = await response.json();

            return {
                id: result.id,
                value: result.value,
                size: result.size || file.size,
                date: Date.now() / 1000,
                type: result.type || type,
                src: result.src,
                thumb: result.thumb,
                path: result.id.split('/')[0]
            };
        } catch (err) {
            console.error('Replace error:', err);
            return null;
        }
    },

    async deleteFile(fileId: string, type?: string): Promise<boolean> {
        try {
            const response = await fetch('/api/storage/delete', {
                method: 'DELETE',
                headers: {
                    ...(await this.authHeaders()),
                    'Content-Type': 'application/json'
                },
                body: JSON.stringify({ id: fileId, type })
            });
            if (!response.ok) {
                const details = await response.text().catch(() => '');
                throw new Error(`Delete failed (${response.status})${details ? `: ${details}` : ''}`);
            }
            return true;
        } catch (err) {
            console.error('Delete error:', err);
            return false;
        }
    },

    async renameMediaWithAi(payload: RenameMediaWithAiPayload): Promise<RenameMediaWithAiResult | null> {
        try {
            const response = await fetch('/api/storage/seo-rename', {
                method: 'POST',
                headers: {
                    ...(await this.authHeaders()),
                    'Content-Type': 'application/json'
                },
                body: JSON.stringify(payload)
            });

            if (!response.ok) {
                const details = await response.text().catch(() => '');
                throw new Error(`SEO rename failed (${response.status})${details ? `: ${details}` : ''}`);
            }

            return await response.json();
        } catch (err) {
            console.error('SEO rename error:', err);
            return null;
        }
    },

    async generateMediaAltTextWithAi(payload: GenerateMediaAltTextPayload): Promise<GenerateMediaAltTextResult | null> {
        try {
            const response = await fetch('/api/storage/seo-alt-text', {
                method: 'POST',
                headers: {
                    ...(await this.authHeaders()),
                    'Content-Type': 'application/json'
                },
                body: JSON.stringify(payload)
            });

            if (!response.ok) {
                const details = await response.text().catch(() => '');
                throw new Error(`SEO alt text failed (${response.status})${details ? `: ${details}` : ''}`);
            }

            return await response.json();
        } catch (err) {
            console.error('SEO alt text error:', err);
            return null;
        }
    }
};
