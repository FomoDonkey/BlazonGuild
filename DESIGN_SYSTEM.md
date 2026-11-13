# BlazonGuild — Design System (Blizzard Hybrid)

> Especificación obligatoria: `docs/specs/ART_DIRECTION_V1.md`. Este documento explica cómo está implementada.
> Código: `apps/web/src/app/globals.css` (tokens), `apps/web/tailwind.config.ts` (mapeo), `apps/web/src/components/**`.

## 1. Concepto: "la mesa de guerra"
El elemento memorable es la **heráldica real de cada guild**: el emblema de Battle.net, teñido con sus colores sobre un medallón original, preside la página y tiñe sutilmente su cabecera. Así cada guild se ve como su propio estandarte. En la Armería, el protagonista es el **render 3D real** del personaje, iluminado con el color de su clase. Todo lo demás es sobrio: superficies obsidiana, líneas finas y el dorado azerita reservado para acciones primarias, navegación activa y cifras clave.

Evitado a propósito: tarjetas idénticas para todo, bordes dorados por todas partes, glassmorphism, degradados decorativos, etiquetas en MAYÚSCULAS, tipografía monoespaciada para datos y animaciones de entrada en cada sección.

## 1b. Dirección visual v2: Híbrida (elegida por el autor el 2026-11-12)
Comparada en `/lab/direcciones` frente a "interfaz del juego" y "cinemática total".
- **Portadas cinematográficas** (`CinematicHero`): ilustración oficial de la instancia (Horda → Núcleo de Magma, Alianza → Naxxramas; cada raid usa la de su instancia), etalonado, viñeta, niebla CSS a la deriva, brasas o motas en canvas y parallax con el ratón. Siempre con la paleta oscura (`.cinematic`), también en tema claro.
- **Línea de mando** (`Lineup`): renders 3D reales del GM y los oficiales escalonados sobre el escenario, con brillo del color de clase.
- **Placas de metal** (`.plate`, `.surface-metal`) con filigrana original (`FiligreeCorner`, `OrnateFrame`, `RuneDivider`) para cifras, tooltips, talentos y tarjetas; filetes dorados (`.rule-gold`) y titulares en oro metálico (`.text-gold`).
- **Datos densos limpios:** tablas, roster y rankings siguen sobrios y legibles.
- **Rendimiento:** canvas en pausa fuera de pantalla, nada animado con `prefers-reduced-motion`, parallax desactivado en táctil.

## 2. Color (tokens semánticos, RGB para soportar alfa)

| Token | Oscuro | Claro | Uso |
| :--- | :--- | :--- | :--- |
| `canvas` | `#0B0E13` | `#E9ECF1` | Fondo de página (claro = pergamino frío, no crema) |
| `sunken` | `#10141C` Obsidian | `#DEE2E9` | Barras laterales, pistas, campos |
| `surface` | `#151B24` | `#FFFFFF` | Paneles |
| `elevated` | `#222C38` | `#F5F6F9` | Activo, chips, popovers |
| `line` / `line-strong` | `#242E3C` / `#687589` | `#D3D8E1` / `#808A99` | Divisores / bordes de campos (≥ 3:1) |
| `text`, `text-2`, `text-3` | Ivory `#E7EAF0`, `#AAB3C1`, `#8A94A3` | `#10141C`, `#3D4654`, `#56606F` | Jerarquía de texto (todas ≥ 4,5:1) |
| `accent` | Azerite `#D0B078` | `#7A5E28` | Marca, acción primaria, activo |
| `success / warning / danger / info` | `#56B98A / #E3AD54 / #E47880 / #6DA8E8` | oscurecidos | Estados (siempre con icono y texto) |
| `horde / alliance` | `#EC766A / #6896E6` | `#A4261E / #2254AA` | Facción |
| `--class-{id}` | colores canónicos del juego | variantes oscuras | Identidad de clase (icono, nombre, barra) |
| `--q-{CALIDAD}` | colores de rareza del juego | variantes oscuras | Nombre y marco de objetos |

**Validación:** `node tools/contrast.mjs` comprueba 134 pares (texto, estados, facción, clase y calidad sobre cada superficie, en ambos temas) contra WCAG 2.2 AA. Estado actual: todos cumplen (tras corregir Horda, Chamán y los bordes de campo, que no llegaban).

