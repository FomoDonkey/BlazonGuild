-- Honores (entrega 11; Olympus' Honors.lua and HonorsNet.lua, MIT, our own implementation).
--
-- Titles a member earns by what the guild already records, worked out by each client from the shared records
-- (nothing new is sent): the best hunter («Se busca»), the top donor (Tesorería, only where the master lets the
-- members see the donors), the best crafter (orders delivered and confirmed), the best recruiter and the most raids
-- confirmed. Each one has its ranking (the first ten) in Rankings, and the first of each wears a golden crest on
-- their nameplate, portrait and chat (Marks.lua). (No "first to the top level": Peregrino, 2026-11-13, the game had
-- started long before the addon, so many were already at 60.)
local _, BG = ...
local Honors = {}
BG.Honors = Honors
local Store, Names = BG.Store, BG.Names

local DAYS = 90
local TOP = 10
Honors.TOP = TOP

local function guildData()
  local g = BG.Guild.Entry()
  return g
end

-- Raids: who was confirmed for each raid that started (kept here, as raids leave the shared records two days
-- after they start).
function Honors.NoteRaids()
  local g = guildData()
  if not g then
    return
  end
  g.attendance = g.attendance or {}
  local log, now = g.attendance, Store.Now()
  for _, r in ipairs(Store.List("raids")) do
    if not log[r.id] and r.d.start and r.d.start <= now and r.d.status ~= "CANCELLED" then
      local names = {}
      for _, s in ipairs(BG.Raids.Signups(r.id)) do
        if s.d.status == "CONFIRMED" then
          names[#names + 1] = s.d.name
        end
      end
      if #names > 0 then
        log[r.id] = { at = r.d.start, title = r.d.title, names = names }
      end
    end
  end
  for id, e in pairs(log) do
    if type(e) ~= "table" or (e.at or 0) < now - DAYS * 86400 then
      log[id] = nil
    end
  end
end

function Honors.Raiders(limit)
  local g = guildData()
  local count, order = {}, {}
  local since = Store.Now() - DAYS * 86400
  for _, e in pairs(g and g.attendance or {}) do
    if (e.at or 0) >= since then
      for _, n in ipairs(e.names or {}) do
        if not count[n] then
          count[n] = 0
          order[#order + 1] = n
        end
        count[n] = count[n] + 1
      end
    end
  end
  table.sort(order, function(a, b)
    if count[a] ~= count[b] then
      return count[a] > count[b]
    end
    return a < b
  end)
  local out = {}
  for i = 1, math.min(limit or 10, #order) do
    out[i] = { name = order[i], n = count[order[i]] }
  end
  return out
end

-- Categories ---------------------------------------------------------------------------------------------------------
local function plural(n, one, many)
  return n .. " " .. (n == 1 and one or many)
end

local DEFS = {
  { key = "hunter", title = "Mejor cazador", icon = "Interface\\Icons\\Ability_Hunter_SniperShot",
    how = "Puntos de «Se busca» en 90 días: cada baja de un buscado da su recompensa más 1.",
    top = function()
      local out = {}
      for i, h in ipairs(BG.Wanted.Hunters(TOP)) do
        out[i] = { name = h.name, text = plural(h.n, "punto", "puntos") .. ", " .. plural(h.kills, "baja", "bajas") }
      end
      return out
    end },
  { key = "arena", title = "Campeón de la Arena", icon = "Interface\\Icons\\Ability_DualWield",
    how = "La mejor puntuación de la Arena esta temporada, con 5 combates o más.",
    top = function()
      local out = {}
      for i, f in ipairs(BG.Arena.Build().ranked) do
        if i > TOP then
          break
        end
        out[i] = { name = f.name, text = f.rating .. " puntos" .. (f.tier and (", " .. f.tier.label:lower()) or "") }
      end
      return out
    end },
  { key = "donor", title = "Mayor donante", icon = "Interface\\Icons\\INV_Misc_Coin_01",
    how = "Oro dado a los tesoreros en 90 días (si el maestro deja ver los donantes).",
    top = function()
      if not BG.Treasury.Sees("rank") then
        return {}, "El maestro ha decidido no mostrar los donantes."
      end
      local out = {}
      for i, d in ipairs(BG.Treasury.Ranking(TOP)) do
        out[i] = { name = d.name, text = BG.Treasury.Money(d.c) }
      end
      return out
    end },
  { key = "crafter", title = "Mejor artesano", icon = "Interface\\Icons\\Trade_BlackSmithing",
    how = "Encargos entregados y confirmados en 90 días.",
    top = function()
      local out = {}
      for i, c in ipairs(BG.Crafts.Ranking(TOP)) do
        out[i] = { name = c.name, text = plural(c.n, "encargo", "encargos") }
      end
      return out
    end },
  { key = "recruiter", title = "Mejor reclutador", icon = "Interface\\Icons\\INV_Misc_GroupNeedMore",
    how = "Miembros nuevos que dicen que los trajo (180 días).",
    top = function()
      local out = {}
      for i, r in ipairs(BG.Recruit.Recruiters(TOP)) do
        out[i] = { name = r.name, text = plural(r.n, "miembro traído", "miembros traídos") }
      end
      return out
    end },
  { key = "raider", title = "Fiel a las raids", icon = "Interface\\Icons\\Achievement_Boss_Ragnaros",
    how = "Raids en las que estaba confirmado al empezar, en 90 días (las que ha visto este addon).",
    top = function()
      local out = {}
      for i, r in ipairs(Honors.Raiders(TOP)) do
        out[i] = { name = r.name, text = plural(r.n, "raid", "raids") }
      end
      return out
    end },
}
Honors.DEFS = DEFS

-- Every category with its ranking: { key, title, icon, how, top = { { name, text } x10 }, note }. Kept for half a
-- minute, or until a record changes (nameplates ask often).
local cache
function Honors.Invalidate()
  cache = nil
end

function Honors.Categories()
  if cache and GetTime() - cache.t < 30 then
    return cache.list
  end
  local list = {}
  for _, d in ipairs(DEFS) do
    local ok, top, note = pcall(d.top)
    list[#list + 1] = { key = d.key, title = d.title, icon = d.icon, how = d.how, top = ok and top or {}, note = note }
  end
  cache = { t = GetTime(), list = list }
  return list
end

-- The titles `name` holds now (the first of each ranking).
function Honors.Of(name)
  local short = Names.Short(name)
  local out = {}
  if not short then
    return out
  end
  for _, c in ipairs(Honors.Categories()) do
    if c.top[1] and Names.Same(c.top[1].name, short) then
      out[#out + 1] = c.title
    end
  end
  return out
end

function Honors.Honored(name)
  return #Honors.Of(name) > 0
end

BG:On("BG_STORE_CHANGED", function(name)
  if name == "raids" or name == "signups" then
    Honors.NoteRaids()
  end
  Honors.Invalidate()
  BG:Fire("BG_HONORS_CHANGED")
end)
BG:On("BG_CHRONICLE", function()
  Honors.Invalidate()
end)
BG:On("BG_WANTED_CHANGED", function()
  Honors.Invalidate()
end)
BG:On("BG_ARENA_CHANGED", function()
  Honors.Invalidate()
end)
BG:On("BG_ROSTER_UPDATED", function()
  Honors.NoteRaids()
end)
