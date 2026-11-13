// Shared loader for the offline tests: one simulated game client per call, each running the addon's real Lua
// (tests/wow-stubs.lua is the client). A network test creates several and routes their addon messages
// like the game server does: GUILD to every member (the sender included, as the real echo), WHISPER to the
// named player only. Every frame is checked against the game's limits (255 bytes, no NUL byte).
import fs from 'node:fs';
import path from 'node:path';
import { LuaFactory } from 'wasmoon';

export const here = path.dirname(new URL(import.meta.url).pathname.replace(/^\/(\w:)/, '$1'));
export const root = path.join(here, '..', 'BlazonGuild');
export const tocFiles = fs
  .readFileSync(path.join(root, 'BlazonGuild.toc'), 'utf8')
  .split(/\r?\n/)
  .filter((l) => l.trim() && !l.startsWith('#'))
  .map((l) => l.trim().replace(/\\/g, '/'));

// The addon's own version, from its .toc (clients run it unless a test asks for another).
export const addonVersion = fs.readFileSync(path.join(root, 'BlazonGuild.toc'), 'utf8').match(/## Version: (\S+)/)[1];

const factory = new LuaFactory();

export const DEFAULT_GUILD = 'C A Ñ A D A';
const guildOf = (p) => (p?.noGuild ? '' : p?.guild ?? DEFAULT_GUILD); // ('' = no guild)

// identity: { first, second, guid, rosterIndex, guild?, faction? } — rosterIndex is the fixture row this client
// plays; guild (default C A Ñ A D A) and faction ("Alliance" or "Horde") let a test run several guilds.
export async function createClient({ identity, version = addonVersion, seed = 1, onSend } = {}) {
  const lua = await factory.createEngine();
  lua.global.set('__read', (f) => fs.readFileSync(path.join(root, f), 'utf8'));
  if (onSend) lua.global.set('__send', (prefix, msg, dist, target) => onSend({ prefix, msg, dist, target }));
  await lua.doString(fs.readFileSync(path.join(here, 'wow-stubs.lua'), 'utf8'));
  await lua.doString(`math.randomseed(${seed})`);
  if (identity && guildOf(identity) !== DEFAULT_GUILD) {
    // Another guild: its own name, and fixture members that are not C A Ñ A D A's.
    const tag = guildOf(identity).split(' ').pop();
    await lua.doString(`
      SIM.guildName = ${JSON.stringify(guildOf(identity))}
      for i, r in ipairs(SIM.roster) do r[1] = ${JSON.stringify(tag)} .. " Prueba " .. i r[17] = "Player-7000-" .. ${JSON.stringify(tag)} .. i end
    `);
  }
  if (identity?.faction) await lua.doString(`SIM.faction = ${JSON.stringify(identity.faction)}`);
  if (identity?.noGuild) await lua.doString('SIM.inGuild = false');
  if (identity) {
    await lua.doString(`
      SIM.me = { first = ${JSON.stringify(identity.first)}, second = ${JSON.stringify(identity.second)}, guid = ${JSON.stringify(identity.guid)} }
      local row = SIM.roster[${identity.rosterIndex}]
      row[1] = ${JSON.stringify(`${identity.first} ${identity.second}`)}
      row[9] = true
      row[17] = ${JSON.stringify(identity.guid)}
    `);
  }
  await lua.doString(`SIM.version = ${JSON.stringify(version)}`);
  await lua.doString(`
    BG = {}
    for _, f in ipairs({${tocFiles.map((f) => JSON.stringify(f)).join(',')}}) do
      local chunk, err = load(__read(f), "@" .. f)
      if not chunk then error(err) end
      chunk("BlazonGuild", BG)
    end
  `);
  const client = {
    lua,
    name: identity ? `${identity.first} ${identity.second}` : 'El Peregrino',
    run: (code) => lua.doString(code),
    async login() {
      await lua.doString(`
        SIM.fire("ADDON_LOADED", "BlazonGuild")
        SIM.fire("PLAYER_LOGIN")
        SIM.fire("GUILD_ROSTER_UPDATE")
        SIM.advance(1)
      `);
    },
    // Called by the network router between steps (never from inside a send), like the server would.
    deliver(prefix, msg, dist, sender) {
      lua.global.set('__in', { prefix, msg, dist, sender });
      lua.doStringSync('SIM.fire("CHAT_MSG_ADDON", __in.prefix, __in.msg, __in.dist, __in.sender)');
    },
    // Chat channels (0.22.0): is this player in channel `name`, and a line someone says there.
    inChannel(name) {
      lua.global.set('__ch', name);
      lua.doStringSync('__chIn = SIM.joined[__ch] ~= nil');
      return lua.global.get('__chIn') === true;
    },
    channelLine(msg, sender, name) {
      lua.global.set('__cl', { msg, sender, name });
      lua.doStringSync('local j = SIM.joined[__cl.name] SIM.fire("CHAT_MSG_CHANNEL", __cl.msg, __cl.sender, "", j.i .. ". " .. __cl.name, __cl.sender, "", 0, j.i, __cl.name)');
    },
    // A line from the server in the system chat ("No player named X is currently playing").
    system(text) {
      lua.global.set('__sys', text);
      lua.doStringSync('SIM.system(__sys)');
    },
    close: () => lua.global.close(),
  };
  return client;
}

// Guilds of simulated clients behind a simulated server. people: [{ first, second, guid, rosterIndex, version,
// guild? }]. Every client sees the played members of its guild online. advance(seconds) moves all clocks in
// lockstep and delivers frames between steps: GUILD to everyone in the sender's guild (sender's echo included),
// OFFICER to its ranks 0-1, PARTY/RAID/INSTANCE_CHAT to the clients in net.group, WHISPER to the named player in any guild; a whisper to someone not playing brings
// the sender the server's "No player named..." line. Rina's frames arrive stamped "-ForeverPvP2" (another
// sub-realm), like the real server does. logout(client) takes a player out of the game.
export async function createNetwork(people, { startIndex = 0 } = {}) {
  const net = { clients: [], wire: [], violations: [], inbox: [], step: 0 };
  net.add = async (p, i = net.clients.length) => {
    const client = await createClient({
      identity: p,
      version: p.version ?? addonVersion,
      seed: 11 + i + startIndex,
      onSend: (m) => {
        const bytes = Buffer.byteLength(m.msg, 'utf8');
        if (bytes > 255) net.violations.push(`${p.first}: trama de ${bytes} bytes`);
        if (m.msg.includes('\0')) net.violations.push(`${p.first}: byte NUL`);
        if (m.prefix !== 'BlazonGuild' && m.dist !== 'CHANNEL') net.violations.push(`${p.first}: prefijo ${m.prefix}`);
        const frame = { from: `${p.first} ${p.second}`, ...m, step: net.step };
        net.wire.push(frame);
        net.inbox.push(frame);
      },
    });
    client.person = p;
    client.rank = null;
    const mates = guildOf(p) === '' ? [] : [...net.clients, client].filter((c) => guildOf(c.person) === guildOf(p));
    const all = mates.map((c) => c.person);
    for (const c of mates) {
      await c.run(all.map((q) => `SIM.roster[${q.rosterIndex}][1] = ${JSON.stringify(`${q.first} ${q.second}`)} SIM.roster[${q.rosterIndex}][9] = true SIM.roster[${q.rosterIndex}][17] = ${JSON.stringify(q.guid)}`).join('\n'));
    }
    client.rank = await client.lua.doString(`return SIM.roster[${p.rosterIndex}][3]`);
    // The game sends a roster update to everyone when a member logs in; clients already running rescan.
    for (const c of net.clients) if (guildOf(p) !== '' && guildOf(c.person) === guildOf(p)) await c.run('if BG.Guild.info then BG.Guild.Scan() end');
    net.clients.push(client);
    return client;
  };
  for (const p of people) await net.add(p);
  net.loginAll = async () => {
    for (const c of net.clients) await c.login();
  };
  const online = () => net.clients.filter((c) => !c.offline);
  net.logout = async (client) => {
    client.offline = true;
    for (const c of online()) {
      if (guildOf(c.person) === guildOf(client.person)) await c.run(`SIM.roster[${client.person.rosterIndex}][9] = false BG.Guild.Scan()`);
    }
  };
  net.advance = async (seconds, dt = 0.25) => {
    for (let s = 0; s < seconds; s += dt) {
      net.step++;
      for (const c of online()) await c.run(`SIM.advance(${dt})`);
      const batch = net.inbox;
      net.inbox = [];
      for (const f of batch) {
        const from = net.clients.find((c) => c.name === f.from);
        if (!from || from.offline) continue;
        const sender = f.from === 'Rina Dagaluna' ? 'Rina Dagaluna-ForeverPvP2' : f.from;
        const guild = guildOf(from.person);
        if (f.dist === 'GUILD') {
          for (const c of online()) if (guild !== '' && guildOf(c.person) === guild) c.deliver(f.prefix, f.msg, 'GUILD', sender);
        } else if (f.dist === 'OFFICER') {
          for (const c of online()) if (guildOf(c.person) === guild && c.rank <= 1) c.deliver(f.prefix, f.msg, 'OFFICER', sender);
        } else if (f.dist === 'PARTY' || f.dist === 'RAID' || f.dist === 'INSTANCE_CHAT') {
          // a group the test makes (net.group: clients of any guild), the sender's echo included
          if ((net.group || []).includes(from)) for (const c of online()) if (net.group.includes(c)) c.deliver(f.prefix, f.msg, f.dist, sender);
        } else if (f.dist === 'CHANNEL') {
          // a player's own line in a chat channel: everyone in it hears it (their own echo too), in any guild
          for (const c of online()) if (c.inChannel(f.target)) c.channelLine(f.msg, sender, f.target);
        } else if (f.dist === 'WHISPER') {
          // (a whisper may name the sub-realm too, "Rina Dagaluna-ForeverPvP2", as the game needs across sub-realms)
          const to = online().find((c) => c.name === f.target || c.name === String(f.target).replace(/-[^ ]+$/, ''));
          if (to) to.deliver(f.prefix, f.msg, 'WHISPER', sender);
          else from.system(`No player named '${f.target}' is currently playing.`);
        }
      }
    }
  };
  net.get = async (c, expr) => {
    await c.run(`__out = (function() ${expr} end)()`);
    return c.lua.global.get('__out');
  };
  net.close = () => net.clients.forEach((c) => c.close());
  return net;
}

// Collects named checks; prints them and sets the exit code like the other test files.
export function checklist(title) {
  const results = [];
  return {
    async check(name, fn) {
      try {
        const out = await fn();
        results.push([out === true, name, out === true ? '' : String(out)]);
      } catch (e) {
        results.push([false, name, String(e?.message ?? e).split('\n')[0]]);
      }
    },
    report() {
      let failed = 0;
      for (const [ok, name, detail] of results) {
        console.log(`${ok ? '✓' : '✗'} ${name}${ok ? '' : `: ${detail}`}`);
        if (!ok) failed++;
      }
      console.log(`${results.length - failed}/${results.length} ${title}`);
      if (failed) process.exitCode = 1;
    },
  };
}
