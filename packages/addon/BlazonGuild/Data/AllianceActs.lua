-- Acts of the guild that leads the alliance (the rest of entrega 6; ideas of Olympus' Acts.lua (writs, open the
-- gates), Moderation.lua (hiding someone across the network) and War.lua (an operation of the whole army), MIT; our
-- own implementation). An organiser of the leader's guild signs each act with their key, as the calls to arms
-- (AllianceLead.lua). Four kinds:
--   lt  a letter to the masters (or the masters and captains) of every guild; each one marks it read, and the
--       leader's guild sees how many did;
--   hd  someone (or a whole guild) hidden in the alliance's shared chats for a while;
--   dr  the doors: which guild of the alliance takes the new players, for a few hours;
--   op  an operation of the whole alliance: every guild's war room gets it, each member answers in their own guild,
--       and each guild's messenger tells the leader's guild how many go.
-- Each guild keeps the acts in its records (lacts), put there by one of its organisers once the signature checks
-- out, so a member who logs in later gets them like any other record. The leader's guild says the live ones again
-- every quarter of an hour, in case a guild had no organiser online.
local _, BG = ...
local Acts = { counts = {} }
BG.AllianceActs = Acts
local Alliance, Rules, Sign = BG.Alliance, BG.AllianceRules, BG.Sign
local Store, Names, Comm, Serial = BG.Store, BG.Names, BG.Comm, BG.Serial
local str = BG.Raids.Clean
local has = Alliance.Has

local KEEP = { lt = 30 * 86400, hd = 30 * 86400, dr = 2 * 86400, op = 14 * 86400 }
local RESEND_EVERY = 15 * 60
local COUNT_EVERY = 30
local MAX_X = 900
local MAX_TEXT = 400
local noop = function() end

local function myKey()
  return BG.Guild.info and BG.Guild.info.key or nil
end

-- What an act's signature signs.
function Rules.ActText(allianceId, b)
  return table.concat({ "BGL1", allianceId, b.i, b.k, b.f, b.g, tostring(math.floor(tonumber(b.at) or 0)), tostring(math.floor(tonumber(b.v) or 0)), b.x or "" }, "\031")
end

local function short(s, max)
  return type(s) == "string" and #s > 0 and #s <= max and s or nil
end

-- The signed act, as it travels and as each guild keeps it.
local function clean(d)
  if type(d) ~= "table" or not KEEP[d.k] then
    return nil
  end
  local out = { a = short(d.a, 40), i = short(d.i, 40), k = d.k, f = short(d.f, 40), g = short(d.g, 80), at = tonumber(d.at), v = math.floor(tonumber(d.v) or 0),
    x = short(d.x, MAX_X), s = short(d.s, 200), p = short(d.p, 120) }
  if not (out.a and out.i and out.f and out.g and out.at and out.v >= 1 and out.x and out.s and out.p) then
    return nil
  end
  return out
end

Store.Define("lacts", {
  ttl = function(r)
    return (r.d and r.d.at or r.at) + (KEEP[r.d and r.d.k] or 86400)
  end,
  can = function(author)
    return Store.IsOrganiser(author)
  end,
  normalize = clean,
})

-- A letter read: id "act|reader", kept by the leader's guild.
Store.Define("lreads", {
  ttl = 30 * 86400,
  can = function(author)
    return Store.IsOrganiser(author)
  end,
  normalize = function(d, r)
    local n = Names.Short(str(d.n, 40))
    if type(d.i) ~= "string" or not n or r.id ~= d.i .. "|" .. n then
      return nil
    end
    return { i = d.i, n = n, g = short(d.g, 80), at = tonumber(d.at) }
  end,
})

-- The payload of an act (what Serial wrote), or nil.
function Acts.Payload(b)
  if not b or type(b.x) ~= "string" then
    return nil
  end
  local ok, p = pcall(Serial.Decode, b.x)
  return ok and type(p) == "table" and p or nil
end

local function live(kind)
  return Store.List("lacts", function(r)
    return r.d.k == kind and Alliance.Doc() ~= nil and r.d.a == Alliance.Doc().id
  end)
end

