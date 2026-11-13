-- Map and layers (entrega 7; Olympus' Positions.lua, Layers.lua, Hop.lua and PartyGuard.lua, MIT, our own
-- implementation). Everything here stays inside the guild (GUILD and whispers between guildmates) and only for
-- whoever turns it on ("Compartir mi posición y mi capa", off by default).
--
-- Positions: a sharer's client sends where they are (zone map and x, y) every 15 s or more, when they moved;
-- never inside instances. Guildmates draw them as class-coloured dots on the world map.
-- Layers: a server copies a busy zone into "layers". Nothing in the game names them, but the creatures' GUIDs
-- carry the zone's copy (Creature-0-server-instance-ZONE-npc-spawn): the same number in the same zone is the
-- same layer. A sharer's client reads it from the creatures they target, mouse over or see (two different
-- creatures must agree) and tells the guild. On Forever a realm group is split into sub-realms, so a layer is
-- (zone, number, sub-realm).
-- Layer hop: asking a guildmate on another layer for an invite. They get the request and decide (the addon
-- never invites anyone by itself); once the game moves us to their layer, the addon takes us out of the group.
local _, BG = ...
local Layers = { seen = {}, requests = {} }
BG.Layers = Layers
local Positions = { mates = {} }
BG.Positions = Positions
local Names, Comm, Peers = BG.Names, BG.Comm, BG.Peers

local POS_EXPIRE = 90
local POS_MIN = 15
local LAYER_EVERY = 600
local LAYER_GAP = 30
local LAYER_EXPIRE = 2 * LAYER_EVERY + 60
local HOLD = 6 -- seconds without our layer's creatures before another one takes over
local EVIDENCE = 15 -- two different creatures within this window
local REQUEST_TTL = 5 * 60
local HOP_WAIT = 90 -- seconds to be invited
local RELOG_WINDOW = 10 * 60
local TICK = 5

-- Settings (per character) ------------------------------------------------------------------------------------
local function me()
  return Names.Me()
end

function Layers.Sharing()
  local m = me()
  return m ~= nil and BG.db.mapShare ~= nil and BG.db.mapShare[m] == true
end

function Layers.Helping()
  local m = me()
  return Layers.Sharing() and not (BG.db.hopNoHelp and BG.db.hopNoHelp[m])
end

-- Turns sharing on or off. Off: our dot and our layer leave every screen at once.
function Layers.SetSharing(on)
  local m = me()
  if not m then
    return nil, "sin personaje"
  end
  if on and not BG.Consent.Accepted() then
    return nil, "consent"
  end
  BG.db.mapShare = BG.db.mapShare or {}
  BG.db.mapShare[m] = on and true or nil
  if on then
    Positions.Send(true)
    Layers.Announce(true)
  else
    Comm.Send("PS", { off = 1 }, "GUILD", nil, { lane = "normal", key = "PS" })
    Comm.Send("LY", { off = 1 }, "GUILD", nil, { lane = "normal", key = "LY" })
  end
  BG:Fire("BG_MAP_CHANGED")
  return true
end

function Layers.SetHelping(on)
  local m = me()
  if not m then
    return nil
  end
  BG.db.hopNoHelp = BG.db.hopNoHelp or {}
  BG.db.hopNoHelp[m] = (not on) or nil
  Layers.Announce(true)
  BG:Fire("BG_MAP_CHANGED")
  return true
end

-- Where we are: the zone map (not a continent) and x, y; nil inside instances or when the game hides it.
local function zoneMap()
  if IsInInstance and IsInInstance() then
    return nil
  end
  local map = C_Map and C_Map.GetBestMapForUnit and C_Map.GetBestMapForUnit("player")
  if not map then
    return nil
  end
  if C_Map.GetMapInfo then
    local info = C_Map.GetMapInfo(map)
    if info and info.mapType and info.mapType <= 2 then
      return nil -- the world or a continent (a boat, a flight): no zone
    end
  end
  return map
end
Layers.ZoneMap = zoneMap

