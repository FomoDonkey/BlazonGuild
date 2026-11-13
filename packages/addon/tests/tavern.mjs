// La Taberna (entrega 12, tercera parte): the Huesos rules, a practice game against the house, a game between two
// members (the same dice reach both, a throw with nothing loses the turn, the winner, nobody can play out of turn or
// give themselves a win), an invitation turned down, the practice lottery (free tickets, the officers' draw with
// /roll, who hits), the innkeeper's word, and the screens. Points only, no gold.
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
const t = checklist('comprobaciones de la Taberna');
const notice = (c) => get(c, 'return BG.lastNotice and (BG.lastNotice.title .. "|" .. (BG.lastNotice.text or "")) or ""');
// Throws (a /roll of 1-46656 read as six dice): 1 1 1 2 3 4, and 2 3 4 6 6 2 (nothing scores).
const THREE_ONES = 26137, NOTHING = 15458;

await t.check('las reglas: unos, cincos, tríos y más, escalera, tres parejas; lo que no puntúa; seis dados de un /roll', async () => {
  return get(peregrino, `
    local S, out = BG.Bones.Score, {}
    local cases = { { { 1 }, 100 }, { { 5 }, 50 }, { { 1, 5 }, 150 }, { { 2, 2, 2 }, 200 }, { { 1, 1, 1 }, 1000 }, { { 3, 3, 3, 3 }, 600 },
      { { 6, 6, 6, 6, 6, 6 }, 2400 }, { { 1, 2, 3, 4, 5, 6 }, 1500 }, { { 2, 2, 3, 3, 4, 4 }, 750 } }
    for _, c in ipairs(cases) do if S(c[1]) ~= c[2] then return table.concat(c[1], " ") .. " = " .. tostring(S(c[1])) end end
    if S({ 2 }) or S({ 1, 2 }) then return "un 2 suelto puntúa" end
    if BG.Bones.Best({ 2, 3, 4, 6, 6, 2 }) then return "esa tirada no puntúa" end
    local keep, v = BG.Bones.Best({ 1, 5, 2, 2, 3, 4 })
    if table.concat(keep, ",") ~= "1,2" or v ~= 150 then return "mejor: " .. table.concat(keep, ",") .. " " .. tostring(v) end
    local d = BG.Bones.Decode(${THREE_ONES}, 6)
    if table.concat(d, " ") ~= "1 1 1 2 3 4" then return "dados: " .. table.concat(d, " ") end
    if table.concat(BG.Bones.Decode(46656, 6), "") ~= "666666" or table.concat(BG.Bones.Decode(1, 6), "") ~= "111111" then return "extremos" end
    return true`);
});

await t.check('contra la casa: tu /roll da los dados, apartas, te plantas, y la casa juega su turno sola', async () => {
  return get(peregrino, `
    local g = BG.Bones.Practice()
    SIM.rolls = { ${THREE_ONES} }
    assert(BG.Bones.Roll())
    return true`).then(async (r) => {
    if (r !== true) return r;
    await net.advance(1);
    const mid = await get(peregrino, `local g = BG.Bones.game
      if g.phase ~= "keep" or table.concat(g.dice, " ") ~= "1 1 1 2 3 4" then return "tirada: " .. g.phase .. " " .. table.concat(g.dice or {}, " ") end
      local r, w = BG.Bones.Keep({ 4 }, false)
      if w ~= "no puntúan" then return "apartar un 2: " .. tostring(w) end
      assert(BG.Bones.Keep({ 1, 2, 3 }, true))
      return g.score[1] .. "|" .. g.turn`);
    if (mid !== '1000|2') return `al plantarse: ${mid}`;
    await net.advance(30, 0.5);
    return get(peregrino, `local g = BG.Bones.game return (g.turn == 1 or g.phase == "over") and true or ("la casa no acaba su turno: " .. g.phase)`);
  });
});

