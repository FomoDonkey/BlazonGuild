-- Addon-to-addon messages: one prefix, typed messages, a paced send queue and piece reassembly.
--
-- What the live client allows (ADDON_COMPATIBILITY §2, measured by our probe and by Olympus, MIT):
--   * GUILD messages reach every member with the addon, on every sub-realm of the faction, and come
--     back to the sender too (our probe: 431 ms). Addon WHISPERs work across sub-realms by "First Surname".
--   * Messages on player-made channels are NOT delivered on Forever, so nothing here uses CHANNEL; sister
--     guilds talk through whispers between their members (Alliance.lua).
--   * A message is at most 255 bytes; the game throttles bursts and refuses everything during a chat
--     lockdown (C_ChatInfo.InChatMessagingLockdown: raids, dungeons, encounters, PvP matches).
--
-- Frame on the wire:  <protocol><"!"><TYPE>:<Serial>              a whole message
--                     <protocol><"#"><id:2><index:2><count:2><piece>  one piece of a long one (base36)
-- Nothing leaves this client before the player accepts the privacy page (Consent.lua).
local _, BG = ...
local Comm = {}
BG.Comm = Comm
local Serial, Names = BG.Serial, BG.Names

Comm.PREFIX = "BlazonGuild"
Comm.PROTOCOL = 1
local PROTO_CHAR = Serial.Base36(Comm.PROTOCOL)
Comm.MAX_FRAME = 255
Comm.PIECE = 240
Comm.MAX_PARTS = 64 -- about 15 KB for one message
Comm.MAX_QUEUE = 120
local OPEN_PER_SENDER = 4
local OPEN_MAX = 200
local BUCKET_CAP = 4 -- a short burst, then one message every REFILL seconds
local REFILL = 1.2
local HOLD_MAX = 600 -- a message held this long by a lockdown is dropped rather than sent stale
local LOCK_RECHECK = 5
local RETRY_WAIT = { 2, 4, 8, 15, 30 }
local RETRY_MAX = 5
-- Enum.SendAddonMessageResult: 0 success; "not now": 3 AddonMessageThrottle, 8 ChannelThrottle,
-- 9 GeneralError, 11 AddOnMessageLockdown. Anything else (12: target offline) ends the job.
local LOCKDOWN = 11
local RETRYABLE = { [3] = true, [8] = true, [9] = true, [LOCKDOWN] = true }
local LANE_ORDER = { "alert", "normal", "bulk" }
local DISTS = { GUILD = true, OFFICER = true, WHISPER = true, PARTY = true, RAID = true, INSTANCE_CHAT = true }

local handlers = {}
local lanes = { alert = {}, normal = {}, bulk = {} }
local queued = 0
local tokens, refilledAt = BUCKET_CAP, nil
local waitUntil, refusedInRow, heldSince = 0, 0, nil
local pumpScheduled = false
local nextId = 0
local open, openCount, openBySender = {}, 0, {}

Comm.stats = { sent = 0, recv = 0, bytesOut = 0, bytesIn = 0, fails = 0, retries = 0, dropped = 0, echo = 0, bad = 0, unknown = 0, future = 0, refused = 0, byType = {} }
local stats = Comm.stats

local function now()
  return GetTime()
end

local function count(kind)
  stats.byType[kind] = (stats.byType[kind] or 0) + 1
end

function Comm.InLockdown()
  if C_ChatInfo and C_ChatInfo.InChatMessagingLockdown then
    local ok, locked = pcall(C_ChatInfo.InChatMessagingLockdown)
    return ok and locked == true
  end
  return false
end

