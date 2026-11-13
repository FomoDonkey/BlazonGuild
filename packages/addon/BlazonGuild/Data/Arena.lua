-- La Arena (entrega 12, primera parte; after Olympus' ArenaParse.lua, ArenaRating.lua and ArenaFights.lua, MIT:
-- the format reader is adapted from ArenaParse, the rating's numbers are ArenaRating's; see THIRD_PARTY_NOTICES).
--
-- Duels between members, read from the game itself: when a duel ends, the game writes "X has defeated Y in a duel"
-- (or "Y has fled from X") in every nearby player's chat. The loser's own client writes the result ("duels": only
-- the loser writes, about their own defeat, so nobody can give themselves wins; the organisers may take one off).
-- The rating is worked out from those rows by every client the same way (Elo): everyone starts at 1500; the first
-- 10 fights move it more; a level of difference counts as 50 points; the same two fighters within 24 hours weigh
-- 1, 1/2, 1/4... (no farming). With 5 fights a fighter gets a tier: gold (the best 10%), silver (the next 20%),
-- bronze (the next 30%). The champion's belt: the season's first winner holds it, and whoever beats the holder
-- takes it. Seasons: an organiser starts a new one; the old one is kept with its champion and podium.
-- Challenges: a member challenges another (DQ by whisper), who says yes or no (DY). The duel itself is the game's
-- own (right-click the portrait, "Duel"): the addon never starts one.
-- No gold: there are no bets here, nor anywhere in BlazonGuild.
local _, BG = ...
local Arena = { challenges = {}, sent = {}, accepted = {}, lastDuel = nil }
BG.Arena = Arena
local Store, Names, Comm = BG.Store, BG.Names, BG.Comm
local str, int = BG.Raids.Clean, BG.Raids.Int

local R = {
  START = 1500, K_NEW = 40, NEW_FIGHTS = 10, K = 24, K_HIGH = 16, HIGH_RATING = 2000, GAP_CAP = 800,
  LEVEL_POINTS = 50, PAIR_WINDOW = 86400, RANKED_MIN = 5,
  TIERS = { { key = "gold", label = "Oro", share = 10 }, { key = "silver", label = "Plata", share = 20 }, { key = "bronze", label = "Bronce", share = 30 } },
}
Arena.R = R
local CHALLENGE_TTL = 30 * 60
local CHALLENGE_GAP = 60

local function secret(v)
  return issecretvalue ~= nil and issecretvalue(v)
end

-- Reading the game's lines -------------------------------------------------------------------------------------
-- A format string of the game ("%s", "%d", "%%" and the positional "%1$s" other languages use) as an anchored
-- pattern, with the argument each capture holds. nil for anything else (read wrongly is worse than not read).
local MAGIC = "[%^%$%(%)%%%.%[%]%*%+%-%?]"
local CAPTURE = { s = "(.+)", d = "(%d+)" }
local compiled = {}

