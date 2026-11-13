-- BlazonGuild visual language in-game: the web's Hybrid tokens (docs/specs/ART_DIRECTION_V1.md, DESIGN_SYSTEM.md).
local _, BG = ...

local function rgb(hex)
  return tonumber(hex:sub(1, 2), 16) / 255, tonumber(hex:sub(3, 4), 16) / 255, tonumber(hex:sub(5, 6), 16) / 255
end

BG.color = {
  canvas = { rgb("0b0e13") }, sunken = { rgb("10141c") }, surface = { rgb("151b24") }, elevated = { rgb("222c38") },
  line = { rgb("242e3c") }, lineStrong = { rgb("687589") },
  text = { rgb("e7eaf0") }, text2 = { rgb("aab3c1") }, text3 = { rgb("8a94a3") },
  gold = { rgb("d0b078") }, goldHi = { rgb("e6cc98") }, goldTitle = { rgb("f0d48f") }, goldDeep = { rgb("8f6a2b") },
  success = { rgb("56b98a") }, warning = { rgb("e3ad54") }, danger = { rgb("e47880") }, info = { rgb("6da8e8") },
  horde = { rgb("ec766a") }, alliance = { rgb("6896e6") },
}

function BG.hex(c)
  return string.format("ff%02x%02x%02x", math.floor(c[1] * 255 + 0.5), math.floor(c[2] * 255 + 0.5), math.floor(c[3] * 255 + 0.5))
end

function BG.colorize(text, c)
  return "|c" .. BG.hex(c) .. text .. "|r"
end

-- Fonts that ship with the game client. Friz Quadrata is the house serif of Warcraft's interface.
BG.font = { display = "Fonts\\FRIZQT__.TTF", body = "Fonts\\FRIZQT__.TTF", narrow = "Fonts\\ARIALN.TTF" }

