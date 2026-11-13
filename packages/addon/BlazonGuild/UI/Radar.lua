-- Guildmates on the minimap and the arrow to follow someone (entrega 7; ideas of Olympus' Positions.lua and
-- KingArrow.lua, MIT; our own maths, without libraries). The guildmates who share their position (Layers.lua) show
-- as dots of their class colour on the minimap when they are within its range. «Seguir» puts an arrow under the
-- minimap that points at a guildmate, a meeting point or a sighting, with the distance in yards. Nothing new is
-- sent: it uses only the positions the guild already shares.
local _, BG = ...
local UI, C = BG.UI, BG.color
local Radar = { dots = {} }
BG.Radar = Radar
local Positions = BG.Positions

local STEP = 0.05 -- seconds between two redraws
local ARRIVED = 10 -- yards: a point is reached
local LOST = 60 -- seconds without a followed guildmate's position before the arrow gives up
-- The minimap's radius in yards for each zoom step (the game's own steps), outdoors and indoors.
local OUTDOOR = { [0] = 233.333, 200, 166.667, 133.333, 100, 66.667 }
local INDOOR = { [0] = 150, 120, 90, 60, 40, 25 }

local atan2 = math.atan2 or function(y, x)
  return math.atan(y, x)
end

local function setting()
  local s = BG.db and BG.db.settings
  return not (s and s.miniDots == false)
end

function Radar.Enabled()
  return setting()
end

function Radar.SetEnabled(on)
  BG.db.settings = BG.db.settings or {}
  BG.db.settings.miniDots = on and true or false
  Radar.Update()
  BG:Fire("BG_MAP_CHANGED")
end

function Radar.Radius()
  if C_Minimap and C_Minimap.GetViewRadius then
    local ok, r = pcall(C_Minimap.GetViewRadius)
    if ok and type(r) == "number" and r > 0 then
      return r
    end
  end
  local zoom = Minimap and Minimap.GetZoom and Minimap:GetZoom() or 0
  local inside = IsIndoors and IsIndoors()
  return (inside and INDOOR or OUTDOOR)[zoom or 0] or OUTDOOR[0]
end

local function facing()
  if not GetPlayerFacing then
    return nil
  end
  local ok, f = pcall(GetPlayerFacing)
  if not ok or type(f) ~= "number" or (issecretvalue and issecretvalue(f)) then
    return nil
  end
  return f
end

local function rotates()
  return GetCVar ~= nil and GetCVar("rotateMinimap") == "1"
end

-- Yards east and south -> yards right and up on the minimap (which may turn with the player).
function Radar.ToMinimap(east, south)
  local north = -south
  if rotates() then
    local f = facing()
    if not f then
      return nil
    end
    local c, s = math.cos(f), math.sin(f)
    return east * c + north * s, -east * s + north * c
  end
  return east, north
end

