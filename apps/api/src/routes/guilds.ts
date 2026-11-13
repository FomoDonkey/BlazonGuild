import { createRoute, z } from '@hono/zod-openapi';
import type { Context } from 'hono';
import {
  activityEvents,
  and,
  auditLogs,
  characters,
  count,
  desc,
  eq,
  guildMemberships,
  guilds,
  lt,
  users,
} from '@blazonguild/database';
import {
  GUILD_ROLES,
  RAID_INSTANCES,
  canAssignRole,
  isRegion,
  type GuildRole,
  type Region,
  type RankingMetric,
} from '@blazonguild/types';
import type { AppEnv } from '../context';
import { guildAccess, requireUser } from '../auth/access';
import { audit } from '../lib/audit';
import { badRequest, forbidden, notFound, tooMany } from '../lib/errors';
import { clampPage, json, router } from '../lib/http';
import { RateLimiter } from '../lib/rate-limit';
import { buildOverview, getOrImportGuild, queryRoster } from '../services/guilds';
import { toActivity, toGuildSummary } from '../services/mappers';
import { createRaid, listRaids } from '../services/raids';
import { RANKING_METRICS, rankingBoard } from '../services/rankings';

const Any = z.any();
const GuildParams = z.object({
  region: z.string().refine(isRegion, 'Región no válida (eu, us, kr, tw)'),
  slug: z.string().min(1).max(64),
});
const csvInts = z
  .string()
  .optional()
  .transform((v) => (v ? v.split(',').map(Number).filter((n) => Number.isInteger(n)) : undefined));

async function loadGuild(c: Context<AppEnv>, params: { region: string; slug: string }) {
  return getOrImportGuild(c.var.deps, params.region as Region, decodeURIComponent(params.slug), c.var.user?.id ?? null);
}

