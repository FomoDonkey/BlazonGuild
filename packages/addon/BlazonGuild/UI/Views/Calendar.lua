-- Calendario: the guild's next two weeks. BlazonGuild raids together with the game calendar's guild events,
-- player events and holidays (C_Calendar, verified on this client by the probe). Idea of a combined week from
-- Olympus's Week.lua (MIT). Clicking a raid opens it in Raids.
local _, BG = ...
local UI, C = BG.UI, BG.color
local Raids = BG.Raids

local PAD, DAYS = 24, 14
local SOURCE = {
  RAID = "Raid de BlazonGuild", GUILD_EVENT = "Evento de hermandad", GUILD_ANNOUNCEMENT = "Anuncio de hermandad",
  PLAYER = "Evento del calendario", HOLIDAY = "Festividad", COMMUNITY_EVENT = "Evento de comunidad",
}

-- Game calendar events of one day, read only (no event is created or answered from here).
local function gameEvents(t)
  local out = {}
  if not (C_Calendar and C_Calendar.GetNumDayEvents and C_Calendar.GetDayEvent) then
    return out
  end
  local d = date("*t", t)
  local now = date("*t")
  local offset = (d.year - now.year) * 12 + (d.month - now.month)
  local ok, n = pcall(C_Calendar.GetNumDayEvents, offset, d.day)
  if not ok or not n then
    return out
  end
  for i = 1, n do
    local okE, e = pcall(C_Calendar.GetDayEvent, offset, d.day, i)
    if okE and type(e) == "table" and e.title and e.calendarType ~= "RAID_LOCKOUT" and e.calendarType ~= "RAID_RESET" then
      local st = e.startTime
      local at = st and time({ year = st.year, month = st.month, day = st.monthDay, hour = st.hour or 0, min = st.minute or 0, sec = 0 }) or t
      out[#out + 1] = { at = at, title = e.title, source = SOURCE[e.calendarType] or "Calendario del juego", kind = e.calendarType, allDay = e.calendarType == "HOLIDAY" }
    end
  end
  return out
end

local function agenda()
  local base = date("*t")
  local rows = {}
  local holidays, holidayOrder = {}, {}
  local raidsByDay = {}
  for _, r in ipairs(Raids.Upcoming()) do
    local d = date("*t", r.d.start)
    local key = d.year * 10000 + d.month * 100 + d.day
    raidsByDay[key] = raidsByDay[key] or {}
    table.insert(raidsByDay[key], r)
  end
  local total = 0
  for i = 0, DAYS - 1 do
    local dayStart = time({ year = base.year, month = base.month, day = base.day + i, hour = 0, min = 0, sec = 0 })
    local d = date("*t", dayStart)
    local events = {}
    for _, r in ipairs(raidsByDay[d.year * 10000 + d.month * 100 + d.day] or {}) do
      local counts = Raids.Counts(r.id)
      events[#events + 1] = { at = r.d.start, title = r.d.title, source = SOURCE.RAID, raid = r, kind = "RAID",
        note = r.d.status == "CANCELLED" and "cancelada" or (counts.confirmed .. "/" .. r.d.cap .. " apuntados") }
    end
    for _, e in ipairs(gameEvents(dayStart)) do
      if e.kind == "HOLIDAY" then
        -- Holidays last days: listed once, above the agenda, with the day they end.
        local h = holidays[e.title]
        if not h then
          h = { title = e.title, first = dayStart, last = dayStart }
          holidays[e.title] = h
          holidayOrder[#holidayOrder + 1] = h
        end
        h.last = dayStart
      else
        events[#events + 1] = e
      end
    end
    table.sort(events, function(a, b)
      return a.at < b.at
    end)
    if #events > 0 then
      local label = i == 0 and "Hoy" or (i == 1 and "Mañana" or UI.FormatDate(dayStart))
      rows[#rows + 1] = { header = BG.Locale.UpperFirst(BG.T(label)) }
      for _, e in ipairs(events) do
        rows[#rows + 1] = e
        total = total + 1
      end
    end
  end
  return rows, total, holidayOrder
end

BG:RegisterView("calendar", {
  Build = function(f)
    f.hero = UI.Hero(f, 110)
    f.hero:SetPoint("TOPLEFT")
    f.hero:SetPoint("TOPRIGHT")
    f.hero:SetIcon("Interface\\Icons\\INV_Misc_Note_01")
    f.holidays = UI.Text(f, 12, C.text2, { wrap = true })
    f.holidays:SetPoint("TOPLEFT", f.hero, "BOTTOMLEFT", PAD, -10)
    f.holidays:SetPoint("RIGHT", -PAD, 0)
    f.holidays:SetMaxLines(2)
    f.heading = UI.Heading(f, "Las próximas dos semanas")
    f.heading:SetPoint("TOPLEFT", f.holidays, "BOTTOMLEFT", 0, -8)
    f.heading:SetPoint("RIGHT", -PAD, 0)
    f.list = UI.List(f, 30, function(list)
      local r = CreateFrame("Button", nil, list)
      r.bg = r:CreateTexture(nil, "BACKGROUND")
      r.bg:SetAllPoints()
      r.lz = r:CreateTexture(nil, "ARTWORK")
      r.lz:SetTexture(BG.media .. "lozenge.png")
      r.lz:SetSize(10, 10)
      r.lz:SetPoint("LEFT", 4, 0)
      r.time = UI.Text(r, 12, C.goldHi)
      r.time:SetPoint("LEFT", 26, 0)
      r.time:SetWidth(60)
      r.title = UI.Text(r, 13, C.text)
      r.title:SetPoint("LEFT", r.time, "RIGHT", 6, 0)
      r.source = UI.Text(r, 11, C.text3, { justify = "RIGHT" })
      r.source:SetPoint("RIGHT", -10, 0)
      r.source:SetWidth(260)
      r.title:SetPoint("RIGHT", r.source, "LEFT", -10, 0)
      local hl = r:CreateTexture(nil, "HIGHLIGHT")
      hl:SetColorTexture(C.gold[1], C.gold[2], C.gold[3], 0.07)
      hl:SetAllPoints()
      r:SetScript("OnClick", function(self)
        local raid = self.row and self.row.raid
        if raid then
          BG:ShowView("raids")
          local vf = BG.window.viewFrames.raids
          vf.selected = raid.id
          BG.views.raids.Refresh(vf, BG.views.raids)
        end
      end)
      return r
    end, function(r, row)
      r.row = row
      if row.header then
        r.bg:SetColorTexture(1, 1, 1, 0.03)
        r.lz:Show()
        r.time:SetText("")
        r.title:SetFont(BG.font.display, 14, "")
        r.title:SetText(row.header)
        r.title:SetTextColor(C.goldTitle[1], C.goldTitle[2], C.goldTitle[3])
        r.source:SetText("")
        return
      end
      r.bg:SetColorTexture(0, 0, 0, 0)
      r.lz:Hide()
      r.time:SetText(row.allDay and "todo el día" or UI.FormatTime(row.at))
      r.title:SetFont(BG.font.body, 13, "")
      r.title:SetText(row.title .. (row.note and BG.colorize("   " .. row.note, C.text3) or ""))
      local c = row.kind == "RAID" and C.text or C.text2
      r.title:SetTextColor(c[1], c[2], c[3])
      r.source:SetText(row.source)
    end)
    f.list:SetPoint("TOPLEFT", f.heading, "BOTTOMLEFT", 0, -12)
    f.list:SetPoint("BOTTOMRIGHT", -PAD, 18)
    f.empty = UI.Text(f, 14, C.text2, { justify = "CENTER", wrap = true })
    f.empty:SetPoint("CENTER", 0, 10)
    f.empty:SetWidth(460)
    f:SetScript("OnShow", function()
      if C_Calendar and C_Calendar.OpenCalendar then
        pcall(C_Calendar.OpenCalendar) -- asks the server for the month's events; CALENDAR_UPDATE_EVENT_LIST follows
      end
    end)
  end,
  Refresh = function(f)
    local rows, total, holidays = agenda()
    local info = BG.Guild.info
    f.hero:SetArt(BG.art[info and info.faction or "ALLIANCE"] or BG.art.ALLIANCE, 0.5)
    f.hero.title:SetText(info and BG.TF("Calendario de %s", info.name) or "Calendario")
    local raids = 0
    for _, row in ipairs(rows) do
      if row.kind == "RAID" then
        raids = raids + 1
      end
    end
    f.hero.sub:SetText(string.format("%s de BlazonGuild y %s del calendario del juego en las próximas dos semanas.",
      raids == 1 and "1 raid" or (raids .. " raids"), (total - raids) == 1 and "1 evento" or ((total - raids) .. " eventos")))
    local parts = {}
    for _, h in ipairs(holidays) do
      parts[#parts + 1] = BG.colorize(h.title, C.goldHi) .. BG.colorize(" (hasta el " .. UI.FormatDate(h.last):gsub("^(%S+) ", "%1 ") .. ")", C.text3)
    end
    f.holidays:SetText(#parts > 0 and ("Festividades: " .. table.concat(parts, ", ")) or "Sin festividades en estas dos semanas.")
    f.list:SetItems(rows)
    f.heading.title:SetText(total == 0 and "Las próximas dos semanas" or ("Las próximas dos semanas (" .. total .. ")"))
    f.empty:SetShown(total == 0)
    f.empty:SetText("Nada en las próximas dos semanas: ni raids de BlazonGuild ni eventos en el calendario del juego. Las raids que cree cualquier miembro en Raids aparecerán aquí.")
  end,
})

BG:On("PLAYER_LOGIN", function()
  C_Timer.After(8, function()
    if C_Calendar and C_Calendar.OpenCalendar then
      pcall(C_Calendar.OpenCalendar)
    end
  end)
end)

BG:On("CALENDAR_UPDATE_EVENT_LIST", function()
  BG:RefreshView("calendar")
end)
