// Minimapa, flecha y avistamientos (0.21.0, the rest of entrega 7): guildmates who share their position as dots on
// the minimap (only within its range, turning with it), the arrow to follow a guildmate or a point (distance, way,
// arriving, giving up), the meeting point to follow, and sightings: what each client saw of the other faction stays
// in memory, nothing is sent until someone asks, only those who accept answer, the answer goes to the one who
// asked alone, and the screen.
import { createNetwork, checklist } from './harness.mjs';

const P = {
  tarek: { first: 'Tarek', second: 'Vientoalto', guid: 'Player-6842-SIMA', rosterIndex: 1 }, // Maestro
  peregrino: { first: 'El', second: 'Peregrino', guid: 'Player-6842-0A1B2C3D', rosterIndex: 2 }, // Miembro
  rina: { first: 'Rina', second: 'Dagaluna', guid: 'Player-6842-SIMB', rosterIndex: 5 }, // Miembro
  lobo: { first: 'Lobo', second: 'Feroz', guid: 'Player-7000-LOBO', rosterIndex: 1, guild: 'Los Lobos' }, // another guild
};
const net = await createNetwork([P.tarek, P.peregrino, P.rina, P.lobo]);
const [tarek, peregrino, rina, lobo] = net.clients;
await net.loginAll();
for (const c of net.clients) await c.run('BG.Consent.Accept()');
await net.advance(20, 0.5);
const get = net.get;
const t = checklist('comprobaciones del minimapa, la flecha y los avistamientos');
const notice = (c) => get(c, 'return BG.lastNotice and (BG.lastNotice.title .. "|" .. (BG.lastNotice.text or "")) or ""');
const near = (a, b, eps = 0.6) => Math.abs(a - b) <= eps;

// Peregrino stands at (0.4512, 0.6078) of zone 1437 (1000 yards a side). Rina, 50 yards to his east; Tarek, far away.
await rina.run('SIM.mapPos = { map = 1437, x = 0.5012, y = 0.6078 } assert(BG.Layers.SetSharing(true))');
await tarek.run('SIM.mapPos = { map = 1436, x = 0.9, y = 0.9 } assert(BG.Layers.SetSharing(true))');
await net.advance(4);

await t.check('minimapa: el compañero cercano sale donde está; el lejano, no', async () => {
  const r = await get(peregrino, `BG.Radar.Update() local d = BG.Radar.dots[1]
    local shown = 0 for _, x in ipairs(BG.Radar.dots) do if x:IsShown() then shown = shown + 1 end end
    return shown .. "|" .. (d and d.mate.name or "") .. "|" .. (d and string.format("%.1f|%.1f", d.rx, d.ry) or "")`);
  const [n, name, rx, ry] = r.split('|');
  return (n === '1' && name === 'Rina Dagaluna' && near(+rx, 50) && near(+ry, 0)) || r;
});

await t.check('minimapa que gira: con el jugador mirando al oeste, quien está al este sale abajo', async () => {
  const r = await get(peregrino, `SIM.cvars.rotateMinimap = "1" SIM.facing = math.pi / 2 BG.Radar.Update()
    local d = BG.Radar.dots[1] local out = string.format("%.1f|%.1f", d.rx, d.ry)
    SIM.cvars.rotateMinimap = nil SIM.facing = 0 return out`);
  const [rx, ry] = r.split('|').map(Number);
  return (near(rx, 0) && near(ry, -50)) || r;
});

await t.check('los puntos se quitan y se ponen; y desaparecen cuando deja de compartir', async () => {
  const off = await get(peregrino, 'BG.Radar.SetEnabled(false) BG.Radar.Update() return tostring(BG.Radar.dots[1]:IsShown())');
  const on = await get(peregrino, 'BG.Radar.SetEnabled(true) BG.Radar.Update() return tostring(BG.Radar.dots[1]:IsShown())');
  await rina.run('assert(BG.Layers.SetSharing(false))');
  await net.advance(3);
  const gone = await get(peregrino, 'BG.Radar.Update() return tostring(BG.Radar.dots[1]:IsShown())');
  await rina.run('assert(BG.Layers.SetSharing(true))');
  await net.advance(3);
  return (off === 'false' && on === 'true' && gone === 'false') || `quitar ${off}; poner ${on}; al dejar de compartir ${gone}`;
});

