-- Alianza: the sister guilds. Without an alliance, what it is and how to start one (the master creates it or
-- accepts an invitation; everyone else sees who decides). With one: the totals of all its guilds (people, not
-- only characters), a card per guild (members, online, BlazonGuild users, last contact, its captains) with a
-- button to talk to them, and on the side the leadership (who leads, the votes, the leader's calls and new key),
-- the cargos of our guild, the invitations, hiding and the way out. A second tab, «Cartas y avisos» (0.22.0,
-- AllianceActs.lua): the leader's letters to the masters, the doors (which guild takes the new players) and who is
-- hidden in the alliance's chats.
local _, BG = ...
local UI, C = BG.UI, BG.color
local Alliance, Names, Store = BG.Alliance, BG.Names, BG.Store

local PAD = 24
local BANNER = { ALLIANCE = "Interface\\Icons\\INV_BannerPVP_02", HORDE = "Interface\\Icons\\INV_BannerPVP_01" }

local function banner(faction)
  return BG.file(BANNER[faction or "ALLIANCE"] or BANNER.ALLIANCE, "Interface\\Icons\\INV_Misc_Note_06")
end

local function masterName()
  for _, m in ipairs(BG.Guild.members or {}) do
    if m.rankIndex == 0 then
      return Names.Short(m.name)
    end
  end
  return nil
end

local function agoText(at)
  if not at then
    return nil
  end
  local s = Store.Now() - at
  if s < 120 then
    return "ahora"
  elseif s < 3600 then
    return "hace " .. math.floor(s / 60) .. " min"
  elseif s < 86400 then
    return "hace " .. math.floor(s / 3600) .. " h"
  end
  return "hace " .. math.floor(s / 86400) .. " días"
end

local function openChat(channel)
  BG.db.settings.chatChannel = channel
  BG:ShowView("chat")
  local f = BG.window and BG.window.viewFrames.chat
  if f and f.select then
    f.select(channel)
  end
end

local function why(w)
  return ({ permiso = "Solo el maestro de la hermandad puede hacerlo.", nombre = "Escribe un nombre.", ya = "Ya estáis en una alianza.",
    consent = "Acepta antes la privacidad (/bg privacidad).", ["es de tu hermandad"] = "Esa persona es de tu propia hermandad.",
    llena = "La alianza ya tiene diez hermandades.", ["no es de tu hermandad"] = "Esa persona no es de tu hermandad.",
    firma = "Tu firma aún no está en la alianza. La añade vuestro maestro la próxima vez que se conecte.",
    ocupado = "La alianza estaba cambiando en ese momento. Prueba otra vez.", ["no existe"] = "Esa hermandad ya no está en la alianza.",
    ["sin alianza"] = "No estáis en ninguna alianza." })[w] or ("No se pudo (" .. tostring(w) .. ").")
end

local function names(list)
  return #list > 0 and table.concat(list, ", ") or nil
end

-- Guild cards ------------------------------------------------------------------------------------------------
local function guildCard(list)
  local c = UI.Card(list)
  c.talk = UI.CardButton(c, "Hablar", { height = 24, width = 76 })
  c.talk:SetScript("OnClick", function()
    if c.guild then
      openChat("ally-" .. Alliance.Code(c.guild.k))
    end
  end)
  c.vote = UI.CardButton(c, "Votar", { height = 24, width = 70 })
  c.vote:SetScript("OnClick", function()
    local g = c.guild
    if not g then
      return
    end
    BG.UI.Dialog({
      title = "Votar a " .. g.n,
      items = { "Tu voto dice que el maestro de " .. g.n .. " lidere la alianza.",
        { bullet = "Cambia de líder cuando más de la mitad de los maestros vota a la misma hermandad." },
        { note = "Puedes cambiar tu voto cuando quieras." } },
      primary = { label = "Votar", fn = function()
        local ok, w = Alliance.Vote(g.k, function(doc, w2)
          BG:Notify(doc and "Voto dado" or "No se pudo votar", doc and ("Tu voto es para " .. g.n .. ".") or why(w2), { kind = doc and "success" or "warning", view = "alliance" })
        end)
        if not ok then
          BG:Notify("No se pudo votar", why(w), { kind = "warning" })
        end
      end },
      secondary = { label = "Cancelar" },
    })
  end)
  c.out = UI.CardButton(c, "Expulsar", { height = 24, width = 80 })
  c.out:SetScript("OnClick", function()
    local g = c.guild
    if not g then
      return
    end
    BG.UI.Dialog({
      title = "Sacar a " .. g.n .. " de la alianza",
      items = { g.n .. " dejará de ver el chat de la alianza y sus salas.",
        { bullet = "La alianza recibe una clave nueva, para que no puedan seguir escribiendo." },
        { note = "Para volver, alguien tendrá que invitarlos de nuevo." } },
      primary = { label = "Expulsar", fn = function()
        local ok, w = Alliance.Expel(g.k, function(doc, w2)
          BG:Notify(doc and "Hermandad expulsada" or "No se pudo", doc and (g.n .. " ya no está en la alianza.") or why(w2), { kind = doc and "info" or "warning", view = "alliance" })
        end)
        if not ok then
          BG:Notify("No se pudo", why(w), { kind = "warning" })
        end
      end },
      secondary = { label = "Cancelar" },
    })
  end)
  return c
end

-- Buttons from the right edge, only those shown; the texts on the right sit left of them.
local function layoutButtons(c)
  local anchor
  for _, b in ipairs({ c.talk, c.vote, c.out }) do
    b:ClearAllPoints()
    if b:IsShown() then
      if anchor then
        b:SetPoint("RIGHT", anchor, "LEFT", -6, 0)
      else
        b:SetPoint("RIGHT", -10, 0)
      end
      anchor = b
    end
  end
  c.right:ClearAllPoints()
  if anchor then
    c.right:SetPoint("TOPRIGHT", anchor, "TOPLEFT", -12, 2)
  else
    c.right:SetPoint("TOPRIGHT", -12, -10)
  end
  c.right2:ClearAllPoints()
  c.right2:SetPoint("TOPRIGHT", c.right, "BOTTOMRIGHT", 0, -4)
end

local function fillGuildCard(c, g)
  c.guild = g
  local mine = BG.Guild.info and g.k == BG.Guild.info.key
  local doc = Alliance.Doc()
  local lead = Alliance.Lead() == g.k
  local master = Store.IsMaster(Names.Me() or "")
  c.icon:SetTexture(banner(g.f))
  c.title:SetText(g.n .. (lead and BG.colorize("  líder", C.goldHi) or "") .. (mine and BG.colorize("  la vuestra", C.gold) or "")
    .. (doc and doc.founder == g.k and not lead and BG.colorize("  fundadora", C.text3) or ""))
  c.talk:SetShown(not mine)
  local myVote = BG.Guild.info and Alliance.VoteOf(BG.Guild.info.key)
  c.vote:SetShown(master and myVote ~= g.k)
  c.out:SetShown(not mine and Alliance.AmLeader())
  layoutButtons(c)
  local caps = names(Alliance.Cargos(g.k, "cap"))
  local tail = caps and (". Capitanes: " .. caps) or ""
  if mine then
    local s = BG.Guild.stats
    c.sub:SetText(string.format("%d miembros, %d conectados, %d con BlazonGuild. Maestro: %s%s", s and s.total or 0, s and s.online or 0, #BG.Peers.Active(), masterName() or "?", tail))
    c.right:SetText(BG.colorize("en línea", C.success))
    c.right2:SetText(myVote and myVote ~= g.k and ("votáis a " .. ((Alliance.Guild(myVote) or {}).n or "?")) or "")
    c.accent:SetColorTexture(C.gold[1], C.gold[2], C.gold[3], 0.9)
    return
  end
  local at, p = Alliance.LastSeen(g.k)
  local live = Alliance.Presence(g.k)
  if p then
    c.sub:SetText(string.format("%d miembros, %d conectados, %d con BlazonGuild. Maestro: %s%s", p.tot or 0, p.onl or 0, live and #live.on or (p.addon or 0), g.m or "?", tail))
  else
    c.sub:SetText("Maestro: " .. (g.m or "?") .. ". Aún sin contacto: llegará cuando se conecte alguien suyo con BlazonGuild.")
  end
  c.right:SetText(live and BG.colorize("en contacto", C.success) or (at and ("visto " .. agoText(at)) or BG.colorize("sin contacto", C.text3)))
  c.right2:SetText(myVote == g.k and BG.colorize("tu voto", C.gold) or (live and live.m and ("mensajero: " .. live.m) or ""))
  local ac = live and C.success or C.line
  c.accent:SetColorTexture(ac[1], ac[2], ac[3], 0.9)
end

-- Invitation cards (without an alliance) -------------------------------------------------------------------
local function inviteCard(list)
  local c = UI.Card(list)
  c.no = UI.CardButton(c, "Rechazar", { height = 24, width = 84 })
  c.no:SetPoint("BOTTOMRIGHT", -10, 8)
  c.yes = UI.CardButton(c, "Aceptar", { primary = true, height = 24, width = 84 })
  c.yes:SetPoint("RIGHT", c.no, "LEFT", -6, 0)
  c.yes:SetScript("OnClick", function()
    local inv = c.inv
    if not inv then
      return
    end
    BG.UI.Dialog({
      title = "Unirse a «" .. inv.d.an .. "»",
      items = { inv.d.g.n .. " os invita a su alianza.", { bullet = "Tendréis un chat común, con una pestaña para cada hermandad." },
        { bullet = "Las salas de roles y el comercio se comparten con todas." },
        { bullet = "Cada hermandad sigue con su maestro y sus normas; podéis salir cuando quieras." } },
      primary = { label = "Aceptar", fn = function()
        local ok, w = Alliance.Accept(inv.id)
        BG:Notify(ok and "Aceptada" or "No se pudo", ok and ("Avisamos a " .. inv.d.g.n .. ". En cuanto contesten, estaréis dentro.") or why(w), { kind = ok and "success" or "warning" })
      end },
      secondary = { label = "Ahora no" },
    })
  end)
  c.no:SetScript("OnClick", function()
    if c.inv then
      Alliance.Decline(c.inv.id)
    end
  end)
  return c
end

local function fillInviteCard(c, inv)
  c.inv = inv
  c:SetHeight(62)
  c.icon:SetTexture(banner(inv.d.g.f))
  c.title:SetText(inv.d.g.n .. " os invita")
  c.sub:SetText("A su alianza «" .. inv.d.an .. "». La recibió " .. (inv.d.via or "?") .. ".")
  local master = Store.IsMaster(Names.Me())
  local accepted = inv.d.st == "ACCEPTED"
  c.yes:SetShown(master and not accepted)
  c.no:SetShown(master and not accepted)
  c.right:SetText(accepted and BG.colorize("aceptada: esperando su respuesta", C.warning) or (master and "" or "decide el maestro"))
  c.right2:SetText("")
end

-- Side panel pieces --------------------------------------------------------------------------------------------
local function section(parent, title, after, gap)
  local h = UI.Heading(parent, title)
  if after then
    h:SetPoint("TOPLEFT", after, "BOTTOMLEFT", 0, -(gap or 14))
  else
    h:SetPoint("TOPLEFT", 16, -8)
  end
  h:SetPoint("RIGHT", -16, 0)
  local text = UI.Text(parent, 12, C.text2, { wrap = true })
  text:SetPoint("TOPLEFT", h, "BOTTOMLEFT", 0, -6)
  text:SetPoint("RIGHT", -16, 0)
  text:SetSpacing(3)
  return h, text
end

local function leadershipText()
  local doc = Alliance.Doc()
  local lead = Alliance.LeaderGuild()
  local lines = {}
  if lead then
    lines[1] = BG.TF("Líder: %s, maestro de %s.", BG.colorize(lead.m or "?", C.goldHi), lead.n)
  end
  local count, need = BG.AllianceRules.Tally(doc)
  local parts = {}
  for _, g in ipairs(doc.guilds) do
    if count[g.k] then
      parts[#parts + 1] = g.n .. " " .. count[g.k]
    end
  end
  lines[#lines + 1] = (#parts > 0 and ("Votos: " .. table.concat(parts, ", ") .. ". ") or "Aún nadie ha votado. ")
    .. "Cambia con " .. need .. (need == 1 and " voto" or " votos") .. " de maestros."
  return table.concat(lines, "\n")
end

local function cargosText(k)
  local caps, msgs = Alliance.Cargos(k, "cap"), Alliance.Cargos(k, "msg")
  if #caps == 0 and #msgs == 0 then
    return "Sin cargos. Los capitanes leen y escriben en «Oficiales de la alianza»; los mensajeros llevan los mensajes a las otras hermandades."
  end
  local out = {}
  if #caps > 0 then
    out[#out + 1] = "Capitanes: " .. table.concat(caps, ", ") .. "."
  end
  if #msgs > 0 then
    out[#out + 1] = "Mensajeros: " .. table.concat(msgs, ", ") .. "."
  end
  return table.concat(out, " ")
end

-- «Cartas y avisos» ---------------------------------------------------------------------------------------------
local TABS = { { value = "guilds", label = "Hermandades" }, { value = "acts", label = "Cartas y avisos" }, { value = "manage", label = "Gestión" } }
local HIDE_FOR = { { value = 1, label = "1 hora" }, { value = 24, label = "1 día" }, { value = 168, label = "7 días" } }
local DOORS_FOR = { { value = 1, label = "1 hora" }, { value = 2, label = "2 horas" }, { value = 4, label = "4 horas" }, { value = 8, label = "8 horas" } }

local function actWhy(w)
  return ({ permiso = "Solo los organizadores de la hermandad que lidera la alianza.", firma = "No se pudo firmar: abre /reload y vuelve a probar.",
    ["vacío"] = "Escribe el asunto y la carta.", largo = "Es demasiado largo.", ["sin nombre"] = "Escribe un nombre.",
    ["la tuya"] = "No puedes ocultar a tu propia hermandad.", ["no existe"] = "Ya no existe." })[w] or tostring(w or "No se pudo.")
end

local function letterCard(list)
  local c = UI.Card(list)
  c.icon:SetTexture("Interface\\Icons\\INV_Letter_15")
  c.read = UI.CardButton(c, "Marcar leída", { height = 22, width = 120 })
  c.read:SetPoint("BOTTOMRIGHT", -10, 8)
  c.read:SetScript("OnClick", function()
    if c.letter then
      BG.AllianceActs.MarkRead(c.letter.id)
    end
  end)
  return c
end

local function fillLetter(c, l)
  c.letter = l
  c.key = l.id
  c:SetHeight(58)
  c.title:SetText(l.title .. ((not l.read and not l.mine) and BG.colorize("  nueva", C.gold) or ""))
  c.sub:SetText(string.format("De %s, de «%s», %s.", l.from, l.guild, UI.FormatDate(l.at, true)))
  c.detail = { l.text, l.captains and "Para los maestros y los capitanes." or "Para los maestros." }
  c.right:SetText(l.mine and string.format("leída por %d", l.readers) or (l.read and "leída" or ""))
  c.right2:SetText("")
  c.read:SetShown(not l.mine and not l.read)
  local ac = (not l.read and not l.mine) and C.gold or C.line
  c.accent:SetColorTexture(ac[1], ac[2], ac[3], 0.9)
end

local function hideCard(list)
  local c = UI.Card(list)
  c.icon:SetTexture("Interface\\Icons\\Spell_Shadow_Silence")
  c.lift = UI.CardButton(c, "Quitar", { height = 22, width = 80 })
  c.lift:SetPoint("BOTTOMRIGHT", -10, 8)
  c.lift:SetScript("OnClick", function()
    if c.hidden then
      local ok, w = BG.AllianceActs.Unhide(c.hidden.id)
      if not ok then
        BG:Notify("No se pudo", actWhy(w), { kind = "warning" })
      end
    end
  end)
  return c
end

local function fillHide(c, h)
  c.hidden = h
  c.key = h.id
  c:SetHeight(44)
  c.title:SetText(h.g and string.format("Hermandad «%s»", h.label) or h.label)
  c.sub:SetText(string.format("Hasta el %s.", UI.FormatDate(h["until"], true)) .. (h.why and h.why ~= "" and (" " .. h.why) or ""))
  c.right:SetText("")
  c.right2:SetText("")
  c.lift:SetShown(BG.AllianceActs.MayLead())
end

local function buildActs(f)
  local acts = CreateFrame("Frame", nil, f)
  acts:SetPoint("TOPLEFT", f.hero, "BOTTOMLEFT", PAD, -16)
  acts:SetPoint("BOTTOMRIGHT", -PAD, 18)
  f.acts = acts
  local Acts = BG.AllianceActs

  -- Letters (left).
  local L = UI.Plate(acts, { corners = 18, rail = 0.24 })
  L:SetPoint("TOPLEFT")
  L:SetPoint("BOTTOM")
  acts.letters = L
  L.head = UI.Heading(L, "Cartas a los líderes")
  L.head:SetPoint("TOPLEFT", 16, -8)
  L.head:SetPoint("TOPRIGHT", -16, -8)
  L.subject = UI.EditBox(L, { maxLetters = 60, placeholder = "Asunto" })
  L.subject:SetPoint("TOPLEFT", L.head, "BOTTOMLEFT", 0, -8)
  L.subject:SetPoint("RIGHT", -16, 0)
  L.body = UI.EditBox(L, { maxLetters = 400, placeholder = "La carta: qué quieres decir a los maestros" })
  L.body:SetPoint("TOPLEFT", L.subject, "BOTTOMLEFT", 0, -6)
  L.body:SetPoint("RIGHT", -16, 0)
  L.to = UI.Picker(L, { width = 200 })
  L.to:SetPoint("TOPLEFT", L.body, "BOTTOMLEFT", 0, -6)
  L.to:SetOptions({ { value = "M", label = "A los maestros" }, { value = "MC", label = "A maestros y capitanes" } })
  L.to:SetValue("M", true)
  L.send = UI.Button(L, "Enviar la carta", { primary = true, height = 26, width = 130 })
  L.send:SetPoint("LEFT", L.to, "RIGHT", 8, 0)
  L.note = UI.Text(L, 11, C.text3, { wrap = true })
  L.note:SetPoint("TOPLEFT", L.to, "BOTTOMLEFT", 0, -4)
  L.note:SetPoint("RIGHT", -16, 0)
  L.send:SetScript("OnClick", function()
    local ok, w = Acts.Letter(L.subject:GetText(), L.body:GetText(), L.to:GetValue() == "MC", function(act, w2)
      if act then
        L.subject:SetText("")
        L.body:SetText("")
      end
      L.note:SetText(act and BG.colorize("Enviada. Cada maestro la verá aquí y podrá marcarla como leída.", C.success) or BG.colorize(actWhy(w2), C.warning))
    end)
    L.note:SetText(ok and BG.colorize("Firmando…", C.text3) or BG.colorize(actWhy(w), C.warning))
  end)
  f.letters = UI.List(L, 64, letterCard, fillLetter)
  f.letters:SetPoint("BOTTOMRIGHT", -16, 14)
  L.empty = UI.Text(L, 12, C.text3, { wrap = true })
  L.empty:SetPoint("RIGHT", -16, 0)

  -- Doors and hidden (right).
  local R = UI.Plate(acts, { corners = 18, rail = 0.24 })
  R:SetPoint("TOPLEFT", L, "TOPRIGHT", 18, 0)
  R:SetPoint("BOTTOMRIGHT")
  acts.side = R
  R.doorsHead, R.doors = section(R, "Puertas abiertas")
  R.open = UI.Button(R, "Abrir", { primary = true, height = 26, width = 70 })
  R.open:SetPoint("TOPRIGHT", R.doors, "BOTTOMRIGHT", 0, -8)
  R.doorFor = UI.Picker(R, { width = 84 })
  R.doorFor:SetPoint("RIGHT", R.open, "LEFT", -6, 0)
  R.doorFor:SetOptions(DOORS_FOR)
  R.doorFor:SetValue(2, true)
  R.doorTo = UI.Picker(R, { width = 120 })
  R.doorTo:SetPoint("TOPLEFT", R.doors, "BOTTOMLEFT", 0, -8)
  R.doorTo:SetPoint("RIGHT", R.doorFor, "LEFT", -6, 0)
  R.open:SetScript("OnClick", function()
    local ok, w = Acts.OpenDoors(R.doorTo:GetValue(), R.doorFor:GetValue())
    if not ok then
      BG:Notify("No se pudo", actWhy(w), { kind = "warning" })
    end
  end)
  R.close = UI.Button(R, "Cerrar las puertas", { height = 24, width = 150 })
  R.close:SetPoint("TOPLEFT", R.doorTo, "BOTTOMLEFT", 0, -6)
  R.close:SetScript("OnClick", function()
    local ok, w = Acts.CloseDoors()
    if not ok then
      BG:Notify("No se pudo", actWhy(w), { kind = "warning" })
    end
  end)
  R.hideHead, R.hideText = section(R, "Ocultos en la alianza", R.doorTo, 14)
  R.hideBtn = UI.Button(R, "Ocultar", { height = 26, width = 80 })
  R.hideBtn:SetPoint("TOPRIGHT", R.hideText, "BOTTOMRIGHT", 0, -8)
  R.hideFor = UI.Picker(R, { width = 84 })
  R.hideFor:SetPoint("RIGHT", R.hideBtn, "LEFT", -6, 0)
  R.hideFor:SetOptions(HIDE_FOR)
  R.hideFor:SetValue(24, true)
  R.hideName = UI.EditBox(R, { width = 120, maxLetters = 40, placeholder = "Jugador o hermandad" })
  R.hideName:SetPoint("TOPLEFT", R.hideText, "BOTTOMLEFT", 0, -8)
  R.hideName:SetPoint("RIGHT", R.hideFor, "LEFT", -6, 0)
  R.hideBtn:SetScript("OnClick", function()
    local typed = (R.hideName:GetText() or ""):gsub("^%s+", ""):gsub("%s+$", "")
    local target = typed
    for _, g in ipairs(Alliance.Doc() and Alliance.Doc().guilds or {}) do
      if g.n:lower() == typed:lower() then
        target = g.k -- (a whole guild, by its name)
      end
    end
    local ok, w = Acts.Hide(target, R.hideFor:GetValue(), nil, function(act, w2)
      if act then
        R.hideName:SetText("")
      else
        BG:Notify("No se pudo", actWhy(w2), { kind = "warning" })
      end
    end)
    if not ok then
      BG:Notify("No se pudo", actWhy(w), { kind = "warning" })
    end
  end)
  f.hides = UI.List(R, 48, hideCard, fillHide)
  f.hides:SetPoint("BOTTOMRIGHT", -16, 14)
end

local function refreshActs(f)
  local Acts = BG.AllianceActs
  local me = Names.Me() or ""
  local lead = Acts.MayLead()
  local L, R = f.acts.letters, f.acts.side
  for _, w in ipairs({ L.subject, L.body, L.to, L.send, L.note }) do
    w:SetShown(lead)
  end
  local letters = Acts.Letters()
  local anchor = lead and L.note or L.head
  f.letters:ClearAllPoints()
  f.letters:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, lead and -6 or -10)
  f.letters:SetPoint("BOTTOMRIGHT", -16, 14)
  f.letters:SetItems(letters)
  L.empty:ClearAllPoints()
  L.empty:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -12)
  L.empty:SetPoint("RIGHT", -16, 0)
  local reads = Store.IsMaster(me) or Alliance.Cargo(me) == "cap" or lead
  L.empty:SetText(reads and "Aún no hay cartas. El líder de la alianza escribe aquí a los maestros (y, si quiere, a los capitanes)."
    or "Las cartas del líder de la alianza son para los maestros y los capitanes de cada hermandad.")
  L.empty:SetShown(#letters == 0)

  local doors = Acts.Doors()
  R.doors:SetText(doors and string.format("La alianza manda ahora a los nuevos a «%s», hasta las %s.", doors.name, UI.FormatTime(doors["until"]))
    or "Cerradas: cada hermandad recluta por su cuenta. El líder puede abrirlas unas horas para mandar a los nuevos a una hermandad.")
  local guilds = {}
  for _, g in ipairs(Alliance.Doc() and Alliance.Doc().guilds or {}) do
    guilds[#guilds + 1] = { value = g.k, label = g.n }
  end
  R.doorTo:SetOptions(guilds)
  if not R.doorTo:GetValue() and guilds[1] then
    R.doorTo:SetValue(guilds[1].value, true)
  end
  for _, w in ipairs({ R.doorTo, R.doorFor, R.open }) do
    w:SetShown(lead)
  end
  R.close:SetShown(lead and doors ~= nil)
  R.hideHead:ClearAllPoints()
  R.hideHead:SetPoint("TOPLEFT", lead and (doors and R.close or R.doorTo) or R.doors, "BOTTOMLEFT", 0, -14)
  R.hideHead:SetPoint("RIGHT", -16, 0)
  local org = Store.IsOrganiser(me)
  local hidden = org and Acts.Hidden() or {}
  R.hideText:SetText(org and (#hidden == 0 and "Nadie. El líder puede ocultar a un jugador o a una hermandad en los chats comunes durante un tiempo." or "Sus mensajes no salen en los chats comunes de la alianza.")
    or "El líder puede ocultar a alguien en los chats comunes; la lista la ven los organizadores.")
  for _, w in ipairs({ R.hideName, R.hideFor, R.hideBtn }) do
    w:SetShown(lead)
  end
  f.hides:ClearAllPoints()
  f.hides:SetPoint("TOPLEFT", lead and R.hideName or R.hideText, "BOTTOMLEFT", 0, -8)
  f.hides:SetPoint("BOTTOMRIGHT", -16, 14)
  f.hides:SetItems(hidden)
end

-- View ----------------------------------------------------------------------------------------------------
BG:RegisterView("alliance", {
  Build = function(f, def)
    f.hero = UI.Hero(f, 118)
    f.hero:SetPoint("TOPLEFT")
    f.hero:SetPoint("TOPRIGHT")

    -- Without an alliance ------------------------------------------------------------------------------
    local intro = UI.Plate(f, { corners = 18, rail = 0.24 })
    intro:SetPoint("TOPLEFT", f.hero, "BOTTOMLEFT", PAD, -16)
    intro:SetPoint("BOTTOM", 0, 18)
    f.intro = intro
    intro.head = UI.Heading(intro, "Qué es una alianza")
    intro.head:SetPoint("TOPLEFT", 16, -8)
    intro.head:SetPoint("TOPRIGHT", -16, -8)
    intro.text = UI.Text(intro, 13, C.text, { wrap = true })
    intro.text:SetPoint("TOPLEFT", intro.head, "BOTTOMLEFT", 0, -10)
    intro.text:SetPoint("RIGHT", -18, 0)
    intro.text:SetSpacing(5)
    intro.text:SetText(table.concat({
      "Varias hermandades amigas se unen. Cada una sigue siendo la misma, con su maestro y sus normas.",
      "· Un chat común: una pestaña para toda la alianza y otra para cada hermandad hermana.",
      "· Los oficiales de todas tienen su canal, y los maestros el suyo.",
      "· Las salas de Sanadores, Tanques, Daño, Comercio y Ayuda se comparten.",
      "· Veis cuánta gente hay y quién está conectado en cada hermandad.",
      "· Los maestros eligen un líder, que puede llamar a las armas a toda la alianza.",
      "La crean y la aceptan los maestros: ninguna hermandad entra sin que su maestro diga que sí.",
    }, "\n"))
    intro.nameLabel = UI.Text(intro, 11, C.text3)
    intro.nameLabel:SetPoint("BOTTOMLEFT", 16, 52)
    intro.nameLabel:SetText("Nombre de la alianza")
    intro.name = UI.EditBox(intro, { width = 300, maxLetters = 40, placeholder = "Por ejemplo: Alianza del León" })
    intro.name:SetPoint("TOPLEFT", intro.nameLabel, "BOTTOMLEFT", 0, -4)
    intro.create = UI.Button(intro, "Crear la alianza", { primary = true, height = 26, width = 150 })
    intro.create:SetPoint("LEFT", intro.name, "RIGHT", 10, 0)
    intro.create:SetScript("OnClick", function()
      local ok, w = Alliance.Create(intro.name:GetText(), function(doc, w2)
        if doc then
          BG.Sound("LEVELUP")
          BG:Notify("Alianza creada", "«" .. doc.name .. "» ya existe. Ahora invita a otra hermandad.", { kind = "success", view = "alliance" })
        else
          intro.error:SetText(why(w2))
        end
      end)
      intro.error:SetText(ok and BG.colorize("Creando y firmando…", C.text3) or why(w))
    end)
    intro.who = UI.Text(intro, 12, C.goldTitle, { wrap = true })
    intro.who:SetPoint("TOPLEFT", intro.text, "BOTTOMLEFT", 0, -14)
    intro.who:SetPoint("RIGHT", -18, 0)
    intro.error = UI.Text(intro, 12, C.danger, { wrap = true })
    intro.error:SetPoint("TOPLEFT", intro.who, "BOTTOMLEFT", 0, -8)
    intro.error:SetPoint("RIGHT", -18, 0)

    local inbox = UI.Plate(f, { corners = 18, rail = 0.24 })
    inbox:SetPoint("TOPLEFT", intro, "TOPRIGHT", 18, 0)
    inbox:SetPoint("BOTTOMRIGHT", -PAD, 18)
    f.inbox = inbox
    inbox.head = UI.Heading(inbox, "Invitaciones recibidas")
    inbox.head:SetPoint("TOPLEFT", 16, -8)
    inbox.head:SetPoint("TOPRIGHT", -16, -8)
    f.invites = UI.List(inbox, 68, inviteCard, fillInviteCard)
    f.invites:SetPoint("TOPLEFT", inbox.head, "BOTTOMLEFT", 0, -10)
    f.invites:SetPoint("RIGHT", -16, 0)
    f.invites:SetHeight(300)
    inbox.empty = UI.Text(inbox, 12, C.text3, { wrap = true })
    inbox.empty:SetPoint("TOPLEFT", inbox.head, "BOTTOMLEFT", 0, -12)
    inbox.empty:SetPoint("RIGHT", -16, 0)
    inbox.empty:SetText("Ninguna. Cuando otra hermandad os invite, aparecerá aquí y vuestro maestro decidirá.")

    -- With an alliance -----------------------------------------------------------------------------------
    f.plates = {}
    for i = 1, 4 do
      local p = UI.StatPlate(f)
      p:SetHeight(80)
      f.plates[i] = p
    end
    local list = UI.Plate(f, { corners = 18, rail = 0.24 })
    list:SetPoint("TOPLEFT", f.plates[1], "BOTTOMLEFT", 0, -14)
    list:SetPoint("BOTTOM", 0, 18)
    f.list = list
    list.head = UI.Heading(list, "Hermandades de la alianza")
    list.head:SetPoint("TOPLEFT", 16, -8)
    list.head:SetPoint("TOPRIGHT", -16, -8)
    f.guilds = UI.List(list, 62, guildCard, function(c, g)
      c:SetHeight(56)
      fillGuildCard(c, g)
    end)
    f.guilds:SetPoint("TOPLEFT", list.head, "BOTTOMLEFT", 0, -10)
    f.guilds:SetPoint("BOTTOMRIGHT", -16, 14)

    local side = UI.Plate(f, { corners = 18, rail = 0.24 })
    side:SetPoint("TOPLEFT", list, "TOPRIGHT", 18, 0)
    side:SetPoint("BOTTOMRIGHT", -PAD, 18)
    f.side = side

    -- «Gestión»: the cargos of our guild and inviting other guilds (the master names and invites; everyone sees who).
    local manage = CreateFrame("Frame", nil, f)
    manage:SetPoint("TOPLEFT", f.hero, "BOTTOMLEFT", PAD, -16)
    manage:SetPoint("BOTTOMRIGHT", -PAD, 18)
    f.manage = manage
    local mg = UI.Plate(manage, { corners = 18, rail = 0.24 })
    mg:SetPoint("TOPLEFT")
    mg:SetPoint("BOTTOM")
    manage.cargo = mg
    local mi = UI.Plate(manage, { corners = 18, rail = 0.24 })
    mi:SetPoint("TOPLEFT", mg, "TOPRIGHT", 18, 0)
    mi:SetPoint("BOTTOMRIGHT")
    manage.invite = mi

    -- Leadership: who leads, the votes; the leader's guild calls to arms and gives a new key.
    side.leadHead, side.lead = section(side, "Liderazgo")
    side.arms = UI.Button(side, "¡A las armas!", { primary = true, height = 24, width = 120 })
    side.arms:SetPoint("TOPLEFT", side.lead, "BOTTOMLEFT", 0, -8)
    side.arms:SetScript("OnClick", function()
      local ok, w = Alliance.Call("ARMS", "", function(done, w2)
        if not done then
          BG:Notify("No se pudo", why(w2), { kind = "warning" })
        end
      end)
      if not ok then
        BG:Notify("No se pudo", why(w), { kind = "warning" })
      end
    end)
    side.rekey = UI.Button(side, "Nueva clave", { height = 24, width = 110 })
    side.rekey:SetPoint("LEFT", side.arms, "RIGHT", 6, 0)
    side.rekey:SetScript("OnClick", function()
      BG.UI.Dialog({
        title = "Nueva clave para la alianza",
        items = { "Todos los mensajes de la alianza llevan una marca hecha con su clave. Cámbiala si crees que la conoce alguien de fuera.",
          { note = "Las hermandades la reciben solas; durante un minuto puede perderse algún mensaje." } },
        primary = { label = "Cambiar la clave", fn = function()
          local ok, w = Alliance.NewKey(function(doc, w2)
            BG:Notify(doc and "Clave nueva" or "No se pudo", doc and "La alianza ya usa la clave nueva." or why(w2), { kind = doc and "success" or "warning" })
          end)
          if not ok then
            BG:Notify("No se pudo", why(w), { kind = "warning" })
          end
        end },
        secondary = { label = "Cancelar" },
      })
    end)

    -- Cargos of our guild (the master names them).
    side.cargoHead, side.cargos = section(side, "Cargos de tu hermandad", side.arms, 12)
    mg.head, mg.text = section(mg, "Cargos de tu hermandad")
    mg.list = UI.Text(mg, 12, C.text, { wrap = true })
    mg.list:SetPoint("TOPLEFT", mg.text, "BOTTOMLEFT", 0, -8)
    mg.list:SetPoint("RIGHT", -16, 0)
    mg.list:SetSpacing(3)
    side.cargoSet = UI.Button(mg, "Nombrar", { height = 26, width = 84 })
    side.cargoSet:SetPoint("TOPRIGHT", mg.list, "BOTTOMRIGHT", 0, -10)
    side.cargoPick = UI.Picker(mg, { width = 110 })
    side.cargoPick:SetPoint("RIGHT", side.cargoSet, "LEFT", -6, 0)
    side.cargoPick:SetOptions({ { value = "cap", label = "Capitán" }, { value = "msg", label = "Mensajero" }, { value = "none", label = "Sin cargo" } })
    side.cargoPick:SetValue("cap", true)
    side.cargoName = UI.EditBox(mg, { maxLetters = 40, placeholder = "Nombre y apellido" })
    side.cargoName:SetPoint("TOPLEFT", mg.list, "BOTTOMLEFT", 0, -10)
    side.cargoName:SetPoint("RIGHT", side.cargoPick, "LEFT", -6, 0)
    side.cargoSet:SetScript("OnClick", function()
      local cargo = side.cargoPick:GetValue()
      local who = side.cargoName:GetText()
      local ok, w = Alliance.SetCargo(who, cargo ~= "none" and cargo or nil, function(doc, w2)
        if doc then
          side.cargoName:SetText("")
        end
        side.cargoNote:SetText(doc and BG.colorize("Hecho: ya lo saben las demás hermandades.", C.success) or BG.colorize(why(w2), C.warning))
      end)
      side.cargoNote:SetText(ok and BG.colorize("Firmando…", C.text3) or BG.colorize(why(w), C.warning))
    end)
    side.cargoNote = UI.Text(mg, 11, C.text3, { wrap = true })
    side.cargoNote:SetPoint("TOPLEFT", side.cargoName, "BOTTOMLEFT", 0, -4)
    side.cargoNote:SetPoint("RIGHT", -16, 0)

    -- Inviting another guild (the master).
    side.head, side.text = section(mi, "Invitar a otra hermandad")
    side.send = UI.Button(mi, "Invitar", { primary = true, height = 26, width = 84 })
    side.send:SetPoint("TOPRIGHT", side.text, "BOTTOMRIGHT", 0, -8)
    side.name = UI.EditBox(mi, { maxLetters = 40, placeholder = "Nombre y apellido" })
    side.name:SetPoint("TOPLEFT", side.text, "BOTTOMLEFT", 0, -8)
    side.name:SetPoint("RIGHT", side.send, "LEFT", -8, 0)
    side.send:SetScript("OnClick", function()
      local ok, w = Alliance.Invite(side.name:GetText(), function(tok, w2)
        if tok then
          side.name:SetText("")
          side.note:SetText(BG.colorize("Enviada. Te avisamos cuando conteste.", C.success))
        else
          side.note:SetText(BG.colorize(why(w2), C.warning))
        end
      end)
      side.note:SetText(ok and BG.colorize("Firmando y enviando…", C.text3) or BG.colorize(why(w), C.warning))
    end)
    side.note = UI.Text(mi, 11, C.text3, { wrap = true })
    side.note:SetPoint("TOPLEFT", side.name, "BOTTOMLEFT", 0, -4)
    side.note:SetPoint("RIGHT", -16, 0)
    side.pending = UI.Text(mi, 11, C.text2, { wrap = true })
    side.pending:SetPoint("TOPLEFT", side.note, "BOTTOMLEFT", 0, -6)
    side.pending:SetPoint("RIGHT", -16, 0)
    side.pending:SetMaxLines(4)

    -- Bottom: hiding (organisers) and leaving (the master).
    side.hide = UI.Button(side, "Ocultarme", { height = 24 })
    side.hide:SetPoint("BOTTOMLEFT", 16, 16)
    side.hide:SetPoint("RIGHT", side, "BOTTOM", -4, 0)
    side.hide:SetScript("OnClick", function()
      local on = not Alliance.IsHidden()
      local ok, w = Alliance.SetHidden(on)
      if ok then
        BG:Notify(on and "Oculto" or "Visible", on and "Las otras hermandades no te verán conectado. Los mensajes de «Maestros» de otras hermandades no te llegarán mientras sigas oculto."
          or "Las otras hermandades vuelven a verte conectado.", { kind = "info" })
      else
        BG:Notify("No se pudo", why(w), { kind = "warning" })
      end
    end)
    side.leave = UI.Button(side, "Salir de la alianza", { height = 24 })
    side.leave:SetPoint("BOTTOMRIGHT", -16, 16)
    side.leave:SetPoint("LEFT", side, "BOTTOM", 4, 0)
    side.leave:SetScript("OnClick", function()
      local doc = Alliance.Doc()
      BG.UI.Dialog({
        title = "Salir de «" .. (doc and doc.name or "") .. "»",
        items = { "Tu hermandad dejará de ver el chat de la alianza y sus salas compartidas. Las demás hermandades siguen juntas.",
          { note = "Para volver, otra hermandad tendrá que invitaros de nuevo." } },
        primary = { label = "Salir", fn = function()
          local ok, w = Alliance.Leave(function(done, w2)
            BG:Notify(done and "Habéis salido de la alianza" or "No se pudo", done and "Las demás hermandades ya lo saben." or why(w2), { kind = done and "info" or "warning" })
          end)
          if not ok then
            BG:Notify("No se pudo", why(w), { kind = "warning" })
          end
        end },
        secondary = { label = "Cancelar" },
      })
    end)

    buildActs(f)
    f.tab = "guilds"
    f.tabs = UI.Segmented(f.hero, TABS, { height = 24, onChange = function(v)
      f.tab = v
      BG:RefreshView("alliance")
    end })
    f.tabs:SetPoint("BOTTOMRIGHT", -PAD, 12)
    f.hero.sub:SetPoint("RIGHT", f.tabs, "LEFT", -16, 0) -- (the text never runs under the tabs)
    f.hero.title:SetPoint("RIGHT", f.tabs, "LEFT", -16, 0)

    f:SetScript("OnSizeChanged", function(self, w)
      local inner = w - PAD * 2
      self.acts.letters:SetWidth(math.floor((inner - 18) * 0.56))
      self.manage.cargo:SetWidth(math.floor((inner - 18) * 0.5))
      local introW = math.floor((inner - 18) * 0.56)
      self.intro:SetWidth(introW)
      self.intro.name:SetWidth(math.max(120, math.min(300, introW - 32 - 160))) -- (the box and its button always fit)
      self.list:SetWidth(math.floor((inner - 18) * 0.58))
      local gap = 12
      local pw = (inner - gap * 3) / 4
      for i, p in ipairs(self.plates) do
        p:SetWidth(pw)
        p:ClearAllPoints()
        p:SetPoint("TOPLEFT", self.hero, "BOTTOMLEFT", PAD + (i - 1) * (pw + gap), -16)
      end
    end)
  end,

  Refresh = function(f)
    local doc = Alliance.Doc()
    local info = BG.Guild.info
    local me = Names.Me() or ""
    local master = Store.IsMaster(me)
    local faction = info and info.faction or "ALLIANCE"
    f.hero:SetArt(BG.art[faction] or BG.art.ALLIANCE, 0.5)
    f.hero:SetIcon(banner(faction))

    local without = doc == nil
    local acts = not without and f.tab == "acts"
    local manage = not without and f.tab == "manage"
    local guildsTab = not without and not acts and not manage
    f.intro:SetShown(without)
    f.inbox:SetShown(without)
    for _, p in ipairs(f.plates) do
      p:SetShown(guildsTab)
    end
    f.list:SetShown(guildsTab)
    f.side:SetShown(guildsTab)
    f.acts:SetShown(acts)
    f.manage:SetShown(manage)
    f.tabs:SetShown(not without)
    f.tabs:SetValue(f.tab, true)
    if not without and BG.AllianceActs then
      local unread = BG.AllianceActs.Unread()
      f.tabs.buttons[2].text:SetText(unread > 0 and string.format("Cartas y avisos (%d)", unread) or "Cartas y avisos")
    end

    if without then
      f.hero.title:SetText("Hermandades hermanas")
      f.hero.sub:SetText("Une " .. (info and info.name or "tu hermandad") .. " con otras hermandades: chat común, salas compartidas y quién está conectado en todas.")
      f.intro.name:SetShown(master)
      f.intro.nameLabel:SetShown(master)
      f.intro.create:SetShown(master)
      local m = masterName()
      f.intro.who:SetText(master and "Como maestro, tú decides: crea la alianza y luego invita a otras hermandades, o acepta una invitación de la derecha."
        or ("Solo el maestro" .. (m and (", " .. m .. ",") or "") .. " puede crear una alianza o aceptar una invitación. Si conoces una hermandad amiga, cuéntaselo."))
      local invites = Alliance.Invitations()
      f.invites:SetItems(invites)
      f.inbox.empty:SetShown(#invites == 0)
      return
    end
    f.intro.error:SetText("")

    local census = Alliance.Census()
    local lead = Alliance.LeaderGuild()
    f.hero.title:SetText("Alianza «" .. doc.name .. "»")
    f.hero.sub:SetText(string.format("%d hermandades y %d personas, %d conectadas ahora%s.%s", census.guilds, census.people, census.online,
      census.unknown > 0 and (" (sin contar " .. census.unknown .. (census.unknown == 1 and " hermandad" or " hermandades") .. " aún sin contacto)") or "",
      lead and BG.TF(" Líder: %s, de %s.", lead.m or "?", lead.n) or ""))
    f.plates[1]:Set(tostring(census.guilds), "Hermandades", "en la alianza")
    f.plates[2]:Set(tostring(census.people), "Personas", census.members .. " personajes")
    f.plates[3]:Set(tostring(census.online), "Conectados", "ahora mismo")
    f.plates[4]:Set(tostring(census.addon), "Con BlazonGuild", "conectados")
    if acts then
      refreshActs(f)
      return
    end

    local guilds = {}
    for _, g in ipairs(doc.guilds) do
      guilds[#guilds + 1] = g
    end
    f.guilds:SetItems(guilds)

    local side = f.side
    -- Leadership
    side.lead:SetText(leadershipText())
    local leaderSide = Alliance.AmLeaderGuild() and Alliance.CanSign() and Store.IsOrganiser(me)
    side.arms:SetShown(leaderSide)
    side.rekey:SetShown(leaderSide)
    side.cargoHead:ClearAllPoints()
    side.cargoHead:SetPoint("TOPLEFT", leaderSide and side.arms or side.lead, "BOTTOMLEFT", 0, -12)
    side.cargoHead:SetPoint("RIGHT", -16, 0)
    -- Cargos (the list on the side; naming them in «Gestión»)
    side.cargos:SetText(cargosText(info and info.key))
    f.manage.cargo.text:SetText(master and "Los capitanes leen y escriben en «Oficiales de la alianza»; los mensajeros llevan los mensajes a las otras hermandades. Escribe su nombre y elige el cargo."
      or "El maestro nombra a los capitanes (leen y escriben en «Oficiales de la alianza») y a los mensajeros (llevan los mensajes a las otras hermandades).")
    local ck = info and info.key
    f.manage.cargo.list:SetText((#Alliance.Cargos(ck, "cap") + #Alliance.Cargos(ck, "msg")) == 0 and "Aún no hay ningún cargo." or cargosText(ck))
    side.cargoName:SetShown(master)
    side.cargoPick:SetShown(master)
    side.cargoSet:SetShown(master)
    -- Inviting
    side.name:SetShown(master)
    side.send:SetShown(master)
    if master then
      side.text:SetText("Escribe el nombre de alguien de esa hermandad que tenga BlazonGuild y esté conectado. Su maestro decidirá si entran.")
    else
      local m = masterName()
      side.text:SetText("El maestro" .. (m and (", " .. m .. ",") or "") .. " invita a otras hermandades y decide si seguís en la alianza.")
      side.note:SetText("")
    end
    local lines = {}
    local open = Alliance.OpenInvites()
    for i = #open, 1, -1 do
      local v = open[i]
      lines[#lines + 1] = "Invitación a " .. (v.to or "?") .. ", " .. (agoText(v.at) or "") .. ": esperando a su maestro."
    end
    side.pending:SetText(#lines > 0 and table.concat(lines, "\n") or "")
    -- Bottom
    side.hide:SetShown(Alliance.MayHide() or Alliance.IsHidden())
    side.hide.text:SetText(Alliance.IsHidden() and "Mostrarme conectado" or "Ocultarme")
    side.leave:SetShown(master)
  end,
})

BG:On("BG_ALLIANCE_CHANGED", function()
  BG:RefreshView("alliance")
end)
BG:On("BG_PEERS_CHANGED", function()
  BG:RefreshView("alliance")
end)
BG:On("BG_SIGN_READY", function()
  BG:RefreshView("alliance")
end)
