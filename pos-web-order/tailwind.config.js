/** @type {import('tailwindcss').Config} */
export default {
  content: ['./index.html', './src/**/*.{js,ts,jsx,tsx}'],
  theme: {
    extend: {
      colors: {
        brand: {
          DEFAULT: '#1D4ED8',
          light: '#EFF6FF',
          dark: '#1E3A8A',
        },
        ink: '#0F172A',
        ink2: '#334155',
        muted: '#64748B',
        line: '#E2E8F0',
        surface: '#FFFFFF',
        surface2: '#F8FAFC',
        bg: '#F4F6F9',
        ok: '#16A34A',
        okl: '#DCFCE7',
        warn: '#D97706',
        warnl: '#FEF3C7',
        err: '#DC2626',
        errl: '#FEE2E2',
      },
      fontFamily: {
        sans: ['Inter', 'system-ui', '-apple-system', 'Segoe UI', 'Roboto', 'sans-serif'],
        mono: ['"JetBrains Mono"', 'ui-monospace', 'SFMono-Regular', 'monospace'],
      },
      maxWidth: { app: '480px' },
    },
  },
  plugins: [],
};