-- Class identity: same hues as the web (RAID_CLASS_COLORS is the game's own source when present).
local CLASS_FALLBACK = {
  WARRIOR = "c69b6d", PALADIN = "f48cba", HUNTER = "aad372", ROGUE = "fff468", PRIEST = "ffffff", SHAMAN = "0070dd",
  MAGE = "3fc7eb", WARLOCK = "8788ee", DRUID = "ff7c0a",
}

function BG.classColor(classFile)
  local c = RAID_CLASS_COLORS and RAID_CLASS_COLORS[classFile]
  if c then
    return { c.r, c.g, c.b }
  end
  return { rgb(CLASS_FALLBACK[classFile] or "aab3c1") }
end

local CLASS_COORDS = {
  WARRIOR = { 0, 0.25, 0, 0.25 }, MAGE = { 0.25, 0.49609375, 0, 0.25 }, ROGUE = { 0.49609375, 0.7421875, 0, 0.25 },
  DRUID = { 0.7421875, 0.98828125, 0, 0.25 }, HUNTER = { 0, 0.25, 0.25, 0.5 }, SHAMAN = { 0.25, 0.49609375, 0.25, 0.5 },
  PRIEST = { 0.49609375, 0.7421875, 0.25, 0.5 }, WARLOCK = { 0.7421875, 0.98828125, 0.25, 0.5 }, PALADIN = { 0, 0.25, 0.5, 0.75 },
}

function BG.setClassIcon(tex, classFile)
  local coords = (CLASS_ICON_TCOORDS and CLASS_ICON_TCOORDS[classFile]) or CLASS_COORDS[classFile]
  if coords then
    tex:SetTexture("Interface\\TargetingFrame\\UI-Classes-Circles")
    tex:SetTexCoord(coords[1], coords[2], coords[3], coords[4])
  else
    tex:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
    tex:SetTexCoord(0.08, 0.92, 0.08, 0.92)
  end
end

-- Game file that may not exist in this client: fall back instead of drawing a hole.
function BG.file(path, fallback)
  if GetFileIDFromPath and not GetFileIDFromPath(path) then
    if fallback == false then
      return nil -- the caller tries something else
    end
    return fallback or "Interface\\Icons\\INV_Misc_QuestionMark"
  end
  return path
end

-- Official art per faction, verified present in the WoW: Forever client by the probe.
BG.art = {
  ALLIANCE = "Interface\\Glues\\LoadingScreens\\LoadScreenEasternKingdom",
  HORDE = "Interface\\Glues\\LoadingScreens\\LoadScreenKalimdor",
  RAID = "Interface\\Glues\\LoadingScreens\\LoadScreenMoltenCore",
  BWL = "Interface\\Glues\\LoadingScreens\\LoadScreenBlackwingLair",
  MC_JOURNAL = "Interface\\EncounterJournal\\UI-EJ-BACKGROUND-MoltenCore",
}

-- Art for a raid or dungeon key: its own loading screen or journal background when this client has it
-- (checked with BG.file, which falls back), else the faction's loading screen.
local INSTANCE_ART = {
  BARROW = { "Interface\\Glues\\LoadingScreens\\LoadScreenKalimdor" },
  HYJAL = { "Interface\\Glues\\LoadingScreens\\LoadScreenKalimdor" },
  MC = { "Interface\\Glues\\LoadingScreens\\LoadScreenMoltenCore" },
  BWL = { "Interface\\Glues\\LoadingScreens\\LoadScreenBlackwingLair" },
  ONY = { "Interface\\EncounterJournal\\UI-EJ-BACKGROUND-OnyxiasLair", "Interface\\Glues\\LoadingScreens\\LoadScreenOnyxiasLair" },
  ZG = { "Interface\\EncounterJournal\\UI-EJ-BACKGROUND-ZulGurub", "Interface\\Glues\\LoadingScreens\\LoadScreenZulGurub" },
  AQ20 = { "Interface\\EncounterJournal\\UI-EJ-BACKGROUND-RuinsofAhnQiraj", "Interface\\Glues\\LoadingScreens\\LoadScreenAhnQiraj" },
  AQ40 = { "Interface\\EncounterJournal\\UI-EJ-BACKGROUND-TempleofAhnQiraj", "Interface\\Glues\\LoadingScreens\\LoadScreenAhnQiraj" },
  NAXX = { "Interface\\EncounterJournal\\UI-EJ-BACKGROUND-Naxxramas", "Interface\\Glues\\LoadingScreens\\LoadScreenNaxxramas" },
  UBRS = { "Interface\\Glues\\LoadingScreens\\LoadScreenBlackwingLair" },
  BRD = { "Interface\\LFGFrame\\UI-LFG-BACKGROUND-BlackrockDepths" },
  LBRS = { "Interface\\LFGFrame\\UI-LFG-BACKGROUND-BlackrockSpire" },
  STRAT = { "Interface\\LFGFrame\\UI-LFG-BACKGROUND-Stratholme" },
  SCHOLO = { "Interface\\LFGFrame\\UI-LFG-BACKGROUND-Scholomance" },
  SM = { "Interface\\LFGFrame\\UI-LFG-BACKGROUND-ScarletMonastery" },
  DM = { "Interface\\LFGFrame\\UI-LFG-BACKGROUND-Deadmines" },
  WC = { "Interface\\LFGFrame\\UI-LFG-BACKGROUND-WailingCaverns" },
}
local artCache = {}
function BG.ArtFor(key)
  if artCache[key] then
    return artCache[key]
  end
  local faction = BG.Guild and BG.Guild.info and BG.Guild.info.faction
  local found = BG.art[faction or "ALLIANCE"] or BG.art.ALLIANCE
  for _, path in ipairs(INSTANCE_ART[key] or {}) do
    local candidate = BG.file(path, false)
    if candidate then
      found = candidate
      break
    end
  end
  artCache[key] = found
  return found
end

-- Official role icons (the game's group finder sheet: 256 px, 67 px cells).
local ROLE_CELL = { TANK = { 1, 2 }, HEALER = { 2, 1 }, DPS = { 2, 2 } }
function BG.setRoleIcon(tex, role)
  local c = ROLE_CELL[role] or ROLE_CELL.DPS
  local s = 67 / 256
  tex:SetTexture("Interface\\LFGFrame\\UI-LFG-ICON-ROLES")
  tex:SetTexCoord((c[1] - 1) * s, c[1] * s, (c[2] - 1) * s, c[2] * s)
end
