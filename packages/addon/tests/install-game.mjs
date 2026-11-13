// Development install: copies packages/addon/BlazonGuild into the local WoW: Forever AddOns folder and
// verifies every file arrived byte for byte. Path from WOW_FOREVER_DIR or the default install location.
import crypto from 'node:crypto';
import fs from 'node:fs';
import path from 'node:path';

const here = path.dirname(new URL(import.meta.url).pathname.replace(/^\/(\w:)/, '$1'));
const src = path.join(here, '..', 'BlazonGuild');
const game = process.env.WOW_FOREVER_DIR ?? 'C:/Program Files (x86)/World of Warcraft/_forever_';
const dest = path.join(game, 'Interface', 'AddOns', 'BlazonGuild');

if (!fs.existsSync(path.join(game, 'Interface', 'AddOns'))) {
  console.error(`No encuentro la carpeta de addons en ${game}. Usa WOW_FOREVER_DIR=<ruta a _forever_>.`);
  process.exit(1);
}
fs.cpSync(src, dest, { recursive: true, force: true });

const hash = (f) => crypto.createHash('sha256').update(fs.readFileSync(f)).digest('hex');
const walk = (d) => fs.readdirSync(d, { withFileTypes: true }).flatMap((e) => (e.isDirectory() ? walk(path.join(d, e.name)) : [path.join(d, e.name)]));
const files = walk(src);
const bad = files.filter((f) => hash(f) !== hash(path.join(dest, path.relative(src, f))));
if (bad.length) {
  console.error('Copia incompleta:', bad.map((f) => path.relative(src, f)));
  process.exit(1);
}
console.log(`BlazonGuild instalado en ${dest} (${files.length} ficheros verificados)`);
