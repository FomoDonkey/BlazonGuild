-- Raids: upcoming guild raids, your signup, the composition by role and the organisers' tools (create, edit,
-- cancel, bench, groups, invite everyone confirmed, call the officers). Everything is shared live with the
-- guild's addons (Data/Raids.lua) and will be uploaded to the web by the companion app.
local _, BG = ...
local UI, C = BG.UI, BG.color
local Raids, Instances, Names = BG.Raids, BG.Instances, BG.Names

local PAD, LIST_W, CARD_H = 24, 260, 62
local STATUS_LABEL = { CONFIRMED = "Voy", TENTATIVE = "Quizá", DECLINED = "No voy" }
local STATE_LABEL = { SCHEDULED = "Programada", CANCELLED = "Cancelada", IN_PROGRESS = "En curso", COMPLETED = "Terminada" }
local RAID_ICON = {
  BARROW = "Interface\\Icons\\INV_Misc_Bone_ElfSkull_01", HYJAL = "Interface\\Icons\\Spell_Nature_Tranquility",
  MC = "Interface\\Icons\\Spell_Fire_Incinerate", ONY = "Interface\\Icons\\INV_Misc_Head_Dragon_Black",
  BWL = "Interface\\Icons\\INV_Misc_Head_Dragon_Bronze", ZG = "Interface\\Icons\\INV_Misc_Idol_03",
  AQ20 = "Interface\\Icons\\INV_Misc_AhnQirajTrinket_04", AQ40 = "Interface\\Icons\\INV_Misc_AhnQirajTrinket_01",
  NAXX = "Interface\\Icons\\INV_Trinket_Naxxramas04", UBRS = "Interface\\Icons\\INV_Misc_Key_14",
  DUNGEON = "Interface\\Icons\\INV_Misc_Key_03", OTHER = "Interface\\Icons\\INV_Misc_Note_01",
}

