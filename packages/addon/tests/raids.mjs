// Entrega 2 in a simulated guild: raids (create, sign up, bench, groups, invite, cancel), permissions and forged
// records, a member who logs in late and catches up, dungeon groups (ask, accept, decline), the board's
// flags, the officer call, the calendar, and the three views with real data.
import { createNetwork, checklist } from './harness.mjs';

const P = {
  tarek: { first: 'Tarek', second: 'Vientoalto', guid: 'Player-6842-SIMA', rosterIndex: 1 }, // Maestro (rank 0)
  peregrino: { first: 'El', second: 'Peregrino', guid: 'Player-6842-0A1B2C3D', rosterIndex: 2 }, // Miembro
  rina: { first: 'Rina', second: 'Dagaluna', guid: 'Player-6842-SIMB', rosterIndex: 5 }, // Miembro
  brasa: { first: 'Sr', second: 'Brasa', guid: 'Player-6842-SIMC', rosterIndex: 7 }, // Miembro
};
const late = { first: 'Bruno', second: 'Hierrosol', guid: 'Player-6842-SIMD', rosterIndex: 3 }; // Oficial (rank 1)

const net = await createNetwork([P.tarek, P.peregrino, P.rina, P.brasa]);
const [tarek, peregrino, rina, brasa] = net.clients;
await net.loginAll();
for (const c of net.clients) await c.run('BG.Consent.Accept()');
await net.advance(20);
const get = net.get;
const t = checklist('comprobaciones de raids, grupos y calendario');

let raidId;
let peregrinoRaid;
await t.check('cualquier miembro crea su raid y la dirige; nadie puede pisar la de otro', async () => {
  peregrinoRaid = await get(peregrino, 'local r = assert(BG.Raids.Save(nil, { inst = "ZG", start = time() + 3 * 86400 })) return r.id');
  await net.advance(6);
  const seen = await get(rina, `local r = BG.Raids.Get(${JSON.stringify(peregrinoRaid)}) return r and (r.d.title .. "|" .. r.d.leader) or "nada"`);
  if (seen !== "Zul'Gurub|El Peregrino") return `Rina ve: ${seen}`;
  const manage = await get(peregrino, `return tostring(BG.Raids.CanManage(BG.Raids.Get(${JSON.stringify(peregrinoRaid)})))`);
  if (manage !== 'true') return 'su creador no la gestiona';
  await rina.run(`
    local r = BG.Raids.Get(${JSON.stringify(peregrinoRaid)})
    local d = {} for k, v in pairs(r.d) do d[k] = v end
    d.status = "CANCELLED" d.leader = "Rina Dagaluna"
    BG.Comm.Send("RC", { c = "raids", r = { id = r.id, rev = r.rev + 3, at = BG.Store.Now(), by = "Rina Dagaluna", d = d } }, "GUILD")`);
  await net.advance(6);
  const after = await get(tarek, `local r = BG.Raids.Get(${JSON.stringify(peregrinoRaid)}) return r.d.status .. "|" .. r.d.leader`);
  return after === 'SCHEDULED|El Peregrino' || `tras el intento de Rina: ${after}`;
});

await t.check('el maestro crea una raid y toda la hermandad la recibe', async () => {
  raidId = await get(tarek, `
    local r = assert(BG.Raids.Save(nil, { inst = "MC", start = time() + 2 * 86400, note = "Traed resistencia al fuego", minLevel = 58 }))
    return r.id`);
  await net.advance(6);
  for (const c of [peregrino, rina, brasa]) {
    const title = await get(c, `local r = BG.Raids.Get(${JSON.stringify(raidId)}) return r and (r.d.title .. "|" .. r.d.cap .. "|" .. r.d.need.HEALER) or "nada"`);
    if (title !== 'Núcleo de Magma|40|10') return `${c.name}: ${title}`;
  }
  return true;
});

