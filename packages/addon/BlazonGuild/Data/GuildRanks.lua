-- Clasificación de hermandades (Peregrino, 2026-11-13: "rankings, estadísticas y comparativas contra guilds, top guilds").
-- BlazonGuild runs in many guilds and there is no shared channel in Forever, so each guild's numbers travel addon to
-- addon (ADR-024):
--   * A guild appears only if its master says yes («Publicar nuestras cifras»). Its card has numbers of the guild,
--     never anything of one person: members, at the top level, active this week, with BlazonGuild, bosses defeated,
--     whole raids, raids of the last 90 days, kills of wanted foes, duels, best Arena rating, crafters. An organiser's
--     addon makes it (record "gcard"), so every member of the guild has it to show.
--   * Grouping with someone of another guild (party, raid, battleground) is how cards meet: each addon says hello to
--     the group ("GH", with its guild's card, or only asking). A card that comes from someone in our group whose guild
--     the game itself names (GetGuildInfo of their unit) is "verified"; then our addon passes it to our guild ("GV"),
--     and answers by whisper with a few other verified cards it knows ("GK"), which arrive "sin verificar" there.
--   * Only the same faction (a group is of one faction). A card lasts 30 days without news.
-- The numbers are what each guild's addon counts (nobody can check another guild's numbers from outside).
local _, BG = ...
local GR = {}
BG.GuildRanks = GR
local Store, Names, Comm = BG.Store, BG.Names, BG.Comm
local str, int = BG.Raids.Clean, BG.Raids.Int

local CARD_TTL = 30 * 86400
local REBUILD = 6 * 3600 -- our card is made again at most this often (or when the master turns it on)
local HELLO_GAP = 15 * 60 -- one hello per group every so often
local SHARE_MAX = 8 -- other cards sent back by whisper
local KEEP_MAX = 200 -- cards kept on this computer

GR.STATS = {
  { key = "m", title = "Miembros", how = "Personajes en la hermandad, según la lista del juego." },
  { key = "l", title = "En el nivel máximo", how = "Miembros en el nivel máximo." },
  { key = "a", title = "Activos esta semana", how = "Miembros que se han conectado en los últimos 7 días." },
  { key = "b", title = "Jefes derrotados", how = "Jefes de banda distintos que la hermandad ha matado (lo apunta el addon de quien estaba allí)." },
  { key = "c", title = "Bandas enteras", how = "Bandas con todos sus jefes derrotados." },
  { key = "r", title = "Raids (90 días)", how = "Raids de BlazonGuild que empezaron en los últimos 90 días." },
  { key = "w", title = "Cazadores de «Se busca»", how = "Bajas de buscados de la otra facción en 90 días." },
  { key = "d", title = "Duelos de la Arena", how = "Duelos apuntados en la temporada de la Arena." },
  { key = "ar", title = "Mejor de la Arena", how = "La mejor puntuación de la Arena de la hermandad." },
  { key = "cr", title = "Artesanos", how = "Miembros que publican sus profesiones." },
  { key = "u", title = "Con BlazonGuild", how = "Miembros con el addon conectados hace poco." },
}
local NUMBERS = {}
for _, s in ipairs(GR.STATS) do
  NUMBERS[s.key] = true
end

-- The master's switch ("showcase"/"guild": { on }) and our card ("gcard"/"guild"), in the guild's records.
Store.Define("showcase", {
  can = function(author)
    return Store.IsMaster(author)
  end,
  normalize = function(d)
    return { on = d.on == true or nil }
  end,
})

-- A card, clean (from anyone: it is checked field by field). Pure.
function GR.Clean(d)
  if type(d) ~= "table" then
    return nil
  end
  local n, k = str(d.n, 40), str(d.k, 60)
  local f = d.f == "ALLIANCE" and "ALLIANCE" or d.f == "HORDE" and "HORDE" or nil
  local v = int(d.v, 1, 4e9)
  if not (n and n ~= "" and k and k ~= "" and f and v) then
    return nil
  end
  local card = { n = n, k = k, f = f, v = v }
  for key in pairs(NUMBERS) do
    card[key] = int(d[key], 0, 100000) or 0
  end
  return card
