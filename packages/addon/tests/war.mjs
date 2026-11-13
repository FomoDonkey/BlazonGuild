// Sala de guerra (entrega 6, third part) with four members: squads (organisers make them, the leader picks its
// people, nobody is in two), operations (organisers and squad leaders plan them, the squads called get the
// notice, everyone answers), the start alert to those called, the reminder, the report into the chronicle, the
// squad's private chat, and the screens.
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
const t = checklist('comprobaciones de la sala de guerra');
const notice = (c) => get(c, 'return BG.lastNotice and (BG.lastNotice.title .. "|" .. (BG.lastNotice.text or "")) or ""');
const clearNotice = async (...cs) => {
  for (const c of cs) await c.run('BG.lastNotice = nil');
};

await t.check('pantalla vacía: cada uno ve lo que puede hacer', async () => {
  const member = await get(peregrino, `
    BG:ToggleWindow() SIM.layout(834, 604) BG:ShowView("war") SIM.layout(834, 604)
    local f = BG.window.viewFrames.war
    if f.newOp:IsShown() or f.newSquad:IsShown() then return "un miembro ve los botones de planear" end
    if not f.opsEmpty:GetText():find("organizadores", 1, true) then return "texto vacío: " .. f.opsEmpty:GetText() end
    return true`);
  if (member !== true) return member;
  return get(tarek, `
    BG:ToggleWindow() SIM.layout(834, 604) BG:ShowView("war") SIM.layout(834, 604)
    local f = BG.window.viewFrames.war
    return (f.newOp:IsShown() and f.newSquad:IsShown()) or "el maestro no ve Planear y Nueva escuadra"`);
});

let lobos;
let halcones;
await t.check('escuadras: las crean los organizadores y el jefe elige a su gente', async () => {
  const denied = await get(peregrino, 'local r, why = BG.War.SaveSquad(nil, { name = "Mía", leader = "El Peregrino" }) return tostring(why)');
  if (denied !== 'permiso') return `un miembro creó una escuadra: ${denied}`;
  lobos = await get(tarek, 'return assert(BG.War.SaveSquad(nil, { name = "Los Lobos", spec = "ASSAULT", leader = "Rina Dagaluna" })).id');
  await net.advance(4);
  await clearNotice(peregrino);
  await rina.run(`assert(BG.War.AddToSquad(${JSON.stringify(lobos)}, "El Peregrino"))`);
  await net.advance(4);
  const told = await notice(peregrino);
  if (!told.startsWith('Nueva escuadra') || !told.includes('Los Lobos')) return `aviso a Peregrino: ${told}`;
  const rename = await get(rina, `local sq = BG.Store.Get("squads", ${JSON.stringify(lobos)}) local d = {} for k, v in pairs(sq.d) do d[k] = v end d.name = "Las Ritas"
    local r, why = BG.Store.Put("squads", sq.id, d) return tostring(why)`);
  if (rename !== 'permiso') return `la jefa cambió el nombre: ${rename}`;
  const add = await get(peregrino, `local r, why = BG.War.AddToSquad(${JSON.stringify(lobos)}, "Bruno Hierrosol") return tostring(why)`);
  return add === 'permiso' || `un miembro añadió gente: ${add}`;
});

await t.check('nadie está en dos escuadras: un organizador lo cambia, un jefe no se lo lleva', async () => {
  halcones = await get(tarek, 'return assert(BG.War.SaveSquad(nil, { name = "Halcones", spec = "SCOUT", leader = "Bruno Hierrosol" })).id');
  await net.advance(4);
  await bruno.run(`assert(BG.War.AddToSquad(${JSON.stringify(halcones)}, "El Peregrino"))`);
  await net.advance(4);
  const where = await get(rina, `return BG.War.SquadOf("El Peregrino").d.name .. "|" .. #BG.Store.Get("squads", ${JSON.stringify(lobos)}).d.members`);
  if (where !== 'Halcones|0') return `Peregrino está en ${where}`;
  const taken = await get(rina, `local r, why, other = BG.War.AddToSquad(${JSON.stringify(lobos)}, "El Peregrino") return tostring(why) .. "|" .. tostring(other)`);
  if (taken !== 'en otra|Halcones') return `la jefa se lo llevó: ${taken}`;
  await tarek.run(`assert(BG.War.AddToSquad(${JSON.stringify(lobos)}, "El Peregrino"))`);
  await net.advance(4);
  const back = await get(bruno, 'return BG.War.SquadOf("El Peregrino").d.name');
  return back === 'Los Lobos' || back;
});

