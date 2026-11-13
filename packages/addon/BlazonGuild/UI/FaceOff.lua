-- «Cara a cara» (ArenaFace.lua): two fighters side by side, their health live while both are in sight, and the duel's
-- result when the game says it. One movable frame on the screen, outside the main window, that can grow (- / +) and
-- stays open in combat: for whoever watches a duel, and for whoever shows it on a stream.
local _, BG = ...
local UI, C = BG.UI, BG.color
local Face = BG.ArenaFace

local W, H = 560, 300
local STEP = 0.2
local TIER_COLOR = { gold = C.goldHi, silver = { 0.82, 0.84, 0.88 }, bronze = { 0.80, 0.56, 0.36 } }

local frame

local function className(file)
  return file and ((LOCALIZED_CLASS_NAMES_MALE and LOCALIZED_CLASS_NAMES_MALE[file]) or (BG.Recruit and BG.Recruit.CLASS_NAMES[file])) or nil
end

local function half(f, align)
  local h = CreateFrame("Frame", nil, f)
  h:SetSize(220, 210)
  local right = align == "RIGHT"
  h.icon = h:CreateTexture(nil, "ARTWORK")
  h.icon:SetSize(44, 44)
  h.icon:SetPoint(right and "TOPRIGHT" or "TOPLEFT", 0, 0)
  local function text(size, color, opts)
    local t = UI.Text(h, size, color, opts)
    t:SetJustifyH(align)
    return t
  end
  h.name = text(16, C.text, { font = BG.font.display })
  h.name:SetPoint(right and "TOPRIGHT" or "TOPLEFT", h.icon, right and "TOPLEFT" or "TOPRIGHT", right and -8 or 8, -2)
  h.name:SetPoint(right and "LEFT" or "RIGHT", h, right and "LEFT" or "RIGHT", 0, 0)
  h.who = text(11, C.text2)
  h.who:SetPoint(right and "TOPRIGHT" or "TOPLEFT", h.name, right and "BOTTOMRIGHT" or "BOTTOMLEFT", 0, -4)
  h.who:SetPoint(right and "LEFT" or "RIGHT", h, right and "LEFT" or "RIGHT", 0, 0)
  h.rating = text(22, C.goldTitle, { font = BG.font.display })
  h.rating:SetPoint(right and "TOPRIGHT" or "TOPLEFT", h.icon, right and "BOTTOMRIGHT" or "BOTTOMLEFT", 0, -10)
  h.rank = text(12, C.text)
  h.rank:SetPoint(right and "TOPRIGHT" or "TOPLEFT", h.rating, right and "BOTTOMRIGHT" or "BOTTOMLEFT", 0, -4)
  h.rank:SetPoint(right and "LEFT" or "RIGHT", h, right and "LEFT" or "RIGHT", 0, 0)
  h.record = text(12, C.text2)
  h.record:SetPoint(right and "TOPRIGHT" or "TOPLEFT", h.rank, right and "BOTTOMRIGHT" or "BOTTOMLEFT", 0, -4)
  h.record:SetPoint(right and "LEFT" or "RIGHT", h, right and "LEFT" or "RIGHT", 0, 0)
  h.last = text(12, C.text2)
  h.last:SetPoint(right and "TOPRIGHT" or "TOPLEFT", h.record, right and "BOTTOMRIGHT" or "BOTTOMLEFT", 0, -4)
  h.last:SetPoint(right and "LEFT" or "RIGHT", h, right and "LEFT" or "RIGHT", 0, 0)
  h.bar = UI.Bar(h)
  h.bar:SetHeight(14)
  h.bar:SetPoint("BOTTOMLEFT", 0, 16)
  h.bar:SetPoint("BOTTOMRIGHT", 0, 16)
  h.hp = text(11, C.text2)
  h.hp:SetPoint(right and "TOPRIGHT" or "TOPLEFT", h.bar, right and "BOTTOMRIGHT" or "BOTTOMLEFT", 0, -3)
  h.hp:SetPoint(right and "LEFT" or "RIGHT", h, right and "LEFT" or "RIGHT", 0, 0)
  return h
