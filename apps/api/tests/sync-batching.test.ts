import { afterAll, beforeAll, describe, expect, it } from 'vitest';
import { characters, eq, guilds, syncJobs } from '@blazonguild/database';
import { createHarness, type Harness } from './harness';

let h: Harness;
beforeAll(async () => {
  h = await createHarness();
  h.deps.sync.detailBatch = 10;
}, 60_000);
afterAll(async () => h?.close());

const detailed = async () => {
  const [g] = await h.deps.db.select().from(guilds).where(eq(guilds.slug, 'forever'));
  const rows = await h.deps.db.select().from(characters).where(eq(characters.guildId, g.id));
  return rows.filter((c) => c.detailSyncedAt);
};

describe('progressive profile sync for big guilds', () => {
  it('syncs one batch per pass, highest levels first, and reports what remains', async () => {
    await h.deps.sync.syncGuild('eu', 'forever', { trigger: 'CLI', details: 'stale', awaitDetails: true });
    const first = await detailed();
    expect(first).toHaveLength(10);
    const topLevels = [...h.state.roster.members].map((m: any) => m.character.level).sort((a: number, b: number) => b - a).slice(0, 10);
    expect(Math.min(...first.map((c) => c.level))).toBeGreaterThanOrEqual(Math.min(...topLevels));
    const [job] = await h.deps.db.select().from(syncJobs).where(eq(syncJobs.kind, 'GUILD'));
    expect(job.stats.detailsRemaining).toBe(h.state.roster.members.length - 10);

    await h.deps.sync.syncGuild('eu', 'forever', { trigger: 'CLI', details: 'stale', awaitDetails: true });
    expect(await detailed()).toHaveLength(20);
  });
});
