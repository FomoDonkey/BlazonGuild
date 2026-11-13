-- Artesanía y botín: three tabs. Artesanos (the crafters' board, "who can make this?", whisper or order with a
-- click, and your own professions to publish); Encargos (orders and the crafters' ranking); Botín (the loot
-- notes the organisers write, and optional points by hand).
local _, BG = ...
local UI, C = BG.UI, BG.color
local Crafts, Names, Store = BG.Crafts, BG.Names, BG.Store

local PAD = 24

local function why(w)
  return ({ permiso = "Solo los organizadores pueden hacerlo.", ["no es de tu hermandad"] = "Esa persona no es de tu hermandad.", ["no existe"] = "Ya no existe.",
    datos = "Escribe qué objeto es.", consent = "Acepta antes la privacidad (/bg privacidad).", ["número"] = "Escribe un número." })[w] or ("No se pudo (" .. tostring(w) .. ").")
end

local function itemText(d)
  local name = d.item and Crafts.ItemName(d.item) or d.what
  return (d.qty and d.qty > 1 and (d.qty .. "x ") or "") .. (name or d.what or "?")
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

-- Two plates side by side inside a tab.
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
  tab.left, tab.right = left, right
  return left, right
end

-- Artesanos ----------------------------------------------------------------------------------------------------
local function crafterCard(list, f)
  local c = UI.Card(list)
  c.order = UI.CardButton(c, "Pedir", { height = 22, width = 64 })
  c.order:SetPoint("BOTTOMRIGHT", -10, 8)
  c.order:SetScript("OnClick", function()
    if c.who then
      f.orderForm:Open(c.who)
    end
  end)
  c.tell = UI.CardButton(c, "Susurrar", { height = 22, width = 84 })
  c.tell:SetPoint("RIGHT", c.order, "LEFT", -6, 0)
  c.tell:SetScript("OnClick", function()
    if c.who then
      Crafts.Whisper(c.who)
    end
  end)
  c.right:ClearAllPoints()
  c.right:SetPoint("TOPRIGHT", -12, -10)
  return c
end

