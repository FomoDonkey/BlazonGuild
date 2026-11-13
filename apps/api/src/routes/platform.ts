import { createHash } from 'node:crypto';
import fs from 'node:fs/promises';
import path from 'node:path';
import { createRoute, z } from '@hono/zod-openapi';
import {
  and,
  auditLogs,
  characters,
  count,
  desc,
  eq,
  guilds,
  ilike,
  ingestBatches,
  isNull,
  notifications,
  or,
  sql,
  syncJobs,
  users,
} from '@blazonguild/database';
import { isRegion, type Region, type SearchResultDTO } from '@blazonguild/types';
import { requireAdmin, requireUser } from '../auth/access';
import { audit } from '../lib/audit';
import { badRequest, conflict } from '../lib/errors';
import { clampPage, json, router } from '../lib/http';
import { displayName, toGuildSummary } from '../services/mappers';

const Any = z.any();
const MEDIA_HOST = 'render.worldofwarcraft.com';
const MAX_MEDIA_BYTES = 5 * 1024 * 1024;

export function platformRoutes() {
  const app = router();

  app.openapi(
    createRoute({ method: 'get', path: '/v1/health', tags: ['Platform'], summary: 'Estado del servicio', responses: { 200: json('OK', Any) } }),
    async (c) => {
      const started = Date.now();
      await c.var.deps.db.execute(sql`select 1`);
      return c.json({ status: 'ok', db: 'ok', dbLatencyMs: Date.now() - started, time: c.var.deps.now().toISOString() }, 200);
    },
  );

  // --- Global search -------------------------------------------------------------
  app.openapi(
    createRoute({
      method: 'get', path: '/v1/search', tags: ['Platform'], summary: 'Búsqueda global de hermandades y personajes',
      request: { query: z.object({ q: z.string().trim().min(2).max(48), region: z.string().default('eu') }) },
      responses: { 200: json('SearchResultDTO', Any) },
    }),
    async (c) => {
      const { q, region: r } = c.req.valid('query');
      const region: Region = isRegion(r) ? r : 'eu';
      const like = `%${q.replace(/[%_]/g, '')}%`;
      const { db } = c.var.deps;
      const g = await db.select().from(guilds).where(and(eq(guilds.region, region), or(ilike(guilds.name, like), ilike(guilds.slug, like)))).orderBy(desc(guilds.memberCount)).limit(6);
      const ch = await db
        .select({ c: characters, guildName: guilds.name })
        .from(characters)
        .leftJoin(guilds, eq(guilds.id, characters.guildId))
        .where(and(eq(characters.region, region), or(ilike(characters.name, like), ilike(characters.surname, like), ilike(characters.slug, like))))
        .orderBy(desc(characters.level))
        .limit(8);
      const result: SearchResultDTO = {
        query: q,
        guilds: g.map((x) => {
          const s = toGuildSummary(x);
          return { region: s.region, slug: s.slug, name: s.name, faction: s.faction, memberCount: s.memberCount, crest: s.crest };
        }),
        characters: ch.map(({ c: x, guildName }) => ({ region: x.region as Region, slug: x.slug, displayName: displayName(x), level: x.level, classId: x.classId, guildName })),
      };
      return c.json(result, 200);
    },
  );

  // --- Media proxy (same-origin crest/icon images; allow-listed host only) ---------------
  app.openapi(
    createRoute({
      method: 'get', path: '/v1/media', tags: ['Platform'], summary: `Proxy de imágenes de ${MEDIA_HOST} (con caché)`,
      request: { query: z.object({ url: z.string().url().max(400) }) },
      responses: { 200: { description: 'Imagen' } },
    }),
    async (c) => {
      const target = new URL(c.req.valid('query').url);
      if (target.protocol !== 'https:' || target.hostname !== MEDIA_HOST || target.port || target.username) throw badRequest('Origen de imagen no permitido');
      if (!/\.(png|jpe?g)$/i.test(target.pathname)) throw badRequest('Tipo de imagen no permitido');
      const dir = path.resolve(c.var.deps.env.MEDIA_CACHE_DIR);
      const key = createHash('sha256').update(target.href).digest('hex');
      const file = path.join(dir, key);
      const type = /\.png$/i.test(target.pathname) ? 'image/png' : 'image/jpeg';
      const headers = { 'Content-Type': type, 'Cache-Control': 'public, max-age=604800, immutable', 'X-Content-Type-Options': 'nosniff' };
      try {
        const buf = await fs.readFile(file);
        return c.body(new Uint8Array(buf), 200, headers);
      } catch {
        /* cache miss */
      }
      const res = await fetch(target.href, { redirect: 'error', signal: AbortSignal.timeout(8000) });
      if (!res.ok) return c.body(null, res.status === 404 || res.status === 403 ? 404 : 502);
      const length = Number(res.headers.get('content-length') ?? 0);
      if (length > MAX_MEDIA_BYTES) return c.body(null, 413);
      const buf = new Uint8Array(await res.arrayBuffer());
      if (buf.byteLength > MAX_MEDIA_BYTES) return c.body(null, 413);
      await fs.mkdir(dir, { recursive: true });
      await fs.writeFile(file, buf);
      return c.body(buf, 200, headers);
    },
  );

  // --- Notifications ---------------------------------------------------------------
  app.openapi(
    createRoute({ method: 'get', path: '/v1/notifications', tags: ['Platform'], summary: 'Mis notificaciones', responses: { 200: json('Lista', Any) } }),
    async (c) => {
      const user = requireUser(c);
      const { db } = c.var.deps;
      const rows = await db.select().from(notifications).where(eq(notifications.userId, user.id)).orderBy(desc(notifications.createdAt)).limit(30);
      const [{ n }] = await db.select({ n: count() }).from(notifications).where(and(eq(notifications.userId, user.id), isNull(notifications.readAt)));
      return c.json({ unread: Number(n), items: rows.map((r) => ({ id: r.id, type: r.type, title: r.title, body: r.body, link: r.link, readAt: r.readAt, createdAt: r.createdAt })) }, 200);
    },
  );
  app.openapi(
    createRoute({ method: 'post', path: '/v1/notifications/read-all', tags: ['Platform'], summary: 'Marcar todas como leídas', responses: { 204: { description: 'Hecho' } } }),
    async (c) => {
      const user = requireUser(c);
      await c.var.deps.db.update(notifications).set({ readAt: c.var.deps.now() }).where(and(eq(notifications.userId, user.id), isNull(notifications.readAt)));
      return c.body(null, 204);
    },
  );

  // --- Addon ingestion (companion app → Core) ----------------------------------------
  const IngestBody = z.object({
    addonVersion: z.string().max(20),
    clientBuild: z.string().max(40).optional(),
    capturedAt: z.string().datetime(),
    character: z.object({ region: z.string(), slug: z.string().max(64) }),
    data: z.record(z.string(), z.unknown()),
  });
  app.openapi(
    createRoute({
      method: 'post', path: '/v1/ingest/addon', tags: ['Ingestion'], summary: 'Subida de SavedVariables del addon (Bearer token). Se almacena como no verificada; procesado en Fase 6–7.',
      request: { body: { content: { 'application/json': { schema: IngestBody } }, required: true } },
      responses: { 202: json('Aceptado', Any), 409: json('Duplicado', Any) },
    }),
    async (c) => {
      const user = requireUser(c);
      const body = c.req.valid('json');
      const raw = JSON.stringify(body);
      if (raw.length > 2_000_000) throw badRequest('Carga demasiado grande (máx. 2 MB)');
      const checksum = createHash('sha256').update(raw).digest('hex');
      const { db } = c.var.deps;
      const dup = await db.select({ id: ingestBatches.id }).from(ingestBatches).where(eq(ingestBatches.checksum, checksum)).limit(1);
      if (dup[0]) throw conflict('Este lote ya se recibió', { batchId: dup[0].id });
      const [row] = await db
        .insert(ingestBatches)
        .values({ userId: user.id, source: 'ADDON', checksum, addonVersion: body.addonVersion, clientBuild: body.clientBuild ?? null, payload: body })
        .returning();
      await audit(db, { actorUserId: user.id, action: 'INGEST_ADDON', entity: 'ingest_batch', entityId: row.id, changes: { checksum, character: body.character }, ip: c.var.clientIp });
      return c.json({ batchId: row.id, checksum, status: row.status, provenance: { source: 'ADDON_COLLECTED', status: 'UNVERIFIED' } }, 202);
    },
  );

  // --- Platform administration ---------------------------------------------------------
  app.openapi(
    createRoute({ method: 'get', path: '/v1/admin/overview', tags: ['Admin'], summary: 'Métricas de la plataforma', responses: { 200: json('Resumen', Any) } }),
    async (c) => {
      requireAdmin(c);
      const { db } = c.var.deps;
      const one = async (q: Promise<{ n: number }[]>) => Number((await q)[0]?.n ?? 0);
      return c.json(
        {
          users: await one(db.select({ n: count() }).from(users)),
          guilds: await one(db.select({ n: count() }).from(guilds)),
          characters: await one(db.select({ n: count() }).from(characters)),
          syncErrors24h: await one(db.select({ n: count() }).from(syncJobs).where(and(eq(syncJobs.state, 'ERROR'), sql`${syncJobs.createdAt} > now() - interval '24 hours'`))),
        },
        200,
      );
    },
  );
  app.openapi(
    createRoute({ method: 'get', path: '/v1/admin/sync-jobs', tags: ['Admin'], summary: 'Trabajos de sincronización recientes', request: { query: z.object({ page: z.coerce.number().int().min(1).optional() }) }, responses: { 200: json('SyncJobDTO[]', Any) } }),
    async (c) => {
      requireAdmin(c);
      const { pageSize, offset } = clampPage(c.req.valid('query').page, 50);
      const rows = await c.var.deps.db.select().from(syncJobs).orderBy(desc(syncJobs.createdAt)).limit(pageSize).offset(offset);
      return c.json(rows.map((j) => ({ id: j.id, kind: j.kind, target: `${j.region}/${j.target}`, state: j.state, trigger: j.trigger, startedAt: j.startedAt, finishedAt: j.finishedAt, stats: j.stats, error: j.error })), 200);
    },
  );
  app.openapi(
    createRoute({ method: 'get', path: '/v1/admin/audit', tags: ['Admin'], summary: 'Auditoría global', request: { query: z.object({ page: z.coerce.number().int().min(1).optional() }) }, responses: { 200: json('AuditEntryDTO[]', Any) } }),
    async (c) => {
      requireAdmin(c);
      const { pageSize, offset } = clampPage(c.req.valid('query').page, 50);
      const rows = await c.var.deps.db.select({ a: auditLogs, actor: users.displayName }).from(auditLogs).leftJoin(users, eq(users.id, auditLogs.actorUserId)).orderBy(desc(auditLogs.createdAt)).limit(pageSize).offset(offset);
      return c.json(rows.map(({ a, actor }) => ({ id: a.id, at: a.createdAt, actor, action: a.action, entity: a.entity, entityId: a.entityId, changes: a.changes })), 200);
    },
  );
  app.openapi(
    createRoute({
      method: 'post', path: '/v1/admin/characters/link', tags: ['Admin'], summary: 'Vincular manualmente un personaje a un usuario (sin verificación Battle.net, auditado)',
      request: { body: { content: { 'application/json': { schema: z.object({ userId: z.string().uuid(), region: z.string(), slug: z.string() }) } }, required: true } },
      responses: { 200: json('Vinculado', Any) },
    }),
    async (c) => {
      const admin = requireAdmin(c);
      const body = c.req.valid('json');
      if (!isRegion(body.region)) throw badRequest('Región no válida');
      const row = await c.var.deps.sync.syncCharacter(body.region, body.slug, { trigger: 'MANUAL', userId: admin.id });
      if (!row) throw badRequest('El personaje no existe en Battle.net');
      await c.var.deps.db.update(characters).set({ ownerUserId: body.userId, ownershipVerified: false }).where(eq(characters.id, row.id));
      await audit(c.var.deps.db, { actorUserId: admin.id, guildId: row.guildId, action: 'ADMIN_LINK_CHARACTER', entity: 'character', entityId: row.id, changes: { userId: body.userId }, ip: c.var.clientIp });
      return c.json({ characterId: row.id, ownerUserId: body.userId, verified: false }, 200);
    },
  );

  return app;
}
