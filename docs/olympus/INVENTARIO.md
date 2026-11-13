# Olympus → BlazonGuild: inventario completo

> Qué hace cada parte del addon Olympus y cómo quedará en BlazonGuild. Pedido por el autor el 2026-11-12 (ADR-017).
> Analizado: `dnl-gentile/olympus-addon`, versión 1.5.7, commit `eb91d5b` (11 nov 2026), licencia MIT.
> Son **173 módulos** en tres addons: Olympus (150), Olympus_Arena (22, los juegos) y OlympusSiteAggregate (1, para su web).

## Estado (2026-11-12)

- **Hechas:** entrega 1 (addon 0.2.0), entrega 2 (0.3.0), entrega 3 (0.4.0, vista por el autor en el juego) y entrega 4 (0.5.0: chat y moderación; quedan `Moderation.lua` entre hermandades y `Cover.lua`, que van con la alianza) y entrega 5 (0.6.0: el tablón). Entrega 6, primera parte (0.7.0): alianza por acuerdo de los maestros, mensajeros por susurro, presencia, chat con pestaña por hermandad, salas compartidas. Segunda parte (0.8.0): firmas Ed25519, líder por votos, llamada a las armas de la alianza, expulsar, clave nueva, cargos, ocultarse, censo de personas. Tercera parte (0.9.0): sala de guerra (escuadras con chat, operaciones, partes). Entrega 7 (0.10.0): mapa por zonas, posiciones y capas compartidas a voluntad, puntos en el mapa del mundo, pedir invitación a otra capa (sin avistamientos ni minimapa todavía). Entrega 8 (0.11.0): artesanía (tablón, encargos, ranking) y notas de botín con puntos. Entrega 9 (0.12.0): tesorería (tesoreros, cuota, libro automático por comercio y correo, campañas, banco, copia). Entrega 10 (0.13.0): reclutamiento (ficha, «Únete» con /who, peticiones con «Invitar», quién te trajo, traer tu ficha). Entrega 11 (0.14.0): «Se busca» (resumen de muerte y golpe final propio, recompensas, cazadores, aviso «Cerca»), honores con podios y marcas sobre los nombres, en el retrato y en el chat.
- **Entrega 3, completada en la 0.20.0:** inspección cercana (en la Armería, al pulsar «Inspeccionar») y si lleva tabardo (en la Armería); la «patrulla» automática de tabardos de Olympus no se hace: el addon nunca inspecciona sin que lo pidas. Antes pendiente: `Inspect.lua` y `TabardsV2.lua` y `Who.lua` (irá con reclutamiento, entrega 10).
- **Siguiente:** entrega 13 (extras: mando, pruebas dentro del juego, API para otros addons). Idiomas hechos en la 0.19.0 (ADR-022): inglés, alemán, francés, italiano, portugués y ruso, además de español. La 11 está completa, con la marca de honor en el chat. Entrega 12, primera parte (0.15.0): la Arena con duelos que se apuntan solos, clasificación Elo, rangos, cinturón, temporadas y retos. Segunda parte (0.17.0): torneos con cuadro, cabezas de serie y sorteo con /roll, y veladas. Tercera parte (0.18.0): la Taberna (Huesos por puntos, lotería de práctica, aviso del posadero). La entrega 12 está completa; de ella no se hace la flecha a la posada (haría falta una lista de posadas) ni nada con oro. La entrega 7 quedó completa en la 0.21.0 (puntos en el minimapa, flecha «Seguir» —la idea de `KingArrow.lua`— y avistamientos de la otra facción bajo pregunta, ADR-025). La entrega 6 quedó completa en la 0.22.0 (ADR-026): chat también por canal del juego, operaciones de toda la alianza, ocultar en toda la alianza, cartas a los líderes con lectura y puertas abiertas; el nombre de incógnito no hace falta (la moderación ya sale sin nombre). La entrega 12 quedó completa en la 0.23.0 (ADR-027): «Cara a cara» (ficha, vista del duelo y pantalla para retransmitir en una sola ventana), árbitros sin dinero y una sala de chat por torneo. La entrega 13 quedó hecha en la 0.24.0 (ADR-028): autoprueba, mando, vista por cargo y API de solo lectura para otros addons; fuera, por decisión, el puente y la exportación a la web, Olympus Link (Discord) y el taller del autor. **Con esto están todas las entregas.**

