/**
 * BlazonGuild Core API v1 — response contracts shared by the API and the web platform.
 * Dates are ISO 8601 UTC strings. `null` always means "unknown / not available", never zero.
 */
import type { CombatRole, Faction, ItemQuality, Region, SlotType, RaidInstanceKey } from './game';
import type { Provenance } from './provenance';
import type { GuildRole, Permission, PlatformRole } from './roles';

export interface Page<T> {
  items: T[];
  total: number;
  page: number;
  pageSize: number;
}

export interface ApiErrorBody {
  error: { code: string; message: string; details?: unknown };
}

// ---------------------------------------------------------------------------
// Guilds
// ---------------------------------------------------------------------------

export interface GuildCrestDTO {
  emblemUrl: string | null;
  borderUrl: string | null;
  emblemColor: string;
  borderColor: string;
  backgroundColor: string;
}

export type SyncState = 'NEVER' | 'RUNNING' | 'OK' | 'PARTIAL' | 'ERROR';

export interface GuildSummaryDTO {
  id: string;
  region: Region;
  slug: string;
  name: string;
  faction: Faction;
  ruleset: { id: number; name: string } | null;
  memberCount: number;
  crest: GuildCrestDTO | null;
  /** In-game founding date reported by Battle.net. */
  foundedAt: string | null;
  lastSyncedAt: string | null;
  syncState: SyncState;
  platformMembers: number;
}

export interface ViewerContextDTO {
  authenticated: boolean;
  role: GuildRole;
  permissions: Permission[];
}

export interface DistributionBucket {
  key: string;
  label: string;
  count: number;
}

export interface GuildHighlightDTO {
  metric: string;
  label: string;
  value: number;
  unit: string;
  member: RosterMemberDTO;
  provenance: Provenance;
}

export interface GuildOverviewDTO {
  guild: GuildSummaryDTO;
  viewer: ViewerContextDTO;
  stats: {
    members: number;
    averageLevel: number | null;
    medianLevel: number | null;
    maxLevel: number | null;
    atLevelCap: number;
    /** Characters whose full profile has been synchronised (activity/ilvl need it). */
    detailedMembers: number;
    activeLast7d: number | null;
    activeLast30d: number | null;
    averageItemLevel: number | null;
    classDistribution: DistributionBucket[];
    levelDistribution: DistributionBucket[];
    rankDistribution: DistributionBucket[];
  };
  highlights: GuildHighlightDTO[];
  /** Up to 5 characters to feature (guild master first, then officers, then highest level) that have a 3D render. */
  lineup: RosterMemberDTO[];
  recentActivity: ActivityEventDTO[];
  upcomingRaids: RaidSummaryDTO[] | null;
  provenance: Provenance;
}

export interface RosterMemberDTO {
  characterId: string;
  region: Region;
  slug: string;
  name: string;
  surname: string | null;
  displayName: string;
  level: number;
  classId: number;
  raceId: number | null;
  faction: Faction | null;
  rankIndex: number;
  rankName: string | null;
  itemLevel: number | null;
  lastLoginAt: string | null;
  achievementPoints: number | null;
  honorableKills: number | null;
  /** Points per talent tree, in the class' tree order, e.g. [5, 2, 36]. */
  talentSplit: number[] | null;
  primarySpecId: number | null;
  roleHint: CombatRole | null;
  avatarUrl: string | null;
  /** Full-body transparent render (1600×1200 PNG). */
  renderUrl: string | null;
  claimed: boolean;
  detailSyncedAt: string | null;
}

export type RosterSortKey = 'name' | 'level' | 'class' | 'rank' | 'itemLevel' | 'lastLogin' | 'honorableKills';

// ---------------------------------------------------------------------------
// Activity
// ---------------------------------------------------------------------------

