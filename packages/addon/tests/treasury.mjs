// Tesorería (entrega 9) with four members: the master names a treasurer and sets the weekly dues; gold given to
// the treasurer by trade or by mail is written down by itself (an unfinished trade, a non-treasurer's trade or
// the auction house's mail is not); gold the treasurer sends is a payment; the balance; what members see; dues
// and exemptions (organisers); lines by hand and a campaign; the guild bank's snapshot; the copy as text; the
// screen with its four tabs.
import { createNetwork, checklist } from './harness.mjs';

const P = {
  tarek: { first: 'Tarek', second: 'Vientoalto', guid: 'Player-6842-SIMA', rosterIndex: 1 }, // Maestro
  bruno: { first: 'Bruno', second: 'Hierrosol', guid: 'Player-6842-SIMD', rosterIndex: 3 }, // Oficial
  peregrino: { first: 'El', second: 'Peregrino', guid: 'Player-6842-0A1B2C3D', rosterIndex: 2 }, // Miembro
  rina: { first: 'Rina', second: 'Dagaluna', guid: 'Player-6842-SIMB', rosterIndex: 5 }, // Miembro, tesorera
};
const net = await createNetwork([P.tarek, P.bruno, P.peregrino, P.rina]);
const [tarek, bruno, peregrino, rina] = net.clients;
await net.loginAll();
for (const c of net.clients) await c.run('BG.Consent.Accept()');
await net.advance(20, 0.5);
const get = net.get;
const t = checklist('comprobaciones de la tesorería');
const notice = (c) => get(c, 'return BG.lastNotice and (BG.lastNotice.title .. "|" .. (BG.lastNotice.text or "")) or ""');
const lines = (c) => get(c, 'local o = {} for _, r in ipairs(BG.Treasury.Lines()) do o[#o+1] = r.d.k .. ":" .. r.d.c .. ":" .. r.d.who .. ":" .. r.d.via end table.sort(o) return table.concat(o, " / ")');

await t.check('el maestro nombra tesorera y pone la cuota; nadie más puede', async () => {
  const denied = await get(bruno, 'local r, why = BG.Treasury.Configure({ dues = 50000 }) return tostring(why)');
  if (denied !== 'permiso') return `un oficial cambió la cuota: ${denied}`;
  const bad = await get(tarek, 'local r, why, who = BG.Treasury.Configure({ keepers = "Nadie Existe" }) return tostring(why) .. "|" .. tostring(who)');
  if (bad !== 'no es de tu hermandad|Nadie Existe') return `nombre que no existe: ${bad}`;
  await tarek.run('assert(BG.Treasury.Configure({ keepers = "Rina Dagaluna", dues = 50000 }))');
  await net.advance(4);
  const seen = await get(peregrino, 'local s = BG.Treasury.Settings() return table.concat(s.keepers, ",") .. "|" .. s.dues .. "|" .. tostring(BG.Treasury.IsKeeper("Rina Dagaluna"))');
  return seen === 'Rina Dagaluna|50000|true' || seen;
});

await t.check('un comercio con la tesorera se apunta solo, y al donante le llega un «gracias»', async () => {
  await rina.run(`SIM.trade2 = { npc = "El Peregrino", got = 30000, gave = 0 }
    SIM.fire("TRADE_SHOW") SIM.fire("TRADE_MONEY_CHANGED") SIM.fire("UI_INFO_MESSAGE", 0, ERR_TRADE_COMPLETE)`);
  // A trade that did not complete, and a trade of someone who is not a treasurer: nothing.
  await rina.run(`SIM.trade2 = { npc = "Bruno Hierrosol", got = 90000, gave = 0 } SIM.fire("TRADE_SHOW") SIM.fire("TRADE_MONEY_CHANGED") SIM.fire("TRADE_CLOSED") SIM.advance(2)`);
  await bruno.run(`SIM.trade2 = { npc = "El Peregrino", got = 20000, gave = 0 } SIM.fire("TRADE_SHOW") SIM.fire("TRADE_MONEY_CHANGED") SIM.fire("UI_INFO_MESSAGE", 0, ERR_TRADE_COMPLETE)`);
  await net.advance(4);
  const l = await lines(peregrino);
  if (l !== 'IN:30000:El Peregrino:TRADE') return `libro: ${l}`;
  const thanks = await notice(peregrino);
  return thanks.startsWith('Gracias por tu donación') || `aviso: ${thanks}`;
});

