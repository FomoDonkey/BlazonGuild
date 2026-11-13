import { normalizeMediaUrl, type EquippedItemPayload, type CharacterEquipmentPayload } from '@blazonguild/data-providers';
import type { characters, guilds, activityEvents } from '@blazonguild/database';
import {
  EQUIPMENT_SLOTS,
  classById,
  specById,
  type ActivityEventDTO,
  type CharacterStatsDTO,
  type EquippedItemDTO,
  type GuildSummaryDTO,
  type ItemQuality,
  type Region,
  type RosterMemberDTO,
  type StatRowDTO,
} from '@blazonguild/types';

type GuildRow = typeof guilds.$inferSelect;
type CharacterRow = typeof characters.$inferSelect;
type ActivityRow = typeof activityEvents.$inferSelect;

const iso = (d: Date | null | undefined) => (d ? d.toISOString() : null);
export const displayName = (c: { name: string; surname: string | null }) => [c.name, c.surname].filter(Boolean).join(' ');

/** Same-origin media proxy path (needed for CSS masks on the crest; CDN sends no CORS headers). */
export const proxied = (url: string | null | undefined) => (url ? `/api/v1/media?url=${encodeURIComponent(url)}` : null);

export function toGuildSummary(g: GuildRow, platformMembers = 0): GuildSummaryDTO {
  return {
    id: g.id,
    region: g.region as Region,
    slug: g.slug,
    name: g.name,
    faction: g.faction,
    ruleset: g.rulesetId !== null ? { id: g.rulesetId, name: g.rulesetName ?? `Ruleset ${g.rulesetId}` } : null,
    memberCount: g.memberCount,
    crest: g.crest
      ? {
          emblemUrl: proxied(g.crest.emblemUrl),
          borderUrl: proxied(g.crest.borderUrl),
          emblemColor: g.crest.emblemColor,
          borderColor: g.crest.borderColor,
          backgroundColor: g.crest.backgroundColor,
        }
      : null,
    foundedAt: iso(g.foundedAt),
    lastSyncedAt: iso(g.lastSyncedAt),
    syncState: g.syncState,
    platformMembers,
  };
}

export function toRosterMember(c: CharacterRow, rankNames?: Record<string, string>): RosterMemberDTO {
  const spec = specById(c.primarySpecId);
  return {
    characterId: c.id,
    region: c.region as Region,
    slug: c.slug,
    name: c.name,
    surname: c.surname,
    displayName: displayName(c),
    level: c.level,
    classId: c.classId,
    raceId: c.raceId,
    faction: c.faction,
    rankIndex: c.guildRank ?? -1,
    rankName: c.guildRank !== null ? rankNames?.[String(c.guildRank)] ?? null : null,
    itemLevel: c.equippedItemLevel,
    lastLoginAt: iso(c.lastLoginAt),
    achievementPoints: c.achievementPoints,
    honorableKills: c.honorableKills,
    talentSplit: c.talentSplit,
    primarySpecId: c.primarySpecId,
    roleHint: spec?.roleHint ?? null,
    avatarUrl: c.avatarUrl,
    renderUrl: c.renderUrl,
    claimed: !!c.ownerUserId,
    detailSyncedAt: iso(c.detailSyncedAt),
  };
}

export function toActivity(
  e: ActivityRow,
  ch?: Pick<CharacterRow, 'region' | 'slug' | 'name' | 'surname' | 'classId'> | null,
): ActivityEventDTO {
  return {
    id: e.id,
    type: e.type as ActivityEventDTO['type'],
    occurredAt: e.occurredAt.toISOString(),
    character: ch ? { region: ch.region as Region, slug: ch.slug, displayName: displayName(ch), classId: ch.classId } : null,
    title: e.title,
    detail: e.detail,
    provenance: e.provenance,
  };
}

// ---------------------------------------------------------------------------
// Equipment
// ---------------------------------------------------------------------------

const KNOWN_QUALITIES = new Set(['POOR', 'COMMON', 'UNCOMMON', 'RARE', 'EPIC', 'LEGENDARY', 'ARTIFACT', 'HEIRLOOM']);

function requirementLines(req: Record<string, unknown> | undefined): string[] {
  if (!req) return [];
  const out: string[] = [];
  for (const value of Object.values(req)) {
    const v = value as { display_string?: string } | undefined;
    if (v?.display_string) out.push(v.display_string);
  }
  return out;
}

function money(sell: EquippedItemPayload['sell_price']) {
  const d = sell?.display_strings;
  if (!d) return null;
  return { gold: Number(d.gold ?? 0), silver: Number(d.silver ?? 0), copper: Number(d.copper ?? 0) };
}

