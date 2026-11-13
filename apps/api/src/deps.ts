import { BlizzardClient } from '@blazonguild/data-providers';
import { openDatabase } from '@blazonguild/database';
import type { Region } from '@blazonguild/types';
import type { AppDeps } from './context';
import type { Env } from './env';
import { createLogger, type Logger } from './lib/logger';
import { StaticDataService } from './services/static-data';
import { SyncService } from './services/sync';

export async function createDeps(env: Env, overrides: { log?: Logger; fetchImpl?: typeof fetch; now?: () => Date } = {}) {
  const log = overrides.log ?? createLogger(env.NODE_ENV === 'production' ? 'info' : 'debug');
  const handle = await openDatabase(env.DATABASE_URL);
  const clients = new Map<Region, BlizzardClient>();
  const blizzard = (region: Region) => {
    let client = clients.get(region);
    if (!client) {
      client = new BlizzardClient({ clientId: env.BLIZZARD_CLIENT_ID, clientSecret: env.BLIZZARD_CLIENT_SECRET, region, locale: env.BLIZZARD_LOCALE, fetchImpl: overrides.fetchImpl });
      clients.set(region, client);
    }
    return client;
  };
  const now = overrides.now ?? (() => new Date());
  const staticData = new StaticDataService(handle.db, blizzard, log);
  const sync = new SyncService(handle.db, blizzard, staticData, log, now);
  const deps: AppDeps = { env, db: handle.db, log, blizzard, sync, staticData, now };
  return { deps, close: handle.close, driver: handle.driver };
}
