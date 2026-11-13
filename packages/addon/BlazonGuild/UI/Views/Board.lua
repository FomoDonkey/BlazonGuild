-- Tablón: the guild's notice board. Announcements (with who has read them), the current poll with live
-- results, the week in numbers, the chronicle, the speaking queue and questions and answers. Organisers
-- also call to arms or to a meeting point from here.
local _, BG = ...
local UI, C = BG.UI, BG.color
local Board, Names, Store = BG.Board, BG.Names, BG.Store

local PAD = 22
local KIND_ICON = {
  join = "Interface\\Icons\\Spell_Holy_Resurrection", leave = "Interface\\Icons\\Spell_Shadow_Teleport",
  promote = "Interface\\Icons\\INV_Misc_Ribbon_01", demote = "Interface\\Icons\\INV_Misc_Ribbon_01",
  max = "Interface\\Icons\\Spell_Holy_SurgeOfLight", raid = "Interface\\Icons\\Achievement_Boss_Ragnaros",
  case = "Interface\\Icons\\Ability_Warrior_RallyingCry", news = "Interface\\Icons\\INV_Letter_15",
  decree = "Interface\\Icons\\Ability_Warrior_BattleShout",
}

local function minutesLeft(t)
  local s = t - Store.Now()
  if s <= 0 then
    return "cerrada"
  elseif s < 3600 then
    return "cierra en " .. math.ceil(s / 60) .. " min"
  end
  return "cierra en " .. math.floor(s / 3600) .. " h"
end

-- Small overlay form with labelled fields (used for announcements and polls).
local function overlay(f, title, height)
  local o = UI.Plate(f, { corners = 18, rail = 0.32 })
  o:SetFrameLevel(f:GetFrameLevel() + 25)
  o:SetSize(520, height)
  o:SetPoint("TOP", 0, -120)
  o:EnableMouse(true)
  o:Hide()
  o.head = UI.Heading(o, title)
  o.head:SetPoint("TOPLEFT", 18, -12)
  o.head:SetPoint("TOPRIGHT", -18, -12)
  o.y = -50
  function o:Field(label, maxLetters, placeholder)
    local l = UI.Text(self, 11, C.text3)
    l:SetPoint("TOPLEFT", 18, self.y)
    l:SetText(label)
    local e = UI.EditBox(self, { width = 484, maxLetters = maxLetters, placeholder = placeholder })
    e:SetPoint("TOPLEFT", 18, self.y - 16)
    self.y = self.y - 52
    return e
  end
  o.ok = UI.Button(o, "Publicar", { primary = true, height = 28, width = 130 })
  o.ok:SetPoint("BOTTOMRIGHT", -18, 14)
  o.cancel = UI.Button(o, "Cancelar", { height = 28, width = 100 })
  o.cancel:SetPoint("RIGHT", o.ok, "LEFT", -8, 0)
  o.cancel:SetScript("OnClick", function()
    o:Hide()
  end)
  o.error = UI.Text(o, 12, C.danger)
  o.error:SetPoint("BOTTOMLEFT", 18, 20)
  return o
end

