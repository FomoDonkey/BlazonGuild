// The images of BlazonGuild's CurseForge page: a cover and a framed banner for each big section, drawn with the addon's
// own art (Media: metal, corner filigree, divider) and our shield. Design graphics, not screenshots of the game.
// Run: node docs/curseforge/make-images.mjs  (writes docs/curseforge/media/*.png)
import { chromium } from 'playwright';
import { readFileSync, mkdirSync } from 'node:fs';
import { join, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';

const HERE = dirname(fileURLToPath(import.meta.url));
const MEDIA = join(HERE, '..', '..', 'packages', 'addon', 'BlazonGuild', 'Media');
const OUT = join(HERE, 'media');
mkdirSync(OUT, { recursive: true });
const b64 = (p) => `data:image/png;base64,${readFileSync(p).toString('base64')}`;
const METAL = b64(join(MEDIA, 'metal.png'));
const CORNER = b64(join(MEDIA, 'corner.png'));
const DIVIDER = b64(join(MEDIA, 'divider.png'));
const LOGO = b64(join(OUT, 'logo-512.png'));

const CSS = `
@import url('https://fonts.googleapis.com/css2?family=Cinzel:wght@600;700&family=Alegreya+Sans:wght@400;500&display=block');
* { box-sizing: border-box; margin: 0; }
body { width: 1600px; background: #0b0d12; }
.banner { position: relative; width: 1600px; height: 400px; overflow: hidden;
  background: radial-gradient(ellipse at 30% 40%, rgba(214,178,94,.10), transparent 60%), url(${METAL}) , #12161e; background-size: auto, 256px, auto; }
.banner::before { content: ''; position: absolute; inset: 0; background: linear-gradient(90deg, rgba(8,10,14,.25), rgba(8,10,14,.75)); }
.frame { position: absolute; inset: 18px; border: 2px solid rgba(214,178,94,.75); box-shadow: inset 0 0 0 6px rgba(0,0,0,.35), inset 0 0 0 7px rgba(214,178,94,.25); }
.c { position: absolute; width: 96px; height: 96px; background: url(${CORNER}) no-repeat center / contain; }
.tl { left: 10px; top: 10px; } .tr { right: 10px; top: 10px; transform: scaleX(-1); }
.bl { left: 10px; bottom: 10px; transform: scaleY(-1); } .br { right: 10px; bottom: 10px; transform: scale(-1,-1); }
.art { position: absolute; left: 70px; top: 50px; width: 640px; height: 300px; display: flex; align-items: center; justify-content: center; }
.text { position: absolute; left: 760px; right: 80px; top: 0; bottom: 0; display: flex; flex-direction: column; justify-content: center; }
h1 { font: 700 62px/1.05 'Cinzel', serif; letter-spacing: .5px;
  background: linear-gradient(180deg, #fbefc4 0%, #e2c06a 48%, #a8802f 100%); -webkit-background-clip: text; color: transparent;
  filter: drop-shadow(0 2px 0 rgba(0,0,0,.6)); }
.rule { width: 190px; height: 26px; margin: 14px 0 16px; background: url(${DIVIDER}) no-repeat left center / contain; opacity: .9; }
p { font: 400 29px/1.35 'Alegreya Sans', sans-serif; color: #e9e1cb; max-width: 760px; }
p b { color: #f2d98c; font-weight: 500; }
.panel { background: rgba(10,12,17,.82); border: 1px solid rgba(214,178,94,.45); border-radius: 6px; box-shadow: 0 10px 30px rgba(0,0,0,.5); }
`;

const CLASS = { war: '#c69b6d', pal: '#f48cba', hun: '#aad372', rog: '#fff468', pri: '#ffffff', sha: '#0070dd', mag: '#3fc7eb', loc: '#8788ee', dru: '#ff7c0a' };
const die = (v, look = '', size = 74) => {
  const P = { 1: [[2, 2]], 2: [[1, 1], [3, 3]], 3: [[1, 1], [2, 2], [3, 3]], 4: [[1, 1], [3, 1], [1, 3], [3, 3]], 5: [[1, 1], [3, 1], [2, 2], [1, 3], [3, 3]], 6: [[1, 1], [3, 1], [1, 2], [3, 2], [1, 3], [3, 3]] }[v];
  const pip = size * 0.17;
  const pips = P.map(([x, y]) => `<div style="position:absolute;left:${x * size / 4 - pip / 2}px;top:${y * size / 4 - pip / 2}px;width:${pip}px;height:${pip}px;border-radius:50%;background:#2b1c12"></div>`).join('');
  const glow = look === 'pick' ? 'box-shadow:0 0 0 5px #ffd96b,0 0 22px #ffd96b;transform:translateY(-12px)' : look === 'hint' ? 'box-shadow:0 0 0 4px rgba(214,178,94,.55)' : look === 'dim' ? 'opacity:.45' : '';
  return `<div style="position:relative;width:${size}px;height:${size}px;background:linear-gradient(180deg,#f7f0dc,#e2d6b5);border:3px solid #a8946f;border-radius:6px;${glow}">${pips}</div>`;
};

const ARTS = {
  raids: () => `<div class="panel" style="padding:22px 26px;display:grid;grid-template-columns:repeat(4,1fr);gap:16px;width:600px">
    ${[['war', 'pri', 'mag', 'rog', 'hun'], ['pal', 'sha', 'loc', 'mag', 'dru'], ['war', 'pri', 'hun', 'rog', 'mag'], ['dru', 'pal', 'loc', 'sha', 'war']].map((g, i) => `
      <div><div style="font:600 18px Cinzel;color:#e2c06a;margin-bottom:8px">Group ${i + 1}</div>
      ${g.map((c) => `<div style="height:30px;margin-bottom:6px;border-radius:3px;background:linear-gradient(90deg,${CLASS[c]}cc,${CLASS[c]}44);border:1px solid rgba(0,0,0,.6)"></div>`).join('')}</div>`).join('')}
  </div>`,
  chat: () => `<div class="panel" style="padding:24px 28px;width:600px;font:400 23px/1.5 'Alegreya Sans'">
    <div style="font:600 19px Cinzel;color:#e2c06a;margin-bottom:10px">Healers</div>
    <div><span style="color:${CLASS.pri}">Aria Lumen</span><span style="color:#cfc6ae">: who heals UBRS tonight?</span></div>
    <div><span style="color:${CLASS.sha}">Tomas Ventisca</span><span style="color:#cfc6ae">: me, at nine</span></div>
    <div><span style="color:${CLASS.pal}">Gema Fuego</span><span style="color:#cfc6ae">: I'll bring the potions</span></div>
    <div style="color:#8c8676;font-style:italic">Message removed by the moderation</div>
  </div>`,
  arena: () => `<div style="display:flex;align-items:center;gap:30px">
    ${[['Lia Sombra', '1612', 'Gold', CLASS.rog, 72], ['Ramiro Escudo', '1548', 'Silver', CLASS.war, 41]].map(([n, r, t, c, hp]) => `
      <div class="panel" style="width:250px;padding:20px 22px">
        <div style="font:700 24px Cinzel;color:${c}">${n}</div>
        <div style="font:700 50px Cinzel;color:#f2d98c;margin-top:6px">${r}</div>
        <div style="font:500 21px 'Alegreya Sans';color:#e9e1cb">${t}, 14 wins</div>
        <div style="margin-top:14px;height:16px;background:#111;border-radius:2px"><div style="width:${hp}%;height:100%;background:${hp > 50 ? '#56b98a' : '#e3ad54'}"></div></div>
      </div>`).join('<div style="font:700 54px Cinzel;color:#ffd96b;text-shadow:0 0 18px rgba(255,217,107,.6)">VS</div>')}
  </div>`,
  tavern: () => `<div style="width:610px;height:250px;border:10px solid #5c381c;border-radius:6px;background:radial-gradient(ellipse at 50% 40%,#1f5236,#123322);display:flex;align-items:center;justify-content:center;gap:18px;box-shadow:0 10px 30px rgba(0,0,0,.6)">
    ${die(1, 'pick')}${die(1, 'pick')}${die(5, 'hint')}${die(3, 'dim')}${die(6, 'dim')}${die(2, 'dim')}
  </div>`,
  map: () => `<div style="position:relative;width:600px;height:280px;border-radius:6px;border:3px solid #6b5a33;background:radial-gradient(ellipse at 40% 50%,#d8c08a,#a88b55);box-shadow:0 10px 30px rgba(0,0,0,.6);overflow:hidden">
    <svg width="600" height="280" style="position:absolute;inset:0;opacity:.35"><path d="M40 210 C120 140 160 230 260 170 S420 80 560 120" stroke="#5c4320" stroke-width="3" fill="none"/><path d="M60 90 C150 60 240 120 330 80 S480 40 560 60" stroke="#5c4320" stroke-width="2" fill="none" stroke-dasharray="6 6"/><circle cx="430" cy="190" r="60" stroke="#5c4320" stroke-width="2" fill="none"/></svg>
    ${[[120, 150, CLASS.mag], [170, 120, CLASS.war], [310, 140, CLASS.pri], [350, 175, CLASS.hun], [440, 90, CLASS.pal], [470, 200, CLASS.rog]].map(([x, y, c]) => `<div style="position:absolute;left:${x}px;top:${y}px;width:20px;height:20px;border-radius:50%;background:${c};border:3px solid #111"></div>`).join('')}
    <svg width="90" height="90" style="position:absolute;left:220px;top:170px"><path d="M45 6 L72 70 L45 56 L18 70 Z" fill="#ffd96b" stroke="#6b4b10" stroke-width="3" transform="rotate(35 45 45)"/></svg>
  </div>`,
  wanted: () => `<div style="display:flex;align-items:flex-end;gap:40px">
    <div class="panel" style="width:220px;padding:22px;text-align:center">
      <svg width="90" height="96" viewBox="0 0 90 96"><path d="M45 6 C20 6 8 24 8 44 c0 14 8 22 14 26 v14 h12 v-8 h6 v8 h10 v-8 h6 v8 h12 V70 c6-4 14-12 14-26 C82 24 70 6 45 6z" fill="#e47880"/><circle cx="30" cy="46" r="10" fill="#1a0c0c"/><circle cx="60" cy="46" r="10" fill="#1a0c0c"/><path d="M45 56 l-6 10 h12z" fill="#1a0c0c"/></svg>
      <div style="font:700 22px Cinzel;color:#e47880;margin-top:8px">Wanted</div>
      <div style="font:500 21px 'Alegreya Sans';color:#e9e1cb">Bounty 3</div>
    </div>
    <div style="display:flex;align-items:flex-end;gap:10px">
      ${[['2', 120, '#c9ccd2'], ['1', 170, '#ffd96b'], ['3', 90, '#c98a55']].map(([n, h, c]) => `<div style="width:96px;height:${h}px;background:linear-gradient(180deg,${c},${c}88);border:2px solid rgba(0,0,0,.6);border-radius:4px 4px 0 0;display:flex;justify-content:center;padding-top:10px;font:700 40px Cinzel;color:#1a140a">${n}</div>`).join('')}
    </div>
  </div>`,
  crafting: () => `<div class="panel" style="width:600px;padding:26px 30px;font:400 23px 'Alegreya Sans';color:#e9e1cb">
    <div style="font:700 24px Cinzel;color:#e2c06a">Order: 10× Major Healing Potion</div>
    <div style="margin:10px 0 20px">Taken by <span style="color:${CLASS.dru}">Nadia Arco</span>, done, received</div>
    <div style="font:700 24px Cinzel;color:#e2c06a">Campaign: raid potions</div>
    <div style="margin-top:12px;height:22px;background:#111;border-radius:3px;border:1px solid #6b5a33"><div style="width:64%;height:100%;background:linear-gradient(90deg,#a8802f,#f2d98c)"></div></div>
    <div style="margin-top:8px;color:#a9a08a">64 of 100 gold, written down by itself</div>
  </div>`,
  alliance: () => `<div style="display:flex;align-items:flex-start;gap:34px">
    ${[['#7f1d1d', 'E'], ['#1e3a8a', 'T'], ['#14532d', 'O']].map(([c, l]) => `<div style="display:flex;flex-direction:column;align-items:center">
      <div style="width:10px;height:26px;background:#6b5a33"></div>
      <div style="width:130px;height:200px;background:linear-gradient(180deg,${c},${c}cc);border:3px solid #d6b25e;clip-path:polygon(0 0,100% 0,100% 82%,50% 100%,0 82%);display:flex;align-items:center;justify-content:center;font:700 64px Cinzel;color:#f2d98c">${l}</div>
    </div>`).join('')}
  </div>`,
  trust: () => `<svg width="300" height="300" viewBox="0 0 120 120">
    <defs><linearGradient id="g" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stop-color="#fbefc4"/><stop offset=".5" stop-color="#d6b25e"/><stop offset="1" stop-color="#8a6a28"/></linearGradient></defs>
    <path d="M60 6 L104 22 V58 C104 86 84 104 60 114 C36 104 16 86 16 58 V22 Z" fill="#10151d" stroke="url(#g)" stroke-width="6"/>
    <rect x="42" y="56" width="36" height="30" rx="4" fill="url(#g)"/><path d="M48 56 V46 a12 12 0 0 1 24 0 V56" stroke="url(#g)" stroke-width="6" fill="none"/>
  </svg>`,
};

const BANNERS = [
  ['raids', 'Raids that organise themselves', 'Sign-ups by role, <b>raid groups by drag and drop</b>, and «Place in raid» moves everyone into their real group.'],
  ['chat', 'Chat, rooms and moderation', 'Healers, Tanks, Trade and more, with mutes, warnings and cases. <b>Muted players never see who did it.</b>'],
  ['arena', 'Duels that count', 'Every duel <b>records itself</b>: an Elo season, ranks, the champion\'s belt, tournaments, and «Face to face» live.'],
  ['tavern', 'The Tavern', 'Bones, a dice game with the game\'s real <b>/roll</b>: the dice fall, spin and shine when they score. Points only, never gold.'],
  ['map', 'Your guild on the map', 'Guildmates on your <b>world map and minimap</b>, an arrow to follow them, layers, and sightings of enemies.'],
  ['wanted', 'Wanted, honours and rankings', 'Gankers get a <b>bounty</b>, hunters collect it, and the best of the guild wear a golden crest.'],
  ['crafting', 'Crafting, loot and treasury', 'Orders with every step notified, loot notes, and a ledger that <b>writes itself</b>. It never moves gold.'],
  ['alliance', 'Alliances and the war room', 'Sister guilds with shared chat, a leader by vote, <b>signed</b> letters and operations for everyone.'],
  ['trust', 'Built to be trusted', 'Nothing leaves your game until you say yes. <b>No gold, no automation, no betting.</b> Every extra is its own opt-in.'],
];

const banner = ([key, title, text]) => `<div class="banner"><div class="frame"></div><div class="c tl"></div><div class="c tr"></div><div class="c bl"></div><div class="c br"></div>
  <div class="art">${ARTS[key]()}</div><div class="text"><h1>${title}</h1><div class="rule"></div><p>${text}</p></div></div>`;

const hero = `<div class="banner" style="height:640px"><div class="frame"></div><div class="c tl"></div><div class="c tr"></div><div class="c bl"></div><div class="c br"></div>
  <div style="position:absolute;left:110px;top:90px;width:440px;height:440px;background:url(${LOGO}) no-repeat center / contain;filter:drop-shadow(0 16px 40px rgba(0,0,0,.7)) drop-shadow(0 0 40px rgba(214,178,94,.25))"></div>
  <div class="text" style="left:640px">
    <h1 style="font-size:118px">BlazonGuild</h1><div class="rule" style="width:240px"></div>
    <p style="font-size:38px;max-width:820px">Your whole guild, inside <b>World of Warcraft: Forever</b>. No website, no account: addon to addon.</p>
    <div style="display:flex;flex-wrap:wrap;gap:12px;margin-top:30px;max-width:840px">
      ${['Raids', 'Chat', 'Arena', 'Tavern', 'Map', 'Wanted', 'Armory', 'Crafting', 'Treasury', 'Recruitment', 'Alliances', '7 languages'].map((t) => `<span style="font:500 24px 'Alegreya Sans';color:#f2d98c;border:1px solid rgba(214,178,94,.6);background:rgba(10,12,17,.7);padding:6px 16px;border-radius:999px">${t}</span>`).join('')}
    </div>
  </div></div>`;

const browser = await chromium.launch();
const page = await browser.newPage({ viewport: { width: 1600, height: 640 }, deviceScaleFactor: 1 });
const shoot = async (name, html, height) => {
  await page.setViewportSize({ width: 1600, height });
  await page.setContent(`<html><head><style>${CSS}</style></head><body>${html}</body></html>`, { waitUntil: 'networkidle' });
  await page.evaluate(() => document.fonts.ready);
  await page.screenshot({ path: join(OUT, `${name}.png`), clip: { x: 0, y: 0, width: 1600, height } });
  console.log(name);
};
await shoot('hero', hero, 640);
for (const b of BANNERS) await shoot(b[0], banner(b), 400);
await browser.close();
