// Torneos y veladas (entrega 12, segunda parte): anyone creates one; members enter; whoever runs it draws (the best
// of the Arena as seeds, the rest by the game's /roll); the duels decide the matches (only once both are known: a
// duel before does not count); the champion is announced; a fight night with announced bouts; deciding by hand;
// who may do what; and the screens (list, detail, forms, bracket).
import { createNetwork, checklist } from './harness.mjs';

const P = {
  tarek: { first: 'Tarek', second: 'Vientoalto', guid: 'Player-6842-SIMA', rosterIndex: 1 }, // Maestro
  bruno: { first: 'Bruno', second: 'Hierrosol', guid: 'Player-6842-SIMD', rosterIndex: 3 }, // Oficial
  peregrino: { first: 'El', second: 'Peregrino', guid: 'Player-6842-0A1B2C3D', rosterIndex: 2 }, // Miembro
  rina: { first: 'Rina', second: 'Dagaluna', guid: 'Player-6842-SIMB', rosterIndex: 5 }, // Miembro
};
const net = await createNetwork([P.tarek, P.bruno, P.peregrino, P.rina]);
const [tarek, bruno, peregrino, rina] = net.clients;
await net.loginAll();
for (const c of net.clients) await c.run('BG.Consent.Accept()');
await net.advance(20, 0.5);
const get = net.get;
const t = checklist('comprobaciones de los torneos');
const notice = (c) => get(c, 'return BG.lastNotice and (BG.lastNotice.title .. "|" .. (BG.lastNotice.text or "")) or ""');
const PER = 'Tarek Vientoalto', BEN = 'Bruno Hierrosol', EDG = 'El Peregrino', RIT = 'Rina Dagaluna';
const duel = async (w, l) => {
  for (const c of net.clients) await c.run(`SIM.fire("CHAT_MSG_SYSTEM", ${JSON.stringify(`${w} has defeated ${l} in a duel`)})`);
  await net.advance(3);
};

// Before the tournament: Tarek beats Bruno (the two of them are rated: the seeds).
await duel(PER, BEN);
let cup;

await t.check('cualquiera crea un torneo; los demás se apuntan y se pueden borrar', async () => {
  cup = await get(peregrino, 'local r = assert(BG.Tourney.Create({ kind = "CUP", title = "Torneo del viernes", when = "viernes 22:00", size = 4 })) return r.id');
  await net.advance(3);
  for (const c of [tarek, bruno, peregrino, rina]) await c.run(`assert(BG.Tourney.Enter(${JSON.stringify(cup)}))`);
  await net.advance(4);
  const r = await get(tarek, `return table.concat(BG.Tourney.Entries(${JSON.stringify(cup)}), ",")`);
  if (r !== 'Bruno Hierrosol,El Peregrino,Rina Dagaluna,Tarek Vientoalto') return `apuntados: ${r}`;
  const full = await get(bruno, `BG.Tourney.Leave(${JSON.stringify(cup)})`).then(() => net.advance(3))
    .then(() => get(bruno, `return #BG.Tourney.Entries(${JSON.stringify(cup)})`));
  await bruno.run(`assert(BG.Tourney.Enter(${JSON.stringify(cup)}))`);
  await net.advance(3);
  return full === 3 || `al borrarse: ${full}`;
});

await t.check('sortear: los mejores de la Arena son cabezas de serie y el resto sale del /roll del juego; un miembro no puede', async () => {
  const member = await get(rina, `local r, w = BG.Tourney.Draw(${JSON.stringify(cup)}) return tostring(w)`);
  if (member !== 'permiso') return `un miembro sorteó: ${member}`;
  await peregrino.run(`SIM.rolls = { 2 } assert(BG.Tourney.Draw(${JSON.stringify(cup)}))`);
  await net.advance(6, 0.25);
  const r = await get(bruno, `local t = BG.Tourney.Get(${JSON.stringify(cup)})
    return t.d.state .. "|" .. table.concat(t.d.order, ",") .. "|" .. table.concat(t.d.rolls, ",") .. "|" .. t.d.seeds`);
  const asked = await get(peregrino, 'return table.concat(SIM.rollsAsked, ",")');
  const late = await get(rina, `local r, w = BG.Tourney.Leave(${JSON.stringify(cup)}) return tostring(w)`);
  if (asked !== '1-2') return `tiradas pedidas: ${asked}`;
  if (late !== 'cerrado') return `borrarse tras el sorteo: ${late}`;
  return r === 'RUNNING|Tarek Vientoalto,Bruno Hierrosol,Rina Dagaluna,El Peregrino|2|2' || r;
});