local function myPosition()
  local map = zoneMap()
  if not map or not C_Map.GetPlayerMapPosition then
    return nil
  end
  local ok, pos = pcall(C_Map.GetPlayerMapPosition, map, "player")
  if not ok or not pos then
    return nil
  end
  local x, y = pos:GetXY()
  if not x or (issecretvalue and (issecretvalue(x) or issecretvalue(y))) or (x == 0 and y == 0) then
    return nil
  end
  return map, x, y
end
Layers.MyPosition = myPosition

-- Positions ---------------------------------------------------------------------------------------------------
local lastPos = { t = -math.huge }

local function posInterval()
  return math.max(POS_MIN, math.floor(#Peers.Active() / 3))
end

function Positions.Send(force)
  if not Layers.Sharing() or not IsInGuild() then
    return false
  end
  local map, x, y = myPosition()
  if not map then
    return false
  end
  local t = GetTime()
  local moved = lastPos.map ~= map or math.abs((lastPos.x or 0) - x) > 0.004 or math.abs((lastPos.y or 0) - y) > 0.004
  if not force and (t - lastPos.t < posInterval() or (not moved and t - lastPos.t < 50)) then
    return false
  end
  lastPos = { map = map, x = x, y = y, t = t }
  return Comm.Send("PS", { m = map, x = math.floor(x * 10000), y = math.floor(y * 10000) }, "GUILD", nil, { lane = "bulk", key = "PS" })
end

Comm.Register("PS", function(sender, b)
  local m = BG.Guild.Find(sender)
  if type(b) ~= "table" or not m then
    return
  end
  if b.off then
    Positions.mates[sender] = nil
  else
    local map, x, y = tonumber(b.m), tonumber(b.x), tonumber(b.y)
    if not (map and x and y and x >= 0 and x <= 10000 and y >= 0 and y <= 10000) then
      return
    end
    Positions.mates[sender] = { name = sender, m = math.floor(map), x = x / 10000, y = y / 10000, t = GetTime(), c = m.classFile }
  end
  BG:Fire("BG_MAP_CHANGED")
end, { maxBytes = 80 })

-- Guildmates sharing their position now (heard in the last minute and a half).
function Positions.Mates()
  local out, t = {}, GetTime()
  for name, p in pairs(Positions.mates) do
    local m = BG.Guild.Find(name)
    if t - p.t > POS_EXPIRE or (m and not m.online) then
      Positions.mates[name] = nil
    else
      out[#out + 1] = p
    end
  end
  table.sort(out, function(a, b)
    return a.name < b.name
  end)
  return out
end

-- (x, y) of map `m` on map `shown`, through the world's coordinates (the game's own conversion); nil when it
-- falls outside.
function Positions.Translate(m, x, y, shown)
  if m == shown then
    return x, y
  end
  if not (C_Map and C_Map.GetWorldPosFromMapPos and C_Map.GetMapPosFromWorldPos and CreateVector2D) then
    return nil
  end
  local ok, cont, world = pcall(C_Map.GetWorldPosFromMapPos, m, CreateVector2D(x, y))
  if not ok or not cont or not world then
    return nil
  end
  local ok2, _, pos = pcall(C_Map.GetMapPosFromWorldPos, cont, world, shown)
  if not ok2 or not pos then
    return nil
  end
  local px, py = pos:GetXY()
  if not px or px < 0 or px > 1 or py < 0 or py > 1 then
    return nil
  end
  return px, py
end

-- The world's coordinates of (x, y) on map `m`: the continent, then north and west in yards (the game's axes:
-- its first number grows to the north, the second to the west).
local function worldOf(m, x, y)
  if not (C_Map and C_Map.GetWorldPosFromMapPos and CreateVector2D) then
    return nil
  end
  local ok, cont, w = pcall(C_Map.GetWorldPosFromMapPos, m, CreateVector2D(x, y))
  if not ok or not cont or not w then
    return nil
  end
  local north, west = w:GetXY()
  if type(north) ~= "number" or type(west) ~= "number" then
    return nil
  end
  return cont, north, west
end

-- How far (x, y) of map `m` is from us, in yards to the east and to the south; nil when we have no position
-- (an instance, a boat) or it is on another continent.
function Positions.Offset(m, x, y)
  local mm, mx, my = myPosition()
  if not mm then
    return nil
  end
  local c1, n1, w1 = worldOf(mm, mx, my)
  local c2, n2, w2 = worldOf(m, x, y)
  if not c1 or c1 ~= c2 then
    return nil
  end
  return w1 - w2, n1 - n2
end

-- World map dots -------------------------------------------------------------------------------------------
local pins = {}
Positions.pins = pins

local function canvas()
  local w = WorldMapFrame
  if not w then
    return nil
  end
  if w.GetCanvas then
    return w:GetCanvas()
  end
  return w.ScrollContainer and w.ScrollContainer.Child or nil
end

local function makePin(parent)
  local f = CreateFrame("Frame", nil, parent)
  f:SetFrameLevel((parent:GetFrameLevel() or 1) + 50)
  f.edge = f:CreateTexture(nil, "BACKGROUND")
  f.edge:SetTexture("Interface\\CHARACTERFRAME\\TempPortraitAlphaMask")
  f.edge:SetVertexColor(0, 0, 0, 0.9)
  f.edge:SetAllPoints()
  f.dot = f:CreateTexture(nil, "ARTWORK")
  f.dot:SetTexture("Interface\\CHARACTERFRAME\\TempPortraitAlphaMask")
  f.dot:SetPoint("TOPLEFT", 1.5, -1.5)
  f.dot:SetPoint("BOTTOMRIGHT", -1.5, 1.5)
  f:EnableMouse(true)
  f:SetScript("OnEnter", function(self)
    if not (GameTooltip and self.mate) then
      return
    end
    local m = BG.Guild.Find(self.mate.name)
    local c = BG.classColor(self.mate.c)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:AddLine(self.mate.name, c[1], c[2], c[3])
    if m then
      GameTooltip:AddLine((m.level and ("Nivel " .. m.level) or "") .. (m.zone and (", " .. m.zone) or ""), 0.8, 0.8, 0.8)
    end
    GameTooltip:AddLine("Clic: seguirle con la flecha del minimapa", 0.6, 0.6, 0.6)
    BG.ShowTip()
  end)
  f:SetScript("OnMouseUp", function(self)
    if self.mate and BG.Radar then
      BG.Radar.Follow({ mate = self.mate.name })
    end
  end)
  f:SetScript("OnLeave", function()
    if GameTooltip then
      GameTooltip:Hide()
    end
  end)
  return f
end

function Positions.Draw()
  local c = canvas()
  local shown = c and WorldMapFrame:IsShown() and WorldMapFrame.GetMapID and WorldMapFrame:GetMapID()
  local n = 0
  if shown then
    local w, h = c:GetWidth() or 0, c:GetHeight() or 0
    local scale = WorldMapFrame.GetCanvasScale and WorldMapFrame:GetCanvasScale() or 1
    for _, mate in ipairs(Positions.Mates()) do
      local px, py = Positions.Translate(mate.m, mate.x, mate.y, shown)
      if px and w > 0 then
        n = n + 1
        local pin = pins[n] or makePin(c)
        pins[n] = pin
        local size = 12 / math.max(0.2, scale)
        pin:SetSize(size, size)
        pin:ClearAllPoints()
        pin:SetPoint("CENTER", c, "TOPLEFT", px * w, -py * h)
        local col = BG.classColor(mate.c)
        pin.dot:SetVertexColor(col[1], col[2], col[3], 1)
        pin.mate, pin.mx, pin.my = mate, px, py
        pin:Show()
      end
    end
  end
  for i = n + 1, #pins do
    pins[i]:Hide()
    pins[i].mate = nil
  end
  return n
end

local hooked = false
local function hookMap()
  if hooked or not WorldMapFrame then
    return
  end
  hooked = true
  WorldMapFrame:HookScript("OnShow", Positions.Draw)
  if hooksecurefunc and WorldMapFrame.OnMapChanged then
    pcall(hooksecurefunc, WorldMapFrame, "OnMapChanged", Positions.Draw)
  end
end

-- Layers ---------------------------------------------------------------------------------------------------
local mine -- { m, z, t, firstGUID, firstAt, confirmed }
local pending -- { z, guids, n, t }
local lastAnnounce, retryQueued = -math.huge, false

function Layers.ZoneUID(guid)
  if type(guid) ~= "string" then
    return nil
  end
  local kind, z = guid:match("^(%a+)%-%d+%-%d+%-%d+%-(%d+)%-")
  if kind ~= "Creature" and kind ~= "Vehicle" then
    return nil
  end
  return tonumber(z)
end

local function realm()
  return GetNormalizedRealmName and GetNormalizedRealmName() or nil
end

function Layers.Mine()
  return mine and mine.confirmed and mine or nil
end

-- A creature seen (target, mouse-over, nameplate). A layer counts once two different creatures show it. Another
-- layer takes over from ours only when ours has not been seen for HOLD seconds and two different creatures show
-- the new one (a zone's border shows creatures of other copies now and then); at once in a new zone.
function Layers.Observe(unit)
  local guid = UnitGUID and UnitGUID(unit)
  local z = Layers.ZoneUID(guid)
  local map = z and zoneMap()
  if not map then
    return
  end
  local t = GetTime()
  if mine and mine.m == map and mine.z == z then
    mine.t, pending = t, nil
    if not mine.confirmed and guid ~= mine.firstGUID then
      mine.confirmed = true
      Layers.Changed()
    end
    return
  end
  if not (mine and mine.m == map and mine.confirmed) then
    mine = { m = map, z = z, t = t, firstGUID = guid, confirmed = false } -- a first look at this zone's layer
    return
  end
  if not pending or pending.z ~= z or t - pending.t > EVIDENCE then
    pending = { z = z, guids = { [guid] = true }, n = 1, t = t }
    return
  end
  if not pending.guids[guid] then
    pending.guids[guid] = true
    pending.n = pending.n + 1
  end
  if pending.n >= 2 and t - mine.t >= HOLD then
    mine = { m = map, z = z, t = t, firstGUID = guid, confirmed = true }
    pending = nil
    Layers.Changed()
  end
end

function Layers.Changed()
  Layers.Announce(true)
  Layers.CheckHop()
  BG:Fire("BG_MAP_CHANGED")
end

function Layers.Announce(force)
  if not (mine and mine.confirmed) or not Layers.Sharing() or not IsInGuild() then
    return false
  end
  local t = GetTime()
  if not force and t - lastAnnounce < LAYER_EVERY then
    return false
  end
  if t - lastAnnounce < LAYER_GAP then
    if force and not retryQueued then
      retryQueued = true
      C_Timer.After(LAYER_GAP - (t - lastAnnounce) + 1, function()
        retryQueued = false
        Layers.Announce(true)
      end)
    end
    return false
  end
  lastAnnounce = t
  return Comm.Send("LY", { m = mine.m, z = mine.z, r = realm(), h = Layers.Helping() and 1 or nil }, "GUILD", nil, { lane = "normal", key = "LY" })
end

Comm.Register("LY", function(sender, b)
  if type(b) ~= "table" or not BG.Guild.Find(sender) then
    return
  end
  if b.off then
    Layers.seen[sender] = nil
  else
    local m, z = tonumber(b.m), tonumber(b.z)
    if not (m and z) then
      return
    end
    Layers.seen[sender] = { name = sender, m = math.floor(m), z = math.floor(z), r = type(b.r) == "string" and #b.r <= 40 and b.r or nil, h = b.h == 1, t = GetTime() }
  end
  BG:Fire("BG_MAP_CHANGED")
end, { maxBytes = 120 })

local function layerKey(z, r)
  return tostring(z) .. "@" .. tostring(r or realm())
end

-- The layers of zone `map` that the guild knows: { key, z, r, members = { names }, mine, label }, ours first.
function Layers.InZone(map)
  local groups, order = {}, {}
  local t = GetTime()
  local function add(name, z, r, rankIndex)
    local key = layerKey(z, r)
    local g = groups[key]
    if not g then
      g = { key = key, z = z, r = r or realm(), members = {}, best = 99 }
      groups[key] = g
      order[#order + 1] = g
    end
    g.members[#g.members + 1] = name
    if rankIndex < g.best then
      g.best, g.label = rankIndex, name
    end
  end
  for name, s in pairs(Layers.seen) do
    local m = BG.Guild.Find(name)
    if t - s.t > LAYER_EXPIRE or (m and not m.online) then
      Layers.seen[name] = nil
    elseif s.m == map then
      add(name, s.z, s.r, m and m.rankIndex or 99)
    end
  end
  local my = Layers.Mine()
  if my and my.m == map then
    local m = BG.Guild.me
    add(me(), my.z, realm(), m and m.rankIndex or 99)
    groups[layerKey(my.z, realm())].mine = true
  end
  table.sort(order, function(a, b)
    if (a.mine and 1 or 0) ~= (b.mine and 1 or 0) then
      return a.mine == true
    end
    return #a.members > #b.members
  end)
  return order
end

-- Who on layer `group` can be asked for an invite: someone who helps, not ourselves.
function Layers.HostOf(group)
  for _, n in ipairs(group.members) do
    local s = Layers.seen[n]
    if s and s.h and not Names.IsMe(n) then
      return n
    end
  end
  return nil
end

-- Layer hop ---------------------------------------------------------------------------------------------------
local function hop()
  local m = me()
  return m and BG.db.hopPending and BG.db.hopPending[m] or nil
end

local function setHop(h)
  local m = me()
  if not m then
    return
  end
  BG.db.hopPending = BG.db.hopPending or {}
  BG.db.hopPending[m] = h
  BG:Fire("BG_MAP_CHANGED")
end

function Layers.Pending()
  return hop()
end

-- Asks `host` (a guildmate on another layer) for an invite. They decide; the addon never invites by itself.
function Layers.Ask(host)
  local s = Layers.seen[Names.Short(host) or ""]
  if not s or not s.h then
    return nil, "no ayuda"
  end
  if IsInGroup and IsInGroup() then
    return nil, "en grupo"
  end
  if not Comm.Send("LR", { m = s.m, z = s.z }, "WHISPER", s.name, { lane = "alert" }) then
    return nil, "envío"
  end
  setHop({ host = s.name, m = s.m, z = s.z, r = s.r, at = time() })
  return true
end

function Layers.CancelHop()
  setHop(nil)
end

Comm.Register("LR", function(sender, b)
  if type(b) ~= "table" or not BG.Guild.Find(sender) then
    return
  end
  if not Layers.Helping() then
    return Comm.Send("LN", {}, "WHISPER", sender, { lane = "alert" })
  end
  Layers.requests[sender] = { name = sender, at = GetTime() }
  BG:Notify("Petición de capa", sender .. " quiere pasar a tu capa. Ábrelo en Mapa para invitarle (o no).", { kind = "info", view = "map", sound = "READY_CHECK" })
  BG:Fire("BG_MAP_CHANGED")
end, { channels = { "WHISPER" }, maxBytes = 80 })

Comm.Register("LN", function(sender)
  local h = hop()
  if h and Names.Same(h.host, sender) then
    setHop(nil)
    BG:Notify("Ahora no puede", sender .. " no puede invitarte ahora. Prueba con otra persona de esa capa.", { kind = "warning", view = "map" })
  end
end, { channels = { "WHISPER" }, maxBytes = 20 })

function Layers.Requests()
  local out, t = {}, GetTime()
  for name, r in pairs(Layers.requests) do
    if t - r.at > REQUEST_TTL then
      Layers.requests[name] = nil
    else
      out[#out + 1] = r
    end
  end
  table.sort(out, function(a, b)
    return a.at < b.at
  end)
  return out
end

-- The host's answer (a click): invite them, or say no.
function Layers.Answer(name, yes)
  local r = Layers.requests[name]
  if not r then
    return nil, "no existe"
  end
  Layers.requests[name] = nil
  if yes then
    local invite = (C_PartyInfo and C_PartyInfo.InviteUnit) or InviteUnit
    if invite and BG.InGame() then
      invite(name)
    end
  else
    Comm.Send("LN", {}, "WHISPER", name, { lane = "alert" })
  end
  BG:Fire("BG_MAP_CHANGED")
  return true
end

-- The asker's side: once in the host's group, we wait to be on their layer (a creature tells us), then leave
-- the group. On another sub-realm the game only moves us after leaving the game and coming back.
local toldRelog = false
function Layers.CheckHop()
  local h = hop()
  if not h then
    return
  end
  if not h.joined and not IsInGroup() and time() - h.at > HOP_WAIT then
    setHop(nil)
    BG:Notify("Sin invitación", h.host .. " no te invitó a tiempo. Puedes pedírselo de nuevo o a otra persona de su capa.", { kind = "warning", view = "map" })
    return
  end
  if time() - h.at > RELOG_WINDOW or (h.joined and not IsInGroup()) then
    setHop(nil)
    BG:Notify("Salto de capa sin terminar", "No llegaste a la capa de " .. h.host .. ". Puedes intentarlo de nuevo.", { kind = "warning", view = "map" })
    return
  end
  if IsInGroup() and not h.joined then
    h.joined = true
    setHop(h)
    if h.r and h.r ~= realm() and not toldRelog then
      toldRelog = true
      BG:Notify("Ya estás en su grupo", h.host .. " juega en otro reino (" .. tostring(h.r) .. "). Sal del juego y vuelve a entrar sin salir del grupo: al llegar a su capa te sacamos del grupo.",
        { kind = "info", view = "map", duration = 20 })
    end
  end
  local my = Layers.Mine()
  if h.joined and my and my.m == h.m and my.z == h.z and (not h.r or h.r == realm()) then
    setHop(nil)
    local leave = (C_PartyInfo and C_PartyInfo.LeaveParty) or LeaveParty
    if leave and IsInGroup() and not BG.demo then
      leave()
    end
    BG:Notify("Ya estás en su capa", "Estás en la capa de " .. h.host .. ". Te hemos sacado del grupo.", { kind = "success", view = "map", sound = "LEVELUP" })
  end
end

-- Events and upkeep -------------------------------------------------------------------------------------------
BG:On("PLAYER_TARGET_CHANGED", function()
  Layers.Observe("target")
end)
BG:On("UPDATE_MOUSEOVER_UNIT", function()
  Layers.Observe("mouseover")
end)
BG:On("NAME_PLATE_UNIT_ADDED", function(unit)
  Layers.Observe(unit)
end)
BG:On("ZONE_CHANGED_NEW_AREA", function()
  mine, pending = nil, nil
  BG:Fire("BG_MAP_CHANGED")
end)
BG:On("GROUP_ROSTER_UPDATE", function()
  Layers.CheckHop()
end)

local function tick()
  if BG.Consent.Accepted() and IsInGuild() then
    Positions.Send(false)
    Layers.Announce(false)
    Layers.CheckHop()
  end
  hookMap()
  if WorldMapFrame and WorldMapFrame:IsShown() then
    Positions.Draw()
  end
  C_Timer.After(TICK, tick)
end
local started = false
BG:On("BG_ROSTER_UPDATED", function()
  if not started and BG.Guild.info then
    started = true
    C_Timer.After(TICK, tick)
  end
end)

-- The online members by zone (from the guild roster: everyone, with the addon or not), biggest first.
function Layers.Zones()
  local zones, order = {}, {}
  for _, m in ipairs(BG.Guild.members or {}) do
    if m.online and m.zone and m.zone ~= "" then
      local z = zones[m.zone]
      if not z then
        z = { zone = m.zone, members = {} }
        zones[m.zone] = z
        order[#order + 1] = z
      end
      z.members[#z.members + 1] = m
    end
  end
  local here = BG.Guild.me and BG.Guild.me.zone
  table.sort(order, function(a, b)
    if (a.zone == here) ~= (b.zone == here) then
      return a.zone == here
    end
    if #a.members ~= #b.members then
      return #a.members > #b.members
    end
    return a.zone < b.zone
  end)
  for _, z in ipairs(order) do
    table.sort(z.members, function(a, b)
      return a.level > b.level
    end)
  end
  return order
end

BG.commands = BG.commands or {}
BG.commands.mapa = function()
  if not (BG.window and BG.window:IsShown()) then
    BG:ToggleWindow()
  end
  BG:ShowView("map")
end
