-- «Huesos» (entrega 12, tercera parte; Olympus' Farkle, MIT: the idea of the six dice from one /roll of 1-6^n read
-- from the server's line is theirs; the rules and the rest are our own). Points only: no gold, no stakes.
--
-- The tavern dice game (Farkle). Throw the dice, set aside the ones that score, then throw the rest again or bank
-- the turn's points. A throw where nothing scores loses the turn's points. All six set aside: throw all six again.
-- First to 3000 wins. Scoring: a 1 is 100, a 5 is 50; three of a kind is the face × 100 (three 1s, 1000), and each
-- die more doubles it once more (four: ×2, five: ×3, six: ×4); a straight 1-6 is 1500; three pairs, 750.
-- The dice of a throw come from the game's own /roll of 1 to 6^n, written by the server where everyone near sees it:
-- one roll, n dice (its digits in base 6).
-- Against the house (practice, alone: its dice are local, nothing is sent or kept), or against a member with
-- BlazonGuild: an invitation (ZI) and its answer (ZA); each throw goes to the other (ZR), each choice too (ZK), and
-- giving up (ZQ). Both clients play the same game from the same moves. The loser's client writes the result
-- ("bones": only the loser, like the Arena's duels), and the guild sees who wins the most.
local _, BG = ...
local Bones = { game = nil, invites = {}, sent = {} }
BG.Bones = Bones
local Store, Names, Comm = BG.Store, BG.Names, BG.Comm
local str, int = BG.Raids.Clean, BG.Raids.Int

Bones.TARGET = 3000
local INVITE_TTL = 5 * 60
local ROLL_WAIT = 6
local HOUSE = "La casa"
Bones.HOUSE = HOUSE

local function secret(v)
  return issecretvalue ~= nil and issecretvalue(v)
end

-- Rules (pure) -------------------------------------------------------------------------------------------------
local function counts(dice)
  local c = { 0, 0, 0, 0, 0, 0 }
  for _, d in ipairs(dice) do
    c[d] = c[d] + 1
  end
  return c
end

-- What a set of dice set aside is worth, or nil if any of them does not score.
function Bones.Score(dice)
  if #dice == 0 then
    return nil
  end
  local c = counts(dice)
  if #dice == 6 then
    local straight, pairs_ = true, 0
    for f = 1, 6 do
      straight = straight and c[f] == 1
      pairs_ = pairs_ + (c[f] == 2 and 1 or 0)
    end
    if straight then
      return 1500
    end
    if pairs_ == 3 then
      return 750
    end
  end
  local v = 0
  for f = 1, 6 do
    local n = c[f]
    if n >= 3 then
      v = v + (f == 1 and 1000 or f * 100) * (n - 2)
    elseif n > 0 then
      if f == 1 then
        v = v + 100 * n
      elseif f == 5 then
        v = v + 50 * n
      else
        return nil
      end
    end
  end
  return v
end

-- Which dice of a throw can be part of something that scores (the table makes them shine): all six on a straight or
-- three pairs; else the 1s, the 5s and those of three or more of a kind.
function Bones.Scorable(dice)
  local out = {}
  if not dice then
    return out
  end
  local c = counts(dice)
  local pairs_, distinct = 0, 0
  for v = 1, 6 do
    if c[v] > 0 then
      distinct = distinct + 1
    end
    if c[v] == 2 then
      pairs_ = pairs_ + 1
    end
  end
  local all = (#dice == 6 and (distinct == 6 or pairs_ == 3))
  for i, v in ipairs(dice) do
    out[i] = all or v == 1 or v == 5 or c[v] >= 3
  end
  return out
end

-- The best set aside from a throw (the indexes of the dice) and its worth; nil when nothing scores (a «huesos»).
function Bones.Best(dice)
  if #dice == 6 and Bones.Score(dice) then
    local all = {}
    for i = 1, 6 do
      all[i] = i
    end
    return all, Bones.Score(dice)
  end
  local c = counts(dice)
  local keep = {}
  for i, d in ipairs(dice) do
    if d == 1 or d == 5 or c[d] >= 3 then
      keep[#keep + 1] = i
    end
  end
  if #keep == 0 then
    return nil
  end
  local sel = {}
  for _, i in ipairs(keep) do
    sel[#sel + 1] = dice[i]
  end
  return keep, Bones.Score(sel)
end

-- 6^n as a whole number (the /roll's top: "46656", never "46656.0").
local function sixTo(n)
  local m = 1
  for _ = 1, n do
    m = m * 6
  end
  return m
end
Bones.SixTo = sixTo

-- A /roll of 1 to 6^n as n dice (its value minus one, in base 6).
function Bones.Decode(value, n)
  local v = value - 1
  local dice = {}
  for i = 1, n do
    dice[i] = v % 6 + 1
    v = math.floor(v / 6)
  end
  return dice
end

-- The game (the same moves on both clients) ----------------------------------------------------------------------
local function newGame(id, a, b, vsHouse)
  return { id = id, players = { a, b }, score = { 0, 0 }, turn = 1, pts = 0, left = 6, dice = nil, phase = "roll",
    house = vsHouse, log = {}, started = GetTime(), kept = {}, rolls = 0 }
end

local function log(g, text)
  table.insert(g.log, 1, text)
  g.log[9] = nil
end

local function pass(g)
  g.turn = 3 - g.turn
  g.pts, g.left, g.dice, g.phase = 0, 6, nil, "roll"
  g.kept = {}
end

local function finish(g, winner, why)
  g.phase, g.winner, g.why = "over", winner, why
  log(g, winner .. " gana la partida" .. (why == "quit" and " (el otro se rinde)" or "") .. ".")
  BG:Fire("BG_BONES_OVER", g)
end

-- A throw's dice for the player whose turn it is.
function Bones.ApplyRoll(g, dice)
  if g.phase ~= "roll" or #dice ~= g.left then
    return nil, "fuera de turno"
  end
  g.dice = dice
  local who = g.players[g.turn]
  -- (what the table shows: every throw, a farkle's too, which passes the turn at once)
  g.rolls = (g.rolls or 0) + 1
  g.lastRoll = { n = g.rolls, who = who, dice = dice, farkle = not Bones.Best(dice), lost = g.pts, at = GetTime() }
  if not Bones.Best(dice) then
    log(g, who .. " saca " .. table.concat(dice, " ") .. ": ¡huesos! Pierde " .. g.pts .. " puntos del turno.")
    g.lastFarkle = { who = who, dice = dice }
    pass(g)
    return "huesos"
  end
  g.phase = "keep"
  log(g, who .. " saca " .. table.concat(dice, " ") .. ".")
  return "keep"
end

-- The player whose turn it is sets aside `keep` (indexes of the throw) and throws again or banks.
function Bones.ApplyKeep(g, keep, bank)
  if g.phase ~= "keep" or not g.dice then
    return nil, "fuera de turno"
  end
  local sel, seen = {}, {}
  for _, i in ipairs(keep) do
    if not g.dice[i] or seen[i] then
      return nil, "dados"
    end
    seen[i] = true
    sel[#sel + 1] = g.dice[i]
  end
  local v = Bones.Score(sel)
  if not v or v <= 0 then
    return nil, "no puntúan"
  end
  local who = g.players[g.turn]
  g.pts = g.pts + v
  g.left = g.left - #sel
  g.kept = g.kept or {}
  for _, x in ipairs(sel) do
    g.kept[#g.kept + 1] = x
  end
  if g.left == 0 then
    g.left = 6 -- (all six set aside: all six again)
    g.kept = {}
    g.hotDice = (g.hotDice or 0) + 1
    log(g, who .. " aparta los seis: ¡a tirarlos todos otra vez!")
  end
  g.dice = nil
  if bank then
    g.lastBank = { who = who, pts = g.pts, n = (g.lastBank and g.lastBank.n or 0) + 1 }
    g.score[g.turn] = g.score[g.turn] + g.pts
    log(g, who .. " se planta con " .. g.pts .. ": lleva " .. g.score[g.turn] .. ".")
    if g.score[g.turn] >= Bones.TARGET then
      finish(g, who, "target")
      return "over"
    end
    pass(g)
    return "banked"
  end
  g.phase = "roll"
  return "again"
end

function Bones.MySeat(g)
  for i, p in ipairs(g.players) do
    if Names.IsMe(p) then
      return i
    end
  end
end

function Bones.MyTurn(g)
  return g and g.phase ~= "over" and Bones.MySeat(g) == g.turn
end

-- Throwing: our own /roll, read from the server's line -----------------------------------------------------------
local rolling
function Bones.Roll()
  local g = Bones.game
  if not Bones.MyTurn(g) or g.phase ~= "roll" then
    return nil, "fuera de turno"
  end
  if rolling then
    return nil, "tirando"
  end
  if not RandomRoll then
    return nil, "sin juego"
  end
  rolling = { n = g.left, max = sixTo(g.left), at = GetTime(), game = g.id }
  if not pcall(BG.RandomRoll, 1, rolling.max) then
    rolling = nil
    return nil, "sin juego"
  end
  local mine = rolling
  C_Timer.After(ROLL_WAIT, function()
    if rolling == mine then
      rolling = nil -- (no answer from the game: the button works again)
      BG:Fire("BG_BONES_CHANGED")
    end
  end)
  BG:Fire("BG_BONES_CHANGED")
  return true
end

function Bones.Rolling()
  return rolling ~= nil
end

local function onSystem(msg)
  if not rolling or secret(msg) then
    return
  end
  local args = BG.Arena.Scan(BG.Arena.Format("RANDOM_ROLL_RESULT"), msg)
  if not args or not Names.IsMe(args[1]) or args[3] ~= 1 or args[4] ~= rolling.max then
    return
  end
  local g = Bones.game
  local r = rolling
  rolling = nil
  if not g or g.id ~= r.game or not Bones.MyTurn(g) then
    return
  end
  local dice = Bones.Decode(args[2], r.n)
  Bones.ApplyRoll(g, dice)
  if not g.house then
    Comm.Send("ZR", { g = g.id, v = args[2], n = r.n }, "WHISPER", g.players[3 - Bones.MySeat(g)], { lane = "alert" })
  end
  BG:Fire("BG_BONES_CHANGED")
  Bones.HouseTurn()
end
BG:On("CHAT_MSG_SYSTEM", onSystem)

function Bones.Keep(keep, bank)
  local g = Bones.game
  if not Bones.MyTurn(g) then
    return nil, "fuera de turno"
  end
  local res, why = Bones.ApplyKeep(g, keep, bank)
  if not res then
    return nil, why
  end
  if not g.house then
    local k = {}
    for _, i in ipairs(keep) do
      k[#k + 1] = tostring(i)
    end
    Comm.Send("ZK", { g = g.id, k = table.concat(k), b = bank and true or nil }, "WHISPER", g.players[3 - Bones.MySeat(g)], { lane = "alert" })
  end
  BG:Fire("BG_BONES_CHANGED")
  Bones.HouseTurn()
  return res
end

-- The house (practice): it throws with local dice and plays a plain strategy: it banks with 300 or more when two
-- dice or fewer are left, or with 500 or more, or when it would reach the target.
function Bones.HouseTurn()
  local g = Bones.game
  if not (g and g.house and g.phase ~= "over" and g.players[g.turn] == HOUSE) or g.houseBusy then
    return
  end
  g.houseBusy = true
  C_Timer.After(1.2, function()
    g.houseBusy = false
    if Bones.game ~= g or g.phase == "over" or g.players[g.turn] ~= HOUSE then
      return
    end
    if g.phase == "roll" then
      local dice = {}
      for i = 1, g.left do
        dice[i] = math.random(1, 6)
      end
      Bones.ApplyRoll(g, dice)
    else
      local keep, v = Bones.Best(g.dice)
      local pts, left = g.pts + v, g.left - #keep
      local bank = left > 0 and (pts >= 500 or (pts >= 300 and left <= 2) or g.score[g.turn] + pts >= Bones.TARGET)
      Bones.ApplyKeep(g, keep, bank)
    end
    BG:Fire("BG_BONES_CHANGED")
    Bones.HouseTurn()
  end)
end

function Bones.Practice()
  local me = Names.Me()
  if not me then
    return nil, "sin personaje"
  end
  Bones.game = newGame("casa-" .. GetTime(), me, HOUSE, true)
  log(Bones.game, "Partida de práctica contra la casa. Empiezas tú.")
  BG:Fire("BG_BONES_CHANGED")
  return Bones.game
end

function Bones.Quit()
  local g = Bones.game
  if not g then
    return nil
  end
  if g.phase ~= "over" then
    local seat = Bones.MySeat(g)
    if not g.house then
      Comm.Send("ZQ", { g = g.id }, "WHISPER", g.players[3 - seat], { lane = "alert" })
    end
    finish(g, g.players[3 - seat], "quit")
  end
  Bones.game = nil
  BG:Fire("BG_BONES_CHANGED")
  return true
end

-- Against a member ---------------------------------------------------------------------------------------------------
function Bones.Invite(name)
  local m = BG.Guild.Find(name or "")
  if not m then
    return nil, "no es de tu hermandad"
  end
  local target = Names.Short(m.name)
  if Names.IsMe(target) then
    return nil, "tú mismo"
  end
  if not (m.online and BG.Peers.Get(target)) then
    return nil, "sin addon"
  end
  if Bones.game and Bones.game.phase ~= "over" then
    return nil, "jugando"
  end
  local id = (Names.Me() or "?"):gsub("%s", "") .. "-" .. Store.Now() .. BG.Alliance.RandomId(2)
  Bones.sent[target] = { id = id, at = GetTime() }
  Comm.Send("ZI", { g = id }, "WHISPER", target, { lane = "alert" })
  BG:Fire("BG_BONES_CHANGED")
  return id
end

Comm.Register("ZI", function(sender, b)
  local who = Names.Short(sender)
  if type(b) ~= "table" or type(b.g) ~= "string" or not who or not BG.Guild.Find(who) then
    return
  end
  Bones.invites[who] = { name = who, id = str(b.g, 60), at = GetTime() }
  BG:Notify(who .. " te invita a los Huesos", "Una partida de dados por puntos (a 3000). Ábrelo en la Arena, pestaña «Taberna».",
    { kind = "info", view = "arena", sound = "READY_CHECK", icon = "Interface\\Buttons\\UI-GroupLoot-Dice-Up" })
  BG:Fire("BG_BONES_CHANGED")
end, { channels = { "WHISPER" }, maxBytes = 120 })

function Bones.Invites()
  local out, t = {}, GetTime()
  for name, i in pairs(Bones.invites) do
    if t - i.at > INVITE_TTL then
      Bones.invites[name] = nil
    else
      out[#out + 1] = i
    end
  end
  table.sort(out, function(a, b)
    return a.at > b.at
  end)
  return out
end

-- Accepting starts the game on both sides (the one who invited throws first).
function Bones.Answer(name, yes)
  local who = Names.Short(name)
  local inv = who and Bones.invites[who]
  if not inv then
    return nil, "no existe"
  end
  Bones.invites[who] = nil
  Comm.Send("ZA", { g = inv.id, y = yes == true }, "WHISPER", who, { lane = "alert" })
  if yes then
    if Bones.game and Bones.game.phase ~= "over" then
      Bones.Quit()
    end
    Bones.game = newGame(inv.id, who, Names.Me(), false)
    log(Bones.game, "Partida contra " .. who .. ". Empieza " .. who .. ".")
  end
  BG:Fire("BG_BONES_CHANGED")
  return true
end

Comm.Register("ZA", function(sender, b)
  local who = Names.Short(sender)
  local sent = who and Bones.sent[who]
  if type(b) ~= "table" or not sent or b.g ~= sent.id then
    return
  end
  Bones.sent[who] = nil
  if b.y == true then
    Bones.game = newGame(sent.id, Names.Me(), who, false)
    log(Bones.game, "Partida contra " .. who .. ". Empiezas tú.")
    BG:Notify(who .. " acepta", "Empiezas tú: pulsa «Tirar» en la Taberna.", { kind = "success", view = "arena" })
  else
    BG:Notify(who .. " no quiere jugar ahora", "Quizá en otro momento.", { kind = "info", view = "arena" })
  end
  BG:Fire("BG_BONES_CHANGED")
end, { channels = { "WHISPER" }, maxBytes = 80 })

-- The other player's moves (only from them, only in their turn, only in this game).
local function theirs(sender, b)
  local g = Bones.game
  local who = Names.Short(sender)
  if not g or g.house or type(b) ~= "table" or b.g ~= g.id or g.phase == "over" then
    return nil
  end
  local seat = Bones.MySeat(g)
  if not seat or not Names.Same(g.players[3 - seat], who) or g.turn ~= 3 - seat then
    return nil
  end
  return g
end

Comm.Register("ZR", function(sender, b)
  local g = theirs(sender, b)
  local v, n = g and int(b.v, 1, 46656), g and int(b.n, 1, 6)
  if not (g and v and n == g.left and v <= sixTo(n)) then
    return
  end
  Bones.ApplyRoll(g, Bones.Decode(v, n))
  BG:Fire("BG_BONES_CHANGED")
end, { channels = { "WHISPER" }, maxBytes = 60 })

Comm.Register("ZK", function(sender, b)
  local g = theirs(sender, b)
  if not g or type(b.k) ~= "string" or #b.k > 6 then
    return
  end
  local keep = {}
  for ch in b.k:gmatch("%d") do
    keep[#keep + 1] = tonumber(ch)
  end
  Bones.ApplyKeep(g, keep, b.b == true)
  BG:Fire("BG_BONES_CHANGED")
end, { channels = { "WHISPER" }, maxBytes = 60 })

Comm.Register("ZQ", function(sender, b)
  local g = Bones.game
  local who = Names.Short(sender)
  if not g or g.house or type(b) ~= "table" or b.g ~= g.id or g.phase == "over" then
    return
  end
  local seat = Bones.MySeat(g)
  if seat and Names.Same(g.players[3 - seat], who) then
    finish(g, g.players[seat], "quit")
    BG:Fire("BG_BONES_CHANGED")
  end
end, { channels = { "WHISPER" }, maxBytes = 60 })

-- Results and the ranking --------------------------------------------------------------------------------------------
-- d = { w = winner, l = loser, ws, ls (their points) }; written only by the loser, about their own defeat.
Store.Define("bones", {
  ttl = 90 * 86400,
  can = function(author, r)
    local prefix = author:gsub("%s", "") .. "-"
    if r.del then
      return r.id:sub(1, #prefix) == prefix or Store.IsOrganiser(author)
    end
    return r.id:sub(1, #prefix) == prefix and Names.Same(r.d.l, author)
  end,
  normalize = function(d)
    local w, l = Names.Short(str(d.w, 40)), Names.Short(str(d.l, 40))
    if not w or not l or w == l then
      return nil
    end
    return { w = w, l = l, ws = int(d.ws, 0, 100000), ls = int(d.ls, 0, 100000) }
  end,
})

BG:On("BG_BONES_OVER", function(g)
  if g.house then
    BG:Notify(Names.IsMe(g.winner) and "¡Le ganas a la casa!" or "Gana la casa", "Partida de práctica: " .. g.score[1] .. " a " .. g.score[2] .. ".", { kind = "info", view = "arena" })
    return
  end
  local seat = Bones.MySeat(g)
  if not seat then
    return
  end
  if Names.IsMe(g.winner) then
    BG:Notify("¡Ganas a los Huesos!", "Contra " .. g.players[3 - seat] .. ": " .. g.score[seat] .. " a " .. g.score[3 - seat] .. ".", { kind = "success", view = "arena" })
  else
    local me = Names.Me()
    Store.Put("bones", me:gsub("%s", "") .. "-" .. Store.Now() .. BG.Alliance.RandomId(2), { w = g.winner, l = me, ws = g.score[3 - seat], ls = g.score[seat] })
    BG:Notify("Gana " .. g.winner, "A los Huesos: " .. g.score[3 - seat] .. " a " .. g.score[seat] .. ". ¡La próxima!", { kind = "info", view = "arena" })
  end
end)

function Bones.Ranking(limit)
  local wins, played, order = {}, {}, {}
  for _, r in ipairs(Store.List("bones")) do
    for _, n in ipairs({ r.d.w, r.d.l }) do
      if not played[n] then
        played[n], wins[n] = 0, 0
        order[#order + 1] = n
      end
      played[n] = played[n] + 1
    end
    wins[r.d.w] = wins[r.d.w] + 1
  end
  table.sort(order, function(a, b)
    if wins[a] ~= wins[b] then
      return wins[a] > wins[b]
    end
    if played[a] ~= played[b] then
      return played[a] < played[b]
    end
    return a < b
  end)
  local out = {}
  for i = 1, math.min(limit or 10, #order) do
    out[i] = { name = order[i], wins = wins[order[i]], played = played[order[i]] }
  end
  return out
end

-- The innkeeper: talking to one (their dialog offers to make the inn your home) brings a word about the game.
-- Nothing in the game's dialog is touched: only our notice, once per innkeeper and session.
local told = {}
local function isInnkeeper()
  if C_GossipInfo and C_GossipInfo.GetOptions then
    local ok, opts = pcall(C_GossipInfo.GetOptions)
    if ok and type(opts) == "table" then
      for _, o in ipairs(opts) do
        if type(o) == "table" and not secret(o.icon) and (o.icon == 132052 or (type(o.icon) == "string" and o.icon:find("Binder"))) then
          return true
        end
      end
    end
  end
  if GetGossipOptions then
    local ok, list = pcall(function()
      return { GetGossipOptions() }
    end)
    if ok then
      for _, v in ipairs(list) do
        if v == "binder" then
          return true
        end
      end
    end
  end
  return false
end

BG:On("GOSSIP_SHOW", function()
  if not isInnkeeper() then
    return
  end
  local okN, npc = pcall(UnitName, "npc")
  local key = (okN and not secret(npc) and npc) or "posadero"
  if told[key] then
    return
  end
  told[key] = true
  BG:Notify("¿Unos Huesos en la posada?", "Echa una partida de dados por puntos: contra la casa para practicar, o retando a alguien de la hermandad. Arena, pestaña «Taberna».",
    { kind = "info", view = "arena", icon = "Interface\\Buttons\\UI-GroupLoot-Dice-Up" })
end)
