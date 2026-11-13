/**
 * BlazonGuild Core — canonical relational schema (PostgreSQL).
 *
 * Multi-guild by design: every guild-scoped record carries `guild_id`, and a user can be a
 * member (with a different role) of any number of guilds. See DATA_MODEL.md for the ERD.
 */
import { sql } from 'drizzle-orm';
import {
  bigint,
  boolean,
  index,
  integer,
  jsonb,
  pgTable,
  primaryKey,
  real,
  text,
  timestamp,
  uniqueIndex,
  uuid,
} from 'drizzle-orm/pg-core';
import type { GuildRole, PermissionOverrides, Provenance } from '@blazonguild/types';

const ts = (name: string) => timestamp(name, { withTimezone: true, mode: 'date' });
const createdAt = () => ts('created_at').notNull().defaultNow();
const updatedAt = () => ts('updated_at').notNull().defaultNow().$onUpdate(() => new Date());

// ---------------------------------------------------------------------------
// Identity
// ---------------------------------------------------------------------------

export const users = pgTable(
  'users',
  {
    id: uuid('id').primaryKey().defaultRandom(),
    /** Always stored lower-cased. */
    email: text('email').notNull(),
    /** scrypt hash; null for accounts created through Battle.net only. */
    passwordHash: text('password_hash'),
    displayName: text('display_name').notNull(),
    platformRole: text('platform_role').$type<'ADMIN' | 'USER'>().notNull().default('USER'),
    battlenetId: bigint('battlenet_id', { mode: 'number' }),
    battleTag: text('battle_tag'),
    isActive: boolean('is_active').notNull().default(true),
    lastLoginAt: ts('last_login_at'),
    createdAt: createdAt(),
    updatedAt: updatedAt(),
  },
  (t) => [uniqueIndex('users_email_uq').on(t.email), uniqueIndex('users_battlenet_uq').on(t.battlenetId)],
);

export const sessions = pgTable(
  'sessions',
  {
    /** SHA-256 of the opaque session token (the token itself is never stored). */
    id: text('id').primaryKey(),
    userId: uuid('user_id')
      .notNull()
      .references(() => users.id, { onDelete: 'cascade' }),
    expiresAt: ts('expires_at').notNull(),
    lastSeenAt: ts('last_seen_at').notNull().defaultNow(),
    ip: text('ip'),
    userAgent: text('user_agent'),
    createdAt: createdAt(),
  },
  (t) => [index('sessions_user_idx').on(t.userId), index('sessions_expiry_idx').on(t.expiresAt)],
);

/** Personal access tokens (companion app / addon uploads). */
export const apiTokens = pgTable(
  'api_tokens',
  {
    id: uuid('id').primaryKey().defaultRandom(),
    userId: uuid('user_id')
      .notNull()
      .references(() => users.id, { onDelete: 'cascade' }),
    name: text('name').notNull(),
    tokenHash: text('token_hash').notNull(),
    scopes: jsonb('scopes').$type<string[]>().notNull().default(sql`'["ingest"]'::jsonb`),
    lastUsedAt: ts('last_used_at'),
    revokedAt: ts('revoked_at'),
    createdAt: createdAt(),
  },
  (t) => [uniqueIndex('api_tokens_hash_uq').on(t.tokenHash), index('api_tokens_user_idx').on(t.userId)],
);

// ---------------------------------------------------------------------------
// Guilds
// ---------------------------------------------------------------------------

export interface GuildCrest {
  emblemId: number | null;
  emblemUrl: string | null;
  emblemColor: string;
  borderId: number | null;
  borderUrl: string | null;
  borderColor: string;
  backgroundColor: string;
}

export interface GuildSettings {
  /** In-game rank index → custom display name (the API only exposes indexes). */
  rankNames?: Record<string, string>;
  /** Rank index → platform role granted to *verified* characters of that rank. */
  rankRoles?: Record<string, GuildRole>;
  permissions?: PermissionOverrides;
  description?: string;
  recruitment?: string;
}