await t.check('el cuadro: 1 contra 4 y 2 contra 3', async () => {
  const r = await get(rina, `local b = BG.Tourney.Bracket(BG.Tourney.Get(${JSON.stringify(cup)}))
    local m = b.matches return b.rounds .. "|" .. m[1][1].a .. " v " .. m[1][1].b .. "|" .. m[1][2].a .. " v " .. m[1][2].b .. "|" .. tostring(m[2][1].a)`);
  return r === '2|Tarek Vientoalto v El Peregrino|Bruno Hierrosol v Rina Dagaluna|nil' || r;
});

await t.check('los duelos deciden los combates (y se avisa a todos); uno de antes de tiempo no cuenta', async () => {
  await duel(RIT, BEN); // semifinal 2
  const passed = await notice(tarek);
  if (!passed.startsWith('Torneo del viernes: Rina Dagaluna pasa|Gana a Bruno Hierrosol y pasa a final')) return `aviso: ${passed}`;
  await duel(RIT, PER); // (Tarek has not won his semifinal yet: this does not decide the final)
  await duel(PER, EDG); // semifinal 1
  const mid = await get(bruno, `local b = BG.Tourney.Bracket(BG.Tourney.Get(${JSON.stringify(cup)})) local f = b.matches[2][1]
    return f.a .. " v " .. f.b .. "|" .. tostring(f.winner)`);
  if (mid !== 'Tarek Vientoalto v Rina Dagaluna|nil') return `final antes de tiempo: ${mid}`;
  await duel(PER, RIT); // final
  const champ = await notice(peregrino);
  const r = await get(bruno, `return tostring(BG.Tourney.Champion(BG.Tourney.Get(${JSON.stringify(cup)})))`);
  return (r === PER && champ.startsWith('¡Tarek Vientoalto gana «Torneo del viernes»!')) || `${r}; aviso: ${champ}`;
});

let night;
await t.check('velada: combates anunciados que decide su duelo; un oficial decide uno a mano; un miembro no puede', async () => {
  night = await get(rina, 'local r = assert(BG.Tourney.Create({ kind = "NIGHT", title = "Velada de Ventormenta" })) return r.id');
  await net.advance(3);
  const bad = await get(rina, `local r, w, x = BG.Tourney.AddBout(${JSON.stringify(night)}, "Bruno Hierrosol", "Nadie Existe") return tostring(w) .. ":" .. tostring(x)`);
  if (bad !== 'no es de tu hermandad:Nadie Existe') return `nombre malo: ${bad}`;
  await rina.run(`assert(BG.Tourney.AddBout(${JSON.stringify(night)}, "Bruno Hierrosol", "El Peregrino"))
    assert(BG.Tourney.AddBout(${JSON.stringify(night)}, "Tarek Vientoalto", "Rina Dagaluna"))
    assert(BG.Tourney.StartNight(${JSON.stringify(night)}))`);
  await net.advance(3);
  await duel(EDG, BEN);
  const member = await get(peregrino, `local r, w = BG.Tourney.Decide(${JSON.stringify(night)}, "0.2", "Rina Dagaluna") return tostring(w)`);
  if (member !== 'permiso') return `un miembro decidió: ${member}`;
  await bruno.run(`assert(BG.Tourney.Decide(${JSON.stringify(night)}, "0.2", "Tarek Vientoalto"))`);
  await net.advance(3);
  const r = await get(tarek, `local o = BG.Tourney.Bouts(BG.Tourney.Get(${JSON.stringify(night)}))
    return o[1].winner .. ":" .. o[1].method .. "|" .. o[2].winner .. ":" .. o[2].method`);
  return r === 'El Peregrino:K|Tarek Vientoalto:W' || r;
});

