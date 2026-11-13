// What the full audit found (Peregrino, 2026-11-13: «una auditoría completa… sin asumir nada»), so it never comes back.
// Most of it is the same lesson: the simulator wrote every name as "First Surname", and on Forever the game's own
// functions and events can give "El" (UnitName) or "El-Peregrino" (the surname where a realm would go; Olympus
// measured it and normalises those names, MIT). Here the game's lines and units say it that way.
import { createNetwork, checklist } from './harness.mjs';

const P = {
  tarek: { first: 'Tarek', second: 'Vientoalto', guid: 'Player-6842-SIMA', rosterIndex: 1 }, // Maestro
  peregrino: { first: 'El', second: 'Peregrino', guid: 'Player-6842-0A1B2C3D', rosterIndex: 2 }, // Miembro
  bruno: { first: 'Bruno', second: 'Hierrosol', guid: 'Player-6842-SIMD', rosterIndex: 3 }, // Oficial
};
const net = await createNetwork(Object.values(P));
const [tarek, peregrino, bruno] = net.clients;
await net.loginAll();
for (const c of net.clients) await c.run('BG.Consent.Accept()');
await net.advance(20, 0.5);
const get = net.get;
const t = checklist('comprobaciones de la auditoría');

await t.check('nombres: «El-Peregrino» (como lo dan funciones y eventos del juego) es «El Peregrino»', async () => {
  const r = await get(peregrino, `local S = BG.Names.Short local out = {}
    for _, n in ipairs({ "El-Peregrino", "El Peregrino-ForeverPvP2", "El-Peregrino-ForeverPvP2", "El Peregrino", "Pepe-ForeverPvP" }) do out[#out + 1] = tostring(S(n)) end
    return table.concat(out, "|") .. "|" .. tostring(BG.Names.Same("El-Peregrino", "El Peregrino"))`);
  return r === 'El Peregrino|El Peregrino|El Peregrino|El Peregrino|Pepe|true' || r;
});

await t.check('Arena: la línea del duelo con los nombres «Nombre-Apellido» se apunta', async () => {
  for (const c of net.clients) await c.run('SIM.fire("CHAT_MSG_SYSTEM", "Tarek-Vientoalto has defeated El-Peregrino in a duel")');
  await net.advance(6);
  const r = await get(tarek, 'local d = BG.Store.List("duels")[1] return d and (d.d.w .. ">" .. d.d.l) or "ninguno"');
  return r === 'Tarek Vientoalto>El Peregrino' || r;
});

await t.check('Huesos: la tirada del juego con «El-Peregrino rolls…» cuenta como la tuya', async () => {
  const r = await get(peregrino, `
    local real = RandomRoll
    RandomRoll = function(lo, hi) C_Timer.After(0.3, function() SIM.fire("CHAT_MSG_SYSTEM", "El-Peregrino rolls " .. hi .. " (" .. lo .. "-" .. hi .. ")") end) end
    BG.Bones.Practice() local before = BG.Bones.game.phase
    assert(BG.Bones.Roll()) SIM.advance(2)
    RandomRoll = real
    return before .. ">" .. tostring(BG.Bones.game and BG.Bones.game.phase)`);
  return (r.startsWith('roll>') && !r.endsWith('>roll')) || `fase: ${r}`;
});

await t.check('lotería: el sorteo con «Bruno-Hierrosol rolls…» lo lee', async () => {
  const r = await get(bruno, `
    local real = RandomRoll
    RandomRoll = function(lo, hi) C_Timer.After(0.3, function() SIM.fire("CHAT_MSG_SYSTEM", "Bruno-Hierrosol rolls 42 (1-100)") end) end
    local ok, why = BG.Lotto.Draw() SIM.advance(2)
    RandomRoll = real
    return tostring(ok) .. "|" .. tostring(why) .. "|" .. tostring(BG.Lotto.Drawn(BG.Lotto.Today()))`);
  return /^true\|nil\|/.test(r) && !r.endsWith('|nil') && !r.endsWith('|false') || r;
});