await t.check('inscripciones: cada uno se apunta con su rol y todos cuentan igual', async () => {
  await peregrino.run(`assert(BG.Raids.SignUp(${JSON.stringify(raidId)}, "CONFIRMED", "HEALER", "llego 21:10"))`);
  await rina.run(`assert(BG.Raids.SignUp(${JSON.stringify(raidId)}, "TENTATIVE", "DPS"))`);
  await brasa.run(`assert(BG.Raids.SignUp(${JSON.stringify(raidId)}, "CONFIRMED", "DPS"))`);
  await net.advance(8);
  for (const c of net.clients) {
    const k = await get(c, `local k = BG.Raids.Counts(${JSON.stringify(raidId)}) return k.confirmed .. "/" .. k.tentative .. "/" .. k.HEALER .. "/" .. k.DPS`);
    if (k !== '2/1/1/1') return `${c.name}: ${k}`;
  }
  return true;
});

await t.check('registros falsificados se rechazan (apuntar a otro, crear una raid a nombre de otro, tocar el plan sin permiso)', async () => {
  await rina.run(`
    local now = BG.Store.Now()
    BG.Comm.Send("RC", { c = "signups", r = { id = ${JSON.stringify(raidId)} .. "|El Peregrino", rev = 99, at = now, by = "El Peregrino",
      d = { raid = ${JSON.stringify(raidId)}, name = "El Peregrino", status = "DECLINED", role = "DPS" } } }, "GUILD")
    BG.Comm.Send("RC", { c = "raids", r = { id = "TarekVientoalto-1", rev = 1, at = now, by = "Rina Dagaluna", d = { inst = "ONY", start = now + 3600 } } }, "GUILD")
    BG.Comm.Send("RC", { c = "plans", r = { id = ${JSON.stringify(raidId)}, rev = 50, at = now, by = "Rina Dagaluna", d = { g = {}, bench = { ["El Peregrino"] = true } } } }, "GUILD")
  `);
  await net.advance(10);
  const mine = await get(tarek, `local s = BG.Store.Get("signups", ${JSON.stringify(raidId)} .. "|El Peregrino") return s.d.status`);
  const ony = await get(tarek, 'return BG.Store.Get("raids", "TarekVientoalto-1") and "aceptada" or "rechazada"');
  const bench = await get(tarek, `return BG.Raids.Plan(${JSON.stringify(raidId)}).bench["El Peregrino"] and "sí" or "no"`);
  return (mine === 'CONFIRMED' && ony === 'rechazada' && bench === 'no') || `inscripción ${mine}, raid ${ony}, reserva ${bench}`;
});

await t.check('el organizador manda a reserva, reparte grupos e invita a los confirmados', async () => {
  await tarek.run(`
    assert(BG.Raids.SetBench(${JSON.stringify(raidId)}, "Sr Brasa", true))
    assert(BG.Raids.ApplyAutoGroups(${JSON.stringify(raidId)}))
  `);
  await net.advance(6);
  const plan = await get(peregrino, `local p = BG.Raids.Plan(${JSON.stringify(raidId)}) return tostring(p.bench["Sr Brasa"]) .. "|" .. tostring(p.g["El Peregrino"]) .. "|" .. tostring(p.g["Sr Brasa"])`);
  if (plan !== 'true|1|nil') return `plan visto por El Peregrino: ${plan}`;
  await tarek.run(`BG.__inv = { BG.Raids.InviteConfirmed(${JSON.stringify(raidId)}) }`);
  const invites = await get(tarek, 'return table.concat(SIM.invites, ",")');
  return invites === 'El Peregrino' || `invitados: ${invites}`;
});

await t.check('un miembro que entra tarde se pone al día con el mensajero', async () => {
  const bruno = await net.add(late);
  await bruno.login();
  await bruno.run('BG.Consent.Accept()');
  await net.advance(70);
  const r = await get(bruno, `local r = BG.Raids.Get(${JSON.stringify(raidId)}) if not r then return "sin raid" end local k = BG.Raids.Counts(r.id) return r.d.title .. "|" .. k.confirmed .. "|" .. k.bench`);
  const asked = net.wire.filter((f) => f.from === 'Bruno Hierrosol' && f.msg.startsWith('1!SQ:')).map((f) => f.target);
  return (r === 'Núcleo de Magma|1|1' && asked[0] === 'Tarek Vientoalto') || `visto ${r}, preguntó a ${asked.join(',')}`;
});

