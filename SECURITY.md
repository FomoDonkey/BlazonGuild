# BlazonGuild — Seguridad

## Autenticación
- **Contraseñas:** scrypt de `node:crypto` (N=2^15, r=8, p=3, clave de 64 bytes, sal de 16 bytes), formato `scrypt$N$r$p$sal$hash`. Comparación en tiempo constante. Con un email inexistente se verifica contra un hash señuelo, para que el tiempo de respuesta no revele qué cuentas existen.
- **Sesiones:** token aleatorio de 32 bytes en cookie `httpOnly`, `SameSite=Lax`, `Path=/`; en producción `Secure` y prefijo `__Host-`. En base de datos solo se guarda su SHA-256. Caducidad deslizante de 30 días; "cerrar todas las sesiones" disponible.
- **Battle.net OAuth (authorization_code):** `state` firmado con HMAC y caducidad de 10 min en cookie `httpOnly`. El `returnTo` solo admite rutas relativas, para evitar redirecciones abiertas. Los personajes de la cuenta se marcan como verificados; los que ya no están en la cuenta pierden la verificación.
- **Tokens personales** (`fvr_…`): solo se muestran al crearlos, se guardan como SHA-256, son revocables y por defecto solo permiten `/v1/ingest/*`.

## Autorización (RBAC)
- Rol de plataforma `ADMIN | USER` y rol **por guild** `GUILD_MASTER > OFFICER > RAID_LEADER > RAIDER > MEMBER > VISITOR`.
- Matriz de permisos en `packages/types/src/roles.ts`, configurable por guild (`settings.permissions`) con **suelos no rebajables**: ajustes y gestión de miembros como mínimo oficial; auditoría como mínimo líder de banda.
- Nadie puede asignar un rol igual o superior al suyo ni modificar a alguien de su rango. El rol de GM solo lo dan la verificación de Battle.net (rango 0) o un administrador.
- Las inscripciones exigen que el personaje esté vinculado a la cuenta **y** pertenezca a la guild de la raid.

## Protección de peticiones
- **CSRF:** los métodos que modifican datos con cookie exigen `Content-Type: application/json` (un formulario de otro sitio no puede enviarlo sin *preflight*, y la API no concede CORS) y, si hay `Origin`, debe ser `WEB_ORIGIN`. Las peticiones con Bearer no llevan credenciales ambientales.
- **Rate limiting** (en memoria, una instancia): 600/min por IP global; 10/min en login y registro; 20/h importaciones de guilds nuevas; 60/h consultas de personajes; resincronización manual de guild como mucho cada 2 min.
- **Validación:** toda entrada pasa por esquemas zod (OpenAPI); límite de cuerpo de 2,5 MB (2 MB por lote de ingesta).
- **Cabeceras:** `hono/secure-headers` en la API (CSP `default-src 'none'`, `frame-ancestors 'none'`, nosniff, CORP); en la web, `X-Frame-Options: DENY`, `nosniff`, `Referrer-Policy` y `Permissions-Policy`, sin `X-Powered-By`.
- **SSRF:** el proxy `/v1/media` solo acepta `https://render.worldofwarcraft.com`, sin puerto ni credenciales, solo `.png`/`.jpg` y como mucho 5 MB, sin seguir redirecciones.
- **Inyección SQL:** todas las consultas son parametrizadas (Drizzle); el comodín de las búsquedas `ILIKE` se escapa.
- **XSS:** React escapa toda salida; el único `dangerouslySetInnerHTML` es el script estático de tema.
- **Red:** la API escucha solo en `127.0.0.1` y confía en `X-Forwarded-For` únicamente con `TRUST_PROXY=true` (detrás de Next o de cloudflared).

## Datos no fiables
Nada que envíen los clientes se presenta como verificado: las subidas del addon son `ADDON_COLLECTED`/`UNVERIFIED`; los vínculos de administrador son `verified=false`; los roles estimados por talentos se etiquetan como estimados.

## Auditoría
`audit_logs` registra registro, accesos fallidos, vinculación de Battle.net, tokens, creación y edición de raids, cambios de composición, roles, ajustes de guild, sincronizaciones manuales, vínculos manuales e ingestas, con IP y agente de usuario.

## Secretos
`.env` no se versiona. En producción, `SESSION_SECRET` es obligatorio: la API se niega a arrancar con el valor de desarrollo.

## Pendiente (Fase 8)
Rate limiting compartido si hay varias réplicas; CSP estricta en la web con *nonces*; política de retención de logs y auditoría; copias de seguridad automáticas de PostgreSQL verificadas con restauración; pruebas de penetración.
