// Reclutamiento (entrega 10): the guild's public card (organisers), a player with no guild who searches the guild
// with /who, sees its card and asks to join, the organisers' tray (invite with the game's own invite, or no), who
// brought whom, bringing your card from another guild, and the screens.
import { createNetwork, checklist } from './harness.mjs';

const P = {
  tarek: { first: 'Tarek', second: 'Vientoalto', guid: 'Player-6842-SIMA', rosterIndex: 1 }, // Maestro
  bruno: { first: 'Bruno', second: 'Hierrosol', guid: 'Player-6842-SIMD', rosterIndex: 3 }, // Oficial
  peregrino: { first: 'El', second: 'Peregrino', guid: 'Player-6842-0A1B2C3D', rosterIndex: 2 }, // Miembro
  nora: { first: 'Nora', second: 'Sinhogar', guid: 'Player-6842-NORA', rosterIndex: 9, noGuild: true }, // Sin hermandad
};
const net = await createNetwork([P.tarek, P.bruno, P.peregrino, P.nora]);
const [tarek, bruno, peregrino, nora] = net.clients;
await net.loginAll();
for (const c of net.clients) await c.run('BG.Consent.Accept()');
await net.advance(20, 0.5);
const get = net.get;
const t = checklist('comprobaciones del reclutamiento');
const notice = (c) => get(c, 'return BG.lastNotice and (BG.lastNotice.title .. "|" .. (BG.lastNotice.text or "")) or ""');

await t.check('la ficha pública la escriben los oficiales y la ve toda la hermandad', async () => {
  const denied = await get(peregrino, 'local r, why = BG.Recruit.SaveCharter({ open = true }) return tostring(why)');
  if (denied !== 'permiso') return `un miembro la escribió: ${denied}`;
  await bruno.run(`assert(BG.Recruit.SaveCharter({ open = true, about = "Hermandad española de raids y JcJ", lang = "Español", days = "miércoles y domingos, 21:00",
    roles = { HEALER = true }, classes = { "PRIEST", "DRUID" }, contact = "Bruno Hierrosol" }))`);
  await net.advance(4);
  const r = await get(peregrino, 'local c = BG.Recruit.Charter() return tostring(c.open) .. "|" .. c.days .. "|" .. BG.Recruit.WantsText(c)');
  return r === 'true|miércoles y domingos, 21:00|Buscamos sanadores; sobre todo Sacerdote, Druida.' || r;
});

await t.check('sin hermandad: la ventana abre en «Únete», y la búsqueda con /who encuentra a los suyos', async () => {
  const first = await get(nora, `BG:ToggleWindow() SIM.layout(834, 604)
    return BG.db.settings.lastView .. "|" .. BG.window.viewFrames.recruit.hero.title:GetText()`);
  if (first !== 'recruit|Únete a una hermandad') return `al abrir: ${first}`;
  await nora.run(`SIM.who = { { fullName = "El Peregrino", fullGuildName = "C A Ñ A D A", level = 24, filename = "PALADIN" },
    { fullName = "Otro Cualquiera", fullGuildName = "Los Otros", level = 30, filename = "MAGE" } }
    assert(BG.Recruit.Search("C A Ñ A D A"))`);
  const soon = await get(nora, 'local r, why = BG.Recruit.Search("C A Ñ A D A") return tostring(why)');
  if (soon !== 'espera') return `dos búsquedas seguidas: ${soon}`;
  await net.advance(2);
  const found = await get(nora, 'local o = {} for _, w in ipairs(BG.Recruit.found) do o[#o+1] = w.name end return table.concat(o, ",") .. "|" .. SIM.whoSent[1]');
  return found === 'El Peregrino|g-"C A Ñ A D A"' || found;
});

await t.check('ve la ficha preguntando a un miembro con el addon', async () => {
  await nora.run('BG.Recruit.AskCard("El Peregrino")');
  await net.advance(4);
  const card = await get(nora, 'local c = BG.Recruit.card if not c then return "sin ficha" end return c.guild .. "|" .. c.charter.about .. "|" .. table.concat(c.contacts, ",")');
  return card.startsWith('C A Ñ A D A|Hermandad española de raids y JcJ|Bruno Hierrosol') || card;
});