let op;
await t.check('operaciones: las planean organizadores y jefes; los llamados reciben el aviso', async () => {
  const denied = await get(peregrino, 'local r, why = BG.War.SaveOp(nil, { title = "La mía", start = time() + 3600 }) return tostring(why)');
  if (denied !== 'permiso') return `un miembro planeó: ${denied}`;
  await clearNotice(peregrino, bruno);
  op = await get(rina, `return assert(BG.War.SaveOp(nil, { title = "Defensa del Molino", kind = "DEFENSE", start = time() + 7200, place = "Molino de Tarren", squads = { ${JSON.stringify(lobos)} } })).id`);
  await net.advance(4);
  const e = await notice(peregrino);
  if (!e.startsWith('Nueva operación') || !e.includes('Molino de Tarren')) return `aviso a Peregrino: ${e}`;
  const b = await notice(bruno);
  if (b !== '') return `aviso a Bruno (no lo llaman): ${b}`;
  await peregrino.run(`assert(BG.War.Answer(${JSON.stringify(op)}, "GO"))`);
  await bruno.run(`assert(BG.War.Answer(${JSON.stringify(op)}, "MAYBE"))`);
  await net.advance(4);
  const n = await get(rina, `local n = BG.War.Count(${JSON.stringify(op)}) return n.GO .. "|" .. n.MAYBE .. "|" .. n.NO`);
  return n === '1|1|0' || `respuestas: ${n}`;
});

await t.check('en marcha: la alerta llega a quien llaman y no a los demás', async () => {
  const denied = await get(peregrino, `local r, why = BG.War.Start(${JSON.stringify(op)}) return tostring(why)`);
  if (denied !== 'permiso') return `un miembro la puso en marcha: ${denied}`;
  await clearNotice(peregrino, bruno, tarek);
  await rina.run(`assert(BG.War.Start(${JSON.stringify(op)}))`);
  await net.advance(4);
  const e = await notice(peregrino);
  if (!e.startsWith('¡Operación en marcha!') || !e.includes('Molino de Tarren')) return `a Peregrino: ${e}`;
  const p = await notice(tarek);
  return p === '' || `a Tarek (no lo llaman): ${p}`;
});

await t.check('recordatorio un cuarto de hora antes a quien dijo «Voy»', async () => {
  const soon = await get(bruno, 'return assert(BG.War.SaveOp(nil, { title = "Asalto a la torre", start = time() + 600 })).id');
  await net.advance(4);
  await peregrino.run(`assert(BG.War.Answer(${JSON.stringify(soon)}, "GO"))`);
  await clearNotice(peregrino, rina);
  await net.advance(70, 1);
  const e = await notice(peregrino);
  const r = await notice(rina);
  return (e.startsWith('Operación en un rato') && !r.startsWith('Operación en un rato')) || `Peregrino: ${e}; Rina: ${r}`;
});

