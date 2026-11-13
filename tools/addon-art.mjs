// Exports BlazonGuild's original web artwork (the same SVG ornaments and procedural textures the web uses)
// to PNG for the in-game addon. The probe confirmed the WoW: Forever client draws addon PNGs.
// Usage: node tools/addon-art.mjs   → packages/addon/BlazonGuild/Media/*.png
import fs from 'node:fs';
import path from 'node:path';
import { chromium } from 'playwright';

const OUT = path.resolve('packages/addon/BlazonGuild/Media');
fs.mkdirSync(OUT, { recursive: true });

const gold = (id) => `<defs><linearGradient id="${id}" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stop-color="#fff1c8"/><stop offset=".35" stop-color="#d9b56a"/><stop offset=".6" stop-color="#8f6a2b"/><stop offset="1" stop-color="#f0d18a"/></linearGradient></defs>`;

// Seamless noise tiles: same filters as apps/web/src/components/art/textures.ts, with stitchTiles for tiling.
const tile = (base, filter) => `<svg xmlns="http://www.w3.org/2000/svg" width="256" height="256"><rect width="256" height="256" fill="${base}"/>${filter}</svg>`;
const METAL = `<filter id="m" x="0" y="0"><feTurbulence type="fractalNoise" baseFrequency=".004 .55" numOctaves="3" seed="2" stitchTiles="stitch"/><feColorMatrix values="0 0 0 0 .62  0 0 0 0 .64  0 0 0 0 .68  0 0 0 .16 0"/></filter><rect width="256" height="256" filter="url(#m)"/>`;
const GRAIN = `<filter id="g"><feTurbulence type="fractalNoise" baseFrequency=".85" numOctaves="2" stitchTiles="stitch"/><feColorMatrix values="0 0 0 0 .7  0 0 0 0 .72  0 0 0 0 .78  0 0 0 .07 0"/></filter><rect width="256" height="256" filter="url(#g)"/>`;

const ASSETS = {
  logo: {
    w: 64, h: 64,
    svg: `<svg viewBox="0 0 32 32" width="64" height="64">${gold('lg')}<path d="M16 2 28 8v8c0 7-5.2 12.2-12 14C9.2 28.2 4 23 4 16V8z" fill="#10141c" stroke="url(#lg)" stroke-width="1.4"/><path fill-rule="evenodd" d="M11 8.5h6.4c3.1 0 5 1.6 5 4 0 1.5-.8 2.6-2.1 3.1 1.8.5 2.9 1.8 2.9 3.6 0 2.8-2.1 4.6-5.4 4.6H11zm3 2.6v3.7h3.1c1.4 0 2.2-.7 2.2-1.9 0-1.1-.8-1.8-2.2-1.8zm0 6.2v4.5h3.4c1.6 0 2.5-.8 2.5-2.2 0-1.5-.9-2.3-2.5-2.3z" fill="url(#lg)"/></svg>`,
  },
  corner: {
    w: 128, h: 128,
    svg: `<svg viewBox="0 0 72 72" width="128" height="128">${gold('fc')}<g fill="none" stroke="url(#fc)" stroke-linecap="round"><path d="M3 70V18Q3 3 18 3h52" stroke-width="2"/><path d="M9 70V22Q9 9 22 9h48" stroke-width=".9" opacity=".75"/><path d="M18 18c9 0 15 5 16 14-5-4-10-4-13 1-1-7-5-11-12-11 3-1 6-2 9-4z" fill="url(#fc)" stroke="none"/><path d="M30 3c4 4 4 9 0 12M3 30c4 4 9 4 12 0" stroke-width="1.2"/><circle cx="15" cy="15" r="3.2" fill="url(#fc)" stroke="none"/><circle cx="40" cy="6" r="1.4" fill="url(#fc)" stroke="none"/><circle cx="6" cy="40" r="1.4" fill="url(#fc)" stroke="none"/></g></svg>`,
  },
  divider: {
    w: 512, h: 32,
    svg: `<svg viewBox="0 0 400 24" preserveAspectRatio="none" width="512" height="32"><defs><linearGradient id="rd" x1="0" x2="1"><stop offset="0" stop-color="#c9a35a" stop-opacity="0"/><stop offset=".42" stop-color="#e9cd8b"/><stop offset=".58" stop-color="#e9cd8b"/><stop offset="1" stop-color="#c9a35a" stop-opacity="0"/></linearGradient></defs><path d="M0 12H178M222 12H400" stroke="url(#rd)" stroke-width="1.2"/><path d="M0 16H170M230 16H400" stroke="url(#rd)" stroke-width=".5" opacity=".6"/><path d="M200 2l10 10-10 10-10-10z" fill="none" stroke="#e9cd8b" stroke-width="1.4"/><path d="M200 7l5 5-5 5-5-5z" fill="#e9cd8b"/><circle cx="183" cy="12" r="2" fill="#e9cd8b"/><circle cx="217" cy="12" r="2" fill="#e9cd8b"/></svg>`,
  },
  // Heraldic medallion frame (same construction as GuildCrest.tsx): gold rim, dark gap, field, inner rail.
  ring: {
    w: 128, h: 128,
    svg: `<svg viewBox="0 0 100 100" width="128" height="128">${gold('rg')}<defs><radialGradient id="sh" cx="50%" cy="38%" r="62%"><stop offset="0%" stop-color="#fff" stop-opacity=".18"/><stop offset="70%" stop-color="#000" stop-opacity="0"/><stop offset="100%" stop-color="#000" stop-opacity=".45"/></radialGradient></defs><circle cx="50" cy="50" r="48" fill="url(#rg)"/><circle cx="50" cy="50" r="44.5" fill="#0b0e13"/><circle cx="50" cy="50" r="42" fill="#1d232d"/><circle cx="50" cy="50" r="42" fill="url(#sh)"/><circle cx="50" cy="50" r="38" fill="none" stroke="#d0b078" stroke-opacity=".55" stroke-width=".8"/></svg>`,
  },
  // Lozenge bullet used by section headings on the web.
  lozenge: {
    w: 32, h: 32,
    svg: `<svg viewBox="0 0 16 16" width="32" height="32">${gold('lz')}<path d="M8 1.5 14.5 8 8 14.5 1.5 8z" fill="none" stroke="url(#lz)" stroke-width="1.4"/><path d="M8 5 11 8 8 11 5 8z" fill="url(#lz)"/></svg>`,
  },
  // Sort arrow (points up; the addon flips it for descending). Game fonts lack ▲▼.
  sort: {
    w: 16, h: 16,
    svg: `<svg viewBox="0 0 16 16" width="16" height="16"><path d="M8 4 13 11H3z" fill="#e6cc98"/></svg>`,
  },
  metal: { w: 256, h: 256, svg: tile('#151b24', METAL), opaque: true },
  sunken: { w: 256, h: 256, svg: tile('#10141c', METAL), opaque: true },
  canvas: { w: 256, h: 256, svg: tile('#0b0e13', GRAIN), opaque: true },
};

const browser = await chromium.launch();
const page = await browser.newPage({ deviceScaleFactor: 1 });
for (const [name, a] of Object.entries(ASSETS)) {
  await page.setViewportSize({ width: a.w, height: a.h });
  await page.setContent(`<html><body style="margin:0;background:transparent">${a.svg}</body></html>`);
  await page.screenshot({ path: path.join(OUT, `${name}.png`), omitBackground: !a.opaque, clip: { x: 0, y: 0, width: a.w, height: a.h } });
  console.log(`${name}.png ${a.w}×${a.h}`);
}
await browser.close();
