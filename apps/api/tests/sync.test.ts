import { afterAll, beforeAll, describe, expect, it } from 'vitest';
import { activityEvents, characterEquipment, characterSnapshots, characters, eq, guilds } from '@blazonguild/database';
import { createHarness, type Harness } from './harness';

let h: Harness;
beforeAll(async () => {
  h = await createHarness();
  await h.deps.sync.syncGuild('eu', 'forever', { trigger: 'CLI', details: 'all', awaitDetails: true });
}, 60_000);
afterAll(async () => h?.close());

const gm = async () => (await h.deps.db.select().from(characters).where(eq(characters.slug, 'goa-smashie')))[0];
const events = async (type?: string) =>
  (await h.deps.db.select().from(activityEvents)).filter((e) => !type || e.type === type);

describe('guild sync (real Battle.net payloads)', () => {
  it('imports the guild with its crest and full roster', async () => {
    const [g] = await h.deps.db.select().from(guilds).where(eq(guilds.slug, 'forever'));
    expect(g.name).toBe('Forever');
    expect(g.faction).toBe('HORDE');
    expect(g.rulesetName).toBe('JcJ');
    expect(g.memberCount).toBe(h.state.roster.members.length);
    expect(g.crest?.emblemUrl).toBe('https://render.worldofwarcraft.com/eu/guild/tabards/emblem_98.png'); // forever-eu path normalised
    expect(g.syncState).toBe('OK');
    const chars = await h.deps.db.select().from(characters).where(eq(characters.guildId, g.id));
    expect(chars).toHaveLength(h.state.roster.members.length);
  });

  it('stores a provenance-stamped snapshot and curated columns for the GM', async () => {
    const c = await gm();
    expect(c.level).toBe(52);
    expect(c.guildRank).toBe(0);
    expect(c.talentSplit).toEqual([5, 2, 36]);
    expect(c.primarySpecId).toBe(257); // Protección
    expect(c.honorableKills).toBe(68);
    expect(c.professions?.find((p) => p.name === 'Mining')?.skill).toBe(283);
    const snaps = await h.deps.db.select().from(characterSnapshots).where(eq(characterSnapshots.characterId, c.id));
    expect(snaps).toHaveLength(1);
    expect(snaps[0].provenance.source).toBe('BLIZZARD_API');
    expect(snaps[0].checksum).toMatch(/^[a-f0-9]{64}$/);
    const gear = await h.deps.db.select().from(characterEquipment).where(eq(characterEquipment.characterId, c.id));
    expect(gear.length).toBe(h.state.gmEquipment.equipped_items.length);
  });

  it('records one GUILD_TRACKED event and real achievement events (no fabricated history)', async () => {
    expect(await events('GUILD_TRACKED')).toHaveLength(1);
    expect(await events('MEMBER_JOINED')).toHaveLength(0);
    const ach = await events('ACHIEVEMENT');
    expect(ach.length).toBeGreaterThan(0);
    expect(ach.every((e) => e.provenance.method === 'achievements-recent-events')).toBe(true);
  });

  it('is idempotent: an unchanged re-sync writes no snapshot and no events', async () => {
    const before = (await events()).length;
    await h.deps.sync.syncGuild('eu', 'forever', { trigger: 'CLI', details: 'all', awaitDetails: true });
    expect((await events()).length).toBe(before);
    const c = await gm();
    const snaps = await h.deps.db.select().from(characterSnapshots).where(eq(characterSnapshots.characterId, c.id));
    expect(snaps).toHaveLength(1);
  });

  it('derives joins, departures, promotions, level-ups and gear changes from diffs', async () => {
    const roster = h.state.roster;
    const leaving = roster.members.pop();
    roster.members.push({
      rank: 4,
      character: { id: 999001, name: 'Nueva', surname: 'Recluta', slug: 'nueva-recluta', level: 12, playable_class: { id: 8 }, playable_race: { id: 2 }, faction: { type: 'HORDE' } },
    });
    const leveller = roster.members.find((m: any) => m.character.slug !== 'goa-smashie' && m.rank === 4);
    leveller.character.level += 1;
    const promoted = roster.members.find((m: any) => m.rank === 4 && m !== leveller && m.character.slug !== 'nueva-recluta');
    promoted.rank = 3;
    const mh = h.state.gmEquipment.equipped_items.find((i: any) => i.slot.type === 'MAIN_HAND');
    mh.item.id = 19019;
    mh.name = 'Arma de prueba épica';
    mh.quality = { type: 'EPIC', name: 'Épico' };

    await h.deps.sync.syncGuild('eu', 'forever', { trigger: 'CLI', details: 'all', awaitDetails: true });

    expect((await events('MEMBER_JOINED')).map((e) => e.title)).toEqual(['Nueva Recluta se une a la hermandad']);
    expect((await events('MEMBER_LEFT'))[0].title).toContain(leaving.character.name);
    expect((await events('RANK_CHANGED'))).toHaveLength(1);
    expect((await events('LEVEL_UP'))[0].title).toContain(`nivel ${leveller.character.level}`);
    const item = await events('ITEM_EQUIPPED');
    expect(item).toHaveLength(1);
    expect(item[0].detail).toMatchObject({ itemId: 19019, quality: 'EPIC', slot: 'MAIN_HAND', replaced: 'Zumbaespada' });
    const left = (await h.deps.db.select().from(characters).where(eq(characters.slug, leaving.character.slug)))[0];
    expect(left.guildId).toBeNull();
  });

  it("survives real-world payload quirks: duplicate rings and null spell names (regression)", async () => {
    const eq0 = h.state.gmEquipment;
    const f1 = eq0.equipped_items.find((i: any) => i.slot.type === "FINGER_1");
    const f2 = eq0.equipped_items.find((i: any) => i.slot.type === "FINGER_2");
    f2.item.id = f1.item.id;
    f2.name = f1.name;
    f1.spells = [{ spell: { id: 1, name: null }, description: "Efecto sin nombre" }];
    const row = await h.deps.sync.syncCharacter("eu", "goa-smashie", { trigger: "CLI" });
    expect(row?.detailState).toBe("OK");
    expect(row?.detailError).toBeNull();
  });
});
