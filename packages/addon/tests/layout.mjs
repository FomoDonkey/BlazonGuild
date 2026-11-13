// Nothing sticks out of its panel (Peregrino, 2026-11-12: "el botón sobresale de la interfaz del addon … esto no ha
// de pasar en ningún lado"). The stubs work out every frame's rectangle from its anchors, as the game does
// (SIM.Rect), and SIM.CheckLayout lists the buttons and boxes outside the panel or card they sit on. Every
// screen, as the master and as a member; the busy screens (an alliance, a war room with data, a map with
// layers and requests) are checked in their own network tests too.
import { createClient, checklist } from './harness.mjs';

const t = checklist('comprobaciones de que nada se sale de su sitio');
const who = {
  maestro: { first: 'Tarek', second: 'Vientoalto', guid: 'Player-6842-SIMA', rosterIndex: 1 },
  miembro: { first: 'El', second: 'Peregrino', guid: 'Player-6842-0A1B2C3D', rosterIndex: 2 },
};
for (const [role, identity] of Object.entries(who)) {
  const c = await createClient({ identity });
  await c.login();
  await c.run('BG.Consent.Accept() BG:ToggleWindow() SIM.layout(834, 604)');
  await c.run('__out = {} for i, n in ipairs(BG.nav) do __out[i] = n.key end');
  const keys = Object.values(c.lua.global.get('__out'));
  await t.check(`como ${role}: las ${keys.length} pantallas, con todo dentro de sus paneles`, async () => {
    const bad = [];
    for (const key of keys) {
      await c.run(`BG:ShowView("${key}") SIM.layout(834, 604) __out = table.concat(SIM.CheckLayout(BG.window.viewFrames["${key}"] or BG.window), " ; ")`);
      const r = c.lua.global.get('__out');
      if (r) bad.push(`${key}: ${r}`);
    }
    return bad.length === 0 || bad.join(' | ');
  });
  await t.check(`como ${role}: compartiendo la posición, Mapa sigue cabiendo`, async () => {
    await c.run('BG.Layers.SetSharing(true) BG:ShowView("map") SIM.layout(834, 604) __out = table.concat(SIM.CheckLayout(BG.window.viewFrames.map), " ; ")');
    const r = c.lua.global.get('__out');
    return r === '' || r;
  });
  c.close();
}

await t.check('la comprobación ve un botón que se sale (si no, no valdría nada)', async () => {
  const c = await createClient({ identity: who.maestro });
  await c.login();
  await c.run(`BG.Consent.Accept() BG:ToggleWindow() SIM.layout(834, 604) BG:ShowView("map") SIM.layout(834, 604)
    local side = BG.window.viewFrames.map.side
    local b = BG.UI.Button(side, "Demasiado ancho", { width = 900 })
    b:SetPoint("BOTTOMLEFT", 16, 100)
    __out = table.concat(SIM.CheckLayout(BG.window.viewFrames.map), " ; ")`);
  const r = c.lua.global.get('__out');
  c.close();
  return r.includes('Demasiado ancho') || `no lo vio: ${r}`;
});

await t.check('la comprobación ve botones montados uno encima de otro (lo que vio Peregrino en Artesanía, 0.11.0)', async () => {
  const c = await createClient({ identity: who.maestro });
  await c.login();
  await c.run(`BG.Consent.Accept() BG:ToggleWindow() SIM.layout(834, 604) BG:ShowView("crafts") SIM.layout(834, 604)
    local vf = BG.window.viewFrames.crafts
    if vf.guide then vf.guide:Hide() end
    for _, page in pairs(vf.pages) do page:Show() end -- (as when its refresh broke: the three tabs at once)
    __out = table.concat(SIM.CheckLayout(vf), " ; ")`);
  const r = c.lua.global.get('__out');
  c.close();
  return r.includes('se montan') || `no lo vio: ${r}`;
});

await t.check('la comprobación ve un texto debajo de un botón (lo que vio Peregrino en un encargo, 0.11.1)', async () => {
  const c = await createClient({ identity: who.maestro });
  await c.login();
  await c.run(`BG.Consent.Accept() BG:ToggleWindow() SIM.layout(834, 604) BG:ShowView("map") SIM.layout(834, 604)
    local side = BG.window.viewFrames.map.side
    local text = BG.UI.Text(side, 12, BG.color.text)
    text:SetPoint("TOPLEFT", side.share, "TOPLEFT", 4, -4)
    text:SetText("Lo pide El Peregrino. Para quien sepa hacerlo")
    __out = table.concat(SIM.CheckLayout(BG.window.viewFrames.map), " ; ")`);
  const r = c.lua.global.get('__out');
  c.close();
  return r.includes('queda debajo de') || `no lo vio: ${r}`;
});

t.report();
