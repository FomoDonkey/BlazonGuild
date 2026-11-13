import type { Context, MiddlewareHandler } from 'hono';
import { and, eq, guildMemberships, guilds } from '@blazonguild/database';
import {
  GUILD_ROLE_WEIGHT,
  PERMISSIONS,
  hasGuildPermission,
  type GuildRole,
  type Permission,
  type ViewerContextDTO,
} from '@blazonguild/types';
import type { AppEnv, SessionUser } from '../context';
import { ApiError, forbidden, unauthorized } from '../lib/errors';

const UNSAFE = new Set(['POST', 'PUT', 'PATCH', 'DELETE']);

/**
 * CSRF defence for cookie-authenticated requests:
 *  1. state-changing requests must be JSON (cross-site forms cannot send application/json
 *     without a CORS pre-flight, which we never grant), and
 *  2. when the browser sends an Origin header it must be the platform origin.
 * Bearer-token requests (companion app) carry no ambient credentials and are exempt.
 */
export function csrfGuard(): MiddlewareHandler<AppEnv> {
  return async (c, next) => {
    if (UNSAFE.has(c.req.method) && !c.req.header('authorization')?.startsWith('Bearer ')) {
      const origin = c.req.header('origin');
      const allowed = new URL(c.var.deps.env.WEB_ORIGIN).origin;
      if (origin && origin !== allowed) throw new ApiError(403, 'CSRF_REJECTED', 'Origen no permitido');
      const type = c.req.header('content-type') ?? '';
      const hasBody = Number(c.req.header('content-length') ?? '0') > 0 || c.req.header('transfer-encoding');
      if (hasBody && !type.toLowerCase().startsWith('application/json')) {
        throw new ApiError(415, 'UNSUPPORTED_MEDIA_TYPE', 'Las peticiones deben enviarse como application/json');
      }
    }
    await next();
  };
}

export function requireUser(c: Context<AppEnv>): SessionUser {
  const user = c.var.user;
  if (!user) throw unauthorized();
  if (c.var.tokenScopes && !c.var.tokenScopes.includes('full')) {
    // Personal tokens are limited to the scopes they were issued for (ingest by default).
    const path = new URL(c.req.url).pathname;
    if (!path.startsWith('/v1/ingest')) throw forbidden('Este token solo permite subir datos del addon');
  }
  return user;
}

export function requireAdmin(c: Context<AppEnv>): SessionUser {
  const user = requireUser(c);
  if (user.platformRole !== 'ADMIN') throw forbidden('Solo administradores de la plataforma');
  return user;
}

export type GuildRow = typeof guilds.$inferSelect;

export interface GuildAccess {
  role: GuildRole;
  membershipVerified: boolean;
  can: (permission: Permission) => boolean;
  assert: (permission: Permission) => void;
  viewer: ViewerContextDTO;
}

export async function guildAccess(c: Context<AppEnv>, guild: GuildRow): Promise<GuildAccess> {
  const user = c.var.user;
  let role: GuildRole = 'VISITOR';
  let verified = false;
  if (user) {
    const rows = await c.var.deps.db
      .select()
      .from(guildMemberships)
      .where(and(eq(guildMemberships.guildId, guild.id), eq(guildMemberships.userId, user.id)))
      .limit(1);
    if (rows[0]) {
      role = rows[0].role;
      verified = rows[0].verified;
    }
  }
  const overrides = guild.settings?.permissions ?? null;
  const can = (p: Permission) => hasGuildPermission(role, p, { overrides, platformRole: user?.platformRole });
  const permissions = (Object.keys(PERMISSIONS) as Permission[]).filter(can);
  return {
    role,
    membershipVerified: verified,
    can,
    assert: (p) => {
      if (can(p)) return;
      if (!user) throw unauthorized();
      throw forbidden(`Necesitas el permiso «${PERMISSIONS[p]}» en esta hermandad`);
    },
    viewer: { authenticated: !!user, role, permissions },
  };
}

export function outranks(a: GuildRole, b: GuildRole) {
  return GUILD_ROLE_WEIGHT[a] > GUILD_ROLE_WEIGHT[b];
}
