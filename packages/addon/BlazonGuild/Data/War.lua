-- Sala de guerra (entrega 6, third part; Olympus' War.lua and WarSquads.lua, MIT, our own implementation):
-- the guild's squads (a leader and a few members, with a private chat), operations (when, where, which squads,
-- who goes) and the reports of how they went. Everything stays inside the guild (GUILD, whose senders the game
-- stamps), like Olympus' war room.
--
-- Records: "squads" (organisers create them and name the leader; the leader manages its members), "ops" (an
-- organiser or a squad leader plans it; its leader runs it), "opans" (each player's answer: going, reserve or
-- can't), "reports" (the operation's leader or an organiser writes how it went). Squad chat goes by whisper
-- to each member online (WQ), never to the whole guild.
local _, BG = ...
local War = {}
BG.War = War
local Store, Names, Comm, Peers = BG.Store, BG.Names, BG.Comm, BG.Peers
local str, int = BG.Raids.Clean, BG.Raids.Int

local MAX_MEMBERS = 14 -- besides the leader
local MAX_OP_SQUADS = 8
local REMIND_BEFORE = 15 * 60

War.SPECS = {
  { key = "ASSAULT", name = "Asalto", icon = "Interface\\Icons\\Ability_Warrior_Charge" },
  { key = "DEFENSE", name = "Defensa", icon = "Interface\\Icons\\Ability_Defend" },
  { key = "SCOUT", name = "Exploración", icon = "Interface\\Icons\\Ability_Hunter_EagleEye" },
  { key = "SUPPORT", name = "Apoyo", icon = "Interface\\Icons\\Spell_Holy_PowerWordShield" },
}
War.KINDS = {
  { key = "PVP", name = "JcJ", icon = "Interface\\Icons\\Ability_DualWield" },
  { key = "DEFENSE", name = "Defensa", icon = "Interface\\Icons\\Ability_Defend" },
  { key = "RAID", name = "Banda", icon = "Interface\\Icons\\Achievement_Boss_Ragnaros" },
  { key = "OTHER", name = "Otra", icon = "Interface\\Icons\\INV_Misc_Map_01" },
}
War.STATES = { PLANNED = "planeada", ACTIVE = "en marcha", DONE = "terminada", CANCELLED = "cancelada" }
War.ANSWERS = { GO = "Voy", MAYBE = "Reserva", NO = "No puedo" }
War.RESULTS = { WIN = "Victoria", LOSS = "Derrota", DRAW = "Empate", NONE = "Sin combate" }

local function find(list, key)
  for _, x in ipairs(list) do
    if x.key == key then
      return x
    end
  end
  return nil
end
function War.Spec(key)
  return find(War.SPECS, key)
end
function War.Kind(key)
  return find(War.KINDS, key)
end

