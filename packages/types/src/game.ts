/**
 * World of Warcraft: Forever — static game domain.
 *
 * Every id below was verified against the live Battle.net API on 2026-11-12
 * (namespace `static-1.60.1_70399-forever-eu`). Localised names come from the
 * API at runtime; the Spanish/English names here are fallbacks only.
 */

export const REGIONS = ['eu', 'us', 'kr', 'tw'] as const;
export type Region = (typeof REGIONS)[number];

export function isRegion(value: string): value is Region {
  return (REGIONS as readonly string[]).includes(value);
}

export type Faction = 'ALLIANCE' | 'HORDE';
export type CombatRole = 'TANK' | 'HEALER' | 'DPS';

export type ClassKey =
  | 'WARRIOR'
  | 'PALADIN'
  | 'HUNTER'
  | 'ROGUE'
  | 'PRIEST'
  | 'SHAMAN'
  | 'MAGE'
  | 'WARLOCK'
  | 'DRUID';

export interface SpecMeta {
  id: number;
  /** Talent tree id that hosts this spec (all three trees of a class share it). */
  treeId: number;
  nameEs: string;
  nameEn: string;
  /** Typical raid role of a character that invests mostly in this tree. A hint, never a fact. */
  roleHint: CombatRole;
}

export interface ClassMeta {
  id: number;
  key: ClassKey;
  nameEs: string;
  nameEn: string;
  /** Canonical in-game class colour. */
  color: string;
  /** Darker variant with ≥4.5:1 contrast on light surfaces. */
  colorOnLight: string;
  iconFileId: number;
  powerType: 'MANA' | 'RAGE' | 'ENERGY';
  roles: CombatRole[];
  specs: SpecMeta[];
}

