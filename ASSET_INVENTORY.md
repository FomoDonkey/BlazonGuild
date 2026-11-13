# BlazonGuild — Inventario de assets y procedencia

> Requisito §13 de `docs/specs/ART_DIRECTION_V1.md`: solo assets originales, con licencia o autorizados, y documentados.

| Asset | Origen | Licencia / permiso | Cómo se usa | Redistribución |
| :--- | :--- | :--- | :--- | :--- |
| Renders 3D y avatares de personajes | Battle.net API (`character-media`) → `render.worldofwarcraft.com` | Contenido servido por la API oficial bajo los términos de la Blizzard Developer API | Enlace directo a la CDN; el optimizador de Next lo convierte a AVIF/WebP bajo demanda | **No** se copian al repositorio |
| Arte del addon (`packages/addon/BlazonGuild/Media/*.png`: monograma, filigrana, separador, medallón, rombo, flecha, texturas de metal y grano) | Original de BlazonGuild: los mismos SVG y filtros de la web, exportados con `tools/addon-art.mjs` | Propio | Texturas del addon | Sí, con el addon |
| Arte oficial dentro del juego (pantallas de carga, iconos, atlas, retratos de clase, fuentes Friz Quadrata y Arial Narrow) | Ficheros del propio cliente de WoW: Forever, comprobados con la sonda | Del cliente del jugador; el addon solo los referencia por ruta | Portadas, iconos y tipografía del addon | **No** se copian ni se distribuyen |
| Iconos de objetos, talentos, clases y especializaciones | Battle.net API (`media/item`, `media/spell`, `media/playable-class`, `media/playable-specialization`) | Ídem | Enlace directo (`/eu/icons/…`, ver ADR-012) | No se copian |
| Emblemas y bordes de guild | Battle.net API (`media/guild-crest`) | Ídem | Proxy same-origin `/v1/media` con caché en disco (`MEDIA_CACHE_DIR`, fuera del repo), teñido con CSS `mask-image` | La caché es local y regenerable; no se versiona |
| Ilustraciones de bandas y mazmorras (600×300) | Battle.net API (`media/journal-instance`) → `render.worldofwarcraft.com/eu/zones/{instancia}-small.jpg` | Ídem | Fondo de las portadas cinematográficas, tarjetas de raid y login (desenfocado y etalonado) | No se copian |
| Texturas de piedra, metal cepillado y pergamino; filigranas; brasas; niebla | **Original BlazonGuild** (SVG/`feTurbulence`, canvas y CSS en `components/art/`) | Propio | Superficies, marcos y atmósfera | Sí |
| Nombres de objetos, talentos, logros y profesiones | Battle.net API (es_ES; algunos llegan en inglés tal cual) | Ídem | Texto | — |
| Medallón heráldico (marco, anillos, sombreado) | **Original BlazonGuild** (SVG en `GuildCrest.tsx`) | Propio | — | Sí |
| Wordmark y escudo "B" | **Original BlazonGuild** (SVG en `Shell.tsx`) | Propio | — | Sí |
| Textura de grano | **Original** (SVG `feTurbulence` en línea) | Propio | — | Sí |
| Marcellus | Google Fonts | SIL Open Font License 1.1 | `next/font` (autoalojada en el build) | Permitida |
| IBM Plex Sans | Google Fonts | SIL Open Font License 1.1 | `next/font` | Permitida |
| Iconos de interfaz | lucide-react | ISC | Componentes React | Permitida |
| Catálogo de instancias de banda (nombres) | Conocimiento del juego clásico | Nombres propios de Blizzard, usados de forma descriptiva | Selector de instancia al crear raids | — |

**Normas:** no se incluyen en el repositorio ni en el bundle logotipos de Blizzard ni de World of Warcraft, ni artwork de juego descargado. Cualquier ilustración nueva debe ser original, tener licencia o proceder de la API oficial, y registrarse aquí antes de usarse. Antes de un lanzamiento público hay que revisar los términos vigentes de la Blizzard Developer API: atribución, prohibición de sugerir afiliación oficial y límites de uso.
