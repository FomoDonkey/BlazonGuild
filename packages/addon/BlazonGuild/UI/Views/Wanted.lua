-- «Se busca» (the menu's JcJ slot). Left: the wanted foes (bounty, how many members they killed, where) or what
-- happened lately (each death and each kill, with "Quitar" for its author and the organisers). Right: the hunters
-- of the last 90 days, how it works in two lines, and the member's own switch (record my deaths and kills).
local _, BG = ...
local UI, C = BG.UI, BG.color
local W, Names, Store = BG.Wanted, BG.Names, BG.Store

local PAD = 24

local function plate(f, title)
  local p = UI.Plate(f, { corners = 18, rail = 0.24 })
  p.head = UI.Heading(p, title)
  p.head:SetPoint("TOPLEFT", 16, -8)
  p.head:SetPoint("TOPRIGHT", -16, -8)
  return p
end

local function className(file)
  return file and ((LOCALIZED_CLASS_NAMES_MALE and LOCALIZED_CLASS_NAMES_MALE[file]) or (BG.Recruit.CLASS_NAMES[file])) or nil
end

-- Cards ---------------------------------------------------------------------------------------------------------
local function foeRow(list)
  return UI.Card(list)
end

local function fillFoe(c, f)
  c.key = "foe:" .. f.name
  c:SetHeight(58)
  BG.setClassIcon(c.icon, f.class)
  c.title:SetText(BG.colorize(f.name, BG.classColor(f.class)))
  c.sub:SetText("Ha matado a " .. f.nVictims .. (f.nVictims == 1 and " miembro" or " miembros") .. (f.zone and (", visto en " .. f.zone) or "") .. ".")
  c.right:SetText(BG.colorize("Recompensa " .. f.bounty, f.bounty >= W.WANTED_AT and C.danger or C.gold))
  c.right2:SetText(UI.FormatDate(f.at, true))
  local detail = {}
  local lvl = f.level == -1 and "??" or (f.level and tostring(f.level)) or nil
  local cls = className(f.class)
  if lvl or cls then
    detail[#detail + 1] = (cls or "Jugador") .. (lvl and (" de nivel " .. lvl) or "") .. "."
  end
  detail[#detail + 1] = "Muertes que ha causado: " .. f.deaths .. (f.ganks > 0 and (" (" .. f.ganks .. " a alguien de mucho menos nivel: valen doble)") or "") .. ". Última víctima: " .. (f.lastVictim or "?") .. "."
  if f.kills > 0 then
    detail[#detail + 1] = "Ya le han cazado " .. f.kills .. (f.kills == 1 and " vez" or " veces") .. (f.lastHunter and (", la última " .. f.lastHunter) or "") .. "."
  end
  detail[#detail + 1] = "Si le matas tú, te llevas " .. (f.bounty + 1) .. " puntos de cazador."
  c.detail = detail
end

local function recentRow(list, f)
  local c = UI.Card(list)
  c.remove = UI.CardButton(c, "Quitar", { height = 22, width = 70 })
  c.remove:SetPoint("BOTTOMRIGHT", -10, 8)
  c.remove:SetScript("OnClick", function()
    if c.row then
      local ok, w = W.Remove(c.row.id)
      if not ok then
        BG:Notify("No se pudo", w == "permiso" and "Solo quien lo apuntó o un oficial puede quitarlo." or ("No se pudo (" .. tostring(w) .. ")."), { kind = "warning" })
      end
    end
  end)
  c.right:ClearAllPoints()
  c.right:SetPoint("TOPRIGHT", -12, -10)
  return c
end

local function fillRecent(c, r)
  c.row = r
  c.key = r.id
  c:SetHeight(58)
  local died = r.d.k == "D"
  c.icon:SetTexture(died and "Interface\\Icons\\Ability_Rogue_FeignDeath" or "Interface\\Icons\\Ability_Hunter_SniperShot")
  local foe = BG.colorize(r.d.foe, BG.classColor(r.d.fc))
  c.title:SetText(died and (foe .. " mató a " .. r.by) or (r.by .. " cazó a " .. foe))
  local lvl = r.d.fl == -1 and "??" or (r.d.fl and tostring(r.d.fl)) or nil
  c.sub:SetText((r.d.zone or "Sin zona") .. (lvl and (", nivel " .. lvl .. (r.d.ml and (" contra " .. r.d.ml) or "")) or "") .. (died and W.Gank(r.d) and ", vale doble" or ""))
  c.right:SetText(UI.FormatDate(r.at, true))
  c.right2:SetText("")
  c.detail = { died and ("Lo vio el propio cliente de " .. r.by .. " (el resumen de muerte del juego).") or ("Golpe final de " .. r.by .. ", visto por su propio cliente."),
    "Si es un error, quien lo apuntó o un oficial puede quitarlo." }
  c.remove:SetShown(W.CanRemove(r))
end

-- View ---------------------------------------------------------------------------------------------------------------
local TABS = { { value = "board", label = "Se busca" }, { value = "recent", label = "Lo último" } }

BG:RegisterView("pvp", {
  Build = function(f)
    f.hero = UI.Hero(f, 108)
    f.hero:SetPoint("TOPLEFT")
    f.hero:SetPoint("TOPRIGHT")
    f.tab = "board"

    local left = plate(f, "Se busca")
    left:SetPoint("TOPLEFT", f.hero, "BOTTOMLEFT", PAD, -16)
    left:SetPoint("BOTTOMLEFT", PAD, 18)
    f.left = left
    f.tabs = UI.Segmented(left, TABS, { itemWidth = 96, height = 24, onChange = function(v)
      f.tab = v
      BG:RefreshView("pvp")
    end })
    f.tabs:SetPoint("TOPRIGHT", -16, -8)
    f.foes = UI.List(left, 62, foeRow, fillFoe)
    f.foes:SetPoint("TOPLEFT", left.head, "BOTTOMLEFT", 0, -12)
    f.foes:SetPoint("BOTTOMRIGHT", -16, 14)
    f.recent = UI.List(left, 62, function(list)
      return recentRow(list, f)
    end, fillRecent)
    f.recent:SetPoint("TOPLEFT", left.head, "BOTTOMLEFT", 0, -12)
    f.recent:SetPoint("BOTTOMRIGHT", -16, 14)
    f.empty = UI.Text(left, 12, C.text3, { wrap = true })
    f.empty:SetPoint("TOPLEFT", left.head, "BOTTOMLEFT", 0, -16)
    f.empty:SetPoint("RIGHT", -16, 0)
    f.empty:SetSpacing(4)

    local right = plate(f, "Cazadores (90 días)")
    right:SetPoint("TOPLEFT", left, "TOPRIGHT", 18, 0)
    right:SetPoint("BOTTOMRIGHT", -PAD, 18)
    f.right = right
    f.hunters = UI.Text(right, 12, C.text2, { wrap = true })
    f.hunters:SetPoint("TOPLEFT", right.head, "BOTTOMLEFT", 0, -8)
    f.hunters:SetPoint("RIGHT", -16, 0)
    f.hunters:SetSpacing(4)
    f.howHead = UI.Heading(right, "Cómo se cuenta")
    f.howHead:SetPoint("TOPLEFT", f.hunters, "BOTTOMLEFT", 0, -16)
    f.howHead:SetPoint("RIGHT", -16, 0)
    f.how = UI.Text(right, 12, C.text2, { wrap = true })
    f.how:SetPoint("TOPLEFT", f.howHead, "BOTTOMLEFT", 0, -6)
    f.how:SetPoint("RIGHT", -16, 0)
    f.how:SetSpacing(4)
    f.switch = UI.Button(right, "", { height = 26 })
    f.switch:SetPoint("BOTTOMLEFT", 16, 16)
    f.switch:SetPoint("BOTTOMRIGHT", -16, 16)
    f.switch:SetScript("OnClick", function()
      W.SetEnabled(not W.Enabled())
      BG:RefreshView("pvp")
    end)
    f.switchNote = UI.Text(right, 11, C.text3, { wrap = true })
    f.switchNote:SetPoint("BOTTOMLEFT", f.switch, "TOPLEFT", 0, 8)
    f.switchNote:SetPoint("RIGHT", -16, 0)

    f:SetScript("OnSizeChanged", function(self, w)
      self.left:SetWidth(math.floor((w - PAD * 2 - 18) * 0.6))
    end)
  end,

  Refresh = function(f)
    local info = BG.Guild.info
    local faction = info and info.faction or "ALLIANCE"
    f.hero:SetArt(BG.art[faction] or BG.art.ALLIANCE, 0.5)
    f.hero:SetIcon(BG.file("Interface\\Icons\\Ability_Hunter_MarkedForDeath", "Interface\\Icons\\Ability_DualWield"))
    f.hero.title:SetText("Se busca")
    f.hero.sub:SetText("Jugadores de la otra facción que matan a gente de la hermandad fuera de mazmorras y campos de batalla. Quien los caza se lleva su recompensa.")
    f.tabs:SetValue(f.tab, true)
    local board = f.tab == "board"
    f.left.head:SetText(board and "Se busca" or "Lo último")
    local items = board and W.Board() or W.Recent(40)
    f.foes:SetShown(board)
    f.recent:SetShown(not board)
    if board then
      f.foes:SetItems(items)
    else
      f.recent:SetItems(items)
    end
    f.empty:SetShown(#items == 0)
    f.empty:SetText(board and "Nadie con recompensa. Cuando alguien de la otra facción mate a un miembro fuera de mazmorras, aparecerá aquí por sí solo."
      or "Aún no ha pasado nada. Aquí sale cada muerte y cada baja que apuntan los miembros con el addon.")

    local lines = {}
    for i, h in ipairs(W.Hunters(8)) do
      lines[#lines + 1] = i .. ". " .. h.name .. ": " .. h.n .. (h.n == 1 and " punto" or " puntos") .. " (" .. h.kills .. (h.kills == 1 and " baja)" or " bajas)")
    end
    f.hunters:SetText(#lines > 0 and table.concat(lines, "\n") or "Aún nadie ha cazado a un buscado.")
    f.how:SetText("Cada muerte de un miembro suma 1 a la recompensa del que le mató (2 si le sacaba 10 niveles o más). "
      .. "Quien le mate se lleva la recompensa más 1 punto, y la recompensa vuelve a cero.")
    local on = W.Enabled()
    f.switch:SetText(on and "Apuntar mis muertes y bajas: sí" or "Apuntar mis muertes y bajas: no")
    f.switchNote:SetText(on and "Tu addon apunta solo lo tuyo, con el resumen de muerte y tu golpe final." or "Apagado: tu addon no apunta nada tuyo, pero sigues viendo la lista.")
  end,
})

BG:On("BG_WANTED_CHANGED", function()
  if BG.window and BG.window:IsShown() and BG.db.settings.lastView == "pvp" then
    BG:RefreshView("pvp")
  end
end)

BG.commands = BG.commands or {}
BG.commands.sebusca = function()
  if not (BG.window and BG.window:IsShown()) then
    BG:ToggleWindow()
  end
  BG:ShowView("pvp")
end
