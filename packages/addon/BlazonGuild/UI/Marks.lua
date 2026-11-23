-- Marcas (entrega 11; Olympus' Nameplates.lua and Borders.lua, MIT, our own art).
--
-- Over the nameplate of each member of the guild: the BlazonGuild crest; with a golden ring when that member
-- holds an honour (Honors.lua). Over a player of the other faction who is wanted («Se busca»): a red skull.
-- Around the target's portrait: a golden ring for an honoured member, a red one for a wanted foe.
-- In the chat (BlazonGuild's and the game's): a small golden crest by what an honoured member says.
-- /bg marcas turns them off and on.
--
-- The nameplates and the target frame are the game's protected frames: in combat the game refuses an addon that
-- makes, moves or sizes something in them, or shows or hides a frame of its own there, and counts it in the addon
-- list («Las acciones de interfaz han fallado debido a este add-on», Peregrino, 2026-11-18; until 0.29.2 every mark was a
-- frame of ours on the plate or on the target frame, moved and shown on every target change). Olympus' way on
-- Forever (Nameplates.lua, Borders.lua; MIT): only textures of our own on the game's frame, one per look, made and
-- placed out of combat (or where the client says the frame is not protected), and from then on only shown and
-- hidden, which the game allows for a texture. What cannot be made in a fight is made when it ends. The game's
-- frames are only looked up (with pcall: a nameplate the game keeps to itself, or a portrait that is not where we
-- look, is simply left alone).
local _, BG = ...
local Marks = {}
BG.Marks = Marks
local Names = BG.Names

local GOLD, RED = { 1, 0.82, 0.38 }, { 0.95, 0.22, 0.18 }
local SKULL = "Interface\\TargetingFrame\\UI-RaidTargetingIcon_8"

local plates = setmetatable({}, { __mode = "k" }) -- nameplate -> our mark (its textures)
local onUnit = {} -- nameplate unit -> nameplate (to hide it when it goes)
local waiting = false -- something could not be made in combat: made when the fight ends

local function secret(v)
  return issecretvalue ~= nil and issecretvalue(v)
end

-- May BlazonGuild make a texture on this game frame, or place one, now? Out of combat, or where the client says the
-- frame is not protected (Olympus' CanTouch).
function Marks.CanTouch(region)
  if not (InCombatLockdown and InCombatLockdown()) then
    return true
  end
  local isProtected = type(region) == "table" and region.IsProtected
  if type(isProtected) ~= "function" then
    return false
  end
  local ok, protected = pcall(isProtected, region)
  return ok and not secret(protected) and protected == false
end

-- Shows the textures of `set` named in `want` (a list) and hides the rest: the only calls made in combat.
local function showOnly(set, want)
  for key, tex in pairs(set) do
    local on = false
    for _, k in ipairs(want) do
      if k == key then
        on = true
      end
    end
    if on and not tex:IsShown() then
      tex:Show()
    elseif not on and tex:IsShown() then
      tex:Hide()
    end
  end
end

function Marks.Enabled()
  return not (BG.db and BG.db.settings and BG.db.settings.marksOff)
end

function Marks.SetEnabled(on)
  BG.db.settings.marksOff = (not on) or nil
  Marks.RefreshAll()
  return true
end

-- What a unit wears: "honored", "member", "wanted" or nil (and its name).
function Marks.KindOf(unit)
  local okP, isPlayer = pcall(UnitIsPlayer, unit)
  if not okP or secret(isPlayer) or not isPlayer then
    return nil
  end
  local name = Names.Unit(unit)
  if not name then
    return nil
  end
  if BG.Guild.Find(name) then
    return BG.Honors.Honored(name) and "honored" or "member", name
  end
  local f = BG.Wanted.Foe(name)
  if f and f.bounty > 0 then
    return "wanted", name
  end
  return nil, name
end

-- A plate's mark: its four looks as textures of ours on the game's nameplate, all hidden, centred 8 px above the
-- plate (the ring 24 px, the crest or skull 16 px inside it). Made once, while the game lets us (Marks.CanTouch).
local LOOKS = { member = { "icon_crest" }, honored = { "icon_crest", "ring_gold" }, wanted = { "icon_skull", "ring_red" } }
local NONE = {}

local function build(plate)
  local function tex(layer, sub, file, size, y, c)
    local t = plate:CreateTexture(nil, layer, nil, sub)
    t:SetTexture(file)
    if c then
      t:SetVertexColor(c[1], c[2], c[3])
    end
    t:SetSize(size, size)
    t:SetPoint("BOTTOM", plate, "TOP", 0, y)
    t:Hide()
    return t
  end
  return {
    ring_gold = tex("OVERLAY", 5, BG.media .. "ring.png", 24, -4, GOLD),
    ring_red = tex("OVERLAY", 5, BG.media .. "ring.png", 24, -4, RED),
    icon_crest = tex("OVERLAY", 6, BG.media .. "logo.png", 16, 0),
    icon_skull = tex("OVERLAY", 6, SKULL, 16, 0),
  }
end

-- The look a plate shows now (nil: none), for the tests.
function Marks.Shown(unit)
  local m = onUnit[unit] and plates[onUnit[unit]]
  if not m then
    return nil
  end
  for kind, parts in pairs(LOOKS) do
    local all = true
    for key, t in pairs(m) do
      local want = false
      for _, k in ipairs(parts) do
        if k == key then
          want = true
        end
      end
      if t:IsShown() ~= want then
        all = false
      end
    end
    if all then
      return kind
    end
  end
  return nil
end

local function plateOf(unit)
  if not (C_NamePlate and C_NamePlate.GetNamePlateForUnit) then
    return nil
  end
  local ok, plate = pcall(C_NamePlate.GetNamePlateForUnit, unit)
  if not ok or type(plate) ~= "table" then
    return nil
  end
  if plate.IsForbidden then
    local okF, forbidden = pcall(plate.IsForbidden, plate)
    if not okF or forbidden then
      return nil
    end
  end
  return plate
end

function Marks.Apply(unit)
  local plate = unit and plateOf(unit)
  if not plate then
    return nil
  end
  onUnit[unit] = plate
  local kind = Marks.Enabled() and BG.Gamepad.Allowed("nameplates") and Marks.KindOf(unit) or nil
  local m = plates[plate]
  if not kind then
    if m then
      showOnly(m, NONE)
    end
    return nil
  end
  if not m then
    if not Marks.CanTouch(plate) then
      waiting = true -- (in a fight: made and shown when it ends)
      return nil
    end
    local ok, made = pcall(build, plate)
    if not ok or not made then
      return nil
    end
    m = made
    plates[plate] = m
  end
  showOnly(m, LOOKS[kind])
  return kind
end

function Marks.Remove(unit)
  local plate = onUnit[unit]
  onUnit[unit] = nil
  local m = plate and plates[plate]
  if m then
    showOnly(m, NONE)
  end
end

-- The target's portrait ---------------------------------------------------------------------------------------------
-- Two rings (gold, red) as textures of ours on the frame that holds the portrait (Forever: TargetFrameContainer, as
-- Olympus' borders), one sublevel over the game's art, sized and placed once out of combat; a target change only
-- shows one and hides the other.
local rings
local function portrait()
  local tf = TargetFrame
  if type(tf) ~= "table" then
    return nil
  end
  return tf.portrait or _G.TargetFramePortrait or (tf.TargetFrameContainer and tf.TargetFrameContainer.Portrait) or nil
end

function Marks.Target()
  local p = portrait()
  if not p then
    return nil
  end
  local okE, exists = pcall(UnitExists, "target")
  local kind = Marks.Enabled() and BG.Gamepad.Allowed("nameplates") and okE and exists and not secret(exists) and Marks.KindOf("target") or nil
  local want = (kind == "honored" and "gold") or (kind == "wanted" and "red") or nil
  if not rings then
    if not want then
      return nil
    end
    local okH, host = pcall(function()
      return p.GetParent and p:GetParent() or nil
    end)
    host = (okH and type(host) == "table" and host.CreateTexture) and host or TargetFrame
    if not Marks.CanTouch(host) then
      waiting = true -- (in a fight: made and shown when it ends)
      return nil
    end
    local ok, made = pcall(function()
      local w = p:GetWidth()
      local size = ((w and w > 0) and w or 64) * 1.18
      local r = {}
      for key, c in pairs({ gold = GOLD, red = RED }) do
        local t = host:CreateTexture(nil, "OVERLAY", nil, 7)
        t:SetTexture(BG.media .. "ring.png")
        t:SetVertexColor(c[1], c[2], c[3])
        t:SetSize(size, size)
        t:SetPoint("CENTER", p, "CENTER")
        t:Hide()
        r[key] = t
      end
      return r
    end)
    if not ok or not made then
      return nil
    end
    rings = made
  end
  showOnly(rings, want and { want } or NONE)
  return want and kind or nil
end

-- The ring shown round the portrait now ("gold", "red" or nil), for the tests.
function Marks.TargetShown()
  if not rings then
    return nil
  end
  return (rings.gold:IsShown() and "gold") or (rings.red:IsShown() and "red") or nil
end

-- The chat ------------------------------------------------------------------------------------------------------------
-- A golden crest by what an honoured member of the guild says. In BlazonGuild's chat it goes before the name
-- (Chat.FormatLine); in the game's chat windows, through the game's own message filter, which may change the
-- message but not the name: the crest goes right after the name ("[Tarek Vientoalto]: <crest> hola"). Nothing
-- is touched when the game hides a message or its author (a secret value), and only the honoured get it, so the
-- guild chat does not fill up with crests.
local CREST = "|T" .. BG.media .. "logo.png:14:14:0:0|t "
Marks.CREST = CREST

function Marks.ChatMark(author)
  if not Marks.Enabled() or not BG.Honors or not BG.Gamepad.Allowed("chatmarks") then
    return ""
  end
  local name = Names.Short(author)
  if name and BG.Guild.Find(name) and BG.Honors.Honored(name) then
    return CREST
  end
  return ""
end

function Marks.ChatFilter(_, _, msg, author, ...)
  if type(msg) ~= "string" or type(author) ~= "string" or secret(msg) or secret(author) then
    return false
  end
  local ok, m = pcall(Marks.ChatMark, author)
  if not ok or m == "" then
    return false
  end
  return false, m .. msg, author, ...
end

local CHAT_EVENTS = { "CHAT_MSG_GUILD", "CHAT_MSG_OFFICER", "CHAT_MSG_SAY", "CHAT_MSG_YELL", "CHAT_MSG_WHISPER",
  "CHAT_MSG_PARTY", "CHAT_MSG_PARTY_LEADER", "CHAT_MSG_RAID", "CHAT_MSG_RAID_LEADER", "CHAT_MSG_INSTANCE_CHAT",
  "CHAT_MSG_INSTANCE_CHAT_LEADER", "CHAT_MSG_CHANNEL" }

-- (how many chat kinds carry the mark: /bg estado can tell; 0 = this client has no message filter)
Marks.chatEvents = nil
local function hookChat()
  if Marks.chatEvents then
    return
  end
  local add = (ChatFrameUtil and ChatFrameUtil.AddMessageEventFilter) or ChatFrame_AddMessageEventFilter
  local n = 0
  if add then
    for _, e in ipairs(CHAT_EVENTS) do
      if pcall(add, e, Marks.ChatFilter) then
        n = n + 1
      end
    end
  end
  Marks.chatEvents = n
end
BG:On("PLAYER_LOGIN", hookChat)

function Marks.RefreshAll()
  for unit in pairs(onUnit) do
    Marks.Apply(unit)
  end
  Marks.Target()
end
BG:On("BG_GAMEPAD_CHANGED", function()
  Marks.RefreshAll()
end)

BG:On("NAME_PLATE_UNIT_ADDED", function(unit)
  Marks.Apply(unit)
end)
BG:On("NAME_PLATE_UNIT_REMOVED", function(unit)
  Marks.Remove(unit)
end)
BG:On("PLAYER_TARGET_CHANGED", function()
  Marks.Target()
end)
-- What a fight kept from being made (a plate's mark, the rings) is made now.
BG:On("PLAYER_REGEN_ENABLED", function()
  if waiting then
    waiting = false
    Marks.RefreshAll()
  end
end)
local soon = false
local function later()
  if soon then
    return
  end
  soon = true
  C_Timer.After(1, function()
    soon = false
    Marks.RefreshAll()
  end)
end
BG:On("BG_WANTED_CHANGED", later)
BG:On("BG_HONORS_CHANGED", later)

BG.commands = BG.commands or {}
BG.commands.marcas = function()
  Marks.SetEnabled(not Marks.Enabled())
  BG:Print(Marks.Enabled() and "marcas visibles sobre los nombres y en el chat (las quitas con /bg marcas)." or "marcas ocultas (vuelven con /bg marcas).")
end
