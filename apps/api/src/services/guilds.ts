import {
  activityEvents,
  and,
  asc,
  characters,
  count,
  desc,
  eq,
  gte,
  guildMemberships,
  guilds,
  ilike,
  inArray,
  isNotNull,
  lte,
  or,
  raids,
  sql,
  type SQL,
} from '@blazonguild/database';
import {
  LEVEL_CAP,
  RAID_INSTANCES,
  blizzardProvenance,
  classById,
  specById,
  type DistributionBucket,
  type GuildHighlightDTO,
  type GuildOverviewDTO,
  type Page,
  type Region,
  type RosterMemberDTO,
  type RosterSortKey,
} from '@blazonguild/types';
import type { AppDeps } from '../context';
import type { GuildAccess } from '../auth/access';
import { notFound, upstream } from '../lib/errors';
import { toActivity, toGuildSummary, toRosterMember } from './mappers';
import { GuildNotFoundError, ROSTER_STALE_MS } from './sync';
import { BlizzardApiError } from '@blazonguild/data-providers';
import { listRaids } from './raids';

type GuildRow = typeof guilds.$inferSelect;

export async function findGuild(deps: AppDeps, region: Region, slug: string) {
  const rows = await deps.db.select().from(guilds).where(and(eq(guilds.region, region), eq(guilds.slug, slug.trim().toLowerCase()))).limit(1);
  return rows[0] ?? null;
}

/**
 * Public guild lookup: imports any WoW: Forever guild on first visit and refreshes stale
 * rosters in the background, so the platform works for every guild without manual setup.
 */
export async function getOrImportGuild(deps: AppDeps, region: Region, slug: string, userId: string | null): Promise<GuildRow> {
  let guild = await findGuild(deps, region, slug);
  if (!guild) {
    try {
      guild = await deps.sync.syncGuild(region, slug, { trigger: 'VIEW', userId, details: 'stale', awaitDetails: false });
    } catch (err) {
      if (err instanceof GuildNotFoundError) throw notFound(err.message);
      if (err instanceof BlizzardApiError) throw upstream('Battle.net no responde ahora mismo. Inténtalo de nuevo en unos minutos.');
      throw err;
    }
    return guild;
  }
  const now = deps.now().getTime();
  const stale = !guild.lastSyncedAt || now - guild.lastSyncedAt.getTime() > ROSTER_STALE_MS;
  if (stale && !deps.sync.isRunning(region, slug)) {
    void deps.sync.syncGuild(region, slug, { trigger: 'VIEW', details: 'stale' }).catch((err) => deps.log.warn('background guild refresh failed', { slug, err: String(err) }));
  }
  if (!guild.lastViewedAt || now - guild.lastViewedAt.getTime() > 5 * 60_000) {
    await deps.db.update(guilds).set({ lastViewedAt: deps.now() }).where(eq(guilds.id, guild.id));
  }
  return guild;
}

export async function platformMemberCount(deps: AppDeps, guildId: string) {
  const [r] = await deps.db.select({ n: count() }).from(guildMemberships).where(eq(guildMemberships.guildId, guildId));
  return Number(r?.n ?? 0);
}

const median = (xs: number[]) => {
  if (!xs.length) return null;
  const s = [...xs].sort((a, b) => a - b);
  const m = Math.floor(s.length / 2);
  return s.length % 2 ? s[m] : Math.round((s[m - 1] + s[m]) / 2);
};