export function guildRoutes() {
  const app = router();
  const importLimiter = new RateLimiter(20, 3_600_000);

  app.openapi(
    createRoute({
      method: 'get', path: '/v1/guilds', tags: ['Guilds'], summary: 'Hermandades seguidas por BlazonGuild (más vistas primero)',
      request: { query: z.object({ region: z.string().optional(), limit: z.coerce.number().int().min(1).max(50).default(12) }) },
      responses: { 200: json('GuildSummaryDTO[]', Any) },
    }),
    async (c) => {
      const q = c.req.valid('query');
      const rows = await c.var.deps.db
        .select()
        .from(guilds)
        .where(q.region && isRegion(q.region) ? eq(guilds.region, q.region) : undefined)
        .orderBy(desc(guilds.lastViewedAt), desc(guilds.memberCount))
        .limit(q.limit);
      return c.json(rows.map((g) => toGuildSummary(g)), 200);
    },
  );

  app.openapi(
    createRoute({
      method: 'get', path: '/v1/guilds/{region}/{slug}', tags: ['Guilds'], summary: 'Centro de mando: identidad, estadísticas, actividad y próximas raids. Importa la hermandad si es la primera visita.',
      request: { params: GuildParams }, responses: { 200: json('GuildOverviewDTO', Any), 404: json('No existe en Battle.net', Any) },
    }),
    async (c) => {
      const p = c.req.valid('param');
      const exists = await c.var.deps.db.select({ id: guilds.id }).from(guilds).where(and(eq(guilds.region, p.region), eq(guilds.slug, decodeURIComponent(p.slug).toLowerCase()))).limit(1);
      if (!exists[0] && !importLimiter.take(`import:${c.var.user?.id ?? c.var.clientIp}`).ok) throw tooMany('Has importado muchas hermandades seguidas; espera un poco');
      const guild = await loadGuild(c, p);
      const access = await guildAccess(c, guild);
      return c.json(await buildOverview(c.var.deps, guild, access), 200);
    },
  );

  app.openapi(
    createRoute({
      method: 'get', path: '/v1/guilds/{region}/{slug}/roster', tags: ['Guilds'], summary: 'Roster con filtros, orden y paginación',
      request: {
        params: GuildParams,
        query: z.object({
          q: z.string().max(40).optional(),
          classIds: csvInts,
          ranks: csvInts,
          role: z.enum(['TANK', 'HEALER', 'DPS']).optional(),
          minLevel: z.coerce.number().int().min(1).max(60).optional(),
          maxLevel: z.coerce.number().int().min(1).max(60).optional(),
          activeDays: z.coerce.number().int().min(1).max(365).optional(),
          sort: z.enum(['name', 'level', 'class', 'rank', 'itemLevel', 'lastLogin', 'honorableKills']).optional(),
          dir: z.enum(['asc', 'desc']).optional(),
          page: z.coerce.number().int().min(1).optional(),
          pageSize: z.coerce.number().int().min(1).max(500).optional(),
        }),
      },
      responses: { 200: json('Page<RosterMemberDTO>', Any) },
    }),
    async (c) => {
      const guild = await loadGuild(c, c.req.valid('param'));
      const q = c.req.valid('query');
      const page = clampPage(q.page, q.pageSize, 500);
      return c.json(await queryRoster(c.var.deps, guild, { ...q, ...page }), 200);
    },
  );

  app.openapi(
    createRoute({
      method: 'get', path: '/v1/guilds/{region}/{slug}/activity', tags: ['Guilds'], summary: 'Actividad reciente (derivada de sincronizaciones y logros)',
      request: { params: GuildParams, query: z.object({ before: z.string().datetime().optional(), limit: z.coerce.number().int().min(1).max(100).default(30) }) },
      responses: { 200: json('ActivityEventDTO[]', Any) },
    }),
    async (c) => {
      const guild = await loadGuild(c, c.req.valid('param'));
      const q = c.req.valid('query');
      const rows = await c.var.deps.db
        .select({ e: activityEvents, c: { region: characters.region, slug: characters.slug, name: characters.name, surname: characters.surname, classId: characters.classId } })
        .from(activityEvents)
        .leftJoin(characters, eq(characters.id, activityEvents.characterId))
        .where(and(eq(activityEvents.guildId, guild.id), q.before ? lt(activityEvents.occurredAt, new Date(q.before)) : undefined))
        .orderBy(desc(activityEvents.occurredAt))
        .limit(q.limit);
      return c.json(rows.map((r) => toActivity(r.e, r.c?.slug ? r.c : null)), 200);
    },
  );

  app.openapi(
    createRoute({
      method: 'post', path: '/v1/guilds/{region}/{slug}/sync', tags: ['Guilds'], summary: 'Forzar sincronización completa (oficiales)',
      request: { params: GuildParams }, responses: { 202: json('Sincronización iniciada', Any) },
    }),
    async (c) => {
      const user = requireUser(c);
      const guild = await loadGuild(c, c.req.valid('param'));
      (await guildAccess(c, guild)).assert('guild.sync');
      if (guild.lastSyncedAt && c.var.deps.now().getTime() - guild.lastSyncedAt.getTime() < 2 * 60_000) throw tooMany('La hermandad se sincronizó hace menos de 2 minutos');
      void c.var.deps.sync.syncGuild(guild.region as Region, guild.slug, { trigger: 'MANUAL', userId: user.id, details: 'all' }).catch((err) => c.var.deps.log.warn('manual sync failed', { err: String(err) }));
      await audit(c.var.deps.db, { actorUserId: user.id, guildId: guild.id, action: 'GUILD_SYNC', entity: 'guild', entityId: guild.id, ip: c.var.clientIp });
      return c.json({ started: true }, 202);
    },
  );

  // --- Rankings ---------------------------------------------------------------
  app.openapi(
    createRoute({
      method: 'get', path: '/v1/guilds/{region}/{slug}/rankings/{metric}', tags: ['Rankings'], summary: 'Clasificación con metodología explícita',
      request: {
        params: GuildParams.extend({ metric: z.enum(RANKING_METRICS as [RankingMetric, ...RankingMetric[]]) }),
        query: z.object({ classId: z.coerce.number().int().optional(), role: z.enum(['TANK', 'HEALER', 'DPS']).optional(), minLevel: z.coerce.number().int().min(1).max(60).optional(), limit: z.coerce.number().int().min(1).max(500).optional() }),
      },
      responses: { 200: json('RankingBoardDTO', Any) },
    }),
    async (c) => {
      const p = c.req.valid('param');
      const guild = await loadGuild(c, p);
      return c.json(await rankingBoard(c.var.deps, guild, p.metric, c.req.valid('query')), 200);
    },
  );

  // --- Raids -----------------------------------------------------------------
  app.openapi(
    createRoute({
      method: 'get', path: '/v1/guilds/{region}/{slug}/raids', tags: ['Raids'], summary: 'Raids de la hermandad (miembros)',
      request: { params: GuildParams, query: z.object({ scope: z.enum(['upcoming', 'past', 'all']).default('upcoming') }) },
      responses: { 200: json('RaidSummaryDTO[]', Any) },
    }),
    async (c) => {
      const guild = await loadGuild(c, c.req.valid('param'));
      const access = await guildAccess(c, guild);
      access.assert('raids.view');
      return c.json({ viewer: access.viewer, raids: await listRaids(c.var.deps, guild, { scope: c.req.valid('query').scope, userId: c.var.user?.id ?? null }) }, 200);
    },
  );

  const RaidBody = z.object({
    title: z.string().trim().min(3).max(80),
    instanceKey: z.enum(RAID_INSTANCES.map((i) => i.key) as [string, ...string[]]),
    startsAt: z.string().datetime({ offset: true }),
    endsAt: z.string().datetime({ offset: true }).nullable().optional(),
    capacity: z.number().int().min(5).max(40).optional(),
    minLevel: z.number().int().min(1).max(60).nullable().optional(),
    notes: z.string().max(2000).nullable().optional(),
  });

  app.openapi(
    createRoute({
      method: 'post', path: '/v1/guilds/{region}/{slug}/raids', tags: ['Raids'], summary: 'Crear raid (líder de banda o superior)',
      request: { params: GuildParams, body: { content: { 'application/json': { schema: RaidBody } }, required: true } },
      responses: { 201: json('Raid creada', Any) },
    }),
    async (c) => {
      const user = requireUser(c);
      const guild = await loadGuild(c, c.req.valid('param'));
      (await guildAccess(c, guild)).assert('raids.create');
      const raid = await createRaid(c.var.deps, guild, user.id, c.req.valid('json') as Parameters<typeof createRaid>[3], { ip: c.var.clientIp, ua: c.req.header('user-agent') });
      return c.json({ id: raid.id }, 201);
    },
  );

  // --- Platform members & roles -------------------------------------------------
  app.openapi(
    createRoute({
      method: 'get', path: '/v1/guilds/{region}/{slug}/members', tags: ['Membership'], summary: 'Miembros de la plataforma y sus roles',
      request: { params: GuildParams }, responses: { 200: json('Miembros', Any) },
    }),
    async (c) => {
      const guild = await loadGuild(c, c.req.valid('param'));
      const access = await guildAccess(c, guild);
      access.assert('members.view');
      const rows = await c.var.deps.db
        .select({ m: guildMemberships, u: { id: users.id, displayName: users.displayName, battleTag: users.battleTag } })
        .from(guildMemberships)
        .innerJoin(users, eq(users.id, guildMemberships.userId))
        .where(eq(guildMemberships.guildId, guild.id));
      return c.json({ viewer: access.viewer, members: rows.map(({ m, u }) => ({ userId: u.id, displayName: u.displayName, battleTag: access.can('members.manage') ? u.battleTag : null, role: m.role, verified: m.verified, source: m.source, since: m.createdAt })) }, 200);
    },
  );

  app.openapi(
    createRoute({
      method: 'put', path: '/v1/guilds/{region}/{slug}/members/{userId}', tags: ['Membership'], summary: 'Asignar rol de plataforma (auditado)',
      request: {
        params: GuildParams.extend({ userId: z.string().uuid() }),
        body: { content: { 'application/json': { schema: z.object({ role: z.enum(GUILD_ROLES.filter((r) => r !== 'VISITOR') as [GuildRole, ...GuildRole[]]) }) } }, required: true },
      },
      responses: { 200: json('Actualizado', Any) },
    }),
    async (c) => {
      const actor = requireUser(c);
      const p = c.req.valid('param');
      const { role } = c.req.valid('json');
      const guild = await loadGuild(c, p);
      const access = await guildAccess(c, guild);
      access.assert('members.manage');
      const { db } = c.var.deps;
      const target = (await db.select().from(users).where(eq(users.id, p.userId)).limit(1))[0];
      if (!target) throw notFound('Usuario no encontrado');
      const current = (await db.select().from(guildMemberships).where(and(eq(guildMemberships.guildId, guild.id), eq(guildMemberships.userId, p.userId))).limit(1))[0];
      if (!canAssignRole(access.role, current?.role ?? 'VISITOR', role, actor.platformRole)) throw forbidden('No puedes asignar un rol igual o superior al tuyo, ni modificar a alguien de tu rango');
      if (role === 'GUILD_MASTER' && actor.platformRole !== 'ADMIN') throw forbidden('El rol de maestro solo lo otorga la verificación de Battle.net o un administrador');
      const [row] = current
        ? await db.update(guildMemberships).set({ role, source: current.source === 'BATTLENET' ? 'BATTLENET' : 'ADMIN' }).where(eq(guildMemberships.id, current.id)).returning()
        : await db.insert(guildMemberships).values({ guildId: guild.id, userId: p.userId, role, source: 'ADMIN', verified: false }).returning();
      await audit(db, { actorUserId: actor.id, guildId: guild.id, action: 'MEMBER_ROLE', entity: 'guild_membership', entityId: row.id, changes: { before: current?.role ?? null, after: role, user: target.displayName }, ip: c.var.clientIp });
      return c.json({ userId: p.userId, role: row.role }, 200);
    },
  );

  app.openapi(
    createRoute({
      method: 'get', path: '/v1/guilds/{region}/{slug}/settings', tags: ['Membership'], summary: 'Ajustes actuales, rangos presentes en el roster y permisos efectivos (gestión)',
      request: { params: GuildParams }, responses: { 200: json('Ajustes', Any) },
    }),
    async (c) => {
      const guild = await loadGuild(c, c.req.valid('param'));
      const access = await guildAccess(c, guild);
      if (!access.can('guild.settings') && !access.can('members.manage') && !access.can('audit.view')) access.assert('guild.settings');
      const { PERMISSIONS, DEFAULT_PERMISSION_MIN_ROLE, minRoleFor } = await import('@blazonguild/types');
      const ranks = await c.var.deps.db
        .select({ rank: characters.guildRank, n: count() })
        .from(characters)
        .where(eq(characters.guildId, guild.id))
        .groupBy(characters.guildRank)
        .orderBy(characters.guildRank);
      const settings = guild.settings ?? {};
      return c.json(
        {
          viewer: access.viewer,
          settings,
          ranks: ranks.filter((r) => r.rank !== null).map((r) => ({ index: r.rank!, members: Number(r.n), name: settings.rankNames?.[String(r.rank)] ?? null, role: settings.rankRoles?.[String(r.rank)] ?? null })),
          permissions: (Object.keys(PERMISSIONS) as (keyof typeof PERMISSIONS)[]).map((k) => ({ key: k, label: PERMISSIONS[k], defaultRole: DEFAULT_PERMISSION_MIN_ROLE[k], effectiveRole: minRoleFor(k, settings.permissions) })),
          sync: { state: guild.syncState, lastSyncedAt: guild.lastSyncedAt, error: guild.syncError },
        },
        200,
      );
    },
  );

  app.openapi(
    createRoute({
      method: 'patch', path: '/v1/guilds/{region}/{slug}/settings', tags: ['Membership'], summary: 'Nombres de rango, roles por rango, permisos y descripción',
      request: {
        params: GuildParams,
        body: {
          content: {
            'application/json': {
              schema: z.object({
                rankNames: z.record(z.string().regex(/^\d{1,2}$/), z.string().trim().max(30)).optional(),
                rankRoles: z.record(z.string().regex(/^\d{1,2}$/), z.enum(['OFFICER', 'RAID_LEADER', 'RAIDER', 'MEMBER'])).optional(),
                permissions: z.record(z.string(), z.enum(GUILD_ROLES)).optional(),
                description: z.string().max(2000).optional(),
                recruitment: z.string().max(2000).optional(),
              }),
            },
          },
          required: true,
        },
      },
      responses: { 200: json('Ajustes', Any) },
    }),
    async (c) => {
      const actor = requireUser(c);
      const guild = await loadGuild(c, c.req.valid('param'));
      (await guildAccess(c, guild)).assert('guild.settings');
      const patch = c.req.valid('json');
      const { PERMISSIONS } = await import('@blazonguild/types');
      for (const k of Object.keys(patch.permissions ?? {})) if (!(k in PERMISSIONS)) throw badRequest(`Permiso desconocido: ${k}`);
      const settings = { ...guild.settings, ...patch } as typeof guild.settings;
      await c.var.deps.db.update(guilds).set({ settings }).where(eq(guilds.id, guild.id));
      await audit(c.var.deps.db, { actorUserId: actor.id, guildId: guild.id, action: 'GUILD_SETTINGS', entity: 'guild', entityId: guild.id, changes: { before: guild.settings, after: settings }, ip: c.var.clientIp });
      if (patch.rankRoles) await c.var.deps.sync.reconcileMemberships(guild.id);
      return c.json(settings, 200);
    },
  );

  app.openapi(
    createRoute({
      method: 'get', path: '/v1/guilds/{region}/{slug}/audit', tags: ['Membership'], summary: 'Registro de auditoría de la hermandad',
      request: { params: GuildParams, query: z.object({ page: z.coerce.number().int().min(1).optional() }) }, responses: { 200: json('AuditEntryDTO[]', Any) },
    }),
    async (c) => {
      const guild = await loadGuild(c, c.req.valid('param'));
      (await guildAccess(c, guild)).assert('audit.view');
      const { pageSize, offset, page } = clampPage(c.req.valid('query').page, 50);
      const { db } = c.var.deps;
      const [{ n }] = await db.select({ n: count() }).from(auditLogs).where(eq(auditLogs.guildId, guild.id));
      const rows = await db
        .select({ a: auditLogs, actor: users.displayName })
        .from(auditLogs)
        .leftJoin(users, eq(users.id, auditLogs.actorUserId))
        .where(eq(auditLogs.guildId, guild.id))
        .orderBy(desc(auditLogs.createdAt))
        .limit(pageSize)
        .offset(offset);
      return c.json({ total: Number(n), page, pageSize, items: rows.map(({ a, actor }) => ({ id: a.id, at: a.createdAt.toISOString(), actor, action: a.action, entity: a.entity, entityId: a.entityId, changes: a.changes })) }, 200);
    },
  );

  return app;
}
