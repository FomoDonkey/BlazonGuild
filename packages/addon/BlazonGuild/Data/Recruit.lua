-- Reclutamiento (entrega 10; Olympus' Recruit.lua, Who.lua, GuildCharter.lua, the Church files and Carry.lua,
-- MIT, our own implementation, for any guild).
--
-- The guild's public card (charter): what the guild is about, its language and raid days, the roles and
-- classes it looks for, whether it recruits. The organisers write it.
-- Joining: a player with no guild searches a guild by name with the game's own /who (one search per click, as
-- the game requires), asks one of its members with BlazonGuild for the card (RF/RG), and asks to join (RQ). The
-- member's client tells the guild (RJ over GUILD), and the organisers online see the request with "Invitar" (the
-- game's own invite, one click) and "No". The player gets an answer (RA). Nothing invites anyone by itself.
-- Recruiters: a new member says once who brought them; the guild sees who brings the most people.
-- Carry: someone who changes guild may bring their own card (about them, role, hours) from their old guild.
local _, BG = ...
local Recruit = { found = {}, requests = {}, answers = {} }
BG.Recruit = Recruit
local Store, Names, Comm = BG.Store, BG.Names, BG.Comm
local str, int = BG.Raids.Clean, BG.Raids.Int

local REQUEST_TTL = 30 * 60
local WHO_GAP = 6
local CLASSES = { "WARRIOR", "PALADIN", "HUNTER", "ROGUE", "PRIEST", "SHAMAN", "MAGE", "WARLOCK", "DRUID" }
Recruit.CLASSES = CLASSES
Recruit.CLASS_NAMES = { WARRIOR = "Guerrero", PALADIN = "Paladín", HUNTER = "Cazador", ROGUE = "Pícaro", PRIEST = "Sacerdote",
  SHAMAN = "Chamán", MAGE = "Mago", WARLOCK = "Brujo", DRUID = "Druida" }

