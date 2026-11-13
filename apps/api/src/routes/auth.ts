import { createRoute, z } from '@hono/zod-openapi';
import { getCookie, setCookie, deleteCookie } from 'hono/cookie';
import { and, apiTokens, characters, desc, eq, guildMemberships, guilds, isNull, users } from '@blazonguild/database';
import { isRegion, type MeDTO, type Region } from '@blazonguild/types';
import type { AppDeps } from '../context';
import { requireUser } from '../auth/access';
import { completeBattlenetLogin, safeReturnTo, signState, verifyState } from '../auth/battlenet';
import { createSession, destroyAllSessions, destroySession } from '../auth/session';
import { audit } from '../lib/audit';
import { getDummyHash, hashPassword, randomToken, sha256, verifyPassword } from '../lib/crypto';
import { ApiError, badRequest, conflict, notFound, unauthorized } from '../lib/errors';
import { json, router } from '../lib/http';
import { RateLimiter, rateLimit } from '../lib/rate-limit';
import { displayName, toGuildSummary } from '../services/mappers';

const Any = z.any();
const Credentials = z.object({
  email: z.string().trim().toLowerCase().email().max(254),
  password: z.string().min(10, 'La contraseña debe tener al menos 10 caracteres').max(200),
});
const Register = Credentials.extend({ displayName: z.string().trim().min(2).max(40) });

export async function buildMe(deps: AppDeps, userId: string): Promise<MeDTO> {
  const [u] = await deps.db.select().from(users).where(eq(users.id, userId)).limit(1);
  if (!u) throw unauthorized();
  const memberships = await deps.db
    .select({ m: guildMemberships, g: guilds })
    .from(guildMemberships)
    .innerJoin(guilds, eq(guilds.id, guildMemberships.guildId))
    .where(eq(guildMemberships.userId, userId));
  const chars = await deps.db
    .select({ c: characters, guildSlug: guilds.slug })
    .from(characters)
    .leftJoin(guilds, eq(guilds.id, characters.guildId))
    .where(eq(characters.ownerUserId, userId))
    .orderBy(desc(characters.isMain), desc(characters.level));
  return {
    user: { id: u.id, email: u.email, displayName: u.displayName, role: u.platformRole, battleTag: u.battleTag, createdAt: u.createdAt.toISOString() },
    memberships: memberships.map(({ m, g }) => {
      const s = toGuildSummary(g);
      return { guild: { id: s.id, region: s.region, slug: s.slug, name: s.name, faction: s.faction, crest: s.crest }, role: m.role, verified: m.verified };
    }),
    characters: chars.map(({ c, guildSlug }) => ({
      id: c.id, region: c.region as Region, slug: c.slug, displayName: displayName(c), classId: c.classId, level: c.level,
      verified: c.ownershipVerified, isMain: c.isMain, guildSlug: guildSlug ?? null,
    })),
  };
}

