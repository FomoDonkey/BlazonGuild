import { createRoute, z } from '@hono/zod-openapi';
import type { Context } from 'hono';
import { and, asc, characters, eq, gt, groupListings, groupMembers, guilds, inArray, users } from '@blazonguild/database';
import { DUNGEONS, dungeonByKey, groupComposition, isRegion, type CombatRole, type Region } from '@blazonguild/types';
import type { AppEnv } from '../context';
import { guildAccess, requireUser } from '../auth/access';
import { audit } from '../lib/audit';
import { badRequest, conflict, forbidden, notFound } from '../lib/errors';
import { json, router } from '../lib/http';
import { getOrImportGuild } from '../services/guilds';
import { displayName } from '../services/mappers';

const Any = z.any();
const Role = z.enum(['TANK', 'HEALER', 'DPS']);
const GuildParams = z.object({ region: z.string().refine(isRegion, 'Región no válida'), slug: z.string().min(1).max(64) });
const DUNGEON_KEYS = DUNGEONS.map((d) => d.key) as [string, ...string[]];

type ListingRow = typeof groupListings.$inferSelect;

async function ownCharacter(c: Context<AppEnv>, guildId: string, userId: string, characterId: string) {
  const row = (await c.var.deps.db.select().from(characters).where(and(eq(characters.id, characterId), eq(characters.ownerUserId, userId), eq(characters.guildId, guildId))).limit(1))[0];
  if (!row) throw forbidden('Solo puedes usar personajes vinculados a tu cuenta que estén en esta hermandad');
  return row;
}

async function describe(c: Context<AppEnv>, listings: ListingRow[]) {
  if (!listings.length) return [];
  const ids = listings.map((l) => l.id);
  const rows = await c.var.deps.db
    .select({ m: groupMembers, ch: characters, u: { displayName: users.displayName } })
    .from(groupMembers)
    .innerJoin(characters, eq(characters.id, groupMembers.characterId))
    .innerJoin(users, eq(users.id, groupMembers.userId))
    .where(inArray(groupMembers.listingId, ids))
    .orderBy(asc(groupMembers.joinedAt));
  const viewer = c.var.user?.id ?? null;
  return listings.map((l) => {
    const d = dungeonByKey(l.dungeonKey);
    const comp = groupComposition(d?.size ?? 5);
    const members = rows.filter((r) => r.m.listingId === l.id);
    const filled: Record<CombatRole, number> = { TANK: 0, HEALER: 0, DPS: 0 };
    for (const m of members) filled[m.m.role]++;
    return {
      id: l.id,
      dungeon: d ? { key: d.key, name: d.nameEs, min: d.min, max: d.max, size: d.size } : { key: l.dungeonKey, name: l.dungeonKey, min: 1, max: 60, size: 5 },
      note: l.note,
      startsAt: l.startsAt?.toISOString() ?? null,
      status: l.status,
      leaderUserId: l.leaderUserId,
      isLeader: viewer === l.leaderUserId,
      needs: { TANK: Math.max(0, comp.TANK - filled.TANK), HEALER: Math.max(0, comp.HEALER - filled.HEALER), DPS: Math.max(0, comp.DPS - filled.DPS) },
      members: members.map((r) => ({
        userId: r.m.userId,
        userDisplayName: r.u.displayName,
        role: r.m.role,
        isViewer: r.m.userId === viewer,
        character: { id: r.ch.id, region: r.ch.region, slug: r.ch.slug, displayName: displayName(r.ch), classId: r.ch.classId, level: r.ch.level },
      })),
      createdAt: l.createdAt.toISOString(),
    };
  });
}

async function loadListing(c: Context<AppEnv>, id: string) {
  const row = (await c.var.deps.db.select({ l: groupListings, g: guilds }).from(groupListings).innerJoin(guilds, eq(guilds.id, groupListings.guildId)).where(eq(groupListings.id, id)).limit(1))[0];
  if (!row) throw notFound('Grupo no encontrado');
  const access = await guildAccess(c, row.g);
  access.assert('raids.view');
  return { listing: row.l, guild: row.g, access };
}

