import { z } from 'zod';

/**
 * Defensive schemas for the WoW: Forever Battle.net API.
 * Only the fields BlazonGuild consumes are validated; everything else passes through
 * (z.looseObject) so that Blizzard adding fields never breaks ingestion.
 * Shapes verified against live responses on 2026-11-09 and 2026-11-12.
 */

const ref = z.looseObject({ id: z.number(), name: z.string().nullish() });
const typed = z.looseObject({ type: z.string(), name: z.string().nullish() });
const rgba = z.looseObject({ r: z.number(), g: z.number(), b: z.number(), a: z.number().nullish() });

export const OAuthTokenSchema = z.looseObject({
  access_token: z.string(),
  token_type: z.string(),
  expires_in: z.number(),
  scope: z.string().nullish(),
  id_token: z.string().nullish(),
});

export const GuildSchema = z.looseObject({
  id: z.number(),
  name: z.string(),
  slug: z.string(),
  faction: typed,
  achievement_points: z.number().nullish(),
  member_count: z.number().nullish(),
  created_timestamp: z.number().nullish(),
  ruleset: ref.optional(),
  crest: z
    .looseObject({
      emblem: z.looseObject({ id: z.number(), media: z.looseObject({ id: z.number() }).optional(), color: z.looseObject({ rgba }) }).optional(),
      border: z.looseObject({ id: z.number(), media: z.looseObject({ id: z.number() }).optional(), color: z.looseObject({ rgba }) }).optional(),
      background: z.looseObject({ color: z.looseObject({ rgba }) }).optional(),
    })
    .optional(),
});
export type GuildPayload = z.infer<typeof GuildSchema>;

export const GuildRosterSchema = z.looseObject({
  guild: z.looseObject({ id: z.number(), name: z.string(), slug: z.string().nullish() }).optional(),
  members: z
    .array(
      z.looseObject({
        rank: z.number(),
        character: z.looseObject({
          id: z.number(),
          name: z.string(),
          surname: z.string().nullish(),
          slug: z.string(),
          level: z.number(),
          playable_class: z.looseObject({ id: z.number() }),
          playable_race: z.looseObject({ id: z.number() }).optional(),
          faction: z.looseObject({ type: z.string() }).optional(),
        }),
      }),
    )
    .default([]),
});
export type GuildRosterPayload = z.infer<typeof GuildRosterSchema>;

export const CharacterProfileSchema = z.looseObject({
  id: z.number(),
  name: z.string(),
  surname: z.string().nullish(),
  gender: typed.optional(),
  faction: typed.optional(),
  race: ref.optional(),
  character_class: ref,
  guild: z.looseObject({ id: z.number(), name: z.string(), slug: z.string() }).optional(),
  level: z.number(),
  experience: z.number().nullish(),
  achievement_points: z.number().nullish(),
  last_login_timestamp: z.number().nullish(),
  average_item_level: z.number().nullish(),
  equipped_item_level: z.number().nullish(),
  ruleset: ref.optional(),
  active_title: z.looseObject({ name: z.string().nullish(), display_string: z.string().nullish() }).optional(),
});
export type CharacterProfilePayload = z.infer<typeof CharacterProfileSchema>;

const displayString = z.looseObject({ display_string: z.string().nullish() });

export const EquippedItemSchema = z.looseObject({
  item: z.looseObject({ id: z.number() }),
  slot: typed,
  quality: typed.optional(),
  name: z.string().nullish(),
  level: z.looseObject({ value: z.number() }).optional(),
  media: z.looseObject({ id: z.number() }).optional(),
  item_class: ref.optional(),
  item_subclass: ref.optional(),
  inventory_type: typed.optional(),
  binding: typed.optional(),
  unique_equipped: z.string().nullish(),
  armor: z.looseObject({ value: z.number() }).optional(),
  weapon: z
    .looseObject({
      damage: displayString.optional(),
      attack_speed: displayString.optional(),
      dps: displayString.optional(),
    })
    .optional(),
  stats: z
    .array(
      z.looseObject({
        // Summary lines such as "+1 a todas las resistencias" carry no type.
        type: typed.optional(),
        value: z.number().nullish(),
        is_negated: z.boolean().nullish(),
        is_hidden: z.boolean().nullish(),
        is_equip_bonus: z.boolean().nullish(),
        display: z.looseObject({ display_string: z.string(), color: rgba.optional() }).optional(),
      }),
    )
    .optional(),
  spells: z.array(z.looseObject({ description: z.string().nullish(), spell: ref.optional() })).optional(),
  enchantments: z.array(z.looseObject({ display_string: z.string().nullish() })).optional(),
  requirements: z.record(z.string(), z.unknown()).optional(),
  durability: z.looseObject({ value: z.number().nullish(), display_string: z.string().nullish() }).optional(),
  sell_price: z
    .looseObject({ value: z.number().nullish(), display_strings: z.record(z.string(), z.string()).optional() })
    .optional(),
  set: z.unknown().optional(),
  transmog: z.looseObject({ display_string: z.string().nullish() }).optional(),
  description: z.string().nullish(),
});
export type EquippedItemPayload = z.infer<typeof EquippedItemSchema>;

