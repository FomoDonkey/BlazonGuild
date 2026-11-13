# BlazonGuild — Matriz de viabilidad (actualizada 2026-11-12)

Categorías: **A** cliente (addon) · **B** servidor autorizado (Battle.net) · **C** registros de combate · **D** aportación de miembros · **E** no obtenible o no fiable.

| Funcionalidad | Cat. | Fuente | Estado en BlazonGuild |
| :--- | :---: | :--- | :--- |
| Cualquier guild y roster de cualquier región | B | `guild` + `roster` | ✅ Implementado (importación al visitarla) |
| Nombres de rango | D | Ajustes de la guild (la API solo da índices) | ✅ API e interfaz de administración |
| Identidad, nivel, raza, clase, facción | B | perfil | ✅ |
| Equipo de 19 huecos con tooltip completo | B | equipment | ✅ |
| Atributos (modelo clásico) | B | statistics | ✅ (se descartan los de retail) |
| Árboles de talentos con puntos | B | specializations + talent-tree | ✅ |
| Renders, avatares, iconos y emblemas | B | media | ✅ (con normalización de rutas) |
| Profesiones | B | professions | ✅ |
| JcJ: muertes con honor y rango | B | pvp-summary | ✅ datos y página JcJ |
| Logros recientes | B | achievements | ✅ (feed y armería) |
| Actividad de la guild | B (derivado) | diffs de sincronización | ✅ |
| Historial del personaje | B (derivado) | snapshots por checksum | ✅ datos · gráficas en Fase 4/5 |
| Comparar personajes | B | snapshots | ⏳ Fase 4 |
| Rankings de nivel, iLvl, MCH, profesión y logros | B | columnas sincronizadas | ✅ |
| Progreso de banda por jefe | B/C | encounters (vacío hoy) + registros de combate | 🟡 preparación por banda en JcE · jefe a jefe en Fase 5 |
| DPS, HPS, daño recibido, supervivencia | C | WoWCombatLog.txt | ⏳ Fase 5 (mostrado como "no disponible") |
| Asistencia real | A/C | addon o registros de combate | ⏳ Fase 5–7 (las inscripciones no prueban asistencia) |
| Raids: crear, inscribirse, composición | D | web | ✅ |
| Buscador de grupo de mazmorras | D | web | ✅ |
| Eventos y calendario | D | web | ✅ calendario de raids |
| Propiedad verificada de personajes | B | OAuth `/profile/user/wow` | ✅ implementado y verificado con una cuenta real |
| Subida desde el addon | A | SavedVariables → app compañera → `/v1/ingest/addon` | ✅ ingesta y deduplicación · procesado en Fase 6–7 |
| HTTP directo desde el addon | E | — | ❌ El sandbox de WoW lo prohíbe; se resuelve con la app compañera |
| Ficha de objeto independiente (`/item/{id}`) | E | — | ❌ 404 en Forever; el tooltip sale del equipo |
| Percentiles globales | E | — | ❌ Sin muestras fuera de cada guild; no se calculan |
