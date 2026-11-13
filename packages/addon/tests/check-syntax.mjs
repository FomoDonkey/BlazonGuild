// Lua 5.1 syntax check of every file listed in the .toc, plus a report of globals the addon writes.
import fs from 'node:fs';
import path from 'node:path';
import luaparse from 'luaparse';

const root = path.resolve(path.dirname(new URL(import.meta.url).pathname.replace(/^\/(\w:)/, '$1')), '..', 'BlazonGuild');
const toc = fs.readFileSync(path.join(root, 'BlazonGuild.toc'), 'utf8');
const files = toc.split(/\r?\n/).filter((l) => l.trim() && !l.startsWith('#')).map((l) => l.trim().replace(/\\/g, '/'));
const ALLOWED_GLOBALS = new Set(['BlazonGuildDB', 'BINDING_HEADER_BLAZONGUILD', 'BINDING_NAME_BLAZONGUILD_TOGGLE', 'SLASH_BLAZONGUILD1', 'SLASH_BLAZONGUILD2', 'BlazonGuildAPI']); // (BlazonGuildAPI: the API for other addons, Core/API.lua)
let failed = false;
for (const f of files) {
  const src = fs.readFileSync(path.join(root, f), 'utf8');
  // A single backslash before a letter inside a string ("Interface\Icons") is not an error in Lua 5.1: the
  // backslash silently disappears and the game gets a path that does not exist. Game paths need "\\".
  const badEscape = src.split('\n').findIndex((line) => /(^|[^\\])\\[A-Za-z]/.test(line.replace(/\\\\/g, '')) && !/^\s*--/.test(line) && /\\[A-Z]/.test(line.replace(/\\\\/g, '')));
  if (badEscape >= 0) {
    failed = true;
    console.log(`✗ ${f}:${badEscape + 1}: ruta con una sola barra invertida (deben ser dos)`);
    continue;
  }
  try {
    const ast = luaparse.parse(src, { luaVersion: '5.1', scope: true });
    const globals = new Set();
    const walk = (n) => {
      if (!n || typeof n !== 'object') return;
      if (Array.isArray(n)) return n.forEach(walk);
      if (n.type === 'AssignmentStatement') for (const v of n.variables) if (v.type === 'Identifier' && v.isLocal === false) globals.add(v.name);
      for (const k of Object.keys(n)) walk(n[k]);
    };
    walk(ast);
    const unexpected = [...globals].filter((g) => !ALLOWED_GLOBALS.has(g));
    if (unexpected.length) {
      failed = true;
      console.log(`✗ ${f}: escribe globales no previstas: ${unexpected.join(', ')}`);
    } else console.log(`✓ ${f}`);
  } catch (e) {
    failed = true;
    console.log(`✗ ${f}: ${e.message}`);
  }
}
if (failed) process.exit(1);
console.log(`Sintaxis Lua 5.1 correcta en ${files.length} ficheros`);
