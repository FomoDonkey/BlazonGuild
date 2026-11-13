// «Se busca», honores y marcas (entrega 11): a member's own death to a player of the other faction (the game's death
// recap) puts him on the list with his bounty; what never counts (an instance, the same faction, an old recap, a
// creature, the same death twice, a member who turned it off); a member's own killing blow (PARTY_KILL) collects
// the bounty; only one's own rows (the organisers may take one off); the sighting notice; the honours, the profile,
// the marks over the names and the target's portrait; and the screens.
import { createNetwork, checklist } from './harness.mjs';

const P = {
  tarek: { first: 'Tarek', second: 'Vientoalto', guid: 'Player-6842-SIMA', rosterIndex: 1 }, // Maestro
  bruno: { first: 'Bruno', second: 'Hierrosol', guid: 'Player-6842-SIMD', rosterIndex: 3 }, // Oficial
  peregrino: { first: 'El', second: 'Peregrino', guid: 'Player-6842-0A1B2C3D', rosterIndex: 2 }, // Miembro
};
const net = await createNetwork([P.tarek, P.bruno, P.peregrino]);
const [tarek, bruno, peregrino] = net.clients;
await net.loginAll();
for (const c of net.clients) await c.run('BG.Consent.Accept()');
await net.advance(20, 0.5);
const get = net.get;
const t = checklist('comprobaciones de «Se busca», honores y marcas');
const notice = (c) => get(c, 'return BG.lastNotice and (BG.lastNotice.title .. "|" .. (BG.lastNotice.text or "")) or ""');

const HORDE = 'Player-6842-H0RDA1';
const HUMAN = 'Player-6842-HUMANO';
const SKY = 'Player-6842-SKYB0RN';
const players = `
  SIM.players[${JSON.stringify(HORDE)}] = { name = "Grosh", surname = "Rompehuesos", class = "WARRIOR", race = "Orc" }
  SIM.players[${JSON.stringify(HUMAN)}] = { name = "Juan", surname = "Traidor", class = "ROGUE", race = "Human" }
  SIM.players[${JSON.stringify(SKY)}] = { name = "Aire", surname = "Celeste", class = "MAGE", race = "Skyborn" }`;
for (const c of net.clients) await c.run(players);
// One death: the recap's newest row is the killing blow (overkill 0 or more), dated now unless `ago` says otherwise.
const die = (c, source, opts = {}) => c.run(`
  SIM.recap = { { timestamp = GetServerTime() - ${opts.ago ?? 0}, event = ${JSON.stringify(opts.event ?? 'SWING_DAMAGE')}, sourceGUID = ${JSON.stringify(source)},
    sourceName = "Grosh", sourceFlags = ${opts.flags ?? 0x548}, overkill = 12, destGUID = SIM.me.guid },
    { timestamp = GetServerTime() - 2, event = "SPELL_DAMAGE", sourceGUID = ${JSON.stringify(source)}, sourceName = "Grosh", sourceFlags = 0x548, overkill = -1, destGUID = SIM.me.guid } }
  SIM.dead = true
  SIM.fire("PLAYER_DEAD")`);
const bounty = (c, name = 'Grosh Rompehuesos') => get(c, `local f = BG.Wanted.Foe(${JSON.stringify(name)}) return f and f.bounty or 0`);

await t.check('si te mata alguien de la otra facción fuera de mazmorras, entra en «Se busca» y lo ve toda la hermandad', async () => {
  await die(peregrino, HORDE);
  const toMe = await notice(peregrino);
  if (!toMe.startsWith('Te ha matado Grosh Rompehuesos')) return `aviso a Peregrino: ${toMe}`;
  await net.advance(4);
  const b = await bounty(tarek);
  const row = await get(tarek, 'local f = BG.Wanted.Board()[1] return f and (f.name .. "|" .. f.class .. "|" .. f.zone .. "|" .. f.lastVictim) or "nada"');
  return (b === 1 && row === 'Grosh Rompehuesos|WARRIOR|Vega de Tuercespina|El Peregrino') || `recompensa ${b}; ${row}`;
});

