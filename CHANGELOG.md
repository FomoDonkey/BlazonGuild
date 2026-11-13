# FOREVER Ecosystem Changelog

All notable changes to the FOREVER product ecosystem are documented in this file.

---

## [0.33.3] — 2026-11-14 — Repositorio público y licencia MIT (el addon sigue en 0.29.2)

### Cambiado
- **Licencia MIT** para el addon y todo el repositorio (antes All Rights Reserved): `LICENSE` en la raíz y `packages/addon/BlazonGuild/LICENSE.txt`. El addon no cambia de versión (el autor: solo el repositorio y CurseForge); el zip 0.29.2 ya subido lleva el texto viejo hasta la próxima versión. Lo adaptado de Olympus (MIT) y TweetNaCl (dominio público) sigue con sus avisos en `THIRD_PARTY_NOTICES.md`.
- **Código público** en https://github.com/FomoDonkey/BlazonGuild: una copia sin historial y sin datos reales de jugadores (los personajes y la hermandad de las pruebas tienen nombres inventados). El repositorio de trabajo sigue privado.
- README nuevo para GitHub (qué hace, instalar, estructura, pruebas, licencia), en inglés con un resumen en español.

### Arreglado
- Simulador: `date()` sin hora usaba el reloj del ordenador y `time()` el del simulador. Desde el 14 de noviembre el Calendario (que mira «las próximas dos semanas» con `date()`) dejó en el pasado el evento de prueba de «mañana» y `tests/raids.mjs` fallaba. Ahora los dos usan el reloj del simulador.

## [0.33.2] — 2026-11-13 — Addon 0.29.2: la Armería con el nombre de cada objeto

### Arreglado
- **Armería** (captura del autor: cada ranura decía «Item 6189» con una interrogación, y al pasar el ratón por su propio objeto salían dos ventanas iguales): el addon leía los objetos con la función global `GetItemInfo`, que **en Forever no existe** (lo midió la sonda del 2026-11-12, `ADDON_COMPATIBILITY.md`; Olympus usa `C_Item.GetItemInfo`). Ahora todo pasa por `BG.ItemInfo` (`C_Item.GetItemInfo`): Armería, Artesanía (segunda vía para el nombre) y soltar un objeto en una caja de texto.
- El icono sale en seguida (`C_Item.GetItemIconByID`, de los ficheros del juego) aunque el nombre tarde: el juego lo pide al servidor una vez por objeto y la pantalla se redibuja sola al llegar; solo por los objetos que pidió la Armería, no por cada objeto que cargue la bolsa o el chat.
- **Tu propio objeto**: la ventana es la de tu personaje (`SetInventoryItem`: ligado, durabilidad) y se cierra la de comparación del juego («Equipado», con Mayúsculas o si siempre comparas), que ahí era el mismo objeto repetido. En el objeto de otro se queda: comparar es para lo que sirve.
- Simulador como Forever: sin `GetItemInfo` global, con `C_Item`, objetos que el juego aún no conoce (`SIM.uncached`) y las ventanas de comparación. `tests/audit.mjs` prohíbe las funciones que la sonda vio que faltan (`GetItemInfo`, `CombatLogGetCurrentEventInfo`, `GetTalentInfo`, `EasyMenu`…). Con el código viejo fallan 5 comprobaciones; 352 en total, todas bien.

## [0.33.1] — 2026-11-13 — Addon 0.29.1: cambiar de idioma sin error

### Arreglado
- **Administración → Idioma** (el autor: «al darle a recargar sale un error en el chat: no se ha podido realizar la acción de interfaz por culpa de un addon»): el botón «Recargar ahora» llamaba a `ReloadUI()`, y el cliente de Forever no deja que un accesorio recargue la interfaz. Ahora la ventana pide escribir `/reload` (como hace Olympus, que nunca recarga por su cuenta). Abrir el chat con `/reload` ya escrito tampoco vale: contamina lo que el jugador escribe después.
- `tests/audit.mjs`: ningún fichero del addon llama a `ReloadUI` ni a `C_UI.Reload` (sin el arreglo, señala `Admin.lua:107`). 348 comprobaciones.

## [0.33.0] — 2026-11-13 — Addon 0.29.0: consume menos

Auditoría de rendimiento (el autor: «que consuma lo menos posible sin afectar en absoluto al producto»). Medido en el simulador con una hermandad de 500 miembros y 10 minutos de juego en una ciudad (chat, ratón, objetivo, placas de nombre, la lista de la hermandad refrescándose): **tiempo de CPU −73 % (218 → 58 ms), basura −88 % (11 475 → 1 392 KB)**; **memoria en reposo −48 %** jugando en español (4,3 → 2,2 MB) y −35 % en otros idiomas. Nada de lo que se ve cambia.

### Cambiado
- **La lista de la hermandad** (era el 78 % del tiempo y el 97 % de la basura): cada miembro se actualiza en su propia tabla, campo a campo, en vez de crear una nueva en cada refresco; y si nada cambió (la mayoría de las veces que el juego la manda), no se rehace nada ni se avisa a los módulos. Un refresco sin cambios: de 8,1 ms y 382 KB a 1,1 ms y 2 KB; con un cambio, de 7,9 ms y 382 KB a 2,3 ms y 35 KB.
- **La crónica** compara la lista sin copiar a todos los miembros cada vez (`Board.DiffInPlace`, mismos avisos que `Board.Diff`); lo guardado pasa a una tabla por GUID (`prevRoster`), y la lista antigua se convierte sola una vez.
- **Idiomas**: al entrar al mundo solo queda en memoria el idioma elegido (cambiar de idioma ya pedía recargar). Del modo capturas, solo la hermandad de ejemplo de ese idioma.
- **Minimapa**: el que dibuja los puntos y la flecha duerme cuando no hay nada que dibujar (no corre en cada fotograma) y despierta cuando cambia el mapa.
- **Líneas del sistema**: una línea que no es de duelo ni de tirada ya no crea tablas; y la misma línea se lee una vez para la Arena, «Cara a cara» y la autoprueba.

### Pruebas
- `tests/audit.mjs` (+5): la lista sin cambios no avisa y con cambios sí (los mismos miembros), la crónica dice lo mismo que antes, solo queda el idioma elegido, el minimapa duerme y despierta, y la lectura de líneas da lo mismo sin crear nada. 347 comprobaciones.

## [0.32.0] — 2026-11-13 — Addon 0.28.0: las mazmorras y bandas de WoW Forever

