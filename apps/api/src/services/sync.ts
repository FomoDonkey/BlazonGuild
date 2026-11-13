import {
  BlizzardApiError,
  sha256,
  type BlizzardClient,
  type CharacterEquipmentPayload,
  type CharacterSpecializationsPayload,
  type GuildPayload,
  type GuildRosterPayload,
  type ProfessionsPayload,
} from '@blazonguild/data-providers';
import {
  activityEvents,
  and,
  characterEquipment,
  characterSnapshots,
  characters,
  eq,
  guildMemberships,
  guilds,
  inArray,
  items,
  sql,
  syncJobs,
  type Database,
  type GuildCrest,
} from '@blazonguild/database';
import {
  blizzardProvenance,
  classById,
  defaultRoleForRankIndex,
  type ActivityType,
  type GuildRole,
  type Region,
} from '@blazonguild/types';
import type { Logger } from '../lib/logger';
import type { StaticDataService } from './static-data';

type GuildRow = typeof guilds.$inferSelect;
type CharacterRow = typeof characters.$inferSelect;
type Trigger = 'SCHEDULE' | 'VIEW' | 'MANUAL' | 'CLI';

export const DETAIL_STALE_MS = 6 * 3600 * 1000;
export const ROSTER_STALE_MS = 30 * 60 * 1000;
/**
 * Character profiles refreshed per guild sync. Big guilds (1000+ members) are completed
 * progressively by the scheduler instead of firing thousands of Battle.net requests at once.
 */
export const DETAIL_BATCH = 80;
const DETAIL_CONCURRENCY = 12;

export class GuildNotFoundError extends Error {}

const rgbaCss = (c?: { r: number; g: number; b: number; a?: number | null }) =>
  c ? `rgba(${c.r}, ${c.g}, ${c.b}, ${c.a ?? 1})` : 'rgba(128, 128, 128, 1)';

const normSlug = (slug: string) => slug.trim().toLowerCase();

interface ActivityInput {
  guildId: string | null;
  characterId: string | null;
  type: ActivityType;
  occurredAt: Date;
  title: string;
  detail?: Record<string, unknown>;
  dedupeKey: string;
  method: string;
  collectedAt: Date;
}

export class SyncService {
  private locks = new Map<string, Promise<unknown>>();
  /** Profiles per guild sync pass (mutable for tests). */
  detailBatch = DETAIL_BATCH;
  private background = new Set<Promise<unknown>>();

  /** Tracks fire-and-forget work so CLIs/shutdown can wait for it (see drain()). */
  private track<T>(p: Promise<T>) {
    this.background.add(p);
    void p.finally(() => this.background.delete(p)).catch(() => {});
    return p;
  }

  async drain() {
    while (this.background.size || this.locks.size) {
      await Promise.allSettled([...this.background, ...this.locks.values()]);
    }
  }

  constructor(
    private readonly db: Database,
    private readonly blizzard: (region: Region) => BlizzardClient,
    private readonly staticData: StaticDataService,
    private readonly log: Logger,
    private readonly now: () => Date = () => new Date(),
  ) {}

  /** Serialises work per key so two requests never sync the same guild/character concurrently. */
  private async withLock<T>(key: string, fn: () => Promise<T>): Promise<T> {
    const running = this.locks.get(key);
    if (running) return running as Promise<T>;
    const p = fn().finally(() => this.locks.delete(key));
    this.locks.set(key, p);
    return p;
  }

  isRunning(region: Region, slug: string) {
    return this.locks.has(`guild:${region}:${normSlug(slug)}`);
  }

  private async recordActivity(events: ActivityInput[]) {
    if (!events.length) return 0;
    const rows = await this.db
      .insert(activityEvents)
      .values(
        events.map((e) => ({
          guildId: e.guildId,
          characterId: e.characterId,
          type: e.type,
          occurredAt: e.occurredAt,
          title: e.title,
          detail: e.detail ?? {},
          dedupeKey: e.dedupeKey,
          provenance: blizzardProvenance(e.collectedAt, { method: e.method }),
        })),
      )
      .onConflictDoNothing({ target: activityEvents.dedupeKey })
      .returning({ id: activityEvents.id });
    return rows.length;
  }

