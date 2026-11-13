-- Tesorería: four tabs. Resumen (the balance and this week, your dues, the campaigns, the donors); Libro (every
-- line, written by itself for trades and mail with a treasurer, or by hand; its purpose, its campaign; a copy as
-- text); Cuotas (the master's settings, and who paid this week, for the organisers); Banco (the guild bank as
-- last seen). Nothing here moves gold.
local _, BG = ...
local UI, C = BG.UI, BG.color
local T, Names, Store = BG.Treasury, BG.Names, BG.Store

local PAD = 24
local Money = T.Money

local function why(w, extra)
  return ({ permiso = "No tienes permiso para eso.", cantidad = "Escribe una cantidad, por ejemplo 5 (oro) o 2o 50p.", ["no es de tu hermandad"] = "«" .. tostring(extra or "") .. "» no es de tu hermandad.",
    ["no existe"] = "Ya no existe.", consent = "Acepta antes la privacidad (/bg privacidad).", datos = "Faltan datos." })[w] or ("No se pudo (" .. tostring(w) .. ").")
end

local function overlay(f, title)
  local form = UI.Plate(f, { corners = 22, rail = 0.3 })
  form:SetFrameLevel(f:GetFrameLevel() + 20)
  form:EnableMouse(true)
  form:SetPoint("TOPLEFT", f.hero, "BOTTOMLEFT", PAD, -16)
  form:SetPoint("BOTTOMRIGHT", -PAD, 18)
  form:Hide()
  form.heading = UI.Heading(form, title)
  form.heading:SetPoint("TOPLEFT", 22, -18)
  form.heading:SetPoint("TOPRIGHT", -22, -18)
  function form:Label(text, anchor, y)
    local l = UI.Text(self, 11, C.text3)
    l:SetPoint("TOPLEFT", anchor or self.heading, "BOTTOMLEFT", 0, y or -14)
    l:SetText(text)
    return l
  end
  form.error = UI.Text(form, 12, C.danger, { wrap = true })
  form.error:SetPoint("BOTTOMLEFT", 22, 26)
  form.error:SetWidth(300)
  form.back = UI.Button(form, "Volver", { height = 30, width = 100 })
  form.back:SetPoint("BOTTOMRIGHT", -22, 18)
  form.back:SetScript("OnClick", function()
    form:Hide()
  end)
  return form
end

local function columns(tab, leftTitle, rightTitle)
  local left = UI.Plate(tab, { corners = 18, rail = 0.24 })
  left:SetPoint("TOPLEFT")
  left:SetPoint("BOTTOMLEFT")
  left.head = UI.Heading(left, leftTitle)
  left.head:SetPoint("TOPLEFT", 16, -8)
  left.head:SetPoint("TOPRIGHT", -16, -8)
  local right = UI.Plate(tab, { corners = 18, rail = 0.24 })
  right:SetPoint("TOPLEFT", left, "TOPRIGHT", 18, 0)
  right:SetPoint("BOTTOMRIGHT")
  right.head = UI.Heading(right, rightTitle)
  right.head:SetPoint("TOPLEFT", 16, -8)
  right.head:SetPoint("TOPRIGHT", -16, -8)
  right.text = UI.Text(right, 12, C.text2, { wrap = true })
  right.text:SetPoint("TOPLEFT", right.head, "BOTTOMLEFT", 0, -6)
  right.text:SetPoint("RIGHT", -16, 0)
  right.text:SetSpacing(4)
  tab.left, tab.right = left, right
  return left, right
end

-- Resumen -----------------------------------------------------------------------------------------------------------
local function campaignRow(list)
  local c = UI.Card(list)
  c.icon:SetTexture("Interface\\Icons\\INV_Misc_Coin_01")
  c.bar = UI.Bar(c)
  c.bar:SetHeight(6)
  c.bar:SetPoint("BOTTOMLEFT", 54, 10)
  c.bar:SetPoint("BOTTOMRIGHT", -12, 10)
  return c
