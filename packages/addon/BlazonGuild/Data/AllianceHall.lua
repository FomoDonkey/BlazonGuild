-- The alliance's chat through a channel of the game (the rest of entrega 6; the idea of Olympus' ChatHall.lua, MIT;
-- our own implementation). On WoW: Forever an addon's own messages on a chat channel never arrive, but a line a
-- player sends to a channel reaches everyone in it, across sub-realms (Olympus measured it on the live realms). So
-- each client of the alliance joins a hidden channel whose name and password come from the alliance's key, and a
-- line of «Toda la alianza» or of a shared room also leaves as the player's own text there, written so that only
-- BlazonGuild reads it (with the alliance's mark, which nobody outside can make). It is sent only when the player
-- presses Enter or «Enviar» (the game allows it only then). The usual way (our guild, and the messengers to the
-- other guilds) goes on as before: each line is taken once, whichever way arrives first. The channel never shows in
-- the chat windows.
local _, BG = ...
local Hall = { stats = { sent = 0, heard = 0 } }
BG.AllianceHall = Hall
local Alliance, Names = BG.Alliance, BG.Names

local JOIN_AFTER = 30 -- seconds after logging in (the game's own channels first, so their numbers stay)
local CHECK_EVERY = 60

local joined -- the channel's name while we are in it
local ready = false

local function names()
  local d = Alliance.Doc()
  if not d or type(d.key) ~= "string" then
    return nil
  end
  return "BG" .. Alliance.Hash("canal\031" .. d.key):sub(1, 10), Alliance.Hash("clave\031" .. d.key):sub(1, 12)
end

function Hall.Name()
  return joined
end

local function index()
  if not joined or not GetChannelName then
    return 0
  end
  local id = GetChannelName(joined)
  return tonumber(id) or 0
end

function Hall.On()
  return joined ~= nil and index() > 0 and SendChatMessage ~= nil and BG.Gamepad.Allowed("channel")
end

local function hide(name)
  for i = 1, (NUM_CHAT_WINDOWS or 10) do
    local cf = _G["ChatFrame" .. i]
    if cf and ChatFrame_RemoveChannel then
      pcall(ChatFrame_RemoveChannel, cf, name)
    end
  end
end

local function leave()
  if joined and LeaveChannelByName then
    pcall(LeaveChannelByName, joined)
  end
  joined = nil
end

-- In the alliance's channel when there is an alliance (and out of it otherwise, or of an old one).
function Hall.Sync()
  if not ready or BG.demo then
    return
  end
  local name, pass = names()
  if not name or not BG.Consent.Accepted() or not BG.Gamepad.Allowed("channel") then
    leave()
    return
  end
  if joined == name and index() > 0 then
    return
  end
  if joined and joined ~= name then
    leave()
  end
  local join = JoinTemporaryChannel or JoinChannelByName
  if not join then
    return
  end
  local ok = pcall(join, name, pass)
  if ok then
    joined = name
    hide(name)
  end
end

-- A line of ours (Alliance.Send builds the body) as our own text in the channel. True if the game took it.
function Hall.Send(b)
  if BG.demo or not Hall.On() or type(b) ~= "table" or (b.r ~= "ally" and not Alliance.IsSharedRoom(b.r)) then
    return false
  end
  local line = table.concat({ "BG1", b.r, b.i, Alliance.Code(b.g), b.c or "", b.h or "", b.t }, "~")
  if #line > 255 or line:find("\n", 1, true) then
    return false
  end
  local ok = pcall(SendChatMessage, line, "CHANNEL", nil, index())
  if ok then
    Hall.stats.sent = Hall.stats.sent + 1
  end
  return ok
end

local function ours(baseName, channelName)
  if not joined then
    return false
  end
  if type(baseName) == "string" and baseName ~= "" then
    return baseName:lower() == joined:lower()
  end
  return type(channelName) == "string" and channelName:gsub("^%d+%.%s*", ""):lower() == joined:lower()
end

-- A line heard in the channel: taken as a line of the alliance's chat if it is one (Alliance.TakeLine checks the
-- mark, the author and the rest).
function Hall.OnChannel(text, sender, _, channelName, _, _, _, _, baseName)
  if issecretvalue and (issecretvalue(text) or issecretvalue(sender)) then
    return false
  end
  if not ours(baseName, channelName) or type(text) ~= "string" or #text > 255 or type(sender) ~= "string" then
    return false
  end
  local r, i, code, c, h, t = text:match("^BG1~([^~]+)~([^~]+)~([^~]+)~([^~]*)~([^~]*)~(.*)$")
  if not r then
    return false
  end
  local mk = BG.Guild.info and BG.Guild.info.key
  local g = (mk and Alliance.Code(mk) == code) and mk or Alliance.KeyOfCode(code)
  if not g then
    return false
  end
  Hall.stats.heard = Hall.stats.heard + 1
  local from = Names.Short(sender)
  Alliance.TakeLine(sender, { r = r, i = i, t = t, f = from, g = g, c = c ~= "" and c or nil, h = h }, "CHANNEL")
  return true
end

BG:On("CHAT_MSG_CHANNEL", function(...)
  local ok, err = pcall(Hall.OnChannel, ...)
  if not ok then
    BG:RecordError("alliance channel", err)
  end
end)

-- Nothing of the channel shows in the chat windows: its lines, and the game's notices about it.
if ChatFrame_AddMessageEventFilter then
  local function filter(_, _, ...)
    local channelName = select(4, ...)
    local baseName = select(9, ...)
    return ours(baseName, channelName)
  end
  for _, event in ipairs({ "CHAT_MSG_CHANNEL", "CHAT_MSG_CHANNEL_NOTICE", "CHAT_MSG_CHANNEL_NOTICE_USER", "CHAT_MSG_CHANNEL_JOIN", "CHAT_MSG_CHANNEL_LEAVE" }) do
    ChatFrame_AddMessageEventFilter(event, filter)
  end
end

local function tick()
  local ok, err = pcall(Hall.Sync)
  if not ok then
    BG:RecordError("alliance channel", err)
  end
  C_Timer.After(CHECK_EVERY, tick)
end

BG:On("PLAYER_LOGIN", function()
  if not ready then
    C_Timer.After(JOIN_AFTER, function()
      ready = true
      tick()
    end)
  end
end)
BG:On("BG_ALLIANCE_CHANGED", function()
  pcall(Hall.Sync)
end)
BG:On("BG_CONSENT_CHANGED", function()
  pcall(Hall.Sync)
end)
BG:On("BG_GAMEPAD_CHANGED", function()
  pcall(Hall.Sync)
end)