end

local function fill(h, s)
  BG.setClassIcon(h.icon, s.classFile)
  h.name:SetText(BG.colorize(s.name, BG.classColor(s.classFile)))
  local cls = className(s.classFile)
  h.who:SetText((s.level and string.format("Nivel %d", s.level) or "") .. (cls and ((s.level and ", " or "") .. cls) or ""))
  h.rating:SetText(tostring(s.rating))
  local rank = s.tier and BG.colorize(s.tier.label, TIER_COLOR[s.tier.key] or C.text) or BG.colorize(s.fights < BG.Arena.R.RANKED_MIN and "sin rango todavía" or "sin rango", C.text3)
  h.rank:SetText(rank .. (s.place and string.format(", puesto %d", s.place) or "") .. (s.champion and BG.colorize(", campeón", C.goldHi) or ""))
  h.record:SetText(string.format("%d victorias, %d derrotas", s.wins, s.losses) .. (s.streak >= 2 and string.format(", racha de %d", s.streak) or ""))
  h.last:SetText(#s.recent > 0 and ("Últimos: " .. table.concat(s.recent, " ")) or "Aún sin combates esta temporada.")
end

local function scale()
  local s = BG.db.settings and tonumber(BG.db.settings.faceScale) or 1
  return math.max(0.6, math.min(1.6, s))
end

local function build()
  local f = UI.Plate(UIParent, { corners = 18, rail = 0.3 })
  f:SetSize(W, H)
  f:SetFrameStrata("HIGH")
  f:SetClampedToScreen(true)
  f:SetMovable(true)
  f:EnableMouse(true)
  f:RegisterForDrag("LeftButton")
  f:SetScript("OnDragStart", f.StartMoving)
  f:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    local x, y = self:GetCenter()
    BG.db.settings = BG.db.settings or {}
    BG.db.settings.faceAt = x and { x, y } or nil
  end)
  f.head = UI.Heading(f, "Cara a cara")
  f.head:SetPoint("TOPLEFT", 16, -8)
  f.close = UI.Button(f, "×", { height = 22, width = 26 })
  f.close:SetPoint("TOPRIGHT", -10, -8)
  f.close:SetScript("OnClick", function()
    f:Hide()
  end)
  f.bigger = UI.Button(f, "+", { height = 22, width = 26 })
  f.bigger:SetPoint("RIGHT", f.close, "LEFT", -6, 0)
  f.smaller = UI.Button(f, "−", { height = 22, width = 26 })
  f.smaller:SetPoint("RIGHT", f.bigger, "LEFT", -6, 0)
  local function rescale(d)
    BG.db.settings = BG.db.settings or {}
    BG.db.settings.faceScale = math.max(0.6, math.min(1.6, scale() + d))
    f:SetScale(scale())
  end
  f.bigger:SetScript("OnClick", function()
    rescale(0.1)
  end)
  f.smaller:SetScript("OnClick", function()
    rescale(-0.1)
  end)
  f.head:SetPoint("RIGHT", f.smaller, "LEFT", -10, 0)
  f.A = half(f, "LEFT")
  f.A:SetPoint("TOPLEFT", 18, -44)
  f.B = half(f, "RIGHT")
  f.B:SetPoint("TOPRIGHT", -18, -44)
  f.vs = UI.Text(f, 26, C.goldHi, { font = BG.font.display, justify = "CENTER" })
  f.vs:SetPoint("TOP", 0, -92)
  f.vs:SetText("VS")
  f.meet = UI.Text(f, 11, C.text2, { justify = "CENTER", wrap = true })
  f.meet:SetPoint("TOP", f.vs, "BOTTOM", 0, -6)
  f.meet:SetWidth(76)
  f.result = UI.Text(f, 14, C.goldHi, { font = BG.font.display, justify = "CENTER" })
  f.result:SetPoint("BOTTOMLEFT", 18, 14)
  f.result:SetPoint("BOTTOMRIGHT", -18, 14)
  local acc = 0
  f:SetScript("OnUpdate", function(self, elapsed)
    acc = acc + (elapsed or 0)
    if acc >= STEP then
      acc = 0
      BG.UI.FaceOffTick()
    end
  end)
  f:SetScript("OnHide", function(self)
    self.pair = nil
  end)
  f:Hide()
  return f