end

local function fillCampaign(c, r)
  c.key = r.id
  c:SetHeight(64)
  local frac = math.min(1, r.raised / r.d.goal)
  c.title:SetText(r.d.title .. (r.d.done and BG.colorize("  cerrada", C.text3) or ""))
  c.sub:SetText(r.d.untilT and BG.TF("%s de %s reunidos, hasta el %s", Money(r.raised), Money(r.d.goal), UI.FormatDate(r.d.untilT)) or BG.TF("%s de %s reunidos", Money(r.raised), Money(r.d.goal)))
  c.right:SetText(math.floor(frac * 100) .. "%")
  c.right2:SetText("")
  c.bar:Set(frac, frac >= 1 and C.success or C.gold)
  c.detail = { "Para aportar, dale el oro a un tesorero (comercio o correo) y dile que es para esta campaña." }
end

local function buildSummary(tab, f)
  local left, right = columns(tab, "Esta semana", "Campañas")
  f.plates = {}
  for i = 1, 3 do
    local p = UI.StatPlate(left)
    p:SetHeight(72)
    f.plates[i] = p
  end
  f.mine = UI.Text(left, 13, C.text, { wrap = true })
  f.mine:SetPoint("TOPLEFT", f.plates[1], "BOTTOMLEFT", 0, -16)
  f.mine:SetPoint("RIGHT", -16, 0)
  f.mine:SetSpacing(4)
  f.donorsHead = UI.Heading(left, "Mayores donantes (90 días)")
  f.donorsHead:SetPoint("TOPLEFT", f.mine, "BOTTOMLEFT", 0, -14)
  f.donorsHead:SetPoint("RIGHT", -16, 0)
  f.donors = UI.Text(left, 12, C.text2, { wrap = true })
  f.donors:SetPoint("TOPLEFT", f.donorsHead, "BOTTOMLEFT", 0, -6)
  f.donors:SetPoint("RIGHT", -16, 0)
  f.donors:SetSpacing(4)
  f.newCamp = UI.Button(right, "Nueva campaña", { height = 24, width = 130 })
  f.newCamp:SetPoint("TOPRIGHT", -16, -10)
  f.newCamp:SetScript("OnClick", function()
    f.campForm:Open()
  end)
  f.camps = UI.List(right, 70, campaignRow, fillCampaign)
  f.camps:SetPoint("TOPLEFT", right.text, "BOTTOMLEFT", 0, -10)
  f.camps:SetPoint("BOTTOMRIGHT", -16, 14)
end

-- Libro -------------------------------------------------------------------------------------------------------------
local VIA = { TRADE = "comercio", MAIL = "correo", HAND = "a mano" }

local function lineRow(list, f)
  local c = UI.Card(list)
  c.edit = UI.CardButton(c, "Editar", { height = 22, width = 70 })
  c.edit:SetPoint("BOTTOMRIGHT", -10, 8)
  c.edit:SetScript("OnClick", function()
    if c.line then
      f.lineForm:Open(c.line)
    end
  end)
  c.right:ClearAllPoints()
  c.right:SetPoint("TOPRIGHT", -12, -10)
  return c
end

local function fillLine(c, r)
  c.line = r
  c.key = r.id
  c:SetHeight(60)
  local inc = r.d.k == "IN"
  c.icon:SetTexture(inc and "Interface\\Icons\\INV_Misc_Coin_02" or "Interface\\Icons\\INV_Misc_Coin_04")
  c.title:SetText(BG.colorize((inc and "+" or "-") .. Money(r.d.c), inc and C.success or C.warning) .. "  " .. (inc and "de " or "para ") .. (r.d.who or "?"))
  local camp = r.d.camp and Store.Get("campaigns", r.d.camp)
  c.sub:SetText((r.d.note and r.d.note ~= "" and r.d.note or "Sin concepto") .. (camp and camp.d and (", campaña «" .. camp.d.title .. "»") or ""))
  c.right:SetText(UI.FormatDate(r.at, true))
  c.right2:SetText("")
  c.detail = { "Apuntado por " .. (r.d.keeper or r.by or "?") .. ", " .. (VIA[r.d.via] or "") .. "." }
  local me = Names.Me() or ""
  c.edit:SetShown(Store.IsMaster(me) or (T.IsKeeper(me) and Names.Same(r.d.keeper, me)))
