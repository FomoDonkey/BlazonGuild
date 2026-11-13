# BlazonGuild — Tablero de tareas

Leyenda: ✅ completado y verificado · 🟡 en curso · ⛔ bloqueado · ⏳ planificado · ❌ no viable técnicamente

## Fases
- ✅ **Fase 0 — Descubrimiento:** entorno, cliente `1.60.1.70862` (interfaz 16001), namespaces `*-forever-*`, matriz de viabilidad.
- ✅ **Fase 1 — Arquitectura:** monorepo, contratos, decisiones (revisada el 2026-11-12: multi-guild, Drizzle/PostgreSQL, Hono).
- ✅ **Fase 2 — Dirección de arte y prototipos** (rehecha el 2026-11-12 sobre datos reales; los prototipos anteriores mostraban datos inventados).
- ✅ **Fase 3 — BlazonGuild Core.**
- 🟡 **Fase 6 — Addon (adelantada, ADR-016):** sonda ejecutada; addon 0.1.0 con ventana, Resumen y La hermandad en vivo.
- 🟡 **Fase 4 — Módulos web** (administración, mazmorras, JcJ, JcE y calendario hechos) · ⏳ Fase 5 — Analítica · ⏳ Fase 6 — Addon · ⏳ Fase 7 — Integración y app compañera · ⏳ Fase 8 — QA y hardening · ⏳ Fase 9 — Producción.

## Fase 3 — BlazonGuild Core
- ✅ Esquema PostgreSQL de 18 tablas con migraciones (Drizzle); PGlite con candado de proceso.
- ✅ Cliente Battle.net: zod v4 tolerante, validación objeto a objeto, reintentos con 429/`Retry-After`, semáforo, *timeout*, checksum, normalización de media.
- ✅ Sincronización de guild, roster y personaje: snapshots por checksum, equipo normalizado, caché de objetos con iconos y feed de actividad derivado (altas, bajas, rangos, niveles, equipo, logros).
- ✅ Autenticación: registro e inicio de sesión (scrypt), sesiones opacas, cerrar todas las sesiones, tokens personales.
- ✅ Battle.net OAuth: inicio, callback, propiedad verificada y roles por rango; probado de extremo a extremo con la cuenta real del autor (2026-11-12).
- ✅ RBAC por guild con anulaciones configurables y suelos; prevención de escalada de privilegios.
- ✅ API v1 (47 operaciones, OpenAPI 3.1): guilds, roster con filtros, orden y paginación, actividad, rankings con metodología, armería, raids (CRUD, inscripción, composición), miembros y roles, ajustes, auditoría, búsqueda, notificaciones, proxy de media, ingesta del addon, administración.
- ✅ Seguridad: CSRF, rate limiting, cabeceras, límites de cuerpo, SSRF, auditoría.
- ✅ Planificador de resincronización y CLIs (`sync:guild`, `admin:create`, `dev-verification`, `gen-api-spec`).
- ✅ Tests: 27 de API + 8 del cliente; probados también contra Battle.net real (2 guilds, 90 personajes, 743 objetos).

## Fase 2 — Prototipos (datos reales)
- ✅ Tokens oscuro y claro, 134 pares AA validados; Marcellus + IBM Plex Sans.
- ✅ Shell: sidebar contraíble, raíl en tablet, barra inferior + "Más" en móvil, breadcrumbs, búsqueda ⌘K, notificaciones, menú de usuario y tema.
- ✅ Portada de exploración · Resumen de guild (heráldica real) · La hermandad (tabla y directorio) · Armería (render, 19 huecos, tooltip, atributos, talentos, profesiones, JcJ, logros, historial) · Rankings · Raid Center (lista, creación, inscripción, planificador con arrastre, teclado y toque).
- ✅ Estados de carga, vacío, error y 404; páginas honestas para los módulos de fases futuras.
- ✅ Verificación: capturas a 1440 px y 390 px en ambos temas, sin scroll horizontal ni errores de consola; E2E del planificador; build de producción servido y capturado.

## Fase 4 — Módulos web (en curso)
- ✅ Administración: miembros y roles, nombres de rango y rol por rango, permisos con suelos, auditoría y sincronizaciones (`GET /settings` nuevo).
- ✅ Mazmorras: directorio de 20 mazmorras clásicas con arte oficial y miembros en nivel; buscador de grupo (crear, unirse por rol, salir, cerrar; caduca a las 4 h del inicio o a las 12 h). Tablas `group_listings` y `group_members`, 5 operaciones nuevas y test.
- ✅ JcJ: muertes con honor y rango por miembro y por clase (datos de `pvp-summary`).
- ✅ JcE: miembros por tramo de nivel, preparación por banda (con nivel suficiente y raids completadas), progreso por jefe mostrado como "sin datos" hasta la Fase 5, historial de raids.
- ✅ Calendario: mes completo en escritorio y agenda en móvil, con las raids de la guild.
- ✅ Sincronización progresiva de guilds grandes: detalle por lotes de 80 personajes (los nunca vistos primero) y el planificador continúa hasta completar.
- ⏳ Perfil de miembro y privacidad · Comparador de personajes · Gráficas de historial.
- ⏳ Notificaciones en tiempo real (opcional: Discord).
