-- Guild raids from the game: organisers create them, members sign up with a role, organisers plan groups and
-- the bench and invite everyone confirmed. Shapes mirror the web's `raids`, `raid_signups` (status, role,
-- comment, groupNo) so the companion app can upload them as they are.
local _, BG = ...
local Raids = {}
BG.Raids = Raids
local Store, Names, Instances = BG.Store, BG.Names, BG.Instances

local STATUSES = { CONFIRMED = true, TENTATIVE = true, DECLINED = true }
local RAID_STATES = { SCHEDULED = true, CANCELLED = true, IN_PROGRESS = true, COMPLETED = true }

local function str(v, max)
  if type(v) ~= "string" then
    return nil
  end
  v = v:gsub("[%c|]", ""):gsub("^%s+", ""):gsub("%s+$", "")
  if #v > max then
    v = v:sub(1, max):gsub("[\192-\255][\128-\191]*$", "") -- never end on half a letter
  end
  return v
end
Raids.Clean = str

local function int(v, lo, hi)
  v = tonumber(v)
  if not v then
    return nil
  end
  v = math.floor(v)
  return math.max(lo, math.min(hi, v))
end
Raids.Int = int

local function need(t, size)
  local base = Instances.Composition(size or 40)
  t = type(t) == "table" and t or {}
  return { TANK = int(t.TANK, 0, 40) or base.TANK, HEALER = int(t.HEALER, 0, 40) or base.HEALER, DPS = int(t.DPS, 0, 40) or base.DPS }
end

Store.Define("cfg", {
  can = function(author)
    return Store.IsMaster(author)
  end,
  normalize = function(d)
    return { organiserMax = int(d.organiserMax, 0, 9) or 1 }
  end,
})

