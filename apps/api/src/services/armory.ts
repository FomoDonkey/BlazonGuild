import type { CharacterEquipmentPayload, CharacterSpecializationsPayload } from '@blazonguild/data-providers';
import { and, asc, characterSnapshots, characters, desc, eq, guilds, inArray, items } from '@blazonguild/database';
import {
  blizzardProvenance,
  classById,
  type CharacterArmoryDTO,
  type Region,
  type TalentLoadoutDTO,
  type TalentTreeDTO,
} from '@blazonguild/types';
import { BlizzardApiError, normalizeMediaUrl } from '@blazonguild/data-providers';
import type { AppDeps } from '../context';
import { notFound, upstream } from '../lib/errors';
import { curateStats, displayName, mapEquipment } from './mappers';

type CharacterRow = typeof characters.$inferSelect;
const VIEW_STALE_MS = 60 * 60 * 1000;

export async function getOrSyncCharacter(deps: AppDeps, region: Region, slug: string, userId: string | null): Promise<CharacterRow> {
  const key = slug.trim().toLowerCase();
  let row = (await deps.db.select().from(characters).where(and(eq(characters.region, region), eq(characters.slug, key))).limit(1))[0];
  const fresh = row?.detailSyncedAt && row.detailState === 'OK' && deps.now().getTime() - row.detailSyncedAt.getTime() < VIEW_STALE_MS;
  if (!row || row.detailState !== 'OK') {
    try {
      const synced = await deps.sync.syncCharacter(region, key, { trigger: 'VIEW', userId });
      if (!synced) throw notFound(`El personaje «${slug}» no existe en ${region.toUpperCase()} (o su perfil es privado)`);
      row = synced;
    } catch (err) {
      if (err instanceof BlizzardApiError) {
        if (row) return row; // serve what we have
        throw upstream('Battle.net no responde ahora mismo. Inténtalo de nuevo en unos minutos.');
      }
      throw err;
    }
  } else if (!fresh) {
    void deps.sync.syncCharacter(region, key, { trigger: 'VIEW' }).catch((err) => deps.log.warn('background character refresh failed', { slug: key, err: String(err) }));
  }
  return row;
}

export async function buildTalents(deps: AppDeps, region: Region, classId: number, payload: CharacterSpecializationsPayload | null, collectedAt: Date | null): Promise<TalentLoadoutDTO | null> {
  const cls = classById(classId);
  if (!cls) return null;
  const group = payload?.specialization_groups.find((g) => g.is_active) ?? payload?.specialization_groups[0];
  const trees: TalentTreeDTO[] = await Promise.all(
    cls.specs.map(async (spec) => {
      const [tree, specIcon] = await Promise.all([deps.staticData.talentTree(region, spec.treeId, spec.id), deps.staticData.specIcon(region, spec.id)]);
      const charSpec = group?.specializations.find((s) => s.specialization.id === spec.id);
      const rankByTalent = new Map((charSpec?.talents ?? []).map((t) => [t.talent.id, t.talent_rank ?? 0]));
      // Battle.net numbers columns globally across the three trees (1–4, 7–10, 14–17): normalise per tree.
      const minCol = Math.min(...(tree?.spec_talent_nodes ?? []).map((n) => n.display_col), Infinity);
      const minRow = Math.min(...(tree?.spec_talent_nodes ?? []).map((n) => n.display_row), Infinity);
      const nodes = await Promise.all(
        (tree?.spec_talent_nodes ?? []).map(async (n) => {
          const first = n.ranks[0]?.tooltip;
          const talentId = first?.talent?.id ?? null;
          const rank = talentId !== null ? rankByTalent.get(talentId) ?? 0 : 0;
          const shown = n.ranks[Math.max(rank, 1) - 1]?.tooltip ?? first;
          const spellId = first?.spell_tooltip?.spell?.id;
          return {
            id: n.id,
            row: n.display_row - minRow + 1,
            col: n.display_col - minCol + 1,
            maxRank: n.ranks.length,
            rank,
            talentId,
            name: first?.talent?.name ?? first?.spell_tooltip?.spell?.name ?? 'Talento',
            description: shown?.spell_tooltip?.description ?? null,
            iconUrl: spellId ? normalizeMediaUrl(await deps.staticData.spellIcon(region, spellId)) : null,
            lockedBy: n.locked_by ?? [],
          };
        }),
      );
      const spentFromNodes = nodes.reduce((sum, n) => sum + n.rank, 0);
      return {
        specId: spec.id,
        name: tree?.playable_specialization?.name ?? spec.nameEs,
        iconUrl: normalizeMediaUrl(specIcon),
        spentPoints: charSpec?.spent_points ?? spentFromNodes,
        rows: Math.max(7, ...nodes.map((n) => n.row)),
        cols: Math.max(4, ...nodes.map((n) => n.col)),
        nodes,
      };
    }),
  );
  return {
    treeId: cls.specs[0].treeId,
    totalPoints: trees.reduce((s, t) => s + t.spentPoints, 0),
    trees,
    provenance: blizzardProvenance(collectedAt, { endpoint: 'specializations + talent-tree', method: 'talent ids matched to static tree nodes' }),
  };
}

