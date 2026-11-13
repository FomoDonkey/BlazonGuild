-- Marcas (entrega 11; Olympus' Nameplates.lua and Borders.lua, MIT, our own art).
--
-- Over the nameplate of each member of the guild: the BlazonGuild crest; with a golden ring when that member
-- holds an honour (Honors.lua). Over a player of the other faction who is wanted («Se busca»): a red skull.
-- Around the target's portrait: a golden ring for an honoured member, a red one for a wanted foe.
-- In the chat (BlazonGuild's and the game's): a small golden crest by what an honoured member says.
-- Everything is our own frame; the game's frames are only looked up (with pcall: a nameplate the game keeps to
-- itself, or a portrait that is not where we look, is simply left alone). /bg marcas turns them off and on.
local _, BG = ...
local Marks = {}
BG.Marks = Marks
local Names = BG.Names

local GOLD, RED = { 1, 0.82, 0.38 }, { 0.95, 0.22, 0.18 }
local SKULL = "Interface\\TargetingFrame\\UI-RaidTargetingIcon_8"

local plates = setmetatable({}, { __mode = "k" }) -- nameplate -> our mark
local onUnit = {} -- nameplate unit -> nameplate (to hide it when it goes)

local function secret(v)
  return issecretvalue ~= nil and issecretvalue(v)
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

local function build(plate)
  local m = CreateFrame("Frame", nil, plate)
  m:SetSize(24, 24)
  m:SetPoint("BOTTOM", plate, "TOP", 0, -4)
  m.ring = m:CreateTexture(nil, "BACKGROUND")
  m.ring:SetTexture(BG.media .. "ring.png")
  m.ring:SetPoint("CENTER")
  m.ring:SetSize(24, 24)
  m.icon = m:CreateTexture(nil, "ARTWORK")
  m.icon:SetPoint("CENTER")
  m.icon:SetSize(16, 16)
  return m
end

local function style(m, kind)
  m.kind = kind
  if kind == "wanted" then
    m.icon:SetTexture(SKULL)
    m.icon:SetVertexColor(1, 1, 1)
    m.ring:SetVertexColor(RED[1], RED[2], RED[3])
    m.ring:Show()
  else
    m.icon:SetTexture(BG.media .. "logo.png")
    m.icon:SetVertexColor(1, 1, 1)
    m.ring:SetVertexColor(GOLD[1], GOLD[2], GOLD[3])
    m.ring:SetShown(kind == "honored")
  end
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
      m:Hide()
    end
    return nil
  end
  if not m then
    local ok, made = pcall(build, plate)
    if not ok then
      return nil
    end
    m = made
    plates[plate] = m
  end
  style(m, kind)
  m:Show()
  return kind
end

function Marks.Remove(unit)
  local plate = onUnit[unit]
  onUnit[unit] = nil
  local m = plate and plates[plate]
  if m then
    m:Hide()
  end
end

-- The target's portrait ---------------------------------------------------------------------------------------------
local ring
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
  if kind ~= "honored" and kind ~= "wanted" then
    if ring then
      ring:Hide()
    end
    return nil
  end
  if not ring then
    local ok, made = pcall(function()
      local r = CreateFrame("Frame", nil, TargetFrame)
      r.tex = r:CreateTexture(nil, "OVERLAY")
      r.tex:SetAllPoints()
      r.tex:SetTexture(BG.media .. "ring.png")
      return r
    end)
    if not ok then
      return nil
    end
    ring = made
  end
  local okS = pcall(function()
    local w = p:GetWidth()
    ring:SetSize(((w and w > 0) and w or 64) * 1.18, ((w and w > 0) and w or 64) * 1.18)
    ring:ClearAllPoints()
    ring:SetPoint("CENTER", p, "CENTER")
  end)
  if not okS then
    ring:Hide()
    return nil
  end
  local c = kind == "wanted" and RED or GOLD
  ring.tex:SetVertexColor(c[1], c[2], c[3])
  ring:Show()
  return kind
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
