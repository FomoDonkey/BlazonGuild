-- Armería (the menu's slot that said «Pronto» until 0.20.0). Left: the members, the best item level first, with where
-- we know their equipment from (they share it, or you saw it). Right: the chosen one, slot by slot (icon, name in its
-- quality's colour, the game's tooltip on hover), their professions and whether they wear the tabard; for yourself,
-- the switch to share your equipment; for someone near you, «Inspeccionar».
local _, BG = ...
local UI, C = BG.UI, BG.color
local A, Names = BG.Armory, BG.Names

local PAD = 24
local ROW = 21
local QUALITY = { [0] = { 0.62, 0.62, 0.62 }, [1] = { 1, 1, 1 }, [2] = { 0.12, 1, 0 }, [3] = { 0, 0.44, 0.87 }, [4] = { 0.64, 0.21, 0.93 },
  [5] = { 1, 0.5, 0 }, [6] = { 0.9, 0.8, 0.5 } }
local WHY = { lejos = "Tiene que estar cerca de ti (tu objetivo, el ratón encima o en tu grupo).", combate = "No se puede en combate.",
  ventana = "Cierra antes la ventana de inspección del juego.", ocupado = "Espera un momento: hay otra inspección en marcha.",
  no = "El juego no deja inspeccionarle ahora.",
  ["sin addon"] = "El juego solo deja inspeccionar de cerca (unos 30 metros). Desde lejos solo se ve el equipo de quien tiene BlazonGuild: acércate a él, o pídele que lo instale.",
  ["ya pedido"] = "Ya se lo has pedido: espera su respuesta.", capturas = "En el modo capturas no se hace nada en el juego: es solo una hermandad de ejemplo." }

local function plate(f, title)
  local p = UI.Plate(f, { corners = 18, rail = 0.24 })
  p.head = UI.Heading(p, title)
  p.head:SetPoint("TOPLEFT", 16, -8)
  p.head:SetPoint("TOPRIGHT", -16, -8)
  return p
end

local function className(file)
  return file and ((LOCALIZED_CLASS_NAMES_MALE and LOCALIZED_CLASS_NAMES_MALE[file]) or BG.Recruit.CLASS_NAMES[file]) or nil
end

local function ago(t)
  local days = (BG.Store.Now() - (t or 0)) / 86400
  return UI.Ago(days)
end

local function sourceText(g)
  if not g then
    return "sin datos"
  end
  return g.source == "shared" and ("lo comparte, " .. ago(g.at)) or ("visto por ti, " .. ago(g.at))
end

local function memberRow(list, f)
  local c = UI.Card(list)
  c:SetScript("OnClick", function(self)
    if self.item then
      f.selected = self.item.name
      BG.Sound("U_CHAT_SCROLL_BUTTON")
      BG:RefreshView("armory")
    end
  end)
  return c
end

local function fillMember(c, x, f)
  c.item = x
  c.key = "arm:" .. x.name
  c:SetHeight(50)
  BG.setClassIcon(c.icon, x.m.classFile)
  c.title:SetText(BG.colorize(x.name, BG.classColor(x.m.classFile)))
  c.sub:SetText("Nivel " .. (x.m.level or "?") .. (className(x.m.classFile) and (", " .. className(x.m.classFile)) or ""))
  c.right:SetText(x.il and BG.colorize("Nivel de objeto " .. x.il, C.gold) or "")
  c.right2:SetText(sourceText(x.gear))
  local on = f.selected ~= nil and Names.Same(f.selected, x.name)
  c:SetSelected(on)
  c.accent:SetShown(on)
end

-- The game's comparison windows («Equipado»: what you wear, beside an item's tooltip; with Shift held, or always if
-- the player chose so). On your own slots they would show the same item twice (Peregrino: «sale duplicado»): there they
-- close as they open. Someone else's item keeps them: comparing is what they are for.
local hooked, ours = {}, setmetatable({}, { __mode = "k" })
local function noCompare()
  for _, t in ipairs((GameTooltip and GameTooltip.shoppingTooltips) or {}) do
    if not hooked[t] then
      hooked[t] = true
      t:HookScript("OnShow", function(self)
        local owner = GameTooltip:GetOwner()
        if owner and ours[owner] and owner.mine then
          self:Hide()
        end
      end)
    end
    t:Hide()
  end
end

local function slotRow(parent)
  local r = CreateFrame("Button", nil, parent)
  r:SetHeight(ROW - 2)
  r.icon = r:CreateTexture(nil, "ARTWORK")
  r.icon:SetSize(18, 18)
  r.icon:SetPoint("LEFT")
  r.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
  r.slot = UI.Text(r, 10, C.text3)
  r.slot:SetPoint("LEFT", r.icon, "RIGHT", 6, 0)
  r.slot:SetWidth(78)
  r.name = UI.Text(r, 12, C.text)
  r.name:SetPoint("LEFT", r.slot, "RIGHT", 4, 0)
  r.name:SetPoint("RIGHT", -2, 0)
  ours[r] = true
  r:SetScript("OnEnter", function(self)
    if not (GameTooltip and self.itemId) then
      return
    end
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    local worn = self.mine and select(2, pcall(GetInventoryItemID, "player", self.slotId))
    if worn == self.itemId and GameTooltip.SetInventoryItem then
      GameTooltip:SetInventoryItem("player", self.slotId) -- (yours as it is: bound, its durability)
    elseif GameTooltip.SetHyperlink then
      GameTooltip:SetHyperlink("item:" .. self.itemId .. ":" .. (self.ench or 0))
    else
      GameTooltip:SetText(self.label or "")
    end
    BG.ShowTip()
    if self.mine then
      noCompare()
    end
  end)
  r:SetScript("OnLeave", function()
    if GameTooltip then
      GameTooltip:Hide()
    end
  end)
  return r
