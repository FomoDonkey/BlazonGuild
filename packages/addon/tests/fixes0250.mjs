// What Peregrino found playing 0.24.0 (2026-11-13): the Armory needed you to be near (now, far away, it asks the member's
// addon, and every member is asked once about sharing), item links did not go into the orders' box (Shift + click and
// dragging now), the dropdowns of people opened empty (now made when they open, all online in the tavern, and a word
// when there is nobody), and the Huesos table: drawn dice that fall and spin, the dice that score shining, the ones
// kept aside, the turn's steps, buttons that say what they do, and «Cómo se juega».
import { createNetwork, checklist } from './harness.mjs';

const P = {
  tarek: { first: 'Tarek', second: 'Vientoalto', guid: 'Player-6842-SIMA', rosterIndex: 1 }, // Maestro
  peregrino: { first: 'El', second: 'Peregrino', guid: 'Player-6842-0A1B2C3D', rosterIndex: 2 }, // Miembro
};
const net = await createNetwork(Object.values(P));
const [tarek, peregrino] = net.clients;
await net.loginAll();
for (const c of net.clients) await c.run('BG.Consent.Accept()');
await net.advance(30, 0.5);
const get = net.get;
const t = checklist('comprobaciones de lo que vio Peregrino en la 0.24.0');
const notice = (c) => get(c, 'return BG.lastNotice and (BG.lastNotice.title .. "|" .. (BG.lastNotice.text or "")) or ""');
const dialog = (c) => get(c, 'return BlazonGuildDialog and BlazonGuildDialog:IsShown() and BlazonGuildDialog.title:GetText() or "sin diálogo"');

await t.check('Armería desde lejos: se le pregunta a su addon; si dice que sí, su equipo se ve sin estar cerca', async () => {
  await tarek.run('SIM.gear.player = { [1] = 7946, [5] = { 2244, 1897 } } SIM.ilvl[7946] = 60 SIM.ilvl[2244] = 62');
  const r = await get(peregrino, 'local ok, how = BG.Armory.Look("Tarek Vientoalto") return tostring(ok) .. "|" .. tostring(how)');
  if (r !== 'true|asked') return `pedir: ${r}`;
  await net.advance(3);
  const asked = await dialog(tarek);
  if (asked !== 'El Peregrino quiere ver tu equipo') return `a Tarek: ${asked}`;
  await tarek.run('BlazonGuildDialog.primary:Click()');
  await net.advance(6);
  const seen = await get(peregrino, 'local g = BG.Armory.Of("Tarek Vientoalto") return g and (g.source .. "|" .. tostring(g.il)) or "nada"');
  const told = await notice(peregrino);
  const again = await get(peregrino, 'local ok, how = BG.Armory.Look("Tarek Vientoalto") return tostring(how)');
  return (seen.startsWith('shared|') && told.startsWith('Tarek Vientoalto comparte su equipo') && again === 'ya pedido') || `${seen}; ${told}; otra vez: ${again}`;
});

await t.check('Armería: lejos y sin BlazonGuild, explica el límite del juego; cerca, inspecciona', async () => {
  const far = await get(peregrino, 'local ok, how = BG.Armory.Look("Miembro Prueba 7") return tostring(ok) .. "|" .. tostring(how)');
  const near = await get(peregrino, 'SIM.units.target = { "Miembro", "Prueba 7" } local ok, how = BG.Armory.Look("Miembro Prueba 7") SIM.units.target = nil return tostring(ok) .. "|" .. tostring(how)');
  return (far === 'nil|sin addon' && near === 'true|inspect') || `lejos ${far}; cerca ${near}`;
});

await t.check('Armería: a cada personaje se le pregunta una vez si comparte su equipo', async () => {
  await net.advance(70, 2);
  const first = await dialog(peregrino);
  await peregrino.run('if BlazonGuildDialog and BlazonGuildDialog:IsShown() then BlazonGuildDialog:Hide() end SIM.fire("PLAYER_LOGIN")');
  await net.advance(70, 2);
  const second = await dialog(peregrino);
  return (first === '¿Compartes tu equipo?' && second === 'sin diálogo') || `primera vez: ${first}; segunda: ${second}`;
});

