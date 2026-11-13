-- BlazonGuild client probe (development only).
-- Records what the WoW: Forever client allows so the real addon is designed on evidence, not assumptions.
-- Read-only: it never changes guild, calendar, group or game settings. Everything is stored in
-- BlazonGuildProbeDB, which the game writes to SavedVariables on /reload or logout.

local ADDON_NAME = ...
local PREFIX = "BGPROBE"
local MEDIA = "Interface\\AddOns\\" .. ADDON_NAME .. "\\"

local report = { checks = {}, templates = {}, files = {}, errors = {}, comms = {}, timings = {} }
local ui -- status window

local function now()
  return GetTimePreciseSec and GetTimePreciseSec() or GetTime()
end

local function safe(step, fn, ...)
  local ok, err = pcall(fn, ...)
  if not ok then
    report.errors[#report.errors + 1] = step .. ": " .. tostring(err)
  end
  return ok
end

local function resolve(path)
  local t = _G
  for part in string.gmatch(path, "[^%.]+") do
    if type(t) ~= "table" then
      return nil
    end
    t = t[part]
  end
  return t
end

-- API surface the real addon may rely on, grouped by feature.
local API = {
  -- core
  "GetBuildInfo", "C_AddOns.GetAddOnMetadata", "GetAddOnMetadata", "C_AddOns.IsAddOnLoaded", "C_Timer.After",
  "C_Timer.NewTicker", "GetServerTime", "C_DateAndTime.GetCurrentCalendarTime", "C_DateAndTime.GetServerTimeLocal",
  "GetCurrentRegion", "GetCurrentRegionName", "GetRealmName", "GetNormalizedRealmName", "C_GameRules",
  "C_Seasons.GetActiveSeason", "C_EncodingUtil.SerializeCBOR", "C_EncodingUtil.CompressString", "C_EncodingUtil.EncodeBase64",
  "C_RestrictedActions", "C_Secrets", "issecretvalue", "canaccessvalue",
  -- guild
  "IsInGuild", "GetGuildInfo", "C_GuildInfo.GuildRoster", "GuildRoster", "GetNumGuildMembers", "GetGuildRosterInfo",
  "IsGuildLeader", "CanGuildInvite", "CanGuildPromote", "CanGuildDemote", "CanGuildRemove", "CanEditOfficerNote",
  "C_GuildInfo.CanEditOfficerNote", "CanEditPublicNote", "C_GuildInfo.CanViewOfficerNote", "CanViewOfficerNote",
  "CanEditMOTD", "CanEditGuildInfo", "GuildControlGetNumRanks", "GuildControlGetRankName",
  "C_GuildInfo.GuildControlGetRankFlags", "GuildControlGetRankFlags", "C_GuildInfo.Invite", "GuildInvite",
  "C_GuildInfo.Promote", "GuildPromote", "C_GuildInfo.Demote", "GuildDemote", "C_GuildInfo.Uninvite", "GuildUninvite",
  "GuildRosterSetPublicNote", "GuildRosterSetOfficerNote", "C_GuildInfo.SetNote", "GetGuildRosterMOTD",
  "C_GuildInfo.GetGuildNewsInfo", "C_Club.GetGuildClubId", "C_Club.GetClubMembers", "C_Club.GetMemberInfo",
  -- addon messages (in-game sync between guild members)
  "C_ChatInfo.RegisterAddonMessagePrefix", "C_ChatInfo.SendAddonMessage", "C_ChatInfo.SendAddonMessageLogged",
  "C_ChatInfo.IsAddonMessagePrefixRegistered", "C_ChatInfo.InChatMessagingLockdown", "C_ChatInfo.GetChannelRosterInfo",
  -- calendar
  "C_Calendar.OpenCalendar", "C_Calendar.GetNumDayEvents", "C_Calendar.GetDayEvent", "C_Calendar.CanAddEvent",
  "C_Calendar.CreateGuildSignUpEvent", "C_Calendar.CreateGuildAnnouncement", "C_Calendar.CreatePlayerEvent",
  "C_Calendar.AddEvent", "C_Calendar.EventSetTitle", "C_Calendar.EventSetDate", "C_Calendar.EventSignUp",
  "C_Calendar.GetEventIndexInfo", "C_Calendar.GetNumPendingInvites", "Calendar_Toggle", "ToggleCalendar",
  -- groups and raids
  "C_PartyInfo.InviteUnit", "InviteUnit", "C_PartyInfo.ConvertToRaid", "ConvertToRaid", "GetRaidRosterInfo",
  "SetRaidSubgroup", "SwapRaidSubgroup", "UnitSetRole", "UnitGroupRolesAssigned", "C_PartyInfo.SetRestrictPings",
  "C_LFGList.CreateListing", "C_LFGList.GetActiveEntryInfo", "C_LFGList.Search", "C_LFGInfo", "LFGBrowseFrame",
  "GetNumGroupMembers", "IsInRaid", "IsInGroup",
  -- character data
  "C_Traits.GetConfigInfo", "C_ClassTalents.GetActiveConfigID", "GetNumTalentTabs", "GetTalentTabInfo", "GetTalentInfo",
  "C_SpecializationInfo", "GetSpecialization", "GetAverageItemLevel", "GetInventoryItemLink", "C_Item.GetItemInfo",
  "C_Item.GetDetailedItemLevelInfo", "C_Item.GetItemIconByID", "GetItemInfo", "NotifyInspect", "CanInspect",
  "C_PaperDollInfo.GetInspectItemLevel", "GetProfessions", "GetNumSkillLines", "GetSkillLineInfo",
  "GetPVPLifetimeStats", "UnitPVPRank", "GetPVPRankInfo", "C_PvP", "GetStatistic", "GetAchievementInfo",
  "C_Engraving", "C_CurrencyInfo.GetCurrencyInfo",
  -- interface building blocks
  "BackdropTemplateMixin", "Mixin", "CreateFromMixins", "CreateFramePool", "CreateObjectPool", "ScrollUtil",
  "CreateScrollBoxListLinearView", "CreateDataProvider", "MenuUtil.CreateContextMenu", "UIDropDownMenu_Initialize",
  "EasyMenu", "Settings.RegisterCanvasLayoutCategory", "Settings.RegisterAddOnCategory", "InterfaceOptions_AddCategory",
  "AddonCompartmentFrame", "C_Texture.GetAtlasInfo", "GetFileIDFromPath", "C_Sound", "PlaySound", "SOUNDKIT",
  "C_TooltipInfo", "TooltipDataProcessor", "EventRegistry", "C_EditMode", "C_Map.GetBestMapForUnit", "C_CVar.GetCVar",
  "ChatFrame_AddMessageEventFilter", "C_KeyBindings", "SetOverrideBindingClick",
  -- combat log (analytics, Phase 5)
  "CombatLogGetCurrentEventInfo", "LoggingCombat", "C_CombatLog",
}

local TEMPLATES = {
  { "Frame", "BackdropTemplate" }, { "Frame", "ButtonFrameTemplate" }, { "Frame", "PortraitFrameTemplate" },
  { "Frame", "BasicFrameTemplateWithInset" }, { "Frame", "DefaultPanelTemplate" }, { "Frame", "InsetFrameTemplate" },
  { "Frame", "TooltipBackdropTemplate" }, { "Frame", "NineSlicePanelTemplate" }, { "Frame", "TabSystemTemplate" },
  { "Button", "UIPanelButtonTemplate" }, { "Button", "UIPanelCloseButton" }, { "Button", "PanelTabButtonTemplate" },
  { "Button", "SecureActionButtonTemplate" }, { "EditBox", "InputBoxTemplate" }, { "EditBox", "SearchBoxTemplate" },
  { "CheckButton", "UICheckButtonTemplate" }, { "ScrollFrame", "UIPanelScrollFrameTemplate" },
  { "Frame", "WowScrollBoxList" }, { "EventFrame", "MinimalScrollBar" }, { "DropdownButton", "WowStyle1DropdownTemplate" },
  { "Frame", "UIDropDownMenuTemplate" }, { "Slider", "MinimalSliderWithSteppersTemplate" },
}

-- Official art that could dress the addon (Blizzard files inside the client) plus our own test textures.
local FILES = {
  "Interface\\DialogFrame\\UI-DialogBox-Background-Dark", "Interface\\DialogFrame\\UI-DialogBox-Gold-Border",
  "Interface\\DialogFrame\\UI-DialogBox-Border", "Interface\\Tooltips\\UI-Tooltip-Border",
  "Interface\\Tooltips\\UI-Tooltip-Background", "Interface\\FrameGeneral\\UI-Background-Marble",
  "Interface\\FrameGeneral\\UI-Background-Rock", "Interface\\LFGFrame\\UI-LFG-ICON-ROLES",
  "Interface\\TargetingFrame\\UI-Classes-Circles", "Interface\\GLUES\\CHARACTERCREATE\\UI-CharacterCreate-Classes",
  "Interface\\AchievementFrame\\UI-Achievement-Parchment-Horizontal", "Interface\\Calendar\\UI-Calendar-Event-Raid",
  "Interface\\EncounterJournal\\UI-EJ-BACKGROUND-MoltenCore", "Interface\\EncounterJournal\\UI-EJ-DUNGEONBUTTON-MoltenCore",
  "Interface\\LFGFrame\\UI-LFG-BACKGROUND-MoltenCore", "Interface\\LFGFrame\\LFGIcon-MoltenCore",
  "Interface\\Glues\\LoadingScreens\\LoadScreenMoltenCore", "Interface\\Glues\\LoadingScreens\\LoadScreenBlackwingLair",
  "Interface\\Glues\\LoadingScreens\\LoadScreenEasternKingdom", "Interface\\Glues\\LoadingScreens\\LoadScreenKalimdor",
  "Interface\\Glues\\LoadingScreens\\LoadScreenOrgrimmar", "Interface\\Glues\\LoadingScreens\\LoadScreenStormwind",
  "Interface\\PVPFrame\\PVP-Banner-Emblem-1", "Interface\\GuildFrame\\GuildEmblemsLG_01",
  "Interface\\Icons\\INV_Misc_QuestionMark", "Interface\\Icons\\Achievement_Boss_Ragnaros",
  MEDIA .. "probe.tga", MEDIA .. "probe.png",
}

local ATLASES = {
  "groupfinder-icon-role-large-tank", "groupfinder-icon-role-large-heal", "groupfinder-icon-role-large-dps",
  "roleicon-tiny-tank", "roleicon-tiny-healer", "roleicon-tiny-dps", "UI-LFG-RoleIcon-Tank", "UI-Frame-Metal-CornerTopLeft",
  "Options_InnerFrame", "communities-guildbanner-background", "UI-HUD-ActionBar-IconFrame", "auctionhouse-background-index",
  "GarrMission_MissionParchment", "ui-frame-diamondmetal-header-cornerleft", "Campaign_Alliance", "Campaign_Horde",
  "AllianceEmblem", "HordeEmblem", "UI-Achievement-Guild-Flag-Outline", "loottoast-bg-alliance",
}

local function collectBuild()
  local version, build, date, toc = GetBuildInfo()
  report.build = { version = version, build = build, date = date, toc = toc, projectId = WOW_PROJECT_ID }
  report.player = {
    name = UnitName("player"), level = UnitLevel("player"), class = select(2, UnitClass("player")),
    race = select(2, UnitRace("player")), faction = UnitFactionGroup("player"), realm = GetRealmName(),
    normalizedRealm = GetNormalizedRealmName and GetNormalizedRealmName() or nil,
    region = GetCurrentRegion and GetCurrentRegion() or nil, locale = GetLocale(),
  }
  local fontFile, fontSize = GameFontNormal:GetFont()
  report.fonts = { normal = fontFile, normalSize = fontSize, highlight = (GameFontHighlight:GetFont()) }
end

local function collectApis()
  local available, total = 0, 0
  for _, name in ipairs(API) do
    local value = resolve(name)
    report.checks[name] = value ~= nil and type(value) or false
    total = total + 1
    if value ~= nil then
      available = available + 1
    end
  end
  report.apiSummary = { available = available, total = total }
end

local function collectTemplates()
  local ok, total = 0, 0
  for _, t in ipairs(TEMPLATES) do
    local created, frame = pcall(CreateFrame, t[1], nil, UIParent, t[2])
    total = total + 1
    if created then
      ok = ok + 1
      report.templates[t[2]] = true
      if frame and frame.Hide then
        frame:Hide()
      end
    else
      report.templates[t[2]] = string.sub(tostring(frame), 1, 140)
    end
  end
  report.templateSummary = { available = ok, total = total }
end

local function collectFiles()
  local probe = UIParent:CreateTexture(nil, "BACKGROUND")
  probe:Hide()
  for _, path in ipairs(FILES) do
    local entry = {}
    if GetFileIDFromPath then
      entry.fileId = GetFileIDFromPath(path) or false
    end
    entry.setTexture = probe:SetTexture(path) and true or false
    report.files[path] = entry
  end
  report.atlases = {}
  if C_Texture and C_Texture.GetAtlasInfo then
    for _, atlas in ipairs(ATLASES) do
      local info = C_Texture.GetAtlasInfo(atlas)
      report.atlases[atlas] = info and { w = info.width, h = info.height, file = info.file or info.filename } or false
    end
  end
end

local function collectGuild()
  if not IsInGuild() then
    report.guild = false
    return
  end
  local guildName, rankName, rankIndex = GetGuildInfo("player")
  local total, online = GetNumGuildMembers()
  local g = { name = guildName, myRank = rankName, myRankIndex = rankIndex, total = total, online = online, ranks = {}, perms = {} }
  if IsGuildLeader then
    g.isLeader = IsGuildLeader() and true or false
  end
  for _, fname in ipairs({ "CanGuildInvite", "CanGuildPromote", "CanGuildDemote", "CanGuildRemove", "CanEditOfficerNote",
    "CanEditPublicNote", "CanViewOfficerNote", "CanEditMOTD", "CanEditGuildInfo" }) do
    local fn = _G[fname] or (C_GuildInfo and C_GuildInfo[fname])
    if fn then
      local ok, value = pcall(fn)
      g.perms[fname] = ok and (value and true or false) or "error"
    end
  end
  if GuildControlGetNumRanks then
    for i = 1, GuildControlGetNumRanks() do
      g.ranks[i] = GuildControlGetRankName(i)
    end
  end
  -- Shape of one roster row (my own character only): number of return values and their types.
  local me = UnitName("player")
  for i = 1, total or 0 do
    local name = GetGuildRosterInfo(i)
    if name and (name == me or string.find(name, me, 1, true) == 1) then
      local row = { GetGuildRosterInfo(i) }
      local shape = {}
      for k = 1, select("#", GetGuildRosterInfo(i)) do
        shape[k] = type(row[k]) .. "=" .. string.sub(tostring(row[k]), 1, 40)
      end
      g.myRosterRow = shape
      break
    end
  end
  report.guild = g
end

local function collectCalendar()
  if not (C_Calendar and C_DateAndTime and C_DateAndTime.GetCurrentCalendarTime) then
    report.calendar = false
    return
  end
  local t = C_DateAndTime.GetCurrentCalendarTime()
  local c = { today = string.format("%04d-%02d-%02d", t.year, t.month, t.monthDay) }
  if C_Calendar.CanAddEvent then
    c.canAddEvent = C_Calendar.CanAddEvent() and true or false
  end
  if C_Calendar.GetNumDayEvents then
    c.todayEvents = C_Calendar.GetNumDayEvents(0, t.monthDay)
    local month = 0
    for day = 1, 31 do
      month = month + (C_Calendar.GetNumDayEvents(0, day) or 0)
    end
    c.monthEvents = month
  end
  report.calendar = c
end

local function startComms()
  if not (C_ChatInfo and C_ChatInfo.RegisterAddonMessagePrefix) then
    report.comms.available = false
    return
  end
  report.comms.registered = tostring(C_ChatInfo.RegisterAddonMessagePrefix(PREFIX))
  if IsInGuild() then
    report.timings.pingSent = now()
    report.comms.guildSend = tostring(C_ChatInfo.SendAddonMessage(PREFIX, "ping", "GUILD"))
  end
  report.timings.whisperSent = now()
  report.comms.whisperSelf = tostring(C_ChatInfo.SendAddonMessage(PREFIX, "ping-self", "WHISPER", UnitName("player")))
end

local function onAddonMessage(prefix, text, channel, sender)
  if prefix ~= PREFIX then
    return
  end
  local key = channel == "GUILD" and "guildEcho" or "whisperEcho"
  local sent = channel == "GUILD" and report.timings.pingSent or report.timings.whisperSent
  report.comms[key] = { text = text, channel = channel, sender = sender, ms = sent and math.floor((now() - sent) * 1000) or nil }
end

local function yesNo(v)
  return v and "|cff4fd36fsí|r" or "|cffff6b5bno|r"
end

local function refreshWindow(final)
  if not ui then
    return
  end
  local a, t = report.apiSummary or {}, report.templateSummary or {}
  local g = report.guild
  local lines = {
    string.format("Cliente %s (build %s, interfaz %s)", tostring(report.build and report.build.version),
      tostring(report.build and report.build.build), tostring(report.build and report.build.toc)),
    string.format("Funciones disponibles: %s de %s", tostring(a.available), tostring(a.total)),
    string.format("Plantillas de ventana: %s de %s", tostring(t.available), tostring(t.total)),
    g and string.format("Hermandad: %s, %s miembros, tu rango %s", tostring(g.name), tostring(g.total), tostring(g.myRank))
      or "Hermandad: no estás en ninguna",
    "Mensajes de addon a la hermandad: " .. yesNo(report.comms.guildEcho) .. "   a ti mismo: " .. yesNo(report.comms.whisperEcho),
    "Calendario del juego: " .. yesNo(report.calendar) .. "   errores de la sonda: " .. #report.errors,
  }
  ui.body:SetText(table.concat(lines, "\n"))
  if final then
    ui.status:SetText("|cffffd27aListo.|r Haz una captura (Impr Pant) y escribe |cffffffff/reload|r para guardar el informe.")
  end
end

local function buildWindow()
  local f = CreateFrame("Frame", "BlazonGuildProbeFrame", UIParent, BackdropTemplateMixin and "BackdropTemplate" or nil)
  f:SetSize(560, 300)
  f:SetPoint("CENTER", 0, 80)
  f:SetFrameStrata("DIALOG")
  f:SetMovable(true)
  f:EnableMouse(true)
  f:RegisterForDrag("LeftButton")
  f:SetScript("OnDragStart", f.StartMoving)
  f:SetScript("OnDragStop", f.StopMovingOrSizing)
  if f.SetBackdrop then
    f:SetBackdrop({
      bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark",
      edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Gold-Border",
      tile = true, tileSize = 32, edgeSize = 32,
      insets = { left = 11, right = 12, top = 12, bottom = 11 },
    })
  end
  local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
  title:SetPoint("TOP", 0, -22)
  title:SetText("BlazonGuild: sonda del cliente")
  safe("closeButton", function()
    local close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", -8, -8)
  end)

  -- Our own texture formats, side by side, to see which ones the client draws.
  local function swatch(file, label, x)
    local tex = f:CreateTexture(nil, "ARTWORK")
    tex:SetSize(56, 56)
    tex:SetPoint("TOPLEFT", x, -56)
    tex:SetTexture(file)
    local fs = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    fs:SetPoint("TOP", tex, "BOTTOM", 0, -4)
    fs:SetText(label)
  end
  swatch(MEDIA .. "probe.tga", "TGA propio", 34)
  swatch(MEDIA .. "probe.png", "PNG propio", 104)
  swatch("Interface\\Icons\\Achievement_Boss_Ragnaros", "Icono del juego", 174)

  f.body = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  f.body:SetPoint("TOPLEFT", 34, -142)
  f.body:SetPoint("RIGHT", -30, 0)
  f.body:SetJustifyH("LEFT")
  f.body:SetSpacing(3)
  f.status = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  f.status:SetPoint("BOTTOMLEFT", 34, 22)
  f.status:SetPoint("RIGHT", -30, 0)
  f.status:SetJustifyH("LEFT")
  f.status:SetText("Comprobando el cliente…")
  ui = f
end

local events = CreateFrame("Frame")
events:RegisterEvent("ADDON_LOADED")
events:RegisterEvent("PLAYER_LOGIN")
events:RegisterEvent("GUILD_ROSTER_UPDATE")
events:RegisterEvent("CHAT_MSG_ADDON")
events:RegisterEvent("CALENDAR_UPDATE_EVENT_LIST")
events:SetScript("OnEvent", function(_, event, ...)
  if event == "ADDON_LOADED" and ... == ADDON_NAME then
    report.startedAt = date("!%Y-%m-%dT%H:%M:%SZ")
    BlazonGuildProbeDB = report
  elseif event == "PLAYER_LOGIN" then
    safe("build", collectBuild)
    safe("apis", collectApis)
    safe("templates", collectTemplates)
    safe("files", collectFiles)
    safe("window", buildWindow)
    safe("comms", startComms)
    safe("rosterRequest", function()
      if C_GuildInfo and C_GuildInfo.GuildRoster then
        C_GuildInfo.GuildRoster()
      elseif GuildRoster then
        GuildRoster()
      end
    end)
    safe("calendarOpen", function()
      if C_Calendar and C_Calendar.OpenCalendar then
        C_Calendar.OpenCalendar()
      end
    end)
    refreshWindow(false)
    C_Timer.After(8, function()
      safe("guild", collectGuild)
      safe("calendar", collectCalendar)
      report.finishedAt = date("!%Y-%m-%dT%H:%M:%SZ")
      refreshWindow(true)
      print("|cffffd27aBlazonGuild (sonda):|r listo. Escribe /reload para guardar el informe. /bgsonda vuelve a abrir la ventana.")
    end)
  elseif event == "GUILD_ROSTER_UPDATE" then
    report.timings.rosterUpdates = (report.timings.rosterUpdates or 0) + 1
  elseif event == "CHAT_MSG_ADDON" then
    safe("addonMessage", onAddonMessage, ...)
    refreshWindow(report.finishedAt ~= nil)
  elseif event == "CALENDAR_UPDATE_EVENT_LIST" then
    report.timings.calendarUpdates = (report.timings.calendarUpdates or 0) + 1
  end
end)

SLASH_BLAZONGUILDPROBE1 = "/bgsonda"
SlashCmdList.BLAZONGUILDPROBE = function()
  if ui then
    ui:Show()
  end
end
