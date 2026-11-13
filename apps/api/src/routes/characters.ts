import { createRoute, z } from '@hono/zod-openapi';
import { isRegion, type Region } from '@blazonguild/types';
import { requireUser } from '../auth/access';
import { audit } from '../lib/audit';
import { tooMany } from '../lib/errors';
import { json, router } from '../lib/http';
import { RateLimiter } from '../lib/rate-limit';
import { buildArmory, getOrSyncCharacter } from '../services/armory';

const Any = z.any();
const Params = z.object({ region: z.string().refine(isRegion, 'Región no válida'), slug: z.string().min(3).max(64) });

export function characterRoutes() {
  const app = router();
  const lookupLimiter = new RateLimiter(60, 3_600_000);

  app.openapi(
    createRoute({
      method: 'get', path: '/v1/characters/{region}/{slug}', tags: ['Armory'], summary: 'Armería: identidad, equipo (19 huecos), estadísticas, talentos, profesiones, JcJ e historial',
      request: { params: Params }, responses: { 200: json('CharacterArmoryDTO', Any), 404: json('No existe', Any) },
    }),
    async (c) => {
      const p = c.req.valid('param');
      if (!lookupLimiter.take(`char:${c.var.user?.id ?? c.var.clientIp}`).ok) throw tooMany();
      const row = await getOrSyncCharacter(c.var.deps, p.region as Region, decodeURIComponent(p.slug), c.var.user?.id ?? null);
      return c.json(await buildArmory(c.var.deps, row, c.var.user?.id ?? null), 200);
    },
  );

  app.openapi(
    createRoute({ method: 'post', path: '/v1/characters/{region}/{slug}/sync', tags: ['Armory'], summary: 'Actualizar el personaje desde Battle.net', request: { params: Params }, responses: { 200: json('CharacterArmoryDTO', Any) } }),
    async (c) => {
      const user = requireUser(c);
      const p = c.req.valid('param');
      const slug = decodeURIComponent(p.slug).toLowerCase();
      const row = await c.var.deps.sync.syncCharacter(p.region as Region, slug, { trigger: 'MANUAL', userId: user.id });
      const fresh = row ?? (await getOrSyncCharacter(c.var.deps, p.region as Region, slug, user.id));
      await audit(c.var.deps.db, { actorUserId: user.id, action: 'CHARACTER_SYNC', entity: 'character', entityId: fresh.id, ip: c.var.clientIp });
      return c.json(await buildArmory(c.var.deps, fresh, user.id), 200);
    },
  );

  return app;
}
