-- Life of the guild: announcements with read receipts, polls with a countdown, a speaking queue ("court"),
-- the leadership's calls to arms with an on-screen alert and a map pin, a chronicle of what happens, the
-- week's summary, release letters after each update, a welcome when you receive a role, and questions and
-- answers. Ideas from Olympus's Decree, Acts, Vox, Court, Chronicle, WeeklyBrief, Letters, RoleBriefings,
-- Answers and AnswerBank (MIT); our own implementation and texts.
local _, BG = ...
local Board = {}
BG.Board = Board
local Store, Names, Comm = BG.Store, BG.Names, BG.Comm
local str, int = BG.Raids.Clean, BG.Raids.Int

local function organiserOnly(author)
  return Store.IsOrganiser(author)
end

local function ownId(author, r)
  local prefix = author:gsub("%s", "") .. "-"
  return r.id:sub(1, #prefix) == prefix
end

-- Announcements -----------------------------------------------------------------------------------------
Store.Define("news", { ttl = 30 * 86400, can = function(author, r, old)
  return Store.IsOrganiser(author) and (not old or ownId(author, r) or Store.IsMaster(author))
end, normalize = function(d)
  local title = str(d.title, 80)
  if not title or title == "" then
    return nil
  end
  return { title = title, text = str(d.text, 600), important = d.important == true or nil }
end })

-- Each player's read receipts: one record per player with the ids they have read.
Store.Define("seen", { ttl = 30 * 86400, can = function(author, r)
  return Names.Same(r.id, author)
end, normalize = function(d)
  local ids = {}
  for i = 1, math.min(40, #(type(d.ids) == "table" and d.ids or {})) do
    local id = str(d.ids[i], 80)
    if id then
      ids[#ids + 1] = id
    end
  end
  return { ids = ids }
end })

function Board.News()
  local list = Store.List("news")
  table.sort(list, function(a, b)
    if (a.d.important or false) ~= (b.d.important or false) then
      return a.d.important == true
    end
    return a.at > b.at
  end)
  return list
end

function Board.Post(title, text, important)
  local me = Names.Me()
  return Store.Put("news", me:gsub("%s", "") .. "-" .. Store.Now(), { title = title, text = text, important = important }, { lane = "alert" })
end

function Board.Readers(newsId)
  local out = {}
  for _, r in ipairs(Store.List("seen")) do
    for _, id in ipairs(r.d.ids) do
      if id == newsId then
        out[#out + 1] = r.id
        break
      end
    end
  end
  table.sort(out)
  return out
end

function Board.HasRead(newsId)
  local me = Names.Me()
  local r = me and Store.Get("seen", me)
  for _, id in ipairs(r and not r.del and r.d.ids or {}) do
    if id == newsId then
      return true
    end
  end
  return false
end

function Board.MarkRead(newsId)
  local me = Names.Me()
  if not me or Board.HasRead(newsId) then
    return
  end
  local r = Store.Get("seen", me)
  local ids = {}
  for _, id in ipairs(r and not r.del and r.d.ids or {}) do
    if Store.Get("news", id) then
      ids[#ids + 1] = id -- (only receipts for announcements that still exist)
    end
  end
  ids[#ids + 1] = newsId
  return Store.Put("seen", me, { ids = ids })
end

-- Polls --------------------------------------------------------------------------------------------------
-- Any member can ask the guild; the poll's author or an organiser can close it early.
Store.Define("polls", { ttl = function(r)
  return (r.d and r.d.closes or r.at) + 7 * 86400
end, can = function(author, r, old)
  if old then
    return ownId(author, r) or Store.IsOrganiser(author)
  end
  return ownId(author, r) and BG.Guild.Find(author) ~= nil
end, normalize = function(d)
  local q = str(d.q, 140)
  local options = {}
  for i = 1, math.min(6, #(type(d.options) == "table" and d.options or {})) do
    local o = str(d.options[i], 60)
    if o and o ~= "" then
      options[#options + 1] = o
    end
  end
  local closes = tonumber(d.closes)
  if not q or q == "" or #options < 2 or not closes then
    return nil
  end
  return { q = q, options = options, closes = math.floor(closes) }
end })

Store.Define("votes", { ttl = 14 * 86400, can = function(author, r)
  return Names.Same(r.id:match("|(.+)$"), author)
end, normalize = function(d, r)
  local poll = type(d.poll) == "string" and d.poll or nil
  local choice = int(d.choice, 1, 6)
  if not poll or not choice or r.id:match("^(.+)|") ~= poll then
    return nil
  end
  local p = Store.Get("polls", poll)
  if p and p.d and (choice > #p.d.options or r.at > p.d.closes) then
    return nil -- an option that does not exist, or a vote after the poll closed
  end
  return { poll = poll, choice = choice }
end })

function Board.Polls()
  local list = Store.List("polls")
  local now = Store.Now()
  table.sort(list, function(a, b)
    local ao, bo = a.d.closes > now, b.d.closes > now
    if ao ~= bo then
      return ao
    end
    return a.at > b.at
  end)
  return list
end

function Board.Ask(question, options, minutes)
  local me = Names.Me()
  return Store.Put("polls", me:gsub("%s", "") .. "-" .. Store.Now(), { q = question, options = options, closes = Store.Now() + (minutes or 60) * 60 }, { lane = "alert" })
end

function Board.ClosePoll(id)
  local p = Store.Get("polls", id)
  if not p or p.del then
    return nil, "no existe"
  end
  return Store.Put("polls", id, { q = p.d.q, options = p.d.options, closes = Store.Now() - 1 })
end

function Board.Vote(pollId, choice)
  local me = Names.Me()
  return Store.Put("votes", pollId .. "|" .. me, { poll = pollId, choice = choice }, { lane = "alert" })
end

-- Pure given the stores: counts per option and the total.
function Board.Results(pollId)
  local p = Store.Get("polls", pollId)
  local counts, total = {}, 0
  for i = 1, #(p and p.d and p.d.options or {}) do
    counts[i] = 0
  end
  for _, v in ipairs(Store.List("votes", function(r)
    return r.d.poll == pollId
  end)) do
    if counts[v.d.choice] then
      counts[v.d.choice] = counts[v.d.choice] + 1
      total = total + 1
    end
  end
  return counts, total
end

function Board.MyVote(pollId)
  local me = Names.Me()
  local r = me and Store.Get("votes", pollId .. "|" .. me)
  return r and not r.del and r.d.choice or nil
end

-- Court: the speaking queue. The leader opens it; present members ask for a turn; the leader gives the floor.
Store.Define("court", { ttl = 6 * 3600, can = organiserOnly, normalize = function(d)
  return { open = d.open == true or nil, speaker = Names.Short(str(d.speaker, 40)), topic = str(d.topic, 120) }
end })

Store.Define("turns", { ttl = 6 * 3600, can = function(author, r)
  return Names.Same(r.id, author)
end, normalize = function(d)
  return { topic = str(d.topic, 120) }
end })

function Board.Court()
  local c = Store.Get("court", "guild")
  return c and not c.del and c.d.open and c or nil
end

function Board.OpenCourt(topic)
  return Store.Put("court", "guild", { open = true, topic = topic }, { lane = "alert" })
end

function Board.CloseCourt()
  return Store.Put("court", "guild", { open = false }, { lane = "alert" })
end

function Board.Queue()
  local court = Board.Court()
  local list = Store.List("turns", function(r)
    return court ~= nil and r.at >= court.at - 3600 and r.id ~= court.d.speaker
  end)
  table.sort(list, function(a, b)
    return a.at < b.at
  end)
  return list
end

function Board.AskTurn(topic)
  return Store.Put("turns", Names.Me(), { topic = topic }, { lane = "alert" })
end

function Board.LeaveQueue()
  return Store.Delete("turns", Names.Me())
end

function Board.NextSpeaker()
  local court = Board.Court()
  local q = Board.Queue()
  if not court then
    return nil
  end
  local nextName = q[1] and q[1].id or nil
  return Store.Put("court", "guild", { open = true, topic = court.d.topic, speaker = nextName }, { lane = "alert" })
end

-- Calls to arms -------------------------------------------------------------------------------------------
-- An organiser calls everyone: an alert in the middle of the screen, a sound and, when they share where, a
-- pin on the map. Live only (never stored): it would mean nothing an hour later.
local function myPosition()
  if not (C_Map and C_Map.GetBestMapForUnit and C_Map.GetPlayerMapPosition) then
    return nil
  end
  local ok, map = pcall(C_Map.GetBestMapForUnit, "player")
  if not ok or not map then
    return nil
  end
  local okP, pos = pcall(C_Map.GetPlayerMapPosition, map, "player")
  if not okP or not pos then
    return nil
  end
  local x, y = pos:GetXY()
  if issecretvalue and (issecretvalue(x) or issecretvalue(y)) then
    return nil
  end
  return map, x, y
end

function Board.Decree(kind, text, withPlace)
  if not Store.IsOrganiser(Names.Me()) then
    return false, "permiso"
  end
  local body = { k = kind == "RALLY" and "RALLY" or "ARMS", t = str(text, 120) }
  if withPlace then
    local map, x, y = myPosition()
    if map then
      body.m, body.x, body.y = map, math.floor(x * 10000), math.floor(y * 10000)
    end
  end
  BG.Board.ShowDecree(Names.Me(), body)
  return Comm.Send("DC", body, "GUILD", nil, { lane = "alert" })
end

function Board.ShowDecree(sender, body)
  -- (it can come from another addon, of any version: only text where text goes, without the game's escapes)
  sender = Names.Short(str(sender, 40)) or "?"
  body = { k = body.k, t = str(body.t, 120), al = str(body.al, 60), m = body.m, x = body.x, y = body.y }
  local title = (body.k == "RALLY" and "Reunión" or "¡A las armas!") .. (body.al and (" — alianza «" .. body.al .. "»") or "")
  local text = (body.t and body.t ~= "" and body.t or (body.k == "RALLY" and "Venid a donde está " .. sender or "Os necesitan ya")) .. " — " .. sender
  if RaidNotice_AddMessage and RaidWarningFrame and ChatTypeInfo then
    pcall(RaidNotice_AddMessage, RaidWarningFrame, title .. ": " .. text, ChatTypeInfo.RAID_WARNING)
  end
  BG.Sound("RAID_WARNING")
  BG:Notify(title, text, { kind = "danger", duration = 12, sound = "RAID_WARNING" })
  local map, x, y = tonumber(body.m), tonumber(body.x), tonumber(body.y)
  if map and x and y and x >= 0 and x <= 10000 and y >= 0 and y <= 10000 then
    -- (Mapa, «En el mapa»: the place can be followed with the minimap's arrow for half an hour)
    Board.lastPlace = { m = map, x = x / 10000, y = y / 10000, t = GetTime(), by = sender,
      label = string.format(body.k == "RALLY" and "Reunión con %s" or "¡A las armas!, con %s", sender) }
    BG:Fire("BG_MAP_CHANGED")
  end
  if map and x and y and C_Map and C_Map.SetUserWaypoint and UiMapPoint and UiMapPoint.CreateFromCoordinates then
    local okP, point = pcall(UiMapPoint.CreateFromCoordinates, map, x / 10000, y / 10000)
    if okP and point then
      pcall(C_Map.SetUserWaypoint, point)
      if C_SuperTrack and C_SuperTrack.SetSuperTrackedUserWaypoint then
        pcall(C_SuperTrack.SetSuperTrackedUserWaypoint, true)
      end
    end
  end
  Board.Log("decree", title .. " de " .. sender .. (body.t and body.t ~= "" and (": " .. body.t) or ""))
end

Comm.Register("DC", function(sender, body)
  if type(body) == "table" and Store.IsOrganiser(sender) then
    Board.ShowDecree(sender, body)
  end
end, { maxBytes = 300 })

-- Chronicle -------------------------------------------------------------------------------------------------
-- What happens, as this addon sees it: joins, departures, promotions, level 60, raids, decisions, calls.
local function chronicle()
  local g = BG.Guild.Entry()
  if not g then
    return nil
  end
  g.chronicle = g.chronicle or {}
  return g.chronicle
end

function Board.Log(kind, text, who)
  local c = chronicle()
  if not c then
    return
  end
  table.insert(c, 1, { at = Store.Now(), kind = kind, text = text, who = who })
  while #c > 300 do
    table.remove(c)
  end
  BG:Fire("BG_CHRONICLE")
end

function Board.Chronicle(days)
  local c = chronicle() or {}
  if not days then
    return c
  end
  local since = Store.Now() - days * 86400
  local out = {}
  for _, e in ipairs(c) do
    if e.at >= since then
      out[#out + 1] = e
    end
  end
  return out
end

-- Pure: what changed between two roster snapshots (by GUID).
function Board.Diff(before, after, maxLevel)
  local events = {}
  local old = {}
  for _, m in ipairs(before or {}) do
    if m.guid then
      old[m.guid] = m
    end
  end
  local seen = {}
  for _, m in ipairs(after or {}) do
    if m.guid then
      seen[m.guid] = true
      local o = old[m.guid]
      if not o then
        events[#events + 1] = { kind = "join", text = m.name .. " entra en la hermandad", who = m.name }
      else
        if o.rankIndex and m.rankIndex and m.rankIndex < o.rankIndex then
          events[#events + 1] = { kind = "promote", text = m.name .. " asciende a " .. tostring(m.rank), who = m.name, rankIndex = m.rankIndex }
        elseif o.rankIndex and m.rankIndex and m.rankIndex > o.rankIndex then
          events[#events + 1] = { kind = "demote", text = m.name .. " pasa a " .. tostring(m.rank), who = m.name, rankIndex = m.rankIndex }
        end
        if (o.level or 0) < (maxLevel or 60) and (m.level or 0) >= (maxLevel or 60) then
          events[#events + 1] = { kind = "max", text = m.name .. " llega al nivel " .. (maxLevel or 60), who = m.name }
        end
      end
    end
  end
  for guid, o in pairs(old) do
    if not seen[guid] then
      events[#events + 1] = { kind = "leave", text = o.name .. " deja la hermandad", who = o.name }
    end
  end
  return events
end

-- Week's summary: pure over a chronicle list and the raids.
function Board.WeekSummary(entries, raids)
  local s = { join = 0, leave = 0, promote = 0, max = 0, raids = 0, decree = 0 }
  for _, e in ipairs(entries) do
    if s[e.kind] then
      s[e.kind] = s[e.kind] + 1
    end
  end
  local now = Store.Now()
  for _, r in ipairs(raids or {}) do
    if r.d.start >= now - 7 * 86400 and r.d.start <= now + 7 * 86400 and r.d.status ~= "CANCELLED" then
      s.raids = s.raids + 1
    end
  end
  return s
end

-- The roster as the chronicle last saw it, kept in the guild's saved entry: GUID -> { name, rankIndex, rank, level }.
-- (Since 0.28 it is brought up to date in place, only what changed: copying a big guild's every member at each change
-- was most of the addon's garbage. The list of before, prevMembers, becomes this once.)
local function knownRoster(entry)
  if not entry.prevRoster and type(entry.prevMembers) == "table" then
    local map = {}
    for _, m in ipairs(entry.prevMembers) do
      if m.guid then
        map[m.guid] = { name = m.name, rankIndex = m.rankIndex, rank = m.rank, level = m.level }
      end
    end
    entry.prevRoster, entry.prevMembers = map, nil
  end
  return entry.prevRoster
end

-- What changed since `known` (the same events as Board.Diff, in the same order), with `known` brought up to `members`.
local gen = 0
function Board.DiffInPlace(known, members, maxLevel)
  gen = gen == 0 and time() * 1000 or gen + 1 -- (a mark for whom we saw now; never the one of another session)
  maxLevel = maxLevel or 60
  local events = {}
  for _, m in ipairs(members) do
    if m.guid then
      local o = known[m.guid]
      if not o then
        events[#events + 1] = { kind = "join", text = m.name .. " entra en la hermandad", who = m.name }
        o = {}
        known[m.guid] = o
      else
        if o.rankIndex and m.rankIndex and m.rankIndex < o.rankIndex then
          events[#events + 1] = { kind = "promote", text = m.name .. " asciende a " .. tostring(m.rank), who = m.name, rankIndex = m.rankIndex }
        elseif o.rankIndex and m.rankIndex and m.rankIndex > o.rankIndex then
          events[#events + 1] = { kind = "demote", text = m.name .. " pasa a " .. tostring(m.rank), who = m.name, rankIndex = m.rankIndex }
        end
        if (o.level or 0) < maxLevel and (m.level or 0) >= maxLevel then
          events[#events + 1] = { kind = "max", text = m.name .. " llega al nivel " .. maxLevel, who = m.name }
        end
      end
      o.name, o.rankIndex, o.rank, o.level, o.seen = m.name, m.rankIndex, m.rank, m.level, gen
    end
  end
  for guid, o in pairs(known) do
    if o.seen ~= gen then
      events[#events + 1] = { kind = "leave", text = tostring(o.name) .. " deja la hermandad", who = o.name }
      known[guid] = nil
    end
  end
  return events
end

local lastDemo
BG:On("BG_ROSTER_UPDATED", function()
  local g = BG.Guild
  if not g.info or g.fromCache then
    return
  end
  local entry = g.Entry()
  if not entry then
    return
  end
  -- Going into or out of the capture mode (Core/Demo.lua) changes the whole guild on screen: nobody joined or left.
  local switched = (BG.demo or false) ~= (lastDemo or false)
  lastDemo = BG.demo
  local known = knownRoster(entry)
  if switched or not known then
    entry.prevRoster = {}
    Board.DiffInPlace(entry.prevRoster, g.members, g.MaxLevel()) -- (only to fill it)
  else
    for _, e in ipairs(Board.DiffInPlace(known, g.members, g.MaxLevel())) do
      Board.Log(e.kind, e.text, e.who)
      -- A welcome letter the first time you receive an organiser's rank (Olympus's RoleBriefings idea).
      if e.kind == "promote" and g.me and Names.Same(e.who, g.me.name) and Store.IsOrganiser(g.me.name) then
        BG.UI.Dialog({
          title = "Ahora organizas en " .. g.info.name,
          items = { "Tu nuevo rango, " .. tostring(g.me.rank) .. ", es de organizador en BlazonGuild. A partir de ahora puedes:",
            { bullet = "gestionar todas las raids de la hermandad, no solo las tuyas;" },
            { bullet = "moderar el chat: silenciar, borrar mensajes y abrir casos;" },
            { bullet = "publicar anuncios y lanzar «¡A las armas!» y «Reunión aquí»." },
            { note = "Las decisiones finales de moderación siguen siendo del maestro." } },
          primary = { label = "Entendido" },
        })
      end
    end
  end
end)

BG:On("BG_RECORD", function(kind, r, old)
  if kind == "raids" and r.d and not old then
    Board.Log("raid", (r.d.leader or r.by) .. " convoca " .. r.d.title)
  elseif kind == "cases" and r.d and r.d.status == "DECIDED" and not (old and old.d and old.d.status == "DECIDED") then
    Board.Log("case", "El maestro decide sobre " .. r.d.target)
  elseif kind == "news" and r.d and not old then
    Board.Log("news", "Anuncio: " .. r.d.title)
    BG:Notify(r.d.important and "Anuncio importante" or "Anuncio nuevo", r.d.title, { kind = r.d.important and "warning" or "info", view = "board" })
  elseif kind == "polls" and r.d and not old then
    BG:Notify("Encuesta nueva", r.d.q, { kind = "info", view = "board" })
  elseif kind == "court" and r.d and r.d.speaker and Names.IsMe(r.d.speaker) and not (old and old.d and old.d.speaker == r.d.speaker) then
    BG:Notify("Tienes la palabra", (r.d.topic and r.d.topic ~= "" and r.d.topic or "Es tu turno de hablar") .. ".", { kind = "success", view = "board", sound = "READY_CHECK" })
  end
end)

-- Release letters: once per version, after an update (Olympus's Letters idea).
Board.letters = {
  ["0.5.0"] = {
    "Cualquier miembro puede crear raids y dirigirlas.",
    "Nueva sección Chat: el chat de hermandad con más espacio y salas como Sanadores o Comercio.",
    "Moderación para los organizadores, con avisos y casos que decide el maestro.",
    "Administración enseña cómo va la conexión, con una prueba de mensajes.",
  },
  ["0.6.0"] = {
    "Nueva sección Tablón: anuncios, encuestas, turnos de palabra, la crónica y el resumen de la semana.",
    "«¡A las armas!» y «Reunión aquí» para los organizadores, con alerta y marca en el mapa.",
    "Preguntas frecuentes dentro del juego.",
  },
  ["0.7.0"] = {
    "Nueva sección Alianza: une tu hermandad con otras (lo deciden los maestros).",
    "En el chat, una pestaña para toda la alianza y otra para cada hermandad hermana; las salas de roles se comparten.",
    "«Mazmorras» ahora se llama Grupos: también para JcJ, misiones, subir de nivel o farmear.",
  },
  ["0.8.0"] = {
    "La alianza tiene líder: el maestro de la hermandad que vote la mayoría de los maestros.",
    "El líder puede llamar a las armas a toda la alianza y darle una clave nueva.",
    "Cada maestro nombra capitanes (entran en «Oficiales de la alianza») y mensajeros.",
    "Los cambios de la alianza van firmados: nadie puede falsificarlos.",
    "La alianza cuenta personas, no personajes: los alters cuentan una vez.",
  },
  ["0.9.0"] = {
    "Nueva Sala de guerra: escuadras con su jefe y su propio chat.",
    "Operaciones con día, hora y lugar: respondes «Voy», «Reserva» o «No puedo», y te avisamos al empezar.",
    "Al terminar, quien la dirigió escribe el parte, que queda en la crónica.",
  },
  ["0.10.0"] = {
    "Nueva sección Mapa: cuántos compañeros hay en cada zona y quiénes son.",
    "Si quieres, compartes tu posición y tu capa con la hermandad: salís como puntos en el mapa del mundo.",
    "Capas: ves en qué copia de la zona está cada uno y puedes pedir invitación para pasar a la suya.",
  },
  ["0.10.1"] = {
    "Mapa explica qué pasa al compartir tu posición, quién te ve y dónde, y abre el mapa del mundo.",
    "Chat de hermandad: lo que se dijo mientras no estabas te lo pasa un compañero con BlazonGuild.",
    "Los enlaces de objetos del chat se ven bien (antes salían rotos), también los ya guardados.",
    "Ningún botón se sale de su panel: ahora lo comprueban las pruebas en todas las pantallas.",
  },
  ["0.10.2"] = {
    "Botón para minimizar (junto a la X): queda una barra pequeña que puedes mover; púlsala para volver.",
    "Al abrir el mapa del mundo la ventana se minimiza sola, y vuelve al cerrarlo.",
    "Nuevo botón redondo en el minimapa: un clic abre o cierra BlazonGuild; arrástralo para moverlo.",
  },
  ["0.11.0"] = {
    "Nueva sección Artesanía y botín: al abrir tu profesión, puedes publicarla para tu hermandad.",
    "Busca quién sabe hacer un objeto, susúrrale o hazle un encargo; los encargos cumplidos hacen el ranking de artesanos.",
    "Notas de botín para los organizadores (a quién se dio qué y por qué), con puntos opcionales a mano. Sin pujas ni oro.",
  },
  ["0.11.1"] = {
    "Arreglado: Artesanía y botín se veía con las pestañas una encima de otra.",
    "Nuevo botón «?» arriba: «Cómo funciona», una guía corta y con ejemplos de cada sección complicada.",
    "La guía sale sola la primera vez que abres Artesanía, Mapa, Alianza o Sala de guerra.",
  },
  ["0.11.2"] = {
    "Pulsa cualquier tarjeta para desplegarla y leer todo su texto (vuelve a pulsar para recogerla).",
    "Pasa el ratón por encima de una tarjeta para ver su texto entero.",
    "El texto ya nunca queda debajo de los botones de la tarjeta.",
  },
  ["0.12.0"] = {
    "Nueva sección Tesorería: el libro de la hermandad se apunta solo cuando das oro a un tesorero (comercio o correo).",
    "Cuota semanal opcional: en «Resumen» ves cuánto has dado esta semana y cuánto te falta.",
    "Campañas de donación con su barra de progreso, y una foto del banco de la hermandad.",
  },
  ["0.13.0"] = {
    "Nueva sección Reclutamiento: la ficha pública de la hermandad, que escriben los oficiales.",
    "Quien no tiene hermandad puede buscaros, ver vuestra ficha y pedir entrar; los oficiales le invitan con un clic.",
    "Cada nuevo miembro dice quién le trajo, y si cambias de hermandad puedes traerte tu ficha.",
  },
  ["0.14.0"] = {
    "Nueva sección «Se busca»: quien de la otra facción mate a uno de los vuestros fuera de mazmorras entra en la lista con su recompensa.",
    "Si le cazas tú, te llevas la recompensa; y si un buscado anda cerca, te avisa.",
    "Rankings y honores: los primeros de cada podio llevan un escudo dorado sobre su nombre, en el chat y su honor en la ficha.",
  },
  ["0.15.0"] = {
    "Nueva sección Arena: duelos entre miembros con su clasificación. El resultado lo lee el propio juego.",
    "Rangos Oro, Plata y Bronce, cinturón de campeón y temporadas.",
    "Puedes retar a quien esté conectado; si acepta, os avisamos a los dos. Sin apuestas.",
  },
  ["0.15.1"] = {
    "Arreglado: la Arena y «Se busca» se quedaban a medias (y la Arena enseñaba «Nueva temporada» a todos).",
    "Tesorería: las cantidades ya caben en sus cuadros. Rankings: los 10 primeros de cada honor, y ya no está el del nivel 60.",
    "Arena: en «Retos» salen todos los conectados, y se explica cómo retar. Administración: solo marca en rojo los errores de esta versión.",
  },
  ["0.16.0"] = {
    "Raids: nuevo botón «Grupos», con los grupos de la banda como en el juego. Arrastra a cada uno a su grupo, o púlsalo y luego pulsa dónde va.",
    "«Colocar en la banda» mueve a la gente a sus grupos de verdad cuando la banda ya está formada (líder o ayudante, fuera de combate).",
    "Todos ven los grupos; los mueven el líder de la raid, quien la creó y los oficiales.",
  },
  ["0.17.0"] = {
    "Arena, nueva pestaña «Torneos»: torneos con cuadro eliminatorio y sorteo con /roll, y veladas con combates anunciados.",
    "Cada combate lo decide el duelo entre los dos, y toda la hermandad se entera de quién pasa y de quién gana.",
    "Nuevo honor en Rankings: Campeón de la Arena. Y arreglado: algunos botones salían sin texto.",
  },
  ["0.17.1"] = {
    "Raids: «Voy», «Quizá» y «No voy» se guardan al pulsarlos (y el rol, si ya estás apuntado).",
    "Una raid cancelada se ve cancelada: solo su cabecera con «CANCELADA» y, para quien la gestiona, «Volver a programar» y «Borrar».",
    "Arreglado: al volver a programar una raid cancelada, seguía cancelada.",
  },
  ["0.17.2"] = {
    "Grupos de la raid: ahora eliges también la fila dentro del grupo; soltarlo sobre otro les cambia la fila.",
    "Velada: al añadir un combate, eliges a cada luchador de una lista con los miembros por orden alfabético, o escribes parte del nombre para buscarlo.",
  },
  ["0.18.0"] = {
    "Arena, nueva pestaña «Taberna»: los Huesos, un juego de dados por puntos (contra la casa para practicar, o contra alguien de la hermandad).",
    "Lotería de práctica: cada día, hasta 3 boletos gratis; un oficial sortea con /roll 1-100 y se anuncia quién acierta.",
    "Al hablar con un posadero, un aviso te propone una partida. Todo por puntos: aquí no se mueve oro.",
  },
  ["0.19.0"] = {
    "BlazonGuild habla ahora inglés, alemán, francés, italiano, portugués y ruso, además de español.",
    "Sale en el idioma de tu juego. En Administración, «Idioma del addon», eliges otro; se aplica al recargar la interfaz.",
    "Los nombres y lo que escribe cada uno (notas, anuncios, mensajes) salen tal cual, sin traducir.",
  },
  ["0.19.1"] = {
    "Seguridad: nadie de otra hermandad puede meter nada en la vuestra (antes, un jugador de otra hermandad con el addon podía colaros un torneo, una sala de chat o un grupo).",
    "Los casos de moderación y los avisos ya solo están en el ordenador de los organizadores.",
    "Un ordenador con personajes en varias hermandades guarda lo de cada una por separado, también si dos se llaman igual.",
  },
  ["0.20.0"] = {
    "Nueva Armería: el equipo de cada uno, ranura a ranura, si lo comparte (pulsa «Compartir mi equipo»), o si lo inspeccionas tú de cerca.",
    "Nuevo JcE: quién tiene nivel para cada banda, los jefes que lleva derrotados la hermandad (se apuntan solos) y las últimas raids.",
    "Rankings, nueva pestaña «Hermandades»: la clasificación de las hermandades con BlazonGuild y la comparativa con la vuestra. Sale la vuestra si el maestro lo activa.",
  },
  ["0.21.0"] = {
    "Mapa: quien comparte su posición sale ahora también como un punto en tu minimapa.",
    "Mapa, pestaña «En el mapa»: «Seguir» pone una flecha bajo el minimapa que te lleva hasta un compañero o hasta el punto de reunión.",
    "Mapa, pestaña «Avistamientos»: pregunta a tu hermandad dónde se vio a un jugador de la otra facción (responde quien lo acepta).",
  },
  ["0.22.0"] = {
    "Alianza, pestaña «Cartas y avisos»: cartas del líder a los maestros (con quién las ha leído), «puertas abiertas» para mandar a los nuevos a una hermandad y ocultar a alguien en los chats comunes.",
    "Sala de guerra: la hermandad que lidera la alianza puede planear operaciones de toda la alianza; llegan a todas las hermandades y cada una responde en la suya.",
    "El chat de la alianza va también por un canal oculto del juego, así llega aunque falten mensajeros. Y la pestaña «Gestión» reúne los cargos y las invitaciones.",
  },
  ["0.23.0"] = {
    "Arena, «Cara a cara»: dos luchadores frente a frente (puntos, rango, récord, sus combates entre ellos), con su vida en directo si los tienes cerca y quién gana al acabar. Se agranda para retransmitir.",
    "«Ver un duelo» (o /bg duelo): el cara a cara del duelo de tu objetivo. Y en cada torneo o velada, «Cara a cara del siguiente combate».",
    "Árbitros de la Arena (los nombran los organizadores) y una sala de chat para cada torneo o velada.",
  },
  ["0.24.0"] = {
    "Autoprueba (Administración o /bg autoprueba): comprueba el addon en tu juego y te da un informe para copiar.",
    "Con mando: BlazonGuild ya no toca nada de la interfaz del juego mientras la de mando está activada.",
    "Los organizadores pueden ver el addon como un miembro («Ver como miembro»), y otros addons pueden leer BlazonGuild si tú les das permiso.",
  },
  ["0.25.0"] = {
    "Taberna: los Huesos tienen mesa nueva, con dados que caen, ruedan y brillan si puntúan, los pasos del turno a la vista y «Cómo se juega».",
    "Armería: «Ver su equipo» funciona aunque esté lejos (si tiene BlazonGuild, se lo pedimos). Y en los encargos puedes poner el objeto con Mayús+clic o arrastrándolo.",
    "Las listas para elegir a alguien ya no salen vacías: se hacen al abrirlas, y si no hay nadie lo dicen.",
  },
  ["0.26.0"] = {
    "Modo capturas (/bg capturas, o «Capturas» en Administración): una hermandad de ejemplo con nombres inventados, solo en tu pantalla, para enseñar BlazonGuild con todas las pantallas llenas. No sale nada de tu juego.",
    "Armería: la lista del equipo ya no se sale de su panel la primera vez que se abre.",
    "En inglés y los demás idiomas: los títulos del Tablón y el Calendario, el oro de la Tesorería, la Arena, los grupos y la Sala de guerra ya salen traducidos.",
  },
  ["0.27.0"] = {
    "Revisión completa del addon. En Forever el juego da los nombres de otra forma («El», o «El-Peregrino»), y por eso los duelos no se apuntaban, las tiradas de los Huesos y la lotería no se leían, el oro por comercio o correo se apuntaba a otro nombre y «Ver su equipo» no encontraba a nadie cerca. Arreglado.",
    "Los jefes de las bandas se apuntan aunque el juego dé solo el nombre, y la clasificación de hermandades ya verifica las fichas de las demás.",
    "Privacidad: la página dice también lo que el juego cuenta solo (duelos, muertes en JcJ, oro a tesoreros, jefes) y todo lo que se pide aparte.",
    "Tesorería: el oro se escribe también como 2g 50s. Autoprueba: dice cómo escribe tu juego los nombres.",
  },
  ["0.28.0"] = {
    "Las mazmorras y bandas son ya las de WoW Forever: sus 9 mazmorras nuevas (Salón de los Feudales, Ruinas de Lordaeron, Ciudad de Dalaran, Bastión Faucenegra…) y sus tres bandas, Cavernas del Túmulo, Cima Hyjal y Guarida de Onyxia, con los nombres del juego.",
    "Núcleo de Magma, Guarida Alanegra, Zul'Gurub, Ahn'Qiraj y Naxxramas ya no salen para elegir: no están en Forever. Una raid antigua que las usara se sigue viendo.",
    "Las mazmorras de dentro de una capital son de su bando; las demás, para todos (las Minas de la Muerte y el Castillo de Colmillo Oscuro ya salen a las dos facciones).",
  },
  ["0.29.0"] = {
    "Consume menos, y todo sigue igual: el addon ocupa casi la mitad de memoria (solo guarda tu idioma), y en una hermandad grande cada actualización de la lista de miembros cuesta varias veces menos y casi no deja basura.",
    "El punto del minimapa y la flecha ya no gastan nada mientras no hay nada que dibujar.",
  },
  ["0.29.1"] = {
    "Administración: al cambiar de idioma ya no sale «Una acción de interfaz ha fallado por culpa de un accesorio». El juego no deja que un accesorio recargue la interfaz: escribe /reload.",
  },
  ["0.29.2"] = {
    "Armería: cada objeto sale con su nombre y su icono (antes salía «Objeto 6189» con una interrogación). En tu propio equipo, la ventana del objeto ya no sale repetida al lado.",
  },
  ["0.29.3"] = {
    "Marcas: el escudo sobre los nombres y el aro del retrato de tu objetivo ya no tocan en combate los marcos protegidos del juego, que podían sacar «Las acciones de interfaz han fallado debido a este add-on» en la lista de accesorios.",
    "Si el juego bloquea algo del addon, queda guardado con su origen en Administración, «Errores internos», para poder arreglarlo.",
    "Quien lo instala ve un aviso que dice cómo abrirlo: /bg o el escudo junto al minimapa.",
  },
  ["0.29.4"] = {
    "Ya no sale «BlazonGuild ha registrado un error interno» al combatir: en combate el addon pedía al juego el mensaje del día de la hermandad, y el juego no lo deja. Ahora lo lee al acabar el combate.",
  },
}

-- A first install has nothing to catch up on: it starts at the current version, and only later updates
-- bring a letter.
BG:On("BG_READY", function()
  if BG.db.lastLetter == nil and BG.db.consent == nil and BG.db.consentDeclinedAt == nil then
    BG.db.lastLetter = BG.version
  end
end)

BG:On("PLAYER_LOGIN", function()
  C_Timer.After(20, function()
    local last = BG.db.lastLetter
    -- Every letter newer than the last one read, oldest first (someone may skip versions).
    local versions = {}
    for v in pairs(Board.letters) do
      if (not last or BG.Peers.CompareVersions(v, last) > 0) and BG.Peers.CompareVersions(v, BG.version) <= 0 then
        versions[#versions + 1] = v
      end
    end
    table.sort(versions, function(a, b)
      return BG.Peers.CompareVersions(a, b) < 0
    end)
    local lines = {}
    for _, v in ipairs(versions) do
      for _, l in ipairs(Board.letters[v]) do
        lines[#lines + 1] = l
      end
    end
    BG.db.lastLetter = BG.version
    if last ~= BG.version and #lines > 0 and BG.Consent.Answered() then -- (not on a first install: the privacy page comes first)
      local items = {}
      for _, l in ipairs(lines) do
        items[#items + 1] = { bullet = l }
      end
      items[#items + 1] = { note = "Lo verás todo en /bg." }
      BG.UI.Dialog({ title = "Novedades de BlazonGuild " .. BG.version, items = items, primary = { label = "Ver" , fn = function()
        if not (BG.window and BG.window:IsShown()) then
          BG:ToggleWindow()
        end
      end }, secondary = { label = "Cerrar" } })
    end
  end)
end)

-- Questions and answers: BlazonGuild's own, plus the guild's (organisers write them).
Store.Define("faq", { ttl = 365 * 86400, can = organiserOnly, normalize = function(d)
  local q = str(d.q, 120)
  if not q or q == "" then
    return nil
  end
  return { q = q, a = str(d.a, 500) }
end })

Board.basics = {
  { q = "¿Qué comparte el addon?", a = "Que lo usas, tu versión y lo que tú hagas en él (apuntarte, publicar un grupo, tu ficha). Lo decides en /bg privacidad." },
  { q = "¿Quién puede crear raids?", a = "Cualquier miembro. Quien la crea la dirige; el maestro y los organizadores gestionan todas." },
  { q = "¿Por qué no veo a alguien con el addon?", a = "Solo aparece quien lo tiene instalado, está conectado y ha aceptado la privacidad." },
  { q = "¿Cómo compruebo que funciona?", a = "Escribe /bg prueba: tu mensaje va a la hermandad y vuelve; si alguien más tiene el addon, te responde." },
  { q = "¿Hace falta una web o un programa aparte?", a = "No. Todo funciona dentro del juego, entre los addons de los miembros. No hay que registrarse en ningún sitio." },
  { q = "¿Cómo hablamos con otras hermandades?", a = "Con una alianza: el maestro la crea en Alianza e invita a otra hermandad; si su maestro acepta, el chat tiene una pestaña para cada una." },
  { q = "¿Para qué sirve la Sala de guerra?", a = "Para organizar escuadras y operaciones (defensas, JcJ, bandas). Los organizadores crean escuadras; ellos y los jefes de escuadra planean operaciones." },
  { q = "¿Ven los demás dónde estoy?", a = "Solo si lo activas en Mapa («Compartir mi posición»), y solo tu hermandad: te ven como un punto en su mapa y su minimapa. Está apagado hasta que lo enciendes." },
  { q = "¿Cómo llego hasta un compañero?", a = "En Mapa, pestaña «En el mapa», pulsa «Seguir» junto a su nombre: una flecha bajo el minimapa te lleva hasta él. Sirve con quien comparte su posición y con el punto de reunión." },
  { q = "¿Qué son los avistamientos?", a = "En Mapa, pestaña «Avistamientos», preguntas dónde se vio a un jugador de la otra facción. Responden los compañeros que lo aceptan, con lo que vieron en el último cuarto de hora. Nada se envía si nadie pregunta." },
  { q = "¿Cómo encuentro a alguien que me fabrique algo?", a = "En Artesanía y botín: busca el objeto y susurra al artesano o hazle un encargo. Los artesanos publican su profesión al abrirla en el juego." },
  { q = "¿Cómo doy oro a la hermandad?", a = "Dáselo a un tesorero por comercio o por correo: se apunta solo en la Tesorería. Los tesoreros los nombra el maestro." },
  { q = "¿Cómo se juega a los Huesos?", a = "En la Arena, pestaña «Taberna». Tiras seis dados, apartas los que puntúan (unos, cincos, tríos…) y decides si sigues o te plantas. Si una tirada no da nada, pierdes lo del turno. Gana quien llega a 3000." },
  { q = "¿Cómo se hace un torneo?", a = "En la Arena, pestaña «Torneos», pulsa «Nuevo». La gente se apunta; tú pulsas «Sortear y empezar» y sale el cuadro. Cada combate lo decide su duelo." },
  { q = "¿Cómo organizo los grupos de una raid?", a = "En la raid, pulsa «Grupos» y arrastra a cada uno a su grupo. Cuando la banda esté formada en el juego, «Colocar en la banda» los mueve de verdad." },
  { q = "¿Cómo veo un duelo de otros?", a = "Pon en tu objetivo a uno de los dos que se baten y escribe /bg duelo (o pulsa «Ver un duelo» en la Arena). Sale «Cara a cara» con su vida en directo y, al acabar, quién gana." },
  { q = "¿Qué hace un árbitro de la Arena?", a = "Los organizadores nombran árbitros en la Arena. Un árbitro puede decidir a mano los combates de cualquier torneo y quitar un duelo apuntado por error." },
  { q = "¿Cómo se apunta un duelo en la Arena?", a = "Solo. Al terminar un duelo entre dos de la hermandad, el juego dice quién ganó y el addon de quien pierde lo apunta. Así nadie puede darse victorias." },
  { q = "¿Cómo entra alguien en «Se busca»?", a = "Solo cuando el addon de un miembro ve que le mata alguien de la otra facción fuera de mazmorras y campos de batalla. Nadie puede apuntar a otro a mano." },
  { q = "¿Cómo encuentra alguien nuestra hermandad?", a = "Quien no tiene hermandad abre BlazonGuild, escribe vuestro nombre en Reclutamiento, ve vuestra ficha y pide entrar. Los oficiales le invitan con un clic." },
  { q = "¿Cómo se organiza algo con toda la alianza?", a = "La hermandad que lidera la alianza planea la operación en su Sala de guerra eligiendo «Toda la alianza». Llega a la Sala de guerra de cada hermandad; cada uno responde allí y el líder ve cuántos van de cada una." },
  { q = "¿Qué son las cartas de la alianza?", a = "Mensajes firmados del líder de la alianza para los maestros (y, si quiere, los capitanes). Salen en Alianza, pestaña «Cartas y avisos»; al marcarlas como leídas, el líder lo ve." },
  { q = "¿Quién manda en la alianza?", a = "Cada hermandad sigue con su maestro. La alianza tiene un líder: el maestro de la hermandad que vote más de la mitad de los maestros (si no, la fundadora)." },
  { q = "¿Funciona con mando?", a = "Sí. Con la interfaz de mando del juego, BlazonGuild no toca los menús, las placas ni el chat del juego (es lo que da problemas); su ventana, el mapa y los avisos siguen igual." },
  { q = "¿Cómo compruebo que todo funciona en mi juego?", a = "Escribe /bg autoprueba (o Administración, «Autoprueba»). Dice qué funciona aquí y qué no; con «Copiar» tienes el informe en texto para mandarlo." },
  { q = "¿En qué idioma sale el addon?", a = "En el de tu juego: español, inglés, alemán, francés, italiano, portugués o ruso. Para otro, en Administración, «Idioma del addon», o escribe /bg idioma en. Se aplica al recargar la interfaz." },
  { q = "¿Cómo sale nuestra hermandad en la clasificación de hermandades?", a = "El maestro pulsa «Publicar nuestras cifras» en Rankings, pestaña «Hermandades». Se ven al jugar en grupo con alguien de otra hermandad que use BlazonGuild. Solo cifras de la hermandad, nada de nadie en concreto." },
}

function Board.Questions()
  local out = {}
  for _, q in ipairs(Board.basics) do
    out[#out + 1] = { q = q.q, a = q.a, basic = true }
  end
  for _, r in ipairs(Store.List("faq")) do
    out[#out + 1] = { q = r.d.q, a = r.d.a, id = r.id }
  end
  return out
end
