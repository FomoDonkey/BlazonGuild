import { serve } from '@hono/node-server';
import { getConnInfo } from '@hono/node-server/conninfo';
import type { Context } from 'hono';
import { createApp } from './app';
import { createDeps } from './deps';
import { loadEnv } from './env';
import { startScheduler } from './scheduler';

const env = loadEnv();
const { deps, close, driver } = await createDeps(env);
const app = createApp(deps, { remoteAddress: (c) => getConnInfo(c as Context).remote.address });
const stopScheduler = env.DISABLE_SCHEDULER ? () => {} : startScheduler(deps);

const server = serve({ fetch: app.fetch, port: env.PORT, hostname: '127.0.0.1' }, (info) => {
  deps.log.info('BlazonGuild Core API listening', { port: info.port, driver, env: env.NODE_ENV });
});

const shutdown = async (signal: string) => {
  deps.log.info('shutting down', { signal });
  stopScheduler();
  server.close();
  await deps.sync.drain();
  await close();
  process.exit(0);
};
process.on('SIGINT', () => void shutdown('SIGINT'));
process.on('SIGTERM', () => void shutdown('SIGTERM'));
