// Checks the translation files: each chunk has as many texts as its part of i18n/source.json, each translation has the
// same values in it (%s, %d... as many; %1$s... may reorder them) and keeps a leading space or line break where the
// Spanish has one (the ends of joined texts). Run: node tests/i18n-check.mjs [lang]
import { readFileSync, readdirSync, existsSync } from 'node:fs';
import { join, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';
import { LANGS, CHUNK } from './i18n-build.mjs';

const ROOT = join(dirname(fileURLToPath(import.meta.url)), '..');
const source = JSON.parse(readFileSync(join(ROOT, 'i18n', 'source.json'), 'utf8'));
const specs = (s) => (s.replace(/%%/g, '').match(/%(\d\$)?[-\d.]*[sdx]/g) || []).length;

export function check(lang) {
  const problems = [];
  let done = 0;
  const dir = join(ROOT, 'i18n', lang);
  if (!existsSync(dir)) return { done, problems };
  for (const f of readdirSync(dir).filter((x) => /^\d+\.json$/.test(x)).sort()) {
    const base = parseInt(f, 10) * CHUNK;
    let arr;
    try {
      arr = JSON.parse(readFileSync(join(dir, f), 'utf8'));
    } catch (e) {
      problems.push(`${lang}/${f}: no es JSON válido (${e.message})`);
      continue;
    }
    const want = Math.min(CHUNK, source.length - base);
    if (arr.length !== want) problems.push(`${lang}/${f}: ${arr.length} textos, deberían ser ${want}`);
    arr.forEach((t, i) => {
      const k = source[base + i];
      if (k === undefined || typeof t !== 'string') return;
      done++;
      if (specs(k) !== specs(t)) problems.push(`${lang}/${f} #${base + i}: valores ${specs(t)} en vez de ${specs(k)}: ${JSON.stringify(k)} -> ${JSON.stringify(t)}`);
      if (/^\s/.test(k) && !/^\s/.test(t)) problems.push(`${lang}/${f} #${base + i}: espacio inicial distinto: ${JSON.stringify(k)} -> ${JSON.stringify(t)}`);
    });
  }
  return { done, problems };
}

if (process.argv[1] && fileURLToPath(import.meta.url) === process.argv[1]) {
  const only = process.argv[2];
  let bad = 0;
  for (const lang of only ? [only] : LANGS) {
    const { done, problems } = check(lang);
    console.log(`${lang}: ${done} de ${source.length}${problems.length ? `, ${problems.length} problemas` : ''}`);
    for (const p of problems.slice(0, 15)) console.log('  ' + p);
    bad += problems.length;
  }
  process.exit(bad ? 1 : 0);
}
