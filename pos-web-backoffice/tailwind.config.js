/** @type {import('tailwindcss').Config} */
export default {
  content: ['./index.html', './src/**/*.{js,ts,jsx,tsx}'],
  theme: {
    extend: {
      colors: {
        // Token final DESIGN_TOKENS_POS_V2 / FIGMA_MAKE_DESIGN_BRIEF §0
        brand: {
          DEFAULT: '#1D4ED8',
          hover: '#1E40AF',
          light: '#EFF6FF',
        },
        sidebar: '#0F172A',
        sidebarText: '#94A3B8',
        ink: '#0F172A',
        ink2: '#334155',
        muted: '#64748B',
        disabled: '#94A3B8',
        line: '#E2E8F0',
        line2: '#CBD5E1',
        surface: '#FFFFFF',
        surface2: '#F8FAFC',
        bg: '#F4F6F9',
        ok: '#16A34A',
        okl: '#DCFCE7',
        warn: '#D97706',
        warnl: '#FEF3C7',
        err: '#DC2626',
        errl: '#FEE2E2',
        info: '#1E3A8A',
        infol: '#DBEAFE',
      },
      fontFamily: {
        sans: ['Inter', 'system-ui', '-apple-system', 'Segoe UI', 'Roboto', 'sans-serif'],
        mono: ['"JetBrains Mono"', 'ui-monospace', 'SFMono-Regular', 'monospace'],
      },
      borderRadius: { card: '12px', modal: '14px' },
      boxShadow: {
        card: '0 1px 3px rgba(0,0,0,.06)',
        cardHover: '0 4px 12px rgba(0,0,0,.10)',
        btn: '0 4px 12px rgba(29,78,216,.30)',
        modal: '0 24px 48px rgba(0,0,0,.18)',
      },
    },
  },
  plugins: [],
};