## Cómo leer este documento

Cada bloque explica, en palabras sencillas, qué hace esa parte en Olympus y qué haremos nosotros. Al lado de cada módulo va una de estas marcas:

- **Incluir**: lo hacemos igual, para cualquier hermandad.
- **Adaptar**: lo hacemos, pero cambiado, porque en Olympus depende de Asmongold, del nombre "Olympus" o de su autor.
- **Base**: no se ve, pero lo necesitan las demás funciones (mensajes entre addons, firmas, errores…).
- **Ya lo tenemos**: BlazonGuild ya lo hace, en el addon o en la web.
- **Fuera**: no lo haremos, y se explica por qué.

Todo lo que se incluye se verá también en la web (ADR-016), salvo lo marcado como privado.

## Lo más importante que hemos aprendido de Olympus

1. **En los servidores reales de Forever, los addons no pueden hablarse por un canal de chat oculto.** Olympus lo midió la noche del lanzamiento: de 123 mensajes no llegó ninguno. Sí funcionan dos cosas: el canal de la hermandad y los **susurros entre addons** (mensajes privados que el jugador no ve). Para unir hermandades, Olympus usa "mensajeros": un miembro de cada hermandad recibe los mensajes por susurro y los reparte por el canal de su hermandad (`Relay.lua`). **Corrige lo que se explicó al autor el 2026-11-12:** las hermandades hermanas de BlazonGuild se unirán así, no con un canal oculto.
2. **Lo que los jugadores escriben a mano en un canal de chat normal sí llega**, aunque estén en distintos servidores de Forever (`ChatHall.lua`). El chat entre hermandades puede ir por ahí.
3. **En Forever los nombres son "Nombre Apellido"** y el juego los separa por el espacio. Coincide con lo que encontró nuestra sonda ("El Peregrino" → "El").
4. Las ventanas emergentes del juego fallan si las abre un addon cuando se juega con mando. Por eso Olympus usa ventanas propias (`Dialog.lua`).
5. Olympus trae un modelo de todo lo que existe en el cliente de Forever (`tests/fixtures/forever-api.lua`). Nos sirve para que nuestras pruebas sin el juego sean mucho más fieles.

---

## Entrega 1 — La base: que los addons se hablen

Sin esto no funciona casi nada de lo demás: cada addon tiene que saber quién más tiene el addon, mandar mensajes cortos y comprimidos, y no saturar el chat.

- `Comm.lua`: saludo entre los addons de la hermandad, elección de un "mensajero" por hermandad y envío de resúmenes. **Base.**
- `Codec.lua`: formato de los mensajes y troceo de los largos. **Base** (con `C_EncodingUtil`, que existe en Forever).
- `Relay.lua`, `RelayTree.lua`, `RelayFallback.lua`: mensajeros por susurro entre hermandades, reparto en árbol cuando son muchas y mensajeros de reserva. **Adaptar**: en Olympus los mensajeros son personas firmadas por su autor; aquí serán los mensajeros elegidos por cada hermandad de la alianza.
- `Diagnostics.lua`, `Bootstrap.lua`: guardan los errores para revisarlos tras un `/reload`. **Ya lo tenemos** (BlazonGuildDB.errors); se amplía.
- `Perf.lua`: medidor de rendimiento para quien note tirones. **Incluir.**
- `Sign.lua`, `Ed25519.lua`: firmas que no se pueden falsificar. **Base** (Ed25519 se reutiliza con su aviso MIT).
- `Versions.lua`, `Builds.lua`: qué versión del addon tiene cada uno, aviso para actualizar y bloqueo de copias modificadas. **Incluir.**
- `Consent.lua`, `Accord.lua`: página de privacidad y condiciones de uso que cada cuenta acepta una vez antes de compartir nada. **Adaptar** (texto propio de BlazonGuild).
- `Core.lua`: núcleo, comandos y ajustes. **Adaptar** a nuestro núcleo.

