// Runs the addon's real Lua in a simulated client (tests/wow-stubs.lua) and checks behaviour end to end:
// login, roster scan, window, every section, sorting, search and the online filter.
import fs from 'node:fs';
import path from 'node:path';
import { LuaFactory } from 'wasmoon';

const here = path.dirname(new URL(import.meta.url).pathname.replace(/^\/(\w:)/, '$1'));
const root = path.join(here, '..', 'BlazonGuild');
const files = fs.readFileSync(path.join(root, 'BlazonGuild.toc'), 'utf8').split(/\r?\n/).filter((l) => l.trim() && !l.startsWith('#')).map((l) => l.trim().replace(/\\/g, '/'));

const lua = await new LuaFactory().createEngine();
lua.global.set('__read', (f) => fs.readFileSync(path.join(root, f), 'utf8'));
await lua.doString(fs.readFileSync(path.join(here, 'wow-stubs.lua'), 'utf8'));
await lua.doString(`
  BG = {}
  for _, f in ipairs({${files.map((f) => JSON.stringify(f)).join(',')}}) do
    local chunk, err = load(__read(f), "@" .. f)
    if not chunk then error(err) end
    chunk("BlazonGuild", BG)
  end
`);

const checks = [];
const check = async (name, code) => {
  try {
    const ok = await lua.doString(code);
    checks.push([ok === true, name, ok === true ? '' : String(ok)]);
  } catch (e) {
    checks.push([false, name, String(e.message ?? e).split('\n')[0]]);
  }
};

await check('carga y lee el roster al entrar', `
  SIM.fire("ADDON_LOADED", "BlazonGuild")
  BG.db.settings.debug = true
  SIM.fire("PLAYER_LOGIN")
  SIM.fire("GUILD_ROSTER_UPDATE")
  SIM.flushTimers()
  local g = BG.Guild
  if not g.info then return "sin info" end
  if g.info.name ~= "C A Ñ A D A" then return g.info.name end
  if g.stats.total ~= 36 then return "total " .. g.stats.total end
  if not g.me or g.me.name ~= "El Peregrino" then return "no me identifica por GUID" end
  return true`);
await check('estadísticas coherentes', `
  local s = BG.Guild.stats
  local bands = s.bands[1] + s.bands[2] + s.bands[3] + s.bands[4]
  if bands ~= s.total then return "tramos " .. bands end
  if s.online ~= 2 then return "conectados " .. s.online end
  local expected = 0 for _, r in ipairs(SIM.roster) do if r[4] >= 60 then expected = expected + 1 end end
  if s.atMax ~= expected then return "nivel 60: " .. s.atMax .. " (esperado " .. expected .. ")" end
  local sum = 0 for _, c in ipairs(s.byClass) do sum = sum + c.count end
  if sum ~= 36 then return "clases " .. sum end
  return true`);
await check('abre la ventana y muestra el resumen', `
  BG:ToggleWindow()
  SIM.layout(834, 604)
  BG:ShowView("overview")
  local f = BG.window.viewFrames.overview
  if not BG.window:IsShown() then return "ventana oculta" end
  if f.plates[1].value:GetText() ~= "36" then return "miembros " .. f.plates[1].value:GetText() end
  if f.plates[3].value:GetText() ~= "35,1" and not f.plates[3].value:GetText():find(",") then return "nivel medio " .. f.plates[3].value:GetText() end
  if f.hero.title:GetText() ~= "C A Ñ A D A" then return "título" end
  return true`);
await check('todas las secciones se construyen sin errores', `
  for _, item in ipairs(BG.nav) do
    BG:ShowView(item.key)
    SIM.layout(834, 604)
  end
  return true`);
await check('roster: orden, búsqueda y filtro de conectados', `
  BG:ShowView("roster")
  SIM.layout(834, 604)
  local f = BG.window.viewFrames.roster
  if #f.list.items ~= 36 then return "items " .. #f.list.items end
  for _, h in ipairs(f.headers) do if h.col.key == "level" then h:Click() end end
  if f.list.items[1].level ~= 60 then return "orden por nivel " .. f.list.items[1].level end
  f.query = "peregr"
  BG.views.roster.Refresh(f, BG.views.roster)
  if #f.list.items ~= 1 then return "búsqueda " .. #f.list.items end
  f.query = ""
  f.onlineOnly = true
  BG.views.roster.Refresh(f, BG.views.roster)
  if #f.list.items ~= 2 then return "conectados " .. #f.list.items end
  return true`);
await check('sin hermandad: estados vacíos honestos', `
  SIM.inGuild = false
  BG.Guild.Scan()
  BG:ShowView("overview")
  local f = BG.window.viewFrames.overview
  if f.hero.title:GetText() ~= "Sin hermandad" then return f.hero.title:GetText() end
  SIM.inGuild = true
  return true`);
await check('privacidad: se pregunta al abrir, se acepta y Escape no la retira', `
  BG.Guild.Scan()
  if BG.window:IsShown() then BG.window:Hide() end
  BlazonGuildDB.consent, BlazonGuildDB.consentDeclinedAt = nil, nil
  BlazonGuildDialog:Hide()
  BG:ToggleWindow()
  if not BG.UI.DialogShown() then return "no se pregunta" end
  if not BlazonGuildDialog.title:GetText():find("Antes de conectar") then return BlazonGuildDialog.title:GetText() end
  if not BG.window.status:GetText():find("Sin compartir") then return "estado: " .. BG.window.status:GetText() end
  BlazonGuildDialog.primary:Click()
  if not BG.Consent.Accepted() then return "no aceptada" end
  if BG.UI.DialogShown() then return "sigue abierto" end
  BG.commands.privacidad()
  if BlazonGuildDialog.title:GetText() ~= "Privacidad" then return "vista aceptada: " .. BlazonGuildDialog.title:GetText() end
  BlazonGuildDialog:Hide()
  if not BG.Consent.Accepted() then return "Escape retiró el permiso" end
  BG:RefreshStatus()
  if not BG.window.status:GetText():find("con BlazonGuild") then return "estado: " .. BG.window.status:GetText() end
  BG:ToggleWindow() BG:ToggleWindow()
  if BG.UI.DialogShown() then return "vuelve a preguntar" end
  return true`);
await check('ningún error capturado por el bus de eventos', `
  for _, line in ipairs(SIM.log) do if line:find("error en") then return line end end
  if BG.db.errors and #BG.db.errors > 0 then return BG.db.errors[1].where .. ": " .. BG.db.errors[1].error end
  return true`);

lua.global.close();
let failed = 0;
for (const [ok, name, detail] of checks) {
  console.log(`${ok ? '✓' : '✗'} ${name}${ok ? '' : `: ${detail}`}`);
  if (!ok) failed++;
}
console.log(`${checks.length - failed}/${checks.length} comprobaciones del addon en el cliente simulado`);
if (failed) process.exit(1);