end

-- The slots in two columns, as wide as the panel is now (it is measured again whenever it changes size: the first
-- time the screen is drawn the members' column has no width yet, and the slots took the whole screen).
local function placeSlots(f)
  local width = f.right:GetWidth() or 0
  if width <= 0 then
    return
  end
  local colW = math.floor((width - 32 - 12) / 2)
  local half = math.ceil(#A.SLOTS / 2)
  for i in ipairs(A.SLOTS) do
    local r = f.slots[i]
    local col, row = i <= half and 0 or 1, i <= half and (i - 1) or (i - half - 1)
    r:ClearAllPoints()
    r:SetPoint("TOPLEFT", f.who, "BOTTOMLEFT", col * (colW + 12), -10 - row * ROW)
    r:SetWidth(colW)
  end
end

BG:RegisterView("armory", {
  Build = function(f)
    f.hero = UI.Hero(f, 108)
    f.hero:SetPoint("TOPLEFT")
    f.hero:SetPoint("TOPRIGHT")

    local left = plate(f, "Miembros")
    left:SetPoint("TOPLEFT", f.hero, "BOTTOMLEFT", PAD, -16)
    left:SetPoint("BOTTOMLEFT", PAD, 18)
    f.left = left
    f.list = UI.List(left, 54, function(list)
      return memberRow(list, f)
    end, function(c, x)
      fillMember(c, x, f)
    end)
    f.list:SetPoint("TOPLEFT", left.head, "BOTTOMLEFT", 0, -10)
    f.list:SetPoint("BOTTOMRIGHT", -16, 14)

    local right = plate(f, "")
    right:SetPoint("TOPLEFT", left, "TOPRIGHT", 18, 0)
    right:SetPoint("BOTTOMRIGHT", -PAD, 18)
    f.right = right
    f.who = UI.Text(right, 12, C.text2, { wrap = true })
    f.who:SetPoint("TOPLEFT", right.head, "BOTTOMLEFT", 0, -4)
    f.who:SetPoint("RIGHT", -16, 0)
    f.who:SetMaxLines(2)
    f.slots = {}
    for i = 1, #A.SLOTS do
      f.slots[i] = slotRow(right)
    end
    f.extra = UI.Text(right, 12, C.text2, { wrap = true })
    f.extra:SetMaxLines(3)
    f.empty = UI.Text(right, 12, C.text3, { wrap = true })
    f.empty:SetPoint("TOPLEFT", f.who, "BOTTOMLEFT", 0, -14)
    f.empty:SetPoint("RIGHT", -16, 0)
    f.empty:SetSpacing(4)

    f.share = UI.Button(right, "", { height = 26 })
    f.share:SetPoint("BOTTOMLEFT", 16, 14)
    f.share:SetScript("OnClick", function()
      local on = not A.Sharing()
      A.SetSharing(on)
      BG:Notify(on and "Compartes tu equipo" or "Ya no compartes tu equipo",
        on and "Tu hermandad ve lo que llevas puesto en la Armería; se actualiza cuando cambias algo." or "Se ha quitado de la Armería de tus compañeros.",
        { kind = "success", view = "armory" })
      BG:RefreshView("armory")
    end)
    f.inspect = UI.Button(right, "Ver su equipo", { height = 26, width = 150 })
    f.inspect:SetPoint("BOTTOMRIGHT", -16, 14)
    f.inspect:SetScript("OnClick", function()
      local ok, how = A.Look(f.selected)
      if not ok then
        BG:Notify("No se pudo ver su equipo", WHY[how] or tostring(how), { kind = "warning", view = "armory" })
      elseif how == "asked" then
        BG:Notify("Se lo hemos pedido", "Está lejos: le llega la pregunta y, si dice que sí, verás su equipo aquí.", { kind = "info", view = "armory" })
      end
    end)
    f.note = UI.Text(right, 11, C.text3, { wrap = true })
    f.note:SetPoint("BOTTOMLEFT", f.share, "TOPLEFT", 0, 8)
    f.note:SetPoint("RIGHT", -16, 0)
    f.note:SetMaxLines(2)

    f:SetScript("OnSizeChanged", function(self, w)
      self.left:SetWidth(math.floor((w - PAD * 2 - 18) * 0.42))
    end)
    right:HookScript("OnSizeChanged", function()
      placeSlots(f)
    end)
  end,

  Refresh = function(f)
    f.hero:SetArt(BG.file("Interface\\Glues\\LoadingScreens\\LoadScreenBlackwingLair", BG.art.RAID), 0.45)
    f.hero:SetIcon(BG.file("Interface\\Icons\\INV_Chest_Plate04", "Interface\\Icons\\INV_Misc_Note_02"))
    f.hero.title:SetText("Armería")
    local sum = A.Summary()
    f.hero.sub:SetText(sum.shared .. (sum.shared == 1 and " miembro comparte" or " miembros comparten") .. " su equipo"
      .. (sum.avg and (". Nivel de objeto medio de los que conoces: " .. sum.avg .. ".") or "."))

    local members = A.Members()
    if not f.selected then
      f.selected = Names.Me()
    end
    f.list:SetItems(members)

    local me = Names.Me()
    local x
    for _, m in ipairs(members) do
      if Names.Same(m.name, f.selected) then
        x = m
      end
    end
    local mine = me ~= nil and f.selected ~= nil and Names.Same(f.selected, me)
    f.right.head:SetText(x and BG.colorize(x.name, BG.classColor(x.m.classFile)) or "Nadie elegido")
    local g = x and x.gear
    local cls = x and className(x.m.classFile)
    f.who:SetText(x and ((cls or "Personaje") .. " de nivel " .. (x.m.level or "?") .. (g and g.il and (", nivel de objeto " .. g.il) or "")
      .. ". " .. (g and (g.source == "shared" and "Lo comparte él mismo (" .. ago(g.at) .. ")." or "Lo viste tú (" .. ago(g.at) .. ").") or "Aún no se sabe qué lleva.")) or "")

    -- slots in two columns
    placeSlots(f)
    local half = math.ceil(#A.SLOTS / 2)
    for i, s in ipairs(A.SLOTS) do
      local r = f.slots[i]
      local item = g and g.slots[s.id]
      r:SetShown(g ~= nil)
      r.slot:SetText(s.name)
      r.itemId, r.ench, r.slotId, r.mine = item and item.id, item and item.ench, s.id, mine
      if item then
        local info = A.Item(item.id)
        r.icon:SetTexture(info.icon or "Interface\\Icons\\INV_Misc_QuestionMark")
        local q = QUALITY[info.quality or 1] or QUALITY[1]
        r.label = info.name or ("Objeto " .. item.id)
        r.name:SetText(BG.colorize(r.label, q) .. (item.ench and BG.colorize("  +", C.success) or ""))
      else
        r.icon:SetTexture("Interface\\PaperDoll\\UI-Backpack-EmptySlot")
        r.label = nil
        r.name:SetText(BG.colorize("vacío", C.text3))
      end
    end
    f.extra:ClearAllPoints()
    f.extra:SetPoint("TOPLEFT", f.who, "BOTTOMLEFT", 0, -10 - half * ROW - 8)
    f.extra:SetPoint("RIGHT", -16, 0)
    local profs = x and A.Professions(x.name) or {}
    local tabard = g and g.slots[19]
    f.extra:SetShown(g ~= nil or #profs > 0)
    f.extra:SetText((#profs > 0 and ("Profesiones: " .. table.concat(profs, ", ") .. ". ") or "")
      .. (g and (tabard and "Lleva un tabardo." or "No lleva tabardo.") or ""))
    f.empty:SetShown(x ~= nil and g == nil)
    f.empty:SetText(mine and "Aún no compartes tu equipo. Pulsa «Compartir mi equipo» y tu hermandad verá lo que llevas puesto (se actualiza solo cuando cambias algo)."
      or "No lo comparte. Pulsa «Ver su equipo»: si está cerca, lo inspeccionas; si está lejos y tiene BlazonGuild, se lo pedimos."
      .. (#profs > 0 and ("\n\nProfesiones: " .. table.concat(profs, ", ") .. ".") or ""))

    f.share:SetShown(mine)
    f.share:SetWidth(250)
    f.share:SetText(A.Sharing() and "Compartir mi equipo: sí" or "Compartir mi equipo: no")
    f.inspect:SetShown(x ~= nil and not mine)
    local status = x and A.lastStatus[x.name]
    f.note:SetShown(mine or status ~= nil)
    f.note:SetText(mine and "Solo lo que llevas puesto, como lo ve cualquiera que te inspeccione en el juego."
      or (status == "pedido" and "Pidiendo su equipo al juego…" or status == "sin respuesta" and "El juego no respondió; acércate y vuelve a probar."
        or status == "visto" and "Visto ahora: solo lo ves tú." or status == "preguntado" and "Le hemos preguntado si lo comparte; esperando su respuesta."
        or status == "compartido" and "Lo comparte: ya lo ves aunque esté lejos." or status == "no quiere" and "Prefiere no compartirlo; inspecciónale cuando esté cerca." or ""))
  end,
})

BG:On("BG_ARMORY_CHANGED", function()
  if BG.window and BG.window:IsShown() and BG.db.settings.lastView == "armory" then
    BG:RefreshView("armory")
  end
end)