await t.check('pide entrar: los oficiales lo ven con «Invitar»; un miembro no puede invitar', async () => {
  await nora.run('assert(BG.Recruit.AskToJoin("Soy sacerdote, me gusta curar"))');
  await net.advance(6);
  const toNora = await notice(nora);
  if (!toNora.startsWith('Petición entregada')) return `a Nora: ${toNora}`;
  const toOrg = await notice(tarek);
  if (!toOrg.startsWith('Quiere entrar en la hermandad')) return `a Tarek: ${toOrg}`;
  const tray = await get(tarek, 'local r = BG.Recruit.Requests()[1] return r and (r.name .. "|" .. r.level .. "|" .. r.note) or "vacía"');
  if (tray !== 'Nora Sinhogar|24|Soy sacerdote, me gusta curar') return `bandeja: ${tray}`;
  const member = await get(peregrino, 'local r, why = BG.Recruit.Answer("Nora Sinhogar", true) return tostring(why)');
  if (member !== 'permiso') return `un miembro invitó: ${member}`;
  await tarek.run('assert(BG.Recruit.Answer("Nora Sinhogar", true))');
  await net.advance(4);
  const inv = await get(tarek, 'return SIM.guildInvites and SIM.guildInvites[1] or "nada"');
  const cleared = await get(bruno, 'return #BG.Recruit.Requests()');
  return (inv === 'Nora Sinhogar' && cleared === 0) || `invitación ${inv}; bandeja de Bruno ${cleared}`;
});

await t.check('un «no» le llega educado', async () => {
  await net.advance(6);
  await nora.run('BG.Recruit.AskToJoin("Otra vez")');
  await net.advance(6);
  await bruno.run('assert(BG.Recruit.Answer("Nora Sinhogar", false))');
  await net.advance(4);
  const r = await notice(nora);
  return r.startsWith('Ahora no') || r;
});

await t.check('quién te trajo: cada uno lo dice, y sale quién trae más gente', async () => {
  const self = await get(peregrino, 'local r, why = BG.Recruit.SetBroughtBy("El Peregrino") return tostring(why)');
  if (self !== 'tú mismo') return `a sí mismo: ${self}`;
  const nobody = await get(peregrino, 'local r, why = BG.Recruit.SetBroughtBy("Nadie Existe") return tostring(why)');
  if (nobody !== 'no es de tu hermandad') return `a alguien de fuera: ${nobody}`;
  await peregrino.run('assert(BG.Recruit.SetBroughtBy("Bruno Hierrosol"))');
  await net.advance(4);
  const r = await get(tarek, 'local r = BG.Recruit.Recruiters()[1] return r and (r.name .. ":" .. r.n) or "nadie"');
  return r === 'Bruno Hierrosol:1' || r;
});

await t.check('si cambias de hermandad, te traes tu ficha', async () => {
  const r = await get(peregrino, `
    BG.db.guilds["EU|Los Otros"] = { store = { profiles = { ["El Peregrino"] = { id = "El Peregrino", at = 10, rev = 1, by = "El Peregrino", d = { bio = "Pala sanador", role = "HEALER", hours = "tardes", chars = {} } } } } }
    local p = BG.Store.Get("profiles", "El Peregrino") if p then BG.Store.Delete("profiles", "El Peregrino") end
    local old = BG.Recruit.CardElsewhere()
    if not old then return "no ve su ficha de la otra hermandad" end
    assert(BG.Recruit.BringCard())
    local now = BG.People.Profile("El Peregrino")
    return old.guild .. "|" .. (now and now.d.bio or "sin ficha")`);
  return r === 'Los Otros|Pala sanador' || r;
});

await t.check('pantallas: «Únete», la ficha, la bandeja, el formulario, y nada se sale ni se monta', async () => {
  const n = await get(nora, `
    BG:ShowView("recruit") SIM.layout(834, 604)
    local f = BG.window.viewFrames.recruit
    if f.guide then f.guide:Hide() end
    if not f.searchPlate:IsShown() or f.minePlate:IsShown() then return "sin hermandad no ve «Únete»" end
    if not f.cardText:GetText():find("Hermandad española", 1, true) then return "ficha: " .. f.cardText:GetText() end
    local out = SIM.CheckLayout(f) if #out > 0 then return "únete: " .. out[1] end
    return true`);
  if (n !== true) return n;
  await nora.run('BG.Recruit.AskToJoin("Una vez más")');
  await net.advance(6);
  return get(tarek, `
    BG:ToggleWindow() SIM.layout(834, 604) BG:ShowView("recruit") SIM.layout(834, 604)
    local f = BG.window.viewFrames.recruit
    if f.guide then f.guide:Hide() end
    if not f.minePlate:IsShown() then return "no ve la ficha" end
    if #f.requests.items ~= 1 then return "bandeja: " .. #f.requests.items end
    if not f.recruiters:GetText():find("Bruno Hierrosol", 1, true) then return "reclutadores: " .. f.recruiters:GetText() end
    local out = SIM.CheckLayout(f) if #out > 0 then return "reclutamiento: " .. out[1] end
    f.edit:Click()
    out = SIM.CheckLayout(f) if #out > 0 then return "formulario: " .. out[1] end
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
