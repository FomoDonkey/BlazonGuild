# FOREVER Battle.net API Integration Validation Report

**Execution Date:** 2026-11-09T19:52:52.042Z
**Target:** World of Warcraft: Forever (Official)
**Region:** EU | **Ruleset:** 1 | **Locale:** es_ES

## Endpoint Verification Matrix

| Target | Endpoint / Resource | Classification | HTTP Status | Latency | Outcome | Notes |
| :--- | :--- | :---: | :---: | :---: | :---: | :--- |
| **OAuth Client Credentials** | `https://oauth.battle.net/token` | `OFFICIALLY_DOCUMENTED` | `200` | 811ms | **PASS** | Token acquired successfully. Expires in: 86399s |
| **Ruleset Index** | `/data/wow/ruleset/index?namespace=dynamic-forever-eu&locale=es_ES` | `COMMUNITY_PROBED` | `200` | 133ms | **PASS** | Valid JSON returned (_links, rulesets) |
| **Ruleset Detail (ID: 1 - JcJ)** | `/data/wow/ruleset/1?namespace=dynamic-forever-eu&locale=es_ES` | `COMMUNITY_PROBED` | `200` | 71ms | **PASS** | Valid JSON returned (_links, id, name, auctions, status) |
| **Character Profile** | `/profile/wow/character/el-peregrino?namespace=profile-forever-eu&locale=es_ES` | `COMMUNITY_PROBED` | `200` | 66ms | **PASS** | Valid JSON returned (_links, id, name, gender, faction, race, character_class, guild, level, experience, achievement_points, achievements, titles, pvp_summary, encounters, media, last_login_timestamp, average_item_level, equipped_item_level, specializations, statistics, mythic_keystone_profile, equipment, appearance, collections, reputations, quests, achievements_statistics, professions, is_remix, surname, ruleset, name_search) |
| **Character Equipment** | `/profile/wow/character/el-peregrino/equipment?namespace=profile-forever-eu&locale=es_ES` | `COMMUNITY_PROBED` | `200` | 68ms | **PASS** | Valid JSON returned (_links, character, equipped_items, equipped_item_sets) |
| **Character Statistics** | `/profile/wow/character/el-peregrino/statistics?namespace=profile-forever-eu&locale=es_ES` | `COMMUNITY_PROBED` | `200` | 66ms | **PASS** | Valid JSON returned (_links, health, power, power_type, speed, strength, agility, intellect, stamina, melee_crit, melee_haste, mastery, bonus_armor, lifesteal, versatility, versatility_damage_done_bonus, versatility_healing_done_bonus, versatility_damage_taken_bonus, avoidance, attack_power, main_hand_damage_min, main_hand_damage_max, main_hand_speed, main_hand_dps, off_hand_damage_min, off_hand_damage_max, off_hand_speed, off_hand_dps, spell_power, spell_penetration, spell_crit, mana_regen, mana_regen_combat, armor, dodge, parry, block, ranged_crit, ranged_haste, spell_haste, character, spirit, defense, fire_resistance, shadow_resistance, nature_resistance, arcane_resistance, frost_resistance, movement_speed, ranged_attack_power, ranged_damage_min, ranged_damage_max, expertise, off_hand_expertise, armor_penetration, spell_healing, melee_hit, off_hand_hit, ranged_hit, spell_hit) |
| **Character Specializations/Traits** | `/profile/wow/character/el-peregrino/specializations?namespace=profile-forever-eu&locale=es_ES` | `PENDING_VALIDATION` | `200` | 103ms | **PASS** | Valid JSON returned (_links, character, specialization_groups) |
| **Character Media** | `/profile/wow/character/el-peregrino/character-media?namespace=profile-forever-eu&locale=es_ES` | `PENDING_VALIDATION` | `200` | 100ms | **PASS** | Valid JSON returned (_links, character, assets) |
| **Guild Roster** | `/data/wow/guild/forever/roster?namespace=profile-forever-eu&locale=es_ES` | `COMMUNITY_PROBED` | `200` | 64ms | **PASS** | Valid JSON returned (_links, guild, members) |
| **Guild Activity** | `/data/wow/guild/forever/activity?namespace=profile-forever-eu&locale=es_ES` | `PENDING_VALIDATION` | `200` | 71ms | **PASS** | Valid JSON returned (_links, guild) |

## Sample Response Payloads & Field Schemas

### Ruleset Index
```json
{
  "_links": {
    "self": {
      "href": "https://eu.api.blizzard.com/data/wow/ruleset/?namespace=dynamic-forever-eu"
    }
  },
  "rulesets": [
    {
      "key": {
        "href": "https://eu.api.blizzard.com/data/wow/ruleset/1?namespace=dynamic-forever-eu"
      },
      "id": 1
    },
    {
      "key": {
        "href": "https://eu.api.blizzard.com/data/wow/ruleset/15?namespace=dynamic-forever-eu"
      },
      "id": 15
    },
    {
      "key": {
        "href": "https://eu.api.blizzard.com/data/wow/ruleset/3?namespace=dynamic-forever-eu"
      },
      "id": 3
    },
    {
      "key": {
        "href": "https://eu.api.blizzard.com/data/wow/ruleset/2?namespace=dynamic-forever-eu"
      },
      "id": 2
    }
  ]
}
```

### Ruleset Detail (ID: 1 - JcJ)
```json
{
  "_links": {
    "self": {
      "href": "https://eu.api.blizzard.com/data/wow/ruleset/1?namespace=dynamic-forever-eu"
    }
  },
  "id": 1,
  "name": "JcJ",
  "auctions": {
    "href": "https://eu.api.blizzard.com/data/wow/ruleset/1/auctions/?namespace=dynamic-forever-eu"
  },
  "status": {
    "type": "UP",
    "name": "Activo"
  }
}
```

### Character Profile
```json
{
  "_links": {
    "self": {
      "href": "https://eu.api.blizzard.com/profile/wow/character/el-peregrino?namespace=profile-forever-eu"
    }
  },
  "id": 11909959,
  "name": "El",
  "gender": {
    "type": "MALE",
    "name": "Masculino"
  },
  "faction": {
    "type": "ALLIANCE",
    "name": "Alianza"
  },
  "race": {
    "key": {
      "href": "https://eu.api.blizzard.com/data/wow/playable-race/1?namespace=static-1.60.1_70399-forever-eu"
    },
    "name": "Humano",
    "id": 1
  },
  "character_class": {
    "key": {
      "href": "https://eu.api.blizzard.com/data/wow/playable-class/2?namespace=static-1.60.1_70399-forever-eu"
    },
    "name": "Paladín",
    "id": 2
  },
  "guild": {
    "key": {
      "href": "https://eu.api.blizzard.com/data/wow/guild/c-a-%C3%B1-a-d-a?namespace=profile-forever-eu"
    },
    "name": "C A Ñ A D A",
    "id": 272600,
    "faction": {
      "type": "ALLIANCE",
      "name": "Alianza"
    },
    "slug": "c-a-ñ-a-d-a"
  },
  "level": 21,
  "experience": 18270,
  "achievement_points": 0,
  "achievements": {
    "href": "https://eu.api.blizzard.com/profile/wow/character/el-peregrino/achievements?namespace=profile-forever-eu"
  },
  "titles": {
    "href": "https://eu.api.blizzard.com/profile/wow/character/el-peregrino/titles?namespace=profile-forever-eu"
  },
  "pvp_summary": {
    "href": "https://eu.api.blizzard.com/profile/wow/character/el-peregrino/pvp-summary?namespace=profile-forever-eu"
  },
  "encounters": {
    "href": "https://eu.api.blizzard.com/profile/wow/character/el-peregrino/encounters?namespace=profile-forever-eu"
  },
  "media": {
    "href": "https://eu.api.blizzard.com/profile/wow/character/el-peregrino/character-media?namespace=profile-forever-eu"
  },
  "last_login_timestamp": 1794186281000,
  "average_item_level": 13,
  "equipped_item_level": 13,
  "specializations": {
    "href": "https://eu.api.blizzard.com/profile/wow/character/el-peregrino/specializations?namespace=profile-forever-eu"
  },
  "statistics": {
    "href": "https://eu.api.blizzard.com/profile/wow/character/el-peregrino/statistics?namespace=profile-forever-eu"
  },
  "mythic_keystone_profile": {
    "href": "https://eu.api.blizzard.com/profile/wow/character/el-peregrino/mythic-keystone-profile?namespace=profile-forever-eu"
  },
  "equipment": {
    "href": "https://eu.api.blizzard.com/profile/wow/character/el-peregrino/equipment?namespace=profile-forever-eu"
  },
  "appearance": {
    "href": "https://eu.api.blizzard.com/profile/wow/character/el-peregrino/appearance?namespace=profile-forever-eu"
  },
  "collections": {
    "href": "https://eu.api.blizzard.com/profile/wow/character/el-peregrino/collections?namespace=profile-forever-eu"
  },
  "reputations": {
    "href": "https://eu.api.blizzard.com/profile/wow/character/el-peregrino/reputations?namespace=profile-forever-eu"
  },
  "quests": {
    "href": "https://eu.api.blizzard.com/profile/wow/character/el-peregrino/quests?namespace=profile-forever-eu"
  },
  "achievements_statistics": {
    "href": "https://eu.api.blizzard.com/profile/wow/character/el-peregrino/achievements/statistics?namespace=profile-forever-eu"
  },
  "professions": {
    "href": "https://eu.api.blizzard.com/profile/wow/character/el-peregrino/professions?namespace=profile-forever-eu"
  },
  "is_remix": false,
  "surname": "Peregrino",
  "ruleset": {
    "key": {
      "href": "https://eu.api.blizzard.com/data/wow/ruleset/1?namespace=dynamic-forever-eu"
    },
    "name": "JcJ",
    "id": 1
  },
  "name_search": "El Peregrino"
}
```

