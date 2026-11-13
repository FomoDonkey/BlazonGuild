-- Guild data straight from the game client: roster, ranks and derived statistics.
-- Everything here is live and authoritative for the player's own guild (the game server provides it).
local _, BG = ...

local Guild = { members = {}, byGuid = {}, byName = {}, info = nil, stats = nil, scannedAt = nil, fromCache = false }
BG.Guild = Guild

-- The member with this name ("First Surname", with or without "-Realm"), or nil.
function Guild.Find(name)
  local short = BG.Names.Short(name)
  return short and Guild.byName[short] or nil
end

local function indexByName(members)
  local byName = {}
  for _, m in ipairs(members) do
    local short = BG.Names.Short(m.fullName or m.name)
    if short then
      byName[short] = m
    end
  end
  return byName
end
Guild.IndexByName = indexByName

function Guild.MaxLevel()
  if GetMaxLevelForPlayerExpansion then
    local ok, lvl = pcall(GetMaxLevelForPlayerExpansion)
    if ok and lvl and lvl > 0 then
      return lvl
    end
  end
  return 60
end

-- Days since last seen; nil when the client does not say.
local function lastOnlineDays(i)
  if not GetGuildRosterLastOnline then
    return nil
  end
  local ok, years, months, days, hours = pcall(GetGuildRosterLastOnline, i)
  if not ok or years == nil then
    return nil
  end
  return years * 365 + (months or 0) * 30 + (days or 0) + (hours or 0) / 24
end

-- One roster row. Shape verified in-game by the probe (17 values, GUID last).
-- reuse (optional): the last scan's members by GUID. The row goes into that member's own table, field by field, so a
-- big guild's every update does not make a new table per member; the second value says whether anything changed.
function Guild.ReadRow(i, reuse)
  local name, rankName, rankIndex, level, className, zone, publicNote, _, isOnline, status, classFile, achievementPoints, _, isMobile, _, _, guid = GetGuildRosterInfo(i)
  if not name then
    return nil
  end
  local m = reuse and guid and reuse[guid]
  local changed = m == nil
  m = m or {}
  local display = Ambiguate and Ambiguate(name, "guild") or name
  local online, mobile = isOnline and true or false, isMobile and true or false
  local ach = (achievementPoints and achievementPoints >= 0) and achievementPoints or nil
  local away = isOnline and 0 or lastOnlineDays(i)
  level, status = level or 0, status or 0
  if m.name ~= display or m.fullName ~= name or m.guid ~= guid or m.rank ~= rankName or m.rankIndex ~= rankIndex or m.level ~= level
    or m.className ~= className or m.classFile ~= classFile or m.zone ~= zone or m.note ~= publicNote or m.online ~= online
    or m.status ~= status or m.mobile ~= mobile or m.achievements ~= ach or m.lastOnlineDays ~= away then
    m.name, m.fullName, m.guid, m.rank, m.rankIndex, m.level = display, name, guid, rankName, rankIndex, level
    m.className, m.classFile, m.zone, m.note, m.online = className, classFile, zone, publicNote, online
    m.status, m.mobile, m.achievements, m.lastOnlineDays = status, mobile, ach, away
    changed = true
  end
  return m, changed
end