  // -------------------------------------------------------------------------
  // Guild
  // -------------------------------------------------------------------------

  async syncGuild(
    region: Region,
    slugInput: string,
    opts: { trigger: Trigger; userId?: string | null; details?: 'stale' | 'all' | 'none'; awaitDetails?: boolean } = { trigger: 'MANUAL' },
  ): Promise<GuildRow> {
    const slug = normSlug(slugInput);
    return this.withLock(`guild:${region}:${slug}`, async () => {
      const client = this.blizzard(region);
      const [job] = await this.db
        .insert(syncJobs)
        .values({ kind: 'GUILD', region, target: slug, state: 'RUNNING', trigger: opts.trigger, requestedByUserId: opts.userId ?? null, startedAt: this.now() })
        .returning();
      const stats: Record<string, number> = {};
      let guildRow: GuildRow | undefined;
      try {
        const guildRes = await client.guild(slug);
        if (!guildRes) throw new GuildNotFoundError(`La hermandad «${slug}» no existe en ${region.toUpperCase()}`);
        guildRow = await this.upsertGuild(region, guildRes.data, opts.userId ?? null);
        await this.db.update(guilds).set({ syncState: 'RUNNING' }).where(eq(guilds.id, guildRow.id));
        await this.db.update(syncJobs).set({ guildId: guildRow.id }).where(eq(syncJobs.id, job.id));

        const rosterRes = await client.guildRoster(slug);
        const rosterStats = rosterRes ? await this.applyRoster(region, guildRow, rosterRes.data.members, rosterRes.checksum, rosterRes.fetchedAt) : null;
        Object.assign(stats, rosterStats ?? {});
        await this.reconcileMemberships(guildRow.id);

        guildRow = (
          await this.db
            .update(guilds)
            .set({ lastSyncedAt: this.now(), syncState: 'OK', syncError: null })
            .where(eq(guilds.id, guildRow.id))
            .returning()
        )[0];

        const detailMode = opts.details ?? 'stale';
        const runDetails = async () => {
          if (detailMode === 'none') return { ok: 0, failed: 0 };
          return this.syncGuildDetails(region, guildRow!.id, detailMode === 'all');
        };

        const finish = async (detail: { ok: number; failed: number; remaining?: number }) => {
          stats.detailsSynced = detail.ok;
          stats.detailsFailed = detail.failed;
          stats.detailsRemaining = detail.remaining ?? 0;
          const state = detail.failed > 0 ? 'PARTIAL' : 'OK';
          await this.db.update(syncJobs).set({ state, stats, finishedAt: this.now() }).where(eq(syncJobs.id, job.id));
          await this.db.update(guilds).set({ syncState: state }).where(eq(guilds.id, guildRow!.id));
        };

        if (opts.awaitDetails) {
          await finish(await runDetails());
        } else {
          void this.track(runDetails()
            .then(finish)
            .catch(async (err) => {
              this.log.error('guild detail sync failed', { region, slug, err: String(err) });
              await this.db.update(syncJobs).set({ state: 'ERROR', error: String(err), finishedAt: this.now() }).where(eq(syncJobs.id, job.id));
            }));
        }
        return guildRow;
      } catch (err) {
        const message = err instanceof Error ? err.message : String(err);
        await this.db.update(syncJobs).set({ state: 'ERROR', error: message, stats, finishedAt: this.now() }).where(eq(syncJobs.id, job.id));
        if (guildRow) await this.db.update(guilds).set({ syncState: 'ERROR', syncError: message }).where(eq(guilds.id, guildRow.id));
        throw err;
      }
    });
  }

