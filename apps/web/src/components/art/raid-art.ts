/**
 * Official instance artwork served by the Battle.net Game Data API
 * (`/data/wow/media/journal-instance/{id}` → render.worldofwarcraft.com/eu/zones/{key}-small.jpg, 600×300).
 * Verified 2026-11-12. See ASSET_INVENTORY.md.
 */
export const ZONE_ART: Record<string, string> = {
  MC: 'molten-core',
  ONY: 'onyxias-lair',
  BWL: 'blackwing-lair',
  ZG: 'zulgurub',
  AQ20: 'ruins-of-ahnqiraj',
  AQ40: 'temple-of-ahnqiraj',
  NAXX: 'naxxramas',
  UBRS: 'upper-blackrock-spire',
  LBRS: 'lower-blackrock-spire',
  BRD: 'blackrock-depths',
  DM: 'deadmines',
  STRAT: 'stratholme',
  SCHOLO: 'scholomance',
  DIREMAUL: 'dire-maul',
  RFC: 'ragefire-chasm',
  WC: 'wailing-caverns',
  SFK: 'shadowfang-keep',
  SM: 'scarlet-monastery',
  ULDA: 'uldaman',
  ZF: 'zulfarrak',
  MARA: 'maraudon',
  ST: 'sunken-temple',
  BFD: 'blackfathom-deeps',
  GNOMER: 'gnomeregan',
  RFK: 'razorfen-kraul',
  RFD: 'razorfen-downs',
  STOCKS: 'the-stockade',
};

export const zoneArt = (key: string | null | undefined) => `https://render.worldofwarcraft.com/eu/zones/${ZONE_ART[key ?? ''] ?? 'molten-core'}-small.jpg`;

/** Atmosphere per faction: Horde burns (Molten Core, embers), Alliance glows (Naxxramas, arcane motes). */
export function factionAtmosphere(faction: 'ALLIANCE' | 'HORDE' | null | undefined) {
  return faction === 'ALLIANCE'
    ? { art: zoneArt('NAXX'), hue: 195, glow: 'rgba(120, 190, 255, .28)' }
    : { art: zoneArt('MC'), hue: 28, glow: 'rgba(255, 150, 60, .30)' };
}