Store.Define("raids", {
  ttl = function(r)
    return (r.d and r.d.start or r.at) + 2 * 86400
  end,
  -- Any member may create raids for whoever wants to join (Peregrino, 2026-11-12: "entre miembros de la guild
  -- quieran hacer los suyos"). Its creator and its leader manage it; organisers manage every raid. A raid's id
  -- starts with its creator's name, so nobody can overwrite someone else's raid by reusing its id.
  can = function(author, r, old)
    if Store.IsOrganiser(author) then
      return true
    end
    local prefix = author:gsub("%s", "") .. "-"
    local mine = r.id:sub(1, #prefix) == prefix
    if old and not old.del then
      return mine or Names.Same(old.d and old.d.leader, author)
    end
    return mine and BG.Guild.Find(author) ~= nil
  end,
  normalize = function(d)
    local inst = Instances.Raid(d.inst)
    local start = tonumber(d.start)
    if not inst or not start then
      return nil
    end
    local cap = int(d.cap, 5, 40) or inst.size
    return {
      title = str(d.title, 60) ~= "" and str(d.title, 60) or inst.name,
      inst = inst.key, start = math.floor(start), cap = cap, minLevel = int(d.minLevel, 1, 60),
      note = str(d.note, 200), leader = Names.Short(str(d.leader, 40)), status = RAID_STATES[d.status] and d.status or "SCHEDULED",
      need = need(d.need, cap),
    }
  end,
})

Store.Define("signups", {
  ttl = function(r)
    local raid = r.d and Store.Get("raids", r.d.raid)
    return raid and raid.exp or (r.at + 14 * 86400)
  end,
  can = function(author, r)
    return Names.Same(r.id:match("|(.+)$"), author) -- only the player signs up or withdraws
  end,
  normalize = function(d, r)
    if type(d.raid) ~= "string" or not STATUSES[d.status] or not Instances.Role(d.role) then
      return nil
    end
    local name = Names.Short(str(d.name, 40))
    if not name or r.id ~= d.raid .. "|" .. name then
      return nil
    end
    return { raid = d.raid, name = name, status = d.status, role = d.role, note = str(d.note, 120), class = str(d.class, 12), level = int(d.level, 1, 60) }
  end,
})

-- One planning record per raid, written by organisers: group per player (1-8), their row in it (1-5, optional: the
-- plan's own order, which the game's raid frame does not take), and the bench.
Store.Define("plans", {
  ttl = function(r)
    local raid = Store.Get("raids", r.id)
    return raid and raid.exp or (r.at + 14 * 86400)
  end,
  can = function(author, r)
    local raid = Store.Get("raids", r.id)
    local prefix = author:gsub("%s", "") .. "-"
    return Store.IsOrganiser(author) or (raid and raid.d and Names.Same(raid.d.leader, author)) or r.id:sub(1, #prefix) == prefix
  end,
  normalize = function(d)
    local g, bench = {}, {}
    local n = 0
    for name, group in pairs(type(d.g) == "table" and d.g or {}) do
      n = n + 1
      if n > 60 then
        break
      end
      local short, grp = Names.Short(str(name, 40)), int(group, 1, 8)
      if short and grp then
        g[short] = grp
      end
    end
    n = 0
    for name, on in pairs(type(d.bench) == "table" and d.bench or {}) do
      n = n + 1
      if n > 60 then
        break
      end
      local short = Names.Short(str(name, 40))
      if short and on then
        bench[short] = true
      end
    end
    local rows = {}
    n = 0
    for name, row in pairs(type(d.s) == "table" and d.s or {}) do
      n = n + 1
      if n > 60 then
        break
      end
      local short, r = Names.Short(str(name, 40)), int(row, 1, 5)
      if short and r and g[short] then
        rows[short] = r
      end
    end
    return { g = g, bench = bench, s = rows }
  end,
})

-- Queries ----------------------------------------------------------------------------------------
function Raids.Upcoming()
  local t = Store.Now()
  local list = Store.List("raids", function(r)
    return r.d.start > t - 6 * 3600
  end)
  table.sort(list, function(a, b)
    return a.d.start < b.d.start
  end)
  return list
end

function Raids.Get(id)
  local r = Store.Get("raids", id)
  return r and not r.del and r or nil
end

function Raids.Signups(raidId)
  local list = Store.List("signups", function(r)
    return r.d.raid == raidId
  end)
  table.sort(list, function(a, b)
    return a.d.name < b.d.name
  end)
  return list
end

function Raids.MySignup(raidId)
  local me = Names.Me()
  local r = me and Store.Get("signups", raidId .. "|" .. me)
  return r and not r.del and r or nil
end

function Raids.Plan(raidId)
  local p = Store.Get("plans", raidId)
  local d = (p and not p.del and p.d) or { g = {}, bench = {} }
  d.s = d.s or {}
  return d
end

-- Counts for the composition panel: confirmed (not benched) per role, tentative, declined, benched.
function Raids.Counts(raidId)
  local plan = Raids.Plan(raidId)
  local c = { TANK = 0, HEALER = 0, DPS = 0, confirmed = 0, tentative = 0, declined = 0, bench = 0 }
  for _, s in ipairs(Raids.Signups(raidId)) do
    if s.d.status == "CONFIRMED" then
      if plan.bench[s.d.name] then
        c.bench = c.bench + 1
      else
        c.confirmed = c.confirmed + 1
        c[s.d.role] = c[s.d.role] + 1
      end
    elseif s.d.status == "TENTATIVE" then
      c.tentative = c.tentative + 1
    else
      c.declined = c.declined + 1
    end
  end
  return c
end

function Raids.CanManage(raid)
  local me = Names.Me()
  if not me or not raid then
    return false
  end
  local prefix = me:gsub("%s", "") .. "-"
  return Store.IsOrganiser(me) or Names.Same(raid.d and raid.d.leader, me) or raid.id:sub(1, #prefix) == prefix
end

function Raids.CanCreate()
  return Names.Me() ~= nil and BG.Guild.me ~= nil
end

function Raids.IsOrganiser()
  local me = Names.Me()
  return me ~= nil and Store.IsOrganiser(me)
end

-- Edits ------------------------------------------------------------------------------------------
function Raids.Save(id, fields)
  local me = Names.Me()
  if not me then
    return nil, "sin personaje"
  end
  id = id or (me:gsub("%s", "") .. "-" .. Store.Now() .. "-" .. math.random(100, 999))
  local old = Raids.Get(id)
  local d = {}
  for k, v in pairs(old and old.d or {}) do
    d[k] = v
  end
  for k, v in pairs(fields) do
    d[k] = v
  end
  d.leader = d.leader or me
  return Store.Put("raids", id, d)
end

function Raids.Cancel(id)
  return Raids.Save(id, { status = "CANCELLED" })
end

-- Takes a raid off the list for everyone (its creator, its leader or an organiser).
function Raids.Delete(id)
  local raid = Raids.Get(id)
  if not raid or not Raids.CanManage(raid) then
    return nil, "permiso"
  end
  return Store.Delete("raids", id)
end

function Raids.SignUp(raidId, status, role, note)
  local me = Names.Me()
  local m = BG.Guild.me
  if not me then
    return nil, "sin personaje"
  end
  return Store.Put("signups", raidId .. "|" .. me, {
    raid = raidId, name = me, status = status, role = role, note = note,
    class = m and m.classFile, level = m and m.level or UnitLevel("player"),
  }, { lane = "alert" })
end

function Raids.SetGroup(raidId, name, group)
  local plan = Raids.Plan(raidId)
  local g, bench = {}, {}
  for k, v in pairs(plan.g) do
    g[k] = v
  end
  for k, v in pairs(plan.bench) do
    bench[k] = v
  end
  g[name] = group
  return Store.Put("plans", raidId, { g = g, bench = bench, s = Raids.Plan(raidId).s })
end

function Raids.SetBench(raidId, name, on)
  local plan = Raids.Plan(raidId)
  local g, bench = {}, {}
  for k, v in pairs(plan.g) do
    g[k] = v
  end
  for k, v in pairs(plan.bench) do
    bench[k] = v
  end
  bench[name] = on and true or nil
  return Store.Put("plans", raidId, { g = g, bench = bench, s = Raids.Plan(raidId).s })
end

-- Pure: spreads confirmed players over groups of 5, tanks and healers first so each group gets some.
function Raids.AutoGroups(signups, bench, size)
  local groups = math.max(1, math.ceil((size or 40) / 5))
  local byRole = { TANK = {}, HEALER = {}, DPS = {} }
  for _, s in ipairs(signups) do
    if s.d.status == "CONFIRMED" and not bench[s.d.name] then
      table.insert(byRole[s.d.role] or byRole.DPS, s.d.name)
    end
  end
  local out, fill, nextGroup = {}, {}, 1
  for g = 1, groups do
    fill[g] = 0
  end
  for _, role in ipairs({ "TANK", "HEALER", "DPS" }) do
    table.sort(byRole[role])
    for _, name in ipairs(byRole[role]) do
      local tries = 0
      while fill[nextGroup] >= 5 and tries < groups do
        nextGroup = nextGroup % groups + 1
        tries = tries + 1
      end
      if fill[nextGroup] < 5 then
        out[name] = nextGroup
        fill[nextGroup] = fill[nextGroup] + 1
        nextGroup = nextGroup % groups + 1
      end
    end
  end
  return out
end

function Raids.ApplyAutoGroups(raidId)
  local raid = Raids.Get(raidId)
  if not raid then
    return nil
  end
  local plan = Raids.Plan(raidId)
  return Store.Put("plans", raidId, { g = Raids.AutoGroups(Raids.Signups(raidId), plan.bench, raid.d.cap), bench = plan.bench })
end

-- Organising the groups by hand (the «Grupos» screen: drag a player, or pick and drop) ---------------------------
-- A player's place: a group (1-8), "none" (no group yet) or "bench" (reserve).
function Raids.PlaceOf(raidId, name)
  local plan = Raids.Plan(raidId)
  return plan.bench[name] and "bench" or plan.g[name] or "none"
end

local function copyPlan(raidId)
  local plan = Raids.Plan(raidId)
  local g, bench, rows = {}, {}, {}
  for k, v in pairs(plan.g) do
    g[k] = v
  end
  for k, v in pairs(plan.bench) do
    bench[k] = v
  end
  for k, v in pairs(plan.s) do
    rows[k] = v
  end
  return g, bench, rows
end

-- `name` to `place` (and, in a group, to `row` if given: whoever had that row there loses it and takes a free one).
local function put(g, bench, rows, name, place, row)
  g[name], bench[name], rows[name] = nil, nil, nil
  if place == "bench" then
    bench[name] = true
  elseif type(place) == "number" then
    g[name] = place
    if row then
      for other, r in pairs(rows) do
        if r == row and g[other] == place then
          rows[other] = nil
        end
      end
      rows[name] = row
    end
  end
end

-- The rows of a group as shown: those with a row first at theirs, the rest in the free ones (by role, then name).
-- `order` sorts the names without a row; returns { [row] = name }.
function Raids.Rows(raidId, group, names, order)
  local plan = Raids.Plan(raidId)
  local out, rest = {}, {}
  table.sort(names, function(a, b)
    return a < b
  end)
  for _, n in ipairs(names) do
    local r = plan.s[n]
    if r and not out[r] then
      out[r] = n
    else
      rest[#rest + 1] = n
    end
  end
  if order then
    table.sort(rest, order)
  end
  local i = 1
  for _, n in ipairs(rest) do
    while out[i] do
      i = i + 1
    end
    out[i] = n
  end
  return out
end

-- How many players a group has (leaving `except` out).
local function filled(g, group, except)
  local n = 0
  for name, grp in pairs(g) do
    if grp == group and name ~= except then
      n = n + 1
    end
  end
  return n
end

function Raids.Move(raidId, name, place, row)
  local raid = Raids.Get(raidId)
  if not raid or not Raids.CanManage(raid) then
    return nil, "permiso"
  end
  local g, bench, rows = copyPlan(raidId)
  if type(place) == "number" and filled(g, place, name) >= 5 then
    return nil, "lleno"
  end
  put(g, bench, rows, name, place, row)
  return Store.Put("plans", raidId, { g = g, bench = bench, s = rows })
end

-- Two players change places (a group and its row, no group or the reserve). rowA and rowB: the rows they show in
-- now (their place is taken row and all).
function Raids.Swap(raidId, a, b, rowA, rowB)
  local raid = Raids.Get(raidId)
  if not raid or not Raids.CanManage(raid) then
    return nil, "permiso"
  end
  if a == b then
    return nil, "igual"
  end
  local pa, pb = Raids.PlaceOf(raidId, a), Raids.PlaceOf(raidId, b)
  local g, bench, rows = copyPlan(raidId)
  put(g, bench, rows, a, pb, type(pb) == "number" and rowB or nil)
  put(g, bench, rows, b, pa, type(pa) == "number" and rowA or nil)
  return Store.Put("plans", raidId, { g = g, bench = bench, s = rows })
end

-- The real raid: each player to the group of the plan, one move at a time (each move waits for the game's
-- GROUP_ROSTER_UPDATE, so every step reads the raid as it really is). The leader or an assistant, out of combat.
-- A full group is entered by swapping with someone who should not be there.
Raids.placing = nil
local PLACE_STEPS, PLACE_TIME = 80, 40

local function raidNow()
  local roster, count = {}, {}
  for i = 1, (GetNumGroupMembers and GetNumGroupMembers() or 0) do
    local ok, _, _, sub = pcall(GetRaidRosterInfo, i)
    local name = Names.Unit("raid" .. i)
    if ok and type(sub) == "number" then
      count[sub] = (count[sub] or 0) + 1
      if name then
        roster[name] = { i = i, g = sub }
      end
    end
  end
  return roster, count
end

local function finish(p, state, why)
  Raids.placing = nil
  BG:Fire("BG_RAID_PLACING", state, why, p)
  return state
end

function Raids.PlaceStep()
  local p = Raids.placing
  if not p then
    return nil
  end
  if InCombatLockdown() then
    return finish(p, "stopped", "combate")
  end
  if p.steps >= PLACE_STEPS or GetTime() - p.at > PLACE_TIME then
    return finish(p, "stopped", "tiempo")
  end
  local plan = Raids.Plan(p.raid)
  local roster, count = raidNow()
  local names = {}
  for name in pairs(plan.g) do
    names[#names + 1] = name
  end
  table.sort(names)
  p.missing = 0
  for _, name in ipairs(names) do
    local want, r = plan.g[name], roster[name]
    if not r then
      p.missing = p.missing + 1
    elseif r.g ~= want and not p.stuck[name] then
      local ok
      if (count[want] or 0) < 5 then
        ok = pcall(SetRaidSubgroup, r.i, want)
      else
        local partner
        for other, o in pairs(roster) do
          if o.g == want and plan.g[other] ~= want then
            partner = o
            break
          end
        end
        if partner then
          ok = pcall(SwapRaidSubgroup, r.i, partner.i)
        end
      end
      if not ok then
        p.stuck[name] = true
      else
        p.steps, p.moved, p.movedAt = p.steps + 1, p.moved + 1, GetTime()
        BG:Fire("BG_RAID_PLACING", "moving", nil, p)
        return "moving"
      end
    end
  end
  return finish(p, "done")
end

function Raids.PlaceInRaid(raidId)
  local raid = Raids.Get(raidId)
  if not raid or not Raids.CanManage(raid) then
    return nil, "permiso"
  end
  if not BG.InGame() then
    return nil, "capturas"
  end
  if not (SetRaidSubgroup and SwapRaidSubgroup and GetRaidRosterInfo) then
    return nil, "sin juego"
  end
  if not IsInRaid() then
    return nil, "sin banda"
  end
  if not (UnitIsGroupLeader("player") or (UnitIsGroupAssistant and UnitIsGroupAssistant("player"))) then
    return nil, "sin mando"
  end
  if InCombatLockdown() then
    return nil, "combate"
  end
  Raids.placing = { raid = raidId, steps = 0, moved = 0, missing = 0, stuck = {}, at = GetTime(), movedAt = 0 }
  local state = Raids.PlaceStep()
  -- (in case the game's update after a move never comes: try again after a moment)
  local function nudge()
    local p = Raids.placing
    if not p then
      return
    end
    if GetTime() - p.movedAt >= 1.5 then
      Raids.PlaceStep()
    end
    if Raids.placing then
      C_Timer.After(1.5, nudge)
    end
  end
  if Raids.placing then
    C_Timer.After(1.5, nudge)
  end
  return state
end

-- (the next move, once the game has applied the last one)
BG:On("GROUP_ROSTER_UPDATE", function()
  if Raids.placing then
    Raids.PlaceStep()
  end
end)

-- Invites every confirmed, not benched player who is online and not yet in our group. A party turns into a
-- raid as soon as the game allows it (the conversion needs at least one other member).
local pendingConvert = false
function Raids.InviteConfirmed(raidId)
  if not BG.InGame() then
    return 0, 0
  end
  local plan = Raids.Plan(raidId)
  local invited, offline = 0, 0
  for _, s in ipairs(Raids.Signups(raidId)) do
    local name = s.d.name
    if s.d.status == "CONFIRMED" and not plan.bench[name] and not Names.IsMe(name) then
      local m = BG.Guild.Find(name)
      if m and m.online and not (UnitInParty(name) or UnitInRaid(name)) then
        C_PartyInfo.InviteUnit(Names.Tell(name))
        invited = invited + 1
      elseif not (m and m.online) then
        offline = offline + 1
      end
    end
  end
  if invited > 4 and not IsInRaid() then
    pendingConvert = true
    if IsInGroup() then
      C_PartyInfo.ConvertToRaid()
      pendingConvert = false
    end
  end
  return invited, offline
end

BG:On("GROUP_ROSTER_UPDATE", function()
  if pendingConvert and IsInGroup() and not IsInRaid() and UnitIsGroupLeader("player") then
    C_PartyInfo.ConvertToRaid()
    pendingConvert = false
  end
end)

-- Officer muster: a discreet call to the officers only (OFFICER reaches those who can read officer chat).
function Raids.Muster(text)
  return BG.Comm.Send("OM", { t = str(text, 140) or "" }, "OFFICER", nil, { lane = "alert" })
end

BG.Comm.Register("OM", function(sender, body)
  if type(body) ~= "table" then
    return
  end
  BG.Sound("RAID_WARNING")
  BG.UI.Dialog({
    title = "Llamada a los oficiales",
    items = { sender .. " os llama:", "«" .. (str(body.t, 140) or "") .. "»", { note = "Solo lo ven los rangos que leen el chat de oficiales." } },
    primary = { label = "Entendido" },
  })
end, { channels = { "OFFICER" }, maxBytes = 300 })
