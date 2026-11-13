-- A member's card, over the current section of the main window: who they are in the guild, what they chose
-- to tell, their confirmed characters, their upcoming raids and their flag. Your own card has an editor.
-- Opened from La hermandad, from the game's right-click menu and from tooltips (Hooks.lua).
local _, BG = ...
local UI, C = BG.UI, BG.color
local People, Names, Instances = BG.People, BG.Names, BG.Instances

local ROLE_NAME = { TANK = "Tanque", HEALER = "Sanador", DPS = "Daño" }
local panel

local function build()
  local w = BG.window
  local p = CreateFrame("Frame", nil, w.content)
  p:SetAllPoints()
  p:SetFrameLevel(w.content:GetFrameLevel() + 30)
  p:EnableMouse(true)
  p:Hide()
  UI.Tile(p, "canvas.png")
  UI.Shade(p, 0.03, 0.2)

  p.back = UI.Button(p, "Volver", { height = 26, width = 90 })
  p.back:SetPoint("TOPRIGHT", -24, -16)
  p.back:SetScript("OnClick", function()
    p:Hide()
  end)

  -- (The ring's art has a dark centre: it goes under the class icon, never over it.)
  p.icon = p:CreateTexture(nil, "OVERLAY")
  p.icon:SetSize(64, 64)
  p.icon:SetPoint("TOPLEFT", 28, -24)
  p.ring = p:CreateTexture(nil, "ARTWORK")
  p.ring:SetTexture(BG.media .. "ring.png")
  p.ring:SetPoint("TOPLEFT", p.icon, "TOPLEFT", -6, 6)
  p.ring:SetPoint("BOTTOMRIGHT", p.icon, "BOTTOMRIGHT", 6, -6)
  p.name = UI.Text(p, 24, C.goldTitle, { font = BG.font.display })
  p.name:SetPoint("TOPLEFT", p.icon, "TOPRIGHT", 18, -2)
  p.name:SetPoint("RIGHT", p.back, "LEFT", -12, 0)
  p.line1 = UI.Text(p, 13, C.text)
  p.line1:SetPoint("TOPLEFT", p.name, "BOTTOMLEFT", 0, -6)
  p.line2 = UI.Text(p, 12, C.text2)
  p.line2:SetPoint("TOPLEFT", p.line1, "BOTTOMLEFT", 0, -4)

  p.actions = CreateFrame("Frame", nil, p)
  p.actions:SetSize(500, 26)
  p.actions:SetPoint("TOPLEFT", p.icon, "BOTTOMLEFT", 0, -18)
  p.whisper = UI.Button(p.actions, "Saludar por susurro", { height = 26 })
  p.whisper:SetPoint("LEFT")
  p.invite = UI.Button(p.actions, "Invitar al grupo", { height = 26 })
  p.invite:SetPoint("LEFT", p.whisper, "RIGHT", 8, 0)
  p.editBtn = UI.Button(p.actions, "Editar mi ficha", { primary = true, height = 26 })
  p.editBtn:SetPoint("LEFT")

  -- Read view
  p.read = CreateFrame("Frame", nil, p)
  p.read:SetPoint("TOPLEFT", p.actions, "BOTTOMLEFT", 0, 0)
  p.read:SetPoint("BOTTOMRIGHT", -24, 18)
  local r = p.read
  r.aboutHead = UI.Heading(r, "Sobre esta persona")
  r.aboutHead:SetPoint("TOPLEFT", 0, -14)
  r.aboutHead:SetPoint("RIGHT")
  r.about = UI.Text(r, 13, C.text, { wrap = true })
  r.about:SetPoint("TOPLEFT", r.aboutHead, "BOTTOMLEFT", 0, -8)
  r.about:SetPoint("RIGHT")
  r.facts = UI.Text(r, 12, C.text2, { wrap = true })
  r.facts:SetPoint("TOPLEFT", r.about, "BOTTOMLEFT", 0, -8)
  r.facts:SetPoint("RIGHT")
  r.charsHead = UI.Heading(r, "Sus personajes")
  r.charsHead:SetPoint("TOPLEFT", r.facts, "BOTTOMLEFT", 0, -16)
  r.charsHead:SetPoint("RIGHT")
  r.chars = {}
  r.charsNote = UI.Text(r, 12, C.text3, { wrap = true })
  r.activityHead = UI.Heading(r, "En la hermandad")
  r.activity = UI.Text(r, 12, C.text, { wrap = true })

  -- Edit view (own card)
  p.edit = CreateFrame("Frame", nil, p)
  p.edit:SetPoint("TOPLEFT", p.actions, "BOTTOMLEFT", 0, 0)
  p.edit:SetPoint("BOTTOMRIGHT", -24, 18)
  local e = p.edit
  e.head = UI.Heading(e, "Tu ficha")
  e.head:SetPoint("TOPLEFT", 0, -14)
  e.head:SetPoint("RIGHT")
  local function label(text, anchor)
    local l = UI.Text(e, 11, C.text3)
    l:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -12)
    l:SetText(text)
    return l
  end
  local l1 = label("Unas palabras sobre ti (lo verá tu hermandad)", e.head)
  e.bio = UI.EditBox(e, { width = 560, maxLetters = 160, placeholder = "Por ejemplo: paladín sanador, me encantan las bandas y ayudar a los nuevos" })
  e.bio:SetPoint("TOPLEFT", l1, "BOTTOMLEFT", 0, -4)
  local l2 = label("Tu rol habitual", e.bio)
  e.role = UI.Segmented(e, { { value = "TANK", label = "Tanque" }, { value = "HEALER", label = "Sanador" }, { value = "DPS", label = "Daño" }, { value = "NONE", label = "Sin decir" } }, { itemWidth = 90 })
  e.role:SetPoint("TOPLEFT", l2, "BOTTOMLEFT", 0, -4)
  local l3 = label("Cuándo sueles jugar", e.role)
  e.hours = UI.EditBox(e, { width = 360, maxLetters = 60, placeholder = "Por ejemplo: noches entre semana y domingos" })
  e.hours:SetPoint("TOPLEFT", l3, "BOTTOMLEFT", 0, -4)
  local l4 = label("Tus personajes en esta hermandad", e.hours)
  e.share = UI.Segmented(e, { { value = true, label = "Mostrarlos" }, { value = false, label = "No mostrarlos" } }, { itemWidth = 120 })
  e.share:SetPoint("TOPLEFT", l4, "BOTTOMLEFT", 0, -4)
  e.main = UI.Picker(e, { width = 200, placeholder = "Personaje principal" })
  e.main:SetPoint("LEFT", e.share, "RIGHT", 14, 0)
  e.shareNote = UI.Text(e, 11, C.text3, { wrap = true })
  e.shareNote:SetPoint("TOPLEFT", e.share, "BOTTOMLEFT", 0, -6)
  e.shareNote:SetWidth(560)
  e.save = UI.Button(e, "Guardar mi ficha", { primary = true, height = 30, width = 160 })
  e.save:SetPoint("BOTTOMLEFT", 0, 0)
  e.cancel = UI.Button(e, "Cancelar", { height = 30, width = 100 })
  e.cancel:SetPoint("LEFT", e.save, "RIGHT", 10, 0)
  e.error = UI.Text(e, 12, C.danger)
  e.error:SetPoint("LEFT", e.cancel, "RIGHT", 12, 0)

  p.editBtn:SetScript("OnClick", function()
    p.editing = true
    BG.UI.ShowProfile(p.target)
  end)
  e.cancel:SetScript("OnClick", function()
    p.editing = false
    BG.UI.ShowProfile(p.target)
  end)
  e.save:SetScript("OnClick", function()
    if not BG.Consent.Accepted() then
      e.error:SetText("Acepta antes la privacidad (/bg privacidad).")
      return
    end
    BG.Consent.SetLine("alts", e.share:GetValue() == true)
    local role = e.role:GetValue()
    local ok, why = People.Publish({ bio = e.bio:GetText(), hours = e.hours:GetText(), role = role ~= "NONE" and role or false, main = e.main:GetValue() or false })
    if not ok then
      e.error:SetText("No se pudo guardar (" .. tostring(why) .. ").")
      return
    end
    BG.Sound("IG_QUEST_LIST_COMPLETE")
    p.editing = false
    BG.UI.ShowProfile(p.target)
  end)
  p.whisper:SetScript("OnClick", function()
    People.SendWhisper(p.target, "¡Hola! Te saludo desde BlazonGuild.")
  end)
  p.whisper:HookScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetText("Envía: «¡Hola! Te saludo desde BlazonGuild.»", 1, 1, 1, 1, true)
    BG.ShowTip()
  end)
  p.whisper:HookScript("OnLeave", function()
    GameTooltip:Hide()
  end)
  p.invite:SetScript("OnClick", function()
    if C_PartyInfo and C_PartyInfo.InviteUnit and BG.InGame() then
      C_PartyInfo.InviteUnit(Names.Tell(p.target))
    end
  end)
  return p
