// What the author saw on 2026-11-18 in the game's addon list: «Las acciones de interfaz han fallado debido a este add-on: 3»,
// and guildmates who installed BlazonGuild and did not know how to open it. Here, with the stubs as strict as the game
// in combat (the target frame and the nameplates protected, ADDON_ACTION_BLOCKED fired for each refused call): the
// marks only show and hide textures in a fight, what a fight keeps from being made is made when it ends, nothing on
// any screen is refused in combat, every refusal is kept with where it came from, and a new install says how to
// open it.
import { createNetwork, checklist } from './harness.mjs';

const P = {
  tarek: { first: 'Tarek', second: 'Vientoalto', guid: 'Player-6842-SIMA', rosterIndex: 1 },
  peregrino: { first: 'El', second: 'Peregrino', guid: 'Player-6842-0A1B2C3D', rosterIndex: 2 },
  bruno: { first: 'Bruno', second: 'Hierrosol', guid: 'Player-6842-SIMB', rosterIndex: 3 }, // installs it today
};
const net = await createNetwork(Object.values(P));
const [tarek, peregrino, bruno] = net.clients;
await net.loginAll();
for (const c of [tarek, peregrino]) await c.run('BG.Consent.Accept()');
await net.advance(30, 0.5);
const get = net.get;
const t = checklist('comprobaciones de las acciones bloqueadas y de la bienvenida');

// A wanted foe and an honoured member for the marks, without a whole hunt (Wanted and Honors have their own tests).
await peregrino.run(`
  local foe, honored = BG.Wanted.Foe, BG.Honors.Honored
  BG.Wanted.Foe = function(n) if n == "Grosh Rompehuesos" then return { bounty = 5 } end return foe(n) end
  BG.Honors.Honored = function(n) return n == "Tarek Vientoalto" or honored(n) end`);

await t.check('el simulador bloquea lo que bloquea el juego: la marca de la 0.29.2 (un marco en la placa) en combate', async () => {
  const r = await get(peregrino, `
    SIM.blocked = {}
    SIM.combat = true
    local plate = C_NamePlate.GetNamePlateForUnit("nameplate9")
    local m = CreateFrame("Frame", nil, plate)
    m:SetSize(24, 24) m:SetPoint("BOTTOM", plate, "TOP", 0, -4) m:Hide() m:Show()
    local tex = m:CreateTexture(nil, "OVERLAY")
    SIM.combat = false
    return table.concat(SIM.blocked, ",") .. "|" .. tostring(tex)`);
  return r === 'Frame:SetSize(),Frame:SetPoint(),Frame:Hide(),Frame:Show(),Frame:CreateTexture()|nil' || r;
});

await t.check('en combate, la marca de un compañero que aparece no toca su placa; sale al acabar el combate', async () => {
  const r = await get(peregrino, `
    SIM.blocked = {}
    SIM.combat = true
    SIM.units.nameplate1 = { "Miembro", "Prueba 5" }
    SIM.fire("NAME_PLATE_UNIT_ADDED", "nameplate1")
    local during = tostring(BG.Marks.Shown("nameplate1"))
    SIM.combat = false
    SIM.fire("PLAYER_REGEN_ENABLED")
    return #SIM.blocked .. "|" .. during .. "|" .. tostring(BG.Marks.Shown("nameplate1"))`);
  return r === '0|nil|member' || r;
});

await t.check('ya hecha, en combate solo se enciende y se apaga: buscado, honrado, nadie, sin un solo bloqueo', async () => {
  const r = await get(peregrino, `
    SIM.blocked = {}
    SIM.combat = true
    local seen = {}
    for _, who in ipairs({ { "Grosh", "Rompehuesos" }, { "Tarek", "Vientoalto" }, { "Paseante", "Cualquiera" }, { "Miembro", "Prueba 5" } }) do
      SIM.fire("NAME_PLATE_UNIT_REMOVED", "nameplate1")
      SIM.units.nameplate1 = who
      SIM.fire("NAME_PLATE_UNIT_ADDED", "nameplate1")
      seen[#seen + 1] = tostring(BG.Marks.Shown("nameplate1"))
    end
    SIM.combat = false
    return #SIM.blocked .. "|" .. table.concat(seen, ",")`);
  return r === '0|wanted,honored,nil,member' || r;
});