  private async upsertGuild(region: Region, g: GuildPayload, trackedBy: string | null): Promise<GuildRow> {
    const [emblemUrl, borderUrl] = await Promise.all([
      g.crest?.emblem ? this.staticData.crestUrl(region, 'emblem', g.crest.emblem.id) : null,
      g.crest?.border ? this.staticData.crestUrl(region, 'border', g.crest.border.id) : null,
    ]);
    const crest: GuildCrest | null = g.crest
      ? {
          emblemId: g.crest.emblem?.id ?? null,
          emblemUrl,
          emblemColor: rgbaCss(g.crest.emblem?.color.rgba),
          borderId: g.crest.border?.id ?? null,
          borderUrl,
          borderColor: rgbaCss(g.crest.border?.color.rgba),
          backgroundColor: rgbaCss(g.crest.background?.color.rgba),
        }
      : null;
    const values = {
      region,
      slug: normSlug(g.slug),
      blizzardId: g.id,
      name: g.name,
      faction: (g.faction.type === 'ALLIANCE' ? 'ALLIANCE' : 'HORDE') as 'ALLIANCE' | 'HORDE',
      rulesetId: g.ruleset?.id ?? null,
      rulesetName: g.ruleset?.name ?? null,
      memberCount: g.member_count ?? 0,
      achievementPoints: g.achievement_points ?? null,
      crest,
      foundedAt: g.created_timestamp ? new Date(g.created_timestamp) : null,
    };
    // Guild renames keep their Blizzard id: match on it first.
    const existing = await this.db.select().from(guilds).where(and(eq(guilds.region, region), eq(guilds.blizzardId, g.id))).limit(1);
    if (existing[0]) {
      const [row] = await this.db.update(guilds).set(values).where(eq(guilds.id, existing[0].id)).returning();
      return row;
    }
    const [row] = await this.db
      .insert(guilds)
      .values({ ...values, trackedByUserId: trackedBy })
      .onConflictDoUpdate({ target: [guilds.region, guilds.slug], set: values })
      .returning();
    return row;
  }

