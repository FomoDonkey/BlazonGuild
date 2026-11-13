-- Resumen: cinematic banner with official art, stat plates and the guild at a glance (live roster data).
local _, BG = ...
local UI, C = BG.UI, BG.color

local FACTION_LABEL = { ALLIANCE = "Alianza", HORDE = "Horda" }
local ROW = 22

local function hero(parent)
  local h = CreateFrame("Frame", nil, parent)
  h:SetPoint("TOPLEFT")
  h:SetPoint("TOPRIGHT")
  h:SetHeight(168)
  h:SetClipsChildren(true)
  h.art = h:CreateTexture(nil, "BACKGROUND")
  h.art:SetAllPoints()
  -- Crop the 4:3 loading-screen art to the banner's shape so it never stretches.
  h:SetScript("OnSizeChanged", function(self, w, hh)
    if w and hh and w > 0 then
      local visible = math.min(1, (4 / 3) / (w / hh))
      local top = 0.36 - visible / 2
      self.art:SetTexCoord(0, 1, math.max(0, top), math.max(0, top) + visible)
    end
  end)
  local fadeLeft = h:CreateTexture(nil, "BORDER")
  fadeLeft:SetColorTexture(1, 1, 1, 1)
  fadeLeft:SetGradient("HORIZONTAL", CreateColor(0.03, 0.04, 0.05, 0.92), CreateColor(0.03, 0.04, 0.05, 0.15))
  fadeLeft:SetAllPoints()
  local fadeBottom = h:CreateTexture(nil, "BORDER", nil, 1)
  fadeBottom:SetColorTexture(1, 1, 1, 1)
  fadeBottom:SetGradient("VERTICAL", CreateColor(0.04, 0.05, 0.07, 1), CreateColor(0.04, 0.05, 0.07, 0))
  fadeBottom:SetPoint("BOTTOMLEFT")
  fadeBottom:SetPoint("BOTTOMRIGHT")
  fadeBottom:SetHeight(70)
  local rule = h:CreateTexture(nil, "ARTWORK")
  rule:SetColorTexture(1, 1, 1, 1)
  rule:SetGradient("HORIZONTAL", CreateColor(C.gold[1], C.gold[2], C.gold[3], 0.6), CreateColor(C.gold[1], C.gold[2], C.gold[3], 0))
  rule:SetHeight(1)
  rule:SetPoint("BOTTOMLEFT")
  rule:SetPoint("BOTTOMRIGHT")

  h.crest = UI.Medallion(h, 84)
  h.crest:SetPoint("LEFT", 30, -4)
  h.title = UI.Text(h, 30, C.goldTitle, { font = BG.font.display })
  h.title:SetPoint("TOPLEFT", h.crest, "TOPRIGHT", 18, -10)
  h.sub = UI.Text(h, 13, C.text)
  h.sub:SetPoint("TOPLEFT", h.title, "BOTTOMLEFT", 0, -8)
  h.motd = UI.Text(h, 12, C.text2, { wrap = true })
  h.motd:SetPoint("TOPLEFT", h.sub, "BOTTOMLEFT", 0, -8)
  h.motd:SetPoint("RIGHT", -40, 0)
  h.motd:SetMaxLines(2)
  return h
end

local function column(parent, title)
  local col = CreateFrame("Frame", nil, parent)
  col.heading = UI.Heading(col, title)
  col.heading:SetPoint("TOPLEFT")
  col.heading:SetPoint("TOPRIGHT")
  col.rows = {}
  return col
end

local function classRow(col, i)
  local r = col.rows[i]
  if r then
    return r
  end
  r = CreateFrame("Frame", nil, col)
  r:SetHeight(ROW)
  r:SetPoint("TOPLEFT", 0, -38 - (i - 1) * ROW)
  r:SetPoint("RIGHT")
  r.icon = r:CreateTexture(nil, "ARTWORK")
  r.icon:SetSize(16, 16)
  r.icon:SetPoint("LEFT")
  r.name = UI.Text(r, 12, C.text)
  r.name:SetPoint("LEFT", r.icon, "RIGHT", 7, 0)
  r.name:SetWidth(84)
  r.count = UI.Text(r, 12, C.text, { justify = "RIGHT" })
  r.count:SetPoint("RIGHT")
  r.count:SetWidth(30)
  r.bar = UI.Bar(r)
  r.bar:SetPoint("LEFT", r.name, "RIGHT", 6, 0)
  r.bar:SetPoint("RIGHT", r.count, "LEFT", -8, 0)
  col.rows[i] = r
  return r
