// «Grupos de la banda» (0.16.0): the raid's groups as the game's raid frame shows them. Everyone sees them; the
// leader and the organisers move players by dragging (or picking and dropping); dropping on someone swaps them; a
// full group says so; the boxes follow the raid's size; and «Colocar en la banda» moves the real raid, swapping
// into a full group, until it matches the plan.
import { createNetwork, checklist } from './harness.mjs';

const P = {
  tarek: { first: 'Tarek', second: 'Vientoalto', guid: 'Player-6842-SIMA', rosterIndex: 1 }, // Maestro
  bruno: { first: 'Bruno', second: 'Hierrosol', guid: 'Player-6842-SIMD', rosterIndex: 3 }, // Oficial
  peregrino: { first: 'El', second: 'Peregrino', guid: 'Player-6842-0A1B2C3D', rosterIndex: 2 }, // Miembro
};
const net = await createNetwork([P.tarek, P.bruno, P.peregrino]);
const [tarek, bruno, peregrino] = net.clients;
await net.loginAll();
for (const c of net.clients) await c.run('BG.Consent.Accept()');
await net.advance(20, 0.5);
const get = net.get;
const t = checklist('comprobaciones de los grupos de la banda');

const raid = await get(tarek, 'local r = assert(BG.Raids.Save(nil, { inst = "ZG", start = time() + 2 * 86400 })) return r.id');
await net.advance(3);
await tarek.run(`assert(BG.Raids.SignUp(${JSON.stringify(raid)}, "CONFIRMED", "TANK"))`);
await bruno.run(`assert(BG.Raids.SignUp(${JSON.stringify(raid)}, "CONFIRMED", "HEALER"))`);
await peregrino.run(`assert(BG.Raids.SignUp(${JSON.stringify(raid)}, "CONFIRMED", "DPS"))`);
await net.advance(4);
// Six more players (only Tarek's client knows them: enough for the organiser's screen).
await tarek.run(`
  local s = BG.Guild.Entry().store
  for i = 1, 6 do
    local n = "Falso Jugador" .. i
    s.signups[${JSON.stringify(raid)} .. "|" .. n] = { id = ${JSON.stringify(raid)} .. "|" .. n, rev = 1, at = time(), by = n,
      d = { raid = ${JSON.stringify(raid)}, name = n, status = i == 6 and "TENTATIVE" or "CONFIRMED", role = "DPS", class = "MAGE", level = 60 } }
  end`);
const open = (c) => c.run(`
  if not (BG.window and BG.window:IsShown()) then BG:ToggleWindow() end
  SIM.layout(834, 604) BG:ShowView("raids") SIM.layout(834, 604)
  local f = BG.window.viewFrames.raids
  if f.guide then f.guide:Hide() end
  f.selected = ${JSON.stringify(raid)} BG:RefreshView("raids")
  f.detail.groupsBtn:Click() SIM.layout(834, 604)`);
// The chip of `name` wherever it is (a side list row or a group's place).
const CHIP = `local function chipOf(view, name)
  for _, p in ipairs({ view.none, view.bench }) do
    for _, row in ipairs(p.list.rows) do if row:IsShown() and row.name == name then return row end end
  end
  for _, box in ipairs(view.boxes) do
    for _, s in ipairs(box.slots) do if s.chip:IsShown() and s.chip.name == name then return s.chip, s end end
  end
end`;
const place = (c, name) => get(c, `return tostring(BG.Raids.PlaceOf(${JSON.stringify(raid)}, ${JSON.stringify(name)}))`);

await t.check('todos ven los grupos (tantos como pide la banda: 4 para una de 20); un miembro no puede mover a nadie', async () => {
  await peregrino.run('SIM.group = { inGroup = false, inRaid = false, leader = false }');
  await open(peregrino);
  return get(peregrino, `${CHIP}
    local view = BG.window.viewFrames.raids.groups
    if not view:IsShown() then return "no se abre" end
    local shown = 0 for _, b in ipairs(view.boxes) do if b:IsShown() then shown = shown + 1 end end
    if shown ~= 4 then return "grupos: " .. shown end
    if #view.none.list.items ~= 3 then return "sin grupo: " .. #view.none.list.items end
    if view.auto:IsShown() or view.place:IsShown() then return "un miembro ve los botones" end
    local c = chipOf(view, "Bruno Hierrosol")
    c:GetScript("OnDragStart")(c)
    if view.dragging then return "un miembro arrastra" end
    local r, w = BG.Raids.Move(${JSON.stringify(raid)}, "Bruno Hierrosol", 1)
    return tostring(w) == "permiso" or ("mover: " .. tostring(w))`);
});