  private async applyRoster(
    region: Region,
    guild: GuildRow,
    members: GuildRosterPayload['members'],
    checksum: string,
    fetchedAt: Date,
  ) {
    const firstSync = !guild.lastSyncedAt;
    const previous = await this.db.select().from(characters).where(eq(characters.guildId, guild.id));
    const prevBySlug = new Map(previous.map((c) => [c.slug, c]));
    const rosterSlugs = new Set(members.map((m) => normSlug(m.character.slug)));

    const now = this.now();
    if (members.length) {
      await this.db
        .insert(characters)
        .values(
          members.map((m) => ({
            region,
            slug: normSlug(m.character.slug),
            blizzardId: m.character.id,
            name: m.character.name,
            surname: m.character.surname ?? null,
            classId: m.character.playable_class.id,
            raceId: m.character.playable_race?.id ?? null,
            faction: (m.character.faction?.type === 'ALLIANCE' ? 'ALLIANCE' : m.character.faction?.type === 'HORDE' ? 'HORDE' : guild.faction) as 'ALLIANCE' | 'HORDE',
            level: m.character.level,
            guildId: guild.id,
            guildRank: m.rank,
            rosterSeenAt: now,
          })),
        )
        .onConflictDoUpdate({
          target: [characters.region, characters.slug],
          set: {
            blizzardId: sql`excluded.blizzard_id`,
            name: sql`excluded.name`,
            surname: sql`excluded.surname`,
            classId: sql`excluded.class_id`,
            raceId: sql`excluded.race_id`,
            faction: sql`excluded.faction`,
            level: sql`greatest(${characters.level}, excluded.level)`,
            guildId: sql`excluded.guild_id`,
            guildRank: sql`excluded.guild_rank`,
            rosterSeenAt: sql`excluded.roster_seen_at`,
          },
        });
    }

    const current = await this.db.select().from(characters).where(eq(characters.guildId, guild.id));
    const bySlug = new Map(current.map((c) => [c.slug, c]));
    const leftChars = previous.filter((c) => !rosterSlugs.has(c.slug));
    if (leftChars.length) {
      await this.db
        .update(characters)
        .set({ guildId: null, guildRank: null })
        .where(inArray(characters.id, leftChars.map((c) => c.id)));
    }

    const events: ActivityInput[] = [];
    const window = { detectedBetween: [guild.lastSyncedAt?.toISOString() ?? null, now.toISOString()] };
    const stats = { members: members.length, joined: 0, left: leftChars.length, rankChanges: 0, levelUps: 0 };
    if (firstSync) {
      events.push({
        guildId: guild.id, characterId: null, type: 'GUILD_TRACKED', occurredAt: now,
        title: `${guild.name} se incorpora a BlazonGuild con ${members.length} personajes`,
        detail: { members: members.length }, dedupeKey: `tracked:${guild.id}`, method: 'roster-import', collectedAt: fetchedAt,
      });
    } else {
      for (const m of members) {
        const slug = normSlug(m.character.slug);
        const row = bySlug.get(slug);
        if (!row) continue;
        const before = prevBySlug.get(slug);
        const display = [m.character.name, m.character.surname].filter(Boolean).join(' ');
        if (!before) {
          stats.joined++;
          events.push({
            guildId: guild.id, characterId: row.id, type: 'MEMBER_JOINED', occurredAt: now,
            title: `${display} se une a la hermandad`, detail: { ...window, rank: m.rank },
            dedupeKey: `joined:${guild.id}:${row.id}:${now.toISOString().slice(0, 10)}`, method: 'roster-diff', collectedAt: fetchedAt,
          });
          continue;
        }
        if (before.guildRank !== null && before.guildRank !== m.rank) {
          stats.rankChanges++;
          events.push({
            guildId: guild.id, characterId: row.id, type: 'RANK_CHANGED', occurredAt: now,
            title: `${display} pasa del rango ${before.guildRank} al ${m.rank}`, detail: { ...window, from: before.guildRank, to: m.rank },
            dedupeKey: `rank:${row.id}:${before.guildRank}:${m.rank}:${now.toISOString().slice(0, 13)}`, method: 'roster-diff', collectedAt: fetchedAt,
          });
        }
        if (m.character.level > before.level) {
          stats.levelUps++;
          events.push({
            guildId: guild.id, characterId: row.id, type: 'LEVEL_UP', occurredAt: now,
            title: `${display} alcanza el nivel ${m.character.level}`, detail: { ...window, from: before.level, to: m.character.level },
            dedupeKey: `level:${row.id}:${m.character.level}`, method: 'roster-diff', collectedAt: fetchedAt,
          });
        }
      }
      for (const c of leftChars) {
        events.push({
          guildId: guild.id, characterId: c.id, type: 'MEMBER_LEFT', occurredAt: now,
          title: `${[c.name, c.surname].filter(Boolean).join(' ')} ya no está en la hermandad`, detail: window,
          dedupeKey: `left:${guild.id}:${c.id}:${now.toISOString().slice(0, 10)}`, method: 'roster-diff', collectedAt: fetchedAt,
        });
      }
    }
    await this.recordActivity(events);
    await this.db.update(guilds).set({ memberCount: members.length, rosterChecksum: checksum }).where(eq(guilds.id, guild.id));
    return stats;
  }

