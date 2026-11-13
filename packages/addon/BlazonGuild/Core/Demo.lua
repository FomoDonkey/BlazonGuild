-- Modo capturas (/bg capturas): an example guild on this screen alone, to take pictures of BlazonGuild with every
-- screen full and no real player's name in them (Peregrino, 2026-11-13). The example comes from Data/DemoData.lua,
-- which tools/demo-build.mjs makes by running a simulated guild of invented players through the addon's own code
-- (so every record has the shape the addon itself writes), and moves its dates to now.
--
-- While it is on:
--   * BG.db is the example's saved data (the real one stays in BlazonGuildDB, which is what the game saves), but the
--     settings (window, size, language, minimap) are the real ones;
--   * the roster, who uses BlazonGuild and the guildmates on the map are the example's;
--   * nothing goes out (Comm.Send) and nothing comes in (Comm.OnMessage), and nothing is done in the game: no invite,
--     no whisper, no channel, no /roll that others would see (BG.InGame). A /roll of the Tavern is rolled here.
-- It ends with /bg capturas again, or with a /reload; the real guild comes back as it was.
local _, BG = ...
local Demo = {}
BG.Demo = Demo
local Names = BG.Names

local saved = nil
local ticker = nil

function Demo.Active()
  return saved ~= nil
end

-- The snapshot of this language, or the English one (the Spanish one for Spanish).
local function maker()
  local data = BG.DemoData or {}
  local lang = BG.Locale and BG.Locale.lang or "es"
  return data[lang] or data.en or data.es, lang
end

function Demo.Available()
  return maker() ~= nil
end

-- The snapshot with its dates moved to now: every number that is a date of the simulation (a server time within a
-- year of it) moves by the same amount, and the day keys ("20261113") follow.
local function load()
  local make = maker()
  local snap = make()
  local now = BG.Store.Now()
  local shift = now - snap.now
  local lo, hi = snap.now - 400 * 86400, snap.now + 400 * 86400
  local days = {}
  for d = -90, 60 do
    local t = snap.now + d * 86400
    days[date("!%Y%m%d", t)] = date("!%Y%m%d", t + shift)
  end
  local function fix(v)
    local kind = type(v)
    if kind == "number" then
      if v >= lo and v <= hi then
        return v + shift
      end
      return v
    elseif kind == "string" then
      if v:find("%d%d%d%d%d%d%d%d") then
        return (v:gsub("%d%d%d%d%d%d%d%d", days))
      end
      return v
    elseif kind ~= "table" then
      return v
    end
    local out = {}
    for k, x in pairs(v) do
      out[fix(k)] = fix(x)
    end
    return out
  end
  return fix(snap)
end

-- What the example plans (raids, operations) on its evening: the same hour of the day, so many days from today (a
-- plan for 23:00 that is already over today goes to tomorrow). The dates moved by an exact amount would put a raid
-- at 10:09.
local function plan(snap)
  local now = BG.Store.Now()
  local store = snap.db.guilds and snap.db.guilds[snap.info.home] and snap.db.guilds[snap.info.home].store or {}
  for _, s in ipairs(snap.sched or {}) do
    local r = store[s.c] and store[s.c][s.id]
    if r and r.d then
      local t = date("*t", now)
      t.hour, t.min, t.sec = s.hour, 0, 0
      local at = time(t) + s.days * 86400
      if at <= now + 1800 then
        at = at + 86400
      end
      r.d.start = at
      local def = BG.Store.collections[s.c]
      if def then
        r.exp = BG.Store.Expiry(def, r)
      end
    end
  end
end

-- Guildmates on the map: around this player, on their own map (so they show on the minimap too).
local function placeMates(snap)
  local mates = {}
  local map = C_Map and C_Map.GetBestMapForUnit and C_Map.GetBestMapForUnit("player")
  local pos = map and C_Map.GetPlayerMapPosition and C_Map.GetPlayerMapPosition(map, "player")
  local x, y = pos and pos.GetXY and pos:GetXY()
  if not (map and x and y) then
    return mates
  end
  for _, p in ipairs(snap.mates or {}) do
    local m = BG.Guild.Find(p.name)
    if m then
      local px, py = x + p.dx, y + p.dy
      if px > 0.01 and px < 0.99 and py > 0.01 and py < 0.99 then
        mates[p.name] = { name = p.name, m = map, x = px, y = py, t = GetTime(), c = m.classFile }
      end
    end
  end
  return mates
end

local function refresh()
  BG:Fire("BG_ROSTER_UPDATED")
  BG:Fire("BG_PEERS_CHANGED")
  for name in pairs(BG.Store.collections) do
    BG:Fire("BG_STORE_CHANGED", name)
  end
  BG:Fire("BG_MAP_CHANGED")
  BG:Fire("BG_CHRONICLE")
  BG:Fire("BG_DEMO_CHANGED", saved ~= nil)
  if BG.window and BG.window:IsShown() and BG.db.settings.lastView then
    BG:ShowView(BG.db.settings.lastView)
  end
