import { defineConfig } from 'astro/config';
import react from '@astrojs/react';
import vercel from '@astrojs/vercel';

import { fileURLToPath } from 'url';

const remoteImageHosts = (process.env.PUBLIC_REMOTE_IMAGE_HOSTS || '')
    .split(',')
    .map((host) => host.trim())
    .filter(Boolean);

const clientOptimizeDeps = [
    '@astrojs/react/client.js',
    'react',
    'react-dom',
    'react-dom/client',
    'react/jsx-dev-runtime',
    'react/jsx-runtime',
    'astro > aria-query',
    'astro > axobject-query',
    'astro > html-escaper',
    'astro/virtual-modules/transitions-router.js',
    'astro/virtual-modules/transitions-types.js',
    'astro/virtual-modules/transitions-events.js',
    'astro/virtual-modules/transitions-swap-functions.js',
    'astro/runtime/client/dev-toolbar/entrypoint.js',
    'scheduler',
    'emoji-picker-react',
    'lucide-react',
    'swiper/modules',
    'swiper/react',
];

// https://astro.build/config
export default defineConfig({
    output: 'server',
    adapter: vercel({
        webAnalytics: { enabled: true },
    }),
    integrations: [react()],
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
            },
        },
        build: {
            chunkSizeWarningLimit: 6000,
            commonjsOptions: {
                transformMixedEsModules: true,
            },
            rollupOptions: {
                onwarn(warning, warn) {
                    const id = String(warning.id || '');
                    const message = String(warning.message || '');
                    if (id.includes('@daybrush/utils') && message.includes('#__PURE__')) return;
                    warn(warning);
                },
            },
        },
        optimizeDeps: {
            include: clientOptimizeDeps,
            noDiscovery: true,
        }
    },
});
