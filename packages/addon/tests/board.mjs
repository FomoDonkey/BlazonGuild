// Entrega 5 in a simulated guild: announcements with read receipts, polls, the speaking queue, calls to arms
// with a map pin, the chronicle from roster changes, the welcome for a new organiser, release letters,
// questions and answers, and the Tablón screen with real data.
import { createNetwork, checklist, addonVersion } from './harness.mjs';

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
await net.advance(30);
const get = net.get;
const t = checklist('comprobaciones del tablón');

let newsId;
await t.check('anuncios: solo organizadores; todos los ven y se sabe quién los ha leído', async () => {
  const denied = await get(peregrino, 'local r, why = BG.Board.Post("Hola", "texto") return tostring(why)');
  if (denied !== 'permiso') return `un miembro publicó: ${denied}`;
  newsId = await get(tarek, 'local r = assert(BG.Board.Post("Raid de Onyxia el sábado", "A las 21:00 en la puerta", true)) return r.id');
  await net.advance(5);
  const seen = await get(peregrino, `local n = BG.Board.News()[1] return n and (n.d.title .. "|" .. tostring(n.d.important)) or "nada"`);
  if (seen !== 'Raid de Onyxia el sábado|true') return `Peregrino ve: ${seen}`;
  const notice = await get(rina, 'return BG.lastNotice and BG.lastNotice.title or ""');
  if (notice !== 'Anuncio importante') return `aviso: ${notice}`;
  await peregrino.run(`BG.Board.MarkRead(${JSON.stringify(newsId)})`);
  await net.advance(5);
  const readers = await get(tarek, `return table.concat(BG.Board.Readers(${JSON.stringify(newsId)}), ",")`);
  return readers === 'El Peregrino' || `leído por: ${readers}`;
});

let pollId;
await t.check('encuestas: cualquiera pregunta, cada uno vota una vez y puede cambiar; cierra a su hora', async () => {
  pollId = await get(rina, 'local r = assert(BG.Board.Ask("¿Qué banda el sábado?", { "Onyxia", "Núcleo de Magma", "Zul\'Gurub" }, 15)) return r.id');
  await net.advance(5);
  await peregrino.run(`assert(BG.Board.Vote(${JSON.stringify(pollId)}, 2))`);
  await bruno.run(`assert(BG.Board.Vote(${JSON.stringify(pollId)}, 2))`);
  await tarek.run(`assert(BG.Board.Vote(${JSON.stringify(pollId)}, 1))`);
  await net.advance(5);
  await peregrino.run(`assert(BG.Board.Vote(${JSON.stringify(pollId)}, 1))`);
  const bad = await get(rina, `local r, why = BG.Board.Vote(${JSON.stringify(pollId)}, 5) return tostring(why)`);
  await net.advance(5);
  const results = await get(rina, `local c, total = BG.Board.Results(${JSON.stringify(pollId)}) return table.concat(c, "/") .. "=" .. total`);
  if (results !== '2/1/0=3' || bad !== 'datos') return `resultados ${results}, opción inexistente: ${bad}`;
  await net.advance(16 * 60, 2);
  const late = await get(bruno, `local r, why = BG.Board.Vote(${JSON.stringify(pollId)}, 3) return tostring(why)`);
  return late === 'datos' || `voto tardío: ${late}`;
});

await t.check('turnos de palabra: abre un organizador, cada uno pide turno y se da la palabra en orden', async () => {
  const denied = await get(peregrino, 'local r, why = BG.Board.OpenCourt("x") return tostring(why)');
  if (denied !== 'permiso') return `un miembro abrió los turnos: ${denied}`;
  await bruno.run('assert(BG.Board.OpenCourt("Reunión de la semana"))');
  await net.advance(4);
  await peregrino.run('assert(BG.Board.AskTurn(""))');
  await net.advance(2);
  await rina.run('assert(BG.Board.AskTurn(""))');
  await net.advance(4);
  const queue = await get(bruno, 'local q = {} for _, r in ipairs(BG.Board.Queue()) do q[#q + 1] = r.id end return table.concat(q, ",")');
  if (queue !== 'El Peregrino,Rina Dagaluna') return `cola: ${queue}`;
  await bruno.run('assert(BG.Board.NextSpeaker())');
  await net.advance(4);
  const speaker = await get(rina, 'return BG.Board.Court().d.speaker');
  const told = await get(peregrino, 'return BG.lastNotice and BG.lastNotice.title or ""');
  return (speaker === 'El Peregrino' && told === 'Tienes la palabra') || `habla ${speaker}; aviso a Peregrino: ${told}`;
});

