-- La hermandad: every member with live presence, sortable columns, search and an "online only" filter.
local _, BG = ...
local UI, C = BG.UI, BG.color

local ROW_H = 26
local PAD = 24
local COLUMNS = {
  { key = "name", label = "Nombre", width = 214, asc = true },
  { key = "level", label = "Nivel", width = 54, asc = false, justify = "CENTER" },
  { key = "class", label = "Clase", width = 108, asc = true },
  { key = "rank", label = "Rango", width = 118, asc = true },
  { key = "zone", label = "Zona", width = 150, asc = true },
  { key = "seen", label = "Visto", width = 90, asc = true },
  { key = "achievements", label = "Logros", width = 52, asc = false, justify = "RIGHT" },
}

local STATUS = { [1] = "Ausente", [2] = "No molestar" }

local function seenText(m)
  if m.online then
    local label = STATUS[m.status] or (m.mobile and "En la app" or "En línea")
    local c = m.status == 0 and C.success or C.warning
    return BG.colorize(label, c)
  end
  return UI.Ago(m.lastOnlineDays)
end

local function createRow(list)
  local r = CreateFrame("Button", nil, list)
  r.zebra = r:CreateTexture(nil, "BACKGROUND")
  r.zebra:SetAllPoints()
  local hl = r:CreateTexture(nil, "HIGHLIGHT")
  hl:SetColorTexture(C.gold[1], C.gold[2], C.gold[3], 0.08)
  hl:SetAllPoints()
  r.cells = {}
  local x = 0
  for i, col in ipairs(COLUMNS) do
    local fs = UI.Text(r, 12, C.text, { justify = col.justify })
    if i == 1 then
      r.icon = r:CreateTexture(nil, "ARTWORK")
      r.icon:SetSize(18, 18)
      r.icon:SetPoint("LEFT", x + 8, 0)
      r.dot = r:CreateTexture(nil, "OVERLAY")
      r.dot:SetSize(6, 6)
      r.dot:SetPoint("BOTTOMRIGHT", r.icon, "BOTTOMRIGHT", 1, -1)
      r.dot:SetColorTexture(C.success[1], C.success[2], C.success[3], 1)
      fs:SetPoint("LEFT", r.icon, "RIGHT", 8, 0)
      fs:SetWidth(col.width - 62)
      -- BlazonGuild's mark: this member's addon answered our hello (Peers.lua).
      r.badge = r:CreateTexture(nil, "ARTWORK")
      r.badge:SetTexture(BG.media .. "logo.png")
      r.badge:SetSize(14, 14)
      r.badge:SetPoint("LEFT", x + col.width - 22, 0)
    else
      fs:SetPoint("LEFT", x + 6, 0)
      fs:SetWidth(col.width - 12)
    end
    r.cells[col.key] = fs
    x = x + col.width
  end
  r:SetScript("OnEnter", function(self)
    local m = self.member
    if not m then
      return
    end
    GameTooltip:SetOwner(self, "ANCHOR_CURSOR_RIGHT")
    local cc = BG.classColor(m.classFile)
    GameTooltip:AddLine(m.name, cc[1], cc[2], cc[3])
    GameTooltip:AddLine(string.format("Nivel %d %s, %s", m.level, m.className or "", m.rank or ""), 1, 1, 1)
    if m.zone and m.zone ~= "" then
      GameTooltip:AddLine(m.zone, C.text2[1], C.text2[2], C.text2[3])
    end
    if m.note and m.note ~= "" then
      GameTooltip:AddLine("Nota: " .. m.note, C.goldHi[1], C.goldHi[2], C.goldHi[3], true)
    end
    local peer = BG.Peers.Get(m.fullName or m.name)
    if peer then
      GameTooltip:AddLine("Usa BlazonGuild " .. tostring(peer.version), C.gold[1], C.gold[2], C.gold[3])
    end
    if not m.online and m.lastOnlineDays then
      GameTooltip:AddLine("Última conexión " .. UI.Ago(m.lastOnlineDays), C.text3[1], C.text3[2], C.text3[3])
    end
    local main = BG.People.Main(m.fullName or m.name)
    if main and main ~= BG.Names.Short(m.fullName or m.name) then
      GameTooltip:AddLine("Alter de " .. main, C.text2[1], C.text2[2], C.text2[3])
    end
    GameTooltip:AddLine("Clic para ver su ficha", C.text3[1], C.text3[2], C.text3[3])
    BG.ShowTip()
  end)
  r:SetScript("OnLeave", function()
    GameTooltip:Hide()
  end)
  r:SetScript("OnClick", function(self)
    if self.member then
      BG.UI.ShowProfile(self.member.fullName or self.member.name)
    end
  end)
  return r