await t.check('no cuenta: dentro de una instancia, la misma facción, una raza de las dos, un resumen viejo, una criatura, ni la misma muerte dos veces', async () => {
  const out = [];
  const why = async (setup) => get(peregrino, `${setup}
    SIM.recap[1].timestamp = SIM.recap[1].timestamp
    local r, w = BG.Wanted.ReadDeath() return tostring(w)`);
  await peregrino.run('SIM.inInstance = true');
  await die(peregrino, HORDE, { ago: 1 });
  out.push(await why('SIM.recap[1].timestamp = GetServerTime() - 3'));
  await peregrino.run('SIM.inInstance = false');
  await die(peregrino, HUMAN);
  out.push(await why(`SIM.recap[1].sourceGUID = ${JSON.stringify(HUMAN)} SIM.recap[1].timestamp = GetServerTime() - 4`));
  out.push(await why(`SIM.recap[1].sourceGUID = ${JSON.stringify(SKY)} SIM.recap[1].timestamp = GetServerTime() - 5`));
  out.push(await why(`SIM.recap[1].sourceGUID = ${JSON.stringify(HORDE)} SIM.recap[1].timestamp = GetServerTime() - 600`));
  out.push(await why('SIM.recap[1].sourceGUID = "Creature-0-6842-0-1-1234-0001" SIM.recap[1].timestamp = GetServerTime() - 6'));
  out.push(await why(`SIM.recap[1].sourceGUID = ${JSON.stringify(HORDE)} SIM.recap[1].sourceFlags = 0x518 SIM.recap[1].timestamp = GetServerTime() - 7`));
  await net.advance(4);
  const b = await bounty(tarek);
  const expected = 'instancia,facción,facción,antiguo,no es jugador,no es hostil';
  return (out.join(',') === expected && b === 1) || `${out.join(',')} (recompensa ${b})`;
});

await t.check('la misma muerte leída dos veces cuenta una sola vez', async () => {
  await die(peregrino, HORDE);
  const again = await get(peregrino, 'local r, w = BG.Wanted.ReadDeath() return tostring(w)');
  await net.advance(4);
  const b = await bounty(tarek);
  return (again === 'ya leído' && b === 2) || `${again}, recompensa ${b}`;
});

await t.check('si te mata uno de 10 niveles más (o «??»), cuenta doble; al llegar a 3 de recompensa, aviso «Se busca» a todos', async () => {
  await bruno.run(`SIM.unitGuids.target = ${JSON.stringify(HORDE)} SIM.unitLevels.target = -1`);
  await die(bruno, HORDE);
  await bruno.run('SIM.unitGuids.target = nil SIM.unitLevels.target = nil');
  await net.advance(4);
  const b = await bounty(tarek);
  const n = await notice(tarek);
  return (b === 4 && n.startsWith('Se busca: Grosh Rompehuesos|Ha matado a Bruno Hierrosol')) || `recompensa ${b}; aviso: ${n}`;
});

await t.check('si ves a un buscado, te avisa (una vez cada cinco minutos) y lleva una calavera sobre el nombre', async () => {
  const r = await get(peregrino, `
    BG.lastNotice = nil
    SIM.units.nameplate3 = { "Grosh", "Rompehuesos" } SIM.unitGuids.nameplate3 = ${JSON.stringify(HORDE)} SIM.unitLevels.nameplate3 = 30
    SIM.fire("NAME_PLATE_UNIT_ADDED", "nameplate3")
    local first = BG.lastNotice and BG.lastNotice.title or "sin aviso"
    BG.lastNotice = nil
    SIM.fire("NAME_PLATE_UNIT_ADDED", "nameplate3")
    local second = BG.lastNotice and BG.lastNotice.title or "sin aviso"
    local m = BG.Marks.Apply("nameplate3")
    return first .. "|" .. second .. "|" .. tostring(m)`);
  return r === 'Cerca: Grosh Rompehuesos, se busca|sin aviso|wanted' || r;
});

await t.check('solo apuntas lo tuyo; un oficial puede quitar una línea falsa, un miembro no la de otro', async () => {
  const forged = await get(peregrino, 'local r, w = BG.Store.Put("wanted", "TarekVientoalto-1-abc", { k = "D", foe = "Otro Nombre" }) return tostring(w)');
  if (forged !== 'permiso') return `escribió por otro: ${forged}`;
  const id = await get(peregrino, 'local r = assert(BG.Store.Put("wanted", "ElPeregrino-" .. GetServerTime() .. "-zz", { k = "D", foe = "Falso Nombre", zone = "Inventada" })) return r.id');
  await net.advance(4);
  const seen = await bounty(tarek, 'Falso Nombre');
  if (seen !== 1) return `no llegó la línea: ${seen}`;
  const brunoRow = await get(tarek, 'for _, r in ipairs(BG.Wanted.Recent()) do if r.by == "Bruno Hierrosol" then return r.id end end return ""');
  const member = await get(peregrino, `local r, w = BG.Wanted.Remove(${JSON.stringify(brunoRow)}) return tostring(w)`);
  if (member !== 'permiso') return `un miembro quitó la de otro: ${member}`;
  await bruno.run(`assert(BG.Wanted.Remove(${JSON.stringify(id)}))`);
  await net.advance(4);
  const gone = await bounty(peregrino, 'Falso Nombre');
  return gone === 0 || `sigue: ${gone}`;
});