await t.check('jefes: con la lista de banda del juego dando solo el nombre («El»), el jefe se apunta igual', async () => {
  const raid = `SIM.setRaid({ { "Tarek", "Vientoalto", 1 }, { "El", "Peregrino", 1 }, { "Bruno", "Hierrosol", 1 }, { "Miembro", "Prueba 4", 2 }, { "Miembro", "Prueba 5", 2 } })
    SIM.group.inRaid = true SIM.instance = { name = "Núcleo de Magma", kind = "raid", mapId = 409 }
    GetRaidRosterInfo = function(i) local r = SIM.raid[i] if not r then return nil end return r[1], 0, r[3] end`;
  for (const c of net.clients) await c.run(`${raid} SIM.fire("ENCOUNTER_END", 663, "Lucifron", 9, 40, 1)`);
  await net.advance(6);
  const r = await get(peregrino, 'local ours, n = BG.PvE.OursInGroup() return ours .. "/" .. n .. "|" .. #BG.Store.List("kills")');
  for (const c of net.clients) await c.run('SIM.group.inRaid = false SIM.setRaid({}) SIM.instance = nil');
  return r === '5/5|1' || `de los nuestros|jefes: ${r}`;
});

await t.check('tesorería: el oro de una carta de «Tarek-Vientoalto» se apunta a Tarek Vientoalto', async () => {
  await tarek.run('assert(BG.Treasury.Configure({ keepers = "Bruno Hierrosol" }))');
  await net.advance(4);
  const r = await get(bruno, `
    SIM.inbox = { { sender = "Tarek-Vientoalto", subject = "Para la raid", money = 70000, cod = 0, canReply = true } }
    SIM.fire("MAIL_INBOX_UPDATE") TakeInboxMoney(1) SIM.advance(1)
    for _, r in ipairs(BG.Store.List("ledger")) do if r.d.via == "MAIL" then return r.d.who .. ":" .. r.d.c end end
    return "nada"`);
  return r === 'Tarek Vientoalto:70000' || r;
});

await t.check('tesorería: cantidades con las letras inglesas y alemanas («2g 50s», «5k»)', async () => {
  const r = await get(peregrino, 'local P = BG.Treasury.ParseMoney return P("2g 50s") .. "|" .. P("12o 30p") .. "|" .. P("5k") .. "|" .. P("12,5") .. "|" .. tostring(P("abc"))');
  return r === '25000|123000|5|125000|nil' || r;
});

await t.check('tesorería: las cuotas de toda la hermandad salen igual que contando a cada uno (una sola pasada)', async () => {
  await bruno.run('assert(BG.Treasury.Record("IN", 30000, "El Peregrino", "HAND")) assert(BG.Treasury.Record("IN", 20000, "Tarek Vientoalto", "HAND"))');
  await net.advance(4);
  const r = await get(peregrino, `local bad = {}
    for _, d in ipairs(BG.Treasury.Dues()) do
      if d.given ~= BG.Treasury.GivenIn(d.name) then bad[#bad + 1] = d.name end
      for i = 1, 4 do if d.weeks[i] ~= BG.Treasury.GivenIn(d.name, BG.Treasury.WeekStart() - i * 7 * 86400) then bad[#bad + 1] = d.name .. "@" .. i end end
    end
    return #bad == 0 and ("ok " .. BG.Treasury.GivenIn("El Peregrino")) or table.concat(bad, ",")`);
  return r === 'ok 30000' || r;
});

await t.check('mensajes: lo que llega roto de otro addon no deja errores internos (grupos, «¡A las armas!»)', async () => {
  const r = await get(peregrino, `BG.db.errors = {}
    local def = BG.Store.collections.groups
    local ok1 = pcall(def.normalize, { key = "BRD", need = 5, leader = "Tarek Vientoalto", members = {} })
    local ok2 = pcall(BG.Board.ShowDecree, "Tarek Vientoalto", { k = "ARMS", t = { "x" }, al = 7 })
    local ok3 = pcall(BG.Board.ShowDecree, "Tarek Vientoalto", { k = "RALLY", t = "|cffff0000rojo|r |Hitem:1|h[x]|h" })
    local shown = BG.lastNotice and BG.lastNotice.text or ""
    return tostring(ok1) .. tostring(ok2) .. tostring(ok3) .. "|" .. #BG.db.errors .. "|" .. tostring(shown:find("|", 1, true) == nil)`);
  return r === 'truetruetrue|0|true' || r;
});

await t.check('mensajes: justo al entrar, si el juego aún no da el nombre de la hermandad, lo puesto en cola sale igual', async () => {
  const r = await get(peregrino, `
    local real = GetGuildInfo
    local before = BG.Comm.stats.sent
    BG.Comm.Send("HI", { v = "0.0.0" }, "GUILD") -- (queued with the guild's name...)
    GetGuildInfo = function() return nil end -- (...which the game does not give for a moment)
    SIM.advance(3)
    GetGuildInfo = real
    return tostring(BG.Comm.stats.sent > before)`);
  return r === 'true' || r;
});

