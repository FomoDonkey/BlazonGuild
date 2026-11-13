import { createRoute, z } from '@hono/zod-openapi';
import type { Context } from 'hono';
import { RAID_INSTANCES } from '@blazonguild/types';
import type { AppEnv } from '../context';
import { guildAccess, requireUser } from '../auth/access';
import { forbidden } from '../lib/errors';
import { json, router } from '../lib/http';
import { applyComposition, getRaid, raidDetail, updateRaid, upsertSignup, withdrawSignup } from '../services/raids';

const Any = z.any();
const RaidParams = z.object({ id: z.string().uuid() });
const Role = z.enum(['TANK', 'HEALER', 'DPS']);

async function load(c: Context<AppEnv>, id: string) {
  const { raid, guild } = await getRaid(c.var.deps, id);
  const access = await guildAccess(c, guild);
  access.assert('raids.view');
  return { raid, guild, access };
}

const meta = (c: Context<AppEnv>) => ({ ip: c.var.clientIp, ua: c.req.header('user-agent') });

export function raidRoutes() {
  const app = router();

  app.openapi(
    createRoute({ method: 'get', path: '/v1/raids/{id}', tags: ['Raids'], summary: 'Detalle de raid con inscripciones y composición', request: { params: RaidParams }, responses: { 200: json('RaidDetailDTO', Any) } }),
    async (c) => {
      const { raid, guild, access } = await load(c, c.req.valid('param').id);
      return c.json(await raidDetail(c.var.deps, guild, raid, c.var.user?.id ?? null, access.viewer), 200);
    },
  );

  app.openapi(
    createRoute({
      method: 'patch', path: '/v1/raids/{id}', tags: ['Raids'], summary: 'Editar o cambiar estado de la raid',
      request: {
        params: RaidParams,
        body: {
          content: {
            'application/json': {
              schema: z.object({
                title: z.string().trim().min(3).max(80).optional(),
                instanceKey: z.enum(RAID_INSTANCES.map((i) => i.key) as [string, ...string[]]).optional(),
                startsAt: z.string().datetime({ offset: true }).optional(),
                endsAt: z.string().datetime({ offset: true }).nullable().optional(),
                capacity: z.number().int().min(5).max(40).optional(),
                minLevel: z.number().int().min(1).max(60).nullable().optional(),
                notes: z.string().max(2000).nullable().optional(),
                status: z.enum(['SCHEDULED', 'IN_PROGRESS', 'COMPLETED', 'CANCELLED']).optional(),
              }),
            },
          },
          required: true,
        },
      },
      responses: { 200: json('Raid', Any) },
    }),
    async (c) => {
      const user = requireUser(c);
      const { raid, access } = await load(c, c.req.valid('param').id);
      access.assert('raids.create');
      const after = await updateRaid(c.var.deps, raid, user.id, c.req.valid('json') as Parameters<typeof updateRaid>[3], meta(c));
      return c.json({ id: after.id, status: after.status }, 200);
    },
  );

  app.openapi(
    createRoute({
      method: 'put', path: '/v1/raids/{id}/signup', tags: ['Raids'], summary: 'Inscribirse / cambiar estado (confirmado, tentativo, rechazado)',
      request: {
        params: RaidParams,
        body: {
          content: { 'application/json': { schema: z.object({ characterId: z.string().uuid(), status: z.enum(['CONFIRMED', 'TENTATIVE', 'DECLINED']), role: Role, comment: z.string().max(280).nullable().optional() }) } },
          required: true,
        },
      },
      responses: { 200: json('Inscripción', Any) },
    }),
    async (c) => {
      const user = requireUser(c);
      const { raid, access } = await load(c, c.req.valid('param').id);
      access.assert('raids.signup');
      const row = await upsertSignup(c.var.deps, raid, user.id, c.req.valid('json'));
      return c.json({ id: row.id, status: row.status }, 200);
    },
  );

  app.openapi(
    createRoute({ method: 'delete', path: '/v1/raids/{id}/signup', tags: ['Raids'], summary: 'Retirar mi inscripción', request: { params: RaidParams }, responses: { 204: { description: 'Retirada' } } }),
    async (c) => {
      const user = requireUser(c);
      const { raid } = await load(c, c.req.valid('param').id);
      await withdrawSignup(c.var.deps, raid, user.id);
      return c.body(null, 204);
    },
  );

  app.openapi(
    createRoute({
      method: 'put', path: '/v1/raids/{id}/composition', tags: ['Raids'], summary: 'Guardar la composición (grupos, banquillo, roles)',
      request: {
        params: RaidParams,
        body: {
          content: {
            'application/json': {
              schema: z.object({
                assignments: z
                  .array(z.object({ signupId: z.string().uuid(), group: z.number().int().nullable(), slot: z.number().int().nullable(), status: z.enum(['CONFIRMED', 'TENTATIVE', 'DECLINED', 'BENCHED']).optional(), role: Role.optional() }))
                  .max(80),
              }),
            },
          },
          required: true,
        },
      },
      responses: { 200: json('RaidDetailDTO', Any) },
    }),
    async (c) => {
      const user = requireUser(c);
      const { raid, guild, access } = await load(c, c.req.valid('param').id);
      if (!access.can('raids.manage')) throw forbidden('Solo el liderazgo de banda puede editar la composición');
      await applyComposition(c.var.deps, raid, user.id, c.req.valid('json').assignments, meta(c));
      return c.json(await raidDetail(c.var.deps, guild, raid, user.id, access.viewer), 200);
    },
  );

  return app;
}