  /** Grants/updates platform memberships for users whose characters are Battle.net-verified. */
  async reconcileMemberships(guildId: string) {
    const [guild] = await this.db.select().from(guilds).where(eq(guilds.id, guildId)).limit(1);
    if (!guild) return;
    const owned = await this.db
      .select({ userId: characters.ownerUserId, rank: characters.guildRank })
      .from(characters)
      .where(and(eq(characters.guildId, guildId), eq(characters.ownershipVerified, true)));
    const best = new Map<string, number>();
    for (const o of owned) {
      if (!o.userId || o.rank === null) continue;
      best.set(o.userId, Math.min(best.get(o.userId) ?? 99, o.rank));
    }
    const rankRoles = guild.settings?.rankRoles ?? {};
    const memberships = await this.db.select().from(guildMemberships).where(eq(guildMemberships.guildId, guildId));
    for (const [userId, rank] of best) {
      const role: GuildRole = rankRoles[String(rank)] ?? defaultRoleForRankIndex(rank);
      const existing = memberships.find((m) => m.userId === userId);
      if (!existing) {
        await this.db.insert(guildMemberships).values({ guildId, userId, role, verified: true, source: 'BATTLENET' }).onConflictDoNothing();
      } else if (existing.source === 'BATTLENET' && existing.role !== role) {
        await this.db.update(guildMemberships).set({ role, verified: true }).where(eq(guildMemberships.id, existing.id));
      } else if (!existing.verified) {
        await this.db.update(guildMemberships).set({ verified: true }).where(eq(guildMemberships.id, existing.id));
      }
    }
    // Battle.net-derived memberships lapse when the user no longer has a verified character in the guild.
    const stale = memberships.filter((m) => m.source === 'BATTLENET' && !best.has(m.userId)).map((m) => m.id);
    if (stale.length) await this.db.delete(guildMemberships).where(inArray(guildMemberships.id, stale));
  }

  private async syncGuildDetails(region: Region, guildId: string, all: boolean) {
    const rows = await this.db.select().from(characters).where(eq(characters.guildId, guildId));
    const cutoff = this.now().getTime() - DETAIL_STALE_MS;
    // Priority: never-synced first (highest level first — they matter most to the guild), then the oldest.
    const pending = rows
      .filter((c) => all || !c.detailSyncedAt || c.detailSyncedAt.getTime() < cutoff)
      .sort((a, b) => {
        if (!a.detailSyncedAt !== !b.detailSyncedAt) return a.detailSyncedAt ? 1 : -1;
        if (!a.detailSyncedAt || !b.detailSyncedAt) return b.level - a.level;
        return a.detailSyncedAt.getTime() - b.detailSyncedAt.getTime();
      });
    const todo = pending.slice(0, this.detailBatch);
    let ok = 0;
    let failed = 0;
    for (let i = 0; i < todo.length; i += DETAIL_CONCURRENCY) {
      await Promise.all(
        todo.slice(i, i + DETAIL_CONCURRENCY).map(async (c) => {
          try {
            const res = await this.syncCharacter(region, c.slug, { trigger: 'SCHEDULE', recordJob: false });
            if (res) ok++;
            else failed++;
          } catch (err) {
            failed++;
            this.log.warn('character detail sync failed', { region, slug: c.slug, err: String(err) });
          }
        }),
      );
    }
    return { ok, failed, remaining: pending.length - todo.length };
  }

  // -------------------------------------------------------------------------
  // Character
  // -------------------------------------------------------------------------

