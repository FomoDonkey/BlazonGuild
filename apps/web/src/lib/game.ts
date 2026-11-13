import type { CSSProperties } from 'react';
export { CLASSES, classById, qualityOf, raceById, specById, EQUIPMENT_SLOTS, RAID_INSTANCES, LEVEL_CAP } from '@blazonguild/types';

/** Theme-aware class colour (CSS variables swap to darker variants in the light theme). */
export const classVar = (classId: number | null | undefined) => (classId ? `var(--class-${classId})` : 'rgb(var(--c-text))');
export const qualityVar = (quality: string | null | undefined) => `var(--q-${quality ?? 'COMMON'})`;
export const classStyle = (classId: number | null | undefined): CSSProperties => ({ ['--cls' as string]: classVar(classId) }) as CSSProperties;

export const ROLE_LABEL = { TANK: 'Tanque', HEALER: 'Sanador', DPS: 'Daño' } as const;
export const FACTION_LABEL = { ALLIANCE: 'Alianza', HORDE: 'Horda' } as const;
export const REGION_LABEL: Record<string, string> = { eu: 'Europa', us: 'América', kr: 'Corea', tw: 'Taiwán' };

export const characterHref = (region: string, slug: string) => `/c/${region}/${encodeURIComponent(slug)}`;
export const guildHref = (region: string, slug: string, sub = '') => `/g/${region}/${encodeURIComponent(slug)}${sub}`;