await t.check('entre dos miembros: invitar y aceptar; los mismos dados llegan a los dos; si no puntúa nada, pierde el turno; gana el primero en llegar', async () => {
  for (const c of net.clients) await c.run('BG.Bones.TARGET = 1500');
  await peregrino.run('BG.Bones.Quit()');
  await tarek.run('assert(BG.Bones.Invite("El Peregrino"))');
  await net.advance(3);
  const inv = await notice(peregrino);
  if (!inv.startsWith('Tarek Vientoalto te invita a los Huesos')) return `invitación: ${inv}`;
  await peregrino.run('assert(BG.Bones.Answer("Tarek Vientoalto", true))');
  await net.advance(3);
  await tarek.run(`SIM.rolls = { ${THREE_ONES} } assert(BG.Bones.Roll())`);
  await net.advance(3);
  const seen = await get(peregrino, 'local g = BG.Bones.game return g.players[1] .. "|" .. g.phase .. "|" .. table.concat(g.dice or {}, " ")');
  if (seen !== 'Tarek Vientoalto|keep|1 1 1 2 3 4') return `lo que ve El Peregrino: ${seen}`;
  // (out of turn: El Peregrino tries to throw, and to slip a throw of his own to Tarek)
  const early = await get(peregrino, 'local r, w = BG.Bones.Roll() return tostring(w)');
  if (early !== 'fuera de turno') return `tirar sin turno: ${early}`;
  await peregrino.run(`BG.Comm.Send("ZR", { g = BG.Bones.game.id, v = 46656, n = 6 }, "WHISPER", "Tarek Vientoalto")`);
  await net.advance(3);
  const kept = await get(tarek, 'return table.concat(BG.Bones.game.dice, " ")');
  if (kept !== '1 1 1 2 3 4') return `una tirada colada: ${kept}`;
  await tarek.run('assert(BG.Bones.Keep({ 1, 2, 3 }, true))');
  await net.advance(3);
  await peregrino.run(`SIM.rolls = { ${NOTHING} } assert(BG.Bones.Roll())`);
  await net.advance(3);
  const farkle = await get(tarek, 'local g = BG.Bones.game return g.score[1] .. "-" .. g.score[2] .. "|" .. g.turn .. "|" .. g.log[1]');
  if (!farkle.startsWith('1000-0|1|El Peregrino saca 2 3 4 6 6 2: ¡huesos!')) return `huesos: ${farkle}`;
  await tarek.run(`SIM.rolls = { ${THREE_ONES} } assert(BG.Bones.Roll())`);
  await net.advance(3);
  await tarek.run('assert(BG.Bones.Keep({ 1, 2, 3 }, true))');
  await net.advance(4);
  const over = await get(peregrino, 'local g = BG.Bones.game return g.phase .. "|" .. tostring(g.winner)');
  if (over !== 'over|Tarek Vientoalto') return `final: ${over}`;
  const rank = await get(bruno, 'local r = BG.Bones.Ranking()[1] return r and (r.name .. ":" .. r.wins .. "/" .. r.played) or "nadie"');
  return rank === 'Tarek Vientoalto:1/1' || `ranking: ${rank}`;
});

await t.check('nadie se da victorias (solo el que pierde apunta la partida); una invitación se puede rechazar', async () => {
  const forged = await get(tarek, 'local r, w = BG.Store.Put("bones", "TarekVientoalto-1-aa", { w = "Tarek Vientoalto", l = "Bruno Hierrosol" }) return tostring(w)');
  if (forged !== 'permiso') return `se dio una victoria: ${forged}`;
  await bruno.run('assert(BG.Bones.Invite("El Peregrino"))');
  await net.advance(3);
  await peregrino.run('assert(BG.Bones.Answer("Bruno Hierrosol", false))');
  await net.advance(3);
  const no = await notice(bruno);
  return no.startsWith('El Peregrino no quiere jugar ahora') || no;
});

