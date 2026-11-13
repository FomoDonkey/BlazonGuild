// The addon in more languages (Peregrino, 2026-11-13: "todo en más idiomas, los principales de WoW"): English, German,
// French, Italian, Portuguese and Russian, with Spanish as it is written in the code. Every text of the code is in the
// list; every language has all of them with the same values; the files the game loads are built from them; every
// screen shows no Spanish in another language and nothing sticks out of its panel; a text is never half in each
// language; and the language is the game's own, or the one chosen in Administración.
import { readFileSync } from 'node:fs';
import { join } from 'node:path';
import { createClient, checklist, root } from './harness.mjs';
import { extractKeys } from './i18n-keys.mjs';
import { LANGS, luaFor } from './i18n-build.mjs';
import { check } from './i18n-check.mjs';
import { scan } from './i18n-scan.mjs';

const t = checklist('comprobaciones de los idiomas');
const source = JSON.parse(readFileSync(join(root, '..', 'i18n', 'source.json'), 'utf8'));
const who = {
  maestro: { first: 'Tarek', second: 'Vientoalto', guid: 'Player-6842-SIMA', rosterIndex: 1 },
  miembro: { first: 'El', second: 'Peregrino', guid: 'Player-6842-0A1B2C3D', rosterIndex: 2 },
};

await t.check(`cada texto del código está en la lista para traducir (${source.length})`, async () => {
  const have = new Set(source);
  const missing = [...extractKeys().keys()].filter((k) => !have.has(k));
  return missing.length === 0 || `faltan ${missing.length}: ${missing.slice(0, 5).map((k) => JSON.stringify(k)).join(', ')}`;
});

await t.check(`los ${LANGS.length} idiomas los tienen todos, con los mismos valores (%s, %d) que el español`, async () => {
  const bad = [];
  for (const lang of LANGS) {
    const { done, problems } = check(lang);
    if (done !== source.length) bad.push(`${lang}: ${done} de ${source.length}`);
    bad.push(...problems.slice(0, 3));
  }
  return bad.length === 0 || bad.join(' | ');
});

await t.check('los ficheros que carga el juego (Locales/*.lua) están hechos con esas traducciones', async () => {
  const stale = LANGS.filter((lang) => readFileSync(join(root, 'Locales', `${lang}.lua`), 'utf8') !== luaFor(lang).text);
  return stale.length === 0 || `sin rehacer (node tests/i18n-build.mjs): ${stale.join(', ')}`;
});

for (const lang of LANGS) {
  await t.check(`${lang}: ninguna pantalla (ni sus pestañas ni sus guías) enseña textos en español`, async () => {
    const left = await scan(lang);
    return left.length === 0 || `${left.length}: ${left.slice(0, 4).join(' | ')}`;
  });
}

for (const lang of LANGS) {
  await t.check(`${lang}: en todas las pantallas y pestañas nada se sale de su sitio, como maestro y como miembro`, async () => {
    const bad = [];
    for (const [role, identity] of Object.entries(who)) {
      const c = await createClient({ identity });
      await c.login();
      await c.run(`BG.db.settings.lang = "${lang}" BG.Locale.Init() BG.Consent.Accept() BG:ToggleWindow() SIM.layout(834, 604)
        local bad = {}
        for _, item in ipairs(BG.nav) do
          BG:ShowView(item.key) SIM.layout(834, 604)
          local f = BG.window.viewFrames[item.key]
          local function look(tag)
            local r = table.concat(SIM.CheckLayout(f or BG.window), " ; ")
            if r ~= "" then bad[#bad + 1] = tag .. ": " .. r end
          end
          if f and f.guide and f.guide:IsShown() then look(item.key .. " (guía)") f.guide:Hide() SIM.layout(834, 604) end
          look(item.key)
          if f and f.tabs and f.tabs.buttons then
            for i = 2, #f.tabs.buttons do
              f.tabs.buttons[i]:Click() SIM.layout(834, 604)
              look(item.key .. " #" .. i)
            end
            f.tabs.buttons[1]:Click()
          end
        end
        __out = table.concat(bad, " | ")`);
      const r = c.lua.global.get('__out');
      if (r) bad.push(`${role}: ${r}`);
      c.close();
    }
    return bad.length === 0 || bad.join(' || ').slice(0, 600);
  });
}

// Texts the code joins from pieces: each piece in the language, or the whole text as it was; never a mix
// ("Núcleo of Magma", "Ganaste 12 points", "On Peregrino").
await t.check('un texto hecho de trozos sale entero en el idioma, o entero como estaba: nunca la mitad en cada uno', async () => {
  const c = await createClient({ identity: who.miembro });
  await c.login();
  const cases = [
    ['en', 'Núcleo de Magma|cff8a94a3   0/40 apuntados|r', 'Molten Core|cff8a94a3   0/40 signed up|r'],
    ['en', 'Faltan 1 tanque, 2 de daño. Dentro: El Peregrino, Tarek.', '1 tank short, 2 damage. In the group: El Peregrino, Tarek.'],
    ['en', 'En vivo, hace 25 s, 2 con BlazonGuild', 'Live, 25 s ago, 2 with BlazonGuild'],
    ['en', 'Nivel 17, en Bosque del Ocaso', 'Nivel 17, en Bosque del Ocaso'], // (with a zone the addon does not name, the whole text stays as it was)
    ['en', 'Nivel 17, en Los Humedales', 'Level 17, in Wetlands'], // (one the addon names, for a dungeon of Forever, is translated)
    ['en', 'Miembro|cffd0b078  (tú)|r', 'Miembro|cffd0b078  (you)|r'], // (the guild's own rank name stays)
    ['en', 'sábado 14 de noviembre, 16:03. La organiza Tarek Vientoalto. Pulsa para apuntarte.', 'Saturday 14 November, 16:03. Organised by Tarek Vientoalto. Click to sign up.'],
    ['en', 'Nota: Raid el viernes a las 21:00', 'Note: Raid el viernes a las 21:00'],
    ['en', 'Ganaste 12 puntos, 3 bajas)', 'Ganaste 12 puntos, 3 bajas)'],
    ['en', 'El Peregrino', 'El Peregrino'],
    ['en', 'Gana Tarek.', 'Tarek wins.'],
    ['ru', 'Núcleo de Magma|cff8a94a3   0/40 apuntados|r', 'Огненные Недра|cff8a94a3   записано 0/40|r'],
    ['de', 'Aceptada el 12/11/2026', 'Akzeptiert am 12/11/2026'],
  ];
  const bad = [];
  for (const [lang, from, want] of cases) {
    await c.run(`BG.db.settings.lang = "${lang}" BG.Locale.Init() __out = BG.T(${JSON.stringify(from)})`);
    const got = c.lua.global.get('__out');
    if (got !== want) bad.push(`${lang} ${JSON.stringify(from)} -> ${JSON.stringify(got)} (no ${JSON.stringify(want)})`);
  }
  c.close();
  return bad.length === 0 || bad.join(' | ');
});

