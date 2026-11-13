# BlazonGuild — Arquitectura

> Plataforma **multi-guild** para *World of Warcraft: Forever* (cliente `1.60.1.70862`, interfaz `16001`, mundos sin reinos organizados por *rulesets*).
> **BlazonGuild** es el nombre del producto (antes "FOREVER", que coincidía con el nombre del juego). No está atado a ninguna guild: cualquier guild y cualquier personaje de cualquier región funciona sin configuración.
> Estado: Fase 3 implementada (núcleo backend) y prototipos de Fase 2 conectados a datos reales. Actualizado 2026-11-12.

## 1. Visión general

```
                         ┌────────────────────────────── Fuentes de datos ──────────────────────────────┐
                         │  Battle.net API (profile/dynamic/static-forever-{region})  ← verificada       │
                         │  Addon in-game → SavedVariables → app compañera (Fase 6–7) ← no verificada    │
                         │  WoWCombatLog.txt → motor de analítica (Fase 5)            ← derivada         │
                         │  Miembros (inscripciones, notas)                           ← manual           │
                         └───────────────┬──────────────────────────────────┬──────────────────────────┘
                                         │ OAuth2 client_credentials        │ HTTPS + token personal (Bearer fvr_…)
                                         ▼                                  ▼
┌──────────────────────────────────── BlazonGuild Core (apps/api, Hono + Node 20) ────────────────────────────────┐
│  Middleware: request-id · log JSON · cabeceras seguras · límite de cuerpo · rate limit · sesión · CSRF      │
│  Rutas /v1 (OpenAPI 3.1): auth · guilds · roster · rankings · characters · raids · members · admin · ingest │
│  Servicios: SyncService (guild + roster + personajes, diffs → actividad) · StaticDataService (caché)        │
│             armory (equipo, stats curadas, talentos) · rankings (metodología) · raids (composición)         │
│  RBAC por guild (@blazonguild/types/roles) · auditoría append-only · planificador de resincronización           │
└──────────────────────────────┬──────────────────────────────────────────────────────────────────────────────┘
                               │ Drizzle ORM (una sola instancia, re-exportada por @blazonguild/database)
                               ▼
                 PostgreSQL (producción)  ·  PGlite = PostgreSQL en WASM (desarrollo y tests)
                               ▲
                               │ fetch server-side (cookie + IP reenviadas) y /api/* reescrito al mismo origen
┌──────────────────────────────┴───────────── BlazonGuild Web (apps/web, Next.js 16 + React 19) ──────────────────┐
│  Server Components para datos · Client Components solo para interacción (filtros, planner, búsqueda)         │
│  Shell global: sidebar contraíble / raíl en tablet / barra inferior + hoja "Más" en móvil, ⌘K, avisos      │
│  /  ·  /g/{region}/{guild}[/roster|/raids|/raids/{id}|/rankings|/…]  ·  /c/{region}/{personaje}  ·  /armory │
└──────────────────────────────────────────────────────────────────────────────────────────────────────────────┘
```

## 2. Monorepo

```
GuildCommand/
├── apps/
│   ├── api/            BlazonGuild Core: Hono + @hono/zod-openapi, servicios, CLIs, tests (vitest + PGlite)
│   └── web/            Next.js 16 App Router, Tailwind 3 con tokens CSS, diseño Blizzard Hybrid
├── packages/
│   ├── types/          Dominio compartido: clases/razas/huecos verificados, RBAC, procedencia, DTOs de la API
│   ├── data-providers/ Cliente Battle.net (zod v4, reintentos, semáforo, checksum, normalización de media)
│   └── database/       Esquema Drizzle (PostgreSQL), migraciones SQL, apertura pg/PGlite con candado
├── tools/              screenshots.mjs (QA visual), contrast.mjs (WCAG), dev.mjs, validator/ (sonda API)
├── docs/specs/         Especificaciones de producto aportadas por el autor
└── (tasks/: notas de trabajo internas, no incluidas en la copia pública)
```

Sin microservicios: API y web son dos procesos del mismo producto y se despliegan en el mismo contenedor (ver §8).

## 3. Modelo multi-guild