### Character Equipment
```json
{
  "_links": {
    "self": {
      "href": "https://eu.api.blizzard.com/profile/wow/character/el-peregrino/equipment?namespace=profile-forever-eu"
    }
  },
  "character": {
    "key": {
      "href": "https://eu.api.blizzard.com/profile/wow/character/el-peregrino?namespace=profile-forever-eu"
    },
    "name": "El",
    "id": 11909959,
    "surname": "Peregrino",
    "slug": "el-peregrino"
  },
  "equipped_items": [
    {
      "item": {
        "key": {
          "href": "https://eu.api.blizzard.com/data/wow/item/4694?namespace=static-1.60.1_70399-forever-eu"
        },
        "id": 4694
      },
      "slot": {
        "type": "SHOULDER",
        "name": "Hombros"
      },
      "quantity": 1,
      "context": 1,
      "quality": {
        "type": "COMMON",
        "name": "Común"
      },
      "name": "Espaldares bruñidos",
      "media": {
        "key": {
          "href": "https://eu.api.blizzard.com/data/wow/media/item/4694?namespace=static-1.60.1_70399-forever-eu"
        },
        "id": 4694
      },
      "item_class": {
        "key": {
          "href": "https://eu.api.blizzard.com/data/wow/item-class/4?namespace=static-1.60.1_70399-forever-eu"
        },
        "name": "Armadura",
        "id": 4
      },
      "item_subclass": {
        "key": {
          "href": "https://eu.api.blizzard.com/data/wow/item-class/4/item-subclass/3?namespace=static-1.60.1_70399-forever-eu"
        },
        "name": "Mallas",
        "id": 3
      },
      "inventory_type": {
        "type": "SHOULDER",
        "name": "Hombro"
      },
      "armor": {
        "value": 124,
        "display": {
          "display_string": "124 armadura",
          "color": {
            "r": 255,
            "g": 255,
            "b": 255,
            "a": 1
          }
        }
      },
      "sell_price": {
        "value": 515,
        "display_strings": {
          "header": "Precio de venta:",
          "gold": "0",
          "silver": "5",
          "copper": "15"
        }
      },
      "requirements": {
        "level": {
          "value": 17,
          "display_string": "Necesitas ser de nivel 17"
        }
      },
      "level": {
        "value": 22,
        "display_string": "Nivel de objeto 22"
      },
      "durability": {
        "value": 28,
        "display_string": "Durabilidad 28 / 50"
      }
    },
    {
      "item": {
        "key": {
          "href": "https://eu.api.blizzard.com/data/wow/item/2575?namespace=static-1.60.1_70399-forever-eu"
        },
        "id": 2575
      },
      "slot": {
        "type": "SHIRT",
        "name": "Camisola"
      },
      "quantity": 1,
      "context": 11,
      "quality": {
        "type": "COMMON",
        "name": "Común"
      },
      "name": "Camisa de lino roja",
      "media": {
        "key": {
          "href": "https://eu.api.blizzard.com/data/wow/media/item/2575?namespace=static-1.60.1_70399-forever-eu"
        },
        "id": 2575
      },
      "item_class": {
        "key": {
          "href": "https://eu.api.blizzard.com/data/wow/item-class/4?namespace=static-1.60.1_70399-forever-eu"
        },
        "name": "Armadura",
        "id": 4
      },
      "item_subclass": {
        "key": {
          "href": "https://eu.api.blizzard.com/data/wow/item-class/4/item-subclass/0?namespace=static-1.60.1_70399-forever-eu"
        },
        "name": "Misceláneo",
        "id": 0
      },
      "inventory_type": {
        "type": "BODY",
        "name": "Camisola"
      },
      "sell_price": {
        "value": 25,
        "display_strings": {
          "header": "Precio de venta:",
          "gold": "0",
          "silver": "0",
          "copper": "25"
        }
      },
      "level": {
        "value": 10,
        "display_string": "Nivel de objeto 10"
      },
      "is_subclass_hidden": true
    },
    {
      "item": {
        "key": {
          "href": "https://eu.api.blizzard.com/data/wow/item/2965?namespace=static-1.60.1_70399-forever-eu"
        },
        "id": 2965
      },
      "enchantments": [
        {
          "display_string": "Encantado: Aguante +2 y armadura +16",
          "source_item": {
            "key": {
              "href": "https://eu.api.blizzard.com/data/wow/item/2313?namespace=static-1.60.1_70399-forever-eu"
            },
            "name": "Refuerzo para armadura medio",
            "id": 2313
          },
          "enchantment_id": 8481,
          "enchantment_slot": {
            "id": 0,
            "type": "PERMANENT"
          }
        }
      ],
      "slot": {
        "type": "CHEST",
        "name": "Pecho"
      },
      "quantity": 1,
      "quality": {
        "type": "UNCOMMON",
        "name": "No común"
      },
      "name": "Túnica de guerrero",
      "media": {
        "key": {
          "href": "https://eu.api.blizzard.com/data/wow/media/item/2965?namespace=static-1.60.1_70399-forever-eu"
        },
        "id": 2965
      },
      "item_class": {
        "key": {
          "href": "https://eu.api.blizzard.com/data/wow/item-class/4?namespace=static-1.60.1_70399-forever-eu"
        },
        "name": "Armadura",
        "id": 4
      },
      "item_subclass": {
        "key": {
          "href": "https://eu.api.blizzard.com/data/wow/item-class/4/item-subclass/3?namespace=static-1.60.1_70399-forever-eu"
        },
        "name": "Mallas",
        "id": 3
      },
      "inventory_type": {
        "type": "CHEST",
        "name": "Pecho"
      },
      "binding": {
        "type": "ON_EQUIP",
        "name": "Se liga al equiparlo"
      },
      "armor": {
        "value": 115,
        "display": {
          "display_string": "115 armadura",
          "color": {
            "r": 255,
            "g": 255,
            "b": 255,
            "a": 1
          }
        }
      },
      "stats": [
        {
          "type": {
            "type": "STRENGTH",
            "name": "fuerza"
          },
          "value": 2,
          "display": {
            "display_string": "+2 fuerza",
            "color": {
              "r": 255,
              "g": 255,
              "b": 255,
              "a": 1
            }
          }
        }
      ],
      "sell_price": {
        "value": 189,
        "display_strings": {
          "header": "Precio de venta:",
          "gold": "0",
          "silver": "1",
          "copper": "89"
        }
      },
      "requirements": {
        "level": {
          "value": 6,
          "display_string": "Necesitas ser de nivel 6"
        }
      },
      "level": {
        "value": 11,
        "display_string": "Nivel de objeto 11"
      },
      "durability": {
        "value": 37,
        "display_string": "Durabilidad 37 / 65"
      }
    },
    {
      "item": {
        "key": {
          "href": "https://eu.api.blizzard.com/data/wow/item/1154?namespace=static-1.60.1_70399-forever-eu"
        },
        "id": 1154
      },
      "slot": {
        "type": "WAIST",
        "name": "Cintura"
      },
      "quantity": 1,
      "context": 11,
      "quality": {
        "type": "COMMON",
        "name": "Común"
      },
      "name": "Cinturón de las Milicias del pueblo",
      "media": {
        "key": {
          "href": "https://eu.api.blizzard.com/data/wow/media/item/1154?namespace=static-1.60.1_70399-forever-eu"
        },
        "id": 1154
      },
      "item_class": {
        "key": {
          "href": "https://eu.api.blizzard.com/data/wow/item-class/4?namespace=static-1.60.1_70399-forever-eu"
        },
        "name": "Armadura",
        "id": 4
      },
      "item_subclass": {
        "key": {
          "href": "https://eu.api.blizzard.com/data/wow/item-class/4/item-subclass/3?namespace=static-1.60.1_70399-forever-eu"
        },
        "name": "Mallas",
        "id": 3
      },
      "inventory_type": {
        "type": "WAIST",
        "name": "Cintura"
      },
      "binding": {
        "type": "ON_ACQUIRE",
        "name": "Se liga al recogerlo"
      },
      "armor": {
        "value": 73,
        "display": {
          "display_string": "73 armadura",
          "color": {
            "r": 255,
            "g": 255,
            "b": 255,
            "a": 1
          }
        }
      },
      "sell_price": {
        "value": 102,
        "display_strings": {
          "header": "Precio de venta:",
          "gold": "0",
          "silver": "1",
          "copper": "2"
        }
      },
      "level": {
        "value": 14,
        "display_string": "Nivel de objeto 14"
      },
      "durability": {
        "value": 11,
        "display_string": "Durabilidad 11 / 20"
      }
    },
    {
      "item": {
        "key": {
          "href": "https://eu.api.blizzard.com/data/wow/item/1943?namespace=static-1.60.1_70399-forever-eu"
        },
        "id": 1943
      },
      "slot": {
        "type": "LEGS",
        "name": "Piernas"
      },
      "quantity": 1,
      "context": 1,
      "quality": {
        "type": "UNCOMMON",
        "name": "No común"
      },
      "name": "Leotardos de malla goblin",
      "media": {
        "key": {
          "href": "https://eu.api.blizzard.com/data/wow/media/item/1943?namespace=static-1.60.1_70399-forever-eu"
        },
        "id": 1943
      },
      "item_class": {
        "key": {
          "href": "https://eu.api.blizzard.com/data/wow/item-class/4?namespace=static-1.60.1_70399-forever-eu"
        },
        "name": "Armadura",
        "id": 4
      },
      "item_subclass": {
        "key": {
          "href": "https://eu.api.blizzard.com/data/wow/item-class/4/item-subclass/3?namespace=static-1.60.1_70399-forever-eu"
        },
        "name": "Mallas",
        "id": 3
      },
      "inventory_type": {
        "type": "LEGS",
        "name": "Piernas"
      },
      "binding": {
        "type": "ON_EQUIP",
        "name": "Se liga al equiparlo"
      },
      "armor": {
        "value": 144,
        "display": {
          "display_string": "144 armadura",
          "color": {
            "r": 255,
            "g": 255,
            "b": 255,
            "a": 1
          }
        }
      },
      "stats": [
        {
          "type": {
            "type": "STRENGTH",
            "name": "fuerza"
          },
          "value": 4,
          "display": {
            "display_string": "+4 fuerza",
            "color": {
              "r": 255,
              "g": 255,
              "b": 255,
              "a": 1
            }
          }
        },
        {
          "type": {
            "type": "STAMINA",
            "name": "aguante"
          },
          "value": 3,
          "display": {
            "display_string": "+3 aguante",
            "color": {
              "r": 255,
              "g": 255,
              "b": 255,
              "a": 1
            }
          }
        }
      ],
      "sell_price": {
        "value": 713,
        "display_strings": {
          "header": "Precio de venta:",
          "gold": "0",
          "silver": "7",
          "copper": "13"
        }
      },
      "requirements": {
        "level": {
          "value": 14,
          "display_string": "Necesitas ser de nivel 14"
        }
      },
      "level": {
        "value": 19,
        "display_string": "Nivel de objeto 19"
      },
      "durability": {
        "value": 32,
        "display_string": "Durabilidad 32 / 60"
      }
    },
    {
      "item": {
        "key": {
          "href": "https://eu.api.blizzard.com/data/wow/item/2910?namespace=static-1.60.1_70399-forever-eu"
        },
        "id": 2910
      },
      "slot": {
        "type": "FEET",
        "name": "Pies"
      },
      "quantity": 1,
      "context": 11,
      "quality": {
        "type": "UNCOMMON",
        "name": "No común"
      },
      "name": "Botas de milicia de oro",
      "media": {
        "key": {
          "href": "https://eu.api.blizzard.com/data/wow/media/item/2910?namespace=static-1.60.1_70399-forever-eu"
        },
        "id": 2910
      },
      "item_class": {
        "key": {
          "href": "https://eu.api.blizzard.com/data/wow/item-class/4?namespace=static-1.60.1_70399-forever-eu"
        },
        "name": "Armadura",
        "id": 4
      },
      "item_subclass": {
        "key": {
          "href": "https://eu.api.blizzard.com/data/wow/item-class/4/item-subclass/3?namespace=static-1.60.1_70399-forever-eu"
        },
        "name": "Mallas",
        "id": 3
      },
      "inventory_type": {
        "type": "FEET",
        "name": "Pies"
      },
      "binding": {
        "type": "ON_ACQUIRE",
        "name": "Se liga al recogerlo"
      },
      "armor": {
        "value": 126,
        "display": {
          "display_string": "126 armadura",
          "color": {
            "r": 255,
            "g": 255,
            "b": 255,
            "a": 1
          }
        }
      },
      "stats": [
        {
          "type": {
            "type": "STRENGTH",
            "name": "fuerza"
          },
          "value": 3,
          "display": {
            "display_string": "+3 fuerza",
            "color": {
              "r": 255,
              "g": 255,
              "b": 255,
              "a": 1
            }
          }
        },
        {
          "type": {
            "type": "STAMINA",
            "name": "aguante"
          },
          "value": 5,
          "display": {
            "display_string": "+5 aguante",
            "color": {
              "r": 255,
              "g": 255,
              "b": 255,
              "a": 1
            }
          }
        }
      ],
      "sell_price": {
        "value": 1257,
        "display_strings": {
          "header": "Precio de venta:",
          "gold": "0",
          "silver": "12",
          "copper": "57"
        }
      },
      "level": {
        "value": 25,
        "display_string": "Nivel de objeto 25"
      },
      "durability": {
        "value": 26,
        "display_string": "Durabilidad 26 / 45"
      }
    },
    {
      "item": {
        "key": {
          "href": "https://eu.api.blizzard.com/data/wow/item/3211?namespace=static-1.60.1_70399-forever-eu"
        },
        "id": 3211
      },
      "slot": {
        "type": "WRIST",
        "name": "Muñeca"
      },
      "quantity": 1,
      "context": 1,
      "quality": {
        "type": "UNCOMMON",
        "name": "No común"
      },
      "name": "Brazales bruñidos",
      "media": {
        "key": {
          "href": "https://eu.api.blizzard.com/data/wow/media/item/3211?namespace=static-1.60.1_70399-forever-eu"
        },
        "id": 3211
      },
      "item_class": {
        "key": {
          "href": "https://eu.api.blizzard.com/data/wow/item-class/4?namespace=static-1.60.1_70399-forever-eu"
        },
        "name": "Armadura",
        "id": 4
      },
      "item_subclass": {
        "key": {
          "href": "https://eu.api.blizzard.com/data/wow/item-class/4/item-subclass/3?namespace=static-1.60.1_70399-forever-eu"
        },
        "name": "Mallas",
        "id": 3
      },
      "inventory_type": {
        "type": "WRIST",
        "name": "Muñeca"
      },
      "binding": {
        "type": "ON_EQUIP",
        "name": "Se liga al equiparlo"
      },
      "armor": {
        "value": 72,
        "display": {
          "display_string": "72 armadura",
          "color": {
            "r": 255,
            "g": 255,
            "b": 255,
            "a": 1
          }
        }
      },
      "stats": [
        {
          "type": {
            "type": "STRENGTH",
            "name": "fuerza"
          },
          "value": 2,
          "display": {
            "display_string": "+2 fuerza",
            "color": {
              "r": 255,
              "g": 255,
              "b": 255,
              "a": 1
            }
          }
        },
        {
          "type": {
            "type": "STAMINA",
            "name": "aguante"
          },
          "value": 2,
          "display": {
            "display_string": "+2 aguante",
            "color": {
              "r": 255,
              "g": 255,
              "b": 255,
              "a": 1
            }
          }
        }
      ],
      "sell_price": {
        "value": 373,
        "display_strings": {
          "header": "Precio de venta:",
          "gold": "0",
          "silver": "3",
          "copper": "73"
        }
      },
      "requirements": {
        "level": {
          "value": 14,
          "display_string": "Necesitas ser de nivel 14"
        }
      },
      "level": {
        "value": 19,
        "display_string": "Nivel de objeto 19"
      },
      "durability": {
        "value": 16,
        "display_string": "Durabilidad 16 / 30"
      }
    },
    {
      "item": {
        "key": {
          "href": "https://eu.api.blizzard.com/data/wow/item/7606?namespace=static-1.60.1_70399-forever-eu"
        },
        "id": 7606
      },
      "slot": {
        "type": "HANDS",
        "name": "Manos"
      },
      "quantity": 1,
      "context": 11,
      "quality": {
        "type": "UNCOMMON",
        "name": "No común"
      },
      "name": "Guanteletes polares",
      "media": {
        "key": {
          "href": "https://eu.api.blizzard.com/data/wow/media/item/7606?namespace=static-1.60.1_70399-forever-eu"
        },
        "id": 7606
      },
      "item_class": {
        "key": {
          "href": "https://eu.api.blizzard.com/data/wow/item-class/4?namespace=static-1.60.1_70399-forever-eu"
        },
        "name": "Armadura",
        "id": 4
      },
      "item_subclass": {
        "key": {
          "href": "https://eu.api.blizzard.com/data/wow/item-class/4/item-subclass/3?namespace=static-1.60.1_70399-forever-eu"
        },
        "name": "Mallas",
        "id": 3
      },
      "inventory_type": {
        "type": "HAND",
        "name": "Manos"
      },
      "binding": {
        "type": "ON_ACQUIRE",
        "name": "Se liga al recogerlo"
      },
      "armor": {
        "value": 109,
        "display": {
          "display_string": "109 armadura",
          "color": {
            "r": 255,
            "g": 255,
            "b": 255,
            "a": 1
          }
        }
      },
      "stats": [
        {
          "type": {
            "type": "STRENGTH",
            "name": "fuerza"
          },
          "value": 4,
          "display": {
            "display_string": "+4 fuerza",
            "color": {
              "r": 255,
              "g": 255,
              "b": 255,
              "a": 1
            }
          }
        },
        {
          "type": {
            "type": "SPIRIT",
            "name": "espíritu"
          },
          "value": 2,
          "is_equip_bonus": true,
          "display": {
            "display_string": "+2 espíritu",
            "color": {
              "r": 0,
              "g": 255,
              "b": 0,
              "a": 1
            }
          }
        }
      ],
      "sell_price": {
        "value": 564,
        "display_strings": {
          "header": "Precio de venta:",
          "gold": "0",
          "silver": "5",
          "copper": "64"
        }
      },
      "level": {
        "value": 22,
        "display_string": "Nivel de objeto 22"
      },
      "durability": {
        "value": 17,
        "display_string": "Durabilidad 17 / 30"
      }
    },
    {
      "item": {
        "key": {
          "href": "https://eu.api.blizzard.com/data/wow/item/1156?namespace=static-1.60.1_70399-forever-eu"
        },
        "id": 1156
      },
      "slot": {
        "type": "FINGER_1",
        "name": "Anillo 1"
      },
      "quantity": 1,
      "context": 1,
      "quality": {
        "type": "RARE",
        "name": "Raro"
      },
      "name": "Anillo con una piedra magnífica",
      "media": {
        "key": {
          "href": "https://eu.api.blizzard.com/data/wow/media/item/1156?namespace=static-1.60.1_70399-forever-eu"
        },
        "id": 1156
      },
      "item_class": {
        "key": {
          "href": "https://eu.api.blizzard.com/data/wow/item-class/4?namespace=static-1.60.1_70399-forever-eu"
        },
        "name": "Armadura",
        "id": 4
      },
      "item_subclass": {
        "key": {
          "href": "https://eu.api.blizzard.com/data/wow/item-class/4/item-subclass/0?namespace=static-1.60.1_70399-forever-eu"
        },
        "name": "Misceláneo",
        "id": 0
      },
      "inventory_type": {
        "type": "FINGER",
        "name": "Dedo"
      },
      "binding": {
        "type": "ON_ACQUIRE",
        "name": "Se liga al recogerlo"
      },
      "unique_equipped": "Único-Equipado",
      "stats": [
        {
          "type": {
            "type": "INTELLECT",
            "name": "intelecto"
          },
          "value": 6,
          "display": {
            "display_string": "+6 intelecto",
            "color": {
              "r": 255,
              "g": 255,
              "b": 255,
              "a": 1
            }
          }
        },
        {
          "type": {
            "type": "AGILITY",
            "name": "agilidad"
          },
          "value": 2,
          "display": {
            "display_string": "+2 agilidad",
            "color": {
              "r": 255,
              "g": 255,
              "b": 255,
              "a": 1
            }
          }
        }
      ],
      "sell_price": {
        "value": 903,
        "display_strings": {
          "header": "Precio de venta:",
          "gold": "0",
          "silver": "9",
          "copper": "3"
        }
      },
      "requirements": {
        "level": {
          "value": 17,
          "display_string": "Necesitas ser de nivel 17"
        }
      },
      "level": {
        "value": 22,
        "display_string": "Nivel de objeto 22"
      },
      "is_subclass_hidden": true
    },
    {
      "item": {
        "key": {
          "href": "https://eu.api.blizzard.com/data/wow/item/284715?namespace=static-1.60.1_70399-forever-eu"
        },
        "id": 284715
      },
      "slot": {
        "type": "FINGER_2",
        "name": "Anillo 2"
      },
      "quantity": 1,
      "context": 1,
      "quality": {
        "type": "RARE",
        "name": "Raro"
      },
      "name": "Sortija de contramaestre",
      "media": {
        "key": {
          "href": "https://eu.api.blizzard.com/data/wow/media/item/284715?namespace=static-1.60.1_70399-forever-eu"
        },
        "id": 284715
      },
      "item_class": {
        "key": {
          "href": "https://eu.api.blizzard.com/data/wow/item-class/4?namespace=static-1.60.1_70399-forever-eu"
        },
        "name": "Armadura",
        "id": 4
      },
      "item_subclass": {
        "key": {
          "href": "https://eu.api.blizzard.com/data/wow/item-class/4/item-subclass/0?namespace=static-1.60.1_70399-forever-eu"
        },
        "name": "Misceláneo",
        "id": 0
      },
      "inventory_type": {
        "type": "FINGER",
        "name": "Dedo"
      },
      "binding": {
        "type": "ON_ACQUIRE",
        "name": "Se liga al recogerlo"
      },
      "unique_equipped": "Único-Equipado",
      "stats": [
        {
          "type": {
            "type": "STRENGTH",
            "name": "fuerza"
          },
          "value": 4,
          "display": {
            "display_string": "+4 fuerza",
            "color": {
              "r": 255,
              "g": 255,
              "b": 255,
              "a": 1
            }
          }
        },
        {
          "type": {
            "type": "STAMINA",
            "name": "aguante"
          },
          "value": 5,
          "display": {
            "display_string": "+5 aguante",
            "color": {
              "r": 255,
              "g": 255,
              "b": 255,
              "a": 1
            }
          }
        }
      ],
      "sell_price": {
        "value": 944,
        "display_strings": {
          "header": "Precio de venta:",
          "gold": "0",
          "silver": "9",
          "copper": "44"
        }
      },
      "requirements": {
        "level": {
          "value": 17,
          "display_string": "Necesitas ser de nivel 17"
        }
      },
      "set": {
        "item_set": {
          "key": {
            "href": "https://eu.api.blizzard.com/data/wow/item-set/2131?namespace=static-1.60.1_70399-forever-eu"
          },
          "name": "Cómplices",
          "id": 2131
        },
        "items": [
          {
            "item": {
              "key": {
                "href": "https://eu.api.blizzard.com/data/wow/item/284715?namespace=static-1.60.1_70399-forever-eu"
              },
              "name": "Sortija de contramaestre",
              "id": 284715
            },
            "is_equipped": true
          },
          {
            "item": {
              "key": {
                "href": "https://eu.api.blizzard.com/data/wow/item/284716?namespace=static-1.60.1_70399-forever-eu"
              },
              "name": "Sortija de la mejor mitad",
              "id": 284716
            }
          }
        ],
        "effects": [
          {
            "display_string": "(2) Bonif.: Probabilidad de que al golpear cuerpo a cuerpo te enfades, lo que aumenta 50 p. la fuerza durante 10 s.",
            "required_count": 2
          },
          {
            "display_string": "(2) Bonif.: +22 p. de fuerza.",
            "required_count": 2
          }
        ],
        "display_string": "Cómplices (1/2)"
      },
      "level": {
        "value": 22,
        "display_string": "Nivel de objeto 22"
      },
      "is_subclass_hidden": true
    },
    {
      "item": {
        "key": {
          "href": "https://eu.api.blizzard.com/data/wow/item/14167?namespace=static-1.60.1_70399-forever-eu"
        },
        "id": 14167
      },
      "slot": {
        "type": "BACK",
        "name": "Espalda"
      },
      "quantity": 1,
      "context": 0,
      "bonus_list": [
        12741
      ],
      "quality": {
        "type": "UNCOMMON",
        "name": "No común"
      },
      "name": "Manteo de bucanero de protección contra el Fuego",
      "media": {
        "key": {
          "href": "https://eu.api.blizzard.com/data/wow/media/item/14167?namespace=static-1.60.1_70399-forever-eu"
        },
        "id": 14167
      },
      "item_class": {
        "key": {
          "href": "https://eu.api.blizzard.com/data/wow/item-class/4?namespace=static-1.60.1_70399-forever-eu"
        },
        "name": "Armadura",
        "id": 4
      },
      "item_subclass": {
        "key": {
          "href": "https://eu.api.blizzard.com/data/wow/item-class/4/item-subclass/1?namespace=static-1.60.1_70399-forever-eu"
        },
        "name": "Tela",
        "id": 1
      },
      "inventory_type": {
        "type": "CLOAK",
        "name": "Espalda"
      },
      "binding": {
        "type": "ON_EQUIP",
        "name": "Se liga al equiparlo"
      },
      "armor": {
        "value": 16,
        "display": {
          "display_string": "16 armadura",
          "color": {
            "r": 255,
            "g": 255,
            "b": 255,
            "a": 1
          }
        }
      },
      "stats": [
        {
          "type": {
            "type": "STAMINA",
            "name": "aguante"
          },
          "value": 2,
          "display": {
            "display_string": "+2 aguante",
            "color": {
              "r": 255,
              "g": 255,
              "b": 255,
              "a": 1
            }
          }
        },
        {
          "type": {
            "type": "FIRE_RESISTANCE",
            "name": "Resistencia a Fuego"
          },
          "value": 2,
          "display": {
            "display_string": "+2 resistencia a Fuego",
            "color": {
              "r": 0,
              "g": 255,
              "b": 0,
              "a": 1
            }
          }
        }
      ],
      "sell_price": {
        "value": 358,
        "display_strings": {
          "header": "Precio de venta:",
          "gold": "0",
          "silver": "3",
          "copper": "58"
        }
      },
      "requirements": {
        "level": {
          "value": 14,
          "display_string": "Necesitas ser de nivel 14"
        }
      },
      "level": {
        "value": 19,
        "display_string": "Nivel de objeto 19"
      },
      "is_subclass_hidden": true
    },
    {
      "item": {
        "key": {
          "href": "https://eu.api.blizzard.com/data/wow/item/5187?namespace=static-1.60.1_70399-forever-eu"
        },
        "id": 5187
      },
      "enchantments": [
        {
          "display_string": "Pesado +2",
          "source_item": {
            "key": {
              "href": "https://eu.api.blizzard.com/data/wow/item/3239?namespace=static-1.60.1_70399-forever-eu"
            },
            "name": "Contrapeso férreo",
            "id": 3239
          },
          "enchantment_id": 19,
          "enchantment_slot": {
            "id": 1,
            "type": "TEMPORARY"
          }
        }
      ],
      "slot": {
        "type": "MAIN_HAND",
        "name": "Mano principal"
      },
      "quantity": 1,
      "context": 1,
      "quality": {
        "type": "RARE",
        "name": "Raro"
      },
      "name": "Martillo de Rhahk'Zor",
      "media": {
        "key": {
          "href": "https://eu.api.blizzard.com/data/wow/media/item/5187?namespace=static-1.60.1_70399-forever-eu"
        },
        "id": 5187
      },
      "item_class": {
        "key": {
          "href": "https://eu.api.blizzard.com/data/wow/item-class/2?namespace=static-1.60.1_70399-forever-eu"
        },
        "name": "Arma",
        "id": 2
      },
      "item_subclass": {
        "key": {
          "href": "https://eu.api.blizzard.com/data/wow/item-class/2/item-subclass/5?namespace=static-1.60.1_70399-forever-eu"
        },
        "name": "Maza",
        "id": 5
      },
      "inventory_type": {
        "type": "TWOHWEAPON",
        "name": "Dos manos"
      },
      "binding": {
        "type": "ON_ACQUIRE",
        "name": "Se liga al recogerlo"
      },
      "weapon": {
        "damage": {
          "min_value": 47,
          "max_value": 71,
          "display_string": "47 - 71 Daño",
          "damage_class": {
            "type": "PHYSICAL",
            "name": "Físico"
          }
        },
        "attack_speed": {
          "value": 3200,
          "display_string": "Velocidad 3,20"
        },
        "dps": {
          "value": 18.4375,
          "display_string": "(18,4 daño por segundo)"
        }
      },
      "stats": [
        {
          "type": {
            "type": "STAMINA",
            "name": "aguante"
          },
          "value": 8,
          "display": {
            "display_string": "+8 aguante",
            "color": {
              "r": 255,
              "g": 255,
              "b": 255,
              "a": 1
            }
          }
        },
        {
          "type": {
            "type": "SPELL_POWER",
            "name": "poder con hechizos"
          },
          "value": 8,
          "is_equip_bonus": true,
          "display": {
            "display_string": "+8 poder con hechizos",
            "color": {
              "r": 0,
              "g": 255,
              "b": 0,
              "a": 1
            }
          }
        }
      ],
      "sell_price": {
        "value": 2454,
        "display_strings": {
          "header": "Precio de venta:",
          "gold": "0",
          "silver": "24",
          "copper": "54"
        }
      },
      "requirements": {
        "level": {
          "value": 16,
          "display_string": "Necesitas ser de nivel 16"
        }
      },
      "level": {
        "value": 21,
        "display_string": "Nivel de objeto 21"
      },
      "durability": {
        "value": 43,
        "display_string": "Durabilidad 43 / 75"
      }
    }
  ],
  "equipped_item_sets": [
    {
      "item_set": {
        "key": {
          "href": "https://eu.api.blizzard.com/data/wow/item-set/2131?namespace=static-1.60.1_70399-forever-eu"
        },
        "name": "Cómplices",
        "id": 2131
      },
      "items": [
        {
          "item": {
            "key": {
              "href": "https://eu.api.blizzard.com/data/wow/item/284715?namespace=static-1.60.1_70399-forever-eu"
            },
            "name": "Sortija de contramaestre",
            "id": 284715
          },
          "is_equipped": true
        },
        {
          "item": {
            "key": {
              "href": "https://eu.api.blizzard.com/data/wow/item/284716?namespace=static-1.60.1_70399-forever-eu"
            },
            "name": "Sortija de la mejor mitad",
            "id": 284716
          }
        }
      ],
      "effects": [
        {
          "display_string": "(2) Bonif.: Probabilidad de que al golpear cuerpo a cuerpo te enfades, lo que aumenta 50 p. la fuerza durante 10 s.",
          "required_count": 2
        },
        {
          "display_string": "(2) Bonif.: +22 p. de fuerza.",
          "required_count": 2
        }
      ],
      "display_string": "Cómplices (1/2)"
    }
  ]
}
```

