/**
 * Generates API_SPECIFICATION.md from the live OpenAPI document (single source of truth).
 * Usage (from apps/api): npx tsx src/cli/gen-api-spec.ts ../../API_SPECIFICATION.md
 */
import fs from 'node:fs';
import { createApp } from '../app';
import { createDeps } from '../deps';
import { loadEnv } from '../env';
import { silentLogger } from '../lib/logger';

const out = process.argv[2] ?? 'API_SPECIFICATION.md';
const env = loadEnv({ NODE_ENV: 'test', BLIZZARD_CLIENT_ID: 'doc', BLIZZARD_CLIENT_SECRET: 'doc', DATABASE_URL: 'pglite:memory', DISABLE_SCHEDULER: 'true' });
const { deps, close } = await createDeps(env, { log: silentLogger });
const res = await createApp(deps).request('/v1/openapi.json');
const spec = (await res.json()) as { info: { title: string; version: string; description: string }; paths: Record<string, Record<string, { tags?: string[]; summary?: string; parameters?: { name: string; in: string; required?: boolean }[]; requestBody?: unknown }>> };
await close();

const byTag = new Map<string, string[]>();
for (const [path, ops] of Object.entries(spec.paths)) {
  for (const [method, op] of Object.entries(ops)) {
    const tag = op.tags?.[0] ?? 'Otros';
    const params = (op.parameters ?? []).filter((p) => p.in === 'query').map((p) => `\`${p.name}\``).join(', ');
    const row = `| \`${method.toUpperCase()}\` | \`${path}\` | ${op.summary ?? ''}${params ? ` — query: ${params}` : ''}${op.requestBody ? ' — cuerpo JSON' : ''} |`;
    byTag.set(tag, [...(byTag.get(tag) ?? []), row]);
  }
}
let md = `# ${spec.info.title} — especificación v${spec.info.version}\n\n`;
md += `> Generado automáticamente desde el documento OpenAPI 3.1 (\`GET /v1/openapi.json\`, referencia interactiva en \`/v1/docs\`).\n> No editar a mano: \`npx tsx src/cli/gen-api-spec.ts ../../API_SPECIFICATION.md\` desde \`apps/api\`.\n\n`;
md += `${spec.info.description}\n\n`;
md += `## Convenciones\n\n- **Versionado:** prefijo \`/v1\`. Cambios incompatibles irán en \`/v2\`.\n- **Autenticación:** cookie de sesión \`httpOnly\` (\`forever_session\`, \`__Host-forever_session\` en producción) o \`Authorization: Bearer fvr_…\` (tokens personales, solo ingesta).\n- **CSRF:** las peticiones que modifican datos deben ser \`application/json\`; si el navegador envía \`Origin\`, debe ser el de la web.\n- **Errores:** \`{ "error": { "code": "…", "message": "…", "details"?: … } }\` con el código HTTP adecuado (400 validación, 401, 403, 404, 409, 413, 415, 429, 502).\n- **Paginación:** \`page\` y \`pageSize\` → \`{ items, total, page, pageSize }\`.\n- **Límites:** 600 peticiones/min por IP; 10/min en login y registro; importación de hermandades nuevas 20/hora; consultas de personajes 60/hora por usuario o IP.\n- **Procedencia:** las respuestas con datos de juego incluyen \`provenance\` (fuente, estado, confianza, fecha de captura).\n- **Contratos TypeScript:** \`packages/types/src/dto.ts\`.\n\n`;
for (const [tag, rows] of [...byTag.entries()].sort()) {
  md += `## ${tag}\n\n| Método | Ruta | Descripción |\n| :--- | :--- | :--- |\n${rows.join('\n')}\n\n`;
}
fs.writeFileSync(out, md);
console.log(`Escrito ${out}: ${[...byTag.values()].flat().length} operaciones`);
