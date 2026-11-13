-- Chat: the guild's conversations in one place, with BlazonGuild's look. Channels on the left (the game's
-- guild and officer chat; the alliance: everyone, one tab per sister guild, organisers, masters; the rooms),
-- the conversation with class-coloured names, rank marks, the sister guild of each line and clickable items,
-- and the moderation desk for organisers (reports, cases, mutes, filtered words).
local _, BG = ...
local UI, C = BG.UI, BG.color
local Chat, Names = BG.Chat, BG.Names

local RAIL_W, PAD = 206, 18
local ROOM_ROLE = { healers = "HEALER", tanks = "TANK", dps = "DPS" }
local MUTE_LABELS = { "5 minutos", "30 minutos", "1 hora", "24 horas", "7 días" }

local DECISION = { KICK = "Expulsar", WARN = "Aviso final", NOTHING = "Nada" }

-- Small marks next to a name (Olympus's ChatMarks idea): master, organisers, and the golden crest of an honour.
local function mark(name)
  local honour = BG.Marks and BG.Marks.ChatMark(name) or ""
  local r = BG.Store.RankOf(name)
  if r == 0 then
    return "|TInterface\\GroupFrame\\UI-Group-LeaderIcon:12:12:0:0|t " .. honour
  elseif r and r <= BG.Store.OrganiserMax() then
    return "|TInterface\\GroupFrame\\UI-Group-AssistantIcon:12:12:0:0|t " .. honour
  end
  return honour
end

-- One line as shown: time, mark, the clickable name, the text (filtered). Pure given the stores; tested.
function Chat.FormatLine(channel, index, line)
  local stamp = BG.colorize(date("%H:%M", line.at or time()), C.text3)
  if line.id and Chat.Deleted(line.id) then
    return stamp .. "  " .. BG.colorize("Mensaje borrado por la moderación", C.text3)
  end
  local cc = BG.classColor(line.class)
  local name = "|c" .. BG.hex(cc) .. "|Hbgline:" .. channel .. ":" .. index .. "|h" .. line.from .. "|h|r"
  local guild = line.gn and BG.colorize("[" .. line.gn .. "] ", C.text3) or ""
  return stamp .. "  " .. guild .. mark(line.from) .. name .. BG.colorize(":", C.text3) .. " " .. Chat.ApplyFilter(line.text)
end

local function channelButton(parent, label)
  local b = CreateFrame("Button", nil, parent)
  b:SetHeight(28)
  b.active = b:CreateTexture(nil, "BACKGROUND")
  b.active:SetColorTexture(1, 1, 1, 1)
  b.active:SetGradient("HORIZONTAL", CreateColor(C.gold[1], C.gold[2], C.gold[3], 0.2), CreateColor(C.gold[1], C.gold[2], C.gold[3], 0))
  b.active:SetAllPoints()
  b.bar = b:CreateTexture(nil, "ARTWORK")
  b.bar:SetColorTexture(C.gold[1], C.gold[2], C.gold[3], 1)
  b.bar:SetPoint("TOPLEFT")
  b.bar:SetPoint("BOTTOMLEFT")
  b.bar:SetWidth(2)
  local hl = b:CreateTexture(nil, "HIGHLIGHT")
  hl:SetColorTexture(C.gold[1], C.gold[2], C.gold[3], 0.07)
  hl:SetAllPoints()
  b.hash = UI.Text(b, 13, C.gold)
  b.hash:SetPoint("LEFT", 12, 0)
  b.hash:SetText("#")
  b.role = b:CreateTexture(nil, "ARTWORK")
  b.role:SetSize(15, 15)
  b.role:SetPoint("LEFT", 9, 0)
  b.role:Hide()
  b.text = UI.Text(b, 12, C.text)
  b.text:SetPoint("LEFT", 28, 0)
  b.text:SetPoint("RIGHT", -30, 0)
  b.text:SetText(label)
  b.badge = UI.Text(b, 11, C.goldTitle, { justify = "RIGHT" })
  b.badge:SetPoint("RIGHT", -10, 0)
  function b:SetActive(on)
    self.active:SetShown(on)
    self.bar:SetShown(on)
    local c = on and C.goldTitle or C.text
    self.text:SetTextColor(c[1], c[2], c[3])
  end
  return b
end

local function moderationDialog(f, channel, index)
  local line = Chat.History(channel)[index]
  if not line or Names.IsMe(line.from) then
    if line then
      BG.UI.ShowProfile(line.from)
    end
    return
  end
  local items = { "«" .. line.text .. "»" }
  local mod = Chat.IsModerator()
  if mod then
    items[#items + 1] = { note = "Avisos acumulados: " .. Chat.Strikes(line.from) .. " de 3. Al tercero se abre un caso que decide el maestro." }
  end
  BG.UI.Dialog({
    title = line.from,
    items = items,
    primary = { label = "Ver su ficha", fn = function()
      BG.UI.ShowProfile(line.from)
    end },
    secondary = mod and { label = "Moderar", fn = function()
      local isRoom = line.id and channel ~= "guild" and channel ~= "officer"
      local choices = {}
      for step, label in ipairs({ "5 min", "30 min", "1 hora", "24 h", "7 días" }) do
        choices[#choices + 1] = { label = label, fn = function()
          local muted, strikes = Chat.Mute(line.from, step, "por: «" .. line.text:sub(1, 80) .. "»")
          if isRoom then
            Chat.Delete(channel, line.id)
          end
          BG:Notify("Silenciado " .. MUTE_LABELS[step], table.concat(muted, ", ") .. ". Avisos: " .. strikes .. " de 3" .. (strikes >= 3 and "; se ha abierto un caso." or "."), { kind = "warning", view = "chat" })
        end }
      end
      BG.UI.Dialog({
        title = "Moderar a " .. line.from,
        items = { "Silenciarle en las salas de BlazonGuild suma un aviso; al tercero se abre un caso que decide el maestro. Si comparte su BattleTag con los organizadores, alcanza a todos sus personajes.",
          { note = "El chat de hermandad del juego no se puede silenciar desde un addon: ahí solo se oculta en BlazonGuild." } },
        choices = choices,
        primary = { label = isRoom and "Solo borrar el mensaje" or "Ocultarle en mi chat", fn = function()
          if isRoom then
            Chat.Delete(channel, line.id)
          else
            Chat.SetHidden(line.from, true)
          end
        end },
        secondary = { label = "Cancelar" },
      })
    end } or { label = "Denunciar", fn = function()
      local n = Chat.Report(line, channel, "denunciado desde el chat")
      BG:Notify(n > 0 and "Denuncia enviada" or "Sin organizadores conectados", n > 0 and ("La han recibido " .. n .. " organizadores conectados.")
        or "Ningún organizador con BlazonGuild está conectado ahora. Prueba más tarde.", { kind = n > 0 and "success" or "warning" })
    end },
  })
end

-- Moderation desk -----------------------------------------------------------------------------------
local function buildDesk(f)
  local desk = CreateFrame("Frame", nil, f.main)
  desk:SetAllPoints()
  desk:Hide()
  desk.head = UI.Heading(desk, "Casos")
  desk.head:SetPoint("TOPLEFT", 0, 0)
  desk.head:SetPoint("TOPRIGHT")
  desk.cases = UI.List(desk, 64, function(list)
    local c = UI.Card(list)
    c.kick = UI.CardButton(c, "Expulsar", { height = 22, width = 82 })
    c.kick:SetPoint("BOTTOMRIGHT", -8, 6)
    c.warn = UI.CardButton(c, "Aviso final", { height = 22, width = 92 })
    c.warn:SetPoint("RIGHT", c.kick, "LEFT", -6, 0)
    c.none = UI.CardButton(c, "Nada", { height = 22, width = 62 })
    c.none:SetPoint("RIGHT", c.warn, "LEFT", -6, 0)
    for key, b in pairs({ KICK = c.kick, WARN = c.warn, NOTHING = c.none }) do
      b:SetScript("OnClick", function()
        local case = c.case
        if not case then
          return
        end
        if BG.Store.IsMaster(Names.Me()) then
          Chat.Decide(case.id, key)
          if key == "KICK" then
            BG:Notify("Decisión tomada", "Expulsar a " .. case.d.target .. ": hazlo tú desde la ventana de hermandad del juego. El addon nunca expulsa a nadie.", { kind = "warning" })
          end
        else
          Chat.Vote(case.id, key)
        end
      end)
    end
    return c
  end, function(c, case)
    c.case = case
    c:SetHeight(58)
    c.icon:SetTexture("Interface\\Icons\\Ability_Warrior_RallyingCry")
    c.title:SetText(case.d.target .. (case.d.status == "DECIDED" and BG.colorize("  " .. DECISION[case.d.decision], C.goldHi) or ""))
    local votes = {}
    for who, v in pairs(case.d.votes) do
      votes[#votes + 1] = who .. ": " .. DECISION[v]:lower()
    end
    c.sub:SetText((case.d.reason or "") .. (#votes > 0 and (". Opiniones: " .. table.concat(votes, ", ")) or ""))
    local open = case.d.status == "OPEN"
    local master = BG.Store.IsMaster(Names.Me())
    for _, b in ipairs({ c.kick, c.warn, c.none }) do
      b:SetShown(open)
    end
    c.kick.text:SetText(master and "Expulsar" or "Opino: expulsar")
    c.right:SetText(open and (master and "decides tú" or "decide el maestro") or "cerrado")
    c.right2:SetText("")
  end)
  desk.cases:SetPoint("TOPLEFT", desk.head, "BOTTOMLEFT", 0, -8)
  desk.cases:SetPoint("RIGHT")
  desk.cases:SetHeight(196)

  desk.head2 = UI.Heading(desk, "Denuncias y silencios")
  desk.head2:SetPoint("TOPLEFT", desk.cases, "BOTTOMLEFT", 0, -10)
  desk.head2:SetPoint("RIGHT")
  desk.log = UI.Text(desk, 12, C.text2, { wrap = true })
  desk.log:SetPoint("TOPLEFT", desk.head2, "BOTTOMLEFT", 0, -8)
  desk.log:SetPoint("RIGHT")
  desk.log:SetMaxLines(7)

  desk.head3 = UI.Heading(desk, "Palabras filtradas en toda la hermandad")
  desk.head3:SetPoint("BOTTOMLEFT", 0, 34)
  desk.head3:SetPoint("RIGHT")
  desk.words = UI.EditBox(desk, { width = 420, maxLetters = 400, placeholder = "palabras separadas por comas" })
  desk.words:SetPoint("BOTTOMLEFT", 0, 0)
  desk.saveWords = UI.Button(desk, "Guardar filtro", { height = 26, width = 120 })
  desk.saveWords:SetPoint("LEFT", desk.words, "RIGHT", 8, 0)
  desk.saveWords:SetScript("OnClick", function()
    local words = {}
    for w in desk.words:GetText():gmatch("[^,]+") do
      w = w:gsub("^%s+", ""):gsub("%s+$", "")
      if w ~= "" then
        words[#words + 1] = w
      end
    end
    if BG.Store.Put("filter", "guild", { words = words }) then
      BG:Notify("Filtro guardado", #words .. " palabras se verán como asteriscos en el chat de todos.", { kind = "success" })
    end
  end)

  function desk:Refresh()
    self.cases:SetItems(Chat.Cases())
    local lines = {}
    for i, r in ipairs(BG.Chat.Reports()) do
      if i > 4 then
        break
      end
      lines[#lines + 1] = BG.colorize(date("%d/%m %H:%M", r.at), C.text3) .. "  " .. r.by .. " denuncia a " .. tostring(r.who) .. ": «" .. tostring(r.text) .. "»"
    end
    for _, m in ipairs(BG.Store.List("mutes", function(r)
      return r.d["until"] > BG.Store.Now()
    end)) do
      lines[#lines + 1] = BG.colorize("Silenciado", C.warning) .. " " .. m.id .. " hasta las " .. UI.FormatTime(m.d["until"]) .. (m.d.reason and (", " .. m.d.reason) or "")
    end
    self.log:SetText(#lines > 0 and table.concat(lines, "\n") or "Sin denuncias recibidas ni nadie silenciado ahora.")
    local common = BG.Store.Get("filter", "guild")
    if not self.words.edit:HasFocus() then
      self.words:SetText(common and not common.del and table.concat(common.d.words, ", ") or "")
    end
  end
  return desk
end

-- View --------------------------------------------------------------------------------------------------
BG:RegisterView("chat", {
  Build = function(f, def)
    f.channel = BG.db.settings.chatChannel or "guild"

    -- Channel rail
    local rail = UI.Plate(f, { rail = 0.2 })
    rail:SetPoint("TOPLEFT", PAD, -16)
    rail:SetPoint("BOTTOMLEFT", PAD, 16)
    rail:SetWidth(RAIL_W)
    f.rail = rail
    f.heads, f.chanButtons = {}, {}
    local function select(id)
      f.channel = id
      BG.db.settings.chatChannel = id
      Chat.MarkRead(id)
      BG.Sound("IG_MAINMENU_OPTION")
      def.Refresh(f, def)
      BG:RefreshChrome()
    end
    f.select = select
    rail.newRoom = UI.Button(rail, "+", { height = 20, width = 24 })
    -- No sister guilds yet: a short invitation to the Alianza section; once there are, the rail lists them.
    local cta = CreateFrame("Frame", nil, rail)
    cta:SetHeight(60)
    cta.text = UI.Text(cta, 11, C.text2, { wrap = true })
    cta.text:SetPoint("TOPLEFT", 12, -2)
    cta.text:SetPoint("RIGHT", -10, 0)
    cta.text:SetText("Aquí tendréis una pestaña por cada hermandad hermana.")
    cta.btn = UI.Button(cta, "Ver la alianza", { height = 22, width = 120 })
    cta.btn:SetPoint("TOPLEFT", cta.text, "BOTTOMLEFT", 0, -6)
    cta.btn:SetScript("OnClick", function()
      BG:ShowView("alliance")
    end)
    f.cta = cta
    f.deskBtn = channelButton(rail, "Moderación")
    f.deskBtn.hash:SetText("!")
    f.deskBtn:SetPoint("BOTTOMLEFT", 1, 8)
    f.deskBtn:SetPoint("RIGHT", -1, 0)
    f.deskBtn:SetScript("OnClick", function()
      select("desk")
    end)
    rail.newRoom:SetScript("OnClick", function()
      f.roomForm:SetShown(not f.roomForm:IsShown())
    end)

    -- Main area
    local main = CreateFrame("Frame", nil, f)
    main:SetPoint("TOPLEFT", rail, "TOPRIGHT", 16, 0)
    main:SetPoint("BOTTOMRIGHT", -PAD, 16)
    f.main = main
    main.title = UI.Text(main, 20, C.goldTitle, { font = BG.font.display })
    main.title:SetPoint("TOPLEFT", 2, -2)
    main.desc = UI.Text(main, 12, C.text2, { wrap = true })
    main.desc:SetPoint("TOPLEFT", main.title, "BOTTOMLEFT", 0, -4)
    main.desc:SetPoint("RIGHT")
    main.desc:SetMaxLines(2)
    main.desc:SetHeight(30)
    local logPlate = UI.Plate(main, { tile = "sunken.png", rail = 0.14 })
    logPlate:SetPoint("TOPLEFT", main.desc, "BOTTOMLEFT", -2, -10)
    logPlate:SetPoint("BOTTOMRIGHT", 0, 40)
    f.logPlate = logPlate
    local log = CreateFrame("ScrollingMessageFrame", nil, logPlate)
    log:SetPoint("TOPLEFT", 12, -10)
    log:SetPoint("BOTTOMRIGHT", -12, 10)
    log:SetFont(BG.font.body, 13, "")
    log:SetShadowColor(0, 0, 0, 0.9)
    log:SetShadowOffset(1, -1)
    log:SetJustifyH("LEFT")
    log:SetFading(false)
    log:SetMaxLines(200)
    log:SetSpacing(3)
    log:SetHyperlinksEnabled(true)
    log:EnableMouseWheel(true)
    log:SetScript("OnMouseWheel", function(self, delta)
      if delta > 0 then
        self:ScrollUp()
      else
        self:ScrollDown()
      end
    end)
    log:SetScript("OnHyperlinkClick", function(_, link, text, button)
      local channel, index = link:match("^bgline:([^:]+):(%d+)$")
      if channel then
        moderationDialog(f, channel, tonumber(index))
      elseif link:match("^item:") or link:match("^spell:") or link:match("^achievement:") or link:match("^quest:") then
        if SetItemRef then
          SetItemRef(link, text, button)
        end
      end
    end)
    f.log = log
    f.emptyLog = UI.Text(logPlate, 13, C.text3, { justify = "CENTER", wrap = true })
    f.emptyLog:SetPoint("CENTER")
    f.emptyLog:SetWidth(420)

    f.input = UI.EditBox(main, { width = 400, height = 30, maxLetters = 255, onEnter = function(text)
      local ok, why = Chat.Send(f.channel, text)
      if ok then
        f.input:SetText("")
        f.inputNote:SetText("")
      else
        f.inputNote:SetText(BG.colorize(why == "consent" and "Acepta la privacidad para hablar en las salas." or (why == "despacio" and "Un momento: escribes muy rápido." or (why == "capturas" and "En el modo capturas no se hace nada en el juego: es solo una hermandad de ejemplo." or tostring(why))), C.warning))
      end
    end })
    f.input:SetPoint("BOTTOMLEFT", 0, 0)
    f.input:SetPoint("RIGHT", -110, 0)
    f.send = UI.Button(main, "Enviar", { primary = true, height = 30, width = 100 })
    f.send:SetPoint("BOTTOMRIGHT", 0, 0)
    f.send:SetScript("OnClick", function()
      f.input.edit:GetScript("OnEnterPressed")(f.input.edit)
    end)
    f.inputNote = UI.Text(main, 11, C.text3, { justify = "RIGHT" })
    f.inputNote:SetPoint("BOTTOMRIGHT", f.send, "TOPRIGHT", 0, 6)

    f.desk = buildDesk(f)
    f.desk:ClearAllPoints()
    f.desk:SetPoint("TOPLEFT", main.desc, "BOTTOMLEFT", 0, -12)
    f.desk:SetPoint("BOTTOMRIGHT", 0, 0)

    -- New room form (small plate over the conversation)
    local form = UI.Plate(main, { corners = 16, rail = 0.3 })
    form:SetFrameLevel(main:GetFrameLevel() + 20)
    form:SetPoint("TOPLEFT", logPlate, "TOPLEFT", 20, -20)
    form:SetSize(420, 170)
    form:EnableMouse(true)
    form:Hide()
    form.head = UI.Heading(form, "Nueva sala")
    form.head:SetPoint("TOPLEFT", 16, -10)
    form.head:SetPoint("TOPRIGHT", -16, -10)
    form.name = UI.EditBox(form, { width = 388, maxLetters = 32, placeholder = "Nombre: por ejemplo, Raid del viernes" })
    form.name:SetPoint("TOPLEFT", form.head, "BOTTOMLEFT", 0, -10)
    form.desc = UI.EditBox(form, { width = 388, maxLetters = 120, placeholder = "Para qué es (opcional)" })
    form.desc:SetPoint("TOPLEFT", form.name, "BOTTOMLEFT", 0, -8)
    form.ok = UI.Button(form, "Crear sala", { primary = true, height = 26, width = 120 })
    form.ok:SetPoint("BOTTOMRIGHT", -16, 14)
    form.cancel = UI.Button(form, "Cancelar", { height = 26, width = 90 })
    form.cancel:SetPoint("RIGHT", form.ok, "LEFT", -8, 0)
    form.cancel:SetScript("OnClick", function()
      form:Hide()
    end)
    form.ok:SetScript("OnClick", function()
      local r = Chat.CreateRoom(form.name:GetText(), form.desc:GetText())
      if r then
        form:Hide()
        form.name:SetText("")
        form.desc:SetText("")
        select(r.id)
      end
    end)
    f.roomForm = form
  end,

  Refresh = function(f)
    local rail = f.rail
    local A = BG.Alliance
    local doc = A and A.Doc()
    local sisters = doc and A.Sisters() or {}
    local me = Names.Me()
    local rooms = Chat.Rooms()

    -- The rail's entries: your guild, the alliance (or the way to it), the rooms.
    local entries = {}
    local function head(text, plus)
      entries[#entries + 1] = { head = text, plus = plus }
    end
    local function chan(id, name, opts)
      entries[#entries + 1] = { id = id, name = name, role = opts and opts.role, mark = opts and opts.mark }
    end
    head("Tu hermandad")
    chan("guild", "Hermandad")
    if Chat.CanOfficer() then
      chan("officer", "Oficiales")
    end
    local W = BG.War
    for _, sq in ipairs(W and me and W.Squads() or {}) do
      if W.InSquad(sq, me) then
        chan("sq-" .. sq.id, "Escuadra «" .. sq.d.name .. "»", { mark = "»" })
      end
    end
    if doc then
      head("Alianza «" .. doc.name .. "»")
      chan("ally", "Toda la alianza", { mark = "*" })
      for _, g in ipairs(sisters) do
        chan("ally-" .. A.Code(g.k), g.n, { mark = "»" })
      end
      if A.ReadsOrg(me or "") then
        chan("allyorg", "Oficiales de la alianza", { mark = "*" })
      end
      if me and BG.Store.IsMaster(me) then
        chan("allymaster", "Maestros", { mark = "*" })
      end
    else
      head("Hermandades hermanas")
      entries[#entries + 1] = { cta = true }
    end
    head(#sisters > 0 and "Salas, con la alianza" or "Salas", true)
    for _, room in ipairs(rooms) do
      chan(room.id, room.name, { role = ROOM_ROLE[room.id] })
    end

    -- Rows shrink a little when there are many, so everything fits above the moderation button.
    local nHeads, nChans, ctaH = 0, 0, 0
    for _, e in ipairs(entries) do
      if e.head then
        nHeads = nHeads + 1
      elseif e.cta then
        ctaH = f.cta:GetHeight()
      else
        nChans = nChans + 1
      end
    end
    local railH = rail:GetHeight() or 0
    local avail = (railH > 0 and railH or 560) - 12 - (Chat.IsModerator() and 40 or 8)
    local rowH = math.max(20, math.min(28, math.floor((avail - nHeads * 26 - ctaH) / math.max(1, nChans))))
    local y, hi, bi = -6, 0, 0
    local all = {}
    f.cta:Hide()
    rail.newRoom:Hide()
    for _, e in ipairs(entries) do
      if e.head then
        hi = hi + 1
        local h = f.heads[hi]
        if not h then
          h = UI.Text(rail, 11, C.text3)
          f.heads[hi] = h
        end
        h:ClearAllPoints()
        h:SetPoint("TOPLEFT", 12, y - 10)
        h:SetPoint("RIGHT", e.plus and -38 or -10, 0)
        h:SetText(e.head)
        h:Show()
        if e.plus then
          rail.newRoom:ClearAllPoints()
          rail.newRoom:SetPoint("RIGHT", rail, "TOPRIGHT", -8, y - 15)
          rail.newRoom:Show()
        end
        y = y - 26
      elseif e.cta then
        f.cta:ClearAllPoints()
        f.cta:SetPoint("TOPLEFT", 0, y)
        f.cta:SetPoint("RIGHT")
        f.cta:Show()
        y = y - ctaH
      else
        bi = bi + 1
        local b = f.chanButtons[bi]
        if not b then
          b = channelButton(rail, e.name)
          f.chanButtons[bi] = b
        end
        b:ClearAllPoints()
        b:SetPoint("TOPLEFT", 1, y)
        b:SetPoint("RIGHT", -1, 0)
        b:SetHeight(rowH)
        b.text:SetText(e.name)
        b.role:SetShown(e.role ~= nil)
        b.hash:SetShown(e.role == nil)
        if e.role then
          BG.setRoleIcon(b.role, e.role)
        end
        b.hash:SetText(e.mark or "#")
        local id = e.id
        b.channel = id
        b:SetScript("OnClick", function()
          f.select(id)
        end)
        b:Show()
        all[id] = b
        y = y - rowH
      end
    end
    for i = hi + 1, #f.heads do
      f.heads[i]:Hide()
    end
    for i = bi + 1, #f.chanButtons do
      f.chanButtons[i]:Hide()
    end
    f.deskBtn:SetShown(Chat.IsModerator())
    if Chat.IsModerator() then
      all.desk = f.deskBtn
    end
    if not all[f.channel] then
      f.channel = "guild"
    end
    f.railButtons = all
    for id, b in pairs(all) do
      b:SetActive(id == f.channel)
      local n = Chat.unread[id]
      b.badge:SetText(n and n > 0 and id ~= f.channel and tostring(n) or "")
    end

    -- Header
    local main = f.main
    local isDesk = f.channel == "desk"
    if f.channel == "guild" then
      main.title:SetText("Hermandad")
      main.desc:SetText("Lo que dice cualquiera en el chat de hermandad, tenga o no el addon. Lo que se dijo mientras no estabas te lo pasa un compañero con BlazonGuild.")
    elseif f.channel == "officer" then
      main.title:SetText("Oficiales")
      main.desc:SetText("El chat de oficiales del juego: solo lo leen los rangos con permiso.")
    elseif isDesk then
      main.title:SetText("Moderación")
      main.desc:SetText("Casos, denuncias y silencios. Las decisiones las toma el maestro; el addon nunca expulsa a nadie.")
    elseif f.channel == "ally" then
      main.title:SetText("Toda la alianza")
      main.desc:SetText("Hablas con todas las hermandades de «" .. doc.name .. "». Cada mensaje lleva delante el nombre de su hermandad.")
    elseif f.channel == "allyorg" then
      main.title:SetText("Oficiales de la alianza")
      main.desc:SetText("Los organizadores de todas las hermandades de la alianza. Nadie más lo lee.")
    elseif f.channel == "allymaster" then
      main.title:SetText("Maestros")
      main.desc:SetText("Solo los maestros de las hermandades de la alianza.")
    elseif BG.War and BG.War.IsChannel(f.channel) then
      local sq = BG.Store.Get("squads", f.channel:sub(4))
      main.title:SetText(sq and sq.d and ("Escuadra «" .. sq.d.name .. "»") or "Escuadra")
      main.desc:SetText(sq and sq.d and ("Solo tu escuadra: " .. sq.d.leader .. " (jefe) y " .. #sq.d.members .. (#sq.d.members == 1 and " persona más" or " personas más")
        .. ". Va por susurro a cada uno: nadie más lo lee.") or "")
    elseif f.channel:sub(1, 5) == "ally-" then
      local g = A.Guild(A.KeyOfCode(f.channel:sub(6)))
      local p = g and A.Presence(g.k)
      main.title:SetText(g and g.n or "Hermandad hermana")
      main.desc:SetText("Solo " .. (BG.Guild.info and BG.Guild.info.name or "tu hermandad") .. " y " .. (g and g.n or "ellos") .. ": lo leen los miembros de las dos con BlazonGuild. "
        .. (p and ("Ahora tienen " .. p.onl .. " conectados, " .. #p.on .. " con BlazonGuild.") or "Aún sin contacto: llegará cuando se conecte alguien suyo con BlazonGuild."))
    else
      local room
      for _, r in ipairs(rooms) do
        if r.id == f.channel then
          room = r
        end
      end
      main.title:SetText(room and room.name or "Sala")
      main.desc:SetText((room and room.desc or "") .. (room and room.by and (" Creada por " .. room.by .. ".") or "")
        .. (room and room.builtin and #sisters > 0 and " Compartida con toda la alianza." or ""))
    end

    f.logPlate:SetShown(not isDesk)
    f.input:SetShown(not isDesk)
    f.send:SetShown(not isDesk)
    f.inputNote:SetShown(not isDesk)
    f.desk:SetShown(isDesk)
    if isDesk then
      f.desk:Refresh()
      return
    end

    Chat.MarkRead(f.channel)
    f.log:Clear()
    local history = Chat.History(f.channel)
    local shown = 0
    for i, line in ipairs(history) do
      if not Chat.Hidden(line.from) then
        f.log:AddMessage(Chat.FormatLine(f.channel, i, line), C.text[1], C.text[2], C.text[3])
        shown = shown + 1
      end
    end
    f.emptyLog:SetShown(shown == 0)
    f.emptyLog:SetText(f.channel == "guild" and "Todavía no hay mensajes en esta sesión. Lo que se diga en el chat de hermandad aparecerá aquí."
      or (A.IsChannel(f.channel) and "Nadie ha escrito aquí todavía. Empieza tú: lo leerán con BlazonGuild las hermandades de este canal."
      or "Nadie ha escrito aquí todavía. Empieza tú: lo leerán los miembros con BlazonGuild."))
    local muted = Chat.MutedUntil(Names.Me())
    local room = f.channel ~= "guild" and f.channel ~= "officer"
    if room and muted then
      f.inputNote:SetText(BG.colorize("Estás silenciado en las salas hasta las " .. UI.FormatTime(muted) .. ".", C.warning))
    elseif room and not BG.Consent.Accepted() then
      f.inputNote:SetText(BG.colorize("Acepta la privacidad para hablar en las salas.", C.warning))
    end
    f.input.placeholder:SetText("Escribe en " .. main.title:GetText() .. "… (Intro para enviar)")
  end,
})

BG:On("BG_CHAT_LINE", function(channel, line)
  local f = BG.window and BG.window.viewFrames.chat
  if f and f:IsShown() and BG.db.settings.lastView == "chat" and channel == f.channel and not Chat.Hidden(line.from) then
    f.log:AddMessage(Chat.FormatLine(channel, #Chat.History(channel), line), C.text[1], C.text[2], C.text[3])
    f.emptyLog:Hide()
    Chat.MarkRead(channel)
  else
    BG:RefreshChrome()
    if f and f:IsShown() and BG.db.settings.lastView == "chat" then
      BG.views.chat.Refresh(f, BG.views.chat)
    end
  end
end)
BG:On("BG_CHAT_REDRAW", function()
  BG:RefreshView("chat")
end)
BG:On("BG_STORE_CHANGED", function(name)
  if name == "rooms" or name == "chatdel" or name == "mutes" or name == "cases" or name == "filter" or name == "strikes" then
    BG:RefreshView("chat")
  end
end)
BG:On("BG_ALLIANCE_CHANGED", function()
  BG:RefreshView("chat")
end)
