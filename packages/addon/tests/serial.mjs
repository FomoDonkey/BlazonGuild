// The wire format (Core/Serial.lua) and framing (Core/Comm.lua) on their own: round trips, determinism,
// chat-safe output, hostile input, and frames that respect the game's 255-byte limit.
import { createClient, checklist } from './harness.mjs';

const c = await createClient();
const t = checklist('comprobaciones del formato de mensajes');
const lua = (code) => c.run(code);

await t.check('ida y vuelta de valores variados', () =>
  lua(`
  local S = BG.Serial
  local function same(a, b)
    if type(a) ~= type(b) then return false end
    if type(a) ~= "table" then return a == b end
    for k, v in pairs(a) do if not same(v, b[k]) then return false end end
    for k in pairs(b) do if a[k] == nil then return false end end
    return true
  end
  local cases = {
    true, false, 0, 1, -1, 35, 36, 1295, -987654321, 9007199254740991, 3.25, -0.001, 1e300,
    "", "hola", "C A Ñ A D A", "~;|", "a~7eb", "línea\\nnueva\\t", string.char(0, 1, 31, 127), "ñandú 😀",
    {}, { 1, 2, 3 }, { "a", { "b", { "c" } } }, { x = 1, y = "dos", [3] = true, [10] = false },
    { raid = { id = 42, name = "Núcleo de Magma", slots = { tank = 2, heal = 5 } }, at = 1794494786 },
  }
  for i, v in ipairs(cases) do
    local text, err = S.Encode(v)
    if not text then return "case " .. i .. " encode: " .. tostring(err) end
    local back, why = S.Decode(text)
    if back == nil then return "case " .. i .. " decode: " .. tostring(why) .. " <" .. text .. ">" end
    if not same(v, back) then return "case " .. i .. " differs: " .. text end
  end
  return true`));

await t.check('codificación determinista (mismas claves en cualquier orden)', () =>
  lua(`
  local a = { z = 1, a = 2, m = { k = 3, b = 4 }, [5] = "x", [2] = "y" }
  local b = {} b[2] = "y" b.m = { b = 4, k = 3 } b.a = 2 b[5] = "x" b.z = 1
  local ea, eb = BG.Serial.Encode(a), BG.Serial.Encode(b)
  return ea == eb or (ea .. " vs " .. eb)`));

await t.check('la salida nunca lleva bytes de control ni "|"', () =>
  lua(`
  local text = BG.Serial.Encode({ s = string.char(0, 7, 10, 13, 27, 124, 127) .. "|cffff0000rojo|r", n = "~;" })
  if text:find("[%c|]") then return "contiene " .. text end
  return true`));

await t.check('entradas hostiles devuelven error, nunca rompen', () =>
  lua(`
  local S = BG.Serial
  local bad = { "", "x", "i;", "izz", "s~zz;", "s~4;", "[", "{s1;", "{T", "[i1;i2;", "T F", "n1e9999x;",
    string.rep("[", 50) .. string.rep("]", 50), "s" .. string.rep("a", 40000) .. ";", "{[];i1;}", "i1;i2;" }
  for i, text in ipairs(bad) do
    local ok, v, why = pcall(S.Decode, text)
    if not ok then return "case " .. i .. " raised " .. tostring(v) end
    if v ~= nil then return "case " .. i .. " accepted <" .. text .. ">" end
  end
  local cycle = {} cycle.self = cycle
  local enc, why = S.Encode(cycle)
  if enc ~= nil then return "cycle encoded" end
  if S.Encode({ f = print }) ~= nil then return "function encoded" end
  return true`));

await t.check('tramas de 255 bytes como máximo, sin partir letras', () =>
  lua(`
  local payload = "XX:" .. BG.Serial.Encode({ text = string.rep("ñandú áéíóú ", 600) })
  local frames = BG.Comm.Frames(payload, 7)
  if #frames < 10 then return "pocas tramas " .. #frames end
  local joined = {}
  for i, f in ipairs(frames) do
    if #f > 255 then return "trama " .. i .. " de " .. #f .. " bytes" end
    local piece = f:sub(9)
    local first = piece:byte(1)
    if first and first >= 128 and first < 192 then return "trama " .. i .. " empieza a mitad de letra" end
    joined[i] = piece
  end
  if table.concat(joined) ~= payload then return "no se recompone" end
  local small = BG.Comm.Frames("HI:{}", 1)
  if #small ~= 1 or small[1] ~= "1!HI:{}" then return "mensaje corto " .. tostring(small[1]) end
  return true`));

await t.check('reensamblado: piezas desordenadas, repetidas y basura', () =>
  lua(`
  local C = BG.Comm
  local payload = "TX:" .. BG.Serial.Encode({ s = string.rep("abc", 300) })
  local frames = C.Frames(payload, 33)
  local order = {}
  for i = #frames, 1, -1 do order[#order + 1] = frames[i] end
  table.insert(order, 2, frames[1]) -- a repeated piece
  local got
  for _, f in ipairs(order) do
    local r = C.Assemble("Alguien Prueba", f, 1)
    if r then got = r end
  end
  if got ~= payload then return "no recompone" end
  for _, junk in ipairs({ "1#zz0001", "1#0100", "1#01zz02abc", "1#010302x", "1#0100000" }) do
    if C.Assemble("Alguien Prueba", junk, 2) then return "aceptó " .. junk end
  end
  return true`));

c.close();
t.report();