local function classList(t)
  local out, have = {}, {}
  for _, c in ipairs(type(t) == "table" and t or {}) do
    if Recruit.CLASS_NAMES[c] and not have[c] then
      have[c] = true
      out[#out + 1] = c
    end
  end
  return out
end

local function roleSet(t)
  t = type(t) == "table" and t or {}
  return { TANK = t.TANK == true or nil, HEALER = t.HEALER == true or nil, DPS = t.DPS == true or nil }
end

local function normalizeCharter(d)
  return { open = d.open == true, about = str(d.about, 240) or "", lang = str(d.lang, 30) or "", days = str(d.days, 80) or "",
    roles = roleSet(d.roles), classes = classList(d.classes), minLevel = int(d.minLevel, 1, 60), contact = Names.Short(str(d.contact, 40)) }
end
Recruit.NormalizeCharter = normalizeCharter

-- Shared records -----------------------------------------------------------------------------------------------
Store.Define("charter", {
  can = function(author)
    return Store.IsOrganiser(author)
  end,
  normalize = normalizeCharter,
})

-- Who brought a member: written by that member once (the organisers may fix it).
Store.Define("recruits", {
  ttl = 365 * 86400,
  can = function(author, r)
    return Names.Same(r.id, author) or Store.IsOrganiser(author)
  end,
  normalize = function(d)
    return { by = Names.Short(str(d.by, 40)) }
  end,
})

function Recruit.Charter()
  local r = Store.Get("charter", "main")
  return r and not r.del and r.d or nil
end

function Recruit.SaveCharter(fields)
  if not Store.IsOrganiser(Names.Me() or "") then
    return nil, "permiso"
  end
  return Store.Put("charter", "main", fields)
end

-- Text of the roles and classes a card asks for.
function Recruit.WantsText(c)
  local parts = {}
  local roles = {}
  for _, r in ipairs({ { "TANK", "tanques" }, { "HEALER", "sanadores" }, { "DPS", "daño" } }) do
    if c.roles and c.roles[r[1]] then
      roles[#roles + 1] = r[2]
    end
  end
  if #roles > 0 then
    parts[#parts + 1] = "Buscamos " .. table.concat(roles, ", ")
  end
  local cls = {}
  for _, k in ipairs(c.classes or {}) do
    cls[#cls + 1] = Recruit.CLASS_NAMES[k]
  end
  if #cls > 0 then
    parts[#parts + 1] = (#roles > 0 and "sobre todo " or "Buscamos ") .. table.concat(cls, ", ")
  end
  if c.minLevel then
    parts[#parts + 1] = "desde el nivel " .. c.minLevel
  end
  return #parts > 0 and (table.concat(parts, "; ") .. ".") or "Cualquiera es bienvenido."
end

-- Organisers online with BlazonGuild (who may invite), the card's contact first.
local function contacts()
  local out, have = {}, {}
  local c = Recruit.Charter()
  local function add(n)
    if n and not have[n] and #out < 3 then
      have[n] = true
      out[#out + 1] = n
    end
  end
  if c and c.contact and BG.Guild.Find(c.contact) and BG.Guild.Find(c.contact).online then
    add(c.contact)
  end
  for _, p in ipairs(BG.Peers.Active()) do
    if Store.IsOrganiser(p.name) then
      add(p.name)
    end
  end
  return out
end

-- Searching with /who (players with no guild, or anyone) ----------------------------------------------------------
local whoAt, whoFor = -math.huge, nil

function Recruit.CanSearch()
  return GetTime() - whoAt >= WHO_GAP
end

-- One search, from the player's click (the game takes /who only from a click). Results come with WHO_LIST_UPDATE.
function Recruit.Search(guildName)
  guildName = str(guildName, 40)
  if not guildName or guildName == "" then
    return nil, "nombre"
  end
  if not Recruit.CanSearch() then
    return nil, "espera"
  end
  whoAt, whoFor = GetTime(), guildName
  Recruit.searched, Recruit.found, Recruit.card = guildName, {}, nil
  local query = 'g-"' .. guildName .. '"'
  if C_FriendList and C_FriendList.SetWhoToUi then
    pcall(C_FriendList.SetWhoToUi, true)
  elseif SetWhoToUI then
    pcall(SetWhoToUI, 1)
  end
  if C_FriendList and C_FriendList.SendWho then
    C_FriendList.SendWho(query)
  elseif SendWho then
    SendWho(query)
  else
    return nil, "sin who"
  end
  BG:Fire("BG_RECRUIT_CHANGED")
  return true
end

local function whoRow(i)
  if C_FriendList and C_FriendList.GetWhoInfo then
    local w = C_FriendList.GetWhoInfo(i)
    if w then
      return w.fullName, w.fullGuildName, w.level, w.filename
    end
  elseif GetWhoInfo then
    local name, guild, level, _, _, _, file = GetWhoInfo(i)
    return name, guild, level, file
  end
end

BG:On("WHO_LIST_UPDATE", function()
  if not whoFor then
    return
  end
  local total = 0
  if C_FriendList and C_FriendList.GetNumWhoResults then
    total = C_FriendList.GetNumWhoResults() or 0
  elseif GetNumWhoResults then
    total = GetNumWhoResults() or 0
  end
  local found = {}
  for i = 1, math.min(50, total) do
    local name, guild, level, file = whoRow(i)
    if name and guild and guild:lower() == whoFor:lower() then
      found[#found + 1] = { name = Names.Short(name), level = level, class = file, guild = guild }
    end
  end
  Recruit.found = found
  whoFor = nil
  BG:Fire("BG_RECRUIT_CHANGED")
end)

-- Asking a member for their guild's card (they answer if they have BlazonGuild).
function Recruit.AskCard(name)
  Recruit.cardAsked = Names.Short(name)
  return Comm.Send("RF", {}, "WHISPER", name, { lane = "alert" })
end

Comm.Register("RF", function(sender)
  local info = BG.Guild.info
  if not info then
    return
  end
  local c = Recruit.Charter()
  local s = BG.Guild.stats
  Comm.Send("RG", { g = info.name, c = c or {}, has = c ~= nil, n = s and s.total or 0, on = s and s.online or 0, k = contacts() }, "WHISPER", sender, { lane = "normal" })
end, { channels = { "WHISPER" }, maxBytes = 20 })

Comm.Register("RG", function(sender, b)
  if type(b) ~= "table" or type(b.g) ~= "string" then
    return
  end
  local k = {}
  for i = 1, math.min(3, #(type(b.k) == "table" and b.k or {})) do
    local n = Names.Short(str(b.k[i], 40))
    if n then
      k[#k + 1] = n
    end
  end
  Recruit.card = { guild = str(b.g, 40), from = Names.Short(sender), has = b.has == true, charter = normalizeCharter(type(b.c) == "table" and b.c or {}),
    total = int(b.n, 0, 1000) or 0, online = int(b.on, 0, 1000) or 0, contacts = k }
  BG:Fire("BG_RECRUIT_CHANGED")
end, { channels = { "WHISPER" }, maxBytes = 1200 })

-- Asking to join: to an organiser the card named, else to the member who answered, else to anyone found.
function Recruit.AskToJoin(note)
  local card = Recruit.card
  local target = card and (card.contacts[1] or card.from) or (Recruit.found[1] and Recruit.found[1].name)
  if not target then
    return nil, "nadie"
  end
  local _, classFile = UnitClass and UnitClass("player")
  Recruit.asked = { to = target, guild = card and card.guild or Recruit.searched, at = GetTime() }
  Comm.Send("RQ", { g = card and card.guild or Recruit.searched, l = UnitLevel and UnitLevel("player") or nil, c = classFile, n = str(note, 140) }, "WHISPER", target, { lane = "alert" })
  BG:Fire("BG_RECRUIT_CHANGED")
  return target
end

local heardRequest -- (below: a request the guild heard, into the organisers' tray)

-- A request reached us: the whole guild hears it (RJ), and the player hears that it arrived (RA).
Comm.Register("RQ", function(sender, b)
  local info = BG.Guild.info
  if type(b) ~= "table" or not info then
    return
  end
  if BG.Guild.Find(sender) then
    return -- (already one of us)
  end
  local c = Recruit.Charter()
  Comm.Send("RA", { s = (c and not c.open) and "closed" or "sent" }, "WHISPER", sender, { lane = "alert" })
  local rj = { p = Names.Short(sender), l = int(b.l, 1, 60), c = str(b.c, 12), n = str(b.n, 140) }
  Comm.Send("RJ", rj, "GUILD", nil, { lane = "alert" })
  heardRequest(Names.Me(), rj) -- (our own GUILD message does not come back to us: our tray hears it here)
end, { channels = { "WHISPER" }, maxBytes = 400 })

function heardRequest(sender, b)
  local p = Names.Short(str(b.p, 40))
  if not p or BG.Guild.Find(p) then
    return
  end
  local fresh = not Recruit.requests[p]
  Recruit.requests[p] = { name = p, level = int(b.l, 1, 60), class = str(b.c, 12), note = str(b.n, 140), via = sender, at = GetTime() }
  if fresh and Store.IsOrganiser(Names.Me() or "") then
    BG:Notify("Quiere entrar en la hermandad", p .. (b.l and (" (nivel " .. b.l .. ")") or "") .. " pide entrar. Ábrelo en Reclutamiento para invitarle.",
      { kind = "info", view = "recruit", sound = "READY_CHECK" })
  end
  BG:Fire("BG_RECRUIT_CHANGED")
end

Comm.Register("RJ", function(sender, b)
  if type(b) == "table" and BG.Guild.Find(sender) then
    heardRequest(sender, b)
  end
end, { channels = { "GUILD" }, maxBytes = 400 })

Comm.Register("RA", function(sender, b)
  if type(b) ~= "table" or not Recruit.asked then
    return
  end
  Recruit.answers[Names.Short(sender)] = b.s
  if b.s == "closed" then
    BG:Notify("Petición entregada", (Recruit.asked.guild or "La hermandad") .. " no está reclutando ahora, pero sus oficiales verán tu petición.", { kind = "info", view = "recruit" })
  elseif b.s == "no" then
    BG:Notify("Ahora no", (Recruit.asked.guild or "La hermandad") .. " no puede invitarte ahora.", { kind = "warning", view = "recruit" })
  else
    BG:Notify("Petición entregada", "Los oficiales de " .. (Recruit.asked.guild or "la hermandad") .. " ya la ven. Te invitarán desde el juego si dicen que sí.", { kind = "success", view = "recruit" })
  end
  BG:Fire("BG_RECRUIT_CHANGED")
end, { channels = { "WHISPER" }, maxBytes = 40 })

function Recruit.Requests()
  local out, t = {}, GetTime()
  for name, r in pairs(Recruit.requests) do
    if t - r.at > REQUEST_TTL or BG.Guild.Find(name) then
      Recruit.requests[name] = nil
    else
      out[#out + 1] = r
    end
  end
  table.sort(out, function(a, b)
    return a.at < b.at
  end)
  return out
end

-- An organiser's answer (a click): the game's own invite, or a no.
function Recruit.Answer(name, yes)
  if not Store.IsOrganiser(Names.Me() or "") then
    return nil, "permiso"
  end
  local r = Recruit.requests[name]
  if not r then
    return nil, "no existe"
  end
  Recruit.requests[name] = nil
  if yes then
    local invite = (C_GuildInfo and C_GuildInfo.Invite) or GuildInvite
    if invite and BG.InGame() then
      invite(name)
    end
  else
    Comm.Send("RA", { s = "no" }, "WHISPER", name, { lane = "alert" })
  end
  Comm.Send("RK", { p = name }, "GUILD", nil, { lane = "normal" }) -- (the other organisers' trays let it go)
  BG:Fire("BG_RECRUIT_CHANGED")
  return true
end

Comm.Register("RK", function(sender, b)
  if type(b) == "table" and Store.IsOrganiser(sender) then
    Recruit.requests[Names.Short(str(b.p, 40)) or ""] = nil
    BG:Fire("BG_RECRUIT_CHANGED")
  end
end, { channels = { "GUILD" }, maxBytes = 80 })

-- Recruiters --------------------------------------------------------------------------------------------------------
function Recruit.WhoBrought(name)
  local r = Store.Get("recruits", Names.Short(name) or "")
  return r and not r.del and r.d.by or nil, r ~= nil
end

function Recruit.SetBroughtBy(by)
  local me = Names.Me()
  if not me then
    return nil, "sin personaje"
  end
  local m = by and by ~= "" and BG.Guild.Find(by)
  if by and by ~= "" and not m then
    return nil, "no es de tu hermandad"
  end
  if m and Names.Same(m.name, me) then
    return nil, "tú mismo"
  end
  return Store.Put("recruits", me, { by = m and Names.Short(m.name) or nil })
end

-- Who brought the most people in the last `days` days (180 by default).
function Recruit.Recruiters(limit, days)
  local since = Store.Now() - (days or 180) * 86400
  local count, order = {}, {}
  for _, r in ipairs(Store.List("recruits", function(x)
    return x.d.by ~= nil and x.at >= since
  end)) do
    if not count[r.d.by] then
      count[r.d.by] = 0
      order[#order + 1] = r.d.by
    end
    count[r.d.by] = count[r.d.by] + 1
  end
  table.sort(order, function(a, b)
    if count[a] ~= count[b] then
      return count[a] > count[b]
    end
    return a < b
  end)
  local out = {}
  for i = 1, math.min(limit or 10, #order) do
    out[i] = { name = order[i], n = count[order[i]] }
  end
  return out
end

-- Carry: our card in another guild of this account (the newest), to bring here.
function Recruit.CardElsewhere()
  local me, here = Names.Me(), BG.Guild.info and BG.Guild.info.home
  if not me or not here then
    return nil
  end
  local best
  for key, g in pairs(BG.db.guilds or {}) do
    local r = key ~= here and type(g) == "table" and g.store and g.store.profiles and g.store.profiles[me]
    if r and not r.del and r.d and (r.d.bio or r.d.role or r.d.hours) and (not best or r.at > best.at) then
      best = { at = r.at, d = r.d, guild = (g.info and g.info.name) or key:match("([^|]+)$") or key }
    end
  end
  return best
end

function Recruit.BringCard()
  local old = Recruit.CardElsewhere()
  if not old then
    return nil, "no hay"
  end
  return BG.People.Publish({ bio = old.d.bio, role = old.d.role, hours = old.d.hours })
end

-- A member who just joined (no card here, but one elsewhere; or never said who brought them): asked once.
local askedThisSession = false
BG:On("BG_ROSTER_UPDATED", function()
  if askedThisSession or not BG.Guild.info or BG.Guild.fromCache or not BG.Consent.Accepted() then
    return
  end
  askedThisSession = true
  C_Timer.After(8, function()
    local me = Names.Me()
    if not me then
      return
    end
    local old = Recruit.CardElsewhere()
    if old and not BG.People.Profile(me) then
      BG.UI.Dialog({
        title = "¿Traer tu ficha?",
        items = { "Tenías una ficha en " .. old.guild .. " (tu presentación, tu rol, cuándo juegas).", { bullet = "¿La traes a " .. BG.Guild.info.name .. "?" } },
        primary = { label = "Traerla", fn = function()
          Recruit.BringCard()
        end },
        secondary = { label = "No" },
      })
    end
  end)
end)

BG.commands = BG.commands or {}
BG.commands.reclutar = function()
  if not (BG.window and BG.window:IsShown()) then
    BG:ToggleWindow()
  end
  BG:ShowView("recruit")
end