### Character Statistics
```json
{
  "_links": {
    "self": {
      "href": "https://eu.api.blizzard.com/profile/wow/character/el-peregrino/statistics?namespace=profile-forever-eu"
    }
  },
  "health": 716,
  "power": 785,
  "power_type": {
    "key": {
      "href": "https://eu.api.blizzard.com/data/wow/power-type/0?namespace=static-1.60.1_70399-forever-eu"
    },
    "name": "Maná",
    "id": 0
  },
  "speed": {
    "rating_bonus": 0,
    "value": 0,
    "rating_normalized": 0
  },
  "strength": {
    "base": 43,
    "effective": 68
  },
  "agility": {
    "base": 32,
    "effective": 34
  },
  "intellect": {
    "base": 33,
    "effective": 42
  },
  "stamina": {
    "base": 42,
    "effective": 69
  },
  "melee_crit": {
    "rating_bonus": 0,
    "value": 5.7195997,
    "rating_normalized": 0
  },
  "melee_haste": {
    "rating_bonus": 0,
    "value": 0,
    "rating_normalized": 0
  },
  "mastery": {
    "rating_bonus": 0,
    "value": 0,
    "rating_normalized": 0
  },
  "bonus_armor": 16,
  "lifesteal": {
    "rating_bonus": 0,
    "value": 0,
    "rating_normalized": 0
  },
  "versatility": 0,
  "versatility_damage_done_bonus": 0,
  "versatility_healing_done_bonus": 0,
  "versatility_damage_taken_bonus": 0,
  "avoidance": {
    "rating_bonus": 0,
    "value": 0,
    "rating_normalized": 0
  },
  "attack_power": 179,
  "main_hand_damage_min": 89.91429,
  "main_hand_damage_max": 113.91429,
  "main_hand_speed": 3.2,
  "main_hand_dps": 31.848215,
  "off_hand_damage_min": 13.285715,
  "off_hand_damage_max": 13.285715,
  "off_hand_speed": 2,
  "off_hand_dps": 6.6428576,
  "spell_power": 8,
  "spell_penetration": 0,
  "spell_crit": {
    "rating_bonus": 0,
    "value": 6.2009997,
    "rating_normalized": 0
  },
  "mana_regen": 50,
  "mana_regen_combat": 0,
  "armor": {
    "base": 16,
    "effective": 863
  },
  "dodge": {
    "rating_bonus": 0,
    "value": 4.5995994,
    "rating_normalized": 0
  },
  "parry": {
    "rating_bonus": 0,
    "value": 4.84,
    "rating_normalized": 0
  },
  "block": {
    "rating_bonus": 0,
    "value": 4.84,
    "rating_normalized": 0
  },
  "ranged_crit": {
    "rating_bonus": 0,
    "value": 3.3996,
    "rating_normalized": 0
  },
  "ranged_haste": {
    "rating_bonus": 0,
    "value": 0,
    "rating_normalized": 0
  },
  "spell_haste": {
    "rating_bonus": 0,
    "value": 0,
    "rating_normalized": 0
  },
  "character": {
    "key": {
      "href": "https://eu.api.blizzard.com/profile/wow/character/el-peregrino?namespace=profile-forever-eu"
    },
    "name": "El",
    "id": 11909959,
    "surname": "Peregrino",
    "slug": "el-peregrino"
  },
  "spirit": {
    "base": 35,
    "effective": 40
  },
  "defense": {
    "base": 101,
    "effective": 101
  },
  "fire_resistance": {
    "base": 2,
    "effective": 2
  },
  "shadow_resistance": {
    "base": 0,
    "effective": 0
  },
  "nature_resistance": {
    "base": 0,
    "effective": 0
  },
  "arcane_resistance": {
    "base": 0,
    "effective": 0
  },
  "frost_resistance": {
    "base": 0,
    "effective": 0
  },
  "movement_speed": 100,
  "ranged_attack_power": 0,
  "ranged_damage_min": 1,
  "ranged_damage_max": 1,
  "expertise": 0,
  "off_hand_expertise": 0,
  "armor_penetration": 0,
  "spell_healing": 8,
  "melee_hit": {
    "rating_bonus": 0,
    "value": 0,
    "rating_normalized": 0
  },
  "off_hand_hit": {
    "rating_bonus": 0,
    "value": 0,
    "rating_normalized": 0
  },
  "ranged_hit": {
    "rating_bonus": 0,
    "value": 0,
    "rating_normalized": 0
  },
  "spell_hit": {
    "rating_bonus": 0,
    "value": 0,
    "rating_normalized": 0
  }
}
```

