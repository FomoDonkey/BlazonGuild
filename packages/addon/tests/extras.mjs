// Entrega 13 (0.24.0): playing with a gamepad (with the game's gamepad interface on, BlazonGuild touches nothing of the
// game's interface, and gives it back at a switch), the in-game self-test (its report and its window), «Ver como
// miembro» (only downwards, the Store keeps the real rank, ten minutes at most) and the API for other addons (nothing
// before the player's yes, read only, no names in the raids, taken back with /bg api).
import { createNetwork, checklist } from './harness.mjs';

const P = {
  tarek: { first: 'Tarek', second: 'Vientoalto', guid: 'Player-6842-SIMA', rosterIndex: 1 }, // Maestro
  peregrino: { first: 'El', second: 'Peregrino', guid: 'Player-6842-0A1B2C3D', rosterIndex: 2 }, // Miembro
};
const net = await createNetwork(Object.values(P));
const [tarek, peregrino] = net.clients;
// Another addon registers before the login, as addons do when they load.
await peregrino.run('OTHER = BlazonGuildAPI.Register("OtroAddon")');
await net.loginAll();
for (const c of net.clients) await c.run('BG.Consent.Accept()');
await net.advance(30, 0.5);
const get = net.get;
const t = checklist('comprobaciones del mando, la autoprueba, la vista por cargo y la API');
const notice = (c) => get(c, 'return BG.lastNotice and (BG.lastNotice.title .. "|" .. (BG.lastNotice.text or "")) or ""');

await t.check('con mando: ni marcas sobre los nombres, ni escudo en el chat, ni el chat del juego, ni el atajo; la ventana sí', async () => {
  const r = await get(peregrino, `
    SIM.inputStyle = 1 SIM.fire("INPUT_DEVICE_INTERFACE_TRANSITION") SIM.advance(0.1)
    SIM.units.nameplate1 = { "Tarek", "Vientoalto" }
    local mark = BG.Marks.Apply("nameplate1")
    local tells = #SIM.tells
    local whisper = BG.Crafts.Whisper("Tarek Vientoalto")
    local keys = 0 for _ in pairs(SIM.overrides) do keys = keys + 1 end
    return tostring(mark) .. "|" .. tostring(whisper) .. "|" .. (#SIM.tells - tells) .. "|" .. keys .. "|" .. tostring(BG.Gamepad.Allowed("window")) .. "|"
      .. tostring(BG.Gamepad.Allowed("nameplates")) .. "|" .. tostring(BG.Gamepad.Allowed("inventado"))`);
  const told = await notice(peregrino);
  return (r === 'nil|false|0|0|true|false|false' && told.startsWith('Con mando')) || `${r}; aviso: ${told}`;
});

await t.check('al volver a ratón y teclado, todo vuelve (y se avisa)', async () => {
  const r = await get(peregrino, `
    SIM.inputStyle = 0 SIM.fire("INPUT_DEVICE_INTERFACE_TRANSITION") SIM.advance(0.1)
    local keys = 0 for _ in pairs(SIM.overrides) do keys = keys + 1 end
    return tostring(BG.Gamepad.Allowed("nameplates")) .. "|" .. keys`);
  const told = await notice(peregrino);
  return (r === 'true|1' && told.startsWith('Ratón y teclado')) || `${r}; aviso: ${told}`;
});

await t.check('autoprueba: dice qué hay en este juego y qué responde, en una ventana que cabe, y lo copia en texto', async () => {
  const r = await get(peregrino, `
    local f = BG.SelfTest.Open() SIM.layout(1920, 1080)
    local lay = table.concat(SIM.CheckLayout(f), " ; ")
    local checks = f.checks
    local n, yes, groups = #checks, 0, {}
    for _, c in ipairs(checks) do if c.ok == true then yes = yes + 1 end groups[c.group] = true end
    local g = 0 for _ in pairs(groups) do g = g + 1 end
    f.copy:Click()
    local text = f.box:GetText()
    return n .. "|" .. g .. "|" .. tostring(yes > 10) .. "|" .. tostring(text:find("Sí ENCOUNTER_END: existe", 1, true) ~= nil) .. "|"
      .. tostring(text:find("Radio del minimapa: 200 metros", 1, true) ~= nil) .. "|" .. lay`);
  return /^\d+\|4\|true\|true\|true\|$/.test(r) || r;
});

await t.check('autoprueba: la prueba de mensajes se completa sola unos segundos después', async () => {
  await net.advance(14, 1);
  const r = await get(peregrino, `for _, c in ipairs(BG.SelfTest.Frame().checks) do if c.label == "Mensajes por la hermandad" then return tostring(c.ok) .. "|" .. c.detail end end return "nada"`);
  return /^true\|vuelven en \d+ ms; 1 respondieron$/.test(r) || r;
});

