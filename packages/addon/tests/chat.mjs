// Entrega 4 in a simulated guild: the game's guild chat inside BlazonGuild, rooms (built-in and created by a
// member), safe text, and moderation by organisers (mute with durations, warnings that open a case only the
// master decides, deleting a line, word filter, reports, a mute that follows a shared BattleTag, hiding).
import { createNetwork, checklist } from './harness.mjs';

const P = {
  tarek: { first: 'Tarek', second: 'Vientoalto', guid: 'Player-6842-SIMA', rosterIndex: 1 }, // Maestro
  bruno: { first: 'Bruno', second: 'Hierrosol', guid: 'Player-6842-SIMD', rosterIndex: 3 }, // Oficial
  peregrino: { first: 'El', second: 'Peregrino', guid: 'Player-6842-0A1B2C3D', rosterIndex: 2 }, // Miembro
  rina: { first: 'Rina', second: 'Dagaluna', guid: 'Player-6842-SIMB', rosterIndex: 5 }, // Miembro
  brasa: { first: 'Sr', second: 'Brasa', guid: 'Player-6842-SIMC', rosterIndex: 7 }, // Rina's other character (same BattleTag)
};
const net = await createNetwork([P.tarek, P.bruno, P.peregrino, P.rina, P.brasa]);
const [tarek, bruno, peregrino, rina, brasa] = net.clients;
await net.loginAll();
for (const c of net.clients) await c.run('BG.Consent.Accept()');
await rina.run('SIM.battletag = "Rina#1234"');
await brasa.run('SIM.battletag = "Rina#1234"');
await net.advance(30);
const get = net.get;
const t = checklist('comprobaciones del chat y la moderación');

await t.check('el chat de hermandad del juego aparece en BlazonGuild y se escribe desde él', async () => {
  await peregrino.run('SIM.fire("CHAT_MSG_GUILD", "¿Alguien para Mazmorras?", "Rina Dagaluna-ForeverPvP2", "", "", "", "", 0, 0, "", 0, 77, "Player-6842-SIMB")');
  const line = await get(peregrino, 'local h = BG.Chat.History("guild") local l = h[#h] return l.from .. "|" .. l.text .. "|" .. tostring(l.class)');
  if (line !== 'Rina Dagaluna|¿Alguien para Mazmorras?|' + 'ROGUE' && !line.startsWith('Rina Dagaluna|¿Alguien para Mazmorras?|')) return line;
  await peregrino.run('assert(BG.Chat.Send("guild", "¡Yo voy!"))');
  const sent = await get(peregrino, 'local m = SIM.chat[#SIM.chat] return m.chatType .. "|" .. m.msg');
  return sent === 'GUILD|¡Yo voy!' || sent;
});

await t.check('texto seguro: los enlaces de objetos se quedan; texturas y códigos raros, no', async () => {
  const r = await get(peregrino, `
    local link = "|cff0070dd|Hitem:16800::::::::60:::::|h[Botas de Arcanista]|h|r"
    local s = BG.Chat.Sanitize("mira " .. link .. " |TInterface/Icons/x:64|t y |Kq1|k fin")
    if not s:find(link, 1, true) then return "perdió el enlace: " .. s end
    if s:find("|T", 1, true) or s:find("|K", 1, true) then return "dejó códigos: " .. s end
    -- Newer clients colour links by name (quality 3): Peregrino saw them broken in 0.10.0.
    local named = "|cnIQ3:|Hitem:211527::::::::22:1488::11:::::::|h[Saco de dormir acogedor]|h|r"
    if BG.Chat.Sanitize(named) ~= named then return "enlace con color por nombre: " .. BG.Chat.Sanitize(named) end
    local broken = "/cnIQ3:/Hitem:211527::::::::22:1488::11:::::::/h[Saco de dormir acogedor]/h/r"
    if BG.Chat.RepairLinks(broken) ~= named then return "no repara el enlace roto: " .. BG.Chat.RepairLinks(broken) end
    return true`);
  return r;
});