local function nameList(t, max)
  local out, have = {}, {}
  for i = 1, math.min(max, #(type(t) == "table" and t or {})) do
    local n = Names.Short(str(t[i], 40))
    if n and n ~= "" and not have[n] then
      have[n] = true
      out[#out + 1] = n
    end
  end
  return out
end

local function has(list, name)
  for _, n in ipairs(list or {}) do
    if Names.Same(n, name) then
      return true
    end
  end
  return false
end

-- Shared records -----------------------------------------------------------------------------------------------
Store.Define("squads", {
  can = function(author, r, old)
    if Store.IsOrganiser(author) then
      return true
    end
    -- The leader keeps their squad's members and note; the name, speciality and leader are the organisers'.
    if not (old and not old.del and old.d and Names.Same(old.d.leader, author)) or r.del then
      return false
    end
    return r.d.name == old.d.name and r.d.spec == old.d.spec and Names.Same(r.d.leader, old.d.leader)
  end,
  normalize = function(d)
    local name, leader = str(d.name, 30), Names.Short(str(d.leader, 40))
    if not name or name == "" or not leader then
      return nil
    end
    local members = {}
    for _, n in ipairs(nameList(d.members, MAX_MEMBERS + 1)) do
      if not Names.Same(n, leader) and #members < MAX_MEMBERS then
        members[#members + 1] = n
      end
    end
    return { name = name, spec = War.Spec(d.spec) and d.spec or "ASSAULT", leader = leader, members = members, note = str(d.note, 120) }
  end,
})

Store.Define("ops", {
  ttl = function(r)
    return (r.d and r.d.start or r.at) + 3 * 86400
  end,
  can = function(author, r, old)
    if Store.IsOrganiser(author) then
      return true
    end
    local prefix = author:gsub("%s", "") .. "-"
    local mine = r.id:sub(1, #prefix) == prefix
    if old and not old.del then
      return mine or Names.Same(old.d and old.d.leader, author)
    end
    return mine and War.LeadsSquad(author)
  end,
  normalize = function(d)
    local start = tonumber(d.start)
    local title = str(d.title, 60)
    if not start or not title or title == "" then
      return nil
    end
    local squads = {}
    for i = 1, math.min(MAX_OP_SQUADS, #(type(d.squads) == "table" and d.squads or {})) do
      local id = d.squads[i]
      if type(id) == "string" and #id <= 24 and id:match("^[%w%-]+$") then
        squads[#squads + 1] = id
      end
    end
    -- (an operation of the whole alliance: whose it is, and the act that carries it; AllianceActs.lua)
    local ally
    if type(d.ally) == "table" and type(d.ally.i) == "string" and #d.ally.i <= 40 and type(d.ally.g) == "string" and #d.ally.g <= 80 then
      ally = { i = d.ally.i, g = d.ally.g, n = str(d.ally.n, 40), lead = d.ally.lead == true or nil }
    end
    return {
      title = title, kind = War.Kind(d.kind) and d.kind or "PVP", start = math.floor(start), place = str(d.place, 40),
      leader = Names.Short(str(d.leader, 40)), squads = squads, status = War.STATES[d.status] and d.status or "PLANNED", note = str(d.note, 160),
      ally = ally,
    }
  end,
})

Store.Define("opans", {
  ttl = function(r)
    local op = r.d and Store.Get("ops", r.d.op)
    return op and op.exp or (r.at + 7 * 86400)
  end,
  can = function(author, r)
    return Names.Same(r.id:match("|(.+)$"), author) -- only the player answers for themselves
  end,
  normalize = function(d, r)
    local name = Names.Short(str(d.name, 40))
    if type(d.op) ~= "string" or not War.ANSWERS[d.a] or not name or r.id ~= d.op .. "|" .. name then
      return nil
    end
    return { op = d.op, name = name, a = d.a, role = BG.Instances.Role(d.role) and d.role or nil, class = str(d.class, 12) }
  end,
})

Store.Define("reports", {
  ttl = 120 * 86400,
  can = function(author, r)
    if Store.IsOrganiser(author) then
      return true
    end
    local op = Store.Get("ops", r.id)
    return op ~= nil and op.d ~= nil and Names.Same(op.d.leader, author)
  end,
  normalize = function(d)
    local title = str(d.title, 60)
    if not title or not War.RESULTS[d.result] then
      return nil
    end
    return { title = title, kind = War.Kind(d.kind) and d.kind or "OTHER", start = int(d.start, 0, 4e9) or 0, result = d.result, note = str(d.note, 300),
      present = nameList(d.present, 60), leader = Names.Short(str(d.leader, 40)) }
  end,
})

-- Squads ------------------------------------------------------------------------------------------------------------
function War.Squads()
  local list = Store.List("squads")
  table.sort(list, function(a, b)
    return a.d.name:lower() < b.d.name:lower()
  end)
  return list
end

function War.InSquad(sq, name)
  return sq ~= nil and sq.d ~= nil and (Names.Same(sq.d.leader, name) or has(sq.d.members, name))
end

function War.SquadOf(name)
  for _, sq in ipairs(War.Squads()) do
    if War.InSquad(sq, name) then
      return sq
    end
  end
  return nil
end

function War.LeadsSquad(name)
  for _, sq in ipairs(War.Squads()) do
    if Names.Same(sq.d.leader, name) then
      return sq
    end
  end
  return nil
end

-- Who may plan operations: the organisers and the squad leaders.
function War.CanPlan(name)
  name = name or Names.Me()
  return name ~= nil and (Store.IsOrganiser(name) or War.LeadsSquad(name) ~= nil)
end

function War.CanManageSquad(sq, name)
  name = name or Names.Me()
  return name ~= nil and (Store.IsOrganiser(name) or (sq ~= nil and Names.Same(sq.d.leader, name)))
end

local function member(name)
  local m = BG.Guild.Find(str(name, 40) or "")
  return m and Names.Short(m.name) or nil
end

-- An organiser creates or edits a squad. Returns the record or nil and why.
function War.SaveSquad(id, fields)
  if not Store.IsOrganiser(Names.Me() or "") then
    return nil, "permiso"
  end
  local old = id and Store.Get("squads", id)
  local leader = member(fields.leader)
  if not leader then
    return nil, "jefe"
  end
  local d = { name = fields.name, spec = fields.spec, leader = leader, members = old and old.d and old.d.members or {}, note = fields.note }
  return Store.Put("squads", id or ("sq" .. BG.Alliance.RandomId(8)), d)
end

function War.DeleteSquad(id)
  if not Store.IsOrganiser(Names.Me() or "") then
    return nil, "permiso"
  end
  return Store.Delete("squads", id)
end

-- Adds a member of the guild to a squad (its leader or an organiser). Someone already in another squad moves,
-- if an organiser does it; a leader cannot take people from another squad.
function War.AddToSquad(id, name)
  local sq = Store.Get("squads", id)
  if not sq or sq.del then
    return nil, "no existe"
  end
  if not War.CanManageSquad(sq) then
    return nil, "permiso"
  end
  local who = member(name)
  if not who then
    return nil, "no es de tu hermandad"
  end
  if War.InSquad(sq, who) then
    return nil, "ya está"
  end
  if #sq.d.members >= MAX_MEMBERS then
    return nil, "llena"
  end
  local other = War.SquadOf(who)
  if other then
    if not Store.IsOrganiser(Names.Me()) or Names.Same(other.d.leader, who) then
      return nil, "en otra", other.d.name
    end
    local od = {}
    for k, v in pairs(other.d) do
      od[k] = v
    end
    od.members = {}
    for _, n in ipairs(other.d.members) do
      if not Names.Same(n, who) then
        od.members[#od.members + 1] = n
      end
    end
    Store.Put("squads", other.id, od)
  end
  local d = {}
  for k, v in pairs(sq.d) do
    d[k] = v
  end
  d.members = {}
  for _, n in ipairs(sq.d.members) do
    d.members[#d.members + 1] = n
  end
  d.members[#d.members + 1] = who
  return Store.Put("squads", id, d)
end

function War.RemoveFromSquad(id, name)
  local sq = Store.Get("squads", id)
  if not sq or sq.del then
    return nil, "no existe"
  end
  if not War.CanManageSquad(sq) then
    return nil, "permiso"
  end
  local d = {}
  for k, v in pairs(sq.d) do
    d[k] = v
  end
  d.members = {}
  for _, n in ipairs(sq.d.members) do
    if not Names.Same(n, name) then
      d.members[#d.members + 1] = n
    end
  end
  return Store.Put("squads", id, d)
end

-- Operations --------------------------------------------------------------------------------------------------------
function War.Ops()
  local now = Store.Now()
  local list = Store.List("ops", function(r)
    return r.d.status == "ACTIVE" or r.d.status == "PLANNED" and r.d.start > now - 6 * 3600 or now - r.d.start < 86400
  end)
  local order = { ACTIVE = 1, PLANNED = 2, DONE = 3, CANCELLED = 4 }
  table.sort(list, function(a, b)
    if order[a.d.status] ~= order[b.d.status] then
      return order[a.d.status] < order[b.d.status]
    end
    return a.d.start < b.d.start
  end)
  return list
end

-- Is `name` called to operation `op`: everyone when it names no squads, else the members of its squads.
function War.Called(op, name)
  if #op.d.squads == 0 then
    return true
  end
  for _, id in ipairs(op.d.squads) do
    if War.InSquad(Store.Get("squads", id), name) then
      return true
    end
  end
  return Names.Same(op.d.leader, name)
end

function War.SquadNames(op)
  local out = {}
  for _, id in ipairs(op.d.squads) do
    local sq = Store.Get("squads", id)
    if sq and not sq.del then
      out[#out + 1] = sq.d.name
    end
  end
  return out
end

-- An organiser or a squad leader plans (or edits) an operation. Returns the record or nil and why.
-- fields.ally: an operation of the whole alliance (only the leader guild's organisers who can sign; it goes to every
-- guild's war room, AllianceActs.lua).
function War.SaveOp(id, fields)
  local me = Names.Me()
  local old = id and Store.Get("ops", id)
  if not old and not War.CanPlan(me) then
    return nil, "permiso"
  end
  if old and old.d.ally and not old.d.ally.lead then
    return nil, "permiso" -- (another guild's: it changes there)
  end
  local Acts = BG.AllianceActs
  local ally = old and old.d.ally or nil
  if fields.ally and not ally then
    if not (Acts and Acts.MayLead()) then
      return nil, "permiso"
    end
    local info = BG.Guild.info
    ally = { i = "op-" .. BG.Alliance.RandomId(8), g = info.key, n = info.name, lead = true }
  end
  local d = {
    title = fields.title, kind = fields.kind, start = fields.start, place = fields.place, note = fields.note,
    leader = member(fields.leader) or (old and old.d.leader) or me, squads = ally and {} or fields.squads or (old and old.d.squads) or {},
    status = old and old.d.status or "PLANNED", ally = ally,
  }
  local r, why = Store.Put("ops", id or (me:gsub("%s", "") .. "-" .. Store.Now()), d, { lane = "alert" })
  if r and ally and ally.lead and Acts then
    Acts.IssueOp(r)
  end
  return r, why
end

local function setStatus(op, status)
  local d = {}
  for k, v in pairs(op.d) do
    d[k] = v
  end
  d.status = status
  local r, why = Store.Put("ops", op.id, d, { lane = "alert" })
  if r and d.ally and d.ally.lead and BG.AllianceActs then
    BG.AllianceActs.IssueOp(r)
  end
  return r, why
end

-- A sister guild's operation of the whole alliance, kept in our war room (an organiser of ours puts it).
function War.PutAllyOp(id, p, ally)
  local d = { title = p.title, kind = p.kind, start = p.start, place = p.place, note = p.note, leader = p.leader, squads = {}, status = p.status, ally = ally }
  return Store.Put("ops", id, d, { lane = "alert" })
end

function War.CanRun(op, name)
  name = name or Names.Me()
  if not name then
    return false
  end
  if op.d.ally and not op.d.ally.lead then
    return false -- (another guild's operation: its own guild starts, ends or cancels it)
  end
  local prefix = name:gsub("%s", "") .. "-"
  return Store.IsOrganiser(name) or Names.Same(op.d.leader, name) or op.id:sub(1, #prefix) == prefix
end

-- The operation starts now: everyone called to it gets the alert.
function War.Start(id)
  local op = Store.Get("ops", id)
  if not op or op.del then
    return nil, "no existe"
  end
  if not War.CanRun(op) then
    return nil, "permiso"
  end
  return setStatus(op, "ACTIVE")
end

function War.Cancel(id)
  local op = Store.Get("ops", id)
  if not op or op.del then
    return nil, "no existe"
  end
  if not War.CanRun(op) then
    return nil, "permiso"
  end
  return setStatus(op, "CANCELLED")
end

-- Ends the operation with its report: the result, a note and who was there (those who said they were going,
-- and its leader). It goes into the guild's chronicle too.
function War.Finish(id, result, note)
  local op = Store.Get("ops", id)
  if not op or op.del then
    return nil, "no existe"
  end
  if not War.CanRun(op) then
    return nil, "permiso"
  end
  if not War.RESULTS[result] then
    return nil, "resultado"
  end
  local present = {}
  if op.d.leader then
    present[1] = op.d.leader
  end
  for _, a in ipairs(War.Answers(id)) do
    if a.d.a == "GO" and not has(present, a.d.name) then
      present[#present + 1] = a.d.name
    end
  end
  local r, why = Store.Put("reports", id, { title = op.d.title, kind = op.d.kind, start = op.d.start, result = result, note = note, present = present, leader = op.d.leader })
  if not r then
    return nil, why
  end
  setStatus(op, "DONE")
  return r
end

function War.Reports(limit)
  local list = Store.List("reports")
  table.sort(list, function(a, b)
    return a.d.start > b.d.start
  end)
  while limit and #list > limit do
    table.remove(list)
  end
  return list
end

-- Answers ---------------------------------------------------------------------------------------------------------
function War.Answer(opId, a, role)
  local me = Names.Me()
  local op = Store.Get("ops", opId)
  if not me or not op or op.del then
    return nil, "no existe"
  end
  if not War.ANSWERS[a] then
    return nil, "respuesta"
  end
  local m = BG.Guild.me
  return Store.Put("opans", opId .. "|" .. me, { op = opId, name = me, a = a, role = role or (BG.People.Profile(me) or { d = {} }).d.role, class = m and m.classFile },
    { lane = "alert" })
end

function War.Answers(opId)
  local prefix = opId .. "|"
  return Store.List("opans", function(r)
    return r.id:sub(1, #prefix) == prefix
  end)
end

function War.MyAnswer(opId)
  local me = Names.Me()
  local r = me and Store.Get("opans", opId .. "|" .. me)
  return r and not r.del and r.d.a or nil
end

function War.Count(opId)
  local out = { GO = 0, MAYBE = 0, NO = 0, roles = { TANK = 0, HEALER = 0, DPS = 0 } }
  for _, a in ipairs(War.Answers(opId)) do
    out[a.d.a] = out[a.d.a] + 1
    if a.d.a == "GO" and a.d.role and out.roles[a.d.role] then
      out.roles[a.d.role] = out.roles[a.d.role] + 1
    end
  end
  return out
end

-- Squad chat ---------------------------------------------------------------------------------------------------------
-- Channel "sq-<id>": by whisper to each member of the squad online with BlazonGuild, never to the whole guild.
function War.IsChannel(channel)
  return type(channel) == "string" and channel:sub(1, 3) == "sq-"
end

local seq = 0
function War.SquadSend(channel, text)
  local id = channel:sub(4)
  local sq = Store.Get("squads", id)
  local me = Names.Me()
  if not sq or sq.del or not War.InSquad(sq, me) then
    return false, "no eres de esa escuadra"
  end
  seq = seq + 1
  local lineId = me:gsub("%s", "") .. "-" .. Store.Now() .. "-" .. seq
  local m = BG.Guild.me
  local body = { s = id, i = lineId, t = text, c = m and m.classFile }
  local reached = 0
  for _, p in ipairs(Peers.Active()) do
    if not p.me and War.InSquad(sq, p.name) then
      if Comm.Send("WQ", body, "WHISPER", p.name, { lane = "alert" }) then
        reached = reached + 1
      end
    end
  end
  BG.Chat.Add(channel, { at = Store.Now(), from = me, text = text, id = lineId, class = body.c })
  return true, reached
end

local heard = {}
Comm.Register("WQ", function(sender, b)
  if type(b) ~= "table" or type(b.s) ~= "string" or type(b.t) ~= "string" or type(b.i) ~= "string" or #b.i > 80 or heard[b.i] then
    return
  end
  local sq = Store.Get("squads", b.s)
  if not sq or sq.del or not War.InSquad(sq, sender) or not War.InSquad(sq, Names.Me()) or not BG.Guild.Find(sender) then
    return
  end
  heard[b.i] = true
  if BG.Chat.MutedUntil(sender) then
    return
  end
  BG.Chat.Add("sq-" .. b.s, { at = Store.Now(), from = Names.Short(sender), text = BG.Chat.Sanitize(b.t), id = b.i, class = str(b.c, 12) })
end, { channels = { "WHISPER" }, maxBytes = 700 })

-- Notices ------------------------------------------------------------------------------------------------------------
local function when(t)
  return BG.UI and BG.UI.FormatDate and BG.UI.FormatDate(t, true) or date("%d/%m %H:%M", t)
end

local function alert(title, text)
  if RaidNotice_AddMessage and RaidWarningFrame and ChatTypeInfo then
    pcall(RaidNotice_AddMessage, RaidWarningFrame, title .. ": " .. text, ChatTypeInfo.RAID_WARNING)
  end
  BG:Notify(title, text, { kind = "danger", duration = 12, sound = "RAID_WARNING", view = "war" })
end

BG:On("BG_RECORD", function(kind, r, old)
  local me = Names.Me()
  if not me or not r.d then
    return
  end
  if kind == "ops" and War.Called(r, me) and not Names.Same(r.by, me) then
    local was = old and old.d and old.d.status
    if not old then
      BG:Notify("Nueva operación", r.d.title .. ", " .. when(r.d.start) .. (r.d.place and r.d.place ~= "" and (", en " .. r.d.place) or "") .. ". ¿Vas?",
        { kind = "info", view = "war", sound = "READY_CHECK" })
    elseif r.d.status == "ACTIVE" and was ~= "ACTIVE" and War.MyAnswer(r.id) ~= "NO" then
      alert("¡Operación en marcha!", r.d.title .. (r.d.place and r.d.place ~= "" and (" — " .. r.d.place) or "") .. " — " .. (r.d.leader or r.by))
    elseif r.d.status == "CANCELLED" and was ~= "CANCELLED" then
      BG:Notify("Operación cancelada", r.d.title .. " no se hace.", { kind = "warning", view = "war" })
    end
  elseif kind == "squads" and not (old and old.d and War.InSquad(old, me)) and War.InSquad(r, me) and not Names.Same(r.by, me) then
    BG:Notify("Nueva escuadra", "Estás en la escuadra «" .. r.d.name .. "» (" .. ((War.Spec(r.d.spec) or {}).name or "") .. "). Su jefe es " .. r.d.leader .. ".",
      { kind = "info", view = "war" })
  elseif kind == "reports" and not old then
    local res = War.RESULTS[r.d.result]
    if BG.Board and BG.Board.Log then
      BG.Board.Log("report", "Parte de «" .. r.d.title .. "»: " .. res:lower() .. ", " .. #r.d.present .. " presentes")
    end
  end
  if kind == "ops" or kind == "opans" or kind == "squads" or kind == "reports" then
    BG:Fire("BG_WAR_CHANGED")
  end
end)
BG:On("BG_STORE_CHANGED", function(name)
  if name == "ops" or name == "opans" or name == "squads" or name == "reports" then
    BG:Fire("BG_WAR_CHANGED")
  end
end)

-- A reminder a quarter of an hour before an operation, to whoever said they were going.
local reminded = {}
local function tick()
  local now = Store.Now()
  for _, op in ipairs(War.Ops()) do
    if op.d.status == "PLANNED" and not reminded[op.id] and op.d.start - now <= REMIND_BEFORE and op.d.start - now > -300 and War.MyAnswer(op.id) == "GO" then
      reminded[op.id] = true
      BG:Notify("Operación en un rato", op.d.title .. " empieza a las " .. date("%H:%M", op.d.start) .. (op.d.place and op.d.place ~= "" and (", en " .. op.d.place) or "") .. ".",
        { kind = "info", view = "war", sound = "READY_CHECK" })
    end
  end
  C_Timer.After(60, tick)
end
local started = false
BG:On("BG_ROSTER_UPDATED", function()
  if not started and BG.Guild.info then
    started = true
    C_Timer.After(60, tick)
  end
end)

BG.commands = BG.commands or {}
BG.commands.guerra = function()
  if not (BG.window and BG.window:IsShown()) then
    BG:ToggleWindow()
  end
  BG:ShowView("war")
end
