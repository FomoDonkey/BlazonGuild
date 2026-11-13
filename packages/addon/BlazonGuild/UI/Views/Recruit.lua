-- Reclutamiento. Without a guild: "Únete a una hermandad" (search a guild by name, see its card, ask to join).
-- In a guild: its public card (the organisers write it), the join requests (organisers: invite or not), who
-- brings the most people, and "who brought you?".
local _, BG = ...
local UI, C = BG.UI, BG.color
local R, Names, Store = BG.Recruit, BG.Names, BG.Store

local PAD = 24

local function why(w)
  return ({ permiso = "Solo los oficiales pueden hacerlo.", nombre = "Escribe el nombre de la hermandad.", espera = "Espera unos segundos entre búsquedas (el juego lo pide).",
    nadie = "Busca antes la hermandad: hace falta alguien suyo conectado.", ["no es de tu hermandad"] = "Esa persona no es de tu hermandad.",
    ["tú mismo"] = "Escribe el nombre de quien te trajo.", ["sin who"] = "Este cliente no permite buscar con /who." })[w] or ("No se pudo (" .. tostring(w) .. ").")
end

local function plate(f, title)
  local p = UI.Plate(f, { corners = 18, rail = 0.24 })
  p.head = UI.Heading(p, title)
  p.head:SetPoint("TOPLEFT", 16, -8)
  p.head:SetPoint("TOPRIGHT", -16, -8)
  return p
end

