// Artesanía y botín (entrega 8) with four members: reading a profession when its window opens and asking once,
// publishing it to the crafters' board, "who can make this?", the game's whisper, orders (anyone who can make it
// takes it; only the crafter says it is done; only who asked confirms) and the crafters' ranking, loot notes and
// points (organisers only), and the screen with its three tabs.
import { createNetwork, checklist } from './harness.mjs';

const P = {
  tarek: { first: 'Tarek', second: 'Vientoalto', guid: 'Player-6842-SIMA', rosterIndex: 1 }, // Maestro
  bruno: { first: 'Bruno', second: 'Hierrosol', guid: 'Player-6842-SIMD', rosterIndex: 3 }, // Oficial
  peregrino: { first: 'El', second: 'Peregrino', guid: 'Player-6842-0A1B2C3D', rosterIndex: 2 }, // Miembro
  rina: { first: 'Rina', second: 'Dagaluna', guid: 'Player-6842-SIMB', rosterIndex: 5 }, // Miembro, herrera
};
const net = await createNetwork([P.tarek, P.bruno, P.peregrino, P.rina]);
const [tarek, bruno, peregrino, rina] = net.clients;
await net.loginAll();
for (const c of net.clients) await c.run('BG.Consent.Accept()');
await net.advance(20, 0.5);
const get = net.get;
const t = checklist('comprobaciones de artesanía y botín');
const notice = (c) => get(c, 'return BG.lastNotice and (BG.lastNotice.title .. "|" .. (BG.lastNotice.text or "")) or ""');

await t.check('al abrir su profesión, el addon la lee y pregunta una vez si publicarla', async () => {
  const r = await get(rina, `
    SIM.trade = { name = "Herrería", rank = 150, max = 300, recipes = { { "Armas", "header" }, { "Hoja de acero de Runas", "optimal", 7946 }, { "Martillo de bronce", "medium", 3853 }, { "Piedra de afilar tosca", "trivial", 2862 } } }
    SIM.fire("TRADE_SKILL_SHOW") SIM.advance(1)
    local p = BG.Crafts.MyProfessions()[1]
    if not p then return "no la leyó" end
    if not BG.UI.DialogShown() then return "no preguntó" end
    if BG.Store.Get("crafters", "Rina Dagaluna|Herrería") then return "la publicó sin preguntar" end
    return p.p .. "|" .. p.r .. "/" .. p.m .. "|" .. #p.it`);
  return r === 'Herrería|150/300|3' || r;
});

await t.check('publicada, la hermandad la ve, busca «¿quién sabe hacer…?» y susurra con un clic', async () => {
  await rina.run('assert(BG.Crafts.SetShare("Herrería", true))');
  await net.advance(4);
  const board = await get(peregrino, 'local b = BG.Crafts.Board() return #b .. "|" .. (b[1] and (b[1].name .. "|" .. b[1].profs[1].p .. " " .. b[1].profs[1].r) or "")');
  if (board !== '1|Rina Dagaluna|Herrería 150') return `tablón: ${board}`;
  const found = await get(peregrino, 'local s = BG.Crafts.Search("acero") return #s .. "|" .. (s[1] and (s[1].name .. "|" .. table.concat(s[1].items, ",")) or "")');
  if (found !== '1|Rina Dagaluna|Hoja de acero de Runas') return `búsqueda: ${found}`;
  const none = await get(peregrino, 'return #BG.Crafts.Search("dragón")');
  if (none !== 0) return `búsqueda de algo que nadie hace: ${none}`;
  const tell = await get(peregrino, 'BG.Crafts.Whisper("Rina Dagaluna") return SIM.tells[#SIM.tells]');
  return tell === 'Rina Dagaluna' || `susurro: ${tell}`;
});

let order;
await t.check('encargos: quien sabe hacerlo lo toma, solo él dice «hecho» y solo quien pidió confirma', async () => {
  await peregrino.run('assert(BG.Crafts.Order({ what = "|cff1eff00|Hitem:7946::::::::|h[Hoja de acero de Runas]|h|r", qty = 2, note = "pongo yo el acero" }))');
  await net.advance(4);
  order = await get(rina, 'local o = BG.Crafts.Orders()[1] return o and o.id');
  const told = await notice(rina);
  if (!told.startsWith('Encargo que sabes hacer')) return `aviso a Rina: ${told}`;
  await rina.run(`assert(BG.Crafts.Take(${JSON.stringify(order)}))`);
  await net.advance(4);
  const taken = await notice(peregrino);
  if (!taken.startsWith('Encargo en marcha')) return `aviso a Peregrino: ${taken}`;
  const notHers = await get(bruno, `local r, why = BG.Crafts.Done(${JSON.stringify(order)}) return tostring(why)`);
  if (notHers !== 'permiso') return `otro lo dio por hecho: ${notHers}`;
  const notHis = await get(bruno, `local r, why = BG.Crafts.CancelOrder(${JSON.stringify(order)}) return tostring(why)`);
  if (notHis !== 'permiso') return `otro lo canceló: ${notHis}`;
  await rina.run(`assert(BG.Crafts.Done(${JSON.stringify(order)}))`);
  await net.advance(4);
  const done = await notice(peregrino);
  if (!done.startsWith('Encargo hecho')) return `aviso de hecho: ${done}`;
  const early = await get(rina, `local r, why = BG.Crafts.Confirm(${JSON.stringify(order)}) return tostring(why)`);
  if (early !== 'permiso') return `la artesana se lo confirmó a sí misma: ${early}`;
  await peregrino.run(`assert(BG.Crafts.Confirm(${JSON.stringify(order)}))`);
  await net.advance(4);
  const rank = await get(tarek, 'local r = BG.Crafts.Ranking() return r[1] and (r[1].name .. ":" .. r[1].n) or "nada"');
  return rank === 'Rina Dagaluna:2' || `ranking: ${rank}`;
});

