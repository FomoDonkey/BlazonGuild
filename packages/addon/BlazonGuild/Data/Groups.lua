-- Looking for group, inside the guild:
--   * Flags (the board): "I'm looking for a group for X as a healer", one per player, gone after an hour.
--     Idea from Olympus's Board.lua (MIT).
--   * Groups: a leader publishes a group with the roles it still needs; players ask to join with a role;
--     the leader accepts (and the game invites them) or declines. Same shape as the web's group_listings
--     and group_members (dungeon key, note, roles).
local _, BG = ...
local Groups = {}
BG.Groups = Groups
local Store, Names, Instances = BG.Store, BG.Names, BG.Instances
local str, int = BG.Raids.Clean, BG.Raids.Int

local FLAG_TTL = 3600
local GROUP_TTL = 3 * 3600
local KINDS = { DUNGEON = "Mazmorra", RAID = "Banda", PVP = "JcJ", QUEST = "Misiones", OTHER = "Otra cosa" }
Groups.kinds = { "DUNGEON", "RAID", "PVP", "QUEST", "OTHER" }
Groups.kindName = KINDS

local function who()
  local m = BG.Guild.me
  return { class = m and m.classFile, level = m and m.level or UnitLevel("player"), zone = m and m.zone }
end

Store.Define("flags", {
  ttl = FLAG_TTL,
  can = function(author, r)
    return Names.Same(r.id, author)
  end,
  normalize = function(d, r)
    if not KINDS[d.kind] or not Instances.Role(d.role) then
      return nil
    end
    return { kind = d.kind, key = Instances.Dungeon(d.key) and d.key or nil, role = d.role, note = str(d.note, 120),
      class = str(d.class, 12), level = int(d.level, 1, 60), zone = str(d.zone, 60) }
  end,
})

