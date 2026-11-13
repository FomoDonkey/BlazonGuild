// Real-browser screenshots for visual review: desktop (1440) + mobile (390), dark + light.
// Usage: node tools/screenshots.mjs <outDir> <path> [path...] [--themes=dark,light] [--widths=1440,390] [--full]
import fs from 'node:fs';
import path from 'node:path';
import { chromium } from 'playwright';

const args = process.argv.slice(2);
const flags = Object.fromEntries(args.filter((a) => a.startsWith('--')).map((a) => a.slice(2).split('=')));
const [outDir, ...paths] = args.filter((a) => !a.startsWith('--'));
if (!outDir || !paths.length) {
  console.error('Uso: node tools/screenshots.mjs <dir-salida> /ruta [/ruta...] [--themes=dark,light] [--widths=1440,390] [--full]');
  process.exit(1);
}
const base = process.env.BASE_URL ?? 'http://localhost:3000';
const themes = (flags.themes ?? 'dark').split(',');
const widths = (flags.widths ?? '1440,390').split(',').map(Number);
fs.mkdirSync(outDir, { recursive: true });

const browser = await chromium.launch();
const problems = [];
for (const theme of themes) {
  for (const width of widths) {
    const ctx = await browser.newContext({
      viewport: { width, height: width < 600 ? 844 : 900 },
      deviceScaleFactor: width < 600 ? 2 : 1,
      colorScheme: theme === 'light' ? 'light' : 'dark',
      reducedMotion: 'reduce',
    });
    await ctx.addInitScript((t) => localStorage.setItem('forever-theme', t), theme);
    if (process.env.LOGIN) {
      // LOGIN="email:password" → authenticate once per context through the real API.
      const [email, ...pw] = process.env.LOGIN.split(':');
      const r = await ctx.request.post(base + '/api/v1/auth/login', { data: { email, password: pw.join(':') } });
      if (!r.ok()) problems.push(`[login] HTTP ${r.status()}`);
    }
    const page = await ctx.newPage();
    page.on('console', (m) => m.type() === 'error' && problems.push(`[console] ${m.text().slice(0, 200)}`));
    page.on('pageerror', (e) => problems.push(`[pageerror] ${e.message.slice(0, 200)}`));
    for (const p of paths) {
      const res = await page.goto(base + p, { waitUntil: 'networkidle', timeout: 60_000 });
      await page.waitForTimeout(400);
      const overflow = await page.evaluate(() => document.documentElement.scrollWidth - window.innerWidth);
      if (overflow > 1) problems.push(`[overflow] ${p} @${width}px: ${overflow}px de scroll horizontal`);
      const name = `${p.replace(/[^a-z0-9]+/gi, '_').replace(/^_|_$/g, '') || 'home'}_${width}_${theme}.png`;
      await page.screenshot({ path: path.join(outDir, name), fullPage: 'full' in flags });
      console.log(`${res?.status()} ${name}`);
    }
    await ctx.close();
  }
}
await browser.close();
if (problems.length) console.log('\nProblemas detectados:\n' + [...new Set(problems)].join('\n'));
