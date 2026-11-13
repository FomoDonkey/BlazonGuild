// The rest of entrega 6 (0.22.0) with two guilds in an alliance: the leader guild's signed acts (a letter to the
// masters, read and counted; hiding someone in the alliance's chats; the doors for new players; an operation of the
// whole alliance in every guild's war room, with each guild's answers counted back), nobody else can issue them,
// and the alliance's chat through a channel of the game (hidden from the chat windows, a forged line refused,
// each line taken once), and the screens.
import { createNetwork, checklist } from './harness.mjs';

const B = 'Los Templarios';
const P = {
  tarek: { first: 'Tarek', second: 'Vientoalto', guid: 'Player-6842-SIMA', rosterIndex: 1 }, // Maestro de C A Ñ A D A
  bruno: { first: 'Bruno', second: 'Hierrosol', guid: 'Player-6842-SIMD', rosterIndex: 3 }, // Oficial
  peregrino: { first: 'El', second: 'Peregrino', guid: 'Player-6842-0A1B2C3D', rosterIndex: 2 }, // Miembro
  gema: { first: 'Gema', second: 'Fuego', guid: 'Player-6850-GEMA', rosterIndex: 1, guild: B }, // Maestra
  ramiro: { first: 'Ramiro', second: 'Escudo', guid: 'Player-6850-RAMI', rosterIndex: 3, guild: B }, // Oficial
  lia: { first: 'Lia', second: 'Sombra', guid: 'Player-6850-LIAS', rosterIndex: 5, guild: B }, // Miembro
};
const net = await createNetwork(Object.values(P));
const [tarek, bruno, peregrino, gema, ramiro, lia] = net.clients;
await net.loginAll();
for (const c of net.clients) await c.run('BG.Consent.Accept() BG.Alliance.REFRESH_EVERY = 20');
await net.advance(30, 0.5);
const get = net.get;
const t = checklist('comprobaciones de las cartas, los avisos y el canal de la alianza');
const notice = (c) => get(c, 'return BG.lastNotice and (BG.lastNotice.title .. "|" .. (BG.lastNotice.text or "")) or ""');
const KEY_B = `EU|${B}`;

// The alliance: Tarek founds it (his guild leads), Gema accepts.
await tarek.run('assert(BG.Alliance.Create("Alianza del León"))');
await net.advance(4);
await tarek.run('INV = nil assert(BG.Alliance.Invite("Lia Sombra", function(t) INV = t end))');
await net.advance(6);
const token = await get(tarek, 'return INV');
await gema.run(`assert(BG.Alliance.Accept(${JSON.stringify(token)}))`);
await net.advance(60);
await net.advance(150, 1); // (signers settle, presence goes round, the channel is joined)

await t.check('la alianza está lista: dos hermandades, y lidera la fundadora', async () => {
  const r = await get(lia, 'local d = BG.Alliance.Doc() local l = BG.Alliance.LeaderGuild() return d and (#d.guilds .. "|" .. l.n) or "nada"');
  const may = await get(tarek, 'return tostring(BG.AllianceActs.MayLead())');
  return (r === '2|C A Ñ A D A' && may === 'true') || `${r}; Tarek puede: ${may}`;
});

await t.check('carta: solo la manda el liderazgo; la leen los maestros (no los miembros) y se cuenta quién la leyó', async () => {
  const member = await get(peregrino, 'local r, w = BG.AllianceActs.Letter("Hola", "Texto") return tostring(w)');
  const other = await get(gema, 'local r, w = BG.AllianceActs.Letter("Hola", "Texto") return tostring(w)');
  if (member !== 'permiso' || other !== 'permiso') return `un miembro: ${member}; otra hermandad: ${other}`;
  await tarek.run('assert(BG.AllianceActs.Letter("Defensa del sábado", "Cada hermandad trae diez personas al Molino de Tarren a las 21:00.", false))');
  await net.advance(20);
  const g = await get(gema, 'local l = BG.AllianceActs.Letters()[1] return l and (l.title .. "|" .. l.from .. "|" .. l.guild .. "|" .. tostring(l.read)) or "nada"');
  const liaSees = await get(lia, 'return #BG.AllianceActs.Letters()');
  const unread = await get(gema, 'return BG.AllianceActs.Unread()');
  if (g !== 'Defensa del sábado|Tarek Vientoalto|C A Ñ A D A|false' || liaSees !== 0 || unread !== 1) return `Gema: ${g} (sin leer ${unread}); Lia ve ${liaSees}`;
  await gema.run('assert(BG.AllianceActs.MarkRead(BG.AllianceActs.Letters()[1].id))');
  await net.advance(12);
  const count = await get(tarek, 'local l = BG.AllianceActs.Letters()[1] return l.readers .. "|" .. tostring(l.mine)');
  const later = await get(bruno, 'local l = BG.AllianceActs.Letters()[1] return l and l.readers or -1');
  return (count === '1|true' && later === 1) || `Tarek ve leída por ${count}; Bruno ${later}`;
});

