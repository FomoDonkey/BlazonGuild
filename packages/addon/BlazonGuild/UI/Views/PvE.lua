-- JcE (the menu's slot that said «Pronto» until 0.20.0). Left: one card per raid with how many members have the level
-- (and how many are online) and the bosses the guild has defeated there. Right: the chosen raid, boss by boss (first
-- time, how many times), and the guild's last raids.
local _, BG = ...
local UI, C = BG.UI, BG.color
local PvE = BG.PvE

local PAD = 24
local ICONS = { BARROW = "Interface\\Icons\\INV_Misc_Bone_ElfSkull_01", HYJAL = "Interface\\Icons\\Spell_Nature_Tranquility",
  MC = "Interface\\Icons\\Achievement_Boss_Ragnaros", ONY = "Interface\\Icons\\INV_Misc_Head_Dragon_Black",
  BWL = "Interface\\Icons\\INV_Misc_Head_Dragon_01", ZG = "Interface\\Icons\\INV_Misc_Idol_02", AQ20 = "Interface\\Icons\\INV_Misc_AhnQirajTrinket_01",
  AQ40 = "Interface\\Icons\\INV_Misc_AhnQirajTrinket_05", NAXX = "Interface\\Icons\\INV_Misc_Bone_HumanSkull_01", UBRS = "Interface\\Icons\\INV_Misc_Key_14" }

local function plate(f, title)
  local p = UI.Plate(f, { corners = 18, rail = 0.24 })
  p.head = UI.Heading(p, title)
  p.head:SetPoint("TOPLEFT", 16, -8)
  p.head:SetPoint("TOPRIGHT", -16, -8)
  return p
end

local function raidRow(list, f)
  local c = UI.Card(list)
  c:SetScript("OnClick", function(self)
    if self.item then
      f.selected = self.item.key
      BG.Sound("U_CHAT_SCROLL_BUTTON")
      BG:RefreshView("pve")
    end
  end)
  return c
end

local function fillRaid(c, r, f)
  c.item = r
  c.key = "pve:" .. r.key
  c:SetHeight(50)
  c.icon:SetTexture(BG.file(ICONS[r.key] or "Interface\\Icons\\INV_Misc_Head_Dragon_01", "Interface\\Icons\\INV_Misc_Note_02"))
  c.title:SetText(r.name)
  c.sub:SetText(r.ready .. " con nivel " .. r.minLevel .. " (" .. r.online .. " conectados)")
  local p = r.progress
  c.right:SetText(p.of and BG.colorize("Jefes " .. p.done .. "/" .. p.of, p.done >= p.of and C.success or (p.done > 0 and C.gold or C.text3)) or "")
  c.right2:SetText(r.size .. " jugadores")
  local on = f.selected == r.key
  c:SetSelected(on)
  c.accent:SetShown(on)
end

BG:RegisterView("pve", {
  Build = function(f)
    f.hero = UI.Hero(f, 108)
    f.hero:SetPoint("TOPLEFT")
    f.hero:SetPoint("TOPRIGHT")
    f.selected = PvE.ORDER[1]

    local left = plate(f, "Bandas")
    left:SetPoint("TOPLEFT", f.hero, "BOTTOMLEFT", PAD, -16)
    left:SetPoint("BOTTOMLEFT", PAD, 18)
    f.left = left
    f.list = UI.List(left, 54, function(list)
      return raidRow(list, f)
    end, function(c, r)
      fillRaid(c, r, f)
    end)
    f.list:SetPoint("TOPLEFT", left.head, "BOTTOMLEFT", 0, -10)
    f.list:SetPoint("BOTTOMRIGHT", -16, 14)

    local right = plate(f, "")
    right:SetPoint("TOPLEFT", left, "TOPRIGHT", 18, 0)
    right:SetPoint("BOTTOMRIGHT", -PAD, 18)
    f.right = right
    f.info = UI.Text(right, 12, C.text2, { wrap = true })
    f.info:SetPoint("TOPLEFT", right.head, "BOTTOMLEFT", 0, -4)
    f.info:SetPoint("RIGHT", -16, 0)
    f.bosses = UI.Text(right, 12, C.text, { wrap = true })
    f.bosses:SetPoint("TOPLEFT", f.info, "BOTTOMLEFT", 0, -10)
    f.bosses:SetPoint("RIGHT", -16, 0)
    f.bosses:SetSpacing(3)
    f.bosses:SetMaxLines(9)
    f.histHead = UI.Heading(right, "Últimas raids de la hermandad")
    f.histHead:SetPoint("BOTTOMLEFT", 16, 132)
    f.histHead:SetPoint("BOTTOMRIGHT", -16, 132)
    f.hist = UI.Text(right, 12, C.text2, { wrap = true })
    f.hist:SetPoint("TOPLEFT", f.histHead, "BOTTOMLEFT", 0, -6)
    f.hist:SetPoint("RIGHT", -16, 0)
    f.hist:SetSpacing(3)
    f.hist:SetMaxLines(5)

    f:SetScript("OnSizeChanged", function(self, w)
      self.left:SetWidth(math.floor((w - PAD * 2 - 18) * 0.5))
    end)
  end,

  Refresh = function(f)
    f.hero:SetArt(BG.file("Interface\\Glues\\LoadingScreens\\LoadScreenMoltenCore", BG.art.RAID), 0.5)
    f.hero:SetIcon(BG.file("Interface\\Icons\\INV_Misc_Head_Dragon_01", "Interface\\Icons\\INV_Misc_Note_02"))
    f.hero.title:SetText("JcE")
    local raids = PvE.Raids()
    local t = PvE.Totals()
    f.hero.sub:SetText("Quién tiene nivel para cada banda y lo que la hermandad lleva derrotado: " .. t.bosses
      .. (t.bosses == 1 and " jefe" or " jefes") .. (t.cleared > 0 and (", " .. t.cleared .. (t.cleared == 1 and " banda entera." or " bandas enteras.")) or "."))
    f.list:SetItems(raids)
    local r
    for _, x in ipairs(raids) do
      if x.key == f.selected then
        r = x
      end
    end
    r = r or raids[1]
    if not r then
      return
    end
    f.right.head:SetText(r.name)
    local p = r.progress
    f.info:SetText("Banda de " .. r.size .. " desde el nivel " .. r.minLevel .. ". En la hermandad tienen el nivel " .. r.ready .. " (" .. r.online .. " conectados ahora)."
      .. (p.of and (" Jefes derrotados: " .. p.done .. " de " .. p.of .. ".") or ""))
    local lines = {}
    for _, b in ipairs(p.bosses) do
      lines[#lines + 1] = "|TInterface\\RaidFrame\\ReadyCheck-Ready:12|t " .. b.n .. BG.colorize("  la primera vez el " .. UI.FormatDate(b.first) .. (b.times > 1 and (", " .. b.times .. " veces") or ""), C.text3)
    end
    f.bosses:SetText(#lines > 0 and table.concat(lines, "\n")
      or "Aún ninguno. Cuando la hermandad mate a un jefe de esta banda (con la mayoría del grupo de la hermandad), el addon de quien estaba allí lo apunta solo.")
    local hist = {}
    for _, h in ipairs(PvE.History(5)) do
      hist[#hist + 1] = BG.TF(h.n == 1 and "%s: %s (%d confirmado)" or "%s: %s (%d confirmados)", UI.FormatDate(h.at), BG.T(h.title), h.n)
    end
    f.hist:SetText(#hist > 0 and table.concat(hist, "\n") or "Aún ninguna. Aquí salen las raids de BlazonGuild que ya empezaron, con cuántos fueron.")
  end,
})

BG:On("BG_PVE_CHANGED", function()
  if BG.window and BG.window:IsShown() and BG.db.settings.lastView == "pve" then
    BG:RefreshView("pve")
  end
end)