export async function buildArmory(deps: AppDeps, row: CharacterRow, viewerId: string | null): Promise<CharacterArmoryDTO> {
  const region = row.region as Region;
  const snapshots = await deps.db
    .select({ id: characterSnapshots.id, takenAt: characterSnapshots.takenAt, level: characterSnapshots.level, itemLevel: characterSnapshots.itemLevel, achievementPoints: characterSnapshots.achievementPoints })
    .from(characterSnapshots)
    .where(eq(characterSnapshots.characterId, row.id))
    .orderBy(asc(characterSnapshots.takenAt));
  const latestId = snapshots[snapshots.length - 1]?.id;
  const latest = latestId ? (await deps.db.select().from(characterSnapshots).where(eq(characterSnapshots.id, latestId)).limit(1))[0] : undefined;

  const equipmentPayload = (latest?.equipment ?? null) as CharacterEquipmentPayload | null;
  const itemIds = equipmentPayload?.equipped_items.map((i) => i.item.id) ?? [];
  if (itemIds.length) await deps.staticData.ensureItemIcons(region, itemIds);
  const iconRows = itemIds.length ? await deps.db.select({ id: items.id, iconUrl: items.iconUrl }).from(items).where(inArray(items.id, itemIds)) : [];
  const icons = new Map(iconRows.map((r) => [r.id, r.iconUrl]));

  const profile = (latest?.profile ?? {}) as { guild?: { slug: string; name: string }; ruleset?: { id: number; name?: string } };
  const guildRow = row.guildId ? (await deps.db.select().from(guilds).where(eq(guilds.id, row.guildId)).limit(1))[0] : undefined;
  const ach = (latest?.achievements ?? null) as { recent_events?: { achievement: { id: number; name?: string }; timestamp: number }[] } | null;
  const pvp = (latest?.pvp ?? null) as { honorable_kills?: number; pvp_rank?: number } | null;

  return {
    character: {
      id: row.id,
      region,
      slug: row.slug,
      name: row.name,
      surname: row.surname,
      displayName: displayName(row),
      level: row.level,
      classId: row.classId,
      raceId: row.raceId,
      gender: row.gender,
      faction: row.faction,
      achievementPoints: row.achievementPoints,
      averageItemLevel: row.averageItemLevel,
      equippedItemLevel: row.equippedItemLevel,
      lastLoginAt: row.lastLoginAt?.toISOString() ?? null,
      guild: guildRow
        ? { region: guildRow.region as Region, slug: guildRow.slug, name: guildRow.name, rankIndex: row.guildRank, tracked: true }
        : profile.guild
          ? { region, slug: profile.guild.slug, name: profile.guild.name, rankIndex: null, tracked: false }
          : null,
      ruleset: profile.ruleset ? { id: profile.ruleset.id, name: profile.ruleset.name ?? `Ruleset ${profile.ruleset.id}` } : null,
    },
    media: { avatarUrl: row.avatarUrl, renderUrl: row.renderUrl },
    equipment: mapEquipment(equipmentPayload, icons),
    stats: curateStats((latest?.statistics ?? null) as Record<string, unknown> | null, row.classId),
    talents: await buildTalents(deps, region, row.classId, (latest?.specializations ?? null) as CharacterSpecializationsPayload | null, latest?.takenAt ?? null),
    professions: row.professions ?? [],
    pvp: pvp && typeof pvp.honorable_kills === 'number' ? { honorableKills: pvp.honorable_kills, rank: pvp.pvp_rank ?? 0 } : null,
    recentAchievements: (ach?.recent_events ?? [])
      .slice(0, 8)
      .map((e) => ({ id: e.achievement.id, name: e.achievement.name ?? `Logro ${e.achievement.id}`, completedAt: new Date(e.timestamp).toISOString() })),
    history: snapshots.map((s) => ({ takenAt: s.takenAt.toISOString(), level: s.level, itemLevel: s.itemLevel, achievementPoints: s.achievementPoints })),
    ownership: { claimed: !!row.ownerUserId, verified: row.ownershipVerified, isViewer: !!viewerId && row.ownerUserId === viewerId },
    syncedAt: row.detailSyncedAt?.toISOString() ?? null,
    provenance: latest?.provenance ?? blizzardProvenance(row.detailSyncedAt),
  };
}

export async function recentSnapshots(deps: AppDeps, characterId: string, limit = 50) {
  return deps.db.select().from(characterSnapshots).where(eq(characterSnapshots.characterId, characterId)).orderBy(desc(characterSnapshots.takenAt)).limit(limit);
}
