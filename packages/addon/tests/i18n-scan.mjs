// Opens every screen in a language and lists the visible texts that are still in Spanish (a diagnostic; tests/locales.mjs
// asserts on it). Run: node tests/i18n-scan.mjs [lang]
import { createNetwork } from './harness.mjs';

export async function scan(lang) {
  const P = {
    tarek: { first: 'Tarek', second: 'Vientoalto', guid: 'Player-6842-SIMA', rosterIndex: 1 },
    peregrino: { first: 'El', second: 'Peregrino', guid: 'Player-6842-0A1B2C3D', rosterIndex: 2 },
  };
  const net = await createNetwork([P.tarek, P.peregrino]);
  const [tarek, peregrino] = net.clients;
  await net.loginAll();
  // Peregrino's addon in that language from the start (in the game it only changes on reloading), so the notices that
  // arrive are in it too
  await peregrino.run(`BG.db.settings.lang = "${lang}" BG.Locale.Init()`);
  for (const c of net.clients) await c.run('BG.Consent.Accept()');
  await net.advance(20, 0.5);
  // some content on the screens (a raid, a tournament, a duel, a wanted foe), as the guild would have it
  await tarek.run(`assert(BG.Raids.Save(nil, { inst = "MC", start = time() + 2 * 86400, note = "" }))
    assert(BG.Tourney.Create({ kind = "CUP", title = "Copa", size = 8 }))`);
  await net.advance(4);
  const out = await net.get(peregrino, `
    BG:ToggleWindow() SIM.layout(834, 604)
    -- what the guild and the game write (names, the guild's own ranks and message of the day), not the addon
    local FIXTURES = { "Miembro Prueba %d+", "C A Ñ A D A", "Dagaluna", "Los Humedales", "Vega de Tuercespina", "Raid el viernes a las 21:00",
      "Copa", "Núcleo de Magma", "El Peregrino", "Tarek Vientoalto", "Bruno Hierrosol", "Miembro", "Oficial", "Maestro de hermandad", "Iniciado" }
    -- words that give Spanish away in this language (the ones it shares are left out: "que" in French, "con" in Italian...)
    local WORDS = { "de", "del", "la", "las", "los", "el", "y", "en", "con", "para", "por", "que", "una", "un", "se", "su", "sus", "al", "lo",
      "es", "más", "hace", "está", "están", "sin", "tu", "tú", "aquí", "ahora", "todavía", "nadie", "nada", "pulsa", "puntos", "miembros" }
    local SHARED = { de = { es = 1, los = 1, un = 1 }, fr = { de = 1, la = 1, que = 1, en = 1, se = 1, un = 1, es = 1, y = 1, su = 1, tu = 1 },
      it = { la = 1, una = 1, un = 1, con = 1, del = 1, se = 1, su = 1, al = 1, lo = 1, tu = 1 },
      pt = { de = 1, para = 1, que = 1, se = 1, por = 1, la = 1, lo = 1, a = 1, ["está"] = 1, nada = 1 } }
    local ACCENTS = { en = { "á", "é", "í", "ó", "ú" }, de = { "á", "é", "í", "ó", "ú" }, ru = { "á", "é", "í", "ó", "ú" },
      fr = { "á", "í", "ó", "ú" }, it = { "á", "í", "ó", "ú" }, pt = {} }
    local SPANISH = { "hermandad", "ñ", "¿", "¡" }
    for _, w in ipairs(WORDS) do
      if not (SHARED["${lang}"] or {})[w] then
        SPANISH[#SPANISH + 1] = "%f[%w\\128-\\255]" .. w .. "%f[^%w\\128-\\255]"
      end
    end
    for _, a in ipairs(ACCENTS["${lang}"] or {}) do
      SPANISH[#SPANISH + 1] = a
    end
    local seen, found = {}, {}
    local function check(view)
      for _, o in ipairs(SIM.objects) do
        if o.__kind == "FontString" and o.__shown and o:IsVisible() and type(o.__text) == "string" and o.__text ~= "" and not o.isPlaceholder then
          local t = o.__text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("|T.-|t", "")
          for _, f in ipairs(FIXTURES) do t = t:gsub(f, "") end
          local low = t:lower()
          for _, p in ipairs(SPANISH) do
            if low:find(p) and not seen[o.__text] then
              seen[o.__text] = true
              found[#found + 1] = view .. ": " .. o.__text:gsub("\\n", " / "):sub(1, 140)
              break
            end
          end
        end
      end
    end
    for _, item in ipairs(BG.nav) do
      BG:ShowView(item.key) SIM.layout(834, 604)
      local f = BG.window.viewFrames[item.key]
      if f and f.guide then
        check(item.key .. " (guía)")
        f.guide:Hide()
      end
      check(item.key)
      if f and f.tabs and f.tabs.buttons then
        for i = 2, #f.tabs.buttons do
          f.tabs.buttons[i]:Click() SIM.layout(834, 604)
          check(item.key .. " #" .. i)
        end
        f.tabs.buttons[1]:Click()
      end
    end
    return table.concat(found, string.char(10))`);
  net.close();
  return out ? out.split('\n') : [];
}

if (process.argv[1] && process.argv[1].endsWith('i18n-scan.mjs')) {
  const lang = process.argv[2] || 'en';
  const left = await scan(lang);
  console.log(`${lang}: ${left.length} textos todavía en español`);
  for (const l of left.slice(0, 80)) console.log('  ' + l);
}
