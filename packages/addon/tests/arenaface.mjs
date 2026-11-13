// The Arena's extras (0.23.0, the rest of entrega 12): «Cara a cara» (two fighters side by side, their meetings, their
// health live while in sight, the result of the duel when the game says it, for whoever watches), «Ver un duelo» from
// the target, arbiters (the organisers name them; they decide bouts and take duels out), a chat room for each
// tournament, and the screens (also in the six languages).
import { createNetwork, checklist } from './harness.mjs';

const P = {
  tarek: { first: 'Tarek', second: 'Vientoalto', guid: 'Player-6842-SIMA', rosterIndex: 1 }, // Maestro
  bruno: { first: 'Bruno', second: 'Hierrosol', guid: 'Player-6842-SIMD', rosterIndex: 3 }, // Oficial
  peregrino: { first: 'El', second: 'Peregrino', guid: 'Player-6842-0A1B2C3D', rosterIndex: 2 }, // Miembro
  rina: { first: 'Rina', second: 'Dagaluna', guid: 'Player-6842-SIMB', rosterIndex: 5 }, // Miembro
};
const net = await createNetwork(Object.values(P));
const [tarek, bruno, peregrino, rina] = net.clients;
await net.loginAll();
for (const c of net.clients) await c.run('BG.Consent.Accept()');
await net.advance(20, 0.5);
const get = net.get;
const t = checklist('comprobaciones de cara a cara, árbitros y salas de la Arena');
const notice = (c) => get(c, 'return BG.lastNotice and (BG.lastNotice.title .. "|" .. (BG.lastNotice.text or "")) or ""');
const PER = 'Tarek Vientoalto', BEN = 'Bruno Hierrosol';
const duel = async (w, l) => {
  for (const c of net.clients) await c.run(`SIM.fire("CHAT_MSG_SYSTEM", ${JSON.stringify(`${w} has defeated ${l} in a duel`)})`);
  await net.advance(3);
};
for (const c of net.clients) {
  await c.run(`SIM.health = {} -- unit -> { cur, max }
    UnitHealth = function(u) local h = SIM.health[u] return h and h[1] or 0 end
    UnitHealthMax = function(u) local h = SIM.health[u] return h and h[2] or 0 end`);
}

await duel(PER, BEN);
await duel(PER, BEN);
await duel(BEN, PER);

await t.check('cara a cara: puntuación, récord, el cinturón y cuántas veces se han ganado entre ellos', async () => {
  const r = await get(peregrino, `local m = BG.ArenaFace.Model("Tarek Vientoalto", "Bruno Hierrosol")
    return m.a.name .. "|" .. m.a.wins .. "-" .. m.a.losses .. "|" .. m.b.wins .. "-" .. m.b.losses .. "|" .. m.meetings.a .. "-" .. m.meetings.b
      .. "|" .. tostring(m.b.champion) .. "|" .. tostring(m.a.rating > 1500)`);
  return r === `${PER}|2-1|1-2|2-1|true|true` || r;
});

await t.check('la ventana se abre con los dos, cabe, y crece y encoge', async () => {
  const r = await get(peregrino, `local f = BG.UI.FaceOff("Tarek Vientoalto", "Bruno Hierrosol") SIM.layout(1920, 1080)
    local lay = table.concat(SIM.CheckLayout(f), " ; ")
    f.bigger:Click() f.bigger:Click()
    local big = BG.db.settings.faceScale
    f.smaller:Click()
    return tostring(f:IsShown()) .. "|" .. f.meet:GetText() .. "|" .. string.format("%.1f/%.1f", big, BG.db.settings.faceScale) .. "|" .. lay`);
  return r === 'true|Entre ellos: 2-1|1.2/1.1|' || r;
});