await t.check('arrastrar un nombre a un grupo lo coloca, y lo ve toda la hermandad', async () => {
  await open(tarek);
  const r = await get(tarek, `${CHIP}
    local view = BG.window.viewFrames.raids.groups
    if not view.auto:IsShown() then return "el maestro no ve «Repartir solos»" end
    local c = chipOf(view, "El Peregrino")
    c:GetScript("OnDragStart")(c)
    if view.dragging ~= "El Peregrino" then return "no empieza a arrastrar" end
    SIM.mouseOver = view.boxes[2]
    c:GetScript("OnDragStop")(c)
    SIM.mouseOver = nil
    return true`);
  if (r !== true) return r;
  await net.advance(4);
  return (await place(bruno, 'El Peregrino')) === '2' || `en Bruno: ${await place(bruno, 'El Peregrino')}`;
});

await t.check('soltar sobre otro jugador: se cambian el sitio', async () => {
  await tarek.run(`assert(BG.Raids.Move(${JSON.stringify(raid)}, "Bruno Hierrosol", 1))`);
  await net.advance(2);
  const r = await get(tarek, `${CHIP}
    local view = BG.window.viewFrames.raids.groups
    view:Refresh()
    local c = chipOf(view, "El Peregrino")
    local _, slot = chipOf(view, "Bruno Hierrosol")
    c:GetScript("OnDragStart")(c)
    SIM.mouseOver = slot
    c:GetScript("OnDragStop")(c)
    SIM.mouseOver = nil
    return true`);
  if (r !== true) return r;
  await net.advance(4);
  const a = await place(peregrino, 'El Peregrino'), b = await place(peregrino, 'Bruno Hierrosol');
  return (a === '1' && b === '2') || `El Peregrino ${a}, Bruno ${b}`;
});

await t.check('sin arrastrar: pulsar el nombre y luego el sitio; clic derecho lo deja sin grupo', async () => {
  return get(tarek, `${CHIP}
    local view = BG.window.viewFrames.raids.groups
    local c = chipOf(view, "Tarek Vientoalto")
    c:Click()
    if view.picked ~= "Tarek Vientoalto" then return "no se marca" end
    view.bench:GetScript("OnMouseUp")(view.bench)
    if BG.Raids.PlaceOf(${JSON.stringify(raid)}, "Tarek Vientoalto") ~= "bench" then return "a reserva: " .. tostring(BG.Raids.PlaceOf(${JSON.stringify(raid)}, "Tarek Vientoalto")) end
    c = chipOf(view, "Tarek Vientoalto")
    c:Click()
    view.boxes[1]:GetScript("OnMouseUp")(view.boxes[1])
    if BG.Raids.PlaceOf(${JSON.stringify(raid)}, "Tarek Vientoalto") ~= 1 then return "al grupo 1: " .. tostring(BG.Raids.PlaceOf(${JSON.stringify(raid)}, "Tarek Vientoalto")) end
    c = chipOf(view, "El Peregrino")
    c:GetScript("OnClick")(c, "RightButton")
    return BG.Raids.PlaceOf(${JSON.stringify(raid)}, "El Peregrino") == "none" or ("clic derecho: " .. tostring(BG.Raids.PlaceOf(${JSON.stringify(raid)}, "El Peregrino")))`);
});

await t.check('un grupo lleno lo dice, y la pantalla se ve sin nada fuera de su sitio', async () => {
  return get(tarek, `${CHIP}
    local view = BG.window.viewFrames.raids.groups
    for i = 1, 5 do assert(BG.Raids.Move(${JSON.stringify(raid)}, "Falso Jugador" .. i, 3)) end
    view:Refresh()
    local c = chipOf(view, "Falso Jugador6")
    c:GetScript("OnDragStart")(c)
    SIM.mouseOver = view.boxes[3]
    c:GetScript("OnDragStop")(c)
    SIM.mouseOver = nil
    if not (view.note:GetText() or ""):find("ya tiene 5", 1, true) then return "aviso: " .. tostring(view.note:GetText()) end
    if BG.Raids.PlaceOf(${JSON.stringify(raid)}, "Falso Jugador6") ~= "none" then return "entró en un grupo lleno" end
    SIM.layout(834, 604)
    local out = SIM.CheckLayout(BG.window.viewFrames.raids)
    return #out == 0 or out[1]`);
});

