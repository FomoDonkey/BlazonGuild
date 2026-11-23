-- Diagnostics a player can run in the game and read in chat:
--   /bg estado       connection to the guild: consent, addon users, messenger, queue, traffic
--   /bg prueba       sends a test message over GUILD; reports when it comes back and who answers
--   /bg rendimiento  memory and the time spent handling each message type
--   /bg errores      the last internal errors kept in SavedVariables
-- Idea from Olympus's Diagnostics.lua and Perf.lua (MIT); implementation is our own.
local _, BG = ...
local Diag = {}
BG.Diagnostics = Diag
local Comm, Peers = BG.Comm, BG.Peers

local function line(label, value)
  BG:Print(BG.colorize(label .. ":", BG.color.text3) .. " " .. tostring(value))
end

local function ago(t)
  if not t then
    return "nunca"
  end
  local s = math.floor(GetTime() - t)
  return s < 60 and ("hace " .. s .. " s") or ("hace " .. math.floor(s / 60) .. " min")
end

function Diag.Status()
  local s = Comm.stats
  local active = Peers.Active()
  BG:Print("estado de la conexión con tu hermandad")
  line("Privacidad", BG.Consent.Accepted() and "aceptada, compartes con tu hermandad" or "sin aceptar: no se envía nada (/bg privacidad)")
  line("Con BlazonGuild ahora", #active .. (#active == 1 and " miembro" or " miembros"))
  line("Mensajero de la hermandad", Peers.Messenger() or "nadie todavía")
  line("Mensajes", string.format("%d enviados, %d recibidos, %d de vuelta (eco), %d fallidos", s.sent, s.recv, s.echo, s.fails))
  line("Último eco propio", ago(Comm.lastEcho))
  line("En cola", Comm.QueueSize() .. (Comm.Held() and string.format(" (retenidos %d s: el juego bloquea mensajes aquí)", Comm.Held()) or ""))
  if s.lastFail then
    line("Último fallo", s.lastFail)
  end
  if s.bad + s.unknown + s.future > 0 then
    line("Ignorados", string.format("%d ilegibles, %d de tipo desconocido, %d de versiones futuras", s.bad, s.unknown, s.future))
  end
  local H = BG.AllianceHall
  if H and BG.Alliance and BG.Alliance.Doc() then
    line("Canal de la alianza", (H.On() and "dentro" or "fuera (va todo por los mensajeros)") .. string.format("; %d enviadas, %d oídas", H.stats.sent, H.stats.heard))
  end
  local W, M = BG.Wanted, BG.Marks
  if W then
    local kill = not (BG.unknownEvents and BG.unknownEvents.PARTY_KILL)
    line("«Se busca»", (W.Enabled() and "apuntando" or "apagado") .. "; resumen de muerte del juego: " .. (type(C_DeathRecap) == "table" and "sí" or "no")
      .. "; golpe final: " .. (kill and "sí" or "no"))
    line("Última muerte leída", W.stats.death or "ninguna desde que entraste")
    if W.stats.kill then
      line("Última baja de un jugador", W.stats.kill)
    end
  end
  if M then
    line("Marcas en el chat del juego", M.chatEvents == nil and "aún no" or (M.chatEvents > 0 and (M.chatEvents .. " tipos de chat") or "este cliente no lo permite"))
  end
end

function Diag.Perf()
  local kb
  if UpdateAddOnMemoryUsage and GetAddOnMemoryUsage then
    UpdateAddOnMemoryUsage()
    kb = GetAddOnMemoryUsage(BG.name)
  end
  BG:Print("rendimiento")
  line("Memoria", kb and string.format("%.0f KB", kb) or "el juego no lo indica")
  local handled = Comm.HandlerStats()
  if #handled == 0 then
    line("Mensajes procesados", "ninguno todavía")
  end
  for i = 1, math.min(6, #handled) do
    local h = handled[i]
    line("Tipo " .. h.kind, string.format("%d mensajes, %.1f ms en total", h.calls, h.ms))
  end
end

function Diag.Errors()
  local list = BG.db.errors or {}
  if #list == 0 then
    BG:Print("no hay errores guardados.")
    return
  end
  BG:Print(#list .. " errores guardados (los más recientes primero):")
  for i = 1, math.min(5, #list) do
    local e = list[i]
    line(e.at .. " v" .. tostring(e.version) .. ((e.count or 1) > 1 and (" ×" .. e.count) or ""), e.where .. ": " .. e.error)
  end
end

-- Test message: our own GUILD message coming back proves the channel works; other members' addons
-- answer by addon whisper, which proves whispers between "First Surname" names work too. The result shows
-- in Administración and as an on-screen notice, never only in the chat box.
local ANSWER_GAP = 20
local answeredAt = {}

local function pingChanged()
  BG:Fire("BG_PING_UPDATED")
end

function Diag.Ping()
  if not IsInGuild() then
    BG:Notify("Prueba de mensajes", "Necesitas estar en una hermandad.", { kind = "warning" })
    return
  end
  if not BG.Consent.Accepted() then
    BG:Notify("Prueba de mensajes", "Antes acepta la privacidad: sin eso el addon no envía nada.", { kind = "warning", view = "admin" })
    return
  end
  local probe = { sent = GetTime(), answers = {} }
  local ok, why = Comm.Send("PG", { n = math.random(1, 99999) }, "GUILD", nil, { lane = "alert" })
  if not ok then
    BG:Notify("Prueba de mensajes", "No se pudo enviar (" .. tostring(why) .. ").", { kind = "danger" })
    return
  end
  Diag.lastPing = probe
  pingChanged()
  C_Timer.After(12, function()
    if Diag.lastPing ~= probe then
      return
    end
    probe.done = true
    pingChanged()
    local n = #probe.answers
    if not probe.echo then
      BG:Notify("La prueba no ha vuelto", "Puede que el juego esté bloqueando mensajes aquí (banda, mazmorra o combate). Prueba fuera.", { kind = "danger", view = "admin" })
    elseif n == 0 then
      BG:Notify("Prueba superada", string.format("Tu mensaje volvió en %d ms. Ningún otro miembro conectado tiene BlazonGuild ahora.", probe.ms), { kind = "success", view = "admin" })
    else
      BG:Notify("Prueba superada", string.format("Volvió en %d ms y %s: %s.", probe.ms, n == 1 and "respondió" or ("respondieron " .. n), table.concat(probe.answers, ", ")), { kind = "success", view = "admin" })
    end
  end)
end

BG:On("BG_COMM_ECHO", function()
  local probe = Diag.lastPing
  if probe and not probe.echo then
    probe.echo = GetTime()
    probe.ms = math.floor((probe.echo - probe.sent) * 1000 + 0.5)
    pingChanged()
  end
end)

Comm.Register("PG", function(sender)
  if not BG.Consent.Accepted() or (answeredAt[sender] and GetTime() - answeredAt[sender] < ANSWER_GAP) then
    return
  end
  answeredAt[sender] = GetTime()
  Comm.Send("PO", { v = BG.version }, "WHISPER", sender, { lane = "alert" })
end, { maxBytes = 40 })

Comm.Register("PO", function(sender, body)
  local probe = Diag.lastPing
  if probe and not probe.done and type(body) == "table" and BG.Guild.Find(sender) then
    probe.answers[#probe.answers + 1] = sender .. " (" .. tostring(body.v):sub(1, 12) .. ")"
    pingChanged()
  end
end, { channels = { "WHISPER" }, maxBytes = 40 })

BG.commands = BG.commands or {}
local function openAdmin()
  if not (BG.window and BG.window:IsShown()) then
    BG:ToggleWindow()
  end
  BG:ShowView("admin")
end
BG.commands.estado = function()
  openAdmin()
  Diag.Status()
end
BG.commands.rendimiento = Diag.Perf
BG.commands.errores = Diag.Errors
BG.commands.prueba = function()
  openAdmin()
  Diag.Ping()
end
BG.commands.privacidad = function()
  BG.Consent.Open()
end
