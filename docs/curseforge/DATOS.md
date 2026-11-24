# BlazonGuild en CurseForge — qué pegar en cada sitio

## Publicado (2026-11-14)

- **Proyecto:** id `1803645`, https://www.curseforge.com/wow/addons/blazonguild (se ve como «preview» hasta que lo apruebe un moderador de CurseForge).
- **Fichero:** «BlazonGuild 0.29.2» (aprobado, 2026-11-14), «BlazonGuild 0.29.3» (aprobado) y «BlazonGuild 0.29.4» (subido el 2026-11-24, «Under Review»), WoW Forever 1.60.1, Release, se publica solo al aprobarse. Para adjuntar el zip: interceptar el `click()` del campo de fichero que crea «Choose File» y usar la subida de ficheros del navegador sobre ese campo.
- **Ajustes:** licencia MIT (desde el 2026-11-14; se creó con All Rights Reserved); enlace al código en «Source»; categorías Guild + Chat & Communication, PvP, Map & Minimap, Professions (CurseForge deja 4); comentarios activados (la descripción pide los fallos ahí); distribución a otras apps permitida; público.
- **Capturas:** las del autor del juego, **sin recortar**. En la descripción van a 840 px de ancho (lo máximo que deja CurseForge, reducidas, nunca recortadas); en la galería, 18 a tamaño original. Copias en `packages/addon/dist/shots/` (no se suben a git). Faltan Raids y JcE.
- **Descripción:** `description.en.md` con `{{shot:NN:texto}}` → `description.curseforge.html`. Primero qué es y una visita por cada parte con su captura; las novedades, al final.

## Resumen (Summary, una línea)

En inglés (210 caracteres), el que recomiendo, porque CurseForge lo leen jugadores de todo el mundo:

```
Your guild's home inside the game: raids with drag-and-drop groups, chat with moderation, a duel Arena that records itself, map and minimap, crafting orders, treasury, recruitment, rankings and guild alliances.
```

En español (202 caracteres):

```
La casa de tu hermandad dentro del juego: raids con grupos arrastrando, chat con moderación, Arena de duelos que se apunta sola, mapa y minimapa, encargos, tesorería, reclutamiento, rankings y alianzas.
```

## Descripción

- **En inglés:** `description.en.md`. Si el editor de CurseForge no acepta Markdown, usa `description.en.html` en el modo de código fuente.
- **En español:** `descripcion.es.md`. También existe `descripcion.es.html`.
- **Para las dos:** pega primero la inglesa y, debajo, una línea «🇪🇸 Descripción en español» seguida de la española.

## Categorías

- **Principal:** Guild.
- **Adicionales, en este orden:**
  1. Chat & Communication
  2. PvP
  3. Map & Minimap
  4. Professions
  5. Minigames

Si CurseForge deja menos, quédate con las primeras.

## Licencia, versión del juego y fichero

- **Licencia:** MIT (el autor, 2026-11-14; antes All Rights Reserved). Código en https://github.com/FomoDonkey/BlazonGuild. Dentro del addon van `LICENSE.txt` y `THIRD_PARTY_NOTICES.md` (lo adaptado de Olympus sigue con su MIT).
- **Versión del juego:** WoW Forever, **1.60.1** (así lo etiqueta CurseForge; es la de Olympus). Solo Forever: BlazonGuild está hecho para cómo Forever da los nombres.
- **Fichero:** `packages/addon/dist/BlazonGuild-<versión>.zip` (la carpeta `BlazonGuild/` tal cual; comprobado que es idéntico a la carpeta). Desde la 0.29.4 se hace con la carpeta del repositorio público (sin nombres reales en comentarios ni ejemplos).

## Capturas reales (con el modo capturas)

Se hacen en el juego, con la hermandad de ejemplo: nombres inventados y todas las pantallas llenas.

1. **En inglés** (CurseForge lo lee todo el mundo): escribe `/bg idioma en` y luego `/reload`.
2. **Modo capturas:** `/bg capturas` (o Administración → «Screenshot mode»).
3. **Ventana grande y centrada:** `/bg escala 1.2` si cabe en tu pantalla.
4. **Una captura por pantalla** con la tecla **Impr Pant**. El juego las guarda en `_forever_\Screenshots`.
5. **Al terminar:** `/bg capturas` (vuelves a tu hermandad) y, si quieres el addon en español otra vez, `/bg idioma es` y `/reload`.
6. **Avísame:** yo recorto cada captura a la ventana del addon (así no sale tu chat ni tu nombre), les pongo marco y título, y las subo.

Lista (en este orden):

1. **Overview** (Resumen).
2. **Guild** (La hermandad), con la ficha de alguien abierta (pulsa a Seren Duskwhisper).
3. **Raids** → Onyxia's Lair; y luego **Groups** (los grupos de la banda).
4. **Chat** → la sala «Friday raid».
5. **Board** (Tablón): anuncios y la encuesta.
6. **Arena** → la clasificación.
7. **Arena** → Tournaments: el cuadro de la «Friday Cup».
8. **Arena** → Tavern → Bones: «Practice» y pulsa «Roll» una vez (los dados en la mesa).
9. **Map** → «On the map»: los compañeros alrededor de ti y en el minimapa.
10. **Wanted** («Se busca»).
11. **Rankings** → Honours; y → Guilds (clasificación de hermandades).
12. **Crafting** → Orders (encargos).
13. **Treasury** → Summary; y → Dues (cuotas).
14. **Alliance** → Guilds; y **War room** (Sala de guerra).

## Antes de publicar

- Pasa `/bg autoprueba` en el juego, fuera de una mazmorra y con un objetivo (haz antes un `/roll`: así dice cómo escribe tu juego los nombres).
- Si algo sale «No», quita de la descripción la línea que dependa de ello:
  - «ENCOUNTER_END» → los jefes que se apuntan solos (JcE).
  - «Radio del minimapa» o «Coordenadas del mundo» → los puntos del minimapa y la flecha «Seguir».
  - «Vida de tu objetivo» → la vida en directo de «Cara a cara».
  - «Canal de la alianza» → el canal oculto del chat de la alianza.