export const guilds = pgTable(
  'guilds',
  {
    id: uuid('id').primaryKey().defaultRandom(),
    region: text('region').notNull(),
    slug: text('slug').notNull(),
    blizzardId: bigint('blizzard_id', { mode: 'number' }),
    name: text('name').notNull(),
    faction: text('faction').$type<'ALLIANCE' | 'HORDE'>().notNull(),
    rulesetId: integer('ruleset_id'),
    rulesetName: text('ruleset_name'),
    memberCount: integer('member_count').notNull().default(0),
    achievementPoints: integer('achievement_points'),
    crest: jsonb('crest').$type<GuildCrest | null>(),
    foundedAt: ts('founded_at'),
    settings: jsonb('settings').$type<GuildSettings>().notNull().default(sql`'{}'::jsonb`),
    rosterChecksum: text('roster_checksum'),
    lastSyncedAt: ts('last_synced_at'),
    syncState: text('sync_state').$type<'NEVER' | 'RUNNING' | 'OK' | 'PARTIAL' | 'ERROR'>().notNull().default('NEVER'),
    syncError: text('sync_error'),
    /** Last time anyone looked at the guild — drives scheduled re-sync priority. */
    lastViewedAt: ts('last_viewed_at'),
    trackedByUserId: uuid('tracked_by_user_id').references(() => users.id, { onDelete: 'set null' }),
    createdAt: createdAt(),
    updatedAt: updatedAt(),
  },
  (t) => [
    uniqueIndex('guilds_region_slug_uq').on(t.region, t.slug),
    uniqueIndex('guilds_region_blizzard_uq').on(t.region, t.blizzardId),
    index('guilds_name_idx').on(t.name),
  ],
);

/** Platform membership: which users manage/belong to which guild, with what role. */
export const guildMemberships = pgTable(
  'guild_memberships',
  {
    id: uuid('id').primaryKey().defaultRandom(),
    guildId: uuid('guild_id')
      .notNull()
      .references(() => guilds.id, { onDelete: 'cascade' }),
    userId: uuid('user_id')
      .notNull()
      .references(() => users.id, { onDelete: 'cascade' }),
    role: text('role').$type<GuildRole>().notNull().default('MEMBER'),
    /** True when backed by a Battle.net-verified character currently in the guild. */
    verified: boolean('verified').notNull().default(false),
    source: text('source').$type<'BATTLENET' | 'ADMIN' | 'INVITE'>().notNull(),
    createdAt: createdAt(),
    updatedAt: updatedAt(),
  },
  (t) => [uniqueIndex('memberships_guild_user_uq').on(t.guildId, t.userId), index('memberships_user_idx').on(t.userId)],
);

// ---------------------------------------------------------------------------
// Characters & armory
// ---------------------------------------------------------------------------

export const characters = pgTable(
  'characters',
  {
    id: uuid('id').primaryKey().defaultRandom(),
    region: text('region').notNull(),
    /** Realmless slug `{name}-{surname}`, lower-case. */
    slug: text('slug').notNull(),
    blizzardId: bigint('blizzard_id', { mode: 'number' }),
    name: text('name').notNull(),
    surname: text('surname'),
    classId: integer('class_id').notNull(),
    raceId: integer('race_id'),
    gender: text('gender'),
    faction: text('faction').$type<'ALLIANCE' | 'HORDE'>(),
    level: integer('level').notNull().default(1),
    guildId: uuid('guild_id').references(() => guilds.id, { onDelete: 'set null' }),
    guildRank: integer('guild_rank'),
    averageItemLevel: integer('average_item_level'),
    equippedItemLevel: integer('equipped_item_level'),
    achievementPoints: integer('achievement_points'),
    honorableKills: integer('honorable_kills'),
    pvpRank: integer('pvp_rank'),
    lastLoginAt: ts('last_login_at'),
    talentSplit: jsonb('talent_split').$type<number[] | null>(),
    professions: jsonb('professions').$type<{ id: number; name: string; skill: number; max: number; kind: 'primary' | 'secondary' }[] | null>(),
    primarySpecId: integer('primary_spec_id'),
    avatarUrl: text('avatar_url'),
    renderUrl: text('render_url'),
    ownerUserId: uuid('owner_user_id').references(() => users.id, { onDelete: 'set null' }),
    ownershipVerified: boolean('ownership_verified').notNull().default(false),
    isMain: boolean('is_main').notNull().default(false),
    rosterSeenAt: ts('roster_seen_at'),
    detailSyncedAt: ts('detail_synced_at'),
    detailChecksum: text('detail_checksum'),
    detailState: text('detail_state').$type<'NEVER' | 'OK' | 'NOT_FOUND' | 'ERROR'>().notNull().default('NEVER'),
    detailError: text('detail_error'),
    lastViewedAt: ts('last_viewed_at'),
    createdAt: createdAt(),
    updatedAt: updatedAt(),
  },
  (t) => [
    uniqueIndex('characters_region_slug_uq').on(t.region, t.slug),
    index('characters_guild_idx').on(t.guildId),
    index('characters_owner_idx').on(t.ownerUserId),
    index('characters_class_idx').on(t.classId),
    index('characters_name_idx').on(t.name),
  ],
);