local function compile(fmt)
  if type(fmt) ~= "string" or fmt == "" then
    return nil
  end
  local parts, order, kinds, auto, positional, i, n = { "^" }, {}, {}, 0, false, 1, #fmt
  while i <= n do
    local at = fmt:find("%", i, true)
    if not at then
      parts[#parts + 1] = (fmt:sub(i):gsub(MAGIC, "%%%0"))
      break
    end
    parts[#parts + 1] = (fmt:sub(i, at - 1):gsub(MAGIC, "%%%0"))
    local pos, kind, after = fmt:match("^(%d+)%$([sd])()", at + 1)
    if not pos then
      kind, after = fmt:match("^([sd%%])()", at + 1)
    end
    if not kind then
      return nil
    end
    if kind == "%" then
      parts[#parts + 1] = "%%"
    else
      local arg = pos and tonumber(pos)
      if arg then
        positional = true
      else
        auto = auto + 1
        arg = auto
      end
      if (positional and auto > 0) or arg < 1 or #order >= 32 or (kinds[arg] and kinds[arg] ~= kind) then
        return nil
      end
      order[#order + 1], kinds[arg] = arg, kind
      parts[#parts + 1] = CAPTURE[kind]
    end
    i = after
  end
  parts[#parts + 1] = "$"
  return { pattern = table.concat(parts), order = order, kinds = kinds }
end

function Arena.Scan(fmt, text)
  if secret(text) or type(text) ~= "string" then
    return nil
  end
  local c = compiled[fmt]
  if c == nil then
    c = compile(fmt) or false
    compiled[fmt] = c
  end
  if not c or not text:find(c.pattern) then
    return nil -- (most of the game's lines are not this one: nothing is made for them)
  end
  local caps = { text:match(c.pattern) }
  if caps[1] == nil then
    return nil
  end
  local args = {}
  for i, arg in ipairs(c.order) do
    local v = caps[i]
    if c.kinds[arg] == "d" then
      v = tonumber(v)
    end
    if v == nil or (args[arg] ~= nil and args[arg] ~= v) then
      return nil
    end
    args[arg] = v
  end
  return args
end

local EN = {
  DUEL_WINNER_KNOCKOUT = "%1$s has defeated %2$s in a duel",
  DUEL_WINNER_RETREAT = "%2$s has fled from %1$s in a duel",
  RANDOM_ROLL_RESULT = "%s rolls %d (%d-%d)",
}
function Arena.Format(key)
  local f = _G[key]
  if type(f) == "string" and f ~= "" and not secret(f) then
    return f
  end
  return EN[key]
end

-- The duel's line: winner, loser, "K" (knockout) or "F" (fled); nil when it is not one, or when both of the
-- game's lines would read it (a language where one holds the other's words: which it was is unknown).
local WAYS = { { "DUEL_WINNER_KNOCKOUT", "K" }, { "DUEL_WINNER_RETREAT", "F" } }
-- (the same system line is asked for by the Arena, «Cara a cara» and the self-test: read once)
local lastMsg, lastW, lastL, lastM
function Arena.DuelResult(msg)
  if secret(msg) or type(msg) ~= "string" then
    return nil
  end
  if msg == lastMsg then
    return lastW, lastL, lastM
  end
  lastMsg, lastW, lastL, lastM = msg, Arena.ReadDuel(msg)
  return lastW, lastL, lastM
end

function Arena.ReadDuel(msg)
  local read
  for _, way in ipairs(WAYS) do
    local args = Arena.Scan(Arena.Format(way[1]), msg)
    if args then
      if read then
        return nil
      end
      read = { w = Names.Short(args[1]), l = Names.Short(args[2]), m = way[2] }
    end
  end
  if read and read.w and read.l and read.w ~= read.l and not read.w:find("%c") and not read.l:find("%c") then
    return read.w, read.l, read.m
  end
  return nil
end

-- Shared records ---------------------------------------------------------------------------------------------------
-- d = { w = winner, l = loser, m = "K" | "F", wl = winner's level, ll = loser's level, zone, s = season }
Store.Define("duels", {
  ttl = 365 * 86400,
  can = function(author, r)
    local prefix = author:gsub("%s", "") .. "-"
    if r.del then
      return r.id:sub(1, #prefix) == prefix or Store.IsOrganiser(author)
    end
    return r.id:sub(1, #prefix) == prefix and Names.Same(r.d.l, author) -- (only the loser, about their own defeat)
  end,
  normalize = function(d)
    local w, l = Names.Short(str(d.w, 40)), Names.Short(str(d.l, 40))
    if not w or not l or w == "" or w == l or (d.m ~= "K" and d.m ~= "F") then
      return nil
    end
    return { w = w, l = l, m = d.m, wl = int(d.wl, 1, 100), ll = int(d.ll, 1, 100), zone = str(d.zone, 60), s = int(d.s, 1, 10000) }
  end,
})

-- The season (organisers): { season = n, since = time, past = { { n, since, untilT, champ, top = { names } } } }
Store.Define("arena", {
  can = function(author)
    return Store.IsOrganiser(author)
  end,
  normalize = function(d)
    local past = {}
    for i, p in ipairs(type(d.past) == "table" and d.past or {}) do
      if i > 8 then
        break
      end
      if type(p) == "table" then
        local top = {}
        for j = 1, 3 do
          local n = type(p.top) == "table" and Names.Short(str(p.top[j], 40))
          if n then
            top[#top + 1] = n
          end
        end
        past[#past + 1] = { n = int(p.n, 1, 10000), since = int(p.since, 0, 4294967295), untilT = int(p.untilT, 0, 4294967295),
          champ = Names.Short(str(p.champ, 40)), top = top, fights = int(p.fights, 0, 1000000) }
      end
    end
    return { season = int(d.season, 1, 10000) or 1, since = int(d.since, 0, 4294967295) or 0, past = past }
  end,
})

function Arena.Season()
  local r = Store.Get("arena", "main")
  local d = r and not r.del and r.d
  return d and d.season or 1, d and d.since or 0, d and d.past or {}
end

-- The rating ---------------------------------------------------------------------------------------------------------
local function expected(ra, rb, la, lb)
  local gap = (rb + (lb or 0) * R.LEVEL_POINTS) - (ra + (la or 0) * R.LEVEL_POINTS)
  gap = math.max(-R.GAP_CAP, math.min(R.GAP_CAP, gap))
  return 1 / (1 + 10 ^ (gap / 400))
end
Arena.Expected = expected

local function kOf(f)
  if f.fights < R.NEW_FIGHTS then
    return R.K_NEW
  end
  return f.rating >= R.HIGH_RATING and R.K_HIGH or R.K
end

local function round(x)
  return math.floor(x + 0.5)
end

-- Every fighter of the season from its duels (oldest first): { name, rating, fights, wins, losses, streak, best,
-- recent = { "V"/"D" newest first }, last }, the belt's holder, and each duel's change (by id).
local cache
function Arena.Invalidate()
  cache = nil
end

function Arena.Build()
  if cache and GetTime() - cache.t < 30 then
    return cache.built
  end
  local season, since = Arena.Season()
  local rows = Store.List("duels", function(r)
    return r.at >= since
  end)
  table.sort(rows, function(a, b)
    if a.at ~= b.at then
      return a.at < b.at
    end
    return a.id < b.id
  end)
  local fighters, pairs_, deltas, belt = {}, {}, {}, nil
  local function fighter(n)
    local f = fighters[n]
    if not f then
      f = { name = n, rating = R.START, fights = 0, wins = 0, losses = 0, streak = 0, recent = {} }
      fighters[n] = f
    end
    return f
  end
  for _, r in ipairs(rows) do
    local d = r.d
    local w, l = fighter(d.w), fighter(d.l)
    local key = d.w < d.l and (d.w .. "|" .. d.l) or (d.l .. "|" .. d.w)
    local p = pairs_[key] or {}
    for i = #p, 1, -1 do
      if r.at - p[i] >= R.PAIR_WINDOW then
        table.remove(p, i)
      end
    end
    local weight = 0.5 ^ math.min(16, #p)
    p[#p + 1] = r.at
    pairs_[key] = p
    local ew = expected(w.rating, l.rating, d.wl, d.ll)
    local gain = round(kOf(w) * (1 - ew) * weight)
    local loss = round(kOf(l) * (1 - ew) * weight)
    w.rating, l.rating = w.rating + gain, l.rating - loss
    w.fights, l.fights = w.fights + 1, l.fights + 1
    w.wins, l.losses = w.wins + 1, l.losses + 1
    w.streak = w.streak >= 0 and w.streak + 1 or 1
    l.streak = l.streak <= 0 and l.streak - 1 or -1
    table.insert(w.recent, 1, "V")
    table.insert(l.recent, 1, "D")
    w.recent[6], l.recent[6] = nil, nil
    if not w.best or l.rating + loss > w.best.rating then
      w.best = { name = l.name, rating = l.rating + loss }
    end
    w.last, l.last = r.at, r.at
    deltas[r.id] = { gain = gain, loss = loss }
    if not belt or belt == d.l then
      belt = d.w
    end
  end
  -- Places and tiers: the fighters with RANKED_MIN fights, best rating first.
  local ranked, list = {}, {}
  for _, f in pairs(fighters) do
    list[#list + 1] = f
    if f.fights >= R.RANKED_MIN then
      ranked[#ranked + 1] = f
    end
  end
  local function better(a, b)
    if a.rating ~= b.rating then
      return a.rating > b.rating
    end
    if a.wins ~= b.wins then
      return a.wins > b.wins
    end
    return a.name < b.name
  end
  table.sort(ranked, better)
  local at = 0
  for _, t in ipairs(R.TIERS) do
    local n = math.ceil(#ranked * t.share / 100)
    for i = at + 1, math.min(#ranked, at + n) do
      ranked[i].tier = t
    end
    at = at + n
  end
  for i, f in ipairs(ranked) do
    f.place = i
  end
  table.sort(list, function(a, b)
    if (a.place ~= nil) ~= (b.place ~= nil) then
      return a.place ~= nil
    end
    return better(a, b)
  end)
  local built = { season = season, since = since, fighters = fighters, list = list, ranked = ranked, belt = belt, deltas = deltas, fights = #rows }
  cache = { t = GetTime(), built = built }
  return built
end

function Arena.Fighter(name)
  return Arena.Build().fighters[Names.Short(name) or ""]
end

-- Text of one fighter, for the profile and the duel request: "1532, oro, 12 victorias y 3 derrotas".
function Arena.Summary(name)
  local f = Arena.Fighter(name)
  if not f then
    return nil
  end
  local b = Arena.Build()
  return f.rating .. (f.tier and (", " .. f.tier.label:lower()) or "") .. (b.belt == f.name and ", campeón" or "") .. ", "
    .. f.wins .. (f.wins == 1 and " victoria" or " victorias") .. " y " .. f.losses .. (f.losses == 1 and " derrota" or " derrotas")
end

-- The latest duels of the season, newest first, with their change.
function Arena.Recent(limit)
  local b = Arena.Build()
  local rows = Store.List("duels", function(r)
    return r.at >= b.since
  end)
  table.sort(rows, function(a, c)
    return a.at > c.at
  end)
  local out = {}
  for i = 1, math.min(limit or 30, #rows) do
    local r = rows[i] -- (a copy: the stored record stays as it was)
    out[i] = { id = r.id, at = r.at, by = r.by, d = r.d, delta = b.deltas[r.id] }
  end
  return out
end

function Arena.CanRemove(r)
  local me = Names.Me() or ""
  return r ~= nil and (Store.IsOrganiser(me) or Names.Same(r.d and r.d.l, me))
end

function Arena.Remove(id)
  local r = Store.Get("duels", id)
  if not r or r.del then
    return nil, "no existe"
  end
  if not Arena.CanRemove(r) then
    return nil, "permiso"
  end
  local ok, why = Store.Delete("duels", id)
  Arena.Invalidate()
  BG:Fire("BG_ARENA_CHANGED")
  return ok, why
end

-- A new season (organisers): the one ending is kept with its champion and its podium.
function Arena.NewSeason()
  if not Store.IsOrganiser(Names.Me() or "") then
    return nil, "permiso"
  end
  local b = Arena.Build()
  local season, since, past = Arena.Season()
  local top = {}
  for i = 1, math.min(3, #b.ranked) do
    top[i] = b.ranked[i].name
  end
  local list = { { n = season, since = since, untilT = Store.Now(), champ = b.belt, top = top, fights = b.fights } }
  for i, p in ipairs(past) do
    if i < 8 then
      list[#list + 1] = p
    end
  end
  local r, why = Store.Put("arena", "main", { season = season + 1, since = Store.Now(), past = list })
  Arena.Invalidate()
  BG:Fire("BG_ARENA_CHANGED")
  return r, why
end

-- The duel's line ----------------------------------------------------------------------------------------------------
local function levelOf(name)
  local m = BG.Guild.Find(name)
  return m and m.level or nil
end

local function zoneText()
  local ok, z = pcall(GetRealZoneText or GetZoneText or function() return nil end)
  return ok and not secret(z) and str(z, 60) or nil
end

function Arena.OnSystem(msg)
  local w, l, m = Arena.DuelResult(msg)
  if not w then
    return nil
  end
  local me = Names.Me()
  if not me or not (Names.Same(w, me) or Names.Same(l, me)) then
    return nil -- (someone else's duel, nearby)
  end
  local other = Names.Same(w, me) and l or w
  Arena.lastDuel = { w = w, l = l, m = m, at = GetTime() }
  Arena.accepted[other] = nil
  if not BG.Guild.Find(other) then
    BG:Notify(Names.Same(w, me) and ("Has ganado a " .. other) or ("Te ha ganado " .. other), "No cuenta para la Arena: no es de tu hermandad.", { kind = "info", view = "arena" })
    return nil, "fuera"
  end
  if Names.Same(w, me) then
    local hasAddon = BG.Peers.Get(other) ~= nil
    BG:Notify("Has ganado a " .. other, hasAddon and "Su addon apunta el combate: lo verás en la Arena en un momento."
      or "No cuenta para la Arena: " .. other .. " no tiene BlazonGuild (el combate lo apunta el addon de quien pierde).", { kind = "success", view = "arena" })
    return nil, hasAddon and "lo apunta el otro" or "sin addon"
  end
  if not BG.Consent.Accepted() then
    return nil, "consent"
  end
  local season = Arena.Season()
  local id = me:gsub("%s", "") .. "-" .. Store.Now() .. BG.Alliance.RandomId(3)
  local before = Arena.Fighter(me)
  local r, why = Store.Put("duels", id, { w = w, l = me, m = m, wl = levelOf(w), ll = UnitLevel and UnitLevel("player") or levelOf(me), zone = zoneText(), s = season })
  if not r then
    return nil, why
  end
  Arena.Invalidate()
  BG:Fire("BG_DUEL_ADDED", r)
  local after = Arena.Fighter(me)
  local change = (after and after.rating or R.START) - (before and before.rating or R.START)
  BG:Notify("Te ha ganado " .. w, (m == "F" and "Te has rendido. " or "") .. "Tu puntuación: " .. (after and after.rating or R.START) .. " (" .. change .. "). ¡A por la revancha!",
    { kind = "info", view = "arena" })
  BG:Fire("BG_ARENA_CHANGED")
  return r
end

BG:On("CHAT_MSG_SYSTEM", function(msg)
  Arena.OnSystem(msg)
end)

-- When the game shows someone's duel request, BlazonGuild tells their rating.
BG:On("DUEL_REQUESTED", function(name)
  if secret(name) then
    return
  end
  local n = Names.Short(name)
  local s = n and BG.Guild.Find(n) and Arena.Summary(n)
  if s then
    BG:Notify(n .. " te reta a un duelo", "En la Arena: " .. s .. ".", { kind = "info", view = "arena", icon = "Interface\\Icons\\Ability_DualWield" })
  end
end)

-- Challenges ---------------------------------------------------------------------------------------------------------
function Arena.Challenge(name, note)
  local m = BG.Guild.Find(name or "")
  if not m then
    return nil, "no es de tu hermandad"
  end
  local target = Names.Short(m.name)
  if Names.IsMe(target) then
    return nil, "tú mismo"
  end
  if not m.online or not BG.Peers.Get(target) then
    return nil, "sin addon"
  end
  local last = Arena.sent[target]
  if last and GetTime() - last.at < CHALLENGE_GAP then
    return nil, "espera"
  end
  Arena.sent[target] = { at = GetTime(), note = str(note, 80) }
  Comm.Send("DQ", { n = str(note, 80) }, "WHISPER", target, { lane = "alert" })
  BG:Fire("BG_ARENA_CHANGED")
  return true
end

Comm.Register("DQ", function(sender, b)
  local who = Names.Short(sender)
  if not who or not BG.Guild.Find(who) then
    return
  end
  Arena.challenges[who] = { name = who, note = type(b) == "table" and str(b.n, 80) or nil, at = GetTime() }
  local s = Arena.Summary(who)
  BG:Notify(who .. " te reta a un duelo", (s and ("En la Arena: " .. s .. ". ") or "") .. "Ábrelo en la Arena para decir sí o no.",
    { kind = "info", view = "arena", sound = "READY_CHECK", icon = "Interface\\Icons\\Ability_DualWield" })
  BG:Fire("BG_ARENA_CHANGED")
end, { channels = { "WHISPER" }, maxBytes = 120 })

function Arena.Challenges()
  local out, t = {}, GetTime()
  for name, c in pairs(Arena.challenges) do
    if t - c.at > CHALLENGE_TTL then
      Arena.challenges[name] = nil
    else
      out[#out + 1] = c
    end
  end
  table.sort(out, function(a, b)
    return a.at > b.at
  end)
  return out
end

function Arena.Answer(name, yes)
  local who = Names.Short(name)
  if not who or not Arena.challenges[who] then
    return nil, "no existe"
  end
  Arena.challenges[who] = nil
  Comm.Send("DY", { y = yes == true }, "WHISPER", who, { lane = "alert" })
  if yes then
    Arena.accepted[who] = GetTime()
  end
  BG:Fire("BG_ARENA_CHANGED")
  return true
end

Comm.Register("DY", function(sender, b)
  local who = Names.Short(sender)
  if not who or not Arena.sent[who] or type(b) ~= "table" then
    return
  end
  Arena.sent[who] = nil
  if b.y == true then
    Arena.accepted[who] = GetTime()
    local m = BG.Guild.Find(who)
    BG:Notify(who .. " acepta tu reto", "Búscale" .. (m and m.zone and m.zone ~= "" and (" (está en " .. m.zone .. ")") or "") .. " y retadle desde el juego: clic derecho en su retrato, «Duelo».",
      { kind = "success", view = "arena" })
  else
    BG:Notify(who .. " no acepta ahora", "Quizá en otro momento.", { kind = "info", view = "arena" })
  end
  BG:Fire("BG_ARENA_CHANGED")
end, { channels = { "WHISPER" }, maxBytes = 20 })

-- Members online: those with BlazonGuild first (they can be challenged, and their duels count), those in our
-- zone first among them; the rest show why not.
function Arena.Rivals()
  local here = zoneText()
  local out = {}
  for _, m in ipairs(BG.Guild.members or {}) do
    if m.online and not Names.IsMe(m.name) then
      local n = Names.Short(m.name)
      out[#out + 1] = { name = n, class = m.classFile, level = m.level, zone = m.zone, near = here ~= nil and m.zone == here,
        addon = BG.Peers.Get(n) ~= nil, f = Arena.Fighter(n) }
    end
  end
  table.sort(out, function(a, b)
    if a.addon ~= b.addon then
      return a.addon
    end
    if a.near ~= b.near then
      return a.near
    end
    return a.name < b.name
  end)
  return out
end

function Arena.Accepted(name)
  local t = Arena.accepted[Names.Short(name) or ""]
  return t ~= nil and GetTime() - t < CHALLENGE_TTL
end

BG:On("BG_STORE_CHANGED", function(name)
  if name == "duels" or name == "arena" then
    Arena.Invalidate()
    BG:Fire("BG_ARENA_CHANGED")
  end
end)
BG:On("BG_RECORD", function(kind, r, old)
  if kind ~= "duels" and kind ~= "arena" then
    return
  end
  Arena.Invalidate()
  if kind == "duels" and not r.del and not old then
    BG:Fire("BG_DUEL_ADDED", r)
  end
  if kind == "duels" and not r.del and not old and r.d and Names.IsMe(r.d.w) then
    local f = Arena.Fighter(r.d.w)
    local delta = Arena.Build().deltas[r.id]
    BG:Notify("Victoria apuntada", "Contra " .. r.d.l .. ": " .. (f and f.rating or R.START) .. " puntos" .. (delta and (" (+" .. delta.gain .. ")") or "") .. ".", { kind = "success", view = "arena" })
  end
  BG:Fire("BG_ARENA_CHANGED")
end)

BG.commands = BG.commands or {}
BG.commands.arena = function()
  if not (BG.window and BG.window:IsShown()) then
    BG:ToggleWindow()
  end
  BG:ShowView("arena")
end
