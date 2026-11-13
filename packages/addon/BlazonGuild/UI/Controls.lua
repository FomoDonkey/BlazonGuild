-- Form controls drawn with BlazonGuild's art: a dropdown (our own list, no game menus), a text box,
-- segmented choices, a number stepper and a small icon button. Our own frames so nothing depends on
-- menu APIs that differ between clients, and nothing breaks with the gamepad interface.
local _, BG = ...
local UI, C = BG.UI, BG.color

-- Dropdown ---------------------------------------------------------------------------------------
-- options: list of { value, label, note?, disabled? }. onChange(value). The list opens under the button, scrolls with
-- the wheel when long and closes on a choice, on Escape or when the button is clicked again. opts.fill(): the
-- options made again each time the list opens (lists of people: the roster of that moment); opts.empty: what
-- the list says when there is nothing to choose (never an empty box).
local menu
local function getMenu()
  if menu then
    return menu
  end
  menu = CreateFrame("Frame", "BlazonGuildPickerMenu", UIParent)
  menu:SetFrameStrata("FULLSCREEN_DIALOG")
  menu:EnableMouse(true)
  menu:EnableMouseWheel(true)
  menu:Hide()
  UI.Tile(menu, "sunken.png")
  UI.Border(menu, { 0, 0, 0 }, 0.9)
  UI.Border(menu, C.gold, 0.35, 1)
  menu.rows = {}
  menu.offset = 0
  tinsert(UISpecialFrames, "BlazonGuildPickerMenu")
  menu:SetScript("OnMouseWheel", function(self, delta)
    local maxOffset = math.max(0, #self.options - #self.rows)
    self.offset = math.max(0, math.min(maxOffset, self.offset - delta))
    self:Render()
  end)
  function menu:Render()
    for i, row in ipairs(self.rows) do
      local opt = self.options[i + self.offset]
      row.option = opt
      row:SetShown(opt ~= nil)
      if opt then
        row.text:SetText(opt.label)
        row.note:SetText(opt.note or "")
        local selected = opt.value == self.owner.value
        local c = opt.disabled and C.text3 or (selected and C.goldTitle or C.text)
        row.text:SetTextColor(c[1], c[2], c[3])
        row:SetAlpha(opt.disabled and 0.6 or 1)
      end
    end
  end
  return menu
end

local ROW = 22
local MAX_ROWS = 12

function UI.Picker(parent, opts)
  opts = opts or {}
  local b = CreateFrame("Button", nil, parent)
  b:SetSize(opts.width or 200, opts.height or 26)
  UI.Tile(b, "sunken.png")
  local edge = UI.Border(b, C.lineStrong, 0.5)
  b.text = UI.Text(b, 12, C.text)
  b.text:SetPoint("LEFT", 10, 0)
  b.text:SetPoint("RIGHT", -24, 0)
  b.arrow = b:CreateTexture(nil, "ARTWORK")
  b.arrow:SetTexture(BG.media .. "sort.png")
  b.arrow:SetSize(10, 10)
  b.arrow:SetPoint("RIGHT", -9, 0)
  b.arrow:SetTexCoord(0, 1, 1, 0) -- pointing down
  b.options = {}
  b:SetScript("OnEnter", function()
    for _, t in ipairs(edge) do
      t:SetColorTexture(C.gold[1], C.gold[2], C.gold[3], 0.8)
    end
  end)
  b:SetScript("OnLeave", function()
    for _, t in ipairs(edge) do
      t:SetColorTexture(C.lineStrong[1], C.lineStrong[2], C.lineStrong[3], 0.5)
    end
  end)

  function b:SetOptions(list)
    self.options = list or {}
    self:SetValue(self.value, true) -- only refreshes the label; never fires onChange
  end
  function b:SetValue(value, silent)
    self.value = value
    local label = opts.placeholder or "Elegir…"
    for _, o in ipairs(self.options) do
      if o.value == value then
        label = o.label
      end
    end
    self.text:SetText(label)
    if not silent and opts.onChange then
      opts.onChange(value)
    end
  end
  function b:GetValue()
    return self.value
  end
  b:SetScript("OnClick", function(self)
    local m = getMenu()
    if m:IsShown() and m.owner == self then
      m:Hide()
      return
    end
    if opts.fill then
      self:SetOptions(opts.fill())
    end
    local list = self.options
    if #list == 0 then
      list = { { label = BG.colorize(opts.empty or "No hay nada que elegir ahora.", C.text3), disabled = true } }
    end
    m.owner, m.options, m.offset = self, list, 0
    local count = math.min(MAX_ROWS, #list)
    for i = #m.rows + 1, count do
      local row = CreateFrame("Button", nil, m)
      row:SetHeight(ROW)
      row:SetPoint("TOPLEFT", 3, -3 - (i - 1) * ROW)
      row:SetPoint("RIGHT", -3, 0)
      local hl = row:CreateTexture(nil, "HIGHLIGHT")
      hl:SetColorTexture(C.gold[1], C.gold[2], C.gold[3], 0.15)
      hl:SetAllPoints()
      row.text = UI.Text(row, 12, C.text)
      row.text:SetPoint("LEFT", 8, 0)
      row.note = UI.Text(row, 10, C.text3, { justify = "RIGHT" })
      row.note:SetPoint("RIGHT", -8, 0)
      row.text:SetPoint("RIGHT", row.note, "LEFT", -6, 0)
      row:SetScript("OnClick", function(r)
        if r.option and r.option.disabled then
          return
        end
        m:Hide()
        if r.option then
          m.owner:SetValue(r.option.value)
          BG.Sound("U_CHAT_SCROLL_BUTTON")
        end
      end)
      m.rows[i] = row
    end
    for i = count + 1, #m.rows do
      m.rows[i]:Hide()
    end
    m:SetSize(math.max(self:GetWidth(), opts.menuWidth or 0), count * ROW + 6)
    m:ClearAllPoints()
    m:SetPoint("TOPLEFT", self, "BOTTOMLEFT", 0, -2)
    m:SetScale(self:GetEffectiveScale() / UIParent:GetEffectiveScale())
    m:Render()
    m:Show()
  end)
  b:SetScript("OnHide", function(self)
    if menu and menu.owner == self then
      menu:Hide()
    end
  end)
  return b
end

-- Text box ---------------------------------------------------------------------------------------
-- Never takes the keyboard on its own (with the gamepad UI another addon's focus change can break the
-- game's own code, as Olympus found); the player clicks into it.
function UI.EditBox(parent, opts)
  opts = opts or {}
  local holder = CreateFrame("Frame", nil, parent)
  holder:SetSize(opts.width or 240, opts.height or 26)
  UI.Tile(holder, "sunken.png")
  UI.Border(holder, C.lineStrong, 0.5)
  local e = CreateFrame("EditBox", nil, holder)
  e:SetPoint("TOPLEFT", 8, 0)
  e:SetPoint("BOTTOMRIGHT", -8, 0)
  e:SetFont(BG.font.body, 12, "")
  e:SetTextColor(C.text[1], C.text[2], C.text[3])
  e:SetAutoFocus(false)
  e:SetMaxLetters(opts.maxLetters or 120)
  e:SetScript("OnEscapePressed", e.ClearFocus)
  e:SetScript("OnEnterPressed", function(self)
    self:ClearFocus()
    if opts.onEnter then
      opts.onEnter(self:GetText())
    end
  end)
  holder.placeholder = UI.Text(holder, 12, C.text3)
  holder.placeholder:SetPoint("LEFT", 9, 0)
  holder.placeholder:SetText(opts.placeholder or "")
  holder.placeholder.isPlaceholder = true -- (drawn inside the box on purpose)
  e:SetScript("OnTextChanged", function(self)
    holder.placeholder:SetShown((self:GetText() or "") == "")
  end)
  holder.edit = e
  function holder:GetText()
    return e:GetText() or ""
  end
  function holder:SetText(t)
    e:SetText(t or "")
    holder.placeholder:SetShown((t or "") == "")
  end
  return holder
end

-- Item links in our text boxes ----------------------------------------------------------------------------
-- Shift + click on an item (bags, character, chat, tooltips…) while one of our boxes that takes links has the focus,
-- or dragging an item onto it, puts the item's link there, as the game's chat box does. The game's own paths for a
-- link are followed after the game's own work (ChatEdit_InsertLink, ChatFrameUtil.InsertLink, and the bags'
-- HandleModifiedItemClick): one click may pass two of them, the link goes in once.
local linkBoxes = {}
local lastFocus, lastLink, lastLinkAt
local function insertLink(link)
  if type(link) ~= "string" or not link:find("|H", 1, true) or not BG.Gamepad.Allowed("links") then
    return false
  end
  local box
  for _, b in ipairs(linkBoxes) do
    if b:IsVisible() and (b:HasFocus() or (lastFocus == b and GetTime() - (b.focusLostAt or 0) < 0.5)) then
      box = b
    end
  end
  if not box then
    return false
  end
  if lastLink == link and GetTime() - (lastLinkAt or 0) < 0.25 then
    return true
  end
  lastLink, lastLinkAt = link, GetTime()
  box:SetFocus()
  box:Insert(link)
  return true
end
UI.InsertLink = insertLink

local linksHooked = false
local function hookLinks()
  if linksHooked or not hooksecurefunc then
    return
  end
  linksHooked = true
  if ChatEdit_InsertLink then
    pcall(hooksecurefunc, "ChatEdit_InsertLink", function(link)
      insertLink(link)
    end)
  end
  if ChatFrameUtil and ChatFrameUtil.InsertLink then
    pcall(hooksecurefunc, ChatFrameUtil, "InsertLink", function(link)
      insertLink(link)
    end)
  end
  if HandleModifiedItemClick then
    pcall(hooksecurefunc, "HandleModifiedItemClick", function(link)
      if IsModifiedClick and IsModifiedClick("CHATLINK") then
        insertLink(link)
      end
    end)
  end
end

-- holder: a UI.EditBox. Its box takes item links by Shift + click and by dragging an item onto it.
function UI.AcceptLinks(holder)
  local e = holder.edit or holder
  linkBoxes[#linkBoxes + 1] = e
  hookLinks()
  e:HookScript("OnEditFocusGained", function(self)
    lastFocus = self
  end)
  e:HookScript("OnEditFocusLost", function(self)
    self.focusLostAt = GetTime()
  end)
  local function drop(self)
    if not GetCursorInfo then
      return
    end
    local kind, id, link = GetCursorInfo()
    if kind ~= "item" then
      return
    end
    if type(link) ~= "string" and id then
      link = select(2, BG.ItemInfo(id))
    end
    if type(link) == "string" then
      if ClearCursor then
        ClearCursor()
      end
      self:SetFocus()
      self:Insert(link)
    end
  end
  e:SetScript("OnReceiveDrag", drop)
  e:HookScript("OnMouseDown", function(self)
    if GetCursorInfo and GetCursorInfo() then
      drop(self)
    end
  end)
  return holder
end

-- Segmented choice ---------------------------------------------------------------------------------
-- items: { { value, label, icon? } }; one is selected; onChange(value).
function UI.Segmented(parent, items, opts)
  opts = opts or {}
  local f = CreateFrame("Frame", nil, parent)
  f:SetHeight(opts.height or 26)
  f.buttons = {}
  local x = 0
  for i, it in ipairs(items) do
    local b = CreateFrame("Button", nil, f)
    b:SetHeight(opts.height or 26)
    b.bg = b:CreateTexture(nil, "BACKGROUND")
    b.bg:SetAllPoints()
    b.edge = UI.Border(b, C.lineStrong, 0.45)
    local hl = b:CreateTexture(nil, "HIGHLIGHT")
    hl:SetColorTexture(C.gold[1], C.gold[2], C.gold[3], 0.1)
    hl:SetAllPoints()
    local left = 10
    if it.icon or it.role then
      b.icon = b:CreateTexture(nil, "ARTWORK")
      b.icon:SetSize(it.role and 18 or 16, it.role and 18 or 16)
      b.icon:SetPoint("LEFT", 6, 0)
      if it.role then
        BG.setRoleIcon(b.icon, it.role) -- the game's own role icons
      else
        b.icon:SetTexture(it.icon)
        b.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
      end
      left = 28
    end
    b.text = UI.Text(b, 12, C.text)
    b.text:SetPoint("LEFT", left, 0)
    b.text:SetText(it.label)
    local w = opts.itemWidth or math.max(64, b.text:GetStringWidth() + left + 12)
    b:SetWidth(w)
    b:SetPoint("LEFT", x, 0)
    x = x + w - 1
    b.value = it.value
    b:SetScript("OnClick", function()
      f:SetValue(it.value)
      BG.Sound("U_CHAT_SCROLL_BUTTON")
    end)
    f.buttons[i] = b
  end
  f:SetWidth(x + 1)
  function f:SetValue(value, silent)
    self.value = value
    for _, b in ipairs(self.buttons) do
      local on = b.value == value
      b.bg:SetColorTexture(on and C.gold[1] or C.sunken[1], on and C.gold[2] or C.sunken[2], on and C.gold[3] or C.sunken[3], on and 0.22 or 0.9)
      for _, t in ipairs(b.edge) do
        t:SetColorTexture(on and C.gold[1] or C.lineStrong[1], on and C.gold[2] or C.lineStrong[2], on and C.gold[3] or C.lineStrong[3], on and 0.85 or 0.45)
      end
      local tc = on and C.goldTitle or C.text2
      b.text:SetTextColor(tc[1], tc[2], tc[3])
    end
    if not silent and opts.onChange then
      opts.onChange(value)
    end
  end
  function f:GetValue()
    return self.value
  end
  function f:SetEnabledValues(allowed)
    for _, b in ipairs(self.buttons) do
      local ok = not allowed or allowed[b.value]
      b:SetEnabled(ok)
      b:SetAlpha(ok and 1 or 0.35)
    end
  end
  return f
end

-- Number stepper: label, − value +.
function UI.Stepper(parent, label, min, max, opts)
  opts = opts or {}
  local f = CreateFrame("Frame", nil, parent)
  f:SetSize(opts.width or 150, 26)
  f.label = UI.Text(f, 12, C.text2)
  f.label:SetPoint("LEFT")
  f.label:SetText(label)
  local plus = UI.Button(f, "+", { width = 24, height = 22 })
  plus:SetPoint("RIGHT")
  f.valueText = UI.Text(f, 13, C.goldTitle, { justify = "CENTER" })
  f.valueText:SetWidth(28)
  f.valueText:SetPoint("RIGHT", plus, "LEFT", -2, 0)
  local minus = UI.Button(f, "−", { width = 24, height = 22 })
  minus:SetPoint("RIGHT", f.valueText, "LEFT", -2, 0)
  function f:SetValue(v, silent)
    self.value = math.max(min, math.min(max, v or min))
    self.valueText:SetText(self.value)
    if not silent and opts.onChange then
      opts.onChange(self.value)
    end
  end
  function f:GetValue()
    return self.value
  end
  plus:SetScript("OnClick", function()
    f:SetValue(f.value + 1)
  end)
  minus:SetScript("OnClick", function()
    f:SetValue(f.value - 1)
  end)
  f:SetValue(opts.value or min, true)
  return f
end

-- Card: a plate row for lists of raids, groups and flags (title, subtitle, right note, accent bar).
-- A button on a card: the card's text ends before it (UI.Card's Fit). order: the higher, the further left.
function UI.CardButton(card, label, opts)
  local b = UI.Button(card, label, opts)
  card.actions = card.actions or {}
  card.actions[#card.actions + 1] = b
  b.order = #card.actions
  return b
end

function UI.Card(parent)
  local c = CreateFrame("Button", nil, parent)
  UI.Tile(c, "sunken.png")
  c.edge = UI.Border(c, C.line, 0.9)
  local hl = c:CreateTexture(nil, "HIGHLIGHT")
  hl:SetColorTexture(C.gold[1], C.gold[2], C.gold[3], 0.07)
  hl:SetAllPoints()
  c.accent = c:CreateTexture(nil, "ARTWORK")
  c.accent:SetPoint("TOPLEFT")
  c.accent:SetPoint("BOTTOMLEFT")
  c.accent:SetWidth(3)
  c.accent:SetColorTexture(C.gold[1], C.gold[2], C.gold[3], 0.8)
  c.icon = c:CreateTexture(nil, "ARTWORK")
  c.icon:SetSize(32, 32)
  c.icon:SetPoint("LEFT", 12, 0)
  c.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
  c.isPanel = true -- (tests check that nothing sticks out of it)
  c.title = UI.Text(c, 13, C.text, { font = BG.font.display })
  c.title:SetPoint("TOPLEFT", c.icon, "TOPRIGHT", 10, 1)
  c.sub = UI.Text(c, 11, C.text2)
  c.sub:SetPoint("TOPLEFT", c.title, "BOTTOMLEFT", 0, -4)
  c.right = UI.Text(c, 11, C.text3, { justify = "RIGHT" })
  c.right:SetPoint("TOPRIGHT", -12, -10)
  c.right2 = UI.Text(c, 11, C.text2, { justify = "RIGHT" })
  c.right2:SetPoint("TOPRIGHT", c.right, "BOTTOMRIGHT", 0, -4)
  c.title:SetPoint("RIGHT", c.right, "LEFT", -8, 0)
  c.sub:SetPoint("RIGHT", c.right2, "LEFT", -8, 0)
  -- The whole text, always: the sub line remembers what it was given (it may be cut on screen), and
  -- c.detail (optional) adds lines that only show unfolded.
  local setSub = c.sub.SetText
  function c.sub.SetText(fs, t)
    c.subFull = t
    setSub(fs, t)
  end
  c.actions = {}
  c.more = UI.Text(c, 12, C.text2, { wrap = true })
  c.more:SetPoint("TOPLEFT", c.sub, "BOTTOMLEFT", 0, -6)
  c.more:SetPoint("RIGHT", -12, 0)
  c.more:SetSpacing(2)
  c.more:Hide()
  local function key()
    return c.key or c.title:GetText()
  end
  -- After its row is filled (UI.List): the sub line ends before the buttons, and an unfolded card shows all.
  function c:Fit()
    local left
    for _, b in ipairs(self.actions) do
      if b:IsShown() and (not left or (b.order or 0) > (left.order or 0)) then
        left = b
      end
    end
    self.sub:ClearAllPoints()
    self.sub:SetPoint("TOPLEFT", self.title, "BOTTOMLEFT", 0, -4)
    if left then
      self.sub:SetPoint("RIGHT", left, "LEFT", -8, 0)
    else
      self.sub:SetPoint("RIGHT", self.right2, "LEFT", -8, 0)
    end
    local open = self.list ~= nil and self.list.unfolded ~= nil and self.list.unfolded == key()
    self.unfolded = open
    self.sub:SetWordWrap(open)
    if open then
      self.sub:ClearAllPoints()
      self.sub:SetPoint("TOPLEFT", self.title, "BOTTOMLEFT", 0, -4)
      self.sub:SetPoint("RIGHT", -12, 0)
      local lines = {}
      for _, l in ipairs(self.detail or {}) do
        lines[#lines + 1] = l
      end
      self.more:SetText(table.concat(lines, "\n"))
      self.more:SetShown(#lines > 0)
      local base = self.baseHeight or self:GetHeight()
      -- The icon (and the title beside it) keep their place: the card grows downwards, and all its text ends
      -- above its buttons, which stay at the bottom.
      local top = math.floor((base - 32) / 2)
      if self.iconCentered ~= false then
        self.icon:ClearAllPoints()
        self.icon:SetPoint("TOPLEFT", 12, -top)
      end
      local textBottom = top + 14 + 4 + (self.sub:GetStringHeight() or 14) + (#lines > 0 and ((self.more:GetStringHeight() or 14) + 6) or 0)
      local h = math.max(base, math.floor(textBottom + (left and 40 or 12) + 0.5))
      self.extra = h - base
      self:SetHeight(h)
    else
      self.more:Hide()
      self.extra = 0
      if self.iconCentered ~= false then
        self.icon:ClearAllPoints()
        self.icon:SetPoint("LEFT", 12, 0)
      end
    end
  end
  local setHeight = c.SetHeight
  function c.SetHeight(frame, h)
    if not frame.unfolded then
      frame.baseHeight = h
    end
    setHeight(frame, h)
  end
  c:SetScript("OnClick", function(self)
    if not self.list then
      return
    end
    local k = key()
    self.list.unfolded = self.list.unfolded ~= k and k or nil
    BG.Sound("U_CHAT_SCROLL_BUTTON")
    self.list:Render()
  end)
  c:SetScript("OnEnter", function(self)
    if not GameTooltip then
      return
    end
    GameTooltip:SetOwner(self, "ANCHOR_CURSOR")
    GameTooltip:SetText(self.title:GetText() or "", C.gold[1], C.gold[2], C.gold[3], 1, true)
    if self.subFull and self.subFull ~= "" then
      GameTooltip:AddLine(self.subFull, 1, 1, 1, true)
    end
    for _, l in ipairs(self.detail or {}) do
      GameTooltip:AddLine(l, 0.8, 0.8, 0.8, true)
    end
    GameTooltip:AddLine(self.unfolded and "Pulsa para recogerla." or "Pulsa para leerla entera aquí.", 0.6, 0.6, 0.6, true)
    BG.ShowTip()
  end)
  c:SetScript("OnLeave", function()
    if GameTooltip then
      GameTooltip:Hide()
    end
  end)
  function c:SetSelected(on)
    for _, t in ipairs(self.edge) do
      t:SetColorTexture(on and C.gold[1] or C.line[1], on and C.gold[2] or C.line[2], on and C.gold[3] or C.line[3], on and 0.7 or 0.9)
    end
  end
  return c
end

-- Date helpers in Spanish (the game's server time; shown in the player's local time like the calendar).
local DAYS = { "domingo", "lunes", "martes", "miércoles", "jueves", "viernes", "sábado" }
local MONTHS = { "enero", "febrero", "marzo", "abril", "mayo", "junio", "julio", "agosto", "septiembre", "octubre", "noviembre", "diciembre" }

function UI.FormatDate(t, withTime)
  local d = date("*t", t)
  local other = BG.Locale and BG.Locale.lang ~= "es" and BG.Locale.Date(d, withTime)
  if other then
    return other
  end
  local s = DAYS[d.wday] .. " " .. d.day .. " de " .. MONTHS[d.month]
  if withTime then
    s = s .. ", " .. string.format("%02d:%02d", d.hour, d.min)
  end
  return s
end

function UI.FormatTime(t)
  local d = date("*t", t)
  return string.format("%02d:%02d", d.hour, d.min)
end

-- Options for the next `days` days (value: local midnight) and for times of day every 30 minutes.
function UI.DayOptions(days)
  local now = time()
  local base = date("*t", now)
  local out = {}
  for i = 0, (days or 21) - 1 do
    local t = time({ year = base.year, month = base.month, day = base.day + i, hour = 0, min = 0, sec = 0 })
    local label = i == 0 and "Hoy" or (i == 1 and "Mañana" or UI.FormatDate(t))
    out[#out + 1] = { value = t, label = BG.Locale.UpperFirst(BG.T(label)), note = i > 1 and "" or UI.FormatDate(t) }
  end
  return out
end

function UI.TimeOptions(from, to)
  local out = {}
  for m = (from or 14) * 60, (to or 23) * 60 + 30, 30 do
    out[#out + 1] = { value = m * 60, label = string.format("%02d:%02d", math.floor(m / 60), m % 60) }
  end
  return out
end