await t.check('parte: quien la dirige la termina; queda en la crónica con los presentes', async () => {
  const denied = await get(peregrino, `local r, why = BG.War.Finish(${JSON.stringify(op)}, "WIN", "") return tostring(why)`);
  if (denied !== 'permiso') return `un miembro escribió el parte: ${denied}`;
  await rina.run(`assert(BG.War.Finish(${JSON.stringify(op)}, "WIN", "Aguantamos el puente"))`);
  await net.advance(6);
  const rep = await get(tarek, `local r = BG.Store.Get("reports", ${JSON.stringify(op)}) return r and (r.d.result .. "|" .. table.concat(r.d.present, ",")) or "nada"`);
  if (rep !== 'WIN|Rina Dagaluna,El Peregrino') return `parte: ${rep}`;
  const status = await get(peregrino, `return BG.Store.Get("ops", ${JSON.stringify(op)}).d.status`);
  if (status !== 'DONE') return `estado: ${status}`;
  const chron = await get(bruno, 'local c = BG.Guild.Entry().chronicle local e = c and c[1] return e and e.text or ""');
  return chron.includes('Parte de «Defensa del Molino»: victoria') || `crónica: ${chron}`;
});

await t.check('chat de escuadra: solo sus miembros, por susurro', async () => {
  const before = net.wire.length;
  await peregrino.run(`assert(BG.Chat.Send("sq-" .. ${JSON.stringify(lobos)}, "Lobos, a la torre"))`);
  await net.advance(4);
  const read = (c) => get(c, `local h = BG.Chat.History("sq-" .. ${JSON.stringify(lobos)}) local l = h[#h] return l and l.text or "nada"`);
  const [r, p, b] = [await read(rina), await read(tarek), await read(bruno)];
  if (r !== 'Lobos, a la torre' || p !== 'nada' || b !== 'nada') return `Rina ${r}; Tarek ${p}; Bruno ${b}`;
  const guild = net.wire.slice(before).filter((f) => f.msg.includes('WQ:') && f.dist !== 'WHISPER');
  if (guild.length) return 'el chat de escuadra salió a toda la hermandad';
  const outsider = await get(tarek, `local ok, why = BG.Chat.Send("sq-" .. ${JSON.stringify(lobos)}, "hola") return tostring(why)`);
  return outsider === 'no eres de esa escuadra' || `alguien de fuera escribió: ${outsider}`;
});

await t.check('pantallas: operaciones, escuadras, partes, formularios y la pestaña del chat', async () => {
  const e = await get(peregrino, `
    BG:ShowView("war") SIM.layout(834, 604)
    local f = BG.window.viewFrames.war
    if #f.ops.items < 1 then return "sin operaciones" end
    if #f.squads.items ~= 2 then return "escuadras: " .. #f.squads.items end
    if not f.reports:GetText():find("Victoria", 1, true) then return "partes: " .. f.reports:GetText() end
    if not f.hero.sub:GetText():find("2 escuadras", 1, true) then return "cabecera: " .. f.hero.sub:GetText() end
    local out = SIM.CheckLayout(f)
    if #out > 0 then return "se sale: " .. out[1] end
    BG:ShowView("chat") SIM.layout(834, 604)
    local c = BG.window.viewFrames.chat
    local tab = c.railButtons["sq-" .. ${JSON.stringify(lobos)}]
    if not tab then return "sin pestaña de la escuadra" end
    tab:Click()
    if not c.main.title:GetText():find("Los Lobos", 1, true) then return "título: " .. c.main.title:GetText() end
    return true`);
  if (e !== true) return e;
  return get(tarek, `
    BG:ShowView("war") SIM.layout(834, 604)
    local f = BG.window.viewFrames.war
    f.opForm:Open(nil)
    if not f.opForm:IsShown() then return "no abre el formulario de operación" end
    local out = SIM.CheckLayout(f)
    if #out > 0 then return "se sale (formulario): " .. out[1] end
    f.opForm.back:Click()
    f.squadForm:Open(BG.Store.Get("squads", ${JSON.stringify(lobos)}))
    if not f.squadForm.members:GetText():find("El Peregrino", 1, true) then return "miembros: " .. f.squadForm.members:GetText() end
    f.squadForm.back:Click()
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
