import type { Metadata, Viewport } from 'next';
import { IBM_Plex_Sans, Marcellus } from 'next/font/google';
import Script from 'next/script';
import './globals.css';
import { GRAIN, METAL, STONE } from '@/components/art/textures';

const display = Marcellus({ weight: '400', subsets: ['latin', 'latin-ext'], variable: '--font-display', display: 'swap' });
const sans = IBM_Plex_Sans({ weight: ['400', '500', '600', '700'], subsets: ['latin', 'latin-ext'], variable: '--font-sans', display: 'swap' });

export const metadata: Metadata = {
  title: { default: 'BlazonGuild — Hermandades de World of Warcraft: Forever', template: '%s · BlazonGuild' },
  description: 'Roster, armería, raids y clasificaciones de cualquier hermandad de World of Warcraft: Forever, con datos oficiales de Battle.net.',
  applicationName: 'BlazonGuild',
};

export const viewport: Viewport = {
  width: 'device-width',
  initialScale: 1,
  themeColor: [
    { media: '(prefers-color-scheme: dark)', color: '#0B0E13' },
    { media: '(prefers-color-scheme: light)', color: '#E9ECF1' },
  ],
};

/** Applies the stored/system theme before first paint (no flash of the wrong theme). */
const themeScript = `(function(){try{var t=localStorage.getItem('forever-theme');if(t!=='dark'&&t!=='light'){t=window.matchMedia('(prefers-color-scheme: light)').matches?'light':'dark'}document.documentElement.dataset.theme=t}catch(e){document.documentElement.dataset.theme='dark'}})();`;

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="es" className={`${display.variable} ${sans.variable}`} suppressHydrationWarning>
      <head>
        <style>{`:root{--tex-metal:${METAL};--tex-stone:${STONE};--tex-grain:${GRAIN}}`}</style>
      </head>
      <body>
        <Script id="forever-theme" strategy="beforeInteractive">
          {themeScript}
        </Script>
        <a href="#main" className="sr-only focus:not-sr-only focus:fixed focus:left-3 focus:top-3 focus:z-[100] focus:rounded focus:bg-accent focus:px-4 focus:py-2 focus:text-accent-on">
          Saltar al contenido
        </a>
        {children}
      </body>
    </html>
  );
}
