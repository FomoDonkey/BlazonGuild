import type { Context } from 'hono';
import { deleteCookie, getCookie, setCookie } from 'hono/cookie';
import { and, apiTokens, eq, gt, isNull, sessions, users, type Database } from '@blazonguild/database';
import type { AppEnv, SessionUser } from '../context';
import { randomToken, sha256 } from '../lib/crypto';

const SESSION_TTL_MS = 30 * 24 * 3600 * 1000;
/** Sliding expiry is only re-written when less than this remains, to avoid a write per request. */
const REFRESH_THRESHOLD_MS = 20 * 24 * 3600 * 1000;

export function sessionCookieName(secure: boolean) {
  // `__Host-` forces Secure + Path=/ + no Domain → cannot be set by a sub-domain.
  return secure ? '__Host-forever_session' : 'forever_session';
}

function isSecure(c: Context<AppEnv>) {
  return c.var.deps.env.NODE_ENV === 'production';
}

export async function createSession(c: Context<AppEnv>, userId: string) {
  const token = randomToken(32);
  const now = c.var.deps.now();
  await c.var.deps.db.insert(sessions).values({
    id: sha256(token),
    userId,
    expiresAt: new Date(now.getTime() + SESSION_TTL_MS),
    ip: c.var.clientIp,
    userAgent: c.req.header('user-agent')?.slice(0, 300) ?? null,
  });
  setCookie(c, sessionCookieName(isSecure(c)), token, {
    httpOnly: true,
    secure: isSecure(c),
    sameSite: 'Lax',
    path: '/',
    maxAge: SESSION_TTL_MS / 1000,
  });
}

export async function destroySession(c: Context<AppEnv>) {
  if (c.var.sessionId) await c.var.deps.db.delete(sessions).where(eq(sessions.id, c.var.sessionId));
  deleteCookie(c, sessionCookieName(isSecure(c)), { path: '/', secure: isSecure(c) });
}

export async function destroyAllSessions(db: Database, userId: string) {
  await db.delete(sessions).where(eq(sessions.userId, userId));
}

const toSessionUser = (u: typeof users.$inferSelect): SessionUser => ({
  id: u.id,
  email: u.email,
  displayName: u.displayName,
  platformRole: u.platformRole,
  battleTag: u.battleTag,
});

/** Resolves the cookie session (browser) or a Bearer personal token (companion/addon uploads). */
export async function resolveAuth(c: Context<AppEnv>) {
  const { db, now } = c.var.deps;
  const authz = c.req.header('authorization');
  if (authz?.startsWith('Bearer ')) {
    const hash = sha256(authz.slice(7).trim());
    const rows = await db
      .select({ token: apiTokens, user: users })
      .from(apiTokens)
      .innerJoin(users, eq(users.id, apiTokens.userId))
      .where(and(eq(apiTokens.tokenHash, hash), isNull(apiTokens.revokedAt)))
      .limit(1);
    const row = rows[0];
    if (row && row.user.isActive) {
      await db.update(apiTokens).set({ lastUsedAt: now() }).where(eq(apiTokens.id, row.token.id));
      c.set('user', toSessionUser(row.user));
      c.set('tokenScopes', row.token.scopes);
    }
    return;
  }

  const token = getCookie(c, sessionCookieName(isSecure(c)));
  if (!token) return;
  const id = sha256(token);
  const rows = await db
    .select({ session: sessions, user: users })
    .from(sessions)
    .innerJoin(users, eq(users.id, sessions.userId))
    .where(and(eq(sessions.id, id), gt(sessions.expiresAt, now())))
    .limit(1);
  const row = rows[0];
  if (!row || !row.user.isActive) return;
  c.set('user', toSessionUser(row.user));
  c.set('sessionId', id);
  const remaining = row.session.expiresAt.getTime() - now().getTime();
  if (remaining < REFRESH_THRESHOLD_MS) {
    await db
      .update(sessions)
      .set({ expiresAt: new Date(now().getTime() + SESSION_TTL_MS), lastSeenAt: now() })
      .where(eq(sessions.id, id));
  }
}
