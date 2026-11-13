-- People: each member's card (what they choose to tell: a few words about them, main role, when they play),
-- their characters, and who has been away for a while. Ideas from Olympus's PlayerProfile, ProfileEdit, Alts
-- and Members (MIT); our own implementation.
--
-- Alts are confirmed both ways, and without anyone typing anything: BlazonGuild's saved data is shared by
-- every character of one game account, so each character knows its siblings. Each character publishes the
-- list of its siblings in the guild; A and B show as the same person only if A lists B AND B lists A. Nobody
-- can attach their character to someone else's. Sharing the list is off until the player turns it on.
local _, BG = ...
local People = {}
BG.People = People
local Store, Names, Instances = BG.Store, BG.Names, BG.Instances
local str, int = BG.Raids.Clean, BG.Raids.Int

local PROFILE_TTL = 60 * 86400

BG.Consent.Register({ key = "alts", label = "Mostrar a tu hermandad qué personajes son tuyos" })

Store.Define("profiles", {
  ttl = PROFILE_TTL,
  can = function(author, r)
    return Names.Same(r.id, author)
  end,
  normalize = function(d)
    local chars = {}
    for i = 1, math.min(20, #(type(d.chars) == "table" and d.chars or {})) do
      local n = Names.Short(str(d.chars[i], 40))
      if n then
        chars[#chars + 1] = n
      end
    end
    return {
      bio = str(d.bio, 160), role = Instances.Role(d.role) and d.role or nil, hours = str(d.hours, 60),
      main = Names.Short(str(d.main, 40)), chars = chars,
    }
  end,
})

-- Characters of this game account in this guild (from the account-wide saved data).
function People.MyChars()
  local key = BG.Guild.info and BG.Guild.info.home
  local out = {}
  for _, c in pairs(BG.db.characterInfo or {}) do
    if c.key == key and c.name then
      out[#out + 1] = c.name
    end
  end
  table.sort(out)
  return out
end

function People.Profile(name)
  local short = Names.Short(name)
  local r = short and Store.Get("profiles", short)
  return r and not r.del and r or nil
end

-- Publishes (or refreshes) our card. Keeps what the player wrote; updates the character list.
function People.Publish(fields)
  local me = Names.Me()
  if not me or not BG.Consent.Accepted() then
    return nil, "consent"
  end
  local old = People.Profile(me)
  local d = {}
  for k, v in pairs(old and old.d or {}) do
    d[k] = v
  end
  for k, v in pairs(fields or {}) do
    if v == false then
      d[k] = nil
    else
      d[k] = v
    end
  end
  d.chars = BG.Consent.Line("alts") and People.MyChars() or {}
  return Store.Put("profiles", me, d)
end

-- The characters confirmed to be the same person as `name` (both lists name each other), itself included.
function People.Characters(name)
  local short = Names.Short(name)
  local p = People.Profile(short)
  local out = { short }
  if not p then
    return out
  end
  for _, other in ipairs(p.d.chars) do
    if other ~= short then
      local q = People.Profile(other)
      if q then
        for _, back in ipairs(q.d.chars) do
          if back == short then
            out[#out + 1] = other
            break
          end
        end
      end
    end
  end
  return out
end

-- The main of a person: what the card says if that character is confirmed, else the highest level one.
function People.Main(name)
  local chars = People.Characters(name)
  local p = People.Profile(name)
  if p and p.d.main then
    for _, c in ipairs(chars) do
      if c == p.d.main then
        return c
      end
    end
  end
  local best, bestLevel = Names.Short(name), -1
  for _, c in ipairs(chars) do
    local m = BG.Guild.Find(c)
    if m and m.level > bestLevel then
      best, bestLevel = c, m.level
    end
  end
  return best
end

-- How many people the guild is, each one once with their alts: characters whose cards name each other count
-- once, and so do the members of an alts rank ("Alter", "Alts"...) unless their card says they are a main.
function People.Census(members)
  members = members or BG.Guild.members or {}
  local seen, people, chars = {}, 0, 0
  for _, m in ipairs(members) do
    local short = Names.Short(m.name)
    if short then
      chars = chars + 1
      local p = People.Profile(short)
      local altRank = type(m.rank) == "string" and m.rank:lower():find("^alt") ~= nil and not (p and p.d.main == short)
      local main = People.Main(short)
      if not altRank and not seen[main] then
        seen[main] = true
        people = people + 1
      end
    end
  end
  return { people = people, chars = chars }
end

-- Members away for at least `days` days (offline, with a known last connection), longest first.
function People.Inactive(days)
  local out = {}
  for _, m in ipairs(BG.Guild.members) do
    if not m.online and m.lastOnlineDays and m.lastOnlineDays >= days then
      out[#out + 1] = m
    end
  end
  table.sort(out, function(a, b)
    return a.lastOnlineDays > b.lastOnlineDays
  end)
  return out
end

-- Pure: counts for the inactivity buckets shown to the leadership (7, 14 and 30 days).
function People.InactiveCounts(members)
  local c = { [7] = 0, [14] = 0, [30] = 0 }
  for _, m in ipairs(members) do
    if not m.online and m.lastOnlineDays then
      for _, d in ipairs({ 7, 14, 30 }) do
        if m.lastOnlineDays >= d then
          c[d] = c[d] + 1
        end
      end
    end
  end
  return c
end

-- Sends a fixed, polite whisper (the text is shown before the click). The game only lets addons send chat
-- inside a click, and opening the chat box from an addon would taint what the player types next (Olympus).
function People.SendWhisper(name, text)
  local target = Names.Tell(name)
  if not target or not text or not BG.InGame() then
    return false
  end
  local send = (C_ChatInfo and C_ChatInfo.SendChatMessage) or SendChatMessage
  local ok = pcall(send, text, "WHISPER", nil, target)
  return ok
end

-- Keep our card's character list current: after login, and whenever the sharing choice changes.
local function refresh()
  if BG.Consent.Accepted() and BG.Guild.info and not BG.Guild.fromCache then
    local me = Names.Me()
    local old = me and People.Profile(me)
    local want = BG.Consent.Line("alts") and People.MyChars() or {}
    local same = old and #old.d.chars == #want
    if same then
      for i, n in ipairs(want) do
        if old.d.chars[i] ~= n then
          same = false
        end
      end
    end
    if not same then
      People.Publish({})
    end
  end
end

local published = false
BG:On("BG_ROSTER_UPDATED", function()
  if not published and BG.Guild.info and not BG.Guild.fromCache then
    published = true
    C_Timer.After(15, refresh)
  end
end)
BG:On("BG_CONSENT_LINE", function(key)
  if key == "alts" then
    refresh()
  end
end)
BG:On("BG_CONSENT_CHANGED", function(on)
  if on then
    C_Timer.After(5, refresh)
  end
end)
