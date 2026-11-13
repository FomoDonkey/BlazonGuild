-- Playing with a gamepad (entrega 13; the idea of Olympus' Gamepad.lua and GamepadRegistry.lua, MIT; our own,
-- smaller). With the game's gamepad interface on, the game's own code drives its menus, tooltips, nameplates and chat
-- box, and an addon that touches them can make the game refuse its next protected call until a /reload. So, with the
-- gamepad interface on, BlazonGuild keeps to its own windows: every way it reaches into the game's interface is in
-- the list below, and the ones marked "gate" ask Gamepad.Allowed(id) each time and do nothing while it is on. A switch
-- between the gamepad and mouse and keyboard is followed at once (BG_GAMEPAD_CHANGED).
local _, BG = ...
local Pad = {}
BG.Gamepad = Pad

-- guard: "gate" off while the gamepad interface is on; "own" only our frames, or reading the game (stays).
Pad.REACH = {
  menus = { guard = "gate", what = "«Ver su ficha» en el menú del botón derecho del juego" },
  tooltip = { guard = "gate", what = "La línea de BlazonGuild en el recuadro de un jugador" },
  guildframe = { guard = "gate", what = "El botón de BlazonGuild en la ventana de hermandad del juego" },
  mainkey = { guard = "gate", what = "El atajo Mayús + tecla de hermandad" },
  nameplates = { guard = "gate", what = "Las marcas sobre las placas de nombre y el aro del retrato del objetivo" },
  chatmarks = { guard = "gate", what = "El escudo de honor en las ventanas de chat del juego" },
  chatbox = { guard = "gate", what = "Abrir el chat del juego para susurrar a alguien" },
  links = { guard = "gate", what = "Mayús + clic en un objeto para ponerlo en un campo de BlazonGuild" },
  channel = { guard = "gate", what = "El canal oculto de la alianza (su chat sigue por los mensajeros)" },
  window = { guard = "own", what = "La ventana de BlazonGuild, sus diálogos y sus avisos" },
  worldmap = { guard = "own", what = "Los puntos de los compañeros en el mapa del mundo" },
  minimap = { guard = "own", what = "Los puntos del minimapa y la flecha «Seguir»" },
  faceoff = { guard = "own", what = "La ventana «Cara a cara»" },
  mail = { guard = "own", what = "Apuntar en la Tesorería el oro del correo (solo lee lo que hace el juego)" },
  quiet = { guard = "own", what = "Callar el aviso del juego «no está conectado» de los susurros entre addons" },
}

-- Is the game's gamepad interface on now? (the game's own test)
function Pad.On()
  local current = C_InputInterfaceStyle and C_InputInterfaceStyle.GetCurrentStyle
  local gamepad = Enum and Enum.InputDeviceInterfaceType and Enum.InputDeviceInterfaceType.Gamepad
  if not current or gamepad == nil then
    return false
  end
  local ok, style = pcall(current)
  return ok and style == gamepad
end

-- May BlazonGuild do `id` now? An id missing from the list is refused, so nothing new slips in unlisted.
function Pad.Allowed(id)
  local r = Pad.REACH[id]
  if not r then
    return false
  end
  return r.guard ~= "gate" or not Pad.On()
end

local was
BG:On("INPUT_DEVICE_INTERFACE_TRANSITION", function()
  -- (the game sends it in the middle of its own switch: our work waits for the next frame)
  C_Timer.After(0, function()
    local on = Pad.On()
    if on == was then
      return
    end
    was = on
    BG:Fire("BG_GAMEPAD_CHANGED", on)
    BG:Notify(on and "Modo mando" or "Ratón y teclado", on and "BlazonGuild deja de tocar los menús, las placas y el chat del juego. Su ventana sigue igual."
      or "BlazonGuild vuelve a poner sus marcas y sus líneas en la interfaz del juego.", { kind = "info" })
  end)
end)

BG:On("PLAYER_LOGIN", function()
  was = Pad.On()
end)
