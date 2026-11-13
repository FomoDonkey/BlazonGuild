-- Rankings (the menu's Rankings slot), two tabs.
-- «Honores»: left, one card per honour (Honors.lua) with who holds it now; click one to see its ranking. Right: the
-- first ten of that honour, the first three with their medal colour, and how it is counted. Below: the honours of the
-- player, and the switch of the marks (crest over the members' names, golden for the honoured, in the chat too).
-- «Hermandades» (0.20.0, GuildRanks.lua): left, each number guilds are compared by; right, the guilds known of our
-- faction in that number, ours marked; click one to compare it with ours. Below: our places, and the master's switch.
local _, BG = ...
local UI, C = BG.UI, BG.color
local H, Names = BG.Honors, BG.Names

local PAD = 24
local GAP = 16
local LEFT_W = 260
local ROW_H = 24
local MEDAL = { { 1, 0.82, 0.3 }, { 0.82, 0.84, 0.88 }, { 0.8, 0.52, 0.3 } }
local GR = BG.GuildRanks
local TABS = { { value = "honors", label = "Honores" }, { value = "guilds", label = "Hermandades" } }

local function categoryCard(f, i)
  local c = UI.Card(f.cats)
  c:SetHeight(56)
  c:SetPoint("TOPLEFT", 0, -(i - 1) * 62)
  c:SetPoint("TOPRIGHT", 0, -(i - 1) * 62)
  c:SetScript("OnClick", function(self)
    f.selected = self.cat and self.cat.key or f.selected
    BG.Sound("U_CHAT_SCROLL_BUTTON")
    BG:RefreshView("rankings")
  end)
  c:SetScript("OnEnter", function(self)
    if not (GameTooltip and self.cat) then
      return
    end
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetText(self.cat.title, C.gold[1], C.gold[2], C.gold[3], 1, true)
    GameTooltip:AddLine(self.cat.how, 1, 1, 1, true)
    GameTooltip:AddLine("Pulsa para ver los " .. H.TOP .. " primeros.", 0.6, 0.6, 0.6, true)
    BG.ShowTip()
  end)
  return c
end

local function rankRow(parent, i)
  local r = {}
  r.pos = UI.Text(parent, 13, MEDAL[i] or C.text3, { font = BG.font.display, justify = "RIGHT" })
  r.pos:SetWidth(26)
  r.pos:SetText(i .. ".")
  r.value = UI.Text(parent, 12, C.text2, { justify = "RIGHT" })
  r.name = UI.Text(parent, 13, C.text)
  r.line = parent:CreateTexture(nil, "BORDER")
  r.line:SetColorTexture(C.line[1], C.line[2], C.line[3], 0.35)
  r.line:SetHeight(1)
  return r
end

BG:RegisterView("rankings", {
  Build = function(f)
    f.hero = UI.Hero(f, 108)
    f.hero:SetPoint("TOPLEFT")
    f.hero:SetPoint("TOPRIGHT")
    f.selected = H.DEFS[1].key

    f.cats = CreateFrame("Frame", nil, f)
    f.cats:SetPoint("TOPLEFT", f.hero, "BOTTOMLEFT", PAD, -16)
    f.cats:SetWidth(LEFT_W)
    f.cats:SetHeight(#H.DEFS * 62)
    f.cards = {}
    for i = 1, #H.DEFS do
      f.cards[i] = categoryCard(f, i)
    end

    local board = UI.Plate(f, { corners = 18, rail = 0.24 })
    board:SetPoint("TOPLEFT", f.cats, "TOPRIGHT", GAP, 0)
    board:SetPoint("RIGHT", -PAD, 0)
    board:SetPoint("BOTTOM", 0, 18 + 58 + 14)
    f.board = board
    board.head = UI.Heading(board, "")
    board.head:SetPoint("TOPLEFT", 16, -8)
    board.head:SetPoint("TOPRIGHT", -16, -8)
    f.how = UI.Text(board, 12, C.text3, { wrap = true })
    f.how:SetPoint("TOPLEFT", board.head, "BOTTOMLEFT", 0, -6)
    f.how:SetPoint("RIGHT", -16, 0)
    f.rows = {}
    for i = 1, H.TOP do
      local r = rankRow(board, i)
      local y = -8 - (i - 1) * ROW_H
      r.pos:SetPoint("TOPLEFT", f.how, "BOTTOMLEFT", 0, y)
      r.value:SetPoint("TOPRIGHT", f.how, "BOTTOMRIGHT", 0, y)
      r.name:SetPoint("LEFT", r.pos, "RIGHT", 10, 0)
      r.name:SetPoint("RIGHT", r.value, "LEFT", -10, 0)
      r.line:SetPoint("TOPLEFT", r.pos, "BOTTOMLEFT", 0, -5)
      r.line:SetPoint("RIGHT", f.how, "RIGHT", 0, 0)
      f.rows[i] = r
    end
    f.empty = UI.Text(board, 12, C.text3, { wrap = true })
    f.empty:SetPoint("TOPLEFT", f.how, "BOTTOMLEFT", 0, -12)
    f.empty:SetPoint("RIGHT", -16, 0)

    f.foot = UI.Plate(f, { corners = 14, rail = 0.2 })
    f.foot:SetPoint("BOTTOMLEFT", PAD, 18)
    f.foot:SetPoint("BOTTOMRIGHT", -PAD, 18)
    f.foot:SetHeight(58)
    f.marks = UI.Button(f.foot, "", { height = 26, width = 230 })
    f.marks:SetPoint("RIGHT", -14, 0)
    f.marks:SetScript("OnClick", function()
      BG.Marks.SetEnabled(not BG.Marks.Enabled())
      BG:RefreshView("rankings")
    end)
    f.mine = UI.Text(f.foot, 12, C.text, { wrap = true })
    f.mine:SetPoint("LEFT", 16, 0)
    f.mine:SetPoint("RIGHT", f.marks, "LEFT", -14, 0)
    f.mine:SetMaxLines(2)

    f.tab = "honors"
    f.tabs = UI.Segmented(f.hero, TABS, { itemWidth = 110, height = 24, onChange = function(v)
      f.tab = v
      BG:RefreshView("rankings")
    end })
    f.tabs:SetPoint("BOTTOMRIGHT", -PAD, 12)
    f.hero.sub:SetPoint("RIGHT", f.tabs, "LEFT", -16, 0) -- (the text never runs under the tabs)
    f.hero.title:SetPoint("RIGHT", f.tabs, "LEFT", -16, 0)

    -- Guilds
    f.gstat = GR.STATS[1].key
    f.gcats = UI.List(f, 44, function(list)
      local c = UI.Card(list)
      c:SetScript("OnClick", function(self)
        if self.item then
          f.gstat = self.item.key
          BG.Sound("U_CHAT_SCROLL_BUTTON")
          BG:RefreshView("rankings")
        end
      end)
      return c
    end, function(c, st)
      c.item = st
      c.key = "gr:" .. st.key
      c:SetHeight(40)
      c.icon:SetTexture("Interface\\Icons\\INV_Misc_Ribbon_01")
      c.title:SetText(st.title)
      local place = f.places and f.places[st.key]
      c.sub:SetText(place and ("Vuestro puesto: " .. place .. "º") or "")
      c.right:SetText("")
      c.right2:SetText("")
      local on = st.key == f.gstat
      c:SetSelected(on)
      c.accent:SetShown(on)
    end)
    f.gcats:SetPoint("TOPLEFT", f.hero, "BOTTOMLEFT", PAD, -16)
    f.gcats:SetPoint("BOTTOM", 0, 18 + 58 + 14)
    f.gcats:SetWidth(LEFT_W)
    local gboard = UI.Plate(f, { corners = 18, rail = 0.24 })
    gboard:SetPoint("TOPLEFT", f.gcats, "TOPRIGHT", GAP, 0)
    gboard:SetPoint("RIGHT", -PAD, 0)
    gboard:SetPoint("BOTTOM", 0, 18 + 58 + 14)
    f.gboard = gboard
    gboard.head = UI.Heading(gboard, "")
    gboard.head:SetPoint("TOPLEFT", 16, -8)
    gboard.head:SetPoint("TOPRIGHT", -16, -8)
    f.ghow = UI.Text(gboard, 12, C.text3, { wrap = true })
    f.ghow:SetPoint("TOPLEFT", gboard.head, "BOTTOMLEFT", 0, -6)
    f.ghow:SetPoint("RIGHT", -16, 0)
    f.ghow:SetMaxLines(2)
    f.grows = {}
    for i = 1, H.TOP do
      -- each row is a button (click: compare with ours) that holds its own texts
      local hit = CreateFrame("Button", nil, gboard)
      hit:SetHeight(ROW_H)
      hit:SetPoint("TOPLEFT", f.ghow, "BOTTOMLEFT", 0, -4 - (i - 1) * ROW_H)
      hit:SetPoint("RIGHT", f.ghow, "RIGHT", 0, 0)
      local r = rankRow(hit, i)
      r.pos:SetPoint("LEFT", 0, 0)
      r.value:SetPoint("RIGHT", 0, 0)
      r.name:SetPoint("LEFT", r.pos, "RIGHT", 10, 0)
      r.name:SetPoint("RIGHT", r.value, "LEFT", -10, 0)
      r.line:SetPoint("BOTTOMLEFT", 0, 0)
      r.line:SetPoint("BOTTOMRIGHT", 0, 0)
      r.hit = hit
      hit:SetScript("OnClick", function()
        if r.entry then
          GR.ShowCompare(r.entry)
        end
      end)
      f.grows[i] = r
    end
    f.gempty = UI.Text(gboard, 12, C.text3, { wrap = true })
    f.gempty:SetPoint("TOPLEFT", f.ghow, "BOTTOMLEFT", 0, -12)
    f.gempty:SetPoint("RIGHT", -16, 0)
    f.gempty:SetSpacing(4)
    f.gfoot = UI.Plate(f, { corners = 14, rail = 0.2 })
    f.gfoot:SetPoint("BOTTOMLEFT", PAD, 18)
    f.gfoot:SetPoint("BOTTOMRIGHT", -PAD, 18)
    f.gfoot:SetHeight(58)
    f.publish = UI.Button(f.gfoot, "", { height = 26, width = 250 })
    f.publish:SetPoint("RIGHT", -14, 0)
    f.publish:SetScript("OnClick", function()
      local on = not GR.Publishing()
      local ok, why = GR.SetPublishing(on)
      if not ok then
        BG:Notify("No se pudo", why == "permiso" and "Solo el maestro decide si la hermandad sale en la clasificación." or tostring(why), { kind = "warning" })
      end
      BG:RefreshView("rankings")
    end)
    f.gmine = UI.Text(f.gfoot, 12, C.text, { wrap = true })
    f.gmine:SetPoint("LEFT", 16, 0)
    f.gmine:SetPoint("RIGHT", f.publish, "LEFT", -14, 0)
    f.gmine:SetMaxLines(2)
  end,

  Refresh = function(f)
    f.hero:SetArt(BG.file("Interface\\Glues\\LoadingScreens\\LoadScreenMoltenCore", BG.art.RAID), 0.5)
    f.hero:SetIcon(BG.file("Interface\\Icons\\INV_Misc_Ribbon_01", "Interface\\Icons\\INV_Misc_Note_02"))
    f.tabs:SetValue(f.tab, true)
    local honors = f.tab ~= "guilds"
    f.cats:SetShown(honors)
    f.board:SetShown(honors)
    f.foot:SetShown(honors)
    f.gcats:SetShown(not honors)
    f.gboard:SetShown(not honors)
    f.gfoot:SetShown(not honors)
    if not honors then
      return GR.RefreshView(f)
    end
    f.hero.title:SetText("Rankings y honores")
    f.hero.sub:SetText("El primero de cada ranking lleva su honor: sale en su ficha, con un escudo dorado sobre su nombre y en el chat.")
    local cats = H.Categories()
    local shown
    for i, cat in ipairs(cats) do
      local c = f.cards[i]
      if c then
        c.cat = cat
        c.icon:SetTexture(BG.file(cat.icon, "Interface\\Icons\\INV_Misc_Ribbon_01"))
        c.title:SetText(cat.title)
        local first = cat.top[1]
        c.sub:SetText(first and ("Lo lleva " .. first.name) or (cat.note and "Oculto por el maestro" or "Aún nadie"))
        c.right:SetText("")
        c.right2:SetText("")
        local on = cat.key == f.selected
        c:SetSelected(on)
        c.accent:SetShown(on)
        if on then
          shown = cat
        end
      end
    end
    shown = shown or cats[1]
    f.board.head:SetText(shown.title)
    f.how:SetText(shown.how)
    for i, r in ipairs(f.rows) do
      local t = shown.top[i]
      r.pos:SetShown(t ~= nil)
      r.name:SetShown(t ~= nil)
      r.value:SetShown(t ~= nil)
      r.line:SetShown(t ~= nil)
      if t then
        local m = BG.Guild.Find(t.name)
        r.name:SetText(BG.colorize(t.name, BG.classColor(m and m.classFile)))
        r.value:SetText(t.text)
      end
    end
    f.empty:SetShown(#shown.top == 0)
    f.empty:SetText(shown.note or "Aún no hay nadie en este ranking.")
    local me = Names.Me()
    local mine = me and H.Of(me) or {}
    f.mine:SetText(#mine > 0 and ("Tus honores: " .. table.concat(mine, ", ") .. ".") or "Aún no tienes honores. Cazar buscados, donar, fabricar encargos, traer gente o ir a las raids te sube en los rankings.")
    f.marks:SetText(BG.Marks.Enabled() and "Marcas en nombres y chat: sí" or "Marcas en nombres y chat: no")
  end,
})

BG:On("BG_HONORS_CHANGED", function()
  BG:RefreshView("rankings")
end)

-- The guilds tab ----------------------------------------------------------------------------------------------------
function GR.RefreshView(f)
  f.hero.title:SetText("Clasificación de hermandades")
  f.hero.sub:SetText("Las hermandades de vuestra facción que juegan con BlazonGuild y publican sus cifras. Se conocen al jugar en grupo con alguien de ellas.")
  local places, n = GR.MyPlaces()
  f.places = places
  f.gcats:SetItems(GR.STATS)
  local st
  for _, s in ipairs(GR.STATS) do
    if s.key == f.gstat then
      st = s
    end
  end
  st = st or GR.STATS[1]
  f.gboard.head:SetText(st.title)
  f.ghow:SetText(st.how)
  local list = GR.Ranking(st.key)
  for i, r in ipairs(f.grows) do
    local e = list[i]
    r.entry = e
    for _, part in ipairs({ r.pos, r.name, r.value, r.line, r.hit }) do
      part:SetShown(e ~= nil)
    end
    if e then
      r.pos:SetText(e.place .. ".")
      r.name:SetText(e.mine and BG.colorize(e.card.n .. "  (vosotros)", C.gold) or (e.card.n .. (e.verified and "" or BG.colorize("  sin verificar", C.text3))))
      r.value:SetText(tostring(e.value))
    end
  end
  f.gempty:SetShown(#list <= 1)
  f.gempty:SetText(#list == 0 and "Aún no conocéis ninguna hermandad. Cuando alguien de la vuestra juegue en grupo con alguien de otra hermandad que use BlazonGuild y publique sus cifras, aparecerá aquí."
    or "Aún no conocéis otras hermandades. Aparecen al jugar en grupo (mazmorras, bandas, campos de batalla) con alguien de ellas que use BlazonGuild.")
  local master = BG.Store.IsMaster(BG.Names.Me())
  local on = GR.Publishing()
  f.publish:SetShown(master)
  f.publish:SetText(on and "Publicar nuestras cifras: sí" or "Publicar nuestras cifras: no")
  local best
  for _, s in ipairs(GR.STATS) do
    if places[s.key] and (not best or places[s.key] < best.place) then
      best = { place = places[s.key], title = s.title }
    end
  end
  local others = math.max(0, n - ((on and GR.Mine()) and 1 or 0))
  f.gmine:SetText((on and ((best and n > 1) and ("Vuestro mejor puesto: " .. best.place .. "º de " .. n .. " en " .. best.title .. ". ") or "Salís en la clasificación. ")
    or (master and "La hermandad no sale: pulsa para publicar sus cifras (nada de nadie en concreto). " or "La hermandad no sale en la clasificación: lo decide el maestro. "))
    .. "Conocéis " .. others .. (others == 1 and " hermandad más." or " hermandades más."))
end

-- Ours and another, side by side.
function GR.ShowCompare(e)
  local mine = GR.Mine() or GR.Count()
  if e.mine or not mine then
    return
  end
  local items = { BG.colorize(mine.n, C.gold) .. "  contra  " .. e.card.n .. (e.verified and "" or " (sin verificar)") }
  local ahead = 0
  for _, s in ipairs(GR.STATS) do
    local a, b = mine[s.key] or 0, e.card[s.key] or 0
    if a > b then
      ahead = ahead + 1
    end
    items[#items + 1] = { bullet = s.title .. ": " .. BG.colorize(tostring(a), a >= b and C.success or C.text2) .. "  /  " .. BG.colorize(tostring(b), b >= a and C.success or C.text2) }
  end
  items[#items + 1] = { note = "Vais por delante en " .. ahead .. " de " .. #GR.STATS .. ". Sus cifras son del " .. UI.FormatDate(e.card.v) .. "." }
  UI.Dialog({ title = "Comparativa", items = items, secondary = { label = "Cerrar" } })
end

BG:On("BG_GUILDRANKS_CHANGED", function()
  if BG.window and BG.window:IsShown() and BG.db.settings.lastView == "rankings" then
    BG:RefreshView("rankings")
  end
end)