  async syncCharacter(
    region: Region,
    slugInput: string,
    opts: { trigger: Trigger; userId?: string | null; recordJob?: boolean } = { trigger: 'MANUAL' },
  ): Promise<CharacterRow | null> {
    const slug = normSlug(slugInput);
    return this.withLock(`char:${region}:${slug}`, async () => {
      const client = this.blizzard(region);
      const job = opts.recordJob === false
        ? null
        : (await this.db.insert(syncJobs).values({ kind: 'CHARACTER', region, target: slug, state: 'RUNNING', trigger: opts.trigger, requestedByUserId: opts.userId ?? null, startedAt: this.now() }).returning())[0];
      const finishJob = async (state: 'OK' | 'PARTIAL' | 'ERROR', stats: Record<string, number>, error?: string) => {
        if (job) await this.db.update(syncJobs).set({ state, stats, error: error ?? null, finishedAt: this.now() }).where(eq(syncJobs.id, job.id));
      };

      try {
        const profileRes = await client.character(slug);
        const existing = (await this.db.select().from(characters).where(and(eq(characters.region, region), eq(characters.slug, slug))).limit(1))[0];
        if (!profileRes) {
          if (existing) await this.db.update(characters).set({ detailState: 'NOT_FOUND', detailSyncedAt: this.now() }).where(eq(characters.id, existing.id));
          await finishJob('ERROR', {}, 'NOT_FOUND');
          return null;
        }
        const p = profileRes.data;

        const settle = async <T>(fn: () => Promise<T>) => {
          try {
            return { ok: true as const, value: await fn() };
          } catch (err) {
            return { ok: false as const, error: err };
          }
        };
        const [equipment, statistics, specs, media, pvp, professions, achievements] = await Promise.all([
          settle(() => client.characterEquipment(slug)),
          settle(() => client.characterStatistics(slug)),
          settle(() => client.characterSpecializations(slug)),
          settle(() => client.characterMedia(slug)),
          settle(() => client.characterPvp(slug)),
          settle(() => client.characterProfessions(slug)),
          settle(() => client.characterAchievements(slug)),
        ]);
        const parts = { equipment, statistics, specs, media, pvp, professions, achievements };
        const failedParts = Object.entries(parts).filter(([, r]) => !r.ok).map(([k]) => k);
        const val = <T>(r: { ok: true; value: T } | { ok: false; error: unknown }) => (r.ok ? r.value : null);

        const checksum = sha256(
          [profileRes.checksum, ...Object.values(parts).map((r) => (r.ok ? r.value?.checksum ?? 'none' : 'err'))].join('|'),
        );

        const guildSlug = p.guild?.slug ? normSlug(p.guild.slug) : null;
        const guildRow = guildSlug
          ? (await this.db.select({ id: guilds.id }).from(guilds).where(and(eq(guilds.region, region), eq(guilds.slug, guildSlug))).limit(1))[0]
          : undefined;

        const specPayload = val(specs)?.data ?? null;
        const { split, primarySpecId } = talentSummary(p.character_class.id, specPayload);
        const mediaAssets = val(media)?.data.assets ?? [];
        const asset = (k: string) => mediaAssets.find((a) => a.key === k)?.value ?? null;
        const pvpData = val(pvp)?.data ?? null;
        const profSummary = professionSummary(val(professions)?.data ?? null);
        const achData = val(achievements)?.data ?? null;

        const columns = {
          region,
          slug,
          blizzardId: p.id,
          name: p.name,
          surname: p.surname ?? null,
          classId: p.character_class.id,
          raceId: p.race?.id ?? null,
          gender: p.gender?.type ?? null,
          faction: (p.faction?.type === 'ALLIANCE' ? 'ALLIANCE' : p.faction?.type === 'HORDE' ? 'HORDE' : null) as 'ALLIANCE' | 'HORDE' | null,
          level: p.level,
          guildId: guildRow?.id ?? null,
          averageItemLevel: p.average_item_level ?? null,
          equippedItemLevel: p.equipped_item_level ?? null,
          achievementPoints: achData?.total_points ?? p.achievement_points ?? null,
          honorableKills: pvpData?.honorable_kills ?? null,
          pvpRank: pvpData?.pvp_rank ?? null,
          lastLoginAt: p.last_login_timestamp ? new Date(p.last_login_timestamp) : null,
          talentSplit: split,
          primarySpecId,
          professions: profSummary,
          avatarUrl: asset('avatar'),
          renderUrl: asset('main-raw'),
          detailSyncedAt: this.now(),
          detailChecksum: checksum,
          detailState: 'OK' as const,
          detailError: failedParts.length ? `Fallaron: ${failedParts.join(', ')}` : null,
        };

        let row: CharacterRow;
        if (existing) {
          const guildChanged = existing.guildId !== columns.guildId;
          [row] = await this.db
            .update(characters)
            .set({ ...columns, guildRank: guildChanged ? null : existing.guildRank })
            .where(eq(characters.id, existing.id))
            .returning();
        } else {
          [row] = await this.db.insert(characters).values(columns).returning();
        }

        const changed = !existing || existing.detailChecksum !== checksum;
        const events: ActivityInput[] = [];
        const collectedAt = profileRes.fetchedAt;
        const display = [p.name, p.surname].filter(Boolean).join(' ');

        if (changed) {
          await this.db
            .insert(characterSnapshots)
            .values({
              characterId: row.id,
              checksum,
              level: p.level,
              itemLevel: p.equipped_item_level ?? null,
              achievementPoints: columns.achievementPoints,
              profile: p as Record<string, unknown>,
              equipment: (val(equipment)?.data ?? null) as Record<string, unknown> | null,
              statistics: (val(statistics)?.data ?? null) as Record<string, unknown> | null,
              specializations: (specPayload ?? null) as Record<string, unknown> | null,
              professions: (val(professions)?.data ?? null) as Record<string, unknown> | null,
              pvp: (pvpData ?? null) as Record<string, unknown> | null,
              achievements: (achData ?? null) as Record<string, unknown> | null,
              provenance: blizzardProvenance(collectedAt, {
                namespace: profileRes.namespace,
                endpoint: `/profile/wow/character/${slug}`,
                checksum,
                method: 'profile+equipment+statistics+specializations+media+pvp+professions+achievements',
                processorVersion: 'sync-v1',
                notes: failedParts.length ? `Secciones no disponibles: ${failedParts.join(', ')}` : undefined,
              }),
            })
            .onConflictDoNothing();

          if (existing?.detailSyncedAt && p.level > existing.level) {
            events.push({
              guildId: row.guildId, characterId: row.id, type: 'LEVEL_UP', occurredAt: this.now(),
              title: `${display} alcanza el nivel ${p.level}`, detail: { from: existing.level, to: p.level, detectedBetween: [existing.detailSyncedAt.toISOString(), this.now().toISOString()] },
              dedupeKey: `level:${row.id}:${p.level}`, method: 'profile-diff', collectedAt,
            });
          }
          const equipmentData = val(equipment)?.data;
          if (equipmentData) events.push(...(await this.applyEquipment(region, row, equipmentData, !!existing?.detailSyncedAt, collectedAt, display)));
        }

        for (const ev of achData?.recent_events ?? []) {
          events.push({
            guildId: row.guildId, characterId: row.id, type: 'ACHIEVEMENT', occurredAt: new Date(ev.timestamp),
            title: `${display} consigue «${ev.achievement.name ?? `Logro ${ev.achievement.id}`}»`,
            detail: { achievementId: ev.achievement.id, name: ev.achievement.name ?? null },
            dedupeKey: `ach:${row.id}:${ev.achievement.id}`, method: 'achievements-recent-events', collectedAt,
          });
        }
        await this.recordActivity(events);
        await finishJob(failedParts.length ? 'PARTIAL' : 'OK', { endpoints: 8 - failedParts.length, failed: failedParts.length });
        return row;
      } catch (err) {
        const message = err instanceof Error ? err.message : String(err);
        await this.db
          .update(characters)
          .set({ detailState: 'ERROR', detailError: message.slice(0, 500) })
          .where(and(eq(characters.region, region), eq(characters.slug, slug)));
        await finishJob('ERROR', {}, message);
        if (err instanceof BlizzardApiError) this.log.warn('character sync upstream error', { slug, status: err.status });
        throw err;
      }
    });
  }