await t.check('aviso de versión nueva: dice CurseForge y no una web que no existe', async () => {
  await peregrino.run('SIM.log = {}');
  for (const c of [tarek]) await c.run('BG.Comm.Send("HI", { v = "9.9.9", p = 1 }, "GUILD")');
  await net.advance(4);
  const r = await get(peregrino, 'return table.concat(SIM.log, " ")');
  return (r.includes('CurseForge') && !r.includes('web')) || r;
});

await t.check('privacidad: la página dice también lo que el juego cuenta solo (duelos, muertes, oro, jefes)', async () => {
  const r = await get(peregrino, `for i = 1, 5 do if BlazonGuildDialog and BlazonGuildDialog:IsShown() then BlazonGuildDialog:Hide() SIM.advance(0.5) end end
    BG.Consent.Open() SIM.advance(0.5)
    local f = BlazonGuildDialog local out = {}
    for _, o in ipairs(SIM.objects) do local p = o while p do if p == f then break end p = p.__parent end
      if p and o.GetText and o:IsVisible() then local tx = o:GetText() if type(tx) == "string" then out[#out + 1] = tx end end end
    f:Hide()
    local text = table.concat(out, " ")
    return tostring(text:find("duelos", 1, true) ~= nil and text:find("tesorero", 1, true) ~= nil and text:find("tu equipo", 1, true) ~= nil)`);
  return r === 'true' || r;
});

// Forever's places (Peregrino: «¿salen las mazmorras de WoW Forever o de otras versiones?»): its 28 dungeons (19 of the
// classic era and 9 new) and its three raids; Molten Core and the other classic raids are not in Forever.
await t.check('Forever: las 28 mazmorras (las 9 nuevas incluidas) y solo sus tres bandas para elegir', async () => {
  const r = await get(peregrino, `local I = BG.Instances local news, raids = {}, {}
    for _, d in ipairs(I.dungeons) do if d.new then news[#news + 1] = d.key end end
    for _, x in ipairs(I.RaidOptions()) do raids[#raids + 1] = x.key end
    local old = {} for _, x in ipairs(I.RaidOptions("MC")) do old[#old + 1] = x.key end
    return #I.dungeons .. "|" .. table.concat(news, ",") .. "|" .. table.concat(raids, ",") .. "|" .. table.concat(old, ",")`);
  return r === '29|THANES,RUINS,EXCAV,DALA,DROWN,KROL,ALCAZ,BLACKM,SHAPER|BARROW,HYJAL,ONY,DUNGEON,OTHER|BARROW,HYJAL,ONY,DUNGEON,OTHER,MC' || r;
});

await t.check('Forever: cada facción ve las mazmorras a las que puede entrar (solo las de dentro de una capital son de un bando)', async () => {
  const r = await get(peregrino, `local I = BG.Instances local function keys(level, fac) local o = {} for _, d in ipairs(I.DungeonsFor(level, fac)) do o[#o + 1] = d.key end return table.concat(o, ",") end
    return keys(15, "ALLIANCE") .. "|" .. keys(15, "HORDE") .. "|" .. keys(24, "HORDE")`);
  const [a15, h15, h24] = r.split('|');
  const ok = a15.includes('THANES') && !a15.includes('RUINS') && !a15.includes('RFC') && h15.includes('RUINS') && h15.includes('RFC') && !h15.includes('THANES')
    && h24.includes('DM') && h24.includes('SFK') && !h24.includes('STOCKS');
  return ok || r;
});

await t.check('JcE: reconoce las bandas de Forever por su nombre (español o inglés) y, si el juego da otro, por su tamaño', async () => {
  const r = await get(peregrino, `local out = {}
    for _, i in ipairs({ { "Cima Hyjal", 20 }, { "Hyjal Summit", 20 }, { "The Barrow Deeps", 10 }, { "Gipfel des Hyjal", 20 }, { "Hügelgrabtiefen", 10 }, { "Guarida de Onyxia", 40 } }) do
      SIM.instance = { name = i[1], kind = "raid", mapId = 99999, size = i[2] } out[#out + 1] = tostring(BG.PvE.RaidHere())
    end
    SIM.instance = nil
    return table.concat(out, ",")`);
  return r === 'HYJAL,HYJAL,BARROW,HYJAL,BARROW,ONY' || r;
});

