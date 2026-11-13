-- In-game self-test (entrega 13; the idea of Olympus' SelfTest.lua, MIT; our own, for what this addon needs). /bg
-- autoprueba (or Administración, «Autoprueba») checks in the real game what the offline tests cannot: that the events
-- and functions BlazonGuild counts on exist in this client, and what they answer here (the minimap's radius, the
-- facing, the world's coordinates, a unit's health, an item's level...), plus the guild messages' round trip. Each line
-- says yes, no, or "cannot tell here" (some need the open world, a group or a target). «Copiar» gives the whole report
-- as text, to paste anywhere. Nothing is sent but the usual message test.
local _, BG = ...
local UI, C = BG.UI, BG.color
local Self = {}
BG.SelfTest = Self

local function secret(v)
  return issecretvalue ~= nil and issecretvalue(v)
end

local function add(out, group, label, ok, detail)
  out[#out + 1] = { group = group, label = label, ok = ok, detail = detail or "" }
end

-- How the game writes names here (the audit of 2026-11-13: on Forever UnitName gives the first name alone, and the
-- game's lines may say "First-Surname"; BlazonGuild reads both, and this says which one this client uses). The last
-- line of a duel or a /roll the game printed, word for word.
BG:On("CHAT_MSG_SYSTEM", function(msg)
  if type(msg) ~= "string" or secret(msg) or not BG.Arena then
    return
  end
  if BG.Arena.DuelResult(msg) or BG.Arena.Scan(BG.Arena.Format("RANDOM_ROLL_RESULT"), msg) then
    Self.lastLine = msg
  end
end)

local function parts(unit)
  if not UnitName then
    return "?"
  end
  local ok, a, b = pcall(UnitName, unit)
  if not ok or secret(a) or secret(b) then
    return "oculto"
  end
  return "«" .. tostring(a) .. "»" .. (b and b ~= "" and (" + «" .. tostring(b) .. "»") or "")
end

-- The checks: { group, label, ok = true | false | nil (cannot tell here), detail }.
function Self.Checks()
  local out = {}
  local G = "El juego"
  local build, iface
  if GetBuildInfo then
    local _, b, _, i = GetBuildInfo()
    build, iface = b, i
  end
  add(out, G, "Versiones", true, string.format("BlazonGuild %s; juego %s, interfaz %s", tostring(BG.version), tostring(build or "?"), tostring(iface or "?")))
  add(out, G, "Privacidad aceptada", BG.Consent.Accepted(), BG.Consent.Accepted() and "sí" or "sin aceptar: el addon no envía nada")
  local info = BG.Guild.info
  add(out, G, "Hermandad", info ~= nil, info and string.format("%s, %d miembros", info.name, #(BG.Guild.members or {})) or "sin hermandad")
  add(out, G, "Interfaz de mando", true, BG.Gamepad.On() and "activada: BlazonGuild no toca la interfaz del juego" or "no (ratón y teclado)")

  G = "Eventos"
  local unknown = BG.unknownEvents or {}
  for _, e in ipairs({ "ENCOUNTER_END", "PARTY_KILL", "INSPECT_READY", "PLAYER_EQUIPMENT_CHANGED", "NAME_PLATE_UNIT_ADDED", "CHAT_MSG_CHANNEL",
    "DUEL_REQUESTED", "INPUT_DEVICE_INTERFACE_TRANSITION" }) do
    add(out, G, e, not unknown[e], unknown[e] and "este juego no lo tiene" or "existe")
  end

  G = "Funciones"
  local fns = {
    { "C_Minimap.GetViewRadius", C_Minimap and C_Minimap.GetViewRadius },
    { "GetPlayerFacing", GetPlayerFacing },
    { "C_Map.GetWorldPosFromMapPos", C_Map and C_Map.GetWorldPosFromMapPos },
    { "NotifyInspect", NotifyInspect },
    { "C_DeathRecap", C_DeathRecap },
    { "JoinTemporaryChannel", JoinTemporaryChannel },
    { "GetDetailedItemLevelInfo", (C_Item and C_Item.GetDetailedItemLevelInfo) or GetDetailedItemLevelInfo },
    { "UnitHealth", UnitHealth },
    { "C_ChatInfo.SendAddonMessage", C_ChatInfo and C_ChatInfo.SendAddonMessage },
  }
  for _, f in ipairs(fns) do
    add(out, G, f[1], f[2] ~= nil, f[2] ~= nil and "existe" or "no existe")
  end

  G = "Lo que responde aquí"
  local inside = IsInInstance and IsInInstance()
  if C_Minimap and C_Minimap.GetViewRadius then
    local ok, r = pcall(C_Minimap.GetViewRadius)
    add(out, G, "Radio del minimapa", ok and type(r) == "number" and r > 0, ok and type(r) == "number" and string.format("%d metros", math.floor(r + 0.5)) or "no da un número")
  else
    add(out, G, "Radio del minimapa", true, "por los pasos de zoom del juego (no hay función)")
  end
  local okF, facing = pcall(GetPlayerFacing or function() return nil end)
  add(out, G, "Hacia dónde miras", okF and type(facing) == "number" and not secret(facing) or (inside and nil or false),
    okF and type(facing) == "number" and not secret(facing) and string.format("%.2f radianes", facing) or (inside and "dentro de una instancia el juego no lo da" or "no lo da"))
  local map, x, y = BG.Layers.MyPosition()
  local east = map and BG.Positions.Offset(map, x, y)
  add(out, G, "Coordenadas del mundo", map and east ~= nil or (not map and nil or false), map and (east ~= nil and "funcionan (puntos del minimapa y flecha)" or "no responden")
    or "sin posición aquí (instancia, barco o vuelo)")
  local okH, hp = pcall(UnitHealth or function() return nil end, "player")
  add(out, G, "Vida (tú)", okH and type(hp) == "number" and not secret(hp), okH and type(hp) == "number" and not secret(hp) and tostring(hp) or "oculta o sin número")
  local okT, exists = pcall(UnitExists or function() return false end, "target")
  if okT and exists and not secret(exists) then
    local okTH, thp = pcall(UnitHealth, "target")
    local okTM, tmax = pcall(UnitHealthMax, "target")
    local good = okTH and okTM and type(thp) == "number" and type(tmax) == "number" and not secret(thp) and tmax > 0
    add(out, G, "Vida de tu objetivo", good, good and string.format("%d de %d (%s)", thp, tmax, tmax == 100 and "parece un porcentaje" or "cifra real") or "oculta")
  else
    add(out, G, "Vida de tu objetivo", nil, "elige un objetivo y vuelve a probar")
  end
  local link
  for _, slot in ipairs({ 1, 5, 7, 16 }) do
    local okL, l = pcall(GetInventoryItemLink or function() return nil end, "player", slot)
    if okL and type(l) == "string" then
      link = l
      break
    end
  end
  local il = link and BG.Armory and BG.Armory.ItemLevel and BG.Armory.ItemLevel(link)
  add(out, G, "Tu equipo y su nivel", link ~= nil and (il ~= nil or nil), link and (il and string.format("se lee (nivel de objeto %d)", il) or "se lee, sin nivel de objeto") or "no se lee")
  local tex = UIParent:CreateTexture(nil, "BACKGROUND")
  add(out, G, "Girar la flecha", tex.SetRotation ~= nil, tex.SetRotation and "sí" or "este juego no gira texturas")
  tex:Hide()
  local name, kind, _, _, _, _, _, mapId = GetInstanceInfo and GetInstanceInfo()
  add(out, G, "Dónde estás", true, string.format("%s (%s, mapa %s)", tostring(name or "?"), tostring(kind or "?"), tostring(mapId or "?")))
  local H = BG.AllianceHall
  if BG.Alliance and BG.Alliance.Doc() and H then
    add(out, G, "Canal de la alianza", H.On(), H.On() and string.format("dentro; %d enviadas, %d oídas", H.stats.sent, H.stats.heard) or "fuera (va por los mensajeros)")
  else
    add(out, G, "Canal de la alianza", nil, "sin alianza")
  end
  local me = BG.Names.Unit("player")
  add(out, G, "Nombres del juego", me ~= nil, string.format("UnitName da %s; nombre completo «%s»", parts("player"), tostring(me))
    .. (UnitIsPlayer and UnitExists and UnitExists("target") and UnitIsPlayer("target") and string.format("; tu objetivo: %s", parts("target")) or ""))
  add(out, G, "Nombres en las líneas del juego", Self.lastLine and true or nil, Self.lastLine and ("«" .. Self.lastLine .. "»") or "haz /roll y vuelve a probar")
  local errs = 0
  for _, e in ipairs(BG.db.errors or {}) do
    if e.version == BG.version then
      errs = errs + 1
    end
  end
  add(out, G, "Errores de esta versión", errs == 0, errs == 0 and "ninguno" or string.format("%d (Administración, «Errores internos»)", errs))
  local ping = BG.Diagnostics and BG.Diagnostics.lastPing
  if ping and ping.done then
    add(out, G, "Mensajes por la hermandad", ping.echo ~= nil, ping.echo and string.format("vuelven en %d ms; %d respondieron", ping.ms or 0, #ping.answers) or "no volvieron")
  else
    add(out, G, "Mensajes por la hermandad", nil, ping and "probando… (12 segundos)" or "pulsa «Probar otra vez» en unos segundos")
  end
  return out
end

-- The report as plain text (to copy).
function Self.Text(checks)
  local lines = { "BlazonGuild — autoprueba " .. date("%Y-%m-%d %H:%M") }
  local group
  for _, c in ipairs(checks) do
    if c.group ~= group then
      group = c.group
      lines[#lines + 1] = "[" .. BG.T(group) .. "]"
    end
    lines[#lines + 1] = string.format("%s %s: %s", c.ok == true and BG.T("Sí") or (c.ok == false and BG.T("No") or "--"), BG.T(c.label), BG.T(c.detail))
  end
  return table.concat(lines, "\n")
end

-- The window ---------------------------------------------------------------------------------------------------------
local frame

local function build()
  local f = UI.Plate(UIParent, { corners = 18, rail = 0.3 })
  f:SetSize(600, 470)
  f:SetPoint("CENTER")
  f:SetFrameStrata("DIALOG")
  f:SetClampedToScreen(true)
  f:SetMovable(true)
  f:EnableMouse(true)
  f:RegisterForDrag("LeftButton")
  f:SetScript("OnDragStart", f.StartMoving)
  f:SetScript("OnDragStop", f.StopMovingOrSizing)
  tinsert(UISpecialFrames, "BlazonGuildSelfTest")
  _G.BlazonGuildSelfTest = f
  f.head = UI.Heading(f, "Autoprueba")
  f.head:SetPoint("TOPLEFT", 16, -8)
  f.close = UI.Button(f, "×", { height = 22, width = 26 })
  f.close:SetPoint("TOPRIGHT", -10, -8)
  f.close:SetScript("OnClick", function()
    f:Hide()
  end)
  f.head:SetPoint("RIGHT", f.close, "LEFT", -10, 0)
  f.body = UI.Text(f, 11, C.text, { wrap = true })
  f.body:SetPoint("TOPLEFT", f.head, "BOTTOMLEFT", 0, -8)
  f.body:SetPoint("RIGHT", -16, 0)
  f.body:SetSpacing(2)
  f.again = UI.Button(f, "Probar otra vez", { primary = true, height = 26, width = 150 })
  f.again:SetPoint("BOTTOMLEFT", 16, 14)
  f.again:SetScript("OnClick", function()
    Self.Open(true)
  end)
  f.copy = UI.Button(f, "Copiar", { height = 26, width = 110 })
  f.copy:SetPoint("LEFT", f.again, "RIGHT", 8, 0)
  f.body:SetPoint("BOTTOM", f.again, "TOP", 0, 10)
  f.body:SetJustifyV("TOP")
  -- (the report as text, selected, for Ctrl+C)
  f.box = CreateFrame("EditBox", nil, f)
  f.box:SetMultiLine(true)
  f.box:SetFont(BG.font.body, 11, "")
  f.box:SetTextColor(C.text[1], C.text[2], C.text[3])
  f.box:SetPoint("TOPLEFT", f.head, "BOTTOMLEFT", 0, -8)
  f.box:SetPoint("BOTTOMRIGHT", -16, 50)
  f.box:SetAutoFocus(false)
  f.box:SetScript("OnEscapePressed", function(self)
    self:ClearFocus()
    self:Hide()
    f.body:Show()
  end)
  f.box:Hide()
  f.copy:SetScript("OnClick", function()
    if f.box:IsShown() then
      f.box:Hide()
      f.body:Show()
      return
    end
    f.box:SetText(Self.Text(f.checks or Self.Checks()))
    f.body:Hide()
    f.box:Show()
    f.box:SetFocus()
    f.box:HighlightText()
  end)
  f.hint = UI.Text(f, 11, C.text3, { wrap = true })
  f.hint:SetPoint("LEFT", f.copy, "RIGHT", 10, 0)
  f.hint:SetPoint("RIGHT", -16, 0)
  f.hint:SetText("«Copiar» y luego Ctrl+C: pégalo donde quieras.")
  f:Hide()
  return f
end

function Self.Show(checks)
  frame = frame or build()
  frame.checks = checks
  local lines, group = {}, nil
  for _, c in ipairs(checks) do
    if c.group ~= group then
      group = c.group
      lines[#lines + 1] = BG.colorize(BG.T(c.group), C.goldTitle)
    end
    -- (each piece in the player's language: the line mixes them with names of the game's functions)
    local mark = c.ok == true and BG.colorize(BG.T("Sí"), C.success) or (c.ok == false and BG.colorize(BG.T("No"), C.danger) or BG.colorize("--", C.text3))
    lines[#lines + 1] = mark .. "  " .. BG.T(c.label) .. ": " .. BG.colorize(BG.T(c.detail), C.text2)
  end
  frame.body:SetText(table.concat(lines, "\n"))
  frame.box:Hide()
  frame.body:Show()
  frame:Show()
  return frame
end

-- Runs it: the message test too (its answer shows in a few seconds, «Probar otra vez»).
function Self.Open(rerun)
  if not rerun and BG.Diagnostics and BG.Consent.Accepted() and IsInGuild() then
    BG.Diagnostics.Ping()
  end
  local checks = Self.Checks()
  local f = Self.Show(checks)
  if not rerun then
    C_Timer.After(13, function()
      if f:IsShown() then
        Self.Show(Self.Checks())
      end
    end)
  end
  return f
end

function Self.Frame()
  return frame
end

BG.commands = BG.commands or {}
BG.commands.autoprueba = function()
  Self.Open()
end