await t.check('si le das tú el golpe final, te llevas su recompensa más 1 y vuelve a cero; el golpe de otro no cuenta', async () => {
  const other = await get(peregrino, `local r, w = BG.Wanted.PartyKill("Player-6842-SIMA", ${JSON.stringify(HORDE)}) return tostring(w)`);
  if (other !== 'no es mío') return `contó el golpe de otro: ${other}`;
  await tarek.run(`SIM.fire("PARTY_KILL", SIM.me.guid, ${JSON.stringify(HORDE)})`);
  const mine = await notice(tarek);
  if (!mine.startsWith('Has cazado a Grosh Rompehuesos|+5 puntos')) return `aviso a Tarek: ${mine}`;
  await net.advance(4);
  const toPeregrino = await notice(peregrino);
  const r = await get(peregrino, 'local h = BG.Wanted.Hunters()[1] return (h and (h.name .. ":" .. h.n .. ":" .. h.kills) or "nadie") .. "|" .. #BG.Wanted.Board()');
  return (r === 'Tarek Vientoalto:5:1|0' && toPeregrino.startsWith('Tarek Vientoalto ha cazado a Grosh Rompehuesos')) || `${r}; aviso: ${toPeregrino}`;
});

await t.check('quien lo apaga no apunta nada suyo', async () => {
  await bruno.run('BG.Wanted.SetEnabled(false)');
  await die(bruno, HORDE);
  await net.advance(4);
  const b = await bounty(tarek);
  await bruno.run('BG.Wanted.SetEnabled(true)');
  return b === 0 || `apuntó igualmente: ${b}`;
});

await t.check('honores: mejor cazador y fiel a las raids (ya no hay honor del nivel máximo); salen en la ficha', async () => {
  for (const c of net.clients) await c.run('BG.Board.Log("max", "Bruno Hierrosol llega al nivel 60", "Bruno Hierrosol")');
  const raid = await get(peregrino, 'local r = assert(BG.Raids.Save(nil, { inst = "MC", start = time() + 30 })) return r.id');
  await net.advance(3);
  await peregrino.run(`assert(BG.Raids.SignUp(${JSON.stringify(raid)}, "CONFIRMED", "HEALER"))`);
  await bruno.run(`assert(BG.Raids.SignUp(${JSON.stringify(raid)}, "TENTATIVE", "DPS"))`);
  await net.advance(40, 1);
  const r = await get(tarek, `
    BG.Honors.NoteRaids() BG.Honors.Invalidate()
    local a = table.concat(BG.Honors.Of("Tarek Vientoalto"), ",")
    local b = table.concat(BG.Honors.Of("Bruno Hierrosol"), ",")
    local e = table.concat(BG.Honors.Of("El Peregrino"), ",")
    return a .. "|" .. b .. "|" .. e`);
  if (r !== 'Mejor cazador||Fiel a las raids') return r;
  return get(tarek, `
    BG:ToggleWindow() SIM.layout(834, 604)
    BG.UI.ShowProfile("Tarek Vientoalto")
    for _, o in ipairs(SIM.objects) do
      local t = o.GetText and o:GetText()
      if type(t) == "string" and t:find("Honores: Mejor cazador", 1, true) then return true end
    end
    return "la ficha no enseña los honores"`);
});

await t.check('marcas: escudo sobre los miembros, dorado para los honrados, aro en el retrato; se pueden quitar', async () => {
  return get(peregrino, `
    BG.Honors.Invalidate()
    SIM.units.nameplate1 = { "Tarek", "Vientoalto" }
    SIM.units.nameplate2 = { "Miembro", "Prueba 5" }
    local a, b = BG.Marks.Apply("nameplate1"), BG.Marks.Apply("nameplate2")
    SIM.units.target = { "Tarek", "Vientoalto" }
    local ring = BG.Marks.Target()
    BG.Marks.SetEnabled(false)
    local off = BG.Marks.Apply("nameplate1")
    BG.Marks.SetEnabled(true)
    SIM.units.target = nil
    return tostring(a) .. "|" .. tostring(b) .. "|" .. tostring(ring) .. "|" .. tostring(off) == "honored|member|honored|nil" or (tostring(a) .. "|" .. tostring(b) .. "|" .. tostring(ring) .. "|" .. tostring(off))`);
});