- Una **guild** se identifica por `(region, slug)`; un **personaje** por `(region, slug)` con slug `nombre-apellido` (los reinos no existen en Forever).
- La primera visita a `/g/{region}/{guild}` importa la guild desde Battle.net (roster inmediato, perfiles en segundo plano). No hay alta manual ni lista blanca.
- Los datos públicos (resumen, roster, armería, rankings) son visibles para cualquiera. Lo operativo (raids, inscripciones, miembros, auditoría) es privado de cada guild y se controla con RBAC por guild.
- Un usuario puede pertenecer a varias guilds con roles distintos. La pertenencia **verificada** nace del login con Battle.net (personajes de la cuenta + rango en la guild → rol), nunca de una autodeclaración.

## 4. Sincronización (SyncService)

| Paso | Qué hace | Procedencia |
| :--- | :--- | :--- |
| Guild | Perfil, ruleset, emblema (URLs de media normalizadas) | `BLIZZARD_API` · VERIFIED |
| Roster | Upsert de personajes; diff con el roster anterior → altas, bajas, ascensos, subidas de nivel | evento `roster-diff` con ventana de detección |
| Personaje | Perfil + equipo + estadísticas + talentos + media + JcJ + profesiones + logros (en paralelo, con tolerancia a fallos parciales) | snapshot con checksum SHA-256 |
| Snapshot | Solo se escribe si cambia el checksum combinado → historial sin duplicados | `character_snapshots` |
| Equipo | Tabla normalizada actual + caché de objetos con icono → evento `ITEM_EQUIPPED` (calidad ≥ poco común) | `equipment-diff` |
| Logros | `recent_events` con su fecha real → eventos `ACHIEVEMENT` | `achievements-recent-events` |

- Concurrencia: semáforo de 8 peticiones simultáneas por región; reintentos con *backoff* en 429/5xx respetando `Retry-After`; *timeout* de 10 s.
- Bloqueos por clave (`guild:eu:forever`) para que dos peticiones no sincronicen lo mismo; `drain()` espera el trabajo en segundo plano antes de cerrar.
- Frescura: roster 30 min, perfiles 6 h (1 h al visitar una armería). El planificador repasa cada 10 min hasta 3 guilds vistas en los últimos 14 días.
- Todas las ejecuciones quedan en `sync_jobs` (estado, estadísticas, error).

## 5. Seguridad y permisos

Resumen (detalle en `SECURITY.md`): contraseñas con scrypt (parámetros OWASP), sesiones opacas de 256 bits guardadas como SHA-256, cookies `httpOnly` + `SameSite=Lax` (+ `__Host-` y `Secure` en producción), CSRF por tipo de contenido y `Origin`, rate limiting, RBAC por guild con suelos no configurables, auditoría de toda acción administrativa, proxy de media con lista blanca de host.

## 6. Web

- **Datos:** los Server Components llaman a la API por red interna (`API_INTERNAL_URL`) reenviando cookie e IP; el navegador usa `/api/*`, reescrito por Next al mismo origen (cookies de primera parte, CSRF trivial).
- **Diseño:** tokens CSS RGB en `globals.css` (oscuro y claro validados con `tools/contrast.mjs`), Marcellus (display) + IBM Plex Sans (interfaz y cifras tabulares), heráldica real de cada guild. Ver `DESIGN_SYSTEM.md`.
- **Estados:** `loading.tsx` (esqueletos), `error.tsx`, `not-found.tsx` y estados vacíos explicativos en cada módulo; los módulos de fases futuras dicen qué incluirán y de qué fuente saldrá cada dato.

## 7. Procedencia (ADR-003)

Cada valor de juego lleva `{ source, status, confidence, collectedAt, endpoint?, checksum?, method? }`. Battle.net Forever se trata como dato de servidor verificado con confianza 0,9 (endpoints no documentados oficialmente pero estables, ver ADR-010). Lo estimado (rol a partir de talentos) se etiqueta como estimado. Lo no disponible (DPS, HPS, asistencia) se muestra como no disponible, nunca con cifras inventadas.

## 8. Despliegue previsto (Fase 9)

App con servidor → **LXC propio en Proxmox** (un contenedor para todo el producto: web + API + PostgreSQL) + **Cloudflare Tunnel con nombre** (`cloudflared` dentro del CT → `localhost:3000`). La API escucha solo en `127.0.0.1:3001` con `TRUST_PROXY=true`. Pendiente de confirmar con el autor.
