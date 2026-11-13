import { randomUUID } from 'node:crypto';
import { OpenAPIHono } from '@hono/zod-openapi';
import { HTTPException } from 'hono/http-exception';
import { secureHeaders } from 'hono/secure-headers';
import { bodyLimit } from 'hono/body-limit';
import type { AppDeps, AppEnv } from './context';
import { csrfGuard } from './auth/access';
import { resolveAuth } from './auth/session';
import { ApiError } from './lib/errors';
import { RateLimiter, rateLimit } from './lib/rate-limit';
import { authRoutes } from './routes/auth';
import { characterRoutes } from './routes/characters';
import { groupRoutes } from './routes/groups';
import { guildRoutes } from './routes/guilds';
import { platformRoutes } from './routes/platform';
import { raidRoutes } from './routes/raids';

export function createApp(deps: AppDeps, opts: { remoteAddress?: (c: unknown) => string | undefined } = {}) {
  const app = new OpenAPIHono<AppEnv>();
  const globalLimiter = new RateLimiter(600, 60_000);

  app.use('*', async (c, next) => {
    const started = Date.now();
    c.set('deps', deps);
    c.set('requestId', c.req.header('x-request-id')?.slice(0, 64) || randomUUID());
    c.set('user', null);
    c.set('sessionId', null);
    c.set('tokenScopes', null);
    const forwarded = deps.env.TRUST_PROXY ? c.req.header('x-forwarded-for')?.split(',')[0]?.trim() : undefined;
    c.set('clientIp', forwarded || opts.remoteAddress?.(c) || 'unknown');
    await next();
    c.header('X-Request-Id', c.var.requestId);
    const path = new URL(c.req.url).pathname;
    if (path !== '/v1/health' && !path.startsWith('/v1/media')) {
      deps.log.info('request', { id: c.var.requestId, method: c.req.method, path, status: c.res.status, ms: Date.now() - started, user: c.var.user?.id ?? null });
    }
  });
  app.use('*', secureHeaders({ crossOriginResourcePolicy: 'same-site', contentSecurityPolicy: { defaultSrc: ["'none'"], frameAncestors: ["'none'"] } }));
  app.use('/v1/*', bodyLimit({ maxSize: 2_500_000, onError: () => { throw new ApiError(413, 'PAYLOAD_TOO_LARGE', 'La petición es demasiado grande'); } }));
  app.use('/v1/*', rateLimit(globalLimiter, (c) => `g:${c.var.clientIp}`));
  app.use('/v1/*', async (c, next) => {
    await resolveAuth(c);
    await next();
  });
  app.use('/v1/*', csrfGuard());

  app.route('/', platformRoutes());
  app.route('/', authRoutes());
  app.route('/', guildRoutes());
  app.route('/', characterRoutes());
  app.route('/', raidRoutes());
  app.route('/', groupRoutes());

  app.doc31('/v1/openapi.json', {
    openapi: '3.1.0',
    info: {
      title: 'BlazonGuild Core API',
      version: '1.0.0',
      description:
        'API de la plataforma multi-hermandad BlazonGuild para World of Warcraft: Forever. Todas las respuestas de datos de juego incluyen metadatos de procedencia (fuente, estado de verificación, confianza, fecha de captura).',
    },
    servers: [{ url: '/' }],
  });
  app.get('/v1/docs', (c) =>
    c.html(`<!doctype html><html lang="es"><head><meta charset="utf-8"><title>BlazonGuild Core API</title><meta name="viewport" content="width=device-width,initial-scale=1"></head>
<body><script id="api-reference" data-url="/api/v1/openapi.json"></script>
<script src="https://cdn.jsdelivr.net/npm/@scalar/api-reference@1.25.0"></script></body></html>`, 200, {
      'Content-Security-Policy': "default-src 'none'; script-src https://cdn.jsdelivr.net 'unsafe-inline'; style-src 'unsafe-inline' https://cdn.jsdelivr.net https://fonts.googleapis.com; font-src https://fonts.gstatic.com https://cdn.jsdelivr.net; connect-src 'self'; img-src 'self' data:",
    }),
  );

  app.notFound((c) => c.json({ error: { code: 'NOT_FOUND', message: 'Ruta no encontrada' } }, 404));
  app.onError((err, c) => {
    if (err instanceof ApiError) {
      return c.json({ error: { code: err.code, message: err.message, details: err.details } }, err.status);
    }
    if (err instanceof HTTPException) {
      return c.json({ error: { code: 'HTTP_ERROR', message: err.message } }, err.status);
    }
    deps.log.error('unhandled error', { id: c.var.requestId, err: err instanceof Error ? `${err.message}\n${err.stack}` : String(err) });
    return c.json({ error: { code: 'INTERNAL', message: 'Error interno. Referencia: ' + c.var.requestId } }, 500);
  });

  return app;
}