export const CLASSES: readonly ClassMeta[] = [
  {
    id: 1, key: 'WARRIOR', nameEs: 'Guerrero', nameEn: 'Warrior', color: '#C69B6D', colorOnLight: '#7A5533',
    iconFileId: 626008, powerType: 'RAGE', roles: ['TANK', 'DPS'],
    specs: [
      { id: 26, treeId: 1117, nameEs: 'Armas', nameEn: 'Arms', roleHint: 'DPS' },
      { id: 256, treeId: 1117, nameEs: 'Furia', nameEn: 'Fury', roleHint: 'DPS' },
      { id: 257, treeId: 1117, nameEs: 'Protección', nameEn: 'Protection', roleHint: 'TANK' },
    ],
  },
  {
    id: 2, key: 'PALADIN', nameEs: 'Paladín', nameEn: 'Paladin', color: '#F48CBA', colorOnLight: '#A3326A',
    iconFileId: 626003, powerType: 'MANA', roles: ['TANK', 'HEALER', 'DPS'],
    specs: [
      { id: 594, treeId: 1100, nameEs: 'Sagrado', nameEn: 'Holy', roleHint: 'HEALER' },
      { id: 267, treeId: 1100, nameEs: 'Protección', nameEn: 'Protection', roleHint: 'TANK' },
      { id: 184, treeId: 1100, nameEs: 'Reprensión', nameEn: 'Retribution', roleHint: 'DPS' },
    ],
  },
  {
    id: 3, key: 'HUNTER', nameEs: 'Cazador', nameEn: 'Hunter', color: '#AAD372', colorOnLight: '#4C6E1F',
    iconFileId: 626000, powerType: 'MANA', roles: ['DPS'],
    specs: [
      { id: 50, treeId: 1091, nameEs: 'Dominio de bestias', nameEn: 'Beast Mastery', roleHint: 'DPS' },
      { id: 163, treeId: 1091, nameEs: 'Puntería', nameEn: 'Marksmanship', roleHint: 'DPS' },
      { id: 51, treeId: 1091, nameEs: 'Supervivencia', nameEn: 'Survival', roleHint: 'DPS' },
    ],
  },
  {
    id: 4, key: 'ROGUE', nameEs: 'Pícaro', nameEn: 'Rogue', color: '#FFF468', colorOnLight: '#7A6F00',
    iconFileId: 626005, powerType: 'ENERGY', roles: ['DPS'],
    specs: [
      { id: 253, treeId: 1111, nameEs: 'Asesinato', nameEn: 'Assassination', roleHint: 'DPS' },
      { id: 38, treeId: 1111, nameEs: 'Combate', nameEn: 'Combat', roleHint: 'DPS' },
      { id: 39, treeId: 1111, nameEs: 'Sutileza', nameEn: 'Subtlety', roleHint: 'DPS' },
    ],
  },
  {
    id: 5, key: 'PRIEST', nameEs: 'Sacerdote', nameEn: 'Priest', color: '#FFFFFF', colorOnLight: '#5B6470',
    iconFileId: 626004, powerType: 'MANA', roles: ['HEALER', 'DPS'],
    specs: [
      { id: 613, treeId: 1114, nameEs: 'Disciplina', nameEn: 'Discipline', roleHint: 'HEALER' },
      { id: 56, treeId: 1114, nameEs: 'Sagrado', nameEn: 'Holy', roleHint: 'HEALER' },
      { id: 78, treeId: 1114, nameEs: 'Magia sombría', nameEn: 'Shadow', roleHint: 'DPS' },
    ],
  },
  {
    id: 7, key: 'SHAMAN', nameEs: 'Chamán', nameEn: 'Shaman', color: '#0070DD', colorOnLight: '#0058AD',
    iconFileId: 626006, powerType: 'MANA', roles: ['HEALER', 'DPS'],
    specs: [
      { id: 375, treeId: 1082, nameEs: 'Combate elemental', nameEn: 'Elemental', roleHint: 'DPS' },
      { id: 373, treeId: 1082, nameEs: 'Mejora', nameEn: 'Enhancement', roleHint: 'DPS' },
      { id: 374, treeId: 1082, nameEs: 'Recuperación', nameEn: 'Restoration', roleHint: 'HEALER' },
    ],
  },
  {
    id: 8, key: 'MAGE', nameEs: 'Mago', nameEn: 'Mage', color: '#3FC7EB', colorOnLight: '#0E6E87',
    iconFileId: 626001, powerType: 'MANA', roles: ['DPS'],
    specs: [
      { id: 237, treeId: 1112, nameEs: 'Arcano', nameEn: 'Arcane', roleHint: 'DPS' },
      { id: 8, treeId: 1112, nameEs: 'Fuego', nameEn: 'Fire', roleHint: 'DPS' },
      { id: 6, treeId: 1112, nameEs: 'Escarcha', nameEn: 'Frost', roleHint: 'DPS' },
    ],
  },
  {
    id: 9, key: 'WARLOCK', nameEs: 'Brujo', nameEn: 'Warlock', color: '#8788EE', colorOnLight: '#4B4CB8',
    iconFileId: 626007, powerType: 'MANA', roles: ['DPS'],
    specs: [
      { id: 355, treeId: 1116, nameEs: 'Aflicción', nameEn: 'Affliction', roleHint: 'DPS' },
      { id: 354, treeId: 1116, nameEs: 'Demonología', nameEn: 'Demonology', roleHint: 'DPS' },
      { id: 593, treeId: 1116, nameEs: 'Destrucción', nameEn: 'Destruction', roleHint: 'DPS' },
    ],
  },
  {
    id: 11, key: 'DRUID', nameEs: 'Druida', nameEn: 'Druid', color: '#FF7C0A', colorOnLight: '#A34A00',
    iconFileId: 625999, powerType: 'MANA', roles: ['TANK', 'HEALER', 'DPS'],
    specs: [
      { id: 574, treeId: 1089, nameEs: 'Equilibrio', nameEn: 'Balance', roleHint: 'DPS' },
      { id: 134, treeId: 1089, nameEs: 'Combate feral', nameEn: 'Feral Combat', roleHint: 'TANK' },
      { id: 573, treeId: 1089, nameEs: 'Recuperación', nameEn: 'Restoration', roleHint: 'HEALER' },
    ],
  },
] as const;

