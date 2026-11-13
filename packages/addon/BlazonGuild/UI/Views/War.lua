-- Sala de guerra: the guild's operations (when, where, which squads, who goes; its leader starts it and writes
-- the report), its squads (a leader and a few members, with their own chat) and the latest reports. Organisers
-- and squad leaders plan operations; organisers make squads; every member answers.
local _, BG = ...
local UI, C = BG.UI, BG.color
local War, Names, Store = BG.War, BG.Names, BG.Store

local PAD = 24

local function why(w, extra)
  return ({ permiso = "No tienes permiso para eso.", jefe = "El jefe tiene que ser de tu hermandad.", ["no es de tu hermandad"] = "Esa persona no es de tu hermandad.",
    ["ya está"] = "Ya está en esta escuadra.", llena = "La escuadra está llena (15 con el jefe).", ["en otra"] = "Ya está en la escuadra «" .. tostring(extra) .. "».",
    datos = "Falta el nombre o el título.", consent = "Acepta antes la privacidad (/bg privacidad).", ["no existe"] = "Ya no existe." })[w]
    or ("No se pudo (" .. tostring(w) .. ").")
end

local function openChat(channel)
  BG.db.settings.chatChannel = channel
  BG:ShowView("chat")
  local f = BG.window and BG.window.viewFrames.chat
  if f and f.select then
    f.select(channel)
  end
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
  form.error:SetWidth(320)
  form.back = UI.Button(form, "Volver", { height = 30, width = 100 })
  form.back:SetPoint("BOTTOMRIGHT", -22, 18)
  form.back:SetScript("OnClick", function()
    form:Hide()
    BG:RefreshView("war")
  end)
  return form
end