local function memberList(t)
  local out = {}
  for i = 1, math.min(40, #(type(t) == "table" and t or {})) do
    local m = t[i]
    if type(m) == "table" and Instances.Role(m.role) then
      local name = Names.Short(str(m.name, 40))
      if name then
        out[#out + 1] = { name = name, role = m.role, class = str(m.class, 12), level = int(m.level, 1, 60) }
      end
    end
  end
  return out
end

Store.Define("groups", {
  ttl = GROUP_TTL,
  can = function(author, r)
    -- Only the leader who created it (its id starts with their name) edits or closes it; nobody can take
    -- over someone else's group by writing their own name as leader.
    local prefix = author:gsub("%s", "") .. "-"
    return r.id:sub(1, #prefix) == prefix and (r.del or Names.Same(r.d.leader, author))
  end,
  normalize = function(d)
    local key = d.key
    if not Instances.Any(key) then
      return nil
    end
    local size = int(d.size, 2, 40) or 5
    local need = type(d.need) == "table" and d.need or {} -- (from another addon: whatever came, never an error)
    local declined = {}
    for name in pairs(type(d.declined) == "table" and d.declined or {}) do
      local short = Names.Short(str(name, 40))
      if short then
        declined[short] = true
      end
    end
    return {
      key = key, note = str(d.note, 140), leader = Names.Short(str(d.leader, 40)), size = size,
      need = { TANK = int(need.TANK, 0, 10) or 0, HEALER = int(need.HEALER, 0, 10) or 0, DPS = int(need.DPS, 0, 30) or 0 },
      members = memberList(d.members), declined = declined, status = d.status == "CLOSED" and "CLOSED" or "OPEN",
    }
  end,
})

Store.Define("requests", {
  ttl = GROUP_TTL,
  can = function(author, r)
    return Names.Same(r.id:match("|(.+)$"), author)
  end,
  normalize = function(d, r)
    local name = Names.Short(str(d.name, 40))
    if type(d.group) ~= "string" or not Instances.Role(d.role) or not name or r.id ~= d.group .. "|" .. name then
      return nil
    end
    return { group = d.group, name = name, role = d.role, note = str(d.note, 120), class = str(d.class, 12), level = int(d.level, 1, 60) }
  end,
})

-- Flags --------------------------------------------------------------------------------------------
function Groups.Flags()
  local list = Store.List("flags")
  table.sort(list, function(a, b)
    return a.at > b.at
  end)
  return list
end

function Groups.MyFlag()
  local me = Names.Me()
  local r = me and Store.Get("flags", me)
  return r and not r.del and (not r.exp or r.exp > Store.Now()) and r or nil
end

function Groups.RaiseFlag(kind, key, role, note)
  local me = Names.Me()
  if not me then
    return nil, "sin personaje"
  end
  local w = who()
  return Store.Put("flags", me, { kind = kind, key = key, role = role, note = note, class = w.class, level = w.level, zone = w.zone }, { lane = "alert" })
end

function Groups.LowerFlag()
  local me = Names.Me()
  return me and Store.Delete("flags", me)
end

-- Groups -------------------------------------------------------------------------------------------
function Groups.Open()
  local list = Store.List("groups", function(r)
    return r.d.status == "OPEN"
  end)
  table.sort(list, function(a, b)
    return a.at > b.at
  end)
  return list
end

function Groups.Get(id)
  local r = Store.Get("groups", id)
  return r and not r.del and r or nil
end

function Groups.Mine()
  local me = Names.Me()
  for _, g in ipairs(Groups.Open()) do
    if Names.Same(g.d.leader, me) then
      return g
    end
  end
  return nil
end

-- Roles still missing: wanted minus accepted members (the leader counts with the role they chose).
function Groups.Missing(g)
  local miss = { TANK = g.d.need.TANK, HEALER = g.d.need.HEALER, DPS = g.d.need.DPS }
  for _, m in ipairs(g.d.members) do
    miss[m.role] = math.max(0, (miss[m.role] or 0) - 1)
  end
  return miss
end

function Groups.Create(key, need, note, myRole)
  local me = Names.Me()
  if not me then
    return nil, "sin personaje"
  end
  local w = who()
  local inst = Instances.Any(key)
  local id = me:gsub("%s", "") .. "-" .. Store.Now()
  return Store.Put("groups", id, {
    key = key, note = note, leader = me, size = inst and inst.size or 5, need = need,
    members = { { name = me, role = myRole or "DPS", class = w.class, level = w.level } }, declined = {}, status = "OPEN",
  }, { lane = "alert" })
end

local function edit(id, fn)
  local g = Groups.Get(id)
  if not g then
    return nil, "no existe"
  end
  local d = {}
  for k, v in pairs(g.d) do
    d[k] = v
  end
  d.members = {}
  for i, m in ipairs(g.d.members) do
    d.members[i] = m
  end
  d.declined = {}
  for k, v in pairs(g.d.declined) do
    d.declined[k] = v
  end
  fn(d)
  return Store.Put("groups", id, d, { lane = "alert" })
end

function Groups.Close(id)
  return edit(id, function(d)
    d.status = "CLOSED"
  end)
end

function Groups.Requests(groupId)
  local g = Groups.Get(groupId)
  local list = Store.List("requests", function(r)
    if r.d.group ~= groupId or not g then
      return false
    end
    if g.d.declined[r.d.name] then
      return false
    end
    for _, m in ipairs(g.d.members) do
      if m.name == r.d.name then
        return false
      end
    end
    return true
  end)
  table.sort(list, function(a, b)
    return a.at < b.at
  end)
  return list
end

function Groups.Ask(groupId, role, note)
  local me = Names.Me()
  if not me then
    return nil, "sin personaje"
  end
  local w = who()
  return Store.Put("requests", groupId .. "|" .. me, { group = groupId, name = me, role = role, note = note, class = w.class, level = w.level }, { lane = "alert" })
end

function Groups.Withdraw(groupId)
  local me = Names.Me()
  return me and Store.Delete("requests", groupId .. "|" .. me)
end

function Groups.MyRequest(groupId)
  local me = Names.Me()
  local r = me and Store.Get("requests", groupId .. "|" .. me)
  return r and not r.del and r or nil
end

-- Leader: accept (adds the member and sends the game's invite) or decline.
function Groups.Accept(groupId, name)
  local req = Store.Get("requests", groupId .. "|" .. name)
  if not req or req.del then
    return nil, "sin petición"
  end
  local r, why = edit(groupId, function(d)
    d.members[#d.members + 1] = { name = req.d.name, role = req.d.role, class = req.d.class, level = req.d.level }
    local missing = 0
    for _, n in pairs(Groups.Missing({ d = d })) do
      missing = missing + n
    end
    if missing == 0 then
      d.status = "CLOSED"
    end
  end)
  if r and C_PartyInfo and C_PartyInfo.InviteUnit and BG.InGame() then
    C_PartyInfo.InviteUnit(Names.Tell(name))
  end
  return r, why
end

function Groups.Decline(groupId, name)
  return edit(groupId, function(d)
    d.declined[name] = true
  end)
end

-- The fixed whispers a click sends (shown in the card's tooltip before clicking). Never the chat box:
-- opening it from an addon taints what the player types next (learned from Olympus).
function Groups.FlagWhisper(flag)
  local inst = Instances.Any(flag.d.key)
  return "Hola, he visto en BlazonGuild que buscas grupo" .. (inst and (" para " .. inst.name) or "") .. ". ¿Vamos juntos?"
end

function Groups.GroupWhisper(g)
  local inst = Instances.Any(g.d.key)
  return "Hola, he visto tu grupo" .. (inst and (" de " .. inst.name) or "") .. " en BlazonGuild. ¿Te queda sitio?"
end

function Groups.Whisper(name, text)
  return BG.People.SendWhisper(name, text)
end