export function authRoutes() {
  const app = router();
  const authLimiter = new RateLimiter(10, 60_000);
  const limited = rateLimit(authLimiter, (c) => `auth:${c.var.clientIp}`);

  app.use('/v1/auth/login', limited);
  app.use('/v1/auth/register', limited);

  app.openapi(
    createRoute({ method: 'post', path: '/v1/auth/register', tags: ['Auth'], summary: 'Crear cuenta con email y contraseña', request: { body: { content: { 'application/json': { schema: Register } }, required: true } }, responses: { 201: json('Sesión iniciada', Any) } }),
    async (c) => {
      const body = c.req.valid('json');
      const { db } = c.var.deps;
      const exists = await db.select({ id: users.id }).from(users).where(eq(users.email, body.email)).limit(1);
      if (exists[0]) throw conflict('Ya existe una cuenta con ese email');
      const [user] = await db
        .insert(users)
        .values({ email: body.email, displayName: body.displayName, passwordHash: await hashPassword(body.password), lastLoginAt: c.var.deps.now() })
        .returning();
      await audit(db, { actorUserId: user.id, action: 'USER_REGISTER', entity: 'user', entityId: user.id, ip: c.var.clientIp, userAgent: c.req.header('user-agent') });
      await createSession(c, user.id);
      return c.json(await buildMe(c.var.deps, user.id), 201);
    },
  );

  app.openapi(
    createRoute({ method: 'post', path: '/v1/auth/login', tags: ['Auth'], summary: 'Iniciar sesión', request: { body: { content: { 'application/json': { schema: Credentials } }, required: true } }, responses: { 200: json('Sesión iniciada', Any) } }),
    async (c) => {
      const body = c.req.valid('json');
      const { db } = c.var.deps;
      const [user] = await db.select().from(users).where(eq(users.email, body.email)).limit(1);
      const ok = await verifyPassword(body.password, user?.passwordHash ?? (await getDummyHash()));
      if (!user || !ok || !user.isActive) {
        await audit(db, { actorUserId: user?.id ?? null, action: 'LOGIN_FAILED', entity: 'user', entityId: user?.id ?? body.email, ip: c.var.clientIp, userAgent: c.req.header('user-agent') });
        throw new ApiError(401, 'INVALID_CREDENTIALS', 'Email o contraseña incorrectos');
      }
      await db.update(users).set({ lastLoginAt: c.var.deps.now() }).where(eq(users.id, user.id));
      await createSession(c, user.id);
      return c.json(await buildMe(c.var.deps, user.id), 200);
    },
  );

  app.openapi(
    createRoute({ method: 'post', path: '/v1/auth/logout', tags: ['Auth'], summary: 'Cerrar sesión', responses: { 204: { description: 'Sesión cerrada' } } }),
    async (c) => {
      await destroySession(c);
      return c.body(null, 204);
    },
  );

  app.openapi(
    createRoute({ method: 'post', path: '/v1/auth/logout-all', tags: ['Auth'], summary: 'Cerrar todas las sesiones de la cuenta', responses: { 204: { description: 'Sesiones cerradas' } } }),
    async (c) => {
      const user = requireUser(c);
      await destroyAllSessions(c.var.deps.db, user.id);
      await destroySession(c);
      await audit(c.var.deps.db, { actorUserId: user.id, action: 'LOGOUT_ALL', entity: 'user', entityId: user.id, ip: c.var.clientIp });
      return c.body(null, 204);
    },
  );

  app.openapi(
    createRoute({ method: 'get', path: '/v1/auth/me', tags: ['Auth'], summary: 'Usuario actual, hermandades y personajes', responses: { 200: json('MeDTO', Any) } }),
    async (c) => {
      const user = requireUser(c);
      return c.json(await buildMe(c.var.deps, user.id), 200);
    },
  );

  app.openapi(
    createRoute({ method: 'get', path: '/v1/auth/providers', tags: ['Auth'], summary: 'Métodos de inicio de sesión disponibles', responses: { 200: json('Proveedores', Any) } }),
    (c) => c.json({ password: true, battlenet: !!c.var.deps.env.BATTLENET_REDIRECT_URI }, 200),
  );

  // --- Battle.net OAuth --------------------------------------------------------
  const stateCookie = 'forever_oauth_state';
  app.openapi(
    createRoute({
      method: 'get', path: '/v1/auth/battlenet/start', tags: ['Auth'], summary: 'Redirige a Battle.net para verificar personajes',
      request: { query: z.object({ returnTo: z.string().optional(), region: z.string().default('eu') }) },
      responses: { 302: { description: 'Redirección a oauth.battle.net' } },
    }),
    (c) => {
      const { env } = c.var.deps;
      if (!env.BATTLENET_REDIRECT_URI) throw new ApiError(503, 'BATTLENET_DISABLED', 'El inicio de sesión con Battle.net no está configurado en este servidor');
      const q = c.req.valid('query');
      const region = isRegion(q.region) ? q.region : 'eu';
      const state = signState(env.SESSION_SECRET, { returnTo: safeReturnTo(q.returnTo), region });
      setCookie(c, stateCookie, state, { httpOnly: true, sameSite: 'Lax', secure: env.NODE_ENV === 'production', path: '/', maxAge: 600 });
      return c.redirect(c.var.deps.blizzard(region).authorizeUrl({ redirectUri: env.BATTLENET_REDIRECT_URI, state }), 302);
    },
  );

  app.openapi(
    createRoute({
      method: 'get', path: '/v1/auth/battlenet/callback', tags: ['Auth'], summary: 'Callback OAuth de Battle.net',
      request: { query: z.object({ code: z.string().optional(), state: z.string().optional(), error: z.string().optional() }) },
      responses: { 302: { description: 'Redirección a la web' } },
    }),
    async (c) => {
      const { env } = c.var.deps;
      const q = c.req.valid('query');
      const web = env.WEB_ORIGIN;
      const cookieState = getCookie(c, stateCookie);
      deleteCookie(c, stateCookie, { path: '/' });
      const state = verifyState(env.SESSION_SECRET, q.state);
      if (!state || !cookieState || cookieState !== q.state) return c.redirect(`${web}/login?error=state`, 302);
      if (q.error || !q.code) return c.redirect(`${web}/login?error=denied`, 302);
      try {
        const { user } = await completeBattlenetLogin(c.var.deps, state.region, q.code, c.var.user?.id ?? null, { ip: c.var.clientIp, ua: c.req.header('user-agent') });
        await createSession(c, user.id);
        return c.redirect(`${web}${state.returnTo}`, 302);
      } catch (err) {
        c.var.deps.log.error('battlenet login failed', { err: String(err) });
        return c.redirect(`${web}/login?error=battlenet`, 302);
      }
    },
  );

  // --- Personal access tokens (companion / addon uploads) ------------------------
  app.openapi(
    createRoute({ method: 'get', path: '/v1/me/tokens', tags: ['Auth'], summary: 'Tokens personales', responses: { 200: json('Lista', Any) } }),
    async (c) => {
      const user = requireUser(c);
      const rows = await c.var.deps.db.select().from(apiTokens).where(and(eq(apiTokens.userId, user.id), isNull(apiTokens.revokedAt)));
      return c.json(rows.map((r) => ({ id: r.id, name: r.name, scopes: r.scopes, lastUsedAt: r.lastUsedAt, createdAt: r.createdAt })), 200);
    },
  );
  app.openapi(
    createRoute({
      method: 'post', path: '/v1/me/tokens', tags: ['Auth'], summary: 'Crear token para la app compañera (solo se muestra una vez)',
      request: { body: { content: { 'application/json': { schema: z.object({ name: z.string().trim().min(1).max(60) }) } }, required: true } },
      responses: { 201: json('Token creado', Any) },
    }),
    async (c) => {
      const user = requireUser(c);
      if (c.var.tokenScopes) throw badRequest('No se pueden crear tokens con otro token');
      const token = `fvr_${randomToken(32)}`;
      const [row] = await c.var.deps.db.insert(apiTokens).values({ userId: user.id, name: c.req.valid('json').name, tokenHash: sha256(token) }).returning();
      await audit(c.var.deps.db, { actorUserId: user.id, action: 'TOKEN_CREATE', entity: 'api_token', entityId: row.id, ip: c.var.clientIp });
      return c.json({ id: row.id, name: row.name, token, scopes: row.scopes }, 201);
    },
  );
  app.openapi(
    createRoute({ method: 'delete', path: '/v1/me/tokens/{id}', tags: ['Auth'], summary: 'Revocar token', request: { params: z.object({ id: z.string().uuid() }) }, responses: { 204: { description: 'Revocado' } } }),
    async (c) => {
      const user = requireUser(c);
      const { id } = c.req.valid('param');
      const res = await c.var.deps.db.update(apiTokens).set({ revokedAt: c.var.deps.now() }).where(and(eq(apiTokens.id, id), eq(apiTokens.userId, user.id))).returning({ id: apiTokens.id });
      if (!res[0]) throw notFound('Token no encontrado');
      await audit(c.var.deps.db, { actorUserId: user.id, action: 'TOKEN_REVOKE', entity: 'api_token', entityId: id, ip: c.var.clientIp });
      return c.body(null, 204);
    },
  );

  // --- Main character -------------------------------------------------------------
  app.openapi(
    createRoute({
      method: 'put', path: '/v1/me/main', tags: ['Auth'], summary: 'Marcar personaje principal',
      request: { body: { content: { 'application/json': { schema: z.object({ characterId: z.string().uuid() }) } }, required: true } },
      responses: { 200: json('MeDTO', Any) },
    }),
    async (c) => {
      const user = requireUser(c);
      const { characterId } = c.req.valid('json');
      const { db } = c.var.deps;
      const owned = await db.select({ id: characters.id }).from(characters).where(and(eq(characters.id, characterId), eq(characters.ownerUserId, user.id))).limit(1);
      if (!owned[0]) throw notFound('Ese personaje no está vinculado a tu cuenta');
      await db.transaction(async (tx) => {
        await tx.update(characters).set({ isMain: false }).where(eq(characters.ownerUserId, user.id));
        await tx.update(characters).set({ isMain: true }).where(eq(characters.id, characterId));
      });
      return c.json(await buildMe(c.var.deps, user.id), 200);
    },
  );

  return app;
}
