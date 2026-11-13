-- The tournament's bracket, over the Arena screen: one column per round (the first on the left, the final on the
-- right), each match a box with its two fighters, joined by lines to the next. The winner shows in gold, the one
-- who fell dimmed; a bye says so; a match still waiting says «por decidir». Hovering a match tells how it was
-- decided; whoever runs the tournament may click a match to decide it by hand (someone did not come).
local _, BG = ...
local UI, C = BG.UI, BG.color
local T, Names = BG.Tourney, BG.Names

local PAD = 20
local COL_GAP = 28
local HOW = { K = "por K.O.", F = "se rindió", W = "decidido a mano", B = "pase directo" }

local function sideText(name, m)
  if name == nil then
    return BG.colorize("por decidir", C.text3)
  elseif name == false then
    return BG.colorize("(nadie)", C.text3)
  end
  local member = BG.Guild.Find(name)
  local cc = BG.classColor(member and member.classFile)
  if m.winner and m.winner ~= name then
    return BG.colorize(name, C.text3)
  end
  if m.winner == name then
    return BG.colorize(name, C.goldTitle) -- (the one who goes on, in gold)
  end
  return BG.colorize(name, cc)
end

local function matchBox(view)
  local b = CreateFrame("Button", nil, view.area)
  b.bg = b:CreateTexture(nil, "BACKGROUND")
  b.bg:SetAllPoints()
  b.bg:SetColorTexture(C.sunken[1], C.sunken[2], C.sunken[3], 0.95)
  b.edge = UI.Border(b, C.line, 0.9)
  local hl = b:CreateTexture(nil, "HIGHLIGHT")
  hl:SetColorTexture(C.gold[1], C.gold[2], C.gold[3], 0.08)
  hl:SetAllPoints()
  b.a = UI.Text(b, 12, C.text)
  b.a:SetPoint("TOPLEFT", 8, -5)
  b.a:SetPoint("RIGHT", -6, 0)
  b.b = UI.Text(b, 12, C.text)
  b.b:SetPoint("BOTTOMLEFT", 8, 5)
  b.b:SetPoint("RIGHT", -6, 0)
  b.sep = b:CreateTexture(nil, "ARTWORK")
  b.sep:SetColorTexture(C.line[1], C.line[2], C.line[3], 0.6)
  b.sep:SetHeight(1)
  b.sep:SetPoint("LEFT", 4, 0)
  b.sep:SetPoint("RIGHT", -4, 0)
  b:SetScript("OnEnter", function(self)
    local m = self.m
    if not (GameTooltip and m) then
      return
    end
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetText(T.RoundName(view.R, m.round), C.gold[1], C.gold[2], C.gold[3])
    if m.winner then
      GameTooltip:AddLine("Pasa " .. m.winner .. " (" .. (HOW[m.method] or "") .. ")" .. (m.at and m.method ~= "B" and (", " .. UI.FormatDate(m.at, true)) or ""), 1, 1, 1, true)
    elseif m.a and m.b then
      GameTooltip:AddLine("Lo decide su primer duelo: clic derecho en el retrato del otro, «Duelo».", 1, 1, 1, true)
    else
      GameTooltip:AddLine("Esperando a que se decidan los combates de antes.", 0.8, 0.8, 0.8, true)
    end
    if view.canManage and m.a and m.b then
      GameTooltip:AddLine("Pulsa para decidirlo a mano (si alguien no se presenta).", 0.6, 0.6, 0.6, true)
    end
    BG.ShowTip()
  end)
  b:SetScript("OnLeave", function()
    if GameTooltip then
      GameTooltip:Hide()
    end
  end)
  b:SetScript("OnClick", function(self)
    local m = self.m
    if not (view.canManage and m and m.a and m.b) then
      return
    end
    local id = view.tid
    if m.method == "W" then
      UI.Dialog({ title = "Decidido a mano", items = { "Pasa " .. m.winner .. ", decidido por quien dirige el torneo.", { note = "Puedes dejar que lo decida su duelo." } },
        primary = { label = "Que lo decida el duelo", fn = function()
          T.Decide(id, m.key, nil)
        end }, secondary = { label = "Dejarlo así" } })
      return
    end
    UI.Dialog({ title = "¿Quién pasa?", items = { m.a .. " contra " .. m.b .. ".", { note = "Úsalo solo si alguien no se presenta: lo normal es que lo decida su duelo." } },
      primary = { label = "Pasa " .. m.a, fn = function()
        T.Decide(id, m.key, m.a)
      end },
      secondary = { label = "Pasa " .. m.b, fn = function()
        T.Decide(id, m.key, m.b)
      end } })
  end)
  return b
end

