-- Minimal simulation of the WoW client for offline tests: widgets, events, timers and the guild roster.
-- It does not draw anything; it exists to run the addon's real code paths and catch errors before the game does.
unpack = unpack or table.unpack
tinsert = table.insert
-- The game's bit library (LuaBitOp): 32-bit operations, the result a signed number as in the client.
do
  local function u(x) return math.floor(x) & 0xFFFFFFFF end
  local function i32(x) x = u(x) if x >= 0x80000000 then x = x - 0x100000000 end return x end
  local function fold(op)
    return function(a, ...)
      local r = u(a)
      for i = 1, select("#", ...) do r = op(r, u((select(i, ...)))) end
      return i32(r)
    end
  end
  bit = {
    tobit = i32,
    band = fold(function(a, b) return a & b end),
    bor = fold(function(a, b) return a | b end),
    bxor = fold(function(a, b) return a ~ b end),
    bnot = function(a) return i32(~u(a)) end,
    lshift = function(a, n) return i32(u(a) << (math.floor(n) % 32)) end,
    rshift = function(a, n) return i32(u(a) >> (math.floor(n) % 32)) end,
    arshift = function(a, n) return i32(i32(a) >> (math.floor(n) % 32) | (i32(a) < 0 and ~(0xFFFFFFFF >> (math.floor(n) % 32)) or 0)) end,
  }
