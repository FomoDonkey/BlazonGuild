-- BlazonGuild inside the game's own interface, adding and never replacing:
--   * a line in the right-click menu of a guildmate ("Ver su ficha en BlazonGuild")
--   * a line in a guildmate's tooltip (alt of whom, uses BlazonGuild, looking for a group)
--   * a button in the Guild & Communities window that opens BlazonGuild
--   * Shift + the guild key (J unless the player moved it) opens BlazonGuild, only when that key is free
-- Rules learned from Olympus (PlayerMenu.lua, GuildFrame.lua, MainKey.lua; MIT): menus only through
-- Menu.ModifyMenu and never the game's guild roster menus (their promote/remove actions break with an
-- addon's line in them); nothing with the gamepad interface on (its navigation picks up our buttons);
-- nothing read from a value the game hides from addons (secret values).
local _, BG = ...
local Hooks = {}
BG.Hooks = Hooks
local Names = BG.Names

local function secret(...)
  if type(issecretvalue) ~= "function" then
    return false
  end
  for i = 1, select("#", ...) do
    if issecretvalue((select(i, ...))) then
      return true
    end
  end
  return false
end

function Hooks.Gamepad()
  return BG.Gamepad.On() -- (Core/Gamepad.lua: with the gamepad interface on, nothing of ours in the game's frames)
end

-- Right-click menus ------------------------------------------------------------------------------
Hooks.MENUS = { "SELF", "PLAYER", "PARTY", "RAID_PLAYER", "RAID", "FRIEND", "COMMUNITIES_WOW_MEMBER", "CHAT_ROSTER", "RECENT_ALLY" }

-- The guildmate a menu is for, or nil. Pure given the game's unit functions; tested offline.
function Hooks.MenuTarget(ctx)
  if type(ctx) ~= "table" or secret(ctx.name, ctx.surname, ctx.server, ctx.unit, ctx.isOffline, ctx.bnetIDAccount) then
    return nil
  end
  if ctx.bnetIDAccount then
    return nil
  end
  local name
  if type(ctx.unit) == "string" and ctx.unit ~= "" then
    if UnitIsPlayer and not UnitIsPlayer(ctx.unit) then
      return nil
    end
    name = Names.Unit(ctx.unit)
  elseif type(ctx.name) == "string" and ctx.name ~= "" then
    name = ctx.name
    if type(ctx.surname) == "string" and ctx.surname ~= "" and not name:find(" ", 1, true) then
      name = name .. " " .. ctx.surname -- Forever hands the surname apart
    end
  end
  local m = name and BG.Guild.Find(name)
  return m and Names.Short(m.name) or nil
end

local function buildMenu(_, root, ctx)
  if Hooks.Gamepad() or not BG.db then
    return
  end
  local ok, name = pcall(Hooks.MenuTarget, ctx)
  if not ok or not name then
    return
  end
  root:CreateDivider()
  root:CreateTitle("BlazonGuild")
  root:CreateButton(Names.IsMe(name) and "Mi ficha" or "Ver su ficha", function()
    BG.UI.ShowProfile(name)
  end)
end

function Hooks.HookMenus()
  if not (Menu and type(Menu.ModifyMenu) == "function") or Hooks.Gamepad() then
    return false
  end
  for _, which in ipairs(Hooks.MENUS) do
    pcall(Menu.ModifyMenu, "MENU_UNIT_" .. which, function(owner, root, ctx)
      local ok, err = pcall(buildMenu, owner, root, ctx)
      if not ok then
        BG:RecordError("menú del botón derecho", err)
      end
    end)
  end
  Hooks.menusHooked = true
  return true
end

-- Tooltips ---------------------------------------------------------------------------------------
-- Pure given the stores: the BlazonGuild line for a guildmate, or nil.
function Hooks.TooltipLine(name)
  local m = BG.Guild.Find(name)
  if not m then
    return nil
  end
  local short = Names.Short(m.name)
  local parts = {}
  local main = BG.People.Main(short)
  if main and main ~= short then
    parts[#parts + 1] = "alter de " .. main
  end
  local flag = BG.Store.Get("flags", short)
  if flag and not flag.del and (flag.exp or 0) > BG.Store.Now() then
    local inst = BG.Instances.Any(flag.d.key)
    parts[#parts + 1] = "busca grupo" .. (inst and (" para " .. inst.name) or "")
  end
  if BG.Peers.Get(short) then
    parts[#parts + 1] = "usa el addon"
  end
  if #parts == 0 then
    return nil
  end
  return "BlazonGuild: " .. table.concat(parts, ", ")
end

local function onUnitTooltip(tooltip)
  if tooltip ~= GameTooltip or not BG.db or not tooltip.GetUnit then
    return
  end
  local ok, _, unit = pcall(tooltip.GetUnit, tooltip)
  if not ok or not unit or secret(unit) or (UnitIsPlayer and not UnitIsPlayer(unit)) then
    return
  end
  local name = Names.Unit(unit)
  local line = name and Hooks.TooltipLine(name)
  if line then
    local c = BG.color.gold
    tooltip:AddLine(line, c[1], c[2], c[3])
  end
end

function Hooks.HookTooltips()
  if TooltipDataProcessor and TooltipDataProcessor.AddTooltipPostCall and Enum and Enum.TooltipDataType then
    TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Unit, function(tooltip)
      local ok, err = pcall(onUnitTooltip, tooltip)
      if not ok then
        BG:RecordError("recuadro de jugador", err)
      end
    end)
  elseif GameTooltip and GameTooltip.HookScript then
    GameTooltip:HookScript("OnTooltipSetUnit", function(tooltip)
      pcall(onUnitTooltip, tooltip)
    end)
  end
end

-- Button in the Guild & Communities window ---------------------------------------------------------
local guildButton
function Hooks.AddGuildButton()
  local frame = _G.CommunitiesFrame
  if guildButton or not frame or Hooks.Gamepad() then
    return
  end
  guildButton = BG.UI.Button(frame, "BlazonGuild", { height = 22, width = 104, size = 11, primary = true })
  local anchor = frame.MaximizeMinimizeFrame or frame.CloseButton
  if anchor then
    guildButton:SetPoint("RIGHT", anchor, "LEFT", -2, 0)
    guildButton:SetFrameLevel(math.max(frame:GetFrameLevel() + 10, anchor:GetFrameLevel()))
  else
    guildButton:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -54, -2)
  end
  guildButton:SetScript("OnClick", function()
    BG:ToggleWindow()
  end)
end

BG:On("ADDON_LOADED", function(name)
  if name == "Blizzard_Communities" then
    Hooks.AddGuildButton()
  end
end)

-- Shift + guild key --------------------------------------------------------------------------------
local keyButton
function Hooks.MainKey()
  if InCombatLockdown and InCombatLockdown() then
    return false
  end
  if not BG.Gamepad.Allowed("mainkey") then
    return false
  end
  local key = GetBindingKey and GetBindingKey("TOGGLEGUILDTAB")
  local want = (type(key) == "string" and not key:find("-", 1, true)) and ("SHIFT-" .. key) or "SHIFT-J"
  if GetBindingAction and GetBindingAction(want, true) ~= "" then
    return false -- the player (or another addon) already uses that key
  end
  keyButton = keyButton or CreateFrame("Button", "BlazonGuildMainKey", UIParent)
  keyButton:SetScript("OnClick", function()
    BG:ToggleWindow()
  end)
  SetOverrideBindingClick(keyButton, false, want, "BlazonGuildMainKey", "LeftButton")
  Hooks.mainKey = want
  return true
end

-- A switch to the gamepad: the key goes back to the game; back to mouse and keyboard, it is ours again.
BG:On("BG_GAMEPAD_CHANGED", function(on)
  if on then
    if keyButton and Hooks.mainKey and ClearOverrideBindings and not (InCombatLockdown and InCombatLockdown()) then
      ClearOverrideBindings(keyButton)
      Hooks.mainKey = nil
    end
    if guildButton then
      guildButton:Hide()
    end
  else
    if not Hooks.mainKey then
      Hooks.MainKey()
    end
    if guildButton then
      guildButton:Show()
    else
      Hooks.AddGuildButton()
    end
    Hooks.HookMenus()
    Hooks.HookTooltips()
  end
end)

BG:On("PLAYER_LOGIN", function()
  Hooks.HookMenus()
  Hooks.HookTooltips()
  Hooks.AddGuildButton()
  if not Hooks.MainKey() then
    BG:On("PLAYER_REGEN_ENABLED", function()
      if not Hooks.mainKey then
        Hooks.MainKey()
      end
    end)
  end
end)
