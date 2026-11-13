-- «Grupos de la banda»: the raid's groups as the game's raid frame shows them (Peregrino, 2026-11-13: "organizar los
-- equipos de la raid arrastrándolos y moviéndolos en campos como en el propio wow"). Over the Raids screen: on the
-- left who has no group yet and the reserve; on the right one box per group (2 for a 10, 4 for a 20, 8 for a 40),
-- five places each. The raid's leader, its creator and the organisers move players: drag a name with the mouse, or
-- click it and then click where it goes (dropping on someone swaps them; right click takes a player out of their
-- group). Everyone else sees it. «Repartir solos» spreads them by role; «Colocar en la banda» moves the real raid.
local _, BG = ...
local UI, C = BG.UI, BG.color
local Raids, Names = BG.Raids, BG.Names

local PAD = 20
local SIDE_W = 200
local CHIP_H = 22
local GAP = 10
local STATUS = { CONFIRMED = "va", TENTATIVE = "quizá" }

local function why(w)
  return ({ lleno = "Ese grupo ya tiene 5.", permiso = "Solo el líder de la raid, quien la creó y los oficiales pueden moverlos.",
    ["sin banda"] = "Primero forma la banda en el juego (puedes usar «Invitar confirmados»).", ["sin mando"] = "Tienes que ser líder o ayudante de la banda.",
    combate = "Espera a salir de combate.", ["sin juego"] = "Este cliente no deja a los addons mover a la gente de grupo.",
    tiempo = "El juego tardaba demasiado en responder; vuelve a pulsar.", capturas = "En el modo capturas no se hace nada en el juego: es solo una hermandad de ejemplo." })[w] or ("No se pudo (" .. tostring(w) .. ").")
end

-- The name that follows the mouse while dragging.
local ghost
local function ghostFrame()
  if ghost then
    return ghost
  end
  ghost = CreateFrame("Frame", nil, UIParent)
  ghost:SetSize(150, CHIP_H)
  ghost:SetFrameStrata("TOOLTIP")
  ghost.bg = ghost:CreateTexture(nil, "BACKGROUND")
  ghost.bg:SetAllPoints()
  ghost.bg:SetColorTexture(0.08, 0.09, 0.12, 0.92)
  UI.Border(ghost, C.gold, 0.8)
  ghost.text = UI.Text(ghost, 12, C.text)
  ghost.text:SetPoint("LEFT", 8, 0)
  ghost.text:SetPoint("RIGHT", -8, 0)
  ghost:SetScript("OnUpdate", function(self)
    if GetCursorPosition then
      local x, y = GetCursorPosition()
      local s = UIParent:GetEffectiveScale()
      self:ClearAllPoints()
      self:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", x / s + 12, y / s - 6)
    end
  end)
  ghost:Hide()
  return ghost
end

-- A player's name, to drag or click.
local function chip(parent, view)
  local b = CreateFrame("Button", nil, parent)
  b:SetHeight(CHIP_H)
  b.bg = b:CreateTexture(nil, "BACKGROUND")
  b.bg:SetAllPoints()
  b.bg:SetColorTexture(C.sunken[1], C.sunken[2], C.sunken[3], 0.9)
  b.picked = b:CreateTexture(nil, "BORDER")
  b.picked:SetAllPoints()
  b.picked:SetColorTexture(C.gold[1], C.gold[2], C.gold[3], 0.22)
  b.picked:Hide()
  local hl = b:CreateTexture(nil, "HIGHLIGHT")
  hl:SetColorTexture(C.gold[1], C.gold[2], C.gold[3], 0.1)
  hl:SetAllPoints()
  b.role = b:CreateTexture(nil, "ARTWORK")
  b.role:SetSize(14, 14)
  b.role:SetPoint("LEFT", 4, 0)
  b.text = UI.Text(b, 12, C.text)
  b.text:SetPoint("LEFT", b.role, "RIGHT", 5, 0)
  b.text:SetPoint("RIGHT", -4, 0)
  b:RegisterForDrag("LeftButton")
  b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
  b:SetScript("OnDragStart", function(self)
    view:StartDrag(self)
  end)
  b:SetScript("OnDragStop", function(self)
    view:StopDrag(self)
  end)
  b:SetScript("OnClick", function(self, button)
    view:ChipClick(self, button)
  end)
  b:SetScript("OnEnter", function(self)
    if not (GameTooltip and self.entry) then
      return
    end
    local d = self.entry.d
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetText(d.name, BG.classColor(d.class)[1], BG.classColor(d.class)[2], BG.classColor(d.class)[3])
    GameTooltip:AddLine((BG.Instances.Role(d.role) and BG.Instances.Role(d.role).name or "") .. ", " .. (STATUS[d.status] or "") .. (d.level and (", nivel " .. d.level) or ""), 1, 1, 1)
    if d.note and d.note ~= "" then
      GameTooltip:AddLine("«" .. d.note .. "»", 0.8, 0.8, 0.8, true)
    end
    if view.canManage then
      GameTooltip:AddLine("Arrástralo a un grupo, o púlsalo y luego pulsa dónde va. Clic derecho: sin grupo.", 0.6, 0.6, 0.6, true)
    end
    BG.ShowTip()
  end)
  b:SetScript("OnLeave", function()
    if GameTooltip then
      GameTooltip:Hide()
    end
  end)
  return b
end

local function fillChip(b, entry, view)
  b.entry = entry
  b.name = entry and entry.d.name
  if not entry then
    b:Hide()
    return
  end
  local d = entry.d
  BG.setRoleIcon(b.role, d.role)
  b.text:SetText(BG.colorize(d.name, BG.classColor(d.class)) .. (d.status == "TENTATIVE" and BG.colorize(" (quizá)", C.text3) or ""))
  b.picked:SetShown(view.picked == d.name)
  b:Show()
end

-- A place to drop on: a side list or a group box (the plate itself: a click on it drops what is picked), or one
-- of a group's places (a button).
local function target(view, frame, place, slot)
  view.targets[#view.targets + 1] = { f = frame, place = place, slot = slot }
  frame:EnableMouse(true)
  local function drop()
    if view.picked then
      view:Drop(view.picked, place, slot and slot.chip.name, slot and slot.row)
    end
  end
  if slot then
    frame:RegisterForClicks("LeftButtonUp")
    frame:SetScript("OnClick", drop)
  else
    frame:SetScript("OnMouseUp", drop)
  end
end

local function sideList(view, parent, title, place)
  local p = UI.Plate(parent, { corners = 14, rail = 0.22 })
  p.head = UI.Heading(p, title)
  p.head:SetPoint("TOPLEFT", 12, -6)
  p.head:SetPoint("TOPRIGHT", -12, -6)
  target(view, p, place) -- (the whole plate takes a drop)
  p.list = UI.List(p, CHIP_H + 3, function(list)
    return chip(list, view)
  end, function(b, entry)
    fillChip(b, entry, view)
  end)
  p.list:SetPoint("TOPLEFT", p.head, "BOTTOMLEFT", 0, -8)
  p.list:SetPoint("BOTTOMRIGHT", -12, 10)
  p.empty = UI.Text(p, 11, C.text3, { wrap = true })
  p.empty:SetPoint("TOPLEFT", p.head, "BOTTOMLEFT", 0, -10)
  p.empty:SetPoint("RIGHT", -12, 0)
  return p
end

local function groupBox(view, parent, n)
  local box = UI.Plate(parent, { corners = 12, rail = 0.2 })
  box.n = n
  target(view, box, n)
  box.title = UI.Text(box, 13, C.goldTitle, { font = BG.font.display })
  box.title:SetPoint("TOPLEFT", 10, -8)
  box.title:SetText("Grupo " .. n)
  box.count = UI.Text(box, 11, C.text3, { justify = "RIGHT" })
  box.count:SetPoint("TOPRIGHT", -10, -9)
  box.slots = {}
  for i = 1, 5 do
    local s = CreateFrame("Button", nil, box)
    s:SetHeight(CHIP_H)
    s:SetPoint("TOPLEFT", 8, -28 - (i - 1) * (CHIP_H + 3))
    s:SetPoint("TOPRIGHT", -8, -28 - (i - 1) * (CHIP_H + 3))
    s.bg = s:CreateTexture(nil, "BACKGROUND")
    s.bg:SetAllPoints()
    s.bg:SetColorTexture(1, 1, 1, 0.03)
    s.empty = UI.Text(s, 11, C.text3)
    s.empty:SetPoint("LEFT", 8, 0)
    s.empty:SetText("libre")
    s.row = i
    s.chip = chip(s, view)
    s.chip:SetAllPoints()
    target(view, s, n, s)
    box.slots[i] = s
  end
  return box
end

function BG.UI.RaidGroups(host)
  local view = UI.Plate(host, { corners = 22, rail = 0.3 })
  view:SetFrameLevel(host:GetFrameLevel() + 20)
  view:EnableMouse(true)
  view:SetPoint("TOPLEFT", 16, -12)
  view:SetPoint("BOTTOMRIGHT", -16, 12)
  view:Hide()
  view.targets, view.rowOf = {}, {}
  view.heading = UI.Heading(view, "Grupos de la banda")
  view.heading:SetPoint("TOPLEFT", PAD, -14)
  view.heading:SetPoint("TOPRIGHT", -PAD, -14)

  view.toolbar = CreateFrame("Frame", nil, view)
  view.toolbar:SetPoint("BOTTOMLEFT", PAD, 14)
  view.toolbar:SetPoint("BOTTOMRIGHT", -PAD, 14)
  view.toolbar:SetHeight(30)
  view.back = UI.Button(view.toolbar, "Volver", { height = 28, width = 96 })
  view.back:SetPoint("RIGHT")
  view.back:SetScript("OnClick", function()
    view:Hide()
  end)
  view.place = UI.Button(view.toolbar, "Colocar en la banda", { height = 28, width = 170, primary = true })
  view.place:SetPoint("RIGHT", view.back, "LEFT", -8, 0)
  view.place:SetScript("OnClick", function()
    local state, w = Raids.PlaceInRaid(view.raidId)
    if not state then
      view.note:SetText(BG.colorize(why(w), C.warning))
    elseif state == "done" then
      view.note:SetText(BG.colorize("La banda ya estaba como en el plan.", C.success))
    else
      view.note:SetText("Colocando a la gente en sus grupos…")
    end
  end)
  view.auto = UI.Button(view.toolbar, "Repartir solos", { height = 28, width = 130 })
  view.auto:SetPoint("RIGHT", view.place, "LEFT", -8, 0)
  view.auto:SetScript("OnClick", function()
    Raids.ApplyAutoGroups(view.raidId)
  end)
  view.note = UI.Text(view.toolbar, 11, C.text3, { wrap = true })
  view.note:SetPoint("LEFT")
  view.note:SetPoint("RIGHT", view.auto, "LEFT", -12, 0)
  view.note:SetMaxLines(2)

  view.side = CreateFrame("Frame", nil, view)
  view.side:SetPoint("TOPLEFT", view.heading, "BOTTOMLEFT", 0, -12)
  view.side:SetPoint("BOTTOM", view.toolbar, "TOP", 0, 12)
  view.side:SetWidth(SIDE_W)
  view.none = sideList(view, view.side, "Sin grupo", "none")
  view.bench = sideList(view, view.side, "Reserva", "bench")
  view.none:SetPoint("TOPLEFT")
  view.none:SetPoint("TOPRIGHT")
  view.bench:SetPoint("BOTTOMLEFT")
  view.bench:SetPoint("BOTTOMRIGHT")

  view.grid = CreateFrame("Frame", nil, view)
  view.grid:SetPoint("TOPLEFT", view.side, "TOPRIGHT", 16, 0)
  view.grid:SetPoint("BOTTOMRIGHT", view.toolbar, "TOPRIGHT", 0, 12)
  view.boxes = {}
  for n = 1, 8 do
    view.boxes[n] = groupBox(view, view.grid, n)
  end

  -- (sizes from the view's own: its parts are sized by their anchors, which the game resolves later)
  local function layout(self, w, h)
    local groups = self.groups or 8
    for n, box in ipairs(self.boxes) do
      box:SetShown(n <= groups)
    end
    w = (type(w) == "number" and w > 0) and w or self.lastW or self:GetWidth()
    h = (type(h) == "number" and h > 0) and h or self.lastH or self:GetHeight()
    if not w or w <= 0 or not h or h <= 0 then
      return
    end
    self.lastW, self.lastH = w, h
    local gridW = w - PAD * 2 - SIDE_W - 16
    local sideH = h - (14 + 30 + 12) - (14 + 30 + 12)
    self.none:SetHeight(math.floor((sideH - GAP) * 0.6))
    self.bench:SetHeight(math.floor((sideH - GAP) * 0.4))
    local cols = math.min(4, groups)
    local bw = math.floor((gridW - GAP * (cols - 1)) / cols)
    local bh = 28 + 5 * (CHIP_H + 3) + 6
    for n, box in ipairs(self.boxes) do
      local col, row = (n - 1) % cols, math.floor((n - 1) / cols)
      box:ClearAllPoints()
      box:SetPoint("TOPLEFT", self.grid, "TOPLEFT", col * (bw + GAP), -row * (bh + GAP))
      box:SetSize(bw, bh)
    end
  end
  view:SetScript("OnSizeChanged", layout)

  -- Dragging and dropping ---------------------------------------------------------------------------------------
  function view:StartDrag(b)
    if not (self.canManage and b.name) then
      return
    end
    self.dragging = b.name
    local g = ghostFrame()
    g.text:SetText(b.text:GetText() or b.name)
    g:Show()
  end

  function view:StopDrag(b)
    local name = self.dragging
    self.dragging = nil
    if ghost then
      ghost:Hide()
    end
    if not name then
      return
    end
    -- the place under the mouse: a group's place first, then its box, then a side list
    local hit
    for _, t in ipairs(self.targets) do
      if t.f:IsVisible() and t.f:IsMouseOver() and (not hit or (t.slot and not hit.slot)) then
        hit = t
      end
    end
    if hit then
      self:Drop(name, hit.place, hit.slot and hit.slot.chip.name, hit.slot and hit.slot.row)
    end
  end

  function view:ChipClick(b, button)
    if not (self.canManage and b.name) then
      return
    end
    if button == "RightButton" then
      self.picked = nil
      return self:Drop(b.name, "none")
    end
    if self.picked == b.name then
      self.picked = nil
    elseif self.picked then
      return self:Drop(self.picked, Raids.PlaceOf(self.raidId, b.name), b.name, b.row)
    else
      self.picked = b.name
      self.note:SetText("Ahora pulsa dónde va " .. b.name .. ": un grupo, «Sin grupo» o «Reserva». Si pulsas a otro jugador, se cambian el sitio.")
    end
    self:Refresh()
  end

  -- `name` goes to `place` (1-8, "none", "bench") and, in a group, to `row` if given (a free row: the player stays
  -- there; dropped on `onto`, another player, the two swap places, rows and all).
  function view:Drop(name, place, onto, row)
    self.picked = nil
    local ok, w
    if onto and onto ~= name then
      ok, w = Raids.Swap(self.raidId, name, onto, self.rowOf[name], row)
    elseif Raids.PlaceOf(self.raidId, name) == place and (not row or self.rowOf[name] == row) then
      ok = true
    else
      ok, w = Raids.Move(self.raidId, name, place, row)
    end
    self.note:SetText(ok and "" or BG.colorize(why(w), C.warning))
    self:Refresh()
    return ok, w
  end

  function view:Open(raidId)
    self.raidId, self.picked = raidId, nil
    self.note:SetText("")
    self:Show()
    self:Refresh()
  end

  function view:Refresh()
    local raid = Raids.Get(self.raidId)
    if not (raid and self:IsShown()) then
      self:Hide()
      return
    end
    self.canManage = Raids.CanManage(raid)
    self.groups = math.max(1, math.min(8, math.ceil((raid.d.cap or 40) / 5)))
    layout(self)
    self.heading:SetText("Grupos de la banda: " .. raid.d.title)
    local plan = Raids.Plan(raid.id)
    local none, bench, inGroup = {}, {}, {}
    for n = 1, 8 do
      inGroup[n] = {}
    end
    for _, s in ipairs(Raids.Signups(raid.id)) do
      if s.d.status ~= "DECLINED" then
        local name = s.d.name
        if plan.bench[name] then
          bench[#bench + 1] = s
        elseif plan.g[name] and plan.g[name] <= self.groups then
          table.insert(inGroup[plan.g[name]], s)
        else
          none[#none + 1] = s
        end
      end
    end
    local order = { TANK = 1, HEALER = 2, DPS = 3 }
    local function sorted(list)
      table.sort(list, function(a, b)
        if (a.d.status == "CONFIRMED") ~= (b.d.status == "CONFIRMED") then
          return a.d.status == "CONFIRMED"
        end
        if a.d.role ~= b.d.role then
          return (order[a.d.role] or 4) < (order[b.d.role] or 4)
        end
        return a.d.name < b.d.name
      end)
      return list
    end
    self.none.list:SetItems(sorted(none))
    self.bench.list:SetItems(sorted(bench))
    self.none.empty:SetShown(#none == 0)
    self.none.empty:SetText("Todos los apuntados tienen grupo.")
    self.bench.empty:SetShown(#bench == 0)
    self.bench.empty:SetText(self.canManage and "Arrastra aquí a quien quede de reserva." or "Nadie en reserva.")
    -- each group's rows: a player stays in the row they were put in; the rest fill the free rows by role
    self.rowOf = {}
    local byName = {}
    for n = 1, self.groups do
      local names = {}
      for _, s in ipairs(inGroup[n]) do
        names[#names + 1] = s.d.name
        byName[s.d.name] = s
      end
      local rows = Raids.Rows(raid.id, n, names, function(a, b)
        local ea, eb = byName[a], byName[b]
        if ea.d.role ~= eb.d.role then
          return (order[ea.d.role] or 4) < (order[eb.d.role] or 4)
        end
        return a < b
      end)
      local box = self.boxes[n]
      box.count:SetText(#names .. "/5")
      for i, s in ipairs(box.slots) do
        local who = rows[i]
        fillChip(s.chip, who and byName[who] or nil, self)
        s.chip.row = i
        s.empty:SetShown(who == nil)
        if who then
          self.rowOf[who] = i
        end
      end
    end
    for _, b in ipairs({ self.auto, self.place }) do
      b:SetShown(self.canManage)
    end
    if not self.canManage and (self.note:GetText() or "") == "" then
      self.note:SetText("Los mueven el líder de la raid, quien la creó y los oficiales. Tú lo ves tal como está.")
    elseif self.canManage and not self.picked and (self.note:GetText() or "") == "" then
      self.note:SetText("Arrastra cada nombre a su grupo y su fila, o púlsalo y luego pulsa dónde va. Al soltarlo sobre otro, se cambian el sitio.")
    end
  end

  BG:On("BG_STORE_CHANGED", function(name)
    if view:IsShown() and (name == "plans" or name == "signups" or name == "raids") then
      view:Refresh()
    end
  end)
  BG:On("BG_RAID_PLACING", function(state, w, p)
    if not view:IsShown() then
      return
    end
    if state == "moving" then
      view.note:SetText("Colocando a la gente en sus grupos… (" .. (p and p.moved or 0) .. " movidos)")
    elseif state == "done" then
      local missing = p and p.missing or 0
      local stuck = 0
      for _ in pairs(p and p.stuck or {}) do
        stuck = stuck + 1
      end
      view.note:SetText(BG.colorize("Hecho: " .. (p and p.moved or 0) .. " movidos.", C.success)
        .. (missing > 0 and (" " .. missing .. " del plan no están en la banda.") or "") .. (stuck > 0 and (" " .. stuck .. " no se pudieron mover.") or "")
        .. " El orden dentro de cada grupo lo pone el juego.")
    else
      view.note:SetText(BG.colorize(why(w), C.warning))
    end
  end)
  return view
end