end

local function updateRow(r, m, index)
  r.member = m
  local even = index % 2 == 0
  r.zebra:SetColorTexture(1, 1, 1, even and 0.025 or 0)
  BG.setClassIcon(r.icon, m.classFile)
  r.icon:SetDesaturated(not m.online)
  r.icon:SetAlpha(m.online and 1 or 0.7)
  r.dot:SetShown(m.online and m.status == 0)
  r.badge:SetShown(BG.Peers.Get(m.fullName or m.name) ~= nil)
  local cc = BG.classColor(m.classFile)
  local name = r.cells.name
  name:SetText(m.name)
  name:SetTextColor(cc[1], cc[2], cc[3], m.online and 1 or 0.8)
  r.cells.level:SetText(m.level)
  r.cells.class:SetText(m.className or "")
  r.cells.class:SetTextColor(C.text2[1], C.text2[2], C.text2[3])
  r.cells.rank:SetText(m.rank or "")
  r.cells.zone:SetText(m.zone or "")
  r.cells.zone:SetTextColor(C.text2[1], C.text2[2], C.text2[3])
  r.cells.seen:SetText(seenText(m))
  r.cells.seen:SetTextColor(C.text3[1], C.text3[2], C.text3[3])
  r.cells.achievements:SetText(m.achievements or "—")
end