await t.check('flecha: sigue a un compañero lejano con la distancia y el giro; se aparta si deja de compartir', async () => {
  const r = await get(peregrino, `assert(BG.Radar.Follow({ mate = "Tarek Vientoalto" })) BG.Radar.Update()
    local a = BlazonGuildArrow return tostring(a:IsShown()) .. "|" .. a.label:GetText() .. "|" .. a.dist:GetText() .. "|" .. string.format("%.2f", a.turn)`);
  const [shown, label, dist, turn] = r.split('|');
  // Tarek: (2600 + 720, 3400 + 720) against Peregrino's (2451.2, 3607.8): 868.8 east and 512.2 south -> 1009 yards,
  // to the south-east: turning right (clockwise) by about 120 degrees.
  if (!(shown === 'true' && label === 'Tarek Vientoalto' && dist === '1009 metros' && near(+turn, -2.103, 0.01))) return r;
  await tarek.run('assert(BG.Layers.SetSharing(false))');
  await net.advance(3);
  const lost = await get(peregrino, 'BG.Radar.Update() return BlazonGuildArrow.dist:GetText()');
  await net.advance(65, 5);
  const after = await get(peregrino, 'BG.Radar.Update() return tostring(BG.Radar.Following() == nil) .. "|" .. tostring(BlazonGuildArrow:IsShown())');
  const told = await notice(peregrino);
  await tarek.run('assert(BG.Layers.SetSharing(true))');
  return (lost === 'sin posición ahora' && after === 'true|false' && told.startsWith('Flecha apagada'))
    || `sin posición: ${lost}; después: ${after}; aviso: ${told}`;
});

await t.check('punto de reunión: sale en «En el mapa», se sigue, y al llegar la flecha se apaga', async () => {
  await tarek.run('SIM.mapPos = { map = 1437, x = 0.4512, y = 0.5578 } assert(BG.Board.Decree("RALLY", "Todos aquí", true))');
  await net.advance(3);
  const listed = await get(peregrino, `BG:ToggleWindow() BG:ShowView("map") local f = BG.window.viewFrames.map
    f.zonesPlate.tabs.buttons[2]:Click() SIM.layout(834, 604)
    local it = f.mates.items[1] return #f.mates.items .. "|" .. (it and (it.label or it.mate) or "")`);
  if (listed !== '3|Reunión con Tarek Vientoalto') return `lista: ${listed}`;
  const go = await get(peregrino, `local f = BG.window.viewFrames.map f.mates.rows[1].go:Click() BG.Radar.Update()
    return BlazonGuildArrow.dist:GetText() .. "|" .. f.mates.rows[1].go.text:GetText()`);
  if (go !== '50 metros|Dejar de seguir') return `seguir: ${go}`;
  await peregrino.run('SIM.mapPos = { map = 1437, x = 0.4512, y = 0.5628 } BG.Radar.Update()');
  const arrived = await get(peregrino, 'return tostring(BG.Radar.Following() == nil) .. "|" .. tostring(BlazonGuildArrow:IsShown())');
  const told = await notice(peregrino);
  await peregrino.run('SIM.mapPos = { map = 1437, x = 0.4512, y = 0.6078 }');
  return (arrived === 'true|false' && told.startsWith('Has llegado')) || `al llegar: ${arrived}; aviso: ${told}`;
});

// A Horde player Rina sees on her target; a human (our faction) she sees too.
const HORDE = 'Player-6842-H0RDA1';
const HUMAN = 'Player-6842-HUMANO';
for (const c of net.clients) {
  await c.run(`SIM.players[${JSON.stringify(HORDE)}] = { name = "Grosh", surname = "Rompehuesos", class = "WARRIOR", race = "Orc" }
    SIM.players[${JSON.stringify(HUMAN)}] = { name = "Juan", surname = "Paseante", class = "ROGUE", race = "Human" }
    SIM.guildOf["Grosh Rompehuesos"] = "Kor'kron"`);
}
const sees = (c, guid, first, second, unit = 'target') => c.run(`
  SIM.units[${JSON.stringify(unit)}] = { ${JSON.stringify(first)}, ${JSON.stringify(second)} } SIM.unitGuids[${JSON.stringify(unit)}] = ${JSON.stringify(guid)}
  SIM.unitLevels[${JSON.stringify(unit)}] = 60
  SIM.fire(${JSON.stringify(unit === 'target' ? 'PLAYER_TARGET_CHANGED' : 'NAME_PLATE_UNIT_ADDED')}, ${JSON.stringify(unit)})`);

