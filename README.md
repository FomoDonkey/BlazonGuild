# BlazonGuild

**Your guild's home inside World of Warcraft: Forever.** An in-game addon that gives any guild raids with drag-and-drop groups, a bigger chat with rooms and moderation, a duel Arena that records itself, the guild on the map, crafting orders, a treasury that never moves gold, recruitment, rankings and alliances of guilds, all in one window.

- **Download:** [BlazonGuild on CurseForge](https://www.curseforge.com/wow/addons/blazonguild) (WoW: Forever 1.60.1).
- **License:** [MIT](LICENSE). Free to use, study, change and share.
- **Languages:** English, Español, Deutsch, Français, Italiano, Português and Русский.

> *Blazon* is a coat of arms: every guild under its own banner.

---

## What it does

| Part | What you get |
| --- | --- |
| **Overview and roster** | Who's online, the guild's classes and ranks, member profiles and confirmed alts. |
| **Raids, groups and calendar** | Sign-ups by role, raid groups by drag and drop, «Place in raid», looking-for-group, and the next two weeks with the game's own events. |
| **Chat** | Guild and officer chat in a bigger window, rooms (Healers, Tanks, Trade…), and moderation tools. |
| **Board** | Announcements, polls, «To arms!», a speaking queue for meetings and the guild chronicle. |
| **Arena and Tavern** | Duels between guildmates recorded by the game itself, a season ranking, tournaments, fight nights, «Face to face», and a dice game for points (never gold). |
| **Map** | Guildmates zone by zone, an optional position on the world map and minimap, layers and sightings. |
| **Wanted, rankings and honours** | Bounties on enemy players who kill your members, podiums and a guild-vs-guild ranking. |
| **Crafting, treasury and recruitment** | Who can make what and orders, a record of gold given to the treasurers, and a public card for new players. |
| **Armory and PvE** | Shared gear with the game's tooltips, who can enter each raid, and the bosses the guild has killed. |
| **Alliances and war room** | Several guilds joined with a shared chat and leadership, squads and operations. |

Everything travels between the guildmates' addons, inside the game: there is no website, no account and no extra program to install.

## Safe by design

- **No money and no automation:** it never moves gold, never invites, removes or promotes anyone by itself, and has no betting.
- **Privacy first:** nothing leaves your game until you accept a short privacy page, and anything personal (your position, your gear, your BattleTag…) is off until you turn it on.
- **Nobody can type results:** duels, deaths, bosses and gold received are read from the game's own lines.
- **Signed alliances:** changes to an alliance are signed with Ed25519, so they cannot be forged.

## Install

1. Install it with the CurseForge app, or unzip the `BlazonGuild` folder into `World of Warcraft\_forever_\Interface\AddOns`.
2. Log in with a character in a guild and accept the privacy page.
3. Type `/bg`, click the minimap button or press Shift + your guild key.

After updating to a version with new files, close and open the game (a `/reload` does not load new files).

---

## Repository

```
packages/addon/BlazonGuild   The addon (Lua 5.1, WoW: Forever 1.60.1) — this is what players install
packages/addon/tests         Offline checks: a simulated game client (wasmoon) and a network of addons
packages/addon/i18n          Translations (source in Spanish; en, de, fr, it, pt, ru)
apps/api, apps/web           Companion API and website (in development, not needed to play)
packages/types, database, data-providers   Shared code for the API and the website
docs/                        Specifications, the CurseForge page and the addon API for other addons
tools/                       Development tools (demo data, probes, visual QA)
```

### Working on the addon

Requirements: Node ≥ 20.19.

```bash
npm install
cd packages/addon
npm test                 # syntax check + every simulated scenario (about 350 checks)
npm run install:game     # copy the addon into your game's AddOns folder (WOW_FOREVER_DIR=<path to _forever_> if it isn't the default)
```

- Every screen text is written in Spanish in the code and translated through `packages/addon/i18n` (`node tests/i18n-keys.mjs`, then `node tests/i18n-build.mjs`).
- The simulator follows what WoW: Forever really does (for example, it has no global `GetItemInfo`: use `C_Item`). See [ADDON_COMPATIBILITY.md](ADDON_COMPATIBILITY.md).
- Other addons can read BlazonGuild with the player's permission: see [docs/API.md](docs/API.md).

### Working on the website and API

```bash
cp .env.example .env     # BLIZZARD_CLIENT_ID / BLIZZARD_CLIENT_SECRET from develop.battle.net
npm run dev              # API on 127.0.0.1:3001 and website on http://localhost:3000
npm test                 # API, Battle.net client and addon tests
```

## Documentation

[ARCHITECTURE](ARCHITECTURE.md) · [DECISIONS](DECISIONS.md) · [ADDON_COMPATIBILITY](ADDON_COMPATIBILITY.md) · [SECURITY](SECURITY.md) · [DATA_MODEL](DATA_MODEL.md) · [API_SPECIFICATION](API_SPECIFICATION.md) · [DESIGN_SYSTEM](DESIGN_SYSTEM.md) · [ROADMAP](ROADMAP.md) · [CHANGELOG](CHANGELOG.md)

## Credits and license

- **License:** [MIT](LICENSE).
- **Olympus:** many ideas come from the Olympus addon (MIT), rewritten for any guild and without its betting. The Ed25519 signatures and the reading of the game's duel lines are adapted from it; the curve arithmetic is a port of TweetNaCl (public domain). See [THIRD_PARTY_NOTICES.md](packages/addon/BlazonGuild/THIRD_PARTY_NOTICES.md).
- World of Warcraft and Blizzard Entertainment are trademarks of Blizzard Entertainment, Inc. BlazonGuild is a fan-made addon and is not affiliated with or endorsed by Blizzard.

---

## En español

**BlazonGuild es la casa de tu hermandad dentro de World of Warcraft: Forever**: raids con grupos arrastrando, un chat más grande con salas y moderación, una Arena de duelos que se apunta sola, la hermandad en el mapa, encargos de artesanía, una tesorería que nunca mueve oro, reclutamiento, rankings y alianzas de hermandades. Todo pasa entre los addons de los compañeros, dentro del juego, sin web ni cuentas.

- **Descarga:** [BlazonGuild en CurseForge](https://www.curseforge.com/wow/addons/blazonguild).
- **Instalar:** con la app de CurseForge, o descomprime la carpeta `BlazonGuild` en `Interface\AddOns`; entra con un personaje de tu hermandad, acepta la página de privacidad y escribe `/bg`.
- **Licencia:** [MIT](LICENSE): puedes usarlo, estudiarlo, cambiarlo y compartirlo.
