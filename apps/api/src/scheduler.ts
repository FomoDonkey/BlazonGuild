import { and, asc, gte, guilds, isNotNull, isNull, lt, or, sql } from '@blazonguild/database';
import type { Region } from '@blazonguild/types';
import type { AppDeps } from './context';
import { ROSTER_STALE_MS } from './services/sync';

/**
 * Keeps recently viewed guilds fresh without hammering Battle.net. Every 10 minutes, at most
 * 3 guilds viewed during the last 14 days are re-synchronised when their roster is older than
 * 30 minutes or they still have never-synced profiles. Each pass refreshes at most
 * DETAIL_BATCH profiles per guild, so 1000-member guilds fill in gradually.
 */
export function startScheduler(deps: AppDeps, intervalMs = 10 * 60_000) {
  let running = false;
  const tick = async () => {
    if (running) return;
    running = true;
    try {
      const now = deps.now().getTime();
      const due = await deps.db
        .select({ region: guilds.region, slug: guilds.slug })
        .from(guilds)
        .where(
          and(
            isNotNull(guilds.lastViewedAt),
            gte(guilds.lastViewedAt, new Date(now - 14 * 86_400_000)),
            or(
              isNull(guilds.lastSyncedAt),
              lt(guilds.lastSyncedAt, new Date(now - ROSTER_STALE_MS)),
              sql`exists (select 1 from characters c where c.guild_id = ${guilds.id} and c.detail_synced_at is null)`,
            ),
          ),
        )
        .orderBy(asc(guilds.lastSyncedAt))
        .limit(3);
      for (const g of due) {
        await deps.sync
          .syncGuild(g.region as Region, g.slug, { trigger: 'SCHEDULE', details: 'stale', awaitDetails: true })
          .catch((err) => deps.log.warn('scheduled sync failed', { slug: g.slug, err: String(err) }));
      }
    } finally {
      running = false;
    }
  };
  const timer = setInterval(() => void tick(), intervalMs);
  timer.unref();
  return () => clearInterval(timer);
}
