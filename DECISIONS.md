# Architecture Decision Records (ADR)

## ADR-001: Monorepo para el ecosistema
- **Fecha:** 2026-11-09 · **Estado:** Aceptada (revisada 2026-11-12)
- **Decisión:** un único repositorio con workspaces npm: `apps/web`, `apps/api`, `packages/types`, `packages/data-providers`, `packages/database` (más adelante `packages/addon`, `packages/analytics`, `apps/companion`).
- **Consecuencias:** contratos TypeScript compartidos entre API y web, cambios atómicos.

## ADR-002: Sincronización in-game por archivos
- **Fecha:** 2026-11-09 · **Estado:** Aceptada
- **Contexto:** el sandbox Lua de WoW no permite red.
- **Decisión:** el addon escribe `SavedVariables`; una app compañera sube el contenido a `POST /v1/ingest/addon` con token personal, checksum SHA-256 y deduplicación. Lo recibido es `ADDON_COLLECTED` + `UNVERIFIED`.

## ADR-003: Procedencia obligatoria y confianza por niveles
- **Fecha:** 2026-11-09 · **Estado:** Aceptada (contrato simplificado 2026-11-12)
- **Decisión:** todo dato de juego lleva `Provenance { source, status, confidence, collectedAt, … }` (`packages/types/src/provenance.ts`). La UI muestra fuente y antigüedad; lo estimado se etiqueta; lo no disponible no se rellena.

## ADR-004: Blizzard Hybrid y densidad adaptativa
- **Fecha:** 2026-11-09 · **Estado:** Aceptada. Especificación completa en `docs/specs/ART_DIRECTION_V1.md`.

## ADR-005: Plataforma multi-guild (no una guild concreta)
- **Fecha:** 2026-11-12 · **Estado:** Aceptada (requisito explícito del autor)
- **Contexto:** el trabajo previo asumía una guild llamada "Forever" (una guild real de terceros que Gemini eligió por coincidencia de nombre). El autor aclara que el addon se publicará para que cualquier guild lo use y que la web debe permitir consultar cualquier guild.
- **Decisión:** guild = tenant identificado por `(region, slug)`; importación automática en la primera visita; RBAC y datos operativos por guild; un usuario puede estar en varias guilds.
- **Consecuencias:** nada de configuración por guild en `.env`; rate limits de importación; PostgreSQL justificado por volumen.

## ADR-006: Drizzle ORM + PostgreSQL (PGlite en desarrollo y tests)
- **Fecha:** 2026-11-12 · **Estado:** Aceptada. Sustituye el esquema Prisma + SQLite heredado (nunca llegó a generarse ni usarse).
- **Contexto:** SQLite no tiene enums/JSONB reales y Prisma no permite cambiar de proveedor por entorno; no hay Postgres ni Docker activo en el equipo de desarrollo.
- **Decisión:** esquema `pgTable` de Drizzle, migraciones SQL generadas con `drizzle-kit`, `node-postgres` en producción y **PGlite** (PostgreSQL real compilado a WASM) en desarrollo y tests. La URL decide el driver (`postgres://…` / `pglite:<dir>` / `pglite:memory`).
- **Consecuencias:** mismo dialecto en todos los entornos, tests de integración en memoria sin servicios externos. PGlite es mono-proceso → candado PID en el directorio de datos.

## ADR-007: Hono + OpenAPI para BlazonGuild Core
- **Fecha:** 2026-11-12 · **Estado:** Aceptada. Sustituye Express (declarado pero sin código).
- **Decisión:** `hono` + `@hono/zod-openapi`: una sola definición zod da validación, tipos y documento OpenAPI 3.1 (`/v1/openapi.json`, `/v1/docs`). `API_SPECIFICATION.md` se genera desde ahí.

## ADR-008: Sesiones opacas, scrypt y verificación por Battle.net
- **Fecha:** 2026-11-12 · **Estado:** Aceptada
- **Decisión:** contraseñas con `node:crypto` scrypt (N=2^15, r=8, p=3; sin dependencias nativas); sesiones opacas de 32 bytes guardadas como SHA-256 (revocables, a diferencia de JWT); propiedad de personajes **solo** vía Battle.net OAuth (`/profile/user/wow`) o asignación auditada de un administrador. Los roles verificados derivan del rango en la guild (0 → GM, 1 → oficial, resto → miembro; configurable por guild).