## 3. Tipografía
- **Marcellus** (titulares, nombres de guild y personaje, secciones): serif de remates abiertos en la tradición de Friz Quadrata, la letra de la interfaz de WoW. Nunca en textos largos ni en cifras.
- **IBM Plex Sans** (interfaz, cuerpo, tablas): cifras tabulares (`.t-num`) y `.t-figure` para números destacados. Marcellus dibuja el "1" como una "I" romana; por eso todas las cifras van en Plex.
- Escala: 0,6875 / 0,75 / 0,875 / 0,9375 (cuerpo) / 1,125 / 1,25 / 1,5 / 1,875–2,25 / 3–3,75 rem. Las líneas de texto largo se limitan a 68 caracteres (`max-w-prose`).

## 4. Navegación
- **Escritorio (≥ 1024 px):** sidebar persistente de 264 px, contraíble a raíl de 72 px (preferencia guardada). Arriba, el emblema y el nombre de la guild actual; luego las secciones (las de fases futuras indican su fase) y "Tus hermandades".
- **Tablet (768–1023 px):** raíl de iconos con título emergente.
- **Móvil (< 768 px):** barra superior compacta y barra inferior con Resumen, Roster, Raids, Rankings y "Más" (hoja inferior con todo).
- **Global:** breadcrumbs, búsqueda ⌘K / Ctrl K / `/` (hermandades y personajes, con importación desde Battle.net), notificaciones y menú de usuario con personaje principal y selector de tema.

## 5. Densidad adaptativa (implementada)
| Módulo | Densidad | Tratamiento |
| :--- | :--- | :--- |
| Resumen de guild | Editorial | Cabecera heráldica, cifras clave en banda, feed por días, composición, niveles |
| La hermandad | Equilibrada → densa | Tabla ordenable con columnas configurables; directorio de retratos; en móvil, lista legible y filtros plegables |
| Armería | Inmersiva | Render centrado con los 19 huecos alrededor y tooltip fiel al juego (hoja inferior en táctil); atributos en banda multicolumna; árboles de talentos clásicos |
| Rankings | Alta densidad | Tabla con barra relativa en color de clase y metodología a la vista |
| Raids | Táctica | 8 grupos × 5, banquillo, rechazados, análisis de roles, clases y avisos |

## 6. Componentes y estados
`GuildCrest`, `ClassIcon`, `ItemIcon` (con el icono de interrogación del juego como respaldo), `CharacterLink`, `RoleIcon`, `FactionMark`, `TalentSplit`, `Coins`, `ProvenanceNote`, `EmptyState`, `ErrorPanel`, `SectionHeading`, `Meter`, `RankedBars`, `Histogram`, `.btn-primary/secondary/ghost`, `.field`.
Cada pantalla tiene sus estados de carga (`loading.tsx` con esqueletos), vacío (explica qué falta y qué hacer), error (`error.tsx` y `ErrorPanel` con el mensaje de la API) y *foco visible* (anillo dorado de 2 px).

## 7. Gráficas
Siguen la guía de *dataviz*: barras finas con extremo redondeado de 4 px y separación de 2 px, una sola serie sin leyenda, identidad nunca solo por color (icono y nombre junto a cada barra), valores en tinta de texto, tooltip al pasar el ratón o enfocar, y tabla equivalente para lectores de pantalla.

## 8. Accesibilidad (WCAG 2.2 AA, objetivo)
Enlace "Saltar al contenido", HTML semántico (`nav`, `main`, `aside`, `section` con `aria-labelledby`), `aria-current` en navegación, `aria-sort` en cabeceras, combobox accesible en la búsqueda, `dialog` nativo con foco atrapado, objetivos táctiles de ≥ 40 px, `prefers-reduced-motion` y `prefers-reduced-transparency` respetados, y planificador de raid usable sin arrastrar (seleccionar y colocar con teclado o toque).

## 9. QA visual
`node tools/screenshots.mjs <dir> /ruta … --themes=dark,light --widths=1440,390 [--full]` (con `LOGIN=email:pass` para pantallas privadas) captura con Chromium real y señala el scroll horizontal y los errores de consola. Se ha usado en cada iteración; en Git Bash hace falta `MSYS_NO_PATHCONV=1`.