BG:RegisterView("board", {
  Build = function(f, def)
    f.hero = UI.Hero(f, 104)
    f.hero:SetPoint("TOPLEFT")
    f.hero:SetPoint("TOPRIGHT")
    f.hero:SetIcon("Interface\\Icons\\INV_Misc_Note_06")
    f.arms = UI.Button(f.hero, "¡A las armas!", { primary = true, height = 26, width = 130 })
    f.arms:SetPoint("TOPRIGHT", -18, -16)
    f.rally = UI.Button(f.hero, "Reunión aquí", { height = 26, width = 120 })
    f.rally:SetPoint("RIGHT", f.arms, "LEFT", -8, 0)
    f.arms:SetScript("OnClick", function()
      Board.Decree("ARMS", "", false)
    end)
    f.rally:SetScript("OnClick", function()
      Board.Decree("RALLY", "", true)
    end)

    -- Left column: announcements and the poll
    local left = CreateFrame("Frame", nil, f)
    left:SetPoint("TOPLEFT", f.hero, "BOTTOMLEFT", PAD, -14)
    left:SetPoint("BOTTOM", 0, 16)
    f.left = left
    left.newsHead = UI.Heading(left, "Anuncios")
    left.newsHead:SetPoint("TOPLEFT")
    left.newsHead:SetPoint("TOPRIGHT")
    f.newNews = UI.Button(left, "Nuevo anuncio", { height = 22, width = 120 })
    f.newNews:SetPoint("RIGHT", left.newsHead, "RIGHT", 0, 2)
    f.news = UI.List(left, 62, function(list)
      local c = UI.Card(list)
      c.icon:SetTexture("Interface\\Icons\\INV_Letter_15")
      c:SetScript("OnClick", function(self)
        local n = self.news
        if not n then
          return
        end
        Board.MarkRead(n.id)
        local readers = Board.Readers(n.id)
        BG.UI.Dialog({
          title = n.d.title,
          items = { n.d.text and n.d.text ~= "" and n.d.text or "(sin más texto)",
            { note = "Publicado por " .. n.by .. ", " .. UI.FormatDate(n.at, true) .. ". Lo han leído " .. #readers .. (#readers > 0 and (": " .. table.concat(readers, ", ")) or "") .. "." } },
          primary = { label = "Entendido" },
        })
      end)
      return c
    end, function(c, n)
      c.news = n
      c:SetHeight(56)
      c.title:SetText(n.d.title)
      c.sub:SetText(n.d.text or "")
      local readers = #Board.Readers(n.id)
      local unread = not Board.HasRead(n.id)
      c.right:SetText(unread and BG.colorize("Nuevo", C.goldTitle) or "")
      c.right2:SetText("leído por " .. readers)
      local accent = n.d.important and C.danger or C.gold
      c.accent:SetColorTexture(accent[1], accent[2], accent[3], 0.9)
    end)
    f.news:SetPoint("TOPLEFT", left.newsHead, "BOTTOMLEFT", 0, -8)
    f.news:SetPoint("RIGHT")
    f.news:SetHeight(196)
    f.newsEmpty = UI.Text(left, 12, C.text3, { wrap = true })
    f.newsEmpty:SetPoint("TOPLEFT", f.news, "TOPLEFT", 4, -10)
    f.newsEmpty:SetPoint("RIGHT", -4, 0)

    left.pollHead = UI.Heading(left, "Encuesta")
    left.pollHead:SetPoint("TOPLEFT", f.news, "BOTTOMLEFT", 0, -10)
    left.pollHead:SetPoint("RIGHT")
    f.newPoll = UI.Button(left, "Preguntar a la hermandad", { height = 22, width = 180 })
    f.newPoll:SetPoint("RIGHT", left.pollHead, "RIGHT", 0, 2)
    local poll = CreateFrame("Frame", nil, left)
    poll:SetPoint("TOPLEFT", left.pollHead, "BOTTOMLEFT", 0, -8)
    poll:SetPoint("BOTTOMRIGHT")
    f.poll = poll
    poll.q = UI.Text(poll, 14, C.text, { font = BG.font.display, wrap = true })
    poll.q:SetPoint("TOPLEFT")
    poll.q:SetPoint("RIGHT", -120, 0)
    poll.when = UI.Text(poll, 11, C.text3, { justify = "RIGHT" })
    poll.when:SetPoint("TOPRIGHT")
    poll.rows = {}
    for i = 1, 6 do
      local r = CreateFrame("Button", nil, poll)
      r:SetHeight(24)
      r:SetPoint("TOPLEFT", 0, -28 - (i - 1) * 27)
      r:SetPoint("RIGHT")
      r.bar = UI.Bar(r)
      r.bar:SetPoint("LEFT", 150, 0)
      r.bar:SetPoint("RIGHT", -60, 0)
      r.label = UI.Text(r, 12, C.text)
      r.label:SetPoint("LEFT", 6, 0)
      r.label:SetWidth(140)
      r.count = UI.Text(r, 12, C.text2, { justify = "RIGHT" })
      r.count:SetPoint("RIGHT", -4, 0)
      local hl = r:CreateTexture(nil, "HIGHLIGHT")
      hl:SetColorTexture(C.gold[1], C.gold[2], C.gold[3], 0.08)
      hl:SetAllPoints()
      r:SetScript("OnClick", function(self)
        if f.currentPoll and f.currentPoll.d.closes > Store.Now() then
          Board.Vote(f.currentPoll.id, self.index)
          BG.Sound("IG_MAINMENU_OPTION_CHECKBOX_ON")
        end
      end)
      r.index = i
      poll.rows[i] = r
    end
    poll.close = UI.Button(poll, "Cerrar encuesta", { height = 22, width = 130 })
    poll.close:SetPoint("BOTTOMRIGHT")
    poll.close:SetScript("OnClick", function()
      if f.currentPoll then
        Board.ClosePoll(f.currentPoll.id)
      end
    end)
    poll.empty = UI.Text(poll, 12, C.text3, { wrap = true })
    poll.empty:SetPoint("TOPLEFT", 4, -6)
    poll.empty:SetPoint("RIGHT", -4, 0)

    -- Right column: the week, the chronicle, the court, questions
    local right = CreateFrame("Frame", nil, f)
    right:SetPoint("TOPLEFT", left, "TOPRIGHT", 22, 0)
    right:SetPoint("BOTTOMRIGHT", -PAD, 16)
    f.right = right
    right.weekHead = UI.Heading(right, "Esta semana")
    right.weekHead:SetPoint("TOPLEFT")
    right.weekHead:SetPoint("TOPRIGHT")
    f.week = UI.Text(right, 12, C.text, { wrap = true })
    f.week:SetPoint("TOPLEFT", right.weekHead, "BOTTOMLEFT", 0, -8)
    f.week:SetPoint("RIGHT")
    right.chronHead = UI.Heading(right, "Crónica")
    right.chronHead:SetPoint("TOPLEFT", f.week, "BOTTOMLEFT", 0, -12)
    right.chronHead:SetPoint("RIGHT")
    f.chron = UI.List(right, 24, function(list)
      local r = CreateFrame("Frame", nil, list)
      r.icon = r:CreateTexture(nil, "ARTWORK")
      r.icon:SetSize(16, 16)
      r.icon:SetPoint("LEFT", 2, 0)
      r.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
      r.when = UI.Text(r, 10, C.text3)
      r.when:SetPoint("LEFT", r.icon, "RIGHT", 6, 0)
      r.when:SetWidth(64)
      r.text = UI.Text(r, 12, C.text)
      r.text:SetPoint("LEFT", r.when, "RIGHT", 4, 0)
      r.text:SetPoint("RIGHT", -2, 0)
      return r
    end, function(r, e)
      r.icon:SetTexture(KIND_ICON[e.kind] or "Interface\\Icons\\INV_Misc_Note_01")
      r.when:SetText(date("%d/%m %H:%M", e.at))
      r.text:SetText(e.text)
    end)
    f.chron:SetPoint("TOPLEFT", right.chronHead, "BOTTOMLEFT", 0, -8)
    f.chron:SetPoint("RIGHT")
    f.chron:SetPoint("BOTTOM", 0, 92)
    f.chronEmpty = UI.Text(right, 12, C.text3, { wrap = true })
    f.chronEmpty:SetPoint("TOPLEFT", f.chron, "TOPLEFT", 4, -6)
    f.chronEmpty:SetPoint("RIGHT", -4, 0)

    local court = UI.Plate(right, { rail = 0.22 })
    court:SetPoint("BOTTOMLEFT", 0, 34)
    court:SetPoint("BOTTOMRIGHT", 0, 34)
    court:SetHeight(52)
    f.court = court
    court.text = UI.Text(court, 12, C.text, { wrap = true })
    court.text:SetPoint("LEFT", 12, 0)
    court.text:SetPoint("RIGHT", -150, 0)
    court.btn = UI.Button(court, "Pedir turno", { height = 24, width = 130 })
    court.btn:SetPoint("RIGHT", -10, 0)
    court.btn2 = UI.Button(court, "Siguiente", { height = 24, width = 90, primary = true })
    court.btn2:SetPoint("RIGHT", court.btn, "LEFT", -6, 0)
    f.faq = UI.Button(right, "Preguntas frecuentes", { height = 26, width = 170 })
    f.faq:SetPoint("BOTTOMLEFT")
    f.faq:SetScript("OnClick", function()
      local items = {}
      for _, q in ipairs(Board.Questions()) do
        items[#items + 1] = { bullet = q.q .. "  " .. BG.colorize(q.a or "", C.text2) }
      end
      BG.UI.Dialog({ title = "Preguntas frecuentes", items = items, primary = { label = "Cerrar" } })
    end)

    f:SetScript("OnSizeChanged", function(self, w)
      self.left:SetWidth(math.floor((w - PAD * 2 - 22) * 0.54))
    end)

    -- Forms
    f.newsForm = overlay(f, "Nuevo anuncio", 220)
    f.newsForm.title = f.newsForm:Field("Título", 80, "Por ejemplo: Raid de Onyxia este sábado")
    f.newsForm.text = f.newsForm:Field("Texto (opcional)", 600, "Lo que la hermandad debe saber")
    f.newsForm.important = UI.Segmented(f.newsForm, { { value = false, label = "Normal" }, { value = true, label = "Importante" } }, { itemWidth = 110 })
    f.newsForm.important:SetPoint("TOPLEFT", 18, f.newsForm.y + 4)
    f.newsForm.ok:SetScript("OnClick", function()
      local form = f.newsForm
      local r, why = Board.Post(form.title:GetText(), form.text:GetText(), form.important:GetValue() == true)
      if not r then
        form.error:SetText(why == "permiso" and "Solo los organizadores publican anuncios." or ("No se pudo (" .. tostring(why) .. ")."))
        return
      end
      form:Hide()
    end)
    f.pollForm = overlay(f, "Preguntar a la hermandad", 340)
    local pf = f.pollForm
    pf.q = pf:Field("Pregunta", 140, "Por ejemplo: ¿Qué banda hacemos el sábado?")
    pf.opts = {}
    for i = 1, 4 do
      local e = UI.EditBox(pf, { width = 236, maxLetters = 60, placeholder = "Opción " .. i .. (i > 2 and " (opcional)" or "") })
      e:SetPoint("TOPLEFT", 18 + ((i - 1) % 2) * 248, pf.y - math.floor((i - 1) / 2) * 34)
      pf.opts[i] = e
    end
    pf.y = pf.y - 76
    pf.minutes = UI.Picker(pf, { width = 200 })
    pf.minutes:SetPoint("TOPLEFT", 18, pf.y)
    pf.minutes:SetOptions({ { value = 15, label = "Abierta 15 minutos" }, { value = 60, label = "Abierta 1 hora" }, { value = 1440, label = "Abierta 1 día" }, { value = 4320, label = "Abierta 3 días" } })
    pf.minutes:SetValue(60, true)
    pf.ok.text:SetText("Preguntar")
    pf.ok:SetScript("OnClick", function()
      local options = {}
      for _, e in ipairs(pf.opts) do
        if e:GetText() ~= "" then
          options[#options + 1] = e:GetText()
        end
      end
      local r = Board.Ask(pf.q:GetText(), options, pf.minutes:GetValue())
      if not r then
        pf.error:SetText("Escribe la pregunta y al menos dos opciones.")
        return
      end
      pf:Hide()
    end)

    f.newNews:SetScript("OnClick", function()
      f.newsForm.title:SetText("")
      f.newsForm.text:SetText("")
      f.newsForm.important:SetValue(false, true)
      f.newsForm.error:SetText("")
      f.newsForm:Show()
    end)
    f.newPoll:SetScript("OnClick", function()
      pf.q:SetText("")
      for _, e in ipairs(pf.opts) do
        e:SetText("")
      end
      pf.error:SetText("")
      pf:Show()
    end)
    court.btn:SetScript("OnClick", function()
      local c = Board.Court()
      local organiser = Store.IsOrganiser(Names.Me())
      if organiser and not c then
        Board.OpenCourt("Turno de palabra")
      elseif organiser and c and court.btn.text:GetText() == "Cerrar turnos" then
        Board.CloseCourt()
      elseif BG.Store.Get("turns", Names.Me()) and not BG.Store.Get("turns", Names.Me()).del then
        Board.LeaveQueue()
      else
        Board.AskTurn("")
      end
    end)
    court.btn2:SetScript("OnClick", function()
      Board.NextSpeaker()
    end)
  end,

  Refresh = function(f)
    local info = BG.Guild.info
    local organiser = Store.IsOrganiser(Names.Me())
    local accepted = BG.Consent.Accepted()
    f.hero:SetArt(BG.art.BWL, 0.3)
    f.hero.title:SetText(info and BG.TF("Tablón de %s", info.name) or "Tablón")
    f.hero.sub:SetText(accepted and "Anuncios, encuestas y todo lo que pasa en la hermandad." or "Acepta la privacidad (/bg privacidad) para ver y publicar en el tablón.")
    f.arms:SetShown(organiser and accepted)
    f.rally:SetShown(organiser and accepted)
    f.newNews:SetShown(organiser and accepted)
    f.newPoll:SetShown(accepted)

    local news = Board.News()
    f.news:SetItems(news)
    f.newsEmpty:SetShown(#news == 0)
    f.newsEmpty:SetText(organiser and "Sin anuncios. Publica el primero: toda la hermandad lo verá y sabrás quién lo ha leído."
      or "Sin anuncios todavía. Los publican el maestro y los organizadores.")

    -- The poll shown: the newest open one, else the newest closed.
    local polls = Board.Polls()
    local p = polls[1]
    f.currentPoll = p
    local poll = f.poll
    poll.empty:SetShown(p == nil)
    poll.q:SetShown(p ~= nil)
    poll.when:SetShown(p ~= nil)
    poll.close:SetShown(p ~= nil and p.d.closes > Store.Now() and (organiser or Names.Same(p.by, Names.Me())))
    poll.empty:SetText("Ninguna encuesta abierta. Cualquiera puede preguntar a la hermandad: qué banda hacer, a qué hora quedar…")
    if p then
      local counts, total = Board.Results(p.id)
      local mine = Board.MyVote(p.id)
      local open = p.d.closes > Store.Now()
      poll.q:SetText(p.d.q)
      poll.when:SetText(minutesLeft(p.d.closes) .. ", " .. total .. (total == 1 and " voto" or " votos"))
      local top = 0
      for _, n in ipairs(counts) do
        top = math.max(top, n)
      end
      for i, r in ipairs(poll.rows) do
        local label = p.d.options[i]
        r:SetShown(label ~= nil)
        if label then
          r.label:SetText((mine == i and "|TInterface\\RaidFrame\\ReadyCheck-Ready:12:12:0:0|t " or "") .. label)
          r.count:SetText(counts[i])
          r.bar:Set(top > 0 and counts[i] / top or 0, (counts[i] == top and top > 0 and not open) and C.goldHi or C.gold)
          r:SetEnabled(open)
        end
      end
    else
      for _, r in ipairs(poll.rows) do
        r:Hide()
      end
    end

    -- The week and the chronicle
    local s = Board.WeekSummary(Board.Chronicle(7), BG.Raids.Upcoming())
    local parts = {}
    local function add(n, one, many)
      if n > 0 then
        parts[#parts + 1] = n .. " " .. (n == 1 and one or many)
      end
    end
    add(s.join, "entrada", "entradas")
    add(s.leave, "salida", "salidas")
    add(s.promote, "ascenso", "ascensos")
    add(s.max, "nuevo nivel 60", "nuevos nivel 60")
    add(s.raids, "raid", "raids")
    add(s.decree, "llamada a las armas", "llamadas a las armas")
    f.week:SetText(#parts > 0 and (table.concat(parts, ", ") .. ".") or "Semana tranquila por ahora: lo que pase aparecerá aquí.")
    local chron = Board.Chronicle()
    f.chron:SetItems(chron)
    f.chronEmpty:SetShown(#chron == 0)
    f.chronEmpty:SetText("La crónica empieza ahora: entradas, salidas, ascensos, raids y decisiones, según tu addon las ve.")

    -- Court
    local c = Board.Court()
    local q = Board.Queue()
    local court = f.court
    local inQueue = false
    for _, t in ipairs(q) do
      if Names.IsMe(t.id) then
        inQueue = true
      end
    end
    if c then
      court.text:SetText("Turnos de palabra abiertos" .. (c.d.speaker and (". Habla " .. BG.colorize(c.d.speaker, C.goldTitle)) or "") .. ". En cola: " .. #q .. ".")
      court.btn.text:SetText(organiser and "Cerrar turnos" or (inQueue and "Salir de la cola" or "Pedir turno"))
    else
      court.text:SetText("Turnos de palabra cerrados." .. (organiser and " Ábrelos para una reunión: cada uno pide turno y tú das la palabra." or ""))
      court.btn.text:SetText(organiser and "Abrir turnos" or "Pedir turno")
    end
    court.btn:SetShown(accepted and (organiser or c ~= nil))
    court.btn2:SetShown(organiser and c ~= nil)
    -- The text ends before whichever buttons show (it ran under «Siguiente»).
    court.text:SetPoint("RIGHT", court.btn2:IsShown() and court.btn2 or (court.btn:IsShown() and court.btn or court), court.btn:IsShown() and "LEFT" or "RIGHT", -10, 0)
  end,
})

BG:On("BG_STORE_CHANGED", function(name)
  if name == "news" or name == "seen" or name == "polls" or name == "votes" or name == "court" or name == "turns" or name == "faq" then
    BG:RefreshView("board")
  end
end)
BG:On("BG_CHRONICLE", function()
  BG:RefreshView("board")
end)