## ADR-009: Next.js 16 + React 19
- **Fecha:** 2026-11-12 · **Estado:** Aceptada
- **Contexto:** Next 14.2.35 tenía avisos críticos (incluida RCE en servidores Windows en el optimizador de imágenes).
- **Decisión:** `next@16.4.3` (≥ 2 semanas de antigüedad y fuera del rango vulnerable), React 19.3. Tailwind se mantiene en 3.4 para no mezclar migraciones.

## ADR-010: Confianza 0,9 para Battle.net Forever
- **Fecha:** 2026-11-12 · **Estado:** Aceptada
- **Decisión:** los namespaces `*-forever-*` no aparecen en la documentación pública de Blizzard pero responden con esquemas estables (sondeados el 9 y el 12 de noviembre). Se tratan como datos de servidor `VERIFIED` con confianza 0,9, validados con esquemas tolerantes (`z.looseObject`, `nullish`) y validación objeto a objeto en el equipo.

## ADR-011: Tipografía Marcellus + IBM Plex Sans
- **Fecha:** 2026-11-12 · **Estado:** Aceptada
- **Decisión:** Marcellus (serif de remates abiertos en la tradición de Friz Quadrata, la letra de la interfaz de WoW) para titulares; IBM Plex Sans para interfaz, tablas y **todas las cifras** (Marcellus dibuja el "1" como una "I" romana). Ambas OFL vía `next/font` (autoalojadas en el build).

## ADR-012: Normalización y proxy de media de Blizzard
- **Fecha:** 2026-11-12 · **Estado:** Aceptada
- **Contexto:** la API devuelve emblemas e iconos bajo `/forever-{region}/…` y muchos dan 403; los mismos ficheros existen bajo `/{region}/…`. La CDN no envía CORS, imprescindible para teñir emblemas con `mask-image`.
- **Decisión:** `normalizeMediaUrl()` reescribe `forever-xx/(guild|icons)` → `xx/…` (los renders de personaje sí funcionan en `forever-xx`); `GET /v1/media?url=` sirve en el mismo origen, con lista blanca de host, solo PNG/JPEG, ≤ 5 MB y caché en disco.

## ADR-013: Datos de demostración
- **Fecha:** 2026-11-12 · **Estado:** Aceptada
- **Decisión:** la UI nunca contiene datos de juego hardcodeados. Los fixtures reales capturados de Battle.net viven solo en `apps/api/tests/fixtures`. Para QA visual existe `apps/api/src/cli/dev-verification.ts` (`seed`/`clean`), que marca todo con el prefijo `verif-`/"[Prueba de verificación]", se niega a ejecutarse en producción y se limpia tras cada verificación.

## ADR-014: Nombre del producto: BlazonGuild
- **Fecha:** 2026-11-12 · **Estado:** Aceptada (decisión del autor)
- **Contexto:** "FOREVER" coincidía con el nombre del juego (*World of Warcraft: Forever*) y con una guild real, y generaba confusión.
- **Decisión:** la marca pasa a **BlazonGuild** (*blazon*, escudo de armas: cada guild con su estandarte). Los paquetes pasan a `@blazonguild/*`. Se mantienen sin cambiar los identificadores internos invisibles: cookie `forever_session`, claves `forever-*` de localStorage y prefijo `fvr_` de los tokens, para no cerrar sesiones ni romper preferencias guardadas. Las referencias al juego (`*-forever-*`, `WOW_FOREVER_*`) no cambian.
- **Pendiente:** comprobar la disponibilidad de dominio, nombre del addon y marca antes de publicar.

## ADR-015: Buscador de grupo sin permisos nuevos
- **Fecha:** 2026-11-12 · **Estado:** Aceptada
- **Contexto:** el buscador de mazmorras necesita "ver", "apuntarse" y "moderar", igual que las raids.
- **Decisión:** reutiliza `raids.view`, `raids.signup` y `raids.manage` en vez de añadir permisos propios: así las guilds que ya ajustaron quién ve o se apunta a raids no tienen que configurar nada más. Cerrar un grupo lo puede hacer quien lo creó o quien tenga `raids.manage`. Solo se puede usar un personaje propio de la guild; los grupos caducan solos para que la lista no se llene de grupos muertos.

