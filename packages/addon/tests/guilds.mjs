// Different guilds (Peregrino, 2026-11-13: "si es un addon que puede usar cualquier jugador de WoW, cada jugador puede
// ser de distintas guilds, y que no haya problemas de ningún tipo con eso"). Any player can whisper our addon, so
// nothing whispered by someone of another guild may get into our records, our chat, our moderation or our tests;
// they get nothing of ours back; and one computer with characters in several guilds keeps each guild's data apart
// (also two different guilds with the same name, one of each faction).
import { createNetwork, createClient, checklist } from './harness.mjs';

const t = checklist('comprobaciones de hermandades distintas');
const P = {
  tarek: { first: 'Tarek', second: 'Vientoalto', guid: 'Player-6842-SIMA', rosterIndex: 1 },
  peregrino: { first: 'El', second: 'Peregrino', guid: 'Player-6842-0A1B2C3D', rosterIndex: 2 },
  bruno: { first: 'Bruno', second: 'Hierrosol', guid: 'Player-6842-BENI', rosterIndex: 3 },
  // the master of another guild, same faction, who has BlazonGuild too
  lobo: { first: 'Lobo', second: 'Feroz', guid: 'Player-7000-LOBO', rosterIndex: 1, guild: 'Los Lobos' },
};
const net = await createNetwork([P.tarek, P.peregrino, P.bruno, P.lobo]);
const [tarek, peregrino, bruno, lobo] = net.clients;
const get = net.get;
await net.loginAll();
for (const c of net.clients) await c.run('BG.Consent.Accept()');
await net.advance(20, 0.5);

// Something of ours to protect, and something of theirs: each guild makes the same kinds of records.
const pollId = await get(bruno, 'local r = assert(BG.Board.Ask("¿Qué banda el sábado?", { "Onyxia", "Núcleo de Magma" }, 30)) return r.id');
await tarek.run('assert(BG.Raids.Save(nil, { inst = "MC", start = time() + 2 * 86400, note = "La nuestra" }))');
await lobo.run(`
  assert(BG.People.Publish({ bio = "Soy de Los Lobos" }))
  assert(BG.Groups.RaiseFlag("DUNGEON", "BRD", "TANK", "tanque libre"))
  assert(BG.Groups.Create("BRD", { TANK = 1, HEALER = 1, DPS = 3 }, "con los lobos", "TANK"))
  assert(BG.Chat.CreateRoom("Lobera", "solo lobos"))
  assert(BG.Raids.Save(nil, { inst = "MC", start = time() + 86400, note = "Raid de los lobos" }))
  assert(BG.Tourney.Create({ kind = "CUP", title = "Copa lobuna", size = 8 }))
  assert(BG.Lotto.Take(42))`);
await net.advance(6);

await t.check('nada de lo que alguien de otra hermandad susurra entra en vuestros registros (ni sobre sí mismo ni un voto en vuestra encuesta)', async () => {
  // Lobo whispers everything of his guild's records to Peregrino and to Tarek, as a catch-up answer would, plus a
  // vote of his in our poll.
  const n = await get(lobo, `
    local list = {}
    for name, b in pairs(BG.Guild.Entry().store) do
      for _, r in pairs(b) do list[#list + 1] = { c = name, r = r } end
    end
    list[#list + 1] = { c = "votes", r = { id = ${JSON.stringify(pollId)} .. "|Lobo Feroz", rev = 1, at = BG.Store.Now(), by = "Lobo Feroz",
      d = { poll = ${JSON.stringify(pollId)}, choice = 2 } } }
    for _, to in ipairs({ "El Peregrino", "Tarek Vientoalto" }) do
      for i = 1, #list, 10 do
        local part = {}
        for j = i, math.min(#list, i + 9) do part[#part + 1] = list[j] end
        BG.Comm.Send("SA", { r = part }, "WHISPER", to)
      end
    end
    __lobo = list
    return #list`);
  await net.advance(30, 0.5);
  const bad = [];
  // the records (by id) that reached our stores
  const ids = await get(lobo, 'local out = {} for _, x in ipairs(__lobo) do out[#out + 1] = x.c .. "/" .. x.r.id end return table.concat(out, ";")');
  for (const c of [peregrino, tarek]) {
    const found = await get(c, `
      local found, open = {}, 0
      for item in (${JSON.stringify(ids)} .. ";"):gmatch("(.-);") do
        local name, id = item:match("^(.-)/(.+)$")
        local r = BG.Store.Get(name, id)
        if r and r.by == "Lobo Feroz" then found[#found + 1] = item end
      end
      return table.concat(found, ", ")`);
    if (found) bad.push(`${c.name} guardó: ${found}`);
  }
  const results = await get(peregrino, `local counts, total = BG.Board.Results(${JSON.stringify(pollId)}) return total`);
  if (results !== 0) bad.push(`la encuesta cuenta ${results} votos (debería ser 0)`);
  return (n >= 8 && bad.length === 0) || `enviados ${n}; ${bad.join(' | ')}`;
});