end

local function keepAlive()
  local t = GetTime()
  for _, p in pairs(BG.Peers.list) do
    p.seen = t
  end
  for _, p in pairs(BG.Positions.mates) do
    p.t = t
  end
end

function Demo.Start()
  if saved then
    return nil, "ya"
  end
  if not Demo.Available() then
    return nil, "sin datos"
  end
  if InCombatLockdown and InCombatLockdown() then
    return nil, "combate"
  end
  local snap = load()
  plan(snap)
  local G = BG.Guild
  saved = {
    db = BG.db, viewAs = BG.viewAs,
    guild = { info = G.info, members = G.members, byGuid = G.byGuid, byName = G.byName, me = G.me, stats = G.stats, scannedAt = G.scannedAt, fromCache = G.fromCache },
    peers = BG.Peers.list, mates = BG.Positions.mates, layers = BG.Layers.seen,
  }
  BG.viewAs = nil
  local db = snap.db
  db.settings = saved.db.settings -- (the real window, size, language and minimap)
  db.characters = { [UnitGUID("player")] = snap.info.home }
  BG.db = db
  BG.demo = true
  G.info, G.members, G.scannedAt, G.fromCache = snap.info, snap.members, BG.Store.Now(), false
  G.byGuid = {}
  for _, m in ipairs(snap.members) do
    if m.guid then
      G.byGuid[m.guid] = m
    end
  end
  G.byName = G.IndexByName(snap.members)
  G.me = G.byName[snap.me]
  G.stats = G.BuildStats(snap.members, G.MaxLevel())
  BG.Peers.list = {}
  for _, name in ipairs(snap.peers or {}) do
    BG.Peers.list[name] = { name = name, version = BG.version, protocol = BG.Comm.PROTOCOL, willing = true, seen = GetTime() }
  end
  BG.Layers.seen = {}
  BG.Positions.mates = placeMates(snap)
  ticker = C_Timer.NewTicker(20, keepAlive)
  BG:Notify(BG.T("Modo capturas"), BG.T("Una hermandad de ejemplo, solo en tu pantalla: nombres inventados y nada sale de tu juego. Vuelve a la tuya con /bg capturas."), { kind = "info" })
  refresh()
  return true
end

function Demo.Stop()
  if not saved then
    return nil, "no"
  end
  if ticker then
    ticker:Cancel()
    ticker = nil
  end
  local G, s = BG.Guild, saved
  saved = nil
  BG.demo = nil
  BG.db = s.db
  BG.viewAs = s.viewAs
  for k, v in pairs(s.guild) do
    G[k] = v
  end
  BG.Peers.list, BG.Positions.mates, BG.Layers.seen = s.peers, s.mates, s.layers
  if BG.Radar and BG.Radar.Stop then
    BG.Radar.Stop()
  end
  BG:Notify(BG.T("Tu hermandad"), BG.T("El modo capturas ha terminado: vuelves a ver tu hermandad."), { kind = "info" })
  refresh()
  G.Scan()
  return true
end

function Demo.Toggle()
  if saved then
    return Demo.Stop()
  end
  return Demo.Start()
end

-- What the addon would do in the game (invite, whisper, a channel, a /roll others see...): in the capture mode it
-- is not done, and the player is told once in a while. Returns true when it may go ahead.
local told = 0
function BG.InGame()
  if not saved then
    return true
  end
  if GetTime() - told > 10 then
    told = GetTime()
    BG:Notify(BG.T("Modo capturas"), BG.T("En el modo capturas no se hace nada en el juego: es solo una hermandad de ejemplo."), { kind = "info" })
  end
  return false
end

-- /roll: the game's own, or one rolled on this screen in the capture mode (the line the game would print, read by
-- the same code a moment later).
function BG.RandomRoll(lo, hi)
  if not saved then
    return RandomRoll(lo, hi)
  end
  local v = math.random(lo, hi)
  C_Timer.After(0.6, function()
    if saved then
      BG:Fire("CHAT_MSG_SYSTEM", BG.Arena.Format("RANDOM_ROLL_RESULT"):format(Names.Me(), v, lo, hi))
    end
  end)
end

BG.commands = BG.commands or {}
BG.commands.capturas = function()
  local ok, why = Demo.Toggle()
  if not ok then
    BG:Print(BG.T(why == "combate" and "en combate no; prueba al salir." or "este addon no trae la hermandad de ejemplo."))
  end
end
BG.commands.screenshots = BG.commands.capturas