## ADR-016: El addon es el producto principal; la web, la ventana
- **Fecha:** 2026-11-12 · **Estado:** Aceptada (decisión del autor)
- **Contexto:** el autor quiere que los jugadores lo hagan todo desde el juego (organizar raids y grupos, calendario, gestión de miembros, apuntarse) sin vincular nada en la web, y que todo se refleje en la web, que queda para consultar (y también gestionar).
- **Alcance (aclarado por el autor):** paridad total. No solo lo que se gestiona (raids, grupos, calendario, miembros, inscripciones), también todo lo que se consulta en la web: resumen, roster, armería, rankings, JcJ, JcE, mazmorras, actividad.
- **Decisión:** cada funcionalidad se diseña primero para el addon. Entre jugadores, el addon sincroniza en tiempo real por mensajes de addon de la hermandad. Hacia la web se usa la app compañera, porque el juego no deja a los addons conectarse a internet. Vincular la cuenta en la web nunca es requisito; Battle.net en la web queda como verificación opcional.
- **Consecuencias:** la hoja de ruta adelanta el addon (Fase 6) y el puente (Fase 7) a la analítica (Fase 5). La API necesita aceptar lo que crea el addon (raids, grupos, inscripciones) con su procedencia, y resolver conflictos entre lo hecho en el juego y en la web. Lo que llega del addon se contrasta con el roster oficial de Battle.net. Para la paridad de consulta, el addon combina tres fuentes: lo que el propio juego da de la hermandad (roster, rangos, niveles, clases), lo que comparten los miembros que tienen el addon (equipo, talentos, JcJ) y lo que la web calcula con Battle.net, que le llega a través de la app compañera.

## ADR-017: Integrar las funciones del addon Olympus
- **Fecha:** 2026-11-12 · **Estado:** Aceptada (decisión del autor)
- **Contexto:** el autor quiere que BlazonGuild haga todo lo que hace Olympus (dnl-gentile/olympus-addon, v1.5.7, licencia MIT), el addon de la hermandad de Asmongold, que solo funciona en hermandades llamadas Olympus y tiene la jerarquía fija.
- **Decisión:** cada función se rehace dentro de BlazonGuild, para cualquier hermandad, con el diseño Híbrido y reflejada en la web. El código de Olympus se reutiliza donde sirva, siempre con su aviso de copyright MIT. No se usan su nombre, su arte ni referencias a Asmongold.
- **Elecciones del autor:** se incluyen (1) el salto a la capa del líder ("si lo tiene Olympus, déjalo"), (2) la lista "Se busca" de jugadores de la facción contraria y (3) las sanciones que siguen al BattleTag, este último con el consentimiento explícito de cada jugador para compartir su BattleTag. Las apuestas con oro quedan fuera, igual que en las versiones publicadas de Olympus.
- **Hermandades hermanas:** en Olympus se reconocen por el nombre y por una lista firmada por su autor. En BlazonGuild se unen por acuerdo entre sus maestros (invitación y aceptación dentro del juego), con la identidad garantizada por el propio juego y contrastada con el roster oficial de Battle.net. Se comunican por **susurros entre addons**: un "mensajero" por hermandad los recibe y los reparte por el canal de su hermandad, como hace Olympus (`Relay.lua`), porque en Forever los canales ocultos no entregan mensajes de addon. Ver `docs/olympus/INVENTARIO.md`.

## ADR-018: Cualquier miembro organiza; los organizadores gestionan todo
- **Fecha:** 2026-11-12 · **Estado:** Aceptada (decisión del autor)
- **Contexto:** la 0.4.0 solo dejaba crear raids al maestro y a los oficiales. El autor: "puede que entre miembros de la guild quieran hacer los suyos", no solo los de rango alto.
- **Decisión:** cualquier miembro crea raids, grupos y salas de chat. Quien crea una raid la dirige (inscripciones, reserva, grupos, invitaciones). Los **organizadores** (el maestro y los rangos que él elija en Administración; por defecto el rango 1) gestionan además todas las raids, llaman a los oficiales y moderan el chat. Solo el maestro cierra los casos de moderación.
- **Seguridad:** el identificador de cada raid, grupo o sala empieza por el nombre de quien la crea, y cada addon lo comprueba: nadie puede editar ni cancelar lo de otro sin ser organizador. Probado con registros falsificados en la red simulada.