  private async applyEquipment(
    region: Region,
    row: CharacterRow,
    payload: CharacterEquipmentPayload,
    emitEvents: boolean,
    collectedAt: Date,
    display: string,
  ): Promise<ActivityInput[]> {
    const before = await this.db.select().from(characterEquipment).where(eq(characterEquipment.characterId, row.id));
    const beforeBySlot = new Map(before.map((b) => [b.slot, b]));
    const now = this.now();
    const next = payload.equipped_items.map((it) => ({
      characterId: row.id,
      slot: it.slot.type,
      itemId: it.item.id,
      name: it.name ?? `Objeto ${it.item.id}`,
      quality: it.quality?.type ?? 'COMMON',
      itemLevel: it.level?.value ?? null,
      enchantments: (it.enchantments ?? []).map((e) => e.display_string).filter((s): s is string => !!s),
      equippedSince: beforeBySlot.get(it.slot.type)?.itemId === it.item.id ? beforeBySlot.get(it.slot.type)!.equippedSince : now,
    }));

    if (next.length) {
      await this.db
        .insert(items)
        .values([...new Map(next.map((n) => [n.itemId, { id: n.itemId, name: n.name, quality: n.quality }])).values()])
        .onConflictDoUpdate({ target: items.id, set: { name: sql`excluded.name`, quality: sql`excluded.quality` } });
    }
    await this.db.delete(characterEquipment).where(eq(characterEquipment.characterId, row.id));
    if (next.length) await this.db.insert(characterEquipment).values(next);
    void this.track(this.staticData.ensureItemIcons(region, next.map((n) => n.itemId)));

    if (!emitEvents) return [];
    const QUALITY_RANK: Record<string, number> = { POOR: 0, COMMON: 1, UNCOMMON: 2, RARE: 3, EPIC: 4, LEGENDARY: 5 };
    return next
      .filter((n) => beforeBySlot.get(n.slot)?.itemId !== n.itemId && (QUALITY_RANK[n.quality] ?? 0) >= 2)
      .map((n) => ({
        guildId: row.guildId, characterId: row.id, type: 'ITEM_EQUIPPED' as const, occurredAt: now,
        title: `${display} equipa ${n.name}`,
        detail: { itemId: n.itemId, name: n.name, quality: n.quality, slot: n.slot, itemLevel: n.itemLevel, replaced: beforeBySlot.get(n.slot)?.name ?? null },
        dedupeKey: `item:${row.id}:${n.slot}:${n.itemId}`, method: 'equipment-diff', collectedAt,
      }));
  }
}