await t.check('en directo: la vida de cada uno mientras está a la vista; si no, «fuera de vista»', async () => {
  const r = await get(peregrino, `
    SIM.units.target = { "Tarek", "Vientoalto" } SIM.health.target = { 300, 1000 }
    SIM.units.party1 = { "Bruno", "Hierrosol" } SIM.health.party1 = { 900, 1000 }
    BG.UI.FaceOffTick()
    local f = BG.UI.FaceOffFrame()
    local a, b = f.A.hp:GetText(), f.B.hp:GetText()
    SIM.units.party1 = nil
    BG.UI.FaceOffTick()
    return a .. "|" .. b .. "|" .. f.B.hp:GetText()`);
  return r.replace(/\|c[0-9a-f]{8}|\|r/g, '') === '30%|90%|fuera de vista' || r;
});

await t.check('el resultado del duelo sale en la ventana de quien mira (sin apuntarlo: no es su combate)', async () => {
  const before = await get(peregrino, 'return #BG.Store.List("duels")');
  await peregrino.run(`SIM.fire("CHAT_MSG_SYSTEM", "Bruno Hierrosol has defeated Tarek Vientoalto in a duel")`);
  await net.advance(2);
  const r = await get(peregrino, 'return BG.UI.FaceOffFrame().result:GetText()');
  const after = await get(peregrino, 'return #BG.Store.List("duels")');
  return (r === `Gana ${BEN}` && after === before) || `${r}; duelos ${before}->${after}`;
});

await t.check('«Ver un duelo»: con tu objetivo y el suyo; sin ellos, te dice cómo', async () => {
  const none = await get(rina, 'SIM.units.target = nil SIM.units.targettarget = nil return tostring(BG.UI.WatchDuel() ~= nil)');
  const told = await notice(rina);
  const r = await get(rina, `SIM.units.target = { "Tarek", "Vientoalto" } SIM.units.targettarget = { "Bruno", "Hierrosol" }
    local f = BG.UI.WatchDuel() return f and (f.pair.A .. "|" .. f.pair.B) or "nada"`);
  return (none === 'false' && told.startsWith('Ver un duelo') && r === `${PER}|${BEN}`) || `sin objetivo ${none} (${told}); con objetivo ${r}`;
});

await t.check('árbitros: solo los organizadores los nombran; deciden combates y quitan duelos como ellos', async () => {
  const member = await get(peregrino, 'local ok, w = BG.ArenaFace.ToggleArbiter("Rina Dagaluna") return tostring(w)');
  const outsider = await get(bruno, 'local ok, w = BG.ArenaFace.ToggleArbiter("Nadie Existe") return tostring(w)');
  if (member !== 'permiso' || outsider !== 'no es de la hermandad') return `miembro: ${member}; de fuera: ${outsider}`;
  await tarek.run('local id = assert(BG.Tourney.Create({ kind = "NIGHT", title = "Velada del viernes" })) ');
  await net.advance(4);
  const before = await get(rina, 'local t = BG.Tourney.List()[1] return tostring(BG.Tourney.CanManage(t)) .. "|" .. tostring(BG.Arena.CanRemove(BG.Store.List("duels")[1]))');
  await bruno.run('assert(BG.ArenaFace.ToggleArbiter("Rina Dagaluna"))');
  await net.advance(4);
  const after = await get(rina, 'local t = BG.Tourney.List()[1] return tostring(BG.Tourney.CanManage(t)) .. "|" .. tostring(BG.Arena.CanRemove(BG.Store.List("duels")[1]))');
  const list = await get(peregrino, 'return table.concat(BG.ArenaFace.Arbiters(), ",")');
  return (before === 'false|false' && after === 'true|true' && list === 'Rina Dagaluna') || `antes ${before}; después ${after}; lista ${list}`;
});