end

-- Live: each fighter's health while in sight.
function BG.UI.FaceOffTick()
  local f = frame
  if not (f and f:IsShown() and f.pair) then
    return
  end
  for _, k in ipairs({ "A", "B" }) do
    local h = f[k]
    local unit = Face.UnitOf(f.pair[k])
    local hp = Face.Health(unit)
    if hp then
      h.bar:Show()
      h.bar:Set(hp, hp > 0.5 and C.success or (hp > 0.2 and C.warning or C.danger))
      h.hp:SetText(string.format("%d%%", math.floor(hp * 100 + 0.5)))
    else
      h.bar:Set(0, C.line)
      h.hp:SetText(BG.colorize("fuera de vista", C.text3))
    end
  end
end

-- Opens the card for fighters a and b (a on the left).
function BG.UI.FaceOff(a, b)
  local model = Face.Model(a, b)
  if not model then
    return nil
  end
  frame = frame or build()
  local f = frame
  f.pair = { A = model.a.name, B = model.b.name }
  fill(f.A, model.a)
  fill(f.B, model.b)
  local m = model.meetings
  f.meet:SetText((m.a + m.b) > 0 and string.format("Entre ellos: %d-%d", m.a, m.b) or "Nunca se han enfrentado")
  local r = Face.lastResult
  local fresh = r and GetTime() - r.at < 120 and ((r.w == model.a.name and r.l == model.b.name) or (r.w == model.b.name and r.l == model.a.name))
  f.result:SetText(fresh and string.format("Gana %s", r.w) or "Cuando acabe el duelo, aquí sale quién gana.")
  f:ClearAllPoints()
  local at = BG.db.settings and BG.db.settings.faceAt
  if type(at) == "table" and tonumber(at[1]) and tonumber(at[2]) then
    f:SetPoint("CENTER", UIParent, "BOTTOMLEFT", at[1], at[2])
  else
    f:SetPoint("TOP", UIParent, "TOP", 0, -120)
  end
  f:SetScale(scale())
  f:Show()
  BG.UI.FaceOffTick()
  return f
end

function BG.UI.FaceOffFrame()
  return frame
end

BG:On("BG_FACE_RESULT", function(w, l)
  local f = frame
  if f and f:IsShown() and f.pair and ((f.pair.A == w and f.pair.B == l) or (f.pair.A == l and f.pair.B == w)) then
    f.result:SetText(string.format("Gana %s", w))
    BG.Sound("READY_CHECK")
    -- (the ratings change a moment later, when the loser's addon writes the duel down)
    C_Timer.After(4, function()
      if f:IsShown() and f.pair then
        local model = Face.Model(f.pair.A, f.pair.B)
        if model then
          fill(f.A, model.a)
          fill(f.B, model.b)
          local m = model.meetings
          f.meet:SetText((m.a + m.b) > 0 and string.format("Entre ellos: %d-%d", m.a, m.b) or "Nunca se han enfrentado")
        end
      end
    end)
  end
end)

BG.commands = BG.commands or {}
BG.commands.duelo = function()
  BG.UI.WatchDuel()
end

-- «Ver el duelo»: the player we target and the one they target.
function BG.UI.WatchDuel()
  local a, b = Face.PairFromTarget()
  if not a then
    BG:Notify("Ver un duelo", "Pon en tu objetivo a uno de los dos que se baten (él tiene que tener al otro en su objetivo) y pulsa otra vez.", { kind = "info" })
    return nil
  end
  return BG.UI.FaceOff(a, b)
end
