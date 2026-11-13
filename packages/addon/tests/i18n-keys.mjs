// The texts to translate, read from the addon's own code (Spanish is the source language). Every text shown on
// screen is a string literal, or literals joined with `..` around values: the joined ones become templates with
// "%s" where a value goes ("Ha matado a " .. n .. " miembros" -> "Ha matado a %s miembros"), and string.format's
// own format strings are kept as they are. Run directly, it writes i18n/keys.json (the list a translator works on).
import { readFileSync, readdirSync, statSync, writeFileSync, mkdirSync } from 'node:fs';
import { join, relative, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';

const HERE = dirname(fileURLToPath(import.meta.url));
export const ADDON = join(HERE, '..', 'BlazonGuild');
const SKIP_FILES = /(^|[\\/])(Ed25519\.lua|DemoData\.lua|Locales[\\/])/; // (DemoData: the capture mode's example guild, data and not texts)

function luaFiles(dir) {
  const out = [];
  for (const name of readdirSync(dir)) {
    const p = join(dir, name);
    if (statSync(p).isDirectory()) out.push(...luaFiles(p));
    else if (name.endsWith('.lua')) out.push(p);
  }
  return out;
}

// Tokens: strings (with their value), names, numbers, symbols; comments dropped.
function tokenize(src) {
  const t = [];
  let i = 0;
  const n = src.length;
  while (i < n) {
    const c = src[i];
    if (c === '-' && src[i + 1] === '-') {
      const long = src.slice(i + 2).match(/^\[(=*)\[/);
      if (long) {
        const close = ']' + long[1] + ']';
        const end = src.indexOf(close, i + 2 + long[0].length);
        i = end < 0 ? n : end + close.length;
      } else {
        const end = src.indexOf('\n', i);
        i = end < 0 ? n : end;
      }
      continue;
    }
    if (/\s/.test(c)) { i++; continue; }
    if (c === '"' || c === "'") {
      let j = i + 1, v = '';
      while (j < n && src[j] !== c) {
        if (src[j] === '\\') {
          const e = src[j + 1];
          const map = { n: '\n', t: '\t', '\\': '\\', '"': '"', "'": "'" };
          if (map[e] !== undefined) { v += map[e]; j += 2; continue; }
          if (/\d/.test(e)) { const m = src.slice(j + 1).match(/^\d{1,3}/); v += String.fromCharCode(+m[0]); j += 1 + m[0].length; continue; }
          v += e; j += 2; continue;
        }
        v += src[j]; j++;
      }
      t.push({ k: 'str', v, line: src.slice(0, i).split('\n').length });
      i = j + 1;
      continue;
    }
    const long = src.slice(i).match(/^\[(=*)\[/);
    if (long) {
      const close = ']' + long[1] + ']';
      const end = src.indexOf(close, i + long[0].length);
      t.push({ k: 'str', v: src.slice(i + long[0].length, end), line: 0 });
      i = end + close.length;
      continue;
    }
    const name = src.slice(i).match(/^[A-Za-z_][A-Za-z0-9_]*/);
    if (name) { t.push({ k: 'name', v: name[0] }); i += name[0].length; continue; }
    const num = src.slice(i).match(/^(0x[0-9a-fA-F]+|\d+\.?\d*(e[+-]?\d+)?)/);
    if (num) { t.push({ k: 'num', v: num[0] }); i += num[0].length; continue; }
    const sym = src.slice(i).match(/^(\.\.\.|\.\.|==|~=|<=|>=|::|[-+*/%^#<>=(){}\[\];:,.])/);
    t.push({ k: 'sym', v: sym ? sym[0] : c });
    i += sym ? sym[0].length : 1;
  }
  return t;
}

const STOP = new Set(['and', 'or', 'not', 'return', 'then', 'do', 'else', 'elseif', 'end', 'local', 'if', 'in', 'until', 'while', 'for', 'function', 'repeat']);
const STOP_SYM = new Set([',', ';', '=', '==', '~=', '<', '>', '<=', '>=']);
// Calls whose string arguments are never shown (names of things, codes, events, paths, patterns).
const CODE_CALLS = new Set(['Define', 'Get', 'List', 'Put', 'Delete', 'Register', 'Send', 'On', 'Fire', 'RegisterEvent', 'CreateFrame',
  'SetPoint', 'SetTexture', 'find', 'match', 'gmatch', 'gsub', 'file', 'Sound', 'RecordError', 'Debug', 'SetFont', 'CreateTexture',
  'CreateFontString', 'SetScript', 'HookScript', 'GetScript', 'RegisterForDrag', 'RegisterForClicks', 'ShowView', 'RefreshView',
  'Scan', 'Format', 'Accept', 'RegisterView', 'Tile', 'Unit', 'pcall', 'date', 'Expiry', 'IsOrganiser', 'SetFrameStrata', 'SetGradient']);

const isText = (s) => {
  if (/^[VD]$/.test(s)) return true; // (the Arena's V and D, a win and a loss: shown, so translated)
  const words = s.replace(/\|T[^|]*\|t|\|c[0-9a-fA-F%s]{1,8}|\|r|\|H[^|]*\|h|%[-\d.]*[sdx]|BlazonGuild|png/g, '');
  if (!/[A-Za-zÁÉÍÓÚÑáéíóúñü¿¡]{2,}/.test(words)) return false;
  if (/^[A-Z0-9_]+$/.test(s)) return false; // CODES
  if (/^(Interface|Fonts|Sound)[\\/]/.test(s)) return false;
  if (/^\|T[^|]*\|t ?$/.test(s)) return false;
  if (/^[a-z][A-Za-z0-9_]*$/.test(s) && !/[áéíóúñ]/.test(s) && s.length <= 3) return false;
  // Lua patterns ("^(.-)%s*$"), but not a text that starts with a value ("%s de BlazonGuild y %s del calendario"),
  // nor a sentence that goes on (". La organiza ") or something in brackets ("(tú)")
  if (/^[\^$[\]*+?-]/.test(s) || /^\.(?!\s)/.test(s) || /^\((?![A-Za-zÁÉÍÓÚÑáéíóúñ¿¡])/.test(s) || /^%(?![-\d.]*[sd] )/.test(s)
    || /%[a-z]{1}[+*-]?$/.test(s) && !/\s/.test(s)) return false;
  if (/^[A-Za-z]+[-][A-Za-z0-9]+$/.test(s)) return false; // GUID-like, keys
  if (/^[0-9a-fA-F]{6,8}$/.test(s)) return false; // colours
  if (/\.(png|tga|blp|ttf|lua|toc)$/i.test(s) || /^%s[a-z]+\.(png|tga)$/.test(s)) return false; // files
  if (/^\/[a-z]+$/.test(s)) return false; // slash commands
  if (/^[a-z0-9]{20,}$/.test(s)) return false; // alphabets, ids
  if (/^(BG_|SIM|Player-|Creature-|Interface)/.test(s)) return false;
  if (/_/.test(s) && !/\s/.test(s)) return false; // code names
  if (/^Jc[JE]$/.test(s)) return true; // (JcJ and JcE: the Spanish for PvP and PvE, not CamelCase names)
  if (/^[A-Z][a-z0-9]+([A-Z][A-Za-z0-9]*)+$/.test(s)) return false; // CamelCase names of the game's API and our frames
  if (/^(Creature|Horde|Alliance|LeftButton|RightButton|BlazonGuild)$/.test(s)) return false;
  return true;
};

// Every chain of operands joined by `..` at one depth: { parts: [{ lit } | { val }] }.
function chains(tokens) {
  const out = [];
  const stack = [[]]; // per depth: the current chain's parts and whether a `..` is pending
  let cur = { parts: [], val: false, joined: false };
  const flush = () => {
    if (cur.parts.length) out.push(cur);
    cur = { parts: [], val: false, joined: false };
  };
  const pushOperand = (part) => {
    if (cur.parts.length && !cur.joined) flush();
    cur.parts.push(part);
    cur.joined = false;
  };
  const curStack = [];
  for (let i = 0; i < tokens.length; i++) {
    const tk = tokens[i];
    if (tk.k === 'sym' && (tk.v === '(' || tk.v === '{' || tk.v === '[')) {
      // a call or a bracket opens: what comes before it is part of the current operand (a value)
      const callName = tokens[i - 1] && tokens[i - 1].k === 'name' ? tokens[i - 1].v : null;
      curStack.push({ cur, callName });
      cur = { parts: [], val: false, joined: false, code: callName && CODE_CALLS.has(callName), key: tk.v === '[' };
      continue;
    }
    if (tk.k === 'sym' && (tk.v === ')' || tk.v === '}' || tk.v === ']')) {
      flush();
      const top = curStack.pop();
      if (!top) continue;
      const inner = out.splice(0); // (keep them: they belong to the list too)
      collected.push(...inner.map((c) => ({ ...c, code: c.code || (top && top.code) })));
      cur = top.cur;
      // the bracket was a value inside the outer operand
      if (!cur.parts.length || cur.joined) { cur.parts.push({ val: true }); cur.joined = false; }
      continue;
    }
    if (tk.k === 'sym' && tk.v === '..') { cur.joined = true; continue; }
    if ((tk.k === 'name' && STOP.has(tk.v)) || (tk.k === 'sym' && STOP_SYM.has(tk.v))) { flush(); continue; }
    if (tk.k === 'str') {
      // a string right after a name is a call with one string argument: f"x" (code, e.g. require)
      pushOperand({ lit: tk.v, line: tk.line });
      continue;
    }
    // names, numbers, '.', ':', arithmetic: parts of a value operand
    if (tk.k === 'sym' && ['+', '-', '*', '/', '%', '^', '#', '.', ':'].includes(tk.v)) {
      if (cur.parts.length && !cur.joined) { const last = cur.parts[cur.parts.length - 1]; if (!last.val) cur.parts[cur.parts.length - 1] = { val: true }; }
      continue;
    }
    if (cur.parts.length && !cur.joined && cur.parts[cur.parts.length - 1].val) continue; // (still the same value)
    pushOperand({ val: true });
  }
  flush();
  collected.push(...out);
  return collected.splice(0);
}
const collected = [];

// A chain as a template: its literal pieces with %s for each value; only those with some text.
function template(chain) {
  const lits = chain.parts.filter((p) => p.lit !== undefined);
  if (!lits.length) return null;
  if (!lits.some((p) => isText(p.lit))) return null;
  if (chain.parts.length === 1) return { key: lits[0].lit, line: lits[0].line, plain: true };
  let key = '';
  for (const p of chain.parts) key += p.lit !== undefined ? p.lit.replace(/%/g, '%%') : '%s';
  return { key, line: lits[0].line, plain: false };
}

export function extractKeys() {
  const keys = new Map();
  for (const file of luaFiles(ADDON)) {
    const rel = relative(ADDON, file);
    if (SKIP_FILES.test(rel)) continue;
    const toks = tokenize(readFileSync(file, 'utf8'));
    // string.format("...") format strings: kept as they are
    for (let i = 0; i + 4 < toks.length; i++) {
      if (toks[i].v === 'format' && toks[i + 1].v === '(' && toks[i + 2].k === 'str' && isText(toks[i + 2].v)) {
        add(keys, toks[i + 2].v, rel, toks[i + 2].line);
      }
    }
    // BG.TF("...", ...): its first argument is always a text to show, whatever it looks like ("%s, en %s"), and so are
    // both texts of a choice there (BG.TF(n == 1 and "%d objeto" or "%d objetos", n))
    for (let i = 0; i + 2 < toks.length; i++) {
      if (toks[i].v !== 'TF' || toks[i + 1].v !== '(' || (toks[i - 1] && toks[i - 1].v !== '.')) continue;
      let depth = 0;
      for (let j = i + 2; j < toks.length; j++) {
        const tk = toks[j];
        if (tk.k === 'sym' && ['(', '{', '['].includes(tk.v)) depth++;
        else if (tk.k === 'sym' && [')', '}', ']'].includes(tk.v)) {
          if (depth === 0) break;
          depth--;
        } else if (depth === 0 && tk.k === 'sym' && tk.v === ',') break;
        else if (depth === 0 && tk.k === 'str' && !['==', '~='].includes(toks[j - 1].v) && /[A-Za-zÁÉÍÓÚÑáéíóúñü¿¡]/.test(tk.v.replace(/%[-\d.]*[sdfi]/g, ''))) add(keys, tk.v, rel, tk.line);
      }
    }
    for (const ch of chains(toks)) {
      if (ch.code || ch.key) continue;
      const tpl = template(ch);
      if (!tpl) continue;
      if (/^%s[%s ,.:]*$/.test(tpl.key)) continue;
      add(keys, tpl.key, rel, tpl.line);
    }
  }
  return keys;
}

function add(keys, key, file, line) {
  if (!keys.has(key)) keys.set(key, new Set());
  keys.get(key).add(`${file}:${line}`);
}

if (process.argv[1] && fileURLToPath(import.meta.url) === process.argv[1]) {
  const keys = extractKeys();
  const list = [...keys.keys()].sort();
  mkdirSync(join(HERE, '..', 'i18n'), { recursive: true });
  writeFileSync(join(HERE, '..', 'i18n', 'keys.json'), JSON.stringify(list, null, 1));
  const words = list.reduce((a, k) => a + k.split(/\s+/).length, 0);
  console.log(`${list.length} textos, unas ${words} palabras -> i18n/keys.json`);
}
