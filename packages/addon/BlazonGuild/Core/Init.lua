-- BlazonGuild: namespace, saved data, events and entry points (slash command, key binding, addon compartment).
local ADDON_NAME, BG = ...
BG.name = ADDON_NAME
BG.version = C_AddOns and C_AddOns.GetAddOnMetadata(ADDON_NAME, "Version") or "0.1.0"
BG.media = "Interface\\AddOns\\" .. ADDON_NAME .. "\\Media\\"

local SCHEMA = 2

-- Tiny event bus: game events and the addon's own messages share one registry.
local listeners = {}
local frame = CreateFrame("Frame")

-- A game event this client does not have (Forever has no CRAFT_SHOW, for one) is skipped, never an error: an
-- error here stopped the rest of a file from loading (Artesanía, 0.11.0).
function BG:On(event, fn)
  if not listeners[event] then
    listeners[event] = {}
    if not event:find("^BG_") then
      local ok = pcall(frame.RegisterEvent, frame, event)
      if not ok then
        BG.unknownEvents = BG.unknownEvents or {}
        BG.unknownEvents[event] = true
      end
    end
  end
  table.insert(listeners[event], fn)
end

function BG:Fire(event, ...)
  for _, fn in ipairs(listeners[event] or {}) do
    local ok, err = pcall(fn, ...)
    if not ok then
      BG:RecordError(event, err)
    end
  end
end

frame:SetScript("OnEvent", function(_, event, ...)
  BG:Fire(event, ...)
end)

-- An item's name, link, quality, item level and icon, as the game knows it (nil while the client has no data of it
-- yet: C_Item.RequestLoadItemDataByID brings it, and GET_ITEM_INFO_RECEIVED says so). On Forever the item functions
-- live in C_Item and there is no global GetItemInfo (the probe of 2026-11-12): calling the global left the Armería
-- with «Objeto 6189» and a question mark in every slot (0.29.2). tests/audit.mjs keeps the global out of the addon.
function BG.ItemInfo(item)
  local get = C_Item and C_Item.GetItemInfo
  if not (get and item) then
    return nil
  end
  local ok, name, link, quality, level, _, _, _, _, _, icon = pcall(get, item)
  if not ok or type(name) ~= "string" or (issecretvalue and issecretvalue(name)) or name == "" then
    return nil
  end
  return name, link, tonumber(quality), tonumber(level), icon
end

-- Interface sound by SOUNDKIT name; silently skipped if this client lacks it (PlaySound(nil) would error).
function BG.Sound(key)
  local id = SOUNDKIT and SOUNDKIT[key]
  if id then
    PlaySound(id)
  end
end

-- Internal errors are kept in SavedVariables (last 30) so they can be diagnosed after a /reload,
-- and announced once per session in chat without flooding it.
local announced = false
function BG:RecordError(where, err)
  local text = "error en " .. tostring(where) .. ": " .. tostring(err)
  BG:Debug(text)
  if BG.db then
    BG.db.errors = BG.db.errors or {}
    local last, at = BG.db.errors[1], date("!%Y-%m-%dT%H:%M:%SZ")
    if last and last.where == tostring(where) and last.error == tostring(err) and last.version == BG.version then
      last.count, last.at = (last.count or 1) + 1, at -- (the same again: counted, so one repeated error does not push out the rest)
    else
      table.insert(BG.db.errors, 1, { at = at, version = BG.version, where = tostring(where), error = tostring(err) })
    end
    while #BG.db.errors > 30 do
      table.remove(BG.db.errors)
    end
  end
  if not announced then
    announced = true
    BG:Print("ha registrado un error interno; queda guardado para revisarlo.")
  end
end

