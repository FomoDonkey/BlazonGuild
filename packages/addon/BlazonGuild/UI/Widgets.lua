-- Building blocks of the in-game interface, drawn with BlazonGuild's own art (Media/*.png, exported from the web)
-- and the game's own fonts and official files. Same vocabulary as the web: plates, gold rails, filigree, lozenges.
local _, BG = ...

local UI = {}
BG.UI = UI
local C = BG.color

local function setColor(tex, c, a)
  tex:SetColorTexture(c[1], c[2], c[3], a or 1)
end

function UI.Tile(parent, file, layer, sub)
  local t = parent:CreateTexture(nil, layer or "BACKGROUND", nil, sub or 0)
  t:SetTexture(BG.media .. file, "REPEAT", "REPEAT")
  t:SetHorizTile(true)
  t:SetVertTile(true)
  t:SetAllPoints()
  return t
end

-- Vertical light falloff (top lighter, bottom darker), like the web's metal plates.
function UI.Shade(parent, topAlpha, bottomAlpha, layer)
  local t = parent:CreateTexture(nil, layer or "BACKGROUND", nil, 2)
  t:SetColorTexture(1, 1, 1, 1)
  t:SetGradient("VERTICAL", CreateColor(0, 0, 0, bottomAlpha or 0.25), CreateColor(1, 1, 1, topAlpha or 0.04))
  t:SetAllPoints()
  return t
end

-- 1px box made of four textures.
function UI.Border(parent, c, a, inset, layer)
  inset = inset or 0
  local edges = {}
  for i = 1, 4 do
    local t = parent:CreateTexture(nil, layer or "BORDER")
    setColor(t, c, a)
    edges[i] = t
  end
  edges[1]:SetPoint("TOPLEFT", inset, -inset)
  edges[1]:SetPoint("TOPRIGHT", -inset, -inset)
  edges[1]:SetHeight(1)
  edges[2]:SetPoint("BOTTOMLEFT", inset, inset)
  edges[2]:SetPoint("BOTTOMRIGHT", -inset, inset)
  edges[2]:SetHeight(1)
  edges[3]:SetPoint("TOPLEFT", inset, -inset)
  edges[3]:SetPoint("BOTTOMLEFT", inset, inset)
  edges[3]:SetWidth(1)
  edges[4]:SetPoint("TOPRIGHT", -inset, -inset)
  edges[4]:SetPoint("BOTTOMRIGHT", -inset, inset)
  edges[4]:SetWidth(1)
  return edges
end

-- Filigree corners (one PNG mirrored with tex coords).
function UI.Corners(parent, size, layer)
  local coords = { { "TOPLEFT", 0, 1, 0, 1 }, { "TOPRIGHT", 1, 0, 0, 1 }, { "BOTTOMLEFT", 0, 1, 1, 0 }, { "BOTTOMRIGHT", 1, 0, 1, 0 } }
  for _, k in ipairs(coords) do
    local t = parent:CreateTexture(nil, layer or "OVERLAY")
    t:SetTexture(BG.media .. "corner.png")
    t:SetSize(size, size)
    t:SetPoint(k[1])
    t:SetTexCoord(k[2], k[3], k[4], k[5])
  end
end

function UI.Text(parent, size, color, opts)
  opts = opts or {}
  local fs = parent:CreateFontString(nil, opts.layer or "OVERLAY")
  fs:SetFont(opts.font or BG.font.body, size or 12, opts.flags or "")
  local c = color or C.text
  fs:SetTextColor(c[1], c[2], c[3], opts.alpha or 1)
  if opts.shadow ~= false then
    fs:SetShadowColor(0, 0, 0, 0.9)
    fs:SetShadowOffset(1, -1)
  end
  fs:SetJustifyH(opts.justify or "LEFT")
  fs:SetWordWrap(opts.wrap or false)
  -- (in the chosen language: Core/Locale.lua; Spanish shows as it is)
  local set = fs.SetText
  fs.SetText = function(self, t)
    return set(self, BG.T(t))
  end
  return fs
end

