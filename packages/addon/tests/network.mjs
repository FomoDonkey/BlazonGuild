// Several simulated members of C A Ñ A D A, each running the real addon, talking through a simulated server:
// consent gate, hellos and versions, the messenger election, long messages, whispers between "First Surname"
// names, pacing, chat lockdown, refused sends and hostile frames.
import { createClient, checklist } from './harness.mjs';

const people = [
  { first: 'El', second: 'Peregrino', guid: 'Player-6842-0A1B2C3D', rosterIndex: 2, version: '0.2.0' },
  { first: 'Tarek', second: 'Vientoalto', guid: 'Player-6842-SIMA', rosterIndex: 1, version: '0.2.0' },
  { first: 'Rina', second: 'Dagaluna', guid: 'Player-6842-SIMB', rosterIndex: 5, version: '0.2.0' },
  { first: 'Sr', second: 'Brasa', guid: 'Player-6842-SIMC', rosterIndex: 7, version: '0.3.1' },
];

const wire = []; // every frame the server saw: { from, prefix, msg, dist, target, step }
const violations = [];
let inbox = [];
let step = 0;
const clients = [];
for (const [i, p] of people.entries()) {
  const client = await createClient({
    identity: p,
    version: p.version,
    seed: 11 + i,
    onSend: (m) => {
      const bytes = Buffer.byteLength(m.msg, 'utf8');
      if (bytes > 255) violations.push(`${p.first}: trama de ${bytes} bytes`);
      if (m.msg.includes('\0')) violations.push(`${p.first}: byte NUL`);
      if (m.prefix !== 'BlazonGuild') violations.push(`${p.first}: prefijo ${m.prefix}`);
      const frame = { from: `${p.first} ${p.second}`, ...m, step };
      wire.push(frame);
      inbox.push(frame);
    },
  });
  clients.push(client);
}
const [ana, tarek, rina, brasa] = clients; // "ana" plays El Peregrino (Peregrino)
const everyone = clients;

// Every member sees every guild member online who is played by a client.
for (const c of everyone) {
  await c.run(`for _, idx in ipairs({ ${people.map((p) => p.rosterIndex).join(', ')} }) do SIM.roster[idx][9] = true end`);
  await c.run(`${people.map((p) => `SIM.roster[${p.rosterIndex}][1] = ${JSON.stringify(`${p.first} ${p.second}`)}`).join('\n')}`);
}
for (const c of everyone) await c.login();

// Advances every client's clock by dt seconds in small steps, delivering frames like the server would
// (GUILD: every client, the sender's echo included; WHISPER: the named player; the server stamps
// senders as "First Surname-Realm" for players of another sub-realm).
async function advance(seconds, dt = 0.25) {
  for (let s = 0; s < seconds; s += dt) {
    step++;
    for (const c of everyone) await c.run(`SIM.advance(${dt})`);
    const batch = inbox;
    inbox = [];
    for (const f of batch) {
      const sender = f.from === 'Rina Dagaluna' ? 'Rina Dagaluna-ForeverPvP2' : f.from;
      if (f.dist === 'GUILD') {
        for (const c of everyone) c.deliver(f.prefix, f.msg, 'GUILD', sender);
      } else if (f.dist === 'WHISPER') {
        const to = everyone.find((c) => c.name === f.target);
        if (to) to.deliver(f.prefix, f.msg, 'WHISPER', sender);
      }
    }
  }
}
const sentBy = (name) => wire.filter((f) => f.from === name).length;
const get = async (c, expr) => {
  await c.run(`__out = (function() ${expr} end)()`);
  return c.lua.global.get('__out');
};

const t = checklist('comprobaciones de la red entre addons');

await t.check('sin aceptar la privacidad no sale nada', async () => {
  await advance(30);
  const n = wire.length;
  if (n) return `${n} tramas enviadas sin permiso`;
  const queued = await get(ana, 'local ok, why = BG.Comm.Send("HI", {}, "GUILD") return tostring(ok) .. ":" .. tostring(why)');
  return queued === 'false:consent' || queued;
});