await t.check('¡A las armas! y Reunión aquí: alerta, sonido y marca en el mapa; un miembro no puede', async () => {
  await bruno.run('assert(BG.Board.Decree("RALLY", "Todos a la puerta de Roca Negra", true))');
  await net.advance(4);
  const r = await get(peregrino, `
    local w = SIM.warnings[#SIM.warnings] or ""
    local p = SIM.waypoint
    return w .. "|" .. (p and (p.map .. ":" .. string.format("%.2f", p.x)) or "sin marca") .. "|" .. tostring(SIM.supertrack)`);
  if (r !== 'Reunión: Todos a la puerta de Roca Negra — Bruno Hierrosol|1437:0.45|true') return r;
  await rina.run('SIM.warnings = {}');
  await peregrino.run('BG.Comm.Send("DC", { k = "ARMS", t = "broma" }, "GUILD")');
  await net.advance(4);
  const fooled = await get(rina, 'return #SIM.warnings');
  return fooled === 0 || 'un miembro lanzó una alerta';
});

await t.check('crónica: entradas, salidas, ascensos y nivel 60 desde la lista de miembros', async () => {
  const pure = await get(peregrino, `
    local before = { { guid = "a", name = "Ana", rankIndex = 4, level = 59 }, { guid = "b", name = "Bea", rankIndex = 4, level = 20 } }
    local after = { { guid = "a", name = "Ana", rankIndex = 1, rank = "Oficial", level = 60 }, { guid = "c", name = "Ciro", rankIndex = 5, level = 1 } }
    local kinds = {}
    for _, e in ipairs(BG.Board.Diff(before, after, 60)) do kinds[#kinds + 1] = e.kind end
    table.sort(kinds)
    return table.concat(kinds, ",")`);
  if (pure !== 'join,leave,max,promote') return `diferencias: ${pure}`;
  await peregrino.run(`
    table.remove(SIM.roster, 30)
    SIM.roster[2][2], SIM.roster[2][3] = "Oficial", 1
    BG.Guild.Scan()`);
  const log = await get(peregrino, 'local t = {} for i, e in ipairs(BG.Board.Chronicle()) do if i <= 4 then t[#t + 1] = e.kind end end table.sort(t) return table.concat(t, ",")');
  const welcome = await get(peregrino, 'return BlazonGuildDialog and BlazonGuildDialog:IsShown() and BlazonGuildDialog.title:GetText() or ""');
  return (log.includes('leave') && log.includes('promote') && welcome.startsWith('Ahora organizas en')) || `crónica ${log}; bienvenida: ${welcome}`;
});

await t.check('resumen de la semana y carta de novedades tras actualizar', async () => {
  const week = await get(peregrino, 'local s = BG.Board.WeekSummary(BG.Board.Chronicle(7), BG.Raids.Upcoming()) return s.leave .. "/" .. s.promote');
  if (week !== '1/1') return `semana: ${week}`;
  const letter = await get(rina, `
    BlazonGuildDB.lastLetter = "0.5.0"
    if BlazonGuildDialog then BlazonGuildDialog:Hide() end
    SIM.fire("PLAYER_LOGIN")
    SIM.advance(21)
    return BlazonGuildDialog and BlazonGuildDialog:IsShown() and BlazonGuildDialog.title:GetText() or "sin carta"`);
  return letter === `Novedades de BlazonGuild ${addonVersion}` || letter;
});

await t.check('preguntas frecuentes: las básicas y las que añade un organizador', async () => {
  const denied = await get(rina, 'local r, why = BG.Store.Put("faq", "q1", { q = "¿Hora de raid?", a = "21:00" }) return tostring(why)');
  await tarek.run('assert(BG.Store.Put("faq", "q1", { q = "¿A qué hora son las raids?", a = "A las 21:00, hora del servidor." }))');
  await net.advance(4);
  const qs = await get(rina, 'local q = BG.Board.Questions() return #q .. "|" .. q[#q].q');
  return (denied === 'permiso' && qs === '28|¿A qué hora son las raids?') || `miembro: ${denied}; preguntas: ${qs}`;
});

await t.check('pantalla del Tablón con anuncios, encuesta, crónica y turnos', async () => {
  return await get(bruno, `
    BG:ToggleWindow() SIM.layout(834, 604)
    BG:ShowView("board") SIM.layout(834, 604)
    local f = BG.window.viewFrames.board
    if #f.news.items ~= 1 then return "anuncios: " .. #f.news.items end
    if not f.poll.q:GetText():find("¿Qué banda") then return "encuesta: " .. f.poll.q:GetText() end
    if not f.poll.when:GetText():find("cerrada") then return "estado: " .. f.poll.when:GetText() end
    if not f.arms:IsShown() then return "un organizador no ve ¡A las armas!" end
    if not f.court.text:GetText():find("Habla") then return "turnos: " .. f.court.text:GetText() end
    local lay = SIM.CheckLayout(f) if #lay > 0 then return "Tablón se sale o se monta: " .. lay[1] end
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