await t.check('nadie de otra hermandad puede hacerse pasar por el líder (firma de su propia clave)', async () => {
  await ramiro.run(`BG.Sign.Ensure(function()
    local d = BG.Alliance.Doc()
    local b = { a = d.id, i = "falsa", k = "dr", f = "Tarek Vientoalto", g = "EU|C A Ñ A D A", at = BG.Store.Now(), v = 9,
      x = BG.Serial.Encode({ to = ${JSON.stringify(KEY_B)}, u = BG.Store.Now() + 9999 }) }
    BG.Sign.Sign(BG.AllianceRules.ActText(d.id, b), function(s, pk)
      b.s, b.p = s, pk
      BG.Comm.Send("LA", b, "WHISPER", "Bruno Hierrosol")
      BG.Comm.Send("LA", b, "GUILD")
    end)
  end)`);
  await net.advance(10);
  const a = await get(bruno, 'return tostring(BG.AllianceActs.Doors() ~= nil)');
  const b = await get(lia, 'return tostring(BG.AllianceActs.Doors() ~= nil)');
  return (a === 'false' && b === 'false') || `puertas falsas: Bruno ${a}, Lia ${b}`;
});

await t.check('puertas abiertas: la alianza manda a los nuevos a una hermandad unas horas; se ve en Reclutamiento', async () => {
  await tarek.run(`assert(BG.AllianceActs.OpenDoors(${JSON.stringify(KEY_B)}, 2))`);
  await net.advance(15);
  const lia2 = await get(lia, 'local d = BG.AllianceActs.Doors() return d and d.name or "cerradas"');
  const sub = await get(peregrino, 'BG:ToggleWindow() BG:ShowView("recruit") SIM.layout(834, 604) return BG.window.viewFrames.recruit.hero.sub:GetText()');
  await tarek.run('assert(BG.AllianceActs.CloseDoors())');
  await net.advance(15);
  const closed = await get(lia, 'return tostring(BG.AllianceActs.Doors() == nil)');
  return (lia2 === B && sub.includes('«Los Templarios»') && closed === 'true') || `Lia: ${lia2}; Reclutamiento: ${sub}; al cerrar: ${closed}`;
});

await t.check('ocultar en la alianza: sus líneas no salen en ninguna hermandad hasta que se quita', async () => {
  await tarek.run('assert(BG.AllianceActs.Hide("Lia Sombra", 1, "insultos"))');
  await net.advance(15);
  const lines = (c) => get(c, 'local n = 0 for _, l in ipairs(BG.Chat.History("ally")) do if l.text == "hola a todos" then n = n + 1 end end return n');
  await lia.run('BG.Chat.Send("ally", "hola a todos")');
  await net.advance(10);
  const hiddenE = await lines(peregrino);
  const hiddenR = await lines(ramiro);
  const list = await get(ramiro, 'local h = BG.AllianceActs.Hidden()[1] return h and (h.label .. "|" .. h.why) or "nada"');
  const memberList = await get(lia, 'BG:ToggleWindow() BG:ShowView("alliance") local f = BG.window.viewFrames.alliance f.tabs.buttons[2]:Click() SIM.layout(834, 604) return #f.hides.items');
  if (hiddenE !== 0 || hiddenR !== 0 || list !== 'Lia Sombra|insultos' || memberList !== 0) return `Peregrino ${hiddenE}, Ramiro ${hiddenR}; lista de Ramiro ${list}; Lia ve ${memberList}`;
  await tarek.run('assert(BG.AllianceActs.Unhide(BG.AllianceActs.Hidden()[1].id))');
  await net.advance(15);
  await lia.run('BG.Chat.Send("ally", "ya puedo hablar")');
  await net.advance(10);
  const back = await get(peregrino, 'local n = 0 for _, l in ipairs(BG.Chat.History("ally")) do if l.text == "ya puedo hablar" then n = n + 1 end end return n');
  return back === 1 || `al quitarlo, Peregrino ve la línea ${back} veces`;
});