end

local function charButton(r, i)
  local b = r.chars[i]
  if b then
    return b
  end
  b = CreateFrame("Button", nil, r)
  b:SetSize(260, 22)
  b.icon = b:CreateTexture(nil, "ARTWORK")
  b.icon:SetSize(16, 16)
  b.icon:SetPoint("LEFT")
  b.text = UI.Text(b, 12, C.text)
  b.text:SetPoint("LEFT", b.icon, "RIGHT", 6, 0)
  local hl = b:CreateTexture(nil, "HIGHLIGHT")
  hl:SetColorTexture(C.gold[1], C.gold[2], C.gold[3], 0.08)
  hl:SetAllPoints()
  b:SetScript("OnClick", function(self)
    BG.UI.ShowProfile(self.name)
  end)
  r.chars[i] = b
  return b
end

function BG.UI.ShowProfile(name)
  local short = Names.Short(name)
  if not short then
    return
  end
  if not (BG.window and BG.window:IsShown()) then
    BG:ToggleWindow()
  end
  panel = panel or build()
  local p = panel
  if p.target ~= short then
    p.editing = false
  end
  p.target = short
  local m = BG.Guild.Find(short)
  local prof = People.Profile(short)
  local isMe = Names.IsMe(short)
  local cc = BG.classColor(m and m.classFile)
  BG.setClassIcon(p.icon, m and m.classFile)
  p.name:SetText(short)
  p.name:SetTextColor(cc[1], cc[2], cc[3])
  if m then
    p.line1:SetText(string.format("Nivel %d %s, %s de %s", m.level, (LOCALIZED_CLASS_NAMES_MALE and LOCALIZED_CLASS_NAMES_MALE[m.classFile]) or m.className or "", m.rank or "", BG.Guild.info and BG.Guild.info.name or ""))
    local where = m.online and BG.colorize("Conectado", C.success) .. (m.zone and m.zone ~= "" and (", en " .. m.zone) or "") or ("Última conexión " .. UI.Ago(m.lastOnlineDays))
    local peer = BG.Peers.Get(short)
    p.line2:SetText(where .. (peer and (", usa BlazonGuild " .. tostring(peer.version)) or ""))
  else
    local sister = BG.Alliance and BG.Alliance.GuildOfName(short)
    p.line1:SetText(sister and ("De " .. sister.n .. ", hermandad hermana") or "No está en tu hermandad")
    p.line2:SetText(sister and "Es de la alianza: podéis hablar en el chat de la alianza." or "")
  end
  p.whisper:SetShown(not isMe and m ~= nil and m.online)
  p.invite:SetShown(not isMe and m ~= nil and m.online)
  p.editBtn:SetShown(isMe and not p.editing)
  p.read:SetShown(not p.editing)
  p.edit:SetShown(p.editing == true)

  if p.editing then
    local e = p.edit
    local d = prof and prof.d or {}
    e.bio:SetText(d.bio or "")
    e.hours:SetText(d.hours or "")
    e.role:SetValue(d.role or "NONE", true)
    e.share:SetValue(BG.Consent.Line("alts"), true)
    local mine = People.MyChars()
    local opts = {}
    for _, c in ipairs(mine) do
      opts[#opts + 1] = { value = c, label = c }
    end
    e.main:SetOptions(opts)
    e.main:SetValue(d.main, true)
    e.shareNote:SetText(#mine <= 1 and "Cuando entres con otros personajes de esta cuenta en la hermandad, aparecerán aquí. Solo se muestran juntos si cada uno de ellos lo comparte también."
      or ("Esta cuenta tiene " .. #mine .. " personajes en la hermandad: " .. table.concat(mine, ", ") .. ". Se muestran como tuyos solo si los compartes desde cada uno de ellos."))
    e.error:SetText("")
  else
    local r = p.read
    local d = prof and prof.d
    r.about:SetText(d and d.bio and d.bio ~= "" and d.bio or (isMe and "Todavía no has escrito nada. Pulsa «Editar mi ficha»." or "Todavía no ha escrito nada sobre sí."))
    local facts = {}
    local honors = BG.Honors and m and BG.Honors.Of(short) or {}
    if #honors > 0 then
      facts[#facts + 1] = BG.colorize("Honores: " .. table.concat(honors, ", "), C.gold)
    end
    local arena = BG.Arena and m and BG.Arena.Summary(short)
    if arena then
      facts[#facts + 1] = "Arena: " .. arena
    end
    if d and d.role then
      facts[#facts + 1] = "Rol habitual: " .. ROLE_NAME[d.role]:lower()
    end
    if d and d.hours and d.hours ~= "" then
      facts[#facts + 1] = "Suele jugar: " .. d.hours
    end
    if m and m.note and m.note ~= "" then
      facts[#facts + 1] = "Nota de la hermandad: " .. m.note
    end
    r.facts:SetText(table.concat(facts, "\n"))
    local chars = People.Characters(short)
    local main = People.Main(short)
    for i, c in ipairs(chars) do
      local b = charButton(r, i)
      local cm = BG.Guild.Find(c)
      b.name = c
      BG.setClassIcon(b.icon, cm and cm.classFile)
      local bc = BG.classColor(cm and cm.classFile)
      b.text:SetText(BG.colorize(c, bc) .. BG.colorize((cm and ("  nivel " .. cm.level) or "") .. (c == main and #chars > 1 and ", principal" or ""), C.text3))
      b:ClearAllPoints()
      b:SetPoint("TOPLEFT", r.charsHead, "BOTTOMLEFT", ((i - 1) % 2) * 280, -8 - math.floor((i - 1) / 2) * 24)
      b:Show()
    end
    for i = #chars + 1, #r.chars do
      r.chars[i]:Hide()
    end
    local rows = math.ceil(#chars / 2)
    r.charsNote:ClearAllPoints()
    r.charsNote:SetPoint("TOPLEFT", r.charsHead, "BOTTOMLEFT", 0, -12 - rows * 24)
    r.charsNote:SetPoint("RIGHT")
    r.charsNote:SetText(#chars > 1 and "" or (isMe and "Tus otros personajes aparecerán aquí si eliges mostrarlos en tu ficha." or ""))
    r.activityHead:ClearAllPoints()
    r.activityHead:SetPoint("TOPLEFT", r.charsNote, "BOTTOMLEFT", 0, -16)
    r.activityHead:SetPoint("RIGHT")
    local act = {}
    for _, raid in ipairs(BG.Raids.Upcoming()) do
      local s = BG.Store.Get("signups", raid.id .. "|" .. short)
      if s and not s.del and s.d.status ~= "DECLINED" then
        act[#act + 1] = "Apuntado a " .. raid.d.title .. " (" .. UI.FormatDate(raid.d.start, true) .. ")" .. (s.d.status == "TENTATIVE" and ", quizá" or "")
      end
    end
    local flag = BG.Store.Get("flags", short)
    if flag and not flag.del and (flag.exp or 0) > BG.Store.Now() then
      local inst = Instances.Any(flag.d.key)
      act[#act + 1] = "Busca grupo" .. (inst and (" para " .. inst.name) or "") .. " como " .. ROLE_NAME[flag.d.role]:lower()
    end
    r.activity:ClearAllPoints()
    r.activity:SetPoint("TOPLEFT", r.activityHead, "BOTTOMLEFT", 0, -8)
    r.activity:SetPoint("RIGHT")
    r.activity:SetText(#act > 0 and table.concat(act, "\n") or "Sin raids próximas ni bandera en el tablón.")
  end
  p:Show()
end

function BG.UI.HideProfile()
  if panel then
    panel:Hide()
  end
end

BG:On("BG_STORE_CHANGED", function(name)
  if panel and panel:IsShown() and not panel.editing and (name == "profiles" or name == "signups" or name == "flags") then
    BG.UI.ShowProfile(panel.target)
  end
end)