await t.check('avistamientos: se recuerda solo a la otra facción, en memoria, y no sale nada sin preguntar', async () => {
  const before = net.wire.length;
  await sees(rina, HORDE, 'Grosh', 'Rompehuesos');
  await sees(rina, HUMAN, 'Juan', 'Paseante', 'nameplate1');
  await net.advance(10, 1);
  const sent = net.wire.slice(before).filter((f) => /^\d+!(VQ|VR):/.test(f.msg) || f.msg.includes('Grosh'));
  const mine = await get(rina, 'local o = {} for _, s in ipairs(BG.Sightings.Mine()) do o[#o + 1] = s.name .. ":" .. tostring(s.guild) .. ":" .. s.level end return table.concat(o, ",")');
  const saved = await get(rina, 'local n = 0 for k, v in pairs(BG.db) do if type(v) == "table" and tostring(k):find("ight") then n = n + 1 end end return n');
  return (sent.length === 0 && mine === "Grosh Rompehuesos:Kor'kron:60" && saved === 0) || `enviado ${sent.length}; Rina recuerda ${mine}; guardado ${saved}`;
});

await t.check('quien no acepta «avistamientos» no responde', async () => {
  await peregrino.run('assert(BG.Sightings.Ask("grosh"))');
  await net.advance(6);
  const rows = await get(peregrino, 'return #BG.Sightings.Current().rows');
  return rows === 0 || `respuestas sin aceptarlo: ${rows}`;
});

await t.check('quien lo acepta responde, solo a quien pregunta y por susurro; aviso y fila con distancia', async () => {
  await rina.run('assert(BG.Sightings.SetAnswering(true))');
  await net.advance(11);
  const before = net.wire.length;
  await peregrino.run('assert(BG.Sightings.Ask("grosh"))');
  await net.advance(6);
  const answers = net.wire.slice(before).filter((f) => f.from === 'Rina Dagaluna' && /^\d+!VR:/.test(f.msg));
  const toPeregrinoOnly = answers.length >= 1 && answers.every((f) => f.dist === 'WHISPER' && f.target === 'El Peregrino');
  const row = await get(peregrino, `local r = BG.Sightings.Current().rows[1]
    return r and (r.name .. "|" .. r.by .. "|" .. r.level .. "|" .. r.guild .. "|" .. string.format("%.3f", r.x)) or "nada"`);
  const told = await notice(peregrino);
  const tarekKnows = await get(tarek, 'return tostring(BG.Sightings.Current() ~= nil)');
  return (toPeregrinoOnly && row === "Grosh Rompehuesos|Rina Dagaluna|60|Kor'kron|0.501" && told.startsWith('Avistamiento: Grosh Rompehuesos') && tarekKnows === 'false')
    || `susurros ${answers.length} (${answers.map((f) => f.dist + '>' + f.target).join(',')}); fila ${row}; aviso ${told}; Tarek ${tarekKnows}`;
});

await t.check('«Enemigos en mi zona» trae a los de la otra facción vistos en tu zona, y nunca a los de la tuya', async () => {
  await net.advance(11);
  await peregrino.run('assert(BG.Sightings.Ask())');
  await net.advance(6);
  const rows = await get(peregrino, 'local o = {} for _, r in ipairs(BG.Sightings.Current().rows) do o[#o + 1] = r.name end return table.concat(o, ",")');
  return rows === 'Grosh Rompehuesos' || rows;
});