local function fillCrafter(c, e)
  c.who = e.name
  c.key = e.name .. (e.prof or "")
  c:SetHeight(64)
  c.icon:SetTexture("Interface\\Icons\\Trade_BlackSmithing")
  local col = BG.classColor(e.class)
  c.title:SetText(BG.colorize(e.name, col))
  if e.items then
    c.sub:SetText(e.prof .. ": " .. table.concat(e.items, ", ", 1, math.min(4, #e.items)) .. (#e.items > 4 and (" y " .. (#e.items - 4) .. " más") or ""))
    c.detail = { "Sabe hacer: " .. table.concat(e.items, ", ") .. "." }
  else
    local parts = {}
    for _, p in ipairs(e.profs) do
      parts[#parts + 1] = p.p .. " " .. p.r .. "/" .. p.m .. " (" .. (#p.it + #p.sp) .. ")"
    end
    c.sub:SetText(table.concat(parts, ", "))
    c.detail = { "Busca un objeto arriba para ver qué sabe hacer, o pulsa «Pedir» para hacerle un encargo." }
  end
  c.right:SetText(e.online and BG.colorize("conectado", C.success) or BG.colorize("desconectado", C.text3))
  c.right2:SetText("")
  c.tell:SetShown(not Names.IsMe(e.name))
  c.order:SetShown(not Names.IsMe(e.name))
end

local function profRow(list)
  local c = UI.Card(list)
  c.toggle = UI.CardButton(c, "Publicar", { height = 22, width = 140 })
  c.toggle:SetPoint("BOTTOMRIGHT", -10, 8)
  c.toggle:SetScript("OnClick", function()
    if c.prof then
      Crafts.SetShare(c.prof.k, not c.prof.shared)
    end
  end)
  return c
end

local function fillProf(c, p)
  c.prof = p
  c:SetHeight(60)
  c.icon:SetTexture("Interface\\Icons\\INV_Misc_Note_02")
  c.title:SetText(p.p .. "  " .. BG.colorize(p.r .. "/" .. p.m, C.text3))
  c.sub:SetText((#p.it + #p.sp) .. " recetas")
  c.right:SetText(p.shared and BG.colorize("publicada", C.success) or BG.colorize("sin publicar", C.text3))
  c.right2:SetText("")
  c.toggle.text:SetText(p.shared and "Dejar de publicar" or "Publicar")
end

local function buildCrafters(tab, f)
  local left, right = columns(tab, "Artesanos de la hermandad", "Tus profesiones")
  f.search = UI.EditBox(left, { width = 200, maxLetters = 60, placeholder = "¿Quién sabe hacer…? Escribe un objeto" })
  f.search:SetPoint("TOPLEFT", left.head, "BOTTOMLEFT", 0, -8)
  f.search:SetPoint("TOPRIGHT", left.head, "BOTTOMRIGHT", 0, -8)
  f.search.edit:HookScript("OnTextChanged", function()
    BG:RefreshView("crafts")
  end)
  f.board = UI.List(left, 70, function(list)
    return crafterCard(list, f)
  end, fillCrafter)
  f.board:SetPoint("TOPLEFT", f.search, "BOTTOMLEFT", 0, -10)
  f.board:SetPoint("BOTTOMRIGHT", -16, 14)
  f.boardEmpty = UI.Text(left, 12, C.text3, { wrap = true })
  f.boardEmpty:SetPoint("TOPLEFT", f.search, "BOTTOMLEFT", 0, -14)
  f.boardEmpty:SetPoint("RIGHT", -16, 0)

  right.text = UI.Text(right, 12, C.text2, { wrap = true })
  right.text:SetPoint("TOPLEFT", right.head, "BOTTOMLEFT", 0, -6)
  right.text:SetPoint("RIGHT", -16, 0)
  right.text:SetSpacing(3)
  f.profs = UI.List(right, 66, profRow, fillProf)
  f.profs:SetPoint("TOPLEFT", right.text, "BOTTOMLEFT", 0, -10)
  f.profs:SetPoint("BOTTOMRIGHT", -16, 14)
end

-- Encargos -------------------------------------------------------------------------------------------------------
local function orderCard(list)
  local c = UI.Card(list)
  c.a = UI.CardButton(c, "", { height = 22, width = 96 })
  c.a:SetPoint("BOTTOMRIGHT", -10, 8)
  c.b = UI.CardButton(c, "", { height = 22, width = 84 })
  c.b:SetPoint("RIGHT", c.a, "LEFT", -6, 0)
  local function act(button)
    local fn = button.fn
    if fn and c.order then
      local ok, w = fn(c.order.id)
      if not ok then
        BG:Notify("No se pudo", why(w), { kind = "warning" })
      end
      BG:RefreshView("crafts")
    end
  end
  c.a:SetScript("OnClick", act)
  c.b:SetScript("OnClick", act)
  c.right:ClearAllPoints()
  c.right:SetPoint("TOPRIGHT", -12, -10)
  return c
end

local STATE_COLOR = { OPEN = "gold", TAKEN = "warning", DONE = "success", CONFIRMED = "text3" }

local function fillOrder(c, r)
  c.order = r
  c:SetHeight(64)
  local d, me = r.d, Names.Me() or ""
  c.icon:SetTexture("Interface\\Icons\\INV_Crate_04")
  c.title:SetText(itemText(d) .. "  " .. BG.colorize(Crafts.ORDER_STATES[d.st], C[STATE_COLOR[d.st]] or C.text3))
  c.key = r.id
  c.sub:SetText("Lo pide " .. (d.by or "?") .. ". " .. (d.crafter and ("Lo hace " .. d.crafter .. ".") or "Para quien sepa hacerlo.") .. (d.note and d.note ~= "" and (" " .. d.note) or ""))
  c.detail = { "Qué: " .. itemText(d), "Estado: " .. Crafts.ORDER_STATES[d.st] .. ", desde el " .. UI.FormatDate(r.at, true) .. "." }
  if d.note and d.note ~= "" then
    table.insert(c.detail, 1, "Nota: " .. d.note)
  end
  c.right:SetText(UI.FormatDate(r.at))
  c.right2:SetText("")
  local mineAsk, mineCraft = Names.Same(d.by, me), Names.Same(d.crafter, me)
  local a, b
  if mineAsk then
    if d.st == "DONE" then
      a = { "Recibido", Crafts.Confirm }
    elseif d.st == "OPEN" or d.st == "TAKEN" then
      a = { "Cancelar", Crafts.CancelOrder }
    end
  elseif mineCraft and d.st == "TAKEN" then
    a, b = { "Hecho", Crafts.Done }, { "Devolver", Crafts.Release }
  elseif d.st == "OPEN" and (not d.crafter or mineCraft) then
    a = { "Lo hago", Crafts.Take }
  end
  c.a:SetShown(a ~= nil)
  c.b:SetShown(b ~= nil)
  if a then
    c.a.text:SetText(a[1])
    c.a.fn = a[2]
  end
  if b then
    c.b.text:SetText(b[1])
    c.b.fn = b[2]
  end
end

local function buildOrders(tab, f)
  local left, right = columns(tab, "Encargos", "Mejores artesanos")
  f.newOrder = UI.Button(left, "Nuevo encargo", { primary = true, height = 24, width = 130 })
  f.newOrder:SetPoint("TOPRIGHT", -16, -10)
  f.newOrder:SetScript("OnClick", function()
    f.orderForm:Open(nil)
  end)
  f.orders = UI.List(left, 70, orderCard, fillOrder)
  f.orders:SetPoint("TOPLEFT", left.head, "BOTTOMLEFT", 0, -10)
  f.orders:SetPoint("BOTTOMRIGHT", -16, 14)
  f.ordersEmpty = UI.Text(left, 12, C.text3, { wrap = true })
  f.ordersEmpty:SetPoint("TOPLEFT", left.head, "BOTTOMLEFT", 0, -14)
  f.ordersEmpty:SetPoint("RIGHT", -16, 0)
  f.ordersEmpty:SetText("No hay encargos. Pide un objeto a un artesano (o a quien sepa hacerlo): te avisamos cuando lo tome y cuando esté hecho.")
  right.text = UI.Text(right, 12, C.text2, { wrap = true })
  right.text:SetPoint("TOPLEFT", right.head, "BOTTOMLEFT", 0, -6)
  right.text:SetPoint("RIGHT", -16, 0)
  right.text:SetSpacing(4)
  f.ranking = right.text
end

-- Botín ------------------------------------------------------------------------------------------------------------
local function noteCard(list)
  local c = UI.Card(list)
  c.del = UI.CardButton(c, "Borrar", { height = 22, width = 70 })
  c.del:SetPoint("BOTTOMRIGHT", -10, 8)
  c.del:SetScript("OnClick", function()
    if c.note then
      Crafts.RemoveNote(c.note.id)
    end
  end)
  c.right:ClearAllPoints()
  c.right:SetPoint("TOPRIGHT", -12, -10)
  return c
end

local function fillNote(c, r)
  c.note = r
  c.key = r.id
  c:SetHeight(60)
  c.detail = { "Anotado por " .. (r.by or "?") .. " el " .. UI.FormatDate(r.at, true) .. "." }
  c.icon:SetTexture("Interface\\Icons\\INV_Misc_Bag_10")
  local m = BG.Guild.Find(r.d.to)
  c.title:SetText(BG.TF("%s para %s", itemText(r.d), BG.colorize(r.d.to, BG.classColor(m and m.classFile))))
  c.sub:SetText((r.d.why and r.d.why ~= "" and r.d.why or "Sin motivo anotado") .. (r.d.raid and r.d.raid ~= "" and (" (" .. r.d.raid .. ")") or ""))
  c.right:SetText(UI.FormatDate(r.at) .. ", " .. (r.by or "?"))
  c.right2:SetText("")
  c.del:SetShown(Store.IsOrganiser(Names.Me() or ""))
end

local function buildLoot(tab, f)
  local left, right = columns(tab, "Notas de botín", "Puntos (opcional)")
  f.newNote = UI.Button(left, "Anotar", { primary = true, height = 24, width = 90 })
  f.newNote:SetPoint("TOPRIGHT", -16, -10)
  f.newNote:SetScript("OnClick", function()
    f.noteForm:Open()
  end)
  f.lootFilter = UI.EditBox(left, { width = 200, maxLetters = 40, placeholder = "Buscar por persona u objeto" })
  f.lootFilter:SetPoint("TOPLEFT", left.head, "BOTTOMLEFT", 0, -8)
  f.lootFilter:SetPoint("TOPRIGHT", left.head, "BOTTOMRIGHT", 0, -8)
  f.lootFilter.edit:HookScript("OnTextChanged", function()
    BG:RefreshView("crafts")
  end)
  f.notes = UI.List(left, 66, noteCard, fillNote)
  f.notes:SetPoint("TOPLEFT", f.lootFilter, "BOTTOMLEFT", 0, -10)
  f.notes:SetPoint("BOTTOMRIGHT", -16, 14)
  f.notesEmpty = UI.Text(left, 12, C.text3, { wrap = true })
  f.notesEmpty:SetPoint("TOPLEFT", f.lootFilter, "BOTTOMLEFT", 0, -14)
  f.notesEmpty:SetPoint("RIGHT", -16, 0)

  right.text = UI.Text(right, 12, C.text2, { wrap = true })
  right.text:SetPoint("TOPLEFT", right.head, "BOTTOMLEFT", 0, -6)
  right.text:SetPoint("RIGHT", -16, 0)
  right.text:SetSpacing(3)
  right.text:SetText("Si tu hermandad usa puntos de botín, los organizadores los apuntan a mano: nada los suma ni los resta solo. Sin pujas ni oro.")
  f.pointsList = UI.Text(right, 12, C.text, { wrap = true })
  f.pointsList:SetPoint("TOPLEFT", right.text, "BOTTOMLEFT", 0, -10)
  f.pointsList:SetPoint("RIGHT", -16, 0)
  f.pointsList:SetSpacing(4)
  f.pointsName = UI.EditBox(right, { width = 150, maxLetters = 40, placeholder = "Nombre y apellido" })
  f.pointsName:SetPoint("BOTTOMLEFT", 16, 16)
  f.pointsSet = UI.Button(right, "Poner", { height = 26, width = 70 })
  f.pointsSet:SetPoint("BOTTOMRIGHT", -16, 16)
  f.pointsValue = UI.EditBox(right, { width = 70, maxLetters = 6, placeholder = "Puntos" })
  f.pointsValue:SetPoint("RIGHT", f.pointsSet, "LEFT", -6, 0)
  f.pointsName:SetPoint("RIGHT", f.pointsValue, "LEFT", -6, 0)
  f.pointsSet:SetScript("OnClick", function()
    local ok, w = Crafts.SetPoints(f.pointsName:GetText(), f.pointsValue:GetText())
    if ok then
      f.pointsName:SetText("")
      f.pointsValue:SetText("")
    else
      BG:Notify("No se pudo", why(w), { kind = "warning" })
    end
  end)
end

-- Forms ------------------------------------------------------------------------------------------------------------
local function buildOrderForm(f)
  local form = overlay(f, "Nuevo encargo")
  local l1 = form:Label("Qué objeto (Mayús+clic en el objeto, o arrástralo aquí)")
  form.what = UI.EditBox(form, { width = 360, maxLetters = 200, placeholder = "Por ejemplo: Poción de sanación superior" })
  form.what:SetPoint("TOPLEFT", l1, "BOTTOMLEFT", 0, -4)
  UI.AcceptLinks(form.what)
  local l2 = form:Label("Cuántos", form.what, -12)
  form.qty = UI.Stepper(form, "", 1, 200, { width = 90, value = 1 })
  form.qty:SetPoint("TOPLEFT", l2, "BOTTOMLEFT", 0, -4)
  local l3 = form:Label("A quién (vacío: a quien sepa hacerlo)", form.qty, -12)
  form.crafter = UI.EditBox(form, { width = 260, maxLetters = 40, placeholder = "Nombre y apellido" })
  form.crafter:SetPoint("TOPLEFT", l3, "BOTTOMLEFT", 0, -4)
  local l4 = form:Label("Nota (opcional)", form.crafter, -12)
  form.note = UI.EditBox(form, { width = 420, maxLetters = 140, placeholder = "Por ejemplo: pongo yo los materiales" })
  form.note:SetPoint("TOPLEFT", l4, "BOTTOMLEFT", 0, -4)
  form.save = UI.Button(form, "Pedir", { primary = true, height = 30, width = 120 })
  form.save:SetPoint("RIGHT", form.back, "LEFT", -10, 0)
  form.save:SetScript("OnClick", function()
    local r, w = Crafts.Order({ what = form.what:GetText(), qty = form.qty:GetValue(), crafter = form.crafter:GetText(), note = form.note:GetText() })
    if not r then
      form.error:SetText(why(w))
      return
    end
    BG.Sound("IG_QUEST_LIST_COMPLETE")
    form:Hide()
    f.tab = "orders"
    BG:RefreshView("crafts")
  end)
  function form:Open(crafter)
    self.error:SetText("")
    self.what:SetText("")
    self.note:SetText("")
    self.qty:SetValue(1, true)
    self.crafter:SetText(crafter or "")
    self:Show()
  end
  return form
end

local function buildNoteForm(f)
  local form = overlay(f, "Anotar botín")
  local l1 = form:Label("Qué objeto (Mayús+clic en el objeto, o arrástralo aquí)")
  form.what = UI.EditBox(form, { width = 360, maxLetters = 200, placeholder = "Por ejemplo: Cinturón del asesino nocturno" })
  form.what:SetPoint("TOPLEFT", l1, "BOTTOMLEFT", 0, -4)
  UI.AcceptLinks(form.what)
  local l2 = form:Label("Para quién", form.what, -12)
  form.to = UI.EditBox(form, { width = 260, maxLetters = 40, placeholder = "Nombre y apellido" })
  form.to:SetPoint("TOPLEFT", l2, "BOTTOMLEFT", 0, -4)
  local l3 = form:Label("Por qué (lo que decidisteis, para la próxima vez)", form.to, -12)
  form.why = UI.EditBox(form, { width = 460, maxLetters = 160, placeholder = "Por ejemplo: pasó de los guantes; Bob tiene el siguiente" })
  form.why:SetPoint("TOPLEFT", l3, "BOTTOMLEFT", 0, -4)
  local l4 = form:Label("Banda (opcional)", form.why, -12)
  form.raid = UI.EditBox(form, { width = 260, maxLetters = 40, placeholder = "Por ejemplo: Núcleo de Magma, 14/11" })
  form.raid:SetPoint("TOPLEFT", l4, "BOTTOMLEFT", 0, -4)
  form.save = UI.Button(form, "Guardar", { primary = true, height = 30, width = 120 })
  form.save:SetPoint("RIGHT", form.back, "LEFT", -10, 0)
  form.save:SetScript("OnClick", function()
    local r, w = Crafts.Note({ what = form.what:GetText(), to = form.to:GetText(), why = form.why:GetText(), raid = form.raid:GetText() })
    if not r then
      form.error:SetText(why(w == "datos" and "datos" or w))
      return
    end
    form:Hide()
    BG:RefreshView("crafts")
  end)
  function form:Open()
    self.error:SetText("")
    for _, b in ipairs({ self.what, self.to, self.why, self.raid }) do
      b:SetText("")
    end
    self:Show()
  end
  return form
end

-- View ---------------------------------------------------------------------------------------------------------------
local TABS = { { value = "crafters", label = "Quién fabrica qué" }, { value = "orders", label = "Encargos" }, { value = "loot", label = "Botín de banda" } }

BG:RegisterView("crafts", {
  Build = function(f)
    f.hero = UI.Hero(f, 108)
    f.hero:SetPoint("TOPLEFT")
    f.hero:SetPoint("TOPRIGHT")
    f.tab = "crafters"
    f.tabs = UI.Segmented(f, TABS, { itemWidth = 140, onChange = function(v)
      f.tab = v
      BG:RefreshView("crafts")
    end })
    f.tabs:SetPoint("TOPLEFT", f.hero, "BOTTOMLEFT", PAD, -12)
    f.pages = {}
    for _, t in ipairs(TABS) do
      local page = CreateFrame("Frame", nil, f)
      page:SetPoint("TOPLEFT", f.tabs, "BOTTOMLEFT", 0, -12)
      page:SetPoint("BOTTOMRIGHT", -PAD, 18)
      f.pages[t.value] = page
    end
    buildCrafters(f.pages.crafters, f)
    buildOrders(f.pages.orders, f)
    buildLoot(f.pages.loot, f)
    f.orderForm = buildOrderForm(f)
    f.noteForm = buildNoteForm(f)
    f:SetScript("OnSizeChanged", function(self, w)
      local lw = math.floor((w - PAD * 2 - 18) * 0.58)
      for _, page in pairs(self.pages) do
        page.left:SetWidth(lw)
      end
    end)
  end,

  Refresh = function(f)
    local info = BG.Guild.info
    local me = Names.Me() or ""
    local org = Store.IsOrganiser(me)
    local faction = info and info.faction or "ALLIANCE"
    f.hero:SetArt(BG.art[faction] or BG.art.ALLIANCE, 0.5)
    f.hero:SetIcon(BG.file("Interface\\Icons\\Trade_BlackSmithing", "Interface\\Icons\\INV_Misc_Note_02"))
    local board = Crafts.Board()
    local open = 0
    for _, r in ipairs(Crafts.Orders()) do
      if r.d.st == "OPEN" or r.d.st == "TAKEN" then
        open = open + 1
      end
    end
    f.hero.title:SetText("Artesanía y botín")
    f.hero.sub:SetText("Encuentra quién te fabrica algo, pídeselo y lleva el botín de las bandas. "
      .. string.format("Ahora: %d %s y %d %s.", #board, #board == 1 and "artesano" or "artesanos", open, open == 1 and "encargo abierto" or "encargos abiertos"))
    f.tabs:SetValue(f.tab, true)
    for key, page in pairs(f.pages) do
      page:SetShown(key == f.tab)
    end

    if f.tab == "crafters" then
      local q = f.search:GetText() or ""
      local items = q ~= "" and Crafts.Search(q) or board
      f.board:SetItems(items)
      f.boardEmpty:SetShown(#items == 0)
      f.boardEmpty:SetText(q ~= "" and ("Nadie de la lista sabe hacer «" .. q .. "». En «Encargos» puedes pedirlo a quien sepa.")
        or "Aún no hay nadie. Para salir aquí, cada uno abre la ventana de su profesión en el juego y dice «Publicar». Escribe arriba un objeto para buscar quién lo fabrica.")
      local profs = Crafts.MyProfessions()
      f.pages.crafters.right.text:SetText(#profs == 0 and "Aún no hemos visto ninguna. En el juego, abre la ventana de tu profesión (por ejemplo, Herrería o Alquimia): BlazonGuild te preguntará si quieres publicarla. Solo la ve tu hermandad."
        or "Lo que publicas lo ve tu hermandad: quién sabe hacer cada objeto, para susurrarte o hacerte un encargo. Se actualiza al abrir la profesión.")
      f.profs:SetItems(profs)
    elseif f.tab == "orders" then
      local list = Crafts.Orders()
      f.orders:SetItems(list)
      f.ordersEmpty:SetShown(#list == 0)
      local lines = {}
      for i, e in ipairs(Crafts.Ranking(10)) do
        lines[#lines + 1] = BG.TF(e.n == 1 and "%d. %s: %d objeto" or "%d. %s: %d objetos", i, e.name, e.n)
      end
      f.ranking:SetText(#lines > 0 and BG.TF("Objetos entregados y confirmados en los últimos 90 días.\n%s", table.concat(lines, "\n"))
        or "Cuando alguien confirma que recibió su encargo, cuenta para el artesano que lo hizo. Aún no hay ninguno.")
    else
      local list = Crafts.Notes(f.lootFilter:GetText())
      f.notes:SetItems(list)
      f.newNote:SetShown(org)
      f.notesEmpty:SetShown(#list == 0)
      f.notesEmpty:SetText(org and "Sin notas. Apunta a quién se dio cada objeto y por qué: la próxima banda empieza de lo decidido."
        or "Sin notas. Los organizadores apuntan aquí a quién se dio cada objeto y por qué.")
      local pts = {}
      for _, r in ipairs(Crafts.Points()) do
        pts[#pts + 1] = r.id .. ": " .. r.d.p
      end
      f.pointsList:SetText(#pts > 0 and table.concat(pts, "\n", 1, math.min(12, #pts)) or BG.colorize("Nadie tiene puntos apuntados.", C.text3))
      for _, w in ipairs({ f.pointsName, f.pointsValue, f.pointsSet }) do
        w:SetShown(org)
      end
    end
  end,
})

BG:On("BG_CRAFTS_CHANGED", function()
  BG:RefreshView("crafts")
end)