### Character Specializations/Traits
```json
{
  "_links": {
    "self": {
      "href": "https://eu.api.blizzard.com/profile/wow/character/el-peregrino/specializations?namespace=profile-forever-eu"
    }
  },
  "character": {
    "key": {
      "href": "https://eu.api.blizzard.com/profile/wow/character/el-peregrino?namespace=profile-forever-eu"
    },
    "name": "El",
    "id": 11909959,
    "surname": "Peregrino",
    "slug": "el-peregrino"
  },
  "specialization_groups": [
    {
      "is_active": true,
      "specializations": [
        {
          "specialization": {
            "key": {
              "href": "https://eu.api.blizzard.com/data/wow/playable-specialization/594?namespace=static-1.60.1_70399-forever-eu"
            },
            "name": "Sagrado",
            "id": 594
          },
          "talents": [
            {
              "talent": {
                "name": "Fuerza divina",
                "id": 145961
              },
              "spell_tooltip": {
                "spell": {
                  "name": "Fuerza divina",
                  "id": 20262
                },
                "description": "Aumenta tu fuerza en un 10%.",
                "cast_time": "Pasivo"
              },
              "talent_rank": 5
            },
            {
              "talent": {
                "name": "Sellos mejorados",
                "id": 134829
              },
              "spell_tooltip": {
                "spell": {
                  "name": "Sellos mejorados",
                  "id": 20224
                },
                "description": "Aumenta un 6% el daño que infligen todos tus sellos y sentencias.",
                "cast_time": "Pasivo"
              },
              "talent_rank": 2
            }
          ],
          "specialization_name": "Sagrado",
          "spent_points": 7
        },
        {
          "specialization": {
            "key": {
              "href": "https://eu.api.blizzard.com/data/wow/playable-specialization/267?namespace=static-1.60.1_70399-forever-eu"
            },
            "name": "Protección",
            "id": 267
          },
          "talents": [
            {
              "talent": {
                "name": "Intelecto divino",
                "id": 134827
              },
              "spell_tooltip": {
                "spell": {
                  "name": "Intelecto divino",
                  "id": 20257
                },
                "description": "Aumenta tu intelecto total en un 10%.",
                "cast_time": "Pasivo"
              },
              "talent_rank": 5
            }
          ],
          "specialization_name": "Protección",
          "spent_points": 5
        }
      ]
    }
  ]
}
```

