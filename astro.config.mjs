import { defineConfig } from 'astro/config';
import react from '@astrojs/react';
import tailwind from '@astrojs/tailwind';
import vercel from '@astrojs/vercel';

import { fileURLToPath } from 'url';

const remoteImageHosts = (process.env.PUBLIC_REMOTE_IMAGE_HOSTS || '')
    .split(',')
    .map((host) => host.trim())
    .filter(Boolean);

// https://astro.build/config
export default defineConfig({
    output: 'server',
    adapter: vercel({
        webAnalytics: { enabled: true },
    }),
    integrations: [react(), tailwind()],
    image: {
        remotePatterns: [
            ...remoteImageHosts.map((hostname) => ({ protocol: 'https', hostname })),
            { protocol: 'https', hostname: 'images.unsplash.com' },
            { protocol: 'https', hostname: 'picsum.photos' },
        ],
    },
    prefetch: {
        prefetchAll: true,
        defaultStrategy: 'hover',
    },
    vite: {
        define: {
            global: 'globalThis',
        },
        resolve: {
            alias: {
                '@': fileURLToPath(new URL('./src', import.meta.url)),
                // 'konva/lib/Global.js': fileURLToPath(new URL('./src/shims/konva-global.ts', import.meta.url)),
            },
        },
        build: {
            commonjsOptions: {
                transformMixedEsModules: true,
            },
        },
        optimizeDeps: {
            include: [
                'scheduler',
                'react-reconciler',
                'react-reconciler/constants',
                'konva',
                'react-konva',
                'react-filerobot-image-editor',
                'react-filerobot-image-editor/lib/actions',
                'react-filerobot-image-editor/lib/hooks/useStore',
                'react-filerobot-image-editor/lib/components/ToolsBar/ToolsBarItemButton',
                'react-filerobot-image-editor/lib/components/tools/tools.constants',
                '@googleforcreators/story-editor',
                '@scaleflex/ui/core/popper',
                '@scaleflex/icons',
                'styled-components',
                // Prevent dev hard-refresh 504 "Outdated Optimize Dep" flashes for heavy admin deps.
                'react-dropzone',
                'react-quill-new',
                '@emotion/is-prop-valid',
            ],
        }
    },
});
