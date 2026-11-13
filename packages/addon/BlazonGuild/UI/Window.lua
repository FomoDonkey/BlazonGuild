-- Main window: same structure as the web (metal sidebar with the guild, sections, header with breadcrumb).
local _, BG = ...
local UI, C = BG.UI, BG.color

local W, H, SIDEBAR, HEADER = 1060, 660, 224, 54

-- The web's sections (apps/web/src/components/shell/nav.ts) plus the ones born in the game: Chat, Tablón,
-- Alianza, Sala de guerra and Mapa. "Grupos" is the web's "Mazmorras": groups for dungeons, raids, PvP, quests or anything else.
BG.nav = {
  { key = "overview", label = "Resumen", icon = "Interface\\Icons\\INV_Misc_Book_11" },
  { key = "roster", label = "La hermandad", icon = "Interface\\Icons\\INV_Misc_GroupNeedMore" },
  { key = "chat", label = "Chat", icon = "Interface\\Icons\\INV_Letter_15" },
  { key = "board", label = "Tablón", icon = "Interface\\Icons\\INV_Misc_Note_06" },
  { key = "alliance", label = "Alianza", icon = "Interface\\Icons\\INV_BannerPVP_02" },
  { key = "war", label = "Sala de guerra", icon = "Interface\\Icons\\Ability_Warrior_BattleShout" },
  { key = "map", label = "Mapa", icon = "Interface\\Icons\\INV_Misc_Map_01" },
  { key = "crafts", label = "Artesanía y botín", icon = "Interface\\Icons\\Trade_BlackSmithing" },
  { key = "treasury", label = "Tesorería", icon = "Interface\\Icons\\INV_Misc_Coin_01" },
  { key = "recruit", label = "Reclutamiento", icon = "Interface\\Icons\\INV_Misc_GroupNeedMore" },
  { key = "armory", label = "Armería", icon = "Interface\\Icons\\INV_Chest_Plate04" },
  { key = "raids", label = "Raids", icon = "Interface\\Icons\\Achievement_Boss_Ragnaros" },
  { key = "dungeons", label = "Grupos", icon = "Interface\\Icons\\INV_Misc_Key_03" },
  { key = "pvp", label = "Se busca", icon = "Interface\\Icons\\Ability_Hunter_MarkedForDeath" },
  { key = "arena", label = "Arena", icon = "Interface\\Icons\\Ability_DualWield" },
  { key = "pve", label = "JcE", icon = "Interface\\Icons\\INV_Misc_Head_Dragon_01" },
  { key = "rankings", label = "Rankings", icon = "Interface\\Icons\\INV_Misc_Ribbon_01" },
  { key = "calendar", label = "Calendario", icon = "Interface\\Icons\\INV_Misc_Note_01" },
  { key = "admin", label = "Administración", icon = "Interface\\Icons\\INV_Misc_Gear_01" },
}

BG.views = {}
function BG:RegisterView(key, def)
  BG.views[key] = def
end

local FACTION_LABEL = { ALLIANCE = "Alianza", HORDE = "Horda" }

local function navButton(parent, item)
  local b = CreateFrame("Button", nil, parent)
  b:SetHeight(32)
  b.active = b:CreateTexture(nil, "BACKGROUND")
  b.active:SetColorTexture(1, 1, 1, 1)
  b.active:SetGradient("HORIZONTAL", CreateColor(C.gold[1], C.gold[2], C.gold[3], 0.2), CreateColor(C.gold[1], C.gold[2], C.gold[3], 0))
  b.active:SetAllPoints()
  b.bar = b:CreateTexture(nil, "ARTWORK")
  b.bar:SetColorTexture(C.gold[1], C.gold[2], C.gold[3], 1)
  b.bar:SetPoint("TOPLEFT")
  b.bar:SetPoint("BOTTOMLEFT")
  b.bar:SetWidth(2)
  local hl = b:CreateTexture(nil, "HIGHLIGHT")
  hl:SetColorTexture(1, 1, 1, 0.05)
  hl:SetAllPoints()
  b.icon = b:CreateTexture(nil, "ARTWORK")
  b.icon:SetTexture(BG.file(item.icon))
  b.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
  b.icon:SetSize(20, 20)
  b.icon:SetPoint("LEFT", 16, 0)
  b.label = UI.Text(b, 13, C.text2)
  b.label:SetPoint("LEFT", b.icon, "RIGHT", 10, 0)
  b.label:SetText(item.label)
  b.badge = UI.Text(b, 10, C.text3, { justify = "RIGHT" })
  b.badge:SetPoint("RIGHT", -14, 0)
  function b:SetActive(on)
    self.active:SetShown(on)
    self.bar:SetShown(on)
    local c = on and C.goldHi or C.text2
    self.label:SetTextColor(c[1], c[2], c[3])
    self.icon:SetDesaturated(false)
    self.icon:SetAlpha(on and 1 or 0.85)
  end
  b:SetActive(false)
  return b
