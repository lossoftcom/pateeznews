import { fileURLToPath, URL } from 'node:url';
import { defineConfig } from 'vite';
import react from '@vitejs/plugin-react';

// Builds the isolated Google Web Stories editor into the Flutter admin assets
// folder (admin/assets/web_stories), mirroring the vendored posta_builder bundle.
export default defineConfig({
  plugins: [react()],
  base: './',
  resolve: {
    alias: [
      {
        find: './panes/media/local/mediaPane.js',
        replacement: fileURLToPath(
          new URL('./src/CustomMediaPane.jsx', import.meta.url)
        ),
      },
      {
        find: 'module',
        replacement: fileURLToPath(
          new URL('./src/shims/node-module.js', import.meta.url)
        ),
      },
    ],
  },
  define: {
    // Some @googleforcreators packages read process.env.* at runtime.
    'process.env.NODE_ENV': JSON.stringify('production'),
  },
  build: {
    outDir: fileURLToPath(new URL('../assets/web_stories', import.meta.url)),
    emptyOutDir: true,
    chunkSizeWarningLimit: 8000,
    sourcemap: false,
    rollupOptions: {
      onwarn(warning, warn) {
        if (
          warning.code === 'INVALID_ANNOTATION' &&
          warning.id &&
          warning.id.includes('@daybrush/utils')
        ) {
          return;
        }
        warn(warning);
      },
    },
  },
});
