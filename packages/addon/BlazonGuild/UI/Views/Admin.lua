-- Administración: how the connection with the guild is doing (privacy, a message test with its result, who
-- has BlazonGuild, the messenger, traffic, internal errors) and the guild's settings (which ranks organise).
-- Everything readable at a glance in the window; the chat box is never where a result hides.
local _, BG = ...
local UI, C = BG.UI, BG.color
local Comm, Peers, Diag = BG.Comm, BG.Peers, BG.Diagnostics

local PAD = 24
local OK_ICON = "Interface\\RaidFrame\\ReadyCheck-Ready"
local BAD_ICON = "Interface\\RaidFrame\\ReadyCheck-NotReady"
local WAIT_ICON = "Interface\\RaidFrame\\ReadyCheck-Waiting"

local function statusRow(parent, i, label)
  local r = CreateFrame("Frame", nil, parent)
  r:SetHeight(40)
  r:SetPoint("TOPLEFT", 16, -44 - (i - 1) * 44)
  r:SetPoint("RIGHT", -16, 0)
  r.icon = r:CreateTexture(nil, "ARTWORK")
  r.icon:SetSize(18, 18)
  r.icon:SetPoint("TOPLEFT", 0, -2)
  r.label = UI.Text(r, 11, C.text3)
  r.label:SetPoint("TOPLEFT", r.icon, "TOPRIGHT", 10, 1)
  r.label:SetText(label)
  r.value = UI.Text(r, 13, C.text)
  r.value:SetPoint("TOPLEFT", r.label, "BOTTOMLEFT", 0, -3)
  r.value:SetPoint("RIGHT", -120, 0)
  local line = r:CreateTexture(nil, "BACKGROUND")
  line:SetColorTexture(C.line[1], C.line[2], C.line[3], 0.7)
  line:SetHeight(1)
  line:SetPoint("BOTTOMLEFT", 0, 0)
  line:SetPoint("BOTTOMRIGHT", 0, 0)
  function r:Set(state, text)
    self.icon:SetTexture(BG.file(state == "ok" and OK_ICON or (state == "bad" and BAD_ICON or WAIT_ICON), BG.media .. "lozenge.png"))
    self.value:SetText(text)
  end
  return r
end