await t.check('operación de toda la alianza: llega a la sala de guerra de la otra hermandad, que responde; el líder ve cuántos van', async () => {
  await tarek.run(`assert(BG.War.SaveOp(nil, { title = "Asalto a Molino", kind = "PVP", start = time() + 7200, place = "Molino de Tarren", ally = true }))`);
  await net.advance(15);
  const copy = await get(lia, 'for _, op in ipairs(BG.War.Ops()) do if op.d.ally then return op.d.title .. "|" .. op.d.ally.n .. "|" .. tostring(BG.War.CanRun(op)) .. "|" .. tostring(BG.War.Called(op, "Lia Sombra")) end end return "nada"');
  if (copy !== 'Asalto a Molino|C A Ñ A D A|false|true') return `copia de Lia: ${copy}`;
  const denied = await get(ramiro, 'for _, op in ipairs(BG.War.Ops()) do if op.d.ally then local r, w = BG.War.Start(op.id) return tostring(w) end end return "nada"');
  if (denied !== 'permiso') return `Ramiro la empezó: ${denied}`;
  await lia.run('for _, op in ipairs(BG.War.Ops()) do if op.d.ally then assert(BG.War.Answer(op.id, "GO")) end end');
  await net.advance(70, 1);
  const counts = await get(bruno, `for _, op in ipairs(BG.War.Ops()) do if op.d.ally then local c = BG.AllianceActs.Counts(op.d.ally.i)[${JSON.stringify(KEY_B)}] return c and (c.name .. "|" .. c.y) or "sin cuentas" end end return "nada"`);
  if (counts !== `${B}|1`) return `cuentas que ve Bruno: ${counts}`;
  await tarek.run('for _, op in ipairs(BG.War.Ops()) do if op.d.ally then assert(BG.War.Start(op.id)) end end');
  await net.advance(15);
  const active = await get(lia, 'for _, op in ipairs(BG.War.Ops()) do if op.d.ally then return op.d.status end end return "nada"');
  return active === 'ACTIVE' || `al empezarla, Lia la ve ${active}`;
});

await t.check('canal de la alianza: cada uno está dentro, oculto de las ventanas de chat, y sus líneas llegan una sola vez', async () => {
  const names = [];
  for (const c of [peregrino, lia, gema]) names.push(await get(c, 'return tostring(BG.AllianceHall.Name()) .. "|" .. tostring(BG.AllianceHall.On()) .. "|" .. tostring(SIM.removedChannels[BG.AllianceHall.Name() or ""])'));
  if (new Set(names).size !== 1 || !names[0].endsWith('|true|true')) return `canales: ${names.join(' / ')}`;
  const before = await get(gema, 'return BG.AllianceHall.stats.heard');
  await peregrino.run('BG.Chat.Send("ally", "por el canal")');
  await net.advance(10);
  const heard = await get(gema, 'return BG.AllianceHall.stats.heard');
  const shown = await get(gema, 'local n = 0 for _, l in ipairs(BG.Chat.History("ally")) do if l.text == "por el canal" then n = n + 1 end end return n');
  const filtered = await get(gema, `local hidden = true for _, fn in ipairs(SIM.filters.CHAT_MSG_CHANNEL or {}) do end
    local name = BG.AllianceHall.Name() local any = false
    for _, fn in ipairs(SIM.filters.CHAT_MSG_CHANNEL or {}) do if fn(ChatFrame1, "CHAT_MSG_CHANNEL", "BG1~x", "Alguien", "", "5. " .. name, "Alguien", "", 0, 5, name) then any = true end end
    return tostring(any)`);
  return (heard > before && shown === 1 && filtered === 'true') || `oído ${before}->${heard}; se ve ${shown} veces; oculto de las ventanas ${filtered}`;
});