await t.check('aro del retrato: en combate no toca el marco del objetivo; sale al acabar, y luego cada cambio solo enciende o apaga', async () => {
  const r = await get(peregrino, `
    SIM.blocked = {}
    SIM.combat = true
    local seen = {}
    SIM.units.target = { "Tarek", "Vientoalto" }
    SIM.fire("PLAYER_TARGET_CHANGED")
    seen[#seen + 1] = tostring(BG.Marks.TargetShown())
    SIM.combat = false
    SIM.fire("PLAYER_REGEN_ENABLED")
    seen[#seen + 1] = tostring(BG.Marks.TargetShown())
    SIM.combat = true
    for _, who in ipairs({ { "Grosh", "Rompehuesos" }, { "Miembro", "Prueba 5" }, { "Tarek", "Vientoalto" } }) do
      SIM.units.target = who
      SIM.fire("PLAYER_TARGET_CHANGED")
      seen[#seen + 1] = tostring(BG.Marks.TargetShown())
    end
    SIM.units.target = nil
    SIM.fire("PLAYER_TARGET_CHANGED")
    seen[#seen + 1] = tostring(BG.Marks.TargetShown())
    SIM.combat = false
    return #SIM.blocked .. "|" .. table.concat(seen, ",")`);
  return r === '0|nil,gold,red,nil,gold,nil' || r;
});

await t.check('en combate, abrir la ventana y cada pantalla no hace nada que el juego bloquee', async () => {
  const r = await get(peregrino, `
    SIM.blocked = {}
    SIM.combat = true
    if not (BG.window and BG.window:IsShown()) then BG:ToggleWindow() end
    local names = {}
    for key in pairs(BG.views) do names[#names + 1] = key end
    table.sort(names)
    for _, key in ipairs(names) do BG:ShowView(key) end
    SIM.layout(834, 604)
    BG:ToggleWindow()
    SIM.combat = false
    return #names .. "|" .. table.concat(SIM.blocked, ",")`);
  const [n, blocked] = r.split('|');
  return (Number(n) > 15 && blocked === '') || r;
});

// A player's game with 0.29.3 (2026-11-21): «UNKNOWN() IN_COMBAT < Data/Guild.lua:249 < Data/Guild.lua:315», 317 times,
// and «BlazonGuild ha registrado un error interno» in chat on both of their PCs. The roster scan asked for the message of
// the day on every update of the guild list, and in combat the game refuses it. Without the MOTD the scan also saw
// «something changed» each time and rebuilt and repainted the guild in every fight.
await t.check('en combate, la hermandad se pone al día sin pedir el mensaje del día (el juego lo bloquea); se lee al acabar el combate', async () => {
  const r = await get(peregrino, `
    SIM.advance(1)
    local before = tostring(BG.Guild.info and BG.Guild.info.motd)
    SIM.blocked = {}
    BG.db.errors = {}
    __told = 0
    if not __toldHooked then __toldHooked = true BG:On("BG_ROSTER_UPDATED", function() __told = __told + 1 end) end
    SIM.combat = true
    SIM.motd = "Banda el sábado a las 22:00"
    for _ = 1, 5 do SIM.fire("GUILD_ROSTER_UPDATE") SIM.advance(1) end
    local idle, during = __told, tostring(BG.Guild.info.motd)
    local row = SIM.roster[#SIM.roster]
    local wasOn = row[9]
    row[9] = not wasOn
    SIM.fire("GUILD_ROSTER_UPDATE") SIM.advance(1)
    local m = BG.Guild.byGuid[row[17]]
    local seen = tostring(m ~= nil and m.online == (not wasOn))
    row[9] = wasOn
    SIM.fire("GUILD_ROSTER_UPDATE") SIM.advance(1)
    SIM.combat = false
    SIM.fire("PLAYER_REGEN_ENABLED")
    SIM.advance(1)
    local after = tostring(BG.Guild.info.motd)
    SIM.motd = "Raid el viernes a las 21:00"
    SIM.fire("GUILD_ROSTER_UPDATE") SIM.advance(1)
    return table.concat({ #SIM.blocked, #BG.db.errors, before, during, idle, seen, after }, "|")`);
  return r === '0|0|Raid el viernes a las 21:00|Raid el viernes a las 21:00|0|true|Banda el sábado a las 22:00' || r;
});