## ADR-019: Hermandades hermanas por susurros entre sus miembros, con acuerdo de los maestros
- **Fecha:** 2026-11-12 · **Estado:** Aceptada (primera parte de la entrega 6)
- **Contexto:** el autor vio el chat de la 0.6.0 y preguntó por las hermandades hermanas: esperaba pestañas por hermandad, no solo por rol. En Forever los addons no pueden hablarse por un canal de chat oculto (Olympus lo midió: de 123 mensajes no llegó ninguno); sí funcionan el canal de la hermandad y los susurros entre addons, en todos los subreinos.
- **Decisión:** una alianza la crea un maestro y entra cada hermandad cuando su maestro acepta (ADR-017). Cada hermandad guarda el registro de la alianza en sus registros compartidos (solo lo escriben el maestro y los organizadores). Los mensajes entre hermandades van por susurro: el mensajero de cada hermandad manda su presencia a las demás cada dos minutos y la reparte a los suyos; quien escribe en el chat de la alianza manda la línea a los suyos por GUILD y al mensajero de cada hermandad hermana por susurro. Una clave compartida, que solo tienen los miembros de la alianza, marca cada mensaje.
- **Consecuencias:** el chat entre hermandades llega con uno o dos segundos de retraso y necesita que alguien de cada hermandad tenga el addon conectado. Un miembro de una hermandad de la alianza podría falsear líneas en nombre de otro; se resolverá con firmas cuando llegue el liderazgo de la alianza (segunda parte). El chat de texto por un canal del juego (más rápido, lo usa Olympus desde su 1.5.0) queda como mejora: exige unirse a un canal y esconderlo de las ventanas de chat.

## ADR-031: Las mazmorras y bandas de WoW Forever, con los nombres de su cliente
- **Fecha:** 2026-11-13 · **Estado:** Aceptada (0.28.0)
- **Contexto:** el autor preguntó si las mazmorras y bandas que salían eran las de Forever. No: eran las de la era clásica. Forever tiene 28 mazmorras (19 clásicas y 9 nuevas) y sus bandas abren el 9 de diciembre de 2026: Cavernas del Túmulo (10 jugadores, 8 jefes), Cima Hyjal (20, 13) y Guarida de Onyxia (40). Núcleo de Magma, Guarida Alanegra, Zul'Gurub, Ahn'Qiraj y Naxxramas no están anunciadas (siguen en los ficheros del juego; algunas guías las listan por eso).
- **Fuentes:** la «Raid Overview» de Blizzard (las tres bandas, tamaños, jefes, fecha); los nombres en inglés y español del propio cliente de Forever, según el traductor de «The Forever Era»; dos guías independientes (Warcraft Tavern, allthings.how) para la lista de mazmorras; Olympus (MIT), que funciona en Forever, para las claves y para confirmar la lista.
- **Decisión:** `Instances.lua` con las 28 mazmorras y las tres bandas de Forever. Las bandas clásicas quedan como `legacy`: nunca se ofrecen, pero una raid antigua que las use se lee y se edita igual. Facción solo para las de dentro o bajo una capital (Sima Ígnea, Las Mazmorras, Salón de los Feudales, Ruinas de Lordaeron). El JcE reconoce las bandas nuevas por nombre (español o inglés) y, mientras cada una tenga su tamaño, por el número de jugadores que da el juego (los ids de mapa de las nuevas no se conocen).
- **Consecuencias:** los niveles de las mazmorras son los rangos habituales (las guías no coinciden del todo). En alemán, francés, italiano, portugués y ruso, los nombres de lo nuevo de Forever salen en inglés hasta conocer los oficiales. Cuando Blizzard añada bandas (la hoja de ruta habla de 2027) hay que añadirlas aquí; si llega otra del mismo tamaño, el reconocimiento por tamaño deja de valer (el código lo detecta y no apunta nada). El botín de las bandas nuevas no es público: el equipo de ejemplo del modo capturas sigue siendo el clásico.

