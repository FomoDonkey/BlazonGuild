// Entrega 6 with three guilds (and one of the other faction): forming an alliance (only masters decide),
// invitations kept for the master, the signed record (nobody can forge a change), presence of each guild, the
// alliance chat (everyone, one tab per sister guild, organisers), shared role rooms, a third guild, cargos,
// the leader's vote, the alliance's call to arms, hiding, taking a guild out and letting it back, a contact
// who is not playing, leaving (and the new key after it), a member who logs in later, and the screens.
import { createNetwork, checklist } from './harness.mjs';

const B = 'Los Templarios';
const CG = 'La Orden del Alba';
const P = {
  tarek: { first: 'Tarek', second: 'Vientoalto', guid: 'Player-6842-SIMA', rosterIndex: 1 }, // Maestro de C A Ñ A D A
  bruno: { first: 'Bruno', second: 'Hierrosol', guid: 'Player-6842-SIMD', rosterIndex: 3 }, // Oficial
  peregrino: { first: 'El', second: 'Peregrino', guid: 'Player-6842-0A1B2C3D', rosterIndex: 2 }, // Miembro
  gema: { first: 'Gema', second: 'Fuego', guid: 'Player-6850-GEMA', rosterIndex: 1, guild: B }, // Maestra
  ramiro: { first: 'Ramiro', second: 'Escudo', guid: 'Player-6850-RAMI', rosterIndex: 3, guild: B }, // Oficial
  lia: { first: 'Lia', second: 'Sombra', guid: 'Player-6850-LIAS', rosterIndex: 5, guild: B }, // Miembro
  tomas: { first: 'Tomas', second: 'Luz', guid: 'Player-6860-TOMA', rosterIndex: 1, guild: CG }, // Maestro
  nadia: { first: 'Nadia', second: 'Arco', guid: 'Player-6860-NADI', rosterIndex: 5, guild: CG }, // Miembro
  rojo: { first: 'Rojo', second: 'Hacha', guid: 'Player-6870-ROJO', rosterIndex: 1, guild: 'Horda Roja', faction: 'Horde' },
};
const net = await createNetwork(Object.values(P));
const [tarek, bruno, peregrino, gema, ramiro, lia, tomas, nadia, rojo] = net.clients;
await net.loginAll();
for (const c of net.clients) await c.run('BG.Consent.Accept() BG.Alliance.REFRESH_EVERY = 20'); // (signers checked often in tests)
await net.advance(30, 0.5);
const get = net.get;
const t = checklist('comprobaciones de la alianza de hermandades');
const notice = (c) => get(c, 'return BG.lastNotice and (BG.lastNotice.title .. "|" .. (BG.lastNotice.text or "")) or ""');
const KEY_A = 'EU|C A Ñ A D A';
const KEY_B = `EU|${B}`;

await t.check('sin alianza: el chat invita a verla y la pantalla dice quién decide', async () => {
  const member = await get(peregrino, `
    BG:ToggleWindow() SIM.layout(834, 604)
    BG:ShowView("chat") SIM.layout(834, 604)
    local f = BG.window.viewFrames.chat
    if not f.cta:IsShown() then return "el chat no invita a ver la alianza" end
    BG:ShowView("alliance") SIM.layout(834, 604)
    local a = BG.window.viewFrames.alliance
    if not a.intro:IsShown() then return "no explica qué es" end
    if a.intro.create:IsShown() then return "un miembro ve Crear la alianza" end
    if not a.intro.who:GetText():find("Tarek Vientoalto", 1, true) then return "no dice quién decide: " .. a.intro.who:GetText() end
    return true`);
  if (member !== true) return member;
  return await get(tarek, `
    BG:ToggleWindow() SIM.layout(834, 604)
    BG:ShowView("alliance") SIM.layout(834, 604)
    return BG.window.viewFrames.alliance.intro.create:IsShown() or "el maestro no ve Crear la alianza"`);
});

await t.check('solo el maestro crea la alianza, y toda su hermandad la ve', async () => {
  const denied = await get(peregrino, 'local r, why = BG.Alliance.Create("La mía") return tostring(why)');
  if (denied !== 'permiso') return `un miembro la creó: ${denied}`;
  await tarek.run('assert(BG.Alliance.Create("Alianza del León"))');
  await net.advance(4);
  const seen = await get(peregrino, 'local d = BG.Alliance.Doc() return d and (d.name .. "|" .. #d.guilds) or "nada"');
  return seen === 'Alianza del León|1' || seen;
});

