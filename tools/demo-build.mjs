// Builds packages/addon/BlazonGuild/Data/DemoData.lua: the example guild of the capture mode (/bg capturas, Core/Demo.lua).
// A simulated guild of invented players goes through the addon's own code for three weeks (duels, deaths to the Horde,
// donations, an Onyxia night, a tournament, orders, an alliance of three guilds…), in English and in Spanish, and
// the guild master's saved data is written down as a Lua table. Every name here is invented.
// Run: node tools/demo-build.mjs
import fs from 'node:fs';
import path from 'node:path';
import { createNetwork, root } from '../packages/addon/tests/harness.mjs';

const OUT = path.join(root, 'Data', 'DemoData.lua');
const HOUR = 3600;
const DAY = 24 * HOUR;

// [first, second, classFile, level, rankIndex, zoneKey, online]; the first rows of each guild play (they have the addon).
const ROSTER_A = [
  ['Aldric', 'Valemont', 'PALADIN', 60, 0, 'sw', true],
  ['Seren', 'Duskwhisper', 'PRIEST', 60, 1, 'if', true],
  ['Brom', 'Ironhide', 'WARRIOR', 60, 1, 'brm', true],
  ['Lyra', 'Nightbloom', 'DRUID', 60, 2, 'ws', true],
  ['Kael', 'Emberfall', 'MAGE', 60, 3, 'sw', true],
  ['Tessa', 'Quickfeather', 'HUNTER', 60, 3, 'fel', true],
  ['Finn', 'Lightstep', 'ROGUE', 60, 3, 'epl', true],
  ['Mira', 'Ashgrove', 'WARLOCK', 60, 2, 'sw', true],
  ['Dorn', 'Stonebrew', 'WARRIOR', 60, 3, 'if', true],
  ['Elsa', 'Brightforge', 'PALADIN', 58, 3, 'tan', true],
  ['Garrick', 'Hale', 'PRIEST', 60, 3, 'sw', true],
  ['Nyra', 'Frostvale', 'MAGE', 60, 2, 'ung', true],
  ['Rowan', 'Thistle', 'DRUID', 60, 3, 'fer', false],
  ['Talia', 'Swiftbrook', 'HUNTER', 57, 3, 'bs', false],
  ['Corin', 'Blackwood', 'ROGUE', 60, 2, 'sw', false],
  ['Isolde', 'Fairwind', 'PRIEST', 60, 3, 'if', false],
  ['Bram', 'Copperpot', 'WARRIOR', 52, 4, 'bs', false],
  ['Wren', 'Starling', 'MAGE', 60, 3, 'wpl', false],
  ['Odric', 'Greymantle', 'WARLOCK', 60, 3, 'sil', false],
  ['Fenna', 'Mossglen', 'DRUID', 44, 4, 'fer', false],
  ['Hollis', 'Reed', 'HUNTER', 60, 3, 'ws', false],
  ['Sabine', 'Moonwell', 'PRIEST', 60, 2, 'sw', false],
  ['Tobin', 'Ashdown', 'ROGUE', 39, 4, 'tan', false],
  ['Maren', 'Stormcrest', 'PALADIN', 60, 3, 'if', false],
  ['Edric', 'Holloway', 'WARRIOR', 60, 3, 'epl', false],
  ['Liora', 'Dawnmere', 'MAGE', 60, 3, 'sw', false],
  ['Gideon', 'Frost', 'WARLOCK', 55, 3, 'fel', false],
  ['Ysolde', 'Brook', 'HUNTER', 60, 3, 'ung', false],
  ['Percival', 'Oakes', 'PALADIN', 31, 4, 'sw', false],
  ['Nell', 'Hearthstone', 'PRIEST', 60, 3, 'if', false],
  ['Quill', 'Fenwick', 'ROGUE', 60, 3, 'brm', false],
  ['Adela', 'Wintergreen', 'DRUID', 60, 3, 'ws', false],
  ['Benedikt', 'Rook', 'WARRIOR', 47, 4, 'bs', false],
  ['Celia', 'Marsh', 'MAGE', 60, 3, 'sw', false],
  ['Darius', 'Vane', 'WARLOCK', 60, 3, 'sil', false],
  ['Emmeline', 'Shaw', 'HUNTER', 26, 4, 'sw', false],
];
const ROSTER_B = [
  ['Corwin', 'Ashford', 'WARRIOR', 60, 0, 'sw', true],
  ['Elena', 'Varga', 'PRIEST', 60, 1, 'sw', true],
  ['Hugo', 'Penrose', 'MAGE', 60, 2, 'if', true],
  ['Ilsa', 'Wren', 'HUNTER', 60, 3, 'fel', false],
  ['Jory', 'Kettle', 'ROGUE', 60, 3, 'bs', false],
  ['Kira', 'Ashvale', 'DRUID', 58, 3, 'ws', true],
  ['Lucan', 'Merrow', 'PALADIN', 60, 1, 'if', false],
  ['Mabel', 'Quint', 'WARLOCK', 60, 3, 'sw', false],
  ['Nils', 'Harrow', 'WARRIOR', 55, 4, 'tan', false],
  ['Oona', 'Pike', 'MAGE', 60, 3, 'sw', true],
  ['Piers', 'Calloway', 'PRIEST', 60, 3, 'epl', false],
  ['Rhea', 'Dunmore', 'HUNTER', 49, 4, 'fer', false],
];
const ROSTER_C = [
  ['Hilda', 'Thornwood', 'DRUID', 60, 0, 'if', true],
  ['Ansel', 'Birch', 'PALADIN', 60, 1, 'if', true],
  ['Bryn', 'Holt', 'WARRIOR', 60, 3, 'brm', false],
  ['Cora', 'Lindqvist', 'MAGE', 60, 3, 'sw', true],
  ['Davin', 'Shore', 'ROGUE', 60, 3, 'epl', false],
  ['Esme', 'Rowe', 'PRIEST', 60, 2, 'ws', true],
  ['Fitz', 'Morrow', 'HUNTER', 57, 3, 'tan', false],
  ['Greta', 'Hollin', 'WARLOCK', 60, 3, 'fel', false],
  ['Henrik', 'Vale', 'WARRIOR', 42, 4, 'bs', false],
  ['Ivy', 'Carrow', 'DRUID', 60, 3, 'ung', false],
];
const PLAYING = 8;
const full = (r) => `${r[0]} ${r[1]}`;
const N = Object.fromEntries([...ROSTER_A, ...ROSTER_B, ...ROSTER_C].map((r) => [r[0], full(r)])); // N.Aldric = "Aldric Valemont"
const guidOf = (realm, i) => `Player-${realm}-0000${String(i + 1).padStart(4, '0')}`;

// The Horde players who hunt the guild (invented too).
const FOES = {
  grokk: { guid: 'Player-9101-00000A01', name: 'Grokk', surname: 'Skullsplitter', class: 'WARRIOR', race: 'Orc' },
  vexa: { guid: 'Player-9101-00000A02', name: 'Vexa', surname: 'Shadowfang', class: 'ROGUE', race: 'Scourge' },
  thrumbo: { guid: 'Player-9101-00000A03', name: 'Thrumbo', surname: 'Ironhoof', class: 'HUNTER', race: 'Tauren' },
};