## Entrega 2 — Buscar grupo y raids

- `Board.lua`: "el tablón": cada jugador levanta una bandera (mazmorra, banda, JcJ, capa) con una nota; un clic en la tarjeta de otro le susurra. **Incluir** (completa el buscador de la web).
- `Groups.lua`: un líder publica un grupo con los roles que le faltan; los jugadores se apuntan con su rol; el líder invita o rechaza. **Ya lo tenemos** en la web (buscador de grupo); se lleva al addon.
- `Week.lua`: la semana del líder (raids, noches JcJ…) junto a los eventos del calendario del juego. **Adaptar**: semana de la hermandad o de la alianza.
- `OfficerMuster.lua`: llamada discreta solo para oficiales. **Incluir.**
- Raids de BlazonGuild (inscripción, composición, planificador): **Ya lo tenemos** en la web; se llevan al addon.

## Entrega 3 — Personas: ficha, menú y alters

- `PlayerMenu.lua`: líneas propias en el menú del botón derecho sobre un jugador (marco de objetivo, grupo, chat, lista de amigos…). **Incluir.**
- `PlayerProfile.lua`, `ProfileEdit.lua`: ficha de un jugador y "mi perfil" editable. **Incluir.**
- `PlayerTooltip.lua`: datos extra en el recuadro al pasar el ratón por un jugador. **Incluir.**
- `Alts.lua`: unir los personajes de una misma cuenta (se confirma desde cada personaje, nadie puede unir los de otro). **Incluir.**
- `Inspect.lua`, `TabardsV2.lua`: inspeccionar a los miembros cercanos y ver quién lleva el tabardo. **Incluir** (para oficiales).
- `Members.lua`: lista de miembros que llevan 7, 14 o 30 días sin entrar, para el liderazgo. **Incluir.**
- `Who.lua`: búsquedas `/who` del juego, una por clic, sin saturar. **Base.**
- `GuildFrame.lua`: botón de BlazonGuild dentro de la ventana de hermandad del juego. **Incluir.**
- `MainKey.lua`: atajo de teclado (Mayús + tecla de hermandad). **Ya lo tenemos** (atajo asignable); se añade este.

## Entrega 4 — Chat propio y moderación

- `Channels.lua`, `ChatHall.lua`, `ChatWindow.lua`: chats de la hermandad y de la alianza por rangos, en una pestaña de la ventana. **Adaptar**: Olympus tiene [Olympus], [Capitanes] y [Señores]; aquí cada hermandad o alianza define los suyos.
- `ChatRooms.lua`: salas por rol (por ejemplo, solo sanadores o solo reclutadores). **Incluir.**
- `ChatMarks.lua`: pequeña marca de honor junto al nombre en el chat. **Incluir.**
- `Filter.lua`: palabras bloqueadas, personales y comunes. **Incluir.**
- `WatchChat.lua`, `ChatStrikes.lua`: borrar mensajes y silenciar 5 min, 30 min, 1 h, 24 h o 7 días; tres avisos y a la tercera decide el equipo. **Incluir.**
- `Moderation.lua`: ocultar a un personaje o a una hermandad en toda la red. **Incluir.**
- `Watch.lua`: el puesto de moderación privado de cada hermandad (denuncias, casos). **Incluir.**
- `Judgment.lua`: un consejo vota un caso y el líder tiene la última palabra. **Adaptar** (consejo que elija cada alianza).
- `JusticeTasks.lua`: peticiones de expulsión con pruebas firmadas (nunca expulsa solo). **Incluir.**
- `TagFollow.lua`: la sanción sigue al BattleTag y alcanza a los otros personajes de esa cuenta. **Incluir** (decisión del autor), con consentimiento expreso de cada jugador para compartir su BattleTag.
- `Cover.lua`: nombre de incógnito para moderadores. **Incluir.**

## Entrega 5 — Avisos y vida de la hermandad