// Invites `name` from master `c` (signed first, so it takes a moment) and returns the invitation's token.
const invite = async (c, name) => {
  await c.run(`INV = nil assert(BG.Alliance.Invite(${JSON.stringify(name)}, function(t) INV = t end))`);
  await net.advance(6);
  return get(c, 'return INV');
};

let token;
await t.check('invitar: quien la recibe la guarda y su maestra la ve y decide', async () => {
  token = await invite(tarek, 'Lia Sombra');
  if (!token) return 'no se firmó la invitación';
  const told = await notice(tarek);
  if (!told.startsWith('Invitación entregada')) return `al maestro: ${told}`;
  const inbox = await get(gema, 'local l = BG.Alliance.Invitations() return #l .. "|" .. (l[1] and l[1].d.g.n or "")');
  if (inbox !== '1|C A Ñ A D A') return `bandeja de Gema: ${inbox}`;
  const gemaTold = await notice(gema);
  if (!gemaTold.startsWith('Invitación a una alianza')) return `aviso a Gema: ${gemaTold}`;
  const lia2 = await get(lia, `local r, why = BG.Alliance.Accept(${JSON.stringify(token)}) return tostring(why)`);
  return lia2 === 'permiso' || `un miembro aceptó: ${lia2}`;
});

await t.check('no se puede invitar a la otra facción, a los tuyos ni a quien no juega (y no ensucia el chat)', async () => {
  await tarek.run('BG.Alliance.Invite("Rojo Hacha")');
  await net.advance(6);
  const faction = await notice(tarek);
  if (!faction.includes('otra facción')) return `otra facción: ${faction}`;
  const own = await get(tarek, 'local r, why = BG.Alliance.Invite("Bruno Hierrosol") return tostring(why)');
  if (own !== 'es de tu hermandad') return `los tuyos: ${own}`;
  await tarek.run('BG.Alliance.Invite("Nadie Existe")');
  await net.advance(6);
  const off = await notice(tarek);
  const shown = await get(tarek, 'return #SIM.systemShown');
  return (off.startsWith('No está conectado') && shown === 0) || `sin conexión: ${off}; líneas del sistema a la vista: ${shown}`;
});

await t.check('la maestra acepta: las dos hermandades están en la alianza, con la misma clave', async () => {
  await gema.run(`assert(BG.Alliance.Accept(${JSON.stringify(token)}))`);
  await net.advance(30); // (the record goes back signed: several message pieces, one every 1.2 s)
  const docs = [];
  for (const c of [peregrino, bruno, lia, ramiro]) docs.push(await get(c, 'local d = BG.Alliance.Doc() return d and (#d.guilds .. ":" .. d.key) or "nada"'));
  if (new Set(docs).size !== 1 || !docs[0].startsWith('2:')) return docs.join(' / ');
  const g = await notice(gema);
  const p = await notice(tarek);
  return (g.startsWith('¡Ya sois hermanas!') && p.startsWith('Nueva hermandad hermana')) || `Gema: ${g}; Tarek: ${p}`;
});