/** Immutable point-in-time captures (only written when the payload checksum changes). */
export const characterSnapshots = pgTable(
  'character_snapshots',
  {
    id: uuid('id').primaryKey().defaultRandom(),
    characterId: uuid('character_id')
      .notNull()
      .references(() => characters.id, { onDelete: 'cascade' }),
    takenAt: ts('taken_at').notNull().defaultNow(),
    checksum: text('checksum').notNull(),
    level: integer('level').notNull(),
    itemLevel: integer('item_level'),
    achievementPoints: integer('achievement_points'),
    profile: jsonb('profile').$type<Record<string, unknown>>().notNull(),
    equipment: jsonb('equipment').$type<Record<string, unknown> | null>(),
    statistics: jsonb('statistics').$type<Record<string, unknown> | null>(),
    specializations: jsonb('specializations').$type<Record<string, unknown> | null>(),
    professions: jsonb('professions').$type<Record<string, unknown> | null>(),
    pvp: jsonb('pvp').$type<Record<string, unknown> | null>(),
    achievements: jsonb('achievements').$type<Record<string, unknown> | null>(),
    provenance: jsonb('provenance').$type<Provenance>().notNull(),
  },
  (t) => [
    index('snapshots_character_taken_idx').on(t.characterId, t.takenAt),
    uniqueIndex('snapshots_character_checksum_uq').on(t.characterId, t.checksum),
  ],
);

/** Current gear, normalised for cross-character queries ("who wears item X?"). */
export const characterEquipment = pgTable(
  'character_equipment',
  {
    characterId: uuid('character_id')
      .notNull()
      .references(() => characters.id, { onDelete: 'cascade' }),
    slot: text('slot').notNull(),
    itemId: integer('item_id').notNull(),
    name: text('name').notNull(),
    quality: text('quality').notNull(),
    itemLevel: integer('item_level'),
    enchantments: jsonb('enchantments').$type<string[]>().notNull().default(sql`'[]'::jsonb`),
    equippedSince: ts('equipped_since').notNull().defaultNow(),
  },
  (t) => [primaryKey({ columns: [t.characterId, t.slot] }), index('equipment_item_idx').on(t.itemId)],
);

/** Item catalogue cache (name/quality/icon) filled while syncing gear. */
export const items = pgTable('items', {
  id: integer('id').primaryKey(),
  name: text('name').notNull(),
  quality: text('quality').notNull(),
  iconUrl: text('icon_url'),
  mediaFetchedAt: ts('media_fetched_at'),
  firstSeenAt: createdAt(),
});

/** Generic cache for static-namespace documents (talent trees, spell icons, crests…). */
export const staticCache = pgTable('static_cache', {
  key: text('key').primaryKey(),
  namespace: text('namespace'),
  payload: jsonb('payload').$type<unknown>(),
  fetchedAt: ts('fetched_at').notNull().defaultNow(),
});

// ---------------------------------------------------------------------------
// Activity feed (derived from sync diffs — Battle.net's guild activity endpoint is empty on Forever)
// ---------------------------------------------------------------------------

export const activityEvents = pgTable(
  'activity_events',
  {
    id: uuid('id').primaryKey().defaultRandom(),
    guildId: uuid('guild_id').references(() => guilds.id, { onDelete: 'cascade' }),
    characterId: uuid('character_id').references(() => characters.id, { onDelete: 'set null' }),
    type: text('type').notNull(),
    occurredAt: ts('occurred_at').notNull(),
    title: text('title').notNull(),
    detail: jsonb('detail').$type<Record<string, unknown>>().notNull().default(sql`'{}'::jsonb`),
    provenance: jsonb('provenance').$type<Provenance>().notNull(),
    /** Natural key preventing duplicates when the same change is observed twice. */
    dedupeKey: text('dedupe_key').notNull(),
    createdAt: createdAt(),
  },
  (t) => [
    uniqueIndex('activity_dedupe_uq').on(t.dedupeKey),
    index('activity_guild_time_idx').on(t.guildId, t.occurredAt),
    index('activity_character_time_idx').on(t.characterId, t.occurredAt),
  ],
);

// ---------------------------------------------------------------------------
// Raid operations
// ---------------------------------------------------------------------------

