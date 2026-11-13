# BlazonGuild Core API — especificación v1.0.0

> Generado automáticamente desde el documento OpenAPI 3.1 (`GET /v1/openapi.json`, referencia interactiva en `/v1/docs`).
> No editar a mano: `npx tsx src/cli/gen-api-spec.ts ../../API_SPECIFICATION.md` desde `apps/api`.

API de la plataforma multi-hermandad BlazonGuild para World of Warcraft: Forever. Todas las respuestas de datos de juego incluyen metadatos de procedencia (fuente, estado de verificación, confianza, fecha de captura).

## Convenciones

- **Versionado:** prefijo `/v1`. Cambios incompatibles irán en `/v2`.
- **Autenticación:** cookie de sesión `httpOnly` (`forever_session`, `__Host-forever_session` en producción) o `Authorization: Bearer fvr_…` (tokens personales, solo ingesta).
- **CSRF:** las peticiones que modifican datos deben ser `application/json`; si el navegador envía `Origin`, debe ser el de la web.
- **Errores:** `{ "error": { "code": "…", "message": "…", "details"?: … } }` con el código HTTP adecuado (400 validación, 401, 403, 404, 409, 413, 415, 429, 502).
- **Paginación:** `page` y `pageSize` → `{ items, total, page, pageSize }`.
- **Límites:** 600 peticiones/min por IP; 10/min en login y registro; importación de hermandades nuevas 20/hora; consultas de personajes 60/hora por usuario o IP.
- **Procedencia:** las respuestas con datos de juego incluyen `provenance` (fuente, estado, confianza, fecha de captura).
- **Contratos TypeScript:** `packages/types/src/dto.ts`.

## Admin

| Método | Ruta | Descripción |
| :--- | :--- | :--- |
| `GET` | `/v1/admin/overview` | Métricas de la plataforma |
| `GET` | `/v1/admin/sync-jobs` | Trabajos de sincronización recientes — query: `page` |
| `GET` | `/v1/admin/audit` | Auditoría global — query: `page` |
| `POST` | `/v1/admin/characters/link` | Vincular manualmente un personaje a un usuario (sin verificación Battle.net, auditado) — cuerpo JSON |

## Armory

| Método | Ruta | Descripción |
| :--- | :--- | :--- |
| `GET` | `/v1/characters/{region}/{slug}` | Armería: identidad, equipo (19 huecos), estadísticas, talentos, profesiones, JcJ e historial |
| `POST` | `/v1/characters/{region}/{slug}/sync` | Actualizar el personaje desde Battle.net |

## Auth

| Método | Ruta | Descripción |
| :--- | :--- | :--- |
| `POST` | `/v1/auth/register` | Crear cuenta con email y contraseña — cuerpo JSON |
| `POST` | `/v1/auth/login` | Iniciar sesión — cuerpo JSON |
| `POST` | `/v1/auth/logout` | Cerrar sesión |
| `POST` | `/v1/auth/logout-all` | Cerrar todas las sesiones de la cuenta |
| `GET` | `/v1/auth/me` | Usuario actual, hermandades y personajes |
| `GET` | `/v1/auth/providers` | Métodos de inicio de sesión disponibles |
| `GET` | `/v1/auth/battlenet/start` | Redirige a Battle.net para verificar personajes — query: `returnTo`, `region` |
| `GET` | `/v1/auth/battlenet/callback` | Callback OAuth de Battle.net — query: `code`, `state`, `error` |
| `GET` | `/v1/me/tokens` | Tokens personales |
| `POST` | `/v1/me/tokens` | Crear token para la app compañera (solo se muestra una vez) — cuerpo JSON |
| `DELETE` | `/v1/me/tokens/{id}` | Revocar token |
| `PUT` | `/v1/me/main` | Marcar personaje principal — cuerpo JSON |

## Groups