await t.check('registro firmado: cada hermandad tiene sus claves y nadie puede falsificar un cambio', async () => {
  await net.advance(30); // (each guild's list of signers settles first: its organisers' keys join it)
  const before = await get(bruno, `local d = BG.Alliance.Doc() local ok = d.sig ~= nil
    for _, g in ipairs(d.guilds) do ok = ok and #g.pk >= 1 and g.ks ~= nil and g.es ~= nil end
    local b = BG.Alliance.Guild(${JSON.stringify(KEY_B)}) return ok and (d.v .. "|" .. #d.guilds .. "|" .. b.ev .. "|" .. #b.pk) or "sin firmas"`);
  if (before === 'sin firmas') return before;
  // 1) Lia (a member of Los Templarios) changes her guild's contacts and keeps the old signature.
  await lia.run(`local e = BG.Alliance.CopyEntry(BG.Alliance.Guild(${JSON.stringify(KEY_B)})) e.ev = e.ev + 1 e.c = { "Lia Sombra" }
    BG.Comm.Send("AE", { a = BG.Alliance.Doc().id, v = BG.Alliance.Doc().v, g = e }, "WHISPER", "Bruno Hierrosol")`);
  // 2) She adds her own key to her guild's signers and signs everything with it.
  await lia.run(`BG.Sign.Ensure(function(pk)
    local d = BG.Alliance.Doc()
    local e = BG.Alliance.CopyEntry(BG.Alliance.Guild(${JSON.stringify(KEY_B)})) e.ev = e.ev + 2
    table.insert(e.pk, pk)
    BG.Sign.Sign(BG.AllianceRules.CertText(d.id, e), function(cs)
      e.ks = { s = cs, p = pk }
      BG.Sign.Sign(BG.AllianceRules.EntrySigned(d.id, e), function(s)
        e.es = { s = s, p = pk }
        BG.Comm.Send("AE", { a = d.id, v = d.v, g = e }, "WHISPER", "Bruno Hierrosol")
      end)
    end)
  end)`);
  // 3) Ramiro, an organiser of Los Templarios, takes C A Ñ A D A out with the old signature.
  await ramiro.run(`local d = BG.Alliance.CopyDoc(BG.Alliance.Doc()) d.v = d.v + 1
    for i = #d.guilds, 1, -1 do if d.guilds[i].k == ${JSON.stringify(KEY_A)} then table.remove(d.guilds, i) end end
    BG.Comm.Send("AU", { d = d }, "WHISPER", "Bruno Hierrosol")`);
  await net.advance(15);
  const after = await get(bruno, `local d = BG.Alliance.Doc() local b = BG.Alliance.Guild(${JSON.stringify(KEY_B)}) return d.v .. "|" .. #d.guilds .. "|" .. b.ev .. "|" .. #b.pk`);
  if (after !== before) return `Bruno tiene ahora ${after} (antes ${before})`;
  const lia2 = await get(bruno, `local b = BG.Alliance.Guild(${JSON.stringify(KEY_B)}) return table.concat(b.c, ",")`);
  return lia2 !== 'Lia Sombra' || 'aceptó los contactos falsos';
});

await t.check('presencia: cada hermandad sabe quién está conectado en la otra', async () => {
  await net.advance(150, 1);
  const a = await get(peregrino, `local p = BG.Alliance.Presence(${JSON.stringify(KEY_B)}) return p and (#p.on .. "|" .. tostring(p.m)) or "sin contacto"`);
  const b = await get(lia, `local p = BG.Alliance.Presence(${JSON.stringify(KEY_A)}) return p and tostring(#p.on) or "sin contacto"`);
  return (a.startsWith('3|') && b === '3') || `Peregrino ve ${a}; Lia ve ${b}`;
});

await t.check('chat de toda la alianza: llega una vez a las dos hermandades, con el nombre de la hermandad', async () => {
  await peregrino.run('assert(BG.Chat.Send("ally", "¡Hola, hermanas!"))');
  await net.advance(6);
  const atLia = await get(lia, 'local h = BG.Chat.History("ally") local l = h[#h] return #h .. "|" .. (l and (l.from .. "|" .. tostring(l.gn) .. "|" .. l.text) or "")');
  if (atLia !== '1|El Peregrino|C A Ñ A D A|¡Hola, hermanas!') return `Lia: ${atLia}`;
  const atBruno = await get(bruno, 'local h = BG.Chat.History("ally") local l = h[#h] return #h .. "|" .. tostring(l and l.gn)');
  if (atBruno !== '1|nil') return `Bruno: ${atBruno}`;
  await lia.run('assert(BG.Chat.Send("ally", "¡Hola, España!"))');
  await net.advance(6);
  const back = await get(peregrino, 'local h = BG.Chat.History("ally") local l = h[#h] return l.from .. "|" .. tostring(l.gn) .. "|" .. BG.Chat.FormatLine("ally", #h, l)');
  return back.startsWith(`Lia Sombra|${B}|`) && back.includes(`[${B}]`) || back;
});

await t.check('salas de roles compartidas: Sanadores llega a la hermandad hermana', async () => {
  await ramiro.run('assert(BG.Chat.Send("healers", "Busco sanador para Las Mazmorras"))');
  await net.advance(6);
  const r = await get(peregrino, 'local h = BG.Chat.History("healers") local l = h[#h] return l and (l.from .. "|" .. tostring(l.gn)) or "nada"');
  return r === `Ramiro Escudo|${B}` || r;
});

