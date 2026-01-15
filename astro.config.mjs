import { defineConfig } from 'astro/config';
import react from '@astrojs/react';
import tailwind from '@astrojs/tailwind';
import node from '@astrojs/node';

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
    adapter: node({
        mode: 'standalone',
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
            ],
        }
    },
});
