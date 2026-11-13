// WCAG 2.2 contrast validator for the BlazonGuild design tokens (apps/web/src/app/globals.css).
import fs from 'node:fs';
const css = fs.readFileSync(new URL('../apps/web/src/app/globals.css', import.meta.url), 'utf8');
const block = (sel) => css.slice(css.indexOf(sel), css.indexOf('}', css.indexOf(sel)));
const parse = (b) => {
  const out = {};
  for (const m of b.matchAll(/--([\w-]+):\s*([^;]+);/g)) {
    const v = m[2].trim();
    if (/^\d+ \d+ \d+$/.test(v)) out[m[1]] = v.split(' ').map(Number);
    else if (/^#[0-9a-f]{6}$/i.test(v)) out[m[1]] = [1, 3, 5].map((i) => parseInt(v.slice(i, i + 2), 16));
  }
  return out;
};
const lum = ([r, g, b]) => {
  const f = (c) => ((c /= 255) <= 0.03928 ? c / 12.92 : ((c + 0.055) / 1.055) ** 2.4);
  return 0.2126 * f(r) + 0.7152 * f(g) + 0.0722 * f(b);
};
const ratio = (a, b) => {
  const [x, y] = [lum(a), lum(b)].sort((p, q) => q - p);
  return (x + 0.05) / (y + 0.05);
};
const themes = { dark: parse(block(":root[data-theme='dark']") + block(':root,')), light: parse(block(":root[data-theme='light']")) };
themes.dark = { ...parse(block(':root,')), ...themes.dark };
let fail = 0;
for (const [name, t] of Object.entries(themes)) {
  const checks = [];
  for (const bg of ['canvas', 'surface', 'elevated', 'sunken']) {
    for (const fg of ['c-text', 'c-text-2', 'c-text-3', 'c-accent', 'c-success', 'c-warning', 'c-danger', 'c-info', 'c-horde', 'c-alliance']) checks.push([fg, 'c-' + bg, 4.5]);
  }
  checks.push(['c-on-accent', 'c-accent', 4.5], ['c-on-accent', 'c-accent-hi', 4.5], ['c-line-strong', 'c-surface', 3]);
  const bgClass = name === 'dark' ? 'c-surface' : 'c-surface';
  for (const id of [1, 2, 3, 4, 5, 7, 8, 9, 11]) checks.push([`class-${id}`, bgClass, 4.5], [`class-${id}`, 'c-elevated', 4.5]);
  for (const q of ['POOR', 'COMMON', 'UNCOMMON', 'RARE', 'EPIC', 'LEGENDARY']) checks.push([`q-${q}`, name === 'dark' ? 'tooltip-bg' : 'c-surface', 4.5]);
  for (const [fg, bg, min] of checks) {
    const r = ratio(t[fg], t[bg]);
    if (r < min) { fail++; console.log(`FAIL ${name.padEnd(5)} ${fg} on ${bg}: ${r.toFixed(2)} < ${min}`); }
  }
  console.log(`${name}: ${checks.length} pares comprobados`);
}
console.log(fail ? `\n${fail} pares por debajo de AA` : '\nTodos los pares cumplen WCAG 2.2 AA');
process.exit(fail ? 1 : 0);
