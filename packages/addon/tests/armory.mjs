// Armería and JcE (0.20.0), the two sections that said «Pronto». Armería: each one shares their equipment only if
// they say yes, and it follows what they wear; someone near you can be inspected (only you see it, nothing is sent).
// JcE: who has the level for each raid, the bosses the guild defeats (written down by the addon of a member who was
// there, once a day per boss, only with a group mostly of the guild) and the last raids.
import { createNetwork, checklist } from './harness.mjs';

const t = checklist('comprobaciones de la Armería y el JcE');
const P = {
  tarek: { first: 'Tarek', second: 'Vientoalto', guid: 'Player-6842-SIMA', rosterIndex: 1 },
  peregrino: { first: 'El', second: 'Peregrino', guid: 'Player-6842-0A1B2C3D', rosterIndex: 2 },
  bruno: { first: 'Bruno', second: 'Hierrosol', guid: 'Player-6842-BENI', rosterIndex: 3 },
};
const net = await createNetwork([P.tarek, P.peregrino, P.bruno]);
const [tarek, peregrino, bruno] = net.clients;
const get = net.get;
await net.loginAll();
for (const c of net.clients) {
  await c.run(`BG.Consent.Accept()
    SIM.items[16866] = "Yelmo de Ira" SIM.items[16865] = "Coraza de Ira" SIM.items[17076] = "Bonereaver"
    SIM.ilvl[16866] = 66 SIM.ilvl[16865] = 66 SIM.ilvl[17076] = 71 SIM.ilvl[3853] = 25`);
}
await bruno.run('SIM.gear.player = { [1] = 16866, [5] = { 16865, 1891 }, [16] = 17076, [19] = 3853 }');
await net.advance(20, 0.5);

await t.check('nadie comparte su equipo si no lo dice: está apagado hasta que cada uno lo enciende', async () => {
  await net.advance(25, 0.5);
  const n = await get(peregrino, 'return #BG.Store.List("gear")');
  return n === 0 || `${n} equipos compartidos sin pedirlo`;
});

await t.check('quien lo enciende comparte lo que lleva (objetos, encantamiento, nivel de objeto) y sus compañeros lo ven', async () => {
  await bruno.run('assert(BG.Armory.SetSharing(true))');
  await net.advance(4);
  const r = await get(peregrino, `
    local g = BG.Armory.Of("Bruno Hierrosol")
    if not g then return "nada" end
    return g.source .. " " .. tostring(g.il) .. " " .. g.slots[1].id .. " " .. tostring(g.slots[5].ench) .. " " .. tostring(g.slots[19] ~= nil)`);
  // (the tabard does not count for the item level: (66 + 66 + 71) / 3 = 68)
  return r === 'shared 68 16866 1891 true' || r;
});

await t.check('si se cambia de equipo se actualiza solo; si lo apaga, desaparece de la Armería de los demás', async () => {
  await bruno.run('SIM.gear.player[1] = nil SIM.fire("PLAYER_EQUIPMENT_CHANGED", 1)');
  await net.advance(26, 0.5);
  const changed = await get(peregrino, 'local g = BG.Armory.Of("Bruno Hierrosol") return tostring(g and g.slots[1] == nil) .. " " .. tostring(g and g.il)');
  await bruno.run('BG.Armory.SetSharing(false)');
  await net.advance(4);
  const gone = await get(peregrino, 'return tostring(BG.Armory.Of("Bruno Hierrosol") == nil)');
  return (changed === 'true 69' && gone === 'true') || `cambio: ${changed}; apagado: ${gone}`;
});

await t.check('inspeccionar a alguien cerca: lo ves tú, sin enviar nada; lejos o en combate, te dice por qué', async () => {
  await tarek.run('SIM.gear["Bruno Hierrosol"] = { [1] = 16866, [16] = 17076 }');
  const far = await get(tarek, 'local ok, why = BG.Armory.Inspect("Bruno Hierrosol") return tostring(why)');
  await tarek.run('SIM.units.target = { "Bruno", "Hierrosol" } SIM.unitGuids.target = "Player-6842-BENI" InCombatLockdown = function() return true end');
  const combat = await get(tarek, 'local ok, why = BG.Armory.Inspect("Bruno Hierrosol") return tostring(why)');
  const before = net.wire.length;
  await tarek.run('InCombatLockdown = function() return false end assert(BG.Armory.Inspect("Bruno Hierrosol"))');
  await net.advance(2, 0.25);
  const seen = await get(tarek, 'local g = BG.Armory.Of("Bruno Hierrosol") return g and (g.source .. " " .. tostring(g.il)) or "nada"');
  const others = await get(peregrino, 'return tostring(BG.Armory.Of("Bruno Hierrosol") == nil)');
  const sent = net.wire.slice(before).filter((f) => f.from === 'Tarek Vientoalto').length;
  return (far === 'lejos' && combat === 'combate' && seen === 'seen 69' && others === 'true' && sent === 0)
    || `lejos: ${far}; combate: ${combat}; visto: ${seen}; los demás no lo ven: ${others}; envió ${sent} tramas`;
});

