/** @type {import('tailwindcss').Config} */
export default {
  content: ['./index.html', './src/**/*.{js,ts,jsx,tsx}'],
  theme: {
    extend: {
      colors: {
        ink: '#07131F',
        navy: '#0B1C29',
        panel: '#102231',
        'panel-light': '#173044',
        mint: '#65F2D0',
        coral: '#FF6B7A',
        gold: '#FFD166',
        lavender: '#B8A1FF',
        muted: '#A9BAC8',
        success: '#70E49A',
        warning: '#FFB55E',
        danger: '#FF5572',
      },
      fontFamily: {
        sans: ['Manrope', 'ui-sans-serif', 'system-ui', 'sans-serif'],
        display: ['Space Grotesk', 'Manrope', 'ui-sans-serif', 'system-ui'],
      },
      boxShadow: {
        glow: '0 0 40px rgba(101, 242, 208, 0.12)',
        panel: '0 18px 50px rgba(2, 10, 18, 0.28)',
      },
      backgroundImage: {
        'quest-gradient':
          'linear-gradient(135deg, rgba(101, 242, 208, 0.18), rgba(184, 161, 255, 0.10) 48%, rgba(255, 107, 122, 0.09))',
      },
      keyframes: {
        'fade-up': {
          '0%': { opacity: '0', transform: 'translateY(8px)' },
          '100%': { opacity: '1', transform: 'translateY(0)' },
        },
        'soft-pulse': {
          '0%, 100%': { opacity: '0.55' },
          '50%': { opacity: '0.85' },
        },
      },
      animation: {
        'fade-up': 'fade-up 400ms ease-out both',
        'soft-pulse': 'soft-pulse 4s ease-in-out infinite',
      },
    },
  },
  plugins: [],
};
