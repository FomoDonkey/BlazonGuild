-- La Arena: three tabs. Clasificación (the season's fighters: rating, tier, record, the champion's belt); Retos (members
-- online with BlazonGuild to challenge, the challenges you got with «Aceptar» and «No»); Combates (the season's duels,
-- with «Quitar» for the loser and the organisers). Right: the season, its tiers in plain words, the past seasons, and
-- «Nueva temporada» for the organisers. No gold, no bets.
local _, BG = ...
local UI, C = BG.UI, BG.color
local A, Names, Store = BG.Arena, BG.Names, BG.Store

local PAD = 24
local TIER_COLOR = { gold = { 1, 0.82, 0.3 }, silver = { 0.82, 0.84, 0.88 }, bronze = { 0.8, 0.52, 0.3 } }

local function why(w)
  return ({ permiso = "Solo los oficiales pueden hacerlo.", ["sin addon"] = "Tiene que estar conectado y con BlazonGuild.", espera = "Ya le has retado hace un momento.",
    ["no existe"] = "Ya no existe.", ["tú mismo"] = "No puedes retarte a ti mismo.", ["no es de tu hermandad"] = "No es de tu hermandad." })[w] or ("No se pudo (" .. tostring(w) .. ").")
end

local function plate(f, title)
  local p = UI.Plate(f, { corners = 18, rail = 0.24 })
  p.head = UI.Heading(p, title)
  p.head:SetPoint("TOPLEFT", 16, -8)
  p.head:SetPoint("TOPRIGHT", -16, -8)
  return p
end