let tokenC;
await t.check('una tercera hermandad entra invitada por otra y la primera se entera sola', async () => {
  tokenC = await invite(gema, 'Nadia Arco');
  await tomas.run(`assert(BG.Alliance.Accept(${JSON.stringify(tokenC)}))`);
  await net.advance(70);
  const peregrinoSees = await get(peregrino, 'local d = BG.Alliance.Doc() return d and #d.guilds or 0');
  const nadiaSees = await get(nadia, 'local d = BG.Alliance.Doc() return d and #d.guilds or 0');
  return (peregrinoSees === 3 && nadiaSees === 3) || `Peregrino ve ${peregrinoSees} hermandades; Nadia ${nadiaSees}`;
});

await t.check('la pestaña de una hermandad hermana solo la leen esas dos', async () => {
  await net.advance(150, 1);
  await peregrino.run(`assert(BG.Chat.Send("ally-" .. BG.Alliance.Code(${JSON.stringify(KEY_B)}), "Solo para los Templarios"))`);
  await net.advance(6);
  const atLia = await get(lia, `local h = BG.Chat.History("ally-" .. BG.Alliance.Code(${JSON.stringify(KEY_A)})) local l = h[#h] return l and l.text or "nada"`);
  const atNadia = await get(nadia, 'local n = 0 for ch, list in pairs(BG.Guild.Entry().chat or {}) do for _, l in ipairs(list) do if l.text == "Solo para los Templarios" then n = n + 1 end end end return n');
  const atBruno = await get(bruno, `local h = BG.Chat.History("ally-" .. BG.Alliance.Code(${JSON.stringify(KEY_B)})) return #h`);
  return (atLia === 'Solo para los Templarios' && atNadia === 0 && atBruno === 1) || `Lia: ${atLia}; Nadia: ${atNadia}; Bruno: ${atBruno}`;
});

await t.check('oficiales de la alianza: solo los organizadores lo leen y escriben', async () => {
  const denied = await get(peregrino, 'local ok, why = BG.Chat.Send("allyorg", "hola") return tostring(why)');
  if (denied !== 'solo para organizadores y capitanes') return `un miembro escribió: ${denied}`;
  await bruno.run('assert(BG.Chat.Send("allyorg", "Reunión de oficiales el domingo"))');
  await net.advance(6);
  const read = async (c) => get(c, 'local h = BG.Chat.History("allyorg") return #h');
  const [r, g, l, tm] = [await read(ramiro), await read(gema), await read(lia), await read(tomas)];
  return (r === 1 && g === 1 && tm === 1 && l === 0) || `Ramiro ${r}, Gema ${g}, Tomas ${tm}, Lia ${l}`;
});

await t.check('un desconocido no puede escribir en la alianza, ni nadie en nombre de otro', async () => {
  await rojo.run(`BG.Comm.Send("AC", { r = "ally", i = "x-1", t = "spam", f = "Rojo Hacha", g = ${JSON.stringify(KEY_B)}, h = "000000000000" }, "WHISPER", "Lia Sombra")`);
  await net.advance(4);
  const n = await get(lia, 'local n = 0 for _, l in ipairs(BG.Chat.History("ally")) do if l.text == "spam" then n = n + 1 end end return n');
  if (n !== 0) return 'el mensaje falso llegó';
  // Lia knows the key, but cannot speak for Gema: a sister guild's line comes from its author.
  await lia.run(`local id = "x-2" BG.Comm.Send("AC", { r = "ally", i = id, t = "Soy Gema", f = "Gema Fuego", g = ${JSON.stringify(KEY_B)}, h = BG.Alliance.Tag("AC" .. id) }, "WHISPER", "El Peregrino")`);
  await net.advance(4);
  const fake = await get(peregrino, 'local n = 0 for _, l in ipairs(BG.Chat.History("ally")) do if l.text == "Soy Gema" then n = n + 1 end end return n');
  return fake === 0 || 'una línea en nombre de otra persona llegó';
});