end

local function buildBook(tab, f)
  local left, right = columns(tab, "Libro de la tesorería", "Cómo se apunta")
  f.addLine = UI.Button(left, "Apuntar a mano", { primary = true, height = 24, width = 140 })
  f.addLine:SetPoint("TOPRIGHT", -16, -10)
  f.addLine:SetScript("OnClick", function()
    f.lineForm:Open(nil)
  end)
  f.lines = UI.List(left, 66, function(list)
    return lineRow(list, f)
  end, fillLine)
  f.lines:SetPoint("TOPLEFT", left.head, "BOTTOMLEFT", 0, -10)
  f.lines:SetPoint("BOTTOMRIGHT", -16, 14)
  f.linesEmpty = UI.Text(left, 12, C.text3, { wrap = true })
  f.linesEmpty:SetPoint("TOPLEFT", left.head, "BOTTOMLEFT", 0, -14)
  f.linesEmpty:SetPoint("RIGHT", -16, 0)
  f.export = UI.Button(right, "Copia de seguridad", { height = 26, width = 170 })
  f.export:SetPoint("BOTTOMLEFT", 16, 16)
  f.export:SetScript("OnClick", function()
    f.exportForm:Open()
  end)
end

-- Cuotas ------------------------------------------------------------------------------------------------------------
local function duesRow(list)
  local c = UI.Card(list)
  c.exempt = UI.CardButton(c, "Exento", { height = 22, width = 80 })
  c.exempt:SetPoint("BOTTOMRIGHT", -10, 8)
  c.exempt:SetScript("OnClick", function()
    if c.member then
      local ok, w = T.SetExempt(c.member.name, not c.member.exempt)
      if not ok then
        BG:Notify("No se pudo", why(w), { kind = "warning" })
      end
    end
  end)
  c.right:ClearAllPoints()
  c.right:SetPoint("TOPRIGHT", -12, -10)
  return c
end