end

Store.Define("gcard", {
  can = function(author)
    return Store.IsOrganiser(author)
  end,
  normalize = function(d)
    return GR.Clean(d)
  end,
})

function GR.Publishing()
  local r = Store.Get("showcase", "guild")
  return r ~= nil and not r.del and r.d ~= nil and r.d.on == true
end

function GR.SetPublishing(on)
  local r, why = Store.Put("showcase", "guild", { on = on == true }, { lane = "alert" })
  if r then
    GR.Rebuild(true)
  end
  return r, why
end

-- Our guild's numbers now (pure given the stores and the roster).
function GR.Count()
  local info, stats = BG.Guild.info, BG.Guild.stats
  if not (info and stats) then
    return nil
  end
  local active = 0
  for _, m in ipairs(BG.Guild.members or {}) do
    if m.online or (m.lastOnlineDays or 1e9) <= 7 then
      active = active + 1
    end
  end
  local pve = BG.PvE.Totals()
  local hunted = 0
  for _, h in ipairs(BG.Wanted.Hunters(1000)) do
    hunted = hunted + (h.kills or 0)
  end
  local arena = BG.Arena.Build()
  local best = 0
  for _, fgt in pairs(arena.fighters or {}) do
    if fgt.fights > 0 and fgt.rating > best then
      best = fgt.rating
    end
  end
  local crafters = {}
  for _, r in ipairs(Store.List("crafters")) do
    crafters[r.id:match("^(.-)|") or r.id] = true
  end
  local nCrafters = 0
  for _ in pairs(crafters) do
    nCrafters = nCrafters + 1
  end
  return {
    n = info.name, k = info.key, f = info.faction, v = Store.Now(),
    m = stats.total, l = stats.atMax, a = active, b = pve.bosses, c = pve.cleared, r = #BG.PvE.History(1000),
    w = hunted, d = arena.fights or 0, ar = best, cr = nCrafters, u = #BG.Peers.Active(),
  }
end

-- Our card: made again (by an organiser) if publishing is on and it is old or changed; taken away if it is off.
function GR.Rebuild(force)
  if not (BG.Guild.info and Store.IsOrganiser(Names.Me()) and BG.Consent.Accepted()) then
    return nil
  end
  local old = Store.Get("gcard", "guild")
  if not GR.Publishing() then
    if old and not old.del then
      return Store.Delete("gcard", "guild")
    end
    return nil
  end
  local now = GR.Count()
  if not now then
    return nil
  end
  if old and not old.del and old.d and not force and Store.Now() - old.at < REBUILD then
    local same = true
    for key in pairs(NUMBERS) do
      same = same and old.d[key] == now[key]
    end
    if same or Store.Now() - old.at < 600 then
      return old
    end
  end
  return Store.Put("gcard", "guild", now, { lane = "bulk" })
end

function GR.Mine()
  local r = Store.Get("gcard", "guild")
  return r and not r.del and r.d or nil
end

-- Cards of other guilds, on this computer ------------------------------------------------------------------------------
local function book()
  BG.db.guildCards = BG.db.guildCards or {}
  return BG.db.guildCards
end

local function keyOf(card)
  return card.f .. "|" .. card.k
end