await t.check('salas: lo que se escribe en Sanadores le llega a todos, con avisos de no leído', async () => {
  await peregrino.run('assert(BG.Chat.Send("healers", "Asigno: yo al tanque principal"))');
  await net.advance(4);
  const seen = await get(rina, 'local h = BG.Chat.History("healers") local l = h[#h] return l and (l.from .. ": " .. l.text) or "nada"');
  const unread = await get(rina, 'return BG.Chat.TotalUnread()');
  return (seen === 'El Peregrino: Asigno: yo al tanque principal' && unread >= 1) || `${seen} (sin leer ${unread})`;
});

await t.check('cualquier miembro crea una sala y todos la ven', async () => {
  const id = await get(rina, 'local r = assert(BG.Chat.CreateRoom("Raid del viernes", "Coordinación de la raid")) return r.id');
  await net.advance(4);
  await peregrino.run(`assert(BG.Chat.Send(${JSON.stringify(id)}, "Llevo frascos"))`);
  await net.advance(4);
  const names = await get(tarek, 'local n = {} for _, r in ipairs(BG.Chat.Rooms()) do n[#n + 1] = r.name end return table.concat(n, ",")');
  const line = await get(tarek, `local h = BG.Chat.History(${JSON.stringify(id)}) return h[1] and h[1].text or "nada"`);
  return (names.includes('Raid del viernes') && line === 'Llevo frascos') || `${names} / ${line}`;
});

await t.check('silenciar 5 minutos: no puede escribir, sus mensajes no llegan, y después sí', async () => {
  const muted = await get(bruno, 'local m = BG.Chat.Mute("Rina Dagaluna", 1, "spam") return table.concat(m, ",")');
  await net.advance(4);
  const refused = await get(rina, 'local ok, why = BG.Chat.Send("trade", "vendo oro") return tostring(why)');
  if (!refused.startsWith('silenciado hasta las')) return `Rina pudo escribir: ${refused}`;
  await rina.run('BG.Comm.Send("CM", { r = "trade", t = "vendo oro barato", i = "x1" }, "GUILD")');
  await net.advance(4);
  const leaked = await get(peregrino, 'local h = BG.Chat.History("trade") for _, l in ipairs(h) do if l.from == "Rina Dagaluna" then return "sí" end end return "no"');
  if (leaked !== 'no') return 'su mensaje forzado llegó';
  await net.advance(310, 1);
  const after = await get(rina, 'local ok, why = BG.Chat.Send("trade", "ya puedo") return tostring(ok)');
  return (muted.includes('Rina Dagaluna') && after === 'true') || `silenciados ${muted}; después: ${after}`;
});

await t.check('el silencio sigue al BattleTag (solo de quien lo comparte, y solo lo ven los organizadores)', async () => {
  await rina.run('BG.Consent.SetLine("battletag", true)');
  await brasa.run('BG.Consent.SetLine("battletag", true)');
  await net.advance(8);
  const tags = await get(bruno, 'local t = BG.Chat.Tags() return tostring(t["Rina Dagaluna"]) .. "|" .. tostring(t["Sr Brasa"])');
  if (tags !== 'Rina#1234|Rina#1234') return `etiquetas en el organizador: ${tags}`;
  const leakedTag = net.wire.some((f) => f.dist === 'GUILD' && f.msg.includes('Rina#1234'));
  if (leakedTag) return 'el BattleTag salió por el canal de la hermandad';
  const member = await get(peregrino, 'return tostring(BG.Chat.Tags()["Rina Dagaluna"])');
  if (member !== 'nil') return 'un miembro conoce el BattleTag';
  const muted = await get(bruno, 'local m = BG.Chat.Mute("Rina Dagaluna", 2, "insultos") table.sort(m) return table.concat(m, ",")');
  await net.advance(4);
  const novaMuted = await get(peregrino, 'return BG.Chat.MutedUntil("Sr Brasa") and "sí" or "no"');
  return (muted === 'Rina Dagaluna,Sr Brasa' && novaMuted === 'sí') || `silenciados ${muted}; Sr Brasa silenciado para Peregrino: ${novaMuted}`;
});