-- Metal plate with gold hairline: the web's `.plate`.
function UI.Plate(parent, opts)
  opts = opts or {}
  local f = CreateFrame("Frame", nil, parent)
  UI.Tile(f, opts.tile or "metal.png")
  UI.Shade(f, 0.05, 0.28)
  UI.Border(f, { 0, 0, 0 }, 0.6)
  UI.Border(f, C.gold, opts.rail or 0.16, 1)
  if opts.corners then
    UI.Corners(f, opts.corners)
  end
  f.isPanel = true -- (tests check that nothing sticks out of it)
  return f
end

-- Section heading: lozenge, title and a gold rule fading to the right.
function UI.Heading(parent, text, note)
  local f = CreateFrame("Frame", nil, parent)
  f:SetHeight(30)
  local lz = f:CreateTexture(nil, "ARTWORK")
  lz:SetTexture(BG.media .. "lozenge.png")
  lz:SetSize(14, 14)
  lz:SetPoint("LEFT", 0, 2)
  local title = UI.Text(f, 16, C.goldTitle, { font = BG.font.display })
  title:SetPoint("LEFT", lz, "RIGHT", 7, 0)
  title:SetText(text)
  local rule = f:CreateTexture(nil, "ARTWORK")
  rule:SetColorTexture(1, 1, 1, 1)
  rule:SetGradient("HORIZONTAL", CreateColor(C.gold[1], C.gold[2], C.gold[3], 0.55), CreateColor(C.gold[1], C.gold[2], C.gold[3], 0))
  rule:SetHeight(1)
  rule:SetPoint("BOTTOMLEFT", 0, 0)
  rule:SetPoint("BOTTOMRIGHT", 0, 0)
  if note then
    local n = UI.Text(f, 11, C.text3)
    n:SetPoint("RIGHT", 0, 2)
    n:SetText(note)
    f.note = n
  end
  f.title = title
  -- (the heading is a Frame, which has no SetText of its own in the game: 0.15.0's Arena stopped on it)
  function f:SetText(t)
    self.title:SetText(t)
  end
  function f:GetText()
    return self.title:GetText()
  end
  return f
end

-- Heraldic medallion: gold rim with the guild's initial (the web's fallback crest).
function UI.Medallion(parent, size)
  local f = CreateFrame("Frame", nil, parent)
  f:SetSize(size, size)
  local ring = f:CreateTexture(nil, "ARTWORK")
  ring:SetTexture(BG.media .. "ring.png")
  ring:SetAllPoints()
  f.initial = UI.Text(f, math.floor(size * 0.42), C.goldHi, { font = BG.font.display, justify = "CENTER" })
  f.initial:SetPoint("CENTER", 0, 0)
  function f:SetName(name)
    local first = name and name:match("^[\1-\127\194-\244][\128-\191]*") or "?" -- first UTF-8 character
    self.initial:SetText(first:upper())
  end
  return f
end

