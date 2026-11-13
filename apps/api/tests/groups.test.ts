import { afterAll, beforeAll, describe, expect, it } from 'vitest';
import { characters, eq, guildMemberships, guilds } from '@blazonguild/database';
import { createHarness, type Harness } from './harness';

let h: Harness;
beforeAll(async () => {
  h = await createHarness();
  await h.deps.sync.syncGuild('eu', 'forever', { trigger: 'CLI', details: 'none', awaitDetails: true });
}, 60_000);
afterAll(async () => h?.close());

async function member(email: string, charIndex: number) {
  const c = h.client();
  const r = await c.req('POST', '/v1/auth/register', { email, password: 'contraseña-segura-1', displayName: email.split('@')[0] });
  const userId = r.data.user.id as string;
  const [g] = await h.deps.db.select().from(guilds).where(eq(guilds.slug, 'forever'));
  await h.deps.db.insert(guildMemberships).values({ guildId: g.id, userId, role: 'MEMBER', source: 'ADMIN' });
  const chars = (await h.deps.db.select().from(characters).where(eq(characters.guildId, g.id))).sort((a, b) => a.slug.localeCompare(b.slug));
  await h.deps.db.update(characters).set({ ownerUserId: userId }).where(eq(characters.id, chars[charIndex].id));
  return { c, userId, characterId: chars[charIndex].id };
}

describe('dungeon group finder', () => {
  it('creates, fills role slots, refuses foreign characters and closes', async () => {
    const leader = await member('lfg-leader@example.com', 0);
    const joiner = await member('lfg-joiner@example.com', 1);
    const other = await member('lfg-other@example.com', 2);
    expect((await h.client().req('GET', '/v1/guilds/eu/forever/groups')).status).toBe(401);

    const created = await leader.c.req('POST', '/v1/guilds/eu/forever/groups', { dungeonKey: 'SM', characterId: leader.characterId, role: 'TANK', note: 'Cementerio y biblioteca' });
    expect(created.status).toBe(201);
    const id = created.data.id;

    const list = await joiner.c.req('GET', '/v1/guilds/eu/forever/groups');
    expect(list.data.groups[0]).toMatchObject({ dungeon: { key: 'SM', name: 'Monasterio Escarlata' }, needs: { TANK: 0, HEALER: 1, DPS: 3 } });

    expect((await joiner.c.req('PUT', `/v1/groups/${id}/join`, { characterId: joiner.characterId, role: 'TANK' })).status).toBe(409);
    expect((await joiner.c.req('PUT', `/v1/groups/${id}/join`, { characterId: leader.characterId, role: 'HEALER' })).status).toBe(403);
    const joined = await joiner.c.req('PUT', `/v1/groups/${id}/join`, { characterId: joiner.characterId, role: 'HEALER' });
    expect(joined.status).toBe(200);
    expect(joined.data.needs).toEqual({ TANK: 0, HEALER: 0, DPS: 3 });
    expect((await joiner.c.req('PUT', `/v1/groups/${id}/join`, { characterId: joiner.characterId, role: 'DPS' })).status).toBe(409);

    expect((await other.c.req('POST', `/v1/groups/${id}/close`, {})).status).toBe(403);
    expect((await leader.c.req('POST', `/v1/groups/${id}/close`, {})).status).toBe(204);
    expect((await joiner.c.req('GET', '/v1/guilds/eu/forever/groups')).data.groups).toEqual([]);
  });
});
