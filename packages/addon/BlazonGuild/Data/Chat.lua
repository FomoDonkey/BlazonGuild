-- The guild's chat inside BlazonGuild: the game's guild and officer chat shown in our window, plus rooms
-- (Sanadores, Tanques, Comercio… and any a member creates) carried by addon messages over GUILD. With sister
-- guilds (Alliance.lua) the built-in rooms are shared with them, and the alliance has its own tabs.
-- Moderation, done by the guild's organisers: delete a room message, mute for 5 min to 7 days, three warnings
-- open a case the guild master decides (nobody is ever removed automatically), word filters, reports to the
-- officers, and — only for players who agree — a sanction that reaches every character of the same
-- BattleTag (the BattleTag goes to the organisers alone, never to the whole guild).
-- Ideas from Olympus's Channels, ChatRooms, ChatMarks, Filter, WatchChat, ChatStrikes, Watch, Judgment,
-- JusticeTasks, TagFollow and Cover (MIT); our own implementation.
local _, BG = ...
local Chat = {}
BG.Chat = Chat
local Store, Names, Comm = BG.Store, BG.Names, BG.Comm
local str = BG.Raids.Clean

local KEEP = 150 -- lines kept per channel
local MUTE_STEPS = { 300, 1800, 3600, 86400, 7 * 86400 }
Chat.MUTE_STEPS = MUTE_STEPS
local ROOM_RATE = 1.2 -- seconds between two lines of ours in rooms

-- Built-in rooms: everyone sees them; anyone can talk unless muted.
Chat.builtin = {
  { id = "healers", name = "Sanadores", desc = "Para quien cura: asignaciones, maná, consejos." },
  { id = "tanks", name = "Tanques", desc = "Para quien tanquea: marcas, agarres y rutas." },
  { id = "dps", name = "Daño", desc = "Para quien hace daño: rotaciones, equipo y amenaza." },
  { id = "trade", name = "Comercio y artesanía", desc = "Pide, ofrece y encarga a los artesanos de la hermandad." },
  { id = "help", name = "Ayuda", desc = "Preguntas de los nuevos: aquí nadie se ríe de nadie." },
}

BG.Consent.Register({ key = "battletag", label = "Compartir mi BattleTag solo con los organizadores, para que una sanción alcance a todos mis personajes" })