const LINK = '|cff0070dd|Hitem:7946::::::::|h[Coraza de prueba]|h|r';
await t.check('encargos: Mayús + clic en un objeto pone su enlace (una vez), y arrastrarlo también', async () => {
  const r = await get(peregrino, `
    if not (BG.window and BG.window:IsShown()) then BG:ToggleWindow() end
    BG:ShowView("crafts") SIM.layout(834, 604)
    local f = BG.window.viewFrames.crafts
    f.orderForm:Open() SIM.layout(834, 604)
    local box = f.orderForm.what.edit
    box:SetFocus()
    SIM.shift = true HandleModifiedItemClick(${JSON.stringify(LINK)}) SIM.shift = false
    local clicked = box:GetText()
    box:SetText("")
    SIM.cursorItem = { id = 7946, link = ${JSON.stringify(LINK)} }
    box:GetScript("OnReceiveDrag")(box)
    local dragged = box:GetText()
    local held = tostring(SIM.cursorItem ~= nil)
    return clicked .. " ## " .. dragged .. " ## " .. held`);
  const [clicked, dragged, held] = r.split(' ## ');
  return (clicked === LINK && dragged === LINK && held === 'false') || r;
});

await t.check('encargos: sin el foco en su campo, o con mando, el enlace no entra', async () => {
  const r = await get(peregrino, `
    local f = BG.window.viewFrames.crafts
    local box = f.orderForm.what.edit
    box:SetText("") box:ClearFocus() SIM.advance(1)
    SIM.shift = true HandleModifiedItemClick(${JSON.stringify(LINK)})
    local unfocused = box:GetText()
    box:SetFocus() SIM.inputStyle = 1
    HandleModifiedItemClick(${JSON.stringify(LINK)}) SIM.shift = false SIM.inputStyle = 0
    return "[" .. unfocused .. "][" .. box:GetText() .. "]"`);
  return r === '[][]' || r;
});

await t.check('listas de personas: la de la velada se hace al abrirla, y si no hay nadie lo dice', async () => {
  const r = await get(peregrino, `
    assert(BG.Tourney.Create({ kind = "NIGHT", title = "Velada" }))
    BG:ShowView("arena") SIM.layout(834, 604)
    local f = BG.window.viewFrames.arena
    f.tabs.buttons[4]:Click() SIM.layout(834, 604)
    f.boutForm:Open()
    f.boutForm.a.pick:SetOptions({})
    f.boutForm.a.pick:Click()
    local m = BlazonGuildPickerMenu
    local n = 0 for _, row in ipairs(m.rows) do if row:IsShown() then n = n + 1 end end
    m:Hide()
    f.boutForm.a:SetText("zzz")
    f.boutForm.a.pick:Click()
    local empty = m.rows[1].text:GetText()
    m:Hide()
    return n .. "|" .. empty`);
  return /^12\|.*Nadie de la hermandad se llama así/.test(r) || r;
});

await t.check('Taberna: la lista para retar sale con todos los conectados; los que no tienen BlazonGuild, sin poder elegirse', async () => {
  const r = await get(peregrino, `
    BG.Bones.game = nil
    local f = BG.window.viewFrames.arena
    f.tabs.buttons[5]:Click() SIM.layout(834, 604)
    local p = f.tavern.rival
    p:Click()
    local m = BlazonGuildPickerMenu
    local out = {}
    for _, o in ipairs(m.options) do out[#out + 1] = o.value .. (o.disabled and "-" or "+") end
    for _, row in ipairs(m.rows) do if row.option and row.option.disabled then row:Click() break end end
    local chosen = tostring(p:GetValue())
    m:Hide()
    return table.concat(out, ",") .. "|" .. chosen`);
  return r === 'Tarek Vientoalto+|nil' || r;
});