function durability(text?: string) {
  const m = text?.match(/(\d+)\s*\/\s*(\d+)/);
  return m ? { current: Number(m[1]), max: Number(m[2]) } : null;
}

export function mapEquipment(payload: CharacterEquipmentPayload | null, icons: Map<number, string | null>): EquippedItemDTO[] {
  if (!payload) return [];
  const setInfo = new Map<number, { name: string; equipped: number; total: number }>();
  for (const s of payload.equipped_item_sets ?? []) {
    const info = { name: s.item_set.name ?? 'Conjunto', equipped: s.items.filter((i) => i.is_equipped).length, total: s.items.length };
    for (const it of s.items) setInfo.set(it.item.id, info);
  }
  const order = new Map(EQUIPMENT_SLOTS.map((s, i) => [s.type, i]));
  return payload.equipped_items
    .map((it): EquippedItemDTO => {
      const quality = (KNOWN_QUALITIES.has(it.quality?.type ?? '') ? it.quality!.type : 'COMMON') as ItemQuality;
      return {
        slot: it.slot.type as EquippedItemDTO['slot'],
        slotName: it.slot.name ?? it.slot.type,
        itemId: it.item.id,
        name: it.name ?? `Objeto ${it.item.id}`,
        quality,
        itemLevel: it.level?.value ?? null,
        iconUrl: normalizeMediaUrl(icons.get(it.item.id)),
        inventoryType: it.inventory_type?.name ?? null,
        itemClass: it.item_class?.name ?? null,
        itemSubclass: it.item_subclass?.name ?? null,
        binding: it.binding?.name ?? null,
        uniqueEquipped: it.unique_equipped ?? null,
        armor: it.armor?.value ?? null,
        weapon: it.weapon
          ? {
              damage: it.weapon.damage?.display_string ?? '',
              speed: it.weapon.attack_speed?.display_string ?? '',
              dps: it.weapon.dps?.display_string ?? '',
            }
          : null,
        stats: (it.stats ?? [])
          .filter((s) => !s.is_hidden)
          .map((s) => ({
            type: s.type?.type ?? null,
            text: s.display?.display_string ?? `${s.value ?? ''} ${s.type?.name ?? s.type?.type ?? ''}`.trim(),
            value: s.value ?? null,
            negative: s.is_negated ?? false,
            bonus: !!s.is_equip_bonus || (s.display?.color ? s.display.color.r === 0 && s.display.color.g === 255 : false),
          })),
        spells: (it.spells ?? []).map((s) => s.description).filter((d): d is string => !!d),
        enchantments: (it.enchantments ?? []).map((e) => e.display_string).filter((d): d is string => !!d),
        requirements: requirementLines(it.requirements),
        durability: durability(it.durability?.display_string ?? undefined),
        sellPrice: money(it.sell_price),
        set: setInfo.get(it.item.id) ?? null,
        transmog: it.transmog?.display_string?.replace(/\n/g, ' ') ?? null,
        description: it.description ?? null,
      };
    })
    .sort((a, b) => (order.get(a.slot) ?? 99) - (order.get(b.slot) ?? 99));
}

// ---------------------------------------------------------------------------
// Statistics — curated for WoW: Forever (classic-era stat model)
// ---------------------------------------------------------------------------

type Raw = Record<string, unknown>;
const num = (v: unknown): number | null => {
  if (typeof v === 'number' && Number.isFinite(v)) return v;
  if (v && typeof v === 'object') {
    const o = v as Record<string, unknown>;
    if (typeof o.effective === 'number') return o.effective;
    if (typeof o.value === 'number') return o.value;
  }
  return null;
};
const base = (v: unknown): number | undefined => {
  if (v && typeof v === 'object' && typeof (v as Raw).base === 'number') return (v as Raw).base as number;
  return undefined;
};

/**
 * Retail-only statistics returned by the Forever API with zero values. They do not exist in
 * the classic-era stat model and are never displayed: mastery, versatility*, lifesteal,
 * avoidance, speed, bonus_armor.
 */
export const RETAIL_ONLY_STATS = ['mastery', 'versatility', 'versatility_damage_done_bonus', 'versatility_healing_done_bonus', 'versatility_damage_taken_bonus', 'lifesteal', 'avoidance', 'speed', 'bonus_armor'];

