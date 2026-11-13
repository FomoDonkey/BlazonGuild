// Signatures (ADR-020): the Ed25519 taken from Olympus checked against RFC 8032 and Node's own, our signing
// keys (made once, kept in the account's saved data, signing and checking in the background), and the
// alliance record's rules (who may change what) on hand-made records.
import crypto from 'node:crypto';
import { createClient, checklist } from './harness.mjs';

const t = checklist('comprobaciones de las firmas');
const c = await createClient({ identity: { first: 'Tarek', second: 'Vientoalto', guid: 'Player-6842-SIMA', rosterIndex: 1 } });
await c.login();
await c.run('BG.Consent.Accept()');
const get = async (expr) => {
  await c.run(`__out = (function() ${expr} end)()`);
  return c.lua.global.get('__out');
};

// RFC 8032, 7.1, test 1 (empty message) and test 3 (two bytes).
const V1 = {
  seed: '9d61b19deffd5a60ba844af492ec2cc44449c5697b326919703bac031cae7f60',
  pk: 'd75a980182b10ab7d54bfed3c964073a0ee172f3daa62325af021a68f707511a',
  msg: '',
  sig: 'e5564300c360ac729086e2cc806e828a84877f1eb8e5d974d873e065224901555fb8821590a33bacc61e39701cf9b46bd25bf5f0595bbe24655141438e7a100b',
};
const V3 = {
  seed: 'c5aa8df43f9f837bedb7442f31dcb7b166d38535076f094b85ce3a2e0b4458f7',
  pk: 'fc51cd8e6218a1a38da47ed00230f0580816ed13ba3303ac5deb911548908025',
  msg: 'af82',
  sig: '6291d657deec24024827e69c3abe01a30ce548a284743a445e3680d7db5ac3ac18ff9b538d16f290ae67f760984dc6594a7c15e9716ed28dc027beceea1ec40a',
};

await t.check('Ed25519 da las claves y firmas del RFC 8032', async () => {
  for (const v of [V1, V3]) {
    const r = await get(`local Ed = BG.Ed25519 local seed, msg = Ed.FromHex("${v.seed}"), Ed.FromHex("${v.msg}") or ""
      local pk = Ed.PublicKey(seed) return Ed.ToHex(pk) .. "|" .. Ed.ToHex(Ed.Sign(seed, msg, pk)) .. "|" .. tostring(Ed.Verify(pk, msg, Ed.FromHex("${v.sig}")))`);
    if (r !== `${v.pk}|${v.sig}|true`) return r;
  }
  return true;
});

await t.check('comprueba firmas de Node y rechaza las cambiadas', async () => {
  const { privateKey, publicKey } = crypto.generateKeyPairSync('ed25519');
  const msg = 'BGE2|alianza|C A Ñ A D A|ñandú';
  const sig = crypto.sign(null, Buffer.from(msg), privateKey).toString('hex');
  const pk = publicKey.export({ format: 'der', type: 'spki' }).subarray(-32).toString('hex');
  c.lua.global.set('__msg', msg);
  const r = await get(`local Ed = BG.Ed25519 local pk, sig = Ed.FromHex("${pk}"), Ed.FromHex("${sig}")
    local bad = sig:sub(1, 10) .. string.char((sig:byte(11) + 1) % 256) .. sig:sub(12)
    return tostring(Ed.Verify(pk, __msg, sig)) .. tostring(Ed.Verify(pk, __msg .. "x", sig)) .. tostring(Ed.Verify(pk, __msg, bad))`);
  return r === 'truefalsefalse' || r;
});

await t.check('SHA-512 como el de Node', async () => {
  const text = 'abc'.repeat(50);
  const r = await get(`return BG.Ed25519.ToHex(BG.Ed25519.SHA512(string.rep("abc", 50)))`);
  return r === crypto.createHash('sha512').update(text).digest('hex') || r;
});

await t.check('nuestra clave se hace una vez, se guarda, firma y comprueba en segundo plano', async () => {
  await c.run('PK = nil BG.Sign.Ensure(function(pk) PK = pk end)');
  const before = await get('return tostring(PK)');
  await c.run('SIM.advance(1)');
  const pk = await get('return PK');
  if (before !== 'nil' || typeof pk !== 'string' || pk.length !== 43) return `antes ${before}, después ${pk}`;
  const kept = await get('return BG.db.signKeys[UnitGUID("player")].p == PK and #BG.db.signKeys[UnitGUID("player")].s');
  if (kept !== 64) return `guardada: ${kept}`;
  await c.run('SIG = nil OK = nil BG.Sign.Sign("hola", function(s) SIG = s BG.Sign.Verify(PK, "hola", s, function(ok) OK = ok end) end)');
  await c.run('SIM.advance(1)');
  const r = await get('return tostring(SIG and #SIG) .. "|" .. tostring(OK)');
  if (r !== '86|true') return r;
  await c.run('BAD = nil BG.Sign.Verify(PK, "adiós", SIG, function(ok) BAD = ok end) SIM.advance(1)');
  const again = await get('local first = PK PK2 = nil BG.Sign.Ensure(function(pk) PK2 = pk end) return tostring(BAD) .. "|" .. tostring(PK2 == first)');
  return again === 'false|true' || again;
});

