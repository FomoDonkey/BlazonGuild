-- Presentation pieces shared by the sections: a cinematic banner with official art (the web's .cinematic
-- covers) and on-screen notices ("toasts") so results never hide in the chat box.
local _, BG = ...
local UI, C = BG.UI, BG.color

-- Banner: official art cropped to the banner's shape, dark gradients for legibility, gold rule, an optional
-- icon in a gold ring, a title and a subtitle. h:SetArt(path, focus) — focus 0..1 picks the art's height.
function UI.Hero(parent, height)
  local h = CreateFrame("Frame", nil, parent)
  h:SetHeight(height or 128)
  h:SetClipsChildren(true)
  h.focus = 0.36
  h.art = h:CreateTexture(nil, "BACKGROUND")
  h.art:SetAllPoints()
  local function crop(self, w, hh)
    if w and hh and w > 0 and hh > 0 then
      local visible = math.min(1, (4 / 3) / (w / hh))
      local top = math.max(0, math.min(1 - visible, self.focus - visible / 2))
      self.art:SetTexCoord(0, 1, top, top + visible)
    end
  end
  h:SetScript("OnSizeChanged", crop)
  local left = h:CreateTexture(nil, "BORDER")
  left:SetColorTexture(1, 1, 1, 1)
  left:SetGradient("HORIZONTAL", CreateColor(0.03, 0.04, 0.05, 0.94), CreateColor(0.03, 0.04, 0.05, 0.1))
  left:SetAllPoints()
  local bottom = h:CreateTexture(nil, "BORDER", nil, 1)
  bottom:SetColorTexture(1, 1, 1, 1)
  bottom:SetGradient("VERTICAL", CreateColor(0.04, 0.05, 0.07, 1), CreateColor(0.04, 0.05, 0.07, 0))
  bottom:SetPoint("BOTTOMLEFT")
  bottom:SetPoint("BOTTOMRIGHT")
  bottom:SetHeight(54)
  local rule = h:CreateTexture(nil, "ARTWORK")
  rule:SetColorTexture(1, 1, 1, 1)
  rule:SetGradient("HORIZONTAL", CreateColor(C.gold[1], C.gold[2], C.gold[3], 0.65), CreateColor(C.gold[1], C.gold[2], C.gold[3], 0))
  rule:SetHeight(1)
  rule:SetPoint("BOTTOMLEFT")
  rule:SetPoint("BOTTOMRIGHT")
  h.icon = h:CreateTexture(nil, "ARTWORK", nil, 2)
  h.icon:SetSize(52, 52)
  h.icon:SetPoint("LEFT", 26, -2)
  h.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
  h.ring = h:CreateTexture(nil, "ARTWORK", nil, 1)
  h.ring:SetTexture(BG.media .. "ring.png")
  h.ring:SetPoint("TOPLEFT", h.icon, "TOPLEFT", -7, 7)
  h.ring:SetPoint("BOTTOMRIGHT", h.icon, "BOTTOMRIGHT", 7, -7)
  h.title = UI.Text(h, 24, C.goldTitle, { font = BG.font.display })
  h.title:SetPoint("TOPLEFT", h.icon, "TOPRIGHT", 18, 2)
  h.title:SetPoint("RIGHT", -24, 0)
  h.sub = UI.Text(h, 13, C.text, { wrap = true })
  h.sub:SetPoint("TOPLEFT", h.title, "BOTTOMLEFT", 0, -6)
  h.sub:SetPoint("RIGHT", -24, 0)
  h.sub:SetMaxLines(2)
  function h:SetArt(path, focus)
    self.focus = focus or 0.36
    self.art:SetTexture(path)
    crop(self, self:GetWidth(), self:GetHeight())
  end
  function h:SetIcon(path, coords)
    self.icon:SetShown(path ~= nil)
    self.ring:SetShown(path ~= nil)
    if path then
      self.icon:SetTexture(path)
      if coords then
        self.icon:SetTexCoord(coords[1], coords[2], coords[3], coords[4])
      else
        self.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
      end
      self.title:SetPoint("TOPLEFT", self.icon, "TOPRIGHT", 18, 2)
    else
      self.title:SetPoint("TOPLEFT", 28, -((self:GetHeight() or 128) / 2 - 22))
    end
  end
  return h
