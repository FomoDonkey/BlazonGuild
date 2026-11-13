-- BlazonGuildAPI: what other addons may read (entrega 13; the idea of Olympus' API.lua and Bridge*.lua, MIT; our own,
-- smaller). docs/API.md is its page for addon authors.
--   - Asked, one addon at a time: BlazonGuildAPI.Register("TheirAddon") gives that addon its handle, and the player is
--     asked once, in BlazonGuild's own dialog, whether «TheirAddon» may read; nothing comes back before a yes, nor after
--     a no. /bg api lists the addons and their answer; /bg api quitar TheirAddon takes a yes back.
--   - Read only, and only what this player already sees on BlazonGuild's own screens, no more detailed: the guild's
--     numbers, the player's own profile, the coming raids (counts by role, never who), the Arena's ranking, «Se busca»
--     and the honours. Never a whisper, a record, a key, a position, a moderation case or anything private; and the
--     getters change nothing and send nothing.
--   - Each answer is built field by field, so what BlazonGuild adds later never reaches an addon by itself.
--   - Events: handle:On("raids" | "arena" | "wanted" | "honors" | "guild", fn) calls fn() when that changes.
local _, BG = ...
local API = { VERSION = 1, handles = {}, pending = {} }
BG.API = API

local function answers()
  BG.db.apiAddons = BG.db.apiAddons or {}
  return BG.db.apiAddons
end

local function clean(s, max)
  return type(s) == "string" and s:gsub("[%c|]", ""):sub(1, max) or nil
end

local EVENTS = {
  raids = { "BG_STORE_CHANGED:raids", "BG_STORE_CHANGED:signups" }, arena = { "BG_ARENA_CHANGED" }, wanted = { "BG_WANTED_CHANGED" },
  honors = { "BG_HONORS_CHANGED" }, guild = { "BG_ROSTER_UPDATED", "BG_PEERS_CHANGED" },
}

local Handle = {}
Handle.__index = Handle

function Handle:Allowed()
  return answers()[self.name] == true and BG.Consent.Accepted()
end

-- Asks the player again (from a click of theirs in the other addon, for instance).
function Handle:Ask()
  API.Ask(self.name)
end