/** Points per tree in the class' canonical tree order + the dominant tree (if any points spent). */
export function talentSummary(classId: number, payload: CharacterSpecializationsPayload | null) {
  const cls = classById(classId);
  if (!cls || !payload) return { split: null, primarySpecId: null };
  const group = payload.specialization_groups.find((g) => g.is_active) ?? payload.specialization_groups[0];
  if (!group) return { split: cls.specs.map(() => 0), primarySpecId: null };
  const split = cls.specs.map((s) => {
    const spec = group.specializations.find((x) => x.specialization.id === s.id);
    if (!spec) return 0;
    return spec.spent_points ?? spec.talents.reduce((sum, t) => sum + (t.talent_rank ?? 0), 0);
  });
  const max = Math.max(...split);
  return { split, primarySpecId: max > 0 ? cls.specs[split.indexOf(max)].id : null };
}

export function professionSummary(payload: ProfessionsPayload | null) {
  if (!payload) return null;
  const map = (list: ProfessionsPayload['primaries'], kind: 'primary' | 'secondary') =>
    (list ?? []).map((pr) => {
      const tier = pr.tiers?.[pr.tiers.length - 1];
      return {
        id: pr.profession.id,
        name: pr.profession.name ?? `Profesión ${pr.profession.id}`,
        skill: tier?.skill_points ?? pr.skill_points ?? 0,
        max: tier?.max_skill_points ?? pr.max_skill_points ?? 0,
        kind,
      };
    });
  return [...map(payload.primaries, 'primary'), ...map(payload.secondaries, 'secondary')];
}
