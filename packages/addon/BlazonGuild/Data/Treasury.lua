-- Tesorería (entrega 9; Olympus' Treasury.lua, Dues.lua, Bank.lua, Campaign.lua, GuildFinance.lua and
-- Backup.lua, MIT, our own implementation). The addon never moves gold: it writes down what players do.
--
-- The master names the treasurers. A treasurer's client keeps the book: gold a guildmate gives them by trade
-- or by mail is a donation, gold they give is a payment, written by itself the moment it happens (the trade
-- completes, the mail's gold is taken or sent); the treasurer can also write a line by hand, give each line its
-- purpose and put it towards a campaign. The book's balance is what came in less what went out.
-- Dues: the master may set a fixed amount a week; each member's donations of that week count towards it. The
-- organisers see who paid; each member sees their own. Organisers can mark someone exempt.
-- Campaigns: a goal ("100 de oro para pociones de banda") and the donations put towards it.
-- Guild bank: when an organiser or a treasurer opens it, a snapshot of its gold and items goes to the guild.
-- What members see is the master's choice: the balance, the donors' ranking, the book (organisers see all).
-- The records travel to every guildmate with the addon: the switches choose what the screens show.
local _, BG = ...
local Treasury = {}
BG.Treasury = Treasury
local Store, Names = BG.Store, BG.Names
local str, int = BG.Raids.Clean, BG.Raids.Int

local MAX_COPPER = 2147483647
local MAX_KEEPERS = 6
local WEEK = 7 * 86400

-- Gold as people read it: "12 de oro, 34 de plata" (no copper below a gold piece's worth).
function Treasury.Money(c)
  c = math.floor(tonumber(c) or 0)
  local neg = c < 0
  c = math.abs(c)
  local g, s, cu = math.floor(c / 10000), math.floor(c / 100) % 100, c % 100
  local parts = {}
  if g > 0 then
    parts[#parts + 1] = BG.TF("%s de oro", g)
  end
  if s > 0 then
    parts[#parts + 1] = BG.TF("%s de plata", s)
  end
  if g == 0 and (cu > 0 or s == 0) then
    parts[#parts + 1] = BG.TF("%s de cobre", cu)
  end
  return (neg and "-" or "") .. table.concat(parts, ", ")
end

-- Short, for a big figure: the game's coin icons when it has them, else "12o 30p" (0 is "0").
function Treasury.MoneyShort(c)
  c = math.floor(tonumber(c) or 0)
  if c == 0 then
    return "0"
  end
  local neg, a = c < 0, math.abs(c)
  if GetCoinTextureString then
    local ok, s = pcall(GetCoinTextureString, a, 18)
    if ok and type(s) == "string" and s ~= "" then
      return (neg and "-" or "") .. s
    end
  end
  local g, s, cu = math.floor(a / 10000), math.floor(a / 100) % 100, a % 100
  local parts = {}
  if g > 0 then
    parts[#parts + 1] = g .. "o"
  end
  if s > 0 then
    parts[#parts + 1] = s .. "p"
  end
  if g == 0 and cu > 0 then
    parts[#parts + 1] = cu .. "c"
  end
  return (neg and "-" or "") .. table.concat(parts, " ")
end

-- "12", "12.5", "12o 30p", "1250c" -> copper. Also with the English and German letters: "12g 30s", "5k".
function Treasury.ParseMoney(text)
  text = type(text) == "string" and text:lower():gsub(",", ".") or ""
  local g, s, c = text:match("(%d+)%s*[og]"), text:match("(%d+)%s*[ps]"), text:match("(%d+)%s*[ck]")
  if g or s or c then
    return (tonumber(g) or 0) * 10000 + (tonumber(s) or 0) * 100 + (tonumber(c) or 0)
  end
  local n = tonumber(text:match("^%s*([%d%.]+)%s*$"))
  return n and math.floor(n * 10000 + 0.5) or nil
end

-- The current week: from the last weekly reset (the game's own clock when it has it; else Wednesday 07:00 UTC).
function Treasury.WeekStart(t)
  if not t and C_DateAndTime and C_DateAndTime.GetSecondsUntilWeeklyReset then
    local ok, left = pcall(C_DateAndTime.GetSecondsUntilWeeklyReset)
    if ok and tonumber(left) then
      return math.floor((Store.Now() + left - WEEK) / 3600 + 0.5) * 3600 -- (to the hour: the same for every client)
    end
  end
  t = t or Store.Now()
  local epoch = 6 * 86400 + 7 * 3600 -- 1970-01-07 (a Wednesday) 07:00 UTC
  return t - ((t - epoch) % WEEK)
end

-- Shared records -----------------------------------------------------------------------------------------------
-- The master's settings: who keeps the book, the weekly dues, what members see, who is exempt.
Store.Define("treasury", {
  can = function(author, r)
    return Store.IsMaster(author) or (r.id == "exempt" and Store.IsOrganiser(author))
  end,
  normalize = function(d, r)
    if r and r.id == "exempt" then
      local names = {}
      for i = 1, math.min(200, #(type(d.names) == "table" and d.names or {})) do
        local n = Names.Short(str(d.names[i], 40))
        if n then
          names[#names + 1] = n
        end
      end
      return { names = names }
    end
    local keepers = {}
    for i = 1, math.min(MAX_KEEPERS, #(type(d.keepers) == "table" and d.keepers or {})) do
      local n = Names.Short(str(d.keepers[i], 40))
      if n then
        keepers[#keepers + 1] = n
      end
    end
    local show = type(d.show) == "table" and d.show or {}
    return { keepers = keepers, dues = int(d.dues, 0, MAX_COPPER) or 0,
      show = { bal = show.bal ~= false, rank = show.rank == true, book = show.book == true } }
  end,
})

local KINDS = { IN = true, OUT = true }
local VIA = { TRADE = "comercio", MAIL = "correo", HAND = "a mano" }

-- A line of the book: id "<treasurer>-<time>-<n>". Written by the treasurer (and the master, to fix it).
Store.Define("ledger", {
  ttl = 400 * 86400,
  can = function(author, r)
    local prefix = author:gsub("%s", "") .. "-"
    return (r.id:sub(1, #prefix) == prefix and Treasury.IsKeeper(author)) or Store.IsMaster(author)
  end,
  normalize = function(d)
    if not KINDS[d.k] then
      return nil
    end
    local c = int(d.c, 1, MAX_COPPER)
    if not c then
      return nil
    end
    return { k = d.k, c = c, who = Names.Short(str(d.who, 40)) or "?", via = VIA[d.via] and d.via or "HAND", note = str(d.note, 100),
      camp = str(d.camp, 24), w = int(d.w, 0, 4e9), keeper = Names.Short(str(d.keeper, 40)) }
  end,
})

Store.Define("campaigns", {
  ttl = 120 * 86400,
  can = function(author)
    return Store.IsOrganiser(author) or Treasury.IsKeeper(author)
  end,
  normalize = function(d)
    local title = str(d.title, 60)
    local goal = int(d.goal, 1, MAX_COPPER)
    if not title or title == "" or not goal then
      return nil
    end
    return { title = title, goal = goal, untilT = int(d.untilT, 0, 4e9), done = d.done == true or nil }
  end,
})

-- The guild bank as an organiser or a treasurer last saw it.
Store.Define("gbank", {
  can = function(author)
    return Store.IsOrganiser(author) or Treasury.IsKeeper(author)
  end,
  normalize = function(d)
    local tabs = {}
    for i = 1, math.min(8, #(type(d.tabs) == "table" and d.tabs or {})) do
      local t = d.tabs[i]
      if type(t) == "table" then
        local items = {}
        for j = 1, math.min(98, #(type(t.it) == "table" and t.it or {})) do
          local x = t.it[j]
          local id, n = type(x) == "table" and int(x[1], 1, 1e7), type(x) == "table" and int(x[2], 1, 10000)
          if id and n then
            items[#items + 1] = { id, n }
          end
        end
        tabs[#tabs + 1] = { n = str(t.n, 30) or ("Pestaña " .. i), it = items }
      end
    end
    return { gold = int(d.gold, 0, 1e12) or 0, tabs = tabs }
  end,
})

-- Reading ---------------------------------------------------------------------------------------------------------
function Treasury.Settings()
  local r = Store.Get("treasury", "cfg")
  return r and not r.del and r.d or { keepers = {}, dues = 0, show = { bal = true, rank = false, book = false } }
end

function Treasury.IsKeeper(name)
  for _, n in ipairs(Treasury.Settings().keepers) do
    if Names.Same(n, name) then
      return true
    end
  end
  return false
end

function Treasury.Exempt(name)
  local r = Store.Get("treasury", "exempt")
  for _, n in ipairs(r and not r.del and r.d.names or {}) do
    if Names.Same(n, name) then
      return true
    end
  end
  return false
end

-- What the viewer may see: organisers and treasurers all; members what the master turned on.
function Treasury.Sees(what)
  local me = Names.Me() or ""
  if Store.IsOrganiser(me) or Treasury.IsKeeper(me) then
    return true
  end
  return Treasury.Settings().show[what] == true
end

function Treasury.Lines()
  local list = Store.List("ledger")
  table.sort(list, function(a, b)
    return a.at > b.at
  end)
  return list
end

-- Totals: balance, in and out, this week's in and donors.
function Treasury.Totals()
  local t = { bal = 0, inAll = 0, outAll = 0, inWeek = 0, donorsWeek = 0 }
  local week = Treasury.WeekStart()
  local donors = {}
  for _, r in ipairs(Store.List("ledger")) do
    if r.d.k == "IN" then
      t.inAll = t.inAll + r.d.c
      if (r.d.w or 0) >= week then
        t.inWeek = t.inWeek + r.d.c
        if not donors[r.d.who] then
          donors[r.d.who] = true
          t.donorsWeek = t.donorsWeek + 1
        end
      end
    else
      t.outAll = t.outAll + r.d.c
    end
  end
  t.bal = t.inAll - t.outAll
  return t
end

-- Donors by what they gave in the last `days` days (90 by default).
function Treasury.Ranking(limit, days)
  local since = Store.Now() - (days or 90) * 86400
  local sum, order = {}, {}
  for _, r in ipairs(Store.List("ledger", function(x)
    return x.d.k == "IN" and x.at >= since
  end)) do
    if not sum[r.d.who] then
      sum[r.d.who] = 0
      order[#order + 1] = r.d.who
    end
    sum[r.d.who] = sum[r.d.who] + r.d.c
  end
  table.sort(order, function(a, b)
    return sum[a] > sum[b]
  end)
  local out = {}
  for i = 1, math.min(limit or 10, #order) do
    out[i] = { name = order[i], c = sum[order[i]] }
  end
  return out
end

-- What `name` gave in the week starting at `week` (this week by default).
function Treasury.GivenIn(name, week)
  week = week or Treasury.WeekStart()
  local sum = 0
  for _, r in ipairs(Store.List("ledger")) do
    if r.d.k == "IN" and Names.Same(r.d.who, name) and (r.d.w or 0) >= week and (r.d.w or 0) < week + WEEK then
      sum = sum + r.d.c
    end
  end
  return sum
end

-- This week's dues of every member: { name, given, owed, exempt, class, weeks = { given of the last 4 weeks } }.
-- (one pass over the book: each member asking it five times was millions of steps in a big guild)
function Treasury.Dues()
  local amount = Treasury.Settings().dues
  local week = Treasury.WeekStart()
  local byName = {} -- name -> { [0] = this week, [1..4] = the weeks before }
  for _, r in ipairs(Store.List("ledger")) do
    local who = r.d.k == "IN" and Names.Short(r.d.who)
    if who then
      local back = -math.floor(((r.d.w or 0) - week) / WEEK)
      if back >= 0 and back <= 4 then
        local w = byName[who] or {}
        byName[who] = w
        w[back] = (w[back] or 0) + r.d.c
      end
    end
  end
  local out = {}
  for _, m in ipairs(BG.Guild.members or {}) do
    local n = Names.Short(m.name)
    if n then
      local sums = byName[n] or {}
      local given = sums[0] or 0
      local weeks = {}
      for i = 1, 4 do
        weeks[i] = sums[i] or 0
      end
      local exempt = Treasury.Exempt(n)
      out[#out + 1] = { name = n, given = given, owed = (exempt or amount == 0) and 0 or math.max(0, amount - given), exempt = exempt,
        class = m.classFile, online = m.online, weeks = weeks }
    end
  end
  table.sort(out, function(a, b)
    if (a.owed > 0) ~= (b.owed > 0) then
      return a.owed > 0
    end
    return a.name < b.name
  end)
  return out
end

function Treasury.Campaigns()
  local list = Store.List("campaigns")
  for _, r in ipairs(list) do
    local raised = 0
    for _, l in ipairs(Store.List("ledger", function(x)
      return x.d.k == "IN" and x.d.camp == r.id
    end)) do
      raised = raised + l.d.c
    end
    r.raised = raised
  end
  table.sort(list, function(a, b)
    if (a.d.done or false) ~= (b.d.done or false) then
      return not a.d.done
    end
    return a.at > b.at
  end)
  return list
end

function Treasury.Bank()
  local r = Store.Get("gbank", "main")
  return r and not r.del and r or nil
end

-- Writing ----------------------------------------------------------------------------------------------------------
local seq = 0
-- A line of our book (we must be a treasurer). k: IN or OUT; via: TRADE, MAIL or HAND.
function Treasury.Record(k, copper, who, via, note)
  local me = Names.Me()
  if not me or not Treasury.IsKeeper(me) then
    return nil, "permiso"
  end
  copper = math.floor(tonumber(copper) or 0)
  if copper <= 0 then
    return nil, "cantidad"
  end
  seq = seq + 1
  return Store.Put("ledger", me:gsub("%s", "") .. "-" .. Store.Now() .. "-" .. seq,
    { k = k, c = copper, who = Names.Short(who) or who, via = via, note = note, w = Treasury.WeekStart(), keeper = me })
end

function Treasury.EditLine(id, fields)
  local r = Store.Get("ledger", id)
  if not r or r.del then
    return nil, "no existe"
  end
  local d = {}
  for k, v in pairs(r.d) do
    d[k] = v
  end
  for k, v in pairs(fields) do
    if v == false then
      d[k] = nil
    else
      d[k] = v
    end
  end
  return Store.Put("ledger", id, d)
end

function Treasury.DeleteLine(id)
  return Store.Delete("ledger", id)
end

-- The master's settings.
function Treasury.Configure(fields)
  if not Store.IsMaster(Names.Me() or "") then
    return nil, "permiso"
  end
  local cur = Treasury.Settings()
  local d = { keepers = cur.keepers, dues = cur.dues, show = { bal = cur.show.bal, rank = cur.show.rank, book = cur.show.book } }
  if fields.keepers then
    local list = {}
    for name in tostring(fields.keepers):gmatch("[^,]+") do
      local m = BG.Guild.Find(strtrim(name))
      if not m then
        return nil, "no es de tu hermandad", strtrim(name)
      end
      list[#list + 1] = Names.Short(m.name)
    end
    d.keepers = list
  end
  if fields.dues then
    d.dues = fields.dues
  end
  for k, v in pairs(fields.show or {}) do
    d.show[k] = v
  end
  return Store.Put("treasury", "cfg", d)
end

function Treasury.SetExempt(name, on)
  if not Store.IsOrganiser(Names.Me() or "") then
    return nil, "permiso"
  end
  local m = BG.Guild.Find(str(name, 40) or "")
  if not m then
    return nil, "no es de tu hermandad"
  end
  local short = Names.Short(m.name)
  local r = Store.Get("treasury", "exempt")
  local names = {}
  for _, n in ipairs(r and not r.del and r.d.names or {}) do
    if not Names.Same(n, short) then
      names[#names + 1] = n
    end
  end
  if on then
    names[#names + 1] = short
  end
  return Store.Put("treasury", "exempt", { names = names })
end

function Treasury.NewCampaign(title, goal, days)
  local me = Names.Me() or ""
  if not (Store.IsOrganiser(me) or Treasury.IsKeeper(me)) then
    return nil, "permiso"
  end
  return Store.Put("campaigns", "c" .. Store.Now() .. BG.Alliance.RandomId(3), { title = title, goal = goal, untilT = days and (Store.Now() + days * 86400) or nil })
end

function Treasury.CloseCampaign(id)
  local r = Store.Get("campaigns", id)
  if not r or r.del then
    return nil, "no existe"
  end
  return Store.Put("campaigns", id, { title = r.d.title, goal = r.d.goal, untilT = r.d.untilT, done = true })
end

-- The book as text, to keep a copy outside the game (one line each: date;in/out;gold in copper;who;how;purpose).
function Treasury.Export()
  local lines = { "fecha;tipo;cobre;quien;como;concepto;tesorero" }
  local list = Treasury.Lines()
  for i = #list, 1, -1 do
    local r = list[i]
    lines[#lines + 1] = table.concat({ date("%Y-%m-%d %H:%M", r.at), r.d.k == "IN" and "entrada" or "salida", tostring(r.d.c), r.d.who or "",
      VIA[r.d.via] or "", (r.d.note or ""):gsub(";", ","), r.d.keeper or r.by or "" }, ";")
  end
  return table.concat(lines, "\n")
end

-- Watching trades and mail (treasurers only) ---------------------------------------------------------------------
local trade
BG:On("TRADE_SHOW", function()
  if not Treasury.IsKeeper(Names.Me() or "") then
    return
  end
  -- (Names.Unit: on Forever UnitName gives only the first name; the whole name is "First Surname")
  local name = Names.Unit("NPC")
  trade = name and { name = name, got = 0, gave = 0 } or nil
end)

local function tradeMoney()
  if trade then
    trade.got = GetTargetTradeMoney and tonumber(GetTargetTradeMoney()) or 0
    trade.gave = GetPlayerTradeMoney and tonumber(GetPlayerTradeMoney()) or 0
  end
end
BG:On("TRADE_MONEY_CHANGED", tradeMoney)
BG:On("TRADE_ACCEPT_UPDATE", tradeMoney)

BG:On("UI_INFO_MESSAGE", function(a, b)
  local msg = type(b) == "string" and b or a
  if not trade or msg ~= ERR_TRADE_COMPLETE then
    return
  end
  local done = trade
  trade = nil
  local net = (done.got or 0) - (done.gave or 0)
  if net > 0 then
    Treasury.Record("IN", net, done.name, "TRADE")
  elseif net < 0 then
    Treasury.Record("OUT", -net, done.name, "TRADE")
  end
end)
BG:On("TRADE_CLOSED", function()
  C_Timer.After(1, function()
    trade = nil -- (a trade that did not complete leaves nothing)
  end)
end)

-- Mail: the gold a player's letter brings, when it is taken; the gold we send, when the letter goes. The
-- letters are read when the mailbox fills (MAIL_INBOX_UPDATE), so what a letter held is known even if the game
-- has already emptied it by the time the gold is taken.
local inbox = {}
local function readInbox()
  wipe(inbox)
  if not (GetInboxNumItems and GetInboxHeaderInfo) then
    return
  end
  for i = 1, (GetInboxNumItems() or 0) do
    local _, _, sender, subject, money, cod, _, _, _, returned, _, canReply = GetInboxHeaderInfo(i)
    inbox[i] = { sender = sender, subject = subject, money = money or 0, cod = cod or 0, returned = returned, canReply = canReply }
  end
end
BG:On("MAIL_INBOX_UPDATE", readInbox)
BG:On("MAIL_SHOW", readInbox)

local function tookMail(index)
  if not Treasury.IsKeeper(Names.Me() or "") or not GetInboxHeaderInfo then
    return
  end
  local m = inbox[index]
  if not (m and m.money > 0) then
    local _, _, sender, subject, money, cod, _, _, _, returned, _, canReply = GetInboxHeaderInfo(index)
    m = { sender = sender, subject = subject, money = money or 0, cod = cod or 0, returned = returned, canReply = canReply }
  end
  inbox[index] = nil
  -- (a letter a player can be answered: never the auction house's or the game's own; no cash on delivery)
  if m.money > 0 and m.cod == 0 and m.canReply and not m.returned and m.sender then
    Treasury.Record("IN", m.money, m.sender, "MAIL", m.subject and m.subject ~= "" and m.subject or nil)
  end
end
local sending
local function hookMail()
  if not hooksecurefunc then
    return
  end
  if TakeInboxMoney then
    hooksecurefunc("TakeInboxMoney", tookMail)
  end
  if AutoLootMailItem then
    hooksecurefunc("AutoLootMailItem", tookMail)
  end
  if SendMail then
    hooksecurefunc("SendMail", function(to, subject)
      local money = GetSendMailMoney and tonumber(GetSendMailMoney()) or 0
      sending = money > 0 and Treasury.IsKeeper(Names.Me() or "") and { to = to, c = money, note = subject } or nil
    end)
  end
end
BG:On("PLAYER_LOGIN", hookMail)
BG:On("MAIL_SEND_SUCCESS", function()
  if sending then
    Treasury.Record("OUT", sending.c, sending.to, "MAIL", sending.note ~= "" and sending.note or nil)
    sending = nil
  end
end)
BG:On("MAIL_FAILED", function()
  sending = nil
end)

-- The guild bank ---------------------------------------------------------------------------------------------------
local bankOpen = false
local function snapshotBank()
  local me = Names.Me() or ""
  if not bankOpen or not (Store.IsOrganiser(me) or Treasury.IsKeeper(me)) or not GetNumGuildBankTabs then
    return
  end
  local tabs = {}
  for tab = 1, math.min(8, GetNumGuildBankTabs() or 0) do
    local name, _, viewable = GetGuildBankTabInfo(tab)
    if viewable then
      local sum, order = {}, {}
      for slot = 1, 98 do
        local link = GetGuildBankItemLink(tab, slot)
        local id = link and tonumber(link:match("item:(%d+)"))
        if id then
          local _, count = GetGuildBankItemInfo(tab, slot)
          if not sum[id] then
            sum[id] = 0
            order[#order + 1] = id
          end
          sum[id] = sum[id] + (tonumber(count) or 1)
        end
      end
      local items = {}
      for _, id in ipairs(order) do
        items[#items + 1] = { id, sum[id] }
      end
      tabs[#tabs + 1] = { n = name, it = items }
    end
  end
  Store.Put("gbank", "main", { gold = GetGuildBankMoney and tonumber(GetGuildBankMoney()) or 0, tabs = tabs }, { lane = "bulk" })
end

local pendingSnap = false
local function soonSnapshot()
  if pendingSnap then
    return
  end
  pendingSnap = true
  C_Timer.After(2, function()
    pendingSnap = false
    snapshotBank()
  end)
end

local function opened()
  bankOpen = true
  for tab = 1, (GetNumGuildBankTabs and GetNumGuildBankTabs() or 0) do
    if QueryGuildBankTab then
      pcall(QueryGuildBankTab, tab)
    end
  end
  soonSnapshot()
end
BG:On("GUILDBANKFRAME_OPENED", opened)
BG:On("GUILDBANKFRAME_CLOSED", function()
  bankOpen = false
end)
BG:On("PLAYER_INTERACTION_MANAGER_FRAME_SHOW", function(kind)
  local want = Enum and Enum.PlayerInteractionType and Enum.PlayerInteractionType.GuildBanker or 10
  if kind == want then
    opened()
  end
end)
BG:On("PLAYER_INTERACTION_MANAGER_FRAME_HIDE", function(kind)
  local want = Enum and Enum.PlayerInteractionType and Enum.PlayerInteractionType.GuildBanker or 10
  if kind == want then
    bankOpen = false
  end
end)
BG:On("GUILDBANKBAGSLOTS_CHANGED", soonSnapshot)

-- Notices ----------------------------------------------------------------------------------------------------------
BG:On("BG_RECORD", function(kind, r, old)
  if kind == "ledger" and r.d and not old and r.d.k == "IN" and Names.IsMe(r.d.who) then
    BG:Notify("Gracias por tu donación", (r.d.keeper or "El tesorero") .. " ha apuntado " .. Treasury.Money(r.d.c) .. " de tu parte.", { kind = "success", view = "treasury" })
  end
  if kind == "ledger" or kind == "treasury" or kind == "campaigns" or kind == "gbank" then
    BG:Fire("BG_TREASURY_CHANGED")
  end
end)
BG:On("BG_STORE_CHANGED", function(name)
  if name == "ledger" or name == "treasury" or name == "campaigns" or name == "gbank" then
    BG:Fire("BG_TREASURY_CHANGED")
  end
end)

BG.commands = BG.commands or {}
BG.commands.tesoreria = function()
  if not (BG.window and BG.window:IsShown()) then
    BG:ToggleWindow()
  end
  BG:ShowView("treasury")
end
