-- La lotería de práctica (entrega 12, tercera parte; Olympus' practice lottery, MIT, as an idea: free tickets, no
-- gold). Each day every member may take up to three free tickets, a number from 1 to 100 each ("ltickets", their
-- own). An organiser draws the day's number with the game's own /roll 1-100, which everyone near sees ("lotto", one
-- record per day); whoever has that number hits, and the guild hears it. Points only: nothing is paid, nothing bet.
local _, BG = ...
local Lotto = { drawing = nil }
BG.Lotto = Lotto
local Store, Names = BG.Store, BG.Names
local str, int = BG.Raids.Clean, BG.Raids.Int

local MAX_TICKETS = 3
local ROLL_WAIT = 6
Lotto.MAX_TICKETS = MAX_TICKETS

local function secret(v)
  return issecretvalue ~= nil and issecretvalue(v)
end

-- The day, as the server counts it (UTC): "20261113".
function Lotto.Today(t)
  return date("!%Y%m%d", t or Store.Now())
end

Store.Define("lotto", {
  ttl = 30 * 86400,
  can = function(author)
    return Store.IsOrganiser(author)
  end,
  normalize = function(d)
    local n = int(d.n, 1, 100)
    if not n then
      return nil
    end
    return { n = n }
  end,
})

Store.Define("ltickets", {
  ttl = 30 * 86400,
  can = function(author, r)
    return Names.Same(r.id:match("|(.+)$"), author) -- (each one takes their own tickets)
  end,
  normalize = function(d, r)
    local name = Names.Short(str(d.name, 40))
    local day = type(d.day) == "string" and d.day:match("^%d%d%d%d%d%d%d%d$")
    if not name or not day or r.id ~= day .. "|" .. name then
      return nil
    end
    local nums, have = {}, {}
    for _, v in ipairs(type(d.n) == "table" and d.n or {}) do
      local x = int(v, 1, 100)
      if x and not have[x] and #nums < MAX_TICKETS then
        have[x] = true
        nums[#nums + 1] = x
      end
    end
    return { day = day, name = name, n = nums }
  end,
})

function Lotto.Drawn(day)
  local r = Store.Get("lotto", day or Lotto.Today())
  return r and not r.del and r.d.n or nil
end

function Lotto.Mine(day)
  local me = Names.Me()
  local r = me and Store.Get("ltickets", (day or Lotto.Today()) .. "|" .. me)
  return r and not r.del and r.d.n or {}
end

function Lotto.Take(number)
  local n = tonumber(number)
  if not n or n ~= math.floor(n) or n < 1 or n > 100 then
    return nil, "número" -- (a number from 1 to 100: 150 is not taken as 100)
  end
  local day = Lotto.Today()
  if Lotto.Drawn(day) then
    return nil, "sorteado"
  end
  local mine = Lotto.Mine(day)
  local list = {}
  for _, x in ipairs(mine) do
    if x == n then
      return nil, "repetido"
    end
    list[#list + 1] = x
  end
  if #list >= MAX_TICKETS then
    return nil, "lleno"
  end
  list[#list + 1] = n
  local me = Names.Me()
  return Store.Put("ltickets", day .. "|" .. me, { day = day, name = me, n = list })
end

-- Who took tickets today, and who has the drawn number.
function Lotto.Players(day)
  day = day or Lotto.Today()
  local out = {}
  for _, r in ipairs(Store.List("ltickets", function(x)
    return x.d.day == day
  end)) do
    out[#out + 1] = r.d
  end
  table.sort(out, function(a, b)
    return a.name < b.name
  end)
  return out
end

function Lotto.Winners(day)
  day = day or Lotto.Today()
  local n = Lotto.Drawn(day)
  local out = {}
  if not n then
    return out
  end
  for _, p in ipairs(Lotto.Players(day)) do
    for _, x in ipairs(p.n) do
      if x == n then
        out[#out + 1] = p.name
      end
    end
  end
  return out
end

-- The last days drawn: { day, n, winners }, newest first.
function Lotto.History(limit)
  local list = Store.List("lotto")
  table.sort(list, function(a, b)
    return a.id > b.id
  end)
  local out = {}
  for i = 1, math.min(limit or 5, #list) do
    out[i] = { day = list[i].id, n = list[i].d.n, winners = Lotto.Winners(list[i].id) }
  end
  return out
end

-- The draw: an organiser's /roll 1-100, read from the server's line.
function Lotto.Draw()
  if not Store.IsOrganiser(Names.Me() or "") then
    return nil, "permiso"
  end
  local day = Lotto.Today()
  if Lotto.Drawn(day) then
    return nil, "sorteado"
  end
  if not RandomRoll then
    return nil, "sin juego"
  end
  if Lotto.drawing then
    return nil, "sorteando"
  end
  Lotto.drawing = { day = day, at = GetTime() }
  if not pcall(BG.RandomRoll, 1, 100) then
    Lotto.drawing = nil
    return nil, "sin juego"
  end
  local mine = Lotto.drawing
  C_Timer.After(ROLL_WAIT, function()
    if Lotto.drawing == mine then
      Lotto.drawing = nil
      BG:Fire("BG_LOTTO_CHANGED")
    end
  end)
  return true
end

local function announce(day, n)
  local w = Lotto.Winners(day)
  BG:Notify("Lotería: ha salido el " .. n, #w > 0 and ("Aciertan: " .. table.concat(w, ", ") .. ". ¡Enhorabuena!") or "Nadie lo tenía. Mañana, más boletos gratis.",
    { kind = #w > 0 and "success" or "info", view = "arena", icon = "Interface\\Icons\\INV_Misc_Note_02" })
end

BG:On("CHAT_MSG_SYSTEM", function(msg)
  local d = Lotto.drawing
  if not d or secret(msg) then
    return
  end
  local args = BG.Arena.Scan(BG.Arena.Format("RANDOM_ROLL_RESULT"), msg)
  if not args or not Names.IsMe(args[1]) or args[3] ~= 1 or args[4] ~= 100 then
    return
  end
  Lotto.drawing = nil
  if Store.Put("lotto", d.day, { n = args[2] }) then
    announce(d.day, args[2])
  end
  BG:Fire("BG_LOTTO_CHANGED")
end)

BG:On("BG_RECORD", function(kind, r, old)
  if kind == "lotto" and not r.del and not old then
    announce(r.id, r.d.n)
  end
  if kind == "lotto" or kind == "ltickets" then
    BG:Fire("BG_LOTTO_CHANGED")
  end
end)
BG:On("BG_STORE_CHANGED", function(name)
  if name == "lotto" or name == "ltickets" or name == "bones" then
    BG:Fire("BG_LOTTO_CHANGED")
  end
end)