await t.check('JcE y Raids: la pantalla enseña las tres bandas de Forever, y una raid antigua de Núcleo de Magma se sigue leyendo', async () => {
  await peregrino.run(`SIM.roster[2][4] = 60 BG.Guild.Scan() SIM.advance(1)
    assert(BG.Raids.Save(nil, { inst = "MC", start = time() + 86400 })) SIM.advance(1)`);
  const r = await get(peregrino, `if not (BG.window and BG.window:IsShown()) then BG:ToggleWindow() end
    BG:ShowView("pve") SIM.layout(834, 604)
    local names = {} for _, x in ipairs(BG.PvE.Raids()) do names[#names + 1] = x.name end
    BG:ShowView("raids") SIM.layout(834, 604)
    local f = BG.window.viewFrames.raids
    local list = {} for _, r in ipairs(BG.Raids.Upcoming()) do list[#list + 1] = r.d.title end
    return table.concat(names, ",") .. "|" .. table.concat(list, ",") .. "|" .. table.concat(SIM.CheckLayout(f), ";")`);
  return r === 'Cavernas del Túmulo,Cima Hyjal,Guarida de Onyxia|Núcleo de Magma|' || r;
});

// Performance (Peregrino: «que consuma lo menos posible sin afectar en absoluto al producto»): the same results, less work.
await t.check('rendimiento: la lista de la hermandad sin cambios no rehace nada ni avisa; con un cambio, sí (y los miembros son los mismos)', async () => {
  const r = await get(peregrino, `
    local fired = 0
    BG:On("BG_ROSTER_UPDATED", function() fired = fired + 1 end)
    local before = BG.Guild.byGuid["Player-6842-SIM5"]
    BG.Guild.Scan() local quiet = fired
    SIM.roster[5][4] = (SIM.roster[5][4] or 1) + 1 BG.Guild.Scan() local one = fired
    local after = BG.Guild.byGuid["Player-6842-SIM5"]
    SIM.roster[37] = { "Recien Llegado", "Miembro", 4, 10, "Mago", "Ventormenta", "", "", true, 0, "MAGE", 0, 1, false, false, 3, "Player-6842-NUEVO" }
    BG.Guild.Scan() local joined = fired .. ":" .. tostring(BG.Guild.Find("Recien Llegado") ~= nil)
    SIM.roster[37] = nil BG.Guild.Scan() local left = fired .. ":" .. tostring(BG.Guild.Find("Recien Llegado") == nil)
    return quiet .. "|" .. one .. "|" .. tostring(before == after and after.level == SIM.roster[5][4]) .. "|" .. joined .. "|" .. left`);
  return r === '0|1|true|2:true|3:true' || `avisos sin cambio|con cambio|mismo miembro|entra|sale: ${r}`;
});

await t.check('rendimiento: la crónica, comparando sin copiar a todos, dice lo mismo que antes (altas, bajas, ascensos, nivel máximo)', async () => {
  const r = await get(peregrino, `
    local function list(t) local o = {} for _, e in ipairs(t) do o[#o + 1] = e.kind .. ":" .. tostring(e.who) end table.sort(o) return table.concat(o, ",") end
    local before = { { guid = "a", name = "Ana Uno", rankIndex = 4, rank = "Miembro", level = 59 }, { guid = "b", name = "Beto Dos", rankIndex = 2, rank = "Veterano", level = 60 },
      { guid = "c", name = "Ceci Tres", rankIndex = 4, rank = "Miembro", level = 40 } }
    local after = { { guid = "a", name = "Ana Uno", rankIndex = 1, rank = "Oficial", level = 60 }, { guid = "b", name = "Beto Dos", rankIndex = 4, rank = "Miembro", level = 60 },
      { guid = "d", name = "Dani Cuatro", rankIndex = 4, rank = "Miembro", level = 10 } }
    local known = {}
    BG.Board.DiffInPlace(known, before, 60)
    local inPlace = list(BG.Board.DiffInPlace(known, after, 60))
    local again = #BG.Board.DiffInPlace(known, after, 60)
    return tostring(inPlace == list(BG.Board.Diff(before, after, 60))) .. "|" .. again .. "|" .. inPlace`);
  return r.startsWith('true|0|') || r;
});

await t.check('rendimiento: al entrar al mundo solo queda en memoria el idioma elegido, y todo sigue en ese idioma', async () => {
  const c = net.clients[0];
  const r = await get(c, `BG.db.settings.lang = "en" BG.Locale.Init()
    SIM.fire("PLAYER_ENTERING_WORLD")
    local langs = {} for k in pairs(BG.Locales) do langs[#langs + 1] = k end table.sort(langs)
    local demo = {} for k in pairs(BG.DemoData or {}) do demo[#demo + 1] = k end table.sort(demo)
    return table.concat(langs, ",") .. "|" .. table.concat(demo, ",") .. "|" .. BG.T("Miembros") .. "|" .. tostring(BG.Demo.Available())`);
  return r === 'en|en|Members|true' || r;
});

