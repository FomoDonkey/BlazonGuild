// Mapa y capas (entrega 7) with three members: online members by zone (from the roster), nothing shared until
// each one turns it on, positions as dots on the world map (and gone when turned off or in an instance), our
// layer read from creatures (two must agree; a stray one does not move us), the guild's layers in our zone,
// asking for an invite (the host decides; a no; someone who does not take requests), arriving and leaving the
// group, a host on another sub-realm, and the screen.
import { createNetwork, checklist } from './harness.mjs';

const P = {
  tarek: { first: 'Tarek', second: 'Vientoalto', guid: 'Player-6842-SIMA', rosterIndex: 1 }, // Maestro
  peregrino: { first: 'El', second: 'Peregrino', guid: 'Player-6842-0A1B2C3D', rosterIndex: 2 }, // Miembro
  rina: { first: 'Rina', second: 'Dagaluna', guid: 'Player-6842-SIMB', rosterIndex: 5 }, // Miembro
};
const net = await createNetwork([P.tarek, P.peregrino, P.rina]);
const [tarek, peregrino, rina] = net.clients;
await net.loginAll();
for (const c of net.clients) await c.run('BG.Consent.Accept()');
await net.advance(20, 0.5);
const get = net.get;
const t = checklist('comprobaciones del mapa y las capas');
const notice = (c) => get(c, 'return BG.lastNotice and (BG.lastNotice.title .. "|" .. (BG.lastNotice.text or "")) or ""');
// A creature with zone copy `z` seen by `c` as `unit` (target, mouseover or a nameplate).
let spawn = 1;
const see = async (c, z, unit = 'target') => {
  spawn += 1;
  const guid = `Creature-0-4469-0-${z}-${1000 + spawn}-0000${spawn}`;
  await c.run(`SIM.units[${JSON.stringify(unit)}] = ${JSON.stringify(guid)}
    SIM.fire(${JSON.stringify(unit === 'target' ? 'PLAYER_TARGET_CHANGED' : unit === 'mouseover' ? 'UPDATE_MOUSEOVER_UNIT' : 'NAME_PLATE_UNIT_ADDED')}, ${JSON.stringify(unit)})`);
};

await t.check('zonas: los conectados por zona, la tuya primero', async () => {
  await peregrino.run('SIM.roster[5][6] = "Bosque de Elwynn" BG.Guild.Scan()');
  const r = await get(peregrino, `local o = {} for _, z in ipairs(BG.Layers.Zones()) do local n = {} for _, m in ipairs(z.members) do n[#n+1] = m.name end
    o[#o+1] = z.zone .. ":" .. table.concat(n, ",") end return table.concat(o, " / ")`);
  return r === 'Los Humedales:El Peregrino,Tarek Vientoalto / Bosque de Elwynn:Rina Dagaluna' || r; // (highest level first: 24 and 17)
});

await t.check('privacidad: nadie comparte posición ni capa hasta encenderlo', async () => {
  const before = net.wire.length;
  await see(peregrino, 1234);
  await see(peregrino, 1234, 'mouseover');
  await net.advance(30, 1);
  const sent = net.wire.slice(before).filter((f) => /(PS|LY):/.test(f.msg));
  if (sent.length) return `salieron ${sent.length} mensajes de posición o capa`;
  const mine = await get(peregrino, 'local l = BG.Layers.Mine() return l and l.z or "nada"');
  return mine === 1234 || `Peregrino sabe su capa: ${mine}`;
});

await t.check('posición: puntos en el mapa del mundo, fuera al apagarlo o en una mazmorra', async () => {
  await rina.run('SIM.mapPos = { map = 1436, x = 0.5, y = 0.5 } assert(BG.Layers.SetSharing(true))');
  await net.advance(4);
  const dot = await get(peregrino, `WorldMapFrame.mapID = 1414 WorldMapFrame:Show() local n = BG.Positions.Draw() local p = BG.Positions.pins[1]
    return n .. "|" .. (p and string.format("%.2f,%.2f|%s", p.mx, p.my, p.mate.name) or "")`);
  if (dot !== '1|0.30,0.38|Rina Dagaluna') return `puntos: ${dot}`;
  const zone = await get(peregrino, 'WorldMapFrame.mapID = 1437 return BG.Positions.Draw()');
  if (zone !== 1) return `en el mapa de la zona de al lado: ${zone}`;
  await rina.run('assert(BG.Layers.SetSharing(false))');
  await net.advance(4);
  const off = await get(peregrino, 'return BG.Positions.Draw() .. "|" .. #BG.Positions.Mates()');
  if (off !== '0|0') return `al apagarlo: ${off}`;
  const inst = await get(rina, 'assert(BG.Layers.SetSharing(true)) SIM.inInstance = true local sent = BG.Positions.Send(true) SIM.inInstance = false return tostring(sent)');
  return inst === 'false' || `en una mazmorra envió su posición: ${inst}`;
});

