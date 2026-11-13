// La Arena (entrega 12, primera parte): reading the game's duel lines (any language's format), only the loser's
// client writes the duel, the rating (Elo with the level factor and the pair window), tiers and the champion's belt,
// duels that do not count (someone from outside, a member without the addon), seasons, challenges, the duel request
// notice, the profile, and the screens.
import { createNetwork, checklist } from './harness.mjs';

const P = {
  tarek: { first: 'Tarek', second: 'Vientoalto', guid: 'Player-6842-SIMA', rosterIndex: 1 }, // Maestro, nivel 17
  bruno: { first: 'Bruno', second: 'Hierrosol', guid: 'Player-6842-SIMD', rosterIndex: 3 }, // Oficial, nivel 60
  peregrino: { first: 'El', second: 'Peregrino', guid: 'Player-6842-0A1B2C3D', rosterIndex: 2 }, // Miembro, nivel 24
};
const net = await createNetwork([P.tarek, P.bruno, P.peregrino]);
const [tarek, bruno, peregrino] = net.clients;
await net.loginAll();
for (const c of net.clients) await c.run('BG.Consent.Accept()');
await net.advance(20, 0.5);
const get = net.get;
const t = checklist('comprobaciones de la Arena');
const notice = (c) => get(c, 'return BG.lastNotice and (BG.lastNotice.title .. "|" .. (BG.lastNotice.text or "")) or ""');
const PER = 'Tarek Vientoalto', BEN = 'Bruno Hierrosol', EDG = 'El Peregrino';
// The game's line, seen by everyone nearby.
const duel = async (w, l, how = 'K') => {
  const line = how === 'K' ? `${w} has defeated ${l} in a duel` : `${l} has fled from ${w} in a duel`;
  for (const c of net.clients) await c.run(`SIM.fire("CHAT_MSG_SYSTEM", ${JSON.stringify(line)})`);
  await net.advance(3);
};
const rating = (c, n) => get(c, `local f = BG.Arena.Fighter(${JSON.stringify(n)}) return f and f.rating or 0`);

await t.check('lee la línea del duelo en cualquier idioma (también con argumentos numerados) y nada más', async () => {
  return get(peregrino, `
    local out = {}
    local function r(msg) local w, l, m = BG.Arena.DuelResult(msg) return tostring(w) .. "/" .. tostring(l) .. "/" .. tostring(m) end
    out[#out + 1] = r("Tarek Vientoalto has defeated El Peregrino in a duel")
    out[#out + 1] = r("El Peregrino has fled from Tarek Vientoalto-ForeverPvP in a duel")
    DUEL_WINNER_KNOCKOUT = "%1$s ha derrotado a %2$s en un duelo"
    DUEL_WINNER_RETREAT = "%2$s ha huido de %1$s en un duelo"
    out[#out + 1] = r("Bruno Hierrosol ha derrotado a El Peregrino en un duelo")
    out[#out + 1] = r("El Peregrino ha huido de Bruno Hierrosol en un duelo")
    out[#out + 1] = r("Bruno Hierrosol has defeated El Peregrino in a duel")
    DUEL_WINNER_KNOCKOUT, DUEL_WINNER_RETREAT = nil, nil
    out[#out + 1] = r("Alguien dice hola")
    issecretvalue = function(v) return v == "oculta" end
    out[#out + 1] = r("oculta")
    issecretvalue = nil
    local roll = BG.Arena.Scan(BG.Arena.Format("RANDOM_ROLL_RESULT"), "El Peregrino rolls 42 (1-100)")
    out[#out + 1] = roll and (roll[1] .. ":" .. roll[2] .. ":" .. roll[3] .. "-" .. roll[4]) or "sin tirada"
    out[#out + 1] = tostring(BG.Arena.Scan("%5.2f veces", "1.00 veces"))
    return table.concat(out, ",")`).then((r) => r === 'Tarek Vientoalto/El Peregrino/K,Tarek Vientoalto/El Peregrino/F,Bruno Hierrosol/El Peregrino/K,Bruno Hierrosol/El Peregrino/F,nil/nil/nil,nil/nil/nil,nil/nil/nil,El Peregrino:42:1-100,nil' || r);
});

await t.check('un duelo entre dos de la hermandad: lo apunta quien pierde y lo ve toda la hermandad, con la puntuación', async () => {
  await duel(PER, EDG);
  const toPeregrino = await notice(peregrino);
  if (!toPeregrino.startsWith('Te ha ganado Tarek Vientoalto|Tu puntuación: 1465 (-35)')) return `aviso a Peregrino: ${toPeregrino}`;
  await net.advance(3);
  const toTarek = await notice(tarek);
  if (!toTarek.startsWith('Victoria apuntada|Contra El Peregrino: 1535 puntos (+35)')) return `aviso a Tarek: ${toTarek}`;
  const r = await get(bruno, 'local b = BG.Arena.Build() return #BG.Arena.Recent() .. "|" .. b.belt .. "|" .. BG.Arena.Fighter("Tarek Vientoalto").rating .. "|" .. BG.Arena.Fighter("El Peregrino").rating');
  return r === '1|Tarek Vientoalto|1535|1465' || r;
});

