-- The Arena's extras (the rest of entrega 12; ideas of Olympus' Card.lua, ArenaSpectate.lua, ArenaChat.lua,
-- ArenaRoles.lua and Overlay.lua, MIT; our own implementation, without anything of their bets):
--   «Cara a cara»: two fighters side by side (rating, rank, record, streak, last five, the belt, their meetings), and,
--     while both are in sight of this client, their health live; the duel's result when the game says it. Nothing is
--     sent and nothing saved: it is what this client already knows and sees.
--   Arbiters: members the organisers name; they decide a tournament's bouts by hand and take a wrong duel out, as the
--     organisers do.
--   A chat room for each tournament or fight night for a week, in the Chat section.
local _, BG = ...
local Face = {}
BG.ArenaFace = Face
local Arena, Store, Names = BG.Arena, BG.Store, BG.Names
local str = BG.Raids.Clean

local function secret(v)
  return issecretvalue ~= nil and issecretvalue(v)
end

-- The two fighters ----------------------------------------------------------------------------------------------------
local function side(name)
  name = Names.Short(name)
  local b = Arena.Build()
  local f = b.fighters[name or ""]
  local m = BG.Guild.Find(name or "")
  return {
    name = name, classFile = m and m.classFile, level = m and m.level, rank = m and m.rank,
    rating = f and f.rating or Arena.R.START, place = f and f.place, tier = f and f.tier, wins = f and f.wins or 0, losses = f and f.losses or 0,
    streak = f and f.streak or 0, recent = f and f.recent or {}, champion = b.belt ~= nil and b.belt == name, fights = f and f.fights or 0,
  }
end

-- What the card shows: { a, b, meetings = { a = wins of a over b, b = ..., last = when } }.
function Face.Model(a, b)
  a, b = Names.Short(a), Names.Short(b)
  if not a or not b or a == b then
    return nil
  end
  local model = { a = side(a), b = side(b), meetings = { a = 0, b = 0 } }
  local since = Arena.Build().since
  for _, r in ipairs(Store.List("duels", function(x)
    return x.at >= since
  end)) do
    local w, l = r.d.w, r.d.l
    if (w == a and l == b) or (w == b and l == a) then
      local who = w == a and "a" or "b"
      model.meetings[who] = model.meetings[who] + 1
      if not model.meetings.last or r.at > model.meetings.last then
        model.meetings.last = r.at
      end
    end
  end
  return model
end

-- Where a fighter is in sight now: a unit token of this client (themselves, the target, focus, mouse, group,
-- nameplates), or nil.
local UNITS = { "player", "target", "focus", "mouseover", "targettarget" }
for i = 1, 4 do
  UNITS[#UNITS + 1] = "party" .. i
end
for i = 1, 40 do
  UNITS[#UNITS + 1] = "raid" .. i
end
for i = 1, 40 do
  UNITS[#UNITS + 1] = "nameplate" .. i
end

function Face.UnitOf(name)
  name = Names.Short(name)
  if not name then
    return nil
  end
  for _, u in ipairs(UNITS) do
    local okE, exists = pcall(UnitExists, u)
    if okE and exists and not secret(exists) then
      local n = Names.Unit(u)
      if n and Names.Same(n, name) then
        return u
      end
    end
  end
  return nil
end

-- Health of a unit as a share (0..1), or nil when the game keeps it from us.
function Face.Health(unit)
  if not unit or not UnitHealth or not UnitHealthMax then
    return nil
  end
  local ok, cur = pcall(UnitHealth, unit)
  local ok2, max = pcall(UnitHealthMax, unit)
  if not ok or not ok2 or secret(cur) or secret(max) or type(cur) ~= "number" or type(max) ~= "number" or max <= 0 then
    return nil
  end
  return math.max(0, math.min(1, cur / max))
end

-- «Ver el duelo» from the target: the player we target and the one they target.
function Face.PairFromTarget()
  local a = Names.Unit("target")
  local b = Names.Unit("targettarget")
  local okA, isA = pcall(UnitIsPlayer, "target")
  local okB, isB = pcall(UnitIsPlayer, "targettarget")
  if not (a and b and okA and okB and isA and isB) or Names.Same(a, b) then
    return nil
  end
  return a, b
end

-- The duel's end, read from the game's line (any duel in sight, not only ours): BG_FACE_RESULT(winner, loser, how).
BG:On("CHAT_MSG_SYSTEM", function(msg)
  local w, l, m = Arena.DuelResult(msg)
  if w then
    Face.lastResult = { w = w, l = l, m = m, at = GetTime() }
    BG:Fire("BG_FACE_RESULT", w, l, m)
  end
end)

-- Arbiters ----------------------------------------------------------------------------------------------------------
Store.Define("arbiters", {
  ttl = 3650 * 86400,
  can = function(author)
    return Store.IsOrganiser(author)
  end,
  normalize = function(d)
    local names = {}
    for i = 1, math.min(10, #(type(d.names) == "table" and d.names or {})) do
      local n = Names.Short(str(d.names[i], 40))
      if n and n ~= "" then
        names[#names + 1] = n
      end
    end
    return { names = names }
  end,
})

function Face.Arbiters()
  local r = Store.Get("arbiters", "list")
  return r and not r.del and r.d.names or {}
end

function Face.IsArbiter(name)
  for _, n in ipairs(Face.Arbiters()) do
    if Names.Same(n, name) then
      return true
    end
  end
  return false
end

-- Names someone arbiter, or takes them out if they already are (the organisers). Returns true and whether they are now.
function Face.ToggleArbiter(name)
  if not Store.IsOrganiser(Names.Me() or "") then
    return nil, "permiso"
  end
  local m = BG.Guild.Find(Names.Short(str(name, 40)) or "")
  if not m then
    return nil, "no es de la hermandad"
  end
  local short = Names.Short(m.name)
  local list, was = {}, false
  for _, n in ipairs(Face.Arbiters()) do
    if Names.Same(n, short) then
      was = true
    else
      list[#list + 1] = n
    end
  end
  if not was then
    if #list >= 10 then
      return nil, "lleno"
    end
    list[#list + 1] = short
  end
  local ok, why = Store.Put("arbiters", "list", { names = list })
  if not ok then
    return nil, why
  end
  BG:Fire("BG_ARENA_CHANGED")
  return true, not was
end

-- Arbiters decide bouts and take wrong duels out, as the organisers do.
local canManage = BG.Tourney.CanManage
BG.Tourney.CanManage = function(t)
  return canManage(t) or (t ~= nil and Face.IsArbiter(Names.Me() or ""))
end
local canRemove = Arena.CanRemove
Arena.CanRemove = function(r)
  return canRemove(r) or (r ~= nil and Face.IsArbiter(Names.Me() or ""))
end

-- A room for each tournament or fight night (Chat.lua lists them) ----------------------------------------------------
function Face.EventRooms()
  local out, now = {}, Store.Now()
  for _, t in ipairs(BG.Tourney.List()) do
    local live = t.d.state ~= "CANCELLED" and now - (t.d.created or t.at or 0) < 7 * 86400
    if live and (#t.id + 3) <= 40 then
      out[#out + 1] = { id = "ev-" .. t.id, name = string.format(t.d.kind == "NIGHT" and "Velada: %s" or "Torneo: %s", t.d.title),
        desc = "La sala de este evento de la Arena, para quien lucha y quien mira. Se cierra una semana después de crearlo.", event = t.id }
    end
  end
  return out
end

BG:On("BG_STORE_CHANGED", function(name)
  if name == "arbiters" then
    BG:Fire("BG_ARENA_CHANGED")
  end
end)