local function fillDues(c, m)
  c.member = m
  c.key = m.name
  c:SetHeight(56)
  c.icon:SetTexture("Interface\\Icons\\INV_Misc_Coin_17")
  c.title:SetText(BG.colorize(m.name, BG.classColor(m.class)))
  local amount = T.Settings().dues
  c.sub:SetText(m.exempt and "Exento de la cuota." or (amount == 0 and ("Esta semana: " .. Money(m.given) .. ".")
    or ("Esta semana: " .. Money(m.given) .. (m.owed > 0 and (", le faltan " .. Money(m.owed)) or ", al día") .. ".")))
  c.right:SetText(m.exempt and BG.colorize("exento", C.text3) or (m.owed > 0 and BG.colorize("pendiente", C.warning) or BG.colorize("al día", C.success)))
  c.right2:SetText("")
  local hist = {}
  for i, g in ipairs(m.weeks) do
    hist[#hist + 1] = (i == 1 and "La semana pasada: " or "") .. Money(g)
  end
  c.detail = { table.concat(hist, ", ") .. " (de la más reciente a la más antigua)." }
  c.exempt.text:SetText(m.exempt and "Quitar exento" or "Exento")
  c.exempt:SetShown(Store.IsOrganiser(Names.Me() or ""))
end

local function buildDues(tab, f)
  local left, right = columns(tab, "Cuotas de esta semana", "Ajustes del maestro")
  f.dues = UI.List(left, 62, duesRow, fillDues)
  f.dues:SetPoint("TOPLEFT", left.head, "BOTTOMLEFT", 0, -10)
  f.dues:SetPoint("BOTTOMRIGHT", -16, 14)
  f.duesNote = UI.Text(left, 12, C.text3, { wrap = true })
  f.duesNote:SetPoint("TOPLEFT", left.head, "BOTTOMLEFT", 0, -14)
  f.duesNote:SetPoint("RIGHT", -16, 0)
  -- The master's settings.
  local l1 = UI.Text(right, 11, C.text3)
  l1:SetPoint("TOPLEFT", right.text, "BOTTOMLEFT", 0, -12)
  l1:SetText("Tesoreros (nombres separados por comas)")
  f.keepers = UI.EditBox(right, { width = 200, maxLetters = 200, placeholder = "Por ejemplo: Rina Dagaluna" })
  f.keepers:SetPoint("TOPLEFT", l1, "BOTTOMLEFT", 0, -4)
  f.keepers:SetPoint("RIGHT", -16, 0)
  local l2 = UI.Text(right, 11, C.text3)
  l2:SetPoint("TOPLEFT", f.keepers, "BOTTOMLEFT", 0, -10)
  l2:SetText("Cuota semanal (oro; 0 = sin cuota)")
  f.duesAmount = UI.EditBox(right, { width = 120, maxLetters = 12, placeholder = "Por ejemplo: 5" })
  f.duesAmount:SetPoint("TOPLEFT", l2, "BOTTOMLEFT", 0, -4)
  f.showBal = UI.Button(right, "", { height = 24 })
  f.showBal:SetPoint("TOPLEFT", f.duesAmount, "BOTTOMLEFT", 0, -12)
  f.showBal:SetPoint("RIGHT", -16, 0)
  f.showRank = UI.Button(right, "", { height = 24 })
  f.showRank:SetPoint("TOPLEFT", f.showBal, "BOTTOMLEFT", 0, -6)
  f.showRank:SetPoint("RIGHT", -16, 0)
  f.showBook = UI.Button(right, "", { height = 24 })
  f.showBook:SetPoint("TOPLEFT", f.showRank, "BOTTOMLEFT", 0, -6)
  f.showBook:SetPoint("RIGHT", -16, 0)
  for key, b in pairs({ bal = f.showBal, rank = f.showRank, book = f.showBook }) do
    b:SetScript("OnClick", function()
      local cur = T.Settings().show
      local ok, w = T.Configure({ show = { [key] = not cur[key] } })
      if not ok then
        BG:Notify("No se pudo", why(w), { kind = "warning" })
      end
    end)
  end
  f.saveCfg = UI.Button(right, "Guardar", { primary = true, height = 26, width = 110 })
  f.saveCfg:SetPoint("BOTTOMRIGHT", -16, 16)
  f.cfgNote = UI.Text(right, 11, C.text3, { wrap = true })
  f.cfgNote:SetPoint("BOTTOMLEFT", 16, 20)
  f.cfgNote:SetPoint("RIGHT", f.saveCfg, "LEFT", -10, 0)
  f.saveCfg:SetScript("OnClick", function()
    local copper = T.ParseMoney(f.duesAmount:GetText() ~= "" and f.duesAmount:GetText() or "0")
    if not copper then
      f.cfgNote:SetText(BG.colorize(why("cantidad"), C.warning))
      return
    end
    local ok, w, extra = T.Configure({ keepers = f.keepers:GetText(), dues = copper })
    f.cfgNote:SetText(ok and BG.colorize("Guardado.", C.success) or BG.colorize(why(w, extra), C.warning))
  end)
  f.cfgWidgets = { l1, l2, f.keepers, f.duesAmount, f.showBal, f.showRank, f.showBook, f.saveCfg, f.cfgNote }
end

-- Banco ------------------------------------------------------------------------------------------------------------
local function buildBank(tab, f)
  local left, right = columns(tab, "Banco de la hermandad", "Qué es esto")
  f.bankText = UI.Text(left, 12, C.text, { wrap = true })
  f.bankText:SetPoint("TOPLEFT", left.head, "BOTTOMLEFT", 0, -8)
  f.bankText:SetPoint("RIGHT", -16, 0)
  f.bankText:SetSpacing(4)
  f.bankText:SetMaxLines(24)
  right.text:SetText("Cuando un oficial o un tesorero abre el banco de la hermandad con BlazonGuild, el addon toma una foto de lo que hay: el oro y los objetos de cada pestaña que puede ver. Aquí sale la última. El addon no saca ni mete nada.")
end

-- Forms ------------------------------------------------------------------------------------------------------------
local function buildLineForm(f)
  local form = overlay(f, "Apuntar en el libro")
  local l0 = form:Label("Qué fue")
  form.kind = UI.Segmented(form, { { value = "IN", label = "Entrada" }, { value = "OUT", label = "Salida" } }, { itemWidth = 110 })
  form.kind:SetPoint("TOPLEFT", l0, "BOTTOMLEFT", 0, -4)
  local l1 = form:Label("Cuánto (5 = 5 de oro; también 2o 50p)", form.kind, -12)
  form.amount = UI.EditBox(form, { width = 160, maxLetters = 14, placeholder = "Por ejemplo: 5" })
  form.amount:SetPoint("TOPLEFT", l1, "BOTTOMLEFT", 0, -4)
  local l2 = form:Label("De quién o para quién", form.amount, -12)
  form.who = UI.EditBox(form, { width = 260, maxLetters = 40, placeholder = "Nombre y apellido" })
  form.who:SetPoint("TOPLEFT", l2, "BOTTOMLEFT", 0, -4)
  local l3 = form:Label("Concepto (para qué es)", form.who, -12)
  form.note = UI.EditBox(form, { width = 420, maxLetters = 100, placeholder = "Por ejemplo: pociones para la banda del jueves" })
  form.note:SetPoint("TOPLEFT", l3, "BOTTOMLEFT", 0, -4)
  local l4 = form:Label("Campaña (opcional)", form.note, -12)
  form.camp = UI.Picker(form, { width = 300, placeholder = "Ninguna" })
  form.camp:SetPoint("TOPLEFT", l4, "BOTTOMLEFT", 0, -4)
  form.save = UI.Button(form, "Guardar", { primary = true, height = 30, width = 120 })
  form.save:SetPoint("RIGHT", form.back, "LEFT", -10, 0)
  form.del = UI.Button(form, "Borrar", { height = 30, width = 90 })
  form.del:SetPoint("RIGHT", form.save, "LEFT", -10, 0)
  form.del:SetScript("OnClick", function()
    if form.editing then
      T.DeleteLine(form.editing)
      form:Hide()
    end
  end)
  form.save:SetScript("OnClick", function()
    local camp = form.camp:GetValue()
    camp = camp ~= "none" and camp or false
    local ok, w
    if form.editing then
      ok, w = T.EditLine(form.editing, { note = form.note:GetText(), camp = camp })
    else
      local copper = T.ParseMoney(form.amount:GetText())
      if not copper or copper <= 0 then
        form.error:SetText(why("cantidad"))
        return
      end
      ok, w = T.Record(form.kind:GetValue(), copper, form.who:GetText(), "HAND", form.note:GetText())
      if ok and camp then
        T.EditLine(ok.id, { camp = camp })
      end
    end
    if not ok then
      form.error:SetText(why(w))
      return
    end
    form:Hide()
  end)
  function form:Open(line)
    self.editing = line and line.id or nil
    self.error:SetText("")
    self.heading.title:SetText(line and "Editar la línea" or "Apuntar en el libro")
    local opts = { { value = "none", label = "Ninguna" } }
    for _, c in ipairs(T.Campaigns()) do
      if not c.d.done then
        opts[#opts + 1] = { value = c.id, label = c.d.title }
      end
    end
    self.camp:SetOptions(opts)
    self.camp:SetValue(line and line.d.camp or "none", true)
    self.kind:SetValue(line and line.d.k or "IN", true)
    self.amount:SetText(line and tostring(line.d.c / 10000) or "")
    self.who:SetText(line and line.d.who or "")
    self.note:SetText(line and line.d.note or "")
    -- (an existing line keeps what happened; only its purpose and campaign change)
    self.kind:SetShown(line == nil)
    self.amount:SetShown(line == nil)
    self.who:SetShown(line == nil)
    self.del:SetShown(line ~= nil)
    self:Show()
  end
  return form
end

local function buildCampaignForm(f)
  local form = overlay(f, "Nueva campaña")
  local l1 = form:Label("Para qué")
  form.title = UI.EditBox(form, { width = 360, maxLetters = 60, placeholder = "Por ejemplo: pociones para Núcleo de Magma" })
  form.title:SetPoint("TOPLEFT", l1, "BOTTOMLEFT", 0, -4)
  local l2 = form:Label("Objetivo (oro)", form.title, -12)
  form.goal = UI.EditBox(form, { width = 140, maxLetters = 12, placeholder = "Por ejemplo: 100" })
  form.goal:SetPoint("TOPLEFT", l2, "BOTTOMLEFT", 0, -4)
  local l3 = form:Label("Días que dura", form.goal, -12)
  form.days = UI.Stepper(form, "", 1, 60, { width = 90, value = 14 })
  form.days:SetPoint("TOPLEFT", l3, "BOTTOMLEFT", 0, -4)
  form.save = UI.Button(form, "Crear", { primary = true, height = 30, width = 120 })
  form.save:SetPoint("RIGHT", form.back, "LEFT", -10, 0)
  form.save:SetScript("OnClick", function()
    local goal = T.ParseMoney(form.goal:GetText())
    if not goal or goal <= 0 then
      form.error:SetText(why("cantidad"))
      return
    end
    local ok, w = T.NewCampaign(form.title:GetText(), goal, form.days:GetValue())
    if not ok then
      form.error:SetText(why(w == "datos" and "datos" or w))
      return
    end
    form:Hide()
  end)
  function form:Open()
    self.error:SetText("")
    self.title:SetText("")
    self.goal:SetText("")
    self.days:SetValue(14, true)
    self:Show()
  end
  return form
end

-- The book as text in a box: select all is done, the player copies it (Ctrl+C) and keeps it outside the game.
local function buildExportForm(f)
  local form = overlay(f, "Copia de seguridad del libro")
  local l1 = form:Label("Pulsa Ctrl+C para copiarlo y guárdalo fuera del juego (por ejemplo, en un documento).")
  form.box = CreateFrame("EditBox", nil, form)
  form.box:SetMultiLine(true)
  form.box:SetAutoFocus(false)
  form.box:SetFontObject(ChatFontNormal)
  form.box:SetPoint("TOPLEFT", l1, "BOTTOMLEFT", 0, -8)
  form.box:SetPoint("BOTTOMRIGHT", -22, 64)
  form.box:SetScript("OnEscapePressed", function(self)
    self:ClearFocus()
  end)
  function form:Open()
    self.box:SetText(T.Export())
    self:Show()
    self.box:SetFocus()
    self.box:HighlightText()
  end
  return form
end

-- View ---------------------------------------------------------------------------------------------------------------
local TABS = { { value = "summary", label = "Resumen" }, { value = "book", label = "Libro" }, { value = "dues", label = "Cuotas" }, { value = "bank", label = "Banco" } }

BG:RegisterView("treasury", {
  Build = function(f)
    f.hero = UI.Hero(f, 108)
    f.hero:SetPoint("TOPLEFT")
    f.hero:SetPoint("TOPRIGHT")
    f.tab = "summary"
    f.tabs = UI.Segmented(f, TABS, { itemWidth = 110, onChange = function(v)
      f.tab = v
      BG:RefreshView("treasury")
    end })
    f.tabs:SetPoint("TOPLEFT", f.hero, "BOTTOMLEFT", PAD, -12)
    f.pages = {}
    for _, t in ipairs(TABS) do
      local page = CreateFrame("Frame", nil, f)
      page:SetPoint("TOPLEFT", f.tabs, "BOTTOMLEFT", 0, -12)
      page:SetPoint("BOTTOMRIGHT", -PAD, 18)
      f.pages[t.value] = page
    end
    buildSummary(f.pages.summary, f)
    buildBook(f.pages.book, f)
    buildDues(f.pages.dues, f)
    buildBank(f.pages.bank, f)
    f.lineForm = buildLineForm(f)
    f.campForm = buildCampaignForm(f)
    f.exportForm = buildExportForm(f)
    f:SetScript("OnSizeChanged", function(self, w)
      local lw = math.floor((w - PAD * 2 - 18) * 0.56)
      for _, page in pairs(self.pages) do
        page.left:SetWidth(lw)
      end
      local inner = lw - 32
      local pw = (inner - 2 * 10) / 3
      for i, p in ipairs(self.plates) do
        p:SetWidth(pw)
        p:ClearAllPoints()
        p:SetPoint("TOPLEFT", self.pages.summary.left.head, "BOTTOMLEFT", (i - 1) * (pw + 10), -10)
      end
    end)
  end,

  Refresh = function(f)
    local info = BG.Guild.info
    local me = Names.Me() or ""
    local org, keeper, master = Store.IsOrganiser(me), T.IsKeeper(me), Store.IsMaster(me)
    local cfg = T.Settings()
    local faction = info and info.faction or "ALLIANCE"
    f.hero:SetArt(BG.art[faction] or BG.art.ALLIANCE, 0.5)
    f.hero:SetIcon(BG.file("Interface\\Icons\\INV_Misc_Coin_01", "Interface\\Icons\\INV_Misc_Note_02"))
    local tot = T.Totals()
    f.hero.title:SetText("Tesorería")
    f.hero.sub:SetText((#cfg.keepers > 0 and ("Tesoreros: " .. table.concat(cfg.keepers, ", ") .. ". ") or "Aún no hay tesoreros: los nombra el maestro en «Cuotas». ")
      .. "El addon no mueve oro: apunta lo que se da a los tesoreros.")
    f.tabs:SetValue(f.tab, true)
    for key, page in pairs(f.pages) do
      page:SetShown(key == f.tab)
    end

    if f.tab == "summary" then
      local seeBal = T.Sees("bal")
      f.plates[1]:Set(seeBal and T.MoneyShort(tot.bal) or "—", "Saldo", seeBal and "según el libro" or "lo decide el maestro")
      f.plates[2]:Set(seeBal and T.MoneyShort(tot.inWeek) or "—", "Esta semana", "entró")
      f.plates[3]:Set(tostring(tot.donorsWeek), "Donantes", "esta semana")
      local given = T.GivenIn(me)
      local dues = cfg.dues
      local mineText
      if dues == 0 then
        mineText = "No hay cuota semanal. " .. (given > 0 and ("Esta semana has dado " .. Money(given) .. ". ¡Gracias!") or "Si quieres ayudar, da oro a un tesorero (comercio o correo): se apunta solo.")
      elseif T.Exempt(me) then
        mineText = BG.TF("Estás exento de la cuota semanal (%s).", Money(dues))
      else
        local owed = math.max(0, dues - given)
        mineText = owed > 0 and BG.TF("Cuota: %s por semana. Esta semana has dado %s: te faltan %s. Dáselo a un tesorero por comercio o correo.", Money(dues), Money(given), Money(owed))
          or BG.TF("Cuota: %s por semana. Esta semana has dado %s: estás al día. ¡Gracias!", Money(dues), Money(given))
      end
      f.mine:SetText(mineText)
      local seeRank = T.Sees("rank")
      f.donorsHead:SetShown(seeRank)
      f.donors:SetShown(seeRank)
      local lines = {}
      for i, d in ipairs(T.Ranking(8)) do
        lines[#lines + 1] = i .. ". " .. d.name .. ": " .. Money(d.c)
      end
      f.donors:SetText(#lines > 0 and table.concat(lines, "\n") or "Aún nadie.")
      local camps = T.Campaigns()
      f.pages.summary.right.text:SetText(#camps == 0 and "No hay campañas. Una campaña junta oro para algo concreto (por ejemplo, 100 de oro para pociones de banda) y enseña cuánto falta."
        or "Para aportar a una, dale el oro a un tesorero y dile para cuál es.")
      f.camps:SetItems(camps)
      f.newCamp:SetShown(org or keeper)
    elseif f.tab == "book" then
      local see = T.Sees("book")
      local list = see and T.Lines() or {}
      f.lines:SetItems(list)
      f.linesEmpty:SetShown(#list == 0)
      f.linesEmpty:SetText(not see and "El maestro ha decidido que el libro solo lo vean los oficiales y los tesoreros."
        or "El libro está vacío. Cuando alguien dé oro a un tesorero por comercio o correo, se apunta aquí solo.")
      f.addLine:SetShown(keeper)
      f.export:SetShown(see)
      f.pages.book.right.text:SetText("Se apunta solo cuando un tesorero recibe o da oro por comercio o por correo: entrada si se lo dan, salida si lo da él. "
        .. "El tesorero también puede apuntar a mano, y en cada línea poner el concepto (para qué es) y su campaña. "
        .. "«Copia de seguridad» saca el libro en texto para guardarlo fuera del juego.")
    elseif f.tab == "dues" then
      local list = org and T.Dues() or {}
      f.dues:SetItems(list)
      f.duesNote:SetShown(#list == 0)
      f.duesNote:SetText(org and "Nadie en la hermandad." or "Solo los oficiales ven quién ha pagado. Tu propia cuota está en «Resumen».")
      f.pages.dues.right.text:SetText(master and "Nombra a los tesoreros y fija la cuota. Los interruptores deciden qué ven los miembros (los oficiales lo ven todo)."
        or ("Lo decide el maestro. Ahora: " .. (cfg.dues > 0 and ("cuota de " .. Money(cfg.dues) .. " por semana.") or "sin cuota.")))
      for _, w in ipairs(f.cfgWidgets) do
        w:SetShown(master)
      end
      if master then
        if not f.keepers.edit:HasFocus() then
          f.keepers:SetText(table.concat(cfg.keepers, ", "))
        end
        if not f.duesAmount.edit:HasFocus() then
          f.duesAmount:SetText(cfg.dues > 0 and tostring(cfg.dues / 10000) or "0")
        end
        f.showBal.text:SetText("Saldo para todos: " .. (cfg.show.bal and "sí" or "no"))
        f.showRank.text:SetText("Ranking de donantes para todos: " .. (cfg.show.rank and "sí" or "no"))
        f.showBook.text:SetText("Libro para todos: " .. (cfg.show.book and "sí" or "no"))
      end
    else
      local b = T.Bank()
      if not b then
        f.bankText:SetText(BG.colorize("Aún no hay foto del banco. Aparecerá cuando un oficial o un tesorero lo abra con BlazonGuild.", C.text3))
      else
        local lines = { BG.TF("Oro: %s. Visto por %s el %s.", Money(b.d.gold), b.by or "?", UI.FormatDate(b.at, true)) }
        for _, t in ipairs(b.d.tabs) do
          local items = {}
          for _, x in ipairs(t.it) do
            items[#items + 1] = (BG.Crafts.ItemName(x[1]) or ("objeto " .. x[1])) .. " x" .. x[2]
          end
          lines[#lines + 1] = BG.colorize(t.n, C.goldTitle) .. ": " .. (#items > 0 and table.concat(items, ", ") or "vacía")
        end
        f.bankText:SetText(table.concat(lines, "\n"))
      end
    end
  end,
})

BG:On("BG_TREASURY_CHANGED", function()
  BG:RefreshView("treasury")
end)
