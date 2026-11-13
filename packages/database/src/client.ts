import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import type { PgDatabase, PgQueryResultHKT } from 'drizzle-orm/pg-core';
import * as schema from './schema';

export type Schema = typeof schema;
/** Driver-agnostic database handle (node-postgres in production, PGlite in dev/tests). */
export type Database = PgDatabase<PgQueryResultHKT, Schema>;

export interface DatabaseHandle {
  db: Database;
  driver: 'pg' | 'pglite';
  close: () => Promise<void>;
}

const here = path.dirname(fileURLToPath(import.meta.url));
export const MIGRATIONS_DIR = path.resolve(here, '../migrations');

/**
 * DATABASE_URL formats:
 *   postgres://user:pass@host:5432/db   → node-postgres pool (production)
 *   pglite:./.data/forever              → embedded PGlite persisted on disk (development)
 *   pglite:memory                       → ephemeral in-memory PGlite (tests)
 */
export async function openDatabase(url: string, opts: { migrate?: boolean } = {}): Promise<DatabaseHandle> {
  const migrateNow = opts.migrate ?? true;
  if (/^postgres(ql)?:\/\//.test(url)) {
    const { default: pg } = await import('pg');
    const { drizzle } = await import('drizzle-orm/node-postgres');
    const pool = new pg.Pool({ connectionString: url, max: 10 });
    const db = drizzle(pool, { schema }) as unknown as Database;
    if (migrateNow) {
      const { migrate } = await import('drizzle-orm/node-postgres/migrator');
      await migrate(drizzle(pool, { schema }), { migrationsFolder: MIGRATIONS_DIR });
    }
    return { db, driver: 'pg', close: () => pool.end() };
  }

  const target = url.replace(/^pglite:/, '').replace(/^file:/, '');
  const { PGlite } = await import('@electric-sql/pglite');
  const { drizzle } = await import('drizzle-orm/pglite');
  const inMemory = target === 'memory' || target === '';
  let releaseLock = () => {};
  if (!inMemory) {
    fs.mkdirSync(path.resolve(target), { recursive: true });
    releaseLock = acquireLock(path.resolve(target));
  }
  const client = inMemory ? new PGlite() : new PGlite(path.resolve(target));
  const pgliteDb = drizzle(client, { schema });
  if (migrateNow) {
    const { migrate } = await import('drizzle-orm/pglite/migrator');
    await migrate(pgliteDb, { migrationsFolder: MIGRATIONS_DIR });
  }
  return {
    db: pgliteDb as unknown as Database,
    driver: 'pglite',
    close: async () => {
      await client.close();
      releaseLock();
    },
  };
}

/**
 * PGlite is single-process: two processes on the same data directory corrupt it.
 * A PID lock file makes a second process fail fast with a clear message instead.
 */
function acquireLock(dir: string) {
  const lock = dir + '.lock';
  try {
    const pid = Number(fs.readFileSync(lock, 'utf8'));
    if (pid && pid !== process.pid) {
      const isAlive = () => {
        try {
          process.kill(pid, 0);
          return true;
        } catch {
          return false;
        }
      };
      // A watcher restart may still be tearing the previous process down: wait up to ~6 s.
      let alive = isAlive();
      for (let i = 0; alive && i < 30; i++) {
        Atomics.wait(new Int32Array(new SharedArrayBuffer(4)), 0, 0, 200);
        alive = isAlive();
      }
      if (alive) throw new Error(`La base de datos PGlite ${dir} ya está abierta por el proceso ${pid}. Cierra esa instancia de la API antes de abrir otra.`);
    }
  } catch (err) {
    if ((err as NodeJS.ErrnoException).code !== 'ENOENT') throw err;
  }
  fs.writeFileSync(lock, String(process.pid));
  const release = () => {
    try {
      if (fs.readFileSync(lock, 'utf8') === String(process.pid)) fs.unlinkSync(lock);
    } catch {
      /* already gone */
    }
  };
  process.once('exit', release);
  return release;
}
