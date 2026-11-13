-- The guild's shared records (raids, signups, groups, flags...), kept by every member's addon and synchronised
-- through Comm. Same shape as the web's tables so the companion app can upload them as they are (ADR-016).
--
--   record = { id, rev, at, by, del, exp, d }
--     id   unique within its collection        rev  edit counter (higher wins)
--     at   server time of the edit (GetServerTime)   by  author ("First Surname")
--     del  true once deleted (kept until exp so the deletion spreads)   exp  server time it expires
--     d    the data itself (a table)
--
-- Live: every edit goes out at once as "RC" over GUILD. Catch-up: after login a member asks the guild's
-- messenger (Peers.lua) with "SQ" and gets the records it missed by whisper ("SA"), from the next candidate
-- if the messenger does not answer. Trust: a record is accepted when its author may write it (each
-- collection's `can` rule, checked against the live roster) and it comes from the author, an organiser
-- (Store.IsOrganiser) or the elected messenger. Signed records arrive in the alliance delivery (ADR-017).
local _, BG = ...
local Store = { collections = {} }
BG.Store = Store
local Comm, Names = BG.Comm, BG.Names

local SYNC_WAIT = 20 -- seconds before asking the next candidate
local SYNC_TRIES = 3
local SA_BATCH = 24 -- records per catch-up message
local DEL_KEEP = 7 * 86400

function Store.Now()
  return GetServerTime and GetServerTime() or time()
end

-- Rank rule: the guild master (rank 0) and the ranks the guild marks as organisers (default: rank 1).
function Store.OrganiserMax()
  local cfg = Store.Get("cfg", "guild")
  local n = cfg and not cfg.del and tonumber(cfg.d.organiserMax)
  return n or 1
end

function Store.RankOf(name)
  local m = BG.Guild.Find(name)
  return m and m.rankIndex or nil
end

-- The rule as the guild's ranks say. The Store's own work (what it keeps, whom it trusts, what it sends) always
-- uses this one; the screens ask Store.IsOrganiser and Store.IsMaster, which a preview «Ver como miembro»
-- (UI/ViewAs.lua) answers differently for this player alone, so they look as a member's do.
local function realOrganiser(name)
  local r = Store.RankOf(name)
  return r ~= nil and r <= Store.OrganiserMax()
end
Store.RealOrganiser = realOrganiser

function Store.IsOrganiser(name)
  if BG.viewAs and name and Names.IsMe(name) then
    return BG.viewAs == "officer"
  end
  return realOrganiser(name)
end

function Store.IsMaster(name)
  if BG.viewAs and name and Names.IsMe(name) then
    return false
  end
  return Store.RankOf(name) == 0
end

-- def: { ttl = seconds after `at` (or a function(record) -> exp), can = function(author, record, old) -> bool,
--        normalize = function(d) -> d | nil (validates and trims incoming data),
--        private = true: only for the organisers (moderation): it travels by whisper to them and is kept only by them,
--        never on a member's computer }
function Store.Define(name, def)
  Store.collections[name] = def
end

local function bucket(name)
  local g = BG.Guild.Entry()
  if not g then
    return nil
  end
  g.store = g.store or {}
  g.store[name] = g.store[name] or {}
  return g.store[name]
end

function Store.Get(name, id)
  local b = bucket(name)
  return b and b[id] or nil
end

-- Live (not deleted, not expired) records of a collection, as a list.
function Store.List(name, filter)
  local b, out, t = bucket(name), {}, Store.Now()
  for _, r in pairs(b or {}) do
    if not r.del and (not r.exp or r.exp > t) and (not filter or filter(r)) then
      out[#out + 1] = r
    end
  end
  return out
end

local function newer(a, b) -- is a newer than b?
  if not b then
    return true
  end
  if a.rev ~= b.rev then
    return a.rev > b.rev
  end
  if a.at ~= b.at then
    return a.at > b.at
  end
  return tostring(a.by) > tostring(b.by)
end
Store.Newer = newer

local changed = {}
local changeScheduled = false
local function markChanged(name)
  changed[name] = true
  if changeScheduled then
    return
  end
  changeScheduled = true
  C_Timer.After(0.2, function()
    changeScheduled = false
    local list = changed
    changed = {}
    for n in pairs(list) do
      BG:Fire("BG_STORE_CHANGED", n)
    end
  end)
end

-- Validates and stores a record that came from `via` over `channel`. Returns true when it was new and accepted.
-- Over GUILD only our guild's members can speak (the game says so); a whisper can come from anyone, of any guild,
-- so it counts only from a member of ours (by our roster). With the rule below (a member writes only their own
-- records; an organiser or the messenger may pass on others'), nobody of another guild writes in our records.
function Store.Accept(name, r, via, channel)
  local def = Store.collections[name]
  if not def or type(r) ~= "table" or type(r.id) ~= "string" or #r.id > 80 or type(r.by) ~= "string"
    or type(r.rev) ~= "number" or type(r.at) ~= "number" then
    return false, "forma"
  end
  if channel ~= "GUILD" and not BG.Guild.Find(via) then
    return false, "otra hermandad"
  end
  local author = Names.Short(r.by)
  if not author then
    return false, "forma"
  end
  if def.private and not realOrganiser(Names.Me()) then
    return false, "privado"
  end
  local trusted = Names.Same(via, author) or realOrganiser(via) or (BG.Peers.Messenger() ~= nil and Names.Same(via, BG.Peers.Messenger()))
  if not trusted then
    return false, "remitente"
  end
  local b = bucket(name)
  if not b then
    return false, "sin hermandad"
  end
  local old = b[r.id]
  if not newer(r, old) then
    return false, "antiguo"
  end
  local clean = { id = r.id, rev = r.rev, at = r.at, by = author, del = r.del == true or nil }
  if not clean.del then
    if type(r.d) ~= "table" then
      return false, "datos"
    end
    local d = def.normalize and def.normalize(r.d, r) or r.d
    if not d then
      return false, "datos"
    end
    clean.d = d
  end
  if not def.can(author, clean, old) then
    return false, "permiso"
  end
  clean.exp = clean.del and (r.at + DEL_KEEP) or Store.Expiry(def, clean)
  b[r.id] = clean
  markChanged(name)
  BG:Fire("BG_RECORD", name, clean, old) -- one record from someone else (notices react to these)
  return true
end

function Store.Expiry(def, r)
  if type(def.ttl) == "function" then
    return def.ttl(r)
  end
  return def.ttl and (r.at + def.ttl) or nil
end

-- Local edit by us: stamps rev/at/by, stores it and broadcasts it. Returns the record or nil, reason.
function Store.Put(name, id, d, opts)
  opts = opts or {}
  local def = Store.collections[name]
  local me = Names.Me()
  local b = bucket(name)
  if not (def and me and b) then
    return nil, "sin hermandad"
  end
  if not BG.Consent.Accepted() then
    return nil, "consent"
  end
  local old = b[id]
  local r = { id = id, rev = (old and old.rev or 0) + 1, at = Store.Now(), by = me, del = opts.delete or nil, d = not opts.delete and d or nil }
  if not opts.delete and def.normalize then
    r.d = def.normalize(d, r)
    if not r.d then
      return nil, "datos"
    end
  end
  if not def.can(me, r, old) then
    return nil, "permiso"
  end
  r.exp = r.del and (r.at + DEL_KEEP) or Store.Expiry(def, r)
  b[id] = r
  markChanged(name)
  if def.private then
    for _, p in ipairs(BG.Peers.Active()) do
      if not p.me and realOrganiser(p.name) then
        Comm.Send("RO", { c = name, r = r }, "WHISPER", p.name, { lane = opts.lane or "normal", key = "RO:" .. p.name .. ":" .. name .. ":" .. id })
      end
    end
  else
    Comm.Send("RC", { c = name, r = r }, "GUILD", nil, { lane = opts.lane or "normal", key = "RC:" .. name .. ":" .. id })
  end
  return r
end

function Store.Delete(name, id)
  return Store.Put(name, id, nil, { delete = true })
end

function Store.Gc()
  local t = Store.Now()
  local g = BG.Guild.Entry()
  local organiser = realOrganiser(Names.Me())
  for name, b in pairs(g and g.store or {}) do
    for id, r in pairs(b) do
      if r.exp and r.exp < t - 3600 then
        b[id] = nil
      end
    end
    local def = Store.collections[name]
    if not def or (def.private and not organiser) then
      g.store[name] = nil -- (also what versions before 0.19.1 kept on every member's computer)
    end
  end
end

Comm.Register("RC", function(sender, body, channel)
  if type(body) == "table" and type(body.c) == "string" then
    local ok, why = Store.Accept(body.c, body.r, sender, channel)
    if not ok and why ~= "antiguo" then
      BG:Debug("registro " .. body.c .. " de " .. sender .. " rechazado: " .. why)
    end
  end
end, { maxBytes = 4000 })

-- A record only for the organisers, from an organiser of ours.
Comm.Register("RO", function(sender, body)
  if type(body) == "table" and type(body.c) == "string" and Store.collections[body.c] and Store.collections[body.c].private
    and realOrganiser(sender) then
    Store.Accept(body.c, body.r, sender, "WHISPER")
  end
end, { channels = { "WHISPER" }, maxBytes = 4000 })

-- Catch-up ----------------------------------------------------------------------------------------
local sync = nil -- { tries, asked = { name = true }, since }

local function candidates()
  local order = {}
  for _, p in ipairs(BG.Peers.Active()) do
    if not p.me and p.willing ~= false then
      order[#order + 1] = p
    end
  end
  table.sort(order, function(a, b)
    return BG.Peers.Rank(a) < BG.Peers.Rank(b)
  end)
  return order
end

function Store.AskSync()
  if not (BG.Consent.Accepted() and BG.Guild.info) then
    return false
  end
  sync = sync or { tries = 0, asked = {}, since = (BG.Guild.Entry() or {}).syncedAt or 0 }
  if sync.tries >= SYNC_TRIES then
    sync = nil
    return false
  end
  for _, p in ipairs(candidates()) do
    if not sync.asked[p.name] then
      sync.asked[p.name] = true
      sync.tries = sync.tries + 1
      sync.from = p.name
      Comm.Send("SQ", { s = math.max(0, sync.since - 600) }, "WHISPER", p.name, { lane = "normal" })
      -- an organiser also asks another organiser for what only organisers keep (if the first one is not)
      if not sync.private and realOrganiser(Names.Me()) and not realOrganiser(p.name) then
        for _, q in ipairs(candidates()) do
          if realOrganiser(q.name) then
            sync.private = true
            Comm.Send("SQ", { s = math.max(0, sync.since - 600), p = 1 }, "WHISPER", q.name, { lane = "normal" })
            break
          end
        end
      end
      local token = sync
      C_Timer.After(SYNC_WAIT, function()
        if sync == token and not token.done then
          Store.AskSync()
        end
      end)
      return true
    end
  end
  return false
end

Comm.Register("SQ", function(sender, body)
  if not BG.Consent.Accepted() or not BG.Guild.Find(sender) then
    return
  end
  local since = type(body) == "table" and tonumber(body.s) or 0
  local onlyPrivate = type(body) == "table" and body.p == 1
  local organiser = realOrganiser(sender)
  if onlyPrivate and not organiser then
    return
  end
  local g = BG.Guild.Entry()
  local batch, sent = {}, 0
  local function flush(last)
    Comm.Send("SA", { r = batch, last = last or nil }, "WHISPER", sender, { lane = "bulk" })
    sent = sent + 1
    batch = {}
  end
  for name, b in pairs(g and g.store or {}) do
    local def = Store.collections[name]
    if def and (def.private and organiser or not def.private and not onlyPrivate) then
      for _, r in pairs(b) do
        if r.at >= since then
          batch[#batch + 1] = { c = name, r = r }
          if #batch >= SA_BATCH then
            flush(false)
          end
        end
      end
    end
  end
  flush(true)
end, { channels = { "WHISPER" }, maxBytes = 60 })

Comm.Register("SA", function(sender, body)
  if type(body) ~= "table" or type(body.r) ~= "table" or not BG.Guild.Find(sender) then
    return -- (only a member of ours answers our catch-up)
  end
  for _, item in ipairs(body.r) do
    if type(item) == "table" then
      Store.Accept(item.c, item.r, sender, "WHISPER")
    end
  end
  if body.last and sync and Names.Same(sender, sync.from) then
    sync.done = true
    sync = nil
    local entry = BG.Guild.Entry()
    if entry then
      entry.syncedAt = Store.Now()
    end
    BG:Fire("BG_STORE_SYNCED", sender)
  end
end, { channels = { "WHISPER" } })

local asked = false
BG:On("BG_PEERS_CHANGED", function()
  if not asked and BG.Consent.Accepted() and BG.Guild.info and not BG.Guild.fromCache and #candidates() > 0 then
    asked = true
    C_Timer.After(3, Store.AskSync)
  end
end)
BG:On("BG_CONSENT_CHANGED", function(on)
  if not on then
    asked = false
  end
end)
BG:On("PLAYER_LOGIN", function()
  C_Timer.After(30, Store.Gc)
end)
