import react from '@vitejs/plugin-react';
import { defineConfig } from 'vite';

// Web Back Office (tenant). Dev: proxy /api ke pos-backend :3001.
// Prod: set VITE_API_BASE ke origin backend.
export default defineConfig({
  plugins: [react()],
  server: {
    host: true,
    port: 5175,
    proxy: {
      '/api': {
        target: 'http://localhost:3001',
        changeOrigin: true,
      },
    },
  },
});