const CLASS_BY_ID = new Map(CLASSES.map((c) => [c.id, c]));
const CLASS_BY_KEY = new Map(CLASSES.map((c) => [c.key, c]));

export function classById(id: number | null | undefined): ClassMeta | undefined {
  return id == null ? undefined : CLASS_BY_ID.get(id);
}

export function classByKey(key: string | null | undefined): ClassMeta | undefined {
  return key ? CLASS_BY_KEY.get(key as ClassKey) : undefined;
}

export function specById(id: number | null | undefined): (SpecMeta & { classId: number }) | undefined {
  if (id == null) return undefined;
  for (const c of CLASSES) {
    const s = c.specs.find((x) => x.id === id);
    if (s) return { ...s, classId: c.id };
  }
  return undefined;
}

export interface RaceMeta {
  id: number;
  nameEs: string;
  nameEn: string;
  faction: Faction;
}

/** Includes the two WoW: Forever–exclusive Skyborn races (95/96). */
export const RACES: readonly RaceMeta[] = [
  { id: 1, nameEs: 'Humano', nameEn: 'Human', faction: 'ALLIANCE' },
  { id: 3, nameEs: 'Enano', nameEn: 'Dwarf', faction: 'ALLIANCE' },
  { id: 4, nameEs: 'Elfo de la noche', nameEn: 'Night Elf', faction: 'ALLIANCE' },
  { id: 7, nameEs: 'Gnomo', nameEn: 'Gnome', faction: 'ALLIANCE' },
  { id: 95, nameEs: 'Cielonato de la Orden Eminente', nameEn: 'Skyborn (Eminent Order)', faction: 'ALLIANCE' },
  { id: 2, nameEs: 'Orco', nameEn: 'Orc', faction: 'HORDE' },
  { id: 5, nameEs: 'No-muerto', nameEn: 'Undead', faction: 'HORDE' },
  { id: 6, nameEs: 'Tauren', nameEn: 'Tauren', faction: 'HORDE' },
  { id: 8, nameEs: 'Trol', nameEn: 'Troll', faction: 'HORDE' },
  { id: 96, nameEs: 'Cielonato Formavientos', nameEn: 'Skyborn (Windshaper)', faction: 'HORDE' },
] as const;

const RACE_BY_ID = new Map(RACES.map((r) => [r.id, r]));
export function raceById(id: number | null | undefined): RaceMeta | undefined {
  return id == null ? undefined : RACE_BY_ID.get(id);
}

/** Level cap observed in item requirements (required_level 60) — reviewed 2026-11-12. */
export const LEVEL_CAP = 60;

// ---------------------------------------------------------------------------
// Equipment
// ---------------------------------------------------------------------------

export type SlotType =
  | 'HEAD' | 'NECK' | 'SHOULDER' | 'BACK' | 'CHEST' | 'SHIRT' | 'TABARD' | 'WRIST'
  | 'HANDS' | 'WAIST' | 'LEGS' | 'FEET' | 'FINGER_1' | 'FINGER_2' | 'TRINKET_1' | 'TRINKET_2'
  | 'MAIN_HAND' | 'OFF_HAND' | 'RANGED';

export interface SlotMeta {
  type: SlotType;
  nameEs: string;
  column: 'left' | 'right' | 'bottom';
}