## ADR-030: Los nombres que da el juego en Forever, normalizados en un solo sitio
- **Fecha:** 2026-11-13 · **Estado:** Aceptada (0.27.0)
- **Contexto:** la auditoría completa encontró que el simulador escribía todos los nombres como «Nombre Apellido», y en Forever no es así: `UnitName` da solo «El» (el apellido va donde iría el reino) y las funciones y eventos del juego pueden dar «El-Peregrino» (Olympus lo midió en Forever y lo normaliza con `ns.Normal`). Con eso, en el juego real fallaban sin que ninguna prueba lo viera: los duelos de la Arena, las tiradas de Huesos, lotería y sorteos, el oro por comercio y por correo, los jefes de JcE, la verificación de la clasificación de hermandades y «Ver su equipo» de cerca.
- **Decisión:** (1) `Names.Short` entiende «Nombre-Apellido»: un nombre sin espacio con guion es nombre y apellido (en Forever todos los personajes tienen apellido), salvo que lo de después del guion sea nuestro reino; así todo lo que pasa por `Names.Short`, `Names.Same`, `Names.IsMe` y `Guild.Find` queda bien. (2) El nombre de una unidad siempre con `Names.Unit` (`UnitFullName`), nunca `UnitName` ni el nombre de `GetRaidRosterInfo`. (3) El simulador da los nombres como el juego (UnitName en dos partes, la lista de banda solo el nombre, la línea de /roll con guion), para que cualquier uso nuevo de `UnitName` falle en las pruebas. (4) La autoprueba dice cómo escribe los nombres el juego de cada uno.
- **Consecuencias:** un jugador sin apellido cuyo nombre llegue como «Nombre-Reino» de otro reino se leería como «Nombre Reino»; en Forever no existe. `tests/audit.mjs` reproduce cada caso con los nombres como los da el juego. **No comprobado en Forever** qué forma usa cada línea del sistema: la autoprueba lo dirá, y las dos formas funcionan.

## ADR-029: Modo capturas: una hermandad de ejemplo hecha por el propio addon, solo en pantalla
- **Fecha:** 2026-11-13 · **Estado:** Aceptada (0.26.0)
- **Contexto:** el autor quiere capturas reales del addon para CurseForge. En su hermandad casi nadie usa aún BlazonGuild (muchas pantallas salen vacías) y las que tienen datos enseñan nombres de otros jugadores.
- **Decisión:** `/bg capturas` (o el botón «Modo capturas» de Administración) cambia, solo en esa sesión, los datos guardados (`BG.db`), la lista de la hermandad, quién usa el addon y los compañeros del mapa por los de una hermandad de ejemplo. El ejemplo (`Data/DemoData.lua`, inglés y español) lo genera `tools/demo-build.mjs` haciendo vivir tres semanas a una hermandad simulada de jugadores inventados con el código del propio addon (duelos, muertes ante la Horda, donaciones, una noche de Núcleo de Magma, un torneo, encargos, una alianza de tres hermandades…), así que cada registro tiene la forma que escribe el addon. Al activarlo, las fechas se mueven a hoy y lo planeado (raids, operaciones) cae en su tarde y su hora. Mientras está activo no sale ni entra ningún mensaje y no se hace nada en el juego (invitar, susurrar, el chat de hermandad, el canal de la alianza, una tirada que otros verían): `BG.InGame()` lo impide y las tiradas de la Taberna se tiran en pantalla (`BG.RandomRoll`). Los ajustes (ventana, tamaño, idioma) son los reales.
- **Consecuencias:** las capturas son del addon de verdad, en el juego, con todas las pantallas llenas y sin nombres de nadie. Los datos reales no se tocan (siguen en `BlazonGuildDB`, que es lo que guarda el juego); un `/reload` lo termina. Al entrar y salir, el Tablón no cuenta el cambio de hermandad como altas y bajas. El ejemplo hay que regenerarlo cuando cambie la forma de algún registro (`tests/demo.mjs` abre todas las pantallas y pestañas con él en español e inglés).