### Cambiado
- **Mazmorras y bandas de Forever** (el autor: «¿salen las mazmorras de WoW Forever o de otras versiones?»; ADR-031). Antes eran las de la era clásica. Ahora: las 28 mazmorras de Forever, las 9 nuevas incluidas (Salón de los Feudales, Ruinas de Lordaeron, Excavación: Los Humedales, Ciudad de Dalaran, La Ciudad Sumergida, Bastión Krol'dok, Prisión de Alcaz, Bastión Faucenegra, Bancal del Creador), y sus tres bandas: Cavernas del Túmulo (10), Cima Hyjal (20) y Guarida de Onyxia (40), con los nombres del cliente de Forever.
- Núcleo de Magma, Guarida Alanegra, Zul'Gurub, Ahn'Qiraj y Naxxramas ya no se ofrecen (no están en Forever); una raid antigua que las use se sigue leyendo y editando.
- Facciones: solo las mazmorras de dentro de una capital son de un bando. Las Minas de la Muerte y el Castillo de Colmillo Oscuro ya salen a las dos.
- JcE: reconoce las bandas nuevas por su nombre (español o inglés) o por su tamaño; muestra las tres de Forever con sus jefes (8, 13 y 1).
- Nombres corregidos con los del cliente: «Minas de la Muerte», «Templo de Atal'Hakkar», «Cumbre de Roca Negra Inferior/Superior», «Guarida Alanegra».
- Modo capturas: la hermandad de ejemplo hace Onyxia y planea Cima Hyjal y las Cavernas del Túmulo (ya no Núcleo de Magma).

### Pruebas
- `tests/audit.mjs` (+4): las 28 mazmorras y las tres bandas, las facciones, el reconocimiento por nombre y tamaño, y una raid antigua que se sigue leyendo. 342 comprobaciones.

## [0.31.0] — 2026-11-13 — Addon 0.27.0: auditoría completa

### Arreglado (lo que en el juego real fallaba y las pruebas no veían)
- **Nombres del juego en Forever** (ADR-030): `UnitName` da solo «El» y el juego puede escribir «El-Peregrino». Por eso: los duelos de la Arena no se apuntaban; las tiradas de los Huesos, la lotería y los sorteos de torneo no se leían; el oro que se da al tesorero por comercio se apuntaba a «El» y el de una carta a «Tarek» (no contaba para la cuota ni el ranking); los jefes de JcE no se apuntaban si la lista de banda daba solo el nombre; la clasificación de hermandades no verificaba ninguna ficha; y «Ver su equipo» no encontraba a nadie cerca. `Names.Short` entiende «Nombre-Apellido», y los nombres de unidades salen siempre de `Names.Unit`.
- **Lo que llega roto de otros addons** ya no deja errores internos: un grupo con los roles mal escritos, o un «¡A las armas!» con el texto roto (que además se limpia de los códigos del juego antes de salir en el aviso de banda).
- **Mensajes justo al entrar**: si el juego tarda en dar el nombre de la hermandad, lo puesto en cola ya no se tira.
- **Privacidad**: la página dice lo que el juego cuenta solo (duelos, muertes en JcJ, oro a tesoreros, jefes) y todo lo que se pide aparte (posición, equipo, otros personajes, BattleTag, avistamientos), también al volver a abrirla.
- **Aviso de versión nueva**: ya no menciona una web que no existe.
- **Tesorería**: se acepta «2g 50s» (inglés y alemán); las cuotas de todos se cuentan en una sola pasada del libro.
- **Modo capturas**: el chat, los grupos de raid y la Armería explican que en ese modo no se hace nada en el juego.

### Añadido
- Autoprueba: «Nombres del juego» y «Nombres en las líneas del juego» (la última línea de duelo o /roll, tal cual).

### Pruebas
- `tests/audit.mjs` (12). El simulador da los nombres como el juego. Fuzz de las 50 colecciones, del decodificador (5404 entradas), de los 55 tipos de mensaje (13 750) y de 143 mensajes reales rotos campo a campo (13 471): limpio. Todas las pantallas y pestañas llenas en los 7 idiomas: nada se sale. 338 comprobaciones.

## [0.30.0] — 2026-11-13 — Addon 0.26.0: modo capturas

### Añadido
- **Modo capturas** (`/bg capturas`, o «Modo capturas» en Administración; el autor: «me gustaría capturas reales del addon»): una hermandad de ejemplo con 36 miembros inventados, solo en tu pantalla, con todas las pantallas llenas (raids con grupos, chat y salas, Arena con clasificación y torneo, «Se busca», encargos, Tesorería, alianza de tres hermandades, Sala de guerra, Armería…). No sale nada de tu juego ni se hace nada en él; vuelve a tu hermandad con el mismo botón, `/bg capturas` o `/reload`. Inglés y español (ADR-029).
- `tools/demo-build.mjs` genera el ejemplo (`Data/DemoData.lua`) con el código del propio addon en el simulador.

### Arreglado
- **Armería:** la lista del equipo se salía de su panel la primera vez que se abría con alguien que comparte su equipo (medía el panel antes de que la columna de miembros tuviera ancho). Ahora se recoloca cada vez que el panel cambia de tamaño.
- **Traducciones que no salían** (en inglés y los demás idiomas): el título del Tablón y del Calendario, «dirige» en las raids, el oro de la Tesorería (cuota, clasificación de donantes, campañas, banco), la racha y los combates de la Arena, el líder de los grupos y de la alianza, la Sala de guerra (próxima operación y partes), las notas de botín y la clasificación de artesanos, y el historial de JcE. `BG.TF` ahora busca su plantilla tal cual (antes la dejaba en español y luego no se atrevía a traducir el texto entero si llevaba un nombre como «Heralds of Dawn»), y la lista de textos recoge todas las plantillas de `BG.TF`.
- El buscador de «La hermandad» («Nombre, rango, clase o zona») sale en el idioma elegido.

### Pruebas
- `tests/demo.mjs` (8): la hermandad de ejemplo, cada pantalla y cada pestaña en español e inglés (todo dentro, sin errores y sin un nombre de verdad), nada sale ni entra ni se hace en el juego, las fechas y horas, la vuelta a la hermandad real sin tocar sus datos ni su crónica. El simulador sabe de botones desactivados. 326 comprobaciones.

## [0.29.0] — 2026-11-13 — Addon 0.25.0: lo que el autor vio jugando la 0.24.0

### Cambiado
- **La mesa de los Huesos, nueva** (el autor: «no se ve nada gráfico… y no se entiende cómo funciona»):
  - Dados dibujados (hueso con sus puntos, `UI/Dice.lua`) sobre un tapete; al tirar, caen desde arriba, rebotan y giran, y se paran en su cara. Mientras el juego no dice el `/roll`, siguen rodando.
  - Los dados que pueden puntuar brillan; los elegidos se levantan en dorado, y los que no puntúan se apagan.
  - Los guardados de este turno se ven aparte.
  - El marcador de los dos tiene una barra hasta 3000.
  - Los tres pasos del turno están a la vista, con el actual marcado, y hay un aviso grande cuando salen «¡huesos!» (con lo que se pierde), al guardar los seis y al plantarse (+puntos).
  - Botones que dicen lo que hacen: «Tirar 6 dados», «Guardar y tirar 3», «Plantarme (+450)». Y «Cómo se juega» explica los pasos y la puntuación.
- **Armería desde lejos** (el autor: «no tiene sentido que tengas que estar cerca»): el juego solo inspecciona de cerca, como su propia inspección. Ahora «Ver su equipo» inspecciona si está cerca; si está lejos y tiene BlazonGuild, le pregunta (en el diálogo propio) si comparte su equipo, y si dice que sí se ve desde cualquier sitio. A cada personaje se le pregunta una vez si comparte su equipo. Sin BlazonGuild y lejos, se explica el límite del juego.
- **Las preguntas que llegan solas esperan su turno** (otro addon, compartir el equipo…): ya no tapan un diálogo que está en pantalla.

### Arreglado
- **Encargos y notas de botín: el enlace del objeto no entraba.** Ahora entra con Mayús + clic (por los tres caminos del juego: `ChatEdit_InsertLink`, `ChatFrameUtil.InsertLink` y `HandleModifiedItemClick`) y arrastrando el objeto al campo.
- **Listas desplegables de personas que salían vacías:** se hacen al abrirlas, y si no hay nadie lo dicen en vez de abrirse vacías. La de la Taberna enseña a todos los conectados; quien no tiene BlazonGuild sale gris y no se puede elegir.

### Pruebas
- `tests/fixes0250.mjs` (10). El simulador entiende el foco de un campo, Mayús + clic y arrastrar objetos. 318 comprobaciones. La mesa se ha mirado en un boceto dibujado con las posiciones reales del simulador (no es el juego).

## [0.28.0] — 2026-11-13 — Addon 0.24.0: autoprueba, mando, vista por cargo y API (entrega 13)

### Añadido
- **Autoprueba** (`/bg autoprueba`, o Administración → «Herramientas» → «Autoprueba»; la idea de `SelfTest.lua` de Olympus): comprueba en el juego real lo que las pruebas sin juego no pueden. Dice si existen los eventos y funciones que usa el addon (`ENCOUNTER_END`, `PARTY_KILL`, `INSPECT_READY`, `C_Minimap.GetViewRadius`, `GetPlayerFacing`…) y qué responden aquí: el radio del minimapa, hacia dónde miras, las coordenadas del mundo, la vida tuya y la de tu objetivo (cifra real o porcentaje), tu equipo y su nivel, si la flecha puede girar, dónde estás, el canal de la alianza, los errores de esta versión y la ida y vuelta de los mensajes por la hermandad. Cada línea dice «Sí», «No» o «--» (no se puede saber aquí). «Copiar» da el informe en texto.
- **Mando** (`Gamepad.lua` y `GamepadRegistry.lua` de Olympus): una lista de cada sitio donde BlazonGuild toca la interfaz del juego. Con la interfaz de mando activada, no pone marcas sobre los nombres ni en el chat, no abre el chat del juego, deja el atajo de teclado, no usa el canal de la alianza y no añade líneas a los menús ni a los recuadros. Al cambiar entre mando y ratón, lo quita o lo devuelve al momento, con aviso.
- **Ver como miembro** (`ViewAs.lua`): los organizadores ven el addon como un miembro (y el maestro como un oficial), solo hacia abajo, 10 minutos como mucho y nunca tras recargar. El addon guarda y comprueba con el rango real (`Store.RealOrganiser`): no se pierde nada privado mientras tanto.
- **API para otros addons** (`BlazonGuildAPI`, `docs/API.md`; la idea de `API.lua` de Olympus): solo lectura, y solo de lo que el jugador ya ve en BlazonGuild. Son las cifras de la hermandad, su ficha, las raids que vienen (cuántos por rol, sin nombres), la clasificación de la Arena, «Se busca» y los honores, más avisos de cambios. Nada llega a un addon antes de que el jugador diga que sí en el diálogo propio de BlazonGuild; `/bg api` lista los permisos y `/bg api quitar Nombre` los retira.
- Comandos nuevos en `/bg ayuda`, dos preguntas frecuentes, carta 0.24.0.

### Pruebas
- `tests/extras.mjs` (8): mando (nada tocado, y vuelta al cambiar), autoprueba (informe, ventana, copia, prueba de mensajes), ver como miembro (solo hacia abajo, lo privado se guarda, vuelve a los 10 min) y la API (nada antes del sí, sin nombres en las raids, avisos, retirar), en los 6 idiomas. 308 comprobaciones.

## [0.27.0] — 2026-11-13 — Addon 0.23.0: cara a cara, árbitros y salas de la Arena (entrega 12 completa)

### Añadido
- **«Cara a cara»** (las ideas de la ficha, la vista del duelo y la pantalla para retransmitir de Olympus: `Card.lua`, `ArenaSpectate.lua`, `Overlay.lua`): una ventana propia, fuera de la principal, con dos luchadores frente a frente: puntos, rango y puesto, victorias y derrotas, racha, últimos cinco, el cinturón y cuántas veces se han ganado entre ellos. Mientras los dos están a la vista (objetivo, foco, ratón, grupo, banda o placas de nombre), su vida en directo; al acabar el duelo, quién gana (lo dice el juego, también a quien mira). Se mueve, crece y encoge (− / +) y sigue abierta en combate: sirve para retransmitir. No envía ni guarda nada.
- **Dónde se abre:** «Cara a cara» en cada luchador de la clasificación (contra ti), «Ver un duelo» o `/bg duelo` (tu objetivo y el suyo) y «Cara a cara del siguiente combate» en cada torneo o velada en juego.
- **Árbitros de la Arena** (`ArenaRoles.lua` de Olympus, sin nada de dinero): los organizadores nombran hasta 10; deciden a mano los combates de cualquier torneo y quitan duelos apuntados por error.
- **Una sala de chat para cada torneo o velada** (`ArenaChat.lua`), en la sección Chat, durante una semana.
- Pasos de la guía, dos preguntas frecuentes, carta 0.23.0.

### Arreglado
- **Las letras V y D de los últimos combates no se traducían:** ahora W/L en inglés, S/N en alemán, V/S en italiano, В/П en ruso (y la explicación de cada idioma dice las mismas).

### Pruebas
- `tests/arenaface.mjs` (10): el modelo, la ventana (cabe, crece y encoge), la vida en directo y «fuera de vista», el resultado para quien mira sin apuntar el duelo, «Ver un duelo», árbitros, la sala del torneo, las pantallas y la ventana en los 6 idiomas. 300 comprobaciones.

## [0.26.0] — 2026-11-13 — Addon 0.22.0: alianza completa (entrega 6, lo que faltaba)

### Añadido
- **Cartas a los líderes** (la idea de los «writs» de Olympus, `Acts.lua`): la hermandad que lidera la alianza escribe cartas firmadas a los maestros (o a maestros y capitanes). Cada uno las ve en Alianza, pestaña «Cartas y avisos», y las marca como leídas; el liderazgo ve cuántos las han leído.
- **Puertas abiertas** («Open the Gates» de Olympus): el liderazgo dice durante unas horas a qué hermandad de la alianza van los nuevos; sale en «Cartas y avisos» y en Reclutamiento de todas las hermandades.
- **Ocultar en toda la alianza** (`Moderation.lua` de Olympus, a nuestra manera): el liderazgo oculta a un jugador o a una hermandad en los chats comunes de la alianza (toda la alianza y las salas compartidas) durante 1 hora, 1 día o 7 días; la lista la ven los organizadores y se puede quitar.
- **Operaciones de toda la alianza:** en la Sala de guerra, «Quién va» → «Toda la alianza» (solo el liderazgo). La operación llega a la Sala de guerra de cada hermandad, con sus avisos de siempre; cada uno responde en la suya, y el mensajero de cada hermandad cuenta al liderazgo cuántos van. Solo el liderazgo la empieza, la cambia o la cancela.
- **Chat de la alianza por un canal del juego** (`ChatHall.lua` de Olympus): cada addon entra en un canal oculto con nombre y contraseña sacados de la clave de la alianza; las líneas de «Toda la alianza» y de las salas compartidas salen también como texto del propio jugador al pulsar Intro (el juego solo lo deja así), con la marca de la alianza. El camino de siempre (hermandad y mensajeros) sigue igual; cada línea se toma una vez. El canal no sale en las ventanas de chat. `/bg estado` dice si estás dentro.
- Todo lo que hace el liderazgo va firmado con la clave de un organizador de su hermandad, y cada hermandad lo guarda en sus registros cuando uno de sus organizadores comprueba la firma (así le llega también a quien entra más tarde).

### Cambiado
- **Alianza en tres pestañas:** «Hermandades», «Cartas y avisos» y «Gestión» (cargos e invitaciones).
- La Sala de guerra escribe cada operación en frases enteras («Lugar: «…»», «Dirige: …»), para que cada idioma la traduzca entera.

### Arreglado
- **La pantalla de la Alianza vista por un maestro no cabía** (nadie lo había visto: la prueba la miraba como miembro): «Nombrar» e «Invitar» se salían del panel y «Ocultarme» y «Salir de la alianza» se montaban. Ahora los cargos y las invitaciones están en «Gestión» y las filas se ajustan al ancho.
- **«JcJ» y «JcE» no se traducían** (el extractor los tomaba por nombres del juego): ahora PvP y PvE en inglés, alemán, italiano y ruso, JxJ y JxA en portugués, JcJ y JcE en francés.
- **El sitio de una operación se traducía a trozos** (en ruso, «Molino de Tarren» salía «Molino из Tarren») y «Dirige» quedaba en español.

### Pruebas
- `tests/acts.mjs` (11), con dos hermandades en alianza: cartas, firma falsa de otra hermandad rechazada, puertas, ocultar y quitar, operación de toda la alianza con respuestas contadas, canal (dentro, oculto, línea falsa rechazada, una vez cada línea) y las pantallas del maestro en los 6 idiomas. El simulador entrega ahora las líneas de los canales de chat. 290 comprobaciones.

## [0.25.0] — 2026-11-13 — Addon 0.21.0: minimapa, flecha y avistamientos (entrega 7 completa)

### Añadido (lo que quedaba de la entrega 7)
- **Puntos en el minimapa:** quien comparte su posición sale también como un punto de su color de clase en el minimapa de sus compañeros, si está a su alcance (se tiene en cuenta el zoom, el interior y el minimapa que gira). «Quitar los puntos del minimapa» los apaga. Sin librerías: el cálculo es nuestro, con la conversión a coordenadas del mundo del propio juego.
- **Flecha para seguir** (la idea de la flecha hacia el líder de Olympus, `KingArrow.lua`): «Seguir» pone una flecha bajo el minimapa que apunta a un compañero que comparte su posición, al punto de una «Reunión aquí» o a un avistamiento, con los metros que faltan. Se mueve arrastrándola; clic derecho la quita; al llegar a un punto se apaga sola, y si el compañero deja de compartir, al minuto.
- **Avistamientos** (`PlayerSightings.lua` de Olympus, a nuestra manera): cada addon recuerda, solo en memoria y un cuarto de hora, a los jugadores de la otra facción que su juego le enseñó (objetivo, ratón, placa de nombre) fuera de mazmorras. Nada sale solo: un miembro pregunta por un nombre o por los enemigos de su zona, y responden por susurro, solo a él, los compañeros que aceptan la línea «avistamientos» de la privacidad (apagada al principio).
- **Mapa con tres pestañas:** «Zonas», «En el mapa» (quién comparte su posición y el punto de reunión, cada uno con «Seguir») y «Avistamientos».
- Guía del Mapa con dos pasos más, dos preguntas frecuentes nuevas, carta de novedades 0.21.0.

### Cambiado
- La pregunta frecuente «¿Se ve en la web?» decía que sí; ahora dice la verdad: no hace falta web ni programa aparte, todo va dentro del juego.
- La descripción del addon en la lista de addons del juego ya no habla de la web, y sale en los 7 idiomas.

### Pruebas
- `tests/radar.mjs` (13): puntos donde tocan y con el minimapa que gira, la flecha (distancia, giro, llegar, compañero perdido), el punto de reunión, y los avistamientos (solo la otra facción, nada sin pregunta, solo responde quien lo acepta, solo por susurro a quien pregunta, respuestas falsas rechazadas, la pantalla en los 6 idiomas). El simulador usa ahora los mismos ejes del mundo que el juego. 279 comprobaciones.

## [0.24.0] — 2026-11-13 — Addon 0.20.0: Armería, JcE y clasificación de hermandades

### Añadido (las dos secciones que decían «Pronto», y lo que pidió el autor: «rankings y estadísticas y comparativas contra guilds, top guilds»)
- **Armería.** El equipo de cada miembro, ranura a ranura (icono, nombre en el color de su calidad, el tooltip del juego al pasar el ratón), con su nivel de objeto medio, si lleva tabardo y sus profesiones.
  - **Compartido:** cada uno decide con «Compartir mi equipo» (apagado hasta que lo enciende; registro `gear`); se actualiza solo al cambiarse de equipo, y desaparece si lo apaga.
  - **Inspeccionado:** «Inspeccionar» a alguien cerca (objetivo, ratón encima o grupo) con la inspección del propio juego, una a la vez, nunca en combate ni con la ventana de inspección abierta. Lo ves solo tú y no se envía a nadie.
- **JcE.** Por banda: cuántos tienen el nivel (y cuántos están conectados) y los jefes derrotados. Un jefe se apunta solo (registro `kills`) cuando muere (`ENCOUNTER_END`) en una banda con un grupo mayoritariamente de la hermandad; una vez por día y jefe. Debajo, las últimas raids de BlazonGuild con cuántos fueron. **`ENCOUNTER_END` no está comprobado aún en el cliente de Forever.**
- **Clasificación de hermandades** (Rankings, pestaña «Hermandades», ADR-024): las hermandades de vuestra facción con BlazonGuild, ordenadas por 11 cifras (miembros, nivel máximo, activos, jefes, bandas enteras, raids, cazadores, duelos, mejor de la Arena, artesanos, con el addon), con vuestro puesto y una comparativa al pulsar una.
  - Sale una hermandad solo si su maestro lo activa («Publicar nuestras cifras»); la ficha lleva cifras de la hermandad, nunca nombres.
  - Las fichas viajan al jugar en grupo con alguien de otra hermandad (`GH` al grupo); la del propio grupo se verifica con el nombre de hermandad que da el juego, y se pasa a toda vuestra hermandad (`GV`). Las que cuenta un tercero (`GK`) salen «sin verificar» y no se pasan.
- Pregunta frecuente sobre la clasificación; carta de novedades 0.20.0. La página de privacidad dice ahora lo de la clasificación (y ya no promete la web).

### Pruebas
- `tests/armory.mjs` (9) y `tests/guildranks.mjs` (8), con varias hermandades simuladas jugando en grupo. 266 comprobaciones; las pantallas nuevas, en los 6 idiomas sin español y sin nada fuera de su sitio.

## [0.23.1] — 2026-11-13 — Addon 0.19.1: hermandades distintas, cada una con lo suyo (auditoría)

### Seguridad (auditoría pedida por el autor: «cada jugador puede ser de distintas guilds, que no haya problemas de ningún tipo»)
- **Grave, corregido:** un jugador de **otra hermandad** con BlazonGuild podía meter registros en la vuestra por susurro, haciéndolos pasar por una respuesta de puesta al día (`SA`): un torneo, una sala de chat, su ficha, un grupo, boletos de lotería, filas de «Se busca» o un voto en vuestras encuestas. Las reglas de cada registro solo miraban que el autor escribiera lo suyo, no que fuera de la hermandad. Ahora un registro que llega por susurro solo cuenta si quien lo trae es miembro (según vuestra lista del juego); por el canal de la hermandad solo pueden hablar los miembros.
- **Dos hermandades distintas con el mismo nombre** (una de cada facción, o de otro reino) compartían los datos guardados en un ordenador con personajes en las dos (la clave era solo región y nombre). Ahora se guardan por región, reino, facción y nombre; lo de antes pasa a su hermandad, nunca a la de la otra facción.
- Las denuncias y los BattleTags que guarda un organizador eran de toda la cuenta (un alt suyo en otra hermandad los veía, y las sanciones por BattleTag podían cruzarse): ahora son de cada hermandad. Los de antes se descartan.
- Denuncias (`RP`), BattleTags (`BT`) y respuestas al `/bg prueba` (`PO`) de alguien que no es de la hermandad se ignoran; como mucho 5 denuncias en 10 minutos de la misma persona.
- Invitaciones a una alianza (`AI`, que puede mandar cualquiera): una por minuto de cada jugador y, como mucho, 10 esperando.
- **Casos de moderación y avisos** solo viajan (por susurro, `RO`) a los organizadores y solo los guardan ellos; antes estaban en el ordenador de todos los miembros aunque no se vieran. Un organizador que entra pide a otro organizador lo que le falte.

### Pruebas
- Nueva `tests/guilds.mjs` (9): lo que susurra alguien de otra hermandad no entra (y la prueba demuestra que sin el arreglo sí entraba); no recibe nada vuestro; sus denuncias, BattleTag e invitaciones en masa no pasan; un ordenador con hermandades del mismo nombre en las dos facciones; los datos de antes; denuncias por hermandad. 249 comprobaciones.

## [0.23.0] — 2026-11-13 — Addon 0.19.0: idiomas

### Añadido (pedido por el autor: «todo en más idiomas, los principales de WoW»)
- **El addon en inglés, alemán, francés, italiano, portugués y ruso**, además de español. Sale en el idioma del juego (`GetLocale`); en Administración, fila «Idioma del addon», o con `/bg idioma en|de|fr|it|pt|ru|es|auto`, se elige otro (se aplica al recargar la interfaz, y lo pregunta).
- Las fechas en cada idioma («Thursday 12 November», «Donnerstag, 12. November», «четверг, 12 ноября»…). En ruso, con un cliente de otro idioma, se usa la letra cirílica del propio juego.
- Lo que escribe cada uno (notas, anuncios, mensajes), los nombres y los rangos de la hermandad salen tal cual.
- Carta de novedades 0.19.0 y una pregunta frecuente nueva («¿En qué idioma sale el addon?»).

### Cómo funciona
- El español sigue escrito en el código. `tests/i18n-keys.mjs` saca los 2236 textos (también los que el código une con `..` y los de `string.format`), `i18n/<idioma>/*.json` tiene sus traducciones y `tests/i18n-build.mjs` hace `Locales/<idioma>.lua`.
- Cada texto se traduce al enseñarse (`SetText` de nuestros textos, avisos, ventanas, tooltips y líneas del chat del addon): entero; o por plantilla (con sus valores traducidos); o por líneas, frases, colores o listas. Una plantilla o un final conocido solo se usan si todo queda traducido: nunca media frase en cada idioma. Un mensaje largo de alguien se deja enseguida tal cual.
- Nueva prueba `tests/locales.mjs` (21 comprobaciones): todos los textos están y con los mismos valores en los 6 idiomas; cada pantalla, pestaña y guía, en cada idioma, sin español y sin nada fuera de su sitio; ningún texto mitad y mitad; fechas; el idioma del juego y el que se elige.

### Corregido
- Las etiquetas en mayúsculas (las cifras del resumen) ponen bien las letras con tilde («TESORERÍA», no «TESORERíA»).

## [0.22.0] — 2026-11-13 — Addon 0.18.0: la Taberna (entrega 12, tercera parte)

### Añadido
- **Arena, pestaña «Taberna».** Todo por puntos: no se mueve ni se apuesta oro.
- **Huesos** (el juego de dados de taberna, Farkle): tirar seis dados, apartar los que puntúan, arriesgar o plantarse; una tirada sin puntos pierde lo del turno; a 3000. Los dados salen de un solo `/roll` del juego (de 1 a 6^n, leído en base 6), que todos ven.
  - **Contra la casa**, para practicar solo (sus dados son locales; no se envía ni se guarda nada).
  - **Contra un miembro** con BlazonGuild: invitación y respuesta; cada tirada y cada elección llegan al otro, y los dos juegan la misma partida. Nadie juega fuera de su turno. El que pierde apunta la partida, y sale quién gana más.
- **Lotería de práctica:** cada día, hasta 3 boletos gratis (del 1 al 100); un oficial sortea con `/roll 1-100` y se anuncia quién acierta; los días anteriores quedan a la vista.
- **El posadero:** al hablar con uno, un aviso propone una partida (una vez por posadero). La ventana del juego no se toca.

## [0.21.2] — 2026-11-13 — Addon 0.17.2: filas en los grupos y lista de miembros en la velada

### Cambiado (pedido por el autor)
- **Grupos de la raid:** se elige la fila dentro del grupo (se queda donde se suelta; soltarlo sobre otro les cambia grupo y fila). Se guarda en el plan (`plans.s`). En la banda real el orden dentro de cada grupo lo pone el juego: ningún addon puede cambiarlo, y la pantalla lo dice.
- **Velada, «Añadir combate»:** cada luchador se elige de una lista con los miembros por orden alfabético (con su nivel y si está conectado), o se escribe parte del nombre y la lista se queda con los que coinciden.

## [0.21.1] — 2026-11-13 — Addon 0.17.1: lo que el autor vio en Raids

### Corregido
- **«Voy», «Quizá» y «No voy» no se guardaban al pulsarlos** (solo cambiaba el botón; hacía falta «Guardar», y en una raid cancelada «Guardar» no hacía nada): ahora se guardan al momento, y el rol también si ya estás apuntado. «Guardar» queda para el comentario.
- **Una raid cancelada seguía enseñándolo todo** (inscripción, composición, botones) y a la izquierda «Voy». Ahora: cabecera con «CANCELADA» grande en rojo y la imagen apagada, una frase, «Cancelada» en la lista; quien la gestiona ve solo «Volver a programar» y «Borrar».
- **Volver a programar una raid cancelada no la reactivaba** (el aviso decía que sí): al guardarla con su nuevo día queda programada.
- Nuevo «Borrar» una raid (quien la creó, quien la dirige o un organizador).

## [0.21.0] — 2026-11-13 — Addon 0.17.0: torneos y veladas (entrega 12, segunda parte)

### Añadido
- **Arena, pestaña «Torneos»:** cualquiera crea un torneo (4, 8 o 16 luchadores) o una velada. Sin apuestas.
- **Torneo:** cada uno se apunta; quien lo dirige pulsa «Sortear y empezar». Los mejores de la Arena son cabezas de serie (no se cruzan al principio) y el resto sale del `/roll` del juego, una tirada por puesto, que todos ven en el chat y que queda guardada. Los huecos son pases directos para los cabezas de serie.
- **Los resultados se apuntan solos:** cuando ya se sabe quiénes se enfrentan, el primer duelo entre los dos decide el combate (uno de antes no cuenta). Toda la hermandad se entera de quién pasa y de quién gana el torneo. Quien lo dirige puede decidir un combate a mano si alguien no se presenta.
- **El cuadro:** una columna por ronda, con líneas a la siguiente; el que pasa en dorado.
- **Velada:** combates anunciados («A contra B»), cada uno decidido por su duelo.
- **Honor «Campeón de la Arena»** en Rankings (la mejor puntuación de la temporada).

### Corregido
- Algunos botones cambiaban su texto con la función del juego y no con su propia etiqueta, así que en el juego salían vacíos («Apuntar mis muertes y bajas», «Marcas en nombres y chat»). Ahora todos los botones cambian su etiqueta, y la comprobación de diseño avisa de un botón sin texto visible.

## [0.20.0] — 2026-11-13 — Addon 0.16.0: grupos de la banda arrastrando

### Añadido
- **Raids, «Grupos»** (pedido por el autor): los grupos de la banda como el marco de banda del juego. Tantos grupos como pide la banda (2, 4 u 8), cinco sitios cada uno; a un lado «Sin grupo» y «Reserva».
- **Mover a la gente:** arrastrar un nombre con el ratón, o pulsarlo y luego pulsar dónde va. Soltarlo sobre otro jugador los cambia de sitio; clic derecho lo deja sin grupo; un grupo lleno lo dice.
- **Quién:** todos los ven; los mueven el líder de la raid, quien la creó y los oficiales.
- **«Repartir solos»** (el reparto por roles de antes) y **«Colocar en la banda»**: con la banda formada, mueve a cada uno a su grupo de verdad, de uno en uno y entrando en un grupo lleno por intercambio. Líder o ayudante, fuera de combate. Dice cuántos movió y quién del plan no está en la banda.
- Guía «Cómo funciona» de Raids.

### Pruebas
- Los stubs miden los marcos por sus anclas, como el juego (antes una lista medía 0 y pintaba una sola fila). Nuevas pruebas de los grupos (8/8, 199 en total).

## [0.19.1] — 2026-11-13 — Addon 0.15.1: lo que el autor vio en Tesorería, Arena, Rankings y Administración

### Corregido
- **La Arena y «Se busca» se quedaban a medias en el juego** («attempt to call a nil value»): cambiaban el título de un cuadro, que en el juego es un marco sin texto propio. Por eso la Arena enseñaba «Nueva temporada» a cualquier miembro. El título ahora sabe cambiar su texto, y el botón sale oculto desde el principio.
- **Tesorería:** «0 de cobre» no cabía en su cuadro y se montaba sobre el de al lado. Las cifras grandes van con las monedas del juego, la letra se encoge si hace falta y, si aun así no cabe, se corta dentro del cuadro y se lee entera con el ratón.
- **Reclutamiento:** el título «Ficha pública de la hermandad» corría bajo «Editar ficha» (ahora «Vuestra ficha»).

### Cambiado
- **Rankings:** a la izquierda los cinco honores con quién lo lleva; a la derecha, los 10 primeros del que elijas. Fuera el honor de los primeros en llegar al nivel 60 (el juego ya había empezado: muchos ya lo eran).
- **Arena, «Retos»:** salen todos los conectados; quien no tiene BlazonGuild sale sin «Retar» y con el porqué. Se explica cómo retar.
- **Administración:** solo los errores de esta versión salen en rojo; «Borrarlos» los limpia.

### Pruebas
- Los stubs son más estrictos, como el juego: `SetText` solo existe en lo que tiene texto; el ancho de un texto depende del tamaño de su letra; y la comprobación de diseño avisa si un texto de una línea se sale de su panel. Con eso aparecieron los fallos de arriba.

## [0.19.0] — 2026-11-13 — Addon 0.15.0: la Arena (entrega 12, primera parte)

### Añadido
- **Sección Arena**, con guía «Cómo funciona». Sin apuestas.
- **Duelos que se apuntan solos:** al terminar un duelo entre dos de la hermandad, el juego escribe quién ganó; el addon de quien pierde lo apunta. Solo quien pierde apunta, así nadie puede darse victorias. Se lee en cualquier idioma (los textos del propio juego).
- **Clasificación por temporada:** todos empiezan con 1500; ganar a alguien mejor o de más nivel da más; los mismos dos en 24 horas valen cada vez la mitad. Con 5 combates, rango Oro, Plata o Bronce. Cinturón de campeón: quien gana al campeón se lo queda.
- **Temporadas:** un oficial empieza una nueva; la anterior se guarda con su campeón y su podio.
- **Retos:** «Retar» a quien esté conectado con BlazonGuild (los de tu zona primero); le llega con «Aceptar» y «No», y os avisamos a los dos. El duelo lo empezáis desde el juego.
- Cuando alguien de la hermandad te reta en el juego, te dice su puntuación. La ficha de cada miembro enseña su Arena. `/bg arena`.

### Corregido
- Los retos usaban al principio el mismo código de mensaje que el chat de la alianza (`AC`) y lo dejaban mudo; las pruebas lo cazaron antes de instalarlo. Ahora son `DQ`/`DY`, y el addon se niega a registrar un código repetido.

## [0.18.0] — 2026-11-13 — Addon 0.14.0: «Se busca», honores y marcas (entrega 11)

### Añadido
- **Sección «Se busca»** (el hueco del menú que ponía «JcJ»), con guía «Cómo funciona».
- **Quién entra en la lista:** solo quien de la otra facción mata a un miembro fuera de mazmorras y campos de batalla, visto por el propio addon de ese miembro (el resumen de muerte del juego). Nadie puede apuntar a otro a mano.
- **Recompensa:** cada muerte suma 1 (2 si el asesino le sacaba 10 niveles o más, o salía con «??»). Al llegar a 3, aviso «Se busca» a toda la hermandad.
- **Cazar:** tu golpe final sobre un buscado te da su recompensa más 1 punto, y la recompensa vuelve a cero. Ranking de cazadores de 90 días. «Lo último»: cada muerte y baja, con «Quitar» para quien la apuntó y los oficiales.
- **Aviso «Cerca»:** si ves a un buscado (objetivo, ratón o placa de nombre), te avisa una vez cada cinco minutos.
- **Rankings y honores** (el hueco «Rankings»): podios de mejor cazador, mayor donante (si el maestro deja verlo), mejor artesano, mejor reclutador, fiel a las raids y pioneros del nivel máximo. El primero de cada podio lleva el honor en su ficha.
- **Marcas:** escudo de BlazonGuild sobre el nombre de los miembros (con aro dorado si tienen un honor) y calavera roja sobre los buscados; aro en el retrato del objetivo. `/bg marcas` las quita.
- **Marca de honor en el chat:** escudo dorado junto a lo que escribe un miembro con honor, en el chat de BlazonGuild (antes del nombre) y en las ventanas de chat del juego (justo después del nombre: el filtro del juego deja cambiar el mensaje, no el nombre). Nada se toca si el juego oculta el mensaje.
- `/bg estado` dice si «Se busca» y la marca del chat funcionan en este cliente, y qué pasó con la última muerte leída.
- Interruptor «Apuntar mis muertes y bajas». `/bg sebusca`.

### Notas técnicas
- Nunca se usa el registro de combate completo (`COMBAT_LOG_EVENT_UNFILTERED`): en Forever está restringido y registrarlo muestra el aviso de «bloqueado» del juego. Se usan `PARTY_KILL` (el evento nativo, solo nuestro golpe final) y `C_DeathRecap` (ADR-021).
- La facción se prueba con la raza que da el juego para ese GUID (`GetPlayerInfoByGUID`); una raza de las dos facciones no prueba nada.

## [0.17.0] — 2026-11-13 — Addon 0.13.0: reclutamiento (entrega 10)

### Añadido
- **Sección Reclutamiento**, con guía «Cómo funciona».
- **Ficha pública de la hermandad:** a qué os dedicáis, idioma, cuándo jugáis, a quién buscáis (roles y clases) y si reclutáis. La escriben los oficiales.
- **«Únete», para quien no tiene hermandad:** la ventana abre ahí; busca una hermandad por su nombre (el `/who` del juego), ve su ficha y pide entrar con unas palabras.
- **Bandeja de los oficiales:** «Quiere entrar en la hermandad», con «Invitar» (la invitación del propio juego, un clic) y «No». El addon nunca invita solo.
- **Quién te trajo:** cada miembro lo dice una vez, y sale quién trae más gente.
- **Traer tu ficha:** si cambias de hermandad, el addon te ofrece traer tu presentación, rol y horario.
- `/bg reclutar`.

## [0.16.0] — 2026-11-13 — Addon 0.12.0: tesorería (entrega 9)

### Añadido
- **Sección Tesorería**, con guía «Cómo funciona». El addon nunca mueve oro: apunta lo que pasa.
- **Tesoreros y cuota:** el maestro nombra a los tesoreros, pone una cuota semanal opcional y decide qué ven los miembros (saldo, ranking de donantes, libro).
- **Libro que se apunta solo:** el oro que un miembro da a un tesorero por comercio o por correo es una entrada, el que el tesorero envía una salida; también a mano, con concepto y campaña. Al donante le llega un «gracias».
- **Cuotas:** cada miembro ve en «Resumen» cuánto ha dado esta semana y cuánto le falta; los oficiales ven quién está al día y marcan exentos.
- **Campañas de donación** con barra de progreso, **foto del banco** de la hermandad al abrirlo un oficial o tesorero, y **copia de seguridad** del libro en texto.
- `/bg tesoreria`.

## [0.15.2] — 2026-11-13 — Addon 0.11.2: leer todo el texto

### Añadido
- **Tarjetas que se despliegan:** pulsa cualquier tarjeta para leer todo su texto (y sus detalles: la nota de un encargo, quién respondió a una operación, los miembros de una escuadra, todo lo que sabe hacer un artesano…); otro clic la recoge. Al pasar el ratón por encima se ve entero en un recuadro.
- Las pruebas comprueban también que ningún texto quede debajo de un botón, en todas las pantallas, vacías y con datos.

### Arreglado
- El texto de las tarjetas ya no queda debajo de sus botones (el autor lo vio en un encargo: «Para quien sepa hac…» bajo «Cancelar»).
- Grupos: en el panel de tu grupo, «Faltan… Dentro: …» quedaba bajo «Cerrar grupo».
- Tablón: «Turnos de palabra abiertos. Habla…» quedaba bajo «Siguiente».

## [0.15.1] — 2026-11-12 — Addon 0.11.1: lo que el autor vio en Artesanía

### Arreglado
- Artesanía y botín se veía con las tres pestañas una encima de otra: Forever no tiene el evento `CRAFT_SHOW`, registrarlo daba error y la mitad del fichero de datos no llegaba a cargarse. Ahora un evento que el cliente no tenga se salta sin error, y las pruebas lo reproducen.
- Sala de guerra: quien dirige una operación veía «No puedo» y «Editar» montados en una ventana estrecha; sus botones pasan arriba a la derecha.

### Añadido
- **«Cómo funciona»**: una guía corta por pasos y con ejemplos de Artesanía y botín, Mapa, Alianza y Sala de guerra. Sale sola la primera vez y luego con el botón «?» de arriba.
- Las pruebas comprueban también que ningún botón ni casilla se monte encima de otro, en todas las pantallas.

### Cambiado
- Artesanía y botín: pestañas «Quién fabrica qué», «Encargos» y «Botín de banda», y textos que dicen qué hacer en cada caso.

## [0.15.0] — 2026-11-12 — Addon 0.11.0: artesanía y botín (entrega 8)

### Añadido
- **Sección «Artesanía y botín»**, con tres pestañas.
- **Artesanos:** al abrir tu profesión en el juego, el addon la lee y te pregunta si publicarla; la hermandad ve quién sabe hacer qué, busca «¿quién sabe hacer…?» y susurra al artesano con un clic.
- **Encargos:** pides un objeto (a un artesano o a quien sepa hacerlo, con cantidad y nota); el artesano lo toma y lo da por hecho, y tú confirmas que lo recibiste. Los encargos confirmados hacen el **ranking de artesanos** (90 días).
- **Botín:** los organizadores anotan a quién se dio cada objeto y por qué, y, si la hermandad los usa, puntos a mano. Sin pujas ni oro.
- `/bg artesania`.

### Cambiado
- El menú reparte su alto entre todas las secciones para que quepan sin tocar el pie.

## [0.14.2] — 2026-11-12 — Addon 0.10.2: minimizar y botón del minimapa

### Añadido
- **Minimizar** (botón junto a la X): la ventana deja una barra pequeña con el escudo, la sección y los mensajes nuevos; se arrastra a cualquier sitio y al pulsarla vuelve la ventana.
- **El mapa del mundo la minimiza solo**, y la devuelve al cerrarlo (si la minimizaste tú, se queda minimizada).
- **Botón redondo en el minimapa**: clic para abrir o cerrar; arrastrándolo se mueve por el borde; `/bg minimapa` lo oculta o lo devuelve.

### Cambiado
- Mapa: «aquí estás» pasa a la derecha de la tarjeta, para que el nombre de la zona no se corte.
- Mapa: cómo saber tu capa, explicado sin la palabra «PNJ» (clic en dos personajes que no sean jugadores, en el juego).

## [0.14.1] — 2026-11-12 — Addon 0.10.1: lo que el autor vio en el Mapa y el chat

### Arreglado
- Mapa: el botón «No aceptar peticiones» se salía del panel. «Crear la alianza» también se salía para el maestro. Ahora los botones se reparten el ancho del panel, y las pruebas comprueban en todas las pantallas que nada se salga.
- Chat: los enlaces de objetos con el color nuevo del juego (`|cnIQ3:`) salían rotos ("/cnIQ3:/Hitem…"); ahora se ven, y los ya guardados se arreglan.
- Chat: dos líneas de sesiones distintas podían tener el mismo identificador.

### Cambiado
- Mapa explica qué hace compartir la posición: quién te ve (tu hermandad, con BlazonGuild), dónde (el mapa del mundo, tecla M), cuántos la comparten ahora, y tiene un botón para abrir el mapa del mundo. Las capas explican qué son y cómo saber la tuya.
- Chat de hermandad: lo que se dijo mientras no estabas te lo pasan los compañeros con BlazonGuild que estaban conectados. Su descripción dice que se ve lo de todos, tengan o no el addon.

## [0.14.0] — 2026-11-12 — Addon 0.10.0: mapa y capas (entrega 7)

### Añadido
- **Sección Mapa:** cuántos compañeros hay conectados en cada zona y quiénes (del roster: funciona aunque no tengan el addon).
- **Compartir posición y capa**, apagado hasta que cada uno lo enciende y solo con su hermandad: los compañeros salen como puntos de su color de clase en el mapa del mundo.
- **Capas:** el addon sabe en qué copia de la zona estás por los PNJ que ves, y enseña las capas de tu hermandad en tu zona.
- **Pedir invitación a otra capa:** quien está en ella decide (el addon nunca invita solo); al llegar a su capa, el addon te saca del grupo. Si está en otro subreino, te dice que salgas y vuelvas a entrar.
- `/bg mapa`.

### Cambiado
- El menú aprieta un poco sus filas para que quepan las dieciséis secciones.
- Sala de guerra vacía: «Aún no hay escuadras» en vez de «0 escuadras con 0 personas».

## [0.13.0] — 2026-11-12 — Addon 0.9.0: sala de guerra (entrega 6, tercera parte)

### Añadido
- **Sala de guerra:** escuadras con su jefe, su especialidad (asalto, defensa, exploración, apoyo) y su propio chat; los organizadores las crean y el jefe elige a su gente.
- **Operaciones:** qué se hace, cuándo, dónde y qué escuadras van (o toda la hermandad). Las planean los organizadores y los jefes de escuadra; cada uno responde «Voy», «Reserva» o «No puedo». Alerta en pantalla al ponerla en marcha y recordatorio un cuarto de hora antes.
- **Partes:** al terminar, quien la dirigió anota el resultado; queda en la crónica con los presentes.
- `/bg guerra` abre la sala.

### Cambiado
- Chat de la alianza: una línea de otra hermandad solo se acepta de su autor (antes, un miembro de esa hermandad podía escribir en nombre de otro).
- Los capitanes de la alianza ya ven la pestaña «Oficiales de la alianza» en el chat (en la 0.8.0 podían escribir, pero la pestaña solo salía a los organizadores).
- Raids: el aviso de permiso ya no dice que solo los oficiales crean raids.

## [0.12.0] — 2026-11-12 — Addon 0.8.0: liderazgo de la alianza (entrega 6, segunda parte)

### Añadido
- **Líder de la alianza:** el maestro de la hermandad que vota más de la mitad de las hermandades (si no, la fundadora). Cada maestro vota con el botón «Votar» de cada hermandad.
- **Llamada a las armas de toda la alianza** y **clave nueva**, para la hermandad del líder. El líder puede **sacar a una hermandad**; la alianza recibe una clave nueva. Si una hermandad sale, también.
- **Cargos:** cada maestro nombra capitanes (entran en «Oficiales de la alianza») y mensajeros (llevan los mensajes a las otras hermandades).
- **Firmas:** cada cambio de la alianza va firmado (Ed25519, de Olympus, MIT) y las demás hermandades lo comprueban; un miembro no puede falsificar quién está, quién manda ni la clave.
- **Personas, no personajes:** la alianza cuenta cada persona una vez (alters confirmados y rango de alters).
- **Ocultarse:** un organizador puede no aparecer como conectado ante las otras hermandades.

### Arreglado
- Quien se conectaba más tarde no recibía el registro de la alianza: en la puesta al día iba demasiado anidado para el formato de mensajes y el envío fallaba sin avisar. Ahora cabe, y un mensaje que no se puede escribir queda en el registro de errores.
- Un mensaje largo por susurro a alguien que no está jugando se seguía enviando pieza a pieza; ahora se para al primer aviso del servidor ("No player named…") y va a otro contacto.

## [0.11.0] — 2026-11-12 — Addon 0.7.0: hermandades hermanas (entrega 6, primera parte)

### Añadido
- **Alianza:** varias hermandades se unen si sus maestros lo aceptan. El maestro la crea y escribe el nombre de alguien de la otra hermandad que tenga BlazonGuild; quien la recibe la guarda para su maestro, que la acepta o la rechaza cuando se conecte. Cada hermandad sigue con su maestro y puede salir cuando quiera. No se puede con la otra facción.
- **Chat con pestañas por hermandad:** «Toda la alianza», una pestaña para cada hermandad hermana (solo la leen esas dos), «Oficiales de la alianza» y «Maestros». Cada línea lleva el nombre de su hermandad. Las salas de Sanadores, Tanques, Daño, Comercio y Ayuda se comparten con toda la alianza.
- **Sección Alianza:** qué es y quién decide; con alianza, totales de todas (hermandades, miembros, conectados, con BlazonGuild), una tarjeta por hermandad con su gente conectada, su maestro, su mensajero y el botón «Hablar».
- **Grupos para todo:** «Mazmorras» pasa a llamarse **Grupos** y admite JcJ, misiones, subir de nivel, farmear u otra cosa, además de mazmorras y bandas.

### Cambiado
- Administración: textos más cortos que ya no se cortan, y una fila con el estado de la alianza.
- Calendario: ya no dice que solo los organizadores crean raids.

## [0.10.0] — 2026-11-12 — Addon 0.6.0: el tablón de la hermandad (entrega 5)

### Añadido
- **Tablón:** anuncios de los organizadores (normales o importantes) sabiendo quién los ha leído; encuestas que puede lanzar cualquiera, con cuenta atrás y resultados en barras; turnos de palabra para reuniones (el organizador abre, cada uno pide turno y se da la palabra en orden); preguntas frecuentes (las de BlazonGuild y las que añada la hermandad).
- **«¡A las armas!» y «Reunión aquí»** para los organizadores: alerta grande en el centro de la pantalla, sonido de alerta de banda y, en la reunión, una marca en el mapa donde está quien llama.
- **Crónica y resumen de la semana:** entradas, salidas, ascensos, nivel 60, raids, decisiones y llamadas, según los ve cada addon.
- **Carta de novedades** tras cada actualización (con todo lo que te perdiste si saltaste versiones) y **bienvenida** cuando te ascienden a un rango que organiza.

## [0.9.0] — 2026-11-12 — Addon 0.5.0: chat y moderación (entrega 4), y lo que el autor vio en el juego

### Añadido
- **Chat dentro de BlazonGuild:** el chat de hermandad (y el de oficiales, para quien puede leerlo) con más espacio, nombres con el color de su clase, marcas de maestro y organizadores y enlaces de objetos; **salas** (Sanadores, Tanques, Daño, Comercio y artesanía, Ayuda) y las que cree cualquier miembro.
- **Moderación** para los organizadores: silenciar 5 min, 30 min, 1 h, 24 h o 7 días; avisos (al tercero se abre un caso: opinan los organizadores y decide el maestro; el addon nunca expulsa); borrar mensajes de las salas; palabras filtradas para toda la hermandad; denuncias que llegan solo a los organizadores; y, para quien lo acepta, el silencio alcanza a todos los personajes del mismo BattleTag (que solo conocen los organizadores).
- **Administración:** estado de la conexión de un vistazo (privacidad, prueba de mensajes con su resultado, quién usa el addon, mensajero, mensajes, errores) y quién organiza (lo elige el maestro).
- **Avisos en pantalla** para lo que te afecta: raid nueva o cancelada, peticiones a tu grupo, si te aceptan. `/bg avisos` los apaga.
- **Portadas con arte oficial** en Raids (la de cada banda), Calendario y Administración; iconos de rol oficiales del juego.

### Cambiado (lo pidió el autor tras probar la 0.4.0)
- **Cualquier miembro crea raids** y dirige las suyas; los organizadores gestionan todas (ADR-018).
- `/bg prueba` abre Administración y enseña el resultado ahí y en un aviso, no solo en el chat.
- Calendario: las festividades de varios días salen una vez arriba, con el día en que terminan.

### Corregido
- El retrato de la ficha salía vacío (el aro dorado tapaba el icono de la clase); "Sanador" se cortaba en su botón.

## [0.8.0] — 2026-11-12 — Addon 0.4.0: personas (entrega 3)

### Añadido
- **Ficha de cada miembro** dentro del juego: rango, nivel, dónde está o cuándo entró, si usa el addon, lo que cuenta de sí (unas palabras, rol habitual, cuándo juega), sus personajes, sus próximas raids y su bandera. La tuya se edita desde la propia ficha.
- **Alters confirmados por ambos lados** sin escribir nada: cada personaje de la cuenta publica sus hermanos si el jugador lo permite; nadie puede declararse alter de otro.
- **La hermandad:** filtro de quién lleva 7, 14 o 30 días sin entrar, clic en un miembro para abrir su ficha y botón «Mi ficha».
- **En la interfaz del juego:** «Ver su ficha» en el menú del botón derecho de un compañero, una línea de BlazonGuild en su recuadro (alter de quién, si busca grupo, si usa el addon), botón BlazonGuild en la ventana de hermandad y comunidades, y Mayús + tecla de hermandad para abrirlo (solo si esa combinación está libre).

### Cambiado
- El clic para escribir a alguien desde el tablón o un grupo envía una frase fija (se ve antes de pulsar) en lugar de abrir el chat, que el addon contaminaría.

## [0.7.0] — 2026-11-12 — Addon 0.3.0: raids, buscar grupo y calendario en el juego (entrega 2)

### Añadido
- **Raids desde el juego:** el maestro y los oficiales crean, editan y cancelan raids (banda, día, hora, plazas por rol, nivel mínimo, nota); cada miembro se apunta con su rol (Voy, Quizá, No voy) y un comentario; composición por rol en vivo; reserva y grupos (con reparto automático); invitar a todos los confirmados (y pasar a banda); llamada discreta a los oficiales.
- **Buscar grupo:** bandera en el tablón ("busco grupo para X como sanador", caduca en una hora), grupos con plazas por rol, peticiones que el líder acepta (el juego invita) o rechaza, y susurro con un clic para escribirle a alguien.
- **Calendario:** las próximas dos semanas con las raids de BlazonGuild y los eventos del calendario del juego.
- **Registros compartidos** con permisos por colección y puesta al día de quien entra tarde a través del mensajero (que ahora prefiere a los organizadores).

### Corregido
- **Cada actualización de la lista de miembros borraba los datos compartidos guardados** (se reescribía la ficha entera de la hermandad). Lo detectó la prueba de red antes de llegar al juego.
- Desplegables que avisaban de un cambio al rellenar sus opciones.

## [0.6.0] — 2026-11-12 — Addon 0.2.0: la base de mensajes (entrega 1 de Olympus)

### Añadido
- **Mensajes entre addons** por el canal de la hermandad y por susurro: formato propio seguro para el chat, troceo de mensajes largos, cola con ritmo, espera durante el bloqueo del chat y reintentos (ADDON_COMPATIBILITY §5).
- **Privacidad:** nada sale del juego hasta que el jugador acepta una página en lenguaje llano; se puede retirar con `/bg privacidad` y los compañeros dejan de verle al momento.
- **Quién tiene el addon:** marca de BlazonGuild en La hermandad, recuento en el Resumen y en la cabecera, aviso cuando un compañero tiene una versión más nueva, y elección del mensajero de la hermandad.
- **Diagnóstico en el juego:** `/bg prueba` (el mensaje vuelve y los demás responden), `/bg estado`, `/bg rendimiento`, `/bg errores`, `/bg ayuda`.
- Ventana de diálogo propia, segura con mando.
- Pruebas: formato de mensajes (6) y red simulada de cuatro miembros (14), además de las 8 del cliente simulado.

### Corregido (vistas en las capturas del autor de la 0.1.0)
- "Conectados ahora" mostraba un solo nombre: ahora llena la columna.
- El pie de la barra lateral se salía del marco; el texto de búsqueda ocupaba dos líneas; "hace menos de 1 h" no cabía en Visto.
- Nombres de clase neutros en el Resumen (antes salía la forma del primer miembro, p. ej. "Sacerdotisa").

## [0.5.0] — 2026-11-12 — El addon primero

### Añadido
- **Decisión (ADR-016):** el addon es el producto principal, con paridad total con la web; vincular la cuenta en la web nunca es requisito.
- **Sonda del cliente** ejecutada en el juego real: 132 de 158 funciones, 22 de 22 plantillas, TGA y PNG propios, mensajes de addon por la hermandad (273 ms), calendario del juego, sin registro de combate para addons. Resultados en ADDON_COMPATIBILITY §1b.
- **Addon BlazonGuild 0.1.0:** ventana principal con la dirección Híbrida (arte original de la web exportado a PNG, fuentes y arte oficial del juego), las 10 secciones de la web, **Resumen** y **La hermandad** completos con datos en vivo del juego; el resto, con lo que harán y de dónde saldrán sus datos.
- Pruebas del addon sin el juego (sintaxis Lua 5.1 y cliente simulado) dentro de `npm test`; instalación de desarrollo verificada.

## [0.4.0] — 2026-11-12 — Fase 4: módulos de la hermandad

### Añadido
- **Administración** (`/g/…/admin`, solo liderazgo): miembros y roles, nombres de rango y rol por rango, permisos con sus suelos, auditoría y sincronizaciones. Nueva operación `GET /v1/guilds/{region}/{slug}/settings`.
- **Mazmorras**: directorio de 20 mazmorras clásicas con arte oficial y cuántos miembros están en nivel; **buscador de grupo** (crear, unirse por rol con un personaje propio, salir, cerrar; caducidad automática). Tablas `group_listings` y `group_members` (migración `0001_group_finder`) y 5 operaciones nuevas.
- **JcJ**: muertes con honor y rango por miembro y por clase.
- **JcE**: miembros por tramo de nivel, preparación por banda e historial de raids; el progreso jefe a jefe se muestra como "sin datos" hasta la Fase 5.
- **Calendario**: cuadrícula mensual en escritorio y agenda en móvil (hora peninsular).

### Cambiado
- Guilds grandes: el detalle de personajes se sincroniza por lotes de 80 (primero los nunca vistos, de mayor a menor nivel) y el planificador continúa hasta completarlos; buscar una guild ya no lanza cientos de peticiones de golpe.
- "Tus hermandades" pasa a "Tu hermandad", con el personaje que te vincula (un personaje solo puede estar en una guild).

### Corregido
- El mes del calendario empezaba en minúscula; la miga de pan de esa página ahora dice "Calendario", como el menú.
- Emblema de reserva (guilds sin emblema en Battle.net): en el tema claro la inicial salía blanca sobre blanco; ahora es un medallón oscuro con la inicial dorada en ambos temas.
- En móvil la miga de pan empezaba con un separador suelto.
- El directorio de mazmorras avisa de las que están en territorio de la facción contraria (p. ej. Sima Ígnea para la Alianza).

## [0.3.1] — 2026-11-12 — BlazonGuild

### Cambiado
- El producto pasa a llamarse **BlazonGuild** (antes FOREVER; ver ADR-014). Paquetes `@blazonguild/*`, logotipo "B" y textos de la web, la API y la documentación.
- Battle.net OAuth verificado de extremo a extremo con una cuenta real.
- Laboratorio visual `/lab/direcciones` con tres propuestas; el autor elige **A · Híbrida**.
- **Dirección visual v2 (Híbrida)** aplicada a exploración, resumen de guild (línea de mando con renders reales), roster, rankings (podio), raids (tarjetas con arte oficial de cada instancia), detalle de raid, armería (escenario cinematográfico, brillo de calidad, tooltip con filigrana, talentos y atributos en placas) y login/registro.
- API: `RosterMemberDTO.renderUrl` y `GuildOverviewDTO.lineup`.

## [0.3.0] — 2026-11-12 — Multi-guild, FOREVER Core y prototipos sobre datos reales

### Cambiado (importante)
- **La plataforma es multi-guild.** Se abandona la suposición de una única guild "Forever" (una guild real de terceros elegida por coincidencia de nombre).
- **Retirados los prototipos con datos inventados** (`blizzard-fixtures.ts`): BWL 8/8, 97,4 % de asistencia, miembros de nivel 60 y DPS ficticios presentados como reales. Copia del estado anterior en `.backup/`.
- Next.js 14.2.35 (avisos críticos) → **16.4.3** + React 19. Prisma/SQLite → **Drizzle + PostgreSQL/PGlite**. Express (sin código) → **Hono + OpenAPI**.

### Añadido
- `packages/types`: dominio verificado (9 clases con especializaciones y árboles, 10 razas incluidas las Cielonato, 19 huecos, calidades), RBAC, procedencia y DTOs.
- `packages/data-providers`: cliente Battle.net robusto (reintentos, semáforo, checksum, normalización de media).
- `packages/database`: 18 tablas, migración inicial y candado PGlite.
- `apps/api`: sincronización con diffs y feed de actividad, autenticación (scrypt, sesiones, Battle.net OAuth, tokens), RBAC por guild, auditoría, rate limiting, CSRF, 41 operaciones OpenAPI, planificador, CLIs y 25 tests.
- `apps/web`: diseño Blizzard Hybrid (tokens AA en oscuro y claro, Marcellus + IBM Plex Sans, heráldica real), shell adaptativa, exploración, resumen de guild, roster, armería, rankings, Raid Center y páginas honestas para las fases futuras.
- Herramientas: `tools/screenshots.mjs`, `tools/contrast.mjs`, `tools/dev.mjs`. Documentos: SECURITY, API_SPECIFICATION (generado), ASSET_INVENTORY y docs/specs/ART_DIRECTION_V1.

### Corregido (encontrado probando contra Battle.net real)
- Equipo con objetos duplicados, hechizos con `name: null` y líneas de tooltip sin `type` (ahora con validación objeto a objeto).
- Columnas de talentos numeradas globalmente; iconos y emblemas con 403 en `/forever-xx/`; orden por defecto del roster.

## [Phase 1 Technical Closure] - 2026-11-09

### Added
- Monorepo workspace architecture initialized with `packages/types`, `packages/data-providers`, and `packages/database`.
- Shared TypeScript domain contracts (`ruleset`, `character`, `guild`, `provenance`).
- Defensive Zod validation schemas using `.passthrough()` in `packages/data-providers/src/schemas.ts`.
- Independent integration testing probe in `tools/validator/probe-blizzard-api.mjs`.
- Successful live Battle.net API integration for all 10 endpoints (OAuth, Ruleset Index, Ruleset Detail, Character Profile, Equipment, Stats, Talents, Media, Guild Roster, Guild Activity).
- Character Media verified with active Blizzard CDN URLs (`avatar`, `main-raw`, `main-sd-raw`).
- Canonical database architecture in `packages/database` covering Users, GuildMembers, Characters, Equipment, Talents, Rulesets, Raids, Encounters, Analytics, and Audit Logs.

### Verified & Resolved
- **Ruleset ID Harmonization:** Verified canonical Blizzard API Ruleset ID `1` ("JcJ") vs local client directory `93` (mapped in Companion).
- **HTTP Status Clarification:** Confirmed all live API success responses return standard HTTP `200 OK`.
- **Character / Guild Decoupling:** Reconciled Alliance test character `el-peregrino` (guild `c-a-ñ-a-d-a`) and Horde guild `forever` as independent live validation fixtures.
- **Experimental Endpoints Identified:** Documented empty activity feed on `/guild/activity` and resolved to track guild activity internally.
