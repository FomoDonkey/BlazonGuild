import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { createApp } from '../src/app';
import { createDeps } from '../src/deps';
import { loadEnv } from '../src/env';
import { silentLogger } from '../src/lib/logger';

const here = path.dirname(fileURLToPath(import.meta.url));

/** Real Battle.net payloads captured on 2026-11-12 (guild "forever", GM "goa-smashie"). Test-only. */
export function loadFixtures() {
  const dir = path.join(here, 'fixtures');
  const out: Record<string, any> = {};
  for (const f of fs.readdirSync(dir)) out[f.replace(/\.json$/, '')] = JSON.parse(fs.readFileSync(path.join(dir, f), 'utf8'));
  return out;
}

const json = (body: unknown, status = 200) => new Response(JSON.stringify(body), { status, headers: { 'content-type': 'application/json' } });

export interface FakeBlizzard {
  fixtures: Record<string, any>;
  roster: any;
  gmEquipment: any;
  calls: string[];
}

export function fakeBlizzardFetch(state: FakeBlizzard): typeof fetch {
  return (async (input: string | URL | Request) => {
    const url = new URL(String(input instanceof Request ? input.url : input));
    state.calls.push(url.pathname);
    if (url.pathname === '/token') return json({ access_token: 'test-token', token_type: 'bearer', expires_in: 86399 });
    const p = decodeURIComponent(url.pathname);
    const f = state.fixtures;
    if (p === '/data/wow/guild/forever') return json(f.guild);
    if (p === '/data/wow/guild/forever/roster') return json(state.roster);
    const gm = p.match(/^\/profile\/wow\/character\/goa-smashie(\/.*)?$/);
    if (gm) {
      const sub = gm[1] ?? '';
      const map: Record<string, any> = {
        '': f.gm, '/equipment': state.gmEquipment, '/statistics': f['gm-stats'], '/specializations': f['gm-specs'],
        '/character-media': f['gm-media'], '/pvp-summary': f['gm-pvp'], '/professions': f['gm-professions'], '/achievements': f['gm-achievements'],
      };
      return map[sub] ? json(map[sub]) : json({ code: 404 }, 404);
    }
    const other = p.match(/^\/profile\/wow\/character\/([^/]+)$/);
    if (other) {
      const member = state.roster.members.find((m: any) => m.character.slug === other[1]);
      if (!member) return json({ code: 404 }, 404);
      const ch = member.character;
      return json({
        id: ch.id, name: ch.name, surname: ch.surname, level: ch.level, character_class: { id: ch.playable_class.id }, race: { id: ch.playable_race.id },
        faction: { type: 'HORDE' }, guild: { id: 94195, name: 'Forever', slug: 'forever' }, last_login_timestamp: Date.now() - 2 * 86_400_000,
        equipped_item_level: 10 + (ch.level % 7),
      });
    }
    const tt = p.match(/^\/data\/wow\/talent-tree\/(\d+)\/playable-specialization\/(\d+)$/);
    if (tt && f[`tt-${tt[1]}-${tt[2]}`]) return json(f[`tt-${tt[1]}-${tt[2]}`]);
    if (p.startsWith('/data/wow/media/guild-crest/')) return json({ assets: [{ key: 'image', value: 'https://render.worldofwarcraft.com/forever-eu/guild/tabards/emblem_98.png' }] });
    if (p.startsWith('/data/wow/media/')) return json({ assets: [{ key: 'icon', value: 'https://render.worldofwarcraft.com/forever-eu/icons/56/133046.jpg', file_data_id: 133046 }] });
    return json({ code: 404, detail: 'Not Found' }, 404);
  }) as typeof fetch;
}

export async function createHarness() {
  const fixtures = loadFixtures();
  const state: FakeBlizzard = { fixtures, roster: structuredClone(fixtures['guild-roster']), gmEquipment: structuredClone(fixtures['gm-equipment']), calls: [] };
  const env = loadEnv({
    NODE_ENV: 'test',
    BLIZZARD_CLIENT_ID: 'test',
    BLIZZARD_CLIENT_SECRET: 'test',
    DATABASE_URL: 'pglite:memory',
    WEB_ORIGIN: 'http://localhost:3000',
    MEDIA_CACHE_DIR: fs.mkdtempSync(path.join(os.tmpdir(), 'forever-media-')),
    DISABLE_SCHEDULER: 'true',
    TRUST_PROXY: 'true',
  });
  const { deps, close } = await createDeps(env, { log: silentLogger, fetchImpl: fakeBlizzardFetch(state) });
  const app = createApp(deps, { remoteAddress: () => '127.0.0.1' });

  let ipCounter = 1;
  const client = (ip = `10.0.0.${ipCounter++}`) => {
    let cookie = '';
    const req = async (method: string, path: string, body?: unknown, headers: Record<string, string> = {}) => {
      const res = await app.request(path, {
        method,
        headers: { 'x-forwarded-for': ip, ...(body !== undefined ? { 'content-type': 'application/json' } : {}), ...(cookie ? { cookie } : {}), ...headers },
        body: body === undefined ? undefined : typeof body === 'string' ? body : JSON.stringify(body),
      });
      const set = res.headers.getSetCookie?.() ?? [];
      for (const c of set) {
        const [pair] = c.split(';');
        if (pair.startsWith('forever_session=')) cookie = pair.endsWith('=') ? '' : pair;
      }
      const text = await res.text();
      let data: any = null;
      try {
        data = text ? JSON.parse(text) : null;
      } catch {
        data = text;
      }
      return { status: res.status, data, headers: res.headers };
    };
    return { req, get cookie() { return cookie; } };
  };

  return { app, deps, state, client, close };
}

export type Harness = Awaited<ReturnType<typeof createHarness>>;