await t.check('lo que el juego bloquea queda en «Errores internos»: qué función, si era en combate y de qué línea; repetido, se cuenta', async () => {
  const r = await get(peregrino, `
    BG.db.errors = {}
    SIM.fire("ADDON_ACTION_BLOCKED", "OtroAddon", "CastSpellByName()")
    local others = #BG.db.errors
    -- a real refusal from our code: a notice shown while everything is (for this check) a protected frame
    UIParent.__protected = true
    SIM.combat = true
    pcall(BG.Notify, BG, "Prueba", "texto")
    SIM.combat = false
    UIParent.__protected = nil
    local fromNotice
    for _, e in ipairs(BG.db.errors) do
      if e.where == "acción bloqueada por el juego" and e.error:find("^Frame:%a+%(%) IN_COMBAT < UI/") and e.error:find("UI/Showcase.lua:%d+") then fromNotice = e.error end
    end
    BG.db.errors = {}
    SIM.fire("ADDON_ACTION_BLOCKED", "BlazonGuild", "UseAction()")
    SIM.fire("ADDON_ACTION_BLOCKED", "BlazonGuild", "UseAction()")
    SIM.fire("ADDON_ACTION_FORBIDDEN", "BlazonGuild", "ReloadUI()")
    local a, b = BG.db.errors[1], BG.db.errors[2]
    return others .. "|" .. tostring(fromNotice) .. "|" .. #BG.db.errors .. "|" .. a.error .. "|" .. b.error .. "|" .. tostring(b.count)`);
  const parts = r.split('|');
  return (parts[0] === '0' && /^Frame:\w+\(\) IN_COMBAT < UI\/.*UI\/Showcase\.lua:\d+/.test(parts[1]) && parts.slice(2).join('|') === '2|ReloadUI() FORBIDDEN|UseAction()|2') || r;
});

await t.check('el origen se lee de una pila como la del juego (nuestros ficheros y los del juego, sin el manejador)', async () => {
  const r = await get(peregrino, `
    local stack = [[[string "@Interface/AddOns/BlazonGuild/Core/Init.lua"]:140: in function <Interface/AddOns/BlazonGuild/Core/Init.lua:139>
[C]: in function 'Hide'
Interface/AddOns/BlazonGuild/UI/Marks.lua:155: in function 'Target'
[string "@Interface/AddOns/Blizzard_NamePlates/Blizzard_NamePlates.lua"]:88: in function <x>
[C]: ?]]
    return BG.StackOrigin(stack) .. "|" .. BG.StackOrigin(nil)`);
  return r === 'UI/Marks.lua:155 < Blizzard_NamePlates/Blizzard_NamePlates.lua:88|' || r;
});

await t.check('quien lo instala y no lo ha abierto ve cómo abrirlo (aviso y chat), tres veces como mucho; quien ya lo usa, no', async () => {
  const first = await get(bruno, 'return (BG.lastNotice and BG.lastNotice.title or "sin aviso") .. "|" .. tostring(BG.db.settings.welcomed)');
  if (first !== 'BlazonGuild está listo|1') return `al entrar: ${first}`;
  const chat = await get(bruno, 'for _, l in ipairs(SIM.log) do if l:find("listo. Ábrelo con /bg", 1, true) then return "sí" end end return "no"');
  if (chat !== 'sí') return 'no lo dice en el chat';
  const again = await get(bruno, 'return tostring(BG.Welcome()) .. tostring(BG.Welcome()) .. tostring(BG.Welcome())');
  if (again !== 'truetruefalse') return `más veces: ${again}`;
  const users = await get(peregrino, 'return tostring(BG.db.settings.welcomed) .. "|" .. tostring(BG.Welcome())');
  if (users !== 'nil|false') return `a quien ya lo usa: ${users}`;
  await bruno.run('BG.db.settings.welcomed = nil BG:ToggleWindow()');
  const asked = await get(bruno, 'return BlazonGuildDialog and BlazonGuildDialog:IsShown() and BlazonGuildDialog.title:GetText() or "sin diálogo"');
  await bruno.run('BlazonGuildDialog.primary:Click() BG:ToggleWindow()');
  const after = await get(bruno, 'return tostring(BG.Welcome())');
  return (asked === 'Antes de conectar con tu hermandad' && after === 'false') || `al abrir: ${asked}; después: ${after}`;
});

await t.check('nada de esto deja errores internos', async () => {
  for (const c of net.clients) {
    const e = await get(c, 'local e = BG.db.errors and BG.db.errors[1] return e and (e.where .. ": " .. e.error) or ""');
    if (e && !e.startsWith('acción bloqueada por el juego: UseAction()') && !e.startsWith('acción bloqueada por el juego: ReloadUI()')) return `${c.name}: ${e}`;
  }
  return true;
});

net.close();
t.report();