await t.check('rendimiento: el minimapa duerme si no hay nada que dibujar y despierta cuando cambia el mapa', async () => {
  const r = await get(peregrino, `
    local driver
    for _, f in ipairs(SIM.frames) do
      local fn = f.__scripts.OnUpdate
      if fn then local i = debug.getinfo(fn, "S") if (i.short_src or ""):find("Radar") then driver = f end end
    end
    if not driver then return "sin driver" end
    BG.Positions.mates = {} BG.Radar.Stop()
    driver:Show() driver.__scripts.OnUpdate(driver, 1)
    local slept = not driver:IsShown()
    BG:Fire("BG_MAP_CHANGED")
    local woke = driver:IsShown()
    return tostring(slept) .. "|" .. tostring(woke)`);
  return r === 'true|true' || r;
});

await t.check('rendimiento: leer una línea del sistema una vez sirve a todos, y una línea que no es de duelo no crea nada', async () => {
  const r = await get(peregrino, `
    local line = "Tarek Vientoalto has defeated Bruno Hierrosol in a duel"
    local a1, b1, c1 = BG.Arena.DuelResult(line)
    local a2, b2, c2 = BG.Arena.ReadDuel(line)
    collectgarbage("collect") collectgarbage("stop")
    local k0 = collectgarbage("count")
    for i = 1, 200 do BG.Arena.DuelResult("Socio Numero" .. (i % 2) .. " se ha conectado.") end
    local kb = collectgarbage("count") - k0
    collectgarbage("restart")
    return tostring(a1 == a2 and b1 == b2 and c1 == c2 and a1 == "Tarek Vientoalto") .. "|" .. tostring(kb < 20)`);
  return r === 'true|true' || r;
});

await t.check('el addon nunca recarga la interfaz por su cuenta (Forever lo bloquea: «acción de interfaz fallida por culpa de un accesorio»)', async () => {
  const fs = await import('node:fs');
  const path = await import('node:path');
  const root = path.join(path.dirname(new URL(import.meta.url).pathname.replace(/^\/(\w:)/, '$1')), '..', 'BlazonGuild');
  const found = [];
  const walk = (d) => { for (const n of fs.readdirSync(d)) { const p = path.join(d, n); if (fs.statSync(p).isDirectory()) walk(p); else if (n.endsWith('.lua')) {
    fs.readFileSync(p, 'utf8').split('\n').forEach((l, i) => { if (/\b(ReloadUI|C_UI\.Reload)\s*\(/.test(l) && !/^\s*--/.test(l)) found.push(`${path.relative(root, p)}:${i + 1}`); });
  } } };
  walk(root);
  return found.length === 0 || found.join(', ');
});

await t.check('el addon no llama a funciones que Forever no tiene (GetItemInfo suelta y las demás que midió la sonda): con ellas la Armería decía «Objeto 6189»', async () => {
  const fs = await import('node:fs');
  const path = await import('node:path');
  const root = path.join(path.dirname(new URL(import.meta.url).pathname.replace(/^\/(\w:)/, '$1')), '..', 'BlazonGuild');
  const MISSING = ['GetItemInfo', 'CombatLogGetCurrentEventInfo', 'GetSkillLineInfo', 'GetTalentInfo', 'GetNumTalentTabs', 'UnitPVPRank',
    'GetPVPRankInfo', 'EasyMenu', 'InterfaceOptions_AddCategory', 'CreateGuildAnnouncement'];
  const re = new RegExp(`(^|[^.:\\w])(${MISSING.join('|')})\\b`);
  const found = [];
  const walk = (d) => { for (const n of fs.readdirSync(d)) { const p = path.join(d, n); if (fs.statSync(p).isDirectory()) walk(p); else if (n.endsWith('.lua')) {
    fs.readFileSync(p, 'utf8').split('\n').forEach((l, i) => {
      const code = l.replace(/--.*$/, '').replace(/"(?:[^"\\]|\\.)*"/g, '""');
      const m = code.match(re);
      if (m) found.push(`${path.relative(root, p)}:${i + 1} ${m[2]}`);
    });
  } } };
  walk(root);
  return found.length === 0 || found.join(', ');
});

t.report();
net.close();
