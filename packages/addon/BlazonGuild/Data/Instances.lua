-- Raids and dungeons of WoW: Forever (checked 2026-11-13 against Blizzard's «Raid Overview» and, for the names, the
-- game client's own English and Spanish names as «The Forever Era» lists them). Forever has 28 dungeons: 19 of the
-- classic era and 9 new ones. Its raids open on 9 December 2026: The Barrow Deeps (10 players, 8 bosses), Hyjal
-- Summit (20, 13) and Onyxia's Lair (40). Molten Core, Blackwing Lair, Zul'Gurub, Ahn'Qiraj and Naxxramas are not in
-- Forever (Blizzard has not announced them): they stay only as `legacy`, never offered, so a raid an older version
-- saved still reads. `alias`: the names the game may give the place in other languages (PvE.lua reads them).
-- The dungeons' levels are the usual ranges (the guides do not all agree); the keys keep the web's, the new ones
-- Olympus' (MIT).
local _, BG = ...
local Instances = {}
BG.Instances = Instances

Instances.raids = {
  { key = "BARROW", name = "Cavernas del Túmulo", size = 10, minLevel = 60, zone = "Monte Hyjal", alias = { "The Barrow Deeps", "Barrow Deeps" } },
  { key = "HYJAL", name = "Cima Hyjal", size = 20, minLevel = 60, zone = "Monte Hyjal", alias = { "Hyjal Summit" } },
  { key = "ONY", name = "Guarida de Onyxia", size = 40, minLevel = 60, zone = "Marjal Revolcafango", alias = { "Onyxia's Lair" } },
  { key = "DUNGEON", name = "Mazmorra (5 jugadores)", size = 5 },
  { key = "OTHER", name = "Otra actividad", size = 40 },
  -- not in Forever (see above)
  { key = "MC", name = "Núcleo de Magma", size = 40, minLevel = 60, legacy = true },
  { key = "BWL", name = "Guarida Alanegra", size = 40, minLevel = 60, legacy = true },
  { key = "ZG", name = "Zul'Gurub", size = 20, minLevel = 58, legacy = true },
  { key = "AQ20", name = "Ruinas de Ahn'Qiraj", size = 20, minLevel = 60, legacy = true },
  { key = "AQ40", name = "Templo de Ahn'Qiraj", size = 40, minLevel = 60, legacy = true },
  { key = "NAXX", name = "Naxxramas", size = 40, minLevel = 60, legacy = true },
  { key = "UBRS", name = "Cumbre de Roca Negra Superior", size = 10, minLevel = 55, legacy = true },
}

-- faction: only those inside or beneath a capital (the other faction cannot get in); the rest are for everyone.
Instances.dungeons = {
  { key = "RFC", name = "Sima Ígnea", zone = "Orgrimmar", min = 13, max = 18, faction = "HORDE" },
  { key = "THANES", name = "Salón de los Feudales", zone = "Forjaz", min = 13, max = 18, faction = "ALLIANCE", new = true },
  { key = "RUINS", name = "Ruinas de Lordaeron", zone = "Claros de Tirisfal", min = 15, max = 20, faction = "HORDE", new = true },
  { key = "WC", name = "Cuevas de los Lamentos", zone = "Los Baldíos", min = 17, max = 24 },
  { key = "DM", name = "Minas de la Muerte", zone = "Páramos de Poniente", min = 17, max = 26 },
  { key = "SFK", name = "Castillo de Colmillo Oscuro", zone = "Bosque de Argénteos", min = 22, max = 30 },
  { key = "BFD", name = "Cavernas de Brazanegra", zone = "Vallefresno", min = 24, max = 32 },
  { key = "STOCKS", name = "Las Mazmorras", zone = "Ventormenta", min = 24, max = 32, faction = "ALLIANCE" },
  { key = "EXCAV", name = "Excavación: Los Humedales", zone = "Los Humedales", min = 24, max = 29, new = true },
  { key = "DALA", name = "Ciudad de Dalaran", zone = "Montañas de Alterac", min = 28, max = 33, new = true },
  { key = "GNOMER", name = "Gnomeregan", zone = "Dun Morogh", min = 29, max = 38 },
  { key = "RFK", name = "Horado Rajacieno", zone = "Los Baldíos", min = 29, max = 38 },
  { key = "SM", name = "Monasterio Escarlata", zone = "Claros de Tirisfal", min = 30, max = 46 },
  { key = "DROWN", name = "La Ciudad Sumergida", zone = "Vega de Tuercespina", min = 35, max = 40, new = true },
  { key = "RFD", name = "Zahúrda Rajacieno", zone = "Los Baldíos", min = 37, max = 46 },
  { key = "KROL", name = "Bastión Krol'dok", zone = "Clarofluvial", min = 40, max = 45, new = true },
  { key = "ULDA", name = "Uldaman", zone = "Tierras Inhóspitas", min = 41, max = 51 },
  { key = "ZF", name = "Zul'Farrak", zone = "Tanaris", min = 44, max = 54 },
  { key = "MARA", name = "Maraudon", zone = "Desolace", min = 46, max = 55 },
  { key = "ALCAZ", name = "Prisión de Alcaz", zone = "Marjal Revolcafango", min = 48, max = 53, new = true },
  { key = "ST", name = "Templo de Atal'Hakkar", zone = "Pantano de las Penas", min = 50, max = 60 },
  { key = "BRD", name = "Profundidades de Roca Negra", zone = "Montaña Roca Negra", min = 52, max = 60 },
  { key = "DIREMAUL", name = "La Masacre", zone = "Feralas", min = 54, max = 60 },
  { key = "LBRS", name = "Cumbre de Roca Negra Inferior", zone = "Montaña Roca Negra", min = 55, max = 60 },
  { key = "BLACKM", name = "Bastión Faucenegra", zone = "Azshara", min = 55, max = 60, new = true },
  { key = "SHAPER", name = "Bancal del Creador", zone = "Cráter de Un'Goro", min = 58, max = 60, new = true },
  { key = "STRAT", name = "Stratholme", zone = "Tierras de la Peste del Este", min = 58, max = 60 },
  { key = "SCHOLO", name = "Scholomance", zone = "Tierras de la Peste del Oeste", min = 58, max = 60 },
  { key = "UBRS", name = "Cumbre de Roca Negra Superior", zone = "Montaña Roca Negra", min = 58, max = 60, size = 10 },
}

-- The raids a player may pick (Forever's, and the two kinds of activity), plus `current` when an old raid uses one
-- that is not in Forever (so editing it does not change what it was).
function Instances.RaidOptions(current)
  local out = {}
  for _, r in ipairs(Instances.raids) do
    if not r.legacy or r.key == current then
      out[#out + 1] = r
    end
  end
  return out
end

-- Groups for other things than a dungeon or a raid (Grupos): same roles, five places by default.
Instances.activities = {
  { key = "ACT_PVP", name = "JcJ: campos de batalla", size = 5, icon = "Interface\\Icons\\Ability_DualWield" },
  { key = "ACT_QUEST", name = "Misiones en grupo", size = 5, icon = "Interface\\Icons\\INV_Misc_Note_01" },
  { key = "ACT_LEVEL", name = "Subir de nivel juntos", size = 5, icon = "Interface\\Icons\\INV_Misc_Book_11" },
  { key = "ACT_FARM", name = "Farmear y recoger", size = 5, icon = "Interface\\Icons\\INV_Misc_Herb_07" },
  { key = "ACT_OTHER", name = "Otra cosa", size = 5, icon = "Interface\\Icons\\INV_Misc_QuestionMark" },
}

local raidByKey, dungeonByKey, activityByKey = {}, {}, {}
for _, a in ipairs(Instances.activities) do
  activityByKey[a.key] = a
end
for _, r in ipairs(Instances.raids) do
  raidByKey[r.key] = r
end
for _, d in ipairs(Instances.dungeons) do
  dungeonByKey[d.key] = d
end

function Instances.Raid(key)
  return raidByKey[key]
end

function Instances.Dungeon(key)
  return dungeonByKey[key]
end

function Instances.Activity(key)
  return activityByKey[key]
end

-- Anything a group can be for: a dungeon, a raid or another activity.
function Instances.Any(key)
  return dungeonByKey[key] or raidByKey[key] or activityByKey[key]
end

-- Dungeons that suit a level (inside the range, or a few levels around it), for the given faction.
function Instances.DungeonsFor(level, faction)
  local out = {}
  for _, d in ipairs(Instances.dungeons) do
    if (not d.faction or d.faction == faction) and (not level or (level >= d.min - 3 and level <= d.max + 2)) then
      out[#out + 1] = d
    end
  end
  return out
end

-- Roles: same values as the web (TANK, HEALER, DPS) and the role each class can fill.
Instances.roles = {
  { key = "TANK", name = "Tanque", short = "T", icon = "Interface\\Icons\\Ability_Defend" },
  { key = "HEALER", name = "Sanador", short = "S", icon = "Interface\\Icons\\Spell_Holy_Heal" },
  { key = "DPS", name = "Daño", short = "D", icon = "Interface\\Icons\\Ability_SteelMelee" },
}
local roleByKey = {}
for _, r in ipairs(Instances.roles) do
  roleByKey[r.key] = r
end
function Instances.Role(key)
  return roleByKey[key]
end

local CLASS_ROLES = {
  WARRIOR = { "TANK", "DPS" }, PALADIN = { "HEALER", "TANK", "DPS" }, HUNTER = { "DPS" }, ROGUE = { "DPS" },
  PRIEST = { "HEALER", "DPS" }, SHAMAN = { "HEALER", "DPS" }, MAGE = { "DPS" }, WARLOCK = { "DPS" },
  DRUID = { "HEALER", "TANK", "DPS" },
}
function Instances.RolesFor(classFile)
  return CLASS_ROLES[classFile] or { "TANK", "HEALER", "DPS" }
end

-- Default composition per size, as the web's groupComposition (5: 1/1/3, 10: 2/3/5) and usual raid splits.
function Instances.Composition(size)
  if size >= 40 then
    return { TANK = 4, HEALER = 10, DPS = 26 }
  elseif size >= 20 then
    return { TANK = 2, HEALER = 5, DPS = 13 }
  elseif size >= 10 then
    return { TANK = 2, HEALER = 3, DPS = 5 }
  end
  return { TANK = 1, HEALER = 1, DPS = 3 }
end