local function roleOptions()
  local out = {}
  for _, r in ipairs(Instances.roles) do
    out[#out + 1] = { value = r.key, label = r.name, role = r.key }
  end
  return out
end

-- Raid form (create / edit) -------------------------------------------------------------------------
local function buildForm(f)
  local form = UI.Plate(f, { corners = 22, rail = 0.3 })
  form:SetFrameLevel(f:GetFrameLevel() + 20)
  form:EnableMouse(true)
  form:Hide()
  form.heading = UI.Heading(form, "Nueva raid")
  form.heading:SetPoint("TOPLEFT", 22, -18)
  form.heading:SetPoint("TOPRIGHT", -22, -18)

  local function label(text, anchor, y)
    local l = UI.Text(form, 11, C.text3)
    l:SetPoint("TOPLEFT", anchor or form.heading, "BOTTOMLEFT", 0, y or -16)
    l:SetText(text)
    return l
  end

  local lInst = label("Banda o actividad")
  form.inst = UI.Picker(form, { width = 250, onChange = function(v)
    local inst = Instances.Raid(v)
    if inst and not form.loading then
      local comp = Instances.Composition(inst.size)
      form.tank:SetValue(comp.TANK, true)
      form.heal:SetValue(comp.HEALER, true)
      form.dps:SetValue(comp.DPS, true)
      form.cap = inst.size
    end
  end })
  form.inst:SetPoint("TOPLEFT", lInst, "BOTTOMLEFT", 0, -4)
  -- (Forever's raids; an old raid of one that is not in Forever keeps it when edited: Open)
  function form:InstOptions(current)
    local opts = {}
    for _, r in ipairs(Instances.RaidOptions(current)) do
      opts[#opts + 1] = { value = r.key, label = r.name, note = r.size .. "" }
    end
    self.inst:SetOptions(opts)
  end
  form:InstOptions()

  local lDay = label("Día", form.inst, -12)
  form.day = UI.Picker(form, { width = 170, menuWidth = 260 })
  form.day:SetPoint("TOPLEFT", lDay, "BOTTOMLEFT", 0, -4)
  local lTime = UI.Text(form, 11, C.text3)
  lTime:SetPoint("BOTTOMLEFT", form.day, "TOPRIGHT", 14, 4)
  lTime:SetText("Hora")
  form.hour = UI.Picker(form, { width = 70 })
  form.hour:SetPoint("LEFT", form.day, "RIGHT", 14, 0)
  form.hour:SetOptions(UI.TimeOptions(14, 23))

  local lTitle = label("Título (opcional)", form.day, -12)
  form.title = UI.EditBox(form, { width = 330, maxLetters = 60, placeholder = "Por ejemplo: Núcleo de Magma, primera semana" })
  form.title:SetPoint("TOPLEFT", lTitle, "BOTTOMLEFT", 0, -4)

  local lNeed = label("Plazas por rol", form.title, -12)
  form.tank = UI.Stepper(form, "Tanques", 0, 40, { width = 140 })
  form.tank:SetPoint("TOPLEFT", lNeed, "BOTTOMLEFT", 0, -4)
  form.heal = UI.Stepper(form, "Sanadores", 0, 40, { width = 150 })
  form.heal:SetPoint("LEFT", form.tank, "RIGHT", 18, 0)
  form.dps = UI.Stepper(form, "Daño", 0, 40, { width = 120 })
  form.dps:SetPoint("LEFT", form.heal, "RIGHT", 18, 0)

  local lMin = label("Nivel mínimo", form.tank, -12)
  form.minLevel = UI.Stepper(form, "", 1, 60, { width = 90, value = 60 })
  form.minLevel:SetPoint("TOPLEFT", lMin, "BOTTOMLEFT", 0, -4)

  local lNote = label("Nota para la hermandad (opcional)", form.minLevel, -12)
  form.note = UI.EditBox(form, { width = 460, maxLetters = 200, placeholder = "Por ejemplo: traed resistencia al fuego y pociones" })
  form.note:SetPoint("TOPLEFT", lNote, "BOTTOMLEFT", 0, -4)

  form.error = UI.Text(form, 12, C.danger, { wrap = true })
  form.error:SetPoint("BOTTOMLEFT", 22, 26)
  form.error:SetWidth(300)
  form.save = UI.Button(form, "Crear raid", { primary = true, height = 30, width = 150 })
  form.save:SetPoint("BOTTOMRIGHT", -22, 18)
  form.cancel = UI.Button(form, "Volver", { height = 30, width = 100 })
  form.cancel:SetPoint("RIGHT", form.save, "LEFT", -10, 0)
  form.cancel:SetScript("OnClick", function()
    form:Hide()
    BG:RefreshView("raids")
  end)
  form.save:SetScript("OnClick", function()
    local day, minutes = form.day:GetValue(), form.hour:GetValue()
    if not form.inst:GetValue() or not day or not minutes then
      form.error:SetText("Elige la banda, el día y la hora.")
      return
    end
    local start = day + minutes
    if start < time() - 3600 then
      form.error:SetText("Esa hora ya ha pasado.")
      return
    end
    local old = form.editing and Raids.Get(form.editing)
    local r, why = Raids.Save(form.editing, {
      status = (old and old.d.status == "CANCELLED") and "SCHEDULED" or nil, -- (saving a cancelled raid with its new day programmes it again)
      inst = form.inst:GetValue(), start = start, title = form.title:GetText(), note = form.note:GetText(),
      cap = form.cap, minLevel = form.minLevel:GetValue(),
      need = { TANK = form.tank:GetValue(), HEALER = form.heal:GetValue(), DPS = form.dps:GetValue() },
    })
    if not r then
      form.error:SetText(why == "permiso" and "No puedes cambiar esta raid: la gestionan quien la creó, quien la dirige y los organizadores."
        or (why == "consent" and "Acepta antes la privacidad (/bg privacidad)." or ("No se pudo guardar (" .. tostring(why) .. ").")))
      return
    end
    BG.Sound("IG_QUEST_LIST_COMPLETE")
    form:Hide()
    f.selected = r.id
    BG:RefreshView("raids")
  end)

  function form:Open(raid)
    self.loading = true
    self.editing = raid and raid.id or nil
    self.heading.title:SetText(raid and "Editar raid" or "Nueva raid")
    self.save.text:SetText(raid and "Guardar cambios" or "Crear raid")
    self.error:SetText("")
    self.day:SetOptions(UI.DayOptions(21))
    local d = raid and raid.d
    self:InstOptions(d and d.inst)
    self.inst:SetValue(d and d.inst or Instances.raids[1].key, true)
    local inst = Instances.Raid(self.inst:GetValue())
    self.cap = d and d.cap or inst.size
    local comp = d and d.need or Instances.Composition(self.cap)
    self.tank:SetValue(comp.TANK, true)
    self.heal:SetValue(comp.HEALER, true)
    self.dps:SetValue(comp.DPS, true)
    self.minLevel:SetValue(d and d.minLevel or inst.minLevel or 60, true)
    self.title:SetText(d and d.title ~= inst.name and d.title or "")
    self.note:SetText(d and d.note or "")
    if d then
      local t = date("*t", d.start)
      self.day:SetValue(time({ year = t.year, month = t.month, day = t.day, hour = 0, min = 0, sec = 0 }), true)
      self.hour:SetValue((t.hour * 60 + t.min) * 60, true)
    else
      self.day:SetValue(nil, true)
      self.hour:SetValue(21 * 3600, true)
    end
    self.loading = false
    self:Show()
  end
  return form
end

-- Composition column ----------------------------------------------------------------------------------
local function compColumn(parent, role)
  local col = CreateFrame("Frame", nil, parent)
  col.role = role
  col.head = UI.Text(col, 12, C.goldTitle, { font = BG.font.display })
  col.head:SetPoint("TOPLEFT", 0, 0)
  col.icon = col:CreateTexture(nil, "ARTWORK")
  col.icon:SetSize(14, 14)
  col.icon:SetPoint("RIGHT", col.head, "LEFT", -5, 0)
  BG.setRoleIcon(col.icon, role)
  col.head:SetPoint("TOPLEFT", 20, 0)
  col.list = UI.List(col, 20, function(list)
    local r = CreateFrame("Button", nil, list)
    r.icon = r:CreateTexture(nil, "ARTWORK")
    r.icon:SetSize(14, 14)
    r.icon:SetPoint("LEFT", 2, 0)
    r.name = UI.Text(r, 11, C.text)
    r.name:SetPoint("LEFT", r.icon, "RIGHT", 5, 0)
    r.tag = UI.Text(r, 10, C.text3, { justify = "RIGHT" })
    r.tag:SetPoint("RIGHT", -4, 0)
    r.name:SetPoint("RIGHT", r.tag, "LEFT", -4, 0)
    local hl = r:CreateTexture(nil, "HIGHLIGHT")
    hl:SetColorTexture(C.gold[1], C.gold[2], C.gold[3], 0.08)
    hl:SetAllPoints()
    r:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    r:SetScript("OnClick", function(self, button)
      if self.entry and parent.onEntryClick then
        parent.onEntryClick(self.entry, button)
      end
    end)
    r:SetScript("OnEnter", function(self)
      local e = self.entry
      if not e then
        return
      end
      GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
      local cc = BG.classColor(e.d.class)
      GameTooltip:AddLine(e.d.name, cc[1], cc[2], cc[3])
      GameTooltip:AddLine((STATUS_LABEL[e.d.status] or "") .. (e.bench and ", en reserva" or "") .. (e.group and (", grupo " .. e.group) or ""), 1, 1, 1)
      if e.d.note and e.d.note ~= "" then
        GameTooltip:AddLine("«" .. e.d.note .. "»", C.goldHi[1], C.goldHi[2], C.goldHi[3], true)
      end
      if parent.canManage then
        GameTooltip:AddLine("Clic: pasar a reserva o quitarla. Clic derecho: cambiar de grupo.", C.text3[1], C.text3[2], C.text3[3], true)
      end
      BG.ShowTip()
    end)
    r:SetScript("OnLeave", function()
      GameTooltip:Hide()
    end)
    return r
  end, function(r, e)
    r.entry = e
    BG.setClassIcon(r.icon, e.d.class)
    local cc = BG.classColor(e.d.class)
    r.name:SetText(e.d.name)
    local dim = e.bench or e.d.status ~= "CONFIRMED"
    r.name:SetTextColor(cc[1], cc[2], cc[3], dim and 0.55 or 1)
    r.icon:SetDesaturated(dim)
    r.tag:SetText(e.bench and "reserva" or (e.d.status == "TENTATIVE" and BG.colorize("quizá", C.warning) or (e.group and ("G" .. e.group) or "")))
  end)
  col.list:SetPoint("TOPLEFT", 0, -22)
  col.list:SetPoint("BOTTOMRIGHT")
  return col
end

-- View ------------------------------------------------------------------------------------------------
BG:RegisterView("raids", {
  Build = function(f, def)
    f.heading = UI.Heading(f, "Raids")
    f.heading:SetPoint("TOPLEFT", PAD, -18)
    f.heading:SetPoint("TOPRIGHT", -PAD, -18)
    f.newBtn = UI.Button(f, "Nueva raid", { primary = true, height = 26 })
    f.newBtn:SetPoint("RIGHT", f.heading, "RIGHT", 0, 2)
    f.musterBtn = UI.Button(f, "Llamar a los oficiales", { height = 26 })
    f.musterBtn:SetPoint("RIGHT", f.newBtn, "LEFT", -8, 0)

    -- Upcoming list
    f.list = UI.List(f, CARD_H + 8, function(list)
      local card = UI.Card(list)
      card:SetScript("OnClick", function(self)
        f.selected = self.raid and self.raid.id
        BG.Sound("IG_MAINMENU_OPTION")
        def.Refresh(f, def)
      end)
      return card
    end, function(card, raid)
      card.raid = raid
      card:SetHeight(CARD_H)
      local inst = Instances.Raid(raid.d.inst)
      card.icon:SetTexture(RAID_ICON[raid.d.inst] or RAID_ICON.OTHER)
      card.title:SetText(raid.d.title)
      card.sub:SetText(UI.FormatDate(raid.d.start, true))
      local counts = Raids.Counts(raid.id)
      card.right:SetText(counts.confirmed .. "/" .. raid.d.cap)
      local mine = Raids.MySignup(raid.id)
      local cancelled = raid.d.status == "CANCELLED"
      card.right2:SetText(cancelled and BG.colorize("Cancelada", C.danger)
        or (mine and BG.colorize(STATUS_LABEL[mine.d.status], mine.d.status == "CONFIRMED" and C.success or (mine.d.status == "TENTATIVE" and C.warning or C.text3))
        or (inst and inst.size .. " jug." or "")))
      card.accent:SetColorTexture((cancelled and C.danger or C.gold)[1], (cancelled and C.danger or C.gold)[2], (cancelled and C.danger or C.gold)[3], 0.85)
      card.title:SetTextColor((cancelled and C.text3 or C.text)[1], (cancelled and C.text3 or C.text)[2], (cancelled and C.text3 or C.text)[3])
      card:SetSelected(raid.id == f.selected)
    end)
    f.list:SetPoint("TOPLEFT", f.heading, "BOTTOMLEFT", 0, -14)
    f.list:SetPoint("BOTTOMLEFT", PAD, 18)
    f.list:SetWidth(LIST_W)

    -- Detail
    local d = CreateFrame("Frame", nil, f)
    d:SetPoint("TOPLEFT", f.list, "TOPRIGHT", 20, 0)
    d:SetPoint("BOTTOMRIGHT", -PAD, 18)
    f.detail = d
    -- Banner with the raid's own art (Molten Core's loading screen for MC, and so on).
    d.hero = UI.Hero(d, 96)
    d.hero:SetPoint("TOPLEFT")
    d.hero:SetPoint("TOPRIGHT")
    d.hero.icon:SetSize(44, 44)
    d.hero.title:SetFont(BG.font.display, 20, "")
    d.title = d.hero.title
    d.meta = d.hero.sub
    d.meta:SetFont(BG.font.body, 12, "")
    d.state = UI.Text(d.hero, 11, C.text2, { justify = "RIGHT" })
    d.state:SetPoint("TOPRIGHT", -12, -10)
    d.title:SetPoint("RIGHT", d.state, "LEFT", -10, 0)
    d.note = UI.Text(d, 12, C.goldHi, { wrap = true })
    d.note:SetPoint("TOPLEFT", d.hero, "BOTTOMLEFT", 0, -8)
    d.note:SetPoint("RIGHT")
    d.note:SetMaxLines(1)

    d.mineHead = UI.Heading(d, "Tu inscripción")
    d.mineHead:SetPoint("TOPLEFT", d.hero, "BOTTOMLEFT", 0, -26)
    d.mineHead:SetPoint("RIGHT")
    -- «Voy», «Quizá» and «No voy» save at once; the role too, once signed up. «Apuntarme»/«Guardar» is for the comment.
    local function saveNow(what)
      local raid = f.selected and Raids.Get(f.selected)
      if not raid or raid.d.status == "CANCELLED" or not BG.Consent.Accepted() then
        return
      end
      if what == "role" and not Raids.MySignup(raid.id) then
        return
      end
      local r, why = Raids.SignUp(raid.id, d.status:GetValue() or "CONFIRMED", d.role:GetValue() or "DPS", d.comment:GetText())
      if r then
        BG.Sound("IG_QUEST_LIST_COMPLETE")
      else
        d.signupNote:SetText(BG.colorize(why == "consent" and "Acepta antes la privacidad." or ("No se pudo (" .. tostring(why) .. ")."), C.danger))
      end
    end
    d.role = UI.Segmented(d, roleOptions(), { itemWidth = 92, onChange = function()
      saveNow("role")
    end })
    d.role:SetPoint("TOPLEFT", d.mineHead, "BOTTOMLEFT", 0, -10)
    d.status = UI.Segmented(d, { { value = "CONFIRMED", label = "Voy" }, { value = "TENTATIVE", label = "Quizá" }, { value = "DECLINED", label = "No voy" } }, { itemWidth = 68, onChange = function()
      saveNow("status")
    end })
    d.status:SetPoint("LEFT", d.role, "RIGHT", 12, 0)
    d.comment = UI.EditBox(d, { width = 330, maxLetters = 120, placeholder = "Comentario (opcional): llego a las 21:15…" })
    d.comment:SetPoint("TOPLEFT", d.role, "BOTTOMLEFT", 0, -10)
    d.saveSignup = UI.Button(d, "Apuntarme", { primary = true, height = 26, width = 130 })
    d.saveSignup:SetPoint("LEFT", d.comment, "RIGHT", 10, 0)
    d.signupNote = UI.Text(d, 11, C.text3)
    d.signupNote:SetPoint("TOPLEFT", d.comment, "BOTTOMLEFT", 0, -6)
    d.signupNote:SetPoint("RIGHT")

    d.compHead = UI.Heading(d, "Composición")
    d.compHead:SetPoint("TOPLEFT", d.signupNote, "BOTTOMLEFT", 0, -8)
    d.compHead:SetPoint("RIGHT")
    -- The groups, as the game's raid frame shows them: everyone sees them; the leader and organisers move people.
    d.groupsBtn = UI.Button(d.compHead, "Grupos", { height = 22, width = 90 })
    d.groupsBtn:SetPoint("RIGHT", 0, 2)
    d.groupsBtn:SetScript("OnClick", function()
      f.groups = f.groups or BG.UI.RaidGroups(f)
      f.groups:Open(f.selected)
    end)
    d.cols = {}
    for i, role in ipairs({ "TANK", "HEALER", "DPS" }) do
      d.cols[i] = compColumn(d, role)
    end
    d.tools = CreateFrame("Frame", nil, d)
    d.tools:SetPoint("BOTTOMLEFT")
    d.tools:SetPoint("BOTTOMRIGHT")
    d.tools:SetHeight(44)
    d.invite = UI.Button(d.tools, "Invitar confirmados", { height = 26 })
    d.invite:SetPoint("BOTTOMLEFT")
    d.edit = UI.Button(d.tools, "Editar", { height = 26 })
    d.edit:SetPoint("LEFT", d.invite, "RIGHT", 8, 0)
    d.cancelRaid = UI.Button(d.tools, "Cancelar", { height = 26 })
    d.cancelRaid:SetPoint("LEFT", d.edit, "RIGHT", 8, 0)
    d.deleteRaid = UI.Button(d.tools, "Borrar", { height = 26 })
    d.deleteRaid:SetScript("OnClick", function()
      local raid = Raids.Get(f.selected)
      if not raid then
        return
      end
      BG.UI.Dialog({ title = "¿Borrar la raid?", items = { raid.d.title .. ", " .. UI.FormatDate(raid.d.start, true) .. ".", "Desaparece de la lista para todos." },
        primary = { label = "Borrar", fn = function()
          Raids.Delete(raid.id)
        end }, secondary = { label = "No" } })
    end)
    d.cancelled = UI.Text(d, 13, C.text2, { wrap = true })
    d.cancelled:SetPoint("TOPLEFT", d.hero, "BOTTOMLEFT", 0, -18)
    d.cancelled:SetPoint("RIGHT")
    d.cancelled:SetSpacing(4)
    d.cancelled:Hide()
    d.toolNote = UI.Text(d.tools, 11, C.text3)
    d.toolNote:SetPoint("TOPLEFT", 0, 0)
    d.toolNote:SetPoint("RIGHT")

    d:SetScript("OnSizeChanged", function(self, w)
      local gap = 14
      local cw = (w - gap * 2) / 3
      for i, col in ipairs(self.cols) do
        col:ClearAllPoints()
        col:SetPoint("TOPLEFT", self.compHead, "BOTTOMLEFT", (i - 1) * (cw + gap), -10)
        col:SetPoint("BOTTOM", self.tools, "TOP", 0, 6)
        col:SetWidth(cw)
      end
    end)

    -- With no raid yet: a large banner with Molten Core and the way to create the first one.
    f.welcome = CreateFrame("Frame", nil, f)
    f.welcome:SetPoint("TOPLEFT", f.heading, "BOTTOMLEFT", 0, -14)
    f.welcome:SetPoint("BOTTOMRIGHT", -PAD, 18)
    f.welcome.hero = UI.Hero(f.welcome, 250)
    f.welcome.hero:SetPoint("TOPLEFT")
    f.welcome.hero:SetPoint("TOPRIGHT")
    f.welcome.hero:SetArt(BG.ArtFor("MC"), 0.42)
    f.welcome.hero:SetIcon(RAID_ICON.MC)
    f.welcome.hero.title:SetFont(BG.font.display, 28, "")
    f.welcome.hero.title:SetText("Organiza una raid")
    f.welcome.hero.sub:SetText("Elige la banda, el día y la hora. Tu hermandad la verá al instante y se apuntará desde el juego con su rol.")
    f.empty = UI.Text(f.welcome, 13, C.text2, { wrap = true })
    f.empty:SetPoint("TOPLEFT", f.welcome.hero, "BOTTOMLEFT", 28, -22)
    f.empty:SetPoint("RIGHT", -28, 0)
    f.emptyBtn = UI.Button(f.welcome, "Crear la primera raid", { primary = true, height = 32, width = 210, size = 13 })
    f.emptyBtn:SetPoint("TOPLEFT", f.empty, "BOTTOMLEFT", 0, -18)
    f.emptyBtn:SetScript("OnClick", function()
      if BG.Consent.Accepted() then
        f.form:Open(nil)
        BG:RefreshView("raids")
      else
        BG.Consent.Open()
      end
    end)
    local steps = UI.Text(f.welcome, 12, C.text3, { wrap = true })
    steps:SetPoint("TOPLEFT", f.emptyBtn, "BOTTOMLEFT", 0, -20)
    steps:SetPoint("RIGHT", -28, 0)
    steps:SetText("Cualquier miembro puede crear sus raids. Quien la crea la dirige: ve quién se apunta y con qué rol, manda a reserva, reparte los grupos e invita con un botón.")

    f.form = buildForm(f)
    f.form:SetPoint("TOPLEFT", f.detail, "TOPLEFT", -8, 8)
    f.form:SetPoint("BOTTOMRIGHT", f.detail, "BOTTOMRIGHT", 8, -8)

    -- Actions
    f.newBtn:SetScript("OnClick", function()
      f.form:Open(nil)
      BG:RefreshView("raids")
    end)
    f.musterBtn:SetScript("OnClick", function()
      local ok = Raids.Muster("Reunión de oficiales, por favor: conectad con " .. (Names.Me() or "el líder") .. ".")
      BG:Print(ok and "llamada enviada a los oficiales conectados." or "no se pudo enviar la llamada (¿privacidad sin aceptar?).")
    end)
    d.saveSignup:SetScript("OnClick", function()
      if not f.selected then
        return
      end
      local r, why = Raids.SignUp(f.selected, d.status:GetValue() or "CONFIRMED", d.role:GetValue() or "DPS", d.comment:GetText())
      if r then
        BG.Sound("IG_QUEST_LIST_COMPLETE")
      else
        d.signupNote:SetText(BG.colorize(why == "consent" and "Acepta antes la privacidad." or ("No se pudo (" .. tostring(why) .. ")."), C.danger))
      end
    end)
    d.invite:SetScript("OnClick", function()
      local invited, offline = Raids.InviteConfirmed(f.selected)
      d.toolNote:SetText(invited .. " invitados" .. (offline > 0 and (", " .. offline .. " sin conectar") or ""))
    end)
    d.edit:SetScript("OnClick", function()
      f.form:Open(Raids.Get(f.selected))
    end)
    d.cancelRaid:SetScript("OnClick", function()
      local raid = Raids.Get(f.selected)
      if not raid then
        return
      end
      BG.UI.Dialog({
        title = "¿Cancelar la raid?",
        items = { raid.d.title .. ", " .. UI.FormatDate(raid.d.start, true) .. ".", "Los apuntados la verán como cancelada. Se puede volver a programar editándola." },
        primary = { label = "Cancelar la raid", fn = function()
          Raids.Cancel(raid.id)
        end },
        secondary = { label = "No, mantenerla" },
      })
    end)
    d.onEntryClick = function(entry, button)
      if not d.canManage then
        return
      end
      if button == "RightButton" then
        local plan = Raids.Plan(f.selected)
        Raids.SetGroup(f.selected, entry.d.name, ((plan.g[entry.d.name] or 0) % 8) + 1)
      else
        Raids.SetBench(f.selected, entry.d.name, not entry.bench)
      end
    end
  end,

  Refresh = function(f, def)
    local list = Raids.Upcoming()
    local accepted = BG.Consent.Accepted()
    local canCreate = Raids.CanCreate() and accepted
    f.newBtn:SetShown(canCreate and #list > 0 and not f.form:IsShown())
    f.musterBtn:SetShown(Raids.IsOrganiser() and accepted and not f.form:IsShown())
    f.heading.title:SetText(#list == 0 and "Raids" or ("Raids (" .. #list .. ")"))
    if f.selected and not Raids.Get(f.selected) then
      f.selected = nil
    end
    f.selected = f.selected or (list[1] and list[1].id)
    f.list:SetItems(list)
    f.list:SetShown(#list > 0)

    local raid = f.selected and Raids.Get(f.selected)
    local d = f.detail
    local area = #list > 0 and f.detail or f.welcome
    f.form:ClearAllPoints()
    f.form:SetPoint("TOPLEFT", area, "TOPLEFT", -8, 8)
    f.form:SetPoint("BOTTOMRIGHT", area, "BOTTOMRIGHT", 8, -8)
    d:SetShown(raid ~= nil and not f.form:IsShown())
    f.welcome:SetShown(raid == nil and not f.form:IsShown())
    if not raid then
      f.emptyBtn:SetShown(BG.Guild.info ~= nil)
      if not BG.Guild.info then
        f.empty:SetText("Únete a una hermandad para ver y organizar sus raids.")
      elseif not accepted then
        f.empty:SetText("Las raids se comparten entre los addons de tu hermandad. Para crearlas, verlas y apuntarte, acepta antes la privacidad.")
        f.emptyBtn.text:SetText("Revisar la privacidad")
      else
        f.empty:SetText("Todavía no hay raids programadas en " .. BG.Guild.info.name .. ".")
        f.emptyBtn.text:SetText("Crear la primera raid")
      end
      return
    end

    local inst = Instances.Raid(raid.d.inst)
    d.hero:SetArt(BG.ArtFor(raid.d.inst), 0.4)
    d.hero:SetIcon(RAID_ICON[raid.d.inst] or RAID_ICON.OTHER)
    d.title:SetText(raid.d.title)
    local cancelled = raid.d.status == "CANCELLED"
    d.state:SetFont(cancelled and BG.font.display or BG.font.body, cancelled and 20 or 11, "")
    d.state:SetText(cancelled and "CANCELADA" or (STATE_LABEL[raid.d.status] or ""))
    d.hero.art:SetDesaturated(cancelled)
    d.state:SetTextColor((raid.d.status == "CANCELLED" and C.danger or C.text2)[1], (raid.d.status == "CANCELLED" and C.danger or C.text2)[2], (raid.d.status == "CANCELLED" and C.danger or C.text2)[3])
    local metaParts = { UI.FormatDate(raid.d.start, true) }
    if inst and inst.name ~= raid.d.title then
      metaParts[#metaParts + 1] = inst.name
    end
    metaParts[#metaParts + 1] = BG.TF("dirige %s", raid.d.leader or raid.by)
    if raid.d.minLevel then
      metaParts[#metaParts + 1] = "nivel " .. raid.d.minLevel .. "+"
    end
    d.meta:SetText(table.concat(metaParts, ", "))
    d.note:SetText(raid.d.note or "")

    -- My signup
    local mine = Raids.MySignup(raid.id)
    local me = BG.Guild.me
    if f.loadedFor ~= raid.id or (mine and f.loadedRev ~= mine.rev) then
      f.loadedFor, f.loadedRev = raid.id, mine and mine.rev
      local allowed = {}
      for _, role in ipairs(Instances.RolesFor(me and me.classFile)) do
        allowed[role] = true
      end
      d.role:SetEnabledValues(allowed)
      d.role:SetValue(mine and mine.d.role or Instances.RolesFor(me and me.classFile)[1], true)
      d.status:SetValue(mine and mine.d.status or "CONFIRMED", true)
      d.comment:SetText(mine and mine.d.note or "")
    end
    d.saveSignup.text:SetText(mine and "Guardar" or "Apuntarme")
    local tooLow = raid.d.minLevel and me and me.level < raid.d.minLevel
    d.signupNote:SetText(not accepted and BG.colorize("Acepta la privacidad para apuntarte.", C.warning)
      or (mine and ("Apuntado: " .. STATUS_LABEL[mine.d.status] .. ", " .. Instances.Role(mine.d.role).name:lower())
      or (tooLow and BG.colorize("Pide nivel " .. raid.d.minLevel .. "; puedes apuntarte igualmente.", C.warning) or "")))
    d.saveSignup:SetEnabled(accepted and raid.d.status ~= "CANCELLED")

    -- Composition
    local counts = Raids.Counts(raid.id)
    d.compHead.title:SetText(string.format("Composición  %d/%d", counts.confirmed, raid.d.cap))
    local plan = Raids.Plan(raid.id)
    local byRole = { TANK = {}, HEALER = {}, DPS = {} }
    for _, s in ipairs(Raids.Signups(raid.id)) do
      if s.d.status ~= "DECLINED" then
        s.bench = plan.bench[s.d.name] or nil
        s.group = plan.g[s.d.name]
        table.insert(byRole[s.d.role], s)
      end
    end
    for _, col in ipairs(d.cols) do
      local entries = byRole[col.role]
      table.sort(entries, function(a, b)
        local ka = (a.bench and 2 or (a.d.status == "CONFIRMED" and 0 or 1))
        local kb = (b.bench and 2 or (b.d.status == "CONFIRMED" and 0 or 1))
        if ka ~= kb then
          return ka < kb
        end
        return a.d.name < b.d.name
      end)
      local needN = raid.d.need[col.role] or 0
      local have = counts[col.role]
      local c = have >= needN and C.success or C.text2
      col.head:SetText(Instances.Role(col.role).name .. "  " .. BG.colorize(have .. "/" .. needN, c))
      col.list:SetItems(entries)
    end
    local manage = Raids.CanManage(raid)
    d.canManage = manage
    d.tools:SetShown(manage)
    d.tools:SetHeight(manage and 44 or 1)
    -- A cancelled raid shows only its banner, a sentence, and (for whoever manages it) «Volver a programar» and «Borrar».
    for _, w in ipairs({ d.mineHead, d.role, d.status, d.comment, d.saveSignup, d.signupNote, d.compHead, d.invite, d.cancelRaid }) do
      w:SetShown(not cancelled)
    end
    for _, col in ipairs(d.cols) do
      col:SetShown(not cancelled)
    end
    d.note:SetShown(not cancelled)
    d.deleteRaid:SetShown(cancelled)
    d.cancelled:SetShown(cancelled)
    d.edit:ClearAllPoints()
    if cancelled then
      d.edit:SetText("Volver a programar")
      d.edit:SetWidth(180)
      d.edit:SetPoint("BOTTOMLEFT")
      d.deleteRaid:ClearAllPoints()
      d.deleteRaid:SetPoint("LEFT", d.edit, "RIGHT", 8, 0)
      d.toolNote:SetText("")
      d.cancelled:SetText("Esta raid se ha cancelado: los apuntados la ven así." .. (manage and "\n\nSi al final se hace, pulsa «Volver a programar», elige el día y guárdala: vuelve a quedar programada. «Borrar» la quita de la lista para todos." or ""))
    else
      d.edit:SetText("Editar")
      d.edit:SetWidth(math.max(70, d.edit.text:GetStringWidth() + 26))
      d.edit:SetPoint("LEFT", d.invite, "RIGHT", 8, 0)
    end
    if counts.tentative + counts.declined + counts.bench > 0 then
      d.compHead.note = d.compHead.note or UI.Text(d.compHead, 11, C.text3)
      d.compHead.note:SetPoint("RIGHT", d.groupsBtn, "LEFT", -10, 0)
      d.compHead.note:SetText(string.format("%d quizá, %d no van, %d en reserva", counts.tentative, counts.declined, counts.bench))
    elseif d.compHead.note then
      d.compHead.note:SetText("")
    end
  end,
})

BG:On("BG_STORE_CHANGED", function(name)
  if name == "raids" or name == "signups" or name == "plans" then
    BG:RefreshView("raids")
    BG:RefreshView("calendar")
  end
end)