let caseId;
await t.check('al tercer aviso se abre un caso; opinan los organizadores y decide solo el maestro; casos y avisos solo están en el ordenador de los organizadores', async () => {
  await bruno.run('BG.Chat.Mute("Rina Dagaluna", 1, "tercera")');
  await net.advance(4);
  caseId = await get(tarek, 'local c = BG.Chat.Cases()[1] return c and c.id or "nada"');
  if (caseId === 'nada') return 'no se abrió el caso';
  await bruno.run(`assert(BG.Chat.Vote(${JSON.stringify(caseId)}, "WARN"))`);
  const bad = await get(bruno, `local r, why = BG.Chat.Decide(${JSON.stringify(caseId)}, "KICK") return tostring(why)`);
  if (bad !== 'permiso') return `un oficial pudo decidir: ${bad}`;
  // a member tries to decide it himself (he does not even have it: he makes one up with its id)
  await peregrino.run(`
    BG.Comm.Send("RC", { c = "cases", r = { id = ${JSON.stringify(caseId)}, rev = 50, at = BG.Store.Now(), by = "El Peregrino", d = { target = "Rina Dagaluna", decision = "NOTHING" } } }, "GUILD")`);
  await net.advance(4);
  await tarek.run(`assert(BG.Chat.Decide(${JSON.stringify(caseId)}, "KICK"))`);
  await net.advance(4);
  const seen = await get(bruno, `local c = BG.Store.Get("cases", ${JSON.stringify(caseId)}) return c.d.status .. "|" .. tostring(c.d.decision) .. "|" .. tostring(c.d.votes["Bruno Hierrosol"])`);
  if (seen !== 'DECIDED|KICK|WARN') return `caso visto por Bruno: ${seen}`;
  // cases and warnings are only on the organisers' computers, never on a member's (also not Rina's own)
  const onMembers = await get(peregrino, 'return #BG.Store.List("cases") + #BG.Store.List("strikes")') + await get(rina, 'return #BG.Store.List("cases") + #BG.Store.List("strikes")');
  if (onMembers !== 0) return `${onMembers} casos o avisos en el ordenador de un miembro`;
  const reopen = await get(tarek, `local r, why = BG.Chat.Decide(${JSON.stringify(caseId)}, "NOTHING") return tostring(why)`);
  const kicked = await get(tarek, 'return tostring(GuildUninvite ~= nil and SIM.uninvited)');
  return (reopen === 'permiso' && kicked !== 'true') || `reabrir: ${reopen}; expulsión automática: ${kicked}`;
});

await t.check('borrar un mensaje de una sala y filtrar palabras (solo organizadores)', async () => {
  await peregrino.run('assert(BG.Chat.Send("help", "esto es un mensaje tonto"))');
  await net.advance(4);
  const id = await get(bruno, 'local h = BG.Chat.History("help") return h[#h].id');
  const memberTry = await get(peregrino, 'local r, why = BG.Store.Put("filter", "guild", { words = { "hola" } }) return tostring(why)');
  if (memberTry !== 'permiso') return `un miembro cambió el filtro: ${memberTry}`;
  await bruno.run(`assert(BG.Chat.Delete("help", ${JSON.stringify(id)})) assert(BG.Store.Put("filter", "guild", { words = { "tonto" } }))`);
  await net.advance(4);
  const shown = await get(rina, `
    local h = BG.Chat.History("help")
    local deleted = BG.Chat.FormatLine("help", #h, h[#h])
    local filtered = BG.Chat.ApplyFilter("Qué TONTO eres")
    return tostring(deleted:find("borrado por la moderación") ~= nil) .. "|" .. filtered`);
  return shown === 'true|Qué ***** eres' || shown;
});

await t.check('denunciar: llega solo a los organizadores conectados', async () => {
  const n = await get(rina, 'return BG.Chat.Report({ from = "Sr Brasa", text = "mensaje feo" }, "trade", "insulto")');
  await net.advance(4);
  const got = await get(tarek, 'local r = BG.Chat.Reports()[1] return r and (r.by .. ">" .. r.who .. ": " .. r.text) or "nada"');
  const member = await get(peregrino, 'return #BG.Chat.Reports()');
  return (n === 2 && got === 'Rina Dagaluna>Sr Brasa: mensaje feo' && member === 0) || `enviadas ${n}, maestro: ${got}, miembro: ${member}`;
});

