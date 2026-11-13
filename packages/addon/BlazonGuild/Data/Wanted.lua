-- «Se busca» (entrega 11; Olympus' Wanted.lua, MIT, our own implementation, for any guild and either faction).
--
-- A player of the other faction enters the list by himself, the moment a member's own client sees him kill that
-- member (the game's own death recap, read at PLAYER_DEAD) or be killed by that member (the game's PARTY_KILL,
-- our own killing blow only). Never COMBAT_LOG_EVENT_UNFILTERED: on Forever it is restricted, and registering it
-- shows the game's "blocked" pop-up (Olympus' notes, Wanted.lua). Open world only: never in an instance (a
-- battleground, an arena, a dungeon); a duel never kills, so it never counts.
-- The other faction is proven by this client, never typed: the race the game gives for that GUID
-- (GetPlayerInfoByGUID). A race of both factions, a pet, a creature or a hidden value never count.
--
-- Each member writes only their own rows ("wanted", id = their name); the organisers may delete an abusive one.
-- The bounty is worked out from the rows by every client the same way: a death adds 1 (2 when the killer was 10
-- or more levels above, or a "??"); a kill by a member pays the bounty plus 1 to that member and starts again.
-- Hunters: points of the last 90 days.
local _, BG = ...
local Wanted = { heard = {}, read = {}, saw = {}, stats = { deaths = 0, kills = 0, last = nil } }
BG.Wanted = Wanted
local Store, Names = BG.Store, BG.Names
local str, int = BG.Raids.Clean, BG.Raids.Int

local DAYS = 90
local BOUNTY_MAX = 20
local WANTED_AT = 3 -- the bounty at which the whole guild is told "se busca"
local RECAP_WINDOW = 20 -- seconds between the killing blow and reading it
local SIGHT_GAP = 300 -- one "cerca" notice per foe every five minutes
Wanted.DAYS, Wanted.WANTED_AT = DAYS, WANTED_AT

-- Races only one faction plays, by the game's file names (GetPlayerInfoByGUID's fourth value). Forever's
-- Skyborn are of both factions: not listed, so they prove nothing.
local HORDE = { Orc = true, Scourge = true, Undead = true, Tauren = true, Troll = true, BloodElf = true, Goblin = true,
  Nightborne = true, HighmountainTauren = true, MagharOrc = true, ZandalariTroll = true, Vulpera = true }
local ALLIANCE = { Human = true, Dwarf = true, NightElf = true, Gnome = true, Draenei = true, Worgen = true, VoidElf = true,
  LightforgedDraenei = true, DarkIronDwarf = true, KulTiran = true, Mechagnome = true }
local CLASSES = { WARRIOR = true, PALADIN = true, HUNTER = true, ROGUE = true, PRIEST = true, SHAMAN = true, MAGE = true,
  WARLOCK = true, DRUID = true, DEATHKNIGHT = true, MONK = true, DEMONHUNTER = true, EVOKER = true }

local function secret(...)
  if not issecretvalue then
    return false
  end
  for i = 1, select("#", ...) do
    if issecretvalue((select(i, ...))) then
      return true
    end
  end
  return false
end

local function inInstance()
  if not IsInInstance then
    return false
  end
  local ok, inside = pcall(IsInInstance)
  if not ok or secret(inside) then
    return true -- (not known: as if inside)
  end
  return inside == true
end