// The rules, on records made by hand with real signatures.
await c.run(`
  local Ed, R = BG.Ed25519, BG.AllianceRules
  local function key(n) local seed = Ed.SHA512("clave " .. n):sub(1, 32) return seed, Ed.ToB64(Ed.PublicKey(seed)) end
  K = {}
  for _, n in ipairs({ "a1", "a2", "b1", "b2", "x" }) do local s, p = key(n) K[n] = { s = s, p = p } end
  function SIGN(n, text) return Ed.ToB64(Ed.Sign(K[n].s, text, Ed.FromB64(K[n].p))) end
  function ENTRY(id, k, signers, certBy, ev, extra)
    local e = { k = k, n = k, c = {}, at = 1, pk = {}, r = {}, inv = {}, ev = ev }
    for _, n in ipairs(signers) do e.pk[#e.pk + 1] = K[n].p end
    for f, v in pairs(extra or {}) do e[f] = v end
    e.ks = { s = SIGN(certBy, R.CertText(id, e)), p = K[certBy].p }
    e.es = { s = SIGN(signers[1] == certBy and certBy or signers[1], R.EntrySigned(id, e)), p = K[signers[1] == certBy and certBy or signers[1]].p }
    return e
  end
  function CORE(d, by, g) d.sig = { s = SIGN(by, R.CoreText(d)), p = K[by].p, g = g } return d end
  function VERIFY(checks) if not checks then return "nil" end for _, c in ipairs(checks) do
    if not Ed.Verify(Ed.FromB64(c.pk), c.text, Ed.FromB64(c.sig)) then return "mala" end end return "ok" end
`);

await t.check('reglas: cada hermandad cambia lo suyo, con la lista certificada por su ancla', async () => {
  const r = await get(`
    local R = BG.AllianceRules
    local old = ENTRY("al1", "A", { "a1" }, "a1", 1)
    local out = {}
    -- the anchor adds an organiser's key
    out[#out + 1] = VERIFY(R.EntryCheck("al1", ENTRY("al1", "A", { "a1", "a2" }, "a1", 2), old))
    -- an organiser certifies a list that keeps the anchor: refused
    local mid = ENTRY("al1", "A", { "a1", "a2" }, "a1", 2)
    out[#out + 1] = tostring((R.EntryCheck("al1", ENTRY("al1", "A", { "a1", "a2", "x" }, "a2", 3), mid)))
    -- a new anchor (a new master) certified by a key the list had
    out[#out + 1] = VERIFY(R.EntryCheck("al1", ENTRY("al1", "A", { "x", "a2" }, "a2", 3), mid))
    -- an outsider's key certifying its own list: refused
    out[#out + 1] = tostring((R.EntryCheck("al1", ENTRY("al1", "A", { "x" }, "x", 3), mid)))
    -- the same or an older version: nothing to take
    out[#out + 1] = tostring(R.EntryCheck("al1", mid, mid))
    return table.concat(out, ",")`);
  return r === 'ok,nil,ok,nil,false' || r;
});

await t.check('reglas: lo común (quién está, la clave) solo como debe cambiar', async () => {
  const r = await get(`
    local R = BG.AllianceRules
    local A = ENTRY("al1", "A", { "a1" }, "a1", 1, { inv = { { t = "tok1", to = "Lia", at = 1, by = "Tarek" } } })
    local B = ENTRY("al1", "B", { "b1" }, "b1", 1, { jt = "tok1" })
    local C = ENTRY("al1", "C", { "x" }, "x", 1, { jt = "nope" })
    local function doc(v, guilds, key, extra) local d = { id = "al1", name = "León", key = key or "k1", founder = "A", v = v, guilds = guilds } for f, x in pairs(extra or {}) do d[f] = x end return d end
    local old = CORE(doc(1, { A }), "a1", "A")
    local entries = { A = A, B = B, C = C }
    local out = {}
    out[#out + 1] = VERIFY(R.CoreCheck(old, CORE(doc(2, { A, B }), "a1", "A"), entries)) -- B joins with A's invitation
    out[#out + 1] = tostring((R.CoreCheck(old, CORE(doc(2, { A, C }), "a1", "A"), entries))) -- C had no invitation
    local two = CORE(doc(2, { A, B }), "a1", "A")
    out[#out + 1] = VERIFY(R.CoreCheck(two, CORE(doc(3, { A }, "k1", { kr = 1 }), "b1", "B"), entries)) -- B leaves
    out[#out + 1] = tostring((R.CoreCheck(two, CORE(doc(3, { B }), "b1", "B"), entries))) -- B takes A out: no
    out[#out + 1] = tostring((R.CoreCheck(two, CORE(doc(3, { A, B }, "k2"), "b1", "B"), entries))) -- B changes the key: no (A leads)
    out[#out + 1] = VERIFY(R.CoreCheck(two, CORE(doc(3, { A, B }, "k2"), "a1", "A"), entries)) -- the leader does
    out[#out + 1] = tostring((R.CoreCheck(two, CORE(doc(5, { A }), "b1", "B"), entries))) -- a jump, not from the leader
    local forged = CORE(doc(3, { A, B }, "k2"), "a1", "A") forged.key = "k3"
    out[#out + 1] = VERIFY(R.CoreCheck(two, forged, entries)) -- changed after signing
    return table.concat(out, ",")`);
  return r === 'ok,nil,ok,nil,nil,ok,nil,mala' || r;
});

await t.check('reglas: el líder lo decide la mayoría de las hermandades, si no la fundadora', async () => {
  const r = await get(`
    local R = BG.AllianceRules
    local d = { founder = "A", guilds = { { k = "A" }, { k = "B", vote = "C" }, { k = "C", vote = "C" } } }
    local one = R.Lead(d)
    d.guilds[2].vote = "B"
    local two = R.Lead(d)
    local pair = R.Lead({ founder = "A", guilds = { { k = "A" }, { k = "B", vote = "B" } } })
    return one .. two .. pair`);
  return r === 'CAA' || r;
});

await t.check('ningún error interno', async () => {
  const e = await get('local e = BG.db.errors and BG.db.errors[1] return e and (e.where .. ": " .. e.error) or ""');
  return e === '' || e;
});

c.close();
t.report();