await t.check('el correo: el oro de una carta se apunta al cogerlo; el de la casa de subastas, no; lo que envía, como salida', async () => {
  await rina.run(`SIM.inbox = { { sender = "Tarek Vientoalto", subject = "Para la banda", money = 20000 }, { sender = "Casa de subastas", subject = "Vendido", money = 99999, canReply = false } }
    SIM.fire("MAIL_INBOX_UPDATE")
    TakeInboxMoney(1) AutoLootMailItem(2)
    SIM.sendMoney = 10000 SendMail("Bruno Hierrosol", "Reparaciones", "") SIM.fire("MAIL_SEND_SUCCESS")`);
  await net.advance(4);
  const l = await lines(bruno);
  return l === 'IN:20000:Tarek Vientoalto:MAIL / IN:30000:El Peregrino:TRADE / OUT:10000:Bruno Hierrosol:MAIL' || `libro: ${l}`;
});

await t.check('saldo y lo que ve cada uno: el maestro decide el ranking y el libro', async () => {
  const tot = await get(peregrino, 'local t = BG.Treasury.Totals() return t.bal .. "|" .. t.inWeek .. "|" .. t.donorsWeek');
  if (tot !== '40000|50000|2') return `totales: ${tot}`;
  const member = await get(peregrino, 'return tostring(BG.Treasury.Sees("bal")) .. tostring(BG.Treasury.Sees("rank")) .. tostring(BG.Treasury.Sees("book"))');
  if (member !== 'truefalsefalse') return `lo que ve un miembro: ${member}`;
  const officer = await get(bruno, 'return tostring(BG.Treasury.Sees("rank")) .. tostring(BG.Treasury.Sees("book"))');
  if (officer !== 'truetrue') return `lo que ve un oficial: ${officer}`;
  await tarek.run('assert(BG.Treasury.Configure({ show = { rank = true } }))');
  await net.advance(4);
  const after = await get(peregrino, 'local r = BG.Treasury.Ranking() return tostring(BG.Treasury.Sees("rank")) .. "|" .. r[1].name .. ":" .. r[1].c');
  return after === 'true|El Peregrino:30000' || `con el ranking abierto: ${after}`;
});

await t.check('cuotas: los oficiales ven quién debe; exento solo lo marcan ellos', async () => {
  const list = await get(bruno, 'for _, m in ipairs(BG.Treasury.Dues()) do if m.name == "El Peregrino" then return m.given .. "|" .. m.owed end end return "no está"');
  if (list !== '30000|20000') return `cuota de Peregrino: ${list}`;
  const denied = await get(peregrino, 'local r, why = BG.Treasury.SetExempt("El Peregrino", true) return tostring(why)');
  if (denied !== 'permiso') return `un miembro se marcó exento: ${denied}`;
  await bruno.run('assert(BG.Treasury.SetExempt("El Peregrino", true))');
  await net.advance(4);
  const exempt = await get(peregrino, 'return tostring(BG.Treasury.Exempt("El Peregrino"))');
  return exempt === 'true' || `exento: ${exempt}`;
});

await t.check('a mano y campaña: la tesorera apunta y asigna; un miembro no puede', async () => {
  const denied = await get(peregrino, 'local r, why = BG.Treasury.Record("IN", 10000, "Yo", "HAND") return tostring(why)');
  if (denied !== 'permiso') return `un miembro apuntó: ${denied}`;
  await bruno.run('assert(BG.Treasury.NewCampaign("Pociones para Núcleo de Magma", 200000, 14))');
  await net.advance(4);
  const camp = await get(rina, 'return BG.Treasury.Campaigns()[1].id');
  await rina.run(`local r = assert(BG.Treasury.Record("IN", 100000, "Bruno Hierrosol", "HAND", "pociones")) assert(BG.Treasury.EditLine(r.id, { camp = ${JSON.stringify(camp)} }))`);
  await net.advance(6);
  const c = await get(peregrino, 'local c = BG.Treasury.Campaigns()[1] return c.d.title .. "|" .. c.raised .. "/" .. c.d.goal');
  return c === 'Pociones para Núcleo de Magma|100000/200000' || `campaña: ${c}`;
});

