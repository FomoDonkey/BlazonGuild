-- Mapa: where the guild is (online members by zone, from the guild roster), your position (off until you turn
-- it on: then your guildmates see you as a dot on their world map and minimap, and you see theirs), the layers of
-- your zone with a way to ask for an invite to another one, and the invites others ask you for. Three tabs on the
-- left: «Zonas», «En el mapa» (who shares their position, the meeting point, the arrow to follow them) and
-- «Avistamientos» (asking the guild where a player of the other faction was seen).
local _, BG = ...
local UI, C = BG.UI, BG.color
local Layers, Positions, Names, Radar, Sightings = BG.Layers, BG.Positions, BG.Names, BG.Radar, BG.Sightings

local PAD = 24
local TABS = {
  { value = "zones", label = "Zonas" },
  { value = "mates", label = "En el mapa" },
  { value = "seen", label = "Avistamientos" },
}
local PLACE_KEEP = 30 * 60

local function mapName(m)
  local info = C_Map and C_Map.GetMapInfo and C_Map.GetMapInfo(m)
  return info and info.name or nil
end

local function yardsTo(m, x, y)
  local east, south = Positions.Offset(m, x, y)
  return east and math.floor(math.sqrt(east * east + south * south) + 0.5) or nil
end

local function following(item)
  local t = Radar.Following()
  if not t or not item then
    return false
  end
  if item.mate then
    return t.mate == item.mate
  end
  return not t.mate and t.m == item.m and t.x == item.x and t.y == item.y
end

local function followRow(list)
  local c = UI.Card(list)
  c.go = UI.CardButton(c, "Seguir", { height = 22, width = 112 })
  c.go:SetPoint("BOTTOMRIGHT", -10, 8)
  c.go:SetScript("OnClick", function()
    local it = c.item
    if not it then
      return
    end
    if following(it) then
      Radar.Stop()
    elseif it.mate then
      Radar.Follow({ mate = it.mate })
    else
      Radar.Follow({ m = it.m, x = it.x, y = it.y, label = it.label })
    end
    BG:RefreshView("map")
  end)
  c.right2:ClearAllPoints()
  c.right2:SetPoint("RIGHT", c.go, "LEFT", -8, 0)
  return c
end

local function fillMate(c, it)
  c.item = it
  c:SetHeight(52)
  local yards = yardsTo(it.m, it.x, it.y)
  if it.mate then
    c.icon:SetTexture("Interface\\Icons\\INV_Misc_GroupNeedMore")
    c.title:SetText(BG.colorize(it.mate, BG.classColor(it.c)))
  else
    c.icon:SetTexture("Interface\\Icons\\Ability_Warrior_BattleShout")
    c.title:SetText(it.label)
  end
  c.sub:SetText(mapName(it.m) or "")
  c.right:SetText(yards and (yards .. " metros") or "lejos")
  c.right2:SetText("")
  c.go.text:SetText(following(it) and "Dejar de seguir" or "Seguir")
  local ac = following(it) and C.gold or C.line
  c.accent:SetColorTexture(ac[1], ac[2], ac[3], 0.9)
end

local function fillSeen(c, r)
  c.item = { m = r.m, x = r.x, y = r.y, label = "Visto: " .. r.name }
  c:SetHeight(52)
  c.icon:SetTexture("Interface\\Icons\\INV_Misc_Spyglass_02")
  local foe = BG.Wanted and BG.Wanted.Foe(r.name)
  local wanted = foe and foe.bounty > 0
  c.title:SetText(BG.colorize(r.name, BG.classColor(r.class)) .. (r.level and BG.colorize("  " .. (r.level < 0 and "??" or r.level), C.text3) or "")
    .. (wanted and BG.colorize("  se busca", C.danger) or ""))
  local who = r.by == Names.Me() and "por ti" or string.format("por %s", r.by)
  c.sub:SetText((r.zone and string.format("%s en «%s», %s", Sightings.Ago(r.at), r.zone, who) or (Sightings.Ago(r.at) .. ", " .. who))
    .. (r.guild and (". " .. string.format("Hermandad: %s", r.guild)) or ""))
  local yards = yardsTo(r.m, r.x, r.y)
  c.right:SetText(yards and (yards .. " metros") or "lejos")
  c.right2:SetText("")
  c.go.text:SetText(following(c.item) and "Dejar de seguir" or "Seguir")
  local ac = wanted and C.danger or C.line
  c.accent:SetColorTexture(ac[1], ac[2], ac[3], 0.9)
