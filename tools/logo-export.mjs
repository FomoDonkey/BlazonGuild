// Exports BlazonGuild's crest (the same SVG as tools/addon-art.mjs' logo) large, for stores like CurseForge:
// a transparent PNG and one on the dark plate of the addon's window. Usage: node tools/logo-export.mjs <folder>
import path from 'node:path';
import { chromium } from 'playwright';

const out = path.resolve(process.argv[2] ?? '.');
const SIZE = 512;
const gold = `<defs><linearGradient id="lg" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stop-color="#fff1c8"/><stop offset=".35" stop-color="#d9b56a"/><stop offset=".6" stop-color="#8f6a2b"/><stop offset="1" stop-color="#f0d18a"/></linearGradient></defs>`;
const crest = (size) => `<svg viewBox="0 0 32 32" width="${size}" height="${size}">${gold}<path d="M16 2 28 8v8c0 7-5.2 12.2-12 14C9.2 28.2 4 23 4 16V8z" fill="#10141c" stroke="url(#lg)" stroke-width="1.4"/><path fill-rule="evenodd" d="M11 8.5h6.4c3.1 0 5 1.6 5 4 0 1.5-.8 2.6-2.1 3.1 1.8.5 2.9 1.8 2.9 3.6 0 2.8-2.1 4.6-5.4 4.6H11zm3 2.6v3.7h3.1c1.4 0 2.2-.7 2.2-1.9 0-1.1-.8-1.8-2.2-1.8zm0 6.2v4.5h3.4c1.6 0 2.5-.8 2.5-2.2 0-1.5-.9-2.3-2.5-2.3z" fill="url(#lg)"/></svg>`;
const files = {
  'BlazonGuild-logo-transparente.png': { html: crest(SIZE), transparent: true },
  'BlazonGuild-logo-curseforge.png': {
    html: `<div style="width:${SIZE}px;height:${SIZE}px;display:flex;align-items:center;justify-content:center;background:radial-gradient(circle at 50% 38%,#1d232d 0%,#0b0e13 72%)">${crest(Math.round(SIZE * 0.8))}</div>`,
    transparent: false,
  },
};
const browser = await chromium.launch();
const page = await browser.newPage({ deviceScaleFactor: 1, viewport: { width: SIZE, height: SIZE } });
for (const [name, f] of Object.entries(files)) {
  await page.setContent(`<html><body style="margin:0;background:transparent">${f.html}</body></html>`);
  await page.screenshot({ path: path.join(out, name), omitBackground: f.transparent, clip: { x: 0, y: 0, width: SIZE, height: SIZE } });
  console.log(path.join(out, name), `${SIZE}×${SIZE}`);
}
await browser.close();