end
date = os.date
time = os.time
strtrim = function(s) return (s:gsub("^%s+", ""):gsub("%s+$", "")) end
print = function(...) local t = {} for i = 1, select("#", ...) do t[#t + 1] = tostring(select(i, ...)) end SIM.log[#SIM.log + 1] = table.concat(t, " ") end

SIM = { log = {}, frames = {}, timers = {}, objects = {} }

local noop = function() end
local Methods = {}
local MT = {
  __index = function(_, k)
    local m = Methods[k]
    if m then return m end
    if type(k) == "string" and k:match("^[A-Z]") then return noop end
    return nil
  end,
}

local function new(kind, parent)
  local o = setmetatable({ __kind = kind, __shown = true, __w = 0, __h = 0, __scripts = {}, __text = "", __parent = parent }, MT)
  SIM.objects[#SIM.objects + 1] = o
  return o
end

function Methods.SetSize(self, w, h) self.__w, self.__h = w, h end
function Methods.SetWidth(self, w) self.__w = w end
function Methods.SetHeight(self, h) self.__h = h end
-- A frame sized by its anchors measures what it takes on screen, as in the game (a list shows as many rows as fit).
function Methods.GetWidth(self)
  if self.__w > 0 or not SIM.Rect then return self.__w end
  local r = SIM.Rect(self)
  return r and math.max(0, r.r - r.l) or 0
end
function Methods.GetHeight(self)
  if self.__h > 0 or not SIM.Rect then return self.__h end
  local r = SIM.Rect(self)
  return r and math.max(0, r.b - r.t) or 0
end
function Methods.SetScript(self, name, fn) self.__scripts[name] = fn end
function Methods.GetScript(self, name) return self.__scripts[name] end
function Methods.HookScript(self, name, fn)
  local old = self.__scripts[name]
  self.__scripts[name] = function(...) if old then old(...) end fn(...) end
end
function Methods.Show(self)
  local was = self.__shown
  self.__shown = true
  if not was and self.__scripts.OnShow then self.__scripts.OnShow(self) end
end
function Methods.Hide(self)
  local was = self.__shown
  self.__shown = false
  if was and self.__scripts.OnHide then self.__scripts.OnHide(self) end
end
function Methods.SetShown(self, v) if v then self:Show() else self:Hide() end end
function Methods.IsShown(self) return self.__shown end
function Methods.CreateTexture(self) return new("Texture", self) end
function Methods.CreateFontString(self) return new("FontString", self) end
-- Only what has a text in the game has SetText: a plain Frame does not (0.15.0 called it on a heading, a Frame,
-- and the real game stopped the Arena's screen; the stubs used to allow it).
local HAS_TEXT = { FontString = true, Button = true, CheckButton = true, EditBox = true, GameTooltip = true, MessageFrame = true, ScrollingMessageFrame = true, SimpleHTML = true }
function Methods.SetText(self, t)
  if not HAS_TEXT[self.__kind] then error("attempt to call a nil value (method 'SetText' of a " .. tostring(self.__kind) .. ")", 2) end
  self.__text = t == nil and "" or tostring(t)
end
function Methods.GetText(self) if not HAS_TEXT[self.__kind] then return nil end return self.__text end
function Methods.GetStringWidth(self)
  local longest = 0
  for line in (self.__text .. "\n"):gmatch("(.-)\n") do
    local plain = line:gsub("|T.-|t", "XX"):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("[\128-\191]", "")
    longest = math.max(longest, #plain)
  end
  return longest * (self.__size or 12) * 0.5 -- (about half the font size per letter: 6 px at 12, 13 px at 26)
end
function SIM.TextLines(fs, width)
  local n = 0
  for line in (fs.__text .. "\n"):gmatch("(.-)\n") do
    local plain = line:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("[\128-\191]", "")
    n = n + ((fs.__wrap and width and width > 0) and math.max(1, math.ceil(#plain * 5.6 / width)) or 1)
  end
  return math.max(1, n)
end
function Methods.SetJustifyH(self, j) self.__justify = j end
function Methods.SetWordWrap(self, on) self.__wrap = on and true or false end
-- A wrapped text is as tall as its lines (about 14 pixels each); a single line, one line.
function Methods.GetStringHeight(self)
  local r = SIM.Rect and SIM.Rect(self)
  return SIM.TextLines(self, r and (r.r - r.l) or 0) * 14
end
function Methods.SetFont(self, font, size) self.__size = tonumber(size) or self.__size return true end
function Methods.GetFont(self) return "font", self.__size or 12, "" end
function Methods.SetTexture(self, f) self.__tex = f return true end
function Methods.GetPoint() return "CENTER", nil, "CENTER", 0, 0 end

-- Anchors, kept so the tests can work out where everything ends up (SIM.Rect) and catch a button that sticks
-- out of its panel (SIM.CheckLayout). Same rules as the game: one anchor per point, two on an axis set the size.
function Methods.SetPoint(self, point, rel, relPoint, x, y)
  if type(rel) == "number" then
    rel, relPoint, x, y = nil, point, rel, relPoint
  elseif type(relPoint) == "number" then
    relPoint, x, y = point, relPoint, x
  end
  if type(rel) == "string" then rel = _G[rel] end
  self.__points = self.__points or {}
  self.__order = self.__order or {}
  if not self.__points[point] then self.__order[#self.__order + 1] = point end
  self.__points[point] = { rel = rel or self.__parent, relPoint = relPoint or point, x = x or 0, y = y or 0 }
end
function Methods.ClearAllPoints(self) self.__points = {} self.__order = {} end
function Methods.SetAllPoints(self, rel)
  self.__points = { TOPLEFT = { rel = rel or self.__parent, relPoint = "TOPLEFT", x = 0, y = 0 }, BOTTOMRIGHT = { rel = rel or self.__parent, relPoint = "BOTTOMRIGHT", x = 0, y = 0 } }
  self.__order = { "TOPLEFT", "BOTTOMRIGHT" }
end

local H_OF = { TOPLEFT = 0, LEFT = 0, BOTTOMLEFT = 0, TOP = 0.5, CENTER = 0.5, BOTTOM = 0.5, TOPRIGHT = 1, RIGHT = 1, BOTTOMRIGHT = 1 }
local V_OF = { TOPLEFT = 0, TOP = 0, TOPRIGHT = 0, LEFT = 0.5, CENTER = 0.5, RIGHT = 0.5, BOTTOMLEFT = 1, BOTTOM = 1, BOTTOMRIGHT = 1 }
SIM.screen = { w = 1920, h = 1080 }

-- The frame's rectangle on the screen ({ l, r, t, b }, y grows downwards), or nil if it cannot be known.
local resolving = {}
function SIM.Rect(f, memo)
  memo = memo or {}
  if memo[f] ~= nil then return memo[f] or nil end
  if f == UIParent then
    memo[f] = { l = 0, r = SIM.screen.w, t = 0, b = SIM.screen.h }
    return memo[f]
  end
  if resolving[f] then return nil end
  resolving[f] = true
  local pts = f.__points
  local hs, vs = {}, {}
  for _, point in ipairs(f.__order or {}) do
    local a = pts[point]
    local rr = a.rel and SIM.Rect(a.rel, memo)
    if rr and H_OF[point] and H_OF[a.relPoint] then
      hs[#hs + 1] = { h = H_OF[point], at = rr.l + H_OF[a.relPoint] * (rr.r - rr.l) + a.x }
      vs[#vs + 1] = { v = V_OF[point], at = rr.t + V_OF[a.relPoint] * (rr.b - rr.t) - a.y }
    end
  end
  resolving[f] = nil
  -- As the game does: two opposite edges set the size; else an edge with the frame's own size; else the centre.
  local function solve(list, key, size)
    local lo, hi, mid
    for _, c in ipairs(list) do
      if c[key] == 0 then lo = lo or c.at elseif c[key] == 1 then hi = hi or c.at else mid = mid or c.at end
    end
    if lo and hi then return lo, hi end
    if lo then return lo, lo + size end
    if hi then return hi - size, hi end
    if mid then return mid - size / 2, mid + size / 2 end
    return nil
  end
  local w = f.__w > 0 and f.__w or (f.__kind == "FontString" and Methods.GetStringWidth(f) or 0)
  local h = f.__h > 0 and f.__h or (f.__kind == "FontString" and 12 or 0)
  local l, r = solve(hs, "h", w)
  if f.__kind == "FontString" and f.__h == 0 and l then
    h = SIM.TextLines(f, r - l) * 14
  end
  local t, b = solve(vs, "v", h)
  if not l or not t then
    memo[f] = false
    return nil
  end
  memo[f] = { l = l, r = r, t = t, b = b }
  return memo[f]
end

local function visible(f)
  while f do
    if not f.__shown then return false end
    f = f.__parent
  end
  return true
end

-- Buttons, boxes and pickers that stick out of the panel they sit on (more than one pixel), inside `root`.
function SIM.CheckLayout(root)
  local memo, out = {}, {}
  local function inside(f)
    local p = f.__parent
    while p do
      if p == root then return true end
      p = p.__parent
    end
    return false
  end
  local function panelOf(f)
    local p = f.__parent
    while p and p ~= root do
      if p.isPanel then return p end
      p = p.__parent
    end
    return root
  end
  for _, f in ipairs(SIM.frames) do
    if (f.__kind == "Button" or f.__kind == "EditBox") and not f.isPanel and visible(f) and inside(f) then
      local r, pr = SIM.Rect(f, memo), SIM.Rect(panelOf(f), memo)
      if r and pr and (r.l < pr.l - 1 or r.r > pr.r + 1 or r.t < pr.t - 1 or r.b > pr.b + 1) then
        local label = (f.text and f.text.__text) or (f.__text ~= "" and f.__text) or f.__kind
        out[#out + 1] = string.format("%s (%d..%d, %d..%d) fuera de su panel (%d..%d, %d..%d)", label, r.l, r.r, r.t, r.b, pr.l, pr.r, pr.t, pr.b)
      end
    end
  end
  -- Two controls on top of each other (more than 2 pixels each way), unless one sits inside the other or a
  -- frame covers the screen above them (a form or a guide over the view).
  local controls = {}
  for _, f in ipairs(SIM.frames) do
    if (f.__kind == "Button" or f.__kind == "EditBox") and not f.isPanel and visible(f) and inside(f) then
      local r = SIM.Rect(f, memo)
      if r and r.r - r.l > 2 and r.b - r.t > 2 then
        controls[#controls + 1] = { f = f, r = r }
      end
    end
  end
  local function within(a, b)
    local p = a.__parent
    while p do
      if p == b then return true end
      p = p.__parent
    end
    return false
  end
  local function layer(f)
    local p = f
    while p and p ~= root do
      if p.__layer then return p.__layer end
      p = p.__parent
    end
    return 0
  end
  local function name(f)
    return (f.text and f.text.__text) or (f.__text ~= "" and f.__text) or f.__kind
  end
  -- A text running under a button (the text is cut, and hard to read): its visible part, as wide as its words
  -- (or its room, if shorter), against every button that is not its own.
  for _, fs in ipairs(SIM.objects) do
    if fs.__kind == "FontString" and fs.__text ~= "" and not fs.isPlaceholder and visible(fs) and inside(fs) then
      local r = SIM.Rect(fs, memo)
      if r then
        local words = Methods.GetStringWidth(fs)
        local l, rr = r.l, r.r
        if not fs.__wrap and rr - l > words then
          if fs.__justify == "RIGHT" then l = rr - words elseif fs.__justify == "CENTER" then l, rr = (l + rr - words) / 2, (l + rr + words) / 2 else rr = l + words end
        end
        local t, b = r.t, r.b
        for _, c in ipairs(controls) do
          if not within(fs, c.f) and layer(fs) == layer(c.f) then
            local w = math.min(rr, c.r.r) - math.max(l, c.r.l)
            local h = math.min(b, c.r.b) - math.max(t, c.r.t)
            if w > 3 and h > 3 then
              out[#out + 1] = string.format("el texto «%s» queda debajo de «%s»", fs.__text:sub(1, 40), name(c.f))
            end
          end
        end
      end
    end
  end
  -- A one-line text sized by its words (no width, one anchor) that runs out of its panel: in the game it is drawn
  -- whole, over the panel's edge and whatever is beside it (0.12.0: «0 de cobre» in the Tesorería's plates).
  for _, fs in ipairs(SIM.objects) do
    if fs.__kind == "FontString" and fs.__text ~= "" and not fs.__wrap and not fs.isPlaceholder and visible(fs) and inside(fs) then
      local r, pr = SIM.Rect(fs, memo), SIM.Rect(panelOf(fs), memo)
      local words = Methods.GetStringWidth(fs)
      if r and pr and math.abs((r.r - r.l) - words) < 0.5 and (r.l < pr.l - 1 or r.r > pr.r + 1) then
        out[#out + 1] = string.format("el texto «%s» se sale de su panel (%d..%d, panel %d..%d)", fs.__text:sub(1, 40), r.l, r.r, pr.l, pr.r)
      end
    end
  end
  -- A button whose own label (.text) is empty while the game's Button text was set: in the game nothing shows
  -- (0.15.1: «Apuntar mis muertes y bajas» and «Marcas en nombres y chat» were set that way).
  for _, c in ipairs(controls) do
    local f = c.f
    if f.__kind == "Button" and f.text and f.text.__kind == "FontString" and (f.text.__text or "") == "" and (f.__text or "") ~= "" then
      out[#out + 1] = string.format("el botón «%s» no enseña su texto (está en el botón, no en su etiqueta)", f.__text)
    end
  end
  for i = 1, #controls do
    for j = i + 1, #controls do
      local a, b = controls[i], controls[j]
      local w = math.min(a.r.r, b.r.r) - math.max(a.r.l, b.r.l)
      local h = math.min(a.r.b, b.r.b) - math.max(a.r.t, b.r.t)
      if w > 2 and h > 2 and not within(a.f, b.f) and not within(b.f, a.f) and layer(a.f) == layer(b.f) then
        out[#out + 1] = string.format("«%s» y «%s» se montan uno encima del otro", name(a.f), name(b.f))
      end
    end
  end
  return out
end
function Methods.GetEffectiveScale() return 1 end
function Methods.GetFrameLevel() return 1 end
-- A frame raised well above its parent (a form or a guide over a screen) is a layer of its own (SIM.CheckLayout).
function Methods.SetFrameLevel(self, n) if (n or 0) > 10 then self.__layer = n end end
-- Events WoW: Forever does not have (seen in the game: registering CRAFT_SHOW raised an error, 0.11.0).
SIM.unknownEvents = { CRAFT_SHOW = true, CRAFT_CLOSE = true, CRAFT_UPDATE = true }
function Methods.RegisterEvent(self, e)
  if SIM.unknownEvents[e] then error("Attempt to register unknown event \"" .. e .. "\"", 2) end
  self.__events = self.__events or {} self.__events[e] = true
end
function Methods.Click(self) if self.__scripts.OnClick then self.__scripts.OnClick(self, "LeftButton") end end
-- Buttons the game greys out (SetEnabled false): a test asks before pressing one, as a player could not.
function Methods.SetEnabled(self, on) self.__disabled = not on end
function Methods.Enable(self) self.__disabled = nil end
function Methods.Disable(self) self.__disabled = true end
function Methods.IsEnabled(self) return not self.__disabled end

function CreateFrame(kind, name, parent, template)
  local f = new(kind, parent)
  SIM.frames[#SIM.frames + 1] = f
  if name then _G[name] = f end
  if template == "SearchBoxTemplate" then f.Instructions = new("FontString", f) end
  return f
end

UIParent = new("Frame")
GameTooltip = new("Frame")
UISpecialFrames = {}
SlashCmdList = {}
SOUNDKIT = setmetatable({}, { __index = function() return 1 end })
PlaySound = noop
CreateColor = function(r, g, b, a) return { r = r, g = g, b = b, a = a } end
GetFileIDFromPath = function() return 1 end
SIM.cursor = { 0, 0 }
GetCursorPosition = function() return SIM.cursor[1], SIM.cursor[2] end
Minimap = new("Frame")
Minimap:SetSize(140, 140)
Minimap:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", -50, -60)
function Minimap:GetCenter() return 1800, 950 end
ToggleWorldMap = function() if WorldMapFrame:IsShown() then WorldMapFrame:Hide() else WorldMapFrame:Show() end end
Ambiguate = function(n) return n end
C_AddOns = { GetAddOnMetadata = function() return SIM.version end }
-- The game's language: Peregrino's client is in Spanish (a test can change it before logging in).
SIM.locale = "esES"
GetLocale = function() return SIM.locale end
C_GuildInfo = { GuildRoster = function() SIM.rosterRequests = (SIM.rosterRequests or 0) + 1 end, Invite = function(name) SIM.guildInvites = SIM.guildInvites or {} SIM.guildInvites[#SIM.guildInvites + 1] = name end }
-- A controllable clock: timers fire in time order when the test advances it (SIM.advance).
SIM.now = 1000
SIM.seq = 0
GetTime = function() return SIM.now end
debugprofilestop = function() return os.clock() * 1000 end
local function schedule(delay, fn, every)
  SIM.seq = SIM.seq + 1
  local t = { due = SIM.now + math.max(0, delay or 0), fn = fn, every = every, seq = SIM.seq }
  SIM.timers[#SIM.timers + 1] = t
  return t
end
C_Timer = {
  After = function(delay, fn) schedule(delay, fn) end,
  NewTicker = function(every, fn)
    local t = schedule(every, fn, every)
    return { Cancel = function() t.cancelled = true end }
  end,
}
function SIM.advance(dt)
  local target = SIM.now + dt
  for _ = 1, 100000 do
    local best, bi
    for i, t in ipairs(SIM.timers) do
      if not t.cancelled and t.due <= target and (not best or t.due < best.due or (t.due == best.due and t.seq < best.seq)) then best, bi = t, i end
    end
    if not best then break end
    SIM.now = math.max(SIM.now, best.due)
    if best.every then best.due = best.due + best.every else table.remove(SIM.timers, bi) end
    best.fn()
  end
  SIM.now = target
  for i = #SIM.timers, 1, -1 do if SIM.timers[i].cancelled then table.remove(SIM.timers, i) end end
end
function SIM.flushTimers() SIM.advance(1) end

-- Addon messages: sent frames go to the harness (__send, when a network test provides it) or to SIM.sent.
SIM.sent = {}
SIM.sendResult = 0
SIM.lockdown = false
C_ChatInfo = {
  RegisterAddonMessagePrefix = function(p) SIM.prefix = p return 0 end,
  InChatMessagingLockdown = function() return SIM.lockdown end,
  SendAddonMessage = function(prefix, msg, dist, target)
    if SIM.lockdown then return 11 end
    local res = SIM.sendResult
    if type(res) == "table" then res = table.remove(res, 1) or 0 end
    if res ~= 0 then return res end
    SIM.sent[#SIM.sent + 1] = { prefix = prefix, msg = msg, dist = dist, target = target, t = SIM.now }
    if __send then __send(prefix, msg, dist, target or "") end
    return 0
  end,
}
wipe = function(t) for k in pairs(t) do t[k] = nil end return t end
UpdateAddOnMemoryUsage = noop
GetAddOnMemoryUsage = function() return 512 end
GetNormalizedRealmName = function() return "ForeverPvP" end
SIM.me = { first = "El", second = "Peregrino", guid = "Player-6842-0A1B2C3D" }
UnitFullName = function() return SIM.me.first, SIM.me.second end
SIM.version = "0.20.0"
function SIM.fire(event, ...)
  for _, f in ipairs(SIM.frames) do
    if f.__events and f.__events[event] and f.__scripts.OnEvent then f.__scripts.OnEvent(f, event, ...) end
  end
end
-- Lay out every frame that waits for its size (the game does this on its own).
function SIM.layout(w, h)
  for _, o in ipairs(SIM.objects) do
    local fn = o.__scripts.OnSizeChanged
    if fn then
      local r = o.__w == 0 and SIM.Rect(o)
      fn(o, o.__w > 0 and o.__w or (r and r.r - r.l > 0 and r.r - r.l) or w, o.__h > 0 and o.__h or (r and r.b - r.t > 0 and r.b - r.t) or h)
    end
  end
end

-- Guild fixture with the shape verified in-game (17 values per roster row).
SIM.inGuild = true
local CLASSES = { { "PALADIN", "Paladín" }, { "WARRIOR", "Guerrero" }, { "MAGE", "Mago" }, { "PRIEST", "Sacerdote" }, { "ROGUE", "Pícaro" }, { "HUNTER", "Cazador" }, { "WARLOCK", "Brujo" }, { "DRUID", "Druida" }, { "SHAMAN", "Chamán" } }
local RANKS = { "Maestro", "Oficial", "Veterano", "Alter", "Miembro", "Iniciado" }
SIM.roster = {}
for i = 1, 36 do
  local c = CLASSES[(i % #CLASSES) + 1]
  local rankIndex = i == 1 and 0 or (i < 4 and 1 or (i % 3 == 0 and 2 or 4))
  SIM.roster[i] = { "Miembro Prueba " .. i, RANKS[rankIndex + 1], rankIndex, 10 + (i * 7) % 51, c[2], "Los Humedales", "", "", i <= 2, 0, c[1], i * 10, 1, false, false, 3, "Player-6842-SIM" .. i }
end
SIM.roster[2] = { "El Peregrino", "Miembro", 4, 24, "Paladín", "Los Humedales", "", "", true, 0, "PALADIN", -1, 36, false, false, 3, "Player-6842-0A1B2C3D" }
SIM.roster[3][4] = 60

IsInGuild = function() return SIM.inGuild end
SIM.guildName = "C A Ñ A D A"
GetGuildInfo = function()
  if not SIM.inGuild then return nil end
  for _, r in ipairs(SIM.roster) do if r[17] == SIM.me.guid then return SIM.guildName, r[2], r[3] end end
  return SIM.guildName, "Miembro", 4
end
GetNumGuildMembers = function() if not SIM.inGuild then return 0, 0 end local on = 0 for _, r in ipairs(SIM.roster) do if r[9] then on = on + 1 end end return #SIM.roster, on end
GetGuildRosterInfo = function(i) local r = SIM.roster[i] if r then return unpack(r) end end
SIM.lastOnline = {}
GetGuildRosterLastOnline = function(i) local d = SIM.lastOnline[i] or (i % 5) return 0, 0, d, 3 end
GuildControlGetNumRanks = function() return #RANKS end
GuildControlGetRankName = function(i) return RANKS[i] end
GetGuildRosterMOTD = function() return "Raid el viernes a las 21:00" end
SIM.faction = "Alliance"
UnitFactionGroup = function() return SIM.faction, SIM.faction == "Horde" and "Horda" or "Alianza" end
SIM.units = {} -- unit -> GUID of what the player targets, mouses over or sees (layers)
UnitGUID = function(unit) if unit == nil or unit == "player" then return SIM.me.guid end return SIM.units[unit] end
GetCurrentRegionName = function() return "EU" end
GetMaxLevelForPlayerExpansion = function() return 60 end

-- Groups, server time, calendar and chat (Entrega 2).
SIM.invites = {}
SIM.group = { inGroup = false, inRaid = false, leader = true }
C_PartyInfo = {
  InviteUnit = function(name) SIM.invites[#SIM.invites + 1] = name end,
  ConvertToRaid = function() SIM.group.inRaid = true end,
}
UnitInParty = function() return false end
UnitInRaid = function() return nil end
IsInGroup = function() return SIM.group.inGroup end
IsInRaid = function() return SIM.group.inRaid end
UnitIsGroupLeader = function() return SIM.group.leader end
SIM.unitLevels = {}
UnitLevel = function(unit) if unit and unit ~= "player" and SIM.unitLevels[unit] then return SIM.unitLevels[unit] end return SIM.myLevel or 24 end
GetServerTime = function() return 1794494786 + math.floor(SIM.now) end
time = function(t) if t then return os.time(t) end return 1794494786 + math.floor(SIM.now) end
-- The game's date() with no time is "now" on the same clock as time() (the simulated one): with the computer's own
-- date, the Calendar screen's «next two weeks» moved with the real day and a test event «tomorrow» fell in the past.
date = function(fmt, t) return os.date(fmt, t or time()) end
SIM.calendar = {}
C_Calendar = {
  OpenCalendar = function() SIM.calendarOpened = true end,
  GetNumDayEvents = function(offset, day) local list = SIM.calendar[offset .. ":" .. day] return list and #list or 0 end,
  GetDayEvent = function(offset, day, i) local list = SIM.calendar[offset .. ":" .. day] return list and list[i] end,
}
SIM.tells = {}
ChatFrame_SendTell = function(name) SIM.tells[#SIM.tells + 1] = name end

-- People and hooks (Entrega 3).
SIM.chat = {}
SendChatMessage = function(msg, chatType, lang, target) SIM.chat[#SIM.chat + 1] = { msg = msg, chatType = chatType, target = target } end
SIM.menus = {}
Menu = { ModifyMenu = function(tag, fn) SIM.menus[tag] = fn end }
SIM.tooltipCalls = {}
Enum = { TooltipDataType = { Unit = 2 } }
TooltipDataProcessor = { AddTooltipPostCall = function(kind, fn) SIM.tooltipCalls[kind] = fn end }
SIM.units = {}
UnitIsPlayer = function(unit) return SIM.units[unit] ~= nil end
local realUnitFullName = UnitFullName
UnitFullName = function(unit) if unit == nil or unit == "player" then return realUnitFullName() end local u = SIM.units[unit] if u then return u[1], u[2] end end
SIM.bindings = { TOGGLEGUILDTAB = "J" }
SIM.used = {}
GetBindingKey = function(action) return SIM.bindings[action] end
GetBindingAction = function(key) return SIM.used[key] or "" end
SIM.overrides = {}
SetOverrideBindingClick = function(owner, prio, key, button) SIM.overrides[key] = button end
InCombatLockdown = function() return false end

-- Chat (Entrega 4).
function Methods.AddMessage(self, text) self.__lines = self.__lines or {} self.__lines[#self.__lines + 1] = text end
function Methods.Clear(self) self.__lines = {} end
SIM.battletag = "Peregrino#2899"
BNGetInfo = function() return 1, SIM.battletag end

-- Board (Entrega 5): raid warnings and map pins.
SIM.warnings = {}
RaidWarningFrame = {}
ChatTypeInfo = { RAID_WARNING = { r = 1, g = 0.3, b = 0.1 } }
RaidNotice_AddMessage = function(frame, text) SIM.warnings[#SIM.warnings + 1] = text end
SIM.mapPos = { map = 1437, x = 0.4512, y = 0.6078 }
-- Maps (entrega 7): each zone is a square of the continent's world coordinates (made up, consistent).
SIM.maps = { [1414] = { type = 2, cont = 1414, ox = 0, oy = 0, size = 10000 }, [1437] = { type = 3, cont = 1414, ox = 2000, oy = 3000, size = 1000 }, [1436] = { type = 3, cont = 1414, ox = 2600, oy = 3400, size = 800 } }
SIM.inInstance = false
IsInInstance = function() return SIM.inInstance end
CreateVector2D = function(x, y) return { x = x, y = y, GetXY = function(self) return self.x, self.y end } end
C_Map = {
  GetBestMapForUnit = function() return SIM.mapPos.map end,
  GetPlayerMapPosition = function() return { GetXY = function() return SIM.mapPos.x, SIM.mapPos.y end } end,
  SetUserWaypoint = function(point) SIM.waypoint = point end,
  GetMapInfo = function(map) local m = SIM.maps[map] return m and { mapID = map, mapType = m.type } or nil end,
  GetWorldPosFromMapPos = function(map, pos)
    local m = SIM.maps[map]
    if not m or not m.cont then return nil end
    -- (as the game: the first number grows to the north, the second to the west; the map's x grows to the east, y south)
    return m.cont, CreateVector2D(-(m.oy + pos.y * m.size), -(m.ox + pos.x * m.size))
  end,
  GetMapPosFromWorldPos = function(cont, world, map)
    local m = SIM.maps[map]
    if not m or m.cont ~= cont then return nil end
    return map, CreateVector2D((-world.y - m.ox) / m.size, (-world.x - m.oy) / m.size)
  end,
}
WorldMapFrame = new("Frame")
WorldMapFrame.__shown = false
WorldMapFrame.canvas = new("Frame", WorldMapFrame)
WorldMapFrame.canvas:SetSize(1000, 667)
WorldMapFrame.mapID = 1437
function WorldMapFrame:GetCanvas() return self.canvas end
function WorldMapFrame:GetMapID() return self.mapID end
function WorldMapFrame:GetCanvasScale() return 1 end
C_PartyInfo.LeaveParty = function() SIM.left = (SIM.left or 0) + 1 SIM.group.inGroup = false end
UiMapPoint = { CreateFromCoordinates = function(map, x, y) return { map = map, x = x, y = y } end }
C_SuperTrack = { SetSuperTrackedUserWaypoint = function(on) SIM.supertrack = on end }

-- Alliance (Entrega 6): the server's answer to a whisper to someone not playing, and chat filters.
ERR_CHAT_PLAYER_NOT_FOUND_S = "No player named '%s' is currently playing."
SIM.filters = {}
ChatFrame_AddMessageEventFilter = function(event, fn)
  SIM.filters[event] = SIM.filters[event] or {}
  table.insert(SIM.filters[event], fn)
end
SIM.systemShown = {}
function SIM.system(text)
  local hidden = false
  for _, fn in ipairs(SIM.filters.CHAT_MSG_SYSTEM or {}) do
    if fn(nil, "CHAT_MSG_SYSTEM", text) then hidden = true end
  end
  if not hidden then SIM.systemShown[#SIM.systemShown + 1] = text end
  SIM.fire("CHAT_MSG_SYSTEM", text)
end

-- Professions and items (entrega 8): the classic trade skill window, item names, the game's whisper box.
SIM.items = { [7946] = "Hoja de acero de Runas", [3853] = "Martillo de bronce", [2862] = "Piedra de afilar tosca", [19137] = "Cinturón de asesino nocturno" }
SIM.trade = nil -- { name, rank, max, recipes = { { name, kind, itemID } } } while a profession window is open
SIM.tells = {}
GetTradeSkillLine = function() if SIM.trade then return SIM.trade.name, SIM.trade.rank, SIM.trade.max end return "UNKNOWN" end
GetNumTradeSkills = function() return SIM.trade and #SIM.trade.recipes or 0 end
GetTradeSkillInfo = function(i) local r = SIM.trade and SIM.trade.recipes[i] if r then return r[1], r[2] end end
GetTradeSkillItemLink = function(i) local r = SIM.trade and SIM.trade.recipes[i] if r and r[3] then return "|cff1eff00|Hitem:" .. r[3] .. "::::::::|h[" .. r[1] .. "]|h|r" end end
ChatFrame_SendTell = function(name) SIM.tells[#SIM.tells + 1] = name end

-- Treasury (entrega 9): a trade window, the mailbox, sending mail and the guild bank.
SIM.trade2 = { npc = nil, got = 0, gave = 0 }
UnitName = UnitName or function() return nil end
local unitNameBase = UnitName
local function npcParts() local n = SIM.trade2.npc if not n then return nil end return n:match("^(%S+)"), n:match("^%S+%s+(.+)$") end
-- (as the game does on Forever: UnitName gives the first name only, and the surname where the realm goes)
UnitName = function(unit) if unit == "NPC" then return npcParts() end return unitNameBase(unit) end
local fullNameBase = UnitFullName
UnitFullName = function(unit) if unit == "NPC" then return npcParts() end return fullNameBase(unit) end
GetTargetTradeMoney = function() return SIM.trade2.got end
GetPlayerTradeMoney = function() return SIM.trade2.gave end
ERR_TRADE_COMPLETE = "Comercio completado."
SIM.inbox = {} -- { sender, subject, money, canReply }
GetInboxHeaderInfo = function(i) local m = SIM.inbox[i] if m then return nil, nil, m.sender, m.subject, m.money, 0, 30, false, true, false, false, m.canReply ~= false end end
GetInboxNumItems = function() return #SIM.inbox end
TakeInboxMoney = function(i) if SIM.inbox[i] then SIM.inbox[i].money = 0 end end -- (as soon as it is taken: the hardest case)
AutoLootMailItem = function(i) TakeInboxMoney(i) end
SIM.sendMoney = 0
GetSendMailMoney = function() return SIM.sendMoney end
SendMail = function() end
hooksecurefunc = hooksecurefunc or function(a, b, c)
  local tbl, name, fn = _G, a, b
  if type(a) == "table" then tbl, name, fn = a, b, c end
  local orig = tbl[name]
  tbl[name] = function(...) local r = { orig(...) } fn(...) return unpack(r) end
end
SIM.gbank = nil -- { gold, tabs = { { name, slots = { [slot] = { id, count } } } } }
GetNumGuildBankTabs = function() return SIM.gbank and #SIM.gbank.tabs or 0 end
GetGuildBankTabInfo = function(t) local tab = SIM.gbank and SIM.gbank.tabs[t] if tab then return tab.name, nil, true end end
GetGuildBankItemLink = function(t, s) local x = SIM.gbank and SIM.gbank.tabs[t] and SIM.gbank.tabs[t].slots[s] if x then return "|Hitem:" .. x[1] .. "|h[x]|h" end end
GetGuildBankItemInfo = function(t, s) local x = SIM.gbank and SIM.gbank.tabs[t] and SIM.gbank.tabs[t].slots[s] if x then return nil, x[2] end end
GetGuildBankMoney = function() return SIM.gbank and SIM.gbank.gold or 0 end
QueryGuildBankTab = function() end

-- Recruitment (entrega 10): the game's /who (results set by the test, delivered on the next timer step).
SIM.who = {} -- { { fullName, fullGuildName, level, filename } }
SIM.whoSent = {}
C_FriendList = {
  SetWhoToUi = function() end,
  SendWho = function(q) SIM.whoSent[#SIM.whoSent + 1] = q C_Timer.After(0.5, function() SIM.fire("WHO_LIST_UPDATE") end) end,
  GetNumWhoResults = function() return #SIM.who, #SIM.who end,
  GetWhoInfo = function(i) return SIM.who[i] end,
}
UnitClass = UnitClass or function() return "Paladín", "PALADIN" end

-- «Se busca», honours and marks (entrega 11). Players of other factions by GUID (race as the game names it), the
-- game's death recap (set by the test), PARTY_KILL fired by the test, nameplates and the target's portrait.
SIM.players = {} -- guid -> { name, surname, class, race }
GetPlayerInfoByGUID = function(guid)
  local p = SIM.players[guid]
  if not p then return nil end
  return p.class, p.class, p.race, p.race, 2, p.name, p.surname or ""
end
SIM.recap = nil -- list of death recap rows, newest first
C_DeathRecap = {
  HasRecapEvents = function() return SIM.recap ~= nil and #SIM.recap > 0 end,
  GetRecapEvents = function() return SIM.recap end,
}
UnitIsDeadOrGhost = function() return SIM.dead == true end
SIM.zone = "Vega de Tuercespina"
GetRealZoneText = function() return SIM.zone end
SIM.plates = {}
C_NamePlate = { GetNamePlateForUnit = function(unit)
  if not SIM.plates[unit] then
    local f = CreateFrame("Frame", nil, UIParent)
    f:SetSize(120, 30)
    SIM.plates[unit] = f
  end
  return SIM.plates[unit]
end }
UnitExists = UnitExists or function(unit) return SIM.units[unit] ~= nil end
TargetFrame = CreateFrame("Frame", nil, UIParent)
TargetFrame.portrait = TargetFrame:CreateTexture(nil, "ARTWORK")
TargetFrame.portrait:SetSize(64, 64)

SIM.unitGuids = {} -- unit -> GUID for units the test shows (target, nameplates)
local stubUnitGUID = UnitGUID
UnitGUID = function(unit) if unit and SIM.unitGuids[unit] then return SIM.unitGuids[unit] end return stubUnitGUID(unit) end

-- Raid groups (0.16.0): the raid as the game keeps it ({ first, second, group } in raid order), its moves (the
-- game answers each with GROUP_ROSTER_UPDATE a moment later), the mouse over a frame and what is visible.
SIM.raid = {}
SIM.raidMoves = 0
function SIM.setRaid(list)
  SIM.raid = list
  for i = 1, 40 do SIM.units["raid" .. i] = nil end
  for i, r in ipairs(list) do SIM.units["raid" .. i] = { r[1], r[2] } end
end
GetNumGroupMembers = function() return #SIM.raid end
-- (as on Forever: the roster gives the first name alone; whoever needs the whole name reads the unit, Names.Unit)
GetRaidRosterInfo = function(i) local r = SIM.raid[i] if not r then return nil end return r[1], 0, r[3] end
local function raidCount(g) local n = 0 for _, r in ipairs(SIM.raid) do if r[3] == g then n = n + 1 end end return n end
SetRaidSubgroup = function(i, g)
  if not SIM.raid[i] or raidCount(g) >= 5 then return end
  SIM.raid[i][3] = g
  SIM.raidMoves = SIM.raidMoves + 1
  C_Timer.After(0.2, function() SIM.fire("GROUP_ROSTER_UPDATE") end)
end
SwapRaidSubgroup = function(i, j)
  if not (SIM.raid[i] and SIM.raid[j]) then return end
  SIM.raid[i][3], SIM.raid[j][3] = SIM.raid[j][3], SIM.raid[i][3]
  SIM.raidMoves = SIM.raidMoves + 1
  C_Timer.After(0.2, function() SIM.fire("GROUP_ROSTER_UPDATE") end)
end
UnitIsGroupAssistant = function() return SIM.group.assistant == true end
SIM.mouseOver = nil
function Methods.IsMouseOver(self) return SIM.mouseOver == self end
function Methods.IsVisible(self) return visible(self) end

-- Tournaments (0.17.0): the game's /roll. Its line comes a moment later, to whoever is near; the value is the next
-- of SIM.rolls (or the lowest).
SIM.rolls = {}
SIM.rollsAsked = {}
RandomRoll = function(lo, hi)
  SIM.rollsAsked[#SIM.rollsAsked + 1] = lo .. "-" .. hi
  local v = table.remove(SIM.rolls, 1) or lo
  if v > hi then v = hi end
  -- (the name as the game's own lines can give it on Forever: "First-Surname"; Olympus normalises it, MIT)
  C_Timer.After(0.3, function() SIM.fire("CHAT_MSG_SYSTEM", SIM.me.first .. "-" .. SIM.me.second .. " rolls " .. v .. " (" .. lo .. "-" .. hi .. ")") end)
end

-- The tavern (0.18.0): an NPC's dialog options (the innkeeper's "binder" icon is 132052).
SIM.gossip = {}
C_GossipInfo = C_GossipInfo or {}
C_GossipInfo.GetOptions = function() return SIM.gossip end
SIM.npcName = "Posadera Allison"
local stubUnitName = UnitName
UnitName = function(unit) if unit == "npc" then return SIM.npcName end if stubUnitName then return stubUnitName(unit) end end

-- The Armería (0.20.0): what each one wears, the game's inspection and item levels; the JcE: the raid we are in.
SIM.gear = {} -- "First Second" (or "player") -> { [slot] = itemID or { itemID, enchant } }
SIM.ilvl = {} -- itemID -> item level
local function itemLink(x)
  local id = type(x) == "table" and x[1] or x
  local ench = type(x) == "table" and x[2] or ""
  return "|cff0070dd|Hitem:" .. id .. ":" .. ench .. "::::::::|h[" .. (SIM.items[id] or ("Objeto " .. id)) .. "]|h|r"
end
local function wearer(unit)
  if unit == "player" then return "player" end
  local u = SIM.units[unit]
  return u and (u[1] .. " " .. u[2]) or nil
end
GetInventoryItemLink = function(unit, slot)
  local g = SIM.gear[wearer(unit) or ""]
  local x = g and g[slot]
  return x and itemLink(x) or nil
end
-- Items as on Forever (0.29.2): the game's item functions live in C_Item and there is NO global GetItemInfo (the probe
-- of 2026-11-12; the Armería called the global and showed «Objeto 6189» with a question mark). The client knows an
-- item only once the server told it: an id in SIM.uncached has no name yet; RequestLoadItemDataByID brings it a moment
-- later and the game says so (GET_ITEM_INFO_RECEIVED). The icon comes from the client's own files: always there.
SIM.uncached = {}
local function itemId(x) return tonumber(x) or tonumber(tostring(x):match("item:(%d+)")) end
C_Item = {
  GetItemInfo = function(x)
    local n = itemId(x)
    local name = n and not SIM.uncached[n] and SIM.items[n]
    if not name then return nil end
    return name, itemLink(n), 3, SIM.ilvl[n] or 60, 60, "Armadura", "Placas", 1, "INVTYPE_CHEST", 135000 + n % 100
  end,
  GetItemNameByID = function(id) local n = itemId(id) return n and not SIM.uncached[n] and SIM.items[n] or nil end,
  GetItemIconByID = function(id) local n = itemId(id) return n and (135000 + n % 100) or nil end,
  IsItemDataCachedByID = function(id) return not SIM.uncached[itemId(id)] end,
  RequestLoadItemDataByID = function(id)
    local n = itemId(id)
    SIM.itemAsks = (SIM.itemAsks or 0) + 1
    if n and SIM.uncached[n] then
      C_Timer.After(0.3, function() SIM.uncached[n] = nil SIM.fire("GET_ITEM_INFO_RECEIVED", n, SIM.items[n] ~= nil) end)
    end
  end,
  GetDetailedItemLevelInfo = function(link) local n = itemId(link) return n and SIM.ilvl[n] or nil end,
}
GetItemInfo, GetDetailedItemLevelInfo = nil, nil
GetInventoryItemID = function(unit, slot)
  local g = SIM.gear[wearer(unit) or ""]
  local x = g and g[slot]
  return x and (type(x) == "table" and x[1] or x) or nil
end

-- The game's tooltip: what it shows, and its comparison windows («Equipado», what you wear beside the item): the game
-- opens them by itself when Shift is held or the player chose to always compare (SIM.compare), and closes them with it.
GameTooltip = new("GameTooltip")
ShoppingTooltip1, ShoppingTooltip2 = new("GameTooltip"), new("GameTooltip")
ShoppingTooltip1:Hide() ShoppingTooltip2:Hide()
GameTooltip.shoppingTooltips = { ShoppingTooltip1, ShoppingTooltip2 }
SIM.compare = false
local function gameCompares() if SIM.compare then ShoppingTooltip1:Show() end end
function GameTooltip:SetOwner(owner) self.__owner, self.__item = owner, nil ShoppingTooltip1:Hide() end
function GameTooltip:GetOwner() return self.__owner end
function GameTooltip:SetHyperlink(link) self.__item = link gameCompares() end
function GameTooltip:SetInventoryItem(unit, slot) self.__item = "inventory:" .. unit .. ":" .. slot gameCompares() end
function GameTooltip:NumLines() return 0 end
GameTooltip:SetScript("OnHide", function() ShoppingTooltip1:Hide() ShoppingTooltip2:Hide() end)
local unitNameArmory = UnitName
UnitName = function(unit)
  local u = SIM.units[unit]
  if type(u) == "table" then return u[1], u[2] end -- (as on Forever: the first name, and the surname where the realm goes)
  return unitNameArmory(unit)
end
SIM.inspected = 0
CanInspect = function(unit) return type(SIM.units[unit]) == "table" end
NotifyInspect = function(unit)
  SIM.inspected = SIM.inspected + 1
  local guid = UnitGUID(unit)
  C_Timer.After(0.5, function() SIM.fire("INSPECT_READY", guid) end)
end
ClearInspectPlayer = function() end
SIM.instance = nil -- { name, kind, mapId }
GetInstanceInfo = function()
  local i = SIM.instance
  if not i then return "Ventormenta", "none" end
  return i.name, i.kind, 9, (i.size or 40) .. " jugadores", i.size or 40, 0, false, i.mapId
end

-- The guild ranking (0.20.0): the game names the guild of a player in our group (GetGuildInfo of their unit).
SIM.guildOf = {} -- "First Second" -> their guild's name
local guildInfoPlayer = GetGuildInfo
GetGuildInfo = function(unit)
  if unit and unit ~= "player" then
    local u = SIM.units[unit]
    local g = type(u) == "table" and SIM.guildOf[u[1] .. " " .. u[2]] or nil
    if g then return g, "Miembro", 4 end
    return nil
  end
  return guildInfoPlayer(unit)
end

-- The minimap (0.21.0): its view radius in yards, whether it turns with the player, and where the player faces.
SIM.minimapRadius = 200
C_Minimap = { GetViewRadius = function() return SIM.minimapRadius end }
SIM.facing = 0
GetPlayerFacing = function() return SIM.facing end
SIM.cvars = {}
GetCVar = function(k) return SIM.cvars[k] end
IsIndoors = function() return false end

-- Chat channels (0.22.0): joining one (a number for each), its number by name, leaving, and a player's line in it
-- (it goes to the harness, which gives it to everyone in that channel).
SIM.joined = {} -- name -> { i = number, pw = password }
SIM.channelNames = {}
JoinTemporaryChannel = function(name, pw)
  if SIM.joined[name] then return end
  local i = 1
  while SIM.channelNames[i] do i = i + 1 end
  SIM.channelNames[i] = name
  SIM.joined[name] = { i = i, pw = pw }
end
GetChannelName = function(name)
  local j = SIM.joined[name]
  if j then return j.i, name end
  return 0, nil
end
LeaveChannelByName = function(name)
  local j = SIM.joined[name]
  if j then SIM.channelNames[j.i] = nil SIM.joined[name] = nil end
end
SIM.removedChannels = {}
ChatFrame_RemoveChannel = function(cf, name) SIM.removedChannels[name] = true end
NUM_CHAT_WINDOWS = 1
ChatFrame1 = CreateFrame("Frame", nil, UIParent)
local sendChatBefore = SendChatMessage
SendChatMessage = function(msg, chatType, lang, target)
  if chatType == "CHANNEL" then
    local name = SIM.channelNames[tonumber(target) or 0]
    if not name then error("canal " .. tostring(target) .. " inexistente") end
    if #msg > 255 then error("línea de " .. #msg .. " bytes") end
    SIM.channelSent = (SIM.channelSent or 0) + 1
    if __send then __send("", msg, "CHANNEL", name) end
    return
  end
  return sendChatBefore(msg, chatType, lang, target)
end

-- The gamepad interface (0.24.0): the game's current input style (0 mouse and keyboard, 1 gamepad), and override keys.
Enum.InputDeviceInterfaceType = { KeyboardAndMouse = 0, Gamepad = 1 }
SIM.inputStyle = 0
C_InputInterfaceStyle = { GetCurrentStyle = function() return SIM.inputStyle end }
ClearOverrideBindings = function(owner) SIM.overrides = {} end
GetBuildInfo = function() return "1.60.1", "70862", "Nov 2026", 16001 end

-- Item links into text boxes (0.25.0): the focus of a box, inserting text, Shift + click (the game's paths) and an item
-- held on the cursor (dragging).
SIM.focus = nil
function Methods.SetFocus(self)
  local old = SIM.focus
  if old == self then return end
  SIM.focus = self
  if old and old.__scripts.OnEditFocusLost then old.__scripts.OnEditFocusLost(old) end
  if self.__scripts.OnEditFocusGained then self.__scripts.OnEditFocusGained(self) end
end
function Methods.ClearFocus(self)
  if SIM.focus == self then
    SIM.focus = nil
    if self.__scripts.OnEditFocusLost then self.__scripts.OnEditFocusLost(self) end
  end
end
function Methods.HasFocus(self) return SIM.focus == self end
function Methods.Insert(self, t)
  self.__text = (self.__text or "") .. t
  if self.__scripts.OnTextChanged then self.__scripts.OnTextChanged(self, true) end
end
SIM.shift = false
IsModifiedClick = function(what) return what == "CHATLINK" and SIM.shift end
ChatEdit_InsertLink = function(link) return false end
ChatFrameUtil = { InsertLink = function(link) return ChatEdit_InsertLink(link) end }
HandleModifiedItemClick = function(link) if IsModifiedClick("CHATLINK") then return ChatFrameUtil.InsertLink(link) end end
SIM.cursorItem = nil -- { id, link }
GetCursorInfo = function() if SIM.cursorItem then return "item", SIM.cursorItem.id, SIM.cursorItem.link end end
ClearCursor = function() SIM.cursorItem = nil end