export const raids = pgTable(
  'raids',
  {
    id: uuid('id').primaryKey().defaultRandom(),
    guildId: uuid('guild_id')
      .notNull()
      .references(() => guilds.id, { onDelete: 'cascade' }),
    title: text('title').notNull(),
    instanceKey: text('instance_key').notNull(),
    startsAt: ts('starts_at').notNull(),
    endsAt: ts('ends_at'),
    status: text('status').$type<'SCHEDULED' | 'IN_PROGRESS' | 'COMPLETED' | 'CANCELLED'>().notNull().default('SCHEDULED'),
    capacity: integer('capacity').notNull().default(40),
    minLevel: integer('min_level'),
    notes: text('notes'),
    leaderUserId: uuid('leader_user_id').references(() => users.id, { onDelete: 'set null' }),
    createdByUserId: uuid('created_by_user_id').references(() => users.id, { onDelete: 'set null' }),
    createdAt: createdAt(),
    updatedAt: updatedAt(),
  },
  (t) => [index('raids_guild_start_idx').on(t.guildId, t.startsAt)],
);

export const raidSignups = pgTable(
  'raid_signups',
  {
    id: uuid('id').primaryKey().defaultRandom(),
    raidId: uuid('raid_id')
      .notNull()
      .references(() => raids.id, { onDelete: 'cascade' }),
    characterId: uuid('character_id')
      .notNull()
      .references(() => characters.id, { onDelete: 'cascade' }),
    userId: uuid('user_id')
      .notNull()
      .references(() => users.id, { onDelete: 'cascade' }),
    status: text('status').$type<'CONFIRMED' | 'TENTATIVE' | 'DECLINED' | 'BENCHED'>().notNull(),
    role: text('role').$type<'TANK' | 'HEALER' | 'DPS'>().notNull(),
    comment: text('comment'),
    groupNo: integer('group_no'),
    slot: integer('slot'),
    signedUpAt: ts('signed_up_at').notNull().defaultNow(),
    updatedAt: updatedAt(),
  },
  (t) => [
    uniqueIndex('signups_raid_character_uq').on(t.raidId, t.characterId),
    uniqueIndex('signups_raid_user_uq').on(t.raidId, t.userId),
    uniqueIndex('signups_raid_position_uq').on(t.raidId, t.groupNo, t.slot),
  ],
);

// ---------------------------------------------------------------------------
// Operations: audit, sync jobs, ingestion, notifications
// ---------------------------------------------------------------------------

export const auditLogs = pgTable(
  'audit_logs',
  {
    id: uuid('id').primaryKey().defaultRandom(),
    actorUserId: uuid('actor_user_id').references(() => users.id, { onDelete: 'set null' }),
    guildId: uuid('guild_id').references(() => guilds.id, { onDelete: 'set null' }),
    action: text('action').notNull(),
    entity: text('entity').notNull(),
    entityId: text('entity_id').notNull(),
    changes: jsonb('changes').$type<unknown>().notNull().default(sql`'{}'::jsonb`),
    ip: text('ip'),
    userAgent: text('user_agent'),
    createdAt: createdAt(),
  },
  (t) => [index('audit_created_idx').on(t.createdAt), index('audit_guild_idx').on(t.guildId, t.createdAt)],
);

export const syncJobs = pgTable(
  'sync_jobs',
  {
    id: uuid('id').primaryKey().defaultRandom(),
    kind: text('kind').$type<'GUILD' | 'CHARACTER'>().notNull(),
    region: text('region').notNull(),
    target: text('target').notNull(),
    guildId: uuid('guild_id').references(() => guilds.id, { onDelete: 'set null' }),
    state: text('state').$type<'QUEUED' | 'RUNNING' | 'OK' | 'PARTIAL' | 'ERROR'>().notNull().default('QUEUED'),
    trigger: text('trigger').$type<'SCHEDULE' | 'VIEW' | 'MANUAL' | 'CLI'>().notNull(),
    requestedByUserId: uuid('requested_by_user_id').references(() => users.id, { onDelete: 'set null' }),
    stats: jsonb('stats').$type<Record<string, number>>().notNull().default(sql`'{}'::jsonb`),
    error: text('error'),
    startedAt: ts('started_at'),
    finishedAt: ts('finished_at'),
    createdAt: createdAt(),
  },
  (t) => [index('sync_jobs_created_idx').on(t.createdAt), index('sync_jobs_target_idx').on(t.region, t.target)],
);