await t.check('respuestas que no valen: de fuera de la hermandad, a una pregunta que no existe, o de otro nombre', async () => {
  const before = await get(peregrino, 'return #BG.Sightings.Current().rows');
  const askId = await get(peregrino, 'return BG.Sightings.Current().id');
  // Lobo (another guild) whispers an answer to the live question; Rina answers a question that does not
  // exist; Rina sends a row for a zone that is not the one asked.
  await lobo.run(`BG.Consent.Accept() BG.Comm.Send("VR", { i = ${JSON.stringify(askId)}, r = { { n = "Grosh Rompehuesos", m = 1437, x = 100, y = 100, a = 5 } } }, "WHISPER", "El Peregrino")`);
  await rina.run(`BG.Comm.Send("VR", { i = "noexiste", r = { { n = "Grosh Rompehuesos", m = 1437, x = 100, y = 100, a = 5 } } }, "WHISPER", "El Peregrino")
    BG.Comm.Send("VR", { i = ${JSON.stringify(askId)}, r = { { n = "Otro Lejos", m = 1436, x = 100, y = 100, a = 5 } } }, "WHISPER", "El Peregrino")`);
  await net.advance(6);
  const after = await get(peregrino, 'local o = {} for _, x in ipairs(BG.Sightings.Current().rows) do o[#o + 1] = x.name .. "@" .. string.format("%.3f", x.x) end return table.concat(o, ",")');
  return (before === 1 && after === 'Grosh Rompehuesos@0.501') || `antes ${before}; después ${after}`;
});

await t.check('pantalla: las tres pestañas del Mapa, sin nada fuera de su sitio', async () => {
  const r = await get(peregrino, `
    local f = BG.window.viewFrames.map
    local out = {}
    for i = 1, 3 do
      f.zonesPlate.tabs.buttons[i]:Click() SIM.layout(834, 604)
      local lay = SIM.CheckLayout(f)
      out[#out + 1] = i .. ":" .. #lay .. (lay[1] and (" " .. lay[1]) or "")
    end
    local seen = #f.seen.items .. " " .. (f.seen.rows[1] and f.seen.rows[1].title:GetText() or "")
    return table.concat(out, ",") .. " | " .. seen .. " | " .. f.zonesPlate.answer.text:GetText()`);
  return /^1:0,2:0,3:0 \| 1 .*Grosh Rompehuesos.* \| Responder cuando pregunten$/.test(r) || r;
});

await t.check('en otros idiomas: el avistamiento, la flecha y el estado salen traducidos y en su sitio', async () => {
  const bad = [];
  for (const lang of ['en', 'de', 'fr', 'it', 'pt', 'ru']) {
    const r = await get(peregrino, `BG.db.settings.lang = "${lang}" BG.Locale.Init()
      assert(BG.Radar.Follow({ m = 1437, x = 0.5012, y = 0.6078, label = "Visto: Grosh Rompehuesos" })) BG.Radar.Update()
      local f = BG.window.viewFrames.map
      f.zonesPlate.tabs.buttons[3]:Click() SIM.layout(834, 604)
      local row = f.seen.rows[1]
      local texts = { row.title:GetText(), row.sub:GetText(), row.right:GetText(), row.go.text:GetText(), f.zonesPlate.status:GetText(),
        BlazonGuildArrow.label:GetText(), BlazonGuildArrow.dist:GetText() }
      local lay = table.concat(SIM.CheckLayout(f), " ; ")
      BG.Radar.Stop()
      return table.concat(texts, " || ") .. " ## " .. lay`);
    const [texts, lay] = r.split(' ## ');
    // (Visto, Seguir and metros are also Italian or Portuguese words)
    const words = { it: /\b(hace|Preguntaste|por ti|metros|avistamientos?|Hermandad|Seguir|Nadie)\b/, pt: /\b(hace|Preguntaste|por ti|Hermandad|Nadie)\b/ };
    const spanish = texts.match(words[lang] || /\b(hace|Preguntaste|por ti|metros|Visto|avistamientos?|Hermandad|Seguir|Nadie)\b/);
    if (spanish || lay) bad.push(`${lang}: ${spanish ? 'español «' + spanish[0] + '» en ' + texts : ''} ${lay}`);
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