/** In-game paper-doll order: 8 left, 8 right, 3 weapons at the bottom. */
export const EQUIPMENT_SLOTS: readonly SlotMeta[] = [
  { type: 'HEAD', nameEs: 'Cabeza', column: 'left' },
  { type: 'NECK', nameEs: 'Cuello', column: 'left' },
  { type: 'SHOULDER', nameEs: 'Hombros', column: 'left' },
  { type: 'BACK', nameEs: 'Espalda', column: 'left' },
  { type: 'CHEST', nameEs: 'Pecho', column: 'left' },
  { type: 'SHIRT', nameEs: 'Camisa', column: 'left' },
  { type: 'TABARD', nameEs: 'Tabardo', column: 'left' },
  { type: 'WRIST', nameEs: 'Muñecas', column: 'left' },
  { type: 'HANDS', nameEs: 'Manos', column: 'right' },
  { type: 'WAIST', nameEs: 'Cintura', column: 'right' },
  { type: 'LEGS', nameEs: 'Piernas', column: 'right' },
  { type: 'FEET', nameEs: 'Pies', column: 'right' },
  { type: 'FINGER_1', nameEs: 'Dedo', column: 'right' },
  { type: 'FINGER_2', nameEs: 'Dedo', column: 'right' },
  { type: 'TRINKET_1', nameEs: 'Abalorio', column: 'right' },
  { type: 'TRINKET_2', nameEs: 'Abalorio', column: 'right' },
  { type: 'MAIN_HAND', nameEs: 'Mano principal', column: 'bottom' },
  { type: 'OFF_HAND', nameEs: 'Mano secundaria', column: 'bottom' },
  { type: 'RANGED', nameEs: 'A distancia', column: 'bottom' },
] as const;

export type ItemQuality = 'POOR' | 'COMMON' | 'UNCOMMON' | 'RARE' | 'EPIC' | 'LEGENDARY' | 'ARTIFACT' | 'HEIRLOOM';

export const ITEM_QUALITY: Record<ItemQuality, { nameEs: string; color: string; colorOnLight: string; rank: number }> = {
  POOR: { nameEs: 'Pobre', color: '#9D9D9D', colorOnLight: '#5F5F5F', rank: 0 },
  COMMON: { nameEs: 'Común', color: '#FFFFFF', colorOnLight: '#3D4450', rank: 1 },
  UNCOMMON: { nameEs: 'Poco común', color: '#1EFF00', colorOnLight: '#167A08', rank: 2 },
  RARE: { nameEs: 'Raro', color: '#0070DD', colorOnLight: '#0058AD', rank: 3 },
  EPIC: { nameEs: 'Épico', color: '#A335EE', colorOnLight: '#7A1FBF', rank: 4 },
  LEGENDARY: { nameEs: 'Legendario', color: '#FF8000', colorOnLight: '#A35200', rank: 5 },
  ARTIFACT: { nameEs: 'Artefacto', color: '#E6CC80', colorOnLight: '#7A6420', rank: 6 },
  HEIRLOOM: { nameEs: 'Reliquia', color: '#00CCFF', colorOnLight: '#00708C', rank: 6 },
};

export function qualityOf(value: string | null | undefined) {
  return ITEM_QUALITY[(value ?? 'COMMON') as ItemQuality] ?? ITEM_QUALITY.COMMON;
}

/** Raid instances of the classic era, used as a selectable catalogue in the Raid Center. */
export const RAID_INSTANCES = [
  { key: 'MC', nameEs: 'Núcleo de Magma', size: 40 },
  { key: 'ONY', nameEs: 'Guarida de Onyxia', size: 40 },
  { key: 'BWL', nameEs: 'Guarida de Alanegra', size: 40 },
  { key: 'ZG', nameEs: "Zul'Gurub", size: 20 },
  { key: 'AQ20', nameEs: "Ruinas de Ahn'Qiraj", size: 20 },
  { key: 'AQ40', nameEs: "Templo de Ahn'Qiraj", size: 40 },
  { key: 'NAXX', nameEs: 'Naxxramas', size: 40 },
  { key: 'DUNGEON', nameEs: 'Mazmorra (5 jugadores)', size: 5 },
  { key: 'UBRS', nameEs: 'Cumbre de Roca Negra', size: 10 },
  { key: 'OTHER', nameEs: 'Otra actividad', size: 40 },
] as const;
export type RaidInstanceKey = (typeof RAID_INSTANCES)[number]['key'];

/** Icon URL on Blizzard's render CDN. The `/eu/` path serves every icon; `/forever-eu/` misses some (403). */
export function iconUrl(fileDataId: number | string, size: 18 | 36 | 56 = 56) {
  return `https://render.worldofwarcraft.com/eu/icons/${size}/${fileDataId}.jpg`;
}

