-- Mazmorras: looking for group inside the guild. Your flag on the board ("busco grupo para X como sanador"),
-- open groups you can ask to join with a role, and, for a leader, the group's requests to accept or decline.
local _, BG = ...
local UI, C = BG.UI, BG.color
local Groups, Instances, Names = BG.Groups, BG.Instances, BG.Names

local PAD = 24
local ROLE_NAME = { TANK = "tanque", HEALER = "sanador", DPS = "daño" }

local function targetName(key)
  local inst = Instances.Any(key)
  return inst and inst.name or nil
end

local function missingText(miss)
  local parts = {}
  if miss.TANK > 0 then
    parts[#parts + 1] = miss.TANK .. (miss.TANK == 1 and " tanque" or " tanques")
  end
  if miss.HEALER > 0 then
    parts[#parts + 1] = miss.HEALER .. (miss.HEALER == 1 and " sanador" or " sanadores")
  end
  if miss.DPS > 0 then
    parts[#parts + 1] = miss.DPS .. " de daño"
  end
  return #parts == 0 and "completo" or ("faltan " .. table.concat(parts, ", "))
end

local function targetOptions(level, faction, withRaids)
  local out = {}
  for _, d in ipairs(Instances.DungeonsFor(level, faction)) do
    out[#out + 1] = { value = d.key, label = d.name, note = d.min .. "-" .. d.max }
  end
  if withRaids then
    for _, r in ipairs(Instances.raids) do
      if r.key ~= "DUNGEON" and r.key ~= "OTHER" and not r.legacy then
        out[#out + 1] = { value = r.key, label = r.name, note = "banda" }
      end
    end
    for _, a in ipairs(Instances.activities) do
      out[#out + 1] = { value = a.key, label = a.name, note = "grupo" }
    end
  end
  return out
end

local function myRoles()
  local me = BG.Guild.me
  local opts = {}
  for _, key in ipairs(Instances.RolesFor(me and me.classFile)) do
    local r = Instances.Role(key)
    opts[#opts + 1] = { value = key, label = r.name, role = key }
  end
  return opts
end

-- Create-group form ---------------------------------------------------------------------------------
local function buildForm(f)
  local form = UI.Plate(f, { corners = 22, rail = 0.3 })
  form:SetFrameLevel(f:GetFrameLevel() + 20)
  form:EnableMouse(true)
  form:Hide()
  form.heading = UI.Heading(form, "Crear grupo")
  form.heading:SetPoint("TOPLEFT", 22, -18)
  form.heading:SetPoint("TOPRIGHT", -22, -18)
  local l1 = UI.Text(form, 11, C.text3)
  l1:SetPoint("TOPLEFT", form.heading, "BOTTOMLEFT", 0, -16)
  l1:SetText("Para qué es el grupo")
  form.target = UI.Picker(form, { width = 300, onChange = function(v)
    local inst = Instances.Any(v)
    local comp = Instances.Composition(inst and inst.size or 5)
    form.tank:SetValue(comp.TANK, true)
    form.heal:SetValue(comp.HEALER, true)
    form.dps:SetValue(comp.DPS, true)
  end })
  form.target:SetPoint("TOPLEFT", l1, "BOTTOMLEFT", 0, -4)
  local l2 = UI.Text(form, 11, C.text3)
  l2:SetPoint("TOPLEFT", form.target, "BOTTOMLEFT", 0, -12)
  l2:SetText("Tu rol en el grupo")
  form.role = nil
  form.roleHolder = CreateFrame("Frame", nil, form)
  form.roleHolder:SetPoint("TOPLEFT", l2, "BOTTOMLEFT", 0, -4)
  form.roleHolder:SetSize(330, 26)
  local l3 = UI.Text(form, 11, C.text3)
  l3:SetPoint("TOPLEFT", form.roleHolder, "BOTTOMLEFT", 0, -12)
  l3:SetText("Plazas del grupo (contándote a ti)")
  form.tank = UI.Stepper(form, "Tanques", 0, 10, { width = 140 })
  form.tank:SetPoint("TOPLEFT", l3, "BOTTOMLEFT", 0, -4)
  form.heal = UI.Stepper(form, "Sanadores", 0, 10, { width = 150 })
  form.heal:SetPoint("LEFT", form.tank, "RIGHT", 18, 0)
  form.dps = UI.Stepper(form, "Daño", 0, 30, { width = 120 })
  form.dps:SetPoint("LEFT", form.heal, "RIGHT", 18, 0)
  local l4 = UI.Text(form, 11, C.text3)
  l4:SetPoint("TOPLEFT", form.tank, "BOTTOMLEFT", 0, -12)
  l4:SetText("Nota (opcional)")
  form.note = UI.EditBox(form, { width = 460, maxLetters = 140, placeholder = "Por ejemplo: vamos a por el Emperador, salimos en 10 min" })
  form.note:SetPoint("TOPLEFT", l4, "BOTTOMLEFT", 0, -4)
  form.error = UI.Text(form, 12, C.danger)
  form.error:SetPoint("BOTTOMLEFT", 22, 26)
  form.save = UI.Button(form, "Publicar grupo", { primary = true, height = 30, width = 150 })
  form.save:SetPoint("BOTTOMRIGHT", -22, 18)
  local back = UI.Button(form, "Volver", { height = 30, width = 100 })
  back:SetPoint("RIGHT", form.save, "LEFT", -10, 0)
  back:SetScript("OnClick", function()
    form:Hide()
    BG:RefreshView("dungeons")
  end)
  form.save:SetScript("OnClick", function()
    if not form.target:GetValue() then
      form.error:SetText("Elige para qué es el grupo: una mazmorra, una banda u otra actividad.")
      return
    end
    local r, why = Groups.Create(form.target:GetValue(), { TANK = form.tank:GetValue(), HEALER = form.heal:GetValue(), DPS = form.dps:GetValue() }, form.note:GetText(), form.role:GetValue())
    if not r then
      form.error:SetText(why == "consent" and "Acepta antes la privacidad (/bg privacidad)." or ("No se pudo publicar (" .. tostring(why) .. ")."))
      return
    end
    BG.Sound("IG_QUEST_LIST_COMPLETE")
    form:Hide()
    BG:RefreshView("dungeons")
  end)
  function form:Open()
    local me = BG.Guild.me
    self.error:SetText("")
    self.target:SetOptions(targetOptions(me and me.level, BG.Guild.info and BG.Guild.info.faction, true))
    self.target:SetValue(nil, true)
    if not self.role then
      self.role = UI.Segmented(self.roleHolder, myRoles(), { itemWidth = 104 })
      self.role:SetPoint("LEFT")
    end
    self.role:SetValue(myRoles()[1].value, true)
    local comp = Instances.Composition(5)
    self.tank:SetValue(comp.TANK, true)
    self.heal:SetValue(comp.HEALER, true)
    self.dps:SetValue(comp.DPS, true)
    self.note:SetText("")
    self:Show()
  end
  return form
end

-- View ----------------------------------------------------------------------------------------------
BG:RegisterView("dungeons", {
  Build = function(f, def)
    f.heading = UI.Heading(f, "Buscar grupo")
    f.heading:SetPoint("TOPLEFT", PAD, -18)
    f.heading:SetPoint("TOPRIGHT", -PAD, -18)
    f.createBtn = UI.Button(f, "Crear grupo", { primary = true, height = 26 })
    f.createBtn:SetPoint("RIGHT", f.heading, "RIGHT", 0, 2)

    -- My flag strip
    local strip = UI.Plate(f, { rail = 0.22 })
    strip:SetPoint("TOPLEFT", f.heading, "BOTTOMLEFT", 0, -12)
    strip:SetPoint("TOPRIGHT", f.heading, "BOTTOMRIGHT", 0, -12)
    strip:SetHeight(72)
    f.strip = strip
    strip.label = UI.Text(strip, 13, C.goldTitle, { font = BG.font.display })
    strip.label:SetPoint("TOPLEFT", 14, -12)
    strip.label:SetText("Tu bandera en el tablón")
    strip.kind = UI.Picker(strip, { width = 110, onChange = function()
      def.Refresh(f, def)
    end })
    strip.kind:SetPoint("TOPLEFT", 12, -36)
    local kinds = {}
    for _, k in ipairs(Groups.kinds) do
      kinds[#kinds + 1] = { value = k, label = Groups.kindName[k] }
    end
    strip.kind:SetOptions(kinds)
    strip.kind:SetValue("DUNGEON", true)
    strip.target = UI.Picker(strip, { width = 200, placeholder = "Cualquiera" })
    strip.target:SetPoint("LEFT", strip.kind, "RIGHT", 6, 0)
    strip.roleHolder = CreateFrame("Frame", nil, strip)
    strip.roleHolder:SetPoint("LEFT", strip.target, "RIGHT", 8, 0)
    strip.roleHolder:SetSize(10, 26)
    strip.note = UI.EditBox(strip, { width = 150, height = 22, maxLetters = 120, placeholder = "Nota para quien lo lea (opcional)" })
    strip.note:SetPoint("LEFT", strip.label, "RIGHT", 14, 0)
    strip.note:SetPoint("RIGHT", -12, 0)
    strip.raise = UI.Button(strip, "Levantar bandera", { primary = true, height = 26, width = 140 })
    strip.raise:SetPoint("TOPRIGHT", -12, -36)
    strip.status = UI.Text(strip, 12, C.text)
    strip.status:SetPoint("LEFT", strip.kind, "LEFT", 2, 0)
    strip.status:SetPoint("RIGHT", strip.raise, "LEFT", -10, 0)

    -- Open groups (left) and flags (right)
    f.groupsHead = UI.Heading(f, "Grupos abiertos")
    f.flagsHead = UI.Heading(f, "Buscan grupo")
    f.groups = UI.List(f, 78, function(list)
      local card = UI.Card(list)
      card.iconCentered = false
      card.icon:ClearAllPoints()
      card.icon:SetPoint("TOPLEFT", 12, -10)
      card.icon:SetSize(26, 26)
      card.right:ClearAllPoints()
      card.right:SetPoint("TOPRIGHT", -12, -10)
      card.ask = UI.CardButton(card, "Apuntarme", { height = 22, width = 104 })
      card.ask:SetPoint("BOTTOMRIGHT", -10, 8)
      card.askRole = UI.Picker(card, { width = 104, height = 22 })
      card.actions[#card.actions + 1] = card.askRole -- (the card's text ends before it too)
      card.askRole.order = #card.actions
      card.askRole:SetPoint("RIGHT", card.ask, "LEFT", -6, 0)
      card.ask:SetScript("OnClick", function(self)
        local g = card.group
        if not g then
          return
        end
        if Groups.MyRequest(g.id) then
          Groups.Withdraw(g.id)
        else
          Groups.Ask(g.id, card.askRole:GetValue() or "DPS", "")
        end
        BG.Sound("IG_MAINMENU_OPTION_CHECKBOX_ON")
      end)
      card:SetScript("OnClick", function()
        if card.group and not Names.IsMe(card.group.d.leader) then
          Groups.Whisper(card.group.d.leader, Groups.GroupWhisper(card.group))
        end
      end)
      card:SetScript("OnEnter", function(self)
        if not self.group or Names.IsMe(self.group.d.leader) then
          return
        end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("Clic para susurrar a " .. self.group.d.leader, 1, 1, 1)
        GameTooltip:AddLine("Envía: «" .. Groups.GroupWhisper(self.group) .. "»", C.text3[1], C.text3[2], C.text3[3], true)
        BG.ShowTip()
      end)
      card:SetScript("OnLeave", function()
        GameTooltip:Hide()
      end)
      return card
    end, function(card, g)
      card.group = g
      card:SetHeight(70)
      local inst = Instances.Any(g.d.key)
      local act = Instances.Activity(g.d.key)
      card.icon:SetTexture(act and BG.file(act.icon) or (Instances.Raid(g.d.key) and "Interface\\Icons\\Achievement_Boss_Ragnaros" or "Interface\\Icons\\INV_Misc_Key_03"))
      card.title:SetText(inst and inst.name or g.d.key)
      local note = g.d.note ~= "" and g.d.note or nil
      card.sub:SetText(BG.TF(note and "%s. Líder: %s. «%s»" or "%s. Líder: %s", missingText(Groups.Missing(g)), g.d.leader, note))
      card.right:SetText(#g.d.members .. "/" .. g.d.size)
      local mine = Names.Same(g.d.leader, Names.Me())
      local asked = Groups.MyRequest(g.id)
      local member = false
      for _, m in ipairs(g.d.members) do
        if Names.IsMe(m.name) then
          member = true
        end
      end
      card.ask:SetShown(not mine and not member)
      card.askRole:SetShown(not mine and not member and not asked)
      card.ask.text:SetText(asked and "Retirar" or "Apuntarme")
      if not mine and not member then
        card.askRole:SetOptions(myRoles())
        if not card.askRole:GetValue() then
          card.askRole:SetValue(myRoles()[1].value, true)
        end
      end
      card.right2:SetText(member and BG.colorize("dentro", C.success) or (asked and BG.colorize("pedido", C.warning) or ""))
    end)
    f.flags = UI.List(f, 58, function(list)
      local card = UI.Card(list)
      card:SetScript("OnClick", function()
        if card.flag and not Names.IsMe(card.flag.id) then
          Groups.Whisper(card.flag.id, Groups.FlagWhisper(card.flag))
        end
      end)
      card:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        if not self.flag or Names.IsMe(self.flag.id) then
          return
        end
        GameTooltip:SetText("Clic para susurrar a " .. self.flag.id, 1, 1, 1)
        GameTooltip:AddLine("Envía: «" .. Groups.FlagWhisper(self.flag) .. "»", C.text3[1], C.text3[2], C.text3[3], true)
        BG.ShowTip()
      end)
      card:SetScript("OnLeave", function()
        GameTooltip:Hide()
      end)
      return card
    end, function(card, flag)
      card.flag = flag
      card:SetHeight(52)
      BG.setClassIcon(card.icon, flag.d.class)
      local cc = BG.classColor(flag.d.class)
      card.title:SetText(flag.id)
      card.title:SetTextColor(cc[1], cc[2], cc[3])
      local target = targetName(flag.d.key) or Groups.kindName[flag.d.kind]
      card.sub:SetText(target .. ", como " .. (ROLE_NAME[flag.d.role] or "") .. (flag.d.note and flag.d.note ~= "" and (". «" .. flag.d.note .. "»") or ""))
      card.right:SetText(flag.d.level and ("nivel " .. flag.d.level) or "")
      local mins = math.max(0, math.floor((BG.Store.Now() - flag.at) / 60))
      card.right2:SetText(mins < 1 and "ahora" or ("hace " .. mins .. " min"))
    end)

    -- Leader panel (replaces the open groups while you lead one)
    local lead = CreateFrame("Frame", nil, f)
    f.lead = lead
    lead.head = UI.Heading(lead, "Tu grupo")
    lead.head:SetPoint("TOPLEFT")
    lead.head:SetPoint("TOPRIGHT")
    lead.info = UI.Text(lead, 12, C.text2, { wrap = true })
    lead.info:SetPoint("TOPLEFT", lead.head, "BOTTOMLEFT", 0, -8)
    lead.info:SetPoint("RIGHT")
    lead.close = UI.Button(lead, "Cerrar grupo", { height = 24 })
    lead.close:SetPoint("RIGHT", lead.head, "RIGHT", 0, 0) -- (on the heading's row: the text below has the width)
    lead.reqHead = UI.Text(lead, 12, C.goldTitle, { font = BG.font.display })
    lead.reqHead:SetPoint("TOPLEFT", lead.info, "BOTTOMLEFT", 0, -14)
    lead.requests = UI.List(lead, 34, function(list)
      local r = CreateFrame("Frame", nil, list)
      r.icon = r:CreateTexture(nil, "ARTWORK")
      r.icon:SetSize(18, 18)
      r.icon:SetPoint("LEFT", 2, 0)
      r.name = UI.Text(r, 12, C.text)
      r.name:SetPoint("LEFT", r.icon, "RIGHT", 6, 0)
      r.accept = UI.Button(r, "Aceptar", { height = 22, width = 80, primary = true })
      r.accept:SetPoint("RIGHT", -2, 0)
      r.decline = UI.Button(r, "Rechazar", { height = 22, width = 80 })
      r.decline:SetPoint("RIGHT", r.accept, "LEFT", -6, 0)
      r.name:SetPoint("RIGHT", r.decline, "LEFT", -8, 0)
      r.accept:SetScript("OnClick", function()
        Groups.Accept(r.req.d.group, r.req.d.name)
      end)
      r.decline:SetScript("OnClick", function()
        Groups.Decline(r.req.d.group, r.req.d.name)
      end)
      return r
    end, function(r, req)
      r.req = req
      BG.setClassIcon(r.icon, req.d.class)
      local cc = BG.classColor(req.d.class)
      r.name:SetText(BG.colorize(req.d.name, cc) .. "  " .. BG.colorize((req.d.level and ("nivel " .. req.d.level .. ", ") or "") .. (ROLE_NAME[req.d.role] or ""), C.text2))
    end)
    lead.requests:SetPoint("TOPLEFT", lead.reqHead, "BOTTOMLEFT", 0, -8)
    lead.requests:SetPoint("BOTTOMRIGHT")
    lead.close:SetScript("OnClick", function()
      if f.myGroup then
        Groups.Close(f.myGroup.id)
      end
    end)

    f.empty = UI.Text(f, 13, C.text3, { justify = "CENTER", wrap = true })
    f.flagsEmpty = UI.Text(f, 12, C.text3, { justify = "CENTER", wrap = true })

    f:SetScript("OnSizeChanged", function(self, w)
      local leftW = math.floor((w - PAD * 2 - 20) * 0.56)
      self.groupsHead:ClearAllPoints()
      self.groupsHead:SetPoint("TOPLEFT", self.strip, "BOTTOMLEFT", 0, -16)
      self.groupsHead:SetWidth(leftW)
      self.flagsHead:ClearAllPoints()
      self.flagsHead:SetPoint("TOPLEFT", self.groupsHead, "TOPRIGHT", 20, 0)
      self.flagsHead:SetPoint("RIGHT", -PAD, 0)
      self.groups:ClearAllPoints()
      self.groups:SetPoint("TOPLEFT", self.groupsHead, "BOTTOMLEFT", 0, -10)
      self.groups:SetPoint("BOTTOM", 0, 18)
      self.groups:SetWidth(leftW)
      self.lead:ClearAllPoints()
      self.lead:SetPoint("TOPLEFT", self.strip, "BOTTOMLEFT", 0, -16)
      self.lead:SetPoint("BOTTOM", 0, 18)
      self.lead:SetWidth(leftW)
      self.flags:ClearAllPoints()
      self.flags:SetPoint("TOPLEFT", self.flagsHead, "BOTTOMLEFT", 0, -10)
      self.flags:SetPoint("BOTTOMRIGHT", -PAD, 18)
      self.empty:ClearAllPoints()
      self.empty:SetPoint("TOP", self.groups, "TOP", 0, -40)
      self.empty:SetWidth(leftW - 40)
      self.flagsEmpty:ClearAllPoints()
      self.flagsEmpty:SetPoint("TOP", self.flags, "TOP", 0, -40)
      self.flagsEmpty:SetWidth(w - PAD * 2 - leftW - 60)
      self.form:ClearAllPoints()
      self.form:SetPoint("TOPLEFT", self.strip, "BOTTOMLEFT", 0, -10)
      self.form:SetPoint("BOTTOMRIGHT", -PAD, 18)
    end)
    f.form = buildForm(f)

    f.createBtn:SetScript("OnClick", function()
      f.form:Open()
    end)
    strip.raise:SetScript("OnClick", function()
      if Groups.MyFlag() then
        Groups.LowerFlag()
      else
        local r, why = Groups.RaiseFlag(strip.kind:GetValue() or "DUNGEON", strip.target:GetValue(), strip.role and strip.role:GetValue() or "DPS", strip.note:GetText())
        if not r then
          strip.status:SetText(BG.colorize(why == "consent" and "Acepta antes la privacidad (/bg privacidad)." or ("No se pudo (" .. tostring(why) .. ")."), C.danger))
          return
        end
      end
      BG.Sound("IG_MAINMENU_OPTION_CHECKBOX_ON")
    end)
  end,

  Refresh = function(f)
    local me = BG.Guild.me
    local strip = f.strip
    if not strip.role and me then
      strip.role = UI.Segmented(strip.roleHolder, myRoles(), { itemWidth = 94 })
      strip.role:SetPoint("LEFT")
      strip.role:SetValue(myRoles()[1].value, true)
      strip.roleHolder:SetWidth(strip.role:GetWidth())
    end
    local kind = strip.kind:GetValue()
    if kind ~= strip.loadedKind then
      strip.loadedKind = kind
      strip.target:SetOptions(kind == "DUNGEON" and targetOptions(me and me.level, BG.Guild.info and BG.Guild.info.faction, false)
        or (kind == "RAID" and targetOptions(60, nil, true) or {}))
      strip.target:SetValue(nil, true)
      strip.target:SetShown(kind == "DUNGEON" or kind == "RAID")
    end

    local flag = Groups.MyFlag()
    local editing = flag == nil
    for _, w in ipairs({ strip.kind, strip.target, strip.roleHolder, strip.note }) do
      w:SetShown(editing and (w ~= strip.target or kind == "DUNGEON" or kind == "RAID"))
    end
    strip.status:SetShown(not editing)
    if flag then
      local left = math.max(0, math.floor(((flag.exp or 0) - BG.Store.Now()) / 60))
      strip.status:SetText("Buscas grupo: " .. (targetName(flag.d.key) or Groups.kindName[flag.d.kind]) .. ", como " .. ROLE_NAME[flag.d.role]
        .. ". Toda la hermandad lo ve. Se quita sola en " .. left .. " min.")
    end
    strip.raise.text:SetText(flag and "Bajar bandera" or "Levantar bandera")
    strip.raise:SetEnabled(BG.Consent.Accepted())

    local mine = Groups.Mine()
    f.myGroup = mine
    f.createBtn:SetShown(not mine and BG.Consent.Accepted() and not f.form:IsShown())
    local formOpen = f.form:IsShown()
    f.lead:SetShown(mine ~= nil and not formOpen)
    f.groups:SetShown(mine == nil and not formOpen)
    f.groupsHead:SetShown(mine == nil and not formOpen)
    f.flags:SetShown(not formOpen)
    f.flagsHead:SetShown(not formOpen)
    local open = Groups.Open()
    f.groups:SetItems(open)
    f.empty:SetShown(mine == nil and not formOpen and #open == 0)
    f.empty:SetText(BG.Consent.Accepted() and "No hay grupos abiertos ahora. Crea uno y tu hermandad podrá apuntarse por rol desde el juego."
      or "Los grupos se comparten entre los addons de tu hermandad. Acepta la privacidad para verlos (/bg privacidad).")
    if mine then
      local inst = Instances.Any(mine.d.key)
      local names = {}
      for _, m in ipairs(mine.d.members) do
        names[#names + 1] = m.name .. " (" .. ROLE_NAME[m.role] .. ")"
      end
      f.lead.head.title:SetText("Tu grupo: " .. (inst and inst.name or mine.d.key))
      f.lead.info:SetText(missingText(Groups.Missing(mine)):gsub("^%l", string.upper) .. ". Dentro: " .. table.concat(names, ", ") .. ".")
      local reqs = Groups.Requests(mine.id)
      f.lead.reqHead:SetText(#reqs == 0 and "Sin peticiones todavía" or ("Peticiones (" .. #reqs .. ")"))
      f.lead.requests:SetItems(reqs)
    end
    local flags = Groups.Flags()
    f.flags:SetItems(flags)
    f.flagsEmpty:SetShown(#flags == 0 and not formOpen)
    f.flagsEmpty:SetText("Nadie ha levantado bandera. Levanta la tuya arriba y la hermandad sabrá que buscas grupo.")
  end,
})

BG:On("BG_STORE_CHANGED", function(name)
  if name == "flags" or name == "groups" or name == "requests" then
    BG:RefreshView("dungeons")
  end
end)
