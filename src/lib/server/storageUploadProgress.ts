export type StorageUploadPhase = 'processing' | 'done' | 'error';

export interface StorageUploadProgress {
    phase: StorageUploadPhase;
    progress: number | null;
    etaSeconds: number | null;
    message?: string;
    updatedAt: number;
}

type ProgressStore = Map<string, StorageUploadProgress>;

const store = () => {
    const globalScope = globalThis as typeof globalThis & {
        __pateezStorageUploadProgress?: ProgressStore;
    };
    globalScope.__pateezStorageUploadProgress ??= new Map();
    return globalScope.__pateezStorageUploadProgress;
};

const clampProgress = (value: number | null) => {
    if (value === null || !Number.isFinite(value)) return null;
    return Math.min(Math.max(value, 0), 1);
};

export const setStorageUploadProgress = (
    id: string | null | undefined,
    progress: Omit<StorageUploadProgress, 'updatedAt'>
) => {
    const normalized = id?.trim();
    if (!normalized) return;
    store().set(normalized, {
        ...progress,
        progress: clampProgress(progress.progress),
        etaSeconds:
            progress.etaSeconds !== null && Number.isFinite(progress.etaSeconds)
                ? Math.max(0, progress.etaSeconds)
                : null,
        updatedAt: Date.now(),
    });
};

export const getStorageUploadProgress = (id: string) => {
    cleanupStorageUploadProgress();
    return store().get(id) ?? null;
};

export const cleanupStorageUploadProgress = () => {
    const cutoff = Date.now() - 10 * 60 * 1000;
    for (const [id, progress] of store()) {
        if (progress.updatedAt < cutoff) store().delete(id);
    }
};