await t.check('Huesos: la mesa con dados, los que puntúan brillan, lo guardado aparte, los pasos y botones claros', async () => {
  const r = await get(peregrino, `
    local f = BG.window.viewFrames.arena
    local t = f.tavern
    t.rules0:Click()
    local rules = BlazonGuildDialog.title:GetText() BlazonGuildDialog:Hide()
    t.house:Click() SIM.layout(834, 604)
    local first = t.roll.text:GetText()
    SIM.rolls = { 17713 } -- (1 1 1 5 2 3: the dice are the digits in base 6, the first one the lowest)
    t.roll:Click()
    return rules .. "|" .. first`);
  const [rules, first] = r.split('|');
  if (rules !== 'Cómo se juega a los Huesos' || first !== 'Tirar 6 dados') return r;
  await net.advance(1);
  const r2 = await get(peregrino, `
    local f = BG.window.viewFrames.arena
    local t = f.tavern
    t.row:Step(5) SIM.layout(834, 604)
    local g = BG.Bones.game
    local looks = {}
    for i = 1, 6 do looks[i] = g.dice[i] .. ":" .. tostring(t.dice[i].look) end
    t.dice[1]:Click() t.dice[2]:Click() t.dice[3]:Click() SIM.layout(834, 604)
    local lay = table.concat(SIM.CheckLayout(f), " ; ")
    return table.concat(looks, ",") .. "|" .. t.roll.text:GetText() .. "|" .. t.bank.text:GetText() .. "|" .. tostring(t.steps[3]:GetText():find("»", 1, true) ~= nil) .. "|" .. lay`);
  // (the throw: 1 1 1 5 2 3: the three 1s and the 5 shine)
  if (!/^1:hint,1:hint,1:hint,5:hint,[2-6]:dim,[2-6]:dim\|Guardar y tirar 3\|Plantarme \(\+1000\)\|true\|$/.test(r2)) return `en partida: ${r2}`;
  const r3 = await get(peregrino, `
    local f = BG.window.viewFrames.arena
    local t = f.tavern
    t.roll:Click() SIM.layout(834, 604)
    local shown = 0 for _, d in ipairs(t.tray) do if d:IsShown() then shown = shown + 1 end end
    return shown .. "|" .. t.roll.text:GetText()`);
  return r3 === '3|Tirar 3 dados' || `guardados: ${r3}`;
});

await t.check('Huesos: «¡huesos!» se ve en la mesa (los dados y el aviso) y la pantalla cabe en los 6 idiomas', async () => {
  const r = await get(peregrino, `
    local f = BG.window.viewFrames.arena
    local t = f.tavern
    SIM.rolls = { 122 } -- (2 3 4: nothing scores)
    t.roll:Click()`);
  await net.advance(1);
  const farkle = await get(peregrino, `
    local t = BG.window.viewFrames.arena.tavern
    t.row:Step(5) SIM.layout(834, 604)
    return t.banner:GetText()`);
  if (!farkle.includes('¡Huesos! Pierdes 1000 puntos.')) return `huesos: ${farkle}`;
  const bad = [];
  for (const lang of ['en', 'de', 'fr', 'it', 'pt', 'ru']) {
    const lay = await get(peregrino, `BG.db.settings.lang = "${lang}" BG.Locale.Init()
      local v = BG.window.viewFrames.arena if v then v:Hide() end BG.window.viewFrames.arena = nil
      BG:ShowView("arena") SIM.layout(834, 604)
      local f = BG.window.viewFrames.arena
      if f.guide then f.guide:Hide() end
      f.tabs.buttons[5]:Click() SIM.layout(834, 604)
      f.tavern.row:Step(5) SIM.layout(834, 604) -- (a throw in the air may cross dice: the check is on the table at rest)
      return table.concat(SIM.CheckLayout(f), " ; ") .. " ## " .. f.tavern.warn:GetText() .. " || " .. f.tavern.steps[2]:GetText()`);
    const [l, texts] = lay.split(' ## ');
    if (l || /Pulsa los que brillan|ningún dado/.test(texts)) bad.push(`${lang}: ${l} ${texts}`);
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
