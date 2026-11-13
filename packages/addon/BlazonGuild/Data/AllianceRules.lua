-- The alliance record's rules (ADR-020): who may change what, and the texts that get signed. Pure functions:
-- they read records and answer; checking the signatures (Sign.lua) comes after.
--
-- The record has two kinds of parts, so that guilds never step on each other:
--   * each guild's own entry (its contacts, master, signers, cargos, vote for the leader, the invitations it
--     sent), with its own version `ev`, signed by that guild alone. Guilds change their entries whenever they
--     like; the newest valid entry of each guild wins.
--   * the common part (who is in, the key, the name), with one version `v`, signed by the guild that changed it.
--     It changes rarely: a guild joins (invited by a guild that had sent the invitation), a guild leaves (on its
--     own, or the leader's guild takes it out), the leader's guild gives a new key.
-- Each entry lists the keys that sign for its guild (the master's first, "the anchor", then its organisers'),
-- and that list carries a certificate: signed by the anchor, or, when the anchor changes (a new master), by a
-- key the previous list had. The leader is the guild more than half of the guilds vote for; else the founder.
local _, BG = ...
local Rules = {}
BG.AllianceRules = Rules

local function list(t)
  return table.concat(t or {}, ",")
end

local function num(n)
  return string.format("%d", tonumber(n) or 0)
end

local function has(t, x)
  for _, v in ipairs(t or {}) do
    if v == x then
      return true
    end
  end
  return false
end
Rules.Has = has

function Rules.EntryText(g)
  local roles, inv = {}, {}
  for _, r in ipairs(g.r or {}) do
    roles[#roles + 1] = r.n .. "=" .. r.c
  end
  for _, v in ipairs(g.inv or {}) do
    inv[#inv + 1] = v.t .. "=" .. (v.to or "") .. "=" .. num(v.at) .. "=" .. (v.by or "")
  end
  return table.concat({ "G", g.k, g.n, g.f or "", g.m or "", list(g.c), num(g.at), list(g.pk), g.ks and g.ks.s or "", g.ks and g.ks.p or "",
    table.concat(roles, ","), g.vote or "", table.concat(inv, ","), g.jt or "", num(g.ev) }, "\030")
end

-- What a guild's entry signature signs.
function Rules.EntrySigned(allianceId, g)
  return "BGE2\031" .. allianceId .. "\031" .. Rules.EntryText(g)
end

-- What a guild's signer list certificate signs.
function Rules.CertText(allianceId, g)
  return table.concat({ "BGK1", allianceId, g.k, list(g.pk) }, "\031")
end

function Rules.Members(d)
  local out = {}
  for _, g in ipairs(d and d.guilds or {}) do
    out[#out + 1] = g.k
  end
  return out
end

-- What the common part's signature signs.
function Rules.CoreText(d)
  return table.concat({ "BGC2", d.id, d.name, d.key, d.founder or "", d.kr and "1" or "", num(d.v), list(Rules.Members(d)) }, "\031")
end

-- The text of a "your guild is out" message (the leader's guild takes a guild out of the alliance).
function Rules.OutText(allianceId, k, v)
  return table.concat({ "BGX1", allianceId, k, num(v) }, "\031")
end

-- The text of an alliance call to arms.
function Rules.CallText(allianceId, b)
  return table.concat({ "BGC1", allianceId, b.i, b.k, b.t or "", b.f, b.g, num(b.at) }, "\031")
end

local function index(d)
  local out = {}
  for _, g in ipairs(d and d.guilds or {}) do
    out[g.k] = g
  end
  return out
end
Rules.Index = index

-- How many votes each guild has, and how many make a majority.
function Rules.Tally(d)
  local present, n = {}, 0
  for _, g in ipairs(d.guilds) do
    present[g.k] = true
    n = n + 1
  end
  local count = {}
  for _, g in ipairs(d.guilds) do
    if g.vote and present[g.vote] then
      count[g.vote] = (count[g.vote] or 0) + 1
    end
  end
  return count, math.floor(n / 2) + 1
end

-- The leader's guild: the one more than half of the guilds voted for; else the founder; else the oldest.
function Rules.Lead(d)
  if not d or not d.guilds[1] then
    return nil
  end
  local count, need = Rules.Tally(d)
  for c, x in pairs(count) do
    if x >= need then
      return c
    end
  end
  for _, g in ipairs(d.guilds) do
    if g.k == d.founder then
      return g.k
    end
  end
  return d.guilds[1].k
end

-- The certificate check of entry `g`, given the entry we had (`o`, nil when the guild is new to us). Returns a
-- signature check { pk, text, sig }, false when none is needed (same list and certificate), or nil and why.
function Rules.CertCheck(allianceId, g, o)
  if not (g.pk and g.pk[1] and g.ks) then
    return nil, "sin claves"
  end
  if o and list(o.pk) == list(g.pk) and o.ks and o.ks.s == g.ks.s and o.ks.p == g.ks.p then
    return false
  end
  if o and o.pk and o.pk[1] then
    if g.pk[1] == o.pk[1] then
      if g.ks.p ~= o.pk[1] then
        return nil, "certificado" -- the same anchor: only it changes its list
      end
    elseif not has(o.pk, g.ks.p) then
      return nil, "certificado" -- a new anchor: certified by a key of the list we knew
    end
  elseif g.ks.p ~= g.pk[1] then
    return nil, "certificado" -- a guild new to us: its own anchor
  end
  return { pk = g.ks.p, text = Rules.CertText(allianceId, g), sig = g.ks.s }
end

-- Is entry `g` a valid newer entry than `o` (ours, or nil)? Returns the signature checks to make (a list), false
-- when it is not newer, or nil and why.
function Rules.EntryCheck(allianceId, g, o)
  if o and (g.ev or 0) <= (o.ev or 0) then
    return false
  end
  if not (g.es and has(g.pk, g.es.p)) then
    return nil, "firma"
  end
  local cert, why = Rules.CertCheck(allianceId, g, o)
  if cert == nil then
    return nil, why
  end
  local checks = {}
  if cert then
    checks[1] = cert
  end
  checks[#checks + 1] = { pk = g.es.p, text = Rules.EntrySigned(allianceId, g), sig = g.es.s }
  return checks
end

-- Is the common part of `new` a valid next one after `old`'s, given the guild entries already checked
-- (`entries`: guild key -> entry)? Returns the signature checks (a list), false when it is not newer, or nil and
-- why. One step at a time is checked change by change; a guild that missed some steps takes the newest only
-- from the leader's guild.
function Rules.CoreCheck(old, new, entries)
  if new.id ~= old.id then
    return nil, "otra alianza"
  end
  if new.v <= old.v then
    return false
  end
  local s = new.sig
  if not s then
    return nil, "sin firma"
  end
  local S = s.g
  local oldG, newG = index(old), index(new)
  if not oldG[S] then
    return nil, "firmante de fuera"
  end
  local signer = entries[S] or oldG[S]
  if not (has(signer.pk, s.p) or has(oldG[S].pk, s.p)) then
    return nil, "firma"
  end
  local lead = Rules.Lead(old)
  if new.v > old.v + 1 then
    if S ~= lead then
      return nil, "salto"
    end
  else
    local removed = 0
    for k in pairs(oldG) do
      if not newG[k] then
        if k ~= S and S ~= lead then
          return nil, "quitar"
        end
        removed = removed + 1
      end
    end
    for k, g in pairs(newG) do
      if not oldG[k] then
        local inviter = entries[S] or oldG[S]
        local invited = false
        for _, v in ipairs(inviter.inv or {}) do
          if g.jt and v.t == g.jt then
            invited = true
          end
        end
        if not invited then
          return nil, "sin invitación"
        end
      end
    end
    if (new.name ~= old.name or new.key ~= old.key) and S ~= lead then
      return nil, "líder"
    end
    if new.kr and not old.kr and removed == 0 then
      return nil, "clave"
    end
    if old.kr and not new.kr and new.key == old.key then
      return nil, "clave"
    end
  end
  if new.founder ~= old.founder then
    return nil, "fundadora"
  end
  return { { pk = s.p, text = Rules.CoreText(new), sig = s.s } }
end

-- A record a guild gets when it joins (it had none to compare with): it must hold both guilds, every entry must
-- be signed under a list certified by one of its own keys, and the inviting guild must have signed the common
-- part, with the invitation in its entry.
function Rules.CheckJoin(new, inviterKey, myKey, token)
  local g = index(new)
  local inviter = g[inviterKey]
  if not (inviter and g[myKey] and new.sig and new.sig.g == inviterKey and has(inviter.pk, new.sig.p)) then
    return nil, "datos"
  end
  local invited = false
  for _, v in ipairs(inviter.inv or {}) do
    if v.t == token then
      invited = true
    end
  end
  if not invited then
    return nil, "sin invitación"
  end
  local checks = {}
  for _, e in ipairs(new.guilds) do
    if not (e.pk and e.pk[1] and e.ks and has(e.pk, e.ks.p) and e.es and has(e.pk, e.es.p)) then
      return nil, "certificado"
    end
    checks[#checks + 1] = { pk = e.ks.p, text = Rules.CertText(new.id, e), sig = e.ks.s }
    checks[#checks + 1] = { pk = e.es.p, text = Rules.EntrySigned(new.id, e), sig = e.es.s }
  end
  checks[#checks + 1] = { pk = new.sig.p, text = Rules.CoreText(new), sig = new.sig.s }
  return checks
end