-- Handlers ---------------------------------------------------------------------------------------
-- opts.channels: the distributions it accepts (default GUILD only). opts.maxBytes caps the payload.
function Comm.Register(kind, fn, opts)
  assert(type(kind) == "string" and kind:find("^[%u%d]+$") and #kind <= 6, "tipo de mensaje no válido")
  assert(not handlers[kind], "tipo de mensaje repetido: " .. tostring(kind)) -- (a second one would silence the first)
  opts = opts or {}
  local channels = {}
  for _, ch in ipairs(opts.channels or { "GUILD" }) do
    channels[ch] = true
  end
  handlers[kind] = { fn = fn, channels = channels, maxBytes = opts.maxBytes or (Comm.PIECE * Comm.MAX_PARTS), time = 0, calls = 0 }
end

function Comm.HandlerStats()
  local out = {}
  for kind, h in pairs(handlers) do
    out[#out + 1] = { kind = kind, calls = h.calls, ms = h.time }
  end
  table.sort(out, function(a, b)
    return a.ms > b.ms
  end)
  return out
end

-- Framing (pure; exposed for the tests) ------------------------------------------------------------
local function pad2(n)
  local s = Serial.Base36(n)
  return #s == 1 and ("0" .. s) or s
end

function Comm.Frames(payload, id)
  if #payload + 2 <= Comm.MAX_FRAME then
    return { PROTO_CHAR .. "!" .. payload }
  end
  -- Pieces never cut a UTF-8 character in two, so every frame is valid text on its own.
  local pieces, pos, len = {}, 1, #payload
  while pos <= len do
    local stop = math.min(len, pos + Comm.PIECE - 1)
    while stop < len and stop > pos do
      local b = payload:byte(stop + 1)
      if b >= 128 and b < 192 then
        stop = stop - 1
      else
        break
      end
    end
    pieces[#pieces + 1] = payload:sub(pos, stop)
    pos = stop + 1
  end
  local n = #pieces
  local frames = {}
  for i = 1, n do
    frames[i] = PROTO_CHAR .. "#" .. pad2(id) .. pad2(i) .. pad2(n) .. pieces[i]
  end
  return frames
end

local function closeOpen(key)
  local a = open[key]
  if a then
    open[key] = nil
    openCount = openCount - 1
    openBySender[a.sender] = (openBySender[a.sender] or 1) - 1
  end
end

local function gcOpen(t)
  for key, a in pairs(open) do
    if t - a.started > a.ttl then
      stats.dropped = stats.dropped + 1
      closeOpen(key)
    end
  end
end

-- Returns the whole payload once every piece arrived, nil while waiting, or false for a bad piece.
function Comm.Assemble(sender, frame, t)
  local id, index, total = frame:sub(3, 4), tonumber(frame:sub(5, 6), 36), tonumber(frame:sub(7, 8), 36)
  if not (index and total) or index < 1 or index > total or total < 2 or total > Comm.MAX_PARTS then
    return false
  end
  local key = sender .. "#" .. id
  local a = open[key]
  if a and a.total ~= total then
    closeOpen(key) -- the same id reused for another message: start over
    a = nil
  end
  if not a then
    gcOpen(t)
    if openCount >= OPEN_MAX or (openBySender[sender] or 0) >= OPEN_PER_SENDER then
      stats.refused = stats.refused + 1
      return false
    end
    a = { sender = sender, total = total, got = 0, parts = {}, started = t, ttl = 30 + total * 3 }
    open[key] = a
    openCount = openCount + 1
    openBySender[sender] = (openBySender[sender] or 0) + 1
  end
  if not a.parts[index] then
    a.parts[index] = frame:sub(9)
    a.got = a.got + 1
  end
  if a.got < total then
    return nil
  end
  closeOpen(key)
  return table.concat(a.parts)
end

-- Receiving --------------------------------------------------------------------------------------
local function deliver(sender, channel, payload)
  local kind, body = payload:match("^([%u%d]+):(.*)$")
  if not kind then
    stats.bad = stats.bad + 1
    return
  end
  local h = handlers[kind]
  if not h then
    stats.unknown = stats.unknown + 1 -- a newer version's message: ignored, never an error
    return
  end
  if not h.channels[channel] or #body > h.maxBytes then
    stats.refused = stats.refused + 1
    return
  end
  local value, why = Serial.Decode(body)
  if value == nil then
    stats.bad = stats.bad + 1
    BG:Debug("mensaje " .. kind .. " de " .. sender .. " ilegible: " .. tostring(why))
    return
  end
  count(kind)
  local started = debugprofilestop and debugprofilestop() or 0
  local ok, err = pcall(h.fn, sender, value, channel)
  h.calls = h.calls + 1
  h.time = h.time + ((debugprofilestop and debugprofilestop() or 0) - started)
  if not ok then
    BG:RecordError("mensaje " .. kind, err)
  end
end

function Comm.OnMessage(prefix, frame, channel, sender)
  if BG.demo or prefix ~= Comm.PREFIX or type(frame) ~= "string" or type(sender) ~= "string" then
    return
  end
  if issecretvalue and (issecretvalue(frame) or issecretvalue(sender)) then
    return
  end
  if Names.IsMe(sender) then
    stats.echo = stats.echo + 1
    Comm.lastEcho = now() -- our own GUILD message came back: the channel works
    BG:Fire("BG_COMM_ECHO", channel)
    return
  end
  if not DISTS[channel] then
    return
  end
  stats.recv = stats.recv + 1
  stats.bytesIn = stats.bytesIn + #frame
  local who = Names.Short(sender)
  local proto, mark = frame:sub(1, 1), frame:sub(2, 2)
  local p = tonumber(proto, 36)
  if not p then
    stats.bad = stats.bad + 1
    return
  end
  if p > Comm.PROTOCOL then
    stats.future = stats.future + 1
    BG:Fire("BG_FUTURE_PROTOCOL", who, p)
    return
  end
  if mark == "!" then
    deliver(who, channel, frame:sub(3))
  elseif mark == "#" then
    local whole = Comm.Assemble(who, frame, now())
    if whole == false then
      stats.bad = stats.bad + 1
    elseif whole then
      deliver(who, channel, whole)
    end
  else
    stats.bad = stats.bad + 1
  end
end

BG:On("CHAT_MSG_ADDON", Comm.OnMessage)

-- Sending ----------------------------------------------------------------------------------------
local schedulePump

local function removeJob(lane, i, why)
  local job = table.remove(lanes[lane], i)
  queued = queued - 1
  if why then
    stats.dropped = stats.dropped + 1
  end
  if job.done then
    local ok, err = pcall(job.done, why == nil, why)
    if not ok then
      BG:RecordError("fin de envío", err)
    end
  end
end

-- Messages that can no longer go: their guild changed, a lockdown held them too long, or consent ended.
local function dropStale(t)
  -- (right after logging in the game may not know the guild's name for a moment: a message is dropped only when
  -- we left the guild, or when both names are known and differ)
  local inGuild = IsInGuild()
  local guild = inGuild and GetGuildInfo("player") or nil
  for _, lane in ipairs(LANE_ORDER) do
    local list = lanes[lane]
    for i = #list, 1, -1 do
      local job = list[i]
      if (job.dist == "GUILD" or job.dist == "OFFICER") and (not inGuild or (job.guild and guild and job.guild ~= guild)) then
        removeJob(lane, i, "guild")
      elseif t - job.t > HOLD_MAX then
        removeJob(lane, i, "late")
      elseif not BG.Consent.Accepted() and not job.anytime then
        removeJob(lane, i, "consent")
      end
    end
  end
end

-- Whispers to someone who is not playing: the server answers with a system line ("No player named X is
-- currently playing", ERR_CHAT_PLAYER_NOT_FOUND_S). We learn from it (BG_WHISPER_OFFLINE: try another
-- contact) and keep it out of the player's chat, since they typed nothing (Olympus does the same, MIT).
local told = {} -- lower-case name -> GetTime() of our last whisper to them
local QUIET = 15
local notFoundPattern
function Comm.NotFoundName(text)
  if type(text) ~= "string" or (issecretvalue and issecretvalue(text)) then
    return nil
  end
  if not notFoundPattern then
    local f = type(ERR_CHAT_PLAYER_NOT_FOUND_S) == "string" and ERR_CHAT_PLAYER_NOT_FOUND_S or "No player named '%s' is currently playing."
    local escaped = f:gsub("([%^%$%(%)%%%.%[%]%*%+%-%?])", "%%%1")
    notFoundPattern = "^" .. escaped:gsub("%%%%s", "(.+)") .. "$"
  end
  local who = text:match(notFoundPattern)
  return who and Names.Short(who) or nil
end

local function toldRecently(name)
  local at = name and told[name:lower()]
  return at ~= nil and now() - at < QUIET
end

-- The rest of what was going to them by whisper is dropped: each piece would only bring the same answer.
function Comm.DropWhispersTo(name)
  local short = Names.Short(name)
  for _, lane in ipairs(LANE_ORDER) do
    local list = lanes[lane]
    for i = #list, 1, -1 do
      local job = list[i]
      if job.dist == "WHISPER" and Names.Same(job.target, short) then
        removeJob(lane, i, "offline")
      end
    end
  end
end

BG:On("CHAT_MSG_SYSTEM", function(text)
  local who = Comm.NotFoundName(text)
  if who and toldRecently(who) then
    Comm.DropWhispersTo(who)
    BG:Fire("BG_WHISPER_OFFLINE", who)
  end
end)

local filtering = false
local function quietFilter(_, _, text)
  local who = Comm.NotFoundName(text)
  return who ~= nil and toldRecently(who)
end

local function sendFrame(job, frame)
  local target = job.dist == "WHISPER" and Names.Tell(job.target) or nil
  if target then
    told[target:lower()] = now()
    if not filtering and ChatFrame_AddMessageEventFilter then
      filtering = true
      pcall(ChatFrame_AddMessageEventFilter, "CHAT_MSG_SYSTEM", quietFilter)
    end
  end
  local ok, res = pcall(C_ChatInfo.SendAddonMessage, Comm.PREFIX, frame, job.dist, target)
  if ok and (res == nil or res == true or res == 0) then
    return true
  end
  return false, ok and res or "error"
end

local function pump()
  pumpScheduled = false
  if queued == 0 then
    heldSince = nil
    return
  end
  local t = now()
  dropStale(t)
  if queued == 0 then
    return
  end
  if Comm.InLockdown() then
    heldSince = heldSince or t
    schedulePump(LOCK_RECHECK)
    return
  end
  heldSince = nil
  if t < waitUntil then
    schedulePump(waitUntil - t)
    return
  end
  refilledAt = refilledAt or t
  tokens = math.min(BUCKET_CAP, tokens + (t - refilledAt) / REFILL)
  refilledAt = t
  while tokens >= 1 and queued > 0 do
    local lane, job
    for _, name in ipairs(LANE_ORDER) do
      if lanes[name][1] then
        lane, job = name, lanes[name][1]
        break
      end
    end
    local frame = job.frames[job.sent + 1]
    local ok, res = sendFrame(job, frame)
    if ok then
      tokens = tokens - 1
      job.sent = job.sent + 1
      job.tries = 0
      refusedInRow = 0
      stats.sent = stats.sent + 1
      stats.bytesOut = stats.bytesOut + #frame
      if job.sent >= #job.frames then
        removeJob(lane, 1, nil)
      end
    elseif RETRYABLE[res] then
      stats.retries = stats.retries + 1
      refusedInRow = refusedInRow + 1
      waitUntil = t + RETRY_WAIT[math.min(refusedInRow, #RETRY_WAIT)]
      if res ~= LOCKDOWN then
        job.tries = (job.tries or 0) + 1
        if job.tries >= RETRY_MAX then
          stats.fails = stats.fails + 1
          stats.lastFail = tostring(res)
          removeJob(lane, 1, "failed")
        end
      end
      break
    else
      stats.fails = stats.fails + 1
      stats.lastFail = tostring(res)
      removeJob(lane, 1, res == 12 and "offline" or "failed")
    end
  end
  if queued > 0 then
    schedulePump(math.max(0.05, t < waitUntil and (waitUntil - t) or (1 - tokens) * REFILL))
  end
end

schedulePump = function(delay)
  if pumpScheduled then
    return
  end
  pumpScheduled = true
  C_Timer.After(delay or 0, pump)
end

-- The messages waiting in one lane (diagnostics and tests).
function Comm.Queue(lane)
  return lanes[lane] or {}
end

function Comm.QueueSize()
  return queued
end

function Comm.Held()
  return heldSince ~= nil and (now() - heldSince) or nil
end

-- Sends `body` as message `kind`. dist: GUILD, OFFICER, WHISPER (target: a name), PARTY, RAID.
-- opts.lane: "alert" | "normal" (default) | "bulk"; opts.key: a newer message with the same key
-- replaces one still waiting; opts.done(sent, why); opts.anytime: allowed before consent (never used
-- for anything but the privacy page itself). Returns true when queued, or false and a reason.
function Comm.Send(kind, body, dist, target, opts)
  opts = opts or {}
  if BG.demo then
    return false, "capturas" -- (the capture mode's example guild never reaches anyone: Core/Demo.lua)
  end
  if not opts.anytime and not BG.Consent.Accepted() then
    return false, "consent"
  end
  if not DISTS[dist] then
    return false, "dist"
  end
  if (dist == "GUILD" or dist == "OFFICER") and not IsInGuild() then
    return false, "guild"
  end
  if dist == "WHISPER" and (type(target) ~= "string" or target == "") then
    return false, "target"
  end
  local encoded, why = Serial.Encode(body)
  if not encoded then
    BG:RecordError("enviar " .. tostring(kind), why) -- a message we built and cannot write: our own mistake, kept to fix it
    return false, why
  end
  local payload = kind .. ":" .. encoded
  nextId = (nextId + 1) % 1296
  local frames = Comm.Frames(payload, nextId)
  if #frames > Comm.MAX_PARTS then
    return false, "too-big"
  end
  local lane = lanes[opts.lane] and opts.lane or "normal"
  if opts.key then
    for _, name in ipairs(LANE_ORDER) do
      local list = lanes[name]
      for i = #list, 1, -1 do
        if list[i].key == opts.key and list[i].sent == 0 then
          removeJob(name, i, "replaced")
        end
      end
    end
  end
  if queued >= Comm.MAX_QUEUE then
    local victim = lanes.bulk[1] and "bulk" or (lanes.normal[1] and "normal" or nil)
    if not victim or lane == "bulk" then
      return false, "queue-full"
    end
    removeJob(victim, #lanes[victim], "queue-full")
  end
  local list = lanes[lane]
  list[#list + 1] = {
    kind = kind, dist = dist, target = target, frames = frames, sent = 0, t = now(), key = opts.key, done = opts.done,
    anytime = opts.anytime, guild = (dist == "GUILD" or dist == "OFFICER") and GetGuildInfo("player") or nil,
  }
  queued = queued + 1
  schedulePump(0)
  return true
end

-- Everything waiting is dropped (consent withdrawn, left the guild); each sender hears why.
function Comm.Clear(why)
  for _, name in ipairs(LANE_ORDER) do
    for i = #lanes[name], 1, -1 do
      removeJob(name, i, why or "cleared")
    end
  end
end

BG:On("PLAYER_LOGIN", function()
  if C_ChatInfo and C_ChatInfo.RegisterAddonMessagePrefix then
    C_ChatInfo.RegisterAddonMessagePrefix(Comm.PREFIX)
  end
end)