-- Pure: statistics shown in the overview. Kept free of WoW calls so it can be tested offline.
function Guild.BuildStats(members, maxLevel)
  maxLevel = maxLevel or 60
  local s = { total = #members, online = 0, levelSum = 0, atMax = 0, byClass = {}, byRank = {}, onlineList = {}, bands = { 0, 0, 0, 0 } }
  local classIndex = {}
  for _, m in ipairs(members) do
    s.levelSum = s.levelSum + m.level
    if m.level >= maxLevel then
      s.atMax = s.atMax + 1
    end
    if m.online then
      s.online = s.online + 1
      s.onlineList[#s.onlineList + 1] = m
    end
    local band = m.level >= maxLevel and 1 or (m.level >= maxLevel - 5 and 2 or (m.level >= maxLevel - 15 and 3 or 4))
    s.bands[band] = s.bands[band] + 1
    local c = classIndex[m.classFile or "?"]
    if not c then
      c = { classFile = m.classFile, className = m.className, count = 0 }
      classIndex[m.classFile or "?"] = c
      s.byClass[#s.byClass + 1] = c
    end
    c.count = c.count + 1
    local r = m.rankIndex or -1
    s.byRank[r] = (s.byRank[r] or 0) + 1
  end
  s.avgLevel = s.total > 0 and s.levelSum / s.total or 0
  table.sort(s.byClass, function(a, b)
    if a.count ~= b.count then
      return a.count > b.count
    end
    return (a.className or "") < (b.className or "")
  end)
  table.sort(s.onlineList, function(a, b)
    if a.level ~= b.level then
      return a.level > b.level
    end
    return a.name < b.name
  end)
  return s
end

-- Pure: sort a member list by a column; ties always fall back to the name so the order is stable.
local SORT_KEYS = {
  name = function(m) return m.name:lower() end,
  level = function(m) return m.level end,
  rank = function(m) return m.rankIndex or 99 end,
  class = function(m) return (m.className or ""):lower() end,
  zone = function(m) return (m.zone or ""):lower() end,
  seen = function(m) return m.online and -1 or (m.lastOnlineDays or 1e9) end,
  achievements = function(m) return m.achievements or -1 end,
}

function Guild.Sort(list, key, ascending)
  local get = SORT_KEYS[key] or SORT_KEYS.name
  table.sort(list, function(a, b)
    local va, vb = get(a), get(b)
    if va ~= vb then
      if ascending then
        return va < vb
      end
      return va > vb
    end
    return a.name:lower() < b.name:lower()
  end)
  return list
end

-- Pure: text search across name, rank, class and zone (plain match, case-insensitive).
function Guild.Filter(members, query, onlineOnly)
  local q = query and query ~= "" and query:lower() or nil
  local out = {}
  for _, m in ipairs(members) do
    if (not onlineOnly or m.online) and (not q
      or m.name:lower():find(q, 1, true)
      or (m.rank or ""):lower():find(q, 1, true)
      or (m.className or ""):lower():find(q, 1, true)
      or (m.zone or ""):lower():find(q, 1, true)) then
      out[#out + 1] = m
    end
  end
  return out
end

-- Live scan -------------------------------------------------------------------------------------

local function region()
  return GetCurrentRegionName and GetCurrentRegionName() or tostring(GetCurrentRegion and GetCurrentRegion() or "?")
end

-- How other guilds know ours (the alliance's records): the region and the name.
local function guildKey(name)
  return region() .. "|" .. name
end

-- Where this computer keeps a guild's data: also its realm and its faction, so two different guilds with the same
-- name (one of each faction, or on another realm) never share it, even with characters of both on one account.
local function homeKey(name, guildRealm, faction)
  local realm = guildRealm and guildRealm ~= "" and guildRealm or (GetNormalizedRealmName and GetNormalizedRealmName()) or "?"
  return region() .. "|" .. realm .. "|" .. (faction or "?") .. "|" .. name
end
Guild.HomeKey = homeKey

-- This guild's saved entry (its records, chat, cache), made if it is not there yet.
function Guild.Entry()
  local home = Guild.info and Guild.info.home
  if not home then
    return nil
  end
  BG.db.guilds[home] = BG.db.guilds[home] or {}
  return BG.db.guilds[home]
end

-- Data saved by versions before 0.19.1 under "region|name": it goes to this guild if it was of this faction (or
-- did not say); the entry of the other faction's guild of the same name stays where it is, never mixed.
local function adopt(key, home, faction)
  local old = BG.db.guilds[key]
  if BG.db.guilds[home] or not old then
    return
  end
  local was = old.info and old.info.faction
  if was == nil or was == faction then
    BG.db.guilds[home], BG.db.guilds[key] = old, nil
  end
end

function Guild.Request()
  if not IsInGuild() then
    return
  end
  if C_GuildInfo and C_GuildInfo.GuildRoster then
    C_GuildInfo.GuildRoster()
  end
end

local scratchMembers, scratchByGuid = {}, {}
function Guild.Scan()
  if BG.demo then
    return -- (the capture mode's example guild stays on screen until it ends: Core/Demo.lua)
  end
  if not IsInGuild() then
    Guild.info, Guild.stats, Guild.members, Guild.byGuid, Guild.byName, Guild.me = nil, nil, {}, {}, {}, nil
    BG:Fire("BG_ROSTER_UPDATED")
    return
  end
  local guildName, myRank, myRankIndex, guildRealm = GetGuildInfo("player")
  local total = GetNumGuildMembers()
  if not guildName or not total or total == 0 then
    return -- the client has not received the roster yet
  end
  -- Each member into their own table from the last scan (Guild.ReadRow). The game sends a roster update often, and
  -- most of the times nothing changed: then nothing is rebuilt and nobody is told (the result would be the same).
  local old, before = Guild.byGuid or {}, #(Guild.members or {})
  local members, byGuid = scratchMembers, scratchByGuid -- (made into the new lists only when something changed)
  wipe(members)
  wipe(byGuid)
  local changed = Guild.fromCache or Guild.info == nil
  for i = 1, total do
    local m, rowChanged = Guild.ReadRow(i, old)
    if m then
      members[#members + 1] = m
      if m.guid then
        byGuid[m.guid] = m
      end
      changed = changed or rowChanged
    end
  end
  changed = changed or #members ~= before -- (the same count and no one new: the same people)
  local ranks = {}
  for i = 1, (GuildControlGetNumRanks and GuildControlGetNumRanks() or 0) do
    ranks[i - 1] = GuildControlGetRankName(i) -- rankIndex is 0-based in the roster
  end
  local faction = UnitFactionGroup("player")
  faction = faction and faction:upper() or nil
  local motd = GetGuildRosterMOTD and GetGuildRosterMOTD() or nil
  local was = Guild.info
  if not changed and was and was.name == guildName and was.myRank == myRank and was.myRankIndex == myRankIndex
    and was.faction == faction and was.motd == motd and #was.ranks == #ranks then
    local same = true
    for i = 0, #ranks do
      same = same and was.ranks[i] == ranks[i]
    end
    if same then
      Guild.scannedAt = time()
      return
    end
  end
  scratchMembers, scratchByGuid = {}, {}
  Guild.info = {
    name = guildName, key = guildKey(guildName), home = homeKey(guildName, guildRealm, faction), myRank = myRank,
    myRankIndex = myRankIndex, ranks = ranks, faction = faction, motd = motd,
  }
  adopt(Guild.info.key, Guild.info.home, faction)
  Guild.members, Guild.byGuid, Guild.byName = members, byGuid, indexByName(members)
  Guild.me = byGuid[UnitGUID("player")]
  Guild.stats = Guild.BuildStats(members, Guild.MaxLevel())
  Guild.scannedAt, Guild.fromCache = time(), false

  -- Cache so the window shows the guild instantly on the next login, before the server answers.
  -- (Update in place: the same entry also keeps the shared records, Store.lua, which a rescan must never drop.)
  local entry = Guild.Entry()
  entry.info, entry.members, entry.scannedAt = Guild.info, members, Guild.scannedAt
  BG.db.characters = BG.db.characters or {}
  BG.db.characters[UnitGUID("player")] = Guild.info.home
  -- The account's characters (saved data is shared by all of them): lets People.lua confirm alts.
  BG.db.characterInfo = BG.db.characterInfo or {}
  if Guild.me then
    BG.db.characterInfo[UnitGUID("player")] = { name = BG.Names.Short(Guild.me.name), key = Guild.info.home, class = Guild.me.classFile, level = Guild.me.level, at = time() }
  end
  BG:Fire("BG_ROSTER_UPDATED")
end

function Guild.LoadCache()
  local key = BG.db.characters and BG.db.characters[UnitGUID("player")]
  local cached = key and BG.db.guilds[key]
  if not cached or Guild.info then
    return
  end
  Guild.info, Guild.members, Guild.scannedAt, Guild.fromCache = cached.info, cached.members, cached.scannedAt, true
  Guild.byGuid = {}
  for _, m in ipairs(cached.members) do
    m.online = false -- presence from a cache is never shown as live
    if m.guid then
      Guild.byGuid[m.guid] = m
    end
  end
  Guild.byName = indexByName(Guild.members)
  Guild.me = Guild.byGuid[UnitGUID("player")]
  Guild.stats = Guild.BuildStats(Guild.members, Guild.MaxLevel())
  BG:Fire("BG_ROSTER_UPDATED")
end

local pending = false
local function scheduleScan()
  if pending then
    return
  end
  pending = true
  C_Timer.After(0.4, function()
    pending = false
    Guild.Scan()
  end)
end

BG:On("PLAYER_LOGIN", function()
  Guild.LoadCache()
  Guild.Request()
end)
BG:On("GUILD_ROSTER_UPDATE", scheduleScan)
BG:On("PLAYER_GUILD_UPDATE", scheduleScan)