await t.check('cargos: el maestro nombra capitán a un miembro, que entra en Oficiales de la alianza', async () => {
  const denied = await get(bruno, 'local r, why = BG.Alliance.SetCargo("El Peregrino", "cap") return tostring(why)');
  if (denied !== 'permiso') return `un oficial nombró: ${denied}`;
  await tarek.run('assert(BG.Alliance.SetCargo("El Peregrino", "cap"))');
  await net.advance(30);
  const atLia = await get(lia, `return table.concat(BG.Alliance.Cargos(${JSON.stringify(KEY_A)}, "cap"), ",")`);
  if (atLia !== 'El Peregrino') return `Lia ve capitanes: ${atLia}`;
  await net.advance(130, 1); // (the presence marks him as a reader of the organisers' tab)
  await peregrino.run('assert(BG.Chat.Send("allyorg", "Capitán al habla"))');
  await net.advance(6);
  const r = await get(ramiro, 'local h = BG.Chat.History("allyorg") local l = h[#h] return l and l.text or "nada"');
  if (r !== 'Capitán al habla') return `Ramiro: ${r}`;
  await gema.run('assert(BG.Chat.Send("allyorg", "Recibido, capitán"))');
  await net.advance(6);
  const back = await get(peregrino, 'local h = BG.Chat.History("allyorg") local l = h[#h] return l and l.text or "nada"');
  return back === 'Recibido, capitán' || `al capitán: ${back}`;
});

await t.check('líder: la fundadora lidera hasta que la mayoría de los maestros vota a otra', async () => {
  const first = await get(nadia, 'return BG.Alliance.Lead()');
  if (first !== KEY_A) return `al principio lidera ${first}`;
  const member = await get(peregrino, `local r, why = BG.Alliance.Vote(${JSON.stringify(KEY_B)}) return tostring(why)`);
  if (member !== 'permiso') return `un miembro votó: ${member}`;
  await gema.run(`assert(BG.Alliance.Vote(${JSON.stringify(KEY_B)}))`);
  await net.advance(30);
  const one = await get(peregrino, 'return BG.Alliance.Lead()');
  if (one !== KEY_A) return `con un voto de tres ya cambió: ${one}`;
  await tomas.run(`assert(BG.Alliance.Vote(${JSON.stringify(KEY_B)}))`);
  await net.advance(30);
  const leads = [];
  for (const c of [peregrino, tarek, lia, nadia]) leads.push(await get(c, 'return BG.Alliance.Lead()'));
  if (leads.some((l) => l !== KEY_B)) return `líder: ${leads.join(' / ')}`;
  const told = await notice(peregrino);
  return (told.startsWith('Nuevo líder de la alianza') && told.includes('Gema Fuego')) || `aviso: ${told}`;
});

await t.check('llamada a las armas de la alianza: solo el liderazgo, firmada, llega a todas', async () => {
  const lia2 = await get(lia, 'local r, why = BG.Alliance.Call("ARMS", "") return tostring(why)');
  if (lia2 !== 'permiso') return `un miembro llamó: ${lia2}`;
  const per = await get(tarek, 'local r, why = BG.Alliance.Call("ARMS", "") return tostring(why)');
  if (per !== 'permiso') return `otro maestro llamó: ${per}`;
  // A forged call: a member of the leader's guild, with a made-up signature.
  await lia.run(`local d = BG.Alliance.Doc() local g = BG.Alliance.LeaderGuild()
    BG.Comm.Send("AK", { a = d.id, i = "falsa1", k = "ARMS", t = "Falsa", f = "Gema Fuego", g = g.k, at = BG.Store.Now(), p = g.pk[1], s = string.rep("A", 86) }, "WHISPER", "El Peregrino")`);
  await net.advance(4);
  if ((await notice(peregrino)).includes('Falsa')) return 'la llamada falsa se mostró';
  await gema.run('assert(BG.Alliance.Call("ARMS", "Defended el puente"))');
  await net.advance(8);
  const seen = [];
  for (const c of [peregrino, tarek, nadia, ramiro]) seen.push(await notice(c));
  const ok = seen.every((n) => n.startsWith('¡A las armas! — alianza «Alianza del León»') && n.includes('Defended el puente'));
  return ok || seen.join(' / ');
});

