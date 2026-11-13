// Modo capturas (/bg capturas, Peregrino 2026-11-13: «me gustaría capturas reales del addon»): an example guild of
// invented players on this screen alone, every screen full, and the real guild back as it was. Nothing goes out,
// nothing comes in, and nothing is done in the game (invites, whispers, the guild chat, a /roll others see).
import { createClient, checklist } from './harness.mjs';

const t = checklist('comprobaciones del modo capturas');
const sent = [];
const c = await createClient({ identity: { first: 'El', second: 'Peregrino', guid: 'Player-6842-0A1B2C3D', rosterIndex: 2 }, onSend: (m) => sent.push(m) });
await c.login();
await c.run('BG.Consent.Accept() SIM.advance(5)');
const get = async (expr) => {
  await c.run(`__out = (function() ${expr} end)()`);
  return c.lua.global.get('__out');
};
// Real data of the real guild before the mode: a raid and a profile.
await c.run('SIM.roster[1][4] = 60 assert(BG.People.Publish({ bio = "Mi perfil de verdad" })) SIM.advance(2)');
const realBefore = await get('return BG.Guild.info.name .. "|" .. #BG.Guild.members .. "|" .. BG.Names.Me() .. "|" .. #BG.Store.List("profiles")');
// Every text on screen inside the window (what a picture would show).
const screenText = `
  local out = {}
  local function inside(f)
    local p = f
    while p do
      if p == BG.window then return true end
      p = p.__parent
    end
    return false
  end
  for _, f in ipairs(SIM.objects) do
    local ok, txt = pcall(function() return f:IsVisible() and f.GetText and f:GetText() end)
    if ok and type(txt) == "string" and txt ~= "" and inside(f) then out[#out + 1] = txt end
  end
  return table.concat(out, "\\n")`;
const REAL = ['El Peregrino', 'C A Ñ A D A', 'Miembro Prueba', 'Mi perfil de verdad'];

await t.check('/bg capturas: la hermandad de ejemplo, con su maestro inventado, y nada de la real', async () => {
  sent.length = 0;
  await c.run('SlashCmdList.BLAZONGUILD("capturas") SIM.advance(1)');
  const r = await get('return tostring(BG.Demo.Active()) .. "|" .. BG.Guild.info.name .. "|" .. #BG.Guild.members .. "|" .. tostring(BG.Names.Me()) .. "|" .. tostring(BG.Store.IsMaster(BG.Names.Me()))');
  const leak = await get('local out = {} for _, m in ipairs(BG.Guild.members) do if m.name:find("Prueba") or m.name == "El Peregrino" then out[#out + 1] = m.name end end return table.concat(out, ",")');
  return (r === 'true|Heraldos del Alba|36|Aldric Valemont|true' && !leak) || `${r}; reales: ${leak}`;
});

await t.check('cada pantalla se abre sin errores, con todo dentro y sin un nombre de verdad', async () => {
  await c.run('BG.db.errors = nil if not (BG.window and BG.window:IsShown()) then BG:ToggleWindow() end SIM.layout(834, 604)');
  await c.run('__out = {} for i, n in ipairs(BG.nav) do __out[i] = n.key end');
  const keys = Object.values(c.lua.global.get('__out'));
  const bad = [];
  for (const key of keys) {
    await c.run(`BG:ShowView("${key}") SIM.layout(834, 604) SIM.advance(0.5)`);
    const lay = await get(`return table.concat(SIM.CheckLayout(BG.window.viewFrames["${key}"] or BG.window), " ; ")`);
    if (lay) bad.push(`${key} se sale: ${lay}`);
    const text = await get(screenText);
    for (const r of REAL) if (text.includes(r)) bad.push(`${key} enseña «${r}»`);
    if (key === 'roster' && !(text.includes('Aldric Valemont') && text.includes('Seren Duskwhisper'))) bad.push(`roster sin la hermandad de ejemplo: ${text.slice(0, 120)}`);
  }
  const errors = await get('local out = {} for _, e in ipairs(BG.db.errors or {}) do out[#out + 1] = e.where .. ": " .. e.error end return table.concat(out, " | ")');
  if (errors) bad.push(`errores: ${errors}`);
  return bad.length === 0 || bad.join(' | ');
});