local function results(recent)
  local out = {}
  for _, r in ipairs(recent or {}) do
    out[#out + 1] = r == "V" and BG.colorize("V", C.success) or BG.colorize("D", C.danger)
  end
  return table.concat(out, " ")
end

-- Cards ---------------------------------------------------------------------------------------------------------
local function fighterRow(list)
  local c = UI.Card(list)
  c.face = UI.CardButton(c, "Cara a cara", { height = 22, width = 104 })
  c.face:SetPoint("BOTTOMRIGHT", -10, 6)
  c.right2:ClearAllPoints()
  c.right2:SetPoint("RIGHT", c.face, "LEFT", -8, 0) -- (the last results, beside the button)
  c.face:SetScript("OnClick", function()
    if c.fighter then
      BG.UI.FaceOff(Names.Me(), c.fighter)
    end
  end)
  return c
end

local function fillFighter(c, f)
  local b = A.Build()
  c.key = "f:" .. f.name
  c.fighter = f.name
  c.face:SetShown(not Names.Same(f.name, Names.Me() or ""))
  c:SetHeight(58)
  local m = BG.Guild.Find(f.name)
  local champ = b.belt == f.name
  if champ then
    c.icon:SetTexture(BG.file("Interface\\Icons\\INV_Belt_13", "Interface\\Icons\\INV_Misc_Ribbon_01"))
  else
    BG.setClassIcon(c.icon, m and m.classFile)
  end
  c.title:SetText((f.place and (f.place .. ". ") or "") .. BG.colorize(f.name, BG.classColor(m and m.classFile)) .. (champ and BG.colorize("  campeón", C.gold) or ""))
  local tier = f.tier and BG.colorize(f.tier.label, TIER_COLOR[f.tier.key]) or BG.colorize(f.fights < A.R.RANKED_MIN and ("le faltan " .. (A.R.RANKED_MIN - f.fights) .. " combates para tener rango") or "sin rango", C.text3)
  c.sub:SetText(BG.TF(f.streak >= 2 and "%s, %d-%d, racha de %d" or "%s, %d-%d", tier, f.wins, f.losses, f.streak))
  c.right:SetText(BG.colorize(tostring(f.rating), C.goldTitle))
  c.right2:SetText(results(f.recent))
  local detail = { "Últimos combates (el más reciente primero): " .. (#f.recent > 0 and table.concat(f.recent, " ") or "ninguno") .. " (V victoria, D derrota)." }
  if f.best then
    detail[#detail + 1] = "Su mejor victoria: contra " .. f.best.name .. ", que tenía " .. f.best.rating .. "."
  end
  if f.last then
    detail[#detail + 1] = "Último combate: " .. UI.FormatDate(f.last, true) .. "."
  end
  c.detail = detail
end

local function rivalRow(list)
  local c = UI.Card(list)
  c.go = UI.CardButton(c, "Retar", { height = 22, width = 70, primary = true })
  c.go:SetPoint("BOTTOMRIGHT", -10, 8)
  c.go:SetScript("OnClick", function()
    if c.rival then
      local ok, w = A.Challenge(c.rival.name)
      BG:Notify(ok and "Reto enviado" or "No se pudo", ok and (c.rival.name .. " lo verá ahora. Si acepta, te avisamos.") or why(w), { kind = ok and "success" or "warning" })
    end
  end)
  c.right:ClearAllPoints()
  c.right:SetPoint("TOPRIGHT", -12, -10)
  return c
end

local function fillRival(c, r)
  c.rival = r
  c.key = "r:" .. r.name
  c:SetHeight(58)
  BG.setClassIcon(c.icon, r.class)
  c.title:SetText(BG.colorize(r.name, BG.classColor(r.class)) .. (A.Accepted(r.name) and BG.colorize("  reto aceptado", C.success) or ""))
  c.sub:SetText(r.addon and ("Nivel " .. (r.level or "?") .. (r.zone and r.zone ~= "" and (", en " .. r.zone) or "") .. (r.near and ", cerca de ti" or ""))
    or BG.colorize("No tiene BlazonGuild: no se le puede retar y su duelo no contaría", C.text3))
  c.right:SetText(r.addon and (r.f and tostring(r.f.rating) or "nuevo") or "")
  c.right2:SetText("")
  c.go:SetShown(r.addon)
  c.detail = r.addon and { r.f and ("En la Arena: " .. A.Summary(r.name) .. ".") or "Aún no ha peleado esta temporada.",
    A.Accepted(r.name) and "Reto aceptado: retadle desde el juego (clic derecho en su retrato, «Duelo»)." or "«Retar» le manda tu reto; el duelo lo empezáis desde el juego." }
    or { "Nivel " .. (r.level or "?") .. (r.zone and r.zone ~= "" and (", en " .. r.zone) or "") .. ".", "Si instala BlazonGuild, podréis retaros y sus duelos contarán en la clasificación." }
end

local function challengeRow(list)
  local c = UI.Card(list)
  c.no = UI.CardButton(c, "No", { height = 22, width = 50 })
  c.no:SetPoint("BOTTOMRIGHT", -10, 8)
  c.yes = UI.CardButton(c, "Aceptar", { height = 22, width = 80, primary = true })
  c.yes:SetPoint("RIGHT", c.no, "LEFT", -6, 0)
  for _, b in ipairs({ c.yes, c.no }) do
    b:SetScript("OnClick", function()
      if c.ch then
        A.Answer(c.ch.name, b == c.yes)
      end
    end)
  end
  return c
end

local function fillChallenge(c, ch)
  c.ch = ch
  c.key = "c:" .. ch.name
  c:SetHeight(58)
  local m = BG.Guild.Find(ch.name)
  BG.setClassIcon(c.icon, m and m.classFile)
  c.title:SetText(BG.colorize(ch.name, BG.classColor(m and m.classFile)) .. " te reta")
  c.sub:SetText(ch.note and ch.note ~= "" and ("«" .. ch.note .. "»") or (A.Summary(ch.name) or "Aún no ha peleado esta temporada."))
  c.right:SetText("")
  c.right2:SetText("")
  c.detail = { "Si aceptas, os avisamos a los dos. El duelo lo empezáis desde el juego: clic derecho en su retrato, «Duelo»." }
end

local function duelRow(list)
  local c = UI.Card(list)
  c.remove = UI.CardButton(c, "Quitar", { height = 22, width = 70 })
  c.remove:SetPoint("BOTTOMRIGHT", -10, 8)
  c.remove:SetScript("OnClick", function()
    if c.row then
      local ok, w = A.Remove(c.row.id)
      if not ok then
        BG:Notify("No se pudo", why(w), { kind = "warning" })
      end
    end
  end)
  c.right:ClearAllPoints()
  c.right:SetPoint("TOPRIGHT", -12, -10)
  return c
end

local function fillDuel(c, r)
  c.row = r
  c.key = r.id
  c:SetHeight(58)
  c.icon:SetTexture("Interface\\Icons\\Ability_DualWield")
  local wm, lm = BG.Guild.Find(r.d.w), BG.Guild.Find(r.d.l)
  c.title:SetText(BG.colorize(r.d.w, BG.classColor(wm and wm.classFile)) .. " ganó a " .. BG.colorize(r.d.l, BG.classColor(lm and lm.classFile)))
  local how = BG.T(r.d.m == "F" and "Se rindió" or "Por K.O.")
  if r.d.zone then
    how = BG.TF("%s, en %s", how, r.d.zone)
  end
  if r.delta then
    how = BG.TF("%s, +%s y -%s", how, r.delta.gain, r.delta.loss)
  end
  c.sub:SetText(how)
  c.right:SetText(UI.FormatDate(r.at, true))
  c.right2:SetText("")
  c.detail = { "Lo apuntó el addon de " .. r.d.l .. ", que perdió: solo quien pierde apunta el combate, para que nadie se dé victorias.",
    "Si es un error, " .. r.d.l .. " o un oficial puede quitarlo." }
  c.remove:SetShown(A.CanRemove(r))
end


-- Torneos y veladas -------------------------------------------------------------------------------------------------
local Tn = BG.Tourney
local CUP_STATE = { OPEN = "Inscripción abierta", RUNNING = "En juego", CANCELLED = "Cancelado" }
local CUP_WHY = { cerrado = "Las inscripciones ya están cerradas.", lleno = "Ya está lleno.", pocos = "Hacen falta al menos 2 apuntados.",
  sorteando = "Ya se está sorteando.", ["sin juego"] = "Este cliente no deja tirar /roll a los addons.", ["vacía"] = "Añade antes algún combate.",
  igual = "Elige a dos luchadores distintos.", permiso = "Solo quien lo dirige y los oficiales pueden hacerlo." }

local function cupWhy(w, extra)
  if w == "no es de tu hermandad" then
    return "«" .. tostring(extra or "") .. "» no es de tu hermandad."
  end
  return CUP_WHY[w] or why(w)
end

local function cupRow(list, f)
  local c = UI.Card(list)
  c:SetScript("OnClick", function(self)
    if self.t then
      f.tsel = self.t.id
      BG.Sound("IG_MAINMENU_OPTION")
      BG:RefreshView("arena")
    end
  end)
  return c
end

local function fillCup(c, t, f)
  c.t = t
  c.key = "t:" .. t.id
  c:SetHeight(58)
  local night = t.d.kind == "NIGHT"
  c.icon:SetTexture(BG.file(night and "Interface\\Icons\\Ability_Warrior_BattleShout" or "Interface\\Icons\\INV_Misc_Trophy_03", "Interface\\Icons\\Ability_DualWield"))
  c.title:SetText(t.d.title)
  local champ = Tn.Champion(t)
  local sub = night and ("Velada, " .. #t.d.bouts .. (#t.d.bouts == 1 and " combate" or " combates"))
    or ("Torneo, " .. (t.d.state == "OPEN" and (#Tn.Entries(t.id) .. " de " .. t.d.size .. " apuntados") or (#t.d.order .. " luchadores")))
  if t.d.when and t.d.when ~= "" then
    sub = sub .. ", " .. t.d.when
  end
  c.sub:SetText(sub)
  c.right:SetText(champ and BG.colorize("Terminado", C.gold) or (CUP_STATE[t.d.state] or ""))
  c.right2:SetText(champ or "")
  c:SetSelected(f.tsel == t.id)
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
  end)
  return form
end

local function buildCupForm(f)
  local form = overlay(f, "Nuevo torneo o velada")
  local l1 = form:Label("Qué es")
  form.kind = UI.Segmented(form, { { value = "CUP", label = "Torneo" }, { value = "NIGHT", label = "Velada" } }, { itemWidth = 110, onChange = function(v)
    form.sizeLabel:SetShown(v == "CUP")
    form.size:SetShown(v == "CUP")
    form.kindNote:SetText(v == "CUP" and "Torneo: cada uno se apunta; al sortear sale el cuadro eliminatorio." or "Velada: tú anuncias los combates (A contra B) y cada duelo decide el suyo.")
  end })
  form.kind:SetPoint("TOPLEFT", l1, "BOTTOMLEFT", 0, -6)
  form.kindNote = UI.Text(form, 11, C.text3, { wrap = true })
  form.kindNote:SetPoint("TOPLEFT", form.kind, "BOTTOMLEFT", 0, -6)
  form.kindNote:SetPoint("RIGHT", -22, 0)
  local l2 = form:Label("Nombre", form.kindNote, -12)
  form.title = UI.EditBox(form, { width = 320, maxLetters = 50, placeholder = "Por ejemplo: Torneo de los viernes" })
  form.title:SetPoint("TOPLEFT", l2, "BOTTOMLEFT", 0, -6)
  local l3 = form:Label("Cuándo (para que la gente se organice)", form.title, -12)
  form.when = UI.EditBox(form, { width = 320, maxLetters = 40, placeholder = "Por ejemplo: sábado a las 22:00, en Ventormenta" })
  form.when:SetPoint("TOPLEFT", l3, "BOTTOMLEFT", 0, -6)
  form.sizeLabel = form:Label("Cuántos luchadores como mucho", form.when, -12)
  form.size = UI.Segmented(form, { { value = 4, label = "4" }, { value = 8, label = "8" }, { value = 16, label = "16" } }, { itemWidth = 60 })
  form.size:SetPoint("TOPLEFT", form.sizeLabel, "BOTTOMLEFT", 0, -6)
  form.save = UI.Button(form, "Crear", { primary = true, height = 30, width = 120 })
  form.save:SetPoint("RIGHT", form.back, "LEFT", -10, 0)
  form.save:SetScript("OnClick", function()
    local r, w = Tn.Create({ kind = form.kind:GetValue(), title = form.title:GetText(), when = form.when:GetText(), size = form.size:GetValue() })
    if not r then
      form.error:SetText(cupWhy(w))
      return
    end
    f.tsel = r.id
    form:Hide()
    BG:RefreshView("arena")
  end)
  function form:Open()
    self.kind:SetValue("CUP")
    self.size:SetValue(8, true)
    self.title:SetText("")
    self.when:SetText("")
    self.error:SetText("")
    self:Show()
  end
  return form
end

-- The guild's members for a picker, alphabetically, with level and whether they are online; `filter` (what is
-- typed) keeps those whose name has it.
local function memberOptions(filter)
  local q = (filter or ""):lower()
  local out = {}
  for _, m in ipairs(BG.Guild.members or {}) do
    local n = Names.Short(m.name)
    if n and (q == "" or n:lower():find(q, 1, true)) then
      out[#out + 1] = { value = n, label = BG.colorize(n, BG.classColor(m.classFile)),
        note = "nivel " .. (m.level or "?") .. (m.online and ", conectado" or "") }
    end
  end
  table.sort(out, function(a, b)
    return a.value < b.value
  end)
  return out
end

-- One fighter: a box to type in (it narrows the list) and the list of members to pick from (it fills the box).
local function fighterField(form, label, anchor, y)
  local l = form:Label(label, anchor, y)
  local box = UI.EditBox(form, { width = 240, maxLetters = 40, placeholder = "Escribe para buscar…" })
  box:SetPoint("TOPLEFT", l, "BOTTOMLEFT", 0, -6)
  local pick = UI.Picker(form, { width = 260, placeholder = "O elígelo de la lista", onChange = function(v)
    box:SetText(v)
  end, fill = function()
    return memberOptions(box:GetText())
  end, empty = "Nadie de la hermandad se llama así. Borra lo escrito para ver a todos." })
  pick:SetPoint("LEFT", box, "RIGHT", 10, 0)
  box.edit:HookScript("OnTextChanged", function(self)
    pick:SetOptions(memberOptions(self:GetText()))
  end)
  box.pick = pick
  return box
end

local function buildBoutForm(f)
  local form = overlay(f, "Añadir un combate a la velada")
  form.a = fighterField(form, "Luchador 1")
  form.b = fighterField(form, "Luchador 2", form.a, -12)
  form.hint = UI.Text(form, 11, C.text3, { wrap = true })
  form.hint:SetPoint("TOPLEFT", form.b, "BOTTOMLEFT", 0, -12)
  form.hint:SetPoint("RIGHT", -22, 0)
  form.hint:SetText("Elige a cada luchador de la lista (los miembros, por orden alfabético), o escribe parte de su nombre y la lista se queda solo con los que coinciden.")
  form.save = UI.Button(form, "Añadir", { primary = true, height = 30, width = 120 })
  form.save:SetPoint("RIGHT", form.back, "LEFT", -10, 0)
  form.save:SetScript("OnClick", function()
    local r, w, extra = Tn.AddBout(f.tsel, form.a:GetText(), form.b:GetText())
    if not r then
      form.error:SetText(cupWhy(w, extra))
      return
    end
    form:Hide()
  end)
  function form:Open()
    for _, box in ipairs({ self.a, self.b }) do
      box:SetText("")
      box.pick:SetOptions(memberOptions(""))
      box.pick:SetValue(nil, true)
    end
    self.error:SetText("")
    self:Show()
  end
  form.MemberOptions = memberOptions
  return form
end

-- What the right plate says about the selected one, and which buttons it shows: { { label, fn, primary } }.
local function cupDetail(f, t)
  local lines, buttons = {}, {}
  local manage = Tn.CanManage(t)
  local night = t.d.kind == "NIGHT"
  lines[#lines + 1] = (night and "Velada" or "Torneo") .. " que dirige " .. tostring(Tn.Director(t)) .. "." .. (t.d.when and t.d.when ~= "" and (" " .. t.d.when .. ".") or "")
  if t.d.state == "CANCELLED" then
    lines[#lines + 1] = BG.colorize("Cancelado.", C.warning)
  elseif night then
    local bouts = Tn.Bouts(t)
    if #bouts == 0 then
      lines[#lines + 1] = "Aún no hay combates." .. (manage and " Añádelos con «Añadir combate»." or "")
    end
    for i, o in ipairs(bouts) do
      lines[#lines + 1] = i .. ". " .. o.a .. " contra " .. o.b .. ": " .. (o.winner and BG.colorize("gana " .. o.winner, C.success) or (t.d.state == "RUNNING" and "por decidir" or "aún no empieza"))
    end
    if t.d.state == "RUNNING" then
      lines[#lines + 1] = BG.colorize("En juego: cada combate lo decide el primer duelo entre los dos.", C.text3)
      for _, o in ipairs(bouts) do
        if not o.winner then
          buttons[#buttons + 1] = { "Cara a cara del siguiente combate", function()
            BG.UI.FaceOff(o.a, o.b)
          end }
          break
        end
      end
    elseif manage then
      buttons[#buttons + 1] = { "Empezar la velada", function()
        local ok, w = Tn.StartNight(t.id)
        if not ok then
          BG:Notify("No se pudo", cupWhy(w), { kind = "warning" })
        end
      end, true }
      buttons[#buttons + 1] = { "Añadir combate", function()
        f.boutForm:Open()
      end }
    end
  elseif t.d.state == "OPEN" then
    local entries = Tn.Entries(t.id)
    lines[#lines + 1] = "Apuntados (" .. #entries .. " de " .. t.d.size .. "): " .. (#entries > 0 and table.concat(entries, ", ") or "nadie todavía") .. "."
    lines[#lines + 1] = BG.colorize("Al sortear, los mejores de la Arena son cabezas de serie; el resto se sortea con /roll, que veréis en el chat.", C.text3)
    if Tn.drawing and Tn.drawing.id == t.id then
      lines[#lines + 1] = BG.colorize("Sorteando… (" .. #Tn.drawing.rolls .. " tiradas)", C.gold)
    end
    local inIt = Tn.Entered(t.id)
    buttons[#buttons + 1] = { inIt and "Borrarme" or "Apuntarme", function()
      local ok, w = (inIt and Tn.Leave or Tn.Enter)(t.id)
      if not ok then
        BG:Notify("No se pudo", cupWhy(w), { kind = "warning" })
      end
    end, not inIt }
    if manage then
      buttons[#buttons + 1] = { "Sortear y empezar", function()
        local ok, w = Tn.Draw(t.id)
        if not ok then
          BG:Notify("No se pudo sortear", cupWhy(w), { kind = "warning" })
        end
        BG:RefreshView("arena")
      end, true }
    end
  else
    local champ = Tn.Champion(t)
    local b = Tn.Bracket(t)
    lines[#lines + 1] = champ and BG.colorize("¡Campeón: " .. champ .. "!", C.gold) or ("En juego, " .. #t.d.order .. " luchadores. Cada combate lo decide el primer duelo entre los dos.")
    if not champ then
      for r, list in ipairs(b.matches) do
        local pending = {}
        for _, m in ipairs(list) do
          if m.a and m.b and not m.winner then
            pending[#pending + 1] = m.a .. " contra " .. m.b
          end
        end
        if #pending > 0 then
          lines[#lines + 1] = Tn.RoundName(b.rounds, r) .. ": " .. table.concat(pending, "; ") .. "."
          local first
          for _, m in ipairs(list) do
            if m.a and m.b and not m.winner and not first then
              first = m
            end
          end
          if first then
            buttons[#buttons + 1] = { "Cara a cara del siguiente combate", function()
              BG.UI.FaceOff(first.a, first.b)
            end }
          end
          break
        end
      end
    end
    buttons[#buttons + 1] = { "Ver cuadro", function()
      f.bracket = f.bracket or BG.UI.Bracket(f)
      f.bracket:Open(t.id)
    end, true }
  end
  if t.d.state ~= "CANCELLED" then
    lines[#lines + 1] = BG.colorize(string.format("Su sala de chat: en Chat, «%s».", string.format(night and "Velada: %s" or "Torneo: %s", t.d.title)), C.text3)
  end
  if manage and t.d.state ~= "CANCELLED" and not Tn.Champion(t) then
    buttons[#buttons + 1] = { "Cancelar", function()
      UI.Dialog({ title = "¿Cancelar «" .. t.d.title .. "»?", items = { "Se queda como cancelado para todos." },
        primary = { label = "Cancelar", fn = function()
          Tn.Cancel(t.id)
        end }, secondary = { label = "No" } })
    end }
  end
  return lines, buttons
end

-- View ---------------------------------------------------------------------------------------------------------------
local TABS = { { value = "ranking", label = "Clasificación" }, { value = "rivals", label = "Retos" }, { value = "duels", label = "Combates" }, { value = "cups", label = "Torneos" }, { value = "tavern", label = "Taberna" } }

BG:RegisterView("arena", {
  Build = function(f)
    f.hero = UI.Hero(f, 108)
    f.hero:SetPoint("TOPLEFT")
    f.hero:SetPoint("TOPRIGHT")
    f.tab = "ranking"
    f.tabs = UI.Segmented(f, TABS, { itemWidth = 112, onChange = function(v)
      f.tab = v
      BG:RefreshView("arena")
    end })
    f.tabs:SetPoint("TOPLEFT", f.hero, "BOTTOMLEFT", PAD, -12)

    local left = plate(f, "")
    left:SetPoint("TOPLEFT", f.tabs, "BOTTOMLEFT", 0, -12)
    left:SetPoint("BOTTOMLEFT", PAD, 18)
    f.left = left
    f.fighters = UI.List(left, 62, fighterRow, fillFighter)
    f.rivals = UI.List(left, 62, rivalRow, fillRival)
    f.duels = UI.List(left, 62, duelRow, fillDuel)
    f.cups = UI.List(left, 62, function(list)
      return cupRow(list, f)
    end, function(c, t)
      fillCup(c, t, f)
    end)
    f.cupNew = UI.Button(left, "Nuevo", { height = 24, width = 90 })
    f.cupNew:SetPoint("TOPRIGHT", -16, -10)
    f.cupNew:SetScript("OnClick", function()
      f.cupForm:Open()
    end)
    for _, l in ipairs({ f.fighters, f.rivals, f.duels, f.cups }) do
      l:SetPoint("TOPLEFT", left.head, "BOTTOMLEFT", 0, -12)
      l:SetPoint("BOTTOMRIGHT", -16, 14)
    end
    f.empty = UI.Text(left, 12, C.text3, { wrap = true })
    f.empty:SetPoint("TOPLEFT", left.head, "BOTTOMLEFT", 0, -16)
    f.empty:SetPoint("RIGHT", -16, 0)
    f.empty:SetSpacing(4)

    local right = plate(f, "")
    right:SetPoint("TOPLEFT", left, "TOPRIGHT", 18, 0)
    right:SetPoint("BOTTOMRIGHT", -PAD, 18)
    f.right = right
    f.challenges = UI.List(right, 62, challengeRow, fillChallenge)
    f.challenges:SetPoint("TOPLEFT", right.head, "BOTTOMLEFT", 0, -12)
    f.challenges:SetPoint("BOTTOMRIGHT", -16, 14)
    f.info = UI.Text(right, 12, C.text2, { wrap = true })
    f.info:SetPoint("TOPLEFT", right.head, "BOTTOMLEFT", 0, -8)
    f.info:SetPoint("RIGHT", -16, 0)
    f.info:SetSpacing(4)
    f.watch = UI.Button(right, "Ver un duelo", { height = 26, width = 130 })
    f.watch:SetPoint("BOTTOMLEFT", 16, 16)
    f.watch:SetScript("OnClick", function()
      BG.UI.WatchDuel()
    end)
    f.arbSet = UI.Button(right, "Árbitro", { height = 26, width = 90 })
    f.arbSet:SetPoint("BOTTOMRIGHT", -16, 50)
    f.arbName = UI.EditBox(right, { maxLetters = 40, placeholder = "Nombre de un miembro" })
    f.arbName:SetPoint("BOTTOMLEFT", 16, 50)
    f.arbName:SetPoint("RIGHT", f.arbSet, "LEFT", -6, 0)
    f.arbSet:SetScript("OnClick", function()
      local ok, now = BG.ArenaFace.ToggleArbiter(f.arbName:GetText())
      if ok then
        f.arbName:SetText("")
        BG:Notify(now and "Árbitro nombrado" or "Ya no es árbitro", now and "Puede decidir combates de los torneos y quitar duelos equivocados." or "", { kind = "success" })
      else
        BG:Notify("No se pudo", now == "no es de la hermandad" and "Escribe el nombre de un miembro de la hermandad." or now == "lleno" and "Como mucho 10 árbitros." or why(now), { kind = "warning" })
      end
    end)
    f.season = UI.Button(right, "Nueva temporada", { height = 26, width = 150 })
    f.season:SetPoint("BOTTOMRIGHT", -16, 16)
    f.season:Hide() -- (only the organisers see it: Refresh shows it to them)
    f.season:SetScript("OnClick", function()
      local season = A.Season()
      UI.Dialog({
        title = "Empezar la temporada " .. (season + 1),
        items = { "La temporada " .. season .. " se cierra y se guarda con su campeón y su podio.",
          { bullet = "Todos vuelven a empezar con " .. A.R.START .. " puntos." },
          { note = "Los combates de antes siguen guardados, pero ya no cuentan." } },
        primary = { label = "Empezar", fn = function()
          local ok, w = A.NewSeason()
          BG:Notify(ok and ("Temporada " .. (season + 1)) or "No se pudo", ok and "Todos empiezan de cero. ¡Suerte!" or why(w), { kind = ok and "success" or "warning", view = "arena" })
        end },
        secondary = { label = "Cancelar" },
      })
    end)

    -- The selected tournament (right): what it is, and up to three buttons stacked at the bottom.
    f.cupBtns = {}
    for i = 1, 3 do
      local b = UI.Button(right, "", { height = 26 })
      b:SetPoint("BOTTOMLEFT", 16, 16 + (i - 1) * 32)
      b:SetPoint("BOTTOMRIGHT", -16, 16 + (i - 1) * 32)
      b:SetScript("OnClick", function(self)
        if self.fn then
          self.fn()
        end
      end)
      b:Hide()
      f.cupBtns[i] = b
    end
    f.cupInfo = UI.Text(right, 12, C.text2, { wrap = true })
    f.cupInfo:SetPoint("TOPLEFT", right.head, "BOTTOMLEFT", 0, -8)
    f.cupInfo:SetPoint("RIGHT", -16, 0)
    f.cupInfo:SetPoint("BOTTOM", f.cupBtns[3], "TOP", 0, 10)
    f.cupInfo:SetJustifyV("TOP")
    f.cupInfo:SetSpacing(4)
    f.cupForm = buildCupForm(f)
    f.boutForm = buildBoutForm(f)
    BG.UI.TavernBuild(f, left, right)

    f:SetScript("OnSizeChanged", function(self, w)
      self.left:SetWidth(math.floor((w - PAD * 2 - 18) * 0.58))
    end)
  end,

  Refresh = function(f)
    local b = A.Build()
    local season, since, past = A.Season()
    f.hero:SetArt(BG.file("Interface\\Glues\\LoadingScreens\\LoadScreenEasternKingdom", BG.art.RAID), 0.45)
    f.hero:SetIcon(BG.file("Interface\\Icons\\Ability_DualWield", "Interface\\Icons\\INV_Misc_Note_02"))
    f.hero.title:SetText("La Arena")
    f.hero.sub:SetText("Duelos entre miembros de la hermandad, con su clasificación. El resultado lo lee el propio juego al terminar el duelo. Sin apuestas.")
    f.tabs:SetValue(f.tab, true)
    local tab = f.tab
    f.fighters:SetShown(tab == "ranking")
    f.rivals:SetShown(tab == "rivals")
    f.duels:SetShown(tab == "duels")
    f.cups:SetShown(tab == "cups")
    f.cupNew:SetShown(tab == "cups" and BG.Guild.me ~= nil)
    local items
    if tab == "tavern" then
      items = { true } -- (the tavern has its own contents: no empty-list text)
    elseif tab == "cups" then
      f.left.head:SetText("Torneos y veladas")
      items = Tn.List()
      if f.tsel and not Tn.Get(f.tsel) then
        f.tsel = nil
      end
      f.tsel = f.tsel or (items[1] and items[1].id)
      f.cups:SetItems(items)
      f.empty:SetText("Aún no hay torneos. Cualquiera puede crear uno con «Nuevo»: un torneo con cuadro eliminatorio, o una velada con combates anunciados.")
    elseif tab == "ranking" then
      f.left.head:SetText("Temporada " .. season)
      items = b.list
      f.fighters:SetItems(items)
      f.empty:SetText("Aún no hay combates esta temporada. Reta a alguien en «Retos», o batíos en duelo desde el juego: el addon de quien pierde lo apunta solo.")
    elseif tab == "rivals" then
      f.left.head:SetText("A quién retar")
      items = A.Rivals()
      f.rivals:SetItems(items)
      f.empty:SetText("Ahora no hay nadie más de la hermandad conectado. Cuando haya alguien, sale aquí; si tiene BlazonGuild, con «Retar».")
    else
      f.left.head:SetText("Combates de la temporada")
      items = A.Recent(40)
      f.duels:SetItems(items)
      f.empty:SetText("Aún no hay combates esta temporada.")
    end
    f.empty:SetShown(#items == 0)

    local challenges = tab == "rivals" and A.Challenges() or {}
    f.challenges:SetShown(tab == "rivals" and #challenges > 0)
    f.challenges:SetItems(challenges)
    f.info:SetShown(not f.challenges:IsShown() and tab ~= "cups" and tab ~= "tavern")
    local org = Store.IsOrganiser(Names.Me() or "")
    f.season:SetShown(tab == "ranking" and org)
    f.watch:SetShown(tab == "ranking")
    f.arbName:SetShown(tab == "ranking" and org)
    f.arbSet:SetShown(tab == "ranking" and org)
    local t = tab == "cups" and f.tsel and Tn.Get(f.tsel)
    f.cupInfo:SetShown(tab == "cups")
    for _, b in ipairs(f.cupBtns) do
      b:Hide()
    end
    BG.UI.TavernRefresh(f, tab == "tavern")
    if tab == "tavern" then
      -- (BG.UI.TavernRefresh above filled both plates)
    elseif tab == "cups" then
      if t then
        f.right.head:SetText(t.d.title)
        local lines, buttons = cupDetail(f, t)
        f.cupInfo:SetText(table.concat(lines, "\n"))
        for i, spec in ipairs(buttons) do
          local b = f.cupBtns[#buttons - i + 1] -- (the first one on top)
          if b then
            b:SetText(spec[1])
            b.fn = spec[2]
            b.text:SetTextColor((spec[3] and C.goldHi or C.text)[1], (spec[3] and C.goldHi or C.text)[2], (spec[3] and C.goldHi or C.text)[3])
            b:Show()
          end
        end
      else
        f.right.head:SetText("Torneos")
        f.cupInfo:SetText("Elige uno a la izquierda, o crea uno con «Nuevo».")
      end
    elseif tab == "rivals" then
      f.right.head:SetText("Te retan")
      f.info:SetText("Nadie te ha retado ahora. Cuando alguien lo haga, te sale aquí con «Aceptar» y «No».\n\n"
        .. "Cómo se reta: pulsa «Retar» junto a alguien de la lista (tiene que estar conectado y con BlazonGuild). Si acepta, os avisamos a los dos.\n\n"
        .. "El duelo lo empezáis desde el juego (clic derecho en su retrato, «Duelo»). Retar no es obligatorio: cualquier duelo entre dos de la hermandad con BlazonGuild cuenta.")
    else
      f.right.head:SetText("Cómo se cuenta")
      local lines = {}
      lines[#lines + 1] = "Temporada " .. season .. (since > 0 and (", desde el " .. UI.FormatDate(since)) or "") .. ": " .. b.fights .. (b.fights == 1 and " combate." or " combates.")
      lines[#lines + 1] = b.belt and ("Campeón: " .. b.belt .. ". Quien le gane se lleva el cinturón.") or "Aún no hay campeón: el primero que gane un duelo se lleva el cinturón."
      lines[#lines + 1] = "Todos empiezan con " .. A.R.START .. " puntos. Ganar a alguien mejor que tú da más puntos; a alguien de más nivel, también."
      lines[#lines + 1] = "Con " .. A.R.RANKED_MIN .. " combates tienes rango: " .. BG.colorize("Oro", TIER_COLOR.gold) .. " (los mejores), " .. BG.colorize("Plata", TIER_COLOR.silver) .. " y " .. BG.colorize("Bronce", TIER_COLOR.bronze) .. "."
      if past[1] then
        local p = past[1]
        lines[#lines + 1] = "Temporada " .. (p.n or "?") .. ": campeón " .. (p.champ or "nadie") .. (#p.top > 0 and (", podio " .. table.concat(p.top, ", ")) or "") .. "."
      end
      local arbiters = BG.ArenaFace.Arbiters()
      lines[#lines + 1] = #arbiters > 0 and ("Árbitros: " .. table.concat(arbiters, ", ") .. ".") or "Sin árbitros: deciden los combates a mano quien dirige cada torneo y los organizadores."
      f.info:SetText(table.concat(lines, "\n"))
    end
  end,
})

BG:On("BG_ARENA_CHANGED", function()
  BG:RefreshView("arena")
end)
BG:On("BG_TOURNEY_CHANGED", function()
  BG:RefreshView("arena")
end)