-- Shared rows ----------------------------------------------------------------------------------------------------
-- d = { k = "D" (a member died) | "K" (a member killed), foe, fc (class), fl (level; -1 = "??"), ml (member's
-- level), zone }
Store.Define("wanted", {
  ttl = DAYS * 86400,
  can = function(author, r)
    local prefix = author:gsub("%s", "") .. "-"
    if r.id:sub(1, #prefix) == prefix then
      return true
    end
    return r.del == true and Store.IsOrganiser(author) -- (an abusive row: the organisers take it off)
  end,
  normalize = function(d)
    local foe = Names.Short(str(d.foe, 40))
    if (d.k ~= "D" and d.k ~= "K") or not foe or foe == "" then
      return nil
    end
    return { k = d.k, foe = foe, fc = CLASSES[d.fc] and d.fc or nil, fl = int(d.fl, -1, 100), ml = int(d.ml, 1, 100), zone = str(d.zone, 60) }
  end,
})

function Wanted.Enabled()
  return not (BG.db and BG.db.settings and BG.db.settings.wantedOff)
end

function Wanted.SetEnabled(on)
  BG.db.settings.wantedOff = (not on) or nil
  BG:Fire("BG_WANTED_CHANGED")
  return true
end

-- Proof --------------------------------------------------------------------------------------------------------------
-- A player of the other faction, as this client proves it from his GUID: { name, class }, or nil and why.
function Wanted.FoeOf(guid, hint)
  if type(guid) ~= "string" or secret(guid) or not guid:find("^Player%-") then
    return nil, "no es jugador"
  end
  if not GetPlayerInfoByGUID then
    return nil, "facción"
  end
  local ok, _, class, _, race, _, name, realm = pcall(GetPlayerInfoByGUID, guid)
  if not ok or secret(class, race, name, realm) then
    return nil, "oculto"
  end
  local theirs = (HORDE[race] and "Horde") or (ALLIANCE[race] and "Alliance") or nil
  local mine = UnitFactionGroup and UnitFactionGroup("player")
  if not theirs or secret(mine) or theirs == mine then
    return nil, "facción"
  end
  local full
  if type(name) == "string" and name ~= "" then
    full = name
    local home = GetNormalizedRealmName and GetNormalizedRealmName() or ""
    if not name:find(" ", 1, true) and type(realm) == "string" and realm ~= "" and realm ~= home then
      full = name .. " " .. realm -- (Forever gives the surname where the realm usually goes)
    end
  elseif type(hint) == "string" and not secret(hint) then
    full = hint
  end
  full = Names.Short(str(full, 40))
  if not full or full == "" then
    return nil, "sin nombre"
  end
  return { name = full, class = CLASSES[class] and class or nil, guid = guid }
end

-- A level this client saw for that GUID: the target, the mouse's, the focus, a nameplate (nil if none).
local seenLevel = {}
function Wanted.LevelOf(guid)
  local units = { "target", "mouseover", "focus" }
  for i = 1, 40 do
    units[#units + 1] = "nameplate" .. i
  end
  for _, u in ipairs(units) do
    local ok, g = pcall(UnitGUID, u)
    if ok and g ~= nil and not secret(g) and g == guid then
      local okL, lvl = pcall(UnitLevel, u)
      if okL and type(lvl) == "number" and not secret(lvl) then
        return lvl
      end
    end
  end
  local s = seenLevel[guid]
  return s and GetTime() - s.t < 120 and s.l or nil
end

local function zoneText()
  local ok, z = pcall(GetRealZoneText or GetZoneText or function() return nil end)
  return ok and not secret(z) and str(z, 60) or nil
end

local function myLevel()
  local ok, l = pcall(UnitLevel, "player")
  return ok and not secret(l) and l or nil
end

-- Recording ----------------------------------------------------------------------------------------------------------
local function record(k, foe)
  if not Wanted.Enabled() then
    return nil, "apagado"
  end
  if not IsInGuild() or not BG.Guild.info then
    return nil, "sin hermandad"
  end
  local me = Names.Me()
  if not me then
    return nil, "sin personaje"
  end
  local id = me:gsub("%s", "") .. "-" .. Store.Now() .. BG.Alliance.RandomId(3)
  local before = Wanted.Foe(foe.name)
  local r, why = Store.Put("wanted", id, { k = k, foe = foe.name, fc = foe.class, fl = Wanted.LevelOf(foe.guid), ml = myLevel(), zone = zoneText() })
  if not r then
    return nil, why
  end
  Wanted.Invalidate()
  local after = Wanted.Foe(foe.name)
  if k == "D" then
    Wanted.stats.deaths = Wanted.stats.deaths + 1
    BG:Notify("Te ha matado " .. foe.name, "Ya está en «Se busca», con " .. (after and after.bounty or 1) .. " de recompensa. Quien de la hermandad lo cace se la lleva.",
      { kind = "warning", icon = "Interface\\Icons\\Ability_Rogue_FeignDeath", view = "pvp" })
  else
    Wanted.stats.kills = Wanted.stats.kills + 1
    local paid = (before and before.bounty or 0) + 1
    BG:Notify("Has cazado a " .. foe.name, "+" .. paid .. (paid == 1 and " punto" or " puntos") .. " de cazador" .. ((before and before.bounty or 0) > 0 and ": te llevas su recompensa." or "."),
      { kind = "success", icon = "Interface\\Icons\\Ability_Hunter_SniperShot", view = "pvp" })
  end
  BG:Fire("BG_WANTED_CHANGED")
  return r
end
Wanted.Record = record

-- Our own killing blow on a player of the other faction (the game's PARTY_KILL: attacker and target GUIDs).
function Wanted.PartyKill(attacker, target)
  if secret(attacker, target) then
    return nil, "oculto"
  end
  local me = UnitGUID("player")
  if type(attacker) ~= "string" or secret(me) or attacker ~= me then
    return nil, "no es mío"
  end
  if inInstance() then
    return nil, "instancia"
  end
  local foe, why = Wanted.FoeOf(target)
  if not foe then
    return nil, why
  end
  Wanted.stats.last = "baja: " .. foe.name
  return record("K", foe)
end

-- Our own death: the game's death recap, newest row first; the first with overkill 0 or more is the killing
-- blow (Blizzard_DeathRecap.lua). It counts when it is recent, damage, from a hostile player (flags 0x440 where
-- the row has flags), every row that names a victim names us, and the killer is of the other faction.
function Wanted.ReadDeath()
  local R = C_DeathRecap
  if type(R) ~= "table" or type(R.HasRecapEvents) ~= "function" or type(R.GetRecapEvents) ~= "function" then
    return nil, "sin resumen"
  end
  local okH, has = pcall(R.HasRecapEvents)
  if not okH or secret(has) or has ~= true then
    return nil, "sin resumen"
  end
  local okE, events = pcall(R.GetRecapEvents)
  if not okE or type(events) ~= "table" then
    return nil, "sin resumen"
  end
  local me = UnitGUID("player")
  if secret(me) then
    return nil, "oculto"
  end
  local kb
  for _, row in ipairs(events) do
    if type(row) == "table" then
      if secret(row.sourceGUID, row.sourceName, row.sourceFlags, row.event, row.overkill, row.timestamp, row.destGUID) then
        return nil, "oculto"
      end
      if type(row.destGUID) == "string" and row.destGUID ~= "" and row.destGUID ~= me then
        return nil, "no soy yo"
      end
      if not kb and type(row.overkill) == "number" and row.overkill >= 0 then
        kb = row
      end
    end
  end
  if not kb then
    return nil, "sin golpe"
  end
  local stamp = tonumber(kb.timestamp)
  local now = Store.Now()
  if not stamp or stamp < now - RECAP_WINDOW or stamp > now + 5 then
    return nil, "antiguo"
  end
  local key = tostring(kb.sourceGUID) .. "@" .. math.floor(stamp)
  if Wanted.read[key] then
    return nil, "ya leído"
  end
  Wanted.read[key] = true
  if inInstance() then
    return nil, "instancia"
  end
  if type(kb.event) ~= "string" or not kb.event:find("_DAMAGE$") then
    return nil, "no es daño"
  end
  local flags = kb.sourceFlags
  if flags ~= nil and not (type(flags) == "number" and bit and bit.band(flags, 0x440) == 0x440) then
    return nil, "no es hostil"
  end
  local foe, why = Wanted.FoeOf(kb.sourceGUID, kb.sourceName)
  if not foe then
    return nil, why
  end
  Wanted.stats.last = "muerte: " .. foe.name
  return record("D", foe)
end

-- The board ----------------------------------------------------------------------------------------------------------
local function gank(d)
  return d.fl == -1 or (d.fl ~= nil and d.ml ~= nil and d.fl - d.ml >= 10)
end
Wanted.Gank = gank

-- Every foe with its bounty, deaths and kills, and the hunters' points, from the rows (oldest first). Kept for a
-- minute, or until a row changes (nameplates ask often).
local cache
function Wanted.Invalidate()
  cache = nil
end

local function tally()
  if cache and GetTime() - cache.t < 60 then
    return cache.foes, cache.hunters
  end
  local rows = Store.List("wanted")
  table.sort(rows, function(a, b)
    if a.at ~= b.at then
      return a.at < b.at
    end
    return a.id < b.id
  end)
  local foes, hunters = {}, {}
  for _, r in ipairs(rows) do
    local d = r.d
    local f = foes[d.foe]
    if not f then
      f = { name = d.foe, bounty = 0, deaths = 0, kills = 0, victims = {}, ganks = 0 }
      foes[d.foe] = f
    end
    f.class = d.fc or f.class
    f.level = d.fl or f.level
    f.zone = d.zone or f.zone
    f.at = r.at
    if d.k == "D" then
      f.deaths = f.deaths + 1
      f.bounty = math.min(BOUNTY_MAX, f.bounty + (gank(d) and 2 or 1))
      f.ganks = f.ganks + (gank(d) and 1 or 0)
      f.lastVictim = r.by
      f.victims[r.by] = true
    else
      f.kills = f.kills + 1
      local h = hunters[r.by] or { name = r.by, n = 0, kills = 0 }
      hunters[r.by] = h
      h.n = h.n + f.bounty + 1
      h.kills = h.kills + 1
      f.lastHunter = r.by
      f.bounty = 0
    end
  end
  cache = { t = GetTime(), foes = foes, hunters = hunters }
  return foes, hunters
end

function Wanted.Foe(name)
  local foes = tally()
  return foes[Names.Short(name) or ""]
end

-- Foes with a bounty, the highest first (then the most recent).
function Wanted.Board()
  local foes = tally()
  local list = {}
  for _, f in pairs(foes) do
    if f.bounty > 0 then
      local n = 0
      for _ in pairs(f.victims) do
        n = n + 1
      end
      f.nVictims = n
      list[#list + 1] = f
    end
  end
  table.sort(list, function(a, b)
    if a.bounty ~= b.bounty then
      return a.bounty > b.bounty
    end
    return a.at > b.at
  end)
  return list
end

function Wanted.Hunters(limit)
  local _, hunters = tally()
  local list = {}
  for _, h in pairs(hunters) do
    list[#list + 1] = h
  end
  table.sort(list, function(a, b)
    if a.n ~= b.n then
      return a.n > b.n
    end
    return a.name < b.name
  end)
  for i = #list, (limit or 10) + 1, -1 do
    list[i] = nil
  end
  return list
end

-- The latest rows (what happened), newest first.
function Wanted.Recent(limit)
  local rows = Store.List("wanted")
  table.sort(rows, function(a, b)
    return a.at > b.at
  end)
  for i = #rows, (limit or 30) + 1, -1 do
    rows[i] = nil
  end
  return rows
end

function Wanted.CanRemove(r)
  local me = Names.Me() or ""
  return r ~= nil and (Store.IsOrganiser(me) or Names.Same(r.by, me))
end

function Wanted.Remove(id)
  local r = Store.Get("wanted", id)
  if not r or r.del then
    return nil, "no existe"
  end
  if not Wanted.CanRemove(r) then
    return nil, "permiso"
  end
  local ok, why = Store.Delete("wanted", id)
  Wanted.Invalidate()
  BG:Fire("BG_WANTED_CHANGED")
  return ok, why
end

-- Sightings: a wanted foe this client sees now (target, mouse, nameplate), told once every five minutes.
function Wanted.Observe(unit)
  if not unit or inInstance() then
    return
  end
  local okP, isPlayer = pcall(UnitIsPlayer, unit)
  if not okP or secret(isPlayer) or not isPlayer then
    return
  end
  local okG, guid = pcall(UnitGUID, unit)
  if not okG or secret(guid) or type(guid) ~= "string" then
    return
  end
  local okL, lvl = pcall(UnitLevel, unit)
  if okL and type(lvl) == "number" and not secret(lvl) then
    seenLevel[guid] = { l = lvl, t = GetTime() }
  end
  local name = Names.Unit(unit)
  local f = name and Wanted.Foe(name)
  if not f or f.bounty <= 0 then
    return
  end
  local last = Wanted.saw[f.name]
  if last and GetTime() - last < SIGHT_GAP then
    return
  end
  Wanted.saw[f.name] = GetTime()
  BG:Notify("Cerca: " .. f.name .. ", se busca", "Recompensa " .. f.bounty .. ". Ha matado a " .. f.deaths .. (f.deaths == 1 and " miembro" or " miembros") .. ". Cuidado.",
    { kind = "warning", icon = "Interface\\Icons\\Ability_Hunter_MarkedForDeath", view = "pvp" })
end

-- Events -------------------------------------------------------------------------------------------------------------
local deathSerial = 0
BG:On("PLAYER_DEAD", function()
  if not Wanted.Enabled() or not BG.Consent.Accepted() then
    return
  end
  deathSerial = deathSerial + 1
  local serial = deathSerial
  local ok, why = Wanted.ReadDeath()
  Wanted.stats.death = ok and ("apuntada: " .. tostring(Wanted.stats.last)) or ("no cuenta (" .. tostring(why) .. ")")
  if ok or why ~= "sin resumen" then
    return
  end
  -- (the game may fill the recap a moment after the death)
  for _, delay in ipairs({ 0.3, 1, 2 }) do
    C_Timer.After(delay, function()
      if serial == deathSerial and not ok and why == "sin resumen" then
        ok, why = Wanted.ReadDeath()
        Wanted.stats.death = ok and ("apuntada: " .. tostring(Wanted.stats.last)) or ("no cuenta (" .. tostring(why) .. ")")
      end
    end)
  end
end)

BG:On("PARTY_KILL", function(attacker, target)
  if Wanted.Enabled() and BG.Consent.Accepted() then
    local ok, why = Wanted.PartyKill(attacker, target)
    if type(target) == "string" and not secret(target) and target:find("^Player%-") then
      Wanted.stats.kill = ok and ("apuntada: " .. tostring(Wanted.stats.last)) or ("no cuenta (" .. tostring(why) .. ")")
    end
  end
end)

BG:On("NAME_PLATE_UNIT_ADDED", function(unit)
  Wanted.Observe(unit)
end)
BG:On("PLAYER_TARGET_CHANGED", function()
  Wanted.Observe("target")
end)
BG:On("UPDATE_MOUSEOVER_UNIT", function()
  Wanted.Observe("mouseover")
end)

-- Someone else's row: the guild hears when a foe becomes wanted, and when a member collects a bounty.
BG:On("BG_RECORD", function(kind, r, old)
  if kind ~= "wanted" then
    return
  end
  Wanted.Invalidate()
  if r.del or old then
    BG:Fire("BG_WANTED_CHANGED")
    return
  end
  local f = Wanted.Foe(r.d.foe)
  if not f then
    return
  end
  if r.d.k == "D" then
    local before = f.bounty - (gank(r.d) and 2 or 1)
    if f.bounty >= WANTED_AT and before < WANTED_AT then
      BG:Notify("Se busca: " .. f.name, "Ha matado a " .. r.by .. (r.d.zone and (" en " .. r.d.zone) or "") .. ". Recompensa " .. f.bounty .. ".",
        { kind = "warning", icon = "Interface\\Icons\\Ability_Hunter_MarkedForDeath", view = "pvp" })
    end
  elseif f.lastHunter and Names.Same(f.lastHunter, r.by) then
    BG:Notify(r.by .. " ha cazado a " .. f.name, (r.d.zone and ("En " .. r.d.zone .. ". ") or "") .. "Le cuenta en el ranking de cazadores.",
      { kind = "success", icon = "Interface\\Icons\\Ability_Hunter_SniperShot", view = "pvp" })
  end
  BG:Fire("BG_WANTED_CHANGED")
end)

BG:On("BG_STORE_CHANGED", function(name)
  if name == "wanted" then
    Wanted.Invalidate()
    BG:Fire("BG_WANTED_CHANGED")
  end
end)