end

local function textRow(col, i)
  local r = col.rows[i]
  if r then
    return r
  end
  r = CreateFrame("Frame", nil, col)
  r:SetHeight(ROW)
  r:SetPoint("TOPLEFT", 0, -38 - (i - 1) * ROW)
  r:SetPoint("RIGHT")
  r.icon = r:CreateTexture(nil, "ARTWORK")
  r.icon:SetSize(16, 16)
  r.icon:SetPoint("LEFT")
  r.left = UI.Text(r, 12, C.text)
  r.left:SetPoint("LEFT", r.icon, "RIGHT", 7, 0)
  r.right = UI.Text(r, 11, C.text3, { justify = "RIGHT" })
  r.right:SetPoint("RIGHT")
  r.left:SetPoint("RIGHT", r.right, "LEFT", -6, 0)
  if col.splitNames then
    r.left:SetPoint("RIGHT", r, "CENTER", 14, 0)
    r.right:SetPoint("LEFT", r, "CENTER", 20, 0)
  end
  local line = r:CreateTexture(nil, "BACKGROUND")
  line:SetColorTexture(C.line[1], C.line[2], C.line[3], 0.6)
  line:SetHeight(1)
  line:SetPoint("BOTTOMLEFT")
  line:SetPoint("BOTTOMRIGHT")
  col.rows[i] = r
  return r
end

local function hideFrom(col, n)
  for i = n, #col.rows do
    col.rows[i]:Hide()
  end
end