## ADR-028: Herramientas de la entrega 13: autoprueba, mando, vista por cargo y API
- **Fecha:** 2026-11-13 · **Estado:** Aceptada (0.24.0)
- **Contexto:** la entrega 13 de Olympus trae la API para otros addons (y su puente a la web), el mando, la prueba dentro del juego, la vista por cargo, el taller del autor, Olympus Link (Discord) y la exportación a su web.
- **Decisión:** se hacen la autoprueba (pensada para comprobar en el juego real lo marcado «no comprobado en Forever»), la puerta del mando (una lista con cada sitio donde se toca la interfaz del juego; con la de mando, solo lo propio), «Ver como miembro» (solo a la baja; el Store usa siempre el rango real) y una API de solo lectura con permiso por addon. No se hacen el puente a la web ni la exportación (el autor, 2026-11-13: la web quizá no se use), ni Olympus Link (necesita un bot de Discord), ni el taller del autor (la lista «Quién usa BlazonGuild» de Administración ya da versiones).
- **Consecuencias:** la autoprueba es la forma de que el autor diga qué funciona en su juego sin mirar código. La API puede crecer, pero cada campo nuevo hay que añadirlo a mano (se construye campo a campo).

## ADR-027: «Cara a cara» como una sola ventana local para mirar, comparar y retransmitir
- **Fecha:** 2026-11-13 · **Estado:** Aceptada (0.23.0)
- **Contexto:** de la entrega 12 quedaban la ficha «cara a cara», ver un duelo, la pantalla para quien retransmite, las salas de cada combate y los cargos de la Arena. En Olympus son tres pantallas distintas en un addon aparte y casi todo gira alrededor de las apuestas.
- **Decisión:** una sola ventana, `UI/FaceOff.lua`, con lo que el cliente ya sabe (la clasificación) y ve (las unidades a la vista), sin enviar nada: comparar, mirar en directo y retransmitir son la misma ventana a distinto tamaño. Los árbitros solo deciden combates y quitan duelos. Las salas de los eventos son salas normales del chat, una por torneo, sin moderación aparte.
- **Consecuencias:** la vida solo se ve de quien está a la vista de ese cliente (el juego no da la de los demás); el resultado lo da la línea del juego a quien está cerca. **No comprobado en Forever** que `UnitHealth` de otros jugadores dé la cifra real en duelos (en el cliente moderno puede dar porcentaje).

## ADR-026: Actos firmados del liderazgo de la alianza, y canal del juego como segundo camino
- **Fecha:** 2026-11-13 · **Estado:** Aceptada (0.22.0)
- **Contexto:** quedaba de la entrega 6 lo que en Olympus hace el «Rey» fuera del trono (cartas, puertas abiertas, perdones, operaciones del ejército), ocultar en toda la red, el nombre de incógnito de la moderación y el chat por canal del juego.
- **Decisión:** un mismo mensaje firmado (`LA`, texto `BGL1`) para cuatro actos del liderazgo: carta, ocultar, puertas y operación. Solo lo firma un organizador de la hermandad líder con una clave de su lista de firmantes; cada hermandad lo guarda en sus registros (`lacts`) cuando uno de sus organizadores comprueba la firma, y el liderazgo lo repite cada cuarto de hora. Las lecturas de las cartas (`LK`) y las cuentas de las operaciones (`LC`) vuelven al liderazgo. El chat por canal: un canal oculto con nombre y contraseña derivados de la clave de la alianza, línea con la marca de la alianza, solo al pulsar Intro, sin quitar el camino de los mensajeros. El nombre de incógnito de Olympus no se hace: en BlazonGuild la moderación ya sale sin nombre ante quien la recibe («Mensaje borrado por la moderación», «Estás silenciado hasta…»), y ocultar la presencia ya existe («Ocultarme»).
- **Consecuencias:** nada nuevo depende del canal (si el juego lo niega, todo sigue por mensajeros). Quien conozca la clave de la alianza podría leer el canal: es la misma frontera que ya tenía el chat de la alianza (por eso existe «Nueva clave»). **No comprobado en Forever:** que el canal acepte la línea al pulsar Intro y que llegue entre subreinos (Olympus lo midió en su versión 1.5.0).

## ADR-025: Avistamientos bajo pregunta, y minimapa sin librerías
- **Fecha:** 2026-11-13 · **Estado:** Aceptada (0.21.0)
- **Contexto:** quedaba de la entrega 7 el «¿dónde se vio a tal jugador?» de Olympus y sus puntos en el minimapa. Olympus pinta el minimapa con HereBeDragons (licencia aparte) y solo deja preguntar a sus moderadores por cualquier nombre.
- **Decisión:** avistamientos solo de jugadores de la otra facción (la información de JcJ de siempre: «un pícaro de la Horda en el molino»), recordados solo en memoria un cuarto de hora, y enviados solo como respuesta a la pregunta de un miembro, por susurro a él, y solo por quien acepta esa línea de la privacidad. Nunca de nadie de la propia facción. El minimapa con cálculo propio: coordenadas del mundo del juego (`C_Map.GetWorldPosFromMapPos`), radio de `C_Minimap.GetViewRadius` (o los pasos de zoom del juego) y giro con `GetPlayerFacing`.
- **Consecuencias:** sin seguimiento continuo de nadie; el que pregunta ve quién lo vio y dónde estaba entonces (no la posición exacta del enemigo, que el juego no da). En español se habla de metros, como el cliente del juego en español.