await t.check('las reglas solas le habrían dejado: por eso cuenta quién lo envía (la prueba ve el agujero)', async () => {
  // The same records handed to the store as if they came from inside the guild: several pass their own rule.
  const passed = await get(peregrino, `
    local open = 0
    BG.Guild.byName["lobo feroz"] = { name = "Lobo Feroz", rankIndex = 4 }
    for _, name in ipairs({ "profiles", "flags", "groups", "rooms", "ltickets", "votes" }) do
      local def = BG.Store.collections[name]
      if def and def.can("Lobo Feroz", { id = name == "profiles" and "Lobo Feroz" or name == "flags" and "Lobo Feroz"
        or name == "ltickets" and "20260101|Lobo Feroz" or name == "votes" and "x|Lobo Feroz" or "LoboFeroz-1", d = { leader = "Lobo Feroz" } }, nil) then
        open = open + 1
      end
    end
    BG.Guild.byName["lobo feroz"] = nil
    return open`);
  return passed >= 4 || `solo ${passed} reglas le dejaban`;
});

await t.check('no recibe nada vuestro: ni vuestros registros, ni el chat de la hermandad, ni la versión al /bg prueba', async () => {
  const before = net.wire.length;
  await lobo.run(`
    BG.Comm.Send("SQ", { s = 0 }, "WHISPER", "El Peregrino")
    BG.Comm.Send("GQ", { s = 0 }, "WHISPER", "El Peregrino")
    BG.Comm.Send("RF", {}, "WHISPER", "El Peregrino")`);
  await net.advance(20, 0.5);
  const back = net.wire.slice(before).filter((f) => f.from === 'El Peregrino' && /Lobo Feroz/.test(String(f.target)));
  const kinds = [];
  for (const f of back) {
    const k = await get(peregrino, `return (${JSON.stringify(f.msg)}):match("^..([%u%d]+):") or (${JSON.stringify(f.msg)}):sub(2, 2)`);
    kinds.push(k);
  }
  const leaked = kinds.filter((k) => k === 'SA' || k === 'GA');
  return leaked.length === 0 || `le respondió: ${kinds.join(', ')}`;
});

await t.check('sus denuncias y su BattleTag no llegan a vuestros moderadores; su respuesta no entra en vuestro /bg prueba', async () => {
  await tarek.run('BG.Diagnostics.lastPing = { answers = {}, done = false }');
  await lobo.run(`
    for i = 1, 3 do BG.Comm.Send("RP", { who = "El Peregrino", t = "insulto falso " .. i, c = "guild", w = "spam" }, "WHISPER", "Tarek Vientoalto") end
    BG.Comm.Send("BT", { t = "Lobo#1234" }, "WHISPER", "Tarek Vientoalto")
    BG.Comm.Send("PO", { v = "9.9.9" }, "WHISPER", "Tarek Vientoalto")`);
  await net.advance(10, 0.5);
  const r = await get(tarek, 'return #BG.Chat.Reports() .. " " .. tostring(BG.Chat.Tags()["Lobo Feroz"]) .. " " .. #BG.Diagnostics.lastPing.answers');
  return r === '0 nil 0' || r;
});

await t.check('invitar a vuestra alianza una y otra vez no llena nada: una invitación por minuto de cada uno', async () => {
  await lobo.run(`
    for i = 1, 6 do
      BG.Comm.Send("AI", { a = "abcdefgh" .. i, t = "tok" .. i .. "abcdefgh", an = "Manada", g = { k = "EU|Los Lobos", n = "Los Lobos", f = "ALLIANCE", m = "Lobo Feroz", c = { "Lobo Feroz" } } }, "WHISPER", "El Peregrino")
    end`);
  await net.advance(10, 0.5);
  const n = await get(peregrino, 'return #BG.Store.List("ainvites")');
  return n <= 1 || `${n} invitaciones guardadas`;
});