await t.check('canal: una línea falsa (sin la marca, o en nombre de otro) no entra', async () => {
  await lia.run(`local name = BG.AllianceHall.Name() local i = GetChannelName(name)
    local code = BG.Alliance.Code(${JSON.stringify(KEY_B)})
    SendChatMessage("BG1~ally~Falsa-1~" .. code .. "~MAGE~000000000000~soy falsa", "CHANNEL", nil, i)
    local good = BG.Alliance.Tag("AC" .. "Falsa-2")
    SendChatMessage("BG1~ally~Falsa-2~" .. code .. "~MAGE~" .. good .. "~en nombre de otro", "CHANNEL", nil, i)`);
  await net.advance(6);
  const r = await get(peregrino, 'local n = 0 for _, l in ipairs(BG.Chat.History("ally")) do if l.text == "soy falsa" then n = n + 1 end end return n');
  // (the second one is Lia's own, with a good mark: it does come in, as hers)
  const own = await get(peregrino, 'for _, l in ipairs(BG.Chat.History("ally")) do if l.text == "en nombre de otro" then return l.from end end return "nada"');
  return (r === 0 && own === 'Lia Sombra') || `falsa: ${r}; la otra, de ${own}`;
});

await t.check('pantallas: «Cartas y avisos» para el líder y para otra maestra, y la operación de la alianza en la sala de guerra', async () => {
  const out = [];
  for (const c of [tarek, gema]) {
    out.push(await get(c, `BG:ToggleWindow() BG:ShowView("alliance") SIM.layout(834, 604)
      local f = BG.window.viewFrames.alliance f.tabs.buttons[2]:Click() SIM.layout(834, 604)
      local lay = table.concat(SIM.CheckLayout(f), " ; ")
      local compose = f.acts.letters.send:IsShown()
      f.tabs.buttons[1]:Click() SIM.layout(834, 604)
      local lay2 = table.concat(SIM.CheckLayout(f), " ; ")
      f.tabs.buttons[3]:Click() SIM.layout(834, 604)
      lay2 = lay2 .. table.concat(SIM.CheckLayout(f), " ; ")
      f.tabs.buttons[1]:Click()
      BG:ShowView("war") SIM.layout(834, 604)
      local w = BG.window.viewFrames.war
      local lay3 = table.concat(SIM.CheckLayout(w), " ; ")
      return #f.letters.items .. "|" .. tostring(compose) .. "|" .. lay .. "|" .. lay2 .. "|" .. lay3`));
  }
  return (out[0] === '1|true|||' && out[1] === '1|false|||') || out.join(' // ');
});

await t.check('en los 6 idiomas: las tres pestañas de la Alianza y la Sala de guerra caben, sin restos en español', async () => {
  const bad = [];
  for (const lang of ['en', 'de', 'fr', 'it', 'pt', 'ru']) {
    // (as after /reload in the game: the screens are built again in the new language)
    const r = await get(tarek, `BG.db.settings.lang = "${lang}" BG.Locale.Init()
      for _, k in ipairs({ "alliance", "war" }) do local v = BG.window.viewFrames[k] if v then v:Hide() end BG.window.viewFrames[k] = nil end
      BG:ShowView("alliance") SIM.layout(834, 604)
      local f = BG.window.viewFrames.alliance
      local out, texts = {}, {}
      for i = 1, 3 do
        f.tabs.buttons[i]:Click() SIM.layout(834, 604)
        for _, p in ipairs(SIM.CheckLayout(f)) do out[#out + 1] = i .. ": " .. p end
      end
      f.tabs.buttons[2]:Click() SIM.layout(834, 604)
      texts[#texts + 1] = f.acts.side.doors:GetText() texts[#texts + 1] = f.acts.side.hideText:GetText()
      texts[#texts + 1] = f.letters.rows[1] and f.letters.rows[1].sub:GetText() or ""
      f.tabs.buttons[3]:Click() SIM.layout(834, 604)
      texts[#texts + 1] = f.manage.cargo.text:GetText() texts[#texts + 1] = f.manage.cargo.list:GetText()
      f.tabs.buttons[1]:Click()
      BG:ShowView("war") SIM.layout(834, 604)
      local w = BG.window.viewFrames.war
      for _, p in ipairs(SIM.CheckLayout(w)) do out[#out + 1] = "war: " .. p end
      texts[#texts + 1] = w.ops and w.ops.rows and w.ops.rows[1] and w.ops.rows[1].sub:GetText() or ""
      return table.concat(out, " ; ") .. " ## " .. table.concat(texts, " || ")`);
    const [lay, texts] = r.split(' ## ');
    const spanish = texts.match(lang === 'fr' ? /(Cerradas|Nadie|hermandad|alianza|capitanes|Dirige)/i : /(Cerradas|Nadie|hermandad|alianza|capitanes|Dirige|JcJ)/i);
    if (lay || (spanish && lang !== 'pt' && lang !== 'it')) bad.push(`${lang}: ${lay} ${spanish ? '«' + spanish[0] + '» en ' + texts : ''}`);
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
