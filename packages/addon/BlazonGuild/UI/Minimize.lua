-- Minimized window and minimap button (Peregrino, 2026-11-12: the window covered the world map and the creatures
-- he had to click, with no way to make it small; and a round button by the minimap, as other addons have).
--
-- Minimized: the window hides and a small bar stays (the crest, "BlazonGuild", the section you were in, and a
-- button to open it again), which you can drag anywhere. Opening the world map minimizes the window by itself,
-- and closing the map brings it back (only if it was the map that minimized it).
-- Minimap button: our crest in a round frame on the minimap's edge; a click opens or closes the window, and
-- dragging moves it around the edge. /bg minimapa hides it or brings it back.
local _, BG = ...
local UI, C = BG.UI, BG.color

local BAR_W, BAR_H = 300, 46
local atan2 = math.atan2 or function(y, x)
  return math.atan(y, x)
end

-- Minimized bar ---------------------------------------------------------------------------------------------
local bar
local function sectionName()
  for _, item in ipairs(BG.nav or {}) do
    if item.key == BG.db.settings.lastView then
      return item.label
    end
  end
  return "BlazonGuild"
end

local function glyphButton(parent, draw, onClick)
  local b = CreateFrame("Button", nil, parent)
  b:SetSize(26, 26)
  local parts = draw(b)
  local function paint(c)
    for _, t in ipairs(parts) do
      t:SetColorTexture(c[1], c[2], c[3], 1)
    end
  end
  paint(C.text2)
  b:SetScript("OnEnter", function()
    paint(C.goldHi)
  end)
  b:SetScript("OnLeave", function()
    paint(C.text2)
  end)
  b:SetScript("OnClick", onClick)
  return b
end

