-- Languages (Peregrino, 2026-11-13: "todo en más idiomas, los principales de WoW"). Spanish is written in the code and
-- is the source; English, German, French, Italian, Portuguese and Russian come from Locales/*.lua, tables from the
-- Spanish text to its translation (tests/i18n-keys.mjs lists every text; tests/locales.mjs checks each language has
-- them all, with the same values in them).
-- Every text on screen is translated as it is shown (UI.Text's SetText, notices, dialogs, tooltips, chat lines of
-- the addon): a whole text first; then a template ("Ha matado a %s miembros", the code's own joins, with the values
-- in it translated too); then line by line, sentence by sentence, and a known ending or beginning ("3 miembros").
-- What is not found stays as it was (in Spanish): never an empty or broken text.
-- The language: the game's own (GetLocale), or the one chosen in Administración (/bg idioma); a change applies on
-- reloading the interface, as every screen is built in its language.
local _, BG = ...
local Loc = { lang = "es", cache = {}, cached = 0 }
BG.Locale = Loc
BG.Locales = BG.Locales or {}

local GAME = { esES = "es", esMX = "es", enUS = "en", enGB = "en", deDE = "de", frFR = "fr", itIT = "it", ptBR = "pt", ptPT = "pt", ruRU = "ru" }
Loc.LANGS = {
  { key = "auto", label = "Automático (el del juego)" },
  { key = "es", label = "Español" }, { key = "en", label = "English" }, { key = "de", label = "Deutsch" }, { key = "fr", label = "Français" },
  { key = "it", label = "Italiano" }, { key = "pt", label = "Português" }, { key = "ru", label = "Русский" },
}

local dict, templates, suffixes, prefixes = {}, {}, {}, {}
local formats = {} -- a template as written in the code ("Tablón de %s") -> its translation, for BG.TF

local function secret(v)
  return issecretvalue ~= nil and issecretvalue(v)
end

function Loc.GameLanguage()
  local ok, l = pcall(GetLocale)
  return ok and GAME[l] or "en"
end

-- A source template as an anchored pattern: %s, %d, %02d, %.1f... are values; %% is a percent sign. Also which values
-- come right after another one ("%s%s": adj[1]), where the split between them is only a guess, and which are someone's
-- own words, after a colon or in quotes ("Nota: %s", "«%s»": free[n]).
local MAGIC = "[%^%$%(%)%.%[%]%*%+%-%?]"
local function compile(key)
  local parts, n, i, adj, last, free = { "^" }, 0, 1, {}, -1, {}
  while i <= #key do
    local c = key:sub(i, i)
    if c == "%" then
      local spec = key:match("^%%[%-%d%.]*[sdfi]", i)
      if spec then
        parts[#parts + 1] = "(.-)"
        n = n + 1
        if last == i then
          adj[n - 1] = true
        end
        local before, after = key:sub(1, i - 1), key:sub(i + #spec)
        free[n] = before:find(":%s*$") or before:find("«$") or before:find("\"$") or after:find("^»") or after:find("^\"")
        i = i + #spec
        last = i
      else
        parts[#parts + 1] = "%%"
        i = i + ((key:sub(i + 1, i + 1) == "%") and 2 or 1)
      end
    else
      parts[#parts + 1] = c:find(MAGIC) and ("%" .. c) or c
      i = i + 1
    end
  end
  parts[#parts + 1] = "$"
  return table.concat(parts), n, adj, free
end

-- The translation's own template with the values: %s (and %d...) in order, %1$s... by number, %% a percent sign.
local function fill(target, caps)
  local out, n, i = {}, 0, 1
  while i <= #target do
    local c = target:sub(i, i)
    if c == "%" then
      local num, after = target:match("^%%(%d)%$[sd]()", i)
      local spec = not num and target:match("^%%[%-%d%.]*[sdfi]", i)
      if num then
        out[#out + 1] = caps[tonumber(num)] or ""
        i = after
      elseif spec then
        n = n + 1
        out[#out + 1] = caps[n] or ""
        i = i + #spec
      else
        out[#out + 1] = "%"
        i = i + ((target:sub(i + 1, i + 1) == "%") and 2 or 1)
      end
    else
      out[#out + 1] = c
      i = i + 1
    end
  end
  return table.concat(out)
end

-- Small Spanish words: a template made only of them ("%s de %s", " el %s") joins anything, so it is used only when
-- what it joins is translated too (never "Núcleo of Magma").
local JOINERS = { de = 1, del = 1, el = 1, la = 1, los = 1, las = 1, y = 1, o = 1, en = 1, a = 1, al = 1, con = 1, para = 1,
  por = 1, sin = 1, un = 1, una = 1, que = 1 }

-- A name, as it is in every language: each word starts with a capital letter or a digit ("El Peregrino", "C A Ñ A D A",
-- "Los Humedales", "Grupo 3").
-- Not with a number next to a word ("Ganaste 12" is the start of a sentence, not a name).
local function nameLike(s)
  local any, digits = false, false
  for w in s:gmatch("%S+") do
    local a, b = w:byte(1, 2)
    if (a >= 65 and a <= 90) or (a == 0xC3 and b and b >= 0x80 and b <= 0x9E) then
      any = true
    elseif w:find("^%d") then
      digits = true
    elseif w:find("[%a\128-\255]") then
      return false
    end
    if w:find(":$") then
      return false -- a label ("Dentro: El Peregrino")
    end
  end
  return any and not digits
end

-- Capital letters, also those with accents and the Cyrillic ones (the game's string.upper only knows A-Z). For plain
-- texts (labels), not ones with colours or icons in them.
function Loc.Upper(s)
  s = s:upper()
  s = s:gsub("\195([\160-\190])", function(c)
    if c ~= "\183" then
      return "\195" .. string.char(c:byte() - 32)
    end
  end)
  s = s:gsub("\208([\176-\191])", function(c)
    return "\208" .. string.char(c:byte() - 32)
  end)
  s = s:gsub("\209([\128-\143])", function(c)
    return "\208" .. string.char(c:byte() + 32)
  end)
  return (s:gsub("\209\145", "\208\129"))
end

-- The first letter as a capital ("domingo 15" -> "Domingo 15", "воскресенье" -> "Воскресенье").
function Loc.UpperFirst(s)
  local first = s:match("^[%z\1-\127\194-\244][\128-\191]*") or ""
  return Loc.Upper(first) .. s:sub(#first + 1)
end

-- Whether a text has words in it (not only numbers, signs, colours or icons).
local function wordy(s)
  return (s:gsub("|T.-|t", ""):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):find("%a")) ~= nil
end

local translate

-- The first template that fits with all its values translated (or numbers, or names), among the strong ones (with
-- words of their own) or the weak ones; and, for later, a strong one that is most of the text with a value it could
-- not translate left as it is (someone's own words: "Nota: Raid el viernes").
local function viaTemplates(s, depth, weak, multiline)
  local loose
  for _, t in ipairs(templates) do
    if #s >= t.min and t.weak == weak and (not multiline or t.nl) and (not t.need or s:find(t.need, 1, true)) then
      local caps = { s:match(t.pattern) }
      if caps[1] ~= nil then
        local outs, dones, trs = {}, {}, {}
        for k, v in ipairs(caps) do
          outs[k], dones[k], trs[k] = translate(v, depth + 1)
        end
        -- two values side by side: if the first split does not fit, another one where a piece starts (" ", ",", ".")
        for k in pairs(t.adj or {}) do
          if not (dones[k] and dones[k + 1]) then
            local both = caps[k] .. caps[k + 1]
            for p = 1, #both + 1 do
              if p == 1 or p == #both + 1 or both:find("^[,%.]%s", p) or both:find("^%s[%(%-]", p) then
                local a, da, ta = translate(both:sub(1, p - 1), depth + 1)
                local b, db, tb = translate(both:sub(p), depth + 1)
                if da and db then
                  caps[k], caps[k + 1] = both:sub(1, p - 1), both:sub(p)
                  outs[k], dones[k], trs[k], outs[k + 1], dones[k + 1], trs[k + 1] = a, da, ta, b, db, tb
                  break
                end
              end
            end
          end
        end
        local whole, translated, named = true, false, false
        for k, v in ipairs(caps) do
          whole = whole and dones[k]
          translated = translated or trs[k]
          named = named or (dones[k] and not trs[k] and wordy(v))
        end
        if whole and (not weak or translated or not named) then
          -- a value that took in a list the template does not have ("faltan 1 tanque, 2 de daño" in "%s de daño")
          local absorbed = false
          if not t.comma then
            for _, v in ipairs(caps) do
              absorbed = absorbed or v:find(", ", 1, true) ~= nil
            end
          end
          return fill(t.to, outs), nil, absorbed
        end
        caps = outs
        if not weak and not loose then
          local ok = true
          for k in ipairs(caps) do
            ok = ok and (dones[k] or t.free[k] ~= nil)
          end
          if ok then
            loose = fill(t.to, caps)
          end
        end
      end
    end
  end
  return nil, loose
end

-- A list ("En vivo, hace 25 s, 2 con BlazonGuild"), when every piece of it is translated (or a number, or a name).
local function viaCommas(s, depth)
  if not s:find(", ", 1, true) then
    return nil
  end
  local out, translated = {}, false
  for piece in (s .. ", "):gmatch("(.-), ") do
    local o, done, any = translate(piece, depth + 1)
    if not done then
      return nil
    end
    out[#out + 1] = o
    translated = translated or any
  end
  return translated and #out > 1 and table.concat(out, ", ") or nil
end

-- Each coloured piece and each plain piece on its own ("Miembro|cff..  (tú)|r").
local function viaColours(s, depth)
  local out, whole, translated, i = {}, true, false, 1
  local function piece(text)
    local o, done, tr = translate(text, depth + 1)
    whole, translated = whole and done, translated or tr
    return o
  end
  while i <= #s do
    local a, b, code, inner = s:find("(|c%x%x%x%x%x%x%x%x)(.-)|r", i)
    if not a then
      out[#out + 1] = piece(s:sub(i))
      break
    end
    if a > i then
      out[#out + 1] = piece(s:sub(i, a - 1))
    end
    out[#out + 1] = code .. piece(inner) .. "|r"
    i = b + 1
  end
  return table.concat(out), whole, translated
end

-- The text in the language, whether all of it is (translated, or numbers and names), and whether anything was
-- translated. A text is cut only where that is safe (lines, sentences, colours); a template or a known ending is used
-- only when all of it ends up translated: never half a sentence in each language.
local memo = {}

local function find(s, depth)
  local tr = dict[s]
  if tr then
    return tr, true, true
  end
  if depth > 6 then
    return s, false, false
  end
  -- coloured as a whole
  local pre, inner = s:match("^(|c%x%x%x%x%x%x%x%x)(.*)|r$")
  if pre and not inner:find("|r", 1, true) then
    local out, done, any = translate(inner, depth + 1)
    return pre .. out .. "|r", done, any
  end
  -- spaces around it stay around it ("   0/40 apuntados": not "записано    0/40"); every text written with spaces
  -- around it is also known without them
  local lead, core, trail = s:match("^(%s*)(.-)(%s*)$")
  if (lead ~= "" or trail ~= "") and core ~= "" then
    local out, done, any = translate(core, depth + 1)
    return lead .. out .. trail, done, any
  end
  -- line by line (a template written with its own lines first)
  if s:find("\n", 1, true) then
    local t = viaTemplates(s, depth, false, true) or viaTemplates(s, depth, true, true)
    if t then
      return t, true, true
    end
    local out, whole, translated = {}, true, false
    for line in (s .. "\n"):gmatch("(.-)\n") do
      local o, done, any = translate(line, depth + 1)
      out[#out + 1] = o
      whole, translated = whole and done, translated or any
    end
    return table.concat(out, "\n"), whole, translated
  end
  local t, loose, absorbed = viaTemplates(s, depth, false)
  if t then
    return absorbed and viaCommas(s, depth) or t, true, true
  end
  -- written with a capital where the text has none ("Faltan 1 tanque, 2 de daño", from "faltan %s"), but not a name
  -- ("El Peregrino" is not "el %s")
  local a = s:byte(1)
  local lower = a >= 65 and a <= 90 and not nameLike(s) and (string.char(a + 32) .. s:sub(2))
  if lower then
    local d = dict[lower]
    if not d then
      local _
      d, _, absorbed = viaTemplates(lower, depth, false)
      d = d and (absorbed and viaCommas(lower, depth) or d)
    end
    if d then
      return Loc.UpperFirst(d), true, true
    end
  end
  if s:find("|c%x%x%x%x%x%x%x%x") then
    return viaColours(s, depth)
  end
  -- sentence by sentence ("A. B.")
  if s:find("[%.!?] %S") then
    local out, rest, whole, translated = {}, s, true, false
    while true do
      local a, b = rest:match("^(.-[%.!?]) (%S.*)$")
      local o, done, any = translate(a or rest, depth + 1)
      out[#out + 1] = o
      whole, translated = whole and done, translated or any
      if not a then
        break
      end
      rest = b
    end
    if #out > 1 then
      return table.concat(out, " "), whole, translated
    end
  end
  local list = viaCommas(s, depth)
  if list then
    return list, true, true
  end
  -- a final full stop or colon ("Gana Tarek.")
  local body, mark = s:match("^(.-)([%.:!?])$")
  if body and body ~= "" then
    local out, done, any = translate(body, depth + 1)
    if done and any then
      return out .. mark, true, true
    end
  end
  t = viaTemplates(s, depth, true)
  if t then
    return t, true, true
  end
  if loose then
    return loose, false, true
  end
  -- a known ending or beginning ("3 miembros", "nivel 24"), when the rest is translated too, or numbers; or a name, if
  -- the ending is a note on it ("El Peregrino (tú)", "Maestro: Tarek"); never "Ganaste 12 points"
  for _, f in ipairs(suffixes) do
    if #s > #f.from and s:sub(-#f.from) == f.from then
      local rest = s:sub(1, -#f.from - 1)
      local out, done, tr = translate(rest, depth + 1)
      if done and (tr or not wordy(rest) or f.note) then
        return out .. f.to, true, true
      end
    end
  end
  for _, f in ipairs(prefixes) do
    if #s > #f.from and s:sub(1, #f.from) == f.from then
      local rest = s:sub(#f.from + 1)
      local out, done, tr = translate(rest, depth + 1)
      if done and (tr or not wordy(rest) or f.note) then
        return f.to .. out, true, true
      end
    end
  end
  if lower then
    local out, done, any = translate(lower, depth + 1)
    if done and any then
      return Loc.UpperFirst(out), true, true
    end
  end
  if nameLike(s) then
    return s, true, false
  end
  return s, false, false
end

-- Work allowed for one text: someone's own long message, which is in no list, is given up on soon (as it is), not
-- tried in every way it could be cut.
local budget = 0

function translate(s, depth)
  if s == "" or not wordy(s) then
    return s, true, false
  end
  local m = memo[s]
  if not m then
    if budget <= 0 then
      return s, false, false
    end
    budget = budget - 1
    m = { find(s, depth) }
    if budget > 0 then
      memo[s] = m
    end
  end
  return m[1], m[2], m[3]
end

-- The text in the chosen language (the same text in Spanish, or when nothing is found).
function Loc.T(s)
  if Loc.lang == "es" or type(s) ~= "string" or s == "" or secret(s) then
    return s
  end
  local c = Loc.cache[s]
  if c then
    return c
  end
  budget = 120
  local out, done = translate(s, 0)
  if Loc.cached > 3000 then
    Loc.cache, Loc.cached, memo = {}, 0, {}
  end
  -- what is already in the language is not translated again (a text shown twice, a date inside another text)
  if done and out ~= s and memo[out] == nil then
    memo[out] = { out, true, true }
  end
  Loc.cache[s] = out
  Loc.cached = Loc.cached + 1
  return out
end
BG.T = Loc.T

-- Formats a text in the chosen language: BG.TF("Ha matado a %s miembros", n).
-- The template itself is looked up first: the values go into the translated one as they are (a guild called
-- «Heralds of Dawn» inside "Tablón de %s" made the whole text too doubtful to translate afterwards).
function BG.TF(fmt, ...)
  return string.format(Loc.lang ~= "es" and formats[fmt] or Loc.T(fmt), ...)
end

-- Builds the lookups for `lang` (exact texts, templates longest first, endings and beginnings).
function Loc.Use(lang)
  local data = BG.Locales[lang]
  if lang == "es" or not data then
    Loc.lang = "es"
    return
  end
  Loc.lang = lang
  dict, templates, suffixes, prefixes = {}, {}, {}, {}
  formats = {}
  Loc.cache, Loc.cached, memo = {}, 0, {}
  local strings = {}
  for from, to in pairs(data.strings or {}) do
    strings[from] = to
  end
  -- a text written with spaces around it ("Aún no hay escuadras. ", " Tú estás en %s%s.") is also found without them
  for from, to in pairs(data.strings or {}) do
    local core = type(to) == "string" and from:match("^%s*(.-)%s*$")
    if core and core ~= from and core ~= "" and strings[core] == nil then
      strings[core] = to:match("^%s*(.-)%s*$")
    end
  end
  for from, to in pairs(strings) do
    if type(to) == "string" and to ~= "" then
      local pattern, n, adj, free = compile(from)
      if n > 0 then
        formats[from] = to
        local literal = from:gsub("%%[%-%d%.]*[sdfi]", ""):gsub("%%%%", "%%")
        -- weak: it starts with a value and has only small words ("%s de %s"); one that starts with its own words
        -- (", en %s") only fits a text that starts that way
        local weak = from:find("^%%") ~= nil
        for w in literal:gmatch("[^%s%p%d]+") do
          weak = weak and JOINERS[w:lower()] ~= nil
        end
        -- its longest piece of its own, looked for first (fast) before trying the pattern
        local need = ""
        for piece in (from:gsub("%%%%", "\1") .. "%s"):gmatch("(.-)%%[%-%d%.]*[sdfi]") do
          piece = piece:gsub("\1", "%%")
          if #piece > #need then
            need = piece
          end
        end
        templates[#templates + 1] = { pattern = pattern, to = to, min = #literal, weight = #literal, weak = weak,
          nl = from:find("\n", 1, true) ~= nil, adj = next(adj) and adj or nil, free = free,
          comma = literal:find(", ", 1, true) ~= nil, need = #need >= 2 and need or nil }
      else
        local plain = from:gsub("%%%%", "%%")
        dict[plain] = to:gsub("%%%%", "%%")
        if plain:find("^[%s,%(%-]") and #plain > 2 then
          suffixes[#suffixes + 1] = { from = plain, to = dict[plain], note = plain:find("^%s*[%(%[%-]") ~= nil }
        elseif plain:find("%s$") and #plain > 2 then
          prefixes[#prefixes + 1] = { from = plain, to = dict[plain], note = plain:find("[:%-]%s+$") ~= nil }
        end
      end
    end
  end
  table.sort(templates, function(a, b)
    return a.weight > b.weight
  end)
  local longest = function(a, b)
    return #a.from > #b.from
  end
  table.sort(suffixes, longest)
  table.sort(prefixes, longest)
end

-- Dates in the chosen language ("domingo 15 de noviembre, 15:00").
function Loc.Date(d, withTime)
  local data = BG.Locales[Loc.lang]
  local f = data and data.date
  if not f then
    return nil
  end
  local s = f.format(f.days[d.wday], d.day, f.months[d.month])
  if withTime then
    s = s .. ", " .. string.format("%02d:%02d", d.hour, d.min)
  end
  memo[s] = memo[s] or { s, true, true }
  return s
end

-- At load (Init.lua, with the saved settings): the chosen language, or the game's; Russian needs the game's
-- Cyrillic fonts on a client of another language.
function Loc.Init()
  local pick = BG.db and BG.db.settings and BG.db.settings.lang or "auto"
  local lang = (pick ~= "auto" and pick) or Loc.GameLanguage()
  if lang ~= "es" and not BG.Locales[lang] then
    lang = BG.Locales.en and "en" or "es"
  end
  Loc.Use(lang)
  if Loc.lang == "ru" and GetLocale and GetLocale() ~= "ruRU" then
    -- only if this client has it (SetFont says so): a missing font would leave every text empty
    local CYR = "Fonts\\FRIZQT___CYR.TTF"
    local probe = Loc.probe or (UIParent and UIParent.CreateFontString and UIParent:CreateFontString())
    Loc.probe = probe
    local called, set = false, false
    if probe then
      called, set = pcall(probe.SetFont, probe, CYR, 12, "")
    end
    if called and set then
      BG.font.body, BG.font.display, BG.font.narrow = CYR, CYR, CYR
    end
  end
end

-- Once in the world, only the chosen language stays in memory (a change of language applies on reloading anyway):
-- the other five, and English when playing in Spanish, were near half of the addon's memory. The capture mode's
-- example guild keeps only the language it will be shown in (Core/Demo.lua: its own, or English).
function Loc.Trim()
  for key in pairs(BG.Locales) do
    if key ~= Loc.lang then
      BG.Locales[key] = nil
    end
  end
  local demo = BG.DemoData
  if demo then
    local keep = demo[Loc.lang] and Loc.lang or (demo.en and "en" or "es")
    for key in pairs(demo) do
      if key ~= keep then
        demo[key] = nil
      end
    end
  end
end
BG:On("PLAYER_ENTERING_WORLD", Loc.Trim)

function Loc.Choose(key)
  BG.db.settings.lang = key ~= "auto" and key or nil
  return true
end

-- Our tooltips: their lines in the chosen language (called before GameTooltip:Show by BG.ShowTip).
function BG.ShowTip()
  if Loc.lang ~= "es" and GameTooltip and GameTooltip.NumLines then
    for i = 1, GameTooltip:NumLines() do
      local fs = _G["GameTooltipTextLeft" .. i]
      if fs and fs.GetText then
        local t = fs:GetText()
        if t and not secret(t) then
          fs:SetText(Loc.T(t))
        end
      end
    end
  end
  GameTooltip:Show()
end

BG.commands = BG.commands or {}
BG.commands.idioma = function(arg)
  local want = arg and arg:lower():match("^%s*(%a+)")
  for _, l in ipairs(Loc.LANGS) do
    if want == l.key then
      Loc.Choose(l.key)
      BG:Print(BG.T("idioma elegido; se aplica al recargar la interfaz (/reload)."))
      return
    end
  end
  local keys = {}
  for _, l in ipairs(Loc.LANGS) do
    keys[#keys + 1] = l.key
  end
  BG:Print(BG.T("uso: /bg idioma") .. " " .. table.concat(keys, " | "))
end
