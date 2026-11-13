# BlazonGuild — Modelo de datos

> 20 tablas. PostgreSQL 17 (PGlite en desarrollo). Fuente de verdad: `packages/database/src/schema.ts`; migraciones SQL en `packages/database/migrations` (`npm run db:generate`). Se aplican solas al arrancar la API.

## Diagrama entidad-relación

```
users ─┬─< sessions                      guilds ─┬─< guild_memberships >── users
       ├─< api_tokens                            ├─< characters (guild_id, guild_rank)
       ├─< notifications >── guilds              ├─< activity_events >── characters
       └─< characters (owner_user_id)            ├─< raids ─< raid_signups >── characters, users
                                                 ├─< group_listings ─< group_members >── characters, users
                                                 └─< audit_logs >── users
characters ─┬─< character_snapshots   (historial inmutable, único por checksum)
            ├─< character_equipment   (equipo actual normalizado, PK personaje+hueco)
            └─< encounter_metrics     (Fase 5: métricas de registros de combate)
items (caché de objetos: nombre, calidad, icono) · static_cache (árboles de talentos, iconos, emblemas)
sync_jobs (cada sincronización) · ingest_batches (subidas del addon, únicas por checksum)
```

## Tablas

| Tabla | Propósito | Claves e índices relevantes |
| :--- | :--- | :--- |
| `users` | Cuenta de plataforma. `platform_role` ADMIN/USER. Email en minúsculas; `password_hash` nulo si solo usa Battle.net | únicos: `email`, `battlenet_id` |
| `sessions` | Sesiones opacas; `id` = SHA-256 del token | `user_id`, `expires_at` |
| `api_tokens` | Tokens personales para la app compañera (`scopes`, `revoked_at`) | único: `token_hash` |
| `guilds` | Guild de Battle.net: facción, ruleset, emblema (`crest` JSONB), `settings` JSONB (nombres de rango, rol por rango, permisos), estado de sync | únicos: `(region, slug)`, `(region, blizzard_id)` |
| `guild_memberships` | Usuario ↔ guild con `role` (GM…MEMBER), `verified`, `source` (BATTLENET/ADMIN/INVITE) | único: `(guild_id, user_id)` |
| `characters` | Personaje realmless: clase, raza, nivel, guild + rango, iLvl, logros, MCH, talentos (`talent_split`), profesiones, media, propietario y verificación, estado de detalle | único: `(region, slug)`; `guild_id`, `owner_user_id`, `class_id`, `name` |
| `character_snapshots` | Captura completa (perfil, equipo, stats, talentos, profesiones, JcJ, logros) + `provenance` | único: `(character_id, checksum)` |
| `character_equipment` | Equipo vigente por hueco con `equipped_since` | PK `(character_id, slot)`; `item_id` |
| `items` | Caché de objetos vistos (nombre, calidad, icono) | PK `id` de Blizzard |
| `static_cache` | Documentos del namespace estático con TTL | PK `key` |
| `activity_events` | Feed derivado (altas, bajas, rangos, niveles, equipo, logros) con `provenance` | único: `dedupe_key`; `(guild_id, occurred_at)` |
| `raids` | Convocatoria: instancia, inicio/fin, plazas, nivel mínimo, notas, líder, estado | `(guild_id, starts_at)` |
| `raid_signups` | Inscripción: estado, rol, comentario, grupo y posición | únicos: `(raid_id, character_id)`, `(raid_id, user_id)`, `(raid_id, group_no, slot)` |
| `group_listings` | Grupo de mazmorra del buscador: clave de mazmorra, nota, inicio opcional, líder, estado OPEN/CLOSED, caducidad | `(guild_id, status, expires_at)` |
| `group_members` | Miembro de un grupo: personaje y rol (TANK/HEALER/DPS) | PK `(listing_id, user_id)` |
| `audit_logs` | Registro append-only (actor, acción, entidad, cambios antes/después, IP, agente) | `created_at`, `(guild_id, created_at)` |
| `sync_jobs` | Ejecución de sincronización (GUILD/CHARACTER, disparador, estado, estadísticas, error) | `created_at`, `(region, target)` |
| `ingest_batches` | Lote subido por el addon (payload JSONB, versión, build del cliente, estado) | único: `checksum` |
| `notifications` | Avisos por usuario (p. ej. nueva raid) | `(user_id, created_at)` |
| `encounter_metrics` | Reservada para la Fase 5 (daño, sanación, muertes por encuentro) | `character_id` |

## Reglas de integridad
- Borrar una guild borra en cascada sus raids, eventos y membresías; sus personajes quedan con `guild_id = NULL`.
- Los snapshots solo se insertan cuando cambia el checksum combinado de los 8 endpoints → el historial no se infla.
- `activity_events.dedupe_key` (p. ej. `level:<char>:45`, `ach:<char>:<logro>`) impide eventos duplicados aunque el mismo cambio se observe dos veces.
- Los grupos del buscador caducan solos (`expires_at` = inicio + 4 h, o creación + 12 h sin hora); las plazas por rol salen de la composición clásica (1 tanque, 1 sanador y 3 de daño en grupos de 5).
- El índice único `(raid_id, group_no, slot)` garantiza que dos jugadores no ocupen la misma posición; la composición se guarda en una transacción que primero libera las posiciones.
