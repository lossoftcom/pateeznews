import { fileURLToPath, URL } from 'node:url';
import { defineConfig } from 'vite';
import react from '@vitejs/plugin-react';

// Builds the isolated Google Web Stories editor into the Flutter admin assets
// folder (admin/assets/web_stories), mirroring the vendored posta_builder bundle.
export default defineConfig({
  plugins: [react()],
  base: './',
  define: {
    // Some @googleforcreators packages read process.env.* at runtime.
    'process.env.NODE_ENV': JSON.stringify('production'),
  },
  build: {
    outDir: fileURLToPath(new URL('../assets/web_stories', import.meta.url)),
    emptyOutDir: true,
    chunkSizeWarningLimit: 8000,
    sourcemap: false,
  },
});