end

-- Notices ----------------------------------------------------------------------------------------------
-- BG:Notify(title, text, { kind = "success" | "warning" | "info" | "danger", icon, view, duration })
-- Up to three stacked at the top of the screen; a click opens `view` in the main window.
local stack = {}
local pool = {}
local KIND = { success = C.success, warning = C.warning, info = C.info, danger = C.danger }
local SHOW, FADE = 7, 0.4

local function layout()
  for i, t in ipairs(stack) do
    t:ClearAllPoints()
    t:SetPoint("TOP", UIParent, "TOP", 0, -120 - (i - 1) * 84)
  end
end

local function release(t)
  for i, s in ipairs(stack) do
    if s == t then
      table.remove(stack, i)
      break
    end
  end
  t:Hide()
  pool[#pool + 1] = t
  layout()
end

local function make()
  local t = UI.Plate(UIParent, { corners = 18, rail = 0.4 })
  t:SetFrameStrata("DIALOG")
  t:SetSize(400, 74)
  t:EnableMouse(true)
  t.accent = t:CreateTexture(nil, "ARTWORK")
  t.accent:SetPoint("TOPLEFT", 1, -1)
  t.accent:SetPoint("BOTTOMLEFT", 1, 1)
  t.accent:SetWidth(3)
  t.icon = t:CreateTexture(nil, "ARTWORK")
  t.icon:SetSize(36, 36)
  t.icon:SetPoint("LEFT", 16, 0)
  t.title = UI.Text(t, 14, C.goldTitle, { font = BG.font.display })
  t.title:SetPoint("TOPLEFT", t.icon, "TOPRIGHT", 12, 4)
  t.title:SetPoint("RIGHT", -14, 0)
  t.text = UI.Text(t, 12, C.text, { wrap = true })
  t.text:SetPoint("TOPLEFT", t.title, "BOTTOMLEFT", 0, -4)
  t.text:SetPoint("RIGHT", -14, 0)
  t.text:SetMaxLines(2)
  t:SetScript("OnMouseUp", function(self)
    if self.view then
      if not (BG.window and BG.window:IsShown()) then
        BG:ToggleWindow()
      end
      BG:ShowView(self.view)
    end
    release(self)
  end)
  t:SetScript("OnUpdate", function(self, elapsed)
    self.age = self.age + elapsed
    local a = 1
    if self.age < FADE then
      a = self.age / FADE
    elseif self.age > self.duration - FADE then
      a = math.max(0, (self.duration - self.age) / FADE)
    end
    self:SetAlpha(a)
    if self.age >= self.duration then
      release(self)
    end
  end)
  return t
end

function BG:Notify(title, text, opts)
  opts = opts or {}
  local t = table.remove(pool) or make()
  local c = KIND[opts.kind or "info"] or C.info
  t.accent:SetColorTexture(c[1], c[2], c[3], 0.95)
  t.icon:SetTexture(opts.icon or (BG.media .. "logo.png"))
  t.icon:SetTexCoord(0, 1, 0, 1)
  if opts.iconCoords then
    t.icon:SetTexCoord(unpack(opts.iconCoords))
  end
  t.title:SetText(title)
  t.text:SetText(text or "")
  t.view = opts.view
  t.age, t.duration = 0, opts.duration or SHOW
  t:SetAlpha(0)
  table.insert(stack, 1, t)
  while #stack > 3 do
    release(stack[#stack])
  end
  layout()
  t:Show()
  BG.Sound(opts.sound or "TELL_MESSAGE")
  BG.lastNotice = { title = title, text = text }
  return t
end