await t.check('ocultarse: un organizador oculto no sale en la presencia de las otras, pero le llega su pestaña', async () => {
  const member = await get(peregrino, 'local r, why = BG.Alliance.SetHidden(true) return tostring(why)');
  if (member !== 'permiso') return `un miembro se ocultó: ${member}`;
  await bruno.run('assert(BG.Alliance.SetHidden(true))');
  await net.advance(150, 1);
  const listed = await get(lia, `local p = BG.Alliance.Presence(${JSON.stringify(KEY_A)}) if not p then return "sin presencia" end
    for _, o in ipairs(p.on) do if o.n == "Bruno Hierrosol" then return "aparece" end end return #p.on`);
  if (listed !== 2) return `Lia ve a C A Ñ A D A: ${listed}`;
  await ramiro.run('assert(BG.Chat.Send("allyorg", "Para los oficiales"))');
  await net.advance(8);
  const r = await get(bruno, 'local h = BG.Chat.History("allyorg") local l = h[#h] return l and l.text or "nada"');
  if (r !== 'Para los oficiales') return `a Bruno oculto: ${r}`;
  await bruno.run('assert(BG.Alliance.SetHidden(false))');
  return true;
});

await t.check('expulsar: el líder saca a una hermandad, que recibe el aviso firmado, y la clave cambia', async () => {
  const other = await get(tarek, `local r, why = BG.Alliance.Expel(${JSON.stringify(`EU|${CG}`)}) return tostring(why)`);
  if (other !== 'permiso') return `otro maestro expulsó: ${other}`;
  const keyBefore = await get(peregrino, 'return BG.Alliance.Doc().key');
  await gema.run(`assert(BG.Alliance.Expel(${JSON.stringify(`EU|${CG}`)}))`);
  await net.advance(40);
  const out = await get(nadia, 'return BG.Alliance.Doc() and "sigue" or "fuera"');
  const outT = await get(tomas, 'return BG.Alliance.Doc() and "sigue" or "fuera"');
  const told = await notice(tomas);
  if (out !== 'fuera' || outT !== 'fuera' || !told.startsWith('Fuera de la alianza')) return `Nadia ${out}, Tomas ${outT}: ${told}`;
  const keys = [];
  for (const c of [peregrino, bruno, lia, ramiro]) keys.push(await get(c, 'local d = BG.Alliance.Doc() return #d.guilds .. ":" .. d.key'));
  if (new Set(keys).size !== 1 || !keys[0].startsWith('2:') || keys[0] === `2:${keyBefore}`) return keys.join(' / ');
  await net.advance(130, 1); // (presence with the new key)
  await peregrino.run('assert(BG.Chat.Send("ally", "Con la clave nueva"))');
  await net.advance(6);
  const atLia = await get(lia, 'local h = BG.Chat.History("ally") local l = h[#h] return l and l.text or "nada"');
  return atLia === 'Con la clave nueva' || `con la clave nueva, Lia: ${atLia}`;
});

await t.check('la hermandad expulsada puede volver si la invitan de nuevo', async () => {
  const tk = await invite(gema, 'Nadia Arco');
  if (!tk) return 'no se firmó la invitación';
  await tomas.run(`assert(BG.Alliance.Accept(${JSON.stringify(tk)}))`);
  await net.advance(70);
  const e = await get(peregrino, 'local d = BG.Alliance.Doc() return d and #d.guilds or 0');
  const n = await get(nadia, 'local d = BG.Alliance.Doc() return d and #d.guilds or 0');
  await tarek.run('assert(BG.Alliance.SetCargo("El Peregrino", nil))'); // (the captain goes back to member)
  await net.advance(10);
  return (e === 3 && n === 3) || `Peregrino ve ${e}; Nadia ${n}`;
});

await t.check('si el contacto de una hermandad no está, el mensaje va por otro', async () => {
  await net.logout(gema);
  await net.logout(bruno);
  await peregrino.run('assert(BG.Chat.Send("ally", "¿Seguís ahí?"))');
  await net.advance(10);
  const r = await get(lia, 'local h = BG.Chat.History("ally") local l = h[#h] return l and l.text or "nada"');
  const shown = await get(peregrino, 'return #SIM.systemShown');
  return (r === '¿Seguís ahí?' && shown === 0) || `Lia: ${r}; líneas del sistema a la vista de Peregrino: ${shown}`;
});