await t.check('ocultar a alguien solo en mi chat', async () => {
  await peregrino.run('BG.Chat.SetHidden("Rina Dagaluna", true)');
  const r = await get(peregrino, `
    BG:ToggleWindow() SIM.layout(834, 604)
    BG:ShowView("chat") SIM.layout(834, 604)
    local f = BG.window.viewFrames.chat
    f.select("trade")
    for _, l in ipairs(f.log.__lines or {}) do if l:find("Rina Dagaluna", 1, true) then return "se ve" end end
    BG.Chat.SetHidden("Rina Dagaluna", false)
    return true`);
  return r;
});

await t.check('pantalla: canales, salas, moderación solo para organizadores y oficiales según rango', async () => {
  const member = await get(peregrino, `
    local f = BG.window.viewFrames.chat
    f.select("healers")
    local lines = table.concat(f.log.__lines or {}, "\\n")
    if not lines:find("Asigno: yo al tanque principal", 1, true) then return "no muestra la sala: " .. lines end
    if f.deskBtn:IsShown() then return "un miembro ve Moderación" end
    if f.railButtons.officer then return "un miembro ve Oficiales" end
    if not f.cta:IsShown() then return "sin alianza no invita a ver la alianza" end
    local lay = SIM.CheckLayout(f) if #lay > 0 then return "Chat se sale o se monta: " .. lay[1] end
    return true`);
  if (member !== true) return member;
  return await get(bruno, `
    BG:ToggleWindow() SIM.layout(834, 604)
    BG:ShowView("chat") SIM.layout(834, 604)
    local f = BG.window.viewFrames.chat
    if not f.deskBtn:IsShown() then return "el oficial no ve Moderación" end
    f.select("desk")
    if not f.desk:IsShown() then return "no abre la mesa" end
    if #f.desk.cases.items < 1 then return "sin casos en la mesa" end
    local lay = SIM.CheckLayout(f) if #lay > 0 then return "Moderación se sale o se monta: " .. lay[1] end
    return true`);
});

await t.check('un aluvión de líneas de una persona se corta (8 cada 10 s)', async () => {
  await tarek.run('for i = 1, 14 do BG.Comm.Send("CM", { r = "dps", t = "spam " .. i, i = "s" .. i }, "GUILD") end');
  await net.advance(30);
  const n = await get(peregrino, 'local n = 0 for _, l in ipairs(BG.Chat.History("dps")) do if l.from == "Tarek Vientoalto" then n = n + 1 end end return n');
  return (n >= 8 && n < 14) || `${n} líneas aceptadas de 14`;
});

await t.check('lo que se dijo mientras no estabas te lo pasa un compañero (lo diga quien lo diga)', async () => {
  // Lunita has no addon: what she says in guild chat reaches everyone's BlazonGuild anyway (the game sends
  // guild chat to every member online).
  for (const c of net.clients) {
    await c.run('SIM.fire("CHAT_MSG_GUILD", "que trabajito ha costao niño", "Lunita Porvenir-ForeverPvP", "", "", "", "", 0, 0, "", 0, 91, "Player-6842-MOJA")');
    await c.run('SIM.fire("CHAT_MSG_GUILD", "¿Quién viene a Brazanegra?", "Tarek Vientoalto-ForeverPvP", "", "", "", "", 0, 0, "", 0, 92, "Player-6842-SIMA")');
  }
  const atPeregrino = await get(peregrino, 'local h = BG.Chat.History("guild") return h[#h - 1].from .. ": " .. h[#h - 1].text');
  if (atPeregrino !== 'Lunita Porvenir: que trabajito ha costao niño') return `Peregrino ve: ${atPeregrino}`;
  const late = await net.add({ first: 'Lola', second: 'Tardía', guid: 'Player-6842-LOLA', rosterIndex: 9 });
  await late.login();
  await late.run('BG.Consent.Accept()');
  await net.advance(40, 0.5);
  const r = await get(late, 'local o = {} for _, l in ipairs(BG.Chat.History("guild")) do o[#o+1] = l.from .. ": " .. l.text end return table.concat(o, " / ")');
  return (r.includes('Lunita Porvenir: que trabajito ha costao niño') && r.includes('Tarek Vientoalto: ¿Quién viene a Brazanegra?')) || `Lola ve: ${r}`;
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
