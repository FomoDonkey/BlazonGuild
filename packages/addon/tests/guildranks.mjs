// Clasificación de hermandades (0.20.0): guilds of the same faction that use BlazonGuild compare their numbers. A
// guild shows only if its master says so, its card has numbers and never anyone's name, it travels when someone of
// ours groups with someone of another guild (verified by the game's own guild name of that player), our guild learns
// it from them, a card that lies about its guild stays «sin verificar» and is not passed on, and the screen ranks and
// compares.
import { createNetwork, checklist } from './harness.mjs';

const t = checklist('comprobaciones de la clasificación de hermandades');
const P = {
  tarek: { first: 'Tarek', second: 'Vientoalto', guid: 'Player-6842-SIMA', rosterIndex: 1 },
  peregrino: { first: 'El', second: 'Peregrino', guid: 'Player-6842-0A1B2C3D', rosterIndex: 2 },
  lobo: { first: 'Lobo', second: 'Feroz', guid: 'Player-7000-LOBO', rosterIndex: 1, guild: 'Los Lobos' },
  lobezno: { first: 'Lobezno', second: 'Ceniza', guid: 'Player-7000-LOBEZNO', rosterIndex: 2, guild: 'Los Lobos' },
  oso: { first: 'Oso', second: 'Pardo', guid: 'Player-7100-OSO', rosterIndex: 1, guild: 'Los Osos' },
};
const net = await createNetwork([P.tarek, P.peregrino, P.lobo, P.lobezno, P.oso]);
const [tarek, peregrino, lobo, lobezno, oso] = net.clients;
const get = net.get;
await net.loginAll();
for (const c of net.clients) await c.run('BG.Consent.Accept()');
await net.advance(20, 0.5);

// Two players in a raid together: each one's game knows the other's guild.
async function group(a, b, guildOfB, guildOfA) {
  net.group = [a, b];
  await a.run(`SIM.setRaid({ { ${JSON.stringify(a.person.first)}, ${JSON.stringify(a.person.second)}, 1 }, { ${JSON.stringify(b.person.first)}, ${JSON.stringify(b.person.second)}, 1 } })
    SIM.group.inRaid = true SIM.guildOf[${JSON.stringify(b.name)}] = ${JSON.stringify(guildOfB)} SIM.fire("GROUP_ROSTER_UPDATE")`);
  await b.run(`SIM.setRaid({ { ${JSON.stringify(a.person.first)}, ${JSON.stringify(a.person.second)}, 1 }, { ${JSON.stringify(b.person.first)}, ${JSON.stringify(b.person.second)}, 1 } })
    SIM.group.inRaid = true SIM.guildOf[${JSON.stringify(a.name)}] = ${JSON.stringify(guildOfA)} SIM.fire("GROUP_ROSTER_UPDATE")`);
  await net.advance(24, 0.5);
}
const known = (c) => get(c, `local out = {} for _, e in ipairs(BG.GuildRanks.Known()) do out[#out + 1] = e.card.n .. (e.mine and "*" or "") .. (e.verified and "" or "?") end table.sort(out) return table.concat(out, ",")`);

await t.check('sin publicar no sale nada: dos hermandades en grupo no se cuentan nada', async () => {
  await group(peregrino, lobezno, 'Los Lobos', 'C A Ñ A D A');
  const a = await known(peregrino);
  const b = await known(lobezno);
  return (a === '' && b === '') || `Peregrino conoce: ${a}; Lobezno: ${b}`;
});

await t.check('solo el maestro decide publicar; la ficha tiene cifras de la hermandad y ningún nombre de nadie', async () => {
  const member = await get(peregrino, 'local r, why = BG.GuildRanks.SetPublishing(true) return tostring(why)');
  await tarek.run('assert(BG.GuildRanks.SetPublishing(true))');
  await lobo.run('assert(BG.GuildRanks.SetPublishing(true))');
  await oso.run('assert(BG.GuildRanks.SetPublishing(true))');
  await net.advance(6);
  const card = await get(peregrino, `
    local c = BG.GuildRanks.Mine()
    if not c then return "sin ficha" end
    local keys = {}
    for k, v in pairs(c) do keys[#keys + 1] = k end
    table.sort(keys)
    local names = 0
    for _, v in pairs(c) do if type(v) == "string" and (v:find("Tarek") or v:find("Peregrino")) then names = names + 1 end end
    return c.n .. " " .. c.m .. " " .. names .. " " .. table.concat(keys, ",")`);
  return (member === 'permiso' && /^C A Ñ A D A \d+ 0 a,ar,b,c,cr,d,f,k,l,m,n,r,u,v,w$/.test(card)) || `miembro: ${member}; ficha: ${card}`;
});

