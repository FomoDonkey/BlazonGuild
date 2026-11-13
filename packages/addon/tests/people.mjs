// Entrega 3 in a simulated guild: member cards, alts confirmed both ways (and an impostor who is not), the
// away-for-a-while filter, the game's right-click menu and tooltips, the guild key shortcut and the card UI.
import { createNetwork, checklist } from './harness.mjs';

const P = {
  peregrino: { first: 'El', second: 'Peregrino', guid: 'Player-6842-0A1B2C3D', rosterIndex: 2 },
  ceniza: { first: 'Sr', second: 'Ceniza', guid: 'Player-6842-ALT1', rosterIndex: 4 }, // Peregrino's alt (same account)
  rina: { first: 'Rina', second: 'Dagaluna', guid: 'Player-6842-SIMB', rosterIndex: 5 },
  brasa: { first: 'Sr', second: 'Brasa', guid: 'Player-6842-SIMC', rosterIndex: 7 },
};
const net = await createNetwork([P.peregrino, P.ceniza, P.rina, P.brasa]);
const [peregrino, ceniza, rina, brasa] = net.clients;
// The same game account: each of Peregrino's characters already knows the other one (account-wide saved data).
for (const c of [peregrino, ceniza]) {
  await c.run(`
    SIM.fire("ADDON_LOADED", "BlazonGuild")
    BlazonGuildDB.characterInfo = {
      ["Player-6842-0A1B2C3D"] = { name = "El Peregrino", key = "EU|ForeverPvP|ALLIANCE|C A Ñ A D A", class = "PALADIN", level = 24 },
      ["Player-6842-ALT1"] = { name = "Sr Ceniza", key = "EU|ForeverPvP|ALLIANCE|C A Ñ A D A", class = "WARRIOR", level = 10 },
    }`);
}
await net.loginAll();
for (const c of net.clients) await c.run('BG.Consent.Accept()');
await net.advance(30);
const get = net.get;
const t = checklist('comprobaciones de personas, menús y fichas');

await t.check('la ficha que escribe uno la ve toda la hermandad', async () => {
  await peregrino.run('assert(BG.People.Publish({ bio = "Paladín sanador, me gustan las bandas", role = "HEALER", hours = "noches entre semana" }))');
  await net.advance(6);
  const seen = await get(rina, 'local p = BG.People.Profile("El Peregrino") return p and (p.d.bio .. "|" .. p.d.role .. "|" .. p.d.hours) or "nada"');
  return seen === 'Paladín sanador, me gustan las bandas|HEALER|noches entre semana' || seen;
});

await t.check('alters: sin permiso no se comparten; con permiso solo de un lado, tampoco', async () => {
  const none = await get(rina, 'return #BG.People.Profile("El Peregrino").d.chars');
  if (none !== 0) return `sin permiso comparte ${none}`;
  await peregrino.run('BG.Consent.SetLine("alts", true)');
  await net.advance(6);
  const oneSide = await get(rina, 'return table.concat(BG.People.Characters("El Peregrino"), ",")');
  return oneSide === 'El Peregrino' || `con un solo lado: ${oneSide}`;
});

await t.check('alters: confirmados por ambos personajes, con el principal elegido', async () => {
  await ceniza.run('BG.Consent.SetLine("alts", true) assert(BG.People.Publish({ main = "El Peregrino" }))');
  await peregrino.run('assert(BG.People.Publish({ main = "El Peregrino" }))');
  await net.advance(8);
  const chars = await get(rina, 'local c = BG.People.Characters("Sr Ceniza") table.sort(c) return table.concat(c, ",") .. "|" .. BG.People.Main("Sr Ceniza")');
  return chars === 'El Peregrino,Sr Ceniza|El Peregrino' || chars;
});

await t.check('nadie puede declararse alter de otro', async () => {
  await brasa.run(`
    BG.Consent.SetLine("alts", true)
    BlazonGuildDB.characterInfo = { a = { name = "Sr Brasa", key = "EU|ForeverPvP|ALLIANCE|C A Ñ A D A" }, b = { name = "El Peregrino", key = "EU|ForeverPvP|ALLIANCE|C A Ñ A D A" } }
    assert(BG.People.Publish({ main = "El Peregrino" }))`);
  await net.advance(6);
  const chars = await get(rina, 'return table.concat(BG.People.Characters("Sr Brasa"), ",") .. "|" .. BG.People.Main("Sr Brasa")');
  return chars === 'Sr Brasa|Sr Brasa' || chars;
});

await t.check('miembros que llevan tiempo sin entrar: 7, 14 y 30 días', async () => {
  await rina.run('SIM.lastOnline[10] = 9 SIM.lastOnline[11] = 20 SIM.lastOnline[12] = 45 BG.Guild.Scan()');
  const r = await get(rina, `
    local c = BG.People.InactiveCounts(BG.Guild.members)
    local list = BG.People.Inactive(14)
    return c[7] .. "/" .. c[14] .. "/" .. c[30] .. "|" .. #list .. "|" .. math.floor(list[1].lastOnlineDays)`);
  return r === '3/2/1|2|45' || r;
});

