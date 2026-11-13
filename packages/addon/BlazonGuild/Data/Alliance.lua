-- Hermandades hermanas: an alliance of guilds whose masters agree to join (ADR-017). What it gives: a shared
-- chat (the whole alliance, one tab per sister guild, the organisers of all, the masters of all), the role
-- rooms shared by everyone, and who is online in each guild.
--
-- How guilds talk (Olympus measured it on Forever, Relay.lua, MIT; our own implementation): an addon cannot
-- use a hidden chat channel there, but addon WHISPERs reach anyone by "First Surname" on any sub-realm. So
-- each guild's messenger (Peers.lua) keeps in touch with one member of every sister guild: a presence
-- message every two minutes says who is online (and is passed on to the whole guild), and a member who
-- writes in the alliance chat whispers the line to each sister guild's messenger, who passes it on to their
-- guild over GUILD.
--
-- Shared records: the alliance ("alliance"/"main": id, name, a shared key, the guilds with their contacts,
-- the invitations sent) in each guild's Store, so every member has it, also after logging in later; and the
-- invitations a guild received ("ainvites"), so its master sees them whenever they log in. Only the master
-- and the organisers write the alliance record; a change made by a sister guild (a guild joins or leaves) is
-- fetched by an organiser of ours when presence shows a newer version.
-- Trust: every message between guilds carries a tag made with the alliance key, which only the members of
-- its guilds have, so a stranger cannot write in the alliance. Every version of the alliance record is signed
-- (Sign.lua, ADR-020) by a key of the guild that made it, and the other guilds check the signature and what
-- that guild may change (AllianceRules.lua) before taking it: a member cannot forge it, whoever carries it.
local _, BG = ...
local Alliance = { presence = {} }
BG.Alliance = Alliance
local Store, Names, Comm, Peers, Rules, Sign = BG.Store, BG.Names, BG.Comm, BG.Peers, BG.AllianceRules, BG.Sign
local str, int = BG.Raids.Clean, BG.Raids.Int

local MAX_GUILDS = 10
local MAX_CONTACTS = 8
local MAX_ONLINE = 30
local MAX_INVITES = 10
local PRESENCE_EVERY = 120 -- the messenger tells each sister guild who is online
local PRESENCE_TTL = 330 -- a sister guild not heard for this long shows as "sin contacto"
local ANSWER_WAIT = 25 -- no answer from a contact in this long: try the next one
local AWAY_FOR = 600 -- a contact the server said is not playing is tried last for this long
local INVITE_TTL = 7 * 86400
local TICK = 15
local MAX_SIGNERS = 6 -- keys that sign for a guild: its master's and its organisers'
local MAX_CARGOS = 12
Alliance.CARGOS = { cap = "Capitán", msg = "Mensajero" }

local seen = {} -- chat line ids already shown
local away = {} -- name -> GetTime() the server said they are not playing
local waiting = {} -- guild key -> { name, at }: our presence waits for an answer
local lastPresenceTo = {} -- guild key -> GetTime()
local askedDoc = {} -- guild key -> GetTime() we asked for their newer alliance record
local sentInvites = {} -- token -> { to, at, answered }
local inFlight = {} -- name -> { { kind, k, body, at } }: what we just whispered to a sister guild's contact
local heardRate = {}

local function myKey()
  return BG.Guild.info and BG.Guild.info.key or nil
end

-- Pure helpers -------------------------------------------------------------------------------------------
-- Two rolling hashes, 64 bits in hex. Not a signature: a tag only those who know the key can make.
function Alliance.Hash(s)
  local h1, h2 = 5381, 52711
  for i = 1, #s do
    local b = s:byte(i)
    h1 = (h1 * 33 + b) % 4294967296
    h2 = (h2 * 131 + b * 7 + i) % 2147483647
  end
  return string.format("%08x%08x", h1, h2)
end

local function keyOf(v)
  if type(v) == "string" and #v > 0 and #v <= 80 and not v:find("%c") then
    return v
  end
  return nil
end

local function token(v, max)
  if type(v) == "string" and #v > 0 and #v <= (max or 16) and v:match("^%w+$") then
    return v
  end
  return nil
end