await t.check('pantalla de la Armería: la lista por nivel de objeto, cada ranura con su objeto y nada fuera de su sitio', async () => {
  await bruno.run('BG.Armory.SetSharing(true) SIM.gear.player[1] = 16866 BG.Armory.Publish()');
  await net.advance(4);
  const r = await get(peregrino, `
    BG:ToggleWindow() BG:ShowView("armory") SIM.layout(834, 604)
    local f = BG.window.viewFrames.armory
    f.selected = "Bruno Hierrosol" BG:RefreshView("armory") SIM.layout(834, 604)
    local first = BG.Armory.Members()[1].name
    local names = {}
    for _, row in ipairs(f.slots) do if row:IsShown() and row.itemId then names[#names + 1] = row.label end end
    local bad = table.concat(SIM.CheckLayout(f), " ; ")
    return first .. " | " .. table.concat(names, ",") .. " | " .. f.hero.sub:GetText() .. " | " .. bad`);
  return /^Bruno Hierrosol \| Yelmo de Ira,.*Coraza de Ira.*Bonereaver.* \| 1 miembro comparte su equipo.* \| $/.test(r) || r;
});

await t.check('JcE: quién tiene el nivel de cada banda, contado de la lista del juego', async () => {
  const r = await get(peregrino, `
    local want = 0
    for _, m in ipairs(BG.Guild.members) do if (m.level or 0) >= 60 then want = want + 1 end end
    local mc = BG.PvE.Raids()[1]
    return mc.key .. " " .. mc.ready .. " " .. want .. " " .. #BG.PvE.Raids()`);
  const [key, ready, want, n] = r.split(' ');
  return (key === 'BARROW' && ready === want && n === '3') || r; // (Forever's raids: Barrow Deeps, Hyjal Summit, Onyxia)
});

const raidOf = (rest) => `SIM.setRaid({ { "Tarek", "Vientoalto", 1 }, { "El", "Peregrino", 1 }, { "Bruno", "Hierrosol", 1 }${rest} })
  SIM.group.inRaid = true SIM.instance = { name = "Guarida de Onyxia", kind = "raid", mapId = 249 }`;

await t.check('al matar a un jefe con un grupo de la hermandad se apunta solo, una vez por día aunque lo vean todos', async () => {
  for (const c of net.clients) await c.run(`${raidOf(', { "Miembro", "Prueba 4", 2 }, { "Miembro", "Prueba 5", 2 }')} SIM.fire("ENCOUNTER_END", 1084, "Onyxia", 9, 40, 1)`);
  await net.advance(4);
  for (const c of net.clients) await c.run('SIM.fire("ENCOUNTER_END", 1084, "Onyxia", 9, 40, 1)');
  await net.advance(4);
  const r = await get(peregrino, 'local p = BG.PvE.Progress("ONY") return #BG.Store.List("kills") .. " " .. p.done .. "/" .. p.of .. " " .. p.bosses[1].n');
  return r === '1 1/1 Onyxia' || r;
});

await t.check('no cuenta: un intento fallido, fuera de una banda, ni un grupo que casi no es de la hermandad', async () => {
  await peregrino.run('SIM.fire("ENCOUNTER_END", 664, "Magmadar", 9, 40, 0)');
  await peregrino.run(`${raidOf(Array.from({ length: 12 }, (_, i) => `, { "Ajeno", "Jugador${i}", 3 }`).join(''))} SIM.fire("ENCOUNTER_END", 665, "Gehennas", 9, 40, 1)`);
  await peregrino.run(`${raidOf('')} SIM.instance = nil SIM.fire("ENCOUNTER_END", 666, "Garr", 9, 40, 1)`);
  await net.advance(4);
  const r = await get(tarek, 'return #BG.Store.List("kills")');
  return r === 1 || `${r} jefes apuntados`;
});

await t.check('pantalla del JcE: las bandas con sus jefes, la elegida jefe a jefe, y nada fuera de su sitio; ya no queda ninguna sección «Pronto»', async () => {
  const r = await get(bruno, `
    BG:ToggleWindow() BG:ShowView("pve") SIM.layout(834, 604)
    local f = BG.window.viewFrames.pve
    f.selected = "ONY" BG:RefreshView("pve") SIM.layout(834, 604)
    local upcoming = {}
    for _, item in ipairs(BG.nav) do
      local v = BG.views[item.key]
      if not v or v.upcoming then upcoming[#upcoming + 1] = item.key end
    end
    return f.right.head:GetText() .. " | " .. (f.bosses:GetText():find("Onyxia") and "Onyxia" or "-") .. " | "
      .. table.concat(SIM.CheckLayout(f), " ; ") .. " | " .. table.concat(upcoming, ",")`);
  return r === 'Guarida de Onyxia | Onyxia |  | ' || r;
});

