import type { BlizzardClient } from '@blazonguild/data-providers';
import type { Database } from '@blazonguild/database';
import type { PlatformRole, Region } from '@blazonguild/types';
import type { Env } from './env';
import type { Logger } from './lib/logger';
import type { SyncService } from './services/sync';
import type { StaticDataService } from './services/static-data';

export interface AppDeps {
  env: Env;
  db: Database;
  log: Logger;
  blizzard: (region: Region) => BlizzardClient;
  sync: SyncService;
  staticData: StaticDataService;
  now: () => Date;
}

export interface SessionUser {
  id: string;
  email: string;
  displayName: string;
  platformRole: PlatformRole;
  battleTag: string | null;
}

export interface AppEnv {
  Variables: {
    deps: AppDeps;
    requestId: string;
    user: SessionUser | null;
    sessionId: string | null;
    /** Set when the request authenticated with a personal API token instead of a cookie. */
    tokenScopes: string[] | null;
    clientIp: string;
  };
}