export type ActivityType =
  | 'GUILD_TRACKED'
  | 'MEMBER_JOINED'
  | 'MEMBER_LEFT'
  | 'RANK_CHANGED'
  | 'LEVEL_UP'
  | 'ITEM_EQUIPPED'
  | 'ACHIEVEMENT'
  | 'RAID_SCHEDULED';

export interface ActivityEventDTO {
  id: string;
  type: ActivityType;
  occurredAt: string;
  character: { region: Region; slug: string; displayName: string; classId: number } | null;
  title: string;
  detail: Record<string, unknown>;
  provenance: Provenance;
}

// ---------------------------------------------------------------------------
// Characters / Armory
// ---------------------------------------------------------------------------

export interface ItemStatLineDTO {
  type: string | null;
  text: string;
  value: number | null;
  negative?: boolean;
  /** Green tooltip line (equip bonus / secondary effect), as rendered in-game. */
  bonus?: boolean;
}

export interface EquippedItemDTO {
  slot: SlotType;
  slotName: string;
  itemId: number;
  name: string;
  quality: ItemQuality;
  itemLevel: number | null;
  iconUrl: string | null;
  inventoryType: string | null;
  itemClass: string | null;
  itemSubclass: string | null;
  binding: string | null;
  uniqueEquipped: string | null;
  armor: number | null;
  weapon: { damage: string; speed: string; dps: string } | null;
  stats: ItemStatLineDTO[];
  spells: string[];
  enchantments: string[];
  requirements: string[];
  durability: { current: number; max: number } | null;
  sellPrice: { gold: number; silver: number; copper: number } | null;
  set: { name: string; equipped: number; total: number } | null;
  transmog: string | null;
  description: string | null;
}

export type StatFormat = 'int' | 'pct' | 'float1' | 'float2' | 'speed';

export interface StatRowDTO {
  key: string;
  label: string;
  value: number;
  format: StatFormat;
  base?: number;
  hint?: string;
}

export interface CharacterStatsDTO {
  health: number | null;
  power: number | null;
  powerType: string | null;
  attributes: StatRowDTO[];
  sections: { key: 'melee' | 'ranged' | 'spell' | 'defense' | 'resistances'; label: string; rows: StatRowDTO[] }[];
}

export interface TalentNodeDTO {
  id: number;
  row: number;
  col: number;
  maxRank: number;
  rank: number;
  talentId: number | null;
  name: string;
  description: string | null;
  iconUrl: string | null;
  lockedBy: number[];
}

export interface TalentTreeDTO {
  specId: number;
  name: string;
  iconUrl: string | null;
  spentPoints: number;
  rows: number;
  cols: number;
  nodes: TalentNodeDTO[];
}

export interface TalentLoadoutDTO {
  treeId: number;
  totalPoints: number;
  trees: TalentTreeDTO[];
  provenance: Provenance;
}

export interface CharacterSnapshotPointDTO {
  takenAt: string;
  level: number;
  itemLevel: number | null;
  achievementPoints: number | null;
}

export interface CharacterArmoryDTO {
  character: {
    id: string;
    region: Region;
    slug: string;
    name: string;
    surname: string | null;
    displayName: string;
    level: number;
    classId: number;
    raceId: number | null;
    gender: string | null;
    faction: Faction | null;
    achievementPoints: number | null;
    averageItemLevel: number | null;
    equippedItemLevel: number | null;
    lastLoginAt: string | null;
    guild: { region: Region; slug: string; name: string; rankIndex: number | null; tracked: boolean } | null;
    ruleset: { id: number; name: string } | null;
  };
  media: { avatarUrl: string | null; renderUrl: string | null };
  equipment: EquippedItemDTO[];
  stats: CharacterStatsDTO | null;
  talents: TalentLoadoutDTO | null;
  professions: { id: number; name: string; skill: number; max: number; kind: 'primary' | 'secondary' }[];
  pvp: { honorableKills: number; rank: number } | null;
  recentAchievements: { id: number; name: string; completedAt: string }[];
  history: CharacterSnapshotPointDTO[];
  ownership: { claimed: boolean; verified: boolean; isViewer: boolean };
  syncedAt: string | null;
  provenance: Provenance;
}