function BG.UI.Bracket(host)
  local view = UI.Plate(host, { corners = 22, rail = 0.3 })
  view:SetFrameLevel(host:GetFrameLevel() + 20)
  view:EnableMouse(true)
  view:SetPoint("TOPLEFT", 16, -12)
  view:SetPoint("BOTTOMRIGHT", -16, 12)
  view:Hide()
  view.heading = UI.Heading(view, "Cuadro")
  view.heading:SetPoint("TOPLEFT", PAD, -14)
  view.heading:SetPoint("TOPRIGHT", -PAD, -14)
  view.back = UI.Button(view, "Volver", { height = 28, width = 96 })
  view.back:SetPoint("BOTTOMRIGHT", -PAD, 14)
  view.back:SetScript("OnClick", function()
    view:Hide()
  end)
  view.note = UI.Text(view, 11, C.text3, { wrap = true })
  view.note:SetPoint("BOTTOMLEFT", PAD, 18)
  view.note:SetPoint("RIGHT", view.back, "LEFT", -12, 0)
  view.note:SetMaxLines(2)
  view.area = CreateFrame("Frame", nil, view)
  view.area:SetPoint("TOPLEFT", view.heading, "BOTTOMLEFT", 0, -26)
  view.area:SetPoint("BOTTOMRIGHT", -PAD, 56)
  view.boxes, view.lines, view.titles = {}, {}, {}

  local function line(i)
    local l = view.lines[i]
    if not l then
      l = view.area:CreateTexture(nil, "BORDER")
      l:SetColorTexture(C.gold[1], C.gold[2], C.gold[3], 0.45)
      view.lines[i] = l
    end
    l:ClearAllPoints()
    l:Show()
    return l
  end

  function view:Draw()
    local t = T.Get(self.tid)
    if not (t and self:IsShown()) then
      self:Hide()
      return
    end
    self.canManage = T.CanManage(t)
    local b = T.Bracket(t)
    self.R = b.rounds
    self.heading:SetText(t.d.title .. (b.champion and (", campeón: " .. b.champion) or ""))
    local w, h = self.area:GetWidth(), self.area:GetHeight()
    if not w or w <= 0 or not h or h <= 0 then
      return
    end
    local R = b.rounds
    local colW = math.floor((w - COL_GAP * (R - 1)) / R)
    local used, nl = 0, 0
    local centers = {}
    for r = 1, R do
      local list = b.matches[r]
      local M = #list
      local slotH = h / M
      local bh = math.min(46, math.floor(slotH - 6))
      local x = (r - 1) * (colW + COL_GAP)
      local title = self.titles[r] or UI.Text(self.area, 11, C.gold)
      self.titles[r] = title
      title:ClearAllPoints()
      title:SetPoint("BOTTOMLEFT", self.area, "TOPLEFT", x + 2, 6)
      title:SetText(T.RoundName(R, r))
      title:Show()
      centers[r] = {}
      for i, m in ipairs(list) do
        used = used + 1
        local box = self.boxes[used] or matchBox(self)
        self.boxes[used] = box
        box.m = m
        local cy = (i - 0.5) * slotH
        centers[r][i] = cy
        box:ClearAllPoints()
        box:SetPoint("TOPLEFT", self.area, "TOPLEFT", x, -(cy - bh / 2))
        box:SetSize(colW, bh)
        box.a:SetText(sideText(m.a, m))
        box.b:SetText(sideText(m.b, m))
        local done = m.winner ~= nil
        local e = done and C.gold or C.line
        for _, tex in ipairs(box.edge) do
          tex:SetColorTexture(e[1], e[2], e[3], done and 0.55 or 0.9)
        end
        box:Show()
        -- lines to the next round (from each pair's middle)
        if r < R and i % 2 == 0 then
          local y1, y2 = centers[r][i - 1], cy
          local xr = x + colW
          local xm = xr + COL_GAP / 2
          local l1 = line(nl + 1)
          l1:SetPoint("TOPLEFT", self.area, "TOPLEFT", xr, -y1)
          l1:SetSize(COL_GAP / 2, 1)
          local l2 = line(nl + 2)
          l2:SetPoint("TOPLEFT", self.area, "TOPLEFT", xr, -y2)
          l2:SetSize(COL_GAP / 2, 1)
          local l3 = line(nl + 3)
          l3:SetPoint("TOPLEFT", self.area, "TOPLEFT", xm, -y1)
          l3:SetSize(1, y2 - y1)
          local l4 = line(nl + 4)
          l4:SetPoint("TOPLEFT", self.area, "TOPLEFT", xm, -(y1 + y2) / 2)
          l4:SetSize(COL_GAP / 2, 1)
          nl = nl + 4
        end
      end
    end
    for i = used + 1, #self.boxes do
      self.boxes[i]:Hide()
    end
    for i = nl + 1, #self.lines do
      self.lines[i]:Hide()
    end
    for r = R + 1, #self.titles do
      self.titles[r]:Hide()
    end
    local rolls = #t.d.rolls > 0 and ("Sorteo con /roll: " .. table.concat(t.d.rolls, ", ") .. ". ") or ""
    self.note:SetText(b.champion and BG.colorize("¡" .. b.champion .. " gana el torneo!", C.gold) .. " " .. rolls
      or (rolls .. "Cada combate lo decide el primer duelo entre los dos. " .. (self.canManage and "Pulsa un combate para decidirlo a mano." or "")))
  end

  function view:Open(id)
    self.tid = id
    self:Show()
    self:Draw()
  end

  view:SetScript("OnSizeChanged", function(self)
    self:Draw()
  end)
  BG:On("BG_TOURNEY_CHANGED", function()
    if view:IsShown() then
      view:Draw()
    end
  end)
  return view
end