let groupId;
await t.check('grupo de mazmorra: crear, pedir plaza, aceptar (invita) y rechazar', async () => {
  groupId = await get(peregrino, 'local g = assert(BG.Groups.Create("BRD", { TANK = 1, HEALER = 1, DPS = 3 }, "a por el Emperador", "HEALER")) return g.id');
  await net.advance(5);
  await rina.run(`assert(BG.Groups.Ask(${JSON.stringify(groupId)}, "DPS", "voy con veneno"))`);
  await brasa.run(`assert(BG.Groups.Ask(${JSON.stringify(groupId)}, "DPS"))`);
  await net.advance(6);
  const reqs = await get(peregrino, `return #BG.Groups.Requests(${JSON.stringify(groupId)})`);
  if (reqs !== 2) return `peticiones ${reqs}`;
  await peregrino.run(`SIM.invites = {} assert(BG.Groups.Accept(${JSON.stringify(groupId)}, "Rina Dagaluna")) assert(BG.Groups.Decline(${JSON.stringify(groupId)}, "Sr Brasa"))`);
  await net.advance(6);
  const seen = await get(brasa, `local g = BG.Groups.Get(${JSON.stringify(groupId)}) local names = {} for _, m in ipairs(g.d.members) do names[#names + 1] = m.name end return table.concat(names, ",") .. "|" .. tostring(g.d.declined["Sr Brasa"])`);
  const invited = await get(peregrino, 'return table.concat(SIM.invites, ",")');
  const left = await get(peregrino, `return #BG.Groups.Requests(${JSON.stringify(groupId)})`);
  return (seen === 'El Peregrino,Rina Dagaluna|true' && invited === 'Rina Dagaluna' && left === 0) || `visto ${seen}, invitados ${invited}, peticiones ${left}`;
});

await t.check('nadie puede quedarse con el grupo de otro', async () => {
  await brasa.run(`
    local g = BG.Groups.Get(${JSON.stringify(groupId)})
    local d = {} for k, v in pairs(g.d) do d[k] = v end
    d.leader = "Sr Brasa"
    BG.Comm.Send("RC", { c = "groups", r = { id = ${JSON.stringify(groupId)}, rev = g.rev + 5, at = BG.Store.Now(), by = "Sr Brasa", d = d } }, "GUILD")
  `);
  await net.advance(6);
  const leader = await get(rina, `return BG.Groups.Get(${JSON.stringify(groupId)}).d.leader`);
  return leader === 'El Peregrino' || leader;
});

await t.check('grupos para otras cosas: JcJ, misiones, subir de nivel… (no solo mazmorras)', async () => {
  const id = await get(rina, 'local g = assert(BG.Groups.Create("ACT_PVP", { TANK = 0, HEALER = 1, DPS = 4 }, "Garganta Grito de Guerra", "DPS")) return g.id');
  await net.advance(5);
  const seen = await get(peregrino, `local g = BG.Groups.Get(${JSON.stringify(id)}) return g and (g.d.key .. "|" .. BG.Instances.Any(g.d.key).name) or "nada"`);
  const bad = await get(rina, 'local g, why = BG.Groups.Create("NOEXISTE", { TANK = 1, HEALER = 1, DPS = 3 }, "", "DPS") return tostring(why)');
  return (seen === 'ACT_PVP|JcJ: campos de batalla' && bad === 'datos') || `visto ${seen}; actividad inventada: ${bad}`;
});

await t.check('tablón: levantar bandera, verla todos, saludar con una frase fija y bajarla', async () => {
  await rina.run('assert(BG.Groups.RaiseFlag("DUNGEON", "SM", "DPS", "cualquiera del Monasterio"))');
  await net.advance(5);
  const seen = await get(tarek, 'local f = BG.Groups.Flags()[1] return f and (f.id .. "|" .. f.d.key .. "|" .. f.d.role) or "nada"');
  if (seen !== 'Rina Dagaluna|SM|DPS') return seen;
  await tarek.run('local f = BG.Groups.Flags()[1] BG.Groups.Whisper("Rina Dagaluna-ForeverPvP2", BG.Groups.FlagWhisper(f))');
  const tell = await get(tarek, 'local m = SIM.chat[#SIM.chat] return m.chatType .. "|" .. m.target .. "|" .. m.msg');
  if (tell !== 'WHISPER|Rina Dagaluna|Hola, he visto en BlazonGuild que buscas grupo para Monasterio Escarlata. ¿Vamos juntos?') return `susurro: ${tell}`;
  await rina.run('BG.Groups.LowerFlag()');
  await net.advance(5);
  const after = await get(tarek, 'return #BG.Groups.Flags()');
  return after === 0 || `quedan ${after}`;
});