-- Button in the Hybrid style: dark metal, gold rail on hover, pressed offset.
function UI.Button(parent, label, opts)
  opts = opts or {}
  local b = CreateFrame("Button", nil, parent)
  b:SetHeight(opts.height or 26)
  UI.Tile(b, "sunken.png")
  UI.Shade(b, 0.06, 0.3)
  local edge = UI.Border(b, opts.primary and C.gold or C.lineStrong, opts.primary and 0.7 or 0.45)
  local hl = b:CreateTexture(nil, "HIGHLIGHT")
  hl:SetColorTexture(C.gold[1], C.gold[2], C.gold[3], 0.12)
  hl:SetAllPoints()
  b.text = UI.Text(b, opts.size or 12, opts.primary and C.goldHi or C.text, { justify = "CENTER" })
  b.text:SetPoint("CENTER")
  b.text:SetText(label)
  b:SetWidth(opts.width or math.max(70, b.text:GetStringWidth() + 26))
  -- (the label is our own FontString: the game's Button:SetText would not change what shows)
  function b:SetText(t)
    self.text:SetText(t)
  end
  function b:GetText()
    return self.text:GetText()
  end
  b:SetScript("OnEnter", function()
    for _, t in ipairs(edge) do
      t:SetColorTexture(C.gold[1], C.gold[2], C.gold[3], 0.9)
    end
  end)
  b:SetScript("OnLeave", function()
    local c = opts.primary and C.gold or C.lineStrong
    for _, t in ipairs(edge) do
      t:SetColorTexture(c[1], c[2], c[3], opts.primary and 0.7 or 0.45)
    end
  end)
  b:SetScript("OnMouseDown", function() b.text:SetPoint("CENTER", 1, -1) end)
  b:SetScript("OnMouseUp", function() b.text:SetPoint("CENTER", 0, 0) end)
  return b
end

-- Stat plate with filigree corners: big figure, small-caps label, note.
function UI.StatPlate(parent)
  local p = UI.Plate(parent, { corners = 16, rail = 0.2 })
  p.value = UI.Text(p, 26, C.goldTitle, { font = BG.font.display, justify = "CENTER" })
  p.value:SetPoint("TOP", 0, -12)
  p.label = UI.Text(p, 10, { 0.78, 0.71, 0.55 }, { justify = "CENTER" })
  p.label:SetPoint("TOP", p.value, "BOTTOM", 0, -4)
  p.note = UI.Text(p, 10, C.text3, { justify = "CENTER" })
  p.note:SetPoint("TOP", p.label, "BOTTOM", 0, -2)
  -- The figure always fits its plate: a long one (an amount of gold) gets a smaller letter, never runs out of it.
  local function fit(self, w)
    w = (type(w) == "number" and w > 0) and w or self:GetWidth()
    if not w or w <= 0 then
      return
    end
    local size = 26
    self.value:SetWidth(0)
    self.value:SetFont(BG.font.display, size, "")
    while size > 12 and self.value:GetStringWidth() > w - 14 do
      size = size - 2
      self.value:SetFont(BG.font.display, size, "")
    end
    -- (still too long at the smallest letter: cut with "..." inside the plate; the mouse shows it whole)
    self.cut = self.value:GetStringWidth() > w - 14
    if self.cut then
      self.value:SetWidth(w - 14)
    end
    self:EnableMouse(self.cut)
  end
  p:SetScript("OnEnter", function(self)
    if self.cut and GameTooltip then
      GameTooltip:SetOwner(self, "ANCHOR_TOP")
      GameTooltip:SetText(self.value:GetText() or "", 1, 1, 1, 1, true)
      BG.ShowTip()
    end
  end)
  p:SetScript("OnLeave", function()
    if GameTooltip then
      GameTooltip:Hide()
    end
  end)
  p.Fit = fit
  p:HookScript("OnSizeChanged", fit)
  function p:Set(value, label, note)
    self.value:SetText(value)
    self.label:SetText(BG.Locale.Upper(BG.T(label)))
    self.note:SetText(note or "")
    fit(self)
  end
  return p
end

-- Horizontal bar for distributions.
function UI.Bar(parent)
  local f = CreateFrame("Frame", nil, parent)
  f:SetHeight(8)
  local bg = f:CreateTexture(nil, "BACKGROUND")
  bg:SetColorTexture(C.sunken[1], C.sunken[2], C.sunken[3], 1)
  bg:SetAllPoints()
  local fill = f:CreateTexture(nil, "ARTWORK")
  fill:SetPoint("TOPLEFT")
  fill:SetPoint("BOTTOMLEFT")
  function f:Set(fraction, c)
    self.fraction, self.c = fraction, c
    fill:SetColorTexture(c[1], c[2], c[3], 1)
    fill:SetWidth(math.max(2, (self:GetWidth() or 0) * math.min(1, fraction)))
  end
  -- Widths are only known after layout: re-apply when the bar gets its real size.
  f:SetScript("OnSizeChanged", function(self)
    if self.fraction then
      self:Set(self.fraction, self.c)
    end
  end)
  return f
end

function UI.Divider(parent)
  local t = parent:CreateTexture(nil, "ARTWORK")
  t:SetTexture(BG.media .. "divider.png")
  t:SetHeight(18)
  return t
end

-- Virtualised list: a fixed pool of rows over any number of items, wheel + draggable gold thumb.
function UI.List(parent, rowHeight, createRow, updateRow)
  local list = CreateFrame("Frame", nil, parent)
  list.rows, list.items, list.offset = {}, {}, 0
  list:EnableMouseWheel(true)

  local track = CreateFrame("Frame", nil, list)
  track:SetWidth(6)
  track:SetPoint("TOPRIGHT", 0, 0)
  track:SetPoint("BOTTOMRIGHT", 0, 0)
  local trackTex = track:CreateTexture(nil, "BACKGROUND")
  trackTex:SetColorTexture(C.sunken[1], C.sunken[2], C.sunken[3], 1)
  trackTex:SetAllPoints()
  local thumb = CreateFrame("Frame", nil, track)
  thumb:SetWidth(6)
  thumb:EnableMouse(true)
  local thumbTex = thumb:CreateTexture(nil, "ARTWORK")
  thumbTex:SetColorTexture(C.gold[1], C.gold[2], C.gold[3], 0.55)
  thumbTex:SetAllPoints()

  local function visibleCount()
    return math.max(1, math.floor((list:GetHeight() or rowHeight) / rowHeight))
  end

  local function maxOffset()
    return math.max(0, #list.items - visibleCount())
  end

  -- A card unfolded to show all its text (UI.Card) is taller: the rows after it move down by as much, and fewer
  -- fit. Only one card is unfolded at a time (list.unfolded holds its key).
  function list:Render()
    local n = visibleCount()
    local height = list:GetHeight() or 0
    local y, shown = 0, 0
    for i = 1, n do
      local row = self.rows[i]
      if not row then
        row = createRow(self)
        row:SetHeight(rowHeight)
        row:SetPoint("RIGHT", track, "LEFT", -6, 0)
        row.list = self
        self.rows[i] = row
      end
      local item = self.items[self.offset + i]
      if item and (i == 1 or height <= 0 or y + rowHeight <= height + 1) then
        row.extra = 0
        updateRow(row, item, self.offset + i)
        if row.Fit then
          row:Fit()
        end
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", 0, -y)
        row:SetPoint("RIGHT", track, "LEFT", -6, 0)
        row:Show()
        y = y + rowHeight + (row.extra or 0)
        shown = shown + 1
      else
        row:Hide()
      end
    end
    for i = n + 1, #self.rows do
      self.rows[i]:Hide()
    end
    n = math.max(1, shown)
    local total = #self.items
    if total <= n then
      track:Hide()
    else
      track:Show()
      local h = track:GetHeight()
      local th = math.max(24, h * n / total)
      thumb:SetHeight(th)
      thumb:ClearAllPoints()
      thumb:SetPoint("TOP", 0, -((h - th) * self.offset / maxOffset()))
    end
  end

  function list:SetItems(items)
    self.items = items
    self.offset = math.min(self.offset, maxOffset())
    self:Render()
  end

  function list:Scroll(delta)
    self.offset = math.max(0, math.min(maxOffset(), self.offset + delta))
    self:Render()
  end

  list:SetScript("OnMouseWheel", function(self, delta)
    self:Scroll(-delta * 3)
  end)
  list:SetScript("OnSizeChanged", function(self)
    self:Render()
  end)
  thumb:SetScript("OnMouseDown", function(self)
    local _, startY = GetCursorPosition()
    local startOffset = list.offset
    local scale = self:GetEffectiveScale()
    self:SetScript("OnUpdate", function()
      local _, y = GetCursorPosition()
      local h = track:GetHeight() - self:GetHeight()
      if h > 0 then
        local delta = (startY - y) / scale / h * maxOffset()
        list.offset = math.max(0, math.min(maxOffset(), math.floor(startOffset + delta + 0.5)))
        list:Render()
      end
    end)
  end)
  thumb:SetScript("OnMouseUp", function(self)
    self:SetScript("OnUpdate", nil)
  end)
  return list
end

-- Relative time in Spanish, from days.
function UI.Ago(days)
  if days == nil then
    return "—"
  end
  if days < 1 / 24 then
    return "hace poco"
  elseif days < 1 then
    return string.format("hace %d h", math.floor(days * 24))
  elseif days < 2 then
    return "hace 1 día"
  elseif days < 31 then
    return string.format("hace %d días", math.floor(days))
  elseif days < 365 then
    local m = math.floor(days / 30)
    return m == 1 and "hace 1 mes" or string.format("hace %d meses", m)
  end
  return "hace más de un año"
end