await t.check('lo vuestro sigue igual: vuestras raids, vuestra encuesta, y no ven ni su raid ni su sala', async () => {
  const r = await get(peregrino, `
    local raids = {}
    for _, x in ipairs(BG.Store.List("raids")) do raids[#raids + 1] = x.d.note end
    local rooms = 0
    for _, x in ipairs(BG.Store.List("rooms")) do if x.d.name == "Lobera" then rooms = rooms + 1 end end
    return table.concat(raids, ",") .. " | " .. rooms`);
  return r === 'La nuestra | 0' || r;
});

net.close();

// One computer, characters in different guilds ------------------------------------------------------------------
await t.check('un ordenador con personajes en dos hermandades del mismo nombre (una de cada facción): cada una con lo suyo', async () => {
  const c = await createClient({ identity: P.peregrino });
  await c.login();
  await c.run('BG.Consent.Accept() assert(BG.People.Publish({ bio = "Soy de la Alianza" }))');
  const homes = [];
  await c.run(`__a = BG.Guild.info.home`);
  homes.push(c.lua.global.get('__a'));
  // the same account, now a Horde character in a different guild that is also called "C A Ñ A D A"
  await c.run(`
    SIM.faction = "Horde"
    SIM.me.guid = "Player-6842-HORDA"
    SIM.roster[2][17] = "Player-6842-HORDA"
    BG.Guild.Scan()
    __b = BG.Guild.info.home
    __mine = BG.People.Profile("El Peregrino")`);
  homes.push(c.lua.global.get('__b'));
  const seen = await c.lua.doString('return __mine and __mine.d.bio or "nada"');
  const entries = await c.lua.doString('local n = 0 for _ in pairs(BG.db.guilds) do n = n + 1 end return n');
  c.close();
  return (homes[0] !== homes[1] && seen === 'nada' && entries === 2) || `${homes.join(' / ')}; la hordana ve: ${seen}; ${entries} hermandades guardadas`;
});

await t.check('los datos de antes (guardados por nombre) pasan a su hermandad, y nunca a la de la otra facción', async () => {
  const c = await createClient({ identity: P.peregrino });
  await c.run(`
    BlazonGuildDB = { guilds = {
      ["EU|C A Ñ A D A"] = { info = { name = "C A Ñ A D A", faction = "ALLIANCE" }, store = { profiles = { ["Bruno Hierrosol"] = { id = "Bruno Hierrosol", rev = 1, at = 1, by = "Bruno Hierrosol", d = { bio = "de antes", chars = {} } } } } },
    } }`);
  await c.login();
  const allianceSees = await c.lua.doString('local r = BG.Store.Get("profiles", "Bruno Hierrosol") return r and r.d.bio or "nada"');
  const c2 = await createClient({ identity: P.peregrino });
  await c2.run(`
    SIM.faction = "Horde"
    BlazonGuildDB = { guilds = {
      ["EU|C A Ñ A D A"] = { info = { name = "C A Ñ A D A", faction = "ALLIANCE" }, store = { profiles = { ["Bruno Hierrosol"] = { id = "Bruno Hierrosol", rev = 1, at = 1, by = "Bruno Hierrosol", d = { bio = "de antes", chars = {} } } } } },
    } }`);
  await c2.login();
  const hordeSees = await c2.lua.doString('local r = BG.Store.Get("profiles", "Bruno Hierrosol") return r and r.d.bio or "nada"');
  c.close();
  c2.close();
  return (allianceSees === 'de antes' && hordeSees === 'nada') || `alianza: ${allianceSees}; horda: ${hordeSees}`;
});

await t.check('las denuncias y BattleTags que guarda un organizador son de su hermandad: su alt en otra no las ve', async () => {
  const c = await createClient({ identity: P.tarek });
  await c.login();
  await c.run(`BG.Consent.Accept()
    table.insert(BG.Chat.Reports(), { at = 1, by = "Bruno Hierrosol", who = "X", text = "algo" })
    BG.Chat.Tags()["Bruno Hierrosol"] = "Beni#1"
    SIM.guildName = "Los Lobos"
    BG.Guild.Scan()
    __out = #BG.Chat.Reports() .. " " .. tostring(BG.Chat.Tags()["Bruno Hierrosol"])`);
  const r = c.lua.global.get('__out');
  c.close();
  return r === '0 nil' || r;
});

t.report();
