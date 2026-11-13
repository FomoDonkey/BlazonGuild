import {
  and,
  asc,
  characters,
  desc,
  eq,
  gte,
  guildMemberships,
  guilds,
  inArray,
  lt,
  ne,
  notifications,
  raidSignups,
  raids,
  users,
} from '@blazonguild/database';
import {
  RAID_INSTANCES,
  type CombatRole,
  type RaidDetailDTO,
  type RaidInstanceKey,
  type RaidSignupDTO,
  type RaidSummaryDTO,
  type Region,
  type SignupStatus,
  type ViewerContextDTO,
} from '@blazonguild/types';
import type { AppDeps } from '../context';
import { audit } from '../lib/audit';
import { badRequest, conflict, forbidden, notFound } from '../lib/errors';
import { displayName } from './mappers';

type GuildRow = typeof guilds.$inferSelect;
type RaidRow = typeof raids.$inferSelect;

const instanceName = (key: string) => RAID_INSTANCES.find((i) => i.key === key)?.nameEs ?? key;

async function summarise(deps: AppDeps, guild: GuildRow, rows: RaidRow[], userId: string | null): Promise<RaidSummaryDTO[]> {
  if (!rows.length) return [];
  const ids = rows.map((r) => r.id);
  const signups = await deps.db
    .select({ s: raidSignups, slug: characters.slug })
    .from(raidSignups)
    .innerJoin(characters, eq(characters.id, raidSignups.characterId))
    .where(inArray(raidSignups.raidId, ids));
  const leaderIds = rows.map((r) => r.leaderUserId).filter((x): x is string => !!x);
  const leaders = leaderIds.length ? await deps.db.select({ id: users.id, name: users.displayName }).from(users).where(inArray(users.id, leaderIds)) : [];
  return rows.map((r) => {
    const mine = signups.filter((x) => x.s.raidId === r.id);
    const roles: Record<CombatRole, number> = { TANK: 0, HEALER: 0, DPS: 0 };
    for (const x of mine) if (x.s.status === 'CONFIRMED') roles[x.s.role]++;
    const viewer = userId ? mine.find((x) => x.s.userId === userId) : undefined;
    return {
      id: r.id,
      guild: { region: guild.region as Region, slug: guild.slug, name: guild.name },
      title: r.title,
      instanceKey: r.instanceKey as RaidInstanceKey,
      instanceName: instanceName(r.instanceKey),
      startsAt: r.startsAt.toISOString(),
      endsAt: r.endsAt?.toISOString() ?? null,
      status: r.status,
      capacity: r.capacity,
      minLevel: r.minLevel,
      leader: leaders.find((l) => l.id === r.leaderUserId)?.name ?? null,
      counts: {
        confirmed: mine.filter((x) => x.s.status === 'CONFIRMED').length,
        tentative: mine.filter((x) => x.s.status === 'TENTATIVE').length,
        declined: mine.filter((x) => x.s.status === 'DECLINED').length,
        benched: mine.filter((x) => x.s.status === 'BENCHED').length,
        roles,
      },
      viewerSignup: viewer ? { status: viewer.s.status, characterSlug: viewer.slug } : null,
    };
  });
}

export async function listRaids(deps: AppDeps, guild: GuildRow, opts: { scope: 'upcoming' | 'past' | 'all'; userId: string | null; limit?: number }) {
  const horizon = new Date(deps.now().getTime() - 6 * 3600 * 1000);
  const where = [eq(raids.guildId, guild.id)];
  if (opts.scope === 'upcoming') where.push(gte(raids.startsAt, horizon), ne(raids.status, 'CANCELLED'));
  if (opts.scope === 'past') where.push(lt(raids.startsAt, horizon));
  const rows = await deps.db
    .select()
    .from(raids)
    .where(and(...where))
    .orderBy(opts.scope === 'past' ? desc(raids.startsAt) : asc(raids.startsAt))
    .limit(opts.limit ?? 50);
  return summarise(deps, guild, rows, opts.userId);
}

export async function getRaid(deps: AppDeps, raidId: string) {
  const rows = await deps.db.select({ raid: raids, guild: guilds }).from(raids).innerJoin(guilds, eq(guilds.id, raids.guildId)).where(eq(raids.id, raidId)).limit(1);
  if (!rows[0]) throw notFound('Raid no encontrada');
  return rows[0];
}

/** Characters of `userId` that are in this guild and linked to the account. */
export async function eligibleCharacters(deps: AppDeps, guildId: string, userId: string | null) {
  if (!userId) return [];
  return deps.db
    .select()
    .from(characters)
    .where(and(eq(characters.guildId, guildId), eq(characters.ownerUserId, userId)))
    .orderBy(desc(characters.isMain), desc(characters.level));
}