BG:RegisterView("admin", {
  Build = function(f, def)
    f.hero = UI.Hero(f, 118)
    f.hero:SetPoint("TOPLEFT")
    f.hero:SetPoint("TOPRIGHT")
    f.hero:SetIcon("Interface\\Icons\\INV_Misc_Gear_01")
    f.hero.title:SetText("Administración")
    f.hero.sub:SetText("Cómo va la conexión con tu hermandad, qué compartes y los ajustes de la hermandad.")

    -- Connection plate
    local conn = UI.Plate(f, { corners = 18, rail = 0.24 })
    conn:SetPoint("TOPLEFT", f.hero, "BOTTOMLEFT", PAD, -16)
    conn:SetPoint("BOTTOM", 0, 18)
    f.conn = conn
    conn.head = UI.Heading(conn, "Conexión con tu hermandad")
    conn.head:SetPoint("TOPLEFT", 16, -8)
    conn.head:SetPoint("TOPRIGHT", -16, -8)
    f.rows = {
      privacy = statusRow(conn, 1, "Privacidad"),
      test = statusRow(conn, 2, "Prueba de mensajes"),
      peers = statusRow(conn, 3, "Con BlazonGuild ahora"),
      messenger = statusRow(conn, 4, "Mensajero de la hermandad"),
      traffic = statusRow(conn, 5, "Mensajes de esta sesión"),
      errors = statusRow(conn, 6, "Errores internos"),
      alliance = statusRow(conn, 7, "Alianza"),
      lang = statusRow(conn, 8, "Idioma del addon"),
      tools = statusRow(conn, 9, "Herramientas"),
    }
    -- Tools: the in-game self-test, and seeing the addon as a member does (organisers).
    f.selfBtn = UI.Button(f.rows.tools, "Autoprueba", { primary = true, height = 24, width = 104 })
    f.selfBtn:SetPoint("RIGHT", 0, -2)
    f.selfBtn:SetScript("OnClick", function()
      BG.SelfTest.Open()
    end)
    f.viewBtn = UI.Button(f.rows.tools, "Ver como miembro", { height = 24, width = 140 })
    f.viewBtn:SetPoint("RIGHT", f.selfBtn, "LEFT", -6, 0)
    f.viewBtn:SetScript("OnClick", function()
      BG.SetViewAs(not BG.viewAs and "member" or nil)
    end)
    -- the capture mode (Core/Demo.lua): an example guild on this screen, to take pictures of every screen. In the
    -- banner (the tools row has no room for a third button)
    f.shotBtn = UI.Button(f.hero, "Modo capturas", { height = 24, width = 150 })
    f.shotBtn:SetPoint("BOTTOMRIGHT", -PAD, 14)
    f.hero.sub:SetPoint("RIGHT", f.shotBtn, "LEFT", -16, 0)
    f.hero.title:SetPoint("RIGHT", f.shotBtn, "LEFT", -16, 0)
    f.shotBtn:SetScript("OnClick", function()
      BG.commands.capturas()
    end)
    f.shotBtn:HookScript("OnEnter", function(self)
      GameTooltip:SetOwner(self, "ANCHOR_TOP")
      GameTooltip:SetText("Modo capturas", 1, 1, 1)
      GameTooltip:AddLine("Una hermandad de ejemplo con nombres inventados, solo en tu pantalla, para hacer capturas de cada pantalla. No sale nada de tu juego. Vuelve a la tuya con el mismo botón o /bg capturas.", 0.8, 0.8, 0.8, true)
      BG.ShowTip()
    end)
    f.shotBtn:HookScript("OnLeave", function()
      GameTooltip:Hide()
    end)
    f.rows.tools.value:SetPoint("RIGHT", f.viewBtn, "LEFT", -8, 0)
    local langOpts = {}
    for _, l in ipairs(BG.Locale.LANGS) do
      langOpts[#langOpts + 1] = { value = l.key, label = l.label }
    end
    f.langPicker = UI.Picker(f.rows.lang, { width = 104, menuWidth = 220, placeholder = "Cambiar", onChange = function(v)
      BG.Locale.Choose(v)
      f.langPicker:SetValue(nil, true)
      def.Refresh(f, def)
      -- (Forever does not let an addon reload the interface: ReloadUI from here was refused with «una acción de interfaz
      -- ha fallado por culpa de un accesorio». The player types /reload, as Olympus asks too.)
      BG.UI.Dialog({ title = "Idioma", items = { "El idioma nuevo se aplica al recargar la interfaz.",
        { bullet = "Escribe /reload en el chat y pulsa Intro (ahora o cuando quieras)." },
        { note = "El juego no deja que un accesorio recargue la interfaz por sí solo." } },
        primary = { label = "Entendido" } })
    end })
    f.langPicker:SetOptions(langOpts)
    f.langPicker:SetPoint("RIGHT", 0, -2)
    f.privacyBtn = UI.Button(f.rows.privacy, "Revisar", { height = 24, width = 104 })
    f.privacyBtn:SetPoint("RIGHT", 0, -2)
    f.privacyBtn:SetScript("OnClick", function()
      BG.Consent.Open()
    end)
    f.testBtn = UI.Button(f.rows.test, "Probar ahora", { primary = true, height = 24, width = 104 })
    f.testBtn:SetPoint("RIGHT", 0, -2)
    f.testBtn:SetScript("OnClick", function()
      Diag.Ping()
      def.Refresh(f, def)
    end)
    f.errorsBtn = UI.Button(f.rows.errors, "Ver", { height = 24, width = 104 })
    f.errorsBtn:SetPoint("RIGHT", 0, -2)
    f.errorsBtn:SetScript("OnClick", function()
      local list = BG.db.errors or {}
      local items = {}
      for i = 1, math.min(4, #list) do
        items[#items + 1] = { bullet = list[i].at:sub(1, 16):gsub("T", " ") .. "  (" .. tostring(list[i].version or "?") .. ")  " .. list[i].where .. ": " .. tostring(list[i].error):sub(1, 140) }
      end
      items[#items + 1] = { note = "Se guardan para poder corregirlos. Si me mandas una captura de esto, sé exactamente qué falló. Entre paréntesis, la versión del addon en la que pasó." }
      BG.UI.Dialog({ title = "Errores internos guardados", items = items, primary = { label = "Cerrar" },
        secondary = { label = "Borrarlos", fn = function()
          BG.db.errors = {}
          BG:RefreshView("admin")
        end } })
    end)

    -- Right column: who has the addon, and the organisers setting
    local side = UI.Plate(f, { corners = 18, rail = 0.24 })
    side:SetPoint("TOPLEFT", conn, "TOPRIGHT", 18, 0)
    side:SetPoint("BOTTOMRIGHT", -PAD, 18)
    f.side = side
    side.head = UI.Heading(side, "Quién usa BlazonGuild")
    side.head:SetPoint("TOPLEFT", 16, -8)
    side.head:SetPoint("TOPRIGHT", -16, -8)
    f.peerList = UI.List(side, 24, function(list)
      local r = CreateFrame("Button", nil, list)
      r.icon = r:CreateTexture(nil, "ARTWORK")
      r.icon:SetSize(16, 16)
      r.icon:SetPoint("LEFT", 2, 0)
      r.name = UI.Text(r, 12, C.text)
      r.name:SetPoint("LEFT", r.icon, "RIGHT", 7, 0)
      r.ver = UI.Text(r, 11, C.text3, { justify = "RIGHT" })
      r.ver:SetPoint("RIGHT", -4, 0)
      local hl = r:CreateTexture(nil, "HIGHLIGHT")
      hl:SetColorTexture(C.gold[1], C.gold[2], C.gold[3], 0.08)
      hl:SetAllPoints()
      r:SetScript("OnClick", function(self)
        BG.UI.ShowProfile(self.peer.name)
      end)
      return r
    end, function(r, p)
      r.peer = p
      local m = BG.Guild.Find(p.name)
      BG.setClassIcon(r.icon, m and m.classFile)
      local cc = BG.classColor(m and m.classFile)
      r.name:SetText(BG.colorize(p.name, cc) .. (p.me and BG.colorize("  (tú)", C.gold) or ""))
      r.ver:SetText("v" .. tostring(p.version) .. (p.name == Peers.Messenger() and ", mensajero" or ""))
    end)
    f.peerList:SetPoint("TOPLEFT", side.head, "BOTTOMLEFT", 0, -10)
    f.peerList:SetPoint("RIGHT", -16, 0)
    f.peerList:SetHeight(190)

    side.orgHead = UI.Heading(side, "Quién organiza")
    side.orgHead:SetPoint("TOPLEFT", f.peerList, "BOTTOMLEFT", 0, -14)
    side.orgHead:SetPoint("RIGHT", -16, 0)
    side.orgText = UI.Text(side, 12, C.text2, { wrap = true })
    side.orgText:SetPoint("TOPLEFT", side.orgHead, "BOTTOMLEFT", 0, -8)
    side.orgText:SetPoint("RIGHT", -16, 0)
    side.orgText:SetText("Cualquier miembro puede crear sus raids y grupos. Los organizadores, además, gestionan todas las raids de la hermandad y llaman a los oficiales.")
    f.orgPicker = UI.Picker(side, { width = 260, onChange = function(v)
      local ok, why = BG.Store.Put("cfg", "guild", { organiserMax = v })
      if not ok then
        BG:Notify("No se pudo guardar", why == "permiso" and "Solo el maestro de la hermandad puede cambiarlo." or tostring(why), { kind = "warning" })
      end
    end })
    f.orgPicker:SetPoint("TOPLEFT", side.orgText, "BOTTOMLEFT", 0, -10)
    f.orgNote = UI.Text(side, 11, C.text3, { wrap = true })
    f.orgNote:SetPoint("TOPLEFT", f.orgPicker, "BOTTOMLEFT", 0, -6)
    f.orgNote:SetPoint("RIGHT", -16, 0)

    f:SetScript("OnSizeChanged", function(self, w)
      self.conn:SetWidth(math.floor((w - PAD * 2 - 18) * 0.56))
    end)
  end,

  Refresh = function(f)
    local accepted = BG.Consent.Accepted()
    local rows = f.rows
    if accepted then
      local since = BG.db.consent.at and date("%d/%m/%Y", BG.db.consent.at) or ""
      rows.privacy:Set("ok", "Aceptada" .. (since ~= "" and (" el " .. since) or ""))
    else
      rows.privacy:Set("bad", "Sin aceptar: el addon no envía nada")
    end
    f.privacyBtn.text:SetText(accepted and "Revisar" or "Aceptar")

    local p = Diag.lastPing
    if not p then
      rows.test:Set("wait", accepted and "Sin probar en esta sesión" or "Acepta la privacidad para probar")
    elseif not p.done and not p.echo then
      rows.test:Set("wait", "Probando… espera unos segundos")
    elseif p.echo then
      local who = #p.answers == 0 and "" or (#p.answers == 1 and (", y " .. p.answers[1] .. " respondió") or (", y respondieron " .. #p.answers))
      rows.test:Set("ok", string.format("Correcto en %d ms%s", p.ms or 0, who))
    else
      rows.test:Set("bad", "No volvió: el juego bloquea mensajes aquí (banda, mazmorra o combate)")
    end
    f.testBtn:SetEnabled(accepted and IsInGuild())

    local active = Peers.Active()
    local others = #active - (accepted and 1 or 0)
    rows.peers:Set(#active > 0 and "ok" or "wait", #active == 0 and "Nadie (acepta la privacidad para aparecer)"
      or (#active .. (#active == 1 and " miembro" or " miembros") .. (others == 0 and ": solo tú por ahora" or "")))
    local messenger = Peers.Messenger()
    rows.messenger:Set(messenger and "ok" or "wait", messenger and (messenger .. (BG.Names.IsMe(messenger) and " (tú)" or "")) or "Nadie todavía")
    local s = Comm.stats
    local held = Comm.Held()
    rows.traffic:Set(held and "wait" or "ok", string.format("%d enviados, %d recibidos%s", s.sent, s.recv,
      held and string.format(", %d en espera (el juego bloquea mensajes aquí)", Comm.QueueSize()) or (Comm.QueueSize() > 0 and (", " .. Comm.QueueSize() .. " en cola") or "")))
    -- (only this version's errors are a red mark: the older ones were in a version already replaced)
    local pick = BG.db.settings.lang or "auto"
    local labelOf = {}
    for _, l in ipairs(BG.Locale.LANGS) do
      labelOf[l.key] = l.label
    end
    local now = labelOf[BG.Locale.lang] or BG.Locale.lang
    rows.lang:Set("ok", (pick == "auto" and (now .. ", el del juego") or now) .. ((pick ~= "auto" and pick ~= BG.Locale.lang) and (", " .. (labelOf[pick] or pick) .. " al recargar") or ""))
    local realOrg = BG.Store.RealOrganiser(BG.Names.Me() or "")
    local demo = BG.Demo and BG.Demo.Active()
    rows.tools:Set((BG.viewAs or demo) and "wait" or "ok", demo and "Modo capturas: una hermandad de ejemplo" or (BG.viewAs and "Ves el addon como un miembro" or "Comprueba el addon en este juego"))
    f.shotBtn.text:SetText(demo and "Volver a mi hermandad" or "Modo capturas")
    f.viewBtn:SetShown(realOrg or BG.viewAs ~= nil)
    f.viewBtn.text:SetText(BG.viewAs and "Volver a mi vista" or "Ver como miembro")
    local errs, old = 0, 0
    for _, e in ipairs(BG.db.errors or {}) do
      if e.version == BG.version then
        errs = errs + 1
      else
        old = old + 1
      end
    end
    rows.errors:Set(errs == 0 and "ok" or "bad", errs > 0 and (errs .. " en esta versión") or (old > 0 and "Ninguno en esta versión" or "Ninguno"))
    f.errorsBtn:SetShown(errs + old > 0)

    local doc = BG.Alliance.Doc()
    if doc then
      local sisters, live = BG.Alliance.Sisters(), 0
      for _, g in ipairs(sisters) do
        if BG.Alliance.Presence(g.k) then
          live = live + 1
        end
      end
      rows.alliance:Set((#sisters == 0 or live > 0) and "ok" or "wait", "«" .. doc.name .. "»: " .. (#sisters + 1) .. " hermandades, en contacto con " .. live)
    else
      rows.alliance:Set("wait", "Sin alianza")
    end

    f.peerList:SetItems(active)
    local info = BG.Guild.info
    local opts = {}
    for idx = 0, 9 do
      local name = info and info.ranks[idx]
      if name then
        local names = {}
        for j = 0, idx do
          names[#names + 1] = info.ranks[j]
        end
        opts[#opts + 1] = { value = idx, label = idx == 0 and ("Solo " .. name) or table.concat(names, ", ") }
      end
    end
    f.orgPicker:SetOptions(opts)
    f.orgPicker:SetValue(BG.Store.OrganiserMax(), true)
    local master = BG.Guild.me and BG.Guild.me.rankIndex == 0
    f.orgPicker:SetEnabled(master)
    f.orgPicker:SetAlpha(master and 1 or 0.6)
    f.orgNote:SetText(master and "Como maestro, puedes cambiarlo; se aplica en el addon de todos."
      or "Solo el maestro de la hermandad puede cambiarlo.")
  end,
})

BG:On("BG_PING_UPDATED", function()
  BG:RefreshView("admin")
end)
BG:On("BG_PEERS_CHANGED", function()
  BG:RefreshView("admin")
end)
BG:On("BG_STORE_CHANGED", function(name)
  if name == "cfg" then
    BG:RefreshView("admin")
    BG:RefreshView("raids")
  end
end)