await t.check('lotería: hasta 3 boletos gratis al día; sortea un oficial con /roll 1-100 y se anuncia quién acierta', async () => {
  const errs = await get(peregrino, `
    assert(BG.Lotto.Take(42)) assert(BG.Lotto.Take("7"))
    local _, a = BG.Lotto.Take(42) local _, b = BG.Lotto.Take(150) local _, c = BG.Lotto.Take("doce")
    assert(BG.Lotto.Take(99)) local _, d = BG.Lotto.Take(5)
    local _, e = BG.Lotto.Draw()
    return table.concat({ tostring(a), tostring(b), tostring(c), tostring(d), tostring(e) }, ",")`);
  if (errs !== 'repetido,número,número,lleno,permiso') return `errores: ${errs}`;
  await bruno.run('assert(BG.Lotto.Take(42))');
  await net.advance(4);
  await tarek.run('SIM.rolls = { 42 } assert(BG.Lotto.Draw())');
  await net.advance(4);
  const heard = await notice(peregrino);
  const late = await get(peregrino, 'local _, w = BG.Lotto.Take(3) return tostring(w)');
  if (late !== 'sorteado') return `después del sorteo: ${late}`;
  return heard.startsWith('Lotería: ha salido el 42|Aciertan: Bruno Hierrosol, El Peregrino') || heard;
});

await t.check('al hablar con un posadero, un aviso propone una partida (una vez por posadero); con otro PNJ, nada', async () => {
  return get(peregrino, `
    BG.lastNotice = nil
    SIM.gossip = { { name = "Quiero recorrer el mundo", icon = 132050 } }
    SIM.fire("GOSSIP_SHOW")
    if BG.lastNotice then return "avisó con otro PNJ" end
    SIM.gossip = { { name = "Haz de esta posada tu hogar", icon = 132052 } }
    SIM.fire("GOSSIP_SHOW")
    local first = BG.lastNotice and BG.lastNotice.title or "sin aviso"
    BG.lastNotice = nil
    SIM.fire("GOSSIP_SHOW")
    return first .. "|" .. tostring(BG.lastNotice)`).then((r) => r === '¿Unos Huesos en la posada?|nil' || r);
});

await t.check('pantallas: la Taberna sin partida, en partida y la lotería, sin nada fuera de su sitio', async () => {
  return get(peregrino, `
    BG.Bones.game = nil
    if not (BG.window and BG.window:IsShown()) then BG:ToggleWindow() end
    BG:ShowView("arena") SIM.layout(834, 604)
    local f = BG.window.viewFrames.arena
    if f.guide then f.guide:Hide() end
    f.tabs.buttons[5]:Click() SIM.layout(834, 604)
    if not f.tavern:IsShown() or not f.tavern.house:IsShown() then return "no se ve la Taberna" end
    if not f.tavern.rank:GetText():find("Tarek Vientoalto", 1, true) then return "ranking: " .. f.tavern.rank:GetText() end
    if not f.lotto.today:GetText():find("ha salido el", 1, true) then return "lotería: " .. f.lotto.today:GetText() end
    local out = SIM.CheckLayout(f) if #out > 0 then return "sin partida: " .. out[1] end
    f.tavern.house:Click()
    SIM.rolls = { ${THREE_ONES} }
    f.tavern.roll:Click()
    return true`).then(async (r) => {
    if (r !== true) return r;
    await net.advance(1);
    return get(peregrino, `
      local f = BG.window.viewFrames.arena
      f.tavern.row:Step(5) -- (the dice's fall: the simulator has no frame clock)
      SIM.layout(834, 604)
      local shown = 0 for _, d in ipairs(f.tavern.dice) do if d:IsShown() then shown = shown + 1 end end
      if shown ~= 6 then return "dados: " .. shown end
      f.tavern.dice[1]:Click() f.tavern.dice[2]:Click() f.tavern.dice[3]:Click()
      if not f.tavern.turn:GetText():find("valen 1000", 1, true) then return "lo apartado: " .. f.tavern.turn:GetText() end
      local out = SIM.CheckLayout(f) if #out > 0 then return "en partida: " .. out[1] end
      return true`);
  });
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