local ALPHABET = "abcdefghijkmnpqrstuvwxyz23456789"
function Alliance.RandomId(n)
  local t = {}
  for i = 1, n do
    local k = math.random(1, #ALPHABET)
    t[i] = ALPHABET:sub(k, k)
  end
  return table.concat(t)
end

local function guildEntry(g)
  if type(g) ~= "table" then
    return nil
  end
  local k, n = keyOf(g.k), str(g.n, 40)
  if not k or not n or n == "" then
    return nil
  end
  local c, have = {}, {}
  for i = 1, math.min(MAX_CONTACTS, #(type(g.c) == "table" and g.c or {})) do
    local name = Names.Short(str(g.c[i], 40))
    if name and name ~= "" and not have[name] then
      have[name] = true
      c[#c + 1] = name
    end
  end
  local pk = {}
  for i = 1, math.min(MAX_SIGNERS, #(type(g.pk) == "table" and g.pk or {})) do
    if Sign.IsKey(g.pk[i]) and not have[g.pk[i]] then
      have[g.pk[i]] = true
      pk[#pk + 1] = g.pk[i]
    end
  end
  local ks = type(g.ks) == "table" and Sign.IsSignature(g.ks.s) and Sign.IsKey(g.ks.p) and { s = g.ks.s, p = g.ks.p } or nil
  local r, named = {}, {}
  for i = 1, math.min(MAX_CARGOS, #(type(g.r) == "table" and g.r or {})) do
    local x = g.r[i]
    local name = type(x) == "table" and Names.Short(str(x.n, 40))
    if name and name ~= "" and Alliance.CARGOS[x.c] and not named[name] then
      named[name] = true
      r[#r + 1] = { n = name, c = x.c }
    end
  end
  local inv = {}
  for i = 1, math.min(MAX_INVITES, #(type(g.inv) == "table" and g.inv or {})) do
    local v = g.inv[i]
    if type(v) == "table" and token(v.t) then
      inv[#inv + 1] = { t = v.t, to = Names.Short(str(v.to, 40)), at = int(v.at, 0, 4e9) or 0, by = Names.Short(str(v.by, 40)) }
    end
  end
  local es = type(g.es) == "table" and Sign.IsSignature(g.es.s) and Sign.IsKey(g.es.p) and { s = g.es.s, p = g.es.p } or nil
  return { k = k, n = n, f = (g.f == "ALLIANCE" or g.f == "HORDE") and g.f or nil, m = Names.Short(str(g.m, 40)), c = c, at = int(g.at, 0, 4e9),
    pk = pk, ks = ks, r = r, vote = keyOf(g.vote), inv = inv, jt = token(g.jt), ev = int(g.ev, 0, 1e9) or 0, es = es }
end
Alliance.GuildEntry = guildEntry

-- Validates an alliance record's data (from the network or our own edits). Pure.
function Alliance.NormalizeDoc(d)
  if type(d) ~= "table" then
    return nil
  end
  local id, name, secret = token(d.id, 16), str(d.name, 40), token(d.key, 32)
  if not (id and name and name ~= "" and secret and #secret >= 8) then
    return nil
  end
  local guilds, have = {}, {}
  for i = 1, math.min(MAX_GUILDS, #(type(d.guilds) == "table" and d.guilds or {})) do
    local g = guildEntry(d.guilds[i])
    if g and not have[g.k] then
      have[g.k] = true
      guilds[#guilds + 1] = g
    end
  end
  if #guilds == 0 then
    return nil
  end
  local sig = type(d.sig) == "table" and Sign.IsSignature(d.sig.s) and Sign.IsKey(d.sig.p) and keyOf(d.sig.g) and { s = d.sig.s, p = d.sig.p, g = d.sig.g } or nil
  return { id = id, name = name, key = secret, v = int(d.v, 1, 1e9) or 1, founder = keyOf(d.founder), kr = d.kr == 1 and 1 or nil, guilds = guilds, sig = sig }
end

local function copyEntry(g)
  local c, pk, r, inv = {}, {}, {}, {}
  for j, n in ipairs(g.c or {}) do
    c[j] = n
  end
  for j, x in ipairs(g.pk or {}) do
    pk[j] = x
  end
  for j, x in ipairs(g.r or {}) do
    r[j] = { n = x.n, c = x.c }
  end
  for j, v in ipairs(g.inv or {}) do
    inv[j] = { t = v.t, to = v.to, at = v.at, by = v.by }
  end
  return { k = g.k, n = g.n, f = g.f, m = g.m, c = c, at = g.at, pk = pk, ks = g.ks and { s = g.ks.s, p = g.ks.p } or nil, r = r, vote = g.vote, inv = inv,
    jt = g.jt, ev = g.ev, es = g.es and { s = g.es.s, p = g.es.p } or nil }
end
Alliance.CopyEntry = copyEntry

local function copyDoc(d)
  local out = { id = d.id, name = d.name, key = d.key, v = d.v, founder = d.founder, kr = d.kr, guilds = {}, sig = d.sig and { s = d.sig.s, p = d.sig.p, g = d.sig.g } or nil }
  for i, g in ipairs(d.guilds) do
    out.guilds[i] = copyEntry(g)
  end
  return out
end
Alliance.CopyDoc = copyDoc

-- Shared records ---------------------------------------------------------------------------------------
Store.Define("alliance", {
  can = function(author)
    return Store.IsOrganiser(author) -- the master and the organisers; nobody else speaks for the guild
  end,
  normalize = function(d)
    return Alliance.NormalizeDoc(d)
  end,
})

Store.Define("ainvites", {
  ttl = INVITE_TTL,
  can = function(author, r, old)
    if Store.IsOrganiser(author) then
      return true
    end
    return old == nil and r.d ~= nil and Names.Same(r.d.via, author) -- whoever received it writes it down once
  end,
  normalize = function(d)
    local a, t, from = token(d.a), token(d.t), guildEntry(d.g)
    if not (a and t and from) then
      return nil
    end
    local st = (d.st == "ACCEPTED" or d.st == "DECLINED" or d.st == "DONE") and d.st or "OPEN"
    return { a = a, an = str(d.an, 40) or "", t = t, g = from, by = Names.Short(str(d.by, 40)), via = Names.Short(str(d.via, 40)), st = st }
  end,
})

-- The public keys our master and organisers sign with (each writes their own), so whoever certifies our
-- guild's list of signers can add them.
Store.Define("skeys", {
  can = function(author, r)
    return Names.Same(r.id, author)
  end,
  normalize = function(d)
    return Sign.IsKey(d.p) and { p = d.p } or nil
  end,
})

-- Reading -------------------------------------------------------------------------------------------------
function Alliance.Doc()
  local r = Store.Get("alliance", "main")
  return r and not r.del and r.d or nil
end

function Alliance.Tag(s)
  local d = Alliance.Doc()
  return d and Alliance.Hash(d.key .. "\031" .. s):sub(1, 12) or nil
end

function Alliance.Guild(k)
  local d = Alliance.Doc()
  for _, g in ipairs(d and d.guilds or {}) do
    if g.k == k then
      return g
    end
  end
  return nil
end

function Alliance.Member(k)
  return k ~= nil and Alliance.Guild(k) ~= nil
end

-- The leader's guild, and its master (the alliance's leader).
function Alliance.Lead()
  local d = Alliance.Doc()
  return d and Rules.Lead(d) or nil
end

function Alliance.LeaderGuild()
  return Alliance.Guild(Alliance.Lead())
end

function Alliance.AmLeaderGuild()
  return Alliance.Lead() ~= nil and Alliance.Lead() == myKey()
end

-- Cargos: what the master of guild `k` (ours by default) named `name`: "cap" (captain) or "msg" (messenger).
function Alliance.Cargo(name, k)
  local g = Alliance.Guild(k or myKey())
  local short = Names.Short(name)
  for _, r in ipairs(g and g.r or {}) do
    if r.n == short then
      return r.c
    end
  end
  return nil
end

function Alliance.Cargos(k, cargo)
  local g, out = Alliance.Guild(k or myKey()), {}
  for _, r in ipairs(g and g.r or {}) do
    if not cargo or r.c == cargo then
      out[#out + 1] = r.n
    end
  end
  return out
end

-- Who reads the organisers' tab of the alliance in our guild: the organisers and the captains.
function Alliance.ReadsOrg(name)
  return Store.IsOrganiser(name) or Alliance.Cargo(name) == "cap"
end

-- The public key a guildmate published (skeys), or nil.
function Alliance.PublishedKey(name)
  local short = Names.Short(name)
  if short and Names.IsMe(short) then
    return Sign.MyKey()
  end
  local r = short and Store.Get("skeys", short)
  return r and not r.del and r.d.p or nil
end

local function has(t, x)
  for _, v in ipairs(t or {}) do
    if v == x then
      return true
    end
  end
  return false
end
Alliance.Has = has

-- Can we sign for our guild (our key is in its list in the alliance record)?
function Alliance.CanSign()
  local g = Alliance.Guild(myKey())
  local pk = Sign.MyKey()
  return g ~= nil and pk ~= nil and has(g.pk, pk)
end

-- Hidden presence: an organiser may choose not to show up as connected to the other guilds.
function Alliance.IsHidden(name)
  if not name or Names.IsMe(name) then
    local me = Names.Me()
    return me ~= nil and BG.db.allyHidden ~= nil and BG.db.allyHidden[me] == true
  end
  local p = Peers.Get(name)
  return p ~= nil and p.hidden == true
end

-- The sister guilds (every guild of the alliance but ours), in the alliance's order.
function Alliance.Sisters()
  local d, mk, out = Alliance.Doc(), myKey(), {}
  for _, g in ipairs(d and d.guilds or {}) do
    if g.k ~= mk then
      out[#out + 1] = g
    end
  end
  return out
end

-- Short code of a guild for chat channel ids (no "|", ":" or spaces, which links and patterns use).
function Alliance.Code(k)
  return Alliance.Hash(k):sub(1, 8)
end

function Alliance.KeyOfCode(code)
  for _, g in ipairs(Alliance.Sisters()) do
    if Alliance.Code(g.k) == code then
      return g.k
    end
  end
  return nil
end

function Alliance.IsChannel(id)
  return id == "ally" or id == "allyorg" or id == "allymaster" or (type(id) == "string" and id:sub(1, 5) == "ally-")
end

local function builtinRoom(id)
  for _, room in ipairs(BG.Chat.builtin) do
    if room.id == id then
      return true
    end
  end
  return false
end

-- Whether a chat line in `channel` goes through the alliance (its own tabs, and the role rooms once there
-- are sister guilds to share them with).
Alliance.IsSharedRoom = builtinRoom

function Alliance.Handles(channel)
  if not Alliance.Doc() then
    return false
  end
  return Alliance.IsChannel(channel) or (builtinRoom(channel) and #Alliance.Sisters() > 0)
end

function Alliance.Presence(k)
  local p = Alliance.presence[k]
  if p and GetTime() - p.seen <= PRESENCE_TTL then
    return p
  end
  return nil
end

-- Who to whisper in guild `k`, best first: their messenger, who is online there, the names we keep, then
-- the record's contacts. Names the server said are not playing go last.
function Alliance.Contacts(k)
  local out, have, later = {}, {}, {}
  local t = GetTime()
  local function add(n)
    n = Names.Short(n)
    if not n or have[n] or Names.IsMe(n) then
      return
    end
    have[n] = true
    if away[n] and t - away[n] < AWAY_FOR then
      later[#later + 1] = n
    else
      out[#out + 1] = n
    end
  end
  local p = Alliance.Presence(k)
  for _, n in ipairs(Alliance.Cargos(k, "msg")) do
    local online = false
    for _, o in ipairs(p and p.on or {}) do
      if o.n == n then
        online = true
      end
    end
    if online or not p then
      add(n)
    end
  end
  if p then
    add(p.m)
    for _, o in ipairs(p.on) do
      if o.o then
        add(o.n)
      end
    end
    for _, o in ipairs(p.on) do
      add(o.n)
    end
  end
  local g = Alliance.Guild(k)
  local cache = BG.db.allyContacts and BG.db.allyContacts[k]
  for _, n in ipairs(cache or {}) do
    add(n)
  end
  if g then
    add(g.m)
    for _, n in ipairs(g.c) do
      add(n)
    end
  end
  for _, n in ipairs(later) do
    out[#out + 1] = n
  end
  return out, #later
end

-- The sister guild where `name` was last seen online (presence), or nil.
function Alliance.GuildOfName(name)
  local short = Names.Short(name)
  for _, g in ipairs(Alliance.Sisters()) do
    local p = Alliance.Presence(g.k)
    for _, o in ipairs(p and p.on or {}) do
      if o.n == short then
        return g
      end
    end
  end
  return nil
end

function Alliance.Target(k, organisers)
  local list = Alliance.Contacts(k)
  if organisers then
    local p = Alliance.Presence(k)
    local g = Alliance.Guild(k)
    local org = {}
    for _, o in ipairs(p and p.on or {}) do
      if o.o then
        org[o.n] = true
      end
    end
    if g and g.m then
      org[g.m] = true
    end
    for _, n in ipairs(list) do
      if org[n] and not (away[n] and GetTime() - away[n] < AWAY_FOR) then
        return n
      end
    end
  end
  return list[1]
end

-- Whispers `kind` to a contact of guild `k` and remembers it a moment: if the server says they are not
-- playing, it goes to the next contact (BG_WHISPER_OFFLINE below).
local function whisperGuild(kind, body, k, opts)
  local target = Alliance.Target(k, opts and opts.organisers)
  if not target then
    return nil
  end
  if not Comm.Send(kind, body, "WHISPER", target, { lane = opts and opts.lane or "normal" }) then
    return nil
  end
  inFlight[target] = inFlight[target] or {}
  table.insert(inFlight[target], { kind = kind, k = k, body = body, at = GetTime(), organisers = opts and opts.organisers })
  return target
end
Alliance.WhisperGuild = whisperGuild

-- Our guild as the alliance record keeps it: name, faction, master and who to whisper (organisers first).
function Alliance.MyEntry()
  local info = BG.Guild.info
  if not info then
    return nil
  end
  local master
  for _, m in ipairs(BG.Guild.members) do
    if m.rankIndex == 0 then
      master = Names.Short(m.name)
    end
  end
  local c, have = {}, {}
  local function add(n)
    n = Names.Short(n)
    if n and not have[n] and #c < MAX_CONTACTS then
      have[n] = true
      c[#c + 1] = n
    end
  end
  local active = {}
  for _, p in ipairs(Peers.Active()) do
    if not p.hidden then
      active[#active + 1] = p
    end
  end
  for _, n in ipairs(Alliance.Cargos(info.key, "msg")) do
    if BG.Guild.Find(n) then
      add(n)
    end
  end
  if Store.IsOrganiser(Names.Me()) and not Alliance.IsHidden() then
    add(Names.Me())
  end
  for _, p in ipairs(active) do
    if Store.IsOrganiser(p.name) then
      add(p.name)
    end
  end
  add(master)
  for _, p in ipairs(active) do
    add(p.name)
  end
  return { k = info.key, n = info.name, f = info.faction, m = master, c = c, at = Store.Now() }
end

-- The keys that should sign for our guild: the master's first (the anchor), then the organisers' that are
-- published, highest rank first. `myPk` is ours, known before it is published.
function Alliance.WantedSigners(myPk)
  local out, have = {}, {}
  local function add(pk)
    if pk and not have[pk] and #out < MAX_SIGNERS then
      have[pk] = true
      out[#out + 1] = pk
    end
  end
  local orgs = {}
  for _, m in ipairs(BG.Guild.members) do
    local short = Names.Short(m.name)
    if short and Store.IsOrganiser(short) then
      orgs[#orgs + 1] = { n = short, r = m.rankIndex, pk = Names.IsMe(short) and myPk or Alliance.PublishedKey(short) }
    end
  end
  table.sort(orgs, function(a, b)
    if a.r ~= b.r then
      return a.r < b.r
    end
    return a.n < b.n
  end)
  for _, o in ipairs(orgs) do
    add(o.pk)
  end
  return out
end

-- Totals for the alliance's header: guilds, members and online (ours live, the others from presence).
function Alliance.Census()
  local s = BG.Guild.stats
  local mine = BG.People.Census()
  local out = { guilds = 1, members = s and s.total or 0, people = mine.people, online = s and s.online or 0, addon = #Peers.Active(), unknown = 0 }
  for _, g in ipairs(Alliance.Sisters()) do
    out.guilds = out.guilds + 1
    local p = Alliance.Presence(g.k)
    if p then
      out.members = out.members + p.tot
      out.people = out.people + (p.pp or p.tot)
      out.online = out.online + p.onl
      out.addon = out.addon + #p.on
    else
      out.unknown = out.unknown + 1
    end
  end
  return out
end

-- Last time we heard each sister guild (kept across sessions, for "último contacto hace…").
local function seenEntry()
  local g = BG.Guild.Entry()
  if g then
    g.allySeen = g.allySeen or {}
    return g.allySeen
  end
  return {}
end

function Alliance.LastSeen(k)
  local p = Alliance.Presence(k)
  if p then
    return Store.Now(), p
  end
  local s = seenEntry()[k]
  return s and s.at or nil, s
end

local function heard(k)
  waiting[k] = nil
end

-- Presence ----------------------------------------------------------------------------------------------
local function onlineList()
  local out = {}
  for _, p in ipairs(Peers.Active()) do
    local m = BG.Guild.Find(p.name)
    if not p.hidden and not (Names.IsMe(p.name) and Alliance.IsHidden()) then
      out[#out + 1] = { n = p.name, o = Alliance.ReadsOrg(p.name) and 1 or nil, M = (m and m.rankIndex == 0) and 1 or nil, c = m and m.classFile or nil, l = m and m.level or nil }
    end
    if #out >= MAX_ONLINE then
      break
    end
  end
  return out
end

local function presenceBody()
  local d, k = Alliance.Doc(), myKey()
  local s = BG.Guild.stats
  local now = Store.Now()
  return { a = d.id, v = d.v, e = Alliance.EntriesVersion(d), g = k, gn = BG.Guild.info.name, m = Alliance.Messenger(), on = onlineList(), tot = s and s.total or 0, onl = s and s.online or 0,
    pp = BG.People.Census().people, s = now, h = Alliance.Tag("AP" .. k .. now) }
end

function Alliance.SendPresence(k, target)
  if not (Alliance.Doc() and BG.Consent.Accepted() and BG.Guild.info) then
    return false
  end
  target = target or Alliance.Target(k)
  if not target then
    return false
  end
  lastPresenceTo[k] = GetTime()
  waiting[k] = { name = target, at = GetTime() }
  return Comm.Send("AP", presenceBody(), "WHISPER", target, { lane = "bulk", key = "AP:" .. k })
end

-- An organiser of ours fetches the alliance record when a sister guild has a newer one.
local function maybeAskDoc(k, v, from, e)
  local d = Alliance.Doc()
  if not d or not v or not Store.IsOrganiser(Names.Me()) then
    return
  end
  if v < d.v or (v == d.v and (e or 0) <= Alliance.EntriesVersion(d)) then
    return
  end
  if GetTime() - (askedDoc[k] or -math.huge) < 60 then
    return
  end
  askedDoc[k] = GetTime()
  Comm.Send("AD", { a = d.id, v = d.v, e = Alliance.EntriesVersion(d) }, "WHISPER", from or Alliance.Target(k), { lane = "normal" })
end

local function takePresence(sender, b)
  local d = Alliance.Doc()
  if not d or type(b) ~= "table" or b.a ~= d.id then
    return nil
  end
  local k = keyOf(b.g)
  if not k or k == myKey() or not Alliance.Member(k) then
    return nil
  end
  if b.h ~= Alliance.Tag("AP" .. k .. tostring(b.s)) then
    maybeAskDoc(k, int(b.v, 1, 1e9), sender, int(b.e, 0, 1e12)) -- a new key (theirs is newer): ask for the record
    return nil
  end
  local on = {}
  for i = 1, math.min(MAX_ONLINE, #(type(b.on) == "table" and b.on or {})) do
    local o = b.on[i]
    local n = type(o) == "table" and Names.Short(str(o.n, 40))
    if n and n ~= "" then
      on[#on + 1] = { n = n, o = o.o == 1 or o.M == 1 or nil, M = o.M == 1 or nil, c = str(o.c, 12), l = int(o.l, 1, 60) }
    end
  end
  local p = { seen = GetTime(), m = Names.Short(str(b.m, 40)), on = on, tot = int(b.tot, 0, 1000) or 0, onl = int(b.onl, 0, 1000) or 0, pp = int(b.pp, 0, 1000),
    v = int(b.v, 1, 1e9) or 1, e = int(b.e, 0, 1e12), gn = str(b.gn, 40) }
  Alliance.presence[k] = p
  local cache = {}
  for _, o in ipairs(on) do
    if #cache < MAX_CONTACTS then
      cache[#cache + 1] = o.n
    end
  end
  if #cache > 0 then
    BG.db.allyContacts = BG.db.allyContacts or {}
    BG.db.allyContacts[k] = cache
  end
  seenEntry()[k] = { at = Store.Now(), tot = p.tot, onl = p.onl, pp = p.pp, addon = #on }
  heard(k)
  maybeAskDoc(k, p.v, p.m or sender, p.e)
  BG:Fire("BG_ALLIANCE_CHANGED")
  return k
end

Comm.Register("AP", function(sender, b)
  local k = takePresence(sender, b)
  if not k then
    return
  end
  Comm.Send("AQ", b, "GUILD", nil, { lane = "bulk", key = "AQ:" .. k }) -- the whole guild learns it
  if GetTime() - (lastPresenceTo[k] or -math.huge) > 60 then
    Alliance.SendPresence(k, sender) -- and they learn ours
  end
end, { channels = { "WHISPER" }, maxBytes = 3000 })

Comm.Register("AQ", function(sender, b)
  takePresence(sender, b)
end, { maxBytes = 3000 })

-- The alliance record, between guilds -----------------------------------------------------------------------
-- Is `name` someone of a guild of the alliance (a contact the record keeps, or seen online in its presence)?
local function knownAlly(name)
  local short = Names.Short(name)
  for _, g in ipairs(Alliance.Sisters()) do
    if g.m == short or has(g.c, short) then
      return true
    end
    local cache = BG.db.allyContacts and BG.db.allyContacts[g.k]
    if has(cache, short) then
      return true
    end
  end
  return Alliance.GuildOfName(short) ~= nil
end

-- The sum of the guild entries' versions: it grows with every change of any guild's entry.
function Alliance.EntriesVersion(d)
  local n = 0
  for _, g in ipairs(d and d.guilds or {}) do
    n = n + (g.ev or 0)
  end
  return n
end

Comm.Register("AD", function(sender, b)
  local d = Alliance.Doc()
  if d and type(b) == "table" and b.a == d.id and knownAlly(sender)
    and ((tonumber(b.v) or 0) < d.v or (tonumber(b.e) or 0) < Alliance.EntriesVersion(d)) then
    Comm.Send("AU", { d = d }, "WHISPER", sender, { lane = "normal" })
  end
end, { channels = { "WHISPER" }, maxBytes = 80 })

-- Merges a record from a sister guild into ours: each guild's entry if it is newer and validly signed, and the
-- common part if it is the next valid one. done(merged or nil) once the signatures are checked.
function Alliance.Merge(mine, incoming, done)
  local myIndex, inIndex = Rules.Index(mine), Rules.Index(incoming)
  -- Entries: of the guilds in either record.
  local groups, candidates = {}, {}
  for k, e in pairs(inIndex) do
    local checks = Rules.EntryCheck(mine.id, e, myIndex[k])
    if checks then
      candidates[k] = e
      groups[#groups + 1] = { k = k, checks = checks }
    end
  end
  local good = {}
  local i = 0
  local function nextEntry()
    i = i + 1
    local grp = groups[i]
    if grp then
      return Sign.VerifyAll(grp.checks, function(ok)
        if ok then
          good[grp.k] = candidates[grp.k]
        end
        nextEntry()
      end)
    end
    -- The common part, with the entries now known to be good.
    local entries = {}
    for k, e in pairs(myIndex) do
      entries[k] = e
    end
    for k, e in pairs(good) do
      entries[k] = e
    end
    local coreChecks = Rules.CoreCheck(mine, incoming, entries)
    local function finish(coreOk)
      local base = coreOk and incoming or mine
      local out = { id = mine.id, name = base.name, key = base.key, founder = base.founder, kr = base.kr, v = base.v, sig = base.sig, guilds = {} }
      local changed = coreOk
      for _, g in ipairs(base.guilds) do
        local e = good[g.k] or myIndex[g.k]
        if not e then
          return done(nil) -- a guild that joins comes with its entry, checked above
        end
        if good[g.k] then
          changed = true
        end
        out.guilds[#out.guilds + 1] = copyEntry(e)
      end
      done(changed and out or nil)
    end
    if coreChecks then
      -- A new member's entry must be among the good ones.
      for k in pairs(inIndex) do
        if not myIndex[k] and not good[k] and has(Rules.Members(incoming), k) then
          return finish(false)
        end
      end
      Sign.VerifyAll(coreChecks, finish)
    else
      finish(false)
    end
  end
  nextEntry()
end

-- A sister guild sent us something older than ours: they get ours back, so both end up the same.
local gaveBack = {}
local function giveBack(name)
  local d = Alliance.Doc()
  if d and name and knownAlly(name) and GetTime() - (gaveBack[name] or -math.huge) > 60 then
    gaveBack[name] = GetTime()
    Comm.Send("AU", { d = d }, "WHISPER", name, { lane = "normal" })
  end
end

-- A newer record from a sister guild (an entry changed, a guild joined or left, a new key). Our master or an
-- organiser checks it before keeping it; anyone else passes it to them.
local function takeDoc(b, tries)
  local d = Alliance.Doc()
  if not d or type(b) ~= "table" then
    return false
  end
  local new = Alliance.NormalizeDoc(b.d)
  if not new or new.id ~= d.id then
    return false
  end
  local mine, newer, older = Rules.Index(d), new.v > d.v, new.v < d.v
  for _, g in ipairs(new.guilds) do
    local o = mine[g.k]
    if o and g.ev > o.ev then
      newer = true
    elseif o and g.ev < o.ev then
      older = true
    end
  end
  if not newer then
    return older and "older" or false -- nothing to take; maybe something to give back
  end
  if not Store.IsOrganiser(Names.Me()) then
    return "forward" -- only the master and organisers write it: our guild's organisers get it over GUILD
  end
  Alliance.Merge(d, new, function(merged)
    local cur = Alliance.Doc()
    if not merged or not cur then
      return
    end
    if cur.v ~= d.v or Alliance.EntriesVersion(cur) ~= Alliance.EntriesVersion(d) then
      if (tries or 0) < 2 then
        takeDoc(b, (tries or 0) + 1) -- ours changed meanwhile: merge into it
      end
      return
    end
    if older then
      giveBack(b.from)
    end
    if not Rules.Index(merged)[myKey()] then
      return -- we are not in it: only the leader's "out" message (AX) takes us out
    end
    Store.Put("alliance", "main", merged)
  end)
  return true
end

Comm.Register("AU", function(sender, b, dist)
  if type(b) == "table" then
    b.from = dist == "WHISPER" and sender or nil -- (who to give ours back to, if theirs was partly older)
  end
  local r = takeDoc(b)
  if r == "forward" and dist == "WHISPER" then
    b.from = nil
    Comm.Send("AU", b, "GUILD", nil, { lane = "normal" })
  elseif r == "older" and Store.IsOrganiser(Names.Me()) then
    giveBack(b.from)
  end
end, { channels = { "WHISPER", "GUILD" }, maxBytes = 6000 })

-- One guild's entry, changed by that guild (its contacts, signers, cargos, vote, invitations). Our master or
-- an organiser checks it and keeps it; anyone else passes it to them.
local function takeEntry(b, sender)
  local d = Alliance.Doc()
  if not d or type(b) ~= "table" or b.a ~= d.id then
    return false
  end
  local e = guildEntry(b.g)
  local o = e and Rules.Index(d)[e.k]
  if not o or e.k == myKey() then
    if e and not o and (tonumber(b.v) or 0) > d.v then
      maybeAskDoc(e.k, tonumber(b.v), sender, nil) -- a guild we do not know yet: the record is newer
    end
    return false
  end
  if e.ev <= o.ev then
    return false
  end
  if not Store.IsOrganiser(Names.Me()) then
    return "forward"
  end
  local checks = Rules.EntryCheck(d.id, e, o)
  if not checks then
    return false
  end
  Sign.VerifyAll(checks, function(good)
    local cur = Alliance.Doc()
    if not good or not cur or cur.id ~= d.id then
      return
    end
    local new = copyDoc(cur)
    for i, g in ipairs(new.guilds) do
      if g.k == e.k and e.ev > (g.ev or 0) then
        new.guilds[i] = e
        Store.Put("alliance", "main", new)
      end
    end
  end)
  return true
end

Comm.Register("AE", function(sender, b, dist)
  if takeEntry(b, dist == "WHISPER" and sender or nil) == "forward" and dist == "WHISPER" then
    Comm.Send("AE", b, "GUILD", nil, { lane = "normal" })
  end
end, { channels = { "WHISPER", "GUILD" }, maxBytes = 2400 })

local function tellSisters(doc, except)
  for _, g in ipairs(doc.guilds) do
    if g.k ~= myKey() and g.k ~= except then
      whisperGuild("AU", { d = doc }, g.k, { organisers = true })
    end
  end
end
Alliance.TellSisters = tellSisters

-- Signing --------------------------------------------------------------------------------------------------
-- Refreshes entry `e` (ours: contacts, master, signers) for record `id` and signs it with version `ev`. The
-- signer list's certificate is signed again when the list changes, if we may (the anchor keeps its list; a new
-- anchor needs a key the old list had). done(entry) or done(nil, why).
local function signEntry(id, cur, e, pk, done)
  local fresh = Alliance.MyEntry()
  if not fresh then
    return done(nil, "sin hermandad")
  end
  e.k, e.n, e.f, e.m, e.c = fresh.k, fresh.n, fresh.f, fresh.m, fresh.c
  e.at = cur and cur.at or e.at or fresh.at
  e.r, e.inv = e.r or {}, e.inv or {}
  e.ev = (cur and cur.ev or 0) + 1
  local function sign()
    if not has(e.pk, pk) then
      return done(nil, "firma")
    end
    Sign.Sign(Rules.EntrySigned(id, e), function(sig)
      if not sig then
        return done(nil, "firma")
      end
      e.es = { s = sig, p = pk }
      done(e)
    end)
  end
  local want = Alliance.WantedSigners(pk)
  if cur and (table.concat(cur.pk, ",") == table.concat(want, ",") or #want == 0) then
    e.pk, e.ks = cur.pk, cur.ks
    return sign()
  end
  local may
  if not cur then
    may = want[1] == pk
  elseif want[1] == cur.pk[1] then
    may = pk == cur.pk[1]
  else
    may = has(cur.pk, pk)
  end
  if not may then
    if not cur then
      return done(nil, "firma")
    end
    e.pk, e.ks = cur.pk, cur.ks
    return sign()
  end
  e.pk = want
  Sign.Sign(Rules.CertText(id, e), function(cs)
    if not cs then
      return done(nil, "firma")
    end
    e.ks = { s = cs, p = pk }
    sign()
  end)
end

-- Our entry for a new record `id` (we are joining): done(entry) or done(nil, why).
function Alliance.SignedEntry(id, extra, done)
  Sign.Ensure(function(pk)
    if not pk then
      return done(nil, "firma")
    end
    local e = {}
    for k, v in pairs(extra or {}) do
      e[k] = v
    end
    signEntry(id, nil, e, pk, done)
  end)
end

local function stored(new, after, fail, retry)
  local r, w = Store.Put("alliance", "main", new)
  if not r then
    return fail(w)
  end
  if after then
    after(r.d)
  end
end

-- Changes our own guild's entry: build(entry copy) changes it (or returns nil and why). It is signed and stored,
-- then after(doc); the sister guilds are told. Only our guild signs it: never clashes with theirs.
function Alliance.UpdateMine(build, after, fail, tries)
  fail = fail or function() end
  Sign.Ensure(function(pk)
    local d = Alliance.Doc()
    if not pk or not d then
      return fail(not d and "sin alianza" or "firma")
    end
    local slot
    for i, g in ipairs(d.guilds) do
      if g.k == myKey() then
        slot = i
      end
    end
    if not slot then
      return fail("sin alianza")
    end
    local cur = d.guilds[slot]
    local e, why = build(copyEntry(cur))
    if not e then
      return fail(why)
    end
    signEntry(d.id, cur, e, pk, function(entry, w)
      if not entry then
        return fail(w)
      end
      local now = Alliance.Doc()
      if not now or now.v ~= d.v or Alliance.EntriesVersion(now) ~= Alliance.EntriesVersion(d) then
        if (tries or 0) < 3 then
          return Alliance.UpdateMine(build, after, fail, (tries or 0) + 1) -- it changed meanwhile: again
        end
        return fail("ocupado")
      end
      local new = copyDoc(now)
      new.guilds[slot] = entry
      stored(new, function(doc)
        -- The sister guilds get only our entry (much smaller than the whole record).
        for _, g in ipairs(doc.guilds) do
          if g.k ~= myKey() then
            whisperGuild("AE", { a = doc.id, v = doc.v, g = entry }, g.k, { organisers = true })
          end
        end
        if after then
          after(doc)
        end
      end, fail)
    end)
  end)
  return true
end

-- Changes the common part (who is in, the key): build(copy of the record) changes it; it is signed by us and
-- stored, then after(doc) (the caller tells whom it must). Our own entry may change in the same step
-- (mine(entry), when we are founding the alliance).
function Alliance.CommitCore(build, after, fail, tries)
  fail = fail or function() end
  Sign.Ensure(function(pk)
    if not pk then
      return fail("firma")
    end
    local old = Alliance.Doc()
    local new, why = build(old and copyDoc(old) or nil)
    if not new then
      return fail(why)
    end
    new.v = (old and old.v or 0) + 1
    new.sig = nil
    local mk = myKey()
    local signer = Rules.Index(new)[mk] or Rules.Index(old)[mk]
    if not (signer and has(signer.pk, pk)) then
      return fail("firma")
    end
    Sign.Sign(Rules.CoreText(new), function(sig)
      if not sig then
        return fail("firma")
      end
      local now = Alliance.Doc()
      if (now and now.v or 0) ~= (old and old.v or 0) then
        if (tries or 0) < 3 then
          return Alliance.CommitCore(build, after, fail, (tries or 0) + 1)
        end
        return fail("ocupado")
      end
      new.sig = { s = sig, p = pk, g = mk }
      stored(new, after, fail)
    end)
  end)
  return true
end

-- Forming the alliance ----------------------------------------------------------------------------------------
local function isMaster()
  return Store.IsMaster(Names.Me())
end

-- Creates the alliance (the master). done(doc) once it is signed and stored, or done(nil, why).
function Alliance.Create(name, done)
  done = done or function() end
  name = str(name, 40)
  if not name or name == "" then
    return nil, "nombre"
  end
  if not isMaster() then
    return nil, "permiso"
  end
  if Alliance.Doc() then
    return nil, "ya"
  end
  if not Alliance.MyEntry() then
    return nil, "sin hermandad"
  end
  if not BG.Consent.Accepted() then
    return nil, "consent"
  end
  local id = Alliance.RandomId(8)
  Alliance.SignedEntry(id, nil, function(entry, w)
    if not entry then
      return done(nil, w)
    end
    Alliance.CommitCore(function()
      return { id = id, name = name, key = Alliance.RandomId(16), founder = entry.k, guilds = { entry } }
    end, done, function(why)
      done(nil, why)
    end)
  end)
  return true
end

-- The invitations our guild sent that are still open (not expired, nobody joined with them).
function Alliance.OpenInvites()
  local d, out = Alliance.Doc(), {}
  local mine = Alliance.Guild(myKey())
  local used = {}
  for _, g in ipairs(d and d.guilds or {}) do
    if g.jt then
      used[g.jt] = true
    end
  end
  for _, v in ipairs(mine and mine.inv or {}) do
    if not used[v.t] and Store.Now() - v.at < INVITE_TTL then
      out[#out + 1] = v
    end
  end
  return out
end

-- Invites the guild of `name` (a player with BlazonGuild in that guild). The master decides on each side.
-- done(token) once the invitation is in our entry and sent, or done(nil, why).
function Alliance.Invite(name, done)
  done = done or function() end
  name = Names.Short(str(name, 40))
  if not name or name == "" then
    return nil, "nombre"
  end
  if not isMaster() then
    return nil, "permiso"
  end
  local d = Alliance.Doc()
  if not d then
    return nil, "sin alianza"
  end
  if BG.Guild.Find(name) then
    return nil, "es de tu hermandad"
  end
  if #d.guilds >= MAX_GUILDS then
    return nil, "llena"
  end
  local t = Alliance.RandomId(10)
  return Alliance.UpdateMine(function(e)
    local now = Store.Now()
    local kept = {}
    for _, v in ipairs(e.inv) do
      if now - v.at < INVITE_TTL and not Names.Same(v.to, name) then
        kept[#kept + 1] = v
      end
    end
    while #kept >= MAX_INVITES do
      table.remove(kept, 1)
    end
    kept[#kept + 1] = { t = t, to = name, at = now, by = Names.Me() }
    e.inv = kept
    return e
  end, function(doc)
    sentInvites[t] = { to = name, at = GetTime() }
    Comm.Send("AI", { a = doc.id, an = doc.name, t = t, g = Alliance.MyEntry() }, "WHISPER", name, { lane = "alert" })
    done(t)
  end, function(why)
    done(nil, why)
  end)
end

local REPLY_TEXT = {
  stored = "Invitación entregada a %s. Ahora decide el maestro de su hermandad.",
  busy = "La hermandad de %s ya está en una alianza.",
  faction = "%s es de la otra facción: los addons no pueden hablarse entre facciones.",
  noguild = "%s no está en ninguna hermandad.",
  same = "%s es de tu misma hermandad.",
}

local invitedBy = {} -- name -> GetTime() of their last invitation to us
Comm.Register("AI", function(sender, b)
  if type(b) ~= "table" then
    return
  end
  -- anyone may invite us (that is how alliances start), but not over and over: one a minute from each
  -- player, and no more waiting than the master can read
  local at = GetTime()
  if invitedBy[sender] and at - invitedBy[sender] < 60 or #Store.List("ainvites") >= MAX_INVITES then
    return
  end
  invitedBy[sender] = at
  local a, t, from = token(b.a), token(b.t), guildEntry(b.g)
  if not (a and t and from) then
    return
  end
  local function reply(s)
    Comm.Send("AR", { t = t, s = s }, "WHISPER", sender, { lane = "alert" })
  end
  local info = BG.Guild.info
  if not info then
    return reply("noguild")
  end
  if from.k == info.key then
    return reply("same")
  end
  if from.f and info.faction and from.f ~= info.faction then
    return reply("faction")
  end
  if Alliance.Doc() then
    return reply("busy")
  end
  local ok = Store.Put("ainvites", t, { a = a, an = b.an, t = t, g = from, by = sender, via = Names.Me() }, { lane = "alert" })
  if ok then
    reply("stored")
    BG:Notify("Invitación a una alianza", from.n .. " invita a " .. info.name .. " a su alianza «" .. tostring(str(b.an, 40)) .. "». Lo decide vuestro maestro.",
      { kind = "info", view = "alliance", icon = "Interface\\Icons\\INV_BannerPVP_02" })
  end
end, { channels = { "WHISPER" }, maxBytes = 1200 })

Comm.Register("AR", function(sender, b)
  if type(b) ~= "table" or not sentInvites[b.t] then
    return
  end
  sentInvites[b.t].answered = true
  local text = REPLY_TEXT[b.s]
  if text then
    BG:Notify(b.s == "stored" and "Invitación entregada" or "No se pudo invitar", text:format(sender), { kind = b.s == "stored" and "success" or "warning", view = "alliance" })
  end
  BG:Fire("BG_ALLIANCE_CHANGED")
end, { channels = { "WHISPER" }, maxBytes = 80 })

function Alliance.Invitations()
  local list = Store.List("ainvites", function(r)
    return r.d.st == "OPEN" or r.d.st == "ACCEPTED"
  end)
  table.sort(list, function(a, b)
    return a.at > b.at
  end)
  return list
end

-- Who to tell that we accepted: the inviter, then their master and contacts.
local function inviterContacts(inv)
  local out, have = {}, {}
  for _, n in ipairs({ inv.d.by, inv.d.g.m, unpack(inv.d.g.c) }) do
    local s = Names.Short(n)
    if s and not have[s] then
      have[s] = true
      out[#out + 1] = s
    end
  end
  return out
end

local acceptTries = {} -- token -> { i = next contact, at }
local myEntries = {} -- invitation token -> our signed entry, made once per session
local function sendAccept(inv)
  local list = inviterContacts(inv)
  local state = acceptTries[inv.id] or { i = 0 }
  state.i = state.i % math.max(1, #list) + 1
  state.at = GetTime()
  acceptTries[inv.id] = state
  local target = list[state.i]
  local function send(entry)
    if target and entry then
      Comm.Send("AA", { t = inv.d.t, a = inv.d.a, g = entry }, "WHISPER", target, { lane = "alert" })
    end
  end
  if myEntries[inv.d.t] then
    send(myEntries[inv.d.t])
  else
    Alliance.SignedEntry(inv.d.a, { jt = inv.d.t }, function(entry)
      myEntries[inv.d.t] = entry
      send(entry)
    end)
  end
  return target
end

function Alliance.Accept(t)
  local inv = Store.Get("ainvites", t)
  if not inv or inv.del or (inv.d.st ~= "OPEN" and inv.d.st ~= "ACCEPTED") then
    return nil, "no existe"
  end
  if not isMaster() then
    return nil, "permiso"
  end
  if Alliance.Doc() then
    return nil, "ya"
  end
  local d = {}
  for k, v in pairs(inv.d) do
    d[k] = v
  end
  d.st = "ACCEPTED"
  local ok, why = Store.Put("ainvites", t, d, { lane = "alert" })
  if not ok then
    return nil, why
  end
  return sendAccept(Store.Get("ainvites", t)) or true
end

function Alliance.Decline(t)
  local inv = Store.Get("ainvites", t)
  if not inv or inv.del then
    return nil, "no existe"
  end
  local d = {}
  for k, v in pairs(inv.d) do
    d[k] = v
  end
  d.st = "DECLINED"
  return Store.Put("ainvites", t, d)
end

-- The inviting guild hears the yes: the guild joins the alliance, and gets the record back (with the key). Only
-- someone who signs for our guild can add it (the others' guilds check that signature).
local adding = {} -- token -> GetTime(): a guild being added
Comm.Register("AA", function(sender, b)
  local d = Alliance.Doc()
  if not d or type(b) ~= "table" or b.a ~= d.id or not Store.IsOrganiser(Names.Me()) or not Alliance.CanSign() then
    return
  end
  local g = guildEntry(b.g)
  if not g or g.k == myKey() or g.jt ~= b.t then
    return
  end
  local function welcome()
    local doc = Alliance.Doc()
    Comm.Send("AW", { t = b.t, d = doc }, "WHISPER", sender, { lane = "alert" })
    C_Timer.After(2, function()
      Alliance.SendPresence(g.k, sender)
    end)
  end
  if Alliance.Member(g.k) then
    return welcome() -- already in (they asked again): the record once more
  end
  local found = false
  for _, v in ipairs(Alliance.OpenInvites()) do
    if v.t == b.t then
      found = true
    end
  end
  if not found or #d.guilds >= MAX_GUILDS or (adding[b.t] and GetTime() - adding[b.t] < 20) then
    return
  end
  local checks = Rules.EntryCheck(d.id, g, nil)
  if not checks then
    return
  end
  adding[b.t] = GetTime()
  Sign.VerifyAll(checks, function(good)
    if not good then
      adding[b.t] = nil
      return
    end
    Alliance.CommitCore(function(new)
      if not new or Alliance.Member(g.k) then
        return nil, "ya"
      end
      new.guilds[#new.guilds + 1] = g -- (as they signed it: their own date of joining)
      return new
    end, function(doc)
      adding[b.t] = nil
      tellSisters(doc, g.k)
      BG:Notify("Nueva hermandad hermana", g.n .. " ha aceptado: entra en la alianza «" .. doc.name .. "».", { kind = "success", view = "alliance", sound = "LEVELUP" })
      welcome()
    end, function()
      adding[b.t] = nil
    end)
  end)
end, { channels = { "WHISPER" }, maxBytes = 1600 })

-- The accepting guild gets the alliance record: now it is in. It checks the record holds both guilds and that
-- the inviting guild signed it, with the invitation in its entry.
Comm.Register("AW", function(sender, b)
  if type(b) ~= "table" or Alliance.Doc() or not Store.IsOrganiser(Names.Me()) then
    return
  end
  local inv = Store.Get("ainvites", token(b.t) or "")
  if not inv or inv.del or inv.d.st ~= "ACCEPTED" then
    return
  end
  local doc = Alliance.NormalizeDoc(b.d)
  if not doc or doc.id ~= inv.d.a then
    return
  end
  local checks, why = Rules.CheckJoin(doc, doc.sig and doc.sig.g, myKey(), inv.d.t)
  if not checks then
    BG:Debug("alianza: registro de bienvenida rechazado (" .. tostring(why) .. ")")
    return
  end
  Sign.VerifyAll(checks, function(good)
    if not good then
      BG:Debug("alianza: firma de bienvenida que no cuadra")
    end
    if not good or Alliance.Doc() or not Store.Put("alliance", "main", doc) then
      return
    end
    local d = {}
    for k, v in pairs(inv.d) do
      d[k] = v
    end
    d.st = "DONE"
    Store.Put("ainvites", inv.id, d)
    acceptTries[inv.id] = nil
    BG:Notify("¡Ya sois hermanas!", BG.Guild.info.name .. " entra en la alianza «" .. doc.name .. "». Abre el chat para hablar con ellas.", { kind = "success", view = "alliance", sound = "LEVELUP" })
    for _, g in ipairs(Alliance.Sisters()) do
      Alliance.SendPresence(g.k, Names.Same(inv.d.g.k, g.k) and sender or nil)
    end
  end)
end, { channels = { "WHISPER" }, maxBytes = 6000 })

-- Leaving: only the master. The sister guilds get the record without us (it asks the leader's guild for a new
-- key, since we knew the old one); our guild's record goes. done(true) or done(nil, why).
function Alliance.Leave(done)
  done = done or function() end
  if not isMaster() then
    return nil, "permiso"
  end
  if not Alliance.Doc() then
    return nil, "sin alianza"
  end
  local mk = myKey()
  local function gone()
    wipe(Alliance.presence)
    Store.Delete("alliance", "main")
    done(true)
  end
  return Alliance.CommitCore(function(new)
    for i = #new.guilds, 1, -1 do
      if new.guilds[i].k == mk then
        table.remove(new.guilds, i)
      end
    end
    if #new.guilds == 0 then
      return nil, "última" -- the last guild: the record simply goes
    end
    new.kr = 1
    return new
  end, function(doc)
    tellSisters(doc)
    gone()
  end, function(why)
    if why == "última" then
      return gone()
    end
    done(nil, why)
  end)
end

-- Chat between guilds ---------------------------------------------------------------------------------------
-- Who reads the organisers' and the masters' tabs: they get each line straight by whisper.
function Alliance.Readers(r)
  local out, have = {}, {}
  local function add(n)
    if n and not have[n] and not Names.IsMe(n) then
      have[n] = true
      out[#out + 1] = n
    end
  end
  for _, p in ipairs(Peers.Active()) do
    local m = BG.Guild.Find(p.name)
    if (r == "allyorg" and Alliance.ReadsOrg(p.name)) or (r == "allymaster" and m and m.rankIndex == 0) then
      add(p.name)
    end
  end
  for _, g in ipairs(Alliance.Sisters()) do
    local p = Alliance.Presence(g.k)
    for _, o in ipairs(p and p.on or {}) do
      if (r == "allyorg" and o.o) or (r == "allymaster" and o.M) then
        add(o.n)
      end
    end
  end
  return out
end

local function addLine(ch, b, from, fromKey)
  local g = fromKey ~= myKey() and Alliance.Guild(fromKey) or nil
  BG.Chat.Add(ch, { at = Store.Now(), from = from, text = BG.Chat.Sanitize(b.t), id = b.i, class = str(b.c, 12), gk = g and g.k or nil, gn = g and g.n or nil })
end

local lineSeq = 0
-- Sends a line (already made safe by Chat.Send) to an alliance tab or a shared room. Returns true and how
-- many sister guilds or readers it went to, or false and a reason.
function Alliance.Send(channel, text)
  local d = Alliance.Doc()
  if not d then
    return false, "sin alianza"
  end
  local me, mk = Names.Me(), myKey()
  local r, to = channel, nil
  if channel:sub(1, 5) == "ally-" then
    r, to = "bi", Alliance.KeyOfCode(channel:sub(6))
    if not to then
      return false, "esa hermandad ya no está en la alianza"
    end
  end
  if r == "allyorg" and not Alliance.ReadsOrg(me) then
    return false, "solo para organizadores y capitanes"
  end
  if r == "allymaster" and not Store.IsMaster(me) then
    return false, "solo para maestros"
  end
  lineSeq = lineSeq + 1
  local id = me:gsub("%s", "") .. "-" .. Store.Now() .. "-" .. lineSeq
  local m = BG.Guild.me
  local body = { r = r, to = to, i = id, t = text, f = me, g = mk, c = m and m.classFile or nil, h = Alliance.Tag("AC" .. id) }
  local reached = 0
  if r == "allyorg" or r == "allymaster" then
    for _, name in ipairs(Alliance.Readers(r)) do
      if Comm.Send("AC", body, "WHISPER", name, { lane = "alert" }) then
        reached = reached + 1
      end
    end
  else
    local ok, why = Comm.Send("AC", body, "GUILD", nil, { lane = "alert" })
    if not ok then
      return false, why
    end
    for _, g in ipairs(d.guilds) do
      if g.k ~= mk and (not to or g.k == to) then
        if whisperGuild("AC", body, g.k, { lane = "alert" }) then
          reached = reached + 1
        end
      end
    end
  end
  seen[id] = true
  addLine(channel, body, me, mk)
  -- The same line as our own text in the alliance's channel too (AllianceHall.lua), for the guilds that hear it there.
  if (r == "ally" or builtinRoom(r)) and BG.AllianceHall then
    BG.AllianceHall.Send(body)
  end
  return true, reached
end

-- A line of the alliance's chat that reached us: by our guild, by whisper (a sister guild's author or messenger),
-- or as its author's own text in the alliance's channel ("CHANNEL", AllianceHall.lua).
local function takeLine(sender, b, dist)
  local d = Alliance.Doc()
  if not d or type(b) ~= "table" or type(b.i) ~= "string" or #b.i > 80 or type(b.t) ~= "string" or type(b.r) ~= "string" then
    return
  end
  if seen[b.i] or b.h ~= Alliance.Tag("AC" .. b.i) then
    return
  end
  local mk, fromKey = myKey(), keyOf(b.g)
  local from = Names.Short(str(b.f, 40))
  if not from or not fromKey or not Alliance.Member(fromKey) then
    return
  end
  if fromKey == mk and (not Names.Same(sender, from) or not BG.Guild.Find(from)) then
    return -- a guildmate's line comes from them, never from someone speaking for them
  end
  if dist == "WHISPER" and fromKey ~= mk and not Names.Same(sender, from) and not BG.Guild.Find(sender) then
    return -- a sister guild's line comes from its author, or from one of ours passing it on
  end
  if dist == "CHANNEL" and (not Names.Same(sender, from) or (b.r ~= "ally" and not builtinRoom(b.r))) then
    return -- in the channel, only its author's own lines of the common tab and the shared rooms
  end
  if BG.AllianceActs and BG.AllianceActs.IsHidden(from, fromKey) then
    seen[b.i] = true
    return -- hidden in the alliance's chats by its leader (AllianceActs.lua)
  end
  local r, ch = b.r, nil
  if r == "ally" then
    ch = r
  elseif r == "allyorg" then
    ch = Alliance.ReadsOrg(Names.Me()) and r or nil
  elseif r == "allymaster" then
    ch = Store.IsMaster(Names.Me()) and r or nil
  elseif r == "bi" then
    local to = keyOf(b.to)
    if fromKey == mk and to and Alliance.Member(to) then
      ch = "ally-" .. Alliance.Code(to)
    elseif to == mk then
      ch = "ally-" .. Alliance.Code(fromKey)
    end
  elseif builtinRoom(r) then
    ch = r
  end
  if not ch then
    return
  end
  seen[b.i] = true
  if fromKey ~= mk then
    heard(fromKey)
  end
  -- (A flood from one author is dropped: at most 8 lines in 10 seconds. Our guild's mutes reach them too.)
  local t = GetTime()
  local rate = heardRate[from] or { start = t, n = 0 }
  if t - rate.start > 10 then
    rate.start, rate.n = t, 0
  end
  rate.n = rate.n + 1
  heardRate[from] = rate
  if rate.n > 8 or BG.Chat.MutedUntil(from) then
    return
  end
  addLine(ch, b, from, fromKey)
  -- A sister guild's line that reached us by whisper goes on to our whole guild (not the private tabs).
  if dist == "WHISPER" and fromKey ~= mk and r ~= "allyorg" and r ~= "allymaster" then
    Comm.Send("AC", b, "GUILD", nil, { lane = "alert" })
  end
  -- The private tabs: whoever of ours is hidden from the other guilds gets them from us (the first reader by
  -- name who shows up), since the other guilds do not know they are online.
  if dist == "WHISPER" and fromKey ~= mk and (r == "allyorg" or r == "allymaster") then
    local relay, hidden = nil, {}
    for _, p in ipairs(Peers.Active()) do
      local m = BG.Guild.Find(p.name)
      local reads = (r == "allyorg" and Alliance.ReadsOrg(p.name)) or (r == "allymaster" and m and m.rankIndex == 0)
      if reads then
        if p.hidden then
          hidden[#hidden + 1] = p.name
        elseif not relay then
          relay = p.name
        end
      end
    end
    if relay and Names.IsMe(relay) then
      for _, n in ipairs(hidden) do
        Comm.Send("AC", b, "WHISPER", n, { lane = "alert" })
      end
    end
  end
end
Alliance.TakeLine = takeLine
Comm.Register("AC", takeLine, { channels = { "GUILD", "WHISPER" }, maxBytes = 900 })

-- Our messenger towards the sister guilds: one our master named (cargo), while connected; else the guild's.
function Alliance.Messenger()
  local active, list = {}, {}
  for _, p in ipairs(Peers.Active()) do
    if not p.hidden then
      active[p.name] = true
      list[#list + 1] = p
    end
  end
  for _, n in ipairs(Alliance.Cargos(myKey(), "msg")) do
    if active[n] then
      return n
    end
  end
  return Peers.Elect(list) -- whoever is hidden never speaks to the other guilds for us
end

function Alliance.AmMessenger()
  local m = Alliance.Messenger()
  return m ~= nil and Names.IsMe(m)
end

-- Upkeep -------------------------------------------------------------------------------------------------
BG:On("BG_WHISPER_OFFLINE", function(name)
  local short = Names.Short(name)
  if not short then
    return
  end
  away[short] = GetTime()
  -- What went to them a moment ago goes to the next contact of their guild.
  local list = inFlight[short] or {}
  inFlight[short] = nil
  for _, item in ipairs(list) do
    if GetTime() - item.at < 60 then
      local next = Alliance.Target(item.k, item.organisers)
      if next and next ~= short then
        whisperGuild(item.kind, item.body, item.k, { organisers = item.organisers, lane = item.kind == "AC" and "alert" or "normal" })
      end
    end
  end
  for k, w in pairs(waiting) do
    if Names.Same(w.name, short) then
      waiting[k] = nil
      C_Timer.After(1, function()
        local next = Alliance.Target(k)
        if next and not (away[next] and GetTime() - away[next] < AWAY_FOR) then
          Alliance.SendPresence(k, next)
        end
      end)
    end
  end
  for t, s in pairs(sentInvites) do
    if not s.answered and Names.Same(s.to, short) then
      s.answered = true
      BG:Notify("No está conectado", short .. " no está jugando ahora. Invita a otra persona de esa hermandad, o prueba más tarde.", { kind = "warning", view = "alliance" })
    end
  end
end)

local function tick()
  local d = Alliance.Doc()
  local t = GetTime()
  for name, list in pairs(inFlight) do
    if not list[1] or t - list[#list].at > 60 then
      inFlight[name] = nil
    end
  end
  if d and BG.Consent.Accepted() and BG.Guild.info and not BG.Guild.fromCache and Alliance.AmMessenger() then
    for _, g in ipairs(Alliance.Sisters()) do
      local w = waiting[g.k]
      if w and t - w.at > ANSWER_WAIT then
        away[w.name] = away[w.name] or t -- no answer: someone else next time
        waiting[g.k] = nil
        local next = Alliance.Target(g.k)
        if next and not (away[next] and t - away[next] < AWAY_FOR) then
          Alliance.SendPresence(g.k, next)
        end
      elseif not w and t - (lastPresenceTo[g.k] or -math.huge) >= PRESENCE_EVERY then
        Alliance.SendPresence(g.k)
      end
    end
  end
  -- An invitation we accepted keeps knocking until the other guild answers.
  if not d and BG.Consent.Accepted() and Store.IsOrganiser(Names.Me() or "") then
    for _, inv in ipairs(Alliance.Invitations()) do
      local state = acceptTries[inv.id]
      if inv.d.st == "ACCEPTED" and (not state or t - state.at > 60) then
        sendAccept(inv)
      end
    end
  end
  if Alliance.Upkeep then
    Alliance.Upkeep()
  end
  for tok, s in pairs(sentInvites) do
    if not s.answered and t - s.at > 30 then
      s.answered = true
      BG:Notify("Sin respuesta", s.to .. " no contesta. Puede que no tenga BlazonGuild o no haya aceptado su privacidad. Prueba con otra persona de esa hermandad.", { kind = "warning", view = "alliance" })
    end
  end
  C_Timer.After(TICK, tick)
end

local started = false
BG:On("BG_ROSTER_UPDATED", function()
  if not started and BG.Guild.info then
    started = true
    C_Timer.After(TICK, tick)
  end
end)

BG:On("PLAYER_GUILD_UPDATE", function()
  if not IsInGuild() then
    wipe(Alliance.presence)
    wipe(waiting)
  end
end)

-- Notices: a new sister guild, an invitation for our master.
BG:On("BG_RECORD", function(kind, r, old)
  if kind == "alliance" and r.d and old and old.d and #r.d.guilds > #old.d.guilds then
    local had = {}
    for _, g in ipairs(old.d.guilds) do
      had[g.k] = true
    end
    for _, g in ipairs(r.d.guilds) do
      if not had[g.k] then
        BG:Notify("Nueva hermandad hermana", g.n .. " entra en la alianza «" .. r.d.name .. "».", { kind = "success", view = "alliance" })
      end
    end
  elseif kind == "ainvites" and r.d and not old and r.d.st == "OPEN" and isMaster() then
    BG:Notify("Invitación a una alianza", r.d.g.n .. " os invita a su alianza «" .. r.d.an .. "». Decides tú.", { kind = "info", view = "alliance", sound = "READY_CHECK" })
  end
  if kind == "alliance" or kind == "ainvites" then
    BG:Fire("BG_ALLIANCE_CHANGED")
  end
end)
BG:On("BG_STORE_CHANGED", function(name)
  if name == "alliance" or name == "ainvites" then
    BG:Fire("BG_ALLIANCE_CHANGED")
  end
end)

BG.commands = BG.commands or {}
BG.commands.alianza = function()
  if not (BG.window and BG.window:IsShown()) then
    BG:ToggleWindow()
  end
  BG:ShowView("alliance")
end