- `Decree.lua`: "¡A las armas!" y "reunión aquí", con aviso en pantalla, sonido y marca en el mapa. **Adaptar** (lo envía el liderazgo de cada hermandad o alianza, no "el Rey").
- `Acts.lua`: cartas oficiales a los líderes, con acuse de lectura; "abrir las puertas" (a qué hermandad mandar a los nuevos). **Adaptar.**
- `Vox.lua`: encuestas del líder con cuenta atrás y resultados en gráfico. **Incluir.**
- `Court.lua`: audiencias: el líder "abre la corte" y los presentes piden turno. **Adaptar.**
- `Chronicle.lua`: registro de lo que ha pasado (avisos, sanciones, cambios). **Incluir.**
- `WeeklyBrief.lua`: resumen semanal. **Incluir.**
- `Letters.lua`: carta de novedades tras cada actualización del addon. **Incluir.**
- `RoleBriefings.lua`: carta de bienvenida a cada cargo la primera vez que alguien lo recibe. **Adaptar.**
- `Answers.lua`, `AnswerBank.lua`: preguntas frecuentes dentro del juego. **Adaptar** (respuestas propias).

## Entrega 6 — Alianza de hermandades (las hermandades hermanas)

- `Data.lua`, `Roster.lua`: un informe por hermandad y la suma de todas. **Adaptar**: la alianza se forma por acuerdo entre maestros (ADR-017), no por el nombre.
- `CensusStats.lua`, `CensusClean.lua`: personas reales (cada una una vez, con sus alters) frente a personajes. **Incluir.**
- `Verify.lua`: verificación de cada hermandad por un verificador. **Adaptar**: aquí la verificación es la aceptación del maestro, contrastada con el roster oficial de Battle.net.
- `Authority.lua`: permisos entre hermandades (en Olympus, dormido). **Base.**
- `King.lua`, `KingArrow.lua`: el trono de Asmongold y una flecha en el minimapa hacia él. **Adaptar**: liderazgo de la alianza y flecha hacia el líder que elija cada alianza.
- `Nominees.lua`: cada maestro nombra a sus centuriones y corresponsales. **Adaptar** (cargos configurables).
- `Keys.lua`: cambiar la clave de la red si se filtra. **Incluir.**
- `PrivatePresence.lua`: que el líder pueda ocultar que está conectado. **Incluir.**
- `War.lua`, `WarSquads.lua`: sala de guerra de la hermandad (operaciones, partes, escuadras pequeñas). **Incluir.**
- `ViewAs.lua`: vista previa de cada rol para el desarrollador. **Incluir** (herramienta interna).
- `Workshop.lua`: pestaña del autor para ver versiones e instalaciones en toda la red. **Adaptar** (pestaña de desarrollo de BlazonGuild).

## Entrega 7 — Mapa, capas y posiciones

- `Map.lua`, `Zones.lua`, `MapNames.lua`: en el mapa del mundo, cuántos miembros hay en cada zona y las marcas de los avisos. **Incluir.**
- `Positions.lua`: puntos de colores de los compañeros en el mapa y el minimapa; solo a tu hermandad y solo si cada uno quiere. **Incluir.**
- `Layers.lua`: saber en qué capa está cada uno (por el código interno de los PNJ). **Incluir.**
- `Hop.lua`, `HopSightings.lua`: pedir invitación para pasar a la capa del líder. **Incluir** (decisión del autor: "si lo tiene Olympus, déjalo"), con el líder que elija cada hermandad en lugar de Asmongold.
- `PartyGuard.lua`: bandeja de peticiones de invitación mientras el líder está conectado; nunca invita solo. **Incluir.**
- `PlayerSightings.lua`: "¿dónde se vio por última vez a tal jugador?", solo bajo petición y con consentimiento. **Incluir.**

## Entrega 8 — Artesanía y botín

- `Crafters.lua`: tablón de artesanos: al abrir tu profesión, eliges publicar lo que sabes fabricar; los demás te susurran con un clic. **Incluir.**
- `CraftRequests.lua`: pedir un objeto a quien sepa fabricarlo, con cantidad y detalles. **Incluir.**
- `CraftRanking.lua`, `Records.lua`: registro firmado de encargos cumplidos y clasificación de artesanos. **Incluir.**
- `Loot.lua`: notas de botín (a quién se dio qué y por qué) con una columna de puntos opcional. **Incluir.** Olympus no permite pujas de oro porque el GDKP no está permitido en Forever; nosotros tampoco.