await t.check('dentro de un grupo se elige la fila: se queda donde lo sueltas, y soltarlo sobre otro les cambia la fila', async () => {
  const r = await get(tarek, `${CHIP}
    local view = BG.window.viewFrames.raids.groups
    view:Refresh()
    local box = view.boxes[4]
    local function drag(name, slot)
      local c = chipOf(view, name)
      c:GetScript("OnDragStart")(c)
      SIM.mouseOver = slot
      c:GetScript("OnDragStop")(c)
      SIM.mouseOver = nil
    end
    drag("El Peregrino", box.slots[4])
    if box.slots[4].chip.name ~= "El Peregrino" or box.slots[1].chip:IsShown() then return "fila 4: " .. tostring(box.slots[4].chip.name) end
    drag("Bruno Hierrosol", box.slots[2])
    if box.slots[2].chip.name ~= "Bruno Hierrosol" then return "fila 2: " .. tostring(box.slots[2].chip.name) end
    local _, slot = chipOf(view, "Bruno Hierrosol")
    drag("El Peregrino", slot)
    if box.slots[2].chip.name ~= "El Peregrino" or box.slots[4].chip.name ~= "Bruno Hierrosol" then
      return "intercambio: 2=" .. tostring(box.slots[2].chip.name) .. ", 4=" .. tostring(box.slots[4].chip.name)
    end
    return true`);
  if (r !== true) return r;
  await net.advance(4);
  const seen = await get(bruno, `local p = BG.Raids.Plan(${JSON.stringify(raid)}) return p.g["El Peregrino"] .. ":" .. p.s["El Peregrino"] .. "|" .. p.g["Bruno Hierrosol"] .. ":" .. p.s["Bruno Hierrosol"]`);
  return seen === '4:2|4:4' || `lo que ve Bruno: ${seen}`;
});

await t.check('«Colocar en la banda»: mueve a cada uno a su grupo (entrando en uno lleno por intercambio)', async () => {
  // Plan: Tarek 1, El Peregrino 1, Bruno 2, Falso1-5 en el 3, «Nadie Ausente» en el 4 (no está en la banda).
  await tarek.run(`
    local id = ${JSON.stringify(raid)}
    assert(BG.Raids.Move(id, "El Peregrino", 1)) assert(BG.Raids.Move(id, "Bruno Hierrosol", 2))
    assert(BG.Raids.Move(id, "Nadie Ausente", 4))`);
  const refused = await get(tarek, `
    SIM.group = { inGroup = true, inRaid = false, leader = true }
    local a, wa = BG.Raids.PlaceInRaid(${JSON.stringify(raid)})
    SIM.group = { inGroup = true, inRaid = true, leader = false, assistant = false }
    local b, wb = BG.Raids.PlaceInRaid(${JSON.stringify(raid)})
    return tostring(wa) .. "," .. tostring(wb)`);
  if (refused !== 'sin banda,sin mando') return `rechazos: ${refused}`;
  await tarek.run(`
    SIM.group = { inGroup = true, inRaid = true, leader = true }
    -- the real raid: group 3 full (El Peregrino among the planned five), Falso Jugador5 waiting in group 2
    SIM.setRaid({ { "Tarek", "Vientoalto", 1 }, { "Bruno", "Hierrosol", 1 }, { "El", "Peregrino", 3 }, { "Falso", "Jugador1", 3 },
      { "Falso", "Jugador2", 3 }, { "Falso", "Jugador3", 3 }, { "Falso", "Jugador4", 3 }, { "Falso", "Jugador5", 2 } })
    local view = BG.window.viewFrames.raids.groups
    view.place:Click()`);
  await net.advance(12, 0.25);
  return get(tarek, `
    local want = { ["Tarek Vientoalto"] = 1, ["El Peregrino"] = 1, ["Bruno Hierrosol"] = 2 }
    for i = 1, 5 do want["Falso Jugador" .. i] = 3 end
    for _, r in ipairs(SIM.raid) do
      local n = r[1] .. " " .. r[2]
      if want[n] ~= r[3] then return n .. " está en el " .. r[3] .. ", y va al " .. tostring(want[n]) end
    end
    local note = BG.window.viewFrames.raids.groups.note:GetText() or ""
    if BG.Raids.placing then return "sigue colocando" end
    if not note:find("Hecho", 1, true) or not note:find("1 del plan no están en la banda", 1, true) then return "aviso: " .. note end
    return SIM.raidMoves <= 4 or ("demasiados movimientos: " .. SIM.raidMoves)`);
});

await t.check('una banda de 40 enseña los 8 grupos', async () => {
  return get(tarek, `
    local id = assert(BG.Raids.Save(nil, { inst = "MC", start = time() + 3 * 86400 })).id
    local f = BG.window.viewFrames.raids
    f.groups:Open(id) SIM.layout(834, 604)
    local shown = 0 for _, b in ipairs(f.groups.boxes) do if b:IsShown() then shown = shown + 1 end end
    local out = SIM.CheckLayout(f)
    f.groups:Hide()
    if shown ~= 8 then return "grupos: " .. shown end
    return #out == 0 or out[1]`);
});

await t.check('ningún error interno y límites del juego respetados', async () => {
  if (net.violations.length) return net.violations.slice(0, 3).join('; ');
  for (const c of net.clients) {
    const e = await get(c, 'local e = BG.db.errors and BG.db.errors[1] return e and (e.where .. ": " .. e.error) or ""');
    if (e) return `${c.name}: ${e}`;
  }
  return true;
});

net.close();
t.report();