-- Operation form -----------------------------------------------------------------------------------------------
local function buildOpForm(f)
  local form = overlay(f, "Nueva operación")
  local lTitle = form:Label("Qué se hace")
  form.title = UI.EditBox(form, { width = 330, maxLetters = 60, placeholder = "Por ejemplo: Defensa del Molino de Tarren" })
  form.title:SetPoint("TOPLEFT", lTitle, "BOTTOMLEFT", 0, -4)
  form.kind = UI.Picker(form, { width = 120 })
  form.kind:SetPoint("LEFT", form.title, "RIGHT", 10, 0)
  local kinds = {}
  for _, k in ipairs(War.KINDS) do
    kinds[#kinds + 1] = { value = k.key, label = k.name }
  end
  form.kind:SetOptions(kinds)
  local lDay = form:Label("Día y hora", form.title, -12)
  form.day = UI.Picker(form, { width = 170, menuWidth = 260 })
  form.day:SetPoint("TOPLEFT", lDay, "BOTTOMLEFT", 0, -4)
  form.hour = UI.Picker(form, { width = 70 })
  form.hour:SetPoint("LEFT", form.day, "RIGHT", 10, 0)
  form.hour:SetOptions(UI.TimeOptions(8, 23))
  local lPlace = form:Label("Dónde (opcional)", form.day, -12)
  form.place = UI.EditBox(form, { width = 250, maxLetters = 40, placeholder = "Por ejemplo: Laderas de Trabalomas" })
  form.place:SetPoint("TOPLEFT", lPlace, "BOTTOMLEFT", 0, -4)
  local lSquad = form:Label("Quién va", form.place, -12)
  form.squad = UI.Picker(form, { width = 250 })
  form.squad:SetPoint("TOPLEFT", lSquad, "BOTTOMLEFT", 0, -4)
  local lLeader = form:Label("Quién la dirige", form.squad, -12)
  form.leader = UI.EditBox(form, { width = 250, maxLetters = 40, placeholder = "Nombre y apellido" })
  form.leader:SetPoint("TOPLEFT", lLeader, "BOTTOMLEFT", 0, -4)
  local lNote = form:Label("Nota (opcional)", form.leader, -12)
  form.note = UI.EditBox(form, { width = 460, maxLetters = 160, placeholder = "Por ejemplo: venid con monturas y vendas" })
  form.note:SetPoint("TOPLEFT", lNote, "BOTTOMLEFT", 0, -4)

  form.save = UI.Button(form, "Planear", { primary = true, height = 30, width = 140 })
  form.save:SetPoint("RIGHT", form.back, "LEFT", -10, 0)
  form.cancelOp = UI.Button(form, "Cancelar operación", { height = 30, width = 160 })
  form.cancelOp:SetPoint("RIGHT", form.save, "LEFT", -10, 0)
  form.cancelOp:SetScript("OnClick", function()
    local id = form.editing
    BG.UI.Dialog({
      title = "Cancelar la operación",
      items = { "Avisamos a todos los llamados de que no se hace." },
      primary = { label = "Cancelarla", fn = function()
        War.Cancel(id)
        form:Hide()
        BG:RefreshView("war")
      end },
      secondary = { label = "Volver" },
    })
  end)
  form.save:SetScript("OnClick", function()
    local day, minutes = form.day:GetValue(), form.hour:GetValue()
    if not day or not minutes then
      form.error:SetText("Elige el día y la hora.")
      return
    end
    local squad = form.squad:GetValue()
    local r, w = War.SaveOp(form.editing, {
      title = form.title:GetText(), kind = form.kind:GetValue(), start = day + minutes, place = form.place:GetText(), note = form.note:GetText(),
      leader = form.leader:GetText() ~= "" and form.leader:GetText() or nil, squads = (squad and squad ~= "ALL" and squad ~= "ALLY") and { squad } or {},
      ally = squad == "ALLY" or nil,
    })
    if not r then
      form.error:SetText(why(w == "datos" and "datos" or w))
      return
    end
    BG.Sound("IG_QUEST_LIST_COMPLETE")
    form:Hide()
    BG:RefreshView("war")
  end)

  function form:Open(op)
    self.editing = op and op.id or nil
    self.heading.title:SetText(op and "Editar operación" or "Nueva operación")
    self.save.text:SetText(op and "Guardar" or "Planear")
    self.cancelOp:SetShown(op ~= nil and op.d.status ~= "CANCELLED" and op.d.status ~= "DONE")
    self.error:SetText("")
    self.day:SetOptions(UI.DayOptions(21))
    local squads = { { value = "ALL", label = "Toda la hermandad" } }
    local ally = op and op.d.ally
    if ally or (not op and BG.AllianceActs and BG.AllianceActs.MayLead()) then
      squads[#squads + 1] = { value = "ALLY", label = "Toda la alianza" }
    end
    if not ally then
      for _, sq in ipairs(War.Squads()) do
        squads[#squads + 1] = { value = sq.id, label = "Escuadra «" .. sq.d.name .. "»" }
      end
    end
    self.squad:SetOptions(squads)
    local d = op and op.d
    self.title:SetText(d and d.title or "")
    self.kind:SetValue(d and d.kind or "PVP", true)
    self.place:SetText(d and d.place or "")
    self.note:SetText(d and d.note or "")
    self.leader:SetText(d and d.leader or (Names.Me() or ""))
    self.squad:SetValue(ally and "ALLY" or d and d.squads[1] or (War.LeadsSquad(Names.Me() or "") and War.LeadsSquad(Names.Me()).id) or "ALL", true)
    local start = d and d.start or (time() + 3600)
    local t = date("*t", start)
    local dayStart = time({ year = t.year, month = t.month, day = t.day, hour = 0 })
    self.day:SetValue(dayStart, true)
    self.hour:SetValue((t.hour * 60 + t.min - t.min % 30) * 60, true)
    self:Show()
  end
  return form
end

-- Report form -----------------------------------------------------------------------------------------------------
local function buildReportForm(f)
  local form = overlay(f, "Parte de la operación")
  form.what = UI.Text(form, 13, C.text, { wrap = true })
  form.what:SetPoint("TOPLEFT", form.heading, "BOTTOMLEFT", 0, -12)
  form.what:SetPoint("RIGHT", -22, 0)
  local lRes = form:Label("Cómo fue", form.what, -14)
  form.result = UI.Picker(form, { width = 160 })
  form.result:SetPoint("TOPLEFT", lRes, "BOTTOMLEFT", 0, -4)
  form.result:SetOptions({ { value = "WIN", label = "Victoria" }, { value = "LOSS", label = "Derrota" }, { value = "DRAW", label = "Empate" }, { value = "NONE", label = "Sin combate" } })
  local lNote = form:Label("Qué pasó (opcional)", form.result, -12)
  form.note = UI.EditBox(form, { width = 460, maxLetters = 300, placeholder = "Por ejemplo: aguantamos el puente hasta que llegaron refuerzos" })
  form.note:SetPoint("TOPLEFT", lNote, "BOTTOMLEFT", 0, -4)
  form.present = UI.Text(form, 12, C.text2, { wrap = true })
  form.present:SetPoint("TOPLEFT", form.note, "BOTTOMLEFT", 0, -14)
  form.present:SetPoint("RIGHT", -22, 0)
  form.save = UI.Button(form, "Terminar y guardar el parte", { primary = true, height = 30, width = 220 })
  form.save:SetPoint("RIGHT", form.back, "LEFT", -10, 0)
  form.save:SetScript("OnClick", function()
    local r, w = War.Finish(form.op, form.result:GetValue(), form.note:GetText())
    if not r then
      form.error:SetText(why(w))
      return
    end
    BG.Sound("IG_QUEST_LIST_COMPLETE")
    form:Hide()
    BG:RefreshView("war")
  end)
  function form:Open(op)
    self.op = op.id
    self.error:SetText("")
    self.what:SetText("«" .. op.d.title .. "», " .. UI.FormatDate(op.d.start, true) .. ". El parte queda en la crónica de la hermandad.")
    self.result:SetValue("WIN", true)
    self.note:SetText("")
    local names = { op.d.leader }
    for _, a in ipairs(War.Answers(op.id)) do
      if a.d.a == "GO" and not Names.Same(a.d.name, op.d.leader) then
        names[#names + 1] = a.d.name
      end
    end
    self.present:SetText("Presentes (" .. #names .. "): " .. table.concat(names, ", ") .. ". Son quienes dijeron «Voy», y quien la dirigió.")
    self:Show()
  end
  return form
end

-- Squad form ------------------------------------------------------------------------------------------------------
local function buildSquadForm(f)
  local form = overlay(f, "Nueva escuadra")
  local lName = form:Label("Nombre y especialidad")
  form.name = UI.EditBox(form, { width = 220, maxLetters = 30, placeholder = "Por ejemplo: Los Lobos" })
  form.name:SetPoint("TOPLEFT", lName, "BOTTOMLEFT", 0, -4)
  form.spec = UI.Picker(form, { width = 140 })
  form.spec:SetPoint("LEFT", form.name, "RIGHT", 10, 0)
  local specs = {}
  for _, s in ipairs(War.SPECS) do
    specs[#specs + 1] = { value = s.key, label = s.name }
  end
  form.spec:SetOptions(specs)
  local lLeader = form:Label("Jefe de escuadra", form.name, -12)
  form.leader = UI.EditBox(form, { width = 220, maxLetters = 40, placeholder = "Nombre y apellido" })
  form.leader:SetPoint("TOPLEFT", lLeader, "BOTTOMLEFT", 0, -4)
  form.saveSquad = UI.Button(form, "Guardar", { primary = true, height = 26, width = 100 })
  form.saveSquad:SetPoint("LEFT", form.leader, "RIGHT", 10, 0)
  form.locked = UI.Text(form, 12, C.text2, { wrap = true })
  form.locked:SetPoint("TOPLEFT", form.heading, "BOTTOMLEFT", 0, -14)
  form.locked:SetPoint("RIGHT", -22, 0)

  form.membersHead = UI.Heading(form, "Miembros")
  form.membersHead:SetPoint("TOPLEFT", form.leader, "BOTTOMLEFT", 0, -18)
  form.membersHead:SetPoint("RIGHT", -22, 0)
  form.members = UI.Text(form, 12, C.text, { wrap = true })
  form.members:SetPoint("TOPLEFT", form.membersHead, "BOTTOMLEFT", 0, -6)
  form.members:SetPoint("RIGHT", -22, 0)
  form.addName = UI.EditBox(form, { width = 220, maxLetters = 40, placeholder = "Nombre y apellido" })
  form.addName:SetPoint("TOPLEFT", form.members, "BOTTOMLEFT", 0, -10)
  form.add = UI.Button(form, "Añadir", { height = 26, width = 90 })
  form.add:SetPoint("LEFT", form.addName, "RIGHT", 10, 0)
  form.removePick = UI.Picker(form, { width = 220, placeholder = "Elegir a quién…" })
  form.removePick:SetPoint("TOPLEFT", form.addName, "BOTTOMLEFT", 0, -10)
  form.remove = UI.Button(form, "Quitar", { height = 26, width = 90 })
  form.remove:SetPoint("LEFT", form.removePick, "RIGHT", 10, 0)
  form.delete = UI.Button(form, "Borrar escuadra", { height = 30, width = 150 })
  form.delete:SetPoint("RIGHT", form.back, "LEFT", -10, 0)

  local function refreshMembers()
    local sq = form.editing and Store.Get("squads", form.editing)
    local list = sq and not sq.del and sq.d.members or {}
    form.members:SetText(sq and (#list > 0 and table.concat(list, ", ") or "Aún nadie, aparte del jefe.") or "Guarda primero la escuadra.")
    local opts = {}
    for _, n in ipairs(list) do
      opts[#opts + 1] = { value = n, label = n }
    end
    form.removePick:SetOptions(opts)
    form.removePick:SetValue(nil, true)
    local can = sq ~= nil and not sq.del and War.CanManageSquad(sq)
    for _, w in ipairs({ form.addName, form.add, form.removePick, form.remove }) do
      w:SetShown(can)
    end
  end
  form.saveSquad:SetScript("OnClick", function()
    local r, w = War.SaveSquad(form.editing, { name = form.name:GetText(), spec = form.spec:GetValue(), leader = form.leader:GetText() })
    if not r then
      form.error:SetText(why(w))
      return
    end
    form.editing = r.id
    form.error:SetText(BG.colorize("Guardada.", C.success))
    form.heading.title:SetText("Escuadra «" .. r.d.name .. "»")
    refreshMembers()
  end)
  form.add:SetScript("OnClick", function()
    local r, w, extra = War.AddToSquad(form.editing, form.addName:GetText())
    form.error:SetText(r and "" or why(w, extra))
    if r then
      form.addName:SetText("")
    end
    refreshMembers()
  end)
  form.remove:SetScript("OnClick", function()
    local who = form.removePick:GetValue()
    if who then
      War.RemoveFromSquad(form.editing, who)
      refreshMembers()
    end
  end)
  form.delete:SetScript("OnClick", function()
    local id = form.editing
    BG.UI.Dialog({
      title = "Borrar la escuadra",
      items = { "Sus miembros quedan libres para otras escuadras. Las operaciones ya planeadas siguen." },
      primary = { label = "Borrar", fn = function()
        War.DeleteSquad(id)
        form:Hide()
        BG:RefreshView("war")
      end },
      secondary = { label = "Volver" },
    })
  end)

  function form:Open(sq)
    self.editing = sq and sq.id or nil
    self.error:SetText("")
    local org = Store.IsOrganiser(Names.Me() or "")
    self.heading.title:SetText(sq and ("Escuadra «" .. sq.d.name .. "»") or "Nueva escuadra")
    for _, w in ipairs({ self.name, self.spec, self.leader, self.saveSquad }) do
      w:SetShown(org)
    end
    self.delete:SetShown(org and sq ~= nil)
    self.locked:SetShown(not org)
    self.locked:SetText(sq and ("Jefe: " .. sq.d.leader .. ". " .. ((War.Spec(sq.d.spec) or {}).name or "") .. ". Los organizadores cambian el nombre y el jefe; tú decides quién está.") or "")
    self.membersHead:ClearAllPoints()
    self.membersHead:SetPoint("TOPLEFT", org and self.leader or self.locked, "BOTTOMLEFT", 0, -18)
    self.membersHead:SetPoint("RIGHT", -22, 0)
    self.name:SetText(sq and sq.d.name or "")
    self.spec:SetValue(sq and sq.d.spec or "ASSAULT", true)
    self.leader:SetText(sq and sq.d.leader or "")
    refreshMembers()
    self:Show()
  end
  return form
end

-- Cards -------------------------------------------------------------------------------------------------------------
local STATE_COLOR = { PLANNED = "gold", ACTIVE = "danger", DONE = "success", CANCELLED = "text3" }

local function opCard(list, f)
  local c = UI.Card(list)
  c.iconCentered = false
  c.icon:ClearAllPoints()
  c.icon:SetPoint("TOPLEFT", 12, -10)
  c.icon:SetSize(30, 30)
  c.right:ClearAllPoints()
  c.right:SetPoint("TOPRIGHT", -12, -10)
  c.answers = {}
  local prev
  for _, key in ipairs({ "GO", "MAYBE", "NO" }) do
    local b = UI.Button(c, War.ANSWERS[key], { height = 22, width = key == "NO" and 82 or 66 })
    if prev then
      b:SetPoint("LEFT", prev, "RIGHT", 6, 0)
    else
      b:SetPoint("BOTTOMLEFT", 54, 8)
    end
    b:SetScript("OnClick", function()
      if c.op then
        local r, w = War.Answer(c.op.id, key)
        if not r then
          BG:Notify("No se pudo", why(w), { kind = "warning" })
        end
        BG:RefreshView("war")
      end
    end)
    c.answers[key] = b
    prev = b
  end
  c.run = UI.CardButton(c, "¡En marcha!", { primary = true, height = 22, width = 110 })
  c.run:SetPoint("TOPRIGHT", -10, -8) -- (top right: the answers take the bottom row, even in a narrow window)
  c.run:SetScript("OnClick", function()
    local op = c.op
    if not op then
      return
    end
    if op.d.status == "PLANNED" then
      War.Start(op.id)
      BG:RefreshView("war")
    elseif op.d.status == "ACTIVE" then
      f.reportForm:Open(op)
    end
  end)
  c.edit = UI.CardButton(c, "Editar", { height = 22, width = 70 })
  c.edit:SetPoint("RIGHT", c.run, "LEFT", -6, 0)
  c.edit:SetScript("OnClick", function()
    if c.op then
      f.opForm:Open(c.op)
    end
  end)
  return c
end

local function fillOp(c, op)
  c.op = op
  c.key = op.id
  c:SetHeight(86)
  c.detail = {}
  if op.d.note and op.d.note ~= "" then
    c.detail[#c.detail + 1] = "Nota: " .. op.d.note
  end
  local who = {}
  for _, a in ipairs(War.Answers(op.id)) do
    who[#who + 1] = a.d.name .. " (" .. War.ANSWERS[a.d.a]:lower() .. ")"
  end
  c.detail[#c.detail + 1] = #who > 0 and ("Respuestas: " .. table.concat(who, ", ") .. ".") or "Aún no ha respondido nadie."
  local ally = op.d.ally
  if ally and ally.lead and BG.AllianceActs then
    local others = {}
    for _, cnt in pairs(BG.AllianceActs.Counts(ally.i)) do
      others[#others + 1] = string.format("%s: %d van, %d en reserva", cnt.name, cnt.y, cnt.m)
    end
    table.sort(others)
    c.detail[#c.detail + 1] = #others > 0 and ("Otras hermandades. " .. table.concat(others, ". ") .. ".") or "Las otras hermandades aún no han dicho cuántos van."
  elseif ally then
    c.detail[#c.detail + 1] = string.format("Operación de toda la alianza: la organiza «%s». Vuestras respuestas le llegan solas.", ally.n or "?")
  end
  local me = Names.Me() or ""
  local kind = War.Kind(op.d.kind) or War.KINDS[1]
  c.icon:SetTexture(BG.file(kind.icon, "Interface\\Icons\\INV_Misc_Map_01"))
  local col = C[STATE_COLOR[op.d.status]] or C.text3
  c.title:SetText(op.d.title .. "  " .. BG.colorize(War.STATES[op.d.status], col))
  local squads = War.SquadNames(op)
  local open = op.d.status == "PLANNED" or op.d.status == "ACTIVE"
  local runs = open and War.CanRun(op)
  local n = War.Count(op.id)
  local counts = string.format("%d van, %d en reserva", n.GO, n.MAYBE)
  -- (in sentences of their own, and what a player wrote between « » or after ":", so each language translates it whole)
  c.sub:SetText((runs and (counts .. ". ") or "") .. kind.name .. ", " .. UI.FormatDate(op.d.start, true) .. ". "
    .. (op.d.place and op.d.place ~= "" and (string.format("Lugar: «%s»", op.d.place) .. ". ") or "")
    .. (ally and (ally.lead and "Toda la alianza" or string.format("Toda la alianza, de «%s»", ally.n or "?")) or #squads > 0 and ("Escuadras: " .. table.concat(squads, ", ")) or "Toda la hermandad")
    .. ". " .. string.format("Dirige: %s.", op.d.leader or "?"))
  local mine = War.MyAnswer(op.id)
  -- Who runs it has its buttons top right; everyone else, the counts and their answer there.
  c.right:SetText(runs and "" or counts)
  c.right2:SetText(runs and "" or (mine and BG.colorize("tú: " .. War.ANSWERS[mine]:lower(), C.gold) or (War.Called(op, me) and BG.colorize("te llaman", C.warning) or "")))
  c.title:SetPoint("RIGHT", runs and c.edit or c.right, "LEFT", -8, 0)
  for key, b in pairs(c.answers) do
    b:SetShown(open)
    b.text:SetTextColor(mine == key and C.goldHi[1] or C.text[1], mine == key and C.goldHi[2] or C.text[2], mine == key and C.goldHi[3] or C.text[3])
  end
  c.run:SetShown(runs)
  c.run.text:SetText(op.d.status == "ACTIVE" and "Terminar" or "¡En marcha!")
  c.edit:SetShown(runs)
  local ac = op.d.status == "ACTIVE" and C.danger or (op.d.status == "PLANNED" and C.gold or C.line)
  c.accent:SetColorTexture(ac[1], ac[2], ac[3], 0.9)
end

local function squadCard(list, f)
  local c = UI.Card(list)
  c.talk = UI.CardButton(c, "Hablar", { height = 22, width = 70 })
  c.talk:SetPoint("BOTTOMRIGHT", -10, 8)
  c.talk:SetScript("OnClick", function()
    if c.sq then
      openChat("sq-" .. c.sq.id)
    end
  end)
  c.manage = UI.CardButton(c, "Gestionar", { height = 22, width = 90 })
  c.manage:SetScript("OnClick", function()
    if c.sq then
      f.squadForm:Open(c.sq)
    end
  end)
  return c
end

local function fillSquad(c, sq)
  c.sq = sq
  c.key = sq.id
  c:SetHeight(62)
  c.detail = { "Miembros: " .. sq.d.leader .. " (jefe)" .. (#sq.d.members > 0 and (", " .. table.concat(sq.d.members, ", ")) or "") .. "." }
  if sq.d.note and sq.d.note ~= "" then
    c.detail[#c.detail + 1] = "Nota: " .. sq.d.note
  end
  local me = Names.Me() or ""
  local spec = War.Spec(sq.d.spec) or War.SPECS[1]
  c.icon:SetTexture(BG.file(spec.icon, "Interface\\Icons\\INV_Sword_04"))
  local mine = War.InSquad(sq, me)
  c.title:SetText(sq.d.name .. "  " .. BG.colorize(spec.name, C.text3))
  local online = 0
  for _, n in ipairs({ sq.d.leader, unpack(sq.d.members) }) do
    local m = BG.Guild.Find(n)
    if m and m.online then
      online = online + 1
    end
  end
  c.sub:SetText("Jefe: " .. sq.d.leader .. ". " .. (#sq.d.members + 1) .. " personas, " .. online .. " conectadas.")
  c.right:SetText(mine and BG.colorize("tu escuadra", C.gold) or "")
  c.right2:SetText("")
  c.talk:SetShown(mine)
  c.manage:SetShown(War.CanManageSquad(sq))
  c.manage:ClearAllPoints()
  if mine then
    c.manage:SetPoint("RIGHT", c.talk, "LEFT", -6, 0)
  else
    c.manage:SetPoint("BOTTOMRIGHT", -10, 8)
  end
  local ac = mine and C.gold or C.line
  c.accent:SetColorTexture(ac[1], ac[2], ac[3], 0.9)
end

-- View ----------------------------------------------------------------------------------------------------------
BG:RegisterView("war", {
  Build = function(f, def)
    f.hero = UI.Hero(f, 118)
    f.hero:SetPoint("TOPLEFT")
    f.hero:SetPoint("TOPRIGHT")

    local ops = UI.Plate(f, { corners = 18, rail = 0.24 })
    ops:SetPoint("TOPLEFT", f.hero, "BOTTOMLEFT", PAD, -16)
    ops:SetPoint("BOTTOM", 0, 18)
    f.opsPlate = ops
    ops.head = UI.Heading(ops, "Operaciones")
    ops.head:SetPoint("TOPLEFT", 16, -8)
    ops.head:SetPoint("TOPRIGHT", -16, -8)
    f.newOp = UI.Button(ops, "Planear operación", { primary = true, height = 24, width = 150 })
    f.newOp:SetPoint("TOPRIGHT", -16, -10)
    f.newOp:SetScript("OnClick", function()
      f.opForm:Open(nil)
    end)
    f.ops = UI.List(ops, 92, function(list)
      return opCard(list, f)
    end, fillOp)
    f.ops:SetPoint("TOPLEFT", ops.head, "BOTTOMLEFT", 0, -10)
    f.ops:SetPoint("BOTTOMRIGHT", -16, 14)
    f.opsEmpty = UI.Text(ops, 12, C.text3, { wrap = true })
    f.opsEmpty:SetPoint("TOPLEFT", ops.head, "BOTTOMLEFT", 0, -14)
    f.opsEmpty:SetPoint("RIGHT", -16, 0)

    local side = UI.Plate(f, { corners = 18, rail = 0.24 })
    side:SetPoint("TOPLEFT", ops, "TOPRIGHT", 18, 0)
    side:SetPoint("BOTTOMRIGHT", -PAD, 18)
    f.side = side
    side.head = UI.Heading(side, "Escuadras")
    side.head:SetPoint("TOPLEFT", 16, -8)
    side.head:SetPoint("TOPRIGHT", -16, -8)
    f.newSquad = UI.Button(side, "Nueva escuadra", { height = 24, width = 130 })
    f.newSquad:SetPoint("TOPRIGHT", -16, -10)
    f.newSquad:SetScript("OnClick", function()
      f.squadForm:Open(nil)
    end)
    f.squads = UI.List(side, 68, function(list)
      return squadCard(list, f)
    end, fillSquad)
    f.squads:SetPoint("TOPLEFT", side.head, "BOTTOMLEFT", 0, -10)
    f.squads:SetPoint("RIGHT", -16, 0)
    f.squads:SetHeight(272)
    f.squadsEmpty = UI.Text(side, 12, C.text3, { wrap = true })
    f.squadsEmpty:SetPoint("TOPLEFT", side.head, "BOTTOMLEFT", 0, -14)
    f.squadsEmpty:SetPoint("RIGHT", -16, 0)
    side.reportsHead = UI.Heading(side, "Partes recientes")
    side.reportsHead:SetPoint("TOPLEFT", f.squads, "BOTTOMLEFT", 0, -10)
    side.reportsHead:SetPoint("RIGHT", -16, 0)
    f.reports = UI.Text(side, 12, C.text2, { wrap = true })
    f.reports:SetPoint("TOPLEFT", side.reportsHead, "BOTTOMLEFT", 0, -6)
    f.reports:SetPoint("RIGHT", -16, 0)
    f.reports:SetSpacing(4)

    f.opForm = buildOpForm(f)
    f.reportForm = buildReportForm(f)
    f.squadForm = buildSquadForm(f)

    f:SetScript("OnSizeChanged", function(self, w)
      self.opsPlate:SetWidth(math.floor((w - PAD * 2 - 18) * 0.58))
    end)
  end,

  Refresh = function(f)
    local info = BG.Guild.info
    local me = Names.Me() or ""
    local faction = info and info.faction or "ALLIANCE"
    f.hero:SetArt(BG.art[faction] or BG.art.ALLIANCE, 0.5)
    f.hero:SetIcon(BG.file("Interface\\Icons\\Ability_Warrior_BattleShout", "Interface\\Icons\\INV_Sword_04"))
    local squads, ops = War.Squads(), War.Ops()
    local people = 0
    for _, sq in ipairs(squads) do
      people = people + #sq.d.members + 1
    end
    local nextOp
    for _, op in ipairs(ops) do
      if op.d.status == "ACTIVE" or (op.d.status == "PLANNED" and not nextOp) then
        nextOp = nextOp and nextOp.d.status == "ACTIVE" and nextOp or op
      end
    end
    f.hero.title:SetText("Sala de guerra")
    f.hero.sub:SetText((#squads == 0 and "Aún no hay escuadras. " or string.format("%d %s con %d personas. ", #squads, #squads == 1 and "escuadra" or "escuadras", people))
      .. (nextOp and BG.TF(nextOp.d.status == "ACTIVE" and "En marcha: %s, %s." or "Próxima operación: %s, %s.", nextOp.d.title, UI.FormatDate(nextOp.d.start, true))
      or BG.T("No hay operaciones planeadas.")))

    local canPlan = War.CanPlan(me)
    f.newOp:SetShown(canPlan)
    f.ops:SetItems(ops)
    f.opsEmpty:SetShown(#ops == 0)
    f.opsEmpty:SetText(canPlan and "No hay operaciones. Planea una: qué se hace, cuándo, dónde y qué escuadras van. Cada uno responde «Voy», «Reserva» o «No puedo»."
      or "No hay operaciones. Las planean los organizadores y los jefes de escuadra; cuando haya una, te avisamos y respondes desde aquí.")

    local org = Store.IsOrganiser(me)
    f.newSquad:SetShown(org)
    f.squads:SetItems(squads)
    f.squadsEmpty:SetShown(#squads == 0)
    f.squadsEmpty:SetText(org and "Aún no hay escuadras. Crea una con un jefe y unos pocos miembros: tendrá su propio chat y podréis llamarla a operaciones."
      or "Aún no hay escuadras. Las crean los organizadores; cada una tiene su jefe y su propio chat.")

    local lines = {}
    for _, r in ipairs(War.Reports(4)) do
      lines[#lines + 1] = BG.TF("%s en «%s», %s: %s presentes.",
        BG.colorize(BG.T(War.RESULTS[r.d.result]), r.d.result == "WIN" and C.success or (r.d.result == "LOSS" and C.danger or C.text)),
        r.d.title, UI.FormatDate(r.d.start), #r.d.present)
    end
    f.reports:SetText(#lines > 0 and table.concat(lines, "\n") or "Aún no hay partes. Quien dirige una operación lo escribe al terminarla.")
  end,
})

BG:On("BG_WAR_CHANGED", function()
  BG:RefreshView("war")
  BG:RefreshView("chat")
end)