## ADR-024: Clasificación de hermandades de addon a addon, al jugar en grupo
- **Fecha:** 2026-11-13 · **Estado:** Aceptada (0.20.0)
- **Contexto:** el autor pidió clasificaciones y comparativas entre hermandades. No hay web en la que apoyarse (el autor no sabe si se usará) y en Forever los addons no tienen un canal común: solo la hermandad, el grupo y los susurros.
- **Decisión:** cada hermandad cuyo maestro lo active publica una ficha con cifras de la hermandad (nunca de nadie en concreto), hecha por el addon de un organizador y guardada en sus registros. Las fichas se conocen al jugar en grupo con alguien de otra hermandad: cada addon saluda al grupo con la suya. Una ficha que llega de alguien del grupo cuyo nombre de hermandad dice el propio juego es «verificada» y se pasa a la hermandad; las que cuenta un tercero son «sin verificar» y no se pasan. Solo la misma facción; una ficha caduca a los 30 días sin noticias.
- **Consecuencias:** la clasificación crece con lo que la hermandad juega con otras; no es un listado de todo el reino. Las cifras las cuenta el addon de cada hermandad: nadie puede comprobar las de otra desde fuera, y la pantalla lo dice. Sin firmas: proteger la ficha con firma no impediría que una hermandad infle sus propias cifras.

## ADR-023: Cada hermandad con lo suyo: lo que llega por susurro, solo de un miembro
- **Fecha:** 2026-11-13 · **Estado:** Aceptada (auditoría de la 0.19.1)
- **Contexto:** BlazonGuild lo puede usar cualquier jugador, de cualquier hermandad. Por el canal de la hermandad solo hablan sus miembros, pero un susurro de addon puede mandarlo cualquiera. La auditoría vio que la puesta al día (`SA`) aceptaba registros de cualquiera si el autor era quien los mandaba, y las reglas de cada registro no miraban la hermandad. Además, los datos guardados se separaban solo por región y nombre de la hermandad.
- **Decisión:** un registro que llega por susurro solo cuenta si quien lo trae está en nuestra lista de miembros del juego (y, como antes, si es su autor, un organizador o el mensajero elegido). Los datos de cada hermandad se guardan por región, reino, facción y nombre. Lo que cada organizador guarda para sí (denuncias, BattleTags) es de su hermandad. Los registros de moderación (casos, avisos) son «privados»: viajan por susurro solo a los organizadores y solo ellos los guardan. Todo mensaje que llega por susurro y toca la hermandad comprueba que el remitente sea miembro.
- **Consecuencias:** nadie de otra hermandad escribe en la vuestra. Queda dentro de la hermandad la confianza en el mensajero: si no hay organizadores conectados, el mensajero es un miembro, y un miembro con mala intención que lo sea podría pasar registros falsos de otros miembros en una puesta al día. El libro de la tesorería sigue en el ordenador de todos (cada uno calcula su cuota con él), aunque la pantalla solo lo enseñe si el maestro lo permite.