-- Keeps a card of another guild. verified: it came from someone the game says is of that guild (or from our own
-- guild, who checked it). A card never replaces a verified one with an unverified one, nor a newer with an older.
-- Returns true if it was new or newer.
function GR.Take(d, verified, via)
  local card = GR.Clean(d)
  local info = BG.Guild.info
  if not card or (info and card.f ~= info.faction) or (info and card.k == info.key) then
    return false
  end
  if Store.Now() - card.v > CARD_TTL or card.v > Store.Now() + 3600 then
    return false
  end
  local b = book()
  local old = b[keyOf(card)]
  if old then
    local better = (verified and not old.verified) or ((verified == true) == old.verified and card.v > old.card.v)
    if not better then
      return false
    end
  end
  b[keyOf(card)] = { card = card, verified = verified == true, via = via, at = Store.Now() }
  -- room: the oldest go first
  local n, oldest, oldestKey = 0, nil, nil
  for k, e in pairs(b) do
    n = n + 1
    if not oldest or e.card.v < oldest then
      oldest, oldestKey = e.card.v, k
    end
  end
  if n > KEEP_MAX and oldestKey then
    b[oldestKey] = nil
  end
  BG:Fire("BG_GUILDRANKS_CHANGED")
  return true
end

-- Every guild we know of our faction, ours included (marked mine), not older than 30 days.
function GR.Known()
  local info = BG.Guild.info
  local out, t = {}, Store.Now()
  for _, e in pairs(book()) do
    if (not info or e.card.f == info.faction) and t - e.card.v <= CARD_TTL then
      out[#out + 1] = { card = e.card, verified = e.verified }
    end
  end
  local mine = GR.Mine()
  if mine then
    out[#out + 1] = { card = mine, verified = true, mine = true }
  end
  return out
end

-- The ranking by one number: { { card, verified, mine, value, place } } the best first (ties share the place).
function GR.Ranking(key)
  local list = GR.Known()
  table.sort(list, function(a, b)
    local x, y = a.card[key] or 0, b.card[key] or 0
    if x ~= y then
      return x > y
    end
    return a.card.n < b.card.n
  end)
  local place, last = 0, nil
  for i, e in ipairs(list) do
    e.value = e.card[key] or 0
    if e.value ~= last then
      place, last = i, e.value
    end
    e.place = place
  end
  return list
end

-- Our place in each ranking: { key = place } and how many guilds there are.
function GR.MyPlaces()
  local places, n = {}, 0
  for _, s in ipairs(GR.STATS) do
    local list = GR.Ranking(s.key)
    n = #list
    for _, e in ipairs(list) do
      if e.mine then
        places[s.key] = e.place
      end
    end
  end
  return places, n
end

-- Messages ------------------------------------------------------------------------------------------------------------
local helloAt = {} -- group signature -> GetTime()
local function groupDist()
  if IsInGroup and LE_PARTY_CATEGORY_INSTANCE and IsInGroup(LE_PARTY_CATEGORY_INSTANCE) then
    return "INSTANCE_CHAT"
  end
  if IsInRaid and IsInRaid() then
    return "RAID"
  end
  if (IsInGroup and IsInGroup()) or (GetNumGroupMembers and GetNumGroupMembers() > 0) then
    return "PARTY"
  end
  return nil
end

-- The units of our group and whether any of them is of another guild.
local function groupUnits()
  local units, others = {}, false
  local raid = IsInRaid and IsInRaid()
  local n = GetNumGroupMembers and GetNumGroupMembers() or 0
  for i = 1, raid and n or math.min(4, n) do
    local u = (raid and "raid" or "party") .. i
    local name = Names.Unit(u) -- (on Forever UnitName gives the first name alone: Names.lua)
    if name then
      units[#units + 1] = { unit = u, name = name }
      if not BG.Guild.Find(name) and not Names.IsMe(name) then
        others = true
      end
    end
  end
  return units, others
end

-- The guild the game names for `name`, if they are in our group now.
function GR.GuildOfMember(name)
  for _, x in ipairs(groupUnits()) do
    if Names.Same(x.name, name) then
      local ok, guild = pcall(GetGuildInfo, x.unit)
      if ok and type(guild) == "string" and not (issecretvalue and issecretvalue(guild)) then
        return guild
      end
    end
  end
  return nil
end

-- Says hello to the group (with our card, if we publish), once in a while, if someone in it is of another guild.
function GR.Hello(force)
  if not BG.Consent.Accepted() then
    return false
  end
  local dist = groupDist()
  if not dist then
    return false
  end
  local units, others = groupUnits()
  if not others and not force then
    return false
  end
  local sig = {}
  for _, x in ipairs(units) do
    sig[#sig + 1] = x.name
  end
  table.sort(sig)
  -- (the same group hears from us again sooner if our card changed: the master just published, say)
  local card = GR.Publishing() and GR.Mine() or nil
  local key = table.concat(sig, ",") .. "|" .. (card and card.v or 0)
  if not force and helloAt[key] and GetTime() - helloAt[key] < HELLO_GAP then
    return false
  end
  helloAt[key] = GetTime()
  return Comm.Send("GH", { c = card }, dist, nil, { lane = "bulk", key = "GH" })
end

local function sendSome(to, except)
  local list = {}
  for _, e in pairs(book()) do
    if e.verified and e.card.k ~= except and Store.Now() - e.card.v <= CARD_TTL then
      list[#list + 1] = e.card
    end
  end
  table.sort(list, function(a, b)
    return a.v > b.v
  end)
  while #list > SHARE_MAX do
    table.remove(list)
  end
  local mine = GR.Publishing() and GR.Mine()
  if mine then
    table.insert(list, 1, mine)
  end
  if #list > 0 then
    Comm.Send("GK", { l = list }, "WHISPER", to, { lane = "bulk", key = "GK:" .. to })
  end
end

Comm.Register("GH", function(sender, b)
  if type(b) ~= "table" or BG.Guild.Find(sender) or not BG.Consent.Accepted() then
    return -- (someone of our own guild: nothing to learn)
  end
  local theirs = type(b.c) == "table" and GR.Clean(b.c)
  if theirs then
    local guild = GR.GuildOfMember(sender)
    local verified = guild ~= nil and guild == theirs.n
    if GR.Take(theirs, verified, sender) and verified then
      Comm.Send("GV", { c = theirs }, "GUILD", nil, { lane = "bulk", key = "GV:" .. theirs.k })
    end
  end
  sendSome(sender, theirs and theirs.k or nil)
end, { channels = { "PARTY", "RAID", "INSTANCE_CHAT" }, maxBytes = 900 })

Comm.Register("GK", function(sender, b)
  if type(b) ~= "table" or type(b.l) ~= "table" or not BG.Consent.Accepted() then
    return
  end
  local guild = GR.GuildOfMember(sender)
  for i = 1, math.min(SHARE_MAX + 1, #b.l) do
    local card = GR.Clean(b.l[i])
    if card then
      local verified = guild ~= nil and guild == card.n -- (their own guild's card, from someone of it in our group)
      if GR.Take(card, verified, sender) and verified then
        Comm.Send("GV", { c = card }, "GUILD", nil, { lane = "bulk", key = "GV:" .. card.k })
      end
    end
  end
end, { channels = { "WHISPER" }, maxBytes = 4000 })

-- From a member of ours who checked it in their group.
Comm.Register("GV", function(sender, b)
  if type(b) == "table" and BG.Consent.Accepted() then
    GR.Take(b.c, true, sender)
  end
end, { maxBytes = 900 })

local pendingHello = false
BG:On("GROUP_ROSTER_UPDATE", function()
  if pendingHello then
    return
  end
  pendingHello = true
  C_Timer.After(8, function()
    pendingHello = false
    GR.Hello(false)
  end)
end)

BG:On("BG_PEERS_CHANGED", function()
  C_Timer.After(40, function()
    GR.Rebuild(false)
  end)
end)

BG:On("BG_STORE_CHANGED", function(name)
  if name == "gcard" or name == "showcase" then
    BG:Fire("BG_GUILDRANKS_CHANGED")
  end
end)