await t.check('tras aceptar, todos se encuentran en menos de 20 s', async () => {
  for (const c of everyone) await c.run('BG.Consent.Accept()');
  await advance(20);
  for (const c of everyone) {
    const n = await get(c, 'return #BG.Peers.Active()');
    if (n !== 4) return `${c.name} ve ${n} miembros con el addon`;
  }
  return true;
});

await t.check('nombres con espacio y sufijo de reino se identifican bien', async () => {
  const seen = await get(ana, 'local p = BG.Peers.Get("Rina Dagaluna") return p and p.name or "nadie"');
  const echo = await get(ana, 'return BG.Comm.stats.echo');
  return (seen === 'Rina Dagaluna' && echo > 0) || `visto: ${seen}, ecos: ${echo}`;
});

await t.check('todos eligen al mismo mensajero (el maestro: los organizadores van primero)', async () => {
  const picks = [];
  for (const c of everyone) picks.push(await get(c, 'return BG.Peers.Messenger()'));
  if (new Set(picks).size !== 1) return picks.join(' / ');
  return picks[0] === 'Tarek Vientoalto' || `elegido ${picks[0]}`;
});

await t.check('aviso de versión nueva (Sr Brasa tiene 0.3.1)', async () => {
  const log = await get(ana, 'for _, l in ipairs(SIM.log) do if l:find("versión más nueva") then return l end end return ""');
  return log.includes('0.3.1') || `sin aviso: "${log}"`;
});

await t.check('un mensaje de 6 KB llega entero y en orden', async () => {
  for (const c of everyone) {
    await c.run(`
      BG.__got = {}
      BG.Comm.Register("TX", function(sender, body) BG.__got[#BG.__got + 1] = { sender = sender, body = body } end, { channels = { "GUILD", "WHISPER" } })
    `);
  }
  await ana.run(`
    local lines = {}
    for i = 1, 120 do lines[i] = "línea " .. i .. ": la raid del viernes en el Núcleo de Magma" end
    BG.__big = lines
    assert(BG.Comm.Send("TX", { lines = lines }, "GUILD", nil, { lane = "bulk" }))
    assert(BG.Comm.Send("TX", { small = 1 }, "GUILD"))
  `);
  await advance(60);
  for (const c of [tarek, rina, brasa]) {
    const r = await get(c, `
      if #BG.__got ~= 2 then return "recibidos " .. #BG.__got end
      local big = BG.__got[2].body.lines and BG.__got[2] or BG.__got[1]
      if #big.body.lines ~= 120 or big.body.lines[120] ~= "línea 120: la raid del viernes en el Núcleo de Magma" then return "contenido" end
      if BG.__got[1].body.small ~= 1 then return "el normal no adelantó al masivo" end
      return big.sender`);
    if (r !== 'El Peregrino') return `${c.name}: ${r}`;
  }
  return true;
});

await t.check('ritmo: nunca más de 4 tramas seguidas ni más de ~1 por 1,2 s sostenido', async () => {
  const mine = wire.filter((f) => f.from === 'El Peregrino');
  const bySecond = new Map();
  for (const f of mine) {
    const sec = Math.floor((f.step * 0.25) / 6); // windows of 6 s
    bySecond.set(sec, (bySecond.get(sec) ?? 0) + 1);
  }
  const worst = Math.max(...bySecond.values());
  return worst <= 4 + 6 / 1.2 + 1 || `peor ventana de 6 s: ${worst} tramas`;
});

await t.check('/bg prueba: abre Administración, el eco vuelve, los demás responden por susurro y sale un aviso', async () => {
  await ana.run('BG.commands.prueba()');
  await advance(14);
  const ping = await get(ana, 'local p = BG.Diagnostics.lastPing return tostring(p.echo ~= nil) .. "|" .. #p.answers .. "|" .. tostring(p.done)');
  if (ping !== 'true|3|true') return 'prueba: ' + ping;
  const notice = await get(ana, 'return BG.lastNotice and (BG.lastNotice.title .. ": " .. BG.lastNotice.text) or "sin aviso"');
  if (!notice.startsWith('Prueba superada: Volvió en') || !notice.includes('respondieron 3')) return 'aviso: ' + notice;
  const shown = await get(ana, 'return BG.window and BG.window:IsShown() and BG.db.settings.lastView or "cerrada"');
  if (shown !== 'admin') return 'pantalla: ' + shown;
  const whispers = wire.filter((f) => f.dist === 'WHISPER' && f.target === 'El Peregrino' && f.msg.startsWith('1!PO:')).length;
  return whispers === 3 || `${whispers} respuestas por susurro`;
});