-- A call of ours the game refused (ADDON_ACTION_BLOCKED; FORBIDDEN for one only the game's own interface may make).
-- The game only counts them in its addon list («Las acciones de interfaz han fallado debido a este add-on: 3», Peregrino,
-- 2026-11-18) and says nothing of which call or from where. It sends the event inside the refused call, so the stack
-- still holds the line that made it: each one is kept as an internal error (Administración, «Errores internos», and
-- /bg errores) with the function the game names, whether it was in combat, and that line, so it can be fixed.
-- (Until 0.29.3 nothing was kept, and each cause had to be found by hand.)
-- Pure: where a stack comes from, as "UI/Marks.lua:155 < UI/Marks.lua:259" (ours without "BlazonGuild/", the game's
-- files by their folder), leaving out this file (the handler and the event bus) and the lines with no file.
function BG.StackOrigin(stack)
  local out = {}
  for line in tostring(stack or ""):gmatch("[^\n]+") do
    local file, num = line:match('AddOns/([^"%]:]+%.lua)"?%]?:(%d+)')
    if file and file ~= "BlazonGuild/Core/Init.lua" then
      out[#out + 1] = file:gsub("^BlazonGuild/", "") .. ":" .. num
      if #out >= 4 then
        break
      end
    end
  end
  return table.concat(out, " < ")
end

local early = {} -- refusals before the saved data is loaded, kept for it
local function refused(forbidden, addon, func)
  if addon ~= ADDON_NAME then
    return
  end
  local origin = BG.StackOrigin(type(debugstack) == "function" and debugstack(1, 20, 0) or "")
  -- (technical words, never translated: what the game calls them)
  local what = tostring(func or "?")
  if forbidden then
    what = what .. " " .. "FORBIDDEN"
  end
  if InCombatLockdown and InCombatLockdown() then
    what = what .. " " .. "IN_COMBAT"
  end
  if origin ~= "" then
    what = what .. " < " .. origin
  end
  if not BG.db then
    early[#early + 1] = what
    return
  end
  BG:RecordError("acción bloqueada por el juego", what)
end
BG:On("ADDON_ACTION_BLOCKED", function(addon, func)
  refused(false, addon, func)
end)
BG:On("ADDON_ACTION_FORBIDDEN", function(addon, func)
  refused(true, addon, func)
end)
BG:On("BG_READY", function()
  for _, what in ipairs(early) do
    BG:RecordError("acción bloqueada por el juego", what)
  end
  early = {}
end)

function BG:Print(msg)
  print("|cffd0b078BlazonGuild|r " .. (BG.T and BG.T(msg) or msg))
end

function BG:Debug(msg)
  if BG.db and BG.db.settings.debug then
    BG:Print("|cff8a94a3" .. msg .. "|r")
  end
end

BG:On("ADDON_LOADED", function(name)
  if name ~= ADDON_NAME then
    return
  end
  BlazonGuildDB = BlazonGuildDB or {}
  local db = BlazonGuildDB
  if (db.schema or 0) < SCHEMA then
    db.schema = SCHEMA
  end
  db.settings = db.settings or {}
  db.settings.scale = db.settings.scale or 1
  db.settings.lastView = db.settings.lastView or "overview"
  db.guilds = db.guilds or {}
  BG.db = db
  if BG.Locale then
    BG.Locale.Init()
  end
  BG:Fire("BG_READY")
end)

-- Entry points -----------------------------------------------------------------------------------

function BlazonGuild_Toggle()
  if BG.ToggleWindow then
    BG:ToggleWindow()
  end
end

function BlazonGuild_OnAddonCompartmentClick()
  BlazonGuild_Toggle()
end

function BlazonGuild_OnAddonCompartmentEnter(_, button)
  GameTooltip:SetOwner(button, "ANCHOR_LEFT")
  GameTooltip:SetText("BlazonGuild", 0.82, 0.69, 0.47)
  GameTooltip:AddLine("Abrir la ventana de tu hermandad", 1, 1, 1)
  GameTooltip:AddLine("También: /bg o la tecla que asignes en Atajos > Accesorios", 0.66, 0.70, 0.76, true)
  BG.ShowTip()
end

function BlazonGuild_OnAddonCompartmentLeave()
  GameTooltip:Hide()
end

BINDING_HEADER_BLAZONGUILD = "BlazonGuild"
BINDING_NAME_BLAZONGUILD_TOGGLE = "Abrir o cerrar BlazonGuild"

SLASH_BLAZONGUILD1 = "/bg"
SLASH_BLAZONGUILD2 = "/blazonguild"
BG.commands = BG.commands or {}
BG.commands.ayuda = function()
  BG:Print("comandos:")
  for _, l in ipairs({
    "/bg  abre o cierra la ventana",
    "/bg privacidad  qué compartes con tu hermandad",
    "/bg prueba  comprueba que los mensajes entre addons funcionan",
    "/bg estado  conexión con tu hermandad",
    "/bg rendimiento  memoria y tiempos del addon",
    "/bg errores  últimos errores internos guardados",
    "/bg escala 0.6–1.6  tamaño de la ventana",
    "/bg minimapa  muestra u oculta el botón del minimapa",
    "/bg sebusca  abre «Se busca»",
    "/bg arena  abre la Arena",
    "/bg duelo  cara a cara del duelo que tienes en tu objetivo",
    "/bg marcas  muestra u oculta las marcas sobre los nombres y en el chat",
    "/bg idioma  el idioma del addon (auto, es, en, de, fr, it, pt, ru)",
    "/bg autoprueba  comprueba el addon en este juego y te da un informe para copiar",
    "/bg vista  ver el addon como un miembro (organizadores), y volver",
    "/bg capturas  una hermandad de ejemplo para hacer capturas (solo en tu pantalla), y volver",
    "/bg api  qué otros addons pueden leer BlazonGuild (/bg api quitar Nombre)",
    "/bg reset  recoloca la ventana",
  }) do
    print("  " .. BG.T(l))
  end
end

SlashCmdList.BLAZONGUILD = function(input)
  local cmd = strtrim(input or ""):lower()
  local word = cmd:match("^(%S+)")
  if word and BG.commands[word] then
    BG.commands[word](cmd:match("^%S+%s+(.+)$"))
  elseif cmd == "debug" then
    BG.db.settings.debug = not BG.db.settings.debug
    BG:Print("modo depuración " .. (BG.db.settings.debug and "activado" or "desactivado"))
  elseif cmd == "reset" then
    BG.db.settings.point = nil
    BG.db.settings.scale = 1
    if BG.window then
      BG.window:ClearAllPoints()
      BG.window:SetPoint("CENTER")
      BG.window:SetScale(1)
    end
    BG:Print("posición y tamaño de la ventana restablecidos")
  elseif cmd:match("^escala") then
    local value = tonumber(cmd:match("([%d%.]+)"))
    if value and value >= 0.6 and value <= 1.6 then
      BG.db.settings.scale = value
      if BG.window then
        BG.window:SetScale(value)
      end
      BG:Print("escala " .. value)
    else
      BG:Print("uso: /bg escala 0.6–1.6")
    end
  else
    BlazonGuild_Toggle()
  end
end