| Método | Ruta | Descripción |
| :--- | :--- | :--- |
| `GET` | `/v1/guilds/{region}/{slug}/groups` | Grupos de mazmorra abiertos (miembros) |
| `POST` | `/v1/guilds/{region}/{slug}/groups` | Crear un grupo de mazmorra (el creador entra con su personaje y rol) — cuerpo JSON |
| `PUT` | `/v1/groups/{id}/join` | Unirse a un grupo en un rol libre — cuerpo JSON |
| `DELETE` | `/v1/groups/{id}/join` | Salir del grupo (si sale el creador, el grupo se cierra) |
| `POST` | `/v1/groups/{id}/close` | Cerrar el grupo (creador o liderazgo de banda) |

## Guilds

| Método | Ruta | Descripción |
| :--- | :--- | :--- |
| `GET` | `/v1/guilds` | Hermandades seguidas por BlazonGuild (más vistas primero) — query: `region`, `limit` |
| `GET` | `/v1/guilds/{region}/{slug}` | Centro de mando: identidad, estadísticas, actividad y próximas raids. Importa la hermandad si es la primera visita. |
| `GET` | `/v1/guilds/{region}/{slug}/roster` | Roster con filtros, orden y paginación — query: `q`, `classIds`, `ranks`, `role`, `minLevel`, `maxLevel`, `activeDays`, `sort`, `dir`, `page`, `pageSize` |
| `GET` | `/v1/guilds/{region}/{slug}/activity` | Actividad reciente (derivada de sincronizaciones y logros) — query: `before`, `limit` |
| `POST` | `/v1/guilds/{region}/{slug}/sync` | Forzar sincronización completa (oficiales) |

## Ingestion

| Método | Ruta | Descripción |
| :--- | :--- | :--- |
| `POST` | `/v1/ingest/addon` | Subida de SavedVariables del addon (Bearer token). Se almacena como no verificada; procesado en Fase 6–7. — cuerpo JSON |

## Membership

| Método | Ruta | Descripción |
| :--- | :--- | :--- |
| `GET` | `/v1/guilds/{region}/{slug}/members` | Miembros de la plataforma y sus roles |
| `PUT` | `/v1/guilds/{region}/{slug}/members/{userId}` | Asignar rol de plataforma (auditado) — cuerpo JSON |
| `GET` | `/v1/guilds/{region}/{slug}/settings` | Ajustes actuales, rangos presentes en el roster y permisos efectivos (gestión) |
| `PATCH` | `/v1/guilds/{region}/{slug}/settings` | Nombres de rango, roles por rango, permisos y descripción — cuerpo JSON |
| `GET` | `/v1/guilds/{region}/{slug}/audit` | Registro de auditoría de la hermandad — query: `page` |

## Platform

| Método | Ruta | Descripción |
| :--- | :--- | :--- |
| `GET` | `/v1/health` | Estado del servicio |
| `GET` | `/v1/search` | Búsqueda global de hermandades y personajes — query: `q`, `region` |
| `GET` | `/v1/media` | Proxy de imágenes de render.worldofwarcraft.com (con caché) — query: `url` |
| `GET` | `/v1/notifications` | Mis notificaciones |
| `POST` | `/v1/notifications/read-all` | Marcar todas como leídas |

## Raids

| Método | Ruta | Descripción |
| :--- | :--- | :--- |
| `GET` | `/v1/guilds/{region}/{slug}/raids` | Raids de la hermandad (miembros) — query: `scope` |
| `POST` | `/v1/guilds/{region}/{slug}/raids` | Crear raid (líder de banda o superior) — cuerpo JSON |
| `GET` | `/v1/raids/{id}` | Detalle de raid con inscripciones y composición |
| `PATCH` | `/v1/raids/{id}` | Editar o cambiar estado de la raid — cuerpo JSON |
| `PUT` | `/v1/raids/{id}/signup` | Inscribirse / cambiar estado (confirmado, tentativo, rechazado) — cuerpo JSON |
| `DELETE` | `/v1/raids/{id}/signup` | Retirar mi inscripción |
| `PUT` | `/v1/raids/{id}/composition` | Guardar la composición (grupos, banquillo, roles) — cuerpo JSON |

## Rankings

| Método | Ruta | Descripción |
| :--- | :--- | :--- |
| `GET` | `/v1/guilds/{region}/{slug}/rankings/{metric}` | Clasificación con metodología explícita — query: `classId`, `role`, `minLevel`, `limit` |