end

local function coloredName(m, onMap)
  local c = BG.classColor(m.classFile)
  return BG.colorize(Names.Short(m.name) or "?", c) .. " " .. BG.colorize(tostring(m.level), C.text3) .. (onMap and BG.colorize(" (en el mapa)", C.gold) or "")
end

local function zoneRow(list)
  local c = UI.Card(list)
  c.icon:SetTexture("Interface\\Icons\\INV_Misc_Map_01")
  return c
end

local function fillZone(c, z)
  c:SetHeight(50)
  local here = BG.Guild.me and BG.Guild.me.zone == z.zone
  local onMap = {}
  for _, p in ipairs(Positions.Mates()) do
    onMap[p.name] = true
  end
  c.title:SetText(z.zone)
  local parts = {}
  for i, m in ipairs(z.members) do
    if i > 6 then
      parts[#parts + 1] = "y " .. (#z.members - 6) .. " más"
      break
    end
    parts[#parts + 1] = coloredName(m, onMap[Names.Short(m.name)])
  end
  c.sub:SetText(table.concat(parts, ", "))
  c.right:SetText(#z.members .. (#z.members == 1 and " conectado" or " conectados"))
  c.right2:SetText(here and BG.colorize("aquí estás", C.gold) or "")
  local ac = here and C.gold or C.line
  c.accent:SetColorTexture(ac[1], ac[2], ac[3], 0.9)
end

local function layerRow(list)
  local c = UI.Card(list)
  c.icon:SetTexture("Interface\\Icons\\Spell_Arcane_PortalDalaran")
  c.ask = UI.CardButton(c, "Pedir invitación", { height = 22, width = 124 })
  c.ask:SetPoint("BOTTOMRIGHT", -10, 8)
  c.ask:SetScript("OnClick", function()
    local host = c.host
    if not host then
      return
    end
    local ok, w = Layers.Ask(host)
    BG:Notify(ok and "Petición enviada" or "No se pudo", ok and (host .. " decide si te invita. Cuando llegues a su capa te sacamos del grupo.")
      or (w == "en grupo" and "Sal antes de tu grupo: la invitación es a uno nuevo." or "Esa persona no acepta peticiones ahora."), { kind = ok and "info" or "warning" })
    BG:RefreshView("map")
  end)
  return c
end

local function fillLayer(c, g)
  c:SetHeight(52)
  local myRealm = GetNormalizedRealmName and GetNormalizedRealmName()
  c.title:SetText("Capa de " .. (g.label or "?") .. (g.mine and BG.colorize("  la tuya", C.gold) or "")
    .. (g.r and g.r ~= myRealm and BG.colorize("  otro reino", C.warning) or ""))
  c.sub:SetText(table.concat(g.members, ", "))
  c.right:SetText(#g.members .. (#g.members == 1 and " persona" or " personas"))
  c.right2:SetText("")
  c.host = not g.mine and Layers.HostOf(g) or nil
  c.ask:SetShown(c.host ~= nil and not Layers.Pending())
  local ac = g.mine and C.gold or C.line
  c.accent:SetColorTexture(ac[1], ac[2], ac[3], 0.9)
end

local function requestRow(list)
  local c = UI.Card(list)
  c.icon:SetTexture("Interface\\Icons\\INV_Letter_15")
  c.no = UI.CardButton(c, "No", { height = 22, width = 50 })
  c.no:SetPoint("RIGHT", -10, 0)
  c.yes = UI.CardButton(c, "Invitar", { primary = true, height = 22, width = 80 })
  c.yes:SetPoint("RIGHT", c.no, "LEFT", -6, 0)
  c.yes:SetScript("OnClick", function()
    if c.req then
      Layers.Answer(c.req.name, true)
    end
  end)
  c.no:SetScript("OnClick", function()
    if c.req then
      Layers.Answer(c.req.name, false)
    end
  end)
  c.right:ClearAllPoints()
  c.right:SetPoint("RIGHT", c.yes, "LEFT", -10, 0)
  return c
end

local function fillRequest(c, r)
  c.req = r
  c:SetHeight(44)
  c.title:SetText(r.name .. " quiere pasar a tu capa")
  c.sub:SetText("Si le invitas, el addon le saca del grupo al llegar.")
  c.right:SetText("")
  c.right2:SetText("")
end

BG:RegisterView("map", {
  Build = function(f)
    f.hero = UI.Hero(f, 118)
    f.hero:SetPoint("TOPLEFT")
    f.hero:SetPoint("TOPRIGHT")

    local zones = UI.Plate(f, { corners = 18, rail = 0.24 })
    zones:SetPoint("TOPLEFT", f.hero, "BOTTOMLEFT", PAD, -16)
    zones:SetPoint("BOTTOM", 0, 18)
    f.zonesPlate = zones
    f.tab = "zones"
    zones.tabs = UI.Segmented(zones, TABS, { height = 24, onChange = function(v)
      f.tab = v
      BG:RefreshView("map")
    end })
    zones.tabs:SetPoint("TOPLEFT", 16, -12)
    f.tabs = zones.tabs -- (the screen checks in every language go through each view's f.tabs)
    zones.note = UI.Text(zones, 12, C.text2, { wrap = true })
    zones.note:SetPoint("TOPLEFT", zones.tabs, "BOTTOMLEFT", 0, -10)
    zones.note:SetPoint("RIGHT", -16, 0)
    zones.note:SetSpacing(2)
    f.zones = UI.List(zones, 56, zoneRow, fillZone)
    f.zones:SetPoint("TOPLEFT", zones.note, "BOTTOMLEFT", 0, -10)
    f.zones:SetPoint("BOTTOMRIGHT", -16, 14)
    f.zonesEmpty = UI.Text(zones, 12, C.text3, { wrap = true })
    f.zonesEmpty:SetPoint("TOPLEFT", zones.note, "BOTTOMLEFT", 0, -14)
    f.zonesEmpty:SetPoint("RIGHT", -16, 0)

    -- «En el mapa»: who shares their position and the meeting point, each one to follow with the arrow.
    f.mates = UI.List(zones, 56, followRow, fillMate)
    f.mates:SetPoint("TOPLEFT", zones.note, "BOTTOMLEFT", 0, -10)
    f.mates:SetPoint("BOTTOMRIGHT", -16, 48)
    zones.dots = UI.Button(zones, "", { height = 24 })
    zones.dots:SetPoint("BOTTOMLEFT", 16, 14)
    zones.dots:SetPoint("BOTTOMRIGHT", -16, 14)
    zones.dots:SetScript("OnClick", function()
      Radar.SetEnabled(not Radar.Enabled())
    end)

    -- «Avistamientos»: ask about one name, or about the zone you are in.
    zones.ask = UI.EditBox(zones, { placeholder = "Nombre de un jugador de la otra facción", maxLetters = 40, onEnter = function(text)
      f.askName(text)
    end })
    zones.ask:SetPoint("TOPLEFT", zones.note, "BOTTOMLEFT", 0, -10)
    zones.ask:SetPoint("RIGHT", -16, 0)
    zones.where = UI.Button(zones, "¿Dónde está?", { primary = true, height = 24 })
    zones.where:SetPoint("TOPLEFT", zones.ask, "BOTTOMLEFT", 0, -8)
    zones.where:SetPoint("TOPRIGHT", zones.ask, "BOTTOM", -4, -8)
    zones.where:SetScript("OnClick", function()
      f.askName(zones.ask:GetText())
    end)
    zones.area = UI.Button(zones, "Enemigos en mi zona", { height = 24 })
    zones.area:SetPoint("TOPLEFT", zones.ask, "BOTTOM", 4, -8)
    zones.area:SetPoint("TOPRIGHT", zones.ask, "BOTTOMRIGHT", 0, -8)
    zones.area:SetScript("OnClick", function()
      local ok, w = Sightings.Ask()
      if not ok then
        BG:Notify("No se pudo preguntar", w == "sin zona" and "Aquí no hay zona: estás en una mazmorra, en un barco o volando."
          or w == "espera" and "Espera unos segundos entre una pregunta y otra." or "Acepta antes la privacidad (/bg privacidad).", { kind = "warning" })
      end
    end)
    zones.status = UI.Text(zones, 12, C.text2, { wrap = true })
    zones.status:SetPoint("TOPLEFT", zones.where, "BOTTOMLEFT", 0, -10)
    zones.status:SetPoint("RIGHT", -16, 0)
    f.seen = UI.List(zones, 56, followRow, fillSeen)
    f.seen:SetPoint("TOPLEFT", zones.status, "BOTTOMLEFT", 0, -8)
    f.seen:SetPoint("BOTTOMRIGHT", -16, 48)
    zones.answer = UI.Button(zones, "", { height = 24 })
    zones.answer:SetPoint("BOTTOMLEFT", 16, 14)
    zones.answer:SetPoint("BOTTOMRIGHT", -16, 14)
    zones.answer:SetScript("OnClick", function()
      local ok = Sightings.SetAnswering(not Sightings.Answering())
      if not ok then
        BG:Notify("No se pudo", "Acepta antes la privacidad (/bg privacidad).", { kind = "warning" })
      end
    end)
    function f.askName(text)
      text = (text or ""):gsub("^%s+", ""):gsub("%s+$", "")
      if text == "" then
        BG:Notify("Escribe un nombre", "Por ejemplo, el de alguien de «Se busca».", { kind = "info" })
        return
      end
      local ok, w = Sightings.Ask(text)
      if not ok then
        BG:Notify("No se pudo preguntar", w == "espera" and "Espera unos segundos entre una pregunta y otra." or "Acepta antes la privacidad (/bg privacidad).", { kind = "warning" })
      end
    end

    local side = UI.Plate(f, { corners = 18, rail = 0.24 })
    side:SetPoint("TOPLEFT", zones, "TOPRIGHT", 18, 0)
    side:SetPoint("BOTTOMRIGHT", -PAD, 18)
    f.side = side

    -- Your position: what sharing does, who sees it and where.
    side.posHead = UI.Heading(side, "Tu posición en el mapa")
    side.posHead:SetPoint("TOPLEFT", 16, -8)
    side.posHead:SetPoint("TOPRIGHT", -16, -8)
    side.status = UI.Text(side, 13, C.text, { wrap = true })
    side.status:SetPoint("TOPLEFT", side.posHead, "BOTTOMLEFT", 0, -6)
    side.status:SetPoint("RIGHT", -16, 0)
    side.how = UI.Text(side, 12, C.text2, { wrap = true })
    side.how:SetPoint("TOPLEFT", side.status, "BOTTOMLEFT", 0, -6)
    side.how:SetPoint("RIGHT", -16, 0)
    side.how:SetSpacing(3)
    side.share = UI.Button(side, "Compartir mi posición", { primary = true, height = 26 })
    side.share:SetPoint("TOPLEFT", side.how, "BOTTOMLEFT", 0, -10)
    side.share:SetPoint("TOPRIGHT", side.how, "BOTTOM", -4, -10)
    side.share:SetScript("OnClick", function()
      local ok, w = Layers.SetSharing(not Layers.Sharing())
      if not ok then
        BG:Notify("No se pudo", w == "consent" and "Acepta antes la privacidad (/bg privacidad)." or tostring(w), { kind = "warning" })
      end
    end)
    side.open = UI.Button(side, "Abrir el mapa del mundo", { height = 26 })
    side.open:SetPoint("TOPLEFT", side.how, "BOTTOM", 4, -10)
    side.open:SetPoint("TOPRIGHT", side.how, "BOTTOMRIGHT", 0, -10)
    side.open:SetScript("OnClick", function()
      BG:Minimize(true) -- (back when the map closes)
      if ToggleWorldMap then
        ToggleWorldMap()
      elseif WorldMapFrame then
        WorldMapFrame:Show()
      end
    end)

    -- Layers of your zone.
    side.layHead = UI.Heading(side, "Capas de tu zona")
    side.layHead:SetPoint("TOPLEFT", side.share, "BOTTOMLEFT", 0, -14)
    side.layHead:SetPoint("RIGHT", -16, 0)
    side.text = UI.Text(side, 12, C.text2, { wrap = true })
    side.text:SetPoint("TOPLEFT", side.layHead, "BOTTOMLEFT", 0, -6)
    side.text:SetPoint("RIGHT", -16, 0)
    side.cancel = UI.Button(side, "Cancelar la petición", { height = 22, width = 150 })
    side.cancel:SetPoint("TOPLEFT", side.text, "BOTTOMLEFT", 0, -6)
    side.cancel:SetScript("OnClick", function()
      Layers.CancelHop()
    end)
    f.requests = UI.List(side, 48, requestRow, fillRequest)
    f.requests:SetPoint("TOPLEFT", side.text, "BOTTOMLEFT", 0, -8)
    f.requests:SetPoint("RIGHT", -16, 0)
    f.requests:SetHeight(96)
    f.layers = UI.List(side, 56, layerRow, fillLayer)
    f.layers:SetPoint("BOTTOMRIGHT", -16, 44)
    side.help = UI.Button(side, "No aceptar peticiones de capa", { height = 24 })
    side.help:SetPoint("BOTTOMLEFT", 16, 14)
    side.help:SetPoint("BOTTOMRIGHT", -16, 14)
    side.help:SetScript("OnClick", function()
      Layers.SetHelping(not Layers.Helping())
    end)

    f:SetScript("OnSizeChanged", function(self, w)
      self.zonesPlate:SetWidth(math.floor((w - PAD * 2 - 18) * 0.45))
    end)
  end,

  Refresh = function(f)
    local info = BG.Guild.info
    local faction = info and info.faction or "ALLIANCE"
    f.hero:SetArt(BG.art[faction] or BG.art.ALLIANCE, 0.5)
    f.hero:SetIcon(BG.file("Interface\\Icons\\INV_Misc_Map_01", "Interface\\Icons\\INV_Misc_Note_01"))
    local zones = Layers.Zones()
    local online = 0
    for _, z in ipairs(zones) do
      online = online + #z.members
    end
    local here = BG.Guild.me and BG.Guild.me.zone
    local map = Layers.ZoneMap()
    local groups = map and Layers.InZone(map) or {}
    local mineLabel
    for _, g in ipairs(groups) do
      if g.mine then
        mineLabel = g.label
      end
    end
    f.hero.title:SetText("Mapa")
    f.hero.sub:SetText(string.format("%d conectados en %d %s.", online, #zones, #zones == 1 and "zona" or "zonas")
      .. (here and (" Tú estás en " .. here .. (mineLabel and (", capa de " .. mineLabel) or "") .. ".") or ""))
    local zp = f.zonesPlate
    zp.tabs:SetValue(f.tab, true)
    local tab = f.tab
    f.zones:SetShown(tab == "zones")
    f.mates:SetShown(tab == "mates")
    zp.dots:SetShown(tab == "mates")
    for _, w in ipairs({ zp.ask, zp.where, zp.area, zp.status, f.seen, zp.answer }) do
      w:SetShown(tab == "seen")
    end
    f.zonesEmpty:Hide()
    if tab == "zones" then
      zp.note:SetText("Los conectados de cada zona, tengan o no BlazonGuild.")
      f.zones:SetItems(zones)
      f.zonesEmpty:SetText("Nadie más está conectado ahora.")
      f.zonesEmpty:SetShown(#zones == 0)
    elseif tab == "mates" then
      zp.note:SetText("Quien comparte su posición sale como un punto en tu mapa del mundo y en tu minimapa. «Seguir» pone una flecha bajo el minimapa que te lleva hasta él.")
      local items = {}
      local place = BG.Board.lastPlace
      if place and GetTime() - place.t < PLACE_KEEP then
        items[1] = { m = place.m, x = place.x, y = place.y, label = place.label }
      end
      for _, p in ipairs(Positions.Mates()) do
        items[#items + 1] = { mate = p.name, c = p.c, m = p.m, x = p.x, y = p.y }
      end
      f.mates:SetItems(items)
      f.zonesEmpty:SetText("Nadie comparte ahora su posición. Cada uno lo enciende con «Compartir mi posición».")
      f.zonesEmpty:SetShown(#items == 0)
      zp.dots.text:SetText(Radar.Enabled() and "Quitar los puntos del minimapa" or "Poner los puntos en el minimapa")
    else
      zp.note:SetText("Pregunta a tu hermandad dónde se vio a un jugador de la otra facción. Responden quienes lo aceptan, con lo que su juego les enseñó en el último cuarto de hora.")
      local ask = Sightings.Current()
      local rows = ask and ask.rows or {}
      if not ask then
        zp.status:SetText(BG.colorize("Aún no has preguntado nada.", C.text3))
      else
        local asked = ask.name and string.format("Preguntaste por «%s» %s.", ask.name, Sightings.Ago(ask.t))
          or string.format("Preguntaste por los enemigos de «%s» %s.", ask.zoneName or "?", Sightings.Ago(ask.t))
        zp.status:SetText(asked .. " " .. (#rows == 0 and "Nadie lo ha visto todavía." or (#rows == 1 and "1 avistamiento." or (#rows .. " avistamientos."))))
      end
      f.seen:SetItems(rows)
      zp.answer.text:SetText(Sightings.Answering() and "No responder cuando pregunten" or "Responder cuando pregunten")
    end

    local side = f.side
    local sharing = Layers.Sharing()
    local mates = #Positions.Mates()
    local guild = info and info.name or "tu hermandad"
    side.status:SetText(sharing and BG.colorize("Compartes tu posición con " .. guild .. ".", C.success) or BG.colorize("No compartes tu posición.", C.text3))
    side.how:SetText(table.concat({
      "· Quien la comparte sale como un punto de su color de clase en el mapa del mundo (tecla M) de sus compañeros con BlazonGuild.",
      "· Solo tu hermandad; nunca dentro de mazmorras. Tú no ves tu punto: el juego ya te marca.",
      "· Ahora la comparten " .. mates .. (mates == 1 and " compañero." or " compañeros."),
    }, "\n"))
    side.share.text:SetText(sharing and "Dejar de compartir" or "Compartir mi posición")

    local h = Layers.Pending()
    if h then
      side.text:SetText(BG.colorize(h.joined and ("Ya estás en el grupo de " .. h.host .. ". En cuanto el juego te pase a su capa, te sacamos del grupo.")
        or ("Esperando a que " .. h.host .. " te invite…"), C.gold))
    elseif not map then
      side.text:SetText("Aquí no hay capas: estás en una mazmorra, en un barco o volando.")
    elseif not Layers.Mine() then
      side.text:SetText("Una capa es una copia de la zona. Para saber la tuya no hace falta tocar nada aquí: en el juego, haz clic en dos personajes que no sean jugadores (un guardia, un vendedor, un bicho) o pasa el ratón por encima de ellos."
        .. (sharing and "" or " Tu hermandad la verá si compartes tu posición."))
    else
      side.text:SetText("Una capa es una copia de la zona. Para jugar con alguien de otra, pídele invitación: él decide, y el addon te saca del grupo al llegar.")
    end
    side.cancel:SetShown(h ~= nil)

    local reqs = Layers.Requests()
    f.requests:SetShown(#reqs > 0)
    f.requests:SetHeight(math.min(2, #reqs) * 48)
    f.requests:SetItems(reqs)
    f.layers:ClearAllPoints()
    f.layers:SetPoint("TOPLEFT", (h and side.cancel) or (#reqs > 0 and f.requests) or side.text, "BOTTOMLEFT", 0, -8)
    f.layers:SetPoint("BOTTOMRIGHT", -16, sharing and 44 or 14)
    f.layers:SetItems(groups)

    side.help:SetShown(sharing)
    side.help.text:SetText(Layers.Helping() and "No aceptar peticiones de capa" or "Aceptar peticiones de capa")
  end,
})

BG:On("BG_MAP_CHANGED", function()
  BG:RefreshView("map")
end)
BG:On("BG_SIGHTINGS_CHANGED", function()
  BG:RefreshView("map")
end)
BG:On("BG_CONSENT_LINE", function()
  BG:RefreshView("map")
end)
