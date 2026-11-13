-- Avistamientos (entrega 7; the idea of Olympus' PlayerSightings.lua, MIT, our own implementation): "where was that
-- player of the other faction seen?". Each client remembers, in memory only and for a quarter of an hour, the players
-- of the other faction its own game showed it (target, mouse over, a nameplate) outside instances: who, level, class,
-- guild, and where we were then. Nothing is sent by itself. A member asks (about one name, or about the zone they
-- are in) and the guildmates who said yes to «avistamientos» answer by whisper to that member alone, with what their
-- own game showed them. Only players of the other faction: never anyone of ours, nor of our faction.
local _, BG = ...
local Sightings = { seen = {}, asks = {} }
BG.Sightings = Sightings
local Names, Comm = BG.Names, BG.Comm
local str = BG.Raids.Clean

local KEEP = 15 * 60 -- what this client saw, in seconds
local MAX_SEEN = 64
local ASK_TTL = 10 * 60 -- answers to a question are taken (and shown) for ten minutes
local ASK_GAP = 10 -- seconds between two questions of ours
local MAX_ROWS = 6 -- rows in one answer
local RATE_WINDOW, RATE_PER = 60, 3 -- questions answered per member per minute

BG.Consent.Register({ key = "sightings", label = "Decir a mi hermandad dónde he visto a jugadores de la otra facción, solo cuando un compañero lo pregunte" })

local function secret(v)
  return issecretvalue ~= nil and issecretvalue(v)
end

local function zoneText()
  local ok, z = pcall(GetRealZoneText or GetZoneText or function() return nil end)
  return ok and not secret(z) and str(z, 60) or nil
end

-- Remembering ------------------------------------------------------------------------------------------------------
local function prune()
  local now, n, oldest, oldestT = GetTime(), 0, nil, math.huge
  for name, s in pairs(Sightings.seen) do
    if now - s.t > KEEP then
      Sightings.seen[name] = nil
    else
      n = n + 1
      if s.t < oldestT then
        oldest, oldestT = name, s.t
      end
    end
  end
  if n > MAX_SEEN and oldest then
    Sightings.seen[oldest] = nil
  end
end

-- A unit this client sees now (target, mouseover, nameplateN): remembered if it is a player of the other faction.
function Sightings.Observe(unit, how)
  if not unit or not BG.Wanted then
    return
  end
  local okP, isPlayer = pcall(UnitIsPlayer, unit)
  if not okP or secret(isPlayer) or not isPlayer then
    return
  end
  local okG, guid = pcall(UnitGUID, unit)
  if not okG or secret(guid) then
    return
  end
  local foe = BG.Wanted.FoeOf(guid, Names.Unit(unit))
  if not foe then
    return
  end
  local map, x, y = BG.Layers.MyPosition() -- (nil inside instances, on a boat or flying)
  if not map then
    return
  end
  local okL, lvl = pcall(UnitLevel, unit)
  local okGu, guild = pcall(GetGuildInfo, unit)
  local s = Sightings.seen[foe.name] or {}
  s.name, s.class = foe.name, foe.class
  s.level = okL and type(lvl) == "number" and not secret(lvl) and lvl or s.level
  if okGu and type(guild) == "string" and not secret(guild) then
    s.guild = str(guild, 40)
  end
  s.m, s.x, s.y, s.zone, s.t, s.how = map, x, y, zoneText(), GetTime(), how
  Sightings.seen[foe.name] = s
  prune()
end

local function firstWord(s)
  return (tostring(s or ""):match("^(%S+)") or ""):lower()
end

-- Does a name typed by someone ("Grosh", "grosh rompehuesos") point to this one?
local function sameName(seen, asked)
  asked = tostring(asked or ""):lower()
  if asked == "" then
    return false
  end
  local full = seen:lower()
  return full == asked or (not asked:find(" ", 1, true) and firstWord(full) == asked)
end

-- What this client saw that answers a question: { name } or { zone map }.
local function matching(q)
  prune()
  local out, now = {}, GetTime()
  for _, s in pairs(Sightings.seen) do
    if (q.n and sameName(s.name, q.n)) or (q.z and s.m == q.z) then
      out[#out + 1] = s
    end
  end
  table.sort(out, function(a, b)
    return a.t > b.t
  end)
  local rows = {}
  for i = 1, math.min(MAX_ROWS, #out) do
    local s = out[i]
    rows[i] = { n = s.name, c = s.class, l = s.level, g = s.guild, m = s.m, x = math.floor(s.x * 1000), y = math.floor(s.y * 1000),
      a = math.floor(now - s.t), z = s.zone }
  end
  return rows
end

-- Asking -----------------------------------------------------------------------------------------------------------
local lastAsk = -math.huge

local function addRow(ask, row, by)
  for i, r in ipairs(ask.rows) do
    if r.name == row.name then
      if r.at >= row.at then
        return false
      end
      table.remove(ask.rows, i)
      break
    end
  end
  row.by = by
  ask.rows[#ask.rows + 1] = row
  table.sort(ask.rows, function(a, b)
    return a.at > b.at
  end)
  return true
end

-- Ask the guild: Sightings.Ask("Grosh") about one player, Sightings.Ask() about the zone we are in.
function Sightings.Ask(name)
  if not BG.Consent.Accepted() then
    return nil, "consent"
  end
  if not IsInGuild() then
    return nil, "sin hermandad"
  end
  if GetTime() - lastAsk < ASK_GAP then
    return nil, "espera"
  end
  local body = { i = BG.Alliance and BG.Alliance.RandomId(6) or tostring(math.random(100000, 999999)) }
  local ask = { id = body.i, t = GetTime(), rows = {} }
  if name then
    name = str(name, 40)
    if not name or name == "" then
      return nil, "sin nombre"
    end
    body.n, ask.name = name, name
  else
    local map = BG.Layers.ZoneMap()
    if not map then
      return nil, "sin zona"
    end
    body.z, ask.zone, ask.zoneName = map, map, zoneText()
  end
  lastAsk = GetTime()
  Sightings.asks[ask.id] = ask
  Sightings.current = ask.id
  -- What we saw ourselves counts too (nothing is sent for it).
  for _, r in ipairs(matching(body)) do
    addRow(ask, { name = r.n, class = r.c, level = r.l, guild = r.g, m = r.m, x = r.x / 1000, y = r.y / 1000, at = GetTime() - r.a, zone = r.z }, Names.Me())
  end
  Comm.Send("VQ", body, "GUILD", nil, { lane = "normal" })
  BG:Fire("BG_SIGHTINGS_CHANGED")
  return ask
end

-- The question on screen (the last one, while its answers are fresh).
function Sightings.Current()
  local ask = Sightings.current and Sightings.asks[Sightings.current]
  if ask and GetTime() - ask.t > ASK_TTL then
    Sightings.asks[ask.id] = nil
    Sightings.current = nil
    return nil
  end
  return ask
end

function Sightings.Clear()
  Sightings.current = nil
  BG:Fire("BG_SIGHTINGS_CHANGED")
end

-- What this client itself saw lately, newest first.
function Sightings.Mine()
  prune()
  local out = {}
  for _, s in pairs(Sightings.seen) do
    out[#out + 1] = s
  end
  table.sort(out, function(a, b)
    return a.t > b.t
  end)
  return out
end

function Sightings.Answering()
  return BG.Consent.Line("sightings")
end

function Sightings.SetAnswering(on)
  if on and not BG.Consent.Accepted() then
    return nil, "consent"
  end
  BG.Consent.SetLine("sightings", on)
  BG:Fire("BG_SIGHTINGS_CHANGED")
  return true
end

-- Messages ---------------------------------------------------------------------------------------------------------
local rates = {}
local function allowed(sender)
  local now = GetTime()
  local r = rates[sender]
  if not r or now - r.t > RATE_WINDOW then
    r = { t = now, n = 0 }
    rates[sender] = r
  end
  r.n = r.n + 1
  return r.n <= RATE_PER
end

Comm.Register("VQ", function(sender, b, channel)
  if channel ~= "GUILD" or type(b) ~= "table" or sender == Names.Me() or not BG.Guild.Find(sender) then
    return
  end
  if not Sightings.Answering() or not allowed(sender) then
    return
  end
  local q = { n = type(b.n) == "string" and str(b.n, 40) or nil, z = tonumber(b.z) }
  if not (q.n or q.z) or type(b.i) ~= "string" or #b.i > 12 then
    return
  end
  local rows = matching(q)
  if #rows > 0 then
    Comm.Send("VR", { i = b.i, r = rows }, "WHISPER", sender, { lane = "normal" })
  end
end, { maxBytes = 120 })

Comm.Register("VR", function(sender, b, channel)
  if channel ~= "WHISPER" or type(b) ~= "table" or type(b.r) ~= "table" or not BG.Guild.Find(sender) then
    return
  end
  local ask = type(b.i) == "string" and Sightings.asks[b.i]
  if not ask or GetTime() - ask.t > ASK_TTL then
    return
  end
  local added = 0
  for i = 1, math.min(MAX_ROWS, #b.r) do
    local r = type(b.r[i]) == "table" and b.r[i] or {}
    local name = type(r.n) == "string" and str(r.n, 40)
    local m, x, y, a = tonumber(r.m), tonumber(r.x), tonumber(r.y), tonumber(r.a)
    local fits = name and name ~= "" and m and x and y and a and x >= 0 and x <= 1000 and y >= 0 and y <= 1000 and a >= 0 and a <= KEEP
    if fits and ((ask.name and sameName(name, ask.name)) or (ask.zone and m == ask.zone)) then
      local lvl = tonumber(r.l)
      local row = { name = name, class = type(r.c) == "string" and r.c:match("^%u+$") and r.c or nil, level = lvl and lvl >= -1 and lvl <= 100 and math.floor(lvl) or nil,
        guild = type(r.g) == "string" and str(r.g, 40) or nil, m = math.floor(m), x = x / 1000, y = y / 1000, at = GetTime() - a,
        zone = type(r.z) == "string" and str(r.z, 60) or nil }
      if addRow(ask, row, sender) then
        added = added + 1
      end
    end
  end
  if added > 0 then
    BG:Fire("BG_SIGHTINGS_CHANGED")
    if ask.name and not ask.told then
      ask.told = true
      local r = ask.rows[1]
      BG:Notify("Avistamiento: " .. r.name, r.zone and string.format("Visto %s en «%s», por %s.", Sightings.Ago(r.at), r.zone, r.by)
        or string.format("Visto %s, por %s.", Sightings.Ago(r.at), r.by),
        { kind = "info", icon = "Interface\\Icons\\INV_Misc_Spyglass_02", view = "map" })
    end
  end
end, { channels = { "WHISPER" }, maxBytes = 1400 })

-- "hace 3 min" for a moment of GetTime().
function Sightings.Ago(at)
  local s = math.max(0, GetTime() - at)
  if s < 60 then
    return "hace un momento"
  end
  local m = math.floor(s / 60)
  return "hace " .. m .. " min"
end

-- Events -------------------------------------------------------------------------------------------------------------
BG:On("PLAYER_TARGET_CHANGED", function()
  Sightings.Observe("target", "t")
end)
BG:On("UPDATE_MOUSEOVER_UNIT", function()
  Sightings.Observe("mouseover", "m")
end)
BG:On("NAME_PLATE_UNIT_ADDED", function(unit)
  Sightings.Observe(unit, "p")
end)
