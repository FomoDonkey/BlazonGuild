-- La Taberna, the Arena's fifth tab: on the left the Huesos table (play against the house to practise, or invite a
-- member), on the right the practice lottery (free tickets, the day's draw, the last days). Points only.
-- The table (0.25.0, Peregrino: «no se ve nada gráfico… y no se entiende cómo funciona»): the two scores with a bar to
-- the target, a felt where the dice fall, bounce and spin (UI/Dice.lua), the dice that can score shining, the ones
-- kept this turn aside, the turn's three steps with the current one lit, buttons that say what they do, and «Cómo
-- se juega» with the scoring.
local _, BG = ...
local UI, C = BG.UI, BG.color
local Bones, Lotto, Names, Store = BG.Bones, BG.Lotto, BG.Names, BG.Store

local DIE, GAP = 44, 12
local FELT = { 0.09, 0.22, 0.14 }
local WOOD = { 0.36, 0.22, 0.11 }
local BANNER_FOR = 3

local function why(w)
  return ({ ["fuera de turno"] = "No es tu turno.", tirando = "Esperando a tu tirada…", ["sin juego"] = "Este cliente no deja tirar /roll a los addons.",
    ["no puntúan"] = "Guarda solo dados que puntúen: los que brillan.", ["sin addon"] = "Tiene que estar conectado y con BlazonGuild.",
    ["no es de tu hermandad"] = "Elige a alguien de tu hermandad.", jugando = "Termina antes tu partida.", ["número"] = "Escribe un número del 1 al 100.",
    sorteado = "Hoy ya se ha sorteado: mañana hay boletos nuevos.", repetido = "Ya tienes ese número.", lleno = "Ya tienes tus 3 boletos de hoy.",
    permiso = "Solo los oficiales sortean.", sorteando = "Ya se está sorteando." })[w] or ("No se pudo (" .. tostring(w) .. ").")
end

local function keepList(f)
  local out = {}
  for i = 1, 6 do
    if f.keep[i] then
      out[#out + 1] = i
    end
  end
  return out
end

-- The rules, in BlazonGuild's own dialog.
function BG.UI.BonesRules()
  UI.Dialog({
    title = "Cómo se juega a los Huesos",
    items = {
      "Gana quien llega antes a " .. Bones.TARGET .. " puntos. Cada turno tiene tres pasos:",
      { bullet = "1. Tira los dados." },
      { bullet = "2. Guarda al menos un dado que puntúe: en la mesa, brillan." },
      { bullet = "3. Tira los que quedan para sumar más, o plántate: lo del turno pasa a tu marcador." },
      "Si al tirar ningún dado puntúa, salen «huesos»: pierdes lo del turno y le toca al otro. Si guardas los seis, vuelves a tirarlos todos.",
      { bullet = "Un 1 vale 100 y un 5 vale 50." },
      { bullet = "Tres iguales: la cara × 100 (tres 4 = 400); tres 1 = 1000. Cada dado igual de más lo dobla." },
      { bullet = "Escalera del 1 al 6: 1500. Tres parejas: 750." },
      { note = "Se juega por puntos: aquí no se apuesta oro." },
    },
    primary = { label = "Entendido" },
  })
end

-- Whom to invite: everyone of the guild online now; who has no BlazonGuild shows, greyed (they cannot play yet).
function BG.UI.BonesRivals()
  local with = {}
  for _, p in ipairs(BG.Peers.Active()) do
    with[Names.Short(p.name) or ""] = true
  end
  local opts = {}
  for _, m in ipairs(BG.Guild.members or {}) do
    local n = Names.Short(m.name)
    if m.online and n and not Names.IsMe(n) then
      local ok = with[n] == true
      opts[#opts + 1] = { value = n, label = BG.colorize(n, BG.classColor(m.classFile)), note = ok and ("nivel " .. (m.level or "?")) or "sin BlazonGuild",
        disabled = not ok or nil }
    end
  end
  table.sort(opts, function(a, b)
    if (a.disabled == nil) ~= (b.disabled == nil) then
      return a.disabled == nil
    end
    return a.value < b.value
  end)
  return opts
end

function BG.UI.TavernBuild(f, left, right)
  local t = CreateFrame("Frame", nil, left)
  t:SetPoint("TOPLEFT", left.head, "BOTTOMLEFT", 0, -10)
  t:SetPoint("BOTTOMRIGHT", -16, 14)
  t:Hide()
  f.tavern = t
  f.keep = {}

  -- With no game: what it is, play against the house, invite someone, the invitations, who wins most.
  t.intro = UI.Text(t, 12, C.text2, { wrap = true })
  t.intro:SetPoint("TOPLEFT")
  t.intro:SetPoint("RIGHT")
  t.intro:SetSpacing(3)
  t.intro:SetText("Un juego de dados de taberna. Tiras seis dados, guardas los que puntúan y decides: arriesgar con los que quedan o plantarte. Gana quien llega a "
    .. Bones.TARGET .. ". Los dados salen del /roll del juego, así que nadie hace trampas.")
  t.house = UI.Button(t, "Jugar contra la casa", { primary = true, height = 26, width = 190 })
  t.house:SetPoint("TOPLEFT", t.intro, "BOTTOMLEFT", 0, -12)
  t.house:SetScript("OnClick", function()
    f.keep = {}
    Bones.Practice()
  end)
  t.rules0 = UI.Button(t, "Cómo se juega", { height = 26, width = 130 })
  t.rules0:SetPoint("LEFT", t.house, "RIGHT", 8, 0)
  t.rules0:SetScript("OnClick", function()
    BG.UI.BonesRules()
  end)
  t.rival = UI.Picker(t, { width = 180, placeholder = "Elige a quién retar", fill = function()
    return BG.UI.BonesRivals()
  end, empty = "Nadie más de la hermandad está conectado ahora." })
  t.rival:SetPoint("TOPLEFT", t.house, "BOTTOMLEFT", 0, -10)
  t.invite = UI.Button(t, "Retar", { height = 26, width = 80 })
  t.invite:SetPoint("LEFT", t.rival, "RIGHT", 8, 0)
  t.invite:SetScript("OnClick", function()
    local ok, w = Bones.Invite(t.rival:GetValue())
    BG:Notify(ok and "Invitación enviada" or "No se pudo", ok and "Si acepta, empiezas tú." or why(w), { kind = ok and "success" or "warning" })
  end)
  t.invites = UI.List(t, 62, function(list)
    local c = UI.Card(list)
    c.no = UI.CardButton(c, "No", { height = 22, width = 50 })
    c.no:SetPoint("BOTTOMRIGHT", -10, 8)
    c.yes = UI.CardButton(c, "Jugar", { height = 22, width = 70, primary = true })
    c.yes:SetPoint("RIGHT", c.no, "LEFT", -6, 0)
    for _, b in ipairs({ c.yes, c.no }) do
      b:SetScript("OnClick", function()
        if c.inv then
          f.keep = {}
          Bones.Answer(c.inv.name, b == c.yes)
        end
      end)
    end
    return c
  end, function(c, inv)
    c.inv = inv
    c.key = "i:" .. inv.name
    c:SetHeight(58)
    c.icon:SetTexture("Interface\\Buttons\\UI-GroupLoot-Dice-Up")
    c.title:SetText(inv.name .. " te invita")
    c.sub:SetText("Una partida de Huesos, a " .. Bones.TARGET .. ".")
    c.right:SetText("")
    c.right2:SetText("")
  end)
  t.invites:SetPoint("TOPLEFT", t.rival, "BOTTOMLEFT", 0, -12)
  t.invites:SetPoint("RIGHT")
  t.invites:SetHeight(130)
  t.rankHead = UI.Heading(t, "Quién gana más")
  t.rankHead:SetPoint("TOPLEFT", t.invites, "BOTTOMLEFT", 0, -8)
  t.rankHead:SetPoint("RIGHT")
  t.rank = UI.Text(t, 12, C.text2, { wrap = true })
  t.rank:SetPoint("TOPLEFT", t.rankHead, "BOTTOMLEFT", 0, -6)
  t.rank:SetPoint("RIGHT")
  t.rank:SetSpacing(3)

  -- In a game: the scores, the felt with the dice, what this turn has, the steps and the buttons.
  local function side(anchorPoint, x)
    local name = UI.Text(t, 12, C.text, { font = BG.font.display })
    name:SetPoint(anchorPoint, t, anchorPoint, x, 0)
    local bar = UI.Bar(t)
    bar:SetHeight(6)
    bar:SetPoint("TOP" .. (anchorPoint == "TOPLEFT" and "LEFT" or "RIGHT"), name, "BOTTOM" .. (anchorPoint == "TOPLEFT" and "LEFT" or "RIGHT"), 0, -5)
    return name, bar
  end
  t.me, t.meBar = side("TOPLEFT", 0)
  t.them, t.themBar = side("TOPRIGHT", 0)
  t.me:SetPoint("RIGHT", t, "CENTER", -10, 0)
  t.them:SetPoint("LEFT", t, "CENTER", 10, 0)
  t.them:SetJustifyH("RIGHT")
  t.meBar:SetPoint("RIGHT", t, "CENTER", -10, 0)
  t.themBar:SetPoint("LEFT", t, "CENTER", 10, 0)

  t.felt = CreateFrame("Frame", nil, t)
  t.felt:SetPoint("TOPLEFT", t.meBar, "BOTTOMLEFT", 0, -10)
  t.felt:SetPoint("RIGHT", t, "RIGHT")
  t.felt:SetHeight(124)
  t.felt:SetClipsChildren(true)
  local wood = t.felt:CreateTexture(nil, "BACKGROUND", nil, -2)
  wood:SetColorTexture(WOOD[1], WOOD[2], WOOD[3], 1)
  wood:SetAllPoints()
  local cloth = t.felt:CreateTexture(nil, "BACKGROUND", nil, -1)
  cloth:SetColorTexture(FELT[1], FELT[2], FELT[3], 1)
  cloth:SetPoint("TOPLEFT", 5, -5)
  cloth:SetPoint("BOTTOMRIGHT", -5, 5)
  UI.Shade(t.felt, 0.0, 0.35, "BACKGROUND")
  t.banner = UI.Text(t.felt, 15, C.goldHi, { font = BG.font.display, justify = "CENTER" })
  t.banner:SetPoint("TOPLEFT", 10, -9)
  t.banner:SetPoint("TOPRIGHT", -10, -9)
  t.row = UI.DiceRow(t.felt, 6, DIE, GAP)
  t.dice = t.row.dice
  for i, d in ipairs(t.dice) do
    d:ClearAllPoints()
    d:SetPoint("CENTER", t.felt, "CENTER", d.bx, -10)
    d:SetScript("OnClick", function()
      local g = Bones.game
      if Bones.MyTurn(g) and g.phase == "keep" and not t.row:Busy() then
        f.keep[i] = not f.keep[i] or nil
        BG.Sound("U_CHAT_SCROLL_BUTTON")
        BG:RefreshView("arena")
      end
    end)
    d:SetScript("OnEnter", function(self)
      local g = Bones.game
      if GameTooltip and Bones.MyTurn(g) and g.phase == "keep" then
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:AddLine(self.look == "hint" and "Puntúa: púlsalo para guardarlo" or (self.look == "pick" and "Guardado: púlsalo otra vez para soltarlo" or "Este no puntúa solo"), 1, 1, 1)
        BG.ShowTip()
      end
    end)
    d:SetScript("OnLeave", function()
      if GameTooltip then
        GameTooltip:Hide()
      end
    end)
  end
  -- (the dice rest a little below the felt's middle: the banner has the top)
  local place = t.row.Place
  function t.row:Place(d, x, y)
    place(self, d, x, y - 10)
  end
  t.row.onLanded = function()
    t.landedAt = GetTime()
    BG:RefreshView("arena")
  end

  t.turn = UI.Text(t, 13, C.text, { wrap = true })
  t.turn:SetPoint("TOPLEFT", t.felt, "BOTTOMLEFT", 0, -8)
  t.turn:SetPoint("RIGHT", t, "RIGHT")
  t.trayLabel = UI.Text(t, 11, C.text3)
  t.trayLabel:SetPoint("TOPLEFT", t.turn, "BOTTOMLEFT", 0, -7)
  t.trayLabel:SetText("Guardados este turno:")
  t.tray = {}
  for i = 1, 6 do
    local d = UI.Die(t, 18)
    d:SetPoint("LEFT", t.trayLabel, "RIGHT", 8 + (i - 1) * 22, 0)
    d:EnableMouse(false)
    d:Hide()
    t.tray[i] = d
  end

  t.rules = UI.Button(t, "Cómo se juega", { height = 22, width = 120 })
  t.rules:SetPoint("TOPRIGHT", t.turn, "BOTTOMRIGHT", 0, -30)
  t.rules:SetScript("OnClick", BG.UI.BonesRules)
  t.steps = {}
  local STEPS = { "Tira los dados.", "Pulsa los que brillan para guardarlos.", "Tira los que quedan, o plántate y súmalo." }
  for i, text in ipairs(STEPS) do
    local s = UI.Text(t, 12, C.text3)
    s:SetPoint("TOPLEFT", i == 1 and t.trayLabel or t.steps[i - 1], "BOTTOMLEFT", 0, i == 1 and -12 or -4)
    s:SetPoint("RIGHT", t.rules, "LEFT", -8, 0)
    s.base = i .. ". " .. BG.T(text) -- (the screen is made in the player's language)
    s:SetText(s.base)
    t.steps[i] = s
  end
  t.warn = UI.Text(t, 11, C.text3, { wrap = true })
  t.warn:SetPoint("TOPLEFT", t.steps[3], "BOTTOMLEFT", 0, -6)
  t.warn:SetPoint("RIGHT", t, "RIGHT")
  t.warn:SetText("Si al tirar ningún dado puntúa: ¡huesos! Pierdes lo de este turno.")

  t.quit = UI.Button(t, "Salir", { height = 26, width = 76 })
  t.quit:SetPoint("BOTTOMRIGHT", t, "BOTTOMRIGHT", 0, 0)
  t.roll = UI.Button(t, "Tirar", { primary = true, height = 26 })
  t.roll:SetPoint("BOTTOMLEFT", t, "BOTTOMLEFT", 0, 0)
  t.roll:SetPoint("RIGHT", t, "BOTTOM", -44, 0)
  t.bank = UI.Button(t, "Plantarme", { height = 26 })
  t.bank:SetPoint("LEFT", t.roll, "RIGHT", 6, 0)
  t.bank:SetPoint("RIGHT", t.quit, "LEFT", -6, 0)
  t.roll:SetScript("OnClick", function()
    local g = Bones.game
    if g and g.phase == "over" then
      f.keep = {}
      if g.house then
        Bones.Practice()
      else
        Bones.game = nil
        BG:RefreshView("arena")
      end
      return
    end
    local ok, w
    if g and g.phase == "keep" then
      ok, w = Bones.Keep(keepList(f), false)
    else
      ok, w = Bones.Roll()
      if ok then
        t.row:Throw(nil, g.left) -- (the dice tumble until the game's /roll says what came out)
      end
    end
    if ok then
      f.keep = {}
    else
      BG:Notify("No se pudo", why(w), { kind = "warning" })
    end
    BG:RefreshView("arena")
  end)
  t.bank:SetScript("OnClick", function()
    local ok, w = Bones.Keep(keepList(f), true)
    if ok then
      f.keep = {}
      BG.Sound("LOOT_WINDOW_COIN_SOUND")
    else
      BG:Notify("No se pudo", why(w), { kind = "warning" })
    end
    BG:RefreshView("arena")
  end)
  t.quit:SetScript("OnClick", function()
    local g = Bones.game
    if g and g.phase ~= "over" and not g.house then
      UI.Dialog({ title = "¿Rendirte?", items = { "Si sales ahora, gana " .. g.players[3 - (Bones.MySeat(g) or 1)] .. "." },
        primary = { label = "Rendirme", fn = function()
          Bones.Quit()
        end }, secondary = { label = "Seguir jugando" } })
    else
      Bones.Quit()
    end
  end)
  t.log = UI.Text(t, 11, C.text3, { wrap = true })
  t.log:SetPoint("TOPLEFT", t.warn, "BOTTOMLEFT", 0, -6)
  t.log:SetPoint("RIGHT", t, "RIGHT")
  t.log:SetPoint("BOTTOM", t.roll, "TOP", 0, 8)
  t.log:SetJustifyV("TOP")

  -- The lottery (right).
  local l = CreateFrame("Frame", nil, right)
  l:SetPoint("TOPLEFT", right.head, "BOTTOMLEFT", 0, -8)
  l:SetPoint("BOTTOMRIGHT", -16, 16)
  l:Hide()
  f.lotto = l
  l.today = UI.Text(l, 12, C.text, { wrap = true })
  l.today:SetPoint("TOPLEFT")
  l.today:SetPoint("RIGHT")
  l.today:SetSpacing(3)
  l.number = UI.EditBox(l, { width = 80, maxLetters = 3, placeholder = "1-100" })
  l.number:SetPoint("TOPLEFT", l.today, "BOTTOMLEFT", 0, -10)
  l.take = UI.Button(l, "Coger boleto", { height = 26, width = 130, primary = true })
  l.take:SetPoint("LEFT", l.number, "RIGHT", 8, 0)
  l.take:SetScript("OnClick", function()
    local ok, w = Lotto.Take(l.number:GetText())
    if ok then
      l.number:SetText("")
    else
      BG:Notify("No se pudo", why(w), { kind = "warning" })
    end
    BG:RefreshView("arena")
  end)
  l.draw = UI.Button(l, "Sortear hoy", { height = 26 })
  l.draw:SetPoint("BOTTOMLEFT")
  l.draw:SetPoint("BOTTOMRIGHT")
  l.draw:SetScript("OnClick", function()
    local ok, w = Lotto.Draw()
    if not ok then
      BG:Notify("No se pudo sortear", why(w), { kind = "warning" })
    end
  end)
  l.history = UI.Text(l, 11, C.text3, { wrap = true })
  l.history:SetPoint("TOPLEFT", l.number, "BOTTOMLEFT", 0, -14)
  l.history:SetPoint("RIGHT")
  l.history:SetPoint("BOTTOM", l.draw, "TOP", 0, 10)
  l.history:SetJustifyV("TOP")
  l.history:SetSpacing(3)
end

function BG.UI.TavernRefresh(f, on)
  local t, l = f.tavern, f.lotto
  t:SetShown(on)
  l:SetShown(on)
  if not on then
    return
  end
  f.left.head:SetText("Huesos")
  f.right.head:SetText("Lotería de práctica")
  local g = Bones.game
  local playing = g ~= nil
  for _, w in ipairs({ t.intro, t.house, t.rules0, t.rival, t.invite, t.invites, t.rankHead, t.rank }) do
    w:SetShown(not playing)
  end
  for _, w in ipairs({ t.me, t.meBar, t.them, t.themBar, t.felt, t.turn, t.trayLabel, t.rules, t.warn, t.roll, t.bank, t.quit, t.log }) do
    w:SetShown(playing)
  end
  for _, s in ipairs(t.steps) do
    s:SetShown(playing)
  end
  if not playing then
    t.rival:SetOptions(BG.UI.BonesRivals()) -- (its label: the placeholder or whom you chose)
    t.invite:SetEnabled(true)
    t.invites:SetItems(Bones.Invites())
    local lines = {}
    for i, r in ipairs(Bones.Ranking(8)) do
      lines[#lines + 1] = i .. ". " .. r.name .. ": " .. r.wins .. (r.wins == 1 and " victoria" or " victorias") .. " (de " .. r.played .. ")"
    end
    t.rank:SetText(#lines > 0 and table.concat(lines, "\n") or "Aún nadie ha jugado una partida entre miembros. Las de práctica contra la casa no cuentan.")
    t.row:Show(nil)
    for _, d in ipairs(t.tray) do
      d:Hide()
    end
  else
    local seat = Bones.MySeat(g) or 1
    local other = g.players[3 - seat]
    local mine = Bones.MyTurn(g)
    t.me:SetText((g.turn == seat and g.phase ~= "over" and BG.colorize("» ", C.goldHi) or "") .. string.format("Tú: %s", BG.colorize(tostring(g.score[seat]), C.goldTitle)))
    t.them:SetText(other .. ": " .. BG.colorize(tostring(g.score[3 - seat]), C.goldTitle) .. (g.turn ~= seat and g.phase ~= "over" and BG.colorize(" «", C.goldHi) or ""))
    t.meBar:Set(math.min(1, g.score[seat] / Bones.TARGET), C.gold)
    t.themBar:Set(math.min(1, g.score[3 - seat] / Bones.TARGET), C.info)

    -- A new throw (ours, the rival's or the house's): the dice fall; ours were already tumbling.
    local lr = g.lastRoll
    if lr and lr.n ~= t.shownRoll then
      t.shownRoll = lr.n
      if GetTime() - (lr.at or 0) < 2 or t.row:Busy() then
        t.row:Land(lr.dice)
      else
        t.landedAt = lr.at -- (an old throw, as the table is made again: it shows still)
      end
    end
    if g.lastBank and g.lastBank.n ~= t.shownBank then
      t.shownBank, t.bankAt = g.lastBank.n, GetTime()
    end
    if (g.hotDice or 0) ~= (t.shownHot or 0) then
      t.shownHot, t.hotAt = g.hotDice or 0, GetTime()
    end

    -- The felt.
    local now = GetTime()
    local busy = t.row:Busy()
    local scorable = mine and g.phase == "keep" and Bones.Scorable(g.dice) or {}
    local farkle = lr and lr.farkle and lr.n == t.shownRoll and now - (t.landedAt or 0) < BANNER_FOR
    if not busy then
      if g.phase == "keep" and g.dice then
        t.row:Show(g.dice)
        for i, d in ipairs(t.dice) do
          if i <= #g.dice then
            local pick = f.keep[i] and mine
            d.lift = pick and 8 or 0
            d:SetLook(pick and "pick" or (scorable[i] and "hint" or (mine and "dim" or nil)))
            t.row:Place(d, 0, 0)
          end
        end
      elseif farkle then
        t.row:Show(lr.dice)
        for _, d in ipairs(t.dice) do
          d.lift = 0
          d:SetLook("dim")
        end
      else
        t.row:Show(nil)
      end
    end
    local banner = ""
    if g.phase == "over" then
      banner = BG.colorize(Names.IsMe(g.winner) and "¡Has ganado la partida!" or string.format("Gana %s", g.winner), C.goldHi)
    elseif busy then
      banner = BG.colorize(Bones.Rolling() and "Rodando…" or "", C.text2)
    elseif farkle then
      banner = BG.colorize(Names.IsMe(lr.who) and string.format("¡Huesos! Pierdes %d puntos.", lr.lost or 0)
        or string.format("¡Huesos! %s pierde %d puntos.", lr.who, lr.lost or 0), C.danger)
    elseif t.hotAt and now - t.hotAt < BANNER_FOR then
      banner = BG.colorize("¡Los seis guardados! Se tiran todos otra vez.", C.goldHi)
    elseif t.bankAt and now - t.bankAt < BANNER_FOR then
      banner = BG.colorize(string.format("+%d para %s", g.lastBank.pts, Names.IsMe(g.lastBank.who) and "ti" or g.lastBank.who), C.goldHi)
    elseif g.phase == "roll" then
      banner = BG.colorize(mine and string.format("Te toca: tira %d %s", g.left, g.left == 1 and "dado" or "dados") or string.format("Le toca a %s…", g.players[g.turn]), C.text2)
    end
    t.banner:SetText(banner)
    if banner ~= "" and (farkle or t.bankAt or t.hotAt) then
      C_Timer.After(BANNER_FOR + 0.1, function()
        BG:RefreshView("arena")
      end)
    end

    -- This turn: its points, what is picked now, and the dice kept aside.
    local sel = {}
    for i = 1, 6 do
      if f.keep[i] and g.dice and g.dice[i] then
        sel[#sel + 1] = g.dice[i]
      end
    end
    local selV = #sel > 0 and Bones.Score(sel) or nil
    if g.phase == "over" then
      t.turn:SetText(BG.colorize(Names.IsMe(g.winner) and "¡Has ganado!" or ("Gana " .. g.winner .. "."), C.gold))
    elseif mine and g.phase == "keep" then
      t.turn:SetText(string.format("Este turno: %s.", BG.colorize(tostring(g.pts), C.goldTitle)) .. " " .. (selV and BG.colorize(string.format("Los que guardas valen %d.", selV), C.success)
        or (#sel > 0 and BG.colorize("Esos no puntúan juntos.", C.warning) or "Pulsa los dados que brillan.")))
    elseif mine then
      t.turn:SetText(string.format("Este turno: %s.", BG.colorize(tostring(g.pts), C.goldTitle)) .. (g.pts > 0 and " Tira para sumar más." or ""))
    else
      t.turn:SetText(g.players[g.turn] .. " lleva " .. g.pts .. " este turno.")
    end
    local kept = g.kept or {}
    for i, d in ipairs(t.tray) do
      d:SetShown(kept[i] ~= nil and g.phase ~= "over")
      if kept[i] then
        d:SetFace(kept[i])
      end
    end
    t.trayLabel:SetShown(g.phase ~= "over" and #kept > 0)

    -- The steps, the current one lit.
    local step = (not mine or g.phase == "over") and 0 or (g.phase == "roll" and (g.pts > 0 and 3 or 1) or (selV and 3 or 2))
    for i, s in ipairs(t.steps) do
      s:SetText(i == step and BG.colorize("» " .. s.base, C.goldHi) or s.base)
    end

    -- The buttons.
    if g.phase == "over" then
      t.roll:SetText(g.house and "Otra partida" or "Cerrar")
      t.roll:SetEnabled(true)
      t.bank:Hide()
      t.quit:SetText("Salir")
    elseif g.phase == "keep" then
      local left = g.left - #sel
      t.roll:SetText(left > 0 and string.format("Guardar y tirar %d", left) or "Guardar y tirar los seis")
      t.roll:SetEnabled(mine and selV ~= nil and not busy)
      t.bank:Show()
      t.bank:SetText(selV and string.format("Plantarme (+%d)", g.pts + selV) or "Plantarme")
      t.bank:SetEnabled(mine and selV ~= nil and not busy)
      t.quit:SetText(g.house and "Salir" or "Rendirse")
    else
      t.roll:SetText(Bones.Rolling() and "Tirando…" or string.format("Tirar %d %s", g.left, g.left == 1 and "dado" or "dados"))
      t.roll:SetEnabled(mine and not Bones.Rolling() and not busy)
      t.bank:Hide()
      t.quit:SetText(g.house and "Salir" or "Rendirse")
    end
    t.log:SetText(g.log[1] and ("Lo último: " .. g.log[1]) or "")
  end

  -- The lottery
  local day = Lotto.Today()
  local drawn = Lotto.Drawn(day)
  local mine = Lotto.Mine(day)
  local players = Lotto.Players(day)
  local lines = {}
  if drawn then
    local w = Lotto.Winners(day)
    lines[#lines + 1] = "Hoy ha salido el " .. BG.colorize(tostring(drawn), C.gold) .. ". " .. (#w > 0 and ("Aciertan: " .. table.concat(w, ", ") .. ".") or "Nadie lo tenía.")
    lines[#lines + 1] = "Mañana hay boletos nuevos."
  else
    lines[#lines + 1] = "Cada día, hasta " .. Lotto.MAX_TICKETS .. " boletos gratis: un número del 1 al 100 cada uno. Un oficial sortea con /roll 1-100."
    lines[#lines + 1] = "Hoy juegan " .. #players .. (#players == 1 and " persona." or " personas.")
  end
  lines[#lines + 1] = #mine > 0 and ("Tus números de hoy: " .. table.concat(mine, ", ") .. ".") or (drawn and "" or "Aún no tienes boletos hoy.")
  l.today:SetText(table.concat(lines, "\n"))
  l.number:SetShown(not drawn and #mine < Lotto.MAX_TICKETS)
  l.take:SetShown(not drawn and #mine < Lotto.MAX_TICKETS)
  l.draw:SetShown(not drawn and Store.IsOrganiser(Names.Me() or ""))
  local hist = {}
  for _, h in ipairs(Lotto.History(5)) do
    if h.day ~= day then
      hist[#hist + 1] = h.day:sub(7, 8) .. "/" .. h.day:sub(5, 6) .. ": salió el " .. h.n .. (#h.winners > 0 and (", acertaron " .. table.concat(h.winners, ", ")) or ", sin aciertos")
    end
  end
  l.history:SetText(#hist > 0 and ("Días anteriores:\n" .. table.concat(hist, "\n")) or "")
end

BG:On("BG_BONES_CHANGED", function()
  BG:RefreshView("arena")
end)
BG:On("BG_LOTTO_CHANGED", function()
  BG:RefreshView("arena")
end)
