-- Player names on WoW: Forever. Names are "First Surname" and are unique across the region, so the
-- short form is the identity everywhere in BlazonGuild. The client hands the surname back where the
-- realm usually goes (UnitName("player") gives "El"; UnitFullName gives "El", "Peregrino"), and the
-- server stamps addon messages "First Surname" or "First Surname-Realm". Verified in-game with the
-- probe (2026-11-12) and matching Olympus's notes (Core.lua, MIT).
local _, BG = ...
local Names = {}
BG.Names = Names

local function secret(v)
  return issecretvalue ~= nil and issecretvalue(v)
end

-- "El Peregrino-ClassicPvP" -> "El Peregrino". Realm names have no spaces.
-- The game's own functions and events can also hand a name as "El-Peregrino": on Forever the surname goes where a
-- realm would (UnitFullName gives "El", "Peregrino"; Olympus measured it and turns those names back with its
-- ns.Normal, MIT). Every character there has a surname, so a name without a space takes its first dash as the space
-- between both, unless what follows is our own realm.
function Names.Short(name)
  if type(name) ~= "string" or secret(name) then
    return nil
  end
  if not name:find(" ", 1, true) then
    local first, rest = name:match("^([^%-]+)%-(.+)$")
    if first then
      local home = GetNormalizedRealmName and GetNormalizedRealmName() or ""
      if rest ~= home then
        name = first .. " " .. rest
      end
    end
  end
  local base = name:match("^(.-)%-[^%s%-]+$")
  return base and base ~= "" and base or name
end

function Names.Same(a, b)
  local sa, sb = Names.Short(a), Names.Short(b)
  return sa ~= nil and sa == sb
end

-- Our own name as the server writes it. The roster entry found by GUID is authoritative; before the
-- roster arrives, the two halves from UnitFullName are joined when the "realm" is not our realm.
function Names.Me()
  local me = BG.Guild and BG.Guild.me
  if me and me.name then
    return Names.Short(me.name)
  end
  if not UnitFullName then
    return nil
  end
  local first, second = UnitFullName("player") -- (an "and" here would drop the second value)
  if secret(first) or secret(second) then
    return nil
  end
  if not first or first == "" then
    return nil
  end
  local realm = GetNormalizedRealmName and GetNormalizedRealmName() or ""
  if second and second ~= "" and second ~= realm then
    return first .. " " .. second
  end
  return first
end

-- The name a whisper takes: Forever's server finds "First Surname" but refuses "First Surname-Realm".
function Names.Tell(name)
  return Names.Short(name)
end

-- A unit's name ("target", "party1"...) as "First Surname", or nil (not a player, or hidden by the game).
function Names.Unit(unit)
  if not UnitFullName then
    return nil
  end
  local ok, first, second = pcall(UnitFullName, unit)
  if not ok or secret(first) or secret(second) or type(first) ~= "string" or first == "" then
    return nil
  end
  if first:find(" ", 1, true) then
    return first
  end
  local realm = GetNormalizedRealmName and GetNormalizedRealmName() or ""
  if type(second) == "string" and second ~= "" and second ~= realm then
    return first .. " " .. second
  end
  return first
end

function Names.IsMe(name)
  local me = Names.Me()
  return me ~= nil and Names.Same(name, me)
end