await t.check('traducir no frena: cien mensajes largos de alguien (que no están en ninguna lista) en poco tiempo', async () => {
  const c = await createClient({ identity: who.miembro });
  await c.login();
  await c.run(`BG.db.settings.lang = "en" BG.Locale.Init()
    local t = os.clock()
    for i = 1, 100 do
      BG.T("Oye, ¿alguien viene esta noche a la raid del Núcleo? Necesitamos dos sanadores más, y traed pociones de fuego, que el jefe pega fuerte. Mensaje " .. i)
    end
    __out = (os.clock() - t) * 1000`);
  const ms = c.lua.global.get('__out');
  c.close();
  return ms < 400 || `${Math.round(ms)} ms`;
});

await t.check('las fechas en cada idioma (día, mes y hora)', async () => {
  const c = await createClient({ identity: who.miembro });
  await c.login();
  const want = { es: 'jueves 12 de noviembre, 16:03', en: 'Thursday 12 November, 16:03', de: 'Donnerstag, 12. November, 16:03',
    fr: 'jeudi 12 novembre, 16:03', it: 'giovedì 12 novembre, 16:03', pt: 'quinta-feira, 12 de novembro, 16:03', ru: 'четверг, 12 ноября, 16:03' };
  const bad = [];
  for (const [lang, w] of Object.entries(want)) {
    await c.run(`BG.db.settings.lang = "${lang}" BG.Locale.Init() __out = BG.UI.FormatDate(time({ year = 2026, month = 11, day = 12, hour = 16, min = 3 }), true)`);
    const got = c.lua.global.get('__out');
    if (got !== w) bad.push(`${lang}: ${got} (no ${w})`);
  }
  c.close();
  return bad.length === 0 || bad.join(' | ');
});

await t.check('con el juego en español, todo queda como está escrito', async () => {
  const c = await createClient({ identity: who.miembro });
  await c.login();
  await c.run('__out = BG.Locale.lang .. " | " .. BG.T("Miembros") .. " | " .. BG.T("Faltan 1 tanque, 2 de daño")');
  const r = c.lua.global.get('__out');
  c.close();
  return r === 'es | Miembros | Faltan 1 tanque, 2 de daño' || r;
});

await t.check('el idioma del juego se usa solo (alemán, y ruso con la letra cirílica del juego en un cliente de otro idioma)', async () => {
  const c = await createClient({ identity: who.miembro });
  await c.login();
  await c.run(`SIM.locale = "deDE" BG.db.settings.lang = nil BG.Locale.Init() local de = BG.Locale.lang .. " " .. BG.T("Miembros")
    BG.db.settings.lang = "ru" BG.Locale.Init()
    __out = de .. " | " .. BG.Locale.lang .. " " .. BG.T("Miembros") .. " | " .. BG.font.body`);
  const r = c.lua.global.get('__out');
  c.close();
  return r === 'de Mitglieder | ru Участники | Fonts\\FRIZQT___CYR.TTF' || r;
});

await t.check('en Administración se elige el idioma: lo dice la fila, pide escribir /reload (el addon no recarga solo: Forever lo bloquea) y al recargar sale en ese idioma; también /bg idioma', async () => {
  const c = await createClient({ identity: who.maestro });
  await c.login();
  await c.run(`BG.Consent.Accept() BG:ToggleWindow() BG:ShowView("admin") SIM.layout(834, 604)
    local f = BG.window.viewFrames.admin
    f.langPicker:SetValue("fr")
    local row = f.rows.lang.value and f.rows.lang.value:GetText() or ""
    local dialog = BlazonGuildDialog and BlazonGuildDialog:IsShown() and BlazonGuildDialog.title:GetText() or "sin pregunta"
    local says = false
    for _, o in ipairs(SIM.objects) do
      local p = o while p do if p == BlazonGuildDialog then break end p = p.__parent end
      if p and o.GetText and o:IsVisible() and tostring(o:GetText() or ""):find("/reload", 1, true) then says = true end
    end
    local reloaded = false
    ReloadUI = function() reloaded = true end
    BlazonGuildDialog.primary:Click()
    BG.Locale.Init()
    local fr = BG.T("Miembros")
    BG.commands.idioma("en")
    local saved = BG.db.settings.lang
    __out = table.concat({ row, dialog, tostring(says), tostring(reloaded), fr, saved }, " | ")`);
  const r = c.lua.global.get('__out');
  c.close();
  return /Français al recargar/.test(r) && r.endsWith('Idioma | true | false | Membres | en') || r;
});

t.report();