await t.check('llamada a oficiales: solo la reciben los rangos de oficiales', async () => {
  await tarek.run('assert(BG.Raids.Muster("Reunión en el canal de voz"))');
  await net.advance(5);
  const officer = await get(net.clients[4], 'return BlazonGuildDialog and BlazonGuildDialog:IsShown() and BlazonGuildDialog.title:GetText() or "nada"');
  const member = await get(peregrino, 'return BlazonGuildDialog and BlazonGuildDialog:IsShown() and BlazonGuildDialog.title:GetText() or "nada"');
  // (a member may have the one-time question about sharing their gear on screen: never the officers' call)
  return (officer === 'Llamada a los oficiales' && member !== 'Llamada a los oficiales') || `oficial: ${officer}, miembro: ${member}`;
});

await t.check('pantallas: Raids, Grupos y Calendario con los datos', async () => {
  await peregrino.run(`
    local d = date("*t", time() + 86400)
    SIM.calendar["0:" .. d.day] = { { title = "Noche de pesca", calendarType = "GUILD_EVENT", startTime = { year = d.year, month = d.month, monthDay = d.day, hour = 20, minute = 0 } } }
    BG:ToggleWindow()
    SIM.layout(834, 604)
  `);
  const out = await get(peregrino, `
    BG:ShowView("raids") SIM.layout(834, 604)
    local r = BG.window.viewFrames.raids
    if r.detail.title:GetText() ~= "Núcleo de Magma" then return "raids: " .. tostring(r.detail.title:GetText()) end
    if r.detail.saveSignup.text:GetText() ~= "Guardar" then return "botón " .. r.detail.saveSignup.text:GetText() end
    if not r.newBtn:IsShown() then return "un miembro no ve Nueva raid" end
    local lay = SIM.CheckLayout(r) if #lay > 0 then return "Raids se sale o se monta: " .. lay[1] end
    BG:ShowView("dungeons") SIM.layout(834, 604)
    local g = BG.window.viewFrames.dungeons
    if not g.lead:IsShown() then return "no ve su grupo" end
    if not g.lead.head.title:GetText():find("Profundidades") then return "grupo: " .. g.lead.head.title:GetText() end
    local lay = SIM.CheckLayout(g) if #lay > 0 then return "Grupos se sale o se monta: " .. lay[1] end
    BG:ShowView("calendar") SIM.layout(834, 604)
    local c = BG.window.viewFrames.calendar
    local titles = {}
    for _, row in ipairs(c.list.items) do titles[#titles + 1] = row.header or row.title end
    local joined = table.concat(titles, " / ")
    if not joined:find("Noche de pesca") or not joined:find("Núcleo de Magma") then return "calendario: " .. joined end
    local lay = SIM.CheckLayout(c) if #lay > 0 then return "Calendario se sale o se monta: " .. lay[1] end
    return true`);
  return out;
});

await t.check('«Voy», «Quizá» y «No voy» se guardan al pulsarlos (y el rol, si ya estás apuntado), sin «Guardar»', async () => {
  const r = await get(peregrino, `
    BG:ShowView("raids") SIM.layout(834, 604)
    local f = BG.window.viewFrames.raids
    local d = f.detail
    d.status.buttons[2]:Click()
    local s = BG.Raids.MySignup(${JSON.stringify(raidId)})
    if s.d.status ~= "TENTATIVE" then return "quizá: " .. s.d.status end
    d.role.buttons[1]:Click()
    s = BG.Raids.MySignup(${JSON.stringify(raidId)})
    if s.d.role ~= "TANK" then return "rol: " .. s.d.role end
    SIM.layout(834, 604)
    for _, row in ipairs(f.list.rows) do
      if row:IsShown() and row.raid and row.raid.id == ${JSON.stringify(raidId)} and not row.right2:GetText():find("Quizá", 1, true) then return "a la izquierda: " .. row.right2:GetText() end
    end
    return true`);
  if (r !== true) return r;
  await net.advance(4);
  const seen = await get(tarek, `local s = BG.Store.Get("signups", ${JSON.stringify(raidId)} .. "|El Peregrino") return s.d.status .. ":" .. s.d.role`);
  return seen === 'TENTATIVE:TANK' || `lo que ve el maestro: ${seen}`;
});