await t.check('sala de chat del torneo: sale en Chat y lo que se escribe allí llega a la hermandad', async () => {
  const room = await get(peregrino, 'for _, r in ipairs(BG.Chat.Rooms()) do if r.event then return r.id .. "|" .. r.name end end return "nada"');
  const [id, name] = room.split('|');
  if (name !== 'Velada: Velada del viernes') return `sala: ${room}`;
  await peregrino.run(`assert(BG.Chat.Send(${JSON.stringify(id)}, "¿quién abre la velada?"))`);
  await net.advance(4);
  const heard = await get(rina, `local n = 0 for _, l in ipairs(BG.Chat.History(${JSON.stringify(id)})) do if l.text == "¿quién abre la velada?" then n = n + 1 end end return n`);
  return heard === 1 || `Rina la ve ${heard} veces`;
});

await t.check('pantallas: la Arena del organizador (árbitros y «Ver un duelo») y la velada con «Cara a cara», sin nada fuera de su sitio', async () => {
  await tarek.run('local t = BG.Tourney.List()[1] assert(BG.Tourney.AddBout(t.id, "Tarek Vientoalto", "Bruno Hierrosol")) assert(BG.Tourney.StartNight(t.id))');
  await net.advance(4);
  const r = await get(tarek, `BG:ToggleWindow() BG:ShowView("arena") SIM.layout(834, 604)
    local f = BG.window.viewFrames.arena
    local lay1 = table.concat(SIM.CheckLayout(f), " ; ")
    local shown = tostring(f.arbSet:IsShown()) .. tostring(f.watch:IsShown())
    f.tabs.buttons[4]:Click() SIM.layout(834, 604)
    local face
    for _, b in ipairs(f.cupBtns) do if b:IsShown() and b.text:GetText() == "Cara a cara del siguiente combate" then face = b end end
    local lay2 = table.concat(SIM.CheckLayout(f), " ; ")
    if face then face:Click() end
    local fo = BG.UI.FaceOffFrame()
    return shown .. "|" .. tostring(face ~= nil) .. "|" .. (fo and fo:IsShown() and fo.pair.A or "") .. "|" .. lay1 .. "|" .. lay2`);
  return r === `truetrue|true|${PER}||` || r;
});

await t.check('en los 6 idiomas la ventana «Cara a cara» cabe y no deja nada en español', async () => {
  const bad = [];
  for (const lang of ['en', 'de', 'fr', 'it', 'pt', 'ru']) {
    const r = await get(peregrino, `BG.db.settings.lang = "${lang}" BG.Locale.Init()
      local f = BG.UI.FaceOff("Tarek Vientoalto", "Bruno Hierrosol") SIM.layout(1920, 1080)
      SIM.units.party1 = nil BG.UI.FaceOffTick()
      local texts = { f.A.who:GetText(), f.A.rank:GetText(), f.A.record:GetText(), f.A.last:GetText(), f.B.rank:GetText(), f.meet:GetText(), f.result:GetText(), f.B.hp:GetText() }
      return table.concat(SIM.CheckLayout(f), " ; ") .. " ## " .. table.concat(texts, " || ")`);
    const [lay, texts] = r.split(' ## ');
    // ("derrotas" is Portuguese too)
    const spanish = texts.match(lang === 'pt' ? /\b(Nivel|victorias|Últimos|Entre ellos|Gana|fuera de vista|puesto|campeón)\b/
      : /\b(Nivel|victorias|derrotas|Últimos|Entre ellos|Gana|fuera de vista|puesto|campeón)\b/);
    if (lay || spanish) bad.push(`${lang}: ${lay} ${spanish ? '«' + spanish[0] + '» en ' + texts : ''}`);
  }
  await peregrino.run('BG.db.settings.lang = "es" BG.Locale.Init()');
  return bad.length === 0 || bad.join('\n');
});

await t.check('ningún error interno y límites del juego respetados', async () => {
  if (net.violations.length) return net.violations.slice(0, 3).join('; ');
  for (const c of net.clients) {
    const e = await get(c, 'local e = BG.db.errors and BG.db.errors[1] return e and (e.where .. ": " .. e.error) or ""');
    if (e) return `${c.name}: ${e}`;
  }
  return true;
});

net.close();
t.report();
