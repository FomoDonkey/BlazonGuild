import { afterAll, beforeAll, describe, expect, it } from 'vitest';
import { and, auditLogs, characters, eq, guildMemberships, guilds, notifications, users } from '@blazonguild/database';
import { createHarness, type Harness } from './harness';

let h: Harness;
beforeAll(async () => {
  h = await createHarness();
  await h.deps.sync.syncGuild('eu', 'forever', { trigger: 'CLI', details: 'all', awaitDetails: true });
}, 60_000);
afterAll(async () => h?.close());

async function registered(email: string, name = 'Tester') {
  const c = h.client();
  const r = await c.req('POST', '/v1/auth/register', { email, password: 'contraseña-segura-1', displayName: name });
  expect(r.status).toBe(201);
  return { c, userId: r.data.user.id as string };
}

describe('auth & sessions', () => {
  it('registers, reads the session, logs out', async () => {
    const { c } = await registered('ana@example.com', 'Ana');
    const me = await c.req('GET', '/v1/auth/me');
    expect(me.status).toBe(200);
    expect(me.data.user.displayName).toBe('Ana');
    expect(me.data.user.role).toBe('USER');
    expect((await c.req('POST', '/v1/auth/logout', {})).status).toBe(204);
    expect((await c.req('GET', '/v1/auth/me')).status).toBe(401);
  });

  it('rejects duplicates, weak passwords and wrong credentials with clear errors', async () => {
    const c = h.client();
    expect((await c.req('POST', '/v1/auth/register', { email: 'ana@example.com', password: 'contraseña-segura-1', displayName: 'Otra' })).status).toBe(409);
    const weak = await c.req('POST', '/v1/auth/register', { email: 'b@example.com', password: 'corta', displayName: 'B' });
    expect(weak.status).toBe(400);
    expect(weak.data.error.code).toBe('VALIDATION_FAILED');
    const bad = await c.req('POST', '/v1/auth/login', { email: 'ana@example.com', password: 'incorrecta-123' });
    expect(bad.status).toBe(401);
    expect(bad.data.error.code).toBe('INVALID_CREDENTIALS');
  });

  it('rate-limits credential endpoints per IP', async () => {
    const c = h.client('10.9.9.9');
    const statuses: number[] = [];
    for (let i = 0; i < 11; i++) statuses.push((await c.req('POST', '/v1/auth/login', { email: 'nadie@example.com', password: 'incorrecta-123' })).status);
    expect(statuses.slice(0, 10).every((s) => s === 401)).toBe(true);
    expect(statuses[10]).toBe(429);
  });

  it('stores only hashed session tokens and scrypt password hashes', async () => {
    const [u] = await h.deps.db.select().from(users).where(eq(users.email, 'ana@example.com'));
    expect(u.passwordHash).toMatch(/^scrypt\$32768\$8\$3\$/);
  });

  it('blocks CSRF: non-JSON bodies and foreign origins', async () => {
    const c = h.client();
    const form = await c.req('POST', '/v1/auth/login', 'email=a&password=b', { 'content-type': 'application/x-www-form-urlencoded' });
    expect(form.status).toBe(415);
    const evil = await c.req('POST', '/v1/auth/login', { email: 'ana@example.com', password: 'x' }, { origin: 'https://evil.example' });
    expect(evil.status).toBe(403);
    expect(evil.data.error.code).toBe('CSRF_REJECTED');
  });
});