export async function raidDetail(deps: AppDeps, guild: GuildRow, raid: RaidRow, userId: string | null, viewer: ViewerContextDTO): Promise<RaidDetailDTO> {
  const [summary] = await summarise(deps, guild, [raid], userId);
  const rows = await deps.db
    .select({ s: raidSignups, c: characters, u: { displayName: users.displayName } })
    .from(raidSignups)
    .innerJoin(characters, eq(characters.id, raidSignups.characterId))
    .innerJoin(users, eq(users.id, raidSignups.userId))
    .where(eq(raidSignups.raidId, raid.id))
    .orderBy(asc(raidSignups.signedUpAt));
  const signups: RaidSignupDTO[] = rows.map(({ s, c, u }) => ({
    id: s.id,
    character: { id: c.id, slug: c.slug, displayName: displayName(c), classId: c.classId, level: c.level, itemLevel: c.equippedItemLevel },
    userDisplayName: u.displayName,
    status: s.status,
    role: s.role,
    comment: s.comment,
    group: s.groupNo,
    slot: s.slot,
    signedUpAt: s.signedUpAt.toISOString(),
    isViewer: s.userId === userId,
  }));
  const own = await eligibleCharacters(deps, guild.id, userId);
  return {
    ...summary,
    notes: raid.notes,
    signups,
    viewer: { ...viewer, characters: own.map((c) => ({ id: c.id, slug: c.slug, displayName: displayName(c), classId: c.classId, level: c.level })) },
    createdAt: raid.createdAt.toISOString(),
    updatedAt: raid.updatedAt.toISOString(),
  };
}

export interface RaidInput {
  title: string;
  instanceKey: RaidInstanceKey;
  startsAt: string;
  endsAt?: string | null;
  capacity?: number;
  minLevel?: number | null;
  notes?: string | null;
}

function validateTimes(startsAt: Date, endsAt: Date | null) {
  if (Number.isNaN(startsAt.getTime())) throw badRequest('Fecha de inicio no válida');
  if (endsAt && endsAt <= startsAt) throw badRequest('La hora de fin debe ser posterior al inicio');
}

export async function createRaid(deps: AppDeps, guild: GuildRow, userId: string, input: RaidInput, meta: { ip: string; ua?: string }) {
  const startsAt = new Date(input.startsAt);
  const endsAt = input.endsAt ? new Date(input.endsAt) : null;
  validateTimes(startsAt, endsAt);
  const size = RAID_INSTANCES.find((i) => i.key === input.instanceKey)?.size ?? 40;
  const [raid] = await deps.db
    .insert(raids)
    .values({
      guildId: guild.id,
      title: input.title.trim(),
      instanceKey: input.instanceKey,
      startsAt,
      endsAt,
      capacity: input.capacity ?? size,
      minLevel: input.minLevel ?? null,
      notes: input.notes?.trim() || null,
      leaderUserId: userId,
      createdByUserId: userId,
    })
    .returning();
  await audit(deps.db, { actorUserId: userId, guildId: guild.id, action: 'RAID_CREATE', entity: 'raid', entityId: raid.id, changes: { after: raid }, ip: meta.ip, userAgent: meta.ua });

  // Notify every platform member of the guild except the creator.
  const members = await deps.db.select({ userId: guildMemberships.userId }).from(guildMemberships).where(eq(guildMemberships.guildId, guild.id));
  const targets = members.filter((m) => m.userId !== userId);
  if (targets.length) {
    await deps.db.insert(notifications).values(
      targets.map((m) => ({
        userId: m.userId,
        guildId: guild.id,
        type: 'RAID_SCHEDULED',
        title: `Nueva raid: ${raid.title}`,
        body: `${instanceName(raid.instanceKey)} · ${raid.startsAt.toISOString()}`,
        link: `/g/${guild.region}/${guild.slug}/raids/${raid.id}`,
      })),
    );
  }
  return raid;
}

export async function updateRaid(deps: AppDeps, raid: RaidRow, userId: string, patch: Partial<RaidInput> & { status?: RaidRow['status'] }, meta: { ip: string; ua?: string }) {
  const startsAt = patch.startsAt ? new Date(patch.startsAt) : raid.startsAt;
  const endsAt = patch.endsAt === undefined ? raid.endsAt : patch.endsAt ? new Date(patch.endsAt) : null;
  validateTimes(startsAt, endsAt);
  const [after] = await deps.db
    .update(raids)
    .set({
      title: patch.title?.trim() ?? raid.title,
      instanceKey: patch.instanceKey ?? raid.instanceKey,
      startsAt,
      endsAt,
      capacity: patch.capacity ?? raid.capacity,
      minLevel: patch.minLevel === undefined ? raid.minLevel : patch.minLevel,
      notes: patch.notes === undefined ? raid.notes : patch.notes?.trim() || null,
      status: patch.status ?? raid.status,
    })
    .where(eq(raids.id, raid.id))
    .returning();
  await audit(deps.db, { actorUserId: userId, guildId: raid.guildId, action: 'RAID_UPDATE', entity: 'raid', entityId: raid.id, changes: { before: raid, after }, ip: meta.ip, userAgent: meta.ua });
  return after;
}

