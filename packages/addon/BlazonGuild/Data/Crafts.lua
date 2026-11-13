-- Artesanía y botín (entrega 8; Olympus' Crafters.lua, CraftRequests.lua, CraftRanking.lua and Loot.lua, MIT,
-- our own implementation). Everything stays inside the guild.
--
-- Crafters: when a player opens one of their professions, the addon reads it (its skill and the items and
-- enchantments it can make: ids only) and asks once whether to publish it. Published, every guildmate sees it on
-- the crafters' board, can search "who can make this?" (names are looked up by each client in its own language)
-- and whisper the crafter with a click (the game's own whisper: the player types it). Nothing is crafted,
-- traded or bought for anyone.
-- Orders: a member asks for an item (from a crafter, or from anyone who can make it); the crafter says they will
-- make it, then that it is done; the one who asked confirms they got it. Confirmed orders make the crafters'
-- ranking.
-- Loot notes: the organisers write who got what and why, the decision next raid starts from, and, if the guild
-- uses them, a member's points by hand (a number nothing adds or takes). No bids and no gold: GDKP is not
-- allowed on Forever.
local _, BG = ...
local Crafts = {}
BG.Crafts = Crafts
local Store, Names = BG.Store, BG.Names
local str, int = BG.Raids.Clean, BG.Raids.Int

local MAX_ITEMS = 400
local MAX_SPELLS = 200
local CRAFTER_TTL = 30 * 86400
local ORDER_TTL = 30 * 86400
local RANKING_DAYS = 90

Crafts.ORDER_STATES = { OPEN = "abierto", TAKEN = "en marcha", DONE = "hecho", CONFIRMED = "recibido", CANCELLED = "cancelado" }

local function idList(t, max)
  local out, have = {}, {}
  for i = 1, math.min(max, #(type(t) == "table" and t or {})) do
    local n = tonumber(t[i])
    if n and n > 0 and n < 1e7 and not have[n] then
      have[n] = true
      out[#out + 1] = math.floor(n)
    end
  end
  return out
end

-- Shared records -----------------------------------------------------------------------------------------------
-- A crafter's profession: id "<name>|<profession key>", written by that player only.
Store.Define("crafters", {
  ttl = CRAFTER_TTL,
  can = function(author, r)
    return Names.Same(r.id:match("^(.-)|"), author)
  end,
  normalize = function(d)
    local p, k = str(d.p, 24), str(d.k, 24)
    if not p or p == "" or not k or k == "" then
      return nil
    end
    return { p = p, k = k, r = int(d.r, 0, 1000) or 0, m = int(d.m, 0, 1000) or 0, it = idList(d.it, MAX_ITEMS), sp = idList(d.sp, MAX_SPELLS) }
  end,
})

-- An order: id "<who asked>-<time>". Who asked creates and cancels it and confirms it arrived; the crafter takes
-- it (anyone who can, when it names nobody) and says it is done.
Store.Define("orders", {
  ttl = ORDER_TTL,
  can = function(author, r, old)
    local prefix = author:gsub("%s", "") .. "-"
    local mine = r.id:sub(1, #prefix) == prefix
    if not old or old.del then
      return mine and not r.del and r.d.st == "OPEN"
    end
    local o, n = old.d, r.d
    if r.del then
      return mine
    end
    if mine then
      -- the one who asked: cancel, or confirm what was done
      return (n.st == "CANCELLED" and (o.st == "OPEN" or o.st == "TAKEN")) or (n.st == "CONFIRMED" and o.st == "DONE")
        or (n.st == o.st and Names.Same(n.crafter, o.crafter))
    end
    if o.st == "OPEN" and n.st == "TAKEN" then
      return Names.Same(n.crafter, author) and (not o.crafter or Names.Same(o.crafter, author))
    end
    if o.st == "TAKEN" and (n.st == "DONE" or n.st == "OPEN") then
      return Names.Same(o.crafter, author) and (n.st == "DONE" or not n.crafter or Names.Same(n.crafter, author))
    end
    return false
  end,
  normalize = function(d)
    local what = str(d.what, 120)
    if not what or what == "" or not Crafts.ORDER_STATES[d.st] then
      return nil
    end
    return { what = what, item = int(d.item, 1, 1e7), qty = int(d.qty, 1, 200) or 1, note = str(d.note, 140), crafter = Names.Short(str(d.crafter, 40)),
      st = d.st, by = Names.Short(str(d.by, 40)) }
  end,
})

-- Loot notes: written by the organisers.
Store.Define("loot", {
  ttl = 365 * 86400,
  can = function(author)
    return Store.IsOrganiser(author)
  end,
  normalize = function(d)
    local what, to = str(d.what, 120), Names.Short(str(d.to, 40))
    if not what or what == "" or not to then
      return nil
    end
    return { what = what, item = int(d.item, 1, 1e7), to = to, why = str(d.why, 160), raid = str(d.raid, 40) }
  end,
})

-- Points (optional): a number per member, set by hand by the organisers.
Store.Define("points", {
  can = function(author)
    return Store.IsOrganiser(author)
  end,
  normalize = function(d)
    local p = tonumber(d.p)
    if not p then
      return nil
    end
    return { p = math.floor(math.max(-99999, math.min(99999, p))), note = str(d.note, 80) }
  end,
})

-- Names of items and spells, as this client knows them ---------------------------------------------------------
local itemNames = {}
function Crafts.ItemName(id)
  if not id then
    return nil
  end
  if itemNames[id] then
    return itemNames[id]
  end
  local name
  if C_Item and C_Item.GetItemNameByID then
    local ok, n = pcall(C_Item.GetItemNameByID, id)
    name = ok and n or nil
  end
  if not name then
    name = BG.ItemInfo(id)
  end
  if name then
    itemNames[id] = name
  elseif C_Item and C_Item.RequestLoadItemDataByID then
    pcall(C_Item.RequestLoadItemDataByID, id) -- (it comes later: GET_ITEM_INFO_RECEIVED)
  end
  return name
end

function Crafts.SpellName(id)
  if C_Spell and C_Spell.GetSpellName then
    local ok, n = pcall(C_Spell.GetSpellName, id)
    if ok and n then
      return n
    end
  end
  if GetSpellInfo then
    local ok, n = pcall(GetSpellInfo, id)
    if ok and n then
      return n
    end
  end
  return nil
end

-- An item id from a link pasted in a box ("|Hitem:16800:...|h[...]|h") or the text itself.
function Crafts.ParseItem(text)
  text = type(text) == "string" and text or ""
  local id = tonumber(text:match("|Hitem:(%d+)"))
  local label = text:match("|h%[(.-)%]|h") or text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
  return id, str(label, 120)
end

-- Reading our professions ---------------------------------------------------------------------------------------
local function idOf(link, kind)
  return type(link) == "string" and tonumber(link:match(kind .. ":(%d+)")) or nil
end

-- Someone else's profession shown in the window (a link, an NPC's): not ours.
local function external()
  local T = C_TradeSkillUI
  for _, f in ipairs({ "IsTradeSkillLinked", "IsTradeSkillGuild", "IsTradeSkillGuildMember", "IsNPCCrafting" }) do
    local fn = T and T[f]
    if type(fn) == "function" then
      local ok, v = pcall(fn)
      if ok and v then
        return true
      end
    end
  end
  if type(IsTradeSkillLinked) == "function" then
    local ok, v = pcall(IsTradeSkillLinked)
    if ok and v then
      return true
    end
  end
  return false
end

-- Newer clients (C_TradeSkillUI).
local function readModern()
  local T = C_TradeSkillUI
  if not T or type(T.GetBaseProfessionInfo) ~= "function" or type(T.GetRecipeInfo) ~= "function" then
    return nil
  end
  local ok, base = pcall(T.GetBaseProfessionInfo)
  if not ok or type(base) ~= "table" or not base.professionID or base.professionID == 0 then
    return nil
  end
  local skill = base
  if type(T.GetChildProfessionInfo) == "function" then
    local okc, c = pcall(T.GetChildProfessionInfo)
    if okc and type(c) == "table" and (c.skillLevel or 0) > 0 then
      skill = c
    end
  end
  local ids
  for _, f in ipairs({ "GetAllRecipeIDs", "GetFilteredRecipeIDs" }) do
    if not ids and type(T[f]) == "function" then
      local okr, r = pcall(T[f])
      if okr and type(r) == "table" then
        ids = r
      end
    end
  end
  local items, spells = {}, {}
  for _, id in ipairs(ids or {}) do
    local okr, info = pcall(T.GetRecipeInfo, id)
    if okr and type(info) == "table" and info.learned then
      local item
      if type(T.GetRecipeOutputItemData) == "function" then
        local oko, out = pcall(T.GetRecipeOutputItemData, id)
        item = oko and type(out) == "table" and out.itemID or nil
      end
      if item then
        items[#items + 1] = item
      else
        spells[#spells + 1] = id
      end
    end
  end
  return { k = tostring(base.professionID), p = base.professionName, r = skill.skillLevel, m = skill.maxSkillLevel, it = items, sp = spells }
end

-- Classic clients: the trade skill window (GetTradeSkill*) or, for Enchanting, the craft window (GetCraft*).
local function readClassic(craft)
  local lineFn = craft and GetCraftDisplaySkillLine or GetTradeSkillLine
  if type(lineFn) ~= "function" then
    return nil
  end
  local name, rank, max = lineFn()
  if type(name) ~= "string" or name == "" or name == "UNKNOWN" or not rank then
    return nil
  end
  local count = craft and GetNumCrafts or GetNumTradeSkills
  local info = craft and GetCraftInfo or GetTradeSkillInfo
  local itemLink = craft and GetCraftItemLink or GetTradeSkillItemLink
  local items, spells = {}, {}
  for i = 1, (type(count) == "function" and count() or 0) do
    local rname, kind, _
    if craft then
      rname, _, kind = info(i)
    else
      rname, kind = info(i)
    end
    if rname and kind ~= "header" and kind ~= "subheader" then
      local link = type(itemLink) == "function" and itemLink(i) or nil
      local item, ench = idOf(link, "item"), idOf(link, "enchant")
      if item then
        items[#items + 1] = item
      elseif ench then
        spells[#spells + 1] = ench
      end
    end
  end
  return { k = name, p = name, r = rank, m = max, it = items, sp = spells }
end

function Crafts.Read(craft)
  if external() then
    return nil
  end
  local p = (not craft and readModern()) or readClassic(craft)
  if not p or (#p.it == 0 and #p.sp == 0) then
    return nil
  end
  p.p, p.k = str(p.p, 24), str(p.k, 24)
  if not p.p or p.p == "" or not p.k or p.k == "" then
    return nil
  end
  p.r, p.m = math.floor(tonumber(p.r) or 0), math.floor(tonumber(p.m) or 0)
  return p
end

local function mine()
  local me = Names.Me()
  if not me then
    return nil
  end
  BG.db.crafts = BG.db.crafts or {}
  BG.db.crafts[me] = BG.db.crafts[me] or { profs = {}, share = {} }
  return BG.db.crafts[me]
end
Crafts.Mine = mine

-- Our professions read so far: { key -> { p, k, r, m, it, sp, shared } }.
function Crafts.MyProfessions()
  local m = mine()
  local out = {}
  for key, p in pairs(m and m.profs or {}) do
    local copy = {}
    for k, v in pairs(p) do
      copy[k] = v
    end
    copy.shared = m.share[key] == true
    out[#out + 1] = copy
  end
  table.sort(out, function(a, b)
    return a.p < b.p
  end)
  return out
end

function Crafts.Publish(key)
  local m = mine()
  local p = m and m.profs[key]
  if not p or not m.share[key] then
    return nil
  end
  local me = Names.Me()
  local old = Store.Get("crafters", me .. "|" .. key)
  if old and not old.del and old.d.r == p.r and #old.d.it == #p.it and #old.d.sp == #p.sp and Store.Now() - old.at < 7 * 86400 then
    return old -- (nothing new to say)
  end
  return Store.Put("crafters", me .. "|" .. key, { p = p.p, k = p.k, r = p.r, m = p.m, it = p.it, sp = p.sp })
end

-- The player's yes or no to publishing a profession.
function Crafts.SetShare(key, on)
  local m = mine()
  if not m or not m.profs[key] then
    return nil, "no existe"
  end
  m.share[key] = on and true or false
  if on then
    Crafts.Publish(key)
  else
    local me = Names.Me()
    local r = Store.Get("crafters", me .. "|" .. key)
    if r and not r.del then
      Store.Delete("crafters", me .. "|" .. key)
    end
  end
  BG:Fire("BG_CRAFTS_CHANGED")
  return true
end

-- A profession window opened: read it, keep it, publish it if the player said yes, ask once if not.
local asked = {}
function Crafts.Opened(craft)
  if InCombatLockdown and InCombatLockdown() then
    return
  end
  local p = Crafts.Read(craft)
  local m = mine()
  if not p or not m then
    return
  end
  m.profs[p.k] = p
  if m.share[p.k] == true then
    Crafts.Publish(p.k)
  elseif m.share[p.k] == nil and not asked[p.k] and BG.Consent.Accepted() then
    asked[p.k] = true
    local key = p.k
    BG.UI.Dialog({
      title = "¿Publicar " .. p.p .. "?",
      items = { "Tu hermandad verá en «Artesanía y botín» lo que sabes fabricar de " .. p.p .. " (" .. p.r .. "/" .. p.m .. ").",
        { bullet = "Podrán buscar quién sabe hacer un objeto y susurrarte, o hacerte un encargo." },
        { note = "Puedes dejar de publicarlo cuando quieras." } },
      primary = { label = "Publicar", fn = function()
        Crafts.SetShare(key, true)
      end },
      secondary = { label = "Ahora no", fn = function()
        Crafts.SetShare(key, false)
      end },
    })
  end
  BG:Fire("BG_CRAFTS_CHANGED")
end

local pending = false
local function soon(craft)
  if pending then
    return
  end
  pending = true
  C_Timer.After(0.5, function()
    pending = false
    Crafts.Opened(craft)
  end)
end
BG:On("TRADE_SKILL_SHOW", function()
  soon(false)
end)
BG:On("CRAFT_SHOW", function()
  soon(true)
end)

-- The board -------------------------------------------------------------------------------------------------------
-- Crafters by player: { name, profs = { { p, r, m, it, sp } }, online }.
function Crafts.Board()
  local by, order = {}, {}
  for _, r in ipairs(Store.List("crafters")) do
    local name = r.id:match("^(.-)|")
    if name then
      local e = by[name]
      if not e then
        local m = BG.Guild.Find(name)
        e = { name = name, profs = {}, online = m and m.online or false, class = m and m.classFile }
        by[name] = e
        order[#order + 1] = e
      end
      e.profs[#e.profs + 1] = r.d
    end
  end
  table.sort(order, function(a, b)
    if a.online ~= b.online then
      return a.online
    end
    return a.name < b.name
  end)
  return order
end

local function fold(s)
  return (s or ""):lower()
end

-- Who can make something whose name contains `text`: { { name, prof, items = { names } } }.
function Crafts.Search(text)
  local q = fold(str(text, 60))
  if q == "" then
    return {}
  end
  local out = {}
  for _, c in ipairs(Crafts.Board()) do
    for _, p in ipairs(c.profs) do
      local hits = {}
      for _, id in ipairs(p.it) do
        local n = Crafts.ItemName(id)
        if n and fold(n):find(q, 1, true) then
          hits[#hits + 1] = n
        end
      end
      for _, id in ipairs(p.sp) do
        local n = Crafts.SpellName(id)
        if n and fold(n):find(q, 1, true) then
          hits[#hits + 1] = n
        end
      end
      if #hits > 0 then
        out[#out + 1] = { name = c.name, online = c.online, class = c.class, prof = p.p, rank = p.r, items = hits }
      end
    end
  end
  return out
end

-- Can `name` make item `id` (from what they published)?
function Crafts.Makes(name, id)
  for _, c in ipairs(Crafts.Board()) do
    if Names.Same(c.name, name) then
      for _, p in ipairs(c.profs) do
        for _, x in ipairs(p.it) do
          if x == id then
            return true
          end
        end
      end
    end
  end
  return false
end

-- The game's own whisper to a crafter: the chat box opens with "/w Name", the player writes.
function Crafts.Whisper(name)
  if not BG.InGame() then
    return false
  end
  if not BG.Gamepad.Allowed("chatbox") then
    BG:Notify("Con mando", "Escribe /w " .. tostring(name) .. " en el chat para susurrarle.", { kind = "info" })
    return false
  end
  if ChatFrame_SendTell then
    ChatFrame_SendTell(name)
    return true
  end
  return false
end

-- Orders ---------------------------------------------------------------------------------------------------------
function Crafts.Order(fields)
  local me = Names.Me()
  if not me then
    return nil, "sin personaje"
  end
  local id, label = Crafts.ParseItem(fields.what)
  return Store.Put("orders", me:gsub("%s", "") .. "-" .. Store.Now(), { what = label, item = id or fields.item, qty = fields.qty, note = fields.note,
    crafter = fields.crafter and fields.crafter ~= "" and fields.crafter or nil, st = "OPEN", by = me }, { lane = "alert" })
end

local function setState(id, st, crafter)
  local r = Store.Get("orders", id)
  if not r or r.del then
    return nil, "no existe"
  end
  local d = {}
  for k, v in pairs(r.d) do
    d[k] = v
  end
  d.st = st
  if crafter ~= nil then
    d.crafter = crafter or nil
  end
  return Store.Put("orders", id, d, { lane = "alert" })
end

function Crafts.Take(id)
  return setState(id, "TAKEN", Names.Me())
end
function Crafts.Done(id)
  return setState(id, "DONE")
end
function Crafts.Confirm(id)
  return setState(id, "CONFIRMED")
end
function Crafts.CancelOrder(id)
  return setState(id, "CANCELLED")
end
-- The crafter gives it back (someone else can take it).
function Crafts.Release(id)
  return setState(id, "OPEN", false)
end

function Crafts.Orders()
  local list = Store.List("orders", function(r)
    return r.d.st ~= "CANCELLED" and (r.d.st ~= "CONFIRMED" or Store.Now() - r.at < 7 * 86400)
  end)
  local order = { OPEN = 2, TAKEN = 1, DONE = 3, CONFIRMED = 4 }
  table.sort(list, function(a, b)
    if order[a.d.st] ~= order[b.d.st] then
      return order[a.d.st] < order[b.d.st]
    end
    return a.at > b.at
  end)
  return list
end

-- Crafters by orders delivered and confirmed in the last 90 days.
function Crafts.Ranking(limit)
  local count, order = {}, {}
  for _, r in ipairs(Store.List("orders", function(x)
    return x.d.st == "CONFIRMED" and x.d.crafter ~= nil and Store.Now() - x.at < RANKING_DAYS * 86400
  end)) do
    local n = r.d.crafter
    if not count[n] then
      count[n] = 0
      order[#order + 1] = n
    end
    count[n] = count[n] + (r.d.qty or 1)
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

-- Loot notes and points ------------------------------------------------------------------------------------------
function Crafts.Note(fields)
  if not Store.IsOrganiser(Names.Me() or "") then
    return nil, "permiso"
  end
  local id, label = Crafts.ParseItem(fields.what)
  local m = BG.Guild.Find(str(fields.to, 40) or "")
  if not m then
    return nil, "no es de tu hermandad"
  end
  return Store.Put("loot", "n" .. Store.Now() .. BG.Alliance.RandomId(3), { what = label, item = id, to = Names.Short(m.name), why = fields.why, raid = fields.raid })
end

function Crafts.RemoveNote(id)
  if not Store.IsOrganiser(Names.Me() or "") then
    return nil, "permiso"
  end
  return Store.Delete("loot", id)
end

function Crafts.Notes(filter)
  local q = fold(str(filter, 40))
  local list = Store.List("loot", function(r)
    return q == "" or fold(r.d.to):find(q, 1, true) ~= nil or fold(r.d.what):find(q, 1, true) ~= nil
  end)
  table.sort(list, function(a, b)
    return a.at > b.at
  end)
  return list
end

function Crafts.SetPoints(name, p)
  if not Store.IsOrganiser(Names.Me() or "") then
    return nil, "permiso"
  end
  local m = BG.Guild.Find(str(name, 40) or "")
  if not m then
    return nil, "no es de tu hermandad"
  end
  if p == nil or p == "" then
    return Store.Delete("points", Names.Short(m.name))
  end
  if not tonumber(p) then
    return nil, "número"
  end
  return Store.Put("points", Names.Short(m.name), { p = tonumber(p) })
end

function Crafts.Points()
  local list = Store.List("points")
  table.sort(list, function(a, b)
    if a.d.p ~= b.d.p then
      return a.d.p > b.d.p
    end
    return a.id < b.id
  end)
  return list
end

-- Notices ---------------------------------------------------------------------------------------------------------
BG:On("BG_RECORD", function(kind, r, old)
  local me = Names.Me()
  if not me or not r.d then
    return
  end
  if kind == "orders" then
    local d, was = r.d, old and old.d and old.d.st
    local what = (d.qty and d.qty > 1 and (d.qty .. "x ") or "") .. d.what
    if not old and not Names.Same(d.by, me) then
      if Names.Same(d.crafter, me) then
        BG:Notify("Te hacen un encargo", d.by .. " te pide " .. what .. ".", { kind = "info", view = "crafts", sound = "READY_CHECK" })
      elseif not d.crafter and d.item and Crafts.Makes(me, d.item) then
        BG:Notify("Encargo que sabes hacer", d.by .. " busca " .. what .. ".", { kind = "info", view = "crafts" })
      end
    elseif Names.Same(d.by, me) and was ~= d.st then
      if d.st == "TAKEN" then
        BG:Notify("Encargo en marcha", (d.crafter or "Alguien") .. " hará tu " .. what .. ".", { kind = "success", view = "crafts" })
      elseif d.st == "DONE" then
        BG:Notify("Encargo hecho", (d.crafter or "El artesano") .. " ha terminado tu " .. what .. ". Cuando lo tengas, pulsa «Recibido».", { kind = "success", view = "crafts", sound = "LEVELUP" })
      end
    end
  end
  if kind == "crafters" or kind == "orders" or kind == "loot" or kind == "points" then
    BG:Fire("BG_CRAFTS_CHANGED")
  end
end)
BG:On("BG_STORE_CHANGED", function(name)
  if name == "crafters" or name == "orders" or name == "loot" or name == "points" then
    BG:Fire("BG_CRAFTS_CHANGED")
  end
end)
local namesQueued = false
BG:On("GET_ITEM_INFO_RECEIVED", function()
  if namesQueued then
    return
  end
  namesQueued = true
  C_Timer.After(1, function()
    namesQueued = false
    BG:Fire("BG_CRAFTS_CHANGED")
  end)
end)

BG.commands = BG.commands or {}
BG.commands.artesania = function()
  if not (BG.window and BG.window:IsShown()) then
    BG:ToggleWindow()
  end
  BG:ShowView("crafts")
end