export function curateStats(raw: Raw | null, classId: number): CharacterStatsDTO | null {
  if (!raw) return null;
  const cls = classById(classId);
  const row = (key: string, label: string, format: StatRowDTO['format'], opts: { hideZero?: boolean; hint?: string } = {}): StatRowDTO | null => {
    const value = num(raw[key]);
    if (value === null) return null;
    if (opts.hideZero && value === 0) return null;
    return { key, label, value, format, base: base(raw[key]), hint: opts.hint };
  };
  const compact = (rows: (StatRowDTO | null)[]) => rows.filter((r): r is StatRowDTO => r !== null);

  const mhMin = num(raw.main_hand_damage_min), mhMax = num(raw.main_hand_damage_max);
  const ohDps = num(raw.off_hand_dps) ?? 0;
  const rMin = num(raw.ranged_damage_min) ?? 0, rMax = num(raw.ranged_damage_max) ?? 0;
  const usesMana = cls?.powerType === 'MANA';

  const melee = compact([
    row('attack_power', 'Poder de ataque', 'int'),
    mhMin !== null && mhMax !== null ? { key: 'main_hand_damage', label: 'Daño mano principal', value: mhMin, base: mhMax, format: 'int', hint: 'range' } : null,
    row('main_hand_speed', 'Velocidad mano principal', 'speed'),
    row('main_hand_dps', 'DPS mano principal', 'float1'),
    ohDps > 0 ? row('off_hand_dps', 'DPS mano secundaria', 'float1') : null,
    row('melee_crit', 'Crítico cuerpo a cuerpo', 'pct'),
    row('melee_hit', 'Golpe cuerpo a cuerpo', 'pct', { hint: 'Bonificación de golpe' }),
    row('melee_haste', 'Celeridad cuerpo a cuerpo', 'pct', { hideZero: true }),
    row('expertise', 'Pericia', 'int', { hideZero: true }),
    row('armor_penetration', 'Penetración de armadura', 'int', { hideZero: true }),
  ]);
  const ranged = compact([
    row('ranged_attack_power', 'Poder de ataque a distancia', 'int'),
    rMax > 0 ? { key: 'ranged_damage', label: 'Daño a distancia', value: rMin, base: rMax, format: 'int', hint: 'range' } : null,
    row('ranged_crit', 'Crítico a distancia', 'pct'),
    row('ranged_hit', 'Golpe a distancia', 'pct'),
    row('ranged_haste', 'Celeridad a distancia', 'pct', { hideZero: true }),
  ]);
  const spell = compact([
    row('spell_power', 'Poder con hechizos', 'int', { hideZero: !usesMana }),
    row('spell_healing', 'Sanación con hechizos', 'int', { hideZero: true }),
    row('spell_crit', 'Crítico con hechizos', 'pct', { hideZero: !usesMana }),
    row('spell_hit', 'Golpe con hechizos', 'pct', { hideZero: !usesMana }),
    row('spell_haste', 'Celeridad con hechizos', 'pct', { hideZero: true }),
    row('spell_penetration', 'Penetración de hechizos', 'int', { hideZero: true }),
    usesMana ? row('mana_regen', 'Regeneración de maná (fuera de combate)', 'float1') : null,
    usesMana ? row('mana_regen_combat', 'Regeneración de maná (en combate)', 'float1') : null,
  ]);
  const defense = compact([
    row('armor', 'Armadura', 'int'),
    row('defense', 'Defensa', 'int'),
    row('dodge', 'Esquivar', 'pct'),
    row('parry', 'Parar', 'pct', { hideZero: true }),
    row('block', 'Bloquear', 'pct', { hideZero: true }),
  ]);
  const resistances = compact([
    row('fire_resistance', 'Fuego', 'int'),
    row('frost_resistance', 'Escarcha', 'int'),
    row('nature_resistance', 'Naturaleza', 'int'),
    row('shadow_resistance', 'Sombras', 'int'),
    row('arcane_resistance', 'Arcano', 'int'),
  ]);

  const power = raw.power_type as { name?: string } | undefined;
  return {
    health: num(raw.health),
    power: num(raw.power),
    powerType: power?.name ?? null,
    attributes: compact([
      row('strength', 'Fuerza', 'int'),
      row('agility', 'Agilidad', 'int'),
      row('stamina', 'Aguante', 'int'),
      row('intellect', 'Intelecto', 'int'),
      row('spirit', 'Espíritu', 'int'),
    ]),
    sections: [
      { key: 'melee' as const, label: 'Cuerpo a cuerpo', rows: melee },
      { key: 'ranged' as const, label: 'A distancia', rows: ranged },
      { key: 'spell' as const, label: 'Hechizos', rows: spell },
      { key: 'defense' as const, label: 'Defensa', rows: defense },
      { key: 'resistances' as const, label: 'Resistencias', rows: resistances },
    ].filter((s) => s.rows.length > 0),
  };
}
