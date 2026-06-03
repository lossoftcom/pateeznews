import { defineConfig } from 'astro/config';
import react from '@astrojs/react';
import cloudflare from '@astrojs/cloudflare';

import { fileURLToPath } from 'url';

const remoteImageHosts = (process.env.PUBLIC_REMOTE_IMAGE_HOSTS || '')
    .split(',')
    .map((host) => host.trim())
    .filter(Boolean);

const clientOptimizeDeps = [
    'emoji-picker-react',
    'lucide-react',
    'swiper/modules',
    'swiper/react',
];

const astroVirtualDeps = [
    'astro/virtual-modules/prefetch.js',
    'astro/virtual-modules/transitions.js',
    'astro/virtual-modules/transitions-router.js',
    'astro/virtual-modules/transitions-types.js',
    'astro/virtual-modules/transitions-events.js',
    'astro/virtual-modules/transitions-swap-functions.js',
];

// https://astro.build/config
export default defineConfig({
    output: 'server',
    adapter: cloudflare({
        imageService: 'passthrough',
        inspectorPort: 0,
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
            __PREFETCH_PREFETCH_ALL__: 'true',
            __PREFETCH_DEFAULT_STRATEGY__: JSON.stringify('hover'),
            __EXPERIMENTAL_CLIENT_PRERENDER__: 'false',
        },
        resolve: {
            dedupe: ['react', 'react-dom'],
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
        server: {
            watch: {
                ignored: [
                    '**/admin/build/**',
                    '**/admin/**/build/**',
                    '**/admin/.dart_tool/**',
                    '**/admin/web/**',
                    '**/admin/macos/Flutter/ephemeral/**',
                    '**/admin/ios/Flutter/ephemeral/**',
                    '**/admin/linux/flutter/ephemeral/**',
                    '**/admin/windows/flutter/ephemeral/**',
                ],
            },
        },
        ssr: {
            optimizeDeps: {
                exclude: astroVirtualDeps,
            },
        },
        optimizeDeps: {
            include: clientOptimizeDeps,
            exclude: astroVirtualDeps,
        }
    },
});