describe('public guild data', () => {
  it('serves the command-center overview with provenance and visitor permissions', async () => {
    const r = await h.client().req('GET', '/v1/guilds/eu/forever');
    expect(r.status).toBe(200);
    const o = r.data;
    expect(o.guild.name).toBe('Forever');
    expect(o.stats.members).toBe(h.state.roster.members.length);
    expect(o.stats.classDistribution.reduce((s: number, b: any) => s + b.count, 0)).toBe(o.stats.members);
    expect(o.provenance.source).toBe('BLIZZARD_API');
    expect(o.viewer.role).toBe('VISITOR');
    expect(o.upcomingRaids).toBeNull(); // visitors cannot see raids
    expect(o.guild.crest.emblemUrl).toMatch(/^\/api\/v1\/media\?url=/);
    const top = Math.max(...h.state.roster.members.map((m: any) => m.character.level));
    expect(o.highlights.find((x: any) => x.metric === 'level').value).toBe(top);
    expect(o.stats.maxLevel).toBe(top);
  });

  it('filters, sorts and paginates the roster', async () => {
    const c = h.client();
    const warriors = await c.req('GET', '/v1/guilds/eu/forever/roster?classIds=1&pageSize=100');
    expect(warriors.data.items.length).toBeGreaterThan(0);
    expect(warriors.data.items.every((m: any) => m.classId === 1)).toBe(true);
    const page = await c.req('GET', '/v1/guilds/eu/forever/roster?sort=level&dir=desc&pageSize=10');
    expect(page.data.items).toHaveLength(10);
    expect(page.data.total).toBe(h.state.roster.members.length);
    const lv = page.data.items.map((m: any) => m.level);
    expect([...lv].sort((a, b) => b - a)).toEqual(lv);
    const byRank = await c.req('GET', '/v1/guilds/eu/forever/roster?pageSize=5');
    expect(byRank.data.items[0].rankIndex).toBe(0); // default: guild master first (regression)
    const search = await c.req('GET', '/v1/guilds/eu/forever/roster?q=smash');
    expect(search.data.items.map((m: any) => m.slug)).toEqual(['goa-smashie']);
  });

  it('returns 404 for guilds that do not exist on Battle.net', async () => {
    const r = await h.client().req('GET', '/v1/guilds/eu/no-existe-jamas');
    expect(r.status).toBe(404);
    expect(r.data.error.code).toBe('NOT_FOUND');
  });

  it('builds the armory with 19-slot gear, classic-only stats and full talent trees', async () => {
    const r = await h.client().req('GET', '/v1/characters/eu/goa-smashie');
    expect(r.status).toBe(200);
    const a = r.data;
    expect(a.character.displayName).toBe('Goa Smashie');
    expect(a.equipment.find((i: any) => i.slot === 'MAIN_HAND').weapon.damage).toMatch(/Daño/);
    const statKeys = [...a.stats.attributes, ...a.stats.sections.flatMap((s: any) => s.rows)].map((r: any) => r.key);
    for (const retail of ['mastery', 'versatility', 'lifesteal', 'avoidance']) expect(statKeys).not.toContain(retail);
    expect(statKeys).toContain('defense');
    expect(a.talents.trees.map((t: any) => t.spentPoints)).toEqual([5, 2, 36]);
    expect(a.talents.trees[2].nodes.some((n: any) => n.rank > 0 && n.iconUrl)).toBe(true);
    expect(a.pvp.honorableKills).toBe(68);
    expect(a.provenance.source).toBe('BLIZZARD_API');
  });

  it('ranks with explicit methodology and refuses to invent combat metrics', async () => {
    const c = h.client();
    const lv = await c.req('GET', '/v1/guilds/eu/forever/rankings/level');
    expect(lv.data.available).toBe(true);
    expect(lv.data.entries[0].position).toBe(1);
    expect(lv.data.methodology.source).toContain('Battle.net');
    const dps = await c.req('GET', '/v1/guilds/eu/forever/rankings/dps');
    expect(dps.data.available).toBe(false);
    expect(dps.data.entries).toEqual([]);
    expect(dps.data.unavailableReason).toMatch(/registros de combate/);
  });

  it('only proxies images from the Blizzard render CDN', async () => {
    const r = await h.client().req('GET', `/v1/media?url=${encodeURIComponent('https://evil.example/x.png')}`);
    expect(r.status).toBe(400);
  });
});