end

-- Gold "X" drawn with two rotated hairlines (no red Blizzard button inside a gold frame).
local function closeButton(parent, onClick)
  local b = CreateFrame("Button", nil, parent)
  b:SetSize(30, 30)
  local lines = {}
  for i, angle in ipairs({ 45, -45 }) do
    local t = b:CreateTexture(nil, "ARTWORK")
    t:SetColorTexture(C.text2[1], C.text2[2], C.text2[3], 1)
    t:SetSize(16, 1.5)
    t:SetPoint("CENTER")
    t:SetRotation(math.rad(angle))
    lines[i] = t
  end
  b:SetScript("OnEnter", function()
    for _, t in ipairs(lines) do
      t:SetColorTexture(C.goldHi[1], C.goldHi[2], C.goldHi[3], 1)
    end
  end)
  b:SetScript("OnLeave", function()
    for _, t in ipairs(lines) do
      t:SetColorTexture(C.text2[1], C.text2[2], C.text2[3], 1)
    end
  end)
  b:SetScript("OnClick", onClick)
  return b
end

function BG:CreateWindow()
  local f = CreateFrame("Frame", "BlazonGuildFrame", UIParent)
  f:SetSize(W, H)
  f:SetFrameStrata("HIGH")
  f:SetToplevel(true)
  f:SetClampedToScreen(true)
  f:EnableMouse(true)
  f:SetMovable(true)
  f:SetScale(BG.db.settings.scale or 1)
  local p = BG.db.settings.point
  if p then
    f:SetPoint(p[1], UIParent, p[2], p[3], p[4])
  else
    f:SetPoint("CENTER")
  end
  f:Hide()
  tinsert(UISpecialFrames, "BlazonGuildFrame") -- Escape closes it, like any game window

  local shadow = f:CreateTexture(nil, "BACKGROUND", nil, -8)
  shadow:SetColorTexture(0, 0, 0, 0.6)
  shadow:SetPoint("TOPLEFT", -5, 5)
  shadow:SetPoint("BOTTOMRIGHT", 5, -5)
  UI.Tile(f, "canvas.png", "BACKGROUND", -6)

  -- Sidebar ------------------------------------------------------------------------------------
  local side = CreateFrame("Frame", nil, f)
  side:SetPoint("TOPLEFT", 1, -1)
  side:SetPoint("BOTTOMLEFT", 1, 1)
  side:SetWidth(SIDEBAR)
  UI.Tile(side, "sunken.png")
  UI.Shade(side, 0.05, 0.22)
  local rail = side:CreateTexture(nil, "ARTWORK")
  rail:SetWidth(1)
  rail:SetPoint("TOPRIGHT")
  rail:SetPoint("BOTTOMRIGHT")
  rail:SetColorTexture(1, 1, 1, 1)
  rail:SetGradient("VERTICAL", CreateColor(C.gold[1], C.gold[2], C.gold[3], 0.08), CreateColor(C.gold[1], C.gold[2], C.gold[3], 0.6))

  local logo = side:CreateTexture(nil, "ARTWORK")
  logo:SetTexture(BG.media .. "logo.png")
  logo:SetSize(30, 30)
  logo:SetPoint("TOPLEFT", 18, -18)
  local word = UI.Text(side, 19, C.goldTitle, { font = BG.font.display })
  word:SetPoint("LEFT", logo, "RIGHT", 8, 0)
  word:SetText("BlazonGuild")

  local card = UI.Plate(side, { tile = "metal.png", rail = 0.14 })
  card:SetPoint("TOPLEFT", 12, -62)
  card:SetPoint("TOPRIGHT", -12, -62)
  card:SetHeight(58)
  card.crest = UI.Medallion(card, 40)
  card.crest:SetPoint("LEFT", 9, 0)
  card.name = UI.Text(card, 13, C.text, { font = BG.font.display })
  card.name:SetPoint("TOPLEFT", card.crest, "TOPRIGHT", 9, -3)
  card.name:SetPoint("RIGHT", -8, 0)
  card.sub = UI.Text(card, 11, C.text3)
  card.sub:SetPoint("TOPLEFT", card.name, "BOTTOMLEFT", 0, -4)
  card.sub:SetPoint("RIGHT", -8, 0)
  f.card = card

  f.navButtons = {}
  local y = -134
  local step = math.min(32, math.floor((H - 134 - 66) / #BG.nav)) -- (every section fits, clear of the footer)
  for _, item in ipairs(BG.nav) do
    local b = navButton(side, item)
    b:SetHeight(step)
    b:SetPoint("TOPLEFT", 1, y)
    b:SetPoint("TOPRIGHT", -1, y)
    b:SetScript("OnClick", function()
      BG:ShowView(item.key)
      BG.Sound("IG_MAINMENU_OPTION")
    end)
    f.navButtons[item.key] = b
    y = y - step
  end

  local foot = UI.Text(side, 10, C.text3)
  foot:SetPoint("BOTTOMLEFT", 16, 30)
  foot:SetPoint("RIGHT", -12, 0)
  foot:SetText("BlazonGuild " .. BG.version)
  local foot2 = UI.Text(side, 10, C.text3)
  foot2:SetPoint("TOPLEFT", foot, "BOTTOMLEFT", 0, -3)
  foot2:SetPoint("RIGHT", -12, 0)
  foot2:SetText("/bg abre y cierra esta ventana")

  -- Header -------------------------------------------------------------------------------------
  local header = CreateFrame("Frame", nil, f)
  header:SetPoint("TOPLEFT", side, "TOPRIGHT", 0, 0)
  header:SetPoint("TOPRIGHT", -1, -1)
  header:SetHeight(HEADER)
  header:EnableMouse(true)
  header:RegisterForDrag("LeftButton")
  header:SetScript("OnDragStart", function()
    f:StartMoving()
  end)
  header:SetScript("OnDragStop", function()
    f:StopMovingOrSizing()
    local point, _, rel, x, yy = f:GetPoint()
    BG.db.settings.point = { point, rel, x, yy }
  end)
  local hrule = header:CreateTexture(nil, "ARTWORK")
  hrule:SetHeight(1)
  hrule:SetPoint("BOTTOMLEFT")
  hrule:SetPoint("BOTTOMRIGHT")
  hrule:SetColorTexture(1, 1, 1, 1)
  hrule:SetGradient("HORIZONTAL", CreateColor(C.gold[1], C.gold[2], C.gold[3], 0.55), CreateColor(C.gold[1], C.gold[2], C.gold[3], 0.1))
  f.crumb = UI.Text(header, 13, C.text2)
  f.crumb:SetPoint("LEFT", 22, 0)
  f.status = UI.Text(header, 11, C.text3, { justify = "RIGHT" })
  f.status:SetPoint("RIGHT", -118, 0)
  -- The status doubles as the way into the privacy page while nothing is shared.
  local statusHit = CreateFrame("Button", nil, header)
  statusHit:SetPoint("RIGHT", -114, 0)
  statusHit:SetSize(340, 30)
  statusHit:SetScript("OnClick", function()
    BG.Consent.Open()
  end)
  statusHit:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_BOTTOMLEFT")
    GameTooltip:SetText("Conexión con tu hermandad", C.gold[1], C.gold[2], C.gold[3])
    GameTooltip:AddLine("Pulsa para ver qué compartes. /bg estado y /bg prueba dan más detalle.", 1, 1, 1, true)
    BG.ShowTip()
  end)
  statusHit:SetScript("OnLeave", function()
    GameTooltip:Hide()
  end)
  local close = closeButton(header, function()
    f:Hide()
  end)
  close:SetPoint("RIGHT", -14, 0)
  -- Minimize: the window leaves a small bar (UI/Minimize.lua), to see the world or the map behind it.
  local mini = CreateFrame("Button", nil, header)
  mini:SetSize(30, 30)
  mini:SetPoint("RIGHT", close, "LEFT", -2, 0)
  local miniLine = mini:CreateTexture(nil, "ARTWORK")
  miniLine:SetSize(14, 1.5)
  miniLine:SetPoint("CENTER", 0, -4)
  miniLine:SetColorTexture(C.text2[1], C.text2[2], C.text2[3], 1)
  mini:SetScript("OnEnter", function(self)
    miniLine:SetColorTexture(C.goldHi[1], C.goldHi[2], C.goldHi[3], 1)
    GameTooltip:SetOwner(self, "ANCHOR_BOTTOMLEFT")
    GameTooltip:SetText("Minimizar", C.gold[1], C.gold[2], C.gold[3])
    GameTooltip:AddLine("Deja una barra pequeña para ver el juego. Pulsa la barra para volver.", 1, 1, 1, true)
    BG.ShowTip()
  end)
  mini:SetScript("OnLeave", function()
    miniLine:SetColorTexture(C.text2[1], C.text2[2], C.text2[3], 1)
    GameTooltip:Hide()
  end)
  mini:SetScript("OnClick", function()
    BG:Minimize(false)
  end)
  f.minimize = mini
  -- "?": how this section works (UI/Guide.lua), for the sections that have a guide.
  local help = CreateFrame("Button", nil, header)
  help:SetSize(30, 30)
  help:SetPoint("RIGHT", mini, "LEFT", -2, 0)
  help.text = UI.Text(help, 16, C.text2, { font = BG.font.display, justify = "CENTER" })
  help.text:SetPoint("CENTER", 0, 0)
  help.text:SetText("?")
  help:SetScript("OnEnter", function(self)
    help.text:SetTextColor(C.goldHi[1], C.goldHi[2], C.goldHi[3])
    GameTooltip:SetOwner(self, "ANCHOR_BOTTOMLEFT")
    GameTooltip:SetText("Cómo funciona", C.gold[1], C.gold[2], C.gold[3])
    GameTooltip:AddLine("Una guía corta de esta sección, paso a paso.", 1, 1, 1, true)
    BG.ShowTip()
  end)
  help:SetScript("OnLeave", function()
    help.text:SetTextColor(C.text2[1], C.text2[2], C.text2[3])
    GameTooltip:Hide()
  end)
  help:SetScript("OnClick", function()
    BG:ShowGuide(BG.db.settings.lastView)
  end)
  help:Hide()
  f.help = help

  -- Content ------------------------------------------------------------------------------------
  local content = CreateFrame("Frame", nil, f)
  content:SetPoint("TOPLEFT", header, "BOTTOMLEFT", 0, 0)
  content:SetPoint("BOTTOMRIGHT", -1, 1)
  f.content = content
  f.viewFrames = {}

  -- Chrome on top of everything: black edge, gold rail and filigree corners (as the web's OrnateFrame).
  local chrome = CreateFrame("Frame", nil, f)
  chrome:SetAllPoints()
  chrome:SetFrameLevel(f:GetFrameLevel() + 40)
  chrome:EnableMouse(false)
  UI.Border(chrome, { 0, 0, 0 }, 0.95, 0, "OVERLAY")
  UI.Border(chrome, C.gold, 0.32, 5, "OVERLAY")
  UI.Corners(chrome, 46, "OVERLAY")

  f:SetScript("OnShow", function()
    BG.Sound("IG_CHARACTER_INFO_OPEN")
    BG.Guild.Request()
    BG:RefreshChrome()
    f.ticker = C_Timer.NewTicker(5, function()
      BG:RefreshStatus()
    end)
    f.rosterTicker = C_Timer.NewTicker(30, BG.Guild.Request)
  end)
  f:SetScript("OnHide", function()
    BG.Sound("IG_CHARACTER_INFO_CLOSE")
    if f.ticker then
      f.ticker:Cancel()
    end
    if f.rosterTicker then
      f.rosterTicker:Cancel()
    end
  end)

  BG.window = f
  return f
end

function BG:RefreshStatus()
  local f = BG.window
  if not f then
    return
  end
  local g = BG.Guild
  if not g.info then
    f.status:SetText(IsInGuild() and "Esperando la lista de la hermandad…" or "")
  elseif g.fromCache then
    f.status:SetText("Datos de tu última sesión, actualizando…")
  elseif not BG.Consent.Accepted() then
    f.status:SetText(BG.colorize("Sin compartir con tu hermandad: pulsa aquí", C.warning))
  else
    local secs = time() - (g.scannedAt or time())
    local live = secs < 10 and "En vivo" or string.format("En vivo, hace %d s", secs)
    local n = #BG.Peers.Active()
    f.status:SetText(live .. ", " .. (n == 1 and "1 con BlazonGuild" or (n .. " con BlazonGuild")))
  end
end

function BG:RefreshChrome()
  local f = BG.window
  if not f then
    return
  end
  local info = BG.Guild.info
  if info then
    f.card.name:SetText(info.name)
    f.card.crest:SetName(info.name)
    local fc = info.faction == "HORDE" and C.horde or C.alliance
    local rank = BG.Guild.me and BG.Guild.me.rank or info.myRank
    f.card.sub:SetText(BG.colorize(FACTION_LABEL[info.faction] or "", fc) .. (rank and (", " .. rank) or ""))
  else
    f.card.name:SetText(IsInGuild() and "Cargando…" or "Sin hermandad")
    f.card.crest:SetName("?")
    f.card.sub:SetText(IsInGuild() and "" or "Únete a una para empezar")
  end
  local current = BG.db.settings.lastView
  local label = ""
  for _, item in ipairs(BG.nav) do
    if item.key == current then
      label = item.label
    end
    local view = BG.views[item.key]
    local badge = view and view.upcoming and "Pronto" or ""
    if item.key == "chat" and BG.Chat and BG.Chat.TotalUnread() > 0 then
      badge = BG.colorize(tostring(BG.Chat.TotalUnread()), C.goldTitle)
    end
    f.navButtons[item.key].badge:SetText(badge)
  end
  f.crumb:SetText((info and (BG.colorize(info.name, C.text2) .. BG.colorize("  ›  ", C.text3)) or "") .. BG.colorize(label, C.text))
  BG:RefreshStatus()
end

function BG:ShowView(key)
  local f = BG.window or BG:CreateWindow()
  if BG.UI.HideProfile then
    BG.UI.HideProfile() -- a member's card covers the sections; choosing one closes it
  end
  local def = BG.views[key] or BG.views.overview
  key = BG.views[key] and key or "overview"
  BG.db.settings.lastView = key
  for k, b in pairs(f.navButtons) do
    b:SetActive(k == key)
  end
  for k, vf in pairs(f.viewFrames) do
    vf:SetShown(k == key)
  end
  local vf = f.viewFrames[key]
  if not vf then
    vf = CreateFrame("Frame", nil, f.content)
    vf:SetAllPoints()
    local ok, err = pcall(def.Build, vf, def)
    if not ok then
      BG:RecordError("build:" .. key, err)
    end
    f.viewFrames[key] = vf
  end
  vf:Show()
  if def.Refresh then
    local ok, err = pcall(def.Refresh, vf, def)
    if not ok then
      BG:RecordError("refresh:" .. key, err)
    end
  end
  if f.help then
    f.help:SetShown(BG.HasGuide ~= nil and BG:HasGuide(key))
  end
  if BG.MaybeGuide then
    BG:MaybeGuide(key)
  end
  BG:RefreshChrome()
end

function BG:ToggleWindow()
  if BG.IsMinimized and BG:IsMinimized() then
    return BG:Restore()
  end
  local f = BG.window or BG:CreateWindow()
  if BG.HookWorldMap then
    BG:HookWorldMap()
  end
  if f:IsShown() then
    f:Hide()
  else
    f:Show()
    -- (with no guild, the one section that helps is finding one)
    BG:ShowView((not IsInGuild() and BG.views.recruit) and "recruit" or BG.db.settings.lastView)
    BG.Consent.MaybeAsk()
  end
end

-- Re-renders one view (or the visible one) if it is on screen; safe to call from any event.
function BG:RefreshView(key)
  local f = BG.window
  if not (f and f:IsShown()) then
    return
  end
  key = key or BG.db.settings.lastView
  if key ~= BG.db.settings.lastView then
    return
  end
  local def, vf = BG.views[key], f.viewFrames[key]
  if def and vf and def.Refresh then
    local ok, err = pcall(def.Refresh, vf, def)
    if not ok then
      BG:RecordError("refresh:" .. key, err)
    end
  end
  BG:RefreshChrome()
end

BG:On("BG_ROSTER_UPDATED", function()
  BG:RefreshView()
end)
BG:On("BG_PEERS_CHANGED", function()
  BG:RefreshView()
end)
BG:On("BG_CONSENT_CHANGED", function()
  BG:RefreshStatus()
end)
