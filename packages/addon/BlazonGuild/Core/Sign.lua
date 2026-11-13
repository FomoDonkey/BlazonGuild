-- Signing keys (ADR-020). The characters who sign for their guild in an alliance (its master and organisers)
-- each have an Ed25519 key (Ed25519.lua). The secret stays in this account's saved data and never leaves the
-- computer; the public key goes into the alliance record, so every guild can check that a change really comes
-- from a guild's leadership, whoever carried it there. Signing and checking run a slice per frame (tens of
-- milliseconds in all), so the game never stops for them.
local _, BG = ...
local Sign = {}
BG.Sign = Sign
local Ed = BG.Ed25519

local MAX_CHECKED = 64

local function keys()
  BG.db.signKeys = BG.db.signKeys or {}
  return BG.db.signKeys
end

local function myId()
  return UnitGUID and UnitGUID("player") or nil
end

-- 32 bytes nobody can guess: the precise clocks, the game's generator, two fresh tables' addresses, the
-- cursor and this character, through SHA-512 (as Olympus' Sign.EntropySample). A missing function is skipped.
function Sign.NewSeed()
  local parts = {}
  local function add(fn, ...)
    if type(fn) == "function" then
      local ok, a, b = pcall(fn, ...)
      if ok then
        parts[#parts + 1] = tostring(a) .. "," .. tostring(b)
      end
    end
  end
  add(debugprofilestop)
  add(GetTimePreciseSec)
  add(GetTime)
  add(GetServerTime)
  add(time)
  parts[#parts + 1] = tostring(math.random()) .. "," .. tostring(math.random()) .. "," .. tostring({}) .. "," .. tostring({})
  add(UnitGUID, "player")
  add(GetCursorPosition)
  add(debugprofilestop)
  return Ed.SHA512(table.concat(parts, "~")):sub(1, 32)
end

-- Our public key (base64url), or nil while it is being made.
function Sign.MyKey()
  local k = myId() and keys()[myId()]
  return k and k.p or nil
end

local waiting, making = {}, false

-- Makes our key the first time (in the background); done(publicKey or nil) once it is ready.
function Sign.Ensure(done)
  local id = myId()
  if not id then
    if done then
      done(nil)
    end
    return false
  end
  local k = keys()[id]
  if k and k.p then
    if done then
      done(k.p)
    end
    return true
  end
  if done then
    waiting[#waiting + 1] = done
  end
  if making then
    return true
  end
  local seed = k and k.s and Ed.FromHex(k.s)
  if not seed or #seed ~= 32 then
    seed = Sign.NewSeed()
    keys()[id] = { s = Ed.ToHex(seed) }
  end
  making = true
  local queued = Ed.Run(function()
    return Ed.PublicKey(seed)
  end, function(ok, pk)
    making = false
    if ok then
      keys()[id].p = Ed.ToB64(pk)
    else
      BG:RecordError("firma: clave", pk)
    end
    local list = waiting
    waiting = {}
    for _, fn in ipairs(list) do
      fn(ok and keys()[id].p or nil)
    end
    BG:Fire("BG_SIGN_READY")
  end)
  if not queued then
    making = false
  end
  return queued
end

-- Signs `text` with our key: done(signature, publicKey), both base64url, or done(nil) if it could not.
function Sign.Sign(text, done)
  Sign.Ensure(function(pk)
    local k = pk and keys()[myId()]
    if not k then
      return done(nil)
    end
    local seed, pkb = Ed.FromHex(k.s), Ed.FromB64(pk)
    local queued = Ed.Run(function()
      return Ed.Sign(seed, text, pkb)
    end, function(ok, sig)
      if ok then
        done(Ed.ToB64(sig), pk)
      else
        BG:RecordError("firma", sig)
        done(nil)
      end
    end)
    if not queued then
      done(nil)
    end
  end)
end

function Sign.IsKey(s)
  return type(s) == "string" and #s == 43 and s:match("^[%w%-_]+$") ~= nil
end

function Sign.IsSignature(s)
  return type(s) == "string" and #s == 86 and s:match("^[%w%-_]+$") ~= nil
end

-- Checks that `sig` is `pk`'s signature of `text`: done(true or false). The same check is remembered (a
-- record arrives many times).
local checked, checkedOrder = {}, {}
function Sign.Verify(pk, text, sig, done)
  if not (Sign.IsKey(pk) and Sign.IsSignature(sig) and type(text) == "string") then
    return done(false)
  end
  local memo = pk .. sig .. Ed.ToHex(Ed.SHA512(text):sub(1, 16))
  if checked[memo] ~= nil then
    return done(checked[memo])
  end
  local pkb, sigb = Ed.FromB64(pk), Ed.FromB64(sig)
  if not pkb or not sigb then
    return done(false)
  end
  local queued = Ed.Run(function()
    return Ed.Verify(pkb, text, sigb) == true
  end, function(ok, good)
    local result = ok and good == true
    checked[memo] = result
    checkedOrder[#checkedOrder + 1] = memo
    if #checkedOrder > MAX_CHECKED then
      checked[table.remove(checkedOrder, 1)] = nil
    end
    done(result)
  end)
  if not queued then
    done(false)
  end
end

-- Checks several { pk, text, sig } one after another: done(true) only if all of them are good.
function Sign.VerifyAll(list, done)
  local i = 0
  local function nextOne(good)
    if good == false then
      return done(false)
    end
    i = i + 1
    local c = list[i]
    if not c then
      return done(true)
    end
    Sign.Verify(c.pk, c.text, c.sig, nextOne)
  end
  nextOne(true)
end