// ---------------------------------------------------------------------------
// Raids
// ---------------------------------------------------------------------------

export type RaidStatus = 'SCHEDULED' | 'IN_PROGRESS' | 'COMPLETED' | 'CANCELLED';
export type SignupStatus = 'CONFIRMED' | 'TENTATIVE' | 'DECLINED' | 'BENCHED';

export interface RaidSummaryDTO {
  id: string;
  guild: { region: Region; slug: string; name: string };
  title: string;
  instanceKey: RaidInstanceKey;
  instanceName: string;
  startsAt: string;
  endsAt: string | null;
  status: RaidStatus;
  capacity: number;
  minLevel: number | null;
  leader: string | null;
  counts: {
    confirmed: number;
    tentative: number;
    declined: number;
    benched: number;
    roles: Record<CombatRole, number>;
  };
  viewerSignup: { status: SignupStatus; characterSlug: string } | null;
}

export interface RaidSignupDTO {
  id: string;
  character: { id: string; slug: string; displayName: string; classId: number; level: number; itemLevel: number | null };
  userDisplayName: string;
  status: SignupStatus;
  role: CombatRole;
  comment: string | null;
  group: number | null;
  slot: number | null;
  signedUpAt: string;
  isViewer: boolean;
}

export interface RaidDetailDTO extends RaidSummaryDTO {
  notes: string | null;
  signups: RaidSignupDTO[];
  viewer: ViewerContextDTO & { characters: { id: string; slug: string; displayName: string; classId: number; level: number }[] };
  createdAt: string;
  updatedAt: string;
}

// ---------------------------------------------------------------------------
// Rankings
// ---------------------------------------------------------------------------

export type RankingMetric =
  | 'level'
  | 'item_level'
  | 'honorable_kills'
  | 'achievement_points'
  | 'profession_skill'
  | 'dps'
  | 'hps'
  | 'attendance';

export interface RankingMethodologyDTO {
  calculation: string;
  period: string;
  eligibility: string;
  source: string;
  verification: string;
  sorting: string;
}

export interface RankingBoardDTO {
  metric: RankingMetric;
  label: string;
  unit: string;
  available: boolean;
  unavailableReason: string | null;
  methodology: RankingMethodologyDTO;
  sampleSize: number;
  eligibleTotal: number;
  entries: { position: number; member: RosterMemberDTO; value: number; detail: string | null }[];
  provenance: Provenance;
}

// ---------------------------------------------------------------------------
// Session / users
// ---------------------------------------------------------------------------

export interface MeDTO {
  user: { id: string; email: string; displayName: string; role: PlatformRole; battleTag: string | null; createdAt: string };
  memberships: { guild: Pick<GuildSummaryDTO, 'id' | 'region' | 'slug' | 'name' | 'faction' | 'crest'>; role: GuildRole; verified: boolean }[];
  characters: { id: string; region: Region; slug: string; displayName: string; classId: number; level: number; verified: boolean; isMain: boolean; guildSlug: string | null }[];
}

export interface SearchResultDTO {
  query: string;
  guilds: Pick<GuildSummaryDTO, 'region' | 'slug' | 'name' | 'faction' | 'memberCount' | 'crest'>[];
  characters: { region: Region; slug: string; displayName: string; level: number; classId: number; guildName: string | null }[];
}

export interface AuditEntryDTO {
  id: string;
  at: string;
  actor: string | null;
  action: string;
  entity: string;
  entityId: string;
  changes: unknown;
}

export interface SyncJobDTO {
  id: string;
  kind: string;
  target: string;
  state: 'QUEUED' | 'RUNNING' | 'OK' | 'PARTIAL' | 'ERROR';
  startedAt: string | null;
  finishedAt: string | null;
  stats: Record<string, number>;
  error: string | null;
}
