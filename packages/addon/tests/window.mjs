// The window gets out of the way (Peregrino, 2026-11-12: it covered the world map and the creatures to click, with
// no way to make it small; and a round button by the minimap): minimizing to a small bar and back, the world map
// minimizing it by itself and bringing it back, the unread lines on the bar, and the minimap button (click,
// drag around the edge, hide).
import { createClient, checklist } from './harness.mjs';

const t = checklist('comprobaciones de minimizar y del botón del minimapa');
const c = await createClient({ identity: { first: 'El', second: 'Peregrino', guid: 'Player-6842-0A1B2C3D', rosterIndex: 2 } });
await c.login();
await c.run('BG.Consent.Accept() SIM.advance(1)');
const get = async (expr) => {
  await c.run(`__out = (function() ${expr} end)()`);
  return c.lua.global.get('__out');
};

await t.check('minimizar deja una barra pequeña con la sección, y la barra la vuelve a abrir', async () => {
  const r = await get(`
    BG:ToggleWindow() SIM.layout(834, 604) BG:ShowView("map") SIM.layout(834, 604)
    BG.window.minimize:Click()
    if BG.window:IsShown() then return "la ventana sigue abierta" end
    local bar = BG.miniBar
    if not (bar and bar:IsShown()) then return "no hay barra" end
    if bar.sub:GetText() ~= "Minimizada en Mapa" then return "barra: " .. tostring(bar.sub:GetText()) end
    local out = SIM.CheckLayout(bar)
    if #out > 0 then return "se sale de la barra: " .. out[1] end
    local r = SIM.Rect(bar)
    if not r or r.r - r.l > 320 or r.b - r.t > 50 then return "la barra no es pequeña" end
    bar:Click()
    if not BG.window:IsShown() or bar:IsShown() then return "no volvió" end
    if BG.db.settings.lastView ~= "map" then return "volvió a otra sección: " .. BG.db.settings.lastView end
    return true`);
  return r;
});

await t.check('el mapa del mundo la minimiza solo y la devuelve al cerrarse', async () => {
  return get(`
    WorldMapFrame:Show()
    if BG.window:IsShown() or not BG.miniBar:IsShown() then return "no se minimizó al abrir el mapa" end
    WorldMapFrame:Hide()
    if not BG.window:IsShown() then return "no volvió al cerrar el mapa" end
    -- Minimized by hand: closing the map leaves it minimized.
    BG.window.minimize:Click()
    WorldMapFrame:Show() WorldMapFrame:Hide()
    if BG.window:IsShown() then return "se abrió sola tras minimizarla a mano" end
    BG:ToggleWindow()
    if not BG.window:IsShown() or BG.miniBar:IsShown() then return "/bg no la devolvió" end
    -- The button in Mapa opens the world map and gets out of the way.
    BG:ShowView("map") SIM.layout(834, 604)
    BG.window.viewFrames.map.side.open:Click()
    if not WorldMapFrame:IsShown() or BG.window:IsShown() then return "el botón no abrió el mapa o no se apartó" end
    WorldMapFrame:Hide()
    return BG.window:IsShown() or "no volvió tras el mapa"`);
});

await t.check('minimizada, la barra cuenta los mensajes nuevos', async () => {
  return get(`
    BG:ShowView("map") BG.window.minimize:Click()
    SIM.fire("CHAT_MSG_GUILD", "¿Alguien para Brazanegra?", "Rina Dagaluna-ForeverPvP", "", "", "", "", 0, 0, "", 0, 5, "Player-6842-SIMB")
    local b = BG.miniBar.badge:GetText()
    BG.miniBar:Click()
    return b == "1 mensaje" or ("contador: " .. tostring(b))`);
});

await t.check('botón del minimapa: en el borde, abre y cierra, se arrastra y se puede ocultar', async () => {
  return get(`
    local b = BG.minimapButton
    if not (b and b:IsShown()) then return "no hay botón" end
    local function center() local r = SIM.Rect(b) return (r.l + r.r) / 2, (r.t + r.b) / 2 end
    local mr = SIM.Rect(Minimap)
    local mx, my = (mr.l + mr.r) / 2, (mr.t + mr.b) / 2
    local x, y = center()
    local d = math.sqrt((x - mx) ^ 2 + (y - my) ^ 2)
    if math.abs(d - 80) > 1 then return "distancia al centro del minimapa: " .. d end
    local was = BG.window:IsShown()
    b:Click()
    if BG.window:IsShown() == was then return "el clic no abrió ni cerró" end
    SIM.cursor = { 1900, 950 } -- (to the right of the minimap's centre)
    b.__scripts.OnDragStart(b)
    b.__scripts.OnUpdate(b)
    b.__scripts.OnDragStop(b)
    x, y = center()
    if math.abs(BG.db.settings.minimapAngle) > 0.5 or math.abs(x - (mx + 80)) > 1 then return "arrastrado: ángulo " .. BG.db.settings.minimapAngle .. ", x " .. x end
    BG.commands.minimapa()
    if b:IsShown() then return "/bg minimapa no lo ocultó" end
    BG.commands.minimapa()
    return b:IsShown() or "no volvió a aparecer"`);
});

await t.check('«Cómo funciona»: sale sola la primera vez, el «?» la vuelve a abrir y todo cabe', async () => {
  return get(`
    BG:ShowView("overview") SIM.layout(834, 604)
    if BG.window.help:IsShown() then return "el ? sale en una sección sin guía" end
    BG:ShowView("crafts") SIM.layout(834, 604)
    local vf = BG.window.viewFrames.crafts
    if not (vf.guide and vf.guide:IsShown()) then return "no salió sola la primera vez" end
    if vf.guide.head.title:GetText() ~= "Así funciona Artesanía y botín" then return "título: " .. tostring(vf.guide.head.title:GetText()) end
    if not vf.guide.rows[1].text:GetText():find("Herrería", 1, true) then return "paso 1: " .. vf.guide.rows[1].text:GetText() end
    local out = SIM.CheckLayout(vf) if #out > 0 then return "se sale: " .. out[1] end
    vf.guide.ok:Click()
    if vf.guide:IsShown() then return "Entendido no la cerró" end
    BG:ShowView("overview") BG:ShowView("crafts")
    if vf.guide:IsShown() then return "salió otra vez sola" end
    if not BG.window.help:IsShown() then return "no hay botón ?" end
    BG.window.help:Click()
    if not vf.guide:IsShown() then return "el ? no la abrió" end
    vf.guide.ok:Click()
    for _, key in ipairs({ "map", "alliance", "war" }) do
      BG:ShowView(key) SIM.layout(834, 604)
      local g = BG.window.viewFrames[key].guide
      if not (g and g:IsShown()) then return "sin guía en " .. key end
      local o = SIM.CheckLayout(BG.window.viewFrames[key]) if #o > 0 then return key .. " se sale: " .. o[1] end
      g.ok:Click()
    end
    return true`);
});

await t.check('ningún error interno', async () => {
  const e = await get('local e = BG.db.errors and BG.db.errors[1] return e and (e.where .. ": " .. e.error) or ""');
  return e === '' || e;
});

c.close();
t.report();
