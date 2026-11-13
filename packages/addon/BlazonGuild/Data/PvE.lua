-- JcE: who is ready for each raid, what the guild has defeated, and its last raids.
--   * Ready: from the game's roster (level), without the addon.
--   * Defeated: when a raid boss dies (the game's ENCOUNTER_END, success) in a group that is mostly of our guild,
--     the addon of a member who was there writes it down (record "kills": the boss, the day, how many of ours).
--     The same boss on the same day is one record, whoever writes it first.
--   * Last raids: BlazonGuild's raids that started, with who was confirmed (Honors.lua keeps them).
-- (Olympus does not use ENCOUNTER_END; it is a standard event, but it has not been seen yet in Forever's client.)
local _, BG = ...
local PvE = {}
BG.PvE = PvE
local Store, Names, Instances = BG.Store, BG.Names, BG.Instances
local str, int = BG.Raids.Clean, BG.Raids.Int

-- Forever's raids (Instances.lua) in their order, how many bosses each one has, and the map ids we know. The classic
-- era's other raids keep their counts only so the kills an older version wrote still read; they are not shown.
PvE.ORDER = { "BARROW", "HYJAL", "ONY" }
PvE.BOSSES = { BARROW = 8, HYJAL = 13, ONY = 1, MC = 10, BWL = 8, ZG = 10, AQ20 = 6, AQ40 = 9, NAXX = 15, UBRS = 7 }
PvE.MAPS = { [249] = "ONY", [409] = "MC", [469] = "BWL", [309] = "ZG", [509] = "AQ20", [531] = "AQ40", [533] = "NAXX", [229] = "UBRS" }
local KILL_TTL = 400 * 86400

-- "kills"/<encounter>-<day>: { e = encounter id, n = boss name, r = raid key, m = members of ours there }.
Store.Define("kills", {
  ttl = KILL_TTL,
  can = function()
    return true -- (any member who was there; it comes from inside the guild, Store.lua)
  end,
  normalize = function(d, r)
    local e = int(d.e, 1, 100000)
    local raid = type(d.r) == "string" and PvE.BOSSES[d.r] and d.r or nil
    if not e or not raid or (r and not tostring(r.id):match("^" .. e .. "%-%d+$")) then
      return nil
    end
    return { e = e, n = str(d.n, 60) or "?", r = raid, m = int(d.m, 1, 40) or 1 }
  end,
})

local function day(t)
  return date("!%Y%m%d", t)
end

-- The raid we are in: by the game's map id, by its name (ours, in the chosen language, or one we know the game uses:
-- Instances' `alias`), or, for Forever's raids, by its size while each one has its own (10, 20, 40). nil if none.
function PvE.RaidHere()
  if not GetInstanceInfo then
    return nil
  end
  local ok, name, kind, _, _, maxPlayers, _, _, mapId = pcall(GetInstanceInfo)
  if not ok or kind ~= "raid" then
    return nil
  end
  if PvE.MAPS[tonumber(mapId) or -1] then
    return PvE.MAPS[tonumber(mapId)]
  end
  for _, r in ipairs(Instances.raids) do
    if PvE.BOSSES[r.key] then
      if name == r.name or name == BG.T(r.name) then
        return r.key
      end
      for _, a in ipairs(r.alias or {}) do
        if name == a then
          return r.key
        end
      end
    end
  end
  local size, found = tonumber(maxPlayers), nil
  for _, key in ipairs(PvE.ORDER) do
    local r = Instances.Raid(key)
    if r and size and r.size == size then
      if found then
        return nil -- (two of that size: the name or the map has to say which)
      end
      found = key
    end
  end
  return found
end

-- How many of the group are of our guild, and the group's size.
-- (each one by their unit, "raidN" or "partyN": the game's roster can give the first name alone on Forever)
function PvE.OursInGroup()
  local n, ours = GetNumGroupMembers and GetNumGroupMembers() or 0, 0
  local raid = IsInRaid and IsInRaid()
  for i = 1, n do
    local unit = raid and ("raid" .. i) or (i == n and "player" or ("party" .. i))
    local name = BG.Names.Unit(unit)
    if name and BG.Guild.Find(name) then
      ours = ours + 1
    end
  end
  return ours, n
end

-- A boss died: written down if we are in one of the raids and the group is mostly ours (5 of ours, or half).
function PvE.OnKill(encounterId, name, success)
  if success ~= 1 and success ~= true then
    return nil, "no"
  end
  local raid = PvE.RaidHere()
  local e = tonumber(encounterId)
  if not raid or not e or not BG.Guild.info then
    return nil, "fuera"
  end
  local ours, size = PvE.OursInGroup()
  if ours < 5 and ours * 2 < size or ours == 0 then
    return nil, "no es de la hermandad"
  end
  local id = e .. "-" .. day(Store.Now())
  if Store.Get("kills", id) then
    return Store.Get("kills", id)
  end
  return Store.Put("kills", id, { e = e, n = name, r = raid, m = ours }, { lane = "normal" })
end

BG:On("ENCOUNTER_END", function(encounterId, name, _, _, success)
  PvE.OnKill(encounterId, name, success)
end)

-- What the guild has defeated in `raid`: { bosses = { { e, n, first, times } } (first kill first), done, of }.
function PvE.Progress(raid)
  local by = {}
  for _, r in ipairs(Store.List("kills", function(x)
    return x.d and x.d.r == raid
  end)) do
    local b = by[r.d.e]
    if not b then
      b = { e = r.d.e, n = r.d.n, first = r.at, times = 0 }
      by[r.d.e] = b
    end
    b.times = b.times + 1
    if r.at < b.first then
      b.first, b.n = r.at, r.d.n
    end
  end
  local list = {}
  for _, b in pairs(by) do
    list[#list + 1] = b
  end
  table.sort(list, function(a, b)
    return a.first < b.first
  end)
  return { bosses = list, done = math.min(#list, PvE.BOSSES[raid] or #list), of = PvE.BOSSES[raid] }
end

-- Who is ready (level) for each raid: { { key, name, size, minLevel, ready, online, progress } } in the usual order.
function PvE.Raids()
  local out = {}
  for _, key in ipairs(PvE.ORDER) do
    local r = Instances.Raid(key)
    if r then
      local ready, online = 0, 0
      for _, m in ipairs(BG.Guild.members or {}) do
        if (m.level or 0) >= (r.minLevel or 60) then
          ready = ready + 1
          if m.online then
            online = online + 1
          end
        end
      end
      out[#out + 1] = { key = key, name = r.name, size = r.size, minLevel = r.minLevel or 60, ready = ready, online = online, progress = PvE.Progress(key) }
    end
  end
  return out
end

-- The guild's last raids (BlazonGuild's, once started): { title, at, n } the newest first.
function PvE.History(limit)
  BG.Honors.NoteRaids()
  local g = BG.Guild.Entry()
  local list = {}
  for _, e in pairs(g and g.attendance or {}) do
    if type(e) == "table" then
      list[#list + 1] = { title = e.title or "Raid", at = e.at or 0, n = #(e.names or {}) }
    end
  end
  table.sort(list, function(a, b)
    return a.at > b.at
  end)
  while #list > (limit or 8) do
    table.remove(list)
  end
  return list
end

-- Bosses defeated in all, and raids with every boss (for the guild ranking, GuildRanks.lua).
function PvE.Totals()
  local bosses, cleared = 0, 0
  for _, key in ipairs(PvE.ORDER) do
    local p = PvE.Progress(key)
    bosses = bosses + p.done
    if p.of and p.done >= p.of then
      cleared = cleared + 1
    end
  end
  return { bosses = bosses, cleared = cleared }
end

BG:On("BG_STORE_CHANGED", function(name)
  if name == "kills" then
    BG:Fire("BG_PVE_CHANGED")
  end
end)