await t.check('solo quien pierde apunta: nadie puede darse victorias', async () => {
  const winner = await get(tarek, 'local r, w = BG.Store.Put("duels", "TarekVientoalto-1-aaa", { w = "Tarek Vientoalto", l = "El Peregrino", m = "K" }) return tostring(w)');
  const self = await get(peregrino, 'local r, w = BG.Store.Put("duels", "ElPeregrino-1-bbb", { w = "El Peregrino", l = "Tarek Vientoalto", m = "K" }) return tostring(w)');
  return (winner === 'permiso' && self === 'permiso') || `ganador: ${winner}; a sí mismo: ${self}`;
});

await t.check('los mismos dos en 24 horas valen la mitad cada vez (nadie gana puntos a base de repetir)', async () => {
  const want = await get(peregrino, 'local e = BG.Arena.Expected(1535, 1465, 17, 24) return math.floor(40 * (1 - e) * 0.5 + 0.5)');
  await duel(PER, EDG, 'F');
  await net.advance(3);
  const r = await get(bruno, 'local d = BG.Arena.Recent()[1] return d.d.m .. "|" .. d.delta.gain');
  return r === `F|${want}` || `${r} (esperado F|${want})`;
});

await t.check('no cuenta: contra alguien de fuera, ni si quien pierde no tiene el addon (y se dice por qué)', async () => {
  await peregrino.run('SIM.fire("CHAT_MSG_SYSTEM", "Grosh Rompehuesos has defeated El Peregrino in a duel")');
  const out = await notice(peregrino);
  await tarek.run('SIM.fire("CHAT_MSG_SYSTEM", "Tarek Vientoalto has defeated Miembro Prueba 5 in a duel")');
  const noAddon = await notice(tarek);
  await net.advance(3);
  const n = await get(bruno, 'return #BG.Arena.Recent()');
  if (!out.includes('no es de tu hermandad')) return `de fuera: ${out}`;
  if (!noAddon.includes('Miembro Prueba 5 no tiene BlazonGuild')) return `sin addon: ${noAddon}`;
  return n === 2 || `combates: ${n}`;
});

await t.check('con 5 combates hay rango (oro, plata, bronce) y el cinturón pasa a quien gana al campeón', async () => {
  await duel(BEN, EDG);
  await duel(BEN, EDG);
  await duel(BEN, PER); // (Bruno gana al campeón: el cinturón es suyo)
  await duel(BEN, PER);
  await duel(EDG, PER);
  await duel(EDG, BEN); // (El Peregrino gana al campeón)
  await net.advance(3);
  return get(tarek, `
    BG.Arena.Invalidate()
    local b = BG.Arena.Build()
    local tiers = {}
    for i, f in ipairs(b.ranked) do tiers[i] = f.name .. ":" .. f.tier.key .. ":" .. f.fights end
    if #b.ranked ~= 3 then return "con rango: " .. #b.ranked end
    if b.ranked[1].tier.key ~= "gold" or b.ranked[2].tier.key ~= "silver" or b.ranked[3].tier.key ~= "bronze" then return table.concat(tiers, ",") end
    if b.ranked[1].rating < b.ranked[2].rating or b.ranked[2].rating < b.ranked[3].rating then return "orden: " .. table.concat(tiers, ",") end
    return b.belt == "El Peregrino" or ("cinturón: " .. tostring(b.belt))`);
});

await t.check('cuando te reta en el juego alguien de la hermandad, te dice su puntuación; y sale en su ficha', async () => {
  const r = await get(peregrino, `
    BG.lastNotice = nil
    SIM.fire("DUEL_REQUESTED", "Bruno Hierrosol")
    local n = BG.lastNotice and BG.lastNotice.text or "sin aviso"
    BG.lastNotice = nil
    SIM.fire("DUEL_REQUESTED", "Grosh Rompehuesos")
    if BG.lastNotice then return "avisó de uno de fuera" end
    BG:ToggleWindow() SIM.layout(834, 604)
    BG.UI.ShowProfile("Bruno Hierrosol")
    local inProfile = false
    for _, o in ipairs(SIM.objects) do
      local t = o.GetText and o:GetText()
      if type(t) == "string" and t:find("Arena: ", 1, true) and t:find("victorias", 1, true) then inProfile = true end
    end
    return n .. "|" .. tostring(inProfile)`);
  return (r.startsWith('En la Arena: ') && r.endsWith('|true')) || r;
});