export async function upsertSignup(
  deps: AppDeps,
  raid: RaidRow,
  userId: string,
  input: { characterId: string; status: Exclude<SignupStatus, 'BENCHED'>; role: CombatRole; comment?: string | null },
) {
  if (raid.status === 'CANCELLED' || raid.status === 'COMPLETED') throw conflict('La raid ya no admite inscripciones');
  const own = await eligibleCharacters(deps, raid.guildId, userId);
  const character = own.find((c) => c.id === input.characterId);
  if (!character) throw forbidden('Solo puedes inscribir personajes vinculados a tu cuenta que estén en esta hermandad');
  if (raid.minLevel && character.level < raid.minLevel) throw badRequest(`Esta raid exige nivel ${raid.minLevel}`);
  const comment = input.comment?.trim().slice(0, 280) || null;

  const existing = (await deps.db.select().from(raidSignups).where(and(eq(raidSignups.raidId, raid.id), eq(raidSignups.userId, userId))).limit(1))[0];
  if (existing) {
    const changedCharacter = existing.characterId !== character.id;
    const [row] = await deps.db
      .update(raidSignups)
      .set({
        characterId: character.id,
        status: existing.status === 'BENCHED' && input.status === 'CONFIRMED' ? 'BENCHED' : input.status,
        role: input.role,
        comment,
        // Declining or swapping character frees the planner position.
        groupNo: input.status === 'DECLINED' || changedCharacter ? null : existing.groupNo,
        slot: input.status === 'DECLINED' || changedCharacter ? null : existing.slot,
      })
      .where(eq(raidSignups.id, existing.id))
      .returning();
    return row;
  }
  const [row] = await deps.db.insert(raidSignups).values({ raidId: raid.id, userId, characterId: character.id, status: input.status, role: input.role, comment }).returning();
  return row;
}

export async function withdrawSignup(deps: AppDeps, raid: RaidRow, userId: string) {
  await deps.db.delete(raidSignups).where(and(eq(raidSignups.raidId, raid.id), eq(raidSignups.userId, userId)));
}

export interface Assignment {
  signupId: string;
  group: number | null;
  slot: number | null;
  status?: SignupStatus;
  role?: CombatRole;
}

/** Atomically replaces the planner layout. Positions are validated for range and uniqueness. */
export async function applyComposition(deps: AppDeps, raid: RaidRow, actorId: string, assignments: Assignment[], meta: { ip: string; ua?: string }) {
  const groups = Math.ceil(raid.capacity / 5);
  const seen = new Set<string>();
  for (const a of assignments) {
    if ((a.group === null) !== (a.slot === null)) throw badRequest('Grupo y posición deben indicarse juntos');
    if (a.group !== null && a.slot !== null) {
      if (a.group < 1 || a.group > groups || a.slot < 0 || a.slot > 4) throw badRequest(`Posición fuera de rango (grupos 1–${groups}, posiciones 0–4)`);
      const key = `${a.group}:${a.slot}`;
      if (seen.has(key)) throw badRequest(`La posición ${key} está duplicada`);
      seen.add(key);
    }
  }
  const current = await deps.db.select().from(raidSignups).where(eq(raidSignups.raidId, raid.id));
  const byId = new Map(current.map((s) => [s.id, s]));
  for (const a of assignments) if (!byId.has(a.signupId)) throw badRequest('Inscripción desconocida en la composición');

  await deps.db.transaction(async (tx) => {
    const touched = assignments.map((a) => a.signupId);
    // Clear positions first so swaps never violate the unique (raid, group, slot) index.
    if (touched.length) await tx.update(raidSignups).set({ groupNo: null, slot: null }).where(inArray(raidSignups.id, touched));
    for (const a of assignments) {
      const before = byId.get(a.signupId)!;
      const status = a.status ?? (a.group !== null && before.status === 'BENCHED' ? 'CONFIRMED' : before.status);
      await tx
        .update(raidSignups)
        .set({ groupNo: a.group, slot: a.slot, status, role: a.role ?? before.role })
        .where(eq(raidSignups.id, a.signupId));
    }
  });
  await audit(deps.db, { actorUserId: actorId, guildId: raid.guildId, action: 'RAID_COMPOSITION', entity: 'raid', entityId: raid.id, changes: { assignments }, ip: meta.ip, userAgent: meta.ua });
}