export const CharacterEquipmentSchema = z.looseObject({
  // Items are validated one by one: an unexpected shape drops that item only, never the whole gear.
  equipped_items: z
    .array(z.unknown())
    .default([])
    .transform((list) => list.flatMap((raw) => {
      const r = EquippedItemSchema.safeParse(raw);
      return r.success ? [r.data] : [];
    })),
  rejected_items: z.unknown().optional(),
  equipped_item_sets: z
    .array(
      z.looseObject({
        item_set: ref,
        items: z.array(z.looseObject({ item: ref, is_equipped: z.boolean().nullish() })).default([]),
      }),
    )
    .optional(),
});
export type CharacterEquipmentPayload = z.infer<typeof CharacterEquipmentSchema>;

/** Statistics are kept as a loose record and curated per game version in the API. */
export const CharacterStatisticsSchema = z.record(z.string(), z.unknown());
export type CharacterStatisticsPayload = z.infer<typeof CharacterStatisticsSchema>;

export const CharacterSpecializationsSchema = z.looseObject({
  specialization_groups: z
    .array(
      z.looseObject({
        is_active: z.boolean().nullish(),
        specializations: z
          .array(
            z.looseObject({
              specialization: ref,
              spent_points: z.number().nullish(),
              talents: z
                .array(
                  z.looseObject({
                    talent: ref,
                    talent_rank: z.number().nullish(),
                    spell_tooltip: z
                      .looseObject({ spell: ref.optional(), description: z.string().nullish() })
                      .optional(),
                  }),
                )
                .default([]),
            }),
          )
          .default([]),
      }),
    )
    .default([]),
});
export type CharacterSpecializationsPayload = z.infer<typeof CharacterSpecializationsSchema>;

export const MediaAssetsSchema = z.looseObject({
  assets: z.array(z.looseObject({ key: z.string(), value: z.string(), file_data_id: z.number().nullish() })).default([]),
});
export type MediaAssetsPayload = z.infer<typeof MediaAssetsSchema>;

export const PvpSummarySchema = z.looseObject({
  honorable_kills: z.number().nullish(),
  pvp_rank: z.number().nullish(),
});

const professionTier = z.looseObject({
  skill_points: z.number().nullish(),
  max_skill_points: z.number().nullish(),
  tier: ref.optional(),
});
const profession = z.looseObject({
  profession: ref,
  skill_points: z.number().nullish(),
  max_skill_points: z.number().nullish(),
  tiers: z.array(professionTier).optional(),
});
export const ProfessionsSchema = z.looseObject({
  primaries: z.array(profession).optional(),
  secondaries: z.array(profession).optional(),
});
export type ProfessionsPayload = z.infer<typeof ProfessionsSchema>;

export const AchievementsSummarySchema = z.looseObject({
  total_quantity: z.number().nullish(),
  total_points: z.number().nullish(),
  recent_events: z.array(z.looseObject({ achievement: ref, timestamp: z.number() })).optional(),
});
export type AchievementsSummaryPayload = z.infer<typeof AchievementsSummarySchema>;

export const SpecTalentTreeSchema = z.looseObject({
  id: z.number(),
  name: z.string().nullish(),
  playable_specialization: ref.optional(),
  spec_talent_nodes: z
    .array(
      z.looseObject({
        id: z.number(),
        display_row: z.number(),
        display_col: z.number(),
        locked_by: z.array(z.number()).optional(),
        unlocks: z.array(z.number()).optional(),
        ranks: z
          .array(
            z.looseObject({
              rank: z.number(),
              tooltip: z
                .looseObject({
                  talent: ref.optional(),
                  spell_tooltip: z.looseObject({ spell: ref.optional(), description: z.string().nullish() }).optional(),
                })
                .optional(),
            }),
          )
          .default([]),
      }),
    )
    .default([]),
});
export type SpecTalentTreePayload = z.infer<typeof SpecTalentTreeSchema>;

export const UserWowProfileSchema = z.looseObject({
  id: z.number().nullish(),
  wow_accounts: z
    .array(
      z.looseObject({
        id: z.number().nullish(),
        characters: z
          .array(
            z.looseObject({
              id: z.number(),
              name: z.string(),
              surname: z.string().nullish(),
              slug: z.string().nullish(),
              level: z.number().nullish(),
              playable_class: z.looseObject({ id: z.number() }).optional(),
              playable_race: z.looseObject({ id: z.number() }).optional(),
              faction: z.looseObject({ type: z.string() }).optional(),
              realm: z.looseObject({ slug: z.string().nullish() }).optional(),
            }),
          )
          .default([]),
      }),
    )
    .default([]),
});
export type UserWowProfilePayload = z.infer<typeof UserWowProfileSchema>;

export const UserInfoSchema = z.looseObject({ id: z.number(), sub: z.string().nullish(), battletag: z.string().nullish() });
