-- Who else in the guild has BlazonGuild: a short hello over GUILD, versions, and the guild's
-- "messenger" (the one member whose addon speaks for the guild to sister guilds and to the web).
--
-- Traffic stays small whatever the guild's size: everyone says hello once after login and then every
-- HELLO_EVERY (with jitter); a newcomer's hello asks for answers, and each peer answers with a
-- probability that keeps the expected number of answers near ANSWERS, so a guild of 500 addon users
-- does not answer one login with 500 messages. Everyone learns everyone within one HELLO_EVERY.
local _, BG = ...
local Peers = { list = {} }
BG.Peers = Peers
local Comm, Names = BG.Comm, BG.Names

local HELLO_EVERY = 300
local HELLO_JITTER = 60
local FIRST_HELLO = 6 -- seconds after the roster and consent are ready
local PEER_TTL = 12 * 60 -- a peer not heard for this long is forgotten
local ANSWERS = 8
local ANSWER_GAP = 30 -- we never answer twice within this

local lastHello = -math.huge
local helloScheduled = false
local newerNotified = false

-- "0.10.2" > "0.9.9": numeric parts compared in order; missing parts are 0. Pure.
function Peers.CompareVersions(a, b)
  local pa, pb = {}, {}
  for n in tostring(a or ""):gmatch("%d+") do
    pa[#pa + 1] = tonumber(n)
  end
  for n in tostring(b or ""):gmatch("%d+") do
    pb[#pb + 1] = tonumber(n)
  end
  for i = 1, math.max(#pa, #pb) do
    local x, y = pa[i] or 0, pb[i] or 0
    if x ~= y then
      return x < y and -1 or 1
    end
  end
  return 0
end

-- Sort key of a candidate for the messenger: organisers first (the guild trusts them with others' records,
-- Store.lua), then the newest protocol, then the name, so every client that sees the same list agrees.
function Peers.Rank(c)
  local organiser = c.organiser
  if organiser == nil and BG.Store then
    organiser = BG.Store.RealOrganiser(c.name)
  end
  return string.format("%d%03d%s", organiser and 0 or 1, 999 - math.min(999, c.protocol or 0), c.name:lower())
end

-- Pure given Rank: the messenger among candidates { name, protocol, willing, organiser }.
function Peers.Elect(candidates)
  local best, bestKey
  for _, c in ipairs(candidates) do
    if c.willing ~= false then
      local key = Peers.Rank(c)
      if not best or key < bestKey then
        best, bestKey = c, key
      end
    end
  end
  return best and best.name or nil
end

local function helloBody(ask)
  return {
    v = BG.version,
    p = Comm.PROTOCOL,
    w = BG.db.settings.messenger ~= false, -- willing to be the guild's messenger
    q = ask or nil,
    x = BG.db.allyHidden and BG.db.allyHidden[Names.Me() or ""] and 1 or nil, -- hidden from the other guilds (Alliance.lua)
  }
end

function Peers.SayHello(ask)
  if not (BG.Consent.Accepted() and IsInGuild()) then
    return false
  end
  lastHello = GetTime()
  return Comm.Send("HI", helloBody(ask), "GUILD", nil, { key = "HI", lane = "normal" })
end

local function scheduleHello(delay, ask)
  if helloScheduled then
    return
  end
  helloScheduled = true
  C_Timer.After(delay, function()
    helloScheduled = false
    Peers.SayHello(ask)
  end)
end

local function notifyNewer(version)
  if newerNotified or Peers.CompareVersions(version, BG.version) <= 0 then
    return
  end
  newerNotified = true
  BG.db.newestSeen = version
  BG:Print(BG.TF("hay una versión más nueva en tu hermandad (%s; tienes %s). Actualízala desde CurseForge.", version, BG.version))
  BG:Fire("BG_NEWER_VERSION", version)
end

local changeScheduled = false
local function changed()
  if changeScheduled then
    return
  end
  changeScheduled = true
  C_Timer.After(0.5, function()
    changeScheduled = false
    BG:Fire("BG_PEERS_CHANGED")
  end)
end

Comm.Register("HI", function(sender, body)
  if type(body) ~= "table" or type(body.v) ~= "string" or #body.v > 20 then
    return
  end
  local isNew = Peers.list[sender] == nil
  Peers.list[sender] = {
    name = sender, version = body.v, protocol = tonumber(body.p) or 1, willing = body.w ~= false, seen = GetTime(), hidden = body.x == 1 or nil,
  }
  notifyNewer(body.v)
  if isNew then
    changed()
  end
  if body.q and GetTime() - lastHello > ANSWER_GAP then
    local known = 0
    for _ in pairs(Peers.list) do
      known = known + 1
    end
    if math.random() <= ANSWERS / math.max(1, known) then
      scheduleHello(1 + math.random() * 5, false)
    end
  end
end, { maxBytes = 120 })

-- Peers heard recently and, when the roster says so, still online. Includes us when we share.
function Peers.Active()
  local t, out = GetTime(), {}
  for name, p in pairs(Peers.list) do
    local m = BG.Guild.Find(name)
    if t - p.seen > PEER_TTL or (m and not m.online and not BG.Guild.fromCache) then
      Peers.list[name] = nil
    else
      out[#out + 1] = p
    end
  end
  local me = Names.Me()
  if me and BG.Consent.Accepted() and IsInGuild() then
    out[#out + 1] = { name = me, version = BG.version, protocol = Comm.PROTOCOL, willing = BG.db.settings.messenger ~= false, seen = t, me = true,
      hidden = BG.db.allyHidden and BG.db.allyHidden[me] or nil }
  end
  table.sort(out, function(a, b)
    return a.name:lower() < b.name:lower()
  end)
  return out
end

function Peers.Get(name)
  local short = Names.Short(name)
  if short and Names.IsMe(short) and BG.Consent.Accepted() then
    return { name = short, version = BG.version, me = true }
  end
  return short and Peers.list[short] or nil
end

function Peers.Messenger()
  return Peers.Elect(Peers.Active())
end

function Peers.AmMessenger()
  local m = Peers.Messenger()
  return m ~= nil and Names.IsMe(m)
end

-- Lifecycle --------------------------------------------------------------------------------------
local ticking = false
local function startTicker()
  if ticking then
    return
  end
  ticking = true
  local function tick()
    if BG.Consent.Accepted() and IsInGuild() and GetTime() - lastHello >= HELLO_EVERY then
      Peers.SayHello(false)
    end
    local before = 0
    for _ in pairs(Peers.list) do
      before = before + 1
    end
    Peers.Active() -- forgets peers that went quiet
    local after = 0
    for _ in pairs(Peers.list) do
      after = after + 1
    end
    if after ~= before then
      changed()
    end
    C_Timer.After(HELLO_EVERY / 5 + math.random() * HELLO_JITTER / 5, tick)
  end
  C_Timer.After(HELLO_EVERY / 5, tick)
end

local function ready()
  if BG.Consent.Accepted() and IsInGuild() and BG.Guild.info then
    scheduleHello(FIRST_HELLO + math.random() * 4, true)
    startTicker()
  end
end

local greeted = false
BG:On("BG_ROSTER_UPDATED", function()
  changed()
  if not greeted and BG.Guild.info and not BG.Guild.fromCache then
    greeted = true
    ready()
  end
end)

BG:On("BG_CONSENT_CHANGED", function(accepted)
  if accepted then
    greeted = BG.Guild.info ~= nil and not BG.Guild.fromCache
    ready()
  else
    Comm.Clear("consent")
    -- The one message sent after consent ends: "forget me", so nobody keeps showing us as connected.
    if IsInGuild() then
      Comm.Send("BY", {}, "GUILD", nil, { lane = "alert", anytime = true })
    end
  end
  changed()
end)

Comm.Register("BY", function(sender)
  if Peers.list[sender] then
    Peers.list[sender] = nil
    changed()
  end
end, { maxBytes = 8 })

BG:On("PLAYER_GUILD_UPDATE", function()
  if not IsInGuild() then
    wipe(Peers.list)
    greeted = false
    changed()
  end
end)
