-- Armería: what each member wears. Two sources, never mixed up:
--   * shared: a member who says yes («Compartir mi equipo con mi hermandad») publishes what they wear (record "gear":
--     each slot's item and enchantment, and their average item level), again whenever it changes;
--   * seen by you: a member you inspect yourself (they must be near you, as the game's own inspection), kept only on
--     your computer and never sent, with when you saw it.
-- Inspection runs only on a click, one at a time, never in combat and never while the game's inspect window is open
-- (as Olympus' Inspect.lua does, MIT; our own implementation). The guild tabard is slot 19 (entrega 3's tabards).
local _, BG = ...
local Armory = {}
BG.Armory = Armory
local Store, Names = BG.Store, BG.Names
local int = BG.Raids.Int

Armory.SLOTS = {
  { id = 1, name = "Cabeza" }, { id = 2, name = "Cuello" }, { id = 3, name = "Hombros" }, { id = 15, name = "Espalda" },
  { id = 5, name = "Pecho" }, { id = 4, name = "Camisa" }, { id = 19, name = "Tabardo" }, { id = 9, name = "Muñecas" },
  { id = 10, name = "Manos" }, { id = 6, name = "Cintura" }, { id = 7, name = "Piernas" }, { id = 8, name = "Pies" },
  { id = 11, name = "Anillo" }, { id = 12, name = "Anillo" }, { id = 13, name = "Abalorio" }, { id = 14, name = "Abalorio" },
  { id = 16, name = "Mano derecha" }, { id = 17, name = "Mano izquierda" }, { id = 18, name = "A distancia" },
}
local COUNTED = { [4] = false, [19] = false } -- the shirt and the tabard do not count for the item level
local GEAR_TTL = 30 * 86400
local PUBLISH_WAIT = 20
local INSPECT_TIMEOUT = 4

BG.Consent.Register({ key = "gear", label = "Compartir mi equipo con mi hermandad (Armería)" })

-- "item:7946:1897:..." -> 7946, 1897 (enchantment, or nil). Pure.
function Armory.ParseLink(link)
  if type(link) ~= "string" or (issecretvalue and issecretvalue(link)) then
    return nil
  end
  local id, ench = link:match("item:(%d+):?(%d*)")
  id, ench = tonumber(id), tonumber(ench)
  if not id then
    return nil
  end
  return id, (ench and ench > 0) and ench or nil
end

-- The level of one item: the game's own (its upgraded level, when it knows it), or its base level.
function Armory.ItemLevel(linkOrId)
  local f = (C_Item and C_Item.GetDetailedItemLevelInfo) or GetDetailedItemLevelInfo
  if f and type(linkOrId) == "string" then
    local ok, lvl = pcall(f, linkOrId)
    if ok and tonumber(lvl) and tonumber(lvl) > 0 then
      return tonumber(lvl)
    end
  end
  return (select(4, BG.ItemInfo(linkOrId)))
end

-- What `unit` wears: { [slot] = { id, ench, link } } and its average item level (of the slots that count, of those
-- whose level the game knows). nil when the game gives nothing.
function Armory.Read(unit)
  if not GetInventoryItemLink then
    return nil
  end
  local slots, sum, n = {}, 0, 0
  for _, s in ipairs(Armory.SLOTS) do
    local ok, link = pcall(GetInventoryItemLink, unit, s.id)
    local id, ench = Armory.ParseLink(ok and link or nil)
    if id then
      slots[s.id] = { id = id, ench = ench, link = link }
      if COUNTED[s.id] ~= false then
        local lvl = Armory.ItemLevel(link)
        if lvl then
          sum, n = sum + lvl, n + 1
        end
      end
    end
  end
  if not next(slots) then
    return nil
  end
  return slots, n > 0 and math.floor(sum / n + 0.5) or nil
end

-- Shared records ------------------------------------------------------------------------------------------------------
-- "gear"/<name>: { s = { "slot:item:ench", ... }, il = average item level }. Each member writes only their own.
Store.Define("gear", {
  ttl = GEAR_TTL,
  can = function(author, r)
    return Names.Same(r.id, author)
  end,
  normalize = function(d)
    local s = {}
    for i = 1, math.min(19, #(type(d.s) == "table" and d.s or {})) do
      local slot, id, ench = tostring(d.s[i]):match("^(%d+):(%d+):?(%d*)$")
      slot, id, ench = tonumber(slot), tonumber(id), tonumber(ench)
      if slot and slot >= 1 and slot <= 19 and id and id <= 1000000 then
        s[#s + 1] = slot .. ":" .. id .. ((ench and ench > 0 and ench <= 1000000) and (":" .. ench) or "")
      end
    end
    return { s = s, il = int(d.il, 0, 2000) }
  end,
})

local function encode(slots)
  local list = {}
  for slot, x in pairs(slots) do
    list[#list + 1] = slot .. ":" .. x.id .. (x.ench and (":" .. x.ench) or "")
  end
  table.sort(list)
  return list
end

local function decode(list)
  local slots = {}
  for _, e in ipairs(list or {}) do
    local slot, id, ench = e:match("^(%d+):(%d+):?(%d*)$")
    slot, id = tonumber(slot), tonumber(id)
    if slot and id then
      slots[slot] = { id = id, ench = tonumber(ench) }
    end
  end
  return slots
end

function Armory.Sharing()
  return BG.Consent.Line("gear")
end

-- Publishes what we wear if we share it and it changed; takes it back if we stopped sharing.
function Armory.Publish()
  local me = Names.Me()
  if not (me and BG.Guild.info and BG.Consent.Accepted()) then
    return nil, "consent"
  end
  local old = Store.Get("gear", me)
  if not Armory.Sharing() then
    if old and not old.del then
      return Store.Delete("gear", me)
    end
    return nil, "no"
  end
  local slots, il = Armory.Read("player")
  if not slots then
    return nil, "vacío"
  end
  local list = encode(slots)
  if old and not old.del and old.d and table.concat(old.d.s or {}, ",") == table.concat(list, ",") and old.d.il == il
    and Store.Now() - old.at < GEAR_TTL / 2 then
    return old -- the same as what the guild already has
  end
  return Store.Put("gear", me, { s = list, il = il }, { lane = "bulk" })
end

function Armory.SetSharing(on)
  BG.Consent.SetLine("gear", on)
  return Armory.Publish()
end

local publishing = false
local function publishSoon()
  if publishing then
    return
  end
  publishing = true
  C_Timer.After(PUBLISH_WAIT, function()
    publishing = false
    Armory.Publish()
  end)
end
BG:On("PLAYER_EQUIPMENT_CHANGED", publishSoon)
BG:On("BG_PEERS_CHANGED", publishSoon)

-- Seen by you ----------------------------------------------------------------------------------------------------------
local function seenBook()
  local g = BG.Guild.Entry()
  if not g then
    return {}
  end
  g.armorySeen = g.armorySeen or {}
  return g.armorySeen
end

-- A unit token for `name` near us now (target, mouseover, focus, our group), or nil.
function Armory.UnitOf(name)
  local units = { "target", "mouseover", "focus" }
  for i = 1, 4 do
    units[#units + 1] = "party" .. i
  end
  for i = 1, 40 do
    units[#units + 1] = "raid" .. i
  end
  for _, u in ipairs(units) do
    local n = Names.Unit(u) -- (on Forever UnitName gives the first name alone: Names.lua)
    if n and Names.Same(n, name) and UnitIsPlayer and UnitIsPlayer(u) then
      return u
    end
  end
  return nil
end

local pending -- { name, guid, unit, at }
Armory.lastStatus = {}

-- Asks the game for `name`'s equipment (they must be near). Returns true, or nil and why: "lejos" (not near),
-- "combate", "ventana" (the game's inspect window is open), "ocupado" (another inspection is waiting), "no" (the game
-- does not allow it).
function Armory.Inspect(name)
  if not BG.InGame() then
    return nil, "capturas"
  end
  local short = Names.Short(name)
  if pending and GetTime() - pending.at < INSPECT_TIMEOUT then
    return nil, "ocupado"
  end
  if InCombatLockdown and InCombatLockdown() then
    return nil, "combate"
  end
  if InspectFrame and InspectFrame.IsShown and InspectFrame:IsShown() then
    return nil, "ventana"
  end
  local unit = short and Armory.UnitOf(short)
  if not unit then
    return nil, "lejos"
  end
  if not (CanInspect and NotifyInspect) or not CanInspect(unit) then
    return nil, "no"
  end
  local guid = UnitGUID(unit)
  pending = { name = short, guid = guid, unit = unit, at = GetTime() }
  Armory.lastStatus[short] = "pedido"
  NotifyInspect(unit)
  local token = pending
  C_Timer.After(INSPECT_TIMEOUT, function()
    if pending == token then
      pending = nil
      Armory.lastStatus[short] = "sin respuesta"
      BG:Fire("BG_ARMORY_CHANGED")
    end
  end)
  BG:Fire("BG_ARMORY_CHANGED")
  return true
end

BG:On("INSPECT_READY", function(guid)
  local p = pending
  if not p or (guid and p.guid and guid ~= p.guid) then
    return
  end
  pending = nil
  local unit = (p.unit and UnitGUID(p.unit) == p.guid) and p.unit or Armory.UnitOf(p.name)
  local slots, il = nil, nil
  if unit then
    slots, il = Armory.Read(unit)
  end
  if ClearInspectPlayer then
    pcall(ClearInspectPlayer)
  end
  if slots then
    seenBook()[p.name] = { s = encode(slots), il = il, at = Store.Now() }
    Armory.lastStatus[p.name] = "visto"
  else
    Armory.lastStatus[p.name] = "sin respuesta"
  end
  BG:Fire("BG_ARMORY_CHANGED")
end)

BG:On("BG_STORE_CHANGED", function(name)
  if name == "gear" or name == "crafters" then
    BG:Fire("BG_ARMORY_CHANGED")
  end
end)

-- From far away (0.25.0, Peregrino: «no tiene sentido que tengas que estar cerca»). The game only inspects whoever is
-- near (about 30 yards), as its own Inspect does. Far away, BlazonGuild asks the member's addon: they get the
-- question in BlazonGuild's own dialog, and if they say yes they share their gear with the guild (the Armory shows
-- it from then on, near or far). One question per asker every ten minutes; never in combat (it waits).
local ASK_GAP = 10 * 60
local asked, askedBy, waiting = {}, {}, {}

-- «Ver su equipo»: near, the game's inspection; far, the question. Returns true and "inspect" | "asked", or nil and why.
function Armory.Look(name)
  local short = Names.Short(name)
  if not short then
    return nil, "no"
  end
  if Armory.UnitOf(short) then
    local ok, why = Armory.Inspect(short)
    return ok and true or nil, ok and "inspect" or why
  end
  if not BG.Peers.Get(short) then
    return nil, "sin addon"
  end
  if asked[short] and GetTime() - asked[short] < ASK_GAP then
    return nil, "ya pedido"
  end
  local ok, why = BG.Comm.Send("AY", {}, "WHISPER", short, { lane = "normal" })
  if not ok then
    return nil, why
  end
  asked[short] = GetTime()
  Armory.lastStatus[short] = "preguntado"
  BG:Fire("BG_ARMORY_CHANGED")
  return true, "asked"
end

local function ask(from)
  if InCombatLockdown and InCombatLockdown() then
    waiting[from] = true
    return
  end
  BG.UI.Dialog({
    wait = true,
    title = string.format("%s quiere ver tu equipo", from),
    items = { "En la Armería de BlazonGuild. Si dices que sí, compartes con tu hermandad lo que llevas puesto (lo mismo que ve quien te inspecciona en el juego), y se pone al día cuando te cambias.",
      { note = "Lo puedes quitar cuando quieras en la Armería («Compartir mi equipo»)." } },
    primary = { label = "Compartirlo", fn = function()
      Armory.SetSharing(true)
      BG.Comm.Send("AZ", { y = 1 }, "WHISPER", from, { lane = "normal" })
    end },
    secondary = { label = "Ahora no", fn = function()
      BG.Comm.Send("AZ", { y = 0 }, "WHISPER", from, { lane = "normal" })
    end },
  })
end

BG.Comm.Register("AY", function(sender)
  if not BG.Guild.Find(sender) then
    return -- (only guildmates may ask)
  end
  if Armory.Sharing() then
    Armory.Publish()
    BG.Comm.Send("AZ", { y = 1 }, "WHISPER", sender, { lane = "normal" })
    return
  end
  if askedBy[sender] and GetTime() - askedBy[sender] < ASK_GAP then
    return
  end
  askedBy[sender] = GetTime()
  ask(Names.Short(sender))
end, { channels = { "WHISPER" }, maxBytes = 40 })

BG.Comm.Register("AZ", function(sender, b)
  local short = Names.Short(sender)
  if type(b) ~= "table" or not BG.Guild.Find(sender) or not asked[short] then
    return
  end
  Armory.lastStatus[short] = b.y == 1 and "compartido" or "no quiere"
  BG:Notify(b.y == 1 and string.format("%s comparte su equipo", short) or string.format("%s prefiere no compartirlo", short),
    b.y == 1 and "Lo verás en la Armería en un momento." or "Puedes inspeccionarle cuando lo tengas cerca.", { kind = b.y == 1 and "success" or "info", view = "armory" })
  BG:Fire("BG_ARMORY_CHANGED")
end, { channels = { "WHISPER" }, maxBytes = 40 })

BG:On("PLAYER_REGEN_ENABLED", function()
  for from in pairs(waiting) do
    waiting[from] = nil
    ask(from)
  end
end)

-- Once per character: the question of sharing the gear, a minute after logging in (so the Armory fills by itself).
BG:On("PLAYER_LOGIN", function()
  C_Timer.After(60, function()
    local me = Names.Me()
    if not (me and BG.Consent.Accepted() and BG.Guild.info) or Armory.Sharing() then
      return
    end
    BG.db.gearAsked = BG.db.gearAsked or {}
    if BG.db.gearAsked[me] or (BG.db.consentLines and BG.db.consentLines.gear == false) then
      return
    end
    BG.db.gearAsked[me] = true
    if InCombatLockdown and InCombatLockdown() then
      return
    end
    BG.UI.Dialog({
      wait = true,
      title = "¿Compartes tu equipo?",
      items = { "Así tu hermandad te ve en la Armería aunque estéis lejos: lo que llevas puesto y su nivel, lo mismo que ve quien te inspecciona en el juego.",
        { note = "Lo puedes cambiar cuando quieras en la Armería." } },
      primary = { label = "Compartirlo", fn = function()
        Armory.SetSharing(true)
      end },
      secondary = { label = "Ahora no" },
    })
  end)
end)

-- Reading ----------------------------------------------------------------------------------------------------------------
-- One member's equipment: { slots, il, at, source = "shared" | "seen" } (the newest of the two), or nil.
function Armory.Of(name)
  local short = Names.Short(name)
  if not short then
    return nil
  end
  local r = Store.Get("gear", short)
  local shared = r and not r.del and r.d and { slots = decode(r.d.s), il = r.d.il, at = r.at, source = "shared" } or nil
  local s = seenBook()[short]
  local seen = s and { slots = decode(s.s), il = s.il, at = s.at, source = "seen" } or nil
  if shared and seen then
    return seen.at > shared.at and seen or shared
  end
  return shared or seen
end

-- The guild's members with what we know of each one's equipment, the best item level first, then the rest by name.
function Armory.Members()
  local out = {}
  for _, m in ipairs(BG.Guild.members or {}) do
    local name = Names.Short(m.name)
    if name then
      local g = Armory.Of(name)
      out[#out + 1] = { name = name, m = m, gear = g, il = g and g.il or nil }
    end
  end
  table.sort(out, function(a, b)
    if (a.il or -1) ~= (b.il or -1) then
      return (a.il or -1) > (b.il or -1)
    end
    return a.name < b.name
  end)
  return out
end

-- How many share and the guild's average item level (of those we know).
function Armory.Summary()
  local shared, known, sum = 0, 0, 0
  for _, x in ipairs(Armory.Members()) do
    if x.gear then
      known = known + 1
      if x.gear.source == "shared" then
        shared = shared + 1
      end
      if x.il then
        sum = sum + x.il
      end
    end
  end
  return { shared = shared, known = known, avg = known > 0 and math.floor(sum / known + 0.5) or nil }
end

-- A member's professions, from the crafters' records (Crafts.lua): { "Herrería 300", ... }.
function Armory.Professions(name)
  local out = {}
  for _, r in ipairs(Store.List("crafters", function(x)
    return Names.Same(x.id:match("^(.-)|"), name)
  end)) do
    out[#out + 1] = (r.d and r.d.p or r.id:match("|(.+)$") or "?") .. ((r.d and r.d.r and r.d.r > 0) and (" " .. r.d.r) or "")
  end
  table.sort(out)
  return out
end

-- The item's name, quality and icon, as the game has them. The icon comes from the game's own files, so it shows at
-- once; the name may need a moment (the game asks the server, once per item): the view refreshes when it comes.
local asked = {}
function Armory.Item(id)
  local name, _, quality, _, icon = BG.ItemInfo(id)
  if not icon then
    local ok, i = pcall((C_Item and C_Item.GetItemIconByID) or GetItemIcon, id)
    icon = ok and i or nil
  end
  if not name and not asked[id] and C_Item and C_Item.RequestLoadItemDataByID then
    asked[id] = true
    pcall(C_Item.RequestLoadItemDataByID, id)
  end
  return { name = name, quality = quality, icon = icon }
end

-- (Only the items the Armería asked for: the game says this for every item any window loads, a bag or a chat link.)
local refreshSoon = false
BG:On("GET_ITEM_INFO_RECEIVED", function(id)
  if refreshSoon or not asked[tonumber(id)] then
    return
  end
  refreshSoon = true
  C_Timer.After(0.5, function()
    refreshSoon = false
    BG:Fire("BG_ARMORY_CHANGED")
  end)
end)