export async function buildOverview(deps: AppDeps, guild: GuildRow, access: GuildAccess): Promise<GuildOverviewDTO> {
  const members = await deps.db.select().from(characters).where(eq(characters.guildId, guild.id));
  const rankNames = guild.settings?.rankNames ?? {};
  const levels = members.map((m) => m.level);
  const detailed = members.filter((m) => m.detailState === 'OK');
  const now = deps.now().getTime();
  const activeWithin = (days: number) => detailed.filter((m) => m.lastLoginAt && now - m.lastLoginAt.getTime() <= days * 86_400_000).length;
  const ilvls = detailed.map((m) => m.equippedItemLevel).filter((v): v is number => typeof v === 'number' && v > 0);

  const classDistribution: DistributionBucket[] = [...new Set(members.map((m) => m.classId))]
    .map((id) => ({ key: String(id), label: classById(id)?.nameEs ?? `Clase ${id}`, count: members.filter((m) => m.classId === id).length }))
    .sort((a, b) => b.count - a.count);
  const bands = [[1, 9], [10, 19], [20, 29], [30, 39], [40, 49], [50, 59], [60, 60]] as const;
  const levelDistribution: DistributionBucket[] = bands.map(([from, to]) => ({
    key: `${from}-${to}`,
    label: from === to ? `${from}` : `${from}–${to}`,
    count: members.filter((m) => m.level >= from && m.level <= to).length,
  }));
  const rankDistribution: DistributionBucket[] = [...new Set(members.map((m) => m.guildRank ?? -1))]
    .sort((a, b) => a - b)
    .map((r) => ({ key: String(r), label: rankNames[String(r)] ?? (r === 0 ? 'Maestro (rango 0)' : `Rango ${r}`), count: members.filter((m) => (m.guildRank ?? -1) === r).length }));

  const highlight = (metric: string, label: string, unit: string, pick: (m: (typeof members)[number]) => number | null): GuildHighlightDTO | null => {
    let best: (typeof members)[number] | null = null;
    let bestValue = -Infinity;
    for (const m of members) {
      const v = pick(m);
      if (v !== null && v > bestValue) {
        best = m;
        bestValue = v;
      }
    }
    if (!best || bestValue <= 0) return null;
    return { metric, label, unit, value: bestValue, member: toRosterMember(best, rankNames), provenance: blizzardProvenance(best.detailSyncedAt ?? best.rosterSeenAt) };
  };
  const highlights = [
    highlight('level', 'Nivel más alto', 'nivel', (m) => m.level),
    highlight('item_level', 'Mayor nivel de objeto', 'iLvl', (m) => m.equippedItemLevel),
    highlight('honorable_kills', 'Más muertes con honor', 'MCH', (m) => m.honorableKills),
    highlight('profession_skill', 'Profesión más avanzada', 'puntos', (m) => Math.max(0, ...(m.professions ?? []).filter((p) => p.kind === 'primary').map((p) => p.skill))),
  ].filter((h): h is GuildHighlightDTO => h !== null);

  const lineup = members
    .filter((m) => m.renderUrl)
    .sort((a, b) => (a.guildRank ?? 99) - (b.guildRank ?? 99) || b.level - a.level || a.name.localeCompare(b.name))
    .slice(0, 5)
    .map((m) => toRosterMember(m, rankNames));

  const recent = await deps.db
    .select({ e: activityEvents, c: { region: characters.region, slug: characters.slug, name: characters.name, surname: characters.surname, classId: characters.classId } })
    .from(activityEvents)
    .leftJoin(characters, eq(characters.id, activityEvents.characterId))
    .where(eq(activityEvents.guildId, guild.id))
    .orderBy(desc(activityEvents.occurredAt))
    .limit(14);

  const upcomingRaids = access.can('raids.view') ? (await listRaids(deps, guild, { scope: 'upcoming', userId: null, limit: 3 })) : null;

  return {
    guild: toGuildSummary(guild, await platformMemberCount(deps, guild.id)),
    viewer: access.viewer,
    stats: {
      members: members.length,
      averageLevel: levels.length ? Math.round((levels.reduce((a, b) => a + b, 0) / levels.length) * 10) / 10 : null,
      medianLevel: median(levels),
      maxLevel: levels.length ? Math.max(...levels) : null,
      atLevelCap: members.filter((m) => m.level >= LEVEL_CAP).length,
      detailedMembers: detailed.length,
      activeLast7d: detailed.length ? activeWithin(7) : null,
      activeLast30d: detailed.length ? activeWithin(30) : null,
      averageItemLevel: ilvls.length ? Math.round((ilvls.reduce((a, b) => a + b, 0) / ilvls.length) * 10) / 10 : null,
      classDistribution,
      levelDistribution,
      rankDistribution,
    },
    highlights,
    lineup,
    recentActivity: recent.map((r) => toActivity(r.e, r.c?.slug ? r.c : null)),
    upcomingRaids,
    provenance: blizzardProvenance(guild.lastSyncedAt, { namespace: `profile-forever-${guild.region}`, endpoint: `/data/wow/guild/${guild.slug}/roster` }),
  };
}

export interface RosterQuery {
  q?: string;
  classIds?: number[];
  ranks?: number[];
  role?: 'TANK' | 'HEALER' | 'DPS';
  minLevel?: number;
  maxLevel?: number;
  activeDays?: number;
  sort?: RosterSortKey;
  dir?: 'asc' | 'desc';
  page: number;
  pageSize: number;
  offset: number;
}

export async function queryRoster(deps: AppDeps, guild: GuildRow, q: RosterQuery): Promise<Page<RosterMemberDTO>> {
  const where: SQL[] = [eq(characters.guildId, guild.id)];
  if (q.q) {
    const like = `%${q.q.replace(/[%_]/g, '')}%`;
    where.push(or(ilike(characters.name, like), ilike(characters.surname, like), ilike(characters.slug, like))!);
  }
  if (q.classIds?.length) where.push(inArray(characters.classId, q.classIds));
  if (q.ranks?.length) where.push(inArray(characters.guildRank, q.ranks));
  if (q.minLevel) where.push(gte(characters.level, q.minLevel));
  if (q.maxLevel) where.push(lte(characters.level, q.maxLevel));
  if (q.activeDays) where.push(and(isNotNull(characters.lastLoginAt), gte(characters.lastLoginAt, new Date(deps.now().getTime() - q.activeDays * 86_400_000)))!);
  if (q.role) {
    const specIds = [1, 2, 3, 4, 5, 7, 8, 9, 11].flatMap((c) => classById(c)!.specs.filter((s) => s.roleHint === q.role).map((s) => s.id));
    where.push(inArray(characters.primarySpecId, specIds));
  }
  const sortKey = q.sort ?? 'rank';
  // Natural default direction per column: hierarchy and names ascend, numbers descend.
  const direction = q.dir ?? (sortKey === 'rank' || sortKey === 'name' || sortKey === 'class' ? 'asc' : 'desc');
  const dir = direction === 'asc' ? asc : desc;
  const sortCol = {
    name: characters.name,
    level: characters.level,
    class: characters.classId,
    rank: characters.guildRank,
    itemLevel: characters.equippedItemLevel,
    lastLogin: characters.lastLoginAt,
    honorableKills: characters.honorableKills,
  }[sortKey];
  const nullsLast = sql`${sortCol} ${sql.raw(direction)} nulls last`;
  const cond = and(...where);
  const [{ n }] = await deps.db.select({ n: count() }).from(characters).where(cond);
  const rows = await deps.db
    .select()
    .from(characters)
    .where(cond)
    .orderBy(sortKey === 'name' ? dir(characters.name) : nullsLast, asc(characters.guildRank), desc(characters.level), asc(characters.name))
    .limit(q.pageSize)
    .offset(q.offset);
  return { items: rows.map((r) => toRosterMember(r, guild.settings?.rankNames)), total: Number(n), page: q.page, pageSize: q.pageSize };
}

export function instanceName(key: string) {
  return RAID_INSTANCES.find((i) => i.key === key)?.nameEs ?? key;
}