-- Shared records --------------------------------------------------------------------------------------
Store.Define("rooms", {
  ttl = 30 * 86400,
  can = function(author, r, old)
    local prefix = author:gsub("%s", "") .. "-"
    return Store.IsOrganiser(author) or r.id:sub(1, #prefix) == prefix
  end,
  normalize = function(d)
    local name = str(d.name, 32)
    if not name or name == "" then
      return nil
    end
    return { name = name, desc = str(d.desc, 120) }
  end,
})

-- Moderation records: only organisers write them.
local function organiserOnly(author)
  return Store.IsOrganiser(author)
end

Store.Define("chatdel", { ttl = 7 * 86400, can = organiserOnly, normalize = function(d)
  return type(d.room) == "string" and { room = str(d.room, 40) } or nil
end })

Store.Define("mutes", { ttl = function(r)
  return (r.d and r.d["until"] or r.at) + 86400
end, can = organiserOnly, normalize = function(d)
  local untilT = tonumber(d["until"])
  return untilT and { ["until"] = math.floor(untilT), reason = str(d.reason, 120) } or nil
end })

Store.Define("strikes", { ttl = 90 * 86400, private = true, can = organiserOnly, normalize = function(d)
  local list = {}
  for i = 1, math.min(10, #(type(d.list) == "table" and d.list or {})) do
    local s = d.list[i]
    if type(s) == "table" and tonumber(s.at) then
      list[#list + 1] = { at = math.floor(s.at), reason = str(s.reason, 120) }
    end
  end
  return { list = list }
end })

Store.Define("filter", { ttl = 365 * 86400, can = organiserOnly, normalize = function(d)
  local words = {}
  for i = 1, math.min(80, #(type(d.words) == "table" and d.words or {})) do
    local w = str(d.words[i], 30)
    if w and w ~= "" then
      words[#words + 1] = w:lower()
    end
  end
  return { words = words }
end })

-- A case: what happened, the evidence (quoted lines), the organisers' opinions and the master's decision.
Store.Define("cases", { ttl = 120 * 86400, private = true, can = function(author, r, old)
  if not Store.IsOrganiser(author) then
    return false
  end
  if old and old.d and old.d.status == "DECIDED" then
    return false -- a decision is final
  end
  if r.d and r.d.status == "DECIDED" then
    return Store.IsMaster(author)
  end
  return true
end, normalize = function(d)
  local target = Names.Short(str(d.target, 40))
  if not target then
    return nil
  end
  local evidence, votes = {}, {}
  for i = 1, math.min(5, #(type(d.evidence) == "table" and d.evidence or {})) do
    evidence[#evidence + 1] = str(d.evidence[i], 200)
  end
  local n = 0
  for name, v in pairs(type(d.votes) == "table" and d.votes or {}) do
    n = n + 1
    if n > 20 then
      break
    end
    local short = Names.Short(str(name, 40))
    if short and (v == "KICK" or v == "WARN" or v == "NOTHING") then
      votes[short] = v
    end
  end
  local decision = (d.decision == "KICK" or d.decision == "WARN" or d.decision == "NOTHING") and d.decision or nil
  return { target = target, reason = str(d.reason, 200), evidence = evidence, votes = votes,
    status = decision and "DECIDED" or "OPEN", decision = decision }
end })

-- History --------------------------------------------------------------------------------------------
local function guildEntry()
  local g = BG.Guild.Entry()
  if g then
    g.chat = g.chat or {}
  end
  return g
end

function Chat.History(channel)
  local g = guildEntry()
  if not g then
    return {}
  end
  g.chat[channel] = g.chat[channel] or {}
  return g.chat[channel]
end

Chat.unread = {}
Chat.viewing = nil

local function add(channel, line)
  local h = Chat.History(channel)
  h[#h + 1] = line
  while #h > KEEP do
    table.remove(h, 1)
  end
  if Chat.viewing ~= channel then
    Chat.unread[channel] = (Chat.unread[channel] or 0) + 1
  end
  BG:Fire("BG_CHAT_LINE", channel, line)
end
Chat.Add = add

-- Text a player sent, made safe to show: item, spell, quest and achievement links stay; other escape codes
-- (textures, colours without a link, protected strings) go. Pure; tested offline.
function Chat.Sanitize(text)
  if type(text) ~= "string" then
    return ""
  end
  text = text:gsub("[%c]", " ")
  local links = {}
  local KINDS = { item = true, spell = true, quest = true, achievement = true, enchant = true }
  -- A link's colour is eight hex digits ("|cff1eff00") or, in newer clients, a named one ("|cnIQ3:" = quality 3).
  text = text:gsub("|c([^|]-)|H(%a+):([^|]*)|h(%[[^|%]]*%])|h|r", function(color, kind, data, label)
    local okColor = color:match("^%x%x%x%x%x%x%x%x$") or color:match("^n[%w_]+:$")
    if okColor and KINDS[kind] then
      links[#links + 1] = "|c" .. color .. "|H" .. kind .. ":" .. data .. "|h" .. label .. "|h|r"
      return "\001" .. #links .. "\002"
    end
    return label
  end)
  text = text:gsub("|H(%a+):([^|]*)|h(%[[^|%]]*%])|h", function(kind, data, label)
    if KINDS[kind] then
      links[#links + 1] = "|H" .. kind .. ":" .. data .. "|h" .. label .. "|h"
      return "\001" .. #links .. "\002"
    end
    return label
  end)
  text = text:gsub("|", "/")
  text = text:gsub("\001(%d+)\002", function(i)
    return links[tonumber(i)] or ""
  end)
  if #text > 255 then
    text = text:sub(1, 255)
  end
  return text
end

-- Filters: the guild's common words (organisers) plus the player's own; matches show as asterisks.
function Chat.FilterWords()
  local out = {}
  local common = Store.Get("filter", "guild")
  for _, w in ipairs(common and not common.del and common.d.words or {}) do
    out[#out + 1] = w
  end
  for _, w in ipairs(BG.db.settings.myFilter or {}) do
    out[#out + 1] = w
  end
  return out
end

function Chat.ApplyFilter(text, words)
  for _, w in ipairs(words or Chat.FilterWords()) do
    local pattern = w:gsub("([%^%$%(%)%%%.%[%]%*%+%-%?])", "%%%1")
    local lower = text:lower()
    local s, e = lower:find(pattern)
    local guard = 0
    while s and guard < 20 do
      text = text:sub(1, s - 1) .. string.rep("*", e - s + 1) .. text:sub(e + 1)
      lower = text:lower()
      s, e = lower:find(pattern, e + 1)
      guard = guard + 1
    end
  end
  return text
end

-- Mutes --------------------------------------------------------------------------------------------
function Chat.MutedUntil(name)
  local r = Store.Get("mutes", Names.Short(name) or "")
  if r and not r.del and r.d["until"] > Store.Now() then
    return r.d["until"]
  end
  return nil
end

function Chat.Hidden(name)
  local list = BG.db.settings.hidden
  return list ~= nil and list[Names.Short(name) or ""] == true
end

function Chat.SetHidden(name, on)
  BG.db.settings.hidden = BG.db.settings.hidden or {}
  BG.db.settings.hidden[Names.Short(name)] = on and true or nil
  BG:Fire("BG_CHAT_REDRAW")
end

-- Rooms ----------------------------------------------------------------------------------------------
function Chat.Rooms()
  local out = {}
  for _, r in ipairs(Chat.builtin) do
    out[#out + 1] = { id = r.id, name = r.name, desc = r.desc, builtin = true }
  end
  local custom = Store.List("rooms")
  table.sort(custom, function(a, b)
    return a.d.name < b.d.name
  end)
  for _, r in ipairs(custom) do
    out[#out + 1] = { id = r.id, name = r.d.name, desc = r.d.desc, by = r.by }
  end
  -- (a room for each tournament or fight night of the Arena, ArenaFace.lua)
  for _, r in ipairs(BG.ArenaFace and BG.ArenaFace.EventRooms() or {}) do
    out[#out + 1] = r
  end
  return out
end

function Chat.CreateRoom(name, desc)
  local me = Names.Me()
  if not me then
    return nil, "sin personaje"
  end
  return Store.Put("rooms", me:gsub("%s", "") .. "-" .. Store.Now(), { name = name, desc = desc })
end

local lastSent = -math.huge
local msgSeq = 0

-- Sends a line to a channel: "guild", "officer" (the game's own chats) or a room id. Must run inside the
-- player's key press or click (the game's rule for chat). Returns true or false and a reason to show.
function Chat.Send(channel, text)
  text = Chat.Sanitize(text)
  if text:gsub("%s", "") == "" then
    return false, "vacío"
  end
  if channel == "guild" or channel == "officer" then
    if not BG.InGame() then
      return false, "capturas"
    end
    local send = (C_ChatInfo and C_ChatInfo.SendChatMessage) or SendChatMessage
    local ok = pcall(send, text, channel == "guild" and "GUILD" or "OFFICER")
    return ok, ok and nil or "el juego no lo envió"
  end
  if not BG.Consent.Accepted() then
    return false, "consent"
  end
  local me = Names.Me()
  local untilT = Chat.MutedUntil(me)
  if untilT then
    return false, "silenciado hasta las " .. BG.UI.FormatTime(untilT)
  end
  if GetTime() - lastSent < ROOM_RATE then
    return false, "despacio"
  end
  lastSent = GetTime()
  -- A squad's chat goes by whisper to its members (War.lua).
  if BG.War and BG.War.IsChannel(channel) then
    local ok, why = BG.War.SquadSend(channel, text)
    return ok, not ok and why or nil
  end
  -- The alliance's tabs, and the role rooms once there are sister guilds to share them with (Alliance.lua).
  if BG.Alliance and BG.Alliance.Handles(channel) then
    local ok, why = BG.Alliance.Send(channel, text)
    return ok, not ok and why or nil
  end
  msgSeq = msgSeq + 1
  local id = (me or "?"):gsub("%s", "") .. "-" .. Store.Now() .. "-" .. msgSeq
  local ok, why = Comm.Send("CM", { r = channel, t = text, i = id }, "GUILD", nil, { lane = "alert" })
  if ok then
    local m = BG.Guild.me
    add(channel, { at = Store.Now(), from = me, text = text, id = id, class = m and m.classFile })
  end
  return ok, why
end

local heardRate = {}
Comm.Register("CM", function(sender, body)
  if type(body) ~= "table" or type(body.r) ~= "string" or #body.r > 40 or type(body.t) ~= "string" then
    return
  end
  local m = BG.Guild.Find(sender)
  if not m then
    return
  end
  -- (A flood from one sender is dropped: at most 8 lines in 10 seconds.)
  local t = GetTime()
  local rate = heardRate[sender] or { start = t, n = 0 }
  if t - rate.start > 10 then
    rate.start, rate.n = t, 0
  end
  rate.n = rate.n + 1
  heardRate[sender] = rate
  if rate.n > 8 or Chat.MutedUntil(sender) then
    return
  end
  add(body.r, { at = Store.Now(), from = sender, text = Chat.Sanitize(body.t), id = str(body.i, 80), class = m.classFile })
end, { maxBytes = 600 })

-- The game's own chats, kept in our history too (guild and officer).
local function gameLine(channel)
  return function(text, author, _, _, _, _, _, _, _, _, lineID, guid)
    if issecretvalue and (issecretvalue(text) or issecretvalue(author)) then
      return
    end
    local name = Names.Short(author)
    local m = name and BG.Guild.Find(name)
    -- (the game's line number starts again every session: with the time it is unique)
    add(channel, { at = Store.Now(), from = name or "?", text = Chat.Sanitize(text), class = m and m.classFile, game = true,
      id = "g" .. Store.Now() .. "-" .. tostring(lineID or math.random(1, 1e6)) })
  end
end

-- Lines saved by 0.10.0 and before with their links broken ("|" written as "/"): put back, once.
function Chat.RepairLinks(text)
  if type(text) ~= "string" or not text:find("/H", 1, true) then
    return text
  end
  local fixed = text:gsub("/c([^/]-)/H(%a+):([^/]*)/h(%[[^/%]]*%])/h/r", "|c%1|H%2:%3|h%4|h|r")
  return Chat.Sanitize(fixed)
end

BG:On("BG_READY", function()
  for _, g in pairs(BG.db.guilds or {}) do
    if type(g) == "table" and type(g.chat) == "table" and not g.linksRepaired then
      g.linksRepaired = true
      for _, list in pairs(g.chat) do
        for _, line in ipairs(list) do
          if line.game then
            line.text = Chat.RepairLinks(line.text)
          end
        end
      end
    end
  end
end)

-- What was said in guild chat while we were away: a guildmate with BlazonGuild who was online passes it on
-- (the game gives no history). We ask one of them once per session, for the lines since we last saw the chat.
local MISSED_MAX = 40
local askedMissed = false

local function lastSeenChat()
  local h = Chat.History("guild")
  local last = h[#h]
  local g = guildEntry()
  return math.max(last and last.at or 0, g and g.chatSeenAt or 0)
end

BG:On("PLAYER_LOGOUT", function()
  local g = guildEntry()
  if g then
    g.chatSeenAt = Store.Now()
  end
end)

local function askMissed()
  if askedMissed or not BG.Consent.Accepted() or not BG.Guild.info then
    return
  end
  local since = lastSeenChat()
  local peers = {}
  for _, p in ipairs(BG.Peers.Active()) do
    if not p.me and #peers < 3 then -- (three: one of them was surely online; repeated lines are merged)
      peers[#peers + 1] = p.name
    end
  end
  if #peers == 0 then
    return
  end
  askedMissed = true
  for _, peer in ipairs(peers) do
    Comm.Send("GQ", { s = since > 0 and since or (Store.Now() - 6 * 3600) }, "WHISPER", peer, { lane = "bulk" })
  end
end

BG:On("BG_PEERS_CHANGED", function()
  C_Timer.After(5, askMissed)
end)

Comm.Register("GQ", function(sender, b)
  if type(b) ~= "table" or not BG.Consent.Accepted() or not BG.Guild.Find(sender) then
    return
  end
  local since = tonumber(b.s) or 0
  local out = {}
  local h = Chat.History("guild")
  for i = #h, 1, -1 do
    local l = h[i]
    if l.at <= since or #out >= MISSED_MAX then
      break
    end
    if l.game and not Chat.Deleted(l.id) then
      table.insert(out, 1, { a = l.at, f = l.from, t = l.text, c = l.class })
    end
  end
  if #out > 0 then
    Comm.Send("GA", { l = out }, "WHISPER", sender, { lane = "bulk" })
  end
end, { channels = { "WHISPER" }, maxBytes = 60 })

Comm.Register("GA", function(sender, b)
  if type(b) ~= "table" or type(b.l) ~= "table" or not BG.Guild.Find(sender) then
    return
  end
  local h = Chat.History("guild")
  local added = 0
  for i = 1, math.min(MISSED_MAX, #b.l) do
    local x = b.l[i]
    local at, from, text = type(x) == "table" and tonumber(x.a), type(x) == "table" and Names.Short(str(x.f, 40)), type(x) == "table" and x.t
    if at and from and type(text) == "string" then
      text = Chat.Sanitize(text)
      local dup = false
      for _, l in ipairs(h) do
        if l.from == from and l.text == text and math.abs(l.at - at) <= 10 then
          dup = true
          break
        end
      end
      if not dup then
        h[#h + 1] = { at = math.floor(at), from = from, text = text, class = str(x.c, 12), game = true, id = "g" .. math.floor(at) .. "-p" .. i, via = sender }
        added = added + 1
      end
    end
  end
  if added > 0 then
    table.sort(h, function(a, c)
      return a.at < c.at
    end)
    while #h > KEEP do
      table.remove(h, 1)
    end
    BG:Fire("BG_CHAT_REDRAW")
  end
end, { channels = { "WHISPER" }, maxBytes = 9000 })
BG:On("CHAT_MSG_GUILD", gameLine("guild"))
BG:On("CHAT_MSG_OFFICER", function(...)
  Chat.officerSeen = true
  gameLine("officer")(...)
end)

function Chat.CanOfficer()
  if Chat.officerSeen then
    return true
  end
  local me = Names.Me()
  return me ~= nil and Store.IsOrganiser(me)
end

-- Moderation ----------------------------------------------------------------------------------------
function Chat.IsModerator()
  local me = Names.Me()
  return me ~= nil and Store.IsOrganiser(me)
end

function Chat.Deleted(id)
  local r = id and Store.Get("chatdel", id)
  return r ~= nil and not r.del
end

function Chat.Delete(room, id)
  return Store.Put("chatdel", id, { room = room }, { lane = "alert" })
end

-- What an organiser's addon keeps for its own guild only (an alt of theirs in another guild never sees it): the
-- reports members sent them and the BattleTags members agreed to share.
local function kept(field)
  local g = BG.Guild.Entry()
  if not g then
    return {}
  end
  g[field] = g[field] or {}
  return g[field]
end
function Chat.Reports()
  return kept("reports")
end
function Chat.Tags()
  return kept("tags")
end

-- Names that share `name`'s BattleTag, as this organiser's addon knows them (players who agreed to share).
function Chat.SameTag(name)
  local tags = Chat.Tags()
  local short = Names.Short(name)
  local tag = tags[short]
  local out = { short }
  if tag then
    for other, t in pairs(tags) do
      if t == tag and other ~= short then
        out[#out + 1] = other
      end
    end
  end
  return out
end

-- Mutes a player (and the characters of the same BattleTag) for MUTE_STEPS[step] seconds, adds a warning,
-- and opens a case at the third. Returns the names muted.
function Chat.Mute(name, step, reason)
  local seconds = MUTE_STEPS[step] or MUTE_STEPS[1]
  local untilT = Store.Now() + seconds
  local muted = {}
  for _, who in ipairs(Chat.SameTag(name)) do
    if Store.Put("mutes", who, { ["until"] = untilT, reason = reason }, { lane = "alert" }) then
      muted[#muted + 1] = who
    end
  end
  local short = Names.Short(name)
  if not BG.Guild.Find(short) then
    return muted, 0 -- someone from a sister guild: muted here, but warnings and cases are for our own members
  end
  local old = Store.Get("strikes", short)
  local list = {}
  for _, s in ipairs(old and not old.del and old.d.list or {}) do
    list[#list + 1] = s
  end
  list[#list + 1] = { at = Store.Now(), reason = reason }
  Store.Put("strikes", short, { list = list })
  if #list >= 3 then
    Chat.OpenCase(short, "Tercer aviso: " .. (reason or "sin motivo escrito"), {})
  end
  return muted, #list
end

function Chat.Unmute(name)
  return Store.Put("mutes", Names.Short(name), { ["until"] = Store.Now() - 1, reason = "levantado" })
end

function Chat.Strikes(name)
  local r = Store.Get("strikes", Names.Short(name) or "")
  return r and not r.del and #r.d.list or 0
end

function Chat.OpenCase(target, reason, evidence)
  local id = Names.Short(target):gsub("%s", "") .. "-" .. Store.Now()
  return Store.Put("cases", id, { target = target, reason = reason, evidence = evidence, votes = {} }, { lane = "alert" })
end

function Chat.Cases()
  local list = Store.List("cases")
  table.sort(list, function(a, b)
    if (a.d.status == "OPEN") ~= (b.d.status == "OPEN") then
      return a.d.status == "OPEN"
    end
    return a.at > b.at
  end)
  return list
end

local function editCase(id, fn)
  local c = Store.Get("cases", id)
  if not c or c.del then
    return nil, "no existe"
  end
  local d = { target = c.d.target, reason = c.d.reason, evidence = c.d.evidence, votes = {}, decision = c.d.decision }
  for k, v in pairs(c.d.votes) do
    d.votes[k] = v
  end
  fn(d)
  return Store.Put("cases", id, d, { lane = "alert" })
end

function Chat.Vote(id, vote)
  return editCase(id, function(d)
    d.votes[Names.Me()] = vote
  end)
end

-- Only the guild master closes a case. Removing someone from the guild stays the master's own action in
-- the game's guild window: the addon never removes anyone.
function Chat.Decide(id, decision)
  return editCase(id, function(d)
    d.decision = decision
  end)
end

-- Reports: any member sends a line to the organisers online (whisper; members cannot write to OFFICER).
function Chat.Report(line, channel, why)
  local sent = 0
  for _, p in ipairs(BG.Peers.Active()) do
    if not p.me and Store.IsOrganiser(p.name) then
      if Comm.Send("RP", { who = line.from, t = str(line.text, 200), c = channel, w = str(why, 120) }, "WHISPER", p.name, { lane = "normal" }) then
        sent = sent + 1
      end
    end
  end
  return sent
end

local reportsFrom = {} -- name -> { GetTime() of their latest reports }
Comm.Register("RP", function(sender, body)
  if not Chat.IsModerator() or type(body) ~= "table" or not BG.Guild.Find(sender) then
    return -- (only a member of ours reports to us)
  end
  local t, recent = GetTime(), {}
  for _, at in ipairs(reportsFrom[sender] or {}) do
    if t - at < 600 then
      recent[#recent + 1] = at
    end
  end
  if #recent >= 5 then
    return -- five in ten minutes is enough from one person
  end
  recent[#recent + 1] = t
  reportsFrom[sender] = recent
  local reports = Chat.Reports()
  table.insert(reports, 1, { at = Store.Now(), by = sender, who = Names.Short(str(body.who, 40)), text = str(body.t, 200), channel = str(body.c, 40), why = str(body.w, 120) })
  while #reports > 50 do
    table.remove(reports)
  end
  BG:Notify("Denuncia nueva", sender .. " denuncia un mensaje de " .. tostring(body.who) .. ".", { kind = "warning", view = "chat" })
  BG:Fire("BG_CHAT_REDRAW")
end, { channels = { "WHISPER" }, maxBytes = 600 })

-- BattleTags: with the player's yes, their client tells the organisers online (whisper, never the guild).
local function myTag()
  if not BNGetInfo then
    return nil
  end
  local ok, _, tag = pcall(BNGetInfo)
  if ok and type(tag) == "string" and tag ~= "" and not (issecretvalue and issecretvalue(tag)) then
    return tag
  end
  return nil
end

function Chat.ShareTag()
  if not BG.Consent.Line("battletag") then
    return 0
  end
  local tag = myTag()
  if not tag then
    return 0
  end
  local n = 0
  for _, p in ipairs(BG.Peers.Active()) do
    if not p.me and Store.IsOrganiser(p.name) then
      if Comm.Send("BT", { t = tag }, "WHISPER", p.name, { lane = "bulk", key = "BT:" .. p.name }) then
        n = n + 1
      end
    end
  end
  return n
end

Comm.Register("BT", function(sender, body)
  if not Chat.IsModerator() or type(body) ~= "table" or type(body.t) ~= "string" or #body.t > 40 or not BG.Guild.Find(sender) then
    return
  end
  Chat.Tags()[sender] = body.t
end, { channels = { "WHISPER" }, maxBytes = 80 })

BG:On("BG_PEERS_CHANGED", function()
  if BG.Consent.Line("battletag") then
    Chat.ShareTag()
  end
end)
BG:On("BG_CONSENT_LINE", function(key, on)
  if key == "battletag" and on then
    Chat.ShareTag()
  end
end)

-- Unread counts for the navigation badge.
function Chat.TotalUnread()
  local n = 0
  for _, v in pairs(Chat.unread) do
    n = n + v
  end
  return n
end

function Chat.MarkRead(channel)
  Chat.unread[channel] = nil
  Chat.viewing = channel
end

-- Before 0.19.1 these were kept for the whole account, whichever guild they came from: they are dropped (the tags
-- come back as members log in; the reports were a few lines).
BG:On("ADDON_LOADED", function(name)
  if name == "BlazonGuild" and BG.db then
    BG.db.reports, BG.db.tags = nil, nil
  end
end)