// Real items of the game (so the icons and tooltips are the game's own): tier 1 and Molten Core weapons (Forever has no
// Molten Core; its own loot is not public yet: to change when it is).
const GEAR = {
  Aldric: { 1: 16854, 3: 16856, 5: 16853, 6: 16858, 7: 16855, 8: 16859, 9: 16857, 10: 16860, 16: 17076 },
  Seren: { 1: 16813, 3: 16816, 5: 16815, 6: 16817, 7: 16814, 8: 16811, 9: 16819, 10: 16812, 16: 17103 },
  Brom: { 1: 16866, 3: 16868, 5: 16865, 6: 16864, 7: 16867, 8: 16862, 9: 16861, 10: 16863, 16: 18832, 17: 18832 },
  Lyra: { 1: 16834, 3: 16836, 5: 16833, 6: 16828, 7: 16835, 8: 16829, 9: 16830, 10: 16831, 16: 18842 },
  Kael: { 1: 16795, 3: 16797, 5: 16798, 6: 16802, 7: 16796, 8: 16800, 9: 16799, 10: 16801, 16: 17103 },
  Tessa: { 1: 16846, 3: 16848, 5: 16845, 6: 16851, 7: 16847, 8: 16849, 9: 16850, 10: 16852, 18: 17069 },
  Finn: { 1: 16821, 3: 16823, 5: 16820, 6: 16827, 7: 16822, 8: 16824, 9: 16825, 10: 16826, 16: 18832 },
  Mira: { 1: 16808, 3: 16807, 5: 16809, 6: 16806, 7: 16810, 8: 16803, 9: 16804, 10: 16805, 16: 18842 },
};
const WEAPONS = new Set([17076, 17103, 18832, 18842, 17069]);

const TEXT = {
  en: {
    guild: 'Heralds of Dawn', guildB: 'Silver Lances', guildC: 'Order of the Oak', alliance: 'Pact of the Dawn',
    ranks: ['Guild Master', 'Officer', 'Veteran', 'Member', 'Recruit'],
    classes: { PALADIN: 'Paladin', WARRIOR: 'Warrior', MAGE: 'Mage', PRIEST: 'Priest', ROGUE: 'Rogue', HUNTER: 'Hunter', WARLOCK: 'Warlock', DRUID: 'Druid' },
    zones: { sw: 'Stormwind City', if: 'Ironforge', brm: 'Blackrock Mountain', ws: 'Winterspring', fel: 'Felwood', epl: 'Eastern Plaguelands', tan: 'Tanaris', ung: "Un'Goro Crater", fer: 'Feralas', bs: 'Burning Steppes', wpl: 'Western Plaguelands', sil: 'Silithus' },
    ony: "Onyxia's Lair",
    motd: 'Onyxia on Friday at 21:00. Nobody forgets the amulet to get in!',
  },
  es: {
    guild: 'Heraldos del Alba', guildB: 'Lanzas de Plata', guildC: 'Orden del Roble', alliance: 'Pacto del Alba',
    ranks: ['Maestro', 'Oficial', 'Veterano', 'Miembro', 'Recluta'],
    classes: { PALADIN: 'Paladín', WARRIOR: 'Guerrero', MAGE: 'Mago', PRIEST: 'Sacerdote', ROGUE: 'Pícaro', HUNTER: 'Cazador', WARLOCK: 'Brujo', DRUID: 'Druida' },
    zones: { sw: 'Ventormenta', if: 'Forjaz', brm: 'Montaña Roca Negra', ws: 'Cuna del Invierno', fel: 'Frondavil', epl: 'Tierras de la Peste del Este', tan: 'Tanaris', ung: "Cráter de Un'Goro", fer: 'Feralas', bs: 'Las Estepas Ardientes', wpl: 'Tierras de la Peste del Oeste', sil: 'Silithus' },
    ony: 'Guarida de Onyxia',
    motd: 'Onyxia el viernes a las 21:00. ¡Que nadie se olvide el amuleto para entrar!',
  },
};

const lua = (v) => JSON.stringify(v); // a JS string as a Lua string literal (the same escapes, for what we use)

// A guild's roster, ranks and message of the day, as the game would give them to its members.
function rosterLua(T, guildName, rows, realm, motd) {
  return `
    SIM.guildName = ${lua(guildName)}
    local RK = { ${T.ranks.map(lua).join(', ')} }
    GuildControlGetNumRanks = function() return #RK end
    GuildControlGetRankName = function(i) return RK[i] end
    GetGuildRosterMOTD = function() return ${lua(motd)} end
    local rows = { ${rows.map((r, i) => `{ ${lua(full(r))}, ${lua(r[2])}, ${r[3]}, ${r[4]}, ${lua(T.zones[r[5]])}, ${r[6]}, ${lua(T.classes[r[2]])}, ${lua(guidOf(realm, i))}, ${(i * 3) % 9} }`).join(',\n')} }
    SIM.roster = {}
    SIM.lastOnline = {}
    for i, r in ipairs(rows) do
      SIM.roster[i] = { r[1], RK[r[4] + 1], r[4], r[3], r[7], r[5], "", "", r[6], 0, r[2], 100 + i * 37, 1, false, false, 3, r[8] }
      SIM.lastOnline[i] = r[9]
    end`;
}