await t.check('retos: «Retar», «Aceptar» y «No» llegan a los dos; sin addon o dos veces seguidas no se puede', async () => {
  await peregrino.run(`assert(BG.Arena.Challenge(${JSON.stringify(BEN)}, "¿Revancha?"))`);
  const again = await get(peregrino, `local r, w = BG.Arena.Challenge(${JSON.stringify(BEN)}) return tostring(w)`);
  const nobody = await get(peregrino, 'local r, w = BG.Arena.Challenge("Miembro Prueba 5") return tostring(w)');
  await net.advance(3);
  const tray = await get(bruno, 'local c = BG.Arena.Challenges()[1] return c and (c.name .. "|" .. tostring(c.note)) or "vacía"');
  if (tray !== 'El Peregrino|¿Revancha?') return `bandeja de Bruno: ${tray}`;
  await bruno.run(`assert(BG.Arena.Answer(${JSON.stringify(EDG)}, true))`);
  await net.advance(3);
  const yes = await notice(peregrino);
  const accepted = await get(peregrino, `return tostring(BG.Arena.Accepted(${JSON.stringify(BEN)}))`);
  await tarek.run(`assert(BG.Arena.Challenge(${JSON.stringify(BEN)}))`);
  await net.advance(3);
  await bruno.run(`assert(BG.Arena.Answer(${JSON.stringify(PER)}, false))`);
  await net.advance(3);
  const no = await notice(tarek);
  if (again !== 'espera' || nobody !== 'sin addon') return `dos veces: ${again}; sin addon: ${nobody}`;
  if (!yes.startsWith('Bruno Hierrosol acepta tu reto') || accepted !== 'true') return `sí: ${yes} (${accepted})`;
  return no.startsWith('Bruno Hierrosol no acepta ahora') || `no: ${no}`;
});

await t.check('pantallas: clasificación, retos con la bandeja, combates, y nada se sale ni se monta', async () => {
  await tarek.run(`assert(BG.Arena.Challenge(${JSON.stringify(EDG)}, "Ven a Ventormenta"))`);
  await net.advance(3);
  return get(peregrino, `
    BG:ShowView("arena") SIM.layout(834, 604)
    local f = BG.window.viewFrames.arena
    if f.guide then f.guide:Hide() end
    if #f.fighters.items ~= 3 then return "clasificación: " .. #f.fighters.items end
    if f.season:IsShown() then return "un miembro ve «Nueva temporada»" end
    local out = SIM.CheckLayout(f) if #out > 0 then return "clasificación: " .. out[1] end
    SIM.roster[5][9] = true BG.Guild.Scan() -- (someone online without BlazonGuild)
    f.tabs.buttons[2]:Click() SIM.layout(834, 604)
    if #f.rivals.items ~= 3 then return "a quién retar: " .. #f.rivals.items end
    local last = f.rivals.items[3]
    if last.addon or not f.rivals.items[1].addon then return "orden: los que tienen el addon van primero" end
    for _, row in ipairs(f.rivals.rows or {}) do
      if row.rival == last and row.go:IsShown() then return "«Retar» a alguien sin addon" end
    end
    if #f.challenges.items ~= 1 or not f.challenges:IsShown() then return "te retan: " .. #f.challenges.items end
    out = SIM.CheckLayout(f) if #out > 0 then return "retos: " .. out[1] end
    f.tabs.buttons[3]:Click() SIM.layout(834, 604)
    if #f.duels.items ~= 8 then return "combates: " .. #f.duels.items end
    out = SIM.CheckLayout(f) if #out > 0 then return "combates: " .. out[1] end
    local nav = BG.window.navButtons.arena
    if not nav then return "la Arena no está en el menú" end
    return true`);
});

await t.check('temporada nueva: solo un oficial; se guarda el campeón y el podio, y todos vuelven a empezar', async () => {
  const member = await get(peregrino, 'local r, w = BG.Arena.NewSeason() return tostring(w)');
  if (member !== 'permiso') return `un miembro la empezó: ${member}`;
  await tarek.run('assert(BG.Arena.NewSeason())');
  await net.advance(4);
  const r = await get(peregrino, `
    BG.Arena.Invalidate()
    local season, since, past = BG.Arena.Season()
    local b = BG.Arena.Build()
    return season .. "|" .. #b.list .. "|" .. tostring(past[1] and past[1].champ) .. "|" .. (past[1] and #past[1].top or 0) .. "|" .. (past[1] and past[1].fights or 0)`);
  return r === '2|0|El Peregrino|3|8' || r;
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
