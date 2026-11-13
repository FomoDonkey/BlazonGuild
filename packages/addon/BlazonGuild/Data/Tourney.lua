-- Torneos y veladas (entrega 12, segunda parte; after Olympus' ArenaTourney.lua and ArenaBracket.lua, MIT: the
-- standard seeding order and the draw by the server's /roll are theirs, the rest is our own and simpler).
--
-- A tournament (CUP): members enter (their own "tentries"), and whoever runs it (its creator; the organisers too)
-- closes it with «Sortear y empezar»: the best of the Arena (by rating) are seeds, so they do not meet early, and
-- everyone else gets their place by the game's own /roll, which everyone near sees in the chat (one roll per
-- place; the rolls are kept on the record). Up to 16 fighters; the empty places are byes for the top seeds.
-- The results write themselves: once both sides of a match are known, the first duel between them (Arena.lua's
-- "duels", written by the loser) decides it. Whoever runs it may decide a match by hand (someone did not come).
-- A fight night (NIGHT): a list of announced bouts ("A contra B"), each decided the same way once it starts.
-- Nothing is bet: no gold anywhere.
local _, BG = ...
local T = { drawing = nil }
BG.Tourney = T
local Store, Names = BG.Store, BG.Names
local str, int = BG.Raids.Clean, BG.Raids.Int

local SIZES = { [2] = true, [4] = true, [8] = true, [16] = true }
local MAX = 16
local ROLL_WAIT = 6
T.MAX = MAX

local function secret(v)
  return issecretvalue ~= nil and issecretvalue(v)
end