BG:RegisterView("overview", {
  Build = function(f)
    f.hero = hero(f)
    f.plates = {}
    for i = 1, 4 do
      local p = UI.StatPlate(f)
      p:SetHeight(80)
      f.plates[i] = p
    end
    f:SetScript("OnSizeChanged", function(self, w)
      local gap, pad = 12, 24
      local pw = (w - pad * 2 - gap * 3) / 4
      for i, p in ipairs(self.plates) do
        p:ClearAllPoints()
        p:SetPoint("TOPLEFT", self.hero, "BOTTOMLEFT", pad + (i - 1) * (pw + gap), -16)
        p:SetWidth(pw)
      end
      local cw = (w - pad * 2 - 28 * 2) / 3
      for i, col in ipairs({ self.classes, self.ranks, self.online }) do
        col:ClearAllPoints()
        col:SetPoint("TOPLEFT", self.hero, "BOTTOMLEFT", pad + (i - 1) * (cw + 28), -120)
        col:SetPoint("BOTTOM", 0, 16)
        col:SetWidth(cw)
      end
      if self.built and self:IsShown() then
        BG:RefreshView("overview")
      end
    end)
    f.built = true
    f.classes = column(f, "Clases")
    f.ranks = column(f, "Rangos")
    f.online = column(f, "Conectados ahora")
    f.online.splitNames = true
    f.empty = UI.Text(f, 14, C.text2, { justify = "CENTER", wrap = true })
    f.empty:SetPoint("CENTER", 0, -40)
    f.empty:SetWidth(460)
  end,

  Refresh = function(f)
    local g = BG.Guild
    local info, s = g.info, g.stats
    local inGuild = info ~= nil and s ~= nil
    f.empty:SetShown(not inGuild)
    for _, w in ipairs({ f.plates[1], f.plates[2], f.plates[3], f.plates[4], f.classes, f.ranks, f.online }) do
      w:SetShown(inGuild)
    end
    f.hero.art:SetTexture(BG.file(BG.art[info and info.faction or "ALLIANCE"] or BG.art.ALLIANCE, BG.art.RAID))
    if not inGuild then
      f.hero.crest:SetName("?")
      f.hero.title:SetText(IsInGuild() and "Cargando tu hermandad…" or "Sin hermandad")
      f.hero.sub:SetText("")
      f.hero.motd:SetText("")
      f.empty:SetText(IsInGuild() and "El juego todavía no ha enviado la lista de miembros. Aparecerá en unos segundos."
        or "Cuando te unas a una hermandad, aquí verás a sus miembros, raids, rankings y todo lo demás, en vivo.")
      return
    end

    local fc = info.faction == "HORDE" and C.horde or C.alliance
    f.hero.crest:SetName(info.name)
    f.hero.title:SetText(info.name)
    local live = g.fromCache and "datos de tu última sesión" or (s.online == 1 and "1 conectado ahora" or (s.online .. " conectados ahora"))
    local peers = BG.Consent.Accepted() and #BG.Peers.Active() or 0
    local addon = peers > 0 and (", " .. peers .. " con BlazonGuild") or ""
    f.hero.sub:SetText(BG.colorize(FACTION_LABEL[info.faction] or "", fc) .. BG.colorize(", " .. s.total .. " miembros, " .. live .. addon, C.text))
    f.hero.motd:SetText(info.motd and info.motd ~= "" and ("Mensaje del día: " .. info.motd) or "")

    local max = BG.Guild.MaxLevel()
    f.plates[1]:Set(s.total, "Miembros", "en la hermandad")
    f.plates[2]:Set(g.fromCache and "—" or s.online, "Conectados", g.fromCache and "esperando al juego" or "ahora mismo")
    local avg = string.format("%.1f", s.avgLevel):gsub("%.", ",") -- gsub's second result must not leak into Set()
    f.plates[3]:Set(avg, "Nivel medio", "de " .. max)
    f.plates[4]:Set(s.atMax, "Nivel " .. max, s.atMax == 1 and "listo para banda" or "listos para banda")

    local top = s.byClass[1] and s.byClass[1].count or 1
    for i, c in ipairs(s.byClass) do
      local r = classRow(f.classes, i)
      BG.setClassIcon(r.icon, c.classFile)
      local cc = BG.classColor(c.classFile)
      r.name:SetText((LOCALIZED_CLASS_NAMES_MALE and LOCALIZED_CLASS_NAMES_MALE[c.classFile]) or c.className or "?")
      r.name:SetTextColor(cc[1], cc[2], cc[3])
      r.count:SetText(c.count)
      r.bar:Set(c.count / top, cc)
      r:Show()
    end
    hideFrom(f.classes, #s.byClass + 1)

    local n = 0
    for idx = 0, 9 do
      local name = info.ranks[idx]
      if name then
        n = n + 1
        local r = textRow(f.ranks, n)
        r.icon:SetTexture(BG.media .. "lozenge.png")
        r.icon:SetTexCoord(0, 1, 0, 1)
        r.icon:SetSize(10, 10)
        r.left:SetText(name .. (idx == info.myRankIndex and BG.colorize("  (tú)", C.gold) or ""))
        r.left:SetTextColor(C.text[1], C.text[2], C.text[3])
        r.right:SetText(s.byRank[idx] or 0)
        r:Show()
      end
    end
    hideFrom(f.ranks, n + 1)

    local colHeight = f.online:GetHeight() or 0
    if colHeight < 100 then
      colHeight = (f:GetHeight() or 0) - 168 - 136
    end
    local maxRows = math.max(4, math.floor((colHeight - 60) / ROW))
    local list = s.onlineList
    local shown = math.min(#list, maxRows)
    for i = 1, shown do
      local m = list[i]
      local r = textRow(f.online, i)
      BG.setClassIcon(r.icon, m.classFile)
      r.icon:SetSize(16, 16)
      local cc = BG.classColor(m.classFile)
      r.left:SetText(m.name)
      r.left:SetTextColor(cc[1], cc[2], cc[3])
      r.right:SetText(m.level .. (m.zone and m.zone ~= "" and (", " .. m.zone) or ""))
      r:Show()
    end
    hideFrom(f.online, shown + 1)
    if not f.online.more then
      f.online.more = UI.Text(f.online, 11, C.text3)
    end
    f.online.more:ClearAllPoints()
    f.online.more:SetPoint("TOPLEFT", 0, -38 - shown * ROW - 6)
    if g.fromCache then
      f.online.more:SetText("Se verá en cuanto el juego envíe la lista.")
    elseif #list == 0 then
      f.online.more:SetText("Nadie más conectado ahora mismo.")
    elseif #list > shown then
      f.online.more:SetText("y " .. (#list - shown) .. " más en La hermandad")
    else
      f.online.more:SetText("")
    end
  end,
})