async function build(lang) {
  const T = TEXT[lang];
  const L = (en, es) => (lang === 'en' ? en : es);
  const people = [
    ...ROSTER_A.slice(0, PLAYING).map((r, i) => ({ first: r[0], second: r[1], guid: guidOf(9001, i), rosterIndex: i + 1, guild: T.guild })),
    { first: 'Corwin', second: 'Ashford', guid: guidOf(9002, 0), rosterIndex: 1, guild: T.guildB },
    { first: 'Hilda', second: 'Thornwood', guid: guidOf(9003, 0), rosterIndex: 1, guild: T.guildC },
  ];
  const net = await createNetwork(people);
  const get = net.get;
  const C = Object.fromEntries(net.clients.map((c) => [c.person.first, c]));
  const A = net.clients.slice(0, PLAYING);
  for (const c of A) await c.run(rosterLua(T, T.guild, ROSTER_A, 9001, T.motd));
  await C.Corwin.run(rosterLua(T, T.guildB, ROSTER_B, 9002, L('Lances up!', '¡Lanzas en alto!')));
  await C.Hilda.run(rosterLua(T, T.guildC, ROSTER_C, 9003, L('Roots run deep.', 'Las raíces llegan hondo.')));
  const players = Object.values(FOES).map((f) => `SIM.players[${lua(f.guid)}] = { name = ${lua(f.name)}, surname = ${lua(f.surname)}, class = ${lua(f.class)}, race = ${lua(f.race)} }`).join('\n');
  // (every BattleTag invented too: the simulator's own is a placeholder that must not end up in the example)
  for (const [i, c] of net.clients.entries()) await c.run(`${players} BG.Alliance.REFRESH_EVERY = 30 SIM.battletag = ${lua(`${c.person.first}#${2100 + i * 37}`)}`);
  for (const c of net.clients) {
    const row = [...ROSTER_A, ...ROSTER_B, ...ROSTER_C].find((r) => r[0] === c.person.first);
    await c.run(`SIM.zone = ${lua(T.zones[row[5]])} SIM.myLevel = ${row[3]}`); // (their level: the duels keep both fighters' levels)
  }
  await net.loginAll();
  for (const c of net.clients) await c.run('BG.Consent.Accept() for _, l in ipairs({ "position", "gear", "alts", "sightings", "battletag" }) do pcall(BG.Consent.SetLine, l, true) end');
  await net.advance(30, 0.5);

  const must = async (who, code, what) => {
    const r = await get(C[who], `local ok, a, b = pcall(function() ${code} end) if not ok then return "ERROR " .. tostring(a) end if a == nil and b ~= nil then return "NO " .. tostring(b) end return "ok"`);
    if (r !== 'ok') throw new Error(`${lang} · ${what}: ${r}`);
  };
  const value = (who, code) => get(C[who], code);
  // Time passes: every clock moves together (its timers too), and the guild says hello again.
  const jump = async (secs) => {
    for (const c of net.clients) await c.run(`SIM.now = SIM.now + ${secs} for _, t in ipairs(SIM.timers) do t.due = t.due + ${secs} end`);
    await net.advance(100, 1);
  };
  const closeDialogs = async () => {
    for (const c of net.clients) await c.run('if BlazonGuildDialog and BlazonGuildDialog:IsShown() then BlazonGuildDialog:Hide() end');
  };
  // A line in the guild chat, as the game gives it to everyone (the master's addon keeps it).
  const say = async (who, text) => {
    for (const c of A) await c.run(`SIM.fire("CHAT_MSG_GUILD", ${lua(text)}, ${lua(N[who])}, "", "", ${lua(N[who])}, "", 0, 0, "", 0, math.random(1, 1e6), "")`);
    await net.advance(1, 0.5);
  };
  // A duel the game reports to everyone near: the loser's addon writes it down.
  const DUEL_ZONES = ['sw', 'if', 'sw', 'brm', 'ws', 'if', 'tan'];
  let duels = 0;
  const duel = async (w, l) => {
    const zone = T.zones[DUEL_ZONES[duels++ % DUEL_ZONES.length]];
    for (const c of A) await c.run(`SIM.zone = ${lua(zone)}`);
    for (const c of A) await c.run(`SIM.fire("CHAT_MSG_SYSTEM", ${lua(`${N[w]} has defeated ${N[l]} in a duel`)})`);
    await net.advance(3, 0.5);
  };
  // A member killed out in the world by a Horde player (the death recap the game keeps).
  const die = async (who, foe, zone) => {
    const f = FOES[foe];
    await C[who].run(`SIM.zone = ${lua(T.zones[zone])}
      SIM.recap = { { timestamp = GetServerTime(), event = "SWING_DAMAGE", sourceGUID = ${lua(f.guid)}, sourceName = ${lua(f.name)}, sourceFlags = 0x548, overkill = 40, destGUID = SIM.me.guid },
        { timestamp = GetServerTime() - 2, event = "SPELL_DAMAGE", sourceGUID = ${lua(f.guid)}, sourceName = ${lua(f.name)}, sourceFlags = 0x548, overkill = -1, destGUID = SIM.me.guid } }
      SIM.dead = true SIM.fire("PLAYER_DEAD")`);
    await net.advance(4, 0.5);
    await C[who].run('SIM.dead = false SIM.recap = {}');
  };

  // Day -21: the guild sets itself up ----------------------------------------------------------------------------------
  const bios = {
    Aldric: [L('Guild master. Raids on Friday and Sunday, duels any time.', 'Maestro de la hermandad. Raids viernes y domingo, duelos cuando quieras.'), 'TANK', L('Evenings, 20:00–00:00', 'Tardes, 20:00–00:00')],
    Seren: [L('Healer and treasurer. Ask me about the potion fund.', 'Sanadora y tesorera. Pregúntame por el bote de pociones.'), 'HEALER', L('Every night', 'Todas las noches')],
    Brom: [L('Main tank. If it moves, I hold it.', 'Tanque principal. Si se mueve, lo aguanto.'), 'TANK', L('Weekends', 'Fines de semana')],
    Lyra: [L('Resto druid, herbalist and flower collector.', 'Druida restauración, herbolista y coleccionista de flores.'), 'HEALER', ''],
    Kael: [L('Frost mage. Water and portals on request.', 'Mago de escarcha. Agua y portales a demanda.'), 'DPS', ''],
    Tessa: [L('Hunter with a very hungry cat.', 'Cazadora con un gato muy hambriento.'), 'DPS', ''],
    Finn: [L('Rogue. You will not see me coming.', 'Pícaro. No me verás venir.'), 'DPS', L('Late nights', 'Madrugadas')],
    Mira: [L('Warlock: summons, soulstones and bad jokes.', 'Bruja: invocaciones, piedras de alma y chistes malos.'), 'DPS', ''],
  };
  for (const [who, [bio, role, hours]] of Object.entries(bios)) await must(who, `return BG.People.Publish({ bio = ${lua(bio)}, role = ${lua(role)}, hours = ${lua(hours)} })`, `perfil ${who}`);
  await must('Aldric', `return BG.Treasury.Configure({ keepers = ${lua(N.Seren)}, dues = 200000 })`, 'tesorería');
  await must('Seren', `return BG.Recruit.SaveCharter({ open = true, about = ${lua(L('Friendly Alliance guild: Onyxia, Hyjal Summit and the Barrow Deeps every week, PvP on weekends, and a tavern that never closes.', 'Hermandad de la Alianza con buen ambiente: Onyxia, Cima Hyjal y las Cavernas del Túmulo cada semana, JcJ los fines de semana y una taberna que nunca cierra.'))},
    lang = ${lua(L('English', 'Español'))}, days = ${lua(L('Wednesday to Sunday, 20:00–00:00', 'De miércoles a domingo, 20:00–00:00'))}, roles = { HEALER = true, TANK = true }, classes = { "PRIEST", "DRUID", "WARRIOR" }, contact = ${lua(N.Seren)} })`, 'carta');
  // Professions: each crafter opens their book once and publishes it.
  const crafts = {
    Brom: [L('Blacksmithing', 'Herrería'), 300, [[L('Weapons', 'Armas'), 'header'], [L('Arcanite Reaper', 'Segadora de arcanita'), 'optimal', 12784], [L('Lionheart Helm', 'Yelmo de corazón de león'), 'optimal', 12640], [L('Imperial Plate Belt', 'Cinturón de placas imperial'), 'medium', 12424]]],
    Lyra: [L('Alchemy', 'Alquimia'), 300, [[L('Flasks', 'Frascos'), 'header'], [L('Flask of the Titans', 'Frasco de los titanes'), 'optimal', 13510], [L('Elixir of the Mongoose', 'Elixir de la mangosta'), 'optimal', 13452], [L('Greater Fire Protection Potion', 'Poción de protección contra el Fuego superior'), 'medium', 13457], [L('Major Healing Potion', 'Poción de sanación excelente'), 'medium', 13446]]],
    Kael: [L('Tailoring', 'Sastrería'), 290, [[L('Cloth', 'Tela'), 'header'], [L('Robe of the Archmage', 'Toga del archimago'), 'optimal', 14152], [L('Runecloth Bag', 'Bolsa de paño rúnico'), 'medium', 14046]]],
  };
  for (const [who, [prof, rank, recipes]] of Object.entries(crafts)) {
    await C[who].run(`SIM.trade = { name = ${lua(prof)}, rank = ${rank}, max = 300, recipes = { ${recipes.map((x) => `{ ${x.map((y) => (typeof y === 'number' ? y : lua(y))).join(', ')} }`).join(', ')} } }
      SIM.fire("TRADE_SKILL_SHOW") SIM.advance(1) SIM.trade = nil`);
    await closeDialogs();
    await must(who, `return BG.Crafts.SetShare(${lua(prof)}, true)`, `artesanía ${who}`);
  }
  // Gear: everyone shares theirs.
  for (const [who, slots] of Object.entries(GEAR)) {
    const ilvl = Object.values(slots).map((id) => `SIM.ilvl[${id}] = ${WEAPONS.has(id) ? 75 : 66}`).join(' ');
    await C[who].run(`SIM.gear.player = { ${Object.entries(slots).map(([s, id]) => `[${s}] = ${id}`).join(', ')} } ${ilvl}`);
    await closeDialogs();
    await must(who, 'BG.Armory.SetSharing(true) BG.Armory.Publish() return true', `armería ${who}`);
  }
  // The guilds publish their numbers, and the alliance is made.
  for (const who of ['Aldric', 'Corwin', 'Hilda']) await must(who, 'return BG.GuildRanks.SetPublishing(true)', `cifras ${who}`);
  await must('Aldric', `return BG.Alliance.Create(${lua(T.alliance)})`, 'alianza');
  await net.advance(4, 0.5);
  for (const who of ['Corwin', 'Hilda']) {
    await C.Aldric.run(`INV = nil assert(BG.Alliance.Invite(${lua(N[who])}, function(t) INV = t end))`);
    await net.advance(8, 0.5);
    const token = await value('Aldric', 'return INV');
    if (!token) throw new Error(`${lang} · invitación a ${who} sin firmar`);
    await must(who, `return BG.Alliance.Accept(${lua(token)})`, `${who} acepta`);
    await net.advance(40, 0.5);
  }
  await closeDialogs();
  const ally = await value('Aldric', 'local d = BG.Alliance.Doc() return d and #d.guilds or 0');
  if (ally !== 3) throw new Error(`${lang} · la alianza tiene ${ally} hermandades`);

  // Three weeks of guild life ------------------------------------------------------------------------------------------
  // Duels: the better fighter usually wins (a fixed order, so the ranking is the same every time).
  const strength = ['Finn', 'Brom', 'Tessa', 'Kael', 'Aldric', 'Mira', 'Lyra', 'Seren'];
  const fighters = [...strength];
  let seed = 7;
  const rnd = () => {
    seed = (seed * 9301 + 49297) % 233280;
    return seed / 233280;
  };
  const days = [];
  for (let d = -20; d <= -1; d++) days.push(d);
  const donations = { '-19': ['Aldric', 300000], '-17': ['Brom', 200000], '-15': ['Kael', 250000], '-12': ['Lyra', 200000], '-10': ['Finn', 400000], '-8': ['Tessa', 200000], '-6': ['Mira', 150000], '-4': ['Aldric', 200000], '-3': ['Brom', 200000], '-2': ['Kael', 200000], '-1': ['Lyra', 100000] };
  const deaths = { '-15': ['Kael', 'grokk', 'fel'], '-9': ['Tessa', 'grokk', 'ws'], '-6': ['Lyra', 'vexa', 'epl'], '-4': ['Seren', 'grokk', 'fel'], '-3': ['Mira', 'thrumbo', 'tan'], '-2': ['Finn', 'vexa', 'epl'] };
  const chatter = {
    '-14': [['Brom', L('Anyone up for Blackrock Depths?', '¿Alguien para Profundidades de Roca Negra?')], ['Kael', L('Me! Bring the water, I bring the portal.', '¡Yo! Traed agua, yo pongo el portal.')]],
    '-7': [['Seren', L('Potion fund is open: Fire Protection for Friday.', 'Bote de pociones abierto: protección contra el Fuego para el viernes.')], ['Finn', L('Sent 40g, see you at the gate.', 'Enviados 40 o, nos vemos en la puerta.')]],
  };
  let campaign = null;
  let cupId = null;
  for (const d of days) {
    await jump(d === -20 ? DAY : DAY);
    // two or three duels a day
    const n = 2 + (d % 2 === 0 ? 1 : 0);
    for (let k = 0; k < n; k++) {
      const a = fighters[Math.floor(rnd() * fighters.length)];
      let b = fighters[Math.floor(rnd() * fighters.length)];
      if (b === a) b = fighters[(fighters.indexOf(a) + 1) % fighters.length];
      const better = strength.indexOf(a) < strength.indexOf(b) ? a : b;
      const worse = better === a ? b : a;
      const upset = rnd() < 0.4;
      await duel(upset ? worse : better, upset ? better : worse);
    }
    if (deaths[d]) {
      const [who, foe, zone] = deaths[d];
      await die(who, foe, zone);
    }
    if (d === -16) {
      await must('Seren', `return BG.Treasury.NewCampaign(${lua(L('Fire Protection Potions for Onyxia', 'Pociones contra el Fuego para Onyxia'))}, 3000000, 30)`, 'campaña');
      campaign = await value('Seren', 'return BG.Treasury.Campaigns()[1].id');
    }
    if (donations[d]) {
      const [who, amount] = donations[d];
      await must('Seren', `local r = assert(BG.Treasury.Record("IN", ${amount}, ${lua(N[who])}, "TRADE", "")) ${campaign && d % 3 === 0 ? `BG.Treasury.EditLine(r.id, { camp = ${lua(campaign)} })` : ''} return r`, `donación ${who}`);
    }
    if (d === -11) await must('Seren', `return BG.Treasury.Record("OUT", 450000, ${lua(N.Lyra)}, "MAIL", ${lua(L('Flasks for the raid', 'Frascos para la raid'))})`, 'gasto');
    if (d === -8) {
      // Brom lands the killing blow on the most wanted
      await C.Brom.run(`SIM.zone = ${lua(T.zones.fel)}`);
      await must('Brom', `return BG.Wanted.PartyKill(UnitGUID("player"), ${lua(FOES.grokk.guid)})`, 'caza');
      await net.advance(4, 0.5);
    }
    if (d === -7) {
      // A raid night: Onyxia, last week (Forever's raids: The Barrow Deeps, Hyjal Summit and Onyxia's Lair). Sign-ups
      // the day before, the boss on the night.
      const start = await value('Aldric', `return BG.Store.Now() + ${DAY - 3 * HOUR}`);
      await must('Aldric', `local r = assert(BG.Raids.Save(nil, { inst = "ONY", start = ${start}, note = ${lua(L('Fire resistance, flasks and patience.', 'Resistencia al Fuego, frascos y paciencia.'))} })) MCLAST = r.id return r`, 'raid pasada');
      await net.advance(4, 0.5);
      const id = await value('Aldric', 'return MCLAST');
      const roles = { Aldric: 'TANK', Brom: 'TANK', Seren: 'HEALER', Lyra: 'HEALER', Kael: 'DPS', Tessa: 'DPS', Finn: 'DPS', Mira: 'DPS' };
      for (const [who, role] of Object.entries(roles)) await must(who, `return BG.Raids.SignUp(${lua(id)}, "CONFIRMED", ${lua(role)})`, `apuntarse ${who}`);
      await net.advance(4, 0.5);
    }
    if (d === -6) {
      const raid = `SIM.setRaid({ ${A.map((c, i) => `{ ${lua(c.person.first)}, ${lua(c.person.second)}, ${1 + Math.floor(i / 5)} }`).join(', ')} }) SIM.group.inRaid = true SIM.instance = { name = ${lua(T.ony)}, kind = "raid", mapId = 249, size = 40 }`;
      for (const c of A) await c.run(raid);
      for (const c of A) await c.run('SIM.fire("ENCOUNTER_END", 1084, "Onyxia", 9, 40, 1)');
      await net.advance(6, 1);
      for (const c of A) await c.run('SIM.instance = nil SIM.group.inRaid = false SIM.setRaid({}) SIM.fire("GROUP_ROSTER_UPDATE")');
      await net.advance(4, 0.5);
    }
    if (d === -5) {
      // The guilds meet in a raid: their numbers cross (the guild ranking).
      for (const [a, b, gb, ga] of [['Aldric', 'Corwin', T.guildB, T.guild], ['Aldric', 'Hilda', T.guildC, T.guild]]) {
        const ca = C[a];
        const cb = C[b];
        net.group = [ca, cb];
        await ca.run(`SIM.setRaid({ { ${lua(ca.person.first)}, ${lua(ca.person.second)}, 1 }, { ${lua(cb.person.first)}, ${lua(cb.person.second)}, 1 } }) SIM.group.inRaid = true SIM.guildOf[${lua(cb.name)}] = ${lua(gb)} SIM.fire("GROUP_ROSTER_UPDATE")`);
        await cb.run(`SIM.setRaid({ { ${lua(ca.person.first)}, ${lua(ca.person.second)}, 1 }, { ${lua(cb.person.first)}, ${lua(cb.person.second)}, 1 } }) SIM.group.inRaid = true SIM.guildOf[${lua(ca.name)}] = ${lua(ga)} SIM.fire("GROUP_ROSTER_UPDATE")`);
        await net.advance(24, 0.5);
        for (const c of [ca, cb]) await c.run('SIM.group.inRaid = false SIM.setRaid({}) SIM.fire("GROUP_ROSTER_UPDATE")');
        net.group = [];
      }
    }
    if (d === -3) {
      // The Friday cup: eight fighters, seeded by the ranking, drawn with /roll; the first round is fought.
      await must('Brom', `local r = assert(BG.Tourney.Create({ kind = "CUP", title = ${lua(L('Friday Cup', 'Copa del viernes'))}, when = ${lua(L('Friday 22:00', 'viernes 22:00'))}, size = 8 })) CUP = r.id return r`, 'copa');
      await net.advance(4, 0.5);
      const cup = await value('Brom', 'return CUP');
      for (const c of A) await c.run(`BG.Tourney.Enter(${lua(cup)})`);
      await net.advance(6, 0.5);
      await C.Brom.run('SIM.rolls = { 3, 1, 2, 1 }');
      await must('Brom', `return BG.Tourney.Draw(${lua(cup)})`, 'sorteo');
      await net.advance(10, 0.5);
      await closeDialogs();
      cupId = cup;
    }
    if (d === -1 || d === -2) {
      // Rounds of the cup: the bracket's open matches are fought (the final stays for tonight).
      const open = await value('Brom', `local t = BG.Tourney.Get(${lua(cupId)}) local out = {} for _, round in ipairs(BG.Tourney.Bracket(t)) do for _, m in ipairs(round) do if m.a and m.b and not m.winner then out[#out + 1] = m.a .. "|" .. m.b .. "|" .. m.round end end end return table.concat(out, ";")`);
      const matches = (open || '').split(';').filter(Boolean).map((s) => s.split('|'));
      const R = d === -2 ? '1' : '2';
      for (const [a, b, round] of matches) {
        if (round !== R) continue;
        const fa = Object.keys(N).find((k) => N[k] === a);
        const fb = Object.keys(N).find((k) => N[k] === b);
        const fav = strength.indexOf(fa) < strength.indexOf(fb) ? a : b;
        const w = rnd() < 0.35 ? (fav === a ? b : a) : fav;
        const l = w === a ? b : a;
        for (const c of A) await c.run(`SIM.fire("CHAT_MSG_SYSTEM", ${lua(`${w} has defeated ${l} in a duel`)})`);
        await net.advance(3, 0.5);
      }
      await closeDialogs();
    }
    if (chatter[d]) for (const [who, text] of chatter[d]) await say(who, text);
    await net.advance(10, 0.5); // (what was written today goes out before the clock jumps)
  }
  await jump(10 * HOUR);
  return { net, C, A, T, L, must, value, say, jump, closeDialogs, lang };
}

// Today: what is on right now (raids to come, groups, polls, orders, the alliance's letters…) -----------------------------
async function today(ctx) {
  const { C, T, L, must, value, say, closeDialogs, net, lang } = ctx;
  ctx.sched = []; // what is planned: { collection, id, days from today, local hour } (Core/Demo.lua puts it on that evening)
  const now = await value('Aldric', 'return BG.Store.Now()');
  const at = (days, hour) => {
    const d = new Date((now + days * DAY) * 1000);
    d.setUTCHours(hour - 1, 0, 0, 0); // (21:00 in Central Europe: 20:00 UTC)
    return Math.floor(d.getTime() / 1000);
  };
  // Raids
  await must('Aldric', `local r = assert(BG.Raids.Save(nil, { inst = "ONY", start = ${at(1, 21)}, note = ${lua(L('Fire resistance and flasks. Whelps on the left, deep breaths in phase 3.', 'Resistencia al Fuego y frascos. Crías a la izquierda, y en la fase 3, respirad hondo.'))} })) MCNEXT = r.id return r`, 'raid Onyxia');
  await must('Brom', `local r = assert(BG.Raids.Save(nil, { inst = "HYJAL", start = ${at(2, 20)}, note = ${lua(L('First night at Hyjal Summit: thirteen bosses to learn.', 'Primera noche en la Cima Hyjal: trece jefes por aprender.'))} })) ONY = r.id return r`, 'raid Hyjal');
  await must('Aldric', `local r = assert(BG.Raids.Save(nil, { inst = "BARROW", start = ${at(4, 21)}, note = ${lua(L('Ten of us into the Barrow Deeps. Learning night.', 'Diez a las Cavernas del Túmulo. Noche de aprendizaje.'))} })) BWL = r.id return r`, 'raid Barrow');
  await net.advance(4, 0.5);
  const mc = await value('Aldric', 'return MCNEXT');
  const ony = await value('Brom', 'return ONY');
  ctx.sched.push(['raids', mc, 1, 21], ['raids', ony, 2, 20], ['raids', await value('Aldric', 'return BWL'), 4, 21]);
  const signs = {
    Aldric: ['CONFIRMED', 'TANK'], Brom: ['CONFIRMED', 'TANK'], Seren: ['CONFIRMED', 'HEALER'], Lyra: ['CONFIRMED', 'HEALER'],
    Kael: ['CONFIRMED', 'DPS'], Tessa: ['CONFIRMED', 'DPS'], Finn: ['TENTATIVE', 'DPS', L('Might be late', 'Puede que llegue tarde')], Mira: ['CONFIRMED', 'DPS'],
  };
  for (const [who, [status, role, note]] of Object.entries(signs)) {
    await must(who, `return BG.Raids.SignUp(${lua(mc)}, ${lua(status)}, ${lua(role)}${note ? `, ${lua(note)}` : ''})`, `MC ${who}`);
    if (who !== 'Finn') await must(who, `return BG.Raids.SignUp(${lua(ony)}, "CONFIRMED", ${lua(role)})`, `Ony ${who}`);
  }
  await net.advance(6, 0.5);
  const groups = { Aldric: [1, 1], Brom: [2, 1], Seren: [1, 2], Lyra: [2, 2], Kael: [3, 1], Tessa: [3, 2], Finn: [4, 1], Mira: [4, 2] };
  for (const [who, [g, row]] of Object.entries(groups)) await must('Aldric', `return BG.Raids.Move(${lua(mc)}, ${lua(N[who])}, ${g}, ${row})`, `grupos ${who}`);
  await net.advance(6, 0.5);
  // Groups for dungeons, and people looking for one
  await must('Lyra', `return BG.Groups.Create("BRD", { TANK = 1, HEALER = 1, DPS = 3 }, ${lua(L('Emperor run, quick and clean', 'A por el Emperador, rápido y limpio'))}, "HEALER")`, 'grupo BRD');
  await must('Kael', `return BG.Groups.Create("STRAT", { TANK = 1, HEALER = 1, DPS = 3 }, ${lua(L('Baron run for the mount', 'Barón para la montura'))}, "DPS")`, 'grupo Strat');
  await must('Finn', `return BG.Groups.RaiseFlag("DUNGEON", "SCHOLO", "DPS", ${lua(L('Free all evening', 'Libre toda la tarde'))})`, 'bandera Finn');
  await must('Tessa', `return BG.Groups.RaiseFlag("DUNGEON", "UBRS", "DPS", "")`, 'bandera Tessa');
  await net.advance(4, 0.5);
  await must('Tessa', `return BG.Groups.Ask((BG.Groups.List and BG.Groups.List()[1] or {}).id or "", "DPS")`, 'pedir grupo').catch(() => {});
  // The board: news, a poll with votes, the guild's own questions
  await must('Aldric', `return BG.Board.Post(${lua(L('Onyxia this Friday', 'Onyxia este viernes'))}, ${lua(L('We are ready. Fire resistance, flasks, food and your amulet. At the lair at 20:45.', 'Estamos listos. Resistencia al Fuego, frascos, comida y el amuleto. En la guarida a las 20:45.'))}, true)`, 'anuncio 1');
  await must('Seren', `return BG.Board.Post(${lua(L('Potion fund', 'Bote de pociones'))}, ${lua(L('Thanks to everyone who gave this week. We are close to the goal!', 'Gracias a todos los que habéis aportado esta semana. ¡Estamos cerca de la meta!'))})`, 'anuncio 2');
  await must('Aldric', `local r = assert(BG.Board.Ask(${lua(L('Which raid on Sunday?', '¿Qué banda el domingo?'))}, { ${[L("Onyxia's Lair", 'Guarida de Onyxia'), L('Hyjal Summit', 'Cima Hyjal'), L('The Barrow Deeps', 'Cavernas del Túmulo')].map(lua).join(', ')} }, 2880)) POLL = r.id return r`, 'encuesta');
  await net.advance(4, 0.5);
  const poll = await value('Aldric', 'return POLL');
  const votes = { Aldric: 3, Seren: 1, Brom: 3, Lyra: 2, Kael: 3, Tessa: 1, Finn: 3 };
  for (const [who, v] of Object.entries(votes)) await must(who, `return BG.Board.Vote(${lua(poll)}, ${v})`, `voto ${who}`);
  await must('Aldric', `return BG.Store.Put("faq", "fire", { q = ${lua(L('Where do I get fire resistance?', '¿Dónde consigo resistencia al Fuego?'))}, a = ${lua(L('Ask Brom for the plate set and Lyra for potions. The guild bank has two cloaks.', 'Pide a Brom el conjunto de placas y a Lyra las pociones. El banco tiene dos capas.'))} })`, 'faq');
  for (const who of ['Seren', 'Brom', 'Kael', 'Tessa', 'Finn']) await C[who].run('for _, n in ipairs(BG.Board.News()) do pcall(BG.Board.MarkRead, n.id) end');
  // Chat: a room, and the guild talking
  await must('Seren', `local r = assert(BG.Chat.CreateRoom(${lua(L('Friday raid', 'Raid del viernes'))}, ${lua(L('Onyxia prep', 'Preparación de Onyxia'))})) ROOM = r.id return r`, 'sala');
  await net.advance(4, 0.5);
  const room = await value('Seren', 'return ROOM');
  const roomLines = [
    ['Seren', L('Healing groups: I take the tanks, Lyra on melee.', 'Grupos de sanación: yo a los tanques, Lyra a cuerpo a cuerpo.')],
    ['Brom', L('I turn Onyxia to the wall. Ranged, on the whelps.', 'Pongo a Onyxia mirando a la pared. Los de distancia, a las crías.')],
    ['Kael', L('Frost Nova on the whelps from me. Mira, soulstone on Seren please.', 'Yo congelo a las crías. Mira, piedra de alma a Seren, por favor.')],
    ['Mira', L('Done. Summons at 20:40 at the gate.', 'Hecho. Invoco a las 20:40 en la puerta.')],
  ];
  for (const [who, text] of roomLines) await must(who, `return BG.Chat.Send(${lua(room)}, ${lua(text)})`, `sala ${who}`);
  await must('Lyra', `return BG.Chat.Send("trade", ${lua(L('Selling Flasks of the Titans, mats from you.', 'Vendo Frascos de los titanes, materiales tuyos.'))})`, 'comercio');
  await must('Tessa', `return BG.Chat.Send("healers", ${lua(L('Any healer for Scholomance in 10 min?', '¿Algún sanador para Scholomance en 10 min?'))})`, 'sanadores');
  await net.advance(4, 0.5);
  const guildChat = [
    ['Finn', L('Who stole my cheese?', '¿Quién me ha robado el queso?')],
    ['Mira', L('Not me. Probably the cat.', 'Yo no. Seguramente el gato.')],
    ['Tessa', L('My cat would never.', 'Mi gato nunca haría eso.')],
    ['Brom', L('Ready for tonight. Repairs done!', 'Listo para esta noche. ¡Reparado!')],
    ['Kael', L('Portal to Ironforge in 2 minutes, last call.', 'Portal a Forjaz en 2 minutos, última llamada.')],
    ['Aldric', L('Duel at the gate, anyone? The belt is waiting.', '¿Duelo en la puerta? El cinturón espera.')],
  ];
  for (const [who, text] of guildChat) await say(who, text);
  // Crafting orders and loot notes
  const link = (id, en, es, q = 'a335ee') => `|cff${q}|Hitem:${id}::::::::|h[${L(en, es)}]|h|r`;
  await must('Finn', `local r = assert(BG.Crafts.Order({ what = ${lua(link(12784, 'Arcanite Reaper', 'Segadora de arcanita'))}, qty = 1, note = ${lua(L('I bring the arcanite bars', 'Pongo yo las barras de arcanita'))} })) ORD1 = r.id return r`, 'encargo 1');
  await must('Tessa', `local r = assert(BG.Crafts.Order({ what = ${lua(link(13510, 'Flask of the Titans', 'Frasco de los titanes', 'ffffff'))}, qty = 3, note = ${lua(L('For Friday', 'Para el viernes'))} })) ORD2 = r.id return r`, 'encargo 2');
  await must('Mira', `local r = assert(BG.Crafts.Order({ what = ${lua(link(14152, 'Robe of the Archmage', 'Toga del archimago'))}, qty = 1 })) ORD3 = r.id return r`, 'encargo 3');
  await net.advance(4, 0.5);
  const o2 = await value('Tessa', 'return ORD2');
  const o3 = await value('Mira', 'return ORD3');
  await must('Lyra', `return BG.Crafts.Take(${lua(o2)})`, 'Lyra toma');
  await must('Kael', `return BG.Crafts.Take(${lua(o3)})`, 'Kael toma');
  await net.advance(4, 0.5);
  await must('Kael', `return BG.Crafts.Done(${lua(o3)})`, 'Kael hecho');
  await net.advance(4, 0.5);
  await must('Mira', `return BG.Crafts.Confirm(${lua(o3)})`, 'Mira confirma');
  await must('Aldric', `return BG.Crafts.Note({ what = ${lua(link(17068, 'Deathbringer', 'Deathbringer'))}, to = ${lua(N.Brom)}, why = ${lua(L('Main tank first', 'Primero el tanque principal'))}, raid = ${lua(T.ony)} })`, 'botín 1');
  await must('Aldric', `return BG.Crafts.Note({ what = ${lua(link(17075, "Vis'kag the Bloodletter", "Vis'kag the Bloodletter"))}, to = ${lua(N.Finn)}, why = ${lua(L('Most raids attended', 'El que más raids lleva'))}, raid = ${lua(T.ony)} })`, 'botín 2');
  await must('Aldric', `return BG.Crafts.SetPoints(${lua(N.Finn)}, "40")`, 'puntos');
  await net.advance(4, 0.5);
  // Treasury: this week's dues and the guild bank
  for (const [who, amount] of [['Mira', 200000], ['Tessa', 200000], ['Seren', 200000]]) await must('Seren', `return BG.Treasury.Record("IN", ${amount}, ${lua(N[who])}, "TRADE", "")`, `cuota ${who}`);
  await C.Brom.run(`SIM.gbank = { gold = 18450000, tabs = { { name = ${lua(L('Consumables', 'Consumibles'))}, slots = { [1] = { 13457, 20 }, [2] = { 13446, 15 }, [3] = { 13510, 4 }, [8] = { 13452, 10 } } }, { name = ${lua(L('Materials', 'Materiales'))}, slots = { [1] = { 12360, 6 }, [2] = { 14047, 60 }, [3] = { 7078, 12 } } } } }
    SIM.fire("GUILDBANKFRAME_OPENED") SIM.advance(3)`);
  await net.advance(4, 0.5);
  // Lottery: today's tickets
  for (const [who, n] of [['Kael', 7], ['Finn', 13], ['Mira', 42], ['Tessa', 77], ['Lyra', 21]]) await must(who, `return BG.Lotto.Take(${n})`, `boleto ${who}`);
  // War room: squads and an operation for tonight
  await must('Brom', `local r = assert(BG.War.SaveSquad(nil, { name = ${lua(L('Iron Wall', 'Muro de Hierro'))}, spec = "DEFENSE", leader = ${lua(N.Brom)} })) SQ1 = r.id return r`, 'escuadra 1');
  await must('Brom', `local r = assert(BG.War.SaveSquad(nil, { name = ${lua(L('Night Hawks', 'Halcones Nocturnos'))}, spec = "SCOUT", leader = ${lua(N.Finn)} })) SQ2 = r.id return r`, 'escuadra 2');
  await net.advance(4, 0.5);
  const sq1 = await value('Brom', 'return SQ1');
  const sq2 = await value('Brom', 'return SQ2');
  for (const who of ['Aldric', 'Mira']) await must('Brom', `return BG.War.AddToSquad(${lua(sq1)}, ${lua(N[who])})`, `escuadra ${who}`);
  for (const who of ['Tessa', 'Kael']) await must('Finn', `return BG.War.AddToSquad(${lua(sq2)}, ${lua(N[who])})`, `escuadra ${who}`).catch(() => must('Brom', `return BG.War.AddToSquad(${lua(sq2)}, ${lua(N[who])})`, `escuadra ${who}`));
  await net.advance(4, 0.5);
  await must('Brom', `local r = assert(BG.War.SaveOp(nil, { title = ${lua(L('Defend Southshore', 'Defender Costasur'))}, kind = "DEFENSE", start = ${at(0, 23)}, place = ${lua(L('Hillsbrad Foothills', 'Laderas de Trabalomas'))}, squads = { ${lua(sq1)}, ${lua(sq2)} } })) OP1 = r.id return r`, 'operación');
  await net.advance(4, 0.5);
  const op1 = await value('Brom', 'return OP1');
  ctx.sched.push(['ops', op1, 0, 23]);
  for (const [who, a] of [['Aldric', 'GO'], ['Brom', 'GO'], ['Finn', 'GO'], ['Tessa', 'GO'], ['Kael', 'MAYBE'], ['Mira', 'GO'], ['Seren', 'NO']]) await must(who, `return BG.War.Answer(${lua(op1)}, ${lua(a)})`, `respuesta ${who}`);
  await must('Brom', `local r = assert(BG.War.SaveOp(nil, { title = ${lua(L('Raid on Tarren Mill', 'Asalto a Molino Tarren'))}, kind = "PVP", start = ${at(2, 22)}, place = ${lua(L('Tarren Mill', 'Molino Tarren'))}, ally = true })) OPALLY = r.id return r`, 'operación de alianza');
  ctx.sched.push(['ops', await value('Brom', 'return OPALLY'), 2, 22]);
  await net.advance(10, 0.5);
  // The alliance: letters, open doors, the alliance chat
  await must('Aldric', `return BG.AllianceActs.Letter(${lua(L('Joint raid on Sunday', 'Raid conjunta el domingo'))}, ${lua(L('Lances and Oaks: Onyxia together on Sunday at 20:00. Bring your best healers.', 'Lanzas y Robles: Onyxia juntos el domingo a las 20:00. Traed a vuestros mejores sanadores.'))})`, 'carta');
  await net.advance(20, 0.5);
  for (const [who, text] of [['Aldric', L('Welcome to the Pact, Silver Lances and Order of the Oak!', '¡Bienvenidos al Pacto, Lanzas de Plata y Orden del Roble!')], ['Corwin', L('Proud to stand with you. Lances ready.', 'Orgullosos de estar con vosotros. Lanzas listas.')], ['Hilda', L('The Oak will heal you all.', 'El Roble os sanará a todos.')]]) await must(who, `return BG.Chat.Send("ally", ${lua(text)})`, `alianza ${who}`);
  await net.advance(20, 0.5);
  // A war report of a past operation, and a fight night with two bouts announced
  await must('Brom', `local r = assert(BG.War.SaveOp(nil, { title = ${lua(L('Hold the Crossroads', 'Aguantar el Cruce'))}, kind = "PVP", start = BG.Store.Now() - 600, place = ${lua(L('The Barrens', 'Los Baldíos'))}, squads = { ${lua(sq1)} } })) OP2 = r.id return r`, 'operación pasada');
  await net.advance(4, 0.5);
  const op2 = await value('Brom', 'return OP2');
  for (const who of ['Aldric', 'Brom', 'Mira', 'Finn']) await must(who, `return BG.War.Answer(${lua(op2)}, "GO")`, `respuesta 2 ${who}`);
  await must('Brom', `return BG.War.Start(${lua(op2)})`, 'empieza');
  await net.advance(4, 0.5);
  await must('Brom', `return BG.War.Finish(${lua(op2)}, "WIN", ${lua(L('We held the bridge for an hour.', 'Aguantamos el puente una hora.'))})`, 'parte');
  await net.advance(4, 0.5);
  await must('Aldric', `local r = assert(BG.Tourney.Create({ kind = "NIGHT", title = ${lua(L('Stormwind Fight Night', 'Velada de Ventormenta'))} })) NIGHT = r.id return r`, 'velada');
  await net.advance(4, 0.5);
  const night = await value('Aldric', 'return NIGHT');
  await must('Aldric', `assert(BG.Tourney.AddBout(${lua(night)}, ${lua(N.Finn)}, ${lua(N.Brom)})) return BG.Tourney.AddBout(${lua(night)}, ${lua(N.Tessa)}, ${lua(N.Kael)})`, 'combates');
  await net.advance(6, 0.5);
  await closeDialogs();
  void lang;
}

async function snapshot(ctx) {
  const { C, net, lang, sched } = ctx;
  await net.advance(120, 1); // (everyone says hello again)
  const problems = await get(C.Aldric, 'local e = BG.db.errors or {} local out = {} for _, x in ipairs(e) do out[#out + 1] = x.where .. ": " .. x.error end return table.concat(out, "\\n")');
  if (problems) console.warn(`${lang}: errores internos del simulador:\n${problems}`);
  return get(C.Aldric, `
    local function ser(v)
      local t = type(v)
      if t == "string" then return (string.format("%q", v):gsub("\\\\\\n", "\\\\n")) end
      if t == "number" then
        if v == math.floor(v) and math.abs(v) < 2^53 then return string.format("%d", v) end
        return string.format("%.14g", v)
      end
      if t == "boolean" then return tostring(v) end
      if t ~= "table" then return "nil" end
      local keys = {}
      for k in pairs(v) do keys[#keys + 1] = k end
      table.sort(keys, function(a, b)
        if type(a) == type(b) then return a < b end
        return type(a) == "number"
      end)
      local n = #v
      local parts = {}
      for i = 1, n do parts[#parts + 1] = ser(v[i]) end
      for _, k in ipairs(keys) do
        if not (type(k) == "number" and k >= 1 and k <= n and k == math.floor(k)) then
          local key = type(k) == "string" and k:match("^[%a_][%w_]*$") and k or ("[" .. ser(k) .. "]")
          parts[#parts + 1] = key .. "=" .. ser(v[k])
        end
      end
      return "{" .. table.concat(parts, ",") .. "}"
    end
    local db = {}
    for k, v in pairs(BG.db) do
      if k ~= "settings" and k ~= "errors" and k ~= "characters" then db[k] = v end
    end
    local peers = {}
    for name in pairs(BG.Peers.list) do peers[#peers + 1] = name end
    table.sort(peers)
    local mates = { ${['Seren', 'Kael', 'Mira', 'Brom', 'Lyra'].map((w, i) => `{ name = ${lua(N[w])}, dx = ${[0.012, -0.018, 0.02, -0.006, 0.026][i]}, dy = ${[-0.01, 0.014, 0.016, -0.022, -0.004][i]} }`).join(', ')} }
    local sched = { ${sched.map(([c, id, days, hour]) => `{ c = ${lua(c)}, id = ${lua(id)}, days = ${days}, hour = ${hour} }`).join(', ')} }
    return ser({ now = BG.Store.Now(), me = BG.Names.Me(), info = BG.Guild.info, members = BG.Guild.members, peers = peers, mates = mates, sched = sched, db = db })`);
}
const get = async (c, expr) => {
  await c.run(`__out = (function() ${expr} end)()`);
  return c.lua.global.get('__out');
};

const parts = [];
for (const lang of ['en', 'es']) {
  const ctx = await build(lang);
  await today(ctx);
  const s = await snapshot(ctx);
  // (for the audit: every message the simulated guild sent, to fuzz the handlers with real shapes)
  if (process.env.DUMP_WIRE) fs.writeFileSync(`${process.env.DUMP_WIRE}.${lang}.json`, JSON.stringify(ctx.net.wire.map((f) => ({ msg: f.msg, dist: f.dist, from: f.from }))));
  ctx.net.close();
  parts.push(`BG.DemoData.${lang} = function()\n  return ${s}\nend\n`);
  console.log(`${lang}: ${(s.length / 1024).toFixed(1)} KB`);
}
fs.writeFileSync(OUT, `-- Generated by tools/demo-build.mjs: the example guild of the capture mode (/bg capturas, Core/Demo.lua). Every name
-- is invented. Do not edit by hand; change the script and run it again.
local _, BG = ...
BG.DemoData = BG.DemoData or {}
${parts.join('')}`);
console.log(`escrito ${path.relative(process.cwd(), OUT)}`);