### Character Media
```json
{
  "_links": {
    "self": {
      "href": "https://eu.api.blizzard.com/profile/wow/character/el-peregrino/character-media?namespace=profile-forever-eu"
    }
  },
  "character": {
    "key": {
      "href": "https://eu.api.blizzard.com/profile/wow/character/el-peregrino?namespace=profile-forever-eu"
    },
    "name": "El",
    "id": 11909959,
    "surname": "Peregrino",
    "slug": "el-peregrino"
  },
  "assets": [
    {
      "key": "main-raw",
      "value": "https://render.worldofwarcraft.com/forever-eu/character/71/11909959-main-raw.png"
    },
    {
      "key": "main-sd-raw",
      "value": "https://render.worldofwarcraft.com/forever-eu/character/71/11909959-main-sd-raw.png"
    },
    {
      "key": "avatar",
      "value": "https://render.worldofwarcraft.com/forever-eu/character/71/11909959-avatar.jpg"
    },
    {
      "key": "avatar-sd",
      "value": "https://render.worldofwarcraft.com/forever-eu/character/71/11909959-avatar-sd.jpg"
    }
  ]
}
```

### Guild Roster
```json
{
  "_links": {
    "self": {
      "href": "https://eu.api.blizzard.com/data/wow/guild/forever/roster?namespace=profile-forever-eu"
    }
  },
  "guild": {
    "key": {
      "href": "https://eu.api.blizzard.com/data/wow/guild/forever?namespace=profile-forever-eu"
    },
    "name": "Forever",
    "id": 94195,
    "faction": {
      "type": "HORDE",
      "name": "Horda"
    },
    "slug": "forever"
  },
  "members": [
    {
      "character": {
        "key": {
          "href": "https://eu.api.blizzard.com/profile/wow/character/mr-rob%C3%A1g?namespace=profile-forever-eu"
        },
        "name": "Mr",
        "id": 535382,
        "level": 36,
        "playable_class": {
          "key": {
            "href": "https://eu.api.blizzard.com/data/wow/playable-class/11?namespace=static-1.60.1_70399-forever-eu"
          },
          "id": 11
        },
        "playable_race": {
          "key": {
            "href": "https://eu.api.blizzard.com/data/wow/playable-race/96?namespace=static-1.60.1_70399-forever-eu"
          },
          "id": 96
        },
        "faction": {
          "type": "HORDE"
        },
        "surname": "Robág",
        "slug": "mr-robág"
      },
      "rank": 4
    },
    {
      "character": {
        "key": {
          "href": "https://eu.api.blizzard.com/profile/wow/character/brown-clown?namespace=profile-forever-eu"
        },
        "name": "Brown",
        "id": 536793,
        "level": 25,
        "playable_class": {
          "key": {
            "href": "https://eu.api.blizzard.com/data/wow/playable-class/1?namespace=static-1.60.1_70399-forever-eu"
          },
          "id": 1
        },
        "playable_race": {
          "key": {
            "href": "https://eu.api.blizzard.com/data/wow/playable-race/2?namespace=static-1.60.1_70399-forever-eu"
          },
          "id": 2
        },
        "faction": {
          "type": "HORDE"
        },
        "surname": "Clown",
        "slug": "brown-clown"
      },
      "rank": 4
    },
    {
      "character": {
        "key": {
          "href": "https://eu.api.blizzard.com/profile/wow/character/luri-storm?namespace=profile-forever-eu"
        },
        "name": "Luri",
        "id": 1698328,
        "level": 43,
        "playable_class": {
          "key": {
            "href": "https://eu.api.blizzard.com/data/wow/playable-class/7?namespace=static-1.60.1_70399-forever-eu"
          },
          "id": 7
        },
        "playable_race": {
          "key": {
            "href": "https://eu.api.blizzard.com/data/wow/playable-race/96?namespace=static-1.60.1_70399-forever-eu"
          },
          "id": 96
        },
        "faction": {
          "type": "HORDE"
        },
        "surname": "Storm",
        "slug": "luri-storm"
      },
      "rank": 1
    },
    {
      "character": {
        "key": {
          "href": "https://eu.api.blizzard.com/profile/wow/character/martl-charge?namespace=profile-forever-eu"
        },
        "name": "Martl",
        "id": 1870631,
        "level": 27,
        "playable_class": {
          "key": {
            "href": "https://eu.api.blizzard.com/data/wow/playable-class/1?namespace=static-1.60.1_70399-forever-eu"
          },
          "id": 1
        },
        "playable_race": {
          "key": {
            "href": "https://eu.api.blizzard.com/data/wow/playable-race/2?namespace=static-1.60.1_70399-forever-eu"
          },
          "id": 2
        },
        "faction": {
          "type": "HORDE"
        },
        "surname": "Charge",
        "slug": "martl-charge"
      },
      "rank": 1
    },
    {
      "character": {
        "key": {
          "href": "https://eu.api.blizzard.com/profile/wow/character/grimnog-nightblood?namespace=profile-forever-eu"
        },
        "name": "Grimnog",
        "id": 2009738,
        "level": 12,
        "playable_class": {
          "key": {
            "href": "https://eu.api.blizzard.com/data/wow/playable-class/4?namespace=static-1.60.1_70399-forever-eu"
          },
          "id": 4
        },
        "playable_race": {
          "key": {
            "href": "https://eu.api.blizzard.com/data/wow/playable-race/5?namespace=static-1.60.1_70399-forever-eu"
          },
          "id": 5
        },
        "faction": {
          "type": "HORDE"
        },
        "surname": "Nightblood",
        "slug": "grimnog-nightblood"
      },
      "rank": 4
    },
    {
      "character": {
        "key": {
          "href": "https://eu.api.blizzard.com/profile/wow/character/useless-dave?namespace=profile-forever-eu"
        },
        "name": "Useless",
        "id": 2661536,
        "level": 36,
        "playable_class": {
          "key": {
            "href": "https://eu.api.blizzard.com/data/wow/playable-class/2?namespace=static-1.60.1_70399-forever-eu"
          },
          "id": 2
        },
        "playable_race": {
          "key": {
            "href": "https://eu.api.blizzard.com/data/wow/playable-race/5?namespace=static-1.60.1_70399-forever-eu"
          },
          "id": 5
        },
        "faction": {
          "type": "HORDE"
        },
        "surname": "Dave",
        "slug": "useless-dave"
      },
      "rank": 4
    },
    {
      "character": {
        "key": {
          "href": "https://eu.api.blizzard.com/profile/wow/character/lexa-bloodrend?namespace=profile-forever-eu"
        },
        "name": "Lexa",
        "id": 3566484,
        "level": 22,
        "playable_class": {
          "key": {
            "href": "https://eu.api.blizzard.com/data/wow/playable-class/1?namespace=static-1.60.1_70399-forever-eu"
          },
          "id": 1
        },
        "playable_race": {
          "key": {
            "href": "https://eu.api.blizzard.com/data/wow/playable-race/5?namespace=static-1.60.1_70399-forever-eu"
          },
          "id": 5
        },
        "faction": {
          "type": "HORDE"
        },
        "surname": "Bloodrend",
        "slug": "lexa-bloodrend"
      },
      "rank": 4
    },
    {
      "character": {
        "key": {
          "href": "https://eu.api.blizzard.com/profile/wow/character/arise-niysa?namespace=profile-forever-eu"
        },
        "name": "Arise",
        "id": 3714723,
        "level": 43,
        "playable_class": {
          "key": {
            "href": "https://eu.api.blizzard.com/data/wow/playable-class/8?namespace=static-1.60.1_70399-forever-eu"
          },
          "id": 8
        },
        "playable_race": {
          "key": {
            "href": "https://eu.api.blizzard.com/data/wow/playable-race/5?namespace=static-1.60.1_70399-forever-eu"
          },
          "id": 5
        },
        "faction": {
          "type": "HORDE"
        },
        "surname": "Niysa",
        "slug": "arise-niysa"
      },
      "rank": 3
    },
    {
      "character": {
        "key": {
          "href": "https://eu.api.blizzard.com/profile/wow/character/messana-tarasind?namespace=profile-forever-eu"
        },
        "name": "Messana",
        "id": 4911849,
        "level": 30,
        "playable_class": {
          "key": {
            "href": "https://eu.api.blizzard.com/data/wow/playable-class/8?namespace=static-1.60.1_70399-forever-eu"
          },
          "id": 8
        },
        "playable_race": {
          "key": {
            "href": "https://eu.api.blizzard.com/data/wow/playable-race/5?namespace=static-1.60.1_70399-forever-eu"
          },
          "id": 5
        },
        "faction": {
          "type": "HORDE"
        },
        "surname": "Tarasind",
        "slug": "messana-tarasind"
      },
      "rank": 4
    },
    {
      "character": {
        "key": {
          "href": "https://eu.api.blizzard.com/profile/wow/character/drudiz-ermondius?namespace=profile-forever-eu"
        },
        "name": "Drudiz",
        "id": 5768465,
        "level": 30,
        "playable_class": {
          "key": {
            "href": "https://eu.api.blizzard.com/data/wow/playable-class/11?namespace=static-1.60.1_70399-forever-eu"
          },
          "id": 11
        },
        "playable_race": {
          "key": {
            "href": "https://eu.api.blizzard.com/data/wow/playable-race/96?namespace=static-1.60.1_70399-forever-eu"
          },
          "id": 96
        },
        "faction": {
          "type": "HORDE"
        },
        "surname": "Ermondius",
        "slug": "drudiz-ermondius"
      },
      "rank": 4
    },
    {
      "character": {
        "key": {
          "href": "https://eu.api.blizzard.com/profile/wow/character/pala-cus?namespace=profile-forever-eu"
        },
        "name": "Pala",
        "id": 5929111,
        "level": 23,
        "playable_class": {
          "key": {
            "href": "https://eu.api.blizzard.com/data/wow/playable-class/2?namespace=static-1.60.1_70399-forever-eu"
          },
          "id": 2
        },
        "playable_race": {
          "key": {
            "href": "https://eu.api.blizzard.com/data/wow/playable-race/5?namespace=static-1.60.1_70399-forever-eu"
          },
          "id": 5
        },
        "faction": {
          "type": "HORDE"
        },
        "surname": "Cus",
        "slug": "pala-cus"
      },
      "rank": 4
    },
    {
      "character": {
        "key": {
          "href": "https://eu.api.blizzard.com/profile/wow/character/elder-hollow?namespace=profile-forever-eu"
        },
        "name": "Elder",
        "id": 6325135,
        "level": 25,
        "playable_class": {
          "key": {
            "href": "https://eu.api.blizzard.com/data/wow/playable-class/2?namespace=static-1.60.1_70399-forever-eu"
          },
          "id": 2
        },
        "playable_race": {
          "key": {
            "href": "https://eu.api.blizzard.com/data/wow/playable-race/5?namespace=static-1.60.1_70399-forever-eu"
          },
          "id": 5
        },
        "faction": {
          "type": "HORDE"
        },
        "surname": "Hollow",
        "slug": "elder-hollow"
      },
      "rank": 4
    },
    {
      "character": {
        "key": {
          "href": "https://eu.api.blizzard.com/profile/wow/character/donnie-doomfinger?namespace=profile-forever-eu"
        },
        "name": "Donnie",
        "id": 6619172,
        "level": 33,
        "playable_class": {
          "key": {
            "href": "https://eu.api.blizzard.com/data/wow/playable-class/9?namespace=static-1.60.1_70399-forever-eu"
          },
          "id": 9
        },
        "playable_race": {
          "key": {
            "href": "https://eu.api.blizzard.com/data/wow/playable-race/5?namespace=static-1.60.1_70399-forever-eu"
          },
          "id": 5
        },
        "faction": {
          "type": "HORDE"
        },
        "surname": "Doomfinger",
        "slug": "donnie-doomfinger"
      },
      "rank": 4
    },
    {
      "character": {
        "key": {
          "href": "https://eu.api.blizzard.com/profile/wow/character/tokken-bw?namespace=profile-forever-eu"
        },
        "name": "Tokken",
        "id": 6665832,
        "level": 24,
        "playable_class": {
          "key": {
            "href": "https://eu.api.blizzard.com/data/wow/playable-class/9?namespace=static-1.60.1_70399-forever-eu"
          },
          "id": 9
        },
        "playable_race": {
          "key": {
            "href": "https://eu.api.blizzard.com/data/wow/playable-race/2?namespace=static-1.60.1_70399-forever-eu"
          },
          "id": 2
        },
        "faction": {
          "type": "HORDE"
        },
        "surname": "Bw",
        "slug": "tokken-bw"
      },
      "rank": 4
    },
    {
      "character": {
        "key": {
          "href": "https://eu.api.blizzard.com/profile/wow/character/power-maxxing?namespace=profile-forever-eu"
        },
        "name": "Power",
        "id": 6762114,
        "level": 34,
        "playable_class": {
          "key": {
            "href": "https://eu.api.blizzard.com/data/wow/playable-class/2?namespace=static-1.60.1_70399-forever-eu"
          },
          "id": 2
        },
        "playable_race": {
          "key": {
            "href": "https://eu.api.blizzard.com/data/wow/playable-race/5?namespace=static-1.60.1_70399-forever-eu"
          },
          "id": 5
        },
        "faction": {
          "type": "HORDE"
        },
        "surname": "Maxxing",
        "slug": "power-maxxing"
      },
      "rank": 2
    },
    {
      "character": {
        "key": {
          "href": "https://eu.api.blizzard.com/profile/wow/character/beev-bringer?namespace=profile-forever-eu"
        },
        "name": "Beev",
        "id": 6765290,
        "level": 29,
        "playable_class": {
          "key": {
            "href": "https://eu.api.blizzard.com/data/wow/playable-class/2?namespace=static-1.60.1_70399-forever-eu"
          },
          "id": 2
        },
        "playable_race": {
          "key": {
            "href": "https://eu.api.blizzard.com/data/wow/playable-race/5?namespace=static-1.60.1_70399-forever-eu"
          },
          "id": 5
        },
        "faction": {
          "type": "HORDE"
        },
        "surname": "Bringer",
        "slug": "beev-bringer"
      },
      "rank": 4
    },
    {
      "character": {
        "key": {
          "href": "https://eu.api.blizzard.com/profile/wow/character/schrempopo-longtongue?namespace=profile-forever-eu"
        },
        "name": "Schrempopo",
        "id": 6859568,
        "level": 36,
        "playable_class": {
          "key": {
            "href": "https://eu.api.blizzard.com/data/wow/playable-class/5?namespace=static-1.60.1_70399-forever-eu"
          },
          "id": 5
        },
        "playable_race": {
          "key": {
            "href": "https://eu.api.blizzard.com/data/wow/playable-race/5?namespace=static-1.60.1_70399-forever-eu"
          },
          "id": 5
        },
        "faction": {
          "type": "HORDE"
        },
        "surname": "Longtongue",
        "slug": "schrempopo-longtongue"
      },
      "rank": 4
    },
    {
      "character": {
        "key": {
          "href": "https://eu.api.blizzard.com/profile/wow/character/shinigami-bones?namespace=profile-forever-eu"
        },
        "name": "Shinigami",
        "id": 6884399,
        "level": 33,
        "playable_class": {
          "key": {
            "href": "https://eu.api.blizzard.com/data/wow/playable-class/4?namespace=static-1.60.1_70399-forever-eu"
          },
          "id": 4
        },
        "playable_race": {
          "key": {
            "href": "https://eu.api.blizzard.com/data/wow/playable-race/5?namespace=static-1.60.1_70399-forever-eu"
          },
          "id": 5
        },
        "faction": {
          "type": "HORDE"
        },
        "surname": "Bones",
        "slug": "shinigami-bones"
      },
      "rank": 1
    },
    {
      "character": {
        "key": {
          "href": "https://eu.api.blizzard.com/profile/wow/character/chabby-holyhammer?namespace=profile-forever-eu"
        },
        "name": "Chabby",
        "id": 6884920,
        "level": 37,
        "playable_class": {
          "key": {
            "href": "https://eu.api.blizzard.com/data/wow/playable-class/2?namespace=static-1.60.1_70399-forever-eu"
          },
          "id": 2
        },
        "playable_race": {
          "key": {
            "href": "https://eu.api.blizzard.com/data/wow/playable-race/5?namespace=static-1.60.1_70399-forever-eu"
          },
          "id": 5
        },
        "faction": {
          "type": "HORDE"
        },
        "surname": "Holyhammer",
        "slug": "chabby-holyhammer"
      },
      "rank": 2
    },
    {
      "character": {
        "key": {
          "href": "https://eu.api.blizzard.com/profile/wow/character/breyka-bigbow?namespace=profile-forever-eu"
        },
        "name": "Breyka",
        "id": 6925672,
        "level": 32,
        "playable_class": {
          "key": {
            "href": "https://eu.api.blizzard.com/data/wow/playable-class/3?namespace=static-1.60.1_70399-forever-eu"
          },
          "id": 3
        },
        "playable_race": {
          "key": {
            "href": "https://eu.api.blizzard.com/data/wow/playable-race/2?namespace=static-1.60.1_70399-forever-eu"
          },
          "id": 2
        },
        "faction": {
          "type": "HORDE"
        },
        "surname": "Bigbow",
        "slug": "breyka-bigbow"
      },
      "rank": 4
    },
    {
      "character": {
        "key": {
          "href": "https://eu.api.blizzard.com/profile/wow/character/moo-backa?namespace=profile-forever-eu"
        },
        "name": "Moo",
        "id": 7212417,
        "level": 20,
        "playable_class": {
          "key": {
            "href": "https://eu.api.blizzard.com/data/wow/playable-class/11?namespace=static-1.60.1_70399-forever-eu"
          },
          "id": 11
        },
        "playable_race": {
          "key": {
            "href": "https://eu.api.blizzard.com/data/wow/playable-race/6?namespace=static-1.60.1_70399-forever-eu"
          },
          "id": 6
        },
        "faction": {
          "type": "HORDE"
        },
        "surname": "Backa",
        "slug": "moo-backa"
      },
      "rank": 4
    },
    {
      "character": {
        "key": {
          "href": "https://eu.api.blizzard.com/profile/wow/character/bobbert-mcbobbins?namespace=profile-forever-eu"
        },
        "name": "Bobbert",
        "id": 7213152,
        "level": 27,
        "playable_class": {
          "key": {
            "href": "https://eu.api.blizzard.com/data/wow/playable-class/2?namespace=static-1.60.1_70399-forever-eu"
          },
          "id": 2
        },
        "playable_race": {
          "key": {
            "href": "https://eu.api.blizzard.com/data/wow/playable-race/5?namespace=static-1.60.1_70399-forever-eu"
          },
          "id": 5
        },
        "faction": {
          "type": "HORDE"
        },
        "surname": "Mcbobbins",
        "slug": "bobbert-mcbobbins"
      },
      "rank": 4
    },
    {
      "character": {
        "key": {
          "href": "https://eu.api.blizzard.com/profile/wow/character/goa-smashie?namespace=profile-forever-eu"
        },
        "name": "Goa",
        "id": 7332211,
        "level": 44,
        "playable_class": {
          "key": {
            "href": "https://eu.api.blizzard.com/data/wow/playable-class/1?namespace=static-1.60.1_70399-forever-eu"
          },
          "id": 1
        },
        "playable_race": {
          "key": {
            "href": "https://eu.api.blizzard.com/data/wow/playable-race/8?namespace=static-1.60.1_70399-forever-eu"
          },
          "id": 8
        },
        "faction": {
          "type": "HORDE"
        },
        "surname": "Smashie",
        "slug": "goa-smashie"
      },
      "rank": 0
    },
    {
      "character": {
        "key": {
          "href": "https://eu.api.blizzard.com/profile/wow/character/lunacy-ofbeatzy?namespace=profile-forever-eu"
        },
        "name": "Lunacy",
        "id": 7392710,
        "level": 21,
        "playable_class": {
          "key": {
            "href": "https://eu.api.blizzard.com/data/wow/playable-class/9?namespace=static-1.60.1_70399-forever-eu"
          },
          "id": 9
        },
        "playable_race": {
          "key": {
            "href": "https://eu.api.blizzard.com/data/wow/playable-race/5?namespace=static-1.60.1_70399-forever-eu"
          },
          "id": 5
        },
        "faction": {
          "type": "HORDE"
        },
        "surname": "Ofbeatzy",
        "slug": "lunacy-ofbeatzy"
      },
      "rank": 4
    },
    {
      "character": {
        "key": {
          "href": "https://eu.api.blizzard.com/profile/wow/character/vaquerillo-maru?namespace=profile-forever-eu"
        },
        "name": "Vaquerillo",
        "id": 7397635,
        "level": 15,
        "playable_class": {
          "key": {
            "href": "https://eu.api.blizzard.com/data/wow/playable-class/11?namespace=static-1.60.1_70399-forever-eu"
          },
          "id": 11
        },
        "playable_race": {
          "key": {
            "href": "https://eu.api.blizzard.com/data/wow/playable-race/6?namespace=static-1.60.1_70399-forever-eu"
          },
          "id": 6
        },
        "faction": {
          "type": "HORDE"
        },
        "surname": "Maru",
        "slug": "vaquerillo-maru"
      },
      "rank": 4
    },
    {
      "character": {
        "key": {
          "href": "https://eu.api.blizzard.com/profile/wow/character/nipeno-skyweaver?namespace=profile-forever-eu"
        },
        "name": "Nipeno",
        "id": 7406937,
        "level": 36,
        "playable_class": {
          "key": {
            "href": "https://eu.api.blizzard.com/data/wow/playable-class/11?namespace=static-1.60.1_70399-forever-eu"
          },
          "id": 11
        },
        "playable_race": {
          "key": {
            "href": "https://eu.api.blizzard.com/data/wow/playable-race/96?namespace=static-1.60.1_70399-forever-eu"
          },
          "id": 96
        },
        "faction": {
          "type": "HORDE"
        },
        "surname": "Skyweaver",
        "slug": "nipeno-skyweaver"
      },
      "rank": 4
    },
    {
      "character": {
        "key": {
          "href": "https://eu.api.blizzard.com/profile/wow/character/snow-born?namespace=profile-forever-eu"
        },
        "name": "Snow",
        "id": 7704257,
        "level": 16,
        "playable_class": {
          "key": {
            "href": "https://eu.api.blizzard.com/data/wow/playable-class/1?namespace=static-1.60.1_70399-forever-eu"
          },
          "id": 1
        },
        "playable_race": {
          "key": {
            "href": "https://eu.api.blizzard.com/data/wow/playable-race/2?namespace=static-1.60.1_70399-forever-eu"
          },
          "id": 2
        },
        "faction": {
          "type": "HORDE"
        },
        "surname": "Born",
        "slug": "snow-born"
      },
      "rank": 4
    },
    {
      "character": {
        "key": {
          "href": "https://eu.api.blizzard.com/profile/wow/character/hotzenplotz-seinvater?namespace=profile-forever-eu"
        },
        "name": "Hotzenplotz",
        "id": 7707955,
        "level": 21,
        "playable_class": {
          "key": {
            "href": "https://eu.api.blizzard.com/data/wow/playable-class/3?namespace=static-1.60.1_70399-forever-eu"
          },
          "id": 3
        },
        "playable_race": {
          "key": {
            "href": "https://eu.api.blizzard.com/data/wow/playable-race/2?namespace=static-1.60.1_70399-forever-eu"
          },
          "id": 2
        },
        "faction": {
          "type": "HORDE"
        },
        "surname": "Seinvater",
        "slug": "hotzenplotz-seinvater"
      },
      "rank": 4
    },
    {
      "character": {
        "key": {
          "href": "https://eu.api.blizzard.com/profile/wow/character/junijunior-afk?namespace=profile-forever-eu"
        },
        "name": "Junijunior",
        "id": 7957133,
        "level": 28,
        "playable_class": {
          "key": {
            "href": "https://eu.api.blizzard.com/data/wow/playable-class/4?namespace=static-1.60.1_70399-forever-eu"
          },
          "id": 4
        },
        "playable_race": {
          "key": {
            "href": "https://eu.api.blizzard.com/data/wow/playable-race/5?namespace=static-1.60.1_70399-forever-eu"
          },
          "id": 5
        },
        "faction": {
          "type": "HORDE"
        },
        "surname": "Afk",
        "slug": "junijunior-afk"
      },
      "rank": 4
    },
    {
      "character": {
        "key": {
          "href": "https://eu.api.blizzard.com/profile/wow/character/steak-eater?namespace=profile-forever-eu"
        },
        "name": "Steak",
        "id": 10444487,
        "level": 29,
        "playable_class": {
          "key": {
            "href": "https://eu.api.blizzard.com/data/wow/playable-class/11?namespace=static-1.60.1_70399-forever-eu"
          },
          "id": 11
        },
        "playable_race": {
          "key": {
            "href": "https://eu.api.blizzard.com/data/wow/playable-race/6?namespace=static-1.60.1_70399-forever-eu"
          },
          "id": 6
        },
        "faction": {
          "type": "HORDE"
        },
        "surname": "Eater",
        "slug": "steak-eater"
      },
      "rank": 2
    },
    {
      "character": {
        "key": {
          "href": "https://eu.api.blizzard.com/profile/wow/character/withe-choclate?namespace=profile-forever-eu"
        },
        "name": "Withe",
        "id": 10516412,
        "level": 14,
        "playable_class": {
          "key": {
            "href": "https://eu.api.blizzard.com/data/wow/playable-class/4?namespace=static-1.60.1_70399-forever-eu"
          },
          "id": 4
        },
        "playable_race": {
          "key": {
            "href": "https://eu.api.blizzard.com/data/wow/playable-race/96?namespace=static-1.60.1_70399-forever-eu"
          },
          "id": 96
        },
        "faction": {
          "type": "HORDE"
        },
        "surname": "Choclate",
        "slug": "withe-choclate"
      },
      "rank": 4
    },
    {
      "character": {
        "key": {
          "href": "https://eu.api.blizzard.com/profile/wow/character/blavie-blavz?namespace=profile-forever-eu"
        },
        "name": "Blavie",
        "id": 10580617,
        "level": 18,
        "playable_class": {
          "key": {
            "href": "https://eu.api.blizzard.com/data/wow/playable-class/11?namespace=static-1.60.1_70399-forever-eu"
          },
          "id": 11
        },
        "playable_race": {
          "key": {
            "href": "https://eu.api.blizzard.com/data/wow/playable-race/6?namespace=static-1.60.1_70399-forever-eu"
          },
          "id": 6
        },
        "faction": {
          "type": "HORDE"
        },
        "surname": "Blavz",
        "slug": "blavie-blavz"
      },
      "rank": 4
    },
    {
      "character": {
        "key": {
          "href": "https://eu.api.blizzard.com/profile/wow/character/scarlett-warhandsson?namespace=profile-forever-eu"
        },
        "name": "Scarlett",
        "id": 11536405,
        "level": 12,
        "playable_class": {
          "key": {
            "href": "https://eu.api.blizzard.com/data/wow/playable-class/1?namespace=static-1.60.1_70399-forever-eu"
          },
          "id": 1
        },
        "playable_race": {
          "key": {
            "href": "https://eu.api.blizzard.com/data/wow/playable-race/5?namespace=static-1.60.1_70399-forever-eu"
          },
          "id": 5
        },
        "faction": {
          "type": "HORDE"
        },
        "surname": "Warhandsson",
        "slug": "scarlett-warhandsson"
      },
      "rank": 4
    },
    {
      "character": {
        "key": {
          "href": "https://eu.api.blizzard.com/profile/wow/character/kuh-schnitzel?namespace=profile-forever-eu"
        },
        "name": "Kuh",
        "id": 11846905,
        "level": 3,
        "playable_class": {
          "key": {
            "href": "https://eu.api.blizzard.com/data/wow/playable-class/3?namespace=static-1.60.1_70399-forever-eu"
          },
          "id": 3
        },
        "playable_race": {
          "key": {
            "href": "https://eu.api.blizzard.com/data/wow/playable-race/6?namespace=static-1.60.1_70399-forever-eu"
          },
          "id": 6
        },
        "faction": {
          "type": "HORDE"
        },
        "surname": "Schnitzel",
        "slug": "kuh-schnitzel"
      },
      "rank": 4
    },
    {
      "character": {
        "key": {
          "href": "https://eu.api.blizzard.com/profile/wow/character/spirit-stuhl?namespace=profile-forever-eu"
        },
        "name": "Spirit",
        "id": 11946738,
        "level": 24,
        "playable_class": {
          "key": {
            "href": "https://eu.api.blizzard.com/data/wow/playable-class/7?namespace=static-1.60.1_70399-forever-eu"
          },
          "id": 7
        },
        "playable_race": {
          "key": {
            "href": "https://eu.api.blizzard.com/data/wow/playable-race/8?namespace=static-1.60.1_70399-forever-eu"
          },
          "id": 8
        },
        "faction": {
          "type": "HORDE"
        },
        "surname": "Stuhl",
        "slug": "spirit-stuhl"
      },
      "rank": 4
    },
    {
      "character": {
        "key": {
          "href": "https://eu.api.blizzard.com/profile/wow/character/gadwick-wizened?namespace=profile-forever-eu"
        },
        "name": "Gadwick",
        "id": 12141676,
        "level": 18,
        "playable_class": {
          "key": {
            "href": "https://eu.api.blizzard.com/data/wow/playable-class/7?namespace=static-1.60.1_70399-forever-eu"
          },
          "id": 7
        },
        "playable_race": {
          "key": {
            "href": "https://eu.api.blizzard.com/data/wow/playable-race/8?namespace=static-1.60.1_70399-forever-eu"
          },
          "id": 8
        },
        "faction": {
          "type": "HORDE"
        },
        "surname": "Wizened",
        "slug": "gadwick-wizened"
      },
      "rank": 4
    },
    {
      "character": {
        "key": {
          "href": "https://eu.api.blizzard.com/profile/wow/character/gandalf-thegirth?namespace=profile-forever-eu"
        },
        "name": "Gandalf",
        "id": 12435406,
        "level": 18,
        "playable_class": {
          "key": {
            "href": "https://eu.api.blizzard.com/data/wow/playable-class/9?namespace=static-1.60.1_70399-forever-eu"
          },
          "id": 9
        },
        "playable_race": {
          "key": {
            "href": "https://eu.api.blizzard.com/data/wow/playable-race/5?namespace=static-1.60.1_70399-forever-eu"
          },
          "id": 5
        },
        "faction": {
          "type": "HORDE"
        },
        "surname": "Thegirth",
        "slug": "gandalf-thegirth"
      },
      "rank": 4
    },
    {
      "character": {
        "key": {
          "href": "https://eu.api.blizzard.com/profile/wow/character/dry-hoibe?namespace=profile-forever-eu"
        },
        "name": "Dry",
        "id": 12676644,
        "level": 22,
        "playable_class": {
          "key": {
            "href": "https://eu.api.blizzard.com/data/wow/playable-class/4?namespace=static-1.60.1_70399-forever-eu"
          },
          "id": 4
        },
        "playable_race": {
          "key": {
            "href": "https://eu.api.blizzard.com/data/wow/playable-race/5?namespace=static-1.60.1_70399-forever-eu"
          },
          "id": 5
        },
        "faction": {
          "type": "HORDE"
        },
        "surname": "Hoibe",
        "slug": "dry-hoibe"
      },
      "rank": 4
    },
    {
      "character": {
        "key": {
          "href": "https://eu.api.blizzard.com/profile/wow/character/the-interlan?namespace=profile-forever-eu"
        },
        "name": "The",
        "id": 12750980,
        "level": 27,
        "playable_class": {
          "key": {
            "href": "https://eu.api.blizzard.com/data/wow/playable-class/2?namespace=static-1.60.1_70399-forever-eu"
          },
          "id": 2
        },
        "playable_race": {
          "key": {
            "href": "https://eu.api.blizzard.com/data/wow/playable-race/5?namespace=static-1.60.1_70399-forever-eu"
          },
          "id": 5
        },
        "faction": {
          "type": "HORDE"
        },
        "surname": "Interlan",
        "slug": "the-interlan"
      },
      "rank": 4
    },
    {
      "character": {
        "key": {
          "href": "https://eu.api.blizzard.com/profile/wow/character/grow-guru?namespace=profile-forever-eu"
        },
        "name": "Grow",
        "id": 12949640,
        "level": 12,
        "playable_class": {
          "key": {
            "href": "https://eu.api.blizzard.com/data/wow/playable-class/11?namespace=static-1.60.1_70399-forever-eu"
          },
          "id": 11
        },
        "playable_race": {
          "key": {
            "href": "https://eu.api.blizzard.com/data/wow/playable-race/6?namespace=static-1.60.1_70399-forever-eu"
          },
          "id": 6
        },
        "faction": {
          "type": "HORDE"
        },
        "surname": "Guru",
        "slug": "grow-guru"
      },
      "rank": 4
    },
    {
      "character": {
        "key": {
          "href": "https://eu.api.blizzard.com/profile/wow/character/taz-grizzl?namespace=profile-forever-eu"
        },
        "name": "Taz",
        "id": 13389200,
        "level": 10,
        "playable_class": {
          "key": {
            "href": "https://eu.api.blizzard.com/data/wow/playable-class/7?namespace=static-1.60.1_70399-forever-eu"
          },
          "id": 7
        },
        "playable_race": {
          "key": {
            "href": "https://eu.api.blizzard.com/data/wow/playable-race/8?namespace=static-1.60.1_70399-forever-eu"
          },
          "id": 8
        },
        "faction": {
          "type": "HORDE"
        },
        "surname": "Grizzl",
        "slug": "taz-grizzl"
      },
      "rank": 4
    },
    {
      "character": {
        "key": {
          "href": "https://eu.api.blizzard.com/profile/wow/character/robuzi-silverhand?namespace=profile-forever-eu"
        },
        "name": "Robuzi",
        "id": 13398804,
        "level": 28,
        "playable_class": {
          "key": {
            "href": "https://eu.api.blizzard.com/data/wow/playable-class/2?namespace=static-1.60.1_70399-forever-eu"
          },
          "id": 2
        },
        "playable_race": {
          "key": {
            "href": "https://eu.api.blizzard.com/data/wow/playable-race/5?namespace=static-1.60.1_70399-forever-eu"
          },
          "id": 5
        },
        "faction": {
          "type": "HORDE"
        },
        "surname": "Silverhand",
        "slug": "robuzi-silverhand"
      },
      "rank": 4
    },
    {
      "character": {
        "key": {
          "href": "https://eu.api.blizzard.com/profile/wow/character/demeter-flora?namespace=profile-forever-eu"
        },
        "name": "Demeter",
        "id": 13740325,
        "level": 20,
        "playable_class": {
          "key": {
            "href": "https://eu.api.blizzard.com/data/wow/playable-class/5?namespace=static-1.60.1_70399-forever-eu"
          },
          "id": 5
        },
        "playable_race": {
          "key": {
            "href": "https://eu.api.blizzard.com/data/wow/playable-race/8?namespace=static-1.60.1_70399-forever-eu"
          },
          "id": 8
        },
        "faction": {
          "type": "HORDE"
        },
        "surname": "Flora",
        "slug": "demeter-flora"
      },
      "rank": 4
    },
    {
      "character": {
        "key": {
          "href": "https://eu.api.blizzard.com/profile/wow/character/warlett-johansson?namespace=profile-forever-eu"
        },
        "name": "Warlett",
        "id": 14649599,
        "level": 24,
        "playable_class": {
          "key": {
            "href": "https://eu.api.blizzard.com/data/wow/playable-class/1?namespace=static-1.60.1_70399-forever-eu"
          },
          "id": 1
        },
        "playable_race": {
          "key": {
            "href": "https://eu.api.blizzard.com/data/wow/playable-race/96?namespace=static-1.60.1_70399-forever-eu"
          },
          "id": 96
        },
        "faction": {
          "type": "HORDE"
        },
        "surname": "Johansson",
        "slug": "warlett-johansson"
      },
      "rank": 4
    },
    {
      "character": {
        "key": {
          "href": "https://eu.api.blizzard.com/profile/wow/character/nyx-hallowsbane?namespace=profile-forever-eu"
        },
        "name": "Nyx",
        "id": 18099476,
        "level": 19,
        "playable_class": {
          "key": {
            "href": "https://eu.api.blizzard.com/data/wow/playable-class/4?namespace=static-1.60.1_70399-forever-eu"
          },
          "id": 4
        },
        "playable_race": {
          "key": {
            "href": "https://eu.api.blizzard.com/data/wow/playable-race/5?namespace=static-1.60.1_70399-forever-eu"
          },
          "id": 5
        },
        "faction": {
          "type": "HORDE"
        },
        "surname": "Hallowsbane",
        "slug": "nyx-hallowsbane"
      },
      "rank": 4
    },
    {
      "character": {
        "key": {
          "href": "https://eu.api.blizzard.com/profile/wow/character/ibarox-bloedhond?namespace=profile-forever-eu"
        },
        "name": "Ibarox",
        "id": 19209301,
        "level": 12,
        "playable_class": {
          "key": {
            "href": "https://eu.api.blizzard.com/data/wow/playable-class/3?namespace=static-1.60.1_70399-forever-eu"
          },
          "id": 3
        },
        "playable_race": {
          "key": {
            "href": "https://eu.api.blizzard.com/data/wow/playable-race/2?namespace=static-1.60.1_70399-forever-eu"
          },
          "id": 2
        },
        "faction": {
          "type": "HORDE"
        },
        "surname": "Bloedhond",
        "slug": "ibarox-bloedhond"
      },
      "rank": 4
    },
    {
      "character": {
        "key": {
          "href": "https://eu.api.blizzard.com/profile/wow/character/sir-biggy?namespace=profile-forever-eu"
        },
        "name": "Sir",
        "id": 13581811,
        "level": 20,
        "playable_class": {
          "key": {
            "href": "https://eu.api.blizzard.com/data/wow/playable-class/8?namespace=static-1.60.1_70399-forever-eu"
          },
          "id": 8
        },
        "playable_race": {
          "key": {
            "href": "https://eu.api.blizzard.com/data/wow/playable-race/5?namespace=static-1.60.1_70399-forever-eu"
          },
          "id": 5
        },
        "faction": {
          "type": "HORDE"
        },
        "surname": "Biggy",
        "slug": "sir-biggy"
      },
      "rank": 4
    }
  ]
}
```

### Guild Activity
```json
{
  "_links": {
    "self": {
      "href": "https://eu.api.blizzard.com/data/wow/guild/forever/activity?namespace=profile-forever-eu"
    }
  },
  "guild": {
    "key": {
      "href": "https://eu.api.blizzard.com/data/wow/guild/forever?namespace=profile-forever-eu"
    },
    "name": "Forever",
    "id": 94195,
    "faction": {
      "type": "HORDE",
      "name": "Horda"
    },
    "slug": "forever"
  }
}
```