-- The direction to a point, as the arrow must turn (counter-clockwise, radians) from straight ahead.
function Radar.Turn(east, south)
  local bearing = atan2(-east, -south) -- (from the north, counter-clockwise: as the game's facing)
  return bearing - (facing() or 0)
end

local function square()
  return GetMinimapShape ~= nil and GetMinimapShape() == "SQUARE"
end

-- Minimap dots ---------------------------------------------------------------------------------------------------
local function makeDot()
  local f = CreateFrame("Button", nil, Minimap)
  f:SetSize(10, 10)
  f:SetFrameLevel((Minimap:GetFrameLevel() or 1) + 8)
  f.edge = f:CreateTexture(nil, "BACKGROUND")
  f.edge:SetTexture("Interface\\CHARACTERFRAME\\TempPortraitAlphaMask")
  f.edge:SetVertexColor(0, 0, 0, 0.9)
  f.edge:SetAllPoints()
  f.dot = f:CreateTexture(nil, "ARTWORK")
  f.dot:SetTexture("Interface\\CHARACTERFRAME\\TempPortraitAlphaMask")
  f.dot:SetPoint("TOPLEFT", 1.5, -1.5)
  f.dot:SetPoint("BOTTOMRIGHT", -1.5, 1.5)
  f:SetScript("OnEnter", function(self)
    if not (GameTooltip and self.mate) then
      return
    end
    local c = BG.classColor(self.mate.c)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:AddLine(self.mate.name, c[1], c[2], c[3])
    GameTooltip:AddLine("A " .. math.floor(self.yards or 0) .. " metros", 0.8, 0.8, 0.8)
    GameTooltip:AddLine("Clic: seguirle con la flecha", 0.6, 0.6, 0.6)
    BG.ShowTip()
  end)
  f:SetScript("OnLeave", function()
    if GameTooltip then
      GameTooltip:Hide()
    end
  end)
  f:SetScript("OnClick", function(self)
    if self.mate then
      Radar.Follow({ mate = self.mate.name })
    end
  end)
  return f
end

local function drawDots()
  local n = 0
  if setting() and Minimap and Minimap:IsShown() then
    local radius = Radar.Radius()
    local w, h = Minimap:GetWidth() or 0, Minimap:GetHeight() or 0
    for _, mate in ipairs(Positions.Mates()) do
      local east, south = Positions.Offset(mate.m, mate.x, mate.y)
      local rx, ry
      if east then
        rx, ry = Radar.ToMinimap(east, south)
      end
      local inside = rx and (square() and math.max(math.abs(rx), math.abs(ry)) <= radius or (rx * rx + ry * ry) <= radius * radius)
      if inside and w > 0 then
        n = n + 1
        local d = Radar.dots[n] or makeDot()
        Radar.dots[n] = d
        d:ClearAllPoints()
        d:SetPoint("CENTER", Minimap, "CENTER", rx / radius * w / 2, ry / radius * h / 2)
        local col = BG.classColor(mate.c)
        d.dot:SetVertexColor(col[1], col[2], col[3], 1)
        d.mate, d.rx, d.ry, d.yards = mate, rx, ry, math.sqrt(east * east + south * south)
        d:Show()
      end
    end
  end
  for i = n + 1, #Radar.dots do
    Radar.dots[i]:Hide()
    Radar.dots[i].mate = nil
  end
  return n
end

-- The arrow ---------------------------------------------------------------------------------------------------------
local arrow

local function makeArrow()
  local f = CreateFrame("Button", "BlazonGuildArrow", UIParent)
  f:SetSize(150, 66)
  f:SetFrameStrata("MEDIUM")
  f:SetClampedToScreen(true)
  f:SetMovable(true)
  f:RegisterForDrag("LeftButton")
  f:RegisterForClicks("RightButtonUp")
  f.pointer = f:CreateTexture(nil, "ARTWORK")
  f.pointer:SetTexture("Interface\\Minimap\\MinimapArrow")
  f.pointer:SetSize(40, 40)
  f.pointer:SetPoint("TOP", 0, 0)
  f.label = UI.Text(f, 12, C.goldTitle, { justify = "CENTER" })
  f.label:SetPoint("TOPLEFT", 0, -40)
  f.label:SetPoint("TOPRIGHT", 0, -40)
  f.dist = UI.Text(f, 11, C.text2, { justify = "CENTER" })
  f.dist:SetPoint("TOPLEFT", f.label, "BOTTOMLEFT", 0, -2)
  f.dist:SetPoint("TOPRIGHT", f.label, "BOTTOMRIGHT", 0, -2)
  f:SetScript("OnDragStart", f.StartMoving)
  f:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    local x, y = self:GetCenter()
    BG.db.settings = BG.db.settings or {}
    BG.db.settings.arrowAt = x and { x, y } or nil
  end)
  f:SetScript("OnClick", function()
    Radar.Stop()
  end)
  f:SetScript("OnEnter", function(self)
    if not GameTooltip then
      return
    end
    GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
    GameTooltip:AddLine("BlazonGuild: " .. (self.label:GetText() or ""), C.goldTitle[1], C.goldTitle[2], C.goldTitle[3])
    GameTooltip:AddLine("Clic derecho: dejar de seguir. Arrástrala para moverla.", 0.8, 0.8, 0.8, true)
    BG.ShowTip()
  end)
  f:SetScript("OnLeave", function()
    if GameTooltip then
      GameTooltip:Hide()
    end
  end)
  f:Hide()
  return f
end