await t.check('capas: dos criaturas la confirman; una suelta no te cambia', async () => {
  await peregrino.run('assert(BG.Layers.SetSharing(true))');
  await tarek.run('assert(BG.Layers.SetSharing(true))');
  await see(tarek, 5678);
  await see(tarek, 5678, 'nameplate1');
  await net.advance(35, 1);
  await see(peregrino, 9999); // (a creature from another copy, at the zone's border)
  await net.advance(2);
  const stay = await get(peregrino, 'return BG.Layers.Mine().z');
  if (stay !== 1234) return `una criatura suelta cambió la capa de Peregrino a ${stay}`;
  const groups = await get(peregrino, `local o = {} for _, g in ipairs(BG.Layers.InZone(1437)) do o[#o+1] = g.z .. ":" .. g.label .. ":" .. #g.members .. (g.mine and "*" or "") end return table.concat(o, " / ")`);
  return groups === '1234:El Peregrino:1* / 5678:Tarek Vientoalto:1' || `capas que ve Peregrino: ${groups}`;
});

await t.check('pedir invitación: quien está en la otra capa decide; nunca invita solo', async () => {
  const ok = await get(peregrino, 'return tostring(BG.Layers.Ask("Tarek Vientoalto"))');
  if (ok !== 'true') return `pedir: ${ok}`;
  await net.advance(3);
  const told = await notice(tarek);
  const listed = await get(tarek, 'local r = BG.Layers.Requests() return #r .. "|" .. (r[1] and r[1].name or "") .. "|" .. #SIM.invites');
  if (!told.startsWith('Petición de capa') || listed !== '1|El Peregrino|0') return `Tarek: ${told}; ${listed}`;
  await tarek.run('assert(BG.Layers.Answer("El Peregrino", true))');
  const invited = await get(tarek, 'return SIM.invites[#SIM.invites]');
  return invited === 'El Peregrino' || `invitó a ${invited}`;
});

await t.check('al llegar a su capa, el addon te saca del grupo', async () => {
  await peregrino.run('SIM.group.inGroup = true SIM.fire("GROUP_ROSTER_UPDATE")');
  await net.advance(8); // (our old layer's creatures not seen for a while)
  await see(peregrino, 5678);
  await see(peregrino, 5678, 'mouseover');
  await net.advance(2);
  const r = await get(peregrino, 'return tostring(SIM.left) .. "|" .. BG.Layers.Mine().z .. "|" .. tostring(BG.Layers.Pending())');
  const told = await notice(peregrino);
  return (r === '1|5678|nil' && told.startsWith('Ya estás en su capa')) || `${r}; aviso: ${told}`;
});

await t.check('un «no», y quien no acepta peticiones', async () => {
  await see(rina, 4321);
  await see(rina, 4321, 'mouseover');
  await rina.run('SIM.mapPos = { map = 1437, x = 0.2, y = 0.2 }');
  await net.advance(35, 1);
  await peregrino.run('assert(BG.Layers.Ask("Rina Dagaluna"))');
  await net.advance(3);
  await rina.run('assert(BG.Layers.Answer("El Peregrino", false))');
  await net.advance(3);
  const no = await notice(peregrino);
  if (!no.startsWith('Ahora no puede') || (await get(peregrino, 'return tostring(BG.Layers.Pending())')) !== 'nil') return `tras el no: ${no}`;
  await rina.run('BG.Layers.SetHelping(false)');
  await net.advance(35, 1);
  const r = await get(peregrino, 'local ok, why = BG.Layers.Ask("Rina Dagaluna") return tostring(why)');
  return r === 'no ayuda' || `a quien no acepta: ${r}`;
});

await t.check('anfitrión de otro reino: te dice que salgas y vuelvas a entrar', async () => {
  await tarek.run('GetNormalizedRealmName = function() return "ForeverPvP2" end BG.Layers.Announce(true)');
  await net.advance(35, 1);
  await peregrino.run('SIM.group.inGroup = false assert(BG.Layers.Ask("Tarek Vientoalto"))');
  await net.advance(3);
  await peregrino.run('SIM.group.inGroup = true SIM.fire("GROUP_ROSTER_UPDATE")');
  const told = await notice(peregrino);
  await peregrino.run('BG.Layers.CancelHop() SIM.group.inGroup = false');
  return (told.startsWith('Ya estás en su grupo') && told.includes('ForeverPvP2') && told.includes('vuelve a entrar')) || told;
});

await t.check('pantalla: zonas, capas, peticiones y el interruptor', async () => {
  const e = await get(peregrino, `
    BG:ToggleWindow() SIM.layout(834, 604) BG:ShowView("map") SIM.layout(834, 604)
    local f = BG.window.viewFrames.map
    if #f.zones.items ~= 2 then return "zonas: " .. #f.zones.items end
    if #f.layers.items < 2 then return "capas: " .. #f.layers.items end
    if not f.hero.sub:GetText():find("capa de", 1, true) then return "cabecera: " .. f.hero.sub:GetText() end
    if f.side.share.text:GetText() ~= "Dejar de compartir" then return "interruptor: " .. f.side.share.text:GetText() end
    local out = SIM.CheckLayout(f)
    if #out > 0 then return "se sale: " .. out[1] end
    return true`);
  if (e !== true) return e;
  await peregrino.run('assert(BG.Layers.Ask("Tarek Vientoalto"))');
  await net.advance(3);
  return get(tarek, `
    BG:ToggleWindow() SIM.layout(834, 604) BG:ShowView("map") SIM.layout(834, 604)
    local f = BG.window.viewFrames.map
    if not f.requests:IsShown() or #f.requests.items ~= 1 then return "peticiones: " .. #f.requests.items end
    local out = SIM.CheckLayout(f)
    if #out > 0 then return "se sale: " .. out[1] end
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