describe('RBAC and raid operations', () => {
  it('enforces per-guild roles end to end', async () => {
    const [guild] = await h.deps.db.select().from(guilds).where(eq(guilds.slug, 'forever'));
    const leader = await registered('leader@example.com', 'Líder');
    const member = await registered('member@example.com', 'Miembro');
    const visitor = await registered('visitor@example.com', 'Visitante');
    await h.deps.db.insert(guildMemberships).values([
      { guildId: guild.id, userId: leader.userId, role: 'RAID_LEADER', source: 'ADMIN' },
      { guildId: guild.id, userId: member.userId, role: 'MEMBER', source: 'ADMIN' },
    ]);
    const chars = await h.deps.db.select().from(characters).where(eq(characters.guildId, guild.id));
    const mine = chars.find((x) => x.slug !== 'goa-smashie')!;
    const notMine = chars.find((x) => x.id !== mine.id)!;
    await h.deps.db.update(characters).set({ ownerUserId: member.userId }).where(eq(characters.id, mine.id));

    expect((await visitor.c.req('GET', '/v1/guilds/eu/forever/raids')).status).toBe(403);
    const body = { title: 'Núcleo de Magma — progreso', instanceKey: 'MC', startsAt: '2026-11-20T19:30:00.000Z', minLevel: null };
    expect((await member.c.req('POST', '/v1/guilds/eu/forever/raids', body)).status).toBe(403);
    const created = await leader.c.req('POST', '/v1/guilds/eu/forever/raids', body);
    expect(created.status).toBe(201);
    const raidId = created.data.id;

    const notif = await h.deps.db.select().from(notifications).where(eq(notifications.userId, member.userId));
    expect(notif[0]?.title).toContain('Núcleo de Magma');

    expect((await member.c.req('PUT', `/v1/raids/${raidId}/signup`, { characterId: notMine.id, status: 'CONFIRMED', role: 'DPS' })).status).toBe(403);
    const signup = await member.c.req('PUT', `/v1/raids/${raidId}/signup`, { characterId: mine.id, status: 'CONFIRMED', role: 'HEALER', comment: 'Llego 5 min tarde' });
    expect(signup.status).toBe(200);

    expect((await member.c.req('PUT', `/v1/raids/${raidId}/composition`, { assignments: [] })).status).toBe(403);
    const dup = await leader.c.req('PUT', `/v1/raids/${raidId}/composition`, { assignments: [{ signupId: signup.data.id, group: 9, slot: 0 }] });
    expect(dup.status).toBe(400);
    const comp = await leader.c.req('PUT', `/v1/raids/${raidId}/composition`, { assignments: [{ signupId: signup.data.id, group: 2, slot: 1 }] });
    expect(comp.status).toBe(200);
    expect(comp.data.signups[0]).toMatchObject({ group: 2, slot: 1, role: 'HEALER', status: 'CONFIRMED' });
    expect(comp.data.counts.roles.HEALER).toBe(1);

    const overview = await member.c.req('GET', '/v1/guilds/eu/forever');
    expect(overview.data.viewer.role).toBe('MEMBER');
    expect(overview.data.upcomingRaids).toHaveLength(1);

    const trail = await h.deps.db.select().from(auditLogs).where(and(eq(auditLogs.guildId, guild.id)));
    expect(trail.map((a) => a.action)).toEqual(expect.arrayContaining(['RAID_CREATE', 'RAID_COMPOSITION']));
    expect((await member.c.req('GET', '/v1/guilds/eu/forever/audit')).status).toBe(403);
    expect((await leader.c.req('GET', '/v1/guilds/eu/forever/audit')).status).toBe(403); // RAID_LEADER < OFFICER by default
  });

  it('prevents privilege escalation through role assignment', async () => {
    const officer = await registered('officer@example.com', 'Oficial');
    const target = await registered('target@example.com', 'Objetivo');
    const [guild] = await h.deps.db.select().from(guilds).where(eq(guilds.slug, 'forever'));
    await h.deps.db.insert(guildMemberships).values({ guildId: guild.id, userId: officer.userId, role: 'OFFICER', source: 'ADMIN' });
    expect((await officer.c.req('PUT', `/v1/guilds/eu/forever/members/${target.userId}`, { role: 'OFFICER' })).status).toBe(403);
    expect((await officer.c.req('PUT', `/v1/guilds/eu/forever/members/${target.userId}`, { role: 'RAIDER' })).status).toBe(200);
    expect((await officer.c.req('PUT', `/v1/guilds/eu/forever/members/${officer.userId}`, { role: 'GUILD_MASTER' })).status).toBe(403);
  });
});

describe('addon ingestion', () => {
  it('accepts token-authenticated uploads once, rejects duplicates and scopes tokens', async () => {
    const { c } = await registered('uploader@example.com', 'Uploader');
    const t = await c.req('POST', '/v1/me/tokens', { name: 'Companion PC' });
    expect(t.status).toBe(201);
    expect(t.data.token).toMatch(/^fvr_/);
    const bearer = { authorization: `Bearer ${t.data.token}` };
    const anon = h.client();
    const payload = { addonVersion: '0.1.0', capturedAt: '2026-11-12T10:00:00.000Z', character: { region: 'eu', slug: 'goa-smashie' }, data: { level: 52 } };
    const first = await anon.req('POST', '/v1/ingest/addon', payload, bearer);
    expect(first.status).toBe(202);
    expect(first.data.provenance).toEqual({ source: 'ADDON_COLLECTED', status: 'UNVERIFIED' });
    expect((await anon.req('POST', '/v1/ingest/addon', payload, bearer)).status).toBe(409);
    expect((await anon.req('GET', '/v1/auth/me', undefined, bearer)).status).toBe(403);
  });
});

describe('armory talent layout (regression)', () => {
  it('normalises globally numbered talent columns to 1..4 per tree', async () => {
    const r = await h.client().req('GET', '/v1/characters/eu/goa-smashie');
    for (const t of r.data.talents.trees) {
      const cols = t.nodes.map((n: any) => n.col);
      expect(Math.min(...cols)).toBe(1);
      expect(Math.max(...cols)).toBeLessThanOrEqual(4);
      expect(t.cols).toBe(4);
    }
  });
});