-- May we (an organiser of the leader's guild, who can sign) issue acts?
function Acts.MayLead()
  return Alliance.AmLeaderGuild() and Alliance.CanSign() and Store.IsOrganiser(Names.Me() or "")
end

function Acts.Spread(b, onlyTo)
  for _, g in ipairs(Alliance.Sisters()) do
    if not onlyTo or g.k == onlyTo then
      Alliance.WhisperGuild("LA", b, g.k, { organisers = true, lane = "normal" })
    end
  end
end

-- Signs and sends an act. id and v to replace an earlier one. done(act) or done(nil, why).
local function issue(kind, payload, id, v, done)
  done = done or noop
  local d = Alliance.Doc()
  if not d then
    return nil, "sin alianza"
  end
  if not Acts.MayLead() then
    return nil, "permiso"
  end
  local x = Serial.Encode(payload)
  if #x > MAX_X then
    return nil, "largo"
  end
  local b = { a = d.id, i = id or Alliance.RandomId(10), k = kind, f = Names.Me(), g = myKey(), at = Store.Now(), v = v or 1, x = x }
  Sign.Sign(Rules.ActText(d.id, b), function(sig, pk)
    if not sig then
      return done(nil, "firma")
    end
    b.s, b.p = sig, pk
    local ok, why = Store.Put("lacts", b.i, b, { lane = "normal" })
    if not ok then
      return done(nil, why)
    end
    Acts.Spread(b)
    BG:Fire("BG_ALLIANCE_CHANGED")
    done(b)
  end)
  return true
end

local function nextVersion(id)
  local old = Store.Get("lacts", id)
  return old and old.d and (old.d.v + 1) or 1
end

local verifying = {}
Comm.Register("LA", function(sender, b, dist)
  local d = Alliance.Doc()
  b = clean(b)
  if not d or not b or b.a ~= d.id then
    return
  end
  local lead = Alliance.LeaderGuild()
  if not lead or b.g ~= lead.k or not has(lead.pk, b.p) or b.g == myKey() then
    return
  end
  if dist == "GUILD" and not BG.Guild.Find(sender) then
    return
  end
  local old = Store.Get("lacts", b.i)
  if old and not old.del and old.d.v >= b.v then
    return
  end
  local key = b.i .. ":" .. b.v
  if verifying[key] then
    return
  end
  verifying[key] = true
  Sign.Verify(b.p, Rules.ActText(d.id, b), b.s, function(good)
    verifying[key] = nil
    if not good then
      return
    end
    if Store.IsOrganiser(Names.Me() or "") then
      if Store.Put("lacts", b.i, b, { lane = "normal" }) then
        Acts.Apply(b)
        BG:Fire("BG_ALLIANCE_CHANGED")
      end
    elseif dist == "WHISPER" then
      Comm.Send("LA", b, "GUILD", nil, { lane = "normal" }) -- an organiser of ours keeps it for the guild
    end
  end)
end, { channels = { "WHISPER", "GUILD" }, maxBytes = 1800 })

-- Letters -------------------------------------------------------------------------------------------------------------
-- Who reads a letter: the masters, and the captains when it is for them too; the leader's organisers see theirs.
function Acts.CanRead(b, p)
  local me = Names.Me() or ""
  if b.g == myKey() and Store.IsOrganiser(me) then
    return true
  end
  return Store.IsMaster(me) or (p and p.c == 1 and Alliance.Cargo(me) == "cap")
end

function Acts.Letter(title, text, toCaptains, done)
  title, text = str(title, 60), str(text, MAX_TEXT)
  if not title or title == "" or not text or text == "" then
    return nil, "vacío"
  end
  return issue("lt", { t = title, x = text, c = toCaptains and 1 or nil }, nil, 1, done)
end

local function readKey()
  local e = BG.Guild.Entry()
  if not e then
    return {}
  end
  e.lettersRead = e.lettersRead or {}
  return e.lettersRead
end

function Acts.Readers(id)
  local prefix = id .. "|"
  return Store.List("lreads", function(r)
    return r.id:sub(1, #prefix) == prefix
  end)
end

-- The letters this player may read, newest first: { id, title, text, from, guild, at, read, mine, readers, captains }.
function Acts.Letters()
  local out = {}
  for _, r in ipairs(live("lt")) do
    local p = Acts.Payload(r.d)
    if p and Acts.CanRead(r.d, p) then
      local g = Alliance.Guild(r.d.g)
      out[#out + 1] = { id = r.d.i, title = str(p.t, 60) or "", text = str(p.x, MAX_TEXT) or "", from = r.d.f, guild = g and g.n or "?", at = r.d.at,
        read = readKey()[r.d.i] == true, mine = r.d.g == myKey(), readers = #Acts.Readers(r.d.i), captains = p.c == 1 }
    end
  end
  table.sort(out, function(a, b)
    return a.at > b.at
  end)
  return out
end

function Acts.Unread()
  local n = 0
  for _, l in ipairs(Acts.Letters()) do
    if not l.read and not l.mine then
      n = n + 1
    end
  end
  return n
end

function Acts.MarkRead(id)
  local r = Store.Get("lacts", id)
  if not r or r.del then
    return nil, "no existe"
  end
  readKey()[id] = true
  local body = { a = r.d.a, i = id, n = Names.Me(), g = myKey(), at = Store.Now() }
  if r.d.g == myKey() then
    if Store.IsOrganiser(Names.Me() or "") then
      Store.Put("lreads", id .. "|" .. body.n, body)
    else
      Comm.Send("LK", body, "GUILD", nil, { lane = "normal" })
    end
  else
    Alliance.WhisperGuild("LK", body, r.d.g, { organisers = true, lane = "normal" })
  end
  BG:Fire("BG_ALLIANCE_CHANGED")
  return true
end

Comm.Register("LK", function(sender, b, dist)
  local d = Alliance.Doc()
  if not d or type(b) ~= "table" or b.a ~= d.id or type(b.i) ~= "string" then
    return
  end
  local r = Store.Get("lacts", b.i)
  if not r or r.del or r.d.g ~= myKey() then
    return
  end
  local n = Names.Short(str(b.n, 40))
  if not n or not (Names.Same(sender, n) or (dist == "GUILD" and BG.Guild.Find(sender))) then
    return
  end
  if Store.IsOrganiser(Names.Me() or "") then
    if not Store.Get("lreads", b.i .. "|" .. n) then
      Store.Put("lreads", b.i .. "|" .. n, { i = b.i, n = n, g = b.g, at = Store.Now() })
      BG:Fire("BG_ALLIANCE_CHANGED")
    end
  elseif dist == "WHISPER" then
    Comm.Send("LK", b, "GUILD", nil, { lane = "normal" })
  end
end, { channels = { "WHISPER", "GUILD" }, maxBytes = 300 })

-- Hidden in the alliance's chats ---------------------------------------------------------------------------------
-- target: a player's name, or a guild's key (one of the alliance's, not the leader's). hours: how long.
function Acts.Hide(target, hours, why, done)
  local p = { u = Store.Now() + math.floor((tonumber(hours) or 24) * 3600), w = str(why, 80) }
  if Alliance.Member(target) then
    if target == myKey() then
      return nil, "la tuya"
    end
    p.g = target
  else
    p.n = Names.Short(str(target, 40))
    if not p.n or p.n == "" then
      return nil, "sin nombre"
    end
  end
  return issue("hd", p, nil, 1, done)
end

function Acts.Unhide(id, done)
  local r = Store.Get("lacts", id)
  local p = r and not r.del and Acts.Payload(r.d)
  if not p then
    return nil, "no existe"
  end
  p.u = Store.Now()
  return issue("hd", p, id, nextVersion(id), done)
end

-- The hidden ones now: { id, name or guild key, label, until, why }.
function Acts.Hidden()
  local out, now = {}, Store.Now()
  for _, r in ipairs(live("hd")) do
    local p = Acts.Payload(r.d)
    if p and tonumber(p.u) and p.u > now then
      local g = p.g and Alliance.Guild(p.g)
      out[#out + 1] = { id = r.d.i, n = p.n, g = p.g, label = p.n or (g and g.n) or "?", ["until"] = p.u, why = p.w }
    end
  end
  table.sort(out, function(a, b)
    return a["until"] < b["until"]
  end)
  return out
end

-- Is this line's author (or their guild) hidden in the alliance's chats?
function Acts.IsHidden(name, guildKey)
  for _, h in ipairs(Acts.Hidden()) do
    if (h.n and Names.Same(h.n, name)) or (h.g and h.g == guildKey) then
      return true
    end
  end
  return false
end

-- The doors --------------------------------------------------------------------------------------------------------
local function doorsId()
  local d = Alliance.Doc()
  return d and ("doors-" .. d.id:sub(1, 12)) or "doors"
end

function Acts.OpenDoors(k, hours, done)
  if not Alliance.Member(k) then
    return nil, "no existe"
  end
  local id = doorsId()
  return issue("dr", { to = k, u = Store.Now() + math.floor((tonumber(hours) or 2) * 3600) }, id, nextVersion(id), done)
end

function Acts.CloseDoors(done)
  local id = doorsId()
  return issue("dr", { u = Store.Now() }, id, nextVersion(id), done)
end

-- Where the alliance sends new players now: { k, name, until } or nil.
function Acts.Doors()
  local r = Store.Get("lacts", doorsId())
  local p = r and not r.del and Acts.Payload(r.d)
  if not p or not p.to or not tonumber(p.u) or p.u <= Store.Now() then
    return nil
  end
  local g = Alliance.Guild(p.to)
  return g and { k = p.to, name = g.n, ["until"] = p.u } or nil
end

-- Operations of the whole alliance (War.lua keeps each one in every guild's war room) -----------------------------
function Acts.IssueOp(op, done)
  local p = { title = op.d.title, kind = op.d.kind, start = op.d.start, place = op.d.place, note = op.d.note, leader = op.d.leader, status = op.d.status }
  local id = op.d.ally and op.d.ally.i or ("op-" .. Alliance.RandomId(8))
  return issue("op", p, id, nextVersion(id), done), id
end

-- A sister guild's copy of the operation in our war room (an organiser of ours puts it).
function Acts.Apply(b)
  if b.k ~= "op" then
    return
  end
  local p = Acts.Payload(b)
  if not p then
    return
  end
  local g = Alliance.Guild(b.g)
  BG.War.PutAllyOp("ally-" .. b.i, p, { g = b.g, n = g and g.n or "?", i = b.i })
end

-- How many go, per sister guild, to one of our alliance operations: { [guild key] = { y, m, n, name } }.
function Acts.Counts(actId)
  return Acts.counts[actId] or {}
end

Comm.Register("LC", function(sender, b, dist)
  local d = Alliance.Doc()
  if not d or type(b) ~= "table" or b.a ~= d.id or type(b.i) ~= "string" or type(b.g) ~= "string" then
    return
  end
  local r = Store.Get("lacts", b.i)
  if not r or r.del or r.d.g ~= myKey() or not Alliance.Member(b.g) or b.g == myKey() then
    return
  end
  if dist == "GUILD" and not BG.Guild.Find(sender) then
    return
  end
  if dist == "WHISPER" then
    local from = Alliance.GuildOfName(sender)
    if not from or from.k ~= b.g then
      return -- a guild's numbers come from someone of that guild
    end
  end
  local g = Alliance.Guild(b.g)
  Acts.counts[b.i] = Acts.counts[b.i] or {}
  Acts.counts[b.i][b.g] = { y = math.floor(tonumber(b.y) or 0), m = math.floor(tonumber(b.m) or 0), n = math.floor(tonumber(b.n) or 0), name = g and g.n or "?" }
  if dist == "WHISPER" then
    Comm.Send("LC", b, "GUILD", nil, { lane = "bulk" })
  end
  BG:Fire("BG_WAR_CHANGED")
end, { channels = { "WHISPER", "GUILD" }, maxBytes = 300 })

-- Upkeep ---------------------------------------------------------------------------------------------------------------
local lastResend, lastCount, sentCounts = -math.huge, -math.huge, {}

local function onDuty()
  -- (of the leader guild's organisers online who can sign, the first by name says the acts again)
  for _, p in ipairs(BG.Peers.Active()) do
    if Store.IsOrganiser(p.name) and Alliance.PublishedKey(p.name) then
      return Names.IsMe(p.name)
    end
  end
  return Names.IsMe(Names.Me())
end

function Acts.Upkeep()
  local d = Alliance.Doc()
  if not (d and BG.Consent.Accepted() and BG.Guild.info and not BG.Guild.fromCache) then
    return
  end
  local t = GetTime()
  if Acts.MayLead() and onDuty() and t - lastResend >= RESEND_EVERY then
    lastResend = t
    for _, r in ipairs(Store.List("lacts", function(r)
      return r.d.a == d.id and r.d.g == myKey()
    end)) do
      Acts.Spread(r.d)
    end
  end
  if Alliance.AmMessenger() and t - lastCount >= COUNT_EVERY then
    lastCount = t
    for _, op in ipairs(BG.War.Ops()) do
      local ally = op.d.ally
      if ally and not ally.lead and (op.d.status == "PLANNED" or op.d.status == "ACTIVE") then
        local c = BG.War.Count(op.id)
        local sig = c.GO .. "/" .. c.MAYBE .. "/" .. c.NO
        if sentCounts[op.id] ~= sig then
          sentCounts[op.id] = sig
          Alliance.WhisperGuild("LC", { a = d.id, i = ally.i, g = myKey(), y = c.GO, m = c.MAYBE, n = c.NO }, ally.g, { lane = "bulk" })
        end
      end
    end
  end
end

local function tick()
  local ok, err = pcall(Acts.Upkeep)
  if not ok then
    BG:RecordError("alliance acts", err)
  end
  C_Timer.After(10, tick)
end
BG:On("PLAYER_LOGIN", function()
  C_Timer.After(30, tick)
end)

BG:On("BG_STORE_CHANGED", function(name)
  if name == "lacts" or name == "lreads" then
    BG:Fire("BG_ALLIANCE_CHANGED")
  end
end)