## Entrega 9 — Tesorería

- `Treasury.lua`: libros de la tesorería con sus tesoreros; el oro entra por comercio o correo, siempre con un clic del jugador. **Adaptar** (tesoreros que nombre cada hermandad).
- `Dues.lua`, `DuesHistory.lua`, `DuesGrace.lua`, `DuesRosterCheckpoints.lua`: cuota semanal fija, historial y periodo de gracia; nunca se publica quién no ha pagado. **Incluir.**
- `Bank.lua`: foto del banco de la hermandad cuando un tesorero lo abre. **Incluir.**
- `Campaign.lua`: campañas de donación con objetivo ("100 de oro para pociones de raid"). **Incluir.**
- `GuildFinance.lua`: a qué hermandad o evento se destina cada ingreso. **Incluir.**
- `Backup.lua`: copia de seguridad de los libros en texto para pegar si se borran los datos. **Incluir.**

## Entrega 10 — Reclutamiento

- `Recruit.lua`: pantalla "Únete" para quien aún no está en la hermandad: busca miembros conectados y les susurra una petición. **Adaptar** (para cualquier hermandad o alianza).
- `GuildCharter.lua`: ficha pública de la hermandad (propósito, idioma, días de raid, clases que busca). **Incluir.**
- `Church.lua`, `ChurchCount.lua`, `ChurchFullness.lua`, `ChurchView.lua`: "La Iglesia Misionera": red de reclutadores con puntos y clasificación por las personas que traen. **Adaptar**: programa de reclutadores con otro nombre y sin la temática religiosa de Olympus.
- `Carry.lua`, `CarryHistory.lua`, `CarryMerger.lua`: llevarse tu historial al cambiar de hermandad dentro de la alianza. **Incluir.**

## Entrega 11 — "Se busca", honores y marcas

- `Wanted.lua`: lista "Se busca" de jugadores de la facción contraria que matan a miembros, con puntos para quien los caza. **Incluir** (decisión del autor).
- `Honors.lua`, `HonorsNet.lua`: títulos y marcos que se ganan (podios, mayores donantes, carrera de niveles, la hermandad con más nivel medio). **Incluir.**
- `Borders.lua`, `Nameplates.lua`, `ProfileEffects.lua`: marcos dorados en el retrato y una marca junto al nombre de los miembros. **Incluir**, con arte propio de BlazonGuild.
- `RankingRules.lua`: página que explica cómo se calcula cada clasificación. **Incluir.**

## Entrega 12 — Arena y juegos (sin apuestas)

Todo esto se carga solo al abrir la Arena, para no pesar en el juego.

- `ArenaFights.lua`, `ArenaMatch.lua`, `ArenaPlaces.lua`, `ArenaParse.lua`: duelos, noches de combate, buscar rival cerca y lectura de resultados. **Incluir.**
- `ArenaTourney.lua`, `ArenaBracket.lua`: torneos con cuadro eliminatorio y sorteo con `/roll`. **Incluir.**
- `ArenaRating.lua`, `ArenaLedger.lua`: clasificación Elo, rangos bronce, plata y oro, cinturones de campeón y temporadas. **Incluir.**
- `ArenaProfile.lua`, `ArenaSpectate.lua`, `ArenaChat.lua`: perfil de luchador, ver un duelo y salas de chat de cada combate. **Incluir.**
- `ArenaFarkle.lua`, `FarkleTable.lua`, `Games/Farkle.lua`, `FarkleBoard.lua`, `BonesChat.lua`: juego de dados "Huesos" (Farkle) en la taberna, con dados de `/roll`. **Incluir**, por puntos.
- `LotteryBoard.lua`, `Games/Games.lua`: lotería de práctica con boletos gratis. **Incluir.**
- `InnkeeperGossip.lua`, `InnkeeperArrow.lua`: una línea en el diálogo del posadero y una flecha a la posada para jugar. **Incluir.**
- `ArenaNet.lua`, `ArenaRoles.lua`, `ArenaTest.lua`, `ArenaHome.lua`: mensajes, cargos (árbitros, directores), ensayos y pestaña de la Arena. **Base**; los cargos se adaptan (en Olympus los nombra el Rey).
- Pantallas de la carpeta `Olympus_Arena`:
  - `Handoff.lua`, `Panes.lua`, `Kit.lua`, `Window.lua`, `Popups.lua`, `ChatPanel.lua`: la ventana de la Arena, sus piezas, sus avisos y el acceso al chat de cada combate. **Base.**
  - `Card.lua`, `BracketView.lua`, `Spectate.lua`: ficha del luchador ("cara a cara"), cuadro del torneo y vista de un duelo. **Incluir.**
  - `PagesPlayer.lua`: páginas de noche de combate, torneo, clasificación y perfil. **Incluir**, sin la cartera de oro ni la clasificación de apostantes.
  - `PagesStaff.lua`: páginas de árbitro y director. **Adaptar**; las del banco de oro y las cuentas de apuestas quedan fuera.
  - `Overlay.lua`: aviso en pantalla para quien retransmite en directo (Asmongold). **Adaptar** para el líder que retransmita.
  - `Games/GamesRules.lua`, `Games/Hookup.lua`, `Sim.lua`: reglas de los juegos, modo práctica y simulación con datos de ejemplo. **Incluir.**
  - `Slip.lua`: el boleto de apuestas. **Fuera.**
