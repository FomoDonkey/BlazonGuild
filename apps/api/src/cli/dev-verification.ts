/**
 * DEVELOPMENT-ONLY verification fixture for visual QA of the Raid Center.
 *   seed  → creates clearly-marked test users (verif-*@forever.invalid), links them to real
 *           characters of a guild WITHOUT verification, and a "[Prueba de verificación]" raid.
 *   clean → removes every record created by `seed` and restores character ownership.
 * Refuses to run against production.
 * Usage: npx tsx --env-file=../../.env src/cli/dev-verification.ts <seed|clean> [guild-slug]
 */
import { and, characters, eq, guildMemberships, guilds, ilike, inArray, isNull, raidSignups, raids, users } from '@blazonguild/database';
import { createDeps } from '../deps';
import { loadEnv } from '../env';
import { hashPassword } from '../lib/crypto';

const [mode, guildSlug = 'c-a-ñ-a-d-a'] = process.argv.slice(2);
const env = loadEnv();
if (env.NODE_ENV === 'production') throw new Error('dev-verification no se ejecuta en producción');
const { deps, close } = await createDeps({ ...env, DISABLE_SCHEDULER: true });
const { db } = deps;
const PREFIX = 'verif-';
const DOMAIN = '@forever.invalid';
const RAID_TITLE = '[Prueba de verificación] Núcleo de Magma';

async function clean() {
  const testUsers = await db.select({ id: users.id }).from(users).where(ilike(users.email, `${PREFIX}%${DOMAIN}`));
  const ids = testUsers.map((u) => u.id);
  if (ids.length) {
    await db.update(characters).set({ ownerUserId: null, ownershipVerified: false, isMain: false }).where(inArray(characters.ownerUserId, ids));
  }
  await db.delete(raids).where(eq(raids.title, RAID_TITLE));
  if (ids.length) await db.delete(users).where(inArray(users.id, ids)); // cascades sessions, memberships, signups, notifications
  console.log(`Limpieza: ${ids.length} usuarios de prueba y su raid eliminados`);
}

async function seed() {
  await clean();
  const [guild] = await db.select().from(guilds).where(eq(guilds.slug, guildSlug));
  if (!guild) throw new Error(`Sincroniza antes la hermandad ${guildSlug}`);
  // Never touch characters that already belong to a real account (e.g. Peregrino's own verified character).
  const roster = (await db.select().from(characters).where(and(eq(characters.guildId, guild.id), eq(characters.detailState, 'OK'), isNull(characters.ownerUserId)))).sort((a, b) => b.level - a.level);
  const password = await hashPassword('verificacion-local-123');
  const [leader] = await db.insert(users).values({ email: `${PREFIX}lider${DOMAIN}`, displayName: 'Líder (prueba)', passwordHash: password }).returning();
  await db.insert(guildMemberships).values({ guildId: guild.id, userId: leader.id, role: 'RAID_LEADER', source: 'ADMIN' });
  const [gm] = await db.insert(users).values({ email: `${PREFIX}gm${DOMAIN}`, displayName: 'Maestro (prueba)', passwordHash: password }).returning();
  await db.insert(guildMemberships).values({ guildId: guild.id, userId: gm.id, role: 'GUILD_MASTER', source: 'ADMIN' });
  const [raid] = await db
    .insert(raids)
    .values({ guildId: guild.id, title: RAID_TITLE, instanceKey: 'MC', startsAt: new Date(Date.now() + 3 * 86_400_000), capacity: 40, leaderUserId: leader.id, createdByUserId: leader.id, notes: 'Registro de prueba para verificar la interfaz. Se elimina con `dev-verification clean`.' })
    .returning();
  const picks = roster.slice(0, 16);
  let i = 0;
  for (const c of picks) {
    const [u] = await db.insert(users).values({ email: `${PREFIX}${i}${DOMAIN}`, displayName: `Prueba ${i}`, passwordHash: password }).returning();
    await db.insert(guildMemberships).values({ guildId: guild.id, userId: u.id, role: 'MEMBER', source: 'ADMIN' });
    await db.update(characters).set({ ownerUserId: u.id, ownershipVerified: false }).where(eq(characters.id, c.id));
    const role = c.primarySpecId && [257, 267, 134].includes(c.primarySpecId) ? 'TANK' : c.primarySpecId && [594, 613, 56, 374, 573].includes(c.primarySpecId) ? 'HEALER' : 'DPS';
    const status = i % 7 === 6 ? 'DECLINED' : i % 5 === 4 ? 'TENTATIVE' : 'CONFIRMED';
    const placed = status === 'CONFIRMED' && i < 9;
    await db.insert(raidSignups).values({ raidId: raid.id, userId: u.id, characterId: c.id, status, role, groupNo: placed ? Math.floor(i / 5) + 1 : null, slot: placed ? i % 5 : null, comment: i === 2 ? 'Llego 10 minutos tarde' : null });
    i++;
  }
  console.log(JSON.stringify({ raidId: raid.id, gmEmail: gm.email, leaderEmail: leader.email, password: 'verificacion-local-123', signups: picks.length }));
}

if (mode === 'seed') await seed();
else if (mode === 'clean') await clean();
else console.error('Uso: dev-verification.ts <seed|clean> [guild-slug]');
await close();
