-- The privacy page: what this addon shares, in plain words, accepted once per game account before anything
-- leaves this client (Comm.Send refuses until then). Later features that share something more on their
-- own (a position on the map, a BattleTag...) add a line with Consent.Register and stay off until the
-- player says yes to that line. Idea from Olympus's Consent.lua and Accord.lua (MIT); text is our own.
local _, BG = ...
local Consent = { VERSION = 1, lines = {} }
BG.Consent = Consent

function Consent.Accepted()
  local c = BG.db and BG.db.consent
  return type(c) == "table" and (c.version or 0) >= Consent.VERSION
end

function Consent.Answered()
  return Consent.Accepted() or (BG.db and BG.db.consentDeclinedAt ~= nil)
end

function Consent.Accept()
  BG.db.consent = { version = Consent.VERSION, at = time(), by = BG.Names.Me() }
  BG.db.consentDeclinedAt = nil
  BG:Print("conectado con tu hermandad. Puedes cambiarlo cuando quieras con /bg privacidad.")
  BG:Fire("BG_CONSENT_CHANGED", true)
end

function Consent.Decline()
  local was = Consent.Accepted()
  BG.db.consent = nil
  BG.db.consentDeclinedAt = time()
  if was then
    BG:Print("has dejado de compartir. El addon sigue mostrándote tu hermandad, pero no envía nada.")
    BG:Fire("BG_CONSENT_CHANGED", false)
  end
end

-- line: { key, label, text, explicit } — a feature that shares something more asks for it here.
function Consent.Register(line)
  Consent.lines[#Consent.lines + 1] = line
end

-- true only after the base acceptance AND a yes to this line.
function Consent.Line(key)
  return Consent.Accepted() and type(BG.db.consentLines) == "table" and BG.db.consentLines[key] == true
end

function Consent.SetLine(key, on)
  BG.db.consentLines = BG.db.consentLines or {}
  BG.db.consentLines[key] = on and true or false
  BG:Fire("BG_CONSENT_LINE", key, on)
end

local INTRO = "BlazonGuild funciona entre los addons de los miembros de tu hermandad. Para eso, tu addon tiene que mandar algunos datos a los de tus compañeros. Si aceptas, esto es lo que se comparte:"
local BULLETS = {
  "Que usas BlazonGuild y qué versión tienes.",
  "Lo que tú hagas desde el addon: apuntarte a una raid, publicar un grupo, tu perfil… Cada cosa la decides tú en el momento.",
  "Lo que el propio juego dice de ti y cuenta para la hermandad: tus duelos con compañeros, quién te mata en JcJ fuera de mazmorras, el oro que das a un tesorero y los jefes que matáis juntos.",
  "Solo con miembros de tu hermandad que tengan el addon. Si vuestro maestro forma una alianza, también el chat de la alianza y quién está conectado, con esas hermandades; con ninguna otra.",
  "Si vuestro maestro lo activa, unas cifras de la hermandad (cuántos sois, jefes derrotados…; nada de nadie en concreto) salen en la clasificación de hermandades, para quien juegue en grupo con vosotros.",
}
local NEVER = "Nunca se comparten tu posición en el mapa, tu equipo, tus otros personajes, tu BattleTag ni dónde ves a enemigos sin que lo aceptes aparte, una cosa cada vez. Si no aceptas, el addon te sigue mostrando tu hermandad, pero no envía nada."

function Consent.Open()
  if Consent.Accepted() then
    local since = BG.db.consent.at and date("%d/%m/%Y", BG.db.consent.at) or "hace tiempo"
    BG.UI.Dialog({
      title = "Privacidad",
      items = {
        "Compartes con tu hermandad desde el " .. since .. ".",
        INTRO,
        { bullet = BULLETS[1] }, { bullet = BULLETS[2] }, { bullet = BULLETS[3] }, { bullet = BULLETS[4] }, { bullet = BULLETS[5] },
        NEVER,
        { note = "Si dejas de compartir, tu addon deja de enviar al momento. Lo que ya enviaste lo conservan tus compañeros hasta que caduque." },
      },
      primary = { label = "Seguir compartiendo" },
      secondary = { label = "Dejar de compartir", fn = Consent.Decline },
    })
    return
  end
  BG.UI.Dialog({
    title = "Antes de conectar con tu hermandad",
    items = {
      INTRO,
      { bullet = BULLETS[1] }, { bullet = BULLETS[2] }, { bullet = BULLETS[3] }, { bullet = BULLETS[4] }, { bullet = BULLETS[5] },
      NEVER,
      { note = "Se pregunta una vez por cuenta del juego. Cámbialo cuando quieras con /bg privacidad." },
    },
    primary = { label = "Aceptar y conectar", fn = Consent.Accept },
    secondary = { label = "Ahora no", fn = Consent.Decline },
  })
end

-- Asked when the window opens and the question was never answered on this account.
function Consent.MaybeAsk()
  if not Consent.Answered() and not BG.UI.DialogShown() then
    Consent.Open()
  end
end