await t.check('banco: un oficial lo abre y la hermandad ve la foto', async () => {
  await bruno.run(`SIM.gbank = { gold = 1234567, tabs = { { name = "Consumibles", slots = { [1] = { 7946, 2 }, [5] = { 7946, 3 }, [9] = { 3853, 1 } } } } }
    SIM.fire("GUILDBANKFRAME_OPENED") SIM.advance(3)`);
  await net.advance(4);
  const b = await get(peregrino, 'local b = BG.Treasury.Bank() if not b then return "sin foto" end local t = b.d.tabs[1] return b.d.gold .. "|" .. t.n .. "|" .. t.it[1][1] .. "x" .. t.it[1][2] .. "|" .. #t.it .. "|" .. b.by');
  return b === '1234567|Consumibles|7946x5|2|Bruno Hierrosol' || `banco: ${b}`;
});

await t.check('copia de seguridad: el libro en texto, una línea por apunte', async () => {
  const text = await get(bruno, 'return BG.Treasury.Export()');
  const rows = text.split('\n');
  return (rows.length === 5 && rows[1].includes(';entrada;30000;El Peregrino;comercio;')) || text;
});

await t.check('pantalla: cuatro pestañas, formularios, y nada se sale ni se monta', async () => {
  const e = await get(peregrino, `
    BG:ToggleWindow() SIM.layout(834, 604) BG:ShowView("treasury") SIM.layout(834, 604)
    local f = BG.window.viewFrames.treasury
    if not (f.guide and f.guide:IsShown()) then return "sin guía la primera vez" end
    f.guide.ok:Click()
    if not f.mine:GetText():find("exento", 1, true) then return "su cuota: " .. f.mine:GetText() end
    local out = SIM.CheckLayout(f) if #out > 0 then return "resumen: " .. out[1] end
    f.tabs.buttons[2]:Click()
    if #f.lines.items ~= 0 then return "un miembro ve el libro" end
    out = SIM.CheckLayout(f) if #out > 0 then return "libro: " .. out[1] end
    f.tabs.buttons[3]:Click()
    out = SIM.CheckLayout(f) if #out > 0 then return "cuotas: " .. out[1] end
    f.tabs.buttons[4]:Click()
    if not f.bankText:GetText():find("Consumibles", 1, true) then return "banco: " .. f.bankText:GetText() end
    out = SIM.CheckLayout(f) if #out > 0 then return "banco: " .. out[1] end
    return true`);
  if (e !== true) return e;
  return get(tarek, `
    BG:ToggleWindow() SIM.layout(834, 604) BG:ShowView("treasury") SIM.layout(834, 604)
    local f = BG.window.viewFrames.treasury
    if f.guide then f.guide:Hide() end
    f.tabs.buttons[2]:Click()
    if #f.lines.items ~= 4 then return "el maestro ve " .. #f.lines.items .. " líneas" end -- (comercio, correo, salida y a mano)
    local out = SIM.CheckLayout(f) if #out > 0 then return "libro (maestro): " .. out[1] end
    f.tabs.buttons[3]:Click()
    if not f.saveCfg:IsShown() then return "el maestro no ve sus ajustes" end
    if #f.dues.items < 4 then return "cuotas: " .. #f.dues.items end
    out = SIM.CheckLayout(f) if #out > 0 then return "cuotas (maestro): " .. out[1] end
    f.exportForm:Open()
    out = SIM.CheckLayout(f) if #out > 0 then return "copia: " .. out[1] end
    f.exportForm.back:Click()
    f.campForm:Open()
    out = SIM.CheckLayout(f) if #out > 0 then return "campaña: " .. out[1] end
    f.campForm.back:Click()
    -- A huge balance (what Peregrino saw with «0 de cobre»): the figure gets a smaller letter and stays in its plate.
    f.tabs.buttons[1]:Click() SIM.layout(834, 604)
    f.plates[1]:Set(BG.Treasury.MoneyShort(1234567891), "Saldo", "según el libro")
    f.plates[2]:Set(BG.Treasury.Money(1234567891), "Esta semana", "entró")
    out = SIM.CheckLayout(f) if #out > 0 then return "resumen con mucho oro: " .. out[1] end
    local _, size = f.plates[2].value:GetFont()
    if size >= 26 then return "la cifra no se ha hecho más pequeña: " .. f.plates[2].value:GetText() end
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