await t.check('ver como miembro: el maestro ve lo de un miembro, el addon guarda lo suyo y vuelve solo a los 10 minutos', async () => {
  const member = await get(peregrino, 'local ok, w = BG.SetViewAs("member") return tostring(w)');
  if (member !== 'ya') return `un miembro pudo: ${member}`;
  await tarek.run('assert(BG.Chat.OpenCase("El Peregrino", "prueba", {}))');
  await net.advance(3);
  const r = await get(tarek, `assert(BG.SetViewAs("member"))
    local shown = tostring(BG.Store.IsOrganiser("Tarek Vientoalto")) .. tostring(BG.Store.IsMaster("Tarek Vientoalto")) .. tostring(BG.Store.RealOrganiser("Tarek Vientoalto"))
    BG.Store.Gc()
    local cases = #BG.Store.List("cases")
    BG:ToggleWindow() BG:ShowView("admin") SIM.layout(834, 604)
    local f = BG.window.viewFrames.admin
    return shown .. "|" .. cases .. "|" .. f.viewBtn.text:GetText() .. "|" .. table.concat(SIM.CheckLayout(f), " ; ")`);
  if (r !== 'falsefalsetrue|1|Volver a mi vista|') return `en la vista: ${r}`;
  await net.advance(601, 5);
  const back = await get(tarek, 'return tostring(BG.viewAs) .. "|" .. tostring(BG.Store.IsOrganiser("Tarek Vientoalto"))');
  return back === 'nil|true' || `a los 10 minutos: ${back}`;
});

await t.check('API: nada antes del sí; lo pregunta en el diálogo propio; luego lee solo lo que se ve, sin nombres en las raids', async () => {
  const before = await get(peregrino, 'return tostring(OTHER:GetGuild()) .. "|" .. tostring(OTHER:Allowed())');
  const asked = await get(peregrino, 'return BlazonGuildDialog and BlazonGuildDialog:IsShown() and BlazonGuildDialog.title:GetText() or "sin diálogo"');
  if (before !== 'nil|false' || asked !== '«OtroAddon» quiere leer BlazonGuild') return `antes: ${before}; diálogo: ${asked}`;
  await tarek.run('assert(BG.Raids.Save(nil, { inst = "MC", start = time() + 86400, note = "Núcleo" }))');
  await net.advance(4);
  const r = await get(peregrino, `BlazonGuildDialog.primary:Click()
    CALLED = 0 OTHER:On("raids", function() CALLED = CALLED + 1 end)
    local g = OTHER:GetGuild() local me = OTHER:GetMe() local raids = OTHER:GetRaids()
    local keys = {} for k in pairs(raids[1] or {}) do keys[#keys + 1] = k end table.sort(keys)
    return g.name .. "|" .. g.members .. "|" .. me.name .. "|" .. tostring(me.organiser) .. "|" .. #raids .. "|" .. table.concat(keys, ",")
      .. "|" .. type(OTHER:GetArena()) .. type(OTHER:GetWanted()) .. type(OTHER:GetHonors())`);
  if (!/^C A Ñ A D A\|\d+\|El Peregrino\|false\|1\|dps,going,healers,instance,maybe,start,state,tanks,title\|tabletabletable$/.test(r)) return r;
  await tarek.run('assert(BG.Raids.Save(nil, { inst = "ONY", start = time() + 2 * 86400 }))');
  await net.advance(4);
  const called = await get(peregrino, 'return CALLED');
  await peregrino.run('BG.commands.api("quitar otroaddon")');
  const after = await get(peregrino, 'return tostring(OTHER:GetGuild())');
  return (called >= 1 && after === 'nil') || `avisos: ${called}; tras quitarlo: ${after}`;
});

await t.check('en los 6 idiomas: la autoprueba y la fila de Herramientas caben y no dejan español', async () => {
  const bad = [];
  for (const lang of ['en', 'de', 'fr', 'it', 'pt', 'ru']) {
    const r = await get(tarek, `BG.db.settings.lang = "${lang}" BG.Locale.Init()
      local v = BG.window.viewFrames.admin if v then v:Hide() end BG.window.viewFrames.admin = nil
      BG:ShowView("admin") SIM.layout(834, 604)
      local a = BG.window.viewFrames.admin
      local f = BG.SelfTest.Open(true) SIM.layout(1920, 1080)
      return table.concat(SIM.CheckLayout(a), " ; ") .. table.concat(SIM.CheckLayout(f), " ; ") .. " ## " .. f.body:GetText() .. " || " .. a.rows.tools.value:GetText()`);
    const [lay, texts] = r.split(' ## ');
    // ("existe" is French and Portuguese too)
    const spanish = texts.match(lang === 'fr' || lang === 'pt' ? /\b(Versiones|Hermandad|Radio del minimapa|Errores|Herramientas|Comprueba)\b/
      : /\b(Versiones|Hermandad|existe|Radio del minimapa|Errores|Herramientas|Comprueba)\b/);
    if (lay || spanish) bad.push(`${lang}: ${lay} ${spanish ? '«' + spanish[0] + '»' : ''}`);
  }
  await tarek.run('BG.db.settings.lang = "es" BG.Locale.Init()');
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