await t.check('bloqueo del chat (banda): retiene y envía al salir', async () => {
  await ana.run('SIM.lockdown = true');
  await ana.run('assert(BG.Comm.Send("TX", { during = "raid" }, "GUILD"))');
  const before = sentBy('El Peregrino');
  await advance(20);
  if (sentBy('El Peregrino') !== before) return 'envió durante el bloqueo';
  const held = await get(ana, 'return BG.Comm.Held() or 0');
  if (held < 15) return `retenido ${held} s`;
  await ana.run('SIM.lockdown = false');
  await advance(8);
  const r = await get(tarek, 'local last = BG.__got[#BG.__got] return last and last.body.during or "nada"');
  return r === 'raid' || r;
});

await t.check('el juego dice "ahora no" (código 3): reintenta y entrega', async () => {
  await ana.run('SIM.sendResult = { 3, 3 } assert(BG.Comm.Send("TX", { retry = true }, "GUILD"))');
  await advance(20);
  const r = await get(rina, 'local last = BG.__got[#BG.__got] return last and tostring(last.body.retry) or "nada"');
  const retries = await get(ana, 'return BG.Comm.stats.retries');
  return (r === 'true' && retries >= 2) || `recibido ${r}, reintentos ${retries}`;
});

await t.check('tramas hostiles no rompen nada', async () => {
  await tarek.run(`
    local junk = { "", "1", "9!HI:{}", "1!HI:", "1!HI:{s", "1!hi:{}", "1!TX:" .. string.rep("[", 200), "1#zzzzzz", "1#0102", "z!X:T",
      "1!HI:{s1;i1;}", "1!PG:T", "1!PO:{sv;s" .. string.rep("9", 80) .. ";}" }
    for i = 1, 300 do junk[#junk + 1] = "1#" .. string.format("%02d", i % 99) .. "0109" .. string.rep("x", 200) end
    for _, f in ipairs(junk) do BG.Comm.OnMessage("BlazonGuild", f, "GUILD", "Atacante Malvado") end
    BG.Comm.OnMessage("BlazonGuild", "1!PO:{sv;s1;}", "GUILD", "Atacante Malvado") -- PO only by whisper
  `);
  const errors = await get(tarek, 'return #(BG.db.errors or {})');
  const peer = await get(tarek, 'return BG.Peers.Get("Atacante Malvado") and "sí" or "no"');
  return (errors === 0 && peer === 'no') || `errores ${errors}, atacante como compañero: ${peer}`;
});

await t.check('retirar la privacidad corta el envío al momento (solo sale la despedida)', async () => {
  await rina.run('BG.Consent.Decline()');
  const before = sentBy('Rina Dagaluna');
  const r = await get(rina, 'local ok, why = BG.Comm.Send("TX", {}, "GUILD") return tostring(why)');
  await advance(400, 1);
  const extra = wire.filter((f) => f.from === 'Rina Dagaluna').slice(before);
  const onlyGoodbye = extra.length === 1 && extra[0].msg.startsWith('1!BY:');
  const seen = await get(ana, 'return BG.Peers.Get("Rina Dagaluna") and "sí" or "no"');
  return (r === 'consent' && onlyGoodbye && seen === 'no') || `motivo ${r}, tramas ${extra.map((f) => f.msg.slice(0, 8)).join(',')}, la siguen viendo: ${seen}`;
});

await t.check('límites del juego respetados en todo el tráfico', async () => (violations.length ? violations.slice(0, 3).join('; ') : true));

await t.check('ningún error interno en ningún cliente', async () => {
  for (const c of everyone) {
    const e = await get(c, 'local e = BG.db.errors and BG.db.errors[1] return e and (e.where .. ": " .. e.error) or ""');
    if (e) return `${c.name}: ${e}`;
  }
  return true;
});

console.log(`(tráfico total: ${wire.length} tramas, ${wire.reduce((n, f) => n + Buffer.byteLength(f.msg), 0)} bytes)`);
for (const c of everyone) c.close();
t.report();