local function placeArrow(f)
  f:ClearAllPoints()
  local at = BG.db.settings and BG.db.settings.arrowAt
  if type(at) == "table" and tonumber(at[1]) and tonumber(at[2]) then
    f:SetPoint("CENTER", UIParent, "BOTTOMLEFT", at[1], at[2])
  elseif Minimap then
    f:SetPoint("TOP", Minimap, "BOTTOM", 0, -26)
  else
    f:SetPoint("TOP", UIParent, "TOP", 0, -120)
  end
end

-- Follow someone or something: { mate = "Name" } (a guildmate who shares their position) or
-- { m = map, x, y, label } (a meeting point, a sighting).
function Radar.Follow(target)
  if type(target) ~= "table" then
    return nil
  end
  if target.mate then
    local p = Positions.mates[target.mate]
    if not p then
      BG:Notify("No se puede seguir", target.mate .. " no comparte ahora su posición.", { kind = "warning" })
      return nil, "sin posición"
    end
    target.label = target.mate
  elseif not (tonumber(target.m) and tonumber(target.x) and tonumber(target.y)) then
    return nil
  end
  Radar.target = target
  target.since = GetTime()
  arrow = arrow or makeArrow()
  placeArrow(arrow)
  arrow:Show()
  Radar.Update()
  BG:Fire("BG_MAP_CHANGED")
  return true
end

function Radar.Stop()
  Radar.target = nil
  if arrow then
    arrow:Hide()
  end
  BG:Fire("BG_MAP_CHANGED")
end

function Radar.Following()
  return Radar.target
end

-- Where the followed one is now: map, x, y (nil while we do not know).
local function targetPoint(t)
  if t.mate then
    local p = Positions.mates[t.mate]
    if p and GetTime() - p.t < 90 then
      t.since = GetTime()
      return p.m, p.x, p.y
    end
    return nil
  end
  return t.m, t.x, t.y
end

local function drawArrow()
  local t = Radar.target
  if not t or not arrow then
    return
  end
  local m, x, y = targetPoint(t)
  arrow.label:SetText(t.label or "")
  if not m then
    if GetTime() - (t.since or 0) > LOST then
      Radar.Stop()
      BG:Notify("Flecha apagada", (t.label or "?") .. " ha dejado de compartir su posición.", { kind = "info" })
      return
    end
    arrow.pointer:SetVertexColor(0.5, 0.5, 0.5, 0.7)
    arrow.dist:SetText("sin posición ahora")
    return
  end
  local east, south = Positions.Offset(m, x, y)
  if not east then
    arrow.pointer:SetVertexColor(0.5, 0.5, 0.5, 0.7)
    arrow.dist:SetText("en otro continente, o tú en una mazmorra")
    return
  end
  local yards = math.sqrt(east * east + south * south)
  if not t.mate and yards <= ARRIVED then
    Radar.Stop()
    BG:Notify("Has llegado", t.label or "", { kind = "success" })
    return
  end
  arrow.pointer:SetVertexColor(1, 0.82, 0.3, 1)
  if arrow.pointer.SetRotation then
    arrow.pointer:SetRotation(Radar.Turn(east, south))
  end
  arrow.turn, arrow.yards = Radar.Turn(east, south), yards
  arrow.dist:SetText(math.floor(yards + 0.5) .. " metros")
end

function Radar.Update()
  local ok, err = pcall(function()
    drawDots()
    drawArrow()
  end)
  if not ok and Radar.failed ~= err then
    Radar.failed = err -- (once: it redraws twenty times a second)
    BG:RecordError("radar", err)
  end
end

local driver = CreateFrame("Frame")
local acc = 0
driver:SetScript("OnUpdate", function(self, elapsed)
  acc = acc + (elapsed or 0)
  if acc < STEP then
    return
  end
  acc = 0
  if Radar.target or (setting() and next(Positions.mates) ~= nil) then
    Radar.Update()
  elseif #Radar.dots > 0 and Radar.dots[1]:IsShown() then
    Radar.Update()
  else
    self:Hide() -- (nothing to draw: it sleeps, and costs nothing each frame, until the map changes)
  end
end)
-- (a guildmate's position, following someone, the dots on or off, a meeting point: all of them say BG_MAP_CHANGED)
BG:On("BG_MAP_CHANGED", function()
  driver:Show()
end)
