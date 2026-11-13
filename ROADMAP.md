# BlazonGuild — Hoja de ruta

| Fase | Contenido | Estado |
| :--- | :--- | :--- |
| 0 | Descubrimiento: cliente, API Forever, viabilidad | ✅ |
| 1 | Arquitectura y contratos | ✅ (revisada 2026-11-12) |
| 2 | Dirección de arte y prototipos de alta fidelidad sobre datos reales | ✅ 2026-11-12 |
| 3 | BlazonGuild Core: BD, sincronización, autenticación, RBAC, API, ingesta | ✅ 2026-11-12 (Battle.net OAuth verificado con cuenta real) |
| 4 | Web completa: administración, mazmorras y buscador de grupo, JcJ, JcE, eventos y calendario, perfil de miembro y privacidad, comparador, gráficas de historial | 🟡 en curso (administración, mazmorras y buscador, JcJ, JcE y calendario hechos) |
| 6 | **Addon (adelantada, ADR-016):** ventana propia con la dirección Híbrida; raids, grupos, calendario, gestión de miembros e inscripciones desde el juego; sincronización en tiempo real por la hermandad | 🟡 siguiente: sonda del cliente lista |
| 7 | **Puente (adelantada):** app compañera que sube los `SavedVariables` y baja las novedades de la web; la web refleja lo hecho en el juego | ⏳ |
| 5 | Motor de analítica: parser de `WoWCombatLog.txt`, encuentros, DPS/HPS/supervivencia, asistencia real, fórmulas documentadas | ⏳ |
| 8 | QA y hardening: E2E completo, accesibilidad auditada, regresión visual, rendimiento, seguridad | ⏳ |
| 9 | Producción: LXC en Proxmox + Cloudflare Tunnel con nombre, PostgreSQL con copias verificadas, monitorización | ⏳ |

## Decisiones que necesitan al autor
1. ✅ Redirect URI de desarrollo registrada (2026-11-12). En producción habrá que añadir la del dominio.
2. **Git:** primer commit y repositorio privado `FomoDonkey/GuildCommand`.
3. **Producción:** dominio y confirmación del despliegue en un LXC propio.
4. ✅ **Nombre:** BlazonGuild (2026-11-12). Pendiente comprobar dominio, nombre en CurseForge/Wago y marca antes de publicar.
5. ✅ **Dirección visual v2:** A · Híbrida (2026-11-12), aplicada a todas las pantallas.