- `Compliance.lua`: la puerta que bloquea cualquier apuesta. **Incluir**, siempre cerrada.
- **Fuera, dinero de apuestas:** `Markets.lua`, `MarketBank.lua` y `Games/Bicho.lua` (Olympus tampoco los publica), y también `ArenaMath.lua` (bolsas y cuotas de apuestas), `Stakes.lua`, `Wallet.lua`, `ArenaMoney.lua`, `Debts.lua` y `Lottery.lua` con oro. Se quedan fuera porque solo sirven para mover oro de apuestas, que acordamos no hacer.

## Entrega 13 — Extras

- `API.lua`, `Bridge.lua`, `BridgeSections.lua`, `BridgePeople.lua`, `BridgeAffairs.lua`: que otros addons lean, con permiso del jugador, lo que BlazonGuild ya le enseña. **Incluir.**
- `ArmyExport.lua` y `OlympusSiteAggregate` (`SiteAggregate.lua`): exportar datos de la hermandad a su web. **Ya lo tenemos** a nuestra manera: la app puente y la web de BlazonGuild.
- `LinkLoader.lua` (Olympus Link): demostrar en el juego que un personaje es tuyo para que un bot de Discord te dé tu rol. **Adaptar** más adelante, desde la web.
- `Gamepad.lua`, `GamepadRegistry.lua`, `Dialog.lua`: que nada se rompa jugando con mando. **Incluir.**
- `Views.lua`, `UI.lua`: la ventana de Olympus, que imita la ventana de hermandad clásica. **Ya lo tenemos** con nuestro diseño propio.
- Idiomas (`Locales.lua` y `Locales/`): inglés, portugués, español, francés, alemán, italiano y ruso. **Incluir**: empezamos en español y añadimos los demás. **Hecho (0.19.0)** con un método propio (el español en el código y la traducción al enseñar cada texto, ADR-022); no se copia nada de sus ficheros de idioma.
- `SelfTest.lua`: pruebas automáticas dentro del juego para quien prueba versiones. **Incluir.**
- `Record.lua`: modo "testigo" para el intento de récord Guinness de Olympus. **Fuera**: fue para un evento concreto suyo.

## Lo que no copiamos

- El nombre Olympus, Asmongold, su logotipo y su arte (marcos de bronce, insignias, emblema). Usamos el arte propio de BlazonGuild.
- Las reglas que solo valen para ellos: el filtro por nombre de hermandad, el "Rey" fijo, las listas firmadas por su autor, la temática de iglesia.
- Las apuestas con oro.

## Licencia

Olympus se publica con licencia MIT. Cada fichero de BlazonGuild que reutilice código suyo lo dirá en su cabecera, y el addon incluirá `THIRD_PARTY_NOTICES.md` con el aviso de copyright de "Olympus addon contributors" (2026).
