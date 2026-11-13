import type { Config } from 'tailwindcss';

const token = (name: string) => `rgb(var(--c-${name}) / <alpha-value>)`;

const config: Config = {
  content: ['./src/**/*.{ts,tsx}'],
  darkMode: ['selector', '[data-theme="dark"]'],
  theme: {
    extend: {
      colors: {
        canvas: token('canvas'),
        sunken: token('sunken'),
        surface: token('surface'),
        elevated: token('elevated'),
        line: { DEFAULT: token('line'), strong: token('line-strong') },
        fg: { DEFAULT: token('text'), 2: token('text-2'), 3: token('text-3') },
        accent: { DEFAULT: token('accent'), hi: token('accent-hi'), on: token('on-accent') },
        success: token('success'),
        warning: token('warning'),
        danger: token('danger'),
        info: token('info'),
        horde: token('horde'),
        alliance: token('alliance'),
      },
      fontFamily: {
        display: ['var(--font-display)', 'Georgia', 'serif'],
        sans: ['var(--font-sans)', 'system-ui', 'sans-serif'],
      },
      fontSize: {
        '2xs': ['0.6875rem', { lineHeight: '1rem' }],
      },
      borderRadius: { sm: '3px', DEFAULT: '5px', md: '7px', lg: '10px' },
      boxShadow: {
        lift: '0 1px 0 rgb(255 255 255 / 0.04) inset, 0 12px 32px -16px rgb(0 0 0 / 0.6)',
        tooltip: '0 18px 48px -12px rgb(0 0 0 / 0.75)',
      },
      maxWidth: { prose: '68ch' },
      screens: { xs: '420px' },
    },
  },
  plugins: [],
};

export default config;