/**
 * Classic-era dungeon catalogue (reference data: level ranges and zones as in the original
 * game; WoW: Forever may tune them). Keys match the official artwork map in the web app.
 */
export const DUNGEONS = [
  { key: 'RFC', nameEs: 'Sima Ígnea', zoneEs: 'Orgrimmar', min: 13, max: 18, size: 5, faction: 'HORDE' },
  { key: 'WC', nameEs: 'Cuevas de los Lamentos', zoneEs: 'Los Baldíos', min: 17, max: 24, size: 5, faction: null },
  { key: 'DM', nameEs: 'Las Minas de la Muerte', zoneEs: 'Páramos de Poniente', min: 17, max: 26, size: 5, faction: 'ALLIANCE' },
  { key: 'SFK', nameEs: 'Castillo de Colmillo Oscuro', zoneEs: 'Bosque de Argénteos', min: 22, max: 30, size: 5, faction: 'HORDE' },
  { key: 'BFD', nameEs: 'Cavernas de Brazanegra', zoneEs: 'Vallefresno', min: 24, max: 32, size: 5, faction: null },
  { key: 'STOCKS', nameEs: 'Las Mazmorras', zoneEs: 'Ventormenta', min: 24, max: 32, size: 5, faction: 'ALLIANCE' },
  { key: 'GNOMER', nameEs: 'Gnomeregan', zoneEs: 'Dun Morogh', min: 29, max: 38, size: 5, faction: null },
  { key: 'RFK', nameEs: 'Horado Rajacieno', zoneEs: 'Los Baldíos', min: 29, max: 38, size: 5, faction: null },
  { key: 'SM', nameEs: 'Monasterio Escarlata', zoneEs: 'Claros de Tirisfal', min: 34, max: 45, size: 5, faction: null },
  { key: 'RFD', nameEs: 'Zahúrda Rajacieno', zoneEs: 'Los Baldíos', min: 37, max: 46, size: 5, faction: null },
  { key: 'ULDA', nameEs: 'Uldaman', zoneEs: 'Tierras Inhóspitas', min: 41, max: 51, size: 5, faction: null },
  { key: 'ZF', nameEs: "Zul'Farrak", zoneEs: 'Tanaris', min: 44, max: 54, size: 5, faction: null },
  { key: 'MARA', nameEs: 'Maraudon', zoneEs: 'Desolace', min: 46, max: 55, size: 5, faction: null },
  { key: 'ST', nameEs: "El Templo de Atal'Hakkar", zoneEs: 'Pantano de las Penas', min: 50, max: 56, size: 5, faction: null },
  { key: 'BRD', nameEs: 'Profundidades de Roca Negra', zoneEs: 'Montaña Roca Negra', min: 52, max: 60, size: 5, faction: null },
  { key: 'LBRS', nameEs: 'Cumbre de Roca Negra inferior', zoneEs: 'Montaña Roca Negra', min: 55, max: 60, size: 5, faction: null },
  { key: 'DIREMAUL', nameEs: 'La Masacre', zoneEs: 'Feralas', min: 56, max: 60, size: 5, faction: null },
  { key: 'STRAT', nameEs: 'Stratholme', zoneEs: 'Tierras de la Peste del Este', min: 58, max: 60, size: 5, faction: null },
  { key: 'SCHOLO', nameEs: 'Scholomance', zoneEs: 'Tierras de la Peste del Oeste', min: 58, max: 60, size: 5, faction: null },
  { key: 'UBRS', nameEs: 'Cumbre de Roca Negra superior', zoneEs: 'Montaña Roca Negra', min: 58, max: 60, size: 10, faction: null },
] as const;
export type DungeonKey = (typeof DUNGEONS)[number]['key'];
export const dungeonByKey = (key: string) => DUNGEONS.find((d) => d.key === key);

/** Default 5-player composition; 10-player groups double it. */
export function groupComposition(size: number): Record<CombatRole, number> {
  return size >= 10 ? { TANK: 2, HEALER: 3, DPS: 5 } : { TANK: 1, HEALER: 1, DPS: 3 };
}
