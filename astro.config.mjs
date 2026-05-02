import { defineConfig } from 'astro/config';
import react from '@astrojs/react';
import tailwind from '@astrojs/tailwind';
import vercel from '@astrojs/vercel';

import { fileURLToPath } from 'url';

const remoteImageHosts = (process.env.PUBLIC_REMOTE_IMAGE_HOSTS || '')
    .split(',')
    .map((host) => host.trim())
    .filter(Boolean);

const adminOptimizeDeps = [
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
    '@googleforcreators/element-library',
    '@googleforcreators/elements',
    '@googleforcreators/migration',
    '@scaleflex/ui/core/popper',
    '@scaleflex/icons',
    '@emotion/is-prop-valid',
    'styled-components',
    'react-dropzone',
    'react-quill-new',
    'emoji-picker-react',
    'lucide-react',
    'swiper/modules',
    'swiper/react',
    'bcryptjs',
    'pg',
];

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
        plugins: [
            {
                name: 'mediainfo-wasm-runtime-url',
                enforce: 'pre',
                transform(code, id) {
                    if (!id.includes('/mediainfo.js/dist/') || !code.includes('MediaInfoModule.wasm')) return null;
                    return code.replaceAll(
                        "new URL('MediaInfoModule.wasm', import.meta.url)",
                        "new URL(/* @vite-ignore */ 'MediaInfoModule.wasm', import.meta.url)"
                    ).replaceAll(
                        'new URL("MediaInfoModule.wasm", import.meta.url)',
                        'new URL(/* @vite-ignore */ "MediaInfoModule.wasm", import.meta.url)'
                    );
                },
            },
        ],
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
                    if (message.includes('MediaInfoModule.wasm') && message.includes("doesn't exist at build time")) return;
                    warn(warning);
                },
            },
        },
        optimizeDeps: {
            include: adminOptimizeDeps,
            // Admin uses large lazy-loaded editor modules. If Vite discovers a new
            // dependency after PostManagement starts loading, it invalidates the
            // optimized chunk hash and the browser can receive a 504 Outdated
            // Optimize Dep response. Keep the dev optimizer explicit so admin
            // edits do not trigger mid-load cache invalidation.
            noDiscovery: true,
        }
    },
});
