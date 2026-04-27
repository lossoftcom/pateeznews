/// <reference types="vite/client" />

interface ImportMetaEnv {
    readonly DATABASE_URL?: string
    readonly NEON_DATABASE_URL?: string
    readonly NEON_AUTH_SECRET?: string
    readonly PUBLIC_REMOTE_IMAGE_HOSTS?: string
}

interface ImportMeta {
    readonly env: ImportMetaEnv
}