local function charterText(c, guildName)
  if not c then
    return BG.colorize("Aún no hay ficha. La escriben los oficiales: a qué os dedicáis, idioma, días de banda y a quién buscáis.", C.text3)
  end
  local lines = {}
  lines[#lines + 1] = c.open and BG.colorize("Reclutando", C.success) or BG.colorize("No recluta ahora", C.warning)
  if c.about ~= "" then
    lines[#lines + 1] = c.about
  end
  if c.lang ~= "" then
    lines[#lines + 1] = "Idioma: " .. c.lang .. "."
  end
  if c.days ~= "" then
    lines[#lines + 1] = "Cuándo jugamos: " .. c.days .. "."
  end
  lines[#lines + 1] = R.WantsText(c)
  if c.contact then
    lines[#lines + 1] = "Contacto: " .. c.contact .. "."
  end
  return table.concat(lines, "\n")
end

-- Cards ---------------------------------------------------------------------------------------------------------
local function foundRow(list)
  local c = UI.Card(list)
  c.ask = UI.CardButton(c, "Ver su ficha", { height = 22, width = 110 })
  c.ask:SetPoint("BOTTOMRIGHT", -10, 8)
  c.ask:SetScript("OnClick", function()
    if c.who then
      R.AskCard(c.who.name)
      BG:RefreshView("recruit")
    end
  end)
  return c
end

local function fillFound(c, w)
  c.who = w
  c.key = w.name
  c:SetHeight(56)
  c.icon:SetTexture("Interface\\Icons\\INV_Misc_GroupNeedMore")
  c.title:SetText(BG.colorize(w.name, BG.classColor(w.class)))
  c.sub:SetText("Nivel " .. (w.level or "?") .. ", de " .. (w.guild or "?"))
  c.right:SetText("conectado")
  c.right2:SetText("")
end

local function requestRow(list)
  local c = UI.Card(list)
  c.no = UI.CardButton(c, "No", { height = 22, width = 50 })
  c.no:SetPoint("BOTTOMRIGHT", -10, 8)
  c.yes = UI.CardButton(c, "Invitar", { primary = true, height = 22, width = 80 })
  c.yes:SetPoint("RIGHT", c.no, "LEFT", -6, 0)
  c.yes:SetScript("OnClick", function()
    if c.req then
      R.Answer(c.req.name, true)
    end
  end)
  c.no:SetScript("OnClick", function()
    if c.req then
      R.Answer(c.req.name, false)
    end
  end)
  return c
end

local function fillRequest(c, r)
  c.req = r
  c.key = r.name
  c:SetHeight(58)
  c.icon:SetTexture("Interface\\Icons\\INV_Letter_15")
  c.title:SetText(BG.colorize(r.name, BG.classColor(r.class)) .. (r.level and BG.colorize("  nivel " .. r.level, C.text3) or ""))
  c.sub:SetText(r.note and r.note ~= "" and r.note or ("Pide entrar. Llegó a través de " .. (r.via or "?") .. "."))
  c.right:SetText("")
  c.right2:SetText("")
  c.detail = { "Llegó a través de " .. (r.via or "?") .. ". «Invitar» manda la invitación del juego; «No» se lo dice con educación." }
  local org = Store.IsOrganiser(Names.Me() or "")
  c.yes:SetShown(org)
  c.no:SetShown(org)
end

-- Charter form ----------------------------------------------------------------------------------------------------
local function buildCharterForm(f)
  local form = UI.Plate(f, { corners = 22, rail = 0.3 })
  form:SetFrameLevel(f:GetFrameLevel() + 20)
  form:EnableMouse(true)
  form:SetPoint("TOPLEFT", f.hero, "BOTTOMLEFT", PAD, -16)
  form:SetPoint("BOTTOMRIGHT", -PAD, 18)
  form:Hide()
  form.heading = UI.Heading(form, "Ficha de la hermandad")
  form.heading:SetPoint("TOPLEFT", 22, -18)
  form.heading:SetPoint("TOPRIGHT", -22, -18)
  local function label(text, anchor, y)
    local l = UI.Text(form, 11, C.text3)
    l:SetPoint("TOPLEFT", anchor or form.heading, "BOTTOMLEFT", 0, y or -12)
    l:SetText(text)
    return l
  end
  form.open = UI.Segmented(form, { { value = true, label = "Reclutando" }, { value = false, label = "Cerrado" } }, { itemWidth = 110 })
  form.open:SetPoint("TOPLEFT", label("Reclutamiento"), "BOTTOMLEFT", 0, -4)
  form.about = UI.EditBox(form, { width = 420, maxLetters = 240, placeholder = "Por ejemplo: hermandad española de raids y JcJ, buen rollo" })
  form.about:SetPoint("TOPLEFT", label("A qué os dedicáis", form.open), "BOTTOMLEFT", 0, -4)
  form.about:SetPoint("RIGHT", -22, 0)
  form.lang = UI.EditBox(form, { width = 140, maxLetters = 30, placeholder = "Español" })
  form.lang:SetPoint("TOPLEFT", label("Idioma", form.about), "BOTTOMLEFT", 0, -4)
  form.days = UI.EditBox(form, { width = 260, maxLetters = 80, placeholder = "Por ejemplo: miércoles y domingos, 21:00" })
  form.days:SetPoint("LEFT", form.lang, "RIGHT", 12, 0)
  form.daysLabel = UI.Text(form, 11, C.text3)
  form.daysLabel:SetPoint("BOTTOMLEFT", form.days, "TOPLEFT", 0, 4)
  form.daysLabel:SetText("Cuándo jugáis")
  form.roles = {}
  local lr = label("A quién buscáis (pulsa para marcar)", form.lang)
  local prev
  for _, r in ipairs({ { "TANK", "Tanques" }, { "HEALER", "Sanadores" }, { "DPS", "Daño" } }) do
    local b = UI.Button(form, r[2], { height = 24, width = 104 })
    if prev then
      b:SetPoint("LEFT", prev, "RIGHT", 6, 0)
    else
      b:SetPoint("TOPLEFT", lr, "BOTTOMLEFT", 0, -4)
    end
    b.key = r[1]
    b:SetScript("OnClick", function(self)
      form.state.roles[self.key] = not form.state.roles[self.key] or nil
      form:Paint()
    end)
    form.roles[#form.roles + 1] = b
    prev = b
  end
  form.classes = {}
  local lc = label("Clases (opcional)", form.roles[1])
  for i, k in ipairs(R.CLASSES) do
    local b = UI.Button(form, R.CLASS_NAMES[k], { height = 22, width = 96 })
    local col, row = (i - 1) % 5, math.floor((i - 1) / 5)
    b:SetPoint("TOPLEFT", lc, "BOTTOMLEFT", col * 100, -4 - row * 26)
    b.key = k
    b:SetScript("OnClick", function(self)
      local list, found = form.state.classes, nil
      for j, x in ipairs(list) do
        if x == self.key then
          found = j
        end
      end
      if found then
        table.remove(list, found)
      else
        list[#list + 1] = self.key
      end
      form:Paint()
    end)
    form.classes[#form.classes + 1] = b
  end
  form.contact = UI.EditBox(form, { width = 220, maxLetters = 40, placeholder = "Nombre y apellido (opcional)" })
  form.contact:SetPoint("TOPLEFT", label("Contacto", form.classes[6], -10), "BOTTOMLEFT", 0, -4)
  form.error = UI.Text(form, 12, C.danger, { wrap = true })
  form.error:SetPoint("BOTTOMLEFT", 22, 26)
  form.error:SetWidth(280)
  form.back = UI.Button(form, "Volver", { height = 30, width = 100 })
  form.back:SetPoint("BOTTOMRIGHT", -22, 18)
  form.back:SetScript("OnClick", function()
    form:Hide()
  end)
  form.save = UI.Button(form, "Guardar", { primary = true, height = 30, width = 120 })
  form.save:SetPoint("RIGHT", form.back, "LEFT", -10, 0)
  form.save:SetScript("OnClick", function()
    local ok, w = R.SaveCharter({ open = form.open:GetValue() == true, about = form.about:GetText(), lang = form.lang:GetText(), days = form.days:GetText(),
      roles = form.state.roles, classes = form.state.classes, contact = form.contact:GetText() })
    if not ok then
      form.error:SetText(why(w))
      return
    end
    form:Hide()
  end)
  function form:Paint()
    for _, b in ipairs(self.roles) do
      local on = self.state.roles[b.key]
      b.text:SetTextColor(on and C.goldHi[1] or C.text2[1], on and C.goldHi[2] or C.text2[2], on and C.goldHi[3] or C.text2[3])
    end
    for _, b in ipairs(self.classes) do
      local on = false
      for _, x in ipairs(self.state.classes) do
        on = on or x == b.key
      end
      b.text:SetTextColor(on and C.goldHi[1] or C.text2[1], on and C.goldHi[2] or C.text2[2], on and C.goldHi[3] or C.text2[3])
    end
  end
  function form:Open()
    local c = R.Charter() or R.NormalizeCharter({})
    self.state = { roles = { TANK = c.roles.TANK, HEALER = c.roles.HEALER, DPS = c.roles.DPS }, classes = {} }
    for _, x in ipairs(c.classes) do
      self.state.classes[#self.state.classes + 1] = x
    end
    self.open:SetValue(c.open == true, true)
    self.about:SetText(c.about)
    self.lang:SetText(c.lang ~= "" and c.lang or "Español")
    self.days:SetText(c.days)
    self.contact:SetText(c.contact or "")
    self.error:SetText("")
    self:Paint()
    self:Show()
  end
  return form
end

-- View ---------------------------------------------------------------------------------------------------------------
BG:RegisterView("recruit", {
  Build = function(f)
    f.hero = UI.Hero(f, 118)
    f.hero:SetPoint("TOPLEFT")
    f.hero:SetPoint("TOPRIGHT")

    -- Without a guild: search and join.
    local search = plate(f, "Buscar una hermandad")
    search:SetPoint("TOPLEFT", f.hero, "BOTTOMLEFT", PAD, -16)
    search:SetPoint("BOTTOM", 0, 18)
    f.searchPlate = search
    f.query = UI.EditBox(search, { width = 200, maxLetters = 40, placeholder = "Nombre exacto, por ejemplo C A Ñ A D A" })
    f.query:SetPoint("TOPLEFT", search.head, "BOTTOMLEFT", 0, -8)
    f.go = UI.Button(search, "Buscar", { primary = true, height = 26, width = 90 })
    f.go:SetPoint("TOPRIGHT", search.head, "BOTTOMRIGHT", 0, -8)
    f.query:SetPoint("RIGHT", f.go, "LEFT", -8, 0)
    f.go:SetScript("OnClick", function()
      local ok, w = R.Search(f.query:GetText())
      f.searchNote:SetText(ok and BG.colorize("Buscando… (el juego también abre su lista de /who; puedes cerrarla)", C.text3) or BG.colorize(why(w), C.warning))
    end)
    f.searchNote = UI.Text(search, 11, C.text3, { wrap = true })
    f.searchNote:SetPoint("TOPLEFT", f.query, "BOTTOMLEFT", 0, -6)
    f.searchNote:SetPoint("RIGHT", -16, 0)
    f.found = UI.List(search, 62, foundRow, fillFound)
    f.found:SetPoint("TOPLEFT", f.searchNote, "BOTTOMLEFT", 0, -10)
    f.found:SetPoint("BOTTOMRIGHT", -16, 14)

    local card = plate(f, "Su ficha")
    card:SetPoint("TOPLEFT", search, "TOPRIGHT", 18, 0)
    card:SetPoint("BOTTOMRIGHT", -PAD, 18)
    f.cardPlate = card
    f.cardText = UI.Text(card, 12, C.text, { wrap = true })
    f.cardText:SetPoint("TOPLEFT", card.head, "BOTTOMLEFT", 0, -8)
    f.cardText:SetPoint("RIGHT", -16, 0)
    f.cardText:SetSpacing(4)
    f.note = UI.EditBox(card, { width = 200, maxLetters = 140, placeholder = "Unas palabras para sus oficiales (opcional)" })
    f.note:SetPoint("BOTTOMLEFT", 16, 50)
    f.note:SetPoint("BOTTOMRIGHT", -16, 50)
    f.join = UI.Button(card, "Pedir entrar", { primary = true, height = 26, width = 140 })
    f.join:SetPoint("BOTTOMRIGHT", -16, 16)
    f.join:SetScript("OnClick", function()
      local ok, w = R.AskToJoin(f.note:GetText())
      f.joinNote:SetText(ok and BG.colorize("Enviada a " .. ok .. ". Te avisamos cuando llegue.", C.success) or BG.colorize(why(w), C.warning))
    end)
    f.joinNote = UI.Text(card, 11, C.text3, { wrap = true })
    f.joinNote:SetPoint("BOTTOMLEFT", 16, 20)
    f.joinNote:SetPoint("RIGHT", f.join, "LEFT", -10, 0)

    -- In a guild: its card, requests, recruiters.
    local mine = plate(f, "Vuestra ficha")
    mine:SetPoint("TOPLEFT", f.hero, "BOTTOMLEFT", PAD, -16)
    mine:SetPoint("BOTTOM", 0, 18)
    f.minePlate = mine
    f.edit = UI.Button(mine, "Editar ficha", { height = 24, width = 120 })
    f.edit:SetPoint("TOPRIGHT", -16, -10)
    f.edit:SetScript("OnClick", function()
      f.charterForm:Open()
    end)
    f.mineText = UI.Text(mine, 13, C.text, { wrap = true })
    f.mineText:SetPoint("TOPLEFT", mine.head, "BOTTOMLEFT", 0, -10)
    f.mineText:SetPoint("RIGHT", -16, 0)
    f.mineText:SetSpacing(5)
    f.mineHint = UI.Text(mine, 11, C.text3, { wrap = true })
    f.mineHint:SetPoint("BOTTOMLEFT", 16, 16)
    f.mineHint:SetPoint("RIGHT", -16, 0)

    local side = plate(f, "Quieren entrar")
    side:SetPoint("TOPLEFT", mine, "TOPRIGHT", 18, 0)
    side:SetPoint("BOTTOMRIGHT", -PAD, 18)
    f.side = side
    f.reqNote = UI.Text(side, 12, C.text3, { wrap = true })
    f.reqNote:SetPoint("TOPLEFT", side.head, "BOTTOMLEFT", 0, -6)
    f.reqNote:SetPoint("RIGHT", -16, 0)
    f.requests = UI.List(side, 64, requestRow, fillRequest)
    f.requests:SetPoint("TOPLEFT", f.reqNote, "BOTTOMLEFT", 0, -6)
    f.requests:SetPoint("RIGHT", -16, 0)
    f.requests:SetHeight(140)
    side.recHead = UI.Heading(side, "Quién trae más gente")
    side.recHead:SetPoint("TOPLEFT", f.requests, "BOTTOMLEFT", 0, -6)
    side.recHead:SetPoint("RIGHT", -16, 0)
    f.recruiters = UI.Text(side, 12, C.text2, { wrap = true })
    f.recruiters:SetPoint("TOPLEFT", side.recHead, "BOTTOMLEFT", 0, -6)
    f.recruiters:SetPoint("RIGHT", -16, 0)
    f.recruiters:SetSpacing(3)
    f.broughtLabel = UI.Text(side, 11, C.text3)
    f.broughtLabel:SetPoint("BOTTOMLEFT", 16, 48)
    f.broughtLabel:SetText("¿Quién te trajo a la hermandad?")
    f.brought = UI.EditBox(side, { width = 160, maxLetters = 40, placeholder = "Nombre y apellido" })
    f.brought:SetPoint("BOTTOMLEFT", 16, 16)
    f.broughtSave = UI.Button(side, "Guardar", { height = 26, width = 84 })
    f.broughtSave:SetPoint("BOTTOMRIGHT", -16, 16)
    f.broughtNone = UI.Button(side, "Nadie", { height = 26, width = 70 })
    f.broughtNone:SetPoint("RIGHT", f.broughtSave, "LEFT", -6, 0)
    f.brought:SetPoint("RIGHT", f.broughtNone, "LEFT", -8, 0)
    f.broughtSave:SetScript("OnClick", function()
      local ok, w = R.SetBroughtBy(f.brought:GetText())
      if not ok then
        BG:Notify("No se pudo", why(w), { kind = "warning" })
      end
    end)
    f.broughtNone:SetScript("OnClick", function()
      R.SetBroughtBy(nil)
    end)

    f.charterForm = buildCharterForm(f)
    f:SetScript("OnSizeChanged", function(self, w)
      local lw = math.floor((w - PAD * 2 - 18) * 0.52)
      self.searchPlate:SetWidth(lw)
      self.minePlate:SetWidth(lw)
    end)
  end,

  Refresh = function(f)
    local info = BG.Guild.info
    local inGuild = IsInGuild() and info ~= nil
    local me = Names.Me() or ""
    local org = inGuild and Store.IsOrganiser(me)
    local faction = info and info.faction or "ALLIANCE"
    f.hero:SetArt(BG.art[faction] or BG.art.ALLIANCE, 0.5)
    f.hero:SetIcon(BG.file("Interface\\Icons\\INV_Misc_GroupNeedMore", "Interface\\Icons\\INV_Misc_Note_02"))
    for _, w in ipairs({ f.searchPlate, f.cardPlate }) do
      w:SetShown(not inGuild)
    end
    for _, w in ipairs({ f.minePlate, f.side }) do
      w:SetShown(inGuild)
    end

    if not inGuild then
      f.hero.title:SetText("Únete a una hermandad")
      f.hero.sub:SetText("Escribe el nombre de la hermandad, mira su ficha y pide entrar. Sus oficiales lo verán y te invitarán desde el juego.")
      local found = R.found or {}
      f.found:SetItems(found)
      if R.searched and #found == 0 then
        f.searchNote:SetText(R.CanSearch() and ("Nadie de «" .. R.searched .. "» conectado ahora, o el nombre no es exacto.") or f.searchNote:GetText())
      end
      local card = R.card
      if card then
        f.cardPlate.head.title:SetText("Ficha de " .. (card.guild or "?"))
        f.cardText:SetText((card.has and charterText(card.charter) or "Esta hermandad aún no tiene ficha.")
          .. "\n" .. BG.colorize(card.total .. " miembros, " .. card.online .. " conectados.", C.text3))
      else
        f.cardPlate.head.title:SetText("Su ficha")
        f.cardText:SetText(BG.colorize(R.cardAsked and ("Pidiendo la ficha a " .. R.cardAsked .. "… (si no tiene BlazonGuild no contestará: prueba con otra persona)")
          or "Busca una hermandad y pulsa «Ver su ficha» en alguien suyo.", C.text3))
      end
      f.join:SetShown(card ~= nil or #found > 0)
      return
    end

    local c = R.Charter()
    f.hero.title:SetText("Reclutamiento")
    local doors = BG.AllianceActs and BG.Alliance.Doc() and BG.AllianceActs.Doors()
    f.hero.sub:SetText(doors and string.format("Vuestra ficha y quién pide entrar. La alianza manda ahora a los nuevos a «%s», hasta las %s.", doors.name, UI.FormatTime(doors["until"]))
      or "Vuestra ficha pública, quién pide entrar y quién trae más gente. Quien no tiene hermandad os encuentra por el nombre y os pide entrar desde el juego.")
    f.mineText:SetText(charterText(c, info.name))
    f.edit:SetShown(org)
    f.mineHint:SetText("Quien busca hermandad la ve al pedirla a cualquiera de vosotros con BlazonGuild." .. (org and " La escriben los oficiales." or ""))
    local reqs = R.Requests()
    f.requests:SetItems(org and reqs or {})
    f.reqNote:SetText(org and (#reqs == 0 and "Nadie ahora. Las peticiones llegan mientras estás conectado; «Invitar» manda la invitación del juego." or "")
      or (#reqs > 0 and (#reqs .. (#reqs == 1 and " persona quiere" or " personas quieren") .. " entrar: lo ven los oficiales.") or "Nadie ahora. Las peticiones las ven los oficiales."))
    local lines = {}
    for i, e in ipairs(R.Recruiters(8)) do
      lines[#lines + 1] = i .. ". " .. e.name .. ": " .. e.n .. (e.n == 1 and " persona" or " personas")
    end
    f.recruiters:SetText(#lines > 0 and table.concat(lines, "\n") or "Aún nadie. Cuando alguien entra, dice quién le trajo.")
    local by, answered = R.WhoBrought(me)
    f.broughtLabel:SetText(answered and ("Te trajo: " .. (by or "nadie") .. ". Puedes cambiarlo.") or "¿Quién te trajo a la hermandad?")
  end,
})

BG:On("BG_RECRUIT_CHANGED", function()
  BG:RefreshView("recruit")
end)
BG:On("BG_STORE_CHANGED", function(name)
  if name == "charter" or name == "recruits" then
    BG:RefreshView("recruit")
  end
end)