await t.check('en el chat: escudo dorado junto a lo que dice un honrado, en el nuestro y en el del juego; nada si el juego lo oculta', async () => {
  return get(peregrino, `
    BG.Honors.Invalidate()
    local crest = BG.Marks.CREST
    if BG.Marks.chatEvents ~= 12 or not SIM.filters.CHAT_MSG_GUILD then return "filtros del chat: " .. tostring(BG.Marks.chatEvents) end
    local filter = SIM.filters.CHAT_MSG_GUILD[#SIM.filters.CHAT_MSG_GUILD]
    local hide, msg, author, extra = filter(nil, "CHAT_MSG_GUILD", "hola", "Tarek Vientoalto-ForeverPvP", "x")
    if hide ~= false or msg ~= crest .. "hola" or author ~= "Tarek Vientoalto-ForeverPvP" or extra ~= "x" then return "honrado: " .. tostring(msg) end
    local h2, m2 = filter(nil, "CHAT_MSG_GUILD", "hola", "Miembro Prueba 5-ForeverPvP")
    if h2 ~= false or m2 ~= nil then return "sin honor: " .. tostring(m2) end
    issecretvalue = function(v) return v == "oculto" end
    local h3, m3 = filter(nil, "CHAT_MSG_GUILD", "oculto", "Tarek Vientoalto")
    issecretvalue = nil
    if h3 ~= false or m3 ~= nil then return "mensaje oculto tocado: " .. tostring(m3) end
    local ours = BG.Chat.FormatLine("guild", 1, { from = "Tarek Vientoalto", text = "hola", at = time(), class = "WARRIOR" })
    if not ours:find(crest, 1, true) then return "nuestro chat: " .. ours end
    BG.Marks.SetEnabled(false)
    local h4, m4 = filter(nil, "CHAT_MSG_GUILD", "hola", "Tarek Vientoalto")
    local off = BG.Chat.FormatLine("guild", 1, { from = "Tarek Vientoalto", text = "hola", at = time(), class = "WARRIOR" })
    BG.Marks.SetEnabled(true)
    if m4 ~= nil or off:find(crest, 1, true) then return "con las marcas apagadas sigue saliendo" end
    return true`);
});

await t.check('pantallas: «Se busca», «Lo último» y Rankings y honores, y nada se sale ni se monta', async () => {
  await bruno.run('SIM.unitLevels = {}');
  await die(bruno, HORDE);
  await net.advance(4);
  return get(tarek, `
    BG:ShowView("pvp") SIM.layout(834, 604)
    local f = BG.window.viewFrames.pvp
    if f.guide then f.guide:Hide() end
    if #f.foes.items ~= 1 then return "se busca: " .. #f.foes.items end
    if not f.hunters:GetText():find("Tarek Vientoalto: 5 puntos", 1, true) then return "cazadores: " .. f.hunters:GetText() end
    local out = SIM.CheckLayout(f) if #out > 0 then return "se busca: " .. out[1] end
    f.tabs.buttons[2]:Click() SIM.layout(834, 604)
    if #f.recent.items < 3 then return "lo último: " .. #f.recent.items end
    out = SIM.CheckLayout(f) if #out > 0 then return "lo último: " .. out[1] end
    BG:ShowView("rankings") SIM.layout(834, 604)
    local r = BG.window.viewFrames.rankings
    if r.guide then r.guide:Hide() end
    if #r.cards ~= 6 then return "honores: " .. #r.cards end
    if r.rows[1].name:GetText():find("Tarek Vientoalto", 1, true) == nil then return "ranking: " .. tostring(r.rows[1].name:GetText()) end
    out = SIM.CheckLayout(r) if #out > 0 then return "rankings: " .. out[1] end
    -- the ten places fit in their board, and nothing reaches the bar below
    for i = 1, 10 do r.rows[i].name:SetText("Nombre Larguisimo " .. i) r.rows[i].value:SetText("1234 puntos, 99 bajas") r.rows[i].name:Show() r.rows[i].value:Show() r.rows[i].pos:Show() end
    local foot, board = SIM.Rect(r.foot), SIM.Rect(r.board)
    if board.b > foot.t then return "el ranking pisa la barra de abajo" end
    if SIM.Rect(r.cards[6]).b > foot.t then return "los honores pisan la barra de abajo" end
    for i = 1, 10 do
      local n = SIM.Rect(r.rows[i].value)
      if n.b > board.b - 4 then return "el puesto " .. i .. " se sale del cuadro" end
    end
    out = SIM.CheckLayout(r) if #out > 0 then return "rankings con 10: " .. out[1] end
    r.cards[3]:Click()
    if r.board.head:GetText() ~= "Mayor donante" then return "al pulsar otro honor: " .. tostring(r.board.head:GetText()) end
    return true`);
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