// Every tab of every screen (the tabs are UI.Segmented: each of their buttons, one after the other), in both languages.
const everyTab = async (lang) => {
  // a client of its own in that language from the start (the language changes with a /reload in the game)
  const k = await createClient({ identity: { first: 'El', second: 'Peregrino', guid: 'Player-6842-0A1B2C3D', rosterIndex: 2 } });
  await k.run(`BlazonGuildDB = { settings = { lang = ${JSON.stringify(lang)} } }`);
  await k.login();
  const kget = async (expr) => {
    await k.run(`__out = (function() ${expr} end)()`);
    return k.lua.global.get('__out');
  };
  await k.run('BG.Consent.Accept() SIM.advance(5) BG.Demo.Start() SIM.advance(1) BG.db.errors = nil BG:ToggleWindow() SIM.layout(834, 604)');
  await k.run('__out = {} for i, n in ipairs(BG.nav) do __out[i] = n.key end');
  const keys = Object.values(k.lua.global.get('__out'));
  const bad = [];
  let tabs = 0;
  for (const key of keys) {
    await k.run(`BG:ShowView("${key}") SIM.layout(834, 604) SIM.advance(0.5)`);
    const segs = await kget(`
      local vf = BG.window.viewFrames["${key}"] SEGS = {}
      local function inside(f) local p = f while p do if p == vf then return true end p = p.__parent end return false end
      for _, f in ipairs(SIM.frames) do if f.buttons and f.SetValue and inside(f) and f:IsVisible() then SEGS[#SEGS + 1] = f end end
      return #SEGS`);
    for (let s = 1; s <= segs; s++) {
      const n = await kget(`return SEGS[${s}] and #SEGS[${s}].buttons or 0`);
      for (let b = 1; b <= n; b++) {
        const label = await kget(`local x = SEGS[${s}].buttons[${b}] if not (x:IsVisible() and x:IsEnabled()) then return "" end x:Click() SIM.layout(834, 604) SIM.advance(0.3) SIM.layout(834, 604) return x.text:GetText() or "?"`);
        if (!label) continue;
        tabs++;
        const lay = await kget(`return table.concat(SIM.CheckLayout(BG.window.viewFrames["${key}"] or BG.window), " ; ")`);
        if (lay) bad.push(`${key} › ${label} se sale: ${lay.slice(0, 220)}`);
        await k.run(`__out = (function() ${screenText} end)()`);
        const text = k.lua.global.get('__out');
        for (const r of REAL) if (text.includes(r)) bad.push(`${key} › ${label} enseña «${r}»`);
      }
    }
  }
  const errors = await kget('local out = {} for _, e in ipairs(BG.db.errors or {}) do out[#out + 1] = e.where .. ": " .. e.error end return table.concat(out, " | ")');
  if (errors) bad.push(`errores: ${errors}`);
  k.close();
  return bad.length === 0 ? (tabs > 20 || `solo ${tabs} pestañas`) : bad.join(' | ');
};
await t.check('cada pestaña de cada pantalla, en español: todo dentro, sin errores ni nombres de verdad', () => everyTab('es'));
await t.check('y en inglés', () => everyTab('en'));

await t.check('no sale nada, no entra nada, y no se hace nada en el juego', async () => {
  await c.run(`
    SIM.invites = {} SIM.chat = {} SIM.rollsAsked = {}
    BG.Comm.OnMessage("BlazonGuild", "x", "GUILD", "Tarek Vientoalto")
    BG.Chat.Send("guild", "hola")
    BG.People.SendWhisper("Seren Duskwhisper", "hola")
    BG.Raids.InviteConfirmed("nada")
    BG.Bones.Practice() BG.Bones.Roll() SIM.advance(2)`);
  const r = await get('return #SIM.invites .. "|" .. #SIM.chat .. "|" .. #SIM.rollsAsked .. "|" .. tostring(BG.Bones.game and BG.Bones.game.phase)');
  return (sent.length === 0 && r.startsWith('0|0|0|') && !r.endsWith('roll')) || `enviados ${sent.length}; invitaciones|chat|tiradas|fase ${r}`;
});

await t.check('las fechas son de ahora: los duelos pasaron hace poco y las raids están por venir', async () => {
  const r = await get(`
    local now = BG.Store.Now()
    local newest = 0
    for _, d in ipairs(BG.Store.List("duels")) do newest = math.max(newest, d.at) end
    local soon, later = 0, 0
    for _, r in ipairs(BG.Store.List("raids")) do
      if r.d.start > now and r.d.start < now + 5 * 86400 then soon = soon + 1 else later = later + 1 end
    end
    local hours = {}
    for _, r in ipairs(BG.Store.List("raids")) do hours[#hours + 1] = date("*t", r.d.start).hour .. ":" .. date("*t", r.d.start).min end
    for _, o in ipairs(BG.Store.List("ops")) do if o.d.start > now then hours[#hours + 1] = date("*t", o.d.start).hour .. ":" .. date("*t", o.d.start).min end end
    table.sort(hours)
    return tostring(newest <= now and newest > now - 2 * 86400) .. "|" .. soon .. "|" .. later .. "|" .. table.concat(hours, ",")`);
  return r === 'true|3|0|20:0,21:0,21:0,22:0,23:0' || `duelo reciente|raids próximas|otras|horas: ${r}`;
});

await t.check('/bg capturas otra vez: la hermandad real vuelve tal cual, y sus datos guardados no se tocaron', async () => {
  await c.run('SlashCmdList.BLAZONGUILD("capturas") SIM.advance(1)');
  const after = await get('return BG.Guild.info.name .. "|" .. #BG.Guild.members .. "|" .. BG.Names.Me() .. "|" .. #BG.Store.List("profiles")');
  const saved = await get('local out = {} for k in pairs(BlazonGuildDB.guilds) do if k:find("Heraldos") or k:find("Heralds") then out[#out + 1] = k end end return table.concat(out, ",") .. "|" .. tostring(BG.db == BlazonGuildDB)');
  const chron = await get('local out = {} for _, e in ipairs(BG.Board.Chronicle()) do if e.text:find("Valemont") or e.text:find("Duskwhisper") or e.text:find("deja la hermandad") then out[#out + 1] = e.text end end return table.concat(out, " | ")');
  return (after === realBefore && saved === '|true' && !chron) || `antes ${realBefore}; después ${after}; guardado ${saved}; crónica real: ${chron.slice(0, 160)}`;
});

await t.check('en inglés, la hermandad de ejemplo está en inglés', async () => {
  await c.run('BG.db.settings.lang = "en" BG.Locale.Init() SlashCmdList.BLAZONGUILD("capturas") SIM.advance(1)');
  const r = await get('return BG.Guild.info.name .. "|" .. BG.Guild.members[1].className');
  await c.run('SlashCmdList.BLAZONGUILD("capturas") BG.db.settings.lang = nil BG.Locale.Init()');
  return r === 'Heralds of Dawn|Paladin' || r;
});

t.report();
c.close();
