const deepOcean = '#2C3E50';
const surface = '#F8F9FA';
const actionRed = '#EA4335';
const warmHorizon = '#F39C12';
const coolGray = '#95A5A6';

const neutralScale = {
  50: surface,
  100: surface,
  200: surface,
  300: coolGray,
  400: coolGray,
  500: coolGray,
  600: deepOcean,
  700: deepOcean,
  800: deepOcean,
  900: deepOcean,
  950: deepOcean,
};

const actionScale = {
  50: surface,
  100: surface,
  200: actionRed,
  300: actionRed,
  400: actionRed,
  500: actionRed,
  600: actionRed,
  700: deepOcean,
  800: deepOcean,
  900: deepOcean,
  950: deepOcean,
};

const accentScale = {
  50: surface,
  100: surface,
  200: warmHorizon,
  300: warmHorizon,
  400: warmHorizon,
  500: warmHorizon,
  600: warmHorizon,
  700: deepOcean,
  800: deepOcean,
  900: deepOcean,
  950: deepOcean,
};

const supportScale = {
  50: surface,
  100: surface,
  200: coolGray,
  300: coolGray,
  400: coolGray,
  500: coolGray,
  600: deepOcean,
  700: deepOcean,
  800: deepOcean,
  900: deepOcean,
  950: deepOcean,
};

/** @type {import('tailwindcss').Config} */
export default {
  content: [
    "./src/**/*.{astro,html,js,jsx,md,mdx,svelte,ts,tsx,vue}",
  ],
  theme: {
    extend: {
      fontFamily: {
        sans: ['"Inter"', 'sans-serif'],
        display: ['"Inter"', 'sans-serif'],
      },
      colors: {
        white: '#FFFFFF',
        black: deepOcean,
        gray: neutralScale,
        slate: neutralScale,
        zinc: neutralScale,
        neutral: neutralScale,
        stone: neutralScale,
        red: actionScale,
        rose: actionScale,
        pink: actionScale,
        orange: accentScale,
        amber: accentScale,
        yellow: accentScale,
        lime: accentScale,
        green: accentScale,
        emerald: accentScale,
        teal: supportScale,
        cyan: supportScale,
        sky: supportScale,
        blue: accentScale,
        indigo: supportScale,
        violet: supportScale,
        purple: supportScale,
        fuchsia: supportScale,
        palette: {
          beige: '#E5E7EB',
          tan: coolGray,
          maroon: deepOcean,
          red: actionRed,
          black: deepOcean,
          accent: warmHorizon,
        },
        primary: {
          DEFAULT: actionRed,
          50: surface,
          100: surface,
          500: actionRed,
          600: actionRed,
          700: deepOcean,
        }
      },
      animation: {
        'bounce-subtle': 'bounce-subtle 2s infinite ease-in-out',
        'equalizer': 'equalizer 1s ease-in-out infinite',
        'modal-entry': 'modal-entry 0.1s ease-out forwards',
        'backdrop-entry': 'fade-in 0.1s ease-out forwards',
        'shimmer': 'shimmer 2s infinite ease-in-out',
      },
      keyframes: {
        'bounce-subtle': {
          '0%, 100%': { transform: 'translateY(0)' },
          '50%': { transform: 'translateY(-3px)' },
        },
        'equalizer': {
          '0%': { height: '10%' },
          '50%': { height: '100%' },
          '100%': { height: '10%' },
        },
        'modal-entry': {
          '0%': { opacity: '0', transform: 'scale(0.97)' },
          '100%': { opacity: '1', transform: 'scale(1)' },
        },
        'fade-in': {
          '0%': { opacity: '0' },
          '100%': { opacity: '1' },
        },
        'shimmer': {
          '0%': { transform: 'translateX(-100%)' },
          '100%': { transform: 'translateX(100%)' },
        }
      }
    }
  },
  plugins: [],
}
