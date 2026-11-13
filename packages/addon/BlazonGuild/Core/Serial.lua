-- Wire encoding for addon messages: Lua values <-> compact, chat-safe text. Pure functions (no game API),
-- covered by tests/serial.mjs. Deterministic: the same value always gives the same text (table keys are
-- sorted), so a signature over the text stays valid wherever it is decoded and encoded again.
--
--   T / F            true / false
--   i<base36>;       integer (with a leading "-" when negative), |n| < 2^53
--   n<%.14g>;        any other number
--   s<text>;         string; "~", ";", "|", control bytes and DEL travel as ~XX (two hex digits)
--   [ ... ]          array: values for keys 1..n with no holes
--   { k v k v ... }  any other table: key/value pairs, keys sorted (numbers first, then strings)
--
-- The decoder never trusts its input: depth, item count and length are capped, and anything malformed
-- returns nil plus a reason instead of raising.
local _, BG = ...
local Serial = {}
BG.Serial = Serial

Serial.MAX_DEPTH = 12 -- (the alliance record inside a catch-up batch is nine tables deep)
Serial.MAX_ITEMS = 4000
Serial.MAX_BYTES = 32768

local DIGITS = "0123456789abcdefghijklmnopqrstuvwxyz"

local function base36(n)
  if n == 0 then
    return "0"
  end
  local neg = n < 0
  if neg then
    n = -n
  end
  local out = {}
  while n > 0 do
    local d = n % 36
    out[#out + 1] = DIGITS:sub(d + 1, d + 1)
    n = (n - d) / 36
  end
  local s = string.reverse(table.concat(out))
  return neg and ("-" .. s) or s
end
Serial.Base36 = base36

local function escapeByte(c)
  return string.format("~%02x", c:byte())
end

local function escape(s)
  -- %c is every control byte (0-31) and DEL (127); %z is avoided on purpose (gone after Lua 5.1).
  return (s:gsub("[%c~;|]", escapeByte))
end

local function unescape(s)
  if s:gsub("~%x%x", ""):find("~", 1, true) then
    return nil
  end
  return (s:gsub("~(%x%x)", function(hex)
    return string.char(tonumber(hex, 16))
  end))
end

local function isArray(t)
  local n = #t
  local count = 0
  for k in pairs(t) do
    if type(k) ~= "number" or k < 1 or k > n or k % 1 ~= 0 then
      return false
    end
    count = count + 1
  end
  return count == n
end

local function keyOrder(a, b)
  local ta, tb = type(a), type(b)
  if ta ~= tb then
    return ta == "number"
  end
  return a < b
end

local encodeValue
encodeValue = function(v, out, depth)
  local t = type(v)
  if t == "boolean" then
    out[#out + 1] = v and "T" or "F"
  elseif t == "number" then
    if v ~= v or v == math.huge or v == -math.huge then
      error("número no representable")
    end
    if v % 1 == 0 and v > -9007199254740992 and v < 9007199254740992 then
      out[#out + 1] = "i" .. base36(v) .. ";"
    else
      out[#out + 1] = "n" .. string.format("%.14g", v) .. ";"
    end
  elseif t == "string" then
    out[#out + 1] = "s" .. escape(v) .. ";"
  elseif t == "table" then
    if depth >= Serial.MAX_DEPTH then
      error("demasiado anidado")
    end
    if isArray(v) then
      out[#out + 1] = "["
      for i = 1, #v do
        encodeValue(v[i], out, depth + 1)
      end
      out[#out + 1] = "]"
    else
      local keys = {}
      for k in pairs(v) do
        local kt = type(k)
        if kt ~= "string" and kt ~= "number" then
          error("clave no admitida: " .. kt)
        end
        keys[#keys + 1] = k
      end
      table.sort(keys, keyOrder)
      out[#out + 1] = "{"
      for _, k in ipairs(keys) do
        encodeValue(k, out, depth + 1)
        encodeValue(v[k], out, depth + 1)
      end
      out[#out + 1] = "}"
    end
  else
    error("tipo no admitido: " .. t)
  end
end

-- Returns the text, or nil and a reason (functions, userdata, NaN or cycles deeper than MAX_DEPTH).
function Serial.Encode(value)
  local out = {}
  local ok, err = pcall(encodeValue, value, out, 0)
  if not ok then
    return nil, (tostring(err):gsub("^.-:%d+: ", ""))
  end
  return table.concat(out)
end

-- Returns the value, or nil and a reason. Trailing bytes after the value are an error.
function Serial.Decode(text)
  if type(text) ~= "string" then
    return nil, "no es texto"
  end
  if #text > Serial.MAX_BYTES then
    return nil, "demasiado largo"
  end
  local pos, items = 1, 0
  local value

  local function token()
    local close = text:find(";", pos, true)
    if not close then
      error("falta ';'")
    end
    local raw = text:sub(pos, close - 1)
    pos = close + 1
    return raw
  end

  value = function(depth)
    items = items + 1
    if items > Serial.MAX_ITEMS then
      error("demasiados elementos")
    end
    local c = text:sub(pos, pos)
    pos = pos + 1
    if c == "T" then
      return true
    elseif c == "F" then
      return false
    elseif c == "i" then
      local raw = token()
      if not raw:find("^%-?[0-9a-z]+$") then
        error("entero mal formado")
      end
      local neg = raw:sub(1, 1) == "-"
      local n = tonumber(neg and raw:sub(2) or raw, 36)
      if not n then
        error("entero mal formado")
      end
      return neg and -n or n
    elseif c == "n" then
      local n = tonumber(token())
      if not n or n ~= n then
        error("número mal formado")
      end
      return n
    elseif c == "s" then
      local s = unescape(token())
      if not s then
        error("texto mal escapado")
      end
      return s
    elseif c == "[" or c == "{" then
      if depth >= Serial.MAX_DEPTH then
        error("demasiado anidado")
      end
      local t, close = {}, c == "[" and "]" or "}"
      local n = 0
      while true do
        local nxt = text:sub(pos, pos)
        if nxt == "" then
          error("tabla sin cerrar")
        end
        if nxt == close then
          pos = pos + 1
          return t
        end
        if c == "[" then
          n = n + 1
          t[n] = value(depth + 1)
        else
          local k = value(depth + 1)
          if type(k) ~= "string" and type(k) ~= "number" then
            error("clave no admitida")
          end
          t[k] = value(depth + 1)
        end
      end
    end
    error("marca desconocida '" .. c .. "'")
  end

  local ok, result = pcall(value, 0)
  if not ok then
    return nil, (tostring(result):gsub("^.-:%d+: ", ""))
  end
  if pos <= #text then
    return nil, "sobran datos"
  end
  return result
end
