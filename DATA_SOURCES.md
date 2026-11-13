# BlazonGuild — Fuentes de datos y procedencia

## 1. Battle.net API de WoW: Forever (verificada en vivo el 2026-11-09 y el 2026-11-12)

Namespaces: `profile-forever-{region}`, `dynamic-forever-{region}`, `static-forever-{region}` (la API fija el estático a una build, p. ej. `static-1.60.1_70399-forever-eu`; el cliente lo aprende de las respuestas). Locale `es_ES`.

| Recurso | Endpoint | Estado | Notas reales |
| :--- | :--- | :---: | :--- |
| Token | `POST oauth.battle.net/token` | ✅ | client_credentials; authorization_code para el login |
| Rulesets | `/data/wow/ruleset/index`, `/{id}` | ✅ | 1 JcJ, 2 Normal, 3 Juego de rol, 15 Juego de rol JcJ |
| Guild | `/data/wow/guild/{slug}` | ✅ | id, facción, ruleset, `member_count`, `created_timestamp`, emblema |
| Roster | `/data/wow/guild/{slug}/roster` | ✅ | solo índice de rango (sin nombres de rango) |
| Actividad de guild | `/data/wow/guild/{slug}/activity` | ⚠️ vacío | se deriva de los diffs de sincronización |
| Logros de guild | `/data/wow/guild/{slug}/achievements` | ⚠️ vacío | — |
| Perfil de personaje | `/profile/wow/character/{nombre-apellido}` | ✅ | nivel, clase, raza, guild, `last_login_timestamp`, iLvl; algunos dan 404 (perfil privado o borrado) |
| Equipo | `…/equipment` | ✅ | tooltips completos, conjuntos, transfiguración; ojo: `spell.name: null`, líneas sin `type`, `is_hidden` |
| Estadísticas | `…/statistics` | ✅ | incluye campos de retail a 0 (maestría, versatilidad…) que se descartan |
| Talentos | `…/specializations` | ✅ | 3 árboles clásicos con `spent_points` y rangos |
| Árbol estático | `/data/wow/talent-tree/{tree}/playable-specialization/{spec}` | ✅ | columnas numeradas globalmente (1–4, 7–10, 14–17): se normalizan |
| Media | `…/character-media` | ✅ | `main-raw` (PNG 1600×1200 transparente), `avatar` |
| JcJ | `…/pvp-summary` | ✅ | `honorable_kills`, `pvp_rank` (sistema de honor clásico) |
| Profesiones | `…/professions` | ✅ | puntos/máximo por nivel |
| Logros | `…/achievements` | ✅ | `recent_events` con fechas reales |
| Encuentros | `…/encounters/raids`, `/dungeons` | ⚠️ vacío | aún sin datos en Forever |
| Media estática | `/data/wow/media/{item,spell,playable-class,playable-specialization,guild-crest/…}` | ✅ | URLs `forever-xx/(icons|guild)` con 403 → se normalizan a `xx/` (ADR-012) |
| Objeto | `/data/wow/item/{id}` | ❌ 404 | no disponible en Forever; el tooltip sale del equipo del personaje |
| Cuenta del usuario | `/profile/user/wow` | 🔒 | requiere el token del usuario (login con Battle.net) |
| Temporadas JcJ | `/data/wow/pvp-season/index` | ❌ 404 | no existe en Forever |

Razas reales: Humano, Enano, Elfo de la noche, Gnomo, Orco, No-muerto, Tauren, Trol y las dos exclusivas de Forever, **Cielonato de la Orden Eminente** (95) y **Cielonato Formavientos** (96). Las restricciones de clase por facción cambian respecto al clásico (por ejemplo, existen paladines no-muertos).

## 2. Procedencia en el modelo

```ts
type ProvenanceSource = 'BLIZZARD_API' | 'ADDON_COLLECTED' | 'COMBAT_LOG' | 'MANUAL' | 'CALCULATED' | 'ESTIMATED' | 'UNAVAILABLE';
type VerificationStatus = 'VERIFIED' | 'UNVERIFIED' | 'DERIVED' | 'HEURISTIC' | 'UNAVAILABLE';
interface Provenance { source; status; confidence /*0..1*/; collectedAt; endpoint?; namespace?; checksum?; method?; processorVersion?; notes? }
```

| Origen | Estado | Confianza | Ejemplos |
| :--- | :--- | :---: | :--- |
| Battle.net | VERIFIED | 0,90 | roster, equipo, stats, talentos, JcJ, logros |
| Diffs de sincronización | DERIVED | 0,90 | altas, bajas, rangos, niveles, equipo nuevo (con ventana de detección) |
| Rol a partir de talentos | HEURISTIC | — | filtros y rankings por rol, siempre etiquetados como "estimado" |
| Addon (Fase 6–7) | UNVERIFIED | — | lotes en `ingest_batches` |
| Registro de combate (Fase 5) | DERIVED | — | DPS, HPS, supervivencia |
| Inscripciones | MANUAL | — | asistencia declarada (no prueba asistencia real) |

## 3. Sonda de validación
`npm run probe:api` (`tools/validator/probe-blizzard-api.mjs`) vuelve a consultar los endpoints principales con las credenciales de `.env` y escribe `tools/validator/VALIDATION_REPORT.md`.