await t.check('pantallas: la lista, el detalle con sus botones, los formularios y el cuadro, sin nada fuera de su sitio', async () => {
  return get(peregrino, `
    if not (BG.window and BG.window:IsShown()) then BG:ToggleWindow() end
    BG:ShowView("arena") SIM.layout(834, 604)
    local f = BG.window.viewFrames.arena
    if f.guide then f.guide:Hide() end
    f.tabs.buttons[4]:Click() SIM.layout(834, 604)
    if #f.cups.items ~= 2 then return "torneos: " .. #f.cups.items end
    f.tsel = ${JSON.stringify(cup)} BG:RefreshView("arena") SIM.layout(834, 604)
    if not f.cupBtns[1]:IsShown() or f.cupBtns[1].text:GetText() ~= "Ver cuadro" then return "botón: " .. tostring(f.cupBtns[1].text:GetText()) end
    local out = SIM.CheckLayout(f) if #out > 0 then return "torneo: " .. out[1] end
    f.cupBtns[1]:Click() SIM.layout(834, 604)
    local br = f.bracket
    if not br:IsShown() then return "no se abre el cuadro" end
    local shown = 0 for _, b in ipairs(br.boxes) do if b:IsShown() then shown = shown + 1 end end
    if shown ~= 3 then return "combates en el cuadro: " .. shown end
    out = SIM.CheckLayout(f) if #out > 0 then return "cuadro: " .. out[1] end
    br.back:Click()
    f.tsel = ${JSON.stringify(night)} BG:RefreshView("arena") SIM.layout(834, 604)
    if not f.cupInfo:GetText():find("gana El Peregrino", 1, true) then return "velada: " .. f.cupInfo:GetText() end
    out = SIM.CheckLayout(f) if #out > 0 then return "velada: " .. out[1] end
    f.cupForm:Open() SIM.layout(834, 604)
    out = SIM.CheckLayout(f) if #out > 0 then return "formulario: " .. out[1] end
    f.cupForm.back:Click()
    f.boutForm:Open() SIM.layout(834, 604)
    out = SIM.CheckLayout(f) if #out > 0 then return "combate: " .. out[1] end
    -- the members in a list, alphabetically; typing narrows it; choosing fills the box
    local opts = f.boutForm.a.pick.options
    if #opts ~= #BG.Guild.members then return "en la lista: " .. #opts .. " de " .. #BG.Guild.members end
    for i = 2, #opts do if opts[i - 1].value > opts[i].value then return "sin orden: " .. opts[i - 1].value .. " antes de " .. opts[i].value end end
    f.boutForm.a.edit:SetText("hierr")
    f.boutForm.a.edit:GetScript("OnTextChanged")(f.boutForm.a.edit)
    opts = f.boutForm.a.pick.options
    if #opts ~= 1 or opts[1].value ~= "Bruno Hierrosol" then return "al escribir «hierr»: " .. #opts end
    f.boutForm.a.pick:SetValue("Bruno Hierrosol")
    f.boutForm.b.pick:SetValue("El Peregrino")
    if f.boutForm.a:GetText() ~= "Bruno Hierrosol" then return "la caja: " .. f.boutForm.a:GetText() end
    f.boutForm.back:Click()
    return true`);
});

await t.check('un torneo de 16 se ve entero en el cuadro', async () => {
  return get(tarek, `
    local s = BG.Guild.Entry().store
    local id = assert(BG.Tourney.Create({ kind = "CUP", title = "Gran torneo", size = 16 })).id
    local order = {}
    for i = 1, 13 do order[i] = "Miembro Prueba " .. (i + 5) end
    local t = BG.Tourney.Get(id)
    t.d.state, t.d.order, t.d.startedAt = "RUNNING", order, time()
    if not (BG.window and BG.window:IsShown()) then BG:ToggleWindow() end
    BG:ShowView("arena") SIM.layout(834, 604)
    local f = BG.window.viewFrames.arena
    f.bracket = f.bracket or BG.UI.Bracket(f)
    f.bracket:Open(id) SIM.layout(834, 604)
    local shown = 0 for _, b in ipairs(f.bracket.boxes) do if b:IsShown() then shown = shown + 1 end end
    if shown ~= 15 then return "combates: " .. shown end
    local area = SIM.Rect(f.bracket.area)
    for _, b in ipairs(f.bracket.boxes) do
      local r = SIM.Rect(b)
      if r.b > area.b + 1 or r.r > area.r + 1 then return "un combate se sale del cuadro" end
    end
    local out = SIM.CheckLayout(f)
    return #out == 0 or out[1]`);
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
