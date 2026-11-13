# FOREVER — OFFICIAL ART DIRECTION & DESIGN SYSTEM — DESIGN SPECIFICATION V1.0

> Especificación aportada por el autor el 2026-11-12. **Obligatoria**: tiene prioridad sobre cualquier decisión de diseño genérica.
> Cómo se aplica en el código: ver `DESIGN_SYSTEM.md`.
> **Nota (2026-11-12):** el producto se renombró a **BlazonGuild** (ADR-014). El texto de abajo se conserva tal como lo escribió el autor; donde dice "FOREVER" hay que leer BlazonGuild.

Approved direction: **BLIZZARD HYBRID + ADAPTIVE INFORMATION DENSITY**

Esta especificación establece la dirección artística, los criterios de UX/UI y los estándares visuales obligatorios de todo el ecosistema FOREVER.

## 1. Product vision
FOREVER debe sentirse como un producto premium del universo World of Warcraft, con la calidad de dirección artística, diseño de producto y ejecución técnica que se espera de un equipo especializado de Blizzard Entertainment.

La dirección aprobada es BLIZZARD HYBRID. Combina: cinematic fantasy art direction, premium digital product design, professional esports analytics, MMORPG interface design, editorial visual composition y adaptive information density.

No construir una web convencional de gaming, una plantilla SaaS ni un dashboard administrativo genérico. Construir una identidad de producto original y reconocible.

## 2. Visual identity
Desarrollar un lenguaje visual inspirado en la riqueza artística de Azeroth. Utilizar: artwork de calidad cinematográfica, composiciones editoriales, tratamiento visual de personajes, iconografía auténtica de World of Warcraft, texturas discretas, profundidad visual, iluminación controlada, tipografía refinada, microinteracciones y transiciones elegantes.

La espectacularidad debe proceder de la composición, las ilustraciones, la tipografía y el detalle, no de acumular efectos.

## 3. Color system
Crear tokens semánticos para: primary background, secondary background, elevated surfaces, primary text, secondary text, accent, borders, success, warning, error, information, class colors e item rarity colors. Utilizar la paleta propuesta como punto de partida, validando todos los contrastes. Implementar temas dark y light.

## 4. Typography
Establecer una jerarquía tipográfica completa. Combinar tipografía editorial para titulares especiales con tipografía moderna para navegación, contenido y estadísticas. Los números y las tablas deben utilizar cifras tabulares cuando corresponda. No utilizar tipografías decorativas para textos largos.

## 5. Navigation
Crear navegación global consistente.
- Desktop: sidebar persistente y contraíble, global search, notifications, user menu, breadcrumbs, contextual navigation.
- Mobile: navegación adaptada, acciones prioritarias accesibles, menús compactos, filtros adaptados, tablas transformadas en formatos legibles.

## 6. Adaptive information density
Cada módulo tendrá su propia densidad: Home cinematic and editorial; Guild balanced; Armory immersive inspection; Rankings high-density tables; Analytics advanced data visualization; Raids operational planning; Dungeons exploration and group management; PvP competitive statistics; PvE progression and encounter analysis; Administration operational efficiency. No utilizar una plantilla única para todas las pantallas.

## 7. Screen-specific design
- HOME: cinematic guild identity, meaningful overview, recent activity, progression and events.
- GUILD: professional roster, class identities, hierarchy, membership and filtering.
- ARMORY: character-centered inspection, equipment slots, item details, talents, attributes and history.
- RANKINGS: advanced sortable tables, class filters, performance comparisons and historical rankings.
- ANALYTICS: professional charts, time filters, encounter breakdowns, performance analysis and export.
- RAIDS: calendar, registrations, group composition, assignments, attendance and historical results.
- DUNGEONS: dungeon artwork, bosses, loot, group finder and run history.
- PVP: competitive results, player comparisons and available battlefield statistics.
- PVE: raid progression, bosses, encounters and guild history.
- MEMBER PROFILE: player identity, characters, participation, performance and achievements.
- EVENTS: calendar, agenda, availability and registration.
- ADMINISTRATION: efficient forms, tables, permissions, audit logs and system monitoring.

## 8. Design system
Implement reusable components with complete interaction states. Every component must support: default, hover, focus, active, disabled, loading, error, empty. Maintain consistency without forcing identical layouts across unrelated modules.

## 9. Accessibility and usability
Target WCAG 2.2 AA. Include: keyboard navigation, visible focus, semantic HTML, screen reader compatibility, sufficient contrast, accessible form controls, reduced motion support, responsive typography, touch-friendly controls, meaningful error messages.

## 10. Visual performance
Use visual effects selectively. Optimize artwork, responsive images, loading and animations. Avoid layout shifts, unnecessary rendering and expensive effects. The interface must remain fast and comfortable.

## 11. Addon visual identity
The WoW addon must share the FOREVER brand identity while respecting the native interface conventions and actual capabilities of the target client. Do not reproduce the web interface literally.

## 12. Quality assurance
Every major screen must undergo: art direction review, UX review, UI review, accessibility review, responsive review, performance review. Generate real screenshots and inspect them. Iterate until the interface meets the established quality standard.

## 13. Copyright and asset governance
Use only assets that are original, licensed, permitted or otherwise authorized for the intended use. Do not assume Blizzard artwork or game assets can be redistributed freely through a public website. Create an asset inventory and document asset provenance.

## 14. Final design principle
FOREVER must combine the emotional impact of World of Warcraft with the usability and precision of a world-class professional product. Every screen must feel intentionally designed. Every interaction must feel considered. Every visual element must have a purpose. The result must be extraordinary in appearance, intuitive in use, accessible, performant and technically coherent.

**APPROVED DESIGN DIRECTION: BLIZZARD HYBRID + ADAPTIVE INFORMATION DENSITY.** Do not downgrade this specification to a generic gaming dashboard.
