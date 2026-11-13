import { createNetwork } from './harness.mjs';
const net = await createNetwork([{ first: 'El', second: 'Peregrino', guid: 'Player-6842-0A1B2C3D', rosterIndex: 2 }]);
const [c] = net.clients;
await net.loginAll();
await c.run('BG.Consent.Accept()');
const lang = process.argv[2] || 'en';
const out = await net.get(c, `
  BG.db.settings.lang = "${lang}" BG.Locale.Init()
  local r = {}
  r[#r+1] = BG.T("Ha matado a %s miembros") 
  r[#r+1] = BG.T("1 hora") .. " / " .. BG.T("24 horas") .. " / " .. BG.T("5 miembros") .. " / " .. BG.T("Tú estás en X")
  r[#r+1] = BG.T("Lleva %s apuntados") 
  r[#r+1] = BG.T("%s acepta tu reto")
  r[#r+1] = BG.T("Bruno Hierrosol acepta tu reto")
  r[#r+1] = BG.T("Ganaste 12 puntos, 3 bajas)")
  r[#r+1] = BG.T("|cff00ff00Bruno Hierrosol|r acepta tu reto")
  r[#r+1] = BG.UI.FormatDate(time(), true)
  return table.concat(r, string.char(10))`);
console.log(out);
net.close();