await t.check('cancelar la raid llega a todos', async () => {
  await tarek.run(`assert(BG.Raids.Cancel(${JSON.stringify(raidId)}))`);
  await net.advance(5);
  const s = await get(rina, `return BG.Raids.Get(${JSON.stringify(raidId)}).d.status`);
  return s === 'CANCELLED' || s;
});

await t.check('una raid cancelada se ve cancelada: solo su cabecera y una frase; quien la gestiona, «Volver a programar» y «Borrar»', async () => {
  const member = await get(peregrino, `
    BG:RefreshView("raids") SIM.layout(834, 604)
    local f = BG.window.viewFrames.raids
    local d = f.detail
    if d.state:GetText() ~= "CANCELADA" then return "cabecera: " .. tostring(d.state:GetText()) end
    if d.status:IsShown() or d.role:IsShown() or d.saveSignup:IsShown() or d.compHead:IsShown() or d.cols[1]:IsShown() then return "sigue enseñando la inscripción o la composición" end
    if not d.cancelled:IsShown() or d.cancelled:GetText():find("Volver a programar", 1, true) then return "frase: " .. tostring(d.cancelled:GetText()) end
    for _, row in ipairs(f.list.rows) do
      if row:IsShown() and row.raid and row.raid.id == ${JSON.stringify(raidId)} and not row.right2:GetText():find("Cancelada", 1, true) then return "a la izquierda: " .. row.right2:GetText() end
    end
    local lay = SIM.CheckLayout(f) return #lay == 0 or lay[1]`);
  if (member !== true) return `miembro: ${member}`;
  return get(tarek, `
    if not (BG.window and BG.window:IsShown()) then BG:ToggleWindow() end
    BG:ShowView("raids") SIM.layout(834, 604)
    local f = BG.window.viewFrames.raids
    f.selected = ${JSON.stringify(raidId)} BG:RefreshView("raids") SIM.layout(834, 604)
    local d = f.detail
    if d.invite:IsShown() or d.cancelRaid:IsShown() then return "sigue con «Invitar» o «Cancelar»" end
    if not d.deleteRaid:IsShown() or d.edit.text:GetText() ~= "Volver a programar" then return "botones: " .. tostring(d.edit.text:GetText()) end
    local lay = SIM.CheckLayout(f) return #lay == 0 or ("maestro: " .. lay[1])`);
});

await t.check('«Volver a programar» y guardar la deja programada otra vez; «Borrar» la quita para todos (un miembro no puede)', async () => {
  const back = await get(tarek, `
    local f = BG.window.viewFrames.raids
    f.detail.edit:Click()
    f.form.save:Click()
    return BG.Raids.Get(${JSON.stringify(raidId)}).d.status`);
  if (back !== 'SCHEDULED') return `al guardarla: ${back}`;
  await net.advance(4);
  const seen = await get(rina, `return BG.Raids.Get(${JSON.stringify(raidId)}).d.status`);
  if (seen !== 'SCHEDULED') return `lo que ve Rina: ${seen}`;
  const member = await get(rina, `local r, w = BG.Raids.Delete(${JSON.stringify(raidId)}) return tostring(w)`);
  if (member !== 'permiso') return `un miembro la borró: ${member}`;
  await tarek.run(`assert(BG.Raids.Delete(${JSON.stringify(raidId)}))`);
  await net.advance(4);
  const gone = await get(rina, `return tostring(BG.Raids.Get(${JSON.stringify(raidId)}))`);
  return gone === 'nil' || `sigue: ${gone}`;
});

await t.check('ningún error interno y límites del juego respetados', async () => {
  if (net.violations.length) return net.violations.slice(0, 3).join('; ');
  for (const c of net.clients) {
    const e = await get(c, 'local e = BG.db.errors and BG.db.errors[1] return e and (e.where .. ": " .. e.error) or ""');
    if (e) return `${c.name}: ${e}`;
  }
  return true;
});

console.log(`(tráfico total: ${net.wire.length} tramas, ${net.wire.reduce((n, f) => n + Buffer.byteLength(f.msg), 0)} bytes)`);
net.close();
t.report();