await t.check('salir: la hermandad que sale deja de ver la alianza, las demás lo saben y el líder cambia la clave', async () => {
  const before = await get(peregrino, 'return BG.Alliance.Doc().key');
  await tomas.run('assert(BG.Alliance.Leave())');
  await net.advance(40); // (the record is several message pieces, and the game sends one every 1.2 s)
  const n = await get(nadia, 'return BG.Alliance.Doc() and "sigue" or "fuera"');
  const e = await get(peregrino, 'local d = BG.Alliance.Doc() return d and #d.guilds or 0');
  const l = await get(lia, 'local d = BG.Alliance.Doc() return d and #d.guilds or 0');
  if (!(n === 'fuera' && e === 2 && l === 2)) return `Nadia ${n}; Peregrino ve ${e}; Lia ve ${l}`;
  // The leader's guild gives the new key (C A Ñ A D A again: with two guilds, one vote is no majority).
  await net.advance(60, 1);
  const keys = [];
  for (const c of [peregrino, lia, ramiro]) keys.push(await get(c, 'local d = BG.Alliance.Doc() return d.key .. (d.kr and "|pendiente" or "")'));
  return (new Set(keys).size === 1 && keys[0] !== before && !keys[0].includes('pendiente')) || `claves: ${keys.join(' / ')} (antes ${before})`;
});

await t.check('un miembro que se conecta más tarde recibe la alianza', async () => {
  const rina = await net.add({ first: 'Rina', second: 'Dagaluna', guid: 'Player-6842-SIMB', rosterIndex: 5 });
  await rina.login();
  await rina.run('BG.Consent.Accept()');
  await net.advance(90, 0.5); // (the guild's records come over at the game's pace; the alliance's is the largest)
  const r = await get(rina, 'local d = BG.Alliance.Doc() return d and (d.name .. "|" .. #d.guilds) or "nada"');
  return r === 'Alianza del León|2' || r;
});

await t.check('pantallas: pestaña por hermandad hermana en el chat, y la alianza con sus hermandades', async () => {
  return await get(peregrino, `
    BG:ShowView("chat") SIM.layout(834, 604)
    local f = BG.window.viewFrames.chat
    if f.cta:IsShown() then return "sigue invitando a ver la alianza" end
    local tab = f.railButtons["ally-" .. BG.Alliance.Code(${JSON.stringify(KEY_B)})]
    if not tab or tab.text:GetText() ~= ${JSON.stringify(B)} then return "sin pestaña de Los Templarios" end
    if not f.railButtons.ally then return "sin Toda la alianza" end
    if f.railButtons.allyorg then return "un miembro ve Oficiales de la alianza" end
    tab:Click()
    if f.main.title:GetText() ~= ${JSON.stringify(B)} then return "título: " .. f.main.title:GetText() end
    BG:ShowView("alliance") SIM.layout(834, 604)
    local a = BG.window.viewFrames.alliance
    if a.intro:IsShown() then return "sigue en la explicación" end
    if #a.guilds.items ~= 2 then return "hermandades en la lista: " .. #a.guilds.items end
    if a.side.leave:IsShown() then return "un miembro ve Salir de la alianza" end
    if a.side.cargoSet:IsShown() then return "un miembro ve Nombrar" end
    -- (two guilds left and only Los Templarios voted: one vote of two is not a majority, so the founder leads)
    if not a.hero.sub:GetText():find("Líder: Tarek Vientoalto", 1, true) then return "sin líder: " .. a.hero.sub:GetText() end
    if a.plates[2].label:GetText() ~= "PERSONAS" then return "segunda placa: " .. a.plates[2].label:GetText() end
    if not a.side.lead:GetText():find("Los Templarios 1", 1, true) then return "votos: " .. a.side.lead:GetText() end
    local out = SIM.CheckLayout(a)
    if #out > 0 then return "se sale: " .. out[1] end
    -- People, not characters: a member of the alts rank counts once (with their main).
    local before = BG.People.Census()
    SIM.roster[10][2] = "Alter" BG.Guild.Scan()
    local after = BG.People.Census()
    if not (after.chars == before.chars and after.people == before.people - 1) then return "censo: " .. before.people .. " -> " .. after.people end
    if not a.hero.title:GetText():find("Alianza del León", 1, true) then return "título: " .. a.hero.title:GetText() end
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

const bytes = net.wire.reduce((n, f) => n + Buffer.byteLength(f.msg, 'utf8'), 0);
console.log(`(tráfico total: ${net.wire.length} tramas, ${bytes} bytes)`);
net.close();
t.report();