export const ingestBatches = pgTable(
  'ingest_batches',
  {
    id: uuid('id').primaryKey().defaultRandom(),
    userId: uuid('user_id')
      .notNull()
      .references(() => users.id, { onDelete: 'cascade' }),
    source: text('source').$type<'ADDON' | 'COMBAT_LOG'>().notNull(),
    checksum: text('checksum').notNull(),
    addonVersion: text('addon_version'),
    clientBuild: text('client_build'),
    payload: jsonb('payload').$type<unknown>().notNull(),
    status: text('status').$type<'RECEIVED' | 'PROCESSED' | 'REJECTED'>().notNull().default('RECEIVED'),
    error: text('error'),
    receivedAt: ts('received_at').notNull().defaultNow(),
    processedAt: ts('processed_at'),
  },
  (t) => [uniqueIndex('ingest_checksum_uq').on(t.checksum), index('ingest_user_idx').on(t.userId, t.receivedAt)],
);

export const notifications = pgTable(
  'notifications',
  {
    id: uuid('id').primaryKey().defaultRandom(),
    userId: uuid('user_id')
      .notNull()
      .references(() => users.id, { onDelete: 'cascade' }),
    guildId: uuid('guild_id').references(() => guilds.id, { onDelete: 'cascade' }),
    type: text('type').notNull(),
    title: text('title').notNull(),
    body: text('body'),
    link: text('link'),
    readAt: ts('read_at'),
    createdAt: createdAt(),
  },
  (t) => [index('notifications_user_idx').on(t.userId, t.createdAt)],
);

/** Reserved for Phase 5 (combat log analytics). Declared now so the ERD is complete. */
export const encounterMetrics = pgTable(
  'encounter_metrics',
  {
    id: uuid('id').primaryKey().defaultRandom(),
    raidId: uuid('raid_id').references(() => raids.id, { onDelete: 'cascade' }),
    characterId: uuid('character_id')
      .notNull()
      .references(() => characters.id, { onDelete: 'cascade' }),
    encounterName: text('encounter_name').notNull(),
    result: text('result').$type<'KILL' | 'WIPE'>().notNull(),
    durationMs: integer('duration_ms').notNull(),
    damageDone: bigint('damage_done', { mode: 'number' }).notNull().default(0),
    healingDone: bigint('healing_done', { mode: 'number' }).notNull().default(0),
    damageTaken: bigint('damage_taken', { mode: 'number' }).notNull().default(0),
    deaths: integer('deaths').notNull().default(0),
    activeTimePct: real('active_time_pct'),
    provenance: jsonb('provenance').$type<Provenance>().notNull(),
    createdAt: createdAt(),
  },
  (t) => [index('encounter_metrics_character_idx').on(t.characterId)],
);

// ---------------------------------------------------------------------------
// Dungeon group finder (guild-scoped)
// ---------------------------------------------------------------------------

export const groupListings = pgTable(
  'group_listings',
  {
    id: uuid('id').primaryKey().defaultRandom(),
    guildId: uuid('guild_id')
      .notNull()
      .references(() => guilds.id, { onDelete: 'cascade' }),
    dungeonKey: text('dungeon_key').notNull(),
    note: text('note'),
    startsAt: ts('starts_at'),
    leaderUserId: uuid('leader_user_id')
      .notNull()
      .references(() => users.id, { onDelete: 'cascade' }),
    status: text('status').$type<'OPEN' | 'CLOSED'>().notNull().default('OPEN'),
    expiresAt: ts('expires_at').notNull(),
    createdAt: createdAt(),
    updatedAt: updatedAt(),
  },
  (t) => [index('group_listings_guild_idx').on(t.guildId, t.status, t.expiresAt)],
);

export const groupMembers = pgTable(
  'group_members',
  {
    listingId: uuid('listing_id')
      .notNull()
      .references(() => groupListings.id, { onDelete: 'cascade' }),
    userId: uuid('user_id')
      .notNull()
      .references(() => users.id, { onDelete: 'cascade' }),
    characterId: uuid('character_id')
      .notNull()
      .references(() => characters.id, { onDelete: 'cascade' }),
    role: text('role').$type<'TANK' | 'HEALER' | 'DPS'>().notNull(),
    joinedAt: ts('joined_at').notNull().defaultNow(),
  },
  (t) => [primaryKey({ columns: [t.listingId, t.userId] }), index('group_members_character_idx').on(t.characterId)],
);