BG:RegisterView("roster", {
  Build = function(f, def)
    f.sortKey, f.asc, f.query, f.onlineOnly = "rank", true, "", false

    local heading = UI.Heading(f, "La hermandad")
    heading:SetPoint("TOPLEFT", PAD, -18)
    heading:SetPoint("TOPRIGHT", -PAD, -18)
    f.heading = heading

    local search = CreateFrame("EditBox", nil, f, "SearchBoxTemplate")
    search:SetSize(240, 24)
    search:SetPoint("TOPLEFT", heading, "BOTTOMLEFT", 6, -14)
    search:SetAutoFocus(false)
    search.Instructions:SetText(BG.T("Nombre, rango, clase o zona"))
    search.Instructions:SetWordWrap(false)
    search:HookScript("OnTextChanged", function(self)
      f.query = self:GetText() or ""
      def.Refresh(f, def)
    end)

    -- Who to show: everyone, those online, or those away for a while (Olympus's Members.lua idea).
    f.filterSeg = UI.Segmented(f, {
      { value = "all", label = "Todos" }, { value = "online", label = "Conectados" },
      { value = 7, label = "7+ días fuera" }, { value = 14, label = "14+" }, { value = 30, label = "30+" },
    }, { height = 24, onChange = function(v)
      f.filter = v
      f.onlineOnly = v == "online"
      def.Refresh(f, def)
    end })
    f.filterSeg:SetPoint("LEFT", search, "RIGHT", 14, 0)
    f.filterSeg:SetValue("all", true)

    f.myCard = UI.Button(f, "Mi ficha", { height = 24, width = 90 })
    f.myCard:SetPoint("LEFT", f.filterSeg, "RIGHT", 14, 0)
    f.myCard:SetScript("OnClick", function()
      local me = BG.Names.Me()
      if me then
        BG.UI.ShowProfile(me)
      end
    end)

    f.count = UI.Text(f, 12, C.text3, { justify = "RIGHT" })
    f.count:SetPoint("RIGHT", heading, "RIGHT", 0, 2)

    -- Column headers (click to sort; click again to reverse).
    local head = CreateFrame("Frame", nil, f)
    head:SetPoint("TOPLEFT", search, "BOTTOMLEFT", -6, -14)
    head:SetPoint("RIGHT", -PAD, 0)
    head:SetHeight(26)
    UI.Tile(head, "sunken.png")
    UI.Border(head, C.gold, 0.18)
    f.headers = {}
    local x = 0
    for _, col in ipairs(COLUMNS) do
      local b = CreateFrame("Button", nil, head)
      b:SetPoint("TOPLEFT", x, 0)
      b:SetSize(col.width, 26)
      b.text = UI.Text(b, 11, C.text2, { justify = col.justify })
      if col.key == "name" then
        b.text:SetPoint("LEFT", 34, 0)
      else
        b.text:SetPoint("LEFT", 6, 0)
        b.text:SetWidth(col.width - 12)
      end
      b.arrow = b:CreateTexture(nil, "OVERLAY")
      b.arrow:SetTexture(BG.media .. "sort.png")
      b.arrow:SetSize(10, 10)
      b.arrow:SetPoint("LEFT", b.text, "LEFT", 0, 0)
      b:SetScript("OnClick", function()
        if f.sortKey == col.key then
          f.asc = not f.asc
        else
          f.sortKey, f.asc = col.key, col.asc
        end
        BG.Sound("IG_MAINMENU_OPTION_CHECKBOX_ON")
        def.Refresh(f, def)
      end)
      local hl = b:CreateTexture(nil, "HIGHLIGHT")
      hl:SetColorTexture(1, 1, 1, 0.04)
      hl:SetAllPoints()
      b.col = col
      f.headers[#f.headers + 1] = b
      x = x + col.width
    end

    f.list = UI.List(f, ROW_H, createRow, updateRow)
    f.list:SetPoint("TOPLEFT", head, "BOTTOMLEFT", 0, -2)
    f.list:SetPoint("BOTTOMRIGHT", -PAD + 14, 14)

    f.empty = UI.Text(f, 13, C.text2, { justify = "CENTER", wrap = true })
    f.empty:SetPoint("TOP", head, "BOTTOM", 0, -60)
    f.empty:SetWidth(440)
  end,

  Refresh = function(f)
    local g = BG.Guild
    local members = g.members or {}
    local filter = f.filter or (f.onlineOnly and "online" or "all")
    local items = BG.Guild.Filter(members, f.query, filter == "online")
    if type(filter) == "number" then
      local away = {}
      for _, m in ipairs(items) do
        if not m.online and m.lastOnlineDays and m.lastOnlineDays >= filter then
          away[#away + 1] = m
        end
      end
      items = away
    end
    items = BG.Guild.Sort(items, f.sortKey, f.asc)
    for _, b in ipairs(f.headers) do
      local active = b.col.key == f.sortKey
      b.text:SetText(b.col.label)
      local c = active and C.goldHi or C.text2
      b.text:SetTextColor(c[1], c[2], c[3])
      b.arrow:SetShown(active)
      if active then
        b.arrow:ClearAllPoints()
        local textWidth = math.min(b.text:GetStringWidth(), b.text:GetWidth() > 0 and b.text:GetWidth() or 999)
        local justify = b.col.justify
        if justify == "RIGHT" then
          b.arrow:SetPoint("RIGHT", b.text, "RIGHT", -textWidth - 4, 0)
        elseif justify == "CENTER" then
          b.arrow:SetPoint("LEFT", b.text, "CENTER", textWidth / 2 + 4, 0)
        else
          b.arrow:SetPoint("LEFT", b.text, "LEFT", textWidth + 5, 0)
        end
        b.arrow:SetTexCoord(0, 1, f.asc and 0 or 1, f.asc and 1 or 0)
      end
    end
    f.list:SetItems(items)
    local total, online = #members, g.stats and g.stats.online or 0
    if g.fromCache then
      f.count:SetText(total .. " miembros (última sesión)")
    elseif #items == total then
      f.count:SetText(string.format("%d miembros, %d conectados", total, online))
    else
      f.count:SetText(string.format("%d de %d miembros", #items, total))
    end
    if total == 0 then
      f.empty:SetText(IsInGuild() and "Esperando la lista de la hermandad del juego…" or "No estás en ninguna hermandad.")
    elseif #items == 0 then
      f.empty:SetText(f.onlineOnly and f.query == "" and "Nadie conectado ahora mismo." or "Nadie coincide con la búsqueda.")
    end
    f.empty:SetShown(#items == 0)
  end,
})