## ADR-022: Idiomas: el español en el código y la traducción al enseñar cada texto
- **Fecha:** 2026-11-13 · **Estado:** Aceptada (entrega 13, primera parte)
- **Contexto:** el autor pidió el addon en los idiomas principales de WoW. El código tiene unos 2200 textos en español, muchos hechos de trozos (`"Ha matado a " .. n .. " miembros"`). Cambiar cada uno a una clave (`L["KILLED_N"]`) habría tocado todos los ficheros y cada entrega futura tendría que acordarse.
- **Decisión:** el español sigue escrito tal cual en el código. Una herramienta saca cada texto, también los trozos unidos como plantilla (`"Ha matado a %s miembros"`) y los de `string.format`; cada idioma tiene su tabla del texto en español a su traducción. Nuestros textos se traducen al enseñarse (`UI.Text`, avisos, ventanas, tooltips con `BG.ShowTip`, líneas del chat del addon): el texto entero; una plantilla, con sus valores traducidos; o cortado por líneas, frases, colores o listas. Una plantilla hecha solo de palabras pequeñas («%s de %s») o un final conocido solo valen si todo lo demás queda traducido; un nombre (todas sus palabras con mayúscula) se deja como está. El idioma es el del juego o el elegido, y cambia al recargar la interfaz.
- **Consecuencias:** las entregas nuevas se escriben en español como siempre; `tests/locales.mjs` falla si un texto nuevo no está traducido en los seis idiomas, si una pantalla enseña español en otro idioma o si algo no cabe. Traducir cuesta poco (cada texto una vez, luego de memoria; un mensaje largo de alguien se abandona enseguida). Los plurales del ruso son simplificados (dos formas), y algunos nombres de mazmorras en italiano y portugués pueden no ser los oficiales.

## ADR-021: «Se busca» solo con lo que el juego permite: el resumen de muerte y nuestro golpe final
- **Fecha:** 2026-11-13 · **Estado:** Aceptada (entrega 11)
- **Contexto:** el plan era leer el registro de combate (`COMBAT_LOG_EVENT_UNFILTERED`) para saber quién mató a un miembro. Las notas de Olympus (MIT) dicen que en Forever ese evento está restringido: registrarlo muestra en cada inicio de sesión el aviso del juego de que un addon ha sido bloqueado. Un `pcall` no lo evita.
- **Decisión:** la muerte se lee del resumen de muerte del propio juego (`C_DeathRecap`, al morir y reintentando a los 0,3, 1 y 2 s); la baja, del evento nativo `PARTY_KILL`, y solo cuando el golpe final es nuestro. La facción del otro se prueba con su raza según el juego, nunca con lo que escriba alguien. Fuera de instancias. Cada miembro apunta solo lo suyo (registro `wanted`), y la recompensa se calcula igual en todos los clientes.
- **Consecuencias:** no se apunta una muerte de la que el juego no dé resumen, ni la baja que remata otro del grupo (ese la apunta su propio addon si lo tiene). Quien no quiera, apaga «Apuntar mis muertes y bajas». Las razas de las dos facciones (los Skyborn de Forever) nunca cuentan.

## ADR-020: El registro de la alianza, firmado por partes; el líder lo eligen los votos
- **Fecha:** 2026-11-12 · **Estado:** Aceptada (segunda parte de la entrega 6)
- **Contexto:** en la 0.7.0 cualquier miembro de una hermandad de la alianza conocía la clave y podía falsificar el registro (sacar a una hermandad, cambiar la clave). Además, en las pruebas, dos hermandades que cambiaban el registro a la vez se quedaban cada una con una versión distinta y dejaban de entenderse.
- **Decisión:** firmas Ed25519 (código de Olympus, MIT, con su aviso en THIRD_PARTY_NOTICES.md). El registro se divide: cada hermandad firma su propia entrada (con su versión) y la parte común (quién está, la clave, el nombre) lleva una versión firmada por la hermandad que la cambia. Cada hermandad lista sus firmantes (maestro primero, como ancla, y organizadores), con un certificado del ancla o, si cambia el maestro, de una clave de la lista anterior. Las reglas: cada hermandad cambia solo lo suyo; entra quien tenía invitación; sale cada una por sí misma o la saca el líder; clave y nombre, el líder. El líder es la hermandad con más de la mitad de los votos; si no, la fundadora (sin memoria: así se calcula igual en todas). Quien se pierde varios cambios comunes solo acepta el más nuevo si lo firma la hermandad del líder.
- **Consecuencias:** cada cambio cuesta una o dos firmas (unos 40 ms cada una, repartidos en varios fotogramas). El registro con tres hermandades ocupa unos 2 KB: tarda unos 10 segundos en viajar al ritmo del juego, por eso los cambios de una hermandad viajan solos (`AE`, unos 600 bytes). Si cambian todos los firmantes de una hermandad a la vez, tendrá que salir y volver a entrar. Las líneas de chat aún no van firmadas: un miembro de la alianza podría falsear una línea.