-- A square outline: "open again".
local function drawRestore(b)
  local out = {}
  for _, p in ipairs({ { "TOP", 12, 1.5, 0, 6 }, { "BOTTOM", 12, 1.5, 0, -6 }, { "LEFT", 1.5, 12, -6, 0 }, { "RIGHT", 1.5, 12, 6, 0 } }) do
    local t = b:CreateTexture(nil, "ARTWORK")
    t:SetSize(p[2], p[3])
    t:SetPoint("CENTER", p[4], p[5])
    out[#out + 1] = t
  end
  return out
end

-- A short line: "minimize".
local function drawMinimize(b)
  local t = b:CreateTexture(nil, "ARTWORK")
  t:SetSize(13, 1.5)
  t:SetPoint("CENTER", 0, -4)
  return { t }
end
BG.DrawMinimizeGlyph = drawMinimize

local function drawClose(b)
  local out = {}
  for _, angle in ipairs({ 45, -45 }) do
    local t = b:CreateTexture(nil, "ARTWORK")
    t:SetSize(13, 1.5)
    t:SetPoint("CENTER")
    t:SetRotation(math.rad(angle))
    out[#out + 1] = t
  end
  return out
end

local function buildBar()
  local b = CreateFrame("Button", "BlazonGuildMiniBar", UIParent)
  b:SetSize(BAR_W, BAR_H)
  b:SetFrameStrata("MEDIUM")
  b:SetClampedToScreen(true)
  b:SetMovable(true)
  b:EnableMouse(true)
  b:RegisterForDrag("LeftButton")
  b:Hide()
  local p = BG.db.settings.miniPoint
  if p then
    b:SetPoint(p[1], UIParent, p[2], p[3], p[4])
  else
    b:SetPoint("TOP", UIParent, "TOP", 0, -110)
  end
  b.plate = UI.Plate(b, { tile = "metal.png", corners = 12, rail = 0.3 })
  b.plate:SetAllPoints()
  b.plate:EnableMouse(false)
  b.crest = b.plate:CreateTexture(nil, "OVERLAY")
  b.crest:SetTexture(BG.media .. "logo.png")
  b.crest:SetSize(26, 26)
  b.crest:SetPoint("LEFT", 12, 0)
  b.title = UI.Text(b.plate, 14, C.goldTitle, { font = BG.font.display })
  b.title:SetPoint("TOPLEFT", b.crest, "TOPRIGHT", 9, 1)
  b.title:SetText("BlazonGuild")
  b.sub = UI.Text(b.plate, 11, C.text3)
  b.sub:SetPoint("TOPLEFT", b.title, "BOTTOMLEFT", 0, -3)
  b.close = glyphButton(b, drawClose, function()
    BG:CloseAll()
  end)
  b.close:SetPoint("RIGHT", -8, 0)
  b.open = glyphButton(b, drawRestore, function()
    BG:Restore()
  end)
  b.open:SetPoint("RIGHT", b.close, "LEFT", -2, 0)
  b.sub:SetPoint("RIGHT", b.open, "LEFT", -8, 0)
  b.badge = UI.Text(b.plate, 11, C.goldHi, { justify = "RIGHT" })
  b.badge:SetPoint("TOPRIGHT", b.open, "TOPLEFT", -8, -2)
  b:SetScript("OnClick", function()
    BG:Restore()
  end)
  b:SetScript("OnDragStart", function(self)
    self:StartMoving()
  end)
  b:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    local point, _, rel, x, y = self:GetPoint()
    BG.db.settings.miniPoint = { point, rel, x, y }
  end)
  b:SetScript("OnEnter", function(self)
    if GameTooltip then
      GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
      GameTooltip:SetText("BlazonGuild", C.gold[1], C.gold[2], C.gold[3])
      GameTooltip:AddLine("Pulsa para abrirla otra vez. Arrástrala para moverla.", 1, 1, 1, true)
      BG.ShowTip()
    end
  end)
  b:SetScript("OnLeave", function()
    if GameTooltip then
      GameTooltip:Hide()
    end
  end)
  return b
end

function BG:MiniBar()
  bar = bar or buildBar()
  BG.miniBar = bar
  return bar
end

function BG:IsMinimized()
  return bar ~= nil and bar:IsShown()
end

function BG:RefreshMiniBar()
  if not bar then
    return
  end
  local unread = 0
  for _, n in pairs(BG.Chat and BG.Chat.unread or {}) do
    unread = unread + n
  end
  bar.sub:SetText("Minimizada en " .. sectionName())
  bar.badge:SetText(unread > 0 and (unread .. (unread == 1 and " mensaje" or " mensajes")) or "")
end

-- Hides the window and leaves the bar. auto: it was the world map (it comes back when the map closes).
function BG:Minimize(auto)
  local w = BG.window
  if not (w and w:IsShown()) then
    return false
  end
  BG.miniAuto = auto and true or nil
  w:Hide()
  BG:MiniBar():Show()
  BG:RefreshMiniBar()
  return true
end

function BG:Restore()
  if bar then
    bar:Hide()
  end
  BG.miniAuto = nil
  local w = BG.window or BG:CreateWindow()
  if not w:IsShown() then
    w:Show()
    BG:ShowView(BG.db.settings.lastView)
  end
end

function BG:CloseAll()
  if bar then
    bar:Hide()
  end
  BG.miniAuto = nil
  if BG.window then
    BG.window:Hide()
  end
end

BG:On("BG_CHAT_LINE", function()
  if BG:IsMinimized() then
    BG:RefreshMiniBar()
  end
end)

-- The world map minimizes the window while it is open.
local mapHooked = false
function BG:HookWorldMap()
  if mapHooked or not WorldMapFrame then
    return
  end
  mapHooked = true
  WorldMapFrame:HookScript("OnShow", function()
    if BG.window and BG.window:IsShown() then
      BG:Minimize(true)
    end
  end)
  WorldMapFrame:HookScript("OnHide", function()
    if BG.miniAuto and BG:IsMinimized() then
      BG:Restore()
    end
  end)
end
BG:On("PLAYER_LOGIN", function()
  BG:HookWorldMap()
end)
BG:On("ADDON_LOADED", function(name)
  if name == "Blizzard_WorldMap" then
    BG:HookWorldMap()
  end
end)

-- Minimap button -----------------------------------------------------------------------------------------------
local mm
local function placeButton()
  if not (mm and Minimap) then
    return
  end
  local a = math.rad(BG.db.settings.minimapAngle or 205)
  local r = (Minimap:GetWidth() or 140) / 2 + 10
  mm:ClearAllPoints()
  mm:SetPoint("CENTER", Minimap, "CENTER", math.cos(a) * r, math.sin(a) * r)
end

local function buildMinimapButton()
  local b = CreateFrame("Button", "BlazonGuildMinimapButton", Minimap)
  b:SetSize(31, 31)
  b:SetFrameStrata("MEDIUM")
  b:SetFrameLevel((Minimap:GetFrameLevel() or 1) + 8)
  b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
  b:RegisterForDrag("LeftButton")
  b:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
  local back = b:CreateTexture(nil, "BACKGROUND")
  back:SetTexture("Interface\\Minimap\\UI-Minimap-Background")
  back:SetSize(22, 22)
  back:SetPoint("TOPLEFT", 5, -4)
  b.icon = b:CreateTexture(nil, "ARTWORK")
  b.icon:SetTexture(BG.media .. "logo.png")
  b.icon:SetSize(20, 20)
  b.icon:SetPoint("TOPLEFT", 6, -5)
  local border = b:CreateTexture(nil, "OVERLAY")
  border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
  border:SetSize(53, 53)
  border:SetPoint("TOPLEFT")
  b:SetScript("OnClick", function()
    BG:ToggleWindow()
  end)
  b:SetScript("OnDragStart", function(self)
    self:SetScript("OnUpdate", function()
      local mx, my = Minimap:GetCenter()
      local px, py = GetCursorPosition()
      local scale = Minimap:GetEffectiveScale() or 1
      if mx and px then
        BG.db.settings.minimapAngle = math.deg(atan2(py / scale - my, px / scale - mx))
        placeButton()
      end
    end)
  end)
  b:SetScript("OnDragStop", function(self)
    self:SetScript("OnUpdate", nil)
  end)
  b:SetScript("OnEnter", function(self)
    if GameTooltip then
      GameTooltip:SetOwner(self, "ANCHOR_LEFT")
      GameTooltip:SetText("BlazonGuild", C.gold[1], C.gold[2], C.gold[3])
      GameTooltip:AddLine("Clic: abrir o cerrar la ventana de tu hermandad.", 1, 1, 1, true)
      GameTooltip:AddLine("Arrástralo para moverlo por el borde del minimapa. /bg minimapa lo oculta.", 0.66, 0.70, 0.76, true)
      BG.ShowTip()
    end
  end)
  b:SetScript("OnLeave", function()
    if GameTooltip then
      GameTooltip:Hide()
    end
  end)
  return b
end

function BG:MinimapButton()
  if not Minimap then
    return nil
  end
  mm = mm or buildMinimapButton()
  BG.minimapButton = mm
  placeButton()
  mm:SetShown(not BG.db.settings.minimapHidden)
  return mm
end
BG.PlaceMinimapButton = placeButton

BG:On("PLAYER_LOGIN", function()
  BG:MinimapButton()
end)

-- A new install says how to open it (Peregrino, 2026-11-18: a guildmate installed it and did not know how, «no sé cómo
-- se abre»: nothing showed until the window was opened). Until it has been opened once (the privacy question comes
-- then), at three logins at most: a notice that opens it with a click, and a line in the chat.
local WELCOME_TIMES = 3
function BG.Welcome()
  local s = BG.db.settings
  if BG.demo or BG.Consent.Answered() or (s.welcomed or 0) >= WELCOME_TIMES or (BG.window and BG.window:IsShown()) then
    return false
  end
  s.welcomed = (s.welcomed or 0) + 1
  local how = s.minimapHidden and "Escribe /bg para abrirlo." or "Pulsa aquí, escribe /bg o usa el escudo junto al minimapa."
  BG:Notify("BlazonGuild está listo", how, { kind = "info", view = "overview", duration = 20 })
  BG:Print("listo. Ábrelo con /bg o con el escudo junto al minimapa (/bg ayuda: todos los comandos).")
  return true
end
BG:On("PLAYER_LOGIN", function()
  C_Timer.After(8, function()
    local ok, err = pcall(BG.Welcome)
    if not ok then
      BG:RecordError("bienvenida", err)
    end
  end)
end)

BG.commands = BG.commands or {}
BG.commands.minimapa = function()
  BG.db.settings.minimapHidden = not BG.db.settings.minimapHidden or nil
  BG:MinimapButton()
  BG:Print(BG.db.settings.minimapHidden and "botón del minimapa oculto (vuelve con /bg minimapa)." or "botón del minimapa visible.")
end