function Handle:GetGuild()
  if not self:Allowed() then
    return nil
  end
  local info = BG.Guild.info
  if not info then
    return { inGuild = false }
  end
  local online = 0
  for _, m in ipairs(BG.Guild.members or {}) do
    if m.online then
      online = online + 1
    end
  end
  return { inGuild = true, name = info.name, faction = info.faction, members = #(BG.Guild.members or {}), online = online,
    withAddon = #BG.Peers.Active() }
end

function Handle:GetMe()
  if not self:Allowed() then
    return nil
  end
  local me = BG.Guild.me
  if not me then
    return nil
  end
  local p = BG.People and BG.People.Profile(BG.Names.Me())
  return { name = BG.Names.Short(me.name), rank = me.rank, level = me.level, classFile = me.classFile, organiser = BG.Store.RealOrganiser(me.name),
    role = p and p.d and p.d.role or nil }
end

-- The coming raids: { title, instance, start (server time), state, going, maybe, tanks, healers, dps } (no names).
function Handle:GetRaids()
  if not self:Allowed() then
    return nil
  end
  local out = {}
  for _, r in ipairs(BG.Raids.Upcoming()) do
    local c = BG.Raids.Counts(r.id)
    out[#out + 1] = { title = clean(r.d.title, 80), instance = r.d.inst, start = r.d.start, state = r.d.status,
      going = c.confirmed, maybe = c.tentative, tanks = c.TANK, healers = c.HEALER, dps = c.DPS }
  end
  return out
end

-- The Arena's ranking of the season, as its screen shows it: { name, rating, place, tier, wins, losses, champion }.
function Handle:GetArena()
  if not self:Allowed() then
    return nil
  end
  local b = BG.Arena.Build()
  local out = {}
  for _, f in ipairs(b.list) do
    out[#out + 1] = { name = f.name, rating = f.rating, place = f.place, tier = f.tier and f.tier.key or nil, wins = f.wins, losses = f.losses,
      champion = b.belt == f.name }
  end
  return out
end

-- «Se busca», as its screen shows it: { name, classFile, bounty, deaths }.
function Handle:GetWanted()
  if not self:Allowed() then
    return nil
  end
  local out = {}
  for _, f in ipairs(BG.Wanted.Board()) do
    out[#out + 1] = { name = f.name, classFile = f.class, bounty = f.bounty, deaths = f.deaths }
  end
  return out
end

-- The honours: { key, title, holder } (the first of each ranking).
function Handle:GetHonors()
  if not self:Allowed() then
    return nil
  end
  local out = {}
  for _, h in ipairs(BG.Honors.Categories()) do
    local first = h.top and h.top[1]
    out[#out + 1] = { key = h.key, title = h.title, holder = first and (first.name or first[1]) or nil }
  end
  return out
end

function Handle:On(what, fn)
  if not EVENTS[what] or type(fn) ~= "function" then
    return false
  end
  self.listeners[what] = self.listeners[what] or {}
  table.insert(self.listeners[what], fn)
  return true
end

local function tell(what)
  for _, h in pairs(API.handles) do
    if h.listeners[what] and h:Allowed() then
      for _, fn in ipairs(h.listeners[what]) do
        pcall(fn)
      end
    end
  end
end
local byStore = {}
for what, events in pairs(EVENTS) do
  for _, e in ipairs(events) do
    local event, collection = e:match("^([^:]+):?(.*)$")
    if collection ~= "" then
      byStore[collection] = what
    else
      BG:On(event, function()
        tell(what)
      end)
    end
  end
end
BG:On("BG_STORE_CHANGED", function(name)
  if byStore[name] then
    tell(byStore[name])
  end
end)

-- The question, in BlazonGuild's own dialog (never the game's popups).
function API.Ask(name)
  if not (BG.UI and BG.UI.Dialog) then
    API.pending[name] = true
    return
  end
  BG.UI.Dialog({
    wait = true,
    title = string.format("«%s» quiere leer BlazonGuild", name),
    items = { "Podrá leer lo mismo que tú ves en BlazonGuild: las cifras de tu hermandad, tu ficha, las raids que vienen (sin nombres), la clasificación de la Arena, «Se busca» y los honores.",
      { bullet = "No puede enviar nada, ni cambiar nada, ni leer lo privado." },
      { note = "Puedes quitarle el permiso cuando quieras con /bg api." } },
    primary = { label = "Permitir", fn = function()
      answers()[name] = true
      BG:Print(string.format("«%s» puede leer BlazonGuild.", name))
    end },
    secondary = { label = "No", fn = function()
      answers()[name] = false
    end },
  })
end

BlazonGuildAPI = {
  VERSION = API.VERSION,
  -- The handle of addon `name` (the same each time it registers). Asks the player once, after the login.
  Register = function(name)
    name = clean(name, 40)
    if not name or name == "" then
      return nil, "nombre"
    end
    local h = API.handles[name]
    if not h then
      h = setmetatable({ name = name, listeners = {} }, Handle)
      API.handles[name] = h
    end
    if BG.db and answers()[name] == nil then
      API.pending[name] = true
    end
    return h
  end,
}

-- The questions wait for the login (and for the privacy page's answer).
local function askPending()
  if not (BG.db and BG.Consent.Accepted()) then
    return
  end
  for name in pairs(API.pending) do
    API.pending[name] = nil
    if answers()[name] == nil then
      API.Ask(name)
    end
  end
end
BG:On("PLAYER_LOGIN", function()
  for name in pairs(API.handles) do
    if answers()[name] == nil then
      API.pending[name] = true
    end
  end
  C_Timer.After(25, askPending)
end)
BG:On("BG_CONSENT_CHANGED", function()
  C_Timer.After(2, askPending)
end)

BG.commands = BG.commands or {}
BG.commands.api = function(arg)
  local a = answers()
  local verb, who = (arg or ""):match("^(%S+)%s+(.+)$")
  if verb == "quitar" and who then
    for name in pairs(a) do
      if name:lower() == who:lower() then
        a[name] = false
        BG:Print(string.format("«%s» ya no puede leer BlazonGuild.", name))
        return
      end
    end
    BG:Print(string.format("ningún addon se llama «%s».", who))
    return
  end
  local any = false
  for name, yes in pairs(a) do
    any = true
    BG:Print(string.format("«%s»: %s", name, yes and "puede leer BlazonGuild" or "sin permiso"))
  end
  if not any then
    BG:Print("ningún otro addon ha pedido leer BlazonGuild.")
  end
end