// 0.29.2 (Peregrino's screenshot: every slot said «Item 6189» with a question mark, and his own item's tooltip came twice).
await t.check('Armería: cada objeto con su nombre y su icono; si el juego aún no lo conoce, el icono sale ya y el nombre llega solo', async () => {
  // (Peregrino's client has never seen these gauntlets: the first time the screen draws them, the game has no name yet.)
  await peregrino.run(`
    SIM.items[16863] = "Guanteletes de Ira" SIM.uncached[16863] = true SIM.itemAsks = 0 SIM.firstSeen = nil
    if not (BG.window and BG.window:IsShown()) then BG:ToggleWindow() end
    BG:ShowView("armory") SIM.layout(834, 604)
    local f = BG.window.viewFrames.armory
    f.selected = "Bruno Hierrosol"
    SIM.oldRefresh = BG.RefreshView
    BG.RefreshView = function(self, key)
      SIM.oldRefresh(self, key)
      for _, row in ipairs(f.slots) do
        if row:IsShown() and row.itemId == 16863 and not SIM.firstSeen then SIM.firstSeen = row.label .. " " .. tostring(row.icon.__tex) end
      end
    end`);
  await bruno.run('SIM.items[16863] = "Guanteletes de Ira" SIM.ilvl[16863] = 66 SIM.gear.player[10] = 16863 BG.Armory.Publish()');
  await net.advance(4, 0.25);
  const before = await get(peregrino, 'BG.RefreshView = SIM.oldRefresh return tostring(SIM.firstSeen)');
  const after = await get(peregrino, `
    local f = BG.window.viewFrames.armory
    for _, row in ipairs(f.slots) do if row.itemId == 16863 then return row.label .. " " .. tostring(row.icon.__tex) .. " " .. SIM.itemAsks end end
    return "sin fila"`);
  return (before === 'Objeto 16863 135063' && after === 'Guanteletes de Ira 135063 1') || `antes: ${before}; después: ${after}`;
});

await t.check('rendimiento: un objeto que carga otra ventana (la bolsa, un enlace del chat) no redibuja la Armería', async () => {
  const n = await get(peregrino, `
    local n, old = 0, BG.RefreshView
    BG.RefreshView = function(self, key) if key == "armory" then n = n + 1 end return old(self, key) end
    SIM.fire("GET_ITEM_INFO_RECEIVED", 2589, true) SIM.fire("GET_ITEM_INFO_RECEIVED", 4306, true)
    SIM.advance(2)
    BG.RefreshView = old
    return n`);
  return n === 0 || `${n} redibujados`;
});

await t.check('tu propio objeto: su ventana como en tu personaje (ligado, durabilidad) y sin la de «Equipado» al lado, que era el mismo repetido', async () => {
  const mine = await get(bruno, `
    if not (BG.window and BG.window:IsShown()) then BG:ToggleWindow() end
    BG:ShowView("armory") SIM.layout(834, 604)
    local f = BG.window.viewFrames.armory
    f.selected = "Bruno Hierrosol" BG:RefreshView("armory")
    SIM.compare = true
    local row for _, r in ipairs(f.slots) do if r.itemId == 16866 then row = r end end
    row.__scripts.OnEnter(row)
    local shown = tostring(ShoppingTooltip1:IsShown())
    ShoppingTooltip1:Show() -- (Shift pressed while the mouse stays: the game opens it again)
    local again = tostring(ShoppingTooltip1:IsShown())
    row.__scripts.OnLeave(row)
    SIM.compare = false
    return GameTooltip.__item .. " " .. shown .. " " .. again`);
  const theirs = await get(peregrino, `
    local f = BG.window.viewFrames.armory
    f.selected = "Bruno Hierrosol" BG:RefreshView("armory")
    SIM.compare = true
    local row for _, r in ipairs(f.slots) do if r.itemId == 16866 then row = r end end
    row.__scripts.OnEnter(row)
    local shown = tostring(ShoppingTooltip1:IsShown())
    row.__scripts.OnLeave(row)
    SIM.compare = false
    return GameTooltip.__item .. " " .. shown`);
  return (mine === 'inventory:player:1 false false' && /^item:16866:0 true$/.test(theirs)) || `tuyo: ${mine}; de otro: ${theirs}`;
});

net.close();
t.report();
