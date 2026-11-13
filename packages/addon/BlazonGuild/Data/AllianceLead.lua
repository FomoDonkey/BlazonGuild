-- The alliance's leadership (ADR-020, the second part of entrega 6). The leader is the master of the guild most
-- masters voted for (more than half; the founder's guild until then). The leader's guild may take a guild out,
-- give the alliance a new key and call the whole alliance to arms; each master names their guild's captains
-- (they read and write the organisers' tab) and messengers (they carry the messages between guilds); an
-- organiser may hide from the other guilds that they are online. Every change goes into the signed record
-- (Alliance.Commit), and what travels on its own (a call to arms, "your guild is out") carries a signature too.
local _, BG = ...
local Alliance, Rules, Sign = BG.Alliance, BG.AllianceRules, BG.Sign
local Store, Names, Comm, Peers = BG.Store, BG.Names, BG.Comm, BG.Peers
local str = BG.Raids.Clean
local has = Alliance.Has

Alliance.REFRESH_EVERY = 300 -- how often a signer checks that our guild's list of signers is current
local CALL_FRESH = 300 -- a call to arms older than this is not shown
local noop = function() end

local function myKey()
  return BG.Guild.info and BG.Guild.info.key or nil
end

local function isMaster()
  return Store.IsMaster(Names.Me())
end

-- Votes -------------------------------------------------------------------------------------------------------
-- Our master votes for a guild (ours or a sister) to lead. done(doc) or done(nil, why).
function Alliance.Vote(k, done)
  done = done or noop
  if not isMaster() then
    return nil, "permiso"
  end
  if not Alliance.Doc() then
    return nil, "sin alianza"
  end
  if not Alliance.Member(k) then
    return nil, "no existe"
  end
  if not Alliance.CanSign() then
    return nil, "firma"
  end
  return Alliance.UpdateMine(function(e)
    e.vote = k
    return e
  end, done, function(why)
    done(nil, why)
  end)
end

-- The guild our master voted for, or nil.
function Alliance.VoteOf(k)
  local g = Alliance.Guild(k)
  return g and g.vote or nil
end

-- The leader's guild ---------------------------------------------------------------------------------------------
local function leaderMay()
  return Alliance.AmLeaderGuild() and Alliance.CanSign()
end

function Alliance.AmLeader()
  return leaderMay() and isMaster()
end

-- A new key for the alliance (a guild left knowing the old one, or it leaked). done(doc) or done(nil, why).
function Alliance.NewKey(done)
  done = done or noop
  if not leaderMay() or not Store.IsOrganiser(Names.Me()) then
    return nil, "permiso"
  end
  return Alliance.CommitCore(function(new)
    new.key = Alliance.RandomId(16)
    new.kr = nil
    return new
  end, function(doc)
    Alliance.TellSisters(doc)
    done(doc)
  end, function(why)
    done(nil, why)
  end)
end

-- The leader takes guild `k` out of the alliance: the record goes on without it, with a new key, and that guild
-- gets a signed "you are out" (AX). done(doc) or done(nil, why).
function Alliance.Expel(k, done)
  done = done or noop
  if not Alliance.AmLeader() then
    return nil, "permiso"
  end
  local g = Alliance.Guild(k)
  if not g or k == myKey() then
    return nil, "no existe"
  end
  -- Who to tell, while the record still has them: their organisers online first, then their contacts.
  local targets = {}
  for _, n in ipairs(Alliance.Contacts(k)) do
    if #targets < 3 then
      targets[#targets + 1] = n
    end
  end
  return Alliance.CommitCore(function(new)
    for i = #new.guilds, 1, -1 do
      if new.guilds[i].k == k then
        table.remove(new.guilds, i)
      end
    end
    new.key = Alliance.RandomId(16)
    new.kr = nil
    return new
  end, function(doc)
    Alliance.TellSisters(doc)
    Sign.Sign(Rules.OutText(doc.id, k, doc.v), function(sig, pk)
      if sig then
        for _, n in ipairs(targets) do
          Comm.Send("AX", { a = doc.id, g = k, v = doc.v, s = sig, p = pk }, "WHISPER", n, { lane = "alert" })
        end
      end
    end)
    Alliance.presence[k] = nil
    done(doc)
  end, function(why)
    done(nil, why)
  end)
end

Comm.Register("AX", function(sender, b, dist)
  local d = Alliance.Doc()
  if not d or type(b) ~= "table" or b.a ~= d.id or b.g ~= myKey() or (tonumber(b.v) or 0) <= d.v then
    return
  end
  local lead = Alliance.LeaderGuild()
  if not lead or lead.k == myKey() or not has(lead.pk, b.p) then
    return
  end
  if not Store.IsOrganiser(Names.Me()) then
    if dist == "WHISPER" then
      Comm.Send("AX", b, "GUILD", nil, { lane = "alert" }) -- our organisers check it and act
    end
    return
  end
  Sign.Verify(b.p, Rules.OutText(d.id, b.g, b.v), b.s, function(good)
    local now = Alliance.Doc()
    if not good or not now or now.id ~= d.id then
      return
    end
    wipe(Alliance.presence)
    Store.Delete("alliance", "main")
    BG:Notify("Fuera de la alianza", "El líder de «" .. d.name .. "» ha sacado a " .. (BG.Guild.info and BG.Guild.info.name or "vuestra hermandad") .. " de la alianza.",
      { kind = "warning", view = "alliance" })
  end)
end, { channels = { "WHISPER", "GUILD" }, maxBytes = 400 })

-- Cargos ---------------------------------------------------------------------------------------------------------
-- Our master names `name` (a member of our guild) captain ("cap") or messenger ("msg"), or takes the cargo away
-- (cargo nil). done(doc) or done(nil, why).
function Alliance.SetCargo(name, cargo, done)
  done = done or noop
  if not isMaster() then
    return nil, "permiso"
  end
  if not Alliance.Doc() then
    return nil, "sin alianza"
  end
  local m = BG.Guild.Find(str(name, 40) or "")
  if not m then
    return nil, "no es de tu hermandad"
  end
  if cargo and not Alliance.CARGOS[cargo] then
    return nil, "cargo"
  end
  if not Alliance.CanSign() then
    return nil, "firma"
  end
  local short = Names.Short(m.name)
  return Alliance.UpdateMine(function(g)
    for i = #g.r, 1, -1 do
      if g.r[i].n == short then
        table.remove(g.r, i)
      end
    end
    if cargo then
      if #g.r >= 12 then
        return nil, "llena"
      end
      g.r[#g.r + 1] = { n = short, c = cargo }
    end
    return g
  end, done, function(why)
    done(nil, why)
  end)
end

-- Hidden presence --------------------------------------------------------------------------------------------------
function Alliance.MayHide()
  return Store.IsOrganiser(Names.Me() or "")
end

function Alliance.SetHidden(on)
  local me = Names.Me()
  if not me then
    return nil, "sin hermandad"
  end
  if on and not Alliance.MayHide() then
    return nil, "permiso"
  end
  BG.db.allyHidden = BG.db.allyHidden or {}
  BG.db.allyHidden[me] = on and true or nil
  Peers.SayHello() -- our guild learns it now (who is hidden is never told to the other guilds)
  BG:Fire("BG_ALLIANCE_CHANGED")
  return true
end

-- Calls to arms of the whole alliance -------------------------------------------------------------------------
local callSeen = {}

local function showCall(b)
  local d = Alliance.Doc()
  local g = Alliance.Guild(b.g)
  BG.Board.ShowDecree(b.f .. (g and (", de " .. g.n) or ""), { k = b.k, t = b.t, al = d and d.name })
end

-- The leader's guild calls everyone in the alliance. done(true) or done(nil, why).
function Alliance.Call(kind, text, done)
  done = done or noop
  local d = Alliance.Doc()
  if not d then
    return nil, "sin alianza"
  end
  if not leaderMay() or not Store.IsOrganiser(Names.Me()) then
    return nil, "permiso"
  end
  local b = { a = d.id, i = Alliance.RandomId(10), k = kind == "RALLY" and "RALLY" or "ARMS", t = str(text, 100) or "", f = Names.Me(), g = myKey(), at = Store.Now() }
  Sign.Sign(Rules.CallText(d.id, b), function(sig, pk)
    if not sig then
      return done(nil, "firma")
    end
    b.s, b.p = sig, pk
    callSeen[b.i] = true
    showCall(b)
    Comm.Send("AK", b, "GUILD", nil, { lane = "alert" })
    for _, g in ipairs(Alliance.Sisters()) do
      Alliance.WhisperGuild("AK", b, g.k, { lane = "alert" })
    end
    done(true)
  end)
  return true
end

Comm.Register("AK", function(sender, b, dist)
  local d = Alliance.Doc()
  if not d or type(b) ~= "table" or b.a ~= d.id or type(b.i) ~= "string" or #b.i > 16 or callSeen[b.i] then
    return
  end
  if type(b.t) ~= "string" or #b.t > 100 or type(b.f) ~= "string" or #b.f > 40 or (b.k ~= "ARMS" and b.k ~= "RALLY") then
    return
  end
  local lead = Alliance.LeaderGuild()
  if not lead or b.g ~= lead.k or not has(lead.pk, b.p) or math.abs(Store.Now() - (tonumber(b.at) or 0)) > CALL_FRESH then
    return
  end
  callSeen[b.i] = true
  Sign.Verify(b.p, Rules.CallText(d.id, b), b.s, function(good)
    if not good then
      callSeen[b.i] = nil
      return
    end
    showCall(b)
    if dist == "WHISPER" and b.g ~= myKey() then
      Comm.Send("AK", b, "GUILD", nil, { lane = "alert" }) -- the rest of our guild
    end
  end)
end, { channels = { "WHISPER", "GUILD" }, maxBytes = 600 })

-- Upkeep (every tick of Alliance.lua) ------------------------------------------------------------------------------
local lastRefresh, lastRotate, lastPublish = -math.huge, -math.huge, -math.huge

-- Of our signers online, the first by name does what only one should (a new key, a new anchor).
local function onDuty()
  local g = Alliance.Guild(myKey())
  for _, p in ipairs(Peers.Active()) do
    local pk = Alliance.PublishedKey(p.name)
    if pk and g and has(g.pk, pk) and Store.IsOrganiser(p.name) then
      return Names.IsMe(p.name)
    end
  end
  return false
end

function Alliance.Upkeep()
  if not (BG.Consent.Accepted() and BG.Guild.info and not BG.Guild.fromCache) then
    return
  end
  local me = Names.Me()
  if not me or not Store.IsOrganiser(me) then
    return
  end
  local d = Alliance.Doc()
  if not d and #Alliance.Invitations() == 0 then
    return
  end
  local pk = Sign.MyKey()
  if not pk then
    Sign.Ensure()
    return
  end
  -- Our public key, for whoever certifies our guild's signers.
  local t = GetTime()
  local r = Store.Get("skeys", me)
  if (not r or r.del or r.d.p ~= pk) and t - lastPublish > 60 then
    lastPublish = t
    Store.Put("skeys", me, { p = pk })
  end
  if not d then
    return
  end
  -- A guild left knowing the key: the leader's guild gives the alliance a new one.
  if d.kr and leaderMay() and onDuty() and t - lastRotate > 60 then
    lastRotate = t
    Alliance.NewKey()
    return
  end
  -- Our list of signers follows our organisers: the anchor adds and removes keys; a new master's key becomes
  -- the anchor through any key the list had.
  if t - lastRefresh >= Alliance.REFRESH_EVERY then
    lastRefresh = t
    local g = Alliance.Guild(myKey())
    local want = Alliance.WantedSigners(pk)
    if g and #want > 0 and table.concat(g.pk, ",") ~= table.concat(want, ",") then
      local may = (want[1] == g.pk[1] and pk == g.pk[1]) or (want[1] ~= g.pk[1] and has(g.pk, pk) and onDuty())
      if may then
        Alliance.UpdateMine(function(e)
          return e
        end)
      end
    end
  end
end

-- Notices: a new leader, a guild that left.
BG:On("BG_RECORD", function(kind, r, old)
  if kind ~= "alliance" or not (r.d and old and old.d) then
    return
  end
  local lead, before = Rules.Lead(r.d), Rules.Lead(old.d)
  if lead and lead ~= before then
    local g = Alliance.Guild(lead)
    if g then
      BG:Notify("Nuevo líder de la alianza", (g.m or "El maestro") .. ", de " .. g.n .. ", lidera ahora «" .. r.d.name .. "».", { kind = "info", view = "alliance" })
    end
  end
  local now = {}
  for _, g in ipairs(r.d.guilds) do
    now[g.k] = true
  end
  for _, g in ipairs(old.d.guilds) do
    if not now[g.k] and g.k ~= myKey() then
      BG:Notify("Una hermandad sale de la alianza", g.n .. " ya no está en «" .. r.d.name .. "».", { kind = "info", view = "alliance" })
    end
  end
end)