await t.check('botín: solo los organizadores anotan y ponen puntos; todos lo leen y buscan', async () => {
  const denied = await get(peregrino, 'local r, why = BG.Crafts.Note({ what = "Algo", to = "El Peregrino" }) return tostring(why)');
  if (denied !== 'permiso') return `un miembro anotó: ${denied}`;
  await tarek.run('assert(BG.Crafts.Note({ what = "|cffa335ee|Hitem:19137::::::::|h[Cinturón de asesino nocturno]|h|r", to = "El Peregrino", why = "pasó de los guantes", raid = "Núcleo de Magma" }))');
  await tarek.run('assert(BG.Crafts.SetPoints("El Peregrino", "15"))');
  await net.advance(4);
  const notes = await get(rina, 'local n = BG.Crafts.Notes("peregr") return #n .. "|" .. (n[1] and (n[1].d.to .. "|" .. n[1].d.item .. "|" .. n[1].d.why) or "")');
  if (notes !== '1|El Peregrino|19137|pasó de los guantes') return `notas: ${notes}`;
  const pts = await get(rina, 'local p = BG.Crafts.Points()[1] return p and (p.id .. ":" .. p.d.p) or "nada"');
  if (pts !== 'El Peregrino:15') return `puntos: ${pts}`;
  const memberPts = await get(peregrino, 'local r, why = BG.Crafts.SetPoints("El Peregrino", "999") return tostring(why)');
  return memberPts === 'permiso' || `un miembro se puso puntos: ${memberPts}`;
});

await t.check('pantalla: tres pestañas, formularios, y nada se sale', async () => {
  const e = await get(peregrino, `
    BG:ToggleWindow() SIM.layout(834, 604) BG:ShowView("crafts") SIM.layout(834, 604)
    local f = BG.window.viewFrames.crafts
    if #f.board.items ~= 1 then return "artesanos: " .. #f.board.items end
    local out = SIM.CheckLayout(f) if #out > 0 then return "se sale (artesanos): " .. out[1] end
    f.tabs.buttons[2]:Click()
    if not f.pages.orders:IsShown() or #f.orders.items ~= 1 then return "encargos: " .. #f.orders.items end
    if not f.ranking:GetText():find("Rina Dagaluna: 2", 1, true) then return "ranking: " .. f.ranking:GetText() end
    out = SIM.CheckLayout(f) if #out > 0 then return "se sale (encargos): " .. out[1] end
    f.newOrder:Click()
    if not f.orderForm:IsShown() then return "no abre el formulario de encargo" end
    out = SIM.CheckLayout(f) if #out > 0 then return "se sale (formulario): " .. out[1] end
    f.orderForm.back:Click()
    f.tabs.buttons[3]:Click()
    if #f.notes.items ~= 1 then return "botín: " .. #f.notes.items end
    if f.newNote:IsShown() then return "un miembro ve Anotar" end
    out = SIM.CheckLayout(f) if #out > 0 then return "se sale (botín): " .. out[1] end
    return true`);
  if (e !== true) return e;
  return get(tarek, `
    BG:ToggleWindow() SIM.layout(834, 604) BG:ShowView("crafts") SIM.layout(834, 604)
    local f = BG.window.viewFrames.crafts
    f.tabs.buttons[3]:Click()
    if not f.newNote:IsShown() then return "el maestro no ve Anotar" end
    f.newNote:Click()
    local out = SIM.CheckLayout(f) if #out > 0 then return "se sale (anotar): " .. out[1] end
    return true`);
});

await t.check('un encargo con nota larga: el texto no queda bajo el botón y la tarjeta se despliega para leerlo entero', async () => {
  const long = 'Necesito la hoja para el sábado antes de la banda; pongo yo el acero, el carbón y las piedras de afilar, y te doy una propina';
  await peregrino.run(`assert(BG.Crafts.Order({ what = "Martillo de bronce", qty = 1, note = ${JSON.stringify(long)} }))`);
  await net.advance(4);
  return get(peregrino, `
    BG:ShowView("crafts") SIM.layout(834, 604)
    local f = BG.window.viewFrames.crafts
    if f.guide then f.guide:Hide() end
    f.tabs.buttons[2]:Click()
    local card
    for _, row in ipairs(f.orders.rows) do if row:IsShown() and row.subFull and row.subFull:find("propina", 1, true) then card = row end end
    if not card then return "no está la tarjeta del encargo" end
    local out = SIM.CheckLayout(f) if #out > 0 then return "plegada: " .. out[1] end
    local h = card:GetHeight()
    card:Click()
    if not card.unfolded or card:GetHeight() <= h then return "no se desplegó (alto " .. h .. " → " .. card:GetHeight() .. ")" end
    if not card.more:GetText():find("Nota: " .. ${JSON.stringify(long)}, 1, true) then return "desplegada no enseña la nota entera: " .. card.more:GetText() end
    out = SIM.CheckLayout(f) if #out > 0 then return "desplegada: " .. out[1] end
    -- the card below moved down to leave it room
    local below
    for _, row in ipairs(f.orders.rows) do if row:IsShown() and row ~= card then below = row end end
    if below and SIM.Rect(below).t < SIM.Rect(card).b then return "la siguiente tarjeta queda debajo de la desplegada" end
    card:Click()
    if card.unfolded or card:GetHeight() ~= h then return "no se recogió" end
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