local function nameList(t, max)
  local out, have = {}, {}
  for _, n in ipairs(type(t) == "table" and t or {}) do
    local s = n ~= false and Names.Short(str(n, 40)) or nil
    if #out >= max then
      break
    end
    if n == false then
      out[#out + 1] = false
    elseif s and s ~= "" and not have[s] then
      have[s] = true
      out[#out + 1] = s
    end
  end
  return out
end

-- Shared records -----------------------------------------------------------------------------------------------
-- d = { kind = "CUP" | "NIGHT", title, when (free text), size (CUP: 4, 8 or 16), state = "OPEN" | "RUNNING" |
--   "CANCELLED", startedAt, order (CUP: names by seed), rolls (CUP: the draw's rolls), seeds (how many were seeds),
--   bouts (NIGHT: { { a, b } }), ov (matches decided by hand: key -> winner), created }
Store.Define("tourneys", {
  ttl = function(r)
    return ((r.d and r.d.created) or r.at) + 45 * 86400
  end,
  can = function(author, r, old)
    local prefix = author:gsub("%s", "") .. "-"
    return r.id:sub(1, #prefix) == prefix or Store.IsOrganiser(author)
  end,
  normalize = function(d)
    local kind = (d.kind == "NIGHT") and "NIGHT" or "CUP"
    local state = ({ OPEN = true, RUNNING = true, CANCELLED = true })[d.state] and d.state or "OPEN"
    local bouts = {}
    for _, b in ipairs(type(d.bouts) == "table" and d.bouts or {}) do
      local a, c = type(b) == "table" and Names.Short(str(b[1], 40)), type(b) == "table" and Names.Short(str(b[2], 40))
      if a and c and a ~= c and #bouts < 12 then
        bouts[#bouts + 1] = { a, c }
      end
    end
    local ov, n = {}, 0
    for k, w in pairs(type(d.ov) == "table" and d.ov or {}) do
      n = n + 1
      local key, who = str(k, 8), Names.Short(str(w, 40))
      if n <= 40 and key and key:find("^%d+%.%d+$") and who then
        ov[key] = who
      end
    end
    local rolls = {}
    for i, v in ipairs(type(d.rolls) == "table" and d.rolls or {}) do
      if i <= MAX then
        rolls[i] = int(v, 1, MAX) or 1
      end
    end
    local title = str(d.title, 50)
    return { kind = kind, title = (title and title ~= "") and title or (kind == "NIGHT" and "Velada" or "Torneo"), when = str(d.when, 40),
      size = SIZES[tonumber(d.size)] and tonumber(d.size) or 8, state = state, startedAt = int(d.startedAt, 0, 4294967295),
      order = nameList(d.order, MAX), rolls = rolls, seeds = int(d.seeds, 0, MAX), bouts = bouts, ov = ov,
      created = int(d.created, 0, 4294967295) }
  end,
})

Store.Define("tentries", {
  ttl = function(r)
    local t = r.d and Store.Get("tourneys", r.d.t)
    return t and t.exp or (r.at + 45 * 86400)
  end,
  can = function(author, r)
    return Names.Same(r.id:match("|(.+)$"), author) -- (each one enters or leaves by themselves)
  end,
  normalize = function(d, r)
    local name = Names.Short(str(d.name, 40))
    if type(d.t) ~= "string" or not name or r.id ~= d.t .. "|" .. name then
      return nil
    end
    return { t = d.t, name = name }
  end,
})

-- Queries ----------------------------------------------------------------------------------------------------------
function T.Get(id)
  local r = id and Store.Get("tourneys", id)
  return r and not r.del and r or nil
end

function T.List()
  local list = Store.List("tourneys")
  local rank = { RUNNING = 1, OPEN = 2, CANCELLED = 4 }
  local key = {}
  for _, t in ipairs(list) do
    key[t.id] = T.Champion(t) and 3 or (rank[t.d.state] or 3) -- (a finished cup goes after the live ones)
  end
  table.sort(list, function(a, b)
    local ra, rb = key[a.id], key[b.id]
    if ra ~= rb then
      return ra < rb
    end
    return (a.d.created or a.at) > (b.d.created or b.at)
  end)
  return list
end

function T.CanManage(t)
  local me = Names.Me()
  if not (me and t) then
    return false
  end
  local prefix = me:gsub("%s", "") .. "-"
  return t.id:sub(1, #prefix) == prefix or Store.IsOrganiser(me)
end

function T.Director(t)
  for _, m in ipairs(BG.Guild.members or {}) do
    local prefix = Names.Short(m.name):gsub("%s", "") .. "-"
    if t.id:sub(1, #prefix) == prefix then
      return Names.Short(m.name)
    end
  end
  return t.by
end

function T.Entries(id)
  local out = {}
  for _, r in ipairs(Store.List("tentries", function(x)
    return x.d.t == id
  end)) do
    out[#out + 1] = r.d.name
  end
  table.sort(out)
  return out
end

function T.Entered(id)
  local me = Names.Me()
  local r = me and Store.Get("tentries", id .. "|" .. me)
  return r ~= nil and not r.del
end

-- Edits -------------------------------------------------------------------------------------------------------------
function T.Create(fields)
  local me = Names.Me()
  if not me or not BG.Guild.me then
    return nil, "sin personaje"
  end
  local id = me:gsub("%s", "") .. "-" .. Store.Now() .. BG.Alliance.RandomId(3)
  return Store.Put("tourneys", id, { kind = fields.kind, title = fields.title, when = fields.when, size = fields.size, state = "OPEN", created = Store.Now() })
end

local function update(t, fields)
  local d = {}
  for k, v in pairs(t.d) do
    d[k] = v
  end
  for k, v in pairs(fields) do
    d[k] = v
  end
  return Store.Put("tourneys", t.id, d)
end

function T.Enter(id)
  local t = T.Get(id)
  if not t or t.d.kind ~= "CUP" then
    return nil, "no existe"
  end
  if t.d.state ~= "OPEN" then
    return nil, "cerrado"
  end
  if #T.Entries(id) >= t.d.size and not T.Entered(id) then
    return nil, "lleno"
  end
  local me = Names.Me()
  return Store.Put("tentries", id .. "|" .. me, { t = id, name = me })
end

function T.Leave(id)
  local t = T.Get(id)
  if not t or t.d.state ~= "OPEN" then
    return nil, "cerrado"
  end
  return Store.Delete("tentries", id .. "|" .. (Names.Me() or ""))
end

function T.Cancel(id)
  local t = T.Get(id)
  if not t or not T.CanManage(t) then
    return nil, "permiso"
  end
  return update(t, { state = "CANCELLED" })
end

function T.AddBout(id, a, b)
  local t = T.Get(id)
  if not t or not T.CanManage(t) then
    return nil, "permiso"
  end
  if t.d.kind ~= "NIGHT" then
    return nil, "no existe"
  end
  local ma, mb = BG.Guild.Find(a or ""), BG.Guild.Find(b or "")
  if not ma then
    return nil, "no es de tu hermandad", a
  end
  if not mb then
    return nil, "no es de tu hermandad", b
  end
  if Names.Same(ma.name, mb.name) then
    return nil, "igual"
  end
  local bouts = {}
  for i, x in ipairs(t.d.bouts) do
    bouts[i] = { x[1], x[2] }
  end
  if #bouts >= 12 then
    return nil, "lleno"
  end
  bouts[#bouts + 1] = { Names.Short(ma.name), Names.Short(mb.name) }
  return update(t, { bouts = bouts })
end

function T.RemoveBout(id, i)
  local t = T.Get(id)
  if not t or not T.CanManage(t) then
    return nil, "permiso"
  end
  local bouts = {}
  for j, x in ipairs(t.d.bouts) do
    if j ~= i then
      bouts[#bouts + 1] = { x[1], x[2] }
    end
  end
  return update(t, { bouts = bouts })
end

function T.StartNight(id)
  local t = T.Get(id)
  if not t or not T.CanManage(t) then
    return nil, "permiso"
  end
  if #t.d.bouts == 0 then
    return nil, "vacía"
  end
  return update(t, { state = "RUNNING", startedAt = Store.Now() })
end

-- A match decided by hand (someone did not come), or nil to let the duels decide it again.
function T.Decide(id, key, winner)
  local t = T.Get(id)
  if not t or not T.CanManage(t) then
    return nil, "permiso"
  end
  local ov = {}
  for k, v in pairs(t.d.ov) do
    ov[k] = v
  end
  ov[key] = winner and Names.Short(winner) or nil
  return update(t, { ov = ov })
end

-- Seeding and the draw ----------------------------------------------------------------------------------------------
-- Standard seeding: 1 v S at the top, 2 at the bottom ({ [position] = seed }).
function T.Order(S)
  local o = { 1 }
  local n = 1
  while n < S do
    local nxt = {}
    for _, s in ipairs(o) do
      nxt[#nxt + 1] = s
      nxt[#nxt + 1] = 2 * n + 1 - s
    end
    o, n = nxt, n * 2
  end
  return o
end

function T.SizeFor(n)
  local s = 2
  while s < n do
    s = s * 2
  end
  return s
end

-- Seeds kept out of the draw: the best of the Arena (rated this season), as many as max(2, S/4).
function T.SeedList(entries)
  local rated, other = {}, {}
  for _, n in ipairs(entries) do
    local f = BG.Arena and BG.Arena.Fighter(n)
    if f then
      rated[#rated + 1] = { name = n, rating = f.rating, fights = f.fights }
    else
      other[#other + 1] = n
    end
  end
  table.sort(rated, function(a, b)
    if a.rating ~= b.rating then
      return a.rating > b.rating
    end
    if a.fights ~= b.fights then
      return a.fights > b.fights
    end
    return a.name < b.name
  end)
  local S = T.SizeFor(#entries)
  local k = math.min(#rated, math.max(2, S / 4))
  local seeds, rest = {}, {}
  for i, r in ipairs(rated) do
    if i <= k then
      seeds[#seeds + 1] = r.name
    else
      rest[#rest + 1] = r.name
    end
  end
  for _, n in ipairs(other) do
    rest[#rest + 1] = n
  end
  table.sort(rest)
  return seeds, rest
end

local function finishDraw(ok, why)
  local d = T.drawing
  T.drawing = nil
  if not ok then
    BG:Notify("No se pudo sortear", why == "tirada" and "El juego no devolvió la tirada (/roll). Vuelve a pulsar «Sortear y empezar»." or ("No se pudo (" .. tostring(why) .. ")."),
      { kind = "warning", view = "arena" })
    BG:Fire("BG_TOURNEY_CHANGED")
    return nil, why
  end
  local t = T.Get(d.id)
  local r, w = update(t, { state = "RUNNING", startedAt = Store.Now(), order = d.order, rolls = d.rolls, seeds = d.seeds, size = T.SizeFor(#d.order) })
  BG:Fire("BG_TOURNEY_CHANGED")
  return r, w
end

-- One roll at a time: /roll 1-m, then the game's line with our name and that range (CHAT_MSG_SYSTEM).
local function nextRoll()
  local d = T.drawing
  if not d then
    return
  end
  if #d.rest <= 1 then
    if d.rest[1] then
      d.order[#d.order + 1] = table.remove(d.rest, 1)
    end
    return finishDraw(true)
  end
  d.m = #d.rest
  d.asked = GetTime()
  d.tries = (d.tries or 0) + 1
  if d.tries > 3 then
    return finishDraw(false, "tirada")
  end
  local ok = pcall(BG.RandomRoll, 1, d.m)
  if not ok then
    return finishDraw(false, "tirada")
  end
  local step = #d.rolls
  C_Timer.After(ROLL_WAIT, function()
    if T.drawing == d and #d.rolls == step and d.asked and GetTime() - d.asked >= ROLL_WAIT - 0.1 then
      nextRoll() -- (no answer: roll again, up to three times)
    end
  end)
  BG:Fire("BG_TOURNEY_CHANGED")
end

function T.OnRoll(msg)
  local d = T.drawing
  if not d or not d.m or secret(msg) then
    return
  end
  local args = BG.Arena.Scan(BG.Arena.Format("RANDOM_ROLL_RESULT"), msg)
  if not args or not Names.IsMe(args[1]) or args[3] ~= 1 or args[4] ~= d.m then
    return
  end
  local v = args[2]
  if type(v) ~= "number" or v < 1 or v > d.m then
    return
  end
  d.rolls[#d.rolls + 1] = v
  d.order[#d.order + 1] = table.remove(d.rest, v)
  d.m, d.tries = nil, 0
  nextRoll()
end

function T.Draw(id)
  local t = T.Get(id)
  if not t or not T.CanManage(t) then
    return nil, "permiso"
  end
  if t.d.kind ~= "CUP" or t.d.state ~= "OPEN" then
    return nil, "cerrado"
  end
  if T.drawing then
    return nil, "sorteando"
  end
  local entries = T.Entries(id)
  if #entries < 2 then
    return nil, "pocos"
  end
  if not RandomRoll then
    return nil, "sin juego"
  end
  local seeds, rest = T.SeedList(entries)
  T.drawing = { id = id, order = seeds, seeds = #seeds, rest = rest, rolls = {}, tries = 0 }
  nextRoll()
  return true
end

-- The bracket -------------------------------------------------------------------------------------------------------
-- The first duel between a and b at `since` or later: winner, method, time, row id.
local function duelBetween(a, b, since)
  local best
  for _, r in ipairs(Store.List("duels")) do
    local d = r.d
    if r.at >= since and ((d.w == a and d.l == b) or (d.w == b and d.l == a)) and (not best or r.at < best.at or (r.at == best.at and r.id < best.id)) then
      best = r
    end
  end
  if best then
    return best.d.w, best.d.m, best.at, best.id
  end
end

-- Every match by round: { key = "r.i", round, a, b (a name, false for nobody, nil while waiting), winner, method
-- ("K", "F", "W" by hand, "B" a bye), at, row }, and the champion.
function T.Bracket(t)
  local d = t.d
  local S = T.SizeFor(#d.order)
  local slots = {}
  for pos, seed in ipairs(T.Order(S)) do
    slots[pos] = d.order[seed] or false
  end
  local rounds, R = {}, 0
  local n = S
  while n > 1 do
    R = R + 1
    n = n / 2
  end
  local start = d.startedAt or 0
  local prev
  for r = 1, R do
    local list = {}
    local count = S / 2 ^ r
    for i = 1, count do
      local m = { key = r .. "." .. i, round = r, index = i }
      if r == 1 then
        m.a, m.b, m.ready = slots[2 * i - 1], slots[2 * i], start
      else
        local fa, fb = prev[2 * i - 1], prev[2 * i]
        m.a, m.b = fa.winner, fb.winner
        m.ready = (fa.at and fb.at) and math.max(fa.at, fb.at) or nil
      end
      if m.a ~= nil and m.b ~= nil then
        local manual = d.ov[m.key]
        if m.a == false and m.b == false then
          m.winner, m.method, m.at = false, "B", m.ready
        elseif m.a == false or m.b == false then
          m.winner, m.method, m.at = m.a or m.b, "B", m.ready
        elseif manual and (manual == m.a or manual == m.b) then
          m.winner, m.method, m.at = manual, "W", m.ready
        elseif t.d.state == "RUNNING" then
          local w, how, at, row = duelBetween(m.a, m.b, m.ready or start)
          if w then
            m.winner, m.method, m.at, m.row = w, how, at, row
          end
        end
        if m.winner then
          m.loser = (m.winner == m.a) and m.b or m.a
        end
      end
      list[i] = m
    end
    rounds[r] = list
    prev = list
  end
  local final = rounds[R] and rounds[R][1]
  return { size = S, rounds = R, matches = rounds, champion = final and final.winner or nil, slots = slots }
end

function T.Champion(t)
  if t.d.kind ~= "CUP" or t.d.state ~= "RUNNING" then
    return nil
  end
  return T.Bracket(t).champion or nil
end

-- A fight night's bouts with their result.
function T.Bouts(t)
  local out = {}
  for i, b in ipairs(t.d.bouts) do
    local o = { i = i, a = b[1], b = b[2], key = "0." .. i }
    local manual = t.d.ov[o.key]
    if manual and (manual == o.a or manual == o.b) then
      o.winner, o.method = manual, "W"
    elseif t.d.state == "RUNNING" then
      o.winner, o.method, o.at, o.row = duelBetween(o.a, o.b, t.d.startedAt or 0)
    end
    out[i] = o
  end
  return out
end

function T.RoundName(R, r)
  local left = R - r
  return left == 0 and "Final" or (left == 1 and "Semifinales" or (left == 2 and "Cuartos" or ("Ronda " .. r)))
end

-- A duel that just came in: if it decided a match, the guild hears it (and, at the final, who won the cup).
function T.CheckDuel(row)
  for _, t in ipairs(Store.List("tourneys", function(x)
    return x.d.state == "RUNNING"
  end)) do
    if t.d.kind == "CUP" then
      local b = T.Bracket(t)
      for r, list in ipairs(b.matches) do
        for _, m in ipairs(list) do
          if m.row == row.id then
            if r == b.rounds then
              BG:Notify("¡" .. m.winner .. " gana «" .. t.d.title .. "»!", "En la final contra " .. tostring(m.loser) .. ". Enhorabuena al campeón.",
                { kind = "success", view = "arena", icon = "Interface\\Icons\\INV_Misc_Trophy_03", sound = "READY_CHECK" })
            else
              BG:Notify(t.d.title .. ": " .. m.winner .. " pasa", "Gana a " .. tostring(m.loser) .. " y pasa a " .. T.RoundName(b.rounds, r + 1):lower() .. ".",
                { kind = "info", view = "arena", icon = "Interface\\Icons\\INV_Misc_Trophy_03" })
            end
          end
        end
      end
    else
      for _, o in ipairs(T.Bouts(t)) do
        if o.row == row.id then
          BG:Notify(t.d.title .. ": gana " .. o.winner, (o.winner == o.a and o.b or o.a) .. " cae en el combate de la velada.", { kind = "info", view = "arena" })
        end
      end
    end
  end
end

-- Events -------------------------------------------------------------------------------------------------------------
BG:On("CHAT_MSG_SYSTEM", function(msg)
  T.OnRoll(msg)
end)
BG:On("BG_DUEL_ADDED", function(row)
  T.CheckDuel(row)
  BG:Fire("BG_TOURNEY_CHANGED")
end)
BG:On("BG_STORE_CHANGED", function(name)
  if name == "tourneys" or name == "tentries" or name == "duels" then
    BG:Fire("BG_TOURNEY_CHANGED")
  end
end)