export function groupRoutes() {
  const app = router();

  app.openapi(
    createRoute({ method: 'get', path: '/v1/guilds/{region}/{slug}/groups', tags: ['Groups'], summary: 'Grupos de mazmorra abiertos (miembros)', request: { params: GuildParams }, responses: { 200: json('Grupos', Any) } }),
    async (c) => {
      const p = c.req.valid('param');
      const guild = await getOrImportGuild(c.var.deps, p.region as Region, decodeURIComponent(p.slug), c.var.user?.id ?? null);
      const access = await guildAccess(c, guild);
      access.assert('raids.view');
      const rows = await c.var.deps.db
        .select()
        .from(groupListings)
        .where(and(eq(groupListings.guildId, guild.id), eq(groupListings.status, 'OPEN'), gt(groupListings.expiresAt, c.var.deps.now())))
        .orderBy(asc(groupListings.startsAt), asc(groupListings.createdAt));
      return c.json({ viewer: access.viewer, groups: await describe(c, rows) }, 200);
    },
  );

  app.openapi(
    createRoute({
      method: 'post', path: '/v1/guilds/{region}/{slug}/groups', tags: ['Groups'], summary: 'Crear un grupo de mazmorra (el creador entra con su personaje y rol)',
      request: {
        params: GuildParams,
        body: {
          content: { 'application/json': { schema: z.object({ dungeonKey: z.enum(DUNGEON_KEYS), characterId: z.string().uuid(), role: Role, note: z.string().max(200).nullable().optional(), startsAt: z.string().datetime({ offset: true }).nullable().optional() }) } },
          required: true,
        },
      },
      responses: { 201: json('Grupo creado', Any) },
    }),
    async (c) => {
      const user = requireUser(c);
      const p = c.req.valid('param');
      const body = c.req.valid('json');
      const guild = await getOrImportGuild(c.var.deps, p.region as Region, decodeURIComponent(p.slug), user.id);
      (await guildAccess(c, guild)).assert('raids.signup');
      await ownCharacter(c, guild.id, user.id, body.characterId);
      const startsAt = body.startsAt ? new Date(body.startsAt) : null;
      const now = c.var.deps.now();
      if (startsAt && startsAt.getTime() < now.getTime() - 3_600_000) throw badRequest('La hora de inicio ya ha pasado');
      const expiresAt = new Date((startsAt ?? now).getTime() + (startsAt ? 4 : 12) * 3_600_000);
      const { db } = c.var.deps;
      const listing = await db.transaction(async (tx) => {
        const [l] = await tx.insert(groupListings).values({ guildId: guild.id, dungeonKey: body.dungeonKey, note: body.note?.trim() || null, startsAt, leaderUserId: user.id, expiresAt }).returning();
        await tx.insert(groupMembers).values({ listingId: l.id, userId: user.id, characterId: body.characterId, role: body.role });
        return l;
      });
      await audit(db, { actorUserId: user.id, guildId: guild.id, action: 'GROUP_CREATE', entity: 'group_listing', entityId: listing.id, changes: { dungeon: body.dungeonKey }, ip: c.var.clientIp });
      return c.json({ id: listing.id }, 201);
    },
  );

  app.openapi(
    createRoute({
      method: 'put', path: '/v1/groups/{id}/join', tags: ['Groups'], summary: 'Unirse a un grupo en un rol libre',
      request: { params: z.object({ id: z.string().uuid() }), body: { content: { 'application/json': { schema: z.object({ characterId: z.string().uuid(), role: Role }) } }, required: true } },
      responses: { 200: json('Unido', Any) },
    }),
    async (c) => {
      const user = requireUser(c);
      const { id } = c.req.valid('param');
      const body = c.req.valid('json');
      const { listing, guild, access } = await loadListing(c, id);
      access.assert('raids.signup');
      if (listing.status !== 'OPEN' || listing.expiresAt <= c.var.deps.now()) throw conflict('Este grupo ya está cerrado');
      await ownCharacter(c, guild.id, user.id, body.characterId);
      const [described] = await describe(c, [listing]);
      if (described.members.some((m) => m.userId === user.id)) throw conflict('Ya estás en este grupo');
      if (described.needs[body.role] <= 0) throw conflict(`El grupo ya no necesita ${body.role === 'TANK' ? 'tanque' : body.role === 'HEALER' ? 'sanador' : 'más daño'}`);
      await c.var.deps.db.insert(groupMembers).values({ listingId: id, userId: user.id, characterId: body.characterId, role: body.role });
      return c.json((await describe(c, [listing]))[0], 200);
    },
  );

  app.openapi(
    createRoute({ method: 'delete', path: '/v1/groups/{id}/join', tags: ['Groups'], summary: 'Salir del grupo (si sale el creador, el grupo se cierra)', request: { params: z.object({ id: z.string().uuid() }) }, responses: { 204: { description: 'Fuera' } } }),
    async (c) => {
      const user = requireUser(c);
      const { id } = c.req.valid('param');
      const { listing } = await loadListing(c, id);
      const { db } = c.var.deps;
      if (listing.leaderUserId === user.id) await db.update(groupListings).set({ status: 'CLOSED' }).where(eq(groupListings.id, id));
      else await db.delete(groupMembers).where(and(eq(groupMembers.listingId, id), eq(groupMembers.userId, user.id)));
      return c.body(null, 204);
    },
  );

  app.openapi(
    createRoute({ method: 'post', path: '/v1/groups/{id}/close', tags: ['Groups'], summary: 'Cerrar el grupo (creador o liderazgo de banda)', request: { params: z.object({ id: z.string().uuid() }) }, responses: { 204: { description: 'Cerrado' } } }),
    async (c) => {
      const user = requireUser(c);
      const { id } = c.req.valid('param');
      const { listing, guild, access } = await loadListing(c, id);
      if (listing.leaderUserId !== user.id && !access.can('raids.manage')) throw forbidden('Solo quien creó el grupo o el liderazgo de banda puede cerrarlo');
      await c.var.deps.db.update(groupListings).set({ status: 'CLOSED' }).where(eq(groupListings.id, id));
      await audit(c.var.deps.db, { actorUserId: user.id, guildId: guild.id, action: 'GROUP_CLOSE', entity: 'group_listing', entityId: id, ip: c.var.clientIp });
      return c.body(null, 204);
    },
  );

  return app;
}
