import { defineConfig } from 'astro/config';
import react from '@astrojs/react';
import tailwind from '@astrojs/tailwind';
import vercel from '@astrojs/vercel';

import { fileURLToPath } from 'url';

const supabaseUrl = process.env.PUBLIC_SUPABASE_URL || process.env.VITE_SUPABASE_URL;
let supabaseHostname;
try {
    supabaseHostname = supabaseUrl ? new URL(supabaseUrl).hostname : undefined;
} catch {
    supabaseHostname = undefined;
}

// https://astro.build/config
export default defineConfig({
    output: 'server',
    adapter: vercel({
        webAnalytics: { enabled: true },
    }),
    integrations: [react(), tailwind()],
    image: {
        remotePatterns: [
            ...(supabaseHostname ? [{ protocol: 'https', hostname: supabaseHostname }] : [{ protocol: 'https', hostname: '**.supabase.co' }]),
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
                'react': fileURLToPath(new URL('./node_modules/react', import.meta.url)),
                'react-dom': fileURLToPath(new URL('./node_modules/react-dom', import.meta.url)),
                'react/jsx-runtime': fileURLToPath(new URL('./node_modules/react/jsx-runtime', import.meta.url)),
                'react-is': fileURLToPath(new URL('./node_modules/react-is', import.meta.url)),
                'scheduler': fileURLToPath(new URL('./node_modules/scheduler', import.meta.url)),
                'konva': fileURLToPath(new URL('./node_modules/konva', import.meta.url)),
            },
            dedupe: ['react', 'react-dom', 'styled-components', 'react-is', 'scheduler', 'konva', 'react-konva'],
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
                'immutable',
                'prop-types',
            ],
        }
    },
});