await t.check('al jugar en grupo se conocen (verificadas por el juego) y cada uno lo pasa a su hermandad', async () => {
  await group(peregrino, lobezno, 'Los Lobos', 'C A Ñ A D A');
  const a = await known(peregrino);
  const b = await known(lobezno);
  const relayed = await known(tarek);
  const theirs = await known(lobo);
  return (a === 'C A Ñ A D A*,Los Lobos' && b === 'C A Ñ A D A,Los Lobos*' && relayed === 'C A Ñ A D A*,Los Lobos' && theirs === 'C A Ñ A D A,Los Lobos*')
    || `Peregrino: ${a}; Lobezno: ${b}; Tarek (no estaba): ${relayed}; Lobo (no estaba): ${theirs}`;
});

await t.check('lo que otro cuenta de una tercera hermandad llega «sin verificar» y no se pasa a la hermandad', async () => {
  await group(lobezno, oso, 'Los Osos', 'Los Lobos');
  await net.advance(16 * 60, 10); // (a quarter of an hour later they group again, and say hello again)
  await group(peregrino, lobezno, 'Los Lobos', 'C A Ñ A D A');
  const a = await known(peregrino);
  const relayed = await known(tarek);
  return (a === 'C A Ñ A D A*,Los Lobos,Los Osos?' && relayed === 'C A Ñ A D A*,Los Lobos') || `Peregrino: ${a}; Tarek: ${relayed}`;
});

await t.check('una ficha que miente sobre su hermandad no se verifica, y una de la otra facción no se guarda', async () => {
  net.group = [peregrino, lobezno];
  await lobezno.run(`
    local fake = { n = "Gran Hermandad", k = "EU|Gran Hermandad", f = "ALLIANCE", v = BG.Store.Now(), m = 999, b = 99 }
    BG.Comm.Send("GH", { c = fake }, "RAID")
    BG.Comm.Send("GK", { l = { { n = "Kor'kron", k = "EU|Kor'kron", f = "HORDE", v = BG.Store.Now(), m = 50 } } }, "WHISPER", "El Peregrino")`);
  await net.advance(10, 0.5);
  const a = await known(peregrino);
  const relayed = await known(tarek);
  return (a === 'C A Ñ A D A*,Gran Hermandad?,Los Lobos,Los Osos?' && !relayed.includes('Gran')) || `Peregrino: ${a}; Tarek: ${relayed}`;
});

await t.check('la clasificación por cada cifra, con vuestro puesto, y la comparativa con otra hermandad', async () => {
  const r = await get(peregrino, `
    local list = BG.GuildRanks.Ranking("m")
    local order = {}
    for _, e in ipairs(list) do order[#order + 1] = e.place .. ":" .. e.card.n end
    local places, n = BG.GuildRanks.MyPlaces()
    return table.concat(order, ",") .. " | " .. tostring(places.m) .. " de " .. n`);
  // (Gran Hermandad says 999 members: it ranks, marked «sin verificar»)
  return /^1:Gran Hermandad,\d:.+ \| \d de 4$/.test(r) || r;
});

await t.check('pantalla: pestaña «Hermandades» con la lista, la comparativa al pulsar y nada fuera de su sitio; «Honores» sigue igual', async () => {
  const r = await get(peregrino, `
    BG:ToggleWindow() BG:ShowView("rankings") SIM.layout(834, 604)
    local f = BG.window.viewFrames.rankings
    f.tabs.buttons[2]:Click() SIM.layout(834, 604)
    local rows = {}
    for _, row in ipairs(f.grows) do if row.name:IsShown() then rows[#rows + 1] = row.name:GetText() end end
    local lay = table.concat(SIM.CheckLayout(f), " ; ")
    local lobos
    for _, row in ipairs(f.grows) do if row.entry and row.entry.card.n == "Los Lobos" then lobos = row end end
    lobos.hit:Click()
    local dialog = BlazonGuildDialog and BlazonGuildDialog:IsShown() and BlazonGuildDialog.title:GetText() or "sin comparativa"
    BlazonGuildDialog:Hide()
    f.tabs.buttons[1]:Click() SIM.layout(834, 604)
    local lay2 = table.concat(SIM.CheckLayout(f), " ; ")
    return #rows .. " | " .. f.hero.title:GetText() .. " | " .. dialog .. " | " .. lay .. " | " .. lay2`);
  return r === '4 | Rankings y honores | Comparativa |  | ' || r;
});

await t.check('si el maestro deja de publicar, vuestra ficha desaparece y no se envía', async () => {
  await tarek.run('assert(BG.GuildRanks.SetPublishing(false))');
  await net.advance(6);
  const mine = await get(peregrino, 'return tostring(BG.GuildRanks.Mine() == nil)');
  const before = net.wire.length;
  await peregrino.run('BG.GuildRanks.Hello(true)');
  await net.advance(4);
  const gh = net.wire.slice(before).filter((f) => f.from === 'El Peregrino' && f.dist === 'RAID');
  const withCard = await get(peregrino, `local n = 0 for _, m in ipairs({${gh.map((f) => JSON.stringify(f.msg)).join(',')}}) do if m:find("E S P A") then n = n + 1 end end return n`);
  return (mine === 'true' && gh.length >= 1 && withCard === 0) || `sin ficha: ${mine}; saludos: ${gh.length}; con ficha: ${withCard}`;
});

net.close();
t.report();