await t.check('menú del botón derecho: «Ver su ficha» solo para compañeros, nunca en el roster del juego', async () => {
  const r = await get(rina, `
    local tags = {}
    for tag in pairs(SIM.menus) do tags[#tags + 1] = tag end
    if #tags ~= 9 then return "menús " .. #tags end
    if SIM.menus.MENU_UNIT_COMMUNITIES_GUILD_MEMBER or SIM.menus.MENU_UNIT_GUILD then return "toca el roster del juego" end
    local function build(ctx)
      local lines = {}
      local root = { CreateDivider = function() end, CreateTitle = function(_, t) lines[#lines + 1] = "#" .. t end,
        CreateButton = function(_, t, fn) lines[#lines + 1] = t lines.fn = fn end }
      SIM.menus.MENU_UNIT_FRIEND(nil, root, ctx)
      return lines
    end
    local mate = build({ name = "El", surname = "Peregrino" })
    if mate[2] ~= "Ver su ficha" then return "compañero: " .. table.concat(mate, ",") end
    local stranger = build({ name = "Alguien", surname = "Desconocido" })
    if #stranger ~= 0 then return "desconocido con líneas" end
    if #build({ name = "El", surname = "Peregrino", bnetIDAccount = 7 }) ~= 0 then return "amigo de Battle.net con líneas" end
    SIM.units.target = { "Sr", "Brasa" }
    if BG.Hooks.MenuTarget({ unit = "target" }) ~= "Sr Brasa" then return "por unidad: " .. tostring(BG.Hooks.MenuTarget({ unit = "target" })) end
    mate.fn()
    if not (BG.window and BG.window:IsShown()) then return "no abre la ficha" end
    return true`);
  return r;
});

await t.check('recuadro del jugador: alter, bandera y addon', async () => {
  await ceniza.run('assert(BG.Groups.RaiseFlag("DUNGEON", "WC", "TANK"))');
  await net.advance(5);
  const r = await get(rina, `
    SIM.units.mouseover = { "Sr", "Ceniza" }
    local lines = {}
    local tip = { GetUnit = function() return "Sr", "mouseover" end, AddLine = function(_, l) lines[#lines + 1] = l end }
    GameTooltip = tip
    SIM.tooltipCalls[2](tip)
    return lines[1] or "sin línea"`);
  return r === 'BlazonGuild: alter de El Peregrino, busca grupo para Cuevas de los Lamentos, usa el addon' || r;
});

await t.check('Mayús + tecla de hermandad abre BlazonGuild, sin pisar un atajo del jugador', async () => {
  const set = await get(rina, 'return tostring(SIM.overrides["SHIFT-J"])');
  if (set !== 'BlazonGuildMainKey') return `atajo: ${set}`;
  const kept = await get(brasa, 'SIM.overrides = {} SIM.used["SHIFT-J"] = "MI_MACRO" BG.Hooks.mainKey = nil local ok = BG.Hooks.MainKey() return tostring(ok) .. "|" .. tostring(SIM.overrides["SHIFT-J"])');
  return kept === 'false|nil' || `con atajo ocupado: ${kept}`;
});

await t.check('pantalla de ficha: la de otro (leer) y la propia (editar y guardar)', async () => {
  const r = await get(rina, `
    BG:ToggleWindow() SIM.layout(834, 604)
    BG.UI.ShowProfile("El Peregrino")
    local p = BG.window.content
    local found
    for _, o in ipairs(SIM.objects) do if o.__text == "Paladín sanador, me gustan las bandas" and o.__shown then found = true end end
    if not found then return "no muestra la ficha" end
    return true`);
  if (r !== true) return r;
  const e = await get(peregrino, `
    BG:ToggleWindow() SIM.layout(834, 604)
    BG.UI.ShowProfile("El Peregrino")
    local panel
    for _, o in ipairs(SIM.objects) do if o.editBtn and o.edit then panel = o end end
    if not panel then return "sin panel" end
    if not panel.editBtn:IsShown() then return "sin botón de editar" end
    panel.editBtn:Click()
    if not panel.edit:IsShown() then return "no entra en edición" end
    panel.edit.bio:SetText("Ahora tanque los viernes")
    panel.edit.save:Click()
    local p = BG.People.Profile("El Peregrino")
    if p.d.bio ~= "Ahora tanque los viernes" then return "no guardó: " .. tostring(p.d.bio) end
    if panel.edit:IsShown() then return "sigue en edición" end
    return true`);
  return e;
});

await t.check('La hermandad: filtro de ausentes y clic que abre la ficha', async () => {
  const r = await get(rina, `
    BG:ShowView("roster") SIM.layout(834, 604)
    local f = BG.window.viewFrames.roster
    f.filterSeg:SetValue(14)
    if #f.list.items ~= 2 then return "14+ días: " .. #f.list.items end
    f.filterSeg:SetValue("all")
    if #f.list.items ~= 36 then return "todos: " .. #f.list.items end
    local lay = SIM.CheckLayout(f) if #lay > 0 then return "La hermandad se sale o se monta: " .. lay[1] end
    return true`);
  return r;
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
